extends SceneTree
## Converts the Iglesias clips the clip manifest names into one animation
## library per clip set (ClipLibraries: HumanM for the Hunter, HumanF for the
## Rogue). Run it whenever the manifest changes:
##
##   node scripts/godot.mjs clips
##
## which runs this script twice around a Godot import:
## 1. `--stage` copies each clip's FBX from the packs' folder (AssetSource)
##    into the gitignored staging folder and writes its .import, which
##    retargets it through the Iglesias bone map (unmapped bones' tracks
##    dropped). Staged files the manifest no longer names are removed.
## 2. Godot imports the staged files.
## 3. `--build` reads each imported clip and, for each set, writes its
##    library into the gitignored library folder:
##    - drops the Root track, every scale track and every position track but
##      the hips' (the rules own where a fighter is);
##    - scales the hips' travel from their rest by the target fighter's
##      leg-to-hips ratio over Kevin's rig's, because our fighters' legs are
##      longer for their hips height (docs/research/retarget-prototype.md);
##    - mirrors the clips the manifest marks (left and right swapped);
##    - sets the loop mode, and names the clip by its manifest id;
##    - then builds each composed clip from two of them (compose()).
##
## Roll01 [RM] is staged and imported beside the clips for its root track
## alone (ROOT_SOURCES): `--build` prints its ground travel, normalised to
## 0-1 and resampled to the dodge's frames (roll_curve()), the 17 numbers
## SimConst.MOVE_ROLL_CURVE holds (authored-animation task 17), and never
## puts it in a library.
##
## Neither the staged FBX copies nor the libraries are ever committed
## (docs/specs/authored-animation.md, Licence). Without the packs the stage
## exits with code 2 and says which setting to fix. The output is
## deterministic: two runs from the same packs write identical libraries.

const STAGING: String = "res://assets/kevin_iglesias/staging"
const BONE_MAP: String = "res://assets/kevin_iglesias/iglesias_bone_map.tres"
## Each set's hips travel is scaled for the fighter that plays it.
const TARGETS: Dictionary[StringName, String] = {
	&"HumanM": "res://fighters/hunter/hunter.tscn",
	&"HumanF": "res://fighters/rogue/rogue.tscn",
}
const SKELETON: String = "%GeneralSkeleton"
## Clips staged only for their root track: Roll01 [RM], the roll's travel.
const ROOT_SOURCES: Array[Dictionary] = [
	{"id": &"Roll01_RM", "pack": "Human Basic Motions", "dir": "Movement", "source": "Roll01 [RM]"},
]
## The clip whose root travel is the roll's, and the set it is read from
## (the paths' set).
const ROLL_SOURCE: StringName = &"Roll01_RM"
const ROLL_SET: StringName = &"HumanM"
const EXIT_NO_PACKS: int = 2


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var code: int = 1
	if args.has("--stage"):
		code = stage(ClipManifest.read())
	elif args.has("--build"):
		code = build(ClipManifest.read())
	else:
		printerr("import_clips: say --stage or --build (or run `node scripts/godot.mjs clips`)")
	quit(code)


# --- stage ---------------------------------------------------------------------

## Copies the manifest's clips into STAGING with their import settings.
## Returns 0, EXIT_NO_PACKS, or 1 on any other failure.
func stage(m: ClipManifest) -> int:
	if not m.errors.is_empty():
		printerr("import_clips: the manifest has mistakes:\n  " + "\n  ".join(m.errors))
		return 1
	if not AssetSource.has_iglesias():
		printerr("import_clips: " + AssetSource.missing_message("kevin_iglesias"))
		return EXIT_NO_PACKS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STAGING))
	var wanted: Dictionary[String, bool] = {}
	var missing: PackedStringArray = []
	var copied: int = 0
	for set_name: StringName in m.sets:
		for clip: ClipManifest.Clip in m.sourced() + root_clips():
			var src: String = source_path(m, set_name, clip)
			var dest: String = staged_path(set_name, clip)
			wanted[dest.get_file()] = true
			if not FileAccess.file_exists(src):
				missing.append(src)
				continue
			if not FileAccess.file_exists(dest) or FileAccess.get_md5(src) != FileAccess.get_md5(dest):
				if DirAccess.copy_absolute(src, ProjectSettings.globalize_path(dest)) != OK:
					printerr("import_clips: cannot copy %s" % src)
					return 1
				copied += 1
			_write_import(dest)
	if not missing.is_empty():
		printerr("import_clips: not in the packs:\n  " + "\n  ".join(missing))
		return 1
	var removed: int = 0
	for f: String in DirAccess.get_files_at(STAGING):
		var base: String = f.trim_suffix(".import")
		if not wanted.has(base):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(STAGING.path_join(f)))
			removed += 1
	print("import_clips: staged %d clips for %d sets (%d copied, %d stale files removed)" % [m.sourced().size(), m.sets.size(), copied, removed])
	return 0


## A clip's FBX in the packs.
static func source_path(m: ClipManifest, set_name: StringName, clip: ClipManifest.Clip) -> String:
	return AssetSource.pack_folder("kevin_iglesias").path_join(clip.file(set_name, m.sets[set_name]))


## Where a clip is staged: `<set>@<source>.fbx`, with anything but letters,
## digits and underscores in the source name turned into underscores
## ("Roll01 [RM]" -> "Roll01_RM").
static func staged_path(set_name: StringName, clip: ClipManifest.Clip) -> String:
	var name: String = ""
	for ch: String in clip.source:
		name += ch if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" else "_"
	while name.contains("__"):
		name = name.replace("__", "_")
	return STAGING.path_join("%s@%s.fbx" % [set_name, name.trim_suffix("_")])


## The import settings a staged clip needs (Godot fills in the rest).
static func import_settings(source_file: String) -> String:
	return """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="%s"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
meshes/generate_lods=false
meshes/create_shadow_meshes=false
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
_subresources={
"nodes": {
"PATH:Skeleton3D": {
"retarget/bone_map": Resource("%s"),
"retarget/remove_tracks/unmapped_bones": true
}
}
}
fbx/importer=0
fbx/allow_geometry_helper_nodes=false
fbx/embedded_image_handling=1
fbx/naming_version=2
""" % [source_file, BONE_MAP]


## Writes a staged clip's .import unless it already retargets through the
## bone map (Godot rewrites the file on import, keeping these settings).
func _write_import(dest: String) -> void:
	var path: String = dest + ".import"
	if FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		if text.contains(BONE_MAP) and text.contains("\"retarget/remove_tracks/unmapped_bones\": true") \
				and text.contains("animation/trimming=false") and text.contains("animation/fps=30"):
			return
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(import_settings(dest))
	f.close()


# --- build ---------------------------------------------------------------------

## Writes every set's library from the staged, imported clips.
func build(m: ClipManifest) -> int:
	if not m.errors.is_empty():
		printerr("import_clips: the manifest has mistakes:\n  " + "\n  ".join(m.errors))
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ClipLibraries.FOLDER))
	for set_name: StringName in m.sets:
		var lib: AnimationLibrary = build_set(m, set_name)
		if lib == null:
			return 1
		var path: String = ClipLibraries.path(set_name)
		var err: Error = ResourceSaver.save(lib, path)
		if err != OK:
			printerr("import_clips: cannot save %s (%s)" % [path, error_string(err)])
			return 1
		print("import_clips: %s: %d clips -> %s" % [set_name, lib.get_animation_list().size(), path])
	for set_name: StringName in m.sets:
		var curve: PackedFloat64Array = roll_curve(set_name)
		if curve.is_empty():
			return 1
		print("import_clips: %s Roll01 [RM] travel over %d frames: [%s]%s" % [set_name, SimConst.MOVE_DODGE_FRAMES,
			", ".join(Array(curve).map(func(v: float) -> String: return "%.4f" % v)),
			" (SimConst.MOVE_ROLL_CURVE)" if set_name == ROLL_SET else ""])
	return 0


## The clips staged for their root track alone (ROOT_SOURCES).
static func root_clips() -> Array[ClipManifest.Clip]:
	var out: Array[ClipManifest.Clip] = []
	for d: Dictionary in ROOT_SOURCES:
		var c: ClipManifest.Clip = ClipManifest.Clip.new()
		c.id = d["id"]
		c.pack = d["pack"]
		c.dir = d["dir"]
		c.source = d["source"]
		out.append(c)
	return out


## Roll01 [RM]'s root travel for a set (curve_of()), from its staged import;
## empty, with an error, when it isn't imported.
static func roll_curve(set_name: StringName) -> PackedFloat64Array:
	var clip: ClipManifest.Clip = root_clips()[0]
	var path: String = staged_path(set_name, clip)
	if not ResourceLoader.exists(path):
		printerr("import_clips: %s is not imported; run `node scripts/godot.mjs clips`" % path)
		return PackedFloat64Array()
	var scene: Node = (load(path) as PackedScene).instantiate()
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var src: AnimationLibrary = player.get_animation_library(&"")
	var curve: PackedFloat64Array = curve_of(src.get_animation(src.get_animation_list()[0]), SimConst.MOVE_DODGE_FRAMES)
	scene.free()
	return curve


## A root track's ground travel, normalised to 0-1 and resampled to
## `frames` even steps (frames + 1 numbers): the root's distance across the
## ground from where it starts, over the stretch it travels (until it is
## within 0.1% of where it ends, on a source frame), over its travel by then.
static func curve_of(anim: Animation, frames: int) -> PackedFloat64Array:
	var t: int = anim.find_track(NodePath(SKELETON + ":Root"), Animation.TYPE_POSITION_3D)
	if t < 0:
		return PackedFloat64Array()
	var start: Vector3 = anim.position_track_interpolate(t, 0.0)
	var ground: Callable = func(time: float) -> float:
		var d: Vector3 = anim.position_track_interpolate(t, time) - start
		return Vector2(d.x, d.z).length()
	var total: float = ground.call(anim.length)
	var source_frames: int = roundi(anim.length * ClipManifest.SOURCE_FPS)
	var end: int = source_frames
	for f: int in source_frames + 1:
		if ground.call(f / float(ClipManifest.SOURCE_FPS)) >= total * 0.999:
			end = f
			break
	var reach: float = ground.call(end / float(ClipManifest.SOURCE_FPS))
	var out: PackedFloat64Array = PackedFloat64Array()
	for i: int in frames + 1:
		out.append(snappedf(minf(1.0, ground.call(end * i / float(frames) / ClipManifest.SOURCE_FPS) / reach), 0.0001))
	return out


## A set's library from the staged clips, or null if one isn't imported.
static func build_set(m: ClipManifest, set_name: StringName) -> AnimationLibrary:
	var target: FighterModel = (load(TARGETS[set_name]) as PackedScene).instantiate()
	var target_ratio: float = leg_ratio(target.skeleton)
	target.free()
	var lib: AnimationLibrary = AnimationLibrary.new()
	for clip: ClipManifest.Clip in m.sourced():
		var path: String = staged_path(set_name, clip)
		if not ResourceLoader.exists(path):
			printerr("import_clips: %s is not imported; run `node scripts/godot.mjs clips`" % path)
			return null
		var scene: Node = (load(path) as PackedScene).instantiate()
		var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var players: Array[Node] = scene.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			printerr("import_clips: %s has no clip" % path)
			scene.free()
			return null
		var src: AnimationLibrary = (players[0] as AnimationPlayer).get_animation_library(&"")
		var anim: Animation = src.get_animation(src.get_animation_list()[0]).duplicate(true)
		strip(anim)
		var rest: Vector3 = sk.get_bone_rest(sk.find_bone("Hips")).origin / sk.motion_scale
		scale_hips(anim, rest, target_ratio / leg_ratio(sk))
		scene.free()
		if clip.mirror:
			mirror(anim)
		anim.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		anim.resource_name = String(clip.id)
		# A fixed sub-resource id, so the saved file doesn't change from run to run.
		anim.resource_scene_unique_id = "clip_" + staged_path(set_name, clip).get_file().get_basename().get_slice("@", 1)
		lib.add_animation(clip.id, anim)
	for clip: ClipManifest.Clip in m.clips.values():
		if not clip.composed():
			continue
		var anim: Animation = compose(lib.get_animation(clip.upper), lib.get_animation(clip.legs), clip.upper_from, clip.legs_from)
		anim.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		anim.resource_name = String(clip.id)
		anim.resource_scene_unique_id = "clip_" + String(clip.id)
		lib.add_animation(clip.id, anim)
	return lib


## A composed clip (authored-animation task 22): clip `upper` from source
## frame `upper_from` on the upper body, over clip `legs` from `legs_from`
## on the hips and legs (Locomotion.is_leg_bone(), as the upper-body blend
## splits them), keyed on every source frame for as long as `upper` runs on
## (`legs` held at its end if it runs out). The spine is turned so the upper
## body stands as it did over its own clip's hips, lowered or raised with the
## legs' (leaning back with a slide's hips, a cut would go into the floor).
static func compose(upper: Animation, legs: Animation, upper_from: int, legs_from: int) -> Animation:
	var out: Animation = Animation.new()
	var fps: float = ClipManifest.SOURCE_FPS
	var frames: int = maxi(0, roundi(upper.length * fps) - upper_from)
	out.length = frames / fps
	var hips: NodePath = NodePath(SKELETON + ":Hips")
	var upper_hips: int = upper.find_track(hips, Animation.TYPE_ROTATION_3D)
	var legs_hips: int = legs.find_track(hips, Animation.TYPE_ROTATION_3D)
	for src: Animation in [upper, legs]:
		var from: int = legs_from if src == legs else upper_from
		for t: int in src.get_track_count():
			var path: NodePath = src.track_get_path(t)
			var bone: String = path.get_concatenated_subnames()
			var type: int = src.track_get_type(t)
			if Locomotion.is_leg_bone(bone) != (src == legs) or (type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D):
				continue
			var nt: int = out.add_track(type)
			out.track_set_path(nt, path)
			for k: int in frames + 1:
				var at: float = minf((k + from) / fps, src.length)
				if type == Animation.TYPE_POSITION_3D:
					out.position_track_insert_key(nt, k / fps, src.position_track_interpolate(t, at))
					continue
				var q: Quaternion = src.rotation_track_interpolate(t, at)
				if bone == "Spine" and upper_hips >= 0 and legs_hips >= 0:
					var ha: Quaternion = upper.rotation_track_interpolate(upper_hips, at)
					var hs: Quaternion = legs.rotation_track_interpolate(legs_hips, minf((k + legs_from) / fps, legs.length))
					q = hs.inverse() * ha * q
				out.rotation_track_insert_key(nt, k / fps, q)
	return out



## Leaves only rotation tracks on profile bones other than Root, and the
## hips' position track.
static func strip(anim: Animation) -> void:
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for t: int in range(anim.get_track_count() - 1, -1, -1):
		var path: NodePath = anim.track_get_path(t)
		var bone: StringName = StringName(path.get_concatenated_subnames())
		var type: int = anim.track_get_type(t)
		var keep: bool = String(path.get_concatenated_names()) == SKELETON and bone != &"Root" \
			and profile.find_bone(bone) >= 0 \
			and (type == Animation.TYPE_ROTATION_3D or (type == Animation.TYPE_POSITION_3D and bone == &"Hips"))
		if not keep:
			anim.remove_track(t)


## Scales the hips' travel from `rest` (normalised, as the track holds it)
## by `k`.
static func scale_hips(anim: Animation, rest: Vector3, k: float) -> void:
	var t: int = anim.find_track(NodePath(SKELETON + ":Hips"), Animation.TYPE_POSITION_3D)
	if t < 0:
		return
	for i: int in anim.track_get_key_count(t):
		var v: Vector3 = anim.track_get_key_value(t, i)
		anim.track_set_key_value(t, i, rest + (v - rest) * k)


## Swaps left and right: each Left bone's track goes to its Right bone and
## back, every rotation is reflected across the body's middle (x, y, z, w ->
## x, -y, -z, w) and the hips' travel to the side is flipped.
static func mirror(anim: Animation) -> void:
	for t: int in anim.get_track_count():
		var path: NodePath = anim.track_get_path(t)
		var bone: String = path.get_concatenated_subnames()
		if bone.begins_with("Left"):
			bone = "Right" + bone.substr(4)
		elif bone.begins_with("Right"):
			bone = "Left" + bone.substr(5)
		anim.track_set_path(t, NodePath(SKELETON + ":" + bone))
		for i: int in anim.track_get_key_count(t):
			match anim.track_get_type(t):
				Animation.TYPE_ROTATION_3D:
					var q: Quaternion = anim.track_get_key_value(t, i)
					anim.track_set_key_value(t, i, Quaternion(q.x, -q.y, -q.z, q.w))
				Animation.TYPE_POSITION_3D:
					var v: Vector3 = anim.track_get_key_value(t, i)
					anim.track_set_key_value(t, i, Vector3(-v.x, v.y, v.z))


## Leg length (hip joint to ankle, both legs averaged) over hips height, in
## the rest pose.
static func leg_ratio(sk: Skeleton3D) -> float:
	var length: float = 0.0
	for side: String in ["Left", "Right"]:
		var hip: Vector3 = sk.get_bone_global_rest(sk.find_bone(side + "UpperLeg")).origin
		var knee: Vector3 = sk.get_bone_global_rest(sk.find_bone(side + "LowerLeg")).origin
		var ankle: Vector3 = sk.get_bone_global_rest(sk.find_bone(side + "Foot")).origin
		length += (hip.distance_to(knee) + knee.distance_to(ankle)) / 2.0
	return length / sk.get_bone_global_rest(sk.find_bone("Hips")).origin.y
