extends SceneTree
## Port of scripts/counterlab.ts.
##
## Targeted experiment: a dummy repeating one unblockable vs an AI that always tries the counter.
##
## usage: node scripts/godot.mjs script res://tools/counterlab.gd
##
## Port notes: the output matched the TypeScript counterlab
## (v0.1-web-mvp:scripts/counterlab.ts) line for line up to commit 4222167 (plan task 8.2, which records that baseline);
## since then it reports on the Godot rules alone. The tally is printed like
## console.log, see JsFormat. If a script error aborts the run, _process()
## still quits, with exit code 1.

## Stays 1 unless _run() runs to its end.
var _exit_code: int = 1


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true


func _run() -> void:
	var cases: Array = [[&"slam", &"greatsword"], [&"thrust", &"katana"], [&"sweep", &"greatsword"]]
	for c: Array in cases:
		var kind: StringName = c[0]
		var weapon: StringName = c[1]
		var W: World = World.new(FighterConfig.make(Moves.WEAPONS[weapon]), FighterConfig.make(Moves.KATANA), 5)
		for f: Fighter in W.fighters:
			f.set_state(&"free")
		var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
		dummy.set_behaviour(kind)
		# { ...DIFFICULTY.hard, counter: 1, parry: 0, dodge: 0, block: 0, aggression: 0, guard: 0 }
		var params: AIBrain.AIParams = AIBrain.DIFFICULTY[&"hard"].copy()
		params.counter = 1.0
		params.parry = 0.0
		params.dodge = 0.0
		params.block = 0.0
		params.aggression = 0.0
		params.guard = 0.0
		var ai: AIBrain = AIBrain.new(W.fighters[1], params, 3)
		var tally: Dictionary[String, int] = {}
		for _i: int in 60 * 60:
			W.step([dummy.think(), ai.think()])
			for e: Dictionary in W.drain_events():
				if e["t"] == &"counter":
					_add(tally, "counter:" + String(e["kind"]))
				if e["t"] == &"hit" and e["attacker"] == 0:
					_add(tally, "hit")
				if e["t"] == &"telegraph" and e["f"] == 0:
					_add(tally, "attempts")
				if e["t"] == &"whiff" and e["f"] == 0:
					_add(tally, "whiff")
			for f: Fighter in W.fighters:
				f.hp = 100.0
				f.posture = 0.0
				if f.state == &"ko":
					f.set_state(&"free")
		print("%s %s" % [kind, JsFormat.inspect(tally)])
		dummy.dispose()
		ai.dispose()
		W.dispose()
	_exit_code = 0


static func _add(tally: Dictionary[String, int], k: String) -> void:
	tally[k] = tally.get(k, 0) + 1
