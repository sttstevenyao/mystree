-- StarterPlayerScripts/MystreeClient/Bag (ModuleScript)
-- The Profile window (user, 2026-10-27: the Bag became a profile). Profile tab: your character in 3D
-- (a slowly turning copy, armour and weapon included) with your 8 equipment slots around it, your
-- name, level and Power, the armour set bonuses, and a Show / Hide Armor toggle (the ShowArmor
-- setting: whether your armour is drawn on your character for everyone; stats count either way).
-- Inventory tab (the old bag): a grid of rarity tiles (sorted equipped first, then by CP) and a
-- detail panel for the picked item (stats, substats, CP change, Equip / Lock / Dismantle). Footer:
-- the auto-dismantle filter, auto-equip toggle, "dismantle all below", "dismantle worse" (gear that
-- is worse than what you wear and can't out-grow it: Rules.worseGear), and the bag count.
-- Tiles are kept per item id so their 3D
-- previews are built once; the grid only refreshes on inventory/state changes while the window is open.
-- Set pieces carry a bar in their set colour, Mythforged weapons one in their effect colour; the detail
-- panel lists the set (pieces worn, 2- and 4-piece bonuses) or the weapon's effect, and what a
-- dismantle gives (Scraps, plus forge materials for weapons).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Bag = {}
local T = UI.T

local C
local win, tabs
local grid, detail, footer
local emptyNote -- shown over the grid when the bag holds nothing
local fb = {} -- footer buttons (Lua fields can't live on Instances)
local tiles = {} -- item id -> tile
local slotTiles = {} -- slot -> tile (Equipped tab)
local selected -- item id
local dirty = true
local confirmUntil = 0
local confirmWorseUntil = 0

local function worseIds()
	return Rules.worseGear({ Inventory = State.Inventory, Equipped = State.Equipped })
end

local AUTO_NAMES = { [0] = "Off", "Common", "Uncommon", "Rare", "Epic" }

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

local function isEquipped(id)
	for _, eid in pairs(State.Equipped) do
		if eid == id then
			return true
		end
	end
	return false
end

local function statLine(stat, n)
	return string.format("%s  +%s", stat, Format.Num(n))
end

-- "+4 Iron Shards, +1 Spirit Steel" for what dismantling these items gives besides Scraps
local function yieldText(items)
	local parts = {}
	for k, n in pairs(Rules.forgeYield(items)) do
		local def = Config.Materials[k]
		table.insert(parts, "+" .. Format.Num(n) .. " " .. (def and def.Name or k))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-- the colour of a piece's marker bar: its set, or its Mythforged effect
local function markColor(it)
	if it.Set and Config.ArmorSets[it.Set] then
		return Config.ArmorSets[it.Set].Color
	elseif it.Myth and Config.Forge.Myth[it.Myth] then
		return Config.Forge.Myth[it.Myth].Effect.Color
	end
	return nil
end

local function hex(c)
	return c:Lerp(Color3.new(0, 0, 0), 0.3):ToHex()
end

-- ===================================================================== detail panel
local detailRefs = {}

local function buildDetail(parent)
	detail = UI.new("Frame", { Name = "Detail", BackgroundColor3 = T.Parchment2, Size = UDim2.new(0, 330, 1, -74),
		Position = UDim2.new(1, -330, 0, 0), Parent = parent })
	UI.corner(8, detail)
	UI.stroke(detail, T.InkSoft, 1.5, 0.4)
	UI.pad(detail, 12)
	local d = detailRefs
	d.Preview = UI.tile({ Rarity = 1, Size = UDim2.fromOffset(96, 96), Parent = detail })
	d.Name = UI.text({ Text = "Pick an item", Size = UDim2.new(1, -106, 0, 54), Position = UDim2.fromOffset(106, 0),
		TextSize = 22, Weight = Enum.FontWeight.Heavy, TextXAlignment = Enum.TextXAlignment.Left, Stroke = false, Parent = detail })
	d.Sub = UI.text({ Text = "", Size = UDim2.new(1, -106, 0, 22), Position = UDim2.fromOffset(106, 56),
		TextSize = 17, TextColor3 = T.InkSoft, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	d.CP = UI.text({ Text = "", Size = UDim2.new(1, -106, 0, 24), Position = UDim2.fromOffset(106, 76),
		TextSize = 19, Weight = Enum.FontWeight.Heavy, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	d.Stats = UI.text({ Text = "", Size = UDim2.new(1, 0, 1, -184), Position = UDim2.fromOffset(0, 106), TextSize = 18,
		TextColor3 = T.Ink, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true, Parent = detail })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), Position = UDim2.new(0, 0, 1, -62), Parent = detail })
	UI.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	d.Equip = UI.button({ Text = "Equip", Style = "Orange", Size = UDim2.fromOffset(100, 60), LayoutOrder = 1, Parent = row,
		OnClick = function(b)
			if not selected then
				return
			end
			local ok, msg = Net.invoke("Equip", selected)
			if ok then
				Sounds.play("Pop")
			else
				fail(b, msg)
			end
		end })
	d.Lock = UI.button({ Text = "Lock", Style = "Teal", Size = UDim2.fromOffset(92, 60), LayoutOrder = 2, Parent = row,
		OnClick = function(b)
			local it = selected and State.Inventory[selected]
			if not it then
				return
			end
			local ok, msg = Net.invoke("Lock", selected, not it.Lock)
			if not ok then
				fail(b, msg)
			end
		end })
	d.Dismantle = UI.button({ Text = "Dismantle", Style = "Red", Size = UDim2.fromOffset(110, 60), TextSize = 19, LayoutOrder = 3, Parent = row,
		OnClick = function(b)
			if not selected then
				return
			end
			local ok, msg = Net.invoke("Dismantle", { selected })
			if ok then
				Sounds.play("Coin")
				toast(msg, "Info")
				selected = nil
			else
				fail(b, msg)
			end
		end })
end

local function showDetail()
	local d = detailRefs
	local it = selected and State.Inventory[selected]
	if not it then
		selected = nil
		d.Name.Text = "Pick an item"
		d.Name.TextColor3 = T.Ink
		d.Sub.Text = "Tap any gear to see its stats."
		d.CP.Text = ""
		d.Stats.Text = ""
		UI.setModel(d.Preview.Viewport, nil)
		UI.setTileRarity(d.Preview, 1)
		d.Preview.Level.Text = ""
		for _, b in ipairs({ d.Equip, d.Lock, d.Dismantle }) do
			b.Visible = false
		end
		return
	end
	local r = Config.Rarities[it.R]
	d.Name.Text = Rules.itemName(it)
	-- the rarity colour, deepened so it reads on parchment without an outline
	d.Name.TextColor3 = r.Color:Lerp(Color3.new(0, 0, 0), 0.3)
	d.Sub.Text = string.format("%s · Lv.%d · %s", r.Name, it.L, it.Class or it.Slot)
	UI.setTileRarity(d.Preview, it.R)
	d.Preview.Level.Text = "Lv." .. it.L
	if d.Preview:GetAttribute("ItemId") ~= it.Id then
		d.Preview:SetAttribute("ItemId", it.Id)
		UI.setModel(d.Preview.Viewport, Assets.Gear(it), 35, -18)
	end
	local equipped = isEquipped(it.Id)
	if equipped then
		d.CP.Text = "Equipped"
		d.CP.TextColor3 = T.GreenDark
	else
		local delta = State.cpDelta(it)
		d.CP.Text = string.format("Power %s%s", delta >= 0 and "+" or "-", Format.Num(math.abs(delta)))
		d.CP.TextColor3 = delta >= 0 and T.GreenDark or T.RedDark
	end
	local lines = {}
	for _, stat in ipairs(Rules.Stats) do
		local n = it.Main[stat]
		if n then
			table.insert(lines, "<b>" .. statLine(stat, n) .. "</b>")
		end
	end
	local subKeys = {}
	for k in pairs(it.Subs or {}) do
		table.insert(subKeys, k)
	end
	table.sort(subKeys)
	for _, k in ipairs(subKeys) do
		local def = Config.Substats[k]
		table.insert(lines, string.format('%s  <font color="#%s"><b>+%s</b></font>', def and def.Name or k, hex(T.GreenDark), Format.Pct(it.Subs[k])))
	end
	local set = it.Set and Config.ArmorSets[it.Set]
	if set then
		local worn = Rules.setCounts(State)[it.Set] or 0
		table.insert(lines, string.format('<font color="#%s"><b>%s set (%d/%d)</b></font>', hex(set.Color), set.Name, worn, #Config.SetSlots))
		for _, tier in ipairs({ { 2, set.Bonus2 }, { 4, set.Bonus4 } }) do
			local on = worn >= tier[1]
			table.insert(lines, string.format('<font color="#%s">%d pieces: %s</font>', on and hex(T.GreenDark) or "8a8373", tier[1], Rules.bonusText(tier[2])))
		end
	end
	local myth = it.Myth and Config.Forge.Myth[it.Myth]
	if myth then
		table.insert(lines, string.format('<font color="#%s"><b>%s</b></font>', hex(myth.Effect.Color), myth.Effect.Name))
		table.insert(lines, string.format('<font color="#5a5446">%s</font>', myth.Effect.Desc))
	end
	local extra = yieldText({ it })
	table.insert(lines, string.format('<font color="#7a7365">Dismantles for %s Scraps%s</font>', Format.Num(Rules.dismantleValue(it)), extra ~= "" and (", " .. extra) or ""))
	-- the stats box holds ~8 lines at 18; set pieces and Mythforged weapons need more
	d.Stats.TextSize = (#lines > 8) and 15 or 18
	d.Stats.Text = table.concat(lines, "\n")
	d.Equip.Visible = not equipped
	d.Lock.Visible = true
	d.Lock.Text = it.Lock and "Unlock" or "Lock"
	d.Dismantle.Visible = not equipped and not it.Lock
end

-- ===================================================================== grid
local function markTile(tile, it)
	local eq = tile:FindFirstChild("Eq")
	eq.Visible = isEquipped(it.Id)
	tile:FindFirstChild("LockTag").Visible = it.Lock == true
	tile:FindFirstChild("Sel").Visible = (selected == it.Id)
end

local function makeTile(it)
	local tile = UI.tile({ Rarity = it.R, Level = "Lv." .. it.L, Size = UDim2.fromOffset(84, 84), Parent = grid,
		OnClick = function()
			selected = it.Id
			Bag.refresh()
		end })
	tile.Name = it.Id
	local eq = UI.new("Frame", { Name = "Eq", Size = UDim2.fromOffset(30, 20), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = T.GreenDark, Visible = false, ZIndex = 5, Parent = tile })
	UI.corner(5, eq)
	UI.text({ Text = "EQ", Size = UDim2.fromScale(1, 1), TextSize = 13, Weight = Enum.FontWeight.Heavy, ZIndex = 6, Parent = eq })
	local lock = UI.new("Frame", { Name = "LockTag", Size = UDim2.fromOffset(44, 18), Position = UDim2.new(1, -47, 0, 3),
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.15, Visible = false, ZIndex = 5, Parent = tile })
	UI.corner(5, lock)
	UI.text({ Text = "Lock", Size = UDim2.fromScale(1, 1), TextSize = 13, ZIndex = 6, Parent = lock })
	local sel = UI.new("Frame", { Name = "Sel", Size = UDim2.new(1, 6, 1, 6), Position = UDim2.fromOffset(-3, -3),
		BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = tile })
	UI.corner(8, sel)
	UI.stroke(sel, T.Gold, 3)
	local mark = markColor(it)
	if mark then
		local bar = UI.new("Frame", { Name = "SetBar", Size = UDim2.new(1, -16, 0, 5), Position = UDim2.new(0, 8, 1, -9),
			BackgroundColor3 = mark, ZIndex = 5, Parent = tile })
		UI.corner(3, bar)
	end
	UI.setModel(tile.Viewport, Assets.Gear(it), 35, -18)
	tiles[it.Id] = tile
	return tile
end

local function sortedItems()
	local list = {}
	for _, it in pairs(State.Inventory) do
		table.insert(list, { It = it, Eq = isEquipped(it.Id), CP = Rules.itemCP(it) })
	end
	table.sort(list, function(a, b)
		if a.Eq ~= b.Eq then
			return a.Eq
		end
		if a.CP ~= b.CP then
			return a.CP > b.CP
		end
		return a.It.Id < b.It.Id
	end)
	return list
end

local function refreshFooter()
	local f = fb
	if not f.Count then
		return
	end
	f.Count.Text = string.format("%d / %d", State.itemCount(), State.bagSize())
	f.Count.TextColor3 = (State.itemCount() >= State.bagSize()) and T.Red or T.TextLight
	f.Auto.Text = "Auto-dismantle: " .. (AUTO_NAMES[State.AutoDismantle] or "Off")
	f.AutoEquip.Text = "Auto-equip: " .. (State.AutoEquip and "On" or "Off")
	UI.restyle(f.AutoEquip, State.AutoEquip and "Green" or "Grey")
	local below = math.max(1, State.AutoDismantle)
	f.Bulk.Text = (os.clock() < confirmUntil) and "Tap again to confirm" or ("Dismantle all " .. AUTO_NAMES[below] .. (below > 1 and " and below" or ""))
	local n = #worseIds()
	f.Worse.Text = (os.clock() < confirmWorseUntil) and string.format("Tap again: %d item%s", n, n == 1 and "" or "s") or string.format("Dismantle worse (%d)", n)
	UI.restyle(f.Worse, n > 0 and "Red" or "Grey")
end

local function refreshEquipped()
	for _, slot in ipairs(Config.Slots) do
		local tile = slotTiles[slot]
		local it = State.equipped(slot)
		local id = it and it.Id or ""
		if tile:GetAttribute("ItemId") ~= id then
			tile:SetAttribute("ItemId", id)
			UI.setTileRarity(tile, it and it.R or 1)
			tile.Level.Text = it and ("Lv." .. it.L) or ""
			tile.Caption.Text = it and "" or slot
			UI.setModel(tile.Viewport, it and Assets.Gear(it) or nil, 35, -18)
		end
		tile.Parent:FindFirstChild("Name").Text = it and Rules.itemName(it) or "Empty"
		tile.Parent:FindFirstChild("Name").TextColor3 = it and Config.Rarities[it.R].Color:Lerp(Color3.new(0, 0, 0), 0.5) or T.InkSoft
	end
	if fb.SetBonus then
		local parts = {}
		for setId, n in pairs(Rules.setCounts(State)) do
			local set = Config.ArmorSets[setId]
			if set then
				local bonus = {}
				for _, tier in ipairs({ { 2, set.Bonus2 }, { 4, set.Bonus4 } }) do
					if n >= tier[1] then
						for k, v in pairs(tier[2]) do
							bonus[k] = (bonus[k] or 0) + v
						end
					end
				end
				local text = next(bonus) and Rules.bonusText(bonus) or "no bonus yet"
				table.insert(parts, string.format('<font color="#%s"><b>%s %d/%d</b></font> %s', set.Color:ToHex(), set.Name, n, #Config.SetSlots, text))
			end
		end
		table.sort(parts)
		fb.SetBonus.Text = #parts > 0 and table.concat(parts, "    ") or "Armour sets: wear 2 or 4 pieces of one set for a bonus. Zone bosses and rares drop them."
	end
end

function Bag.refresh()
	if not win then
		return
	end
	dirty = false
	-- drop tiles for items that are gone, add tiles for new ones
	for id, tile in pairs(tiles) do
		if not State.Inventory[id] then
			tile:Destroy()
			tiles[id] = nil
		end
	end
	local sorted = sortedItems()
	-- the detail panel always shows something: the first item until the player picks one
	if not (selected and State.Inventory[selected]) and sorted[1] then
		selected = sorted[1].It.Id
	end
	for i, e in ipairs(sorted) do
		local tile = tiles[e.It.Id] or makeTile(e.It)
		tile.LayoutOrder = i
		markTile(tile, e.It)
	end
	if emptyNote then
		emptyNote.Visible = #sorted == 0
	end
	showDetail()
	refreshFooter()
	refreshEquipped()
end

-- ===================================================================== build
local function buildBagPage(page)
	grid = UI.new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, -344, 1, -74),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8,
		ScrollBarImageColor3 = T.TealDark, Parent = page })
	-- 6 square cells that span the grid's width (no empty strip on the right)
	local layout = UI.new("UIGridLayout", { CellSize = UDim2.new(1 / 6, -8, 0, 84), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UI.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = layout })
	UI.pad(grid, 6, 6, 12, 6)
	UI.autoScrollBar(grid, 8)
	-- empty state: an icon and a line pointing at where gear comes from
	emptyNote = UI.new("Frame", { Name = "Empty", BackgroundTransparency = 1, Size = UDim2.new(1, -344, 1, -74), Visible = false, Parent = page })
	UI.icon(emptyNote, "bag", 84, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, 0) })
	UI.text({ Text = "Your bag is empty. Chop your Divine Tree or hunt in the Wildlands for gear.", Size = UDim2.new(1, -60, 0, 52),
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 10), TextSize = 18, TextColor3 = T.InkSoft, Stroke = false, Parent = emptyNote })
	buildDetail(page)
	footer = UI.new("Frame", { Name = "Footer", BackgroundColor3 = T.Panel, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 0, 1, -64), Parent = page })
	UI.corner(8, footer)
	UI.stroke(footer, T.PanelLine, 1.5, 0.3)
	UI.pad(footer, 6, 4)
	UI.list(footer, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	fb.Auto = UI.button({ Text = "", Style = "Teal", Size = UDim2.fromOffset(200, 56), TextSize = 16, LayoutOrder = 1, Parent = footer,
		OnClick = function(b)
			local nextValue = (State.AutoDismantle + 1) % (#AUTO_NAMES + 1)
			local ok, msg = Net.invoke("SetAutoDismantle", nextValue, State.AutoEquip)
			if not ok then
				fail(b, msg)
			end
		end })
	fb.AutoEquip = UI.button({ Text = "", Style = "Green", Size = UDim2.fromOffset(150, 56), TextSize = 16, LayoutOrder = 2, Parent = footer,
		OnClick = function(b)
			local ok, msg = Net.invoke("SetAutoDismantle", State.AutoDismantle, not State.AutoEquip)
			if not ok then
				fail(b, msg)
			end
		end })
	fb.Bulk = UI.button({ Text = "", Style = "Orange", Size = UDim2.fromOffset(215, 56), TextSize = 16, LayoutOrder = 3, Parent = footer,
		OnClick = function(b)
			if os.clock() > confirmUntil then
				confirmUntil = os.clock() + 3
				refreshFooter()
				task.delay(3.1, refreshFooter)
				return
			end
			confirmUntil = 0
			local below = math.max(1, State.AutoDismantle)
			local ids = {}
			for id, it in pairs(State.Inventory) do
				if it.R <= below and not it.Lock and not isEquipped(id) then
					table.insert(ids, id)
				end
			end
			if #ids == 0 then
				fail(b, "Nothing to dismantle at that rarity.")
				refreshFooter()
				return
			end
			local ok, msg = Net.invoke("Dismantle", ids)
			if ok then
				Sounds.play("Coin")
				toast(msg, "Info")
			else
				fail(b, msg)
			end
			refreshFooter()
		end })
	-- gear that's worse than what you wear AND can't out-grow it at the same level (keeps a weaker
	-- high-rarity piece that has more potential); locked, set and Mythforged pieces are always kept
	fb.Worse = UI.button({ Text = "", Style = "Red", Size = UDim2.fromOffset(215, 56), TextSize = 16, LayoutOrder = 4, Parent = footer,
		OnClick = function(b)
			if #worseIds() == 0 then
				fail(b, "Nothing worse than your equipped gear.")
				return
			end
			if os.clock() > confirmWorseUntil then
				confirmWorseUntil = os.clock() + 3
				refreshFooter()
				task.delay(3.1, refreshFooter)
				return
			end
			confirmWorseUntil = 0
			local ok, msg = Net.invoke("DismantleWorse")
			if ok then
				Sounds.play("Coin")
				toast(msg, "Info")
			else
				fail(b, msg)
			end
			refreshFooter()
		end })
	UI.tooltip(fb.Worse, "Dismantle worse", "Breaks down gear that's weaker than what you wear in its slot AND couldn't beat it even at the same level. A weaker but rarer piece is kept. Locked, set and Mythforged gear is never touched.")
	fb.Count = UI.text({ Text = "", Size = UDim2.fromOffset(100, 56), TextSize = 22, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.TextLight, LayoutOrder = 5, Parent = footer })
	fb.Count.TextColor3 = T.TextLight
end

-- ===================================================================== profile page
local LEFT_SLOTS = { "Helm", "Necklace", "Armor", "Belt" }
local RIGHT_SLOTS = { "Weapon", "Gloves", "Ring", "Boots" }
local profile = {} -- Viewport, World, Camera, Name, Power, ArmorBtn, Spin

-- copy the character (and the weapon it carries) into the viewport; called on open and on changes
local function refreshFigure()
	if not profile.World then
		return
	end
	profile.World:ClearAllChildren()
	local player = Players.LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	char.Archivable = true
	local copy = char:Clone()
	char.Archivable = false
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	copy.Parent = profile.World
	local weapon = C.Equipment and C.Equipment.weapon(player)
	if weapon then
		weapon.Archivable = true
		local w = weapon:Clone()
		w.Parent = profile.World
	end
	profile.Focus = hrp.Position + Vector3.new(0, -0.2, 0)
	profile.Yaw = select(2, hrp.CFrame:ToEulerAnglesYXZ()) + math.rad(200)
end

local ARMOR_PIECES = { Helm = true, Armor = true, Gloves = true, Boots = true, Belt = true }
local pieceBtns = {} -- slot -> its Show/Hide pill

local function refreshArmorButton()
	local all = State.setting("ShowArmor") ~= false
	if profile.ArmorBtn then
		profile.ArmorBtn.Text = all and "Hide all armor" or "Show all armor"
		UI.restyle(profile.ArmorBtn, all and "Grey" or "Green")
	end
	-- each piece: shown unless hidden on its own (or everything is hidden)
	for slot, b in pairs(pieceBtns) do
		local shown = all and not State.setting("Hide" .. slot)
		b.Text = shown and "Shown" or "Hidden"
		UI.restyle(b, shown and "Green" or "Grey")
		b.Visible = State.equipped(slot) ~= nil
	end
end

-- flip one vanity setting, save it, and redraw the figure (rolled back if the server says no)
local function toggleSetting(key)
	local on = not State.setting(key)
	State.setSetting(key, on)
	refreshArmorButton()
	task.spawn(function()
		local ok = Net.invoke("SaveSettings", key, on)
		if not ok then
			State.setSetting(key, not on)
			refreshArmorButton()
		end
		task.wait(0.3)
		refreshFigure()
	end)
end

local function buildProfilePage(page)
	local function slotCell(slot, x, y, i)
		local cell = UI.new("Frame", { Name = slot, BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 92), Position = UDim2.fromOffset(x, y), LayoutOrder = i, Parent = page })
		local tile = UI.tile({ Rarity = 1, Caption = slot, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, -35, 0, 0), Parent = cell,
			OnClick = function()
				local it = State.equipped(slot)
				if it then
					selected = it.Id
				end
				tabs.select("Inventory")
				Bag.refresh()
			end })
		UI.text({ Name = "Name", Text = "Empty", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 71), TextSize = 14,
			Weight = Enum.FontWeight.Heavy, Stroke = false, TextColor3 = T.InkSoft, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = cell })
		slotTiles[slot] = tile
		-- armour pieces: show or hide this piece's look on your character (vanity only)
		if ARMOR_PIECES[slot] then
			-- beside the tile, on the outer side (away from the figure)
			local onRight = x > 400
			local b = UI.button({ Text = "Shown", Style = "Green", Size = UDim2.fromOffset(62, 26), TextSize = 12,
				AnchorPoint = Vector2.new(onRight and 0 or 1, 0), Position = UDim2.new(0.5, onRight and 39 or -39, 0, 22), Parent = cell,
				OnClick = function()
					if State.setting("ShowArmor") == false then
						-- everything is hidden: show all again, with only this piece hidden
						toggleSetting("ShowArmor")
						task.delay(0.3, function() -- (one settings save at a time)
							if not State.setting("Hide" .. slot) then
								toggleSetting("Hide" .. slot)
							end
						end)
						return
					end
					toggleSetting("Hide" .. slot)
				end })
			UI.tooltip(b, slot, "Show or hide this piece on your character. Its stats count either way.")
			pieceBtns[slot] = b
		end
	end
	for i, slot in ipairs(LEFT_SLOTS) do
		slotCell(slot, 40, (i - 1) * 94, i)
	end
	for i, slot in ipairs(RIGHT_SLOTS) do
		slotCell(slot, 746, (i - 1) * 94, i + 4)
	end
	-- the figure: an ink panel with a key-pattern ring behind the character
	local stage = UI.new("Frame", { Name = "Figure", Size = UDim2.fromOffset(500, 372), Position = UDim2.fromOffset(218, 0), BackgroundColor3 = T.Panel, Parent = page })
	UI.corner(8, stage)
	UI.stroke(stage, T.Ornament, 1.5, 0.2)
	UI.ornaments(stage)
	UI.new("ImageLabel", { Name = "Ring", Image = UI.Art.KeyRing, ImageColor3 = T.Ornament, ImageTransparency = 0.75, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(330, 330), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Parent = stage })
	local vp = UI.new("ViewportFrame", { Name = "Viewport", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(150, 146, 140),
		LightColor = Color3.fromRGB(255, 246, 230), LightDirection = Vector3.new(-1, -1.2, -1), Parent = stage })
	local world = UI.new("WorldModel", { Parent = vp })
	local cam = UI.new("Camera", { FieldOfView = 28, Parent = vp })
	vp.CurrentCamera = cam
	profile.Viewport, profile.World, profile.Camera = vp, world, cam
	profile.Name = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 1, -58), TextSize = 22, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.Parchment, Parent = stage })
	profile.Power = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 1, -32), TextSize = 17, Weight = Enum.FontWeight.Bold,
		TextColor3 = T.Gold, Parent = stage })
	profile.ArmorBtn = UI.button({ Text = "Armor: Shown", Style = "Green", Size = UDim2.fromOffset(150, 34), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10), TextSize = 15, Parent = stage, OnClick = function()
			toggleSetting("ShowArmor")
		end })
	UI.tooltip(profile.ArmorBtn, "All armor", "Hide or show every armour piece at once. Each piece also has its own button. Your stats count either way.")
	-- active armour set bonuses along the bottom
	local bar = UI.new("Frame", { Name = "SetBonus", BackgroundColor3 = T.Panel, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -34), Parent = page })
	UI.corner(8, bar)
	UI.stroke(bar, T.PanelLine, 1.5, 0.3)
	fb.SetBonus = UI.text({ Text = "", Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 17, Weight = Enum.FontWeight.Bold,
		TextColor3 = T.TextLight, RichText = true, Parent = bar })
end

local function refreshProfileText()
	local player = Players.LocalPlayer
	if profile.Name then
		profile.Name.Text = string.format("%s  ·  Lv.%d %s", player.DisplayName, State.attr("Level", 1), Rules.realm(State.attr("Level", 1)))
		profile.Power.Text = "Power " .. Format.Num(State.attr("CP", 0))
	end
	refreshArmorButton()
end

function Bag.open(tab)
	if not win then
		return
	end
	win.open()
	if tab then
		tabs.select(tab)
	end
end

function Bag.close()
	if win then
		win.close()
	end
end

function Bag.Start(c)
	C = c
	win = UI.window({ Title = "Profile", Size = Vector2.new(960, 500), OnOpen = function()
		Bag.refresh()
		refreshProfileText()
		refreshFigure()
	end })
	tabs = UI.tabs(win, {
		{ Name = "Profile", Build = buildProfilePage },
		{ Name = "Inventory", Build = buildBagPage },
	})
	tabs.select("Profile")
	-- the figure turns slowly while the window is open
	RunService.Heartbeat:Connect(function(dt)
		if profile.Focus and UI.isOpen(win) then
			profile.Yaw += dt * 0.35
			local f = profile.Focus
			profile.Camera.CFrame = CFrame.new(f) * CFrame.Angles(0, profile.Yaw, 0) * CFrame.Angles(math.rad(-4), 0, 0) * CFrame.new(0, 0, 21)
		end
	end)
	-- the figure follows gear and armour changes
	for _, attr in ipairs({ "ArmorLook", "ShowArmor", "WeaponLook" }) do
		Players.LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
			if UI.isOpen(win) then
				task.delay(0.5, refreshFigure)
				refreshProfileText()
			end
		end)
	end
	local function changed()
		dirty = true
		if UI.isOpen(win) then
			Bag.refresh()
		end
	end
	State.InventoryChanged:Connect(changed)
	State.Changed:Connect(changed)
end

return Bag
