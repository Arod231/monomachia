extends GutTest
## Foot locking (FootLock, authored-animation task 8): a planted foot stays
## where it landed under the clip, and is let go when the clip lifts it,
## carries it off or out of reach. Through task 1's Iglesias clips (local
## only) and a CC0 clip, planted feet move under 1 cm on both fighters.

const SIDES: Array[String] = ["Right", "Left"]
const NEAR: float = 0.01
const TASK1_CLIPS: Array[StringName] = [&"CombatIdle1H01", &"Attack1H01_R", &"Attack2H01", &"Roll01", &"CombatDeath01", &"Dodge01"]


static func _lock() -> FootLock:
	return FootLock.new({"Right": 0.1, "Left": 0.1} as Dictionary[String, float])


static func _step(lock: FootLock, frame: int, right: Vector3, left: Vector3 = Vector3(-0.2, 0.1, 0.0)) -> void:
	var hips: Dictionary[String, Vector3] = {"Right": Vector3(0.1, 0.95, 0.0), "Left": Vector3(-0.1, 0.95, 0.0)}
	lock.update(frame, {"Right": right, "Left": left} as Dictionary[String, Vector3], hips, {"Right": 0.9, "Left": 0.9} as Dictionary[String, float])


func test_a_planted_foot_stays_where_it_landed() -> void:
	var lock: FootLock = _lock()
	var landed: Vector3 = Vector3(0.2, 0.1, 0.1)
	_step(lock, 1, landed)
	assert_true(lock.holds("Right"), "planted at its rest height")
	for i: int in 5:
		# the clip creeps it 1 cm a frame
		var creep: Vector3 = landed + Vector3(0.0, 0.0, 0.01 * (i + 1))
		_step(lock, 2 + i, creep)
		assert_eq(lock.target("Right", creep), landed, "frame %d: held where it landed" % (2 + i))


func test_a_lifted_foot_eases_back_onto_the_clip() -> void:
	var lock: FootLock = _lock()
	var landed: Vector3 = Vector3(0.2, 0.1, 0.1)
	_step(lock, 1, landed)
	var lifted: Vector3 = landed + Vector3(0.0, 0.08, 0.05)
	_step(lock, 2, lifted)
	assert_false(lock.holds("Right"), "let go when lifted")
	assert_almost_eq(lock.hold["Right"], 0.75, 1e-9, "easing out over 4 frames")
	assert_eq(lock.target("Right", lifted), lifted.lerp(landed, 0.75))
	for i: int in 3:
		_step(lock, 3 + i, lifted)
	assert_eq(lock.target("Right", lifted), lifted, "back on the clip")
	assert_false(lock.held.has("Right"))


func test_a_foot_is_let_go_when_carried_off_or_out_of_reach() -> void:
	var lock: FootLock = _lock()
	_step(lock, 1, Vector3(0.2, 0.1, 0.1))
	_step(lock, 2, Vector3(0.2, 0.1, 0.1 + FootLock.SLIDE + 0.01))
	assert_false(lock.holds("Right"), "a slide the clip means")
	lock = _lock()
	_step(lock, 1, Vector3(0.2, 0.1, 0.1))
	var hips: Dictionary[String, Vector3] = {"Right": Vector3(0.1, 1.2, 0.0), "Left": Vector3(-0.1, 1.2, 0.0)}
	lock.update(2, {"Right": Vector3(0.2, 0.1, 0.1), "Left": Vector3(-0.2, 0.1, 0.0)} as Dictionary[String, Vector3], hips,
		{"Right": 0.9, "Left": 0.9} as Dictionary[String, float])
	assert_false(lock.holds("Right"), "the hips rose out of the leg's reach")


func test_a_frame_seen_again_and_switching_off() -> void:
	var lock: FootLock = _lock()
	_step(lock, 1, Vector3(0.2, 0.1, 0.1))
	_step(lock, 1, Vector3(0.2, 0.3, 0.1))
	assert_true(lock.holds("Right"), "hit-stop: the same frame changes nothing")
	lock.enabled = false
	_step(lock, 2, Vector3(0.2, 0.1, 0.1))
	assert_almost_eq(lock.hold["Right"], 0.75, 1e-9, "switched off: eases out")
	lock.enabled = true
	_step(lock, 3, Vector3(0.2, 0.1, 0.12))
	assert_true(lock.holds("Right"), "planted again")
	assert_eq(lock.held["Right"], Vector3(0.2, 0.1, 0.12).lerp(Vector3(0.2, 0.1, 0.1), 0.75), "held where it showed: no jump")


## Plays `anim_name` on `f` a source frame per rules frame with the foot
## lock on, and returns the worst move of a held foot between two frames it
## stays held, the share of frames each foot is held, and the worst creep of
## a planted foot without the lock (all by side).
func _walk_clip(f: FighterModel, anim_name: String) -> Dictionary:
	var sk: Skeleton3D = f.skeleton
	var rig: FighterRig = f.rig
	rig.leg_weight = 1.0
	rig.clip_feet = 1.0
	var lock: FootLock = rig.new_foot_lock()
	rig.foot_lock = lock
	var length: float = f.animation_player.get_animation(anim_name).length
	var frames: int = int(length * 30.0)
	var worst: Dictionary[String, float] = {"Right": 0.0, "Left": 0.0}
	var held: Dictionary[String, int] = {"Right": 0, "Left": 0}
	var last: Dictionary[String, Vector3] = {}
	var was: Dictionary[String, bool] = {}
	for i: int in frames + 1:
		rig.rules_frame = i
		var feet: Dictionary[String, Vector3] = {}
		var grab: Callable = func() -> void:
			for side: String in SIDES:
				feet[side] = sk.get_bone_global_pose(sk.find_bone(side + "Foot")).origin
		(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(grab, CONNECT_ONE_SHOT)
		f.animation_player.play(anim_name, 0.0)
		f.animation_player.seek(i / 30.0, true)
		f.animation_player.pause()
		sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
		for side: String in SIDES:
			var now: bool = lock.holds(side)
			if now:
				held[side] += 1
				if was.get(side, false):
					worst[side] = maxf(worst[side], feet[side].distance_to(last[side]))
			was[side] = now
			last[side] = feet[side]
	rig.foot_lock = null
	return {"worst": worst, "share": {"Right": float(held["Right"]) / (frames + 1), "Left": float(held["Left"]) / (frames + 1)}}


func _fighter(id: StringName) -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(id)
	f.autoplay_idle = false
	add_child_autofree(f)
	f.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	return f


func test_planted_feet_stay_put_through_a_cc0_clip() -> void:
	for id: StringName in FighterLook.IDS:
		var got: Dictionary = _walk_clip(_fighter(id), "ual/Sword_Attack")
		for side: String in SIDES:
			assert_lt(got["worst"][side], NEAR, "%s %s foot: %.2f cm while held" % [id, side, got["worst"][side] * 100.0])
		assert_gt(got["share"]["Right"] + got["share"]["Left"], 0.5, "%s: the feet are held much of the clip" % id)


func test_local_planted_feet_stay_put_through_task_1s_clips() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	for id: StringName in FighterLook.IDS:
		var set_name: StringName = ClipLibraries.FIGHTER_SETS[id]
		var f: FighterModel = _fighter(id)
		f.animation_player.add_animation_library(set_name, ClipLibraries.load_set(set_name))
		for clip: StringName in TASK1_CLIPS:
			var got: Dictionary = _walk_clip(f, "%s/%s" % [set_name, clip])
			for side: String in SIDES:
				assert_lt(got["worst"][side], NEAR, "%s %s, %s foot: %.2f cm while held (held %d%% of it)" % [
					id, clip, side, got["worst"][side] * 100.0, roundi(got["share"][side] * 100.0)])
			gut.p("%s %s: feet held %d%% and %d%% of the clip" % [id, clip, roundi(got["share"]["Right"] * 100.0), roundi(got["share"]["Left"] * 100.0)])
