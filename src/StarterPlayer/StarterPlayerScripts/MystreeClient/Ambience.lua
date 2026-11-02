-- StarterPlayerScripts/MystreeClient/Ambience (ModuleScript)
-- Quiet looping beds under the music, chosen by where you are and the time of day (Config.Ambience).
-- One Sound per bed for its lifetime: changing place only changes target volumes, so a bed shared by
-- two places carries on. A bed silent for StopAfter seconds stops, and restarts at a random point
-- to hide the loop seam. Client only; follows the Sound Effects setting through the SFX group.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Sounds = require(script.Parent.Sounds)

local Ambience = {}
local A = Config.Ambience
local player = Players.LocalPlayer

local beds = {} -- name -> { Sound, Volume, SilentFor }

local function bedOf(name)
	local bed = beds[name]
	if bed then
		return bed
	end
	local s = Instance.new("Sound")
	s.Name = "Ambience" .. name
	s.SoundId = "rbxassetid://" .. A.Beds[name].Id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = Sounds.group()
	s.Parent = SoundService
	bed = { Sound = s, Volume = 0, SilentFor = 0 }
	beds[name] = bed
	return bed
end

local function onIsland()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not root or not plots then
		return false
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") and (plot:GetPivot().Position - root.Position).Magnitude < A.IslandRadius then
			return true
		end
	end
	return false
end

-- the place's bed volumes for right now
local function targets()
	local zone = player:GetAttribute("Zone") or "Village"
	if zone == "Village" and onIsland() then
		zone = "Island"
	end
	local place = A.Places[zone] or A.Places.Village
	local want = {}
	for name in pairs(A.Beds) do
		want[name] = place[name] or 0
	end
	local phase = workspace:GetAttribute("CyclePhase")
	if phase == "Night" and not place.NoNight then
		want.Night = A.Night
	end
	return want
end

local function step(dt)
	local want = targets()
	for name, volume in pairs(want) do
		if volume > 0 or beds[name] then
			local bed = bedOf(name)
			if volume > 0 and not bed.Sound.IsPlaying then
				if bed.Sound.TimeLength > 0 then
					bed.Sound.TimePosition = math.random() * bed.Sound.TimeLength
				end
				bed.Sound:Play()
			end
			local rate = math.max(volume, bed.Volume, 0.05) * dt / A.Fade
			bed.Volume += math.clamp(volume - bed.Volume, -rate, rate)
			bed.Sound.Volume = bed.Volume
			bed.SilentFor = (bed.Volume <= 0.001) and (bed.SilentFor + dt) or 0
			if bed.SilentFor > A.StopAfter and bed.Sound.IsPlaying then
				bed.Sound:Stop()
			end
		end
	end
end

function Ambience.Start()
	task.spawn(function()
		-- starts with the music, as the loading screen fades into the game
		local t0 = os.clock()
		while not player:GetAttribute("Loaded") and os.clock() - t0 < 60 do
			task.wait(0.2)
		end
		while true do
			step(task.wait(A.Poll))
		end
	end)
end

return Ambience
