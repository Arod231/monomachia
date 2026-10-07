# Runs inside Blender (headless): the Blender ends of a clip's trip through
# Cascadeur (milestone-1 task 59; scripts/cascadeur/key-clip.mjs drives it).
#
#   out:  blender -b <block-out.blend> --factory-startup --python-exit-code 1 \
#           --python scripts/blender/casc_roundtrip.py -- --out <block-out.glb>
#     the block-out (rekey_clip.py's source) as a GLB keyed on every frame of
#     every channel, frames 1 on at their own times, for Cascadeur's import:
#     the game's export writes a channel that never changes as two step keys,
#     which Cascadeur reads as the rest pose between them (the hands-on test).
#
#   back: blender -b <block-out.blend> --factory-startup --python-exit-code 1 \
#           --python scripts/blender/casc_roundtrip.py -- --casc <cascadeur.glb> --save <source.blend>
#     the block-out with its body's motion replaced by Cascadeur's: every
#     bone of the body (the hips, spine, neck, head, shoulders, arms and
#     legs) takes its local pose from the Cascadeur export, frame k of it
#     onto the block-out's frame 1 + k (Cascadeur exports from its frame 1 at
#     0 s); the fingers, the hand props, the root, the spine proxy and the jaw
#     keep the block-out's (Cascadeur's rig drives no prop, and its fingers
#     drift where no key holds them). Saved as the clip's source, which the
#     export then turns into the game's GLB.

import sys

import bpy

# The bones Cascadeur's rig drives (scripts/cascadeur/humanm.qrigcasc's body,
# arms and legs); every other bone keeps the block-out's keys.
BODY = ["B-hips", "B-spine", "B-chest", "B-neck", "B-head"] + [
    f"B-{b}.{s}" for s in ("L", "R") for b in ("shoulder", "upperArm", "forearm", "hand", "thigh", "shin", "foot", "toe")
]


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"out": None, "casc": None, "save": None}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key not in out or i + 1 >= len(argv):
            raise SystemExit(f"casc_roundtrip: unknown or empty argument {argv[i]}")
        out[key] = argv[i + 1]
        i += 2
    if not out["out"] and not (out["casc"] and out["save"]):
        raise SystemExit("casc_roundtrip: needs --out, or --casc and --save")
    return out


def armature():
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def export_full(arm, path):
    for o in bpy.context.view_layer.objects:
        o.select_set(o == arm)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
        export_apply=False,
        export_optimize_animation_size=False,
        export_force_sampling=True,
        export_anim_slide_to_zero=False,
    )
    print(f"casc_roundtrip: wrote {path}", flush=True)


def rest_world(arm, names):
    """Each bone's world matrix in its armature's rest pose."""
    saved = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    out = {n: arm.matrix_world @ arm.pose.bones[n].matrix for n in names}
    for pb in arm.pose.bones:
        pb.matrix_basis = saved[pb.name]
    bpy.context.view_layer.update()
    return out


def merge(arm, casc, save):
    """Cascadeur's body motion onto the block-out. The two armatures share
    the clip skeleton's rest pose but not their bones' axes (the FBX and the
    glTF importers orient bones differently), so each bone carries its move
    from rest in the world: Cascadeur's bone at frame f is D @ its rest, and
    the block-out's is set to D @ its own rest."""
    scene = bpy.context.scene
    action = arm.animation_data.action
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=casc)
    imported = [o for o in bpy.data.objects if o not in before]
    src = next(o for o in imported if o.type == "ARMATURE")
    src_action = src.animation_data.action
    first, last = (int(round(x)) for x in src_action.frame_range)
    arm.animation_data.action = None
    src_rest = rest_world(src, BODY)
    dst_rest = rest_world(arm, BODY)
    moves = []
    for f in range(first, last + 1):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        moves.append({n: (src.matrix_world @ src.pose.bones[n].matrix) @ src_rest[n].inverted() for n in BODY})
    arm.animation_data.action = action
    # drop the block-out's body keys, then key Cascadeur's (Blender 5's
    # layered actions keep a slot's curves in its channel bag)
    from bpy_extras import anim_utils
    bag = anim_utils.action_get_channelbag_for_slot(action, arm.animation_data.action_slot)
    for fc in list(bag.fcurves):
        if any(fc.data_path.startswith(f'pose.bones["{n}"].') for n in BODY):
            bag.fcurves.remove(fc)
    inv = arm.matrix_world.inverted()
    prev = {}
    for k, move in enumerate(moves):
        scene.frame_set(1 + k)
        for n in BODY:
            pb = arm.pose.bones[n]
            pb.rotation_mode = "QUATERNION"
            pb.matrix = inv @ move[n] @ dst_rest[n]
            bpy.context.view_layer.update()
            rot = pb.rotation_quaternion.copy()
            if n in prev and prev[n].dot(rot) < 0:
                rot = -rot
                pb.rotation_quaternion = rot
            prev[n] = rot
            pb.keyframe_insert("location", frame=1 + k, group=n)
            pb.keyframe_insert("rotation_quaternion", frame=1 + k, group=n)
            pb.keyframe_insert("scale", frame=1 + k, group=n)
    for o in imported:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a != action:
            bpy.data.actions.remove(a)
    scene.frame_start, scene.frame_end = 1, len(moves)
    bpy.ops.wm.save_as_mainfile(filepath=save, compress=False)
    print(f"casc_roundtrip: {len(moves)} frames from {casc} into {save}", flush=True)


def main():
    a = args()
    arm = armature()
    if a["out"]:
        export_full(arm, a["out"])
    else:
        merge(arm, a["casc"], a["save"])


main()
