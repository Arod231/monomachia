extends GutTest
## Swing playback (plan task 14.10): a move with a swing places the weapon
## exactly where the rules' swing has it at the frame shown, the arms reach
## for it, and the root stays the rules'. The swings are synthetic
## (tests/sim/swing_fixtures.gd) on fresh copies of the weapons.

const SF := preload("res://tests/sim/swing_fixtures.gd")
## How close the shown weapon must be to the sample: 1 mm and 0.5°.
const NEAR_POS: float = 0.001
const NEAR_DEG: float = 0.5


func after_each() -> void:
	SimHelpers.dispose_all()


func _view(fighter_id: StringName, weapon: WeaponDef) -> FighterView:
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(fighter_id, 0, weapon.id, 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	return v


## A copy of weapon `id` whose light start has a level slash.
static func _slashing(id: StringName) -> WeaponDef:
	var start: StringName = (Moves.WEAPONS[id] as WeaponDef).light_start
	var move: AttackDef = (Moves.WEAPONS[id] as WeaponDef).moves[start]
	return SF.weapon(id, {start: SF.level_slash(move)} as Dictionary[StringName, Swing])


## How far the shown weapon `index` is from `s` (a hand track's sample):
## the grip's miss (m) and the worst of the blade's and the edge's turn
## (degrees), worked from the sample by hand, not through SwingPlayer.
func _miss(v: FighterView, index: int, s: Swing.Sample) -> Vector2:
	var xf: Transform3D = v.model.weapons[index].transform
	var grip: Vector3 = Vector3(-s.grip.x, s.grip.y, s.grip.z)
	var blade: Vector3 = Vector3(-s.blade.x, s.blade.y, s.blade.z)
	var edge: Vector3 = Vector3(-s.edge.x, s.edge.y, s.edge.z)
	var turn: float = maxf(xf.basis.y.angle_to(blade), xf.basis.x.angle_to(edge))
	return Vector2(xf.origin.distance_to(grip), rad_to_deg(turn))


## Plays the light start of `weapon` on fighter `fighter_id`, showing every
## step at alpha 1 and halfway between steps, and returns the worst miss of
## the right hand's weapon from the swing's sample at the frame shown.
func _play_and_miss(fighter_id: StringName, weapon: WeaponDef) -> Vector2:
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(fighter_id, weapon)
	var swing: Swing = (weapon.moves[weapon.light_start] as AttackDef).swing
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	var worst: Vector2 = Vector2.ZERO
	var frames: int = 0
	while f.state == &"attack" and frames < 120:
		for alpha: float in [0.5, 1.0]:
			v.update_from(f, Vector3.ZERO, 0.0, alpha, 1.0 / 60.0, 0.0)
			var t: float = maxf(0.0, float(f.atk.frame) - 1.0 + alpha)
			var miss: Vector2 = _miss(v, 0, swing.sample(SF.RIGHT, t))
			worst = Vector2(maxf(worst.x, miss.x), maxf(worst.y, miss.y))
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		frames += 1
	assert_gt(frames, 20, "%s %s: the whole move played" % [fighter_id, weapon.id])
	return worst


func test_the_shown_weapon_is_the_swing_at_every_frame() -> void:
	for pair: Array in [[&"hunter", &"greatsword"], [&"rogue", &"katana"], [&"rogue", &"daggers"], [&"hunter", &"katana"]]:
		var miss: Vector2 = _play_and_miss(pair[0], _slashing(pair[1]))
		assert_lt(miss.x, NEAR_POS, "%s %s: the grip is the swing's (%.2f mm off)" % [pair[0], pair[1], miss.x * 1000.0])
		assert_lt(miss.y, NEAR_DEG, "%s %s: the blade and edge are the swing's (%.2f° off)" % [pair[0], pair[1], miss.y])


## A follow-up enters from the hand-off of the move before, as the rules'
## swing does.
func test_a_follow_up_plays_its_chained_entry() -> void:
	var cut: AttackDef = Moves.GREATSWORD.moves[&"g_l1"]
	var back: AttackDef = Moves.GREATSWORD.moves[&"g_l2"]
	var first: Swing = SF.level_slash(cut)
	var second: Swing = SF.level_slash(back, 1.2, -60.0, 60.0)
	var weapon: WeaponDef = SF.weapon(&"greatsword", {&"g_l1": first, &"g_l2": second} as Dictionary[StringName, Swing])
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", weapon)
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	var steps: int = 0
	while not (f.state == &"attack" and f.atk.def.id == &"g_l2") and steps < 80:
		W.step([SimHelpers.btn(Btn.LIGHT) if steps % 2 == 0 else SimHelpers.idle(), SimHelpers.idle()])
		steps += 1
	assert_eq(f.atk.def.id, &"g_l2", "the follow-up started")
	assert_eq(f.atk.chained_from, weapon.moves[&"g_l1"], "following Heavy Swing")
	var compared: int = 0
	while f.state == &"attack" and f.atk.frame <= back.startup:
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
		var miss: Vector2 = _miss(v, 0, second.sample(SF.RIGHT, float(f.atk.frame), first))
		assert_lt(miss.x, NEAR_POS, "frame %d: the chained entry's grip" % f.atk.frame)
		assert_lt(miss.y, NEAR_DEG, "frame %d: the chained entry's blade" % f.atk.frame)
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		compared += 1
	assert_gt(compared, 5, "the entry was shown")
	assert_ne(second.sample(SF.RIGHT, 1.0, first).grip.x, second.sample(SF.RIGHT, 1.0).grip.x,
			"the chained entry differs from the guard's, so the test can tell them apart")


## The frame shown: between steps by alpha, from 0, and the frame itself
## while charging, as the rules hold the blade.
func test_the_frame_shown_follows_alpha_and_holds_in_a_charge() -> void:
	var W: World = SimHelpers.make_world(_slashing(&"katana"), Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	var at: int = f.atk.frame
	assert_almost_eq(SwingPlayer.swing_frame(f, 0.25), float(at) - 0.75, 1e-9)
	assert_almost_eq(SwingPlayer.swing_frame(f, 1.0), float(at), 1e-9)
	f.atk.frame = 0
	assert_eq(SwingPlayer.swing_frame(f, 0.5), 0.0, "never before the first frame")
	f.atk.frame = 9
	f.atk.charging = true
	assert_eq(SwingPlayer.swing_frame(f, 0.25), 9.0, "held at the charge's frame")


## The root stays where the rules put the fighter, and the stand-in's lean,
## crouch and spin are left out of a swing.
func test_the_root_and_body_stay_the_rules() -> void:
	var weapon: WeaponDef = _slashing(&"greatsword")
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", weapon)
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	for i: int in 16:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		assert_eq(v.position, Vector3(f.pos.x, f.pos.y, f.pos.z), "frame %d: at the rules' position" % f.atk.frame)
		assert_eq(v.model.rotation, Vector3.ZERO, "frame %d: no spin" % f.atk.frame)
		assert_almost_eq(v.model.rig.body.spine_pitch, 0.0, 1e-9, "frame %d: no stand-in lean" % f.atk.frame)
	assert_ne(v.last_pose.lean, 0.0, "the stand-in would have leaned")


## A weapon held in both hands puts the off hand on its off-hand grip, and
## both hands land on the posed weapon wherever their arms reach it (the
## level slash, made for the Katana, takes the Hunter's right hand past its
## reach across the body).
func test_both_hands_grip_a_swung_greatsword() -> void:
	var weapon: WeaponDef = _slashing(&"greatsword")
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", weapon)
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	var worst: float = 0.0
	var reached: int = 0
	while f.state == &"attack":
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
		assert_true(v.model.rig.drives("Right") and v.model.rig.drives("Left"), "frame %d: both hands on it" % f.atk.frame)
		var poses: Array[Transform3D] = await _posed(v)
		for side: String in FighterRig.SIDES:
			var shoulder: Vector3 = poses[v.model.skeleton.find_bone(side + "UpperArm")].origin
			if shoulder.distance_to(v.model.rig.hand_frame(side).origin) > 0.98 * v.model.rig.arm_length(side):
				continue
			reached += 1
			var fist: Vector3 = poses[v.model.skeleton.find_bone(side + "Hand")] * v.model.rig.fist(side).origin
			worst = maxf(worst, fist.distance_to(v.model.rig.grip_point(side)))
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	assert_gt(reached, 40, "most frames are within reach")
	assert_lt(worst, 0.01, "the fists land on the grips they reach (%.1f mm off at worst)" % (worst * 1000.0))


## Moves without a swing, and a dagger with no track of its own, stay on
## the stand-in pose.
func test_moves_without_a_swing_keep_the_stand_in() -> void:
	var weapon: WeaponDef = _slashing(&"daggers")
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", weapon)
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	assert_true(SwingPlayer.plays(f))
	assert_almost_eq(v.model.weapons[1].transform.basis.y, v.last_pose.left.dir, Vector3.ONE * 1e-4,
			"the left dagger, with no track, follows the stand-in")
	# the Daggers with their swings taken off (their lights are baked since
	# authored animation 21)
	var plain: World = SimHelpers.make_world(SF.without_swings(&"daggers"), Moves.KATANA, 3.0)
	plain.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	plain.step([SimHelpers.idle(), SimHelpers.idle()])
	assert_false(SwingPlayer.plays(plain.fighters[0]), "Daggers without swings keep the stand-in")


## The key's elbow-pole tweak goes on the rig for the hand it moves.
func test_the_elbow_pole_tweak_reaches_the_rig() -> void:
	var start: AttackDef = Moves.KATANA.moves[&"k_l1"]
	var swing: Swing = SF.level_slash(start)
	for k: Swing.KeyPose in swing.track(SF.RIGHT):
		k.pole = V3.make(0.3, 0.1, -0.2)
	swing = _rebuilt(swing, start)
	var weapon: WeaponDef = SF.weapon(&"katana", {&"k_l1": swing} as Dictionary[StringName, Swing])
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", weapon)
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	for i: int in start.startup:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	assert_almost_eq(v.model.rig.pole_tweak["Right"], Vector3(-0.3, 0.1, -0.2), Vector3.ONE * 1e-6,
			"turned into skeleton space")
	assert_eq(v.model.rig.pole_tweak["Left"], Vector3.ZERO, "none for the other hand")
	f.set_state(&"free")
	v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	assert_eq(v.model.rig.pole_tweak["Right"], Vector3.ZERO, "cleared out of the swing")


## The same keys in a fresh swing, so its tables hold the changed keys.
static func _rebuilt(swing: Swing, move: AttackDef) -> Swing:
	var out: Swing = Swing.new(move.total_frames(), swing.guard)
	for part: StringName in swing.parts():
		out.add_track(part, swing.track(part))
	return out


## Steps the model's skeleton once and returns every bone's pose in skeleton
## space at the end of the modifier stack.
func _posed(v: FighterView) -> Array[Transform3D]:
	var sk: Skeleton3D = v.model.skeleton
	var poses: Array[Transform3D] = []
	var grab: Callable = func() -> void:
		poses.clear()
		for i: int in sk.get_bone_count():
			poses.append(sk.get_bone_global_pose(i))
	(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(grab, CONNECT_ONE_SHOT)
	sk.advance(1.0 / 60.0)
	if poses.is_empty():
		await wait_process_frames(1)
	return poses


# ------------------------------------------------------------ chains (14.11)

## A copy of weapon `id` whose lights `moves` have level slashes, each the
## other way from the one before, the third lower.
static func _string_weapon(id: StringName, moves: Array[StringName]) -> WeaponDef:
	var w: WeaponDef = Moves.WEAPONS[id]
	var swings: Dictionary[StringName, Swing] = {}
	for i: int in moves.size():
		var move: AttackDef = w.moves[moves[i]]
		var height: float = 1.0 if i == 2 else 1.2
		swings[moves[i]] = SF.level_slash(move, height) if i % 2 == 0 else SF.level_slash(move, height, -60.0, 60.0)
	return SF.weapon(id, swings)


## Plays `lights` lights of fighter 0's string from the guard (pressing the
## light until that many moves have started), showing the fighter at alpha 1
## after every step, `before` steps of standing in the guard first, and
## `after` steps once the string is over. One record per step: "move" (the
## move id, or &"" out of an attack), "frame" and "grip" (the shown grip).
func _play_string(v: FighterView, W: World, lights: int, before: int = 6, after: int = 12) -> Array[Dictionary]:
	var f: Fighter = W.fighters[0]
	var out: Array[Dictionary] = []
	var started: Array[AttackState] = []
	var idle_after: int = 0
	var steps: int = 0
	while steps < 400:
		var press: bool = steps >= before and started.size() < lights and steps % 2 == 0
		W.step([SimHelpers.btn(Btn.LIGHT) if press else SimHelpers.idle(), SimHelpers.idle()])
		steps += 1
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
		var attacking: bool = f.state == &"attack"
		if attacking and not started.has(f.atk):
			started.append(f.atk)
		out.append({"move": f.atk.def.id if attacking else &"", "frame": f.atk.frame if attacking else 0,
				"grip": v.model.weapons[0].transform.origin})
		if not attacking and not started.is_empty():
			idle_after += 1
			if idle_after > after:
				break
	assert_eq(started.size(), lights, "%d lights played" % lights)
	return out


## The most a swing's own right-hand grip moves in a frame between frames
## `from` and `to`, entered from `chained_from`.
static func _own_speed(swing: Swing, from: int, to: int, chained_from: Swing = null) -> float:
	var most: float = 0.0
	for t: int in range(maxi(from, 0), mini(to, swing.last_frame)):
		var a: V3 = swing.sample(SF.RIGHT, float(t), chained_from).grip
		var b: V3 = swing.sample(SF.RIGHT, float(t + 1), chained_from).grip
		most = maxf(most, V3.length(V3.sub(b, a)))
	return most


static func _skeleton(v: V3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## A weapon with swings stands in their guard. Without a stance under it
## (the Greatsword) that is the guard exactly, so an opener plays exactly
## from its first frame: there is no gap to blend.
func test_an_opener_starts_from_the_guard_it_stands_in() -> void:
	var weapon: WeaponDef = _slashing(&"greatsword")
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", weapon)
	var guard: Swing.KeyPose = SF.slash_guard()
	for i: int in 4:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	var held: Swing.Sample = Swing.Sample.new()
	held.grip = guard.grip
	held.blade = guard.blade
	held.edge = guard.edge
	var miss: Vector2 = _miss(v, 0, held)
	assert_lt(miss.x, NEAR_POS, "in the swings' guard")
	assert_lt(miss.y, NEAR_DEG, "turned as the guard is")
	var swing: Swing = (weapon.moves[weapon.light_start] as AttackDef).swing
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	while f.state == &"attack":
		for alpha: float in [0.5, 1.0]:
			v.update_from(f, Vector3.ZERO, 0.0, alpha, 1.0 / 60.0, 0.0)
			var at: Vector2 = _miss(v, 0, swing.sample(SF.RIGHT, SwingPlayer.swing_frame(f, alpha)))
			assert_lt(at.x, NEAR_POS, "frame %d alpha %.1f: the swing exactly" % [f.atk.frame, alpha])
		W.step([SimHelpers.idle(), SimHelpers.idle()])


## Under the Katana's stance the guard rides the lowered pelvis (the
## stand-in's guard is gone); the opener blends from it into the swing over
## at most BLEND_FRAMES frames, then plays it exactly.
func test_the_guard_rides_the_stance_and_the_opener_blends_from_it() -> void:
	var weapon: WeaponDef = _slashing(&"katana")
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", weapon)
	for i: int in 4:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	var guard: Transform3D = SwingPlayer.guard_poses(weapon, 1)[0]
	var shown: Transform3D = v.model.weapons[0].transform
	assert_lt(rad_to_deg(shown.basis.y.angle_to(guard.basis.y)), NEAR_DEG, "the guard's blade")
	assert_gt(shown.origin.distance_to(guard.origin), 0.05, "riding the stance's lowered pelvis")
	assert_almost_eq(shown.origin.y, guard.origin.y - GuardStance.CROUCH, 0.04, "about as low as the stance")
	var swing: Swing = (weapon.moves[weapon.light_start] as AttackDef).swing
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	var before: Vector3 = shown.origin
	var exact_from: int = -1
	while f.state == &"attack":
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
		var now: Vector3 = v.model.weapons[0].transform.origin
		var own: float = _own_speed(swing, f.atk.frame - 2, f.atk.frame)
		assert_lt(now.distance_to(before), own + GuardStance.CROUCH * 0.5,
				"frame %d: no jump (moved %.1f cm)" % [f.atk.frame, now.distance_to(before) * 100.0])
		before = now
		var miss: Vector2 = _miss(v, 0, swing.sample(SF.RIGHT, float(f.atk.frame)))
		if exact_from < 0 and miss.x < NEAR_POS and miss.y < NEAR_DEG:
			exact_from = f.atk.frame
		elif exact_from >= 0:
			assert_lt(miss.x, NEAR_POS, "frame %d: the swing exactly once blended" % f.atk.frame)
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	assert_between(exact_from, 2, int(SwingPlayer.BLEND_FRAMES) + 1, "blended over the first frames only")


## Through the Katana's L-L-L-L and the strings stopped after one, two and
## three lights, the shown grip moves no more in a frame at a chain point
## than the swings around it move on their own, though a follow-up's entry
## starts from the hand-off key, which the move before had not reached (the
## opener also closes the gap from the guard riding the stance); a stopped
## string runs its exit to the guard, then blends to the guard as it rides
## the stance, without a jump. The exit reaches the guard on the move's last
## frame, which the rules never show: the attack ends on the step that
## reaches it, so the last frame shown is a frame short of the guard.
func test_strings_never_jump_and_a_stopped_string_ends_on_the_guard() -> void:
	var lights: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3", &"k_l4"]
	var largest_gap: float = 0.0
	var played_lights: int = 0
	for n: int in [1, 2, 3, 4]:
		var weapon: WeaponDef = _string_weapon(&"katana", lights)
		var chain: Array[StringName] = []
		var id: StringName = weapon.light_start
		while id != &"" and weapon.moves.has(id) and chain.size() < n:
			chain.append(id)
			id = (weapon.moves[id] as AttackDef).chain_light
		if chain.size() < n:
			continue
		played_lights = n
		var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
		var v: FighterView = _view(&"rogue", weapon)
		var played: Array[Dictionary] = _play_string(v, W, n)
		for i: int in range(1, played.size()):
			var was: Dictionary = played[i - 1]
			var now: Dictionary = played[i]
			if now["move"] == &"" or now["move"] == was["move"]:
				continue
			var swing: Swing = (weapon.moves[now["move"]] as AttackDef).swing
			var from: Swing = (weapon.moves[was["move"]] as AttackDef).swing if was["move"] != &"" else null
			var at: int = now["frame"]
			var own: float = _own_speed(swing, at - 1, at, from)
			var allow: float = 0.005 if from != null else 0.005 + GuardStance.CROUCH * 0.5
			if from != null:
				var last: int = was["frame"]
				own = maxf(own, _own_speed(from, last - 1, last))
				var raw: float = (was["grip"] as Vector3).distance_to(_skeleton(swing.sample(SF.RIGHT, float(now["frame"]), from).grip))
				largest_gap = maxf(largest_gap, raw - own)
			var moved: float = (now["grip"] as Vector3).distance_to(was["grip"])
			assert_lt(moved, own + allow, "L x%d, into %s: moved %.1f cm, its swings %.1f cm a frame" % [n, now["move"], moved * 100.0, own * 100.0])
		var guard: Transform3D = SwingPlayer.guard_poses(weapon, 1)[0]
		var last_attack: int = -1
		for i: int in played.size():
			if played[i]["move"] != &"":
				last_attack = i
		var ender: Swing = (weapon.moves[played[last_attack]["move"]] as AttackDef).swing
		var short: float = _own_speed(ender, ender.last_frame - 1, ender.last_frame)
		assert_eq(played[last_attack]["frame"], ender.last_frame - 1, "L x%d: the last frame shown" % n)
		assert_lt((played[last_attack]["grip"] as Vector3).distance_to(guard.origin), short + NEAR_POS,
				"L x%d: a frame of its exit short of the guard" % n)
		var settle: float = (played[-1]["grip"] as Vector3).distance_to(played[last_attack]["grip"])
		for i: int in range(last_attack + 1, played.size()):
			var moved: float = (played[i]["grip"] as Vector3).distance_to(played[i - 1]["grip"])
			assert_lt(moved, 0.6 * settle + 0.005, "L x%d: then on to the guard riding the stance over a few frames, no jump (%.1f of %.1f cm)" % [
					n, moved * 100.0, settle * 100.0])
		assert_almost_eq((played[-1]["grip"] as Vector3).y, guard.origin.y - GuardStance.CROUCH, 0.04, "L x%d: riding it" % n)
	assert_gt(played_lights, 1, "the string has follow-ups")
	assert_gt(largest_gap, 0.008, "some follow-up's entry started away from the shown grip, so the test can fail")


## A swing cut off by a dodge (the stand-in's pose takes over) blends out
## rather than jumping to the stand-in.
func test_a_cut_off_swing_blends_out() -> void:
	var weapon: WeaponDef = _slashing(&"katana")
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", weapon)
	var cut: AttackDef = weapon.moves[weapon.light_start]
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	while f.state == &"attack" and f.atk.frame < cut.dodge_cancel_from + 1:
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	var before: Vector3 = v.model.weapons[0].transform.origin
	W.step([SimHelpers.move(1.0, 0.0, Btn.DODGE), SimHelpers.idle()])
	assert_ne(f.state, &"attack", "the dodge cut the swing off")
	v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	var after: Vector3 = v.model.weapons[0].transform.origin
	var gap: float = before.distance_to(v.last_pose.right.pos)
	assert_gt(gap, 0.1, "the stand-in's pose is far from the swing's")
	assert_lt(after.distance_to(before), 0.2 * gap, "the first frame closes a fifth of the gap at most (%.1f of %.1f cm)" % [
			after.distance_to(before) * 100.0, gap * 100.0])
	for i: int in int(SwingPlayer.BLEND_FRAMES) + 1:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	assert_true(v.swing_player.settled(), "blended out within BLEND_FRAMES")


# ------------------------------------------------------------ the body (14.12)

## A cut for `move` whose hand and body tracks key the same frames: cocked
## 60° to the right with the chest coiled 45° and the pelvis 25° that way and
## the weight 6 cm back, the grip 35 cm out (well within reach, so the fist
## stays on it), held from S - 4 to S - 1 (ease 0), then through
## -10° at the middle of the cut to -80° three frames after the active ones,
## the chest at -30° and the weight 6 cm forward, settling there (ease 0).
## Keyed alike, the hand's and the body's speeds peak together, at the middle.
static func _coiled_cut(move: AttackDef) -> Swing:
	var S: int = move.startup
	var end: int = S + move.active + 3
	var mid: int = (S - 1 + end) / 2
	var guard: Dictionary[StringName, Swing.KeyPose] = {SF.RIGHT: SF.slash_guard(), &"body": SF.body_key(0, 0.0, 0.0)}
	var out: Swing = Swing.new(move.total_frames(), guard)
	out.add_track(SF.RIGHT, [SF.level_pose(S - 4, 1.2, 60.0, 0.0, 0.35), SF.level_pose(S - 1, 1.2, 60.0, 0.0, 0.35),
			SF.level_pose(mid, 1.2, -10.0), SF.level_pose(end, 1.2, -80.0, 0.0)] as Array[Swing.KeyPose])
	var back: V3 = V3.make(0.0, 0.0, -0.06)
	out.add_track(&"body", [_shifted(SF.body_key(S - 4, 45.0, 25.0, 0.0), back), _shifted(SF.body_key(S - 1, 45.0, 25.0, 0.0), back),
			SF.body_key(mid, 7.5, 5.0), _shifted(SF.body_key(end, -30.0, -15.0, 0.0), V3.make(0.0, 0.0, 0.06))] as Array[Swing.KeyPose])
	return out


static func _shifted(k: Swing.KeyPose, shift: V3) -> Swing.KeyPose:
	k.pelvis_shift = shift
	return k


## A copy of weapon `id` whose light start is _coiled_cut().
static func _coiling(id: StringName) -> WeaponDef:
	var w: WeaponDef = Moves.WEAPONS[id]
	return SF.weapon(id, {w.light_start: _coiled_cut(w.moves[w.light_start])} as Dictionary[StringName, Swing])


## Plays the light start of `weapon` on `fighter_id` from the guard, showing
## `per_frame` moments per attack frame on the posed skeleton, and returns
## one record per moment: "t" (the swing's frame shown), "hips", "chest" and
## "head" (headings, degrees, + to the fighter's left), "hips_at" (the hips
## bone's place), "clip_hips" (the middle of the clip's hip joints, before
## the body layer moves them), "hand" (the right hand bone's) and "blade"
## (the weapon's).
func _play_posed(fighter_id: StringName, weapon: WeaponDef, per_frame: int = 1) -> Array[Dictionary]:
	var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(fighter_id, weapon)
	var sk: Skeleton3D = v.model.skeleton
	for i: int in 4:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
		await _posed(v)
	var out: Array[Dictionary] = [await _record(v, f, sk, -1.0)]
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	while f.state == &"attack":
		for j: int in per_frame:
			var alpha: float = float(j + 1) / float(per_frame)
			v.update_from(f, Vector3.ZERO, 0.0, alpha, 1.0 / 60.0, 0.0)
			out.append(await _record(v, f, sk, SwingPlayer.swing_frame(f, alpha)))
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	return out


func _record(v: FighterView, f: Fighter, sk: Skeleton3D, t: float) -> Dictionary:
	var poses: Array[Transform3D] = await _posed(v)
	var heading: Callable = func(bone: String) -> float:
		var id: int = sk.find_bone(bone)
		return rad_to_deg(BodyLayer.heading(sk, id, poses[id]))
	return {"t": t, "hips": heading.call("Hips"), "chest": heading.call("UpperChest"), "head": heading.call("Head"),
			"hips_at": poses[sk.find_bone("Hips")].origin, "clip_hips": (v.model.rig.body.clip_hips["Right"] + v.model.rig.body.clip_hips["Left"]) * 0.5, "hand": poses[sk.find_bone("RightHand")] * v.model.rig.fist("Right").origin,
			"wrist": poses[sk.find_bone("RightHand")].origin,
			"blade": v.model.weapons[0].transform.basis.y}


## The moment `key` turns fastest at, in the records from frame `from` on.
static func _peak(rec: Array[Dictionary], key: String, from: float) -> float:
	var best: float = -1.0
	var at: float = -1.0
	for i: int in range(1, rec.size()):
		if rec[i - 1]["t"] < from:
			continue
		var dt: float = rec[i]["t"] - rec[i - 1]["t"]
		if dt <= 0.0:
			continue
		var turn: float
		if key == "blade":
			turn = rad_to_deg((rec[i]["blade"] as Vector3).angle_to(rec[i - 1]["blade"]))
		else:
			turn = absf(angle_difference(deg_to_rad(rec[i][key]), deg_to_rad(rec[i - 1][key])))
		if turn / dt > best:
			best = turn / dt
			at = (rec[i]["t"] + rec[i - 1]["t"]) / 2.0
	return at


static func _at(rec: Array[Dictionary], t: float) -> Dictionary:
	for r: Dictionary in rec:
		if absf(r["t"] - t) < 1e-6:
			return r
	return {}


## The hips turn first, then the chest, then the blade: on a cut whose hand
## and body are keyed alike, the hips' turning peaks PELVIS_LEAD frames
## before the blade's and the chest's CHEST_LEAD before, on the skeleton.
func test_the_hips_lead_the_chest_lead_the_blade() -> void:
	var weapon: WeaponDef = _coiling(&"katana")
	var cut: AttackDef = weapon.moves[weapon.light_start]
	var rec: Array[Dictionary] = await _play_posed(&"rogue", weapon, 4)
	var from: float = float(cut.startup - 3)
	var hips: float = _peak(rec, "hips", from)
	var chest: float = _peak(rec, "chest", from)
	var blade: float = _peak(rec, "blade", from)
	assert_lt(hips, chest, "the hips peak (frame %.2f) before the chest (%.2f)" % [hips, chest])
	assert_lt(chest, blade, "the chest peaks (frame %.2f) before the blade (%.2f)" % [chest, blade])
	assert_almost_eq(blade - hips, SwingPlayer.PELVIS_LEAD, 0.75, "the hips about two frames ahead")


## The keys' coil shows on the skeleton: cocked, the chest is turned about
## 45° to the right and the hips about 25°, and the head turns back against
## the chest to keep watching the opponent.
func test_the_coil_and_the_head_show_on_the_skeleton() -> void:
	var weapon: WeaponDef = _coiling(&"greatsword")
	var cut: AttackDef = weapon.moves[weapon.light_start]
	var rec: Array[Dictionary] = await _play_posed(&"hunter", weapon)
	var still: Dictionary = rec[0]
	var cocked: Dictionary = _at(rec, float(cut.startup - 3))
	var chest: float = cocked["chest"] - still["chest"]
	assert_almost_eq(chest, -45.0, 4.0, "the chest coiled 45° to the right (%.1f°)" % chest)
	assert_almost_eq(cocked["hips"] - still["hips"], -25.0, 4.0, "the hips 25° (%.1f°)" % (cocked["hips"] - still["hips"]))
	var head: float = cocked["head"] - still["head"]
	assert_almost_eq(head, chest * 0.15, 3.0, "the head turned back about 85%% of the way (%.1f°)" % head)


## The weight goes back over the rear foot in the wind-up and the pelvis
## dips about 5 cm at contact, on the skeleton.
func test_the_weight_shifts_back_and_the_pelvis_dips_at_contact() -> void:
	var weapon: WeaponDef = _coiling(&"greatsword")
	var cut: AttackDef = weapon.moves[weapon.light_start]
	var rec: Array[Dictionary] = await _play_posed(&"hunter", weapon)
	# the swing's own shift: the hips from where the idle clip under it has
	# them, which breathes on its own
	var shift: Callable = func(r: Dictionary) -> Vector3: return (r["hips_at"] as Vector3) - (r["clip_hips"] as Vector3)
	var still: Vector3 = shift.call(rec[0])
	var cocked: Vector3 = shift.call(_at(rec, float(cut.startup - 3)))
	assert_almost_eq(cocked.z - still.z, -0.06, 0.01, "6 cm back over the rear foot")
	var contact: Vector3 = shift.call(_at(rec, float(cut.startup + 1)))
	var before: Vector3 = shift.call(_at(rec, float(cut.startup + 1) - SwingPlayer.DIP_FRAMES))
	assert_almost_eq(contact.y - before.y, -0.05, 0.01, "dipped about 5 cm at contact (%.1f cm)" % ((contact.y - before.y) * 100.0))


## A 2-4 frame cocked hold shows on the skeleton: the hand stays still while
## the hips and chest already begin to turn into the cut.
func test_the_cocked_hold_shows_on_the_skeleton() -> void:
	var weapon: WeaponDef = _coiling(&"katana")
	var cut: AttackDef = weapon.moves[weapon.light_start]
	var rec: Array[Dictionary] = await _play_posed(&"rogue", weapon)
	var held: int = 0
	var moves: PackedStringArray = []
	for t: int in range(cut.startup - 6, cut.startup + 2):
		var a: Dictionary = _at(rec, float(t - 1))
		var b: Dictionary = _at(rec, float(t))
		var moved: float = (b["hand"] as Vector3).distance_to(a["hand"])
		moves.append("%d: fist %.1f wrist %.1f mm" % [t, moved * 1000.0, (b["wrist"] as Vector3).distance_to(a["wrist"]) * 1000.0])
		if moved < 0.003:
			held += 1
	assert_between(held, 2, 4, "the hand holds still for %d frames before the strike (%s)" % [held, ", ".join(moves)])
	var hips_then: float = _at(rec, float(cut.startup - 1))["hips"] - _at(rec, float(cut.startup - 2))["hips"]
	assert_gt(absf(hips_then), 1.0, "while the hips set off")


## PoseCheck's knees pass through a coiled cut on both fighters: the feet
## stay planted and the knees over the toes as the hips turn and shift.
func test_the_knees_pass_pose_check_through_a_coiled_cut() -> void:
	for id: StringName in [&"rogue", &"hunter"]:
		var bench: MoveBench = MoveBench.new(self, id, _coiling(&"katana"))
		var steps: Array[MoveBench.Step] = await bench.play(&"k_l1")
		assert_gt(steps.size(), 20, "%s: the cut played" % id)
		for s: MoveBench.Step in steps:
			for fail: String in s.report.failures():
				assert_false(fail.contains("knee"), "%s frame %d: %s" % [id, s.frame, fail])
	MoveBench.free_all()


# ------------------------------------------------------------ footwork (14.13)

## The posed ankles in the world, by side, for a view standing at `pos`
## facing `yaw`.
func _ankles(v: FighterView, pos: Vector3, yaw: float) -> Dictionary[String, Vector3]:
	var poses: Array[Transform3D] = await _posed(v)
	var place: Transform3D = Transform3D(Basis(Vector3.UP, yaw), pos) * v.model.transform
	var out: Dictionary[String, Vector3] = {}
	for side: String in FighterRig.SIDES:
		out[side] = place * poses[v.model.skeleton.find_bone(side + "Foot")].origin
	return out


## For each of the Katana's lunging lights, played from the guard: the front
## foot touches down on the first active frame (±1), the rear foot after it,
## and on the posed skeleton the feet that stand slide less than 1 cm a frame
## in the world while the fighter lunges over them.
func test_the_front_foot_lands_on_the_first_active_frame() -> void:
	var lights: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3", &"k_l4"]
	var weapon: WeaponDef = _string_weapon(&"katana", lights)
	for id: StringName in lights:
		var def: AttackDef = weapon.moves[id]
		assert_gt(def.lunge, 0.0, "%s lunges" % id)
		var W: World = SimHelpers.make_world(weapon, Moves.KATANA, 3.0)
		var f: Fighter = W.fighters[0]
		var v: FighterView = _view(&"rogue", weapon)
		var show: Callable = func() -> void:
			v.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		for i: int in 6:
			W.step([SimHelpers.idle(), SimHelpers.idle()])
			show.call()
			await _posed(v)
		var start: float = f.pos.z
		assert_true(f.start_attack(id), "%s starts" % id)
		var landed: Dictionary[String, int] = {}
		var was: Dictionary[String, Vector3] = await _ankles(v, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw)
		var worst: float = 0.0
		var planted_frames: int = 0
		while f.state == &"attack":
			W.step([SimHelpers.idle(), SimHelpers.idle()])
			if f.state != &"attack":
				break
			show.call()
			var shuffle: GuardShuffle = v.locomotion.shuffle
			var now: Dictionary[String, Vector3] = await _ankles(v, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw)
			for side: String in FighterRig.SIDES:
				if shuffle.landed.has(side) and not landed.has(side):
					landed[side] = f.atk.frame
				var foot: GuardShuffle.Foot = shuffle.feet[side]
				if not foot.swinging and not shuffle.landed.has(side) and foot.prev_height == 0.0:
					worst = maxf(worst, Vector2(now[side].x - was[side].x, now[side].z - was[side].z).length())
					planted_frames += 1
			was = now
		assert_gt(f.pos.z - start, 0.2, "%s lunged" % id)
		assert_true(landed.has("Right"), "%s: the front foot stepped" % id)
		assert_eq(landed.get("Right", -99), def.startup + 1, "%s: the front foot lands on the first active frame" % id)
		assert_gt(landed.get("Left", 999), landed.get("Right", -99), "%s: the rear foot after it" % id)
		assert_gt(planted_frames, 20, "%s: feet stood on most frames" % id)
		assert_lt(worst, 0.01, "%s: planted feet slide %.1f mm at most" % [id, worst * 1000.0])


## A move with no swing keeps the stand-in's attack: the feet ride with the
## fighter and take no strike steps.
func test_moves_without_a_swing_keep_the_feet_riding() -> void:
	var bare: WeaponDef = SF.without_swings(&"katana")
	var W: World = SimHelpers.make_world(bare, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", bare)
	for i: int in 4:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	assert_true(v.locomotion.shuffle.riding, "riding through the stand-in's attack")
