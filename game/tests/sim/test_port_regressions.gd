extends GutTest
## Regression tests for the discrepancies found by the line-by-line review of
## the GDScript port against the TypeScript rules:
## - Math.hypot, Math.sin, Math.cos and Math.atan2 computed exactly as V8 does
##   (JsMath), at every place the TypeScript calls them;
## - optional move fields that hold a value the old sentinels treated as unset
##   (a zero or negative multiInterval, a negative guardCrush, dodgeCancelFrom,
##   lungeEnd, hitstop, hitstun or blockstun);
## - the tools: toFixed with 3 digits, Number() and String() of a number, and
##   the soak's handling of a match that crashes.
## The TypeScript reference values for the math and the tools are in
## game/tests/fixtures/port.json, written by scripts/port-fixtures.ts. Floats
## are stored as their bits and compared bit for bit. The move fields were
## compared with recorded TypeScript traces until plan task 8.2; they are now
## checked by what the attack does.

const H := preload("res://tests/sim/sim_helpers.gd")
const Soak := preload("res://tools/soak.gd")

## How far apart the patched runs start: near enough for Right Cut's lunge to
## reach.
const GAP: float = 1.6
## Steps enough for a patched Right Cut to play out (60 frames since task 31).
const STEPS: int = 70

var _fx: Dictionary
## [AttackDef, field, old value] for each patched move field, undone after each test
var _patches: Array[Array] = []


func before_all() -> void:
	_fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/port.json"))


## Right Cut, re-keyed (task 31), patched back into a stand-in for each test:
## the move fields checked here are a stand-in's (its lunge, and hit values
## of its own rather than the retuned table's), struck with the cone (its
## re-keyed clip's cut sweeps past the defender before a stretched active
## window ends).
func before_each() -> void:
	_patch("real_markers", false)
	_patch("by_travel", false)
	_patch("travel", PackedFloat64Array())
	_patch("swing", null)


func after_each() -> void:
	_patches.reverse()
	for p: Array in _patches:
		(p[0] as AttackDef).set(p[1], p[2])
	_patches.clear()
	H.dispose_all()


## The double whose big-endian IEEE-754 bits are the 16 hex digits `hex`.
static func _f(hex: String) -> float:
	var b: PackedByteArray = PackedByteArray()
	b.resize(8)
	b.encode_u32(4, hex.substr(0, 8).hex_to_int())
	b.encode_u32(0, hex.substr(8, 8).hex_to_int())
	return b.decode_double(0)


## The bits of x as 16 hex digits (big-endian), as the fixture writes them.
static func _hex(x: float) -> String:
	var b: PackedByteArray = PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return "%08x%08x" % [b.decode_u32(4), b.decode_u32(0)]


## Bit equality, with every NaN equal to every other NaN.
static func _same(got: float, want_hex: String) -> bool:
	var want: float = _f(want_hex)
	if is_nan(want):
		return is_nan(got)
	return _hex(got) == want_hex


# ------------------------------------------------------------------ Math.* as V8 computes them

func test_hypot_matches_math_hypot_bit_for_bit() -> void:
	var bad: Array[String] = []
	for r: Array in _fx["hypot"]:
		var got: float = JsMath.hypot(_f(r[0]), _f(r[1]))
		if not _same(got, r[2]):
			bad.append("hypot(%s, %s) = %s, want %s" % [r[0], r[1], _hex(got), r[2]])
	assert_eq(bad, [] as Array[String])
	assert_gt((_fx["hypot"] as Array).size(), 100)


func test_sin_and_cos_match_v8_bit_for_bit() -> void:
	var bad: Array[String] = []
	for r: Array in _fx["sincos"]:
		var a: float = _f(r[0])
		if not _same(JsMath.sin(a), r[1]):
			bad.append("sin(%s) = %s, want %s" % [r[0], _hex(JsMath.sin(a)), r[1]])
		if not _same(JsMath.cos(a), r[2]):
			bad.append("cos(%s) = %s, want %s" % [r[0], _hex(JsMath.cos(a)), r[2]])
	assert_eq(bad, [] as Array[String])


func test_atan2_matches_v8_bit_for_bit() -> void:
	var bad: Array[String] = []
	for r: Array in _fx["atan2"]:
		var got: float = JsMath.atan2(_f(r[0]), _f(r[1]))
		if not _same(got, r[2]):
			bad.append("atan2(%s, %s) = %s, want %s" % [r[0], r[1], _hex(got), r[2]])
	assert_eq(bad, [] as Array[String])


func test_fwd_right_and_yaw_to_use_v8_trig() -> void:
	var bad: Array[String] = []
	for r: Array in _fx["sincos"]:
		var a: float = _f(r[0])
		var f: V2 = SimMath.fwd(a)
		if not (_same(f.x, r[1]) and _same(f.z, r[2])):
			bad.append("fwd(%s)" % r[0])
		var rt: V2 = SimMath.right(a)
		if not (_same(-rt.x, r[2]) and _same(rt.z, r[1])):
			bad.append("right(%s)" % r[0])
	for r: Array in _fx["atan2"]:
		var got: float = SimMath.yaw_to(V3.make(), V3.make(_f(r[0]), 0.0, _f(r[1])))
		if not _same(got, r[2]):
			bad.append("yawTo(%s, %s)" % [r[0], r[1]])
	assert_eq(bad, [] as Array[String])


func test_the_stick_deadzone_uses_math_hypot() -> void:
	# Sticks on the deadzone circle where Math.hypot and sqrt(x*x + y*y) fall on
	# different sides of DIR_DEADZONE.
	for r: Array in _fx["deadzone"]:
		assert_eq(InputTracker.dir_index(_f(r[0]), _f(r[1])), int(r[2]), "dirIndex(%s, %s)" % [r[0], r[1]])


# ------------------------------------------------------------------ optional move fields

## Sets a field of Right Cut (k_l1) for this test only.
func _patch(field: String, value: Variant) -> void:
	var def: AttackDef = Moves.KATANA.moves[&"k_l1"]
	_patches.append([def, field, def.get(field)])
	def.set(field, value)


## What happened on each step of a patched run: every event, each with
## "step", the index of the step it came on, and the state after each step.
class Trace extends SimHelpers.Rec:
	## The world the run played in.
	var world: World
	## W.frame after each step.
	var frame: Array[int] = []
	## W.hitstop after each step.
	var hitstop: Array[int] = []
	## The attacker's state after each step.
	var attacker: Array[StringName] = []
	## The defender's state after each step.
	var defender: Array[StringName] = []
	## The defender's posture after each step.
	var posture: Array[float] = []

	func collect(W: World) -> void:
		for e: Dictionary in W.drain_events():
			e["step"] = frame.size()
			events.append(e)


## Fighter 0 (the attacker) and fighter 1 (the defender), Katanas 2.2 m apart,
## play p0 and p1 for `steps` steps, after setup (if any) has adjusted the world.
func _run_patched(steps: int, p0: Callable, p1: Callable, setup: Callable = Callable()) -> Trace:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, GAP)
	if not setup.is_null():
		setup.call(W)
	var t: Trace = Trace.new()
	t.world = W
	for i: int in steps:
		W.step([p0.call(i), p1.call(i)])
		t.collect(W)
		t.frame.append(W.frame)
		t.hitstop.append(W.hitstop)
		t.attacker.append(W.fighters[0].state)
		t.defender.append(W.fighters[1].state)
		t.posture.append(W.fighters[1].posture)
	return t


static func _light_at_0(i: int) -> RawInput:
	return H.btn(Btn.LIGHT) if i == 0 else H.idle()


static func _hold_block(_i: int) -> RawInput:
	return H.btn(Btn.BLOCK)


static func _idle(_i: int) -> RawInput:
	return H.idle()


func test_multi_interval_zero_skips_every_active_frame() -> void:
	# TS: (f - S - 1) % 0 is NaN, NaN !== 0, so no frame ever hits (no error).
	assert_eq(_run_patched(STEPS, _light_at_0, _idle).count(&"hit"), 1, "unpatched, the Right Cut reaches and hits")
	_patch("multi_hit", 3)
	_patch("multi_interval", 0)
	_patch("active", 6)
	var t: Trace = _run_patched(STEPS, _light_at_0, _idle)
	assert_eq(t.all(&"hit"), [] as Array[Dictionary], "no active frame hits")
	assert_eq(t.attacker[0], &"attack", "the Right Cut was thrown")


func test_a_negative_multi_interval_is_used_as_is() -> void:
	# TS: (f - S - 1) % -2 has the sign of f - S - 1, so every second active
	# frame hits, as with an interval of 2.
	_patch("multi_hit", 3)
	_patch("multi_interval", -2)
	_patch("active", 6)
	var t: Trace = _run_patched(STEPS, _light_at_0, _idle)
	var hits: Array[Dictionary] = t.all(&"hit")
	assert_eq(hits.size(), 3, "three hits")
	for k: int in range(1, hits.size()):
		var gap: int = t.frame[hits[k]["step"]] - t.frame[hits[k - 1]["step"]]
		assert_eq(gap, 2, "hit %d lands two world frames after the last" % k)


func test_a_negative_guard_crush_is_kept() -> void:
	# TS: guardCrush ?? blockMitigation keeps the negative multiplier, and
	# addPosture then ignores the negative cost.
	_patch("guard_crush", -0.5)
	var t: Trace = _run_patched(STEPS, _light_at_0, _hold_block, func(W: World) -> void: W.fighters[1].posture = 40.0)
	assert_eq([t.count(&"block"), t.count(&"hit")], [1, 0], "the Right Cut is blocked")
	assert_almost_eq(float(t.find(&"block")["posture"]), 7.0 * -0.5, 1e-9, "the block's posture cost keeps the negative multiplier (Right Cut's 7 × -0.5)")
	var rises: int = 0
	for k: int in range(1, t.posture.size()):
		if t.posture[k] > t.posture[k - 1]:
			rises += 1
	assert_eq(rises, 0, "the block adds no posture: it only ever falls")


func test_a_negative_dodge_cancel_frame_cancels_at_once() -> void:
	# TS: dodgeCancelFrom !== undefined accepts a negative frame.
	_patch("dodge_cancel_from", -1)
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.LIGHT) if i == 0 else (H.btn(Btn.DODGE) if i == 1 else H.idle())
	var t: Trace = _run_patched(12, p0, _idle)
	assert_eq(t.attacker.slice(0, 2), [&"attack", &"backstep"] as Array[StringName], "a dodge on the attack's first frame cancels it")


func test_a_negative_lunge_end_means_no_lunge() -> void:
	# TS: lungeEnd ?? S + A keeps a negative end, so the lunge window is empty.
	_patch("lunge_end", -1)
	var out_of_reach: Callable = func(W: World) -> void: W.fighters[1].pos.z = 4.0
	var t: Trace = _run_patched(STEPS, _light_at_0, _idle, out_of_reach)
	assert_eq(t.attacker[0], &"attack", "the Right Cut was thrown")
	var a: Fighter = t.world.fighters[0]
	assert_eq([a.pos.x, a.pos.z], [0.0, -GAP / 2.0], "the attacker never moved")


func test_negative_hitstop_and_hitstun_are_kept() -> void:
	# TS: hitstop ?? 4 and hitstun ?? 20 keep negative values: the world never
	# freezes and the defender recovers at once.
	_patch("hitstop", -3)
	_patch("hitstun", -4)
	var t: Trace = _run_patched(STEPS, _light_at_0, _idle)
	assert_eq(t.count(&"hit"), 1, "one hit")
	var at: int = t.find(&"hit")["step"]
	assert_eq(t.hitstop[at], -3, "the hit-stop is kept as it is")
	assert_eq(t.frame, range(1, STEPS + 1), "the world steps on every step: no hit-stop")
	assert_eq([t.defender[at], t.defender[at + 1]], [&"hitstun", &"free"], "the defender is free on the frame after the hit")


func test_a_negative_blockstun_is_kept() -> void:
	# TS: blockstun ?? 12 keeps a negative value, and the block's hit-stop is
	# max(3, hitstop - 2), so the world freezes the minimum 3 frames (as it
	# would for Right Cut's own 4: the minimum hides the kept -2).
	_patch("blockstun", -5)
	_patch("hitstop", -2)
	var t: Trace = _run_patched(STEPS, _light_at_0, _hold_block)
	assert_eq(t.count(&"block"), 1, "one block")
	var at: int = t.find(&"block")["step"]
	assert_eq(t.hitstop[at], 3, "the minimum hit-stop")
	var next: int = t.frame.find(t.frame[at] + 1)
	assert_eq([t.defender[next - 1], t.defender[next]], [&"blockstun", &"free"], "the defender is free on the first frame after the freeze")


# ------------------------------------------------------------------ tools

func test_to_fixed_matches_js_for_0_to_3_digits() -> void:
	var bad: Array[String] = []
	for r: Array in _fx["toFixed"]:
		var got: String = JsFormat.to_fixed(_f(r[0]), int(r[1]))
		if got != r[2]:
			bad.append("(%s).toFixed(%d) = %s, want %s" % [r[0], int(r[1]), got, r[2]])
	assert_eq(bad, [] as Array[String])


func test_number_parses_a_string_like_js_number() -> void:
	var bad: Array[String] = []
	for r: Array in _fx["number"]:
		var got: float = JsFormat.number(r[0])
		if not _same(got, r[1]) or JsFormat.num(got) != r[2]:
			bad.append("Number(%s) = %s (%s), want %s (%s)" % [JSON.stringify(r[0]), _hex(got), JsFormat.num(got), r[1], r[2]])
	assert_eq(bad, [] as Array[String])


func test_num_prints_like_js_string() -> void:
	var bad: Array[String] = []
	for r: Array in _fx["numToString"]:
		var got: String = JsFormat.num(_f(r[0]))
		if got != r[1]:
			bad.append("String(%s) = %s, want %s" % [r[0], got, r[1]])
	assert_eq(bad, [] as Array[String])


func test_soak_reports_a_crashed_match_and_goes_on() -> void:
	# TS: an exception inside a match is caught, counted as a failure and
	# reported as "match m crashed at frame f: <error>"; the next match runs.
	var lines: Array[String] = []
	var out: Callable = func(s: String) -> void: lines.append(s)
	var crash: Callable = func(m: int, frames: int, W: World) -> void:
		if m == 1 and frames == 150:
			W.fighters[1].opp = null # a null dereference inside the rules
	var failures: int = Soak.run(3.0, out, 240, crash)
	var errors: Array = get_errors()
	for e: GutTrackedError in errors:
		e.handled = true
	assert_gt(errors.size(), 0, "the injected fault raised script errors")
	assert_eq(failures, 3, "two unfinished matches and one crash")
	var crashed: Array[String] = lines.filter(func(s: String) -> bool: return s.begins_with("match 1 crashed at frame 150: "))
	assert_eq(crashed.size(), 1, "one crash line for match 1: %s" % [lines])
	assert_eq(lines.filter(func(s: String) -> bool: return s.begins_with("match 1 (")).size(), 0, "match 1 is not also reported as unfinished")
	assert_eq(lines.filter(func(s: String) -> bool: return s.begins_with("match 2 (")).size(), 1, "match 2 still ran")
	assert_true(lines.has("\n3 matches, 3 failures"), "summary: %s" % [lines])


func test_soak_match_count_is_a_js_number() -> void:
	# TS: N = Number(argv[2] ?? 30); for (m = 0; m < N; m++); prints `${N} matches`
	var lines: Array[String] = []
	var out: Callable = func(s: String) -> void: lines.append(s)
	assert_eq(Soak.run(JsFormat.number("1.5"), out, 1), 2, "1.5 runs two matches (neither finishes in 1 frame)")
	assert_true(lines.has("\n1.5 matches, 2 failures"), "%s" % [lines])
	lines.clear()
	assert_eq(Soak.run(JsFormat.number("abc"), out, 1), 0)
	assert_true(lines.has("\nNaN matches, 0 failures"), "%s" % [lines])
