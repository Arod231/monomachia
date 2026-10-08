# Runs inside Blender (headless): sculpts the Moonlit Shrine's distant
# landscape (milestone-1 task 51) as a Blender source in the asset
# repository, which scripts/blender/export.mjs then exports into the game.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/build_shrine_landscape.py -- \
#     --spec scripts/blender/shrine/landscape.json --assets <asset repository> \
#     [--preview <folder>]
#
# landscape.json is the game's own numbers (ShrineBackdrop.landscape_spec(),
# written by game/tools/export_landscape_spec.gd): each range's crest, with
# its valley toward the moon, and each cliff's place, top, radius and foot.
# Today's layout, remodelled as real 3D (the owner's answers, Oct 8):
#
# - "Range<i>" (nearest 0): a ring of mountains whose crest is the spec's,
#   roughened where it stands clear of the moon, its face falling steeply
#   toward the shrine to its foot under the clouds and its back away behind
#   it, never above the crest. The face is sculpted: long gullies and arete
#   spurs running down it, lumps, strata stepping it, and a little thermal
#   erosion, so loose talus gathers at the foot. "Range<i>_Low" is the same
#   ring with every other row and column of its points (Low's lighter
#   landscape, GraphicsPreset.light_landscape).
# - "Cliff<i>": a karst spire rising out of the clouds, flaring toward its
#   foot, its sides stepped by strata and split by vertical fissures, a
#   notch where its waterfall leaves it, and a flat top at the spec's height
#   out to 0.8 of its radius, where the game stands its pagoda or temple
#   hall. "Cliff<i>_Low" lighter the same way.
#
# The models carry no maps of their own: the game's landscape shader lays the
# paving export's Poly Haven scans (rock_surface, and concrete_moss for the
# moss and grime; CC0) over them by world position (triplanar).
#
# Every range and cliff carries its sculpting in its first UV map ("Mask"):
# u is how much water would run there (the gullies, the fissures: the
# shader's dark, damp rock and moss), v how high up it lies (0 at the clouds,
# 1 at the crest or the top). Godot's axes throughout: +y up, angle a from +z
# toward +x, as ShrineLayout.polar().

import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_shrine_buildings import flat_material, g, reset, save  # noqa: E402

import bmesh  # noqa: E402

# ------------------------------------------------------------------ arguments

def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"spec": None, "assets": None, "preview": None}
    for i in range(0, len(argv) - 1, 2):
        key = argv[i].lstrip("-")
        if key not in out:
            raise SystemExit(f"build_shrine_landscape: unknown argument {argv[i]}")
        out[key] = argv[i + 1]
    if not out["spec"] or not out["assets"]:
        raise SystemExit("build_shrine_landscape: needs --spec and --assets")
    return out


# ------------------------------------------------------------------ noise

class Noise:
    """3D gradient noise (Perlin's) over numpy arrays, about -1..1, from a
    seed of its own, so a rebuild sculpts the same landscape."""

    GRADS = np.array([[1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0], [1, 0, 1], [-1, 0, 1], [1, 0, -1], [-1, 0, -1],
                      [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1]], dtype=np.float64)

    def __init__(self, seed):
        rnd = np.random.RandomState(seed)
        p = rnd.permutation(256)
        self.perm = np.concatenate([p, p, p])
        self.grad_of = rnd.randint(0, 12, 256)

    def _grad(self, ix, iy, iz, dx, dy, dz):
        h = self.perm[self.perm[self.perm[ix] + iy] + iz]
        gr = self.GRADS[self.grad_of[h & 255]]
        return gr[..., 0] * dx + gr[..., 1] * dy + gr[..., 2] * dz

    def __call__(self, x, y, z):
        x, y, z = np.asarray(x, float), np.asarray(y, float), np.asarray(z, float)
        x0, y0, z0 = np.floor(x), np.floor(y), np.floor(z)
        fx, fy, fz = x - x0, y - y0, z - z0
        ix, iy, iz = x0.astype(np.int64) & 255, y0.astype(np.int64) & 255, z0.astype(np.int64) & 255
        u, v, w = (f * f * f * (f * (f * 6 - 15) + 10) for f in (fx, fy, fz))
        out = 0.0
        for cx in (0, 1):
            for cy in (0, 1):
                for cz in (0, 1):
                    weight = (u if cx else 1 - u) * (v if cy else 1 - v) * (w if cz else 1 - w)
                    out = out + weight * self._grad((ix + cx) & 255, (iy + cy) & 255, (iz + cz) & 255,
                                                    fx - cx, fy - cy, fz - cz)
        return out

    def fbm(self, x, y, z, octaves=4, gain=0.5, lacunarity=2.03):
        total, amp, norm = 0.0, 1.0, 0.0
        for o in range(octaves):
            f = lacunarity ** o
            total = total + amp * self(x * f + o * 17.3, y * f - o * 9.1, z * f + o * 5.7)
            norm += amp
            amp *= gain
        return total / norm

    def ridged(self, x, y, z, octaves=4, gain=0.5):
        """Sharp crests (1) between rounded troughs: aretes and gullies."""
        total, amp, norm = 0.0, 1.0, 0.0
        for o in range(octaves):
            f = 2.07 ** o
            r = 1.0 - np.abs(self(x * f + o * 31.7, y * f + o * 3.3, z * f - o * 12.9))
            total = total + amp * r * r
            norm += amp
            amp *= gain
        return total / norm


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ meshes

def grid_object(name, pts, mask, outward, periodic_cols=True, cap=None):
    """An object of a rows x cols grid of points (Godot axes, rows down the
    first index), its quads closing round the columns when periodic, with
    mask (rows x cols x 2) as its "Mask" UV map; cap, if given, is a point
    the first row closes on (a fan). Its faces turn the way outward(vertex
    position, Blender axes) points, on the whole."""
    rows, cols = pts.shape[0], pts.shape[1]
    verts = [tuple(g(*p)) for p in pts.reshape(-1, 3)]
    uvs = mask.reshape(-1, 2)
    faces = []
    span = cols if periodic_cols else cols - 1
    for i in range(rows - 1):
        for j in range(span):
            j1 = (j + 1) % cols
            a, b, c, d = i * cols + j, i * cols + j1, (i + 1) * cols + j1, (i + 1) * cols + j
            faces.append((a, b, c, d))
    if cap is not None:
        centre = len(verts)
        verts.append(tuple(g(*cap[0])))
        uvs = np.vstack([uvs, cap[1]])
        for j in range(cols):
            faces.append((centre, (j + 1) % cols, j))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    uv = me.uv_layers.new(name="Mask")
    loop_verts = np.zeros(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", loop_verts)
    uv.data.foreach_set("uv", uvs[loop_verts].astype(np.float32).ravel())
    # faces wound alike, then all turned outward (up off a range, out of a
    # spire), so the game draws their fronts
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    facing = sum(f.normal.dot(outward(f.calc_center_median())) * f.calc_area() for f in bm.faces)
    if facing < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def lighter(name, pts, mask, outward, cap=None):
    """The twin of a grid's object for Low, named <name>_Low: every other row
    and column of its points, kept where they were (about a quarter of the
    faces), its last row (a range's crest) always among them, so its skyline
    stays the full model's."""
    rows = list(range(0, pts.shape[0], 2))
    if rows[-1] != pts.shape[0] - 1:
        rows.append(pts.shape[0] - 1)
    return grid_object(name + "_Low", pts[rows][:, ::2], mask[rows][:, ::2], outward, cap=cap)


def flow(heights, periodic_cols=True):
    """How much water reaches each cell of a heights grid (rows x cols), each
    cell passing what it gathers to its lowest neighbour: high in gullies
    and fissures. 0..1, on a log scale."""
    rows, cols = heights.shape
    acc = np.ones_like(heights)
    order = np.argsort(-heights, axis=None)
    for idx in order:
        i, j = divmod(int(idx), cols)
        h = heights[i, j]
        best, bi, bj = h, -1, -1
        for di in (-1, 0, 1):
            ii = i + di
            if ii < 0 or ii >= rows:
                continue
            for dj in (-1, 0, 1):
                if di == 0 and dj == 0:
                    continue
                jj = j + dj
                if periodic_cols:
                    jj %= cols
                elif jj < 0 or jj >= cols:
                    continue
                if heights[ii, jj] < best:
                    best, bi, bj = heights[ii, jj], ii, jj
        if bi >= 0:
            acc[bi, bj] += acc[i, j]
    return np.log1p(acc) / np.log1p(acc.max())


# ------------------------------------------------------------------ the ranges

FACE_SLOPE = math.radians(54.0)   # how steeply a range's face climbs from its foot
COLUMN = 2.6                      # metres between a range's columns at its distance
FACE_ROWS = 52
BACK_ROWS = 10
STRATA = 8.0                      # metres between the faces' strata


def moon_weight(angles, moon_angle):
    """1 toward the moon (within the valley the spec cut), 0 well clear of it."""
    return smoothstep(0.6, 0.93, np.cos(angles - moon_angle))


def build_range(spec, rng_spec):
    cloud = spec["cloud_sea_height"]
    foot = spec["range_foot"]
    moon = spec["moon"]
    moon_angle = math.atan2(moon[0], moon[2])
    crest = np.array(rng_spec["crest"], dtype=np.float64)
    n0 = crest.shape[0]
    d = rng_spec["distance"]
    noise = Noise(rng_spec["seed"])
    cols = int(round(2 * math.pi * d / COLUMN))
    # the crest, sampled round the columns (periodic, cubic between the
    # spec's points)
    k = np.arange(cols) * n0 / cols
    k0 = np.floor(k).astype(int)
    f = k - k0
    pts = [crest[(k0 + o) % n0] for o in (-1, 0, 1, 2)]
    ang = 2 * math.pi * np.arange(cols) / cols

    def cubic(p0, p1, p2, p3):
        return p1 + 0.5 * f[:, None] * (p2 - p0 + f[:, None] * (2 * p0 - 5 * p1 + 4 * p2 - p3 + f[:, None] * (3 * (p1 - p2) + p3 - p0)))

    # held between its neighbours, so it never overshoots the spec's crest
    # where it drops steeply into the moon's valley
    c = np.clip(cubic(*pts), np.minimum(pts[1], pts[2]), np.maximum(pts[1], pts[2]))
    crest_r = np.hypot(c[:, 0], c[:, 2])
    crest_h = c[:, 1]
    # never above the spec's crest by more than the jag, and only clear of
    # the moon: the moon's valley keeps exactly its height or lower
    clear = 1.0 - moon_weight(ang, moon_angle)
    cx, cz = np.sin(ang), np.cos(ang)
    lateral = d / 22.0
    jag = (noise.ridged(cx * lateral, cz * lateral, 0.0, octaves=4) - 0.45) * (crest_h - cloud).clip(4.0) * 0.09
    top = crest_h + np.where(jag > 0, jag * clear, jag)
    rise = (top - foot).clip(5.0)
    spur = 1.0 + 0.45 * noise.fbm(cx * d / 140.0, cz * d / 140.0, 3.1, octaves=3)
    width = rise / math.tan(FACE_SLOPE) * spur
    # the face: rows from the foot (0) up to the crest (FACE_ROWS - 1), denser
    # near the crest, then the back
    t = (np.arange(FACE_ROWS) / (FACE_ROWS - 1)) ** 0.75
    T = t[:, None]
    rho = crest_r[None, :] - width[None, :] * (1.0 - T)
    shape = 0.8 * T ** 1.5 + 0.2 * T
    h = foot + rise[None, :] * shape
    # the relief: a ridged, domain-warped noise laid on the ground itself
    # (not round the ring), so spurs and valleys branch down the face as
    # water would carve them, each range's features its own size for its
    # distance
    wl = d * 0.3
    x, z = cx[None, :] * rho, cz[None, :] * rho
    wx = x + 0.4 * wl * noise.fbm(x / wl * 0.5, z / wl * 0.5, 1.7, octaves=3)
    wz = z + 0.4 * wl * noise.fbm(x / wl * 0.5 + 5.2, z / wl * 0.5, 8.3, octaves=3)
    relief = noise.ridged(wx / wl, wz / wl, 0.37, octaves=6, gain=0.55) - 0.5
    belly = np.sin(np.pi * T) ** 0.5 * (1.0 - 0.25 * T)
    h = h + rise[None, :] * 0.42 * relief * belly
    X, Z = x / 30.0, z / 30.0
    band = STRATA * (1.0 + 0.25 * noise(X * 0.2, Z * 0.2, 7.7))
    q = h / band
    stepped = band * (np.floor(q) + smoothstep(0.35, 0.65, q - np.floor(q)))
    patches = smoothstep(-0.1, 0.35, noise(X * 0.3, Z * 0.3, 2.2))
    h = h + (stepped - h) * 0.45 * patches * np.sin(np.pi * T)
    h = np.minimum(h, top[None, :] - 0.3)
    # the crest row is the crest, as the spec and the jag lay it
    h[-1, :] = top
    # thermal erosion: slopes steeper than the talus angle shed down them
    for _ in range(12):
        drop = (h[1:, :] - h[:-1, :]) - np.tan(math.radians(62.0)) * (rho[1:, :] - rho[:-1, :])
        move = np.clip(drop, 0.0, None) * 0.25
        move[-1, :] = 0.0  # the crest stays
        h[1:, :] -= move
        h[:-1, :] += move
    h = np.minimum(h, top[None, :])
    # the back: falling away behind the crest, never above it
    s = (np.arange(1, BACK_ROWS + 1) / BACK_ROWS)[:, None]
    back_rho = crest_r[None, :] + width[None, :] * 0.9 * s
    back_h = top[None, :] - rise[None, :] * (s ** 0.8) * (0.7 + 0.25 * noise.fbm(cx[None, :] * d / 60.0, cz[None, :] * d / 60.0, s * 3.0))
    back_h = np.minimum(back_h, top[None, :] - 0.5)
    rho_all = np.vstack([rho, back_rho])
    h_all = np.vstack([h, back_h])
    wet = flow(h_all)
    up = ((h_all - cloud) / (top - cloud).clip(1.0)[None, :]).clip(0.0, 1.0)
    pts3 = np.stack([cx[None, :] * rho_all, h_all, cz[None, :] * rho_all], axis=-1)
    mask = np.stack([wet, up], axis=-1)
    up = lambda p: Vector((0.0, 0.0, 1.0))  # noqa: E731
    name = "Range%d" % rng_spec["index"]
    return grid_object(name, pts3, mask, up), lighter(name, pts3, mask, up)


# ------------------------------------------------------------------ the cliffs

CLIFF_SEGMENTS = 128
CLIFF_LEVELS = 150
CAP_FLAT = 0.8   # the share of the top's radius kept flat for the buildings


def build_cliff(spec, cl):
    noise = Noise(cl["seed"])
    cxz = np.array(cl["centre"])
    top, foot, R = cl["top"], cl["foot"], cl["radius"]
    toward = math.atan2(cl["toward"][0], cl["toward"][1])
    a = -2 * math.pi * np.arange(CLIFF_SEGMENTS) / CLIFF_SEGMENTS
    t = np.linspace(0.0, 1.0, CLIFF_LEVELS)
    y = top + (foot - top) * t
    A, T = np.meshgrid(a, t)
    Y = top + (foot - top) * T
    dx, dz = np.sin(A), np.cos(A)
    r = R * (1.0 + 0.55 * T * T)
    ox, oz = cxz[0] / 50.0, cxz[1] / 50.0
    lobes = noise.fbm(dx * 1.1 + ox, dz * 1.1 + oz, Y / 60.0, octaves=2)
    lumps = noise.fbm(dx * R / 9.0 + ox, dz * R / 9.0 + oz, Y / 14.0, octaves=5)
    r = r * (1.0 + 0.28 * lobes + 0.12 * lumps)
    fissures = noise.ridged(dx * R / 5.0 + ox, dz * R / 5.0 + oz, Y / 45.0, octaves=3)
    r = r * (1.0 - 0.14 * fissures ** 3)
    band = 5.5 * (1.0 + 0.3 * noise(dx * 0.7, dz * 0.7, 3.3))
    q = (top - Y) / band + 0.3 * noise(dx * 2.0 + ox, dz * 2.0 + oz, 9.1)
    ledge = smoothstep(0.72, 0.95, q - np.floor(q)) * smoothstep(-0.05, 0.4, noise(dx * 1.6 + ox, dz * 1.6, Y / 9.0))
    r = r * (1.0 + 0.08 * ledge - 0.02)
    lip = smoothstep(4.0, 0.0, top - Y)
    r = r * (1.0 + 0.05 * lip)
    if cl["waterfall"]:
        near = smoothstep(math.cos(math.radians(14.0)), math.cos(math.radians(5.0)), np.cos(A - toward))
        r = r * (1.0 - 0.1 * near * smoothstep(26.0, 6.0, top - Y))
    # the top keeps at least 0.9 of the radius, so the buildings stand on it
    r = np.maximum(r, R * 0.9 * smoothstep(top - 6.0, top - 1.0, Y))
    pts = np.stack([cxz[0] + dx * r, Y, cxz[1] + dz * r], axis=-1)
    # the top: rings in from the rim to the flat out to CAP_FLAT, at the top
    rim_r = r[0, :]
    cap_rows = []
    for share, drop in ((0.97, 0.15), (0.9, 0.05), (CAP_FLAT, 0.0), (0.55, 0.0), (0.3, 0.0)):
        cap_rows.append(np.stack([cxz[0] + dx[0] * rim_r * share, np.full(CLIFF_SEGMENTS, top - drop),
                                  cxz[1] + dz[0] * rim_r * share], axis=-1))
    pts[0, :, 1] = top - 0.45
    grid = np.vstack([np.array(cap_rows[::-1]), pts])
    wet_side = fissures ** 2 * 0.8 + (1.0 - ledge) * 0.2
    up_side = 1.0 - T
    mask_side = np.stack([wet_side, up_side], axis=-1)
    mask_cap = np.zeros((len(cap_rows), CLIFF_SEGMENTS, 2))
    mask_cap[..., 1] = 1.0
    mask = np.vstack([mask_cap, mask_side])
    centre = (np.array([cxz[0], top, cxz[1]]), np.array([[0.0, 1.0]]))
    axis = g(cxz[0], 0.0, cxz[1])
    out = lambda p: Vector((p.x - axis.x, p.y - axis.y, 0.0))  # noqa: E731
    name = "Cliff%d" % cl["index"]
    # the lighter twin keeps every cap row (the top stays whole and flat)
    n_cap = len(cap_rows)
    side_rows = list(range(n_cap, grid.shape[0], 2))
    keep = list(range(n_cap)) + side_rows
    low = grid_object(name + "_Low", grid[keep][:, ::2], mask[keep][:, ::2], out, cap=centre)
    return grid_object(name, grid, mask, out, cap=centre), low


# ------------------------------------------------------------------ preview

def preview(path, moon, yaw_deg, pitch_deg=4.0):
    """A quick render (not shipped) from the shrine's floor, 3 m up, yaw_deg
    from the moon round to the right, under a moonlight from the moon."""
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 18.0
    cam_data.clip_end = 5000.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = g(0.0, 3.0, 0.0)
    yaw = math.atan2(moon[0], moon[2]) + math.radians(yaw_deg)
    look = g(math.sin(yaw), math.sin(math.radians(pitch_deg)), math.cos(yaw))
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun_data = bpy.data.lights.new("PreviewMoon", "SUN")
    sun_data.energy = 2.5
    sun = bpy.data.objects.new("PreviewMoon", sun_data)
    sun.rotation_euler = (-g(*moon)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.03, 0.035, 0.06, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 700
    scene.cycles.samples = 24
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in (cam, sun):
        bpy.data.objects.remove(o, do_unlink=True)


# ------------------------------------------------------------------ main

def main():
    a = args()
    with open(a["spec"], encoding="utf-8") as f:
        spec = json.load(f)
    shrine = os.path.join(a["assets"], "blender", "shrine")
    reset()
    body = flat_material("Landscape", (0.18, 0.18, 0.2), 0.9)
    objects = []
    for ob, low in [build_range(spec, rs) for rs in spec["ranges"]] + [build_cliff(spec, cl) for cl in spec["cliffs"]]:
        for o in (ob, low):
            o.data.materials.append(body)
        objects += [ob, low]
        print(f"build_shrine_landscape: {ob.name} {len(ob.data.polygons)} faces, {low.name} {len(low.data.polygons)}", flush=True)
    if a["preview"]:
        os.makedirs(a["preview"], exist_ok=True)
        for o in objects:
            o.hide_render = o.name.endswith("_Low")
        for yaw in (0, 90, 180, 270):
            preview(os.path.join(a["preview"], f"landscape_{yaw}.png"), spec["moon"], yaw)
        for o in objects:
            o.hide_render = False
    save(os.path.join(shrine, "landscape.blend"), objects)
    print("build_shrine_landscape: landscape -> blender/shrine/landscape.blend", flush=True)


if __name__ == "__main__":
    main()
