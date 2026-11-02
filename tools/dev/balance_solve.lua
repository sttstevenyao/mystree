-- Dev tool (Studio, Edit): back-solves mob base stats from fight-time targets (balance_sim's player
-- model). Prints the base HP / Dmg each mob needs so that, against the reference player, it takes
-- TTK seconds to kill and TTD seconds to kill you. Paste the results into Config.Mobs by hand.
--   loadstring(...)(zoneId)
local folder = game:GetService("ReplicatedStorage").Mystree
local cfgCopy = folder.Config:Clone()
cfgCopy.Parent = folder
local fresh = require(cfgCopy)
cfgCopy:Destroy()
local Config = require(folder.Config)
for k, v in pairs(fresh) do
	Config[k] = v
end
local rc = folder.Rules:Clone()
rc.Parent = folder
local Rules = require(rc)
rc:Destroy()
local rng = Random.new(7)

local function onePlayer(P)
	local T = math.clamp(math.floor(P / 2 + 0.5), 1, Config.Tree.MaxLevel)
	local inv, eq = {}, {}
	for _, slot in ipairs(Config.Slots) do
		local best
		for _ = 1, 60 do
			local it = Rules.rollItem(T, math.min(Rules.rollRarity(T, {}, rng), Rules.maxRarity(T)), rng, slot)
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
	local s = Rules.totals({ Level = P, Inventory = inv, Equipped = eq, Companions = { [comp] = { Stars = 2 } }, CompanionEquipped = { comp } })
	local sk = Config.Companions[comp].Skill
	return { S = s, DPS = s.ATK * (3.7 / 1.46) * 0.85 * (1 + s.AttackSpeed) * (1 + s.CritChance * s.CritDamage) + s.ATK * sk.Mult / sk.Interval }
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

-- targets per kind: { reference ("min"/"max" of the zone), TTK, TTD }
local T = {
	Normal = { "min", 3.5, 75 },
	Elite = { "min", 30, 55 },
	Rare = { "min", 45, 75 },
	Boss = { "max", 120, 150 },
	Mythic = { "max", 240, 180 },
}
local zoneId = ...
local out = {}
for _, z in ipairs(Config.Zones) do
	if z.Id == zoneId then
		local ref = { min = player(z.MinLevel), max = player(z.MaxLevel) }
		local ids, seen = {}, {}
		local function add(id)
			if not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
		for _, c in ipairs(z.Camps) do add(c.Mob) end
		for _, c in ipairs(z.NightCamps or {}) do add(c.Mob) end
		add(z.Elite)
		add(z.Rare.Mob)
		add(z.Boss.Mob)
		for _, id in ipairs(ids) do
			local def = Config.Mobs[id]
			local t = T[def.Kind]
			local pl = ref[t[1]]
			local L = def.Level
			local g = Config.MobScaling
			local hp = t[2] * pl.DPS
			local sustain = pl.S.Lifesteal * pl.DPS + pl.S.HP * 0.01
			local incoming = pl.S.HP / t[3] + sustain -- per second, before the 0.75 dodge factor
			local hit = incoming / 0.75 * def.AttackTime
			local k = 100 + 10 * L
			local dmg = hit * (k + pl.S.DEF) / k
			table.insert(out, string.format("%s L%d: HP %.0f (base %.1f, now %d)  Dmg %.0f (base %.2f, now %s)", id, L, hp, hp / g.HPGrowth ^ L, def.HP, dmg, dmg / g.DmgGrowth ^ L, tostring(def.Dmg)))
		end
		table.insert(out, string.format("ref min DPS %d HP %d DEF %d | max DPS %d HP %d DEF %d", ref.min.DPS, ref.min.S.HP, ref.min.S.DEF, ref.max.DPS, ref.max.S.HP, ref.max.S.DEF))
	end
end
return table.concat(out, "\n")
