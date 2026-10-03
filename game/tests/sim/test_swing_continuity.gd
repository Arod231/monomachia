extends GutTest
## Swing continuity (task 7.4): a follow-up's swing starts where the move
## before it hands off. Following a move, a swing enters from that move's
## hand-off key (its last key), so its first key must be close to it: within
## 2 cm and 10 degrees for each hand and foot, and 10 degrees of coil and 2 cm
## of pelvis shift for the body. It complements the sides check in
## test_string_continuity.gd; each weapon's follow-ups are checked once they
## have swings.

const GRIP_GAP: float = 0.02
const TURN_GAP: float = 10.0


## What the chained entry of `next` has to cover, from the hand-off key of
## `prev` to its own first key, beyond 2 cm and 10 degrees, per part both move.
static func _gaps(prev: Swing, next: Swing, what: String) -> Array[String]:
	var out: Array[String] = []
	for part: StringName in next.parts():
		var from: Swing.KeyPose = prev.hand_off(part)
		if from == null:
			continue
		var to: Swing.KeyPose = next.track(part)[0]
		var at: String = "%s %s" % [what, part]
		if part == &"body":
			for coil: String in ["torso", "pelvis"]:
				var turn: float = absf(float(to.get(coil)) - float(from.get(coil)))
				if turn > TURN_GAP:
					out.append("%s: the %s coil turns %.1f degrees" % [at, coil, turn])
			var shift: float = V3.distance(from.pelvis_shift, to.pelvis_shift)
			if shift > GRIP_GAP:
				out.append("%s: the pelvis moves %.1f cm" % [at, shift * 100.0])
		else:
			var move: float = V3.distance(from.grip, to.grip)
			if move > GRIP_GAP:
				out.append("%s: the grip moves %.1f cm" % [at, move * 100.0])
			var turn: float = Quat64.angle_between(Quat64.from_axes(from.blade, from.edge), Quat64.from_axes(to.blade, to.edge)) / SimMath.DEG
			if turn > TURN_GAP:
				out.append("%s: the hand turns %.1f degrees" % [at, turn])
	return out


func test_every_follow_up_starts_where_its_move_hands_off() -> void:
	var problems: Array[String] = []
	for wid: StringName in Moves.WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[wid]
		for id: StringName in w.moves:
			var m: AttackDef = w.moves[id]
			for next_id: StringName in [m.chain_light, m.chain_heavy]:
				if m.swing == null or next_id == &"" or not w.moves.has(next_id) or w.moves[next_id].swing == null:
					continue
				problems.append_array(_gaps(m.swing, w.moves[next_id].swing, "%s.%s -> %s" % [wid, id, next_id]))
	assert_eq(problems, [] as Array[String])


static func _hand(frame: int, grip: V3, blade: V3, edge: V3) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.grip = grip
	k.blade = blade
	k.edge = edge
	return k


static func _body(frame: int, torso: float, pelvis: float, shift: V3 = V3.make()) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.torso = torso
	k.pelvis = pelvis
	k.pelvis_shift = shift
	return k


## A move ending with the hand at `grip` holding the blade out flat to the
## left, and the coil at 30 degrees.
static func _ending(grip: V3) -> Swing:
	var s: Swing = Swing.new(20)
	s.add_track(&"right_hand", [
		_hand(2, V3.make(0.3, 1.4, 0.3), V3.make(0.0, 1.0, 0.0), V3.make(1.0, 0.0, 0.0)),
		_hand(15, grip, V3.make(-1.0, 0.0, 0.0), V3.make(0.0, -1.0, 0.0)),
	] as Array[Swing.KeyPose])
	s.add_track(&"body", [_body(2, 0.0, 0.0), _body(15, 30.0, 20.0)] as Array[Swing.KeyPose])
	return s


## A move starting with the hand at `grip`, its blade turned `turn` degrees
## from flat left about up, and the coil at `coil`.
static func _starting(grip: V3, turn: float, coil: float) -> Swing:
	var blade: V3 = Quat64.rotate(Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), turn * SimMath.DEG), V3.make(-1.0, 0.0, 0.0))
	var s: Swing = Swing.new(20)
	s.add_track(&"right_hand", [
		_hand(3, grip, blade, V3.make(0.0, -1.0, 0.0)),
		_hand(12, V3.make(0.3, 1.3, 0.5), V3.make(1.0, 0.0, 0.0), V3.make(0.0, 1.0, 0.0)),
	] as Array[Swing.KeyPose])
	s.add_track(&"body", [_body(3, coil, 20.0), _body(12, -20.0, -10.0)] as Array[Swing.KeyPose])
	return s


func test_the_check_passes_a_close_start_and_names_each_gap() -> void:
	var end: V3 = V3.make(-0.35, 0.95, 0.2)
	var prev: Swing = _ending(end)
	assert_eq(_gaps(prev, _starting(V3.add(end, V3.make(0.01, 0.01, 0.0)), 8.0, 37.0), "close"), [] as Array[String],
			"1.4 cm, 8 degrees of hand and 7 of coil")
	assert_eq(_gaps(prev, _starting(V3.add(end, V3.make(0.0, 0.03, 0.0)), 0.0, 30.0), "far"),
			["far right_hand: the grip moves 3.0 cm"] as Array[String])
	assert_eq(_gaps(prev, _starting(end, 15.0, 30.0), "turned"),
			["turned right_hand: the hand turns 15.0 degrees"] as Array[String])
	assert_eq(_gaps(prev, _starting(end, 0.0, 42.0), "coiled"),
			["coiled body: the torso coil turns 12.0 degrees"] as Array[String])
	var no_hand: Swing = Swing.new(20)
	no_hand.add_track(&"body", [_body(2, 30.0, 20.0)] as Array[Swing.KeyPose])
	assert_eq(_gaps(no_hand, _starting(V3.make(0.5, 1.0, 0.0), 90.0, 30.0), "no hand"), [] as Array[String],
			"a part the previous move doesn't key enters from the guard")
