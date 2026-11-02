-- ReplicatedStorage/Mystree/Config (ModuleScript)
-- Every tunable number, name, price and colour (Playbook 09: Config is the source of truth).
-- Comments above values explain the tuning. Design: CHO/Mystree Kickoff.md in the vault.

local Config = {}

Config.DataStoreName = "Mystree_v1"
-- v2: tutorial fields (Tutorial, TutorialBase)
Config.DataVersion = 3 -- v3: one gold (retired materials and Mount Shards converted to Scraps)
Config.AutosaveInterval = 90
-- a lock younger than this belongs to a live server (it re-stamps on every autosave)
Config.LockStale = 300
Config.LockWaits = 5
Config.MaxReceipts = 50
-- Studio only: make the tester an admin and let Id = 0 products grant for free
Config.Admins = {}

-- ===================================================================== rarity
-- One ladder for gear, companions and announcements. Colours are used everywhere (tiles, beams,
-- names, borders). Stat mults climb ~1.45x per tier so tree level still matters next to rarity.
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(201, 194, 173), Mult = 1.0, Subs = 0, Scraps = 2 },
	{ Name = "Uncommon", Color = Color3.fromRGB(122, 186, 92), Mult = 1.4, Subs = 1, Scraps = 5 },
	{ Name = "Rare", Color = Color3.fromRGB(78, 152, 222), Mult = 2.0, Subs = 1, Scraps = 14 },
	{ Name = "Epic", Color = Color3.fromRGB(167, 108, 226), Mult = 2.9, Subs = 2, Scraps = 40 },
	{ Name = "Legendary", Color = Color3.fromRGB(244, 160, 48), Mult = 4.2, Subs = 3, Scraps = 120 },
	{ Name = "Mythic", Color = Color3.fromRGB(232, 72, 64), Mult = 6.2, Subs = 4, Scraps = 400 },
	{ Name = "Divine", Color = Color3.fromRGB(255, 244, 196), Mult = 9.0, Subs = 4, Scraps = 1500 },
}
-- drops at or above this tier get a beam, a big card and a sound (no server announcements for drops)
Config.BeamRarity = 3

-- ===================================================================== gear
-- 8 slots (the reference has 12; 8 keeps the art budget sane). Main stats per item level 1.
Config.Slots = { "Weapon", "Helm", "Armor", "Boots", "Belt", "Gloves", "Necklace", "Ring" }
Config.SlotMain = {
	Weapon = { ATK = 12 },
	Helm = { HP = 60, DEF = 2 },
	Armor = { HP = 100, DEF = 4 },
	Boots = { HP = 40, AGL = 6 },
	Belt = { HP = 80 },
	Gloves = { ATK = 5, AGL = 4 },
	Necklace = { ATK = 6, HP = 40 },
	Ring = { ATK = 7, DEF = 1 },
}
-- Each stat point grows by this share per item level
Config.ItemLevelGrowth = 0.18
-- item level = tree level * this, +- ItemLevelSpread
Config.ItemLevelPerTree = 2
Config.ItemLevelSpread = 1
Config.StatRoll = { 0.9, 1.1 }

-- Substats (rolled count from the rarity). Ranges grow with rarity: value = lo..hi * (1 + 0.25 * (rarity - 1))
Config.Substats = {
	CritChance = { Name = "Crit Chance", Lo = 0.01, Hi = 0.03, Pct = true, Cap = 0.6 },
	CritDamage = { Name = "Crit Damage", Lo = 0.05, Hi = 0.12, Pct = true },
	Lifesteal = { Name = "Lifesteal", Lo = 0.005, Hi = 0.015, Pct = true, Cap = 0.25 },
	AttackSpeed = { Name = "Attack Speed", Lo = 0.02, Hi = 0.05, Pct = true, Cap = 0.6 },
	MoveSpeed = { Name = "Move Speed", Lo = 0.01, Hi = 0.03, Pct = true, Cap = 0.3 },
	DropLuck = { Name = "Drop Luck", Lo = 0.01, Hi = 0.03, Pct = true, Cap = 0.5 },
	ScrapBonus = { Name = "Peach Bonus", Lo = 0.03, Hi = 0.08, Pct = true },
}

-- Weapon classes: each has its own moveset (client Combat) and hitbox. Damage is ATK * Mult.
-- Range/Width/Arc describe the server hitbox in front of the player.
Config.WeaponClasses = {
	Sword = {
		Combo = {
			{ Mult = 1.0, Time = 0.42, Range = 9, Arc = 110 },
			{ Mult = 1.1, Time = 0.42, Range = 9, Arc = 110 },
			{ Mult = 1.6, Time = 0.62, Range = 10, Arc = 140 },
		},
	},
	Greatsword = {
		Combo = {
			{ Mult = 1.9, Time = 0.8, Range = 11, Arc = 160 },
			{ Mult = 2.8, Time = 1.05, Range = 12, Arc = 200 },
		},
	},
	Spear = {
		Combo = {
			{ Mult = 1.1, Time = 0.5, Range = 14, Arc = 40 },
			{ Mult = 1.1, Time = 0.5, Range = 14, Arc = 40 },
			{ Mult = 1.9, Time = 0.75, Range = 17, Arc = 50 },
		},
	},
}
Config.ComboReset = 1.1 -- seconds after a swing before the combo starts over
Config.HitStop = 0.05 -- client-side freeze on hit, sells the impact

-- Display names by slot/class and rarity (plain names, Playbook 08)
Config.ItemNames = {
	Sword = { "Iron Sword", "Steel Sword", "Jade Sword", "Moonsteel Sword", "Dragonbone Sword", "Bloodfang Sword", "Heavenfall Sword" },
	Greatsword = { "Iron Greatsword", "Steel Greatsword", "Jade Greatsword", "Moonsteel Greatsword", "Dragonbone Greatsword", "Bloodfang Greatsword", "Heavenfall Greatsword" },
	Spear = { "Iron Spear", "Steel Spear", "Jade Spear", "Moonsteel Spear", "Dragonbone Spear", "Bloodfang Spear", "Heavenfall Spear" },
	Helm = { "Cloth Hood", "Leather Cap", "Jade Helm", "Moonsteel Helm", "Dragonbone Helm", "Bloodfang Crown", "Heavenfall Crown" },
	Armor = { "Cloth Robe", "Leather Vest", "Jade Mail", "Moonsteel Plate", "Dragonbone Plate", "Bloodfang Plate", "Heavenfall Robe" },
	Boots = { "Straw Sandals", "Leather Boots", "Jade Boots", "Moonsteel Greaves", "Dragonbone Greaves", "Bloodfang Greaves", "Heavenfall Steps" },
	Belt = { "Rope Belt", "Leather Belt", "Jade Sash", "Moonsteel Girdle", "Dragonbone Girdle", "Bloodfang Sash", "Heavenfall Sash" },
	Gloves = { "Cloth Wraps", "Leather Gloves", "Jade Bracers", "Moonsteel Gauntlets", "Dragonbone Gauntlets", "Bloodfang Claws", "Heavenfall Bracers" },
	Necklace = { "Bead Necklace", "Bone Charm", "Jade Pendant", "Moonstone Pendant", "Dragon Eye", "Blood Pearl", "Heaven Pearl" },
	Ring = { "Copper Ring", "Silver Ring", "Jade Ring", "Moonstone Ring", "Dragon Ring", "Bloodstone Ring", "Heaven Ring" },
}
Config.BagSize = 60
Config.BigBagExtra = 150

-- Combat Power weights (CP = sum(stat * weight) * (1 + crit/lifesteal value))
Config.CPWeights = { ATK = 4, HP = 0.35, DEF = 5, AGL = 1.5 }

-- ===================================================================== player level
-- EXP for L -> L+1 = Base * L^Power. Mobs give most of it; each chop gives ChopExp.
Config.Level = {
	Base = 20,
	Power = 1.6,
	Max = 120,
	ChopExp = 1,
	-- base stats per level
	PerLevel = { ATK = 4, HP = 40, DEF = 1, AGL = 1 },
	Start = { ATK = 10, HP = 200, DEF = 2, AGL = 10 },
}
-- Realm title by level band (cultivation genre terms, shown as "Lv.12 · Qi Refinement II")
Config.Realms = {
	{ From = 1, Name = "Mortal" },
	{ From = 10, Name = "Qi Refinement" },
	{ From = 25, Name = "Foundation" },
	{ From = 45, Name = "Core Formation" },
	{ From = 70, Name = "Nascent Soul" },
	{ From = 100, Name = "Ascendant" },
}

-- ===================================================================== the Divine Tree
Config.Tree = {
	MaxLevel = 30,
	-- manual chop cooldown (tap as fast as the swing) and auto-chop interval
	ChopCooldown = 0.45,
	AutoInterval = 1.0,
	SwiftAutoInterval = 0.5,
	-- how close you must stand to your tree to chop (server check)
	ChopRange = 22,
	-- Growth: cost and time for L -> L+1. Every 5th level needs an event material.
	GrowthScraps = { Base = 80, Mult = 1.55 },
	GrowthSap = { From = 2, Base = 5, Mult = 1.4 },
	GrowthHeartwood = { From = 6, Base = 2, Mult = 1.3 },
	GrowthEventMat = { Every = 5, Amount = 3 }, -- Blood Amber on odd milestones, Sunstone on even
	GrowthTime = 30, -- seconds * L^2 (L10 = 50 min, L29 = 7 h)
	-- the first growth is free and instant (tutorial burst)
	FreeFirstGrowth = true,
	-- Rarity weights (%) at anchor tree levels; levels in between interpolate.
	Weights = {
		[1] = { 78, 19, 3, 0, 0, 0, 0 },
		[3] = { 65, 26, 8, 1, 0, 0, 0 },
		[5] = { 52, 30, 14, 3.6, 0.4, 0, 0 },
		[10] = { 35, 32, 22, 8.5, 2.2, 0.3, 0 },
		[15] = { 24, 30, 27, 13, 5, 0.9, 0.1 },
		[20] = { 15, 26, 30, 18, 8.5, 2.2, 0.3 },
		[25] = { 9, 20, 30, 23, 12.5, 4.5, 1 },
		[30] = { 5, 14, 28, 27, 17, 7, 2 },
	},
	-- weapon class split for Weapon drops
	ClassWeights = { Sword = 50, Greatsword = 25, Spear = 25 },
	-- Variable-ratio bonuses on top of the guaranteed drop (Playbook 01). Rare at the start and
	-- richer with the tree (user, 2026-10-26): chance = Base + PerLevel * (L - 1), capped at Max;
	-- amounts scale with tree level, so a lucky find stays exciting late.
	Lucky = {
		-- bonus Scraps = N chops of dismantle value at this tree level
		Chip = { Base = 0.03, PerLevel = 0.004, Max = 0.14, ChopsWorth = { 2, 6 } },
		-- Sap: 2..5 * (1 + L / 10)
		SapBurst = { Base = 0.01, PerLevel = 0.001, Max = 0.04, Sap = { 2, 5 } },
		-- a guaranteed drop at the tree's max rarity and a server announcement
		GoldenBough = { Chance = 0.003 },
	},
	-- The best rarity the tree can drop at a level (user: "max rarity pullable"). Nothing goes above
	-- it: not Lucky Incense, Drop Luck, elite shifts or the Golden Bough.
	MaxRarity = { [1] = 3, [2] = 4, [6] = 5, [12] = 6, [20] = 7 },
	-- Lucky Incense multiplies Epic-and-up weights
	IncenseMult = 2,
	IncenseFrom = 4,
	-- Growth stage scale for the placeholder model (5 stages across 30 levels)
	StageEvery = 6,
}
-- Auto-dismantle: drops below this rarity are dismantled on the spot (player can change it).
-- Auto-equip puts on any drop with more CP than what's in its slot.
Config.DefaultAutoDismantle = 1 -- 0 = off, 1 = Common, 2 = up to Uncommon, ...

-- ===================================================================== materials & currencies
-- One gold (user, 2026-10-27: "too many currencies"): Sap, Heartwood, Blood Amber, Sunstone, Mount
-- Shards and the forge ores (Iron Shards, Spirit Steel, Star Shards) are gone; everything they paid
-- for costs Scraps. Older tables below may still name them: the "derived" pass at the end turns
-- them into Scraps at these values, and DataService converts old saves the same way.
-- Peaches = the old chop energy (retired 2026-10-28: chopping is free); the main currency is now
-- SHOWN as Peaches (Config.Currencies.Scraps.Name), its save key stays "Scraps"
Config.ScrapValue = { Sap = 6, Heartwood = 60, BloodAmber = 150, Sunstone = 150, MountShards = 40, IronShard = 25, SpiritSteel = 250, StarShard = 1200, Peaches = 20 }
-- Only the three relics are left as materials: Mythic beast trophies, spent in the Forge.
Config.Materials = {
	-- Desc = the tooltip: what it's for, then where it comes from
	QilinHorn = { Name = "Qilin Horn", Kind = "Relic", Color = Color3.fromRGB(140, 230, 190), Desc = "A relic. Only the Heavenly Qilin drops it. Forges Qilin's Verdict." },
	FoxTail = { Name = "Fox Tail", Kind = "Relic", Color = Color3.fromRGB(255, 200, 200), Desc = "A relic. Only the Nine-Tailed Fox drops it. Forges Foxfire Fang." },
	RocFeather = { Name = "Roc Feather", Kind = "Relic", Color = Color3.fromRGB(120, 160, 255), Desc = "A relic. Only the Thunder Roc drops it. Forges Stormtalon." },
}
Config.Currencies = {
	-- (key "Scraps" for saves; players see Peaches, the Divine Tree's fruit)
	Scraps = { Name = "Peaches", Desc = "Immortal peaches, the one currency: grow your tree, forge gear, unlock mounts and island themes. From chopping, beasts, quests and dismantling gear." },
	Spirit = { Name = "Spirit Stones", Desc = "Summon spirit companions at the shrine. Earned from quests, daily gifts and bosses." },
}

-- ===================================================================== world: day/night + events
Config.Cycle = {
	Length = 300, -- each Day and each Night lasts 5 minutes
	-- chance that a switch into Night is a Bloodmoon / into Day is a Golden Hour
	Events = {
		Bloodmoon = { Phase = "Night", Chance = 0.05, Boss = "GodlySkeleton", Mobs = "BloodSkeleton", Material = "BloodAmber" },
		GoldenHour = { Phase = "Day", Chance = 0.05, Boss = "JadeTortoise", Mobs = "GoldenStag", Material = "Sunstone" },
	},
	-- event mobs spawned per zone when an event starts
	EventMobsPerZone = 4,
}
-- Lighting presets the client tweens between (ClockTime runs through each phase)
Config.Lighting = {
	Day = { ClockFrom = 7, ClockTo = 17, Ambient = Color3.fromRGB(110, 115, 120), Bright = 2.6, Tint = Color3.fromRGB(255, 248, 238), Sat = 0.08, Contrast = 0.08, Atmos = Color3.fromRGB(199, 214, 222), Haze = 1.6, Density = 0.32 },
	-- nights stay readable: bright ambient, cool tint, light haze (dark scenes are hard on phones)
	Night = { ClockFrom = 19, ClockTo = 29, Ambient = Color3.fromRGB(96, 110, 150), Bright = 1.4, Tint = Color3.fromRGB(205, 220, 255), Sat = -0.05, Contrast = 0.1, Atmos = Color3.fromRGB(80, 98, 140), Haze = 1, Density = 0.3 },
	Bloodmoon = { ClockFrom = 19, ClockTo = 29, Ambient = Color3.fromRGB(165, 92, 92), Bright = 1.6, Tint = Color3.fromRGB(255, 196, 186), Sat = 0.12, Contrast = 0.12, Atmos = Color3.fromRGB(150, 56, 52), Haze = 1.4, Density = 0.32 },
	GoldenHour = { ClockFrom = 16.2, ClockTo = 17.6, Ambient = Color3.fromRGB(140, 110, 70), Bright = 2.8, Tint = Color3.fromRGB(255, 222, 160), Sat = 0.2, Contrast = 0.1, Atmos = Color3.fromRGB(240, 196, 130), Haze = 2, Density = 0.3 },
}

-- ===================================================================== map
-- Hub at the origin, Hunting Grounds far along +X (StreamingEnabled keeps phones light).
-- Every player chops on their own floating island ("plot" internally) in a ring around the Village
-- island. Islands float over the void; falling off sends you home.
Config.Map = {
	PlotCount = 8,
	PlotRadius = 300, -- island centres from the Village centre
	IslandRadius = 38,
	HubRadius = 90,
	HubGate = Vector3.new(0, 0, -78),
	IslandGate = Vector3.new(0, 0, 78), -- the Village gate that takes you to your island
	HubSpawn = Vector3.new(0, 0, 20),
	FallY = -80,
	-- the Hunting Grounds camp (centre of the Wildlands): arrival point and the gate back
	GroundsEntry = Vector3.new(1250, 0, 20),
	GroundsGate = Vector3.new(1250, 0, -40),
	-- the top of every walkable ground part (Village, islands, Hunting Grounds)
	GroundY = 2,
	VillageRadius = 200, -- inside this (from the Village centre) is the Village: no axe in hand
}
-- gate portals: the travel ink wash sweeps in for this long before the server moves you
Config.GateCoverTime = 0.4

-- ===================================================================== the Wildlands (open world)
-- The Hunting Grounds are one round floating landmass (user, 2026-10-26: "an actual open world,
-- zones in any order"). A camp sits in the middle; six zones fan out around it as 60-degree
-- sectors, so you can walk into any of them. Grass trails between the sectors stay plain.
-- Positions inside a zone are polar: R = studs from the centre, A = degrees off the zone's Angle.
Config.Wild = {
	Center = Vector3.new(1250, 0, 0),
	Radius = 560,
	CampRadius = 95, -- the camp disc; no zone ground or mobs inside it
	Span = 60, -- degrees per zone
	ArenaR = 450, -- boss arenas sit this far out, on the zone's centre line
	ArenaRadius = 34,
	-- one Mythic beast at a time; each roll (every RollEvery s) spawns one with Chance
	Mythic = { RollEvery = 120, Chance = 0.035, Lifetime = 900 },
}

-- Zones of the Wildlands. Camps keep `Count` mobs alive and respawn them `Respawn` s after death;
-- NightCamps only refill at night. Elite: 5-minute spawn (day/night switch). Rare: each camp spawn
-- has Rare.Chance to be the zone's rare instead (server alert). Boss: always in its arena, back
-- Boss.Respawn s after it falls. Set: the zone's armour set (Config.ArmorSets).
Config.Zones = {
	{
		Id = "WillowFields", Name = "Willow Fields", MinLevel = 1, MaxLevel = 10, Angle = 180, Look = "Willow",
		Elite = "TuskBoar", Rare = { Mob = "MoonhornStag", Chance = 0.006 }, Boss = { Mob = "GuardianOx", Respawn = 480 }, Set = "Willowguard",
		Camps = {
			{ Mob = "Boar", R = 170, A = -12, Count = 4, Respawn = 15 },
			{ Mob = "Wolf", R = 250, A = 14, Count = 4, Respawn = 15 },
			{ Mob = "Boar", R = 330, A = -8, Count = 3, Respawn = 15 },
		},
		NightCamps = { { Mob = "NightWolf", R = 280, A = -16, Count = 3, Respawn = 20 } },
	},
	{
		Id = "BambooThicket", Name = "Bamboo Thicket", MinLevel = 10, MaxLevel = 20, Angle = 240, Look = "Bamboo",
		Elite = "MonkeyChief", Rare = { Mob = "JadePanda", Chance = 0.006 }, Boss = { Mob = "BambooTyrant", Respawn = 480 }, Set = "JadeBamboo",
		Camps = {
			{ Mob = "BambooViper", R = 170, A = 10, Count = 4, Respawn = 16 },
			{ Mob = "StoneMonkey", R = 260, A = -14, Count = 4, Respawn = 16 },
			{ Mob = "BambooViper", R = 340, A = 12, Count = 3, Respawn = 16 },
		},
		NightCamps = { { Mob = "MoonViper", R = 290, A = 4, Count = 3, Respawn = 20 } },
	},
	{
		Id = "MossyRuins", Name = "Mossy Ruins", MinLevel = 20, MaxLevel = 30, Angle = 300, Look = "Ruins",
		Elite = "BanditCaptain", Rare = { Mob = "RelicGolem", Chance = 0.006 }, Boss = { Mob = "BanditWarlord", Respawn = 480 }, Set = "Ruinbreaker",
		Camps = {
			{ Mob = "Bandit", R = 170, A = -10, Count = 4, Respawn = 18 },
			{ Mob = "MossGolem", R = 260, A = 14, Count = 3, Respawn = 22 },
			{ Mob = "Bandit", R = 340, A = -14, Count = 4, Respawn = 18 },
		},
		NightCamps = { { Mob = "Wraith", R = 300, A = 6, Count = 3, Respawn = 22 } },
	},
	{
		Id = "MistyMarsh", Name = "Misty Marsh", MinLevel = 30, MaxLevel = 40, Angle = 0, Look = "Marsh",
		Elite = "BogTroll", Rare = { Mob = "PearlCrane", Chance = 0.006 }, Boss = { Mob = "MireSerpent", Respawn = 480 }, Set = "Mistwalker",
		Camps = {
			{ Mob = "BogToad", R = 170, A = 12, Count = 4, Respawn = 18 },
			{ Mob = "MarshCroc", R = 260, A = -12, Count = 3, Respawn = 20 },
			{ Mob = "BogToad", R = 340, A = 10, Count = 4, Respawn = 18 },
		},
		NightCamps = { { Mob = "MarshWisp", R = 300, A = -4, Count = 3, Respawn = 22 } },
	},
	{
		Id = "AshenGorge", Name = "Ashen Gorge", MinLevel = 40, MaxLevel = 50, Angle = 60, Look = "Ashen",
		Elite = "BoneKnight", Rare = { Mob = "EmberWraith", Chance = 0.006 }, Boss = { Mob = "BoneKnightLord", Respawn = 480 }, Set = "AshenBone",
		Camps = {
			{ Mob = "Skeleton", R = 170, A = -12, Count = 4, Respawn = 20 },
			{ Mob = "AshHound", R = 260, A = 12, Count = 4, Respawn = 20 },
			{ Mob = "Skeleton", R = 340, A = -10, Count = 4, Respawn = 20 },
		},
		NightCamps = { { Mob = "CinderWraith", R = 300, A = 8, Count = 3, Respawn = 22 } },
	},
	{
		Id = "FrostPeak", Name = "Frost Peak", MinLevel = 50, MaxLevel = 60, Angle = 120, Look = "Frost",
		Elite = "GlacierBear", Rare = { Mob = "WhiteTiger", Chance = 0.006 }, Boss = { Mob = "GlacierApe", Respawn = 480 }, Set = "Glacier",
		Camps = {
			{ Mob = "SnowLeopard", R = 170, A = 10, Count = 4, Respawn = 20 },
			{ Mob = "FrostYeti", R = 260, A = -12, Count = 3, Respawn = 22 },
			{ Mob = "SnowLeopard", R = 340, A = 12, Count = 4, Respawn = 20 },
		},
		NightCamps = { { Mob = "IceWisp", R = 300, A = -6, Count = 3, Respawn = 22 } },
	},
}

-- ===================================================================== mobs
-- Level-scaled stats: HP = HP * HPGrowth^Level, Damage = Dmg * DmgGrowth^Level, Exp = Exp * ExpGrowth^Level.
-- (Softened when the Wildlands went to level 60: 1.13^60 made the last zone unbeatable.)
Config.MobScaling = { HPGrowth = 1.105, DmgGrowth = 1.085, ExpGrowth = 1.09, ScrapGrowth = 1.08 }
-- Communal scaling: players within Radius when a mob spawns (re-checked for elites/bosses every 5 s).
-- Everyone who dealt at least MinShare of its HP gets their own full drop rolls.
-- PvP (user, 2026-10-27): a Settings toggle (also the HUD's PvP pill), off by default (not saved:
-- off on every join). Only in the Hunting Grounds, only between players who both have it on.
-- Turning it off takes OffDelay s and is refused within CombatLock s of a PvP hit. Hits deal
-- DamageMult x a normal hit (no one-shots). On a PvP death the player who dealt the most PvP damage
-- in the last KillWindow s takes PeachShare of the loser's Peaches (at least 1, at most PeachMax).
Config.PvP = { DamageMult = 0.3, OffDelay = 10, CombatLock = 10, KillWindow = 20, PeachShare = 0.02, PeachMax = 2500 }
Config.Communal = { Radius = 90, Normal = 0.5, Elite = 0.85, Boss = 1.0, MinShare = 0.03, Recheck = 5 }
Config.MobAI = {
	AggroRange = 38,
	LeashRange = 70,
	Tick = 0.2,
	WindupTelegraph = true,
	CorpseTime = 2.5,
	Engage = 0.8, -- s after a mob aggroes before its first attack (its ring fades in first)
	Recover = 0.35, -- s a mob stays committed after an attack lands
	TurnSpeed = 9, -- rad/s a mob turns to face its target (no snapping)
	LungeTime = 0.22, -- s a lunge / charge surges forward
	LungeChance = 0.3, -- per AI tick, while chasing in lunge range with the attack ready
	BossBarRange = 90, -- studs: bosses and Mythic beasts show their health bar when you're this close
}
-- Mob attacks, Deepwoken / Rune Slayer style: a wind-up with a glint (red = heavy), then the strike.
-- MobService picks one per attack by Weight. Windup = s before the hit, Range = x the mob's reach,
-- Dmg = x its damage, Arc = half-angle (degrees) of the hit cone in front (180 = all round),
-- Lunge = studs it surges forward as it strikes (also used to close the gap), Shockwave = hits
-- everyone in range with a ground shockwave. Anim = the rig's attack pose (Creatures.attack).
-- Sets: Beast (wolves), Horned (boar, deer, ox), HornedBoss, Generic, GenericBoss (placeholders).
Config.MobAttacks = {
	Beast = {
		{ Name = "Bite", Anim = "Bite", Weight = 5, Windup = 0.45, Range = 1, Dmg = 1, Arc = 60 },
		{ Name = "Pounce", Anim = "Lunge", Weight = 3, Windup = 0.6, Range = 1.9, Dmg = 1.25, Arc = 40, Lunge = 9 },
		{ Name = "Claw", Anim = "Swipe", Weight = 3, Windup = 0.5, Range = 1.15, Dmg = 1.1, Arc = 100 },
	},
	Horned = {
		{ Name = "Gore", Anim = "Gore", Weight = 5, Windup = 0.5, Range = 1, Dmg = 1, Arc = 60 },
		{ Name = "Charge", Anim = "Lunge", Weight = 3, Windup = 0.75, Range = 2.2, Dmg = 1.35, Arc = 35, Lunge = 12, Heavy = true },
		{ Name = "Kick", Anim = "Rear", Weight = 2, Windup = 0.55, Range = 1.05, Dmg = 1.15, Arc = 180 },
	},
	HornedBoss = {
		{ Name = "Gore", Anim = "Gore", Weight = 5, Windup = 0.55, Range = 1, Dmg = 1, Arc = 70 },
		{ Name = "Charge", Anim = "Lunge", Weight = 3, Windup = 0.85, Range = 2.3, Dmg = 1.4, Arc = 35, Lunge = 16, Heavy = true },
		{ Name = "Stomp", Anim = "Rear", Weight = 2, Windup = 1.0, Range = 2.1, Dmg = 1.6, Arc = 180, Heavy = true, Shockwave = true },
	},
	Generic = {
		{ Name = "Strike", Anim = "Bite", Weight = 5, Windup = 0.45, Range = 1, Dmg = 1, Arc = 70 },
		{ Name = "Lunge", Anim = "Lunge", Weight = 3, Windup = 0.65, Range = 1.8, Dmg = 1.3, Arc = 40, Lunge = 8 },
		{ Name = "Sweep", Anim = "Swipe", Weight = 2, Windup = 0.55, Range = 1.15, Dmg = 1.1, Arc = 110 },
	},
	GenericBoss = {
		{ Name = "Strike", Anim = "Bite", Weight = 5, Windup = 0.5, Range = 1, Dmg = 1, Arc = 70 },
		{ Name = "Lunge", Anim = "Lunge", Weight = 3, Windup = 0.8, Range = 2, Dmg = 1.35, Arc = 40, Lunge = 12, Heavy = true },
		{ Name = "Slam", Anim = "Rear", Weight = 2, Windup = 1.0, Range = 2.1, Dmg = 1.6, Arc = 180, Heavy = true, Shockwave = true },
	},
}
-- Kind: Normal / Elite / Rare / Boss / Mythic / Event. Size is the placeholder body (studs).
-- Body: Quadruped / Biped / Floater / Bird / Serpent (Builders.Creature). Drops: chance-based tables
-- { chance, min, max }; Gear = { 1, n } gear rolls; Set = { chance } one piece of the zone's armour set.
-- Rare: a zone's rare spawn. Mythic: roams the whole Wildlands (Config.SuperRares), level = the zone
-- it appears in + 5.
-- Balance (2026-10-26, CHO/tools/dev/balance_sim.lua + balance_solve.lua): Ashen Gorge and Frost Peak
-- are solved against a player at the zone's level with the matching tree (level / 2): normals ~3.5 s to
-- kill one-on-one at first. Normals were then re-fit in Play against a whole camp, since all 4 aggro at
-- once (HP 1.4x, damage ~0.56x the solve): a matching player should clear a 4-pack at about half HP.
-- Elites ~30 / 55 s, rares ~45 / 75 s, bosses ~120 / 150 s at the zone's top level, Mythic beasts
-- ~240 / 180 s. Exp gives ~60 normal kills per level; Scraps, Sap and
-- Heartwood pay for a tree growth in about its growth time of hunting there.
Config.Mobs = {
	-- Willow Fields (1-10)
	Boar = { Name = "Boar", Kind = "Normal", Level = 2, HP = 60, Dmg = 6, Speed = 13, Range = 6, AttackTime = 1.6, Exp = 8, Scraps = 3, Size = Vector3.new(4, 3.2, 6), Color = Color3.fromRGB(110, 80, 60), Body = "Quadruped", Drops = { Sap = { 0.35, 1, 2 }, Peaches = { 0.15, 1, 3 } } },
	Wolf = { Name = "Grey Wolf", Kind = "Normal", Level = 4, HP = 55, Dmg = 8, Speed = 17, Range = 6, AttackTime = 1.3, Exp = 10, Scraps = 4, Size = Vector3.new(3, 3.4, 6.5), Color = Color3.fromRGB(120, 120, 125), Body = "Quadruped", Drops = { Sap = { 0.35, 1, 2 }, Peaches = { 0.15, 1, 3 } } },
	NightWolf = { Name = "Night Wolf", Kind = "Normal", Level = 7, HP = 70, Dmg = 10, Speed = 18, Range = 6, AttackTime = 1.2, Exp = 16, Scraps = 6, Size = Vector3.new(3.2, 3.6, 7), Color = Color3.fromRGB(40, 45, 70), Body = "Quadruped", Drops = { Sap = { 0.5, 1, 3 }, Peaches = { 0.2, 1, 3 } } },
	TuskBoar = { Name = "Tusk Boar", Kind = "Elite", Level = 9, HP = 900, Dmg = 18, Speed = 14, Range = 9, AttackTime = 2.2, Exp = 160, Scraps = 60, Size = Vector3.new(7, 6, 11), Color = Color3.fromRGB(90, 60, 45), Body = "Quadruped", Drops = { Heartwood = { 1, 1, 3 }, Sap = { 1, 6, 12 }, Peaches = { 1, 10, 18 }, MountShards = { 0.6, 2, 4 }, Gear = { 1, 1, 1 } } },
	MoonhornStag = { Name = "Moonhorn Stag", Kind = "Rare", Level = 10, HP = 1400, Dmg = 16, Speed = 19, Range = 8, AttackTime = 1.8, Exp = 320, Scraps = 140, Size = Vector3.new(4, 7, 9), Color = Color3.fromRGB(225, 230, 240), Body = "Quadruped", Drops = { Heartwood = { 1, 2, 5 }, Spirit = { 1, 10, 20 }, Peaches = { 1, 12, 20 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 }, Set = { 0.5 } } },
	-- Willow Fields boss (replaces the Tusk King): a huge plain ox; Size.Z 13.4 nose to tail puts the hump
	-- at ~10.4 studs, about 2x a player
	GuardianOx = { Name = "Guardian Ox", Kind = "Boss", Level = 12, HP = 6000, Dmg = 24, Speed = 13, Range = 13, AttackTime = 2.6, Exp = 900, Scraps = 600, Size = Vector3.new(10.5, 10.4, 13.4), Color = Color3.fromRGB(176, 160, 136), Body = "Quadruped", Drops = { Heartwood = { 1, 3, 7 }, Spirit = { 1, 25, 50 }, Peaches = { 1, 25, 40 }, MountShards = { 1, 5, 10 }, Gear = { 1, 1, 1 }, Set = { 1 } } },
	-- Bamboo Thicket (10-20)
	BambooViper = { Name = "Bamboo Viper", Kind = "Normal", Level = 12, HP = 55, Dmg = 9, Speed = 15, Range = 7, AttackTime = 1.3, Exp = 11, Scraps = 5, Size = Vector3.new(2.2, 1.8, 9), Color = Color3.fromRGB(96, 160, 70), Body = "Serpent", Drops = { Sap = { 0.4, 1, 3 }, Peaches = { 0.15, 1, 3 } } },
	StoneMonkey = { Name = "Stone Monkey", Kind = "Normal", Level = 15, HP = 75, Dmg = 10, Speed = 17, Range = 6, AttackTime = 1.2, Exp = 13, Scraps = 5, Size = Vector3.new(2.6, 4.4, 2), Color = Color3.fromRGB(130, 126, 116), Body = "Biped", Drops = { Sap = { 0.4, 1, 3 }, Peaches = { 0.15, 1, 3 } } },
	MoonViper = { Name = "Moon Viper", Kind = "Normal", Level = 17, HP = 70, Dmg = 12, Speed = 16, Range = 7, AttackTime = 1.3, Exp = 16, Scraps = 6, Size = Vector3.new(2.4, 1.9, 10), Color = Color3.fromRGB(60, 70, 130), Body = "Serpent", Drops = { Sap = { 0.4, 1, 3 }, Peaches = { 0.15, 1, 3 } } },
	MonkeyChief = { Name = "Monkey Chief", Kind = "Elite", Level = 18, HP = 900, Dmg = 18, Speed = 15, Range = 9, AttackTime = 2.0, Exp = 160, Scraps = 60, Size = Vector3.new(4, 8, 3), Color = Color3.fromRGB(150, 120, 90), Body = "Biped", Drops = { Heartwood = { 1, 1, 3 }, Sap = { 1, 6, 12 }, Peaches = { 1, 10, 18 }, MountShards = { 0.6, 2, 4 }, Gear = { 1, 1, 1 } } },
	JadePanda = { Name = "Jade Panda", Kind = "Rare", Level = 19, HP = 1400, Dmg = 18, Speed = 13, Range = 9, AttackTime = 2.0, Exp = 320, Scraps = 140, Size = Vector3.new(6, 6, 8), Color = Color3.fromRGB(210, 240, 220), Body = "Quadruped", Drops = { Heartwood = { 1, 2, 5 }, Spirit = { 1, 10, 20 }, Peaches = { 1, 12, 20 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 }, Set = { 0.5 } } },
	BambooTyrant = { Name = "Bamboo Tyrant", Kind = "Boss", Level = 21, HP = 6500, Dmg = 24, Speed = 12, Range = 13, AttackTime = 2.6, Exp = 900, Scraps = 600, Size = Vector3.new(12, 11, 15), Color = Color3.fromRGB(40, 44, 40), Body = "Quadruped", Drops = { Heartwood = { 1, 3, 7 }, Spirit = { 1, 25, 50 }, Peaches = { 1, 25, 40 }, MountShards = { 1, 5, 10 }, Gear = { 1, 1, 1 }, Set = { 1 } } },
	-- Mossy Ruins (20-30)
	Bandit = { Name = "Bandit", Kind = "Normal", Level = 21, HP = 70, Dmg = 9, Speed = 15, Range = 7, AttackTime = 1.4, Exp = 12, Scraps = 5, Size = Vector3.new(2.6, 5.6, 1.6), Color = Color3.fromRGB(120, 90, 70), Body = "Biped", Drops = { Sap = { 0.4, 1, 3 }, Peaches = { 0.15, 1, 3 } } },
	MossGolem = { Name = "Moss Golem", Kind = "Normal", Level = 24, HP = 120, Dmg = 12, Speed = 10, Range = 8, AttackTime = 2.0, Exp = 18, Scraps = 8, Size = Vector3.new(5, 7, 4), Color = Color3.fromRGB(90, 110, 80), Body = "Biped", Drops = { Sap = { 0.5, 2, 3 }, Heartwood = { 0.04, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	Wraith = { Name = "Wraith", Kind = "Normal", Level = 26, HP = 60, Dmg = 13, Speed = 16, Range = 8, AttackTime = 1.6, Exp = 17, Scraps = 7, Size = Vector3.new(2.8, 6, 1.6), Color = Color3.fromRGB(90, 110, 140), Body = "Floater", Drops = { Sap = { 0.5, 1, 3 }, Peaches = { 0.2, 1, 3 } } },
	BanditCaptain = { Name = "Bandit Captain", Kind = "Elite", Level = 28, HP = 900, Dmg = 18, Speed = 15, Range = 9, AttackTime = 2.0, Exp = 160, Scraps = 60, Size = Vector3.new(4, 8, 2.4), Color = Color3.fromRGB(140, 60, 50), Body = "Biped", Drops = { Heartwood = { 1, 2, 4 }, Sap = { 1, 6, 12 }, Peaches = { 1, 10, 18 }, MountShards = { 0.6, 2, 4 }, Gear = { 1, 1, 1 } } },
	RelicGolem = { Name = "Relic Golem", Kind = "Rare", Level = 29, HP = 1500, Dmg = 18, Speed = 10, Range = 10, AttackTime = 2.2, Exp = 320, Scraps = 140, Size = Vector3.new(7, 10, 5), Color = Color3.fromRGB(200, 170, 90), Body = "Biped", Drops = { Heartwood = { 1, 3, 6 }, Spirit = { 1, 10, 20 }, Peaches = { 1, 12, 20 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 }, Set = { 0.5 } } },
	BanditWarlord = { Name = "Bandit Warlord", Kind = "Boss", Level = 31, HP = 7000, Dmg = 24, Speed = 14, Range = 13, AttackTime = 2.4, Exp = 900, Scraps = 600, Size = Vector3.new(6, 12, 3.6), Color = Color3.fromRGB(110, 30, 30), Body = "Biped", Drops = { Heartwood = { 1, 4, 8 }, Spirit = { 1, 25, 50 }, Peaches = { 1, 25, 40 }, MountShards = { 1, 5, 10 }, Gear = { 1, 1, 1 }, Set = { 1 }, SpiritSteel = { 1, 1, 3 } } },
	-- Misty Marsh (30-40)
	BogToad = { Name = "Bog Toad", Kind = "Normal", Level = 31, HP = 80, Dmg = 11, Speed = 12, Range = 7, AttackTime = 1.6, Exp = 14, Scraps = 6, Size = Vector3.new(4, 3, 4.5), Color = Color3.fromRGB(100, 120, 70), Body = "Quadruped", Drops = { Sap = { 0.5, 2, 3 }, Heartwood = { 0.04, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	MarshCroc = { Name = "Marsh Croc", Kind = "Normal", Level = 35, HP = 110, Dmg = 13, Speed = 13, Range = 8, AttackTime = 1.8, Exp = 18, Scraps = 8, Size = Vector3.new(3.6, 2.2, 10), Color = Color3.fromRGB(70, 90, 60), Body = "Quadruped", Drops = { Sap = { 0.5, 2, 3 }, Heartwood = { 0.04, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	MarshWisp = { Aura = "MarshWisp", Name = "Marsh Wisp", Kind = "Normal", Level = 37, HP = 60, Dmg = 14, Speed = 17, Range = 8, AttackTime = 1.5, Exp = 18, Scraps = 7, Size = Vector3.new(2.4, 4.4, 2.4), Color = Color3.fromRGB(120, 220, 200), Body = "Floater", Drops = { Sap = { 0.5, 2, 3 }, Heartwood = { 0.04, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	BogTroll = { Name = "Bog Troll", Kind = "Elite", Level = 38, HP = 950, Dmg = 19, Speed = 12, Range = 10, AttackTime = 2.2, Exp = 170, Scraps = 65, Size = Vector3.new(6, 10, 4), Color = Color3.fromRGB(80, 100, 70), Body = "Biped", Drops = { Heartwood = { 1, 2, 4 }, Sap = { 1, 6, 12 }, Peaches = { 1, 10, 18 }, MountShards = { 0.6, 2, 4 }, Gear = { 1, 1, 1 } } },
	PearlCrane = { Name = "Pearl Crane", Kind = "Rare", Level = 39, HP = 1500, Dmg = 18, Speed = 20, Range = 9, AttackTime = 1.8, Exp = 330, Scraps = 150, Size = Vector3.new(5, 7, 6), Color = Color3.fromRGB(245, 245, 240), Body = "Bird", Drops = { Heartwood = { 1, 3, 6 }, Spirit = { 1, 10, 20 }, Peaches = { 1, 12, 20 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 }, Set = { 0.5 } } },
	MireSerpent = { Name = "Mire Serpent", Kind = "Boss", Level = 42, HP = 7500, Dmg = 25, Speed = 12, Range = 14, AttackTime = 2.6, Exp = 950, Scraps = 650, Size = Vector3.new(7, 6, 40), Color = Color3.fromRGB(60, 80, 60), Body = "Serpent", Drops = { Heartwood = { 1, 4, 8 }, Spirit = { 1, 25, 50 }, Peaches = { 1, 25, 40 }, MountShards = { 1, 5, 10 }, Gear = { 1, 1, 1 }, Set = { 1 }, SpiritSteel = { 1, 2, 4 } } },
	-- Ashen Gorge (40-50)
	Skeleton = { Name = "Skeleton", Kind = "Normal", Level = 41, HP = 690, Dmg = 70, Speed = 14, Range = 7, AttackTime = 1.5, Exp = 5, Scraps = 12, Size = Vector3.new(2.4, 5.8, 1.4), Color = Color3.fromRGB(225, 220, 200), Body = "Biped", Drops = { Sap = { 0.8, 2, 5 }, Heartwood = { 0.02, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	AshHound = { Name = "Ash Hound", Kind = "Normal", Level = 44, HP = 405, Dmg = 42, Speed = 18, Range = 7, AttackTime = 1.3, Exp = 3.5, Scraps = 11, Size = Vector3.new(3, 3.6, 7), Color = Color3.fromRGB(60, 54, 52), Body = "Quadruped", Drops = { Sap = { 0.8, 2, 5 }, Heartwood = { 0.02, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	CinderWraith = { Aura = "CinderWraith", Name = "Cinder Wraith", Kind = "Normal", Level = 47, HP = 280, Dmg = 48, Speed = 16, Range = 8, AttackTime = 1.5, Exp = 3.5, Scraps = 11, Size = Vector3.new(2.8, 6, 1.6), Color = Color3.fromRGB(230, 120, 50), Body = "Floater", Drops = { Sap = { 0.8, 2, 5 }, Heartwood = { 0.02, 1, 1 }, Peaches = { 0.2, 1, 3 } } },
	BoneKnight = { Name = "Bone Knight", Kind = "Elite", Level = 48, HP = 2100, Dmg = 110, Speed = 14, Range = 10, AttackTime = 2.2, Exp = 40, Scraps = 170, Size = Vector3.new(4.4, 9, 2.6), Color = Color3.fromRGB(210, 205, 185), Body = "Biped", Drops = { Heartwood = { 1, 3, 5 }, Sap = { 1, 6, 12 }, Peaches = { 1, 12, 20 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 } } },
	EmberWraith = { Aura = "EmberWraith", Name = "Ember Wraith", Kind = "Rare", Level = 49, HP = 2800, Dmg = 75, Speed = 17, Range = 10, AttackTime = 1.8, Exp = 60, Scraps = 250, Size = Vector3.new(4, 9, 2.4), Color = Color3.fromRGB(255, 110, 40), Body = "Floater", Drops = { Heartwood = { 1, 4, 7 }, Spirit = { 1, 10, 20 }, Peaches = { 1, 12, 20 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 }, Set = { 0.5 } } },
	BoneKnightLord = { Name = "Bone Knight Lord", Kind = "Boss", Level = 52, HP = 7600, Dmg = 135, Speed = 13, Range = 14, AttackTime = 2.4, Exp = 130, Scraps = 700, Size = Vector3.new(7, 15, 4), Color = Color3.fromRGB(180, 170, 150), Body = "Biped", Drops = { Heartwood = { 1, 5, 9 }, Spirit = { 1, 25, 50 }, Peaches = { 1, 25, 40 }, MountShards = { 1, 5, 10 }, Gear = { 1, 1, 1 }, Set = { 1 }, SpiritSteel = { 1, 3, 5 } } },
	-- Frost Peak (50-60)
	SnowLeopard = { Name = "Snow Leopard", Kind = "Normal", Level = 51, HP = 300, Dmg = 40, Speed = 19, Range = 7, AttackTime = 1.2, Exp = 2.5, Scraps = 29, Size = Vector3.new(2.8, 3.4, 7), Color = Color3.fromRGB(235, 235, 240), Body = "Quadruped", Drops = { Sap = { 0.9, 7, 14 }, Heartwood = { 0.03, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	FrostYeti = { Name = "Frost Yeti", Kind = "Normal", Level = 55, HP = 335, Dmg = 53, Speed = 12, Range = 8, AttackTime = 1.9, Exp = 3, Scraps = 31, Size = Vector3.new(5, 8, 3.6), Color = Color3.fromRGB(220, 230, 240), Body = "Biped", Drops = { Sap = { 0.9, 7, 14 }, Heartwood = { 0.03, 1, 1 }, Peaches = { 0.15, 1, 3 } } },
	IceWisp = { Aura = "IceWisp", Name = "Ice Wisp", Kind = "Normal", Level = 57, HP = 147, Dmg = 32, Speed = 17, Range = 8, AttackTime = 1.5, Exp = 1.75, Scraps = 26, Size = Vector3.new(2.4, 4.4, 2.4), Color = Color3.fromRGB(150, 210, 255), Body = "Floater", Drops = { Sap = { 0.9, 7, 14 }, Heartwood = { 0.03, 1, 1 }, Peaches = { 0.2, 1, 3 } } },
	GlacierBear = { Name = "Glacier Bear", Kind = "Elite", Level = 58, HP = 1075, Dmg = 76, Speed = 13, Range = 10, AttackTime = 2.2, Exp = 20, Scraps = 480, Size = Vector3.new(7, 7, 11), Color = Color3.fromRGB(200, 220, 235), Body = "Quadruped", Drops = { Heartwood = { 1, 6, 10 }, Sap = { 1, 30, 50 }, Peaches = { 1, 14, 22 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 } } },
	WhiteTiger = { Name = "White Tiger", Kind = "Rare", Level = 59, HP = 1460, Dmg = 46, Speed = 20, Range = 10, AttackTime = 1.6, Exp = 30, Scraps = 600, Size = Vector3.new(4, 5, 10), Color = Color3.fromRGB(245, 245, 250), Body = "Quadruped", Drops = { Heartwood = { 1, 4, 7 }, Spirit = { 1, 10, 20 }, Peaches = { 1, 12, 20 }, MountShards = { 0.7, 2, 5 }, Gear = { 1, 1, 1 }, Set = { 0.5 } } },
	GlacierApe = { Name = "Glacier Ape", Kind = "Boss", Level = 62, HP = 4030, Dmg = 135, Speed = 12, Range = 15, AttackTime = 2.6, Exp = 60, Scraps = 700, Size = Vector3.new(12, 16, 7), Color = Color3.fromRGB(170, 200, 220), Body = "Biped", Drops = { Heartwood = { 1, 8, 14 }, Spirit = { 1, 25, 50 }, Peaches = { 1, 25, 40 }, MountShards = { 1, 5, 10 }, Gear = { 1, 1, 1 }, Set = { 1 }, SpiritSteel = { 1, 4, 6 } } },
	-- Mythic beasts: roam the whole Wildlands (Config.SuperRares); the only source of forge relics
	HeavenlyQilin = { Aura = "Qilin", Name = "Heavenly Qilin", Kind = "Mythic", Level = 0, HP = 144000, Dmg = 126, Speed = 18, Range = 12, AttackTime = 2.0, Exp = 1000, Scraps = 1600, Size = Vector3.new(6, 9, 13), Color = Color3.fromRGB(120, 220, 180), Body = "Quadruped", ZoneLevel = true, Growth = { HP = 1.055, Dmg = 1.077, Exp = 1.06, Scraps = 1.06 }, Drops = { QilinHorn = { 1, 1, 1 }, StarShard = { 1, 2, 4 }, Spirit = { 1, 60, 120 }, Peaches = { 1, 40, 60 }, MountShards = { 1, 10, 20 }, Gear = { 1, 2, 2 } } },
	NineTailedFox = { Aura = "NineTails", Name = "Nine-Tailed Fox", Kind = "Mythic", Level = 0, HP = 130000, Dmg = 101, Speed = 22, Range = 11, AttackTime = 1.6, Exp = 1000, Scraps = 1600, Size = Vector3.new(5, 6, 11), Color = Color3.fromRGB(255, 228, 228), Body = "Quadruped", ZoneLevel = true, Growth = { HP = 1.055, Dmg = 1.077, Exp = 1.06, Scraps = 1.06 }, Drops = { FoxTail = { 1, 1, 1 }, StarShard = { 1, 2, 4 }, Spirit = { 1, 60, 120 }, Peaches = { 1, 40, 60 }, MountShards = { 1, 10, 20 }, Gear = { 1, 2, 2 } } },
	ThunderRoc = { Aura = "ThunderRoc", Name = "Thunder Roc", Kind = "Mythic", Level = 0, HP = 150000, Dmg = 126, Speed = 20, Range = 13, AttackTime = 2.0, Exp = 1000, Scraps = 1600, Size = Vector3.new(10, 10, 12), Color = Color3.fromRGB(90, 130, 230), Body = "Bird", ZoneLevel = true, Growth = { HP = 1.055, Dmg = 1.077, Exp = 1.06, Scraps = 1.06 }, Drops = { RocFeather = { 1, 1, 1 }, StarShard = { 1, 2, 4 }, Spirit = { 1, 60, 120 }, Peaches = { 1, 40, 60 }, MountShards = { 1, 10, 20 }, Gear = { 1, 2, 2 } } },
	-- event mobs: level follows the zone they spawn in (ZoneLevel)
	BloodSkeleton = { Name = "Blood Skeleton", Kind = "Event", ZoneLevel = true, HP = 90, Dmg = 12, Speed = 16, Range = 7, AttackTime = 1.4, Exp = 40, Scraps = 20, Size = Vector3.new(2.6, 6, 1.5), Color = Color3.fromRGB(170, 40, 40), Body = "Biped", Drops = { BloodAmber = { 0.5, 1, 2 }, Peaches = { 0.4, 2, 5 }, Spirit = { 0.1, 5, 10 } } },
	GoldenStag = { Name = "Golden Stag", Kind = "Event", ZoneLevel = true, HP = 110, Dmg = 4, Speed = 20, Range = 6, AttackTime = 2.0, Exp = 30, Scraps = 80, Size = Vector3.new(3, 5, 7), Color = Color3.fromRGB(240, 196, 80), Body = "Quadruped", Passive = true, Drops = { Sunstone = { 0.5, 1, 2 }, Peaches = { 0.5, 3, 6 }, Spirit = { 0.1, 5, 10 } } },
	GodlySkeleton = { Name = "Godly Skeleton", Kind = "Boss", ZoneLevel = true, HP = 6000, Dmg = 26, Speed = 13, Range = 13, AttackTime = 2.6, Exp = 900, Scraps = 600, Size = Vector3.new(7, 16, 4), Color = Color3.fromRGB(200, 30, 30), Body = "Biped", Drops = { BloodAmber = { 1, 4, 8 }, Spirit = { 1, 30, 60 }, MountShards = { 1, 8, 15 }, Peaches = { 1, 30, 50 }, Gear = { 1, 2, 2 }, Mount = { 0.05, "ShadowWolf" } } },
	JadeTortoise = { Name = "Jade Tortoise", Kind = "Boss", ZoneLevel = true, HP = 7000, Dmg = 20, Speed = 8, Range = 14, AttackTime = 3.0, Exp = 900, Scraps = 900, Size = Vector3.new(14, 8, 18), Color = Color3.fromRGB(80, 170, 140), Body = "Quadruped", Drops = { Sunstone = { 1, 4, 8 }, Spirit = { 1, 30, 60 }, MountShards = { 1, 8, 15 }, Peaches = { 1, 30, 50 }, Gear = { 1, 2, 2 }, Mount = { 0.05, "JadeCloud" } } },
}
-- Elite/boss gear drops roll at the killer's tree weights shifted up by this many tiers
Config.EliteGearBonus = 1

-- ===================================================================== Mythic beasts (super rares)
-- Rarer than any zone rare, and they can turn up anywhere in the Wildlands (Config.Wild.Mythic).
-- Each drops its relic, the only way to forge a Mythforged weapon (Config.Forge.Myth).
Config.SuperRares = { "HeavenlyQilin", "NineTailedFox", "ThunderRoc" }

-- ===================================================================== mutations
-- A Normal mob can spawn mutated (one at a time). Chance per spawn; Event = only while that world
-- event runs (then Chance applies instead of never). HP/Dmg/Exp multiply its stats, Scale its size,
-- Drops are extra rolls on top of its own, Tint = body colour blend. Name prefix shows on its plate.
Config.Mutations = {
	SpiritTouched = { Name = "Spirit-Touched", Chance = 0.03, HP = 1.6, Dmg = 1.2, Exp = 2, Scale = 1.1,
		Tint = { Color3.fromRGB(110, 230, 190), 0.45 }, Glow = Color3.fromRGB(120, 255, 210), Drops = { Spirit = { 1, 5, 12 } } },
	Ancient = { Name = "Ancient", Chance = 0.02, HP = 2.5, Dmg = 1.4, Exp = 2.5, Scale = 1.45,
		Tint = { Color3.fromRGB(90, 120, 70), 0.4 }, Moss = true, Drops = { Heartwood = { 1, 1, 2 } } },
	BloodCorrupted = { Name = "Blood-Corrupted", Event = "Bloodmoon", Chance = 0.15, HP = 1.8, Dmg = 1.5, Exp = 2, Scale = 1.15,
		Tint = { Color3.fromRGB(150, 20, 24), 0.55 }, Glow = Color3.fromRGB(255, 50, 40), Drops = { BloodAmber = { 1, 1, 2 } } },
	Gilded = { Name = "Gilded", Event = "GoldenHour", Chance = 0.15, HP = 1.5, Dmg = 1.1, Exp = 2, Scale = 1.1, ScrapMult = 3,
		Tint = { Color3.fromRGB(255, 205, 80), 0.6 }, Glow = Color3.fromRGB(255, 220, 120), Drops = { Sunstone = { 1, 1, 2 } } },
}

-- ===================================================================== armour sets
-- Each zone's boss (always) and rare (Set chance) drop one piece of the zone's set at its fixed
-- Rarity (above the tree cap: it's the hunt's reward). Pieces get Mult x the normal main stats.
-- Bonus2 / Bonus4 apply with 2 / 4 pieces worn: ATK/HP/DEF/AGL are %, substats add.
Config.ArmorSets = {
	Willowguard = { Name = "Willowguard", Zone = "WillowFields", Rarity = 3, Mult = 1.15, Color = Color3.fromRGB(150, 200, 120),
		Bonus2 = { HP = 0.08 }, Bonus4 = { HP = 0.1, MoveSpeed = 0.05 } },
	JadeBamboo = { Name = "Jade Bamboo", Zone = "BambooThicket", Rarity = 3, Mult = 1.2, Color = Color3.fromRGB(110, 210, 150),
		Bonus2 = { AGL = 0.08 }, Bonus4 = { AttackSpeed = 0.1 } },
	Ruinbreaker = { Name = "Ruinbreaker", Zone = "MossyRuins", Rarity = 4, Mult = 1.15, Color = Color3.fromRGB(190, 170, 110),
		Bonus2 = { DEF = 0.08 }, Bonus4 = { ATK = 0.12 } },
	Mistwalker = { Name = "Mistwalker", Zone = "MistyMarsh", Rarity = 4, Mult = 1.2, Color = Color3.fromRGB(150, 210, 210),
		Bonus2 = { Lifesteal = 0.03 }, Bonus4 = { HP = 0.15, Lifesteal = 0.03 } },
	AshenBone = { Name = "Ashen Bone", Zone = "AshenGorge", Rarity = 5, Mult = 1.15, Color = Color3.fromRGB(230, 140, 80),
		Bonus2 = { ATK = 0.1 }, Bonus4 = { CritDamage = 0.25 } },
	Glacier = { Name = "Glacier", Zone = "FrostPeak", Rarity = 6, Mult = 1.15, Color = Color3.fromRGB(170, 220, 255),
		Bonus2 = { DEF = 0.12 }, Bonus4 = { ATK = 0.15, CritChance = 0.1 } },
}
Config.SetSlots = { "Helm", "Armor", "Boots", "Gloves" }

-- ===================================================================== forging (endgame)
-- Old Bao's forge in the Village. Dismantling a WEAPON also gives forge materials by its rarity.
-- Tiers forge a weapon of a chosen class at that rarity (max main-stat roll, +1 substat); a tier
-- unlocks when the tree can reach that rarity. Myth recipes need a Mythic beast's relic and make a
-- Divine weapon with its own effect: every Every-th hit deals Mult x ATK to everything within Radius
-- of the target (Heal = share of that damage healed).
Config.Forge = {
	Dismantle = {
		[1] = { IronShard = 1 }, [2] = { IronShard = 2 }, [3] = { IronShard = 4 },
		[4] = { SpiritSteel = 1 }, [5] = { SpiritSteel = 3 },
		[6] = { StarShard = 1 }, [7] = { StarShard = 3 },
	},
	Tiers = {
		{ Rarity = 3, Cost = { IronShard = 30, Scraps = 800 } },
		{ Rarity = 4, Cost = { IronShard = 60, SpiritSteel = 4, Scraps = 3000 } },
		{ Rarity = 5, Cost = { SpiritSteel = 20, Scraps = 10000 } },
		{ Rarity = 6, Cost = { SpiritSteel = 40, StarShard = 6, Scraps = 30000 } },
	},
	Myth = {
		QilinVerdict = { Name = "Qilin's Verdict", Class = "Greatsword", Cost = { QilinHorn = 3, StarShard = 15, SpiritSteel = 40, Scraps = 50000 },
			Mult = 1.25, Effect = { Name = "Heavenfire", Desc = "Every 5th hit calls down holy fire: 300% ATK to everything near your target.", Every = 5, Mult = 3, Radius = 12, Color = Color3.fromRGB(255, 220, 120) } },
		FoxfireFang = { Name = "Foxfire Fang", Class = "Spear", Cost = { FoxTail = 3, StarShard = 15, SpiritSteel = 40, Scraps = 50000 },
			Mult = 1.25, Effect = { Name = "Foxfire", Desc = "Every 3rd hit bursts into foxfire: 150% ATK nearby, and heals you for 10% of it.", Every = 3, Mult = 1.5, Radius = 8, Heal = 0.1, Color = Color3.fromRGB(255, 140, 200) } },
		Stormtalon = { Name = "Stormtalon", Class = "Sword", Cost = { RocFeather = 3, StarShard = 15, SpiritSteel = 40, Scraps = 50000 },
			Mult = 1.25, Effect = { Name = "Thunderclap", Desc = "Every 4th hit calls lightning: 200% ATK to everything in a wide ring.", Every = 4, Mult = 2, Radius = 16, Color = Color3.fromRGB(140, 190, 255) } },
	},
	MythOrder = { "QilinVerdict", "FoxfireFang", "Stormtalon" },
}
Config.PlayerRespawn = 4

-- ===================================================================== companions
-- Summoned with Spirit Stones. Duplicates add a star (max 5): +StarBonus of the buffs per star.
-- Skill: every Interval s deals Mult x owner ATK to the owner's current target. Look = a sculpt
-- (Creatures.Looks key) at Length studs nose to tail, else the placeholder. Aura = an Auras preset
-- (Legendary+ get one); Mythic mobs carry Aura too.
Config.Companions = {
	FoxSpirit = { Look = "SpiritFox", Length = 3, Name = "Fox Spirit", Rarity = 3, Buffs = { ATK = 0.04 }, Skill = { Interval = 4, Mult = 0.6 }, Color = Color3.fromRGB(240, 150, 90), Size = 2.2, Fly = false },
	MossTurtle = { Look = "SpiritTurtle", Length = 2.8, Name = "Moss Turtle", Rarity = 3, Buffs = { HP = 0.06, DEF = 0.04 }, Skill = { Interval = 5, Mult = 0.4 }, Color = Color3.fromRGB(110, 150, 90), Size = 2.4, Fly = false },
	JadeRabbit = { Look = "SpiritRabbit", Length = 2.2, Name = "Jade Rabbit", Rarity = 4, Buffs = { HP = 0.06, ATK = 0.05 }, Skill = { Interval = 4, Mult = 0.8 }, Color = Color3.fromRGB(190, 240, 210), Size = 2, Fly = false },
	ThunderHawk = { Look = "SpiritHawk", Length = 2.8, Name = "Thunder Hawk", Rarity = 4, Buffs = { ATK = 0.08, AGL = 0.05 }, Skill = { Interval = 3.5, Mult = 0.9 }, Color = Color3.fromRGB(90, 140, 220), Size = 2.4, Fly = true },
	FrostWolf = { Aura = "FrostWolf", Look = "FrostWolf", Length = 3.6, Name = "Frost Wolf", Rarity = 5, Buffs = { ATK = 0.12, HP = 0.08 }, Skill = { Interval = 3.5, Mult = 1.3 }, Color = Color3.fromRGB(200, 230, 255), Size = 3, Fly = false },
	NineTails = { Aura = "NineTails", Look = "NineTailedFox", Length = 3.4, Name = "Nine-Tailed Fox", Rarity = 5, Buffs = { ATK = 0.14, HP = 0.1, DEF = 0.1 }, Skill = { Interval = 3, Mult = 1.4 }, Color = Color3.fromRGB(255, 220, 220), Size = 3, Fly = false },
	Qilin = { Aura = "Qilin", Look = "HeavenlyQilin", Length = 4, Name = "Qilin", Rarity = 6, Buffs = { ATK = 0.2, HP = 0.2, DEF = 0.2 }, Skill = { Interval = 2.5, Mult = 2.0 }, Color = Color3.fromRGB(120, 220, 200), Size = 3.6, Fly = false },
	AzureDragon = { Aura = "AzureDragon", Look = "AzureDragon", Length = 9, Name = "Azure Dragon", Rarity = 7, Buffs = { ATK = 0.3, HP = 0.25, DEF = 0.25 }, Skill = { Interval = 2.5, Mult = 3.0 }, Color = Color3.fromRGB(70, 140, 255), Size = 4, Fly = true },
}
Config.CompanionStars = { Max = 5, StarBonus = 0.25 }
-- Summon odds by companion rarity (%), shown in the Summon tab
Config.SummonOdds = { [3] = 62, [4] = 28, [5] = 8.5, [6] = 1.3, [7] = 0.2 }
Config.SummonCost = { One = 100, Ten = 900 }
-- every 50th summon without a Legendary+ guarantees one
Config.SummonPity = 50

-- ===================================================================== mounts
-- Speed replaces WalkSpeed in the Hunting Grounds (hub stays at walk speed so plots feel calm).
-- Ground mounts with a Look are sculpted Creatures (Creatures.Looks), Length = nose to tail in
-- studs; the client walks and gallops them under the rider (Equipment)
Config.Mounts = {
	Horse = { Name = "Old Horse", Speed = 26, Unlock = { Level = 8 }, Color = Color3.fromRGB(140, 100, 70), Kind = "Ground", Look = "MountHorse", Length = 8.6 },
	JadeDeer = { Name = "Jade Deer", Speed = 30, Unlock = { Shards = 60 }, Color = Color3.fromRGB(150, 220, 180), Kind = "Ground", Look = "MountJadeDeer", Length = 8.4 },
	ShadowWolf = { Name = "Shadow Wolf", Speed = 34, Unlock = { Shards = 250 }, Color = Color3.fromRGB(40, 30, 60), Kind = "Ground", Look = "MountShadowWolf", Length = 8.4 },
	FlyingSword = { Name = "Flying Sword", Speed = 38, Unlock = { Shards = 600 }, Color = Color3.fromRGB(200, 230, 255), Kind = "Hover" },
	JadeCloud = { Name = "Jade Cloud", Speed = 40, Unlock = { Shards = 1000 }, Color = Color3.fromRGB(220, 255, 240), Kind = "Hover" },
	CelestialSteed = { Name = "Celestial Steed", Speed = 44, Unlock = { Pass = "CelestialSteed" }, Color = Color3.fromRGB(255, 236, 170), Kind = "Ground", Look = "MountCelestialSteed", Length = 9 },
}
Config.WalkSpeed = 18
-- Agility (user, 2026-10-27: it did nothing): the chance to dodge a mob's hit completely is
-- Cap * AGL / (AGL + PerLevel * the mob's level), so it's strong against weaker mobs and never
-- more than Cap (CombatService.hurt; "DODGE" shows like a dash dodge)
Config.Agility = { Cap = 0.3, PerLevel = 20 }
-- the dash tier for an Agility value (Config.Move.Dash.Tiers)
function Config.dashTier(agl)
	local best = Config.Move.Dash.Tiers[1]
	for _, t in ipairs(Config.Move.Dash.Tiers) do
		if (agl or 0) >= t.AGL then
			best = t
		end
	end
	return best
end
-- movement (client Movement; server StatsService for sprint, CombatService for the dash's i-frames)
Config.Move = {
	SprintMult = 1.45, -- Shift toggles sprint: walk speed x this (not while riding)
	-- Q dashes Speed studs/s for Time s; mob hits within IFrames s of the dash miss. Its style grows with
	-- Agility (the highest tier whose AGL you have; user, 2026-10-27): a plain dodge with dust, a
	-- quickstep with ink after-images, then a flashstep (you vanish into ink and reappear further on)
	Dash = { Speed = 80, Time = 0.2, Cooldown = 1.1, IFrames = 0.35,
		Tiers = {
			{ Name = "Dodge", AGL = 0, Speed = 62, Time = 0.2, IFrames = 0.3 }, -- ~12 studs
			{ Name = "Quickstep", AGL = 250, Speed = 80, Time = 0.2, IFrames = 0.35 }, -- ~16 studs
			{ Name = "Flashstep", AGL = 900, Speed = 140, Time = 0.16, IFrames = 0.45 }, -- ~22 studs
		},
	},
	-- Ctrl toggles the shoulder camera: Offset = camera offset (studs), Turn = how fast the body turns
	-- to the camera, Ease = how fast the offset and cursor ease in (both per second)
	ShiftLock = { Offset = Vector3.new(1.75, 0.35, 0), Turn = 16, Ease = 9 },
	-- directional walk (degrees): lean into the move, hips turn toward strafes, chest stays on target
	Lean = { Forward = 7, Side = 9, Sprint = 6, Hips = 50, Ease = 10 },
}
Config.MountSummonTime = 0.6

-- ===================================================================== dailies
Config.Daily = {
	-- streak day -> gift (day 7 repeats)
	Gifts = {
		{ Peaches = 60 },
		{ Peaches = 80, Scraps = 200 },
		{ Spirit = 50 },
		{ Peaches = 120 },
		{ Spirit = 80, MountShards = 10 },
		{ Peaches = 150, Sap = 20 },
		{ Spirit = 150, MountShards = 25 },
	},
}

-- ===================================================================== tutorial
-- Progression-based (Playbook 17): every step is a real step of the game, done for real, and pays a
-- reward. Steps are checked on the server from the save, in order; a step already done earlier
-- (out of order) completes the moment it comes up. {Tap} becomes Tap / Click / the gamepad glyph.
-- Counted steps (Chops, Kills) count from when the step starts. The last reward is the big one: a
-- guaranteed Epic-or-better weapon with the full beam moment. Target ~2 minutes in total.
Config.Tutorial = {
	{ Id = "Chop", Text = "{Tap} CHOP to chop your tree", Need = 5, Reward = { Scraps = 150 } },
	{ Id = "Grow", Text = "Grow your tree: {tap} Tree, then Grow", Need = 1, Reward = { Peaches = 60 } },
	{ Id = "Summon", Text = "Summon your first Spirit", Need = 1, Reward = { Scraps = 200 } },
	{ Id = "Hunt", Text = "Go to the Hunting Grounds", Need = 1, Reward = { Peaches = 40 } },
	{ Id = "Kill", Text = "Defeat 3 monsters", Need = 3, Reward = { Weapon = 4 } },
	-- hands over to the main quest line
	{ Id = "Elder", Text = "Talk to Elder Mo in the Village and accept his quest", Need = 1, Reward = { Spirit = 100, Peaches = 40 } },
}
-- players who clearly know the game already skip it (saves from before the tutorial existed)
Config.TutorialSkipIf = { TreeLevel = 4, Kills = 30 }

-- ===================================================================== village NPCs and quests
-- NPCs stand on the Village island (positions are ground points; y comes from Config.Map.GroundY)
-- and face the plaza. Talking opens their dialog: main quest, side quests, or their window (Opens).
-- Looks: HumanoidDescription colours until the art pass gives them real models
-- (ReplicatedStorage.MystreeAssets.Npc.<Id>).
Config.Npcs = {
	Elder = { Name = "Elder Mo", Title = "Village Elder", Pos = Vector3.new(-12, 0, -8), Skin = Color3.fromRGB(234, 200, 160), Top = Color3.fromRGB(90, 120, 110), Bottom = Color3.fromRGB(60, 70, 66),
		Greeting = "The tree has been restless since you came. Good. It needed someone." },
	Herbalist = { Name = "Lan", Title = "Herbalist", Pos = Vector3.new(-40, 0, 26), Skin = Color3.fromRGB(240, 210, 176), Top = Color3.fromRGB(120, 160, 110), Bottom = Color3.fromRGB(90, 110, 80),
		Greeting = "Mind the pots. Half of them bite." },
	Huntress = { Name = "Rui", Title = "Huntress", Pos = Vector3.new(-20, 0, -50), Skin = Color3.fromRGB(214, 170, 130), Top = Color3.fromRGB(130, 70, 50), Bottom = Color3.fromRGB(70, 50, 40),
		Greeting = "The fields are crawling. I could use another blade." },
	Smith = { Name = "Old Bao", Title = "Blacksmith", Pos = Vector3.new(42, 0, -26), Skin = Color3.fromRGB(200, 150, 110), Top = Color3.fromRGB(80, 70, 66), Bottom = Color3.fromRGB(50, 46, 44),
		Greeting = "Bring me scrap and I'll make it sing." },
	SpiritKeeper = { Name = "Sister Hua", Title = "Spirit Keeper", Opens = "Spirits", Pos = Vector3.new(-44, 0, -22), Skin = Color3.fromRGB(246, 222, 196), Top = Color3.fromRGB(200, 220, 236), Bottom = Color3.fromRGB(150, 170, 200),
		Greeting = "The spirits are curious about you. That's rare." },
	Merchant = { Name = "Fat Jin", Title = "Merchant", Opens = "Shop", Pos = Vector3.new(42, 0, 24), Skin = Color3.fromRGB(230, 190, 150), Top = Color3.fromRGB(170, 60, 50), Bottom = Color3.fromRGB(110, 40, 36),
		Greeting = "Peaches, stones, a little luck. Jin has it all, friend." },
	Stablehand = { Name = "Kai", Title = "Stable Hand", Opens = "Mounts", Pos = Vector3.new(20, 0, -52), Skin = Color3.fromRGB(190, 140, 100), Top = Color3.fromRGB(110, 90, 60), Bottom = Color3.fromRGB(70, 60, 44),
		Greeting = "Every mount here was wild once. Yours will be too." },
}
Config.NpcTalkRange = 14

-- Quest goals: { Type, Need, Mob?, Mat?, Rarity?, Slot? }. Types:
--   Chop, Kill (Mob = id, or any), Elite, Boss, TreeLevel, Level, Bring (Mat, taken on turn-in),
--   Summon, Companions (owned), Dismantle, Equipped (pieces worn), EquipRarity (Slot, Rarity), Visit (Grounds)
-- Counted goals (Chop, Kill, Elite, Boss, Summon, Dismantle) count from when the quest starts.
-- Rewards: any DataService.grant keys, Exp, and Gear = minimum rarity (capped at the tree's max).
Config.Quests = {
	MaxSide = 3, -- side quests held at once
	-- side quest Peaches (key Scraps) rewards grow with the tree: * (1 + SideScale * (TreeLevel - 1))
	SideScale = 0.15,
}

-- Chapter 1: The Withering Root. Started by the tutorial (talk to Elder Mo). Each step is turned in
-- by talking to its Npc; Story is what they say when giving it, Done when it's handed in.
Config.MainQuests = {
	{ Id = "M1", Title = "A Spark in the Bark", Npc = "Elder", Goal = { Type = "Chop", Need = 15 },
		Story = "So the Divine Tree woke for you. It hasn't stirred for anyone in forty years. Something is eating at its roots. Chop it. Every strike wakes it a little more.",
		Done = "Feel how warm the bark is now? It remembers.", Reward = { Peaches = 40, Scraps = 150 } },
	{ Id = "M2", Title = "Sap for the Roots", Npc = "Herbalist", Goal = { Type = "Kill", Need = 10 },
		Story = "Lan the herbalist knows roots better than I do. Boars and wolves in the Hunting Grounds carry sap in their blood. Bring her 8.",
		Done = "Fresh sap. I'll brew it into something the roots can drink.", Reward = { Peaches = 50, Scraps = 200 } },
	{ Id = "M3", Title = "Taller", Npc = "Elder", Goal = { Type = "TreeLevel", Need = 3 },
		Story = "The sap will hold for now. Grow your tree to Lv 3 so it can fight back.",
		Done = "Three rings of new growth. The rot is slowing.", Reward = { Peaches = 50, Spirit = 50 } },
	{ Id = "M4", Title = "The Tusk Boar", Npc = "Huntress", Goal = { Type = "Kill", Mob = "TuskBoar", Need = 1 },
		Story = "Rui says a great boar is tearing up Willow Fields. It shows up every time day turns to night. Help her bring it down.",
		Done = "That's the one that took my brother's net. Thank you. Here, take this.", Reward = { MountShards = 20, Gear = 3 } },
	{ Id = "M5", Title = "A Spirit Friend", Npc = "SpiritKeeper", Goal = { Type = "Companions", Need = 1 },
		Story = "Sister Hua tends the spirits that gather near the tree. One of them might walk with you.",
		Done = "It chose you. Be kind to it and it will fight for you.", Reward = { Spirit = 100, Peaches = 30 } },
	{ Id = "M6", Title = "Dressed for It", Npc = "Smith", Goal = { Type = "Equipped", Need = 6 },
		Story = "Old Bao won't let you near the Ruins in a shirt. Wear 6 pieces of gear and show him.",
		Done = "Ha! Now you look like you could take a punch.", Reward = { Scraps = 400, Peaches = 40 } },
	{ Id = "M7", Title = "Ready for the Ruins", Npc = "Huntress", Goal = { Type = "Level", Need = 15 },
		Story = "The rot started in the Mossy Ruins. Rui won't take you there until you reach Lv 15.",
		Done = "You've grown fast. The Ruins it is.", Reward = { Peaches = 60, MountShards = 15 } },
	{ Id = "M8", Title = "Bandit Trouble", Npc = "Huntress", Goal = { Type = "Kill", Mob = "Bandit", Need = 12 },
		Story = "Bandits are camped in the Mossy Ruins, digging for something under the old walls. Drive them off: 12 should do it.",
		Done = "They were digging toward the roots. Someone sent them.", Reward = { Peaches = 80, Gear = 4 } },
	{ Id = "M9", Title = "Heartwood", Npc = "Herbalist", Goal = { Type = "Elite", Need = 2 },
		Story = "Lan needs heartwood to seal the wound the bandits dug. Elites carry it. Bring 4.",
		Done = "This will hold the roots together. For a while.", Reward = { Peaches = 60, Spirit = 80 } },
	{ Id = "M10", Title = "Taller Than the Gate", Npc = "Elder", Goal = { Type = "TreeLevel", Need = 8 },
		Story = "A strong tree drives the rot out by itself. Grow it to Lv 8.",
		Done = "Look at it. I haven't seen it this green since I was a boy.", Reward = { Peaches = 80, Spirit = 100 } },
	{ Id = "M11", Title = "Red Moon", Npc = "Elder", Goal = { Type = "Kill", Mob = "BloodSkeleton", Need = 5 },
		Story = "On a Bloodmoon the dead walk out of the rot. Next time the moon turns red, put 5 Blood Skeletons back in the ground.",
		Done = "You've seen it now. The rot isn't sickness. Something is feeding on the tree.", Reward = { Peaches = 100, MountShards = 30 } },
	{ Id = "M12", Title = "The Bone Knight", Npc = "Huntress", Goal = { Type = "Kill", Mob = "BoneKnight", Need = 1 },
		Story = "Rui tracked the bandits' orders to the Ashen Gorge. A Bone Knight guards the way. Lv 35 at least.",
		Done = "It carried this seal. The same mark as the bandits.", Reward = { Peaches = 120, Gear = 5 } },
	{ Id = "M13", Title = "Godly Skeleton", Npc = "Elder", Goal = { Type = "Kill", Mob = "GodlySkeleton", Need = 1 },
		Story = "The seal belongs to the Godly Skeleton. It only rises under a Bloodmoon. Gather friends. End it.",
		Done = "It's over, for now. The roots are quiet. Rest, and grow the tree. Chapter 2 is coming.", Reward = { Peaches = 200, Spirit = 300, Gear = 6 } },
}

-- Side quests: each villager offers theirs; each can be done once per day (UTC). MinLevel hides
-- ones you're not ready for. Rewards scale with the tree (Config.Quests.SideScale).
Config.SideQuests = {
	BoarCull = { Npc = "Huntress", Title = "Boar Cull", Goal = { Type = "Kill", Mob = "Boar", Need = 8 }, Reward = { Peaches = 25, Scraps = 120 } },
	WolfPack = { Npc = "Huntress", Title = "Wolf Pack", Goal = { Type = "Kill", Mob = "Wolf", Need = 6 }, Reward = { Peaches = 25, Scraps = 150 } },
	NightHunt = { Npc = "Huntress", Title = "Night Hunt", MinLevel = 6, Goal = { Type = "Kill", Mob = "NightWolf", Need = 5 }, Reward = { Peaches = 35, Scraps = 200 } },
	BanditBounty = { Npc = "Huntress", Title = "Bandit Bounty", MinLevel = 15, Goal = { Type = "Kill", Mob = "Bandit", Need = 10 }, Reward = { Peaches = 50, Scraps = 400 } },
	EliteHunt = { Npc = "Huntress", Title = "Elite Hunt", MinLevel = 8, Goal = { Type = "Elite", Need = 1 }, Reward = { Peaches = 60, MountShards = 10 } },
	SapTea = { Npc = "Herbalist", Title = "Sap for Tea", Goal = { Type = "Kill", Need = 12 }, Reward = { Peaches = 30, Scraps = 100 } },
	HeartSalve = { Npc = "Herbalist", Title = "Heartwood Salve", MinLevel = 10, Goal = { Type = "Elite", Need = 1 }, Reward = { Peaches = 50, Spirit = 30 } },
	MoonHerb = { Npc = "Herbalist", Title = "Moon Herb", MinLevel = 10, Goal = { Type = "Kill", Need = 15 }, Reward = { Spirit = 60, Peaches = 30 } },
	ScrapRun = { Npc = "Smith", Title = "Peach Run", Goal = { Type = "Dismantle", Need = 15 }, Reward = { Scraps = 300, Peaches = 20 } },
	ShowYourBlade = { Npc = "Smith", Title = "Show Me Your Blade", Goal = { Type = "EquipRarity", Slot = "Weapon", Rarity = 3, Need = 1 }, Reward = { Scraps = 400, Peaches = 20 } },
	SpiritCall = { Npc = "SpiritKeeper", Title = "Answer a Call", Goal = { Type = "Summon", Need = 1 }, Reward = { Spirit = 50, Peaches = 30 } },
	RestlessDead = { Npc = "SpiritKeeper", Title = "Restless Dead", MinLevel = 22, Goal = { Type = "Kill", Mob = "Wraith", Need = 6 }, Reward = { Spirit = 60, Peaches = 40 } },
	Delivery = { Npc = "Merchant", Title = "Sap Delivery", Goal = { Type = "Kill", Need = 20 }, Reward = { Scraps = 500, Peaches = 25 } },
	ExerciseHorses = { Npc = "Stablehand", Title = "Stretch Their Legs", Goal = { Type = "Kill", Need = 20 }, Reward = { MountShards = 15, Peaches = 30 } },
}

-- ===================================================================== island customization
-- Decor (user, 2026-10-26): bought with Scraps (never Robux, Playbook 03), kept in a stash, placed
-- on your island. Positions are island-local (studs from the island centre; +Z points at the Village;
-- R = yaw in degrees). Radius = the footprint used for spacing and the clear zones.
-- Buff pieces: the strongest of each Kind counts, different kinds stack (Playbook 02).
--   PeachRegen = Peaches grow this much faster, Luck = added Drop Luck, ScrapBonus = more Scraps.
Config.Decor = {
	StoneLantern = { Name = "Stone Lantern", Price = 150, Radius = 2, Desc = "A lantern that glows at night." },
	PaperLantern = { Name = "Paper Lantern Post", Price = 120, Radius = 1.5, Desc = "Warm red light on a wooden post." },
	Bench = { Name = "Garden Bench", Price = 100, Radius = 2.5, Desc = "Somewhere to watch your tree." },
	FlowerBed = { Name = "Flower Bed", Price = 80, Radius = 2.5, Desc = "Spirit flowers in a stone border." },
	BambooCluster = { Name = "Bamboo Cluster", Price = 200, Radius = 2.5, Desc = "A tall stand of bamboo that sways." },
	RockGarden = { Name = "Rock Garden", Price = 250, Radius = 3.5, Desc = "Raked sand and three old stones." },
	BonsaiPine = { Name = "Bonsai Pine", Price = 400, Radius = 2, Desc = "A tiny pine, older than the village." },
	KoiPond = { Name = "Koi Pond", Price = 900, Radius = 5, Desc = "Still water and lazy koi." },
	WindChime = { Name = "Wind Chime", Price = 300, Radius = 1.5, Desc = "Rings softly in the wind." },
	ShrineGate = { Name = "Shrine Gate", Price = 1500, Radius = 5, Desc = "A red gate for the path to your tree." },
	IncenseBurner = { Name = "Incense Burner", Price = 2500, Radius = 2, MinTree = 3, Buff = { Kind = "Luck", Value = 0.03 },
		Desc = "Drop Luck +3% while it burns." },
	PeachAltar = { Name = "Peach Altar", Price = 3500, Radius = 2.5, MinTree = 4, Buff = { Kind = "ScrapBonus", Value = 0.05 },
		Desc = "+5% Peaches from everything (the Golden Toad's +10% replaces it)." },
	GoldenToad = { Name = "Golden Toad", Price = 6000, Radius = 2, MinTree = 6, Buff = { Kind = "ScrapBonus", Value = 0.1 },
		Desc = "+10% Peaches from everything." },
	SpiritCrystal = { Name = "Spirit Crystal", Price = 20000, Radius = 3, MinTree = 10, Buff = { Kind = "Luck", Value = 0.06 },
		Desc = "Drop Luck +6%. Hums near rare drops." },
}
-- the order cards show in
Config.DecorOrder = { "FlowerBed", "Bench", "PaperLantern", "StoneLantern", "BambooCluster", "RockGarden", "WindChime", "BonsaiPine",
	"KoiPond", "ShrineGate", "IncenseBurner", "PeachAltar", "GoldenToad", "SpiritCrystal" }
Config.Island = {
	MaxDecor = 30,
	-- placement must stay this far inside the island edge
	EdgeMargin = 3,
	-- areas kept clear (island-local x, z, radius): the tree, your spawn stand, the gate, the name
	-- board, the storage chest and the decor workbench
	-- (chest and workbench moved out to x = +-17, away from the tree, 2026-10-26)
	Clear = { { 0, -4, 9 }, { 0, 9, 3.5 }, { -12, 30, 7 }, { 10, 29, 5 }, { 17, 6, 2.5 }, { -17, 6, 3 } },
	Grid = 1, -- placement snaps to this many studs
	LikeCooldownDays = 1, -- one like per island per visitor per UTC day
}
-- Themes repaint the island (grass, earth, rock, tree leaves) and add drifting particles.
-- Unlock with tree level, Scraps or event materials (no Robux).
Config.Themes = {
	Meadow = { Name = "Spring Meadow", Unlock = {}, Grass = Color3.fromRGB(92, 132, 76), Earth = Color3.fromRGB(110, 84, 60), Rock = Color3.fromRGB(104, 100, 94),
		Slate = Color3.fromRGB(84, 86, 88), Leaf = nil, Fx = nil },
	Blossom = { Name = "Cherry Blossom", Unlock = { TreeLevel = 4 }, Grass = Color3.fromRGB(110, 150, 90), Earth = Color3.fromRGB(120, 88, 70), Rock = Color3.fromRGB(120, 112, 112),
		Slate = Color3.fromRGB(96, 92, 96), Leaf = Color3.fromRGB(246, 176, 200), Fx = { Color = Color3.fromRGB(255, 190, 210), Rate = 6, Fall = true } },
	Bamboo = { Name = "Bamboo Grove", Unlock = { Scraps = 3000 }, Grass = Color3.fromRGB(80, 140, 70), Earth = Color3.fromRGB(96, 80, 56), Rock = Color3.fromRGB(96, 104, 92),
		Slate = Color3.fromRGB(76, 84, 76), Leaf = Color3.fromRGB(110, 170, 90), Fx = { Color = Color3.fromRGB(170, 220, 120), Rate = 3, Fall = true } },
	Autumn = { Name = "Autumn Maple", Unlock = { TreeLevel = 8 }, Grass = Color3.fromRGB(150, 130, 70), Earth = Color3.fromRGB(116, 80, 52), Rock = Color3.fromRGB(110, 98, 86),
		Slate = Color3.fromRGB(90, 80, 74), Leaf = Color3.fromRGB(226, 110, 50), Fx = { Color = Color3.fromRGB(240, 130, 50), Rate = 6, Fall = true } },
	Frost = { Name = "Frost Peak", Unlock = { Scraps = 12000 }, Grass = Color3.fromRGB(220, 232, 240), Earth = Color3.fromRGB(150, 160, 176), Rock = Color3.fromRGB(150, 160, 172),
		Slate = Color3.fromRGB(120, 130, 146), Leaf = Color3.fromRGB(200, 230, 245), Fx = { Color = Color3.fromRGB(255, 255, 255), Rate = 10, Fall = true } },
	Moonlit = { Name = "Moonlit Garden", Unlock = { BloodAmber = 10 }, Grass = Color3.fromRGB(60, 80, 96), Earth = Color3.fromRGB(70, 66, 80), Rock = Color3.fromRGB(84, 88, 110),
		Slate = Color3.fromRGB(60, 62, 84), Leaf = Color3.fromRGB(120, 150, 220), Fx = { Color = Color3.fromRGB(170, 210, 255), Rate = 5, Fall = false, Glow = true } },
	Volcanic = { Name = "Ember Isle", Unlock = { TreeLevel = 15, Sunstone = 10 }, Grass = Color3.fromRGB(70, 60, 56), Earth = Color3.fromRGB(80, 50, 40), Rock = Color3.fromRGB(56, 48, 46),
		Slate = Color3.fromRGB(40, 34, 34), Leaf = Color3.fromRGB(230, 120, 60), Fx = { Color = Color3.fromRGB(255, 140, 60), Rate = 8, Fall = false, Glow = true } },
}
Config.ThemeOrder = { "Meadow", "Blossom", "Bamboo", "Autumn", "Frost", "Moonlit", "Volcanic" }

-- ===================================================================== leaderboards
-- Global top lists (OrderedDataStores), refreshed every RefreshEvery s and shown on the custom
-- leaderboard. In-server ranks come straight from player attributes.
Config.Leaderboards = {
	RefreshEvery = 90,
	Top = 25,
	Boards = {
		{ Id = "CP", Name = "Power", Store = "Mystree_TopCP" },
		{ Id = "Tree", Name = "Tree Level", Store = "Mystree_TopTree" },
		{ Id = "Likes", Name = "Island Likes", Store = "Mystree_TopLikes" },
	},
}

-- ===================================================================== monetization
-- Id = 0: not created yet. In Studio it grants for free; live it shows "not on sale".
Config.Gamepasses = {
	VIP = { Id = 0, Price = 299, Name = "VIP", Desc = "+20% Peaches and a gold VIP tag." },
	SwiftAuto = { Id = 0, Price = 199, Name = "Swift Auto", Desc = "Auto-chop swings twice as fast: as quick as clicking yourself." },
	BigBag = { Id = 0, Price = 149, Name = "Big Bag", Desc = "+150 bag slots." },
	TwinSpirits = { Id = 0, Price = 349, Name = "Twin Spirits", Desc = "Bring a second companion." },
	FortuneCharm = { Id = 0, Price = 399, Name = "Fortune Charm", Desc = "Epic-and-up drops are 1.5x as likely, forever." },
	CelestialSteed = { Id = 0, Price = 499, Name = "Celestial Steed", Desc = "The fastest mount in the game (speed 44), yours forever." },
}
Config.FortuneMult = 1.5
Config.VipScrapBonus = 0.2
Config.Products = {
	InstantGrowth = { Id = 0, Price = 49, Name = "Instant Growth", Desc = "Finish your tree's growth now." },
	PeachBasket = { Id = 0, Price = 49, Name = "Peach Basket", Grant = { Peaches = 60 } },
	PeachCrate = { Id = 0, Price = 129, Name = "Peach Crate", Grant = { Peaches = 200 } },
	PeachCart = { Id = 0, Price = 349, Name = "Peach Cart", Grant = { Peaches = 600 } },
	LuckyIncense = { Id = 0, Price = 99, Name = "Lucky Incense", Desc = "30 min of playtime: Epic+ drop odds x2.", Seconds = 1800 },
	CallBloodmoon = { Id = 0, Price = 249, Name = "Call Bloodmoon", Desc = "The next night is a Bloodmoon for the whole server." },
	-- one-time, offered after the tutorial with a 24 h countdown; sized to feel huge early but not skip the tree
	StarterPack = { Id = 0, Price = 99, Name = "Starter Pack", Desc = "8,400 Peaches, 500 Spirit Stones and a Rare+ weapon.", Grant = { Peaches = 300, Spirit = 500, MountShards = 60 }, Weapon = 3, OneTime = true, Hours = 24 },
	-- offered on the death screen in the Hunting Grounds
	Revive = { Id = 0, Price = 19, Name = "Revive Here", Desc = "Get back up where you fell, at full health." },
	-- offered on the quest board when today's side quests are done
	FreshOrders = { Id = 0, Price = 29, Name = "Fresh Orders", Desc = "Every villager has new side quests for you today." },
	-- Spirit Stone packs: bigger packs are better value; paid random (summons) is policy-checked
	Spirit1 = { Id = 0, Price = 49, Name = "Pouch of Spirit Stones", Grant = { Spirit = 100 }, PaidRandom = true },
	Spirit2 = { Id = 0, Price = 129, Name = "Bag of Spirit Stones", Grant = { Spirit = 280 }, PaidRandom = true },
	Spirit3 = { Id = 0, Price = 249, Name = "Box of Spirit Stones", Grant = { Spirit = 600 }, PaidRandom = true },
	Spirit4 = { Id = 0, Price = 499, Name = "Chest of Spirit Stones", Grant = { Spirit = 1300 }, PaidRandom = true },
	Spirit5 = { Id = 0, Price = 999, Name = "Vault of Spirit Stones", Grant = { Spirit = 2800 }, PaidRandom = true },
	Spirit6 = { Id = 0, Price = 1999, Name = "Hoard of Spirit Stones", Grant = { Spirit = 6000 }, PaidRandom = true, Best = true },
}

-- ===================================================================== anti-cheat
Config.AntiCheat = { Tolerance = 1.6, Strikes = 4, Grace = 3 }

-- ===================================================================== look and sound
Config.Particles = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds", -- real magic only (Divine, spirits)
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png", -- wood chips, embers
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}
-- Sound slots. `Ids` = takes picked at random, never the same one twice in a row. Calls that don't
-- pass a speed get a small random pitch (Config.SoundVary) so repeated sounds don't grate.
Config.Sounds = {
	Click = { Id = 17582213219, Volume = 0.25 },
	Pop = { Id = 109359226723492, Volume = 0.5 },
	Coin = { Id = 135483737426662, Volume = 0.45 },
	Error = { Id = 17779566040, Volume = 0.5, Speed = 0.55 },
	Bell = { Id = 111424747937311, Volume = 0.5 },
	Chop = { Id = 114743565978001, Volume = 0.7 },
	Whoosh = { Id = 122522591098602, Ids = { 122522591098602, 9120742716 }, Volume = 0.45 },
	Swing = { Id = 7171591581, Ids = { 7171591581, 4571259077, 9113305311 }, Volume = 0.5 }, -- Sword Swing, Swing, Bat Swing 3
	Hit = { Id = 86812684303392, Ids = { 86812684303392, 4678745096 }, Volume = 0.55, Speed = 1.1 }, -- Sword Hit, Knife Hit 1
	Crit = { Id = 9114855870, Ids = { 9114855870, 5326916842 }, Volume = 0.55 }, -- SpinHit
	Rare = { Id = 4612374393, Volume = 0.6 },
	Epic = { Id = 1839881844, Volume = 0.6 },
	Legendary = { Id = 72827145254925, Volume = 0.6 },
	Alert = { Id = 9125629454, Volume = 0.7 },
	Thunder = { Id = 168586621, Ids = { 168586621, 18650085033 }, Volume = 0.6 }, -- storm bolt impact, lightning strike close up
	Wind = { Id = 84535031431987, Volume = 0.35 },
	Growl = { Id = 9113971531, Volume = 0.6 },
	Quake = { Id = 9113220677, Volume = 0.6 },
	LevelUp = { Id = 9065783664, Volume = 0.5 }, -- power up sfx
	-- mob combat (SFX Library, public)
	MobSwing = { Id = 9120728815, Volume = 0.5 }, -- Whoosh Heavy Punches 1
	MobHit = { Id = 9117969687, Ids = { 9117969687, 8595980577, 8278630896 }, Volume = 0.6 }, -- Punch Kit Beefy Hit 2, hit_punch_l, Punch
	MobStomp = { Id = 74149238738530, Volume = 0.7 }, -- Ground Slam Impact Shockwave
	MobFall = { Id = 3626698892, Volume = 0.55 }, -- Thud Sound Effect
	Glint = { Id = 4678745096, Volume = 0.35, Speed = 1.6 }, -- Knife Hit 1, pitched up
}
Config.SoundVary = 0.04
-- Ambience: quiet looping beds under the music. Each place sets a volume per bed; beds not listed
-- fade to 0. Nights add `Night` to its bed everywhere except where the place says NoNight.
-- Places are Zone attribute values ("Village", "Camp", Config.Zones ids) plus "Island".
Config.Ambience = {
	Beds = {
		Wind = { Id = 9113286969 }, -- Barstow Wind Light Blustery
		Rain = { Id = 7127218501 }, -- Light Rain Loop
		Fire = { Id = 9082326368 }, -- Fire Loop
		Snow = { Id = 336392497 }, -- Snow Ambient
		Night = { Id = 179507208 }, -- Night Ambience
	},
	Places = {
		Village = { Wind = 0.07 },
		Island = { Wind = 0.2 },
		Camp = { Wind = 0.1 },
		WillowFields = { Wind = 0.12 },
		BambooThicket = { Wind = 0.12 },
		MossyRuins = { Wind = 0.16 },
		MistyMarsh = { Rain = 0.14, Wind = 0.06 },
		AshenGorge = { Fire = 0.1, Wind = 0.18, NoNight = true },
		FrostPeak = { Snow = 0.3, NoNight = true },
	},
	Night = 0.2,
	Fade = 2.5, -- seconds for a bed to reach its new volume
	StopAfter = 10, -- a bed silent this long stops playing
	Poll = 0.25,
	IslandRadius = 90, -- within this of a plot counts as "Island"
}
Config.Music = {
	{ Id = 1848354536, Name = "Relaxed Scene" },
	{ Id = 1837879082, Name = "Paradise Falls" },
}
Config.MusicVolume = 0.25
Config.MusicFade = 3

Config.DefaultSettings = {
	Music = true,
	Sfx = true,
	ScreenShake = true,
	Particles = true,
	Flashing = true,
	ShowArmor = true, -- your armour pieces drawn on your character for everyone (vanity; stats count either way)
	-- per piece (Profile): hide one armour piece's look while the rest stay shown
	HideHelm = false,
	HideArmor = false,
	HideGloves = false,
	HideBoots = false,
	HideBelt = false,
}


-- ===================================================================== derived (do not edit)
-- one gold: every cost, reward and drop that still names a retired resource pays Scraps instead
-- (Config.ScrapValue). A drop { chance, min, max } of one joins the mob's Scraps by its expected value.
local function scrapsOf(t)
	if not t then
		return
	end
	local add = 0
	for k, v in pairs(Config.ScrapValue) do
		if type(t[k]) == "number" then
			add += t[k] * v
			t[k] = nil
		end
	end
	if add > 0 then
		t.Scraps = (t.Scraps or 0) + math.floor(add + 0.5)
	end
end
Config.scrapsOf = scrapsOf
local function dropsOf(def)
	local drops = def.Drops
	if not drops then
		return
	end
	for k, v in pairs(Config.ScrapValue) do
		local d = drops[k]
		if type(d) == "table" then
			if def.Scraps then
				def.Scraps += math.floor(d[1] * (d[2] + d[3]) / 2 * v + 0.5)
			else
				drops.Scraps = { d[1], d[2] * v, d[3] * v }
			end
			drops[k] = nil
		end
	end
end
for _, def in pairs(Config.Mobs) do
	dropsOf(def)
end
for _, m in pairs(Config.Mutations) do
	dropsOf(m)
end
for _, t in pairs(Config.Forge.Dismantle) do
	scrapsOf(t)
end
for _, t in ipairs(Config.Forge.Tiers) do
	scrapsOf(t.Cost)
end
for _, m in pairs(Config.Forge.Myth) do
	scrapsOf(m.Cost)
end
for _, g in ipairs(Config.Daily.Gifts) do
	scrapsOf(g)
end
for _, q in ipairs(Config.MainQuests) do
	scrapsOf(q.Reward)
end
for _, step in ipairs(Config.Tutorial) do
	scrapsOf(step.Reward)
end
for _, q in pairs(Config.SideQuests) do
	scrapsOf(q.Reward)
end
for _, th in pairs(Config.Themes) do
	scrapsOf(th.Unlock)
end
for _, pr in pairs(Config.Products) do
	scrapsOf(pr.Grant)
end
for _, m in pairs(Config.Mounts) do
	if m.Unlock.Shards then
		m.Unlock.Scraps = m.Unlock.Shards * Config.ScrapValue.MountShards
		m.Unlock.Shards = nil
	end
end

-- Wildlands positions: Config.wildPos(zone, R, A) -> world point (Y = 0). Each zone also gets
-- Center (its middle, for event spawns), Arena (boss spot) and each camp a Pos.
function Config.wildPos(zone, r, a)
	local ang = math.rad(zone.Angle + (a or 0))
	return Config.Wild.Center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
end
for _, z in ipairs(Config.Zones) do
	z.Center = Config.wildPos(z, 290, 0)
	z.Arena = Config.wildPos(z, Config.Wild.ArenaR, 0)
	for _, c in ipairs(z.Camps) do
		c.Pos = Config.wildPos(z, c.R, c.A)
	end
	for _, c in ipairs(z.NightCamps or {}) do
		c.Pos = Config.wildPos(z, c.R, c.A)
	end
end

return Config
