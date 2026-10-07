# Runs inside Blender (headless): builds the Moonlit Shrine's nobori banners
# and its grass (milestone-1 task 131) as Blender sources in the asset
# repository, which scripts/blender/export.mjs then exports into the game.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/build_banners_grass.py -- \
#     --spec scripts/blender/shrine/banners_grass.json --font <a .ttf with the kanji> \
#     --assets <asset repository>
#
# - blender/shrine/nobori.blend: one banner per variant ("Nobori0".."Nobori3"),
#   each a lacquered pole with a top bar and a finial, and its cloth hanging
#   from the bar, tied along the pole by loops, torn at the hem. The cloth is
#   dark and weathered (black, deep purple, faded ivory), dyed with the gold
#   sagari-fuji (hanging wisteria) mon at its head and a brushed kanji column
#   below, faded and streaked; the same on both faces. Each variant is two
#   meshes, the pole ("Pole", Nobori_Pole) and the cloth ("Cloth",
#   Nobori_Cloth_<n>, its own texture), the cloth subdivided so the game's
#   wind can sway it, its vertex colour's red the sway's weight (0 at the
#   pole, 1 at the free corner). Origin at the pole's foot, the cloth facing
#   +z (Godot's axes).
# - blender/shrine/grass.blend: short tufts of blade cards ("Tuft0".."Tuft3"),
#   each blade a tapered, curved strip, dark green-grey at the root and paler
#   at the tip by vertex colour (its alpha the sway's weight, 0 at the root),
#   about 6 to 11 cm tall; the game scales them by where they grow.

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from build_headwear import g2b, grid, image, material, mesh_object, mon_shapes, noise2  # noqa: E402


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"spec": None, "font": None, "assets": None}
    for i in range(0, len(argv) - 1, 2):
        key = argv[i].lstrip("-")
        if key not in out:
            raise SystemExit(f"build_banners_grass: unknown argument {argv[i]}")
        out[key] = argv[i + 1]
    if not all(out.values()):
        raise SystemExit("build_banners_grass: needs --spec, --font and --assets")
    return out


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# ------------------------------------------------------------------ the cloth's texture

def raster_triangles(tris, w, h):
    """A coverage mask (h, w) of 2D triangles given in pixel coordinates,
    four samples a pixel."""
    mask = np.zeros((h * 2, w * 2), dtype=np.float32)
    for t in tris:
        p = np.array(t) * 2.0
        x0, y0 = np.floor(p.min(axis=0)).astype(int)
        x1, y1 = np.ceil(p.max(axis=0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, w * 2 - 1), min(y1, h * 2 - 1)
        if x1 < x0 or y1 < y0:
            continue
        yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
        (ax, ay), (bx, by), (cx, cy) = p
        d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(d) < 1e-9:
            continue
        l1 = ((by - cy) * (xx - cx) + (cx - bx) * (yy - cy)) / d
        l2 = ((cy - ay) * (xx - cx) + (ax - cx) * (yy - cy)) / d
        inside = (l1 >= 0) & (l2 >= 0) & (l1 + l2 <= 1)
        mask[y0:y1 + 1, x0:x1 + 1] = np.maximum(mask[y0:y1 + 1, x0:x1 + 1], inside)
    return mask.reshape(h, 2, w, 2).mean(axis=(1, 3))


def text_triangles(text, font, height_px, centre_x, top_y, gap):
    """Each character of a vertical column as triangles in pixel
    coordinates, `height_px` a character, top to bottom."""
    out = []
    y = top_y
    for ch in text:
        cu = bpy.data.curves.new("glyph", "FONT")
        cu.body = ch
        cu.font = font
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        ob = bpy.data.objects.new("glyph", cu)
        bpy.context.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        pts = np.array([v.co[:2] for v in bm.verts])
        lo, hi = pts.min(axis=0), pts.max(axis=0)
        scale = height_px / max(hi[1] - lo[1], hi[0] - lo[0], 1e-6)
        mid = (lo + hi) * 0.5
        for f in bm.faces:
            out.append([(centre_x + (v.co.x - mid[0]) * scale, y + height_px * 0.5 - (v.co.y - mid[1]) * scale) for v in f.verts])
        bm.free()
        bpy.data.meshes.remove(me)
        bpy.data.objects.remove(ob)
        bpy.data.curves.remove(cu)
        y += height_px + gap
    return out


def mon_mask(w, h, cx, cy, r):
    """The sagari-fuji mon (mon_shapes(), the tricorn's crest) as a mask."""
    yy, xx = np.mgrid[0:h, 0:w] + 0.5
    u = (xx - cx) / r
    v = -(yy - cy) / r
    m = np.zeros((h, w), dtype=np.float32)
    for px, py, s in mon_shapes():
        m = np.maximum(m, np.clip((s - np.hypot(u - px, v - py)) * r * 0.7 + 0.5, 0.0, 1.0))
    return m


def cloth_texture(variant, spec, font, w, h):
    """The banner's face: its dyed cloth, weathered, the mon at the head and
    the kanji column below."""
    rng = np.random.default_rng(100 + variant["seed"])
    base = hex_rgb(variant["cloth"])
    ink = hex_rgb(variant["ink"])
    gold = hex_rgb(spec["gold"])
    yy, xx = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
    blotch = noise2(h, variant["seed"], 12)[:h, :w]
    fine = noise2(h, variant["seed"] + 1, 200)[:h, :w] * 0.6 + noise2(h, variant["seed"] + 2, 600)[:h, :w] * 0.4
    # rain streaks running down, the hem darker and dirtier
    streak = np.repeat(rng.random((1, w)), h, axis=0)
    streak = np.convolve(streak[0], np.ones(9) / 9, mode="same")[None, :].repeat(h, axis=0)
    shade = 1.0 + (blotch - 0.5) * 0.25 + (fine - 0.5) * 0.08 - 0.1 * (streak > 0.6) * yy
    shade *= 1.0 - 0.35 * np.clip((yy - 0.75) / 0.25, 0, 1)
    img = base[None, None, :] * shade[..., None]
    # the mon, gold, near the head
    mon = mon_mask(w, h, w * 0.5, h * spec["mon_at"], w * spec["mon_size"])
    wear = np.clip(0.7 + 0.5 * (fine - 0.5) + 0.2 * (blotch - 0.5), 0, 1)
    img = img + (gold[None, None, :] * (0.85 + 0.3 * (fine[..., None] - 0.5)) - img) * (mon * wear)[..., None]
    # the kanji, brushed, faded where the cloth wore
    text = variant["text"]
    char_h = h * spec["char_size"]
    top = h * spec["text_top"]
    tris = text_triangles(text, font, char_h, w * 0.5, top, char_h * 0.12)
    mask = raster_triangles(tris, w, h)
    fade = np.clip(0.55 + 0.6 * fine + 0.25 * blotch - 0.3 * (streak > 0.7), 0, 1)
    img = img + (ink[None, None, :] * (0.9 + 0.2 * (fine[..., None] - 0.5)) - img) * (mask * fade * variant["ink_strength"])[..., None]
    return np.clip(img, 0, 1)


# ------------------------------------------------------------------ the banner

def nobori(index, variant, spec, font):
    pole_h = spec["pole_height"]
    cloth_w, cloth_h = spec["cloth_width"], spec["cloth_height"]
    top = pole_h - 0.12
    parts = []
    # the pole: a lacquered shaft, a ring at its foot, a finial at the top
    rings = []
    n = 12
    for y in np.linspace(0.0, pole_h, 24):
        r = spec["pole_radius"] * (1.0 - 0.15 * y / pole_h)
        rings.append([(math.cos(2 * math.pi * i / n) * r, y, math.sin(2 * math.pi * i / n) * r) for i in range(n)])
    v, uv, f = grid(rings, lambda k, i: i / n, lambda k, i: k / 24 * pole_h)
    parts.append(mesh_object("Shaft", v, uv, f))
    knob = []
    for k in range(7):
        b = math.pi * k / 6
        knob.append([(math.cos(2 * math.pi * i / n) * 0.035 * math.sin(b), pole_h + 0.05 - 0.05 * math.cos(b), math.sin(2 * math.pi * i / n) * 0.035 * math.sin(b)) for i in range(n)])
    v, uv, f = grid(knob, lambda k, i: i / n, lambda k, i: k / 6)
    parts.append(mesh_object("Finial", v, uv, f))
    # the top bar, out along +x from the pole
    bar = []
    for x in np.linspace(-0.04, cloth_w + 0.05, 8):
        bar.append([(x, top + math.cos(2 * math.pi * i / 8) * 0.014, math.sin(2 * math.pi * i / 8) * 0.014) for i in range(8)])
    v, uv, f = grid(bar, lambda k, i: i / 8, lambda k, i: k / 8)
    parts.append(mesh_object("Bar", v, uv, f))
    # loops tying the cloth to the pole and the bar
    for j in range(spec["loops"]):
        y = top - 0.08 - j * (cloth_h - 0.3) / max(1, spec["loops"] - 1)
        loop = []
        for k in range(10):
            a = 2 * math.pi * k / 10
            loop.append([(0.035 + math.cos(a) * 0.04 + math.cos(2 * math.pi * i / 6) * 0.006, y + math.sin(2 * math.pi * i / 6) * 0.006, math.sin(a) * 0.03) for i in range(6)])
        v, uv, f = grid(loop, lambda k, i: i / 6, lambda k, i: k / 10)
        parts.append(mesh_object(f"Loop{j}", v, uv, f))
    pole_mat = material("Nobori_Pole", (0.05, 0.035, 0.03), rough=0.45)
    for p in parts:
        p.data.materials.append(pole_mat)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    pole = bpy.context.view_layer.objects.active
    pole.name = f"Nobori{index}_Pole"
    pole.data.name = pole.name
    # the cloth: from the bar down, the pole's side tied, a few soft folds,
    # the hem torn
    rng = np.random.default_rng(7 + index)
    cols, rows = 10, 48
    hem = rng.uniform(0.0, 0.12, cols + 1)
    hem[0] = 0.02
    verts, uvs, faces, sway = [], [], [], []
    for r in range(rows + 1):
        t = r / rows
        for c in range(cols + 1):
            s = c / cols
            x = 0.04 + s * cloth_w
            y = top - 0.02 - t * (cloth_h - hem[c] * t ** 6)
            z = 0.025 * math.sin(s * math.pi * 2.0 + t * 3.0) * s + 0.01 * math.sin(t * 17.0 + index) * s
            verts.append((x, y, z))
            uvs.append((s, 1.0 - t))
            sway.append(min(1.0, s * 0.8 + t * 0.6) * min(1.0, t * 3.0 + s))
    for r in range(rows):
        for c in range(cols):
            a = r * (cols + 1) + c
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    cloth = mesh_object(f"Nobori{index}_Cloth", verts, uvs, faces)
    col = cloth.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, w in enumerate(sway):
        col.data[i].color = (w, 0.0, 0.0, 1.0)
    tex = cloth_texture(variant, spec, font, 512, 2048)
    img = image(f"nobori_cloth_{index}", tex)
    mat = material(f"Nobori_Cloth_{index}", (1.0, 1.0, 1.0), rough=0.9, albedo=img)
    mat.use_backface_culling = False
    cloth.data.materials.append(mat)
    for o in (pole, cloth):
        o.location = Vector(variant.get("offset", (0, 0, 0)))
    return pole, cloth


# ------------------------------------------------------------------ the grass

def tuft(index, spec):
    rng = np.random.default_rng(50 + index)
    blades = rng.integers(spec["blades"][0], spec["blades"][1] + 1)
    verts, faces, cols = [], [], []
    root = hex_rgb(spec["root"])
    tip = hex_rgb(spec["tip"])
    for b in range(blades):
        a = rng.uniform(0, 2 * math.pi)
        r0 = rng.uniform(0.0, 0.035)
        base = Vector((math.cos(a) * r0, 0.0, math.sin(a) * r0))
        h = rng.uniform(spec["height"][0], spec["height"][1])
        lean = Vector((math.cos(a), 0.0, math.sin(a))) * rng.uniform(0.2, 0.6) * h
        width = rng.uniform(0.004, 0.007)
        turn = rng.uniform(0, math.pi)
        side = Vector((math.cos(turn), 0.0, math.sin(turn)))
        segs = 4
        start = len(verts)
        for k in range(segs + 1):
            t = k / segs
            p = base + Vector((0, h * t, 0)) + lean * t * t
            wk = width * (1.0 - t) ** 0.8
            for sgn in (-1, 1):
                verts.append(tuple(p + side * wk * sgn * 0.5))
                c = root + (tip - root) * t
                cols.append((c[0], c[1], c[2], t))
        for k in range(segs):
            a0 = start + k * 2
            faces.append((a0, a0 + 1, a0 + 3, a0 + 2))
    ob = mesh_object(f"Tuft{index}", verts, [(0.0, 0.0)] * len(verts), faces)
    col = ob.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(cols):
        col.data[i].color = c
    return ob


def save(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    if os.path.exists(path + "1"):
        os.remove(path + "1")


def main():
    a = args()
    with open(a["spec"], encoding="utf-8") as f:
        spec = json.load(f)
    out = os.path.join(a["assets"], "blender", "shrine")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    font = bpy.data.fonts.load(a["font"])
    for i, variant in enumerate(spec["banners"]["variants"]):
        variant = dict(variant, offset=(i * 1.5, 0.0, 0.0))
        nobori(i, variant, spec["banners"], font)
    save(os.path.join(out, "nobori.blend"))
    print("build_banners_grass: %d banners" % len(spec["banners"]["variants"]), flush=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    grass_mat = material("Grass", (1.0, 1.0, 1.0), rough=0.85)
    for i in range(spec["grass"]["variants"]):
        ob = tuft(i, spec["grass"])
        ob.location = g2b((i * 0.3, 0.0, 0.0))
        ob.data.materials.append(grass_mat)
    save(os.path.join(out, "grass.blend"))
    print("build_banners_grass: %d grass tufts" % spec["grass"]["variants"], flush=True)


if __name__ == "__main__":
    main()
