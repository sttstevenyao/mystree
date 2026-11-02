	-- a muscle, rounded only in side view (user): flat outer and inner sides with a small wedge on each
	-- corner, so from the front it reads flat; the front and back edges carry the round profile.
	-- R = { { fraction from a to b, half width, front, back }, ... }; the first row is the top, kept
	-- nearly full width but very shallow front-to-back, so the top domes in side view only
	local function muscle(sm, a2, b2, R, col)
		local d = (b2 - a2).Unit
		local fwd = X:Cross(d).Unit
		if fwd.Z > 0 then
			fwd = -fwd
		end
		local rg = {}
		for _, r in ipairs(R) do
			local c, hw, f, b = a2:Lerp(b2, r[1]), r[2], r[3], r[4]
			table.insert(rg, {
				c + fwd * f, c + X * hw * 0.72 + fwd * f * 0.94, c + X * hw + fwd * f * 0.6, c + X * hw - fwd * b * 0.6,
				c + X * hw * 0.72 - fwd * b * 0.94, c - fwd * b, c - X * hw * 0.72 - fwd * b * 0.94, c - X * hw - fwd * b * 0.6,
				c - X * hw + fwd * f * 0.6, c - X * hw * 0.72 + fwd * f * 0.94,
			})
		end
		local paint = function()
			return "Leg", col
		end
		hull(sm, rg, paint)
		cap(sm, rg[1], a2 - d * 0.03, paint)
		cap(sm, rg[#rg], b2 + d * 0.05, paint)
	end
-- ReplicatedStorage/Mystree/Creatures (ModuleScript)
-- Part-built creatures (user's reference, 2026-10-27: a chunky deer made of chamfered blocks and
-- wedges, flat colours with white bands, dark nose, cupped ears). No meshes, no studs.
--
-- The kit:
--   Creatures.block(parent, cf, size, color, opts) - a box whose long edges are cut by wedges
--     (an octagon cross-section). opts.c = chamfer, opts.axis = "X" | "Y" | "Z" (the edges that are
--     cut run along this axis, default "Z"), opts.edges = "all" | "top" | "bottom" | "none".
--   Creatures.plate(parent, cf, size, color, opts) - a plain box (bands, eyes, inner ears).
-- Seams: the inner box of a chamfered block is 0.04 shorter than the outer one, so no two faces of a
-- block are ever coplanar (Playbook z-fighting rule); details sit at least 0.02 proud.
--
-- Recipes build at a fixed design scale, ground at y = 0, facing -Z; Creatures.build(kind, opts)
-- returns a Model with an invisible upright "Root" (PrimaryPart). Callers rescale with Model:ScaleTo.

local Creatures = {}

local SMOOTH = Enum.Material.SmoothPlastic

local function newPart(class, parent, cf, size, color, name)
	local p = Instance.new(class)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = SMOOTH
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Name = name or "Part"
	p.Parent = parent
	return p
end

function Creatures.plate(parent, cf, size, color, opts)
	opts = opts or {}
	local p = newPart("Part", parent, cf, size, color, opts.name)
	if opts.material then
		p.Material = opts.material
	end
	return p
end

-- frame whose local Z runs along the chosen axis of cf, plus the size in that frame
local function alongZ(cf, size, axis)
	if axis == "Y" then
		return cf * CFrame.Angles(-math.pi / 2, 0, 0), Vector3.new(size.X, size.Z, size.Y)
	elseif axis == "X" then
		return cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(size.Z, size.Y, size.X)
	end
	return cf, size
end

function Creatures.block(parent, cf, size, color, opts)
	opts = opts or {}
	local name = opts.name or "Block"
	local edges = opts.edges or "all"
	local F, S = alongZ(cf, size, opts.axis or "Z")
	local W, H, L = S.X, S.Y, S.Z
	local c = math.min(opts.c or math.min(W, H) * 0.2, W / 2 - 0.02, H / 2 - 0.02)
	local top = edges == "all" or edges == "top"
	local bottom = edges == "all" or edges == "bottom"
	local parts = {}
	if edges == "none" or c < 0.03 then
		table.insert(parts, newPart("Part", parent, cf, size, color, name))
		return parts
	end
	-- narrow full-height core and a wide core that stops short of the cut edges (0.04 shorter)
	local hWide = H - (top and c or 0) - (bottom and c or 0)
	local yWide = ((bottom and c or 0) - (top and c or 0)) / 2
	table.insert(parts, newPart("Part", parent, F, Vector3.new(W - 2 * c, H, L), color, name))
	table.insert(parts, newPart("Part", parent, F * CFrame.new(0, yWide, 0), Vector3.new(W, hWide, L - 0.04), color, name))
	for _, sy in ipairs({ 1, -1 }) do
		if (sy > 0 and top) or (sy < 0 and bottom) then
			for _, sx in ipairs({ 1, -1 }) do
				-- a wedge whose right angle sits at (vx, vy) with legs lx along +sx X and ly along +sy Y
				local function wedge(vx, vy, lx, ly)
					local pos = Vector3.new(sx * (vx + lx / 2), sy * (vy + ly / 2), 0)
					local wcf = F * CFrame.fromMatrix(pos, Vector3.new(0, 0, sx * sy), Vector3.new(0, sy, 0), Vector3.new(-sx, 0, 0))
					table.insert(parts, newPart("WedgePart", parent, wcf, Vector3.new(L, ly, lx), color, name))
				end
				local x0, y0 = W / 2 - c, H / 2 - c
				if opts.round then
					-- two facets per corner (a 12-sided cross-section): a filler box and two wedges
					local d = c * (1 - math.cos(math.pi / 4))
					local e = c - d
					table.insert(parts, newPart("Part", parent, F * CFrame.new(sx * (x0 + e / 2), sy * (y0 + e / 2), 0), Vector3.new(e, e, L - 0.02), color, name))
					wedge(x0 + e, y0, d, e)
					wedge(x0, y0 + e, e, d)
				else
					wedge(x0, y0, c, c)
				end
			end
		end
	end
	if opts.material then
		for _, p in ipairs(parts) do
			p.Material = opts.material
		end
	end
	return parts
end

-- a chamfered rod from a to b (thickness t), with a knuckle cube at a so chains have no gaps
function Creatures.rod(parent, a, b, t, color, opts)
	opts = opts or {}
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b, opts.up or Vector3.new(0, 1, 0))
	local parts = Creatures.block(parent, cf, Vector3.new(t, t, len + t * 0.6), color, { c = t * 0.28, name = opts.name, material = opts.material })
	return parts
end

-- a pointed tip: two crossed pairs of mirrored wedges narrowing to the end (base thickness t)
function Creatures.spike(parent, base, dir, t, len, color, name)
	local F = CFrame.lookAt(base, base + dir)
	local parts = {}
	for _, roll in ipairs({ 0, math.pi / 2 }) do
		for _, flip in ipairs({ 0, math.pi }) do
			local cf = F * CFrame.Angles(0, 0, roll + flip) * CFrame.new(0, t / 4, -len / 2)
			table.insert(parts, newPart("WedgePart", parent, cf, Vector3.new(t, t / 2, len), color, name))
		end
	end
	return parts
end

-- a tapering stick from a to b (thickness t0 -> t1) in two pieces with a knuckle between;
-- tip = "spike" ends it in a point, otherwise it ends flat (a crystal cap goes there)
function Creatures.stick(parent, a, b, t0, t1, color, opts)
	opts = opts or {}
	local name = opts.name or "Stick"
	local mid = a:Lerp(b, 0.55)
	local tm = (t0 + t1) / 2
	Creatures.rod(parent, a, mid, t0, color, { name = name })
	Creatures.plate(parent, CFrame.lookAt(mid, b), Vector3.new(tm, tm, tm), color, { name = name })
	if opts.tip == "spike" then
		local d = (b - mid)
		local stem = mid + d * 0.45
		Creatures.rod(parent, mid, stem, tm, color, { name = name })
		Creatures.spike(parent, stem - d.Unit * tm * 0.2, d, tm, d.Magnitude * 0.55 + tm * 0.2, color, name)
	else
		Creatures.rod(parent, mid, b, t1, color, { name = name })
	end
end

local block, plate, rod = Creatures.block, Creatures.plate, Creatures.rod
local stick = Creatures.stick

-- ===================================================================== sculpt kit (smooth low poly)
-- The user wants smooth low-poly animals, not blocks: shapes are faceted surfaces made of triangle
-- plates, each triangle drawn exactly by two WedgeParts (EgoMoose's method, ported from the
-- CreaturePens SculptKit). hull() lofts a solid through rings of points; ring() makes a rounded
-- (superellipse) ring; cap() closes an end to a point.
local X = Vector3.xAxis
local function triFrames(a, b, c, thick)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return nil
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.max(0.01, math.abs(ab:Dot(up)))
	return Vector3.new(thick, height, math.max(0.01, math.abs(ab:Dot(back)))), CFrame.fromMatrix((a + b) / 2, right, up, back),
		Vector3.new(thick, height, math.max(0.01, math.abs(ac:Dot(back)))), CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

-- out (optional): the surface's outward normal. The plate is then pushed inward by half its
-- thickness, so its outer face lies exactly on the triangle: neighbouring facets meet at their shared
-- edge with no crack, and overlap behind it. Without `out` the plate is centred (two-sided leaves).
local function T(parent, name, col, a, b, c, thick, material, out)
	thick = thick or 0.04
	local s1, c1, s2, c2 = triFrames(a, b, c, thick)
	if not s1 then
		return
	end
	if out then
		c1 = c1 - out * thick / 2
		c2 = c2 - out * thick / 2
	end
	local p = newPart("WedgePart", parent, c1, s1, col, name)
	local q = newPart("WedgePart", parent, c2, s2, col, name)
	if Creatures.Record then
		-- the 3D draft export (tools/dev/creature_export.lua) reads each triangle back from its first half
		p:SetAttribute("TriA", a)
		p:SetAttribute("TriB", b)
		p:SetAttribute("TriC", c)
		q:SetAttribute("PlateHalf", true)
	end
	if material then
		p.Material = material
		q.Material = material
	end
	return p, q
end
Creatures.tri = T

local function sp(v, e)
	return math.sign(v) * math.abs(v) ^ e
end
-- n points round c: hw along `side`, `top` along u and `bot` against it (a superellipse: e = 0.8
-- is rounded; lower is boxier, pushing the points out toward the corners)
local function ring(c, side, u, hw, top, bot, n, e)
	e = e or 0.8
	local pts = {}
	for j = 0, n - 1 do
		local a = j / n * math.pi * 2
		local s, co = math.sin(a), math.cos(a)
		table.insert(pts, c + side * hw * sp(s, e) + u * (co > 0 and top or bot) * sp(co, e))
	end
	return pts
end
Creatures.ring = ring

-- a leg section: flat sides (hw out along `side`), shaped only at the front and back edges, which
-- are cut to a blunt point (a 6-sided section, like the references' legs)
local function slab(c, side, u, hw, top, bot)
	return {
		c + u * top, c + side * hw + u * top * 0.45, c + side * hw - u * bot * 0.45,
		c - u * bot, c - side * hw - u * bot * 0.45, c - side * hw + u * top * 0.45,
	}
end
Creatures.slab = slab

-- loft through rings; paint(centre, outward normal, ring index) -> name, colour
-- body and neck sections are 6-sided (user, 2026-10-27: "decrease the poly even more"); a 6-point
-- ring's flat sides sit at 0.89 of its half width, so widths are scaled up to keep the bulk
-- and boxy (user: "slightly more blocky"): flat tops and sides with angled corner facets
local BODY_SIDES, BODY_W, BOX = 6, 1.04, 0.55
local SKIN = 0.1 -- plate thickness for solid surfaces (thick enough to close every seam from inside)
local function hull(parent, rings, paint, thick)
	for i = 1, #rings - 1 do
		local A, B = rings[i], rings[i + 1]
		local n = #A
		local mid = Vector3.zero
		for k = 1, n do
			mid += A[k] + B[k]
		end
		mid /= 2 * n
		for k = 1, n do
			local k2 = k % n + 1
			for _, t in ipairs({ { A[k], A[k2], B[k2] }, { A[k], B[k2], B[k] } }) do
				local nrm = (t[2] - t[1]):Cross(t[3] - t[1])
				if nrm.Magnitude > 1e-6 then
					local cen = (t[1] + t[2] + t[3]) / 3
					nrm = nrm.Unit
					if nrm:Dot(cen - mid) < 0 then
						nrm = -nrm
					end
					local name, col, mat = paint(cen, nrm, i) -- (a paint may return a material: Neon glow)
					T(parent, name, col, t[1], t[2], t[3], thick or SKIN, mat, nrm)
				end
			end
		end
	end
end
-- inside (optional): a point inside the solid; the cap faces away from it. Needed for flat caps
-- (hoof soles), where the apex lies in the ring's own plane and gives no direction.
local function cap(parent, rg, apex, paint, thick, inside)
	local mid = Vector3.zero
	for _, p in ipairs(rg) do
		mid += p
	end
	mid /= #rg
	for k = 1, #rg do
		local a, b = rg[k], rg[k % #rg + 1]
		local cen = (a + b + apex) / 3
		local nrm = (b - a):Cross(apex - a)
		nrm = nrm.Magnitude > 1e-6 and nrm.Unit or (apex - mid).Unit
		if inside then
			if nrm:Dot(cen - inside) < 0 then
				nrm = -nrm
			end
		elseif nrm:Dot(apex - mid) < 0 then
			nrm = -nrm
		end
		local name, col, mat = paint(cen, nrm, 0)
		T(parent, name, col, a, b, apex, thick or SKIN, mat, nrm)
	end
end
Creatures.hull, Creatures.cap = hull, cap

-- a tapering faceted tube through points (antlers, tails): radii per point, pointed end
local function tube(parent, pts, radii, name, col, sides, material)
	local rings = {}
	for i, p in ipairs(pts) do
		local d = (pts[math.min(i + 1, #pts)] - pts[math.max(i - 1, 1)]).Unit
		local side = d:Cross(math.abs(d.Y) < 0.95 and Vector3.yAxis or X).Unit
		local u = side:Cross(d).Unit
		table.insert(rings, ring(p, side, u, radii[i], radii[i], radii[i], sides or 5))
	end
	local paint = function()
		return name, col
	end
	hull(parent, rings, paint, 0.04)
	local dEnd = (pts[#pts] - pts[#pts - 1]).Unit
	cap(parent, rings[#rings], pts[#pts] + dEnd * radii[#radii] * 2.2, paint, 0.04)
	cap(parent, rings[1], pts[1] - (pts[2] - pts[1]).Unit * radii[1] * 0.5, paint, 0.04)
	if material then
		for _, p in ipairs(parent:GetChildren()) do
			if p:IsA("BasePart") and p.Name == name then
				p.Material = material
			end
		end
	end
end
Creatures.tube = tube

-- ===================================================================== legs (shared by every quadruped)
-- A leg is a Model "LegFront" / "LegBack" (attribute Side = +-1) of four bones "Seg1".."Seg4", each a
-- sub-model whose first part holds an Attachment "Joint" at the joint it swings from (Creatures.rig
-- makes the Motor6Ds). A bone is a loft of flat-sided `slab` rings through pts (widths {hw, front,
-- back}); its top ring sits a little above its joint, inside the bone above, so bending never opens a
-- gap. A bone whose last colour is `hoofCol` ends in a flat sole on the ground.
local function bone(sm, pts, wd, cols, hoofCol)
	local rgs = {}
	local sole = hoofCol ~= nil and cols[#cols] == hoofCol
	for i, p in ipairs(pts) do
		local d = (pts[math.min(i + 1, #pts)] - pts[math.max(i - 1, 1)]).Unit
		if sole and i == #pts then
			d = -Vector3.yAxis -- the hoof's last ring lies flat on the ground
		end
		local u = d:Cross(X).Unit -- forward / back of the leg
		table.insert(rgs, slab(p, X, u, wd[i][1], wd[i][2], wd[i][3] or wd[i][2]))
	end
	local function nameOf(col)
		return (hoofCol ~= nil and col == hoofCol) and "Hoof" or "Leg"
	end
	for i = 1, #rgs - 1 do
		hull(sm, { rgs[i], rgs[i + 1] }, function()
			return nameOf(cols[i]), cols[i]
		end)
	end
	local d0 = (pts[2] - pts[1]).Unit
	local dn = (pts[#pts] - pts[#pts - 1]).Unit
	cap(sm, rgs[1], pts[1] - d0 * 0.12, function()
		return "Leg", cols[1]
	end)
	cap(sm, rgs[#rgs], sole and pts[#pts] or (pts[#pts] + dn * 0.06), function() -- a flat sole on hooves
		return nameOf(cols[#cols]), cols[#cols]
	end, nil, pts[#pts - 1])
end
Creatures.bone = bone

-- bones = { { pts, widths, colours, extra = function(segModel) (optional, e.g. a paw) }, ... } x4
local function legModel(m, name, sx, J, bones, hoofCol)
	local lm = Instance.new("Model")
	lm.Name = name
	lm:SetAttribute("Side", sx)
	for i, spec in ipairs(bones) do
		local sm = Instance.new("Model")
		sm.Name = "Seg" .. i
		bone(sm, spec[1], spec[2], spec[3], hoofCol)
		if spec.extra then
			spec.extra(sm)
		end
		local first = sm:FindFirstChildWhichIsA("BasePart")
		local att = Instance.new("Attachment")
		att.Name = "Joint"
		att.Parent = first -- parent first: WorldCFrame is relative to the part it sits on
		att.WorldCFrame = CFrame.new(J[i])
		sm.Parent = lm
	end
	lm.Parent = m
end
Creatures.legModel = legModel

-- an eye: a dark diamond plate (0.07 thick, centred 0.005 out so its back is sunk into the face)
-- with a glint; c on the surface, nrm its outward normal, up / fw half-size vectors in that plane
local function eye(m, c, nrm, up, fw, col, glow)
	local e = c + nrm * 0.005
	local mat = glow and Enum.Material.Neon or nil
	T(m, "Eye", col, e + up, e + fw, e - up, 0.07, mat)
	T(m, "Eye", col, e + up, e - up, e - fw * 0.8, 0.07, mat)
	if not glow then
		local g = c + nrm * 0.04 + up * 0.35 + fw * 0.1
		T(m, "Eye", Color3.fromRGB(250, 250, 250), g + up.Unit * up.Magnitude * 0.33, g + fw.Unit * 0.04, g - up.Unit * up.Magnitude * 0.25, 0.04)
	end
end
Creatures.eye = eye

-- a fur tuft: a 3-faced pyramid, wide along `tangent` (w each way), rooted at base (keep base inside
-- the body) and pointing along dir; `depth` (a vector) sets its back corner, giving it thickness.
-- Reads as a broad faceted lock of fur (wolf ruffs, manes).
local function tuft(m, base, dir, tangent, len, w, name, col, depth)
	local inner = base + (depth or dir:Cross(tangent).Unit * 0.14)
	local a, b = base + tangent * w, base - tangent * w
	local tip = base + dir * len
	local mid = (a + b + inner) / 3
	for _, f in ipairs({ { a, b, tip }, { b, inner, tip }, { inner, a, tip } }) do
		local cen = (f[1] + f[2] + f[3]) / 3
		local n = (f[2] - f[1]):Cross(f[3] - f[1])
		n = n.Magnitude > 1e-6 and n.Unit or dir
		if n:Dot(cen - mid) < 0 then
			n = -n
		end
		T(m, name, col, f[1], f[2], f[3], 0.06, nil, n)
	end
end
Creatures.tuft = tuft

-- a stable 0..1 number per index, so a creature's random-looking details rebuild the same every time
local function rnd(i, salt)
	return (math.sin(i * 12.9898 + salt * 78.233) * 43758.5453) % 1
end

-- A hair strand (Raise a Zoo's manes): a flat ribbon through 4 points in 3 hinged segments, swayed by
-- Creatures.pose. Model "Strand", attribute On = "Neck" | "Head" | "Hips" | "Tail" (what it hangs on);
-- parts S1..S3, the first of each holding an Attachment "Joint" at its hinge.
local function strand(m, on, pts, tangent, w0, col)
	local sm = Instance.new("Model")
	sm.Name = "Strand"
	sm:SetAttribute("On", on)
	local widths = { w0 * 0.8, w0, w0 * 0.72, 0 }
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local wa, wb = tangent * widths[i], tangent * widths[i + 1]
		local name = "S" .. i
		local first = T(sm, name, col, a + wa, a - wa, b - wb, 0.04)
		if wb.Magnitude > 0 then
			T(sm, name, col, a + wa, b - wb, b + wb, 0.04)
		end
		if first then
			local att = Instance.new("Attachment")
			att.Name = "Joint"
			att.Parent = first
			att.WorldCFrame = CFrame.new(a)
		end
	end
	sm.Parent = m
end
Creatures.strand = strand

-- One overlapping scale at c: a shallow keeled diamond, its base close to the skin and its tip lifted
-- and pointing along `tip`. Lifts differ from row to row, so overlapping scales are never coplanar.
local function scale(m, name, col, c, tip, n, w, len, lift)
	local side = n:Cross(tip).Unit
	local base, point = c - tip * len * 0.45 + n * lift, c + tip * len * 0.55 + n * (lift + 0.05)
	local mid = c + n * (lift + 0.015)
	T(m, name, col, base, mid + side * w, point, 0.04, nil, n)
	T(m, name, col, base, point, mid - side * w, 0.04, nil, n)
end

-- scales over one quad strip of a hull: facet k of rings[i..i+1], from f0 to f1 across the facet (0 =
-- ring point k, 1 = the next), in staggered rows. Follows the hull's exact two triangles per quad.
-- pick(index) -> colour; toward = +1 tips point along the rings' order, -1 against it; keep(n) may
-- refuse a facet by its normal
local function scaleStrip(m, name, rings, k, f0, f1, across, len, toward, pick, keep)
	local k2 = k % #rings[1] + 1
	local rowsDone = 0
	for i = 1, #rings - 1 do
		local A, B = rings[i], rings[i + 1]
		local mid = Vector3.zero
		for j = 1, #A do
			mid += A[j] + B[j]
		end
		mid /= 2 * #A
		local rows = math.max(1, math.floor(((A[k] + A[k2]) / 2 - (B[k] + B[k2]) / 2).Magnitude / (len * 0.5) + 0.5))
		for r = 1, rows do
			rowsDone += 1
			local g = (r - 0.5) / rows
			local stagger = (rowsDone % 2) * 0.5
			for a = 0, across - 1 do
				local f = (a + 0.25 + stagger) / across
				local u = f0 + (f1 - f0) * f
				local p, n
				if u >= g then
					p = A[k] + (A[k2] - A[k]) * (u - g) + (B[k2] - A[k]) * g
					n = (A[k2] - A[k]):Cross(B[k2] - A[k])
				else
					p = A[k] + (B[k2] - A[k]) * u + (B[k] - A[k]) * (g - u)
					n = (B[k2] - A[k]):Cross(B[k] - A[k])
				end
				n = n.Unit
				local axis = ((B[k] + B[k2]) - (A[k] + A[k2])).Unit * toward
				if n:Dot(p - mid) < 0 then
					n = -n
				end
				if not keep or keep(n) then
					local tip = (axis - n * axis:Dot(n)).Unit
					local width = (A[k2] - A[k]):Lerp(B[k2] - B[k], g).Magnitude * math.abs(f1 - f0) / across * 0.5
					scale(m, name, pick(rowsDone * 7 + a), p, tip, n, width, len, 0.025 + (rowsDone % 3) * 0.006)
				end
			end
		end
	end
end


-- ===================================================================== recipes
local recipes = {}

-- Deer (doe / stag / elk), sculpted from triangle plates. Design scale: withers ~3.9, nose to tail
-- ~6.3, ground at y = 0, facing -Z. Proportions from the references: deep chest, tucked belly,
-- thick neck, big head and ears, thick legs with rounded tops built on the real joints.
-- opts: Coat, Mane (neck, head, shoulders), Face (head), White, Dark (nose), Shin, Hoof,
--   Antlers ("Branched" | "Swept" | nil), AntlerColor, Glow (crystal tips instead of points), Moon
--   (forehead mark), Scales (3 jade colours), Hair (2 mane colours: swaying mane, forelock, tail plume,
--   fetlock fur), Dragon (longer muzzle with brow ridges, whiskers and a chin beard)
recipes.Deer = function(m, o)
	local coat = o.Coat or Color3.fromRGB(150, 92, 56)
	local mane = o.Mane or coat
	local face = o.Face or mane
	local white = o.White or Color3.fromRGB(238, 234, 228)
	local dark = o.Dark or Color3.fromRGB(52, 48, 50)
	local shin = o.Shin or coat:Lerp(dark, 0.12)
	local hoof = o.Hoof or dark:Lerp(coat, 0.25)
	local Y = Vector3.yAxis
	local V = Vector3.new
	-- Blocky (user, to match the wolf and boar): 8-point sections with a very low exponent are boxes
	-- with small corner bevels; the head is a skull box stepping down to a muzzle box
	local blocky = o.Blocky
	local box = blocky and 0.18 or BOX
	local sides = blocky and 8 or BODY_SIDES
	local hsides = blocky and 8 or 6

	-- built 1:1 from the approved template (CHO/art/blueprints/deer_spec.json, drawn on the "Mystree
	-- Deer Template" canvas): H = withers 3.75, legs to the chest floor 0.55 H (1.2x the body's depth),
	-- body 1.7 deep and 3.7 long, a short thick neck, head 1.55 long (0.42 of the body).
	-- head: from the back of the skull (poll) down to the nose
	local poll, nose = V(0, 4.75, -2.15), V(0, 4.2, -3.6)
	local D = (nose - poll).Unit
	local U = X:Cross(D).Unit
	local hl = (nose - poll).Magnitude

	-- torso: rings from the point of the chest back to the buttock (z, centre y, half width, top, bottom)
	local TORSO = {
		{ -1.85, 2.9, 0.3, 0.45, 0.5 }, { -1.6, 2.92, 0.6, 0.76, 0.86 }, { -1.0, 2.95, 0.72, 0.8, 0.9 },
		{ 1.0, 3.02, 0.69, 0.7, 0.76 }, { 1.55, 3.0, 0.58, 0.62, 0.66 }, { 1.85, 2.95, 0.3, 0.36, 0.42 },
	}
	local rings = {}
	for _, r in ipairs(TORSO) do
		table.insert(rings, ring(V(0, r[2], r[1]), X, Y, r[3] * BODY_W, r[4], r[5], sides, box))
	end
	local function torsoPaint(c, n)
		if n.Y < -0.6 and c.Z > -1.3 and c.Z < 1.3 then
			return "Body", white -- belly
		end
		if c.Z < -1.62 and n.Z < -0.5 and c.Y < 3.0 and not o.Antlers then
			return "Body", white -- chest bib (does)
		end
		if c.Z > 1.62 and n.Z > 0.55 and math.abs(c.X) < 0.34 and c.Y < 3.25 then
			return "Body", white -- rump patch
		end
		if c.Z < -0.9 then
			return "Body", mane
		end
		return "Body", coat
	end
	hull(m, rings, torsoPaint)
	cap(m, rings[1], V(0, 2.85, -1.95), torsoPaint)
	cap(m, rings[#rings], V(0, 2.95, 1.96), torsoPaint)
	if o.Scales then
		-- back and flanks, leaving the belly bare: from behind the chest to the rump
		local pick = function(i)
			return o.Scales[math.floor(rnd(i, 3) * #o.Scales) + 1]
		end
		local band = { rings[2], rings[3], rings[4], rings[5] }
		scaleStrip(m, "Body", band, 1, 0, 1, 2, 0.5, 1, pick)
		scaleStrip(m, "Body", band, 6, 0, 1, 2, 0.5, 1, pick)
		scaleStrip(m, "Body", band, 2, 0, 0.72, 2, 0.5, 1, pick)
		scaleStrip(m, "Body", band, 5, 0.28, 1, 2, 0.5, 1, pick)
	end

	-- neck: rings along a curve from inside the chest up into the head; top = throat side (front)
	local NECK = { { V(0, 3.3, -1.25), 0.55, 0.6, 0.6 }, { V(0, 4.0, -1.75), 0.46, 0.52, 0.44 },
		{ poll + D * hl * 0.28 - U * 0.08, 0.3, 0.3, 0.28 } } -- ends well inside the skull
	if blocky then
		-- one straight block from inside the chest into the skull (user: "the neck is too segmented");
		-- its end is narrower than the skull so it tucks inside
		NECK = { { V(0, 3.25, -1.2), 0.5, 0.56, 0.56 }, { poll + D * hl * 0.24 - U * 0.08, 0.33, 0.3, 0.28 } }
	end
	rings = {}
	for i, r in ipairs(NECK) do
		local d = (NECK[math.min(i + 1, #NECK)][1] - NECK[math.max(i - 1, 1)][1]).Unit
		table.insert(rings, ring(r[1], X, d:Cross(X).Unit, r[2], r[3], r[4], hsides, box))
	end
	hull(m, rings, function(c, n)
		if not o.Antlers and n.Z < -0.55 and n.Y < 0.5 then
			return "Neck", white:Lerp(mane, 0.2) -- pale throat (does)
		end
		return "Neck", mane
	end)
	cap(m, rings[1], NECK[1][1] + V(0, -0.2, 0.25), function()
		return "Neck", mane
	end)
	cap(m, rings[#rings], NECK[#NECK][1] + V(0, 0.1, -0.15), function()
		return "Neck", mane
	end)
	if o.Scales then
		local pick = function(i)
			return o.Scales[math.floor(rnd(i, 5) * #o.Scales) + 1]
		end
		-- tips point down the neck; the pale throat stays bare
		local notThroat = function(n)
			return not (n.Z < -0.45 and n.Y < 0.5)
		end
		for k = 1, #rings[1] do
			scaleStrip(m, "Neck", rings, k, 0, 1, 2, 0.42, -1, pick, notThroat)
		end
	end
	if o.Hair then
		-- the mane: strands down both sides from the crest (the point of each neck ring opposite the
		-- throat), each with its own length, angle and curl so that no two lie in one plane
		local back = hsides // 2 + 1
		local crest = { rings[1][back], rings[2][back], rings[#rings][back] }
		for _, sx in ipairs({ -1, 1 }) do
			for i = 1, 8 do
				local t = (i - 0.5 + (sx > 0 and 0.5 or 0)) / 8.5
				local at = t < 0.5 and crest[1]:Lerp(crest[2], t * 2) or crest[2]:Lerp(crest[3], t * 2 - 1)
				local seedA, seedB = rnd(i * sx + 40, 1), rnd(i * sx + 40, 2)
				local L = (1.5 + seedA * 0.6) / 3
				local dir = (V(sx * (0.45 + seedB * 0.25), -1, 0.28 + seedA * 0.3)).Unit
				local p = at - dir * 0.06
				local pts = { p }
				for s = 1, 3 do
					p += (dir + V(sx * math.sin(s * 1.7 + i) * 0.2, 0, math.cos(s * 1.3 + i) * 0.22)).Unit * L
					table.insert(pts, p)
				end
				local tangent = (V(sx * (seedB - 0.5) * 0.5, 0.45, 0.85)).Unit
				strand(m, "Neck", pts, tangent, 0.2 + seedB * 0.06, o.Hair[(i % 2) + 1])
			end
		end
	end

	-- head: rings along its axis D from the back of the skull to the nose; u = up the face
	local HEAD = { { 0, 0.34, 0.36, 0.36 }, { 0.15, 0.5, 0.46, 0.5 }, { 0.42, 0.44, 0.4, 0.44 }, { 0.7, 0.32, 0.31, 0.33 },
		{ 0.9, 0.26, 0.26, 0.27 }, { 1.0, 0.2, 0.2, 0.21 } }
	if o.Dragon then
		-- narrower behind the eyes, then a broad muzzle: a dragon's head, not a deer's
		HEAD = { { 0, 0.34, 0.36, 0.36 }, { 0.15, 0.5, 0.48, 0.5 }, { 0.42, 0.42, 0.42, 0.4 }, { 0.62, 0.27, 0.28, 0.3 },
			{ 0.86, 0.31, 0.29, 0.29 }, { 1.0, 0.23, 0.21, 0.22 } }
	end
	if blocky then
		-- skull box, then the muzzle box in three sections so its colours follow whole faces:
		-- plain, plain, then the white band right behind the dark nose on the front
		HEAD = { { 0, 0.42, 0.42, 0.4 }, { 0.42, 0.44, 0.44, 0.38 }, { 0.46, 0.3, 0.28, 0.3 }, { 0.7, 0.28, 0.26, 0.28 },
			{ 0.86, 0.265, 0.245, 0.26 }, { 1.0, 0.25, 0.23, 0.24 } }
	end
	-- the head's half width and top height at fraction t (between rings), and where the 6-point
	-- ring's flat side face and its top ridge actually sit (details are placed 0.03 proud of these)
	local function headAt(t)
		for i = 1, #HEAD - 1 do
			local a, b = HEAD[i], HEAD[i + 1]
			if t <= b[1] then
				local f = (t - a[1]) / (b[1] - a[1])
				return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
			end
		end
		return HEAD[#HEAD][2], HEAD[#HEAD][3]
	end
	-- x and height of the ring point next to the top one, as shares of hw and top
	local nextA = math.pi * 2 / hsides
	local SIDE = sp(math.sin(nextA), box)
	local RISE = sp(math.cos(nextA), box)
	rings = {}
	for _, r in ipairs(HEAD) do
		table.insert(rings, ring(poll + D * hl * r[1], X, U, r[2], r[3], r[4], hsides, box))
	end
	local function headPaint(c, n, seg)
		local t = (c - poll):Dot(D) / hl
		local up = n:Dot(U)
		if blocky then
			-- by whole section (no zigzag across a face): chin white under the muzzle, the band white,
			-- the front cap a dark nose
			if seg == 0 then
				return t > 0.9 and "Nose" or "Head", t > 0.9 and dark or face
			end
			if seg >= 3 and up < -0.5 then
				return "Head", white
			end
			if seg == 5 then
				return "Head", white -- the band sits right behind the dark nose
			end
			return "Head", face
		end
		if t > 0.9 and up > -0.3 then
			return "Nose", dark
		end
		if t > 0.68 and t <= 0.9 and up > -0.2 then
			return "Head", white -- muzzle band
		end
		if t > 0.45 and up < -0.45 then
			return "Head", white -- chin
		end
		return "Head", face
	end
	hull(m, rings, headPaint)
	cap(m, rings[1], poll - D * 0.1, headPaint)
	cap(m, rings[#rings], nose + D * 0.08, headPaint, nil, blocky and (poll + D * hl * 0.8) or nil)
	if blocky then
		-- nose bridge: a wedge on the muzzle's flat top, its tall end butting into the skull's front
		local _, skullTop = headAt(0.2)
		local _, muzA = headAt(0.5)
		local _, muzB = headAt(0.72)
		local muzTop = math.min(muzA, muzB) - 0.03
		local L = hl * 0.3
		local h = skullTop - muzTop - 0.04
		local base = poll + D * hl * 0.55 + U * muzTop
		newPart("WedgePart", m, CFrame.fromMatrix(base + U * h / 2, U:Cross(-D), U, -D), V(0.34, h, L), face, "Head")
	end

	-- eyes: a dark diamond with a glint on each side of the skull, 0.03 proud
	for _, sx in ipairs({ -1, 1 }) do
		local hwE, topE = headAt(0.24)
		if blocky then
			-- blocky eye like the wolf's: a dark brow bar tilted down toward the nose over a black
			-- socket with a square eye and a glint, each layer 0.02 proud, on the flat side face
			local ax, ay = hwE * sp(math.sin(math.pi / 4), box), topE * sp(math.cos(math.pi / 4), box)
			local c = poll + D * hl * 0.24 + U * 0.1 + X * sx * (ax + (hwE - ax) * (1 - 0.1 / ay))
			local frame = CFrame.fromMatrix(c, D, U)
			local outv = frame:VectorToWorldSpace(Vector3.zAxis):Dot(X * sx) > 0 and 1 or -1
			local function plate(name, off, size, col, tilt, mat)
				local p = newPart("Part", m, frame * CFrame.new(off.X, off.Y, off.Z * outv) * CFrame.Angles(0, 0, tilt or 0), size, col, name)
				if mat then
					p.Material = mat
				end
			end
			plate("Head", V(-0.02, 0.14, 0.02), V(0.36, 0.08, 0.06), face:Lerp(Color3.new(0, 0, 0), 0.4), math.rad(-12))
			plate("Eye", V(0, 0, 0), V(0.22, 0.13, 0.06), Color3.fromRGB(16, 14, 16))
			plate("Eye", V(0.03, -0.005, 0.02), V(0.1, 0.09, 0.06), Color3.fromRGB(46, 30, 24))
			plate("Eye", V(0.055, 0.025, 0.04), V(0.035, 0.035, 0.06), Color3.fromRGB(250, 250, 250))
		else
			local c = poll + D * hl * 0.24 + U * 0.08 + X * sx * hwE * SIDE
			eye(m, c, X * sx, U * 0.12, D * 0.13, Color3.fromRGB(24, 22, 26))
		end
	end

	-- ears: leaf plates angled up, out and back (lower on stags, under the antlers), white inside
	for _, sx in ipairs({ -1, 1 }) do
		local root = poll + D * hl * 0.14 + U * 0.16 + X * sx * 0.18 -- starts inside the skull
		local dir = (X * sx * (o.Antlers and 1.2 or 0.75) + U * (o.Antlers and 0.45 or 0.95) - D * 0.35).Unit
		local fwd = (-D + X * sx * 0.9).Unit -- the ear's opening faces forward and out
		local side = dir:Cross(fwd).Unit
		local face = side:Cross(dir).Unit -- the leaf's own normal, toward the opening
		if face:Dot(fwd) < 0 then
			face = -face
		end
		local L, W = 1.0, 0.3
		local function at(f, w, out)
			return root + dir * L * f + side * W * w + face * (out or 0)
		end
		local l1, r1, l2, r2, tip = at(0.3, 1), at(0.3, -1), at(0.68, 0.9), at(0.68, -0.9), at(1, 0)
		for _, t in ipairs({ { root, l1, r1 }, { l1, l2, r1 }, { r1, l2, r2 }, { l2, tip, r2 } }) do
			T(m, "Ear", mane, t[1], t[2], t[3], 0.07)
		end
		-- inner ear: a smaller white leaf on the front face
		-- a 0.04 plate whose back sits on the ear's front face (0.035 out): 0.04 proud, no gap
		local o2 = 0.055
		local il, ir, itip = at(0.35, 0.6, o2), at(0.35, -0.6, o2), at(0.85, 0, o2)
		T(m, "Ear", white, at(0.08, 0, o2), il, ir, 0.04)
		T(m, "Ear", white, il, itip, ir, 0.04)
	end

	-- tail: short, white underneath; with Hair a longer stem ending in a flowing plume
	if o.Hair then
		local e = V(0, 2.62, 2.72)
		tube(m, { V(0, 3.4, 1.7), V(0, 3.32, 2.1), V(0, 3.02, 2.45), e }, { 0.2, 0.16, 0.12, 0.08 }, "Tail", coat, 4)
		for i = 1, 9 do
			local a = (i - 5) / 4
			local seedA, seedB = rnd(i + 80, 1), rnd(i + 80, 2)
			local dir = (V(a * 0.42, -1, 0.42 + seedA * 0.35)).Unit
			local L = (1.7 + seedB * 0.7) / 3
			local p = e - dir * 0.3 + V(a * 0.05, 0, 0)
			local pts = { p }
			for s = 1, 3 do
				p += (dir + V(math.sin(s * 1.5 + i) * 0.18, 0, math.cos(s * 1.2 + i) * 0.16)).Unit * L
				table.insert(pts, p)
			end
			strand(m, "Tail", pts, V(math.cos(i * 0.9), 0, math.sin(i * 0.9)), 0.22 + seedB * 0.06, o.Hair[(i % 2) + 1])
		end
	end
	if not o.Hair then
		tube(m, { V(0, 3.4, 1.7), V(0, 3.26, 2.0), V(0, 2.96, 2.17), V(0, 2.68, 2.22) }, { 0.2, 0.18, 0.14, 0.07 }, "Tail", coat, 4)
	end

	-- legs on the real joints (shared builder: legModel / bone)
	local up = Y
	if blocky then
		-- wolf-style block legs: a chamfered block along each bone (big shoulder and thigh blocks
		-- standing a little proud of the body), a thin lofted bone inside each carries the joint
		local function blk(sm, a, b2, w, d, col, c)
			local dir = (a - b2).Unit
			block(sm, CFrame.fromMatrix((a + b2) / 2, X, dir), V(w, (a - b2).Magnitude, d), col, { c = c or math.min(w, d) * 0.22, edges = "all", axis = "Y", name = "Leg" })
		end
		local thin = { { 0.08, 0.1 }, { 0.08, 0.1 }, { 0.08, 0.1 } }
		local function foot(sm, Fj, Hb)
			blk(sm, Fj + up * 0.08, Hb + up * 0.22, 0.22, 0.25, shin)
			newPart("Part", sm, CFrame.new(Hb + V(0, 0.13, -0.05)), V(0.3, 0.26, 0.38), hoof, "Hoof")
		end
		for _, sx in ipairs({ -1, 1 }) do
			local x = sx * 0.56
			local S, E, K, F = V(x, 3.25, -1.2), V(x, 2.15, -1.3), V(x, 1.1, -1.28), V(x, 0.3, -1.25)
			local Hb = V(x, 0.0, -1.33)
			legModel(m, "LegFront", sx, { S, E, K, F }, {
				{ { S + up * 0.2, S, E }, thin, { mane, mane }, extra = function(sm) blk(sm, S + up * 0.45, E, 0.5, 0.74, mane, 0.12) end },
				{ { E + up * 0.1, K }, thin, { coat }, extra = function(sm) blk(sm, E + up * 0.14, K, 0.34, 0.4, coat) end },
				{ { K + up * 0.1, F }, thin, { shin }, extra = function(sm) blk(sm, K + up * 0.1, F, 0.25, 0.28, shin) end },
				{ { F + up * 0.06, Hb + up * 0.2 }, thin, { shin }, extra = function(sm) foot(sm, F, Hb) end },
			})
			x = sx * 0.57
			local P, St, Hk = V(x, 3.3, 1.3), V(x, 2.2, 1.0), V(x, 1.15, 1.6)
			F, Hb = V(x, 0.3, 1.55), V(x, 0.0, 1.47)
			legModel(m, "LegBack", sx, { P, St, Hk, F }, {
				{ { P + up * 0.2, P, St }, thin, { coat, coat }, extra = function(sm) blk(sm, P + up * 0.32, St, 0.54, 0.98, coat, 0.13) end },
				{ { St + up * 0.1, Hk }, thin, { coat }, extra = function(sm) blk(sm, St + V(0, 0.12, -0.05), Hk, 0.36, 0.44, coat) end },
				{ { Hk + up * 0.1, F }, thin, { shin }, extra = function(sm) blk(sm, Hk + up * 0.12, F, 0.25, 0.28, shin) end },
				{ { F + up * 0.06, Hb + up * 0.2 }, thin, { shin }, extra = function(sm) foot(sm, F, Hb) end },
			})
		end
	else
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 0.48
		-- front: shoulder S, elbow E, knee K, fetlock F, hoof H (template joints)
		local S, E, K, F = V(x, 3.25, -1.2), V(x, 2.15, -1.3), V(x, 1.1, -1.28), V(x, 0.3, -1.25)
		local Hb = V(x, 0.0, -1.35)
		-- each lower bone starts 0.03-0.06 narrower than the joint above it (a knuckle step, so
		-- neighbouring flat sides never share a plane)
		local function lower(Fj)
			local spec = { { Fj + up * 0.08, Hb + V(0, 0.24, -0.02), Hb + V(0, 0.046, -0.04) },
				{ { 0.17, 0.2 }, { 0.24, 0.28 }, { 0.27, 0.32, 0.29 } }, { shin, hoof } }
			if o.Hair then
				-- fur falling over the top of the hoof
				spec.extra = function(sm)
					for i = 0, 4 do
						local a = i / 5 * math.pi * 2 + 0.3
						local out = V(math.cos(a), 0, math.sin(a))
						tuft(sm, Fj + out * V(0.14, 0, 0.18) + up * 0.14, (out * 0.45 - up).Unit, out:Cross(up).Unit, 0.36 + rnd(i, 7) * 0.1, 0.13, "Leg", o.Hair[(i % 2) + 1], -out * 0.08)
					end
				end
			end
			return spec
		end
		-- scales on the outer flat of a shoulder or thigh, fading out toward the joint below
		local function upperScales(a, b, hwA, hwB)
			if not o.Scales then
				return nil
			end
			return function(sm)
				for r = 1, 4 do
					local t = (r - 0.5) / 4.5
					for c = -1, 1 do
						local z = (c + (r % 2) * 0.5 - 0.25) * 0.13
						local h = hwA + (hwB - hwA) * t
						local pos = a:Lerp(b, t) + V(sx * h, 0, z)
						scale(sm, "Leg", o.Scales[math.floor(rnd(r * 10 + c, 9) * #o.Scales) + 1], pos, (b - a).Unit, X * sx, 0.08, 0.3, 0.025 + (r % 3) * 0.006)
					end
				end
			end
		end
		legModel(m, "LegFront", sx, { S, E, K, F }, {
			{ { S + up * 0.35 + V(0, 0, 0.1), S, E }, { { 0.22, 0.3 }, { 0.34, 0.5 }, { 0.28, 0.33 } }, { mane, mane }, extra = upperScales(S, E, 0.34, 0.28) },
			{ { E + up * 0.12, K }, { { 0.25, 0.3 }, { 0.24, 0.28 } }, { coat } },
			{ { K + up * 0.1, F }, { { 0.18, 0.21 }, { 0.2, 0.24 } }, { shin } },
			lower(F),
		}, hoof)
		x = sx * 0.5
		-- back: hip P, stifle St, hock Hk (behind), fetlock F, hoof H (template joints)
		local P, St, Hk = V(x, 3.3, 1.3), V(x, 2.2, 1.0), V(x, 1.15, 1.6)
		F, Hb = V(x, 0.3, 1.55), V(x, 0.0, 1.46)
		legModel(m, "LegBack", sx, { P, St, Hk, F }, {
			{ { P + up * 0.3 + V(0, 0, 0.12), P, St }, { { 0.25, 0.39 }, { 0.36, 0.6 }, { 0.3, 0.38 } }, { coat, coat }, extra = upperScales(P, St, 0.36, 0.3) },
			{ { St + V(0, 0.12, -0.04), Hk + V(0, 0, 0.04) }, { { 0.26, 0.33 }, { 0.24, 0.28, 0.32 } }, { coat } },
			{ { Hk + up * 0.12, F }, { { 0.19, 0.22 }, { 0.2, 0.24 } }, { shin } },
			lower(F),
		}, hoof)
	end

	end

	if o.Antlers == "Branched" then
		local ivory = o.AntlerColor or Color3.fromRGB(150, 110, 78)
		for _, sx in ipairs({ -1, 1 }) do
			local hp = poll + D * 0.15 + U * 0.25
			local function at(x, y, z)
				return hp + V(sx * x, y, z)
			end
			-- beam: up and out, sweeping back, then forward at the top; tines point up and forward
			local beam = { at(0.18, 0, 0.05), at(0.5, 0.55, 0.3), at(0.95, 1.25, 0.5), at(1.32, 1.95, 0.36), at(1.48, 2.6, -0.05), at(1.32, 3.1, -0.55) }
			tube(m, beam, { 0.14, 0.12, 0.105, 0.09, 0.075, 0.05 }, "Antler", ivory, 4)
			local tips = { beam[#beam] }
			for _, t in ipairs({ { 2, V(0.15, 0.3, -0.9), 0.08 }, { 3, V(0.05, 0.9, -0.55), 0.07 }, { 4, V(0.15, 0.85, -0.35), 0.065 }, { 5, V(0.35, 0.7, -0.05), 0.055 } }) do
				local p0 = beam[t[1]]
				local p1 = p0 + V(sx * t[2].X, t[2].Y, t[2].Z)
				local mid = p0:Lerp(p1, 0.5) + V(0, 0.05, 0)
				tube(m, { p0 - (p1 - p0).Unit * 0.05, mid, p1 }, { t[3], t[3] * 0.8, t[3] * 0.45 }, "Antler", ivory, 3)
				table.insert(tips, p1)
			end
			if o.Glow then
				-- glowing crystal caps: each tip ends inside its crystal (no gap)
				for _, tp in ipairs(tips) do
					local pts = {}
					for j = 0, 3 do
						local a = j / 4 * math.pi * 2 + 0.4
						table.insert(pts, tp + V(math.cos(a) * 0.11, 0, math.sin(a) * 0.11))
					end
					local top, bot = tp + V(0, 0.26, 0), tp - V(0, 0.12, 0)
					for j = 1, 4 do
						local a, b = pts[j], pts[j % 4 + 1]
						T(m, "AntlerGlow", o.Glow, a, b, top, 0.02, Enum.Material.Neon)
						T(m, "AntlerGlow", o.Glow, b, a, bot, 0.02, Enum.Material.Neon)
					end
				end
			end
		end
	end
	if o.Antlers == "Swept" then
		-- two long horns sweeping straight back over the neck, tapering to a point (on the head joint)
		local col = o.AntlerColor or Color3.fromRGB(46, 36, 30)
		for _, sx in ipairs({ -1, 1 }) do
			local hp = poll + D * 0.16 + U * 0.3
			local function at(x, y, z)
				return hp + V(sx * x, y, z)
			end
			tube(m, { at(0.17, -0.1, -0.04), at(0.24, 0.34, 0.42), at(0.34, 0.62, 1.1), at(0.42, 0.78, 1.85), at(0.47, 0.82, 2.6) },
				{ 0.13, 0.115, 0.09, 0.065, 0.035 }, "Antler", col, 5)
		end
	end
	if o.Hair then
		-- forelock: a few shorter strands from the poll, falling to either side of the horns
		for i = 1, 6 do
			local sx = i % 2 == 0 and 1 or -1
			local dir = (V(sx * (0.5 + rnd(i, 4) * 0.4), -0.7, 0.55 + rnd(i, 6) * 0.3)).Unit
			local L = (0.9 + rnd(i, 8) * 0.4) / 3
			local p = poll + U * 0.34 + X * sx * (0.08 + (i // 2) * 0.05) + D * (0.05 + (i // 2) * 0.1)
			local pts = { p }
			for s = 1, 3 do
				p += (dir + V(0, -0.12 * s, math.sin(s + i) * 0.14)).Unit * L
				table.insert(pts, p)
			end
			strand(m, "Head", pts, (V(sx * 0.3, 0.45, 0.85)).Unit, 0.14 + rnd(i, 2) * 0.03, o.Hair[(i % 2) + 1])
		end
	end
	if o.Dragon then
		local hairCol = o.Hair and o.Hair[1] or white
		local jade = o.Scales and o.Scales[1] or dark
		for _, sx in ipairs({ -1, 1 }) do
			-- heavy brow ridge above the eye
			local browA, browB = poll + D * hl * 0.06 + U * 0.42 + X * sx * 0.2, poll + D * hl * 0.42 + U * 0.3 + X * sx * 0.22
			tube(m, { browA, browA:Lerp(browB, 0.5) + U * 0.05 + X * sx * 0.05, browB }, { 0.07, 0.07, 0.04 }, "Head", jade, 4)
			-- whiskers: thin and long, out from the muzzle, then trailing back and down
			local base = poll + D * hl * 0.84 + X * sx * 0.2
			tube(m, { base, base + X * sx * 0.38 + D * 0.05, base + X * sx * 0.74 - D * 0.28 - U * 0.2, base + X * sx * 0.98 - D * 0.85 - U * 0.5 },
				{ 0.035, 0.03, 0.022, 0.012 }, "Head", hairCol, 3)
			-- cheek fins at the back of the jaw
			for i = 1, 3 do
				local c = poll + D * hl * (0.2 + i * 0.05) - U * (0.2 + i * 0.07) + X * sx * 0.4
				tuft(m, c, (X * sx * 0.75 - D * 0.6 - U * 0.2 * i).Unit, (U + D * 0.3).Unit, 0.55 - i * 0.07, 0.1, "Head", hairCol, -X * sx * 0.1)
			end
		end
		-- chin beard
		for i = 1, 4 do
			local c = poll + D * hl * (0.62 + i * 0.06) - U * 0.27 + X * ((i - 2.5) * 0.06)
			tuft(m, c, (-U + D * 0.1 - D * 0.5).Unit, X, 0.5 + rnd(i, 3) * 0.2, 0.06, "Head", hairCol, U * 0.08)
		end
	end
	if o.Moon then
		-- a glowing crescent on the forehead, 0.03 proud of the face
		local hwM, topM = headAt(0.3)
		local c = poll + D * hl * 0.3
		-- height of the forehead faces at side offset x (they slope from the ridge to the side points)
		local function brow(x)
			return topM - (topM - topM * RISE) * math.min(1, math.abs(x) / (hwM * SIDE)) + 0.005
		end
		local prev
		for i = 0, 6 do
			local a = math.rad(-70 + i * (140 / 6))
			local w = 0.03 + 0.04 * math.sin(i / 6 * math.pi)
			local px, ix = math.sin(a) * 0.2, math.sin(a) * (0.2 - w)
			local p = c + X * px - D * math.cos(a) * 0.08 + U * brow(px)
			local inner = c + X * ix - D * (math.cos(a) * 0.08 - w) + U * brow(ix)
			if prev then
				T(m, "Glow", o.Moon, prev[1], p, inner, 0.07, Enum.Material.Neon)
				T(m, "Glow", o.Moon, prev[1], inner, prev[2], 0.07, Enum.Material.Neon)
			end
			prev = { p, inner }
		end
	end
	-- rig hints: the neck pivots at its base, given relative to the body root centre (0, 2.9, 0.2)
	-- rig hints: the body box (the mob's HumanoidRootPart), the neck pivot relative to its centre,
	-- and the nose-to-tail length that Config Size.Z is matched to
	local rootC = V(0, 2.95, 0)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", V(1.44, 1.7, 3.7))
	m:SetAttribute("NeckBase", V(0, 3.5, -1.3) - rootC)
	m:SetAttribute("HeadPivot", poll - rootC) -- the poll: the head tilts here, the neck bends at NeckBase
	m:SetAttribute("Length", 5.75)
	m:SetAttribute("Stride", 3.3) -- distance per walk cycle at design scale (leg sweep / stance share)
	return V(1.8, o.Antlers and 8.4 or 5.8, 5.75)
end

-- head helper for 6-sided heads: rings along the axis from poll to nose, plus where the flat side
-- face and the top ridge sit at fraction t (details go 0.03-0.04 proud of these)
local SIDE6 = sp(math.sin(math.pi / 3), BOX)
local RISE6 = sp(math.cos(math.pi / 3), BOX)
local function headKit(poll, nose, HEAD, e, n)
	local D = (nose - poll).Unit
	local U = X:Cross(D).Unit
	local hl = (nose - poll).Magnitude
	local function at(t)
		for i = 1, #HEAD - 1 do
			local a, b = HEAD[i], HEAD[i + 1]
			if t <= b[1] then
				local f = (t - a[1]) / (b[1] - a[1])
				return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f
			end
		end
		local l = HEAD[#HEAD]
		return l[2], l[3], l[4]
	end
	local rings = {}
	for _, r in ipairs(HEAD) do
		table.insert(rings, ring(poll + D * hl * r[1], X, U, r[2], r[3], r[4], n or 6, e or BOX))
	end
	return D, U, hl, at, rings
end

-- a leaf ear from root along dir, its opening facing `fwd`; an inner leaf 0.04 proud in `inner`
local function ear(m, root, dir, fwd, L, W, col, inner, thick)
	local side = dir:Cross(fwd).Unit
	local face = side:Cross(dir).Unit
	if face:Dot(fwd) < 0 then
		face = -face
	end
	thick = thick or 0.07
	local function at(f, w, out)
		return root + dir * L * f + side * W * w + face * (out or 0)
	end
	local l1, r1, l2, r2, tip = at(0.3, 1), at(0.3, -1), at(0.68, 0.9), at(0.68, -0.9), at(1, 0)
	for _, t in ipairs({ { root, l1, r1 }, { l1, l2, r1 }, { r1, l2, r2 }, { l2, tip, r2 } }) do
		T(m, "Ear", col, t[1], t[2], t[3], thick)
	end
	if inner then
		local o2 = thick / 2 + 0.02
		local il, ir, itip = at(0.35, 0.6, o2), at(0.35, -0.6, o2), at(0.85, 0, o2)
		T(m, "Ear", inner, at(0.1, 0, o2), il, ir, 0.04)
		T(m, "Ear", inner, il, itip, ir, 0.04)
	end
end

-- a horizontal paw pad (wolves, big cats): rings across the foot from heel to toe, bottoms on y = 0
-- clawCol (optional): four claws at the toes, pointing forward and down (for claw swipes)
local function paw(sm, heelZ, x, len, hw, col, clawCol)
	local Y = Vector3.yAxis
	local s = -1 -- toes point forward (-Z) on every foot
	local P = {
		{ heelZ + 0.08, hw * 0.7, 0.07 }, { heelZ - len * 0.35, hw, 0.1 }, { heelZ - len * 0.8, hw * 0.88, 0.07 },
	}
	local rgs = {}
	for _, r in ipairs(P) do
		table.insert(rgs, ring(Vector3.new(x, 0.085, r[1]), X, Y, r[2], r[3], 0.085, 5))
	end
	local paint = function()
		return "Leg", col
	end
	hull(sm, rgs, paint)
	cap(sm, rgs[#rgs], Vector3.new(x, 0.06, heelZ + s * len), paint)
	cap(sm, rgs[1], Vector3.new(x, 0.09, heelZ + 0.16), paint)
	if clawCol then
		for i, dx in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do
			local base = Vector3.new(x + dx * hw * 0.8, 0.055, heelZ - len * (0.8 + 0.04 * (2 - math.abs(dx) * 2)))
			tuft(sm, base, Vector3.new(0, -0.4, -1).Unit, X, 0.11 + 0.02 * (i % 2), 0.03, "Leg", clawCol, Vector3.new(0, 0.04, 0.04))
		end
	end
end

-- a lower jaw on its own hinge (bites, squeals): rings across the jaw from the hinge to the chin,
-- JAW = { { t along the head, half width, top u, bottom u }, ... } (u along U, the head's up). Its
-- top sits inside the upper jaw's bottom while closed, so the mouth shows only when it opens.
-- Parts are named "Jaw"; set the "JawPivot" attribute so Creatures.rig hinges them.
local function jaw(m, poll, D, U, hl, JAW, paint, e, n)
	local rgs, cs = {}, {}
	for _, r in ipairs(JAW) do
		local c = poll + D * hl * r[1] + U * ((r[3] + r[4]) / 2)
		local h = (r[3] - r[4]) / 2
		table.insert(rgs, ring(c, X, U, r[2], h, h, n or 6, e or BOX))
		table.insert(cs, c)
	end
	hull(m, rgs, paint)
	cap(m, rgs[1], cs[1] - D * 0.08, paint)
	cap(m, rgs[#rgs], cs[#cs] + D * 0.05, paint)
end

-- Boar (Boar, Tusk Boar, Tusk King). Design scale: shoulder hump 2.9, snout to tail ~5.3, ground
-- y = 0, facing -Z. Wild boar build: high shoulders sloping to a smaller rump, deep chest on short
-- legs, no visible neck, a long wedge head carried low ending in a flat snout disc, small upright
-- ears, tusks curving up out of the lower jaw, and a bristle crest along the spine.
-- opts: Coat, Mane (forequarters, crest), Belly, Leg, Hoof, Snout, Tusk, TuskScale, Crest (height
--   scale), EyeGlow (glowing eyes), Bands (tusk band colour), Spikes (bone spikes along the crest)
recipes.Boar = function(m, o)
	local coat = o.Coat or Color3.fromRGB(110, 82, 62)
	local mane = o.Mane or coat:Lerp(Color3.new(0, 0, 0), 0.3)
	local belly = o.Belly or coat:Lerp(Color3.new(1, 1, 1), 0.12)
	local legCol = o.Leg or mane
	local hoof = o.Hoof or Color3.fromRGB(46, 40, 38)
	local snout = o.Snout or Color3.fromRGB(210, 148, 140)
	local tuskCol = o.Tusk or Color3.fromRGB(238, 230, 206)
	local Y, V, up = Vector3.yAxis, Vector3.new, Vector3.yAxis
	local box = o.Box or BOX -- lower = blockier (flat tops and sides)
	-- Blocky (user: match the wolf): 8-point sections with a very low exponent are boxes with small
	-- corner bevels, and the head is a skull box stepping down to a snout box
	local sides = o.Blocky and 8 or BODY_SIDES

	local TORSO = {
		{ -1.75, 1.95, 0.34, 0.55, 0.55 }, { -1.45, 2.02, 0.62, 0.84, 0.84 }, { -0.8, 2.04, 0.66, 0.86, 0.86 },
		{ 0.95, 1.98, 0.62, 0.66, 0.75 }, { 1.45, 1.96, 0.5, 0.54, 0.62 }, { 1.72, 1.94, 0.28, 0.32, 0.38 },
	}
	if o.Low then
		-- lower poly to match the block wolf (user): fewer, longer facets along the body
		-- (the rump section sits far back so the hind legs stay under the body line)
		TORSO = { { -1.75, 1.95, 0.34, 0.55, 0.55 }, { -1.3, 2.03, 0.64, 0.86, 0.86 }, { 1.2, 1.98, 0.62, 0.68, 0.74 }, { 1.76, 1.94, 0.34, 0.38, 0.44 } }
	end
	local rings = {}
	for _, r in ipairs(TORSO) do
		table.insert(rings, ring(V(0, r[2], r[1]), X, Y, r[3] * BODY_W, r[4], r[5], sides, box))
	end
	local function torsoPaint(c, n)
		if n.Y < -0.6 and c.Z > -1.2 and c.Z < 1.2 then
			return "Body", belly
		end
		if c.Z < -0.55 then
			return "Body", mane -- dark forequarters
		end
		return "Body", coat
	end
	hull(m, rings, torsoPaint)
	cap(m, rings[1], V(0, 1.95, -1.85), torsoPaint)
	cap(m, rings[#rings], V(0, 1.98, 1.82), torsoPaint)

	-- bristle crest: two rows of leaning fins along the spine (shoulders highest), roots buried
	local function ridge(z)
		for i = 1, #TORSO - 1 do
			local a, b = TORSO[i], TORSO[i + 1]
			if z <= b[1] then
				local f = (z - a[1]) / (b[1] - a[1])
				return (a[2] + a[4]) + ((b[2] + b[4]) - (a[2] + a[4])) * f
			end
		end
		return TORSO[#TORSO][2] + TORSO[#TORSO][4]
	end
	local crest = o.Crest or 1
	local z = -1.55
	local i = 0
	while z < 0.75 do
		local h = (0.26 + 0.2 * math.sin(math.clamp((z + 1.6) / 2.4, 0, 1) * math.pi)) * crest * (0.85 + 0.15 * ((i % 3) / 2))
		local len = o.Low and 0.5 or 0.36
		for _, sx in ipairs({ -1, 1 }) do
			local x = sx * 0.07
			local y0, y1 = ridge(z) - 0.08, ridge(z + len) - 0.08
			local tip = V(x + sx * h * 0.25, ridge(z + len * 0.7) + h, z + len * 0.85)
			if o.Spikes then
				tube(m, { V(x, y0 + 0.02, z + len * 0.4), V(x + sx * h * 0.2, (y0 + y1) / 2 + h * 0.75, z + len * 0.9), V(x + sx * h * 0.28, (y0 + y1) / 2 + h * 1.3, z + len * 1.4) },
					{ 0.09, 0.06, 0.02 }, "Crest", o.Spikes, 3)
			else
				T(m, "Crest", mane, V(x, y0, z), V(x, y1, z + len), tip, 0.08)
			end
		end
		z += len
		i += 1
	end

	-- neck (short and thick) into the head
	local poll, snoutTip = V(0, 2.4, -1.72), V(0, 1.1, -3.25) -- big head, snout near knee height (refs)
	-- the upper jaw stops at the mouth line (u = -0.13) from mid-head forward; the lower jaw (with
	-- the tusks, which are lower canines) is its own part on a hinge, for squeals and gore tosses
	local HEAD = { { 0, 0.46, 0.5, 0.5 }, { 0.18, 0.56, 0.54, 0.58 }, { 0.45, 0.43, 0.43, 0.2 }, { 0.72, 0.29, 0.29, 0.14 },
		{ 0.92, 0.23, 0.23, 0.13 }, { 1.0, 0.26, 0.25, 0.15 } }
	if o.Blocky then
		HEAD = { { 0, 0.48, 0.5, 0.48 }, { 0.38, 0.5, 0.5, 0.42 }, { 0.42, 0.34, 0.3, 0.17 }, { 1.0, 0.3, 0.26, 0.15 } }
	elseif o.Low then
		HEAD = { { 0, 0.46, 0.5, 0.5 }, { 0.2, 0.56, 0.54, 0.58 }, { 0.6, 0.36, 0.36, 0.17 }, { 1.0, 0.26, 0.25, 0.15 } }
	end
	-- head scale (user: the blocky head 25% bigger)
	local hs = o.HeadScale or 1
	if hs ~= 1 then
		for _, r in ipairs(HEAD) do
			r[2], r[3], r[4] = r[2] * hs, r[3] * hs, r[4] * hs
		end
		snoutTip = poll + (snoutTip - poll) * hs
	end
	local D, U, hl, headAt, hrings = headKit(poll, snoutTip, HEAD, box, o.Blocky and 8 or nil)
	local NECK = { { V(0, 2.1, -1.25), 0.5, 0.62, 0.62 }, { poll + D * hl * 0.22 - U * 0.05, 0.4, 0.4, 0.42 } }
	rings = {}
	for i2, r in ipairs(NECK) do
		local d = (NECK[2][1] - NECK[1][1]).Unit
		table.insert(rings, ring(r[1], X, d:Cross(X).Unit, r[2] * BODY_W, r[3], r[4], sides, box))
	end
	local neckPaint = function()
		return "Neck", mane
	end
	hull(m, rings, neckPaint)
	cap(m, rings[1], NECK[1][1] + V(0, 0, 0.3), neckPaint)
	cap(m, rings[2], NECK[2][1] - D * 0.1, neckPaint)
	local function headPaint(c, n)
		local t = (c - poll):Dot(D) / hl
		if t > 0.95 and n:Dot(D) > 0.5 then
			return "Snout", snout -- the flat snout disc
		end
		if t > 0.4 and n:Dot(U) < -0.7 then
			return "Head", Color3.fromRGB(86, 34, 38) -- roof of the mouth (hidden while closed)
		end
		return "Head", t < 0.35 and mane or coat
	end
	hull(m, hrings, headPaint)
	cap(m, hrings[1], poll - D * 0.12, headPaint)
	cap(m, hrings[#hrings], snoutTip + D * 0.03, headPaint, nil, poll + D * hl * 0.8)
	if o.Blocky then
		-- nose bridge (user): one wedge from the skull's front running down halfway along the muzzle
		-- it lies on the muzzle's flat top and its tall end butts into the skull's front face
		local _, skullTop = headAt(0.2)
		local _, muzA = headAt(0.45)
		local _, muzB = headAt(0.7)
		local muzTop = math.min(muzA, muzB) - 0.03
		local L = hl * 0.34
		local h = skullTop - muzTop - 0.04
		local base = poll + D * hl * 0.53 + U * muzTop
		local cf = CFrame.fromMatrix(base + U * h / 2, U:Cross(-D), U, -D)
		newPart("WedgePart", m, cf, Vector3.new(0.44 * hs, h, L), coat, "Head")
	end
	local JAWR = { { 0.3, 0.4, -0.1, -0.5 }, { 0.45, 0.35, -0.1, -0.45 }, { 0.72, 0.25, -0.1, -0.34 },
		{ 0.92, 0.19, -0.1, -0.27 }, { 0.98, 0.15, -0.1, -0.23 } }
	if o.Blocky then
		JAWR = { { 0.3, 0.38, -0.1, -0.44 }, { 0.42, 0.3, -0.1, -0.4 }, { 0.98, 0.25, -0.1, -0.3 } }
	end
	for _, r in ipairs(JAWR) do
		r[2], r[3], r[4] = r[2] * hs, r[3] * hs, r[4] * hs
	end
	jaw(m, poll, D, U, hl, JAWR, function(c, n)
		if n:Dot(U) > 0.6 then
			return "Jaw", Color3.fromRGB(86, 34, 38)
		end
		return "Jaw", belly
	end, box, o.Blocky and 8 or nil)
	m:SetAttribute("JawPivot", poll + D * hl * 0.3 - U * 0.22 * hs)
	-- nostrils: two dark plates 0.04 proud of the disc
	for _, sx in ipairs({ -1, 1 }) do
		local c = snoutTip + D * 0.035 + X * sx * 0.08 * hs - U * 0.02 * hs
		T(m, "Snout", Color3.fromRGB(52, 36, 36), c + U * 0.06 * hs, c + X * 0.04 * hs, c - U * 0.05 * hs, 0.06)
		T(m, "Snout", Color3.fromRGB(52, 36, 36), c + U * 0.06 * hs, c - U * 0.05 * hs, c - X * 0.04 * hs, 0.06)
	end
	-- eyes: small and high, on the flat side face
	for _, sx in ipairs({ -1, 1 }) do
		local hwE, topE = headAt(0.3)
		local sideX = hwE * SIDE6
		if o.Blocky then
			-- on the flat side between the 45-degree point and the side point
			local ax, ay = hwE * sp(math.sin(math.pi / 4), box), topE * sp(math.cos(math.pi / 4), box)
			sideX = ax + (hwE - ax) * (1 - 0.12 * hs / ay)
		end
		local c = poll + D * hl * 0.3 + U * 0.12 * hs + X * sx * sideX
		if o.Blocky then
			-- blocky eye like the wolf's: a dark brow bar tilted down toward the snout over a black
			-- rectangular socket with a small square eye in it, each layer 0.02 proud of the last
			local frame = CFrame.fromMatrix(c, D, U)
			local function plate(name, off, size, col, tilt, mat)
				local p = newPart("Part", m, frame * CFrame.new(off) * CFrame.Angles(0, 0, tilt or 0), size, col, name)
				if mat then
					p.Material = mat
				end
			end
			local zs = -sx -- CFrame.fromMatrix(c, D, U)'s Z points along -(D x U); flip per side so layers go outward
			local function out(d)
				local w = frame:VectorToWorldSpace(Vector3.zAxis)
				return (w:Dot(X * sx) > 0) and d or -d
			end
			plate("Head", Vector3.new(-0.02, 0.13 * hs, out(0.02)), Vector3.new(0.34 * hs, 0.09 * hs, 0.06), mane:Lerp(Color3.new(0, 0, 0), 0.35), math.rad(-14))
			plate("Eye", Vector3.new(0, 0, out(0.0)), Vector3.new(0.2 * hs, 0.11 * hs, 0.06), Color3.fromRGB(14, 12, 12))
			plate("Eye", Vector3.new(0.03 * hs, 0, out(0.02)), Vector3.new(0.08 * hs, 0.07 * hs, 0.06), o.EyeGlow or Color3.fromRGB(70, 40, 26), nil, o.EyeGlow and Enum.Material.Neon or nil)
		else
			eye(m, c, X * sx, U * 0.07, D * 0.08, o.EyeGlow or Color3.fromRGB(24, 20, 20), o.EyeGlow ~= nil)
		end
	end
	-- ears: small, upright, pointed, opening forward
	for _, sx in ipairs({ -1, 1 }) do
		local root = poll + D * hl * 0.1 + U * 0.3 * hs + X * sx * 0.24 * hs
		ear(m, root, (X * sx * 0.4 + U * 0.95 - D * 0.3).Unit, (-D + X * sx * 0.5).Unit, 0.72 * hs, 0.26 * hs, mane, coat:Lerp(snout, 0.5))
	end
	-- tusks: out of the lower jaw, curving up, out and back
	local ts = o.TuskScale or 1
	for _, sx in ipairs({ -1, 1 }) do
		local B = poll + D * hl * 0.72 - U * 0.2 * hs + X * sx * 0.22 * hs
		local k = ts * hs
		local pts = { B, B + V(sx * 0.1, 0.2, 0.02) * k, B + V(sx * 0.16, 0.38, 0.14) * k, B + V(sx * 0.14, 0.48, 0.3) * k }
		local r = math.sqrt(ts) * hs
		-- tusks are lower canines: they ride the jaw
		tube(m, pts, { 0.075 * r, 0.065 * r, 0.048 * r, 0.026 * r }, "Jaw", tuskCol, 4)
		if o.Bands then
			-- a gold band round the tusk's middle
			tube(m, { pts[2]:Lerp(pts[3], 0.15), pts[2]:Lerp(pts[3], 0.55) }, { 0.085 * r, 0.075 * r }, "Jaw", o.Bands, 6)
		end
	end
	-- tail: thin, with a dark tuft
	-- rooted inside the rump (its top is about y 2.3 at the back), then hanging down past the hams
	tube(m, { V(0, 2.18, 1.6), V(0, 2.12, 1.95), V(0, 1.85, 2.06) }, { 0.08, 0.06, 0.045 }, "Tail", coat, 3)
	tube(m, { V(0, 1.92, 2.05), V(0, 1.72, 2.08), V(0, 1.55, 2.06) }, { 0.08, 0.09, 0.03 }, "Tail", mane, 3)

	-- legs: short, on the real joints (pig: shoulder, elbow, knee, fetlock, cloven trotter)
	for _, sx in ipairs({ -1, 1 }) do
		-- the upper bones start inside the body (refs: only the lower leg shows below the belly)
		local x = sx * 0.5 -- the whole leg sits under its shoulder block
		local S, E, K, F = V(x, 2.2, -1.15), V(x, 1.3, -1.25), V(x, 0.72, -1.22), V(x, 0.24, -1.2)
		local Hb = V(x, 0, -1.3)
		local function lower(Fj)
			return { { Fj + up * 0.07, Hb + V(0, 0.18, -0.02), Hb + V(0, 0.046, -0.04) },
				{ { 0.13, 0.15 }, { 0.19, 0.24 }, { 0.21, 0.26, 0.23 } }, { legCol, hoof } }
		end
		legModel(m, "LegFront", sx, { S, E, K, F }, {
			-- shoulder: a big chamfered block like the wolf's (about two thirds of the chest's height), a
			-- little proud of the body; the slim bone inside carries the joint
			{ { S + up * 0.25 + V(0, 0, 0.08), S, E }, { { 0.18, 0.25 }, { 0.22, 0.3 }, { 0.2, 0.26 } }, { mane, mane },
				extra = function(sm)
					block(sm, CFrame.new(sx * 0.5, 1.97, -1.18), V(0.58, 1.06, 0.8), mane, { c = 0.12, edges = "all", axis = "Y", name = "Leg" })
				end },
			-- forearm: a blocky chamfered piece under the shoulder (slim bone inside carries the joint)
			{ { E + up * 0.12, K }, { { 0.15, 0.19 }, { 0.15, 0.18 } }, { legCol },
				extra = function(sm)
					block(sm, CFrame.new(sx * 0.5, 1.03, -1.23), V(0.5, 0.9, 0.5), legCol, { c = 0.08, edges = "all", axis = "Y", name = "Leg" })
				end },
			{ { K + up * 0.1, F }, { { 0.15, 0.18 }, { 0.16, 0.19 } }, { legCol } },
			lower(F),
		}, hoof)
		x = sx * 0.5 -- the whole leg sits under its thigh block
		local P, St, Hk = V(x, 1.98, 1.1), V(x, 1.36, 0.85), V(x, 0.72, 1.28)
		F, Hb = V(x, 0.24, 1.25), V(x, 0, 1.17)
		legModel(m, "LegBack", sx, { P, St, Hk, F }, {
			-- thigh: a big chamfered block like the wolf's, kept under the back line
			{ { P + up * 0.15 + V(0, 0, 0.1), P, St }, { { 0.18, 0.26 }, { 0.22, 0.32 }, { 0.2, 0.27 } }, { coat, coat },
				extra = function(sm)
					block(sm, CFrame.new(sx * 0.5, 1.8, 1.02) * CFrame.Angles(math.rad(12), 0, 0), V(0.62, 1.08, 1.02), coat, { c = 0.13, edges = "all", axis = "Y", name = "Leg" })
				end },
			-- gaskin: a blocky chamfered piece running back down to the hock
			{ { St + V(0, 0.12, -0.04), Hk + V(0, 0, 0.04) }, { { 0.15, 0.2 }, { 0.15, 0.18, 0.21 } }, { coat },
				extra = function(sm)
					block(sm, CFrame.new(sx * 0.5, 1.08, 1.05) * CFrame.Angles(math.rad(-34), 0, 0), V(0.42, 0.95, 0.48), coat, { c = 0.09, edges = "all", axis = "Y", name = "Leg" })
				end },
			{ { Hk + up * 0.1, F }, { { 0.15, 0.18 }, { 0.16, 0.19 } }, { legCol } },
			lower(F),
		}, hoof)
	end
	local rootC = V(0, 2.0, 0)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", V(1.3, 1.65, 3.4))
	m:SetAttribute("NeckBase", V(0, 2.2, -1.35) - rootC)
	m:SetAttribute("HeadPivot", poll - rootC) -- the poll: the head tilts here, the neck bends at NeckBase
	m:SetAttribute("JawPivot", m:GetAttribute("JawPivot") - rootC)
	m:SetAttribute("Length", 5.3)
	m:SetAttribute("Stride", 2.3)
	return V(1.6, 3.2, 5.3)
end

-- Wolf (Grey Wolf, Night Wolf). Design scale: shoulder 3.0, nose to tail tip ~5.4, ground y = 0,
-- facing -Z. Deep narrow chest and a tucked waist, long digitigrade legs (shoulder, elbow, wrist,
-- paw; hip, stifle, hock, paw) on padded paws, a thick ruffed neck, a long narrow muzzle, tall
-- pointed ears and a bushy tail with a dark tip.
-- opts: Coat, Back (saddle), Mane (neck ruff), Face, Cream (belly, cheeks, muzzle), Leg, Paw, Nose,
--   EyeCol, EyeGlow (glowing eyes), TailTip
--   fox options (Nine-Tailed Fox, Fox Spirit): Tails (1-9, fanned up and out behind the rump),
--   TailFluff (plume thickness, 1 = wolf), EarScale (bigger fox ears), TailGlow (Neon tail tips,
--   foxfire), Glow (a Neon flame mark on the brow)
recipes.Wolf = function(m, o)
	local coat = o.Coat or Color3.fromRGB(128, 128, 134)
	local back = o.Back or coat:Lerp(Color3.new(0, 0, 0), 0.25)
	local mane = o.Mane or coat:Lerp(back, 0.5)
	local face = o.Face or coat
	local cream = o.Cream or Color3.fromRGB(218, 210, 196)
	local legCol = o.Leg or coat:Lerp(cream, 0.25)
	local pawCol = o.Paw or legCol:Lerp(Color3.new(0, 0, 0), 0.35)
	local noseCol = o.Nose or Color3.fromRGB(30, 28, 30)
	local clawCol = o.Claw or Color3.fromRGB(40, 36, 38)
	local mouthCol = Color3.fromRGB(56, 30, 34) -- reads as a dark lip line while closed
	local toothCol = Color3.fromRGB(246, 242, 230)
	local Y, V, up = Vector3.yAxis, Vector3.new, Vector3.yAxis

	-- measured from the user's papercraft wolf (side view, withers H = 3.0): a deep chest tapering to a
	-- slim rump, the back nearly level
	local TORSO = {
		{ -1.55, 2.2, 0.3, 0.45, 0.4 }, { -1.3, 2.15, 0.55, 0.75, 0.75 }, { -0.85, 2.17, 0.6, 0.78, 0.78 },
		{ 0.3, 2.25, 0.5, 0.62, 0.62 }, { 1.2, 2.35, 0.48, 0.45, 0.42 }, { 1.62, 2.4, 0.3, 0.32, 0.3 },
	}
	local rings = {}
	for _, r in ipairs(TORSO) do
		table.insert(rings, ring(V(0, r[2], r[1]), X, Y, r[3] * BODY_W, r[4], r[5], BODY_SIDES, BOX))
	end
	local function torsoPaint(c, n)
		if n.Y < -0.5 or (c.Z < -1.4 and n.Z < -0.5 and c.Y < 2.5) then
			return "Body", cream -- belly and chest
		end
		if n.Y > 0.55 and c.Z > -1.0 then
			return "Body", back -- dark saddle
		end
		return "Body", c.Z < -0.9 and mane or coat
	end
	hull(m, rings, torsoPaint)
	cap(m, rings[1], V(0, 2.2, -1.68), torsoPaint)
	cap(m, rings[#rings], V(0, 2.42, 1.75), torsoPaint)

	-- the head is carried high on a steep neck, the long muzzle level (refs)
	local poll, nose = V(0, 3.5, -1.72), V(0, 3.26, -3.2)
	-- wolf head (refs): broad skull, a raised brow over the eyes, a sharp stop down to a box-shaped
	-- muzzle, a nose pad at the end
	-- the upper jaw stops at the mouth line (u = -0.06) from the stop forward; the lower jaw is its
	-- own part on a hinge below the eyes, so bites can open the mouth
	-- between the brow (t .28) and the stop (t .5) the head narrows fast, so the side of the face there
	-- angles about 30 degrees forward: the eyes sit on it and look ahead
	-- not flat (user): a tall domed skull and deep cheeks, as tall as it is wide, then a clear stop
	local HEAD = { { 0, 0.36, 0.44, 0.38 }, { 0.13, 0.47, 0.6, 0.5 }, { 0.28, 0.47, 0.56, 0.4 }, { 0.5, 0.27, 0.32, 0.08 },
		{ 0.75, 0.24, 0.28, 0.06 }, { 0.94, 0.2, 0.25, 0.06 }, { 1.0, 0.16, 0.19, 0.06 } }
	local D, U, hl, headAt, hrings = headKit(poll, nose, HEAD)
	-- neck: thick, with a ruff; ends inside the skull
	-- the neck grows out of the chest: its first section sits inside the torso and matches it, so the
	-- back line runs straight on up the neck into the head (no ledge where they meet)
	local NECK = { { V(0, 2.45, -0.95), 0.52, 0.5, 0.5 }, { V(0, 2.95, -1.42), 0.46, 0.5, 0.44 }, { V(0, 3.32, -1.66), 0.4, 0.42, 0.38 },
		{ poll + D * hl * 0.25 - U * 0.05, 0.3, 0.3, 0.28 } }
	rings = {}
	for i2, r in ipairs(NECK) do
		local d = (NECK[math.min(i2 + 1, #NECK)][1] - NECK[math.max(i2 - 1, 1)][1]).Unit
		table.insert(rings, ring(r[1], X, d:Cross(X).Unit, r[2] * BODY_W, r[3], r[4], BODY_SIDES, BOX))
	end
	local function neckPaint(c, n)
		if n.Z < -0.5 and n.Y < 0.4 then
			return "Neck", cream -- throat
		end
		return "Neck", mane
	end
	hull(m, rings, neckPaint)
	cap(m, rings[1], NECK[1][1] + V(0, -0.15, 0.3), neckPaint)
	cap(m, rings[#rings], NECK[#NECK][1] + D * 0.12, neckPaint)
	if o.Hair then
		-- a shaggy mane down both sides from the crest (the ring point opposite the throat)
		local back = #rings[1] // 2 + 1
		local crest = { rings[1][back], rings[2][back], rings[#rings][back] }
		for _, sx in ipairs({ -1, 1 }) do
			for i = 1, 7 do
				local t = (i - 0.5 + (sx > 0 and 0.5 or 0)) / 7.5
				local at = t < 0.5 and crest[1]:Lerp(crest[2], t * 2) or crest[2]:Lerp(crest[3], t * 2 - 1)
				local seedA, seedB = rnd(i * sx + 60, 1), rnd(i * sx + 60, 2)
				local L = (o.HairLength or 1.05 + seedA * 0.4) / 3
				local dir = (V(sx * (0.5 + seedB * 0.25), -0.9, 0.42 + seedA * 0.3)).Unit
				local p = at - dir * 0.06
				local pts = { p }
				for k = 1, 3 do
					p += (dir + V(sx * math.sin(k * 1.7 + i) * 0.18, 0, math.cos(k * 1.3 + i) * 0.2)).Unit * L
					table.insert(pts, p)
				end
				strand(m, "Neck", pts, (V(sx * (seedB - 0.5) * 0.5, 0.45, 0.85)).Unit, 0.17 + seedB * 0.05, o.Hair[(i % 2) + 1])
			end
		end
	end
	local function headPaint(c, n)
		local t = (c - poll):Dot(D) / hl
		local u = n:Dot(U)
		if t > 0.95 and u > -0.05 then
			return "Nose", noseCol -- the nose pad: the top front of the muzzle
		end
		if t > 0.4 and u < -0.7 then
			return "Head", mouthCol -- roof of the mouth (hidden while the jaw is closed)
		end
		if t > 0.45 and u < 0 then
			return "Head", cream -- muzzle sides, low
		end
		if t > 0.1 and t < 0.45 and math.abs(n.X) > 0.6 and u < 0.2 then
			return "Head", cream -- cheeks
		end
		return "Head", face
	end
	hull(m, hrings, headPaint)
	cap(m, hrings[1], poll - D * 0.1, headPaint)
	cap(m, hrings[#hrings], nose + D * 0.06, headPaint)
	-- lower jaw: tucked inside the upper while closed; dark mouth on top, cream underneath
	jaw(m, poll, D, U, hl, { { 0.28, 0.32, -0.02, -0.44 }, { 0.47, 0.26, -0.02, -0.36 }, { 0.75, 0.21, -0.02, -0.29 },
		{ 0.94, 0.17, -0.02, -0.24 }, { 0.99, 0.12, -0.02, -0.19 } }, function(c, n)
		if n:Dot(U) > 0.6 then
			return "Jaw", mouthCol
		end
		return "Jaw", n:Dot(U) < -0.3 and cream or cream:Lerp(face, 0.35)
	end)
	m:SetAttribute("JawPivot", poll + D * hl * 0.27 - U * 0.14) -- made relative to the root below
	-- fangs: upper ones hang into the closed jaw, lower ones reach up into the upper jaw (hidden
	-- until the mouth opens); roots sit inside their own jaw
	for _, sx in ipairs({ -1, 1 }) do
		local uf = poll + D * hl * 0.88 + X * sx * 0.13 - U * 0.02
		tuft(m, uf, (-U - D * 0.15).Unit, D, 0.15, 0.035, "Teeth", toothCol, X * sx * 0.03 + U * 0.02)
		local lf = poll + D * hl * 0.83 + X * sx * 0.1 - U * 0.08
		tuft(m, lf, (U - D * 0.1).Unit, D, 0.13, 0.03, "Jaw", toothCol, X * sx * 0.03 - U * 0.02)
		local inc = poll + D * hl * 0.97 + X * sx * 0.05 - U * 0.02
		tuft(m, inc, -U, X, 0.07, 0.025, "Teeth", toothCol, D * 0.03)
	end
	-- eyes (user's side-view wolf ref): a thin almond on the side of the head just under the brow
	-- edge, slanting up toward the ear; a dark outline, an amber iris with a dark pupil and a glint,
	-- a pale brow patch above and a dark tear line running forward-down from the front corner.
	-- Layers sit 0.02 proud of the one below; the outline's back is sunk into the face.
	local irisCol = o.EyeGlow or o.EyeCol or Color3.fromRGB(226, 182, 58)
	local dark = Color3.fromRGB(22, 20, 24)
	for _, sx in ipairs({ -1, 1 }) do
		-- on the forward-angled side face between the brow and the stop rings
		local tE = 0.39
		local hwE, topE = headAt(tE)
		local hwA, hwB = headAt(0.28), headAt(0.5)
		local along = (D * hl * 0.22 + X * sx * (hwB - hwA) * SIDE6).Unit -- down the face, toward the nose
		local n = along:Cross(U).Unit
		if n:Dot(X * sx) < 0 then
			n = -n
		end
		local c = poll + D * hl * tE + X * sx * hwE * SIDE6 + U * (topE * RISE6 - 0.1)
		local e1 = (-along * 0.93 + U * 0.36).Unit -- front corner -> back corner (up toward the ear)
		local e2 = n:Cross(e1).Unit
		if e2:Dot(U) < 0 then
			e2 = -e2
		end
		local function at(o2, x, y)
			return o2 + e1 * x + e2 * y
		end
		local function fan(o2, pts, thick, col, mat, name)
			for i = 1, #pts do
				T(m, name or "Eye", col, o2, pts[i], pts[i % #pts + 1], thick, mat)
			end
		end
		local L, H = 0.15, 0.055
		local o1 = c + n * 0.005
		fan(o1, { at(o1, -L, -0.1 * H), at(o1, -0.3 * L, 0.9 * H), at(o1, 0.45 * L, H), at(o1, L, 0.3 * H),
			at(o1, 0.3 * L, -0.75 * H), at(o1, -0.45 * L, -0.85 * H) }, 0.08, dark)
		local ic = c - e1 * 0.025
		local function hex(cen, r, squash, lift, thick, col, mat)
			local o2 = cen + n * lift
			local pts = {}
			for k = 0, 5 do
				local ang = k / 6 * math.pi * 2 + math.pi / 6
				table.insert(pts, at(o2, math.cos(ang) * r, math.sin(ang) * r * squash))
			end
			fan(o2, pts, thick, col, mat)
		end
		-- the amber fills the almond (inset 0.7), with a small pupil toward the front
		local o3 = c + n * 0.045
		local k = 0.72
		fan(o3, { at(o3, -L * k, -0.1 * H * k), at(o3, -0.3 * L * k, 0.9 * H * k), at(o3, 0.45 * L * k, H * k), at(o3, L * k, 0.3 * H * k),
			at(o3, 0.3 * L * k, -0.75 * H * k), at(o3, -0.45 * L * k, -0.85 * H * k) }, 0.04, irisCol, o.EyeGlow and Enum.Material.Neon or nil)
		hex(ic, 0.017, o.EyeGlow and 1.8 or 1.1, 0.065, 0.03, dark)
		local g = ic + n * 0.085 + e1 * 0.03 + e2 * 0.012
		T(m, "Eye", Color3.fromRGB(252, 252, 250), g + e2 * 0.012, g + e1 * 0.012, g - e2 * 0.01, 0.02)
		-- pale brow patch above the eye and a dark tear line from its front corner (0.03 proud)
		local bp = c + n * 0.03
		T(m, "Head", cream:Lerp(face, 0.2), at(bp, -0.17, 0.07), at(bp, 0.17, 0.1), at(bp, 0.0, 0.125), 0.05)
		local tl = c + n * 0.03
		T(m, "Head", dark, at(tl, -L - 0.01, -0.01), at(tl, -L - 0.07, -0.08), at(tl, -L + 0.02, -0.045), 0.05)
	end
	-- the ruff (refs: low-poly wolf head): faceted fur spikes framing the face from below the ears
	-- down to the chin, and a few hanging off the throat; spacing, size and angle vary, and every
	-- spike's root starts inside the head or neck so nothing floats
	local RUFF = { -- angle from the top of the head (degrees), t along the head, length, root radius
		{ 62, 0.12, 0.62, 0.17 }, { 104, 0.18, 0.66, 0.18 }, { 146, 0.2, 0.5, 0.16 },
	}
	for _, sx in ipairs({ -1, 1 }) do
		for i3, r in ipairs(RUFF) do
			local a = math.rad(r[1] + (sx > 0 and 0 or 4))
			local hw, top, bot = headAt(r[2])
			local radial = (X * sx * math.sin(a) + U * math.cos(a)).Unit
			local reach = math.cos(a) > 0 and top or bot
			local base = poll + D * hl * r[2] + X * sx * math.sin(a) * hw * 0.8 + U * math.cos(a) * reach * 0.8
			local dir = (radial - D * (0.55 + 0.1 * (i3 % 2))).Unit
			local len = r[3] * (sx > 0 and 0.85 or 0.8)
			local tangent = (X * sx * math.cos(a) - U * math.sin(a)).Unit
			local col = r[1] > 150 and cream:Lerp(face, 0.5) or face
			tuft(m, base, dir, tangent, len, r[4] * 1.5, "Head", col, -D * 0.16)
		end
	end
	local throat = NECK[2][1]
	for i3, a in ipairs({ 140, 180, 220 }) do
		local ar = math.rad(a)
		local nd = (NECK[3][1] - NECK[1][1]).Unit
		local upN = (Y - nd * Y:Dot(nd)).Unit
		local side = nd:Cross(upN).Unit
		local radial = (side * math.sin(ar) + upN * math.cos(ar)).Unit
		local base = throat + radial * 0.32
		local dir = (radial + Vector3.new(0, -0.35, 0.25)).Unit
		local len = 0.3 + 0.08 * ((i3 * 7) % 3)
		local tangent = (side * math.cos(ar) - upN * math.sin(ar)).Unit
		tuft(m, base, dir, tangent, len * 1.15, 0.22, "Neck", cream:Lerp(mane, 0.35), Vector3.new(0, 0.04, 0.16))
	end
	for _, sx in ipairs({ -1, 1 }) do
		-- angled out about 40 degrees from vertical (refs), opening forward and a little out
		local root = poll + D * hl * 0.1 + U * 0.36 + X * sx * 0.22
		local es = o.EarScale or 1
		ear(m, root, (X * sx * 0.72 + U * 0.88 - D * 0.15).Unit, (-D + X * sx * 0.45).Unit, 0.72 * es, 0.27 * es, mane, cream:Lerp(mane, 0.35))
	end
	-- bushy tail with a dark tip
	-- tail (refs): runs back off the rump, bends, then sweeps up into a big flat plume with a sharp tip;
	-- diamond sections, thin side to side and tall in profile, like papercraft
	local TAIL = { { V(0, 2.62, 1.5), 0.13, 0.2, 0.2 }, { V(0, 2.32, 2.2), 0.15, 0.32, 0.3 }, { V(0, 2.95, 2.78), 0.14, 0.32, 0.3 },
		{ V(0, 3.55, 3.2), 0.09, 0.2, 0.18 } }
	local TIP = V(0, 4.0, 3.55)
	local tipCol = o.TailTip or Color3.fromRGB(34, 32, 34)
	-- one tail, or a fan of them (a nine-tailed fox): each turns about the tail root by its own yaw
	-- and lift, so the plumes spread up and out behind the rump; the middle one stays the tallest
	local nTails = math.clamp(o.Tails or 1, 1, 9)
	local fluff = o.TailFluff or 1
	local rootT = TAIL[1][1]
	for k = 1, nTails do
		local f = (nTails == 1) and 0 or ((k - 1) / (nTails - 1) * 2 - 1) -- -1 .. 1 across the fan
		local yaw = math.rad(f * 62)
		local lift = math.rad(-math.abs(f) * 24 + (k % 2) * 6) -- outer tails droop a little, alternate ones rise
		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(lift, 0, 0)
		local function tp(p)
			return rootT + rot:VectorToWorldSpace(p - rootT)
		end
		local trings = {}
		for i2, r in ipairs(TAIL) do
			local d = (tp(TAIL[math.min(i2 + 1, #TAIL)][1]) - tp(TAIL[math.max(i2 - 1, 1)][1])).Unit
			local side = rot:VectorToWorldSpace(X)
			local w = (i2 >= 2) and fluff or 1
			table.insert(trings, ring(tp(r[1]), side, side:Cross(d).Unit, r[2] * w, r[3] * w, r[4] * w, 4, 1))
		end
		hull(m, trings, function(c, n, i2)
			return "Tail", i2 >= 3 and back:Lerp(tipCol, 0.35) or back
		end)
		if k == 1 then
			cap(m, trings[1], rootT - V(0, -0.05, 0.25), function()
				return "Tail", back
			end)
		end
		-- the tip: Neon foxfire when TailGlow is set (its own parts, so scripts can relight it)
		cap(m, trings[#trings], tp(TIP), function()
			if o.TailGlow then
				return "TailGlow", o.TailGlow, Enum.Material.Neon
			end
			return "Tail", tipCol
		end)
	end

	-- legs: digitigrade, on padded paws
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 0.3
		local S, E, W, Pw = V(x, 2.45, -1.15), V(x, 1.42, -1.12), V(x, 0.38, -1.2), V(x, 0.15, -1.2)
		legModel(m, "LegFront", sx, { S, E, W, Pw }, {
			{ { S + up * 0.25 + V(0, 0, 0.08), S, E }, { { 0.17, 0.27 }, { 0.23, 0.4 }, { 0.2, 0.25 } }, { mane, mane } },
			{ { E + up * 0.12, W }, { { 0.17, 0.21 }, { 0.15, 0.18 } }, { coat } },
			{ { W + up * 0.1, Pw }, { { 0.12, 0.15 }, { 0.13, 0.16 } }, { legCol } },
			{ { Pw + up * 0.06, Pw + V(0, -0.02, -0.05) }, { { 0.11, 0.13 }, { 0.12, 0.14 } }, { legCol },
				extra = function(sm)
					paw(sm, Pw.Z + 0.1, x, 0.8, 0.17, pawCol, clawCol)
				end },
		})
		x = sx * 0.3
		local P, St, Hk = V(x, 2.35, 1.16), V(x, 1.55, 0.92), V(x, 0.65, 2.1)
		local Pb = V(x, 0.15, 2.12)
		legModel(m, "LegBack", sx, { P, St, Hk, Pb }, {
			{ { P + up * 0.2 + V(0, 0, 0.1), P, St }, { { 0.18, 0.3 }, { 0.22, 0.46 }, { 0.2, 0.27 } }, { coat, coat } },
			{ { St + V(0, 0.12, -0.04), Hk + V(0, 0, 0.04) }, { { 0.17, 0.23 }, { 0.15, 0.17, 0.22 } }, { coat } },
			{ { Hk + up * 0.1, Pb }, { { 0.12, 0.15 }, { 0.13, 0.16 } }, { legCol } },
			{ { Pb + up * 0.06, Pb + V(0, -0.02, -0.05) }, { { 0.11, 0.13 }, { 0.12, 0.14 } }, { legCol },
				extra = function(sm)
					paw(sm, Pb.Z + 0.1, x, 0.75, 0.17, pawCol, clawCol)
				end },
		})
	end
	local rootC = V(0, 2.2, 0)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", V(1.0, 1.4, 3.2))
	m:SetAttribute("NeckBase", V(0, 2.6, -1.1) - rootC)
	m:SetAttribute("HeadPivot", poll - rootC) -- the poll: the head tilts here, the neck bends at NeckBase
	m:SetAttribute("JawPivot", m:GetAttribute("JawPivot") - rootC)
	m:SetAttribute("Length", 5.0) -- nose to rump (the raised tail rides above)
	m:SetAttribute("Stride", 3.0)
	return V(1.2, 4.3, 7.0)
end

-- A jointed limb that isn't a leg (wings, a tail fan, a bird's or dragon's legs): Model "Chain",
-- attribute Chain = motor prefix ("RW" makes RW1, RW2, ...), On = what it hangs on (see Creatures.rig).
-- builders[i](segModel) makes each segment's parts; joints[i] is its hinge.
local function chain(m, tag, on, joints, builders)
	local lm = Instance.new("Model")
	lm.Name = "Chain"
	lm:SetAttribute("Chain", tag)
	lm:SetAttribute("On", on)
	for i, build in ipairs(builders) do
		local sm = Instance.new("Model")
		sm.Name = "Seg" .. i
		build(sm)
		local att = Instance.new("Attachment")
		att.Name = "Joint"
		att.Parent = sm:FindFirstChildWhichIsA("BasePart")
		att.WorldCFrame = CFrame.new(joints[i])
		sm.Parent = lm
	end
	lm.Parent = m
	return lm
end

-- an aura node (Auras looks these up by name) at world point p on a model's first part
local function auraNode(host, name, p)
	local a = Instance.new("Attachment")
	a.Name = "Aura" .. name
	a.Parent = host:FindFirstChildWhichIsA("BasePart", true)
	a.WorldCFrame = CFrame.new(p)
end

-- Bird, raptor build (blueprint "Bird"; design scale 5 beak to tail, faces -Z, hovers): teardrop body
-- in feather scales, a hooked beak, wings of three jointed segments carrying layered feather plates,
-- a fan tail, and legs that trail in flight with talons.
-- opts: Coat, Back, Belly, WingTip, Beak, Leg, Glow (Neon veins in the primaries), EyeGlow, Hair (2 crest
--   colours), Primaries (count), Hover (design units)
recipes.Bird = function(m, o)
	local coat = o.Coat or Color3.fromRGB(60, 92, 170)
	local back = o.Back or coat:Lerp(Color3.new(0, 0, 0), 0.3)
	local belly = o.Belly or Color3.fromRGB(200, 208, 222)
	local wingTip = o.WingTip or back
	local beak = o.Beak or Color3.fromRGB(226, 184, 84)
	local legCol = o.Leg or Color3.fromRGB(190, 150, 70)
	local claw = Color3.fromRGB(32, 30, 36)
	local V, Y = Vector3.new, Vector3.yAxis
	local pickBody = function(i)
		local f = rnd(i, 11)
		return f < 0.5 and coat or (f < 0.8 and back or coat:Lerp(belly, 0.3))
	end

	local TORSO = { { -1.1, 2.35, 0.25, 0.3, 0.3 }, { -0.85, 2.3, 0.55, 0.6, 0.7 }, { -0.35, 2.25, 0.72, 0.72, 0.85 },
		{ 0.25, 2.25, 0.62, 0.6, 0.62 }, { 0.8, 2.3, 0.38, 0.36, 0.36 }, { 1.25, 2.35, 0.18, 0.17, 0.17 } }
	local rings = {}
	for _, r in ipairs(TORSO) do
		table.insert(rings, ring(V(0, r[2], r[1]), X, Y, r[3], r[4], r[5], BODY_SIDES, BOX))
	end
	local function bodyPaint(c, n)
		if n.Y < -0.35 then
			return "Body", belly
		end
		return "Body", coat
	end
	hull(m, rings, bodyPaint)
	cap(m, rings[1], V(0, 2.32, -1.28), bodyPaint)
	cap(m, rings[#rings], V(0, 2.36, 1.4), bodyPaint)
	local band = { rings[2], rings[3], rings[4], rings[5] }
	local wader, lite = o.Wader, o.Lite
	if not lite then
		for _, k in ipairs({ 1, 2, 5, 6 }) do
			scaleStrip(m, "Body", band, k, 0, 1, 2, 0.5, 1, pickBody)
		end
	end

	-- neck and head (a crane's neck is long and S-curved, its head high)
	local lift = wader and 1.25 or 0
	local poll, nose = V(0, 3.32 + lift, -1.22 - (wader and 0.5 or 0)), V(0, 3.14 + lift, -2.0 - (wader and 0.5 or 0))
	local D = (nose - poll).Unit
	local U = X:Cross(D).Unit
	local hl = (nose - poll).Magnitude
	local NECK = { { V(0, 2.55, -0.72), 0.48, 0.5, 0.5 }, { V(0, 3.0, -1.0), 0.38, 0.38, 0.38 }, { poll + D * 0.14, 0.27, 0.27, 0.27 } }
	if wader then
		NECK = { { V(0, 2.5, -0.75), 0.34, 0.36, 0.36 }, { V(0, 3.05, -1.15), 0.2, 0.2, 0.2 }, { V(0, 3.65, -1.1), 0.17, 0.17, 0.17 }, { V(0, 4.15, -1.4), 0.15, 0.15, 0.15 }, { poll + D * 0.14, 0.17, 0.17, 0.17 } }
	end
	rings = {}
	for i, r in ipairs(NECK) do
		local d = (NECK[math.min(i + 1, #NECK)][1] - NECK[math.max(i - 1, 1)][1]).Unit
		table.insert(rings, ring(r[1], X, d:Cross(X).Unit, r[2], r[3], r[4], 6, BOX))
	end
	local neckPaint = function()
		return "Neck", coat:Lerp(belly, 0.25)
	end
	hull(m, rings, neckPaint)
	cap(m, rings[1], NECK[1][1] + V(0, -0.15, 0.2), neckPaint)
	cap(m, rings[#rings], NECK[#NECK][1] + D * 0.1, neckPaint)
	if not lite and not wader then
		for k = 1, 6 do
			scaleStrip(m, "Neck", rings, k, 0, 1, 2, 0.34, -1, pickBody)
		end
	end
	local HEAD = { { 0, 0.3, 0.32, 0.3 }, { 0.25, 0.37, 0.36, 0.34 }, { 0.6, 0.3, 0.3, 0.27 }, { 1, 0.17, 0.17, 0.15 } }
	rings = {}
	for _, r in ipairs(HEAD) do
		table.insert(rings, ring(poll + D * hl * r[1], X, U, r[2], r[3], r[4], 6, BOX))
	end
	local headPaint = function()
		return "Head", coat:Lerp(belly, 0.45)
	end
	hull(m, rings, headPaint)
	cap(m, rings[1], poll - D * 0.08, headPaint)
	cap(m, rings[#rings], nose + D * 0.05, headPaint)
	-- hooked upper beak, lower beak on the jaw hinge
	local bk = nose - D * 0.12
	if wader then
		-- a long straight dagger beak and a red crown patch
		tube(m, { bk, bk + D * 0.5, bk + D * 1.05 }, { 0.12, 0.08, 0.02 }, "Head", beak, 4)
		if o.Crown then
			T(m, "Head", o.Crown, poll + U * 0.39 + D * 0.02 + X * 0.14, poll + U * 0.39 + D * 0.02 - X * 0.14, poll + U * 0.34 + D * 0.42, 0.04)
		end
	else
		tube(m, { bk + U * 0.04, bk + D * 0.3 + U * 0.03, bk + D * 0.56 - U * 0.08, bk + D * 0.66 - U * 0.3 }, { 0.15, 0.13, 0.09, 0.03 }, "Head", beak, 5)
	end
	local jawAt = bk - U * 0.13
	tube(m, { jawAt, jawAt + D * 0.25 - U * 0.02, jawAt + D * 0.42 - U * 0.05 }, { 0.09, 0.08, 0.03 }, "Jaw", beak:Lerp(Color3.new(0, 0, 0), 0.15), 4)
	for _, sx in ipairs({ -1, 1 }) do
		local c = poll + D * hl * 0.34 + U * 0.08 + X * sx * 0.32
		eye(m, c, X * sx, U * 0.08, D * 0.1, o.EyeGlow or Color3.fromRGB(24, 22, 26), o.EyeGlow ~= nil)
		-- brow ridge, the raptor's glare
		local a, b = poll + D * hl * 0.08 + U * 0.3 + X * sx * 0.22, poll + D * hl * 0.56 + U * 0.17 + X * sx * 0.24
		tube(m, { a, a:Lerp(b, 0.5) + U * 0.03, b }, { 0.06, 0.06, 0.03 }, "Head", back, 4)
	end
	-- storm crest swept back off the crown
	if o.Hair then
		for i = 1, 8 do
			local sx = i % 2 == 0 and 1 or -1
			local dir = (V(sx * (0.15 + rnd(i, 3) * 0.35), 0.5 + rnd(i, 4) * 0.45, 0.85)).Unit
			local L = (1.05 + rnd(i, 5) * 0.55) / 3
			local p = poll + U * 0.26 + D * (i * 0.03) + X * sx * (0.04 + (i // 2) * 0.03)
			local pts = { p }
			for k = 1, 3 do
				p += (dir + V(0, -0.1 * k, 0)).Unit * L
				table.insert(pts, p)
			end
			strand(m, "Head", pts, (X * sx * 0.25 + V(0, 0.95, -0.2)).Unit, 0.11 + rnd(i, 6) * 0.04, o.Hair[(i % 2) + 1])
		end
	end

	-- one feather: a keeled leaf from root along dir, lifted a little so that no two share a plane
	local function feather(sm, root, dir, len, w, col, lift, vein)
		local side = dir:Cross(Y).Unit
		local n = side:Cross(dir).Unit
		if n.Y < 0 then
			n = -n
		end
		local base = root + n * lift
		local mid = base + dir * len * 0.5
		local tip = base + dir * len
		T(sm, "Feather", col, base, mid + side * w + n * 0.02, tip, 0.05)
		T(sm, "Feather", col, base, tip, mid - side * w - n * 0.03, 0.05)
		if vein then
			-- a Neon vein along the top of the feather, its own parts so scripts can relight it
			local a, b = base + dir * len * 0.2 + n * 0.05, base + dir * len * 0.86 + n * 0.05
			T(sm, "Glow", vein, a + side * 0.03, b, a - side * 0.03, 0.02, Enum.Material.Neon)
		end
	end

	local prim = o.Primaries or 10
	for _, sx in ipairs({ -1, 1 }) do
		local Sh, El, Wr, Tip = V(sx * 0.52, 2.72, -0.42), V(sx * 1.95, 3.02, -0.32), V(sx * 3.35, 3.08, -0.42), V(sx * 4.9, 2.95, -0.1)
		local function row(sm, from, to, count, lenA, lenB, w, cols, lift, step, outA, outB, vein)
			for i = 1, count do
				local t = (i - 0.5) / count
				local dir = (V(sx * (outA + (outB - outA) * t), -0.04, 1)).Unit
				local len = lenA + (lenB - lenA) * t + (rnd(i * sx + 30, 5) - 0.5) * 0.12
				feather(sm, from:Lerp(to, t), dir, len, w, cols(i, t), lift + i * step, vein)
			end
		end
		local mainCol = function(i, t)
			return back:Lerp(wingTip, t * 0.5 + (i % 2) * 0.12)
		end
		local upper = function(i)
			return pickBody(i * 3 + 1)
		end
		chain(m, sx > 0 and "RW" or "LW", "Hips", { Sh, El, Wr }, {
			function(sm)
				tube(sm, { Sh - V(sx * 0.1, 0, 0), Sh:Lerp(El, 0.5) + V(0, 0.03, 0), El }, { 0.2, 0.18, 0.15 }, "Wing", coat, 4)
				row(sm, Sh, El, 5, 1.7, 2.1, 0.26, mainCol, 0.0, 0.016, 0.02, 0.08)
				if not lite then
					row(sm, Sh, El, 5, 0.85, 1.0, 0.26, upper, 0.13, 0.016, 0.02, 0.08)
				end
			end,
			function(sm)
				tube(sm, { El, El:Lerp(Wr, 0.5) + V(0, 0.02, 0), Wr }, { 0.15, 0.13, 0.11 }, "Wing", coat, 4)
				row(sm, El, Wr, 7, 2.1, 2.3, 0.27, mainCol, 0.0, 0.016, 0.08, 0.22)
				if not lite then
					row(sm, El, Wr, 6, 1.0, 1.05, 0.28, upper, 0.13, 0.016, 0.08, 0.22)
				end
			end,
			function(sm)
				tube(sm, { Wr, Wr:Lerp(Tip, 0.5), Tip }, { 0.11, 0.09, 0.05 }, "Wing", coat, 4)
				row(sm, Wr, Tip, prim, 2.35, 1.9, 0.24, function(i, t)
					return wingTip:Lerp(back, 0.6 - t * 0.6)
				end, 0.0, 0.016, 0.3, 2.3, o.Glow)
				if not lite then
					row(sm, Wr, Tip, 5, 1.05, 0.8, 0.24, upper, 0.14, 0.016, 0.3, 1.6)
				end
				auraNode(sm, sx > 0 and "WingR" or "WingL", Wr:Lerp(Tip, 0.4))
			end,
		})
		-- legs trail in the air (thigh, shank, foot with four talons)
		local H, Kn, An, Fo = V(sx * 0.34, 1.9, 0.12), V(sx * 0.38, 1.25, 0.34), V(sx * 0.38, 0.5, 0.14), V(sx * 0.38, 0.12, 0.08)
		if wader then
			Kn, An, Fo = V(sx * 0.3, 1.0, 0.4), V(sx * 0.3, -0.1, 0.25), V(sx * 0.3, -0.55, 0.2)
		end
		chain(m, sx > 0 and "RH" or "LH", "Hips", { H, Kn, An }, {
			function(sm)
				tube(sm, { H + Y * 0.12, H:Lerp(Kn, 0.5), Kn }, { 0.27, 0.24, 0.13 }, "Leg", coat:Lerp(belly, 0.3), 5)
			end,
			function(sm)
				tube(sm, { Kn + Y * 0.04, Kn:Lerp(An, 0.5), An }, { 0.12, 0.09, 0.09 }, "Leg", legCol, 4)
			end,
			function(sm)
				tube(sm, { An + Y * 0.03, Fo }, { 0.09, 0.11 }, "Leg", legCol, 4)
				for i, off in ipairs({ V(-0.14, 0, -0.32), V(0, 0, -0.4), V(0.14, 0, -0.32), V(0, 0, 0.3) }) do
					local a = Fo + V(off.X * 0.4, -0.02, off.Z * 0.3)
					tube(sm, { a, a + off * 0.65, a + off + V(0, -0.1, 0) }, { 0.055, 0.05, 0.015 }, "Claw", i == 4 and claw or claw:Lerp(legCol, 0.1), 3)
				end
			end,
		})
	end
	-- fan tail on its own joint
	local tailRoot = V(0, 2.36, 1.05)
	chain(m, "TailFan", "Hips", { tailRoot }, {
		function(sm)
			local count = 9
			for i = 1, count do
				local f = (i - (count + 1) / 2) / ((count - 1) / 2)
				local dir = (V(f * 0.62, -0.05 - math.abs(f) * 0.04, 1)).Unit
				feather(sm, tailRoot + V(f * 0.14, 0, 0), dir, 2.15 - math.abs(f) * 0.3, 0.2, back:Lerp(wingTip, 0.3 + (i % 2) * 0.2), (i % 3) * 0.022 + math.abs(f) * 0.02)
			end
		end,
	})

	local rootC = V(0, 2.25, 0)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", V(1.4, 1.6, 2.4))
	m:SetAttribute("NeckBase", V(0, 2.75, -0.72) - rootC)
	m:SetAttribute("HeadPivot", poll - rootC)
	m:SetAttribute("JawPivot", jawAt - rootC)
	m:SetAttribute("Length", 5)
	m:SetAttribute("Stride", 3)
	m:SetAttribute("RigKind", "Bird")
	m:SetAttribute("Hover", o.Hover or (wader and 1.7 or 1.2))
	return V(2, 4.2, 5)
end

-- Long dragon (blueprint "Serpent", Dragon build; design scale ~10 long, faces -Z, no wings: it swims
-- through the air): 12 hinged spine segments in scales with a gold belly, a mane along the back, a long
-- head with whiskers, beard and branched horns, and four short legs with talons.
-- opts: Coat, Back, Belly, Mane (2 colours), Horn, Glow (whiskers), EyeGlow
recipes.Serpent = function(m, o)
	local coat = o.Coat or Color3.fromRGB(52, 118, 220)
	local backCol = o.Back or coat:Lerp(Color3.new(0, 0, 0), 0.28)
	local belly = o.Belly or Color3.fromRGB(240, 205, 120)
	local maneCols = o.Mane or { Color3.fromRGB(246, 248, 255), Color3.fromRGB(205, 222, 246) }
	local horn = o.Horn or Color3.fromRGB(240, 222, 160)
	local glow = o.Glow or Color3.fromRGB(130, 200, 255)
	local V, Y = Vector3.new, Vector3.yAxis
	local dragon = o.Dragon
	local g = o.Girth or 1
	local z0, seg = -3.0, 0.75
	local GIRTH = { 0.34, 0.42, 0.5, 0.55, 0.55, 0.5, 0.46, 0.4, 0.33, 0.26, 0.18, 0.11, 0.05 }
	if not dragon then
		for i, r in ipairs(GIRTH) do
			GIRTH[i] = r * g * 0.8
		end
	end
	local y0 = dragon and 2.0 or GIRTH[4] * 0.9
	local pick = function(i)
		local f = rnd(i, 13)
		return f < 0.5 and coat or (f < 0.82 and backCol or coat:Lerp(Color3.new(1, 1, 1), 0.22))
	end
	local function ringAt(i, shift, shrink)
		local r = GIRTH[i] * shrink
		return ring(V(0, y0, z0 + (i - 1) * seg + shift), X, Y, r, r, r * 0.86, 6, BOX)
	end
	for i = 1, 12 do
		local banded = o.Bands and i % 2 == 0
		local function paint(c, n)
			if n.Y < -0.35 then
				return "Body", belly
			end
			if banded then
				return "Body", o.BandGlow or o.Band or backCol, o.BandGlow and Enum.Material.Neon or nil
			end
			return "Body", coat
		end
		local sm = Instance.new("Model")
		sm.Name = "Spine" .. i
		-- each segment starts just inside the one before it, so bending never shows a gap
		local A, B = ringAt(i, -0.05, 0.95), ringAt(i + 1, 0, 1)
		hull(sm, { A, B }, paint)
		if i == 12 then
			cap(sm, B, V(0, y0, z0 + 12 * seg + 0.3), paint)
		end
		if (dragon or o.Scaled) and GIRTH[i + 1] > 0.1 * g then
			for _, k in ipairs({ 1, 2, 5, 6 }) do
				scaleStrip(sm, "Body", { A, B }, k, 0, 1, 1, 0.6, 1, pick)
			end
		end
		-- the hinge: forward segments turn at their back end, rearward ones at their front (Spine4 mid)
		local hinge = i < 4 and z0 + i * seg or (i == 4 and z0 + 3.5 * seg or z0 + (i - 1) * seg)
		local att = Instance.new("Attachment")
		att.Name = "Joint"
		att.Parent = sm:FindFirstChildWhichIsA("BasePart")
		att.WorldCFrame = CFrame.new(0, y0, hinge)
		sm.Parent = m
		-- mane along the back, wind-swept; a tail plume at the end
		local strands = dragon and (i >= 11 and 4 or 2) or 0
		for s = 1, strands do
			local sx = s % 2 == 0 and 1 or -1
			local top = V(sx * 0.03 * s, y0 + GIRTH[i] * 0.92, z0 + (i - 1) * seg + seg * (s - 0.5) / strands)
			if i == 12 then
				top = V(sx * 0.03 * s, y0 + 0.02, z0 + 12 * seg - 0.05)
			end
			local seedA, seedB = rnd(i * 7 + s, 1), rnd(i * 7 + s, 2)
			local dir = (V(sx * (0.28 + seedB * 0.34), 0.28 + seedA * 0.3, 1)).Unit
			local L = ((i == 12 and 1.5 or 1.05) + seedA * 0.5) / 3
			local p = top - dir * 0.05
			local pts = { p }
			for k = 1, 3 do
				p += (dir + V(0, -0.12 * k, math.sin(k + i) * 0.1)).Unit * L
				table.insert(pts, p)
			end
			strand(m, "Spine" .. i, pts, (V(sx * 0.3, 0.95, -0.2)).Unit, (i == 12 and 0.16 or 0.11) + seedB * 0.04, maneCols[(i + s) % 2 + 1])
		end
	end
	auraNode(m.Spine4, "Core", V(0, y0, z0 + 3.5 * seg))
	auraNode(m.Spine2, "Back", V(0, y0 + 0.4, z0 + 1.5 * seg))
	auraNode(m.Spine12, "Tail", V(0, y0, z0 + 11.8 * seg))

	-- head: long, low, with a broad muzzle
	local headLen = dragon and 1.65 or 1.15 * math.sqrt(g)
	local poll, nose = V(0, y0 + (dragon and 0.2 or 0.12 * g), z0 - 0.1), V(0, y0 + (dragon and 0.02 or 0.02 * g), z0 - 0.1 - headLen)
	local D = (nose - poll).Unit
	local U = X:Cross(D).Unit
	local hl = (nose - poll).Magnitude
	local HEAD = { { 0, 0.3, 0.32, 0.32 }, { 0.2, 0.44, 0.42, 0.4 }, { 0.5, 0.33, 0.32, 0.3 }, { 0.72, 0.24, 0.23, 0.22 }, { 0.9, 0.3, 0.25, 0.2 }, { 1, 0.2, 0.15, 0.14 } }
	if not dragon then
		-- a viper's arrow head: wide at the jaw hinge, tapering to the snout
		HEAD = { { 0, 0.24 * g, 0.22 * g, 0.22 * g }, { 0.3, 0.42 * g, 0.26 * g, 0.24 * g }, { 0.7, 0.24 * g, 0.2 * g, 0.18 * g }, { 1, 0.12 * g, 0.1 * g, 0.1 * g } }
	end
	local rings = {}
	for _, r in ipairs(HEAD) do
		table.insert(rings, ring(poll + D * hl * r[1], X, U, r[2], r[3], r[4], 6, BOX))
	end
	local function headPaint(c, n)
		if n:Dot(U) < -0.4 then
			return "Head", belly
		end
		return "Head", coat
	end
	hull(m, rings, headPaint)
	cap(m, rings[1], poll - D * 0.12, headPaint)
	cap(m, rings[#rings], nose + D * 0.08, headPaint)
	if not dragon then
		-- snake head details: eyes, fangs, and a hood (Moon Viper) or a fin crest (Mire Serpent)
		for _, sx in ipairs({ -1, 1 }) do
			local c = poll + D * hl * 0.34 + U * 0.14 * g + X * sx * 0.33 * g
			eye(m, c, (X * sx + U * 0.4).Unit, U * 0.07 * g, D * 0.09 * g, o.EyeGlow or Color3.fromRGB(230, 200, 70), true)
			local f = poll + D * hl * 0.8 - U * 0.08 * g + X * sx * 0.1 * g
			tube(m, { f, f - U * 0.12 * g, f - U * 0.24 * g - D * 0.05 }, { 0.03 * g, 0.022 * g, 0.006 }, "Head", Color3.fromRGB(240, 236, 220), 3)
			if o.Hood then
				local h0 = poll - D * 0.5 + U * 0.04 * g
				for i = 1, 3 do
					local tip = h0 + X * sx * (0.45 + i * 0.22) * g + U * (0.62 - i * 0.14) * g + D * (i * 0.12 - 0.3)
					T(m, "Head", o.BandGlow or backCol, h0 + U * (0.26 - i * 0.04) * g, tip, h0 + X * sx * (0.12 + i * 0.1) * g - U * 0.05 * g, 0.04, o.BandGlow and Enum.Material.Neon or nil)
				end
			end
		end
		if o.Crest then
			for i = 1, 6 do
				local c = poll - D * (i * 0.13 - 0.5) + U * (0.2 * g)
				local off = X * (i % 2 == 0 and 0.05 or -0.05) -- side by side, so the fins never share a plane
				T(m, "Head", o.Fin or backCol, c + D * 0.1 + off, c - D * 0.12 + off, c + U * (0.42 - i * 0.03) * g - D * 0.26 + off * 2.2, 0.05)
			end
		end
	end
	-- lower jaw, slightly open
	local jw = poll + D * hl * 0.3 - U * 0.24 * (dragon and 1 or g * 0.75)
	if not dragon then
		tube(m, { jw, jw + D * hl * 0.3, jw + D * hl * 0.55 }, { 0.2 * g, 0.15 * g, 0.08 * g }, "Head", belly, 4)
	end
	if dragon then
	tube(m, { jw, jw + D * hl * 0.3 - U * 0.03, jw + D * hl * 0.6 - U * 0.06 }, { 0.22, 0.17, 0.1 }, "Head", belly, 5)
	for _, sx in ipairs({ -1, 1 }) do
		local c = poll + D * hl * 0.25 + U * 0.14 + X * sx * 0.385
		eye(m, c, (X * sx + U * 0.25).Unit, U * 0.09, D * 0.11, o.EyeGlow or Color3.fromRGB(255, 214, 120), true)
		-- brow ridge
		local a, b = poll + D * hl * 0.05 + U * 0.38 + X * sx * 0.24, poll + D * hl * 0.45 + U * 0.28 + X * sx * 0.25
		tube(m, { a, a:Lerp(b, 0.5) + U * 0.05, b }, { 0.07, 0.07, 0.03 }, "Head", backCol, 4)
		-- long Neon whiskers from the muzzle, trailing back
		local w = poll + D * hl * 0.9 + X * sx * 0.25
		tube(m, { w, w + X * sx * 0.55 + D * 0.12 + U * 0.08, w + X * sx * 1.15 - D * 0.35 - U * 0.06, w + X * sx * 1.5 - D * 1.25 - U * 0.5 },
			{ 0.026, 0.022, 0.016, 0.009 }, "Glow", glow, 3, Enum.Material.Neon)
		-- cheek fins
		for i = 1, 3 do
			local base = poll + D * hl * (0.16 + i * 0.04) - U * (0.1 + i * 0.05) + X * sx * 0.38
			tuft(m, base, (X * sx * 0.6 - D * 0.75 - U * 0.1 * i).Unit, (U + D * 0.3).Unit, 0.6 - i * 0.07, 0.1, "Head", maneCols[i % 2 + 1], -X * sx * 0.1)
		end
		-- branched horns sweeping back
		local hp = poll + U * 0.3 + D * 0.12
		local function at(x, y, z)
			return hp + V(sx * x, y, z)
		end
		local beam = { at(0.14, -0.06, 0), at(0.28, 0.35, 0.3), at(0.46, 0.7, 0.75), at(0.62, 0.95, 1.3), at(0.72, 1.12, 1.9) }
		tube(m, beam, { 0.1, 0.085, 0.07, 0.05, 0.025 }, "Antler", horn, 5)
		for _, t in ipairs({ { 2, V(0.2, 0.42, -0.1) }, { 3, V(0.22, 0.5, 0.05) }, { 4, V(0.2, 0.4, 0.16) } }) do
			local a2 = beam[t[1]]
			local b2 = a2 + V(sx * t[2].X, t[2].Y, t[2].Z)
			tube(m, { a2, a2:Lerp(b2, 0.55), b2 }, { 0.05, 0.04, 0.015 }, "Antler", horn, 3)
		end
	end
	-- chin beard and a crest at the poll
	for i = 1, 5 do
		local c = jw + D * hl * (0.14 + i * 0.08) - U * 0.12 + X * ((i - 3) * 0.06)
		local dir = (-U * 0.9 - D * 0.55 + X * ((i - 3) * 0.14)).Unit
		local L = (0.6 + rnd(i, 3) * 0.25) / 3
		local pts = { c, c + dir * L, c + (dir - D * 0.15).Unit * L * 2, c + (dir - D * 0.3).Unit * L * 3 }
		strand(m, "Head", pts, X, 0.08, maneCols[i % 2 + 1])
	end
	for i = 1, 6 do
		local sx = i % 2 == 0 and 1 or -1
		local dir = (V(sx * (0.3 + rnd(i, 4) * 0.3), 0.3 + rnd(i, 5) * 0.3, 0.95)).Unit
		local L = (1.0 + rnd(i, 6) * 0.45) / 3
		local p = poll + U * 0.3 + X * sx * (0.04 + i * 0.015)
		local pts = { p }
		for k = 1, 3 do
			p += (dir + V(0, -0.14 * k, 0)).Unit * L
			table.insert(pts, p)
		end
		strand(m, "Head", pts, (V(sx * 0.3, 0.95, -0.2)).Unit, 0.14 + rnd(i, 7) * 0.04, maneCols[i % 2 + 1])
	end

	-- four short legs on Spine3 and Spine8: shoulder, forearm, foot with three talons
	for _, sp in ipairs({ { 3, "F" }, { 8, "B" } }) do
		local zc = z0 + (sp[1] - 0.5) * seg
		local r = GIRTH[sp[1]]
		for _, sx in ipairs({ -1, 1 }) do
			local Sh, El, Wr = V(sx * r * 0.8, y0 - 0.08, zc), V(sx * (r + 0.32), y0 - 0.48, zc + 0.12), V(sx * (r + 0.36), y0 - 0.95, zc - 0.1)
			local Ft = Wr + V(0, -0.2, -0.02)
			chain(m, sp[2] .. (sx > 0 and "R" or "L"), "Spine" .. sp[1], { Sh, El, Wr }, {
				function(sm)
					tube(sm, { Sh, Sh:Lerp(El, 0.5), El }, { r * 0.42, 0.2, 0.14 }, "Leg", coat, 5)
				end,
				function(sm)
					tube(sm, { El, El:Lerp(Wr, 0.5), Wr }, { 0.14, 0.11, 0.09 }, "Leg", coat:Lerp(belly, 0.25), 4)
				end,
				function(sm)
					tube(sm, { Wr, Ft }, { 0.08, 0.11 }, "Leg", coat:Lerp(belly, 0.25), 4)
					for _, a in ipairs({ -0.5, 0, 0.5 }) do
						local dir = (V(math.sin(a), -0.15, -math.cos(a))).Unit
						tube(sm, { Ft, Ft + dir * 0.22, Ft + dir * 0.4 + V(0, -0.08, 0) }, { 0.045, 0.04, 0.012 }, "Claw", horn, 3)
					end
				end,
			})
		end
	end

	end
	local rootC = V(0, y0, z0 + 3.5 * seg)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", dragon and V(1.1, 1.1, 1.5) or V(1.1 * g, y0 * 1.9, 1.5))
	m:SetAttribute("HeadPivot", poll - rootC)
	m:SetAttribute("Length", 10)
	m:SetAttribute("Stride", 8)
	m:SetAttribute("RigKind", dragon and "Serpent" or "Snake")
	return V(1.6 * g, 3, 10)
end

-- Wolf, block style (user refs, 2026-10-27: Roblox wolves built from Parts and wedges): a big boxy
-- head with a dark brow bar over glowing eyes, a block muzzle with a dark nose and a separate jaw on
-- a hinge (black mouth, white fangs), layered wedge fur on the cheeks, chunky chest and shoulders,
-- thick block legs on big paws with toe blocks and black claws, and a raised block tail. Same rig
-- as the sculpted animals: legs are Seg1..Seg4 models with Joint attachments, the head hangs on a
-- "Neck" part, the lower jaw parts are "Jaw". Faces of touching blocks are kept >= 0.02 apart.
-- opts: Coat, Dark (brow, back fur, tail tip, inner ears), Light (chest, jaw, muzzle underside),
--   Paw, Eye (glow colour), Nose
recipes.WolfBlock = function(m, o)
	local coat = o.Coat or Color3.fromRGB(128, 128, 134)
	local dark = o.Dark or Color3.fromRGB(74, 74, 80)
	local light = o.Light or Color3.fromRGB(198, 196, 194)
	local pawCol = o.Paw or coat:Lerp(light, 0.4)
	local eyeCol = o.Eye or Color3.fromRGB(255, 226, 60)
	local noseCol = o.Nose or Color3.fromRGB(26, 26, 30)
	local black = Color3.fromRGB(14, 14, 16)
	local white = Color3.fromRGB(240, 238, 230)
	local V, CF, A, r = Vector3.new, CFrame.new, CFrame.Angles, math.rad
	local function B(parent, name, size, cf, col, mat)
		local p = newPart("Part", parent, cf, size, col, name)
		if mat then
			p.Material = mat
		end
		return p
	end
	local function W(parent, name, size, cf, col)
		return newPart("WedgePart", parent, cf, size, col, name)
	end

	-- K: a block with small chamfer wedges on its long edges (user: "small fraction edges to add more
	-- angularity", not wedges everywhere). c = chamfer, edges "all"/"top"/"bottom", axis = the edges' direction
	local function K(parent, name, size, cf, col, c, edges, axis)
		return block(parent, cf, size, col, { c = c, edges = edges or "all", axis = axis or "Z", name = name })
	end

	-- body: a deep chest and shoulders, a longer waist, the hips (chamfered edges)
	K(m, "Body", V(1.6, 1.55, 1.3), CF(0, 2.4, -0.95), coat, 0.18)
	K(m, "Body", V(1.3, 1.12, 1.6), CF(0, 2.52, 0.4), coat, 0.16)
	K(m, "Body", V(1.4, 1.14, 0.8), CF(0, 2.56, 1.5), coat, 0.21)
	B(m, "Body", V(0.8, 0.06, 1.2), CF(0, 3.1, 0.4), dark) -- dark saddle on the waist's flat top
	W(m, "Body", V(1.0, 0.3, 0.5), CF(0, 3.26, 1.6) * A(0, math.pi, 0), coat) -- the rump slopes down to the tail
	W(m, "Body", V(1.0, 0.6, 1.0), CF(0, 3.455, -1.1) * A(0, math.pi, 0), coat:Lerp(dark, 0.55)) -- crest: the dark mane, rising from the back to the back of the skull (covers the neck's top corner)
	W(m, "Body", V(1.0, 0.34, 0.5), CF(0, 1.81, -0.12) * A(math.pi, 0, 0), coat) -- the belly slopes up from the chest
	-- neck, leaning forward out of the chest (chamfered along its length); the head hinges on it
	K(m, "Neck", V(1.1, 1.2, 1.0), CF(0, 3.05, -1.6) * A(r(-35), 0, 0), coat, 0.16, "all", "Y")

	-- head: blocky (user), with the angles running forward and in toward the middle: a gable ridge on
	-- the skull top, an angry brow, cheekbone wedges and cheek planes sloping in to the muzzle
	B(m, "Head", V(1.25, 1.05, 1.05), CF(0, 3.5, -2.08), coat) -- skull
	B(m, "Head", V(1.06, 0.8, 0.3), CF(0, 3.5, -1.45), coat:Lerp(dark, 0.15)) -- back of the skull
	B(m, "Head", V(1.35, 0.45, 0.6), CF(0, 3.15, -2.2), coat) -- cheeks, wider than the skull
	for _, sx in ipairs({ -1, 1 }) do
		-- skull-top gable: a wedge each side rising from the edge to a ridge down the middle
		W(m, "Head", V(0.95, 0.16, 0.6), CF(sx * 0.3, 4.095, -2.08) * A(0, -sx * math.pi / 2, 0), coat:Lerp(dark, 0.08))
		-- brow: tilted down toward the nose; sockets and eyes tilted with it
		local tilt = A(0, 0, sx * r(12))
		B(m, "Head", V(0.66, 0.17, 0.26), CF(sx * 0.33, 3.8, -2.55) * tilt, dark)
		B(m, "Eye", V(0.3, 0.15, 0.06), CF(sx * 0.4, 3.6, -2.63) * tilt, black)
		B(m, "Eye", V(0.17, 0.09, 0.05), CF(sx * 0.41, 3.6, -2.67) * tilt, eyeCol, Enum.Material.Neon)
		-- cheek plane: a wedge from the cheek's front corner sloping forward and in to the muzzle side
		W(m, "Head", V(0.4, 0.32, 0.35), CFrame.fromMatrix(V(sx * 0.51, 3.2, -2.675), V(0, sx * -1, 0), V(sx, 0, 0)), coat)
	end
	W(m, "Head", V(0.46, 0.25, 0.35), CF(0, 3.555, -2.78), coat) -- nose bridge, sloping from the brow down the muzzle
	B(m, "Nose", V(0.38, 0.26, 0.15), CF(0, 3.41, -3.44), noseCol)

	-- muzzle: a block on top and thin walls round a hollow underneath, so the dark roof of the mouth
	-- sits up inside the muzzle, hidden from the side (user: "the black part inside of the mouth")
	B(m, "Head", V(0.7, 0.37, 0.85), CF(0, 3.265, -3.0), coat)
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Head", V(0.09, 0.14, 0.85), CF(sx * 0.305, 3.01, -3.0), coat) -- side walls
	end
	B(m, "Head", V(0.52, 0.14, 0.09), CF(0, 3.01, -3.38), coat) -- front wall (upper lip)
	B(m, "Head", V(0.52, 0.03, 0.73), CF(0, 3.065, -2.97), black) -- roof, recessed between the walls
	B(m, "Head", V(0.52, 0.14, 0.04), CF(0, 3.01, -2.6), black) -- back of the mouth
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Teeth", V(0.06, 0.16, 0.06), CF(sx * 0.19, 2.98, -3.27), white) -- upper fangs, rooted in the roof
	end
	-- lower jaw: the same build upside down, a dark floor recessed between its walls
	B(m, "Jaw", V(0.6, 0.14, 0.74), CF(0, 2.8, -2.97), light)
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Jaw", V(0.08, 0.07, 0.74), CF(sx * 0.26, 2.905, -2.97), light)
	end
	B(m, "Jaw", V(0.44, 0.07, 0.08), CF(0, 2.905, -3.3), light)
	B(m, "Jaw", V(0.44, 0.03, 0.66), CF(0, 2.885, -2.93), black) -- floor of the mouth
	B(m, "Jaw", V(0.26, 0.03, 0.4), CF(0, 2.91, -2.86), Color3.fromRGB(196, 92, 98)) -- tongue
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Jaw", V(0.06, 0.11, 0.06), CF(sx * 0.15, 2.99, -3.2), white) -- lower fangs
	end
	m:SetAttribute("JawPivot", V(0, 2.9, -2.55))
	-- ears: thick triangles on the skull's top corners, dark inside
	for _, sx in ipairs({ -1, 1 }) do
		T(m, "Ear", coat, V(sx * 0.18, 4.0, -1.98), V(sx * 0.6, 4.0, -1.98), V(sx * 0.46, 4.7, -1.88), 0.16)
		T(m, "Ear", dark, V(sx * 0.26, 4.04, -2.08), V(sx * 0.53, 4.04, -2.08), V(sx * 0.45, 4.5, -2.0), 0.04)
	end
	-- tail (user's reference): it drops down and back off the rump, widens into a brush, then curves
	-- back up into a flattened point. Blocks along one path, each tilted along it and overlapping the
	-- next, with small chamfers; the point is two wedges back to back
	local tp = V(0, 3.0, 1.8)
	local SEG = { { -42, 0.45, 0.36 }, { -58, 0.5, 0.44 }, { -50, 0.48, 0.5 }, { -32, 0.42, 0.46 } }
	local th
	for i, sg in ipairs(SEG) do
		th = r(sg[1])
		local dir = V(0, math.sin(th), math.cos(th))
		local c = tp + dir * sg[2] / 2
		local col = i == 1 and coat or coat:Lerp(dark, 0.1 + i * 0.07)
		K(m, "Tail", V(sg[3] * 0.85, sg[3], sg[2]), CF(c) * A(-th, 0, 0), col, sg[3] * 0.2)
		if i > 1 then
			-- a joint block at the bend, turned halfway between the two segments, closes the gap on the
			-- outside of the curve (slightly narrower so its sides stay inside the segments' sides)
			local prev = SEG[i - 1]
			local mid = r((prev[1] + sg[1]) / 2)
			local t = (prev[3] + sg[3]) / 2
			K(m, "Tail", V(t * 0.65, t * 0.97, t * 0.55), CF(tp) * A(-mid, 0, 0), col, t * 0.2)
		end
		tp = tp + dir * sg[2] * 0.8
	end
	th = r(-12) -- the point turns back up, starting inside the last segment
	local Ft = CF(tp) * A(-th, 0, 0)
	local w, hh, len = 0.36, 0.2, 0.62
	W(m, "Tail", V(w, hh, len), Ft * CF(0, hh / 2, len / 2) * A(0, math.pi, 0), dark)
	W(m, "Tail", V(w, hh, len), Ft * CF(0, -hh / 2, len / 2) * A(0, math.pi, 0) * A(0, 0, math.pi), dark)

	-- legs: chunky blocks on the real joints, big paws with toes and black claws
	local function legBlocks(name, sx, J, segs)
		local lm = Instance.new("Model")
		lm.Name = name
		lm:SetAttribute("Side", sx)
		for i, build in ipairs(segs) do
			local sm = Instance.new("Model")
			sm.Name = "Seg" .. i
			build(sm)
			local first = sm:FindFirstChildWhichIsA("BasePart")
			local att = Instance.new("Attachment")
			att.Name = "Joint"
			att.Parent = first
			att.WorldCFrame = CF(J[i])
			sm.Parent = lm
		end
		lm.Parent = m
	end
	local function paw(sm, x, z)
		B(sm, "Leg", V(0.56, 0.2, 0.6), CF(x, 0.1, z), pawCol)
		for _, dx in ipairs({ -0.15, 0, 0.15 }) do
			B(sm, "Leg", V(0.13, 0.16, 0.18), CF(x + dx, 0.1, z - 0.3), pawCol) -- toes
			W(sm, "Leg", V(0.06, 0.08, 0.12), CF(x + dx, 0.08, z - 0.43), black) -- claws, sloping to the tip
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 0.5
		legBlocks("LegFront", sx, { V(x, 2.45, -1.05), V(x, 1.5, -1.08), V(x, 0.58, -1.1), V(x, 0.2, -1.12) }, {
			function(sm) K(sm, "Leg", V(0.56, 1.05, 0.66), CF(x, 2.05, -1.05), coat, 0.1, "all", "Y") end,
			function(sm)
				B(sm, "Leg", V(0.46, 1.0, 0.5), CF(x, 1.05, -1.1), coat)
				B(sm, "Leg", V(0.5, 0.3, 0.3), CF(x, 1.52, -0.84), coat) -- the elbow point
			end,
			function(sm)
				B(sm, "Leg", V(0.4, 0.42, 0.4), CF(x, 0.38, -1.12), pawCol)
				B(sm, "Leg", V(0.5, 0.18, 0.6), CF(x, 0.6, -1.1), pawCol:Lerp(coat, 0.5)) -- the wrist
			end,
			function(sm) paw(sm, x, -1.25) end,
		})
		x = sx * 0.5
		local zb = 0.4 -- the hind legs sit under the hips, which moved back with the longer waist
		legBlocks("LegBack", sx, { V(x, 2.5, 1.1 + zb), V(x, 1.65, 0.95 + zb), V(x, 0.85, 1.42 + zb), V(x, 0.2, 1.4 + zb) }, {
			function(sm)
				K(sm, "Leg", V(0.68, 1.12, 1.0), CF(x, 2.18, 1.05 + zb) * A(r(15), 0, 0), coat, 0.13, "all", "Y")
				B(sm, "Leg", V(0.74, 0.62, 0.78), CF(x, 2.4, 1.1 + zb) * A(r(15), 0, 0), coat:Lerp(dark, 0.12)) -- thigh muscle
			end,
			function(sm) B(sm, "Leg", V(0.42, 0.9, 0.46), CF(x, 1.25, 1.2 + zb) * A(r(-28), 0, 0), coat) end,
			function(sm)
				B(sm, "Leg", V(0.36, 0.62, 0.4), CF(x, 0.5, 1.42 + zb), pawCol)
				B(sm, "Leg", V(0.46, 0.24, 0.26), CF(x, 0.86, 1.6 + zb), coat) -- the point of the hock
			end,
			function(sm) paw(sm, x, 1.3 + zb) end,
		})
	end

	-- carry the head and neck lower (user): the head group drops 0.35, the neck 0.2
	local HEADS = { Head = true, Eye = true, Nose = true, Teeth = true, Jaw = true, Ear = true }
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and (HEADS[p.Name] or p.Name == "Neck") then
			p.CFrame = p.CFrame - V(0, HEADS[p.Name] and 0.35 or 0.2, 0)
		end
	end
	m:SetAttribute("JawPivot", m:GetAttribute("JawPivot") - V(0, 0.35, 0))

	local rootC = V(0, 2.4, 0)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", V(1.2, 1.4, 3.4))
	m:SetAttribute("NeckBase", V(0, 2.75, -1.25) - rootC)
	m:SetAttribute("JawPivot", m:GetAttribute("JawPivot") - rootC)
	m:SetAttribute("Length", 5.0)
	m:SetAttribute("Stride", 2.8)
	return V(2.1, 4.6, 6.4)
end

-- Boar, block style (same build as WolfBlock; user refs: wild boar sketches): a big blocky head carried
-- low with a gable ridge, an angled brow over small eyes, a long snout ending in a pink disc, a hollow
-- snout and jaw with the dark mouth inside, tusks riding the lower jaw, small upright ears, a high
-- shoulder hump with a bristle crest of wedge fins, a smaller rump, short legs on cloven hooves and a
-- thin tail with a tuft. opts: Coat, Mane (forequarters, hump, crest), Belly (jaw), Leg, Hoof, Snout,
-- Tusk, TuskScale, Crest (fin height scale), EyeGlow, Bands (gold tusk bands), Spikes (bone spikes)
recipes.BoarBlock = function(m, o)
	local coat = o.Coat or Color3.fromRGB(110, 82, 62)
	local mane = o.Mane or coat:Lerp(Color3.new(0, 0, 0), 0.3)
	local belly = o.Belly or coat:Lerp(Color3.new(1, 1, 1), 0.15)
	local legCol = o.Leg or mane
	local hoofCol = o.Hoof or Color3.fromRGB(40, 34, 32)
	local snoutCol = o.Snout or Color3.fromRGB(196, 140, 132)
	local tuskCol = o.Tusk or Color3.fromRGB(238, 230, 206)
	local black = Color3.fromRGB(14, 14, 16)
	local V, CF, A, r = Vector3.new, CFrame.new, CFrame.Angles, math.rad
	local function B(parent, name, size, cf, col, mat)
		local p = newPart("Part", parent, cf, size, col, name)
		if mat then
			p.Material = mat
		end
		return p
	end
	local function W(parent, name, size, cf, col)
		return newPart("WedgePart", parent, cf, size, col, name)
	end
	local function K(parent, name, size, cf, col, c, edges, axis)
		return block(parent, cf, size, col, { c = c, edges = edges or "all", axis = axis or "Z", name = name })
	end

	-- body: deep forequarters under a high hump, a waist, a smaller rump
	K(m, "Body", V(1.5, 1.6, 1.4), CF(0, 1.95, -0.85), mane, 0.16)
	K(m, "Body", V(1.3, 1.25, 1.4), CF(0, 1.98, 0.45), coat, 0.15)
	K(m, "Body", V(1.2, 1.15, 0.7), CF(0, 1.95, 1.4), coat, 0.19)
	W(m, "Body", V(1.1, 0.4, 1.2), CF(0, 2.93, -0.7) * A(0, math.pi, 0), mane) -- the hump, sloping back from the shoulders
	-- bristle crest: wedge fins along the spine, tallest on the hump, roots buried in the back
	local crest = o.Crest or 1
	local function back(z)
		if z < -0.1 then
			return math.max(2.75, 3.13 - 0.4 * (z + 1.3) / 1.2)
		end
		return 2.605
	end
	for i, z in ipairs({ -1.15, -0.8, -0.45, -0.1, 0.25, 0.6 }) do
		local h = ({ 0.5, 0.48, 0.42, 0.35, 0.28, 0.22 })[i] * crest
		local base = back(z) - 0.06
		if o.Spikes then
			tuft(m, V(0, base, z), V(0, 0.85, 0.5).Unit, X, h * 1.1, 0.09, "Body", o.Spikes, V(0, -0.08, -0.1))
		else
			W(m, "Body", V(0.14, h, 0.38), CF(0, base + h / 2, z) * A(0, math.pi, 0), mane:Lerp(black, 0.25))
		end
	end

	-- neck: short and thick, carrying the head low; the head hinges on it
	B(m, "Neck", V(1.05, 0.95, 0.75), CF(0, 2.0, -1.65) * A(r(15), 0, 0), mane)

	-- head: a blocky skull with a gable ridge, an angled brow over small eyes, ears on top
	B(m, "Head", V(1.15, 1.0, 1.0), CF(0, 1.95, -2.2), coat)
	for _, sx in ipairs({ -1, 1 }) do
		W(m, "Head", V(0.9, 0.14, 0.56), CF(sx * 0.29, 2.51, -2.2) * A(0, -sx * math.pi / 2, 0), mane)
		local tilt = A(0, 0, sx * r(14))
		B(m, "Head", V(0.5, 0.13, 0.2), CF(sx * 0.32, 2.32, -2.66) * tilt, mane:Lerp(black, 0.3))
		B(m, "Eye", V(0.2, 0.1, 0.05), CF(sx * 0.36, 2.15, -2.72) * tilt, black)
		B(m, "Eye", V(0.11, 0.06, 0.04), CF(sx * 0.37, 2.15, -2.75) * tilt, o.EyeGlow or Color3.fromRGB(60, 34, 22), o.EyeGlow and Enum.Material.Neon or nil)
		-- ears: small, upright and pointed, pink inside
		T(m, "Ear", mane, V(sx * 0.26, 2.44, -1.95), V(sx * 0.56, 2.44, -1.95), V(sx * 0.5, 2.92, -1.88), 0.12)
		T(m, "Ear", snoutCol, V(sx * 0.33, 2.48, -2.03), V(sx * 0.52, 2.48, -2.03), V(sx * 0.49, 2.8, -1.98), 0.04)
	end
	W(m, "Head", V(0.6, 0.32, 0.4), CF(0, 2.28, -2.9), coat) -- bridge, sloping from the brow down the snout

	-- snout: a top block and thin walls round a hollow, the dark roof up inside; a pink disc in front
	B(m, "Head", V(0.72, 0.34, 0.95), CF(0, 1.96, -3.15), coat)
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Head", V(0.09, 0.12, 0.95), CF(sx * 0.315, 1.73, -3.15), coat)
	end
	B(m, "Head", V(0.54, 0.12, 0.09), CF(0, 1.73, -3.58), coat)
	B(m, "Head", V(0.54, 0.03, 0.85), CF(0, 1.775, -3.1), black) -- roof
	B(m, "Head", V(0.54, 0.12, 0.04), CF(0, 1.73, -2.69), black) -- back of the mouth
	B(m, "Snout", V(0.78, 0.5, 0.12), CF(0, 1.9, -3.66), snoutCol) -- the snout disc
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Snout", V(0.1, 0.13, 0.04), CF(sx * 0.15, 1.92, -3.735), black) -- nostrils
	end
	-- lower jaw: walls round a dark floor; the tusks ride it (they are lower canines)
	B(m, "Jaw", V(0.66, 0.12, 0.9), CF(0, 1.55, -3.08), belly)
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Jaw", V(0.08, 0.06, 0.9), CF(sx * 0.29, 1.64, -3.08), belly)
	end
	B(m, "Jaw", V(0.5, 0.06, 0.08), CF(0, 1.64, -3.49), belly)
	B(m, "Jaw", V(0.5, 0.03, 0.8), CF(0, 1.625, -3.05), black) -- floor
	B(m, "Jaw", V(0.28, 0.03, 0.45), CF(0, 1.645, -2.95), Color3.fromRGB(196, 92, 98)) -- tongue
	local ts = o.TuskScale or 1
	for _, sx in ipairs({ -1, 1 }) do
		B(m, "Jaw", V(0.14, 0.12, 0.18), CF(sx * 0.36, 1.56, -3.3), belly) -- the tusk's socket on the jaw side
		local h = 0.3 * ts
		local bcf = CF(sx * 0.43, 1.52 + h / 2, -3.3) * A(r(-12), 0, sx * r(-8))
		B(m, "Jaw", V(0.1, h, 0.1) * math.sqrt(ts), bcf, tuskCol)
		local top = (bcf * CF(0, h / 2 - 0.02, 0)).Position
		tuft(m, top, V(sx * 0.15, 0.75, 0.6).Unit, X, 0.28 * ts, 0.05 * math.sqrt(ts), "Jaw", tuskCol, V(0, -0.02, -0.07))
		if o.Bands then
			B(m, "Jaw", V(0.14, 0.06, 0.14) * math.sqrt(ts), bcf * CF(0, 0.05, 0), o.Bands, Enum.Material.Metal)
		end
	end
	m:SetAttribute("JawPivot", V(0, 1.65, -2.7))

	-- tail: thin, hanging, with a dark tuft
	local tp = V(0, 2.35, 1.72)
	for _, sg in ipairs({ { -55, 0.3 }, { -78, 0.28 } }) do
		local th = r(sg[1])
		local dir = V(0, math.sin(th), math.cos(th))
		B(m, "Tail", V(0.1, 0.1, sg[2]), CF(tp + dir * sg[2] / 2) * A(-th, 0, 0), coat)
		tp = tp + dir * sg[2] * 0.85
	end
	tuft(m, tp, V(0, -1, 0.1).Unit, X, 0.25, 0.09, "Tail", mane:Lerp(black, 0.3), V(0, 0.03, 0.09))

	-- legs: short, chunky at the top, thin below, on cloven hooves
	local function legBlocks(name, sx, J, segs)
		local lm = Instance.new("Model")
		lm.Name = name
		lm:SetAttribute("Side", sx)
		for i, build in ipairs(segs) do
			local sm = Instance.new("Model")
			sm.Name = "Seg" .. i
			build(sm)
			local first = sm:FindFirstChildWhichIsA("BasePart")
			local att = Instance.new("Attachment")
			att.Name = "Joint"
			att.Parent = first
			att.WorldCFrame = CF(J[i])
			sm.Parent = lm
		end
		lm.Parent = m
	end
	local function hoof(sm, x, z)
		B(sm, "Leg", V(0.32, 0.12, 0.32), CF(x, 0.25, z), legCol:Lerp(hoofCol, 0.4)) -- pastern, wider than the cannon
		for _, dx in ipairs({ -0.065, 0.065 }) do
			B(sm, "Hoof", V(0.14, 0.2, 0.29), CF(x + dx * 1.08, 0.1, z - 0.045), hoofCol) -- the two toes
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 0.45
		legBlocks("LegFront", sx, { V(x, 2.0, -1.0), V(x, 1.3, -1.05), V(x, 0.68, -1.02), V(x, 0.26, -1.0) }, {
			function(sm) K(sm, "Leg", V(0.52, 1.0, 0.72), CF(x, 1.62, -1.0), mane, 0.1, "all", "Y") end,
			function(sm) B(sm, "Leg", V(0.34, 0.72, 0.38), CF(x, 0.98, -1.04), legCol) end,
			function(sm) B(sm, "Leg", V(0.26, 0.5, 0.28), CF(x, 0.47, -1.02), legCol) end,
			function(sm) hoof(sm, x, -1.02) end,
		})
		legBlocks("LegBack", sx, { V(x, 2.0, 1.3), V(x, 1.25, 1.1), V(x, 0.7, 1.45), V(x, 0.26, 1.4) }, {
			function(sm) K(sm, "Leg", V(0.6, 1.0, 0.85), CF(x, 1.72, 1.3), coat, 0.12, "all", "Y") end,
			function(sm) B(sm, "Leg", V(0.32, 0.66, 0.38), CF(x, 1.0, 1.28) * A(r(-22), 0, 0), legCol) end,
			function(sm) B(sm, "Leg", V(0.25, 0.5, 0.27), CF(x, 0.47, 1.42), legCol) end,
			function(sm) hoof(sm, x, 1.42) end,
		})
	end

	local rootC = V(0, 1.95, 0.2)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", V(1.2, 1.2, 3.0))
	m:SetAttribute("NeckBase", V(0, 2.0, -1.45) - rootC)
	m:SetAttribute("JawPivot", m:GetAttribute("JawPivot") - rootC)
	m:SetAttribute("Length", 5.5)
	m:SetAttribute("Stride", 2.3)
	return V(1.6, 3.5, 5.6)
end

-- Ox: the Guardian Ox, Willow Fields' boss (user, 2026-10-27: "just a really big muscular ox with
-- large horns", nothing spirit or magic). Refs: shaggy horned oxen and a faceted low-poly bull. Same
-- blocky build as the boar and deer: a massive front with a high shoulder hump over a deep chest, a
-- smaller rump, a heavy head carried low with a broad pale muzzle, huge horns sweeping out then up
-- and forward, a shaggy beard and chest, thick block legs on big hooves and a long tufted tail.
-- Attacks: charge, stomp, horn toss (Creatures.attack "Gore").
-- opts: Coat, Mane (hump, forequarters, beard), Muzzle, Leg, Hoof, Horn, HornTip
recipes.Ox = function(m, o)
	-- palette of the user's grey ox reference: a pale taupe body, a darker grey shaggy hump, neck
	-- and beard, dark lower legs, a dark stripe down the face and charcoal horns
	local coat = o.Coat or Color3.fromRGB(176, 160, 136)
	local mane = o.Mane or Color3.fromRGB(104, 94, 82)
	local muzzle = o.Muzzle or Color3.fromRGB(150, 138, 120)
	local legCol = o.Leg or Color3.fromRGB(70, 62, 56)
	local hoof = o.Hoof or Color3.fromRGB(34, 30, 28)
	local horn = o.Horn or Color3.fromRGB(92, 88, 86)
	local hornTip = o.HornTip or Color3.fromRGB(40, 38, 40)
	local black = Color3.fromRGB(14, 12, 12)
	-- a boss gets a bit more geometry (user): 10-point sections, slightly rounder corners, more rings
	local box, sides = 0.3, 10
	local Y, V, up = Vector3.yAxis, Vector3.new, Vector3.yAxis

	-- torso (z, centre y, half width, top, bottom): the hump rises over the shoulders. The belly is
	-- not flat (user): a deep brisket between the front legs, a barrel that sags lowest mid-body, then
	-- a sharp tuck-up to the flank in front of the hind legs
	local TORSO = { { -2.3, 2.5, 0.5, 0.8, 0.95 }, { -1.95, 2.62, 0.92, 1.61, 1.22 }, { -1.55, 2.66, 1.06, 1.94, 1.24 },
		{ -0.95, 2.62, 1.1, 1.56, 1.2 }, { -0.3, 2.56, 1.04, 1.12, 1.28 }, { 0.4, 2.56, 0.96, 0.95, 1.18 },
		{ 0.95, 2.62, 0.9, 0.9, 0.92 }, { 1.35, 2.62, 0.9, 0.88, 0.8 }, { 1.85, 2.6, 0.74, 0.72, 0.7 },
		{ 2.18, 2.56, 0.42, 0.48, 0.5 } }
	-- torso rings: boxy over the back, rounder underneath (a barrel, not a slab)
	local function tring(c, hw, top, bot)
		local pts = {}
		for j = 0, sides - 1 do
			local a = j / sides * math.pi * 2
			local s, co = math.sin(a), math.cos(a)
			local e = co > 0 and box or 0.62
			table.insert(pts, c + X * hw * sp(s, e) + Y * (co > 0 and top or bot) * sp(co, e))
		end
		return pts
	end
	local rings = {}
	for _, r in ipairs(TORSO) do
		table.insert(rings, tring(V(0, r[2], r[1]), r[3] * BODY_W, r[4], r[5]))
	end
	local function torsoPaint(c, n)
		if n.Y < -0.6 then
			return "Body", coat:Lerp(muzzle, 0.25) -- one belly colour all along, so no seam
		end
		return "Body", coat
	end
	hull(m, rings, torsoPaint)
	cap(m, rings[1], V(0, 2.42, -2.42), torsoPaint)
	cap(m, rings[#rings], V(0, 2.56, 2.3), torsoPaint)
	-- head: heavy and low, a skull box stepping down to a broad muzzle box
	local poll, nose = V(0, 3.05, -2.5), V(0, 1.55, -3.55) -- carried low, the face nearly vertical (ref)
	local HEAD = { { 0, 0.6, 0.58, 0.52 }, { 0.15, 0.72, 0.66, 0.58 }, { 0.36, 0.7, 0.62, 0.56 }, { 0.42, 0.55, 0.48, 0.46 },
		{ 0.62, 0.53, 0.46, 0.45 }, { 0.8, 0.52, 0.46, 0.44 }, { 0.93, 0.5, 0.44, 0.42 }, { 1.0, 0.46, 0.4, 0.38 } }
	local D, U, hl, headAt, hrings = headKit(poll, nose, HEAD, box, 10)
	-- neck: one thick block from inside the chest into the skull
	local NECK = { { V(0, 2.9, -1.7), 0.85, 0.85, 0.85 }, { V(0, 3.0, -2.1), 0.74, 0.74, 0.72 }, { poll + D * hl * 0.25, 0.58, 0.52, 0.5 } }
	rings = {}
	for _, r in ipairs(NECK) do
		local d = (NECK[#NECK][1] - NECK[1][1]).Unit
		table.insert(rings, ring(r[1], X, d:Cross(X).Unit, r[2], r[3], r[4], sides, box))
	end
	local neckPaint = function()
		return "Neck", coat
	end
	hull(m, rings, neckPaint)
	cap(m, rings[1], NECK[1][1] + V(0, 0, 0.3), neckPaint)
	cap(m, rings[#rings], NECK[#NECK][1] - D * 0.1, neckPaint)
	local function headPaint(c, n, seg)
		local t = (c - poll):Dot(D) / hl
		if seg == 0 then -- the end caps: nose pad, and the back of the skull in coat (it lines up with coat facets)
			return t > 0.9 and "Nose" or "Head", t > 0.9 and Color3.fromRGB(70, 52, 48) or coat
		end
		if seg >= 6 then -- the muzzle, by whole sections
			return "Head", muzzle
		end
		-- the dark stripe down the face (ref): the two top facets of each skull section (0..36 degrees
		-- each side of the top point). Picked by the triangle's angle round the head, normalised by the
		-- section's size, so both triangles of a facet always match (testing distance or facing split
		-- facets: a zigzag on the forehead and a z-fighting pair)
		if seg >= 1 and seg < 6 then
			local hwc, topc = headAt(math.clamp(t, 0, 1))
			local rel = c - (poll + D * hl * t)
			local u = rel:Dot(U) / topc
			if u > 0 and math.atan2(math.abs(rel:Dot(X)) / hwc, u) < math.rad(38) then
				return "Head", mane
			end
		end
		return "Head", coat
	end
	hull(m, hrings, headPaint)
	cap(m, hrings[1], poll - D * 0.12, headPaint)
	cap(m, hrings[#hrings], nose + D * 0.04, headPaint, nil, poll + D * hl * 0.8)
	-- nostrils on the front face
	for _, sx in ipairs({ -1, 1 }) do
		local c = nose + D * 0.045 + X * sx * 0.2 - U * 0.06
		newPart("Part", m, CFrame.fromMatrix(c, X, U), V(0.12, 0.09, 0.04), black, "Nose")
	end
	-- eyes: a dark brow bar over a black socket and a small dark eye, on the skull's flat side
	for _, sx in ipairs({ -1, 1 }) do
		local hwE, topE = headAt(0.25)
		local ax, ay = hwE * sp(math.sin(math.pi / 4), box), topE * sp(math.cos(math.pi / 4), box)
		local c = poll + D * hl * 0.25 + U * 0.12 + X * sx * (ax + (hwE - ax) * (1 - 0.12 / ay))
		local frame = CFrame.fromMatrix(c, D, U)
		local outv = frame:VectorToWorldSpace(Vector3.zAxis):Dot(X * sx) > 0 and 1 or -1
		local function plate(name, off, size, col, tilt)
			newPart("Part", m, frame * CFrame.new(off.X, off.Y, off.Z * outv) * CFrame.Angles(0, 0, tilt or 0), size, col, name)
		end
		plate("Head", V(-0.02, 0.15, 0.02), V(0.4, 0.1, 0.06), mane:Lerp(black, 0.4), math.rad(-14))
		plate("Eye", V(0, 0, 0), V(0.24, 0.14, 0.06), black)
		plate("Eye", V(0.04, 0, 0.02), V(0.1, 0.09, 0.06), Color3.fromRGB(60, 36, 24))
	end
	-- ears: short, out to the sides under the horns
	for _, sx in ipairs({ -1, 1 }) do
		-- small, drooping out and down below the horn bases
		local root = poll + D * hl * 0.24 - U * 0.05 + X * sx * 0.55
		ear(m, root, (X * sx - U * 0.55 + D * 0.1).Unit, (-D + X * sx * 0.3).Unit, 0.45, 0.2, coat, muzzle)
	end
	-- horns: thick at the skull, out to the sides, then sweeping up and forward to dark tips
	for _, sx in ipairs({ -1, 1 }) do
		-- huge: they run out almost level past the shoulders before turning up and forward
		-- roots out at the sides of the poll (collar inner edge at x 0.21), clear of the forelock between them
		local hb = poll + D * hl * 0.12 + U * 0.42 + X * sx * 0.6
		-- the reference's big C: out to the side, then up and forward, the tips turning in
		local pts = { hb, hb + V(sx * 0.95, 0.0, 0.12), hb + V(sx * 1.65, 0.3, 0.08), hb + V(sx * 1.95, 1.0, -0.2), hb + V(sx * 1.75, 1.65, -0.65), hb + V(sx * 1.35, 1.95, -1.05) }
		tube(m, { pts[1], pts[2], pts[3], pts[4], pts[5] }, { 0.3, 0.27, 0.22, 0.15, 0.09 }, "Horn", horn, 7)
		tube(m, { pts[5] - (pts[5] - pts[4]).Unit * 0.12, pts[5]:Lerp(pts[6], 0.5), pts[6] }, { 0.1, 0.07, 0.025 }, "Horn", hornTip, 7)
		-- a collar of thick hide where each horn grows from the skull: a short round sleeve round the
		-- horn base (a square block poked its corners through the round horn), 8-sided against the
		-- horn's 7 so no faces line up, a little wider than the horn all along; the plates' thickness
		-- closes the open end against the horn
		local dir = (pts[2] - pts[1]).Unit
		local s1 = dir:Cross(Y).Unit
		local s2 = s1:Cross(dir).Unit
		local collar = {}
		for _, r in ipairs({ { -0.04, 0.35 }, { 0.18, 0.34 }, { 0.3, 0.33 } }) do -- flat faces (r * 0.92) stay outside the horn's corners
			table.insert(collar, ring(hb + dir * r[1], s1, s2, r[2], r[2], r[2], 8, 1))
		end
		hull(m, collar, function()
			return "Head", mane
		end)
	end
	-- shaggy beard (ref): a dark block hanging from under the jaw and throat, ending in a wedge point;
	-- no spiky tufts under the body (the user disliked them on the wolf)
	local chin = poll + D * hl * 0.45 - U * 0.42
	local beardCf = CFrame.fromMatrix(chin - Y * 0.45, X, Y)
	block(m, beardCf, V(0.5, 0.9, 0.4), mane, { c = 0.08, edges = "all", axis = "Y", name = "Head" })
	newPart("WedgePart", m, beardCf * CFrame.new(0, -0.62, 0) * CFrame.Angles(math.pi, 0, 0), V(0.46, 0.34, 0.36), mane, "Head")
	-- mane (user's grey ox reference): one intact mass of hair along the top line, from the forelock
	-- over the poll, up over the hump and down the back, tallest on the hump. Its crest flows in
	-- gentle swept-back waves (each lock rises slowly toward the tail, then drops), not spikes.
	-- The colour runs from the current mane colour at the roots to almost black along the crest (user).
	-- the top line, read off the neck and torso rings (each ring's top point), so the mane sits on it
	local TOP = { { -2.5, 3.64 }, { -2.1, 3.76 } }
	for _, r in ipairs(TORSO) do
		if r[1] > -2.0 then
			table.insert(TOP, { r[1], r[2] + r[4] })
		end
	end
	local function topY(z)
		for i = 1, #TOP - 1 do
			local a2, b2 = TOP[i], TOP[i + 1]
			if z <= b2[1] then
				return a2[2] + (b2[2] - a2[2]) * (z - a2[1]) / (b2[1] - a2[1])
			end
		end
		return TOP[#TOP][2]
	end
	local maneMid, maneTop = mane:Lerp(Color3.fromRGB(24, 22, 22), 0.55), Color3.fromRGB(28, 26, 26)
	-- crest section (half width w, height h above the top line): it drapes over the back like a
	-- shaggy coat (crest, shoulder, flank, skirt), its roots sunk 0.5 into the body. Points run round
	-- the ring; each point's level (0 roots .. 3 crest) picks the colour band.
	-- sh = shoulder height fraction: troughs use a different one from crests, so the bands on the
	-- steep back of a wave don't lie in one plane (they z-fought)
	local function section(c, side, upv, w, h, sh)
		sh = sh or 0.82
		return {
			c + upv * h, c + side * w * 0.45 + upv * h * sh, c + side * w * 0.85 + upv * h * 0.45, c + side * w - upv * 0.05,
			c + side * w * 0.8 - upv * 0.45, c - upv * 0.5,
			c - side * w * 0.8 - upv * 0.45, c - side * w - upv * 0.05, c - side * w * 0.85 + upv * h * 0.45, c - side * w * 0.45 + upv * h * sh,
		}
	end
	local LEVEL = { 3, 3, 2, 1, 0, 0, 0, 1, 2, 3 }
	local function bandCol(lv)
		return lv >= 3 and maneTop or lv == 2 and maneMid or mane
	end
	-- loft through crest sections; each quad takes the colour band of its lower point
	local function loft(rgs, names)
		for i = 1, #rgs - 1 do
			local A, B = rgs[i], rgs[i + 1]
			local mid = Vector3.zero
			for k = 1, #A do
				mid += A[k] + B[k]
			end
			mid /= 2 * #A
			for k = 1, #A do
				local k2 = k % #A + 1
				local col = bandCol(math.min(LEVEL[k], LEVEL[k2]))
				for _, t in ipairs({ { A[k], A[k2], B[k2] }, { A[k], B[k2], B[k] } }) do
					local nrm = (t[2] - t[1]):Cross(t[3] - t[1])
					if nrm.Magnitude > 1e-6 then
						local cen = (t[1] + t[2] + t[3]) / 3
						nrm = nrm.Unit
						if nrm:Dot(cen - mid) < 0 then
							nrm = -nrm
						end
						T(m, names[i], col, t[1], t[2], t[3], SKIN, nil, nrm)
					end
				end
			end
		end
	end
	-- lowY (optional): triangles below it are buried in the body and take the coat colour (an
	-- interior face lined up with the neck's end cap inside the skull)
	local function capEnd(rg, apex, name, lowY)
		cap(m, rg, apex, function(cen)
			if lowY and cen.Y < lowY then
				return name, coat
			end
			return name, cen.Y > apex.Y - 0.05 and maneMid or mane
		end)
	end
	-- body mane: a section at every wave trough and crest. Each wave is 0.62 long: the crest rises
	-- over 70% of it toward the tail, then drops, so the hair reads as locks swept back
	local P, z0, z1 = 0.62, -2.5, 1.95
	local ZS = {}
	local z = z0
	while z < z1 - 0.05 do
		table.insert(ZS, { z, 0 })
		if z + P * 0.7 < z1 then
			table.insert(ZS, { z + P * 0.7, 1 })
		end
		z += P
	end
	table.insert(ZS, { z1, 0 })
	local body, names = {}, {}
	for i4, zz in ipairs(ZS) do
		local zq = zz[1]
		local f2 = math.clamp(1 - math.abs(zq + 1.6) / 3.6, 0.2, 1) -- biggest over the hump
		local h = (0.3 + 0.5 * f2) * (zz[2] == 1 and 1 or 0.82)
		-- broad over the hump, draping down its sides; crest and trough widths differ (no shared planes)
		local w = 0.42 + 0.5 * f2 + (zz[2] == 1 and 0.04 or 0)
		if i4 == #ZS then
			h, w = h * 0.6, w * 0.75
		end
		table.insert(body, section(V(0, topY(zq) - 0.1, zq), X, Y, w, h, zz[2] == 1 and 0.82 or 0.7))
		table.insert(names, zq < -2.0 and "Neck" or "Body") -- the neck end nods with the head
	end
	loft(body, names)
	capEnd(body[#body], V(0, topY(2.12) - 0.02, 2.12), "Body")
	capEnd(body[1], V(0, 3.56, -2.62), "Neck")
	-- forelock: the mane runs on over the poll and down the forehead between the horns, getting
	-- lower toward the face; its sections stand on the head's top (up = U), lofted along D
	local fore, fnames = {}, {}
	-- narrow (half width <= 0.17), so it fits between the horn collars without touching them (user)
	for i5, f in ipairs({ { -0.06, 0.42, 0.15 }, { 0.06, 0.36, 0.14 }, { 0.17, 0.26, 0.12 } }) do
		local _, top = headAt(math.max(0, f[1]))
		table.insert(fore, section(poll + D * hl * f[1] + U * (top - 0.1), X, U, f[3] + i5 * 0.012, f[2]))
		table.insert(fnames, "Head")
	end
	loft(fore, fnames)
	do
		local _, top = headAt(0.27)
		capEnd(fore[#fore], poll + D * hl * 0.27 + U * (top - 0.02), "Head")
	end
	capEnd(fore[1], poll - D * hl * 0.12 + U * 0.3, "Head", (fore[1][4] + fore[1][8]).Y / 2)

	-- tail: long, hanging to the hocks, with a dark tuft
	tube(m, { V(0, 3.0, 2.0), V(0, 2.85, 2.35), V(0, 1.9, 2.45), V(0, 1.15, 2.45) }, { 0.12, 0.1, 0.08, 0.07 }, "Tail", coat, 4)
	tuft(m, V(0, 1.2, 2.45), V(0, -1, 0.05).Unit, X, 0.55, 0.18, "Tail", legCol, V(0, 0.05, 0.14))

	-- legs: thick chamfered blocks on the real joints, big block hooves (cloven: a dark split)
	local function blk(sm, a2, b2, w, d, col, c)
		local dir = (a2 - b2).Unit
		block(sm, CFrame.fromMatrix((a2 + b2) / 2, X, dir), V(w, (a2 - b2).Magnitude, d), col, { c = c or math.min(w, d) * 0.2, edges = "all", axis = "Y", name = "Leg" })
	end
	local thin = { { 0.1, 0.12 }, { 0.1, 0.12 }, { 0.1, 0.12 } }
	-- a rounded muscle (user: "round the tops of the shoulders"): a loft of 10-point rounded rings
	-- down the bone, R = { { fraction from a to b, half width, front, back }, ... }, domed at the top
	local function muscle(sm, a2, b2, R, col)
		local d = (b2 - a2).Unit
		local fwd = X:Cross(d).Unit
		if fwd.Z > 0 then
			fwd = -fwd
		end
		local rg = {}
		for _, r in ipairs(R) do
			table.insert(rg, ring(a2:Lerp(b2, r[1]), X, fwd, r[2], r[3], r[4], 10, 0.75))
		end
		local paint = function()
			return "Leg", col
		end
		hull(sm, rg, paint)
		cap(sm, rg[1], a2 - d * 0.12, paint)
		cap(sm, rg[#rg], b2 + d * 0.08, paint)
	end
	local function foot(sm, Fj, Hb)
		blk(sm, Fj + up * 0.08, Hb + up * 0.3, 0.38, 0.42, legCol)
		for _, dx in ipairs({ -0.12, 0.12 }) do
			newPart("Part", sm, CFrame.new(Hb + V(dx, 0.16, -0.06)), V(0.22, 0.32, 0.56), hoof, "Hoof")
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 0.8
		local S, E, K, F = V(x, 3.1, -1.7), V(x, 2.0, -1.82), V(x, 1.0, -1.76), V(x, 0.36, -1.72)
		local Hb = V(x, 0, -1.8)
		legModel(m, "LegFront", sx, { S, E, K, F }, {
			-- a huge rounded shoulder, its domed top rising up the side of the hump
			{ { S + up * 0.2, S, E }, thin, { coat, coat }, extra = function(sm)
				muscle(sm, S + up * 1.0, E, { { 0, 0.5, 0.12, 0.14 }, { 0.07, 0.54, 0.5, 0.55 }, { 0.2, 0.56, 0.8, 0.85 }, { 0.55, 0.55, 0.72, 0.72 }, { 1, 0.36, 0.44, 0.4 } }, coat)
			end },
			{ { E + up * 0.1, K }, thin, { coat }, extra = function(sm)
				muscle(sm, E + up * 0.2, K, { { 0, 0.32, 0.14, 0.14 }, { 0.1, 0.34, 0.38, 0.36 }, { 0.3, 0.38, 0.44, 0.4 }, { 1, 0.25, 0.28, 0.27 } }, coat:Lerp(legCol, 0.3))
			end },
			{ { K + up * 0.1, F }, thin, { legCol }, extra = function(sm) blk(sm, K + up * 0.12, F, 0.42, 0.46, legCol) end },
			{ { F + up * 0.06, Hb + up * 0.3 }, thin, { legCol }, extra = function(sm) foot(sm, F, Hb) end },
		})
		x = sx * 0.74
		local P, St, Hk = V(x, 3.05, 1.5), V(x, 2.0, 1.15), V(x, 1.1, 1.8)
		F, Hb = V(x, 0.36, 1.75), V(x, 0, 1.68)
		legModel(m, "LegBack", sx, { P, St, Hk, F }, {
			{ { P + up * 0.2, P, St }, thin, { coat, coat }, extra = function(sm)
				muscle(sm, P + up * 0.45, St, { { 0, 0.44, 0.12, 0.14 }, { 0.08, 0.47, 0.42, 0.46 }, { 0.22, 0.5, 0.74, 0.78 }, { 0.6, 0.46, 0.6, 0.6 }, { 1, 0.34, 0.4, 0.38 } }, coat)
			end },
			{ { St + up * 0.1, Hk }, thin, { coat }, extra = function(sm)
				muscle(sm, St + V(0, 0.2, -0.04), Hk, { { 0, 0.3, 0.14, 0.14 }, { 0.1, 0.33, 0.36, 0.36 }, { 0.35, 0.36, 0.42, 0.4 }, { 1, 0.25, 0.27, 0.3 } }, coat:Lerp(legCol, 0.3))
			end },
			{ { Hk + up * 0.1, F }, thin, { legCol }, extra = function(sm) blk(sm, Hk + up * 0.14, F, 0.42, 0.46, legCol) end },
			{ { F + up * 0.06, Hb + up * 0.3 }, thin, { legCol }, extra = function(sm) foot(sm, F, Hb) end },
		})
	end
	local rootC = V(0, 2.6, 0)
	m:SetAttribute("RootC", rootC)
	m:SetAttribute("RootS", V(2.0, 2.1, 4.2))
	m:SetAttribute("NeckBase", V(0, 3.0, -1.8) - rootC)
	m:SetAttribute("HeadPivot", poll - rootC) -- the poll: the head tilts here, the neck bends at NeckBase
	m:SetAttribute("Length", 5.9)
	m:SetAttribute("Stride", 3.2)
	return V(4.6, 5.0, 6.2)
end

-- the Willow Fields drafts (not used in game until approved; then they move into Looks)
Creatures.Drafts = {
	TuskKing = { "Boar", { Low = true, Blocky = true, Box = 0.18, HeadScale = 1.125,
		Coat = Color3.fromRGB(78, 52, 40), Mane = Color3.fromRGB(40, 28, 24), Leg = Color3.fromRGB(46, 32, 28),
		TuskScale = 2.4, Crest = 1.8, EyeGlow = Color3.fromRGB(255, 70, 40), Bands = Color3.fromRGB(232, 186, 74),
		Spikes = Color3.fromRGB(228, 218, 196),
	} },
	NightWolfSculpt = { "Wolf", {
		Coat = Color3.fromRGB(46, 52, 82), Back = Color3.fromRGB(26, 30, 50), Mane = Color3.fromRGB(34, 38, 62),
		Face = Color3.fromRGB(52, 58, 92), Cream = Color3.fromRGB(110, 124, 172), TailTip = Color3.fromRGB(18, 20, 34),
		EyeGlow = Color3.fromRGB(120, 210, 255),
	} },
}

-- ===================================================================== which mob uses which recipe
-- MobId -> { recipe, opts }. Size comes from Config.Mobs[id].Size.Z (nose to tail).
Creatures.Looks = {
	-- Willow Fields (approved 2026-10-27)
	Boar = { "Boar", { Low = true, Blocky = true, Box = 0.18, HeadScale = 1.125 } },
	TuskBoar = { "Boar", { Low = true, Blocky = true, Box = 0.18, HeadScale = 1.125,
		Coat = Color3.fromRGB(92, 64, 50), Mane = Color3.fromRGB(52, 38, 32), TuskScale = 1.7, Crest = 1.5,
		EyeGlow = Color3.fromRGB(255, 120, 60),
	} },
	Wolf = { "WolfBlock", {} },
	NightWolf = { "WolfBlock", {
		Coat = Color3.fromRGB(46, 52, 82), Dark = Color3.fromRGB(24, 28, 46), Light = Color3.fromRGB(110, 124, 172),
		Eye = Color3.fromRGB(120, 210, 255),
	} },
	GuardianOx = { "Ox", {} },
	MoonhornStag = { "Deer", { Blocky = true,
		Coat = Color3.fromRGB(212, 218, 232), Mane = Color3.fromRGB(124, 138, 172), Face = Color3.fromRGB(200, 208, 226),
		White = Color3.fromRGB(248, 249, 252), Dark = Color3.fromRGB(44, 48, 66), Shin = Color3.fromRGB(104, 116, 150),
		Hoof = Color3.fromRGB(150, 160, 186), Ruff = true, Antlers = "Branched", AntlerColor = Color3.fromRGB(236, 240, 248),
		Glow = Color3.fromRGB(130, 220, 255), Moon = Color3.fromRGB(130, 220, 255),
	} },
	GoldenStag = { "Deer", { Blocky = true,
		Coat = Color3.fromRGB(236, 190, 84), Mane = Color3.fromRGB(196, 140, 52), Face = Color3.fromRGB(240, 206, 120),
		White = Color3.fromRGB(255, 244, 210), Dark = Color3.fromRGB(70, 46, 24), Shin = Color3.fromRGB(170, 116, 44),
		Hoof = Color3.fromRGB(90, 62, 30), Antlers = "Branched", AntlerColor = Color3.fromRGB(255, 236, 170),
		Glow = Color3.fromRGB(255, 230, 120),
	} },
	-- Mythic beasts (2026-10-31: replacing the primitive placeholders). Smooth wedge-triangle sculpts
	-- (no Blocky), real proportions; the aura flames come from Auras, the glow parts are Neon here.
	-- Heavenly Qilin (2026-11-02, after Raise a Zoo's): a cream body in jade scale plates, two long
	-- swept black horns, a dragon's head with whiskers, a long white mane and tail plume, fur at the fetlocks
	HeavenlyQilin = { "Deer", {
		Coat = Color3.fromRGB(226, 214, 184), Mane = Color3.fromRGB(226, 214, 184), Face = Color3.fromRGB(236, 228, 204),
		White = Color3.fromRGB(240, 234, 216), Dark = Color3.fromRGB(42, 34, 32), Shin = Color3.fromRGB(212, 198, 166),
		Hoof = Color3.fromRGB(42, 34, 32), Antlers = "Swept", AntlerColor = Color3.fromRGB(46, 36, 30), Dragon = true,
		Scales = { Color3.fromRGB(40, 96, 66), Color3.fromRGB(54, 118, 80), Color3.fromRGB(86, 148, 100) },
		Hair = { Color3.fromRGB(246, 243, 234), Color3.fromRGB(222, 216, 200) },
	} },
	-- The first version, kept for a one-word rollback: rename this key to HeavenlyQilin.
	-- A jade deer-dragon, deeper jade on the neck, gold-cream underside, branched gold antlers with
	-- glowing tips and a moon mark on the brow
	HeavenlyQilinV1 = { "Deer", {
		Coat = Color3.fromRGB(96, 186, 150), Mane = Color3.fromRGB(70, 160, 126), Face = Color3.fromRGB(118, 200, 166),
		White = Color3.fromRGB(240, 226, 176), Dark = Color3.fromRGB(30, 62, 54), Shin = Color3.fromRGB(62, 140, 110),
		Hoof = Color3.fromRGB(212, 170, 80), Antlers = "Branched", AntlerColor = Color3.fromRGB(240, 222, 160),
		Glow = Color3.fromRGB(120, 255, 200), Moon = Color3.fromRGB(255, 220, 130),
	} },
	-- Nine-Tailed Fox: a slender blush-white fox, tall ears, nine plumes fanned behind it with
	-- glowing rose foxfire tips and rose eyes
	NineTailedFox = { "Wolf", {
		Tails = 9, TailFluff = 1.35, EarScale = 1.3,
		Coat = Color3.fromRGB(250, 236, 236), Back = Color3.fromRGB(238, 210, 216), Mane = Color3.fromRGB(255, 246, 246),
		Face = Color3.fromRGB(252, 240, 240), Cream = Color3.fromRGB(255, 250, 248), Leg = Color3.fromRGB(246, 226, 230),
		Paw = Color3.fromRGB(216, 170, 186), Nose = Color3.fromRGB(80, 40, 60), TailTip = Color3.fromRGB(240, 120, 170),
		TailGlow = Color3.fromRGB(255, 110, 190), EyeGlow = Color3.fromRGB(255, 120, 190),
		Hair = { Color3.fromRGB(255, 248, 248), Color3.fromRGB(244, 218, 226) },
	} },
	-- Thunder Roc: a storm-blue raptor, pale breast, white wing tips with Neon veins, white storm crest
	ThunderRoc = { "Bird", {
		Coat = Color3.fromRGB(58, 88, 168), Back = Color3.fromRGB(34, 52, 112), Belly = Color3.fromRGB(202, 212, 230),
		WingTip = Color3.fromRGB(226, 234, 250), Beak = Color3.fromRGB(226, 184, 84), Leg = Color3.fromRGB(196, 156, 74),
		Glow = Color3.fromRGB(130, 200, 255), EyeGlow = Color3.fromRGB(170, 225, 255),
		Hair = { Color3.fromRGB(240, 246, 255), Color3.fromRGB(150, 190, 245) }, Primaries = 10,
	} },
	-- Azure Dragon (Divine spirit): a long azure dragon in scales, gold belly, white mane, pale gold horns
	AzureDragon = { "Serpent", { Dragon = true } },
	-- Frost Wolf (spirit): an ice-white wolf with a shaggy mane and pale glowing eyes
	FrostWolf = { "Wolf", {
		Coat = Color3.fromRGB(226, 236, 248), Back = Color3.fromRGB(170, 200, 232), Mane = Color3.fromRGB(240, 246, 252),
		Face = Color3.fromRGB(232, 240, 250), Cream = Color3.fromRGB(250, 252, 255), Leg = Color3.fromRGB(214, 228, 244),
		Paw = Color3.fromRGB(160, 186, 216), Nose = Color3.fromRGB(44, 56, 80), TailTip = Color3.fromRGB(150, 195, 240),
		TailGlow = Color3.fromRGB(150, 225, 255), EyeGlow = Color3.fromRGB(140, 225, 255),
		Hair = { Color3.fromRGB(248, 251, 255), Color3.fromRGB(190, 215, 240) },
	} },
	-- mounts (Config.Mounts Look)
	MountHorse = { "Deer", { Blocky = true,
		Coat = Color3.fromRGB(132, 92, 62), Mane = Color3.fromRGB(62, 42, 32), Face = Color3.fromRGB(122, 84, 56),
		White = Color3.fromRGB(226, 214, 196), Dark = Color3.fromRGB(46, 36, 32), Ruff = true,
	} },
	MountJadeDeer = { "Deer", { Blocky = true,
		Coat = Color3.fromRGB(130, 200, 162), Mane = Color3.fromRGB(70, 140, 108), Face = Color3.fromRGB(150, 214, 178),
		White = Color3.fromRGB(236, 250, 242), Dark = Color3.fromRGB(36, 62, 52), Shin = Color3.fromRGB(80, 150, 116),
		Antlers = "Branched", AntlerColor = Color3.fromRGB(226, 252, 236), Glow = Color3.fromRGB(120, 255, 190),
	} },
	MountShadowWolf = { "WolfBlock", {
		Coat = Color3.fromRGB(48, 38, 70), Dark = Color3.fromRGB(22, 18, 36), Light = Color3.fromRGB(104, 86, 150),
		Eye = Color3.fromRGB(200, 130, 255),
	} },
	MountCelestialSteed = { "Deer", { Blocky = true,
		Coat = Color3.fromRGB(250, 236, 196), Mane = Color3.fromRGB(236, 196, 110), Face = Color3.fromRGB(252, 242, 214),
		White = Color3.fromRGB(255, 252, 240), Dark = Color3.fromRGB(120, 96, 60), Shin = Color3.fromRGB(236, 214, 160),
		Hoof = Color3.fromRGB(214, 176, 92), Ruff = true, Moon = Color3.fromRGB(255, 226, 130),
	} },
}

-- ===================================================================== rig
-- Turns a built creature into a jointed rig around `root` (a part that stays the assembly root):
-- body parts are welded to the root; each leg bone gets a Motor6D at its "Joint" attachment
-- (Part0 = the bone above, or the root for the shoulder / hip), named <F|B><L|R><1..4>; the neck,
-- head and antlers hang on a "Neck" motor at the base of the neck. Motor axes are the model's own,
-- so Transform = CFrame.Angles(a, 0, 0) swings a bone forward (+a) or back (-a).
local HEAD_PARTS = { Neck = true, Head = true, Nose = true, Eye = true, Ear = true, Antler = true, AntlerGlow = true, Glow = true, Tusk = true, Snout = true, Teeth = true }
Creatures.HEAD_PARTS = HEAD_PARTS

local function weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
end

local function motor(name, p0, p1, jointCf)
	local m6 = Instance.new("Motor6D")
	m6.Name = name
	m6.Part0 = p0
	m6.Part1 = p1
	m6.C0 = p0.CFrame:ToObjectSpace(jointCf)
	m6.C1 = p1.CFrame:ToObjectSpace(jointCf)
	m6.Parent = p1
	return m6
end

-- Chains (see chain) and hair strands (see strand), each hung on anchors[its On attribute]: a chain's
-- segments become motors <tag>1.. and hair a chain of three motors Hair<n>_<seg>
local function rigLimbs(m, anchors, rot)
	local hips = anchors.Hips
	-- a chain may hang on another chain's segment ("Waist1"), so build the ones whose anchor exists
	-- first and repeat; anything left at the end hangs on the hips
	local todo = {}
	for _, lm in ipairs(m:GetChildren()) do
		if lm:IsA("Model") and lm.Name == "Chain" then
			table.insert(todo, lm)
		end
	end
	local forced = false
	while #todo > 0 do
		local later = {}
		for _, lm in ipairs(todo) do
			local on = lm:GetAttribute("On")
			if anchors[on] or forced then
				local tag, prev = lm:GetAttribute("Chain"), anchors[on] or hips
				local i = 1
				while lm:FindFirstChild("Seg" .. i) do
					local seg = lm["Seg" .. i]
					local main, joint
					for _, a in ipairs(seg:GetDescendants()) do
						if a:IsA("Attachment") and a.Name == "Joint" then
							main, joint = a.Parent, a
						end
					end
					for _, p in ipairs(seg:GetDescendants()) do
						if p:IsA("BasePart") and p ~= main then
							weld(main, p)
						end
					end
					motor(tag .. i, prev, main, CFrame.new(joint.WorldPosition) * rot)
					anchors[tag .. i] = main
					prev = main
					i += 1
				end
			else
				table.insert(later, lm)
			end
		end
		forced = #later == #todo
		todo = later
	end
	local hairN = 0
	for _, sm in ipairs(m:GetChildren()) do
		if sm:IsA("Model") and sm.Name == "Strand" then
			hairN += 1
			local prev = anchors[sm:GetAttribute("On")] or hips
			for i = 1, 3 do
				local main, joint
				for _, p in ipairs(sm:GetChildren()) do
					local a = p.Name == "S" .. i and p:FindFirstChild("Joint")
					if a then
						main, joint = p, a
					end
				end
				if main then
					for _, p in ipairs(sm:GetChildren()) do
						if p.Name == "S" .. i and p ~= main then
							weld(main, p)
						end
					end
					local mo = motor("Hair" .. hairN .. "_" .. i, prev, main, CFrame.new(joint.WorldPosition) * rot)
					mo:SetAttribute("Hair", hairN)
					mo:SetAttribute("Seg", i)
					prev = main
				end
			end
		end
	end
end

-- Rig (after Raise a Zoo's, CHO/Animal Rig Reference (Raise a Zoo).md):
--   root -> Hips (an invisible torso carrier at the body's centre: bob, roll, breathing)
--   Hips -> legs FR1..BL4, Neck (at NeckBase; with a HeadPivot the neck parts only) -> HeadTilt
--   (the head, at the poll) -> Jaw, and Hips -> Tail1 -> Tail2 -> Tail3 (the tail plates banded by
--   distance from the tail root, so any recipe's tail bends without changes to the recipe)
function Creatures.rig(m, root)
	local rot = root.CFrame.Rotation
	local headMain
	local neckBase = m:GetAttribute("NeckBase")
	local headPivot = m:GetAttribute("HeadPivot")
	local hips = newPart("Part", m, root.CFrame, Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), "HipsCarrier")
	hips.Transparency = 1
	hips.CastShadow = false
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
		end
	end
	motor("Hips", root, hips, CFrame.new(root.Position) * rot)
	local anchors = { Hips = hips }
	if m:GetAttribute("RigKind") == "Serpent" or m:GetAttribute("RigKind") == "Snake" then
		-- a spine: Spine4 on the hips, the chain runs forward to the head and back to the tail
		local mains = {}
		for i = 1, 12 do
			local seg = m:FindFirstChild("Spine" .. i)
			local joint
			for _, a in ipairs(seg:GetDescendants()) do
				if a:IsA("Attachment") and a.Name == "Joint" then
					joint = a
				end
			end
			local main = joint.Parent
			for _, p in ipairs(seg:GetChildren()) do
				if p:IsA("BasePart") and p ~= main then
					weld(main, p)
				end
			end
			mains[i] = { Part = main, At = CFrame.new(joint.WorldPosition) * rot }
			anchors["Spine" .. i] = main
		end
		motor("Spine4", hips, mains[4].Part, mains[4].At)
		for i = 3, 1, -1 do
			motor("Spine" .. i, mains[i + 1].Part, mains[i].Part, mains[i].At)
		end
		for i = 5, 12 do
			motor("Spine" .. i, mains[i - 1].Part, mains[i].Part, mains[i].At)
		end
		local headMain
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") and d ~= root and d ~= hips then
				if headMain then
					weld(headMain, d)
				else
					headMain = d
				end
			end
		end
		motor("Neck", mains[1].Part, headMain, CFrame.new(root.CFrame:PointToWorldSpace(headPivot)) * rot)
		anchors.Head = headMain
		rigLimbs(m, anchors, rot)
		return
	end
	for _, leg in ipairs(m:GetChildren()) do
		if leg:IsA("Model") and leg:GetAttribute("Side") then
			local tag = (leg.Name == "LegFront" and "F" or "B") .. ((leg:GetAttribute("Side") > 0) and "R" or "L")
			local prev = hips
			for i = 1, 4 do
				local seg = leg:FindFirstChild("Seg" .. i)
				local main
				for _, p in ipairs(seg:GetDescendants()) do
					if p:IsA("Attachment") and p.Name == "Joint" then
						main = p.Parent
					end
				end
				for _, p in ipairs(seg:GetDescendants()) do
					if p:IsA("BasePart") and p ~= main then
						weld(main, p)
					end
				end
				motor(tag .. i, prev, main, CFrame.new(main.Joint.WorldPosition) * rot)
				prev = main
			end
		end
	end
	local headParts, jawParts, tailParts = {}, {}, {}
	for _, d in ipairs(m:GetChildren()) do
		if d:IsA("BasePart") and d ~= root and d ~= hips then
			if d.Name == "Jaw" and m:GetAttribute("JawPivot") then
				table.insert(jawParts, d)
			elseif neckBase and HEAD_PARTS[d.Name] then
				table.insert(headParts, d)
				if d.Name == "Neck" and not headMain then
					headMain = d
				end
			elseif d.Name == "Tail" or d.Name == "TailGlow" then
				table.insert(tailParts, d)
			else
				weld(hips, d)
			end
		end
	end
	local skull -- what the jaw hangs on
	if headMain then
		-- with a HeadPivot the head (everything but the neck plates) rides its own HeadTilt joint
		local headTiltMain
		if headPivot then
			local pivotW = root.CFrame:PointToWorldSpace(headPivot)
			for _, p in ipairs(headParts) do
				if p.Name ~= "Neck" and not headTiltMain then
					headTiltMain = p
				end
			end
			if headTiltMain then
				for _, p in ipairs(headParts) do
					if p ~= headMain and p ~= headTiltMain then
						weld(p.Name == "Neck" and headMain or headTiltMain, p)
					end
				end
				motor("HeadTilt", headMain, headTiltMain, CFrame.new(pivotW) * rot)
			end
		end
		if not headTiltMain then
			for _, p in ipairs(headParts) do
				if p ~= headMain then
					weld(headMain, p)
				end
			end
		end
		motor("Neck", hips, headMain, CFrame.new(root.CFrame:PointToWorldSpace(neckBase)) * rot)
		skull = headTiltMain or headMain
	end
	if #jawParts > 0 then
		-- the lower jaw hinges on the head (or the body when there is no neck joint)
		local jawMain = jawParts[1]
		for i = 2, #jawParts do
			weld(jawMain, jawParts[i])
		end
		motor("Jaw", skull or hips, jawMain, CFrame.new(root.CFrame:PointToWorldSpace(m:GetAttribute("JawPivot"))) * rot)
	end
	local tailEnd
	anchors.Neck, anchors.Head = headMain, skull
	if #tailParts > 0 then
		-- the tail root: the tail plate nearest the body's centre; plates are banded by distance from
		-- it into three segments, each hinged where it meets the one before
		local origin, best = nil, math.huge
		for _, p in ipairs(tailParts) do
			local d = (p.Position - root.Position).Magnitude
			if d < best then
				origin, best = p.Position, d
			end
		end
		local far = 0
		for _, p in ipairs(tailParts) do
			far = math.max(far, (p.Position - origin).Magnitude)
		end
		local bands = { {}, {}, {} }
		for _, p in ipairs(tailParts) do
			local f = (p.Position - origin).Magnitude / math.max(far, 1e-3)
			table.insert(bands[math.clamp(math.floor(f * 3) + 1, 1, 3)], p)
		end
		local prev, pivot = hips, origin
		for i, band in ipairs(bands) do
			if #band > 0 then
				local main = band[1]
				for k = 2, #band do
					weld(main, band[k])
				end
				motor("Tail" .. i, prev, main, CFrame.new(pivot) * rot)
				-- the next hinge: where this band's far plates sit
				local sum, n = Vector3.zero, 0
				for _, p in ipairs(band) do
					local f = (p.Position - origin).Magnitude / math.max(far, 1e-3)
					if f > i / 3 - 0.08 then
						sum += p.Position
						n += 1
					end
				end
				pivot = n > 0 and sum / n or main.Position
				prev = main
				tailEnd = main
			end
		end
	end
	anchors.Tail = tailEnd
	rigLimbs(m, anchors, rot)
end

-- ===================================================================== gait
-- Joint angles (radians) for one leg at phase p (0..1): stance (hoof planted, the leg sweeps back)
-- then swing (the leg folds and comes forward). Front: the knee (carpus) folds the cannon back and
-- the fetlock curls; back: the stifle and hock flex together (they are linked in a real deer).
local function legAngles(front, p, duty)
	local sweep, sw
	if p < duty then
		sweep = 1 - 2 * (p / duty)
		sw = 0
	else
		local t = (p - duty) / (1 - duty)
		sweep = -math.cos(t * math.pi)
		sw = math.sin(t * math.pi)
	end
	if front then
		return 0.34 * sweep, 0.22 * sw - 0.06 * sweep, -1.3 * sw, -0.6 * sw + 0.1 * math.max(0, -sweep)
	end
	return 0.32 * sweep - 0.08 * sw, -0.5 * sw, 0.95 * sw - 0.08 * sweep, -0.7 * sw
end

-- walk: lateral sequence (back-left, front-left, back-right, front-right); run: a rotary gallop
local WALK = { BL = 0, FL = 0.25, BR = 0.5, FR = 0.75, Duty = 0.62 }
local GALLOP = { BL = 0, BR = 0.1, FL = 0.42, FR = 0.54, Duty = 0.38 }

-- Attack poses, layered on the gait: kind = "Bite" | "Swipe" | "Gore", t = 0..1 through the move.
-- Bite: a lunge with the head low, the jaw opening wide then snapping shut. Swipe: the right front
-- paw rears up and forward, then rakes down claws first. Gore (boars): the head dips, then tosses
-- the tusks up and out.
-- where in each attack pose (0..1) the strike lands; the wind-up plays up to it, the recovery after
Creatures.ATTACK_STRIKE = { Bite = 0.45, Swipe = 0.55, Gore = 0.45, Lunge = 0.5, Rear = 0.55 }

function Creatures.attack(kind, t)
	local out = {}
	if kind == "Bite" then
		local open = t < 0.45 and math.sin(t / 0.45 * math.pi / 2) or math.max(0, 1 - (t - 0.45) / 0.12)
		out.Jaw = -0.62 * open
		out.Neck = -0.28 * math.sin(math.pi * t)
		out.FL1, out.FR1 = 0.12 * math.sin(math.pi * t), 0.12 * math.sin(math.pi * t)
	elseif kind == "Swipe" then
		local lift = t < 0.55 and math.sin(t / 0.55 * math.pi / 2) or math.max(0, 1 - (t - 0.55) / 0.15)
		out.FR1, out.FR2, out.FR3, out.FR4 = 1.0 * lift, -0.3 * lift, -0.85 * lift, -0.35 * lift
		out.FL1 = -0.1 * lift
		out.Neck = -0.12 * lift
		out.Jaw = -0.25 * lift -- a snarl
	elseif kind == "Lunge" then
		-- crouch (fore legs back, hind legs under, head low, jaw opening), then spring: fore legs
		-- reach, hind legs drive back, jaws snap at the start of the reach
		if t < 0.5 then
			local k = math.sin(t / 0.5 * math.pi / 2)
			out.FL1, out.FR1, out.BL1, out.BR1 = -0.35 * k, -0.35 * k, 0.3 * k, 0.3 * k
			out.Neck, out.Jaw = -0.22 * k, -0.35 * k
		else
			local u = (t - 0.5) / 0.5
			local r = math.sin(u * math.pi)
			out.FL1, out.FR1, out.BL1, out.BR1 = 0.75 * r, 0.75 * r, -0.6 * r, -0.6 * r
			out.Neck = -0.3 * r
			out.Jaw = -0.6 * math.max(0, 1 - u * 2.5)
		end
	elseif kind == "Rear" then
		-- fore legs and head lift, then slam down (kicks and stomps)
		if t < 0.55 then
			local k = math.sin(t / 0.55 * math.pi / 2)
			out.FL1, out.FR1, out.FL2, out.FR2 = 1.1 * k, 1.1 * k, -0.6 * k, -0.6 * k
			out.BL1, out.BR1 = 0.25 * k, 0.25 * k
			out.Neck, out.Jaw = 0.3 * k, -0.3 * k
		else
			local k = math.max(0, 1 - (t - 0.55) / 0.12)
			out.FL1, out.FR1, out.FL2, out.FR2 = 1.1 * k, 1.1 * k, -0.6 * k, -0.6 * k
			out.Neck = 0.3 * k - 0.25 * (1 - k) * math.max(0, 1 - (t - 0.67) / 0.33)
		end
	elseif kind == "Gore" then
		out.Neck = t < 0.45 and -0.38 * math.sin(t / 0.45 * math.pi / 2) or (-0.38 + 0.8 * math.sin((t - 0.45) / 0.55 * math.pi))
		out.Jaw = -0.18 * math.sin(math.pi * t)
		out.FL1, out.FR1 = -0.15 * math.sin(math.pi * t), -0.15 * math.sin(math.pi * t)
	end
	return out
end

-- Bird: flaps in bursts and glides between them, the elbow and wrist lagging the shoulder so the wing
-- curls through the upstroke; the legs trail. Rear = wings open, then slam (the gust); Lunge = a dive
-- with the talons forward; Swipe and Bite = a talon rake. Right wing up is +Z, left is -Z.
local function birdAngles(state)
	local t, seed, walk = state.T or 0, state.Seed or 0, math.clamp(state.Amp or 0, 0, 1)
	local size = state.Size or 1
	local burst = math.clamp(math.sin(t * 0.33 + seed) * 1.2 + 0.5 + walk * 0.5, 0, 1)
	local a = 0.1 + 0.46 * burst
	local th = t * (3.6 + walk * 1.2) + seed
	local out = {}
	local up, sweep, down, legF = 0, 0, 0, 0
	local pitch = 0.05 + 0.07 * walk
	if state.Attack then
		local k, u = state.Attack.Kind, state.Attack.T
		if k == "Rear" then
			if u < 0.55 then
				up = 0.8 * math.sin(u / 0.55 * math.pi / 2)
			else
				local r = math.max(0, 1 - (u - 0.55) / 0.3)
				up = 0.8 * r - 1.0 * math.sin((u - 0.55) / 0.45 * math.pi)
				sweep = 0.7 * math.sin((u - 0.55) / 0.45 * math.pi)
			end
			a *= 0.2
		elseif k == "Lunge" then
			local r = math.sin(u * math.pi)
			pitch += 0.45 * r
			sweep = -0.5 * r
			legF = 1.5 * r
		else
			legF = 1.6 * math.sin(u * math.pi)
			pitch -= 0.25 * math.sin(u * math.pi)
		end
		for name, v in pairs(Creatures.attack(k, u)) do
			if name == "Neck" or name == "Jaw" then
				out[name .. "Add"] = v
			end
		end
	end
	local w1, w2, w3 = math.sin(th), math.sin(th - 0.94), math.sin(th - 1.9)
	local dih = 0.12 + up
	out.RW1 = CFrame.Angles(0, -sweep, dih + a * w1)
	out.LW1 = CFrame.Angles(0, sweep, -(dih + a * w1))
	out.RW2 = CFrame.Angles(0, 0, a * 0.6 * w2 - down)
	out.LW2 = CFrame.Angles(0, 0, -(a * 0.6 * w2 - down))
	out.RW3 = CFrame.Angles(0, 0, a * 0.8 * w3 - 0.1)
	out.LW3 = CFrame.Angles(0, 0, -(a * 0.8 * w3 - 0.1))
	out.Hips = CFrame.new(0, -a * w1 * 0.16 * size, 0) * CFrame.Angles(-pitch, 0, 0)
	for _, h in ipairs({ "RH", "LH" }) do
		out[h .. "1"] = CFrame.Angles(-0.85 + legF, 0, 0)
		out[h .. "2"] = CFrame.Angles(0.8 - legF * 0.4, 0, 0)
		out[h .. "3"] = CFrame.Angles(-0.45 + legF * 0.2, 0, 0)
	end
	out.TailFan1 = CFrame.Angles(math.sin(t * 0.7 + seed) * 0.06, 0, 0)
	local look = math.sin(t * 0.45 + seed * 3) * math.sin(t * 0.17 + seed)
	local neck = (out.NeckAdd or 0) + math.sin(th) * 0.03
	out.Neck = CFrame.Angles(neck + pitch * 0.8, look * 0.5, 0)
	out.HeadTilt = CFrame.Angles(-neck * 0.7, look * 0.2, 0)
	out.Jaw = out.JawAdd or 0
	out.NeckAdd, out.JawAdd = nil, nil
	return out
end

-- Long dragon: a wave runs down the spine from the head to the tail with the distance it travels (plus
-- a slow drift, so it never stops swimming), half as much up and down as side to side; the head turns
-- against the chain ahead of it to stay facing forward, and the legs paddle slowly.
local function serpentAngles(state)
	local t, seed, walk = state.T or 0, state.Seed or 0, math.clamp(state.Amp or 0, 0, 1)
	local snake = state.Rig == "Snake"
	-- a snake on the ground only waves as it moves (and breathes a little); a dragon always swims
	local ph = (state.Phase or 0) * math.pi * 2 + (snake and t * 0.25 or t * 1.1) + seed
	local A = snake and math.rad(3 + 13 * walk) or math.rad(8 + 5 * walk)
	local rise = {} -- extra pitch per front segment during an attack
	local headAdd = 0
	if state.Attack then
		local k, u = state.Attack.Kind, state.Attack.T
		if k == "Rear" then
			local h = u < 0.55 and math.sin(u / 0.55 * math.pi / 2) or math.max(0, 1 - (u - 0.55) / 0.15)
			rise = { 0.32 * h, 0.32 * h, 0.3 * h, 0.2 * h, -0.2 * h }
		else
			-- a coil back, then a straight strike
			local h = u < 0.45 and math.sin(u / 0.45 * math.pi / 2) or math.max(0, 1 - (u - 0.45) / 0.2)
			rise = { -0.3 * h, 0.35 * h, 0.3 * h }
			headAdd = -0.2 * h
		end
	end
	local out = {}
	local sumY, sumP = 0, 0
	for i = 1, 12 do
		local w = ph - i / 12 * math.pi * 3
		local gain = i == 4 and 0.3 or 1
		local yaw, pit = A * math.sin(w) * gain, (snake and 0 or A * 0.5 * math.cos(w * 0.5 + 0.8) * gain) + (rise[i] or 0)
		out["Spine" .. i] = CFrame.Angles(pit, yaw, 0)
		if i <= 4 then
			sumY += yaw
			sumP += pit
		end
	end
	local look = math.sin(t * 0.45 + seed * 3) * math.sin(t * 0.17 + seed)
	out.Neck = CFrame.Angles(-sumP * 0.8 + headAdd, -sumY * 0.8 + look * 0.3, 0)
	out.Hips = CFrame.new(0, snake and 0 or math.sin(t * 1.1 + seed) * 0.05 * (state.Size or 1), 0)
	for i, tag in ipairs({ "FR", "FL", "BR", "BL" }) do
		local p = math.sin(ph * 0.5 + i * 1.6)
		out[tag .. "1"] = CFrame.Angles(-0.55 + p * 0.3, 0, 0)
		out[tag .. "2"] = CFrame.Angles(0.35 + p * 0.2, 0, 0)
		out[tag .. "3"] = CFrame.Angles(-0.2 - p * 0.2, 0, 0)
	end
	return out
end

-- rig kind -> pose function (Creatures.mob copies RigKind to the Rig attribute; default "Quad" has none)
Creatures.drivers = { Bird = birdAngles, Serpent = serpentAngles, Snake = serpentAngles }

-- state = { Phase, Amp, Run, Blend (0 walk .. 1 gallop, eased), T (seconds alive), Seed, Size
-- (studs per design unit, for the body's bob), TailPhase, Attack = { Kind, T } (optional) }
-- -> { motor name = angle (radians, a pitch) or a CFrame }
-- Body language after Raise a Zoo (CHO/Animal Rig Reference (Raise a Zoo).md): the torso rides a
-- Hips joint that bobs over the planted legs, rolls toward them and rocks at a gallop, and breathes
-- when still; the head glances about on an irregular rhythm (two slow sines multiplied) and stays
-- level while the neck nods; the tail wags with a lag down its chain and streams back at a run.
-- Every wave is offset by the creature's Seed so a herd never moves in step.
function Creatures.angles(state)
	local driver = state.Rig and Creatures.drivers[state.Rig]
	if driver then
		return driver(state)
	end
	local blend = state.Blend or (state.Run and 1 or 0)
	local k = state.Amp * (1 + 0.25 * blend)
	local duty = WALK.Duty + (GALLOP.Duty - WALK.Duty) * blend
	local out = {}
	local stanceSum = 0
	for _, tag in ipairs({ "FL", "FR", "BL", "BR" }) do
		-- footfall offsets blend from the walk's to the gallop's, so the change of gait is smooth
		local off = WALK[tag] + (GALLOP[tag] - WALK[tag]) * blend
		local u = (state.Phase + off) % 1
		local a = { legAngles(tag:sub(1, 1) == "F", u, duty) }
		for i = 1, 4 do
			out[tag .. i] = a[i] * k
		end
		if u < duty then
			stanceSum += (tag:sub(2, 2) == "R") and 1 or -1
		end
	end
	local t, seed = state.T or 0, state.Seed or 0
	local walk = math.clamp(state.Amp, 0, 1)
	local idle = 1 - walk
	local size = state.Size or 1
	local ph = state.Phase * math.pi * 2
	-- torso: two bobs per walk cycle (highest over the planted legs), a lean toward the side bearing
	-- weight, a front-to-back rock at a gallop, and slow breathing when standing
	local bob = (math.cos(ph * 2) * 0.5 + 0.5) * (1 - blend) + (math.max(0, math.sin(ph - 1)) * 1.4) * blend
	local y = (bob - 0.5) * 0.06 * size * walk + math.sin(t * 2 + seed) * 0.035 * size * idle
	local pitch = math.sin(ph + 0.4) * 0.05 * blend * walk + math.sin(t * 1.4 + seed) * 0.015 * idle
	local roll = (stanceSum / 4) * 0.035 * walk * (1 - blend)
	local twist = math.sin(ph) * 0.03 * walk
	out.Hips = CFrame.new(0, y, 0) * CFrame.Angles(pitch, twist, roll)
	-- head: nods twice per stride at a walk, reaches with the stride at a gallop; glances about when
	-- idle (product of two slow sines: looks, pauses, looks back); the head counter-tilts to stay level
	local nod = (0.05 * math.sin(ph * 2)) * (1 - blend) + (0.12 * math.sin(ph)) * blend
	local look = math.sin(t * 0.45 + seed * 3) * math.sin(t * 0.17 + seed)
	local neckPitch = nod * state.Amp + math.sin(t * 2 + seed) * 0.03 * idle + (state.Look or 0)
	out.Neck = CFrame.Angles(neckPitch, look * 0.45 * idle, 0)
	out.HeadTilt = CFrame.Angles(-neckPitch * 0.85 - pitch, look * 0.2 * idle, 0)
	-- tail: the root wags, each segment lags behind the one before; at a run it streams back
	local tp = state.TailPhase or t * 2.5
	local run = blend
	for i = 1, 3 do
		local lag = tp + seed - (i - 1) * 0.75
		local yaw = math.sin(lag) * (0.12 + 0.1 * walk) * (1 + 0.25 * (i - 1)) * (1 - 0.6 * run)
		local tpitch = (i == 1 and -0.25 * run or 0) + math.sin(lag * 0.5 + 1.3) * 0.05 * (1 - run)
		out["Tail" .. i] = CFrame.Angles(tpitch, yaw, 0)
	end
	out.Jaw = 0
	if state.Attack then
		for name, v in pairs(Creatures.attack(state.Attack.Kind, state.Attack.T)) do
			local cur = out[name]
			if typeof(cur) == "CFrame" then
				out[name] = cur * CFrame.Angles(v, 0, 0)
			else
				out[name] = (cur or 0) + v
			end
		end
	end
	return out
end

local HAIR_AMP = { 0.05, 0.09, 0.13 }

-- drive the rig's motors (the client keeps one state per creature); motors = { name = Motor6D }, and
-- _Hair = the strand motors, listed separately so a mane costs nothing on animals without one
function Creatures.pose(motors, state)
	for name, a in pairs(Creatures.angles(state)) do
		local mo = motors[name]
		if mo then
			mo.Transform = typeof(a) == "CFrame" and a or CFrame.Angles(a, 0, 0)
		end
	end
	-- hair (Raise a Zoo): two clocks, each segment lags the one before and swings further; it stirs
	-- at rest, swings with the stride and streams back at a run
	local hair = motors._Hair
	if hair then
		local t, seed = state.T or 0, state.Seed or 0
		local walk, run = math.clamp(state.Amp, 0, 1), state.Blend or 0
		for _, h in ipairs(hair) do
			local lag = (h.Seg - 1) * 1.25
			local gain = (HAIR_AMP[h.Seg] or 0.05) * (1 + walk * 1.2)
			local w1 = math.sin(t * 1.9 + seed + h.N * 0.7 - lag)
			local w2 = math.sin(t * 1.1 + seed * 2 + h.N * 1.3 - lag)
			h.Motor.Transform = CFrame.Angles(gain * w1 - run * 0.2 * h.Seg, 0, gain * w2)
		end
	end
end

function Creatures.motors(m)
	local t = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") then
			if d:GetAttribute("Hair") then
				t._Hair = t._Hair or {}
				table.insert(t._Hair, { Motor = d, N = d:GetAttribute("Hair"), Seg = d:GetAttribute("Seg") })
			else
				t[d.Name] = d
			end
		end
	end
	return t
end

-- ===================================================================== mobs
-- A Humanoid mob built from a recipe: HumanoidRootPart (the body box) + rig. Same contract as
-- Builders.Mob: pivot on the ground at cf, front -Z, HipHeight to the bottom of the root.
function Creatures.mob(id, def, cf)
	local look = Creatures.Looks[id]
	local m = Creatures.build(look[1], look[2])
	m.Name = id
	local design = m.PrimaryPart
	local rootC, rootS = m:GetAttribute("RootC"), m:GetAttribute("RootS")
	local hrp = newPart("Part", m, CFrame.new(rootC), rootS, Color3.new(1, 1, 1), "HumanoidRootPart")
	hrp.Transparency = 1
	hrp.CanQuery = true
	hrp.CastShadow = false
	m.PrimaryPart = hrp
	design:Destroy()
	-- bipeds and floaters match Size.Y (their Size.Z is only a thin depth)
	local k = m:GetAttribute("Height") and def.Size.Y / m:GetAttribute("Height") or def.Size.Z / (m:GetAttribute("Length") or 6.2)
	m:ScaleTo(k)
	m:SetAttribute("NeckBase", (m:GetAttribute("NeckBase") or Vector3.zero) * k)
	for _, a in ipairs({ "JawPivot", "HeadPivot" }) do
		if m:GetAttribute(a) then
			m:SetAttribute(a, m:GetAttribute(a) * k)
		end
	end
	local hover = (m:GetAttribute("Hover") or 0) * k
	m:PivotTo(cf * CFrame.new(0, rootC.Y * k + hover, 0))
	Creatures.rig(m, hrp)
	hrp.Anchored = false
	if def.Kind == "Boss" or def.Kind == "Event" then
		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = hrp
	end
	local hum = Instance.new("Humanoid")
	hum.HipHeight = math.max(0.1, (rootC.Y - rootS.Y / 2) * k) + hover
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = m
	m:SetAttribute("Rig", m:GetAttribute("RigKind") or "Quad")
	m:SetAttribute("Stride", (m:GetAttribute("Stride") or 3.3) * k) -- distance per walk cycle
	m:SetAttribute("RigScale", k) -- the body's bob and breathing scale with it (Creatures.angles)
	return m
end

function Creatures.has(kind)
	return recipes[kind] ~= nil
end

-- what the second recipes module (CreatureRecipes2) builds with
Creatures.recipes = recipes
Creatures.kit = { rnd = rnd, scale = scale, scaleStrip = scaleStrip, chain = chain, auraNode = auraNode, newPart = newPart, strand = strand, BOX = BOX, weld = weld }

function Creatures.build(kind, opts)
	local m = Instance.new("Model")
	m.Name = kind
	local size = recipes[kind](m, opts or {})
	local root = newPart("Part", m, CFrame.new(0, size.Y / 2, 0), size, Color3.new(1, 1, 1), "Root")
	root.Transparency = 1
	root.CastShadow = false
	m.PrimaryPart = root
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			d.CastShadow = true
		end
	end
	return m
end

-- the rest of the bestiary lives in its own module (the dev tools load it themselves, with no script)
if script and script.Parent and script.Parent:FindFirstChild("CreatureRecipes2") then
	require(script.Parent.CreatureRecipes2)(Creatures)
end

return Creatures
