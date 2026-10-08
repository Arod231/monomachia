# Runs inside Blender (headless): builds the Hunter's tricorn and scarf
# (milestone-1 task 46) as Blender sources in the asset repository, which
# scripts/blender/export.mjs then exports into the game.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/build_headwear.py -- \
#     --fit scripts/blender/headwear/hunter_fit.json --assets <asset repository>
#
# The fit (game/tools/export_headwear_fit.gd) holds the head and neck as the
# game measures them, in Godot's axes (y up, z forward): the tricorn's frame
# in Head-bone space with the head's outline at its band, and the neck's
# outlines and the back's line in Neck-bone space. Everything is built in
# those bone spaces (turned into Blender's axes), so the game hangs each on
# its bone with no offset.
#
# - blender/headwear/hunter_tricorn.blend: one mesh, "Hat". The tricorn's
#   silhouette as before (an oval crown over the band, the brim turned up on
#   three sides, a point to the front) in a jingasa's black lacquer, crown and
#   brim with a rolled rim; a dark silk band; a small gold sagari-fuji
#   (hanging wisteria) crest on the crown's front; dark cords from the band's
#   sides tied under the chin. Materials Tricorn_Lacquer (first: the game's
#   tests read its surface 0), Tricorn_Band, Tricorn_Gold and Tricorn_Cord,
#   each with a small roughness and metalness map, so the look reads it.
# - blender/headwear/hunter_scarf.blend: the scarf on a rig of its own
#   ("ScarfRig": ScarfRoot at the knot on the nape, then TailL0-3 and
#   TailR0-3 down the two tails), one mesh, "Scarf", in the material
#   headwear_cloth, so it takes the palette's headwear colour over a
#   near-white seigaiha weave: wound round the neck in rolled layers under
#   the jaw, knotted at the nape, its two tails about 50 cm down the back,
#   weighted along their bones for the game's spring bones; and an empty,
#   "BackCapsule", sized to the back they rest on (its scale the radius and
#   half the straight length), for the spring bones' collision.

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

TILE = 0.12  # the lacquer's noise repeat (m)
WAVE = 0.06  # one repeat of the scarf's seigaiha weave (two waves across, m)
TAIL_LENGTH = 0.5
TAIL_BONES = 4
TAIL_WIDTH = (0.085, 0.07)
CLOTH = 0.004  # the scarf's thickness
NAPE_RISE = 0.05  # how far the collar climbs the nape above the measured neck (m)
NAPE_DRAW_IN = 0.42  # and how much closer to the neck it draws there


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"fit": None, "assets": None}
    for i in range(0, len(argv) - 1, 2):
        key = argv[i].lstrip("-")
        if key not in out:
            raise SystemExit(f"build_headwear: unknown argument {argv[i]}")
        out[key] = argv[i + 1]
    if not all(out.values()):
        raise SystemExit("build_headwear: needs --fit and --assets")
    return out


def g2b(v):
    """Godot's axes (y up, z forward) to Blender's (z up, -y forward)."""
    return Vector((v[0], -v[2], v[1]))


def xf(cols):
    """A Godot Transform3D written as [x, y, z, origin] columns."""
    m = Matrix.Identity(4)
    for c in range(3):
        for r in range(3):
            m[r][c] = cols[c][r]
        m[c][3] = cols[3][c]
    return m


# ------------------------------------------------------------------ helpers

def mesh_object(name, verts, uvs, faces, mat_index=0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([g2b(v) for v in verts], [], faces)
    me.update()
    if uvs is not None:
        layer = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li, vi in zip(poly.loop_indices, poly.vertices):
                layer.data[li].uv = uvs[vi]
    for p in me.polygons:
        p.use_smooth = True
        p.material_index = mat_index
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def grid(rings, u_of, v_of, close=True):
    """Quads between consecutive rings (lists of points), with UVs."""
    verts, uvs, faces = [], [], []
    n = len(rings[0])
    for k, ring in enumerate(rings):
        for i, p in enumerate(ring):
            verts.append(p)
            uvs.append((u_of(k, i), v_of(k, i)))
    cols = n if close else n - 1
    for k in range(len(rings) - 1):
        for i in range(cols):
            a, b = k * n + i, k * n + (i + 1) % n
            c, d = (k + 1) * n + (i + 1) % n, (k + 1) * n + i
            faces.append((a, b, c, d))
    return verts, uvs, faces


def solidify(ob, thickness, offset=-1.0):
    m = ob.modifiers.new("Solidify", "SOLIDIFY")
    m.thickness = thickness
    m.offset = offset
    m.use_even_offset = True
    apply_modifiers(ob)


def apply_modifiers(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def transform(ob, matrix_g):
    """Applies a Godot-space transform to an object's mesh (built in Godot
    space, stored in Blender's axes)."""
    conv = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    ob.data.transform(conv @ matrix_g @ conv.inverted())
    ob.data.update()


def image(name, pixels):
    """A packed, non-colour image from an (h, w, 3) array in 0..1."""
    h, w = pixels.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = pixels
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.pack()
    return img


def material(name, color, rough=None, metal=0.0, orm=None, albedo=None):
    """A Principled material; with `rough`, a small roughness and metalness
    map (glTF's packing: roughness green, metalness blue) so the game's look
    reads them; `orm` gives that map's own pixels. With `albedo`, a
    near-white detail texture, the colour is the factor it is multiplied by
    (the export's base colour factor)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if albedo is not None:
        albedo.colorspace_settings.name = "sRGB"
        ta = nt.nodes.new("ShaderNodeTexImage")
        ta.image = albedo
        if tuple(color) == (1.0, 1.0, 1.0):
            nt.links.new(ta.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            nt.links.new(ta.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*color, 1.0)
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    if rough is not None:
        if orm is None:
            orm = np.zeros((4, 4, 3))
            orm[..., 0] = 1.0
            orm[..., 1] = rough
            orm[..., 2] = metal
        to = nt.nodes.new("ShaderNodeTexImage")
        to.image = image(name + "_orm", orm)
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(to.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs[1], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs[2], bsdf.inputs["Metallic"])
    return mat


def noise2(size, seed, cells):
    """Smooth, tiling 2D value noise (size x size, 0..1): a random grid of
    `cells` x `cells` interpolated with a smoothstep, wrapping at the edges."""
    rng = np.random.default_rng(seed)
    grid_v = rng.random((cells, cells))
    t = np.arange(size) / size * cells
    i0 = np.floor(t).astype(int) % cells
    i1 = (i0 + 1) % cells
    f = t - np.floor(t)
    f = f * f * (3.0 - 2.0 * f)
    rows = grid_v[i0][:, i0] * (1 - f)[None, :] + grid_v[i0][:, i1] * f[None, :]
    rows1 = grid_v[i1][:, i0] * (1 - f)[None, :] + grid_v[i1][:, i1] * f[None, :]
    out = rows * (1 - f)[:, None] + rows1 * f[:, None]
    return (out - out.min()) / max(out.max() - out.min(), 1e-9)


def mon_shapes():
    """The sagari-fuji (hanging wisteria) mon as discs (x, y, radius) in a
    unit circle: a ring round two racemes hanging from the top, bulging out
    and curling in toward their tips, their blossoms shrinking downward,
    with leaves arching from the top."""
    shapes = []
    for i in range(72):
        a = 2 * math.pi * i / 72
        shapes.append((math.cos(a) * 0.92, math.sin(a) * 0.92, 0.075))
    for side in (-1, 1):
        steps = 14
        for j in range(steps):
            t = j / (steps - 1)
            cx = side * (0.14 + 0.46 * math.sin(math.pi * (0.12 + 0.82 * t)))
            cy = 0.5 - 1.18 * t
            size = 0.13 * (1.0 - 0.6 * t)
            shapes.append((cx, cy, size))
            # the raceme's blossoms in two rows
            shapes.append((cx - side * size * 0.95, cy - size * 0.35, size * 0.7))
        for k in range(4):
            a = math.radians(160 - 28 * k)
            shapes.append((side * (0.1 + 0.36 * math.cos(math.radians(90 - 22 * k))), 0.62 - 0.035 * k * k, 0.075 - 0.008 * k))
    return shapes


# ------------------------------------------------------------------ the tricorn

def tricorn(fit):
    hat = fit["hat"]
    rx, rz, zc, crown_h = hat["rx"], hat["rz"], hat["zc"], hat["crown_h"]
    n = 96
    parts = []
    # crown: rings from the band up, narrowing, a domed top with a dent
    levels = [(0.0, 1.0), (0.35, 0.985), (0.7, 0.95), (0.86, 0.9), (0.95, 0.75), (0.99, 0.5), (1.0, 0.0)]
    rings = []
    for lv_y, lv_s in levels:
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            dent = 0.012 * (1.0 - lv_s) * (0.5 + 0.5 * math.cos(a))
            ring.append((math.sin(a) * rx * lv_s, lv_y * crown_h - dent, zc + math.cos(a) * rz * lv_s))
        rings.append(ring)
    v, uv, f = grid(rings, lambda k, i: i / n * 2 * math.pi * rx / TILE, lambda k, i: levels[k][0] * crown_h / TILE)
    crown = mesh_object("Crown", v, uv, f)
    solidify(crown, 0.003, 1.0)
    parts.append((crown, "lacquer"))
    # brim: a flap round the crown's base, flat at the three corners and
    # turned up between them, curling steeper at its edge, ending in a rolled
    # lacquer rim
    steps = [0.0, 0.3, 0.6, 0.85, 1.0]
    rng = np.random.default_rng(3)
    wobble = rng.normal(0.0, 1.0, 7)
    rings = []
    for t in steps:
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            base = Vector((math.sin(a) * rx, 0.0, zc + math.cos(a) * rz))
            out = Vector((math.sin(a) / rx, 0.0, math.cos(a) / rz)).normalized()
            corner = (0.5 + 0.5 * math.cos(3.0 * a)) ** 3
            length = hat["brim"] + (hat["front_brim"] - hat["brim"]) * (0.5 + 0.5 * math.cos(a)) ** 6
            droop = sum(w * math.sin((j + 1) * a + j) for j, w in enumerate(wobble)) * 0.012
            angle = math.radians(68.0 + (8.0 - 68.0) * corner) + droop
            curl = angle * (0.75 + 0.35 * t)
            # 4 mm short of the old brim, for the rolled rim beyond it, so the
            # hat stays inside the head capsule PoseCheck measured
            along = (length - 0.004) * t
            p = base + out * along * math.cos(curl) + Vector((0, 1, 0)) * along * math.sin(curl)
            ring.append(tuple(p))
        rings.append(ring)
    v, uv, f = grid(rings, lambda k, i: i / n * 2 * math.pi * rx / TILE, lambda k, i: steps[k] * hat["brim"] / TILE)
    brim = mesh_object("Brim", v, uv, f)
    solidify(brim, 0.0035, 0.0)
    parts.append((brim, "lacquer"))
    # the rim: a thin tube rolled along the brim's edge
    edge = rings[-1]
    tube = []
    for i, p in enumerate(edge):
        q = Vector(edge[(i + 1) % n]) - Vector(edge[i - 1])
        t = q.normalized()
        up = Vector((0, 1, 0))
        side = t.cross(up).normalized()
        up = side.cross(t).normalized()
        ring = [tuple(Vector(p) + (side * math.cos(b) + up * math.sin(b)) * 0.003) for b in np.linspace(0, 2 * math.pi, 8, endpoint=False)]
        tube.append(ring)
    v, uv, f = grid(tube, lambda k, i: k / n * 2 * math.pi * rx / TILE, lambda k, i: i / 8.0)
    # tube rings run along the edge; close the loop
    m = len(tube[0])
    f += [((n - 1) * m + i, (n - 1) * m + (i + 1) % m, (i + 1) % m, i) for i in range(m)]
    rim = mesh_object("Rim", v, uv, f)
    parts.append((rim, "lacquer"))
    # band: a silk ribbon round the crown's base
    rings = []
    for h in (-0.002, hat["band_height"]):
        rings.append([(math.sin(2 * math.pi * i / n) * (rx + 0.0035), h, zc + math.cos(2 * math.pi * i / n) * (rz + 0.0035)) for i in range(n)])
    v, uv, f = grid(rings, lambda k, i: i / n * 2 * math.pi * rx / TILE, lambda k, i: k * hat["band_height"] / TILE)
    band = mesh_object("Band", v, uv, f)
    solidify(band, 0.0015, 1.0)
    parts.append((band, "band"))
    parts.append((crest(hat), "gold"))
    for cord in cords(hat):
        parts.append((cord, "cord"))
    mats = {
        "lacquer": material("Tricorn_Lacquer", (0.018, 0.016, 0.015), rough=0.26, orm=lacquer_orm(),
                            albedo=image("Tricorn_Lacquer_detail", lacquer_detail())),
        "band": material("Tricorn_Band", (0.05, 0.042, 0.038), rough=0.6,
                         albedo=image("Tricorn_Band_detail", band_detail())),
        "gold": material("Tricorn_Gold", (0.78, 0.58, 0.27), rough=0.3, metal=1.0,
                         albedo=image("Tricorn_Gold_detail", gold_detail())),
        "cord": material("Tricorn_Cord", (0.045, 0.036, 0.032), rough=0.85,
                         albedo=image("Tricorn_Cord_detail", cord_detail())),
    }
    order = ["lacquer", "band", "gold", "cord"]
    for ob, kind in parts:
        ob.data.materials.clear()
        for k in order:
            ob.data.materials.append(mats[k])
        for p in ob.data.polygons:
            p.material_index = order.index(kind)
    bpy.ops.object.select_all(action="DESELECT")
    for ob, _ in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0][0]
    bpy.ops.object.join()
    hat_ob = bpy.context.view_layer.objects.active
    hat_ob.name = "Hat"
    hat_ob.data.name = "Hat"
    transform(hat_ob, xf(hat["to_bone"]))
    return hat_ob


def _grey(v):
    return np.repeat(np.clip(v, 0.0, 1.0)[..., None], 3, axis=-1)


def lacquer_detail(size=256):
    """Near-white: the brush's faint streaks round the crown (along u) and
    dust settled in patches."""
    rng = np.random.default_rng(5)
    t = np.arange(size) / size * 48
    i0 = np.floor(t).astype(int) % 48
    f = t - np.floor(t)
    f = f * f * (3 - 2 * f)
    g = rng.random(48)
    streak = g[i0] * (1 - f) + g[(i0 + 1) % 48] * f
    v = 0.93 + 0.05 * streak[:, None] - 0.06 * noise2(size, 21, 6)
    return _grey(v)


def band_detail(size=256):
    """Near-white grosgrain: fine ribs across the silk ribbon."""
    x = np.arange(size)[None, :] / size
    ribs = 0.5 + 0.5 * np.sin(x * 2 * math.pi * 64)
    return _grey(0.86 + 0.1 * ribs - 0.05 * noise2(size, 23, 8))


def gold_detail(size=128):
    """Near-white with tarnish: darker blotches on the gold leaf."""
    n = noise2(size, 29, 6)
    return _grey(1.0 - 0.28 * np.clip((n - 0.45) / 0.4, 0, 1))


def cord_detail(size=128):
    """Near-white twisted strands slanting round the cord."""
    y, x = np.mgrid[0:size, 0:size] / size
    twist = 0.5 + 0.5 * np.sin((x * 4 + y * 8) * 2 * math.pi)
    return _grey(0.78 + 0.2 * twist)


def lacquer_orm():
    """The lacquer's roughness: glossy, a little uneven, worn duller in
    patches."""
    n = noise2(128, 7, 16)
    orm = np.zeros((128, 128, 3))
    orm[..., 0] = 1.0
    orm[..., 1] = 0.2 + 0.14 * n
    return orm


def crest(hat):
    """The sagari-fuji mon, about 4 cm across, gold, raised on the crown's
    front above the band: a ring round two wisteria clusters hanging in
    arcs from the top, their blossoms shrinking toward the tips, with a few
    leaves where they part."""
    r = 0.021
    centre_y = hat["band_height"] + 0.004 + r
    shapes = mon_shapes()
    verts, faces = [], []
    seg = 10
    for cx, cy, s in shapes:
        base = len(verts)
        for h in (0.0, 0.0012):
            verts.append((cx * r, cy * r, h))
            for i in range(seg):
                a = 2 * math.pi * i / seg
                verts.append(((cx + math.cos(a) * s) * r, (cy + math.sin(a) * s) * r, h))
        for i in range(seg):
            j = (i + 1) % seg
            faces.append((base, base + 1 + j, base + 1 + i))
            top = base + seg + 1
            faces.append((top, top + 1 + i, top + 1 + j))
            faces.append((base + 1 + i, base + 1 + j, top + 1 + j, top + 1 + i))
    # laid on the crown's front: x around, y up, z out along its normal
    placed = []
    rz, rx, zc = hat["rz"], hat["rx"], hat["zc"]
    for x, y, h in verts:
        a = x / rz
        level = (centre_y + y) / hat["crown_h"]
        shrink = 1.0 - 0.05 * max(0.0, level - 0.35) / 0.35
        p = Vector((math.sin(a) * rx * shrink, centre_y + y, zc + math.cos(a) * rz * shrink))
        nrm = Vector((math.sin(a) / rx, 0.0, math.cos(a) / rz)).normalized()
        placed.append(tuple(p + nrm * (0.0028 + h)))
    uvs = [(0.5 + x / (2 * r), 0.5 + y / (2 * r)) for x, y, _ in verts]
    return mesh_object("Crest", placed, uvs, faces)


def cords(hat):
    """Two cords from the band's sides, down in front of the ears and along
    the jaw, tied under the chin (in the beard), with short loose ends."""
    chin = Vector(hat["chin"])
    tie = chin + Vector((0.0, -0.04, -0.045))
    out = []
    for side in (-1, 1):
        start = Vector((side * (hat["rx"] + 0.004), -0.004, hat["zc"] + 0.006))
        mid = Vector((side * (hat["rx"] * 0.95 + 0.012), tie.y * 0.75, hat["zc"] + 0.01))
        end = Vector((side * 0.008, tie.y, tie.z))
        tail = end + Vector((side * 0.006, -0.026, 0.004))
        pts = []
        for i in range(25):
            t = i / 24.0
            p = (1 - t) ** 2 * start + 2 * (1 - t) * t * mid + t * t * end
            pts.append(p)
        pts += [end + (tail - end) * (k / 4.0) for k in range(1, 5)]
        out.append(tube_along(f"Cord{side}", pts, 0.0024))
    knot = []
    for b in range(10):
        a = 2 * math.pi * b / 10
        knot.append(tie + Vector((math.cos(a) * 0.009, math.sin(a) * 0.006, 0.0)))
    out.append(tube_along("Knot", knot + [knot[0]], 0.0035))
    return out


def tube_along(name, pts, radius, sides=8):
    rings = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        t = (Vector(b) - Vector(a)).normalized()
        ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        side = t.cross(ref).normalized()
        up = side.cross(t).normalized()
        rings.append([tuple(Vector(p) + (side * math.cos(2 * math.pi * k / sides) + up * math.sin(2 * math.pi * k / sides)) * radius) for k in range(sides)])
    v, uv, f = grid(rings, lambda k, i: k * 0.01 / TILE, lambda k, i: i / sides)
    # swap rows and columns: each ring is around the tube
    faces = []
    for k in range(len(rings) - 1):
        for i in range(sides):
            a, b = k * sides + i, k * sides + (i + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    return mesh_object(name, v, uv, faces)


# ------------------------------------------------------------------ the scarf

def seigaiha_weave(size=512):
    """A tiling near-white weave with the seigaiha lighter on it: two waves
    across, four rings each, for the palette colour to tint."""
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size * 2.0
    best = np.full(x.shape, np.inf)
    ring_d = np.zeros(x.shape)
    row0 = np.floor(y * 2.0)
    for k in (2, 1, 0):
        j = row0 + k
        cy = j * 0.5
        off = np.where(j % 2 == 0, 0.0, 0.5)
        cx = np.round(x - off) + off
        dist = np.hypot(x - cx, y - cy)
        inside = (dist < 1.0) & (y < cy) & np.isinf(best)
        ring = dist * 4
        ring_d = np.where(inside, np.abs(ring - np.round(ring)) / 4, ring_d)
        best = np.where(inside, dist, best)
    line = 1.0 - np.clip((ring_d - 0.02) / 0.025, 0.0, 1.0)
    weave = 0.5 + 0.5 * np.sin(np.mgrid[0:size, 0:size][1] * math.pi / 2) * np.sin(np.mgrid[0:size, 0:size][0] * math.pi / 2)
    grime = noise2(size, 11, 8)
    v = 0.78 + 0.17 * line + 0.03 * weave - 0.08 * grime
    return np.repeat(np.clip(v, 0, 1)[..., None], 3, axis=-1)


def scarf(fit):
    neck = fit["neck"]
    levels = neck["levels"]
    # the collar's rings: only the levels where the neck is whole (above
    # them today's region sloped up at the nape and the outline thins)
    med = sorted(l["rz"] for l in levels)[len(levels) // 2]
    levels = [l for l in levels if l["rz"] > 0.75 * med and l["rx"] > 0.03]
    n = 64
    rings = []
    ys = []
    for k in range(len(levels) * 3 - 2):
        t = k / 3.0
        a0 = levels[int(math.floor(t))]
        a1 = levels[min(int(math.floor(t)) + 1, len(levels) - 1)]
        f = t - math.floor(t)
        lv = {key: a0[key] + (a1[key] - a0[key]) * f for key in ("y", "cx", "cz", "rx", "rz")}
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            # wound layers: rolls bulging round the neck on a slant, looser
            # at the front, where the cloth sags under the jaw
            roll = 0.5 + 0.5 * math.cos(2 * math.pi * (k / 3.0 * 0.9 + 0.15 * math.sin(a)))
            loose = 0.014 + 0.012 * roll + 0.006 * (0.5 + 0.5 * math.cos(a))
            top = k / max(1, len(levels) * 3 - 3)
            sag = -0.012 * max(0.0, math.cos(a)) * top
            # up the nape to the hairline (the measured outline thins out
            # there), drawn in to the neck as it rises
            back = max(0.0, -math.cos(a)) ** 1.2 * top * top
            rise = NAPE_RISE * back
            draw_in = 1.0 - NAPE_DRAW_IN * back
            ring.append((lv["cx"] + math.sin(a) * (lv["rx"] + loose), lv["y"] + sag + rise,
                         lv["cz"] + math.cos(a) * (lv["rz"] + loose) * draw_in))
        rings.append(ring)
        ys.append(lv["y"])
    circ = 2 * math.pi * (levels[0]["rx"] + levels[0]["rz"]) / 2
    v, uv, f = grid(rings, lambda k, i: i / n * circ / WAVE, lambda k, i: (ys[k] - ys[0]) / WAVE)
    collar = mesh_object("Collar", v, uv, f)
    # the knot at the nape, below the collar's middle
    mid = levels[len(levels) // 2]
    knot_c = Vector((mid["cx"], mid["y"] - 0.01, mid["cz"] - mid["rz"] - 0.03))
    knot = []
    for k in range(9):
        b = math.pi * k / 8
        ring = []
        for i in range(16):
            a = 2 * math.pi * i / 16
            r = 0.022 * math.sin(b) + 0.004
            ring.append(tuple(knot_c + Vector((math.cos(a) * r * 1.3, math.cos(b) * 0.02, math.sin(a) * r))))
        knot.append(ring)
    v, uv, f = grid(knot, lambda k, i: i / 16 * 0.1 / WAVE, lambda k, i: k / 8 * 0.04 / WAVE)
    knot_ob = mesh_object("KnotS", v, uv, f)
    # the tails down the back: the back's line, 3 cm off it
    # the back only (a step whose rearmost point lies in front is a gap in
    # the outfit there)
    back = sorted([p for p in neck["back"] if p[1] < 0.0], key=lambda p: -p[0])
    tails = []
    bones = {}
    for side, label in ((-1, "L"), (1, "R")):
        path = [knot_c + Vector((side * 0.012, -0.01, -0.012))]
        length = 0.0
        y = path[0].y
        steps = 30
        while length < TAIL_LENGTH and steps < 400:
            y -= 0.01
            z = np.interp(-y, [-p[0] for p in back], [p[1] for p in back]) - 0.03
            x = side * (0.03 + 0.05 * min(1.0, length / TAIL_LENGTH))
            p = Vector((x, y, min(z, path[-1].z)))
            length += (p - path[-1]).length
            path.append(p)
            steps += 1
        # resample to equal steps
        seg = 20
        cum = [0.0]
        for i in range(1, len(path)):
            cum.append(cum[-1] + (path[i] - path[i - 1]).length)
        samples = []
        for s in range(seg + 1):
            d = cum[-1] * s / seg
            j = max(1, min(len(cum) - 1, int(np.searchsorted(cum, d))))
            t = (d - cum[j - 1]) / max(cum[j] - cum[j - 1], 1e-9)
            samples.append(path[j - 1].lerp(path[j], t))
        rows = []
        for s, p in enumerate(samples):
            w = TAIL_WIDTH[0] + (TAIL_WIDTH[1] - TAIL_WIDTH[0]) * s / seg
            twist = 0.25 * math.sin(s / seg * math.pi * 1.5) * side
            across = Vector((math.cos(twist), 0.0, math.sin(twist)))
            # the end cut on a slant
            cut = 0.03 * (s / seg) ** 8
            rows.append([tuple(p + across * (w * (c / 4.0 - 0.5)) + Vector((0, -cut * (c / 4.0), 0))) for c in range(5)])
        v, uv, f = grid(rows, lambda k, i: i * w / 4 / WAVE, lambda k, i: k * TAIL_LENGTH / seg / WAVE, close=False)
        ob = mesh_object(f"Tail{label}", v, uv, f)
        tails.append((ob, label, samples))
        bones[label] = [samples[int(round(seg * b / TAIL_BONES))] for b in range(TAIL_BONES + 1)]
    for ob in [collar, knot_ob] + [t[0] for t in tails]:
        solidify(ob, CLOTH, 0.0)
    weave = image("scarf_seigaiha", seigaiha_weave())
    mat = material("headwear_cloth", (1.0, 1.0, 1.0), albedo=weave)
    for ob in [collar, knot_ob] + [t[0] for t in tails]:
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    # the rig, in Neck-bone space
    arm_data = bpy.data.armatures.new("ScarfRig")
    rig = bpy.data.objects.new("ScarfRig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm_data.edit_bones.new("ScarfRoot")
    root.head = g2b(knot_c + Vector((0, 0.03, 0)))
    root.tail = g2b(knot_c)
    for label, pts in bones.items():
        parent = root
        for b in range(TAIL_BONES):
            eb = arm_data.edit_bones.new(f"Tail{label}{b}")
            eb.head = g2b(pts[b])
            eb.tail = g2b(pts[b + 1])
            eb.parent = parent
            eb.use_connect = b > 0
            parent = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    # weights: the collar and knot on the root, each tail along its bones
    for ob in [collar, knot_ob]:
        g = ob.vertex_groups.new(name="ScarfRoot")
        g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    for ob, label, samples in tails:
        groups = [ob.vertex_groups.new(name=f"Tail{label}{b}") for b in range(TAIL_BONES)]
        rootg = ob.vertex_groups.new(name="ScarfRoot")
        pts = np.array([tuple(g2b(p)) for p in samples])
        cum = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
        for vtx in ob.data.vertices:
            d = np.linalg.norm(pts - np.array(vtx.co), axis=1)
            i = int(np.argmin(d))
            s = cum[i] / cum[-1] * TAIL_BONES
            for b in range(TAIL_BONES):
                w = max(0.0, 1.0 - abs(s - (b + 0.5)))
                if b == 0 and s < 0.5:
                    w = 1.0
                if b == TAIL_BONES - 1 and s > TAIL_BONES - 0.5:
                    w = 1.0
                if w > 0:
                    groups[b].add([vtx.index], w, "REPLACE")
            if s < 0.25:
                rootg.add([vtx.index], 1.0 - s / 0.25, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in [collar, knot_ob] + [t[0] for t in tails]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = collar
    bpy.ops.object.join()
    sc = bpy.context.view_layer.objects.active
    sc.name = "Scarf"
    sc.data.name = "Scarf"
    sc.parent = rig
    mod = sc.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    # the back the tails rest on, for the game's spring bones: an empty
    # "BackCapsule" at the capsule's centre, its scale the radius (x, z) and
    # half the straight part's length (y), in Godot's axes
    radius = 0.1
    zs = [p[1] for p in back]
    ys = [p[0] for p in back]
    top, bottom = -0.04, min(ys)
    cap = bpy.data.objects.new("BackCapsule", None)
    cap.location = g2b((0.0, (top + bottom) * 0.5, sum(zs) / len(zs) + radius - 0.008))
    cap.scale = (radius, radius, (top - bottom) * 0.5)
    bpy.context.collection.objects.link(cap)
    return sc, rig


def save(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    if os.path.exists(path + "1"):
        os.remove(path + "1")


def main():
    a = args()
    with open(a["fit"], encoding="utf-8") as f:
        fit = json.load(f)
    out = os.path.join(a["assets"], "blender", "headwear")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hat = tricorn(fit)
    print("build_headwear: tricorn %d vertices, %d materials" % (len(hat.data.vertices), len(hat.data.materials)), flush=True)
    save(os.path.join(out, "hunter_tricorn.blend"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc, rig = scarf(fit)
    print("build_headwear: scarf %d vertices, %d bones" % (len(sc.data.vertices), len(rig.data.bones)), flush=True)
    save(os.path.join(out, "hunter_scarf.blend"))


if __name__ == "__main__":
    main()
