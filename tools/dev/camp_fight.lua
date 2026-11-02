-- Dev tool (Studio, Client during Play): bot-fights one camp and reports clear time and damage taken.
-- Clients can't fetch this file, so paste its source into execute_luau on the Client; edit ZONE/CAMP.
-- It waits for the camp to be full (4), heals (admin), stands 30 studs from it, then fights with the
-- equipped weapon's combo timings, always hitting the nearest mob of the camp.
local ZONE, CAMP = 5, 1
local Net = require(game.ReplicatedStorage.Mystree.Net)
local Config = require(game.ReplicatedStorage.Mystree.Config)
local pl = game.Players.LocalPlayer
local zone = Config.Zones[ZONE]
local campDef = zone.Camps[CAMP]
local MOB, camp = campDef.Mob, campDef.Pos
local function alive()
	local list = {}
	for _, m in ipairs(workspace.Mobs:GetChildren()) do
		if m:GetAttribute("MobId") == MOB and not m:GetAttribute("Dead") and m.PrimaryPart and (m.PrimaryPart.Position - camp).Magnitude < 110 then
			table.insert(list, m)
		end
	end
	return list
end
local t = os.clock()
while #alive() < campDef.Count and os.clock() - t < 40 do
	task.wait(1)
end
Net.invoke("Admin", "Heal")
task.wait(0.5)
local hrp = pl.Character.HumanoidRootPart
local hum = pl.Character:FindFirstChildOfClass("Humanoid")
pl.Character:PivotTo(CFrame.new(camp + Vector3.new(0, 6, 30), camp + Vector3.new(0, 6, 0)))
local class = string.match(pl:GetAttribute("WeaponLook") or "Sword", "^(%a+)") or "Sword"
local combo = Config.WeaponClasses[class].Combo
local kills, minHP, taken, last = 0, hum.Health, 0, hum.Health
local hc = hum.HealthChanged:Connect(function(h)
	if h < last then
		taken += last - h
	end
	last = h
	minHP = math.min(minHP, h)
end)
local t0, i = os.clock(), 0
while os.clock() - t0 < 80 and hum.Health > 0 and kills < campDef.Count do
	local best, bd
	for _, m in ipairs(alive()) do
		local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
		if not bd or d < bd then
			best, bd = m, d
		end
	end
	if not best then
		break
	end
	if bd > 9 then
		hum:MoveTo(best.PrimaryPart.Position)
		task.wait(0.25)
	else
		hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(best.PrimaryPart.Position.X, hrp.Position.Y, best.PrimaryPart.Position.Z))
		i = i % #combo + 1
		Net.invoke("Swing", i, (best.PrimaryPart.Position - hrp.Position).Unit)
		task.wait(combo[i].Time)
		if best:GetAttribute("Dead") then
			kills += 1
		end
	end
end
hc:Disconnect()
local el = os.clock() - t0
return string.format("%s %s camp (%s): %.0fs, %d/%d kills, taken %.0f/s, lowest HP %.0f%%, alive %s", zone.Name, MOB, class, el, kills, campDef.Count, taken / el, minHP / hum.MaxHealth * 100, tostring(hum.Health > 0))
