-- StarterPlayerScripts/MystreeClient/Movement (ModuleScript)
-- How the local player moves (user, 2026-10-27). Numbers in Config.Move.
--  * Shift toggles sprint. The client speeds up at once; the server ("Sprint", StatsService) sets the
--    real speed and the anti-cheat cap. No sprint while riding (mounts have their own speed).
--  * Ctrl toggles the shoulder camera (our own "shift lock"; Roblox's is off through
--    StarterPlayer.EnableMouseLockOption): the mouse locks to the centre under a custom cursor, the
--    camera eases over the right shoulder (Humanoid.CameraOffset) and the body turns to the camera.
--  * Directional walk (Rig.hold "Move"): the body leans into the move and banks into turns. In
--    shoulder mode the hips turn toward a strafe while the chest stays on target, and walking
--    backwards runs the walk cycle in reverse.
--  * Q dashes the way you're moving (or facing). Its style grows with Agility (Config.Move.Dash.Tiers):
--    a plain dodge with dust, a quickstep with ink after-images, then a flashstep (you vanish into ink
--    and reappear further on). The server ("Dash", CombatService) opens an i-frame window, so mob hits miss
--    ("Dodge" effect -> a DODGE tag over the head).
-- Touch: Sprint and Dash buttons beside the jump button. Gamepad: L3 sprint, R1 dash.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Rig = require(script.Parent.Rig)
local Sounds = require(script.Parent.Sounds)

local Movement = {}
local M = Config.Move
local T = UI.T
local player = Players.LocalPlayer

local INK = Color3.fromRGB(18, 18, 24)
local FLASH_STEP = "rbxassetid://15107683952" -- VFX Library: inky_flash_step, Grid4x4
local KEY_RING = "rbxassetid://93858335764593" -- VFX Library: Dragon_Marker_01, a key-pattern ring

local C
local sprinting = false
local walkBase -- the walk speed before sprint (so toggling back is exact)
local locked = false
local lockK = 0 -- the shoulder camera eased in, 0..1
local lastDash = -math.huge
local lean = { 0, 0, 0 } -- the current Root lean (degrees), eased toward the target each frame

local function parts()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

local function riding()
	return player:GetAttribute("Riding") == true
end

-- ===================================================================== the custom cursor
local cursorGui = UI.new("ScreenGui", { Name = "MystreeCursor", ResetOnSpawn = false, DisplayOrder = 70, IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None, Parent = UI.PlayerGui })
local cursor = UI.new("CanvasGroup", { Name = "Cursor", Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = cursorGui })
local cursorScale = UI.new("UIScale", { Scale = 1.4, Parent = cursor })
local ring = UI.new("ImageLabel", { Name = "Ring", Image = KEY_RING, ImageColor3 = T.Gold, ImageTransparency = 0.15, BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1), Parent = cursor })
UI.new("Frame", { Name = "Dot", Size = UDim2.fromOffset(5, 5), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = T.Cream, Parent = cursor }, { UI.corner(3), UI.new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.2 }) })
-- the dash's cooldown sweeps round the ring as a thin gold arc
local dashArc = UI.new("Frame", { Name = "DashReady", Size = UDim2.fromOffset(8, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2),
	BackgroundColor3 = T.Gold, BorderSizePixel = 0, Parent = cursor }, { UI.corner(2) })

local function showCursor(on)
	if on then
		cursor.Visible = true
		cursorScale.Scale = 1.4
		TweenService:Create(cursor, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { GroupTransparency = 0 }):Play()
		TweenService:Create(cursorScale, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Scale = 1 }):Play()
	else
		TweenService:Create(cursor, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
		TweenService:Create(cursorScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 0.8 }):Play()
		task.delay(0.17, function()
			if not locked then
				cursor.Visible = false
			end
		end)
	end
end

-- ===================================================================== sprint
local function setSprint(on)
	if on and riding() then
		on = false
	end
	if on == sprinting then
		return
	end
	sprinting = on
	local _, hum = parts()
	if hum then
		-- at once on this client; the server's value (the same number) replicates a moment later
		if on then
			walkBase = hum.WalkSpeed
			hum.WalkSpeed = walkBase * M.SprintMult
		elseif walkBase then
			hum.WalkSpeed = walkBase
		end
	end
	task.spawn(Net.invoke, "Sprint", on)
end

-- ===================================================================== shoulder camera
local function setLock(on)
	if on == locked then
		return
	end
	locked = on
	showCursor(on)
	UserInputService.MouseIconEnabled = not on
	local _, hum = parts()
	if hum and not on then
		hum.AutoRotate = true
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

-- ===================================================================== dash
local function ghost(char, alpha)
	-- an ink after-image: plain copies of the visible body parts, fading out where they stand
	local folder = Instance.new("Folder")
	folder.Name = "DashGhost"
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 0.9 and not p:FindFirstAncestor("MystreeAxe") then
			local g = p:Clone()
			for _, c in ipairs(g:GetChildren()) do
				if not (c:IsA("SpecialMesh") or c:IsA("DataModelMesh")) then
					c:Destroy()
				end
			end
			g.Anchored = true
			g.CanCollide = false
			g.CanQuery = false
			g.CanTouch = false
			g.CastShadow = false
			g.Material = Enum.Material.SmoothPlastic
			g.Color = INK
			g.Transparency = alpha
			g.LocalTransparencyModifier = 0 -- (a flashstep hides the body this way; the ghost must show)
			if g:IsA("MeshPart") then
				pcall(function()
					g.TextureID = ""
				end)
			end
			g.Parent = folder
			TweenService:Create(g, TweenInfo.new(0.38, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
		end
	end
	folder.Parent = workspace.CurrentCamera
	task.delay(0.42, function()
		folder:Destroy()
	end)
end

local function flashStep(at)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = FLASH_STEP
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Lifetime = NumberRange.new(0.4)
	e.Size = NumberSequence.new(7)
	e.Speed = NumberRange.new(0)
	e.Rate = 0
	e.Color = ColorSequence.new(INK)
	e.LightEmission = 0
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = a
	e:Emit(1)
	task.delay(0.6, function()
		a:Destroy()
	end)
end

local DASH_POSE = {
	{ T = 0, Pose = {} },
	{ T = 0.25, Pose = { Root = { -18, 0, 0 }, Waist = { -8, 0, 0 }, RightShoulder = { -30, 0, 10 }, LeftShoulder = { -30, 0, -10 } } },
	{ T = 0.7, Pose = { Root = { -14, 0, 0 }, RightShoulder = { -24, 0, 8 }, LeftShoulder = { -24, 0, -8 } } },
	{ T = 1, Pose = {} },
}

-- the dash's look per tier (Config.Move.Dash.Tiers, from your Agility)
local function dustPuff(at)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(196, 182, 156))
	e.Size = NumberSequence.new(1.6, 3)
	e.Transparency = NumberSequence.new(0.5, 1)
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(70, 20)
	e.Rate = 0
	e.Parent = a
	e:Emit(10)
	task.delay(0.9, function()
		a:Destroy()
	end)
end

-- flashstep: the body vanishes for the dash (on this screen) and fades back in where it lands
local function vanish(char, t)
	local parts = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
			table.insert(parts, d)
		end
	end
	task.delay(t, function()
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local k = math.min(1, (os.clock() - t0) / 0.14)
			for _, d in ipairs(parts) do
				if d.Parent then
					d.LocalTransparencyModifier = 1 - k
				end
			end
			if k >= 1 then
				conn:Disconnect()
			end
		end)
	end)
end

local function dash()
	local D = M.Dash
	local char, hum, root = parts()
	if not char or riding() or os.clock() - lastDash < D.Cooldown then
		return
	end
	-- Q also turns decor while placing it on your island
	if C and C.Island and C.Island.isPlacing and C.Island.isPlacing() then
		return
	end
	lastDash = os.clock()
	local tier = Config.dashTier(player:GetAttribute("AGL") or 0)
	local dir = hum.MoveDirection * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	dir = dir.Unit
	task.spawn(Net.invoke, "Dash")
	local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MystreeDash"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	lv.VectorVelocity = dir * tier.Speed
	lv.Parent = root
	local feet = root.Position - Vector3.new(0, 2.6, 0)
	Rig.play(char, DASH_POSE, tier.Time + 0.12, { Channel = "Dash" })
	if tier.Name == "Dodge" then
		-- a plain physical dodge: dust kicked up, a lower whoosh
		Sounds.play("Whoosh", 1.0, 0.7)
		dustPuff(feet)
	elseif tier.Name == "Quickstep" then
		-- ink after-images and an ink flash-step where you left
		Sounds.play("Whoosh", 1.25, 0.8)
		flashStep(root.Position - Vector3.new(0, 1.5, 0))
		for i = 0, 2 do
			task.delay(tier.Time * i / 3, function()
				if char.Parent then
					ghost(char, 0.35 + i * 0.15)
				end
			end)
		end
	else
		-- flashstep: gone in a burst of ink, a trail of faint after-images, back in a burst further on
		Sounds.play("Glint", 1.4, 0.9)
		Sounds.play("Whoosh", 1.5, 0.9)
		flashStep(root.Position - Vector3.new(0, 1.5, 0))
		ghost(char, 0.15)
		vanish(char, tier.Time)
		for i = 1, 3 do
			task.delay(tier.Time * i / 4, function()
				if char.Parent then
					ghost(char, 0.55 + i * 0.1)
				end
			end)
		end
		task.delay(tier.Time, function()
			if root.Parent then
				flashStep(root.Position - Vector3.new(0, 1.5, 0))
			end
		end)
	end
	task.delay(tier.Time, function()
		lv:Destroy()
		-- carry a little of the speed out instead of stopping dead
		if root.Parent then
			root.AssemblyLinearVelocity = Vector3.new(dir.X * hum.WalkSpeed, root.AssemblyLinearVelocity.Y, dir.Z * hum.WalkSpeed)
		end
	end)
	-- the cooldown pip under the cursor refills
	dashArc.Size = UDim2.fromOffset(0, 3)
	TweenService:Create(dashArc, TweenInfo.new(D.Cooldown, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(18, 3) }):Play()
end

local function dodgeTag()
	local _, _, root = parts()
	if not root then
		return
	end
	local b = UI.new("BillboardGui", { Size = UDim2.fromOffset(140, 40), StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0), AlwaysOnTop = true,
		LightInfluence = 0, Adornee = root, Parent = cursorGui })
	local t = UI.text({ Text = "DODGE", Size = UDim2.fromScale(1, 1), TextSize = 26, Weight = Enum.FontWeight.Heavy, Italic = true,
		TextColor3 = T.Gold, Parent = b })
	TweenService:Create(b, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(0.75, function()
		b:Destroy()
	end)
end

-- ===================================================================== every frame
local function approach(cur, target, rate, dt)
	return cur + (target - cur) * math.min(1, dt * rate)
end

local function walkTracks(hum, backwards)
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local n = track.Name
		if n == "WalkAnim" or n == "RunAnim" then
			if backwards and track.Speed > 0 then
				track:AdjustSpeed(-track.Speed)
			elseif not backwards and track.Speed < 0 then
				track:AdjustSpeed(-track.Speed)
			end
		end
	end
end

local function step(dt)
	local char, hum, root = parts()
	lockK = approach(lockK, locked and 1 or 0, M.ShiftLock.Ease, dt)
	if not char then
		return
	end
	hum.CameraOffset = M.ShiftLock.Offset * lockK
	local camera = workspace.CurrentCamera
	local turning = locked and not riding()
	if locked then
		-- after the camera scripts (which reset it every frame)
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	if turning then
		hum.AutoRotate = false
		local look = camera.CFrame.LookVector
		local want = math.atan2(-look.X, -look.Z)
		local _, cur = root.CFrame:ToEulerAnglesYXZ()
		local d = (want - cur + math.pi) % (2 * math.pi) - math.pi
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, cur + d * math.min(1, dt * M.ShiftLock.Turn), 0)
	end
	-- directional walk
	local L = M.Lean
	local move = root.CFrame:VectorToObjectSpace(hum.MoveDirection)
	local forward, side = -move.Z, move.X
	local planar = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local k = math.clamp(planar / math.max(1, Config.WalkSpeed), 0, 1.6)
	local moving = hum.MoveDirection.Magnitude > 0.1 and planar > 1
	local pitch, yaw, roll = 0, 0, 0
	local backwards = false
	if moving then
		pitch = -(math.max(forward, 0) * L.Forward + (sprinting and L.Sprint or 0)) * math.min(k, 1)
		if turning then
			-- hips toward the strafe, chest stays on the camera (Waist counter-turns)
			if forward >= -0.2 then
				yaw = -math.clamp(math.deg(math.atan2(side, math.max(forward, 0))), -L.Hips, L.Hips)
			else
				backwards = true
				yaw = math.clamp(math.deg(math.atan2(side, -forward)), -L.Hips, L.Hips)
				pitch = L.Forward * 0.5 * math.min(k, 1) -- a slight lean back
			end
			roll = -side * L.Side * math.min(k, 1)
		else
			-- facing the move: bank into turns
			roll = math.clamp(root.AssemblyAngularVelocity.Y * 2.2, -L.Side, L.Side)
		end
	end
	lean[1] = approach(lean[1], pitch, L.Ease, dt)
	lean[2] = approach(lean[2], yaw, L.Ease, dt)
	lean[3] = approach(lean[3], roll, L.Ease, dt)
	Rig.hold(char, "Move", { Root = { lean[1], lean[2], lean[3] }, Waist = { 0, -lean[2] * 0.85, 0 } })
	walkTracks(hum, backwards and moving)
end

-- ===================================================================== start
function Movement.Start(c)
	C = c
	RunService:BindToRenderStep("MystreeMovement", Enum.RenderPriority.Camera.Value + 1, step)
	local function bind(name, fn, touch, title, ...)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				fn()
			end
			return Enum.ContextActionResult.Pass
		end, touch, ...)
		if touch then
			ContextActionService:SetTitle(name, title)
		end
	end
	bind("MystreeSprint", function()
		setSprint(not sprinting)
	end, true, "Sprint", Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	bind("MystreeShoulder", function()
		setLock(not locked)
	end, false, nil, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
	bind("MystreeDash", dash, true, "Dash", Enum.KeyCode.Q, Enum.KeyCode.ButtonR1)
	ContextActionService:SetPosition("MystreeSprint", UDim2.new(1, -170, 1, -70))
	ContextActionService:SetPosition("MystreeDash", UDim2.new(1, -230, 1, -130))
	-- riding switches sprint off (mounts set their own speed); a new character starts walking.
	-- Sprint is dropped WITHOUT putting the walk speed back: that local write used to land after the
	-- server's mount speed and stick (the server's value didn't change, so nothing replicated again),
	-- so mounts ran at walking speed. The mount's speed is set here too, at once.
	player:GetAttributeChangedSignal("Riding"):Connect(function()
		if riding() then
			if sprinting then
				sprinting = false
				task.spawn(Net.invoke, "Sprint", false)
			end
			local _, hum = parts()
			local def = Config.Mounts[player:GetAttribute("Mount") or ""]
			if hum and def then
				hum.WalkSpeed = def.Speed
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		lean = { 0, 0, 0 }
		if sprinting then
			sprinting = false
			task.spawn(Net.invoke, "Sprint", false)
		end
	end)
	Net.get("Effect").OnClientEvent:Connect(function(kind)
		if kind == "Dodge" then
			dodgeTag()
		end
	end)
end

return Movement
