extends GutTest
## The soak's balance report (plan task 12.1): win rates with mirror matches
## left out, disarms per round, and the spec's targets marked in or out; and
## milestone 1's mirror matches (milestone-1 task 7): Hunter-against-Hunter
## Katana mirrors, each fighter's two block abilities drawn at random, win
## rates off, the finisher share and the appear-list in the targets.

const Soak := preload("res://tools/soak.gd")


# These pin the soak over all three weapons, so they run with the whole
# roster; the mirror tests turn it off.
func before_each() -> void:
	Roster.full = true


func after_each() -> void:
	Roster.reset()


## A soak's report lines, failures, and each match's fighters as the rules
## built them.
class SoakRun:
	var lines: Array[String] = []
	## Each match's two weapons.
	var pairs: Array[PackedStringArray] = []
	## Each match's two bodies (fighter ids).
	var bodies: Array[PackedStringArray] = []
	## Each match's two loadouts of block abilities.
	var loadouts: Array[Array] = []
	var failures: int = -1

	## The report's lines after the one equal to heading, up to the next
	## unindented one.
	func block(heading: String) -> Array[String]:
		var out: Array[String] = []
		var i: int = lines.find(heading)
		if i < 0:
			return out
		i += 1
		while i < lines.size() and lines[i].begins_with("  "):
			out.append(lines[i])
			i += 1
		return out

	func mirrors() -> int:
		return pairs.filter(func(p: PackedStringArray) -> bool: return p[0] == p[1]).size()


## A short soak in which fighter 1 is knocked out the moment each round's
## fight starts, so fighter 0 wins every match. `events`, when set, is
## called as events.call(frames, W) before each step, to emit made-up events.
static func _knockout_soak(matches: int, events: Callable = Callable()) -> SoakRun:
	var r := SoakRun.new()
	var hook := func(_m: int, frames: int, W: World) -> void:
		if frames == 0:
			r.pairs.append(PackedStringArray([W.fighters[0].moveset().id, W.fighters[1].moveset().id]))
			r.bodies.append(PackedStringArray([W.fighters[0].body.id, W.fighters[1].body.id]))
			r.loadouts.append([W.fighters[0].abilities.duplicate(), W.fighters[1].abilities.duplicate()])
		if not events.is_null():
			events.call(frames, W)
		if W.fighters[1].state == &"free":
			W.fighters[1].hp = 0.0
	r.failures = Soak.run(float(matches), func(s: String) -> void: r.lines.append(s), 3000, hook)
	return r


## report_balance's lines for a tally.
static func _balance(t: Soak.Tally) -> Array[String]:
	var lines: Array[String] = []
	Soak.report_balance(func(s: String) -> void: lines.append(s), t)
	return lines


## A tally with the win rates on and every appearance at zero.
static func _mixed(avg_round_s: float, disarms_per_round: float, records: Dictionary[String, Vector2i]) -> Soak.Tally:
	var t := Soak.Tally.new()
	t.win_rates = true
	t.rounds = 10
	t.avg_round_s = avg_round_s
	t.disarms_per_round = disarms_per_round
	t.records = records
	return t


func test_win_rates_leave_mirror_matches_out() -> void:
	# The seed's 9 matches: 4 mirrors, and 5 between different weapons, which
	# fighter 0 always wins: the Greatsword 4 of 4, the Katana 1 of 4, the
	# Daggers 0 of 2.
	var soak: SoakRun = _knockout_soak(9)
	assert_eq(soak.failures, 0)
	assert_eq(soak.mirrors(), 4, "the run has mirror matches to leave out")
	assert_eq(soak.block("win rates, mirror matches left out:"), [
		"  katana: 25.0% (1 of 4)",
		"  greatsword: 100.0% (4 of 4)",
		"  daggers: 0.0% (0 of 2)",
	] as Array[String])
	# the ported line still counts the mirrors, a win and a loss each
	assert_true(soak.lines.has("match wins/losses by weapon: { greatsword: [ 4, 0 ], katana: [ 4, 6 ], daggers: [ 1, 3 ] }"), "%s" % [soak.lines])


func test_a_weapon_with_only_mirror_matches_has_no_win_rate() -> void:
	var soak: SoakRun = _knockout_soak(3)
	assert_eq(soak.failures, 0, "every target is out, yet nothing failed: the exit code follows failures alone")
	assert_true(soak.lines.has("\n3 matches, 0 failures"), "%s" % [soak.lines])
	assert_true(soak.block("win rates, mirror matches left out:").has("  daggers: no matches"), "%s" % [soak.lines])
	assert_true(soak.block("targets (the spec's):").has("  daggers wins 45-55%: no matches, out"), "%s" % [soak.lines])
	# rounds end the moment the fight starts, 39 frames after "Fight!" is
	# called (0.65 s), with no disarms
	assert_true(soak.lines.has("disarms per round: 0.00"))
	assert_eq(soak.block("targets (the spec's):").slice(0, 2), [
		"  rounds of 60-90 s: 0.7 s, out",
		"  disarms 0.3-0.6 per round: 0.00, out",
	] as Array[String])


func test_the_targets_take_their_ends_as_in() -> void:
	var lines: Array[String] = _balance(_mixed(60.0, 0.6, {"katana": Vector2i(9, 20), "greatsword": Vector2i(11, 20), "daggers": Vector2i(1101, 2000)}))
	assert_eq(lines.slice(0, 5), [
		"win rates, mirror matches left out:",
		"  katana: 45.0% (9 of 20)",
		"  greatsword: 55.0% (11 of 20)",
		"  daggers: 55.0% (1101 of 2000)",
		"disarms per round: 0.60",
	] as Array[String])
	var targets: Array[String] = lines.slice(lines.find("targets (the spec's):") + 1)
	assert_eq(targets.slice(0, 2), [
		"  rounds of 60-90 s: 60.0 s, in",
		"  disarms 0.3-0.6 per round: 0.60, in",
	] as Array[String])
	assert_eq(targets.slice(targets.size() - 3), [
		"  katana wins 45-55%: 45.0%, in",
		"  greatsword wins 45-55%: 55.0%, in",
		"  daggers wins 45-55%: 55.0%, in",
	] as Array[String], "55.05% prints as 55.0%, and is judged as printed")
	assert_eq(_balance(_mixed(90.0, 0.3, {})).filter(func(s: String) -> bool: return s.begins_with("  rounds")), ["  rounds of 60-90 s: 90.0 s, in"])


func test_the_targets_mark_numbers_past_their_ends_out() -> void:
	var lines: Array[String] = _balance(_mixed(90.06, 0.296, {"katana": Vector2i(889, 2000), "greatsword": Vector2i(1112, 2000)}))
	var targets: Array[String] = lines.slice(lines.find("targets (the spec's):") + 1)
	assert_eq(targets.slice(0, 2), [
		"  rounds of 60-90 s: 90.1 s, out",
		"  disarms 0.3-0.6 per round: 0.30, in",
	] as Array[String], "0.296 prints as 0.30 and is in")
	assert_eq(targets.slice(targets.size() - 3), [
		"  katana wins 45-55%: 44.5%, out",
		"  greatsword wins 45-55%: 55.6%, out",
		"  daggers wins 45-55%: no matches, out",
	] as Array[String])
	assert_eq(_balance(_mixed(59.94, 0.3, {})).filter(func(s: String) -> bool: return s.begins_with("  rounds")), ["  rounds of 60-90 s: 59.9 s, out"])


# ------------------------------------------------------------ milestone 1

func test_the_soak_plays_hunter_katana_mirrors_by_default() -> void:
	# milestone 1 (tasks 4 and 7): without --full-roster only the Katana is
	# offered, and every match is the Hunter against the Hunter
	Roster.full = false
	var soak: SoakRun = _knockout_soak(4)
	assert_eq(soak.failures, 0)
	assert_eq(soak.pairs.size(), 4)
	for i: int in soak.pairs.size():
		assert_eq(soak.pairs[i], PackedStringArray(["katana", "katana"]))
		assert_eq(soak.bodies[i], PackedStringArray(["hunter", "hunter"]))


func test_each_fighter_draws_two_block_abilities_seeded() -> void:
	Roster.full = false
	var soak: SoakRun = _knockout_soak(12)
	var seen: Dictionary[String, bool] = {}
	for pair: Array in soak.loadouts:
		for loadout: Array in pair:
			assert_eq(loadout.size(), 2, "two block abilities: %s" % [loadout])
			assert_ne(loadout[0], loadout[1], "two different ones: %s" % [loadout])
			for a: StringName in loadout:
				assert_true(Moves.KATANA.abilities.has(a), "%s is a Katana ability" % a)
			var key: Array = loadout.duplicate()
			key.sort()
			seen[str(key)] = true
	assert_eq(seen.size(), 3, "all three pairs of Flash, Piercing Thrust and Swallow Sweep come up: %s" % [seen.keys()])
	assert_eq(_knockout_soak(12).loadouts, soak.loadouts, "the draw is seeded: a second run draws the same")


func test_the_ability_draw_leaves_the_matches_seeds_alone() -> void:
	# the draw has its own generator, so the weapons (and the difficulties)
	# come out as before it: the pinned mixed run above still holds
	var soak: SoakRun = _knockout_soak(9)
	for pair: Array in soak.loadouts:
		assert_eq((pair[0] as Array).size(), 2)
	assert_eq(soak.mirrors(), 4)


func test_mirror_matches_turn_win_rates_off() -> void:
	Roster.full = false
	var soak: SoakRun = _knockout_soak(3)
	assert_true(soak.lines.has("win rates: off until milestone 2"), "%s" % [soak.lines])
	assert_eq(soak.block("win rates, mirror matches left out:"), [] as Array[String])
	for line: String in soak.lines:
		assert_false(line.contains("wins 45-55%"), line)
		assert_false(line.begins_with("match wins/losses by weapon"), line)


func test_the_soak_counts_finishers_and_the_appear_list() -> void:
	Roster.full = false
	# made-up events just before each match's first fight: each appearance
	# once, the stomp twice, and the recall's own pick-up, which isn't a
	# pick-up from the ground
	var events := func(frames: int, W: World) -> void:
		if frames != Match.INTRO_FRAMES - 1:
			return
		var pos := {"x": 0.0, "y": 0.0, "z": 0.0}
		W.emit({"t": &"counter", "kind": &"stomp", "by": 0, "on": 1, "pos": pos})
		W.emit({"t": &"counter", "kind": &"stomp", "by": 1, "on": 0, "pos": pos})
		W.emit({"t": &"counter", "kind": &"leap", "by": 0, "on": 1, "pos": pos})
		W.emit({"t": &"parry", "parrier": 0, "attacker": 1, "pos": pos, "kind": &"flash", "timing": 3, "window": 18})
		W.emit({"t": &"parry", "parrier": 0, "attacker": 1, "pos": pos, "kind": &"parry", "timing": 3, "window": 9})
		W.emit({"t": &"ultStart", "f": 0, "ult": &"moonsplitter"})
		W.emit({"t": &"swing", "f": 1, "attack": &"f_breaker", "heavy": true, "weapon": &"fists"})
		W.emit({"t": &"swing", "f": 1, "attack": &"f_sl", "heavy": false, "weapon": &"fists"})
		W.emit({"t": &"recall", "f": 1})
		W.emit({"t": &"pickup", "f": 1})
		W.emit({"t": &"pickup", "f": 0})
	var soak: SoakRun = _knockout_soak(2, events)
	assert_eq(soak.failures, 0)
	assert_true(soak.lines.has("appearances: the stomp 4, the leap 2, Flash 2, Moonsplitter 2, Breaker Palm 2, the recall 2, a pick-up 2"), "%s" % [soak.lines])
	var targets: Array[String] = soak.block("targets (the spec's):")
	assert_eq(targets.slice(2), [
		"  finishers in some rounds: 0 of 6 rounds, out",
		"  the stomp at least once: 4, in",
		"  the leap at least once: 2, in",
		"  Flash at least once: 2, in",
		"  Moonsplitter at least once: 2, in",
		"  Breaker Palm at least once: 2, in",
		"  a pick-up at least once: 2, in",
	] as Array[String])
	assert_true(soak.lines.has("finishers: 0 of 6 rounds (0.0%), the share is set after the first balance run"), "%s" % [soak.lines])


func test_an_item_that_never_appears_is_out_but_no_failure() -> void:
	Roster.full = false
	var soak: SoakRun = _knockout_soak(2)
	assert_eq(soak.failures, 0)
	assert_true(soak.lines.has("appearances: the stomp 0, the leap 0, Flash 0, Moonsplitter 0, Breaker Palm 0, the recall 0, a pick-up 0"), "%s" % [soak.lines])
	assert_true(soak.block("targets (the spec's):").has("  the leap at least once: 0, out"), "%s" % [soak.lines])


func test_a_finisher_event_counts_toward_the_share() -> void:
	# the finisher (task 103) isn't built yet; the soak counts its event
	var t := Soak.Tally.new()
	t.rounds = 8
	t.finishers = 2
	t.avg_round_s = 70.0
	t.disarms_per_round = 0.5
	var lines: Array[String] = _balance(t)
	assert_true(lines.has("finishers: 2 of 8 rounds (25.0%), the share is set after the first balance run"), "%s" % [lines])
	assert_true(lines.has("  finishers in some rounds: 2 of 8 rounds, in"), "%s" % [lines])
	assert_true(lines.has("win rates: off until milestone 2"), "%s" % [lines])
