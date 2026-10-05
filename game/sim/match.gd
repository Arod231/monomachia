class_name Match
extends RefCounted
## Port of v0.1-web-mvp:src/sim/match.ts.
##
## Round and match flow: intro -> fight -> KO -> next round, first to 3 wins.
##
## Port notes: MatchPhase is a StringName equal to the TS literal; the getter
## fighting is fighting(). The KO scan in step() re-reads the event count on
## every pass, like the TS for loop.

## MatchPhase
const PHASES: Array[StringName] = [&"roundIntro", &"fight", &"roundEnd", &"matchEnd"]

const INTRO_FRAMES: int = 100 # "Round N" then "Fight!"
const FIGHT_CALL_FRAME: int = 62
const ROUND_END_FRAMES: int = 170

## [int, int]
var wins: Array[int] = [0, 0]
var round: int = 1
var phase: StringName = &"roundIntro"
var phase_frames: int = 0
var round_winner: int = -1
var match_winner: int = -1
## Training mode: rounds never end, health refills.
var endless: bool = false
var _neutral: Array[RawInput] = [RawInput.empty(), RawInput.empty()]
var world: World


func _init(p_world: World) -> void:
	world = p_world
	start_round()


func start_round() -> void:
	world.reset_round()
	phase = &"roundIntro"
	phase_frames = 0
	round_winner = -1
	world.emit({"t": &"roundStart", "round": round})


func fighting() -> bool:
	return phase == &"fight"


## inputs: [RawInput, RawInput]
func step(inputs: Array[RawInput]) -> void:
	var W: World = world
	phase_frames += 1
	match phase:
		&"roundIntro":
			# keep reading inputs so nothing is "stuck" when the fight starts
			W.step(_neutral)
			if phase_frames == FIGHT_CALL_FRAME:
				W.emit({"t": &"fight", "round": round})
			if phase_frames >= INTRO_FRAMES:
				for f: Fighter in W.fighters:
					f.set_state(&"free")
				phase = &"fight"
				phase_frames = 0
		&"fight":
			var before: int = W.events.size()
			W.step(inputs)
			var i: int = before
			while i < W.events.size():
				var e: Dictionary = W.events[i]
				if e["t"] == &"ko":
					_on_ko(e["winner"])
				i += 1
		&"roundEnd":
			W.step(_neutral)
			if phase_frames == 70 and round_winner >= 0:
				var w: Fighter = W.fighters[round_winner]
				if w.state != &"ko":
					w.set_state(&"victory")
			if phase_frames >= ROUND_END_FRAMES:
				if match_winner >= 0:
					phase = &"matchEnd"
					phase_frames = 0
					W.emit({"t": &"matchOver", "winner": match_winner})
				else:
					round += 1
					start_round()
		&"matchEnd":
			W.step(_neutral)


func _on_ko(winner: int) -> void:
	if endless:
		return
	phase = &"roundEnd"
	phase_frames = 0
	round_winner = winner
	if winner >= 0:
		wins[winner] += 1
	var perfect: bool = winner >= 0 and world.fighters[winner].hp >= SimConst.HP_MAX
	world.emit({"t": &"roundOver", "winner": winner, "wins": [wins[0], wins[1]], "perfect": perfect})
	if winner >= 0 and wins[winner] >= SimConst.ROUNDS_TO_WIN:
		match_winner = winner
