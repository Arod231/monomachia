class_name MatchHost
extends Node
## The fixed-step match host: owns the rules (World, Match, the computer
## brains), feeds them each side's input 60 times per second, and hands every
## rules event to the presentation. Port of the loop in v0.1-web-mvp:src/game.ts.
##
## The rules never see the wall clock. In _process() the host adds the frame's
## time to an accumulator, scaled by the rules' slow motion
## (world.time_scale(), not Engine.time_scale, so menus and the HUD keep real
## time), and steps the rules once per 1/60 s in the accumulator, at most
## MAX_STEPS_PER_FRAME times per frame: past that it drops the backlog, like
## the demo. Tests and screenshot scenes skip the clock: set auto_run = false
## and call step(n), or advance(delta) with a made-up delta.
##
## Each step:
## 1. gathers both sides' RawInput, side 0 first: a computer side's
##    AIBrain.think() (or the training dummy's), a human side's
##    InputDevices.sample(player), as the demo and the soak run do;
## 2. calls Match.step();
## 3. drains the world's events and emits sim_event once per event, in the
##    world's order, then stepped. The view, the HUD and the audio listen to
##    these signals; they read the rules' state and never change it.
##
## For drawing between steps the host keeps each fighter's position and yaw
## from before and after the last step; display_position() and display_yaw()
## blend them by alpha(), the fraction of a step in the accumulator. While the
## rules stand still (hit-stop, and after the last hit-stop step until a step
## moves the world's frame again) alpha() holds at 1, the impact frame, so
## poses neither jitter nor step back. A new round (roundStart) places the
## fighters instead of blending them.
##
## Pause: the pause binding, Esc or Start pauses a match being played; while
## it is paused the same press resumes it, as Back does in the pause menu. A
## rule button pressed while the match stands still (or held when it starts),
## such as the menu's A, B or Space, is ignored until it is let go, so it
## doesn't jump or dodge on resume; a button held through the pause carries on.
## While pause_press_resumes is off (a screen opened over the pause menu, where
## Esc is that screen's Back), the presses are still read but don't resume.
##
## A match ends on the results data, 140 frames into the match-end phase (as
## the demo): match_finished carries a MatchResults. The duel behind the menus
## (attract) never finishes: it restarts with the next seed (from seed_source)
## 240 frames after its match ends.
##
## Training runs the rules' endless match against the dummy, with its upkeep
## (TrainingUpkeep: getting up after a K.O., the refill, the dummy re-arming)
## stepped after each rules step, inside the fixed step. set_refill() turns
## the refill off and on; every match starts with it on.
## set_training_behaviour() tells the dummy what to do, swapping its weapon
## in the rules first when it can't (TrainingUpkeep.weapon_for), and
## loadout_changed tells the view and the HUD; training_changed tells
## Training's panel and pause rows of any change to the behaviour or refill. Versus samples two
## humans on two different devices.

## The match was (re)started from a config: views rebuild from it.
signal match_started(config: MatchConfig)
## One rules event (a SimEvents Dictionary), in the order the world emitted it.
signal sim_event(e: Dictionary)
## A rules step finished and its events were dispatched. step is step_count.
signal stepped(step: int)
## The match is over: show the results.
signal match_finished(results: MatchResults)
signal pause_changed(paused: bool)
## stop() threw the match away (quit to menu).
signal stopped
## A side's weapon changed mid-match (the training dummy's, for a behaviour):
## views re-read fighter(side).weapon.
signal loadout_changed(side: int)
## Training's dummy behaviour or refill changed (set_training_behaviour,
## set_refill).
signal training_changed

const DT: float = SimConst.DT
const MAX_STEPS_PER_FRAME: int = 6
## The longest frame the accumulator takes in (s), as the demo's cap.
const MAX_FRAME_DELTA: float = 0.1
## Frames into the match-end phase before the results open.
const RESULTS_DELAY: int = 140
## Frames into the match-end phase before the attract duel restarts.
const ATTRACT_RESTART: int = 240

## Step with the wall clock in _process(). Off for tests and screenshot scenes,
## which call step(n).
@export var auto_run: bool = true
## Register with the GameServices autoload while a match is played (pause on
## focus loss) and take its InputDevices and ControlProfiles when none were
## given.
@export var use_services: bool = true

var config: MatchConfig
var world: World
var sim_match: Match
## The input every human side is sampled from. Set before start() to inject
## one (tests); otherwise GameServices' (or a fresh one without the autoload).
var input: InputDevices
var profiles: ControlProfiles
## The duel behind the menus: no human input, no results, restarts forever.
var attract: bool = false
## Rules steps taken since start(), including hit-stop steps.
var step_count: int = 0
## Where the attract duel's next seed comes from when it restarts: returns an
## int. main.gd hands it its own seed sequence, so the menus' matches and the
## attract restarts never share a seed. Unset: MatchConfig.next_seed() of the
## current one.
var seed_source: Callable = Callable()
## Whether the pause binding, Esc or Start resumes a paused match. main.gd
## turns it off while a screen is open over the pause menu.
var pause_press_resumes: bool = true

## Per side: an AIBrain, a TrainingBrain, or null for a human.
var _brains: Array[RefCounted] = [null, null]
## Training's upkeep, or null outside Training.
var _upkeep: TrainingUpkeep = null
## Per side: the InputDevices player index, or -1 for a computer side.
var _player_of_side: Array[int] = [-1, -1]
var _acc: float = 0.0
var _started: bool = false
var _paused: bool = false
var _finished: bool = false
var _restart_pending: bool = false
var _prev_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _cur_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _prev_yaw: Array[float] = [0.0, 0.0]
var _cur_yaw: Array[float] = [0.0, 0.0]
## Did the last step move the world's frame (false for a hit-stop step)?
var _last_step_moved: bool = true
## Per side: the rule buttons held at the last sample, and the ones ignored
## until they are let go (pressed in a menu).
var _last_buttons: Array[int] = [0, 0]
var _suppressed: Array[int] = [0, 0]


# ------------------------------------------------------------------ lifecycle

## Builds the rules from a config and starts its first round. A match already
## running is thrown away. Dispatches the intro's events (roundStart) at once.
## Returns false, changing nothing, when the config can't start a match.
func start(cfg: MatchConfig, p_attract: bool = false) -> bool:
	var problem: String = cfg.problem()
	if problem != "":
		push_error("MatchHost: bad match config: %s" % problem)
		return false
	_teardown()
	config = cfg
	attract = p_attract
	var s0: MatchSide = cfg.sides[0]
	var s1: MatchSide = cfg.sides[1]
	world = World.new(
		FighterConfig.make(s0.weapon(), s0.resolved_abilities(), s0.display_name(), s0.fighter_id),
		FighterConfig.make(s1.weapon(), s1.resolved_abilities(), s1.display_name(), s1.fighter_id),
		cfg.world_seed,
	)
	sim_match = Match.new(world)
	if cfg.mode == MatchConfig.TRAINING:
		sim_match.endless = true
		_upkeep = TrainingUpkeep.new(world, cfg.dummy_side())
		_upkeep.weapons = Roster.weapons()
	for i: int in 2:
		var side: MatchSide = cfg.sides[i]
		match side.controller:
			MatchSide.COMPUTER:
				_brains[i] = AIBrain.new(world.fighters[i], AIBrain.DIFFICULTY[side.difficulty], cfg.world_seed + i * 17)
			MatchSide.DUMMY:
				_brains[i] = TrainingBrain.new(world.fighters[i])
			_:
				_brains[i] = null
	_setup_input()
	_acc = 0.0
	step_count = 0
	_paused = false
	_finished = false
	_restart_pending = false
	_last_step_moved = true
	_last_buttons = [0, 0]
	_suppress_new_presses()
	_started = true
	_snapshot(true)
	var services: Node = _services()
	if services != null:
		if attract:
			services.call("end_match", self)
		else:
			services.call("begin_match", self)
	match_started.emit(cfg)
	_dispatch(world.drain_events())
	return true


## Stops the match and frees the rules (quit to menu). The view keeps its last
## picture until the next start().
func stop() -> void:
	_teardown()
	var services: Node = _services()
	if services != null:
		services.call("end_match", self)
	if input != null:
		input.unbind_seats()
	stopped.emit()


func is_started() -> bool:
	return _started


## True while a real match is being played: started, not the attract duel,
## not paused and not over.
func is_playing() -> bool:
	return _started and not attract and not _paused and not _finished


func is_paused() -> bool:
	return _paused


func is_finished() -> bool:
	return _finished


## Stops the clock (and step()). Only a match being played can pause.
func pause() -> void:
	if not is_playing():
		return
	_paused = true
	pause_changed.emit(true)


## Restarts the clock, picking up a profile the pause menu may have changed,
## ignoring a pause button still held from the menu, and ignoring the rule
## buttons pressed during the pause until they are let go.
func resume() -> void:
	if not _paused:
		return
	_paused = false
	_acc = 0.0
	if input != null:
		for i: int in 2:
			var p: int = _player_of_side[i]
			if p >= 0:
				input.set_profile(p, _profile_for(config.sides[i]))
		_suppress_new_presses()
		input.rearm_pause()
	pause_changed.emit(false)


func _process(delta: float) -> void:
	if not auto_run or not _started:
		return
	if input != null:
		if _paused:
			# the pause binding, Esc or Start closes the pause, as Back does;
			# the presses are read either way, so their edges stay current
			if input.any_pause_pressed() and pause_press_resumes:
				resume()
			return
		if is_playing() and input.any_pause_pressed():
			pause()
			return
	advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_teardown()


func _exit_tree() -> void:
	var services: Node = _services()
	if services != null:
		services.call("end_match", self)


# ------------------------------------------------------------------ the clock

## Feeds delta seconds of wall time to the accumulator and steps the rules as
## often as it holds (at most MAX_STEPS_PER_FRAME; past that the backlog is
## dropped). Returns the number of steps taken. Nothing happens while paused.
func advance(delta: float) -> int:
	if not _started or _paused:
		return 0
	_acc += clampf(delta, 0.0, MAX_FRAME_DELTA) * world.time_scale()
	var n: int = 0
	while _acc >= DT and n < MAX_STEPS_PER_FRAME:
		_step_once()
		_acc -= DT
		n += 1
		if _paused or _restart_pending:
			break
	if n >= MAX_STEPS_PER_FRAME:
		_acc = 0.0
	_maybe_restart_attract()
	return n


## Steps the rules n times now, without the clock (tests, screenshot scenes).
## Stops early when the match is paused. Returns the number of steps taken.
func step(n: int = 1) -> int:
	var done: int = 0
	while done < n and _started and not _paused:
		_step_once()
		done += 1
		_maybe_restart_attract()
	return done


## The fraction of a step waiting in the accumulator, 0..1: how far to blend
## from the state before the last step to the state after it. Held at 1
## while the rules stand still (hit-stop, and after the last hit-stop step
## until a step moves the world's frame again), so the impact frame shows
## still and nothing steps back when the freeze ends.
func alpha() -> float:
	if not _started:
		return 0.0
	if world.hitstop > 0 or not _last_step_moved:
		return 1.0
	return clampf(_acc / DT, 0.0, 1.0)


## The time in the accumulator (s), for tests.
func accumulated() -> float:
	return _acc


# ------------------------------------------------------------------ reading the match

func fighter(i: int) -> Fighter:
	return world.fighters[i]


## The brain playing side `i`: an AIBrain, a TrainingBrain (the dummy, whose
## behaviour the swing debug shot sets), or null for a human side.
func brain(i: int) -> RefCounted:
	return _brains[i]


## Where to draw a fighter now: blended between the last two steps.
func display_position(i: int) -> Vector3:
	return _prev_pos[i].lerp(_cur_pos[i], alpha())


func display_yaw(i: int) -> float:
	return lerp_angle(_prev_yaw[i], _cur_yaw[i], alpha())


## The InputDevices player index of a side, or -1 for a computer side.
func player_of_side(i: int) -> int:
	return _player_of_side[i]


## The side the camera and HUD follow: the first human side, else side 0.
func view_side() -> int:
	if config == null:
		return 0
	var h: int = config.first_human_side()
	return h if h >= 0 else 0


## The name of the input a side's player presses for an action ("" for a
## computer side).
func label(action: String, side: int) -> String:
	var p: int = _player_of_side[side]
	if p < 0 or input == null:
		return ""
	return input.label(action, p)


## Whether a side's player names controller buttons now (InputDevices.on_pad;
## false for a computer side).
func on_pad(side: int) -> bool:
	var p: int = _player_of_side[side]
	return p >= 0 and input != null and input.on_pad(p)


## Whether Training refills health (always true outside Training).
func refill() -> bool:
	return _upkeep == null or _upkeep.refill


## The training dummy's behaviour (TrainingBrain.BEHAVIOURS), or &"" outside
## Training.
func training_behaviour() -> StringName:
	var b: TrainingBrain = _dummy_brain()
	return b.behaviour if b != null else &""


## Tells the training dummy what to do. When its weapon can't perform the
## behaviour, it swaps to one the roster offers that can (back to the
## select's pick whenever that one can) and loadout_changed fires; a
## behaviour no such weapon can perform (the Slam while the Greatsword is
## hidden) is refused. Nothing happens outside Training.
func set_training_behaviour(behaviour: StringName) -> void:
	var b: TrainingBrain = _dummy_brain()
	if b == null or not TrainingBrain.BEHAVIOURS.has(behaviour):
		return
	var w: WeaponDef = _upkeep.weapon_for(behaviour)
	if not TrainingUpkeep.can_perform(w, behaviour):
		return
	var swapped: bool = w != world.fighters[_upkeep.dummy].weapon
	if swapped:
		_upkeep.swap_dummy_weapon(w)
	b.set_behaviour(behaviour)
	if swapped:
		loadout_changed.emit(_upkeep.dummy)
	training_changed.emit()


func _dummy_brain() -> TrainingBrain:
	if _upkeep == null:
		return null
	return _brains[_upkeep.dummy] as TrainingBrain


## Turns Training's refill off or on (key 0 on the Training panel).
func set_refill(on: bool) -> void:
	if _upkeep != null:
		_upkeep.refill = on
		training_changed.emit()


func results() -> MatchResults:
	return MatchResults.from_match(sim_match, config, config.first_human_side())


# ------------------------------------------------------------------ stepping

func _step_once() -> void:
	var inputs: Array[RawInput] = [_input_for(0), _input_for(1)]
	for i: int in 2:
		_prev_pos[i] = _cur_pos[i]
		_prev_yaw[i] = _cur_yaw[i]
	var frame_before: int = world.frame
	sim_match.step(inputs)
	step_count += 1
	_last_step_moved = world.frame != frame_before
	var events: Array[Dictionary] = world.drain_events()
	_snapshot(_has_round_start(events))
	_dispatch(events)
	_after_step()
	stepped.emit(step_count)


static func _has_round_start(events: Array[Dictionary]) -> bool:
	for e: Dictionary in events:
		if e["t"] == &"roundStart":
			return true
	return false


func _input_for(i: int) -> RawInput:
	var b: RefCounted = _brains[i]
	if b is AIBrain:
		return (b as AIBrain).think()
	if b is TrainingBrain:
		return (b as TrainingBrain).think()
	var p: int = _player_of_side[i]
	if attract or _finished or p < 0 or input == null:
		return RawInput.empty()
	var raw: RawInput = input.sample(p)
	var held: int = raw.buttons
	_suppressed[i] &= held
	raw.buttons = held & ~_suppressed[i]
	_last_buttons[i] = held
	return raw


## Ignores, until they are let go, the rule buttons a human side holds now but
## didn't at its last sample: a menu's A (jump), B (dodge) or Space (dodge)
## that started or resumed the match. A button held through the pause (a
## block) carries on.
func _suppress_new_presses() -> void:
	for i: int in 2:
		var p: int = _player_of_side[i]
		if p < 0 or input == null or attract:
			_suppressed[i] = 0
			continue
		_suppressed[i] = input.sample(p).buttons & ~_last_buttons[i]


func _dispatch(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		sim_event.emit(e)


func _after_step() -> void:
	if _upkeep != null:
		_upkeep.step()
	if sim_match.phase != &"matchEnd":
		return
	if attract:
		if sim_match.phase_frames > ATTRACT_RESTART:
			_restart_pending = true
	elif not _finished and sim_match.phase_frames >= RESULTS_DELAY:
		_finished = true
		match_finished.emit(results())


func _maybe_restart_attract() -> void:
	if _restart_pending and attract and config != null:
		_restart_pending = false
		var next: int = int(seed_source.call()) if seed_source.is_valid() else MatchConfig.next_seed(config.world_seed)
		start(config.with_seed(next), true)


## Takes the fighters' positions and yaws after a step; reset (match start, a
## new round) places them instead of blending from the last ones.
func _snapshot(reset: bool) -> void:
	for i: int in 2:
		var f: Fighter = world.fighters[i]
		var p: Vector3 = Vector3(f.pos.x, f.pos.y, f.pos.z)
		if reset:
			_prev_pos[i] = p
			_prev_yaw[i] = f.yaw
		_cur_pos[i] = p
		_cur_yaw[i] = f.yaw


func _teardown() -> void:
	for i: int in 2:
		var b: RefCounted = _brains[i]
		if b is AIBrain:
			(b as AIBrain).dispose()
		elif b is TrainingBrain:
			(b as TrainingBrain).dispose()
		_brains[i] = null
	_upkeep = null
	if world != null:
		world.dispose()
	_started = false
	_paused = false


# ------------------------------------------------------------------ input

func _setup_input() -> void:
	var services: Node = _services()
	if input == null:
		input = services.get("input") if services != null else InputDevices.new()
	if profiles == null:
		profiles = services.get("profiles") if services != null else ControlProfiles.new()
	_player_of_side = [-1, -1]
	if attract:
		return
	var humans: Array[int] = []
	for i: int in 2:
		if config.sides[i].is_human():
			_player_of_side[i] = humans.size()
			humans.append(i)
	if humans.size() == 2:
		var devices: Array[String] = [config.sides[0].device, config.sides[1].device]
		var chosen: Array[ControlProfile] = [_profile_for(config.sides[0]), _profile_for(config.sides[1])]
		input.set_versus(devices, chosen)
	elif humans.size() == 1:
		input.set_single_player(_profile_for(config.sides[humans[0]]))
	else:
		# Watch: nobody plays, but Esc and the pause binding still pause.
		input.set_single_player(profiles.active_profile())
	input.rearm_pause()


func _profile_for(side: MatchSide) -> ControlProfile:
	if side.profile >= 0:
		return profiles.profile_at(side.profile)
	return profiles.active_profile()


func _services() -> Node:
	if not use_services:
		return null
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameServices")
