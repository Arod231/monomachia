extends GutTest
## Contact points (task 7.11): a move with a swing puts where its blade went
## deepest into the defender (the sweep's contact) in its hit, block and
## parry events, where the sparks and the parry's rebound start. Moves
## without a swing and scripted hits keep the demo's point, halfway between
## the fighters at 1.25 m. Right Cut's swings here are level slashes at 1.2 m
## (swing_fixtures.gd): from 1.6 m apart it lunges to 1.25 m and first
## touches the defender straight ahead on frame 13.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
const OUTCOMES: Array[StringName] = [&"hit", &"block", &"parry"]
const EPS: float = 1e-9


func after_each() -> void:
	H.dispose_all()


static func _cut() -> AttackDef:
	return Moves.KATANA.moves[CUT]


## Fighter 0 with a Katana whose Right Cut has `swing` (none: the cone), 1.6 m
## from an idle Katana.
static func _world(swing: Swing) -> World:
	var w: WeaponDef = SF.weapon(&"katana", {CUT: swing}) if swing != null else Moves.KATANA
	return H.make_world(w, Moves.KATANA, 1.6)


## Plays Right Cut against `defend` (a Callable of the step; none: idle) until
## its first hit, block or parry, and returns that event. The world is left
## as the step that decided it left it.
func _first_outcome(W: World, defend: Callable = Callable()) -> Dictionary:
	for i: int in 32:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle() if defend.is_null() else defend.call(i)])
		for e: Dictionary in W.drain_events():
			if OUTCOMES.has(e["t"]):
				return e
	return {}


static func _pos(e: Dictionary) -> V3:
	var p: Dictionary = e.get("pos", {"x": NAN, "y": NAN, "z": NAN})
	return V3.make(p["x"], p["y"], p["z"])


func _assert_v3(got: V3, want: V3, what: String, eps: float = EPS) -> void:
	assert_almost_eq(V3.distance(got, want), 0.0, eps, "%s: got %s, want %s" % [what, got, want])


func test_hit_block_and_parry_start_where_the_blade_crosses_the_defender() -> void:
	# the grip 0.8 m out, so the blade runs from 0.89 to 1.58 m out and its
	# sweep across the front holds the defender's axis: the deepest point is
	# where the axis meets the blade's level, 1.2 m up
	var wide: Swing = SF.level_slash(_cut(), 1.2, 60.0, -60.0, 0.8)
	var defences: Dictionary[StringName, Callable] = {
		&"hit": Callable(),
		&"block": func(_i: int) -> RawInput: return H.btn(Btn.BLOCK),
		&"parry": func(i: int) -> RawInput: return H.btn(Btn.BLOCK) if i == 13 else H.idle(),
	}
	for kind: StringName in defences:
		var W: World = _world(wide)
		var e: Dictionary = _first_outcome(W, defences[kind])
		assert_eq(e.get("t"), kind, "a %s" % kind)
		var b: V3 = W.fighters[1].pos
		_assert_v3(_pos(e), V3.make(b.x, 1.2, b.z), "the %s's point" % kind)


func test_a_blade_short_of_the_axis_starts_on_its_sweep_inside_the_capsule() -> void:
	# the grip 0.45 m out: the tip reaches 1.23 m, short of the defender's
	# axis 1.25 m away, so the contact is on the blade's sweep at 1.2 m,
	# inside the defender's capsule but off its axis
	var W: World = _world(SF.level_slash(_cut(), 1.2))
	var e: Dictionary = _first_outcome(W)
	assert_eq(e.get("t"), &"hit")
	var p: V3 = _pos(e)
	var b: V3 = W.fighters[1].pos
	var off_axis: float = SimMath.dist2(p, b)
	assert_almost_eq(p.y, 1.2, EPS, "at the blade's level")
	assert_between(off_axis, 0.01, 0.3575, "inside the capsule (0.35 m and half the blade), off its axis")
	# on the sweep: inside the quad the blade covered this tick, which is level
	var seg: BladeSegment = W.fighters[0].blade_segments()[0]
	var quad: Array[V3] = [seg.prev_base, seg.prev_tip, seg.tip, seg.base]
	var sides: Array[float] = []
	for i: int in 4:
		var u: V3 = quad[i]
		var v: V3 = quad[(i + 1) % 4]
		sides.append((v.x - u.x) * (p.z - u.z) - (v.z - u.z) * (p.x - u.x))
	assert_true(sides.max() <= 1e-12 or sides.min() >= -1e-12, "within the quad's corners: %s" % [sides])
	# and the sweep's own contact
	var touch: BladeSweep = BladeSweep.touch(seg.prev_base, seg.prev_tip, seg.base, seg.tip, seg.half_thickness,
			W.fighters[1].hurt_capsule())
	_assert_v3(p, touch.contact, "the sweep's contact")


func test_moves_without_a_swing_and_scripted_hits_keep_the_midpoint() -> void:
	var W: World = _world(null)
	var e: Dictionary = _first_outcome(W)
	assert_eq(e.get("t"), &"hit", "the cone's hit")
	var a: V3 = W.fighters[0].pos
	var b: V3 = W.fighters[1].pos
	_assert_v3(_pos(e), V3.make((a.x + b.x) / 2.0, 1.25, (a.z + b.z) / 2.0), "halfway, at 1.25 m")
	# a Moonsplitter wave, from a Katana whose Right Cut has a swing
	W = H.make_world(SF.weapon(&"katana", {CUT: SF.level_slash(_cut(), 1.2)}), Moves.KATANA, 8.0)
	W.fighters[0].hp = 20.0
	var wave_hit: Dictionary = {}
	for i: int in 70:
		W.step([H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), H.idle()])
		for ev: Dictionary in W.drain_events():
			if ev["t"] == &"hit" and wave_hit.is_empty():
				wave_hit = ev
				a = V3.make(W.fighters[0].pos.x, W.fighters[0].pos.y, W.fighters[0].pos.z)
				b = V3.make(W.fighters[1].pos.x, W.fighters[1].pos.y, W.fighters[1].pos.z)
	assert_eq(wave_hit.get("attack"), &"u_moon_v", "the wave hit")
	_assert_v3(_pos(wave_hit), V3.make((a.x + b.x) / 2.0, 1.25, (a.z + b.z) / 2.0), "the wave's hit, halfway at 1.25 m")
