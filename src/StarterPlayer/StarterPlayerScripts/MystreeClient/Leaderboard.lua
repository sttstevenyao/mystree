-- StarterPlayerScripts/MystreeClient/Leaderboard (ModuleScript)
-- The custom leaderboard (user, 2026-10-26: "add custom ui leaderboard"), in the jade kit:
--  * Roblox's default player list is hidden (re-applied for a few seconds; CoreScripts load late).
--  * A compact "Players 3 v" pill at the top-right. Below it, everyone in the server sorted by Power,
--    one slim row each (user: just the name and Power with its icon; VIP names in gold). Your own
--    row is highlighted. Tap a row for Inspect / Visit island.
--  * The global top lists (Power, Tree Level, Island Likes) are the Hall of Fame steles in the Village
--    (user: physical leaderboards, no button). The "Leaderboards" window below is kept but unused. It reads from
--    the workspace attribute "Boards" (LeaderboardService). Rows are reused, never rebuilt per frame.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)

local Leaderboard = {}
local C
local T = UI.T
local player = Players.LocalPlayer

local ROW_H = 56
local BOARD_BODY = 406 -- tallest Leaderboards body; short boards shrink the window
-- the always-open player list is compact (user: open by default, Tab toggles, smaller)
local LIST_H = 28
local LIST_W = 300
local MEDALS = { Color3.fromRGB(255, 206, 80), Color3.fromRGB(200, 206, 214), Color3.fromRGB(205, 140, 90) }
local HEART = Color3.fromRGB(240, 100, 120)
local WATCHED = { "CP", "Level", "TreeLevel", "IslandLikes", "Pass_VIP" }

-- ===================================================================== headshots (cached)
local thumbs = {} -- userId -> image id ("" while loading)
local waiting = {} -- userId -> { ImageLabel }

local function headshot(label, userId)
	if not userId or userId <= 0 then
		label.Image = ""
		return
	end
	local img = thumbs[userId]
	if img and img ~= "" then
		label.Image = img
		return
	end
	label.Image = ""
	waiting[userId] = waiting[userId] or {}
	table.insert(waiting[userId], label)
	if img == "" then
		return
	end
	thumbs[userId] = ""
	task.spawn(function()
		local ok, result = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		thumbs[userId] = ok and result or nil
		for _, l in ipairs(waiting[userId] or {}) do
			if l.Parent then
				l.Image = ok and result or ""
			end
		end
		waiting[userId] = nil
	end)
end

local function portrait(parent, size, x)
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(size, size), Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = T.Panel2, Parent = parent })
	UI.corner(size / 2, holder)
	UI.stroke(holder, T.Ornament, 2)
	local img = UI.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", Parent = holder })
	UI.corner(size / 2, img)
	return img
end

-- a small heart drawn from frames (two circles and a rotated square), so no glyph is needed
local function heart(parent, pos, size)
	local h = UI.new("Frame", { Size = UDim2.fromOffset(size, size), Position = pos, AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = parent })
	local r = size * 0.55
	for _, x in ipairs({ 0, size - r }) do
		UI.new("Frame", { Size = UDim2.fromOffset(r, r), Position = UDim2.fromOffset(x, size * 0.08), BackgroundColor3 = HEART, Parent = h }, { UI.corner(r) })
	end
	UI.new("Frame", { Size = UDim2.fromOffset(size * 0.62, size * 0.62), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.56, 0),
		Rotation = 45, BackgroundColor3 = HEART, Parent = h })
	return h
end

-- ===================================================================== hide the default list
local function hideDefaultList()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 8 do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
			task.wait(0.5)
		end
	end)
end

-- ===================================================================== the in-server list
local _, root = UI.screen("MystreeLeaderboard", 7)
-- left of the gear panel, under the top-right travel buttons
local pill = UI.new("TextButton", { Name = "PlayersPill", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(LIST_W, 40), AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 8), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.08, Parent = root })
UI.corner(20, pill)
UI.stroke(pill, T.PanelLine, 1.5, 0.2)
UI.bounce(pill)
local pillText = UI.text({ Text = "Players 1", Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(16, 0), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 18, Weight = Enum.FontWeight.Heavy, TextColor3 = T.TextLight, Parent = pill })
-- chevron from two bars; flips when open
local chevron = UI.new("Frame", { Size = UDim2.fromOffset(22, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -26, 0.5, 0), BackgroundTransparency = 1, Parent = pill })
for _, s in ipairs({ -1, 1 }) do
	UI.new("Frame", { Size = UDim2.fromOffset(14, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, s * 4.5, 0.5, 0), Rotation = s * -38,
		BackgroundColor3 = T.Gold, Parent = chevron }, { UI.corner(2) })
end

UI.text({ Text = "Tab", Size = UDim2.fromOffset(40, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -44, 0.5, 0), TextSize = 13,
	Weight = Enum.FontWeight.Bold, TextColor3 = T.InkSoft, Stroke = false, Parent = pill })
local drop = UI.new("Frame", { Name = "PlayerList", Size = UDim2.fromOffset(LIST_W, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 52),
	BackgroundColor3 = T.Panel, Visible = false, Parent = root })
UI.corner(10, drop)
UI.stroke(drop, T.PanelLine, 1.5, 0.15)
UI.ornaments(drop)
local list = UI.new("ScrollingFrame", { Name = "Rows", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -10), Position = UDim2.fromOffset(4, 5),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = T.Teal, Parent = drop })
UI.list(list, Enum.FillDirection.Vertical, 3)
UI.pad(list, 2, 2, 6, 2)
-- (no Leaderboards button here: the global top lists are the Hall of Fame steles in the Village)

local rows = {} -- player -> { Frame, Name, CP, Bg }
local dropOpen = false

-- Tab slides the whole board (pill and list) off the right edge of the screen and back (user)
local shown = true
local function setShown(on)
	shown = on
	local dx = on and 0 or LIST_W + 40
	local info = TweenInfo.new(on and 0.32 or 0.26, Enum.EasingStyle.Quint, on and Enum.EasingDirection.Out or Enum.EasingDirection.In)
	TweenService:Create(pill, info, { Position = UDim2.new(1, -14 + dx, 0, 8) }):Play()
	TweenService:Create(drop, info, { Position = UDim2.new(1, -14 + dx, 0, 52) }):Play()
end

local function setDrop(on)
	dropOpen = on
	TweenService:Create(chevron, TweenInfo.new(0.2), { Rotation = on and 180 or 0 }):Play()
	if on then
		local n = math.min(6, #Players:GetPlayers())
		drop.Size = UDim2.fromOffset(LIST_W, n * (LIST_H + 3) + 14)
		UI.popIn(drop, 0.85)
	elseif drop.Visible then
		UI.popOut(drop)
	end
end

-- the popover: Inspect / Visit island for one player
local pop = UI.new("Frame", { Name = "RowMenu", Size = UDim2.fromOffset(200, 132), BackgroundColor3 = T.Parchment, Visible = false, ZIndex = 20, Parent = root })
UI.corner(10, pop)
UI.stroke(pop, T.Ornament, 2.5)
local popName = UI.text({ Text = "", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 4), TextSize = 18, Weight = Enum.FontWeight.Heavy,
	TextColor3 = T.Ink, Stroke = false, ZIndex = 21, Parent = pop })
local popTarget
local inspectBtn = UI.button({ Text = "Inspect", Style = "Teal", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 30), TextSize = 19, Parent = pop,
	OnClick = function()
		pop.Visible = false
		if popTarget and popTarget.Parent and C.Inspect then
			C.Inspect.open(popTarget)
		end
	end })
local visitBtn = UI.button({ Text = "Visit island", Style = "Green", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 80), TextSize = 19, Parent = pop,
	OnClick = function()
		pop.Visible = false
		if not (popTarget and popTarget.Parent) then
			return
		end
		local ok, msg = C.Transition.travel("VisitIsland", popTarget.UserId, popTarget.DisplayName)
		if msg and C.Notify then
			C.Notify.toast(msg, ok and "Info" or "Error")
		end
		if ok then
			setDrop(false)
		end
	end })
for _, b in ipairs({ inspectBtn, visitBtn }) do
	b.ZIndex = 21
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 22
		end
	end
end

local function openPop(pl, row)
	popTarget = pl
	popName.Text = pl.DisplayName
	visitBtn.Visible = pl ~= player
	pop.Size = UDim2.fromOffset(200, pl == player and 82 or 132)
	-- to the left of the dropdown, level with the tapped row
	local scale = UI.fitScale()
	local y = (row.AbsolutePosition.Y - root.AbsolutePosition.Y) / scale
	local x = (drop.AbsolutePosition.X - root.AbsolutePosition.X) / scale - 208
	pop.Position = UDim2.fromOffset(x, y)
	UI.popIn(pop, 0.8)
end

local function makeRow(pl)
	local f = UI.new("TextButton", { Name = "Row", Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, LIST_H), BackgroundColor3 = T.Panel2,
		BackgroundTransparency = 0.2, Parent = list })
	UI.corner(4, f)
	local bg = UI.stroke(f, T.Gold, 1.2, 1)
	local name = UI.text({ Text = pl.DisplayName, Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(10, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15, Weight = Enum.FontWeight.SemiBold, TextColor3 = T.White, Stroke = false, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = f })
	-- Power: its icon, then the number
	UI.icon(f, "cp", 20, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -72, 0.5, 0) })
	local cp = UI.text({ Text = "", Size = UDim2.fromOffset(64, LIST_H), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15, Weight = Enum.FontWeight.Bold, TextColor3 = T.CP, Stroke = false, Parent = f })
	f.Activated:Connect(function()
		Sounds.play("Click")
		if pop.Visible and popTarget == pl then
			UI.popOut(pop)
		else
			openPop(pl, f)
		end
	end)
	rows[pl] = { Frame = f, Name = name, CP = cp, Bg = bg }
	return rows[pl]
end

local function fillRow(pl, r)
	r.Name.Text = pl.DisplayName
	r.Name.TextColor3 = (pl:GetAttribute("Pass_VIP") == true) and T.Gold or T.White
	r.CP.Text = Format.Num(pl:GetAttribute("CP") or 0)
	local me = pl == player
	r.Bg.Transparency = me and 0 or 1
	r.Frame.BackgroundColor3 = me and Color3.fromRGB(64, 92, 84) or T.Panel2
end

local function refreshList()
	local all = Players:GetPlayers()
	table.sort(all, function(a, b)
		local ca, cb = a:GetAttribute("CP") or 0, b:GetAttribute("CP") or 0
		if ca == cb then
			return a.Name < b.Name
		end
		return ca > cb
	end)
	for i, pl in ipairs(all) do
		local r = rows[pl] or makeRow(pl)
		r.Frame.LayoutOrder = i
		fillRow(pl, r)
	end
	pillText.Text = "Players " .. #all
	if dropOpen then
		local n = math.min(6, #all)
		drop.Size = UDim2.fromOffset(LIST_W, n * (LIST_H + 3) + 14)
	end
end

local refreshQueued = false
local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.delay(0.2, function()
		refreshQueued = false
		refreshList()
	end)
end

local function watch(pl)
	for _, a in ipairs(WATCHED) do
		pl:GetAttributeChangedSignal(a):Connect(queueRefresh)
	end
	queueRefresh()
end

pill.Activated:Connect(function()
	Sounds.play("Click")
	if pop.Visible then
		pop.Visible = false
	end
	setDrop(not dropOpen)
end)

-- ===================================================================== global boards window
local win, tabs
local boardPages = {} -- board id -> { List, Footer, Rows = { row refs } }
local TAB_OF = {} -- tab name -> board id

local function decodeBoards()
	local raw = workspace:GetAttribute("Boards")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and data or nil
end

local function boardRow(page, i)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, ROW_H), BackgroundColor3 = (i % 2 == 0) and T.Parchment2 or T.Parchment, LayoutOrder = i, Parent = page.List })
	UI.corner(8, f)
	local st = UI.stroke(f, T.OrangeDark, 2.5, 1)
	local medal = UI.new("Frame", { Size = UDim2.fromOffset(38, 38), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), BackgroundColor3 = T.White, Parent = f })
	UI.corner(19, medal)
	local medalStroke = UI.stroke(medal, T.Ink, 2)
	local rank = UI.text({ Text = tostring(i), Size = UDim2.fromScale(1, 1), TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = medal })
	local img = portrait(f, 42, 58)
	local name = UI.text({ Text = "", Size = UDim2.new(1, -300, 1, 0), Position = UDim2.fromOffset(112, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 21, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Scaled = true, MaxTextSize = 21, Parent = f })
	local value = UI.text({ Text = "", Size = UDim2.fromOffset(170, ROW_H), Position = UDim2.new(1, -184, 0, 0), TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 24, Weight = Enum.FontWeight.Heavy, Italic = true, TextColor3 = T.OrangeDark, Stroke = false, Parent = f })
	local r = { Frame = f, Stroke = st, Medal = medal, MedalStroke = medalStroke, Rank = rank, Img = img, Name = name, Value = value, UserId = nil }
	page.Rows[i] = r
	return r
end

local function ago(seconds)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m ago"
	end
	return math.floor(seconds / 3600) .. "h ago"
end

local function refreshBoards()
	if not win then
		return
	end
	local data = decodeBoards() or {}
	local most = 0
	for id, page in pairs(boardPages) do
		local entries = data[id] or {}
		local top = math.min(#entries, Config.Leaderboards.Top or 25)
		most = math.max(most, top)
		for i = 1, top do
			local e = entries[i]
			local r = page.Rows[i] or boardRow(page, i)
			r.Frame.Visible = true
			local rank = e.Rank or i
			r.Rank.Text = tostring(rank)
			local medal = MEDALS[rank]
			r.Medal.BackgroundColor3 = medal or T.Parchment2
			r.MedalStroke.Color = medal and medal:Lerp(Color3.new(0, 0, 0), 0.4) or T.InkSoft
			r.Name.Text = e.Name or "?"
			r.Value.Text = Format.Num(e.Value or 0)
			if r.UserId ~= e.UserId then
				r.UserId = e.UserId
				headshot(r.Img, e.UserId)
			end
			local me = e.UserId == player.UserId
			r.Stroke.Transparency = me and 0 or 1
		end
		for i = top + 1, #page.Rows do
			page.Rows[i].Frame.Visible = false
		end
		if data.Offline then
			page.Footer.Text = "Global boards appear in live servers."
		elseif top == 0 then
			page.Footer.Text = "No one on this board yet."
		elseif data.Updated then
			page.Footer.Text = "Updated " .. ago(math.max(0, os.time() - data.Updated))
		else
			page.Footer.Text = ""
		end
	end
	-- as tall as the longest board's rows (+ padding and the footer), up to the full window;
	-- the same height for every tab so switching boards doesn't jump
	UI.fitWindow(win, math.min(BOARD_BODY, math.max(1, most) * (ROW_H + 6) + 16 + 34))
end

local function buildPage(id)
	return function(page)
		local list = UI.new("ScrollingFrame", { Name = "Board", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -34), CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = T.TealDark, Parent = page })
		UI.list(list, Enum.FillDirection.Vertical, 6)
		UI.pad(list, 4, 4, 4, 4)
		UI.autoScrollBar(list, 8)
		local footer = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -28), TextSize = 18, Weight = Enum.FontWeight.Bold,
			TextColor3 = T.InkSoft, Stroke = false, Parent = page })
		boardPages[id] = { List = list, Footer = footer, Rows = {} }
	end
end

local function buildWindow()
	win = UI.window({ Title = "Leaderboards", Size = Vector2.new(760, 74 + BOARD_BODY), OnOpen = refreshBoards })
	local defs = {}
	for _, b in ipairs(Config.Leaderboards.Boards) do
		TAB_OF[b.Name] = b.Id
		table.insert(defs, { Name = b.Name, Build = buildPage(b.Id) })
	end
	tabs = UI.tabs(win, defs)
	tabs.select(Config.Leaderboards.Boards[1].Name)
end

-- ===================================================================== public
-- tab: a board name ("Combat Power") or id ("CP")
function Leaderboard.open(tab)
	if not win then
		buildWindow()
	end
	if dropOpen then
		setDrop(false)
	end
	pop.Visible = false
	if tab then
		for _, b in ipairs(Config.Leaderboards.Boards) do
			if b.Id == tab or b.Name == tab then
				tabs.select(b.Name)
			end
		end
	end
	win.open()
	refreshBoards()
end

function Leaderboard.close()
	if win then
		win.close()
	end
	setDrop(false)
	pop.Visible = false
end

function Leaderboard.Start(c)
	C = c
	hideDefaultList()
	-- open by default; Tab (or gamepad Select-less: the pill) toggles it
	task.delay(1.5, function()
		if not dropOpen then
			setDrop(true)
		end
	end)
	-- the Inspect / Visit popover closes on any click or tap outside it
	game:GetService("UserInputService").InputBegan:Connect(function(input)
		local t = input.UserInputType
		if pop.Visible and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			local p, a, s = input.Position, pop.AbsolutePosition, pop.AbsoluteSize
			local inset = game:GetService("GuiService"):GetGuiInset()
			local x, y = p.X, p.Y - inset.Y
			if x < a.X or x > a.X + s.X or y < a.Y or y > a.Y + s.Y then
				task.defer(function()
					if pop.Visible then
						UI.popOut(pop)
					end
				end)
			end
		end
	end)
	game:GetService("ContextActionService"):BindAction("MystreeLeaderboard", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			pop.Visible = false
			setShown(not shown)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Tab)
	for _, pl in ipairs(Players:GetPlayers()) do
		watch(pl)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(pl)
		local r = rows[pl]
		if r then
			r.Frame:Destroy()
			rows[pl] = nil
		end
		if popTarget == pl then
			pop.Visible = false
		end
		thumbs[pl.UserId] = nil
		queueRefresh()
	end)
	workspace:GetAttributeChangedSignal("Boards"):Connect(function()
		if win and UI.isOpen(win) then
			refreshBoards()
		end
	end)
	-- the "Updated 1m ago" footer ticks while the window is open
	task.spawn(function()
		while true do
			task.wait(30)
			if win and UI.isOpen(win) then
				refreshBoards()
			end
		end
	end)
	refreshList()
end

return Leaderboard
