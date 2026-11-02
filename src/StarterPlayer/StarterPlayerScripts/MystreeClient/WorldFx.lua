-- StarterPlayerScripts/MystreeClient/WorldFx (ModuleScript)
-- Lighting for the synced 5-minute day/night cycle and its events, read from the workspace
-- attributes WorldService sets (CyclePhase, CycleEvent, CycleStart, CycleEnd).
--  * ClockTime runs across each phase (Config.Lighting[preset].ClockFrom -> ClockTo).
--  * Switching preset tweens ambient, colour grade, atmosphere and bloom over 3 s.
--  * Bloodmoon: a big red moon and drifting red ash. Golden Hour: warm motes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local State = require(script.Parent.State)

local WorldFx = {}

local function ensure(class, name, parent)
	local o = parent:FindFirstChild(name)
	if not o then
		o = Instance.new(class)
		o.Name = name
		o.Parent = parent
	end
	return o
end

local atmos = ensure("Atmosphere", "MystreeAtmosphere", Lighting)
local grade = ensure("ColorCorrectionEffect", "MystreeGrade", Lighting)
local bloom = ensure("BloomEffect", "MystreeBloom", Lighting)
local rays = ensure("SunRaysEffect", "MystreeSunRays", Lighting)
local sky = Lighting:FindFirstChildOfClass("Sky") or ensure("Sky", "MystreeSky", Lighting)
bloom.Intensity = 0.6
bloom.Size = 28
bloom.Threshold = 1.6
rays.Intensity = 0.06
rays.Spread = 0.8
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.7
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.25
pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)

local current
local function preset()
	local ev = workspace:GetAttribute("CycleEvent") or ""
	if ev ~= "" and Config.Lighting[ev] then
		return ev
	end
	return workspace:GetAttribute("CyclePhase") or "Day"
end

-- ambient particles that follow the camera (Bloodmoon ash, Golden Hour motes)
local camera = workspace.CurrentCamera
local motesPart = Instance.new("Part")
motesPart.Name = "AmbientMotes"
motesPart.Anchored = true
motesPart.CanCollide = false
motesPart.CanQuery = false
motesPart.CanTouch = false
motesPart.Transparency = 1
motesPart.Size = Vector3.new(80, 1, 80)
motesPart.Parent = workspace
local motes = Instance.new("ParticleEmitter")
motes.Texture = Config.Particles.Glow
motes.Rate = 0
motes.Lifetime = NumberRange.new(5, 8)
motes.Speed = NumberRange.new(0.5, 2)
motes.SpreadAngle = Vector2.new(180, 180)
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 0) })
motes.LightEmission = 1
motes.Acceleration = Vector3.new(0, -0.5, 0)
motes.Parent = motesPart

local function apply(name, instant)
	current = name
	local L = Config.Lighting[name]
	local info = TweenInfo.new(instant and 0 or 3, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { Ambient = L.Ambient, OutdoorAmbient = L.Ambient:Lerp(Color3.new(1, 1, 1), 0.25), Brightness = L.Bright }):Play()
	TweenService:Create(grade, info, { TintColor = L.Tint, Saturation = L.Sat, Contrast = L.Contrast }):Play()
	TweenService:Create(atmos, info, { Color = L.Atmos, Decay = L.Atmos:Lerp(Color3.new(0, 0, 0), 0.3), Haze = L.Haze, Density = L.Density, Glare = (name == "Day" or name == "GoldenHour") and 0.4 or 0 }):Play()
	sky.MoonAngularSize = (name == "Bloodmoon") and 40 or 11
	sky.SunAngularSize = (name == "GoldenHour") and 28 or 18
	if name == "Bloodmoon" then
		motes.Color = ColorSequence.new(Color3.fromRGB(255, 70, 50), Color3.fromRGB(120, 10, 10))
		motes.Rate = State.setting("Particles") and 26 or 0
		motes.Acceleration = Vector3.new(0, 0.6, 0)
	elseif name == "GoldenHour" then
		motes.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 180, 70))
		motes.Rate = State.setting("Particles") and 20 or 0
		motes.Acceleration = Vector3.new(0, 0.3, 0)
	elseif name == "Night" then
		-- fireflies
		motes.Color = ColorSequence.new(Color3.fromRGB(190, 255, 170))
		motes.Rate = State.setting("Particles") and 8 or 0
		motes.Acceleration = Vector3.new(0, 0, 0)
	else
		motes.Rate = 0
	end
end

function WorldFx.Start(C)
	apply(preset(), true)
	local function onChange()
		local p = preset()
		if p ~= current then
			apply(p)
		end
	end
	workspace:GetAttributeChangedSignal("CyclePhase"):Connect(onChange)
	workspace:GetAttributeChangedSignal("CycleEvent"):Connect(onChange)
	RunService.Heartbeat:Connect(function()
		local s, e = workspace:GetAttribute("CycleStart"), workspace:GetAttribute("CycleEnd")
		if s and e then
			local t = math.clamp((workspace:GetServerTimeNow() - s) / math.max(1, e - s), 0, 1)
			local L = Config.Lighting[current]
			Lighting.ClockTime = (L.ClockFrom + (L.ClockTo - L.ClockFrom) * t) % 24
		end
		motesPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 12, 0))
	end)
end

-- seconds left in the current phase, for the HUD clock
function WorldFx.timeLeft()
	local e = workspace:GetAttribute("CycleEnd")
	return e and math.max(0, e - workspace:GetServerTimeNow()) or 0
end

return WorldFx
