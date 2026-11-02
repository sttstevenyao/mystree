-- StarterPlayerScripts/MystreeClient/Chop (ModuleScript)
-- Chopping the Divine Tree: the moment-to-moment loop, built to feel good on every strike.
--  * Strike: an overhead axe swing (Rig.Chop); on impact a wood-chip and leaf burst at the trunk,
--    a crack sound with random pitch, a small camera kick, the tree shudders, the veins flare, and
--    the server is asked for the drop (Net "Chop"). The drop itself is shown by Loot.
--  * The CHOP button (or gamepad X) takes out the axe (putting the weapon away) and strikes; pressed
--    away from your tree it walks you there with the axe out. With the axe out at your tree, click or
--    tap anywhere in the world to strike, hold to keep striking (user, 2026-10-27).
--  * Auto: keeps striking on Config.Tree.AutoInterval (Swift Auto pass: SwiftAutoInterval) while you
--    stand at your tree; moving away pauses it. Chopping is free.
--  * Everyone sees other players chop (Net "Chopped"): their swing, chips and sound at their tree.
--  * On the islands every player carries an axe: on the back, in the right hand while "Held" is
--    "Axe" (Equipment does the draw / sheathe moves). Chopping takes the axe out first (the CHOP
--    button too); E puts it away. No axe in the Village or the Hunting Grounds.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)
local Rig = require(script.Parent.Rig)

local Chop = {}
local C
local player = Players.LocalPlayer

local BARK = Color3.fromRGB(150, 112, 74)
local LEAF = Color3.fromRGB(120, 180, 110)
local VEIN = Color3.fromRGB(90, 200, 255)

-- ===================================================================== finding trees
local function plotOf(pl)
	local name = pl:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	return name and plots and plots:FindFirstChild(name)
end

local function treeOf(pl)
	local plot = plotOf(pl)
	return plot and plot:FindFirstChild("Tree")
end

local function hitPoint(tree, fromPos)
	local hit = tree:FindFirstChild("Hit")
	local base = tree:GetPivot().Position
	local p = hit and hit.Position or (base + Vector3.new(0, 4, 0))
	if fromPos then
		-- the side of the trunk facing the chopper
		local flat = (fromPos - base) * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.1 then
			local r = hit and (hit.Position - base) * Vector3.new(1, 0, 1)
			p = Vector3.new(base.X, p.Y, base.Z) + flat.Unit * ((r and r.Magnitude) or 3)
		end
	end
	return p
end

local function nearOwnTree()
	local tree = treeOf(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (tree and hrp) then
		return false, tree, hrp
	end
	local d = ((hrp.Position - tree:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude
	return d <= Config.Tree.ChopRange - 4, tree, hrp
end

-- ===================================================================== the strike's feel
local function wobble(tree)
	if tree:GetAttribute("Wobbling") then
		return
	end
	tree:SetAttribute("Wobbling", true)
	local base = tree:GetPivot()
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(x)
		if tree.Parent then
			tree:PivotTo(base * CFrame.Angles(math.rad(x), 0, math.rad(x * 0.6)))
		end
	end)
	local t1 = TweenService:Create(v, TweenInfo.new(0.06), { Value = 1.4 })
	t1:Play()
	t1.Completed:Wait()
	local t2 = TweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), { Value = 0 })
	t2:Play()
	t2.Completed:Wait()
	if tree.Parent then
		tree:PivotTo(base)
	end
	v:Destroy()
	tree:SetAttribute("Wobbling", nil)
end

local function flareVeins(tree)
	for _, p in ipairs(tree:GetChildren()) do
		if p.Name == "Vein" and p:IsA("BasePart") then
			p.Color = Color3.new(1, 1, 1)
			TweenService:Create(p, TweenInfo.new(0.5), { Color = VEIN }):Play()
		end
	end
end

local function impactFx(tree, pos, strong, isMine)
	Fx.burst(pos, { Texture = "Square", Color = BARK, Color2 = BARK:Lerp(Color3.new(0, 0, 0), 0.3), Count = strong and 16 or 10, Speed = { 14, 26 },
		Size = 0.45, Lifetime = { 0.5, 0.9 }, Spread = 70, Gravity = Vector3.new(0, -60, 0), Rotation = 400 })
	Fx.burst(pos + Vector3.new(0, 10, 0), { Texture = "Square", Color = LEAF, Count = 6, Speed = { 3, 8 }, Size = 0.35, Lifetime = { 1.2, 2 }, Spread = 180, Gravity = Vector3.new(0, -6, 0), Drag = 1 })
	Fx.burst(pos, { Texture = "Glow", Color = VEIN, Count = 4, Speed = { 2, 6 }, Size = 0.6, Lifetime = { 0.4, 0.7 }, Light = 1, Gravity = Vector3.zero })
	if isMine then
		Sounds.play("Chop", 0.92 + math.random() * 0.16)
		Fx.shake(strong and 1.1 or 0.6, 0.18)
	else
		Sounds.at("Chop", pos, 0.92 + math.random() * 0.16, 0.6)
	end
	task.spawn(wobble, tree)
	flareVeins(tree)
end

-- ===================================================================== striking
local busy = false
local lastStrike = 0

local function interval()
	if State.Auto and State.attr("Pass_SwiftAuto", false) then
		return Config.Tree.SwiftAutoInterval
	end
	return State.Auto and Config.Tree.AutoInterval or Config.Tree.ChopCooldown
end

local function walkToTree()
	local plot = plotOf(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local stand = plot and plot:FindFirstChild("Stand")
	if hum and stand then
		hum:MoveTo(stand.Position)
	end
end

-- manual = pressed by the player (shows hints); fromKey = the E / X key, which only chops at your
-- tree (E also talks to NPCs, so away from the tree it must do nothing)
function Chop.chop(manual, fromKey)
	if player:GetAttribute("InGrounds") then
		return false
	end
	local near, tree, hrp = nearOwnTree()
	if not tree then
		if manual then
			C.Notify.toast("Your island is getting ready. One moment!", "Info")
		end
		return false
	end
	if not near then
		if manual and not fromKey then
			-- far from the tree: on your island, walk there; elsewhere, go home
			if plotOf(player) and hrp and (hrp.Position - tree:GetPivot().Position).Magnitude < 120 then
				-- walk over, swapping the weapon for the axe on the way
				walkToTree()
				if C.Equipment then
					C.Equipment.setHeld("Axe")
				end
			else
				task.spawn(C.Transition.travel, "Travel", "Home")
			end
		end
		return false
	end
	if busy or os.clock() - lastStrike < interval() * 0.95 then
		return false
	end
	-- the axe comes out first (putting the weapon away if it's out); the next press chops
	if C.Equipment and C.Equipment.held() ~= "Axe" then
		C.Equipment.setHeld("Axe")
		lastStrike = os.clock() + 0.5
		return false
	end
	busy = true
	lastStrike = os.clock()
	local char = player.Character
	-- face the trunk
	local base = tree:GetPivot().Position
	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(base.X, hrp.Position.Y, base.Z))
	Sounds.play("Whoosh", 1.2 + math.random() * 0.2, 0.5)
	local dur = math.min(0.45, interval())
	Rig.play(char, Rig.Chop, dur, { HitAt = 0.55, OnHit = function()
		-- ask for the drop first, so a visual error can never cost a chop
		task.spawn(function()
			local ok, msg, why = Net.invoke("Chop")
			if not ok and msg then
				C.Notify.toast(msg, "Error")
			end
		end)
		if C.Hud then
			C.Hud.pulseChop()
		end
		impactFx(tree, hitPoint(tree, hrp.Position), false, true)
	end })
	task.delay(dur, function()
		busy = false
	end)
	return true
end

function Chop.setAuto(on)
	State.Auto = on
	if C.Hud then
		C.Hud.setAutoLook(on)
	end
	if on then
		local near = nearOwnTree()
		if not near then
			walkToTree()
		end
		C.Notify.toast("Auto-chop on: stand at your tree and it keeps chopping.", "Info")
	end
end

-- ===================================================================== axes in hand (every player)
local axes = {} -- player -> axe model
local axeHand = {} -- player -> the hand part the axe is welded to
-- the axe is for islands only: not in the Hunting Grounds, not in the Village (user)
local function inVillage(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position * Vector3.new(1, 0, 1)).Magnitude < Config.Map.VillageRadius
end
-- on the back: the grip low on the left, the head up over the right shoulder (UpperTorso space)
local BACK_POS, BACK_DIR = Vector3.new(-0.45, -0.55, 0.7), Vector3.new(0.45, 0.88, 0.1).Unit
local function updateAxe(pl)
	local char = pl.Character
	local inHand = C and C.Equipment and C.Equipment.shown(pl) == "Axe"
	local mount = char and char:FindFirstChild(inHand and "RightHand" or "UpperTorso")
	local want = mount and not pl:GetAttribute("InGrounds") and not inVillage(char)
	local cur = axes[pl]
	if want and (not cur or not cur.Parent or axeHand[pl] ~= mount) then
		if cur then
			cur:Destroy()
		end
		local axe = Assets.Axe()
		axe.Name = "MystreeAxe"
		local grip = axe.PrimaryPart:FindFirstChild("Grip")
		for _, p in ipairs(axe:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Massless = true
			end
		end
		local gripCf = grip and grip.WorldCFrame or axe.PrimaryPart.CFrame
		local target
		if inHand then
			local handGrip = mount:FindFirstChild("RightGripAttachment")
			target = handGrip and handGrip.WorldCFrame or mount.CFrame
		else
			-- turn the grip so the head points up the back
			local head = gripCf:PointToObjectSpace(axe:GetBoundingBox().Position)
			local frame = mount.CFrame * CFrame.new(BACK_POS)
			target = CFrame.new(frame.Position) * (frame - frame.Position) * C.Equipment.turnTo(head.Magnitude > 0.1 and head.Unit or Vector3.yAxis, BACK_DIR)
		end
		axe:PivotTo(target * gripCf:Inverse() * axe:GetPivot())
		for _, p in ipairs(axe:GetDescendants()) do
			if p:IsA("BasePart") then
				local w = Instance.new("WeldConstraint")
				w.Part0 = mount
				w.Part1 = p
				w.Parent = p
			end
		end
		axeHand[pl] = mount
		axe.Parent = char
		axes[pl] = axe
	elseif not want and cur then
		cur:Destroy()
		axes[pl] = nil
	end
end

local function watchPlayer(pl)
	pl.CharacterAdded:Connect(function(char)
		char:WaitForChild("RightHand", 10)
		task.wait(0.5)
		updateAxe(pl)
	end)
	pl:GetAttributeChangedSignal("InGrounds"):Connect(function()
		updateAxe(pl)
	end)
	if pl.Character then
		task.spawn(updateAxe, pl)
	end
end

-- ===================================================================== start
function Chop.Start(c)
	C = c
	Net.get("Chopped").OnClientEvent:Connect(function(pl, info)
		if pl == player then
			return
		end
		local tree = treeOf(pl)
		local char = pl.Character
		if not (tree and char) then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		Rig.play(char, Rig.Chop, 0.45, { HitAt = 0.55, OnHit = function()
			impactFx(tree, hitPoint(tree, hrp and hrp.Position), (info.R or 1) >= 4, false)
		end })
	end)
	for _, pl in ipairs(Players:GetPlayers()) do
		watchPlayer(pl)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(pl)
		axes[pl] = nil
		axeHand[pl] = nil
	end)
	-- the axe follows its owner between back and hand (draw moves swap mid-move), and comes off
	-- in the Village and the Hunting Grounds; leaving the islands with it out puts it away
	-- (not in the first seconds of a character: it spawns near the Village centre before it's moved
	-- to the island, and you start with the axe out)
	local spawnedAt = os.clock()
	player.CharacterAdded:Connect(function()
		spawnedAt = os.clock()
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, pl in ipairs(Players:GetPlayers()) do
				updateAxe(pl)
			end
			local char = player.Character
			if C.Equipment and C.Equipment.held() == "Axe" and os.clock() - spawnedAt > 4 and (player:GetAttribute("InGrounds") or inVillage(char)) then
				C.Equipment.setHeld("")
			end
		end
	end)
	-- gamepad X strikes at the tree (E draws / sheathes now: Equipment)
	ContextActionService:BindAction("MystreeChop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and nearOwnTree() then
			Chop.chop(true, true)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonX)
	-- click / tap anywhere in the world at your tree to strike; holding keeps striking (the chop
	-- cooldown paces it). A touch that drags is turning the camera, not chopping.
	local holding, touch = false, nil
	-- with the axe out (otherwise the click swings your weapon: Combat)
	local function canClick()
		return not player:GetAttribute("InGrounds") and C.Equipment and C.Equipment.held() == "Axe" and nearOwnTree()
			and not (C.Island and C.Island.isEditing and C.Island.isEditing())
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and canClick() then
			holding = true
			touch = t == Enum.UserInputType.Touch and { Input = input, Pos = input.Position } or nil
			Chop.chop(true, true)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if touch and input == touch.Input and (input.Position - touch.Pos).Magnitude > 14 then
			holding, touch = false, nil
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or (touch and input == touch.Input) then
			holding, touch = false, nil
		end
	end)
	-- auto-chop loop (and held clicks), and the soft glow pulse on your own tree's veins
	RunService.Heartbeat:Connect(function()
		if State.Auto then
			Chop.chop(false)
		elseif holding and canClick() then
			Chop.chop(false)
		end
	end)
	task.spawn(function()
		-- the vein list is cached per tree (a regrown tree is a new model), and the pulse sleeps
		-- while you're away from your island
		local veinTree, veins = nil, {}
		while true do
			local tree = treeOf(player)
			if tree ~= veinTree then
				veinTree, veins = tree, {}
				for _, p in ipairs(tree and tree:GetChildren() or {}) do
					if p.Name == "Vein" and p:IsA("BasePart") then
						table.insert(veins, p)
					end
				end
			end
			local cam = workspace.CurrentCamera
			if tree and cam and (tree:GetPivot().Position - cam.CFrame.Position).Magnitude < 400 then
				local k = 0.5 + 0.5 * math.sin(os.clock() * 2)
				for _, p in ipairs(veins) do
					p.Transparency = 0.15 * k
				end
				task.wait(0.05)
			else
				task.wait(0.5)
			end
		end
	end)
end

return Chop
