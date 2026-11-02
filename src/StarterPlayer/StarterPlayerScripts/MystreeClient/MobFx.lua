-- StarterPlayerScripts/MystreeClient/MobFx (ModuleScript)
-- Client look of every mob in workspace.Mobs (the server only sets attributes):
--  * engaging (user, 2026-10-27, MMO style): when a mob aggroes on you ("Aggro" = your UserId), a
--    faint crimson ring of two rotating slashes fades in under it, then its health bar shows. The
--    bar also shows for 10 s after you hit a mob. Bosses and Mythic beasts show theirs when you're near.
--  * the health bar: name, "Lv.N", HP with a white trailing bar; Elites, Rares, Bosses, Mythic
--    beasts and event mobs get a coloured frame, a bigger bar and a kind label; "x3 group" when
--    communal scaling raised its HP. Mutated mobs carry their mutation's name as the label.
--  * attacks (Deepwoken / Rune Slayer style, no ground circles): a glint flares at the head as the
--    wind-up starts (white, red for a heavy attack, with a growl); when it lands, a slash or claw
--    streak in front, a whoosh, and for shockwaves a ground ring, dust and a shake. Rigged animals
--    also play the attack pose (Gaits). A shockwave's reach shows as a faint ring while it winds up.
--  * death: the body topples over (a random fall: either side, forward or a slump), lands with a
--    thud and dust, then dissolves into ink wisps. Boss arrival: a big ground ring and a rumble.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Auras = require(ReplicatedStorage.Mystree.Auras)
local Format = require(ReplicatedStorage.Mystree.Format)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local MobFx = {}

local T = UI.T

-- frame colour and bar colour per kind
local KIND_STYLE = {
	Normal = { Frame = Color3.fromRGB(40, 36, 30), Bar = Color3.fromRGB(226, 84, 60), W = 150, H = 40, Label = nil },
	Elite = { Frame = Color3.fromRGB(200, 160, 70), Bar = Color3.fromRGB(196, 92, 220), W = 210, H = 50, Label = "ELITE" },
	Event = { Frame = Color3.fromRGB(230, 70, 60), Bar = Color3.fromRGB(240, 110, 60), W = 190, H = 48, Label = "EVENT" },
	Boss = { Frame = Color3.fromRGB(255, 210, 100), Bar = Color3.fromRGB(220, 40, 40), W = 320, H = 64, Label = "BOSS", Far = 400, Top = true },
	Rare = { Frame = Color3.fromRGB(110, 190, 255), Bar = Color3.fromRGB(70, 150, 240), W = 240, H = 52, Label = "RARE", Far = 220 },
	Mythic = { Frame = Color3.fromRGB(255, 225, 120), Bar = Color3.fromRGB(255, 170, 60), W = 380, H = 72, Label = "MYTHIC", Far = 700, Top = true, Shimmer = true },
}
-- big plates: bigger title and HP numbers
local BIG = { Boss = true, Mythic = true }

local function mutationOf(model)
	local id = model:GetAttribute("Mutation")
	local def = id and Config.Mutations[id]
	if not def then
		return nil
	end
	return def.Name, def.Glow or (def.Tint and def.Tint[1]) or T.Gold
end

local tracked = {} -- model -> { Conns, Gui, Fill, Trail, Telegraph, Ring, HitAt }
local player = game:GetService("Players").LocalPlayer

-- VFX Library art
local ART = {
	Arc = "rbxassetid://1266209505", -- "arc 3": the aggro ring's slashes
	Glint = "rbxassetid://1454292685", -- "Shine": the wind-up glint
	Slash = "rbxassetid://8077816591", -- "NewCrescent": gores, sweeps
	Claw = "rbxassetid://7216852545", -- "scratch_01": three claw marks, bites and pounces
	Smoke = "rbxassetid://17612093017", -- "CloudFadeRough4x4" Grid4x4: death wisps
}
local CRIMSON = Color3.fromRGB(214, 58, 50)
local BIG_BAR = { Boss = true, Mythic = true } -- show their bar when you're near (Config.MobAI.BossBarRange)
local HIT_SHOW = 10 -- s a mob's bar stays up after you hit it

local function groundBelow(pos, model)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Mobs"), Fx.Holder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos, Vector3.new(0, -60, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

-- ===================================================================== health bar
local function buildBar(model, root, e)
	local kind = model:GetAttribute("Kind") or "Normal"
	local st = KIND_STYLE[kind] or KIND_STYLE.Normal
	local _, size = model:GetBoundingBox()
	local g = Instance.new("BillboardGui")
	g.Name = "MobBar"
	g.Size = UDim2.fromOffset(st.W, st.H)
	g.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + (BIG[kind] and 2.5 or 1.4), 0)
	g.MaxDistance = st.Far or 120
	g.AlwaysOnTop = st.Top == true
	g.LightInfluence = 0
	g.ResetOnSpawn = false
	g.Adornee = root
	g.Parent = root
	local name = model:GetAttribute("Name") or model.Name
	local level = model:GetAttribute("Level") or 1
	local title = UI.text({ Name = "Title", Text = string.format('%s  <font color="#FFD66A">Lv.%d</font>', name, level), RichText = true,
		Size = UDim2.new(1, 0, 0.5, 0), TextSize = BIG[kind] and 22 or 16, Weight = Enum.FontWeight.Heavy, Parent = g })
	title.TextScaled = false
	local back = UI.new("Frame", { Name = "Back", Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.fromScale(0, 0.56),
		BackgroundColor3 = Color3.fromRGB(28, 24, 20), Parent = g })
	UI.corner(4, back)
	UI.stroke(back, st.Frame, (kind == "Normal") and 1.5 or 2.5)
	local trail = UI.new("Frame", { Name = "Trail", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = back })
	UI.corner(4, trail)
	local fill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = back })
	UI.corner(4, fill)
	UI.gradient(fill, st.Bar:Lerp(Color3.new(1, 1, 1), 0.2), st.Bar:Lerp(Color3.new(0, 0, 0), 0.2))
	local hpText = UI.text({ Name = "HP", Text = "", Size = UDim2.fromScale(1, 1), TextSize = BIG[kind] and 15 or 12,
		Weight = Enum.FontWeight.Bold, ZIndex = 3, Parent = back })
	-- the label: the kind (ELITE / RARE / MYTHIC ...) or, on a mutated mob, its mutation in its colour
	local mutName, mutColor = mutationOf(model)
	local label, labelColor = st.Label, st.Frame
	if mutName then
		label, labelColor = string.upper(mutName), mutColor
		local frame = back:FindFirstChildOfClass("UIStroke")
		frame.Color = mutColor
		frame.Thickness = 2
	end
	if label then
		local tag = UI.text({ Name = "Kind", Text = label, Size = UDim2.fromOffset(160, 16), Position = UDim2.new(0, 0, 0, -14),
			TextSize = BIG[kind] and 15 or 13, Weight = Enum.FontWeight.Heavy, TextColor3 = labelColor, TextXAlignment = Enum.TextXAlignment.Left, Parent = g })
		tag.ZIndex = 3
	end
	if st.Shimmer then
		-- Mythic: a slow rainbow sweep across the name and the bar
		local grad = UI.new("UIGradient", { Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 140)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(150, 255, 210)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(190, 160, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 140)),
		}), Parent = title })
		local stroke = back:FindFirstChildOfClass("UIStroke")
		e.Shimmer = RunService.Heartbeat:Connect(function()
			local t = os.clock()
			grad.Offset = Vector2.new(math.sin(t * 1.2) * 0.5, 0)
			if stroke then
				stroke.Color = Color3.fromHSV((t * 0.15) % 1, 0.45, 1)
			end
		end)
	end
	local group = UI.text({ Name = "Group", Text = "", Size = UDim2.fromOffset(80, 16), Position = UDim2.new(1, -80, 0, -14),
		TextSize = 13, Weight = Enum.FontWeight.Bold, TextColor3 = Color3.fromRGB(200, 230, 255), TextXAlignment = Enum.TextXAlignment.Right, Parent = g })
	e.Gui, e.Fill, e.Trail, e.HPText, e.Group = g, fill, trail, hpText, group
end

local function updateBar(model, e, instant)
	local hp = model:GetAttribute("HP") or 0
	local max = math.max(1, model:GetAttribute("MaxHP") or 1)
	local frac = math.clamp(hp / max, 0, 1)
	if instant then
		e.Fill.Size = UDim2.fromScale(frac, 1)
		e.Trail.Size = UDim2.fromScale(frac, 1)
	else
		TweenService:Create(e.Fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(frac, 1) }):Play()
		local gen = (e.TrailGen or 0) + 1
		e.TrailGen = gen
		task.delay(0.3, function()
			if e.TrailGen == gen and e.Trail.Parent then
				TweenService:Create(e.Trail, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
			end
		end)
	end
	local kind = model:GetAttribute("Kind")
	if kind ~= "Normal" and kind ~= "Event" then
		e.HPText.Text = Format.Num(hp) .. " / " .. Format.Num(max)
	end
	local scale = model:GetAttribute("Scale") or 1
	e.Group.Text = (scale > 1) and ("x" .. scale .. " group") or ""
end

-- ===================================================================== engaging: aggro ring + bar
local function setRing(model, root, e, on)
	if on and not e.Ring then
		local _, size = model:GetBoundingBox()
		-- a little smaller than the body's footprint (user)
		local r = math.max(size.X, size.Z) * 0.42
		local p = Instance.new("Part")
		p.Name = "AggroRing"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(r * 2, 0.05, r * 2)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Top
		sg.LightInfluence = 0
		sg.CanvasSize = Vector2.new(256, 256)
		sg.Parent = p
		local arcs = {}
		for i = 0, 1 do
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = ART.Arc
			img.ImageColor3 = CRIMSON
			img.ImageTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Rotation = i * 180
			img.Parent = sg
			table.insert(arcs, img)
		end
		p.Parent = Fx.Holder
		e.Ring = { Part = p, Arcs = arcs }
		for _, img in ipairs(arcs) do
			TweenService:Create(img, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { ImageTransparency = 0.62 }):Play()
		end
		local spin = 0
		e.Ring.Conn = RunService.Heartbeat:Connect(function(dt)
			if not root.Parent then
				return
			end
			spin += dt * 70
			local g = groundBelow(root.Position, model)
			p.CFrame = CFrame.new(g + Vector3.new(0, 0.06, 0))
			arcs[1].Rotation = spin
			arcs[2].Rotation = spin + 180
		end)
	elseif not on and e.Ring then
		local ring = e.Ring
		e.Ring = nil
		for _, img in ipairs(ring.Arcs) do
			TweenService:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { ImageTransparency = 1 }):Play()
		end
		task.delay(0.32, function()
			ring.Conn:Disconnect()
			ring.Part:Destroy()
		end)
	end
end

-- the ring fades in first, then the bar shows (and hides again once the fight is over)
local function refreshEngaged(model, root, e)
	if e.Died or not e.Gui then
		return
	end
	local aggro = model:GetAttribute("Aggro") == player.UserId
	setRing(model, root, e, aggro)
	local near = false
	if BIG_BAR[model:GetAttribute("Kind") or ""] then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		near = hrp ~= nil and (hrp.Position - root.Position).Magnitude < Config.MobAI.BossBarRange
	end
	local show = aggro or near or os.clock() - (e.HitAt or -99) < HIT_SHOW
	if show and not e.Gui.Enabled then
		local gen = (e.ShowGen or 0) + 1
		e.ShowGen = gen
		task.delay(aggro and 0.35 or 0, function()
			if e.ShowGen == gen and not e.Died then
				e.Gui.Enabled = true
			end
		end)
	elseif not show then
		e.ShowGen = (e.ShowGen or 0) + 1
		e.Gui.Enabled = false
	end
end

-- ===================================================================== attacks
local function emitOnce(at, props)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Speed = NumberRange.new(0)
	pe.LightEmission = props.Light or 0.5
	pe.Texture = props.Texture
	pe.Size = NumberSequence.new(props.Size)
	pe.Lifetime = NumberRange.new(props.Life or 0.25)
	pe.Color = ColorSequence.new(props.Color or Color3.new(1, 1, 1))
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, props.Alpha or 0.15), NumberSequenceKeypoint.new(1, 1) })
	pe.Rotation = NumberRange.new(props.Rot or 0)
	pe.Orientation = Enum.ParticleOrientation.FacingCamera
	if props.Flipbook then
		pe.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		pe.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	pe.Parent = a
	pe:Emit(props.Count or 1)
	task.delay((props.Life or 0.25) + 0.3, function()
		a:Destroy()
	end)
end

local function glint(model, root, heavy)
	local _, size = model:GetBoundingBox()
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local b = Instance.new("BillboardGui")
	b.Name = "Glint"
	b.Size = UDim2.fromOffset(10, 10)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.StudsOffsetWorldSpace = look * size.Z * 0.42 + Vector3.new(0, size.Y * 0.25, 0)
	b.Adornee = root
	b.Parent = Fx.Holder
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = ART.Glint
	img.ImageColor3 = heavy and CRIMSON or Color3.fromRGB(255, 250, 235)
	img.Size = UDim2.fromScale(1, 1)
	img.Parent = b
	local big = heavy and 140 or 95
	TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(big, big) }):Play()
	TweenService:Create(img, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Rotation = 90 }):Play()
	task.delay(0.16, function()
		TweenService:Create(b, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(4, 4) }):Play()
		TweenService:Create(img, TweenInfo.new(0.24), { ImageTransparency = 1 }):Play()
	end)
	task.delay(0.45, function()
		b:Destroy()
	end)
	Sounds.at("Glint", root.Position, heavy and 1.2 or 1.6)
	if heavy or math.random() < 0.3 then
		Sounds.at("Growl", root.Position, heavy and 0.75 or 1.05, heavy and 1 or 0.6)
	end
end

local function strike(model, root, anim, heavy, shock, range)
	if not root.Parent or model:GetAttribute("Dead") then
		return
	end
	local _, size = model:GetBoundingBox()
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local front = root.Position + look * (size.Z * 0.55 + 1.5) + Vector3.new(0, size.Y * 0.1, 0)
	local tint = heavy and CRIMSON:Lerp(Color3.new(1, 1, 1), 0.35) or Color3.new(1, 1, 1)
	Sounds.at("MobSwing", root.Position, heavy and 0.8 or 1 + math.random() * 0.2)
	if anim == "Bite" or anim == "Lunge" then
		emitOnce(front, { Texture = ART.Claw, Size = size.Y * 1.1 + 2, Life = 0.28, Color = tint, Rot = math.random(-30, 30) })
	elseif anim == "Swipe" or anim == "Gore" then
		emitOnce(front, { Texture = ART.Slash, Size = size.X * 1.4 + 4, Life = 0.22, Color = tint, Rot = math.random(-160, -110) })
	end
	if shock then
		local g = groundBelow(root.Position, model)
		Fx.ring(g, Color3.fromRGB(255, 236, 210), range * 2, 0.45)
		Fx.burst(g, { Texture = "Smoke", Color = Color3.fromRGB(190, 172, 146), Count = 16, Speed = { 10, 20 }, Size = 3, EndSize = 2, Lifetime = { 0.5, 0.9 }, Alpha = 0.35, Gravity = Vector3.new(0, 4, 0), Spread = 80 })
		Sounds.at("MobStomp", g, 1)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - g).Magnitude < range * 2.5 then
			Fx.shake(1.8, 0.35)
		end
	end
end

-- a shockwave's reach: a faint crimson ring that tightens to the hit
local function shockHint(model, root, e, range, total)
	if e.Telegraph then
		e.Telegraph:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = "Telegraph"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = CRIMSON
	p.Transparency = 1
	p.Size = Vector3.new(0.05, range * 2, range * 2)
	p.CFrame = CFrame.new(groundBelow(root.Position, model) + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Fx.Holder
	e.Telegraph = p
	TweenService:Create(p, TweenInfo.new(total, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.8 }):Play()
	task.delay(total + 0.05, function()
		p:Destroy()
		if e.Telegraph == p then
			e.Telegraph = nil
		end
	end)
end

local function onWindup(model, root, e)
	local lands = model:GetAttribute("Windup")
	if type(lands) ~= "number" then
		return
	end
	local total = lands - workspace:GetServerTimeNow()
	if total <= 0 then
		return
	end
	local anim = model:GetAttribute("AttackAnim")
	local heavy = model:GetAttribute("AttackHeavy") == true
	local shock = model:GetAttribute("AttackShock") == true
	local range = model:GetAttribute("AttackRange") or 0
	glint(model, root, heavy)
	if shock and range > 0 then
		shockHint(model, root, e, range, total)
	end
	task.delay(total, strike, model, root, anim, heavy, shock, range)
end

-- ===================================================================== death
-- the body falls over around a point on the ground at its edge (anchored by the server, so moving it
-- here stays local), lands with a thud, then dissolves into ink wisps
local FALLS = {
	function(w, d) -- onto its right side
		return Vector3.new(w / 2, 0, 0), CFrame.Angles(0, 0, math.rad(-82))
	end,
	function(w, d) -- onto its left side
		return Vector3.new(-w / 2, 0, 0), CFrame.Angles(0, 0, math.rad(82))
	end,
	function(w, d) -- forward onto its face
		return Vector3.new(0, 0, -d / 2), CFrame.Angles(math.rad(-58), 0, 0)
	end,
	function(w, d) -- a slump: sinks and leans
		return Vector3.new(w / 4, 0, 0), CFrame.Angles(math.rad(-14), 0, math.rad(-30)), true
	end,
}

local function die(model, root, e)
	if e.Died then
		return
	end
	e.Died = true
	if e.Gui then
		e.Gui.Enabled = false
	end
	setRing(model, root, e, false)
	if e.Telegraph then
		e.Telegraph:Destroy()
	end
	local start = model:GetPivot()
	local cf, size = model:GetBoundingBox()
	local ground = groundBelow(cf.Position, model)
	local edge, turn, slump = FALLS[math.random(1, #FALLS)](size.X, size.Z)
	local hinge = CFrame.new(ground) * (cf - cf.Position) * CFrame.new(edge)
	local rel = hinge:Inverse() * start
	local t0 = os.clock()
	local fall = 0.55
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		local a = math.min(1, (os.clock() - t0) / fall)
		local k = a * a -- falls faster as it goes, like gravity
		if a >= 1 then
			-- a small settle after the impact
			local b = math.min(1, (os.clock() - t0 - fall) / 0.14)
			k = 1 - 0.06 * math.sin(b * math.pi)
		end
		local sink = slump and CFrame.new(0, -size.Y * 0.18 * k, 0) or CFrame.new()
		model:PivotTo(hinge * sink * CFrame.new():Lerp(turn, k) * rel)
		if os.clock() - t0 > fall + 0.15 then
			conn:Disconnect()
		end
	end)
	local def = Config.Mobs[model:GetAttribute("MobId") or ""]
	local color = def and def.Color or Color3.fromRGB(200, 200, 200)
	task.delay(fall, function()
		Sounds.at("MobFall", ground, size.Y > 6 and 0.75 or 1)
		Fx.burst(ground, { Texture = "Smoke", Color = color:Lerp(Color3.fromRGB(200, 190, 170), 0.5), Count = 12, Speed = { 4, 9 }, Size = 2.5, EndSize = 1.6, Lifetime = { 0.6, 1.1 }, Alpha = 0.4, Gravity = Vector3.new(0, 2, 0), Spread = 80 })
		if size.Y > 6 then
			Fx.shake(1.2, 0.3)
		end
	end)
	local kind = model:GetAttribute("Kind")
	if kind == "Mythic" or kind == "Rare" then
		local st = KIND_STYLE[kind]
		Fx.ring(ground, st.Frame, kind == "Mythic" and 50 or 24, 0.7)
		Fx.burst(cf.Position, { Texture = "Glow", Color = st.Frame, Count = kind == "Mythic" and 40 or 18, Speed = { 8, 22 }, Size = 1.1, Light = 1, Lifetime = { 0.8, 1.4 },
			Gravity = Vector3.new(0, 6, 0), Spread = 180 })
	end
	-- dissolve: the body fades while ink wisps rise from it
	task.delay(fall + 0.5, function()
		if not model.Parent then
			return
		end
		local p = model:GetBoundingBox().Position
		for _ = 1, 3 do
			emitOnce(p + Vector3.new(math.random(-10, 10) / 10 * size.X * 0.4, 0, math.random(-10, 10) / 10 * size.Z * 0.4),
				{ Texture = ART.Smoke, Flipbook = true, Size = math.max(size.X, size.Y) * 0.6, Life = 0.9, Color = Color3.fromRGB(26, 24, 28), Alpha = 0.35, Light = 0, Rot = math.random(0, 360) })
		end
		local info = TweenInfo.new(0.85)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			elseif d:IsA("Light") then
				TweenService:Create(d, info, { Brightness = 0 }):Play()
			end
		end
	end)
end

-- ===================================================================== tracking
local function untrack(model)
	local e = tracked[model]
	if not e then
		return
	end
	tracked[model] = nil
	for _, c in ipairs(e.Conns) do
		c:Disconnect()
	end
	if e.Shimmer then
		e.Shimmer:Disconnect()
	end
	if e.Telegraph then
		e.Telegraph:Destroy()
	end
	if e.Ring then
		e.Ring.Conn:Disconnect()
		e.Ring.Part:Destroy()
	end
	if e.Aura then
		e.Aura.Destroy()
	end
end

local function track(model)
	if tracked[model] or not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart", 5)
	if not root or not model.Parent then
		return
	end
	local e = { Conns = {} }
	tracked[model] = e
	buildBar(model, root, e)
	updateBar(model, e, true)
	e.Gui.Enabled = false
	refreshEngaged(model, root, e)
	e.Root = root
	for _, attr in ipairs({ "HP", "MaxHP", "Scale" }) do
		table.insert(e.Conns, model:GetAttributeChangedSignal(attr):Connect(function()
			updateBar(model, e)
		end))
	end
	table.insert(e.Conns, model:GetAttributeChangedSignal("Windup"):Connect(function()
		onWindup(model, root, e)
	end))
	table.insert(e.Conns, model:GetAttributeChangedSignal("Aggro"):Connect(function()
		refreshEngaged(model, root, e)
	end))
	table.insert(e.Conns, model:GetAttributeChangedSignal("Dead"):Connect(function()
		if model:GetAttribute("Dead") then
			if e.Aura then
				e.Aura.Stop()
			end
			die(model, root, e)
		end
	end))
	-- Mythic beasts carry a passive aura (Config.Mobs[id].Aura, ReplicatedStorage.Mystree.Auras)
	local auraDef = Config.Mobs[model:GetAttribute("MobId") or ""]
	if auraDef and auraDef.Aura and not model:GetAttribute("Dead") then
		e.Aura = Auras.attach(model, auraDef.Aura)
	end
	table.insert(e.Conns, model.Destroying:Connect(function()
		untrack(model)
	end))
	if model:GetAttribute("Dead") then
		die(model, root, e)
	elseif model:GetAttribute("Kind") == "Boss" or model:GetAttribute("Kind") == "Mythic" then
		local g = groundBelow(root.Position + Vector3.new(0, 2, 0), model)
		local def = Config.Mobs[model:GetAttribute("MobId") or ""]
		local mythic = model:GetAttribute("Kind") == "Mythic"
		Fx.ring(g, mythic and KIND_STYLE.Mythic.Frame or (def and def.Color or Color3.fromRGB(220, 40, 40)), mythic and 90 or 60, 0.9)
		Fx.ring(g, Color3.fromRGB(255, 240, 220), 36, 0.6)
		if mythic then
			Fx.beam(g, KIND_STYLE.Mythic.Frame, 120, 4)
		end
		Fx.shake(1.6, 0.5)
		Sounds.play("Quake", 0.8, 0.8)
	elseif model:GetAttribute("Kind") == "Rare" then
		local g = groundBelow(root.Position + Vector3.new(0, 2, 0), model)
		Fx.ring(g, KIND_STYLE.Rare.Frame, 30, 0.7)
	end
end

-- mobs you hit show their bar for HIT_SHOW s
function MobFx.noteHit(model)
	local e = tracked[model]
	if e and e.Root then
		e.HitAt = os.clock()
		refreshEngaged(model, e.Root, e)
	end
end

function MobFx.Start(C)
	local folder = workspace:WaitForChild("Mobs")
	-- bars of mobs you only hit hide again HIT_SHOW s later; boss bars come and go with distance
	task.spawn(function()
		while true do
			task.wait(0.5)
			for model, e in pairs(tracked) do
				if e.Root and e.Gui and (BIG_BAR[model:GetAttribute("Kind") or ""] or (e.HitAt and os.clock() - e.HitAt > HIT_SHOW and e.Gui.Enabled)) then
					refreshEngaged(model, e.Root, e)
				end
			end
		end
	end)
	folder.ChildAdded:Connect(function(m)
		task.spawn(track, m)
	end)
	folder.ChildRemoved:Connect(untrack)
	for _, m in ipairs(folder:GetChildren()) do
		task.spawn(track, m)
	end
end

return MobFx
