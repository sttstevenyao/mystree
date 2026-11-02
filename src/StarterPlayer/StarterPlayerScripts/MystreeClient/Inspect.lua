-- StarterPlayerScripts/MystreeClient/Inspect (ModuleScript)
-- Inspect another player: tap or click their character. Reads their public "Public" attribute
-- (CP, level, stats, gear, companions, mount, tree level; published by StatsService) and shows it.
-- On PC in the Hunting Grounds a click is an attack, so there only a tap (touch) inspects.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)

local Inspect = {}
local T = UI.T
local player = Players.LocalPlayer

local C
local win
local refs = { Tiles = {} }
local target -- the player being inspected
local public -- their decoded snapshot

local function decode(pl)
	local raw = pl:GetAttribute("Public")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and data or nil
end

-- ===================================================================== build
-- Laid out like your own Profile (user: a custom profile for other players): their character turning
-- in the middle with the 8 gear slots around it, and a side card with stats, their record, spirits
-- and Visit island. Tapping a slot shows that piece on a card over the figure.
local LEFT_SLOTS = { "Helm", "Necklace", "Armor", "Belt" }
local RIGHT_SLOTS = { "Weapon", "Gloves", "Ring", "Boots" }
local figure = {} -- Viewport, World, Camera, Focus, Yaw

local function slotCell(parent, slot, x, y)
	local cell = UI.new("Frame", { Name = slot, BackgroundTransparency = 1, Size = UDim2.fromOffset(130, 104), Position = UDim2.fromOffset(x, y), Parent = parent })
	local tile = UI.tile({ Rarity = 1, Caption = slot, CaptionSize = 14, Size = UDim2.fromOffset(74, 74), Position = UDim2.new(0.5, -37, 0, 0), Parent = cell,
		OnClick = function()
			Inspect.showItem(slot)
		end })
	UI.text({ Name = "Label", Text = slot, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 77), TextSize = 14, Weight = Enum.FontWeight.Heavy,
		Stroke = false, TextColor3 = T.InkSoft, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = cell })
	refs.Tiles[slot] = tile
	refs.Labels = refs.Labels or {}
	refs.Labels[slot] = cell.Label
end

local function infoRow(parent, order, label)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order, Parent = parent })
	UI.text({ Text = label, Size = UDim2.new(0.55, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Weight = Enum.FontWeight.Bold,
		TextColor3 = T.TextLight, Stroke = false, Parent = row })
	return UI.text({ Text = "", Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16,
		Weight = Enum.FontWeight.Heavy, TextColor3 = T.Parchment, Stroke = false, Parent = row })
end

local function build(body)
	for i, slot in ipairs(LEFT_SLOTS) do
		slotCell(body, slot, 0, (i - 1) * 108)
	end
	for i, slot in ipairs(RIGHT_SLOTS) do
		slotCell(body, slot, 542, (i - 1) * 108)
	end
	-- the figure: an ink stage with the key-pattern ring, name and Power on top
	local stage = UI.new("Frame", { Name = "Figure", Size = UDim2.fromOffset(400, 430), Position = UDim2.fromOffset(136, 0), BackgroundColor3 = T.Panel, Parent = body })
	UI.corner(8, stage)
	UI.stroke(stage, T.Ornament, 1.5, 0.2)
	UI.ornaments(stage)
	UI.new("ImageLabel", { Image = UI.Art.KeyRing, ImageColor3 = T.Ornament, ImageTransparency = 0.75, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(340, 340), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Parent = stage })
	local vp = UI.new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -70), Position = UDim2.fromOffset(0, 70), Ambient = Color3.fromRGB(150, 146, 140),
		LightColor = Color3.fromRGB(255, 246, 230), LightDirection = Vector3.new(-1, -1.2, -1), Parent = stage })
	figure.World = UI.new("WorldModel", { Parent = vp })
	figure.Camera = UI.new("Camera", { FieldOfView = 28, Parent = vp })
	vp.CurrentCamera = figure.Camera
	-- head shot + name, realm and Power across the top
	local ring = UI.new("Frame", { BackgroundColor3 = T.Parchment, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(12, 10), Parent = stage })
	UI.corner(999, ring)
	UI.stroke(ring, T.Ornament, 2)
	refs.Head = UI.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = ring })
	UI.corner(999, refs.Head)
	refs.Name = UI.text({ Text = "", Size = UDim2.new(1, -90, 0, 28), Position = UDim2.fromOffset(78, 8), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 24,
		Weight = Enum.FontWeight.Heavy, TextColor3 = T.Parchment, Parent = stage })
	refs.Realm = UI.text({ Text = "", Size = UDim2.new(1, -90, 0, 20), Position = UDim2.fromOffset(78, 36), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16,
		Weight = Enum.FontWeight.Bold, TextColor3 = T.Cream, Stroke = false, Parent = stage })
	refs.CP = UI.text({ Text = "", Size = UDim2.fromOffset(200, 26), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Gold, Parent = stage })
	-- the gear card: shown over the figure's feet when a slot is tapped
	local card = UI.new("TextButton", { Name = "ItemCard", Text = "", AutoButtonColor = false, Size = UDim2.new(1, -20, 0, 118), AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10), BackgroundColor3 = T.Parchment, Visible = false, ZIndex = 5, Parent = stage })
	UI.corner(8, card)
	UI.stroke(card, T.Ornament, 1.5)
	refs.Item = UI.text({ Text = "", Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), TextSize = 16, TextColor3 = T.Ink, Stroke = false, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6, Parent = card })
	card.Activated:Connect(function()
		card.Visible = false
	end)
	refs.ItemCard = card
	-- the side card: stats, record, spirits, Visit island
	local side = UI.new("Frame", { BackgroundColor3 = T.Panel, Size = UDim2.fromOffset(254, 430), Position = UDim2.fromOffset(682, 0), Parent = body })
	UI.corner(8, side)
	UI.stroke(side, T.PanelLine, 1.5, 0.3)
	UI.ornaments(side)
	local list = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -28, 1, -70), Position = UDim2.fromOffset(14, 12), Parent = side })
	UI.list(list, Enum.FillDirection.Vertical, 2)
	local function header(order, text)
		UI.text({ Text = text, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 17, Weight = Enum.FontWeight.Heavy,
			TextColor3 = T.Gold, Stroke = false, LayoutOrder = order, Parent = list })
	end
	header(1, "Stats")
	refs.ATK = infoRow(list, 2, "Attack")
	refs.HP = infoRow(list, 3, "Health")
	refs.DEF = infoRow(list, 4, "Defense")
	refs.AGL = infoRow(list, 5, "Agility")
	header(6, "Record")
	refs.Tree = infoRow(list, 7, "Divine Tree")
	refs.Mount = infoRow(list, 8, "Mount")
	refs.Kills = infoRow(list, 9, "Monsters slain")
	refs.Bosses = infoRow(list, 10, "Bosses slain")
	refs.Likes = infoRow(list, 11, "Island likes")
	header(12, "Spirits")
	refs.Comp = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 13, Parent = list })
	UI.list(refs.Comp, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	refs.Visit = UI.button({ Text = "Visit island", Style = "Green", Size = UDim2.new(1, -28, 0, 46), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
		TextSize = 19, Parent = side, OnClick = function(b)
			if target and target.Parent and C.Transition then
				win.close()
				local ok, msg = C.Transition.travel("VisitIsland", target.UserId, target.DisplayName)
				if not ok and msg and C.Notify then
					C.Notify.toast(msg, "Error")
				end
			end
		end })
end

-- their character (with the armour and weapon every client draws on it), turning slowly
local function refreshFigure()
	figure.World:ClearAllChildren()
	figure.Focus = nil
	local char = target and target.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, copy = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not copy then
		return
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	copy.Parent = figure.World
	local weapon = C.Equipment and C.Equipment.weapon and C.Equipment.weapon(target)
	if weapon then
		weapon.Archivable = true
		weapon:Clone().Parent = figure.World
	end
	figure.Focus = hrp.Position + Vector3.new(0, -0.4, 0)
	figure.Yaw = select(2, hrp.CFrame:ToEulerAnglesYXZ()) + math.rad(200)
end

function Inspect.showItem(slot)
	local it = public and public.Gear and public.Gear[slot]
	refs.ItemCard.Visible = true
	if not it then
		refs.Item.Text = "<b>" .. slot .. "</b>: nothing equipped."
		return
	end
	local r = Config.Rarities[it.R]
	local lines = { string.format('<font size="19" color="#%s"><b>%s</b></font>  %s · Lv.%d', r.Color:Lerp(Color3.new(0, 0, 0), 0.25):ToHex(), it.Name, r.Name, it.L) }
	local main = {}
	for _, k in ipairs(Rules.Stats) do
		if it.Main and it.Main[k] then
			table.insert(main, k .. " +" .. Format.Num(it.Main[k]))
		end
	end
	table.insert(lines, table.concat(main, "   "))
	local subs = {}
	for k, v in pairs(it.Subs or {}) do
		local def = Config.Substats[k]
		table.insert(subs, (def and def.Name or k) .. " +" .. Format.Pct(v))
	end
	table.sort(subs)
	if #subs > 0 then
		table.insert(lines, table.concat(subs, "   "))
	end
	local set = it.Set and Config.ArmorSets[it.Set]
	if set then
		table.insert(lines, string.format('<font color="#%s"><b>%s set</b></font>', set.Color:Lerp(Color3.new(0, 0, 0), 0.3):ToHex(), set.Name))
	end
	local myth = it.Myth and Config.Forge.Myth[it.Myth]
	if myth then
		table.insert(lines, string.format('<font color="#%s"><b>%s</b></font>  %s', myth.Effect.Color:Lerp(Color3.new(0, 0, 0), 0.3):ToHex(), myth.Effect.Name, myth.Effect.Desc))
	end
	refs.Item.TextSize = (set or myth) and 14 or 16
	refs.Item.Text = table.concat(lines, "\n")
end

function Inspect.refresh()
	if not (win and target) then
		return
	end
	public = decode(target)
	refs.Name.Text = target.DisplayName
	refs.ItemCard.Visible = false
	if not public then
		refs.Realm.Text = "Still loading..."
		return
	end
	refs.Realm.Text = string.format("@%s  ·  Lv.%d %s", target.Name, public.Level or 1, Rules.realm(public.Level or 1))
	refs.CP.Text = "Power " .. Format.Num(public.CP or 0)
	local s = public.Stats or {}
	refs.ATK.Text, refs.HP.Text = Format.Num(s.ATK or 0), Format.Num(s.HP or 0)
	refs.DEF.Text, refs.AGL.Text = Format.Num(s.DEF or 0), Format.Num(s.AGL or 0)
	local rec = public.Record or {}
	refs.Tree.Text = "Lv " .. (public.Tree or 1)
	local mount = Config.Mounts[public.Mount or ""]
	refs.Mount.Text = mount and mount.Name or "None yet"
	refs.Kills.Text = Format.Num(rec.Kills or 0)
	refs.Bosses.Text = Format.Num(rec.Bosses or 0)
	refs.Likes.Text = Format.Num(rec.Likes or 0)
	for _, slot in ipairs(Config.Slots) do
		local tile = refs.Tiles[slot]
		local it = public.Gear and public.Gear[slot]
		UI.setTileRarity(tile, it and it.R or 1)
		tile.Level.Text = it and ("Lv." .. it.L) or ""
		tile.Caption.Text = it and "" or slot
		refs.Labels[slot].Text = it and it.Name or "Empty"
		UI.setModel(tile.Viewport, it and Assets.Gear({ Slot = slot, R = it.R, Class = it.Class }) or nil, 35, -18)
	end
	for _, c in ipairs(refs.Comp:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local comps = public.Companions or {}
	if #comps == 0 then
		UI.text({ Text = "No spirit yet", Size = UDim2.fromOffset(200, 40), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, TextColor3 = T.TextLight,
			Stroke = false, Parent = refs.Comp })
	end
	for i, info in ipairs(comps) do
		local def = Config.Companions[info.Id]
		if def then
			local tile = UI.tile({ Rarity = def.Rarity, Size = UDim2.fromOffset(50, 50), LayoutOrder = i, Parent = refs.Comp })
			tile.Level.Text = info.Stars .. "/" .. Config.CompanionStars.Max
			UI.setModel(tile.Viewport, Assets.Companion(info.Id), 30, -12)
			UI.tooltip(tile, def.Name, Config.Rarities[def.Rarity].Name .. " spirit, " .. info.Stars .. " stars")
		end
	end
	refreshFigure()
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok and refs.Head then
			refs.Head.Image = img
		end
	end)
end

function Inspect.open(pl, allowSelf)
	if not (win and pl and (pl ~= player or allowSelf)) then
		return
	end
	target = pl
	win.Title.Text = pl.DisplayName .. "'s Profile"
	win.open()
	Inspect.refresh()
end

function Inspect.close()
	if win then
		win.close()
	end
end

-- ===================================================================== picking a player in the world
local function playerAt(screenPos)
	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not hit then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model do
		local pl = Players:GetPlayerFromCharacter(model)
		if pl then
			return pl
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Inspect.Start(c)
	C = c
	win = UI.window({ Title = "Profile", Size = Vector2.new(960, 520) })
	build(win.Body)
	-- the figure turns slowly while the profile is open
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		if figure.Focus and UI.isOpen(win) then
			figure.Yaw += dt * 0.35
			figure.Camera.CFrame = CFrame.new(figure.Focus) * CFrame.Angles(0, figure.Yaw, 0) * CFrame.Angles(math.rad(-4), 0, 0) * CFrame.new(0, 0, 19)
		end
	end)
	local downAt, downPos
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or (t == Enum.UserInputType.MouseButton1 and not player:GetAttribute("InGrounds")) then
			downAt, downPos = os.clock(), input.Position
		end
	end)
	-- a tap/click (not a camera drag) opens the panel
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed or not downAt then
			return
		end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local quick = os.clock() - downAt < 0.35 and (input.Position - downPos).Magnitude < 12
		downAt = nil
		if quick then
			local pl = playerAt(input.Position)
			if pl and pl ~= player then
				Sounds.play("Click")
				Inspect.open(pl)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(pl)
		if pl == target and UI.isOpen(win) then
			win.close()
		end
	end)
end

return Inspect
