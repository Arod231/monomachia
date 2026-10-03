class_name WeaponStringsTest
extends GutTest
## What each weapon's strings test (plan tasks 9-11) shares. A test names its
## weapon and the spec's table of its moves in _init, plays its strings
## through _play and _run (see PlayedString), and checks them with the
## asserts below. Expected numbers come from the spec, not the code.

const H := preload("res://tests/sim/sim_helpers.gd")
## toBeCloseTo's default precision (2 digits), as the neighbouring tests use
const CLOSE: float = 0.005
## The buttons that start a follow-up.
const LIGHT_OR_HEAVY: Array[int] = [Btn.LIGHT, Btn.HEAVY]
## How far apart the fighters start (m; or the weapon's duelling distance
## when nearer, _gap()), and how many steps a string plays for.
const GAP: float = 2.2
const STEPS: int = 240
## How far apart the fighters start for a string to whiff (m).
const WHIFF_GAP: float = 10.0

## The weapon fighter 0 holds.
var weapon: WeaponDef
## The spec's table of the weapon's moves, by id: name, frames (startup,
## active, recovery), damage, posture, the light and heavy follow-ups (&""
## for none), and the sides the spec's move data gives the weapon (start,
## end).
var rows: Dictionary[StringName, Dictionary]


func after_each() -> void:
	H.dispose_all()


## The spec's length of move id in frames: startup + active + recovery.
func _length(id: StringName) -> int:
	var frames: Array = rows[id]["frames"]
	return frames[0] + frames[1] + frames[2]


## presses as the spec writes a string: "L-L-H".
static func _named(presses: Array[int]) -> String:
	var out: PackedStringArray = []
	for press: int in presses:
		out.append("L" if press == Btn.LIGHT else "H")
	return "-".join(out)


## Fighter 0 plays a string of presses with the weapon against an idle Katana
## gap m away (see PlayedString.play: the first on step 0, each next one on
## the step after the attack before it swings; mx the stick's sideways push
## throughout; a dodge pressed on attack dodge_in's frame dodge_on).
func _play(
	presses: Array[int], gap: float = NAN, mx: float = 0.0, dodge_in: StringName = &"", dodge_on: int = -1
) -> PlayedString:
	return PlayedString.play(weapon, presses, _gap() if is_nan(gap) else gap, mx, dodge_in, dodge_on)


## Fighter 0, holding the weapon, plays the input p0 gives each step (step
## index -> RawInput) for n steps against a Katana gap m away, which plays
## the input p1 gives (idle without one).
func _run(p0: Callable, gap: float = NAN, n: int = STEPS, p1: Callable = Callable()) -> PlayedString:
	return PlayedString.run(weapon, p0, _gap() if is_nan(gap) else gap, n, p1)


## How far apart a string starts: GAP, or the weapon's duelling distance when
## nearer (the Daggers' 2.0 m: their lights, baked from clips, put 17.5 cm of
## blade into a defender from there and fall short of 2.2; authored
## animation 21).
func _gap() -> float:
	return minf(GAP, weapon.duel_distance)


## Plays presses against a Katana GAP m away that plays the input p1 gives
## (to block, jump or dodge), each press on the step _play pressed it on
## against an idle one.
func _play_against(presses: Array[int], p1: Callable) -> PlayedString:
	var on: Array[int] = _play(presses).pressed_on
	var p0: Callable = func(i: int) -> RawInput:
		var k: int = on.find(i)
		return H.btn(presses[k]) if k >= 0 else H.idle()
	return _run(p0, _gap(), STEPS, p1)


## Plays presses (the stick at mx), then each of buttons as the last of swings
## swings, and checks that it starts nothing: the swings stay swings, and the
## last of them ends on startup + active + recovery, leaving the fighter free.
func _assert_starts_nothing_in(presses: Array[int], swings: Array[StringName], buttons: Array[int], mx: float = 0.0) -> void:
	var id: StringName = swings.back()
	for press: int in buttons:
		var played: Array[int] = presses.duplicate()
		played.append(press)
		var r: PlayedString = _play(played, _gap(), mx)
		var what: String = "a %s pressed in %s" % ["light" if press == Btn.LIGHT else "heavy", rows[id]["name"]]
		assert_eq(r.ids(&"swing"), swings, "%s starts nothing" % what)
		assert_eq(r.ended_on(id), _length(id), "%s: it ends on startup + active + recovery" % what)
		assert_eq(r.state_after(id), &"free", "%s: then the fighter is free" % what)


## Plays presses (the stick at mx) and checks each one hits, and that the
## string then stops: its last move, one of the spec's rows, ends on startup
## + active + recovery, leaving the fighter free.
func _assert_stops_after(presses: Array[int], mx: float = 0.0) -> void:
	var r: PlayedString = _play(presses, _gap(), mx)
	var what: String = "%s%s" % [_named(presses), " sideways" if mx != 0.0 else ""]
	var hits: Array[StringName] = r.ids(&"hit")
	assert_eq(hits.size(), presses.size(), "every press of %s hits" % what)
	if hits.size() != presses.size():
		return
	var last: StringName = hits.back()
	if not rows.has(last):
		fail_test("%s ends on %s, none of the spec's rows" % [what, last])
		return
	var last_name: String = rows[last]["name"]
	assert_eq(r.ended_on(last), _length(last), "%s: %s ends on startup + active + recovery" % [what, last_name])
	assert_eq(r.state_after(last), &"free", "%s: and the fighter is free after %s" % [what, last_name])


## Fighter 0's input to dodge on step 0 with the stick at stick (to the
## right by default), then press button wait steps after the dodge ends (from
## the step it is free again; a dodge attack may follow within 12 frames), gap
## m from the defender.
func _dodge_then(button: int, stick: Vector2 = Vector2(1.0, 0.0), gap: float = NAN, wait: int = 0) -> Callable:
	if is_nan(gap):
		gap = _gap()
	var dodge: Callable = func(i: int) -> RawInput: return H.move(stick.x, stick.y, Btn.DODGE) if i == 0 else H.idle()
	var press_on: int = _run(dodge, gap).state.find(&"free") + wait
	return func(i: int) -> RawInput: return H.btn(button) if i == press_on else dodge.call(i)


## Plays _dodge_then's input against a Katana gap m away that plays the input
## p1 gives (idle without one).
func _out_of_a_dodge(
	button: int, p1: Callable = Callable(), stick: Vector2 = Vector2(1.0, 0.0), gap: float = NAN, wait: int = 0
) -> PlayedString:
	if is_nan(gap):
		gap = _gap()
	return _run(_dodge_then(button, stick, gap, wait), gap, STEPS, p1)


## Plays presses, the last starting attack id, after a hit (GAP) and after a
## whiff (WHIFF_GAP), and checks a dodge pressed on its frame cancel - 1, or
## on any of the frames also_early, is refused there and comes on cancel (the
## input buffer holds it), and one pressed on cancel comes at once.
func _assert_dodge_cancels_from(presses: Array[int], id: StringName, cancel: int, also_early: Array[int] = []) -> void:
	var early_frames: Array[int] = [cancel - 1]
	early_frames.append_array(also_early)
	for gap: float in [_gap(), WHIFF_GAP]:
		var what: String = "%s %s" % [rows[id]["name"], "after a hit" if gap != WHIFF_GAP else "after a whiff"]
		for pressed: int in early_frames:
			var early: PlayedString = _play(presses, gap, 0.0, id, pressed)
			assert_eq(
				[early.ended_on(id), early.state_after(id)],
				[cancel, &"dodge"],
				"%s: a dodge pressed on frame %d is refused there and comes on %d" % [what, pressed, cancel],
			)
		var on_time: PlayedString = _play(presses, gap, 0.0, id, cancel)
		assert_eq(
			[on_time.ended_on(id), on_time.state_after(id)],
			[cancel, &"dodge"],
			"%s: one pressed on frame %d comes at once" % [what, cancel],
		)


## Checks each of the spec's rows against the weapon's move: its name,
## frames, damage and posture, follow-ups and sides.
func _assert_rows_match_the_spec() -> void:
	for id: StringName in rows:
		var row: Dictionary = rows[id]
		var m: AttackDef = weapon.moves.get(id, null)
		assert_not_null(m, "%s exists" % id)
		if m == null:
			continue
		assert_eq(m.name, row["name"], "%s name" % id)
		assert_eq([m.startup, m.active, m.recovery], row["frames"], "%s frames" % row["name"])
		assert_eq([m.damage, m.posture], [float(row["damage"]), float(row["posture"])], "%s damage and posture" % row["name"])
		assert_eq([m.chain_light, m.chain_heavy], [row["light"], row["heavy"]], "%s follow-ups" % row["name"])
		assert_eq([m.side_start, m.side_end], row["sides"], "%s sides" % row["name"])
