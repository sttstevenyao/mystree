# Moonhorn Stag (Willow Fields rare) - quality-bar prototype for the Mystree creature pass.
# Run: /Volumes/Blender/Blender.app/Contents/MacOS/Blender -b -P stag.py -- [render]
# Real red-deer proportions: withers 4.2 studs, chest depth ~45% of that, legs ~55%, a long neck
# carried high, tucked belly, slim legs with knee/hock/fetlock and split hooves.
# Built with mystree_sdf: every piece is one blended surface (no floating hooves, no gaps), eyes sit
# in carved sockets, ears are cupped. Mystree twist: silver coat, crescent "moon" antlers whose tips
# glow, a glowing crescent on each flank (glow parts are separate objects).
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import mystree_kit as K
import mystree_sdf as D
importlib.reload(K)
importlib.reload(D)
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out_stag")
os.makedirs(OUT, exist_ok=True)
K.clear_scene()

COAT = (206, 212, 224)
BACK = (160, 170, 192)
MANE = (138, 148, 170)
WHITE = (244, 246, 250)
LEGDARK = (128, 136, 154)
HOOF = (46, 48, 58)
NOSE = (40, 42, 50)
ANTLER = (234, 238, 246)
BURR = (176, 182, 196)
GLOW = (150, 226, 255)
E, C, chain = D.ellipsoid, D.cone, D.chain

# ---------------------------------------------------------------- body: torso, neck, head, ears, tail
body = D.Sculpt()
body.add([E((0, 0.95, 3.35), (0.8, 1.2, 0.95)),       # ribcage
          E((0, -0.35, 3.4), (0.76, 1.15, 0.8)),       # belly, tucked up
          E((0, -1.5, 3.5), (0.72, 0.95, 0.82)),       # hindquarters
          E((0, 1.3, 4.0), (0.42, 0.7, 0.36)),         # withers
          E((0, 1.95, 3.15), (0.5, 0.4, 0.45))], k=0.45)  # brisket
for s in (1, -1):
    body.add([E((s * 0.42, 1.45, 3.55), (0.38, 0.55, 0.75)),   # shoulder
              E((s * 0.45, -1.65, 3.25), (0.36, 0.72, 0.82))], k=0.3)  # thigh
body.add([C((0, 1.6, 3.85), 0.6, (0, 2.55, 5.25), 0.3),        # neck
          C((0, 1.95, 3.35), 0.42, (0, 2.7, 5.0), 0.26)], k=0.35)  # throat
body.add([E((0, 2.82, 5.55), (0.34, 0.42, 0.34)),              # skull
          C((0, 3.0, 5.5), 0.29, (0, 3.85, 5.2), 0.14),        # face
          C((0, 2.85, 5.3), 0.22, (0, 3.75, 5.08), 0.1),       # jaw
          E((0, 3.88, 5.17), (0.16, 0.2, 0.17))], k=0.15)      # muzzle
body.add(C((0, -2.3, 3.95), 0.17, (0, -2.55, 3.55), 0.1), k=0.12)  # tail
for s in (1, -1):
    body.add(E((s * 0.5, 2.72, 5.95), (0.34, 0.07, 0.15), rot=(0, -25 * s, 12 * s)), k=0.06)  # ear
    body.sub(E((s * 0.54, 2.77, 5.97), (0.25, 0.045, 0.1), rot=(0, -25 * s, 12 * s)), k=0.02)  # ear cup
    body.sub(E((s * 0.065, 4.06, 5.16), (0.035, 0.04, 0.028)), k=0.01)  # nostril

# eyes: find the skin beside the eye, carve a socket and sit the eyeball in it (recessed, no gap)
EYE_Y, EYE_Z = 3.1, 5.62
xs = np.linspace(0, 0.8, 801)
P = np.stack([xs, np.full_like(xs, EYE_Y), np.full_like(xs, EYE_Z)], 1)
skin_x = float(xs[np.argmax(body.field(P) > 0)])
eye_specs = []
for s in (1, -1):
    body.sub(E((s * (skin_x - 0.05), EYE_Y, EYE_Z), (0.1, 0.12, 0.095)), k=0.03)
    eye_specs.append((s * (skin_x - 0.07), EYE_Y, EYE_Z))
body_ob = body.mesh("Body", step=0.035)
K.bake(body_ob, 3200, subdiv=0, jitter=0.004)
rng = np.random.default_rng(3)


def tone(col, amt=0.03):
    f = 1 + rng.uniform(-amt, amt)
    return tuple(min(255, c * f) for c in col)


def body_colour(c, n):
    if c.y > 3.93 and c.z > 5.08 and n.y > 0.2:
        return NOSE  # wet nose
    if c.y > 3.6 and c.z < 5.12:
        return WHITE  # chin
    if 2.0 < c.y < 3.3 and 3.6 < c.z < 5.35 and n.y > 0.1 and n.z < 0.3 and abs(c.x) < 0.3:
        return WHITE  # throat patch
    if c.y < -1.85 and n.y < -0.25 and 2.9 < c.z < 4.1:
        return WHITE  # rump patch around the tail
    if c.y < -2.2 and c.z > 3.5 and n.z > 0.3:
        return MANE  # dark top of the tail
    if n.z < -0.55 and -1.4 < c.y < 1.5:
        return tone(WHITE, 0.015)  # belly
    if 1.5 < c.y < 2.9 and c.z > 4.1 and n.y < 0.5:
        return tone(K.mix(BACK, MANE, 0.5 + 0.5 * max(0, n.z)))  # darker neck mane
    if n.z > 0.5 and c.y < 1.8:
        return tone(K.mix(COAT, BACK, (n.z - 0.5) * 2))  # back saddle
    if c.y > 3.3 and n.z > 0.2:
        return tone(K.mix(COAT, BACK, 0.6))  # darker bridge of the nose
    return tone(K.mix(COAT, BACK, max(0, n.z) * 0.4))
K.paint(body_ob, body_colour)

eyes = []
for p in eye_specs:
    e = K.ellipsoid("Eye", p, (0.2, 0.22, 0.18), 12, 8)
    K.paint(e, lambda c, n: (250, 250, 250) if (n.z > 0.55 and n.y > 0.25) else (20, 24, 36))  # glint
    eyes.append(e)

# ---------------------------------------------------------------- legs: hip to hoof in one piece
legs = []
def leg(pts, radii, extras):
    sc = D.Sculpt()
    sc.add(chain(pts[:3], radii[:3], squash=(0.75, 1, 1)), k=0.12)
    sc.add(chain(pts[2:], radii[2:]), k=0.05)
    for prim, k in extras:
        sc.add(prim, k=k)
    ob = sc.mesh("Leg", step=0.025)
    K.bake(ob, 460, subdiv=0, jitter=0.003)
    def col(c, n):
        if c.z < 0.21:
            return HOOF
        if n.z < -0.4 and c.z > 2.3:
            return WHITE  # inner thigh / elbow underside
        return tone(K.mix(COAT, LEGDARK, (1.9 - c.z) / 1.4))
    K.paint(ob, col)
    legs.append(ob)

def toes(x, y):
    return [(E((x + d, y, 0.1), (0.06, 0.15, 0.1), rot=(-15, 0, 0)), 0.03) for d in (-0.05, 0.05)]

for s in (1, -1):
    x = s * 0.42
    leg([(x, 1.5, 3.6), (x, 1.38, 2.55), (x * 0.95, 1.48, 1.45), (x * 0.95, 1.5, 0.45), (x * 0.95, 1.6, 0.18)],
        [0.36, 0.22, 0.12, 0.09, 0.085],
        [(E((x, 1.42, 2.25), (0.17, 0.21, 0.45)), 0.12),            # forearm muscle
         (E((x * 0.95, 1.49, 1.45), (0.12, 0.13, 0.14)), 0.05),     # knee (carpus)
         (E((x * 0.95, 1.5, 0.45), (0.1, 0.12, 0.11)), 0.04)] + toes(x * 0.95, 1.68))
    x = s * 0.45
    leg([(x, -1.55, 3.45), (x * 1.05, -1.0, 2.55), (x * 0.95, -1.95, 1.5), (x * 0.95, -1.85, 0.45), (x * 0.95, -1.75, 0.18)],
        [0.42, 0.3, 0.12, 0.09, 0.085],
        [(E((x, -1.48, 2.02), (0.16, 0.25, 0.42), rot=(-42, 0, 0)), 0.12),  # gaskin
         (E((x * 0.95, -2.03, 1.55), (0.09, 0.1, 0.12)), 0.05),             # point of the hock
         (E((x * 0.95, -1.85, 0.45), (0.1, 0.12, 0.11)), 0.04)] + toes(x * 0.95, -1.67))

# ---------------------------------------------------------------- crescent antlers, rooted in the skull
antlers, glows = [], []
for s in (1, -1):
    beam = [(s * 0.2, 2.78, 5.8), (s * 0.3, 2.72, 6.15), (s * 0.5, 2.62, 6.6), (s * 0.75, 2.5, 7.15),
            (s * 0.92, 2.55, 7.7), (s * 0.95, 2.8, 8.15), (s * 0.82, 3.15, 8.45), (s * 0.6, 3.45, 8.55)]
    tines = [([(s * 0.4, 2.68, 6.4), (s * 0.5, 3.0, 6.5), (s * 0.55, 3.3, 6.75)], [0.07, 0.05, 0.03]),
             ([(s * 0.72, 2.52, 7.05), (s * 0.85, 2.85, 7.2), (s * 0.92, 3.12, 7.45)], [0.06, 0.045, 0.028]),
             ([(s * 0.93, 2.6, 7.85), (s * 1.2, 2.75, 8.1), (s * 1.32, 2.85, 8.4)], [0.055, 0.04, 0.025])]
    sc = D.Sculpt()
    sc.add(chain(beam, [0.13, 0.12, 0.1, 0.09, 0.08, 0.065, 0.05, 0.035]), k=0.05)
    sc.add(E((s * 0.3, 2.72, 6.12), (0.16, 0.16, 0.08)), k=0.04)  # burr
    for pts, rad in tines:
        sc.add(chain(pts, rad), k=0.05)
    ant = sc.mesh("Antler", step=0.02)
    K.bake(ant, 900, subdiv=0, jitter=0.002)
    K.paint(ant, lambda c, n: tone(K.mix(BURR, ANTLER, (c.z - 6.0) / 0.8), 0.02))
    antlers.append(ant)
    # glow crystals cap each tip (the tip ends inside the crystal, so there is no gap)
    for tip in [beam[-1]] + [pts[-1] for pts, _ in tines]:
        g = K.ellipsoid("AntlerGlow", tip, (0.13, 0.13, 0.13), 8, 6)
        K.solid(g, GLOW)
        glows.append(g)

# ---------------------------------------------------------------- flank crescents (glow), 0.025 proud
deps = bpy.context.evaluated_depsgraph_get()
tree = BVHTree.FromObject(body_ob, deps)
for s in (1, -1):
    outer, inner = [], []
    N = 24
    for i in range(N + 1):
        t = i / N
        a = math.radians(205 + t * 130)
        w = 0.1 * math.sin(math.pi * t)
        for r, lst in ((0.5, outer), (0.5 - w, inner)):
            p = Vector((s * 1.2, 0.3 + math.cos(a) * r, 3.75 + math.sin(a) * r))
            hit = tree.find_nearest(p)
            lst.append(hit[0] + hit[1] * 0.025)
    bm = bmesh.new()
    vo = [bm.verts.new(q) for q in outer]
    vi = [bm.verts.new(q) for q in inner]
    for i in range(N):
        for f in ((vo[i], vo[i + 1], vi[i + 1]), (vo[i], vi[i + 1], vi[i])):
            if len({v.index for v in f}) == 3 and (f[1].co - f[0].co).cross(f[2].co - f[0].co).length > 1e-7:
                face = bm.faces.new(f)
                if face.normal.x * s < 0:
                    face.normal_flip()
    me = bpy.data.meshes.new("FlankGlow")
    bm.to_mesh(me)
    bm.free()
    fg = bpy.data.objects.new("FlankGlow", me)
    bpy.context.scene.collection.objects.link(fg)
    K.solid(fg, GLOW)
    glows.append(fg)

parts = [body_ob] + eyes + legs + antlers + glows
counts = {"Body": K.tri_count(body_ob), "Legs": sum(K.tri_count(l) for l in legs),
          "Antlers": sum(K.tri_count(a) for a in antlers), "Total": sum(K.tri_count(p) for p in parts)}
print("TRIS", counts, "skin_x", round(skin_x, 3))

if "render" in sys.argv:
    cam = K.setup_preview()
    tgt = (0, 0.6, 4.0)
    K.shoot(cam, os.path.join(OUT, "side.png"), 90, 6, tgt, 19)
    K.shoot(cam, os.path.join(OUT, "three_quarter.png"), 45, 10, tgt, 19)
    K.shoot(cam, os.path.join(OUT, "front.png"), 0, 6, tgt, 19)
    K.shoot(cam, os.path.join(OUT, "back.png"), 215, 12, tgt, 19)
    K.shoot(cam, os.path.join(OUT, "head.png"), 35, 8, (0, 3.1, 6.3), 8)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "stag.blend"))
