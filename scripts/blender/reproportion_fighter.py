# Runs inside Blender (headless): re-proportions a fighter's Quaternius parts
# (KE task 3, the spec's D10) into one Blender source per part in the asset
# repository, which scripts/blender/export.mjs then exports into the game.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/reproportion_fighter.py -- \
#     --spec scripts/blender/bodies/<fighter>.json --assets <asset repository>
#
# The spec (JSON) names the fighter, its parts (each a Quaternius glTF in the
# asset repository, by the name its source and export take), the part whose
# skeleton the game plays on (`reference`, which sets the shoulders' width)
# and the proportions: `scale` (every part, about the floor), `shoulders`
# (the shoulder joints' spread, by moving each clavicle out) and `head` (the
# head bone's size). Every part gets the same edits in metres, measured on the
# reference, so they still fit one skeleton. Each edit is posed on the part's
# armature, baked into its meshes and made the armature's rest pose, so the
# part exports with its rig as before, only re-proportioned.

import json
import os
import shutil
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"spec": None, "assets": None}
    for i in range(0, len(argv) - 1, 2):
        key = argv[i].lstrip("-")
        if key not in out:
            raise SystemExit(f"reproportion_fighter: unknown argument {argv[i]}")
        out[key] = argv[i + 1]
    if not out["spec"] or not out["assets"]:
        raise SystemExit("reproportion_fighter: needs --spec and --assets")
    return out


def ints(x):
    """Integral floats as ints: some glTF writers store indices as 3.0,
    which Blender's importer refuses."""
    if isinstance(x, float) and x.is_integer():
        return int(x)
    if isinstance(x, list):
        return [ints(v) for v in x]
    if isinstance(x, dict):
        return {k: ints(v) for k, v in x.items()}
    return x


def import_part(path):
    """Imports a glTF into the empty scene, from a copy whose integral floats
    are ints, its buffers and images beside it."""
    tmp = tempfile.mkdtemp()
    with open(path, encoding="utf-8") as f:
        data = ints(json.load(f))
    here = os.path.dirname(path)
    for ref in [b.get("uri") for b in data.get("buffers", [])] + [i.get("uri") for i in data.get("images", [])]:
        if ref and os.path.exists(os.path.join(here, ref)):
            dest = os.path.join(tmp, ref)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy(os.path.join(here, ref), dest)
    copy = os.path.join(tmp, os.path.basename(path))
    with open(copy, "w", encoding="utf-8") as f:
        json.dump(data, f)
    bpy.ops.import_scene.gltf(filepath=copy)
    # the images point at the asset repository's files, not the copies, and
    # aren't packed into the source (the importer packs them)
    for img in bpy.data.images:
        p = bpy.path.abspath(img.filepath)
        if p.startswith(tmp):
            img.filepath = os.path.join(here, os.path.relpath(p, tmp))
        if img.packed_file:
            img.unpack(method="REMOVE")


def armature():
    found = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(found) != 1:
        raise SystemExit(f"reproportion_fighter: {len(found)} armatures in a part, not one")
    return found[0]


def shoulder_width(arm):
    bones = arm.data.bones
    return abs(bones["upperarm_l"].head_local.x - bones["upperarm_r"].head_local.x)


def select_only(objs, active):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active


def reproportion(arm, scale, spread, head):
    """Scales the part about the floor, moves each clavicle `spread` m out
    (along X) and scales the head by `head`, baking all of it into the rest
    pose and the meshes."""
    objs = list(bpy.context.view_layer.objects)
    for o in objs:
        if o.parent is None:
            o.matrix_world = Matrix.Scale(scale, 4) @ o.matrix_world
    select_only(objs, arm)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for side, sign in (("clavicle_l", 1.0), ("clavicle_r", -1.0)):
        bone = arm.data.bones[side]
        arm.pose.bones[side].location = bone.matrix_local.to_3x3().inverted() @ Vector((sign * spread, 0.0, 0.0))
    arm.pose.bones["Head"].scale = (head, head, head)
    bpy.context.view_layer.update()
    for mesh in [o for o in objs if o.type == "MESH"]:
        mods = [m for m in mesh.modifiers if m.type == "ARMATURE" and m.object == arm]
        if not mods:
            continue
        select_only([mesh], mesh)
        name = mods[0].name
        bpy.ops.object.modifier_apply(modifier=name)
        mod = mesh.modifiers.new(name, "ARMATURE")
        mod.object = arm
        mod.use_vertex_groups = True
        # the re-added modifier goes first, as the imported one was
        while mesh.modifiers[0] != mod:
            bpy.ops.object.modifier_move_up(modifier=name)
    select_only([arm], arm)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def main():
    a = args()
    with open(a["spec"], encoding="utf-8") as f:
        spec = json.load(f)
    parts = spec["parts"]
    scale = float(spec["scale"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import_part(os.path.join(a["assets"], parts[spec["reference"]]))
    width = shoulder_width(armature()) * scale
    spread = width * (float(spec["shoulders"]) - 1.0) / 2.0
    print(f"reproportion_fighter: {spec['fighter']}: shoulders {width:.4f} m apart after the scale, each clavicle {spread * 100:.2f} cm out", flush=True)
    out_dir = os.path.join(a["assets"], "blender", "bodies", spec["fighter"])
    os.makedirs(out_dir, exist_ok=True)
    for name, src in parts.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        import_part(os.path.join(a["assets"], src))
        reproportion(armature(), scale, spread, float(spec["head"]))
        out = os.path.join(out_dir, f"{name}.blend")
        bpy.ops.wm.save_as_mainfile(filepath=out, compress=True, relative_remap=True)
        print(f"reproportion_fighter: wrote blender/bodies/{spec['fighter']}/{name}.blend", flush=True)


main()
