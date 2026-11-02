# Mystree creature kit for Blender (headless: Blender -b -P <species>.py).
# The look (user, 2026-10-27, reference: faceted papercraft deer): clean, anatomically right animals
# with many even facets (~1.5-3k triangles each), flat shaded, no studs. Built from Raise a Zoo's
# notes (Building Rules - Blender Models): real proportions, recessed eyes, separate glow parts.
#
# How a creature is made: a skeleton of joints (each with an x/z radius) is skinned with Blender's
# Skin modifier into one organic mesh, subdivided once, then decimated to a target face count and
# flat shaded. That gives the even, irregular triangle facets of the reference instead of rings.
# Each rig piece (Body, Leg x4, Antler, Eye, Nose, Hoof...) is its own object; the game swings parts
# named "Leg" from their hip. Colour regions are vertex colours painted by rules (white throat, ...).
#
# Axes: Blender +Y = the animal's front, +Z = up, ground at z = 0, 1 Blender unit = 1 stud.
# Roblox import: (x, y, z) blender -> (x, z, -y) roblox, so the animal faces Roblox -Z.
import bpy, bmesh, math, random
from mathutils import Vector

rng = random.Random(11)


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for d in (bpy.data.meshes, bpy.data.materials):
        for x in list(d):
            d.remove(x)


def _link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def skeleton(name, joints, bones):
    """joints: {key: (pos, (rx, rz))}; bones: [(keyA, keyB)]. Returns a skinned object (not applied)."""
    me = bpy.data.meshes.new(name)
    keys = list(joints.keys())
    index = {k: i for i, k in enumerate(keys)}
    me.from_pydata([Vector(joints[k][0]) for k in keys], [(index[a], index[b]) for a, b in bones], [])
    ob = _link(bpy.data.objects.new(name, me))
    mod = ob.modifiers.new("Skin", "SKIN")
    mod.use_smooth_shade = False
    mod.branch_smoothing = 0.6
    # skin radii per vertex; the first joint is the root
    for i, k in enumerate(keys):
        rx, rz = joints[k][1]
        me.skin_vertices[0].data[i].radius = (rx, rz)
    me.skin_vertices[0].data[0].use_root = True
    return ob


def bake(ob, faces, subdiv=1, jitter=0.0):
    """Apply skin (+subsurf), decimate to about `faces` triangles, jitter a little, flat shade."""
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    if subdiv > 0:
        s = ob.modifiers.new("Sub", "SUBSURF")
        s.levels = subdiv
        s.render_levels = subdiv
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    tri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tri > faces:
        d = ob.modifiers.new("Dec", "DECIMATE")
        d.ratio = faces / tri
        d.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=d.name)
    if jitter > 0:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        for v in bm.verts:
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jitter
        bm.to_mesh(ob.data)
        bm.free()
    for p in ob.data.polygons:
        p.use_smooth = False
    ob.select_set(False)
    return ob


def paint(ob, rule):
    """Vertex colours per face: rule(face_centre, face_normal) -> (r, g, b) 0-255."""
    me = ob.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for p in me.polygons:
        c = Vector((0, 0, 0))
        for vi in p.vertices:
            c += me.vertices[vi].co
        c /= len(p.vertices)
        col = rule(ob.matrix_world @ c, p.normal)
        lin = [(x / 255) ** 2.2 for x in col] + [1.0]
        for li in p.loop_indices:
            attr.data[li].color = lin
    me.color_attributes.active_color = attr
    return ob


def solid(ob, rgb):
    return paint(ob, lambda c, n: rgb)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * max(0.0, min(1.0, t)) for i in range(3))


def ellipsoid(name, centre, size, segs=8, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=1, location=centre)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ---------------------------------------------------------------- previews
def setup_preview(target=(0, 0, 3), dist=16):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "VERTEX"
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_cavity = False
    sc.render.resolution_x = 900
    sc.render.resolution_y = 900
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("World")
    sc.world.color = (0.93, 0.9, 0.84)
    sc.display.shading.background_type = "VIEWPORT"
    sh.background_color = (0.93, 0.9, 0.84)
    cam = bpy.data.objects.get("PreviewCam")
    if not cam:
        cam = _link(bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam")))
    sc.camera = cam
    cam.data.lens = 70
    # ground disc for the contact shadow
    if not bpy.data.objects.get("PreviewGround"):
        bpy.ops.mesh.primitive_circle_add(vertices=64, radius=30, fill_type="NGON", location=(0, 0, 0))
        g = bpy.context.active_object
        g.name = "PreviewGround"
        solid(g, (236, 229, 214))
    return cam


def shoot(cam, path, yaw_deg, pitch_deg=8, target=(0, 0, 3), dist=18):
    t = Vector(target)
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    pos = t + Vector((math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * dist
    cam.location = pos
    cam.rotation_euler = (t - pos).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_glb(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_vertex_color="ACTIVE", export_apply=True)
