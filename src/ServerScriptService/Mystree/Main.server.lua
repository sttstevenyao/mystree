-- ServerScriptService/Mystree/Main (Script)
-- Boots every service in a fixed ORDER: Init(S) on all, then Start() on all. Services talk to each
-- other only through the shared S table (S.DataService.add(...)), never by requiring each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builders = require(ReplicatedStorage.Mystree.Builders)
local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"Remotes",
	"DataService",
	"StatsService",
	"GearService",
	"TreeService",
	"WorldService",
	"CombatService",
	"MobService",
	"CompanionService",
	"MountService",
	"DailyService",
	"TutorialService",
	"QuestService",
	"IslandService",
	"LeaderboardService",
	"MonetizationService",
	"AntiCheatService",
	"AdminService",
}

-- The map is built once in Edit (CHO/tools/BuildWorld.lua). If it's ever missing, rebuild it so the
-- game still works.
if not workspace:FindFirstChild("Map") then
	warn("[Mystree] Map missing; rebuilding it from Builders")
	Builders.World()
end

local S = {}
for _, name in ipairs(ORDER) do
	S[name] = require(Services:WaitForChild(name))
end
for _, name in ipairs(ORDER) do
	if S[name].Init then
		S[name].Init(S)
	end
end
for _, name in ipairs(ORDER) do
	if S[name].Start then
		task.spawn(S[name].Start)
	end
end

-- Studio debug hook: lets MCP tests reach the live services (Playbook 10)
if game:GetService("RunService"):IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "MystreeDebug"
	bf.OnInvoke = function(service, fn, ...)
		return S[service][fn](...)
	end
	bf.Parent = game:GetService("ServerStorage")
end
