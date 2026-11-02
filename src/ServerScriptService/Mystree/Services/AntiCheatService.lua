-- ServerScriptService/Mystree/Services/AntiCheatService (ModuleScript)
-- Light, fair anti-cheat (Playbook 13): strikes, never instant kicks.
--  * Speed: horizontal speed above the player's own SpeedCap (walk or mount speed, set by
--    StatsService) times Config.AntiCheat.Tolerance. Strikes inside 20 s pull the player back.
--  * Every server-side teleport grants a grace window first (travel, spawn), or it would false-flag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)

local AntiCheatService = {}
local S

local AC = Config.AntiCheat
local strikes = {} -- player -> { times }
local graceUntil = {} -- player -> os.clock()
local lastPos = {} -- player -> { Pos, T }

function AntiCheatService.grace(player, seconds)
	graceUntil[player] = os.clock() + (seconds or AC.Grace)
	lastPos[player] = nil
end

-- a known burst of movement (a dash): its distance is let through on the next check instead of
-- switching the check off, so dashing on cooldown can't hide a speed hack
-- (it lasts a second, so a dash that straddles two samples is covered in both)
local allowance = {} -- player -> { Studs, Until }
function AntiCheatService.allow(player, studs)
	local a = allowance[player]
	local left = (a and a.Until > os.clock()) and a.Studs or 0
	allowance[player] = { Studs = left + studs, Until = os.clock() + 1 }
end

function AntiCheatService.inGrace(player)
	return (graceUntil[player] or 0) > os.clock()
end

local function strike(player, reason, backTo)
	local now = os.clock()
	local list = strikes[player] or {}
	strikes[player] = list
	table.insert(list, now)
	while list[1] and now - list[1] > 20 do
		table.remove(list, 1)
	end
	warn(string.format("[AntiCheat] %s strike %d (%s)", player.Name, #list, reason))
	if #list >= AC.Strikes and player.Character then
		table.clear(list)
		AntiCheatService.grace(player)
		player.Character:PivotTo(CFrame.new(backTo + Vector3.new(0, 3, 0)))
	end
end

function AntiCheatService.Init(s)
	S = s
end

function AntiCheatService.Start()
	Players.PlayerRemoving:Connect(function(player)
		strikes[player], graceUntil[player], lastPos[player], allowance[player] = nil, nil, nil, nil
	end)
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local now = os.clock()
				local last = lastPos[player]
				if last and not AntiCheatService.inGrace(player) then
					local d = hrp.Position - last.Pos
					local raw = Vector3.new(d.X, 0, d.Z).Magnitude
					local a = allowance[player]
					local free = (a and a.Until > now) and a.Studs or 0
					local flat = math.max(0, raw - free)
					if a then
						a.Studs = free - math.min(free, raw) -- used up once, not on every sample
					end
					local speed = flat / (now - last.T)
					local cap = (player:GetAttribute("SpeedCap") or Config.WalkSpeed) * AC.Tolerance + 4
					if speed > cap then
						strike(player, string.format("speed %.0f > %.0f", speed, cap), last.Pos)
					end
				end
				lastPos[player] = { Pos = hrp.Position, T = now }
			else
				lastPos[player] = nil
			end
		end
	end
end

return AntiCheatService
