-- ServerScriptService/Mystree/Services/CompanionService (ModuleScript)
-- Companions (spirit beasts): summons with Spirit Stones (odds in Config.SummonOdds, pity every
-- Config.SummonPity), duplicates add stars, 1 equipped (2 with Twin Spirits). Equipped companions
-- give % buffs (Rules.totals) and attack the owner's current target in the Hunting Grounds.
-- Clients draw every player's companions from the "Companions" attribute ("Id:Stars,Id:Stars").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)

local CompanionService = {}
local S

local rng = Random.new()
local target = {} -- player -> mob model the player last hit
local nextSkill = {} -- player -> { [id] = os.clock() }

local byRarity = {}
for id, def in pairs(Config.Companions) do
	byRarity[def.Rarity] = byRarity[def.Rarity] or {}
	table.insert(byRarity[def.Rarity], id)
end
for _, list in pairs(byRarity) do
	table.sort(list)
end

function CompanionService.slots(player)
	return S.MonetizationService.hasPass(player, "TwinSpirits") and 2 or 1
end

local function publish(player, data)
	local parts = {}
	for _, id in ipairs(data.CompanionEquipped) do
		local owned = data.Companions[id]
		table.insert(parts, id .. ":" .. (owned and owned.Stars or 1))
	end
	player:SetAttribute("Companions", table.concat(parts, ","))
end

function CompanionService.setTarget(player, mob)
	target[player] = mob
end

-- "1 in N" for one exact spirit (its rarity's share split across that rarity's spirits)
local function oneIn(id)
	local total = 0
	for _, w in pairs(Config.SummonOdds) do
		total += w
	end
	local r = Config.Companions[id].Rarity
	local p = (Config.SummonOdds[r] or 0) / total / #byRarity[r]
	return p > 0 and tostring(math.floor(1 / p + 0.5)) or "?"
end

-- rolls from Rules.summonTiers, the same table the odds screen shows (pity included)
local function rollOne(data)
	local tiers, weights = Rules.summonTiers(data.SummonPity)
	data.SummonPity += 1
	local rarity = tiers[Rules.pickWeighted(weights, rng)]
	if rarity >= 5 then
		data.SummonPity = 0
	end
	local list = byRarity[rarity]
	return list[rng:NextInteger(1, #list)]
end

-- Add a companion (or a star). Returns { Id, Stars, New, Refund }
function CompanionService.grant(player, id)
	local data = S.DataService.data(player)
	local owned = data.Companions[id]
	local res = { Id = id }
	if not owned then
		data.Companions[id] = { Stars = 1 }
		res.New = true
		res.Stars = 1
		if #data.CompanionEquipped < CompanionService.slots(player) then
			table.insert(data.CompanionEquipped, id)
		end
	elseif owned.Stars < Config.CompanionStars.Max then
		owned.Stars += 1
		res.Stars = owned.Stars
	else
		-- maxed: a partial refund so a duplicate never feels wasted
		local refund = math.floor(Config.SummonCost.One * 0.3)
		S.DataService.add(player, "Spirit", refund)
		res.Stars = owned.Stars
		res.Refund = refund
	end
	return res
end

function CompanionService.summon(player, count)
	local data = S.DataService.data(player)
	local cost = (count == 10) and Config.SummonCost.Ten or Config.SummonCost.One
	if data.Spirit < cost then
		return false, string.format("You need %d more Spirit Stones.", cost - data.Spirit)
	end
	S.DataService.add(player, "Spirit", -cost)
	data.Stats.Summons = (data.Stats.Summons or 0) + count
	local results = {}
	local best = 0
	for _ = 1, count do
		local id = rollOne(data)
		local res = CompanionService.grant(player, id)
		res.R = Config.Companions[id].Rarity
		best = math.max(best, res.R)
		table.insert(results, res)
		-- (no server-wide announcements for summons: user, 2026-10-27)
	end
	-- Epic+ pulls light a beam over the summoner that everyone nearby sees (after the roll lands)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if best >= 4 and hrp then
		local pos = hrp.Position
		task.delay(best >= 5 and 4.5 or 3, function()
			S.Remotes.fireNear("Effect", pos, 220, "SummonBeam", player.UserId, best, pos)
		end)
	end
	publish(player, data)
	S.StatsService.refresh(player)
	S.DataService.push(player)
	S.Remotes.effect(player, "Summon", results)
	return true, nil, results
end

function CompanionService.equip(player, id, slot)
	local data = S.DataService.data(player)
	slot = math.clamp(math.floor(slot), 1, CompanionService.slots(player))
	if id ~= "" and not data.Companions[id] then
		return false, "You don't have that companion yet."
	end
	local list = data.CompanionEquipped
	-- one of each companion
	for i = #list, 1, -1 do
		if list[i] == id then
			table.remove(list, i)
		end
	end
	if id == "" then
		if slot <= #list then
			table.remove(list, slot)
		end
	else
		list[math.min(slot, #list + 1)] = id
	end
	publish(player, data)
	S.StatsService.refresh(player)
	S.DataService.push(player)
	return true
end

function CompanionService.Init(services)
	S = services
end

function CompanionService.Start()
	S.Remotes.Handle("Summon", 0.8, { "number" }, function(player, count)
		if count ~= 1 and count ~= 10 then
			return false
		end
		return CompanionService.summon(player, count)
	end)
	S.Remotes.Handle("EquipCompanion", 0.2, { "string", "number" }, CompanionService.equip)
	S.DataService.Loaded:Connect(function(player, data, isNew)
		if isNew then
			-- enough for the first summon in the tutorial
			S.DataService.add(player, "Spirit", Config.SummonCost.One)
		end
		publish(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		target[player] = nil
		nextSkill[player] = nil
	end)
	-- companion skills: every Interval s each equipped companion hits the owner's target
	while true do
		task.wait(0.25)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local mob = target[player]
			local data = S.DataService.data(player)
			if mob and data and player:GetAttribute("InGrounds") then
				local hp = mob.Parent and mob:GetAttribute("HP")
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not hp or hp <= 0 or not hrp or not mob.PrimaryPart or (mob.PrimaryPart.Position - hrp.Position).Magnitude > 45 then
					target[player] = nil
				else
					nextSkill[player] = nextSkill[player] or {}
					for _, id in ipairs(data.CompanionEquipped) do
						local def = Config.Companions[id]
						local due = nextSkill[player][id] or 0
						if def and now >= due then
							nextSkill[player][id] = now + def.Skill.Interval
							local stars = data.Companions[id] and data.Companions[id].Stars or 1
							local mult = def.Skill.Mult * (1 + (stars - 1) * Config.CompanionStars.StarBonus)
							local amount, crit = S.CombatService.rollDamage(player, mult)
							S.MobService.damage(mob, player, amount, crit, id)
						end
					end
				end
			end
		end
	end
end

return CompanionService
