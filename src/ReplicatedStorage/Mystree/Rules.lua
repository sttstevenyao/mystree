-- ReplicatedStorage/Mystree/Rules (ModuleScript)
-- Pure game math shared by server and client: rarity rolls, item generation, stat totals, CP,
-- level curve, tree growth costs. No Instances, no state, so it works in admin tools and previews.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)

local Rules = {}

local STATS = { "ATK", "HP", "DEF", "AGL" }
Rules.Stats = STATS

-- ===================================================================== rarity
-- Weights for a tree level, interpolated between the anchor levels in Config.Tree.Weights
function Rules.treeWeights(level)
	local anchors = {}
	for l in pairs(Config.Tree.Weights) do
		table.insert(anchors, l)
	end
	table.sort(anchors)
	local lo, hi = anchors[1], anchors[#anchors]
	for _, l in ipairs(anchors) do
		if l <= level then
			lo = l
		end
		if l >= level and hi >= l then
			hi = l
			break
		end
	end
	local a, b = Config.Tree.Weights[lo], Config.Tree.Weights[hi]
	local t = (hi == lo) and 0 or (level - lo) / (hi - lo)
	local out = {}
	local cap = Rules.maxRarity(level)
	for i = 1, #Config.Rarities do
		out[i] = (i <= cap) and ((a[i] or 0) + ((b[i] or 0) - (a[i] or 0)) * t) or 0
	end
	-- the top unlocked tier always has a small chance, so a new cap is felt right away
	if out[cap] <= 0 then
		out[cap] = 0.3
	end
	return out
end

-- opts: Luck (0..), Incense (bool), Shift (tiers up), Min (lowest rarity allowed)
function Rules.weightsFor(level, opts)
	opts = opts or {}
	local w = Rules.treeWeights(level)
	local n = #w
	if opts.Shift and opts.Shift > 0 then
		local shifted = table.create(n, 0)
		for i = 1, n do
			local j = math.min(n, i + opts.Shift)
			shifted[j] += w[i]
		end
		w = shifted
	end
	if opts.Luck and opts.Luck > 0 then
		for i = 3, n do
			w[i] *= 1 + opts.Luck
		end
	end
	if opts.Incense then
		for i = Config.Tree.IncenseFrom, n do
			w[i] *= Config.Tree.IncenseMult
		end
	end
	if opts.Charm then
		for i = 4, n do
			w[i] *= Config.FortuneMult
		end
	end
	-- nothing above the tree's max rarity, whatever the boosts (folded into the cap tier)
	local cap = Rules.maxRarity(level)
	for i = cap + 1, n do
		w[cap] += w[i]
		w[i] = 0
	end
	if opts.Min then
		opts.Min = math.min(opts.Min, cap)
		local moved = 0
		for i = 1, opts.Min - 1 do
			moved += w[i]
			w[i] = 0
		end
		-- the removed weight goes to the lowest allowed tier so the floor drop is the common case
		w[opts.Min] += moved * 0.75
		if w[opts.Min] <= 0 then
			w[opts.Min] = 1
		end
	end
	return w
end

-- weights as chances that sum to 1 (for odds screens)
function Rules.normalize(weights)
	local total = 0
	for _, v in ipairs(weights) do
		total += v
	end
	local out = {}
	for i, v in ipairs(weights) do
		out[i] = total > 0 and v / total or 0
	end
	return out
end

-- ===================================================================== summons
-- The tiers and weights of the NEXT summon for a pity count (summons since the last Legendary+).
-- The server rolls from this and the odds screen shows it, so the two can't disagree. At pity
-- Config.SummonPity - 1 the next summon is a guaranteed Legendary or better.
function Rules.summonTiers(pity)
	local tiers, weights = {}, {}
	for r in pairs(Config.SummonOdds) do
		table.insert(tiers, r)
	end
	table.sort(tiers)
	local guaranteed = (pity or 0) + 1 >= Config.SummonPity
	local moved = 0
	for i, r in ipairs(tiers) do
		local w = Config.SummonOdds[r]
		if guaranteed and r < 5 then
			moved += w
			w = 0
		end
		weights[i] = w
	end
	for i, r in ipairs(tiers) do
		if r == 5 then
			weights[i] += moved
		end
	end
	return tiers, weights
end

-- Every companion with its chance (0..1) for the next summon: { { Id, R, P } }, rarest first
function Rules.summonOdds(pity)
	local byRarity = {}
	for id, def in pairs(Config.Companions) do
		byRarity[def.Rarity] = byRarity[def.Rarity] or {}
		table.insert(byRarity[def.Rarity], id)
	end
	local tiers, weights = Rules.summonTiers(pity)
	local chance = Rules.normalize(weights)
	local out = {}
	for i, r in ipairs(tiers) do
		local list = byRarity[r] or {}
		table.sort(list)
		for _, id in ipairs(list) do
			table.insert(out, { Id = id, R = r, P = chance[i] / #list })
		end
	end
	table.sort(out, function(a, b)
		if a.R ~= b.R then
			return a.R > b.R
		end
		return a.Id < b.Id
	end)
	return out
end

function Rules.pickWeighted(weights, rng)
	local total = 0
	for _, v in ipairs(weights) do
		total += v
	end
	local r = rng:NextNumber() * total
	for i, v in ipairs(weights) do
		r -= v
		if r <= 0 and v > 0 then
			return i
		end
	end
	for i = #weights, 1, -1 do
		if weights[i] > 0 then
			return i
		end
	end
	return 1
end

function Rules.rollRarity(level, opts, rng)
	return Rules.pickWeighted(Rules.weightsFor(level, opts), rng)
end

-- ===================================================================== items
local function pickKey(map, rng)
	local keys, weights = {}, {}
	for k, v in pairs(map) do
		table.insert(keys, k)
	end
	table.sort(keys)
	for i, k in ipairs(keys) do
		weights[i] = map[k]
	end
	return keys[Rules.pickWeighted(weights, rng)]
end

-- A new item table (without Id; the server assigns it). Slot is random if nil.
function Rules.rollItem(treeLevel, rarity, rng, slot)
	slot = slot or Config.Slots[rng:NextInteger(1, #Config.Slots)]
	local item = { Slot = slot, R = rarity }
	if slot == "Weapon" then
		item.Class = pickKey(Config.Tree.ClassWeights, rng)
	end
	local spread = Config.ItemLevelSpread
	item.L = math.max(1, treeLevel * Config.ItemLevelPerTree + rng:NextInteger(-spread, spread))
	local mult = Config.Rarities[rarity].Mult * (1 + Config.ItemLevelGrowth * item.L)
	item.Main = {}
	for stat, base in pairs(Config.SlotMain[slot]) do
		local roll = Config.StatRoll[1] + rng:NextNumber() * (Config.StatRoll[2] - Config.StatRoll[1])
		item.Main[stat] = math.max(1, math.floor(base * mult * roll + 0.5))
	end
	item.Subs = {}
	local subKeys = {}
	for k in pairs(Config.Substats) do
		table.insert(subKeys, k)
	end
	table.sort(subKeys)
	for _ = 1, Config.Rarities[rarity].Subs do
		local k = table.remove(subKeys, rng:NextInteger(1, #subKeys))
		local def = Config.Substats[k]
		local v = (def.Lo + rng:NextNumber() * (def.Hi - def.Lo)) * (1 + 0.25 * (rarity - 1))
		item.Subs[k] = math.floor(v * 1000 + 0.5) / 1000
	end
	return item
end

local SLOT_NAMES = { Helm = "Helm", Armor = "Armor", Boots = "Boots", Gloves = "Gloves" }

function Rules.itemName(item)
	if item.Myth and Config.Forge.Myth[item.Myth] then
		return Config.Forge.Myth[item.Myth].Name
	end
	if item.Set and Config.ArmorSets[item.Set] then
		return Config.ArmorSets[item.Set].Name .. " " .. (SLOT_NAMES[item.Slot] or item.Slot)
	end
	local list = Config.ItemNames[item.Class or item.Slot]
	return list and list[item.R] or item.Slot
end

-- ===================================================================== armour sets
-- An armour set piece for a slot at the set's fixed rarity (mult on top of the normal main stats)
function Rules.rollSetItem(treeLevel, setId, rng, slot)
	local set = Config.ArmorSets[setId]
	slot = slot or Config.SetSlots[rng:NextInteger(1, #Config.SetSlots)]
	local item = Rules.rollItem(treeLevel, set.Rarity, rng, slot)
	item.Set = setId
	for k, n in pairs(item.Main) do
		item.Main[k] = math.floor(n * set.Mult + 0.5)
	end
	return item
end

-- { [setId] = pieces worn }
function Rules.setCounts(data)
	local counts = {}
	for _, id in pairs(data.Equipped or {}) do
		local item = data.Inventory and data.Inventory[id]
		if item and item.Set then
			counts[item.Set] = (counts[item.Set] or 0) + 1
		end
	end
	return counts
end

-- the active set bonuses summed: { ATK = 0.1 (as %), CritDamage = 0.25 (added), ... }
function Rules.setBonus(data)
	local out = {}
	for setId, n in pairs(Rules.setCounts(data)) do
		local set = Config.ArmorSets[setId]
		if set then
			for _, tier in ipairs({ { 2, set.Bonus2 }, { 4, set.Bonus4 } }) do
				if n >= tier[1] then
					for k, v in pairs(tier[2]) do
						out[k] = (out[k] or 0) + v
					end
				end
			end
		end
	end
	return out
end

-- one line per bonus, e.g. "+10% ATK", "+25% Crit Damage"
function Rules.bonusText(bonus)
	local parts = {}
	for k, v in pairs(bonus) do
		local name = (Config.Substats[k] and Config.Substats[k].Name) or k
		table.insert(parts, string.format("+%d%% %s", math.floor(v * 100 + 0.5), name))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-- ===================================================================== forging
-- forge materials for dismantling a list of items (weapons only)
function Rules.forgeYield(items)
	local out = {}
	for _, it in ipairs(items) do
		if it.Slot == "Weapon" then
			for k, n in pairs(Config.Forge.Dismantle[it.R] or {}) do
				out[k] = (out[k] or 0) + n
			end
		end
	end
	return out
end

-- can the player pay cost? have(key) -> amount. Returns ok, missingKey
function Rules.canPay(cost, have)
	for k, n in pairs(cost) do
		if have(k) < n then
			return false, k
		end
	end
	return true
end

-- a forged weapon: chosen class and rarity, max main roll, one extra substat
function Rules.forgeItem(treeLevel, rarity, class, rng)
	local item = Rules.rollItem(treeLevel, rarity, rng, "Weapon")
	item.Class = class
	local mult = Config.Rarities[rarity].Mult * (1 + Config.ItemLevelGrowth * item.L)
	for stat, base in pairs(Config.SlotMain.Weapon) do
		item.Main[stat] = math.max(1, math.floor(base * mult * Config.StatRoll[2] + 0.5))
	end
	local keys = {}
	for k in pairs(Config.Substats) do
		if not item.Subs[k] then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	if #keys > 0 then
		local k = keys[rng:NextInteger(1, #keys)]
		local def = Config.Substats[k]
		item.Subs[k] = math.floor(def.Hi * (1 + 0.25 * (rarity - 1)) * 1000 + 0.5) / 1000
	end
	item.Forged = true
	return item
end

-- a Mythforged weapon: Divine, its recipe's class, boosted stats and its effect (item.Myth)
function Rules.mythItem(treeLevel, mythId, rng)
	local def = Config.Forge.Myth[mythId]
	local item = Rules.forgeItem(treeLevel + 3, #Config.Rarities, def.Class, rng)
	for k, n in pairs(item.Main) do
		item.Main[k] = math.floor(n * def.Mult + 0.5)
	end
	item.Myth = mythId
	return item
end

-- A single number to sort and compare items: main stats by CP weight, lifted by its substats
function Rules.itemCP(item)
	local v = 0
	for stat, n in pairs(item.Main or {}) do
		v += n * (Config.CPWeights[stat] or 0)
	end
	local subs = 0
	for _, n in pairs(item.Subs or {}) do
		subs += n
	end
	return math.floor(v * (1 + subs) + 0.5)
end

-- The item's CP if it were at `level` (main stats scale with item level; substats don't). This is its
-- "potential": a Legendary L1 can out-grow an Epic L40, so it isn't junk even though it's weaker now.
function Rules.potentialCP(item, level)
	local g = Config.ItemLevelGrowth
	local scale = (1 + g * level) / (1 + g * (item.L or 1))
	local v = 0
	for stat, n in pairs(item.Main or {}) do
		v += n * scale * (Config.CPWeights[stat] or 0)
	end
	local subs = 0
	for _, n in pairs(item.Subs or {}) do
		subs += n
	end
	return math.floor(v * (1 + subs) + 0.5)
end

-- Bag items that are both worse than what's equipped in their slot now AND have no more potential
-- (CP at the equipped item's level). Skips equipped, locked, armour-set and Mythforged pieces, and
-- slots with nothing equipped. Returns a list of item ids.
function Rules.worseGear(data)
	local equippedIds, bySlot = {}, {}
	for slot, id in pairs(data.Equipped or {}) do
		equippedIds[id] = true
		bySlot[slot] = data.Inventory[id]
	end
	local out = {}
	for id, it in pairs(data.Inventory or {}) do
		local e = bySlot[it.Slot]
		if e and not equippedIds[id] and not it.Lock and not it.Set and not it.Myth then
			local eCP = Rules.itemCP(e)
			if Rules.itemCP(it) < eCP and Rules.potentialCP(it, e.L or 1) <= eCP then
				table.insert(out, id)
			end
		end
	end
	return out
end

function Rules.dismantleValue(item)
	return math.floor(Config.Rarities[item.R].Scraps * (1 + 0.15 * item.L) + 0.5)
end

-- ===================================================================== player totals
-- data: the save (Level, Equipped, Inventory, Companions, CompanionEquipped). Returns stats table:
-- { ATK, HP, DEF, AGL, CritChance, CritDamage, Lifesteal, AttackSpeed, MoveSpeed, DropLuck, ScrapBonus, CP }
function Rules.totals(data)
	local L = Config.Level
	local s = {}
	for _, k in ipairs(STATS) do
		s[k] = L.Start[k] + L.PerLevel[k] * ((data.Level or 1) - 1)
	end
	for k in pairs(Config.Substats) do
		s[k] = 0
	end
	for _, id in pairs(data.Equipped or {}) do
		local item = data.Inventory and data.Inventory[id]
		if item then
			for k, n in pairs(item.Main) do
				s[k] += n
			end
			for k, n in pairs(item.Subs) do
				s[k] = (s[k] or 0) + n
			end
		end
	end
	for k, def in pairs(Config.Substats) do
		if def.Cap then
			s[k] = math.min(s[k], def.Cap)
		end
	end
	-- companion % buffs (all equipped companions stack; one of each kind)
	local pct = { ATK = 0, HP = 0, DEF = 0, AGL = 0 }
	for _, cid in ipairs(data.CompanionEquipped or {}) do
		local buffs = Rules.companionBuffs(cid, data.Companions and data.Companions[cid])
		for k, v in pairs(buffs) do
			pct[k] = (pct[k] or 0) + v
		end
	end
	-- armour set bonuses: main stats as %, substats added (caps still apply)
	for k, v in pairs(Rules.setBonus(data)) do
		if pct[k] then
			pct[k] += v
		else
			s[k] = (s[k] or 0) + v
			local def = Config.Substats[k]
			if def and def.Cap then
				s[k] = math.min(s[k], def.Cap)
			end
		end
	end
	for _, k in ipairs(STATS) do
		s[k] = math.floor(s[k] * (1 + pct[k]) + 0.5)
	end
	s.CritDamage += 0.5 -- crits always do at least +50%
	s.CP = Rules.cp(s)
	return s
end

function Rules.cp(s)
	local w = Config.CPWeights
	local base = s.ATK * w.ATK + s.HP * w.HP + s.DEF * w.DEF + s.AGL * w.AGL
	local lift = 1 + s.CritChance * s.CritDamage + s.Lifesteal + s.AttackSpeed * 0.5
	return math.floor(base * lift + 0.5)
end

function Rules.companionBuffs(id, owned)
	local def = Config.Companions[id]
	if not def then
		return {}
	end
	local stars = (owned and owned.Stars) or 1
	local mult = 1 + (stars - 1) * Config.CompanionStars.StarBonus
	local out = {}
	for k, v in pairs(def.Buffs) do
		out[k] = v * mult
	end
	return out
end

-- ===================================================================== levels
function Rules.expToNext(level)
	return math.floor(Config.Level.Base * level ^ Config.Level.Power + 0.5)
end

-- "Qi Refinement II": realm name plus a sub-stage numeral within the realm
function Rules.realm(level)
	local idx = 1
	for i, r in ipairs(Config.Realms) do
		if level >= r.From then
			idx = i
		end
	end
	local r = Config.Realms[idx]
	local nextFrom = Config.Realms[idx + 1] and Config.Realms[idx + 1].From or (r.From + 30)
	local band = math.max(1, (nextFrom - r.From) / 3)
	local stage = math.clamp(math.floor((level - r.From) / band) + 1, 1, 3)
	return r.Name .. " " .. Format.Roman(stage)
end

-- ===================================================================== tree growth
-- cost to grow from level L to L+1: { Scraps = n }, seconds. The old Sap / Heartwood / event
-- material parts are priced in Scraps (Config.ScrapValue), so the curve is the same as before.
function Rules.growthCost(level)
	local T = Config.Tree
	local cost = {}
	cost.Scraps = math.floor(T.GrowthScraps.Base * T.GrowthScraps.Mult ^ (level - 1) + 0.5)
	if level >= T.GrowthSap.From then
		cost.Sap = math.floor(T.GrowthSap.Base * T.GrowthSap.Mult ^ (level - T.GrowthSap.From) + 0.5)
	end
	if level >= T.GrowthHeartwood.From then
		cost.Heartwood = math.floor(T.GrowthHeartwood.Base * T.GrowthHeartwood.Mult ^ (level - T.GrowthHeartwood.From) + 0.5)
	end
	local nextLevel = level + 1
	if nextLevel % T.GrowthEventMat.Every == 0 then
		local mat = ((nextLevel // T.GrowthEventMat.Every) % 2 == 1) and "BloodAmber" or "Sunstone"
		cost[mat] = T.GrowthEventMat.Amount + nextLevel // 10
	end
	Config.scrapsOf(cost)
	local seconds = T.GrowthTime * level * level
	if level == 1 and T.FreeFirstGrowth then
		cost = {}
		seconds = 0
	end
	return cost, seconds
end

-- ===================================================================== rarity cap by tree level
-- The best rarity the tree can drop at this level (Config.Tree.MaxRarity anchors)
function Rules.maxRarity(level)
	local best = 1
	for l, r in pairs(Config.Tree.MaxRarity) do
		if level >= l and r > best then
			best = r
		end
	end
	return best
end

-- the level the next rarity unlocks at (nil when Divine is already unlocked)
function Rules.nextRarityLevel(level)
	local cur = Rules.maxRarity(level)
	local nextLevel
	for l, r in pairs(Config.Tree.MaxRarity) do
		if r > cur and (not nextLevel or l < nextLevel) then
			nextLevel = l
		end
	end
	return nextLevel
end

-- chance of a scaled lucky bonus at this tree level
function Rules.luckyChance(def, treeLevel)
	return math.min(def.Max, def.Base + def.PerLevel * ((treeLevel or 1) - 1))
end

-- ===================================================================== quests
local GOAL_VERB = {
	Chop = function(g) return string.format("Chop your tree %d times", g.Need) end,
	Kill = function(g)
		if g.Mob then
			local def = Config.Mobs[g.Mob]
			return g.Need == 1 and ("Defeat the " .. def.Name) or string.format("Defeat %d %ss", g.Need, def.Name)
		end
		return string.format("Defeat %d monsters", g.Need)
	end,
	Elite = function(g) return g.Need == 1 and "Defeat an Elite" or string.format("Defeat %d Elites", g.Need) end,
	Boss = function(g) return g.Need == 1 and "Defeat a boss" or string.format("Defeat %d bosses", g.Need) end,
	TreeLevel = function(g) return "Grow your tree to Lv " .. g.Need end,
	Level = function(g) return "Reach Lv " .. g.Need end,
	Bring = function(g) return string.format("Bring %d %s", g.Need, Config.Materials[g.Mat].Name) end,
	Summon = function(g) return g.Need == 1 and "Summon a Spirit" or string.format("Summon %d Spirits", g.Need) end,
	Companions = function(g) return g.Need == 1 and "Befriend a Spirit" or string.format("Own %d Spirits", g.Need) end,
	Dismantle = function(g) return string.format("Dismantle %d pieces of gear", g.Need) end,
	Equipped = function(g) return string.format("Wear %d pieces of gear", g.Need) end,
	EquipRarity = function(g) return string.format("Wear a %s+ %s", Config.Rarities[g.Rarity].Name, string.lower(g.Slot or "item")) end,
	Visit = function() return "Go to the Hunting Grounds" end,
}
function Rules.goalText(goal)
	local f = GOAL_VERB[goal.Type]
	return f and f(goal) or goal.Type
end

-- side quest rewards grow with the tree; main quest rewards are fixed
function Rules.questReward(reward, treeLevel, side)
	local out = {}
	local k = side and (1 + Config.Quests.SideScale * ((treeLevel or 1) - 1)) or 1
	for key, n in pairs(reward) do
		if side and key == "Scraps" then
			out[key] = math.floor(n * k + 0.5)
		else
			out[key] = n
		end
	end
	return out
end

function Rules.rewardText(reward)
	local parts = {}
	for k, n in pairs(reward) do
		if k == "Gear" then
			table.insert(parts, Config.Rarities[math.clamp(n, 1, #Config.Rarities)].Name .. "+ gear")
		elseif k == "Exp" then
			table.insert(parts, "+" .. Format.Num(n) .. " EXP")
		else
			local name = (Config.Currencies[k] and Config.Currencies[k].Name) or (Config.Materials[k] and Config.Materials[k].Name) or k
			table.insert(parts, "+" .. Format.Num(n) .. " " .. name)
		end
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-- ===================================================================== island decor
-- Can a decor piece go at island-local (x, z)? decor = the island's placed list; skip = an index to
-- ignore (when moving a piece). Returns ok, reason. Same check on client (ghost colour) and server.
function Rules.canPlace(decor, id, x, z, skip)
	local def = Config.Decor[id]
	if not def then
		return false, "Unknown decor."
	end
	local I = Config.Island
	if math.sqrt(x * x + z * z) + def.Radius > Config.Map.IslandRadius - I.EdgeMargin then
		return false, "Too close to the edge."
	end
	for _, c in ipairs(I.Clear) do
		local dx, dz = x - c[1], z - c[2]
		if math.sqrt(dx * dx + dz * dz) < c[3] + def.Radius then
			return false, "Keep this spot clear."
		end
	end
	local count = 0
	for i, d in ipairs(decor) do
		if i ~= skip then
			count += 1
			local other = Config.Decor[d.Id]
			local dx, dz = x - d.X, z - d.Z
			if other and math.sqrt(dx * dx + dz * dz) < def.Radius + other.Radius then
				return false, "Too close to your " .. other.Name .. "."
			end
		end
	end
	if not skip and count >= I.MaxDecor then
		return false, string.format("Your island holds %d pieces.", I.MaxDecor)
	end
	return true
end

-- Decor buffs: strongest of each kind counts, kinds stack. Returns { Luck, ScrapBonus }
function Rules.decorBuffs(decor)
	local out = { Luck = 0, ScrapBonus = 0 }
	for _, d in ipairs(decor or {}) do
		local def = Config.Decor[d.Id]
		if def and def.Buff then
			out[def.Buff.Kind] = math.max(out[def.Buff.Kind] or 0, def.Buff.Value)
		end
	end
	return out
end

-- ===================================================================== mobs
-- def.Growth (optional) overrides Config.MobScaling per key: Mythic beasts appear at levels 15-65,
-- so they grow at the player's pace instead of the zone mobs' steeper curve.
function Rules.mobStats(def, level)
	local g = Config.MobScaling
	local o = def.Growth or {}
	return {
		HP = math.floor(def.HP * (o.HP or g.HPGrowth) ^ level + 0.5),
		Dmg = math.floor(def.Dmg * (o.Dmg or g.DmgGrowth) ^ level + 0.5),
		Exp = math.floor(def.Exp * (o.Exp or g.ExpGrowth) ^ level + 0.5),
		Scraps = math.floor(def.Scraps * (o.Scraps or g.ScrapGrowth) ^ level + 0.5),
	}
end

-- damage after DEF: mitigation grows with DEF and falls with attacker level
function Rules.mitigate(damage, def, attackerLevel)
	local k = 100 + 10 * attackerLevel
	return math.max(1, math.floor(damage * k / (k + def) + 0.5))
end

return Rules
