-- Dev tool (Studio, Edit): combat balance simulation for the Wildlands, using the game's own Rules.
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/balance_sim.lua?" .. os.clock(), true))()
-- Model (see CHO/Mystree Kickoff.md 5h for the targets):
--  * a player at level P with the "matching" tree T = clamp(round(P / 2), 1, 30);
--  * gear: per slot the best CP of 60 drops rolled at the tree's odds (what a player keeps); the median
--    of 9 such players by DPS is used;
--  * one companion (Fox Spirit to tree 7, Thunder Hawk to 14, Frost Wolf 2* after), no sets/Myth;
--  * DPS = sword combo (3.7 ATK per 1.46 s) x 0.85 uptime x attack speed x crit, + companion skill;
--  * mob DPS = mitigated hit / AttackTime x 0.75 (some windups dodged); sustain = lifesteal + 1%/s regen.
-- Prints per zone (at its min and max level) time-to-kill and time-to-die for each kind.
local folder = game:GetService("ReplicatedStorage").Mystree
-- fresh Config/Rules (require caches modules for the Studio session)
local cfgCopy = folder.Config:Clone()
cfgCopy.Name = "Config_sim"
cfgCopy.Parent = folder
local okCfg, fresh = pcall(require, cfgCopy)
cfgCopy:Destroy()
if not okCfg then
	return "Config failed: " .. tostring(fresh)
end
local Config = require(folder.Config)
for k, v in pairs(fresh) do
	Config[k] = v
end
local rulesCopy = folder.Rules:Clone()
rulesCopy.Name = "Rules_sim"
rulesCopy.Parent = folder
local Rules = require(rulesCopy)
rulesCopy:Destroy()

local rng = Random.new(7)
local SAMPLES = 60

local function onePlayer(P)
	local T = math.clamp(math.floor(P / 2 + 0.5), 1, Config.Tree.MaxLevel)
	local inv, eq = {}, {}
	for _, slot in ipairs(Config.Slots) do
		local best
		for _ = 1, SAMPLES do
			local r = math.min(Rules.rollRarity(T, {}, rng), Rules.maxRarity(T))
			local it = Rules.rollItem(T, r, rng, slot)
			if slot == "Weapon" then
				it.Class = "Sword"
			end
			if not best or Rules.itemCP(it) > Rules.itemCP(best) then
				best = it
			end
		end
		inv[slot] = best
		eq[slot] = slot
	end
	local comp = (T < 8 and "FoxSpirit") or (T < 15 and "ThunderHawk") or "FrostWolf"
	local data = { Level = P, Inventory = inv, Equipped = eq, Companions = { [comp] = { Stars = 2 } }, CompanionEquipped = { comp } }
	local s = Rules.totals(data)
	local skill = Config.Companions[comp].Skill
	local dps = s.ATK * (3.7 / 1.46) * 0.85 * (1 + s.AttackSpeed) * (1 + s.CritChance * s.CritDamage) + s.ATK * skill.Mult / skill.Interval
	return { P = P, T = T, S = s, DPS = dps, Weapon = inv.Weapon }
end

-- the median of 9 rolled players by DPS (one roll swings +-40% on the weapon's rarity alone)
local function player(P)
	local list = {}
	for _ = 1, 9 do
		table.insert(list, onePlayer(P))
		task.wait() -- yield between players: one call ran ~25k item rolls and froze Studio
	end
	table.sort(list, function(a, b)
		return a.DPS < b.DPS
	end)
	return list[5]
end

local function fight(pl, mobId, level)
	local def = Config.Mobs[mobId]
	local st = Rules.mobStats(def, level)
	local ttk = st.HP / pl.DPS
	local hit = Rules.mitigate(st.Dmg, pl.S.DEF, level)
	local incoming = hit / def.AttackTime * 0.75
	local sustain = pl.S.Lifesteal * pl.DPS + pl.S.HP * 0.01
	local net = incoming - sustain
	local ttd = net > 0 and pl.S.HP / net or math.huge
	return ttk, ttd, st, hit
end

local function fmt(t)
	if t == math.huge then
		return "inf"
	end
	return t >= 100 and string.format("%.0f", t) or string.format("%.1f", t)
end

local out = {}
local only = ... -- optional zone id filter
for _, z in ipairs(Config.Zones) do
	if not only or only == z.Id then
		for _, P in ipairs({ z.MinLevel, z.MaxLevel }) do
			local pl = player(math.max(1, P))
			table.insert(out, string.format("== %s  player L%d tree %d  ATK %d HP %d DEF %d  DPS %d  (wpn R%d)", z.Name, pl.P, pl.T, pl.S.ATK, pl.S.HP, pl.S.DEF, pl.DPS, pl.Weapon.R))
			local rows = {}
			local seen = {}
			for _, c in ipairs(z.Camps) do
				if not seen[c.Mob] then
					seen[c.Mob] = true
					table.insert(rows, c.Mob)
				end
			end
			for _, c in ipairs(z.NightCamps or {}) do
				if not seen[c.Mob] then
					seen[c.Mob] = true
					table.insert(rows, c.Mob)
				end
			end
			table.insert(rows, z.Elite)
			table.insert(rows, z.Rare.Mob)
			table.insert(rows, z.Boss.Mob)
			for _, id in ipairs(rows) do
				local def = Config.Mobs[id]
				local ttk, ttd, st, hit = fight(pl, id, def.Level)
				table.insert(out, string.format("  %-15s %-6s L%-3d HP %-8d hit %-6d TTK %-6s TTD %s", id, def.Kind, def.Level, st.HP, hit, fmt(ttk), fmt(ttd)))
			end
			-- a Mythic beast showing up in this zone (level = zone max + 5)
			local ttk, ttd, st = fight(pl, "HeavenlyQilin", z.MaxLevel + 5)
			table.insert(out, string.format("  %-15s %-6s L%-3d HP %-8d TTK %-6s TTD %s", "HeavenlyQilin", "Mythic", z.MaxLevel + 5, st.HP, fmt(ttk), fmt(ttd)))
			-- hunting income per hour vs this tree level's growth cost. Kill rate: 75% of the time on
			-- normals (TTK + 3 s to walk / regen each), 6 elites and 3 boss kills an hour.
			local function avg(drops, key)
				local d = drops and drops[key]
				return d and d[1] * (d[2] + d[3]) / 2 or 0
			end
			local income = { Scraps = 0, Sap = 0, Heartwood = 0 }
			local normalTTK = fight(pl, z.Camps[1].Mob, Config.Mobs[z.Camps[1].Mob].Level)
			for _, e in ipairs({ { z.Camps[1].Mob, 3600 * 0.75 / (normalTTK + 3) }, { z.Elite, 6 }, { z.Boss.Mob, 3 } }) do
				local def = Config.Mobs[e[1]]
				local st = Rules.mobStats(def, def.Level)
				income.Scraps += st.Scraps * e[2]
				income.Sap += avg(def.Drops, "Sap") * e[2]
				income.Heartwood += avg(def.Drops, "Heartwood") * e[2]
			end
			local cost, secs = Rules.growthCost(pl.T)
			local parts = {}
			for _, k in ipairs({ "Scraps", "Sap", "Heartwood" }) do
				if cost[k] then
					table.insert(parts, string.format("%s %.1fh", k, cost[k] / math.max(1, income[k])))
				end
			end
			table.insert(out, string.format("  tree %d growth: %.1fh timer; hunting here pays it in %s", pl.T, secs / 3600, table.concat(parts, ", ")))
			-- levelling pace: normal kills per level here
			local normal = Config.Mobs[z.Camps[1].Mob]
			local exp = Rules.mobStats(normal, normal.Level).Exp
			table.insert(out, string.format("  kills/level %d (exp %d of %d)", math.ceil(Rules.expToNext(pl.P) / exp), exp, Rules.expToNext(pl.P)))
		end
	end
end
return table.concat(out, "\n")
