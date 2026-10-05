extends GutTest
## The soak's balance report (plan task 12.1): win rates with mirror matches
## left out, disarms per round, and the spec's targets marked in or out.

const Soak := preload("res://tools/soak.gd")


# These pin the soak over all three weapons, so they run with the whole
# roster; test_the_soak_plays_the_roster_s_weapons covers the default.
func before_each() -> void:
	Roster.full = true


func after_each() -> void:
	Roster.reset()


## A soak's report lines, failures, and each match's two weapons.
class SoakRun:
	var lines: Array[String] = []
	var pairs: Array[PackedStringArray] = []
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
## fight starts, so fighter 0 wins every match.
static func _knockout_soak(matches: int) -> SoakRun:
	var r := SoakRun.new()
	var hook := func(_m: int, frames: int, W: World) -> void:
		if frames == 0:
			r.pairs.append(PackedStringArray([W.fighters[0].moveset().id, W.fighters[1].moveset().id]))
		if W.fighters[1].state == &"free":
			W.fighters[1].hp = 0.0
	r.failures = Soak.run(float(matches), func(s: String) -> void: r.lines.append(s), 3000, hook)
	return r


## report_balance's lines for the given numbers.
static func _balance(avg_round_s: float, disarms_per_round: float, records: Dictionary[String, Vector2i]) -> Array[String]:
	var lines: Array[String] = []
	Soak.report_balance(func(s: String) -> void: lines.append(s), avg_round_s, disarms_per_round, records)
	return lines


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
		"  rounds of 35-60 s: 0.7 s, out",
		"  disarms 0.3-0.6 per round: 0.00, out",
	] as Array[String])


func test_the_targets_take_their_ends_as_in() -> void:
	var lines: Array[String] = _balance(35.0, 0.6, {"katana": Vector2i(9, 20), "greatsword": Vector2i(11, 20), "daggers": Vector2i(1101, 2000)})
	assert_eq(lines, [
		"win rates, mirror matches left out:",
		"  katana: 45.0% (9 of 20)",
		"  greatsword: 55.0% (11 of 20)",
		"  daggers: 55.0% (1101 of 2000)",
		"disarms per round: 0.60",
		"targets (the spec's):",
		"  rounds of 35-60 s: 35.0 s, in",
		"  disarms 0.3-0.6 per round: 0.60, in",
		"  katana wins 45-55%: 45.0%, in",
		"  greatsword wins 45-55%: 55.0%, in",
		"  daggers wins 45-55%: 55.0%, in",
	] as Array[String], "55.05% prints as 55.0%, and is judged as printed")


func test_the_targets_mark_numbers_past_their_ends_out() -> void:
	var lines: Array[String] = _balance(60.06, 0.296, {"katana": Vector2i(889, 2000), "greatsword": Vector2i(1112, 2000)})
	assert_eq(lines.slice(5), [
		"targets (the spec's):",
		"  rounds of 35-60 s: 60.1 s, out",
		"  disarms 0.3-0.6 per round: 0.30, in",
		"  katana wins 45-55%: 44.5%, out",
		"  greatsword wins 45-55%: 55.6%, out",
		"  daggers wins 45-55%: no matches, out",
	] as Array[String], "0.296 prints as 0.30 and is in; the rest are past their ends")


func test_the_soak_plays_the_roster_s_weapons() -> void:
	# milestone 1 (task 4): without --full-roster only the Katana is offered
	Roster.full = false
	var soak: SoakRun = _knockout_soak(4)
	assert_eq(soak.failures, 0)
	for p: PackedStringArray in soak.pairs:
		assert_eq(p, PackedStringArray(["katana", "katana"]))
	assert_eq(soak.block("win rates, mirror matches left out:"), ["  katana: no matches"] as Array[String])
