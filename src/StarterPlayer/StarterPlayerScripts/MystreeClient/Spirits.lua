-- StarterPlayerScripts/MystreeClient/Spirits (ModuleScript)
-- Companions window, laid out like the user's "Beast" reference: a big slowly turning preview with
-- a rarity tag and stars, a buffs pill, the skill line and Equip; below it every companion as a
-- tile, owned ones only (user: a bag, not an empty index). Summon tab: odds, pity counter, Spirit Stone
-- balance, Summon x1 / x10 and a card-by-card reveal.

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
local Odds = require(script.Parent.Odds)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Spirits = {}
local T = UI.T
local player = Players.LocalPlayer

local C
local win, tabs
local refs = {}
local selected
local previewCam, previewCenter, previewDist = nil, nil, 0
local tiles = {} -- companion id -> tile

-- companions sorted by rarity then name, for a stable grid
local IDS = {}
for id in pairs(Config.Companions) do
	table.insert(IDS, id)
end
table.sort(IDS, function(a, b)
	local ra, rb = Config.Companions[a].Rarity, Config.Companions[b].Rarity
	if ra ~= rb then
		return ra < rb
	end
	return Config.Companions[a].Name < Config.Companions[b].Name
end)

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

local function starsText(n)
	-- plain text: star glyphs are not safe in every font
	return string.format("Stars %d / %d", n, Config.CompanionStars.Max)
end

local function buffsText(id, owned)
	local b = Rules.companionBuffs(id, owned)
	local parts = {}
	for _, k in ipairs(Rules.Stats) do
		if b[k] then
			table.insert(parts, string.format("%s +%s", k, Format.Pct(b[k])))
		end
	end
	return table.concat(parts, "     ")
end

local function skillText(id, owned)
	local def = Config.Companions[id]
	local stars = owned and owned.Stars or 1
	local mult = def.Skill.Mult * (1 + (stars - 1) * Config.CompanionStars.StarBonus)
	return string.format("Every %ss it deals %s of your ATK to your target in the Hunting Grounds.", tostring(def.Skill.Interval), Format.Pct(mult))
end

local function slotOf(id)
	return table.find(State.CompanionEquipped, id)
end

-- ===================================================================== Spirits tab
local function select(id)
	selected = id
	local def = Config.Companions[id]
	local owned = State.Companions[id]
	local r = Config.Rarities[def.Rarity]
	refs.Tag.Text = r.Name .. "  " .. def.Name
	refs.TagBack.BackgroundColor3 = r.Color
	refs.Stars.Text = owned and starsText(owned.Stars) or "Not found yet"
	refs.Buffs.Text = buffsText(id, owned or { Stars = 1 })
	refs.Skill.Text = skillText(id, owned or { Stars = 1 })
	local model = Assets.Companion(id)
	previewCam = UI.setModel(refs.Preview, model, 30, -12, 1.1)
	if previewCam then
		local cf = model:GetBoundingBox()
		previewCenter = cf.Position
		previewDist = (previewCam.CFrame.Position - cf.Position).Magnitude
	end
	if not owned then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(40, 44, 44)
				p.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	local twin = player:GetAttribute("Pass_TwinSpirits") == true
	local slot = slotOf(id)
	refs.Equip1.Visible = owned ~= nil
	refs.Equip2.Visible = owned ~= nil and twin
	refs.Equip1.Text = (slot == 1) and "Unequip" or (twin and "Equip slot 1" or "Equip")
	refs.Equip2.Text = (slot == 2) and "Unequip" or "Equip slot 2"
	UI.restyle(refs.Equip1, slot == 1 and "Grey" or "Orange")
	UI.restyle(refs.Equip2, slot == 2 and "Grey" or "Green")
	refs.Locked.Visible = owned == nil
	for cid, tile in pairs(tiles) do
		tile.Sel.Visible = (cid == id)
	end
end

local function equip(slotIndex, btn)
	if not selected then
		return
	end
	local current = slotOf(selected)
	local id = (current == slotIndex) and "" or selected
	local ok, msg = Net.invoke("EquipCompanion", id, slotIndex)
	if ok then
		Sounds.play("Pop")
	else
		fail(btn, msg)
	end
end

local function buildSpiritsPage(page)
	local top = UI.new("Frame", { BackgroundColor3 = T.Parchment2, Size = UDim2.new(1, 0, 0, 238), Parent = page })
	UI.corner(8, top)
	UI.stroke(top, T.InkSoft, 1.5, 0.4)
	-- backdrop for the preview: a jade wash with a soft floor and a thin horizon line
	local stage = UI.new("Frame", { BackgroundColor3 = T.White, Size = UDim2.new(0, 400, 1, -12), Position = UDim2.fromOffset(6, 6), ClipsDescendants = true, Parent = top })
	UI.corner(8, stage)
	UI.gradient(stage, Color3.fromRGB(222, 236, 230), Color3.fromRGB(176, 206, 196))
	local floor = UI.new("Frame", { Size = UDim2.new(1, 0, 0.32, 0), Position = UDim2.fromScale(0, 0.68), BackgroundColor3 = Color3.fromRGB(120, 160, 150),
		BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = stage })
	UI.new("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90, Parent = floor })
	UI.new("Frame", { Size = UDim2.new(0.8, 0, 0, 1), Position = UDim2.fromScale(0.1, 0.68), BackgroundColor3 = Color3.fromRGB(90, 130, 120),
		BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = stage })
	refs.Preview = UI.new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -1.3, -1), Parent = stage })
	refs.TagBack = UI.new("Frame", { Size = UDim2.fromOffset(250, 34), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = T.Orange, Parent = stage })
	UI.corner(6, refs.TagBack)
	UI.gradient(refs.TagBack, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 0)
	refs.Tag = UI.text({ Text = "", Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 20, Weight = Enum.FontWeight.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = refs.TagBack })
	refs.Stars = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -34), TextSize = 22, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.GoldDark, Stroke = false, Parent = stage })
	refs.Locked = UI.text({ Text = "?", Size = UDim2.fromScale(1, 1), TextSize = 90, Weight = Enum.FontWeight.Heavy, TextColor3 = T.White, Visible = false, Parent = stage })
	-- info column
	local info = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -426, 1, -12), Position = UDim2.fromOffset(418, 6), Parent = top })
	local pill = UI.new("Frame", { BackgroundColor3 = T.White, Size = UDim2.new(1, 0, 0, 44), Parent = info })
	UI.corner(22, pill)
	UI.stroke(pill, T.InkSoft, 1.5, 0.5)
	refs.Buffs = UI.text({ Text = "", Size = UDim2.fromScale(1, 1), TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = pill })
	refs.Skill = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 54), TextSize = 18, TextColor3 = T.Ink, Stroke = false,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = info })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), Position = UDim2.new(0, 0, 1, -64), Parent = info })
	UI.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right)
	refs.Equip1 = UI.button({ Text = "Equip", Style = "Orange", Size = UDim2.fromOffset(170, 60), LayoutOrder = 1, Parent = row, OnClick = function(b)
		equip(1, b)
	end })
	refs.Equip2 = UI.button({ Text = "Equip slot 2", Style = "Green", Size = UDim2.fromOffset(170, 60), LayoutOrder = 2, Parent = row, OnClick = function(b)
		equip(2, b)
	end })
	-- the collection grid
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -250), Position = UDim2.fromOffset(0, 248), Parent = page })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 92), CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UI.pad(grid, 6)
	for i, id in ipairs(IDS) do
		local tile = UI.tile({ Rarity = Config.Companions[id].Rarity, Size = UDim2.fromOffset(92, 92), LayoutOrder = i, Parent = grid,
			OnClick = function()
				select(id)
			end })
		local sel = UI.new("Frame", { Name = "Sel", Size = UDim2.new(1, 6, 1, 6), Position = UDim2.fromOffset(-3, -3), BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = tile })
		UI.corner(8, sel)
		UI.stroke(sel, T.Gold, 3)
		local eq = UI.new("Frame", { Name = "Eq", Size = UDim2.fromOffset(30, 20), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = T.GreenDark, Visible = false, ZIndex = 5, Parent = tile })
		UI.corner(5, eq)
		UI.text({ Text = "EQ", Size = UDim2.fromScale(1, 1), TextSize = 13, Weight = Enum.FontWeight.Heavy, ZIndex = 6, Parent = eq })
		tiles[id] = tile
	end
	refs.Empty = UI.text({ Text = "No spirit beasts yet. Summon one in the Summon tab!", Size = UDim2.new(1, 0, 1, -250), Position = UDim2.fromOffset(0, 248),
		TextSize = 20, TextColor3 = T.InkSoft, Stroke = false, Visible = false, Parent = page })
end

local function refreshGrid()
	for id, tile in pairs(tiles) do
		local owned = State.Companions[id]
		local shown = tile:GetAttribute("Owned")
		if shown ~= (owned ~= nil) then
			tile:SetAttribute("Owned", owned ~= nil)
			if owned then
				UI.setTileRarity(tile, Config.Companions[id].Rarity)
				tile.Caption.Text = ""
				UI.setModel(tile.Viewport, Assets.Companion(id), 30, -12)
			else
				tile.RarityGradient.Color = ColorSequence.new(Color3.fromRGB(150, 150, 140), Color3.fromRGB(100, 100, 94))
				tile.RarityStroke.Color = Color3.fromRGB(70, 70, 64)
				tile.Caption.Text = "?"
				tile.Caption.TextSize = 40
				UI.setModel(tile.Viewport, nil)
			end
		end
		tile.Level.Text = owned and (owned.Stars .. "/" .. Config.CompanionStars.Max) or ""
		tile.Eq.Visible = slotOf(id) ~= nil
		-- only the spirits you own are listed
		tile.Visible = owned ~= nil
	end
	refs.Empty.Visible = next(State.Companions) == nil
end

-- the spirit to show: the one picked if you own it, else your equipped one, else any you own
local function firstOwned()
	for _, id in ipairs(IDS) do
		if State.Companions[id] then
			return id
		end
	end
end

-- ===================================================================== Summon tab
local function rarityOrder()
	local list = {}
	for r in pairs(Config.SummonOdds) do
		table.insert(list, r)
	end
	table.sort(list)
	return list
end

local function revealCard(parent, res, i)
	local def = Config.Companions[res.Id]
	local r = Config.Rarities[res.R]
	local card = UI.tile({ Rarity = res.R, Size = UDim2.fromOffset(120, 150), LayoutOrder = i, Parent = parent })
	card.Viewport.Size = UDim2.new(1, -6, 1, -46)
	card.Level.Text = ""
	UI.text({ Text = def.Name, Size = UDim2.new(1, -4, 0, 24), Position = UDim2.new(0, 2, 1, -46), TextSize = 15, Weight = Enum.FontWeight.Heavy, Parent = card, ZIndex = 5 })
	local note = res.New and "NEW!" or (res.Refund and ("+" .. res.Refund .. " Stones") or ("Star " .. res.Stars))
	UI.text({ Text = note, Size = UDim2.new(1, -4, 0, 20), Position = UDim2.new(0, 2, 1, -22), TextSize = 15, Weight = Enum.FontWeight.Heavy,
		TextColor3 = res.New and T.Gold or T.White, Parent = card, ZIndex = 5 })
	UI.setModel(card.Viewport, Assets.Companion(res.Id), 30, -12)
	UI.popIn(card, 0.2)
	if res.R >= 5 then
		Sounds.play("Legendary")
	elseif res.R >= 4 then
		Sounds.play("Epic")
	else
		Sounds.play("Rare", 1 + (i % 4) * 0.05, 0.7)
	end
	if res.R >= 5 then
		-- a glow ring that pulses on the best pulls
		local glow = UI.new("Frame", { Size = UDim2.new(1, 10, 1, 10), Position = UDim2.fromOffset(-5, -5), BackgroundTransparency = 1, ZIndex = 0, Parent = card })
		UI.corner(10, glow)
		local st = UI.stroke(glow, r.Color, 4)
		TweenService:Create(st, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
	end
end

local summoning = false
local function summon(n, btn)
	if summoning then
		return
	end
	local cost = (n == 10) and Config.SummonCost.Ten or Config.SummonCost.One
	if State.attr("Spirit", 0) < cost then
		fail(btn, string.format("You need %d more Spirit Stones.", cost - State.attr("Spirit", 0)))
		if C and C.Offers then
			C.Offers.spirit()
		end
		return
	end
	summoning = true
	local ok, msg, results = Net.invoke("Summon", n)
	if not ok then
		summoning = false
		fail(btn, msg)
		return
	end
	-- the full-screen roll and reveal (SummonFx), then back to the Summon tab with the cards
	if C and C.SummonFx and results and #results > 0 then
		UI.closeWindow()
		C.SummonFx.play(results)
		Spirits.open("Summon")
	end
	for _, c in ipairs(refs.Results:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	refs.Hint.Visible = false
	for i, res in ipairs(results or {}) do
		revealCard(refs.Results, res, i)
		task.wait(0.06)
	end
	summoning = false
end

local function buildSummonPage(page)
	local left = UI.new("Frame", { BackgroundColor3 = T.Panel, Size = UDim2.new(0, 260, 1, 0), Parent = page })
	UI.corner(8, left)
	UI.stroke(left, T.PanelLine, 1.5, 0.3)
	UI.ornaments(left)
	UI.pad(left, 14, 12)
	UI.text({ Text = "Summon odds", Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Weight = Enum.FontWeight.Heavy, Parent = left })
	for i, r in ipairs(rarityOrder()) do
		local rr = Config.Rarities[r]
		local row = UI.new("Frame", { BackgroundColor3 = rr.Color, BackgroundTransparency = 0.7, Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 36 + (i - 1) * 42), Parent = left })
		UI.corner(6, row)
		UI.text({ Text = rr.Name, Size = UDim2.new(0.6, -8, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 18, Weight = Enum.FontWeight.Heavy,
			TextColor3 = rr.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.text({ Text = Format.Pct(Config.SummonOdds[r] / 100), Size = UDim2.new(0.4, -8, 1, 0), Position = UDim2.fromScale(0.6, 0), TextSize = 18,
			Weight = Enum.FontWeight.Heavy, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	end
	refs.Pity = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 1, -60), TextSize = 16, TextColor3 = T.TextLight, Parent = left })
	-- the worded odds control (paid random items): every spirit, not just the tiers
	UI.button({ Text = "See every spirit's odds", Style = "Teal", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -100), TextSize = 15, Parent = left,
		OnClick = function()
			Odds.summon(win)
		end })

	local right = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -274, 1, 0), Position = UDim2.fromOffset(274, 0), Parent = page })
	refs.Balance = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 40), TextSize = 30, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Teal,
		Stroke = T.TealLine, StrokeThickness = 2, Parent = right })
	refs.Results = UI.new("Frame", { BackgroundColor3 = T.Parchment2, Size = UDim2.new(1, 0, 1, -124), Position = UDim2.fromOffset(0, 46), Parent = right })
	UI.corner(8, refs.Results)
	UI.stroke(refs.Results, T.InkSoft, 1.5, 0.4)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 116), CellPadding = UDim2.fromOffset(6, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.Results })
	UI.pad(refs.Results, 8)
	refs.Hint = UI.text({ Text = "Summon a spirit beast to fight at your side.\nDuplicates add a star (up to 5).", Size = UDim2.new(1, 0, 1, 0), TextSize = 20,
		TextColor3 = T.InkSoft, Stroke = false, Parent = refs.Results.Parent })
	refs.Hint.Position = refs.Results.Position
	refs.Hint.Size = refs.Results.Size
	refs.Hint.ZIndex = 4
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 66), Position = UDim2.new(0, 0, 1, -68), Parent = right })
	UI.list(row, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	refs.One = UI.button({ Text = "Summon x1   " .. Config.SummonCost.One, Style = "Green", Size = UDim2.fromOffset(230, 64), TextSize = 22, LayoutOrder = 1, Parent = row,
		OnClick = function(b)
			summon(1, b)
		end })
	refs.Ten = UI.button({ Text = "Summon x10   " .. Config.SummonCost.Ten, Style = "Orange", Size = UDim2.fromOffset(250, 64), TextSize = 22, LayoutOrder = 2, Parent = row,
		OnClick = function(b)
			summon(10, b)
		end })
	-- an info button (the odds are already on the left): what summoning is, and every spirit's chance
	local info = UI.button({ Text = "i", Style = "Teal", Size = UDim2.fromOffset(64, 64), TextSize = 30, LayoutOrder = 3, Parent = row, OnClick = function()
		Odds.summon(win)
	end })
	info.FontFace = UI.Serif
	UI.corner(32, info)
	UI.tooltip(info, "Summoning", "Spend Spirit Stones to call a spirit beast. Duplicates add a star. Tap to see every spirit's chance.")
end

local function refreshSummon()
	refs.Balance.Text = Format.Num(State.attr("Spirit", 0)) .. " Spirit Stones"
	local left = Config.SummonPity - (State.SummonPity or 0)
	refs.Pity.Text = string.format("A Legendary or better is guaranteed within %d more summons.", math.max(1, left))
	UI.setDot(refs.One, State.attr("Spirit", 0) >= Config.SummonCost.One)
end

function Spirits.refresh()
	if not win then
		return
	end
	refreshGrid()
	refreshSummon()
	local pick = (selected and State.Companions[selected] and selected) or State.CompanionEquipped[1] or firstOwned() or IDS[1]
	select(pick)
end

function Spirits.open(tab)
	if not win then
		return
	end
	win.open()
	tabs.select(tab or "Spirits")
end

function Spirits.close()
	if win then
		win.close()
	end
end

function Spirits.Start(c)
	C = c
	-- tall enough for the preview + one row of tiles, or the odds list + two rows of x10 cards
	win = UI.window({ Title = "Spirits", Size = Vector2.new(900, 450), OnOpen = function()
		Spirits.refresh()
	end })
	tabs = UI.tabs(win, {
		{ Name = "Spirits", Build = buildSpiritsPage },
		{ Name = "Summon", Build = buildSummonPage },
	})
	tabs.select("Spirits")
	State.Changed:Connect(function()
		if UI.isOpen(win) then
			refreshGrid()
			refreshSummon()
			if selected then
				select(selected)
			end
		end
	end)
	player:GetAttributeChangedSignal("Spirit"):Connect(function()
		if UI.isOpen(win) then
			refreshSummon()
		end
	end)
	-- slowly turn the preview while the window is open
	RunService.Heartbeat:Connect(function(dt)
		if previewCam and previewCam.Parent and previewCenter and UI.isOpen(win) and tabs.Current == "Spirits" then
			local a = os.clock() * 0.6
			local pitch = math.rad(-12)
			previewCam.CFrame = CFrame.new(previewCenter) * CFrame.Angles(0, a, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.new(0, 0, previewDist)
		end
	end)
end

return Spirits
