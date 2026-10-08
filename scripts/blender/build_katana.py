# Runs inside Blender (headless): builds the Katana and its saya (milestone-1
# task 47) as Blender sources in the asset repository, which
# scripts/blender/export.mjs then exports into the game.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/build_katana.py -- \
#     --spec scripts/blender/weapons/katana.json --assets <asset repository>
#
# Built in weapon space, in Godot's axes (see WeaponLook): origin at the
# centre of the right hand's grip, +y toward the tip, +x toward the edge.
#
# - blender/weapons/katana.blend: one mesh, "Katana", its surfaces named for
#   the game's materials (blade, habaki, tsuba, tsuba_rim, fittings, same,
#   ito), and three empties, BladeBase, BladeTip and OffHandGrip, where the
#   game's markers go. The blade is the code-built one's (1.333 m from the
#   guard, the sori, the shinogi-zukuri section and the kissaki, the same UVs
#   for its hamon shader), so the markers and the hit paths keep their
#   places; the mounting is modelled: a gold habaki, copper seppa either side
#   of a plain iron tsuba with a rounded rim, the fuchi and kashira in dark
#   iron, and the tsuka's white ray skin (same) under black silk ito wound in
#   the diamond pattern, standing off the grip.
# - blender/weapons/katana_saya.blend: the saya in the sheathed Katana's
#   frame, on its own rig ("SayaRig": SayaRoot, then Sageo0-5): one mesh,
#   "Saya", grown round the blade, black lacquer (Saya_Lacquer, with faint
#   gold maki-e grasses near the mouth) with a horn koiguchi, kurikata and
#   kojiri (Saya_Horn); and the sageo cord ("Sageo", material sageo, which
#   the game tints with the side's dye) through the kurikata, weighted along
#   its bones for the game's spring bones.

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from build_headwear import _grey, cord_detail, g2b, grid, image, material, mesh_object, noise2, tube_along  # noqa: E402


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"spec": None, "assets": None}
    for i in range(0, len(argv) - 1, 2):
        key = argv[i].lstrip("-")
        if key not in out:
            raise SystemExit(f"build_katana: unknown argument {argv[i]}")
        out[key] = argv[i + 1]
    if not all(out.values()):
        raise SystemExit("build_katana: needs --spec and --assets")
    return out


class Blade:
    """The blade's shape, as tools/build_katana.gd drew it."""

    def __init__(self, k):
        self.k = k
        self.root_y = k["guard_y"] + k["tsuba_thickness"]

    def yokote_s(self):
        return 1.0 - self.k["kissaki"] / self.k["blade_length"]

    def width(self, s):
        k = self.k
        return k["width_base"] + (k["width_tip"] - k["width_base"]) * min(s / self.yokote_s(), 1.0)

    def back_x(self, s):
        return -self.k["sori"] * s * s - 0.45 * self.width(s)

    def mid_x(self, s):
        return self.back_x(s) + 0.5 * self.width(s)

    def section(self, s, width_scale=1.0, thickness_scale=1.0):
        """[(x, z, uv.x)] from the edge round the back."""
        k = self.k
        w = self.width(s) * width_scale
        t = (k["thickness_base"] + (k["thickness_tip"] - k["thickness_base"]) * s) * thickness_scale
        u = min(max((s - self.yokote_s()) / (1.0 - self.yokote_s()), 0.0), 1.0)
        edge = 1.0 - k["yokote_turn"] * u - (1.0 - k["yokote_turn"]) * u ** 2.6
        lean = 0.12 * u * u
        thin = 1.0 - 0.65 * u - 0.35 * u ** 3
        back = self.back_x(s) - 0.5 * (w - self.width(s)) + lean * w
        edge_d = max((edge - lean) * w, 0.0)
        ridge_d = min(0.30 * (1.0 - 0.6 * u) * w, edge_d)
        spine_d = min(0.06 * w, edge_d)
        prof = [(edge_d, 0.0, 0.0), (ridge_d, 0.5 * t * thin, 0.7), (spine_d, 0.36 * t * thin, 0.95),
                (0.0, 0.0, 1.0), (spine_d, -0.36 * t * thin, 0.95), (ridge_d, -0.5 * t * thin, 0.7)]
        return [(back + d, z, uvx) for d, z, uvx in prof]

    def tip(self):
        x, z, _ = self.section(1.0)[0]
        return (x, self.root_y + self.k["blade_length"], z)


def blade_mesh(b):
    k = b.k
    stations = [b.yokote_s() * i / k["blade_segments"] for i in range(k["blade_segments"])]
    stations += [b.yokote_s() + (1.0 - b.yokote_s()) * i / k["kissaki_segments"] for i in range(k["kissaki_segments"] + 1)]
    verts, uvs, faces = [], [], []
    for s in stations:
        y = b.root_y - 0.003 + s * (k["blade_length"] + 0.003)
        for x, z, uvx in b.section(s):
            verts.append((x, y, z))
            uvs.append((uvx, s))
    for r in range(len(stations) - 1):
        for j in range(6):
            j2 = (j + 1) % 6
            a, bb = r * 6 + j, r * 6 + j2
            c, d = (r + 1) * 6 + j2, (r + 1) * 6 + j
            faces.append((a, bb, c, d))
    ob = mesh_object("Blade", verts, uvs, faces)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def habaki_mesh(b):
    k = b.k
    lower = b.section(0.0, 1.35, 2.2)
    upper = b.section(0.0, 1.3, 1.9)
    verts = [(x + 0.001, b.root_y, z) for x, z, _ in lower] + [(x + 0.001, b.root_y + k["habaki_length"], z) for x, z, _ in upper]
    faces = [(j, (j + 1) % 6, 6 + (j + 1) % 6, 6 + j) for j in range(6)]
    faces.append(tuple(range(6, 12)))
    ob = mesh_object("Habaki", verts, [(0.0, 0.0)] * len(verts), faces)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def outward(ob):
    """Turns every face of a part outward: the blade's faces came from the
    code-built one, wound clockwise for Godot, which Blender reads inside
    out."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def ellipse(y, rx, rz, seg=40):
    return [(math.cos(2 * math.pi * i / seg) * rx, y, math.sin(2 * math.pi * i / seg) * rz) for i in range(seg)]


def solid_of_rings(name, rings, cap0=False, cap1=False):
    v, uv, f = grid(rings, lambda k, i: i / len(rings[0]), lambda k, i: k / max(1, len(rings) - 1))
    n = len(rings[0])
    if cap0:
        f.append(tuple(reversed(range(n))))
    if cap1:
        base = (len(rings) - 1) * n
        f.append(tuple(range(base, base + n)))
    return mesh_object(name, v, uv, f)


def mounting(k):
    guard_y, th = k["guard_y"], k["tsuba_thickness"]
    pommel_y = guard_y - k["grip_length"]
    out = []
    # the tsuba: a plain iron plate with a rounded rim
    out.append((solid_of_rings("Tsuba", [ellipse(guard_y, 0.041, 0.037), ellipse(guard_y + th, 0.041, 0.037)], True, True), "tsuba"))
    rim = []
    for i in range(48):
        a = 2 * math.pi * i / 48
        c = Vector((math.cos(a) * 0.0413, guard_y + th * 0.5, math.sin(a) * 0.0373))
        out_dir = Vector((math.cos(a) / 0.0413, 0.0, math.sin(a) / 0.0373)).normalized()
        rim.append([tuple(c + out_dir * math.cos(2 * math.pi * j / 8) * 0.0016 + Vector((0, 1, 0)) * math.sin(2 * math.pi * j / 8) * (th * 0.5 + 0.0012)) for j in range(8)])
    v, uv, f = grid(rim, lambda kk, i: kk / 48, lambda kk, i: i / 8)
    f += [((47) * 8 + j, 47 * 8 + (j + 1) % 8, (j + 1) % 8, j) for j in range(8)]
    out.append((mesh_object("TsubaRim", v, uv, f), "tsuba_rim"))
    # copper seppa either side of the tsuba
    for y0 in (guard_y - 0.0016, guard_y + th):
        out.append((solid_of_rings("Seppa", [ellipse(y0, 0.0185, 0.0152), ellipse(y0 + 0.0016, 0.0185, 0.0152)], True, True), "habaki"))
    # the fuchi at the guard and the kashira capping the pommel
    out.append((solid_of_rings("Fuchi", [ellipse(guard_y - 0.0136, 0.0166, 0.0133, 32), ellipse(guard_y - 0.0016, 0.0170, 0.0137, 32)], False, True), "fittings"))
    kash = [ellipse(pommel_y + 0.017, 0.0163, 0.0130, 32), ellipse(pommel_y + 0.004, 0.0158, 0.0124, 32), ellipse(pommel_y, 0.0145, 0.0112, 32)]
    out.append((solid_of_rings("Kashira", kash, False, True), "fittings"))
    # the tsuka: white ray skin, slightly waisted
    top, bottom = guard_y - 0.0136, pommel_y + 0.017
    core = []
    for i in range(25):
        f = i / 24.0
        waist = math.sin(math.pi * f) * 0.0012
        core.append(ellipse(top + (bottom - top) * f, 0.0152 - waist, 0.0119 - waist, 32))
    out.append((solid_of_rings("Same", core), "same"))
    out += [(o, "ito") for o in ito(k, top, bottom)]
    return out


def ito(k, top, bottom):
    """Black silk ito wound in the diamond pattern: two families of flat
    bands crossing on the grip's flat faces, each band raised off the ray
    skin, the second family a hair higher where they cross."""
    out = []
    length = top - bottom
    diamonds = k["ito_diamonds"]
    turns = diamonds / 2.0
    for fam, sgn in ((0, 1), (1, -1)):
        for start in (0.0, math.pi):
            pts = []
            steps = 160
            for i in range(steps + 1):
                t = i / steps
                y = top - t * length
                a = start + sgn * 2 * math.pi * turns * t
                waist = math.sin(math.pi * t) * 0.0012
                rx, rz = 0.0152 - waist + 0.0012 + 0.0004 * fam, 0.0119 - waist + 0.0012 + 0.0004 * fam
                pts.append((math.cos(a) * rx, y, math.sin(a) * rz, a))
            rows = []
            for x, y, z, a in pts:
                nrm = Vector((math.cos(a) / 0.0152, 0.0, math.sin(a) / 0.0119)).normalized()
                along = Vector((0, 1, 0))
                rows.append([tuple(Vector((x, y, z)) + along * (w * 0.0055) + nrm * (0.0006 * (1 - w * w))) for w in (-1.0, -0.5, 0.0, 0.5, 1.0)])
            v, uv, f = grid(rows, lambda kk, i: i / 4, lambda kk, i: kk / steps * diamonds, close=False)
            out.append(mesh_object(f"Ito{fam}{int(start)}", v, uv, f))
    return out


def katana(k):
    b = Blade(k)
    parts = [(blade_mesh(b), "blade"), (habaki_mesh(b), "habaki")] + mounting(k)
    names = ["blade", "habaki", "tsuba", "tsuba_rim", "fittings", "same", "ito"]
    looks = {
        # (the game draws the blade with its own hamon shader)
        "blade": material("blade", (0.17, 0.18, 0.2), rough=0.2, metal=1.0),
        "habaki": material("habaki", (0.72, 0.52, 0.24), rough=0.32, metal=1.0,
                           albedo=image("habaki_detail", brushed_detail())),
        "tsuba": material("tsuba", (0.08, 0.075, 0.07), rough=0.62, metal=0.8, orm=iron_orm(),
                          albedo=image("tsuba_detail", iron_detail(31))),
        "tsuba_rim": material("tsuba_rim", (0.1, 0.09, 0.08), rough=0.5, metal=0.8,
                              albedo=image("tsuba_rim_detail", iron_detail(33))),
        "fittings": material("fittings", (0.09, 0.085, 0.08), rough=0.55, metal=0.8,
                             albedo=image("fittings_detail", iron_detail(35))),
        "same": material("same", (0.78, 0.75, 0.66), rough=0.7, albedo=image("same_detail", same_detail())),
        "ito": material("ito", (0.035, 0.032, 0.036), rough=0.6, albedo=image("ito_detail", silk_detail())),
    }
    for ob, kind in parts:
        outward(ob)
        ob.data.materials.clear()
        for n in names:
            ob.data.materials.append(looks[n])
        for p in ob.data.polygons:
            p.material_index = names.index(kind)
    bpy.ops.object.select_all(action="DESELECT")
    for ob, _ in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0][0]
    bpy.ops.object.join()
    kat = bpy.context.view_layer.objects.active
    kat.name = "Katana"
    kat.data.name = "Katana"
    # drop the material slots no face uses (none should be unused)
    base_s = k["habaki_length"] / k["blade_length"]
    markers = {
        "BladeBase": (b.mid_x(base_s), b.root_y + k["habaki_length"], 0.0),
        "BladeTip": b.tip(),
        "OffHandGrip": (0.0, k["off_hand_y"], 0.0),
    }
    for name, p in markers.items():
        e = bpy.data.objects.new(name, None)
        e.location = g2b(p)
        bpy.context.collection.objects.link(e)
    return kat, b, markers


def brushed_detail(size=128):
    """Near-white: fine brushing along the habaki."""
    rng = np.random.default_rng(41)
    lines = 0.9 + 0.1 * rng.random(size)
    return _grey(lines[None, :] * np.ones((size, 1)) - 0.04 * noise2(size, 43, 4))


def iron_detail(seed, size=128):
    """Near-white: the iron's forged grain and pitting."""
    rng = np.random.default_rng(seed)
    pits = (rng.random((size, size)) > 0.985) * 0.25
    return _grey(0.97 - 0.18 * noise2(size, seed, 12) - pits)


def same_detail(size=256, cells=24):
    """Near-white ray skin: rounded nodules with darker gaps between."""
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size * cells
    rng = np.random.default_rng(45)
    jit = rng.random((cells, cells, 2)) * 0.3 - 0.15
    best = np.full(x.shape, 9.0)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cy = np.floor(y) + dy
            cx = np.floor(x) + dx
            j = jit[(cy % cells).astype(int), (cx % cells).astype(int)]
            d = np.hypot(x - (cx + 0.5 + j[..., 0]), y - (cy + 0.5 + j[..., 1]))
            best = np.minimum(best, d)
    return _grey(1.0 - 0.3 * np.clip((best - 0.25) / 0.3, 0, 1))


def silk_detail(size=128):
    """Near-white: the silk's flat braid, ribs slanting across the tape."""
    y, x = np.mgrid[0:size, 0:size] / size
    twill = 0.5 + 0.5 * np.sin((x * 16 + y * 16) * 2 * math.pi)
    return _grey(0.8 + 0.18 * twill - 0.04 * noise2(size, 47, 8))


def horn_detail(size=128):
    """Near-white: the horn's streaky mottle."""
    n = noise2(size, 49, 5)
    return _grey(0.8 + 0.2 * n)


def iron_orm():
    n = noise2(128, 21, 24)
    orm = np.zeros((128, 128, 3))
    orm[..., 0] = 1.0
    orm[..., 1] = 0.5 + 0.25 * n
    orm[..., 2] = 0.75
    return orm


# ------------------------------------------------------------------ the saya

def saya(k, b):
    s_cfg = k["saya"]
    base_y = b.root_y + k["habaki_length"] * 0.5 - s_cfg["over_base"]
    tip_y = b.root_y + k["blade_length"]
    slices, sides = s_cfg["slices"], s_cfg["sides"]
    wall = s_cfg["wall"]
    rings, centres = [], []
    for i in range(slices + 1):
        t = i / slices
        y = base_y + (tip_y - base_y) * t + (s_cfg["past_tip"] if i == slices else 0.0)
        s = min(max((y - b.root_y) / k["blade_length"], 0.0), 1.0)
        sec = b.section(s, 1.35 if y < b.root_y + k["habaki_length"] else 1.0, 2.2 if y < b.root_y + k["habaki_length"] else 1.0)
        xs = [p[0] for p in sec]
        zs = [p[1] for p in sec]
        if i == slices:
            last = b.section(b.yokote_s())
            xs = [p[0] for p in last]
            zs = [p[1] for p in last]
        cx, cz = (min(xs) + max(xs)) * 0.5, 0.0
        hx = (max(xs) - min(xs)) * 0.5 + wall
        hz = max(abs(z) for z in zs) + wall
        hz = max(hz, 0.0085)
        if i == slices:
            hx *= 0.82
            hz *= 0.9
        ring = []
        for kk in range(sides):
            a = 2 * math.pi * kk / sides
            c = (math.cos(a), math.sin(a))
            p = (math.copysign(abs(c[0]) ** 0.6, c[0]), math.copysign(abs(c[1]) ** 0.6, c[1]))
            ring.append((cx + p[0] * hx, y, cz + p[1] * hz))
        rings.append(ring)
        centres.append((cx, y, hx, hz))
    v, uv, f = grid(rings, lambda kk, i: i / sides, lambda kk, i: kk / slices)
    f.append(tuple(range(slices * sides, (slices + 1) * sides)))
    shell = mesh_object("Shell", v, uv, f)
    parts = [(shell, "lacquer")]
    # horn fittings: the koiguchi at the mouth, the kojiri at the end, and
    # the kurikata on the +z face, a third of a hand below the mouth
    def band(name, y0, y1, grow):
        rs = []
        for y in (y0, y1):
            s = min(max((y - base_y) / (tip_y - base_y), 0.0), 1.0)
            i = min(int(s * slices), slices - 1)
            cx, _, hx, hz = centres[i]
            rs.append([(cx + math.copysign(abs(math.cos(2 * math.pi * kk / sides)) ** 0.6, math.cos(2 * math.pi * kk / sides)) * (hx + grow), y,
                        math.copysign(abs(math.sin(2 * math.pi * kk / sides)) ** 0.6, math.sin(2 * math.pi * kk / sides)) * (hz + grow)) for kk in range(sides)])
        return solid_of_rings(name, rs, False, False)

    parts.append((band("Koiguchi", base_y, base_y + 0.018, 0.0012), "horn"))
    parts.append((band("Kojiri", tip_y - 0.03, tip_y + s_cfg["past_tip"] - 0.001, 0.0012), "horn"))
    kuri_y = base_y + s_cfg["kurikata_below"]
    i = int((kuri_y - base_y) / (tip_y - base_y) * slices)
    cx, _, hx, hz = centres[i]
    kuri_c = Vector((cx - hx * 0.1, kuri_y, hz + 0.004))
    knob = []
    for kk in range(6):
        b2 = math.pi * kk / 5
        knob.append([tuple(kuri_c + Vector((math.cos(2 * math.pi * j / 12) * 0.008 * math.sin(b2) + 0.0, math.sin(2 * math.pi * j / 12) * 0.006 * math.sin(b2), 0.006 * math.cos(b2)))) for j in range(12)])
    v, uv, f = grid(knob, lambda kk, i: i / 12, lambda kk, i: kk / 5)
    parts.append((mesh_object("Kurikata", v, uv, f), "horn"))
    lacquer = material("Saya_Lacquer", (1.0, 1.0, 1.0), rough=0.24, orm=lacquer_orm(), albedo=image("saya_makie", makie(s_cfg)))
    horn = material("Saya_Horn", (0.05, 0.04, 0.035), rough=0.35, albedo=image("saya_horn_detail", horn_detail()))
    looks = {"lacquer": lacquer, "horn": horn}
    order = ["lacquer", "horn"]
    for ob, kind in parts:
        ob.data.materials.clear()
        for n in order:
            ob.data.materials.append(looks[n])
        for p in ob.data.polygons:
            p.material_index = order.index(kind)
    bpy.ops.object.select_all(action="DESELECT")
    for ob, _ in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = shell
    bpy.ops.object.join()
    sy = bpy.context.view_layer.objects.active
    sy.name = "Saya"
    sy.data.name = "Saya"
    # the sageo: through the kurikata, hanging off the mune's side
    n_b = s_cfg["sageo_bones"]
    seg = s_cfg["sageo_segment"]
    chain = [kuri_c + Vector((-0.01 - seg * j * 0.85, -seg * j * 0.5, 0.0)) for j in range(n_b + 1)]
    pts = []
    for j in range(len(chain) - 1):
        for q in range(4):
            pts.append(chain[j].lerp(chain[j + 1], q / 4.0))
    pts.append(chain[-1])
    cord = tube_along("SageoCord", [tuple(p) for p in pts], 0.0035, 8)
    # a flat tassel end
    sageo_mat = material("sageo", (1.0, 1.0, 1.0), rough=0.85, albedo=image("sageo_detail", cord_detail()))
    cord.data.materials.append(sageo_mat)
    cord.name = "Sageo"
    cord.data.name = "Sageo"
    # the rig
    arm = bpy.data.armatures.new("SayaRig")
    rig = bpy.data.objects.new("SayaRig", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm.edit_bones.new("SayaRoot")
    root.head = g2b((0.0, base_y, 0.0))
    root.tail = g2b((0.0, base_y + 0.1, 0.0))
    parent = root
    for j in range(n_b):
        eb = arm.edit_bones.new(f"Sageo{j}")
        eb.head = g2b(chain[j])
        eb.tail = g2b(chain[j + 1])
        eb.parent = parent
        eb.use_connect = j > 0
        parent = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    g = sy.vertex_groups.new(name="SayaRoot")
    g.add(list(range(len(sy.data.vertices))), 1.0, "REPLACE")
    groups = [cord.vertex_groups.new(name=f"Sageo{j}") for j in range(n_b)]
    rootg = cord.vertex_groups.new(name="SayaRoot")
    samples = np.array([tuple(g2b(p)) for p in pts])
    for vtx in cord.data.vertices:
        i = int(np.argmin(np.linalg.norm(samples - np.array(vtx.co), axis=1)))
        groups[min(i // 4, n_b - 1)].add([vtx.index], 1.0, "REPLACE")
        if i < 2:
            rootg.add([vtx.index], 1.0 - i / 2.0, "REPLACE")
    for ob in (sy, cord):
        ob.parent = rig
        m = ob.modifiers.new("Armature", "ARMATURE")
        m.object = rig
    return sy, cord, rig


def lacquer_orm():
    n = noise2(128, 9, 16)
    orm = np.zeros((128, 128, 3))
    orm[..., 0] = 1.0
    orm[..., 1] = 0.2 + 0.1 * n
    return orm


def makie(s_cfg):
    """The saya's colour: black lacquer, and near the mouth a faint spray of
    gold grasses (maki-e) on the outer face, as the board's saya carries
    them, low enough to read black at a distance. u round the saya (the +z
    face about u = 0.25), v from the mouth to the end."""
    w, h = 256, 2048
    rng = np.random.default_rng(31)
    yy, xx = np.mgrid[0:h, 0:w] + 0.5
    img = np.zeros((h, w, 3)) + np.array([0.02, 0.018, 0.017])
    gold = np.array([0.55, 0.42, 0.2])
    mask = np.zeros((h, w))
    for _ in range(s_cfg["grasses"]):
        x0 = rng.uniform(0.12, 0.38) * w
        y0 = rng.uniform(0.06, 0.32) * h
        length = rng.uniform(0.04, 0.12) * h
        bend = rng.uniform(-0.6, 0.6)
        for t in np.linspace(0, 1, 60):
            x = x0 + bend * t * t * length * 0.25
            y = y0 - t * length
            r = 1.6 * (1.0 - t) + 0.4
            d = np.hypot(xx[int(max(y - 4, 0)):int(y + 4) + 1] - x, yy[int(max(y - 4, 0)):int(y + 4) + 1] - y)
            mask[int(max(y - 4, 0)):int(y + 4) + 1] = np.maximum(mask[int(max(y - 4, 0)):int(y + 4) + 1], np.clip(r - d + 0.5, 0, 1))
    img = img + (gold - img) * (mask * s_cfg["makie_strength"])[..., None]
    img *= (0.92 + 0.16 * noise2(h, 5, 64)[:, :w])[..., None]
    return np.clip(img, 0, 1)


def save(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    if os.path.exists(path + "1"):
        os.remove(path + "1")


def main():
    a = args()
    with open(a["spec"], encoding="utf-8") as f:
        k = json.load(f)
    out = os.path.join(a["assets"], "blender", "weapons")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kat, b, markers = katana(k)
    print("build_katana: katana %d vertices; markers %s" % (len(kat.data.vertices), json.dumps({n: [round(c, 5) for c in p] for n, p in markers.items()})), flush=True)
    save(os.path.join(out, "katana.blend"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sy, cord, rig = saya(k, b)
    print("build_katana: saya %d vertices, sageo %d bones" % (len(sy.data.vertices), len(rig.data.bones) - 1), flush=True)
    save(os.path.join(out, "katana_saya.blend"))


if __name__ == "__main__":
    main()
