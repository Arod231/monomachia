extends SceneTree
## Records the worst-case replay's log (milestone-1 task 28): searches seeds
## for a match whose first 90 s show everything WorstCase.REQUIRED names, and
## writes it to WorstCase.PATH, the log every performance bench plays. Run it
## again whenever a rules change makes the committed log drift (the tests say
## so):
##   npm run bench:record [-- --from=<seed>] [--tries=<n>]
## --from is the first seed tried (1 by default), --tries how many (200).
## Exits 1, writing nothing, when no seed shows everything.

var _exit_code: int = 1


func _initialize() -> void:
	var first: int = 1
	var tries: int = 200
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			first = a.trim_prefix("--from=").to_int()
		elif a.begins_with("--tries="):
			tries = a.trim_prefix("--tries=").to_int()
	var started: int = Time.get_ticks_msec()
	var found: Dictionary = WorstCase.search(first, tries, func(s: String) -> void: print(s))
	if found.is_empty():
		push_error("record_worst_case.gd: no seed from %d to %d shows everything" % [first, first + tries - 1])
		return
	var log_out: InputLog = found["log"]
	var path: String = ProjectSettings.globalize_path(WorstCase.PATH)
	if log_out.save(path) != OK:
		push_error("record_worst_case.gd: cannot write %s" % path)
		return
	print("record_worst_case.gd: seed %d written to %s (%d steps, %.1f s) in %.1f s" % [
		found["seed"], WorstCase.PATH, log_out.step_count(), log_out.step_count() * SimConst.DT,
		(Time.get_ticks_msec() - started) / 1000.0])
	_exit_code = 0


func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true
