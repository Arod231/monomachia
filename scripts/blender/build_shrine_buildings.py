# Runs inside Blender (headless): builds the Moonlit Shrine's buildings
# (milestone-1 task 132) as Blender sources in the asset repository, which
# scripts/blender/export.mjs then exports into the game.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/build_shrine_buildings.py -- \
#     --spec scripts/blender/shrine/buildings.json --assets <asset repository> \
#     [--only lantern,torii,pillar,pagoda,temple_hall] [--preview <folder>]
#
# Every piece is ancient (the owner's answers, Oct 8): stone chipped and
# cracked at its edges with moss and lichen in its crevices and on its tops,
# lacquer chipped to the grey wood, frayed straw rope. The near pieces are
# modelled, unwrapped and baked to textures of their own in Cycles from the
# CC0 scans in blender/shrine/textures/ (Poly Haven's rock_surface and
# mossy_rock for the stone, wood_peeling_paint_weathered under the torii's
# lacquer), so each exports with one base-colour, normal and roughness map;
# the far pieces wear the scans tiled (grey_roof_tiles, weathered_planks,
# rock_surface). Godot's axes throughout the comments: +y up, the pieces'
# fronts as the game places them.
#
# - shrine/lantern.blend: two Kasuga-doro ("Lantern0", "Lantern1", the same
#   shape weathered apart), each a hexagonal base, a round post with its
#   middle knot, a hexagonal middle platform, the fire box (rectangular
#   openings front and back toward -z and +z, a full moon and a deer cut
#   through its four other faces), a six-sided roof curling up at its corners
#   into scrolls, and the jewel finial; "<name>_Stone" (its own baked maps)
#   and "<name>_Paper" (the lit paper inside, round the fire 2.12 m up,
#   ShrineProps.LANTERN_FIRE). Origin at its foot.
# - shrine/torii.blend: a Myojin torii for the gates ("Torii"): vermilion
#   pillars on black feet, the tie beam through them with its wedges, the
#   vermilion lintel under the black, upswept top beam, the strut and its
#   plaque, all one mesh with baked maps ("Torii_Wood"); the shimenawa sagging
#   under the tie beam ("Torii_Rope", twisted straw) with paper shide
#   ("Torii_Paper"). Its passage runs along z, its pillars torii_span apart
#   on x, the top beam's top torii_height + 0.92 up. Origin at its foot.
# - shrine/pillar.blend: a whole pillar ("PillarWhole": "_Stone", its rope
#   "_Rope" and shide "_Paper") whole_height tall, and a broken one
#   ("PillarBroken_Stone", its shaft snapped broken_height up, the fallen
#   drum beside it), both on a square plinth. Origin at the foot; the game
#   scales each to its height.
# - shrine/pagoda.blend and shrine/temple_hall.blend: a five-storey pagoda
#   ("Pagoda") and a temple hall ("TempleHall"), each with its lit windows
#   apart ("_Window"), modelled 1 m wide (ShrineLayout's convention for a
#   far building, which the backdrop scales to its cliff): stone bases,
#   weathered timber, grey tiled roofs flaring up at the eaves, brackets,
#   railings and the pagoda's spire.
# - shrine/paving.blend (milestone-1 task 49): the paving's scans for the
#   floor's shader, a card each: "Paving_Stone" (rock_surface) and
#   "Paving_Grime" (concrete_moss, for the joints' moss and grime).

import json
import math
import os
import random
import sys
import tempfile

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

# ------------------------------------------------------------------ arguments

def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"spec": None, "assets": None, "only": None, "preview": None}
    for i in range(0, len(argv) - 1, 2):
        key = argv[i].lstrip("-")
        if key not in out:
            raise SystemExit(f"build_shrine_buildings: unknown argument {argv[i]}")
        out[key] = argv[i + 1]
    if not out["spec"] or not out["assets"]:
        raise SystemExit("build_shrine_buildings: needs --spec and --assets")
    return out


# ------------------------------------------------------------------ axes and meshes

def g(x, y, z):
    """A point in Godot's axes (+y up, +z toward the viewer) as Blender's
    (+z up): the glTF export turns Blender's (x, y, z) into (x, z, -y)."""
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "OPTIX"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception:  # no GPU: the CPU bakes too, slower
        scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.unit_settings.scale_length = 1.0


def obj_from_bm(name, bm, collection=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    return ob


def lathe(bm, profile, segments, matrix=Matrix(), shape=None, cap_bottom=True, cap_top=True):
    """A solid of revolution round Blender's z: profile is [(radius, z)]
    from the bottom up. shape(angle) scales the radius by angle (a hexagon,
    say), and the profile's radius 0 ends close in a point."""
    rings = []
    for r, z in profile:
        ring = []
        for k in range(segments):
            a = 2.0 * math.pi * k / segments
            s = shape(a) if shape else 1.0
            ring.append(bm.verts.new(matrix @ Vector((math.cos(a) * r * s, math.sin(a) * r * s, z))))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segments):
            k1 = (k + 1) % segments
            try:
                bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
            except ValueError:
                pass
    if cap_bottom:
        try:
            bm.faces.new(list(reversed(rings[0])))
        except ValueError:
            pass
    if cap_top:
        try:
            bm.faces.new(rings[-1])
        except ValueError:
            pass
    return rings


def hexagon(a):
    """A hexagon's radius at angle a, corners at 0, 60, 120... degrees, as a
    share of its corner radius."""
    sector = math.pi / 3.0
    t = (a % sector) - sector * 0.5
    return math.cos(sector * 0.5) / math.cos(t)


def box(bm, centre, size, matrix=Matrix()):
    m = matrix @ Matrix.Translation(centre) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def cylinder(bm, centre, r0, r1, height, segments=24, matrix=Matrix()):
    lathe(bm, [(r0, 0.0), (r1, height)], segments, matrix @ Matrix.Translation(centre))


def prism_cut(name, outline, depth, matrix):
    """A cutter: the 2D outline (x, y pairs) extruded depth along its local z
    and placed by matrix, for a boolean."""
    bm = bmesh.new()
    lo = [bm.verts.new(Vector((x, y, -depth * 0.5))) for x, y in outline]
    hi = [bm.verts.new(Vector((x, y, depth * 0.5))) for x, y in outline]
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(name, bm)
    ob.matrix_world = matrix
    return ob


def boolean(target, cutters, op="DIFFERENCE"):
    for c in cutters:
        mod = target.modifiers.new("cut", "BOOLEAN")
        mod.operation = op
        mod.solver = "EXACT"
        mod.object = c
        apply_modifiers(target)
        bpy.data.objects.remove(c, do_unlink=True)


def apply_modifiers(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def join(name, obs):
    """One object of obs's meshes, named name."""
    bm = bmesh.new()
    for ob in obs:
        me = ob.data.copy()
        me.transform(ob.matrix_world)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        bpy.data.objects.remove(ob, do_unlink=True)
    return obj_from_bm(name, bm)


def weather_stone(ob, voxel, seed, chips, chip_size, roughen):
    """Weathers a stone object: knocks chips out of it (`chips` balls of
    about chip_size at random spots near its edges), fuses it into one
    watertight surface (a voxel remesh), roughens it with noise and settles
    it to a sensible face count."""
    rnd = random.Random(seed)
    me = ob.data
    edges = [e for e in me.edges]
    cutters = []
    if edges and chips > 0:
        # edges sharp enough to chip: the boundary between faces bent by more
        # than 50 degrees
        bm = bmesh.new()
        bm.from_mesh(me)
        sharp = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(50)]
        picks = [((e.verts[0].co.lerp(e.verts[1].co, rnd.random()))) for e in rnd.sample(sharp, min(chips, len(sharp)))] if sharp else []
        bm.free()
        for i, at in enumerate(picks):
            cbm = bmesh.new()
            bmesh.ops.create_icosphere(cbm, subdivisions=2, radius=chip_size * rnd.uniform(0.5, 1.2))
            for v in cbm.verts:
                v.co.x *= rnd.uniform(0.6, 1.4)
                v.co.y *= rnd.uniform(0.6, 1.4)
                v.co.z *= rnd.uniform(0.5, 1.0)
            c = obj_from_bm(f"chip{i}", cbm)
            c.matrix_world = ob.matrix_world @ Matrix.Translation(at) @ Matrix.Rotation(rnd.random() * 6.28, 4, Vector((rnd.random(), rnd.random(), rnd.random())).normalized())
            cutters.append(c)
    remesh = ob.modifiers.new("fuse", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.use_smooth_shade = True
    apply_modifiers(ob)
    for c in cutters:
        _chip(ob, c)
    # roughen: small displacement along the normals by a noise of its own
    off = Vector((seed * 17.31, seed * 3.7, seed * 11.1))
    for v in ob.data.vertices:
        p = v.co * 9.0 + off
        n = noise.noise(p) * 0.6 + noise.noise(p * 3.1) * 0.3 + noise.noise(p * 9.7) * 0.1
        v.co += v.normal * n * roughen
    dec = ob.modifiers.new("settle", "DECIMATE")
    dec.ratio = min(1.0, 60000.0 / max(len(ob.data.polygons), 1))
    apply_modifiers(ob)
    for p in ob.data.polygons:
        p.use_smooth = True


def _chip(ob, cutter):
    """Knocks cutter out of ob, unless the cut goes wrong (an exact boolean
    can lose the whole surface on a fused mesh): then ob is left as it was."""
    before = ob.data.copy()
    size = Vector(ob.dimensions)
    faces = len(ob.data.polygons)
    boolean(ob, [cutter])
    broken = len(ob.data.polygons) < faces * 0.8 or (Vector(ob.dimensions) - size).length > 0.01
    if broken:
        old = ob.data
        ob.data = before
        bpy.data.meshes.remove(old)
    else:
        bpy.data.meshes.remove(before)


def unwrap(ob, margin=0.004):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


# ------------------------------------------------------------------ materials

class Scans:
    """The CC0 scans in blender/shrine/textures/, loaded once each."""

    def __init__(self, folder):
        self.folder = folder
        self.cache = {}

    def image(self, scan, kind):
        key = (scan, kind)
        if key not in self.cache:
            path = os.path.join(self.folder, f"{scan}_{kind}_2k.jpg")
            img = bpy.data.images.load(path, check_existing=True)
            if kind != "diff":
                img.colorspace_settings.name = "Non-Color"
            self.cache[key] = img
        return self.cache[key]


def node(tree, kind, x, y, **props):
    n = tree.nodes.new(kind)
    n.location = (x, y)
    for k, v in props.items():
        setattr(n, k, v)
    return n


def scan_nodes(tree, scans, scan, mapping, x, y, blend=0.25):
    """Box-projected nodes of a scan's colour, roughness and normal, read at
    mapping's coordinates: (colour socket, roughness socket, normal socket)."""
    out = []
    for i, kind in enumerate(("diff", "rough", "nor_gl")):
        t = node(tree, "ShaderNodeTexImage", x, y - i * 280, image=scans.image(scan, kind), projection="BOX",
                 projection_blend=blend)
        tree.links.new(mapping, t.inputs["Vector"])
        out.append(t)
    nmap = node(tree, "ShaderNodeNormalMap", x + 300, y - 560)
    tree.links.new(out[2].outputs["Color"], nmap.inputs["Color"])
    return out[0].outputs["Color"], out[1].outputs["Color"], nmap.outputs["Normal"]


def stone_material(name, scans, spec, seed):
    """The weathered stone for baking: rock_surface, with mossy_rock's moss
    and lichen in the crevices (ambient occlusion) and on the tops (facing
    up), broken up by noise, and the crevices' grime."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    tex = node(tree, "ShaderNodeTexCoord", -1400, 0)
    mapping = node(tree, "ShaderNodeMapping", -1200, 0)
    mapping.inputs["Scale"].default_value = (spec["stone_scale"],) * 3
    mapping.inputs["Location"].default_value = (seed * 0.37, seed * 0.11, 0.0)
    tree.links.new(tex.outputs["Object"], mapping.inputs["Vector"])
    rc, rr, rn = scan_nodes(tree, scans, "rock_surface", mapping.outputs["Vector"], -900, 400)
    mc, mr, mn = scan_nodes(tree, scans, "mossy_rock", mapping.outputs["Vector"], -900, -500)
    # the moss: crevices, tops, broken up
    ao = node(tree, "ShaderNodeAmbientOcclusion", -900, -1300, samples=16)
    ao.inputs["Distance"].default_value = 0.12
    crevice = node(tree, "ShaderNodeMapRange", -650, -1300)
    crevice.inputs["From Min"].default_value = 0.95
    crevice.inputs["From Max"].default_value = 0.55
    tree.links.new(ao.outputs["AO"], crevice.inputs["Value"])
    geo = node(tree, "ShaderNodeNewGeometry", -900, -1600)
    sep = node(tree, "ShaderNodeSeparateXYZ", -700, -1600)
    tree.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    top = node(tree, "ShaderNodeMapRange", -500, -1600)
    top.inputs["From Min"].default_value = 0.55
    top.inputs["From Max"].default_value = 0.95
    top.inputs["To Max"].default_value = spec["moss_on_tops"]
    tree.links.new(sep.outputs["Z"], top.inputs["Value"])
    both = node(tree, "ShaderNodeMath", -300, -1450, operation="MAXIMUM")
    tree.links.new(crevice.outputs["Result"], both.inputs[0])
    tree.links.new(top.outputs["Result"], both.inputs[1])
    nz = node(tree, "ShaderNodeTexNoise", -700, -1900)
    nz.inputs["Scale"].default_value = 2.2
    nz.inputs["Detail"].default_value = 6.0
    tree.links.new(mapping.outputs["Vector"], nz.inputs["Vector"])
    breakup = node(tree, "ShaderNodeMapRange", -500, -1900)
    breakup.inputs["From Min"].default_value = 0.42
    breakup.inputs["From Max"].default_value = 0.62
    tree.links.new(nz.outputs["Fac"], breakup.inputs["Value"])
    moss = node(tree, "ShaderNodeMath", -100, -1500, operation="MULTIPLY", use_clamp=True)
    tree.links.new(both.outputs["Value"], moss.inputs[0])
    tree.links.new(breakup.outputs["Result"], moss.inputs[1])
    amount = node(tree, "ShaderNodeMath", 50, -1500, operation="MULTIPLY", use_clamp=True)
    amount.inputs[1].default_value = spec["moss"]
    tree.links.new(moss.outputs["Value"], amount.inputs[0])
    colour = node(tree, "ShaderNodeMix", 200, 300, data_type="RGBA")
    tree.links.new(amount.outputs["Value"], colour.inputs["Factor"])
    tree.links.new(rc, colour.inputs[6])
    tree.links.new(mc, colour.inputs[7])
    # the stone's own tone, cooler and darker than the scan, and the grime
    tint = node(tree, "ShaderNodeMix", 400, 300, data_type="RGBA", blend_type="MULTIPLY")
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs[7].default_value = tuple(spec["stone_tint"]) + (1.0,)
    tree.links.new(colour.outputs[2], tint.inputs[6])
    grime = node(tree, "ShaderNodeMix", 600, 300, data_type="RGBA", blend_type="MULTIPLY")
    grime_amt = node(tree, "ShaderNodeMapRange", 400, 0)
    grime_amt.inputs["From Min"].default_value = 1.0
    grime_amt.inputs["From Max"].default_value = 0.4
    grime_amt.inputs["To Max"].default_value = spec["grime"]
    tree.links.new(ao.outputs["AO"], grime_amt.inputs["Value"])
    tree.links.new(grime_amt.outputs["Result"], grime.inputs["Factor"])
    grime.inputs[7].default_value = (0.25, 0.24, 0.22, 1.0)
    tree.links.new(tint.outputs[2], grime.inputs[6])
    rough = node(tree, "ShaderNodeMix", 400, -200)
    tree.links.new(amount.outputs["Value"], rough.inputs["Factor"])
    tree.links.new(rr, rough.inputs[2])
    tree.links.new(mr, rough.inputs[3])
    normal = node(tree, "ShaderNodeMix", 400, -500, data_type="VECTOR")
    tree.links.new(amount.outputs["Value"], normal.inputs["Factor"])
    tree.links.new(rn, normal.inputs[4])
    tree.links.new(mn, normal.inputs[5])
    bsdf = node(tree, "ShaderNodeBsdfPrincipled", 900, 0)
    tree.links.new(grime.outputs[2], bsdf.inputs["Base Color"])
    tree.links.new(rough.outputs[0], bsdf.inputs["Roughness"])
    tree.links.new(normal.outputs[1], bsdf.inputs["Normal"])
    out = node(tree, "ShaderNodeOutputMaterial", 1200, 0)
    tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def flat_material(name, colour, roughness=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = tuple(colour) + (1.0,)
    bsdf.inputs["Roughness"].default_value = roughness
    return m


# ------------------------------------------------------------------ baking

def bake(ob, name, size, out_folder):
    """Bakes ob's materials into one base colour, normal and roughness map
    each (size pixels square) over its UVs, saves them beside the source as
    <name>_{diff,nor,rough}.png, and gives ob one material wearing them."""
    imgs = {}
    for kind in ("diff", "nor", "rough"):
        img = bpy.data.images.new(f"{name}_{kind}", size, size, alpha=False, float_buffer=False)
        if kind != "diff":
            img.colorspace_settings.name = "Non-Color"
        imgs[kind] = img
    targets = []
    for mat in {slot.material for slot in ob.material_slots if slot.material is not None}:
        tree = mat.node_tree
        t = tree.nodes.new("ShaderNodeTexImage")
        t.location = (1400, 600)
        targets.append((tree, t))
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    scene = bpy.context.scene
    scene.render.bake.margin = 8
    for kind, bake_type in (("diff", "DIFFUSE"), ("nor", "NORMAL"), ("rough", "ROUGHNESS")):
        for tree, t in targets:
            t.image = imgs[kind]
            tree.nodes.active = t
        kwargs = {"type": bake_type}
        if bake_type == "DIFFUSE":
            kwargs["pass_filter"] = {"COLOR"}
        scene.cycles.samples = 8 if bake_type != "DIFFUSE" else 32
        bpy.ops.object.bake(**kwargs)
        path = os.path.join(out_folder, f"{name}_{kind}.png")
        imgs[kind].filepath_raw = path
        imgs[kind].file_format = "PNG"
        imgs[kind].save()
    for tree, t in targets:
        tree.nodes.remove(t)
    final = bpy.data.materials.new(name)
    final.use_nodes = True
    tree = final.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    d = node(tree, "ShaderNodeTexImage", -700, 300, image=imgs["diff"])
    r = node(tree, "ShaderNodeTexImage", -700, 0, image=imgs["rough"])
    n = node(tree, "ShaderNodeTexImage", -700, -300, image=imgs["nor"])
    nm = node(tree, "ShaderNodeNormalMap", -350, -300)
    tree.links.new(d.outputs["Color"], bsdf.inputs["Base Color"])
    tree.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    tree.links.new(n.outputs["Color"], nm.inputs["Color"])
    tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    ob.data.materials.clear()
    ob.data.materials.append(final)
    return final


# ------------------------------------------------------------------ the Kasuga lantern

DEER = [(-0.38, -0.5), (-0.3, -0.05), (-0.42, 0.05), (-0.36, 0.2), (-0.15, 0.18), (0.2, 0.2), (0.32, 0.38),
        (0.28, 0.62), (0.4, 0.95), (0.45, 0.62), (0.52, 0.85), (0.5, 0.5), (0.42, 0.25), (0.5, 0.12),
        (0.36, 0.0), (0.3, -0.5), (0.2, -0.5), (0.22, -0.08), (-0.18, -0.08), (-0.26, -0.5)]


def circle(r, n=24):
    return [(math.cos(2 * math.pi * k / n) * r, math.sin(2 * math.pi * k / n) * r) for k in range(n)]


def lantern(spec, scans, variant, out_folder):
    """A Kasuga-doro: Blender objects <name>_Stone (baked) and <name>_Paper."""
    s = spec["lantern"]
    name = f"Lantern{variant}"
    seed = s["seeds"][variant]
    rnd = random.Random(seed)
    parts = []
    hexa = hexagon  # flats facing +-y (the game's -+z)

    def part(fn):
        bm = bmesh.new()
        fn(bm)
        ob = obj_from_bm("part", bm)
        parts.append(ob)
        return ob

    # the base: a hexagonal plinth and its lotus band
    part(lambda bm: lathe(bm, [(0.6, 0.0), (0.6, 0.16), (0.52, 0.2), (0.44, 0.22)], 6, shape=hexa))
    part(lambda bm: lathe(bm, [(0.42, 0.2), (0.38, 0.26), (0.27, 0.3), (0.2, 0.33)], 36,
                          shape=lambda a: 1.0 + 0.08 * abs(math.cos(a * 4.0))))
    # the post, its knot and rings
    part(lambda bm: lathe(bm, [(0.17, 0.3), (0.155, 0.34), (0.15, 0.86), (0.175, 0.88), (0.175, 0.93),
                               (0.15, 0.95), (0.135, 1.42), (0.15, 1.46)], 28))
    # the middle platform: a lotus bowl under a hexagonal slab
    part(lambda bm: lathe(bm, [(0.16, 1.44), (0.3, 1.52), (0.4, 1.6), (0.44, 1.66)], 36,
                          shape=lambda a: 1.0 + 0.06 * abs(math.cos(a * 4.0))))
    part(lambda bm: lathe(bm, [(0.5, 1.66), (0.52, 1.7), (0.5, 1.78)], 6, shape=hexa))
    # the fire box: six walls round the fire, the openings cut after
    fire = part(lambda bm: lathe(bm, [(0.37, 1.78), (0.37, 2.46)], 6, shape=hexa))
    inner = part(lambda bm: lathe(bm, [(0.3, 1.77), (0.3, 2.47)], 6, shape=hexa))
    parts.remove(fire)
    parts.remove(inner)
    boolean(fire, [inner])
    cutters = []
    apothem = 0.37 * math.cos(math.pi / 6.0)
    for k in range(6):
        a = math.pi / 2.0 + k * math.pi / 3.0  # face normals, starting at +y (the game's -z: the courtyard)
        rot = Matrix.Rotation(a - math.pi / 2.0, 4, "Z")
        place = rot @ Matrix.Translation(Vector((0.0, apothem, 2.12))) @ Matrix.Rotation(math.pi / 2.0, 4, "X")
        if k in (0, 3):
            outline = [(-0.13, -0.15), (0.13, -0.15), (0.13, 0.15), (-0.13, 0.15)]
        elif k in (1, 4):
            outline = circle(0.085)
        else:
            outline = [(x * 0.25 * (1 if k == 2 else -1), y * 0.25) for x, y in DEER]
            if k != 2:
                outline = list(reversed(outline))
        cutters.append(prism_cut("cut", outline, 0.3, place))
    boolean(fire, cutters)
    parts.append(fire)
    # the roof: six sides, concave, curling up at the corners into scrolls
    def roof(bm):
        prof = []
        for i in range(9):
            t = i / 8.0
            r = 0.82 * (1.0 - t) + 0.1 * t
            z = 2.5 + 0.34 * (t ** 1.6)
            prof.append((r, z))
        rings = lathe(bm, [(0.82, 2.46), (0.84, 2.5)] + prof[1:] + [(0.0, 2.86)], 6 * 12, shape=hexa,
                      cap_top=False)
        for ring in rings:
            for v in ring:
                r = Vector((v.co.x, v.co.y)).length
                a = math.atan2(v.co.y, v.co.x) - math.pi / 6.0
                corner = math.cos(((a % (math.pi / 3.0)) - math.pi / 6.0) * 3.0)
                corner = max(0.0, corner) ** 6
                v.co.z += 0.12 * corner * (r / 0.84) ** 4
    part(roof)
    for k in range(6):
        a = k * math.pi / 3.0
        # a scroll (warabite) curling up off each corner: a tapered stub out
        # of the tip and the rolled bud on it
        tip = Vector((math.cos(a) * 0.83, math.sin(a) * 0.83, 2.66))
        part(lambda bm, tip=tip, a=a: bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.045, radius2=0.03, depth=0.05,
            matrix=Matrix.Translation(tip) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(-0.6, 4, "Y") @ Matrix.Rotation(math.pi / 2.0, 4, "Y")))
        part(lambda bm, tip=tip, a=a: bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.05,
            matrix=Matrix.Translation(tip + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.05))) @ Matrix.Rotation(a, 4, "Z")
            @ Matrix.Diagonal((0.8, 0.55, 1.0, 1.0))))
    # the finial: a lotus cup and the jewel
    part(lambda bm: lathe(bm, [(0.0, 2.84), (0.12, 2.86), (0.14, 2.92), (0.1, 2.95), (0.07, 2.96), (0.11, 3.0),
                               (0.13, 3.06), (0.11, 3.13), (0.06, 3.2), (0.0, 3.27)], 24))
    stone = join(f"{name}_Stone", parts)
    weather_stone(stone, s["voxel"], seed, s["chips"], s["chip_size"], s["roughen"])
    stone.data.materials.clear()
    stone.data.materials.append(stone_material(f"{name}_StoneBake", scans, s["stone"], seed))
    unwrap(stone)
    bake(stone, f"{name}_Stone", s["texture_size"], out_folder)
    # the lit paper inside, round the fire
    bm = bmesh.new()
    lathe(bm, [(0.29, 1.82), (0.29, 2.42)], 6, shape=hexa, cap_bottom=False, cap_top=False)
    paper = obj_from_bm(f"{name}_Paper", bm)
    paper.data.materials.append(flat_material(f"{name}_Paper", s["paper"], 0.9))
    return [stone, paper]


# ------------------------------------------------------------------ swept shapes

def sweep_box(bm, points, half_w, half_h, matrix=Matrix()):
    """A box-section beam along points (Blender space), half_w across
    (horizontal, square to the path) and half_h up, its top facing +z."""
    corners = []
    n = len(points)
    for k in range(n):
        t = (points[min(k + 1, n - 1)] - points[max(k - 1, 0)]).normalized()
        up = (Vector((0, 0, 1)) - t * t.z).normalized()
        side = t.cross(up)
        p = points[k]
        corners.append([bm.verts.new(matrix @ (p + side * sx * half_w + up * sz * half_h))
                        for sx, sz in ((-1, -1), (-1, 1), (1, 1), (1, -1))])
    for k in range(n - 1):
        a, b = corners[k], corners[k + 1]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((a[i], b[i], b[j], a[j]))
    bm.faces.new(list(reversed(corners[0])))
    bm.faces.new(corners[-1])


def tube(bm, points, radii, segments=10):
    """A round tube along points with a radius at each."""
    rings = []
    n = len(points)
    for k in range(n):
        t = (points[min(k + 1, n - 1)] - points[max(k - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        v = t.cross(u)
        rings.append([bm.verts.new(points[k] + (u * math.cos(2 * math.pi * i / segments) + v * math.sin(2 * math.pi * i / segments)) * radii[k])
                      for i in range(segments)])
    for k in range(n - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def rope(bm, a, b, sag, thick, strands=3, twists=6.0, steps=48, fat_middle=True):
    """A twisted straw rope of strands from a to b, sagging by sag, thickest
    (thick) in the middle when fat_middle; returns the centre line."""
    centre = []
    for i in range(steps + 1):
        t = i / steps
        centre.append(a.lerp(b, t) - Vector((0, 0, sag * 4.0 * t * (1.0 - t))))
    along = (b - a).normalized()
    side = along.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(along)
    for s_i in range(strands):
        pts, radii = [], []
        for i, c in enumerate(centre):
            t = i / steps
            r = thick * ((1.0 - 0.55 * abs(2.0 * t - 1.0) ** 1.5) if fat_middle else 1.0)
            ang = 2.0 * math.pi * (twists * t + s_i / strands)
            pts.append(c + (side * math.cos(ang) + up * math.sin(ang)) * r * 0.45)
            radii.append(r * 0.62)
        tube(bm, pts, radii, 8)
    return centre


def shide(bm, top, facing, size=1.0):
    """A zigzag paper streamer (shide) hanging from top, its face square to
    facing (a level direction)."""
    side = facing.cross(Vector((0, 0, 1))).normalized()
    basis = Matrix((side, facing, Vector((0, 0, 1)))).transposed().to_4x4()
    for piece in range(4):
        off = side * (0.025 if piece % 2 == 0 else -0.025) * size
        centre = top + off - Vector((0, 0, (0.07 + piece * 0.12) * size))
        m = Matrix.Translation(centre) @ basis
        bmesh.ops.create_cube(bm, size=1.0, matrix=m @ Matrix.Diagonal((0.045 * size, 0.004, 0.125 * size, 1.0)))


# ------------------------------------------------------------------ the torii

def lacquer_material(name, scans, spec, paint):
    """The torii's lacquer for baking: paint (vermilion or black) over
    wood_peeling_paint_weathered, its dark paint read as ours and the bare
    wood showing grey through the chips, with grime in the crevices."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    tex = node(tree, "ShaderNodeTexCoord", -1400, 0)
    mapping = node(tree, "ShaderNodeMapping", -1200, 0)
    mapping.inputs["Scale"].default_value = (spec["wood_scale"],) * 3
    tree.links.new(tex.outputs["Object"], mapping.inputs["Vector"])
    wc, wr, wn = scan_nodes(tree, scans, "wood_peeling_paint_weathered", mapping.outputs["Vector"], -900, 300, 0.15)
    bw = node(tree, "ShaderNodeRGBToBW", -600, 500)
    tree.links.new(wc, bw.inputs["Color"])
    mask = node(tree, "ShaderNodeMapRange", -400, 500)
    mask.inputs["From Min"].default_value = spec["paint_from"][0]
    mask.inputs["From Max"].default_value = spec["paint_from"][1]
    tree.links.new(bw.outputs["Val"], mask.inputs["Value"])
    # the bare wood weathered grey
    grey = node(tree, "ShaderNodeHueSaturation", -450, 200)
    grey.inputs["Saturation"].default_value = 0.2
    grey.inputs["Value"].default_value = 1.6
    tree.links.new(wc, grey.inputs["Color"])
    wood = node(tree, "ShaderNodeMix", -300, 200, data_type="RGBA", blend_type="MULTIPLY")
    wood.inputs["Factor"].default_value = 1.0
    wood.inputs[7].default_value = tuple(spec["bare_wood"]) + (1.0,)
    tree.links.new(grey.outputs["Color"], wood.inputs[6])
    nz = node(tree, "ShaderNodeTexNoise", -600, -900)
    nz.inputs["Scale"].default_value = 3.0
    tree.links.new(mapping.outputs["Vector"], nz.inputs["Vector"])
    shade = node(tree, "ShaderNodeMapRange", -400, -900)
    shade.inputs["To Min"].default_value = 0.8
    shade.inputs["To Max"].default_value = 1.15
    tree.links.new(nz.outputs["Fac"], shade.inputs["Value"])
    comb = node(tree, "ShaderNodeCombineColor", -250, -900)
    for i in range(3):
        tree.links.new(shade.outputs["Result"], comb.inputs[i])
    paint_col = node(tree, "ShaderNodeMix", -100, -700, data_type="RGBA", blend_type="MULTIPLY")
    paint_col.inputs["Factor"].default_value = 1.0
    paint_col.inputs[6].default_value = tuple(paint) + (1.0,)
    tree.links.new(comb.outputs["Color"], paint_col.inputs[7])
    colour = node(tree, "ShaderNodeMix", 150, 200, data_type="RGBA")
    tree.links.new(mask.outputs["Result"], colour.inputs["Factor"])
    tree.links.new(wood.outputs[2], colour.inputs[6])
    tree.links.new(paint_col.outputs[2], colour.inputs[7])
    ao = node(tree, "ShaderNodeAmbientOcclusion", -300, -1200, samples=16)
    ao.inputs["Distance"].default_value = 0.2
    g_amt = node(tree, "ShaderNodeMapRange", 200, -1200)
    g_amt.inputs["From Min"].default_value = 1.0
    g_amt.inputs["From Max"].default_value = 0.4
    g_amt.inputs["To Max"].default_value = spec["grime"]
    tree.links.new(ao.outputs["AO"], g_amt.inputs["Value"])
    grime = node(tree, "ShaderNodeMix", 400, 200, data_type="RGBA", blend_type="MULTIPLY")
    tree.links.new(g_amt.outputs["Result"], grime.inputs["Factor"])
    grime.inputs[7].default_value = (0.2, 0.18, 0.16, 1.0)
    tree.links.new(colour.outputs[2], grime.inputs[6])
    rough = node(tree, "ShaderNodeMix", 150, -300)
    rough.inputs[3].default_value = spec["paint_roughness"]
    tree.links.new(mask.outputs["Result"], rough.inputs["Factor"])
    tree.links.new(wr, rough.inputs[2])
    bsdf = node(tree, "ShaderNodeBsdfPrincipled", 700, 0)
    tree.links.new(grime.outputs[2], bsdf.inputs["Base Color"])
    tree.links.new(rough.outputs[0], bsdf.inputs["Roughness"])
    tree.links.new(wn, bsdf.inputs["Normal"])
    out = node(tree, "ShaderNodeOutputMaterial", 1000, 0)
    tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def straw_material(name, spec):
    """Twisted straw for baking: bands along the strands, noise, darker in
    the twist's grooves."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    tex = node(tree, "ShaderNodeTexCoord", -1000, 0)
    wave = node(tree, "ShaderNodeTexWave", -750, 200, wave_type="BANDS", bands_direction="DIAGONAL")
    wave.inputs["Scale"].default_value = 60.0
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 4.0
    tree.links.new(tex.outputs["Object"], wave.inputs["Vector"])
    ramp = node(tree, "ShaderNodeValToRGB", -500, 200)
    ramp.color_ramp.elements[0].color = tuple(spec["straw_dark"]) + (1.0,)
    ramp.color_ramp.elements[1].color = tuple(spec["straw"]) + (1.0,)
    tree.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    ao = node(tree, "ShaderNodeAmbientOcclusion", -500, -200, samples=16)
    ao.inputs["Distance"].default_value = 0.05
    mul = node(tree, "ShaderNodeMix", -200, 100, data_type="RGBA", blend_type="MULTIPLY")
    mul.inputs["Factor"].default_value = 0.8
    tree.links.new(ramp.outputs["Color"], mul.inputs[6])
    tree.links.new(ao.outputs["Color"], mul.inputs[7])
    bump = node(tree, "ShaderNodeBump", -200, -300)
    bump.inputs["Strength"].default_value = 0.4
    tree.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    bsdf = node(tree, "ShaderNodeBsdfPrincipled", 100, 0)
    bsdf.inputs["Roughness"].default_value = 0.85
    tree.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    out = node(tree, "ShaderNodeOutputMaterial", 400, 0)
    tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def torii(spec, scans, out_folder):
    t = spec["torii"]
    h, span = t["height"], t["span"]
    half = span * 0.5
    red_parts, black_parts = [], []

    def part(fn, black=False):
        bm = bmesh.new()
        fn(bm)
        ob = obj_from_bm("part", bm)
        (black_parts if black else red_parts).append(ob)

    for sx in (-1.0, 1.0):
        x = half * sx
        part(lambda bm, x=x: lathe(bm, [(0.29, 0.0), (0.27, h * 0.5), (0.24, h + 0.2)], 28, Matrix.Translation((x, 0, 0))))
        # the black feet (kamaki) and the black ring under the lintel (daiwa)
        part(lambda bm, x=x: lathe(bm, [(0.37, 0.0), (0.37, 0.52), (0.35, 0.56), (0.31, 0.6)], 28,
                                   Matrix.Translation((x, 0, 0))), True)
        part(lambda bm, x=x: lathe(bm, [(0.3, h - 0.12), (0.33, h - 0.08), (0.33, h + 0.08), (0.3, h + 0.12)], 28,
                                   Matrix.Translation((x, 0, 0))), True)
        # the wedge (kusabi) where the tie beam passes the pillar
        part(lambda bm, x=x: box(bm, Vector((x + 0.34 * (1 if x > 0 else -1), 0, h * 0.76)), (0.08, 0.3, 0.46)))
    # the tie beam (nuki) through both pillars
    part(lambda bm: box(bm, Vector((0, 0, h * 0.76)), (span + 2.0, 0.26, 0.36)))

    # the lintel (shimaki) and the top beam (kasagi), both curving up to their ends
    def beam(reach, base_z, rise, n=21):
        return [Vector((x, 0.0, base_z + rise * (abs(x) / reach) ** 2.4))
                for x in [-reach + 2 * reach * i / (n - 1) for i in range(n)]]
    part(lambda bm: sweep_box(bm, beam(half + 1.45, h + 0.34, 0.25), 0.18, 0.16))
    part(lambda bm: sweep_box(bm, beam(half + 1.75, h + 0.68, 0.5), 0.24, 0.17), True)
    # the strut (gakuzuka) and the plaque (gaku) on it
    part(lambda bm: box(bm, Vector((0, 0, (h * 0.76 + h + 0.2) * 0.5)), (0.32, 0.22, h + 0.2 - h * 0.76)))
    part(lambda bm: box(bm, Vector((0, 0, (h * 0.76 + h + 0.2) * 0.5 + 0.02)), (0.72, 0.3, 0.98)), True)
    red = join("Torii_Red", red_parts)
    black = join("Torii_Black", black_parts)
    for ob in (red, black):
        bev = ob.modifiers.new("edge", "BEVEL")
        bev.width = 0.015
        bev.segments = 2
        bev.limit_method = "ANGLE"
        apply_modifiers(ob)
    red.data.materials.append(lacquer_material("ToriiVermilion", scans, t, t["vermilion"]))
    black.data.materials.append(lacquer_material("ToriiBlack", scans, t, t["black"]))
    wood = join_keep_materials("Torii_Wood", [red, black])
    for p_ in wood.data.polygons:
        p_.use_smooth = True
    unwrap(wood, 0.002)
    bake(wood, "Torii_Wood", t["texture_size"], out_folder)
    # the shimenawa under the tie beam, its frayed tassels, and its shide
    bm = bmesh.new()
    a = Vector((-half + 0.32, 0.0, h * 0.76 - 0.3))
    b = Vector((half - 0.32, 0.0, h * 0.76 - 0.3))
    centre = rope(bm, a, b, t["rope_sag"], t["rope_thick"])
    rnd = random.Random(5)
    for k in range(t["tassels"]):
        c = centre[int((k + 0.5) / t["tassels"] * (len(centre) - 1))]
        for f in range(5):
            top = c + Vector((rnd.uniform(-0.04, 0.04), rnd.uniform(-0.03, 0.03), -t["rope_thick"] * 0.5))
            tube(bm, [top, top + Vector((rnd.uniform(-0.02, 0.02), rnd.uniform(-0.02, 0.02), -rnd.uniform(0.25, 0.4)))],
                 [0.012, 0.003], 5)
    rope_ob = obj_from_bm("Torii_Rope", bm)
    rope_ob.data.materials.append(straw_material("ToriiStraw", t))
    for p_ in rope_ob.data.polygons:
        p_.use_smooth = True
    unwrap(rope_ob)
    bake(rope_ob, "Torii_Rope", 1024, out_folder)
    bm = bmesh.new()
    for k in range(t["shide"]):
        c = centre[int((k + 1) / (t["shide"] + 1) * (len(centre) - 1))]
        shide(bm, c - Vector((0, 0, t["rope_thick"] * 0.6)), Vector((0, 1, 0)), 1.6)
    paper = obj_from_bm("Torii_Paper", bm)
    paper.data.materials.append(flat_material("Torii_Paper", t["paper"], 0.9))
    return [wood, rope_ob, paper]


# ------------------------------------------------------------------ the pillars

def pillar(spec, scans, broken, out_folder):
    s = spec["pillar"]
    name = "PillarBroken" if broken else "PillarWhole"
    h = s["broken_height"] if broken else s["whole_height"]
    seed = s["seed_broken"] if broken else s["seed_whole"]
    rnd = random.Random(seed)
    parts = []

    def part(fn):
        bm = bmesh.new()
        fn(bm)
        parts.append(obj_from_bm("part", bm))

    part(lambda bm: box(bm, Vector((0, 0, 0.15)), (1.15, 1.15, 0.3)))
    part(lambda bm: lathe(bm, [(0.5, 0.3), (0.5, 0.36), (0.45, 0.42)], 32))
    if not broken:
        part(lambda bm: lathe(bm, [(0.44, 0.4), (0.43, h * 0.35), (0.4, h * 0.7), (0.38, h - 0.3)], 32))
        part(lambda bm: lathe(bm, [(0.4, h - 0.32), (0.46, h - 0.27), (0.46, h - 0.24)], 32))
        part(lambda bm: box(bm, Vector((0, 0, h - 0.12)), (1.0, 1.0, 0.24)))
    else:
        def shaft(bm):
            rings = lathe(bm, [(0.44, 0.4), (0.43, h * 0.5), (0.41, h - 0.3), (0.41, h)], 32, cap_top=False)
            top = rings[-1]
            for v in top:
                v.co.z += rnd.uniform(-0.35, 0.3)
            for v in rings[-2]:
                v.co.z += rnd.uniform(-0.12, 0.05)
            c = bm.verts.new(Vector((0, 0, h - 0.15)))
            for k in range(len(top)):
                bm.faces.new((top[k], top[(k + 1) % len(top)], c))
        part(shaft)
        # the fallen drum and a few broken pieces beside it
        ang = rnd.uniform(0, 2 * math.pi)
        at = Vector((math.cos(ang) * 1.45, math.sin(ang) * 1.45, 0.4))
        lie = Matrix.Translation(at) @ Matrix.Rotation(rnd.uniform(0, 6.28), 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X") \
            @ Matrix.Translation((0, 0, -0.55))
        part(lambda bm: lathe(bm, [(0.41, 0.0), (0.41, 1.1)], 28, lie))
        for k in range(3):
            pa = ang + rnd.uniform(-1.2, 1.2)
            dist = rnd.uniform(0.9, 2.0)
            size = rnd.uniform(0.1, 0.2)
            pc = Vector((math.cos(pa) * dist, math.sin(pa) * dist, 0.08))
            part(lambda bm, pc=pc, size=size: bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size,
                 matrix=Matrix.Translation(pc) @ Matrix.Diagonal((1.3, 1.0, 0.6, 1.0))))
    stone = join(f"{name}_Stone", parts)
    weather_stone(stone, s["voxel"], seed, s["chips"], s["chip_size"], s["roughen"])
    stone.data.materials.clear()
    stone.data.materials.append(stone_material(f"{name}_StoneBake", scans, s["stone_broken" if broken else "stone"], seed))
    unwrap(stone)
    bake(stone, f"{name}_Stone", s["texture_size"], out_folder)
    out = [stone]
    if not broken:
        ring_z = h * 0.62
        bm = bmesh.new()
        n = 40
        pts = [Vector((math.cos(2 * math.pi * k / n) * 0.47, math.sin(2 * math.pi * k / n) * 0.47, ring_z)) for k in range(n + 1)]
        for st in range(3):
            spts = []
            for k, p_ in enumerate(pts):
                ang = 2 * math.pi * (8 * k / n + st / 3)
                radial = Vector((p_.x, p_.y, 0)).normalized()
                spts.append(p_ + (radial * math.cos(ang) + Vector((0, 0, 1)) * math.sin(ang)) * 0.035)
            tube(bm, spts, [0.045] * len(spts), 7)
        rope_ob = obj_from_bm(f"{name}_Rope", bm)
        rope_ob.data.materials.append(straw_material(f"{name}Straw", spec["torii"]))
        for p_ in rope_ob.data.polygons:
            p_.use_smooth = True
        unwrap(rope_ob)
        bake(rope_ob, f"{name}_Rope", 1024, out_folder)
        bm = bmesh.new()
        for k in range(3):
            a = 2 * math.pi * (k + 0.2) / 3
            radial = Vector((math.cos(a), math.sin(a), 0))
            shide(bm, Vector((0, 0, ring_z - 0.04)) + radial * 0.5, radial, 1.1)
        paper = obj_from_bm(f"{name}_Paper", bm)
        paper.data.materials.append(flat_material(f"{name}_Paper", spec["torii"]["paper"], 0.9))
        out += [rope_ob, paper]
    return out


# ------------------------------------------------------------------ the far buildings

def tiled_material(name, scans, scan, tint=(1.0, 1.0, 1.0)):
    """A scan tiled over its UVs (which the builder lays at 2 m a tile), in
    tint."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    d = node(tree, "ShaderNodeTexImage", -800, 300, image=scans.image(scan, "diff"))
    r = node(tree, "ShaderNodeTexImage", -800, 0, image=scans.image(scan, "rough"))
    n = node(tree, "ShaderNodeTexImage", -800, -300, image=scans.image(scan, "nor_gl"))
    mix = node(tree, "ShaderNodeMix", -450, 300, data_type="RGBA", blend_type="MULTIPLY")
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs[7].default_value = tuple(tint) + (1.0,)
    nm = node(tree, "ShaderNodeNormalMap", -450, -300)
    tree.links.new(d.outputs["Color"], mix.inputs[6])
    tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    tree.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    tree.links.new(n.outputs["Color"], nm.inputs["Color"])
    tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def square(a):
    """A square's radius at angle a, corners at 45, 135... degrees, as a share
    of its half side."""
    return 1.0 / max(abs(math.cos(a)), abs(math.sin(a)))


def flared_roof(bm, half_w, half_d, base_z, height, flare, lift, sides_segments=12):
    """A hip roof over a half_w by half_d plan: concave sides (flare), its
    eaves' corners lifting by lift, with a thickness under its eaves."""
    prof = []
    steps = 8
    for i in range(steps + 1):
        t = i / steps
        prof.append((1.0 - t * 0.92, base_z + height * (t ** flare)))
    segs = 4 * sides_segments
    rings = []
    for r, z in prof:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * (k + 0.5) / segs
            sq = square(a)
            cx, cy = math.cos(a) * sq, math.sin(a) * sq
            corner = max(0.0, 1.0 - min(abs(abs(cx) - abs(cy)), 1.0)) ** 4
            ring.append(bm.verts.new(Vector((cx * half_w * r, cy * half_d * r, z + lift * corner * r ** 6))))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            k1 = (k + 1) % segs
            bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    top = bm.verts.new(Vector((0, 0, base_z + height * 1.02)))
    for k in range(segs):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % segs], top))
    under = [bm.verts.new(v.co - Vector((0, 0, 0.04 * half_w))) for v in rings[0]]
    for k in range(segs):
        k1 = (k + 1) % segs
        bm.faces.new((rings[0][k1], rings[0][k], under[k], under[k1]))
    bm.faces.new(list(reversed(under)))


def cube_uv(ob, tile=2.0):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=tile, scale_to_bounds=False, correct_aspect=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def join_keep_materials(name, obs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    obs[0].name = name
    obs[0].data.name = name
    return obs[0]


def far_piece(name, scans, groups, windows, width):
    """Joins groups ({material key: [objects]}) into one object named name
    with a material per scan, its UVs a tile every 2 m at full size, then
    scales it to 1 m wide; the windows are their own object."""
    mats = {
        "roof": lambda: tiled_material(f"{name}_Roof", scans, "grey_roof_tiles", (0.62, 0.64, 0.7)),
        "wood": lambda: tiled_material(f"{name}_Timber", scans, "weathered_planks", (0.8, 0.74, 0.68)),
        "stone": lambda: tiled_material(f"{name}_Stone", scans, "rock_surface", (0.75, 0.75, 0.78)),
        "red": lambda: tiled_material(f"{name}_Lacquer", scans, "wood_peeling_paint_weathered", (1.6, 0.35, 0.25)),
        "bronze": lambda: flat_material(f"{name}_Bronze", (0.12, 0.1, 0.08), 0.5),
    }
    pieces = []
    for key, obs in groups.items():
        if not obs:
            continue
        ob = join(f"{name}_{key}", obs)
        cube_uv(ob)
        ob.data.materials.append(mats[key]())
        pieces.append(ob)
    whole = join_keep_materials(name, pieces)
    win = join(f"{name}_Window", windows)
    win.data.materials.append(flat_material(f"{name}_Window", (1.0, 0.7, 0.4), 0.9))
    for ob in (whole, win):
        ob.data.transform(Matrix.Scale(1.0 / width, 4))
    return [whole, win]


def pagoda(spec, scans):
    s = spec["pagoda"]
    w0 = s["width"]
    g = {"roof": [], "wood": [], "stone": [], "red": [], "bronze": []}
    windows = []

    def add(key, fn):
        bm = bmesh.new()
        fn(bm)
        ob = obj_from_bm("part", bm)
        (windows if key == "window" else g[key]).append(ob)

    add("stone", lambda bm: box(bm, Vector((0, 0, 0.6)), (w0 * 1.3, w0 * 1.3, 1.2)))
    add("stone", lambda bm: box(bm, Vector((0, -w0 * 0.75, 0.3)), (w0 * 0.4, 0.6, 0.6)))
    z = 1.2
    for t_i in range(s["tiers"]):
        w = w0 * (1.0 - t_i * 0.12)
        storey = w0 * 0.36
        add("wood", lambda bm, w=w, z=z, storey=storey: box(bm, Vector((0, 0, z + storey * 0.5)), (w, w, storey)))
        for cx in (-1, 1):
            for cy in (-1, 1):
                add("red", lambda bm, w=w, z=z, storey=storey, cx=cx, cy=cy:
                    box(bm, Vector((cx * w * 0.5, cy * w * 0.5, z + storey * 0.5)), (0.22, 0.22, storey)))
        for k in range(4):
            a = k * math.pi / 2
            d = Vector((round(math.cos(a)), round(math.sin(a)), 0))
            add("window", lambda bm, d=d, w=w, z=z, storey=storey: box(bm, d * (w * 0.5 + 0.03) + Vector((0, 0, z + storey * 0.45)),
                (abs(d.y) * w * 0.28 + 0.06, abs(d.x) * w * 0.28 + 0.06, storey * 0.42)))
            # the balcony's railing
            add("red", lambda bm, d=d, w=w, z=z: box(bm, d * (w * 0.5 + 0.35) + Vector((0, 0, z + 0.55)),
                (abs(d.y) * (w + 0.8) + abs(d.x) * 0.08, abs(d.x) * (w + 0.8) + abs(d.y) * 0.08, 0.08)))
        # the balcony's floor round the storey
        add("wood", lambda bm, w=w, z=z: box(bm, Vector((0, 0, z + 0.06)), (w + 0.9, w + 0.9, 0.12)))
        z += storey
        # the brackets' band, the eaves and the roof
        add("wood", lambda bm, w=w, z=z: box(bm, Vector((0, 0, z + 0.2)), (w * 1.12, w * 1.12, 0.4)))
        add("roof", lambda bm, w=w, z=z: flared_roof(bm, w * 0.86, w * 0.86, z + 0.35, w0 * 0.2, 2.2, w0 * 0.12))
        z += w0 * 0.2 + 0.2
    # the spire: a pole, its nine rings and the jewel
    add("bronze", lambda bm: cylinder(bm, Vector((0, 0, z)), 0.12, 0.08, w0 * 0.9, 10))
    for r_i in range(9):
        add("bronze", lambda bm, r_i=r_i: lathe(bm, [(0.06, 0), (0.32, 0.03), (0.32, 0.08), (0.06, 0.1)], 16,
                                                  Matrix.Translation((0, 0, z + w0 * 0.12 + r_i * w0 * 0.07))))
    add("bronze", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.22,
                                                       matrix=Matrix.Translation((0, 0, z + w0 * 0.95))))
    return far_piece("Pagoda", scans, g, windows, w0)


def temple_hall(spec, scans):
    s = spec["temple_hall"]
    w, d = s["width"], s["depth"]
    g = {"roof": [], "wood": [], "stone": [], "red": [], "bronze": []}
    windows = []

    def add(key, fn):
        bm = bmesh.new()
        fn(bm)
        ob = obj_from_bm("part", bm)
        (windows if key == "window" else g[key]).append(ob)

    add("stone", lambda bm: box(bm, Vector((0, 0, 0.6)), (w * 1.15, d * 1.2, 1.2)))
    add("stone", lambda bm: box(bm, Vector((0, -d * 0.62, 0.3)), (w * 0.35, 0.9, 0.6)))
    wall_h = w * 0.26
    add("wood", lambda bm: box(bm, Vector((0, 0, 1.35)), (w * 1.06, d * 1.08, 0.3)))
    add("wood", lambda bm: box(bm, Vector((0, 0, 1.5 + wall_h * 0.5)), (w * 0.92, d * 0.88, wall_h)))
    n_front = 7
    for i in range(n_front):
        x = -w * 0.5 + w * i / (n_front - 1)
        for y in (-d * 0.5, d * 0.5):
            add("red", lambda bm, x=x, y=y: cylinder(bm, Vector((x, y, 1.5)), 0.2, 0.18, wall_h + 0.2, 10))
    for j in range(1, 4):
        y = -d * 0.5 + d * j / 4
        for x in (-w * 0.5, w * 0.5):
            add("red", lambda bm, x=x, y=y: cylinder(bm, Vector((x, y, 1.5)), 0.2, 0.18, wall_h + 0.2, 10))
    for i in range(1, n_front - 2):
        x = -w * 0.5 + w * (i + 0.5) / (n_front - 1)
        add("window", lambda bm, x=x: box(bm, Vector((x, -d * 0.44 - 0.03, 1.5 + wall_h * 0.45)),
                                          (w / (n_front - 1) * 0.6, 0.06, wall_h * 0.6)))
    # the bracket band, the roof's hipped lower part and its ridge
    add("wood", lambda bm: box(bm, Vector((0, 0, 1.5 + wall_h + 0.25)), (w * 1.02, d * 1.04, 0.5)))
    add("roof", lambda bm: flared_roof(bm, w * 0.72, d * 0.78, 1.5 + wall_h + 0.45, w * 0.26, 2.0, w * 0.06))
    ridge_z = 1.5 + wall_h + 0.45 + w * 0.26
    add("roof", lambda bm: box(bm, Vector((0, 0, ridge_z)), (w * 0.62, 0.5, 0.45)))
    for sx in (-1, 1):
        add("bronze", lambda bm, sx=sx: lathe(bm, [(0.25, 0.0), (0.18, 0.5), (0.05, 0.75)], 8,
                                               Matrix.Translation((sx * w * 0.31, 0, ridge_z + 0.2))))
    return far_piece("TempleHall", scans, g, windows, w)


def build_paving(spec, scans, baked):
    """The paving's scans for the floor's shader (milestone-1 task 49), as
    the wisteria's bark is brought: a card each in its scan's material,
    "Paving_Stone" (rock_surface) and "Paving_Grime" (concrete_moss, the moss
    and grime in the joints)."""
    objects = []
    for name, scan, x in (("Paving_Stone", "rock_surface", 0.0), ("Paving_Grime", "concrete_moss", 2.2)):
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0, matrix=Matrix.Translation((x, 0, 0)))
        ob = obj_from_bm(name, bm)
        ob.data.uv_layers.new(name="UVMap")
        for loop in ob.data.loops:
            co = ob.data.vertices[loop.vertex_index].co
            ob.data.uv_layers[0].data[loop.index].uv = ((co.x - x + 1.0) * 0.5, (co.y + 1.0) * 0.5)
        ob.data.materials.append(tiled_material(name, scans, scan))
        objects.append(ob)
    return objects, (5.0, 3.0, (1.1, 0.0, 0.0))


def build_torii(spec, scans, baked):
    return torii(spec, scans, baked), (11.0, 4.5, (0.0, 0.0, 4.0))


def build_pillars(spec, scans, baked):
    whole = pillar(spec, scans, False, baked)
    broken = pillar(spec, scans, True, baked)
    for o in broken:
        o.location = Vector((3.0, 0.0, 0.0))
    return whole + broken, (8.0, 3.5, (1.5, 0.0, 2.2))


def build_pagoda(spec, scans, baked):
    return pagoda(spec, scans), (7.0, 2.5, (0.0, 0.0, 1.9))


def build_temple_hall(spec, scans, baked):
    return temple_hall(spec, scans), (1.8, 0.7, (0.0, 0.0, 0.25))


# ------------------------------------------------------------------ saving

def save(path, objects):
    """Keeps only objects in the file, packs its images and saves it."""
    keep = set(objects)
    for ob in list(bpy.data.objects):
        if ob not in keep:
            bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            if item.users == 0:
                coll.remove(item)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)


def preview(path, objects, distance, height, look_at):
    """A quick render of objects for review (not shipped)."""
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = Vector((distance * 0.6, -distance, height))
    direction = Vector(look_at) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun_data = bpy.data.lights.new("PreviewSun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(30))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.world = world
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.cycles.samples = 48
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
    scans = Scans(os.path.join(shrine, "textures"))
    # the bakes are packed into each .blend; their loose files are scratch
    baked = tempfile.mkdtemp(prefix="shrine_bake_")
    only = set(a["only"].split(",")) if a["only"] else {"lantern", "torii", "pillar", "pagoda", "temple_hall", "paving"}
    builders = {"lantern": build_lanterns, "torii": build_torii, "pillar": build_pillars,
                "pagoda": build_pagoda, "temple_hall": build_temple_hall, "paving": build_paving}
    for key, fn in builders.items():
        if key not in only:
            continue
        reset()
        scans = Scans(os.path.join(shrine, "textures"))
        objects, look = fn(spec, scans, baked)
        if a["preview"]:
            os.makedirs(a["preview"], exist_ok=True)
            preview(os.path.join(a["preview"], f"{key}.png"), objects, *look)
        for o in objects:
            o.location = Vector((0.0, 0.0, 0.0))
        save(os.path.join(shrine, f"{key}.blend"), objects)
        print(f"build_shrine_buildings: {key} -> blender/shrine/{key}.blend", flush=True)


def build_lanterns(spec, scans, baked):
    objects = []
    for v in range(len(spec["lantern"]["seeds"])):
        obs = lantern(spec, scans, v, baked)
        for o in obs:
            o.location = Vector((v * 2.0, 0.0, 0.0))
        objects += obs
    return objects, (5.0, 2.4, (1.0, 0.0, 1.6))


if __name__ == "__main__":
    main()
