-- ServerScriptService/Mystree/Services/WorldService (ModuleScript)
-- The synced day/night cycle with rare events, travel between the Village and the Hunting Grounds,
-- respawn location, and which zone each player is in.
--  * State lives in workspace attributes so every client (and late joiners) can read it:
--    CyclePhase "Day"/"Night", CycleEvent ""/"Bloodmoon"/"GoldenHour", CycleStart, CycleEnd
--    (workspace:GetServerTimeNow() values). Clients tween the lighting from these (WorldFx).
--  * Each switch rolls the event for the new phase (Config.Cycle.Events). "Call Bloodmoon" forces
--    the next night. Services hook WorldService.Changed (phase, event) for spawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)

local WorldService = {}
local S

local rng = Random.new()
local changed = Instance.new("BindableEvent")
WorldService.Changed = changed.Event

local forced = {} -- [eventName] = buyer name, applied at the next matching phase
local skipNow = false

local EVENT_TEXT = {
	Bloodmoon = { "A BLOODMOON RISES!", "Blood Skeletons roam the Hunting Grounds." },
	GoldenHour = { "GOLDEN HOUR!", "Golden Stags have appeared in the Hunting Grounds." },
}

function WorldService.phase()
	return workspace:GetAttribute("CyclePhase") or "Day", workspace:GetAttribute("CycleEvent") or ""
end

local function setPhase(phase, event)
	local now = workspace:GetServerTimeNow()
	workspace:SetAttribute("CyclePhase", phase)
	workspace:SetAttribute("CycleEvent", event)
	workspace:SetAttribute("CycleStart", now)
	workspace:SetAttribute("CycleEnd", now + Config.Cycle.Length)
	if event ~= "" then
		local t = EVENT_TEXT[event]
		S.Remotes.alert(t[1], event)
		S.Remotes.notifyAll(t[2], event)
	else
		S.Remotes.notifyAll(phase == "Night" and "🌙 Night falls. Night Wolves and Wraiths are out." or "☀️ A new day begins.", phase)
	end
	changed:Fire(phase, event)
end

local function rollEvent(phase)
	for name, ev in pairs(Config.Cycle.Events) do
		if ev.Phase == phase and forced[name] then
			forced[name] = nil
			return name
		end
	end
	for name, ev in pairs(Config.Cycle.Events) do
		if ev.Phase == phase and rng:NextNumber() < ev.Chance then
			return name
		end
	end
	return ""
end

-- Admin / product hooks
function WorldService.force(eventName, buyer)
	forced[eventName] = buyer or true
	if buyer then
		S.Remotes.notifyAll(string.format("🩸 %s called a Bloodmoon! The next night will run red.", buyer), "Bloodmoon")
	end
end

function WorldService.skip()
	skipNow = true
end

-- Start an event right now (admin): switches to its phase immediately
function WorldService.startEvent(eventName)
	local ev = Config.Cycle.Events[eventName]
	if ev then
		setPhase(ev.Phase, eventName)
	end
end

-- ===================================================================== travel
function WorldService.travel(player, where)
	local char = player.Character
	if not char then
		return false
	end
	S.AntiCheatService.grace(player)
	if where == "Grounds" then
		player:SetAttribute("InGrounds", true)
		local p = Config.Map.GroundsEntry + Vector3.new(rng:NextNumber(-6, 6), Config.Map.GroundY + 3, rng:NextNumber(-6, 6))
		char:PivotTo(CFrame.lookAt(p, p + Vector3.new(1, 0, 0)))
	elseif where == "Hub" then
		player:SetAttribute("InGrounds", false)
		local p = Config.Map.HubSpawn + Vector3.new(rng:NextNumber(-5, 5), Config.Map.GroundY + 3, rng:NextNumber(-3, 3))
		char:PivotTo(CFrame.lookAt(p, Vector3.new(0, p.Y, 0)))
	else
		player:SetAttribute("InGrounds", false)
		char:PivotTo(S.TreeService.standCFrame(player))
	end
	-- home: the axe comes out; anywhere else the axe goes away (it's for your island)
	if where == "Home" or where == "Plot" then
		player:SetAttribute("Held", "Axe")
	elseif player:GetAttribute("Held") == "Axe" then
		player:SetAttribute("Held", "")
	end
	S.StatsService.applyCharacter(player)
	S.Remotes.effect(player, "Travel", where)
	return true
end

-- "Village" (anywhere off the Wildlands), "Camp" (its centre) or the zone whose sector holds pos
local function zoneAt(pos)
	local W = Config.Wild
	local d = (pos - W.Center) * Vector3.new(1, 0, 1)
	if d.Magnitude > W.Radius + 60 then
		return "Village"
	end
	if d.Magnitude < W.CampRadius then
		return "Camp"
	end
	local ang = math.deg(math.atan2(d.Z, d.X))
	for _, z in ipairs(Config.Zones) do
		local diff = (ang - z.Angle + 540) % 360 - 180
		if math.abs(diff) <= W.Span / 2 then
			return z.Id
		end
	end
	return "Camp"
end
WorldService.zoneAt = zoneAt

function WorldService.Init(services)
	S = services
end

function WorldService.Start()
	S.Remotes.Handle("Travel", 1, { "string" }, function(player, where)
		if where ~= "Grounds" and where ~= "Hub" and where ~= "Home" then
			return false, "Unknown place."
		end
		if where ~= "Grounds" and S.CombatService.inCombat(player) then
			return false, "You can't leave in the middle of a fight."
		end
		return WorldService.travel(player, where)
	end)
	-- gate portals
	local touchedAt = {}
	for _, gate in ipairs(workspace:WaitForChild("Map"):GetDescendants()) do
		local to = gate:IsA("Model") and gate:GetAttribute("TravelTo")
		local portal = to and gate:FindFirstChild("Portal")
		if portal then
			portal.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and (not touchedAt[player] or os.clock() - touchedAt[player] > 2) then
					touchedAt[player] = os.clock()
					-- the client's ink wash sweeps in first ("TravelCover"), then the move: the travel
					-- screen never just appears (user)
					S.Remotes.effect(player, "TravelCover", to)
					task.delay(Config.GateCoverTime, function()
						if player.Parent then
							WorldService.travel(player, to)
						end
					end)
				end
			end)
		end
	end
	-- death in the Hunting Grounds respawns at the grounds entry
	local function onPlayer(player)
		player:SetAttribute("InGrounds", false)
		player.CharacterAdded:Connect(function(char)
			local revive = player:GetAttribute("ReviveTo")
			if revive then
				-- Revive Here: back where they fell
				task.defer(function()
					S.AntiCheatService.grace(player)
					char:PivotTo(CFrame.new(revive + Vector3.new(0, 3, 0)))
					player:SetAttribute("ReviveTo", nil)
					player:SetAttribute("InGrounds", true)
				end)
			elseif player:GetAttribute("InGrounds") then
				task.defer(function()
					S.AntiCheatService.grace(player)
					local p = Config.Map.GroundsEntry + Vector3.new(0, Config.Map.GroundY + 3, 0)
					char:PivotTo(CFrame.lookAt(p, p + Vector3.new(1, 0, 0)))
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, pl in ipairs(Players:GetPlayers()) do
		onPlayer(pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		touchedAt[player] = nil
	end)
	-- zone tracking (1 Hz)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local z = zoneAt(hrp.Position)
					if player:GetAttribute("Zone") ~= z then
						player:SetAttribute("Zone", z)
						-- walking back through the gate area counts as leaving the grounds
						player:SetAttribute("InGrounds", z ~= "Village")
						S.StatsService.applyCharacter(player)
					end
				end
			end
		end
	end)
	-- the cycle
	setPhase("Day", "")
	while true do
		local ends = workspace:GetAttribute("CycleEnd")
		while workspace:GetServerTimeNow() < ends and not skipNow do
			task.wait(0.5)
			ends = workspace:GetAttribute("CycleEnd")
		end
		skipNow = false
		local nextPhase = (workspace:GetAttribute("CyclePhase") == "Day") and "Night" or "Day"
		setPhase(nextPhase, rollEvent(nextPhase))
	end
end

return WorldService
