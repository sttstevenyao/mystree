-- Dev tool (Studio, Edit): z-fight check for part-built models in workspace._CreaturePreview.
-- Every flat face of every block (Part) and wedge (WedgePart, its rectangles and triangles) is a
-- convex polygon; it reports pairs of faces from different parts that face the same way, lie on the
-- same plane (within 0.015 stud) and overlap (separating-axis test in that plane, 0.005 inset so
-- faces that only touch along an edge don't count). Pairs of the same colour and material, and faces
-- hidden inside another part, can't flicker and are skipped.
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/part_zcheck.lua?" .. os.clock(), true))()
local function faces(p)
	local cf, s = p.CFrame, p.Size / 2
	local out = {}
	local function add(n, pts)
		local w = {}
		for i, v in ipairs(pts) do
			w[i] = cf * v
		end
		table.insert(out, { P = p, N = cf:VectorToWorldSpace(n).Unit, Pts = w })
	end
	local V = Vector3.new
	if p:IsA("WedgePart") then
		add(V(0, -1, 0), { V(-s.X, -s.Y, -s.Z), V(s.X, -s.Y, -s.Z), V(s.X, -s.Y, s.Z), V(-s.X, -s.Y, s.Z) })
		add(V(0, 0, 1), { V(-s.X, -s.Y, s.Z), V(s.X, -s.Y, s.Z), V(s.X, s.Y, s.Z), V(-s.X, s.Y, s.Z) })
		add(V(0, s.Z, -s.Y), { V(-s.X, -s.Y, -s.Z), V(s.X, -s.Y, -s.Z), V(s.X, s.Y, s.Z), V(-s.X, s.Y, s.Z) })
		add(V(1, 0, 0), { V(s.X, -s.Y, -s.Z), V(s.X, -s.Y, s.Z), V(s.X, s.Y, s.Z) })
		add(V(-1, 0, 0), { V(-s.X, -s.Y, -s.Z), V(-s.X, -s.Y, s.Z), V(-s.X, s.Y, s.Z) })
	elseif p:IsA("Part") and p.Shape == Enum.PartType.Block then
		for _, ax in ipairs({ { V(1, 0, 0), V(0, 1, 0), V(0, 0, 1), s.X, s.Y, s.Z }, { V(0, 1, 0), V(0, 0, 1), V(1, 0, 0), s.Y, s.Z, s.X }, { V(0, 0, 1), V(1, 0, 0), V(0, 1, 0), s.Z, s.X, s.Y } }) do
			for _, sg in ipairs({ 1, -1 }) do
				local n, u, w, hn, hu, hw = ax[1] * sg, ax[2], ax[3], ax[4], ax[5], ax[6]
				local c = n * hn
				add(n, { c - u * hu - w * hw, c + u * hu - w * hw, c + u * hu + w * hw, c - u * hu + w * hw })
			end
		end
	end
	return out
end

-- do two convex polygons in one plane (normal n) overlap by more than a sliver?
local function overlap(A, B, n)
	local e1 = (A[2] - A[1]).Unit
	local e2 = n:Cross(e1).Unit
	local function proj(pts)
		local r = {}
		for i, v in ipairs(pts) do
			r[i] = Vector2.new(v:Dot(e1), v:Dot(e2))
		end
		return r
	end
	local a, b = proj(A), proj(B)
	for _, poly in ipairs({ a, b }) do
		for i = 1, #poly do
			local p1, p2 = poly[i], poly[i % #poly + 1]
			local ax = Vector2.new(-(p2.Y - p1.Y), p2.X - p1.X)
			if ax.Magnitude > 1e-6 then
				ax = ax.Unit
				local amin, amax, bmin, bmax = math.huge, -math.huge, math.huge, -math.huge
				for _, v in ipairs(a) do
					local d = v:Dot(ax)
					amin, amax = math.min(amin, d), math.max(amax, d)
				end
				for _, v in ipairs(b) do
					local d = v:Dot(ax)
					bmin, bmax = math.min(bmin, d), math.max(bmax, d)
				end
				if amax - 0.005 <= bmin or bmax - 0.005 <= amin then
					return false
				end
			end
		end
	end
	return true
end

-- a point inside a block or wedge (hidden faces can't flicker)
local function inside(part, pt)
	local l = part.CFrame:PointToObjectSpace(pt)
	local h = part.Size / 2
	if math.abs(l.X) > h.X or math.abs(l.Y) > h.Y or math.abs(l.Z) > h.Z then
		return false
	end
	if part:IsA("WedgePart") then
		-- below the slope from (-h.Y, -h.Z) to (h.Y, h.Z)
		return (l.Y + h.Y) / (2 * h.Y) <= (l.Z + h.Z) / (2 * h.Z)
	end
	return part:IsA("Part") and part.Shape == Enum.PartType.Block
end
local function hidden(face, parts)
	local c = Vector3.zero
	for _, v in ipairs(face.Pts) do
		c += v
	end
	c = c / #face.Pts + face.N * 0.02
	for _, p in ipairs(parts) do
		if p ~= face.P and inside(p, c) then
			return true
		end
	end
	return false
end

local res = {}
for _, m in ipairs(workspace._CreaturePreview:GetChildren()) do
	if not m:IsA("Model") then
		continue
	end
	local all, parts = {}, {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Root" and p.Transparency < 1 then
			table.insert(parts, p)
			for _, f in ipairs(faces(p)) do
				table.insert(all, f)
			end
		end
	end
	local bad, ex = 0, {}
	for i = 1, #all do
		local A = all[i]
		local dA = A.N:Dot(A.Pts[1])
		for j = i + 1, #all do
			local B = all[j]
			-- the two wedge halves of one triangle plate (same thickness and height, side by side) only
			-- touch along their shared edge
			local halves = A.P:IsA("WedgePart") and B.P:IsA("WedgePart") and A.P.Parent == B.P.Parent
				and math.abs(A.P.Size.X - B.P.Size.X) < 1e-3 and math.abs(A.P.Size.Y - B.P.Size.Y) < 1e-3
				and (A.P.Position - B.P.Position).Magnitude < A.P.Size.Y + math.max(A.P.Size.Z, B.P.Size.Z)
			if A.P ~= B.P and not halves and A.N:Dot(B.N) > 0.999 and math.abs(dA - A.N:Dot(B.Pts[1])) < 0.015 and overlap(A.Pts, B.Pts, A.N) then
				-- only faces that can be seen and differ in colour or material actually flicker
				local same = A.P.Color == B.P.Color and A.P.Material == B.P.Material
				if not same and not hidden(A, parts) and not hidden(B, parts) then
					bad += 1
				if #ex < 6 then
					table.insert(ex, A.P.Name .. "/" .. B.P.Name .. string.format(" @(%.2f,%.2f,%.2f)", A.Pts[1].X, A.Pts[1].Y, A.Pts[1].Z))
				end
				end
			end
		end
		if i % 400 == 0 then
			task.wait()
		end
	end
	table.insert(res, string.format("%s: %d faces, %d coplanar overlaps %s", m.Name, #all, bad, table.concat(ex, ", ")))
	task.wait()
end
return table.concat(res, "\n")
