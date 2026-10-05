class_name InputLog
extends RefCounted
## A match recorded as its inputs (milestone-1 task 6): the config it was
## built from, each rules step's RawInput per side, Training's panel actions
## at their step, the rules' hash every CHECKPOINT_EVERY steps, and at the end
## the step count, the winner and the hash. The match host records every
## match into one and replays one (MatchHost.start_replay(), `--replay=<log>`)
## for the performance replay, the balance run's reproductions and bug
## reports; a replay that drifts names the first checkpoint it missed.
##
## Saved as JSON (FORMAT): the config, the actions, the checkpoints and the
## end are readable; the inputs are the doubles' bytes in base64, because
## Godot's text-to-float parsing isn't exact (about one in six of the
## computer's stick values came back from JSON numbers a unit in the last
## place off, enough to drift a replay). Every match played is saved to DIR,
## which keeps the newest KEEP.

const FORMAT: int = 1
const CHECKPOINT_EVERY: int = 60
const DIR: String = "user://replays"
const KEEP: int = 10
const FLAG: String = "--replay="
## Numbers per step: mx, my and buttons for each side.
const PER_STEP: int = 6

var config: MatchConfig
## PER_STEP numbers per rules step.
var inputs: PackedFloat64Array = PackedFloat64Array()
## Training's panel actions, in order: {"step": n, "behaviour": id} or
## {"step": n, "refill": on}, taken after n steps.
var actions: Array[Dictionary] = []
## The step count -> the rules' hash after it.
var checkpoints: Dictionary[int, String] = {}
## Filled when the recording ends: its step count, the match's winner (-1
## for none yet) and the rules' hash then.
var end_steps: int = -1
var end_winner: int = -1
var end_hash: String = ""


static func make(cfg: MatchConfig) -> InputLog:
	var out_log: InputLog = InputLog.new()
	out_log.config = cfg.copy()
	return out_log


## The number of steps recorded.
func step_count() -> int:
	return inputs.size() / PER_STEP


## Appends one step's inputs, side 0 first.
func record(step_inputs: Array[RawInput]) -> void:
	for r: RawInput in step_inputs:
		inputs.append(r.mx)
		inputs.append(r.my)
		inputs.append(float(r.buttons))


## Side `side`'s input at step `index` (0 is the first step).
func input(index: int, side: int) -> RawInput:
	var at: int = index * PER_STEP + side * 3
	return RawInput.make(inputs[at], inputs[at + 1], int(inputs[at + 2]))


## The panel actions taken after `steps` steps.
func actions_at(steps: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in actions:
		if int(a["step"]) == steps:
			out.append(a)
	return out


func to_dict() -> Dictionary:
	var cps: Dictionary = {}
	for s: int in checkpoints:
		cps[str(s)] = checkpoints[s]
	return {
		"format": FORMAT,
		"game": str(ProjectSettings.get_setting("application/config/version", "")),
		"config": config.to_dict(),
		"steps": step_count(),
		"inputs": Marshalls.raw_to_base64(inputs.to_byte_array()),
		"actions": actions.duplicate(true),
		"checkpoints": cps,
		"end": {"steps": end_steps, "winner": end_winner, "hash": end_hash},
	}


## A out_log from to_dict()'s form, or null (and an error) when it isn't one.
static func from_dict(d: Dictionary) -> InputLog:
	if int(d.get("format", -1)) != FORMAT:
		push_error("InputLog: format %s, not %d" % [d.get("format"), FORMAT])
		return null
	var cfg_in: Variant = d.get("config")
	if not cfg_in is Dictionary:
		push_error("InputLog: no config")
		return null
	var out_log: InputLog = InputLog.new()
	out_log.config = MatchConfig.from_dict(cfg_in)
	out_log.inputs = Marshalls.base64_to_raw(str(d.get("inputs", ""))).to_float64_array()
	if out_log.step_count() != int(d.get("steps", -1)) or out_log.inputs.size() % PER_STEP != 0:
		push_error("InputLog: the inputs don't hold the %s steps it names" % d.get("steps"))
		return null
	for a: Variant in d.get("actions", []):
		if a is Dictionary:
			var act: Dictionary = (a as Dictionary).duplicate()
			act["step"] = int(act.get("step", 0))
			out_log.actions.append(act)
	var cps: Variant = d.get("checkpoints", {})
	if cps is Dictionary:
		for k: Variant in cps:
			out_log.checkpoints[int(k)] = str(cps[k])
	var end: Variant = d.get("end", {})
	if end is Dictionary:
		out_log.end_steps = int(end.get("steps", -1))
		out_log.end_winner = int(end.get("winner", -1))
		out_log.end_hash = str(end.get("hash", ""))
	return out_log


func save(path: String) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "", false, true))
	f.close()
	return OK


## Reads a saved out_log, or null (and an error) when it can't.
static func load_file(path: String) -> InputLog:
	if not FileAccess.file_exists(path):
		push_error("InputLog: no file %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("InputLog: %s isn't a out_log" % path)
		return null
	return from_dict(data)


## Saves the out_log into `dir` under a dated name and deletes the oldest past
## `keep`. Returns the path, or "" when it couldn't be written.
func save_recent(dir: String = DIR, keep: int = KEEP) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# dated to the millisecond, so the names sort oldest first
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "-")
	var ms: int = int(Time.get_unix_time_from_system() * 1000.0) % 1000
	var base: String = "%s/replay-%s-%03d-%s" % [dir, stamp, ms, config.mode]
	var path: String = base + ".json"
	var n: int = 2
	while FileAccess.file_exists(path):
		path = "%s-%d.json" % [base, n]
		n += 1
	if save(path) != OK:
		push_error("InputLog: cannot write %s" % path)
		return ""
	var names: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.begins_with("replay-") and f.ends_with(".json"):
			names.append(f)
	names.sort()
	while names.size() > keep:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/" + names.pop_front()))
	return path


## The out_log a command line names with --replay=<path>, or "".
static func requested(args: PackedStringArray) -> String:
	for a: String in args:
		if a.begins_with(FLAG):
			return a.trim_prefix(FLAG)
	return ""
