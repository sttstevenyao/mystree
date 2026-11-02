-- ReplicatedStorage/Mystree/CreatureRecipes2 (ModuleScript)
-- The rest of the bestiary, in the Qilin's style (blueprints: "Mystree Creature Recipe Blueprints").
-- Creatures requires this and passes itself in. Part budgets, since camps spawn in numbers: pack mobs
-- about 500, elites and rares about 1,300, bosses up to 2,500.
--  * Beast family (rig Quad): Feline, Bear, Shelled, Sprawler, SmallBeast share `beast`.
--  * Biped family (rig Biped): Ape, Warrior, Golem share `skeleton` + the Biped pose driver.
--  * Floaters (rig Hover): Wraith, Wisp.

return function(Creatures)
	local kit = Creatures.kit
	local recipes, Looks = Creatures.recipes, Creatures.Looks
	local hull, cap, ring, eye, tuft, T = Creatures.hull, Creatures.cap, Creatures.ring, Creatures.eye, Creatures.tuft, Creatures.tri
	local rnd, scale, scaleStrip, chain, auraNode, newPart, strand = kit.rnd, kit.scale, kit.scaleStrip, kit.chain, kit.auraNode, kit.newPart, kit.strand
	local BOX = kit.BOX
	local X, Y, V, rgb = Vector3.xAxis, Vector3.yAxis, Vector3.new, Color3.fromRGB
	local NEON = Enum.Material.Neon

	-- ================================================================= shared shapes
	-- a tapering limb from a to b: open at a (it starts inside what it hangs on), capped at b
	local function limb(sm, a, b, ra, rb, col, name, sides, mat)
		local d = (b - a).Unit
		local side = d:Cross(math.abs(d.Y) < 0.95 and Y or X).Unit
		local u = side:Cross(d).Unit
		local paint = function()
			return name, col, mat
		end
		local B = ring(b, side, u, rb, rb, rb, sides or 4)
		hull(sm, { ring(a, side, u, ra, ra, ra, sides or 4), B }, paint, 0.06)
		cap(sm, B, b + d * rb * 0.6, paint, 0.06)
	end

	-- a closed solid through sections { pos, half width, top, bottom }; paint(c, n) -> name, colour, material
	local function loft(m, list, paint, sides)
		local rings = {}
		for i, r in ipairs(list) do
			local d = (list[math.min(i + 1, #list)][1] - list[math.max(i - 1, 1)][1]).Unit
			table.insert(rings, ring(r[1], X, d:Cross(X).Unit, r[2], r[3], r[4], sides or 6, BOX))
		end
		hull(m, rings, paint)
		local d0 = (list[1][1] - list[2][1]).Unit
		local dn = (list[#list][1] - list[#list - 1][1]).Unit
		cap(m, rings[1], list[1][1] + d0 * math.min(list[1][2], list[1][3]) * 0.5, paint)
		cap(m, rings[#rings], list[#list][1] + dn * math.min(list[#list][2], list[#list][3]) * 0.5, paint)
		return rings
	end

	-- a point and outward normal on facet k of the quad strip A-B, exactly on the hull's two triangles
	local function surf(A, B, k, u, g, mid)
		local k2 = k % #A + 1
		local p, n
		if u >= g then
			p = A[k] + (A[k2] - A[k]) * (u - g) + (B[k2] - A[k]) * g
			n = (A[k2] - A[k]):Cross(B[k2] - A[k])
		else
			p = A[k] + (B[k2] - A[k]) * u + (B[k] - A[k]) * (g - u)
			n = (B[k2] - A[k]):Cross(B[k] - A[k])
		end
		n = n.Unit
		if n:Dot(p - mid) < 0 then
			n = -n
		end
		return p, n
	end
	local function midOf(A, B)
		local c = Vector3.zero
		for j = 1, #A do
			c += A[j] + B[j]
		end
		return c / (2 * #A)
	end

	-- dark stripes round a body: bars across the given facets of every strip, count per strip
	local function stripes(m, name, rings, facets, count, col, width)
		for i = 1, #rings - 1 do
			local A, B = rings[i], rings[i + 1]
			local mid = midOf(A, B)
			for s = 1, count do
				local g = (s - 0.5) / count
				for _, k in ipairs(facets) do
					local g0, g1 = g - width, g + width * 0.6
					local a, n = surf(A, B, k, 0.02, g0, mid)
					local b = surf(A, B, k, 0.98, g0, mid)
					local c = surf(A, B, k, 0.98, g1, mid)
					local d = surf(A, B, k, 0.02, g1, mid)
					local off = n * 0.035
					T(m, name, col, a + off, b + off, c + off, 0.03)
					T(m, name, col, a + off, c + off, d + off, 0.03)
				end
			end
		end
	end

	-- scattered spots (rosettes) on the same facets
	local function spots(m, name, rings, facets, perStrip, col, seed)
		local n0 = 0
		for i = 1, #rings - 1 do
			local A, B = rings[i], rings[i + 1]
			local mid = midOf(A, B)
			for s = 1, perStrip do
				for _, k in ipairs(facets) do
					n0 += 1
					local p, n = surf(A, B, k, 0.15 + rnd(n0, seed) * 0.7, 0.1 + (s - 1 + rnd(n0, seed + 1)) / perStrip * 0.8, mid)
					local tip = (B[1] - A[1]).Unit
					scale(m, name, col, p, (tip - n * tip:Dot(n)).Unit, n, 0.1, 0.24, 0.02 + (n0 % 7) * 0.0045)
				end
			end
		end
	end

	-- a leg for the Quad rig: Model LegFront / LegBack (attribute Side) with Seg1..4 and Joint attachments
	local function qleg(m, name, sx, J, foot, rad, cols, onFoot)
		local lm = Instance.new("Model")
		lm.Name = name
		lm:SetAttribute("Side", sx)
		for i = 1, 4 do
			local sm = Instance.new("Model")
			sm.Name = "Seg" .. i
			local a, b = J[i], J[i + 1] or foot
			limb(sm, a + (a - b).Unit * rad[i] * 0.5, b, rad[i], rad[i + 1], cols[i], "Leg", 4)
			if i == 4 and onFoot then
				onFoot(sm)
			end
			local att = Instance.new("Attachment")
			att.Name = "Joint"
			att.Parent = sm:FindFirstChildWhichIsA("BasePart")
			att.WorldCFrame = CFrame.new(a)
			sm.Parent = lm
		end
		lm.Parent = m
	end

	-- a broad flat paw with claws, standing on the ground at foot
	local function paw(sm, foot, w, l, h, col, clawCol, nClaws)
		newPart("Part", sm, CFrame.new(foot + V(0, h / 2, -l * 0.18)), V(w, h, l), col, "Paw")
		local front = foot.Z - l * 0.68
		for i = 1, nClaws or 3 do
			local x = foot.X + ((i - ((nClaws or 3) + 1) / 2) / (nClaws or 3)) * w * 0.9
			T(sm, "Claw", clawCol, V(x - 0.06, foot.Y + h * 0.45, front + 0.03), V(x + 0.06, foot.Y + h * 0.45, front + 0.03), V(x, foot.Y + 0.02, front - 0.2), 0.05)
		end
	end

	-- ================================================================= the beast family
	-- spec: Torso { {z, y, hw, top, bot} }, Neck { {pos, hw, top, bot} }, Poll, Nose, Head { {t, hw, top, bot} },
	-- Muzzle (t where the muzzle colour starts), Ear ("Round" | "Tall" | "Long" | false), EarSize, Tail { pts, radii, sides },
	-- Front(sx) / Back(sx) -> joints, foot; LegR { 5 radii } per leg, PawW, PawL, Root { centre, size }, Length, Stride
	local function beast(m, o, s)
		local coat = o.Coat or rgb(150, 140, 130)
		local back = o.Back or coat
		local belly = o.Belly or coat
		local face = o.Face or coat
		local muzzle = o.Muzzle or belly
		local pawCol = o.Paw or coat
		local claw = o.Claw or rgb(36, 32, 34)
		local nose = o.Nose or rgb(32, 28, 30)
		local legTop, legLow = o.LegTop or coat, o.Leg or coat
		local rings = {}
		for _, r in ipairs(s.Torso) do
			table.insert(rings, ring(V(0, r[2], r[1]), X, Y, r[3], r[4], r[5], 6, BOX))
		end
		local function torsoPaint(c, n)
			if o.Pattern == "Panda" and c.Z < -0.3 and c.Z > -1.5 then
				return "Body", o.PatternColor -- the panda's dark shoulder band
			end
			if n.Y < -0.5 then
				return "Body", belly
			end
			if n.Y > 0.72 then
				return "Body", back
			end
			return "Body", coat
		end
		hull(m, rings, torsoPaint)
		local tz = s.Torso
		cap(m, rings[1], V(0, tz[1][2], tz[1][1] - tz[1][3] * 0.6), torsoPaint)
		cap(m, rings[#rings], V(0, tz[#tz][2], tz[#tz][1] + tz[#tz][3] * 0.6), torsoPaint)
		local band = { table.unpack(rings, 2, #rings - 1) }
		if o.Pattern == "Stripes" then
			stripes(m, "Body", band, { 1, 2, 5, 6 }, o.StripeCount or 3, o.PatternColor, 0.09)
		elseif o.Pattern == "Rosettes" then
			spots(m, "Body", band, { 1, 2, 5, 6 }, o.SpotCount or 2, o.PatternColor, 21)
		end
		if o.Scutes then
			-- raised armour plates along the back
			local pick = function(i)
				return o.Scutes[math.floor(rnd(i, 3) * #o.Scutes) + 1]
			end
			for _, k in ipairs(o.ScuteFacets or { 1, 6 }) do
				scaleStrip(m, "Body", band, k, 0, 1, o.ScuteAcross or 1, o.ScuteLen or 0.7, 1, pick)
			end
		end
		if o.ShellRim then
			-- a Neon seam round the shell's widest line
			local A, B = band[2], band[3]
			local mid = midOf(A, B)
			for _, k in ipairs({ 2, 5 }) do
				for g = 0, 2 do
					local p0, n = surf(A, B, k, 0.92, g / 3 + 0.02, mid)
					local p1 = surf(A, B, k, 0.92, (g + 1) / 3 - 0.02, mid)
					local up = Y * 0.05
					T(m, "Body", o.ShellRim, p0 + n * 0.05 + up, p1 + n * 0.05 + up, p1 + n * 0.05 - up, 0.03, NEON)
					T(m, "Body", o.ShellRim, p0 + n * 0.05 + up, p1 + n * 0.05 - up, p0 + n * 0.05 - up, 0.03, NEON)
				end
			end
		end

		-- neck and head
		local neckPaint = function()
			return "Neck", o.NeckColor or coat
		end
		local neckRings = loft(m, s.Neck, neckPaint)
		local poll, noseP = s.Poll, s.Nose
		local D = (noseP - poll).Unit
		local U = X:Cross(D).Unit
		local hl = (noseP - poll).Magnitude
		local hr = {}
		for _, r in ipairs(s.Head) do
			table.insert(hr, ring(poll + D * hl * r[1], X, U, r[2], r[3], r[4], 6, BOX))
		end
		local function headPaint(c, n)
			local t = (c - poll):Dot(D) / hl
			if t > 0.93 then
				return "Nose", nose
			end
			if o.Pattern == "Panda" and n:Dot(U) < 0.5 and t < 0.1 then
				return "Head", face
			end
			if t > (s.Muzzle or 0.6) then
				return "Head", muzzle
			end
			return "Head", face
		end
		hull(m, hr, headPaint)
		cap(m, hr[1], poll - D * s.Head[1][2] * 0.6, headPaint)
		cap(m, hr[#hr], noseP + D * 0.05, headPaint)
		local rEye = s.Head[2]
		for _, sx in ipairs({ -1, 1 }) do
			local c = poll + D * hl * (s.EyeT or 0.3) + U * rEye[3] * 0.32 + X * sx * rEye[2] * 0.87
			eye(m, o.Pattern == "Panda" and c + X * sx * 0.07 or c, (X * sx + U * 0.15).Unit, U * 0.08, D * 0.11, o.EyeGlow or rgb(24, 22, 26), o.EyeGlow ~= nil)
			if o.Pattern == "Panda" then
				-- black teardrop round the eye
				local pc = c + X * sx * 0.03
				T(m, "Head", o.PatternColor, pc + U * 0.16 - D * 0.04, pc + D * 0.2 - U * 0.02, pc - U * 0.14 - D * 0.1, 0.05)
				T(m, "Head", o.PatternColor, pc + U * 0.16 - D * 0.04, pc - U * 0.14 - D * 0.1, pc - D * 0.2, 0.05)
			end
			if s.Ear then
				local e = s.EarSize or 0.4
				local root = poll + D * hl * 0.12 + U * s.Head[2][3] * 0.82 + X * sx * s.Head[2][2] * 0.5
				local dir = (X * sx * (s.Ear == "Round" and 0.55 or 0.3) + U * 0.95 - D * 0.1).Unit
				local side = (D + X * sx * 0.3).Unit
				local earCol = o.EarColor or back
				if s.Ear == "Round" then
					local mid = root + dir * e * 0.6
					T(m, "Ear", earCol, root + side * e * 0.45, root - side * e * 0.45, mid + side * e * 0.5, 0.08)
					T(m, "Ear", earCol, root - side * e * 0.45, mid - side * e * 0.5, mid + side * e * 0.5, 0.08)
					T(m, "Ear", earCol, mid + side * e * 0.5, mid - side * e * 0.5, root + dir * e, 0.08)
				else
					-- the inner ear lies on the ear's front face, along its own normal
					local earOut = side:Cross(dir).Unit
					if earOut:Dot(D) < 0 then
						earOut = -earOut
					end
					T(m, "Ear", earCol, root + side * e * 0.3, root - side * e * 0.3, root + dir * e * (s.Ear == "Long" and 3.2 or 1.5), 0.08)
					T(m, "Ear", o.EarInner or earCol, root + side * e * 0.14 + earOut * 0.075 + dir * e * 0.2, root - side * e * 0.14 + earOut * 0.075 + dir * e * 0.2, root + dir * e * (s.Ear == "Long" and 2.4 or 1.1) + earOut * 0.075, 0.04)
				end
			end
			if o.Horns then
				local h = poll + U * s.Head[2][3] * 0.8 + X * sx * s.Head[2][2] * 0.6
				local pts = { h, h + V(sx * 0.42, 0.22, 0.1), h + V(sx * 0.82, 0.62, -0.1), h + V(sx * 0.95, 1.15, -0.35) }
				Creatures.tube(m, pts, { 0.16, 0.13, 0.09, 0.04 }, "Antler", o.HornColor or rgb(210, 200, 170), 5)
			end
			if o.Tusks then
				local t0 = poll + D * hl * 0.7 - U * s.Head[4][4] * 0.9 + X * sx * s.Head[4][2] * 0.8
				Creatures.tube(m, { t0, t0 + V(sx * 0.06, -0.14, -0.1), t0 + V(sx * 0.1, 0.1, -0.3) }, { 0.07, 0.05, 0.015 }, "Tusk", rgb(240, 232, 210), 3)
			end
		end
		-- lower jaw on its hinge, slightly apart from the head's underside
		local jr = s.Head[3]
		local jawAt = poll + D * hl * 0.26 - U * (s.Head[2][4] * 0.72)
		limb(m, jawAt, jawAt + D * hl * (s.JawLen or 0.62) - U * 0.03, jr[2] * 0.62, jr[2] * 0.42, o.JawColor or muzzle, "Jaw", 5)
		if o.Teeth then
			for _, sx in ipairs({ -1, 1 }) do
				for i = 1, o.Teeth do
					local c = jawAt + D * hl * (0.14 + i * (s.JawLen or 0.62) / (o.Teeth + 1)) + X * sx * jr[2] * 0.48 + U * jr[2] * 0.3
					T(m, "Jaw", rgb(242, 238, 220), c + D * 0.05, c - D * 0.05, c + U * 0.12, 0.03)
				end
			end
		end
		if o.Hair then
			-- a mane down both sides from the crest of the neck
			local backI = #neckRings[1] // 2 + 1
			local c0, c1 = neckRings[1][backI], neckRings[#neckRings][backI]
			for _, sx in ipairs({ -1, 1 }) do
				for i = 1, o.HairCount or 6 do
					local t = (i - 0.5 + (sx > 0 and 0.5 or 0)) / ((o.HairCount or 6) + 0.5)
					local a1, a2 = rnd(i * sx + 90, 1), rnd(i * sx + 90, 2)
					local dir = (V(sx * (0.5 + a2 * 0.3), -0.9, 0.4 + a1 * 0.4)).Unit
					local L = (o.HairLen or 1.1) * (0.85 + a1 * 0.4) / 3
					local p = c0:Lerp(c1, t) - dir * 0.05
					local pts = { p }
					for k = 1, 3 do
						p += (dir + V(sx * math.sin(k * 1.7 + i) * 0.16, 0, math.cos(k * 1.3 + i) * 0.18)).Unit * L
						table.insert(pts, p)
					end
					strand(m, "Neck", pts, V(sx * (a2 - 0.5) * 0.5, 0.45, 0.85).Unit, (o.HairW or 0.2) + a2 * 0.05, o.Hair[(i % 2) + 1])
				end
			end
		end
		-- tail
		if s.Tail then
			Creatures.tube(m, s.Tail[1], s.Tail[2], "Tail", o.TailColor or back, s.Tail[3] or 4)
			if o.TailTip then
				local n = #s.Tail[1]
				local a, b = s.Tail[1][n], s.Tail[1][n] + (s.Tail[1][n] - s.Tail[1][n - 1]).Unit * s.Tail[2][n] * 2.6
				limb(m, a, b, s.Tail[2][n] * 1.25, s.Tail[2][n] * 0.5, o.TailTip, "Tail", 4)
			end
		end
		-- legs
		local R = s.LegR
		local cols = { legTop, legTop, legLow, legLow }
		local function foot(sm, f)
			paw(sm, f, s.PawW, s.PawL, s.PawH or 0.18, pawCol, claw, s.Claws)
		end
		for _, sx in ipairs({ -1, 1 }) do
			local J, f = s.Front(sx)
			qleg(m, "LegFront", sx, J, f, R, o.Pattern == "Panda" and { o.PatternColor, o.PatternColor, o.PatternColor, o.PatternColor } or cols, function(sm)
				foot(sm, f)
			end)
			J, f = s.Back(sx)
			qleg(m, "LegBack", sx, J, f, R, o.Pattern == "Panda" and { coat, o.PatternColor, o.PatternColor, o.PatternColor } or cols, function(sm)
				foot(sm, f)
			end)
		end
		local rootC = s.Root[1]
		m:SetAttribute("RootC", rootC)
		m:SetAttribute("RootS", s.Root[2])
		m:SetAttribute("NeckBase", s.Neck[1][1] + V(0, 0.1, -0.1) - rootC)
		m:SetAttribute("HeadPivot", poll - rootC)
		m:SetAttribute("JawPivot", jawAt - rootC)
		m:SetAttribute("Length", s.Length)
		m:SetAttribute("Stride", s.Stride or 3)
		return V(s.Root[2].X, poll.Y + 1.2, s.Length)
	end

	-- Big cat: long and low, short muzzle, round ears, a long tail. Design 6 long, shoulder 3.
	recipes.Feline = function(m, o)
		local w = o.Build == "Heavy" and 1.32 or 1.14
		local poll, nose = V(0, 3.05, -2.05), V(0, 2.72, -2.95)
		return beast(m, o, {
			Torso = { { -1.75, 2.3, 0.28 * w, 0.42, 0.4 }, { -1.45, 2.3, 0.58 * w, 0.68, 0.72 }, { -0.7, 2.28, 0.62 * w, 0.66, 0.7 },
				{ 0.5, 2.3, 0.54 * w, 0.58, 0.56 }, { 1.25, 2.35, 0.56 * w, 0.58, 0.54 }, { 1.72, 2.4, 0.28 * w, 0.34, 0.3 } },
			Neck = { { V(0, 2.55, -1.3), 0.44 * w, 0.46, 0.46 }, { poll + V(0, -0.2, 0.1), 0.32 * w, 0.32, 0.3 } },
			Poll = poll, Nose = nose, Muzzle = 0.62,
			Head = { { 0, 0.3, 0.3, 0.3 }, { 0.22, 0.48 * w, 0.42, 0.4 }, { 0.6, 0.36 * w, 0.32, 0.3 }, { 0.82, 0.3 * w, 0.24, 0.26 }, { 1, 0.17, 0.14, 0.15 } },
			Ear = "Round", EarSize = 0.34, JawLen = 0.58,
			Tail = { { V(0, 2.62, 1.6), V(0, 2.2, 2.35), V(0, 1.7, 3.0), V(0, 1.72, 3.75), V(0, 2.2, 4.25) }, { 0.2, 0.18, 0.17, 0.16, 0.12 }, 4 },
			Front = function(sx)
				local x = sx * 0.42 * w
				return { V(x, 2.4, -1.2), V(x, 1.55, -1.1), V(x, 0.72, -1.18), V(x, 0.25, -1.2) }, V(x, 0, -1.22)
			end,
			Back = function(sx)
				local x = sx * 0.42 * w
				return { V(x, 2.4, 1.2), V(x, 1.5, 0.92), V(x, 0.82, 1.5), V(x, 0.25, 1.42) }, V(x, 0, 1.4)
			end,
			LegR = { 0.33 * w, 0.27 * w, 0.19 * w, 0.17 * w, 0.17 * w }, PawW = 0.48 * w, PawL = 0.66, Claws = 3,
			Root = { V(0, 2.25, 0), V(1.1, 1.3, 3) }, Length = 6, Stride = 3.2,
		})
	end

	-- Bear: heavy and flat-footed, a shoulder hump, hips lower than the shoulders. Design 6.5 long, shoulder 3.6.
	recipes.Bear = function(m, o)
		local h = o.Hump or 0.3
		local poll, nose = V(0, 3.15, -2.5), V(0, 2.62, -3.4)
		return beast(m, o, {
			Torso = { { -2.1, 2.45, 0.42, 0.55, 0.55 }, { -1.65, 2.55, 0.86, 0.98 + h * 0.3, 1.05 }, { -0.8, 2.55, 0.98, 1.02 + h * 0.4, 1.12 },
				{ 0.5, 2.35, 0.94, 0.88, 1.0 }, { 1.4, 2.22, 0.84, 0.78, 0.84 }, { 1.95, 2.15, 0.42, 0.42, 0.44 } },
			Neck = { { V(0, 2.85, -1.75), 0.62, 0.62, 0.6 }, { poll + V(0, -0.15, 0.15), 0.46, 0.46, 0.44 } },
			Poll = poll, Nose = nose, Muzzle = 0.58, EyeT = 0.34,
			Head = { { 0, 0.36, 0.36, 0.36 }, { 0.26, 0.62, 0.52, 0.48 }, { 0.58, 0.44, 0.38, 0.36 }, { 0.84, 0.3, 0.26, 0.26 }, { 1, 0.18, 0.15, 0.16 } },
			Ear = "Round", EarSize = 0.42, JawLen = 0.62,
			Tail = { { V(0, 2.42, 2.05), V(0, 2.2, 2.4) }, { 0.2, 0.13 }, 4 },
			Front = function(sx)
				local x = sx * 0.66
				return { V(x, 2.6, -1.45), V(x, 1.55, -1.42), V(x, 0.58, -1.45), V(x, 0.3, -1.48) }, V(x, 0, -1.5)
			end,
			Back = function(sx)
				local x = sx * 0.64
				return { V(x, 2.4, 1.35), V(x, 1.42, 1.15), V(x, 0.62, 1.42), V(x, 0.3, 1.4) }, V(x, 0, 1.38)
			end,
			LegR = { 0.46, 0.38, 0.27, 0.25, 0.26 }, PawW = 0.72, PawL = 0.95, PawH = 0.24, Claws = 4,
			Root = { V(0, 2.4, 0), V(1.8, 1.9, 3.5) }, Length = 6.5, Stride = 2.6,
		})
	end

	-- Tortoise: a high domed shell in big plates over stubby legs; the shell never bends. Design 6.5 long.
	recipes.Shelled = function(m, o)
		local poll, nose = V(0, 1.72, -3.05), V(0, 1.45, -3.85)
		local shell = o.Shell or rgb(70, 140, 110)
		o = table.clone(o)
		o.Coat, o.Back = shell, shell
		o.Belly = o.Plastron or rgb(180, 170, 120)
		o.Scutes = o.Scutes or { o.Scute or shell:Lerp(Color3.new(0, 0, 0), 0.25), shell:Lerp(Color3.new(1, 1, 1), 0.12) }
		o.ScuteFacets, o.ScuteAcross, o.ScuteLen = { 1, 2, 5, 6 }, 2, 1.25
		o.Face, o.Muzzle, o.NeckColor = o.Skin, o.Skin, o.Skin
		o.Paw, o.LegTop, o.Leg, o.JawColor, o.TailColor = o.Skin, o.Skin, o.Skin, o.Skin, o.Skin
		return beast(m, o, {
			Torso = { { -2.5, 1.45, 0.8, 0.5, 0.3 }, { -2.05, 1.5, 1.72, 1.15, 0.5 }, { -0.8, 1.55, 2.08, 1.72, 0.55 },
				{ 0.8, 1.55, 2.08, 1.72, 0.55 }, { 2.05, 1.5, 1.72, 1.15, 0.5 }, { 2.5, 1.45, 0.8, 0.5, 0.3 } },
			Neck = { { V(0, 1.55, -2.15), 0.42, 0.42, 0.4 }, { poll + V(0, -0.1, 0.1), 0.34, 0.32, 0.32 } },
			Poll = poll, Nose = nose, Muzzle = 2, EyeT = 0.36,
			Head = { { 0, 0.28, 0.28, 0.28 }, { 0.3, 0.42, 0.36, 0.32 }, { 0.65, 0.32, 0.26, 0.24 }, { 0.88, 0.2, 0.18, 0.16 }, { 1, 0.1, 0.08, 0.09 } },
			Ear = false, JawLen = 0.58,
			Tail = { { V(0, 1.3, 2.4), V(0, 1.05, 3.05) }, { 0.2, 0.06 }, 4 },
			Front = function(sx)
				local x = sx * 1.35
				return { V(x, 1.3, -1.55), V(x + sx * 0.4, 0.85, -1.6), V(x + sx * 0.5, 0.5, -1.62), V(x + sx * 0.5, 0.24, -1.65) }, V(x + sx * 0.5, 0, -1.68)
			end,
			Back = function(sx)
				local x = sx * 1.35
				return { V(x, 1.3, 1.55), V(x + sx * 0.4, 0.85, 1.6), V(x + sx * 0.5, 0.5, 1.62), V(x + sx * 0.5, 0.24, 1.6) }, V(x + sx * 0.5, 0, 1.58)
			end,
			LegR = { 0.46, 0.44, 0.4, 0.38, 0.38 }, PawW = 0.84, PawL = 0.95, PawH = 0.2, Claws = 3,
			Root = { V(0, 1.5, 0), V(3, 1.6, 4.4) }, Length = 6.5, Stride = 1.7,
		})
	end

	-- Crocodile or toad: sprawled legs, the upper leg sticking out sideways, the belly almost on the ground.
	recipes.Sprawler = function(m, o)
		if o.Build == "Toad" then
			local poll, nose = V(0, 1.95, -1.15), V(0, 1.55, -2.2)
			o = table.clone(o)
			o.Scutes = o.Warts and { o.Wart, o.Wart:Lerp(Color3.new(0, 0, 0), 0.15) } or nil
			o.ScuteLen, o.ScuteAcross = 0.42, 1
			local h = beast(m, o, {
				Torso = { { -1.25, 1.35, 0.5, 0.55, 0.55 }, { -0.9, 1.35, 1.25, 0.95, 0.98 }, { -0.2, 1.35, 1.55, 1.1, 1.08 },
					{ 0.6, 1.35, 1.42, 0.95, 0.98 }, { 1.2, 1.32, 0.9, 0.62, 0.68 }, { 1.45, 1.3, 0.4, 0.3, 0.32 } },
				Neck = { { V(0, 1.5, -0.95), 0.7, 0.55, 0.5 }, { poll + V(0, -0.15, 0.1), 0.62, 0.4, 0.42 } },
				Poll = poll, Nose = nose, Muzzle = 2, EyeT = 0.3,
				Head = { { 0, 0.5, 0.36, 0.38 }, { 0.3, 0.92, 0.46, 0.42 }, { 0.7, 0.8, 0.32, 0.3 }, { 0.92, 0.5, 0.16, 0.18 }, { 1, 0.2, 0.06, 0.08 } },
				Ear = false, JawLen = 0.8,
				Front = function(sx)
					local x = sx * 1.05
					return { V(x, 1.1, -0.9), V(x + sx * 0.5, 0.75, -1.05), V(x + sx * 0.62, 0.42, -1.2), V(x + sx * 0.62, 0.2, -1.25) }, V(x + sx * 0.62, 0, -1.3)
				end,
				Back = function(sx)
					local x = sx * 1.1
					return { V(x, 1.2, 0.8), V(x + sx * 0.72, 1.05, 0.1), V(x + sx * 0.92, 0.72, 1.0), V(x + sx * 0.92, 0.2, 0.75) }, V(x + sx * 0.92, 0, 0.7)
				end,
				LegR = { 0.36, 0.26, 0.18, 0.15, 0.15 }, PawW = 0.72, PawL = 0.85, PawH = 0.1, Claws = 3,
				Root = { V(0, 1.3, 0), V(2.4, 1.6, 2.2) }, Length = 4.5, Stride = 1.8,
			})
			return h
		end
		-- croc: 10 long, flat and wide, long snout with teeth, armoured back and tail
		local poll, nose = V(0, 1.05, -3.45), V(0, 0.82, -5.15)
		o = table.clone(o)
		o.Scutes = { o.Back, o.Back:Lerp(o.Coat, 0.5) }
		o.ScuteAcross, o.ScuteLen = 1, 0.72
		o.Teeth = 4
		o.TailColor = o.Back
		return beast(m, o, {
			Torso = { { -3.0, 0.95, 0.5, 0.42, 0.34 }, { -2.5, 0.95, 0.96, 0.58, 0.46 }, { -1.1, 0.98, 1.15, 0.64, 0.5 },
				{ 0.4, 0.98, 1.1, 0.62, 0.5 }, { 1.6, 0.95, 0.82, 0.54, 0.44 }, { 2.4, 0.92, 0.5, 0.42, 0.36 } },
			Neck = { { V(0, 1.0, -2.75), 0.72, 0.5, 0.42 }, { poll + V(0, -0.08, 0.1), 0.56, 0.38, 0.32 } },
			Poll = poll, Nose = nose, Muzzle = 2, EyeT = 0.2,
			Head = { { 0, 0.5, 0.34, 0.3 }, { 0.2, 0.64, 0.42, 0.3 }, { 0.5, 0.38, 0.24, 0.2 }, { 0.86, 0.3, 0.17, 0.14 }, { 1, 0.16, 0.08, 0.08 } },
			Ear = false, JawLen = 0.72,
			Tail = { { V(0, 0.92, 2.2), V(0, 0.85, 3.2), V(0, 0.75, 4.1), V(0, 0.62, 4.9) }, { 0.46, 0.34, 0.22, 0.09 }, 4 },
			Front = function(sx)
				local x = sx * 0.85
				return { V(x, 0.8, -2.0), V(x + sx * 0.62, 0.62, -2.05), V(x + sx * 0.82, 0.3, -2.25), V(x + sx * 0.82, 0.14, -2.3) }, V(x + sx * 0.82, 0, -2.35)
			end,
			Back = function(sx)
				local x = sx * 0.85
				return { V(x, 0.8, 1.2), V(x + sx * 0.72, 0.62, 1.2), V(x + sx * 0.92, 0.3, 1.0), V(x + sx * 0.92, 0.14, 0.95) }, V(x + sx * 0.92, 0, 0.9)
			end,
			LegR = { 0.3, 0.22, 0.16, 0.15, 0.15 }, PawW = 0.56, PawL = 0.66, PawH = 0.1, Claws = 3,
			Root = { V(0, 0.95, 0), V(1.8, 1.0, 4.5) }, Length = 10, Stride = 2.4,
		})
	end

	-- Small spirits: a fox (long muzzle, tall ears, a big brush) or a rabbit (round, long ears, cotton tail)
	recipes.SmallBeast = function(m, o)
		if o.Build == "Rabbit" then
			local poll, nose = V(0, 2.5, -1.15), V(0, 2.2, -1.85)
			return beast(m, o, {
				Torso = { { -1.0, 1.5, 0.34, 0.42, 0.42 }, { -0.75, 1.55, 0.62, 0.72, 0.74 }, { -0.1, 1.58, 0.72, 0.84, 0.82 },
					{ 0.55, 1.5, 0.74, 0.82, 0.8 }, { 1.0, 1.42, 0.5, 0.56, 0.56 }, { 1.2, 1.4, 0.22, 0.22, 0.24 } },
				Neck = { { V(0, 1.95, -0.75), 0.4, 0.4, 0.4 }, { poll + V(0, -0.15, 0.1), 0.3, 0.3, 0.3 } },
				Poll = poll, Nose = nose, Muzzle = 0.62, EyeT = 0.32,
				Head = { { 0, 0.28, 0.3, 0.3 }, { 0.28, 0.46, 0.44, 0.4 }, { 0.62, 0.36, 0.3, 0.3 }, { 0.86, 0.2, 0.17, 0.17 }, { 1, 0.09, 0.07, 0.08 } },
				Ear = "Long", EarSize = 0.42, JawLen = 0.5,
				Tail = { { V(0, 1.6, 1.15), V(0, 1.68, 1.4) }, { 0.2, 0.2 }, 5 },
				Front = function(sx)
					local x = sx * 0.34
					return { V(x, 1.2, -0.66), V(x, 0.8, -0.7), V(x, 0.42, -0.75), V(x, 0.14, -0.78) }, V(x, 0, -0.8)
				end,
				Back = function(sx)
					local x = sx * 0.55
					return { V(x, 1.35, 0.72), V(x, 0.8, 0.28), V(x, 0.42, 0.75), V(x, 0.14, 0.45) }, V(x, 0, 0.4)
				end,
				LegR = { 0.28, 0.2, 0.13, 0.12, 0.12 }, PawW = 0.34, PawL = 0.62, PawH = 0.1, Claws = 2,
				Root = { V(0, 1.5, 0), V(1.1, 1.1, 1.8) }, Length = 3.2, Stride = 1.7,
			})
		end
		local poll, nose = V(0, 2.7, -1.75), V(0, 2.32, -2.9)
		return beast(m, o, {
			Torso = { { -1.5, 2.0, 0.26, 0.36, 0.36 }, { -1.2, 2.0, 0.46, 0.56, 0.6 }, { -0.5, 2.0, 0.48, 0.56, 0.58 },
				{ 0.5, 2.04, 0.4, 0.46, 0.44 }, { 1.1, 2.08, 0.4, 0.44, 0.4 }, { 1.45, 2.1, 0.2, 0.24, 0.22 } },
			Neck = { { V(0, 2.25, -1.1), 0.34, 0.36, 0.36 }, { poll + V(0, -0.2, 0.1), 0.24, 0.25, 0.25 } },
			Poll = poll, Nose = nose, Muzzle = 0.5,
			Head = { { 0, 0.24, 0.25, 0.25 }, { 0.2, 0.42, 0.36, 0.33 }, { 0.5, 0.26, 0.22, 0.22 }, { 0.84, 0.13, 0.12, 0.12 }, { 1, 0.08, 0.07, 0.07 } },
			Ear = "Tall", EarSize = 0.56, EarInner = o.Belly, JawLen = 0.72,
			Tail = { { V(0, 2.25, 1.4), V(0, 2.1, 2.1), V(0, 2.2, 2.85), V(0, 2.55, 3.4) }, { 0.14, 0.32, 0.36, 0.2 }, 4 },
			Front = function(sx)
				local x = sx * 0.3
				return { V(x, 2.05, -1.05), V(x, 1.3, -1.0), V(x, 0.62, -1.05), V(x, 0.2, -1.08) }, V(x, 0, -1.1)
			end,
			Back = function(sx)
				local x = sx * 0.3
				return { V(x, 2.05, 1.05), V(x, 1.3, 0.78), V(x, 0.7, 1.3), V(x, 0.2, 1.24) }, V(x, 0, 1.2)
			end,
			LegR = { 0.17, 0.14, 0.1, 0.09, 0.09 }, PawW = 0.26, PawL = 0.44, PawH = 0.12, Claws = 2,
			Root = { V(0, 2, 0), V(0.8, 1, 2.6) }, Length = 4.6, Stride = 2.6,
		})
	end

	-- ================================================================= the biped family
	-- A skeleton: Hips (pelvis, the HRP) -> Waist1 (chest) -> Head1, RA1..3 / LA1..3 (arms); Hips -> RH1..3 /
	-- LH1..3 (legs). P holds the joint heights; skin.* builds each segment. Design height 5.6, faces -Z.
	local function skeleton(m, P, skin)
		local W = V(0, P.HipY + 0.1, 0)
		skin.pelvis(m)
		chain(m, "Waist", "Hips", { W }, { skin.chest })
		local N = V(0, P.NeckY, P.NeckZ or 0)
		chain(m, "Head", "Waist1", { N }, { skin.head })
		for _, sx in ipairs({ -1, 1 }) do
			local tagA, tagH = sx > 0 and "RA" or "LA", sx > 0 and "RH" or "LH"
			local Sh = V(sx * P.ShX, P.ShY, 0)
			local El = Sh + V(sx * P.ElOut, -P.Upper, 0.02)
			local Wr = El + V(sx * (P.WrOut or 0), -P.Lower, -(P.WrFwd or 0.1))
			local Hd = Wr + V(0, -P.Hand, -0.02)
			chain(m, tagA, "Waist1", { Sh, El, Wr }, {
				function(sm) skin.upperArm(sm, Sh, El, sx) end,
				function(sm) skin.foreArm(sm, El, Wr, sx) end,
				function(sm)
					skin.hand(sm, Wr, Hd, sx)
					auraNode(sm, sx > 0 and "WingR" or "WingL", Hd)
				end,
			})
			local Hp = V(sx * P.HipX, P.HipY, 0)
			local Kn = V(sx * P.HipX * 1.05, P.KneeY, P.KneeZ or -0.08)
			local An = V(sx * P.HipX * 1.05, P.AnkleY or 0.3, 0.04)
			local Ft = V(sx * P.HipX * 1.05, 0, -0.12)
			chain(m, tagH, "Hips", { Hp, Kn, An }, {
				function(sm) skin.thigh(sm, Hp, Kn, sx) end,
				function(sm) skin.shin(sm, Kn, An, sx) end,
				function(sm) skin.foot(sm, An, Ft, sx) end,
			})
		end
		local rootC = V(0, P.HipY, 0)
		m:SetAttribute("RootC", rootC)
		m:SetAttribute("RootS", V(P.HipX * 2.4, 0.7, 0.9))
		m:SetAttribute("Height", 5.6)
		m:SetAttribute("Length", 2)
		m:SetAttribute("Stride", P.Stride or 2.6)
		m:SetAttribute("RigKind", "Biped")
		return V(P.ShX * 2.5, 5.6, 2)
	end

	local function furStrands(sm, on, base, dirv, n, len, w, cols, salt)
		-- a few strands of fur down from a shoulder, forearm or back
		for i = 1, n do
			local a1, a2 = rnd(i + salt, 1), rnd(i + salt, 2)
			local p = base + V((a1 - 0.5) * 0.45, (a2 - 0.5) * 0.5, (a2 - 0.5) * 0.35)
			local dir = (dirv + V((a2 - 0.5) * 0.5, 0, (a1 - 0.5) * 0.5)).Unit
			local L = len * (0.8 + a1 * 0.4) / 3
			strand(sm, on, { p, p + dir * L, p + dir * L * 2 + V(0, -0.02, 0.03), p + dir * L * 3 + V(0, -0.06, 0.06) }, V(a1 - 0.5, 0.1, 1).Unit, w, cols[(i % 2) + 1])
		end
	end

	-- Apes, trolls and the yeti: top-heavy with long arms and always-bent legs
	recipes.Ape = function(m, o)
		local build = o.Build or "Ape"
		local coat, skin = o.Coat or rgb(120, 100, 80), o.Skin or rgb(90, 75, 70)
		local mane = o.Mane or { coat, coat:Lerp(Color3.new(1, 1, 1), 0.2) }
		local big = (build == "Yeti" or build == "Troll") and 1.1 or (build == "Monkey" and 0.82 or 1)
		local P = { HipY = 1.85, HipX = 0.46 * big, KneeY = 0.98, NeckY = 4.55, ShX = 1.06 * big, ShY = 4.1, ElOut = 0.2, Upper = 1.25, Lower = 1.12, Hand = 0.45, Stride = 2.6 }
		if build == "Troll" then
			P.NeckY, P.ShY = 4.75, 4.35
			P.HipY, P.KneeY = 2.15, 1.1
		end
		local function plates(sm, rings, name)
			if not o.Plates then
				return
			end
			local cols = { o.Plates, o.Plates:Lerp(Color3.new(0, 0, 0), 0.18) }
			for _, k in ipairs({ 1, 2, 5, 6 }) do
				scaleStrip(sm, name, rings, k, 0, 1, 1, 0.7, -1, function(i)
					return cols[(i % 2) + 1]
				end)
			end
		end
		local skinSet = {
			pelvis = function(mm)
				loft(mm, { { V(0, P.HipY - 0.42, 0), 0.5 * big, 0.36, 0.36 }, { V(0, P.HipY + 0.1, 0), 0.72 * big, 0.5, 0.5 }, { V(0, P.HipY + 0.5, 0), 0.62 * big, 0.42, 0.42 } }, function()
					return "Body", coat
				end)
			end,
			chest = function(sm)
				local belly = o.Belly or skin
				local rg = loft(sm, { { V(0, P.HipY + 0.32, 0), 0.62 * big, 0.45, 0.42 }, { V(0, P.ShY - 0.9, -0.02), 1.02 * big, 0.68, 0.62 }, { V(0, P.ShY, 0.02), 1.08 * big, 0.68, 0.56 }, { V(0, P.NeckY - 0.1, 0.05), 0.5 * big, 0.36, 0.34 } }, function(c, n)
					if n.Z < -0.65 and c.Y < P.ShY - 0.1 then
						return "Chest", belly
					end
					return "Chest", coat
				end)
				plates(sm, rg, "Chest")
				if o.Fur then
					furStrands(sm, "Waist1", V(0, P.ShY + 0.12, 0.42), V(0, -1, 0.3), o.Fur, 1.6, 0.26, mane, 11)
				end
			end,
			head = function(sm)
				local c = V(0, P.NeckY + 0.32, -0.12)
				local long = build == "Troll" and 1.3 or 1
				local rg = loft(sm, { { c + V(0, -0.45, 0.05), 0.34, 0.3, 0.34 }, { c + V(0, -0.1, 0), 0.5, 0.42, 0.44 }, { c + V(0, 0.34, 0), 0.42, 0.36, 0.38 }, { c + V(0, 0.54, 0.02), 0.18, 0.16, 0.18 } }, function(cc, n)
					if n.Z < -0.55 and cc.Y < c.Y + 0.22 then
						return "Head", skin
					end
					return "Head", coat
				end)
				-- muzzle, brow and jaw
				limb(sm, c + V(0, -0.15, -0.2), c + V(0, -0.2 - (long - 1) * 0.1, -0.5 * long - 0.08), 0.32, 0.2, skin, "Head", 5)
				local browY = c.Y + 0.18
				newPart("Part", sm, CFrame.new(0, browY, c.Z - 0.42), V(0.72, 0.12, 0.2), coat:Lerp(Color3.new(0, 0, 0), 0.25), "Head")
				for _, sx in ipairs({ -1, 1 }) do
					eye(sm, V(sx * 0.19, browY - 0.13, c.Z - 0.39), (V(sx * 0.15, 0, -1)).Unit, Y * 0.06, X * sx * 0.08, o.EyeGlow or rgb(24, 22, 26), o.EyeGlow ~= nil)
					T(sm, "Head", skin, c + V(sx * 0.46, 0.1, 0.04), c + V(sx * 0.46, -0.16, 0.08), c + V(sx * (build == "Troll" and 1.05 or 0.68), 0.02, 0.14), 0.07)
					if o.Tusks then
						local t0 = c + V(sx * 0.14, -0.33, -0.42)
						limb(sm, t0, t0 + V(sx * 0.05, 0.3 * o.Tusks, -0.06), 0.06, 0.02, rgb(236, 228, 204), "Head", 3)
					end
				end
				if o.Crown then
					for i = 1, 5 do
						local a = (i - 3) * 0.42
						local b = c + V(math.sin(a) * 0.38, 0.46, -math.cos(a) * 0.2)
						T(sm, "Head", i == 3 and (o.Glow or o.Crown) or o.Crown, b + V(0.1, 0, 0), b - V(0.1, 0, 0), b + V(0, 0.42 + (i == 3 and 0.2 or 0), 0), 0.05, (i == 3 and o.Glow) and NEON or nil)
					end
				end
				plates(sm, rg, "Head")
				if o.Icicles then
					for i = 1, 3 do
						local p = c + V((i - 2) * 0.28, 0.5, 0.12)
						limb(sm, p, p + V((i - 2) * 0.12, 0.45, 0.08), 0.08, 0.02, o.Glow or rgb(190, 235, 255), "Head", 3, NEON)
					end
				end
			end,
			upperArm = function(sm, a, b, sx)
				limb(sm, a + V(sx * -0.08, 0.2, 0), b, 0.42 * big, 0.32 * big, coat, "Arm", 5)
				if o.Fur then
					furStrands(sm, sx > 0 and "RA1" or "LA1", a + V(sx * 0.18, -0.2, 0.16), V(sx * 0.4, -1, 0.2), 2, 1.1, 0.2, mane, 23 + sx)
				end
				if o.Icicles then
					limb(sm, a + V(sx * 0.1, 0.2, 0.05), a + V(sx * 0.4, 0.9, 0.2), 0.14, 0.03, o.Glow or rgb(190, 235, 255), "Arm", 3, NEON)
				end
			end,
			foreArm = function(sm, a, b, sx)
				limb(sm, a, b, 0.32 * big, 0.3 * big, coat, "Arm", 5)
				if o.Fur then
					furStrands(sm, sx > 0 and "RA2" or "LA2", a:Lerp(b, 0.4) + V(sx * 0.14, 0, 0.14), V(sx * 0.3, -1, 0.15), 2, 0.9, 0.18, mane, 37 + sx)
				end
			end,
			hand = function(sm, a, b, sx)
				limb(sm, a, b, 0.32 * big, 0.3 * big, skin, "Hand", 5)
			end,
			thigh = function(sm, a, b)
				limb(sm, a + V(0, 0.15, 0), b, 0.42 * big, 0.3 * big, coat, "Leg", 5)
			end,
			shin = function(sm, a, b)
				limb(sm, a, b, 0.3 * big, 0.26 * big, coat, "Leg", 5)
			end,
			foot = function(sm, a, f)
				limb(sm, a, f + V(0, 0.15, 0), 0.26 * big, 0.28 * big, skin, "Foot", 4)
				newPart("Part", sm, CFrame.new(f + V(0, 0.09, -0.16)), V(0.52 * big, 0.18, 0.9 * big), skin, "Foot")
			end,
		}
		local h = skeleton(m, P, skinSet)
		if o.Tail then
			local t0 = V(0, P.HipY + 0.1, 0.42)
			local t1, t2, t3 = t0 + V(0, -0.2, 0.75), t0 + V(0, 0.15, 1.45), t0 + V(0, 0.9, 1.8)
			chain(m, "Tail", "Hips", { t0, t1, t2 }, {
				function(sm) limb(sm, t0, t1, 0.13, 0.11, coat, "Tail", 4) end,
				function(sm) limb(sm, t1, t2, 0.11, 0.09, coat, "Tail", 4) end,
				function(sm) limb(sm, t2, t3, 0.09, 0.05, coat, "Tail", 4) end,
			})
		end
		if build ~= "Yeti" and build ~= "Troll" then
			m:SetAttribute("Knuckle", true)
		end
		return h
	end

	-- a weapon in the hand at w, pointing forward and a little up (Sword, Spear, Greatsword)
	local function weapon(sm, w, kind, blade, trim)
		local dir = V(0, 0.32, -1).Unit
		local side = X
		local up = side:Cross(dir).Unit
		local at = w + V(0, -0.42, -0.05)
		if kind == "Spear" then
			limb(sm, at - dir * 1.5, at + dir * 2.9, 0.075, 0.06, rgb(92, 66, 44), "Weapon", 4)
			local tip = at + dir * 2.9
			T(sm, "Weapon", blade, tip + up * 0.14, tip - up * 0.14, tip + dir * 0.85, 0.05)
			return
		end
		local L, H = kind == "Greatsword" and 3.5 or 2.1, kind == "Greatsword" and 0.25 or 0.13
		limb(sm, at - dir * 0.24, at + dir * 0.28, 0.06, 0.06, rgb(62, 44, 34), "Weapon", 3)
		local g = at + dir * 0.28
		newPart("Part", sm, CFrame.lookAt(g, g + dir), V(H * 3.4, 0.09, 0.1), trim or rgb(170, 150, 90), "Weapon")
		local b0 = g + dir * 0.07
		T(sm, "Weapon", blade, b0 + up * H, b0 - up * H, b0 + dir * L - up * H * 0.7, 0.06)
		T(sm, "Weapon", blade, b0 + up * H, b0 + dir * L - up * H * 0.7, b0 + dir * (L + H * 2.2), 0.06)
		T(sm, "Weapon", blade:Lerp(Color3.new(1, 1, 1), 0.3), b0 - up * H * 0.6 + X * 0.045, b0 + dir * (L + H * 1.2) + X * 0.045, b0 + dir * L - up * H * 0.55 + X * 0.045, 0.02)
	end

	-- Humanoids: bandits (flesh and cloth), skeletons (bones in rags), knights (bones in plate).
	recipes.Warrior = function(m, o)
		local bones = o.Body == "Bone"
		local outfit = o.Outfit or "Bandit"
		local bone = o.Bone or rgb(226, 220, 196)
		local skin = bones and bone or (o.Skin or rgb(200, 160, 130))
		local cloth, cloth2 = o.Cloth or rgb(110, 80, 60), o.Cloth2 or rgb(70, 54, 46)
		local armor = o.Armor
		local trim = o.Trim or rgb(170, 150, 90)
		local thin = bones and 0.55 or 1
		local legSides, armSides = bones and 3 or 4, bones and 3 or 4
		local plated = outfit == "Knight" or outfit == "Warlord"
		local P = { HipY = 2.85, HipX = 0.34, KneeY = 1.52, AnkleY = 0.26, KneeZ = -0.06, NeckY = 4.72, ShX = 0.78, ShY = 4.4, ElOut = 0.08, Upper = 0.98, Lower = 0.9, Hand = 0.3, WrFwd = 0.06, Stride = 2.8 }
		-- a plate of armour: a box on the segment, far enough off the limb that no faces meet
		local function plate(sm, a, b, w, d, col, name)
			local len = (a - b).Magnitude
			local dir = (a - b).Unit
			newPart("Part", sm, CFrame.fromMatrix((a + b) / 2, X, dir, X:Cross(dir).Unit), V(w, len, d), col or armor, name or "Armor")
		end
		local set = {
			pelvis = function(mm)
				if bones then
					limb(mm, V(-0.36, P.HipY, 0), V(0.36, P.HipY, 0), 0.16, 0.16, bone, "Body", 4)
					limb(mm, V(0, P.HipY - 0.1, 0.02), V(0, P.HipY + 0.45, 0.04), 0.1, 0.08, bone, "Body", 3)
				else
					loft(mm, { { V(0, P.HipY - 0.28, 0), 0.38, 0.27, 0.27 }, { V(0, P.HipY + 0.12, 0), 0.46, 0.3, 0.3 }, { V(0, P.HipY + 0.42, 0), 0.4, 0.26, 0.26 } }, function()
						return "Body", cloth2
					end)
					-- sash
					local s = o.Sash or rgb(160, 40, 34)
					newPart("Part", mm, CFrame.new(0, P.HipY + 0.28, 0), V(0.98, 0.17, 0.66), s, "Body")
				end
				if outfit ~= "Knight" and (outfit == "Rags" or outfit == "Captain") then
					-- tattered skirt or coat tails
					local col = outfit == "Rags" and (o.Cloth or rgb(70, 66, 58)) or cloth
					for i = 0, outfit == "Captain" and 7 or 5 do
						local a = i / (outfit == "Captain" and 8 or 6) * math.pi * 2 + 0.2
						local dirv = V(math.sin(a), 0, math.cos(a))
						local r0 = (bones and 0.36 or 0.5)
						local top = V(0, P.HipY + 0.22, 0) + dirv * r0
						local long = (outfit == "Captain" and 1.9 or 1.1) * (0.8 + rnd(i, 3) * 0.3)
						local side = V(-dirv.Z, 0, dirv.X)
						T(mm, "Cloth", col, top + side * 0.26, top - side * 0.26, top + dirv * 0.12 + V(0, -long, 0), 0.05)
					end
				end
			end,
			chest = function(sm)
				if bones then
					-- spine and four ribs round an open cage
					limb(sm, V(0, P.HipY + 0.2, 0.08), V(0, P.NeckY, 0.08), 0.08, 0.07, bone, "Bone", 3)
					for i = 1, 4 do
						local y = P.HipY + 0.62 + i * 0.26
						local r = 0.34 + i * 0.05
						local A, B = ring(V(0, y, 0), X, Vector3.zAxis, r + 0.1, r * 0.8, r * 0.8, 6), ring(V(0, y + 0.09, 0), X, Vector3.zAxis, r + 0.1, r * 0.8, r * 0.8, 6)
						hull(sm, { A, B }, function()
							return "Bone", bone
						end, 0.05)
					end
					limb(sm, V(-P.ShX, P.ShY - 0.02, 0), V(P.ShX, P.ShY - 0.02, 0), 0.08, 0.08, bone, "Bone", 3)
				else
					loft(sm, { { V(0, P.HipY + 0.35, 0), 0.42, 0.28, 0.27 }, { V(0, P.ShY - 0.55, 0), 0.62, 0.36, 0.34 }, { V(0, P.ShY, 0), 0.72, 0.36, 0.3 }, { V(0, P.NeckY - 0.05, 0), 0.24, 0.2, 0.2 } }, function()
						return "Chest", cloth
					end)
				end
				if plated then
					local col = armor
					newPart("Part", sm, CFrame.new(0, P.ShY - 0.48, -0.02), V(1.28, 1.3, 0.92), col, "Armor")
					newPart("Part", sm, CFrame.new(0, P.ShY - 0.48, -0.5), V(0.14, 1.18, 0.1), trim, "Armor")
					newPart("Part", sm, CFrame.new(0, P.HipY + 0.56, -0.02), V(1.06, 0.3, 0.86), trim, "Armor")
					if outfit == "Warlord" then
						-- lamellar: rows of small scales over the cuirass
						for r = 1, 3 do
							for c = -2, 2 do
								local p = V(c * 0.22 + (r % 2) * 0.1, P.ShY - 0.05 - r * 0.28, -0.49)
								scale(sm, "Armor", col:Lerp(trim, 0.2 + (r + c) % 2 * 0.2), p, -Y, -Vector3.zAxis, 0.11, 0.3, 0.03 + (r % 2) * 0.008)
							end
						end
					end
				elseif outfit == "Bandit" or outfit == "Captain" then
					-- a leather strap across the chest
					local a, b = V(-0.5, P.ShY - 0.12, -0.3), V(0.5, P.HipY + 0.5, -0.27)
					T(sm, "Chest", cloth2, a, a + V(0.2, 0.02, 0), b, 0.04)
					T(sm, "Chest", cloth2, a + V(0.2, 0.02, 0), b + V(0.2, 0.02, 0), b, 0.04)
				end
			end,
			head = function(sm)
				local c = V(0, P.NeckY + 0.34, -0.03)
				if bones then
					-- a carved skull: dome, cheek, dark sockets with a glow, a hinged-looking jaw
					loft(sm, { { c + V(0, -0.12, 0), 0.25, 0.27, 0.27 }, { c + V(0, 0.12, 0.02), 0.34, 0.36, 0.36 }, { c + V(0, 0.3, 0.03), 0.22, 0.25, 0.25 } }, function()
						return "Head", bone
					end)
					newPart("Part", sm, CFrame.new(c + V(0, -0.3, -0.08)), V(0.34, 0.14, 0.36), bone:Lerp(Color3.new(0, 0, 0), 0.12), "Head")
					for _, sx in ipairs({ -1, 1 }) do
						local e = c + V(sx * 0.13, 0.03, -0.3)
						T(sm, "Eye", rgb(16, 14, 16), e + V(0, 0.1, -0.02), e + V(sx * 0.1, -0.04, 0.02), e + V(-sx * 0.08, -0.05, -0.02), 0.05)
						T(sm, "Eye", o.EyeGlow or rgb(150, 240, 150), e + V(0, 0.05, -0.05), e + V(sx * 0.045, -0.02, -0.04), e + V(-sx * 0.04, -0.025, -0.05), 0.03, NEON)
					end
				else
					loft(sm, { { c + V(0, -0.32, 0), 0.2, 0.2, 0.2 }, { c + V(0, 0, 0), 0.3, 0.31, 0.31 }, { c + V(0, 0.26, 0), 0.25, 0.26, 0.26 } }, function()
						return "Head", skin
					end)
					for _, sx in ipairs({ -1, 1 }) do
						eye(sm, c + V(sx * 0.12, 0.03, -0.29), (V(sx * 0.1, 0, -1)).Unit, Y * 0.045, X * sx * 0.06, rgb(24, 22, 26))
					end
					if o.Mask then
						newPart("Part", sm, CFrame.new(c + V(0, -0.14, -0.03)), V(0.5, 0.25, 0.56), o.MaskColor or cloth2, "Head")
					end
					-- headband or hair
					local hair = o.Hair or rgb(44, 34, 30)
					newPart("Part", sm, CFrame.new(c + V(0, 0.23, 0.02)), V(0.56, 0.17, 0.56), o.Band or hair, "Head")
					limb(sm, c + V(0, 0.3, 0.08), c + V(0, 0.55, 0.2), 0.14, 0.05, hair, "Head", 3)
				end
				if outfit == "Knight" or outfit == "Warlord" then
					-- helm: a box with a slit, on a skull or face
					if not o.NoHelm then
						newPart("Part", sm, CFrame.new(c + V(0, 0.2, 0.02)), V(0.78, 0.44, 0.8), armor, "Armor")
						newPart("Part", sm, CFrame.new(c + V(0, 0.46, 0.02)), V(0.1, 0.12, 0.84), trim, "Armor")
					end
					if o.Plume then
						for i = 1, 5 do
							-- fanned and each turned its own way, so no two ribbons lie in one plane
							local d = V((i - 3) * 0.24, 0.2 + i * 0.05, 1).Unit
							local p = c + V((i - 3) * 0.05, 0.5 + i * 0.012, 0.05)
							local dn = (d - V(0, 0.8, 0)).Unit
							strand(m, "Head1", { p, p + d * 0.55, p + d * 0.9 + dn * 0.3, p + d * 1.05 + dn * 0.9 }, V(1, (i - 3) * 0.3, (i - 3) * 0.25).Unit, 0.13, o.Plume)
						end
					end
				end
				if o.Glow and outfit == "Knight" then
					for i = 1, 5 do
						local a = (i - 3) * 0.55
						-- on the skull's brow when bare, on the helm's rim otherwise
						local b = c + V(math.sin(a) * 0.3, o.NoHelm and 0.28 or 0.44, math.cos(a) * -0.3 + 0.02)
						T(sm, "Glow", o.Glow, b + V(0.09, 0, 0), b - V(0.09, 0, 0), b + V(0, 0.34 + (i == 3 and 0.24 or 0), 0), 0.04, NEON)
					end
				end
			end,
			upperArm = function(sm, a, b, sx)
				limb(sm, a + V(0, 0.1, 0), b, 0.19 * thin, 0.15 * thin, bones and bone or cloth, "Arm", armSides)
				if plated then
					newPart("Part", sm, CFrame.new(a + V(sx * 0.1, 0.1, 0)), V(0.56, 0.36, 0.64), armor, "Armor")
					newPart("Part", sm, CFrame.new(a + V(sx * 0.1, 0.32, 0)), V(0.42, 0.1, 0.5), trim, "Armor")
				elseif outfit == "Rags" and sx > 0 then
					T(sm, "Cloth", o.Cloth or rgb(70, 66, 58), a + V(0.1, 0.1, -0.16), a + V(0.1, 0.1, 0.16), a + V(0.2, -0.6, 0), 0.04)
				end
			end,
			foreArm = function(sm, a, b)
				limb(sm, a, b, 0.14 * thin, 0.12 * thin, bones and bone or skin, "Arm", armSides)
				if plated then
					plate(sm, a + V(0, -0.1, 0), b + V(0, 0.08, 0), 0.34, 0.36)
				end
			end,
			hand = function(sm, a, b, sx)
				limb(sm, a, b, 0.11, 0.11, skin, "Hand", armSides)
				if sx > 0 and o.Weapon then
					weapon(sm, a, o.Weapon, o.Blade or rgb(180, 186, 196), trim)
				end
			end,
			thigh = function(sm, a, b)
				limb(sm, a + V(0, 0.1, 0), b, 0.24 * thin, 0.17 * thin, bones and bone or cloth2, "Leg", legSides)
				if plated then
					plate(sm, a + V(0, -0.15, 0), b + V(0, 0.1, 0), 0.5, 0.56)
				end
			end,
			shin = function(sm, a, b)
				limb(sm, a, b, 0.16 * thin, 0.13 * thin, bones and bone or cloth2, "Leg", legSides)
				if plated then
					plate(sm, a + V(0, -0.08, 0), b + V(0, 0.05, 0), 0.38, 0.42)
				end
			end,
			foot = function(sm, a, f)
				limb(sm, a, f + V(0, 0.1, 0), 0.1, 0.12, bones and bone or rgb(50, 40, 34), "Foot", 3)
				newPart("Part", sm, CFrame.new(f + V(0, 0.07, -0.1)), V(0.3, 0.14, 0.62), plated and armor or (bones and bone or rgb(50, 40, 34)), "Foot")
			end,
		}
		return skeleton(m, P, set)
	end

	-- Stone golems: separate chamfered slabs with gaps, oversized fists, a glowing rune core
	recipes.Golem = function(m, o)
		local stone = o.Coat or rgb(120, 125, 110)
		local dark = stone:Lerp(Color3.new(0, 0, 0), 0.22)
		local moss = o.Moss or rgb(88, 128, 70)
		local glow = o.Glow or rgb(120, 255, 170)
		local block = Creatures.block
		local cover = o.MossCover or 0
		local counter = 0
		local function slab(sm, cf, size, col, name)
			counter += 1
			block(sm, cf, size, col or stone, { c = math.min(size.X, size.Y, size.Z) * 0.18, edges = "all", axis = "Y", name = name or "Body" })
			for clump = 1, 3 do
				if cover > 0 and rnd(counter * 3 + clump, 2) < cover then
					-- clumps of moss on the slab's top, proud of the stone
					local k = counter * 3 + clump
					local top = cf.Position + V((rnd(k, 3) - 0.5) * size.X * 0.7, size.Y / 2 + 0.03 + clump * 0.012, (rnd(k, 4) - 0.5) * size.Z * 0.7)
					T(sm, "Moss", moss, top + V(size.X * 0.2, 0, size.Z * 0.1), top - V(size.X * 0.2, 0, 0), top + V(0, 0.3, -size.Z * 0.12), 0.05)
					T(sm, "Moss", moss:Lerp(stone, 0.2), top + V(0, 0, size.Z * 0.2), top - V(0, 0, size.Z * 0.2), top + V(size.X * 0.14, 0.24, 0), 0.05)
				end
			end
		end
		local P = { HipY = 2.1, HipX = 0.62, KneeY = 1.15, AnkleY = 0.42, NeckY = 4.72, ShX = 1.34, ShY = 4.3, ElOut = 0.08, Upper = 1.12, Lower = 1.02, Hand = 0.55, WrFwd = 0.06, Stride = 1.9 }
		local function between(sm, a, b, w, d, col, name)
			local dir = (a - b).Unit
			slab(sm, CFrame.fromMatrix((a + b) / 2, X, dir, X:Cross(dir).Unit), V(w, (a - b).Magnitude, d), col, name)
		end
		local set = {
			pelvis = function(mm)
				slab(mm, CFrame.new(0, P.HipY + 0.05, 0), V(1.65, 0.72, 1.15), dark, "Body")
			end,
			chest = function(sm)
				slab(sm, CFrame.new(0, P.HipY + 0.84, 0), V(1.55, 0.74, 1.15), stone, "Chest")
				slab(sm, CFrame.new(0, P.ShY - 0.5, 0.02), V(2.28, 1.22, 1.48), stone, "Chest")
				slab(sm, CFrame.new(0, P.ShY + 0.16, 0.2), V(1.5, 0.42, 0.9), dark, "Back")
				-- the rune core, inset on the chest's face
				local z = 0.02 - 1.48 / 2 - 0.03
				local c = V(0, P.ShY - 0.52, z)
				T(sm, "Glow", glow, c + V(0, 0.34, 0), c + V(0.26, 0, 0), c + V(-0.26, 0, 0), 0.04, NEON)
				T(sm, "Glow", glow, c + V(0.26, 0, 0), c + V(0, -0.34, 0), c + V(-0.26, 0, 0), 0.04, NEON)
				if o.Inlay then
					-- gold bands across the chest
					local gold = o.Plate or rgb(204, 170, 86)
					newPart("Part", sm, CFrame.new(0, P.ShY + 0.02, 0.02), V(2.34, 0.13, 1.54), gold, "Plate")
					newPart("Part", sm, CFrame.new(0, P.ShY - 1.0, 0.02), V(2.34, 0.13, 1.54), gold, "Plate")
				end
				auraNode(sm, "Core", c)
			end,
			head = function(sm)
				local c = V(0, P.NeckY + 0.3, -0.18)
				slab(sm, CFrame.new(c), V(0.9, 0.72, 0.86), stone, "Head")
				slab(sm, CFrame.new(c + V(0, 0.22, -0.42)), V(0.96, 0.18, 0.22), dark, "Head")
				newPart("Part", sm, CFrame.new(c + V(0, 0.03, -0.45)), V(0.56, 0.08, 0.05), glow, "Glow").Material = NEON
			end,
			upperArm = function(sm, a, b, sx)
				slab(sm, CFrame.new(a + V(sx * 0.14, 0.12, 0)), V(0.9, 0.62, 1.02), dark, "Arm")
				between(sm, a + V(0, -0.24, 0), b + V(0, 0.05, 0), 0.62, 0.68, stone, "Arm")
			end,
			foreArm = function(sm, a, b)
				between(sm, a + V(0, -0.05, 0), b + V(0, 0.05, 0), 0.72, 0.78, stone, "Arm")
			end,
			hand = function(sm, a, b, sx)
				slab(sm, CFrame.new((a + b) / 2 + V(0, -0.1, -0.04)), V(1.05, 0.98, 1.08), dark, "Hand")
				if o.Inlay then
					newPart("Part", sm, CFrame.new((a + b) / 2 + V(0, -0.1, -0.04)), V(1.11, 0.13, 1.14), o.Plate or rgb(204, 170, 86), "Plate")
				end
			end,
			thigh = function(sm, a, b)
				between(sm, a + V(0, -0.1, 0), b + V(0, 0.05, 0), 0.78, 0.88, stone, "Leg")
			end,
			shin = function(sm, a, b)
				between(sm, a + V(0, -0.05, 0), b + V(0, 0.02, 0), 0.7, 0.82, dark, "Leg")
			end,
			foot = function(sm, a, f)
				slab(sm, CFrame.new(f + V(0, 0.22, -0.12)), V(0.98, 0.42, 1.34), stone, "Foot")
			end,
		}
		return skeleton(m, P, set)
	end

	-- ================================================================= floaters (rig Hover)
	-- Wraith: a deep hood with only eyes inside, a flaring robe with a ragged hem, a spirit tail, long arms
	recipes.Wraith = function(m, o)
		local coat, hood = o.Coat or rgb(90, 110, 140), o.Hood or (o.Coat or rgb(90, 110, 140)):Lerp(Color3.new(0, 0, 0), 0.3)
		local glow, eyeC = o.Glow or rgb(255, 150, 60), o.EyeGlow or rgb(170, 225, 255)
		local robe = loft(m, { { V(0, 1.8, 0.05), 0.82, 0.8, 0.8 }, { V(0, 2.7, 0.03), 0.66, 0.62, 0.6 }, { V(0, 3.7, 0), 0.72, 0.52, 0.5 }, { V(0, 4.3, 0), 0.68, 0.48, 0.46 } }, function()
			return "Body", coat
		end)
		-- hood: a cowl with a dark hollow at the front and two eyes in it
		local hc = V(0, 4.75, -0.05)
		loft(m, { { hc + V(0, -0.42, 0.05), 0.5, 0.48, 0.48 }, { hc, 0.5, 0.5, 0.5 }, { hc + V(0, 0.42, 0.06), 0.3, 0.3, 0.3 } }, function()
			return "Body", hood
		end)
		local f = hc + V(0, -0.02, -0.455)
		T(m, "Eye", rgb(10, 10, 14), f + V(-0.3, 0.26, 0), f + V(0.3, 0.26, 0), f + V(0.3, -0.26, 0), 0.05)
		T(m, "Eye", rgb(10, 10, 14), f + V(-0.3, 0.26, 0), f + V(0.3, -0.26, 0), f + V(-0.3, -0.26, 0), 0.05)
		for _, sx in ipairs({ -1, 1 }) do
			local e = f + V(sx * 0.13, 0.05, -0.05)
			T(m, "Eye", eyeC, e + V(-sx * 0.06, 0.03, 0), e + V(sx * 0.07, 0.05, 0), e + V(0, -0.05, 0), 0.03, NEON)
		end
		-- ragged hem
		local tatter = o.Tatters or 0.6
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2 + 0.15
			local d = V(math.sin(a), 0, math.cos(a))
			local s = V(-d.Z, 0, d.X)
			local top = V(0, 1.95, 0.05) + d * 0.74
			T(m, "Body", coat:Lerp(hood, (i % 2) * 0.5), top + s * 0.36, top - s * 0.36, top + d * 0.14 + V(0, -(0.7 + tatter * 0.9 * rnd(i, 3)), 0), 0.05)
		end
		if o.Cracks then
			-- seams of fire in the robe
			for i = 1, #robe - 1 do
				local A, B = robe[i], robe[i + 1]
				local mid = midOf(A, B)
				for _, k in ipairs({ 1, 2, 4, 5 }) do
					local p, n = surf(A, B, k, 0.3 + rnd(i * k, 3) * 0.4, 0.3, mid)
					local q = surf(A, B, k, 0.25 + rnd(i * k, 4) * 0.5, 0.82, mid)
					local w = (q - p):Cross(n).Unit * 0.05
					T(m, "Glow", glow, p + n * 0.035 + w, p + n * 0.035 - w, q + n * 0.035, 0.03, NEON)
				end
			end
		end
		-- spirit tail: three segments tapering to a point
		local t0, t1, t2, t3 = V(0, 2.0, 0.08), V(0, 1.2, 0.3), V(0, 0.65, 0.75), V(0, 0.32, 1.45)
		chain(m, "Tail", "Hips", { t0, t1, t2 }, {
			function(sm) limb(sm, t0, t1, 0.66, 0.42, coat, "Tail", 5) end,
			function(sm) limb(sm, t1, t2, 0.42, 0.22, hood, "Tail", 4) end,
			function(sm)
				limb(sm, t2, t3, 0.22, 0.03, hood, "Tail", 4)
				auraNode(sm, "Tail", t3)
			end,
		})
		for _, sx in ipairs({ -1, 1 }) do
			local Sh, El, Wr = V(sx * 0.68, 4.15, 0), V(sx * 1.0, 3.2, -0.25), V(sx * 1.08, 2.4, -0.62)
			local tag = sx > 0 and "RA" or "LA"
			chain(m, tag, "Hips", { Sh, El, Wr }, {
				function(sm) limb(sm, Sh + V(0, 0.15, 0), El, 0.2, 0.13, coat, "Arm", 4) end,
				function(sm) limb(sm, El, Wr, 0.13, 0.08, hood, "Arm", 3) end,
				function(sm)
					for i = -1, 1 do
						local tip = Wr + V(i * 0.14, -0.62, -0.1 + math.abs(i) * 0.06)
						limb(sm, Wr, tip, 0.05, 0.012, o.Claw or rgb(30, 30, 38), "Hand", 3)
					end
					auraNode(sm, sx > 0 and "WingR" or "WingL", Wr)
				end,
			})
		end
		auraNode(m, "Core", V(0, 3.4, 0))
		m:SetAttribute("RootC", V(0, 3.2, 0))
		m:SetAttribute("RootS", V(1.2, 0.8, 1))
		m:SetAttribute("Height", 5.2)
		m:SetAttribute("Length", 2)
		m:SetAttribute("Stride", 4)
		m:SetAttribute("RigKind", "Hover")
		return V(1.6, 5.2, 1.6)
	end

	-- Wisp: a Neon core under a crown of flame tongues, with three trailing tendrils; particles do the rest
	recipes.Wisp = function(m, o)
		local glow = o.Glow or rgb(120, 220, 200)
		local shade = o.Shade or glow:Lerp(Color3.new(0, 0, 0), 0.35)
		local c = V(0, 2.6, 0)
		local core = newPart("Part", m, CFrame.new(c), V(1.3, 1.3, 1.3), glow, "Glow")
		core.Shape = Enum.PartType.Ball
		core.Material = NEON
		for i = 1, o.Crown or 5 do
			local a = i / (o.Crown or 5) * math.pi * 2
			local d = V(math.sin(a), 0, math.cos(a))
			local s = V(-d.Z, 0, d.X)
			local base = c + d * 0.42 + V(0, 0.42, 0)
			local h = 0.9 + rnd(i, 3) * 0.55
			T(m, "Crest", shade, base + s * 0.28, base - s * 0.28, base + d * 0.14 + V(0, h, 0), 0.05, NEON)
		end
		for t = 1, 3 do
			local a = t / 3 * math.pi * 2 + 0.5
			local d = V(math.sin(a), 0, math.cos(a))
			local p0 = c + d * 0.3 - V(0, 0.5, 0)
			local p1, p2, p3 = p0 + d * 0.28 - V(0, 0.6, 0), p0 + d * 0.15 - V(0, 1.2, 0) + V(0, 0, 0.2), p0 - d * 0.05 - V(0, 1.75, 0) + V(0, 0, 0.42)
			chain(m, t == 1 and "Tail" or (t == 2 and "TailB" or "TailC"), "Hips", { p0, p1, p2 }, {
				function(sm) limb(sm, p0, p1, 0.18, 0.13, shade, "Tail", 3, NEON) end,
				function(sm) limb(sm, p1, p2, 0.13, 0.08, shade, "Tail", 3, NEON) end,
				function(sm) limb(sm, p2, p3, 0.08, 0.02, shade, "Tail", 3, NEON) end,
			})
		end
		auraNode(m, "Core", c)
		m:SetAttribute("RootC", c)
		m:SetAttribute("RootS", V(1.3, 1.3, 1.3))
		m:SetAttribute("Height", 4.4)
		m:SetAttribute("Length", 2)
		m:SetAttribute("Stride", 4)
		m:SetAttribute("RigKind", "Hover")
		return V(1.6, 4.4, 1.6)
	end

	-- ================================================================= pose drivers
	-- arms during an attack, added to the walk. Strike (anim Bite): an overhead chop with the right arm;
	-- Swipe: a backhand across; Lunge: a thrust with a forward lean; Rear: both fists up, then down in front.
	local function armAttack(out, a)
		local k, u = a.Kind, a.T
		local RS, LS, lean, turn = 0, 0, 0, 0
		if k == "Rear" then
			local up = u < 0.55 and math.sin(u / 0.55 * math.pi / 2) or math.max(0, 1 - (u - 0.55) / 0.14)
			local hit = u >= 0.55 and math.max(0, 1 - (u - 0.69) / 0.31) or 0
			RS, LS = 2.9 * up + (u >= 0.55 and 0.75 * (1 - up) * hit or 0), 2.9 * up + (u >= 0.55 and 0.75 * (1 - up) * hit or 0)
			lean = 0.2 * up - 0.5 * (u >= 0.55 and (1 - up) * hit or 0)
		elseif k == "Lunge" then
			local r = math.sin(u * math.pi)
			RS, lean = 1.55 * r, -0.5 * r
			LS = -0.4 * r
		elseif k == "Swipe" then
			local up = u < 0.55 and math.sin(u / 0.55 * math.pi / 2) or math.max(0, 1 - (u - 0.55) / 0.3)
			RS = 1.5 * up
			turn = u < 0.55 and -0.6 * up or 0.8 * math.sin((u - 0.55) / 0.45 * math.pi)
		else
			local up = u < 0.45 and math.sin(u / 0.45 * math.pi / 2) or math.max(0, 1 - (u - 0.45) / 0.14)
			local rest = u >= 0.45 and math.max(0, 1 - (u - 0.59) / 0.41) or 0
			RS = 2.6 * up + 0.9 * (1 - up) * rest
			lean = 0.12 * up - 0.3 * (1 - up) * rest
		end
		return RS, LS, lean, turn
	end

	local function bipedAngles(state)
		local t, seed, walk = state.T or 0, state.Seed or 0, math.clamp(state.Amp or 0, 0, 1)
		local blend = state.Blend or 0
		local p = (state.Phase or 0) * math.pi * 2
		local s1, s2 = math.sin(p), math.sin(p + math.pi)
		local out = {}
		local stride = 0.62 * walk * (1 + 0.25 * blend)
		local function legs(tag, s, c)
			out[tag .. "1"] = CFrame.Angles(0.12 + stride * s, 0, 0)
			local lift = math.max(0, c) * walk
			out[tag .. "2"] = CFrame.Angles(-0.22 - 0.95 * lift, 0, 0)
			out[tag .. "3"] = CFrame.Angles(0.1 + 0.4 * lift * 0.5, 0, 0)
		end
		legs("RH", s1, math.cos(p))
		legs("LH", s2, -math.cos(p))
		local knuckle = state.Knuckle and blend or 0
		local RS, LS, lean, turn = 0, 0, 0, 0
		if state.Attack then
			RS, LS, lean, turn = armAttack(out, state.Attack)
		end
		local breathe = math.sin(t * 1.8 + seed) * 0.04 * (1 - walk)
		out.RA1 = CFrame.Angles(0.14 + stride * 0.75 * s2 + breathe + RS + knuckle * 1.0, 0, 0.08)
		out.LA1 = CFrame.Angles(0.14 + stride * 0.75 * s1 + breathe + LS + knuckle * 1.0, 0, -0.08)
		out.RA2 = CFrame.Angles(0.28 + walk * 0.2, 0, 0)
		out.LA2 = CFrame.Angles(0.28 + walk * 0.2, 0, 0)
		local bob = (math.cos(p * 2) * 0.5 + 0.5 - 0.5) * 0.09 * walk * (state.Size or 1)
		out.Hips = CFrame.new(0, bob + math.sin(t * 1.8 + seed) * 0.018 * (state.Size or 1) * (1 - walk), 0) * CFrame.Angles(0, math.sin(p) * 0.08 * walk, 0)
		-- apes carry a permanent stoop (Knuckle marks them); everyone leans a little into a walk
		out.Waist1 = CFrame.Angles(-0.07 * walk + lean - knuckle * 0.8 - (state.Knuckle and 0.26 or 0), -math.sin(p) * 0.14 * walk + turn, 0)
		local look = math.sin(t * 0.45 + seed * 3) * math.sin(t * 0.17 + seed)
		out.Head1 = CFrame.Angles(0.07 * walk - lean * 0.6 + knuckle * 0.65 + (state.Knuckle and 0.22 or 0), look * 0.5, 0)
		local tp = state.TailPhase or t
		for i = 1, 3 do
			out["Tail" .. i] = CFrame.Angles(math.sin(tp * 0.7 - i * 0.7 + seed) * 0.1, math.sin(tp - i * 0.75 + seed) * 0.18, 0)
		end
		return out
	end

	local function hoverAngles(state)
		local t, seed, walk = state.T or 0, state.Seed or 0, math.clamp(state.Amp or 0, 0, 1)
		local size = state.Size or 1
		local out = {}
		local RS, LS, lean, turn = 0, 0, 0, 0
		if state.Attack then
			RS, LS, lean, turn = armAttack(out, state.Attack)
		end
		-- a slow bob; leans into its travel, and the tail and tendrils sway in a wave
		out.Hips = CFrame.new(0, math.sin(t * 2.2 + seed) * 0.11 * size, 0) * CFrame.Angles(-0.22 * walk + lean, turn, math.sin(t * 0.9 + seed) * 0.04)
		local idle = math.sin(t * 1.3 + seed) * 0.1
		out.RA1 = CFrame.Angles(0.55 + idle + RS, 0, 0.12)
		out.LA1 = CFrame.Angles(0.55 - idle + LS, 0, -0.12)
		out.RA2 = CFrame.Angles(0.35 - idle * 0.5, 0, 0)
		out.LA2 = CFrame.Angles(0.35 + idle * 0.5, 0, 0)
		for _, tag in ipairs({ "Tail", "TailB", "TailC" }) do
			for i = 1, 3 do
				local w = t * 2 + seed - i * 0.9 + #tag
				out[tag .. i] = CFrame.Angles(math.cos(w * 0.7) * 0.14 - walk * 0.18 * i, math.sin(w) * 0.2, 0)
			end
		end
		return out
	end
	Creatures.drivers.Biped = bipedAngles
	Creatures.drivers.Hover = hoverAngles

	-- ================================================================= looks
	local fur = function(a, b)
		return { rgb(a[1], a[2], a[3]), rgb(b[1], b[2], b[3]) }
	end
	for id, look in pairs({
		-- Ashen Gorge and Frost Peak cats, dogs and bears
		AshHound = { "WolfBlock", { Coat = rgb(62, 56, 54), Dark = rgb(34, 30, 30), Light = rgb(112, 104, 98), Paw = rgb(44, 40, 40), Eye = rgb(255, 130, 50), Nose = rgb(24, 20, 20) } },
		SnowLeopard = { "Feline", { Coat = rgb(232, 232, 236), Back = rgb(206, 210, 218), Belly = rgb(250, 250, 252), Face = rgb(236, 236, 240), Muzzle = rgb(248, 248, 250), Paw = rgb(226, 226, 232), Pattern = "Rosettes", PatternColor = rgb(70, 76, 90), SpotCount = 2, EyeGlow = rgb(150, 220, 240), TailColor = rgb(214, 216, 224), TailTip = rgb(70, 76, 90) } },
		WhiteTiger = { "Feline", { Build = "Heavy", Coat = rgb(244, 244, 248), Back = rgb(232, 232, 240), Belly = rgb(255, 255, 255), Face = rgb(246, 246, 250), Muzzle = rgb(255, 255, 255), Paw = rgb(240, 240, 246), Pattern = "Stripes", PatternColor = rgb(32, 30, 40), StripeCount = 2, Teeth = 3, EyeGlow = rgb(120, 200, 255), TailColor = rgb(238, 238, 244), TailTip = rgb(32, 30, 40), Hair = fur({ 255, 255, 255 }, { 226, 228, 238 }), HairCount = 4, HairLen = 0.75, HairW = 0.16 } },
		JadePanda = { "Bear", { Pattern = "Panda", Coat = rgb(226, 242, 228), Back = rgb(226, 242, 228), Belly = rgb(236, 248, 238), Face = rgb(238, 248, 240), Muzzle = rgb(244, 250, 244), PatternColor = rgb(32, 92, 72), EarColor = rgb(32, 92, 72), Paw = rgb(32, 92, 72), Nose = rgb(22, 50, 40), EyeGlow = rgb(140, 255, 200), Claw = rgb(20, 40, 34) } },
		GlacierBear = { "Bear", { Coat = rgb(204, 222, 238), Back = rgb(160, 196, 226), Belly = rgb(226, 238, 248), Face = rgb(214, 230, 244), Muzzle = rgb(236, 244, 252), Paw = rgb(170, 200, 228), Claw = rgb(190, 235, 255), Nose = rgb(40, 54, 76), Teeth = 3, Hair = fur({ 240, 248, 255 }, { 176, 206, 232 }), HairCount = 7, HairLen = 1.3 } },
		BambooTyrant = { "Bear", { Hump = 1, Horns = true, HornColor = rgb(150, 190, 110), Coat = rgb(38, 42, 38), Back = rgb(28, 32, 30), Belly = rgb(60, 66, 56), Face = rgb(44, 48, 44), Muzzle = rgb(66, 72, 60), Paw = rgb(30, 34, 30), Claw = rgb(150, 190, 110), EyeGlow = rgb(150, 255, 110), Teeth = 4, Tusks = true, Hair = fur({ 56, 66, 50 }, { 34, 38, 34 }), HairCount = 10, HairLen = 1.7, HairW = 0.26, Scutes = { rgb(46, 74, 44), rgb(30, 46, 32) }, ScuteFacets = { 1, 6 }, ScuteAcross = 2, ScuteLen = 0.7 } },
		JadeTortoise = { "Shelled", { Shell = rgb(70, 160, 128), Scute = rgb(36, 104, 84), Skin = rgb(126, 150, 110), Plastron = rgb(190, 176, 118), ShellRim = rgb(255, 214, 110), EyeGlow = rgb(255, 214, 110) } },
		-- Reptiles and birds
		BambooViper = { "Serpent", { Coat = rgb(96, 164, 72), Belly = rgb(226, 222, 150), Bands = 6, Band = rgb(44, 96, 48), EyeGlow = rgb(240, 214, 80) } },
		MoonViper = { "Serpent", { Hood = true, Coat = rgb(52, 62, 120), Belly = rgb(176, 186, 220), Bands = 8, BandGlow = rgb(150, 200, 255), EyeGlow = rgb(160, 215, 255) } },
		MireSerpent = { "Serpent", { Crest = true, Girth = 1.6, Coat = rgb(58, 82, 58), Back = rgb(38, 56, 40), Belly = rgb(150, 150, 96), Fin = rgb(100, 106, 56), Scaled = true, EyeGlow = rgb(226, 230, 90) } },
		BogToad = { "Sprawler", { Build = "Toad", Coat = rgb(108, 128, 72), Back = rgb(84, 104, 58), Belly = rgb(202, 192, 120), Face = rgb(114, 134, 76), Paw = rgb(96, 116, 66), JawColor = rgb(172, 164, 104), Wart = rgb(72, 90, 50), Warts = true, Nose = rgb(60, 74, 44), EyeGlow = rgb(240, 214, 90) } },
		MarshCroc = { "Sprawler", { Build = "Croc", Coat = rgb(74, 94, 62), Back = rgb(50, 66, 46), Belly = rgb(190, 184, 138), Face = rgb(70, 90, 60), Paw = rgb(62, 80, 54), JawColor = rgb(170, 164, 122), Nose = rgb(38, 46, 34), EyeGlow = rgb(246, 180, 60) } },
		PearlCrane = { "Bird", { Wader = true, Coat = rgb(244, 244, 240), Back = rgb(226, 226, 222), Belly = rgb(252, 252, 250), WingTip = rgb(28, 28, 32), Beak = rgb(110, 190, 150), Leg = rgb(50, 54, 60), Crown = rgb(214, 48, 44), Primaries = 8 } },
		-- Apes
		StoneMonkey = { "Ape", { Build = "Monkey", Tail = true, Coat = rgb(132, 128, 118), Skin = rgb(92, 92, 92), Belly = rgb(158, 154, 142), Plates = nil } },
		MonkeyChief = { "Ape", { Build = "Ape", Tail = true, Crown = rgb(190, 150, 70), Glow = rgb(255, 214, 110), Coat = rgb(150, 118, 86), Skin = rgb(110, 84, 66), Belly = rgb(186, 156, 120), Fur = 5, Mane = fur({ 174, 142, 104 }, { 124, 94, 68 }) } },
		BogTroll = { "Ape", { Build = "Troll", Plates = rgb(80, 112, 66), Tusks = 1.2, Coat = rgb(84, 104, 72), Skin = rgb(112, 128, 92), Belly = rgb(120, 132, 94), EyeGlow = rgb(226, 230, 90) } },
		FrostYeti = { "Ape", { Build = "Yeti", Coat = rgb(222, 232, 242), Skin = rgb(110, 134, 160), Belly = rgb(236, 242, 248), Fur = 4, Mane = fur({ 250, 252, 255 }, { 196, 214, 232 }) } },
		GlacierApe = { "Ape", { Build = "Ape", Icicles = true, Coat = rgb(170, 200, 224), Skin = rgb(98, 130, 164), Belly = rgb(204, 226, 244), Glow = rgb(170, 230, 255), EyeGlow = rgb(170, 230, 255), Fur = 9, Mane = fur({ 214, 234, 250 }, { 138, 176, 208 }), Plates = rgb(150, 190, 222) } },
		-- People and bones
		Bandit = { "Warrior", { Outfit = "Bandit", Weapon = "Sword", Mask = true, Cloth = rgb(120, 90, 64), Cloth2 = rgb(74, 58, 46), Sash = rgb(150, 40, 36) } },
		BanditCaptain = { "Warrior", { Outfit = "Captain", Weapon = "Spear", Cloth = rgb(124, 58, 48), Cloth2 = rgb(66, 44, 40), Sash = rgb(190, 160, 90), Band = rgb(190, 160, 90), Trim = rgb(190, 160, 90) } },
		BanditWarlord = { "Warrior", { Outfit = "Warlord", Weapon = "Greatsword", Cloth = rgb(90, 30, 30), Cloth2 = rgb(50, 26, 26), Armor = rgb(128, 32, 32), Trim = rgb(196, 160, 86), Plume = rgb(220, 60, 50), Sash = rgb(196, 160, 86) } },
		Skeleton = { "Warrior", { Body = "Bone", Outfit = "Rags", Weapon = "Sword", Bone = rgb(226, 220, 196), EyeGlow = rgb(150, 240, 150), Blade = rgb(130, 120, 106) } },
		BloodSkeleton = { "Warrior", { Body = "Bone", Outfit = "Rags", Weapon = "Sword", Bone = rgb(170, 48, 46), Cloth = rgb(50, 22, 24), EyeGlow = rgb(255, 60, 50), Blade = rgb(120, 40, 40) } },
		BoneKnight = { "Warrior", { Body = "Bone", Outfit = "Knight", Weapon = "Sword", Bone = rgb(214, 208, 188), Armor = rgb(214, 208, 188), Trim = rgb(92, 96, 104), EyeGlow = rgb(150, 240, 200), NoHelm = true } },
		BoneKnightLord = { "Warrior", { Body = "Bone", Outfit = "Knight", Weapon = "Greatsword", Bone = rgb(190, 180, 158), Armor = rgb(170, 160, 138), Trim = rgb(70, 72, 80), Glow = rgb(255, 130, 50), EyeGlow = rgb(255, 130, 50), Plume = rgb(190, 60, 40) } },
		GodlySkeleton = { "Warrior", { Body = "Bone", Outfit = "Knight", Weapon = "Greatsword", Bone = rgb(166, 36, 36), Armor = rgb(110, 22, 24), Trim = rgb(240, 200, 120), Glow = rgb(255, 60, 60), EyeGlow = rgb(255, 80, 70), NoHelm = true, Blade = rgb(220, 60, 50) } },
		-- Floaters and stone
		Wraith = { "Wraith", { Coat = rgb(92, 112, 144), Tatters = 0.6, EyeGlow = rgb(170, 225, 255) } },
		CinderWraith = { "Wraith", { Coat = rgb(52, 46, 46), Cracks = true, Glow = rgb(255, 120, 40), EyeGlow = rgb(255, 150, 60) } },
		EmberWraith = { "Wraith", { Coat = rgb(62, 44, 40), Cracks = true, Glow = rgb(255, 150, 40), Tatters = 1, EyeGlow = rgb(255, 200, 80) } },
		MarshWisp = { "Wisp", { Glow = rgb(140, 240, 215), Crown = 5 } },
		IceWisp = { "Wisp", { Glow = rgb(170, 225, 255), Crown = 7 } },
		MossGolem = { "Golem", { Coat = rgb(112, 120, 100), MossCover = 0.8, Moss = rgb(92, 134, 72), Glow = rgb(120, 255, 170) } },
		RelicGolem = { "Golem", { Coat = rgb(196, 170, 118), Inlay = true, Plate = rgb(214, 176, 80), MossCover = 0.2, Moss = rgb(120, 140, 80), Glow = rgb(255, 214, 110) } },
		-- Small spirits
		SpiritFox = { "SmallBeast", { Coat = rgb(232, 138, 72), Back = rgb(214, 116, 58), Belly = rgb(250, 236, 214), Face = rgb(236, 146, 80), Muzzle = rgb(250, 240, 224), Paw = rgb(50, 36, 34), Leg = rgb(70, 48, 40), TailColor = rgb(232, 138, 72), TailTip = rgb(250, 244, 234), EarColor = rgb(214, 116, 58) } },
		SpiritRabbit = { "SmallBeast", { Build = "Rabbit", Coat = rgb(196, 240, 214), Back = rgb(172, 228, 196), Belly = rgb(236, 250, 240), Face = rgb(204, 244, 222), Muzzle = rgb(240, 252, 244), Paw = rgb(176, 230, 200), Nose = rgb(240, 150, 170), EarColor = rgb(172, 228, 196), EarInner = rgb(240, 190, 200), TailColor = rgb(250, 255, 252), EyeGlow = rgb(100, 230, 170) } },
		SpiritTurtle = { "Shelled", { Shell = rgb(96, 136, 80), Scute = rgb(66, 100, 56), Skin = rgb(146, 170, 112), Plastron = rgb(200, 190, 130) } },
		SpiritHawk = { "Bird", { Lite = true, Coat = rgb(84, 126, 210), Back = rgb(52, 84, 160), Belly = rgb(214, 224, 240), WingTip = rgb(236, 242, 252), EyeGlow = rgb(170, 225, 255), Primaries = 7, Hover = 0.4 } },
	}) do
		-- matte colours stop short of pure white: above this the game's bloom burns them out (Neon glow
		-- colours are left alone, they are meant to glow)
		local function matte(c)
			return rgb(math.min(c.R * 255, 236), math.min(c.G * 255, 238), math.min(c.B * 255, 242))
		end
		for key, v in pairs(look[2]) do
			if typeof(v) == "Color3" and key ~= "Glow" and key ~= "EyeGlow" and key ~= "BandGlow" and key ~= "ShellRim" then
				look[2][key] = matte(v)
			elseif type(v) == "table" and typeof(v[1]) == "Color3" then
				for i, c in ipairs(v) do
					v[i] = matte(c)
				end
			end
		end
		Looks[id] = look
	end
end
