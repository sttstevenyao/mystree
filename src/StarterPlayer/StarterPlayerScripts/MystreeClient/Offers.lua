-- StarterPlayerScripts/MystreeClient/Offers (ModuleScript)
-- Paid shortcuts offered right where the wait is (Playbook 03), each one click away:
--  * Not enough Spirit Stones to summon: the Spirit Stone shop tab (hidden where paid random items
--    are restricted, then a toast says where to earn them).
--  * Bag full: the Big Bag pass, plus "Open Bag" (the free fix).
--  * Starter Pack: one-time, for 24 h after the tutorial. A countdown pill at the top, and its card
--    opens once by itself.
--  * Death in the Hunting Grounds: "Revive Here" on the fall screen while the respawn counts down.
-- Throttled so an offer never nags: each kind shows at most once per Config window.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Odds = require(script.Parent.Odds)
local Purchase = require(script.Parent.Purchase)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Offers = {}
local C
local T = UI.T
local player = Players.LocalPlayer

local COOLDOWN = { Bag = 120 }
local lastShown = {}

-- no offers at all during the tutorial (user, 2026-10-26)
local function inTutorial()
	local i = player:GetAttribute("Tutorial")
	return i ~= nil and i <= #Config.Tutorial
end

local function ready(kind)
	if inTutorial() then
		return false
	end
	local now = os.clock()
	if lastShown[kind] and now - lastShown[kind] < (COOLDOWN[kind] or 30) then
		return false
	end
	lastShown[kind] = now
	return true
end

-- Buy a product or pass by Config key (Studio: free test grant while the Id is 0)
function Offers.buy(key)
	local ok, msg = Purchase.buy(key)
	if msg and C.Notify then
		C.Notify.toast(msg, ok and "Purchase" or "Error")
	end
end

local function robux(key)
	return Purchase.price(key)
end

-- ===================================================================== the offer sheet
-- A small card above the chop dock: title, one line, up to 3 buy buttons and one free option.
-- It hugs its content: width from the buttons, height from the wrapped line (no empty space).
local _, root = UI.screen("MystreeOffers", 22)
local sheet = UI.new("Frame", { Name = "Sheet", Size = UDim2.fromOffset(560, 200), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -190),
	BackgroundColor3 = T.Parchment, Visible = false, Parent = root })
UI.corner(12, sheet)
UI.stroke(sheet, T.Ornament, 3)
local sheetTitle = UI.text({ Text = "", Size = UDim2.new(1, -60, 0, 36), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 26,
	Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = sheet })
local sheetLine = UI.text({ Text = "", Size = UDim2.new(1, -32, 0, 26), Position = UDim2.fromOffset(16, 44), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18,
	TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = T.InkSoft, Stroke = false, Parent = sheet })
local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 72), Position = UDim2.fromOffset(12, 84), Parent = sheet })
UI.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local closeBtn = UI.new("TextButton", { Text = "X", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -50, 0, 4), BackgroundTransparency = 1,
	FontFace = UI.Heavy, TextSize = 28, TextColor3 = T.InkSoft, Parent = sheet })
local sheetGen = 0
local function hideSheet()
	if sheet.Visible then
		UI.popOut(sheet)
	end
end
closeBtn.Activated:Connect(hideSheet)

-- options: { {Text, Style, OnClick}, ... }
local function windowOpen()
	for _, w in ipairs(UI.WindowRoot:GetChildren()) do
		if w:IsA("Frame") and w.Name ~= "Backdrop" and w.Visible then
			return true
		end
	end
	return false
end

local function showSheet(title, line, options)
	-- never stack on top of an open window (the player is already looking at something)
	if windowOpen() then
		return
	end
	for _, ch in ipairs(row:GetChildren()) do
		if ch:IsA("GuiButton") then
			ch:Destroy()
		end
	end
	sheetTitle.Text = title
	sheetLine.Text = line
	local buttonsW = (#options - 1) * 10
	for _, o in ipairs(options) do
		buttonsW += o[4] or 160
	end
	local w = math.clamp(buttonsW + 40, 420, 640)
	local lineH = 22 * math.max(1, math.ceil(UI.textWidth(line, 18) / (w - 32)))
	sheetLine.Size = UDim2.new(1, -32, 0, lineH)
	row.Position = UDim2.fromOffset(12, 50 + lineH)
	sheet.Size = UDim2.fromOffset(w, 50 + lineH + 72 + 14)
	for i, o in ipairs(options) do
		UI.button({ Text = o[1], Style = o[2], Size = UDim2.fromOffset(o[4] or 160, 72), TextSize = 19, LayoutOrder = i, Parent = row, OnClick = function()
			hideSheet()
			o[3]()
		end })
	end
	sheetGen += 1
	local gen = sheetGen
	UI.popIn(sheet, 0.7)
	Sounds.play("Pop", 0.9, 0.6)
	task.delay(10, function()
		if sheetGen == gen then
			hideSheet()
		end
	end)
end

function Offers.spirit()
	if inTutorial() then
		return
	end
	if player:GetAttribute("NoPaidRandom") then
		if C.Notify then
			C.Notify.toast("Spirit Stones come from quests, bosses and daily gifts.", "Info")
		end
		return
	end
	if C.Shop then
		C.Shop.open("Spirit Stones")
	end
end

function Offers.bagFull()
	if not ready("Bag") or State.attr("Pass_BigBag", false) then
		return
	end
	showSheet("Your bag is full", "New drops are being dismantled. Clear some space, or get more room for good.", {
		{ "Big Bag +" .. Config.BigBagExtra .. "\n" .. robux("BigBag"), "Purple", function()
			Offers.buy("BigBag")
		end, 200 },
		{ "Open Bag", "Green", function()
			if C.Bag then
				C.Bag.open("Inventory")
			end
		end, 160 },
	})
end

-- ===================================================================== Starter Pack (24 h after the tutorial)
local starterPill = UI.button({ Name = "StarterPack", Text = "", Style = "Purple", Size = UDim2.fromOffset(220, 46), AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -324, 0, 56), TextSize = 18, Parent = root })
starterPill.Visible = false
-- The Starter Pack is a featured banner (user: "an actual banner like the vault references", Playbook
-- 17 shop banners): a gold filigree frame around a moonlit mountain scene, the hero chest bursting
-- out on the left over a turning sunburst, a tilted ONE TIME! tag, a shimmering title, a big live
-- countdown, every reward as an icon card, and a big price. One Heartbeat loop animates it, only
-- while the banner is open.
local GOLD = Color3.fromRGB(240, 196, 90)
local banner = {}
local starterCard = UI.window({ Title = "Starter Pack", Size = Vector2.new(780, 470),
	OnOpen = function()
		banner.start()
	end,
	OnClose = function()
		banner.stop()
	end })
do
	local b = starterCard.Body
	local p = Config.Products.StarterPack
	local frame = UI.new("Frame", { Name = "Banner", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = b })
	UI.corner(6, frame)
	UI.gradient(frame, Color3.fromRGB(34, 52, 74), Color3.fromRGB(16, 26, 36))
	UI.stroke(frame, GOLD, 3)
	-- scene: a moon and three layers of mountain silhouettes
	-- the moon rises behind the mountains bottom-right, clear of the title and countdown
	local moon = UI.new("Frame", { Size = UDim2.fromOffset(130, 130), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -40), BackgroundColor3 = Color3.fromRGB(250, 238, 200),
		BackgroundTransparency = 0.25, Parent = frame })
	UI.corner(60, moon)
	UI.new("UIGradient", { Transparency = NumberSequence.new(0, 0.6), Rotation = 45, Parent = moon })
	for layer, c in ipairs({ Color3.fromRGB(30, 50, 62), Color3.fromRGB(22, 38, 46), Color3.fromRGB(14, 26, 30) }) do
		for k = 0, 4 do
			local w = 260 + (k % 2) * 80
			local h = 70 + layer * 26 + (k % 3) * 18
			UI.new("Frame", { Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(k / 4, (layer - 2) * 50, 1, 20 - (3 - layer) * 30),
				Rotation = 45, BackgroundColor3 = c, BorderSizePixel = 0, Parent = frame })
		end
	end
	-- gold filigree corners: two bars and a diamond at each corner
	for _, cx in ipairs({ 0, 1 }) do
		for _, cy in ipairs({ 0, 1 }) do
			local holder = UI.new("Frame", { Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(cx, cy), Position = UDim2.new(cx, cx == 0 and 6 or -6, cy, cy == 0 and 6 or -6),
				BackgroundTransparency = 1, ZIndex = 6, Parent = frame })
			UI.new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, cy, cy == 0 and 0 or -3), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 6, Parent = holder })
			UI.new("Frame", { Size = UDim2.new(0, 3, 1, 0), Position = UDim2.new(cx, cx == 0 and 0 or -3, 0, 0), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 6, Parent = holder })
			UI.new("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(cx, cx == 0 and 1 or -1, cy, cy == 0 and 1 or -1),
				Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 6, Parent = holder })
		end
	end
	-- sunburst behind the hero
	local burst = UI.new("Frame", { Size = UDim2.fromOffset(300, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 150, 0.42, 0), BackgroundTransparency = 1, Parent = frame })
	for k = 0, 11 do
		local ray = UI.new("Frame", { Size = UDim2.fromOffset(26, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = k * 15,
			BackgroundColor3 = GOLD, BorderSizePixel = 0, Parent = burst })
		UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.65), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = ray })
	end
	local hero = UI.icon(frame, "starter", 190, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 150, 0.42, 0), ZIndex = 3 })
	-- tag, title, countdown
	local tag = UI.new("Frame", { Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(300, 26), Rotation = -6, BackgroundColor3 = T.Red, ZIndex = 4, Parent = frame })
	UI.corner(4, tag)
	UI.stroke(tag, Color3.fromRGB(110, 20, 16), 1.5)
	UI.text({ Text = "ONE TIME!", Size = UDim2.fromScale(1, 1), TextSize = 22, Weight = Enum.FontWeight.Bold, ZIndex = 5, Parent = tag })
	local title = UI.text({ Text = "STARTER PACK", Size = UDim2.fromOffset(440, 54), Position = UDim2.fromOffset(300, 70), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 44, TextColor3 = GOLD, Stroke = Color3.fromRGB(60, 36, 10), StrokeThickness = 1.4, ZIndex = 4, Parent = frame })
	title.FontFace = UI.Serif
	local shimmer = UI.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 230)), ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }), Parent = title })
	UI.text({ Text = "Everything you need for your first hunts, once.", Size = UDim2.fromOffset(440, 22), Position = UDim2.fromOffset(302, 122), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16, TextColor3 = T.TextLight, Stroke = false, ZIndex = 4, Parent = frame })
	UI.text({ Text = "ENDS IN", Size = UDim2.fromOffset(180, 18), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 22), TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 14, Weight = Enum.FontWeight.Bold, TextColor3 = T.TextLight, Stroke = false, ZIndex = 4, Parent = frame })
	starterCard.Timer = UI.text({ Text = "", Size = UDim2.fromOffset(200, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 38), TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 34, Weight = Enum.FontWeight.Bold, ZIndex = 4, Parent = frame })
	-- rewards: icon cards
	local rewards = {
		{ "peach", "x" .. Format.Num(p.Grant.Scraps or 0), "Peaches", Color3.fromRGB(255, 160, 140) },
		{ "spirit_stone", "x" .. p.Grant.Spirit, "Spirit Stones", Color3.fromRGB(110, 210, 240) },
		{ "cp", Config.Rarities[p.Weapon].Name .. "+", "Weapon", UI.rarityColor(p.Weapon) },
	}
	local row = UI.new("Frame", { Size = UDim2.fromOffset(440, 130), Position = UDim2.fromOffset(300, 156), BackgroundTransparency = 1, ZIndex = 4, Parent = frame })
	UI.list(row, Enum.FillDirection.Horizontal, 10)
	local cards = {}
	for i, r in ipairs(rewards) do
		local card = UI.new("Frame", { Size = UDim2.fromOffset(102, 124), BackgroundColor3 = Color3.fromRGB(20, 32, 40), BackgroundTransparency = 0.1, LayoutOrder = i, ZIndex = 4, Parent = row })
		UI.corner(5, card)
		UI.stroke(card, r[4], 1.5)
		UI.new("UIGradient", { Color = ColorSequence.new(r[4]:Lerp(Color3.new(0, 0, 0), 0.55), Color3.fromRGB(16, 24, 30)), Rotation = 90, Parent = card })
		UI.icon(card, r[1], 60, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), ZIndex = 5 })
		UI.text({ Text = r[2], Size = UDim2.new(1, -6, 0, 24), Position = UDim2.fromOffset(3, 70), TextSize = 20, Weight = Enum.FontWeight.Bold, TextColor3 = r[4]:Lerp(Color3.new(1, 1, 1), 0.35), ZIndex = 5, Parent = card })
		UI.text({ Text = r[3], Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 96), TextSize = 13, TextColor3 = T.TextLight, Stroke = false, ZIndex = 5, Parent = card })
		cards[i] = card
	end
	local buy = UI.button({ Text = "Get it  " .. robux("StarterPack"), Style = "Purple", Size = UDim2.fromOffset(268, 62), AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 300, 1, -22), TextSize = 26, Parent = frame, OnClick = function()
			Offers.buy("StarterPack")
		end })
	buy.ZIndex = 6
	Purchase.label(buy, "StarterPack", "Get it  R$%s")
	-- the weapon is random: its rarity odds, one tap away
	local oddsBtn = UI.button({ Text = "Weapon odds", Style = "Teal", Size = UDim2.fromOffset(140, 62), AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 578, 1, -22), TextSize = 18, Parent = frame, OnClick = function()
			Odds.gear("Starter Pack weapon odds", { Min = p.Weapon, Item = "Weapon" }, starterCard)
		end })
	oddsBtn.ZIndex = 6
	-- a light sweep across the whole banner every few seconds
	local sweep = UI.new("Frame", { Size = UDim2.new(0, 120, 1.6, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.2, 0, 0.5, 0), Rotation = 20,
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7, Parent = frame })
	UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1) }), Parent = sweep })
	-- star glints drifting up over the scene
	local glints = {}
	for k = 1, 10 do
		local g = UI.icon(frame, "star", 14, { AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 0.3, ZIndex = 5 })
		glints[k] = { Img = g, X = math.random(), Phase = math.random() * 10, Speed = 0.04 + math.random() * 0.05 }
	end
	local conn
	function banner.start()
		if conn then
			return
		end
		local t0 = os.clock()
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			burst.Rotation = t * 12
			hero.Position = UDim2.new(0, 150, 0.42, math.sin(t * 2) * 6)
			local ts = tag:FindFirstChild("PopScale") or UI.new("UIScale", { Name = "PopScale", Parent = tag })
			ts.Scale = 1 + 0.05 * math.max(0, math.sin(t * 5))
			shimmer.Offset = Vector2.new(((t * 0.5) % 2) - 1, 0)
			sweep.Position = UDim2.new(((t % 4) / 4) * 1.6 - 0.3, 0, 0.5, 0)
			-- the reward cards breathe (their layout owns Position, so this scales them)
			for i, card in ipairs(cards) do
				local cs = card:FindFirstChild("PopScale") or UI.new("UIScale", { Name = "PopScale", Parent = card })
				cs.Scale = 1 + 0.025 * math.sin(t * 2.2 + i)
			end
			for _, g in ipairs(glints) do
				local y = 1 - ((t * g.Speed + g.Phase) % 1)
				g.Img.Position = UDim2.fromScale(g.X, y)
				g.Img.ImageTransparency = 0.2 + 0.7 * (1 - math.sin(y * math.pi))
				g.Img.Rotation = t * 40
			end
		end)
	end
	function banner.stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end
end
starterPill.Activated:Connect(function()
	starterCard.open()
end)

local function starterLeft()
	local o = State.Offers or {}
	-- (it holds a random weapon and Spirit Stones: never offered where paid random items are restricted)
	if (o.StarterAt or 0) == 0 or o.StarterBought or player:GetAttribute("NoPaidRandom") ~= false then
		return 0
	end
	return o.StarterAt + Config.Products.StarterPack.Hours * 3600 - os.time()
end

-- ===================================================================== the fall screen (Revive Here)
local fall = UI.new("Frame", { Name = "Fall", Size = UDim2.fromOffset(520, 220), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
	BackgroundColor3 = Color3.fromRGB(30, 16, 16), BackgroundTransparency = 0.15, Visible = false, Parent = root })
UI.corner(14, fall)
UI.stroke(fall, T.Red, 3)
UI.text({ Text = "You fell!", Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 10), TextSize = 46, Weight = Enum.FontWeight.Heavy, Italic = true, TextColor3 = T.Red, Parent = fall })
local fallLine = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 68), TextSize = 20, TextColor3 = T.TextLight, Parent = fall })
local reviveBtn = UI.button({ Text = "Revive Here  " .. robux("Revive"), Style = "Purple", Size = UDim2.fromOffset(320, 74), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18), TextSize = 24, Parent = fall, OnClick = function()
		Offers.buy("Revive")
	end })

local function showFall(seconds)
	-- the paid revive isn't offered during the tutorial
	reviveBtn.Visible = not inTutorial()
	UI.popIn(fall, 0.6)
	local t0 = os.clock()
	task.spawn(function()
		while fall.Visible do
			local left = math.max(0, seconds - (os.clock() - t0))
			fallLine.Text = left > 0 and string.format("Back at the Hunting Grounds entrance in %ds", math.ceil(left)) or "Back at the entrance..."
			task.wait(0.2)
		end
	end)
end

function Offers.Start(c)
	C = c
	Net.get("Effect").OnClientEvent:Connect(function(kind, a)
		if kind == "Died" then
			showFall(a or Config.PlayerRespawn)
		end
	end)
	player.CharacterAdded:Connect(function()
		if fall.Visible then
			UI.popOut(fall)
		end
	end)
	Net.get("Drop").OnClientEvent:Connect(function(info)
		if info.BagFull then
			Offers.bagFull()
		end
	end)
	-- Starter Pack pill + one automatic showing per session
	local autoShown = false
	task.spawn(function()
		while true do
			local left = starterLeft()
			local tutorialDone = (player:GetAttribute("Tutorial") or 99) > #Config.Tutorial
			local show = left > 0 and tutorialDone
			-- hidden while a window is open: it sat on window headers (and the Leaderboards X)
			starterPill.Visible = show and not windowOpen()
			if show then
				starterPill.Text = "Starter Pack  " .. Format.Clock(left)
				starterCard.Timer.Text = Format.Clock(left)
				if not autoShown then
					autoShown = true
					-- opens once, after whatever window is up (daily gift, welcome) has closed
					task.spawn(function()
						task.wait(4)
						while windowOpen() or UI.Busy do
							task.wait(1)
						end
						if starterLeft() > 0 then
							starterCard.open()
						end
					end)
				end
				local s = starterPill:FindFirstChild("PopScale")
				if s and os.clock() % 3 < 0.5 then
					s.Scale = 1 + 0.06 * math.sin(os.clock() * 12)
				end
			elseif UI.isOpen(starterCard) and left <= 0 then
				starterCard.close()
			end
			task.wait(0.25)
		end
	end)
end

return Offers
