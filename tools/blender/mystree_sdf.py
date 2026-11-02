# Signed-distance sculpting for Mystree creatures (numpy, runs inside Blender's Python).
# Why: the Skin-modifier skeleton gave boxy rings (rump like a crate, tube legs). A creature here is
# a list of soft primitives (ellipsoids, tapered capsules) blended with smooth-min, with carved
# sockets (eyes, ear cups, nostrils) subtracted. The field is meshed with surface nets, then
# mystree_kit.bake() decimates it to an even, faceted papercraft look.
#
# Usage:
#   S = Sculpt()
#   S.add(ellipsoid((0, 1, 3), (0.8, 1.2, 0.9)), k=0.3)
#   S.add(cone((0, 1.7, 3.9), 0.5, (0, 2.6, 5.3), 0.3), k=0.3)
#   S.sub(ellipsoid(eye_pos, (0.12, 0.12, 0.12)), k=0.03)
#   ob = S.mesh("Body", step=0.04)
import math
import numpy as np
import bpy
import bmesh


def _rot(euler_deg):
    """Rotation matrix from XYZ Euler degrees (applied X, then Y, then Z)."""
    if not euler_deg:
        return None
    rx, ry, rz = (math.radians(a) for a in euler_deg)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    X = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Y = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Z = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Z @ Y @ X


class Prim:
    def __init__(self, fn, lo, hi):
        self.fn, self.lo, self.hi = fn, np.array(lo, float), np.array(hi, float)


def ellipsoid(c, r, rot=None):
    """Ellipsoid at c with radii r, optionally rotated (Euler degrees). iq's bound approximation."""
    c, r = np.array(c, float), np.array(r, float)
    R = _rot(rot)

    def fn(P):
        q = P - c
        if R is not None:
            q = q @ R  # world -> local (R orthonormal: q @ R == R.T @ q)
        k0 = np.linalg.norm(q / r, axis=1)
        k1 = np.linalg.norm(q / (r * r), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    m = r.max()
    return Prim(fn, c - m, c + m)


def cone(a, ra, b, rb, squash=None):
    """Tapered capsule (round cone) from a (radius ra) to b (radius rb). squash=(sx,sy,sz) scales
    the shape about a (e.g. (0.7,1,1) for a leg that is narrower side to side)."""
    a, b = np.array(a, float), np.array(b, float)
    sq = np.array(squash, float) if squash else None
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2

    def fn(P):
        pa = P - a
        if sq is not None:
            pa = pa / sq
        y = pa @ ba
        z = y - l2
        w = pa * l2 - np.outer(y, ba)
        x2 = np.einsum("ij,ij->i", w, w)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1, rr) * rr * rr * x2
        d = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - ra
        d = np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - ra, d)
        d = np.where(np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - rb, d)
        if sq is not None:
            d = d * sq.min()
        return d
    m = max(ra, rb) * (sq.max() if sq is not None else 1)
    return Prim(fn, np.minimum(a, b) - m, np.maximum(a, b) + m)


def chain(points, radii, squash=None):
    """A polyline of round cones (list of Prims), e.g. a leg or an antler beam."""
    return [cone(points[i], radii[i], points[i + 1], radii[i + 1], squash) for i in range(len(points) - 1)]


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


class Sculpt:
    def __init__(self):
        self.ops = []  # (kind, prim, k)

    def add(self, prims, k=0.2):
        for p in (prims if isinstance(prims, list) else [prims]):
            self.ops.append(("add", p, k))
        return self

    def sub(self, prims, k=0.03):
        for p in (prims if isinstance(prims, list) else [prims]):
            self.ops.append(("sub", p, k))
        return self

    def field(self, P):
        d = None
        for kind, p, k in self.ops:
            v = p.fn(P)
            if kind == "add":
                d = v if d is None else smin(d, v, k)
            else:
                d = smax(d, -v, k)
        return d

    def mesh(self, name, step=0.04):
        adds = [p for kind, p, _ in self.ops if kind == "add"]
        lo = np.min([p.lo for p in adds], axis=0) - 3 * step - 0.15
        hi = np.max([p.hi for p in adds], axis=0) + 3 * step + 0.15
        n = np.ceil((hi - lo) / step).astype(int) + 1
        gx, gy, gz = (lo[i] + np.arange(n[i]) * step for i in range(3))
        G = np.stack(np.meshgrid(gx, gy, gz, indexing="ij"), axis=-1).reshape(-1, 3)
        f = self.field(G).reshape(n[0], n[1], n[2])
        verts, quads = surface_nets(f)
        verts = lo + verts * step
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts.tolist(), [], quads.tolist())
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=step * 0.05)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def surface_nets(f):
    """Naive surface nets on a sampled field f (negative inside). Returns (verts in grid units, quads)."""
    nx, ny, nz = f.shape
    inside = f < 0
    corners = [(cx, cy, cz) for cz in (0, 1) for cy in (0, 1) for cx in (0, 1)]
    F = [f[cx:nx - 1 + cx, cy:ny - 1 + cy, cz:nz - 1 + cz] for cx, cy, cz in corners]
    S = [inside[cx:nx - 1 + cx, cy:ny - 1 + cy, cz:nz - 1 + cz] for cx, cy, cz in corners]
    shp = F[0].shape
    acc = np.zeros(shp + (3,))
    cnt = np.zeros(shp)
    for a in range(8):
        for bit in (1, 2, 4):
            b = a | bit
            if b == a:
                continue
            m = S[a] != S[b]
            t = np.where(m, F[a] / np.where(m, F[a] - F[b], 1), 0)
            ca, cb = np.array(corners[a], float), np.array(corners[b], float)
            acc += m[..., None] * (ca + t[..., None] * (cb - ca))
            cnt += m
    active = cnt > 0
    idx = -np.ones(shp, dtype=np.int64)
    idx[active] = np.arange(active.sum())
    I, J, K = np.nonzero(active)
    verts = np.stack([I, J, K], axis=1) + acc[active] / cnt[active][:, None]
    quads = []
    # edges along x between grid points (i,j,k)-(i+1,j,k); the 4 cells sharing it
    e = inside[:-1, 1:-1, 1:-1] != inside[1:, 1:-1, 1:-1]
    i, j, k = np.nonzero(e)
    j, k = j + 1, k + 1
    q = np.stack([idx[i, j - 1, k - 1], idx[i, j, k - 1], idx[i, j, k], idx[i, j - 1, k]], 1)
    flip = ~inside[i, j, k]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    e = inside[1:-1, :-1, 1:-1] != inside[1:-1, 1:, 1:-1]
    i, j, k = np.nonzero(e)
    i, k = i + 1, k + 1
    q = np.stack([idx[i - 1, j, k - 1], idx[i - 1, j, k], idx[i, j, k], idx[i, j, k - 1]], 1)
    flip = ~inside[i, j, k]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    e = inside[1:-1, 1:-1, :-1] != inside[1:-1, 1:-1, 1:]
    i, j, k = np.nonzero(e)
    i, j = i + 1, j + 1
    q = np.stack([idx[i - 1, j - 1, k], idx[i, j - 1, k], idx[i, j, k], idx[i - 1, j, k]], 1)
    flip = ~inside[i, j, k]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    quads = np.concatenate(quads)
    quads = quads[(quads >= 0).all(1)]
    return verts, quads
