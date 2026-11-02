-- ServerScriptService/Mystree/Services/QuestService (ModuleScript)
-- The main storyline (Config.MainQuests), daily side quests from villagers (Config.SideQuests) and
-- the Village NPCs themselves.
--  * NPCs stand on the Village island (Map.NpcSpots, or Config.Npcs positions) with a "Talk" prompt.
--    Talking (QuestTalk) returns a dialog the client draws; quests are accepted and handed in there.
--  * Main quest steps are OFFERED and must be accepted (or declined, then accepted later). The
--    first is offered by Elder Mo (the tutorial's last step); each later step is offered by the NPC
--    you handed the previous one to (its "giver") and handed in to its own Npc.
--  * Side quests: each villager's can be done once per UTC day, up to Config.Quests.MaxSide at once.
--    Rewards grow with the tree. Fresh Orders (Robux) resets today's.
--  * Counted goals (chops, kills, dismantles, summons) count from when the quest starts (a base
--    stored with it). Bring goals take the materials on hand-in.
-- Progress reaches the client as the "QuestProgress" attribute (JSON), refreshed once a second.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Builders = require(ReplicatedStorage.Mystree.Builders)

local QuestService = {}
local S

local MAIN = Config.MainQuests
local SIDE = Config.SideQuests
local npcModels = {} -- npc id -> model
local lastPublished = {} -- player -> JSON string

local function today()
	return os.time() // 86400
end

local COUNTED = { Chop = true, Kill = true, Elite = true, Boss = true, Summon = true, Dismantle = true }

local function counter(data, goal)
	local t, st = goal.Type, data.Stats
	if t == "Chop" then
		return st.Chops
	elseif t == "Kill" then
		return goal.Mob and ((st.Mobs or {})[goal.Mob] or 0) or st.Kills
	elseif t == "Elite" then
		return st.Elites
	elseif t == "Boss" then
		return st.Bosses
	elseif t == "Summon" then
		return st.Summons or 0
	elseif t == "Dismantle" then
		return st.Dismantled or 0
	end
	return 0
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- progress on a goal for this save (base = counter value when the quest started)
local function have(player, data, goal, base)
	local t = goal.Type
	if COUNTED[t] then
		return counter(data, goal) - (base or 0)
	elseif t == "TreeLevel" then
		return data.Tree.Level
	elseif t == "Level" then
		return data.Level
	elseif t == "Bring" then
		return data.Materials[goal.Mat] or 0
	elseif t == "Companions" then
		return count(data.Companions)
	elseif t == "Equipped" then
		return count(data.Equipped)
	elseif t == "EquipRarity" then
		for slot, id in pairs(data.Equipped) do
			local it = data.Inventory[id]
			if it and (not goal.Slot or goal.Slot == slot) and it.R >= goal.Rarity then
				return 1
			end
		end
		return 0
	elseif t == "Visit" then
		return player:GetAttribute("InGrounds") and 1 or 0
	end
	return 0
end

-- who offers main step i: Elder Mo first, then whoever took the previous step
local function giverOf(index)
	return index <= 1 and "Elder" or MAIN[index - 1].Npc
end
QuestService.giverOf = giverOf

local function baseFor(data, goal)
	return COUNTED[goal.Type] and counter(data, goal) or 0
end

local function sideReward(data, def)
	return Rules.questReward(def.Reward, data.Tree.Level, true)
end

-- ===================================================================== rewards
local function pay(player, reward)
	local plain = {}
	for k, v in pairs(reward) do
		if k ~= "Gear" and k ~= "Exp" then
			plain[k] = v
		end
	end
	S.DataService.grant(player, plain)
	if reward.Exp then
		S.StatsService.addExp(player, reward.Exp)
	end
	if reward.Gear then
		local item = S.GearService.roll(player, { Min = reward.Gear })
		local result = S.GearService.give(player, item)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		S.Remotes.Drop:FireClient(player, {
			Item = item, R = item.R, Pos = hrp and (hrp.Position + hrp.CFrame.LookVector * 6 + Vector3.new(0, 4, 0)),
			Equipped = result.Equipped, Dismantled = result.Dismantled, Scraps = result.Scraps,
		})
	end
	S.DataService.push(player)
end

local function nearNpc(player, npcId)
	local m = npcModels[npcId]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return m and hrp and m.PrimaryPart and (m.PrimaryPart.Position - hrp.Position).Magnitude <= Config.NpcTalkRange + 8
end

-- ===================================================================== progress for the client
local function progress(player, data)
	local Q = data.Quests
	local out = { Side = {} }
	local step = MAIN[Q.Main]
	if Q.Main == 0 then
		out.Main = { Index = 0, Id = "M0", Title = "The Divine Tree", Goal = "Talk to Elder Mo", Have = 0, Need = 1, Ready = true, Npc = "Elder" }
	elseif step and not Q.MainAccepted then
		local giver = giverOf(Q.Main)
		out.Main = { Index = Q.Main, Id = step.Id, Title = step.Title, Goal = "New quest from " .. Config.Npcs[giver].Name, Have = 0, Need = 1,
			Ready = false, Offered = true, Npc = giver }
	elseif step then
		local h = have(player, data, step.Goal, Q.MainBase)
		out.Main = { Index = Q.Main, Id = step.Id, Title = step.Title, Goal = Rules.goalText(step.Goal), Have = math.clamp(h, 0, step.Goal.Need),
			Need = step.Goal.Need, Ready = h >= step.Goal.Need, Npc = step.Npc }
	end
	for id, base in pairs(Q.Side) do
		local def = SIDE[id]
		if def then
			local h = have(player, data, def.Goal, base)
			out.Side[id] = { Title = def.Title, Goal = Rules.goalText(def.Goal), Have = math.clamp(h, 0, def.Goal.Need), Need = def.Goal.Need,
				Ready = h >= def.Goal.Need, Npc = def.Npc }
		end
	end
	return out
end

function QuestService.publish(player)
	local data = S.DataService.data(player)
	if not data then
		return
	end
	local json = HttpService:JSONEncode(progress(player, data))
	if lastPublished[player] ~= json then
		lastPublished[player] = json
		player:SetAttribute("QuestProgress", json)
	end
end

-- ===================================================================== dialog
function QuestService.dialog(player, npcId)
	local data = S.DataService.data(player)
	local npc = Config.Npcs[npcId]
	local Q = data.Quests
	local d = { Npc = npcId, Name = npc.Name, Title = npc.Title, Line = npc.Greeting, Opens = npc.Opens, Side = {} }
	local step = MAIN[Q.Main]
	if step and not Q.MainAccepted then
		-- offered: only its giver shows it, with Accept / Decline
		if giverOf(Q.Main) == npcId then
			d.Main = { Id = step.Id, Title = step.Title, State = "Offer", Text = step.Story, Goal = Rules.goalText(step.Goal),
				Have = 0, Need = step.Goal.Need, Reward = step.Reward, TurnInNpc = step.Npc }
			d.Line = step.Story
		end
	elseif step then
		local h = have(player, data, step.Goal, Q.MainBase)
		local state = (step.Npc ~= npcId) and "Elsewhere" or (h >= step.Goal.Need and "Ready" or "Active")
		if step.Npc == npcId or npcId == "Elder" then
			d.Main = { Id = step.Id, Title = step.Title, State = state, Text = step.Story, Goal = Rules.goalText(step.Goal),
				Have = math.clamp(h, 0, step.Goal.Need), Need = step.Goal.Need, Reward = step.Reward, TurnInNpc = step.Npc }
			if step.Npc == npcId then
				d.Line = step.Story
			end
		end
	end
	local day = today()
	local anyOpen = false
	local ids = {}
	for id, def in pairs(SIDE) do
		if def.Npc == npcId then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local la, lb = SIDE[a].MinLevel or 0, SIDE[b].MinLevel or 0
		return la == lb and a < b or la < lb
	end)
	for _, id in ipairs(ids) do
		local def = SIDE[id]
		local state
		local h = 0
		if Q.Side[id] then
			h = have(player, data, def.Goal, Q.Side[id])
			state = h >= def.Goal.Need and "Ready" or "Active"
			anyOpen = true
		elseif Q.SideDone[id] == day then
			state = "DoneToday"
		elseif data.Level < (def.MinLevel or 0) then
			state = "Locked"
		else
			state = "Offer"
			anyOpen = true
		end
		table.insert(d.Side, { Id = id, Title = def.Title, State = state, Goal = Rules.goalText(def.Goal), Have = math.clamp(h, 0, def.Goal.Need),
			Need = def.Goal.Need, Reward = sideReward(data, def), MinLevel = def.MinLevel })
	end
	if #ids > 0 and not anyOpen then
		local doneAll = true
		for _, e in ipairs(d.Side) do
			if e.State ~= "DoneToday" and e.State ~= "Locked" then
				doneAll = false
			end
		end
		d.FreshOrders = doneAll or nil
	end
	return d
end

-- ===================================================================== actions
-- offer step `index` (it starts counting only once accepted)
local function startMain(player, data, index)
	data.Quests.Main = index
	data.Quests.MainAccepted = false
	data.Quests.MainBase = 0
end

local function acceptMain(player, data)
	local step = MAIN[data.Quests.Main]
	data.Quests.MainAccepted = true
	data.Quests.MainBase = step and baseFor(data, step.Goal) or 0
end

function QuestService.talk(player, npcId)
	local data = S.DataService.data(player)
	if not (data and Config.Npcs[npcId]) then
		return false, "Nobody's there."
	end
	if not nearNpc(player, npcId) then
		return false, "Walk closer to talk."
	end
	local d
	if npcId == "Elder" and data.Quests.Main == 0 then
		-- first meeting: Elder Mo offers the story (accept or decline in the dialog)
		startMain(player, data, 1)
		S.DataService.push(player)
		d = QuestService.dialog(player, npcId)
	else
		d = QuestService.dialog(player, npcId)
	end
	QuestService.publish(player)
	return true, nil, d
end

function QuestService.accept(player, id)
	local data = S.DataService.data(player)
	local step = MAIN[data.Quests.Main]
	if step and step.Id == id then
		if data.Quests.MainAccepted then
			return false, "You're already on it."
		end
		local giver = giverOf(data.Quests.Main)
		if not nearNpc(player, giver) then
			return false, "Talk to " .. Config.Npcs[giver].Name .. " to accept it."
		end
		acceptMain(player, data)
		S.DataService.push(player)
		QuestService.publish(player)
		return true, "Main quest accepted: " .. step.Title, QuestService.dialog(player, giver)
	end
	local def = SIDE[id]
	if not def then
		return false, "Unknown quest."
	end
	local Q = data.Quests
	if Q.Side[id] then
		return false, "You're already on it."
	end
	if Q.SideDone[id] == today() then
		return false, "Come back tomorrow for this one."
	end
	if data.Level < (def.MinLevel or 0) then
		return false, "Reach Lv " .. def.MinLevel .. " first."
	end
	if count(Q.Side) >= Config.Quests.MaxSide then
		return false, string.format("You can hold %d side quests at once. Finish or drop one first.", Config.Quests.MaxSide)
	end
	if not nearNpc(player, def.Npc) then
		return false, "Walk closer to talk."
	end
	Q.Side[id] = baseFor(data, def.Goal)
	S.DataService.push(player)
	QuestService.publish(player)
	return true, "Quest accepted: " .. def.Title, QuestService.dialog(player, def.Npc)
end

function QuestService.abandon(player, id)
	local data = S.DataService.data(player)
	if not data.Quests.Side[id] then
		return false, "You're not on that quest."
	end
	data.Quests.Side[id] = nil
	S.DataService.push(player)
	QuestService.publish(player)
	return true, "Quest dropped."
end

local function takeBring(player, goal)
	if goal.Type == "Bring" then
		S.DataService.addMat(player, goal.Mat, -goal.Need)
	end
end

function QuestService.turnIn(player, id)
	local data = S.DataService.data(player)
	local Q = data.Quests
	local step = MAIN[Q.Main]
	if step and step.Id == id and Q.MainAccepted then
		if not nearNpc(player, step.Npc) then
			return false, "Hand this in to " .. Config.Npcs[step.Npc].Name .. "."
		end
		if have(player, data, step.Goal, Q.MainBase) < step.Goal.Need then
			return false, "Not done yet: " .. Rules.goalText(step.Goal) .. "."
		end
		takeBring(player, step.Goal)
		pay(player, step.Reward)
		startMain(player, data, Q.Main + 1)
		S.DataService.push(player)
		QuestService.publish(player)
		local d = QuestService.dialog(player, step.Npc)
		d.Line = step.Done
		d.Rewarded = { Title = step.Title, Reward = step.Reward }
		-- the next step is now offered right here (d.Main has it with Accept / Decline)
		S.Remotes.effect(player, "Quest", step.Title, step.Reward)
		return true, "Main quest complete: " .. step.Title, d
	end
	local def = SIDE[id]
	if def and Q.Side[id] then
		if not nearNpc(player, def.Npc) then
			return false, "Hand this in to " .. Config.Npcs[def.Npc].Name .. "."
		end
		if have(player, data, def.Goal, Q.Side[id]) < def.Goal.Need then
			return false, "Not done yet: " .. Rules.goalText(def.Goal) .. "."
		end
		takeBring(player, def.Goal)
		local reward = sideReward(data, def)
		pay(player, reward)
		Q.Side[id] = nil
		Q.SideDone[id] = today()
		S.DataService.push(player)
		QuestService.publish(player)
		local d = QuestService.dialog(player, def.Npc)
		d.Rewarded = { Title = def.Title, Reward = reward }
		S.Remotes.effect(player, "Quest", def.Title, reward)
		return true, "Quest complete: " .. def.Title, d
	end
	return false, "That quest isn't ready."
end

-- Fresh Orders (Robux): every villager's side quests are available again today
function QuestService.freshOrders(player)
	local data = S.DataService.data(player)
	table.clear(data.Quests.SideDone)
	S.DataService.push(player)
	QuestService.publish(player)
	S.Remotes.notify(player, "Fresh Orders: every villager has new side quests for you!", "Purchase")
end

function QuestService.reset(player)
	local data = S.DataService.data(player)
	data.Quests.Main = 0
	data.Quests.MainBase = 0
	data.Quests.MainAccepted = false
	table.clear(data.Quests.Side)
	table.clear(data.Quests.SideDone)
	S.DataService.push(player)
	QuestService.publish(player)
end

-- ===================================================================== NPCs
local function npcModel(id, def)
	local art = ReplicatedStorage:FindFirstChild("MystreeAssets")
	art = art and art:FindFirstChild("Npc") and art.Npc:FindFirstChild(id)
	if art then
		return art:Clone()
	end
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		for _, part in ipairs({ "HeadColor", "LeftArmColor", "RightArmColor" }) do
			desc[part] = def.Skin
		end
		desc.TorsoColor = def.Top
		desc.LeftLegColor = def.Bottom
		desc.RightLegColor = def.Bottom
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn("[QuestService] couldn't build an avatar for " .. id .. ": " .. tostring(model))
	local m = Builders.Creature(id, "Biped", Vector3.new(2.4, 5.6, 1.4), def.Top, CFrame.new(0, 2.8, 0))
	m.PrimaryPart.Name = "HumanoidRootPart"
	return m
end

local function spawnNpcs()
	local folder = workspace:FindFirstChild("Npcs") or Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = workspace
	local spots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NpcSpots")
	local G = Vector3.new(0, Config.Map.GroundY, 0)
	for id, def in pairs(Config.Npcs) do
		local spot = spots and spots:FindFirstChild("NpcSpot_" .. id)
		local at = spot and spot.Position or (def.Pos + G)
		-- face the plaza centre
		local ground = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
		local m = npcModel(id, def)
		m.Name = def.Name
		local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		m.PrimaryPart = root
		local hum = m:FindFirstChildOfClass("Humanoid")
		local hip = hum and (hum.HipHeight + root.Size.Y / 2) or 2.8
		m:PivotTo(ground * CFrame.new(0, hip, 0))
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Talk"
		prompt.ActionText = "Talk"
		prompt.ObjectText = def.Name
		prompt.MaxActivationDistance = Config.NpcTalkRange
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Parent = root
		m:SetAttribute("NpcId", id)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		m.Parent = folder
		npcModels[id] = m
	end
end

function QuestService.Init(services)
	S = services
end

function QuestService.Start()
	local R = S.Remotes
	R.Handle("QuestTalk", 0.3, { "string" }, QuestService.talk)
	R.Handle("QuestAccept", 0.3, { "string" }, QuestService.accept)
	R.Handle("QuestTurnIn", 0.5, { "string" }, QuestService.turnIn)
	R.Handle("QuestAbandon", 0.3, { "string" }, QuestService.abandon)
	spawnNpcs()
	S.DataService.Loaded:Connect(function(player)
		QuestService.publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPublished[player] = nil
	end)
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(QuestService.publish, player)
			if not ok then
				warn("[QuestService] " .. tostring(err))
			end
		end
	end
end

-- who to stand next to for a quest (client waypoint / tutorial)
function QuestService.npcModel(id)
	return npcModels[id]
end

return QuestService
