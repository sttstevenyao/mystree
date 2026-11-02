-- StarterPlayerScripts/MystreeClient/Equipment (ModuleScript)
-- What every player carries, drawn on every client (nothing replicates per frame, Playbook 06):
--  * Weapon from the "WeaponLook" attribute ("Sword:4"), always on the body (user, 2026-10-27):
--    sheathed at the left hip (swords) or across the back (greatswords, spears), in the right hand
--    while the "Held" attribute is "Weapon". Epic+ weapons pulse their Glow strip.
--  * Drawing: E draws / sheathes (with the axe out on your island, E puts the axe away first; the
--    axe itself is placed by Chop). Attacking draws the weapon, chopping takes out the axe. Every
--    change plays a draw or sheathe move on that character for everyone (the swap happens mid-move);
--    the server keeps "Held" ("Hold" remote). E does nothing while a prompt is showing (NPC talk,
--    shrine, ...), since those are on E too.
--  * Companions from the "Companions" attribute ("FoxSpirit:3,Qilin:1"): client models that follow
--    the owner, walk/fly, and fire a glowing shot at the target when the server reports their hit.
--  * Mounts when Riding (anywhere): the mount model sits under the rider (its "Seat" lines up with
--    the HumanoidRootPart), legs swing with speed, hover mounts bob; the rider holds Rig.Ride.
-- One Heartbeat loop moves everything. Far followers (> 220 studs) update at ~20 Hz; off-screen
-- ones skip the leg/wing posing. All models are anchored and moved with BulkMoveTo.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Auras = require(ReplicatedStorage.Mystree.Auras)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local Fx = require(script.Parent.Fx)
local Rig = require(script.Parent.Rig)
local Gaits = require(script.Parent.Gaits)
local Creatures = require(ReplicatedStorage.Mystree.Creatures)

local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Sounds = require(script.Parent.Sounds)

local Equipment = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local P = Config.Particles

local holder = Instance.new("Folder")
holder.Name = "MystreeEquipment"
holder.Parent = workspace

-- per player: { Weapon = {Model, Look, Parts, Rels, Glow, Trail}, Companions = {list of followers},
--   CompLook = string, Mount = {follower, Id}, Conns = {} }
local rigs = {}

local FAR = 220
-- tune if the blade sits wrong in the hand (art pass): extra rotation applied at the grip
local GRIP_TWEAK = CFrame.new()

-- ===================================================================== anchored "puppet" helper
-- Records every part's offset from the model pivot so the whole model can be moved with one
-- BulkMoveTo. Legs (Side/End attributes) and wings (Side) can swing around their top/inner edge.
local sculptRig -- (below, with the mounts) a rigged sculpt on an anchored root

local function puppet(model)
	local pivot = model:GetPivot()
	local p = { Model = model, Parts = {}, Rels = {}, Legs = {}, Wings = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local rel = pivot:ToObjectSpace(d.CFrame)
			if d.Name == "Leg" and d:GetAttribute("Side") then
				-- limbs are cylinders along X between hip and foot; the hip is the higher end
				local half = d.CFrame.RightVector * d.Size.X / 2
				local a, b = d.Position + half, d.Position - half
				local hip = (a.Y > b.Y) and a or b
				table.insert(p.Legs, { Part = d, Rel = rel, Hip = pivot:PointToObjectSpace(hip), Phase = ((d:GetAttribute("Side") or 1) * (d:GetAttribute("End") or 1) > 0) and 0 or math.pi })
			elseif d.Name == "Wing" then
				local side = d:GetAttribute("Side") or 1
				local inner = d.Position - d.CFrame.RightVector * side * d.Size.X / 2
				table.insert(p.Wings, { Part = d, Rel = rel, Hinge = pivot:PointToObjectSpace(inner), Side = side })
			else
				table.insert(p.Parts, d)
				table.insert(p.Rels, rel)
			end
		end
	end
	local cf, size = model:GetBoundingBox()
	p.Bottom = pivot.Y - (cf.Y - size.Y / 2) -- pivot height above the model's lowest point
	p.Height = size.Y
	model.Parent = holder
	return p
end

-- Move a puppet: swing = leg swing angle (radians), flap = wing angle
local function place(p, pivot, swing, flap, pose)
	local parts, cfs = {}, {}
	for i, part in ipairs(p.Parts) do
		parts[i] = part
		cfs[i] = pivot * p.Rels[i]
	end
	for _, leg in ipairs(p.Legs) do
		local a = pose and swing * math.cos(leg.Phase) or 0
		table.insert(parts, leg.Part)
		table.insert(cfs, pivot * CFrame.new(leg.Hip) * CFrame.Angles(a, 0, 0) * CFrame.new(-leg.Hip) * leg.Rel)
	end
	for _, w in ipairs(p.Wings) do
		local a = pose and flap * w.Side or 0
		table.insert(parts, w.Part)
		table.insert(cfs, pivot * CFrame.new(w.Hinge) * CFrame.Angles(0, 0, a) * CFrame.new(-w.Hinge) * w.Rel)
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function onScreen(pos)
	local _, vis = camera:WorldToViewportPoint(pos)
	return vis
end

local function charParts(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return char, hrp, hum
end

-- ground height under a character (HRP bottom minus hip height)
local function feetY(hrp, hum)
	return hrp.Position.Y - hrp.Size.Y / 2 - (hum and hum.HipHeight or 2)
end

-- ===================================================================== weapons
local function clearWeapon(r)
	if r.Weapon then
		r.Weapon.Model:Destroy()
		r.Weapon = nil
	end
end

local function buildWeapon(player, r)
	local look = player:GetAttribute("WeaponLook") or ""
	local want = look
	if r.Weapon and r.Weapon.Look == want then
		return
	end
	clearWeapon(r)
	if want == "" then
		return
	end
	local class, rarity = string.match(want, "^(%a+):(%d+)$")
	rarity = tonumber(rarity) or 1
	if not Config.WeaponClasses[class] then
		return
	end
	local model = Assets.Weapon(class, rarity)
	local handle = model.PrimaryPart or model:FindFirstChild("Handle")
	local grip = handle and handle:FindFirstChild("Grip")
	if not grip then
		model:Destroy()
		return
	end
	-- offsets from the grip attachment's world frame
	local gripWorld = grip.WorldCFrame
	local w = { Model = model, Look = want, Rarity = rarity, Parts = {}, Rels = {}, Class = class }
	-- which way the blade runs from the grip (grip space), to point it down the sheath
	local tip = gripWorld:PointToObjectSpace(model:GetBoundingBox().Position)
	w.BladeDir = tip.Magnitude > 0.1 and tip.Unit or Vector3.new(0, 1, 0)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			table.insert(w.Parts, d)
			table.insert(w.Rels, gripWorld:ToObjectSpace(d.CFrame))
		end
	end
	-- swing trail between the blade's base and tip (enabled by Combat during swings)
	local blade = model:FindFirstChild("Blade") or model:FindFirstChild("Head")
	if blade then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, -blade.Size.Y / 2 + 0.3, 0)
		a0.Parent = blade
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, blade.Size.Y / 2, 0)
		a1.Parent = blade
		local trail = Instance.new("Trail")
		trail.Name = "SwingTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.16
		trail.MinLength = 0.05
		trail.LightEmission = 0.8
		local c = Config.Rarities[rarity].Color
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(c, 0.5), c)
		trail.Transparency = NumberSequence.new(0.25, 1)
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = blade
		w.Trail = trail
	end
	local glow = model:FindFirstChild("Glow")
	if glow and rarity >= 4 then
		w.Glow = glow
		local e = Instance.new("ParticleEmitter")
		e.Texture = P.Glow
		e.Color = ColorSequence.new(Config.Rarities[rarity].Color)
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.22, 0)
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(0.2, 0.8)
		e.Rate = (rarity >= 6) and 6 or 3
		e.LockedToPart = false
		e.Parent = glow
	end
	model.Parent = holder
	r.Weapon = w
end

-- a rotation turning direction a onto direction b (both unit)
local function turnTo(a, b)
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-4 then
		return dot > 0 and CFrame.new() or CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end
Equipment.turnTo = turnTo

-- where the grip sits when sheathed: swords at the left hip, blade down and back; long weapons
-- across the back, handle over the right shoulder (offsets in the torso's own space)
local SHEATH = {
	Sword = { Part = "LowerTorso", Pos = Vector3.new(-0.82, 0.2, 0.1), Dir = Vector3.new(-0.1, -0.55, 0.83) },
	Greatsword = { Part = "UpperTorso", Pos = Vector3.new(0.55, 0.7, 0.7), Dir = Vector3.new(-0.55, -0.83, 0.08) },
	Spear = { Part = "UpperTorso", Pos = Vector3.new(0.5, 0.6, 0.7), Dir = Vector3.new(-0.5, -0.86, 0.08) },
}
Equipment.SHEATH = SHEATH

local function placeWeapon(player, r, now)
	local w = r.Weapon
	local char = player.Character
	local base
	if r.Shown == "Weapon" then
		local hand = char and char:FindFirstChild("RightHand")
		local att = hand and hand:FindFirstChild("RightGripAttachment")
		if not att then
			return
		end
		base = att.WorldCFrame * GRIP_TWEAK
	else
		local sh = SHEATH[w.Class] or SHEATH.Sword
		local torso = char and char:FindFirstChild(sh.Part)
		if not torso then
			return
		end
		local frame = torso.CFrame * CFrame.new(sh.Pos)
		base = CFrame.new(frame.Position) * (frame - frame.Position) * turnTo(w.BladeDir, sh.Dir.Unit)
	end
	local cfs = table.create(#w.Parts)
	for i, rel in ipairs(w.Rels) do
		cfs[i] = base * rel
	end
	workspace:BulkMoveTo(w.Parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if w.Glow then
		w.Glow.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(now * 3.2))
	end
end

-- Combat turns the blade trail on for the length of a swing
function Equipment.setTrail(player, on)
	local r = rigs[player]
	if r and r.Weapon and r.Weapon.Trail then
		r.Weapon.Trail.Enabled = on
	end
end

function Equipment.weapon(player)
	local r = rigs[player]
	return r and r.Weapon and r.Weapon.Model
end

-- ===================================================================== companions
local function clearCompanions(r)
	for _, f in ipairs(r.Companions) do
		f.P.Model:Destroy()
	end
	table.clear(r.Companions)
end

local function buildCompanions(player, r)
	local look = player:GetAttribute("Companions") or ""
	if r.CompLook == look then
		return
	end
	r.CompLook = look
	clearCompanions(r)
	local _, hrp = charParts(player)
	local slot = 0
	for id, stars in string.gmatch(look, "(%w+):(%d+)") do
		local def = Config.Companions[id]
		if def then
			slot += 1
			local model, p, sculpt
			if def.Look and Creatures.Looks[def.Look] then
				-- a sculpted spirit: rigged on an anchored root that follows, legs walked by Gaits
				local root, size, rootY, gait
				model, root, size, rootY, gait = sculptRig(def.Look, def.Length)
				model.Parent = holder
				p = { Model = model, Bottom = rootY, Height = size.Y + rootY }
				sculpt = { Root = root, Gait = gait }
			else
				model = Assets.Companion(id)
				p = puppet(model)
			end
			model.Name = "Companion_" .. id
			local f = { Id = id, Def = def, P = p, Slot = slot, Stars = tonumber(stars), Fly = def.Fly, Phase = math.random() * 6, Sculpt = sculpt }
			f.CF = hrp and (hrp.CFrame * CFrame.new(slot == 1 and 3 or -3, 0, 4)) or model:GetPivot()
			-- passive aura for Legendary+ (Playbook 06): its own preset (Auras), else a soft glow
			if def.Aura then
				Auras.attach(model, def.Aura)
			elseif def.Rarity >= 5 then
				local root = model.PrimaryPart
				local e = Instance.new("ParticleEmitter")
				e.Texture = (def.Rarity >= 6) and P.Spark or P.Glow
				e.Color = ColorSequence.new(def.Color, Color3.new(1, 1, 1))
				e.LightEmission = 0.8
				e.Size = NumberSequence.new(0.3, 0)
				e.Lifetime = NumberRange.new(0.8, 1.4)
				e.Speed = NumberRange.new(0.3, 1.2)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Acceleration = Vector3.new(0, 1.5, 0)
				e.Rate = (def.Rarity >= 6) and 5 or 3
				e.Parent = root
				local light = Instance.new("PointLight")
				light.Color = def.Color
				light.Range = 7
				light.Brightness = 0.8
				light.Parent = root
			end
			table.insert(r.Companions, f)
		end
	end
end

local function moveCompanion(f, hrp, hum, dt, now, pose)
	local flat = CFrame.lookAt(hrp.Position, hrp.Position + (hrp.CFrame.LookVector * Vector3.new(1, 0, 1)))
	local side = (f.Slot % 2 == 1) and 3.2 or -3.2
	local back = 3.5 + (f.Slot - 1) * 1.5
	local target = (flat * CFrame.new(side, 0, back)).Position
	local ground = feetY(hrp, hum)
	local y = ground + f.P.Bottom
	if f.Fly then
		y += 5 + math.sin(now * 2 + f.Phase) * 0.6
	end
	-- a short lunge toward the target when the companion attacks
	if f.LungeUntil and now < f.LungeUntil and f.LungeTo then
		target = target:Lerp(f.LungeTo, 0.6)
	end
	local cur = f.CF.Position
	local goal = Vector3.new(target.X, y, target.Z)
	local alpha = 1 - math.exp(-dt * 6)
	local nextPos = cur:Lerp(goal, alpha)
	local vel = (nextPos - cur) / math.max(dt, 1e-3)
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local facing
	if speed > 1 then
		facing = Vector3.new(vel.X, 0, vel.Z).Unit
	else
		facing = flat.LookVector
	end
	local curLook = f.CF.LookVector * Vector3.new(1, 0, 1)
	if curLook.Magnitude < 0.1 then
		curLook = facing
	end
	local look = curLook.Unit:Lerp(facing, math.min(1, dt * 8))
	if look.Magnitude < 0.05 then
		look = facing
	end
	local bob = 0
	if not f.Fly and speed > 2 then
		bob = math.abs(math.sin(now * 9 + f.Phase)) * 0.25
	end
	f.CF = CFrame.lookAt(nextPos, nextPos + look.Unit)
	f.Walk = (f.Walk or 0) + speed * dt * 0.9
	local swing = math.sin(f.Walk) * math.clamp(speed / 12, 0, 1) * 0.6
	if f.Sculpt then
		-- the root carries the body; its legs walk and gallop with the speed (as a mount's do)
		Gaits.step(f.Sculpt.Gait, speed, dt)
		f.Sculpt.Root.CFrame = f.CF
		if pose then
			Creatures.pose(f.Sculpt.Gait.Motors, f.Sculpt.Gait)
		end
		return
	end
	local flap = f.Fly and (0.35 + math.sin(now * 10 + f.Phase) * 0.45) or 0
	place(f.P, f.CF * CFrame.new(0, bob, 0), swing, flap, pose)
end

-- A glowing shot from the companion to its target (server reported the hit)
local function companionShot(f, target)
	local root = target and target.PrimaryPart
	if not root then
		return
	end
	local from = f.CF.Position + Vector3.new(0, f.P.Height * 0.3, 0)
	local to = root.Position
	f.LungeTo = to
	f.LungeUntil = os.clock() + 0.18
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.7, 0.7, 0.7)
	ball.Material = Enum.Material.Neon
	ball.Color = f.Def.Color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(from)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.2
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(f.Def.Color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = ball
	ball.Parent = holder
	local t = math.clamp((to - from).Magnitude / 90, 0.12, 0.35)
	TweenService:Create(ball, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(to) }):Play()
	task.delay(t, function()
		ball.Transparency = 1
		Fx.burst(to, { Texture = "Glow", Color = f.Def.Color, Color2 = Color3.new(1, 1, 1), Count = 10, Speed = { 6, 14 }, Size = 0.6, Light = 1, Gravity = Vector3.new(0, 0, 0), Lifetime = { 0.25, 0.45 } })
	end)
	Debris:AddItem(ball, t + 0.4)
end

-- ===================================================================== mounts
local function clearMount(player, r, puff)
	if not r.Mount then
		return
	end
	local char, hrp, hum = charParts(player)
	if puff and hrp then
		Fx.burst(hrp.Position - Vector3.new(0, 2, 0), { Texture = "Smoke", Color = Color3.fromRGB(230, 230, 230), Count = 10, Speed = { 4, 9 }, Size = 2.2, EndSize = 1.4, Lifetime = { 0.5, 0.9 }, Alpha = 0.4, Gravity = Vector3.new(0, 2, 0) })
	end
	r.Mount.P.Model:Destroy()
	if char then
		Rig.hold(char, "Ride", nil)
	end
	if player == localPlayer and hum and r.Mount.BaseHip then
		hum.HipHeight = r.Mount.BaseHip
	end
	r.Mount = nil
end

-- A sculpted ground mount (Config.Mounts[id].Look = a Creatures look): the rig's root is anchored
-- and set every frame, the body rides on its welds and the legs walk and gallop through the mobs'
-- gait (Gaits.step). Returns the model, the root, the rider's root relative to it, and the root's
-- height above the hooves.
local SADDLE = Color3.fromRGB(110, 50, 40)
local RIDER_UP = 1.25 -- the rider's root above the saddle top (seated R15)
-- a sculpted creature (Creatures.Looks[lookKey]) scaled to `length`, rigged on an anchored root
-- that the caller moves each frame; Gaits walks its legs. Mounts and sculpted spirits use it.
sculptRig = function(lookKey, length)
	local look = Creatures.Looks[lookKey]
	local model = Creatures.build(look[1], look[2])
	local design = model.PrimaryPart
	local rootC, rootS = model:GetAttribute("RootC"), model:GetAttribute("RootS")
	local root = Instance.new("Part")
	root.Name = "MountRoot"
	root.Size = rootS
	root.CFrame = CFrame.new(rootC)
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root
	design:Destroy()
	local k = (length or 7.5) / (model:GetAttribute("Length") or 6)
	model:ScaleTo(k)
	for _, a in ipairs({ "NeckBase", "JawPivot", "HeadPivot" }) do
		local v = model:GetAttribute(a)
		if v then
			model:SetAttribute(a, v * k)
		end
	end
	model:PivotTo(CFrame.new(0, rootC.Y * k, 0))
	Creatures.rig(model, root)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
		end
	end
	root.Anchored = true
	local gait = { Rig = model:GetAttribute("RigKind"), Motors = Creatures.motors(model), Phase = 0, Amp = 0, Run = false, Stride = (model:GetAttribute("Stride") or 3) * k,
		Seed = math.random() * 10, Size = k }
	return model, root, rootS * k, rootC.Y * k, gait
end

local function sculptMount(def)
	local model, root, size, rootY, gait = sculptRig(def.Look, def.Length)
	-- a blanket and a saddle on the back, a little ahead of the middle
	local top = root.CFrame * CFrame.new(0, size.Y / 2, size.Z * 0.04)
	for _, s in ipairs({
		{ "Blanket", Vector3.new(size.X * 1.08, 0.14, size.Z * 0.5), CFrame.new(0, -0.02, 0), Enum.Material.Fabric, def.Color:Lerp(Color3.new(0, 0, 0), 0.35) },
		{ "Saddle", Vector3.new(size.X * 0.82, 0.32, size.Z * 0.36), CFrame.new(0, 0.11, 0.05), Enum.Material.Leather, SADDLE },
	}) do
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Material, p.Color = s[1], s[2], top * s[3], s[4], s[5]
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, p
		w.Parent = p
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
		end
	end
	local seatRel = CFrame.new(0, size.Y / 2 + 0.27 + RIDER_UP, size.Z * 0.04 + 0.05)
	return model, root, seatRel, rootY, gait
end

local function buildMount(player, r)
	local want = ""
	if player:GetAttribute("Riding") then
		want = player:GetAttribute("Mount") or ""
	end
	if r.Mount and r.Mount.Id == want then
		return
	end
	clearMount(player, r, r.Mount ~= nil)
	local def = Config.Mounts[want]
	local char, hrp, hum = charParts(player)
	if not (def and char and hrp and hum) then
		return
	end
	local m
	if def.Look and Creatures.Looks[def.Look] then
		local model, root, seatRel, bottom, gait = sculptMount(def)
		model.Parent = holder
		m = { Id = want, Def = def, P = { Model = model }, Root = root, Gait = gait, SeatRel = seatRel }
		m.SeatHeight = bottom + seatRel.Y
	else
		local model = Assets.Mount(want)
		local seat = model:FindFirstChild("Seat")
		local pivot = model:GetPivot()
		local seatRel = seat and pivot:ToObjectSpace(seat.CFrame) or CFrame.new(0, 3, 0)
		if seat then
			seat.Transparency = 1
		end
		local p = puppet(model)
		m = { Id = want, Def = def, P = p, SeatRel = seatRel, Hover = def.Kind == "Hover" }
		-- the seat's height above the mount's lowest point = where the rider's root must sit
		m.SeatHeight = p.Bottom + seatRel.Y + (m.Hover and 1.5 or 0)
	end
	if player == localPlayer then
		m.BaseHip = hum.HipHeight
		local normal = hum.HipHeight + hrp.Size.Y / 2
		hum.HipHeight = hum.HipHeight + math.max(0, m.SeatHeight - normal)
	end
	Rig.hold(char, "Ride", Rig.Ride, Rig.RideStill)
	r.Mount = m
	Fx.burst(hrp.Position - Vector3.new(0, 1, 0), { Texture = "Smoke", Color = Color3.fromRGB(235, 235, 235), Count = 14, Speed = { 5, 10 }, Size = 2.4, EndSize = 1.4, Lifetime = { 0.5, 1 }, Alpha = 0.35, Gravity = Vector3.new(0, 2, 0) })
	Fx.ring(hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight - 0.1, 0), def.Color, 14, 0.5)
end

local function moveMount(r, hrp, now, pose)
	local m = r.Mount
	local flat = CFrame.lookAt(hrp.Position, hrp.Position + (hrp.CFrame.LookVector * Vector3.new(1, 0, 1)))
	local base = flat * m.SeatRel:Inverse()
	local vel = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	if m.Gait then
		local dt = math.min(now - (m.LastT or now), 0.1)
		m.LastT = now
		Gaits.step(m.Gait, speed, dt)
		-- the back rises and falls a little with each stride, under the rider
		local bob = math.abs(math.sin(m.Gait.Phase * math.pi * 2)) * (m.Gait.Run and 0.16 or 0.06) * m.Gait.Amp
		m.Root.CFrame = base * CFrame.new(0, -bob, 0)
		if pose then
			Creatures.pose(m.Gait.Motors, m.Gait)
		end
		return
	end
	if m.Hover then
		base = base * CFrame.new(0, -1.5 + math.sin(now * 2.2) * 0.3, 0) * CFrame.Angles(math.rad(-math.clamp(speed, 0, 40) * 0.15), 0, 0)
	end
	m.Walk = (m.Walk or 0) + speed * 0.016 * 0.55
	local swing = math.sin(m.Walk * 1.6) * math.clamp(speed / 20, 0, 1) * 0.7
	place(m.P, base, swing, 0, pose)
end

-- ===================================================================== armour (vanity)
-- Every player's equipped armour ("ArmorLook": "Helm:5:SetId,Armor:6:,...") drawn as plates fitted
-- to their body parts, while they have "ShowArmor" on (a setting). Plates are a little bigger than
-- the part they cover, so no face lies on the body's. Dark lacquer tinted toward the set colour (or
-- the rarity colour), trimmed in the rarity colour; Legendary and up get gold trim.
local LACQUER = Color3.fromRGB(38, 36, 42)
local GOLD = Color3.fromRGB(214, 178, 104)

local function plate(folder, part, size, offset, color, name)
	local p = Instance.new("Part")
	p.Name = name or "Plate"
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
	p.CFrame = part.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = part, p
	w.Parent = p
	p.Parent = folder
	return p
end

local ARMOR = {
	Helm = function(f, c, base, trim, r)
		local h = c:FindFirstChild("Head")
		if not h then
			return
		end
		local s = h.Size
		plate(f, h, Vector3.new(s.X * 1.08, 0.2, s.Z * 1.08), CFrame.new(0, s.Y * 0.2, 0), base, "Band")
		plate(f, h, Vector3.new(0.3, 0.34, 0.08), CFrame.new(0, s.Y * 0.32, -s.Z * 0.54 - 0.05), trim, "Crest")
		if r >= 5 then
			plate(f, h, Vector3.new(0.34, 0.26, 0.34), CFrame.new(0, s.Y * 0.56, 0.08), trim, "Knot")
		end
	end,
	Armor = function(f, c, base, trim)
		local t = c:FindFirstChild("UpperTorso")
		if not t then
			return
		end
		local s = t.Size
		plate(f, t, Vector3.new(s.X * 1.08, s.Y * 0.64, s.Z * 1.16), CFrame.new(0, s.Y * 0.08, 0), base, "Chest")
		plate(f, t, Vector3.new(s.X * 1.11, 0.14, s.Z * 1.2), CFrame.new(0, s.Y * 0.08 - s.Y * 0.31, 0), trim, "Trim")
		for _, side in ipairs({ "Left", "Right" }) do
			local a = c:FindFirstChild(side .. "UpperArm")
			if a then
				local as = a.Size
				plate(f, a, Vector3.new(as.X * 1.34, as.Y * 0.36, as.Z * 1.34), CFrame.new(0, as.Y * 0.3, 0), base, "Pauldron")
				plate(f, a, Vector3.new(as.X * 1.4, 0.12, as.Z * 1.4), CFrame.new(0, as.Y * 0.3 - as.Y * 0.18, 0), trim, "PauldronTrim")
			end
		end
	end,
	Gloves = function(f, c, base, trim)
		for _, side in ipairs({ "Left", "Right" }) do
			local a = c:FindFirstChild(side .. "LowerArm")
			if a then
				local s = a.Size
				plate(f, a, Vector3.new(s.X * 1.2, s.Y * 0.6, s.Z * 1.2), CFrame.new(0, -s.Y * 0.06, 0), base, "Bracer")
				plate(f, a, Vector3.new(s.X * 1.26, 0.1, s.Z * 1.26), CFrame.new(0, -s.Y * 0.06 + s.Y * 0.3, 0), trim, "BracerTrim")
			end
		end
	end,
	Boots = function(f, c, base, trim)
		for _, side in ipairs({ "Left", "Right" }) do
			local l = c:FindFirstChild(side .. "LowerLeg")
			if l then
				local s = l.Size
				plate(f, l, Vector3.new(s.X * 1.18, s.Y * 0.7, s.Z * 1.18), CFrame.new(0, -s.Y * 0.08, 0), base, "Greave")
				plate(f, l, Vector3.new(s.X * 1.24, 0.1, s.Z * 1.24), CFrame.new(0, -s.Y * 0.08 + s.Y * 0.35, 0), trim, "GreaveTrim")
			end
		end
	end,
	Belt = function(f, c, base, trim)
		local t = c:FindFirstChild("LowerTorso")
		if not t then
			return
		end
		local s = t.Size
		plate(f, t, Vector3.new(s.X * 1.12, s.Y * 0.36, s.Z * 1.2), CFrame.new(0, s.Y * 0.18, 0), trim, "Sash")
		plate(f, t, Vector3.new(s.X * 0.42, s.Y * 0.95, 0.08), CFrame.new(0, -s.Y * 0.3, -s.Z * 0.6 - 0.06), base, "Tab")
	end,
}

local function buildArmor(player, r)
	local char = player.Character
	if not char then
		return
	end
	local look = player:GetAttribute("ArmorLook") or ""
	local show = player:GetAttribute("ShowArmor") ~= false
	local key = (show and look or "") .. "|" .. tostring(char)
	local old = char:FindFirstChild("MystreeArmor")
	if r.ArmorKey == key and old then
		return
	end
	r.ArmorKey = key
	if old then
		old:Destroy()
	end
	if not show or look == "" then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MystreeArmor"
	for entry in string.gmatch(look, "[^,]+") do
		local slot, rs, setId = string.match(entry, "^(%a+):(%d+):(%w*)$")
		local rarity = tonumber(rs) or 1
		local build = ARMOR[slot or ""]
		if build then
			local set = setId ~= "" and Config.ArmorSets[setId]
			local tint = set and set.Color or Config.Rarities[math.clamp(rarity, 1, #Config.Rarities)].Color
			local base = LACQUER:Lerp(tint, set and 0.45 or 0.3)
			local trim = rarity >= 5 and GOLD or Config.Rarities[math.clamp(rarity, 1, #Config.Rarities)].Color
			build(folder, char, base, trim, rarity)
		end
	end
	folder.Parent = char
end
Equipment.buildArmor = buildArmor

-- ===================================================================== drawing and sheathing
-- r.Shown is what the character visibly holds ("Weapon", "Axe" or ""); it follows the "Held"
-- attribute through a move, swapping at the move's Swap point
local MOVE_TIME = 0.45
local MOVES = {
	-- cross-draw from the left hip, then a short flourish out to the side
	DrawHip = { Swap = 0.42, Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.38, Pose = { RightShoulder = { 10, 0, -40 }, RightElbow = { 70, 0, 0 }, Waist = { 0, 28, 0 } } },
		{ T = 0.68, Pose = { RightShoulder = { 95, 0, 45 }, RightElbow = { 10, 0, 0 }, Waist = { 0, -18, 0 } } },
		{ T = 1, Pose = {} },
	} },
	SheatheHip = { Swap = 0.6, Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.28, Pose = { RightShoulder = { 80, 0, 40 }, RightElbow = { 20, 0, 0 }, Waist = { 0, -12, 0 } } },
		{ T = 0.6, Pose = { RightShoulder = { 10, 0, -40 }, RightElbow = { 70, 0, 0 }, Waist = { 0, 28, 0 } } },
		{ T = 1, Pose = {} },
	} },
	-- over the right shoulder to the back
	DrawBack = { Swap = 0.4, Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.36, Pose = { RightShoulder = { 165, 0, 18 }, RightElbow = { 75, 0, 0 }, Waist = { 0, -10, 0 } } },
		{ T = 0.7, Pose = { RightShoulder = { 70, 0, 30 }, RightElbow = { 15, 0, 0 } } },
		{ T = 1, Pose = {} },
	} },
	SheatheBack = { Swap = 0.55, Keys = {
		{ T = 0, Pose = {} },
		{ T = 0.5, Pose = { RightShoulder = { 165, 0, 18 }, RightElbow = { 75, 0, 0 }, Waist = { 0, -10, 0 } } },
		{ T = 1, Pose = {} },
	} },
}

local function backItem(r, what)
	-- the axe always rides on the back; swords on the hip, long weapons on the back
	return what == "Axe" or (r.Weapon and r.Weapon.Class ~= "Sword")
end

-- play the move that takes `what` out (draw) or puts it away, swapping r.Shown mid-move
local function playMove(player, r, what, draw, done)
	local char = player.Character
	local back = backItem(r, what)
	local move = MOVES[(draw and "Draw" or "Sheathe") .. (back and "Back" or "Hip")]
	if char then
		Rig.play(char, move.Keys, MOVE_TIME, { Channel = "Draw" })
	end
	local gen = (r.MoveGen or 0) + 1
	r.MoveGen = gen
	task.delay(MOVE_TIME * move.Swap, function()
		if r.MoveGen ~= gen then
			return
		end
		r.Shown = draw and what or ""
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			if what == "Weapon" and draw and not back then
				Sounds.at("Glint", hrp.Position, 1.9, 0.8) -- the blade's "shing" leaving the scabbard
			else
				Sounds.at("Whoosh", hrp.Position, draw and 1.3 or 1.1, 0.4)
			end
		end
	end)
	task.delay(MOVE_TIME, function()
		if r.MoveGen == gen and done then
			done()
		end
	end)
end

-- go from r.Shown to `want`: put away what's out, then take out what's wanted
local function animateTo(player, r, want)
	local from = r.Shown or ""
	if from == want then
		return
	end
	if from ~= "" then
		playMove(player, r, from, false, function()
			if want ~= "" then
				playMove(player, r, want, true)
			end
		end)
	else
		playMove(player, r, want, true)
	end
end

-- what the character visibly holds right now (Chop places the axe from this)
function Equipment.shown(player)
	local r = rigs[player]
	return r and r.Shown or ""
end

-- the local player takes something out or puts it away: the move starts here at once, the
-- server's "Held" follows
local pending
function Equipment.setHeld(what)
	local r = rigs[localPlayer]
	if not r or pending == what or ((localPlayer:GetAttribute("Held") or "") == what and (r.Shown or "") == what) then
		return
	end
	pending = what
	animateTo(localPlayer, r, what)
	task.spawn(Net.invoke, "Hold", what)
end

function Equipment.held()
	return localPlayer:GetAttribute("Held") or ""
end

-- ===================================================================== players
local function refresh(player)
	local r = rigs[player]
	if not r then
		return
	end
	buildWeapon(player, r)
	buildArmor(player, r)
	buildCompanions(player, r)
	buildMount(player, r)
end

local function track(player)
	if rigs[player] then
		return
	end
	local r = { Companions = {}, CompLook = nil, Conns = {} }
	rigs[player] = r
	r.Shown = player:GetAttribute("Held") or ""
	for _, attr in ipairs({ "WeaponLook", "InGrounds", "Companions", "Riding", "Mount", "ArmorLook", "ShowArmor" }) do
		table.insert(r.Conns, player:GetAttributeChangedSignal(attr):Connect(function()
			refresh(player)
		end))
	end
	table.insert(r.Conns, player:GetAttributeChangedSignal("Held"):Connect(function()
		local held = player:GetAttribute("Held") or ""
		if player == localPlayer then
			-- our own move already started when we asked; only catch up if the server said otherwise
			if held ~= pending then
				animateTo(player, r, held)
			end
			pending = nil
		else
			animateTo(player, r, held)
		end
	end))
	table.insert(r.Conns, player.CharacterAdded:Connect(function()
		r.MoveGen = (r.MoveGen or 0) + 1
		r.Shown = player:GetAttribute("Held") or ""
		clearWeapon(r)
		if r.Mount then
			r.Mount.P.Model:Destroy()
			r.Mount = nil
		end
		r.CompLook = nil
		task.wait(0.5)
		refresh(player)
	end))
	refresh(player)
end

local function untrack(player)
	local r = rigs[player]
	if not r then
		return
	end
	rigs[player] = nil
	for _, c in ipairs(r.Conns) do
		c:Disconnect()
	end
	clearWeapon(r)
	clearCompanions(r)
	if r.Mount then
		r.Mount.P.Model:Destroy()
	end
end

function Equipment.Start(C)
	-- E: put away whatever is out, or draw the weapon (not while a prompt on E is showing)
	local prompts = 0
	ProximityPromptService.PromptShown:Connect(function()
		prompts += 1
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		prompts = math.max(0, prompts - 1)
	end)
	ContextActionService:BindAction("MystreeDraw", function(_, state)
		if state ~= Enum.UserInputState.Begin or prompts > 0 then
			return Enum.ContextActionResult.Pass
		end
		local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or localPlayer:GetAttribute("Riding") then
			return Enum.ContextActionResult.Pass
		end
		local r = rigs[localPlayer]
		Equipment.setHeld(((r and r.Shown) or "") ~= "" and "" or "Weapon")
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, pl in ipairs(Players:GetPlayers()) do
		task.spawn(track, pl)
	end
	-- companion attacks: the server reports the hit, the companion shows the shot
	Net.get("Hit").OnClientEvent:Connect(function(info)
		if not (info and info.Companion and info.By) then
			return
		end
		local r = rigs[info.By]
		if not r then
			return
		end
		for _, f in ipairs(r.Companions) do
			if f.Id == info.Companion then
				companionShot(f, info.Target)
				break
			end
		end
	end)
	local frame = 0
	RunService.Heartbeat:Connect(function(dt)
		frame += 1
		local now = os.clock()
		local camPos = camera.CFrame.Position
		for player, r in pairs(rigs) do
			local char, hrp, hum = charParts(player)
			if hrp and hum then
				local dist = (hrp.Position - camPos).Magnitude
				-- far players: ~20 Hz (every 3rd frame at 60 fps)
				if dist <= FAR or frame % 3 == 0 then
					local stepDt = (dist <= FAR) and dt or math.min(dt * 3, 0.1)
					local visible = onScreen(hrp.Position)
					if r.Weapon then
						placeWeapon(player, r, now)
					end
					for _, f in ipairs(r.Companions) do
						local ok, err = pcall(moveCompanion, f, hrp, hum, stepDt, now, visible)
						if not ok then
							warn("[Equipment] " .. tostring(err))
						end
					end
					if r.Mount then
						moveMount(r, hrp, now, visible)
					end
				end
			end
		end
	end)
end

return Equipment
