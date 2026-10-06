class_name Counterlab
extends RefCounted
## Counterlab's experiment (counterlab.gd prints it; a GUT test runs it
## short): a Training dummy repeating one unblockable through its route
## (UnblockableRoutes) against a hard brain that always tries the counter and
## does nothing else. Health, posture and knockdowns reset every step.
##
## Milestone 1 proves the stomp and the leap reachable against the Katana's
## Piercing Thrust and Swallow Sweep (milestone-1 task 83); the evade's case,
## against the Greatsword's slam, returns with the Greatsword in milestone 2.

## [drill, the dummy's weapon, the counter that beats it]
const CASES: Array = [
	[&"thrust", &"katana", &"stomp"],
	[&"sweep", &"katana", &"leap"],
]


## Runs one case for `frames` steps and returns its tally: "attempts" (the
## dummy's telegraphs), "counter:<kind>" for each counter landed (by either
## side), "hit" (the dummy's hits) and "whiff" (its whiffs).
static func run(drill: StringName, weapon: StringName, frames: int) -> Dictionary[String, int]:
	var W: World = World.new(FighterConfig.make(Moves.WEAPONS[weapon]), FighterConfig.make(Moves.KATANA), 5)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
	dummy.set_behaviour(drill)
	var ai: AIBrain = AIBrain.new(W.fighters[1], counter_params(), 3)
	var tally: Dictionary[String, int] = {}
	for _i: int in frames:
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
	dummy.dispose()
	ai.dispose()
	W.dispose()
	return tally


## The countering brain: { ...DIFFICULTY.hard, counter: 1, parry: 0, dodge: 0,
## block: 0, aggression: 0, guard: 0 }.
static func counter_params() -> AIBrain.AIParams:
	var params: AIBrain.AIParams = AIBrain.DIFFICULTY[&"hard"].copy()
	params.counter = 1.0
	params.parry = 0.0
	params.dodge = 0.0
	params.block = 0.0
	params.aggression = 0.0
	params.guard = 0.0
	return params


static func _add(tally: Dictionary[String, int], k: String) -> void:
	tally[k] = tally.get(k, 0) + 1
