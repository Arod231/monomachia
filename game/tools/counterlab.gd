extends SceneTree
## Port of scripts/counterlab.ts.
##
## Targeted experiment: a dummy repeating one unblockable vs an AI that always
## tries the counter, a minute per case (Counterlab, counterlab_run.gd, holds
## the cases and the run). Exits 1 when a case never lands its counter.
##
## usage: node scripts/godot.mjs script res://tools/counterlab.gd   (or: npm run counterlab)
##
## Port notes: the output matched the TypeScript counterlab
## (v0.1-web-mvp:scripts/counterlab.ts) line for line up to commit 4222167 (plan task 8.2, which records that baseline);
## since then it reports on the Godot rules alone. Since milestone-1 task 83
## its cases are the Katana's thrust and sweep through Training's routes (the
## Greatsword's slam returns in milestone 2). The tally is printed like
## console.log, see JsFormat. If a script error aborts the run, _process()
## still quits, with exit code 1.

## Loaded when the run starts, not named: a script run with -s that names
## Counterlab compiles the moves while the frame-data table is still loading.
const LAB: String = "res://tools/counterlab_run.gd"

## Stays 1 unless _run() runs to its end with every counter landed.
var _exit_code: int = 1


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true


func _run() -> void:
	var lab: GDScript = load(LAB)
	var missed: Array[String] = []
	for c: Array in lab.CASES:
		var kind: StringName = c[0]
		var tally: Dictionary[String, int] = lab.run(kind, c[1], 60 * 60)
		print("%s %s" % [kind, JsFormat.inspect(tally)])
		if tally.get("counter:" + String(c[2]), 0) == 0:
			missed.append("%s never countered by %s" % [kind, c[2]])
	for m: String in missed:
		printerr("counterlab: " + m)
	_exit_code = 0 if missed.is_empty() else 1
