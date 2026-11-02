-- ServerScriptService/Mystree/Services/CombatService (ModuleScript)
-- Player attacks and player damage. The client plays the swing and sends intent ("Swing", combo
-- index, facing); the server checks timing against the equipped weapon's moveset, finds mobs in
-- the hitbox (range + arc in front of the player), rolls crits and applies damage via MobService.
-- Hit numbers go to everyone nearby (Remotes "Hit"), so the whole group sees the fight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)

local CombatService = {}
local S

local rng = Random.new()
local lastSwing = {} -- player -> { At, Index }

local procCount = {} -- player -> hits landed with a Mythforged weapon
local dodgeUntil = {} -- player -> os.clock() until which mob hits miss (the dash's i-frames)
local lastPvP = {} -- player -> os.clock() of their last PvP hit, dealt or taken
local pvpDamage = {} -- victim -> { [attacker] = { Dmg, At } }: PvP damage taken since their last death

-- both on, both in the Hunting Grounds, both alive
local function pvpOk(a, b)
	if a == b or not (a:GetAttribute("PvP") and b:GetAttribute("PvP")) then
		return false
	end
	return a:GetAttribute("InGrounds") == true and b:GetAttribute("InGrounds") == true
end
CombatService.pvpOk = pvpOk

local function weapon(player)
	local data = S.DataService.data(player)
	local id = data and data.Equipped.Weapon
	return id and data.Inventory[id]
end

-- Mythforged weapon effect: every Every-th landed swing hits everything near the target
local function proc(player, target, hum)
	local w = weapon(player)
	local def = w and w.Myth and Config.Forge.Myth[w.Myth]
	if not def then
		return
	end
	local fx = def.Effect
	procCount[player] = (procCount[player] or 0) + 1
	if procCount[player] % fx.Every ~= 0 then
		return
	end
	local center = target.PrimaryPart and target.PrimaryPart.Position
	if not center then
		return
	end
	local total = 0
	for _, mob in ipairs(S.MobService.alive()) do
		local root = mob.PrimaryPart
		if root and ((root.Position - center) * Vector3.new(1, 0, 1)).Magnitude <= fx.Radius + math.max(root.Size.X, root.Size.Z) / 2 then
			local amount, crit = CombatService.rollDamage(player, fx.Mult)
			S.MobService.damage(mob, player, amount, crit)
			total += amount
		end
	end
	if fx.Heal and hum then
		hum.Health = math.min(hum.MaxHealth, hum.Health + total * fx.Heal)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - center).Magnitude < 200 then
			S.Remotes.Effect:FireClient(pl, "WeaponProc", { Myth = w.Myth, Pos = center, Radius = fx.Radius, Color = fx.Color })
		end
	end
end

local function weaponClass(player)
	local data = S.DataService.data(player)
	local id = data and data.Equipped.Weapon
	local item = id and data.Inventory[id]
	return item and item.Class or "Sword"
end

-- Roll one hit for a player: returns amount, crit
function CombatService.rollDamage(player, mult)
	local st = S.StatsService.get(player)
	if not st then
		return 0, false
	end
	local crit = rng:NextNumber() < st.CritChance
	local spread = 0.92 + rng:NextNumber() * 0.16
	local amount = st.ATK * mult * spread * (crit and (1 + st.CritDamage) or 1)
	return math.max(1, math.floor(amount + 0.5)), crit
end

function CombatService.swing(player, index, look)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum and hum.Health > 0) then
		return false
	end
	if not player:GetAttribute("InGrounds") then
		return false
	end
	local class = Config.WeaponClasses[weaponClass(player)]
	local move = class.Combo[index]
	if not move then
		return false
	end
	-- timing: the previous move must have (mostly) played out, scaled by Attack Speed
	local st = S.StatsService.get(player)
	local speed = 1 + (st and st.AttackSpeed or 0)
	local prev = lastSwing[player]
	local now = os.clock()
	-- combo order: a chain starts at 1 and only moves forward (no spamming the best step)
	if index ~= 1 and prev and index <= prev.Index and now - prev.At < Config.ComboReset + 1 then
		return false
	end
	if prev then
		local prevMove = class.Combo[prev.Index] or move
		if now - prev.At < prevMove.Time / speed * 0.75 then
			return false
		end
	end
	lastSwing[player] = { At = now, Index = index }
	-- facing: the client's look, flattened; fall back to the root's look
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.1 then
		dir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	dir = dir.Unit
	local origin = hrp.Position
	local cosHalf = math.cos(math.rad(move.Arc / 2))
	local hits = 0
	local first
	for _, mob in ipairs(S.MobService.alive()) do
		local root = mob.PrimaryPart
		if root then
			local to = (root.Position - origin) * Vector3.new(1, 0, 1)
			local radius = math.max(root.Size.X, root.Size.Z) / 2
			local dist = to.Magnitude
			if dist <= move.Range + radius and math.abs(root.Position.Y - origin.Y) < 14 then
				local inArc = dist < radius + 2 or (to.Unit:Dot(dir) >= cosHalf)
				if inArc then
					local amount, crit = CombatService.rollDamage(player, move.Mult)
					S.MobService.damage(mob, player, amount, crit)
					hits += 1
					first = first or mob
					if st and st.Lifesteal > 0 then
						hum.Health = math.min(hum.MaxHealth, hum.Health + amount * st.Lifesteal)
					end
				end
			end
		end
	end
	-- PvP: other opted-in players in the same arc (Config.PvP)
	if player:GetAttribute("PvP") then
		for _, other in ipairs(Players:GetPlayers()) do
			local oc = other.Character
			local ohrp = oc and oc:FindFirstChild("HumanoidRootPart")
			local ohum = oc and oc:FindFirstChildOfClass("Humanoid")
			if ohrp and ohum and ohum.Health > 0 and pvpOk(player, other) and not oc:FindFirstChildOfClass("ForceField") then
				local to = (ohrp.Position - origin) * Vector3.new(1, 0, 1)
				local dist = to.Magnitude
				if dist <= move.Range + 1.5 and math.abs(ohrp.Position.Y - origin.Y) < 10 and (dist < 3 or to.Unit:Dot(dir) >= cosHalf) then
					if (dodgeUntil[other] or 0) > os.clock() then
						S.Remotes.effect(other, "Dodge", origin)
					else
						local amount, crit = CombatService.rollDamage(player, move.Mult * Config.PvP.DamageMult)
						local ost = S.StatsService.get(other)
						local dmg = Rules.mitigate(amount, ost and ost.DEF or 0, S.DataService.get(player, "Level") or 1)
						ohum:TakeDamage(dmg)
						lastPvP[player], lastPvP[other] = os.clock(), os.clock()
						pvpDamage[other] = pvpDamage[other] or {}
						local rec = pvpDamage[other][player] or { Dmg = 0 }
						rec.Dmg += dmg
						rec.At = os.clock()
						pvpDamage[other][player] = rec
						S.Remotes.fireNear("Hit", ohrp.Position, 150, { Target = oc, Amount = dmg, Crit = crit, By = player })
						S.Remotes.effect(other, "Hurt", dmg, origin)
						hits += 1
					end
				end
			end
		end
	end
	if first then
		proc(player, first, hum)
	end
	return true, nil, hits
end

-- A mob hits a player. Mitigated by DEF. Returns the damage dealt.
function CombatService.hurt(player, damage, attackerLevel, fromPos)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) or char:FindFirstChildOfClass("ForceField") then
		return 0
	end
	if (dodgeUntil[player] or 0) > os.clock() then
		S.Remotes.effect(player, "Dodge", fromPos)
		return 0
	end
	local st = S.StatsService.get(player)
	-- Agility: a chance to dodge the hit outright (Config.Agility)
	local agl = st and st.AGL or 0
	if agl > 0 then
		local A = Config.Agility
		if rng:NextNumber() < A.Cap * agl / (agl + A.PerLevel * math.max(1, attackerLevel or 1)) then
			S.Remotes.effect(player, "Dodge", fromPos)
			return 0
		end
	end
	local dmg = Rules.mitigate(damage, st and st.DEF or 0, attackerLevel)
	hum:TakeDamage(dmg)
	S.Remotes.effect(player, "Hurt", dmg, fromPos)
	return dmg
end

-- Revive Here (Robux): back on your feet where you fell, at full health
function CombatService.revive(player)
	local at = player:GetAttribute("DeathPos")
	if not at then
		return
	end
	player:SetAttribute("ReviveTo", at)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		player:LoadCharacter() -- WorldService places the new character at ReviveTo
	else
		S.AntiCheatService.grace(player)
		player.Character:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
		hum.Health = hum.MaxHealth
		player:SetAttribute("ReviveTo", nil)
		player:SetAttribute("InGrounds", true)
	end
	S.Remotes.notify(player, "Back on your feet!", "Purchase")
end

-- in a PvP fight (a PvP hit dealt or taken within Config.PvP.CombatLock): no leaving by travel
function CombatService.inCombat(player)
	return os.clock() - (lastPvP[player] or -99) < Config.PvP.CombatLock
end

function CombatService.Init(services)
	S = services
end

function CombatService.Start()
	Players.RespawnTime = Config.PlayerRespawn
	S.Remotes.Handle("Swing", 0.15, { "number", "Vector3" }, function(player, index, look)
		if index ~= math.floor(index) or not (look.Magnitude <= 2) then
			return false
		end
		return CombatService.swing(player, index, look)
	end)
	-- the dash (client Movement moves the character): opens the i-frame window and gives the
	-- anti-cheat a moment, since a dash is faster than any walk speed
	local D = Config.Move.Dash
	S.Remotes.Handle("Dash", D.Cooldown * 0.8, {}, function(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) or player:GetAttribute("Riding") then
			return false
		end
		-- the tier (and its i-frames) comes from the player's Agility (Config.Move.Dash.Tiers)
		local st = S.StatsService.get(player)
		local tier = Config.dashTier(st and st.AGL or 0)
		dodgeUntil[player] = os.clock() + tier.IFrames
		S.AntiCheatService.allow(player, tier.Speed * tier.Time * 1.3)
		return true
	end)
	-- what the character holds ("Held"): the client plays the draw / sheathe moves for everyone
	S.Remotes.Handle("Hold", 0.1, { "string" }, function(player, what)
		if what ~= "" and what ~= "Weapon" and what ~= "Axe" then
			return false
		end
		if what == "Axe" and player:GetAttribute("InGrounds") then
			return false
		end
		player:SetAttribute("Held", what)
		return true
	end)
	-- PvP toggle: on at once; off after Config.PvP.OffDelay, never in the middle of a fight
	local offToken = {}
	S.Remotes.Handle("SetPvP", 0.5, { "boolean" }, function(player, on)
		local P = Config.PvP
		if on then
			offToken[player] = nil
			player:SetAttribute("PvPOffAt", nil)
			player:SetAttribute("PvP", true)
			return true, "PvP is on. Players with PvP on can fight you in the Hunting Grounds."
		end
		if not player:GetAttribute("PvP") then
			return true
		end
		if os.clock() - (lastPvP[player] or -99) < P.CombatLock then
			return false, "You can't turn PvP off in the middle of a fight."
		end
		local token = {}
		offToken[player] = token
		player:SetAttribute("PvPOffAt", workspace:GetServerTimeNow() + P.OffDelay)
		task.delay(P.OffDelay, function()
			if offToken[player] == token and player.Parent then
				offToken[player] = nil
				player:SetAttribute("PvPOffAt", nil)
				player:SetAttribute("PvP", false)
			end
		end)
		return true, string.format("PvP turns off in %d seconds.", P.OffDelay)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		procCount[player] = nil
		dodgeUntil[player] = nil
		lastPvP[player] = nil
		pvpDamage[player] = nil
		for _, t in pairs(pvpDamage) do
			t[player] = nil
		end
		offToken[player] = nil
	end)
	-- remember where players fall in the Hunting Grounds (for Revive Here)
	local function watch(player)
		player:SetAttribute("Held", player:GetAttribute("InGrounds") and "" or "Axe")
		player:SetAttribute("PvP", false)
		player.CharacterAdded:Connect(function(char)
			-- you spawn at your island with the axe out (user); in the Hunting Grounds, empty-handed
			player:SetAttribute("Held", player:GetAttribute("InGrounds") and "" or "Axe")
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					-- a PvP death: whoever dealt the most PvP damage recently takes a little of the
					-- loser's Peaches
					local P = Config.PvP
					local taken = pvpDamage[player]
					pvpDamage[player] = nil
					local winner, most = nil, 0
					for attacker, rec in pairs(taken or {}) do
						if attacker.Parent and os.clock() - rec.At < P.KillWindow and rec.Dmg > most then
							winner, most = attacker, rec.Dmg
						end
					end
					if winner then
						-- (Peaches = the main currency, save key "Scraps")
						local have = S.DataService.get(player, "Scraps") or 0
						local amount = math.min(have, math.clamp(math.floor(have * P.PeachShare + 0.5), 1, P.PeachMax))
						if amount > 0 then
							S.DataService.add(player, "Scraps", -amount)
							S.DataService.add(winner, "Scraps", amount)
						end
						local data = S.DataService.data(winner)
						if data then
							data.Stats.PvPKills = (data.Stats.PvPKills or 0) + 1
						end
						S.Remotes.notifyAll(string.format("%s defeated %s%s", winner.DisplayName, player.DisplayName,
							amount > 0 and string.format(" and took %s Peaches!", Format.Commas(amount)) or "!"), "Elite")
					end
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp and player:GetAttribute("InGrounds") then
						player:SetAttribute("DeathPos", hrp.Position)
						S.Remotes.effect(player, "Died", Config.PlayerRespawn)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, pl in ipairs(Players:GetPlayers()) do
		watch(pl)
	end
end

return CombatService
