-- Dev tool (Studio, Edit): exports Creatures recipes as triangle data for the 3D drafts on the
-- Design canvas. Builds each look with Creatures.Record on (every plate keeps its triangle), tags each
-- triangle with the rig group it moves with (Body, Neck, FL1..BR4), reads the joints, and POSTs one
-- JSON file per look to the local receiver (tools/dev/recv.py, port 34894) -> tools/dev/pulled/_drafts/.
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/creature_export.lua?" .. os.clock(), true))()({ "Boar", "Wolf" })
local HS = game:GetService("HttpService")
local C = loadstring(HS:GetAsync("http://localhost:34893/src/ReplicatedStorage/Mystree/Creatures.lua?" .. os.clock(), true))()

local function r3(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

local function groupOf(part)
	local seg = part.Parent
	local leg = seg and seg.Parent
	if seg and seg:IsA("Model") and seg.Name:match("^Seg%d$") and leg and leg:GetAttribute("Side") then
		return (leg.Name == "LegFront" and "F" or "B") .. ((leg:GetAttribute("Side") > 0) and "R" or "L") .. seg.Name:sub(4)
	end
	if part.Name == "Jaw" then
		return "Jaw"
	end
	if C.HEAD_PARTS[part.Name] then
		return "Neck"
	end
	return "Body"
end

-- the second wedge of a triangle plate (T) carries no TriA; it is recognised by the "PlateHalf" mark
local function isPlateHalf(p)
	return p:GetAttribute("PlateHalf") == true
end

return function(ids)
	local out = {}
	for _, id in ipairs(ids) do
		local look = C.Looks[id] or C.Drafts[id]
		C.Record = true
		local m = C.build(look[1], look[2])
		C.Record = nil
		local tris, joints = {}, {}
		for _, p in ipairs(m:GetDescendants()) do
			local plain = p:IsA("BasePart") and p.Name ~= "Root" and not p:GetAttribute("TriA") and not (p:IsA("WedgePart") and p.Parent and false)
			if plain and (p:IsA("Part") or (p:IsA("WedgePart") and not p:GetAttribute("PlateHalf"))) and not isPlateHalf(p) then
				-- a block or wedge built directly (block-style creatures): its faces as triangles
				local col = p.Color
				local h = p.Size / 2
				local cf = p.CFrame
				local Vn = Vector3.new
				local polys
				if p:IsA("WedgePart") then
					polys = { { Vn(-h.X, -h.Y, -h.Z), Vn(h.X, -h.Y, -h.Z), Vn(h.X, -h.Y, h.Z), Vn(-h.X, -h.Y, h.Z) },
						{ Vn(-h.X, -h.Y, h.Z), Vn(h.X, -h.Y, h.Z), Vn(h.X, h.Y, h.Z), Vn(-h.X, h.Y, h.Z) },
						{ Vn(-h.X, -h.Y, -h.Z), Vn(h.X, -h.Y, -h.Z), Vn(h.X, h.Y, h.Z), Vn(-h.X, h.Y, h.Z) },
						{ Vn(h.X, -h.Y, -h.Z), Vn(h.X, -h.Y, h.Z), Vn(h.X, h.Y, h.Z) }, { Vn(-h.X, -h.Y, -h.Z), Vn(-h.X, -h.Y, h.Z), Vn(-h.X, h.Y, h.Z) } }
				else
					polys = {}
					for _, sx in ipairs({ -1, 1 }) do
						table.insert(polys, { Vn(sx * h.X, -h.Y, -h.Z), Vn(sx * h.X, h.Y, -h.Z), Vn(sx * h.X, h.Y, h.Z), Vn(sx * h.X, -h.Y, h.Z) })
						table.insert(polys, { Vn(-h.X, sx * h.Y, -h.Z), Vn(h.X, sx * h.Y, -h.Z), Vn(h.X, sx * h.Y, h.Z), Vn(-h.X, sx * h.Y, h.Z) })
						table.insert(polys, { Vn(-h.X, -h.Y, sx * h.Z), Vn(h.X, -h.Y, sx * h.Z), Vn(h.X, h.Y, sx * h.Z), Vn(-h.X, h.Y, sx * h.Z) })
					end
				end
				for _, poly in ipairs(polys) do
					for k = 2, #poly - 1 do
						local a2, b2, c2 = cf * poly[1], cf * poly[k], cf * poly[k + 1]
						table.insert(tris, { r3(a2.X), r3(a2.Y), r3(a2.Z), r3(b2.X), r3(b2.Y), r3(b2.Z), r3(c2.X), r3(c2.Y), r3(c2.Z),
							math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5),
							p.Material == Enum.Material.Neon and 1 or 0, groupOf(p) })
					end
				end
			end
			if p:IsA("WedgePart") and p:GetAttribute("TriA") then
				local a, b, c = p:GetAttribute("TriA"), p:GetAttribute("TriB"), p:GetAttribute("TriC")
				local col = p.Color
				table.insert(tris, { r3(a.X), r3(a.Y), r3(a.Z), r3(b.X), r3(b.Y), r3(b.Z), r3(c.X), r3(c.Y), r3(c.Z),
					math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5),
					p.Material == Enum.Material.Neon and 1 or 0, groupOf(p) })
			elseif p:IsA("Attachment") and p.Name == "Joint" then
				local g = groupOf(p.Parent)
				local w = p.WorldPosition
				joints[g] = { r3(w.X), r3(w.Y), r3(w.Z) }
			end
		end
		local parts = 0
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "Root" then
				parts += 1
			end
		end
		local rootC, neck, jp = m:GetAttribute("RootC"), m:GetAttribute("NeckBase"), m:GetAttribute("JawPivot")
		local nb = rootC + neck
		local jw = jp and (rootC + jp)
		local data = {
			id = id, recipe = look[1], parts = parts, length = m:GetAttribute("Length"), stride = m:GetAttribute("Stride"),
			neck = { r3(nb.X), r3(nb.Y), r3(nb.Z) }, jaw = jw and { r3(jw.X), r3(jw.Y), r3(jw.Z) } or nil, joints = joints, tris = tris,
		}
		m:Destroy()
		local body = HS:JSONEncode(data)
		HS:PostAsync("http://localhost:34894/_drafts/" .. id .. ".json", body, Enum.HttpContentType.ApplicationJson)
		table.insert(out, string.format("%s: %d triangles, %d parts, %d KB", id, #tris, parts, math.floor(#body / 1024)))
		task.wait()
	end
	return table.concat(out, "\n")
end
