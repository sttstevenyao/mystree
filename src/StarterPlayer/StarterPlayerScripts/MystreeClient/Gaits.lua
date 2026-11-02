-- StarterPlayerScripts/MystreeClient/Gaits (ModuleScript)
-- Walk and gallop cycles for jointed creature mobs (Creatures.rig): every frame each mob's speed
-- drives its leg, torso (Hips), neck, head and tail Motor6Ds through Creatures.pose (body bob and
-- roll, idle breathing and glances, tail wag: see Creatures.angles). Deer walk in lateral sequence and break
-- into a gallop when fast. Local only (Motor6D.Transform does not replicate), skipped far away.
-- Attacks: when the server sets "Windup" (with "AttackAnim"), the rig plays that Creatures.attack
-- pose: the wind-up runs until the hit lands, the recovery for Config.MobAI.Recover after.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Creatures = require(ReplicatedStorage.Mystree.Creatures)
local Config = require(ReplicatedStorage.Mystree.Config)

local Gaits = {}

local FAR = 180
local tracked = {} -- model -> { Motors, Phase, Amp, Run, Stride }

local function track(m)
	if not m:GetAttribute("Rig") or tracked[m] then
		return
	end
	local st = { Rig = m:GetAttribute("Rig"), Knuckle = m:GetAttribute("Knuckle"), Motors = Creatures.motors(m), Phase = math.random(), Amp = 0, Run = false, Stride = m:GetAttribute("Stride") or 3,
		Seed = math.random() * 10, Size = m:GetAttribute("RigScale") or 1 }
	tracked[m] = st
	m:GetAttributeChangedSignal("Windup"):Connect(function()
		local lands = m:GetAttribute("Windup")
		local kind = m:GetAttribute("AttackAnim")
		if type(lands) == "number" and Creatures.ATTACK_STRIKE[kind or ""] then
			local now = os.clock()
			st.Swing = { Kind = kind, Start = now, Land = now + math.max(0.05, lands - workspace:GetServerTimeNow()) }
		end
	end)
end

-- where the current attack is in its pose (nil when it's over)
local function attackT(sw, now)
	local strike = Creatures.ATTACK_STRIKE[sw.Kind]
	if now < sw.Land then
		return strike * (now - sw.Start) / (sw.Land - sw.Start)
	end
	local t = strike + (1 - strike) * (now - sw.Land) / Config.MobAI.Recover
	return t < 1 and t or nil
end

-- advance one creature's gait by a frame at `speed` studs/s (mobs here; mounts in Equipment)
function Gaits.step(st, speed, dt)
	-- gallop above ~3.4 strides a second, back to a walk below ~2.8 (no flicker in between); the
	-- legs' footfalls blend between the two over about a third of a second (Blend)
	st.Run = speed > st.Stride * (st.Run and 2.8 or 3.4)
	st.Blend = (st.Blend or 0) + ((st.Run and 1 or 0) - (st.Blend or 0)) * math.min(1, dt * 3)
	st.Phase = (st.Phase + speed * dt / (st.Stride * (1 + st.Blend))) % 1
	local target = math.clamp(speed / (st.Stride * 0.9), 0, 1)
	st.Amp += (target - st.Amp) * math.min(1, dt * 8)
	-- idle life and the tail run on their own clocks; big creatures wag slower
	st.Seed = st.Seed or math.random() * 10
	st.T = (st.T or 0) + dt
	st.TailPhase = (st.TailPhase or 0) + dt * (2.5 + 3 * math.clamp(st.Amp, 0, 1)) / math.max(st.Size or 1, 0.5) ^ 0.75
end

function Gaits.Start()
	local folder = workspace:WaitForChild("Mobs")
	folder.ChildAdded:Connect(function(m)
		task.defer(track, m)
	end)
	folder.ChildRemoved:Connect(function(m)
		tracked[m] = nil
	end)
	for _, m in ipairs(folder:GetChildren()) do
		track(m)
	end
	local camera = workspace.CurrentCamera
	RunService.Stepped:Connect(function(_, dt)
		local eye = camera.CFrame.Position
		for m, st in pairs(tracked) do
			local root = m.PrimaryPart
			if not root or not m.Parent then
				tracked[m] = nil
				continue
			end
			if m:GetAttribute("Dead") or (root.Position - eye).Magnitude > FAR then
				continue
			end
			Gaits.step(st, (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude, dt)
			local t = st.Swing and attackT(st.Swing, os.clock())
			st.Attack = t and { Kind = st.Swing.Kind, T = t } or nil
			if not t then
				st.Swing = nil
			end
			Creatures.pose(st.Motors, st)
		end
	end)
end

return Gaits
