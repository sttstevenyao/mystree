-- Dev tool (Studio, Edit): builds Creatures recipes into workspace._CreaturePreview (a grass pad at
-- 4000,200,4000) and poses their legs by forward kinematics with Creatures.angles, so gait frames
-- can be screenshotted without Play. Creatures faces +X; look from -Z for side views.
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/creature_preview.lua?" .. os.clock(), true))()(list)
-- list = { { Look = "MoonhornStag" | Recipe = "Deer", Opts = {...}, State = { Phase, Amp, Run } }, ... }
local HS = game:GetService("HttpService")
local C = loadstring(HS:GetAsync("http://localhost:34893/src/ReplicatedStorage/Mystree/Creatures.lua?" .. os.clock(), true))()
loadstring(HS:GetAsync("http://localhost:34893/src/ReplicatedStorage/Mystree/CreatureRecipes2.lua?" .. os.clock(), true))()(C)

local O = Vector3.new(4000, 200, 4000)

local function posed(m, state)
	local ang = C.angles(state)
	local axis = m:GetPivot().RightVector
	-- the lower jaw swings about its hinge (design point -> world through the Root at (0, size.Y/2, 0))
	local jp, rootC = m:GetAttribute("JawPivot"), m:GetAttribute("RootC")
	if jp and rootC and ang.Jaw and ang.Jaw ~= 0 then
		local design = m.PrimaryPart.CFrame * CFrame.new(0, -m.PrimaryPart.Size.Y / 2, 0)
		local J = design * (rootC + jp)
		local turn = CFrame.new(J) * CFrame.fromAxisAngle(axis, ang.Jaw) * CFrame.new(-J)
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Jaw" then
				p.CFrame = turn * p.CFrame
			end
		end
	end
	for _, leg in ipairs(m:GetChildren()) do
		if leg:IsA("Model") and leg:GetAttribute("Side") then
			local tag = (leg.Name == "LegFront" and "F" or "B") .. ((leg:GetAttribute("Side") > 0) and "R" or "L")
			local joints = {}
			for i = 1, 4 do
				for _, d in ipairs(leg["Seg" .. i]:GetDescendants()) do
					if d:IsA("Attachment") and d.Name == "Joint" then
						joints[i] = d.WorldPosition
					end
				end
			end
			local acc = CFrame.new()
			for i = 1, 4 do
				acc = acc * CFrame.new(joints[i]) * CFrame.fromAxisAngle(axis, ang[tag .. i]) * CFrame.new(-joints[i])
				local seg = leg["Seg" .. i]
				seg:PivotTo(acc * seg:GetPivot())
			end
		end
	end
end

return function(list)
	local f = workspace:FindFirstChild("_CreaturePreview")
	if not f then
		f = Instance.new("Folder")
		f.Name = "_CreaturePreview"
		local g = Instance.new("Part")
		g.Anchored = true
		g.Size = Vector3.new(80, 1, 60)
		g.Position = O - Vector3.new(0, 0.5, 0)
		g.Color = Color3.fromRGB(110, 170, 80)
		g.Material = Enum.Material.Grass
		g.Parent = f
		f.Parent = workspace
	end
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("Model") then
			c:Destroy()
		end
	end
	local counts = {}
	for i, e in ipairs(list) do
		local recipe, opts = e.Recipe, e.Opts or {}
		if e.Look then
			local look = C.Looks[e.Look] or C.Drafts[e.Look]
			recipe, opts = look[1], look[2]
		end
		local m = C.build(recipe, opts)
		local pv = m:GetPivot()
		m:PivotTo(CFrame.new(O + Vector3.new((i - (#list + 1) / 2) * (e.Gap or 9.5), pv.Y, 0)) * CFrame.Angles(0, math.rad(-90), 0))
		m.Parent = f
		if e.State then
			posed(m, e.State)
		end
		local n = 0
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		table.insert(counts, n)
		task.wait()
	end
	return "parts: " .. table.concat(counts, ", ")
end
