-- StarterPlayerScripts/MystreeClient/Loot (ModuleScript)
-- What a drop looks like (Net "Drop"). The rarer the drop, the louder the moment (Playbook 01):
--  * Every drop: a glowing orb in the rarity colour pops out of the trunk (or the mob), arcs to the
--    ground, bounces, then flies into you.
--  * Rare+: a light beam on the landing spot, a ring, the rarity sound, and a loot card with the
--    item in 3D, its stats and the CP change, with Equip / Dismantle buttons.
--  * Epic+: a screen flash and a bigger shake. Legendary+: a centre "LEGENDARY!" moment.
--    Golden Bough: a gold beam and the jackpot moment.
--  * Lucky bonuses (Lucky Chip, Sap Burst) and mob loot float up as coloured numbers.
--  * Armour set pieces get the big moment and their set's name on the icon. Relics (Mythic beast
--    drops, the rarest thing in the game) get two beams, a "RELIC!" moment and their own icon; Star
--    Shards get a smaller glow burst.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local Loot = {}
local C
local T = UI.T
local player = Players.LocalPlayer

local RARITY_SOUND = { [3] = "Rare", [4] = "Epic", [5] = "Legendary", [6] = "Legendary", [7] = "Legendary" }

local function myRoot()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function ownTreeHit()
	local name = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	local plot = name and plots and plots:FindFirstChild(name)
	local tree = plot and plot:FindFirstChild("Tree")
	if not tree then
		return nil
	end
	local hit = tree:FindFirstChild("Hit")
	return hit and hit.Position or tree:GetPivot().Position + Vector3.new(0, 4, 0)
end

-- ===================================================================== the orb
-- Arcs from origin to a landing spot, bounces, waits, then flies into the player.
local function orb(origin, rarity, hold)
	local hrp = myRoot()
	local color = UI.rarityColor(rarity)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(1, 1, 1) * (0.8 + rarity * 0.12)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(origin)
	p.Parent = Fx.Holder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6 + rarity
	light.Brightness = 1.5
	light.Parent = p
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.Parent = p
	-- landing spot: between the source and the player, a little to the side
	local toward = hrp and (hrp.Position - origin) * Vector3.new(1, 0, 1) or Vector3.new(1, 0, 0)
	if toward.Magnitude < 0.1 then
		toward = Vector3.new(1, 0, 0)
	end
	local side = Vector3.new(-toward.Unit.Z, 0, toward.Unit.X) * (math.random() * 8 - 4)
	local groundY = (hrp and hrp.Position.Y - 2.6) or origin.Y - 3.5
	local land = Vector3.new(origin.X, groundY, origin.Z) + toward.Unit * math.min(toward.Magnitude * 0.55, 9) + side + Vector3.new(0, p.Size.Y / 2, 0)
	local t0 = os.clock()
	local dur = 0.55
	local peak = 7 + rarity
	local landed = false
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = (os.clock() - t0) / dur
		if t >= 1 then
			conn:Disconnect()
			p.CFrame = CFrame.new(land)
			landed = true
			return
		end
		local pos = origin:Lerp(land, t) + Vector3.new(0, math.sin(t * math.pi) * peak, 0)
		p.CFrame = CFrame.new(pos)
	end)
	while not landed do
		task.wait()
	end
	Fx.burst(land, { Texture = "Glow", Color = color, Count = 6 + rarity * 2, Speed = { 4, 10 }, Size = 0.6, Light = 1, Lifetime = { 0.3, 0.6 }, Gravity = Vector3.zero })
	-- a small bounce while it sits
	TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Bounce), { CFrame = CFrame.new(land + Vector3.new(0, 0.6, 0)) }):Play()
	task.wait(hold)
	-- magnet into the player
	local start = p.Position
	local t1 = os.clock()
	while p.Parent do
		local r = myRoot()
		local tt = math.clamp((os.clock() - t1) / 0.35, 0, 1)
		local target = r and r.Position or start
		p.CFrame = CFrame.new(start:Lerp(target, tt * tt) + Vector3.new(0, math.sin(tt * math.pi) * 3, 0))
		if tt >= 1 then
			break
		end
		task.wait()
	end
	p:Destroy()
	Sounds.play("Pop", 1 + rarity * 0.08, 0.6)
	return land
end

-- ===================================================================== the loot icon
-- A small round icon per notable drop (user, 2026-10-26: no big card): the item in 3D inside a circle
-- with a rarity-coloured ring and glow, and one short tag under it (EQUIPPED / +CP / Scraps). Up to
-- 3 stack on the right; each pops in, spins slowly and fades after a few seconds. Tap opens the Bag.
local gui, root = UI.screen("MystreeLoot", 15)
local stack = UI.new("Frame", { Name = "LootIcons", BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 380), AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.55, 0), Parent = root })
UI.list(stack, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
local iconOrder = 0

local function showCard(info)
	local item = info.Item
	local r = item.R
	local color = UI.rarityColor(r)
	iconOrder += 1
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(104, 118), BackgroundTransparency = 1, LayoutOrder = iconOrder, Parent = stack })
	-- soft glow behind the circle
	local glow = UI.new("Frame", { Size = UDim2.fromOffset(104, 104), BackgroundColor3 = color, BackgroundTransparency = 0.55, Parent = holder })
	UI.corner(52, glow)
	local circle = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(88, 88), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(52, 52), BackgroundColor3 = T.Panel, Parent = holder })
	UI.corner(44, circle)
	UI.gradient(circle, color:Lerp(T.Panel, 0.55), T.Panel)
	UI.stroke(circle, color, 4)
	local vp = UI.new("ViewportFrame", { Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -1.4, -1), Parent = circle })
	UI.corner(40, vp)
	local cam = UI.setModel(vp, Assets.Gear(item), 30, -12, 0.85)
	local tag
	local set = item.Set and Config.ArmorSets[item.Set]
	if set and not info.Equipped and not info.Dismantled then
		tag = set.Name .. " set"
	elseif info.Equipped then
		tag = "EQUIPPED"
	elseif info.Dismantled then
		tag = "+" .. Format.Num(info.Scraps or 0) .. " Peaches"
	elseif State.Inventory[item.Id] then
		local d = State.cpDelta(item)
		tag = d > 0 and ("+" .. Format.Commas(d) .. " Power") or "In bag"
	end
	UI.text({ Text = tag or "", Size = UDim2.new(1, 20, 0, 22), Position = UDim2.fromOffset(-10, 98), TextSize = 17, Weight = Enum.FontWeight.Heavy,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35), Parent = holder })
	circle.Activated:Connect(function()
		if C.Bag then
			C.Bag.open("Inventory")
		end
	end)
	UI.bounce(circle)
	UI.popIn(holder, 0.3)
	-- keep at most 3
	local icons = {}
	for _, ch in ipairs(stack:GetChildren()) do
		if ch:IsA("Frame") then
			table.insert(icons, ch)
		end
	end
	table.sort(icons, function(x, y)
		return x.LayoutOrder < y.LayoutOrder
	end)
	for i = 1, #icons - 3 do
		icons[i]:Destroy()
	end
	if set then
		-- set pieces: a second ring in the set colour
		local ring = UI.new("Frame", { Size = UDim2.fromOffset(98, 98), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(52, 52),
			BackgroundTransparency = 1, Parent = holder })
		UI.corner(49, ring)
		UI.stroke(ring, set.Color, 2.5)
	end
	-- slow spin + pulsing glow while it's up
	local center
	if cam then
		local model = vp:FindFirstChildOfClass("Model")
		center = model and model:GetBoundingBox().Position or Vector3.zero
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		if cam then
			local offset = cam.CFrame.Position - center
			cam.CFrame = CFrame.lookAt(center + CFrame.Angles(0, dt * 1.2, 0) * offset, center)
		end
		glow.BackgroundTransparency = 0.5 + 0.2 * math.sin((os.clock() - t0) * 5)
	end)
	task.delay(r >= 5 and 5 or 3.5, function()
		if holder.Parent then
			UI.popOut(holder, function()
				holder:Destroy()
			end)
		end
	end)
end

-- A relic's icon in the same stack: its icon in a circle in the relic colour, its name under it
local function showRelicCard(key)
	local def = Config.Materials[key]
	iconOrder += 1
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(104, 118), BackgroundTransparency = 1, LayoutOrder = iconOrder, Parent = stack })
	local glow = UI.new("Frame", { Size = UDim2.fromOffset(104, 104), BackgroundColor3 = def.Color, BackgroundTransparency = 0.45, Parent = holder })
	UI.corner(52, glow)
	local circle = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(88, 88), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(52, 52), BackgroundColor3 = T.Panel, Parent = holder })
	UI.corner(44, circle)
	UI.gradient(circle, def.Color:Lerp(T.Panel, 0.4), T.Panel)
	UI.stroke(circle, T.Gold, 4)
	UI.icon(circle, key, 64, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	UI.text({ Text = def.Name, Size = UDim2.new(1, 20, 0, 22), Position = UDim2.fromOffset(-10, 98), TextSize = 17, Weight = Enum.FontWeight.Heavy,
		TextColor3 = def.Color:Lerp(Color3.new(1, 1, 1), 0.35), Parent = holder })
	circle.Activated:Connect(function()
		if C.Forge then
			C.Forge.open("Mythforge")
		end
	end)
	UI.bounce(circle)
	UI.popIn(holder, 0.3)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		glow.BackgroundTransparency = 0.4 + 0.25 * math.sin((os.clock() - t0) * 6)
	end)
	task.delay(7, function()
		if holder.Parent then
			UI.popOut(holder, function()
				holder:Destroy()
			end)
		end
	end)
end

-- the loudest moment in the game: a relic from a Mythic beast
local function relicMoment(origin, key)
	local def = Config.Materials[key]
	local hrp = myRoot()
	local spot = hrp and Vector3.new(origin.X, hrp.Position.Y - 2.6, origin.Z):Lerp(Vector3.new(hrp.Position.X, hrp.Position.Y - 2.6, hrp.Position.Z), 0.5) or origin
	Fx.beam(spot, def.Color, 120, 6)
	Fx.beam(spot, T.Gold, 80, 5)
	Fx.ring(spot, def.Color, 40, 0.8)
	task.delay(0.15, Fx.ring, spot, T.Gold, 26, 0.6)
	Fx.burst(spot + Vector3.new(0, 2, 0), { Texture = "Glow", Color = def.Color, Color2 = T.Gold, Count = 50, Speed = { 12, 32 }, Size = 1.2, Light = 1,
		Lifetime = { 0.8, 1.6 }, Gravity = Vector3.new(0, -6, 0), Spread = 180 })
	Fx.flash(def.Color, 0.6, 0.6)
	Fx.shake(3, 0.7)
	Fx.punch(8)
	Sounds.play("Legendary")
	if C.Notify then
		C.Notify.moment("RELIC!", def.Name, def.Color)
	end
	showRelicCard(key)
end

-- ===================================================================== drops
local function lucky(pos, l)
	if l.Kind == "Chip" then
		Sounds.play("Coin", 1.1)
		Fx.float(pos + Vector3.new(0, 3, 0), "Lucky Chip! +" .. Format.Num(l.Amount) .. " Peaches", { Color = T.Gold, Size = 30, Rise = 6, Time = 1.6 })
		Fx.burst(pos, { Texture = "Square", Color = T.Gold, Count = 18, Speed = { 10, 22 }, Size = 0.4, Light = 0.4, Lifetime = { 0.6, 1 } })
	end
end

local LOOT_COLORS = {
	Exp = Color3.fromRGB(255, 220, 120), Scraps = Color3.fromRGB(230, 170, 100), Peaches = Color3.fromRGB(255, 160, 140),
	Spirit = Color3.fromRGB(110, 210, 240), MountShards = Color3.fromRGB(200, 160, 255),
}

local function onDrop(info)
	local origin = info.Pos or ownTreeHit() or (myRoot() and myRoot().Position) or Vector3.zero
	-- mob loot numbers
	if info.Loot then
		local y = 4
		for k, n in pairs(info.Loot) do
			local name = (k == "Exp" and "EXP") or (Config.Currencies[k] and Config.Currencies[k].Name) or (Config.Materials[k] and Config.Materials[k].Name) or k
			local color = LOOT_COLORS[k] or (Config.Materials[k] and Config.Materials[k].Color) or T.White
			task.delay(y * 0.03, function()
				Fx.float(origin + Vector3.new(0, y, 0), "+" .. Format.Num(n) .. " " .. name, { Color = color, Size = 24, Rise = 5, Time = 1.4 })
			end)
			y += 1.6
		end
		if info.Loot.Scraps then
			Sounds.play("Coin", 1.3, 0.6)
		end
		-- forge materials and relics
		for k in pairs(info.Loot) do
			local def = Config.Materials[k]
			if def and def.Kind == "Relic" then
				task.delay(0.4, relicMoment, origin, k)
			elseif def and k == "StarShard" then
				Fx.burst(origin + Vector3.new(0, 3, 0), { Texture = "Glow", Color = def.Color, Count = 18, Speed = { 6, 14 }, Size = 0.8, Light = 1,
					Lifetime = { 0.6, 1 }, Gravity = Vector3.new(0, 6, 0), Spread = 120 })
				Sounds.play("Epic", 1.1, 0.7)
			end
		end
	end
	if not info.Item then
		return
	end
	local r = info.R or info.Item.R
	if info.Lucky then
		lucky(origin, info.Lucky)
	end
	local big = r >= Config.BeamRarity or info.Golden
	task.spawn(function()
		local land = orb(origin, r, big and 1.4 or 0.15)
		if not big and info.Dismantled and (info.Scraps or 0) > 0 then
			Fx.float(land + Vector3.new(0, 2, 0), "+" .. Format.Num(info.Scraps) .. " Peaches", { Color = Color3.fromRGB(230, 200, 150), Size = 20, Rise = 3, Time = 0.8 })
		end
	end)
	if not big then
		-- small drops only get an icon when they were an upgrade you now wear
		if info.Equipped then
			task.delay(0.6, showCard, info)
		end
		return
	end
	-- the big moment
	task.delay(0.5, function()
		local color = info.Golden and T.Gold or UI.rarityColor(r)
		local hrp = myRoot()
		local spot = hrp and Vector3.new(origin.X, hrp.Position.Y - 2.6, origin.Z):Lerp(Vector3.new(hrp.Position.X, hrp.Position.Y - 2.6, hrp.Position.Z), 0.5) or origin
		Fx.beam(spot, color, 30 + r * 8, 2.5 + r * 0.3)
		Fx.ring(spot, color, 10 + r * 3, 0.6)
		Sounds.play(RARITY_SOUND[r] or "Rare")
		Fx.float(spot + Vector3.new(0, 6, 0), Rules.itemName(info.Item), { Color = color, Size = 30 + r * 2, Rise = 4, Time = 2 })
		if r >= 4 or info.Golden then
			Fx.flash(color, 0.75, 0.4)
			Fx.shake(1.5 + (r - 4) * 0.8, 0.45)
			Fx.burst(spot + Vector3.new(0, 2, 0), { Texture = "Glow", Color = color, Count = 30, Speed = { 10, 26 }, Size = 0.9, Light = 1, Lifetime = { 0.6, 1.2 }, Gravity = Vector3.new(0, -10, 0) })
		end
		local set = info.Item.Set and Config.ArmorSets[info.Item.Set]
		if set then
			Fx.ring(spot, set.Color, 18 + r * 3, 0.7)
			if C.Notify then
				C.Notify.moment("SET PIECE!", Rules.itemName(info.Item), set.Color)
			end
		elseif r >= 5 or info.Golden then
			Fx.punch(6)
			if C.Notify then
				C.Notify.moment(info.Golden and "GOLDEN BOUGH!" or (string.upper(Config.Rarities[r].Name) .. "!"), Rules.itemName(info.Item), color)
			end
		end
		showCard(info)
	end)
end

function Loot.Start(c)
	C = c
	Net.get("Drop").OnClientEvent:Connect(onDrop)
	-- bag full warnings come with the drop
	Net.get("Drop").OnClientEvent:Connect(function(info)
		if info.BagFull then
			C.Notify.toast("Your bag is full, so that drop was dismantled. Open the Bag to clear space.", "Error")
		end
	end)
end

Loot.showCard = showCard
Loot.showRelicCard = showRelicCard

return Loot
