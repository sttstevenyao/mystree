-- StarterPlayerScripts/MystreeClient/AdminPanel (ModuleScript)
-- Admin panel for testing (Playbook 09): only for players the server marks Admin (Studio always).
-- The Admin button (right side, clear of the jump button) or F2 opens a compact window of buttons,
-- one per AdminService command. The server re-checks every command. ResetSave needs a second tap.
-- The Stats rows at the top take typed values: "500" sets, "+500" / "-500" adds or takes away
-- ("2.5k" works), Enter or SET sends it; RESET puts a main stat back to what level and gear give.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Net = require(ReplicatedStorage.Mystree.Net)
local Format = require(ReplicatedStorage.Mystree.Format)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)

local AdminPanel = {}
local T = UI.T
local player = Players.LocalPlayer

local C
local win
local built = false

local function toast(text, kind)
	if C and C.Notify and text then
		C.Notify.toast(text, kind)
	end
end

local function run(btn, cmd, a, b)
	local ok, msg = Net.invoke("Admin", cmd, a, b)
	if ok then
		Sounds.play("Pop", 1.2, 0.6)
		toast(msg or cmd, "Info")
	else
		Sounds.play("Error")
		toast(msg or "Failed", "Error")
		task.spawn(UI.shake, btn)
	end
end

local function sorted(map)
	local list = {}
	for k in pairs(map) do
		table.insert(list, k)
	end
	table.sort(list)
	return list
end

-- sections of { Label, Command, A, B, Style }
local function sections()
	local spawns = {}
	for _, id in ipairs(sorted(Config.Mobs)) do
		local kind = Config.Mobs[id].Kind
		table.insert(spawns, { id, "Spawn", id, nil, (kind == "Boss" or kind == "Mythic") and "Red" or (kind == "Rare" and "Purple" or "Teal") })
	end
	-- a mutated mob of the zone you're standing in
	for _, id in ipairs(sorted(Config.Mutations)) do
		table.insert(spawns, { Config.Mutations[id].Name, "Spawn", id, nil, "Green" })
	end
	local comps = {}
	for _, id in ipairs(sorted(Config.Companions)) do
		table.insert(comps, { Config.Companions[id].Name, "Companion", id })
	end
	local mounts = {}
	for _, id in ipairs(sorted(Config.Mounts)) do
		table.insert(mounts, { Config.Mounts[id].Name, "Mount", id })
	end
	local rolls = {}
	for r = 3, #Config.Rarities do
		table.insert(rolls, { "Roll " .. Config.Rarities[r].Name, "Roll", r, nil, "Orange" })
	end
	return {
		{ "Currencies", {
			{ "+10K Peaches", "Scraps", 10000 }, { "+1K Spirit", "Spirit", 1000 },
			{ "+50 Relics", "Materials", 50 },
		} },
		{ "Progress", {
			{ "Restart tutorial", "Tutorial", nil, nil, "Green" }, { "Reset quests", "Quests", nil, nil, "Green" }, { "Main quest +1", "QuestStep" }, { "Tree Lv +1", "TreeLevel" }, { "Finish growth", "FinishGrowth" }, { "Level 10", "Level", 10 },
			{ "Level 25", "Level", 25 }, { "Level 40", "Level", 40 },
		} },
		{ "Drops", rolls },
		{ "World", {
			{ "Bloodmoon", "Bloodmoon", nil, nil, "Red" }, { "Golden Hour", "GoldenHour", nil, nil, "Orange" }, { "Skip cycle", "SkipCycle" },
			{ "Kill mobs near", "KillMobs", nil, nil, "Red" }, { "Go to Village", "Travel", "Hub" }, { "Go to Grounds", "Travel", "Grounds" },
			{ "Heal", "Heal", nil, nil, "Green" },
		} },
		{ "Spawn mob", spawns },
		{ "Companions", comps },
		{ "Summon preview", {
			{ "Rare", "SummonPreview", 3, 1, "Teal" }, { "Epic", "SummonPreview", 4, 1, "Purple" }, { "Legendary", "SummonPreview", 5, 1, "Orange" },
			{ "Mythic", "SummonPreview", 6, 1, "Red" }, { "Divine", "SummonPreview", 7, 1, "Orange" }, { "Mythic x10", "SummonPreview", 6, 10, "Red" },
		} },
		{ "Mounts", mounts },
		{ "Save", { { "Reset my save", "ResetSave", nil, nil, "Red" } } },
	}
end

-- { attribute / command key, label, can reset }
local STAT_ROWS = {
	{ "ATK", "Attack", true }, { "HP", "Health", true }, { "DEF", "Defense", true }, { "AGL", "Agility", true },
	{ "Level", "Level" }, { "TreeLevel", "Tree level" }, { "Scraps", "Peaches" }, { "Spirit", "Spirit Stones" },
}

-- one typed-value row: name, live value, a box, SET (and RESET for main stats)
local function statRow(parent, order, key, label, canReset)
	local row = UI.new("Frame", { BackgroundColor3 = T.Parchment2, LayoutOrder = order, Parent = parent })
	UI.corner(6, row)
	UI.text({ Text = label, Size = UDim2.new(0, 120, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 17, Weight = Enum.FontWeight.Bold,
		TextColor3 = T.Ink, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local value = UI.text({ Text = "", Size = UDim2.new(0, 84, 1, 0), Position = UDim2.fromOffset(128, 0), TextSize = 17, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.CPBrush, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local function show()
		local v = player:GetAttribute(key)
		value.Text = type(v) == "number" and Format.Num(v) or "-"
	end
	player:GetAttributeChangedSignal(key):Connect(show)
	show()
	local box = UI.new("TextBox", { Text = "", PlaceholderText = "500, +50, -50", ClearTextOnFocus = false, Size = UDim2.new(0, 112, 0, 34),
		Position = UDim2.new(0, 214, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.Parchment, TextColor3 = T.Ink,
		PlaceholderColor3 = T.InkSoft, TextSize = 17, FontFace = UI.font(Enum.FontWeight.Bold), Parent = row })
	UI.corner(4, box)
	UI.stroke(box, T.InkSoft, 1, 0.3)
	local set
	local function send(btn)
		if box.Text == "" then
			return
		end
		run(btn or set, "Stat", key, box.Text)
		box.Text = ""
	end
	set = UI.button({ Text = "SET", Style = "Green", TextSize = 15, Size = UDim2.fromOffset(canReset and 54 or 116, 34),
		Position = UDim2.new(0, 332, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = row, OnClick = function(btn)
			send(btn)
		end })
	if canReset then
		UI.button({ Text = "RESET", Style = "Teal", TextSize = 13, Size = UDim2.fromOffset(58, 34), Position = UDim2.new(0, 390, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5), Parent = row, OnClick = function(btn)
				run(btn, "Stat", key, "reset")
			end })
	end
	box.FocusLost:Connect(function(enter)
		if enter then
			send()
		end
	end)
end

local function build()
	built = true
	win = UI.window({ Title = "Admin", Size = Vector2.new(960, 520) })
	local scroll = UI.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = T.TealDark, Parent = win.Body })
	UI.list(scroll, Enum.FillDirection.Vertical, 6)
	UI.pad(scroll, 4, 4, 14, 4)
	UI.text({ Text = "Stats  (type 500, +50 or -50, then Enter)", Size = UDim2.new(1, 0, 0, 28), TextSize = 20, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.Ink, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = -2, Parent = scroll })
	local statGrid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -1, Parent = scroll })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(456, 46), CellPadding = UDim2.fromOffset(10, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = statGrid })
	for i, r in ipairs(STAT_ROWS) do
		statRow(statGrid, i, r[1], r[2], r[3])
	end
	local confirmAt = 0
	for i, sec in ipairs(sections()) do
		UI.text({ Text = sec[1], Size = UDim2.new(1, 0, 0, 28), TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i * 2 - 1, Parent = scroll })
		local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i * 2, Parent = scroll })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 56), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		for j, e in ipairs(sec[2]) do
			local label, cmd, a, b, style = e[1], e[2], e[3], e[4], e[5]
			UI.button({ Text = label, Style = style or "Teal", TextSize = 18, LayoutOrder = j, Parent = grid, OnClick = function(btn)
				if cmd == "ResetSave" then
					if os.clock() - confirmAt > 3 then
						confirmAt = os.clock()
						btn.Text = "Tap again to reset"
						task.delay(3, function()
							btn.Text = label
						end)
						return
					end
					confirmAt = 0
					btn.Text = label
				end
				run(btn, cmd, a, b)
			end })
		end
	end
	-- the always-visible Admin button
	local _, root = UI.screen("MystreeAdmin", 15)
	UI.button({ Name = "AdminButton", Text = "Admin", Style = "Red", Size = UDim2.fromOffset(96, 48), TextSize = 18,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Parent = root, OnClick = function()
			win.toggle()
		end })
end

function AdminPanel.toggle()
	if win then
		win.toggle()
	end
end

function AdminPanel.Start(c)
	C = c
	local function check()
		if player:GetAttribute("Admin") and not built then
			build()
		end
	end
	player:GetAttributeChangedSignal("Admin"):Connect(check)
	check()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.F2 and win then
			win.toggle()
		end
	end)
end

return AdminPanel
