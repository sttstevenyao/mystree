-- StarterPlayerScripts/MystreeClient/Forge (ModuleScript)
-- Old Bao's forge (the Village forge's prompt opens it: Opens = "Forge"). Endgame crafting:
--  * Forge: pick a weapon class, then forge one at a rarity tier (Config.Forge.Tiers) from forge
--    materials and Scraps. A tier unlocks when the Divine Tree can reach that rarity.
--  * Mythforge: one card per Mythforged weapon (Config.Forge.Myth): its effect and its relic cost.
--    Relics only drop from the Mythic beasts that roam the Wildlands.
--  * Materials: every forge material and relic with how many you hold and where it comes from.
-- Each tab fits the window to its content (Playbook 07). Costs show have/need, red when short.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local Forge = {}
local T = UI.T
local player = Players.LocalPlayer

local C
local win, tabs
local busy = false
local chosen = "Sword"
local CLASSES = { "Sword", "Greatsword", "Spear" }
local refs = { Tiers = {}, Myth = {}, Mats = {}, Chips = {}, ClassButtons = {} }

local WIDTH = 900
local ROW_H, ROW_GAP, PICK_H = 72, 8, 48
local CARD_H, NOTE_H = 292, 24
local MAT_H, MAT_GAP = 84, 10
local BODY = {
	Forge = PICK_H + 10 + #Config.Forge.Tiers * ROW_H + (#Config.Forge.Tiers - 1) * ROW_GAP,
	Mythforge = NOTE_H + 8 + CARD_H,
	Materials = 0, -- set in buildMaterials from the material count
}

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

local function have(key)
	if Config.Materials[key] then
		return State.attr("Mat_" .. key, 0)
	end
	return State.attr(key, 0)
end

local function nameOf(key)
	return (Config.Materials[key] and Config.Materials[key].Name) or (Config.Currencies[key] and Config.Currencies[key].Name) or key
end

-- the tree level a rarity unlocks at (nil if it never caps there)
local function unlockLevel(rarity)
	local best
	for l, r in pairs(Config.Tree.MaxRarity) do
		if r >= rarity and (not best or l < best) then
			best = l
		end
	end
	return best
end

-- ===================================================================== cost chips
-- icon + "have/need" (red when short); hover shows what the material is. Cost order: relics and
-- materials first, Scraps last.
local function sortedCost(cost)
	local keys = {}
	for k in pairs(cost) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		local ra = (Config.Materials[a] and Config.Materials[a].Kind == "Relic") and 0 or (a == "Scraps" and 2 or 1)
		local rb = (Config.Materials[b] and Config.Materials[b].Kind == "Relic") and 0 or (b == "Scraps" and 2 or 1)
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return keys
end

local function costChip(parent, key, need, order, width)
	local chip = UI.new("Frame", { Name = key, Size = UDim2.fromOffset(width or 124, 32), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1,
		LayoutOrder = order, Parent = parent })
	UI.corner(16, chip)
	UI.icon(chip, key, 30, { Position = UDim2.fromOffset(1, 1) })
	local label = UI.text({ Text = "", Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(34, 0), TextSize = 15, Weight = Enum.FontWeight.Heavy,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
	local def = Config.Materials[key] or Config.Currencies[key]
	UI.tooltip(chip, nameOf(key), def and def.Desc)
	table.insert(refs.Chips, { Label = label, Key = key, Need = need })
	return chip
end

local function refreshChips()
	for _, c in ipairs(refs.Chips) do
		local n = have(c.Key)
		c.Label.Text = Format.Num(n) .. "/" .. Format.Num(c.Need)
		c.Label.TextColor3 = (n >= c.Need) and T.TextLight or Color3.fromRGB(255, 110, 100)
	end
end

local function canAfford(cost)
	return Rules.canPay(cost, have)
end

-- ===================================================================== forging
local function celebrate(item, msg)
	local r = item and item.R or 3
	local color = UI.rarityColor(r)
	if item and item.Myth and Config.Forge.Myth[item.Myth] then
		color = Config.Forge.Myth[item.Myth].Effect.Color
	end
	Sounds.play(r >= 5 and "Legendary" or "Epic")
	Fx.flash(color, 0.7, 0.45)
	Fx.shake(r >= 6 and 2.5 or 1.2, 0.4)
	if item and C.Notify then
		C.Notify.moment(item.Myth and "MYTHFORGED!" or "FORGED!", Rules.itemName(item), color)
	end
	if item and C.Loot and C.Loot.showCard then
		C.Loot.showCard({ Item = item })
	end
	if msg then
		toast(msg, "Purchase")
	end
end

local function forge(btn, remote, a, b)
	if busy then
		return
	end
	busy = true
	local ok, msg, item = Net.invoke(remote, a, b)
	busy = false
	if ok then
		celebrate(item, msg)
		Forge.refresh()
	else
		fail(btn, msg)
	end
end

-- ===================================================================== Forge tab
local function setClass(class)
	chosen = class
	for name, b in pairs(refs.ClassButtons) do
		UI.restyle(b, name == class and "Cream" or "Teal")
	end
	for _, row in ipairs(refs.Tiers) do
		UI.setModel(row.Tile.Viewport, Assets.Weapon(class, row.Rarity), 35, -18)
		row.Name.Text = Config.Rarities[row.Rarity].Name .. " " .. class
	end
end

local function buildForge(page)
	local pick = UI.new("Frame", { Name = "Class", BackgroundColor3 = T.Panel, Size = UDim2.new(1, 0, 0, PICK_H), Parent = page })
	UI.corner(8, pick)
	UI.stroke(pick, T.PanelLine, 1.5, 0.3)
	UI.pad(pick, 12, 2, 12, 2)
	UI.list(pick, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	UI.text({ Text = "Weapon class", Size = UDim2.fromOffset(150, 40), TextSize = 19, Weight = Enum.FontWeight.Heavy, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.Cream, LayoutOrder = 0, Parent = pick })
	for i, class in ipairs(CLASSES) do
		refs.ClassButtons[class] = UI.button({ Text = class, Style = "Teal", Size = UDim2.fromOffset(150, 40), TextSize = 19, LayoutOrder = i, Parent = pick,
			OnClick = function()
				Sounds.play("Click")
				setClass(class)
			end })
	end
	UI.text({ Text = "Forged weapons roll max main stats and one extra substat.", Size = UDim2.new(1, -684, 0, 40), TextSize = 14, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.TextLight, LayoutOrder = 9, Parent = pick })
	for i, tier in ipairs(Config.Forge.Tiers) do
		local y = PICK_H + 10 + (i - 1) * (ROW_H + ROW_GAP)
		local row = UI.new("Frame", { Name = "Tier" .. i, BackgroundColor3 = T.Parchment2, Size = UDim2.new(1, 0, 0, ROW_H), Position = UDim2.fromOffset(0, y), Parent = page })
		UI.corner(8, row)
		UI.stroke(row, T.Ornament, 1.5)
		local r = Config.Rarities[tier.Rarity]
		local tile = UI.tile({ Rarity = tier.Rarity, Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(6, 6), Parent = row })
		local name = UI.text({ Text = "", Size = UDim2.fromOffset(230, 28), Position = UDim2.fromOffset(76, 8), TextSize = 21, Weight = Enum.FontWeight.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = r.Color:Lerp(Color3.new(0, 0, 0), 0.25), Stroke = false, Parent = row })
		local sub = UI.text({ Text = "", Size = UDim2.fromOffset(230, 22), Position = UDim2.fromOffset(76, 38), TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.InkSoft, Stroke = false, Parent = row })
		local costs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -470, 1, 0), Position = UDim2.fromOffset(312, 0), Parent = row })
		UI.list(costs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		for k, key in ipairs(sortedCost(tier.Cost)) do
			costChip(costs, key, tier.Cost[key], k)
		end
		local btn = UI.button({ Text = "Forge", Style = "Orange", Size = UDim2.fromOffset(140, 54), AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -9, 0.5, 0), TextSize = 22, Parent = row, OnClick = function(b)
				forge(b, "Forge", i, chosen)
			end })
		table.insert(refs.Tiers, { Rarity = tier.Rarity, Cost = tier.Cost, Tile = tile, Name = name, Sub = sub, Button = btn })
	end
	setClass(chosen)
end

local function refreshForge()
	local tree = (State.Tree and State.Tree.Level) or 1
	local cap = Rules.maxRarity(tree)
	for _, row in ipairs(refs.Tiers) do
		row.Sub.Text = string.format("Item Lv.%d · max stats · +1 substat", tree * Config.ItemLevelPerTree)
		if row.Rarity > cap then
			local need = unlockLevel(row.Rarity)
			row.Button.Text = need and ("Tree Lv " .. need) or "Locked"
			UI.restyle(row.Button, "Grey")
			row.Button.Active = false
		else
			row.Button.Text = "Forge"
			UI.restyle(row.Button, canAfford(row.Cost) and "Orange" or "Grey")
			row.Button.Active = true
		end
	end
end

-- ===================================================================== Mythforge tab
local function buildMyth(page)
	UI.text({ Text = "Relics drop only from the Mythic beasts that roam the Wildlands: the Heavenly Qilin, the Nine-Tailed Fox and the Thunder Roc.",
		Size = UDim2.new(1, 0, 0, NOTE_H), TextSize = 15, TextColor3 = T.InkSoft, Stroke = false, Parent = page })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, CARD_H), Position = UDim2.fromOffset(0, NOTE_H + 8), Parent = page })
	UI.list(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	local n = #Config.Forge.MythOrder
	local divine = UI.rarityColor(#Config.Rarities)
	for i, id in ipairs(Config.Forge.MythOrder) do
		local def = Config.Forge.Myth[id]
		local eff = def.Effect
		local card = UI.new("Frame", { Name = id, BackgroundColor3 = T.Panel, Size = UDim2.new(1 / n, -12 * (n - 1) / n, 1, 0), LayoutOrder = i, Parent = row })
		UI.corner(10, card)
		UI.stroke(card, eff.Color, 2.5)
		UI.gradient(card, eff.Color:Lerp(T.Panel, 0.72), T.Panel)
		UI.ornaments(card, T.Gold)
		local tile = UI.tile({ Rarity = #Config.Rarities, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(1, -80, 0, 10), Parent = card })
		UI.setModel(tile.Viewport, Assets.Weapon(def.Class, #Config.Rarities), 35, -18)
		UI.text({ Text = def.Name, Size = UDim2.new(1, -96, 0, 30), Position = UDim2.fromOffset(12, 10), TextSize = 23, Weight = Enum.FontWeight.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = divine, Parent = card })
		UI.text({ Text = "Divine " .. def.Class, Size = UDim2.new(1, -96, 0, 20), Position = UDim2.fromOffset(12, 42), TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.TextLight, Parent = card })
		UI.text({ Text = eff.Name, Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 84), TextSize = 19, Weight = Enum.FontWeight.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = eff.Color, Parent = card })
		UI.text({ Text = eff.Desc, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 106), TextSize = 14, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = T.TextLight, Parent = card })
		local costs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 154), Parent = card })
		UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 32), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = costs })
		for k, key in ipairs(sortedCost(def.Cost)) do
			costChip(costs, key, def.Cost[key], k)
		end
		local btn = UI.button({ Text = "Mythforge", Style = "Purple", Size = UDim2.new(1, -40, 0, 54), Position = UDim2.new(0, 20, 1, -64), TextSize = 22, Parent = card,
			OnClick = function(b)
				forge(b, "Mythforge", id)
			end })
		refs.Myth[id] = { Cost = def.Cost, Button = btn }
	end
end

local function refreshMyth()
	for _, m in pairs(refs.Myth) do
		UI.restyle(m.Button, canAfford(m.Cost) and "Purple" or "Grey")
	end
end

-- ===================================================================== Materials tab
local function buildMaterials(page)
	local keys = {}
	for k, def in pairs(Config.Materials) do
		if def.Kind == "Forge" or def.Kind == "Relic" then
			table.insert(keys, k)
		end
	end
	table.sort(keys, function(a, b)
		local ka, kb = Config.Materials[a].Kind, Config.Materials[b].Kind
		if ka ~= kb then
			return ka == "Forge"
		end
		return a < b
	end)
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = page })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -MAT_GAP / 2, 0, MAT_H), CellPadding = UDim2.fromOffset(MAT_GAP, MAT_GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, key in ipairs(keys) do
		local def = Config.Materials[key]
		local f = UI.new("Frame", { Name = key, BackgroundColor3 = T.Parchment2, LayoutOrder = i, Parent = grid })
		UI.corner(8, f)
		UI.stroke(f, def.Kind == "Relic" and T.Gold or T.Ornament, def.Kind == "Relic" and 2.5 or 1.5)
		UI.icon(f, key, 64, { Position = UDim2.fromOffset(10, 10) })
		UI.text({ Text = def.Name, Size = UDim2.new(1, -170, 0, 26), Position = UDim2.fromOffset(84, 8), TextSize = 20, Weight = Enum.FontWeight.Heavy,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = def.Color:Lerp(Color3.new(0, 0, 0), 0.35), Stroke = false, Parent = f })
		local count = UI.text({ Text = "0", Size = UDim2.fromOffset(80, 26), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), TextSize = 22,
			Weight = Enum.FontWeight.Heavy, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Ink, Stroke = false, Parent = f })
		UI.text({ Text = def.Desc or "", Size = UDim2.new(1, -96, 0, 40), Position = UDim2.fromOffset(84, 36), TextSize = 14, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = T.InkSoft, Stroke = false, Parent = f })
		refs.Mats[key] = count
	end
	local rows = math.ceil(#keys / 2)
	BODY.Materials = rows * MAT_H + math.max(0, rows - 1) * MAT_GAP
end

local function refreshMaterials()
	for key, label in pairs(refs.Mats) do
		label.Text = Format.Num(have(key))
	end
end

-- ===================================================================== public
function Forge.refresh()
	if not (win and UI.isOpen(win)) then
		return
	end
	refreshChips()
	refreshForge()
	refreshMyth()
	refreshMaterials()
end

function Forge.open(tab)
	if not win then
		return
	end
	win.open()
	tabs.select(tab or "Forge")
	Forge.refresh()
end

function Forge.close()
	if win then
		win.close()
	end
end

function Forge.Start(c)
	C = c
	win = UI.window({ Title = "Old Bao's Forge", Size = Vector2.new(WIDTH, 74 + BODY.Forge), OnOpen = function()
		task.defer(Forge.refresh)
	end })
	tabs = UI.tabs(win, {
		{ Name = "Forge", Build = buildForge },
		{ Name = "Mythforge", Build = buildMyth },
		{ Name = "Materials", Build = buildMaterials },
	}, function(name)
		UI.fitWindow(win, BODY[name] or BODY.Forge)
	end)
	tabs.select("Forge")
	State.Changed:Connect(Forge.refresh)
	player.AttributeChanged:Connect(function(name)
		if name == "Scraps" or string.sub(name, 1, 4) == "Mat_" then
			Forge.refresh()
		end
	end)
end

return Forge
