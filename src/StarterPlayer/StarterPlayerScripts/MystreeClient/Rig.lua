-- StarterPlayerScripts/MystreeClient/Rig (ModuleScript)
-- Procedural poses on R15 characters, layered on top of the Animator (chop swings, weapon combos,
-- riding). Works on Motor6D and AnimationConstraint joints (Avatar Joint Upgrade) through .Transform.
-- Angles are degrees {X, Y, Z} per joint in the joint's frame. Measured R15 axes (Playbook 06):
--   Shoulder +X swings the arm forward/up, RightShoulder +Z lifts it out to the side (Left: -Z),
--   Elbow +X bends, Knee -X bends, Waist +X leans back, Root Y turns the hips.
-- Rig.play(character, keys, duration) runs a keyframed move: keys = { {T = 0..1, Pose = {Joint = {x,y,z}}} }
-- Rig.hold(character, name, pose) keeps a named pose on (riding, carrying); Rig.hold(character, name, nil) clears it.
-- When real animations arrive (art pass) these calls become AnimationTracks; callers don't change.

local RunService = game:GetService("RunService")

local Rig = {}

local JOINTS = {
	"Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist",
	"RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle",
}

local chars = {} -- character -> { Joints = {name = joint}, Moves = {...}, Holds = {name = pose}, Last = {joint = cf}, Base = {joint = cf} }

local function jointsOf(char)
	local found = {}
	for _, d in ipairs(char:GetDescendants()) do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and table.find(JOINTS, d.Name) and not found[d.Name] then
			found[d.Name] = d
		end
	end
	return found
end

local function entry(char)
	local e = chars[char]
	if not e then
		e = { Joints = jointsOf(char), Moves = {}, Holds = {}, Still = {}, Last = {}, Base = {} }
		chars[char] = e
		char.Destroying:Once(function()
			chars[char] = nil
		end)
		char.DescendantAdded:Connect(function(d)
			if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
				e.Joints = jointsOf(char)
			end
		end)
	end
	return e
end

local function ease(t)
	return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2
end

-- Interpolate a keyframe list at time t (0..1). Missing joints in a key count as {0,0,0}.
local function sample(keys, t)
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].T and t <= keys[i + 1].T then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = math.max(1e-4, b.T - a.T)
	local k = ease(math.clamp((t - a.T) / span, 0, 1))
	local out = {}
	local names = {}
	for n in pairs(a.Pose) do
		names[n] = true
	end
	for n in pairs(b.Pose) do
		names[n] = true
	end
	for n in pairs(names) do
		local pa = a.Pose[n] or { 0, 0, 0 }
		local pb = b.Pose[n] or { 0, 0, 0 }
		out[n] = { pa[1] + (pb[1] - pa[1]) * k, pa[2] + (pb[2] - pa[2]) * k, pa[3] + (pb[3] - pa[3]) * k }
	end
	return out
end

-- Returns the move handle; handle.Stop() ends it early. onHit(t) fires once at keys' Hit time.
function Rig.play(char, keys, duration, opts)
	opts = opts or {}
	local e = entry(char)
	local move = { Keys = keys, Start = os.clock(), Duration = duration, HitAt = opts.HitAt, OnHit = opts.OnHit, Weight = opts.Weight or 1 }
	-- one move per channel (a new swing replaces the old one)
	local channel = opts.Channel or "Main"
	e.Moves[channel] = move
	function move.Stop()
		if e.Moves[channel] == move then
			e.Moves[channel] = nil
		end
	end
	-- hit-stop: hold the current pose for `t` seconds, then carry on
	function move.Freeze(t)
		local now = os.clock()
		move.Held = now - move.Start
		move.HeldUntil = now + t
		move.Start += t
	end
	return move
end

-- `still` (optional): joint names the hold takes off the Animator while it lasts, so the walk cycle
-- doesn't play under the pose (riding: the legs sit still while the Animator thinks you walk)
function Rig.hold(char, name, pose, still)
	local e = entry(char)
	e.Holds[name] = pose
	e.Still[name] = pose and still or nil
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	for char, e in pairs(chars) do
		if not char.Parent then
			chars[char] = nil
			continue
		end
		local total = {}
		local function add(pose, w)
			for n, v in pairs(pose) do
				local t = total[n]
				if not t then
					t = { 0, 0, 0 }
					total[n] = t
				end
				t[1] += v[1] * w
				t[2] += v[2] * w
				t[3] += v[3] * w
			end
		end
		for _, pose in pairs(e.Holds) do
			add(pose, 1)
		end
		local still = {}
		for _, list in pairs(e.Still) do
			for _, n in ipairs(list) do
				still[n] = true
			end
		end
		for channel, m in pairs(e.Moves) do
			local t = (m.HeldUntil and now < m.HeldUntil and m.Held or now - m.Start) / m.Duration
			if t >= 1 then
				e.Moves[channel] = nil
			else
				if m.HitAt and not m.HitDone and t >= m.HitAt then
					m.HitDone = true
					if m.OnHit then
						task.spawn(m.OnHit)
					end
				end
				add(sample(m.Keys, t), m.Weight)
			end
		end
		for name, joint in pairs(e.Joints) do
			if joint.Parent then
				-- the Animator rewrites Transform each frame it plays; if it didn't, undo our last offset
				local cur = joint.Transform
				local base = (e.Last[joint] and cur == e.Last[joint]) and e.Base[joint] or cur
				local v = total[name]
				local from = still[name] and CFrame.identity or base
				local result = v and from * CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3])) or from
				e.Base[joint] = base
				e.Last[joint] = result
				if result ~= cur then
					joint.Transform = result
				end
			end
		end
	end
end)

-- ===================================================================== shared moves
-- Two-handed overhead chop (axe), ~0.45 s. The hit lands at 55%.
Rig.Chop = {
	{ T = 0, Pose = {} },
	{ T = 0.38, Pose = { RightShoulder = { 160, 0, 10 }, LeftShoulder = { 150, 0, -10 }, RightElbow = { 40, 0, 0 }, LeftElbow = { 40, 0, 0 }, Waist = { 14, -20, 0 } } },
	{ T = 0.55, Pose = { RightShoulder = { 40, 0, 4 }, LeftShoulder = { 46, 0, -4 }, RightElbow = { 6, 0, 0 }, LeftElbow = { 6, 0, 0 }, Waist = { -16, 18, 0 } } },
	{ T = 0.75, Pose = { RightShoulder = { 30, 0, 4 }, LeftShoulder = { 34, 0, -4 }, Waist = { -10, 12, 0 } } },
	{ T = 1, Pose = {} },
}

-- Riding: seated astride, thighs forward and out around the mount's back, knees bent down. The
-- whole body is taken off the Animator (RideStill) so the walk cycle can't play while riding;
-- the arms hang at rest, so weapon swings and the draw move still play on top.
Rig.Ride = { RightHip = { 72, 0, 24 }, LeftHip = { 72, 0, -24 }, RightKnee = { -78, 0, 0 }, LeftKnee = { -78, 0, 0 }, RightAnkle = { 20, 0, 0 }, LeftAnkle = { 20, 0, 0 }, Waist = { -6, 0, 0 } }
Rig.RideStill = { "Root", "Waist", "RightHip", "LeftHip", "RightKnee", "LeftKnee", "RightAnkle", "LeftAnkle", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist" }

return Rig
