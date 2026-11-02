-- Dev tool (Studio, Edit): z-fight check for triangle-plate sculpts in workspace._CreaturePreview.
-- Reports pairs of plate faces that face the same way, lie on the same plane (within 0.01 stud) and
-- truly overlap (a triangle's centre inside the other). Neighbouring facets that only share an edge
-- are not counted.
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/plate_zcheck.lua?" .. os.clock(), true))()
local res = {}
for _, m in ipairs(workspace._CreaturePreview:GetChildren()) do
	if not m:IsA("Model") then
		continue
	end
	local items = {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("WedgePart") then
			local cf, s = p.CFrame, p.Size
			for _, sg in ipairs({ 1, -1 }) do
				local o = Vector3.new(sg * s.X / 2, 0, 0)
				local tri = { cf * (o + Vector3.new(0, -s.Y / 2, -s.Z / 2)), cf * (o + Vector3.new(0, -s.Y / 2, s.Z / 2)), cf * (o + Vector3.new(0, s.Y / 2, s.Z / 2)) }
				table.insert(items, { P = p, N = cf.RightVector * sg, T = tri, C = (tri[1] + tri[2] + tri[3]) / 3 })
			end
		end
	end
	local function inside(pt, t, n)
		local ref = (t[2] - t[1]):Cross(t[3] - t[1]):Dot(n)
		for i = 1, 3 do
			local a, b = t[i], t[i % 3 + 1]
			if (b - a):Cross(pt - a):Dot(n) * ref < 1e-5 then
				return false
			end
		end
		return true
	end
	local buckets = {}
	for i, it in ipairs(items) do
		local k = string.format("%d,%d,%d,%d", math.floor(it.N.X * 20 + 0.5), math.floor(it.N.Y * 20 + 0.5), math.floor(it.N.Z * 20 + 0.5), math.floor(it.N:Dot(it.C) * 20 + 0.5))
		buckets[k] = buckets[k] or {}
		table.insert(buckets[k], i)
	end
	local bad, ex = 0, {}
	for _, list in pairs(buckets) do
		for a = 1, #list do
			for b = a + 1, #list do
				local A, B = items[list[a]], items[list[b]]
				if A.P ~= B.P and A.N:Dot(B.N) > 0.999 and math.abs(A.N:Dot(A.C - B.C)) < 0.01 and (inside(B.C, A.T, A.N) or inside(A.C, B.T, A.N)) then
					bad += 1
					if #ex < 5 then
						table.insert(ex, A.P.Name .. "/" .. B.P.Name .. (A.P.Color == B.P.Color and " (same colour)" or " (DIFFERENT colour)"))
					end
				end
			end
		end
	end
	table.insert(res, string.format("%s: %d plates, %d overlapping coplanar pairs %s", m.Name, #items / 2, bad, table.concat(ex, ", ")))
	task.wait()
end
return table.concat(res, "\n")
