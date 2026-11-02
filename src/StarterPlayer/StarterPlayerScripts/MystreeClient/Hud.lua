-- StarterPlayerScripts/MystreeClient/Hud (ModuleScript)
-- The always-on screen (layout v2, user feedback 2026-10-26):
--  * left column, top: the main-quest tracker (user, 2026-10-27: moved out of the top bar, where it
--    looked off screen), over the travel strip and the menu grid;
--  * bottom-right: Spirit Stones / Peaches (the main currency, key "Scraps") pills with a small Settings gear beside them;
--  * top-right: the day/night clock, then the leaderboard pill (Leaderboard module) at the corner;
--  * top-centre: notifications (Notify) and the tutorial pill;
--  * left: travel strip (Island / Village / Hunt) over a 2 x 3 menu grid (Quests, Bag, Decor,
--    Spirits, Mounts, Shop). The tree has its own button in the chop dock and a prompt on the tree,
--    and equipped gear lives in the Bag, so neither is doubled here;
--  * bottom-left: the player card: portrait, name, CP, level/realm, HEALTH, EXP, tree progress and stats;
--  * bottom-centre: the chop dock (CHOP, Auto, Tree), shown only on your own island. Chopping is free.
-- Groups that come and go fade and slide (UI.fade on CanvasGroups); nothing pops in hard.
-- Roblox's own top-left UI is kept clear (user, 2026-10-26): the left column (quest tracker + menu)
-- sits below the chat when it fits, never over the player card (keepClearOfRoblox).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Hud = {}
local T = UI.T
local player = Players.LocalPlayer
local C

local _, root = UI.screen("MystreeHud", 5)
local DARK = Color3.fromRGB(18, 18, 22) -- ink (murim kit, UI.lua)

local function group(name, size, pos, anchor)
	return UI.new("CanvasGroup", { Name = name, BackgroundTransparency = 1, Size = size, Position = pos, AnchorPoint = anchor or Vector2.zero, Parent = root })
end

local function travelTo(where)
	local ok, msg = C.Transition.travel("Travel", where)
	if not ok and msg then
		C.Notify.error(msg)
	end
end

-- ===================================================================== bottom-right: currencies, materials, settings
-- (user: currencies bottom-right). Laid out right-to-left inside a fixed-size group.
-- the Settings gear is a small round button in the gap right of the currency pills (user, 2026-10-27)
local money = group("Money", UDim2.fromOffset(340, 150), UDim2.new(1, -14, 1, -10), Vector2.new(1, 1))
-- a currency pill: icon, amount, optional "+" (shop) button, and a tooltip saying what it is
local function pill(parent, x, y, w, id, onPlus)
	local def = Config.Currencies[id]
	local p = UI.new("Frame", { Name = id, Size = UDim2.fromOffset(w, 34), Position = UDim2.fromOffset(x, y), BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Parent = parent })
	UI.corner(17, p)
	UI.stroke(p, T.PanelLine, 1, 0.45)
	UI.icon(p, id, 34, { Position = UDim2.fromOffset(1, 0) })
	UI.tooltip(p, def.Name, def.Desc)
	local label = UI.text({ Text = "0", Size = UDim2.new(1, onPlus and -66 or -42, 1, 0), Position = UDim2.fromOffset(38, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 20, Weight = Enum.FontWeight.Heavy, Parent = p })
	if onPlus then
		local plus = UI.new("TextButton", { Text = "+", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -32, 0, 2), BackgroundColor3 = T.Green,
			FontFace = UI.Heavy, TextSize = 24, TextColor3 = T.White, Parent = p })
		UI.corner(15, plus)
		UI.bounce(plus)
		plus.Activated:Connect(onPlus)
	end
	return label
end
local spiritLabel = pill(money, 0, 116, 140, "Spirit", function()
	Sounds.play("Click")
	if C.Shop then
		C.Shop.open("Spirit Stones")
	end
end)
local scrapLabel = pill(money, 148, 116, 136, "Scraps")
-- Settings: a small round button in the gap right of the currency pills
local settingsBtn = UI.new("TextButton", { Name = "Settings", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(296, 116),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Parent = money })
UI.corner(17, settingsBtn)
local settingsStroke = UI.stroke(settingsBtn, T.PanelLine, 1, 0.45)
UI.bounce(settingsBtn)
local settingsIcon = UI.icon(settingsBtn, "settings", 24, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
settingsBtn.MouseEnter:Connect(function()
	settingsStroke.Color, settingsStroke.Transparency = T.Gold, 0
	TweenService:Create(settingsIcon, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Rotation = 45 }):Play()
end)
settingsBtn.MouseLeave:Connect(function()
	settingsStroke.Color, settingsStroke.Transparency = T.PanelLine, 0.45
	TweenService:Create(settingsIcon, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Rotation = 0 }):Play()
end)
UI.tooltip(settingsBtn, "Settings", "Music, sound, screen shake, particles and flashing lights.")
settingsBtn.Activated:Connect(function()
	Sounds.play("Click")
	if C.Settings then
		C.Settings.open()
	end
end)
-- (one gold, user 2026-10-27: the materials row is gone; only Spirit Stones and Peaches show here)
local incenseText = UI.text({ Text = "", Size = UDim2.fromOffset(280, 20), Position = UDim2.fromOffset(4, 44), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16,
	Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(230, 190, 255), Parent = money })


-- ===================================================================== top-centre: clock
local clock = UI.new("Frame", { Size = UDim2.fromOffset(180, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -324, 0, 8), BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15, Parent = root })
UI.corner(19, clock)
local clockStroke = UI.stroke(clock, T.PanelLine, 1.5)
local clockText = UI.text({ Text = "Day 5:00", Size = UDim2.fromScale(1, 1), TextSize = 20, Weight = Enum.FontWeight.Heavy, Parent = clock })
UI.shadow(clock, 19, 0.6)

-- the PvP pill left of the clock: says whether PvP is on (crimson) or off (ink), counts down while it
-- turns off, and toggles it on a click (Config.PvP; the Settings row does the same)
local pvpPill = UI.new("TextButton", { Name = "PvP", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(124, 40), AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -514, 0, 8), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Parent = root })
UI.corner(19, pvpPill)
local pvpStroke = UI.stroke(pvpPill, T.PanelLine, 1.5)
UI.bounce(pvpPill)
local pvpText = UI.text({ Text = "PvP OFF", Size = UDim2.fromScale(1, 1), TextSize = 18, Weight = Enum.FontWeight.Heavy, TextColor3 = T.TextLight, Parent = pvpPill })
UI.tooltip(pvpPill, "PvP", "On: players who also have PvP on can fight you in the Hunting Grounds. The top damage dealer takes a few of your Peaches if you fall.")
local function refreshPvP()
	local on = player:GetAttribute("PvP") == true
	local offAt = player:GetAttribute("PvPOffAt")
	if on and type(offAt) == "number" then
		pvpText.Text = string.format("PvP OFF in %ds", math.max(0, math.ceil(offAt - workspace:GetServerTimeNow())))
	else
		pvpText.Text = on and "PvP ON" or "PvP OFF"
	end
	pvpText.TextSize = (on and offAt) and 15 or 18
	TweenService:Create(pvpPill, TweenInfo.new(0.2), { BackgroundColor3 = on and T.Crimson or DARK }):Play()
	pvpStroke.Color = on and T.Ornament or T.PanelLine
end
pvpPill.Activated:Connect(function()
	Sounds.play("Click")
	task.spawn(function()
		local ok, msg = Net.invoke("SetPvP", not player:GetAttribute("PvP") or player:GetAttribute("PvPOffAt") ~= nil)
		if msg and C and C.Notify then
			C.Notify.toast(msg, ok and "Info" or "Error")
		end
	end)
end)
player:GetAttributeChangedSignal("PvP"):Connect(refreshPvP)
player:GetAttributeChangedSignal("PvPOffAt"):Connect(refreshPvP)
task.spawn(function()
	while true do
		task.wait(0.5)
		if player:GetAttribute("PvPOffAt") then
			refreshPvP()
		end
	end
end)
refreshPvP()

-- ===================================================================== left: quest tracker, travel strip, menu grid
local QUEST_H = 66
local side = group("Side", UDim2.fromOffset(214, 300 + QUEST_H + 8), UDim2.new(0, 14, 0.5, -26), Vector2.new(0, 0.5))
-- the quest tracker: a slim parchment card with a gold edge at the top of the column; tap opens the
-- quest log
local quest = UI.new("TextButton", { Name = "Quest", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(204, QUEST_H), Position = UDim2.fromOffset(0, 0),
	BackgroundColor3 = T.Parchment, BackgroundTransparency = 0.04, Parent = side })
UI.corner(8, quest)
UI.stroke(quest, T.Ornament, 1.5)
UI.bounce(quest)
UI.new("Frame", { Size = UDim2.new(0, 4, 1, -14), Position = UDim2.fromOffset(6, 7), BackgroundColor3 = T.Gold, Parent = quest }, { UI.corner(2) })
local questTitle = UI.text({ Text = "MAIN QUEST", Size = UDim2.new(1, -66, 0, 16), Position = UDim2.fromOffset(16, 5), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12,
	Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(160, 110, 30), Stroke = false, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = quest })
local questText = UI.text({ Text = "", Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(16, 22), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextSize = 16, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, TextWrapped = true,
	Scaled = true, MaxTextSize = 16, Parent = quest })
local questProgress = UI.text({ Text = "", Size = UDim2.fromOffset(60, 16), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5),
	TextXAlignment = Enum.TextXAlignment.Right, TextSize = 13, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Red, Stroke = false, Parent = quest })
local travel = UI.new("Frame", { Size = UDim2.fromOffset(204, 48), Position = UDim2.fromOffset(0, QUEST_H + 8), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Parent = side })
UI.corner(12, travel)
UI.stroke(travel, T.PanelLine, 1.2, 0.35)
UI.pad(travel, 4)
UI.list(travel, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local function travelButton(text, where, order)
	local b = UI.new("TextButton", { Name = "Travel" .. where, Text = text, AutoButtonColor = false, Size = UDim2.fromOffset(62, 40), BackgroundColor3 = T.Panel2,
		BackgroundTransparency = 1, FontFace = UI.Heavy, TextSize = 17, TextColor3 = T.TextLight, LayoutOrder = order, Parent = travel })
	UI.corner(9, b)
	UI.bounce(b)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.3 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
	end)
	b.Activated:Connect(function()
		Sounds.play("Click")
		travelTo(where)
	end)
	return b
end
local travelButtons = {
	Home = travelButton("Island", "Home", 1),
	Hub = travelButton("Village", "Hub", 2),
	Grounds = travelButton("Hunt", "Grounds", 3),
}
local menu = UI.new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(204, 240), Position = UDim2.fromOffset(0, QUEST_H + 8 + 58), Parent = side })
UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 70), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
local menuTiles = {}
for i, def in ipairs({ { "Quests", "Quests", "quests" }, { "Profile", "Bag", "cp" }, { "Decor", "Island", "decor" }, { "Spirits", "Spirits", "spirits" },
	{ "Mounts", "Mounts", "mounts" }, { "Shop", "Shop", "shop" } }) do
	local tile = UI.menuTile({ Text = def[1], Size = UDim2.fromOffset(96, 70), LayoutOrder = i, TextSize = 16, Parent = menu, OnClick = function()
		local m = C[def[2]]
		if m and m.open then
			m.open()
		end
	end })
	-- icon on top, label underneath
	UI.icon(tile, def[3], 40, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4) })
	local label = tile:FindFirstChild("Label")
	if label then
		label.Size = UDim2.new(1, -8, 0, 20)
		label.Position = UDim2.new(0, 4, 1, -23)
	end
	menuTiles[def[2]] = tile
end
Hud.MenuTiles = menuTiles

-- ===================================================================== bottom-left: the player card
local card = group("PlayerCard", UDim2.fromOffset(360, 166), UDim2.new(0, 12, 1, -10), Vector2.new(0, 1))
local cardBg = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.12, Parent = card })
UI.corner(14, cardBg)
UI.stroke(cardBg, T.PanelLine, 1.4, 0.3)
UI.pattern(cardBg, T.White, 0.02)
local portrait = UI.new("ImageLabel", { Size = UDim2.fromOffset(74, 74), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = T.Panel2, Image = "", Parent = card })
UI.corner(37, portrait)
UI.stroke(portrait, T.Ornament, 1.5)
-- a gold key-pattern ring round the portrait (VFX Library "Dragon_Marker_01")
UI.new("ImageLabel", { Name = "KeyRing", Image = UI.Art.KeyRing, ImageColor3 = T.Ornament, BackgroundTransparency = 1, Size = UDim2.fromOffset(94, 94),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(49, 49), ZIndex = 2, Parent = card })
task.spawn(function()
	local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	if ok then
		portrait.Image = img
	end
end)
UI.text({ Text = player.DisplayName, Size = UDim2.fromOffset(124, 26), Position = UDim2.fromOffset(98, 10), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 22, Weight = Enum.FontWeight.Heavy, Scaled = true, MaxTextSize = 22, Parent = card })
-- Power (user: an icon, not "CP"): the Power icon and the number on a red brush, top-right of the card
local cpBand = UI.new("Frame", { Name = "Power", Size = UDim2.fromOffset(130, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), BackgroundColor3 = T.CPBrush, Parent = card })
UI.corner(6, cpBand)
UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.3, 0.05), NumberSequenceKeypoint.new(1, 0.05) }), Parent = cpBand })
UI.icon(cpBand, "cp", 26, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) })
UI.tooltip(cpBand, "Power", "Your overall strength: attack, health, defence and agility from your level, gear and spirits.")
local cpText = UI.text({ Text = "0", Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(40, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 22,
	Weight = Enum.FontWeight.Heavy, TextColor3 = T.CP, Stroke = Color3.fromRGB(90, 22, 12), StrokeThickness = 1.2, Parent = cpBand })
local levelText = UI.text({ Text = "Lv.1 · Mortal I", Size = UDim2.fromOffset(290, 22), Position = UDim2.fromOffset(98, 38), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 18, Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(255, 232, 170), Stroke = Color3.fromRGB(60, 40, 20), Parent = card })

-- slim bars: health (with a trailing damage bar) and EXP
local function slimBar(y, h, c1, c2)
	local back = UI.new("Frame", { Size = UDim2.new(1, -110, 0, h), Position = UDim2.fromOffset(98, y), BackgroundColor3 = Color3.fromRGB(22, 20, 18), Parent = card })
	UI.corner(h, back)
	UI.stroke(back, Color3.fromRGB(10, 10, 8), 1)
	local trail = UI.new("Frame", { Name = "Trail", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 236, 200), BackgroundTransparency = 0.2, Parent = back })
	UI.corner(h, trail)
	local fill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.White, Parent = back })
	UI.corner(h, fill)
	UI.gradient(fill, c1, c2, 0)
	local label = UI.text({ Text = "", Size = UDim2.fromScale(1, 1), TextSize = math.max(12, h - 3), Weight = Enum.FontWeight.Heavy, Parent = back, ZIndex = 3 })
	return { Back = back, Fill = fill, Trail = trail, Label = label }
end
local hpBar = slimBar(64, 18, Color3.fromRGB(240, 90, 80), Color3.fromRGB(180, 40, 40))
local expBar = slimBar(88, 13, T.Exp, T.ExpDark)
local function setSlim(bar, frac, text, trail)
	frac = math.clamp(frac, 0, 1)
	TweenService:Create(bar.Fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
	if trail then
		-- the light trail lags behind damage, then catches up
		task.delay(0.35, function()
			TweenService:Create(bar.Trail, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
		end)
	else
		TweenService:Create(bar.Trail, TweenInfo.new(0.25), { Size = UDim2.fromScale(frac, 1) }):Play()
	end
	bar.Label.Text = text or ""
end
-- tree row: "Tree Lv 10" and either the growth countdown, "Ready to grow!" or progress toward the Scraps cost
local treeRow = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 110), BackgroundColor3 = DARK,
	BackgroundTransparency = 0.25, Parent = card })
UI.corner(8, treeRow)
UI.icon(treeRow, "tree", 24, { Position = UDim2.fromOffset(5, 1) })
local treeText = UI.text({ Text = "Tree Lv 1", Size = UDim2.new(0, 150, 1, 0), Position = UDim2.fromOffset(32, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16,
	Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(170, 230, 150), Parent = treeRow })
local treeBar = UI.new("Frame", { Size = UDim2.new(1, -196, 0, 10), Position = UDim2.new(0, 186, 0.5, -5), BackgroundColor3 = Color3.fromRGB(22, 20, 18), Parent = treeRow })
UI.corner(5, treeBar)
local treeFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(130, 210, 110), Parent = treeBar })
UI.corner(5, treeFill)
local treeNote = UI.text({ Text = "", Size = UDim2.new(1, -196, 1, 0), Position = UDim2.fromOffset(186, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15,
	Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(150, 240, 130), Parent = treeRow })
treeRow.Activated:Connect(function()
	Sounds.play("Click")
	if C.TreePanel then
		C.TreePanel.open()
	end
end)
-- the three stats, spelled out, each with a tooltip saying what it does (user: "what does agility do")
local statRow = UI.new("Frame", { Name = "Stats", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(14, 140), Parent = card })
UI.list(statRow, Enum.FillDirection.Horizontal, 16)
local statLabels = {}
for i, st in ipairs({
	{ "ATK", "Attack", "How hard your hits are. Every swing deals damage based on Attack." },
	{ "DEF", "Defense", "Cuts the damage monsters deal to you." },
	{ "AGL", "Agility", "A chance to dodge a monster's hit completely (up to 30%). Works best against weaker monsters." },
}) do
	local l = UI.text({ Text = "", Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15, Weight = Enum.FontWeight.Bold, TextColor3 = T.TextLight, LayoutOrder = i, Parent = statRow })
	UI.tooltip(l, st[2], st[3])
	statLabels[st[1]] = { Label = l, Name = st[2] }
end

-- ===================================================================== bottom-centre: the chop dock (own island only)
-- the dock is a CanvasGroup, which clips: keep a margin around the CHOP button for its 4px stroke and
-- its press bounce (user: the stroke was cut off at the top)
local DOCK_TOP = 12
local dock = group("Dock", UDim2.fromOffset(340, 170 + DOCK_TOP), UDim2.new(0.5, 0, 1, -6), Vector2.new(0.5, 1))
local chop = UI.new("TextButton", { Name = "Chop", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(136, 136), AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, DOCK_TOP), BackgroundColor3 = T.White, Parent = dock })
UI.corner(68, chop)
UI.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 150)), ColorSequenceKeypoint.new(0.55, T.Gold), ColorSequenceKeypoint.new(1, T.GoldDark) }), Rotation = 90, Parent = chop })
UI.stroke(chop, Color3.fromRGB(150, 96, 24), 4)
UI.new("Frame", { Size = UDim2.new(1, -18, 1, -18), Position = UDim2.fromOffset(9, 9), BackgroundTransparency = 1, Parent = chop },
	{ UI.corner(60), UI.new("UIStroke", { Color = Color3.fromRGB(255, 246, 200), Thickness = 2, Transparency = 0.2 }) })
UI.bounce(chop)
UI.icon(chop, "chop", 86, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })

local function roundButton(text, icon, x, onClick)
	local b = UI.new("TextButton", { Name = text, Text = text, AutoButtonColor = false, Size = UDim2.fromOffset(66, 66), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 64 + DOCK_TOP),
		BackgroundColor3 = T.White, FontFace = UI.Heavy, TextSize = 17, TextColor3 = T.White, Parent = dock })
	UI.corner(33, b)
	local g = UI.gradient(b, Color3.fromRGB(66, 64, 72), Color3.fromRGB(30, 29, 35))
	UI.stroke(b, T.PanelLine, 1.5, 0.2)
	local label = UI.textLayer(b, Color3.fromRGB(8, 8, 10), 1.4)
	label.Size = UDim2.new(1, -4, 0, 16)
	label.Position = UDim2.new(0, 2, 1, -21)
	b.TextSize = 14
	UI.icon(b, icon, 36, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
	UI.bounce(b)
	b.Activated:Connect(function()
		Sounds.play("Click")
		onClick(b, g)
	end)
	return b, g
end
local autoButton, autoGrad = roundButton("Auto", "auto", -120, function()
	if C.Chop then
		C.Chop.setAuto(not State.Auto)
	end
end)
local growButton = roundButton("Tree", "tree", 120, function()
	if C.TreePanel then
		C.TreePanel.open()
	end
end)
chop.Activated:Connect(function()
	if C.Chop then
		C.Chop.chop(true)
	end
end)

function Hud.setAutoLook(on)
	autoGrad.Color = on and ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(220, 150, 40)) or ColorSequence.new(Color3.fromRGB(66, 64, 72), Color3.fromRGB(30, 29, 35))
	autoButton.Text = on and "ON" or "Auto"
end

function Hud.pulseChop()
	local s = chop:FindFirstChild("PopScale")
	if s then
		s.Scale = 0.9
		TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end
Hud.ChopButton = chop
Hud.GrowButton = growButton
Hud.TravelButtons = travelButtons

-- ===================================================================== goals for the tracker (before / after the story)
local function count(t)
	local n = 0
	for _ in pairs(t or {}) do
		n += 1
	end
	return n
end
local GOALS = {
	{ "Chop your tree", function() return State.Stats.Chops or 0, 10 end, function() C.Chop.chop(true) end },
	{ "Grow your tree to Lv 2", function() return State.attr("TreeLevel", 1), 2 end, function() C.TreePanel.open() end },
	{ "Wear 6 pieces of gear", function() return count(State.Equipped), 6 end, function() C.Bag.open() end },
	{ "Defeat a monster", function() return State.Stats.Kills or 0, 1 end, function() travelTo("Grounds") end },
	{ "Summon a Spirit", function() return count(State.Companions), 1 end, function() C.Spirits.open("Summon") end },
}
local currentGoal
local function inTutorial()
	local tut = player:GetAttribute("Tutorial")
	return tut ~= nil and tut <= #Config.Tutorial
end
-- the column closes up when the tracker is hidden
local function showQuest(on)
	quest.Visible = on
	local y = on and QUEST_H + 8 or 0
	travel.Position = UDim2.fromOffset(0, y)
	menu.Position = UDim2.fromOffset(0, y + 58)
end

local function refreshGoal()
	-- the tutorial's own pill replaces this tracker until it's done
	if inTutorial() then
		showQuest(false)
		return
	end
	showQuest(true)
	if C and C.Quests and C.Quests.trackerText then
		local title, goal, have, need, ready = C.Quests.trackerText()
		if title then
			currentGoal = { title, nil, function()
				C.Quests.open("Main")
			end }
			questTitle.Text = "MAIN QUEST · " .. string.upper(title)
			local p = C.Quests.progress and C.Quests.progress()
			if ready then
				local npc = p and p.Main and Config.Npcs[p.Main.Npc]
				questText.Text = npc and ("Talk to " .. npc.Name) or goal
				questProgress.Text = "Ready!"
				questProgress.TextColor3 = Color3.fromRGB(60, 150, 70)
			else
				questText.Text = goal
				questProgress.Text = ((need or 0) > 1) and string.format("%d/%d", have or 0, need) or ""
				questProgress.TextColor3 = T.Red
			end
			return
		end
	end
	for _, g in ipairs(GOALS) do
		local have, need = g[2]()
		if have < need then
			currentGoal = g
			questTitle.Text = "NEXT GOAL"
			questText.Text = g[1]
			questProgress.Text = string.format("%d/%d", math.min(have, need), need)
			return
		end
	end
	local tl = State.attr("TreeLevel", 1)
	currentGoal = GOALS[2]
	questTitle.Text = "NEXT GOAL"
	questText.Text = "Grow your tree to Lv " .. (tl + 1)
	questProgress.Text = ""
end
quest.Activated:Connect(function()
	Sounds.play("Click")
	if currentGoal then
		pcall(currentGoal[3])
	end
end)

-- ===================================================================== refresh
local shownCP = 0
local function setCP(cp)
	if cp == shownCP then
		return
	end
	local from = shownCP
	shownCP = cp
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(function(x)
		cpText.Text = Format.Commas(x)
	end)
	TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = cp }):Play()
	task.delay(0.7, function()
		v:Destroy()
		cpText.Text = Format.Commas(cp)
	end)
	if cp > from and from > 0 then
		local s = cpText:FindFirstChild("PopScale") or UI.new("UIScale", { Name = "PopScale", Parent = cpText })
		s.Scale = 1.2
		TweenService:Create(s, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function refreshNumbers()
	spiritLabel.Text = Format.Num(State.attr("Spirit", 0))
	scrapLabel.Text = Format.Num(State.attr("Scraps", 0))
	setCP(State.attr("CP", 0))
	local level = State.attr("Level", 1)
	levelText.Text = string.format("Lv.%d · %s", level, Rules.realm(level))
	local exp, need = State.attr("Exp", 0), Rules.expToNext(level)
	setSlim(expBar, exp / need, string.format("EXP %s / %s", Format.Num(exp), Format.Num(need)))
	for key, e in pairs(statLabels) do
		e.Label.Text = string.format('%s <font color="#F4D88E">%s</font>', e.Name, Format.Num(State.attr(key, 0)))
		e.Label.RichText = true
	end
	refreshGoal()
end

-- health from the character's Humanoid, with a lagging damage trail
local lastHp
local function watchHealth(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	local function upd()
		local max = math.max(1, hum.MaxHealth)
		local hp = math.max(0, hum.Health)
		setSlim(hpBar, hp / max, string.format("HP %s / %s", Format.Num(hp), Format.Num(max)), lastHp ~= nil and hp < lastHp)
		lastHp = hp
	end
	hum.HealthChanged:Connect(upd)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(upd)
	lastHp = nil
	upd()
end

local function canGrow()
	if State.Tree.Growing or State.attr("TreeLevel", 1) >= Config.Tree.MaxLevel then
		return false
	end
	for k, n in pairs((Rules.growthCost(State.attr("TreeLevel", 1)))) do
		local have = Config.Materials[k] and State.attr("Mat_" .. k, 0) or State.attr(k, 0)
		if have < n then
			return false
		end
	end
	return true
end

local function refreshTree()
	local level = State.attr("TreeLevel", 1)
	if State.Tree.Growing then
		local _, total = Rules.growthCost(level)
		local left = math.max(0, (State.Tree.GrowEndsAt or 0) - os.time())
		treeText.Text = string.format("Tree Lv %d > %d", level, level + 1)
		treeBar.Visible = true
		treeFill.Size = UDim2.fromScale(total > 0 and math.clamp(1 - left / total, 0, 1) or 1, 1)
		treeNote.Text = ""
		treeText.Text = treeText.Text .. "  " .. Format.Clock(left)
	elseif level >= Config.Tree.MaxLevel then
		treeText.Text = "Tree Lv " .. level
		treeBar.Visible = false
		treeNote.Text = "Fully grown"
	elseif canGrow() then
		treeText.Text = "Tree Lv " .. level
		treeBar.Visible = false
		treeNote.Text = "Ready to grow!"
	else
		-- progress toward the next growth's Scraps (the main gate)
		treeText.Text = "Tree Lv " .. level
		local cost = Rules.growthCost(level)
		treeBar.Visible = true
		treeNote.Text = ""
		TweenService:Create(treeFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(State.attr("Scraps", 0) / math.max(1, cost.Scraps or 1), 0, 1), 1) }):Play()
	end
end

local function refreshDots()
	UI.setDot(growButton, canGrow())
	UI.setDot(menuTiles.Spirits, State.attr("Spirit", 0) >= Config.SummonCost.One)
	UI.setDot(menuTiles.Bag, State.itemCount() >= State.bagSize())
end

-- the chop dock only on YOUR island (not in the Village or the Hunting Grounds)
local function onOwnIsland()
	local name = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	local plot = name and plots and plots:FindFirstChild(name)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (plot and plot.PrimaryPart and hrp) or player:GetAttribute("InGrounds") then
		return false
	end
	return (hrp.Position - plot.PrimaryPart.Position).Magnitude < Config.Map.IslandRadius + 12
end
Hud.onOwnIsland = onOwnIsland
local dockShown
local function refreshPlace()
	local show = onOwnIsland()
	if show ~= dockShown then
		dockShown = show
		UI.fade(dock, show, UDim2.fromOffset(0, 40))
		if not show and C.Chop and State.Auto then
			C.Chop.setAuto(false)
		end
	end
end

-- ===================================================================== keep clear of Roblox's top-left UI
local sideScale = UI.new("UIScale", { Name = "MenuFit", Parent = side })
local SIDE_H = 300 + QUEST_H + 8
local GAP = 10

local function place(g, pos, anchor)
	g.AnchorPoint = anchor
	g:SetAttribute("HomePos", pos) -- UI.fade glides back to HomePos
	g.Position = pos
end

-- bottom of Roblox's chat (window + input bar) in screen pixels, or nil when chat is off
local function chatBottomPx()
	local bottom
	for _, cls in ipairs({ "ChatWindowConfiguration", "ChatInputBarConfiguration" }) do
		local cfg = TextChatService:FindFirstChildOfClass(cls)
		if cfg and cfg.Enabled then
			local ok, b = pcall(function()
				-- these are measured below the top bar, like a GuiObject's AbsolutePosition
				return cfg.AbsolutePosition.Y + cfg.AbsoluteSize.Y + GuiService:GetGuiInset().Y
			end)
			if ok and b and b > 0 then
				bottom = math.max(bottom or 0, b)
			end
		end
	end
	return bottom
end

local function keepClearOfRoblox()
	local k = UI.fitScale()
	local vp = UI.viewport()
	local inset = GuiService.TopbarInset
	local bandPx = inset.Height > 0 and inset.Height or 58
	local band = bandPx / k
	-- left column (quest tracker + menu): full size (user: never shrink it), never under the top bar or over the player card.
	-- It moves below Roblox's chat when there's room; on short screens it overlaps the chat instead,
	-- since both can't fit above the card.
	local screenH = vp.Y / k
	local cardTop = screenH - 10 - 166
	local ceiling = band + GAP
	-- short screens (phones): the six menu tiles go 3 x 2 and the column widens to match, so it
	-- keeps nearly full size above the player card instead of shrinking
	local room = cardTop - GAP - ceiling
	local wide = room < SIDE_H
	local width = wide and (96 * 3 + 12 * 2) or 204
	local sideH = wide and (QUEST_H + 8 + 58 + 152 + 8) or SIDE_H
	quest.Size = UDim2.fromOffset(width, QUEST_H)
	travel.Size = UDim2.fromOffset(width, 48)
	menu.Size = UDim2.fromOffset(width, wide and 152 or 240)
	side.Size = UDim2.fromOffset(width + 10, sideH)
	local s = math.min(1, room / sideH) -- only a very short screen shrinks it
	local h = sideH * s
	local top = screenH / 2 - 26 - sideH / 2
	local chat = chatBottomPx()
	if chat then
		top = math.max(top, chat / k + GAP)
	end
	top = math.clamp(top, ceiling, cardTop - GAP - h)
	sideScale.Scale = s
	place(side, UDim2.fromOffset(14, top), Vector2.zero)
end
Hud.keepClearOfRoblox = keepClearOfRoblox

function Hud.Start(c)
	C = c
	local watch = { "Spirit", "Scraps", "CP", "Level", "Exp", "TreeLevel", "ATK", "DEF", "AGL" }
	for _, a in ipairs(watch) do
		player:GetAttributeChangedSignal(a):Connect(function()
			refreshNumbers()
			refreshDots()
		end)
	end
	player:GetAttributeChangedSignal("Tutorial"):Connect(refreshGoal)
	player:GetAttributeChangedSignal("QuestProgress"):Connect(function()
		refreshGoal()
		local ok, p = pcall(function()
			return game:GetService("HttpService"):JSONDecode(player:GetAttribute("QuestProgress"))
		end)
		local waiting = false
		if ok and p then
			waiting = (p.Main and (p.Main.Offered or (p.Main.Ready and (p.Main.Index or 0) > 0))) or false
			for _, q in pairs(p.Side or {}) do
				waiting = waiting or q.Ready
			end
		end
		UI.setDot(menuTiles.Quests, waiting)
	end)
	State.Changed:Connect(function()
		refreshNumbers()
		refreshDots()
	end)
	State.InventoryChanged:Connect(refreshDots)
	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	dock.Visible = false
	refreshNumbers()
	refreshDots()
	keepClearOfRoblox()
	local function refitSoon()
		task.defer(keepClearOfRoblox) -- after UI's own refit of the scale
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refitSoon)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refitSoon)
	UI.Refitted:Connect(refitSoon)
	for _, cls in ipairs({ "ChatWindowConfiguration", "ChatInputBarConfiguration" }) do
		local cfg = TextChatService:FindFirstChildOfClass(cls)
		if cfg then
			for _, prop in ipairs({ "AbsolutePosition", "AbsoluteSize" }) do
				pcall(function()
					cfg:GetPropertyChangedSignal(prop):Connect(refitSoon)
				end)
			end
		end
	end
	-- Roblox finishes building its top bar and chat a moment after join
	task.delay(2, keepClearOfRoblox)
	-- the HUD groups glide in on join
	for i, g in ipairs({ side, card, money }) do
		g.Visible = false
		task.delay(0.12 * i, function()
			UI.fade(g, true, (g == side) and UDim2.fromOffset(-30, 0) or UDim2.fromOffset(0, (g == card or g == money) and 30 or -20), 0.4)
		end)
	end
	-- 4 Hz: clock, incense, tree row, dock visibility
	task.spawn(function()
		while true do
			local phase = workspace:GetAttribute("CyclePhase") or "Day"
			local ev = workspace:GetAttribute("CycleEvent") or ""
			local left = C.WorldFx and C.WorldFx.timeLeft() or 0
			local name = (ev == "Bloodmoon" and "Bloodmoon") or (ev == "GoldenHour" and "Golden Hour") or phase
			clockText.Text = name .. "  " .. Format.Clock(left)
			local col = C.Notify and C.Notify.color(ev ~= "" and ev or phase) or T.PanelLine
			clockStroke.Color = col
			clockText.TextColor3 = col:Lerp(T.White, 0.45)
			local inc = State.Boosts and State.Boosts.Incense or 0
			incenseText.Text = inc > 0 and ("Lucky Incense " .. Format.Time(inc)) or ""
			refreshTree()
			refreshPlace()
			task.wait(0.25)
		end
	end)
end

return Hud
