-- StarterPlayerScripts/MystreeClient/Sounds (ModuleScript)
-- UI and gameplay sounds plus the music playlist. Respects the Music / Sfx settings.
-- Ids and volumes: Config.Sounds / Config.Music. Sounds.play(name, speed, volumeScale)
-- Sounds.at(name, position) plays a 3D sound in the world (chops at other plots, hits).
-- A slot with Ids picks a take at random, never the same one twice in a row. With no speed passed,
-- the pitch varies a little (Config.SoundVary). Sounds.group() is the SFX group, for Ambience.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local State = require(script.Parent.State)

local Sounds = {}

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Parent = SoundService

local lastTake = {}
local function idOf(def, name)
	local ids = def.Ids
	if not ids or #ids < 2 then
		return def.Id
	end
	local k = math.random(1, #ids - 1)
	if k >= (lastTake[name] or #ids) then
		k += 1
	end
	lastTake[name] = k
	return ids[k]
end

local function speedOf(def, speed)
	if speed then
		return speed
	end
	return (def.Speed or 1) * (1 + (math.random() * 2 - 1) * Config.SoundVary)
end

function Sounds.group()
	return sfxGroup
end

local cache = {}
local function make(name)
	local def = Config.Sounds[name]
	if not def then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. def.Id
	s.Volume = def.Volume or 0.5
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	return s
end

-- Overlapping plays (fast chops) clone the cached sound so they don't cut each other off
function Sounds.play(name, speed, volumeScale)
	cache[name] = cache[name] or make(name)
	local base = cache[name]
	if not base then
		return
	end
	local def = Config.Sounds[name]
	local s = base
	if base.IsPlaying then
		s = base:Clone()
		s.Parent = SoundService
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	s.SoundId = "rbxassetid://" .. idOf(def, name)
	s.PlaybackSpeed = speedOf(def, speed)
	s.Volume = (def.Volume or 0.5) * (volumeScale or 1)
	s.TimePosition = 0
	s:Play()
end

function Sounds.at(name, position, speed, volumeScale)
	local def = Config.Sounds[name]
	if not def then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. idOf(def, name)
	s.Volume = (def.Volume or 0.5) * (volumeScale or 1)
	s.PlaybackSpeed = speedOf(def, speed)
	s.RollOffMaxDistance = 140
	s.SoundGroup = sfxGroup
	s.Parent = a
	s:Play()
	-- long takes (thunder) must not be cut off
	task.delay(8, function()
		a:Destroy()
	end)
end

local function applySettings()
	sfxGroup.Volume = State.setting("Sfx") and 1 or 0
	musicGroup.Volume = State.setting("Music") and 1 or 0
end

function Sounds.Start()
	applySettings()
	State.Changed:Connect(applySettings)
	task.spawn(function()
		-- the music starts as the loading screen fades into the game (ReplicatedFirst.MystreeLoading
		-- sets "Loaded"; Playbook 17), with a fallback in case that screen is ever removed
		local player = game:GetService("Players").LocalPlayer
		local t0 = os.clock()
		while not player:GetAttribute("Loaded") and os.clock() - t0 < 60 do
			task.wait(0.2)
		end
		local k = 0
		while true do
			k = k % #Config.Music + 1
			local track = Config.Music[k]
			local s = Instance.new("Sound")
			s.Name = "Music"
			s.SoundId = "rbxassetid://" .. track.Id
			s.Volume = 0
			s.SoundGroup = musicGroup
			s.Parent = SoundService
			s:Play()
			TweenService:Create(s, TweenInfo.new(Config.MusicFade), { Volume = Config.MusicVolume }):Play()
			local t0 = os.clock()
			while not s.IsLoaded and os.clock() - t0 < 10 do
				task.wait(0.5)
			end
			local length = (s.TimeLength > 0) and s.TimeLength or 120
			task.wait(math.max(5, length - Config.MusicFade))
			TweenService:Create(s, TweenInfo.new(Config.MusicFade), { Volume = 0 }):Play()
			task.delay(Config.MusicFade + 0.1, function()
				s:Destroy()
			end)
		end
	end)
end

return Sounds
