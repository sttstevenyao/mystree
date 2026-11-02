-- StarterPlayerScripts/MystreeClient/Fx (ModuleScript)
-- Shared client effects: camera shake, particle bursts, rising numbers, rings, loot beams, screen
-- flashes and hit-stop. Everything is client-only and cleans itself up (Debris backstop).
-- Respects the ScreenShake / Particles / Flashing settings.

local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Fx = {}

local camera = workspace.CurrentCamera
local P = Config.Particles

local holder = Instance.new("Folder")
holder.Name = "MystreeFx"
holder.Parent = workspace

local function anchor(pos)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = holder
	return p
end
Fx.anchor = anchor

-- ===================================================================== camera shake
local shakes = {}
function Fx.shake(intensity, duration)
	if not State.setting("ScreenShake") or GuiService.ReducedMotionEnabled then
		return
	end
	table.insert(shakes, { I = intensity, D = duration or 0.2, Start = os.clock() })
end

-- noise speed is capped at 0.4 x the frame rate: 22 Hz shake at 30 fps reads as teleporting
local lastOffset = CFrame.new()
local fps = 60
RunService:BindToRenderStep("MystreeShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	fps += (1 / math.max(dt, 1 / 240) - fps) * 0.1
	local freq = math.min(22, 0.4 * fps)
	local now = os.clock()
	local x, y = 0, 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local t = (now - s.Start) / s.D
		if t >= 1 then
			table.remove(shakes, i)
		else
			local k = s.I * (1 - t) ^ 2
			x += math.noise(now * freq, i * 3.1) * k
			y += math.noise(i * 7.7, now * freq) * k
		end
	end
	local off = CFrame.Angles(math.rad(y), math.rad(x), 0)
	if x ~= 0 or y ~= 0 or lastOffset ~= CFrame.new() then
		camera.CFrame = camera.CFrame * off
	end
	lastOffset = off
end)

-- ===================================================================== particles
-- opts: Texture (key of Config.Particles), Color, Count, Speed {min,max}, Size, Lifetime {min,max},
-- Spread (degrees), Gravity (Vector3), Dir (Vector3 normal), Rotation, Light (0..1)
function Fx.burst(pos, opts)
	if not State.setting("Particles") and not opts.Always then
		return
	end
	local a = anchor(pos)
	if opts.Dir then
		a.CFrame = CFrame.lookAt(pos, pos + opts.Dir) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = P[opts.Texture or "Square"]
	e.Color = ColorSequence.new(opts.Color or Color3.new(1, 1, 1), opts.Color2 or opts.Color or Color3.new(1, 1, 1))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.Size or 0.4), NumberSequenceKeypoint.new(1, (opts.Size or 0.4) * (opts.EndSize or 0.2)) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.Alpha or 0), NumberSequenceKeypoint.new(0.7, opts.Alpha or 0), NumberSequenceKeypoint.new(1, 1) })
	local sp = opts.Speed or { 10, 20 }
	e.Speed = NumberRange.new(sp[1], sp[2])
	local lt = opts.Lifetime or { 0.4, 0.8 }
	e.Lifetime = NumberRange.new(lt[1], lt[2])
	e.SpreadAngle = Vector2.new(opts.Spread or 60, opts.Spread or 60)
	e.Acceleration = opts.Gravity or Vector3.new(0, -40, 0)
	e.Rotation = NumberRange.new(0, 360)
	local rot = opts.Rotation or 200
	e.RotSpeed = NumberRange.new(-rot, rot)
	e.LightEmission = opts.Light or 0
	e.Drag = opts.Drag or 2
	e.Rate = 0
	e.Parent = a
	e:Emit(opts.Count or 12)
	Debris:AddItem(a, lt[2] + 0.2)
	return a
end

-- Expanding flat ring on the ground (shockwaves, landings)
function Fx.ring(pos, color, size, duration)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.new(1, 1, 1)
	p.Transparency = 0.25
	p.Size = Vector3.new(0.12, 1, 1)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.CastShadow = false
	p.Parent = holder
	local d = duration or 0.45
	TweenService:Create(p, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, size or 12, size or 12), Transparency = 1 }):Play()
	Debris:AddItem(p, d + 0.1)
	return p
end

-- A vertical light beam in the rarity colour (loot drops). Returns the model; fades after duration.
function Fx.beam(pos, color, height, duration)
	local m = Instance.new("Model")
	m.Name = "LootBeam"
	local core = Instance.new("Part")
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Material = Enum.Material.Neon
	core.Color = color
	core.Shape = Enum.PartType.Cylinder
	core.Size = Vector3.new(height, 0.7, 0.7)
	core.CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	core.Transparency = 0.15
	core.Parent = m
	local glow = core:Clone()
	glow.Size = Vector3.new(height, 2.2, 2.2)
	glow.Transparency = 0.75
	glow.Parent = m
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 3
	light.Parent = core
	-- rising motes up the beam
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(-height / 2 + 0.5, 0, 0)
	a.Parent = core
	local e = Instance.new("ParticleEmitter")
	e.Texture = P.Glow
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Speed = NumberRange.new(6, 12)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Rate = 14
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Right
	e.Parent = a
	m.Parent = holder
	core.Size = Vector3.new(height, 0.05, 0.05)
	TweenService:Create(core, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = Vector3.new(height, 0.7, 0.7) }):Play()
	task.delay(duration or 3, function()
		e.Enabled = false
		for _, part in ipairs({ core, glow }) do
			TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
		TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	end)
	Debris:AddItem(m, (duration or 3) + 1.5)
	return m
end

-- ===================================================================== floating text (damage numbers, +Scraps)
-- opts: Color, Size (px), Crit (bigger + shake), Rise (studs), Time
function Fx.float(pos, text, opts)
	opts = opts or {}
	local a = anchor(pos)
	local size = opts.Size or 30
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(240, size * 1.6)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 160
	g.Parent = a
	local l = UI.text({ Text = text, Size = UDim2.fromScale(1, 1), TextSize = size, Weight = Enum.FontWeight.Heavy,
		Italic = opts.Crit, TextColor3 = opts.Color or Color3.new(1, 1, 1), Stroke = opts.Stroke or Color3.fromRGB(30, 20, 14), StrokeThickness = 2.2, Parent = g })
	local s = Instance.new("UIScale")
	s.Scale = opts.Crit and 1.9 or 1.4
	s.Parent = l
	TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local rise = opts.Rise or 4
	local t = opts.Time or 0.9
	local jitter = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
	TweenService:Create(a, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(pos + jitter + Vector3.new(0, rise, 0)) }):Play()
	task.delay(t * 0.6, function()
		TweenService:Create(l, TweenInfo.new(t * 0.4), { TextTransparency = 1 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(t * 0.4), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(a, t + 0.1)
end

-- ===================================================================== screen
local flashGui = Instance.new("ScreenGui")
flashGui.Name = "MystreeFlash"
flashGui.IgnoreGuiInset = true
flashGui.ScreenInsets = Enum.ScreenInsets.None -- IgnoreGuiInset alone now stops at the notch
flashGui.DisplayOrder = 50
flashGui.ResetOnSpawn = false
flashGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = flashGui

function Fx.flash(color, alpha, duration)
	if not State.setting("Flashing") then
		alpha = math.max(alpha or 0.6, 0.85)
	end
	flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = alpha or 0.6
	TweenService:Create(flash, TweenInfo.new(duration or 0.35), { BackgroundTransparency = 1 }):Play()
end

-- Hit-stop: a tiny camera FOV punch (the world can't be paused client-side, so we sell the impact)
-- (the resting FOV is remembered, so punches that overlap don't ratchet the FOV down)
local punchBase, punchTween
function Fx.punch(amount)
	if GuiService.ReducedMotionEnabled then
		return
	end
	punchBase = punchTween and punchBase or camera.FieldOfView
	if punchTween then
		punchTween:Cancel()
	end
	camera.FieldOfView = punchBase - (amount or 2)
	local tween = TweenService:Create(camera, TweenInfo.new(0.12), { FieldOfView = punchBase })
	punchTween = tween
	tween.Completed:Connect(function()
		if punchTween == tween then
			punchTween = nil
		end
	end)
	tween:Play()
end

Fx.Holder = holder

return Fx
