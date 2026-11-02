-- StarterPlayerScripts/MystreeClient/Interact (ModuleScript)
-- Walk-up interactables in the world that open windows (user, 2026-10-26: "physical parts you can
-- interact with to make the UIs show up"). Builders puts an invisible part named "Interact" with a
-- ProximityPrompt "Interact" (attributes Opens = client module, Tab) on: the Summoning Shrine
-- (Spirits/Summon), Jin's stall (Shop), the stable (Mounts), the quest board (Quests), the Hall of
-- Fame (Leaderboard), and on every island the storage chest (Bag) and decor workbench (Island).
--  * Prompts draw as a jade pill over the object ("[E] Summon · Summoning Shrine"), fading and
--    scaling in and out; on touch the pill itself is the button.
--  * Your own Divine Tree gets a client-side "Tend tree" prompt (key F, since E chops) that opens
--    the Tree window.
--  * Every tree has a billboard: owner and level, and on yours a slim growth line (growing timer,
--    "Ready to grow!", or what the next level costs).
--  * The Hall of Fame steles are filled from workspace.Boards.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local Interact = {}
local C
local T = UI.T
local player = Players.LocalPlayer

local FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local promptGui = UI.new("ScreenGui", { Name = "MystreeInteract", ResetOnSpawn = false, DisplayOrder = 8, IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None, Parent = UI.PlayerGui })
local pills = {} -- prompt -> billboard
local pillGen = {} -- prompt -> counter, so a pill measured while hidden again isn't shown
local labelWidth = {} -- label -> measured text width
local treeBoards = {} -- tree model -> { Board, Name, Level, Line?, Bar? }

local function isInteract(prompt)
	return prompt:IsA("ProximityPrompt") and prompt.Name == "Interact" and prompt:GetAttribute("Opens") ~= nil
end

local function keyGlyph(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return nil
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

-- ===================================================================== prompt pills
local function showPill(prompt, inputType)
	if not isInteract(prompt) then
		return
	end
	local old = pills[prompt]
	if old then
		old:Destroy()
		pills[prompt] = nil
	end
	pillGen[prompt] = (pillGen[prompt] or 0) + 1
	local gen = pillGen[prompt]
	local label = prompt.ActionText .. ((prompt.ObjectText ~= "") and (" · " .. prompt.ObjectText) or "")
	-- the pill hugs its label: key (60) + text + right margin (measuring may yield once per label)
	labelWidth[label] = labelWidth[label] or UI.textWidth(label, 22, Enum.FontWeight.Heavy)
	if pillGen[prompt] ~= gen then
		return
	end
	local width = math.clamp(math.ceil(60 + labelWidth[label] + 24), 150, 340)
	local board = UI.new("BillboardGui", { Name = "InteractPrompt", Adornee = prompt.Parent, Size = UDim2.fromOffset(width, 64), StudsOffset = Vector3.new(0, 1.4, 0),
		AlwaysOnTop = true, LightInfluence = 0, Active = true, ResetOnSpawn = false, Parent = promptGui })
	local group = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Parent = board })
	local scale = UI.new("UIScale", { Scale = 0.8, Parent = group })
	local pill = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.04, Parent = group })
	UI.corner(30, pill)
	UI.stroke(pill, T.Ornament, 2.5)
	UI.gradient(pill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 214, 210))
	local glyph = keyGlyph(prompt, inputType)
	local key = UI.new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(9, 8), BackgroundColor3 = T.Parchment, Parent = pill })
	UI.corner(10, key)
	UI.stroke(key, T.TealLine, 2)
	UI.text({ Text = glyph or "Tap", Size = UDim2.fromScale(1, 1), TextSize = glyph and 24 or 16, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = key })
	UI.text({ Text = label, Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(60, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 22, Weight = Enum.FontWeight.Heavy, Scaled = true, MaxTextSize = 22, Parent = pill })
	pill.Activated:Connect(function()
		-- on touch (and mouse) the pill is the button: it triggers the real prompt
		prompt:InputHoldBegin()
		prompt:InputHoldEnd()
	end)
	TweenService:Create(group, FADE, { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	pills[prompt] = board
end

local function hidePill(prompt)
	pillGen[prompt] = (pillGen[prompt] or 0) + 1
	local board = pills[prompt]
	pills[prompt] = nil
	if not board then
		return
	end
	local group = board:FindFirstChildOfClass("CanvasGroup")
	if group then
		TweenService:Create(group, FADE, { GroupTransparency = 1 }):Play()
		local s = group:FindFirstChildOfClass("UIScale")
		if s then
			TweenService:Create(s, FADE, { Scale = 0.85 }):Play()
		end
	end
	task.delay(0.2, function()
		board:Destroy()
	end)
end

local function claim(d)
	if d:IsA("ProximityPrompt") and d.Name == "Interact" then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function onTriggered(prompt)
	if not isInteract(prompt) then
		return
	end
	local opens, tab = prompt:GetAttribute("Opens"), prompt:GetAttribute("Tab")
	local mod = C and C[opens]
	Sounds.play("Click")
	local at = prompt.Parent
	if at and at:IsA("BasePart") then
		Fx.ring(at.Position - Vector3.new(0, 2.6, 0), T.Ornament, 8, 0.4)
	end
	if mod and mod.open then
		local ok, err = pcall(mod.open, tab)
		if not ok then
			warn("[Interact] " .. tostring(opens) .. ".open failed: " .. tostring(err))
		end
	elseif C and C.Notify then
		C.Notify.toast("Coming soon.", "Info")
	end
end

-- ===================================================================== your tree's "Tend tree" prompt
local tendPrompt
local function attachTend(tree)
	if tendPrompt then
		tendPrompt:Destroy()
		tendPrompt = nil
	end
	if not tree then
		return
	end
	local at = tree:FindFirstChild("Hit") or tree.PrimaryPart
	if not at then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "Interact"
	p.ActionText = "Tend tree"
	p.ObjectText = "Divine Tree"
	p.HoldDuration = 0
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	-- E chops at your tree, so tending uses F / Y
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.GamepadKeyCode = Enum.KeyCode.ButtonY
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Opens", "TreePanel")
	p.Parent = at
	tendPrompt = p
end

local function myPlot()
	local name = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	return name and plots and plots:FindFirstChild(name)
end

-- ===================================================================== tree billboards
local function costText(cost)
	local parts = {}
	for k, n in pairs(cost) do
		local name = (Config.Materials[k] and Config.Materials[k].Name) or (Config.Currencies[k] and Config.Currencies[k].Name) or k
		table.insert(parts, Format.Num(n) .. " " .. name)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function canAfford(cost)
	for k, n in pairs(cost) do
		local have = Config.Materials[k] and State.attr("Mat_" .. k, 0) or State.attr(k, 0)
		if have < n then
			return false
		end
	end
	return true
end

local function buildTreeBoard(tree)
	if treeBoards[tree] then
		return
	end
	local root = tree.PrimaryPart or tree:FindFirstChild("Hit")
	if not root then
		return
	end
	local _, size = tree:GetBoundingBox()
	local board = UI.new("BillboardGui", { Name = "TreeBoard", Adornee = root, Size = UDim2.fromOffset(240, 92),
		StudsOffsetWorldSpace = Vector3.new(0, size.Y + 3, 0), MaxDistance = 140, LightInfluence = 0, AlwaysOnTop = false, ResetOnSpawn = false, Parent = promptGui })
	local group = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Parent = board })
	local name = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 24), TextSize = 20, Weight = Enum.FontWeight.Heavy, Parent = group })
	local level = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 22), TextSize = 26, Weight = Enum.FontWeight.Heavy,
		TextColor3 = Color3.fromRGB(255, 232, 170), Stroke = Color3.fromRGB(60, 40, 20), StrokeThickness = 2, Parent = group })
	local entry = { Board = board, Group = group, Name = name, Level = level }
	if tree:GetAttribute("Owner") == player.UserId then
		entry.Line = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 52), TextSize = 16, Weight = Enum.FontWeight.Bold, Parent = group })
		local bar = UI.new("Frame", { Size = UDim2.new(0.8, 0, 0, 8), Position = UDim2.new(0.1, 0, 0, 76), BackgroundColor3 = T.Bar, BackgroundTransparency = 0.1, Visible = false, Parent = group })
		UI.corner(4, bar)
		UI.stroke(bar, Color3.fromRGB(20, 18, 14), 1.2)
		local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.White, Parent = bar })
		UI.corner(4, fill)
		UI.gradient(fill, Color3.fromRGB(150, 235, 140), Color3.fromRGB(70, 170, 90), 0)
		entry.Bar = bar
		entry.Fill = fill
		entry.Scale = UI.new("UIScale", { Parent = entry.Line })
	end
	treeBoards[tree] = entry
	TweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()
	tree.Destroying:Once(function()
		treeBoards[tree] = nil
		board:Destroy()
	end)
end

local function refreshTreeBoard(tree, entry, now)
	local ownerId = tree:GetAttribute("Owner")
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	local lv = tree:GetAttribute("Level") or 1
	entry.Name.Text = owner and (owner.DisplayName .. "'s Divine Tree") or "Divine Tree"
	entry.Level.Text = "Tree Lv " .. lv
	if not entry.Line then
		return
	end
	local T2 = State.Tree or {}
	if lv >= Config.Tree.MaxLevel then
		entry.Line.Text = "Fully grown"
		entry.Bar.Visible = false
	elseif T2.Growing then
		local _, total = Rules.growthCost(lv)
		local left = math.max(0, (T2.GrowEndsAt or 0) - os.time())
		entry.Line.Text = string.format("Growing to Lv %d · %s", lv + 1, Format.Time(left))
		entry.Line.TextColor3 = Color3.fromRGB(190, 240, 180)
		entry.Bar.Visible = true
		local frac = (total and total > 0) and (1 - left / total) or 1
		TweenService:Create(entry.Fill, TweenInfo.new(0.45), { Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) }):Play()
		entry.Scale.Scale = 1
	else
		local cost = Rules.growthCost(lv)
		entry.Bar.Visible = false
		if canAfford(cost) then
			entry.Line.Text = "Ready to grow!"
			entry.Line.TextColor3 = T.Gold
			entry.Scale.Scale = 1 + 0.06 * math.sin(now * 5)
		else
			entry.Line.Text = "Next: " .. costText(cost)
			entry.Line.TextColor3 = T.TextLight
			entry.Scale.Scale = 1
		end
	end
end

local function scanTrees()
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local tree = plot:FindFirstChild("Tree")
		if tree then
			buildTreeBoard(tree)
		end
	end
	-- your own tree's prompt follows rebuilds (new stage = new model)
	local mine = myPlot()
	local tree = mine and mine:FindFirstChild("Tree")
	if tree and (not tendPrompt or not tendPrompt:IsDescendantOf(tree)) then
		attachTend(tree)
	elseif not tree and tendPrompt then
		attachTend(nil)
	end
end

-- ===================================================================== Hall of Fame
local RANK = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(214, 220, 230), Color3.fromRGB(218, 148, 92) }
local lastBoards

local function fillBoard(part)
	local gui = part:FindFirstChild("Board")
	local list = lastBoards and lastBoards[part:GetAttribute("Board")]
	if not (gui and list) then
		return
	end
	-- rows are Rank / Player / Value labels; the top three take medal colours, your own name is gold
	local me = game:GetService("Players").LocalPlayer.UserId
	for r = 1, 10 do
		local row = gui:FindFirstChild("Row" .. r)
		local e = list[r]
		if row then
			local plain = Color3.fromRGB(226, 236, 230)
			row.Rank.Text = tostring(r)
			row.Rank.TextColor3 = RANK[r] or Color3.fromRGB(150, 168, 162)
			local who = row:FindFirstChild("Player")
			if who and e then
				who.Text = e.Name or "?"
				who.TextColor3 = (e.UserId == me) and Color3.fromRGB(255, 215, 90) or plain
				row.Value.Text = Format.Num(e.Value or 0)
			elseif who then
				who.Text = (r == 1 and #list == 0) and "No entries yet" or "-"
				who.TextColor3 = Color3.fromRGB(120, 140, 134)
				row.Value.Text = ""
			end
		end
	end
	local sub = gui:FindFirstChild("Sub")
	if sub then
		sub.Text = lastBoards.Offline and "TOP 10 · THIS SERVER" or "TOP 10 · ALL SERVERS"
	end
end

local function fillAllBoards()
	local raw = workspace:GetAttribute("Boards")
	if type(raw) == "string" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then
			lastBoards = data
		end
	end
	local map = workspace:FindFirstChild("Map")
	if not (map and lastBoards) then
		return
	end
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Board") then
			fillBoard(d)
		end
	end
end

function Interact.Start(c)
	C = c
	for _, d in ipairs(workspace:GetDescendants()) do
		claim(d)
	end
	workspace.DescendantAdded:Connect(function(d)
		claim(d)
		-- steles streaming in get filled right away
		if d:IsA("BasePart") and d:GetAttribute("Board") then
			task.defer(fillBoard, d)
		end
	end)
	ProximityPromptService.PromptShown:Connect(showPill)
	ProximityPromptService.PromptHidden:Connect(hidePill)
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	workspace:GetAttributeChangedSignal("Boards"):Connect(fillAllBoards)
	fillAllBoards()
	-- trees: billboards and your Tend prompt (2 Hz scan, 4 Hz text)
	task.spawn(function()
		local tick = 0
		while true do
			tick += 1
			if tick % 2 == 0 then
				scanTrees()
			end
			local now = os.clock()
			for tree, entry in pairs(treeBoards) do
				if tree.Parent then
					refreshTreeBoard(tree, entry, now)
				end
			end
			task.wait(0.25)
		end
	end)
end

return Interact
