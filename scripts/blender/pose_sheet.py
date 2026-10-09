# Runs inside Blender (headless): renders a clip source's frames on the pack's
# HumanM body, to judge key poses while keying (milestone-1 task 59). Picture
# only, never committed (the body is a Kevin Iglesias pack's).
#
#   blender -b --factory-startup --python-exit-code 1 --python scripts/blender/pose_sheet.py -- \
#     --clip <source.blend> --body <pack clip .fbx with the body> --frames 0,5,10 --out <dir> [--views front,side,top] [--blade 1]
#
# Writes <dir>/<frame>_<view>.png (frames counted from 0, the clip's frame 1
# in Blender) at 480x640, workbench, the ground drawn as a grid. --blade 1 draws
# the Katana's blade off the right hand's prop bone (rekey_clip.py's BLADE),
# to judge a cut's line (milestone-1 task 75); "top" looks down on the hips.

import math
import os
import sys

import bpy
import mathutils


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"frames": None, "out": None, "views": "front,side", "blade": "0"}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        out[key] = argv[i + 1]
        i += 2
    return out


# The Katana's blade from the grip, m along the prop bone's +Y, in the pack
# rig's metres (rekey_clip.py BLADE: 0.09 to 1.39 m on the game's bodies,
# scaled by their hips, 1.10 m against 0.98).
BLADE = (0.09 * 0.98 / 1.10, 1.39 * 0.98 / 1.10)


def blade(body):
    """A thin cylinder along the Katana's blade on B-handProp.R; the objects made."""
    pb = body.pose.bones.get("B-handProp.R")
    if pb is None:
        return []
    m = body.matrix_world @ pb.matrix
    o = m.to_translation()
    y = (m.to_3x3() @ mathutils.Vector((0.0, 1.0, 0.0))).normalized()
    a, b = o + y * BLADE[0], o + y * BLADE[1]
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(radius=0.014, depth=d.length, vertices=8, location=(a + b) / 2)
    c = bpy.context.active_object
    c.rotation_mode = "QUATERNION"
    c.rotation_quaternion = d.to_track_quat("Z", "Y")
    return [c]


def figure(body):
    """A capsule from each bone's head to its tail where the pose has them
    now, and a ball for the head; the objects made."""
    made = []
    mw = body.matrix_world
    for pb in body.pose.bones:
        if pb.name in ("B-root", "B-spineProxy", "B-jaw") or "Prop" in pb.name:
            continue
        a, b = mw @ pb.head, mw @ pb.tail
        d = b - a
        if d.length < 1e-4:
            continue
        r = 0.012 if any(k in pb.name for k in ("Finger", "thumb", "pinky")) else 0.045
        if pb.name.startswith(("B-thigh", "B-hips", "B-chest", "B-spine")):
            r = 0.07
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, vertices=10, location=(a + b) / 2)
        c = bpy.context.active_object
        c.rotation_mode = "QUATERNION"
        c.rotation_quaternion = d.to_track_quat("Z", "Y")
        made.append(c)
    head = body.pose.bones.get("B-head")
    if head:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=mw @ head.tail)
        made.append(bpy.context.active_object)
    return made


def main():
    a = args()
    body = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    scene = bpy.context.scene
    scene.frame_set(1)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "SINGLE"
    scene.render.resolution_x, scene.render.resolution_y = 480, 640
    scene.render.film_transparent = False
    bpy.ops.mesh.primitive_plane_add(size=6)
    floor = bpy.context.active_object
    floor.display_type = "WIRE"
    bpy.ops.object.modifier_add(type="WIREFRAME")
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 3.2
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # the pack's characters face -Y in Blender; front looks at the face
    views = {"front": ((0.0, -6.0, 1.0), (math.radians(90), 0, 0)), "side": ((6.0, 0.0, 1.0), (math.radians(90), 0, math.radians(90))),
             "back": ((0.0, 6.0, 1.0), (math.radians(90), 0, math.radians(180))),
             "top": ((0.0, 0.0, 6.0), (0.0, 0.0, 0.0))}
    os.makedirs(a["out"], exist_ok=True)
    hips = body.pose.bones["B-hips"]
    frames = [int(f) for f in a["frames"].split(",")]
    shown = a["views"].split(",")
    for frame in frames:
        scene.frame_set(1 + frame)
        bpy.context.view_layer.update()
        made = figure(body)
        if a["blade"] == "1":
            made += blade(body)
        at = body.matrix_world @ hips.head
        for v in shown:
            loc, rot = views[v]
            cam.location = mathutils.Vector((at.x + loc[0], at.y + loc[1], loc[2]))
            cam.rotation_euler = rot
            scene.render.filepath = os.path.join(a["out"], f"{frame:02d}_{v}.png")
            bpy.ops.render.render(write_still=True)
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)
    stitch(a["out"], frames, shown)
    print(f"pose_sheet: wrote {a['out']}", flush=True)


def stitch(out, frames, views):
    """Every render in one sheet.png: a column per frame, a row per view,
    at half size."""
    import numpy as np
    tiles = []
    for v in views:
        row = []
        for frame in frames:
            img = bpy.data.images.load(os.path.join(out, f"{frame:02d}_{v}.png"))
            w, h = img.size
            px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::2, ::2]
            bpy.data.images.remove(img)
            row.append(px)
        tiles.append(np.concatenate(row, axis=1))
    grid = np.concatenate(tiles[::-1], axis=0)  # Blender's rows run bottom up
    h, w = grid.shape[:2]
    sheet = bpy.data.images.new("sheet", w, h, alpha=True)
    sheet.pixels[:] = grid.ravel()
    sheet.filepath_raw = os.path.join(out, "sheet.png")
    sheet.file_format = "PNG"
    sheet.save()


main()
