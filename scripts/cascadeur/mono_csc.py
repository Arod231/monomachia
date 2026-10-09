# Runs inside Cascadeur (2026.2.3), sent over its script server by
# scripts/cascadeur/run.mjs: the keying steps the clips of milestone-1 task 59
# on are made with (docs/research/cascadeur-python-api.md has the API facts).
#
# A clip's key poses come in as a GLB block-out keyed on every frame (the
# Blender pass, scripts/blender/rekey_clip.py); here they go onto the HumanM
# rig, every frame but the spec's key poses is unkeyed, the intervals between
# them are set to Cascadeur's AI inbetweening, and the result goes back out as
# a GLB of the animation alone, in metres, for scripts/blender/import_casc.py.
#
# Each step works on this module's own scene tab (never the owner's): `tab()`
# makes it once and keeps it across calls in builtins._mono_state, under the
# calling lane's name (several lanes share the owner's one Cascadeur), since
# the scene manager doesn't list tabs in the order they were opened.

import builtins
import json

import csc

APP = csc.app.get_application()
# Cascadeur works in centimetres: at the clips' metres the rig build fails its
# hinge check (the hands-on test, Oct 6).
IMPORT_SCALE = 100.0
EXPORT_SCALE = 0.01
FPS = 30.0


# The calling lane: run.mjs sets it from the git branch (milestone-1 task 76:
# a name fixed here made every lane take the lock as one, and swap the others'
# tabs mid-run).
LANE = 'lane/m1-59-93-94-95'


def _state():
	"""This lane's own state, its tab, kept across calls."""
	return builtins.__dict__.setdefault('_mono_lanes', {}).setdefault(LANE, {})


def lock():
	"""Takes Cascadeur for this lane: several sessions share the owner's one
	Cascadeur, and two driving it at once crashed it (Oct 7). Returns the
	holder's name when another lane holds it (then do nothing), else ''."""
	held = getattr(builtins, '_lane_lock', None)
	if held and held != LANE:
		return held
	builtins._lane_lock = LANE
	return ''


def unlock():
	if getattr(builtins, '_lane_lock', None) == LANE:
		builtins._lane_lock = None


def tab(fresh=False):
	"""This module's scene tab, made current; a new one when `fresh`."""
	sm = APP.get_scene_manager()
	t = _state().get('tab')
	if fresh or t is None or not any(s is t for s in sm.scenes()):
		t = sm.create_application_scene()
		_state()['tab'] = t
	sm.set_current_scene(t)
	return t


def close():
	"""Closes this module's tab, if it is open: only the very tab object
	tab() made (tab names are reused, so never by name or position)."""
	sm = APP.get_scene_manager()
	t = _state().pop('tab', None)
	if t is not None and any(s is t for s in sm.scenes()):
		sm.remove_application_scene(t)


def scene():
	return tab().domain_scene()


def import_glb(path, objects=True, animation=True):
	opts = csc.glb.ImportOptions()
	opts.include_objects = objects
	opts.include_animation = animation
	opts.scale_factor = IMPORT_SCALE
	csc.glb.process_import(scene(), path, opts)


def joints():
	"""Every joint object of the scene, by name."""
	mv = scene().model_viewer()
	bv = mv.behaviour_viewer()
	out = {}
	for obj in mv.get_objects():
		if not bv.get_behaviour_by_name(obj, 'Joint').is_null():
			out[mv.get_object_name(obj)] = obj
	return out


def build_rig(template_path):
	"""Rig mode on without its dialog, the template's rig generated, rig mode
	off: the order the hands-on test found."""
	from rig_mode import on as rig_on
	from rig_mode import off as rig_off
	sc = scene()
	ids = list(joints().values())

	def mod(model, update, sc_updater, session):
		be = model.behaviour_editor()
		o_id = update.root().create_object('Rig info').object_id()
		rig_info = be.add_behaviour(o_id, 'RigInfo')
		be.set_behaviour_model_objects_to_range(rig_info, 'related_joints', ids)
		sc_updater.generate_update()
		session.take_selector().select({o_id}, o_id)
		rig_on.on(model, update, sc_updater, session, None, None, o_id)

	sc.modify_update_with_session('Rig mode on', mod)
	with open(template_path, encoding='utf-8') as f:
		text = f.read()
	rigging = APP.get_tools_manager().get_tool('RiggingToolWindowTool').editor(tab())
	rigging.load_template_by_content(text)
	rigging.generate_rig_elements()
	rig_off.run(sc, True)
	return len(scene().model_viewer().get_objects())


def layer_ids():
	return scene().layers_viewer().all_layer_ids()


def key_frames():
	"""The frames any track has a key on, in order."""
	lv = scene().layers_viewer()
	out = set()
	for lid in lv.all_layer_ids():
		out.update(lv.layer(lid).key_frame_indices())
	return sorted(out)


def keep_keys(keep, ai=True, description=''):
	"""Every key unset but those on frames `keep`, and (`ai`) each interval
	from a kept key set to Cascadeur's AI inbetweening, told `description`:
	the key poses stay and Cascadeur makes the motion between them. The way
	Nekki's own keyframe reduction edits keys."""
	keep = set(keep)

	def mod_section(section):
		section.interval.interpolation = csc.layers.layer.Interpolation.AI
		if description:
			section.interval.description_for_ai_interpolation = description

	def mod(model, update, sc):
		le = model.layers_editor()
		lv = sc.layers_viewer()
		for lid in lv.all_layer_ids():
			for pos in list(lv.layer(lid).key_frame_indices()):
				if pos not in keep:
					le.unset_section(pos, lid)
				elif ai:
					le.change_section(pos, lid, mod_section)

	return scene().modify('Keep the key poses', mod)


def export_glb(path, first, last):
	"""The animation of frames `first` to `last` as a GLB in metres at 30 fps
	(Cascadeur adds a rest-pose frame 0, so a clip keyed from frame 1 exports
	from 1 and lands one frame early; import_casc.py puts it back)."""
	sc = scene()
	sc.get_layers_selector().set_full_selection_by_parts(layer_ids(), first, last)
	opts = csc.glb.ExportOptions()
	opts.include_animation = True
	opts.for_selected_interval = True
	opts.fps = FPS
	opts.scale_factor = EXPORT_SCALE
	csc.glb.process_export(sc, path, opts)


def save(path):
	"""Saves this module's scene as `path` (a .casc), the clip's editable
	source. (DataSourceManager.save_scene_as() returns without saving.)"""
	tab().save(path.replace('/', chr(92)))




def info():
	sc = scene()
	mv = sc.model_viewer()
	return {'objects': len(mv.get_objects()), 'joints': len(joints())}
