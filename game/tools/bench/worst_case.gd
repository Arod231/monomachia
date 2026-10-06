class_name WorstCase
extends RefCounted
## The worst-case replay (milestone-1 task 28, stories 201 and 202): the
## match every performance bench plays, recorded as an input log and
## committed at PATH, so each bench measures the same match. Its last STEPS
## steps (90 s), the window the harness times, show everything REQUIRED:
## both ultimates (Moonsplitter and Breaker Palm) and a stretch at the wall.
## The steps before the window are its lead-in, which the harness plays
## untimed. Blood and the petals come with it once the effects and the arena
## have them, since every worst case has hits on the Shrine; the finisher is
## counted now and joins REQUIRED when task 103 adds it.
##
## The log is found by a seeded search (the owner's choice, Oct 5): search()
## plays Hard-against-Hard Hunter mirrors with the Katana on the Moonlit
## Shrine, seed after seed, and keeps the first one with a 90 s window
## holding every item, cut at that window's end. (The ultimates need low
## health, so they come late in a round, and few matches show them and a
## stretch at the wall in their first 90 s.) Rules changes make the log
## drift, which test_frame_time_bench.gd catches; `npm run bench:record`
## (tools/bench/record_worst_case.gd) searches again and rewrites it. The
## match is recorded as Watch and saved as a Duel, so the harness shows it
## from the Duel's camera with its HUD: the rules don't know the mode, and a
## replay feeds the log's inputs to both sides either way.

const PATH: String = "res://tools/bench/worst_case.json"
## The timed window: 90 s of rules steps.
const STEPS: int = 90 * 60
## How far into a match the search looks for the window's end: 5 minutes.
const LIMIT: int = 5 * 60 * 60
## A fighter is at the wall within this of where the rules stop its centre
## (m), for at least WALL_STEPS steps in a row of the fight.
const WALL_SLACK: float = 0.5
const WALL_STEPS: int = 60
## What the worst case must show, in the report's order: [key, name].
const REQUIRED: Array[Array] = [
	[&"moonsplitter", "Moonsplitter"],
	[&"breaker", "Breaker Palm"],
	[&"wall", "a stretch at the wall"],
]
## Counted and reported, not required yet: the finisher (task 103).
const REPORTED: Array[Array] = [
	[&"finisher", "a finisher"],
]


## What a stretch of a match showed: each item's count and the longest run
## at the wall, observed step by step.
class Coverage:
	extends RefCounted

	var counts: Dictionary[StringName, int] = {}
	## The longest run of fight steps with a fighter at the wall.
	var longest_wall: int = 0
	var _wall_run: int = 0

	func _init() -> void:
		for item: Array in WorstCase.REQUIRED + WorstCase.REPORTED:
			counts[item[0]] = 0

	## One step: its events, whether a fighter stood at the wall after it, and
	## whether the fight was on (not the intro or a round's end).
	func observe(events: Array, at_wall: bool, fighting: bool) -> void:
		for e: Dictionary in events:
			var item: StringName = WorstCase.item_of(e)
			if item != &"":
				counts[item] += 1
		if at_wall and fighting:
			_wall_run += 1
			longest_wall = maxi(longest_wall, _wall_run)
			if _wall_run == WorstCase.WALL_STEPS:
				counts[&"wall"] += 1
		else:
			_wall_run = 0

	## The names of the REQUIRED items not seen.
	func missing() -> Array[String]:
		var out: Array[String] = []
		for item: Array in WorstCase.REQUIRED:
			if counts[item[0]] == 0:
				out.append(item[1])
		return out

	## "Moonsplitter 1, Breaker Palm 2, a stretch at the wall 1 (longest 2.4 s), a finisher 0".
	func line() -> String:
		var parts := PackedStringArray()
		for item: Array in WorstCase.REQUIRED + WorstCase.REPORTED:
			var part: String = "%s %d" % [item[1], counts[item[0]]]
			if item[0] == &"wall":
				part += " (longest %.1f s)" % (longest_wall * SimConst.DT)
			parts.append(part)
		return ", ".join(parts)


## A whole match, step by step, as the search sees it: the events that count
## toward an item and whether a fighter stood at the wall during the fight.
class Timeline:
	extends RefCounted

	## Step index (0 is the first step) -> the events there that count.
	var events: Dictionary[int, Array] = {}
	## Per step: 1 when a fighter stood at the wall during the fight.
	var wall: PackedByteArray = PackedByteArray()

	func size() -> int:
		return wall.size()

	## Appends one step.
	func add(step_events: Array, at_wall: bool, fighting: bool) -> void:
		var kept: Array = []
		for e: Dictionary in step_events:
			if WorstCase.item_of(e) != &"":
				kept.append(e)
		if not kept.is_empty():
			events[wall.size()] = kept
		wall.append(1 if at_wall and fighting else 0)

	## What steps [from, to) show.
	func coverage(from: int, to: int) -> Coverage:
		var c := Coverage.new()
		for i: int in range(from, to):
			c.observe(events.get(i, []), wall[i] == 1, true)
		return c

	## The smallest end (a step count of at least `window`) whose last
	## `window` steps show every REQUIRED item, or -1.
	func earliest_end(window: int) -> int:
		if size() < window:
			return -1
		# per item, the steps it happened at, and the wall's runs [start, end)
		var at: Dictionary[StringName, PackedInt32Array] = {}
		for item: Array in WorstCase.REQUIRED:
			at[item[0]] = PackedInt32Array()
		var steps: Array[int] = events.keys()
		steps.sort()
		for s: int in steps:
			for e: Dictionary in events[s]:
				var item: StringName = WorstCase.item_of(e)
				if at.has(item):
					at[item].append(s)
		var runs: Array[Vector2i] = []
		var start: int = -1
		for i: int in size() + 1:
			var on: bool = i < size() and wall[i] == 1
			if on and start < 0:
				start = i
			elif not on and start >= 0:
				runs.append(Vector2i(start, i))
				start = -1
		for end: int in range(window, size() + 1):
			var from: int = end - window
			if _shows_all(at, runs, from, end):
				return end
		return -1

	static func _shows_all(at: Dictionary[StringName, PackedInt32Array], runs: Array[Vector2i], from: int, to: int) -> bool:
		for item: StringName in at:
			if item == &"wall":
				continue
			var seen: bool = false
			for s: int in at[item]:
				if s >= from and s < to:
					seen = true
					break
			if not seen:
				return false
		for r: Vector2i in runs:
			if mini(r.y, to) - maxi(r.x, from) >= WorstCase.WALL_STEPS:
				return true
		return false


## The item a rules event counts toward (moonsplitter, breaker, finisher), or
## &"" for none.
static func item_of(e: Dictionary) -> StringName:
	match e["t"]:
		&"ultStart":
			if e.get("ult") == &"moonsplitter":
				return &"moonsplitter"
		&"swing":
			if e.get("attack") == &"f_breaker":
				return &"breaker"
		&"finisher":
			return &"finisher"
	return &""


## Whether a fighter's centre at pos is at the wall.
static func near_wall(pos: V3) -> bool:
	return JsMath.hypot(pos.x, pos.z) >= SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS - WALL_SLACK


## The match a seed records: Watch, the Hunter mirror with the Katana and its
## default block abilities, both Hard, on the Moonlit Shrine.
static func config(seed_value: int) -> MatchConfig:
	return MatchConfig.make(
		MatchConfig.WATCH,
		MatchSide.computer(MatchConfig.DEFAULT_FIGHTER, MatchConfig.DEFAULT_WEAPON, 0, &"hard"),
		MatchSide.computer(MatchConfig.DEFAULT_FIGHTER, MatchConfig.DEFAULT_WEAPON, 1, &"hard"),
		seed_value,
		MatchConfig.DEFAULT_ARENA,
	)


## Plays a seed's match for up to `steps` steps (fewer if it ends) and
## returns its log, ended there and saved as a Duel.
static func record(seed_value: int, steps: int) -> InputLog:
	var host: MatchHost = _host()
	host.start(config(seed_value))
	_play(host, steps)
	var log_out: InputLog = host.input_log
	host.stop()
	host.free()
	log_out.config.mode = MatchConfig.DUEL
	log_out.config.sides[0].controller = MatchSide.HUMAN
	return log_out


## Plays a seed's match for up to `steps` steps (fewer if it ends): its
## Timeline.
static func timeline(seed_value: int, steps: int = LIMIT) -> Timeline:
	var host: MatchHost = _host()
	host.start(config(seed_value))
	var t: Timeline = _play(host, steps)
	host.stop()
	host.free()
	return t


## Replays a log headless to its end: { "ok", "report" (the host's line about
## matching the log), "coverage" (what its last `window` steps showed) }.
static func replay(log_in: InputLog, window: int = STEPS) -> Dictionary:
	var host: MatchHost = _host()
	var result: Dictionary = {"ok": false, "report": "the log's config can't start a match", "coverage": Coverage.new()}
	host.replay_checked.connect(func(ok: bool, report: String) -> void:
		result["ok"] = ok
		result["report"] = report)
	if host.start_replay(log_in):
		var t: Timeline = _play(host, log_in.step_count())
		result["coverage"] = t.coverage(maxi(0, t.size() - window), t.size())
		host.step(1) # past the log's end: the host checks it
	host.stop()
	host.free()
	return result


## Seeds first_seed, first_seed + 1, ... up to `tries` of them, until one has
## a STEPS window showing every REQUIRED item within its first LIMIT steps:
## { "seed", "log" (cut at the earliest such window's end), "coverage" (the
## window's) }, or {} when none does. Each seed tried is reported to
## out.call(line).
static func search(first_seed: int, tries: int, out: Callable) -> Dictionary:
	for s: int in range(first_seed, first_seed + tries):
		var t: Timeline = timeline(s)
		var end: int = t.earliest_end(STEPS)
		if end < 0:
			var best: Coverage = t.coverage(0, t.size())
			out.call("seed %d: no window (the whole %.0f s: %s)" % [s, t.size() * SimConst.DT, best.line()])
			continue
		var coverage: Coverage = t.coverage(end - STEPS, end)
		out.call("seed %d: %.1f s of lead-in, then %s" % [s, (end - STEPS) * SimConst.DT, coverage.line()])
		return {"seed": s, "log": record(s, end), "coverage": coverage}
	return {}


static func _host() -> MatchHost:
	var host: MatchHost = MatchHost.new()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	return host


## Steps a started host up to `steps` times (stopping when its match ends),
## observing every step.
static func _play(host: MatchHost, steps: int) -> Timeline:
	var t := Timeline.new()
	var events: Array[Dictionary] = []
	var keep: Callable = func(e: Dictionary) -> void: events.append(e)
	host.sim_event.connect(keep)
	while host.step_count < steps and host.sim_match.phase != &"matchEnd":
		events.clear()
		if host.step(1) == 0:
			break
		var at_wall: bool = false
		for f: Fighter in host.world.fighters:
			at_wall = at_wall or near_wall(f.pos)
		t.add(events, at_wall, host.sim_match.phase == &"fight")
	host.sim_event.disconnect(keep)
	return t
