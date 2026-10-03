class_name SmokeRun
extends RefCounted
## The check exported builds run (`Monomachia.exe --smoke`): a computer-
## vs-computer match (Watch) played through the game's own flow to the
## results, as fast as the rules can step, after which the game quits with
## exit code 0. It quits with 1 if any engine or script error is logged, if
## the results never come, or if it takes longer than max_seconds of wall
## time. It shows the exported pack holds everything a match needs without a
## person playing it, and its report names the control profiles loaded from
## user://controls.cfg, so a second run can show they were kept.
##
## main.gd starts one when the flag is on the command line, ticks it every
## frame, prints report() and quits with exit_code().

## How the run stands after a tick.
enum Status { RUNNING, PASSED, FAILED }

## The command-line flag that asks for a smoke run.
const FLAG: String = "--smoke"


## Counts the errors logged while the run is on (warnings aside) and keeps
## the first one's text. The engine may call it from any thread.
class ErrorCount:
	extends Logger

	var count: int = 0
	var first: String = ""
	var _mutex: Mutex = Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		if count == 0:
			first = "%s:%d: %s" % [file, line, rationale if rationale != "" else code]
		count += 1
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


## Rules steps per rendered frame: a whole match takes a few seconds.
var steps_per_tick: int = 600
## Give up after this many steps: two 12-minute matches' worth.
var max_steps: int = 60 * 60 * 24
## Give up after this much wall time, in case the steps stall.
var max_seconds: float = 120.0
## Steps taken so far.
var steps: int = 0
## The match's results, once they come.
var results: MatchResults
## The errors logged since start().
var errors: ErrorCount = ErrorCount.new()

var _main: Node
var _host: MatchHost
var _status: Status = Status.RUNNING
var _started: bool = false
var _started_msec: int = 0
var _logging: bool = false


## Whether the smoke flag is among the command-line arguments.
static func requested(args: PackedStringArray) -> bool:
	return args.has(FLAG)


## `main` is the game's main scene (scenes/main.gd).
func _init(main: Node) -> void:
	_main = main
	_host = main.get_node("MatchHost")


## Starts counting errors and the Watch match, with the host off the wall
## clock.
func start() -> void:
	OS.add_logger(errors)
	_logging = true
	_started = true
	_started_msec = Time.get_ticks_msec()
	_host.auto_run = false
	_host.match_finished.connect(func(r: MatchResults) -> void: results = r)
	_main.call("start_watch")


## Steps the match on; returns PASSED once the results are in with no error
## logged, FAILED on an error, on running out of steps or time, or if the
## match stops, and RUNNING until then. A pause (the window losing focus) is
## undone, so the run never stalls.
func tick() -> Status:
	if _status != Status.RUNNING:
		return _status
	if _host.is_paused():
		_host.resume()
	if results == null and steps < max_steps:
		steps += _host.step(mini(steps_per_tick, max_steps - steps))
	if errors.count > 0:
		_status = Status.FAILED
	elif results != null:
		_status = Status.PASSED
	elif steps >= max_steps or _out_of_time() or not _host.is_started():
		_status = Status.FAILED
	if _status != Status.RUNNING:
		finish()
	return _status


## Stops counting errors. tick() calls it when the run ends.
func finish() -> void:
	if _logging:
		OS.remove_logger(errors)
		_logging = false


## The process exit code for the outcome.
func exit_code() -> int:
	return 0 if _status == Status.PASSED else 1


## One line on the outcome, the errors and the control profiles.
func report() -> String:
	var outcome: String
	if results != null:
		outcome = "the Watch match reached the results after %d steps (%s)" % [steps, results.title()]
	elif _out_of_time():
		outcome = "out of time after %d steps" % steps
	else:
		outcome = "no results after %d steps" % steps
	if errors.count > 0:
		outcome += "; %d error%s logged, the first %s" % [errors.count, "" if errors.count == 1 else "s", errors.first]
	var profiles: PackedStringArray = GameServices.profiles.names() if GameServices.profiles != null else PackedStringArray()
	var saved: String = "saved" if FileAccess.file_exists(ControlProfiles.PATH) else "defaults, nothing saved"
	return "smoke: %s; control profiles: %s (%s)" % [outcome, ", ".join(profiles), saved]


func _out_of_time() -> bool:
	return _started and Time.get_ticks_msec() - _started_msec >= max_seconds * 1000.0
