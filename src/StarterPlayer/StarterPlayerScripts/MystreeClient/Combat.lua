-- StarterPlayerScripts/MystreeClient/Combat (ModuleScript)
-- The local player's PvE fighting in the Hunting Grounds, and hit feedback for everyone nearby.
--  * Input (user, 2026-10-26: no ATTACK button): left click or a tap on the world (not over UI), or
--    gamepad R2, anywhere (hits only count in the Hunting Grounds). Holding keeps attacking; a touch that drags (turning the camera) stops attacking.
--    Riding (anywhere): R on keyboard, B on gamepad; touch devices also get a RIDE button.
--  * Combo: the equipped weapon's class picks its moveset (Config.WeaponClasses). The next press
--    within Config.ComboReset continues the combo; otherwise it starts over. Each step has its own
--    keyframed swing (Rig.play), sped up by Attack Speed. The "Swing" intent goes to the server at
--    the moment the blade lands (HitAt); the server decides the hits.
--  * Soft auto-aim turns you to the nearest mob in reach (it matters on phones). Finishers lunge.
--  * Hit feedback (Net "Hit"): a white flash on the target and sparks in the weapon's rarity colour
--    (no floating damage numbers: user, 2026-10-27); your own hits add sound, shake and an FOV
--    punch on crits. HP shows on the mob's bar (MobFx).
--  * Getting hurt: red flash, a red number over your head, a small shake.
--  * Mythforged weapon procs (Effect "WeaponProc", seen by everyone nearby): Heavenfire (golden
--    pillar + rings), Foxfire (pink fox-fire burst), Thunderclap (lightning bolts + a wide ring).

local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)
local Rig = require(script.Parent.Rig)

local Combat = {}

local player = Players.LocalPlayer
local T = UI.T
local C -- controllers (set in Start)

-- ===================================================================== movesets
-- Keyframes per class and combo step. Degrees {X, Y, Z} per joint (axes: see Rig). HitAt is the
-- share of the swing where the blade lands and the Swing intent is sent.
local MOVES = {
	Sword = {
		{ -- 1: slash right to left
			HitAt = 0.48,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.3, Pose = { RightShoulder = { 70, 0, 75 }, RightElbow = { 35, 0, 0 }, Waist = { 0, -35, 0 }, LeftShoulder = { 20, 0, -20 } } },
				{ T = 0.5, Pose = { RightShoulder = { 85, 0, -25 }, RightElbow = { 5, 0, 0 }, Waist = { 0, 28, 0 }, LeftShoulder = { 10, 0, -30 } } },
				{ T = 0.72, Pose = { RightShoulder = { 60, 0, -45 }, RightElbow = { 15, 0, 0 }, Waist = { 0, 32, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
		{ -- 2: slash left to right
			HitAt = 0.48,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.3, Pose = { RightShoulder = { 85, 0, -45 }, RightElbow = { 40, 0, 0 }, Waist = { 0, 30, 0 } } },
				{ T = 0.5, Pose = { RightShoulder = { 75, 0, 70 }, RightElbow = { 5, 0, 0 }, Waist = { 0, -30, 0 }, LeftShoulder = { 15, 0, -25 } } },
				{ T = 0.72, Pose = { RightShoulder = { 50, 0, 80 }, RightElbow = { 15, 0, 0 }, Waist = { 0, -32, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
		{ -- 3: overhead finisher
			HitAt = 0.52,
			Lunge = 2.5,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.35, Pose = { RightShoulder = { 170, 0, 12 }, RightElbow = { 55, 0, 0 }, Waist = { 14, 0, 0 }, LeftShoulder = { 40, 0, -20 } } },
				{ T = 0.52, Pose = { RightShoulder = { 45, 0, 0 }, RightElbow = { 0, 0, 0 }, Waist = { -22, 0, 0 }, RightHip = { 25, 0, 0 }, LeftKnee = { -20, 0, 0 } } },
				{ T = 0.75, Pose = { RightShoulder = { 35, 0, 0 }, Waist = { -16, 0, 0 }, RightHip = { 20, 0, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
	},
	Greatsword = {
		{ -- 1: wide two-handed cleave
			HitAt = 0.52,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.38, Pose = { RightShoulder = { 60, 0, 85 }, LeftShoulder = { 75, 0, 40 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 45, 0, 0 }, Waist = { 0, -55, 0 } } },
				{ T = 0.55, Pose = { RightShoulder = { 75, 0, -55 }, LeftShoulder = { 85, 0, -20 }, RightElbow = { 5, 0, 0 }, LeftElbow = { 20, 0, 0 }, Waist = { 0, 50, 0 } } },
				{ T = 0.78, Pose = { RightShoulder = { 55, 0, -60 }, LeftShoulder = { 60, 0, -30 }, Waist = { 0, 45, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
		{ -- 2: overhead slam with a shockwave
			HitAt = 0.6,
			Lunge = 1.5,
			Slam = true,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.45, Pose = { RightShoulder = { 175, 0, 5 }, LeftShoulder = { 170, 0, -5 }, RightElbow = { 60, 0, 0 }, LeftElbow = { 60, 0, 0 }, Waist = { 22, 0, 0 } } },
				{ T = 0.6, Pose = { RightShoulder = { 30, 0, 0 }, LeftShoulder = { 35, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftElbow = { 5, 0, 0 }, Waist = { -28, 0, 0 }, RightKnee = { -35, 0, 0 }, LeftKnee = { -35, 0, 0 }, RightHip = { 30, 0, 0 }, LeftHip = { 30, 0, 0 } } },
				{ T = 0.82, Pose = { RightShoulder = { 25, 0, 0 }, LeftShoulder = { 30, 0, 0 }, Waist = { -20, 0, 0 }, RightKnee = { -25, 0, 0 }, LeftKnee = { -25, 0, 0 }, RightHip = { 20, 0, 0 }, LeftHip = { 20, 0, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
	},
	Spear = {
		{ -- 1: thrust
			HitAt = 0.5,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.3, Pose = { RightShoulder = { 55, 0, 20 }, RightElbow = { 100, 0, 0 }, LeftShoulder = { 60, 0, -10 }, LeftElbow = { 60, 0, 0 }, Waist = { 0, -25, 0 } } },
				{ T = 0.5, Pose = { RightShoulder = { 90, 0, 5 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 80, 0, -5 }, LeftElbow = { 10, 0, 0 }, Waist = { -8, 18, 0 } } },
				{ T = 0.75, Pose = { RightShoulder = { 80, 0, 10 }, RightElbow = { 20, 0, 0 }, Waist = { 0, 10, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
		{ -- 2: low thrust
			HitAt = 0.5,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.3, Pose = { RightShoulder = { 40, 0, 25 }, RightElbow = { 105, 0, 0 }, LeftShoulder = { 45, 0, -10 }, Waist = { 8, -30, 0 }, RightKnee = { -20, 0, 0 } } },
				{ T = 0.5, Pose = { RightShoulder = { 70, 0, 5 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 70, 0, -5 }, Waist = { -14, 22, 0 }, RightHip = { 25, 0, 0 }, LeftKnee = { -25, 0, 0 } } },
				{ T = 0.75, Pose = { RightShoulder = { 60, 0, 10 }, RightElbow = { 25, 0, 0 }, Waist = { -6, 12, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
		{ -- 3: lunging double thrust (one server hit when the second thrust lands)
			HitAt = 0.68,
			Lunge = 3.5,
			Keys = {
				{ T = 0, Pose = {} },
				{ T = 0.18, Pose = { RightShoulder = { 55, 0, 20 }, RightElbow = { 100, 0, 0 }, Waist = { 0, -25, 0 } } },
				{ T = 0.32, Pose = { RightShoulder = { 92, 0, 5 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 80, 0, -5 }, Waist = { -10, 18, 0 } } },
				{ T = 0.48, Pose = { RightShoulder = { 60, 0, 20 }, RightElbow = { 95, 0, 0 }, Waist = { 0, -22, 0 } } },
				{ T = 0.68, Pose = { RightShoulder = { 95, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 85, 0, 0 }, Waist = { -18, 22, 0 }, RightHip = { 35, 0, 0 }, LeftKnee = { -35, 0, 0 } } },
				{ T = 0.86, Pose = { RightShoulder = { 80, 0, 5 }, Waist = { -10, 12, 0 }, RightHip = { 20, 0, 0 } } },
				{ T = 1, Pose = {} },
			},
		},
	},
}
Combat.Moves = MOVES

-- ===================================================================== state
local combo = { Index = 0, LastEnd = 0, BusyUntil = 0, Buffered = 0 }
local BUFFER = 0.3 -- s a press during a swing is kept and played when the swing ends
local HIT_STOP = 0.07 -- s a finisher or slam that connects holds its pose (66 ms+ so it reads on 30 fps phones)
local holding = false

local function charParts()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return char, hrp, hum
end

local function subStat(name)
	local raw = player:GetAttribute("SubStats")
	if type(raw) ~= "string" then
		return 0
	end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and t[name] or 0
end

local function weaponClass()
	local w = State.equipped("Weapon")
	local class = w and w.Class or "Sword"
	if not Config.WeaponClasses[class] then
		class = "Sword"
	end
	return class
end

local function mobsFolder()
	return workspace:FindFirstChild("Mobs")
end

-- the nearest living mob that is after you (Aggro = your UserId) within range, for auto-aim
local function nearestAggro(pos, range)
	local folder = mobsFolder()
	if not folder then
		return nil
	end
	local best, bestD = nil, range
	for _, m in ipairs(folder:GetChildren()) do
		local root = m.PrimaryPart
		if root and m:GetAttribute("Aggro") == player.UserId and not m:GetAttribute("Dead") then
			local d = ((root.Position - pos) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

-- with PvP on: the nearest other player with PvP on in the Hunting Grounds, within range
local function nearestEnemy(pos, range)
	if not player:GetAttribute("PvP") then
		return nil
	end
	local best, bestD = nil, range
	for _, other in ipairs(Players:GetPlayers()) do
		local hrp = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local hum = hrp and other.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and other:GetAttribute("PvP") and other:GetAttribute("InGrounds") then
			local d = ((hrp.Position - pos) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestD then
				best, bestD = other.Character, d
			end
		end
	end
	return best
end

-- nearest living mob within reach (for auto-aim)
local function nearestMob(pos, reach)
	local folder = mobsFolder()
	if not folder then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in ipairs(folder:GetChildren()) do
		local root = m.PrimaryPart
		if root and not m:GetAttribute("Dead") and (m:GetAttribute("HP") or 0) > 0 then
			local radius = math.max(root.Size.X, root.Size.Z) / 2
			local d = ((root.Position - pos) * Vector3.new(1, 0, 1)).Magnitude - radius
			if d < reach and d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

-- a short forward step on finishers (local only, stops at walls)
local function lunge(hrp, dir, dist)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character, mobsFolder() }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local steps = 6
	local stepLen = dist / steps
	task.spawn(function()
		for _ = 1, steps do
			if not hrp.Parent then
				return
			end
			if workspace:Raycast(hrp.Position, dir * (stepLen + 1.5), params) then
				return
			end
			hrp.CFrame = hrp.CFrame + dir * stepLen
			RunService.Heartbeat:Wait()
		end
	end)
end

-- you can swing anywhere (user, 2026-10-27); hits only land in the Hunting Grounds (the server
-- decides). With the axe out the click belongs to chopping (Chop).
-- turn the character to face dir over t seconds (yaw only; position stays with the physics)
local TURN_TIME = 0.08
local turnGen = 0
local function turnTo(hrp, hum, dir, t)
	if dir.Magnitude < 0.1 then
		return
	end
	turnGen += 1
	local gen = turnGen
	local _, from = hrp.CFrame:ToEulerAnglesYXZ()
	local to = math.atan2(-dir.X, -dir.Z)
	local d = (to - from + math.pi) % (2 * math.pi) - math.pi
	local auto = hum.AutoRotate
	hum.AutoRotate = false
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.min(1, (os.clock() - t0) / t)
		local e = 1 - (1 - a) * (1 - a)
		if gen ~= turnGen or not hrp.Parent then
			conn:Disconnect()
			return
		end
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, from + d * e, 0)
		if a >= 1 then
			conn:Disconnect()
			hum.AutoRotate = auto
		end
	end)
end

local function trySwing(pressed)
	if C and C.Equipment and C.Equipment.held() == "Axe" then
		return
	end
	if C and C.Island and C.Island.isEditing and C.Island.isEditing() then
		return
	end
	local char, hrp, hum = charParts()
	if not (char and hrp and hum) or hum.Health <= 0 then
		return
	end
	if player:GetAttribute("Riding") then
		task.spawn(Net.invoke, "Ride", false)
		return
	end
	local now = os.clock()
	if now < combo.BusyUntil then
		if pressed then
			combo.Buffered = now
		end
		return
	end
	combo.Buffered = 0
	-- attacking draws the weapon first (Equipment plays the draw); the swing follows
	if C and C.Equipment and C.Equipment.held() ~= "Weapon" then
		C.Equipment.setHeld("Weapon")
		combo.BusyUntil = now + 0.45
		return
	end
	local class = weaponClass()
	local list = Config.WeaponClasses[class].Combo
	local moves = MOVES[class]
	local index = 1
	if now - combo.LastEnd <= Config.ComboReset and combo.Index < #list then
		index = combo.Index + 1
	end
	local move, anim = list[index], moves[index] or moves[1]
	local duration = move.Time / (1 + subStat("AttackSpeed"))
	combo.Index = index
	combo.BusyUntil = now + duration * 0.92
	combo.LastEnd = now + duration
	-- auto-aim on the click (user: you turn to the mob when you attack, not when it aggroes): the
	-- nearest mob that is after you, else the nearest mob in reach
	local target = nearestAggro(hrp.Position, move.Range + 18) or nearestMob(hrp.Position, move.Range + 4) or nearestEnemy(hrp.Position, move.Range + 6)
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	if target and target.PrimaryPart then
		-- a very fast turn toward the target, not a snap (user); the swing aims at it from the start
		local tp = target.PrimaryPart.Position
		look = (tp - hrp.Position) * Vector3.new(1, 0, 1)
		turnTo(hrp, hum, look, TURN_TIME)
	end
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	if C and C.Equipment then
		C.Equipment.setTrail(player, true)
		task.delay(duration, function()
			C.Equipment.setTrail(player, false)
		end)
	end
	task.delay(duration * anim.HitAt * 0.65, function()
		Sounds.play("Swing", 0.9 + math.random() * 0.25 + (class == "Greatsword" and -0.2 or 0), class == "Greatsword" and 1.2 or 1)
	end)
	if anim.Lunge then
		task.delay(duration * anim.HitAt * 0.8, function()
			lunge(hrp, look, anim.Lunge)
		end)
	end
	local swing
	swing = Rig.play(char, anim.Keys, duration, {
		HitAt = anim.HitAt,
		OnHit = function()
			-- hit-stop on finishers and slams that will land (felt at once, not after the server answers)
			if (index == #list or anim.Slam) and nearestMob(hrp.Position, move.Range + 2) and not GuiService.ReducedMotionEnabled then
				swing.Freeze(HIT_STOP)
				combo.BusyUntil += HIT_STOP
				combo.LastEnd += HIT_STOP
			end
			Net.invoke("Swing", index, look)
			if anim.Slam then
				local ground = hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight - 0.1, 0)
				Fx.ring(ground + look * 5, Color3.fromRGB(255, 236, 200), 26, 0.5)
				Fx.burst(ground + look * 5, { Texture = "Smoke", Color = Color3.fromRGB(190, 170, 140), Count = 14, Speed = { 8, 16 }, Size = 2.4, EndSize = 1.5, Lifetime = { 0.5, 0.9 }, Alpha = 0.3, Gravity = Vector3.new(0, 4, 0), Spread = 80 })
				Fx.shake(2.2, 0.35)
				Sounds.play("Quake", 1.3, 0.6)
			end
		end,
	})
end

-- ===================================================================== buttons (Grounds only)
local gui, root
local rideBtn
local RIDE_KEYS = { Enum.KeyCode.R, Enum.KeyCode.ButtonB }
local TAP_DRAG = 14 -- pixels a touch may move before it counts as turning the camera

local function roundButton(name, size, pos, top, bottom, line, text, textSize)
	local b = UI.new("TextButton", {
		Name = name, Text = text, AutoButtonColor = false, Size = UDim2.fromOffset(size, size), Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.White, FontFace = UI.Heavy, TextSize = textSize,
		TextColor3 = T.White, Parent = root,
	})
	UI.corner(999, b)
	UI.gradient(b, top, bottom)
	UI.stroke(b, line, 3)
	UI.textLayer(b, line, 2)
	UI.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), Parent = b },
		{ UI.corner(999), UI.new("UIStroke", { Color = Color3.fromRGB(255, 244, 200), Thickness = 2, Transparency = 0.25 }) })
	UI.bounce(b)
	return b
end

local function toggleRide()
	if (player:GetAttribute("Mount") or "") == "" then
		if C and C.Notify then
			C.Notify.toast("Equip a mount at the Stable first.", "Info")
		end
		return
	end
	local ok, msg = Net.invoke("Ride", not player:GetAttribute("Riding"))
	if not ok and msg and C and C.Notify then
		C.Notify.toast(msg, "Error")
	end
end

local function buildButtons()
	gui, root = UI.screen("MystreeCombat", 6)
	-- touch only: a RIDE button bottom-right, above the jump button (keyboard and gamepad use a key)
	rideBtn = roundButton("Ride", 78, UDim2.new(1, -110, 1, -230), T.Teal, T.TealDark, T.TealLine, "RIDE", 18)
	rideBtn.Activated:Connect(function()
		Sounds.play("Click")
		toggleRide()
	end)
	local function updateRide()
		rideBtn.Text = player:GetAttribute("Riding") and "WALK" or "RIDE"
		rideBtn.Visible = UserInputService.TouchEnabled and (player:GetAttribute("Mount") or "") ~= ""
	end
	player:GetAttributeChangedSignal("Riding"):Connect(updateRide)
	player:GetAttributeChangedSignal("Mount"):Connect(updateRide)
	updateRide()
	local hinted = false
	-- mounts ride anywhere now, so the RIDE button shows everywhere (touch, with a mount)
	local function updateVisible()
		local on = true
		gui.Enabled = on
		-- keyboard players have no RIDE button: say which key it is, once per session
		if on and not hinted and not UserInputService.TouchEnabled and (player:GetAttribute("Mount") or "") ~= "" and C and C.Notify then
			hinted = true
			C.Notify.toast(UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and "Press B to ride your mount." or "Press R to ride your mount.", "Info")
		end
	end
	player:GetAttributeChangedSignal("InGrounds"):Connect(updateVisible)
	updateVisible()
end

-- ===================================================================== hit feedback
local function rarityOf(by)
	local look = by and by:GetAttribute("WeaponLook") or ""
	return tonumber(string.match(look, ":(%d+)$")) or 1
end

local function flashTarget(model)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.25
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	task.delay(0.08, function()
		h:Destroy()
	end)
end

local function onHit(info)
	local model = info and info.Target
	local root = model and model.PrimaryPart
	if not root then
		return
	end
	local mine = info.By == player
	if mine and C and C.MobFx then
		C.MobFx.noteHit(model)
	end
	if info.Crit and not info.Companion then
		Fx.burst(root.Position, { Texture = "Square", Color = T.Gold, Color2 = Color3.new(1, 1, 1), Count = 10, Speed = { 12, 24 }, Size = 0.5, Light = 1, Lifetime = { 0.3, 0.6 }, Spread = 180, Rotation = 400 })
	end
	if not info.Companion then
		flashTarget(model)
		local c = Config.Rarities[math.clamp(rarityOf(info.By), 1, #Config.Rarities)].Color
		Fx.burst(root.Position, { Texture = "Sparks", Color = c:Lerp(Color3.new(1, 1, 1), 0.4), Color2 = c, Count = info.Crit and 14 or 8, Speed = { 14, 26 }, Size = 0.6, Light = 1, Lifetime = { 0.15, 0.35 }, Spread = 70, Gravity = Vector3.new(0, -20, 0) })
	end
	if mine and not info.Companion then
		if info.Crit then
			Sounds.play("Crit", 0.95 + math.random() * 0.15)
			Fx.shake(1.4, 0.22)
			Fx.punch(1.5)
		else
			Sounds.play("Hit", 1.15 + math.random() * 0.25)
			Fx.shake(0.6, 0.14)
		end
	end
end

local function onHurt(dmg)
	local char, hrp = charParts()
	Sounds.play("MobHit", 0.9 + math.random() * 0.2)
	Fx.flash(Color3.fromRGB(200, 20, 20), 0.75, 0.35)
	Fx.shake(0.9, 0.2)
	if hrp then
		Fx.float(hrp.Position + Vector3.new(0, 3.5, 0), "-" .. Format.Num(dmg or 0), { Color = Color3.fromRGB(255, 80, 70), Size = 26, Rise = 3 })
	end
end

-- ===================================================================== Mythforged weapon procs
local function procGround(pos)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Mobs"), Fx.Holder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

-- a short-lived neon part that fades out
local function glowPart(props, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = Fx.Holder
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.1)
	return p
end

local PROCS = {}

-- Heavenfire: a golden pillar falls on the target, two rings and rising embers
function PROCS.QilinVerdict(ground, radius, color)
	local pillar = glowPart({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.1, Size = Vector3.new(70, radius * 0.5, radius * 0.5),
		CFrame = CFrame.new(ground + Vector3.new(0, 35, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, 0.55)
	TweenService:Create(pillar, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Size = Vector3.new(70, radius * 0.12, radius * 0.12) }):Play()
	glowPart({ Shape = Enum.PartType.Cylinder, Color = Color3.new(1, 1, 1), Transparency = 0.3, Size = Vector3.new(70, radius * 0.22, radius * 0.22),
		CFrame = CFrame.new(ground + Vector3.new(0, 35, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, 0.35)
	Fx.ring(ground, color, radius * 2, 0.5)
	task.delay(0.1, Fx.ring, ground, Color3.fromRGB(255, 250, 230), radius * 1.3, 0.4)
	Fx.burst(ground + Vector3.new(0, 1, 0), { Texture = "Fire", Color = color, Color2 = Color3.fromRGB(255, 140, 40), Count = 26, Speed = { 8, 20 }, Size = 2.2, EndSize = 0.3,
		Light = 1, Lifetime = { 0.5, 0.9 }, Gravity = Vector3.new(0, 20, 0), Spread = 35, Dir = Vector3.new(0, 1, 0) })
	Sounds.at("Crit", ground, 0.7, 1)
	Fx.shake(0.7, 0.25)
end

-- Foxfire: pink flames burst out in a ring and curl upward
function PROCS.FoxfireFang(ground, radius, color)
	Fx.burst(ground + Vector3.new(0, 1.5, 0), { Texture = "Fire", Color = color, Color2 = Color3.fromRGB(180, 90, 255), Count = 34, Speed = { 10, radius * 2.4 }, Size = 2,
		EndSize = 0.2, Light = 1, Lifetime = { 0.4, 0.8 }, Gravity = Vector3.new(0, 14, 0), Spread = 180, Drag = 4 })
	Fx.burst(ground + Vector3.new(0, 2, 0), { Texture = "Glow", Color = Color3.fromRGB(255, 220, 240), Count = 14, Speed = { 4, 10 }, Size = 0.9, Light = 1,
		Lifetime = { 0.6, 1 }, Gravity = Vector3.new(0, 10, 0), Spread = 60, Dir = Vector3.new(0, 1, 0) })
	Fx.ring(ground, color, radius * 2, 0.4)
	Sounds.at("Whoosh", ground, 1.3, 0.9)
end

-- Thunderclap: a few jagged bolts from the sky into the ring, a white blink and a wide shockwave
local function bolt(from, to, color)
	local points = { from }
	local steps = 6
	for i = 1, steps - 1 do
		local p = from:Lerp(to, i / steps)
		table.insert(points, p + Vector3.new(math.random(-20, 20) / 10, 0, math.random(-20, 20) / 10))
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		glowPart({ Color = color, Transparency = 0, Size = Vector3.new(0.35, 0.35, len), CFrame = CFrame.lookAt((a + b) / 2, b) }, 0.3)
	end
end

function PROCS.Stormtalon(ground, radius, color)
	for k = 1, 4 do
		local ang = math.random() * math.pi * 2
		local d = (k == 1) and 0 or math.random() * radius
		local to = ground + Vector3.new(math.cos(ang) * d, 0.2, math.sin(ang) * d)
		task.delay((k - 1) * 0.05, bolt, to + Vector3.new(math.random(-6, 6), 45, math.random(-6, 6)), to, k == 1 and Color3.fromRGB(235, 245, 255) or color)
	end
	Fx.ring(ground, color, radius * 2, 0.45)
	Fx.burst(ground + Vector3.new(0, 1, 0), { Texture = "Sparks", Color = color, Color2 = Color3.new(1, 1, 1), Count = 24, Speed = { 14, 30 }, Size = 0.5,
		Light = 1, Lifetime = { 0.2, 0.45 }, Spread = 180, Gravity = Vector3.new(0, -30, 0) })
	Fx.flash(Color3.fromRGB(220, 235, 255), 0.85, 0.15)
	Sounds.at("Thunder", ground, 1.2, 0.8)
	Fx.shake(0.8, 0.25)
end

local function onProc(info)
	if type(info) ~= "table" or typeof(info.Pos) ~= "Vector3" then
		return
	end
	local def = Config.Forge.Myth[info.Myth or ""]
	local fx = PROCS[info.Myth or ""]
	if not (def and fx) then
		return
	end
	local color = typeof(info.Color) == "Color3" and info.Color or def.Effect.Color
	fx(procGround(info.Pos), info.Radius or def.Effect.Radius, color)
end

-- ===================================================================== start
function Combat.Start(controllers)
	C = controllers
	buildButtons()
	local touchStart -- the attacking touch and where it started
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding = true
			trySwing(true)
		elseif t == Enum.UserInputType.Touch then
			-- a tap on the world attacks (the thumbstick and buttons come in as processed)
			touchStart = { Input = input, Pos = input.Position }
			holding = true
			trySwing(true)
		elseif table.find(RIDE_KEYS, input.KeyCode) and not (C and C.Island and C.Island.isPlacing and C.Island.isPlacing()) then
			toggleRide() -- (R also turns decor while placing it)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if touchStart and input == touchStart.Input and (input.Position - touchStart.Pos).Magnitude > TAP_DRAG then
			-- dragging to turn the camera: stop attacking
			holding = false
			touchStart = nil
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
			or (touchStart and input == touchStart.Input) then
			holding = false
			touchStart = nil
		end
	end)
	-- hold to keep attacking
	RunService.Heartbeat:Connect(function()
		-- held, or pressed during the last swing (buffered on the press, used once)
		if holding or os.clock() - combo.Buffered <= BUFFER then
			trySwing()
		end
	end)
	player.CharacterAdded:Connect(function()
		holding = false
		combo.Index, combo.BusyUntil, combo.LastEnd, combo.Buffered = 0, 0, 0, 0
	end)
	Net.get("Hit").OnClientEvent:Connect(onHit)
	Net.get("Effect").OnClientEvent:Connect(function(kind, a)
		if kind == "Hurt" then
			onHurt(a)
		elseif kind == "WeaponProc" then
			onProc(a)
		end
	end)
end

return Combat
