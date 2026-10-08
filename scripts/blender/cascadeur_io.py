# Runs inside Blender (headless): the Blender half of the Cascadeur round trip
# (milestone-1 task 89 on; scripts/cascadeur/generate.mjs drives it). Two modes,
# each on the open .blend (a key-pose block-out rekey_clip.py wrote, on the
# Kevin Iglesias rig):
#
#   blender -b <keys.blend> --factory-startup --python-exit-code 1 \
#     --python scripts/blender/cascadeur_io.py -- --to <file.glb>
#   blender -b <keys.blend> --factory-startup --python-exit-code 1 \
#     --python scripts/blender/cascadeur_io.py -- --from <file.glb> --out <clip.blend>
#
# --to exports the armature and its motion for Cascadeur's import: every
# channel keyed on every frame (export_optimize_animation_size off, or
# Cascadeur keys a constant channel's two end frames and falls back to the
# rest pose between them, docs/research/cascadeur-python-api.md), slid to 0 s
# so the clip's frame k is Cascadeur's frame k.
#
# --from reads the clip Cascadeur generated (a GLB of the same skeleton, in
# metres, its frame k at k/30 s) back onto the block-out's own armature: each
# bone follows its namesake in the import in world space (copy-transforms
# constraints), baked on every frame from 1 as rekey_clip.py keys, the import
# deleted, and the source saved at --out (blender/clips/<clip>.blend), which
# the asset repository's sources.json lists and npm run export turns into the
# game's GLB.

import os
import sys

import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rekey_clip  # noqa: E402  (its legs_to(); it runs nothing on import)

FPS = 30


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"to": None, "from": None, "out": None}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key not in out or i + 1 >= len(argv):
            raise SystemExit(f"cascadeur_io: unknown or empty argument {argv[i]}")
        out[key] = argv[i + 1]
        i += 2
    if bool(out["to"]) == bool(out["from"]) or (out["from"] and not out["out"]):
        raise SystemExit("cascadeur_io: needs --to <glb>, or --from <glb> --out <blend>")
    return out


def armature():
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit(f"cascadeur_io: the block-out must hold one armature, not {len(arms)}")
    return arms[0]


def to_cascadeur(path):
    arm = armature()
    for o in bpy.context.view_layer.objects:
        o.select_set(o == arm)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_animations=True,
        export_optimize_animation_size=False, export_anim_slide_to_zero=True, export_force_sampling=True,
        export_extras=False, export_cameras=False, export_lights=False, export_apply=False)
    print(f"cascadeur_io: wrote {path}", flush=True)


def from_cascadeur(path, out):
    arm = armature()
    scene = bpy.context.scene
    scene.render.fps = FPS  # the glTF import times keys by the scene's fps
    length = int(round(arm.animation_data.action.frame_range[1])) - 1
    # the block-out's feet, which the generated clip is held to, and its
    # knees, which the legs bend toward (over the toes, or for a kick or a
    # pivot as its clip bends them; the generated clip's own can fall inside
    # the foot line)
    mw = arm.matrix_world
    feet0 = {}
    feet = {"L": [], "R": []}
    knees = {"L": [], "R": []}
    for n in range(length + 1):
        scene.frame_set(1 + n)
        bpy.context.view_layer.update()
        for side in ("L", "R"):
            m = mw @ arm.pose.bones["B-foot." + side].matrix
            if n == 0:
                feet0[side] = m.copy()
            feet[side].append((m.to_translation(), m.to_quaternion(), m.to_translation().z - feet0[side].to_translation().z))
            hip, knee = mw @ arm.pose.bones["B-thigh." + side].head, mw @ arm.pose.bones["B-shin." + side].head
            bend = knee - (hip + m.to_translation()) / 2
            knees[side].append(knee + (bend.normalized() if bend.length > 1e-4 else mathutils.Vector((0.0, -1.0, 0.0))) * 0.5)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    imported = [o for o in bpy.data.objects if o not in before]
    src = next((o for o in imported if o.type == "ARMATURE"), None)
    if src is None or not src.animation_data or not src.animation_data.action:
        raise SystemExit(f"cascadeur_io: {path} holds no animated armature")
    act = src.animation_data.action
    # the import keys its frame k (k/30 s) on Blender frame k; ours on k + 1
    f0, f1 = act.frame_range
    frames = int(round(f1 - f0))
    if frames != length:
        print(f"cascadeur_io: the import has {frames + 1} frames, the block-out {length + 1}", flush=True)
    names = {b.name for b in src.data.bones}
    for pb in arm.pose.bones:
        if pb.name not in names:
            continue
        c = pb.constraints.new("COPY_TRANSFORMS")
        c.name = "cascadeur_io"
        c.target, c.subtarget = src, pb.name
        c.target_space = c.owner_space = "WORLD"
    baked = []
    for n in range(length + 1):
        scene.frame_set(int(f0) + n)
        bpy.context.view_layer.update()
        baked.append({pb.name: arm.convert_space(pose_bone=pb, matrix=pb.matrix, from_space="POSE", to_space="LOCAL")
                      for pb in arm.pose.bones if pb.name in names})
    for pb in arm.pose.bones:
        for c in [c for c in pb.constraints if c.name == "cascadeur_io"]:
            pb.constraints.remove(c)
    old = arm.animation_data.action
    new = bpy.data.actions.new(old.name.replace("_rekeyed", "") + "_cascadeur")
    arm.animation_data.action = new
    prev_q = {}
    for n, frame in enumerate(baked):
        for name, m in frame.items():
            pb = arm.pose.bones[name]
            pb.rotation_mode = "QUATERNION"
            loc, rot, scl = m.decompose()
            if name in prev_q and prev_q[name].dot(rot) < 0:
                rot = -rot
            prev_q[name] = rot
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
            for p in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(p, frame=1 + n, group=name)
    bpy.data.actions.remove(old)
    for o in imported:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a != new:
            bpy.data.actions.remove(a)
    scene.frame_start, scene.frame_end = 1, 1 + length
    # AI inbetweening lets a planted foot drift a few centimetres between the
    # key poses; held to the block-out's feet (its steps and its plants, so
    # the travel the frame-data generator reads is the block-out's), the
    # knees bent as the block-out bends them
    over = rekey_clip.legs_to(arm, scene, length, feet, feet0, knees)
    if over:
        print(f"cascadeur_io: a planted foot is out of the leg's reach on {over}", flush=True)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=False)
    print(f"cascadeur_io: wrote {out} ({length + 1} frames)", flush=True)


def main():
    a = args()
    if a["to"]:
        to_cascadeur(a["to"])
    else:
        from_cascadeur(a["from"], a["out"])


main()
