class_name FinisherRules
extends RefCounted
## The finisher's rules (milestone-1 task 103, spec "The finisher"): a disarm
## of a fighter at FINISHER_HP_SHARE of HP or less opens one prompt for the
## disarmer, FINISHER_PROMPT_FRAMES rules frames played at
## FINISHER_PROMPT_SLOWMO. Inside it a fresh heavy press, from whatever state
## the disarmer is in, starts the finisher; a fresh press of light, block,
## dodge, jump or ultimate forfeits it; a press from before the prompt, held or
## waiting in the input buffer, counts for nothing. Otherwise the prompt runs
## out and the disarm plays out.
##
## The finisher is a paired state for both fighters (the finisher's
## &"finisher", the victim's &"finished"): the finisher lines up face to face
## with the victim, the victim's inputs are ignored and neither can be hit,
## and the round ends as a K.O. at the kill. The weapon decides it: the
## disarmer's weapon when armed, bare hands' (&"fists") when the disarmed
## fighter redirected, played from its strike when it disarmed by a blocked
## power blow (P52). Until tasks 104 and 105 read the clips' lengths and
## markers from the table, both are one stand-in (SimConst's FINISHER_*).
##
## The state is the world's (World.prompt_*, World.finisher_*), so the
## snapshot, the hash and the replay cover it. Events: finisherPrompt (f,
## victim, kind), finisherPromptEnd (f, why: &"finisher", &"forfeit",
## &"timeout" or &"lost"), finisher (f, victim, kind, from_strike) and
## finisherKill (f, victim); the K.O. carries finisher: true.

## The presses that forfeit an open prompt.
const FORFEITS: Array[int] = [Btn.LIGHT, Btn.BLOCK, Btn.DODGE, Btn.JUMP, Btn.ULTIMATE]


## Fighter.disarm() calls it once `victim` is disarmed by `by` for `reason`.
static func on_disarm(W: World, victim: Fighter, by: Fighter, reason: StringName) -> void:
	if victim.hp > SimConst.HP_MAX * SimConst.FINISHER_HP_SHARE:
		return
	if W.prompt_by >= 0 or W.finisher_by >= 0 or by.state == &"ko":
		return
	W.prompt_by = by.id
	W.prompt_at = W.frame
	W.prompt_kind = by.weapon.id if by.armed else &"fists"
	W.prompt_from_strike = not by.armed and reason == &"blocked"
	W.request_slowmo(SimConst.FINISHER_PROMPT_FRAMES, SimConst.FINISHER_PROMPT_SLOWMO)
	W.emit({"t": &"finisherPrompt", "f": by.id, "victim": victim.id, "kind": W.prompt_kind})


## Each rules frame, before the fighters act: closes the prompt or starts the
## finisher from it. The prompt's frames are the world's after the one it
## opened on, so a press during the disarm's hit-stop counts.
static func step_prompt(W: World) -> void:
	if W.prompt_by < 0:
		return
	var a: Fighter = W.fighters[W.prompt_by]
	var victim: Fighter = a.opp
	if W.frame > W.prompt_at + SimConst.FINISHER_PROMPT_FRAMES:
		_close(W, &"timeout")
		return
	if a.state == &"ko" or victim.state == &"ko":
		_close(W, &"lost")
		return
	var inp: InputTracker = a.input
	if inp.press_frame[Btn.HEAVY] > W.prompt_at:
		inp.consume(Btn.HEAVY)
		var kind: StringName = W.prompt_kind
		var from_strike: bool = W.prompt_from_strike
		_close(W, &"finisher")
		_start(W, a, victim, kind, from_strike)
		return
	for b: int in FORFEITS:
		if inp.press_frame[b] > W.prompt_at:
			_close(W, &"forfeit")
			return


## Each rules frame, after the fighters move: the line-up, the kill and the
## end. The frame the finisher starts on is its frame 0 (or the strike's).
static func step_finisher(W: World) -> void:
	if W.finisher_by < 0:
		return
	var a: Fighter = W.fighters[W.finisher_by]
	var victim: Fighter = a.opp
	var start: int = SimConst.FINISHER_STRIKE_FRAME if W.finisher_from_strike else 0
	var t: float = minf(1.0, float(W.finisher_frame - start) / float(SimConst.FINISHER_LINE_UP_FRAMES))
	var away: V2 = SimMath.norm2(W.finisher_from_x - victim.pos.x, W.finisher_from_z - victim.pos.z)
	a.pos.x = SimMath.lerp(W.finisher_from_x, victim.pos.x + away.x * SimConst.FINISHER_GAP, t)
	a.pos.z = SimMath.lerp(W.finisher_from_z, victim.pos.z + away.z * SimConst.FINISHER_GAP, t)
	a.vel.x = 0.0
	a.vel.z = 0.0
	a.yaw = SimMath.yaw_to(a.pos, victim.pos)
	if victim.state == &"finished":
		victim.yaw = SimMath.yaw_to(victim.pos, a.pos)
	if W.finisher_frame == SimConst.FINISHER_KILL_FRAME and victim.state != &"ko":
		W.emit({"t": &"finisherKill", "f": a.id, "victim": victim.id})
		victim.to_ko(a)
	if W.finisher_frame >= SimConst.FINISHER_FRAMES:
		W.finisher_by = -1
		if a.state == &"finisher":
			a.to_free()
		return
	W.finisher_frame += 1


static func _close(W: World, why: StringName) -> void:
	W.emit({"t": &"finisherPromptEnd", "f": W.prompt_by, "why": why})
	W.prompt_by = -1
	W.prompt_kind = &""
	W.prompt_from_strike = false


static func _start(W: World, a: Fighter, victim: Fighter, kind: StringName, from_strike: bool) -> void:
	W.finisher_by = a.id
	W.finisher_kind = kind
	W.finisher_from_strike = from_strike
	W.finisher_frame = SimConst.FINISHER_STRIKE_FRAME if from_strike else 0
	W.finisher_from_x = a.pos.x
	W.finisher_from_z = a.pos.z
	a.release_if_impaling()
	# the pair holds still but for the line-up: no knock-back carries on
	a.knock_left = 0
	victim.knock_left = 0
	a.set_state(&"finisher")
	victim.set_state(&"finished", SimConst.FINISHER_KILL_FRAME - W.finisher_frame)
	W.emit({"t": &"finisher", "f": a.id, "victim": victim.id, "kind": kind, "from_strike": from_strike})
