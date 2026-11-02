-- StarterPlayerScripts/MystreeClient/Shop (ModuleScript)
-- The shop: Featured (Call Bloodmoon and Lucky Incense banners that move: turning sunburst, pulsing
-- NEW tag, shine sweep, bobbing title), Peaches, Spirit Stones (3x2, BEST VALUE on the biggest,
-- hidden where paid random items are restricted) and Passes (OWNED once bought).
-- Purchases: Id 0 products are free test grants in Studio (StudioPurchase), the real prompt otherwise.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Odds = require(script.Parent.Odds)
local Purchase = require(script.Parent.Purchase)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Shop = {}
local T = UI.T
local player = Players.LocalPlayer

local C
local win, tabs
local refs = { Passes = {}, Banners = {} }

local PURPLE = { Color3.fromRGB(176, 120, 230), Color3.fromRGB(120, 70, 190), Color3.fromRGB(70, 34, 120), Color3.fromRGB(235, 215, 255) }
UI.Styles.Purple = UI.Styles.Purple or PURPLE

local function toast(text, kind)
	if C and C.Notify and text then
		C.Notify.toast(text, kind)
	end
end

local function fail(btn, msg)
	Sounds.play("Error")
	toast(msg, "Error")
	if btn then
		task.spawn(UI.shake, btn)
	end
end

function Shop.buy(key, btn)
	local ok, msg = Purchase.buy(key)
	if not ok then
		fail(btn, msg)
	elseif msg then
		Sounds.play("Coin")
		toast(msg, "Purchase")
	end
end

local function priceButton(parent, key, size, pos, textSize)
	local b = UI.button({ Text = Purchase.price(key), Style = "Purple", Size = size or UDim2.fromOffset(160, 60),
		Position = pos or UDim2.new(), TextSize = textSize or 24, Parent = parent, OnClick = function(btn)
			Shop.buy(key, btn)
		end })
	b.Name = "Price"
	Purchase.label(b, key)
	return b
end

local function card(parent, order, size)
	local f = UI.new("Frame", { BackgroundColor3 = T.Panel, Size = size, LayoutOrder = order, Parent = parent })
	UI.corner(8, f)
	UI.stroke(f, T.PanelLine, 1.5, 0.3)
	UI.ornaments(f)
	return f
end

-- ===================================================================== Featured banners
local function sunburst(parent, color)
	local holder = UI.new("Frame", { Name = "Sunburst", BackgroundTransparency = 1, Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent })
	for i = 0, 11 do
		UI.new("Frame", { Size = UDim2.fromOffset(620, 26), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = i * 15, BackgroundColor3 = color, BackgroundTransparency = 0.86, Parent = holder })
	end
	return holder
end

local function banner(parent, key, opts)
	local f = UI.new("Frame", { Name = key, BackgroundColor3 = T.White, Size = UDim2.new(0.5, -8, 1, 0), LayoutOrder = opts.Order,
		ClipsDescendants = true, Parent = parent })
	UI.corner(10, f)
	UI.gradient(f, opts.Top, opts.Bottom)
	UI.stroke(f, T.Gold, 3)
	local burst = sunburst(f, opts.Burst)
	UI.ornaments(f, T.Gold)
	local title = UI.text({ Text = opts.Title, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 40), TextSize = 40,
		Weight = Enum.FontWeight.Heavy, TextColor3 = opts.TitleColor, Stroke = T.Outline, StrokeThickness = 1.2, Parent = f })
	UI.text({ Text = opts.Desc, Size = UDim2.new(1, -40, 0, 84), Position = UDim2.fromOffset(20, 98), TextSize = 19,
		TextColor3 = T.White, Parent = f })
	-- the hero: the offer's icon in the middle of the card
	local hero = UI.icon(f, opts.Icon, 92, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 188), ZIndex = 2 })
	UI.text({ Text = opts.Note, Size = UDim2.new(1, -40, 0, 40), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -92), TextSize = 15,
		TextColor3 = T.Cream, Parent = f })
	priceButton(f, key, UDim2.fromOffset(220, 66), UDim2.new(0.5, -110, 1, -84), 30)
	local tag = UI.new("Frame", { BackgroundColor3 = T.Red, Size = UDim2.fromOffset(92, 32), Position = UDim2.fromOffset(12, 10),
		Rotation = -8, ZIndex = 4, Parent = f })
	UI.corner(6, tag)
	UI.stroke(tag, T.White, 2)
	UI.text({ Text = opts.Tag or "NEW!", Size = UDim2.fromScale(1, 1), TextSize = 20, Weight = Enum.FontWeight.Heavy, ZIndex = 5, Parent = tag })
	-- shine sweep: a soft white bar that crosses the banner every few seconds
	local shine = UI.new("Frame", { BackgroundColor3 = T.White, BackgroundTransparency = 0.82, Size = UDim2.new(0, 60, 2, 0),
		Position = UDim2.new(-0.3, 0, -0.5, 0), Rotation = 20, ZIndex = 3, Parent = f })
	refs.Banners[key] = { Frame = f, Burst = burst, Title = title, Tag = tag, Shine = shine, Phase = opts.Order, Hero = hero }
	return f
end

local function buildFeatured(page)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = page })
	UI.list(holder, Enum.FillDirection.Horizontal, 16)
	banner(holder, "CallBloodmoon", {
		Order = 1, Title = "Call Bloodmoon", TitleColor = Color3.fromRGB(255, 120, 110),
		Top = Color3.fromRGB(120, 24, 24), Bottom = Color3.fromRGB(40, 10, 14), Burst = Color3.fromRGB(255, 120, 100),
		Desc = "The next night is a Bloodmoon for the whole server: Blood Skeletons, Blood Amber and the Godly Skeleton.",
		Note = "Everyone on the server sees your name when it rises.", Tag = "SERVER", Icon = "boss",
	})
	banner(holder, "LuckyIncense", {
		Order = 2, Title = "Lucky Incense", TitleColor = T.Gold,
		Top = Color3.fromRGB(196, 130, 40), Bottom = Color3.fromRGB(90, 50, 16), Burst = Color3.fromRGB(255, 230, 150),
		Desc = "Epic, Legendary, Mythic and Divine drops are twice as likely for 30 minutes.",
		Note = "30 minutes of playtime. Buying again adds more time.", Tag = "NEW!", Icon = "incense",
	})
end

-- ===================================================================== Peaches
local PEACHES = { "PeachBasket", "PeachCrate", "PeachCart" }

local function buildPeaches(page)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = page })
	UI.list(holder, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	for i, key in ipairs(PEACHES) do
		local p = Config.Products[key]
		-- three cards share the page width and height (no empty margins)
		local f = card(holder, i, UDim2.new(1 / 3, -11, 1, 0))
		UI.text({ Text = p.Name, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 24), TextSize = 26, Weight = Enum.FontWeight.Heavy, Parent = f })
		-- the peach icon, bigger for bigger packs, and the amount under it
		UI.icon(f, "peach", 96 + i * 22, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 0) })
		UI.text({ Text = "x" .. Format.Commas(p.Grant.Scraps), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.52, 0), TextSize = 34,
			Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(255, 196, 170), Stroke = false, Parent = f })
		UI.text({ Text = "Grow your tree, forge gear and unlock mounts", Size = UDim2.new(1, -20, 0, 48), Position = UDim2.new(0, 10, 0.64, 0),
			TextSize = 17, TextColor3 = T.TextLight, Parent = f })
		priceButton(f, key, UDim2.new(1, -40, 0, 62), UDim2.new(0, 20, 1, -80), 26)
	end
end

-- ===================================================================== Spirit Stones
local SPIRIT = { "Spirit1", "Spirit2", "Spirit3", "Spirit4", "Spirit5", "Spirit6" }

local function buildSpirit(page)
	refs.SpiritGrid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = page })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(270, 196), CellPadding = UDim2.fromOffset(14, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.SpiritGrid })
	for i, key in ipairs(SPIRIT) do
		local p = Config.Products[key]
		local f = card(refs.SpiritGrid, i, UDim2.new())
		f.ClipsDescendants = false
		if p.Best then
			UI.gradient(f, Color3.fromRGB(150, 90, 200), Color3.fromRGB(70, 40, 120))
		end
		UI.text({ Text = p.Name, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 14), TextSize = 19, Weight = Enum.FontWeight.Heavy, Parent = f })
		-- amount: the Spirit Stone icon and the number
		local amt = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 46), Parent = f })
		UI.list(amt, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		UI.icon(amt, "spirit_stone", 48, { LayoutOrder = 1 })
		UI.text({ Text = Format.Commas(p.Grant.Spirit), Size = UDim2.fromOffset(0, 52), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextSize = 42,
			Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(150, 225, 240), Stroke = false, LayoutOrder = 2, Parent = amt })
		priceButton(f, key, UDim2.new(1, -134, 0, 60), UDim2.new(0, 16, 1, -72), 24)
		-- Spirit Stones pay for summons (paid random items): the odds sit on every pack
		UI.button({ Text = "Odds", Style = "Teal", Size = UDim2.fromOffset(92, 60), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -72),
			TextSize = 20, Parent = f, OnClick = function()
				Odds.summon(win)
			end })
		if p.Best then
			local rib = UI.new("Frame", { BackgroundColor3 = T.Red, Size = UDim2.fromOffset(132, 32), Position = UDim2.new(1, -110, 0, -12),
				Rotation = 6, ZIndex = 5, Parent = f })
			UI.corner(6, rib)
			UI.stroke(rib, T.White, 2)
			UI.text({ Text = "BEST VALUE", Size = UDim2.fromScale(1, 1), TextSize = 18, Weight = Enum.FontWeight.Heavy, ZIndex = 6, Parent = rib })
			refs.Ribbon = rib
		end
	end
	refs.SpiritBlocked = UI.text({ Text = "Spirit Stone packs aren't available in your region. You can still earn Spirit Stones from bosses, Bloodmoons and daily gifts.",
		Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(30, 0), TextSize = 22, TextColor3 = T.Ink, Stroke = false, Visible = false, Parent = page })
end

-- ===================================================================== Passes
local PASSES = { "VIP", "SwiftAuto", "BigBag", "TwinSpirits", "FortuneCharm", "CelestialSteed" }

local function buildPasses(page)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = page })
	-- 3 x 2 so all six fit without scrolling (Playbook 07)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(278, 204), CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	local colors = {
		VIP = { Color3.fromRGB(230, 180, 60), Color3.fromRGB(150, 100, 20) },
		SwiftAuto = { Color3.fromRGB(90, 170, 220), Color3.fromRGB(40, 90, 150) },
		BigBag = { Color3.fromRGB(120, 180, 110), Color3.fromRGB(50, 110, 60) },
		TwinSpirits = { Color3.fromRGB(180, 120, 230), Color3.fromRGB(90, 50, 150) },
		FortuneCharm = { Color3.fromRGB(240, 140, 90), Color3.fromRGB(150, 60, 30) },
		CelestialSteed = { Color3.fromRGB(250, 210, 120), Color3.fromRGB(160, 110, 40) },
	}
	local passIcons = { VIP = "star", SwiftAuto = "auto", BigBag = "bag", TwinSpirits = "spirits", FortuneCharm = "heart", CelestialSteed = "mounts" }
	for i, key in ipairs(PASSES) do
		local p = Config.Gamepasses[key]
		local f = card(holder, i, UDim2.new())
		UI.gradient(f, colors[key][1], colors[key][2])
		UI.icon(f, passIcons[key], 52, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10) })
		UI.text({ Text = p.Name, Size = UDim2.new(1, -84, 0, 38), Position = UDim2.fromOffset(12, 10), TextSize = 28, Weight = Enum.FontWeight.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left, Scaled = true, MaxTextSize = 28, Parent = f })
		UI.text({ Text = p.Desc, Size = UDim2.new(1, -84, 0, 70), Position = UDim2.fromOffset(12, 50), TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = f })
		UI.text({ Text = "Forever", Size = UDim2.fromOffset(100, 24), Position = UDim2.new(0, 12, 1, -46), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18, TextColor3 = T.Cream, Parent = f })
		local price = priceButton(f, key, UDim2.fromOffset(150, 60), UDim2.new(1, -162, 1, -70), 24)
		local owned = UI.text({ Text = "OWNED", Size = UDim2.fromOffset(150, 60), Position = UDim2.new(1, -162, 1, -70), TextSize = 28,
			Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(200, 255, 200), Stroke = T.GreenLine, StrokeThickness = 1.2, Visible = false, Parent = f })
		refs.Passes[key] = { Price = price, Owned = owned }
	end
end

-- ===================================================================== refresh and motion
function Shop.refresh()
	if not win then
		return
	end
	for key, r in pairs(refs.Passes) do
		local owned = player:GetAttribute("Pass_" .. key) == true
		r.Price.Visible = not owned
		r.Owned.Visible = owned
	end
	local blocked = player:GetAttribute("NoPaidRandom") == true
	if refs.SpiritGrid then
		refs.SpiritGrid.Visible = not blocked
		refs.SpiritBlocked.Visible = blocked
	end
end

local function animate()
	if not (win and UI.isOpen(win)) then
		return
	end
	local t = os.clock()
	if tabs.Current == "Featured" then
		for _, b in pairs(refs.Banners) do
			b.Burst.Rotation = (t * 12 + b.Phase * 40) % 360
			b.Title.Position = UDim2.fromOffset(10, 40 + math.sin(t * 2 + b.Phase) * 4)
			if b.Hero then
				b.Hero.Position = UDim2.new(0.5, 0, 0, 188 + math.sin(t * 2.4 + b.Phase) * 5)
			end
			local s = 1 + math.max(0, math.sin(t * 4 + b.Phase)) * 0.08
			b.Tag.Size = UDim2.fromOffset(92 * s, 32 * s)
			-- shine every ~3.5 s
			local k = ((t + b.Phase * 1.2) % 3.5) / 0.9
			b.Shine.Position = UDim2.new(-0.3 + math.clamp(k, 0, 1) * 1.6, 0, -0.5, 0)
		end
	elseif tabs.Current == "Spirit Stones" and refs.Ribbon then
		refs.Ribbon.Rotation = 6 + math.sin(t * 3) * 2
	end
end

function Shop.open(tab)
	if not win then
		return
	end
	win.open()
	tabs.select(tab or "Featured")
end

function Shop.close()
	if win then
		win.close()
	end
end

function Shop.Start(c)
	C = c
	win = UI.window({ Title = "Shop", Size = Vector2.new(900, 500), OnOpen = function()
		Shop.refresh()
	end })
	tabs = UI.tabs(win, {
		{ Name = "Featured", Build = buildFeatured },
		{ Name = "Peaches", Build = buildPeaches },
		{ Name = "Spirit Stones", Build = buildSpirit },
		{ Name = "Passes", Build = buildPasses },
	})
	tabs.select("Featured")
	for _, b in pairs(tabs.Buttons) do
		b.Size = UDim2.fromOffset(196, 50)
	end
	for _, key in ipairs(PASSES) do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(Shop.refresh)
	end
	player:GetAttributeChangedSignal("NoPaidRandom"):Connect(Shop.refresh)
	RunService.Heartbeat:Connect(animate)
end

return Shop
