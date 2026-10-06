extends GutTest
## The finisher's rules (milestone-1 task 103, spec "The finisher", P35 and
## P52, stories 25, 114, 116, 117, 118, 125): a disarm of a fighter at 5% HP
## or less opens one prompt of 18 rules frames, played at 0.3x; only a fresh
## heavy press inside it starts the paired finisher, which ends the round as a
## K.O. at its kill.
##
## The owner's answers (Oct 5): until tasks 104 and 105 add the clips, both
## finishers are one stand-in: a line-up over 6 frames to 1.2 m apart, face to
## face, 80 frames long, the kill at frame 56. A fresh press of light, block,
## dodge, jump or ultimate forfeits the prompt (walking doesn't); a fresh heavy
## press starts the finisher from whatever state the disarmer is in.

const H := preload("res://tests/sim/sim_helpers.gd")

const PROMPT: int = 18
const SLOW: float = 0.3
const LINE_UP: int = 6
const GAP: float = 1.2
const LENGTH: int = 80
const KILL: int = 56


func after_each() -> void:
	H.dispose_all()


## A world with fighter 0 (the victim, at `hp`) and fighter 1 (the disarmer)
## 2 m apart, both free.
func _world(hp: float = 5.0) -> World:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	W.fighters[0].hp = hp
	return W


## Steps W once with fighter 1's input `p1` (idle when null), collecting the
## events into r.
func _step(W: World, r: H.Rec, p1: RawInput = null) -> void:
	W.step([H.idle(), p1 if p1 != null else H.idle()])
	r.collect(W)


## Steps W until a world frame passes (the disarm's hit-stop holds the frame),
## fighter 1 idle; returns the world frame.
func _step_frame(W: World, r: H.Rec, p1: RawInput = null) -> int:
	var f: int = W.frame
	while W.frame == f:
		_step(W, r, p1)
		p1 = null
	return W.frame


## Disarms fighter 0 by fighter 1 (parried), with the disarm's hit-stop as a
## real one would have; returns the record from the disarm on.
func _disarm(W: World, reason: StringName = &"parried", victim: int = 0) -> H.Rec:
	var r: H.Rec = H.Rec.new()
	W.fighters[victim].disarm(W.fighters[1 - victim], reason)
	W.hitstop = 14
	r.collect(W)
	return r


## Presses heavy for fighter 1 on the next step, then lets go.
func _press_heavy(W: World, r: H.Rec) -> void:
	_step(W, r, H.btn(Btn.HEAVY))
	_step(W, r)


func test_a_disarm_at_5_hp_opens_the_prompt_for_the_disarmer() -> void:
	var W: World = _world(5.0)
	var r: H.Rec = _disarm(W)
	var opened: Array[Dictionary] = r.all(&"finisherPrompt")
	assert_eq(opened.size(), 1, "one prompt")
	assert_eq([opened[0]["f"], opened[0]["victim"], opened[0]["kind"]], [1, 0, &"katana"], "for the armed disarmer: the Katana's")


func test_a_disarm_above_5_hp_opens_none() -> void:
	var W: World = _world(5.5)
	var r: H.Rec = _disarm(W)
	for _i: int in 60:
		_step(W, r)
	assert_eq(r.count(&"finisherPrompt"), 0)


func test_the_prompt_lasts_18_rules_frames_in_slow_motion_then_the_disarm_plays_out() -> void:
	var W: World = _world()
	var r: H.Rec = _disarm(W)
	var opened_at: int = W.frame
	var scales: Array[float] = []
	var closed_at: int = -1
	while closed_at < 0 and W.frame < opened_at + 40:
		# the host paces each rules frame by the time scale before it
		var scale: float = W.time_scale()
		var f: int = _step_frame(W, r)
		if r.has(&"finisherPromptEnd"):
			closed_at = f
		else:
			scales.append(scale)
	assert_eq(closed_at - opened_at, PROMPT + 1, "open for 18 rules frames, closing on the next")
	assert_eq(r.find(&"finisherPromptEnd")["why"], &"timeout")
	assert_eq(scales.size(), PROMPT, "every frame of it")
	for s: float in scales:
		assert_eq(s, SLOW, "at 0.3x")
	assert_eq(r.count(&"finisher"), 0, "no finisher")
	assert_eq(W.fighters[0].state, &"disarmStagger", "the disarm plays out")
	assert_gt(W.fighters[0].hp, 0.0)


func test_a_fresh_heavy_press_inside_the_prompt_starts_the_finisher() -> void:
	var W: World = _world()
	var r: H.Rec = _disarm(W)
	_step_frame(W, r)
	_press_heavy(W, r)
	var started: Dictionary = r.find(&"finisher")
	assert_false(started.is_empty(), "the finisher starts")
	assert_eq([started["f"], started["victim"], started["kind"], started["from_strike"]], [1, 0, &"katana", false])
	assert_eq(r.find(&"finisherPromptEnd")["why"], &"finisher", "and the prompt closes")
	assert_eq([W.fighters[1].state, W.fighters[0].state], [&"finisher", &"finished"], "a paired state for both")
	assert_null(W.fighters[1].atk, "no heavy attack")


func test_a_press_made_before_the_prompt_does_not_count_held_or_buffered() -> void:
	# held from before the disarm, through the window
	var held: World = _world()
	held.step([H.idle(), H.btn(Btn.HEAVY)])
	var r: H.Rec = _disarm(held)
	for _i: int in 40:
		_step(held, r, H.btn(Btn.HEAVY))
	assert_eq(r.count(&"finisher"), 0, "a held press")
	# pressed two steps before the disarm, still in the input buffer
	var buffered: World = _world()
	buffered.fighters[1].set_state(&"blockstun", 30)
	buffered.step([H.idle(), H.btn(Btn.HEAVY)])
	buffered.step([H.idle(), H.idle()])
	assert_true(buffered.fighters[1].input.buffered(Btn.HEAVY), "the press waits in the buffer")
	var r2: H.Rec = _disarm(buffered)
	for _i: int in 40:
		_step(buffered, r2)
	assert_eq(r2.count(&"finisher"), 0, "a buffered press")


func test_a_press_after_the_prompt_closes_is_an_ordinary_heavy() -> void:
	var W: World = _world()
	var r: H.Rec = _disarm(W)
	for _i: int in 60:
		if r.has(&"finisherPromptEnd"):
			break
		_step(W, r)
	assert_true(r.has(&"finisherPromptEnd"), "the prompt closed")
	_press_heavy(W, r)
	assert_eq(r.count(&"finisher"), 0)


func test_another_press_forfeits_the_prompt_but_walking_does_not() -> void:
	for b: int in [Btn.LIGHT, Btn.BLOCK, Btn.DODGE, Btn.JUMP, Btn.ULTIMATE]:
		var W: World = _world()
		var r: H.Rec = _disarm(W)
		_step_frame(W, r)
		_step(W, r, H.btn(b))
		_step(W, r)
		assert_eq(r.find(&"finisherPromptEnd").get("why"), &"forfeit", "button %d forfeits" % b)
		_press_heavy(W, r)
		assert_eq(r.count(&"finisher"), 0, "button %d: no finisher after" % b)
	var walked: World = _world()
	var rw: H.Rec = _disarm(walked)
	for _i: int in 20:
		_step(walked, rw, H.move(1.0, 0.0))
	_press_heavy(walked, rw)
	assert_eq(rw.count(&"finisher"), 1, "walking keeps it open")


func test_the_heavy_press_starts_it_from_whatever_state_the_disarmer_is_in() -> void:
	for st: StringName in [&"parryAnim", &"recoil", &"hitstun"]:
		var W: World = _world()
		W.fighters[1].set_state(st, 60)
		var r: H.Rec = _disarm(W)
		_step_frame(W, r)
		_press_heavy(W, r)
		assert_eq(r.count(&"finisher"), 1, "from %s" % st)


func test_the_line_up_brings_them_face_to_face_1_2_m_apart_over_6_frames() -> void:
	var W: World = _world()
	W.fighters[1].pos = V3.make(0.5, 0.0, 3.0)
	var r: H.Rec = _disarm(W)
	_step_frame(W, r)
	_step(W, r, H.btn(Btn.HEAVY))
	var a: Fighter = W.fighters[1]
	var v: Fighter = W.fighters[0]
	var at: V3 = V3.make(v.pos.x, v.pos.y, v.pos.z)
	for _i: int in LINE_UP:
		_step_frame(W, r)
	assert_almost_eq(SimMath.dist2(a.pos, v.pos), GAP, 1e-9, "1.2 m apart")
	assert_eq([v.pos.x, v.pos.z], [at.x, at.z], "the victim stays where it was")
	assert_almost_eq(SimMath.angle_between(a.yaw, SimMath.yaw_to(a.pos, v.pos)), 0.0, 1e-9, "the finisher faces the victim")
	assert_almost_eq(SimMath.angle_between(v.yaw, SimMath.yaw_to(v.pos, a.pos)), 0.0, 1e-9, "and the victim the finisher")


func test_the_victim_can_t_act_or_be_hit_and_the_round_ends_as_a_ko_at_the_kill() -> void:
	var W: World = _world()
	var M: Match = Match.new(W) # starting the round refills HP
	M.phase = &"fight"
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	W.fighters[0].hp = 5.0
	var r: H.Rec = _disarm(W)
	_step_frame(W, r)
	W.step([H.idle(), H.btn(Btn.HEAVY)])
	r.collect(W)
	var start: int = W.frame
	var killed_at: int = -1
	while killed_at < 0 and W.frame < start + LENGTH:
		M.step([H.btn(Btn.DODGE) if W.frame % 2 == 0 else H.btn(Btn.BLOCK), H.idle()])
		r.collect(W)
		if r.has(&"finisherKill"):
			killed_at = W.frame
		elif W.fighters[0].state != &"finished":
			break
	assert_eq(killed_at - start, KILL, "the kill on its frame")
	assert_eq(r.count(&"dodge"), 0, "the victim's presses ignored")
	var ko: Dictionary = r.find(&"ko")
	assert_eq([ko.get("loser"), ko.get("winner"), ko.get("finisher")], [0, 1, true], "a K.O. by finisher")
	assert_eq(M.phase, &"roundEnd", "the round ends")
	assert_eq(W.fighters[0].state, &"ko")


func test_the_finisher_plays_to_its_end_then_frees_the_finisher() -> void:
	var W: World = _world()
	var r: H.Rec = _disarm(W)
	_step_frame(W, r)
	W.step([H.idle(), H.btn(Btn.HEAVY)])
	var start: int = W.frame
	while W.fighters[1].state == &"finisher" and W.frame < start + LENGTH + 10:
		_step_frame(W, r)
	assert_eq(W.frame - start, LENGTH, "80 frames")
	assert_eq(W.fighters[1].state, &"free")


func test_a_redirect_by_a_disarmed_fighter_opens_bare_hands_finisher() -> void:
	var W: World = _world()
	W.fighters[1].armed = false
	var r: H.Rec = _disarm(W, &"redirect")
	_step_frame(W, r)
	_press_heavy(W, r)
	assert_eq([r.find(&"finisherPrompt")["kind"], r.find(&"finisher")["kind"], r.find(&"finisher")["from_strike"]], [&"fists", &"fists", false])


func test_a_disarmed_fighter_s_blocked_power_blow_opens_bare_hands_finisher_from_its_strike() -> void:
	var W: World = _world()
	W.fighters[1].armed = false
	var r: H.Rec = _disarm(W, &"blocked")
	_step_frame(W, r)
	_step(W, r, H.btn(Btn.HEAVY))
	var started: Dictionary = r.find(&"finisher")
	assert_eq([started["kind"], started["from_strike"]], [&"fists", true])
	var start: int = W.frame
	while not r.has(&"finisherKill") and W.frame < start + LENGTH:
		_step_frame(W, r)
	assert_lt(W.frame - start, KILL, "from its strike: the kill comes sooner")


func test_a_real_parry_of_a_full_posture_attacker_at_5_hp_opens_the_prompt() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	var a: Fighter = W.fighters[0]
	a.posture = SimConst.POSTURE_MAX
	a.hp = 5.0
	var r: H.Rec = H.Rec.new()
	H.run(W, 30, H.tap_at(0, Btn.LIGHT), H.tap_at(8, Btn.BLOCK), r)
	assert_false(a.armed, "parried into a disarm")
	assert_eq(r.count(&"finisherPrompt"), 1, "the prompt opens for the parrier")


## The replay test and the save-and-restore test through a finisher (story
## 25): a scripted finisher run twice hashes alike on every step, and a world
## saved mid-prompt and mid-finisher steps on from its restore as the original.
func test_a_finisher_replays_and_restores_to_the_same_hash() -> void:
	var runs: Array = []
	for k: int in 2:
		var W: World = _world()
		var r: H.Rec = _disarm(W)
		var hashes: Array[String] = []
		var saves: Dictionary = {}
		for i: int in 140:
			if i == 16 or i == 50:
				saves[i] = W.snapshot()
			W.step([H.idle(), H.btn(Btn.HEAVY) if i == 20 else H.idle()])
			W.drain_events()
			hashes.append(W.state_hash())
		runs.append([hashes, saves])
	assert_eq(runs[0][0], runs[1][0], "the same hash on every step")
	for at: int in [16, 50]:
		var W2: World = _world(80.0)
		W2.restore(runs[0][1][at])
		var first_diff: int = -1
		for i: int in range(at, 140):
			W2.step([H.idle(), H.btn(Btn.HEAVY) if i == 20 else H.idle()])
			W2.drain_events()
			if first_diff < 0 and W2.state_hash() != runs[0][0][i]:
				first_diff = i
		assert_eq(first_diff, -1, "restored at step %d, no step differs" % at)
