-- StarterPlayerScripts/MystreeClient/SummonFx (ModuleScript)
-- The spirit summon reveal, in the style of Sol's RNG (user, 2026-10-26):
--  1. ROLL: a slot in the middle of a dimmed screen flicks through spirit names in their rarity
--     colours, fast at first and slowing down, each tick a click that rises in pitch; it lands on
--     the result. Tap to skip the roll.
--  2. REVEAL, louder the rarer it is:
--     Rare      quick colour flash, the card pops in, a small spark burst.
--     Epic      darker screen, slow purple rays, a bigger burst, a shake.
--     Legendary suspense (the screen goes black, a heartbeat), a light pillar sweeps up, the title
--               types in letter by letter, fast gold rays, a big burst, a hard shake.
--     Mythic    longer suspense (three heartbeats, the screen pulses), the sky tints red, shockwave
--               rings, a glitching title, plus everything above.
--     Divine    all of it in shifting rainbow colours with a white-out flash.
--  3. The card shows the spirit in 3D, its name, rarity and "1 in N" odds. x10 shows the best pull's
--     cinematic, then all ten cards. Tap (or wait) to close.
-- Rare pulls also light a beam over the summoner that everyone nearby sees (Effect "SummonBeam").

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local SummonFx = {}
local T = UI.T
local player = Players.LocalPlayer

local function rc(r)
	return UI.rarityColor(r)
end

-- ===================================================================== odds
local byRarity = {}
for id, def in pairs(Config.Companions) do
	byRarity[def.Rarity] = byRarity[def.Rarity] or {}
	table.insert(byRarity[def.Rarity], id)
end

-- "1 in N" for this exact spirit (its rarity's odds split across that rarity's spirits)
function SummonFx.oneIn(id)
	local def = Config.Companions[id]
	local total = 0
	for _, w in pairs(Config.SummonOdds) do
		total += w
	end
	local p = (Config.SummonOdds[def.Rarity] or 0) / total / #byRarity[def.Rarity]
	return p > 0 and math.floor(1 / p + 0.5) or 0
end

local function randomSpirit(rng)
	local total = 0
	for _, w in pairs(Config.SummonOdds) do
		total += w
	end
	local roll = rng:NextNumber() * total
	for r, w in pairs(Config.SummonOdds) do
		roll -= w
		if roll <= 0 then
			local list = byRarity[r]
			return list[rng:NextInteger(1, #list)]
		end
	end
	return "FoxSpirit"
end

-- ===================================================================== the stage
local gui, root = UI.screen("MystreeSummon", 35, true)
gui.Enabled = false
local shade = UI.new("Frame", { Name = "Shade", Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1.5, -1.5), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, Active = true, Parent = root })
local center = UI.new("Frame", { Name = "Center", Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
	BackgroundTransparency = 1, Parent = root })

-- rotating light rays behind the card
local rays = UI.new("Frame", { Name = "Rays", Size = UDim2.fromOffset(1000, 1000), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, Parent = center })
local rayParts = {}
for i = 1, 14 do
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(2, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1,
		Rotation = i * (360 / 14), Parent = rays })
	local ray = UI.new("Frame", { Size = UDim2.fromOffset(70 + (i % 3) * 30, 520), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(1, 0),
		BackgroundColor3 = T.White, BackgroundTransparency = 0, Parent = holder })
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 0.25) }), Parent = ray })
	table.insert(rayParts, ray)
end
-- soft glow discs
local glow = UI.new("Frame", { Size = UDim2.fromOffset(420, 420), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = T.White,
	BackgroundTransparency = 1, Parent = center })
-- scale-based corners keep the glows round at any size they tween to
UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = glow })
local glow2 = UI.new("Frame", { Size = UDim2.fromOffset(260, 260), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = T.White,
	BackgroundTransparency = 1, Parent = center })
UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = glow2 })
for _, g in ipairs({ glow, glow2 }) do
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.7) }), Parent = g })
end
-- the light pillar (Legendary+)
local pillar = UI.new("Frame", { Size = UDim2.fromOffset(120, 0), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 900), BackgroundColor3 = T.White,
	BackgroundTransparency = 1, Parent = center })
UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }), Parent = pillar })

-- the roll slot
local slot = UI.new("Frame", { Name = "Slot", Size = UDim2.fromOffset(560, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, Parent = center })
local slotName = UI.text({ Text = "", Size = UDim2.fromScale(1, 0.7), TextSize = 56, Weight = Enum.FontWeight.Heavy, Italic = true, StrokeThickness = 3, Parent = slot })
local slotScale = UI.new("UIScale", { Parent = slotName })
local slotSub = UI.text({ Text = "", Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.7), TextSize = 24, Weight = Enum.FontWeight.Heavy, Parent = slot })
local rollingLabel = UI.text({ Text = "SUMMONING...", Size = UDim2.fromOffset(400, 30), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -90),
	TextSize = 22, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Cream, Parent = center })

-- the big title (Legendary+), with two offset copies for the Mythic glitch
local title = UI.text({ Text = "", Size = UDim2.fromOffset(900, 110), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -250), TextSize = 96,
	Weight = Enum.FontWeight.Heavy, Italic = true, StrokeThickness = 4, Parent = center })
local titleScale = UI.new("UIScale", { Parent = title })
local ghostA = UI.text({ Text = "", Size = title.Size, AnchorPoint = title.AnchorPoint, Position = title.Position, TextSize = 96, Weight = Enum.FontWeight.Heavy, Italic = true,
	TextColor3 = Color3.fromRGB(255, 60, 80), TextTransparency = 1, Stroke = false, Parent = center })
local ghostB = UI.text({ Text = "", Size = title.Size, AnchorPoint = title.AnchorPoint, Position = title.Position, TextSize = 96, Weight = Enum.FontWeight.Heavy, Italic = true,
	TextColor3 = Color3.fromRGB(60, 220, 255), TextTransparency = 1, Stroke = false, Parent = center })

-- the result card
local card = UI.new("Frame", { Name = "Card", Size = UDim2.fromOffset(340, 420), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = T.Panel, Visible = false, Parent = center })
UI.corner(18, card)
local cardStroke = UI.stroke(card, T.White, 4)
local cardGrad = UI.gradient(card, T.Panel2, T.Panel)
local cardScale = UI.new("UIScale", { Parent = card })
local cardVp = UI.new("ViewportFrame", { Size = UDim2.fromOffset(300, 250), Position = UDim2.fromOffset(20, 16), BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(180, 180, 180), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -1.4, -1), Parent = card })
local cardName = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 272), TextSize = 34, Weight = Enum.FontWeight.Heavy, Parent = card })
local cardRarity = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 316), TextSize = 24, Weight = Enum.FontWeight.Heavy, Italic = true, Parent = card })
local cardOdds = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 346), TextSize = 20, Weight = Enum.FontWeight.Bold, TextColor3 = T.TextLight, Parent = card })
local cardTag = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 378), TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Gold, Parent = card })

-- x10 results grid
local grid = UI.new("Frame", { Name = "Grid", Size = UDim2.fromOffset(820, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	BackgroundTransparency = 1, Visible = false, Parent = root })
UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 140), CellPadding = UDim2.fromOffset(14, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
local hint = UI.text({ Text = "", Size = UDim2.fromOffset(500, 30), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), TextSize = 20,
	Weight = Enum.FontWeight.Bold, TextColor3 = T.TextLight, Parent = root })

-- a separate grade for the sky tint (Mythic+), so it never fights WorldFx's
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "MystreeSummonGrade"
grade.Parent = Lighting

-- ===================================================================== small helpers
local tapped = false
shade.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		tapped = true
	end
end)

local function waitOrTap(seconds)
	local t0 = os.clock()
	tapped = false
	while os.clock() - t0 < seconds and not tapped do
		RunService.Heartbeat:Wait()
	end
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function setRayColor(color, alpha)
	for _, r in ipairs(rayParts) do
		r.BackgroundColor3 = color
	end
	for _, r in ipairs(rayParts) do
		tween(r, 0.4, { BackgroundTransparency = alpha })
	end
end

-- UI sparks flying out from the centre
local function sparks(color, count, speed)
	for i = 1, count do
		local s = UI.new("Frame", { Size = UDim2.fromOffset(math.random(6, 14), math.random(6, 14)), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Rotation = math.random(0, 90), BackgroundColor3 = color:Lerp(T.White, math.random() * 0.5), Parent = center })
		UI.corner(3, s)
		local a = math.random() * math.pi * 2
		local d = (speed or 1) * math.random(180, 460)
		tween(s, 0.9 + math.random() * 0.6, { Position = UDim2.new(0.5, math.cos(a) * d, 0.5, math.sin(a) * d), Rotation = s.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2) }, Enum.EasingStyle.Quint)
		task.delay(1.6, function()
			s:Destroy()
		end)
	end
end

-- an expanding ring (shockwave)
local function ring(color, size)
	local r = UI.new("Frame", { Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = center })
	UI.corner(999, r)
	local st = UI.stroke(r, color, 10)
	tween(r, 0.7, { Size = UDim2.fromOffset(size or 900, size or 900) }, Enum.EasingStyle.Quint)
	tween(st, 0.7, { Transparency = 1, Thickness = 1 })
	task.delay(0.8, function()
		r:Destroy()
	end)
end

-- type the title letter by letter, each letter punching in
local function typeTitle(text, color)
	title.TextColor3 = color
	title.Text = ""
	title.TextTransparency = 0
	for i = 1, #text do
		title.Text = string.sub(text, 1, i)
		titleScale.Scale = 1.25
		tween(titleScale, 0.12, { Scale = 1 })
		Sounds.play("Click", 0.8 + i * 0.05, 0.7)
		task.wait(0.06)
	end
end

-- rainbow cycling for Divine
local rainbowConn
local function rainbow(on)
	if rainbowConn then
		rainbowConn:Disconnect()
		rainbowConn = nil
	end
	if on then
		rainbowConn = RunService.Heartbeat:Connect(function()
			local c = Color3.fromHSV((os.clock() * 0.35) % 1, 0.55, 1)
			for _, r in ipairs(rayParts) do
				r.BackgroundColor3 = c
			end
			title.TextColor3 = c
			cardStroke.Color = c
			glow.BackgroundColor3 = c
		end)
	end
end

local spin
local function spinRays(speed)
	if spin then
		spin:Disconnect()
	end
	spin = RunService.Heartbeat:Connect(function(dt)
		rays.Rotation = (rays.Rotation + dt * speed) % 360
	end)
end

-- ===================================================================== phases
local function roll(final, ticks)
	local rng = Random.new()
	slot.Visible = true
	rollingLabel.Visible = true
	rollingLabel.TextTransparency = 0
	tapped = false
	for i = 1, ticks do
		local id = (i == ticks) and final or randomSpirit(rng)
		local def = Config.Companions[id]
		slotName.Text = def.Name
		slotName.TextColor3 = rc(def.Rarity):Lerp(T.White, 0.15)
		slotSub.Text = Config.Rarities[def.Rarity].Name
		slotSub.TextColor3 = rc(def.Rarity)
		slotScale.Scale = 1.15
		tween(slotScale, 0.1, { Scale = 1 })
		Sounds.play("Click", 0.7 + (i / ticks) * 0.9, 0.6)
		-- slows down toward the end; tapping skips to the last tick
		local t = i / ticks
		local delay = 0.04 + 0.30 * t * t * t
		if tapped and i < ticks - 1 then
			delay = 0
		end
		if delay > 0 then
			task.wait(delay)
		end
	end
	tween(rollingLabel, 0.2, { TextTransparency = 1 })
end

local function suspense(beats)
	tween(shade, 0.25, { BackgroundTransparency = 0.02 })
	slot.Visible = false
	for b = 1, beats do
		Sounds.play("Quake", 0.6 + b * 0.1, 0.8)
		Fx.shake(0.6 + b * 0.4, 0.3)
		glow.BackgroundTransparency = 0.6
		glow.Size = UDim2.fromOffset(160, 160)
		tween(glow, 0.45, { Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1 })
		task.wait(0.55)
	end
end

local function showCard(res)
	local def = Config.Companions[res.Id]
	local color = rc(def.Rarity)
	card.Visible = true
	cardStroke.Color = color
	cardGrad.Color = ColorSequence.new(color:Lerp(T.Panel, 0.55), T.Panel)
	cardName.Text = def.Name
	cardName.TextColor3 = color:Lerp(T.White, 0.2)
	cardRarity.Text = string.upper(Config.Rarities[def.Rarity].Name)
	cardRarity.TextColor3 = color
	cardOdds.Text = "1 in " .. Format.Commas(SummonFx.oneIn(res.Id))
	cardTag.Text = res.New and "NEW!" or (res.Refund and ("Max stars: +" .. res.Refund .. " Spirit Stones") or ("+1 star  (" .. (res.Stars or 1) .. "/" .. Config.CompanionStars.Max .. ")"))
	local cam = UI.setModel(cardVp, Assets.Companion(res.Id), 25, -10, 0.9)
	cardScale.Scale = 0.3
	tween(cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	-- the spirit turns slowly in its card
	if cam then
		local model = cardVp:FindFirstChildOfClass("Model")
		local c = model and model:GetBoundingBox().Position or Vector3.zero
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not card.Visible or not cam.Parent then
				conn:Disconnect()
				return
			end
			local off = CFrame.Angles(0, dt * 0.8, 0) * (cam.CFrame.Position - c)
			cam.CFrame = CFrame.lookAt(c + off, c)
		end)
	end
end

-- the tiered reveal for one result
local function reveal(res)
	local r = Config.Companions[res.Id].Rarity
	local color = rc(r)
	local name = Config.Rarities[r].Name
	if r >= 5 then
		suspense(r >= 6 and 3 or 1)
	end
	slot.Visible = false
	if r >= 6 then
		-- the sky turns
		grade.TintColor = Color3.new(1, 1, 1)
		tween(grade, 0.6, { TintColor = color:Lerp(Color3.new(1, 1, 1), 0.35), Saturation = 0.3 })
	end
	if r >= 5 then
		-- light pillar sweeps up, then the white flash
		pillar.BackgroundColor3 = color
		pillar.BackgroundTransparency = 0
		pillar.Size = UDim2.fromOffset(40, 0)
		tween(pillar, 0.35, { Size = UDim2.fromOffset(r >= 6 and 220 or 140, 1400) }, Enum.EasingStyle.Quint)
		Sounds.play("Thunder", 1, 0.9)
		task.wait(0.35)
		Fx.flash(r >= 7 and Color3.new(1, 1, 1) or color, r >= 7 and 0 or 0.3, 0.8)
		tween(pillar, 0.6, { BackgroundTransparency = 1 })
	end
	-- glow, rays, rings, sparks
	glow.BackgroundColor3 = color
	glow.Size = UDim2.fromOffset(200, 200)
	glow.BackgroundTransparency = 0.4
	tween(glow, 0.6, { Size = UDim2.fromOffset(r >= 5 and 760 or 460, r >= 5 and 760 or 460), BackgroundTransparency = r >= 4 and 0.75 or 0.9 })
	glow2.BackgroundColor3 = color:Lerp(T.White, 0.5)
	glow2.BackgroundTransparency = 0.5
	glow2.Size = UDim2.fromOffset(100, 100)
	tween(glow2, 0.5, { Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 0.85 })
	if r >= 4 then
		setRayColor(color, r >= 5 and 0.3 or 0.55)
		spinRays(r >= 6 and 60 or (r >= 5 and 40 or 14))
		tween(shade, 0.3, { BackgroundTransparency = r >= 5 and 0.15 or 0.3 })
	else
		setRayColor(color, 1)
		Fx.flash(color, 0.75, 0.3)
	end
	if r >= 6 then
		ring(color, 1100)
		task.delay(0.15, ring, T.White, 900)
		task.delay(0.3, ring, color, 700)
	elseif r >= 5 then
		ring(color, 900)
	end
	sparks(color, (r >= 6 and 90) or (r >= 5 and 60) or (r >= 4 and 34) or 16, r >= 5 and 1.4 or 1)
	Fx.shake((r >= 6 and 4) or (r >= 5 and 3) or (r >= 4 and 1.5) or 0.5, r >= 5 and 0.8 or 0.35)
	if r >= 7 then
		rainbow(true)
	end
	Sounds.play((r >= 5 and "Legendary") or (r >= 4 and "Epic") or "Rare", 1, 1)
	if r >= 6 then
		Sounds.play("Alert", 1.1, 0.8)
	end
	showCard(res)
	if r >= 5 then
		task.spawn(typeTitle, string.upper(name) .. "!", color)
	end
	if r >= 6 then
		-- glitching title: offset colour ghosts jitter for a moment
		task.spawn(function()
			ghostA.Text = string.upper(name) .. "!"
			ghostB.Text = ghostA.Text
			for _ = 1, 14 do
				ghostA.TextTransparency = 0.35
				ghostB.TextTransparency = 0.35
				ghostA.Position = title.Position + UDim2.fromOffset(math.random(-8, 8), math.random(-4, 4))
				ghostB.Position = title.Position + UDim2.fromOffset(math.random(-8, 8), math.random(-4, 4))
				task.wait(0.05)
			end
			ghostA.TextTransparency = 1
			ghostB.TextTransparency = 1
		end)
	end
end

local function cleanup()
	rainbow(false)
	if spin then
		spin:Disconnect()
		spin = nil
	end
	tween(grade, 0.8, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
	tween(shade, 0.25, { BackgroundTransparency = 1 })
	for _, r in ipairs(rayParts) do
		tween(r, 0.25, { BackgroundTransparency = 1 })
	end
	tween(glow, 0.25, { BackgroundTransparency = 1 })
	tween(glow2, 0.25, { BackgroundTransparency = 1 })
	tween(title, 0.25, { TextTransparency = 1 })
	tween(cardScale, 0.2, { Scale = 0.6 })
	task.wait(0.25)
	card.Visible = false
	grid.Visible = false
	hint.Text = ""
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	gui.Enabled = false
end

local function miniCard(res, order)
	local def = Config.Companions[res.Id]
	local color = rc(def.Rarity)
	local f = UI.new("Frame", { BackgroundColor3 = T.Panel, LayoutOrder = order, Parent = grid })
	UI.corner(12, f)
	UI.stroke(f, color, 3)
	UI.gradient(f, color:Lerp(T.Panel, 0.6), T.Panel)
	local vp = UI.new("ViewportFrame", { Size = UDim2.fromOffset(130, 84), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 180, 180), LightDirection = Vector3.new(-1, -1.4, -1), Parent = f })
	UI.setModel(vp, Assets.Companion(res.Id), 25, -10, 0.95)
	UI.text({ Text = def.Name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 90), TextSize = 17, Weight = Enum.FontWeight.Heavy, Scaled = true, MaxTextSize = 17,
		TextColor3 = color:Lerp(T.White, 0.25), Parent = f })
	UI.text({ Text = res.New and "NEW!" or ("+1 star"), Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 114), TextSize = 15, Weight = Enum.FontWeight.Heavy,
		TextColor3 = res.New and T.Gold or T.TextLight, Parent = f })
	UI.popIn(f, 0.5)
	if def.Rarity >= 4 then
		Sounds.play(def.Rarity >= 5 and "Legendary" or "Epic", 1.2, 0.5)
	else
		Sounds.play("Pop", 1 + order * 0.04, 0.5)
	end
end

-- ===================================================================== public
-- Plays the whole sequence for a summon's results (yields until the player closes it)
function SummonFx.play(results)
	if not results or #results == 0 then
		return
	end
	local best = results[1]
	for _, r in ipairs(results) do
		if Config.Companions[r.Id].Rarity > Config.Companions[best.Id].Rarity then
			best = r
		end
	end
	-- other pop-ups (daily gift, Starter Pack) wait while this plays
	UI.Busy = true
	gui.Enabled = true
	card.Visible = false
	grid.Visible = false
	title.TextTransparency = 1
	shade.BackgroundTransparency = 1
	tween(shade, 0.3, { BackgroundTransparency = 0.35 })
	hint.Text = "Tap to skip"
	roll(best.Id, #results > 1 and 14 or 22)
	hint.Text = ""
	reveal(best)
	task.wait(0.6)
	hint.Text = (#results > 1) and "Tap to see all ten" or "Tap to continue"
	waitOrTap(Config.Companions[best.Id].Rarity >= 5 and 6 or 3.5)
	if #results > 1 then
		-- every result as a small card
		tween(cardScale, 0.2, { Scale = 0.5 })
		task.wait(0.2)
		card.Visible = false
		tween(title, 0.2, { TextTransparency = 1 })
		grid.Visible = true
		for i, r in ipairs(results) do
			miniCard(r, i)
			task.wait(0.12)
		end
		hint.Text = "Tap to continue"
		waitOrTap(8)
	end
	cleanup()
	UI.Busy = false
end

function SummonFx.Start(C)
	-- rare pulls light a pillar over the summoner for everyone nearby
	Net.get("Effect").OnClientEvent:Connect(function(kind, userId, r, pos)
		if kind == "SummonPreview" then
			task.spawn(SummonFx.play, userId)
			return
		end
		if kind ~= "SummonBeam" or not pos then
			return
		end
		local color = rc(r)
		Fx.beam(pos - Vector3.new(0, 3, 0), color, 60 + r * 15, 4 + r * 0.5)
		Fx.ring(pos - Vector3.new(0, 3, 0), color, 30 + r * 6, 0.9)
		if userId ~= player.UserId then
			Sounds.at(r >= 6 and "Legendary" or "Epic", pos, 1, 1)
		end
	end)
end

return SummonFx
