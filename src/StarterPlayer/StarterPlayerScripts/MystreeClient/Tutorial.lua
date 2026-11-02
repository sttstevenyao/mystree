-- StarterPlayerScripts/MystreeClient/Tutorial (ModuleScript)
-- Shows the progression tutorial the server runs (TutorialService, Config.Tutorial):
--  * a goal pill at the top: "STEP 2/5 · Grow your tree", progress, the reward, and a Skip button;
--  * a spotlight: the screen dims except the button to press (four dark Frames around it, never
--    Active, so they never catch a click), with a bouncing arrow on the button;
--  * in the world: a bouncing arrow over the target (your tree, the gate, the nearest monster) and a
--    glowing path to it.
-- The player is never blocked: everything stays clickable, and steps done out of order still count.
-- Wording follows the device: Tap / Click / Press.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local Tutorial = {}
local C
local T = UI.T
local player = Players.LocalPlayer
local STEPS = Config.Tutorial
local GOLD = T.Gold

local function active()
	local i = player:GetAttribute("Tutorial")
	return i ~= nil and i <= #STEPS
end
Tutorial.active = active

-- "Tap" on touch, "Press" with a gamepad, "Click" with a mouse
local function verb()
	if UserInputService:GetLastInputType().Name:find("Gamepad") then
		return "Press"
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return "Tap"
	end
	return "Click"
end

local function wording(text)
	local v = verb()
	return (text:gsub("{Tap}", v):gsub("{tap}", string.lower(v)))
end

local function rewardText(reward)
	local parts = {}
	for k, n in pairs(reward) do
		if k == "Weapon" then
			local name = Config.Rarities[n].Name
			local article = name:sub(1, 1):match("[AEIOUaeiou]") and "an " or "a "
			table.insert(parts, article .. name .. "+ weapon")
		else
			local name = (Config.Currencies[k] and Config.Currencies[k].Name) or (Config.Materials[k] and Config.Materials[k].Name) or k
			table.insert(parts, "+" .. Format.Num(n) .. " " .. name)
		end
	end
	return table.concat(parts, ", ")
end

-- ===================================================================== the goal pill
local _, root = UI.screen("MystreeTutorial", 25)
-- sits a little right of centre so it clears the CP banner; shrinks while a window is open
-- centred just below the top HUD rows (profile, clock, travel), where nothing else lives
local PILL_POS = UDim2.new(0.5, 0, 0, 86)
local pill = UI.new("Frame", { Name = "Goal", Size = UDim2.fromOffset(380, 84), AnchorPoint = Vector2.new(0.5, 0), Position = PILL_POS,
	BackgroundColor3 = T.Parchment, Visible = false, Parent = root })
UI.corner(42, pill)
UI.stroke(pill, T.Ornament, 3)
local glow = UI.stroke(pill, GOLD, 6, 0.6)
glow.Name = "Glow"
local stepTag = UI.new("Frame", { Size = UDim2.fromOffset(92, 30), Position = UDim2.fromOffset(18, -14), BackgroundColor3 = T.White, Parent = pill })
UI.corner(15, stepTag)
UI.gradient(stepTag, T.Header, T.HeaderDark)
UI.stroke(stepTag, T.TealLine, 2)
local stepText = UI.text({ Text = "STEP 1/5", Size = UDim2.fromScale(1, 1), TextSize = 16, Weight = Enum.FontWeight.Heavy, Stroke = T.TealLine, Parent = stepTag })
local goalText = UI.text({ Text = "", Size = UDim2.new(1, -170, 0, 34), Position = UDim2.fromOffset(26, 12), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 23, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Scaled = true, MaxTextSize = 24, Parent = pill })
local rewardLine = UI.text({ Text = "", Size = UDim2.new(1, -170, 0, 24), Position = UDim2.fromOffset(26, 48), TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 17, Weight = Enum.FontWeight.Bold, TextColor3 = T.OrangeDark, Stroke = false, Parent = pill })
local progressText = UI.text({ Text = "", Size = UDim2.fromOffset(70, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -82, 0.5, 0),
	TextSize = 26, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Red, Stroke = false, Parent = pill })
local skipBtn = UI.button({ Text = "Skip", Style = "Grey", Size = UDim2.fromOffset(64, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
	TextSize = 17, Parent = pill })
local skipArmed = 0
skipBtn.Activated:Connect(function()
	Sounds.play("Click")
	if os.clock() > skipArmed then
		skipArmed = os.clock() + 3
		skipBtn.Text = "Sure?"
		task.delay(3, function()
			skipBtn.Text = "Skip"
		end)
		return
	end
	local ok, msg = Net.invoke("SkipTutorial")
	if ok and C.Notify then
		C.Notify.toast(msg, "Info", true)
	end
end)

-- ===================================================================== spotlight + screen arrow
-- Pixel space (no fit scale) so it lines up with any button's AbsolutePosition.
-- full screen, like every other Mystree screen (no inset), so AbsolutePositions line up directly
local spotGui = UI.new("ScreenGui", { Name = "MystreeSpotlight", ResetOnSpawn = false, DisplayOrder = 24, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, Parent = UI.PlayerGui })
local shades = {}
for i = 1, 4 do
	shades[i] = UI.new("Frame", { Name = "Shade" .. i, BackgroundColor3 = Color3.fromRGB(8, 14, 14), BackgroundTransparency = 1, Active = false, Parent = spotGui })
end
local ring = UI.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Visible = false, Active = false, Parent = spotGui })
UI.corner(12, ring)
local ringStroke = UI.stroke(ring, GOLD, 4)
local arrow = UI.new("Frame", { Name = "Arrow", Size = UDim2.fromOffset(44, 56), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Visible = false, Active = false, Parent = spotGui })
-- a downward chevron from frames: a stem and two angled bars
local function arrowShape(parent)
	UI.new("Frame", { Size = UDim2.fromOffset(14, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = GOLD, Parent = parent },
		{ UI.corner(4), UI.new("UIStroke", { Color = Color3.fromRGB(110, 70, 10), Thickness = 2 }) })
	for _, s in ipairs({ -1, 1 }) do
		UI.new("Frame", { Size = UDim2.fromOffset(14, 32), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, s * 9, 1, -2), Rotation = s * 40,
			BackgroundColor3 = GOLD, Parent = parent }, { UI.corner(4), UI.new("UIStroke", { Color = Color3.fromRGB(110, 70, 10), Thickness = 2 }) })
	end
end
arrowShape(arrow)

local shadeOn = false
local function setShade(on)
	if shadeOn == on then
		return
	end
	shadeOn = on
	for _, f in ipairs(shades) do
		TweenService:Create(f, TweenInfo.new(0.25), { BackgroundTransparency = on and 0.45 or 1 }):Play()
	end
	ring.Visible = on
	arrow.Visible = on
end

local function placeSpot(target)
	local inset = 10
	-- AbsolutePosition is measured below the top bar even on full-screen guis, so add the inset back
	local top = GuiService:GetGuiInset()
	local p, s = target.AbsolutePosition + top - Vector2.new(inset, inset), target.AbsoluteSize + Vector2.new(inset * 2, inset * 2)
	local vp = spotGui.AbsoluteSize
	shades[1].Position, shades[1].Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(vp.X, math.max(0, p.Y))
	shades[2].Position, shades[2].Size = UDim2.fromOffset(0, p.Y + s.Y), UDim2.fromOffset(vp.X, math.max(0, vp.Y - p.Y - s.Y))
	shades[3].Position, shades[3].Size = UDim2.fromOffset(0, p.Y), UDim2.fromOffset(math.max(0, p.X), s.Y)
	shades[4].Position, shades[4].Size = UDim2.fromOffset(p.X + s.X, p.Y), UDim2.fromOffset(math.max(0, vp.X - p.X - s.X), s.Y)
	ring.Position, ring.Size = UDim2.fromOffset(p.X, p.Y), UDim2.fromOffset(s.X, s.Y)
	local bob = math.abs(math.sin(os.clock() * 5)) * 12
	-- above the target, or below it when it sits at the top of the screen
	if p.Y > 80 then
		arrow.Rotation = 0
		arrow.AnchorPoint = Vector2.new(0.5, 1)
		arrow.Position = UDim2.fromOffset(p.X + s.X / 2, p.Y - 4 - bob)
	else
		arrow.Rotation = 180
		arrow.AnchorPoint = Vector2.new(0.5, 1)
		arrow.Position = UDim2.fromOffset(p.X + s.X / 2, p.Y + s.Y + 60 + bob)
	end
	ringStroke.Transparency = 0.2 + 0.3 * math.abs(math.sin(os.clock() * 4))
end

-- ===================================================================== world arrow + path
local worldPart = Instance.new("Part")
worldPart.Name = "TutorialMarker"
worldPart.Anchored = true
worldPart.CanCollide = false
worldPart.CanQuery = false
worldPart.CanTouch = false
worldPart.Transparency = 1
worldPart.Size = Vector3.new(1, 1, 1)
worldPart.Parent = Fx.Holder
local board = UI.new("BillboardGui", { Size = UDim2.fromOffset(80, 110), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Parent = worldPart })
local boardArrow = UI.new("Frame", { Size = UDim2.fromOffset(44, 56), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Parent = board })
arrowShape(boardArrow)
local boardText = UI.text({ Text = "", Size = UDim2.new(1, 40, 0, 30), Position = UDim2.fromOffset(-20, 0), TextSize = 22, Weight = Enum.FontWeight.Heavy, TextColor3 = GOLD, Parent = board })
local a0 = Instance.new("Attachment")
a0.Parent = worldPart
local a1 -- on the player's root
local path = Instance.new("Beam")
path.Attachment0 = a0
path.Color = ColorSequence.new(GOLD)
path.Width0 = 0.6
path.Width1 = 0.6
path.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.85) })
path.LightEmission = 1
path.FaceCamera = true
path.Segments = 1
path.Enabled = false
path.Parent = worldPart

-- ===================================================================== step targets
local function shown(obj)
	if not (obj and obj.Parent) then
		return false
	end
	local o = obj
	while o and not o:IsA("LayerCollector") do
		if o:IsA("GuiObject") and not o.Visible then
			return false
		end
		o = o.Parent
	end
	return o ~= nil and o.Enabled and obj.AbsoluteSize.X > 2
end

local function window(name)
	local w = UI.WindowRoot:FindFirstChild(name)
	return (w and w.Visible) and w or nil
end

local function buttonIn(rootObj, prefix)
	for _, d in ipairs(rootObj:GetDescendants()) do
		if d:IsA("TextButton") and d.Text:sub(1, #prefix) == prefix and shown(d) then
			return d
		end
	end
end

local function ownTree()
	local name = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	local plot = name and plots and plots:FindFirstChild(name)
	return plot and plot:FindFirstChild("Tree")
end

local function nearestMob()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("Mobs")
	if not (hrp and folder) then
		return nil
	end
	local best, bd = nil, 250
	for _, m in ipairs(folder:GetChildren()) do
		if m.PrimaryPart and not m:GetAttribute("Dead") and m:GetAttribute("Kind") == "Normal" then
			local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
			if d < bd then
				best, bd = m, d
			end
		end
	end
	return best
end

-- each returns (gui target or nil, world position or nil, world label)
local TARGETS = {
	Chop = function()
		local tree = ownTree()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local far = tree and hrp and (hrp.Position - tree:GetPivot().Position).Magnitude > 30
		return C.Hud and C.Hud.ChopButton, tree and tree:GetPivot().Position + Vector3.new(0, 26, 0), far and "Your tree" or nil
	end,
	Grow = function()
		local w = window("Divine Tree")
		if w then
			return buttonIn(w, "Grow")
		end
		return C.Hud and C.Hud.GrowButton
	end,
	Summon = function()
		local w = window("Spirits")
		if w then
			local one = buttonIn(w, "Summon x1")
			if one then
				return one
			end
			local tabs = w:FindFirstChild("Tabs")
			return tabs and buttonIn(tabs, "Summon")
		end
		return C.Hud and C.Hud.MenuTiles.Spirits
	end,
	Hunt = function()
		local gate = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("HuntGate")
		local inVillage = player:GetAttribute("Zone") == "Village"
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local nearGate = gate and hrp and (hrp.Position - gate:GetPivot().Position).Magnitude < 120
		return C.Hud and C.Hud.TravelButtons.Grounds, (inVillage and nearGate) and gate:GetPivot().Position + Vector3.new(0, 26, 0) or nil, "Hunting Grounds"
	end,
	Elder = function()
		local folder = workspace:FindFirstChild("Npcs")
		local elder
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:GetAttribute("NpcId") == "Elder" then
				elder = m
			end
		end
		local inVillage = player:GetAttribute("Zone") == "Village" and elder and elder.PrimaryPart
			and (elder.PrimaryPart.Position - (player.Character and player.Character:GetPivot().Position or Vector3.zero)).Magnitude < 160
		local gui = (not inVillage) and C.Hud and C.Hud.TravelButtons.Hub or nil
		local pos = elder and elder.PrimaryPart and elder.PrimaryPart.Position + Vector3.new(0, 6, 0)
		return gui, inVillage and pos or nil, "Elder Mo"
	end,
	Kill = function()
		local mob = nearestMob()
		local gui
		if UserInputService.TouchEnabled then
			local combat = UI.PlayerGui:FindFirstChild("MystreeCombat")
			gui = combat and combat:FindFirstChild("Attack", true)
		end
		return gui, mob and mob.PrimaryPart.Position + Vector3.new(0, mob.PrimaryPart.Size.Y / 2 + 6, 0), "Defeat it!"
	end,
}

-- ===================================================================== refresh
local lastStep
local pillTucked = false
local function refreshPill()
	if not active() then
		if pill.Visible then
			UI.popOut(pill)
		end
		setShade(false)
		board.Enabled = false
		path.Enabled = false
		lastStep = nil
		return
	end
	local i = player:GetAttribute("Tutorial")
	local step = STEPS[i]
	stepText.Text = string.format("STEP %d/%d", i, #STEPS)
	goalText.Text = wording(step.Text)
	rewardLine.Text = "Reward: " .. rewardText(step.Reward)
	local have, need = player:GetAttribute("TutorialHave") or 0, player:GetAttribute("TutorialNeed") or step.Need
	progressText.Text = need > 1 and string.format("%d/%d", have, need) or ""
	if lastStep ~= i then
		lastStep = i
		UI.popIn(pill, 0.6)
	end
end

function Tutorial.Start(c)
	C = c
	for _, a in ipairs({ "Tutorial", "TutorialHave", "TutorialNeed" }) do
		player:GetAttributeChangedSignal(a):Connect(refreshPill)
	end
	refreshPill()
	Net.get("Effect").OnClientEvent:Connect(function(kind, index, reward)
		if kind ~= "Tutorial" then
			return
		end
		Sounds.play("LevelUp", 1.15)
		if C.Notify then
			C.Notify.toast("Step complete! " .. rewardText(reward), "Legendary", true)
		end
		local s = pill:FindFirstChild("PopScale")
		if s then
			s.Scale = 1.15
			TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		if index == #STEPS and C.Notify then
			C.Notify.moment("TUTORIAL COMPLETE!", "Your Divine Tree is waiting. Keep growing it!", GOLD, true)
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not active() then
			return
		end
		local step = STEPS[player:GetAttribute("Tutorial")]
		local fn = TARGETS[step.Id]
		local gui, worldPos, label
		if fn then
			gui, worldPos, label = fn()
		end
		-- spotlight only when the button is really on screen and no unrelated window covers it
		local openWin
		for _, w in ipairs(UI.WindowRoot:GetChildren()) do
			if w:IsA("Frame") and w.Name ~= "Backdrop" and w.Visible then
				openWin = w
			end
		end
		if gui and openWin and not gui:IsDescendantOf(openWin) then
			gui = nil
		end
		-- tuck the pill up and smaller over open windows so their titles stay readable (on change only,
		-- so it never fights the pop-in tween)
		local tucked = openWin ~= nil
		if tucked ~= pillTucked then
			pillTucked = tucked
			local ps = pill:FindFirstChild("PopScale") or UI.new("UIScale", { Name = "PopScale", Parent = pill })
			TweenService:Create(ps, TweenInfo.new(0.2), { Scale = tucked and 0.72 or 1 }):Play()
			TweenService:Create(pill, TweenInfo.new(0.2), { Position = tucked and UDim2.new(0.5, 0, 0, -6) or PILL_POS }):Play()
		end
		if gui and shown(gui) then
			setShade(true)
			placeSpot(gui)
		else
			setShade(false)
		end
		if worldPos then
			worldPart.Position = worldPos + Vector3.new(0, math.abs(math.sin(os.clock() * 4)) * 1.5, 0)
			board.Enabled = true
			boardText.Text = label or ""
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				if not a1 or a1.Parent ~= hrp then
					a1 = Instance.new("Attachment")
					a1.Name = "TutorialPath"
					a1.Position = Vector3.new(0, -2.5, 0)
					a1.Parent = hrp
					path.Attachment1 = a1
				end
				-- the path only helps when the target is a walk away
				path.Enabled = (hrp.Position - worldPos).Magnitude > 30
			end
		else
			board.Enabled = false
			path.Enabled = false
		end
	end)
end

return Tutorial
