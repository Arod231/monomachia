extends SceneTree
## Port of scripts/soak.ts.
##
## Headless robot matches: computer vs computer at full speed.
## Verifies matches finish without errors and reports how often each mechanic
## occurs, each weapon's win rate against the other weapons, and whether the
## spec's balance targets are met (plan task 12.1).
##
## usage: node scripts/godot.mjs soak [matches]     (or: npm run soak -- 40)
##        npm run soak:tune                         (300 matches, for tuning)
##        npm run soak -- 40 --full-roster          (the hidden weapons too)
##
## Milestone 1 (tasks 4 and 7): by default it plays the matches milestone 1
## promises, the Hunter against the Hunter with the Katana, at random
## difficulties, each fighter's two block abilities drawn at random (seeded)
## from the Katana's three, so the stomp and the leap can both appear. Win
## rates are off until milestone 2; the targets block adds the finisher share
## (zero until task 103 adds the finisher) and the appear-list (the stomp,
## the leap, Flash, Moonsplitter, Breaker Palm and a pick-up, each at least
## once; the recall is reported too). With --full-roster it plays random
## pairs of the offered weapons and reports their win rates, as before
## milestone 1.
##
## Port notes:
## - The match count is the first user argument (after --), read like JS
##   Number(); the default is 30.
## - It uses the same seeds as the TS soak, and its report matched the TS
##   soak (v0.1-web-mvp:scripts/soak.ts) line for line up to commit 4222167
##   (plan task 8.2, which records that baseline). Since then the Godot rules
##   change on their own, so the report describes them alone. Numbers are
##   printed with JsFormat (JS toFixed and console.log of an object).
## - GDScript has no exceptions. The TS try/catch around each match is an
##   ErrorCatcher: a Logger that records the first error (a script error such
##   as a null access, a push_error or an engine error) raised while a match
##   runs. The match then ends and is reported as crashed at that frame, like
##   a TS throw. A failed sanity check (the TS throw) does the same.
## - The soak is run(): tests call it with their own output, a shorter frame
##   limit and a hook that runs before each step.
## - The exit code is 1 on any failure. If a script error aborts the run,
##   _process() still quits, with exit code 1. A target out of range is not a
##   failure.
## - The win rates, disarms per round and the targets block (report_balance)
##   come after the ported report, which is unchanged but for its
##   wins/losses line, printed only with the win rates.
## - The ability draw has its own generator, so the weapons and the
##   difficulties keep the seeds they had before milestone 1.

## 12 minutes of game time
const LIMIT: int = 60 * 60 * 12
## How far past the wall a fighter's centre may be before the match fails
## with "left the arena" (the demo's 12 m at its 11.5 m wall).
const LEFT_ARENA_SLACK: float = 0.5
## The spec's balance targets (milestone 1's balance-run targets), [low,
## high]: the average round in seconds (P24), disarms per round, and, with
## --full-roster, each weapon's win rate in percent against the other
## weapons. Doubles, not a Vector2: its 32-bit 0.3 is above 0.3 itself.
const TARGET_ROUND_S: Array[float] = [60.0, 90.0]
const TARGET_DISARMS: Array[float] = [0.3, 0.6]
const TARGET_WIN_RATE: Array[float] = [45.0, 55.0]
## The fighter every soak match plays (milestone 1's mirror).
const FIGHTER: StringName = &"hunter"
## How many block abilities each fighter takes into a match.
const ABILITIES: int = 2
## The appear-list, in the report's order: [key, name]. Each must appear at
## least once but the recall, which is reported only. A stomp or a leap is
## its counter landing, Flash a Flash parry, Moonsplitter its start,
## Breaker Palm its swing, a pick-up a weapon picked up from the ground (the
## recall's own pick-up isn't one).
const APPEAR: Array[Array] = [
	[&"stomp", "the stomp"],
	[&"leap", "the leap"],
	[&"flash", "Flash"],
	[&"moonsplitter", "Moonsplitter"],
	[&"breaker", "Breaker Palm"],
	[&"recall", "the recall"],
	[&"pickup", "a pick-up"],
]
## The appear-list's items that are reported but not targets.
const REPORTED_ONLY: Array[StringName] = [&"recall"]

## Stays 1 unless run() returns with no failures.
var _exit_code: int = 1


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var n: float = JsFormat.number(args[0]) if args.size() > 0 else 30.0
	var failures: int = run(n, func(s: String) -> void: print(s))
	_exit_code = 1 if failures > 0 else 0


func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true


## Runs N matches and returns the number of failures. Every line of the report
## goes to out.call(line). limit is the frame limit per match (LIMIT in the
## TS); before_step, when set, is called as before_step.call(m, frames, W)
## before each step.
static func run(N: float, out: Callable, limit: int = LIMIT, before_step: Callable = Callable()) -> int:
	var rng: Rng = Rng.new(2026)
	var ability_rng: Rng = Rng.new(2027)
	var offered: Array[StringName] = Roster.weapons()
	var mixed: bool = Roster.full
	var diffs: Array[StringName] = [&"easy", &"normal", &"hard"]
	var totals: Dictionary[String, int] = {}
	var total_rounds: int = 0
	var total_round_frames: int = 0
	var longest: int = 0
	## weapon id -> [wins, losses], in insertion order
	var wins_by_weapon: Dictionary[String, Array] = {}
	## weapon id -> (wins, matches) against another weapon (mirror matches left out)
	var records: Dictionary[String, Vector2i] = {}
	var disarms: int = 0
	var finishers: int = 0
	var appears: Dictionary[StringName, int] = {}
	for item: Array in APPEAR:
		appears[item[0]] = 0
	var failures: int = 0
	var catcher: ErrorCatcher = ErrorCatcher.new()
	OS.add_logger(catcher)

	var m: int = 0
	while float(m) < N:
		var w0: StringName = rng.pick(offered)
		var w1: StringName = rng.pick(offered)
		var d0: StringName = rng.pick(diffs)
		var d1: StringName = rng.pick(diffs)
		var W: World = World.new(_config(w0, ability_rng), _config(w1, ability_rng), 1000 + m)
		var M: Match = Match.new(W)
		var ai: Array[AIBrain] = [
			AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[d0], 11 + m),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[d1], 77 + m),
		]
		var frames: int = 0
		var round_start: int = 0
		var error: String = "" # the TS throw
		var recalling: Array[bool] = [false, false]
		catcher.first = "" # try {
		while M.phase != &"matchEnd" and frames < limit:
			if not before_step.is_null():
				before_step.call(m, frames, W)
			M.step([ai[0].think(), ai[1].think()])
			if catcher.first != "":
				error = catcher.first
				break
			frames += 1
			for e: Dictionary in W.drain_events():
				match e["t"]:
					&"fight":
						round_start = frames
					&"roundOver":
						var length: int = frames - round_start # len
						total_rounds += 1
						total_round_frames += length
						longest = maxi(longest, length)
					&"parry":
						_add(totals, "parry:" + String(e["kind"]))
						if e["kind"] == &"flash":
							appears[&"flash"] += 1
					&"counter":
						_add(totals, "counter:" + String(e["kind"]))
						if appears.has(e["kind"]):
							appears[e["kind"]] += 1
					&"swing":
						if e["attack"] == &"f_breaker":
							appears[&"breaker"] += 1
					&"hit":
						_add(totals, "hits")
					&"block":
						_add(totals, "blocks")
					&"disarm":
						_add(totals, "disarm:" + String(e["reason"]))
						disarms += 1
					&"ultStart":
						_add(totals, "ult:" + String(e["ult"]))
						if e["ult"] == &"moonsplitter":
							appears[&"moonsplitter"] += 1
					&"ultChoice":
						_add(totals, "ult:disarmedChoice")
					&"recall":
						_add(totals, "recall")
						appears[&"recall"] += 1
						recalling[int(e["f"])] = true
					&"pickup":
						_add(totals, "rearm")
						if recalling[int(e["f"])]:
							recalling[int(e["f"])] = false
						else:
							appears[&"pickup"] += 1
					&"finisher":
						# the finisher (task 103) emits it; nothing does yet
						finishers += 1
					&"stagger":
						_add(totals, "stagger")
					&"evade":
						_add(totals, "evade")
					&"knockdown":
						_add(totals, "knockdown")
					&"ko":
						if int(e["winner"]) < 0:
							_add(totals, "doubleKO")
			# sanity checks
			for f: Fighter in W.fighters:
				if M.phase == &"fight" and f.posture_full():
					_add(totals, "framesAtFullPosture")
				if not is_finite(f.pos.x) or not is_finite(f.pos.z) or not is_finite(f.hp):
					error = "Error: NaN state"
					break
				if JsMath.hypot(f.pos.x, f.pos.z) > SimConst.ARENA_RADIUS + LEFT_ARENA_SLACK:
					error = "Error: left the arena"
					break
				if f.posture < -1e-6 or f.posture > 100.0001:
					error = "Error: posture out of range " + JsFormat.num(f.posture)
					break
			if error == "" and catcher.first != "":
				error = catcher.first
			if error != "":
				break
		if error != "":
			failures += 1
			out.call("match %d crashed at frame %d: %s" % [m, frames, error])
		elif M.phase != &"matchEnd":
			failures += 1
			out.call("match %d (%s/%s vs %s/%s) did not finish: wins %d,%d" % [m, w0, d0, w1, d1, M.wins[0], M.wins[1]])
		else:
			if not wins_by_weapon.has(String(w0)):
				wins_by_weapon[String(w0)] = [0, 0]
			if not wins_by_weapon.has(String(w1)):
				wins_by_weapon[String(w1)] = [0, 0]
			wins_by_weapon[String(w0 if M.match_winner == 0 else w1)][0] += 1
			wins_by_weapon[String(w1 if M.match_winner == 0 else w0)][1] += 1
			if w0 != w1:
				var winner: StringName = w0 if M.match_winner == 0 else w1
				for w: StringName in [w0, w1]:
					records[String(w)] = records.get(String(w), Vector2i()) + Vector2i(1 if w == winner else 0, 1)
		for brain: AIBrain in ai:
			brain.dispose()
		W.dispose()
		m += 1
	OS.remove_logger(catcher)

	var rounds: int = maxi(1, total_rounds)
	var avg_round_s: float = float(total_round_frames) / float(rounds) / 60.0
	out.call("\n%s matches, %d failures" % [JsFormat.num(N), failures])
	out.call("rounds: %d, avg round %s s, longest %s s" % [
		total_rounds,
		JsFormat.to_fixed(avg_round_s, 1),
		JsFormat.to_fixed(float(longest) / 60.0, 1),
	])
	out.call("per round:")
	# Object.entries(totals).sort(): the default sort compares "key,value" strings.
	var keys: Array[String] = []
	keys.assign(totals.keys())
	keys.sort_custom(func(a: String, b: String) -> bool: return "%s,%d" % [a, totals[a]] < "%s,%d" % [b, totals[b]])
	for k: String in keys:
		out.call("  %s %s" % [k.rpad(22), JsFormat.to_fixed(float(totals[k]) / float(rounds), 2)])
	if mixed:
		out.call("match wins/losses by weapon: " + JsFormat.inspect(wins_by_weapon))
	var t: Tally = Tally.new()
	t.win_rates = mixed
	t.rounds = total_rounds
	t.avg_round_s = avg_round_s
	t.disarms_per_round = float(disarms) / float(rounds)
	t.finishers = finishers
	t.appears = appears
	t.records = records
	report_balance(out, t)
	return failures


## A soak fighter's config: the Hunter with weapon `id` and ABILITIES of its
## block abilities, drawn from `draw` without repeats.
static func _config(id: StringName, draw: Rng) -> FighterConfig:
	var weapon: WeaponDef = Moves.WEAPONS[id]
	var pool: Array[StringName] = weapon.abilities.duplicate()
	var picked: Array[StringName] = []
	while picked.size() < ABILITIES and not pool.is_empty():
		picked.append(pool.pop_at(draw.int(0, pool.size() - 1)))
	return FighterConfig.make(weapon, picked, "", FIGHTER)


## What report_balance reports: the run's numbers.
class Tally:
	## Whether the run reports each weapon's win rate (--full-roster).
	var win_rates: bool = false
	var rounds: int = 0
	var avg_round_s: float = 0.0
	var disarms_per_round: float = 0.0
	## Rounds that ended in a finisher.
	var finishers: int = 0
	## How often each APPEAR item appeared; a missing key counts as 0.
	var appears: Dictionary[StringName, int] = {}
	## weapon id -> (wins, matches) against another weapon.
	var records: Dictionary[String, Vector2i] = {}


## The balance lines after the ported report: each weapon's win rate against
## the other weapons from its records (wins, matches) with --full-roster,
## else that win rates are off; disarms per round; the finisher share; the
## appear-list; and the targets block marking each number in or out of the
## spec's ranges. Each mark judges the number as printed, so a line never
## reads "0.60, out".
static func report_balance(out: Callable, t: Tally) -> void:
	var win_rates: Array[String] = [] # as printed, or "" with no matches
	var offered: Array[StringName] = Roster.weapons()
	if t.win_rates:
		out.call("win rates, mirror matches left out:")
		for id: StringName in offered:
			var r: Vector2i = t.records.get(String(id), Vector2i())
			win_rates.append("" if r.y == 0 else JsFormat.to_fixed(100.0 * float(r.x) / float(r.y), 1))
			out.call("  %s: %s" % [id, "no matches" if r.y == 0 else "%s%% (%d of %d)" % [win_rates.back(), r.x, r.y]])
	else:
		out.call("win rates: off until milestone 2")
	var disarms_text: String = JsFormat.to_fixed(t.disarms_per_round, 2)
	var round_text: String = JsFormat.to_fixed(t.avg_round_s, 1)
	out.call("disarms per round: " + disarms_text)
	var share: float = 0.0 if t.rounds == 0 else 100.0 * float(t.finishers) / float(t.rounds)
	out.call("finishers: %d of %d rounds (%s%%), the share is set after the first balance run" % [t.finishers, t.rounds, JsFormat.to_fixed(share, 1)])
	var seen: PackedStringArray = []
	for item: Array in APPEAR:
		seen.append("%s %d" % [item[1], t.appears.get(item[0], 0)])
	out.call("appearances: " + ", ".join(seen))
	out.call("targets (the spec's):")
	out.call("  rounds of %s s: %s s, %s" % [_range(TARGET_ROUND_S), round_text, _mark(round_text, TARGET_ROUND_S)])
	out.call("  disarms %s per round: %s, %s" % [_range(TARGET_DISARMS), disarms_text, _mark(disarms_text, TARGET_DISARMS)])
	out.call("  finishers in some rounds: %d of %d rounds, %s" % [t.finishers, t.rounds, "in" if t.finishers > 0 else "out"])
	for item: Array in APPEAR:
		if REPORTED_ONLY.has(item[0]):
			continue
		var n: int = t.appears.get(item[0], 0)
		out.call("  %s at least once: %d, %s" % [item[1], n, "in" if n > 0 else "out"])
	if t.win_rates:
		for i: int in offered.size():
			var shown: String = "no matches" if win_rates[i] == "" else win_rates[i] + "%"
			out.call("  %s wins %s%%: %s, %s" % [offered[i], _range(TARGET_WIN_RATE), shown, _mark(win_rates[i], TARGET_WIN_RATE)])


## "60-90" for [60, 90].
static func _range(target: Array[float]) -> String:
	return "%s-%s" % [JsFormat.num(target[0]), JsFormat.num(target[1])]


## "in" when the printed number shown lies in target, else "out" (also for "").
static func _mark(shown: String, target: Array[float]) -> String:
	if shown == "":
		return "out"
	var v: float = shown.to_float()
	return "in" if v >= target[0] and v <= target[1] else "out"


static func _add(totals: Dictionary[String, int], k: String, v: int = 1) -> void:
	totals[k] = totals.get(k, 0) + v


## Records the first error raised on the main thread since first was cleared,
## as "Error: <message>" with the place it came from.
class ErrorCatcher:
	extends Logger

	var first: String = ""

	func _log_error(
		function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type == ERROR_TYPE_WARNING or first != "":
			return
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			return
		var message: String = rationale if rationale != "" else code
		first = "Error: %s\n    at %s (%s:%d)" % [message, function, file, line]
