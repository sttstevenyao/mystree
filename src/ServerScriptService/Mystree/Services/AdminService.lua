-- ServerScriptService/Mystree/Services/AdminService (ModuleScript)
-- Admin panel commands for testing everything solo (Playbook 09). Admins: Studio always, the place
-- owner, the group owner (rank 255) and Config.Admins. Every command is re-checked here; the client
-- only shows the panel (F2 / the Admin button). Studio playtests write the REAL save: use ResetSave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)

local AdminService = {}
local S

local rng = Random.new()

function AdminService.isAdmin(player)
	if RunService:IsStudio() or table.find(Config.Admins, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId == player.UserId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= 255
end

local function num(v, default)
	return math.floor(tonumber(v) or default)
end

-- typed values (admin Stats rows): "500" sets, "+500" / "-500" adds or takes away, k/m/b
-- suffixes multiply ("2.5k"); "" or "reset" clears a stat override. Returns false for nonsense.
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9 }
local function typed(text, current)
	text = string.lower((string.gsub(tostring(text or ""), "[%s,]", "")))
	if text == "" or text == "reset" then
		return nil
	end
	local sign, digits, suffix = string.match(text, "^([%+%-]?)([%d%.]+)([kmb]?)$")
	local n = tonumber(digits)
	if not n then
		return false
	end
	n *= SUFFIX[suffix] or 1
	if sign == "+" then
		return current + n
	elseif sign == "-" then
		return current - n
	end
	return n
end

local MAIN_STATS = { ATK = "Attack", HP = "Health", DEF = "Defense", AGL = "Agility" }
local CURRENCIES = { Scraps = true, Spirit = true }

local COMMANDS = {
	-- set or nudge one value from the admin Stats rows (see `typed`)
	Stat = function(player, key, text)
		key = tostring(key)
		if MAIN_STATS[key] then
			local s = S.StatsService.get(player)
			local v = typed(text, s and s[key] or 0)
			if v == false then
				return false, "Type a number, +n, -n or reset"
			end
			if v ~= nil then
				v = math.max(key == "HP" and 1 or 0, math.floor(v))
				if v == S.StatsService.natural(player, key) then
					v = nil
				end
			end
			S.StatsService.setOverride(player, key, v)
			return true, MAIN_STATS[key] .. (v and (" set to " .. v) or " back to normal")
		elseif key == "Level" or key == "TreeLevel" or CURRENCIES[key] then
			local data = S.DataService.data(player)
			local cur = key == "TreeLevel" and data.Tree.Level or (data[key] or 0)
			local v = typed(text, cur)
			if not v then
				return false, "Type a number, +n or -n"
			end
			v = math.floor(v)
			if key == "Level" then
				v = math.clamp(v, 1, Config.Level.Max)
				S.DataService.set(player, "Level", v)
				S.DataService.set(player, "Exp", 0)
				S.StatsService.refresh(player)
				S.MountService.checkUnlocks(player)
				return true, "Level " .. v
			elseif key == "TreeLevel" then
				data.Tree.Level = math.clamp(v, 1, Config.Tree.MaxLevel)
				data.Tree.Growing = false
				player:SetAttribute("TreeLevel", data.Tree.Level)
				S.DataService.push(player)
				S.TreeService.buildTree(player)
				return true, "Tree level " .. data.Tree.Level
			end
			S.DataService.set(player, key, math.max(0, v))
			return true, key .. " set to " .. math.max(0, v)
		end
		return false, "Unknown stat"
	end,

	Scraps = function(player, n)
		S.DataService.add(player, "Scraps", num(n, 10000))
		return true, "Peaches added"
	end,
	Spirit = function(player, n)
		S.DataService.add(player, "Spirit", num(n, 1000))
		return true, "Spirit Stones added"
	end,
	Materials = function(player, n)
		for name in pairs(Config.Materials) do
			S.DataService.addMat(player, name, num(n, 50))
		end
		return true, "Materials added"
	end,
	TreeLevel = function(player, n)
		local data = S.DataService.data(player)
		data.Tree.Level = math.clamp(num(n, data.Tree.Level + 1), 1, Config.Tree.MaxLevel)
		data.Tree.Growing = false
		player:SetAttribute("TreeLevel", data.Tree.Level)
		S.DataService.push(player)
		S.TreeService.buildTree(player)
		return true, "Tree level " .. data.Tree.Level
	end,
	FinishGrowth = function(player)
		return S.TreeService.finishGrowth(player, true), "Growth finished"
	end,
	Level = function(player, n)
		S.DataService.set(player, "Level", math.clamp(num(n, 10), 1, Config.Level.Max))
		S.DataService.set(player, "Exp", 0)
		S.StatsService.refresh(player)
		S.MountService.checkUnlocks(player)
		return true, "Level set"
	end,
	-- chop one drop of a chosen rarity (tests beams/cards/announcements)
	Roll = function(player, r)
		r = math.clamp(num(r, 5), 1, #Config.Rarities)
		local data = S.DataService.data(player)
		local item = Rules.rollItem(data.Tree.Level, r, rng)
		local res = S.GearService.give(player, item)
		S.Remotes.Drop:FireClient(player, { Item = item, R = r, Equipped = res.Equipped, Dismantled = res.Dismantled, Scraps = res.Scraps, Admin = true })
		return true, "Rolled a " .. Config.Rarities[r].Name
	end,
	Bloodmoon = function()
		S.WorldService.startEvent("Bloodmoon")
		return true, "Bloodmoon started"
	end,
	GoldenHour = function()
		S.WorldService.startEvent("GoldenHour")
		return true, "Golden Hour started"
	end,
	SkipCycle = function()
		S.WorldService.skip()
		return true, "Skipping to the next phase"
	end,
	Spawn = function(player, id)
		return S.MobService.spawnNear(player, tostring(id)), "Spawned " .. tostring(id)
	end,
	KillMobs = function(player)
		local n = 0
		for _, m in ipairs(S.MobService.alive()) do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and m.PrimaryPart and (m.PrimaryPart.Position - hrp.Position).Magnitude < 120 then
				S.MobService.damage(m, player, m:GetAttribute("HP") + 1, true)
				n += 1
			end
		end
		return true, "Killed " .. n
	end,
	Companion = function(player, id)
		if not Config.Companions[id] then
			return false, "Unknown companion"
		end
		S.CompanionService.grant(player, id)
		S.CompanionService.equip(player, id, 1)
		return true, "Given " .. id
	end,
	Mount = function(player, id)
		if not Config.Mounts[id] then
			return false, "Unknown mount"
		end
		S.MountService.grant(player, id)
		return true, "Given " .. id
	end,
	Travel = function(player, where)
		return S.WorldService.travel(player, where == "Hub" and "Hub" or "Grounds"), "Travelled"
	end,
	Heal = function(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
		return true, "Healed"
	end,
	Product = function(player, key)
		return S.MonetizationService.grantProduct(player, tostring(key)), "Granted " .. tostring(key)
	end,
	Quests = function(player)
		S.QuestService.reset(player)
		return true, "Quests reset"
	end,
	QuestStep = function(player)
		local data = S.DataService.data(player)
		data.Quests.Main = math.min(#Config.MainQuests + 1, data.Quests.Main + 1)
		data.Quests.MainAccepted = true
		S.DataService.push(player)
		S.QuestService.publish(player)
		return true, "Main quest step " .. data.Quests.Main
	end,
	-- plays the summon cinematic for a chosen rarity without granting anything (Studio testing)
	SummonPreview = function(player, r, n)
		r = math.clamp(num(r, 5), 3, 7)
		local pool = {}
		for id, def in pairs(Config.Companions) do
			if def.Rarity == r then
				table.insert(pool, id)
			end
		end
		local results = {}
		for i = 1, math.clamp(num(n, 1), 1, 10) do
			local rr = (i == 1) and r or 3
			local id = pool[1]
			if rr ~= r then
				for cid, def in pairs(Config.Companions) do
					if def.Rarity == rr then
						id = cid
					end
				end
			end
			table.insert(results, { Id = id, R = rr, New = i == 1, Stars = 1 })
		end
		S.Remotes.effect(player, "SummonPreview", results)
		return true, "Previewing a " .. Config.Rarities[r].Name .. " summon"
	end,
	Tutorial = function(player)
		S.TutorialService.reset(player)
		return true, "Tutorial restarted"
	end,
	ResetSave = function(player)
		S.DataService.reset(player)
		player:SetAttribute("TreeLevel", 1)
		S.TreeService.buildTree(player)
		S.StatsService.refresh(player)
		S.TutorialService.reset(player)
		return true, "Save reset to a fresh start"
	end,
}

function AdminService.Init(services)
	S = services
end

function AdminService.Start()
	S.Remotes.Handle("Admin", 0.1, { "string", "any", "any" }, function(player, command, a, b)
		if not AdminService.isAdmin(player) then
			return false, "Admins only."
		end
		local fn = COMMANDS[command]
		if not fn then
			return false, "Unknown command"
		end
		return fn(player, a, b)
	end)
	local function mark(player)
		task.spawn(function()
			player:SetAttribute("Admin", AdminService.isAdmin(player))
		end)
	end
	Players.PlayerAdded:Connect(mark)
	for _, pl in ipairs(Players:GetPlayers()) do
		mark(pl)
	end
end

return AdminService
