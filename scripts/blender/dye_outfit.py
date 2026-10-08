# Runs inside Blender (headless): dyes a fighter's outfit for one palette
# (milestone-1 task 45) into a Blender source in the asset repository, which
# scripts/blender/export.mjs then exports into the game as a GLB holding the
# dyed maps on one material.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/dye_outfit.py -- \
#     --spec scripts/blender/dyes/<palette>.json --game <repo>/game --assets <asset repository>
#
# The spec (JSON) names the outfit parts (the game's re-proportioned
# Quaternius glTFs), the outfit's maps they share (base colour, ORM, normal),
# the material the dye replaces, each garment slot's dye, the side's pattern
# and the trim's, and how worn the outfit is.
#
# How: Cycles bakes, from the parts in rest pose, which garment each texel
# of the outfit's atlas belongs to and where it sits on the body (position
# and normal), so the patterns and the wear are laid on the body in 3D,
# continuous across the atlas's seams. Then numpy recolours the source's
# base colour garment by garment, keeping its painted shading (the material
# of a texel, cloth, trim, leather or metal, comes from its source colour, as
# tools/bake_palettes.gd sorted it), weaves the patterns into the dyed cloth,
# lighter where the resist kept the dye out, and wears it: dust up the boots
# and hems, knees and cuffs worn through (the dye faded, the pattern ghosted),
# scuffed leather edges and blotchy grime. It writes three maps: the base
# colour (2048), roughness and metalness (glTF's metallic-roughness, 1024)
# and the normal map (the source's, with the pattern's threads raised, 1024),
# packs them into a .blend holding one small plane in a material that uses
# them, and saves that as the source.

import json
import math
import os
import sys

import bpy
import numpy as np

# Garments, from the outfit mesh names (the first match wins), as
# tools/bake_palettes.gd names them. 0 is no garment.
PIECES = [
    ("_Head_Hood", "hood"), ("_Acc_Pauldron", "pauldron"), ("_Body_Belt", "belt"),
    ("_Arms_Bracer", "bracer"), ("_Body", "body"), ("_Arms", "arms"),
    ("_Legs", "legs"), ("_Feet", "boots"),
]
PIECE_IDS = {name: i + 1 for i, (_, name) in enumerate(PIECES)}
SLOTS = ["hood", "vest", "shirt", "trim", "sleeve", "trouser", "leather", "boot", "metal"]
CLOTH, TRIM, LEATHER = 0, 1, 2
DIRT = np.array([0.21, 0.18, 0.14])


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"spec": None, "game": None, "assets": None}
    for i in range(0, len(argv) - 1, 2):
        key = argv[i].lstrip("-")
        if key not in out:
            raise SystemExit(f"dye_outfit: unknown argument {argv[i]}")
        out[key] = argv[i + 1]
    if not all(out.values()):
        raise SystemExit("dye_outfit: needs --spec, --game and --assets")
    return out


def res(game, path):
    return os.path.join(game, path.replace("res://", "")) if path.startswith("res://") else path


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# ------------------------------------------------------------------ the bake

def piece_of(name):
    for key, piece in PIECES:
        if key in name:
            return piece
    return None


def load_parts(game, spec):
    """Imports the parts in rest pose and keeps the outfit's faces: [(object,
    piece)]."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for path in spec["parts"]:
        bpy.ops.import_scene.gltf(filepath=res(game, path))
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    parts = []
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        piece = piece_of(o.name)
        keep = [i for i, m in enumerate(o.data.materials) if m is not None and m.name.split(".")[0] == spec["material"]]
        if piece is None or not keep:
            bpy.data.objects.remove(o)
            continue
        # only the outfit's faces bake into its atlas (the arms' skin is
        # another material on other UVs)
        polys = o.data.polygons
        drop = np.array([p.material_index not in keep for p in polys])
        if drop.any():
            import bmesh
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.nonzero(drop)[0]], context="FACES")
            bm.to_mesh(o.data)
            bm.free()
        o["piece"] = float(PIECE_IDS[piece])
        parts.append((o, piece))
    return parts


def landmarks():
    """Rest positions (game axes: x right, y up, z forward) the wear is
    placed around."""
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")

    def at(bone):
        return to_game(np.array(arm.matrix_world @ arm.data.bones[bone].head_local))

    return {
        "hands": [at("hand_l"), at("hand_r")],
        "knees": [at("calf_l"), at("calf_r")],
        "hips": at("pelvis"),
    }


def to_game(v):
    """Blender's axes (z up, -y forward) to the game's (y up, z forward)."""
    v = np.asarray(v, dtype=np.float64)
    return np.stack([v[..., 0], v[..., 2], -v[..., 1]], axis=-1)


def bake_maps(parts, size):
    """Bakes, into the outfit's atlas, each texel's garment (0 for none), its
    rest position and its normal, in game axes: (piece, position, normal)."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    scene.render.bake.margin = 6
    scene.render.bake.margin_type = "EXTEND"
    out = {}
    for what in ("piece", "position", "normal"):
        img = bpy.data.images.new(f"bake_{what}", size, size, alpha=False, float_buffer=True)
        img.colorspace_settings.name = "Non-Color"
        img.generated_color = (0.0, 0.0, 0.0, 1.0)
        mat = bpy.data.materials.new(f"bake_{what}")
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        emit = nt.nodes.new("ShaderNodeEmission")
        outn = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(emit.outputs[0], outn.inputs["Surface"])
        if what == "piece":
            attr = nt.nodes.new("ShaderNodeAttribute")
            attr.attribute_type = "OBJECT"
            attr.attribute_name = "piece"
            scale = nt.nodes.new("ShaderNodeMath")
            scale.operation = "DIVIDE"
            scale.inputs[1].default_value = 16.0
            nt.links.new(attr.outputs["Fac"], scale.inputs[0])
            nt.links.new(scale.outputs[0], emit.inputs["Color"])
        else:
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            mapv = nt.nodes.new("ShaderNodeVectorMath")
            mapv.operation = "MULTIPLY_ADD"
            # positions within +-2 m, normals within +-1, both into 0..1
            k = 0.25 if what == "position" else 0.5
            mapv.inputs[1].default_value = (k, k, k)
            mapv.inputs[2].default_value = (0.5, 0.5, 0.5)
            nt.links.new(geo.outputs["Position" if what == "position" else "Normal"], mapv.inputs[0])
            nt.links.new(mapv.outputs[0], emit.inputs["Color"])
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.nodes.active = tex
        for o, _ in parts:
            o.data.materials.clear()
            o.data.materials.append(mat)
        for o, _ in parts:
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.bake(type="EMIT", use_clear=False, margin=6, margin_type="EXTEND")
        px = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        out[what] = px.reshape(size, size, 4)[::-1, :, :3].astype(np.float64)
    piece = np.rint(out["piece"][..., 0] * 16.0).astype(np.int32)
    position = to_game(out["position"] * 4.0 - 2.0)
    normal = to_game(out["normal"] * 2.0 - 1.0)
    n = np.linalg.norm(normal, axis=-1, keepdims=True)
    normal = normal / np.maximum(n, 1e-6)
    return piece, position, normal


# ------------------------------------------------------------------ images

def read_image(path, size, srgb):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    if tuple(img.size) != (size, size):
        img.scale(size, size)
    px = np.empty(size * size * img.channels, dtype=np.float32)
    img.pixels.foreach_get(px)
    a = px.reshape(size, size, img.channels)[::-1, :, :3].astype(np.float64)
    bpy.data.images.remove(img)
    # foreach_get gives linear floats for an sRGB image's byte buffer only
    # when it is float; a byte image reads back as stored, so these are the
    # file's own 0..1 values
    return a


def write_image(name, a, path, srgb):
    h, w = a.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(a, 0.0, 1.0)
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def grow(mask, px):
    """A mask grown by `px` texels (a square reach)."""
    out = mask.copy()
    for _ in range(px):
        g = out.copy()
        g[1:] |= out[:-1]
        g[:-1] |= out[1:]
        g[:, 1:] |= out[:, :-1]
        g[:, :-1] |= out[:, 1:]
        out = g
    return out


def shrink(a, size):
    """Box-filters a square map down to `size`."""
    k = a.shape[0] // size
    return a.reshape(size, k, size, k, -1).mean(axis=(1, 3))


# ------------------------------------------------------------------ the dye

def hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-9
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6.0
    h[gm] = (b - r)[gm] / d[gm] + 2.0
    h[bm] = (r - g)[bm] / d[bm] + 4.0
    s = np.where(mx > 1e-9, d / np.maximum(mx, 1e-9), 0.0)
    return h * 60.0, s, mx


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def classify(src):
    """Per-texel weights (cloth, trim, leather, metal; they sum to 1) and the
    source's value, by colour, as tools/bake_palettes.gd sorts them."""
    hue, sat, val = hsv(src)
    warm = 1.0 - smoothstep(80.0, 110.0, hue) * (1.0 - smoothstep(300.0, 330.0, hue))
    cloth = (1.0 - smoothstep(0.26, 0.42, sat)) * warm
    trim = smoothstep(0.55, 0.7, sat) * smoothstep(42.5, 45.5, hue) * (1.0 - smoothstep(68.0, 78.0, hue)) * smoothstep(0.15, 0.2, val) * warm
    trim = trim * (1.0 - cloth)
    leather = np.maximum(0.0, warm - cloth - trim)
    return np.stack([cloth, trim, leather, 1.0 - warm], axis=-1), val


def slot_of(piece, mat):
    if piece == "hood":
        return "hood"
    if piece == "body":
        return ["shirt", "trim", "vest"][mat]
    if piece == "arms":
        return ["sleeve", "trim", "leather"][mat]
    if piece == "legs":
        return "trim" if mat == TRIM else "trouser"
    if piece == "boots":
        return "boot"
    return "trim" if mat == TRIM else "leather"


def references(weights, val, piece_map):
    """The source value each garment's material is pinned to (its 75th
    percentile there), so there it takes its slot's dye exactly."""
    refs = {}
    for name, pid in PIECE_IDS.items():
        here = piece_map == pid
        for m in range(3):
            w = weights[..., m][here]
            v = val[here]
            refs[(name, m)] = max(weighted_percentile(v, w, 0.75), 0.02) if w.sum() > 0 else 0.5
    metal = weights[..., 3][piece_map > 0]
    refs["metal"] = max(weighted_percentile(val[piece_map > 0], metal, 0.75), 0.02) if metal.sum() > 0 else 0.5
    return refs


def weighted_percentile(v, w, q):
    order = np.argsort(v)
    cw = np.cumsum(w[order])
    i = np.searchsorted(cw, cw[-1] * q)
    return float(v[order][min(i, len(v) - 1)])


def shade(target, v, ref):
    """The slot's dye, as bright relative to it as the source's value `v` is
    to the slot's reference: the painted shading kept. Highlights lose a
    little saturation, as real dye does."""
    th, ts, tv = hsv(target[None, :])
    ratio = v / ref
    gamma = np.clip(np.sqrt(ref / tv[0]), 0.45, 1.0) if tv[0] > ref else 1.0
    value = np.clip(tv[0] * ratio ** gamma, 0.0, 1.0)
    sat = np.clip(ts[0] * (1.15 - 0.15 * ratio), 0.0, 1.0)
    return hsv_to_rgb(th[0], sat, value)


def hsv_to_rgb(h, s, v):
    h = np.broadcast_to(h, np.shape(v))
    c = v * s
    hp = (h / 60.0) % 6.0
    x = c * (1.0 - np.abs(hp % 2.0 - 1.0))
    z = np.zeros_like(v)
    sector = np.floor(hp).astype(int)
    r = np.choose(sector, [c, x, z, z, x, c])
    g = np.choose(sector, [x, c, c, x, z, z])
    b = np.choose(sector, [z, z, x, c, c, x])
    m = v - c
    return np.stack([r + m, g + m, b + m], axis=-1)


# ------------------------------------------------------------------ noise and patterns

def value_noise(p):
    """Smooth 3D value noise in 0..1 at points p (..., 3)."""
    i = np.floor(p)
    f = p - i
    u = f * f * (3.0 - 2.0 * f)

    def h(dx, dy, dz):
        q = (i[..., 0] + dx) * 127.1 + (i[..., 1] + dy) * 311.7 + (i[..., 2] + dz) * 74.7
        return np.modf(np.abs(np.sin(q) * 43758.5453))[0]

    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wx = u[..., 0] if dx else 1.0 - u[..., 0]
                wy = u[..., 1] if dy else 1.0 - u[..., 1]
                wz = u[..., 2] if dz else 1.0 - u[..., 2]
                out = out + h(dx, dy, dz) * wx * wy * wz
    return out


def fbm(p, octaves, seed):
    p = p + seed * 17.13
    total, amp, norm = 0.0, 0.5, 0.0
    for _ in range(octaves):
        total = total + value_noise(p) * amp
        norm += amp
        p = p * 2.03 + 3.7
        amp *= 0.5
    return total / norm


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    return np.hypot(px - ax - t * dx, py - ay - t * dy)


def asanoha(x, y):
    """Distance to the hemp-leaf lines, in cell units (a cell is one
    triangle's side): the triangular grid's edges and each triangle's
    centroid joined to its corners."""
    s3 = math.sqrt(3.0)
    # skewed coordinates on the triangular lattice
    b = y / (s3 / 2.0)
    a = x - b * 0.5
    ia, ib = np.floor(a), np.floor(b)
    fa, fb = a - ia, b - ib
    up = fa + fb < 1.0
    # the triangle's corners in skewed coordinates
    c0a = np.where(up, ia, ia + 1.0)
    c0b = np.where(up, ib, ib + 1.0)
    c1a = np.where(up, ia + 1.0, ia)
    c1b = np.where(up, ib, ib + 1.0)
    c2a = np.where(up, ia, ia + 1.0)
    c2b = np.where(up, ib + 1.0, ib)

    def cart(ca, cb):
        return ca + cb * 0.5, cb * s3 / 2.0

    p0, p1, p2 = cart(c0a, c0b), cart(c1a, c1b), cart(c2a, c2b)
    cx = (p0[0] + p1[0] + p2[0]) / 3.0
    cy = (p0[1] + p1[1] + p2[1]) / 3.0
    d = np.full(x.shape, np.inf)
    for (ax, ay), (bx, by) in ((p0, p1), (p1, p2), (p2, p0), ((cx, cy), p0), ((cx, cy), p1), ((cx, cy), p2)):
        d = np.minimum(d, seg_dist(x, y, ax, ay, bx, by))
    return d


def sayagata(x, y):
    """Distance to the sayagata's lines (the board's interlocking squares),
    in units of a manji's arm: manji (arms 2, hooks 1) on the lattice (3, 1),
    (-1, 3), so each one's hooks run into its neighbours' arms in a key-fret
    meander, the whole turned 45 degrees."""
    r = 1.0 / math.sqrt(2.0)
    u = (x + y) * r
    v = (y - x) * r
    # the nearest lattice point, by the lattice's own coordinates
    det = 10.0
    i = np.round((3.0 * u + 1.0 * v) / det)
    j = np.round((-1.0 * u + 3.0 * v) / det)
    tu = u - (3.0 * i - 1.0 * j)
    tv = v - (1.0 * i + 3.0 * j)
    segs = [(0, 0, 2, 0), (0, 0, 0, 2), (0, 0, -2, 0), (0, 0, 0, -2),
            (2, 0, 2, 1), (0, 2, -1, 2), (-2, 0, -2, -1), (0, -2, 1, -2)]
    d = np.full(x.shape, np.inf)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ox = 3.0 * di - 1.0 * dj
            oy = 1.0 * di + 3.0 * dj
            for ax, ay, bx, by in segs:
                d = np.minimum(d, seg_dist(tu, tv, ax + ox, ay + oy, bx + ox, by + oy))
    return d


def seigaiha(x, y, rings=4):
    """Distance to the blue-sea-wave arcs, in units of a wave's radius:
    overlapping fans of concentric rings, each row in front of the one
    above it."""
    best = np.full(x.shape, np.inf)
    ring_d = np.zeros(x.shape)
    row0 = np.floor(y * 2.0)
    for k in (2, 1, 0):  # the lowest row (the largest k) is in front
        j = row0 + k
        cy = j * 0.5
        off = np.where(j % 2 == 0, 0.0, 0.5)
        cx = np.round(x - off) + off
        dist = np.hypot(x - cx, y - cy)
        inside = (dist < 1.0) & (y < cy) & np.isinf(best)
        ring = dist * rings
        dr = np.abs(ring - np.round(ring)) / rings
        ring_d = np.where(inside, dr, ring_d)
        best = np.where(inside, dist, best)
    return np.where(np.isinf(best), 0.0, ring_d)


PATTERNS = {"asanoha": asanoha, "sayagata": sayagata, "seigaiha": seigaiha}


def triplanar(fn, pos, nrm, cell, width, where):
    """The pattern laid on the body in 3D: drawn on each axis plane and
    blended by how much the surface faces it, so it runs across the atlas's
    seams. 1 on a line, 0 off it; drawn only where `where`."""
    out = np.zeros(where.shape)
    w = np.abs(nrm[where]) ** 4
    w = w / np.maximum(w.sum(axis=-1, keepdims=True), 1e-9)
    p = pos[where] / cell
    for axis, (i, j) in enumerate(((2, 1), (0, 2), (0, 1))):
        d = fn(p[..., i], p[..., j])
        line = 1.0 - smoothstep(width, width * 1.8, d)
        out[where] += line * w[..., axis]
    return out


# ------------------------------------------------------------------ main

def dye(spec, game, parts, marks, neutral=False):
    """One atlas's three maps, dyed for the garments of `parts`; a neutral
    atlas (the gear's) takes no dye: its cloth and trim go the leather's
    (the boots' the boot's) colour."""
    def slot(name, m):
        s = slot_of(name, m)
        if neutral and s in spec["dyed"]:
            return "boot" if name == "boots" else "leather"
        return s

    size = spec.get("size", 2048)
    data_size = spec.get("data_size", 1024)
    for o in bpy.data.objects:
        o.hide_render = o.type == "MESH" and all(o is not p for p, _ in parts)
    piece_map, pos, nrm = bake_maps(parts, size)
    src = read_image(res(game, spec["maps"]["base_color"]), size, True)
    orm = read_image(res(game, spec["maps"]["orm"]), size, False)
    src_n = read_image(res(game, spec["maps"]["normal"]), size, False)
    weights, val = classify(src)
    refs = references(weights, val, piece_map)
    slots = {k: hex_rgb(v) for k, v in spec["slots"].items()}
    names = {pid: name for name, pid in PIECE_IDS.items()}
    on = piece_map > 0

    albedo = src.copy()
    colour = np.zeros_like(src)
    for pid, name in names.items():
        here = piece_map == pid
        if not here.any():
            continue
        for m in range(3):
            w = weights[..., m][here]
            colour[here] += shade(slots[slot(name, m)], val[here], refs[(name, m)]) * w[:, None]
        colour[here] += shade(slots["metal"], val[here], refs["metal"]) * weights[..., 3][here][:, None]
    dyed_cloth = np.zeros(piece_map.shape)
    for pid, name in names.items():
        here = piece_map == pid
        for m in range(3):
            if slot(name, m) in spec["dyed"]:
                dyed_cloth[here] += weights[..., m][here]
    trim_w = np.where(on, weights[..., TRIM], 0.0)
    body_w = np.clip(dyed_cloth - trim_w, 0.0, 1.0)
    leather_w = np.zeros(piece_map.shape)
    for pid, name in names.items():
        here = piece_map == pid
        for m in range(3):
            if slot(name, m) not in spec["dyed"]:
                leather_w[here] += weights[..., m][here]

    # the wear's masks, placed on the body
    big = fbm(pos * 5.0, 3, 11)
    fine = fbm(pos * 40.0, 2, 23)
    y = pos[..., 1]
    dirt = np.zeros(piece_map.shape)
    worn = np.zeros(piece_map.shape)  # knees and cuffs worn through
    pid = PIECE_IDS
    dirt = np.where(piece_map == pid["boots"], 1.0 - smoothstep(0.02, 0.58, y), dirt)
    dirt = np.where(piece_map == pid["legs"], 0.55 * (1.0 - smoothstep(0.44, 0.8, y)), dirt)
    legs = piece_map == pid["legs"]
    for k in marks["knees"]:
        d = np.linalg.norm(pos - (k + np.array([0.0, 0.0, 0.07])), axis=-1)
        knee = (1.0 - smoothstep(0.03, 0.13, d)) * smoothstep(-0.2, 0.5, nrm[..., 2])
        dirt = np.where(legs, np.maximum(dirt, 0.75 * knee), dirt)
        worn = np.where(legs, np.maximum(worn, knee), worn)
    arms = (piece_map == pid["arms"]) | (piece_map == pid["bracer"])
    for hnd in marks["hands"]:
        d = np.linalg.norm(pos - hnd, axis=-1)
        cuff = 1.0 - smoothstep(0.05, 0.23, d)
        dirt = np.where(arms, np.maximum(dirt, 0.6 * cuff), dirt)
        worn = np.where(arms, np.maximum(worn, cuff), worn)
    hips = marks["hips"][1]
    dirt = np.where(piece_map == pid["body"], np.maximum(dirt, 0.45 * (1.0 - smoothstep(hips - 0.02, hips + 0.14, y))), dirt)
    wear = spec["wear"]
    dirt = dirt * wear * (0.45 + 0.75 * big) * (0.8 + 0.4 * fine)
    worn = np.clip(worn * wear * (0.5 + 0.9 * big) * smoothstep(0.3, 0.7, fine + 0.25), 0.0, 1.0)

    # the patterns, resist-dyed: lighter lines, tone on tone, ghosted where
    # the cloth is worn through
    pat = spec["pattern"]
    body_line = triplanar(PATTERNS[pat["kind"]], pos, nrm, pat["cell"], pat["width"], body_w > 0.01)
    tpat = spec["trim_pattern"]
    trim_line = triplanar(PATTERNS[tpat["kind"]], pos, nrm, tpat["cell"], tpat["width"], trim_w > 0.01)
    line = body_line * body_w + trim_line * trim_w
    strength = np.where(trim_w > body_w, tpat["strength"], pat["strength"])
    resist = line * strength * (1.0 - 0.7 * worn)
    lum = colour @ np.array([0.2126, 0.7152, 0.0722])
    pale = colour + (lum[..., None] * 0.6 + 0.12 - colour) * 0.35
    colour = colour + (pale - colour) * resist[..., None] + colour * (resist * 0.6)[..., None]
    # worn through: the dye faded toward the undyed cloth and the weave
    undyed = hex_rgb(spec.get("undyed", "#8a7f6c"))
    fade = (worn * dyed_cloth * 0.55)[..., None]
    colour = colour + (undyed * (0.55 + 0.45 * fine[..., None]) * (lum[..., None] / max(float(np.mean(lum[on])), 1e-3)) * 0.5 - colour) * fade

    ao = orm[..., 0]
    colour = colour * (1.0 + (ao - 1.0) * 0.85)[..., None]
    grime = (DIRT + (colour * 0.6 - DIRT) * 0.35)
    colour = colour + (grime - colour) * np.clip(dirt, 0.0, 0.85)[..., None]
    # pale scuffs on the leather's edges, where the normal map bevels
    nz = src_n[..., 2] * 2.0 - 1.0
    edge = smoothstep(0.06, 0.32, 1.0 - nz) * smoothstep(0.35, 0.75, fine)
    lum = colour @ np.array([0.2126, 0.7152, 0.0722])
    scuff = (lum[..., None] + (colour - lum[..., None]) * 0.4) * 1.7 + np.array([0.05, 0.045, 0.04])
    sc = np.clip(edge * leather_w * wear * 0.55, 0.0, 1.0)[..., None]
    colour = colour + (scuff - colour) * sc
    colour = colour * (1.0 - wear * 0.22 * smoothstep(0.45, 0.85, big))[..., None]
    colour = colour * (0.95 + 0.1 * fine)[..., None]
    # a weave on the dyed cloth
    weave = fbm(pos * 900.0, 1, 5)
    colour = colour * (1.0 + (weave - 0.5) * 0.08 * dyed_cloth)[..., None]
    albedo[on] = colour[on]

    # roughness and metalness: cloth matte, leather smoother and polished
    # where worn, metal bright; grime roughens
    rough_by = spec["roughness"]
    rough = (weights[..., CLOTH] * rough_by["cloth"] + weights[..., TRIM] * rough_by["trim"]
             + weights[..., LEATHER] * rough_by["leather"] + weights[..., 3] * rough_by["metal"])
    rough = np.where(dyed_cloth > 0.5, rough_by["cloth"], rough)
    rough = rough - sc[..., 0] * 0.15 + np.clip(dirt, 0.0, 1.0) * 0.12 + (fine - 0.5) * 0.06 - resist * 0.05
    rough = np.clip(rough, 0.2, 1.0)
    metal = np.clip(weights[..., 3] * 0.9, 0.0, 1.0)
    orm_out = np.stack([ao, np.where(on, rough, rough_by["cloth"]), np.where(on, metal, 0.0)], axis=-1)

    # the normal map: the source's, the pattern's threads raised (a height
    # field differentiated in the atlas, so in tangent space)
    height = line * 0.6 + (weave - 0.5) * 0.25 * dyed_cloth
    gy, gx = np.gradient(height)
    k = spec.get("relief", 3.0)
    n = src_n * 2.0 - 1.0
    n[..., 0] -= gx * k
    n[..., 1] += gy * k
    n = n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    normal_out = n * 0.5 + 0.5

    # texels no garment of this atlas uses (past a margin for the mips) go
    # flat, so the maps hold only what is drawn and compress small
    used = grow(on, 12)
    albedo[~used] = albedo[on].mean(axis=0)
    orm_out[~used] = (1.0, rough_by["cloth"], 0.0)
    normal_out[~used] = (0.5, 0.5, 1.0)

    stats = {
        "coverage": float(on.mean()),
        "dyed": {s: list(np.round(slots[s], 3)) for s in spec["dyed"]},
        "mean_albedo_on": list(np.round(albedo[on].mean(axis=0), 3)),
    }
    return albedo, shrink(orm_out, data_size), shrink(normal_out, data_size), stats


def material_for(name, albedo, orm, normal, tmp):
    """A material in the three maps, packed, as the glTF export reads it:
    the base colour, roughness (G) and metalness (B) from the second map,
    and the normal map."""
    a = write_image(f"{name}_albedo", albedo, os.path.join(tmp, f"{name}_albedo.png"), True)
    o = write_image(f"{name}_orm", orm, os.path.join(tmp, f"{name}_orm.png"), False)
    nm = write_image(f"{name}_normal", normal, os.path.join(tmp, f"{name}_normal.png"), False)
    mat = bpy.data.materials.new(f"Dye_{name}")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    ta = nt.nodes.new("ShaderNodeTexImage")
    ta.image = a
    nt.links.new(ta.outputs["Color"], bsdf.inputs["Base Color"])
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = o
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(to.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs[1], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs[2], bsdf.inputs["Metallic"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = nm
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def save_source(spec, atlases, out_blend):
    """Saves the source: one small plane per atlas (Dye_<name>_<atlas>) in a
    material of its maps."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    tmp = os.path.join(os.path.dirname(out_blend), ".dye_tmp")
    os.makedirs(tmp, exist_ok=True)
    for k, (atlas, maps) in enumerate(atlases.items()):
        name = f"{spec['name']}_{atlas}"
        mat = material_for(name, *maps, tmp)
        bpy.ops.mesh.primitive_plane_add(size=0.2, location=(0.3 * k, 0.0, 0.0))
        plane = bpy.context.active_object
        plane.name = f"Dye_{name}"
        plane.data.name = f"Dye_{name}"
        plane.data.materials.append(mat)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, compress=True)
    # Blender keeps the file it overwrote as .blend1
    if os.path.exists(out_blend + "1"):
        os.remove(out_blend + "1")
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)


def main():
    a = args()
    with open(a["spec"], encoding="utf-8") as f:
        spec = json.load(f)
    parts = load_parts(a["game"], spec)
    marks = landmarks()
    # The outfit's parts share one atlas and reuse each other's regions (the
    # boots and belts are painted from the vest's leather), so each atlas
    # dyes only its own garments: the dyed cloth's parts in one, the gear's
    # (belts, boots) in the other, each part drawn in its atlas's material.
    atlases = {}
    for atlas, pieces in spec["atlases"].items():
        mine = [(o, p) for o, p in parts if p in pieces]
        albedo, orm, normal, stats = dye(spec, a["game"], mine, marks, atlas in spec.get("neutral", []))
        atlases[atlas] = (albedo, orm, normal)
        print("dye_outfit: %s %s %s" % (spec["name"], atlas, json.dumps(stats)), flush=True)
    out_blend = os.path.join(a["assets"], "blender", spec["source"])
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    save_source(spec, atlases, out_blend)
    print("dye_outfit: %s -> %s" % (spec["name"], out_blend), flush=True)


main()
