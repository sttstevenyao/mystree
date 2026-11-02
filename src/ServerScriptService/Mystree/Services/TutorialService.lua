-- ServerScriptService/Mystree/Services/TutorialService (ModuleScript)
-- The progression tutorial (Config.Tutorial). The server owns it: twice a second it checks the
-- current step against the save, and when it's met it pays the reward and moves on. Nothing the
-- client says completes a step; the client only shows the goal, the spotlight and the arrows.
-- Player attributes for the client: Tutorial (step index, past the end = done), TutorialHave,
-- TutorialNeed. Rewards: any DataService.grant keys, plus Weapon = minimum rarity (a guaranteed
-- weapon drop with the full loot moment).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)

local TutorialService = {}
local S

local STEPS = Config.Tutorial

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- progress of a step for this save: have (capped at Need)
local PROGRESS = {
	Chop = function(player, data)
		return data.Stats.Chops - data.TutorialBase
	end,
	Grow = function(player, data)
		return data.Tree.Level >= 2 and 1 or 0
	end,
	Summon = function(player, data)
		return count(data.Companions)
	end,
	Hunt = function(player, data)
		return player:GetAttribute("InGrounds") and 1 or 0
	end,
	Kill = function(player, data)
		return data.Stats.Kills - data.TutorialBase
	end,
	-- talking to Elder Mo starts the main quest (QuestService), which ends the tutorial
	Elder = function(player, data)
		return (data.Quests.Main > 1 or (data.Quests.Main == 1 and data.Quests.MainAccepted)) and 1 or 0
	end,
}
-- counted steps remember where they started
local BASE = {
	Chop = function(data)
		return data.Stats.Chops
	end,
	Kill = function(data)
		return data.Stats.Kills
	end,
}

local function publish(player, data)
	player:SetAttribute("Tutorial", data.Tutorial)
	local step = STEPS[data.Tutorial]
	if step then
		local have = PROGRESS[step.Id](player, data)
		player:SetAttribute("TutorialHave", math.clamp(have, 0, step.Need))
		player:SetAttribute("TutorialNeed", step.Need)
	end
end

local function startStep(player, data)
	local step = STEPS[data.Tutorial]
	data.TutorialBase = (step and BASE[step.Id]) and BASE[step.Id](data) or 0
	publish(player, data)
end

local function pay(player, reward)
	local plain = {}
	for k, v in pairs(reward) do
		if k ~= "Weapon" then
			plain[k] = v
		end
	end
	S.DataService.grant(player, plain)
	if reward.Weapon then
		-- rarity from the player's own odds with a floor, always a weapon (the thing you swing next)
		local rarity = S.GearService.roll(player, { Min = reward.Weapon }).R
		local fresh = Rules.rollItem(S.DataService.data(player).Tree.Level, rarity, Random.new(), "Weapon")
		local result = S.GearService.give(player, fresh)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		S.Remotes.Drop:FireClient(player, {
			Item = fresh, R = fresh.R, Pos = hrp and hrp.Position + hrp.CFrame.LookVector * 6 + Vector3.new(0, 4, 0),
			Equipped = result.Equipped, Dismantled = result.Dismantled, Scraps = result.Scraps, Golden = true,
		})
	end
	S.DataService.push(player)
end

function TutorialService.check(player)
	local data = S.DataService.data(player)
	if not data then
		return
	end
	local step = STEPS[data.Tutorial]
	if not step then
		return
	end
	local have = PROGRESS[step.Id](player, data)
	if have >= step.Need then
		pay(player, step.Reward)
		S.Remotes.effect(player, "Tutorial", data.Tutorial, step.Reward)
		data.Tutorial += 1
		if data.Tutorial > #STEPS then
			publish(player, data)
			-- the Starter Pack offer starts its countdown now
			if data.Offers.StarterAt == 0 then
				data.Offers.StarterAt = os.time()
				S.DataService.push(player)
			end
			S.Remotes.notify(player, "Tutorial complete! Follow the main quest to learn what's eating the tree.", "Legendary")
		else
			startStep(player, data)
		end
	elseif player:GetAttribute("TutorialHave") ~= math.clamp(have, 0, step.Need) then
		publish(player, data)
	end
end

function TutorialService.reset(player)
	local data = S.DataService.data(player)
	if data then
		data.Tutorial = 1
		startStep(player, data)
	end
end

function TutorialService.Init(services)
	S = services
end

function TutorialService.Start()
	S.Remotes.Handle("SkipTutorial", 1, {}, function(player)
		local data = S.DataService.data(player)
		data.Tutorial = #STEPS + 1
		publish(player, data)
		-- skipping counts as finishing: the Starter Pack countdown starts too
		if data.Offers.StarterAt == 0 then
			data.Offers.StarterAt = os.time()
			S.DataService.push(player)
		end
		return true, "Tutorial skipped. The goal pill at the bottom still shows what to do next."
	end)
	S.DataService.Loaded:Connect(function(player, data, isNew)
		local skip = Config.TutorialSkipIf
		if not isNew and data.Tutorial <= #STEPS and (data.Tree.Level >= skip.TreeLevel or data.Stats.Kills >= skip.Kills) then
			data.Tutorial = #STEPS + 1
		end
		if data.Tutorial <= #STEPS then
			startStep(player, data)
		else
			publish(player, data)
		end
	end)
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(TutorialService.check, player)
			if not ok then
				warn("[TutorialService] " .. tostring(err))
			end
		end
	end
end

return TutorialService
