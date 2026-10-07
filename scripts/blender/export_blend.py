# Runs inside Blender (headless) for scripts/blender/export.mjs: exports the
# open .blend to one GLB (milestone-1 task 12). It refuses a clip or fighter
# source whose armature lacks the Kevin Iglesias rig's bones, since task 13's
# import retargets and mirrors those clips through the Iglesias bone map. A
# body part (KE task 3) goes out as a .gltf and its .bin, without images (the
# export keeps the original part's materials), and is refused without the
# Quaternius rig's bones (the bones given).
#
#   blender -b <source.blend> --factory-startup --python-exit-code 1 \
#     --python scripts/blender/export_blend.py -- --kind <clip|fighter|weapon|shrine|body|material> \
#     --out <file.glb, or file.gltf for a body> [--bones <bones.json>]
#
# Exit codes: 0 exported, 3 refused (the reason on a line starting
# "export_blend: refused:"); anything else is a Blender or script failure.

import json
import sys

import bpy

REFUSED = 3
# The kinds whose sources carry an armature (the Iglesias one, or a body
# part's Quaternius one), and whose exports keep their animations (only clips
# do; a fighter's motion comes from the clips).
RIGGED = {"clip", "fighter", "body"}
ANIMATED = {"clip"}


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"kind": None, "out": None, "bones": None}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key not in out or i + 1 >= len(argv):
            raise SystemExit(f"export_blend: unknown or empty argument {argv[i]}")
        out[key] = argv[i + 1]
        i += 2
    if out["kind"] not in {"clip", "fighter", "weapon", "shrine", "body", "material"} or not out["out"]:
        raise SystemExit("export_blend: needs --kind clip|fighter|weapon|shrine|body|material and --out")
    return out


def refuse(reason):
    print(f"export_blend: refused: {reason}", flush=True)
    sys.stdout.flush()
    # os._exit: a plain exit inside --python leaves Blender to decide the code
    import os
    os._exit(REFUSED)


def rig(bones, kind):
    """The armature holding every bone of the kind's rig, or a refusal naming
    the gap."""
    rig_name = "the Quaternius" if kind == "body" else "the Kevin Iglesias"
    armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not armatures:
        refuse("no armature (a clip or fighter is keyed on the Kevin Iglesias rig, a body part rigged on the Quaternius one)")
    best, missing = None, None
    for a in armatures:
        names = {b.name for b in a.data.bones}
        gap = [b for b in bones if b not in names]
        if missing is None or len(gap) < len(missing):
            best, missing = a, gap
    if missing:
        shown = ", ".join(missing[:6]) + (" and %d more" % (len(missing) - 6) if len(missing) > 6 else "")
        refuse(f"the armature {best.name} lacks {rig_name} rig's bones {shown}")
    return best


def main():
    a = args()
    bones = []
    if a["kind"] in RIGGED:
        if not a["bones"]:
            raise SystemExit("export_blend: a rigged kind needs --bones")
        with open(a["bones"], encoding="utf-8") as f:
            bones = json.load(f)
    armature = rig(bones, a["kind"]) if a["kind"] in RIGGED else None
    if a["kind"] in ANIMATED and not bpy.data.actions:
        refuse("a clip source has no action")
    options = dict(
        filepath=a["out"],
        export_format="GLB",
        export_animations=a["kind"] in ANIMATED,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
        export_apply=False,
        # the exporter times a key at its Blender frame / fps, so a clip keyed
        # from frame 1 (rekey_clip.py's sources) would start at 1/30 s, and
        # Godot's import would hold its first pose over frame 0: slid to 0 s,
        # a clip's frame k plays at k/30 s and it lasts its length/30 s
        export_anim_slide_to_zero=True,
    )
    if a["kind"] == "body":
        # the meshes, skin and skeleton; the game copy keeps the original
        # part's materials and its texture files
        options["export_format"] = "GLTF_SEPARATE"
        options["export_image_format"] = "NONE"
    if a["kind"] == "clip":
        # a clip is the armature and its motion, no meshes
        for o in bpy.context.view_layer.objects:
            o.select_set(o == armature)
        options["use_selection"] = True
    bpy.ops.export_scene.gltf(**options)
    print(f"export_blend: exported {bpy.data.filepath} to {a['out']}", flush=True)


main()
