# Runs inside Blender (headless) for the export's local-only test
# (tests/blender-export.test.mjs): builds three test sources in a folder,
# nothing committed:
#   block_out.blend   a block-out clip: an armature with the Kevin Iglesias
#                     rig's bones (from --bones) and its prop sockets, its
#                     hips, right arm and right prop keyed over 10 frames;
#   block_out_from_1.blend  the same clip keyed from Blender frame 1, as
#                     rekey_clip.py keys its sources (the scene from frame 1);
#   box.blend         a box model with a material;
#   no_rig.blend      a clip keyed on an empty, with no armature.
#
#   blender -b --factory-startup --python-exit-code 1 \
#     --python scripts/blender/make_test_sources.py -- <folder> <bones.json>

import json
import os
import sys

import bpy

folder, bones_file = sys.argv[sys.argv.index("--") + 1:][:2]
with open(bones_file, encoding="utf-8") as f:
    bones = json.load(f)


def empty_scene(start=0):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.frame_start = start
    bpy.context.scene.frame_end = start + 10
    bpy.context.scene.render.fps = 30


def save(name):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, name))


# a block-out clip on the Iglesias rig: a chain of bones, each 10 cm above the last,
# keyed over 10 frames from `start`
def block_out(start, file):
    empty_scene(start)
    data = bpy.data.armatures.new("HumanM")
    rig = bpy.data.objects.new("HumanM", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    parent = None
    for i, name in enumerate(bones):
        b = data.edit_bones.new(name)
        b.head = (0.0, 0.0, 0.1 * i)
        b.tail = (0.0, 0.0, 0.1 * i + 0.08)
        if parent is not None:
            b.parent = parent
        if name in ("B-root", "B-hips", "B-spine", "B-chest"):
            parent = b
    # the prop sockets, on the hands, which the import keeps for a clip flagged
    # "props" (task 13)
    for side in ("L", "R"):
        b = data.edit_bones.new("B-handProp." + side)
        hand = data.edit_bones["B-hand." + side]
        b.head = hand.head
        b.tail = (hand.head[0], hand.head[1] + 0.08, hand.head[2])
        b.parent = hand
    bpy.ops.object.mode_set(mode="POSE")
    for frame, turn in ((start, 0.0), (start + 5, 0.6), (start + 10, 0.0)):
        for name in ("B-hips", "B-upperArm.R", "B-handProp.R"):
            pb = rig.pose.bones[name]
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (turn, 0.0, turn * 0.5)
            pb.keyframe_insert("rotation_euler", frame=frame)
        prop = rig.pose.bones["B-handProp.R"]
        prop.location = (0.0, turn * 0.1, 0.0)
        prop.keyframe_insert("location", frame=frame)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.animation_data.action.name = "BlockOut"
    save(file)


block_out(0, "block_out.blend")
block_out(1, "block_out_from_1.blend")

# a box model
empty_scene()
bpy.ops.mesh.primitive_cube_add(size=0.2)
box = bpy.context.active_object
box.name = "Box"
mat = bpy.data.materials.new("Lacquer")
mat.diffuse_color = (0.62, 0.17, 0.15, 1.0)
box.data.materials.append(mat)
save("box.blend")

# a clip keyed on an empty: no armature
empty_scene()
e = bpy.data.objects.new("Mover", None)
bpy.context.scene.collection.objects.link(e)
for frame, x in ((0, 0.0), (10, 1.0)):
    e.location = (x, 0.0, 0.0)
    e.keyframe_insert("location", frame=frame)
save("no_rig.blend")
print("make_test_sources: wrote block_out.blend, block_out_from_1.blend, box.blend and no_rig.blend", flush=True)
