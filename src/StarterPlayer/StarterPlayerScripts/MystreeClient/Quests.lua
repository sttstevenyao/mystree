-- StarterPlayerScripts/MystreeClient/Quests (ModuleScript)
-- The quest side of the Village, drawn on the client (QuestService owns every rule):
--  * Talk prompts on NPCs in a custom jade pill ("[E] Talk · Elder Mo"; a tap button on touch).
--  * The dialog window: NPC portrait, a typewriter line, the main quest row, side quest rows
--    (Accept / progress + Abandon / Complete / come back tomorrow / Reach Lv N), the NPC's own
--    window button (Shop, Spirits, Mounts) and the Fresh Orders offer when today's quests are done.
--  * The quest log (Main / Side tabs) with "Track" waypoints.
--  * Overhead name tags with "!" (something to take), "?" gold (ready to hand in), "?" grey (in progress).
--  * A bouncing world arrow + glowing path to the NPC a quest is waiting at.
-- Progress comes from the "QuestProgress" attribute (JSON) and State.Quests (the State JSON).

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Purchase = require(script.Parent.Purchase)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local Quests = {}
local C
local T = UI.T
local player = Players.LocalPlayer
local GOLD = T.Gold
local CHAPTER = "Chapter 1: The Withering Root"

-- ===================================================================== helpers
local function npcName(id)
	local def = Config.Npcs[id]
	return def and def.Name or tostring(id)
end

local function npcModel(id)
	local folder = workspace:FindFirstChild("Npcs")
	if not folder then
		return nil
	end
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("NpcId") == id then
			return m
		end
	end
end

local function toast(text, kind)
	if C and C.Notify and text and text ~= "" then
		C.Notify.toast(text, kind)
	end
end

local function fail(msg)
	Sounds.play("Error")
	toast(msg or "That didn't work.", "Error")
end

-- the QuestProgress attribute, decoded
local function progress()
	local raw = player:GetAttribute("QuestProgress")
	if type(raw) ~= "string" then
		return { Side = {} }
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(data) ~= "table" then
		return { Side = {} }
	end
	data.Side = data.Side or {}
	return data
end
Quests.progress = progress

local function questState()
	local q = State.Quests or {}
	return { Main = q.Main, Side = q.Side or {}, SideDone = q.SideDone or {} }
end

local function today()
	return workspace:GetAttribute("UtcDay") or (os.time() // 86400)
end

-- the main quest hasn't started yet (Index 0 or no progress at all)
local function mainNotStarted(qp)
	return qp.Main == nil or (qp.Main.Index or 0) == 0
end

-- ===================================================================== main quest tracker (for the HUD pill)
-- Returns title, goal text, have, need, ready
function Quests.trackerText()
	local qp = progress()
	if mainNotStarted(qp) then
		return "Begin your journey", "Talk to Elder Mo", 0, 1, false
	end
	local m = qp.Main
	if m.Ready then
		return m.Title or "Main quest", "Return to " .. npcName(m.Npc), m.Need or 1, m.Need or 1, true
	end
	return m.Title or "Main quest", m.Goal or "", m.Have or 0, m.Need or 1, false
end

-- ===================================================================== waypoint (world arrow + path)
local wpPart = Instance.new("Part")
wpPart.Name = "QuestWaypoint"
wpPart.Anchored = true
wpPart.CanCollide = false
wpPart.CanQuery = false
wpPart.CanTouch = false
wpPart.Transparency = 1
wpPart.Size = Vector3.new(1, 1, 1)
wpPart.Parent = Fx.Holder
local wpBoard = UI.new("BillboardGui", { Size = UDim2.fromOffset(110, 120), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Parent = wpPart })
local wpArrow = UI.new("Frame", { Size = UDim2.fromOffset(44, 56), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Parent = wpBoard })
UI.new("Frame", { Size = UDim2.fromOffset(14, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = GOLD, Parent = wpArrow },
	{ UI.corner(4), UI.new("UIStroke", { Color = Color3.fromRGB(110, 70, 10), Thickness = 2 }) })
for _, s in ipairs({ -1, 1 }) do
	UI.new("Frame", { Size = UDim2.fromOffset(14, 32), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, s * 9, 1, -2), Rotation = s * 40,
		BackgroundColor3 = GOLD, Parent = wpArrow }, { UI.corner(4), UI.new("UIStroke", { Color = Color3.fromRGB(110, 70, 10), Thickness = 2 }) })
end
local wpText = UI.text({ Text = "", Size = UDim2.new(1, 60, 0, 30), Position = UDim2.fromOffset(-30, 0), TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = GOLD, Parent = wpBoard })
local wpA0 = Instance.new("Attachment")
wpA0.Position = Vector3.new(0, -8, 0)
wpA0.Parent = wpPart
local wpA1
local wpBeam = Instance.new("Beam")
wpBeam.Attachment0 = wpA0
wpBeam.Color = ColorSequence.new(GOLD)
wpBeam.Width0 = 0.6
wpBeam.Width1 = 0.6
wpBeam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.85) })
wpBeam.LightEmission = 1
wpBeam.FaceCamera = true
wpBeam.Enabled = false
wpBeam.Parent = wpPart

local waypoint = { Npc = nil, Manual = false } -- Manual = set by "Track" (cleared on arrival)

function Quests.waypoint(npcId, manual)
	waypoint.Npc = npcId
	waypoint.Manual = manual or false
	if npcId and manual and player:GetAttribute("Zone") ~= "Village" then
		toast("Travel to the Village, then follow the arrow to " .. npcName(npcId) .. ".", "Info")
	end
end

-- ===================================================================== custom Talk prompts
local promptGui = UI.new("ScreenGui", { Name = "MystreePrompts", ResetOnSpawn = false, DisplayOrder = 8, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, Parent = UI.PlayerGui })
local promptBoards = {} -- prompt -> BillboardGui

local function npcOfPrompt(prompt)
	local m = prompt:FindFirstAncestorWhichIsA("Model")
	local folder = workspace:FindFirstChild("Npcs")
	while m and folder and m.Parent ~= folder do
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
	end
	return m and m:GetAttribute("NpcId")
end

local function isTalk(prompt)
	return prompt:IsA("ProximityPrompt") and prompt.Name == "Talk" and npcOfPrompt(prompt) ~= nil
end

local function keyGlyph(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return nil
	end
	return prompt.KeyboardKeyCode.Name
end

local function showPrompt(prompt, inputType)
	if not isTalk(prompt) then
		return
	end
	local old = promptBoards[prompt]
	if old then
		old:Destroy()
	end
	local npcId = npcOfPrompt(prompt)
	local board = UI.new("BillboardGui", { Name = "TalkPrompt", Adornee = prompt.Parent, Size = UDim2.fromOffset(250, 64), StudsOffset = Vector3.new(0, 1.2, 0),
		AlwaysOnTop = true, LightInfluence = 0, Active = true, ResetOnSpawn = false, Parent = promptGui })
	local pill = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.05, Parent = board })
	UI.corner(32, pill)
	UI.stroke(pill, T.Ornament, 2.5)
	UI.bounce(pill)
	local glyph = keyGlyph(prompt, inputType)
	local key = UI.new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = T.Parchment, Parent = pill })
	UI.corner(10, key)
	UI.stroke(key, T.TealLine, 2)
	UI.text({ Text = glyph or "Tap", Size = UDim2.fromScale(1, 1), TextSize = glyph and 24 or 16, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = key })
	UI.text({ Text = "Talk · " .. npcName(npcId), Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(62, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 22, Weight = Enum.FontWeight.Heavy, Scaled = true, MaxTextSize = 22, Parent = pill })
	pill.Activated:Connect(function()
		Sounds.play("Click")
		Quests.talk(npcId)
	end)
	UI.popIn(pill, 0.6)
	promptBoards[prompt] = board
end

local function hidePrompt(prompt)
	local b = promptBoards[prompt]
	promptBoards[prompt] = nil
	if b then
		b:Destroy()
	end
end

local function claimPrompt(d)
	if d:IsA("ProximityPrompt") and d.Name == "Talk" then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end

-- ===================================================================== reward burst
local function rewardBurst(rewarded)
	if not rewarded then
		return
	end
	Sounds.play("Legendary")
	local reward = rewarded.Reward or {}
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local y = 3
		local keys = {}
		for k in pairs(reward) do
			table.insert(keys, k)
		end
		table.sort(keys)
		for i, k in ipairs(keys) do
			local one = Rules.rewardText({ [k] = reward[k] })
			task.delay(i * 0.12, function()
				Fx.float(hrp.Position + Vector3.new(0, y + i * 1.6, 0), one, { Color = GOLD, Size = 26, Rise = 5, Time = 1.6 })
			end)
		end
		Fx.burst(hrp.Position, { Texture = "Glow", Color = GOLD, Count = 24, Speed = { 8, 18 }, Size = 0.7, Light = 1, Lifetime = { 0.6, 1.2 }, Gravity = Vector3.new(0, 8, 0) })
	end
	toast("Quest complete: " .. (rewarded.Title or "") .. " · " .. Rules.rewardText(reward), "Legendary")
end

-- ===================================================================== dialog window
local dlg -- window
local dlgRefs = {} -- Portrait, Name, Title, Speech, Rows, Opens, RowsH
local currentDialog -- last dialog table shown
local typing -- { Label, Full, Conn }

local function finishTyping()
	if typing then
		if typing.Conn then
			typing.Conn:Disconnect()
		end
		typing.Label.MaxVisibleGraphemes = -1
		typing = nil
	end
end

local function typeLine(label, text)
	finishTyping()
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local total = utf8.len(text) or #text
	local t0 = os.clock()
	local entry = { Label = label }
	entry.Conn = RunService.Heartbeat:Connect(function()
		local n = math.floor((os.clock() - t0) * 55)
		if n >= total then
			label.MaxVisibleGraphemes = -1
			entry.Conn:Disconnect()
			if typing == entry then
				typing = nil
			end
		else
			label.MaxVisibleGraphemes = n
		end
	end)
	typing = entry
end

local function setPortrait(npcId)
	local vp = dlgRefs.Portrait
	for _, ch in ipairs(vp:GetChildren()) do
		if ch:IsA("Model") or ch:IsA("Camera") or ch:IsA("WorldModel") then
			ch:Destroy()
		end
	end
	local src = npcModel(npcId)
	if not src then
		return
	end
	local wasArchivable = src.Archivable
	src.Archivable = true
	local ok, copy = pcall(function()
		return src:Clone()
	end)
	src.Archivable = wasArchivable
	if not ok or not copy then
		return
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local world = UI.new("WorldModel", { Parent = vp })
	copy.Parent = world
	local cam = UI.new("Camera", { FieldOfView = 32, Parent = vp })
	vp.CurrentCamera = cam
	local head = copy:FindFirstChild("Head") or copy.PrimaryPart
	local pivot = copy:GetPivot()
	-- a head-and-shoulders portrait for the square frame
	local focus = head and head.Position - Vector3.new(0, 0.45, 0) or pivot.Position
	local front = pivot.LookVector
	cam.CFrame = CFrame.lookAt(focus + front * 5.2 + pivot.RightVector * 0.9 + Vector3.new(0, 0.3, 0), focus)
end

local showDialog -- forward

local function act(remote, id)
	local ok, msg, dialog = Net.invoke(remote, id)
	if not ok then
		fail(msg)
		return
	end
	if msg then
		toast(msg, "Info")
	end
	if dialog then
		showDialog(dialog)
	end
end

local function buyFreshOrders(btn)
	local ok, msg = Purchase.buy("FreshOrders")
	if not ok then
		fail(msg)
	elseif msg then -- a Studio test grant (a real purchase refreshes through the save)
		toast(msg, "Purchase")
		if currentDialog then
			Quests.talk(currentDialog.Npc)
		end
	end
end

-- ---------------------------------------------------------------- the talk box
-- RPG style (user's reference): a box at the bottom middle with the NPC's portrait, a name tag on its
-- top edge and the line typing out; the choices are small buttons stacked above it, on the right.
-- No dim and no blur, so the village stays in view. Walking away closes it.
local TALK_W, TALK_H, CHOICE_W, CHOICE_H = 760, 150, 380, 44
local _, talkRoot = UI.screen("MystreeTalk", 19)
local talk = UI.new("Frame", { Name = "Talk", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = talkRoot })
local box = UI.new("TextButton", { Name = "Box", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(TALK_W, TALK_H), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.06, Parent = talk })
UI.corner(10, box)
UI.stroke(box, T.Ornament, 2, 0.1)
UI.ornaments(box)
dlgRefs.Portrait = UI.new("ViewportFrame", { Size = UDim2.fromOffset(TALK_H - 26, TALK_H - 26), Position = UDim2.fromOffset(13, 13), BackgroundColor3 = Color3.fromRGB(70, 110, 106),
	Ambient = Color3.fromRGB(170, 170, 170), LightColor = Color3.fromRGB(255, 248, 236), LightDirection = Vector3.new(-1, -1, -1), Parent = box })
UI.corner(8, dlgRefs.Portrait)
UI.stroke(dlgRefs.Portrait, T.Ornament, 1.5, 0.2)
-- the name tag sits on the box's top edge, over the speech
local nameTag = UI.new("Frame", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(TALK_H, -18),
	BackgroundColor3 = T.Parchment, ZIndex = 3, Parent = box })
UI.corner(6, nameTag)
UI.stroke(nameTag, T.Ornament, 1.5)
UI.pad(nameTag, 4, 14, 4, 14)
UI.list(nameTag, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
dlgRefs.Name = UI.text({ Text = "", Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextSize = 20, Weight = Enum.FontWeight.Heavy,
	TextColor3 = T.Ink, Stroke = false, LayoutOrder = 1, ZIndex = 4, Parent = nameTag })
dlgRefs.Title = UI.text({ Text = "", Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextSize = 15, Weight = Enum.FontWeight.Bold,
	TextColor3 = T.InkSoft, Stroke = false, LayoutOrder = 2, ZIndex = 4, Parent = nameTag })
dlgRefs.Speech = UI.text({ Text = "", Size = UDim2.new(1, -TALK_H - 56, 1, -36), Position = UDim2.fromOffset(TALK_H, 24), TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextSize = 20, Weight = Enum.FontWeight.Bold, TextColor3 = T.Parchment, Stroke = false, Parent = box })
box.Activated:Connect(finishTyping)
local closeTalk = UI.button({ Text = "X", Style = "Red", Size = UDim2.fromOffset(36, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
	TextSize = 18, Parent = box, OnClick = function()
		dlg.close()
	end })
closeTalk.Name = "Close"
-- the choices, stacked upwards from just above the box's right end
local choices = UI.new("ScrollingFrame", { Name = "Choices", BackgroundTransparency = 1, Size = UDim2.fromOffset(CHOICE_W + 12, 0), AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(0.5, TALK_W / 2 + 6, 1, -18 - TALK_H - 10), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6, ScrollBarImageColor3 = T.Ornament, Parent = talk })
UI.list(choices, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
UI.pad(choices, 2, 6, 2, 2)
dlgRefs.Rows = choices

-- one choice: an ink button with an accent bar; `sub` is a smaller second line (goal, reward)
local function choice(order, text, sub, accent, onClick)
	local h = sub and 52 or CHOICE_H
	dlgRefs.RowsH = (dlgRefs.RowsH or 0) + h + 6
	local b = UI.new(onClick and "TextButton" or "Frame", { Size = UDim2.fromOffset(CHOICE_W, h), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.08,
		LayoutOrder = order, Parent = choices })
	if onClick then
		b.Text = ""
		b.AutoButtonColor = false
		UI.bounce(b)
		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = T.Panel:Lerp(T.White, 0.08)
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = T.Panel
		end)
		b.Activated:Connect(function()
			Sounds.play("Click")
			onClick(b)
		end)
	end
	UI.corner(8, b)
	UI.stroke(b, accent or T.PanelLine, 1.5, onClick and 0.1 or 0.5)
	UI.new("Frame", { Size = UDim2.new(0, 4, 1, -14), Position = UDim2.fromOffset(7, 7), BackgroundColor3 = accent or T.PanelLine, Parent = b }, { UI.corner(2) })
	UI.text({ Text = text, Size = UDim2.new(1, -30, 0, sub and 24 or h), Position = UDim2.fromOffset(20, sub and 4 or 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 17, Weight = Enum.FontWeight.Heavy, TextColor3 = onClick and T.Parchment or T.TextLight, Stroke = false, TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
	if sub then
		UI.text({ Text = sub, Size = UDim2.new(1, -30, 0, 20), Position = UDim2.fromOffset(20, 27), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14,
			Weight = Enum.FontWeight.Bold, TextColor3 = T.Gold, Stroke = false, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
	end
	return b
end

local GREEN, ORANGE, TEAL, GREY, PURPLE = T.Green, T.Orange, T.Teal, Color3.fromRGB(120, 120, 120), Color3.fromRGB(170, 110, 230)

local function haveNeed(q)
	return string.format("%s/%s", Format.Num(q.Have or 0), Format.Num(q.Need or 1))
end

local function buildMainRow(m)
	local reward = "Reward: " .. Rules.rewardText(m.Reward or {})
	if m.State == "Offer" then
		choice(1, "Accept: " .. (m.Title or "Main quest"), (m.Goal or "") .. "  ·  " .. reward, GOLD, function()
			act("QuestAccept", m.Id)
		end)
		choice(2, "Not now", nil, GREY, function()
			dlg.close()
			toast("No rush. " .. npcName(currentDialog and currentDialog.Npc or "Elder") .. " will keep it for you.", "Info")
		end)
	elseif m.State == "Ready" then
		choice(1, "Complete: " .. (m.Title or "Main quest"), reward, ORANGE, function()
			act("QuestTurnIn", m.Id)
		end)
	elseif m.State == "Active" then
		choice(1, (m.Title or "Main quest") .. "   " .. haveNeed(m), m.Goal, GOLD)
	else
		choice(1, "Track: talk to " .. npcName(m.TurnInNpc), m.Title, GOLD, function()
			Quests.waypoint(m.TurnInNpc, true)
			dlg.close()
		end)
	end
end

local function buildSideRow(s, order)
	local o = 10 + order * 2
	local reward = "Reward: " .. Rules.rewardText(s.Reward or {})
	if s.State == "Offer" then
		choice(o, "Accept: " .. (s.Title or ""), (s.Goal or "") .. "  ·  " .. reward, GREEN, function()
			act("QuestAccept", s.Id)
		end)
	elseif s.State == "Ready" then
		choice(o, "Complete: " .. (s.Title or ""), reward, ORANGE, function()
			act("QuestTurnIn", s.Id)
		end)
	elseif s.State == "Active" then
		local row = choice(o, (s.Title or "") .. "   " .. haveNeed(s), s.Goal, TEAL)
		local ab = UI.button({ Text = "Abandon", Style = "Grey", Size = UDim2.fromOffset(84, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			TextSize = 13, Parent = row, OnClick = function()
				local ok, msg = Net.invoke("QuestAbandon", s.Id)
				if ok then
					toast(msg or "Quest dropped.", "Info")
					if currentDialog then
						Quests.talk(currentDialog.Npc)
					end
				else
					fail(msg)
				end
			end })
		ab.ZIndex = 3
	else
		local why = (s.State == "Locked") and ("Reach Lv " .. tostring(s.MinLevel or "?")) or "Come back tomorrow"
		choice(o, s.Title or "", why, GREY)
	end
end

local function buildFreshOrders()
	local b = choice(100, "Fresh Orders  " .. Purchase.price("FreshOrders"), Config.Products.FreshOrders.Desc, PURPLE, buyFreshOrders)
	local label = b:FindFirstChildOfClass("TextLabel")
	if label then
		Purchase.label(label, "FreshOrders", "Fresh Orders  R$%s")
	end
end

local talkNpc -- the NPC model being talked to (walking away closes the box)
dlg = {}
function dlg.close()
	if not talk.Visible then
		return
	end
	finishTyping()
	talkNpc = nil
	choices.Visible = false
	UI.popOut(box, function()
		if not choices.Visible then
			talk.Visible = false
		end
	end)
end
function dlg.open()
	choices.Visible = true
	if not talk.Visible or not box.Visible then
		talk.Visible = true
		UI.popIn(box)
	end
end

showDialog = function(dialog)
	currentDialog = dialog
	dlgRefs.Name.Text = dialog.Name or npcName(dialog.Npc)
	dlgRefs.Title.Text = dialog.Title or ""
	dlgRefs.Title.Visible = (dialog.Title or "") ~= ""
	setPortrait(dialog.Npc)
	talkNpc = npcModel(dialog.Npc)
	-- the line: a freshly started main step reads as the NPC's next words
	local line = dialog.Line or ""
	if dialog.Next then
		line = dialog.Next.Text or line
		if dialog.Next.Npc and dialog.Next.Npc ~= dialog.Npc then
			line = line .. "  (Talk to " .. npcName(dialog.Next.Npc) .. ")"
		end
	end
	typeLine(dlgRefs.Speech, line)
	for _, ch in ipairs(choices:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	dlgRefs.RowsH = 0
	if dialog.Main then
		buildMainRow(dialog.Main)
	end
	for i, s in ipairs(dialog.Side or {}) do
		buildSideRow(s, i)
	end
	if dialog.FreshOrders then
		buildFreshOrders()
	end
	if dialog.Opens and C[dialog.Opens] and C[dialog.Opens].open then
		local key = dialog.Opens
		local label = ({ Shop = "Open the shop", Spirits = "See the spirits", Mounts = "See the mounts" })[key] or ("Open " .. key)
		choice(200, label, nil, TEAL, function()
			dlg.close()
			task.delay(0.2, function()
				C[key].open()
			end)
		end)
	end
	choice(300, "Goodbye", nil, GREY, function()
		dlg.close()
	end)
	-- as tall as the choices, up to what fits above the box
	choices.Size = UDim2.fromOffset(CHOICE_W + 12, math.min(dlgRefs.RowsH + 4, 330))
	rewardBurst(dialog.Rewarded)
	-- a just-finished quest clears its waypoint
	if dialog.Rewarded and waypoint.Npc == dialog.Npc then
		Quests.waypoint(nil)
	end
	-- the talk box replaces any open window
	UI.closeWindow()
	dlg.open()
end

local function buildDialog()
	-- (the talk box is built when the module loads; this watches for walking away)
	task.spawn(function()
		while true do
			task.wait(0.3)
			if talk.Visible and talkNpc then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local pivot = talkNpc.Parent and talkNpc:GetPivot()
				if not pivot or (hrp and (hrp.Position - pivot.Position).Magnitude > Config.NpcTalkRange + 8) then
					dlg.close()
				end
			end
		end
	end)
end

-- Talk to an NPC: asks the server for their dialog and shows it
local talking = false
function Quests.talk(npcId)
	if talking or not npcId then
		return
	end
	talking = true
	local ok, msg, dialog = Net.invoke("QuestTalk", npcId)
	talking = false
	if not ok then
		fail(msg)
		return
	end
	if dialog then
		showDialog(dialog)
	end
end

-- ===================================================================== quest log
local log -- window
local LOG_BODY = 406 -- tallest quest log body; shorter lists shrink the window
local logTabs
local logRefs = {} -- MainList, SideList

local function logRow(parent, height, order, accent)
	local f = UI.new("Frame", { Size = UDim2.new(1, -12, 0, height), BackgroundColor3 = T.Parchment2, LayoutOrder = order, Parent = parent })
	UI.corner(8, f)
	UI.stroke(f, accent or T.PanelLine, accent and 3 or 1.5)
	return f
end

local function clear(frame)
	for _, ch in ipairs(frame:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function trackButton(parent, npcId, y)
	return UI.button({ Text = "Track", Style = "Teal", Size = UDim2.fromOffset(150, 60), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, y or 14),
		TextSize = 21, Parent = parent, OnClick = function()
			Quests.waypoint(npcId, true)
			log.close()
		end })
end

-- the log hugs the open tab's rows, up to the full window
local function fitLog()
	local h = logRefs.Heights and logTabs and logRefs.Heights[logTabs.Current]
	if h then
		UI.fitWindow(log, math.clamp(h + 12, 150, LOG_BODY))
	end
end

local function refreshLog()
	if not log then
		return
	end
	local qp = progress()
	-- Main tab (heights are summed as rows are added, so the window can hug them)
	local list = logRefs.MainList
	clear(list)
	local mainH = 8 + 36
	UI.text({ Text = CHAPTER, Size = UDim2.new(1, -12, 0, 36), TextSize = 26, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, LayoutOrder = 0, Parent = list })
	if mainNotStarted(qp) then
		local f = logRow(list, 110, 1, GOLD)
		mainH += 8 + 110
		UI.text({ Text = "Begin your journey", Size = UDim2.new(1, -190, 0, 30), Position = UDim2.fromOffset(14, 10), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22,
			Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(150, 96, 20), Stroke = false, Parent = f })
		UI.text({ Text = "Talk to Elder Mo in the Village.", Size = UDim2.new(1, -190, 0, 26), Position = UDim2.fromOffset(14, 46), TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 19, Weight = Enum.FontWeight.Bold, TextColor3 = T.Ink, Stroke = false, Parent = f })
		trackButton(f, "Elder", 24)
	else
		local m = qp.Main
		local def = Config.MainQuests[m.Index] or {}
		local f = logRow(list, 230, 1, GOLD)
		mainH += 8 + 230
		UI.text({ Text = string.format("Step %d · %s", m.Index or 0, m.Title or def.Title or ""), Size = UDim2.new(1, -190, 0, 30), Position = UDim2.fromOffset(14, 10),
			TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22, Weight = Enum.FontWeight.Heavy, TextColor3 = Color3.fromRGB(150, 96, 20), Stroke = false, Parent = f })
		UI.text({ Text = def.Story or "", Size = UDim2.new(1, -250, 0, 78), Position = UDim2.fromOffset(14, 44), TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextSize = 18, Weight = Enum.FontWeight.Bold, TextColor3 = T.InkSoft, Stroke = false, Parent = f })
		local goal = m.Ready and ("Return to " .. npcName(m.Npc)) or (m.Goal or "")
		UI.text({ Text = goal, Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(14, 124), TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 20, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = f })
		local bar = UI.bar({ Size = UDim2.fromOffset(320, 22), Position = UDim2.fromOffset(14, 156), TextSize = 15, Parent = f })
		UI.setBar(bar, m.Ready and 1 or (m.Have or 0) / math.max(1, m.Need or 1), string.format("%s/%s", Format.Num(m.Have or 0), Format.Num(m.Need or 1)))
		UI.text({ Text = "Reward: " .. Rules.rewardText(def.Reward or {}) .. "    Where: " .. npcName(m.Npc), Size = UDim2.new(1, -28, 0, 24), Position = UDim2.fromOffset(14, 190),
			TextXAlignment = Enum.TextXAlignment.Left, TextSize = 17, Weight = Enum.FontWeight.Bold, TextColor3 = T.OrangeDark, Stroke = false, Parent = f })
		trackButton(f, m.Npc, 10)
		-- finished steps
		for i = (m.Index or 1) - 1, 1, -1 do
			local done = Config.MainQuests[i]
			if done then
				local r = logRow(list, 44, 10 + (m.Index - i), nil)
				mainH += 8 + 44
				UI.text({ Text = string.format("Step %d · %s", i, done.Title), Size = UDim2.new(1, -130, 1, 0), Position = UDim2.fromOffset(14, 0), TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 18, Weight = Enum.FontWeight.Bold, TextColor3 = T.InkSoft, Stroke = false, Parent = r })
				UI.text({ Text = "Done", Size = UDim2.fromOffset(100, 44), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), TextSize = 18,
					Weight = Enum.FontWeight.Heavy, TextColor3 = T.GreenDark, Stroke = false, Parent = r })
			end
		end
	end
	-- Side tab
	local side = logRefs.SideList
	clear(side)
	local ids = {}
	for id in pairs(qp.Side) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local sideH = 8 + math.max(70, #ids * 120 - 8)
	if #ids == 0 then
		UI.text({ Text = "No side quests yet. Villagers with a gold ! over their heads have work for you.", Size = UDim2.new(1, -20, 0, 70), TextSize = 20,
			Weight = Enum.FontWeight.Bold, TextColor3 = T.InkSoft, Stroke = false, Parent = side })
	end
	for i, id in ipairs(ids) do
		local s = qp.Side[id]
		local f = logRow(side, 112, i, s.Ready and GOLD or nil)
		UI.text({ Text = s.Title or id, Size = UDim2.new(1, -330, 0, 28), Position = UDim2.fromOffset(14, 8), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 21,
			Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = f })
		local goal = s.Ready and ("Return to " .. npcName(s.Npc)) or (s.Goal or "")
		UI.text({ Text = goal, Size = UDim2.new(1, -330, 0, 24), Position = UDim2.fromOffset(14, 38), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18,
			Weight = Enum.FontWeight.Bold, TextColor3 = T.Ink, Stroke = false, Parent = f })
		local bar = UI.bar({ Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(14, 72), TextSize = 15, Parent = f })
		UI.setBar(bar, s.Ready and 1 or (s.Have or 0) / math.max(1, s.Need or 1), string.format("%s/%s", Format.Num(s.Have or 0), Format.Num(s.Need or 1)))
		trackButton(f, s.Npc, 10)
		UI.button({ Text = "Abandon", Style = "Grey", Size = UDim2.fromOffset(150, 44), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -168, 1, -8), TextSize = 17,
			Parent = f, OnClick = function()
				local ok, msg = Net.invoke("QuestAbandon", id)
				if ok then
					toast(msg or "Quest dropped.", "Info")
				else
					fail(msg)
				end
			end })
	end
	logRefs.Heights = { Main = mainH, Side = sideH }
	fitLog()
end

local function buildLog()
	log = UI.window({ Title = "Quests", Size = Vector2.new(860, 74 + LOG_BODY), OnOpen = refreshLog })
	local function page(key)
		return function(p)
			local s = UI.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 8, ScrollBarImageColor3 = T.TealDark, Parent = p })
			UI.list(s, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
			UI.pad(s, 2, 4, 2, 4)
			UI.autoScrollBar(s, 8)
			logRefs[key] = s
		end
	end
	logTabs = UI.tabs(log, {
		{ Name = "Main", Build = page("MainList") },
		{ Name = "Side", Build = page("SideList") },
	}, function()
		fitLog()
	end)
	logTabs.select("Main")
end

function Quests.open(tab)
	if not log then
		buildLog()
	end
	logTabs.select(tab or "Main")
	refreshLog()
	log.open()
end

function Quests.close()
	if log then
		log.close()
	end
	if dlg then
		dlg.close()
	end
end

-- ===================================================================== NPC overhead tags and markers
local tags = {} -- npc model -> { Board, Mark }

local function markFor(npcId, qp, qs, level)
	local ready, active, offer = false, false, false
	local m = qp.Main
	if mainNotStarted(qp) then
		if npcId == "Elder" then
			offer = true
		end
	elseif m.Npc == npcId then
		if m.Offered then
			offer = true
		elseif m.Ready then
			ready = true
		else
			active = true
		end
	end
	local activeCount = 0
	for id, s in pairs(qp.Side) do
		activeCount += 1
		if s.Npc == npcId then
			if s.Ready then
				ready = true
			else
				active = true
			end
		end
	end
	if activeCount < Config.Quests.MaxSide then
		local day = today()
		for id, def in pairs(Config.SideQuests) do
			if def.Npc == npcId and qp.Side[id] == nil and qs.Side[id] == nil and qs.SideDone[id] ~= day and (def.MinLevel or 1) <= level then
				offer = true
			end
		end
	end
	if ready then
		return "?", GOLD
	elseif offer then
		return "!", GOLD
	elseif active then
		return "?", Color3.fromRGB(190, 190, 180)
	end
	return nil
end

local function refreshMarks()
	local qp = progress()
	local qs = questState()
	local level = State.attr("Level", 1)
	for model, tag in pairs(tags) do
		local id = model:GetAttribute("NpcId")
		local mark, color = markFor(id, qp, qs, level)
		tag.Mark.Visible = mark ~= nil
		if mark then
			tag.Mark.Text = mark
			tag.Mark.TextColor3 = color
		end
	end
end

local function addTag(model)
	if tags[model] or not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("NpcId")
	if not id then
		return
	end
	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5) or model.PrimaryPart
	if not head then
		return
	end
	local def = Config.Npcs[id] or {}
	local board = UI.new("BillboardGui", { Name = "NpcTag", Adornee = head, Size = UDim2.fromOffset(220, 110), StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
		MaxDistance = 80, LightInfluence = 0, ResetOnSpawn = false, Parent = promptGui })
	local mark = UI.text({ Text = "!", Size = UDim2.new(1, 0, 0, 52), TextSize = 50, Weight = Enum.FontWeight.Heavy, TextColor3 = GOLD,
		Stroke = Color3.fromRGB(70, 44, 10), StrokeThickness = 3, Visible = false, Parent = board })
	UI.text({ Text = def.Name or id, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 54), TextSize = 24, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.White, Stroke = T.TealLine, StrokeThickness = 2, Parent = board })
	UI.text({ Text = def.Title or "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 84), TextSize = 18, Weight = Enum.FontWeight.Bold,
		TextColor3 = T.Cream, Stroke = T.TealLine, StrokeThickness = 1.6, Parent = board })
	tags[model] = { Board = board, Mark = mark }
	model.Destroying:Once(function()
		local t = tags[model]
		tags[model] = nil
		if t then
			t.Board:Destroy()
		end
	end)
	for _, d in ipairs(model:GetDescendants()) do
		claimPrompt(d)
	end
	model.DescendantAdded:Connect(claimPrompt)
	refreshMarks()
end

local function watchNpcs(folder)
	for _, m in ipairs(folder:GetChildren()) do
		task.spawn(addTag, m)
	end
	folder.ChildAdded:Connect(function(m)
		task.spawn(addTag, m)
	end)
end

-- ===================================================================== start
function Quests.Start(c)
	C = c
	buildDialog()
	-- prompts
	ProximityPromptService.PromptShown:Connect(showPrompt)
	ProximityPromptService.PromptHidden:Connect(hidePrompt)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if isTalk(prompt) then
			Quests.talk(npcOfPrompt(prompt))
		end
	end)
	-- NPCs (streamed in and out)
	task.spawn(function()
		local folder = workspace:WaitForChild("Npcs", 60)
		if folder then
			watchNpcs(folder)
		end
	end)
	-- progress changes: marks, log, auto waypoint to a ready main quest
	local lastReady
	local function onProgress()
		refreshMarks()
		if log and UI.isOpen(log) then
			refreshLog()
		end
		local qp = progress()
		local readyKey = (qp.Main and qp.Main.Ready) and qp.Main.Id or nil
		if readyKey and readyKey ~= lastReady then
			Quests.waypoint(qp.Main.Npc, false)
			toast(string.format("%s is done! Return to %s.", qp.Main.Title or "Main quest", npcName(qp.Main.Npc)), "Legendary")
		elseif not readyKey and not waypoint.Manual then
			Quests.waypoint(nil)
		end
		lastReady = readyKey
	end
	player:GetAttributeChangedSignal("QuestProgress"):Connect(onProgress)
	player:GetAttributeChangedSignal("Level"):Connect(refreshMarks)
	State.Changed:Connect(refreshMarks)
	workspace:GetAttributeChangedSignal("UtcDay"):Connect(refreshMarks)
	onProgress()
	-- waypoint follow loop
	RunService.Heartbeat:Connect(function()
		local model = waypoint.Npc and npcModel(waypoint.Npc)
		local head = model and (model:FindFirstChild("Head") or model.PrimaryPart)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (head and hrp) then
			wpBoard.Enabled = false
			wpBeam.Enabled = false
			return
		end
		local target = head.Position + Vector3.new(0, 7 + math.abs(math.sin(os.clock() * 4)) * 1.5, 0)
		wpPart.Position = target
		wpBoard.Enabled = true
		wpText.Text = npcName(waypoint.Npc)
		if not wpA1 or wpA1.Parent ~= hrp then
			wpA1 = Instance.new("Attachment")
			wpA1.Name = "QuestPath"
			wpA1.Position = Vector3.new(0, -2.5, 0)
			wpA1.Parent = hrp
			wpBeam.Attachment1 = wpA1
		end
		local dist = (hrp.Position - head.Position).Magnitude
		wpBeam.Enabled = dist > 20
		-- arrived: a "Track" waypoint has done its job
		if waypoint.Manual and dist < 10 then
			Quests.waypoint(nil)
		end
	end)
end

return Quests
