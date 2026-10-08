extends GutTest
## Travel comes from the clips (milestone-1 task 21): a Katana or bare-hands
## move its family has re-keyed (real markers, AttackDef.by_travel) moves the
## fighter only by its row's travel, with no lunge and none of a run's speed;
## the stand-ins, the Counter Lunges and the hidden weapons keep their lunges
## until they are re-keyed (milestone 2 for the last two). Right Cut is
## re-keyed here on a fresh Katana with made-up travel, and played as a
## stand-in (lunging by its record, as before task 31 re-keyed it) where a
## test needs one.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
const EPS: float = 1e-9
## The moves re-keyed so far: the light string (task 31: Right Cut and Return
## Cut; task 32: Kesa Cut and Crown Cut), the one-handed grip's own five hits and the two-handed grip's hits 1 and 2
## (KE task 11), Crescent Coil (KE task 16), Breaker Palm (task 99) and bare hands' eight movement attacks (tasks 93 and 94), light string (task 89) and heavies (task 133).
const KEYED: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3", &"k_l4", &"k_1l1", &"k_1l2", &"k_1l3", &"k_1l4", &"k_1l5", &"k_2l1", &"k_2l2", &"k_coil", &"f_breaker", &"f_l1", &"f_l2", &"f_l3", &"f_h1", &"f_h2", &"f_sl", &"f_sh", &"f_dl", &"f_dh", &"f_bl", &"f_bh", &"f_jl", &"f_jh"]


func after_each() -> void:
	H.dispose_all()


## A fresh Katana whose Right Cut is a stand-in again: no travel, its
## record's lunge.
static func _stand_in() -> WeaponDef:
	return SF.stand_ins(&"katana", [CUT] as Array[StringName])


## A fresh Katana whose Right Cut is re-keyed: moved by `step` ([forward m,
## sideways m to the right, turn degrees to the right]) on every frame after
## frame 0, its swing a level slash, and with `tracking` its turn toward the
## opponent as the move data give it (else none).
static func _re_keyed(step: Array, tracking: bool = false) -> WeaponDef:
	var w: WeaponDef = SF.weapon(&"katana", {CUT: SF.level_slash(SF.without_swings(&"katana").moves[CUT])})
	var cut: AttackDef = w.moves[CUT]
	cut.by_travel = true
	var travel: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	for f: int in cut.total_frames():
		travel.append_array(PackedFloat64Array(step))
	cut.travel = travel
	if not tracking:
		cut.track_startup = 0.0
		cut.track_active = 0.0
	return w


## Fighter 0 with `w` plays Right Cut against an idle Katana `gap` m away,
## after running at it for `run` steps (the press on the step after): each
## step of the attack as [attack frame, pos, yaw], from the pose it started
## in ([-1, pos, yaw]).
static func _play(w: WeaponDef, gap: float = 10.0, run: int = 0) -> Array[Array]:
	var W: World = H.make_world(w, Moves.KATANA, gap)
	var a: Fighter = W.fighters[0]
	var out: Array[Array] = []
	for i: int in run + 60:
		var input: RawInput = H.move(0.0, 1.0) if i < run else (H.btn(Btn.LIGHT) if i == run else H.idle())
		if i == run:
			out.append([-1, V3.make(a.pos.x, a.pos.y, a.pos.z), a.yaw])
		W.step([input, H.idle()])
		if a.state == &"attack":
			out.append([a.atk.frame, V3.make(a.pos.x, a.pos.y, a.pos.z), a.yaw])
		elif i > run:
			break
	return out


func test_a_re_keyed_attack_moves_only_by_its_travel() -> void:
	var w: WeaponDef = _re_keyed([0.02, 0.005, 0.0])
	var steps: Array[Array] = _play(w)
	var n: int = 0
	for i: int in range(1, steps.size()):
		var was: Array = steps[i - 1]
		n = steps[i][0]
		# each frame's travel in the way it faced as the frame began (the
		# recovery still turns it toward the opponent the sideways step puts
		# off the line)
		var want: V3 = SimMath.local_to_world(was[1], was[2], V3.make(0.005 * (n - maxi(0, was[0])), 0.0, 0.02 * (n - maxi(0, was[0]))))
		assert_almost_eq(V3.length(V3.sub(steps[i][1], want)), 0.0, EPS, "frame %d: its travel, no lunge" % n)
	assert_eq(n, (w.moves[CUT] as AttackDef).total_frames() - 1, "through the move")


func test_its_turn_turns_the_fighter_and_what_comes_after_goes_its_new_way() -> void:
	var w: WeaponDef = _re_keyed([0.02, 0.0, 3.0])
	var cut: AttackDef = w.moves[CUT]
	var steps: Array[Array] = _play(w)
	var pos: V3 = steps[0][1]
	var yaw: float = steps[0][2]
	var f: int = 0
	# through the active frames, whose tracking is off here (the recovery
	# still turns back toward the opponent at the rules' rate, as today)
	for s: Array in steps.slice(1).filter(func(x: Array) -> bool: return x[0] <= cut.startup + cut.active):
		while f < s[0]:
			f += 1
			# each frame's move in the fighter's frame of that moment, then its turn
			pos = SimMath.local_to_world(pos, yaw, V3.make(0.0, 0.0, 0.02))
			yaw = SimMath.wrap_angle(yaw - 3.0 * SimMath.DEG)
		assert_almost_eq(V3.length(V3.sub(s[1], pos)), 0.0, EPS, "frame %d: where it is" % f)
		assert_almost_eq(SimMath.wrap_angle(s[2] - yaw), 0.0, EPS, "frame %d: 3° more to the right a frame" % f)


func test_an_attack_out_of_a_run_keeps_none_of_its_speed() -> void:
	var w: WeaponDef = _re_keyed([0.02, 0.0, 0.0])
	var steps: Array[Array] = _play(w, 10.0, 30)
	var start: V3 = steps[0][1]
	var first: Array = steps[1]
	assert_almost_eq(V3.length(V3.sub(first[1], start)), 0.02 * first[0], EPS, "the step it starts on moves by the travel alone")
	var last: Array = steps[-1]
	assert_almost_eq(V3.length(V3.sub(last[1], start)), 0.02 * last[0], EPS, "and so does the whole move")
	# a stand-in out of a run keeps its share (ATTACK_MOMENTUM_KEEP) as before
	var stand_in: Array[Array] = _play(_stand_in(), 10.0, 30)
	assert_gt(V3.length(V3.sub(stand_in[1][1], stand_in[0][1])), 0.03, "the stand-in carries the run on")


func test_the_stand_ins_the_counter_lunges_and_the_hidden_weapons_lunge_as_today() -> void:
	for w: WeaponDef in [Moves.KATANA, Moves.FISTS, Moves.GREATSWORD, Moves.DAGGERS]:
		for id: StringName in w.moves:
			var def: AttackDef = w.moves[id]
			var keyed: bool = (w == Moves.KATANA or w == Moves.FISTS) and KEYED.has(id)
			assert_eq(def.by_travel, keyed, "%s: re-keyed only if its family keyed it" % id)
			if not keyed:
				assert_eq(def.lunge_from(10.0), def.lunge if def.special != &"counterLunge" else 7.0, "%s keeps its lunge" % id)
	# Right Cut as a stand-in, from 10 m: its 0.35 m lunge, eased over its frames
	var steps: Array[Array] = _play(_stand_in())
	assert_almost_eq(V3.length(V3.sub(steps[-1][1], steps[0][1])), Moves.KATANA.moves[CUT].lunge, 1e-6, "Right Cut lunges 0.35 m")
	var heavy: Array[Array] = _play(Moves.GREATSWORD)
	var lunge_and_slide: float = Moves.GREATSWORD.moves[&"g_l1"].lunge + SimConst.COLOSSAL_SLIDE_DIST
	assert_almost_eq(V3.length(V3.sub(heavy[-1][1], heavy[0][1])), lunge_and_slide, 1e-6, "Heavy Swing lunges and slides on as it did")


func test_the_re_keyed_right_cut_moves_by_its_rows_travel() -> void:
	# task 31's Right Cut: no lunge, its okuri-ashi's travel from the table
	var cut: AttackDef = Moves.KATANA.moves[CUT]
	assert_true(cut.by_travel)
	assert_eq(cut.lunge_from(10.0), 0.0, "no lunge")
	var ahead: float = 0.0
	for f: int in range(1, cut.total_frames()):
		ahead += cut.travel_at(f)[0]
	assert_gt(ahead, 1.0, "a real step: %.2f m" % ahead)
	var steps: Array[Array] = _play(Moves.KATANA)
	assert_almost_eq(V3.length(V3.sub(steps[-1][1], steps[0][1])), ahead, 0.02, "the fighter goes as far as its travel")


func test_who_is_led_by_their_clips() -> void:
	assert_true(AttackDef.led_by_clip(&"katana", false, &""), "a re-keyed Katana move")
	assert_true(AttackDef.led_by_clip(&"fists", false, &""), "a re-keyed bare-hands move")
	assert_false(AttackDef.led_by_clip(&"katana", true, &""), "not a stand-in")
	assert_false(AttackDef.led_by_clip(&"katana", false, &"counterLunge"), "nor a Counter Lunge (milestone 2)")
	assert_false(AttackDef.led_by_clip(&"greatsword", false, &""), "nor the Greatsword (milestone 2)")


## The attack frame fighter 0, with `w`, first touches an idle defender
## `distance` m away at `bearing` degrees to its right with Right Cut, and how
## deep, or [] for none.
func _stepped_first_touch(w: WeaponDef, distance: float, bearing: float) -> Array:
	var W: World = H.make_world(w, Moves.KATANA, distance)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var off: float = bearing * SimMath.DEG
	b.pos = SimMath.local_to_world(a.pos, a.yaw, V3.make(distance * JsMath.sin(off), 0.0, distance * JsMath.cos(off)))
	var cut: AttackDef = w.moves[CUT]
	for i: int in 40:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		if a.state != &"attack":
			continue
		var f: int = a.atk.frame
		if f > cut.startup and f <= cut.startup + cut.active:
			var touch: BladeSweep = a.blade_touch(b.hurt_capsule())
			if touch != null:
				return [f, touch.depth]
	return []


func test_first_contact_plays_the_travel_as_the_world_does() -> void:
	# 5 cm forward and 1 cm right a frame, tracking the defender as the move
	# data say: from 1.9 m the travel alone brings the blade in
	var w: WeaponDef = _re_keyed([0.05, 0.01, 0.5], true)
	var body: FighterBody = FighterBody.of(&"")
	for c: Array in [[1.2, 0.0], [1.9, 0.0], [1.9, 30.0], [3.5, 0.0]]:
		var what: String = "%.1f m at %d°" % [c[0], c[1]]
		var want: Array = _stepped_first_touch(w, c[0], c[1])
		var got: SwingReach.Contact = SwingReach.first_contact(w.moves[CUT], w, c[0], c[1], body)
		if want.is_empty():
			assert_null(got, "%s: no contact" % what)
			continue
		assert_not_null(got, "%s: a contact" % what)
		if got != null:
			assert_eq(got.frame, want[0], "%s: the frame" % what)
			assert_almost_eq(got.depth, want[1], EPS, "%s: the depth" % what)
	assert_false(_stepped_first_touch(w, 1.9, 0.0).is_empty(), "the travel reaches from 1.9 m")
	assert_true(_stepped_first_touch(w, 3.5, 0.0).is_empty(), "and not from 3.5 m")


func test_the_computer_counts_the_travel_into_a_moves_reach() -> void:
	# the swing's reach, a fighter's radius, the farthest the travel carries
	# the fighter forward by the end of the active frames, and 0.6 m
	var cut: AttackDef = _re_keyed([0.05, 0.0, 0.0]).moves[CUT]
	var far: float = 0.05 * (cut.startup + cut.active)
	assert_almost_eq(cut.forward_reach(), far, EPS)
	var edge: float = cut.reach() + SimConst.FIGHTER_RADIUS + far + 0.6
	assert_true(AIBrain.threatens(cut, edge - 0.01))
	assert_false(AIBrain.threatens(cut, edge + 0.01))
