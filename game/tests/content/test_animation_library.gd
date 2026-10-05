extends GutTest
## The shared clip library every fighter plays: the clips the game needs, the
## right loop flags, tracks only on humanoid bones, and no root motion.

const LIBRARY: String = "res://assets/quaternius/animations/ual_library.res"

const LOOPING: Array[StringName] = [
	&"Idle", &"Sword_Idle", &"Walk", &"Walk_Formal", &"Jog_Fwd", &"Sprint", &"Jump", &"NinjaJump_Idle",
	&"Dance", &"Idle_FoldArms", &"Idle_Shield",
]
const ONE_SHOT: Array[StringName] = [
	&"Jump_Start", &"Jump_Land", &"NinjaJump_Start", &"NinjaJump_Land",
	&"Hit_Chest", &"Hit_Head", &"Hit_Knockback", &"LayToIdle", &"Death01",
	&"Punch_Jab", &"Punch_Cross", &"Melee_Hook", &"PickUp_Table", &"Roll",
	&"Sword_Block", &"Idle_Shield_Break", &"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C",
	&"Sword_Heavy_Combo", &"Sword_Dash", &"Sword_Attack", &"Yes",
]

## Every clip the Fallback column of the spec's clip table names
## (docs/specs/authored-animation.md), which a fresh clone without the
## Iglesias packs plays. "UAL2 Walk_*_Loop" is the eight walk directions.
const FALLBACK: Array[StringName] = [
	# UAL2 Source clips.
	&"Sword_Light_A", &"Sword_Light_B", &"Sword_Light_C", &"Sword_Light_D",
	&"Sword_Heavy_A", &"Sword_Heavy_B", &"Sword_Heavy_C", &"Sword_Heavy_D",
	&"Sword_UpperCut", &"Sword_Aerial_B", &"Melee_Uppercut", &"Slide_Start",
	&"Walk_Fwd", &"Walk_Bwd", &"Walk_L", &"Walk_R", &"Walk_Fwd_L", &"Walk_Fwd_R", &"Walk_Bwd_L", &"Walk_Bwd_R",
	# Clips already in the UAL1 and UAL2 Standard library.
	&"Sword_Attack", &"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C", &"Sword_Dash",
	&"Sword_Block", &"Sword_Heavy_Combo", &"Idle_Shield_Break", &"Punch_Jab", &"Punch_Cross", &"Melee_Hook",
	&"Roll", &"Sword_Idle", &"Idle", &"Walk", &"Jog_Fwd", &"Sprint", &"Jump_Start", &"Jump", &"Jump_Land",
	&"NinjaJump_Start", &"Hit_Knockback", &"Hit_Chest", &"Hit_Head", &"LayToIdle", &"PickUp_Table",
	&"Death01", &"Yes",
]
## The UAL2 clips the table gives as first candidates. The importer strips
## `_Loop`, so Sword_Aerial_Combo_Loop is Sword_Aerial_Combo.
const UAL2_CANDIDATES: Array[StringName] = [
	&"Sword_Dash", &"Shield_Dash", &"Sword_GroundPound", &"Sword_UpperCut", &"Sword_Aerial_A",
	&"Sword_Aerial_B", &"Sword_Aerial_Combo", &"Sword_Light_D", &"Melee_Knee", &"Melee_Uppercut",
]
## Of the clips above, the ones that loop.
const FALLBACK_LOOPING: Array[StringName] = [
	&"Walk_Fwd", &"Walk_Bwd", &"Walk_L", &"Walk_R", &"Walk_Fwd_L", &"Walk_Fwd_R", &"Walk_Bwd_L", &"Walk_Bwd_R",
	&"Sword_Aerial_Combo",
]

var _lib: AnimationLibrary


func before_all() -> void:
	_lib = load(LIBRARY)


func test_the_library_has_every_clip_the_game_needs() -> void:
	for clip: StringName in LOOPING + ONE_SHOT:
		assert_true(_lib.has_animation(clip), "has %s" % clip)


func test_the_library_has_every_fallback_clip_in_the_clip_table() -> void:
	for clip: StringName in FALLBACK + UAL2_CANDIDATES:
		assert_true(_lib.has_animation(clip), "has %s" % clip)


func test_fallback_clips_loop_or_play_once() -> void:
	for clip: StringName in FALLBACK + UAL2_CANDIDATES:
		if not _lib.has_animation(clip) or LOOPING.has(clip):
			continue
		var want: Animation.LoopMode = Animation.LOOP_LINEAR if FALLBACK_LOOPING.has(clip) else Animation.LOOP_NONE
		assert_eq(_lib.get_animation(clip).loop_mode, want, "%s loop mode" % clip)


func test_locomotion_and_idles_loop() -> void:
	for clip: StringName in LOOPING:
		if _lib.has_animation(clip):
			assert_eq(_lib.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)


func test_actions_play_once() -> void:
	for clip: StringName in ONE_SHOT:
		if _lib.has_animation(clip):
			assert_eq(_lib.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s plays once" % clip)


func test_tracks_address_humanoid_bones_on_the_unique_skeleton() -> void:
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for clip: StringName in _lib.get_animation_list():
		var anim: Animation = _lib.get_animation(clip)
		var bad: Array[String] = []
		for t: int in anim.get_track_count():
			var path: NodePath = anim.track_get_path(t)
			if String(path.get_concatenated_names()) != "%GeneralSkeleton" or profile.find_bone(path.get_concatenated_subnames()) < 0:
				bad.append(String(path))
		assert_eq(bad, [] as Array[String], "%s tracks" % clip)


func test_no_clip_moves_the_root() -> void:
	for clip: StringName in _lib.get_animation_list():
		var anim: Animation = _lib.get_animation(clip)
		assert_eq(anim.find_track(^"%GeneralSkeleton:Root", Animation.TYPE_POSITION_3D), -1, "%s has no root motion" % clip)


func test_loops_stay_in_place() -> void:
	# Hips positions are stored divided by the skeleton's motion scale (the
	# hips' height, about 0.93 m); 0.05 is about 5 cm.
	for clip: StringName in LOOPING + FALLBACK_LOOPING:
		if not _lib.has_animation(clip):
			continue
		var anim: Animation = _lib.get_animation(clip)
		var t: int = anim.find_track(^"%GeneralSkeleton:Hips", Animation.TYPE_POSITION_3D)
		if t < 0:
			continue
		var first: Vector3 = anim.track_get_key_value(t, 0)
		var last: Vector3 = anim.track_get_key_value(t, anim.track_get_key_count(t) - 1)
		assert_lt(Vector2(last.x - first.x, last.z - first.z).length(), 0.05, "%s ends where it starts" % clip)
