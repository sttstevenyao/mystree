-- ServerScriptService/Mystree/Services/MobService (ModuleScript)
-- Mobs of the Wildlands (the open-world Hunting Grounds): camps, elites, rares, Mythic beasts, zone
-- bosses, event mobs, mutations, simple melee AI, and rewards.
--  * Camps keep Count mobs alive and respawn them Respawn s after death. Night camps only refill
--    at night. A camp spawn can be the zone's Rare instead (Rare.Chance, one alive per zone), and a
--    Normal spawn can be mutated (Config.Mutations, some only during a world event).
--  * Each zone's Boss always stands in its arena and comes back Boss.Respawn s after it falls.
--  * Mythic beasts (Config.SuperRares) roll every Wild.Mythic.RollEvery s: at most one alive, anywhere
--    in the Wildlands, leaving after Lifetime s if nobody is fighting it.
--  * Every day/night switch (5 min) each zone spawns its Elite; an event (Bloodmoon/Golden Hour)
--    spawns event mobs and a boss per zone with a big server alert. Event mobs leave when it ends.
--  * Communal scaling: HP grows with the players nearby at spawn (elites/bosses re-check every 5 s),
--    and everyone who dealt at least Config.Communal.MinShare of its HP gets their own full rewards.
--  * HP lives in attributes (HP, MaxHP) on the model; the Humanoid only walks. Attributes also carry
--    MobId, Level, Kind, Aggro (UserId of the player it's after, 0 = none) and the current attack
--    (AttackAnim, AttackHeavy, AttackShock, AttackRange, then Windup = server time it lands) for the
--    client (MobFx, Gaits).
--  * Combat (user, 2026-10-27, Deepwoken / Rune Slayer style): mobs turn to face their target
--    smoothly (an AlignOrientation, never a CFrame snap), wait Config.MobAI.Engage after aggroing,
--    then pick an attack from their set (Config.MobAttacks): wind-up, commit, strike. Lunges and
--    charges surge forward and can open from range; shockwaves hit everyone near; the rest hit a
--    cone in front. A dash's i-frames make it miss (CombatService.hurt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local Creatures = require(ReplicatedStorage.Mystree.Creatures)

local MobService = {}
local S

local rng = Random.new()
local folder
local mobs = {} -- model -> state { Def, Id, Level, Stats, Home, Camp, Target, NextAttack, Damage = {player = n}, Event? }
local attackSet, alignFor, setTarget -- defined further down
local camps = {} -- { Zone, Def (camp table), Night, Alive = {model}, Pending = n }

local zoneIndex = {}
for _, z in ipairs(Config.Zones) do
	zoneIndex[z.Id] = z
end
local function zoneById(id)
	return zoneIndex[id]
end

local ALERT_NAMES = {
	GodlySkeleton = "GODLY SKELETON HAS SPAWNED!",
	JadeTortoise = "THE JADE TORTOISE HAS SPAWNED!",
}

function MobService.alive()
	local list = {}
	for m, st in pairs(mobs) do
		if not st.Dead then
			table.insert(list, m)
		end
	end
	return list
end

local function playersNear(pos, radius)
	local n, list = 0, {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and (hrp.Position - pos).Magnitude <= radius then
			n += 1
			table.insert(list, pl)
		end
	end
	return n, list
end

-- Rares scale like elites and Mythic beasts like bosses
local BIG = { Elite = "Elite", Rare = "Elite", Boss = "Boss", Mythic = "Boss" }

local function communalMult(kind, n)
	local C = Config.Communal
	local per = (BIG[kind] == "Boss" and C.Boss) or (BIG[kind] == "Elite" and C.Elite) or C.Normal
	return 1 + per * math.max(0, n - 1)
end

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { folder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), params)
	return hit and hit.Position or pos
end

-- Mutation look, server-side so every client sees it: body tinted, a glow (light + soft mist) or moss
local MIST = "rbxasset://textures/particles/smoke_main.dds"
local function mutate(model, mut)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Name ~= "Eye" then
			p.Color = p.Color:Lerp(mut.Tint[1], mut.Tint[2])
			if mut.Moss and (p.Name == "Body" or p.Name == "Torso" or p.Name == "Chest") then
				p.Material = Enum.Material.Grass
			end
		end
	end
	local root = model.PrimaryPart
	if mut.Glow then
		local light = Instance.new("PointLight")
		light.Color = mut.Glow
		light.Range = 12
		light.Brightness = 1.2
		light.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Texture = MIST
		e.Color = ColorSequence.new(mut.Glow)
		e.LightEmission = 0.8
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new(root.Size.X * 0.6, root.Size.X * 1.1)
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Rate = 6
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = root
	end
end

-- big-mob glow (rares and Mythic beasts read from far away)
local function aura(model, color, mythic, lightOnly)
	local root = model.PrimaryPart
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = mythic and 26 or 16
	light.Brightness = mythic and 2.5 or 1.6
	light.Parent = root
	if lightOnly then
		return -- a sculpted model: under the game's bloom this mist washes it out to white
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = MIST
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(root.Size.X * 0.8, root.Size.X * 1.6)
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Rate = mythic and 14 or 7
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = root
end

-- a Normal spawn's mutation roll (event-only mutations only while their event runs)
local function rollMutation()
	local event = workspace:GetAttribute("CycleEvent") or ""
	for id, mut in pairs(Config.Mutations) do
		if (not mut.Event or mut.Event == event) and rng:NextNumber() < mut.Chance then
			return id
		end
	end
	return nil
end

-- Spawn one mob. opts: Level (override), Camp, Event (event name), Zone (zone table), Mutation (id)
-- which attack set a mob uses: its own (Mobs[id].Attacks), else by its creature recipe
local HORNED = { Boar = true, Deer = true, Ox = true }
local BEASTS = { Wolf = true, WolfBlock = true, Feline = true, Bear = true, Sprawler = true, Serpent = true }
attackSet = function(id, def)
	if def.Attacks and Config.MobAttacks[def.Attacks] then
		return Config.MobAttacks[def.Attacks]
	end
	local boss = def.Kind == "Boss" or def.Kind == "Mythic"
	local look = Creatures.Looks[id]
	if look and HORNED[look[1]] then
		return Config.MobAttacks[boss and "HornedBoss" or "Horned"]
	elseif look and BEASTS[look[1]] and not (boss and look[1] ~= "Wolf") then
		return Config.MobAttacks.Beast
	end
	return Config.MobAttacks[boss and "GenericBoss" or "Generic"]
end

-- turns the mob smoothly toward its target while it fights (Humanoid.AutoRotate is off then)
alignFor = function(root)
	local att = Instance.new("Attachment")
	att.Name = "MobAlign"
	att.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Name = "MobAlign"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e12
	ao.MaxAngularVelocity = Config.MobAI.TurnSpeed
	ao.Responsiveness = 30
	ao.Enabled = false
	ao.Parent = root
	return ao
end

function MobService.spawn(id, pos, opts)
	opts = opts or {}
	local def = Config.Mobs[id]
	local zone = opts.Zone
	local level = opts.Level or def.Level or 1
	if def.ZoneLevel and zone then
		level = (def.Kind == "Mythic") and (zone.MaxLevel + 5) or (zone.MinLevel + 5)
	end
	local mut = opts.Mutation and Config.Mutations[opts.Mutation]
	local stats = Rules.mobStats(def, level)
	if mut then
		stats.HP = math.floor(stats.HP * mut.HP + 0.5)
		stats.Dmg = math.floor(stats.Dmg * mut.Dmg + 0.5)
		stats.Exp = math.floor(stats.Exp * mut.Exp + 0.5)
		stats.Scraps = math.floor(stats.Scraps * (mut.ScrapMult or 1) + 0.5)
	end
	local ground = groundAt(pos)
	local model = Assets.Mob(id, CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	if mut then
		if mut.Scale and mut.Scale ~= 1 then
			model:ScaleTo(mut.Scale)
		end
		mutate(model, mut)
		model:SetAttribute("Mutation", opts.Mutation)
	elseif def.Kind == "Rare" or def.Kind == "Mythic" then
		-- (beasts with their own Auras preset skip this mist: under the game's bloom it washed them white)
		if not def.Aura then
			aura(model, def.Color:Lerp(Color3.new(1, 1, 1), 0.3), def.Kind == "Mythic", Creatures.Looks[id] ~= nil)
		end
	end
	local n = playersNear(ground, Config.Communal.Radius)
	local maxHP = math.floor(stats.HP * communalMult(def.Kind, n) + 0.5)
	model:SetAttribute("MobId", id)
	model:SetAttribute("Name", mut and (mut.Name .. " " .. def.Name) or def.Name)
	model:SetAttribute("Level", level)
	model:SetAttribute("Kind", def.Kind)
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("HP", maxHP)
	model:SetAttribute("Scale", n)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = def.Speed
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = folder
	local root = model.PrimaryPart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	mobs[model] = {
		Def = def,
		Id = id,
		Level = level,
		Stats = stats,
		Home = ground,
		Camp = opts.Camp,
		Event = opts.Event,
		ZoneId = zone and zone.Id,
		Mutation = opts.Mutation,
		Born = os.clock(),
		LastHit = 0,
		Players = n,
		NextAttack = 0,
		NextWander = os.clock() + rng:NextNumber(2, 6),
		Damage = {},
		Attacks = attackSet(id, def),
		Align = alignFor(root),
		BusyUntil = 0,
	}
	model:SetAttribute("Aggro", 0)
	return model
end

-- ===================================================================== damage & rewards
local function rollTable(drops)
	local out = {}
	for key, d in pairs(drops) do
		if key == "Mount" then
			if rng:NextNumber() < d[1] then
				out.Mount = d[2]
			end
		elseif key == "Gear" then
			out.Gear = d[2] -- count (always drops)
		elseif key == "Set" then
			out.Set = rng:NextNumber() < d[1]
		elseif rng:NextNumber() < d[1] then
			out[key] = rng:NextInteger(d[2], d[3])
		end
	end
	return out
end

local function reward(player, model, st)
	local data = S.DataService.data(player)
	if not data then
		return
	end
	local def = st.Def
	local pos = model.PrimaryPart and model.PrimaryPart.Position or st.Home
	S.StatsService.addExp(player, st.Stats.Exp)
	local scraps = math.floor(st.Stats.Scraps * S.GearService.scrapMult(player) + 0.5)
	S.DataService.add(player, "Scraps", scraps)
	data.Stats.Kills += 1
	data.Stats.Mobs = data.Stats.Mobs or {}
	data.Stats.Mobs[st.Id] = (data.Stats.Mobs[st.Id] or 0) + 1
	if def.Kind == "Elite" or def.Kind == "Rare" then
		data.Stats.Elites += 1
	elseif def.Kind == "Boss" or def.Kind == "Mythic" then
		data.Stats.Bosses += 1
	end
	local got = rollTable(def.Drops or {})
	-- a mutation adds its own rolls
	local mut = st.Mutation and Config.Mutations[st.Mutation]
	if mut then
		for k, n in pairs(rollTable(mut.Drops)) do
			got[k] = (got[k] or 0) + n
		end
	end
	local loot = { Scraps = scraps, Exp = st.Stats.Exp }
	for k, n in pairs(got) do
		if k ~= "Gear" and k ~= "Mount" and k ~= "Set" then
			S.DataService.grant(player, { [k] = n })
			loot[k] = n
		end
	end
	S.Remotes.Drop:FireClient(player, { Source = "Mob", Pos = pos, Loot = loot, Mob = def.Name })
	-- elite/boss gear: rolled at the player's tree odds, shifted up a tier
	for _ = 1, (got.Gear or 0) do
		local item = S.GearService.roll(player, { Shift = Config.EliteGearBonus })
		local result = S.GearService.give(player, item)
		S.Remotes.Drop:FireClient(player, {
			Source = "Mob", Pos = pos, Item = item, R = item.R,
			Equipped = result.Equipped, Dismantled = result.Dismantled, Scraps = result.Scraps, BagFull = result.BagFull,
		})
	end
	-- a piece of the zone's armour set (bosses always, rares by chance)
	local zone = st.ZoneId and zoneById(st.ZoneId)
	if got.Set and zone and zone.Set then
		local item = Rules.rollSetItem(data.Tree.Level, zone.Set, rng)
		local result = S.GearService.give(player, item)
		S.Remotes.Drop:FireClient(player, {
			Source = "Mob", Pos = pos, Item = item, R = item.R,
			Equipped = result.Equipped, Dismantled = result.Dismantled, Scraps = result.Scraps, BagFull = result.BagFull,
		})
	end
	-- (no server-wide announcements for loot, relics or mounts: user, 2026-10-27)
	if got.Mount and not data.Mounts[got.Mount] then
		S.MountService.grant(player, got.Mount)
	end
	S.DataService.push(player)
end

local function kill(model, st)
	st.Dead = true
	model:SetAttribute("HP", 0)
	model:SetAttribute("Dead", true)
	local total = model:GetAttribute("MaxHP")
	for player, dealt in pairs(st.Damage) do
		if player.Parent and dealt >= total * Config.Communal.MinShare then
			task.spawn(reward, player, model, st)
		end
	end
	if st.Def.Kind == "Boss" or st.Def.Kind == "Mythic" then
		S.Remotes.alert(string.upper(st.Def.Name) .. " HAS FALLEN!", st.Def.Kind == "Mythic" and "Mythic" or "Legendary")
	elseif st.Def.Kind == "Rare" then
		S.Remotes.notifyAll(string.format("The %s has been slain.", st.Def.Name), "Rare")
	end
	if st.Arena then
		-- zone boss: back in its arena after Respawn s
		local zone = st.Arena
		task.delay(zone.Boss.Respawn, function()
			MobService.spawnBoss(zone)
		end)
	end
	local root = model.PrimaryPart
	if root then
		root.Anchored = true
	end
	st.Align.Enabled = false
	model:SetAttribute("Aggro", 0)
	task.delay(Config.MobAI.CorpseTime, function()
		mobs[model] = nil
		model:Destroy()
	end)
	if st.Camp then
		local camp = st.Camp
		camp.Pending += 1
		task.delay(camp.Def.Respawn, function()
			camp.Pending -= 1
		end)
	end
end

-- companion: the companion id when a companion dealt it (clients draw its attack)
function MobService.damage(model, player, amount, crit, companion)
	local st = mobs[model]
	if not st or st.Dead then
		return
	end
	local hp = model:GetAttribute("HP") - amount
	st.Damage[player] = (st.Damage[player] or 0) + amount
	st.LastHit = os.clock()
	model:SetAttribute("HP", math.max(0, hp))
	-- getting hit pulls aggro onto the hitter (passive mobs flee instead)
	if not st.Target or not st.Target.Parent then
		setTarget(model, st, player, os.clock())
	end
	local pos = model.PrimaryPart and model.PrimaryPart.Position or st.Home
	S.Remotes.fireNear("Hit", pos, 150, { Target = model, Amount = amount, Crit = crit, By = player, Companion = companion })
	S.CompanionService.setTarget(player, model)
	if hp <= 0 then
		kill(model, st)
	end
end

-- ===================================================================== AI
local function targetPos(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return hrp.Position
	end
	return nil
end

local function flat(v)
	v = v * Vector3.new(1, 0, 1)
	return v.Magnitude > 1e-3 and v.Unit or Vector3.new(0, 0, -1)
end

-- face a point (the AlignOrientation turns the body; AutoRotate would fight it)
local function faceTo(st, hum, pos, at)
	hum.AutoRotate = false
	st.Align.CFrame = CFrame.lookAt(Vector3.zero, flat(at - pos))
	st.Align.Enabled = true
end

local function freeTurn(st, hum)
	st.Align.Enabled = false
	hum.AutoRotate = true
end

-- a short server-side surge forward (lunges, charges)
local function surge(root, dir, dist)
	local att = root:FindFirstChild("MobAlign")
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(1e7, 0, 1e7)
	lv.VectorVelocity = dir * (dist / Config.MobAI.LungeTime)
	lv.Parent = root
	task.delay(Config.MobAI.LungeTime, function()
		lv:Destroy()
	end)
end

local function pick(list, filter)
	local total, pool = 0, {}
	for _, a in ipairs(list) do
		if not filter or filter(a) then
			total += a.Weight
			table.insert(pool, a)
		end
	end
	local r = rng:NextNumber() * total
	for _, a in ipairs(pool) do
		r -= a.Weight
		if r <= 0 then
			return a
		end
	end
	return pool[#pool]
end

-- wind up, commit, strike. atk = one of Config.MobAttacks[set]
local function attack(model, st, root, hum, atk, reach, now)
	local AI = Config.MobAI
	local def = st.Def
	-- a little jitter, so a pack doesn't strike in lockstep
	st.NextAttack = now + math.max(def.AttackTime, atk.Windup + AI.Recover + 0.2) + rng:NextNumber(0, 1)
	st.BusyUntil = now + atk.Windup + AI.Recover + (atk.Lunge and AI.LungeTime or 0)
	hum:MoveTo(root.Position)
	local hitRange = reach * atk.Range
	model:SetAttribute("AttackAnim", atk.Anim)
	model:SetAttribute("AttackHeavy", atk.Heavy == true)
	model:SetAttribute("AttackShock", atk.Shockwave == true)
	model:SetAttribute("AttackRange", atk.Shockwave and hitRange or 0)
	model:SetAttribute("Windup", workspace:GetServerTimeNow() + atk.Windup)
	local target = st.Target
	-- track the target through most of the wind-up, then commit (a late dodge sideways works)
	local track = RunService.Heartbeat:Connect(function()
		local tp = targetPos(target)
		if tp and root.Parent then
			faceTo(st, hum, root.Position, tp)
		end
	end)
	task.delay(atk.Windup * 0.7, function()
		track:Disconnect()
	end)
	task.delay(atk.Windup, function()
		if st.Dead or not model.Parent then
			return
		end
		local look = flat(root.CFrame.LookVector)
		local function resolve()
			if st.Dead or not model.Parent then
				return
			end
			local origin = root.Position
			for _, pl in ipairs(Players:GetPlayers()) do
				local pp = targetPos(pl)
				if pp and (atk.Shockwave or pl == target or atk.Arc >= 90) then
					local off = (pp - origin) * Vector3.new(1, 0, 1)
					local ang = off.Magnitude < 0.5 and 0 or math.deg(math.acos(math.clamp(look:Dot(off.Unit), -1, 1)))
					if off.Magnitude <= hitRange and ang <= atk.Arc then
						S.CombatService.hurt(pl, math.floor(st.Stats.Dmg * atk.Dmg + 0.5), st.Level, origin)
					end
				end
			end
		end
		if atk.Lunge then
			-- surge up to the target, not through it; the hit is then a melee check in front
			local tp = targetPos(target)
			local gap = tp and ((tp - root.Position) * Vector3.new(1, 0, 1)).Magnitude or atk.Lunge
			surge(root, look, math.clamp(gap - reach * 0.5, 0, atk.Lunge))
			hitRange = reach * 1.05
			task.delay(AI.LungeTime * 0.9, resolve)
		else
			resolve()
		end
	end)
end

-- the player a mob is after (0 = none) also goes to the client (aggro ring, health bar)
setTarget = function(model, st, player, now)
	if st.Target == player then
		return
	end
	st.Target = player
	model:SetAttribute("Aggro", player and player.UserId or 0)
	if player then
		st.NextAttack = math.max(st.NextAttack, now + Config.MobAI.Engage + rng:NextNumber(0, 0.6))
	end
end

local function think(model, st, now)
	local root = model.PrimaryPart
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return
	end
	local AI = Config.MobAI
	local def = st.Def
	local pos = root.Position
	-- mid-attack: committed
	if now < st.BusyUntil then
		return
	end
	-- leash: too far from home -> drop target and walk back
	if (pos - st.Home).Magnitude > AI.LeashRange then
		setTarget(model, st, nil, now)
		freeTurn(st, hum)
		hum:MoveTo(st.Home)
		return
	end
	if st.Target then
		local tp = targetPos(st.Target)
		if not tp or (tp - pos).Magnitude > AI.LeashRange then
			setTarget(model, st, nil, now)
		end
	end
	if not st.Target and not def.Passive then
		local best, bestD = nil, AI.AggroRange
		for _, pl in ipairs(Players:GetPlayers()) do
			local tp = targetPos(pl)
			if tp and (tp - pos).Magnitude < bestD then
				best, bestD = pl, (tp - pos).Magnitude
			end
		end
		setTarget(model, st, best, now)
	end
	if st.Target then
		local tp = targetPos(st.Target)
		if def.Passive then
			-- flee: run directly away from whoever is hunting it
			freeTurn(st, hum)
			local away = (pos - tp) * Vector3.new(1, 0, 1)
			if away.Magnitude > 0.1 then
				hum:MoveTo(pos + away.Unit * 16)
			end
			return
		end
		local d = ((tp - pos) * Vector3.new(1, 0, 1)).Magnitude
		local reach = def.Range + math.max(root.Size.X, root.Size.Z) / 2
		if d > reach * 0.85 then
			-- chasing; with the attack ready and the target in lunge range, sometimes open with a lunge
			if now >= st.NextAttack and rng:NextNumber() < AI.LungeChance then
				local lunge = pick(st.Attacks, function(a)
					return a.Lunge ~= nil and d <= reach * a.Range
				end)
				if lunge and lunge.Lunge then
					faceTo(st, hum, pos, tp)
					attack(model, st, root, hum, lunge, reach, now)
					return
				end
			end
			freeTurn(st, hum)
			hum:MoveTo(tp)
		else
			hum:MoveTo(pos)
			faceTo(st, hum, pos, tp)
			if now >= st.NextAttack then
				attack(model, st, root, hum, pick(st.Attacks), reach, now)
			end
		end
	elseif now >= st.NextWander then
		freeTurn(st, hum)
		st.NextWander = now + rng:NextNumber(4, 9)
		hum:MoveTo(st.Home + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14)))
	end
end

-- Communal re-check for elites/bosses: more players arrived -> more HP, same fraction
local function rescale(model, st)
	if not BIG[st.Def.Kind] then
		return
	end
	local n = playersNear(model.PrimaryPart.Position, Config.Communal.Radius)
	if n > st.Players then
		local oldMax = model:GetAttribute("MaxHP")
		local newMax = math.floor(st.Stats.HP * communalMult(st.Def.Kind, n) + 0.5)
		local frac = model:GetAttribute("HP") / oldMax
		st.Players = n
		model:SetAttribute("MaxHP", newMax)
		model:SetAttribute("HP", math.floor(newMax * frac + 0.5))
		model:SetAttribute("Scale", n)
	end
end

-- ===================================================================== spawning rules
local hasAlive

local function fillCamps()
	local isNight = workspace:GetAttribute("CyclePhase") == "Night"
	for _, camp in ipairs(camps) do
		-- prune the dead
		for i = #camp.Alive, 1, -1 do
			local m = camp.Alive[i]
			if not mobs[m] or mobs[m].Dead then
				table.remove(camp.Alive, i)
			end
		end
		if camp.Night and not isNight then
			continue
		end
		while #camp.Alive + camp.Pending < camp.Def.Count do
			local p = camp.Def.Pos + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
			local zone = camp.Zone
			local id, mutation = camp.Def.Mob, nil
			if zone.Rare and not hasAlive(zone.Rare.Mob, zone) and rng:NextNumber() < zone.Rare.Chance then
				id = zone.Rare.Mob
			elseif Config.Mobs[id].Kind == "Normal" then
				mutation = rollMutation()
			end
			local m = MobService.spawn(id, p, { Camp = camp, Zone = zone, Mutation = mutation })
			table.insert(camp.Alive, m)
			if id ~= camp.Def.Mob then
				S.Remotes.alert(string.format("A %s HAS APPEARED IN %s!", string.upper(Config.Mobs[id].Name), string.upper(zone.Name)), "Rare")
			end
		end
	end
end

function hasAlive(id, zone)
	for m, st in pairs(mobs) do
		if st.Id == id and not st.Dead and st.ZoneId == zone.Id then
			return true
		end
	end
	return false
end

local function onCycle(phase, event)
	-- event mobs from the last event leave
	for m, st in pairs(mobs) do
		if st.Event and st.Event ~= event and not st.Dead then
			mobs[m] = nil
			m:Destroy()
		end
	end
	-- night camp mobs leave at dawn
	if phase == "Day" then
		for _, camp in ipairs(camps) do
			if camp.Night then
				for _, m in ipairs(camp.Alive) do
					local st = mobs[m]
					if st and not st.Dead and not st.Target then
						mobs[m] = nil
						m:Destroy()
					end
				end
			end
		end
	end
	-- elites (5-minute spawns, communal scaling)
	for _, z in ipairs(Config.Zones) do
		if not hasAlive(z.Elite, z) then
			MobService.spawn(z.Elite, z.Center + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30)), { Zone = z })
		end
	end
	S.Remotes.notifyAll("⚔️ Elites have appeared in every zone of the Wildlands.", "Elite")
	if event ~= "" then
		local ev = Config.Cycle.Events[event]
		for _, z in ipairs(Config.Zones) do
			for _ = 1, Config.Cycle.EventMobsPerZone do
				local p = Config.wildPos(z, rng:NextNumber(150, 400), rng:NextNumber(-20, 20))
				MobService.spawn(ev.Mobs, p, { Zone = z, Event = event })
			end
			MobService.spawn(ev.Boss, z.Center, { Zone = z, Event = event })
		end
		task.delay(2.5, function()
			S.Remotes.alert(ALERT_NAMES[ev.Boss] or (string.upper(Config.Mobs[ev.Boss].Name) .. " HAS SPAWNED!"), event)
		end)
	end
end
MobService.onCycle = onCycle

-- ===================================================================== zone bosses and Mythic beasts
-- A zone's boss, standing in its arena (it leashes back there)
function MobService.spawnBoss(zone)
	if hasAlive(zone.Boss.Mob, zone) then
		return
	end
	local m = MobService.spawn(zone.Boss.Mob, zone.Arena, { Zone = zone })
	mobs[m].Arena = zone
	return m
end

-- One Mythic beast somewhere in the Wildlands (id / zone random unless given)
function MobService.spawnMythic(id, zone)
	id = id or Config.SuperRares[rng:NextInteger(1, #Config.SuperRares)]
	zone = zone or Config.Zones[rng:NextInteger(1, #Config.Zones)]
	local p = Config.wildPos(zone, rng:NextNumber(150, 420), rng:NextNumber(-22, 22))
	local m = MobService.spawn(id, p, { Zone = zone })
	S.Remotes.alert(string.format("A %s HAS APPEARED IN %s!", string.upper(Config.Mobs[id].Name), string.upper(zone.Name)), "Mythic")
	return m
end

local function mythicAlive()
	for m, st in pairs(mobs) do
		if st.Def.Kind == "Mythic" and not st.Dead then
			return m, st
		end
	end
end

local function mythicLoop()
	local M = Config.Wild.Mythic
	while true do
		task.wait(M.RollEvery)
		local m, st = mythicAlive()
		if m then
			-- it wanders off if nobody has fought it for a minute after its time is up
			if os.clock() - st.Born > M.Lifetime and os.clock() - st.LastHit > 60 then
				mobs[m] = nil
				m:Destroy()
				S.Remotes.notifyAll(string.format("The %s has vanished into the mist.", st.Def.Name), "Info")
			end
		elseif rng:NextNumber() < M.Chance then
			MobService.spawnMythic()
		end
	end
end

function MobService.Init(services)
	S = services
	folder = workspace:FindFirstChild("Mobs") or Instance.new("Folder")
	folder.Name = "Mobs"
	folder.Parent = workspace
	for _, z in ipairs(Config.Zones) do
		for _, c in ipairs(z.Camps) do
			table.insert(camps, { Zone = z, Def = c, Night = false, Alive = {}, Pending = 0 })
		end
		for _, c in ipairs(z.NightCamps or {}) do
			table.insert(camps, { Zone = z, Def = c, Night = true, Alive = {}, Pending = 0 })
		end
	end
end

-- Admin: spawn any mob in front of a player
function MobService.spawnNear(player, id)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (hrp and (Config.Mobs[id] or Config.Mutations[id])) then
		return false
	end
	local zone = Config.Zones[1]
	for _, z in ipairs(Config.Zones) do
		if S.WorldService.zoneAt(hrp.Position) == z.Id then
			zone = z
		end
	end
	local mutation = Config.Mutations[id] and id or nil
	if mutation then
		-- "Spawn <MutationId>": a mutated Normal mob of this zone
		id = zone.Camps[1].Mob
	end
	MobService.spawn(id, hrp.Position + hrp.CFrame.LookVector * 20, { Zone = zone, Mutation = mutation })
	if Config.Mobs[id].Kind == "Boss" then
		S.Remotes.alert(ALERT_NAMES[id] or (string.upper(Config.Mobs[id].Name) .. " HAS SPAWNED!"), "Bloodmoon")
	end
	return true
end

function MobService.Start()
	S.WorldService.Changed:Connect(onCycle)
	task.wait(1)
	onCycle(workspace:GetAttribute("CyclePhase") or "Day", workspace:GetAttribute("CycleEvent") or "")
	for _, z in ipairs(Config.Zones) do
		MobService.spawnBoss(z)
	end
	task.spawn(mythicLoop)
	local lastRescale = 0
	while true do
		task.wait(Config.MobAI.Tick)
		local now = os.clock()
		fillCamps()
		local doRescale = now - lastRescale > Config.Communal.Recheck
		if doRescale then
			lastRescale = now
		end
		for model, st in pairs(mobs) do
			if not st.Dead and model.Parent then
				local ok, err = pcall(think, model, st, now)
				if not ok then
					warn("[MobService] " .. tostring(err))
				end
				if doRescale then
					rescale(model, st)
				end
			end
		end
	end
end

return MobService
