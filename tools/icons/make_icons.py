# Mystree UI icon set (framework from HussMadness / CreaturePens tools/icons, v2 glossy look):
# thick dark outline, saturated colours with a light-to-dark gradient per part, a darker bottom band,
# a glossy highlight up-left, a soft drop shadow, no studs. Mystree's palette: jade, gold, bronze,
# warm wood, cream and deep teal, for a crafted xianxia feel (carved jade, gold trim).
# Each icon is a list of parts drawn in order; every part gets its own outline.
# Output: out/<key>.png (512x512, transparent) and sheet.png (labelled preview + 48 px rows).
# Run: python3 make_icons.py [key ...]
import colorsys, math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

S = 2  # the 256-unit grid is drawn at 512 px
N = 256 * S
INK = (28, 30, 30, 255)
OUTLINE = 5  # MaxFilter passes (each grows ~3 px at 512)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
ROUND = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"


def u(v):
    return v * S


def lighter(c, k):
    return tuple(int(c[i] + (255 - c[i]) * k) for i in range(3)) + (255,)


def darker(c, k):
    return tuple(int(c[i] * (1 - k)) for i in range(3)) + (255,)


def pop(c):
    # every colour a bit more saturated and bright so the icons read at 40 px
    h, s_, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    if s_ > 0.08:
        s_ = min(1, s_ * 1.18 + 0.03)
    v = min(1, v * 1.04)
    r, g, b = colorsys.hsv_to_rgb(h, s_, v)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def vgrad(box, top, bottom):
    g = Image.new("RGBA", (N, N), bottom)
    y0, y1 = box[1], max(box[3], box[1] + 1)
    d = ImageDraw.Draw(g)
    for y in range(y0, y1):
        t = (y - y0) / (y1 - y0)
        d.line([(0, y), (N, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return g


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    def mask(self, fn):
        m = Image.new("L", (N, N), 0)
        fn(ImageDraw.Draw(m))
        return m

    def part(self, fn, color, shine=True, outline=True, glow=None):
        m = self.mask(fn)
        if glow:
            # a soft coloured halo behind the part (spirit things, gems)
            g = m.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(u(10)))
            halo = Image.new("RGBA", (N, N), tuple(glow)[:3] + (255,))
            halo.putalpha(g.point(lambda v: int(v * 0.7)))
            self.img.alpha_composite(halo)
        if outline:
            grown = m
            for _ in range(OUTLINE):
                grown = grown.filter(ImageFilter.MaxFilter(7))
            self.img.paste(Image.new("RGBA", (N, N), INK), (0, 0), grown)
        color = pop(tuple(color)[:3])
        box = m.getbbox()
        if not box:
            return
        self.img.paste(vgrad(box, lighter(color, 0.24), darker(color, 0.18)), (0, 0), m)
        if shine:
            inner = m.filter(ImageFilter.MinFilter(9))
            w, h = box[2] - box[0], box[3] - box[1]
            bt = Image.new("L", (N, N), 0)
            ImageDraw.Draw(bt).rectangle([box[0], box[3] - h * 0.22, box[2], box[3]], fill=70)
            bt = ImageChops.multiply(bt.filter(ImageFilter.GaussianBlur(u(3))), inner)
            self.img.paste(Image.new("RGBA", (N, N), darker(color, 0.45)), (0, 0), bt)
            sh = Image.new("L", (N, N), 0)
            d = ImageDraw.Draw(sh)
            d.rectangle([box[0], box[1], box[2], box[1] + h * 0.3], fill=70)
            d.ellipse([box[0] + w * 0.1, box[1] + h * 0.06, box[0] + w * 0.48, box[1] + h * 0.3], fill=170)
            sh = ImageChops.multiply(sh.filter(ImageFilter.GaussianBlur(u(2))), inner)
            self.img.paste(Image.new("RGBA", (N, N), (255, 255, 255, 255)), (0, 0), sh)

    def flat(self, fn, color, alpha=255):
        # a flat detail (facet, vein, line) with no outline or shine
        m = self.mask(fn)
        if alpha < 255:
            m = m.point(lambda v: int(v * alpha / 255))
        self.img.paste(Image.new("RGBA", (N, N), tuple(color)[:3] + (255,)), (0, 0), m)

    def save(self, key):
        a = self.img.getchannel("A")
        sh = Image.new("RGBA", (N, N), (10, 20, 20, 0))
        sh.putalpha(a.point(lambda v: int(v * 0.42)).filter(ImageFilter.GaussianBlur(u(5))))
        out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        out.alpha_composite(sh, (0, u(6)))
        out.alpha_composite(self.img)
        out.save(os.path.join(OUT, key + ".png"))


# shape helpers (units on a 256 grid) ---------------------------------------------------------------
def rr(x0, y0, x1, y1, r=10):
    return lambda d: d.rounded_rectangle([u(x0), u(y0), u(x1), u(y1)], radius=u(r), fill=255)


def ell(x0, y0, x1, y1):
    return lambda d: d.ellipse([u(x0), u(y0), u(x1), u(y1)], fill=255)


def poly(pts):
    return lambda d: d.polygon([(u(x), u(y)) for x, y in pts], fill=255)


def thick(pts, w):
    return lambda d: d.line([(u(x), u(y)) for x, y in pts], fill=255, width=u(w), joint="curve")


def arc(cx, cy, r, a0, a1, w):
    return lambda d: d.arc([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], a0, a1, fill=255, width=u(w))


def multi(*fns):
    def f(d):
        for g in fns:
            g(d)
    return f


def heart_pts(cx, cy, s):
    pts = []
    for i in range(80):
        t = i / 80 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s, cy - y * s))
    return pts


def star_pts(cx, cy, r0, r1, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = r0 if i % 2 == 0 else r1
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def rot(pts, cx, cy, deg):
    a = math.radians(deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)) for x, y in pts]


def rbox(cx, cy, w, h, deg):
    return rot([(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)], cx, cy, deg)


def gear_pts(cx, cy, r0, r1, teeth):
    pts = []
    for i in range(teeth * 4):
        a = math.radians(i * 360 / (teeth * 4))
        r = r0 if (i % 4) in (0, 1) else r1
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


# palette (Mystree: jade, gold, bronze, wood, cream, teal) -------------------------------------------
JADE = (70, 185, 140)
JADE_D = (35, 120, 98)
TEAL = (45, 130, 140)
GOLD = (245, 190, 55)
BRONZE = (196, 128, 58)
WOOD = (150, 96, 56)
WOOD_D = (110, 66, 38)
CREAM = (246, 232, 200)
RED = (215, 55, 50)
CYAN = (80, 215, 240)
PURPLE = (150, 90, 225)
PEACH = (255, 160, 140)
LEAF = (80, 175, 80)
STEEL = (190, 200, 210)
STEEL_D = (110, 120, 135)
BONE = (236, 228, 205)
ORANGE = (250, 140, 40)
GREY = (150, 150, 160)
WHITE = (255, 255, 255)

ICONS = {}


def icon(key):
    def wrap(fn):
        ICONS[key] = fn
        return fn
    return wrap


# ===================================================================== currencies and materials
@icon("spirit_stone")
def _(i):
    outer = [(128, 14), (200, 78), (180, 214), (128, 244), (76, 214), (56, 78)]
    i.part(poly(outer), CYAN, glow=(120, 230, 255))
    i.flat(poly([(128, 30), (166, 86), (128, 210), (90, 86)]), lighter(CYAN, 0.55), 200)
    i.flat(poly([(128, 30), (90, 86), (68, 84)]), lighter(CYAN, 0.35), 160)
    i.flat(poly([(166, 86), (186, 86), (170, 200), (128, 210)]), darker(CYAN, 0.25), 150)
    i.part(poly(star_pts(186, 42, 22, 6, 4, 0)), WHITE, shine=False, outline=False)


@icon("scraps")
def _(i):
    # bronze coins with square holes (old cultivation coins) and a bent metal scrap
    i.part(poly(rbox(168, 86, 96, 46, -24)), STEEL_D)
    i.flat(thick([(132, 92), (202, 62)], 4), lighter(STEEL_D, 0.4), 160)
    for cx, cy in ((84, 186), (150, 196), (116, 146)):
        i.part(ell(cx - 50, cy - 40, cx + 50, cy + 40), BRONZE)
        i.flat(rr(cx - 12, cy - 12, cx + 12, cy + 12, 2), darker(BRONZE, 0.55))
        i.flat(arc(cx, cy, 34, 200, 340, 4), lighter(BRONZE, 0.5), 170)


@icon("peach")
def _(i):
    i.part(thick([(128, 64), (138, 22)], 10), WOOD)
    i.part(poly([(138, 40), (196, 14), (226, 40), (180, 66)]), LEAF)
    i.flat(thick([(146, 40), (210, 34)], 4), darker(LEAF, 0.35))
    i.part(multi(ell(30, 66, 226, 244), poly([(70, 120), (128, 46), (186, 120)])), PEACH)
    i.flat(ell(130, 120, 214, 220), (255, 110, 120), 140)
    i.flat(arc(128, 150, 66, 250, 290, 6), darker(PEACH, 0.35), 200)
    i.flat(thick([(128, 70), (120, 150), (124, 228)], 5), darker(PEACH, 0.3), 170)


@icon("sap")
def _(i):
    i.part(multi(ell(58, 104, 198, 244), poly([(128, 14), (66, 150), (190, 150)])), (100, 210, 90), glow=(150, 255, 140))
    i.flat(ell(96, 150, 140, 196), lighter((100, 210, 90), 0.6), 200)


@icon("heartwood")
def _(i):
    i.part(poly(heart_pts(128, 132, 7.2)), WOOD)
    i.flat(poly(heart_pts(128, 132, 5.4)), lighter(WOOD, 0.3))
    i.flat(poly(heart_pts(128, 132, 3.7)), WOOD)
    i.flat(poly(heart_pts(128, 132, 2.1)), (220, 90, 60))
    i.flat(thick([(70, 90), (100, 150)], 3), darker(WOOD, 0.3), 160)


@icon("blood_amber")
def _(i):
    pts = [(96, 24), (160, 24), (220, 84), (220, 160), (160, 232), (96, 232), (36, 160), (36, 84)]
    i.part(poly(pts), RED, glow=(255, 90, 80))
    i.flat(poly([(96, 44), (160, 44), (196, 84), (60, 84)]), lighter(RED, 0.45), 190)
    i.flat(poly([(60, 84), (196, 84), (160, 204), (96, 204)]), darker(RED, 0.15), 120)
    i.flat(ell(78, 108, 108, 138), (255, 220, 160), 160)


@icon("sunstone")
def _(i):
    i.part(poly(star_pts(128, 128, 120, 86, 12, -90)), GOLD)
    i.part(ell(56, 56, 200, 200), ORANGE, glow=(255, 210, 90))
    i.flat(poly(star_pts(128, 128, 56, 30, 6, -90)), lighter(GOLD, 0.5), 200)


@icon("mount_shard")
def _(i):
    i.part(poly([(150, 12), (204, 120), (160, 244), (96, 184), (110, 70)]), PURPLE, glow=(190, 140, 255))
    i.flat(poly([(150, 30), (178, 120), (150, 200), (124, 120)]), lighter(PURPLE, 0.45), 190)
    i.part(poly([(58, 120), (90, 150), (74, 220), (40, 186)]), lighter(PURPLE, 0.15))


@icon("cp")
def _(i):
    for deg, x in ((40, 1), (-40, -1)):
        i.part(poly(rbox(128, 118, 22, 200, deg)), STEEL)
        i.part(poly(rbox(128 - x * 62, 186, 22, 54, deg)), WOOD_D)
    i.part(poly(rbox(84, 162, 64, 16, -50)), GOLD)
    i.part(poly(rbox(172, 162, 64, 16, 50)), GOLD)
    i.part(ell(98, 96, 158, 156), RED)
    i.part(poly(star_pts(128, 126, 22, 9)), GOLD, shine=False, outline=False)


@icon("exp")
def _(i):
    i.part(rr(34, 60, 222, 200, 18), CREAM)
    i.part(rr(22, 50, 52, 210, 12), WOOD)
    i.part(rr(204, 50, 234, 210, 12), WOOD)
    i.part(poly(star_pts(128, 130, 62, 26)), GOLD)


# ===================================================================== menu and HUD
@icon("quests")
def _(i):
    i.part(rr(40, 46, 216, 206, 12), CREAM)
    i.flat(thick([(70, 90), (186, 90)], 6), darker(CREAM, 0.4), 200)
    i.flat(thick([(70, 120), (186, 120)], 6), darker(CREAM, 0.4), 200)
    i.flat(thick([(70, 150), (150, 150)], 6), darker(CREAM, 0.4), 200)
    i.part(rr(28, 30, 60, 222, 14), WOOD)
    i.part(rr(196, 30, 228, 222, 14), WOOD)
    i.part(ell(150, 150, 214, 214), RED)
    i.flat(poly(star_pts(182, 182, 16, 7)), lighter(RED, 0.5), 220)


@icon("bag")
def _(i):
    i.part(poly([(70, 60), (186, 60), (156, 92), (100, 92)]), (205, 170, 115))
    i.part(multi(ell(36, 90, 220, 244), poly([(90, 100), (166, 100), (200, 150), (56, 150)])), (190, 150, 95))
    i.part(rr(84, 82, 172, 104, 10), GOLD)
    i.part(ell(116, 76, 140, 110), GOLD)
    i.flat(poly(star_pts(128, 172, 28, 12, 4, 0)), JADE, 220)


@icon("decor")
def _(i):
    i.part(thick([(128, 8), (128, 40)], 6), WOOD_D)
    i.part(rr(92, 30, 164, 52, 8), GOLD)
    i.part(ell(48, 44, 208, 212), RED, glow=(255, 170, 90))
    for x in (88, 128, 168):
        i.flat(thick([(x, 52), (x + (x - 128) * 0.25, 128), (x, 204)], 4), darker(RED, 0.35), 200)
    i.flat(ell(84, 84, 172, 172), (255, 200, 120), 120)
    i.part(rr(92, 204, 164, 226, 8), GOLD)
    i.part(poly([(116, 226), (140, 226), (148, 252), (108, 252)]), RED)


@icon("spirits")
def _(i):
    flame = [(128, 244), (60, 190), (52, 120), (84, 64), (96, 112), (118, 30), (144, 90), (170, 50), (200, 122), (196, 190)]
    i.part(poly(flame), (90, 210, 230), glow=(140, 240, 255))
    i.flat(poly([(128, 228), (88, 186), (90, 140), (112, 160), (128, 110), (146, 156), (168, 138), (170, 190)]), (210, 250, 255), 230)
    i.part(poly([(86, 120), (100, 82), (114, 124)]), (90, 210, 230), shine=False)
    i.part(poly([(142, 124), (156, 82), (170, 120)]), (90, 210, 230), shine=False)
    i.flat(ell(102, 162, 116, 176), TEAL)
    i.flat(ell(140, 162, 154, 176), TEAL)


@icon("mounts")
def _(i):
    head = [(150, 14), (176, 48), (204, 76), (232, 238), (118, 238), (128, 180), (96, 170), (46, 172), (26, 146), (38, 116), (106, 50), (128, 38)]
    i.part(poly(head), (175, 115, 70))
    i.part(poly([(150, 24), (176, 46), (212, 84), (242, 238), (214, 238), (188, 96), (158, 62)]), (80, 50, 32), shine=False)
    i.flat(poly([(46, 150), (96, 158), (92, 172), (46, 172), (30, 150)]), (130, 80, 50), 200)
    i.flat(ell(108, 82, 132, 106), (30, 20, 15))
    i.flat(ell(114, 86, 122, 94), WHITE)
    i.flat(ell(40, 132, 54, 146), (40, 25, 15))
    i.part(thick([(36, 124), (110, 140), (150, 110)], 9), GOLD, shine=False)
    i.part(ell(100, 128, 124, 152), GOLD, shine=False)


@icon("shop")
def _(i):
    i.part(multi(ell(40, 84, 216, 240), rr(70, 76, 186, 120, 20)), JADE)
    i.part(rr(76, 62, 180, 90, 12), GOLD)
    i.part(ell(100, 140, 156, 196), GOLD)
    i.flat(rr(118, 158, 138, 178, 3), darker(GOLD, 0.5))
    i.part(thick([(178, 70), (206, 36)], 4), CREAM, shine=False)
    i.part(poly(rbox(214, 40, 44, 30, 30)), CREAM)
    i.flat(ell(206, 32, 214, 40), darker(CREAM, 0.6))


@icon("settings")
def _(i):
    i.part(poly(gear_pts(128, 128, 112, 84, 8)), BRONZE)
    i.part(ell(88, 88, 168, 168), lighter(BRONZE, 0.2))
    i.flat(ell(108, 108, 148, 148), (40, 40, 40))


@icon("leaderboard")
def _(i):
    i.part(arc(56, 96, 34, 90, 270, 14), GOLD, shine=False)
    i.part(arc(200, 96, 34, 270, 90, 14), GOLD, shine=False)
    i.part(poly([(56, 40), (200, 40), (186, 120), (150, 154), (106, 154), (70, 120)]), JADE)
    i.flat(poly([(70, 52), (186, 52), (180, 80), (76, 80)]), lighter(JADE, 0.5), 160)
    i.part(rr(112, 150, 144, 196, 6), GOLD)
    i.part(rr(70, 194, 186, 230, 10), GOLD)
    i.part(poly(star_pts(128, 96, 26, 11)), GOLD, shine=False)


@icon("island")
def _(i):
    i.part(poly([(30, 120), (226, 120), (180, 170), (150, 236), (118, 200), (88, 222), (66, 164)]), (125, 110, 100))
    i.flat(poly([(70, 150), (180, 150), (150, 190), (100, 186)]), (100, 88, 80), 160)
    i.part(ell(24, 92, 232, 144), (100, 195, 95))
    i.part(rr(120, 54, 136, 116, 6), WOOD)
    i.part(ell(84, 18, 172, 84), JADE)


@icon("village")
def _(i):
    i.part(rr(64, 150, 192, 236, 6), CREAM)
    i.part(rr(70, 150, 88, 236, 4), RED)
    i.part(rr(168, 150, 186, 236, 4), RED)
    i.part(rr(112, 178, 144, 236, 6), WOOD_D)
    i.part(poly([(12, 150), (40, 120), (128, 70), (216, 120), (244, 150), (200, 140), (128, 104), (56, 140)]), TEAL)
    i.part(poly([(44, 82), (68, 62), (128, 22), (188, 62), (212, 82), (176, 78), (128, 52), (80, 78)]), TEAL)
    i.part(rr(122, 4, 134, 30, 4), GOLD)


@icon("hunt")
def _(i):
    i.part(arc(60, 196, 136, 270, 360, 16), WOOD)
    i.part(thick([(60, 60), (196, 196)], 4), CREAM, shine=False)
    i.part(thick([(50, 206), (200, 56)], 10), WOOD_D, shine=False)
    i.part(poly([(234, 22), (180, 46), (210, 76)]), STEEL)
    i.part(poly([(50, 206), (30, 200), (20, 232), (56, 226)]), RED, shine=False)
    i.part(poly([(66, 190), (52, 168), (30, 200), (50, 206)]), RED, shine=False)


@icon("tree")
def _(i):
    i.part(poly([(104, 236), (112, 140), (100, 110), (128, 120), (156, 110), (144, 140), (152, 236)]), WOOD)
    i.part(poly([(84, 240), (104, 220), (152, 220), (172, 240)]), WOOD_D)
    i.part(multi(ell(30, 40, 130, 130), ell(110, 20, 220, 120), ell(70, 70, 190, 160)), JADE)
    i.flat(thick([(124, 214), (130, 170), (122, 140)], 5), (110, 210, 255), 230)


@icon("auto")
def _(i):
    i.part(arc(128, 128, 88, 200, 340, 28), JADE)
    i.part(poly([(190, 38), (238, 82), (172, 98)]), JADE)
    i.part(arc(128, 128, 88, 20, 160, 28), JADE)
    i.part(poly([(66, 218), (18, 174), (84, 158)]), JADE)


@icon("chop")
def _(i):
    i.part(poly(rbox(124, 138, 22, 210, -38)), WOOD)
    i.part(poly([(120, 40), (186, 20), (226, 84), (196, 128), (150, 86)]), STEEL)
    i.flat(thick([(190, 26), (224, 82)], 6), WHITE, 200)
    i.part(poly(rbox(66, 214, 34, 30, -38)), WOOD_D)


@icon("daily")
def _(i):
    i.part(rr(40, 110, 216, 238, 8), RED)
    i.part(rr(28, 78, 228, 122, 8), lighter(RED, 0.1))
    i.part(rr(114, 78, 142, 238, 2), GOLD)
    i.part(ell(70, 34, 128, 84), GOLD)
    i.part(ell(128, 34, 186, 84), GOLD)
    i.part(ell(112, 60, 144, 92), GOLD)


@icon("close")
def _(i):
    i.part(multi(thick([(58, 58), (198, 198)], 46), thick([(198, 58), (58, 198)], 46), ell(35, 35, 81, 81), ell(175, 35, 221, 81), ell(35, 175, 81, 221), ell(175, 175, 221, 221)), RED)


@icon("lock")
def _(i):
    i.part(arc(128, 100, 56, 180, 360, 26), STEEL)
    i.part(rr(122 - 72, 96, 134 + 72, 98, 2), STEEL)
    i.part(rr(46, 104, 210, 236, 22), GOLD)
    i.flat(ell(114, 140, 142, 168), (40, 30, 20))
    i.flat(rr(122, 160, 134, 200, 3), (40, 30, 20))


@icon("star")
def _(i):
    i.part(poly(star_pts(128, 134, 118, 52)), GOLD)


@icon("heart")
def _(i):
    i.part(poly(heart_pts(128, 132, 7.4)), (235, 70, 90))


@icon("tutorial")
def _(i):
    for k, x in enumerate(range(44, 212, 34)):
        i.part(rr(x, 40, x + 30, 220, 8), (150, 200, 110) if k % 2 else (130, 185, 95))
        i.flat(thick([(x + 4, 100), (x + 26, 100)], 3), darker((130, 185, 95), 0.35), 200)
    i.part(thick([(32, 70), (224, 70)], 8), RED, shine=False)
    i.part(thick([(32, 190), (224, 190)], 8), RED, shine=False)


@icon("starter")
def _(i):
    i.part(rr(32, 112, 224, 232, 10), WOOD)
    i.part(multi(rr(32, 80, 224, 128, 6), ell(32, 40, 224, 120)), lighter(WOOD, 0.08))
    i.part(rr(32, 112, 224, 130, 2), GOLD)
    i.part(rr(112, 96, 144, 150, 6), GOLD)
    i.part(poly(star_pts(196, 46, 34, 13)), (200, 140, 255), glow=(220, 180, 255))


@icon("revive")
def _(i):
    feather = [(206, 20), (230, 60), (196, 140), (130, 210), (60, 240), (46, 220), (90, 150), (150, 70)]
    i.part(poly(feather), ORANGE, glow=(255, 160, 60))
    i.flat(poly([(206, 30), (214, 70), (170, 130), (120, 180), (140, 110)]), (255, 220, 90), 220)
    i.flat(poly([(120, 120), (90, 150), (140, 140)]), RED, 170)
    i.part(thick([(214, 34), (52, 232)], 6), CREAM, shine=False)


@icon("incense")
def _(i):
    for x, top in ((104, 30), (128, 18), (152, 34)):
        i.part(thick([(x, top), (x, 140)], 7), (180, 70, 50), shine=False)
        i.flat(ell(x - 7, top - 7, x + 7, top + 7), (255, 160, 60))
    i.flat(thick([(128, 14), (116, -2), (132, -10)], 4), GREY, 160)
    i.part(multi(ell(44, 120, 212, 220), rr(44, 120, 212, 170, 8)), BRONZE)
    i.part(rr(36, 116, 220, 140, 8), lighter(BRONZE, 0.15))
    for x in (70, 128, 186):
        i.part(poly([(x - 10, 210), (x + 10, 210), (x + 6, 246), (x - 6, 246)]), darker(BRONZE, 0.1))


@icon("summon")
def _(i):
    i.part(arc(128, 128, 104, 0, 360, 18), JADE, glow=(120, 240, 200))
    i.part(arc(128, 128, 72, 0, 360, 8), (110, 225, 205), shine=False)
    tri1 = [(128, 58), (189, 163), (67, 163)]
    tri2 = [(128, 198), (67, 93), (189, 93)]
    i.part(thick(tri1 + [tri1[0]], 8), (200, 255, 240), shine=False, outline=False)
    i.part(thick(tri2 + [tri2[0]], 8), (200, 255, 240), shine=False, outline=False)
    i.part(ell(110, 110, 146, 146), (210, 255, 250), glow=(160, 255, 230))


def skull(i, y=0):
    i.part(multi(ell(54, 70 + y, 202, 210 + y), rr(84, 170 + y, 172, 236 + y, 18)), BONE)
    i.flat(ell(80, 126 + y, 120, 166 + y), (40, 30, 30))
    i.flat(ell(136, 126 + y, 176, 166 + y), (40, 30, 30))
    i.flat(poly([(128, 172 + y), (118, 192 + y), (138, 192 + y)]), (40, 30, 30))
    for x in (104, 128, 152):
        i.flat(rr(x - 3, 206 + y, x + 3, 232 + y, 2), darker(BONE, 0.35))


@icon("boss")
def _(i):
    skull(i, 8)
    i.part(poly([(56, 86), (60, 26), (92, 56), (128, 14), (164, 56), (196, 26), (200, 86)]), GOLD)
    i.part(ell(116, 46, 140, 70), RED, shine=False)


@icon("elite")
def _(i):
    i.part(poly([(70, 110), (24, 64), (30, 14), (52, 60), (96, 92)]), (90, 80, 70))
    i.part(poly([(186, 110), (232, 64), (226, 14), (204, 60), (160, 92)]), (90, 80, 70))
    skull(i, 4)
    i.flat(ell(88, 136, 112, 160), (255, 80, 60))
    i.flat(ell(144, 136, 168, 160), (255, 80, 60))


@icon("admin")
def _(i):
    i.part(poly(rbox(118, 150, 26, 180, 40)), WOOD)
    i.part(poly(rbox(166, 84, 140, 60, 40)), STEEL_D)
    i.flat(poly(rbox(166, 70, 124, 14, 40)), lighter(STEEL_D, 0.5), 170)
    i.part(poly(rbox(62, 216, 34, 30, 40)), WOOD_D)


# ===================================================================== forging (materials, relics, markers)
def ingot(i, cx, cy, w, color, glow=None, h=34):
    # a trapezoid bar seen from the front-top: top face lighter, front face full colour
    top = [(cx - w * 0.36, cy - h), (cx + w * 0.36, cy - h), (cx + w * 0.5, cy), (cx - w * 0.5, cy)]
    front = [(cx - w * 0.5, cy), (cx + w * 0.5, cy), (cx + w * 0.5, cy + h * 1.3), (cx - w * 0.5, cy + h * 1.3)]
    i.part(multi(poly(top), poly(front)), color, glow=glow)
    i.flat(poly(top), lighter(color, 0.4), 210)
    i.flat(thick([(cx - w * 0.5 + 6, cy + 2), (cx + w * 0.5 - 6, cy + 2)], 3), darker(color, 0.35), 200)


@icon("iron_shard")
def _(i):
    ingot(i, 128, 168, 176, STEEL)
    # two jagged shards resting on the bar
    i.part(poly([(70, 120), (96, 44), (122, 116), (104, 132)]), STEEL_D)
    i.flat(poly([(96, 58), (112, 112), (100, 120)]), lighter(STEEL_D, 0.45), 190)
    i.part(poly([(136, 126), (178, 58), (196, 70), (176, 128)]), lighter(STEEL_D, 0.12))
    i.flat(poly([(178, 72), (188, 76), (172, 122)]), lighter(STEEL_D, 0.5), 190)


@icon("spirit_steel")
def _(i):
    c = (60, 200, 190)
    ingot(i, 124, 140, 196, c, glow=(110, 255, 230), h=52)
    # glowing rune line across the front face and a spark
    i.flat(thick([(52, 172), (92, 172), (112, 156), (136, 190), (156, 172), (196, 172)], 7), (220, 255, 250), 235)
    i.part(poly(star_pts(196, 66, 30, 9, 4, 0)), (210, 255, 250), shine=False, glow=(140, 255, 235))


@icon("star_shard")
def _(i):
    i.part(poly(star_pts(128, 132, 116, 46, 4, -90)), PURPLE, glow=(200, 150, 255))
    i.flat(poly([(128, 22), (150, 110), (128, 132), (106, 110)]), lighter(PURPLE, 0.55), 210)
    i.flat(poly([(128, 132), (238, 132), (150, 154)]), darker(PURPLE, 0.25), 150)
    i.part(poly(star_pts(196, 48, 24, 7, 4, 0)), WHITE, shine=False, outline=False)


@icon("qilin_horn")
def _(i):
    # a smooth curved horn: broad base lower-left, sharp tip upper-right, ringed with gold bands
    centre, left, right = [], [], []
    for k in range(25):
        t = k / 24
        x = 62 + t * 150 - math.sin(t * math.pi) * 30
        y = 226 - t * 206 - math.sin(t * math.pi) * 10
        centre.append((x, y))
    for k, (x, y) in enumerate(centre):
        t = k / 24
        x2, y2 = centre[min(k + 1, 24)] if k < 24 else centre[23]
        dx, dy = (x2 - x, y2 - y) if k < 24 else (x - x2, y - y2)
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        w = 34 * (1 - t) ** 0.9 + 1
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    outline = left + right[::-1]
    i.part(poly(outline), JADE, glow=(140, 255, 200))
    for k in (3, 7, 11, 15, 19):
        i.flat(thick([left[k], right[k + 1]], max(4, 11 - k // 3)), GOLD, 245)
    i.flat(thick([((l[0] + c[0]) / 2, (l[1] + c[1]) / 2) for l, c in zip(left[2:22], centre[2:22])], 4), lighter(JADE, 0.6), 160)


@icon("fox_tail")
def _(i):
    # a big fluffy curled tail (overlapping puffs) ending in a pink foxfire tip
    tail = [(56, 214), (78, 166), (112, 134), (152, 114), (184, 86), (200, 52)]
    fur = (255, 226, 206)
    i.part(multi(*[ell(x - 44 + k * 3, y - 40 + k * 2, x + 44 - k * 3, y + 40 - k * 2) for k, (x, y) in enumerate(tail)]), fur)
    for x, y in tail[:4]:
        i.flat(arc(x, y, 30, 30, 120, 5), (235, 170, 160), 190)
    i.part(poly([(170, 54), (190, 0), (204, 26), (228, 6), (232, 50), (210, 78)]), (255, 110, 170), glow=(255, 140, 200))
    i.flat(poly([(192, 20), (202, 42), (216, 30), (218, 56), (204, 66)]), (255, 236, 140), 230)


@icon("roc_feather")
def _(i):
    c = (80, 130, 235)
    vane = [(210, 18), (232, 56), (204, 132), (146, 196), (78, 232), (62, 214), (100, 150), (150, 72)]
    i.part(poly(vane), c, glow=(140, 190, 255))
    i.flat(poly([(210, 28), (218, 62), (180, 124), (130, 176), (150, 108)]), lighter(c, 0.45), 200)
    for k in range(4):
        y = 70 + k * 34
        i.flat(thick([(196 - k * 30, y), (226 - k * 30, y + 20)], 3), darker(c, 0.35), 200)
    i.part(thick([(220, 32), (54, 238)], 6), CREAM, shine=False)
    # a lightning glint
    i.part(poly([(70, 40), (104, 40), (88, 74), (112, 74), (66, 132), (78, 88), (56, 88)]), (255, 230, 90), shine=False, glow=(255, 240, 140))


@icon("forge")
def _(i):
    # orange forge glow behind an anvil, a hammer on top
    i.part(ell(36, 120, 220, 240), (255, 140, 40), shine=False, outline=False, glow=(255, 150, 50))
    i.part(multi(poly([(30, 96), (226, 96), (196, 136), (60, 136)]), poly([(14, 96), (40, 96), (60, 120), (30, 112)])), STEEL_D)
    i.part(rr(96, 134, 160, 184, 4), darker(STEEL_D, 0.1))
    i.part(rr(64, 182, 192, 222, 8), darker(STEEL_D, 0.2))
    i.flat(thick([(44, 102), (214, 102)], 5), lighter(STEEL_D, 0.5), 200)
    i.part(poly(rbox(150, 54, 16, 108, -50)), WOOD)
    i.part(poly(rbox(108, 40, 74, 34, -50)), STEEL)
    i.part(poly(star_pts(196, 118, 22, 7, 4, 0)), (255, 220, 120), shine=False, outline=False)


@icon("mythic")
def _(i):
    # a gold sun emblem with flame rays around a red-gold core (Mythic beast marker)
    i.part(poly(star_pts(128, 128, 122, 70, 8, -90)), ORANGE, glow=(255, 190, 80))
    i.part(poly(star_pts(128, 128, 96, 62, 8, -67.5)), GOLD)
    i.part(ell(70, 70, 186, 186), RED)
    i.part(poly(star_pts(128, 128, 44, 18, 4, -90)), (255, 236, 160), shine=False)


@icon("set")
def _(i):
    shield = [(128, 18), (220, 50), (210, 140), (128, 240), (46, 140), (36, 50)]
    i.part(poly(shield), STEEL_D)
    inner = [(128, 40), (198, 64), (190, 136), (128, 214), (66, 136), (58, 64)]
    i.part(poly(inner), JADE, shine=True, outline=False)
    i.part(arc(128, 116, 44, 0, 360, 12), GOLD, shine=False)
    i.part(poly([(128, 84), (152, 116), (128, 148), (104, 116)]), GOLD, shine=False)


# ===================================================================== build + sheet
def build(keys=None):
    os.makedirs(OUT, exist_ok=True)
    for key, fn in ICONS.items():
        if keys and key not in keys:
            continue
        ic = Icon()
        fn(ic)
        ic.save(key)
    keys = list(ICONS)
    cols = 10
    rows = math.ceil(len(keys) / cols)
    cell = 140
    small = 48
    srow = small + 16
    # big labelled grid (parchment / deep teal rows), then 48 px preview rows on both backgrounds
    per = (cols * cell) // (small + 8)
    srows = math.ceil(len(keys) / per)
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 24) + 2 * srow * srows), (246, 236, 214, 255))
    d = ImageDraw.Draw(sheet)
    lab = ImageFont.truetype(ROUND, 15)
    for n, key in enumerate(keys):
        x, y = (n % cols) * cell, (n // cols) * (cell + 24)
        if (n // cols) % 2:
            d.rectangle([x, y, x + cell, y + cell + 24], fill=(35, 58, 59, 255))
        im = Image.open(os.path.join(OUT, key + ".png")).resize((112, 112), Image.LANCZOS)
        sheet.alpha_composite(im, (x + 14, y + 6))
        d.text((x + cell / 2, y + cell + 8), key, font=lab, fill=(40, 25, 12) if (n // cols) % 2 == 0 else (230, 230, 220), anchor="mm")
    y0 = rows * (cell + 24)
    for bg_i, bg in enumerate(((35, 58, 59, 255), (246, 236, 214, 255))):
        d.rectangle([0, y0 + bg_i * srow * srows, cols * cell, y0 + (bg_i + 1) * srow * srows], fill=bg)
        for n, key in enumerate(keys):
            x = 8 + (n % per) * (small + 8)
            y = y0 + bg_i * srow * srows + 8 + (n // per) * srow
            im = Image.open(os.path.join(OUT, key + ".png")).resize((small, small), Image.LANCZOS)
            sheet.alpha_composite(im, (x, y))
    sheet.save(os.path.join(HERE, "sheet.png"))
    print(len(ICONS), "icons")


if __name__ == "__main__":
    build(sys.argv[1:] or None)
