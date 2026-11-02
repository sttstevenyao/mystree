-- StarterPlayerScripts/MystreeClient/Odds (ModuleScript)
-- One "Odds" window for everything random that Robux reaches, directly or through Spirit Stones
-- (Roblox paid random item policy):
--  * Odds.summon(back): every spirit beast with its chance for your NEXT summon, pity included
--    (Rules.summonOdds: the table the server rolls from).
--  * Odds.gear(title, opts, back): drop chance per rarity at your tree level, with your gear luck,
--    island luck, Lucky Incense and Fortune Charm (GearLuck from the server) plus opts (Min, Shift).
--  * Odds.text(p): a chance as text that never shows a real chance as 0%.
-- `back` is the window to reopen when the odds are closed (one window is open at a time).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Net = require(ReplicatedStorage.Mystree.Net)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Odds = {}
local T = UI.T
local player = Players.LocalPlayer

local win, list, note
local backTo

-- 0.0372 -> "3.72%", 0.000167 -> "0.0167%": three significant digits, never rounded down to 0
function Odds.text(p)
	local v = p * 100
	if v <= 0 then
		return "0%"
	elseif v >= 10 then
		return string.format("%.1f%%", v)
	end
	local digits = math.max(2, 2 - math.floor(math.log10(v)))
	return string.format("%." .. digits .. "f%%", v)
end

local function build()
	win = UI.window({ Title = "Odds", Size = Vector2.new(560, 520), OnClose = function()
		local back = backTo
		backTo = nil
		-- back to the window the odds were opened from, unless another window took over
		task.defer(function()
			if back and UI.current() == nil then
				back.open()
			end
		end)
	end })
	note = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 44), TextSize = 16, TextColor3 = T.InkSoft, Stroke = false, TextWrapped = true, Parent = win.Body })
	list = UI.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = T.TealDark, Parent = win.Body })
	UI.list(list, Enum.FillDirection.Vertical, 4)
	UI.pad(list, 2, 2, 12, 2)
	UI.autoScrollBar(list)
end

-- rows: { { Name, R, P } }
local function show(title, text, rows, back)
	if not win then
		build()
	end
	win.Title.Text = title
	note.Text = text
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local total = 0
	for i, r in ipairs(rows) do
		total += r.P
		local rr = Config.Rarities[r.R]
		local row = UI.new("Frame", { BackgroundColor3 = rr.Color, BackgroundTransparency = 0.78, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i, Parent = list })
		UI.corner(5, row)
		UI.text({ Text = r.Name, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 17, Weight = Enum.FontWeight.Bold,
			TextColor3 = T.Ink, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.text({ Text = rr.Name, Size = UDim2.new(0.25, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), TextSize = 16, Weight = Enum.FontWeight.Bold,
			TextColor3 = rr.Color:Lerp(Color3.new(0, 0, 0), 0.55), Stroke = false, Parent = row })
		UI.text({ Text = Odds.text(r.P), Size = UDim2.new(0.25, -10, 1, 0), Position = UDim2.fromScale(0.75, 0), TextSize = 17, Weight = Enum.FontWeight.Heavy,
			TextColor3 = T.Ink, Stroke = false, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	end
	UI.text({ Text = "Total " .. Odds.text(total), Size = UDim2.new(1, -10, 0, 26), TextSize = 15, TextColor3 = T.InkSoft, Stroke = false,
		TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = #rows + 1, Parent = list })
	-- sized to the list (no empty paper under it), up to the tallest window
	UI.fitWindow(win, math.min(446, 50 + 4 + #rows * 38 + 30 + 14))
	backTo = back
	win.open()
end

function Odds.summon(back)
	local pity = State.SummonPity or 0
	local rows = {}
	for _, o in ipairs(Rules.summonOdds(pity)) do
		table.insert(rows, { Name = Config.Companions[o.Id].Name, R = o.R, P = o.P })
	end
	local left = Config.SummonPity - pity
	local text = left <= 1 and "Your next summon is a guaranteed Legendary or better."
		or string.format("Chances for your next summon. A Legendary or better is guaranteed within %d summons.", left)
	show("Summon odds", text, rows, back)
end

-- the rarity of a gear drop from your tree (opts: Min = lowest rarity, Shift = tiers up)
function Odds.gear(title, opts, back)
	local luck = Net.invoke("GearLuck")
	luck = type(luck) == "table" and luck or {}
	luck.Min, luck.Shift = opts and opts.Min, opts and opts.Shift
	local level = player:GetAttribute("TreeLevel") or 1
	local chance = Rules.normalize(Rules.weightsFor(level, luck))
	local rows = {}
	for r = #chance, 1, -1 do
		if chance[r] > 0 then
			table.insert(rows, { Name = (opts and opts.Item) or "Gear", R = r, P = chance[r] })
		end
	end
	local boosts = {}
	if luck.Incense then
		table.insert(boosts, "Lucky Incense")
	end
	if luck.Charm then
		table.insert(boosts, "Fortune Charm")
	end
	if (luck.Luck or 0) > 0 then
		table.insert(boosts, string.format("+%d%% luck", math.floor(luck.Luck * 100 + 0.5)))
	end
	local text = string.format("At your tree level (%d)%s.", level, #boosts > 0 and (", with " .. table.concat(boosts, ", ")) or "")
	show(title, text, rows, back)
end

function Odds.window()
	return win
end

return Odds
