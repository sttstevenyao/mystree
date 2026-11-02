-- ReplicatedStorage/Mystree/Builders (ModuleScript)
-- PLACEHOLDER models, built from code so every system works before the art pass. Real art goes in
-- ReplicatedStorage.MystreeAssets.<Kind>.<Id> and Assets.get() prefers it (see Assets).
-- Placeholders follow the Mystree look rules: smooth parts, real materials, no studs, no blocks
-- thrown together. Every model has an invisible upright "Root" as PrimaryPart (Playbook 05).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Creatures = require(ReplicatedStorage.Mystree.Creatures)

local Builders = {}

-- ===================================================================== helpers
function Builders.part(parent, props)
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local part = Builders.part

local function newModel(name, cf, size)
	local m = Instance.new("Model")
	m.Name = name
	local root = part(m, { Name = "Root", Size = size or Vector3.new(1, 1, 1), CFrame = cf, Transparency = 1, CastShadow = false })
	m.PrimaryPart = root
	return m, root
end

-- a cylinder standing up between two points (cylinder axis is X, so rotate)
local function limb(parent, a, b, radius, props)
	local len = (b - a).Magnitude
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(len, radius * 2, radius * 2)
	props.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, props)
end
Builders.limb = limb

-- Weld every BasePart in a model to its root, unanchored (for things that move with physics)
function Builders.weldAll(model, root)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			p.Anchored = false
			p.Massless = true
		end
	end
end

local function rarityColor(r)
	return Config.Rarities[math.clamp(r or 1, 1, #Config.Rarities)].Color
end

-- ===================================================================== the Divine Tree
-- One model per growth stage (1..5). Twisted trunk, buttress roots, layered canopy, and glowing blue
-- veins in the bark like the reference (separate Neon parts so they can pulse).
function Builders.Tree(stage, cf)
	stage = math.clamp(stage or 1, 1, 5)
	local s = 0.75 + stage * 0.25 -- overall scale
	local m, root = newModel("DivineTree", cf, Vector3.new(4, 4, 4))
	local bark = Color3.fromRGB(92, 78, 64)
	local leaf = Color3.fromRGB(88, 140, 92):Lerp(Color3.fromRGB(120, 190, 150), (stage - 1) / 4)
	local trunkH = 22 * s
	-- trunk: stacked, slightly twisting cylinders that taper
	local prev = cf.Position
	local segs = 6
	for i = 1, segs do
		local t = i / segs
		local twist = CFrame.Angles(0, t * 1.6, 0) * Vector3.new(math.sin(t * 3) * 1.6 * s, 0, 0)
		local nextP = cf.Position + Vector3.new(twist.X, trunkH * t, twist.Z)
		local r = (3.2 - 1.6 * t) * s
		limb(m, prev, nextP + Vector3.new(0, 0.6 * s, 0), r, { Name = "Trunk", Material = Enum.Material.Wood, Color = bark })
		prev = nextP
	end
	-- hit point for chips: front of the trunk at chest height
	part(m, { Name = "Hit", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 4, -3.2 * s), Transparency = 1, CastShadow = false })
	-- buttress roots
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + 0.3
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local p0 = cf.Position + Vector3.new(0, 2.5 * s, 0) + out * 1.5 * s
		local p1 = cf.Position + out * (6 + (i % 3)) * s + Vector3.new(0, -0.4, 0)
		limb(m, p0, p1, (1.1 - (i % 2) * 0.25) * s, { Name = "RootArm", Material = Enum.Material.Wood, Color = bark:Lerp(Color3.new(0, 0, 0), 0.1) })
	end
	-- branches + canopy clusters
	local top = prev
	for i = 1, 4 + stage do
		local a = i / (4 + stage) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0.55 + (i % 3) * 0.15, math.sin(a)).Unit
		local b0 = top - Vector3.new(0, (i % 3) * 2 * s, 0)
		local b1 = b0 + dir * (8 + (i % 4)) * s
		limb(m, b0, b1, 0.9 * s, { Name = "Branch", Material = Enum.Material.Wood, Color = bark })
		for j = 1, 2 do
			local c = b1 + Vector3.new((j - 1.5) * 3 * s, (j - 1) * 2 * s, (i % 2 - 0.5) * 2 * s)
			local d = (8 + (i + j) % 3 * 2) * s
			part(m, { Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(c), Material = Enum.Material.LeafyGrass, Color = leaf:Lerp(Color3.fromRGB(60, 100, 70), ((i + j) % 3) * 0.12), CastShadow = true })
		end
	end
	local crown = (12 + stage * 2) * s
	part(m, { Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(crown, crown * 0.8, crown), CFrame = CFrame.new(top + Vector3.new(0, 3 * s, 0)), Material = Enum.Material.LeafyGrass, Color = leaf })
	-- glowing veins (pulse on the client): thin strips sitting 0.05 proud of the bark
	for i = 1, 2 + stage do
		local a = i * 2.1
		local h0 = 2 + i * 2.2
		local r = (3.2 - 1.6 * (h0 / trunkH)) * s
		local p = cf.Position + Vector3.new(math.cos(a) * (r + 0.05), h0 * s, math.sin(a) * (r + 0.05))
		part(m, { Name = "Vein", Size = Vector3.new(0.18, 3.2 * s, 0.3), CFrame = CFrame.lookAt(p, cf.Position + Vector3.new(0, h0 * s, 0)) * CFrame.Angles(0, 0, 0.25 * ((i % 2) * 2 - 1)), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 200, 255), CastShadow = false })
	end
	-- blue spirit flowers at the base
	for i = 1, 3 + stage do
		local a = i * 1.7
		local p = cf.Position + Vector3.new(math.cos(a) * (5 + i % 3) * s, 0.4, math.sin(a) * (5 + i % 3) * s)
		part(m, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(p), Material = Enum.Material.Neon, Color = Color3.fromRGB(110, 190, 255), CastShadow = false })
	end
	-- collision for the trunk only (players walk around it, not through it)
	part(m, { Name = "Collider", Shape = Enum.PartType.Cylinder, Size = Vector3.new(trunkH, 6 * s, 6 * s), CFrame = cf * CFrame.new(0, trunkH / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1, CanCollide = true, CastShadow = false })
	m:SetAttribute("Stage", stage)
	return m
end

-- ===================================================================== weapons and the axe
-- Weapons are built around a "Handle" part whose "Grip" attachment sits in the palm. Blades point up
-- the handle's +Y. Epic+ get a Neon edge strip (its own part, so it can pulse) in the rarity colour.
function Builders.Weapon(class, rarity)
	local m = Instance.new("Model")
	m.Name = class
	local steel = Color3.fromRGB(196, 200, 206):Lerp(rarityColor(rarity), 0.12)
	local grip = Color3.fromRGB(70, 48, 36)
	local handleLen = (class == "Spear") and 9 or (class == "Greatsword" and 2.4 or 1.4)
	local handle = part(m, { Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(handleLen, 0.32, 0.32), CFrame = CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = grip })
	m.PrimaryPart = handle
	local g = Instance.new("Attachment")
	g.Name = "Grip"
	g.CFrame = CFrame.new(-handleLen / 2 + 0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
	g.Parent = handle
	local up = handle.CFrame * CFrame.Angles(0, 0, math.rad(-90)) -- +Y along the handle
	local function at(y)
		return up * CFrame.new(0, y, 0)
	end
	local edge = rarity >= 4
	local glow = rarityColor(rarity)
	if class == "Spear" then
		part(m, { Name = "Head", Class = "WedgePart", Size = Vector3.new(0.16, 2.2, 0.7), CFrame = at(handleLen / 2 + 1.1), Material = Enum.Material.Metal, Color = steel })
		part(m, { Name = "Head2", Class = "WedgePart", Size = Vector3.new(0.16, 2.2, 0.7), CFrame = at(handleLen / 2 + 1.1) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Metal, Color = steel })
		part(m, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.45, 0.45), CFrame = at(handleLen / 2) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = glow })
		if edge then
			part(m, { Name = "Glow", Size = Vector3.new(0.05, 1.6, 0.05), CFrame = at(handleLen / 2 + 1) * CFrame.new(0.11, 0, 0), Material = Enum.Material.Neon, Color = glow, CastShadow = false })
		end
	else
		local big = class == "Greatsword"
		local bladeLen = big and 6.2 or 4.2
		local bladeW = big and 0.95 or 0.55
		local base = handleLen / 2
		part(m, { Name = "Guard", Size = Vector3.new(0.34, 0.3, big and 2.4 or 1.6), CFrame = at(base + 0.1), Material = Enum.Material.Metal, Color = glow:Lerp(Color3.fromRGB(80, 70, 60), 0.5) })
		part(m, { Name = "Pommel", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = at(-base - 0.15), Material = Enum.Material.Metal, Color = glow:Lerp(Color3.fromRGB(80, 70, 60), 0.5) })
		part(m, { Name = "Blade", Size = Vector3.new(0.14, bladeLen, bladeW), CFrame = at(base + 0.2 + bladeLen / 2), Material = Enum.Material.Metal, Color = steel })
		part(m, { Name = "Tip", Class = "WedgePart", Size = Vector3.new(0.14, 0.9, bladeW / 2), CFrame = at(base + 0.2 + bladeLen + 0.45) * CFrame.new(0, 0, bladeW / 4), Material = Enum.Material.Metal, Color = steel })
		part(m, { Name = "Tip2", Class = "WedgePart", Size = Vector3.new(0.14, 0.9, bladeW / 2), CFrame = at(base + 0.2 + bladeLen + 0.45) * CFrame.new(0, 0, -bladeW / 4) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Metal, Color = steel })
		-- fuller (a recessed groove reads as detail): darker strip 0.03 proud each side
		part(m, { Name = "Fuller", Size = Vector3.new(0.2, bladeLen * 0.7, bladeW * 0.18), CFrame = at(base + 0.2 + bladeLen * 0.4), Material = Enum.Material.Metal, Color = steel:Lerp(Color3.new(0, 0, 0), 0.25) })
		if edge then
			part(m, { Name = "Glow", Size = Vector3.new(0.17, bladeLen * 0.9, 0.06), CFrame = at(base + 0.2 + bladeLen * 0.48) * CFrame.new(0, 0, bladeW / 2 + 0.01), Material = Enum.Material.Neon, Color = glow, CastShadow = false })
		end
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
		end
	end
	return m
end

function Builders.Axe()
	local m = Instance.new("Model")
	m.Name = "Axe"
	local handle = part(m, { Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 0.3, 0.3), CFrame = CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 84, 56) })
	m.PrimaryPart = handle
	local g = Instance.new("Attachment")
	g.Name = "Grip"
	g.CFrame = CFrame.new(-1.2, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
	g.Parent = handle
	local up = handle.CFrame * CFrame.Angles(0, 0, math.rad(-90))
	part(m, { Name = "Head", Size = Vector3.new(0.3, 1.0, 1.4), CFrame = up * CFrame.new(0, 1.35, -0.6), Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 156, 162) })
	part(m, { Name = "Bit", Class = "WedgePart", Size = Vector3.new(0.26, 1.5, 0.6), CFrame = up * CFrame.new(0, 1.35, -1.55) * CFrame.Angles(math.rad(180), 0, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 205, 210) })
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
		end
	end
	return m
end

-- Gear previews for the UI (armour and jewellery have no in-world model yet). Small, smooth shapes in
-- the slot's material with a rarity-coloured accent; replaced by MystreeAssets.Gear.<Slot>_<R>.
function Builders.GearIcon(slot, rarity)
	local m = Instance.new("Model")
	m.Name = slot
	local c = rarityColor(rarity)
	local metal = Color3.fromRGB(176, 180, 186):Lerp(c, 0.15)
	local leather = Color3.fromRGB(120, 82, 56)
	local cloth = Color3.fromRGB(150, 130, 100):Lerp(c, 0.35)
	local O = CFrame.new()
	if slot == "Helm" then
		part(m, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = O, Material = Enum.Material.Metal, Color = metal })
		part(m, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.6, 2.6), CFrame = O * CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = c })
		part(m, { Name = "Crest", Size = Vector3.new(0.25, 1.1, 1.8), CFrame = O * CFrame.new(0, 1.3, 0), Material = Enum.Material.Fabric, Color = c })
	elseif slot == "Armor" then
		part(m, { Name = "Chest", Size = Vector3.new(2.6, 2.8, 1.3), CFrame = O, Material = Enum.Material.Metal, Color = metal })
		for _, sx in ipairs({ -1, 1 }) do
			part(m, { Name = "Pauldron", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.1, 1.4), CFrame = O * CFrame.new(sx * 1.45, 1.1, 0), Material = Enum.Material.Metal, Color = c })
		end
		part(m, { Name = "Belt", Size = Vector3.new(2.7, 0.35, 1.4), CFrame = O * CFrame.new(0, -1.1, 0), Material = Enum.Material.Leather, Color = leather })
	elseif slot == "Boots" then
		for _, sx in ipairs({ -0.75, 0.75 }) do
			part(m, { Name = "Shaft", Size = Vector3.new(0.9, 1.8, 0.9), CFrame = O * CFrame.new(sx, 0.4, 0.2), Material = Enum.Material.Leather, Color = cloth })
			part(m, { Name = "Foot", Size = Vector3.new(0.9, 0.6, 1.7), CFrame = O * CFrame.new(sx, -0.5, -0.2), Material = Enum.Material.Leather, Color = cloth })
			part(m, { Name = "Cuff", Size = Vector3.new(1.0, 0.25, 1.0), CFrame = O * CFrame.new(sx, 1.25, 0.2), Material = Enum.Material.Metal, Color = c })
		end
	elseif slot == "Belt" then
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			part(m, { Name = "Link", Size = Vector3.new(0.4, 0.5, 0.75), CFrame = O * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.3), Material = Enum.Material.Leather, Color = leather })
		end
		part(m, { Name = "Buckle", Size = Vector3.new(0.9, 0.8, 0.2), CFrame = O * CFrame.new(0, 0, -1.6), Material = Enum.Material.Metal, Color = c })
	elseif slot == "Gloves" then
		for _, sx in ipairs({ -0.8, 0.8 }) do
			part(m, { Name = "Hand", Size = Vector3.new(0.9, 1.4, 0.5), CFrame = O * CFrame.new(sx, 0, 0) * CFrame.Angles(0, 0, sx * -0.15), Material = Enum.Material.Leather, Color = cloth })
			part(m, { Name = "Cuff", Size = Vector3.new(1.05, 0.5, 0.65), CFrame = O * CFrame.new(sx, -0.85, 0) * CFrame.Angles(0, 0, sx * -0.15), Material = Enum.Material.Metal, Color = c })
		end
	elseif slot == "Necklace" or slot == "Ring" then
		local r = (slot == "Ring") and 0.9 or 1.4
		for i = 0, 13 do
			local a = i / 14 * math.pi * 2
			part(m, { Name = "Band", Size = Vector3.new(0.3, 0.3, r * 0.5), CFrame = O * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0, -r), Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 190, 110) })
		end
		part(m, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75), CFrame = O * CFrame.new(0, -r - 0.25, 0), Material = Enum.Material.Glass, Color = c })
	end
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	return m
end

-- ===================================================================== creatures (mobs, companions, mounts)
-- Body plans: Quadruped (boar, wolf, stag, tortoise), Biped (bandit, skeleton, golem), Floater (wraith),
-- Bird. size = bounding size (x width, y height, z length). Returns a model whose Root is the body
-- centre at height size.Y/2 above the ground. Parts are anchored; callers weld if needed.
function Builders.Creature(name, plan, size, color, cf)
	cf = cf or CFrame.new()
	local m, root = newModel(name, cf, size)
	local accent = color:Lerp(Color3.new(0, 0, 0), 0.35)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.25)
	local mat = Enum.Material.Fabric
	local w, h, l = size.X, size.Y, size.Z
	local ground = cf * CFrame.new(0, -h / 2, 0)
	local function at(x, y, z)
		return ground * CFrame.new(x, y, z)
	end
	if plan == "Quadruped" then
		local legH = h * 0.42
		local bodyH = h * 0.45
		part(m, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(w, bodyH, l * 0.72), CFrame = at(0, legH + bodyH / 2, 0), Material = mat, Color = color })
		part(m, { Name = "Chest", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.95, bodyH * 1.05, l * 0.4), CFrame = at(0, legH + bodyH * 0.55, -l * 0.22), Material = mat, Color = color })
		local head = part(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.62, bodyH * 0.7, l * 0.3), CFrame = at(0, legH + bodyH * 0.8, -l * 0.46), Material = mat, Color = light })
		part(m, { Name = "Snout", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.36, bodyH * 0.36, l * 0.22), CFrame = head.CFrame * CFrame.new(0, -bodyH * 0.1, -l * 0.14), Material = mat, Color = light })
		for _, sx in ipairs({ -1, 1 }) do
			part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * math.max(1, w / 4), CFrame = head.CFrame * CFrame.new(sx * w * 0.2, bodyH * 0.1, -l * 0.12), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 210, 120), CastShadow = false })
			part(m, { Name = "Ear", Class = "WedgePart", Size = Vector3.new(0.2, w * 0.25, w * 0.18), CFrame = head.CFrame * CFrame.new(sx * w * 0.2, bodyH * 0.38, l * 0.02), Material = mat, Color = accent })
			for _, sz in ipairs({ -1, 1 }) do
				local hip = at(sx * w * 0.3, legH + 0.2, sz * l * 0.26)
				local leg = limb(m, hip.Position, at(sx * w * 0.3, 0.3, sz * l * 0.26).Position, w * 0.11, { Name = "Leg", Material = mat, Color = accent })
				leg:SetAttribute("Side", sx)
				leg:SetAttribute("End", sz)
			end
		end
		limb(m, at(0, legH + bodyH * 0.6, l * 0.34).Position, at(0, legH + bodyH * 0.3, l * 0.5).Position, w * 0.07, { Name = "Tail", Material = mat, Color = accent })
	elseif plan == "Biped" then
		local legH = h * 0.45
		part(m, { Name = "Torso", Size = Vector3.new(w * 0.8, h * 0.32, l * 0.7), CFrame = at(0, legH + h * 0.16, 0), Material = mat, Color = color })
		part(m, { Name = "Hips", Size = Vector3.new(w * 0.7, h * 0.1, l * 0.65), CFrame = at(0, legH + 0.02, 0), Material = mat, Color = accent })
		local head = part(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.42, h * 0.15, w * 0.42), CFrame = at(0, legH + h * 0.32 + h * 0.09, 0), Material = mat, Color = light })
		for _, sx in ipairs({ -1, 1 }) do
			part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22) * math.max(1, w / 3), CFrame = head.CFrame * CFrame.new(sx * w * 0.08, 0, -w * 0.19), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 90), CastShadow = false })
			local sh = at(sx * w * 0.5, legH + h * 0.29, 0)
			local arm = limb(m, sh.Position, at(sx * w * 0.55, legH - h * 0.02, 0).Position, w * 0.12, { Name = "Arm", Material = mat, Color = color })
			arm:SetAttribute("Side", sx)
			local leg = limb(m, at(sx * w * 0.2, legH, 0).Position, at(sx * w * 0.2, 0.2, 0).Position, w * 0.15, { Name = "Leg", Material = mat, Color = accent })
			leg:SetAttribute("Side", sx)
		end
	elseif plan == "Floater" then
		part(m, { Name = "Cloak", Class = "WedgePart", Size = Vector3.new(w, h * 0.7, l), CFrame = at(0, h * 0.45, 0) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Fabric, Color = color, Transparency = 0.15 })
		part(m, { Name = "Cloak2", Class = "WedgePart", Size = Vector3.new(w, h * 0.7, l), CFrame = at(0, h * 0.45, 0), Material = Enum.Material.Fabric, Color = color, Transparency = 0.15 })
		local head = part(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.5, w * 0.5, w * 0.5), CFrame = at(0, h * 0.86, 0), Material = Enum.Material.Fabric, Color = accent })
		for _, sx in ipairs({ -1, 1 }) do
			part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = head.CFrame * CFrame.new(sx * w * 0.1, 0, -w * 0.22), Material = Enum.Material.Neon, Color = Color3.fromRGB(140, 220, 255), CastShadow = false })
		end
	elseif plan == "Serpent" then
		-- a chain of ellipsoid segments snaking back from the head (-Z), thinning to the tail
		local n = 8
		for i = 0, n - 1 do
			local t = i / (n - 1)
			local k = 1 - t * 0.6
			local seg = Vector3.new(w * k, h * k, l / n * 1.7)
			local cfs = at(math.sin(t * math.pi * 2) * w * 0.3, seg.Y / 2, -l * 0.42 + t * l * 0.84)
			part(m, { Name = (i == 0) and "Head" or "Body", Shape = Enum.PartType.Ball, Size = seg, CFrame = cfs, Material = mat, Color = (i % 2 == 0) and color or accent })
			if i == 0 then
				for _, sx in ipairs({ -1, 1 }) do
					part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * math.max(1, w / 2), CFrame = cfs * CFrame.new(sx * w * 0.28, seg.Y * 0.2, -seg.Z * 0.3), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 90), CastShadow = false })
				end
			end
		end
	elseif plan == "Bird" then
		part(m, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.5, h * 0.5, l * 0.8), CFrame = at(0, h * 0.5, 0), Material = mat, Color = color })
		local head = part(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.3, w * 0.3, w * 0.3), CFrame = at(0, h * 0.72, -l * 0.38), Material = mat, Color = light })
		part(m, { Name = "Beak", Class = "WedgePart", Size = Vector3.new(0.2, 0.2, 0.5), CFrame = head.CFrame * CFrame.new(0, 0, -w * 0.2) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 190, 80) })
		for _, sx in ipairs({ -1, 1 }) do
			local wing = part(m, { Name = "Wing", Size = Vector3.new(w * 0.9, 0.12, l * 0.45), CFrame = at(sx * w * 0.6, h * 0.55, 0), Material = mat, Color = accent })
			wing:SetAttribute("Side", sx)
		end
	end
	return m
end

-- Mobs: a Humanoid-driven model. The Root is the HumanoidRootPart (collides, moves), the body is welded.
function Builders.Mob(id, cf)
	local def = Config.Mobs[id]
	if Creatures.Looks[id] then
		return Creatures.mob(id, def, cf) -- sculpted, jointed creature (smooth low poly)
	end
	local m = Builders.Creature(id, def.Body, def.Size, def.Color, cf * CFrame.new(0, def.Size.Y / 2, 0))
	local root = m.PrimaryPart
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(def.Size.X, def.Size.Y * 0.6, math.min(def.Size.Z, def.Size.X * 1.4))
	root.CanCollide = false
	root.CanQuery = true
	if def.Kind == "Boss" or def.Kind == "Event" then
		-- event/boss glow so they read from far away
		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = root
	end
	Builders.weldAll(m, root)
	root.Anchored = false
	root.Massless = false
	local hum = Instance.new("Humanoid")
	hum.HipHeight = def.Size.Y * 0.2
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = m
	return m
end

function Builders.Companion(id)
	local def = Config.Companions[id]
	if def.Look and Creatures.Looks[def.Look] then
		-- a sculpted spirit (shop and Spirits window previews; the follower is rigged by Equipment)
		local look = Creatures.Looks[def.Look]
		local m = Creatures.build(look[1], look[2])
		m:ScaleTo(def.Length / (m:GetAttribute("Length") or 6))
		m.Name = id
		return m
	end
	local s = def.Size
	if def.Fly then
		return Builders.Creature(id, "Bird", Vector3.new(s * 1.3, s, s * 1.2), def.Color)
	end
	return Builders.Creature(id, "Quadruped", Vector3.new(s * 0.7, s, s * 1.4), def.Color)
end

-- Mounts: ground mounts are a creature with a saddle; hover mounts are a flying sword or a cloud.
-- Root sits at the rider's hip height; "Seat" marks where the rider's HumanoidRootPart goes.
function Builders.Mount(id)
	local def = Config.Mounts[id]
	if def.Look and Creatures.Looks[def.Look] then
		-- a sculpted mount for display (shop previews, the stable): standing, pivot on the ground.
		-- The ridden one is built and rigged by the client (Equipment).
		local look = Creatures.Looks[def.Look]
		local sm = Creatures.build(look[1], look[2])
		sm.Name = id
		sm:ScaleTo((def.Length or 7.5) / (sm:GetAttribute("Length") or 6))
		local cf, size = sm:GetBoundingBox()
		local root = sm.PrimaryPart
		root.Anchored = true
		root.PivotOffset = root.CFrame:ToObjectSpace(CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z))
		for _, d in ipairs(sm:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		return sm
	end
	local m
	if def.Kind == "Hover" then
		m = newModel(id, CFrame.new(), Vector3.new(2, 1, 6))
		if id == "FlyingSword" then
			local blade = Builders.Weapon("Greatsword", 6)
			for _, p in ipairs(blade:GetChildren()) do
				p.Parent = m
			end
			blade:Destroy()
			-- lay the greatsword flat, blade forward
			local hcf = CFrame.new(0, 0, 2) * CFrame.Angles(math.rad(-90), 0, 0)
			local handle = m:FindFirstChild("Handle")
			local rel = handle.CFrame:Inverse()
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") and p.Name ~= "Root" then
					p.CFrame = hcf * rel * p.CFrame
					p.Size = p.Size * 1
				end
			end
		else
			for i = 1, 7 do
				local x = (i - 4) * 0.9
				local d = 2.6 + (i % 3) * 0.7
				part(m, { Name = "Puff", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.7, d), CFrame = CFrame.new(x * 0.6, -0.4 + (i % 2) * 0.3, (i % 3 - 1) * 1.1), Material = Enum.Material.SmoothPlastic, Color = def.Color, Transparency = 0.05 })
			end
		end
		local seat = part(m, { Name = "Seat", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 2.2, 0), Transparency = 1, CastShadow = false })
		seat:SetAttribute("Hover", true)
	else
		local size = Vector3.new(2.6, 5.6, 7.4)
		m = Builders.Creature(id, "Quadruped", size, def.Color, CFrame.new(0, 0, 0))
		local bodyTop = -size.Y / 2 + size.Y * 0.42 + size.Y * 0.45
		part(m, { Name = "Saddle", Size = Vector3.new(size.X * 0.85, 0.35, 2.2), CFrame = CFrame.new(0, bodyTop - 0.05, 0.4), Material = Enum.Material.Leather, Color = Color3.fromRGB(110, 50, 40) })
		part(m, { Name = "Seat", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, bodyTop + 2.2, 0.4), Transparency = 1, CastShadow = false })
	end
	return m
end

-- ===================================================================== map pieces
-- ===================================================================== interactables
-- A walk-up prompt that opens a window (client Interact.lua): an invisible anchored part named
-- "Interact" holding a ProximityPrompt named "Interact" with attributes Opens (the client module)
-- and Tab. Custom style: the client draws the jade pill.
function Builders.interact(parent, cf, opens, tab, action, object)
	local p = part(parent, { Name = "Interact", Size = Vector3.new(1, 1, 1), CFrame = cf, Transparency = 1, CastShadow = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Interact"
	prompt.ActionText = action
	prompt.ObjectText = object or ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Opens", opens)
	if tab then
		prompt:SetAttribute("Tab", tab)
	end
	prompt.Parent = p
	return p
end

-- Storage chest (island, opens the Bag). cf = ground centre, front -Z. Footprint radius ~2.
-- Every layer sits at its own depth: bands and brackets 0.03 proud, the lid 0.03 longer than the body.
function Builders.Chest(parent, cf)
	local m = Instance.new("Model")
	m.Name = "StorageChest"
	local wood = Color3.fromRGB(120, 78, 48)
	local dark = Color3.fromRGB(70, 46, 30)
	local gold = Color3.fromRGB(214, 170, 70)
	local M = Enum.Material
	part(m, { Name = "Feet", Size = Vector3.new(3.3, 0.3, 2.1), CFrame = cf * CFrame.new(0, 0.15, 0), Material = M.Wood, Color = dark, CanCollide = true })
	part(m, { Name = "Body", Size = Vector3.new(3.2, 1.6, 2), CFrame = cf * CFrame.new(0, 1.1, 0), Material = M.WoodPlanks, Color = wood, CanCollide = true })
	-- rounded lid: a cylinder along X whose lower half sits inside the body
	part(m, { Name = "Lid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.26, 2, 2), CFrame = cf * CFrame.new(0, 1.9, 0), Material = M.WoodPlanks, Color = wood:Lerp(Color3.new(1, 1, 1), 0.06), CanCollide = true })
	for _, x in ipairs({ -1.05, 1.05 }) do
		-- iron bands over body and lid (slightly bigger than both)
		part(m, { Name = "Band", Size = Vector3.new(0.22, 1.66, 2.06), CFrame = cf * CFrame.new(x, 1.1, 0), Material = M.Metal, Color = Color3.fromRGB(64, 64, 68) })
		part(m, { Name = "LidBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.26, 2.06, 2.06), CFrame = cf * CFrame.new(x, 1.9, 0), Material = M.Metal, Color = Color3.fromRGB(64, 64, 68) })
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(m, { Name = "Corner", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = cf * CFrame.new(sx * 1.5, 0.45, sz * 0.9), Material = M.Metal, Color = gold, CastShadow = false })
		end
	end
	part(m, { Name = "Lock", Size = Vector3.new(0.5, 0.6, 0.1), CFrame = cf * CFrame.new(0, 1.62, -1.04), Material = M.Metal, Color = gold, CastShadow = false })
	part(m, { Name = "Keyhole", Size = Vector3.new(0.12, 0.22, 0.06), CFrame = cf * CFrame.new(0, 1.58, -1.1), Material = M.SmoothPlastic, Color = Color3.fromRGB(30, 24, 20), CastShadow = false })
	-- a faint glow from the lid seam: something good is inside
	part(m, { Name = "Seam", Size = Vector3.new(2.9, 0.06, 0.06), CFrame = cf * CFrame.new(0, 1.92, -1.02), Material = M.Neon, Color = Color3.fromRGB(255, 220, 140), CastShadow = false })
	Builders.interact(m, cf * CFrame.new(0, 2.4, 0), "Bag", nil, "Bag", "Storage Chest")
	m.PrimaryPart = m:FindFirstChild("Body")
	m.Parent = parent
	return m
end

-- Decor workbench (island, opens the decor shop). cf = ground centre, front -Z. Footprint radius ~2.5.
function Builders.Workbench(parent, cf)
	local m = Instance.new("Model")
	m.Name = "DecorWorkbench"
	local wood = Color3.fromRGB(150, 112, 74)
	local dark = Color3.fromRGB(84, 60, 42)
	local M = Enum.Material
	part(m, { Name = "Top", Size = Vector3.new(4.2, 0.3, 2.2), CFrame = cf * CFrame.new(0, 2.85, 0), Material = M.WoodPlanks, Color = wood, CanCollide = true })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(m, { Name = "Leg", Size = Vector3.new(0.3, 2.7, 0.3), CFrame = cf * CFrame.new(sx * 1.8, 1.35, sz * 0.8), Material = M.Wood, Color = dark, CanCollide = true })
		end
		part(m, { Name = "Rail", Size = Vector3.new(0.2, 0.2, 1.3), CFrame = cf * CFrame.new(sx * 1.8, 0.6, 0), Material = M.Wood, Color = dark })
	end
	part(m, { Name = "Shelf", Size = Vector3.new(3.4, 0.16, 1.3), CFrame = cf * CFrame.new(0, 0.7, 0), Material = M.WoodPlanks, Color = dark:Lerp(wood, 0.5) })
	-- on top: a blueprint, a small lantern being built, a hammer, a plank offcut
	part(m, { Name = "Blueprint", Size = Vector3.new(1.4, 0.04, 1.0), CFrame = cf * CFrame.new(-1.0, 3.02, 0.1) * CFrame.Angles(0, 0.2, 0), Material = M.Fabric, Color = Color3.fromRGB(120, 170, 210), CastShadow = false })
	part(m, { Name = "Ink", Size = Vector3.new(0.9, 0.02, 0.06), CFrame = cf * CFrame.new(-1.0, 3.05, 0.1) * CFrame.Angles(0, 0.2, 0), Material = M.SmoothPlastic, Color = Color3.fromRGB(240, 246, 255), CastShadow = false })
	part(m, { Name = "LanternBase", Size = Vector3.new(0.6, 0.3, 0.6), CFrame = cf * CFrame.new(0.9, 3.15, 0.2), Material = M.Slate, Color = Color3.fromRGB(128, 124, 116) })
	part(m, { Name = "LanternGlow", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = cf * CFrame.new(0.9, 3.5, 0.2), Material = M.Neon, Color = Color3.fromRGB(255, 196, 120), CastShadow = false })
	part(m, { Name = "LanternCap", Size = Vector3.new(0.75, 0.16, 0.75), CFrame = cf * CFrame.new(0.9, 3.78, 0.2) * CFrame.Angles(0, math.rad(45), 0), Material = M.Slate, Color = Color3.fromRGB(110, 106, 100) })
	part(m, { Name = "HammerHead", Size = Vector3.new(0.5, 0.2, 0.2), CFrame = cf * CFrame.new(0.2, 3.11, -0.6) * CFrame.Angles(0, -0.4, 0), Material = M.Metal, Color = Color3.fromRGB(110, 112, 118) })
	part(m, { Name = "HammerGrip", Size = Vector3.new(0.12, 0.12, 0.9), CFrame = cf * CFrame.new(0.32, 3.08, -0.3) * CFrame.Angles(0, -0.4, 0), Material = M.Wood, Color = dark })
	part(m, { Name = "Offcut", Size = Vector3.new(1.2, 0.18, 0.4), CFrame = cf * CFrame.new(1.4, 3.09, -0.55) * CFrame.Angles(0, 0.5, 0), Material = M.WoodPlanks, Color = wood:Lerp(Color3.new(1, 1, 1), 0.1) })
	Builders.interact(m, cf * CFrame.new(0, 3.6, 0), "Island", "Decor", "Decorate", "Decor Workbench")
	m.PrimaryPart = m:FindFirstChild("Top")
	m.Parent = parent
	return m
end

-- An island plot: the props on a player's floating island (the landmass is Builders.Landmass).
-- cf: island centre at ground height, +Z pointing at the Village. Holds the name board, the stand
-- where the owner spawns, and a small gate back to the Village. The tree is placed by TreeService.
function Builders.Plot(index, cf)
	local m = newModel("Plot" .. index, cf, Vector3.new(4, 1, 4))
	local R = Config.Map.IslandRadius
	-- name board on two posts near the Village-facing edge
	local boardCf = cf * CFrame.new(10, 0, R - 9) * CFrame.Angles(0, math.rad(-20), 0)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, { Name = "Post", Size = Vector3.new(0.5, 6, 0.5), CFrame = boardCf * CFrame.new(sx * 3.2, 3, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 70, 50), CanCollide = true })
	end
	local board = part(m, { Name = "Board", Size = Vector3.new(7, 2.2, 0.3), CFrame = boardCf * CFrame.new(0, 5, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 116, 80) })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Sign"
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "Owner"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "Empty island"
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
		label.TextColor3 = Color3.fromRGB(255, 244, 220)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
	end
	part(m, { Name = "Stand", Size = Vector3.new(2, 0.2, 2), CFrame = cf * CFrame.new(0, 1, 9), Transparency = 1, CastShadow = false })
	-- walk-up interactables either side of the spawn stand, well away from the tree (island-local
	-- (17, 6) and (-17, 6)): the storage chest (Bag) and the decor workbench, both facing the path
	local function faceStand(x, z)
		local at = cf * CFrame.new(x, 0, z)
		return CFrame.lookAt(at.Position, (cf * CFrame.new(0, 0, z + 2)).Position)
	end
	Builders.Chest(m, faceStand(17, 6))
	Builders.Workbench(m, faceStand(-17, 6))
	-- the way back: a small gate at the island edge facing the Village
	local gate = Builders.Gate("VillageGate", cf * CFrame.new(-12, 0, R - 8) * CFrame.Angles(0, math.rad(20), 0), "VILLAGE", Color3.fromRGB(150, 255, 190))
	gate:ScaleTo(0.6)
	gate:SetAttribute("TravelTo", "Hub")
	gate.Parent = m
	return m
end

-- A gate arch with a swirling portal pane; touching "Portal" travels (WorldService handles it)
function Builders.Gate(name, cf, label, color)
	local m = newModel(name, cf, Vector3.new(2, 2, 2))
	local stone = Color3.fromRGB(120, 118, 110)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, { Name = "Pillar", Size = Vector3.new(3, 18, 3), CFrame = cf * CFrame.new(sx * 8, 9, 0), Material = Enum.Material.Slate, Color = stone, CanCollide = true })
		part(m, { Name = "Cap", Size = Vector3.new(3.6, 1, 3.6), CFrame = cf * CFrame.new(sx * 8, 18.5, 0), Material = Enum.Material.Slate, Color = stone:Lerp(Color3.new(0, 0, 0), 0.15) })
	end
	part(m, { Name = "Lintel", Size = Vector3.new(21, 2.2, 3.4), CFrame = cf * CFrame.new(0, 20, 0), Material = Enum.Material.Slate, Color = stone })
	part(m, { Name = "Roof", Class = "WedgePart", Size = Vector3.new(23, 2, 2.2), CFrame = cf * CFrame.new(0, 22.1, -1.1) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 90, 80) })
	part(m, { Name = "Roof2", Class = "WedgePart", Size = Vector3.new(23, 2, 2.2), CFrame = cf * CFrame.new(0, 22.1, 1.1), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 90, 80) })
	part(m, { Name = "Portal", Size = Vector3.new(12.9, 16.6, 0.4), CFrame = cf * CFrame.new(0, 9.4, 0), Material = Enum.Material.Neon, Color = color, Transparency = 0.55, CanTouch = true, CastShadow = false })
	local sign = part(m, { Name = "SignBoard", Size = Vector3.new(10, 2, 0.3), CFrame = cf * CFrame.new(0, 20, -1.86), Material = Enum.Material.Wood, Color = Color3.fromRGB(60, 46, 36) })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.Parent = sign
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = label
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
		t.TextColor3 = Color3.fromRGB(240, 220, 160)
		t.Parent = gui
	end
	return m
end

-- An ellipsoid: a Part with a Sphere SpecialMesh stretched to its size (organic rock and earth
-- shapes from parts; the mesh renders the part's material). Collision is the box, so these are
-- decoration only (CanCollide off) unless asked.
function Builders.blob(parent, cf, size, material, color, props)
	local p = part(parent, { Name = "Rock", Size = size, CFrame = cf, Material = material, Color = color })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end
local blob = Builders.blob

local ROCK = Color3.fromRGB(104, 100, 94)
local SLATE = Color3.fromRGB(84, 86, 88)
local EARTH = Color3.fromRGB(110, 84, 60)
local GRASS = Color3.fromRGB(92, 132, 76)

-- A floating landmass from parts (no terrain): a walkable grass disc whose top is at top.Y, an earth
-- lip around the rim, and a rock cone under it (shrinking, drifting ellipsoid tiers + lumps + a
-- hanging tip). Everything but the grass sits below the grass top, so nothing pokes through.
-- opts: Grass (Color3), Seed. Returns the model.
function Builders.Landmass(name, top, radius, opts)
	opts = opts or {}
	local rng = Random.new(opts.Seed or 1)
	local m = Instance.new("Model")
	m.Name = name
	part(m, { Name = "Ground", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, radius * 2, radius * 2),
		CFrame = CFrame.new(top - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Grass, Color = opts.Grass or GRASS, CanCollide = true, CanQuery = true })
	-- earth lip: a ring of flattened ellipsoids just under the grass edge
	local lips = math.max(10, math.floor(radius / 3))
	for i = 1, lips do
		local a = i / lips * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local w = radius * 0.55 + rng:NextNumber(0, 4)
		local cf = CFrame.new(top + Vector3.new(math.cos(a) * (radius - w * 0.32), -3.2 - rng:NextNumber(0, 0.6), math.sin(a) * (radius - w * 0.32))) * CFrame.Angles(0, -a, 0)
		blob(m, cf, Vector3.new(w * 0.7, 4.4, w), Enum.Material.Ground, EARTH:Lerp(ROCK, rng:NextNumber(0, 0.3)))
	end
	-- rock cone
	local x, z = top.X, top.Z
	local tiers = math.max(4, math.floor(radius / 7))
	local depth = radius * 0.9 + 10
	for k = 1, tiers do
		local t = k / tiers
		local r = radius * (1 - t * 0.85) + 1.5
		x += rng:NextNumber(-1.5, 1.5)
		z += rng:NextNumber(-1.5, 1.5)
		local y = top.Y - 3 - t * depth * 0.8
		local h = depth / tiers * 2.2
		blob(m, CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Vector3.new(r * 2, h, r * 2 * rng:NextNumber(0.85, 1)), Enum.Material.Rock, (k % 3 == 0) and SLATE or ROCK)
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local lr = math.clamp(r * 0.45, 2, 9)
			blob(m, CFrame.new(x + math.cos(a) * r * 0.7, y - h * 0.15, z + math.sin(a) * r * 0.7) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)),
				Vector3.new(lr * 2, lr * 1.6, lr * 1.4), Enum.Material.Rock, ROCK:Lerp(SLATE, rng:NextNumber()))
		end
	end
	local tip = math.max(2.5, radius * 0.12)
	blob(m, CFrame.new(x, top.Y - 3 - depth * 0.9, z), Vector3.new(tip * 2, tip * 3.2, tip * 2), Enum.Material.Slate, SLATE)
	-- a few boulders on top near the rim, half buried (these collide)
	for _ = 1, math.floor(radius / 12) + 1 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = radius * rng:NextNumber(0.72, 0.88)
		local bs = rng:NextNumber(2.5, 4.5)
		blob(m, CFrame.new(top + Vector3.new(math.cos(a) * d, bs * 0.18, math.sin(a) * d)) * CFrame.Angles(0, a, 0.2),
			Vector3.new(bs * 1.4, bs, bs * 1.2), Enum.Material.Rock, ROCK, { CanCollide = true })
	end
	return m
end

-- ===================================================================== the Village (buildings and props)
-- A xianxia village on the Village island, parts only: white plaster walls on stone bases, dark
-- timber frames, red lacquer posts, grey-teal clay tile roofs with upturned eaves. Each NPC
-- (Config.Npcs) gets their place behind their spot: the Elder's hall, Lan's herb stall, Rui's hunting
-- camp, Old Bao's forge, Sister Hua's spirit shrine, Fat Jin's market stall and Kai's stable.
-- Every NPC spot keeps a 7-stud clear circle and a clear line to the plaza. NPC stand points are
-- marked by map.NpcSpots.NpcSpot_<Id> (ground point, facing the plaza).
-- Z-fighting: every detail layer sits at its own depth (>= 0.02 apart), nothing stacks flush.
function Builders.Village(map, G)
	local H = {} -- helpers (kept in a table: Builders is near the 200-locals limit)
	local folder = Instance.new("Model")
	folder.Name = "Buildings"
	local village = map:FindFirstChild("Village") or map
	folder.Parent = village

	local C = {
		Plaster = Color3.fromRGB(236, 230, 216),
		Timber = Color3.fromRGB(70, 50, 38),
		Lacquer = Color3.fromRGB(150, 40, 34),
		Tile = Color3.fromRGB(72, 88, 90),
		TileDark = Color3.fromRGB(52, 64, 66),
		Stone = Color3.fromRGB(128, 124, 116),
		Wood = Color3.fromRGB(122, 88, 60),
		Plank = Color3.fromRGB(150, 116, 80),
		Paper = Color3.fromRGB(244, 232, 200),
		Gold = Color3.fromRGB(214, 170, 70),
		Canvas = Color3.fromRGB(196, 176, 140),
		Hay = Color3.fromRGB(214, 182, 100),
		Soil = Color3.fromRGB(86, 64, 46),
		Clay = Color3.fromRGB(176, 100, 70),
		Lantern = Color3.fromRGB(255, 190, 120),
		Iron = Color3.fromRGB(70, 72, 76),
	}
	local M = Enum.Material

	-- decorative part (no collision, no queries) / solid part
	function H.d(parent, name, size, cf, mat, color, extra)
		local props = { Name = name, Size = size, CFrame = cf, Material = mat, Color = color }
		for k, v in pairs(extra or {}) do
			props[k] = v
		end
		return part(parent, props)
	end
	function H.s(parent, name, size, cf, mat, color, extra)
		local p = H.d(parent, name, size, cf, mat, color, extra)
		p.CanCollide = true
		p.CanQuery = true
		return p
	end
	-- vertical cylinder (axis X rotated up), ground-based: bottom at cf.Y
	function H.post(parent, name, cf, radius, height, mat, color, solid)
		local p = (solid and H.s or H.d)(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), mat, color, { Shape = Enum.PartType.Cylinder })
		return p
	end
	function H.model(name, parent)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parent or folder
		return m
	end
	-- frame at a ground point, -Z (LookVector) facing the plaza centre
	function H.facing(pos)
		local p = G + Vector3.new(pos.X, 0, pos.Z)
		local c = Vector3.new(G.X, G.Y, G.Z)
		if (p - c).Magnitude < 0.1 then
			return CFrame.new(p)
		end
		return CFrame.lookAt(p, c)
	end
	-- point light
	function H.light(p, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness or 1
		l.Shadows = false
		l.Parent = p
		return l
	end
	function H.sign(p, text, face, color)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face or Enum.NormalId.Front
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = text
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
		t.TextColor3 = color or Color3.fromRGB(245, 225, 170)
		t.Parent = gui
	end

	-- ------------------------------------------------------------- roofs
	-- Gable roof with upturned eaves over a w x d footprint whose wall top is at height top (local).
	-- cf: footprint centre at ground, front = -Z. pitch in degrees. overX/overZ: overhangs.
	function H.roof(m, cf, w, d, top, o)
		o = o or {}
		local pitch = math.rad(o.Pitch or 30)
		local overX, overZ = o.OverX or 1.4, o.OverZ or 1.6
		local tile, ridgeColor = o.Tile or C.Tile, o.Ridge or C.TileDark
		local dd = d / 2 + overZ
		local riseRidge = (d / 2) * math.tan(pitch)
		local yRidge = top + riseRidge
		local L = dd / math.cos(pitch)
		local thick = 0.5
		for _, sz in ipairs({ -1, 1 }) do
			-- slope line: from the ridge (z = 0, y = yRidge) down to the eave (z = sz*dd)
			local mid = Vector3.new(0, yRidge - (dd / 2) * math.tan(pitch), sz * dd / 2)
			local rot = CFrame.Angles(sz * pitch, 0, 0)
			local c = cf * CFrame.new(mid) * rot * CFrame.new(0, thick / 2, 0)
			H.s(m, "Roof", Vector3.new(w + overX * 2, thick, L), c, M.ClayRoofTiles, tile)
			-- eave board under the roof edge (a darker fascia, 0.04 lower than the tiles)
			local eave = cf * CFrame.new(0, yRidge - dd * math.tan(pitch) - 0.04, sz * (dd - 0.25)) * rot
			H.d(m, "Fascia", Vector3.new(w + overX * 2 + 0.1, 0.3, 0.5), eave * CFrame.new(0, -0.1, 0), M.Wood, C.Timber)
			-- upturned eave tips at both corners (tall side outward)
			for _, sx in ipairs({ -1, 1 }) do
				local tip = cf * CFrame.new(sx * (w / 2 + overX - 0.45), yRidge - dd * math.tan(pitch) + 0.55, sz * (dd + 0.35))
				local yaw = (sz < 0) and math.pi or 0
				H.d(m, "EaveTip", Vector3.new(0.7, 1.2, 1.5), tip * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-12), 0, 0), M.ClayRoofTiles, ridgeColor, { Class = "WedgePart" })
			end
		end
		-- ridge with curled ends
		H.d(m, "Ridge", Vector3.new(w + overX * 2 + 0.6, 0.85, 0.85), cf * CFrame.new(0, yRidge + 0.38, 0), M.ClayRoofTiles, ridgeColor, { Shape = Enum.PartType.Cylinder })
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "RidgeHorn", Vector3.new(0.6, 1.3, 1.3), cf * CFrame.new(sx * (w / 2 + overX + 0.5), yRidge + 0.95, 0) * CFrame.Angles(0, sx * math.rad(90), 0), M.ClayRoofTiles, ridgeColor, { Class = "WedgePart" })
		end
		-- gable triangles (recessed 0.1 inside the wall line)
		if not o.NoGable then
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local yaw = (sz > 0) and math.pi or 0
					H.d(m, "Gable", Vector3.new(0.3, riseRidge, d / 2), cf * CFrame.new(sx * (w / 2 - 0.25), top + riseRidge / 2, sz * d / 4) * CFrame.Angles(0, yaw, 0), M.Plaster, C.Plaster, { Class = "WedgePart" })
				end
			end
		end
		return yRidge
	end

	-- lattice window on a wall face. cf: wall face centre point frame with -Z pointing out of the wall.
	-- layer depths (outward): paper 0.02..0.12, lattice 0.04..0.20 / 0.06..0.17, frame 0.01..0.23 / 0.03..0.25
	function H.window(m, cf, w, h)
		H.d(m, "Paper", Vector3.new(w, h, 0.10), cf * CFrame.new(0, 0, -0.07), M.Fabric, C.Paper)
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "WinFrame", Vector3.new(0.3, h + 0.6, 0.22), cf * CFrame.new(sx * (w / 2 + 0.15), 0, -0.12), M.Wood, C.Timber)
		end
		for _, sy in ipairs({ -1, 1 }) do
			H.d(m, "WinFrame", Vector3.new(w, 0.3, 0.22), cf * CFrame.new(0, sy * (h / 2 + 0.15), -0.14), M.Wood, C.Timber)
		end
		H.d(m, "Lattice", Vector3.new(0.14, h - 0.04, 0.16), cf * CFrame.new(0, 0, -0.12), M.Wood, C.Timber)
		H.d(m, "Lattice", Vector3.new(w - 0.04, 0.14, 0.11), cf * CFrame.new(0, 0, -0.115), M.Wood, C.Timber)
	end

	-- ------------------------------------------------------------- house
	-- cf: ground centre, front (-Z) facing the plaza. o: Posts (colour), Door, Windows, Porch
	function H.house(name, cf, w, d, h, o)
		o = o or {}
		local m = H.model(name)
		local y0 = 0.8
		H.s(m, "Base", Vector3.new(w + 1.2, 1.0, d + 1.2), cf * CFrame.new(0, 0.3, 0), M.Slate, C.Stone)
		H.s(m, "Walls", Vector3.new(w, h, d), cf * CFrame.new(0, y0 + h / 2, 0), M.Plaster, C.Plaster)
		local postColor = o.Posts or C.Timber
		local postMat = o.Posts and M.SmoothPlastic or M.Wood
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				H.d(m, "Post", Vector3.new(0.9, h + 0.2, 0.9), cf * CFrame.new(sx * w / 2, y0 + h / 2 + 0.05, sz * d / 2), postMat, postColor)
			end
		end
		-- timber bands: top and sill on every side (side bands 0.03 higher so corners never share a face)
		for _, sz in ipairs({ -1, 1 }) do
			H.d(m, "Beam", Vector3.new(w - 0.1, 0.45, 0.3), cf * CFrame.new(0, y0 + h - 0.25, sz * (d / 2 + 0.1)), M.Wood, C.Timber)
			H.d(m, "Sill", Vector3.new(w - 0.1, 0.4, 0.28), cf * CFrame.new(0, y0 + 0.22, sz * (d / 2 + 0.09)), M.Wood, C.Timber)
		end
		for _, sx in ipairs({ -1, 1 }) do
			-- 0.02 below the front/back beams' top, and clear of the wall top
			H.d(m, "Beam", Vector3.new(0.3, 0.45, d - 0.1), cf * CFrame.new(sx * (w / 2 + 0.1), y0 + h - 0.27, 0), M.Wood, C.Timber)
			H.d(m, "Sill", Vector3.new(0.28, 0.4, d - 0.1), cf * CFrame.new(sx * (w / 2 + 0.09), y0 + 0.25, 0), M.Wood, C.Timber)
		end
		-- door (front, -Z)
		local fz = -(d / 2)
		local doorH = math.min(5, h - 1.6)
		H.d(m, "Door", Vector3.new(3, doorH, 0.2), cf * CFrame.new(0, y0 + 0.45 + doorH / 2, fz - 0.1), M.WoodPlanks, Color3.fromRGB(96, 60, 40))
		H.d(m, "DoorLintel", Vector3.new(4.2, 0.55, 0.36), cf * CFrame.new(0, y0 + 0.45 + doorH + 0.27, fz - 0.18), o.Posts and M.SmoothPlastic or M.Wood, postColor)
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "Jamb", Vector3.new(0.55, doorH + 0.3, 0.34), cf * CFrame.new(sx * 1.78, y0 + 0.3 + doorH / 2, fz - 0.17), o.Posts and M.SmoothPlastic or M.Wood, postColor)
			H.d(m, "DoorRing", Vector3.new(0.3, 0.3, 0.1), cf * CFrame.new(sx * 0.45, y0 + 0.45 + doorH * 0.55, fz - 0.25), M.Metal, C.Gold)
		end
		-- windows: two on the front when wide enough, one on each side
		local wy = y0 + h * 0.55
		if w >= 11 then
			for _, sx in ipairs({ -1, 1 }) do
				H.window(m, cf * CFrame.new(sx * (w / 4 + 1), wy, fz), 2.4, 2.2)
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			H.window(m, cf * CFrame.new(sx * (w / 2), wy, 0) * CFrame.Angles(0, sx * math.rad(-90), 0), 2.2, 2)
		end
		local yRidge = H.roof(m, cf, w, d, y0 + h, o.Roof)
		-- eave brackets under the front eave at the posts
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "Bracket", Vector3.new(0.5, 0.6, 1.3), cf * CFrame.new(sx * w / 2, y0 + h - 0.32, fz - 0.78), M.Wood, postColor)
		end
		return m, yRidge
	end

	-- ------------------------------------------------------------- small props
	function H.crate(parent, cf, s)
		H.s(parent, "Crate", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), M.WoodPlanks, C.Plank)
		-- banding sits 0.04 proud on two opposite faces only
		H.d(parent, "CrateBand", Vector3.new(s + 0.08, 0.25, s * 0.6), cf * CFrame.new(0, s * 0.5, 0), M.Wood, C.Timber)
	end
	function H.sack(parent, cf, s, color)
		blob(parent, cf * CFrame.new(0, s * 0.45, 0), Vector3.new(s, s * 0.95, s * 0.85), M.Fabric, color or Color3.fromRGB(196, 176, 130))
		blob(parent, cf * CFrame.new(0, s * 0.95, 0), Vector3.new(s * 0.35, s * 0.3, s * 0.35), M.Fabric, (color or Color3.fromRGB(196, 176, 130)):Lerp(Color3.new(0, 0, 0), 0.15))
	end
	function H.lanternHang(parent, pos, color, lit)
		local l = blob(parent, CFrame.new(pos), Vector3.new(1.1, 1.5, 1.1), M.Neon, color or C.Lantern)
		l.Transparency = 0.12
		H.d(parent, "LanternCap", Vector3.new(0.25, 0.7, 0.7), CFrame.new(pos + Vector3.new(0, 0.82, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Wood, C.Timber, { Shape = Enum.PartType.Cylinder })
		H.d(parent, "LanternCap", Vector3.new(0.2, 0.6, 0.6), CFrame.new(pos - Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), M.Wood, C.Timber, { Shape = Enum.PartType.Cylinder })
		if lit then
			H.light(l, color or C.Lantern, 9, 0.9)
		end
		return l
	end
	-- a post with an arm and a hanging lantern
	function H.lanternPost(cf, lit)
		local m = H.model("LanternPost")
		H.s(m, "Post", Vector3.new(0.5, 7, 0.5), cf * CFrame.new(0, 3.5, 0), M.Wood, C.Timber)
		H.d(m, "Arm", Vector3.new(0.3, 0.3, 2.3), cf * CFrame.new(0, 6.7, -1.0), M.Wood, C.Timber)
		H.d(m, "Chain", Vector3.new(0.08, 0.7, 0.08), cf * CFrame.new(0, 6.2, -1.9), M.Metal, C.Iron)
		H.lanternHang(m, (cf * CFrame.new(0, 5.0, -1.9)).Position, C.Lantern, lit)
	end
	function H.bench(cf)
		local m = H.model("Bench")
		H.s(m, "Seat", Vector3.new(5, 0.3, 1.4), cf * CFrame.new(0, 1.5, 0), M.WoodPlanks, C.Plank)
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "Leg", Vector3.new(0.4, 1.4, 1.2), cf * CFrame.new(sx * 2, 0.7, 0), M.Wood, C.Timber)
		end
		H.d(m, "Back", Vector3.new(5, 1.1, 0.25), cf * CFrame.new(0, 2.3, 0.62) * CFrame.Angles(math.rad(-10), 0, 0), M.WoodPlanks, C.Plank)
	end
	function H.flowerBed(cf, w, d, seed)
		local m = H.model("FlowerBed")
		local rng = Random.new(seed)
		for _, sz in ipairs({ -1, 1 }) do
			H.d(m, "Border", Vector3.new(w, 0.6, 0.3), cf * CFrame.new(0, 0.3, sz * (d / 2 - 0.15)), M.Wood, C.Wood)
		end
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "Border", Vector3.new(0.3, 0.62, d - 0.6), cf * CFrame.new(sx * (w / 2 - 0.15), 0.31, 0), M.Wood, C.Wood)
		end
		H.d(m, "Soil", Vector3.new(w - 0.6, 0.45, d - 0.6), cf * CFrame.new(0, 0.225, 0), M.Ground, C.Soil)
		local colors = { Color3.fromRGB(240, 120, 140), Color3.fromRGB(250, 220, 110), Color3.fromRGB(200, 150, 240), Color3.fromRGB(255, 255, 240), Color3.fromRGB(250, 150, 90) }
		for i = 1, math.floor(w * d / 2.2) do
			local x = rng:NextNumber(-w / 2 + 0.7, w / 2 - 0.7)
			local z = rng:NextNumber(-d / 2 + 0.7, d / 2 - 0.7)
			local hgt = rng:NextNumber(0.5, 1.1)
			H.d(m, "Stem", Vector3.new(0.1, hgt, 0.1), cf * CFrame.new(x, 0.45 + hgt / 2, z), M.SmoothPlastic, Color3.fromRGB(70, 120, 60))
			local s = rng:NextNumber(0.45, 0.7)
			H.d(m, "Flower", Vector3.new(s, s, s), cf * CFrame.new(x, 0.45 + hgt + s * 0.3, z), M.SmoothPlastic, colors[(i % #colors) + 1], { Shape = Enum.PartType.Ball })
		end
	end
	-- fence along a line from a to b (ground points), posts every ~3 studs, two rails
	function H.fence(parent, a, b, color)
		local dir = (b - a)
		local len = dir.Magnitude
		local n = math.max(1, math.floor(len / 3))
		local cf = CFrame.lookAt(a, b)
		for i = 0, n do
			H.s(parent, "FencePost", Vector3.new(0.4, 2.6, 0.4), cf * CFrame.new(0, 1.3, -len * i / n), M.Wood, color or C.Wood)
		end
		for k, y in ipairs({ 1.0, 2.0 }) do
			-- rails 0.06 apart in depth so the two never share a plane
			H.s(parent, "FenceRail", Vector3.new(0.2, 0.28, len), cf * CFrame.new(0.1 + k * 0.03, y, -len / 2), M.Wood, (color or C.Wood):Lerp(Color3.new(0, 0, 0), 0.08))
		end
	end
	function H.banner(cf, color, trim)
		local m = H.model("Banner")
		H.post(m, "Pole", cf, 0.22, 10, M.Wood, C.Lacquer, true)
		H.d(m, "Crossbar", Vector3.new(2.8, 0.2, 0.2), cf * CFrame.new(0.9, 9.4, 0), M.Wood, C.Lacquer)
		H.d(m, "Cloth", Vector3.new(2.2, 5.2, 0.1), cf * CFrame.new(1.2, 6.7, 0), M.Fabric, color)
		H.d(m, "Trim", Vector3.new(2.3, 0.3, 0.16), cf * CFrame.new(1.2, 4.15, 0), M.Fabric, trim or C.Gold)
		H.d(m, "Emblem", Vector3.new(1.0, 1.0, 0.14), cf * CFrame.new(1.2, 7.3, 0) * CFrame.Angles(0, 0, math.rad(45)), M.Fabric, trim or C.Gold)
	end

	-- ============================================================= the places, one per NPC
	-- NPC stand points come from Config.Npcs; these copies only cover a Config that predates them
	local npcs = Config.Npcs or {
		Elder = { Pos = Vector3.new(-12, 0, -8) }, Herbalist = { Pos = Vector3.new(-40, 0, 26) },
		Huntress = { Pos = Vector3.new(-20, 0, -50) }, Smith = { Pos = Vector3.new(42, 0, -26) },
		SpiritKeeper = { Pos = Vector3.new(-44, 0, -22) }, Merchant = { Pos = Vector3.new(42, 0, 24) },
		Stablehand = { Pos = Vector3.new(20, 0, -52) },
	}
	local function npcFrame(id, dist)
		local n = npcs[id]
		local p = n and n.Pos or Vector3.new(0, 0, 0)
		local dir = Vector3.new(p.X, 0, p.Z)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1)
		return H.facing(p + dir * dist)
	end

	-- --- Elder's hall: the biggest building, west of the plaza, with a porch and red posts
	do
		local cf = H.facing(Vector3.new(-86, 0, 2))
		local m = H.house("ElderHall", cf, 22, 13, 8, { Posts = C.Lacquer, Roof = { Pitch = 28, OverX = 1.6, OverZ = 2 } })
		-- porch under the front eave: steps, red pillars with a beam, a name board, lanterns, banners
		local pz = -(13 / 2 + 1.6)
		H.s(m, "Step", Vector3.new(9, 0.4, 1.6), cf * CFrame.new(0, 0.2, -(13 / 2 + 1.4)), M.Slate, C.Stone)
		for _, sx in ipairs({ -1, 1 }) do
			H.post(m, "PorchPillar", cf * CFrame.new(sx * 5.2, 0.4, pz), 0.42, 7.2, M.SmoothPlastic, C.Lacquer, true)
			H.d(m, "PillarBase", Vector3.new(1.4, 0.5, 1.4), cf * CFrame.new(sx * 5.2, 0.45, pz), M.Slate, C.Stone)
			H.lanternHang(m, (cf * CFrame.new(sx * 3.3, 5.6, pz)).Position, C.Lantern, sx < 0)
			H.d(m, "LanternString", Vector3.new(0.06, 1.0, 0.06), cf * CFrame.new(sx * 3.3, 6.95, pz), M.Fabric, C.Canvas)
			-- long banners on the front wall, clear of the windows
			H.d(m, "WallBanner", Vector3.new(1.4, 4.6, 0.1), cf * CFrame.new(sx * 9.6, 4.6, -(13 / 2 + 0.05)), M.Fabric, C.Lacquer)
			H.d(m, "WallBannerTrim", Vector3.new(1.5, 0.28, 0.16), cf * CFrame.new(sx * 9.6, 2.4, -(13 / 2 + 0.1)), M.Fabric, C.Gold)
		end
		H.d(m, "PorchBeam", Vector3.new(11.6, 0.55, 0.6), cf * CFrame.new(0, 7.5, pz), M.SmoothPlastic, C.Lacquer)
		local board = H.d(m, "NameBoard", Vector3.new(5, 1.2, 0.25), cf * CFrame.new(0, 7.55, -(13 / 2 + 0.13)), M.WoodPlanks, Color3.fromRGB(40, 32, 28))
		H.sign(board, "ELDER'S HALL", Enum.NormalId.Front)
		H.flowerBed(cf * CFrame.new(-8.5, 0, -(13 / 2 + 3.6)), 4, 2, 11)
		H.flowerBed(cf * CFrame.new(8.5, 0, -(13 / 2 + 3.6)), 4, 2, 12)
	end

	-- --- Lan's herb stall: counter with a green awning, drying racks, pots and a fenced garden
	do
		local cf = npcFrame("Herbalist", 18)
		local m = H.model("HerbStall")
		H.s(m, "Counter", Vector3.new(8, 3, 2.2), cf * CFrame.new(0, 1.5, -3), M.WoodPlanks, C.Plank)
		H.d(m, "CounterTop", Vector3.new(8.4, 0.25, 2.6), cf * CFrame.new(0, 3.125, -3), M.Wood, C.Timber)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				H.post(m, "StallPost", cf * CFrame.new(sx * 4.4, 0, -3 + sz * 1.5), 0.2, 6.4, M.Wood, C.Timber)
			end
		end
		H.d(m, "Awning", Vector3.new(9.6, 0.15, 4.6), cf * CFrame.new(0, 6.6, -3.2) * CFrame.Angles(math.rad(-14), 0, 0), M.Fabric, Color3.fromRGB(96, 140, 90))
		H.d(m, "AwningFringe", Vector3.new(9.6, 0.5, 0.12), cf * CFrame.new(0, 6.0, -5.5), M.Fabric, Color3.fromRGB(230, 220, 170))
		-- herbs and jars on the counter
		local rng = Random.new(21)
		for i = 1, 6 do
			local x = -3.2 + i * 0.95
			if i % 2 == 0 then
				H.d(m, "Jar", Vector3.new(0.8, 0.7, 0.7), cf * CFrame.new(x, 3.25 + 0.4, -3 + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, 0, math.rad(90)), M.Glass, Color3.fromRGB(150, 200, 170), { Shape = Enum.PartType.Cylinder, Transparency = 0.3 })
			else
				blob(m, cf * CFrame.new(x, 3.25 + 0.3, -3 + rng:NextNumber(-0.4, 0.4)), Vector3.new(0.9, 0.55, 0.7), M.LeafyGrass, Color3.fromRGB(100, 150, 80))
			end
		end
		-- drying rack: two A-frames and a bar with hanging bundles
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				limb(m, (cf * CFrame.new(sx * 3.2, 0, 3 + sz * 0.9)).Position, (cf * CFrame.new(sx * 3.2, 4.4, 3)).Position, 0.15, { Name = "RackLeg", Material = M.Wood, Color = C.Wood })
			end
		end
		H.d(m, "RackBar", Vector3.new(7, 0.25, 0.25), cf * CFrame.new(0, 4.3, 3), M.Wood, C.Wood)
		for i = 1, 6 do
			local x = -2.6 + (i - 1) * 1.04
			H.d(m, "String", Vector3.new(0.06, 0.6, 0.06), cf * CFrame.new(x, 3.9, 3), M.Fabric, C.Canvas)
			blob(m, cf * CFrame.new(x, 3.1, 3) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(0.6, 1.3, 0.5), M.LeafyGrass, Color3.fromRGB(110, 130, 70):Lerp(Color3.fromRGB(150, 110, 60), rng:NextNumber(0, 0.5)))
		end
		-- clay pots with plants
		for i = 1, 5 do
			local x = -6.5 + i * 2.2 + rng:NextNumber(-0.3, 0.3)
			local s = rng:NextNumber(1.1, 1.6)
			H.post(m, "Pot", cf * CFrame.new(x, 0, 7.5 + rng:NextNumber(-0.6, 0.6)), s / 2, s * 0.9, M.SmoothPlastic, C.Clay, true)
			blob(m, cf * CFrame.new(x, s * 0.9 + 0.4, 7.5), Vector3.new(s * 1.1, s * 0.9, s * 1.1), M.LeafyGrass, Color3.fromRGB(86, 140, 80))
		end
		-- garden bed with a low fence
		H.flowerBed(cf * CFrame.new(-8.5, 0, 1), 3.4, 6, 31)
		H.fence(m, (cf * CFrame.new(-11, 0, -2.5)).Position, (cf * CFrame.new(-11, 0, 10)).Position)
		H.fence(m, (cf * CFrame.new(-11, 0, 10.6)).Position, (cf * CFrame.new(9, 0, 10.6)).Position)
		local sign = H.d(m, "Sign", Vector3.new(4.4, 1.0, 0.2), cf * CFrame.new(0, 7.2, -5.65), M.WoodPlanks, Color3.fromRGB(56, 76, 52))
		H.sign(sign, "HERBS", Enum.NormalId.Front)
	end

	-- --- Rui's hunting camp: canvas tent, weapon rack, pelts on a frame, a campfire with log seats
	do
		local cf = npcFrame("Huntress", 18)
		local m = H.model("HuntCamp")
		-- tent (A-frame, door toward the plaza)
		local tcf = cf * CFrame.new(-5, 0, 4)
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "TentSide", Vector3.new(0.2, 5.4, 7), tcf * CFrame.new(sx * 1.85, 2.2, 0) * CFrame.Angles(0, 0, sx * math.rad(38)), M.Fabric, C.Canvas)
		end
		limb(m, (tcf * CFrame.new(0, 4.35, -3.8)).Position, (tcf * CFrame.new(0, 4.35, 3.8)).Position, 0.15, { Name = "TentPole", Material = M.Wood, Color = C.Wood })
		for _, sz in ipairs({ -1, 1 }) do
			limb(m, (tcf * CFrame.new(0, 0, sz * 3.6)).Position + Vector3.new(0, 0.01, 0), (tcf * CFrame.new(0, 4.4, sz * 3.6)).Position, 0.13, { Name = "TentPost", Material = M.Wood, Color = C.Wood })
		end
		-- back wall triangle
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "TentBack", Vector3.new(0.15, 4.2, 3.2), tcf * CFrame.new(sx * 0.8, 2.1, 3.4) * CFrame.Angles(0, -sx * math.rad(90), 0), M.Fabric, C.Canvas:Lerp(Color3.new(0, 0, 0), 0.1), { Class = "WedgePart" })
		end
		-- weapon rack with spears
		local rcf = cf * CFrame.new(5.5, 0, 5)
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "RackPost", Vector3.new(0.35, 3.6, 0.35), rcf * CFrame.new(sx * 2.2, 1.8, 0), M.Wood, C.Wood)
		end
		H.d(m, "RackRail", Vector3.new(4.8, 0.25, 0.3), rcf * CFrame.new(0, 3.2, 0), M.Wood, C.Wood)
		H.d(m, "RackRail", Vector3.new(4.8, 0.25, 0.32), rcf * CFrame.new(0, 0.9, 0.04), M.Wood, C.Wood)
		for i = 1, 4 do
			local x = -1.6 + (i - 1) * 1.05
			limb(m, (rcf * CFrame.new(x, 0.1, 0.5)).Position, (rcf * CFrame.new(x + 0.2, 5.2, -0.3)).Position, 0.09, { Name = "Spear", Material = M.Wood, Color = C.Wood })
			H.d(m, "SpearHead", Vector3.new(0.12, 0.8, 0.35), rcf * CFrame.new(x + 0.21, 5.55, -0.36) * CFrame.Angles(math.rad(-9), 0, 0), M.Metal, Color3.fromRGB(190, 194, 200), { Class = "WedgePart" })
		end
		-- pelt drying frame
		local pcf = cf * CFrame.new(0, 0, 9)
		for _, sx in ipairs({ -1, 1 }) do
			H.post(m, "FramePost", pcf * CFrame.new(sx * 3, 0, 0), 0.2, 5, M.Wood, C.Wood, true)
		end
		H.d(m, "FrameBar", Vector3.new(6.6, 0.3, 0.3), pcf * CFrame.new(0, 4.8, 0), M.Wood, C.Wood)
		blob(m, pcf * CFrame.new(-1.4, 3.2, 0.1) * CFrame.Angles(0, 0, math.rad(4)), Vector3.new(2.4, 3.0, 0.2), M.Fabric, Color3.fromRGB(122, 92, 66))
		blob(m, pcf * CFrame.new(1.5, 3.3, 0.18) * CFrame.Angles(0, 0, math.rad(-6)), Vector3.new(2.2, 2.6, 0.2), M.Fabric, Color3.fromRGB(130, 130, 134))
		-- campfire: stone ring, crossed logs, a flame and a warm light
		local fcf = cf * CFrame.new(2, 0, -1)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			blob(m, fcf * CFrame.new(math.cos(a) * 1.5, 0.25, math.sin(a) * 1.5), Vector3.new(0.8, 0.55, 0.7), M.Rock, C.Stone)
		end
		for i = 1, 3 do
			local a = i / 3 * math.pi
			limb(m, (fcf * CFrame.new(math.cos(a) * 1.1, 0.25 + i * 0.05, math.sin(a) * 1.1)).Position, (fcf * CFrame.new(-math.cos(a) * 1.1, 0.25 + i * 0.05, -math.sin(a) * 1.1)).Position, 0.2, { Name = "Log", Material = M.Wood, Color = Color3.fromRGB(80, 56, 40) })
		end
		local flame = blob(m, fcf * CFrame.new(0, 1.0, 0), Vector3.new(0.9, 1.4, 0.9), M.Neon, Color3.fromRGB(255, 150, 60))
		flame.Transparency = 0.15
		H.light(flame, Color3.fromRGB(255, 160, 80), 10, 1.2)
		local att = Instance.new("Attachment")
		att.Parent = flame
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = Config.Particles.Fire
		fire.Rate = 6
		fire.Lifetime = NumberRange.new(0.5, 0.9)
		fire.Speed = NumberRange.new(2, 4)
		fire.SpreadAngle = Vector2.new(12, 12)
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 90, 40))
		fire.LightEmission = 1
		fire.EmissionDirection = Enum.NormalId.Top
		fire.Parent = att
		for _, sx in ipairs({ -1, 1 }) do
			limb(m, (fcf * CFrame.new(sx * 3.2, 0.6, -1.4)).Position, (fcf * CFrame.new(sx * 3.4, 0.6, 1.6)).Position, 0.55, { Name = "LogSeat", Material = M.Wood, Color = Color3.fromRGB(100, 72, 50), CanCollide = true })
		end
	end

	-- --- Old Bao's forge: an open shed with a brick hearth, glowing coals, chimney, anvil and barrel
	do
		local cf = npcFrame("Smith", 18)
		local m = H.model("Forge")
		local w, d, h = 12, 9, 6.5
		H.s(m, "Floor", Vector3.new(w + 1, 0.6, d + 1), cf * CFrame.new(0, 0.1, 0), M.Slate, C.Stone)
		-- back wall (brick) and four timber posts
		H.s(m, "BackWall", Vector3.new(w, h, 0.8), cf * CFrame.new(0, 0.4 + h / 2, d / 2 - 0.4), M.Brick, Color3.fromRGB(140, 90, 70))
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "Post", Vector3.new(0.7, h + 0.4, 0.7), cf * CFrame.new(sx * (w / 2 - 0.35), 0.4 + h / 2 + 0.2, -(d / 2 - 0.35)), M.Wood, C.Timber)
		end
		-- single slope roof, high at the back
		H.s(m, "ShedRoof", Vector3.new(w + 2, 0.45, d + 2.4), cf * CFrame.new(0, 0.4 + h + 0.9, 0.2) * CFrame.Angles(math.rad(12), 0, 0), M.ClayRoofTiles, C.Tile)
		-- hearth with coals and embers
		local hcf = cf * CFrame.new(-2.5, 0, d / 2 - 2.2)
		H.s(m, "Hearth", Vector3.new(4.2, 2.6, 2.8), hcf * CFrame.new(0, 0.4 + 1.3, 0), M.Brick, Color3.fromRGB(120, 80, 64))
		local coal = blob(m, hcf * CFrame.new(0, 0.4 + 2.6 + 0.08, 0), Vector3.new(2.8, 0.55, 1.8), M.Neon, Color3.fromRGB(255, 110, 40))
		coal.Transparency = 0.05
		H.light(coal, Color3.fromRGB(255, 130, 60), 9, 1.4)
		local ea = Instance.new("Attachment")
		ea.Parent = coal
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = Config.Particles.Square
		embers.Rate = 3
		embers.Lifetime = NumberRange.new(1, 2)
		embers.Speed = NumberRange.new(2, 5)
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.Acceleration = Vector3.new(0, 1.5, 0)
		embers.Size = NumberSequence.new(0.14, 0.02)
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 30))
		embers.LightEmission = 1
		embers.Rotation = NumberRange.new(0, 360)
		embers.RotSpeed = NumberRange.new(-120, 120)
		embers.Parent = ea
		-- chimney through the roof
		H.s(m, "Chimney", Vector3.new(2.2, 13, 2.2), hcf * CFrame.new(0, 0.4 + 2.6 + 6.5, 0.6), M.Brick, Color3.fromRGB(120, 80, 64))
		H.d(m, "ChimneyCap", Vector3.new(2.8, 0.5, 2.8), hcf * CFrame.new(0, 0.4 + 2.6 + 13.25, 0.6), M.Slate, C.Stone)
		-- anvil
		local acf = cf * CFrame.new(2.2, 0.4, -0.5) * CFrame.Angles(0, math.rad(15), 0)
		H.s(m, "AnvilBase", Vector3.new(1.4, 1.4, 1.2), acf * CFrame.new(0, 0.7, 0), M.Metal, C.Iron)
		H.d(m, "AnvilWaist", Vector3.new(0.8, 0.5, 0.7), acf * CFrame.new(0, 1.65, 0), M.Metal, C.Iron)
		H.d(m, "AnvilTop", Vector3.new(2.6, 0.6, 1.0), acf * CFrame.new(0, 2.2, 0), M.Metal, Color3.fromRGB(86, 88, 92))
		H.d(m, "AnvilHorn", Vector3.new(0.9, 0.6, 1.1), acf * CFrame.new(1.75, 2.2, 0) * CFrame.Angles(0, math.rad(-90), 0), M.Metal, Color3.fromRGB(86, 88, 92), { Class = "WedgePart" })
		H.d(m, "Hammer", Vector3.new(0.12, 1.3, 0.12), acf * CFrame.new(-0.6, 2.56, 0.1) * CFrame.Angles(0, 0, math.rad(80)), M.Wood, C.Wood)
		H.d(m, "HammerHead", Vector3.new(0.5, 0.4, 0.4), acf * CFrame.new(-1.25, 2.68, 0.1), M.Metal, C.Iron)
		-- quench barrel and a rack of blades on the wall
		H.post(m, "Barrel", cf * CFrame.new(4.2, 0.4, 2), 0.9, 2.0, M.WoodPlanks, C.Plank, true)
		H.d(m, "BarrelWater", Vector3.new(0.1, 1.5, 1.5), cf * CFrame.new(4.2, 0.4 + 1.86, 2) * CFrame.Angles(0, 0, math.rad(90)), M.Glass, Color3.fromRGB(70, 110, 130), { Shape = Enum.PartType.Cylinder, Transparency = 0.2 })
		for i = 1, 3 do
			local x = 1 + i * 1.1
			H.d(m, "WallBlade", Vector3.new(0.3, 3.2, 0.12), cf * CFrame.new(x, 3.6, d / 2 - 0.86 - i * 0.02) * CFrame.Angles(0, 0, math.rad(4 - i * 3)), M.Metal, Color3.fromRGB(180, 184, 190))
		end
		local sign = H.d(m, "Sign", Vector3.new(4.4, 1.0, 0.2), cf * CFrame.new(0, h + 0.2, -(d / 2 - 0.6)), M.WoodPlanks, Color3.fromRGB(60, 44, 34))
		H.sign(sign, "FORGE", Enum.NormalId.Front)
	end

	-- --- Sister Hua's spirit shrine: a stone platform, a red pavilion, an altar with a spirit stone,
	-- paper lanterns and a slow incense curl
	do
		local cf = npcFrame("SpiritKeeper", 18)
		local m = H.model("SpiritShrine")
		H.s(m, "Platform", Vector3.new(10, 0.8, 10), cf * CFrame.new(0, 0.4, 0), M.Slate, Color3.fromRGB(150, 150, 146))
		H.s(m, "Step", Vector3.new(6, 0.4, 1.4), cf * CFrame.new(0, 0.2, -5.7), M.Slate, Color3.fromRGB(140, 140, 136))
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				H.post(m, "Pillar", cf * CFrame.new(sx * 3.8, 0.8, sz * 3.8), 0.32, 6.6, M.SmoothPlastic, C.Lacquer, true)
			end
		end
		for _, sz in ipairs({ -1, 1 }) do
			H.d(m, "Lintel", Vector3.new(8.6, 0.5, 0.5), cf * CFrame.new(0, 7.15, sz * 3.8), M.SmoothPlastic, C.Lacquer)
		end
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "Lintel", Vector3.new(0.5, 0.5, 8.6), cf * CFrame.new(sx * 3.8, 7.18, 0), M.SmoothPlastic, C.Lacquer)
		end
		H.roof(m, cf, 7.6, 7.6, 7.4, { Pitch = 34, OverX = 1.4, OverZ = 1.5, Tile = Color3.fromRGB(64, 96, 100), NoGable = false })
		-- altar and spirit stone
		H.s(m, "Altar", Vector3.new(3.2, 1.6, 1.6), cf * CFrame.new(0, 0.8 + 0.8, 1.6), M.Wood, Color3.fromRGB(90, 50, 40))
		H.d(m, "AltarCloth", Vector3.new(3.3, 0.12, 1.7), cf * CFrame.new(0, 0.8 + 1.66, 1.6), M.Fabric, C.Gold)
		local stone = blob(m, cf * CFrame.new(0, 0.8 + 1.72 + 0.6, 1.6), Vector3.new(0.9, 1.2, 0.9), M.Neon, Color3.fromRGB(130, 220, 230))
		stone.Transparency = 0.15
		H.light(stone, Color3.fromRGB(130, 220, 230), 8, 0.8)
		H.post(m, "Incense", cf * CFrame.new(0, 0.8, -1.4), 0.45, 0.8, M.Metal, Color3.fromRGB(150, 120, 60), true)
		local ia = Instance.new("Attachment")
		ia.Parent = H.d(m, "IncenseTip", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 1.75, -1.4), M.Neon, Color3.fromRGB(255, 150, 80))
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = Config.Particles.Smoke
		smoke.Rate = 1.5
		smoke.Lifetime = NumberRange.new(3, 4)
		smoke.Speed = NumberRange.new(0.6, 1.2)
		smoke.Size = NumberSequence.new(0.3, 1.2)
		smoke.Transparency = NumberSequence.new(0.6, 1)
		smoke.Color = ColorSequence.new(Color3.fromRGB(230, 230, 236))
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Parent = ia
		-- paper lanterns at the roof corners, pale cyan for the spirits
		for i, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local pos = (cf * CFrame.new(sx * 4.5, 5.6, sz * 4.5)).Position
				H.d(m, "LanternString", Vector3.new(0.06, 1.1, 0.06), CFrame.new(pos + Vector3.new(0, 1.35, 0)), M.Fabric, C.Canvas)
				H.lanternHang(m, pos, Color3.fromRGB(200, 240, 246), i == 1 and sz < 0)
			end
		end
	end

	-- --- Fat Jin's market stall: striped awning, crates, sacks, fruit on the counter
	do
		local cf = npcFrame("Merchant", 18)
		local m = H.model("MarketStall")
		H.s(m, "Counter", Vector3.new(9, 3, 2.2), cf * CFrame.new(0, 1.5, -3), M.WoodPlanks, C.Plank)
		H.d(m, "CounterTop", Vector3.new(9.4, 0.25, 2.6), cf * CFrame.new(0, 3.125, -3), M.Wood, C.Timber)
		H.d(m, "CounterCloth", Vector3.new(9.1, 1.4, 0.1), cf * CFrame.new(0, 2.2, -4.15), M.Fabric, C.Lacquer)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				H.post(m, "StallPost", cf * CFrame.new(sx * 4.9, 0, -3 + sz * 1.6), 0.22, 6.8, M.SmoothPlastic, C.Lacquer)
			end
		end
		-- striped awning: alternating strips, each a hair apart in height so tops never share a plane
		for i = 1, 7 do
			local x = -4.8 + (i - 0.5) * (10.4 / 7) - 0.4
			local col = (i % 2 == 0) and Color3.fromRGB(240, 226, 190) or Color3.fromRGB(190, 60, 50)
			H.d(m, "Awning", Vector3.new(10.4 / 7, 0.15, 5), cf * CFrame.new(x + 0.4, 7.0 + (i % 2) * 0.03, -3.3) * CFrame.Angles(math.rad(-15), 0, 0), M.Fabric, col)
		end
		-- fruit (peaches, of course) and a scale on the counter
		local rng = Random.new(41)
		for i = 1, 7 do
			local s = rng:NextNumber(0.45, 0.6)
			H.d(m, "Peach", Vector3.new(s, s, s), cf * CFrame.new(-3.6 + i * 0.5, 3.25 + s / 2, -3.2 + rng:NextNumber(-0.5, 0.5)), M.SmoothPlastic, Color3.fromRGB(255, 160, 120):Lerp(Color3.fromRGB(240, 110, 90), rng:NextNumber()), { Shape = Enum.PartType.Ball })
		end
		H.d(m, "ScaleBase", Vector3.new(1.2, 0.3, 0.8), cf * CFrame.new(2.6, 3.4, -3), M.Metal, C.Gold)
		H.d(m, "ScalePole", Vector3.new(0.1, 1.2, 0.1), cf * CFrame.new(2.6, 4.15, -3), M.Metal, C.Gold)
		H.d(m, "ScaleBar", Vector3.new(1.6, 0.08, 0.06), cf * CFrame.new(2.6, 4.75, -3), M.Metal, C.Gold)
		-- crates (varied sizes, turned) and sacks
		H.crate(m, cf * CFrame.new(-5.8, 0, 1.8) * CFrame.Angles(0, math.rad(12), 0), 1.8)
		H.crate(m, cf * CFrame.new(-3.6, 0, 2.6) * CFrame.Angles(0, math.rad(-20), 0), 1.5)
		H.crate(m, cf * CFrame.new(-5.6, 1.8, 1.9) * CFrame.Angles(0, math.rad(37), 0), 1.2)
		H.sack(m, cf * CFrame.new(4.2, 0, 2.2), 1.4)
		H.sack(m, cf * CFrame.new(5.6, 0, 1.4) * CFrame.Angles(0, 0.6, 0), 1.2, Color3.fromRGB(170, 150, 110))
		H.sack(m, cf * CFrame.new(3.2, 0, 3.4), 1.1)
		H.lanternHang(m, (cf * CFrame.new(-4.4, 5.6, -4.6)).Position, C.Lantern, true)
		local sign = H.d(m, "Sign", Vector3.new(5, 1.1, 0.2), cf * CFrame.new(0, 8.1, -1.4), M.WoodPlanks, Color3.fromRGB(60, 40, 30))
		H.sign(sign, "JIN'S GOODS", Enum.NormalId.Front)
	end

	-- --- Kai's stable: paddock fence, a shed with hay, a trough and an old horse
	do
		local cf = npcFrame("Stablehand", 16)
		local m = H.model("Stable")
		-- shed at the back
		local w, d, h = 12, 5, 6
		local scf = cf * CFrame.new(0, 0, 8)
		H.s(m, "ShedBack", Vector3.new(w, h, 0.5), scf * CFrame.new(0, h / 2, d / 2), M.WoodPlanks, C.Plank)
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "ShedSide", Vector3.new(0.5, h, d - 0.5), scf * CFrame.new(sx * (w / 2 - 0.25), h / 2, 0), M.WoodPlanks, C.Plank:Lerp(Color3.new(0, 0, 0), 0.06))
			H.post(m, "ShedPost", scf * CFrame.new(sx * (w / 2 - 0.3), 0, -d / 2 + 0.3), 0.25, h + 0.4, M.Wood, C.Timber, true)
		end
		H.s(m, "ShedRoof", Vector3.new(w + 1.6, 0.4, d + 2.2), scf * CFrame.new(0, h + 0.75, -0.2) * CFrame.Angles(math.rad(14), 0, 0), M.RoofShingles, Color3.fromRGB(90, 80, 70))
		-- hay bales
		local rng = Random.new(61)
		for i = 1, 3 do
			H.s(m, "Hay", Vector3.new(2.4, 1.3, 1.5), scf * CFrame.new(-4 + i * 2.6, 0.65 + (i == 2 and 0 or 0), rng:NextNumber(-0.5, 0.8)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0), M.Fabric, C.Hay)
		end
		H.s(m, "Hay", Vector3.new(2.2, 1.2, 1.4), scf * CFrame.new(-1.3, 1.95, 0.4) * CFrame.Angles(0, 0.4, 0), M.Fabric, C.Hay:Lerp(Color3.new(1, 1, 1), 0.08))
		-- paddock fence (open toward the plaza)
		local function p(x, z)
			return (cf * CFrame.new(x, 0, z)).Position
		end
		H.fence(m, p(-8, -4), p(-8, 10.8))
		H.fence(m, p(8, 10.8), p(8, -4))
		H.fence(m, p(-7.4, -4.2), p(-3.2, -4.2))
		H.fence(m, p(3.2, -4.2), p(7.4, -4.2))
		-- trough
		local tcf = cf * CFrame.new(5.2, 0, 2) * CFrame.Angles(0, math.rad(90), 0)
		H.d(m, "TroughBottom", Vector3.new(4.6, 0.3, 1.06), tcf * CFrame.new(0, 0.17, 0), M.WoodPlanks, C.Plank)
		for _, sz in ipairs({ -1, 1 }) do
			H.s(m, "TroughSide", Vector3.new(5, 1.2, 0.25), tcf * CFrame.new(0, 0.6, sz * 0.675), M.WoodPlanks, C.Plank)
		end
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "TroughEnd", Vector3.new(0.25, 1.18, 1.1), tcf * CFrame.new(sx * 2.36, 0.59, 0), M.WoodPlanks, C.Plank)
		end
		H.d(m, "TroughWater", Vector3.new(4.4, 0.15, 1.1), tcf * CFrame.new(0, 0.95, 0), M.Glass, Color3.fromRGB(80, 120, 140), { Transparency = 0.2 })
		-- an old horse in the paddock (the Old Horse mount's look)
		local ok, horse = pcall(Builders.Mount, "Horse")
		if ok and horse then
			horse:PivotTo(cf * CFrame.new(-2.5, 0, 2) * CFrame.Angles(0, math.rad(70), 0)) -- pivot on the ground
			horse.Name = "StableHorse"
			for _, x in ipairs(horse:GetDescendants()) do
				if x:IsA("BasePart") then
					x.CanCollide = false
					x.CanQuery = false
				end
			end
			horse.Parent = m
		end
		local sign = H.d(m, "Sign", Vector3.new(4.4, 1.0, 0.2), scf * CFrame.new(0, h - 0.6, -d / 2 + 0.15), M.WoodPlanks, Color3.fromRGB(60, 44, 34))
		H.sign(sign, "STABLE", Enum.NormalId.Front)
	end

	-- ============================================================= houses around the edge
	H.house("HouseEast", H.facing(Vector3.new(86, 0, 2)), 13, 9, 7, {})
	H.flowerBed(H.facing(Vector3.new(86, 0, 2)) * CFrame.new(-4.3, 0, -6.8), 3, 1.6, 71)
	H.house("HouseSouthEast", H.facing(Vector3.new(42, 0, 74)), 12, 9, 6.5, { Posts = C.Lacquer })
	H.flowerBed(H.facing(Vector3.new(42, 0, 74)) * CFrame.new(4, 0, -6.8), 3, 1.6, 72)
	H.house("HouseSouthWest", H.facing(Vector3.new(-38, 0, 74)), 12, 9, 6.5, {})
	H.flowerBed(H.facing(Vector3.new(-38, 0, 74)) * CFrame.new(-4, 0, -6.8), 3, 1.6, 73)
	H.house("Storehouse", H.facing(Vector3.new(72, 0, -62)), 10, 8, 6, { Roof = { Pitch = 26 } })
	H.crate(folder, H.facing(Vector3.new(72, 0, -62)) * CFrame.new(-4.2, 0, -6.2) * CFrame.Angles(0, 0.3, 0), 1.6)
	H.sack(folder, H.facing(Vector3.new(72, 0, -62)) * CFrame.new(4, 0, -6.4), 1.3)

	-- ============================================================= plaza dressing
	-- the well (east of the shrine)
	do
		local m = H.model("Well")
		local cf = CFrame.new(G + Vector3.new(26, 0, -2))
		H.s(m, "WellRing", Vector3.new(2.4, 6, 6), cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Cobblestone, C.Stone, { Shape = Enum.PartType.Cylinder })
		H.d(m, "WellRim", Vector3.new(0.3, 6.4, 6.4), cf * CFrame.new(0, 2.55, 0) * CFrame.Angles(0, 0, math.rad(90)), M.Slate, Color3.fromRGB(110, 108, 100), { Shape = Enum.PartType.Cylinder })
		H.d(m, "WellDark", Vector3.new(0.1, 4.6, 4.6), cf * CFrame.new(0, 2.75, 0) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, Color3.fromRGB(20, 26, 30), { Shape = Enum.PartType.Cylinder })
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "WellPost", Vector3.new(0.45, 5.6, 0.45), cf * CFrame.new(sx * 2.6, 2.8, 0), M.Wood, C.Timber)
		end
		H.d(m, "Crank", Vector3.new(5.6, 0.35, 0.35), cf * CFrame.new(0, 4.2, 0), M.Wood, C.Wood, { Shape = Enum.PartType.Cylinder })
		H.d(m, "Rope", Vector3.new(0.08, 1.2, 0.08), cf * CFrame.new(0.4, 3.5, 0), M.Fabric, C.Canvas)
		H.post(m, "Bucket", cf * CFrame.new(0.4, 2.3, 0), 0.4, 0.6, M.WoodPlanks, C.Plank)
		H.roof(m, cf * CFrame.new(0, 0, 0), 5.2, 2.6, 5.6, { Pitch = 32, OverX = 0.5, OverZ = 0.8, NoGable = true })
	end
	-- quest notice board near the spawn side of the plaza
	do
		local cf = H.facing(Vector3.new(-15, 0, 38))
		local m = H.model("QuestBoard")
		for _, sx in ipairs({ -1, 1 }) do
			H.s(m, "BoardPost", Vector3.new(0.6, 6.4, 0.6), cf * CFrame.new(sx * 3.4, 3.2, 0), M.Wood, C.Timber)
		end
		local board = H.s(m, "Board", Vector3.new(6.2, 3.8, 0.3), cf * CFrame.new(0, 3.5, 0), M.WoodPlanks, C.Plank)
		local title = H.d(m, "Title", Vector3.new(4.6, 0.9, 0.2), cf * CFrame.new(0, 5.95, -0.07), M.WoodPlanks, Color3.fromRGB(56, 40, 30))
		H.sign(title, "QUESTS", Enum.NormalId.Front)
		local rng = Random.new(81)
		local spots = { { -2.0, 4.4 }, { -0.3, 4.6 }, { 1.6, 4.3 }, { -1.3, 2.6 }, { 0.8, 2.5 }, { 2.3, 2.8 } }
		for i, s in ipairs(spots) do
			H.d(m, "Note", Vector3.new(1.3, 1.5, 0.05), cf * CFrame.new(s[1], s[2], -(0.175 + i * 0.03)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), M.Fabric, C.Paper:Lerp(Color3.fromRGB(220, 200, 160), rng:NextNumber(0, 0.6)))
			H.d(m, "Pin", Vector3.new(0.18, 0.18, 0.1), cf * CFrame.new(s[1], s[2] + 0.55, -(0.21 + i * 0.03 + 0.03)), M.SmoothPlastic, C.Lacquer)
		end
		H.roof(m, cf, 6.8, 1.4, 6.0, { Pitch = 34, OverX = 0.5, OverZ = 0.6, NoGable = true })
		board:SetAttribute("QuestBoard", true)
	end
	-- benches, lantern posts and banners around the plaza
	for _, a in ipairs({ 0, 180, 60 }) do
		local r = math.rad(a)
		H.bench(H.facing(Vector3.new(math.cos(r) * 38, 0, math.sin(r) * 38)))
	end
	local lit = 0
	for _, a in ipairs({ 45, 135, 225, 315 }) do
		local r = math.rad(a)
		lit += 1
		H.lanternPost(H.facing(Vector3.new(math.cos(r) * 49, 0, math.sin(r) * 49)), lit <= 4)
	end
	for _, zz in ipairs({ -30, -60, 30, 60 }) do
		local sx = (zz % 60 == 0) and 9 or -9
		-- arms reach over the path
		H.lanternPost(CFrame.new(G + Vector3.new(sx, 0, zz)) * CFrame.Angles(0, (sx > 0) and math.rad(90) or math.rad(-90), 0), math.abs(zz) == 60)
	end
	for _, sx in ipairs({ -1, 1 }) do
		H.banner(CFrame.new(G + Vector3.new(sx * 10, 0, -46)) * CFrame.Angles(0, sx > 0 and math.pi or 0, 0), C.Lacquer, C.Gold)
		H.banner(CFrame.new(G + Vector3.new(sx * 10, 0, 46)) * CFrame.Angles(0, sx > 0 and math.pi or 0, 0), Color3.fromRGB(60, 110, 110), C.Gold)
	end

	-- ============================================================= paths, more homes, trees
	-- dirt paths from the plaza edge out to each place (tops 0.025 up: under the plaza's 0.06,
	-- clear of the gate paths' 0.03/0.045, and radial so they never overlap each other outside it)
	local paths = H.model("DirtPaths")
	local function dirtPath(angleDeg, r0, r1, width)
		local a = math.rad(angleDeg)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p0, p1 = G + dir * r0, G + dir * r1
		local cf = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, 0.025 - 0.2, 0)
		H.s(paths, "DirtPath", Vector3.new(width or 4, 0.4, (p1 - p0).Magnitude), cf, M.Ground, Color3.fromRGB(128, 104, 78))
	end
	for id, n in pairs(npcs) do
		local p = n.Pos
		local dist = Vector3.new(p.X, 0, p.Z).Magnitude
		if dist > 30 then
			dirtPath(math.deg(math.atan2(p.Z, p.X)), 44, dist + 6)
		end
	end
	dirtPath(180, 44, 76, 5) -- to the Elder's hall
	dirtPath(2, 44, 79, 3.2) -- east house
	-- a second ring of homes
	H.house("HouseWest", H.facing(Vector3.new(-72, 0, 50)), 12, 8.5, 6.5, { Roof = { Pitch = 32 } })
	H.house("HouseNorthWest", H.facing(Vector3.new(-66, 0, -64)), 11, 8.5, 6.5, { Posts = C.Lacquer })
	H.house("HouseNorthEast", H.facing(Vector3.new(74, 0, 50)), 12, 9, 6.8, {})
	H.flowerBed(H.facing(Vector3.new(-72, 0, 50)) * CFrame.new(3.8, 0, -6.6), 3, 1.6, 74)
	H.flowerBed(H.facing(Vector3.new(74, 0, 50)) * CFrame.new(-3.8, 0, -6.8), 3, 1.6, 75)
	-- cherry trees (the placeholder tree, pink, scaled down) dotted between the places
	local trng = Random.new(91)
	for _, pos in ipairs({ Vector3.new(30, 0, 44), Vector3.new(-30, 0, -40), Vector3.new(54, 0, -6), Vector3.new(-56, 0, 8), Vector3.new(-48, 0, 54), Vector3.new(70, 0, 22) }) do
		local t = Builders.Tree(1, CFrame.new(G + pos) * CFrame.Angles(0, trng:NextNumber(0, 6.28), 0))
		for _, v in ipairs(t:GetDescendants()) do
			if v.Name == "Vein" or v.Name == "Flower" then
				v:Destroy()
			elseif v:IsA("BasePart") then
				if v.Name == "Canopy" then
					v.Color = Color3.fromRGB(246, 178, 196):Lerp(Color3.fromRGB(255, 220, 230), trng:NextNumber(0, 0.6))
				end
				if v.Name ~= "Collider" then
					v.CanCollide = false
				end
			end
		end
		t:ScaleTo(trng:NextNumber(0.4, 0.5))
		t.Name = "CherryTree"
		t.Parent = folder
	end
	-- stone lanterns along the island-gate path, and a hand cart by the market
	for _, zz in ipairs({ 52, 66 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local m = H.model("StoneLantern")
			local cf = CFrame.new(G + Vector3.new(sx * 8.2, 0, zz))
			H.s(m, "Base", Vector3.new(1.4, 0.5, 1.4), cf * CFrame.new(0, 0.25, 0), M.Slate, C.Stone)
			H.s(m, "Shaft", Vector3.new(0.6, 2.2, 0.6), cf * CFrame.new(0, 1.6, 0), M.Slate, C.Stone)
			H.d(m, "Box", Vector3.new(1.2, 1.0, 1.2), cf * CFrame.new(0, 3.2, 0), M.Slate, C.Stone)
			H.d(m, "Glow", Vector3.new(0.8, 0.6, 1.24), cf * CFrame.new(0, 3.2, 0), M.Neon, C.Lantern)
			H.d(m, "Cap", Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(0, 3.9, 0) * CFrame.Angles(0, math.rad(45), 0), M.Slate, C.Stone)
		end
	end
	do
		local m = H.model("Cart")
		local cf = H.facing(Vector3.new(58, 0, 12)) * CFrame.Angles(0, math.rad(70), 0)
		H.s(m, "Bed", Vector3.new(3.2, 0.4, 5), cf * CFrame.new(0, 1.6, 0), M.WoodPlanks, C.Plank)
		for _, sx in ipairs({ -1, 1 }) do
			H.d(m, "Rail", Vector3.new(0.25, 0.8, 5), cf * CFrame.new(sx * 1.48, 2.2, 0), M.Wood, C.Wood)
			H.d(m, "Wheel", Vector3.new(0.3, 2.6, 2.6), cf * CFrame.new(sx * 1.85, 1.3, 0.6), M.Wood, C.Timber, { Shape = Enum.PartType.Cylinder })
			limb(m, (cf * CFrame.new(sx * 0.8, 1.6, -2.4)).Position, (cf * CFrame.new(sx * 0.6, 0.4, -5.2)).Position, 0.12, { Name = "Handle", Material = M.Wood, Color = C.Wood })
		end
		H.sack(m, cf * CFrame.new(0.5, 1.8, 1.2), 1.1)
		H.crate(m, cf * CFrame.new(-0.4, 1.8, -1.0) * CFrame.Angles(0, 0.3, 0), 1.2)
	end

	-- ============================================================= walk-up interactables
	-- Spirit Summoning Shrine beside Sister Hua (ground centre (-50, -10), radius ~6.2): a slate
	-- circle with an inset glowing rune ring, four short pillars with floating spirit orbs and a
	-- central altar holding a spirit flame. Layers: disc top 0.40, inner dais top 0.43, runes top 0.46.
	do
		local cf = H.facing(Vector3.new(-50, 0, -10))
		local m = H.model("SummoningShrine")
		local glow = Color3.fromRGB(150, 220, 255)
		local disc = function(name, r, h, y, mat, color, solid)
			return (solid and H.s or H.d)(m, name, Vector3.new(h, r * 2, r * 2), cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), mat, color, { Shape = Enum.PartType.Cylinder })
		end
		disc("Circle", 5, 0.4, 0.2, M.Slate, Color3.fromRGB(120, 124, 128), true)
		disc("Dais", 3.8, 0.06, 0.4, M.Slate, Color3.fromRGB(72, 80, 92))
		-- outer rune ring: 20 glowing glyph blocks with gaps, alternating sizes so it isn't uniform
		for i = 1, 20 do
			local a = i / 20 * math.pi * 2
			local len = (i % 3 == 0) and 0.9 or 0.6
			H.d(m, "Rune", Vector3.new(0.18, 0.08, len), cf * CFrame.Angles(0, a, 0) * CFrame.new(4.4, 0.42, 0) * CFrame.Angles(0, math.rad(90), 0), M.Neon, glow, { CastShadow = false })
		end
		-- radial glyph lines on the dais (start outside the altar so they never cross)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + 0.3
			H.d(m, "Glyph", Vector3.new(2.2, 0.06, 0.12), cf * CFrame.Angles(0, a, 0) * CFrame.new(2.4, 0.43, 0), M.Neon, glow:Lerp(Color3.new(1, 1, 1), 0.2), { CastShadow = false })
		end
		-- central altar: plinth, top slab and a hovering spirit flame
		H.s(m, "Altar", Vector3.new(1.5, 1.8, 1.5), cf * CFrame.new(0, 1.3, 0), M.Slate, Color3.fromRGB(140, 140, 136))
		H.d(m, "AltarTop", Vector3.new(1.9, 0.25, 1.9), cf * CFrame.new(0, 2.32, 0) * CFrame.Angles(0, math.rad(45), 0), M.Slate, Color3.fromRGB(110, 110, 108))
		local flame = H.d(m, "SpiritFlame", Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(0, 3.4, 0), M.Neon, glow, { Shape = Enum.PartType.Ball, CastShadow = false })
		H.light(flame, glow, 10, 1.4)
		local a0 = Instance.new("Attachment")
		a0.Parent = flame
		local e = Instance.new("ParticleEmitter")
		e.Texture = Config.Particles.Spark -- real spirit magic (Playbook 06 exception)
		e.Color = ColorSequence.new(glow)
		e.LightEmission = 1
		e.Rate = 4
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(0.6, 1.4)
		e.SpreadAngle = Vector2.new(30, 30)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = a0
		-- four short pillars just outside the circle, each with a floating orb
		for i = 1, 4 do
			local a = (i - 0.5) / 4 * math.pi * 2
			local pcf = cf * CFrame.Angles(0, a, 0) * CFrame.new(5.6, 0, 0)
			H.post(m, "Pillar", pcf, 0.45, 3.2, M.Slate, Color3.fromRGB(150, 146, 140), true)
			H.d(m, "PillarCap", Vector3.new(1.3, 0.3, 1.3), pcf * CFrame.new(0, 3.35, 0) * CFrame.Angles(0, math.rad(45), 0), M.Slate, Color3.fromRGB(120, 118, 114))
			H.d(m, "PillarBand", Vector3.new(0.2, 0.98, 0.98), pcf * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)), M.SmoothPlastic, C.Lacquer, { Shape = Enum.PartType.Cylinder })
			H.d(m, "Orb", Vector3.new(0.6, 0.6, 0.6), pcf * CFrame.new(0, 4.4 + (i % 2) * 0.3, 0), M.Neon, glow:Lerp(Color3.fromRGB(200, 170, 255), (i % 2) * 0.5), { Shape = Enum.PartType.Ball, CastShadow = false })
		end
		Builders.interact(m, cf * CFrame.new(0, 3, 0), "Spirits", "Summon", "Summon", "Summoning Shrine")
	end
	-- Hall of Fame at the plaza edge by the island-gate path (centre (-24, 54), ~30 x 3): the game's
	-- leaderboards as three tall stone steles (user: physical leaderboards, no UI button). Each has a
	-- dark inset face with a SurfaceGui "Board": title, "TOP 10" and ten rows of Rank / Name / Value
	-- frames that the client fills from workspace.Boards (Interact). Face 0.04 proud of the slab,
	-- trims 0.03 proud of the face.
	do
		local cf = H.facing(Vector3.new(-24, 0, 54))
		local m = H.model("HallOfFame")
		local stone = Color3.fromRGB(150, 146, 136)
		local W, Hh, D = 7, 10.5, 0.9 -- face width / height, slab depth
		local boards = { { "CP", "POWER" }, { "Tree", "TREE LEVEL" }, { "Likes", "ISLAND LIKES" } }
		local montserrat = "rbxasset://fonts/families/Montserrat.json"
		for i, b in ipairs(boards) do
			local x = (i - 2) * 10 -- 10 apart: neighbouring cap tips must not cross (they share a plane)
			local scf = cf * CFrame.new(x, 0, 0)
			local top = 1 + Hh + 0.8
			H.s(m, "Plinth", Vector3.new(W + 1.6, 0.8, D + 1.4), scf * CFrame.new(0, 0.4, 0), M.Slate, stone:Lerp(Color3.new(0, 0, 0), 0.15))
			H.s(m, "Slab", Vector3.new(W + 0.8, Hh + 1.4, D), scf * CFrame.new(0, 0.8 + (Hh + 1.4) / 2, 0), M.Slate, stone)
			local fy = 0.8 + 0.7 + Hh / 2
			local face = H.d(m, "Face", Vector3.new(W, Hh, 0.1), scf * CFrame.new(0, fy, -(D / 2 + 0.04)), M.SmoothPlastic, Color3.fromRGB(26, 42, 46))
			face:SetAttribute("Board", b[1])
			H.d(m, "TrimTop", Vector3.new(W + 0.2, 0.16, 0.12), scf * CFrame.new(0, fy + Hh / 2 + 0.08, -(D / 2 + 0.07)), M.Metal, C.Gold)
			H.d(m, "TrimBottom", Vector3.new(W + 0.2, 0.16, 0.12), scf * CFrame.new(0, fy - Hh / 2 - 0.08, -(D / 2 + 0.07)), M.Metal, C.Gold)
			-- a tiled cap with upturned ends
			H.d(m, "Cap", Vector3.new(W + 1.8, 0.5, D + 0.9), scf * CFrame.new(0, top + 0.6, 0), M.ClayRoofTiles, C.Tile)
			for _, sx in ipairs({ -1, 1 }) do
				H.d(m, "CapTip", Vector3.new(0.8, 0.35, D + 0.7), scf * CFrame.new(sx * (W / 2 + 0.9), top + 0.85, 0) * CFrame.Angles(0, 0, math.rad(sx * -25)), M.ClayRoofTiles, C.TileDark)
			end
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Board"
			gui.Face = Enum.NormalId.Front
			gui.PixelsPerStud = 60
			gui.LightInfluence = 0.15
			gui.Parent = face
			local function label(parent, name, text, size, pos, xAlign, font, color)
				local t = Instance.new("TextLabel")
				t.Name = name
				t.Size = size
				t.Position = pos
				t.BackgroundTransparency = 1
				t.Text = text
				t.TextScaled = true
				t.TextXAlignment = xAlign
				t.FontFace = font
				t.TextColor3 = color
				t.Parent = parent
				return t
			end
			label(gui, "Title", b[2], UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.025), Enum.TextXAlignment.Center,
				Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold), Color3.fromRGB(245, 215, 140))
			label(gui, "Sub", "TOP 10", UDim2.fromScale(0.9, 0.035), UDim2.fromScale(0.05, 0.115), Enum.TextXAlignment.Center,
				Font.new(montserrat, Enum.FontWeight.SemiBold), Color3.fromRGB(170, 190, 184))
			local rule = Instance.new("Frame")
			rule.Size = UDim2.fromScale(0.8, 0.004)
			rule.Position = UDim2.fromScale(0.1, 0.16)
			rule.BorderSizePixel = 0
			rule.BackgroundColor3 = Color3.fromRGB(203, 185, 140)
			rule.Parent = gui
			for r = 1, 10 do
				local row = Instance.new("Frame")
				row.Name = "Row" .. r
				row.Size = UDim2.fromScale(0.92, 0.074)
				row.Position = UDim2.fromScale(0.04, 0.18 + (r - 1) * 0.08)
				row.BackgroundColor3 = Color3.new(1, 1, 1)
				row.BackgroundTransparency = (r % 2 == 1) and 0.94 or 1
				row.BorderSizePixel = 0
				row.Parent = gui
				local text = Color3.fromRGB(226, 236, 230)
				label(row, "Rank", tostring(r), UDim2.fromScale(0.12, 0.8), UDim2.fromScale(0.02, 0.1), Enum.TextXAlignment.Center, Font.new(montserrat, Enum.FontWeight.Bold), text)
				-- "Player", not "Name": row.Name would be the frame's own Name property
				label(row, "Player", "", UDim2.fromScale(0.56, 0.7), UDim2.fromScale(0.16, 0.15), Enum.TextXAlignment.Left, Font.new(montserrat, Enum.FontWeight.SemiBold), text)
				label(row, "Value", "", UDim2.fromScale(0.26, 0.7), UDim2.fromScale(0.72, 0.15), Enum.TextXAlignment.Right, Font.new(montserrat, Enum.FontWeight.Bold), Color3.fromRGB(255, 196, 120))
			end
		end
	end
	-- prompts on the places that already exist (stall, stable, quest board): at the front centre
	for _, e in ipairs({ { "MarketStall", "Shop", nil, "Shop", "Jin's Goods", 4 }, { "Stable", "Mounts", nil, "Mounts", "Stable", 4 }, { "QuestBoard", "Quests", "Main", "Quest Log", "Quest Board", 2 },
		{ "Forge", "Forge", nil, "Forge", "Old Bao's Forge", 4 } }) do
		local mdl = folder:FindFirstChild(e[1])
		if mdl then
			local bcf, size = mdl:GetBoundingBox()
			local toCentre = (Vector3.new(G.X, bcf.Position.Y, G.Z) - bcf.Position)
			toCentre = toCentre.Magnitude > 0.1 and toCentre.Unit or Vector3.new(0, 0, 1)
			local front = bcf.Position + toCentre * math.min(e[6], math.max(size.X, size.Z) / 2)
			Builders.interact(mdl, CFrame.new(Vector3.new(front.X, G.Y + 3, front.Z)), e[2], e[3], e[4], e[5])
		end
	end

	-- ============================================================= NPC spots
	local spots = Instance.new("Folder")
	spots.Name = "NpcSpots"
	spots.Parent = map
	for id, n in pairs(npcs) do
		local cf = H.facing(n.Pos)
		local s = part(spots, { Name = "NpcSpot_" .. id, Size = Vector3.new(1, 0.2, 1), CFrame = cf, Transparency = 1, CastShadow = false })
		s:SetAttribute("NpcId", id)
	end
	return folder
end

-- ===================================================================== island decor
-- Decor pieces players buy and place on their island (Config.Decor). Builders.Decor(id) returns a
-- Model whose PrimaryPart "Root" sits at the ground centre (pivot y = ground), front facing -Z, the
-- footprint inside Config.Decor[id].Radius. Only solid things collide (bases, posts, seats, rims).
-- Moving bits (bamboo stalks, chime rods) sit in a sub-Model "Sway" with a "Sway" attribute (degrees)
-- for the client to animate. Glows are separate Neon parts with at most one small PointLight.
local D = {
	GRANITE = Color3.fromRGB(150, 146, 138),
	DARKSTONE = Color3.fromRGB(96, 94, 90),
	WOOD = Color3.fromRGB(112, 78, 52),
	DARKWOOD = Color3.fromRGB(70, 48, 34),
	RED = Color3.fromRGB(172, 42, 36),
	BLACK = Color3.fromRGB(42, 38, 36),
	BRONZE = Color3.fromRGB(150, 108, 58),
	GOLD = Color3.fromRGB(232, 184, 72),
	LEAF = Color3.fromRGB(70, 110, 62),
	WARM = Color3.fromRGB(255, 196, 120),
}

-- a box: P(model, size, cframe, material, color, props)
function D.P(m, size, cf, mat, color, props)
	local p = part(m, { Size = size, CFrame = cf, Material = mat or Enum.Material.SmoothPlastic, Color = color or D.GRANITE })
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

-- an upright cylinder centred at pos (height along Y)
function D.cyl(m, pos, height, radius, mat, color, props)
	local p = part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Material = mat or Enum.Material.SmoothPlastic, Color = color or D.GRANITE })
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

function D.light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 7
	l.Brightness = brightness or 1.2
	l.Shadows = false
	l.Parent = parent
	return l
end

function D.noShadow(parts)
	for _, p in ipairs(parts) do
		p.CastShadow = false
	end
end

D.Build = {}

-- Stone lantern (toro): base, plinth, post, light box with four corner posts, two-tier roof, finial
D.Build.StoneLantern = function(m)
	local S, G = Enum.Material.Slate, D.GRANITE
	D.P(m, Vector3.new(2.2, 0.32, 2.2), CFrame.new(0, 0.11, 0), S, D.DARKSTONE, { CanCollide = true })
	D.P(m, Vector3.new(1.5, 0.36, 1.5), CFrame.new(0, 0.44, 0), S, G, { CanCollide = true })
	D.cyl(m, Vector3.new(0, 1.32, 0), 1.44, 0.34, S, G, { CanCollide = true })
	D.P(m, Vector3.new(1.36, 0.24, 1.36), CFrame.new(0, 2.12, 0), S, G)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			D.P(m, Vector3.new(0.2, 0.86, 0.2), CFrame.new(sx * 0.48, 2.67, sz * 0.48), S, G)
		end
	end
	local core = D.P(m, Vector3.new(0.66, 0.62, 0.66), CFrame.new(0, 2.6, 0), Enum.Material.Neon, D.WARM, { Transparency = 0.15 })
	core.CastShadow = false
	D.light(core, D.WARM, 8, 1.2)
	D.P(m, Vector3.new(1.84, 0.22, 1.84), CFrame.new(0, 3.21, 0), S, D.DARKSTONE)
	D.P(m, Vector3.new(1.3, 0.26, 1.3), CFrame.new(0, 3.42, 0) * CFrame.Angles(0, math.rad(45), 0), S, D.DARKSTONE)
	-- upturned roof corners
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		D.P(m, Vector3.new(0.18, 0.18, 0.4), CFrame.new(math.cos(a) * 1.18, 3.28, math.sin(a) * 1.18) * CFrame.Angles(0, -a, 0) * CFrame.Angles(math.rad(25), 0, 0), S, D.DARKSTONE)
	end
	blob(m, CFrame.new(0, 3.72, 0), Vector3.new(0.42, 0.5, 0.42), S, G)
end

-- Paper lantern on a wooden post with an arm
D.Build.PaperLantern = function(m)
	D.P(m, Vector3.new(0.9, 0.3, 0.9), CFrame.new(0, 0.1, 0), Enum.Material.Slate, D.DARKSTONE, { CanCollide = true })
	D.cyl(m, Vector3.new(0, 2.65, 0), 4.9, 0.17, Enum.Material.Wood, D.DARKWOOD, { CanCollide = true })
	D.P(m, Vector3.new(1.24, 0.16, 0.16), CFrame.new(0.5, 4.86, 0), Enum.Material.Wood, D.DARKWOOD)
	D.P(m, Vector3.new(0.12, 0.42, 0.12), CFrame.new(0, 4.62, 0.001) * CFrame.new(0.32, 0, 0) * CFrame.Angles(0, 0, math.rad(-45)), Enum.Material.Wood, D.DARKWOOD)
	local x = 1.0
	local cord = D.P(m, Vector3.new(0.04, 0.32, 0.04), CFrame.new(x, 4.62, 0), Enum.Material.Fabric, D.BLACK)
	local cap1 = D.cyl(m, Vector3.new(x, 4.42, 0), 0.1, 0.24, Enum.Material.Wood, D.BLACK)
	local shade = blob(m, CFrame.new(x, 3.84, 0), Vector3.new(0.86, 1.1, 0.86), Enum.Material.Neon, Color3.fromRGB(210, 64, 44), { Transparency = 0.05 })
	shade.CastShadow = false
	local cap2 = D.cyl(m, Vector3.new(x, 3.27, 0), 0.1, 0.22, Enum.Material.Wood, D.BLACK)
	local tassel = D.P(m, Vector3.new(0.06, 0.42, 0.06), CFrame.new(x, 2.99, 0), Enum.Material.Fabric, Color3.fromRGB(230, 180, 60))
	D.noShadow({ cord, cap1, cap2, tassel })
	-- the ribs of the paper
	for i = 1, 2 do
		local y = 3.84 + (i - 1.5) * 0.5
		local rib = D.cyl(m, Vector3.new(x, y, 0), 0.04, 0.4 - math.abs(i - 1.5) * 0.04, Enum.Material.Wood, D.BLACK)
		rib.CastShadow = false
	end
	D.light(shade, Color3.fromRGB(255, 140, 100), 7, 1.1)
end

-- Garden bench: slatted seat, two stone legs, slatted back
D.Build.Bench = function(m)
	local W = Enum.Material.WoodPlanks
	for _, sx in ipairs({ -1, 1 }) do
		D.P(m, Vector3.new(0.3, 0.94, 1.36), CFrame.new(sx * 1.45, 0.43, 0), Enum.Material.Slate, D.DARKSTONE, { CanCollide = true })
		D.P(m, Vector3.new(0.18, 1.5, 0.16), CFrame.new(sx * 1.45, 1.62, 0.68) * CFrame.Angles(math.rad(-10), 0, 0), Enum.Material.Wood, D.DARKWOOD)
	end
	for i, z in ipairs({ -0.5, 0, 0.5 }) do
		D.P(m, Vector3.new(3.6 - i * 0.02, 0.12, 0.44), CFrame.new(0, 0.96, z), W, D.WOOD, { CanCollide = true })
	end
	for i, y in ipairs({ 1.5, 1.95 }) do
		D.P(m, Vector3.new(3.56 - i * 0.04, 0.32, 0.1), CFrame.new(0, y, 0.6 + (y - 1.5) * 0.18) * CFrame.Angles(math.rad(-10), 0, 0), W, D.WOOD)
	end
end

-- Flower bed: stone border, soil, a mix of flowers (a few glowing spirit flowers)
D.Build.FlowerBed = function(m)
	local rng = Random.new(7)
	for i = 1, 11 do
		local a = i / 11 * math.pi * 2
		blob(m, CFrame.new(math.cos(a) * 1.95, 0.14, math.sin(a) * 1.95) * CFrame.Angles(0, -a, 0), Vector3.new(0.7, 0.42, 1.25), Enum.Material.Slate, D.GRANITE:Lerp(D.DARKSTONE, rng:NextNumber()))
	end
	D.cyl(m, Vector3.new(0, 0.1, 0), 0.24, 1.86, Enum.Material.Ground, Color3.fromRGB(96, 70, 50))
	local colors = { Color3.fromRGB(236, 120, 150), Color3.fromRGB(250, 220, 110), Color3.fromRGB(240, 240, 250), Color3.fromRGB(190, 120, 220) }
	for i = 1, 13 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0.2, 1.5)
		local base = Vector3.new(math.cos(a) * d, 0.22, math.sin(a) * d)
		local h = rng:NextNumber(0.5, 0.9)
		local stem = limb(m, base, base + Vector3.new(rng:NextNumber(-0.1, 0.1), h, rng:NextNumber(-0.1, 0.1)), 0.04, { Color = D.LEAF })
		stem.CastShadow = false
		local spirit = i % 5 == 0
		local bloom = part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(base + Vector3.new(0, h + 0.05, 0)),
			Material = spirit and Enum.Material.Neon or Enum.Material.SmoothPlastic, Color = spirit and Color3.fromRGB(110, 190, 255) or colors[i % #colors + 1], CastShadow = false })
		local _ = bloom
	end
	for i = 1, 4 do
		local a = i * 1.6
		blob(m, CFrame.new(math.cos(a) * 1.0, 0.3, math.sin(a) * 1.0) * CFrame.Angles(0, a, 0), Vector3.new(0.7, 0.3, 0.45), Enum.Material.Grass, D.LEAF, { CastShadow = false })
	end
end

-- Bamboo cluster: a mound and seven jointed stalks with leaf tufts (stalks in a "Sway" sub-model)
D.Build.BambooCluster = function(m)
	blob(m, CFrame.new(0, 0.05, 0), Vector3.new(4, 0.55, 3.6), Enum.Material.Ground, Color3.fromRGB(92, 72, 52))
	local sway = Instance.new("Model")
	sway.Name = "Sway"
	sway:SetAttribute("Sway", 3)
	sway.Parent = m
	local rng = Random.new(11)
	local green = Color3.fromRGB(118, 150, 74)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local d = (i == 6) and 0 or rng:NextNumber(0.5, 1.4)
		local base = Vector3.new(math.cos(a) * d, 0.1, math.sin(a) * d)
		local h = rng:NextNumber(6.5, 9.5)
		local r = rng:NextNumber(0.13, 0.2)
		local top = base + Vector3.new(rng:NextNumber(-0.4, 0.4), h, rng:NextNumber(-0.4, 0.4))
		limb(sway, base, top, r, { Material = Enum.Material.SmoothPlastic, Color = green:Lerp(Color3.fromRGB(150, 160, 90), rng:NextNumber(0, 0.4)) })
		-- nodes
		local nodes = math.floor(h / 2.1)
		for k = 1, nodes do
			local p = base:Lerp(top, k / (nodes + 1))
			local ring = limb(sway, p - (top - base).Unit * 0.04, p + (top - base).Unit * 0.04, r + 0.03, { Color = green:Lerp(Color3.new(0, 0, 0), 0.15) })
			ring.CastShadow = false
		end
		-- drooping leaf sprays on the top third: thin blades fanning out and down from a node
		for k = 0, 1 do
			local node = base:Lerp(top, 0.78 + k * 0.14)
			local spin = rng:NextNumber(0, math.pi * 2)
			for j = 1, 3 do
				local yaw = spin + j * 2.1
				local leaf = blob(sway, CFrame.new(node) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, -0.15, -0.55) * CFrame.Angles(math.rad(-25 - k * 6), 0, 0),
					Vector3.new(0.16, 0.05, 1.2), Enum.Material.Grass, Color3.fromRGB(96, 146, 70):Lerp(Color3.fromRGB(140, 170, 80), rng:NextNumber(0, 0.4)))
				leaf.CastShadow = false
			end
		end
	end
end

-- Rock garden: raked sand disc with grooves, a border of flat stones, three old stones (one mossy)
D.Build.RockGarden = function(m)
	D.cyl(m, Vector3.new(0, 0.06, 0), 0.16, 3.0, Enum.Material.Sand, Color3.fromRGB(222, 212, 186))
	-- raked grooves: thin darker strips 0.02 above the sand top (0.14 -> 0.16)
	for i = -3, 3 do
		local half = math.sqrt(math.max(0, 2.7 * 2.7 - (i * 0.6) ^ 2))
		local g = D.P(m, Vector3.new(half * 2, 0.04, 0.08), CFrame.new(0, 0.15 + (i % 2) * 0.004, i * 0.6), Enum.Material.Sand, Color3.fromRGB(196, 184, 156))
		g.CastShadow = false
	end
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		blob(m, CFrame.new(math.cos(a) * 3.15, 0.1, math.sin(a) * 3.15) * CFrame.Angles(0, -a, 0), Vector3.new(0.6, 0.3, 1.45), Enum.Material.Slate, D.DARKSTONE:Lerp(D.GRANITE, (i % 3) / 3))
	end
	local stones = { { -1.0, 0.3, 1.5, 1.3, 1.1 }, { 0.9, -0.6, 1.0, 0.8, 0.9 }, { 0.4, 1.1, 0.7, 0.55, 0.6 } }
	for i, s in ipairs(stones) do
		blob(m, CFrame.new(s[1], s[4] * 0.42, s[2]) * CFrame.Angles(0.15 * i, i, 0.1), Vector3.new(s[3] * 1.3, s[4], s[5] * 1.2), Enum.Material.Granite, D.GRANITE:Lerp(D.DARKSTONE, 0.2 * i), { CanCollide = true })
	end
	blob(m, CFrame.new(-1.0, 1.08, 0.3), Vector3.new(1.2, 0.3, 0.9), Enum.Material.Grass, Color3.fromRGB(90, 130, 70), { CastShadow = false })
end

-- Bonsai pine: glazed pot with a rim, soil, a twisted trunk, flat foliage pads
D.Build.BonsaiPine = function(m)
	local glaze = Color3.fromRGB(62, 96, 98)
	D.P(m, Vector3.new(1.6, 0.6, 1.0), CFrame.new(0, 0.3, 0), Enum.Material.Marble, glaze, { CanCollide = true })
	D.P(m, Vector3.new(1.72, 0.14, 0.08), CFrame.new(0, 0.65, -0.54), Enum.Material.Marble, glaze)
	D.P(m, Vector3.new(1.72, 0.14, 0.08), CFrame.new(0, 0.65, 0.54), Enum.Material.Marble, glaze)
	-- side bars a touch shorter than the front/back ones so no faces share a plane
	D.P(m, Vector3.new(0.08, 0.1, 1.0), CFrame.new(-0.82, 0.645, 0), Enum.Material.Marble, glaze)
	D.P(m, Vector3.new(0.08, 0.1, 1.0), CFrame.new(0.82, 0.645, 0), Enum.Material.Marble, glaze)
	D.P(m, Vector3.new(1.5, 0.1, 0.94), CFrame.new(0, 0.63, 0), Enum.Material.Ground, Color3.fromRGB(80, 60, 44))
	for _, sx in ipairs({ -1, 1 }) do
		D.P(m, Vector3.new(0.3, 0.14, 0.82), CFrame.new(sx * 0.6, 0.04, 0), Enum.Material.Marble, glaze:Lerp(Color3.new(0, 0, 0), 0.3))
	end
	local bark = Color3.fromRGB(96, 70, 52)
	local pts = { Vector3.new(0.1, 0.66, 0), Vector3.new(-0.25, 1.3, 0.1), Vector3.new(0.2, 1.9, -0.05), Vector3.new(-0.1, 2.5, 0.05) }
	for i = 1, #pts - 1 do
		limb(m, pts[i], pts[i + 1], 0.2 - i * 0.03, { Material = Enum.Material.Wood, Color = bark })
	end
	local pads = { { pts[2] + Vector3.new(-0.6, 0.1, 0), 1.3 }, { pts[3] + Vector3.new(0.65, 0.15, 0), 1.2 }, { pts[4] + Vector3.new(0, 0.25, 0), 1.4 },
		{ pts[3] + Vector3.new(-0.5, 0.35, 0.2), 0.9 } }
	for i, pd in ipairs(pads) do
		local start = (i == 1) and pts[2] or (i == 3 and pts[4] or pts[3])
		if i ~= 3 then
			limb(m, start, pd[1], 0.06, { Material = Enum.Material.Wood, Color = bark })
		end
		blob(m, CFrame.new(pd[1]) * CFrame.Angles(0, i, 0), Vector3.new(pd[2], 0.42, pd[2] * 0.8), Enum.Material.Grass, Color3.fromRGB(56, 92, 58), { CastShadow = true })
	end
	blob(m, CFrame.new(0.45, 0.7, 0.2), Vector3.new(0.3, 0.16, 0.26), Enum.Material.Slate, D.GRANITE)
end

-- Koi pond: a ring of stones, still water 0.05+ above the ground, lily pads, a lotus, three koi
D.Build.KoiPond = function(m)
	local rng = Random.new(3)
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local w = rng:NextNumber(1.1, 1.5)
		blob(m, CFrame.new(math.cos(a) * 4.0, 0.18, math.sin(a) * 4.0) * CFrame.Angles(0, -a, 0), Vector3.new(w * 0.9, 0.55, w * 1.35),
			Enum.Material.Slate, D.GRANITE:Lerp(D.DARKSTONE, rng:NextNumber()), { CanCollide = true })
	end
	-- water: 0.06 -> 0.16 (top 0.16, never coplanar with the stones' curved tops)
	D.cyl(m, Vector3.new(0, 0.11, 0), 0.1, 3.7, Enum.Material.Glass, Color3.fromRGB(64, 120, 140), { Transparency = 0.25 })
	-- a darker floor just under the water so it reads as deep
	D.cyl(m, Vector3.new(0, 0.035, 0), 0.03, 3.6, Enum.Material.SmoothPlastic, Color3.fromRGB(34, 56, 60))
	local pads = { { 1.4, -0.8, 0.45 }, { -1.6, 0.9, 0.55 }, { 0.3, 1.8, 0.4 }, { -0.6, -1.9, 0.35 } }
	for i, pd in ipairs(pads) do
		local pad = D.cyl(m, Vector3.new(pd[1], 0.18 + i * 0.006, pd[2]), 0.03, pd[3], Enum.Material.Grass, Color3.fromRGB(70, 130, 66))
		pad.CastShadow = false
	end
	local lotus = blob(m, CFrame.new(-1.6, 0.34, 0.9), Vector3.new(0.4, 0.32, 0.4), Enum.Material.SmoothPlastic, Color3.fromRGB(250, 180, 200))
	lotus.CastShadow = false
	for i = 1, 3 do
		local a = i * 2.1
		-- koi swim under the surface: everything stays 0.03+ below the water top (0.16)
		local cf = CFrame.new(math.cos(a) * 2.0, 0.09, math.sin(a) * 2.0) * CFrame.Angles(0, -a + math.rad(90), 0)
		local color = (i == 2) and Color3.fromRGB(245, 245, 240) or Color3.fromRGB(240, 120, 50)
		local body = blob(m, cf, Vector3.new(0.26, 0.16, 0.7), Enum.Material.SmoothPlastic, color)
		local tail = D.P(m, Vector3.new(0.04, 0.06, 0.24), cf * CFrame.new(0, 0.02, 0.42) * CFrame.Angles(0, math.rad(25 * (i - 2)), 0), Enum.Material.SmoothPlastic, color)
		D.noShadow({ body, tail })
	end
end

-- Wind chime: a post with an arm, a bronze cap, five hanging rods and a clapper (rods in "Sway")
D.Build.WindChime = function(m)
	D.P(m, Vector3.new(0.8, 0.3, 0.8), CFrame.new(0, 0.1, 0), Enum.Material.Slate, D.DARKSTONE, { CanCollide = true })
	D.cyl(m, Vector3.new(0, 2.6, 0), 4.8, 0.15, Enum.Material.Wood, D.DARKWOOD, { CanCollide = true })
	D.P(m, Vector3.new(1.2, 0.14, 0.14), CFrame.new(0.5, 4.9, 0), Enum.Material.Wood, D.DARKWOOD)
	local x = 0.98
	D.cyl(m, Vector3.new(x, 4.66, 0), 0.08, 0.42, Enum.Material.Metal, D.BRONZE)
	blob(m, CFrame.new(x, 4.76, 0), Vector3.new(0.84, 0.2, 0.84), Enum.Material.Metal, D.BRONZE)
	local sway = Instance.new("Model")
	sway.Name = "Sway"
	sway:SetAttribute("Sway", 6)
	sway.Parent = m
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local len = 0.7 + (i % 3) * 0.3
		local px, pz = x + math.cos(a) * 0.3, math.sin(a) * 0.3
		local string_ = D.P(sway, Vector3.new(0.02, 0.3, 0.02), CFrame.new(px, 4.47, pz), Enum.Material.Fabric, D.BLACK)
		local rod = D.cyl(sway, Vector3.new(px, 4.32 - len / 2, pz), len, 0.05, Enum.Material.Metal, Color3.fromRGB(196, 190, 170))
		D.noShadow({ string_, rod })
	end
	local clap = D.P(sway, Vector3.new(0.02, 1.1, 0.02), CFrame.new(x, 4.05, 0), Enum.Material.Fabric, D.BLACK)
	local paddle = D.P(sway, Vector3.new(0.3, 0.42, 0.03), CFrame.new(x, 3.3, 0), Enum.Material.WoodPlanks, Color3.fromRGB(220, 200, 160))
	D.noShadow({ clap, paddle })
end

-- Shrine gate (torii): red pillars on black stone feet, upturned top beam, tie beam and plaque
D.Build.ShrineGate = function(m)
	local L = Enum.Material.SmoothPlastic
	for _, sx in ipairs({ -1, 1 }) do
		D.cyl(m, Vector3.new(sx * 3.1, 0.3, 0), 0.6, 0.5, Enum.Material.Slate, D.BLACK, { CanCollide = true })
		D.cyl(m, Vector3.new(sx * 3.1, 3.65, 0), 6.1, 0.34, L, D.RED, { CanCollide = true })
	end
	D.P(m, Vector3.new(7.4, 0.36, 0.46), CFrame.new(0, 5.6, 0), L, D.RED)
	D.P(m, Vector3.new(7.9, 0.3, 0.62), CFrame.new(0, 6.6, 0), L, D.RED)
	D.P(m, Vector3.new(8.6, 0.42, 0.76), CFrame.new(0, 6.96, 0), L, D.BLACK)
	-- upturned ends
	for _, sx in ipairs({ -1, 1 }) do
		D.P(m, Vector3.new(0.9, 0.34, 0.74), CFrame.new(sx * 4.48, 7.1, 0) * CFrame.Angles(0, 0, math.rad(sx * 14)), L, D.BLACK)
	end
	D.P(m, Vector3.new(0.5, 0.86, 0.28), CFrame.new(0, 6.09, 0), L, D.RED)
	local plaque = D.P(m, Vector3.new(0.78, 0.6, 0.06), CFrame.new(0, 6.09, -0.18), Enum.Material.Wood, D.BLACK)
	plaque.CastShadow = false
	local gold = D.P(m, Vector3.new(0.5, 0.36, 0.04), CFrame.new(0, 6.09, -0.23), Enum.Material.Foil, D.GOLD)
	gold.CastShadow = false
end

-- Incense burner: a bronze three-legged ding on a stone base, glowing sticks and a smoke curl
D.Build.IncenseBurner = function(m)
	local M = Enum.Material.Metal
	D.cyl(m, Vector3.new(0, 0.1, 0), 0.3, 1.55, Enum.Material.Slate, D.DARKSTONE, { CanCollide = true })
	D.cyl(m, Vector3.new(0, 0.29, 0), 0.08, 1.35, Enum.Material.Slate, D.GRANITE)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		limb(m, Vector3.new(math.cos(a) * 0.55, 0.95, math.sin(a) * 0.55), Vector3.new(math.cos(a) * 0.85, 0.33, math.sin(a) * 0.85), 0.12, { Material = M, Color = D.BRONZE })
		blob(m, CFrame.new(math.cos(a) * 0.88, 0.4, math.sin(a) * 0.88), Vector3.new(0.34, 0.2, 0.34), M, D.BRONZE)
	end
	blob(m, CFrame.new(0, 1.4, 0), Vector3.new(2.0, 1.3, 2.0), M, D.BRONZE, { CanCollide = true })
	-- a band of darker bronze round the belly (0.03 proud)
	blob(m, CFrame.new(0, 1.42, 0), Vector3.new(2.06, 0.22, 2.06), M, D.BRONZE:Lerp(Color3.new(0, 0, 0), 0.3))
	-- rim: a ring of short segments so the ash inside shows
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		D.P(m, Vector3.new(0.18, 0.16, 0.46), CFrame.new(math.cos(a) * 0.93, 2.06, math.sin(a) * 0.93) * CFrame.Angles(0, -a, 0), M, D.BRONZE)
	end
	D.cyl(m, Vector3.new(0, 2.04, 0), 0.04, 0.84, Enum.Material.Sand, Color3.fromRGB(160, 154, 146))
	-- ear handles
	for _, sx in ipairs({ -1, 1 }) do
		D.P(m, Vector3.new(0.12, 0.5, 0.42), CFrame.new(sx * 0.96, 2.36, 0) * CFrame.Angles(0, 0, math.rad(sx * -10)), M, D.BRONZE)
	end
	local tips = {}
	for i = 1, 3 do
		local x = (i - 2) * 0.22
		local stick = limb(m, Vector3.new(x, 2.06, 0.05 * i), Vector3.new(x * 1.3, 3.0, 0.05 * i), 0.025, { Color = Color3.fromRGB(150, 40, 30) })
		local tip = part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.09, 0.09, 0.09), CFrame = CFrame.new(x * 1.3, 3.02, 0.05 * i), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 50) })
		D.noShadow({ stick, tip })
		table.insert(tips, tip)
	end
	D.light(tips[2], Color3.fromRGB(255, 150, 80), 6, 0.8)
	local a = Instance.new("Attachment")
	a.Parent = tips[2]
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = Config.Particles.Smoke
	smoke.Rate = 2.5
	smoke.Lifetime = NumberRange.new(3, 4)
	smoke.Speed = NumberRange.new(1, 1.6)
	smoke.SpreadAngle = Vector2.new(6, 6)
	smoke.Acceleration = Vector3.new(0.3, 0.2, 0)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1.1) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
	smoke.Parent = a
end

-- Peach altar: stone table with a cloth runner, a plate with a pyramid of peaches, two candles
D.Build.PeachAltar = function(m)
	local S = Enum.Material.Slate
	for _, sx in ipairs({ -1, 1 }) do
		D.P(m, Vector3.new(0.36, 1.16, 1.26), CFrame.new(sx * 1.0, 0.58, 0), S, D.GRANITE, { CanCollide = true })
		-- carved scroll foot (0.04 proud of the leg front)
		D.P(m, Vector3.new(0.28, 0.24, 0.06), CFrame.new(sx * 1.0, 0.24, -0.66), S, D.DARKSTONE)
	end
	D.P(m, Vector3.new(2.7, 0.26, 1.6), CFrame.new(0, 1.29, 0), S, D.GRANITE, { CanCollide = true })
	D.P(m, Vector3.new(2.78, 0.1, 1.68), CFrame.new(0, 1.17, 0), S, D.DARKSTONE)
	D.P(m, Vector3.new(0.82, 0.04, 1.7), CFrame.new(0, 1.44, 0), Enum.Material.Fabric, Color3.fromRGB(176, 40, 40))
	D.P(m, Vector3.new(0.82, 0.56, 0.04), CFrame.new(0, 1.16, -0.87), Enum.Material.Fabric, Color3.fromRGB(176, 40, 40))
	D.cyl(m, Vector3.new(0, 1.49, 0), 0.06, 0.62, Enum.Material.Marble, Color3.fromRGB(236, 232, 222))
	local peach = Color3.fromRGB(250, 168, 138)
	local spots = { { -0.18, 0.18 }, { 0.18, 0.18 }, { -0.18, -0.18 }, { 0.18, -0.18 } }
	for _, s in ipairs(spots) do
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.38, 0.38, 0.38), CFrame = CFrame.new(s[1], 1.71, s[2]), Material = Enum.Material.SmoothPlastic, Color = peach })
	end
	local top = part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(0, 1.99, 0), Material = Enum.Material.SmoothPlastic, Color = peach:Lerp(Color3.fromRGB(255, 120, 110), 0.3) })
	D.P(m, Vector3.new(0.05, 0.12, 0.2), CFrame.new(0, 2.21, 0.05) * CFrame.Angles(math.rad(30), 0, 0), Enum.Material.Grass, D.LEAF, { CastShadow = false })
	-- soft glow: a faint halo ball around the top peach
	local halo = part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(0, 1.92, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 160), Transparency = 0.85, CastShadow = false })
	D.light(halo, Color3.fromRGB(255, 190, 150), 7, 1)
	for _, sx in ipairs({ -1, 1 }) do
		local c = D.cyl(m, Vector3.new(sx * 1.05, 1.62, 0.3), 0.3, 0.07, Enum.Material.SmoothPlastic, Color3.fromRGB(240, 230, 210))
		local f = part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.09, 0.14, 0.09), CFrame = CFrame.new(sx * 1.05, 1.84, 0.3), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 90) })
		D.noShadow({ c, f })
	end
	local _ = top
end

-- Golden toad: a three-legged gold toad with a coin in its mouth, on a pile of coins and a stand
D.Build.GoldenToad = function(m)
	local F, M = Enum.Material.Foil, Enum.Material.Metal
	D.cyl(m, Vector3.new(0, 0.15, 0), 0.3, 1.5, Enum.Material.Wood, D.BLACK, { CanCollide = true })
	D.cyl(m, Vector3.new(0, 0.33, 0), 0.06, 1.42, Enum.Material.Wood, D.RED)
	blob(m, CFrame.new(0, 0.42, 0), Vector3.new(2.4, 0.5, 2.2), M, D.GOLD:Lerp(Color3.fromRGB(150, 100, 30), 0.25))
	local rng = Random.new(5)
	for i = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0.7, 1.2)
		local coin = part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.34, 0.34),
			CFrame = CFrame.new(math.cos(a) * d, 0.52 + i * 0.012, math.sin(a) * d) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, math.rad(90) + rng:NextNumber(-0.3, 0.3)), Material = F, Color = D.GOLD, CastShadow = false })
		local _ = coin
	end
	local body = blob(m, CFrame.new(0, 1.15, 0.15), Vector3.new(1.6, 1.1, 1.7), F, D.GOLD)
	local _ = body
	blob(m, CFrame.new(0, 1.42, -0.62), Vector3.new(1.2, 0.78, 0.9), F, D.GOLD)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(sx * 0.36, 1.78, -0.7), Material = F, Color = D.GOLD })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.16, 0.16, 0.16), CFrame = CFrame.new(sx * 0.38, 1.82, -0.83), Material = Enum.Material.Neon, Color = Color3.fromRGB(220, 40, 40), CastShadow = false })
		-- front legs
		blob(m, CFrame.new(sx * 0.55, 0.78, -0.75), Vector3.new(0.3, 0.55, 0.3), F, D.GOLD)
	end
	-- haunches and the third leg at the back
	for _, sx in ipairs({ -1, 1 }) do
		blob(m, CFrame.new(sx * 0.7, 0.9, 0.45), Vector3.new(0.6, 0.7, 0.9), F, D.GOLD:Lerp(Color3.fromRGB(180, 120, 30), 0.15))
	end
	blob(m, CFrame.new(0, 0.75, 0.95), Vector3.new(0.3, 0.45, 0.45), F, D.GOLD)
	-- the coin in its mouth (square hole read by a dark inset 0.03 proud each side)
	D.cyl(m, Vector3.new(0, 1.26, -1.1), 0.08, 0.32, F, D.GOLD, { CFrame = CFrame.new(0, 1.26, -1.1) * CFrame.Angles(0, math.rad(90), 0) })
	D.P(m, Vector3.new(0.12, 0.12, 0.14), CFrame.new(0, 1.26, -1.1), M, D.BLACK, { CastShadow = false })
end

-- Spirit crystal: a carved two-tier stone base with glowing runes, a floating crystal cluster
D.Build.SpiritCrystal = function(m)
	local S = Enum.Material.Slate
	local cyan = Color3.fromRGB(120, 230, 255)
	D.cyl(m, Vector3.new(0, 0.25, 0), 0.5, 1.7, S, D.DARKSTONE, { CanCollide = true })
	D.cyl(m, Vector3.new(0, 0.7, 0), 0.4, 1.25, S, D.GRANITE, { CanCollide = true })
	D.cyl(m, Vector3.new(0, 0.94, 0), 0.08, 1.05, S, D.DARKSTONE)
	-- runes on the upper tier, 0.03 proud
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local rune = D.P(m, Vector3.new(0.05, 0.24, 0.12), CFrame.new(math.cos(a) * 1.28, 0.7, math.sin(a) * 1.28) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad((i % 3) * 15)),
			Enum.Material.Neon, cyan)
		rune.CastShadow = false
	end
	local glass = Enum.Material.Glass
	local center = Vector3.new(0, 3.1, 0)
	local shards = { { 0, 0, 0, 0.75, 2.6, 0.75, 0 }, { 0.55, -0.4, 0.2, 0.42, 1.5, 0.42, 25 }, { -0.5, -0.35, -0.15, 0.38, 1.3, 0.38, -28 },
		{ 0.1, -0.5, -0.55, 0.32, 1.1, 0.32, 20 }, { -0.2, -0.45, 0.5, 0.3, 1.0, 0.3, -18 } }
	for i, s in ipairs(shards) do
		local cf = CFrame.new(center + Vector3.new(s[1], s[2], s[3])) * CFrame.Angles(math.rad(s[7] * 0.6), math.rad(45 + i * 17), math.rad(s[7]))
		D.P(m, Vector3.new(s[4], s[5], s[6]), cf, glass, Color3.fromRGB(150, 230, 255), { Transparency = 0.25, CastShadow = false })
		-- pointed ends: smaller boxes rotated 45 deg, sunk into the shaft
		D.P(m, Vector3.new(s[4] * 0.7, s[4] * 0.7, s[6] * 0.7), cf * CFrame.new(0, s[5] / 2, 0) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(45), 0, 0), glass, Color3.fromRGB(170, 240, 255), { Transparency = 0.25, CastShadow = false })
		if i == 1 then
			local core = D.P(m, Vector3.new(0.3, 1.9, 0.3), cf, Enum.Material.Neon, cyan, { CastShadow = false })
			D.light(core, cyan, 8, 1.3)
			local a = Instance.new("Attachment")
			a.Parent = core
			local motes = Instance.new("ParticleEmitter")
			-- real magic: the only decor allowed the sparkle texture
			motes.Texture = Config.Particles.Spark
			motes.Rate = 3
			motes.Lifetime = NumberRange.new(2, 3)
			motes.Speed = NumberRange.new(0.3, 0.8)
			motes.SpreadAngle = Vector2.new(180, 180)
			motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 0) })
			motes.LightEmission = 1
			motes.Color = ColorSequence.new(cyan)
			motes.Acceleration = Vector3.new(0, 0.3, 0)
			motes.Parent = a
		end
	end
	-- a faint ring of light on the base top under the crystal (0.03 above the cap)
	local glow = D.cyl(m, Vector3.new(0, 1.0, 0), 0.02, 0.6, Enum.Material.Neon, cyan, { Transparency = 0.5 })
	glow.CastShadow = false
end

function Builders.Decor(id)
	local build = D.Build[id]
	assert(build, "no decor builder for " .. tostring(id))
	local m = newModel(id, CFrame.new(), Vector3.new(1, 1, 1))
	build(m)
	m:SetAttribute("DecorId", id)
	return m
end

-- ===================================================================== the Wildlands (open world)
-- One round floating landmass (Config.Wild) built from parts, no terrain:
--  * a cobbled camp in the middle (gate back to the Village, tents, a campfire, a signpost per zone);
--  * six zones as 60-degree sectors. Each zone's ground is a few overlapping discs in its own
--    material; every disc has its own top height (0.04 + 0.025 * k), so no two tops share a plane,
--    and they stay a clear margin inside the sector, so the grass between zones reads as trails;
--  * themed dressing per zone (Look), a boss arena at Wild.ArenaR and an entry sign.
-- Z-fighting: grass top 0, camp 0.06, zone discs 0.065..0.24, arenas 0.45, pools 0.53..0.77 (own
-- height each), lava 0.52; bamboo stalks keep 1.2 apart; stalks and ruin pillars sink below the discs.
local WILD_LOOK = {
	Willow = { Ground = { Enum.Material.Grass, Color3.fromRGB(104, 150, 82) }, Rock = { Enum.Material.Rock, Color3.fromRGB(112, 108, 100) } },
	Bamboo = { Ground = { Enum.Material.LeafyGrass, Color3.fromRGB(86, 140, 76) }, Rock = { Enum.Material.Slate, Color3.fromRGB(96, 104, 92) } },
	Ruins = { Ground = { Enum.Material.LeafyGrass, Color3.fromRGB(96, 118, 76) }, Rock = { Enum.Material.Cobblestone, Color3.fromRGB(124, 126, 112) } },
	Marsh = { Ground = { Enum.Material.Mud, Color3.fromRGB(84, 92, 66) }, Rock = { Enum.Material.Slate, Color3.fromRGB(80, 88, 78) } },
	Ashen = { Ground = { Enum.Material.Basalt, Color3.fromRGB(74, 70, 70) }, Rock = { Enum.Material.Basalt, Color3.fromRGB(56, 52, 52) } },
	Frost = { Ground = { Enum.Material.Snow, Color3.fromRGB(232, 238, 244) }, Rock = { Enum.Material.Glacier, Color3.fromRGB(170, 210, 236) } },
}
-- ground discs per zone: { R, A (deg off the centre line), radius }. All inside their sector with
-- 6+ studs to spare, outside the camp, inside the rim.
local WILD_PATCHES = {
	{ 170, 0, 60 }, { 245, 0, 70 }, { 325, 0, 72 }, { 405, 0, 70 },
	{ 335, -16, 55 }, { 335, 16, 55 }, { 470, -13, 52 }, { 470, 13, 52 },
}

local function signBoard(parent, cf, text, width)
	local sign = Instance.new("Model")
	sign.Name = "Sign"
	part(sign, { Name = "Post", Size = Vector3.new(0.6, 7, 0.6), CFrame = cf * CFrame.new(0, 3.5, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 66, 48), CanCollide = true })
	local board = part(sign, { Name = "Board", Size = Vector3.new(width or 11, 2.4, 0.3), CFrame = cf * CFrame.new(0, 6.2, 0.45), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(140, 108, 76) })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = text
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
		t.TextColor3 = Color3.fromRGB(255, 240, 210)
		t.Parent = gui
	end
	sign.Parent = parent
	return sign
end

-- a point in a zone's sector, kept away from its camps and arena (nil if it can't find one)
local function freeSpot(zone, rng, rMin, rMax, margin)
	for _ = 1, 30 do
		local r = rng:NextNumber(rMin, rMax)
		local a = rng:NextNumber(-25, 25)
		-- stay inside the sector by `margin` studs
		if r * math.sin(math.rad(30 - math.abs(a))) > margin then
			local p = Config.wildPos(zone, r, a)
			local ok = (p - zone.Arena).Magnitude > Config.Wild.ArenaRadius + 10
			for _, c in ipairs(zone.Camps) do
				ok = ok and (p - c.Pos).Magnitude > 22
			end
			for _, c in ipairs(zone.NightCamps or {}) do
				ok = ok and (p - c.Pos).Magnitude > 22
			end
			if ok then
				return p
			end
		end
	end
	return nil
end

local WILD_DRESS = {}
-- willows: the stage-1 tree, hanging fronds of thin green slabs
WILD_DRESS.Willow = function(m, zone, rng, G)
	for _ = 1, 16 do
		local p = freeSpot(zone, rng, 140, 520, 10)
		if p then
			local t = Builders.Tree(1, CFrame.new(p + G) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			for _, v in ipairs(t:GetDescendants()) do
				if v.Name == "Vein" or v.Name == "Flower" then
					v:Destroy()
				elseif v:IsA("BasePart") and v.Name ~= "Collider" then
					v.CanCollide = false
				end
			end
			t:ScaleTo(rng:NextNumber(0.6, 0.9))
			t.Name = "Willow"
			t.Parent = m
		end
	end
	for _ = 1, 10 do
		local p = freeSpot(zone, rng, 140, 520, 8)
		if p then
			local sz = rng:NextNumber(3, 7)
			blob(m, CFrame.new(p + G + Vector3.new(0, sz * 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.15), Vector3.new(sz * 1.5, sz, sz * 1.2), Enum.Material.Rock, ROCK, { CanCollide = true })
		end
	end
end
-- bamboo: clumps of tall jointed stalks with leaf tufts
WILD_DRESS.Bamboo = function(m, zone, rng, G)
	local stalk = Color3.fromRGB(120, 170, 80)
	for _ = 1, 40 do
		local p = freeSpot(zone, rng, 140, 520, 12)
		if p then
			-- stalks keep 1.2 studs between each other at the base, so even leaning they never meet
			local placed = {}
			for _ = 1, rng:NextInteger(9, 15) do
				-- sunk 0.6: below every ground disc's bottom (0.4 thick discs, tops 0.065..0.24)
				local q = p + G + Vector3.new(rng:NextNumber(-6, 6), -0.6, rng:NextNumber(-6, 6))
				local h = rng:NextNumber(16, 30)
				local r = rng:NextNumber(0.5, 0.8)
				local clear = true
				for _, o in ipairs(placed) do
					if ((o[1] - q) * Vector3.new(1, 0, 1)).Magnitude < o[2] + r + 1.2 then
						clear = false
					end
				end
				if not clear then
					continue
				end
				table.insert(placed, { q, r })
				local lean = CFrame.Angles(rng:NextNumber(-0.015, 0.015), 0, rng:NextNumber(-0.015, 0.015))
				local base = CFrame.new(q) * lean
				part(m, { Name = "Stalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r * 2, r * 2), CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = stalk:Lerp(Color3.fromRGB(90, 130, 60), rng:NextNumber()), CanCollide = true })
				-- joints: rings 0.08 wider than the stalk, so their sides never meet its surface
				for y = 3, h - 2, rng:NextNumber(3, 4.5) do
					part(m, { Name = "Joint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, r * 2 + 0.16, r * 2 + 0.16), CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 130, 60) })
				end
				-- leaf sprays: slim drooping ellipsoids fanned around the upper stalk
				for k = 1, rng:NextInteger(6, 9) do
					local y = h * rng:NextNumber(0.6, 1)
					local yaw = k * 2.4 + rng:NextNumber(-0.3, 0.3)
					blob(m, base * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -2.2) * CFrame.Angles(rng:NextNumber(0.25, 0.5), 0, 0),
						Vector3.new(rng:NextNumber(1.2, 1.8), 0.25, rng:NextNumber(4, 6)), Enum.Material.LeafyGrass, Color3.fromRGB(100, 165, 70):Lerp(Color3.fromRGB(150, 190, 90), rng:NextNumber()))
				end
			end
		end
	end
end
-- ruins: broken pillars, low walls with gaps, mossy rubble
WILD_DRESS.Ruins = function(m, zone, rng, G)
	local stone = Color3.fromRGB(150, 146, 130)
	for _ = 1, 14 do
		local p = freeSpot(zone, rng, 140, 520, 10)
		if p then
			local h = rng:NextNumber(5, 16)
			-- sunk 0.55 / 0.5 so their bottoms never share a plane with a ground disc's bottom
			part(m, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3, 3), CFrame = CFrame.new(p + G + Vector3.new(0, h / 2 - 0.55, 0)) * CFrame.Angles(0, 0, math.rad(90 + rng:NextNumber(-4, 4))), Material = Enum.Material.Cobblestone, Color = stone, CanCollide = true })
			part(m, { Name = "Plinth", Size = Vector3.new(4, 1.4, 4), CFrame = CFrame.new(p + G + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Material = Enum.Material.Slate, Color = stone:Lerp(ROCK, 0.4), CanCollide = true })
		end
	end
	for _ = 1, 10 do
		local p = freeSpot(zone, rng, 140, 520, 14)
		if p then
			local yaw = rng:NextNumber(0, 6.28)
			local cf = CFrame.new(p + G) * CFrame.Angles(0, yaw, 0)
			local x = -9
			while x < 9 do
				local w = rng:NextNumber(2.5, 5)
				local h = rng:NextNumber(2, 6)
				if rng:NextNumber() > 0.25 then
					part(m, { Name = "Wall", Size = Vector3.new(w, h, 2), CFrame = cf * CFrame.new(x + w / 2, h / 2 - 0.2, 0), Material = Enum.Material.Cobblestone, Color = stone:Lerp(ROCK, rng:NextNumber(0, 0.4)), CanCollide = true })
				end
				x += w + 0.05 -- 0.05 gap: neighbouring blocks never share a face
			end
		end
	end
	for _ = 1, 14 do
		local p = freeSpot(zone, rng, 140, 520, 8)
		if p then
			local sz = rng:NextNumber(2, 4)
			blob(m, CFrame.new(p + G + Vector3.new(0, sz * 0.2, 0)), Vector3.new(sz * 1.6, sz, sz * 1.3), Enum.Material.Grass, Color3.fromRGB(90, 120, 70))
		end
	end
end
-- marsh: still pools (above every ground disc), reeds and dead trees
WILD_DRESS.Marsh = function(m, zone, rng, G)
	for i = 1, 9 do
		local p = freeSpot(zone, rng, 150, 500, 22)
		if p then
			local r = rng:NextNumber(9, 18)
			-- each pool at its own height (0.5 + 0.03 i), so overlapping pools never share a plane
			local top = 0.5 + 0.03 * i
			part(m, { Name = "Pool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, r * 2, r * 2 * rng:NextNumber(0.7, 1)), CFrame = CFrame.new(p + G + Vector3.new(0, top - 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(90)), Material = Enum.Material.Glass, Color = Color3.fromRGB(70, 120, 110), Transparency = 0.25, Reflectance = 0.15, CastShadow = false })
			for _ = 1, 10 do
				local a = rng:NextNumber(0, 6.28)
				local q = p + G + Vector3.new(math.cos(a) * (r + rng:NextNumber(0, 2)), 0, math.sin(a) * (r + rng:NextNumber(0, 2)))
				local h = rng:NextNumber(3, 6)
				part(m, { Name = "Reed", Size = Vector3.new(0.25, h, 0.25), CFrame = CFrame.new(q + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Material = Enum.Material.Grass, Color = Color3.fromRGB(120, 130, 70) })
			end
		end
	end
	for _ = 1, 10 do
		local p = freeSpot(zone, rng, 140, 520, 10)
		if p then
			local h = rng:NextNumber(10, 18)
			local trunk = Color3.fromRGB(70, 62, 54)
			limb(m, p + G, p + G + Vector3.new(rng:NextNumber(-1, 1), h, rng:NextNumber(-1, 1)), 0.9, { Name = "DeadTree", Material = Enum.Material.Wood, Color = trunk, CanCollide = true })
			for _ = 1, 3 do
				local y = rng:NextNumber(h * 0.5, h * 0.9)
				local a = rng:NextNumber(0, 6.28)
				limb(m, p + G + Vector3.new(0, y, 0), p + G + Vector3.new(math.cos(a) * 5, y + 3, math.sin(a) * 5), 0.35, { Name = "Branch", Material = Enum.Material.Wood, Color = trunk })
			end
		end
	end
end
-- ashen: basalt spires, glowing lava cracks, charred stumps
WILD_DRESS.Ashen = function(m, zone, rng, G)
	for _ = 1, 18 do
		local p = freeSpot(zone, rng, 140, 520, 10)
		if p then
			local h = rng:NextNumber(8, 22)
			local w = rng:NextNumber(3, 6)
			blob(m, CFrame.new(p + G + Vector3.new(0, h * 0.35, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6.28), rng:NextNumber(-0.15, 0.15)), Vector3.new(w, h, w * 0.8), Enum.Material.Basalt, Color3.fromRGB(50, 46, 46), { CanCollide = true })
		end
	end
	for _ = 1, 16 do
		local p = freeSpot(zone, rng, 140, 520, 8)
		if p then
			local len = rng:NextNumber(6, 16)
			part(m, { Name = "Lava", Size = Vector3.new(rng:NextNumber(0.4, 0.9), 0.1, len), CFrame = CFrame.new(p + G + Vector3.new(0, 0.52 - 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 110, 30), CastShadow = false })
		end
	end
	for _ = 1, 8 do
		local p = freeSpot(zone, rng, 140, 520, 8)
		if p then
			limb(m, p + G, p + G + Vector3.new(0, rng:NextNumber(3, 6), 0), rng:NextNumber(0.8, 1.3), { Name = "Stump", Material = Enum.Material.Slate, Color = Color3.fromRGB(36, 32, 30), CanCollide = true })
		end
	end
end
-- frost: snow pines (stacked tiers), ice boulders
WILD_DRESS.Frost = function(m, zone, rng, G)
	for _ = 1, 18 do
		local p = freeSpot(zone, rng, 140, 520, 10)
		if p then
			local h = rng:NextNumber(14, 22)
			limb(m, p + G, p + G + Vector3.new(0, h * 0.4, 0), 0.7, { Name = "Trunk", Material = Enum.Material.Wood, Color = Color3.fromRGB(86, 64, 48), CanCollide = true })
			for k = 0, 3 do
				local t = k / 4
				local r = (1 - t) * h * 0.32 + 1.2
				local y = h * 0.3 + t * h * 0.6
				blob(m, CFrame.new(p + G + Vector3.new(0, y, 0)) * CFrame.Angles(0, k * 0.8, 0), Vector3.new(r * 2, h * 0.22, r * 2), Enum.Material.LeafyGrass, Color3.fromRGB(46, 84, 64))
				-- snow cap: a slightly smaller, slightly higher ellipsoid
				blob(m, CFrame.new(p + G + Vector3.new(0, y + h * 0.05, 0)) * CFrame.Angles(0, k * 0.8 + 0.3, 0), Vector3.new(r * 1.6, h * 0.14, r * 1.6), Enum.Material.Snow, Color3.fromRGB(240, 244, 250))
			end
		end
	end
	for _ = 1, 12 do
		local p = freeSpot(zone, rng, 140, 520, 8)
		if p then
			local sz = rng:NextNumber(3, 8)
			blob(m, CFrame.new(p + G + Vector3.new(0, sz * 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.2), Vector3.new(sz * 1.4, sz, sz * 1.2), Enum.Material.Glacier, Color3.fromRGB(170, 210, 236), { CanCollide = true })
		end
	end
end

function Builders.Wildlands(map, G)
	local W = Config.Wild
	local M = Config.Map
	local root = Instance.new("Folder")
	root.Name = "Wildlands"
	root.Parent = map
	local land = Builders.Landmass("Ground", W.Center + G, W.Radius, { Seed = 61, Grass = Color3.fromRGB(98, 140, 80) })
	land.Parent = root
	-- the camp
	local camp = Instance.new("Model")
	camp.Name = "Camp"
	camp.Parent = root
	part(camp, { Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, W.CampRadius * 2, W.CampRadius * 2), CFrame = CFrame.new(W.Center + G + Vector3.new(0, 0.06 - 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(146, 140, 128), CanCollide = true, CanQuery = true })
	local back = Builders.Gate("HomeGate", CFrame.new(M.GroundsGate + G), "VILLAGE", Color3.fromRGB(150, 255, 190))
	back:SetAttribute("TravelTo", "Hub")
	back.Parent = map
	-- tents around the camp (two leaning wedges each), a campfire
	local cloth = { Color3.fromRGB(190, 160, 110), Color3.fromRGB(150, 70, 60), Color3.fromRGB(90, 120, 110), Color3.fromRGB(170, 150, 120) }
	for i = 1, 4 do
		local a = math.rad(45 + (i - 1) * 90)
		local pos = W.Center + G + Vector3.new(math.cos(a) * 58, 0, math.sin(a) * 58)
		local cf = CFrame.lookAt(pos, W.Center + G)
		part(camp, { Name = "Tent", Class = "WedgePart", Size = Vector3.new(8, 5, 4), CFrame = cf * CFrame.new(0, 2.5, -2), Material = Enum.Material.Fabric, Color = cloth[i], CanCollide = true })
		part(camp, { Name = "Tent", Class = "WedgePart", Size = Vector3.new(8, 5, 4), CFrame = cf * CFrame.new(0, 2.5, 2) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Fabric, Color = cloth[i]:Lerp(Color3.new(0, 0, 0), 0.12), CanCollide = true })
	end
	local fire = W.Center + G + Vector3.new(30, 0, 34)
	for k = 0, 3 do
		limb(camp, fire + Vector3.new(math.cos(k * 0.8) * 1.6, 0.3, math.sin(k * 0.8) * 1.6), fire + Vector3.new(-math.cos(k * 0.8) * 1.6, 0.6, -math.sin(k * 0.8) * 1.6), 0.3, { Name = "Log", Material = Enum.Material.Wood, Color = Color3.fromRGB(80, 56, 40) })
	end
	local flame = part(camp, { Name = "Fire", Size = Vector3.new(1.2, 1.6, 1.2), CFrame = CFrame.new(fire + Vector3.new(0, 1.2, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 60), Transparency = 0.2, CastShadow = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 22
	light.Brightness = 2
	light.Parent = flame
	-- zones
	for zi, z in ipairs(Config.Zones) do
		local look = WILD_LOOK[z.Look]
		local zm = Instance.new("Model")
		zm.Name = z.Id
		zm.Parent = root
		for k, pt in ipairs(WILD_PATCHES) do
			local c = Config.wildPos(z, pt[1], pt[2])
			local top = 0.04 + 0.025 * k
			part(zm, { Name = "Ground", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, pt[3] * 2, pt[3] * 2), CFrame = CFrame.new(c + G + Vector3.new(0, top - 0.2, 0)) * CFrame.Angles(0, k, math.rad(90)),
				Material = look.Ground[1], Color = look.Ground[2]:Lerp(look.Rock[2], (k % 3) * 0.06), CanCollide = true, CanQuery = true })
		end
		local rng = Random.new(zi * 97)
		WILD_DRESS[z.Look](zm, z, rng, G)
		-- boss arena: a stone floor (0.45 up) ringed by standing stones, and its sign
		local arena = Instance.new("Model")
		arena.Name = "Arena"
		arena.Parent = zm
		part(arena, { Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, W.ArenaRadius * 2, W.ArenaRadius * 2), CFrame = CFrame.new(z.Arena + G + Vector3.new(0, 0.45 - 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = look.Rock[2]:Lerp(Color3.fromRGB(120, 116, 108), 0.5), CanCollide = true, CanQuery = true })
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2
			local h = rng:NextNumber(7, 12)
			part(arena, { Name = "Stone", Size = Vector3.new(3, h, 2), CFrame = CFrame.new(z.Arena + G + Vector3.new(math.cos(a) * (W.ArenaRadius + 3), h / 2 - 0.4, math.sin(a) * (W.ArenaRadius + 3))) * CFrame.Angles(0, -a, rng:NextNumber(-0.06, 0.06)),
				Material = look.Rock[1], Color = look.Rock[2], CanCollide = true })
		end
		local toCamp = CFrame.lookAt(z.Arena + G, W.Center + G)
		signBoard(arena, toCamp * CFrame.new(-8, 0, -(W.ArenaRadius + 8)), Config.Mobs[z.Boss.Mob].Name .. "'s Arena", 12)
		-- entry sign on the trail out of the camp, facing the camp
		local entry = Config.wildPos(z, W.CampRadius + 14, 0) + G
		signBoard(zm, CFrame.lookAt(entry, W.Center + G) * CFrame.new(7, 0, 0), string.format("%s  ·  Lv %d-%d", z.Name, z.MinLevel, z.MaxLevel), 12)
	end
	-- invisible rim wall
	local walls = Instance.new("Folder")
	walls.Name = "Boundaries"
	walls.Parent = map
	local n = 48
	for k = 1, n do
		local a = k / n * math.pi * 2
		local r = W.Radius + 2
		part(walls, { Name = "Wall", Size = Vector3.new(2, 60, 2 * math.pi * r / n + 2), CFrame = CFrame.new(W.Center + Vector3.new(math.cos(a) * r, 30, math.sin(a) * r)) * CFrame.Angles(0, -a, 0), Transparency = 1, CanCollide = true, CastShadow = false })
	end
	return root
end

-- ===================================================================== world (Edit-time, CHO/tools/BuildWorld.lua)
-- Parts only (no terrain): floating landmasses for the Village and every player island, ground slabs
-- for the Wildlands (Builders.Wildlands), plaza, gates, scenery trees and
-- invisible boundaries. Re-runnable: clears Workspace.Map first.
function Builders.World()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	local M = Config.Map
	local G = Vector3.new(0, M.GroundY, 0)
	-- the Village: a big floating landmass with a cobbled plaza (top 0.06 up) and two paths (0.03 up)
	local village = Builders.Landmass("Village", G, M.HubRadius + 40, { Seed = 3 })
	village.Parent = map
	local stone = Color3.fromRGB(150, 146, 136)
	part(village, { Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 92, 92), CFrame = CFrame.new(G + Vector3.new(0, 0.06 - 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = stone, CanCollide = true, CanQuery = true })
	for i, gz in ipairs({ M.HubGate.Z, M.IslandGate.Z }) do
		-- each path at its own height (0.03 / 0.045 up) so their faces never share a plane
		part(village, { Name = "Path", Size = Vector3.new(12, 0.4, math.abs(gz)), CFrame = CFrame.new(G + Vector3.new(0, 0.015 + i * 0.015 - 0.2, gz / 2)), Material = Enum.Material.Cobblestone, Color = stone:Lerp(Color3.fromRGB(120, 110, 96), 0.3), CanCollide = true, CanQuery = true })
	end
	-- player islands in a ring around the Village
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	for i = 1, M.PlotCount do
		local a = (i - 1) / M.PlotCount * math.pi * 2 + math.pi / M.PlotCount
		local pos = Vector3.new(math.cos(a) * M.PlotRadius, M.GroundY, math.sin(a) * M.PlotRadius)
		-- a sculpted island model (art pass) replaces the part landmass: MystreeAssets.Island.Island
		local art = game:GetService("ReplicatedStorage"):FindFirstChild("MystreeAssets")
		art = art and art:FindFirstChild("Island") and art.Island:FindFirstChild("Island")
		local land = art and art:Clone() or Builders.Landmass("Island", pos, M.IslandRadius, { Seed = i * 101 })
		if art then
			land:PivotTo(CFrame.new(pos))
		end
		land.Name = "Island" .. i
		land.Parent = map
		-- +Z of the island frame points at the Village
		local cf = CFrame.lookAt(pos, Vector3.new(0, M.GroundY, 0)) * CFrame.Angles(0, math.pi, 0)
		local p = Builders.Plot(i, cf)
		p:SetAttribute("Index", i)
		p.Parent = plots
	end
	-- the village itself: buildings, NPC places, plaza dressing and NPC spots
	Builders.Village(map, G)
	-- plaza centre: a shrine stone
	local shrine = Instance.new("Model")
	shrine.Name = "Shrine"
	part(shrine, { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 14, 14), CFrame = CFrame.new(G + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(130, 128, 120), CanCollide = true })
	part(shrine, { Name = "Stone", Size = Vector3.new(4, 9, 3), CFrame = CFrame.new(G + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0.3, 0.05), Material = Enum.Material.Rock, Color = Color3.fromRGB(110, 120, 115), CanCollide = true })
	part(shrine, { Name = "Rune", Size = Vector3.new(1.2, 4, 0.1), CFrame = CFrame.new(G + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0.3, 0.05) * CFrame.new(0, 0, -1.56), Material = Enum.Material.Neon, Color = Color3.fromRGB(110, 200, 255), CastShadow = false })
	shrine.Parent = map
	-- gate to the Hunting Grounds and the gate back
	local hubGate = Builders.Gate("HuntGate", CFrame.new(M.HubGate + G), "HUNTING GROUNDS", Color3.fromRGB(120, 200, 255))
	hubGate:SetAttribute("TravelTo", "Grounds")
	hubGate.Parent = map
	local islandGate = Builders.Gate("IslandGate", CFrame.new(M.IslandGate + G), "MY ISLAND", Color3.fromRGB(255, 220, 140))
	islandGate:SetAttribute("TravelTo", "Home")
	islandGate.Parent = map
	-- the Hunting Grounds: the open-world Wildlands (camp, six zones, boss arenas, rim wall)
	Builders.Wildlands(map, G)
	-- scenery trees around the hub (placeholder stage-1 trees, scaled down)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = map
	local rng = Random.new(5)
	local function sceneryTree(pos)
		local t = Builders.Tree(1, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		for _, v in ipairs(t:GetDescendants()) do
			if v.Name == "Vein" or v.Name == "Flower" then
				v:Destroy()
			elseif v:IsA("BasePart") and v.Name ~= "Collider" then
				v.CanCollide = false
			end
		end
		t:ScaleTo(rng:NextNumber(0.55, 0.85))
		t.Name = "Tree"
		t.Parent = scenery
	end
	for i = 1, 22 do
		local a = i / 22 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		-- outside the ring of village buildings (which reach ~95 studs out)
		local r = M.HubRadius + rng:NextNumber(14, 32)
		if math.abs(a - math.pi * 1.5) > 0.25 and math.abs(a - math.pi * 0.5) > 0.25 then -- keep both gate paths clear
			sceneryTree(Vector3.new(math.cos(a) * r, M.GroundY, math.sin(a) * r))
		end
	end
	-- spawn location on the plaza
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(M.HubSpawn + G + Vector3.new(0, 0.1, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map
	return map
end

return Builders
