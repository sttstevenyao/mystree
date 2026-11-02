# Projects deer_spec.json into 2D outlines (side / front / top) for the template drawing.
# Prints compact SVG path data (px, 95 px per stud) that the template artboards embed.
import json, math, sys
S = 95
spec = json.load(open(sys.argv[1]))
V = lambda *a: [float(x) for x in a]
add = lambda a, b: [a[i] + b[i] for i in range(3)]
sub = lambda a, b: [a[i] - b[i] for i in range(3)]
mul = lambda a, k: [x * k for x in a]
def unit(a):
    l = math.sqrt(sum(x * x for x in a)); return [x / l for x in a]
def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
X = [1, 0, 0]
def sp(v, e): return math.copysign(abs(v) ** e, v)
def ring(c, side, u, hw, top, bot, n):
    pts = []
    for j in range(n):
        a = j / n * math.pi * 2
        s, co = math.sin(a), math.cos(a)
        pts.append(add(add(c, mul(side, hw * sp(s, .8))), mul(u, (top if co > 0 else bot) * sp(co, .8))))
    return pts
poll, nose = spec["poll"], spec["nose"]
D = unit(sub(nose, poll)); U = unit(cross(X, D)); hl = math.dist(poll, nose)

# views: side (z right, y up) origin; front (x, y); top (z, x)
def side(p, ox, oy): return (ox + p[2] * S, oy - p[1] * S)
def front(p, ox, oy): return (ox + p[0] * S, oy - p[1] * S)
def top(p, ox, oy): return (ox + p[2] * S, oy + p[0] * S)
def path(pts, close=True):
    return "M" + " L".join(f"{x:.0f} {y:.0f}" for x, y in pts) + (" Z" if close else "")

out = {}
OXS, OYS = 420, int(sys.argv[2]) if len(sys.argv) > 2 else 600   # side view origin (ground under z = 0)
# torso side outline
T = spec["torso"]; caps = spec["torsoCaps"]
tops = [(t[0], t[1] + t[3]) for t in T]; bots = [(t[0], t[1] - t[4]) for t in T]
poly = [side([0, caps[0][1], caps[0][2]], OXS, OYS)] + [side([0, y, z], OXS, OYS) for z, y in tops] + [side([0, caps[1][1], caps[1][2]], OXS, OYS)] + [side([0, y, z], OXS, OYS) for z, y in reversed(bots)]
out["torso"] = path(poly)
out["torsoRings"] = " ".join(path([side([0, t[1] + t[3], t[0]], OXS, OYS), side([0, t[1] - t[4], t[0]], OXS, OYS)], False) for t in T[1:-1])
# neck
N = []
for r in spec["neck"]:
    if r[0] == "head":
        c = add(add(poll, mul(D, hl * r[1])), mul(U, r[2])); N.append((c, r[3], r[4], r[5]))
    else:
        N.append((r[0], r[1], r[2], r[3]))
npts_t, npts_b = [], []
for i, (c, hw, t, b) in enumerate(N):
    d = unit(sub(N[min(i + 1, len(N) - 1)][0], N[max(i - 1, 0)][0])); u = unit(cross(d, X))
    npts_t.append(side(add(c, mul(u, t)), OXS, OYS)); npts_b.append(side(sub(c, mul(u, b)), OXS, OYS))
out["neck"] = path(npts_t + list(reversed(npts_b)))
# head
H = spec["head"]
ht = [side(add(add(poll, mul(D, hl * r[0])), mul(U, r[2])), OXS, OYS) for r in H]
hb = [side(sub(add(poll, mul(D, hl * r[0])), mul(U, r[3])), OXS, OYS) for r in H]
out["head"] = path([side(sub(poll, mul(D, .1)), OXS, OYS)] + ht + [side(add(nose, mul(D, .08)), OXS, OYS)] + list(reversed(hb)))
# muzzle band (t .68-.9) and nose (t > .9), side
def headPt(t, k): r = None
def hpt(t, upk):
    # interpolate ring at t
    for i in range(len(H) - 1):
        a, b = H[i], H[i + 1]
        if t <= b[0]:
            f = (t - a[0]) / (b[0] - a[0]); tp = a[2] + (b[2] - a[2]) * f; bt = a[3] + (b[3] - a[3]) * f; break
    c = add(poll, mul(D, hl * t))
    return side(add(c, mul(U, tp)) if upk > 0 else sub(c, mul(U, bt)), OXS, OYS)
out["muzzle"] = path([hpt(.68, 1), hpt(.9, 1), hpt(.9, -1), hpt(.68, -1)])
out["noseTip"] = path([hpt(.9, 1), hpt(1.0, 1), side(add(nose, mul(D, .08)), OXS, OYS), hpt(1.0, -1), hpt(.9, -1)])
# eye
ec = add(add(poll, mul(D, hl * .24)), mul(U, .08)); ex, ey = side(ec, OXS, OYS)
out["eye"] = [round(ex), round(ey)]
# ear (side): leaf from root up/back
er = spec["ear"]; root = add(add(add(poll, mul(D, hl * er["root"][0])), mul(U, er["root"][1])), [er["root"][2], 0, 0])
edir = unit(add(add(mul(X, .75), mul(U, .95)), mul(D, -.35)))
fwd = unit(add(mul(D, -1), mul(X, .9))); sdir = unit(cross(edir, fwd))
L, W = er["length"], er["width"]
def eat(f, w): return side(add(add(root, mul(edir, L * f)), mul(sdir, W * w)), OXS, OYS)
out["ear"] = path([eat(0, 0), eat(.3, 1), eat(.68, .9), eat(1, 0), eat(.68, -.9), eat(.3, -1)])
# tail
tl = spec["tail"]
out["tail"] = path([side(p, OXS, OYS) for p in tl], False)

# legs (side): rings along each bone; draw each bone as a strip
def bone(pts):
    tp, bt = [], []
    for i, (p, d) in enumerate(pts):
        a, b = pts[max(i - 1, 0)][0], pts[min(i + 1, len(pts) - 1)][0]
        dd = unit(sub(b, a)); u = unit(cross(dd, X))
        tp.append(side(add(p, mul(u, d)), OXS, OYS)); bt.append(side(sub(p, mul(u, d)), OXS, OYS))
    return path(tp + list(reversed(bt)))
def legs(L, front_leg):
    x = L["x"]; J = L["joints"]; w = L["widths"]
    P = lambda k: [x, J[k][0], J[k][1]]
    up = [0, 1, 0]
    if front_leg:
        a, b, c, d, h = P("shoulder"), P("elbow"), P("knee"), P("fetlock"), P("hoof")
        names = ["shoulder", "elbow", "knee", "fetlock"]
        bones = [
            [(add(a, [0, .35, .1]), w["shoulder"][1] * .6), (a, w["shoulder"][1]), (b, w["elbow"][1])],
            [(add(b, [0, .12, 0]), w["elbow"][1] * .85), (add(b, mul(sub(c, b), .35)), w["forearm"][1]), (c, w["knee"][1])],
            [(add(c, [0, .1, 0]), w["cannon"][1] * .95), (d, w["fetlock"][1])],
            [(add(d, [0, .08, 0]), w["pastern"][1]), (add(h, [0, .24, -.02]), w["pastern"][1] * 1.1), (add(h, [0, .02, -.04]), w["hoof"][1])],
        ]
    else:
        a, b, c, d, h = P("hip"), P("stifle"), P("hock"), P("fetlock"), P("hoof")
        names = ["hip", "stifle", "hock", "fetlock"]
        bones = [
            [(add(a, [0, .3, .12]), w["hip"][1] * .65), (a, w["hip"][1]), (b, w["stifle"][1])],
            [(add(b, [0, .12, -.04]), w["stifle"][1] * .85), (add(b, mul(sub(c, b), .45)), w["gaskin"][1]), (c, w["hock"][1])],
            [(add(c, [0, .12, 0]), w["cannon"][1] * .95), (d, w["fetlock"][1])],
            [(add(d, [0, .08, 0]), w["pastern"][1]), (add(h, [0, .24, -.02]), w["pastern"][1] * 1.1), (add(h, [0, .02, -.04]), w["hoof"][1])],
        ]
    hoof = path([side(add(h, [0, .28, -.2]), OXS, OYS), side(add(h, [0, .28, .14]), OXS, OYS), side(add(h, [0, 0, .16]), OXS, OYS), side(add(h, [0, 0, -.3]), OXS, OYS)])
    js = [[names[i], *[round(v) for v in side(p, OXS, OYS)]] for i, p in enumerate([a, b, c, d])]
    return [bone(bn) for bn in bones], hoof, js
out["frontLeg"], out["frontHoof"], out["frontJoints"] = legs(spec["front"], True)
out["backLeg"], out["backHoof"], out["backJoints"] = legs(spec["back"], False)

# FRONT VIEW: origin at x centre
OXF, OYF = 990, OYS
chest = [t for t in T if t[0] == -1.0][0]
rg = ring([0, chest[1], 0], X, [0, 1, 0], chest[2], chest[3], chest[4], 8)
out["fTorso"] = path([front(p, OXF, OYF) for p in rg])
nc = N[1]; rgn = ring(nc[0], X, [0, 1, 0], nc[1], nc[2], nc[3], 6)
out["fNeck"] = path([front(p, OXF, OYF) for p in rgn])
hc = add(poll, mul(D, hl * .15)); rgh = ring(hc, X, U, H[1][1], H[1][2], H[1][3], 6)
out["fHead"] = path([front(p, OXF, OYF) for p in rgh])
mc = add(poll, mul(D, hl * .8)); rgm = ring(mc, X, U, .29, .28, .3, 6)
out["fMuzzle"] = path([front(p, OXF, OYF) for p in rgm])
nc2 = add(nose, mul(D, .02)); rgn2 = ring(nc2, X, U, .2, .2, .21, 6)
out["fNose"] = path([front(p, OXF, OYF) for p in rgn2])
# ears front: leaf outline projected on x,y
def eatF(f, w, sx):
    r2 = [root[0] * sx, root[1], root[2]]
    ed = unit(add(add(mul(X, .75 * sx), mul(U, .95)), mul(D, -.35)))
    fw = unit(add(mul(D, -1), mul(X, .9 * sx))); sd = unit(cross(ed, fw))
    return front(add(add(r2, mul(ed, L * f)), mul(sd, W * w)), OXF, OYF)
out["fEars"] = [path([eatF(0, 0, s), eatF(.3, 1, s), eatF(.68, .9, s), eatF(1, 0, s), eatF(.68, -.9, s), eatF(.3, -1, s)]) for s in (1, -1)]
fl = []
for L_, keys in ((spec["front"], ["shoulder", "elbow", "knee", "fetlock", "hoof"]),):
    pass
def fleg(Ls, keys, wkeys, sx):
    x = Ls["x"] * sx; J = Ls["joints"]; w = Ls["widths"]
    ys = [J[k][0] for k in keys]
    hw = [w[k][0] for k in wkeys]
    left = [front([x - hw[i] , ys[i], 0], OXF, OYF) for i in range(len(ys))]
    right = [front([x + hw[i], ys[i], 0], OXF, OYF) for i in range(len(ys))]
    return path(left + list(reversed(right)))
out["fFrontLegs"] = [fleg(spec["front"], ["elbow", "knee", "fetlock", "hoof"], ["elbow", "knee", "fetlock", "hoof"], s) for s in (1, -1)]
out["fBackLegs"] = [fleg(spec["back"], ["stifle", "hock", "fetlock", "hoof"], ["stifle", "hock", "fetlock", "hoof"], s) for s in (1, -1)]
out["fFrontEyes"] = [[round(v) for v in front([s * (H[1][1] * .891 + .0), ec[1], 0], OXF, OYF)] for s in (1, -1)]

# TOP VIEW: z horizontal like the side view, x vertical
OXT, OYT = 420, OYS + 225
tt = [top([t[2], 0, t[0]], OXT, OYT) for t in T]; tb = [top([-t[2], 0, t[0]], OXT, OYT) for t in T]
out["tTorso"] = path([top([0, 0, caps[0][2]], OXT, OYT)] + tt + [top([0, 0, caps[1][2]], OXT, OYT)] + list(reversed(tb)))
hpts = [(add(poll, mul(D, hl * r[0])), r[1]) for r in H]
out["tHead"] = path([top(sub(poll, mul(D, .1)), OXT, OYT)] + [top([hw, 0, c[2]], OXT, OYT) for c, hw in hpts] + [top(add(nose, mul(D, .08)), OXT, OYT)] + [top([-hw, 0, c[2]], OXT, OYT) for c, hw in reversed(hpts)])
out["tNeck"] = path([top([hw, 0, c[2]], OXT, OYT) for c, hw, _, _ in N] + [top([-hw, 0, c[2]], OXT, OYT) for c, hw, _, _ in reversed(N)])
out["tEars"] = [path([top([p, 0, 0], 0, 0) for p in []]) for s in (1, -1)]

# ANTLERS (stag): beam + tines, side and front, as stroke polylines with per-segment width
hp = add(add(poll, mul(D, .15)), mul(U, .25))
beam = [(.18, 0, .05), (.5, .55, .3), (.95, 1.25, .5), (1.32, 1.95, .36), (1.48, 2.6, -.05), (1.32, 3.1, -.55)]
radii = [.14, .12, .105, .09, .075, .05]
tines = [(2, (.15, .3, -.9), .08), (3, (.05, .9, -.55), .07), (4, (.15, .85, -.35), .065), (5, (.35, .7, -.05), .055)]
def antler(view, ox, oy, sx):
    segs = []
    P = [add(hp, [sx * b[0], b[1], b[2]]) for b in beam]
    for i in range(len(P) - 1):
        a, b = view(P[i], ox, oy), view(P[i + 1], ox, oy)
        segs.append([round(a[0]), round(a[1]), round(b[0]), round(b[1]), round((radii[i] + radii[i + 1]) * S)])
    tips = [view(P[-1], ox, oy)]
    for bi, t, r in tines:
        p0 = P[bi - 1]; p1 = add(p0, [sx * t[0], t[1], t[2]])
        a, b = view(p0, ox, oy), view(p1, ox, oy)
        segs.append([round(a[0]), round(a[1]), round(b[0]), round(b[1]), round(r * 1.6 * S)])
        tips.append(b)
    return segs, [[round(x), round(y)] for x, y in tips]
out["aSide"] = antler(side, OXS, OYS, 1)
out["aFront"] = [antler(front, OXF, OYF, s) for s in (1, -1)]
print(json.dumps(out))
