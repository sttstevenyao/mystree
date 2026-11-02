-- StarterPlayerScripts/MystreeClient/Island (ModuleScript)
-- Island customization on the client (the server is IslandService):
--  * The Island window: Decor (buy with Scraps, place from your stash, buffs), Themes (unlock/use),
--    Islands (everyone on the server: visit their island).
--  * Placement mode: a see-through ghost follows the mouse (or the screen centre on touch), snaps to
--    Config.Island.Grid, turns green/red from Rules.canPlace (the same check the server runs), R/Q or
--    the Rotate button turn it 45 degrees, click/tap places it. Keeps placing while the stash has more.
--  * Edit mode: tap a placed piece to Move / Rotate / Store it.
--  * Visiting pill: on someone else's island, their name and likes with a Like and a Home button.
-- Island-local coordinates: studs from the island centre (the plot's Root), +Z toward the Village.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Island = {}
local C
local FULL_BODY = 426 -- Island window body height for the Decor and Themes card grids
local T = UI.T
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GREEN = Color3.fromRGB(110, 220, 120)
local RED = Color3.fromRGB(235, 80, 70)

local win, tabs
local refs = { DecorCards = {}, ThemeCards = {}, IslandRows = {} }

-- ===================================================================== helpers
local function island()
	local i = State.Island
	if type(i) ~= "table" then
		return { Theme = "Meadow", Themes = { Meadow = true }, Decor = {}, Stash = {}, Likes = 0 }
	end
	i.Decor = i.Decor or {}
	i.Stash = i.Stash or {}
	i.Themes = i.Themes or { Meadow = true }
	return i
end

local function toast(text, kind)
	if C and C.Notify and text then
		C.Notify.toast(text, kind)
	end
end

local function fail(msg)
	Sounds.play("Error")
	toast(msg, "Error")
end

local function myPlot()
	local name = player:GetAttribute("Plot")
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return name and plots and plots:FindFirstChild(name)
end

local function plotOf(pl)
	local name = pl:GetAttribute("Plot")
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return name and plots and plots:FindFirstChild(name)
end

-- On your own island? (within the island radius of its centre, horizontally)
local function onOwnIsland()
	local plot = myPlot()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (plot and plot.PrimaryPart and hrp) then
		return false
	end
	local d = (hrp.Position - plot.PrimaryPart.Position) * Vector3.new(1, 0, 1)
	return d.Magnitude <= Config.Map.IslandRadius + 6
end

local function decorModel(id)
	local ok, m = pcall(function()
		return Assets.Decor and Assets.Decor(id)
	end)
	if ok and m then
		return m
	end
	-- fallback until Assets.Decor exists: a simple marker post
	local model = Instance.new("Model")
	local p = Instance.new("Part")
	p.Name = "Root"
	p.Anchored = true
	p.Size = Vector3.new(1.4, 3, 1.4)
	p.CFrame = CFrame.new(0, 1.5, 0)
	p.Material = Enum.Material.Wood
	p.Color = Color3.fromRGB(150, 116, 80)
	p.Parent = model
	model.PrimaryPart = p
	return model
end

local function buffText(def)
	local b = def.Buff
	if not b then
		return ""
	end
	if b.Kind == "Luck" then
		return "Drop Luck +" .. Format.Pct(b.Value)
	elseif b.Kind == "ScrapBonus" then
		return "+" .. Format.Pct(b.Value) .. " Peaches"
	end
	return ""
end

local MAT_NAMES = { BloodAmber = "Blood Amber", Sunstone = "Sunstone" }

-- requirement text and whether it's met (themes)
local function unlockInfo(unlock)
	local parts, met = {}, true
	if unlock.TreeLevel then
		table.insert(parts, "Tree Lv " .. unlock.TreeLevel)
		met = met and (player:GetAttribute("TreeLevel") or 1) >= unlock.TreeLevel
	end
	if unlock.Scraps then
		table.insert(parts, Format.Num(unlock.Scraps) .. " Peaches")
		met = met and (player:GetAttribute("Scraps") or 0) >= unlock.Scraps
	end
	for mat, name in pairs(MAT_NAMES) do
		if unlock[mat] then
			table.insert(parts, unlock[mat] .. " " .. name)
			met = met and (player:GetAttribute("Mat_" .. mat) or 0) >= unlock[mat]
		end
	end
	if #parts == 0 then
		return "Free", true
	end
	return table.concat(parts, " + "), met
end

-- ===================================================================== placement
local placeGui, placeRoot = UI.screen("MystreeIsland", 26)
local bar = UI.new("Frame", { Name = "PlaceBar", BackgroundColor3 = T.Panel, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(620, 96),
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Visible = false, Parent = placeRoot })
UI.corner(12, bar)
UI.stroke(bar, T.Ornament, 2)
local barTitle = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 4), TextSize = 19, Weight = Enum.FontWeight.Heavy, Parent = bar })
local barRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 62), Position = UDim2.fromOffset(10, 30), Parent = bar })
UI.list(barRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local reasonLabel = UI.text({ Text = "", Size = UDim2.fromOffset(420, 30), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -118),
	TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = RED, Visible = false, Parent = placeRoot })

local place = {
	Active = false, Id = nil, Skip = nil, R = 0, X = 0, Z = 0, Ok = false, Reason = nil,
	Ghost = nil, Ring = nil, Highlight = nil, Conn = nil, Busy = false,
}
local edit = { Active = false, Selected = nil, Highlight = nil }

local function clearBar()
	for _, ch in ipairs(barRow:GetChildren()) do
		if ch:IsA("GuiButton") then
			ch:Destroy()
		end
	end
end

local function barButton(text, style, order, onClick)
	return UI.button({ Text = text, Style = style, Size = UDim2.fromOffset(150, 60), TextSize = 21, LayoutOrder = order, Parent = barRow, OnClick = onClick })
end

local function destroyGhost()
	if place.Conn then
		place.Conn:Disconnect()
		place.Conn = nil
	end
	if place.Ghost then
		place.Ghost:Destroy()
		place.Ghost = nil
	end
	if place.Ring then
		place.Ring:Destroy()
		place.Ring = nil
	end
end

local function stopPlacing()
	place.Active = false
	place.Id = nil
	place.Skip = nil
	destroyGhost()
	reasonLabel.Visible = false
	if not edit.Active then
		bar.Visible = false
	end
end

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- where the pointer (or screen centre on touch) meets the island's ground plane, island-local
local function pointerLocal()
	local plot = myPlot()
	if not (plot and plot.PrimaryPart) then
		return nil
	end
	local root = plot.PrimaryPart.CFrame
	local screen
	if isTouch() then
		screen = camera.ViewportSize / 2
	else
		screen = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil
	end
	local world = ray.Origin + ray.Direction * t
	local l = root:PointToObjectSpace(world)
	local g = Config.Island.Grid
	return math.floor(l.X / g + 0.5) * g, math.floor(l.Z / g + 0.5) * g, root
end

local function makeGhost(id)
	destroyGhost()
	local m = decorModel(id)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = math.max(p.Transparency, 0.45)
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("Sound") then
			p:Destroy()
		end
	end
	m.Name = "DecorGhost"
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = m
	m.Parent = workspace
	local def = Config.Decor[id]
	local ring = Instance.new("Part")
	ring.Name = "DecorRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.6
	ring.Size = Vector3.new(0.1, def.Radius * 2, def.Radius * 2)
	ring.Parent = workspace
	place.Ghost, place.Ring, place.Highlight = m, ring, hl
end

local function updateGhost()
	if not (place.Active and place.Ghost) then
		return
	end
	local x, z, root = pointerLocal()
	if not x then
		return
	end
	place.X, place.Z = x, z
	local ok, reason = Rules.canPlace(island().Decor, place.Id, x, z, place.Skip)
	place.Ok, place.Reason = ok, reason
	local cf = root * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(place.R), 0)
	place.Ghost:PivotTo(cf)
	-- ground ring 0.06 above the grass so it never z-fights the ground
	place.Ring.CFrame = root * CFrame.new(x, 0.06, z) * CFrame.Angles(0, 0, math.rad(90))
	local col = ok and GREEN or RED
	place.Ring.Color = col
	place.Highlight.FillColor = col
	place.Highlight.OutlineColor = col
	reasonLabel.Visible = not ok
	reasonLabel.Text = reason or ""
end

local function rotate()
	if place.Active then
		place.R = (place.R + 45) % 360
		updateGhost()
	end
end

local function confirmPlace()
	if not place.Active or place.Busy then
		return
	end
	updateGhost()
	if not place.Ok then
		fail(place.Reason or "Can't place it there.")
		return
	end
	place.Busy = true
	local id, skip = place.Id, place.Skip
	local ok, msg
	if skip then
		ok, msg = Net.invoke("MoveDecor", skip, place.X, place.Z, place.R)
	else
		ok, msg = Net.invoke("PlaceDecor", id, place.X, place.Z, place.R)
	end
	place.Busy = false
	if not ok then
		fail(msg or "Can't place it there.")
		return
	end
	Sounds.play("Pop")
	if skip then
		stopPlacing()
		return
	end
	-- keep placing while the stash still holds more of this piece (the server just took one)
	local left = (island().Stash[id] or 0) - 1
	if left > 0 then
		barTitle.Text = string.format("Placing %s · %d more in your stash", Config.Decor[id].Name, left)
	else
		stopPlacing()
	end
end

local function showPlaceBar()
	clearBar()
	bar.Visible = true
	barButton("Rotate", "Teal", 1, rotate)
	if isTouch() then
		barButton("Place here", "Green", 2, confirmPlace)
	end
	barButton("Done", "Orange", 3, function()
		stopPlacing()
	end)
end

-- Begin placing a decor piece from your stash (skip = index of a placed piece being moved)
function Island.startPlacing(id, skip, startR)
	if not Config.Decor[id] then
		return
	end
	if not onOwnIsland() then
		toast("Go to your island first.", "Info")
		C.Transition.travel("Travel", "Home")
		return
	end
	if not skip and (island().Stash[id] or 0) <= 0 then
		fail("Buy one first in the Island window.")
		return
	end
	if win then
		win.close()
	end
	place.Active, place.Id, place.Skip, place.R = true, id, skip, startR or 0
	makeGhost(id)
	showPlaceBar()
	local pc = isTouch() and "Aim with the camera, then tap Place here" or "Click to place · R / Q to rotate"
	barTitle.Text = (skip and "Moving " or "Placing ") .. Config.Decor[id].Name .. "  ·  " .. pc
	place.Conn = RunService.Heartbeat:Connect(updateGhost)
end

function Island.isPlacing()
	return place.Active
end

-- placing or editing decor: clicks belong to the island editor
function Island.isEditing()
	return place.Active or edit.Active
end

-- ===================================================================== edit mode
local function clearSelection()
	if edit.Highlight then
		edit.Highlight:Destroy()
		edit.Highlight = nil
	end
	edit.Selected = nil
end

local function stopEdit()
	edit.Active = false
	clearSelection()
	if not place.Active then
		bar.Visible = false
	end
end

local function selectedEntry()
	local m = edit.Selected
	local idx = m and m:GetAttribute("DecorIndex")
	return idx, idx and island().Decor[idx]
end

local function showEditBar()
	clearBar()
	bar.Visible = true
	if edit.Selected then
		local _, entry = selectedEntry()
		barTitle.Text = "Editing " .. (entry and Config.Decor[entry.Id] and Config.Decor[entry.Id].Name or "piece")
		barButton("Move", "Teal", 1, function()
			local idx, e = selectedEntry()
			if e then
				clearSelection()
				Island.startPlacing(e.Id, idx, e.R or 0)
			end
		end)
		barButton("Rotate", "Teal", 2, function()
			local idx, e = selectedEntry()
			if e then
				local ok, msg = Net.invoke("MoveDecor", idx, e.X, e.Z, ((e.R or 0) + 45) % 360)
				if ok then
					Sounds.play("Click")
				else
					fail(msg)
				end
			end
		end)
		barButton("Store", "Green", 3, function()
			local idx = selectedEntry()
			if idx then
				local ok, msg = Net.invoke("StoreDecor", idx)
				if ok then
					Sounds.play("Pop")
					toast(msg or "Back in your stash.", "Info")
					clearSelection()
					showEditBar()
				else
					fail(msg)
				end
			end
		end)
	else
		barTitle.Text = (isTouch() and "Tap" or "Click") .. " a piece on your island to edit it"
	end
	barButton("Done", "Orange", 4, stopEdit)
end

function Island.startEdit()
	if not onOwnIsland() then
		toast("Go to your island first.", "Info")
		C.Transition.travel("Travel", "Home")
		return
	end
	if win then
		win.close()
	end
	stopPlacing()
	edit.Active = true
	clearSelection()
	showEditBar()
end

local function pickDecor(screenPos)
	local plot = myPlot()
	local folder = plot and plot:FindFirstChild("Decor")
	if not folder then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	-- decor parts are usually CanQuery=false, so test each piece's bounding box along the ray instead
	local best, bestT
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("DecorIndex") then
			local cf, size = m:GetBoundingBox()
			local lo = cf:PointToObjectSpace(ray.Origin)
			local ld = cf:VectorToObjectSpace(ray.Direction)
			local tmin, tmax = 0, 1e9
			local hit = true
			for _, axis in ipairs({ "X", "Y", "Z" }) do
				local o, d, h = lo[axis], ld[axis], size[axis] / 2 + 0.5
				if math.abs(d) < 1e-6 then
					if math.abs(o) > h then
						hit = false
					end
				else
					local t1, t2 = (-h - o) / d, (h - o) / d
					if t1 > t2 then
						t1, t2 = t2, t1
					end
					tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
					if tmin > tmax then
						hit = false
					end
				end
			end
			if hit and (not bestT or tmin < bestT) then
				best, bestT = m, tmin
			end
		end
	end
	return best
end

-- ===================================================================== input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local kc = input.KeyCode
	if place.Active and (kc == Enum.KeyCode.R or kc == Enum.KeyCode.Q) then
		rotate()
		return
	end
	local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTap = input.UserInputType == Enum.UserInputType.Touch
	if place.Active and isClick then
		confirmPlace()
	elseif edit.Active and not place.Active and (isClick or isTap) then
		local pos = isClick and UserInputService:GetMouseLocation() or Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		local m = pickDecor(pos)
		clearSelection()
		if m then
			edit.Selected = m
			local hl = Instance.new("Highlight")
			hl.FillColor = T.Gold
			hl.OutlineColor = T.Gold
			hl.FillTransparency = 0.7
			hl.Parent = m
			edit.Highlight = hl
			Sounds.play("Click")
		end
		showEditBar()
	end
end)

-- ===================================================================== window: Decor tab
local function buildDecorPage(page)
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), Parent = page })
	refs.Pieces = UI.text({ Text = "", Size = UDim2.new(0.6, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22,
		Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = head })
	refs.Buffs = UI.text({ Text = "", Size = UDim2.new(0.62, 0, 0, 26), Position = UDim2.fromOffset(0, 32), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 17, TextColor3 = T.GreenDark, Stroke = false, Parent = head })
	UI.button({ Text = "Edit island", Style = "Teal", Size = UDim2.fromOffset(190, 56), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 2),
		TextSize = 21, Parent = head, OnClick = function()
			Island.startEdit()
		end })
	local grid = UI.new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -68), Position = UDim2.fromOffset(0, 68),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = T.TealDark, Parent = page })
	-- four cards that span the width; the bar only shows when the list overflows
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 272), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UI.pad(grid, 4, 4, 4, 4)
	UI.autoScrollBar(grid, 8)
	for i, id in ipairs(Config.DecorOrder) do
		local def = Config.Decor[id]
		local card = UI.new("Frame", { Name = id, BackgroundColor3 = T.Panel, LayoutOrder = i, Parent = grid })
		UI.corner(10, card)
		UI.stroke(card, def.Buff and T.Gold or T.PanelLine, def.Buff and 2.5 or 1.5)
		local vp = UI.new("ViewportFrame", { Size = UDim2.new(1, -12, 0, 104), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = T.Panel2,
			Ambient = Color3.fromRGB(170, 170, 170), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -1.4, -1), Parent = card })
		UI.corner(8, vp)
		UI.setModel(vp, decorModel(id), 30, -20, 1)
		UI.text({ Text = def.Name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 112), TextSize = 19, Weight = Enum.FontWeight.Heavy,
			Scaled = true, MaxTextSize = 19, Parent = card })
		local info = UI.text({ Text = def.Buff and buffText(def) or (def.Desc or ""), Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(6, 138), TextSize = 15,
			TextColor3 = def.Buff and T.Gold or T.TextLight, Parent = card })
		-- price: the Scraps icon and the number (or "Tree Lv N" while locked)
		local priceIcon = UI.icon(card, "peach", 24, { Position = UDim2.fromOffset(6, 176) })
		local price = UI.text({ Text = "", Size = UDim2.new(0.6, -28, 0, 24), Position = UDim2.fromOffset(34, 176), TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 19, Weight = Enum.FontWeight.Heavy, Parent = card })
		local stash = UI.text({ Text = "", Size = UDim2.new(0.4, -8, 0, 24), Position = UDim2.new(0.6, 0, 0, 176), TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 17, TextColor3 = T.Cream, Parent = card })
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 60), Position = UDim2.new(0, 6, 1, -66), Parent = card })
		UI.list(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local buy = UI.button({ Text = "Buy", Style = "Green", Size = UDim2.fromOffset(92, 60), TextSize = 20, LayoutOrder = 1, Parent = row, OnClick = function(b)
			local ok, msg = Net.invoke("BuyDecor", id)
			if ok then
				Sounds.play("Coin")
				toast(msg or (def.Name .. " added to your stash."), "Info")
			else
				fail(msg)
				task.spawn(UI.shake, b)
			end
		end })
		local placeBtn = UI.button({ Text = "Place", Style = "Orange", Size = UDim2.fromOffset(92, 60), TextSize = 20, LayoutOrder = 2, Parent = row, OnClick = function()
			Island.startPlacing(id)
		end })
		refs.DecorCards[id] = { Price = price, PriceIcon = priceIcon, Stash = stash, Buy = buy, Place = placeBtn, Info = info }
	end
end

-- ===================================================================== window: Themes tab
local function buildThemesPage(page)
	local grid = UI.new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = T.TealDark, Parent = page })
	-- two rows of four fill the page, so all seven themes show without scrolling
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 200), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UI.pad(grid, 4, 4, 4, 4)
	UI.autoScrollBar(grid, 8)
	for i, id in ipairs(Config.ThemeOrder) do
		local th = Config.Themes[id]
		local card = UI.new("Frame", { Name = id, BackgroundColor3 = T.Panel, LayoutOrder = i, Parent = grid })
		UI.corner(10, card)
		local stroke = UI.stroke(card, T.PanelLine, 2)
		-- swatch: grass band with leaf, earth and rock chips
		local sw = UI.new("Frame", { Size = UDim2.new(1, -12, 0, 62), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = th.Grass, Parent = card })
		UI.corner(8, sw)
		UI.list(sw, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		for j, col in ipairs({ th.Leaf or th.Grass:Lerp(Color3.new(1, 1, 1), 0.2), th.Earth, th.Rock, th.Slate }) do
			UI.new("Frame", { Size = UDim2.fromOffset(34, 34), BackgroundColor3 = col, LayoutOrder = j, Parent = sw }, { UI.corner(17), UI.new("UIStroke", { Color = Color3.fromRGB(20, 20, 20), Thickness = 1.5 }) })
		end
		UI.text({ Text = th.Name, Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 72), TextSize = 21, Weight = Enum.FontWeight.Heavy, Parent = card })
		local req = UI.text({ Text = "", Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 100), TextSize = 16, Parent = card })
		local btn = UI.button({ Text = "", Style = "Green", Size = UDim2.fromOffset(180, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
			TextSize = 21, Parent = card, OnClick = function(b)
				local isl = island()
				if isl.Theme == id then
					return
				end
				local ok, msg = Net.invoke("SetTheme", id)
				if ok then
					Sounds.play("Epic", 1.1, 0.6)
					toast(msg or (th.Name .. " is on!"), "Growth")
				else
					fail(msg)
					task.spawn(UI.shake, b)
				end
			end })
		refs.ThemeCards[id] = { Req = req, Button = btn, Stroke = stroke }
	end
end

-- ===================================================================== window: Islands tab
local function buildIslandsPage(page)
	refs.IslandList = UI.new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = T.TealDark, Parent = page })
	UI.list(refs.IslandList, Enum.FillDirection.Vertical, 8)
	UI.pad(refs.IslandList, 4, 4, 4, 4)
	UI.autoScrollBar(refs.IslandList, 8)
end

local function islandRow(pl, order)
	local row = UI.new("Frame", { Name = tostring(pl.UserId), BackgroundColor3 = T.Panel, Size = UDim2.new(1, 0, 0, 78), LayoutOrder = order, Parent = refs.IslandList })
	UI.corner(10, row)
	UI.stroke(row, pl == player and T.Gold or T.PanelLine, pl == player and 2.5 or 1.5)
	local head = UI.new("ImageLabel", { Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = T.Panel2, Parent = row })
	UI.corner(31, head)
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok and head.Parent then
			head.Image = img
		end
	end)
	UI.text({ Text = pl == player and "Your island" or (pl.DisplayName .. "'s Island"), Size = UDim2.new(1, -330, 0, 30), Position = UDim2.fromOffset(80, 8),
		TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22, Weight = Enum.FontWeight.Heavy, Parent = row })
	local themeId = pl:GetAttribute("IslandTheme") or "Meadow"
	local themeName = Config.Themes[themeId] and Config.Themes[themeId].Name or themeId
	UI.text({ Text = string.format("Tree Lv %d · %s · %s likes", pl:GetAttribute("TreeLevel") or 1, themeName, Format.Num(pl:GetAttribute("IslandLikes") or 0)),
		Size = UDim2.new(1, -330, 0, 24), Position = UDim2.fromOffset(80, 42), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 17,
		TextColor3 = T.TextLight, Parent = row })
	if pl == player then
		UI.button({ Text = "Go home", Style = "Green", Size = UDim2.fromOffset(170, 60), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			TextSize = 21, Parent = row, OnClick = function()
				win.close()
				C.Transition.travel("Travel", "Home")
			end })
	else
		UI.button({ Text = "Visit", Style = "Orange", Size = UDim2.fromOffset(170, 60), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			TextSize = 22, Parent = row, OnClick = function()
				local ok, msg = C.Transition.travel("VisitIsland", pl.UserId, pl.DisplayName)
				if ok then
					win.close()
				else
					fail(msg)
				end
			end })
	end
end

-- ===================================================================== refresh
function Island.refresh()
	if not win then
		return
	end
	local isl = island()
	local scraps = player:GetAttribute("Scraps") or 0
	local treeLevel = player:GetAttribute("TreeLevel") or 1
	if refs.Pieces then
		refs.Pieces.Text = string.format("Pieces: %d / %d", #isl.Decor, Config.Island.MaxDecor)
		local b = Rules.decorBuffs(isl.Decor)
		local parts = {}
		if b.Luck > 0 then
			table.insert(parts, "Drop Luck +" .. Format.Pct(b.Luck))
		end
		if b.ScrapBonus > 0 then
			table.insert(parts, "+" .. Format.Pct(b.ScrapBonus) .. " Peaches")
		end
		refs.Buffs.Text = #parts > 0 and ("Island buffs: " .. table.concat(parts, " · ")) or "Island buffs: none yet (look for gold-framed pieces)"
	end
	for id, card in pairs(refs.DecorCards) do
		local def = Config.Decor[id]
		local locked = def.MinTree and treeLevel < def.MinTree
		card.Price.Text = locked and ("Tree Lv " .. def.MinTree) or Format.Commas(def.Price)
		card.PriceIcon.Visible = not locked
		card.Price.TextColor3 = (locked or scraps < def.Price) and RED or T.Gold
		local n = isl.Stash[id] or 0
		card.Stash.Text = n > 0 and ("Stash: " .. n) or ""
		card.Place.Visible = n > 0
		UI.restyle(card.Buy, locked and "Grey" or "Green")
	end
	for id, card in pairs(refs.ThemeCards) do
		local th = Config.Themes[id]
		local owned = isl.Themes[id] == true or id == "Meadow"
		local inUse = isl.Theme == id
		local text, met = unlockInfo(th.Unlock or {})
		card.Req.Text = owned and "Unlocked" or ("Needs " .. text)
		card.Req.TextColor3 = (owned or met) and GREEN or Color3.fromRGB(240, 170, 160)
		card.Stroke.Color = inUse and T.Gold or T.PanelLine
		if inUse then
			card.Button.Text = "In use"
			UI.restyle(card.Button, "Cream")
		elseif owned then
			card.Button.Text = "Use"
			UI.restyle(card.Button, "Green")
		else
			card.Button.Text = "Unlock"
			UI.restyle(card.Button, met and "Orange" or "Grey")
		end
	end
	if refs.IslandList and tabs and tabs.Current == "Islands" then
		for _, ch in ipairs(refs.IslandList:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		local list = Players:GetPlayers()
		table.sort(list, function(a, b)
			if a == player then
				return true
			elseif b == player then
				return false
			end
			return (a:GetAttribute("IslandLikes") or 0) > (b:GetAttribute("IslandLikes") or 0)
		end)
		for i, pl in ipairs(list) do
			islandRow(pl, i)
		end
		local h = #list * 86
		if #list == 1 then
			local hint = UI.new("Frame", { Name = "Alone", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 99, Parent = refs.IslandList })
			UI.text({ Text = "No one else is here yet. When players join, their islands show up here to visit and like.", Size = UDim2.fromScale(1, 1),
				TextSize = 18, Weight = Enum.FontWeight.Bold, TextColor3 = T.InkSoft, Stroke = false, Parent = hint })
			h += 60
		end
		-- the list is as tall as its rows (up to the full window)
		UI.fitWindow(win, math.min(FULL_BODY, h + 8))
	elseif tabs then
		UI.fitWindow(win, FULL_BODY)
	end
end

function Island.open(tab)
	if not win then
		return
	end
	win.open()
	tabs.select(tab or tabs.Current or "Decor")
	Island.refresh()
end

function Island.close()
	if win then
		win.close()
	end
end

-- ===================================================================== visiting pill
local _, pillRoot = UI.screen("MystreeVisit", 21)
local pill = UI.new("Frame", { Name = "Visiting", Size = UDim2.fromOffset(440, 72), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54),
	BackgroundColor3 = T.Parchment, Visible = false, Parent = pillRoot })
UI.corner(36, pill)
UI.stroke(pill, T.Ornament, 3)
local pillText = UI.text({ Text = "", Size = UDim2.new(1, -230, 1, 0), Position = UDim2.fromOffset(24, 0), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Scaled = true, MaxTextSize = 20, Parent = pill })
local likeBtn = UI.button({ Text = "Like", Style = "Red", Size = UDim2.fromOffset(100, 56), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -116, 0.5, 0),
	TextSize = 20, Parent = pill })
local homeBtn = UI.button({ Text = "Home", Style = "Green", Size = UDim2.fromOffset(96, 56), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
	TextSize = 20, Parent = pill })
local liked = {} -- owner UserId -> true (this session; the server enforces the daily limit)

local function refreshPill()
	local id = player:GetAttribute("Visiting") or 0
	local owner = id ~= 0 and id ~= player.UserId and Players:GetPlayerByUserId(id)
	if not owner then
		if pill.Visible then
			UI.popOut(pill)
		end
		return
	end
	pillText.Text = string.format("%s's Island · %s likes", owner.DisplayName, Format.Num(owner:GetAttribute("IslandLikes") or 0))
	if liked[id] then
		likeBtn.Text = "Liked"
		UI.restyle(likeBtn, "Green")
	else
		likeBtn.Text = "Like"
		UI.restyle(likeBtn, "Red")
	end
	if not pill.Visible then
		UI.popIn(pill, 0.7)
	end
end

likeBtn.Activated:Connect(function()
	local id = player:GetAttribute("Visiting") or 0
	if id == 0 or liked[id] then
		return
	end
	local ok, msg = Net.invoke("LikeIsland", id)
	if ok then
		liked[id] = true
		Sounds.play("Bell")
		toast(msg or "You liked this island!", "Legendary")
	else
		fail(msg)
		if msg and msg:lower():find("already") then
			liked[id] = true
		end
	end
	refreshPill()
end)
homeBtn.Activated:Connect(function()
	C.Transition.travel("Travel", "Home")
end)

local watched = {}
local function watchOwner(pl)
	if watched[pl] then
		return
	end
	watched[pl] = pl:GetAttributeChangedSignal("IslandLikes"):Connect(function()
		refreshPill()
		if win and UI.isOpen(win) then
			Island.refresh()
		end
	end)
end

-- ===================================================================== start
function Island.Start(c)
	C = c
	win = UI.window({ Title = "Island", Size = Vector2.new(900, 74 + FULL_BODY), OnClose = function() end })
	tabs = UI.tabs(win, {
		{ Name = "Decor", Build = buildDecorPage },
		{ Name = "Themes", Build = buildThemesPage },
		{ Name = "Islands", Build = buildIslandsPage },
	}, function()
		Island.refresh()
	end)
	tabs.select("Decor")
	State.Changed:Connect(function()
		if UI.isOpen(win) then
			Island.refresh()
		end
	end)
	for _, a in ipairs({ "Scraps", "TreeLevel", "Mat_BloodAmber", "Mat_Sunstone" }) do
		player:GetAttributeChangedSignal(a):Connect(function()
			if UI.isOpen(win) then
				Island.refresh()
			end
		end)
	end
	player:GetAttributeChangedSignal("Visiting"):Connect(refreshPill)
	for _, pl in ipairs(Players:GetPlayers()) do
		watchOwner(pl)
	end
	Players.PlayerAdded:Connect(function(pl)
		watchOwner(pl)
		if win and UI.isOpen(win) then
			Island.refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function(pl)
		if watched[pl] then
			watched[pl]:Disconnect()
			watched[pl] = nil
		end
		liked[pl.UserId] = nil
		refreshPill()
		if win and UI.isOpen(win) then
			Island.refresh()
		end
	end)
	-- leaving your island mid-placement cancels it; dying too
	player.CharacterAdded:Connect(function()
		stopPlacing()
		stopEdit()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if (place.Active or edit.Active) and not onOwnIsland() then
				stopPlacing()
				stopEdit()
				toast("Placing stopped: you left your island.", "Info")
			end
		end
	end)
	refreshPill()
end

return Island
