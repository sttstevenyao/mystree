# Builds the template SVG (side, front and top views + spec) from deer_geom.py's outlines.
# usage: python3 deer_svg.py doe|moonhorn > out.svg
import json, subprocess, sys
kind = sys.argv[1]
stag = kind == "moonhorn"
OY = 940 if stag else 600
g = json.loads(subprocess.check_output(["python3", "deer_geom.py", "deer_spec.json", str(OY)]))
spec = json.load(open("deer_spec.json"))
S = 95
W, Hh = 1600, (1280 if stag else 960)
if stag:
    C = dict(coat="#D7DCE7", mane="#7C8AAC", face="#C8D0E2", white="#F8F9FC", dark="#2C3042", shin="#68749A", hoof="#96A0BA", line="#3E4A68", far="#A9B2C8", antler="#ECEFF6", glow="#82DCFF")
else:
    C = dict(coat="#B8794A", mane="#B8794A", face="#B8794A", white="#F1ECE3", dark="#2B2729", shin="#A56C42", hoof="#3A302C", line="#5E3A22", far="#8E5A35", antler="#AA9C86", glow=None)
o = []
A = o.append
A(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{Hh}" viewBox="0 0 {W} {Hh}" role="img" aria-label="{"Moonhorn Stag" if stag else "Deer"} template: side, front and top views on a stud grid">')
A(f'<rect width="{W}" height="{Hh}" fill="#F6F3EC"/>')
# grid panels
def grid(x0, y0, x1, y1, ox, oy):
    A(f'<g aria-hidden="true">')
    k = 0.25
    xs = ox
    # vertical lines
    v = ox - int((ox - x0) / (S * k)) * S * k
    while v <= x1:
        major = abs(((v - ox) / S) - round((v - ox) / S)) < 1e-6
        A(f'<line x1="{v:.1f}" y1="{y0}" x2="{v:.1f}" y2="{y1}" stroke="{"#D3C9B4" if major else "#E8E2D5"}" stroke-width="1"/>')
        v += S * k
    h = oy - int((oy - y0) / (S * k)) * S * k
    while h <= y1:
        major = abs(((oy - h) / S) - round((oy - h) / S)) < 1e-6
        A(f'<line x1="{x0}" y1="{h:.1f}" x2="{x1}" y2="{h:.1f}" stroke="{"#D3C9B4" if major else "#E8E2D5"}" stroke-width="1"/>')
        h += S * k
    A('</g>')
top = 70
grid(40, top, 760, OY + 10, 420, OY)
grid(800, top, 1180, OY + 10, 990, OY)
grid(40, OY + 75, 760, OY + 330, 420, OY + 225)
def label(x, y, t, size=15, w=600, col="#3B3428", anchor="start"):
    A(f'<text x="{x}" y="{y}" font-family="Inter, Arial, sans-serif" font-size="{size}" font-weight="{w}" fill="{col}" text-anchor="{anchor}">{t}</text>')
label(40, 52, "SIDE VIEW", 14, 700, "#7A6E58")
label(800, 52, "FRONT VIEW", 14, 700, "#7A6E58")
label(40, OY + 62, "TOP VIEW", 14, 700, "#7A6E58")
# ground lines
A(f'<line x1="40" y1="{OY}" x2="760" y2="{OY}" stroke="#7A6E58" stroke-width="2"/>')
A(f'<line x1="800" y1="{OY}" x2="1180" y2="{OY}" stroke="#7A6E58" stroke-width="2"/>')
stroke = f'stroke="{C["line"]}" stroke-width="1.6" stroke-linejoin="round"'
def P(d, fill, extra=""):
    A(f'<path d="{d}" fill="{fill}" {stroke} {extra}/>')
# SIDE: far legs (mirror is same projection; draw darker, offset 6px back), body, near legs
for d in g["frontLeg"] + g["backLeg"]:
    P(d, C["far"], 'transform="translate(10 -2)"')
P(g["frontHoof"], C["hoof"], 'transform="translate(10 -2)"'); P(g["backHoof"], C["hoof"], 'transform="translate(10 -2)"')
if stag:
    for seg in g["aSide"][0]:
        A(f'<line x1="{seg[0]}" y1="{seg[1]}" x2="{seg[2]}" y2="{seg[3]}" stroke="{C["line"]}" stroke-width="{seg[4] + 3}" stroke-linecap="round"/>')
    for seg in g["aSide"][0]:
        A(f'<line x1="{seg[0]}" y1="{seg[1]}" x2="{seg[2]}" y2="{seg[3]}" stroke="{C["antler"]}" stroke-width="{seg[4]}" stroke-linecap="round"/>')
P(g["tail"] + " L" + g["tail"].split("M")[1].split(" L")[0], C["coat"])
P(g["torso"], C["coat"])
A(f'<path d="{g["torsoRings"]}" fill="none" stroke="{C["line"]}" stroke-opacity=".3" stroke-width="1"/>')
P(g["neck"], C["mane"])
P(g["head"], C["face"])
P(g["muzzle"], C["white"]); P(g["noseTip"], C["dark"])
P(g["ear"], C["mane"])
for d in g["frontLeg"]:
    P(d, C["mane"] if d is g["frontLeg"][0] else (C["coat"] if d is g["frontLeg"][1] else C["shin"]))
for d in g["backLeg"]:
    P(d, C["coat"] if d in g["backLeg"][:2] else C["shin"])
P(g["frontHoof"], C["hoof"]); P(g["backHoof"], C["hoof"])
ex, ey = g["eye"]
A(f'<rect x="{ex-7}" y="{ey-7}" width="14" height="14" transform="rotate(45 {ex} {ey})" fill="#1A181C"/>')
if stag:
    for x, y in g["aSide"][1]:
        A(f'<rect x="{x-9}" y="{y-9}" width="18" height="18" transform="rotate(45 {x} {y})" fill="{C["glow"]}" stroke="{C["line"]}" stroke-width="1.2"/>')
# joints
for name, x, y in g["frontJoints"] + g["backJoints"]:
    A(f'<circle cx="{x}" cy="{y}" r="7" fill="#1F8A87" stroke="#fff" stroke-width="2"/>')
labs = {"shoulder": (-14, -10, "end"), "elbow": (-14, 4, "end"), "knee": (-14, 4, "end"), "fetlock": (-14, 4, "end"),
        "hip": (14, -10, "start"), "stifle": (-14, 4, "end"), "hock": (14, 4, "start")}
for name, x, y in g["frontJoints"]:
    dx, dy, an = labs[name]; label(x + dx, y + dy, name, 13, 600, "#1F5F5D", an)
for name, x, y in g["backJoints"]:
    if name == "fetlock": dx, dy, an = (14, 4, "start")
    else: dx, dy, an = labs[name]
    label(x + dx, y + dy, name, 13, 600, "#1F5F5D", an)
# H markers
wy = OY - 3.75 * S; by = OY - 2.05 * S
for y, t in ((wy, "withers  H = 3.75"), (by, "chest floor  2.05  (0.55 H)")):
    A(f'<line x1="40" y1="{y:.0f}" x2="760" y2="{y:.0f}" stroke="#C0563B" stroke-width="1.2" stroke-dasharray="6 5"/>')
    label(752, y - 6, t, 12, 600, "#A3452E", "end")
# FRONT VIEW: hind legs behind (darker), torso, front legs, neck, head, ears
for d in g["fBackLegs"]:
    P(d, C["far"])
for d in g["fFrontLegs"]:
    P(d, C["shin"])
P(g["fTorso"], C["coat"])
if stag:
    for side in g["aFront"]:
        for seg in side[0]:
            A(f'<line x1="{seg[0]}" y1="{seg[1]}" x2="{seg[2]}" y2="{seg[3]}" stroke="{C["line"]}" stroke-width="{seg[4] + 3}" stroke-linecap="round"/>')
        for seg in side[0]:
            A(f'<line x1="{seg[0]}" y1="{seg[1]}" x2="{seg[2]}" y2="{seg[3]}" stroke="{C["antler"]}" stroke-width="{seg[4]}" stroke-linecap="round"/>')
        for x, y in side[1]:
            A(f'<rect x="{x-9}" y="{y-9}" width="18" height="18" transform="rotate(45 {x} {y})" fill="{C["glow"]}" stroke="{C["line"]}" stroke-width="1.2"/>')
P(g["fNeck"], C["mane"])
for d in g["fEars"]:
    P(d, C["mane"])
P(g["fHead"], C["face"])
P(g["fMuzzle"], C["white"]); P(g["fNose"], C["dark"])
for x, y in g["fFrontEyes"]:
    A(f'<rect x="{x-6}" y="{y-6}" width="12" height="12" transform="rotate(45 {x} {y})" fill="#1A181C"/>')
# TOP VIEW
P(g["tNeck"], C["mane"]); P(g["tTorso"], C["coat"]); P(g["tHead"], C["face"])
# spec panel
x0 = 1220
label(x0, 96, "Moonhorn Stag" if stag else "Deer (doe)", 30, 700, "#2B2419")
label(x0, 124, "template · 1 grid square = 0.25 stud", 14, 500, "#7A6E58")
rows = [("Withers height H", "3.75"), ("Legs to chest floor", "2.05  (0.55 H)"), ("Body depth", "1.7  (0.45 H)"),
        ("Body length", "3.7  (1.0 H)"), ("Head length", "1.55  (0.42 body)"), ("Nose height", "4.2"),
        ("Ear length", "1.0"), ("Leg width (cannon)", "0.38 x 0.44")]
y = 170
for k, v in rows:
    label(x0, y, k, 15, 500, "#5A5040"); label(1560, y, v, 15, 700, "#2B2419", "end")
    A(f'<line x1="{x0}" y1="{y+10}" x2="1560" y2="{y+10}" stroke="#E2DACA"/>'); y += 36
y += 14
label(x0, y, "JOINTS (height, studs)", 13, 700, "#7A6E58"); y += 28
fj = spec["front"]["joints"]; bj = spec["back"]["joints"]
for (a, b) in (("shoulder", "hip"), ("elbow", "stifle"), ("knee", "hock"), ("fetlock", "fetlock")):
    label(x0, y, f"{a}  {fj[a][0]:.2f}", 15, 500, "#1F5F5D"); label(1400, y, f"{b}  {bj[b][0]:.2f}", 15, 500, "#1F5F5D"); y += 30
if stag:
    y += 14
    label(x0, y, "ANTLERS", 13, 700, "#7A6E58"); y += 28
    for t in ("Crescent beams, 4 tines each", "Glowing crystal tips (Neon)", "Top of antlers ~ 8.3 studs", "Silver coat, blue-grey mane"):
        label(x0, y, t, 15, 500, "#5A5040"); y += 28
A('</svg>')
print("\n".join(o))
