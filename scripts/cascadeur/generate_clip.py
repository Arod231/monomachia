# Runs inside Cascadeur, through its script server (scripts/cascadeur/generate.mjs
# sends it with a PARAMS dict prepended): the Cascadeur half of a clip made by
# key poses and AI inbetweening (milestone-1 task 89 on), in stages, one call
# each, since Cascadeur works out the AI inbetweens between calls (its
# interpolator reloads at the next idle) and a call may take at most 30 s:
#
# - "rig": in a new scene tab of its own, imports the key-pose block-out (a
#   GLB of the Kevin Iglesias rig, every channel keyed on every frame, metres)
#   at Cascadeur's centimetres and builds the rig from our Quick Rigging
#   template (scripts/cascadeur/iglesias.qrigcasc);
# - "keys": keeps the keys only on the key-pose frames and sets every
#   interval to AI interpolation, so Cascadeur's inbetweening generates the
#   frames between;
# - "export": exports the clip as a GLB in metres and prints its checksum (the
#   driver exports until two exports agree, the inbetweens settled);
# - "close": saves the scene as a .casc for a later polish and closes the tab.
#
# The tab is kept between calls under PARAMS["id"]; tabs it didn't open are
# never touched (scene_manager.scenes() isn't in open order, and other
# sessions may be working in Cascadeur).
#
# AutoPhysics is not run: called from a script (AutoPhysicsTool.Switch Auto
# Physics, then Snap To Auto Physics) it left the clip unchanged on Oct 7, 2026
# (Cascadeur 2026.2.3), so the weight comes from the key poses and the Blender
# half's planted feet.
#
# PARAMS: {"stage", "id", "glb": block-out GLB, "template": .qrigcasc,
# "keys": [frames], "out": generated GLB, "casc": .casc to save}.

import builtins
import hashlib
import os

import csc
import rig_mode.on as rig_on
import rig_mode.off as rig_off

P = PARAMS  # noqa: F821 (prepended by generate.mjs)
INTERP = csc.layers.layer.Interpolation
if not hasattr(builtins, "_monomachia_tabs"):
    builtins._monomachia_tabs = {}
TABS = builtins._monomachia_tabs


def joints_of(scene):
    mv = scene.model_viewer()
    bv = mv.behaviour_viewer()
    return [o for o in mv.get_objects() if not bv.get_behaviour_by_name(o, "Joint").is_null()]


def rig():
    sm = app.get_scene_manager()  # noqa: F821
    tab = sm.create_application_scene()
    sm.set_current_scene(tab)
    if app.current_scene().name() != tab.name():  # noqa: F821
        raise RuntimeError("the new tab didn't become current")
    TABS[P["id"]] = tab
    scene = tab.domain_scene()
    o = csc.glb.ImportOptions()
    o.include_objects, o.include_animation, o.scale_factor, o.fps = True, True, 100.0, 30
    csc.glb.process_import(scene, P["glb"], o)
    joints = joints_of(scene)

    def on(model, update, updater, session):
        be = model.behaviour_editor()
        info = update.root().create_object("Rig info").object_id()
        rig_info = be.add_behaviour(info, "RigInfo")
        be.set_behaviour_model_objects_to_range(rig_info, "related_joints", joints)
        updater.generate_update()
        session.take_selector().select({info}, info)
        rig_on.on(model, update, updater, session, None, None, info, None, None)

    if not scene.modify_update_with_session("Rig mode on", on):
        raise RuntimeError("rig mode on failed")
    with open(P["template"], encoding="utf-8") as f:
        template = f.read()
    editor = app.get_tools_manager().get_tool("RiggingToolWindowTool").editor(tab)  # noqa: F821
    editor.load_template_by_content(template)
    editor.generate_rig_elements()
    rig_off.run(scene, True)
    print(f"generate_clip: rigged {scene.data_viewer().get_animation_size()} frames")


def keys():
    scene = TABS[P["id"]].domain_scene()
    last = scene.data_viewer().get_animation_size() - 1
    keep = sorted(set(int(k) for k in P["keys"]) | {0, last})
    if keep[-1] != last:
        raise RuntimeError(f"a key pose past the clip's last frame {last}")

    def mod(model, update, sc):
        le = model.layers_editor()
        lv = sc.layers_viewer()

        def ai(section):
            section.interval.interpolation = INTERP.AI

        for lid in lv.all_layer_ids():
            for f in list(lv.layer(lid).key_frame_indices()):
                if f in keep:
                    if f != last:
                        le.change_section(f, lid, ai)
                else:
                    le.unset_section(f, lid)

    if not scene.modify("Key poses, AI inbetweening", mod):
        raise RuntimeError("keeping the key poses failed")
    lv = scene.layers_viewer()
    left = {tuple(lv.layer(lid).key_frame_indices()) for lid in lv.all_layer_ids()}
    if left != {tuple(keep)}:
        raise RuntimeError(f"keys left other than the key poses: {left}")
    print(f"generate_clip: key poses {keep}")


def export():
    scene = TABS[P["id"]].domain_scene()
    last = scene.data_viewer().get_animation_size() - 1
    scene.get_layers_selector().set_full_selection_by_parts(scene.layers_viewer().all_layer_ids(), 0, last)
    e = csc.glb.ExportOptions()
    e.include_animation, e.for_selected_interval, e.fps, e.scale_factor = True, True, 30, 0.01
    csc.glb.process_export(scene, P["out"], e)
    with open(P["out"], "rb") as f:
        print(f"generate_clip: exported {last + 1} frames, sha256 {hashlib.sha256(f.read()).hexdigest()}")


def close():
    tab = TABS.pop(P["id"])
    # the tab's own save is synchronous (DataSourceManager.save_scene_as
    # wrote nothing from a script on Oct 7, 2026)
    tab.save(P["casc"])
    if not os.path.isfile(P["casc"]):
        raise RuntimeError(f"the scene wasn't saved to {P['casc']}")
    app.get_scene_manager().remove_application_scene(tab)  # noqa: F821
    print(f"generate_clip: saved {P['casc']} and closed the tab")


{"rig": rig, "keys": keys, "export": export, "close": close}[P["stage"]]()
