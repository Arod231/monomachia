extends SceneTree
## Builds the shared AnimationLibrary every fighter plays: the clips the game
## needs from the Universal Animation Library GLBs (already retargeted to the
## humanoid profile by their .import files), with the loop flags set and no
## root motion, because the rules own movement. It is the committed CC0
## library: besides the clips the game plays today, it holds every UAL clip
## the clip table in docs/specs/authored-animation.md names, so a fresh clone
## without the Iglesias packs can play each move's fallback.
##
## Run: node scripts/godot.mjs script res://tools/build_animation_library.gd [-- --verbose]
##
## - Tracks address bones as `%GeneralSkeleton:<profile bone>`, so a clip plays
##   on any node that owns a unique Skeleton3D named GeneralSkeleton (see
##   FighterModel).
## - The clips keep their pack names, without the `_Loop` suffix the importer
##   strips.
## - A clip found in more than one GLB is taken from the first in SOURCES, so
##   the Standard clips the game already played stay as they were, and the
##   Source GLB adds only the clips the Standard tier lacks.
## - Root motion: the packs' Standard and Source GLBs are in place (their root
##   bone never moves; the _RM files carry the travel, and the game doesn't
##   use them).
##   The builder still drops any track on the Root bone, so swapping in a
##   root-motion file can't move a fighter. The hips keep their in-pose
##   sway and weight shifts (up to about half a metre in the death fall).
## - Tracks on bones outside the humanoid profile (finger and toe leaf bones)
##   and scale tracks are dropped.

const SOURCES: Array[String] = [
	"res://assets/quaternius/animations/UAL1_Standard.glb",
	"res://assets/quaternius/animations/UAL2_Standard.glb",
	"res://assets/quaternius/animations/UAL2_Source.glb",
]
const OUT_PATH: String = "res://assets/quaternius/animations/ual_library.res"
const SKELETON_PREFIX: String = "%GeneralSkeleton"

## Clips that loop.
const LOOPING: Array[StringName] = [
	&"Idle", &"Sword_Idle", &"Walk", &"Walk_Formal", &"Jog_Fwd", &"Sprint", &"Jump", &"NinjaJump_Idle",
	&"Dance", &"Idle_FoldArms", &"Idle_Shield", &"Idle_Lantern",
	# The clip table's UAL2 clips: the eight walk directions and the aerial
	# combo (Sword_Aerial_Combo_Loop in the pack).
	&"Walk_Fwd", &"Walk_Bwd", &"Walk_L", &"Walk_R", &"Walk_Fwd_L", &"Walk_Fwd_R", &"Walk_Bwd_L", &"Walk_Bwd_R",
	&"Sword_Aerial_Combo",
]
## Clips that play once.
const ONE_SHOT: Array[StringName] = [
	&"Jump_Start", &"Jump_Land", &"NinjaJump_Start", &"NinjaJump_Land",
	&"Hit_Chest", &"Hit_Head", &"Hit_Knockback", &"LayToIdle", &"Death01",
	&"Punch_Jab", &"Punch_Cross", &"Melee_Hook", &"Melee_Hook_Rec",
	&"PickUp_Table", &"Farm_Harvest", &"Roll",
	&"Sword_Block", &"Idle_Shield_Break",
	&"Sword_Regular_A", &"Sword_Regular_A_Rec", &"Sword_Regular_B", &"Sword_Regular_B_Rec", &"Sword_Regular_C",
	&"Sword_Heavy_Combo", &"Sword_Dash", &"Sword_Attack",
	&"Yes",
	# The clip table's UAL2 clips, as fallbacks or first candidates.
	&"Sword_Light_A", &"Sword_Light_B", &"Sword_Light_C", &"Sword_Light_D",
	&"Sword_Heavy_A", &"Sword_Heavy_B", &"Sword_Heavy_C", &"Sword_Heavy_D",
	&"Sword_UpperCut", &"Sword_Aerial_A", &"Sword_Aerial_B", &"Sword_GroundPound",
	&"Shield_Dash", &"Slide_Start", &"Melee_Uppercut", &"Melee_Knee",
]


static func clip_names() -> Array[StringName]:
	var all: Array[StringName] = []
	all.append_array(LOOPING)
	all.append_array(ONE_SHOT)
	return all


func _initialize() -> void:
	var verbose: bool = OS.get_cmdline_user_args().has("--verbose")
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	var found: Dictionary[StringName, Animation] = {}
	for path: String in SOURCES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var lib: AnimationLibrary = player.get_animation_library(&"")
		for clip: StringName in lib.get_animation_list():
			if clip_names().has(clip) and not found.has(clip):
				found[clip] = lib.get_animation(clip).duplicate(true)
		scene.free()
	var out: AnimationLibrary = AnimationLibrary.new()
	var missing: Array[StringName] = []
	for clip: StringName in clip_names():
		if not found.has(clip):
			missing.append(clip)
			continue
		var anim: Animation = found[clip]
		anim.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(clip) else Animation.LOOP_NONE
		var dropped: int = _drop_tracks(anim, profile)
		if verbose:
			print("  %-20s %.2fs %d tracks (%d dropped) %s" % [clip, anim.length, anim.get_track_count(), dropped, "loop" if LOOPING.has(clip) else "once"])
		out.add_animation(clip, anim)
	if not missing.is_empty():
		printerr("build_animation_library: clips not found: %s" % [missing])
		quit(1)
		return
	var err: Error = ResourceSaver.save(out, OUT_PATH, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("build_animation_library: cannot save %s (%s)" % [OUT_PATH, error_string(err)])
		quit(1)
		return
	print("build_animation_library: %d clips saved to %s" % [out.get_animation_list().size(), OUT_PATH])
	quit(0)


## Drops root-bone tracks, scale tracks and tracks on bones the humanoid
## profile doesn't have. Returns how many were dropped.
static func _drop_tracks(anim: Animation, profile: SkeletonProfile) -> int:
	var dropped: int = 0
	for t: int in range(anim.get_track_count() - 1, -1, -1):
		var path: NodePath = anim.track_get_path(t)
		var bone: StringName = path.get_concatenated_subnames()
		var keep: bool = (
			String(path.get_concatenated_names()) == SKELETON_PREFIX
			and bone != &"Root"
			and profile.find_bone(bone) >= 0
			and anim.track_get_type(t) in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]
		)
		if not keep:
			anim.remove_track(t)
			dropped += 1
	return dropped
