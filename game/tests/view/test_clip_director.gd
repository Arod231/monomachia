extends GutTest
## The clip director (ClipDirector, authored-animation task 8): a fighter's
## rules state in, the clips, their times and weights out, with no nodes.
## The Katana's first two lights are given baked swings here (made-up clips
## whose lengths the context names), so these run without the packs.

const LENGTH: float = 1.5

## Each patched move's [swing, real_markers], put back after each test.
var _saved: Dictionary[StringName, Array] = {}


func before_each() -> void:
	FrozenStateClips.install()
	var k: WeaponDef = Moves.KATANA
	for id: StringName in [&"k_l1", &"k_l2"]:
		_saved[id] = [k.moves[id].swing, k.moves[id].real_markers]
		k.moves[id].swing = _baked(k.moves[id], [StringName("Clip_" + String(id))])


func after_each() -> void:
	for id: StringName in _saved:
		Moves.KATANA.moves[id].swing = _saved[id][0]
		Moves.KATANA.moves[id].real_markers = _saved[id][1]
	_saved.clear()
	FrozenStateClips.restore()
	SimHelpers.dispose_all()


## A baked swing for `move` that holds still, baked at ×1.0 from `clips`:
## its markers put the contact start on the move's last startup frame and
## the settle on its last.
static func _baked(move: AttackDef, clips: Array[StringName]) -> Swing:
	var s: Swing = Swing.new(move.total_frames())
	var keys: Array[Swing.KeyPose] = []
	for f: int in move.total_frames() + 1:
		var k: Swing.KeyPose = Swing.KeyPose.new()
		k.frame = f
		k.grip = V3.make(-0.1, 1.1, 0.4)
		k.blade = V3.make(0.0, 0.6, 0.8)
		k.edge = V3.make(1.0, 0.0, 0.0)
		keys.append(k)
	s.add_track(&"right_hand", keys, true)
	s.clips = clips
	s.speed = 1.0
	s.marks = PackedFloat64Array([0.0, move.startup / 2.0, (move.startup + move.active) / 2.0, move.total_frames() / 2.0])
	s.fallback = &"Sword_Attack"
	return s


static func _ctx(fighter_id: StringName = &"hunter", libraries: bool = true) -> ClipDirector.Context:
	var lengths: Dictionary[String, float] = {"ual/Sword_Attack": 1.2}
	for set_name: StringName in ClipLibraries.SETS:
		for id: String in ["Clip_k_l1", "Clip_k_l2", "Chain_A", "Chain_B"]:
			lengths["%s/%s" % [set_name, id]] = LENGTH
	return ClipDirector.Context.make(fighter_id, libraries, lengths)


## Steps the world one frame (no inputs) and the director after it.
static func _next(W: World, prev: ClipDirector.Shot, ctx: ClipDirector.Context, inputs: Array[RawInput] = []) -> ClipDirector.Shot:
	var given: Array[RawInput] = inputs
	if given.is_empty():
		given = [SimHelpers.idle(), SimHelpers.idle()]
	W.step(given)
	return ClipDirector.step(prev, W.fighters[0], ctx)


func test_the_free_idle_is_the_weapon_classs() -> void:
	var cases: Dictionary = {
		Moves.KATANA: ["HumanM/CombatIdle1H01", "ual/Sword_Idle"],
		Moves.GREATSWORD: ["HumanM/CombatIdle2H01", "ual/Sword_Idle"],
		Moves.DAGGERS: ["HumanM/CombatIdle1H01", "ual/Sword_Idle"],
		Moves.FISTS: ["HumanM/CombatIdle01", "ual/Idle"],
	}
	for w: WeaponDef in cases:
		var W: World = SimHelpers.make_world(w, Moves.KATANA)
		var f: Fighter = W.fighters[0]
		assert_eq(ClipDirector.step(null, f, _ctx()).idle, cases[w][0], "%s: its combat idle" % w.id)
		assert_eq(ClipDirector.step(null, f, _ctx(&"rogue")).idle, "HumanF" + String(cases[w][0]).substr(6), "%s: the Rogue's own set" % w.id)
		assert_eq(ClipDirector.step(null, f, _ctx(&"hunter", false)).idle, cases[w][1], "%s: the CC0 fallback without the packs" % w.id)
		assert_eq(ClipDirector.step(null, f, _ctx()).drive, ClipDirector.LEGS, "the legs drive the free state")
	var W2: World = SimHelpers.make_world(Moves.GREATSWORD, Moves.KATANA)
	W2.fighters[0].armed = false
	assert_eq(ClipDirector.step(null, W2.fighters[0], _ctx()).idle, "HumanM/CombatIdle01", "disarmed: bare hands' idle")


func test_an_attacks_clip_time_follows_its_attack_frame() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	shot = _next(W, shot, ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()] as Array[RawInput])
	assert_eq(f.state, &"attack")
	var cut: AttackDef = f.atk.def
	var t: ClipTiming = ClipDirector.timing_of(cut.swing)
	assert_eq([t.startup, t.active, t.total()], [cut.startup, cut.active, cut.total_frames()], "the timing the bake used")
	while f.state == &"attack":
		assert_eq(shot.drive, ClipDirector.ATTACK)
		assert_eq(shot.clip.name, "HumanM/Clip_k_l1")
		assert_almost_eq(shot.clip.time, t.clip_time(float(f.atk.frame)), 1e-9, "frame %d" % f.atk.frame)
		if f.atk.frame == cut.startup:
			assert_almost_eq(shot.clip.time, t.marks[1] / 30.0, 1e-9, "the contact start on the last startup frame")
		shot = _next(W, shot, ctx)
	assert_eq(shot.drive, ClipDirector.LEGS, "back to the legs after")


func test_hit_stop_and_pause_hold_the_shot() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var shot: ClipDirector.Shot = _next(W, ClipDirector.step(null, f, ctx), ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()] as Array[RawInput])
	shot = _next(W, shot, ctx)
	var held: float = shot.clip.time
	# paused: the world isn't stepped, the frame stands
	assert_same(ClipDirector.step(shot, f, ctx), shot, "a frame seen again gives the same shot")
	# hit-stop: the world steps, its frame stands
	W.hitstop = 3
	for i: int in 3:
		var again: ClipDirector.Shot = _next(W, shot, ctx)
		assert_same(again, shot, "hit-stop holds it")
	assert_eq(shot.clip.time, held)
	shot = _next(W, shot, ctx)
	assert_gt(shot.clip.time, held, "and it goes on after")


func test_a_charge_holds_the_clip() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var shot: ClipDirector.Shot = _next(W, ClipDirector.step(null, f, ctx), ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()] as Array[RawInput])
	for i: int in 3:
		shot = _next(W, shot, ctx)
	# a charge holds the attack's frame, as the rules do
	f.atk.charging = true
	var frame: int = f.atk.frame
	var t: float = ClipDirector.step(shot, f, ctx).clip.time
	for i: int in 4:
		W.frame += 1
		f.atk.frame = frame
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq(shot.clip.time, t, "held at the charge's frame")


# ------------------------------------------------------------------ at its own speed (milestone-1 task 19)

## Right Cut's swing as a re-keyed move's: its markers real (no stand-in), so
## its clip plays from its wind-up start (source frame 4) at 1.0x, whatever
## the swing's speed and other marks say. Undone by the caller.
static func _re_keyed(cut: AttackDef) -> void:
	cut.real_markers = true
	cut.swing.speed = 1.45
	cut.swing.marks = PackedFloat64Array([4.0, 9.0, 10.5, 19.0])


func test_a_move_with_real_markers_plays_its_clip_at_1x_of_the_worlds_time() -> void:
	# far enough apart that nothing lands: the only hit-stop is the test's
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	_re_keyed(cut)
	var shot: ClipDirector.Shot = _next(W, ClipDirector.step(null, f, ctx), ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()] as Array[RawInput])
	var seen: int = 0
	while f.state == &"attack":
		assert_eq([shot.drive, shot.clip.name], [ClipDirector.ATTACK, "HumanM/Clip_k_l1"])
		assert_almost_eq(shot.clip.time, (4.0 + f.atk.frame / 2.0) / 30.0, 1e-9, "frame %d: 1.0x from the wind-up start" % f.atk.frame)
		if f.atk.frame == 6:
			# hit-stop holds every clip alike, and it goes on at 1.0x after
			W.hitstop = 3
			for i: int in 3:
				assert_same(_next(W, shot, ctx), shot, "hit-stop holds it")
			# slow motion steps the world less often: each step is still 1/60 s
			W.request_slowmo(50, 0.3)
		var before: float = shot.clip.time
		shot = _next(W, shot, ctx)
		if f.state == &"attack":
			assert_almost_eq(shot.clip.time - before, 1.0 / 60.0, 1e-9, "a rules frame of clip each step")
		seen += 1
	assert_gt(seen, 20, "through the whole move")


func test_a_stand_in_keeps_its_retime() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	cut.real_markers = false # a stand-in, as Right Cut was until task 31
	cut.swing.speed = 1.45
	cut.swing.marks = PackedFloat64Array([4.0, 9.0, 10.5, 19.0])
	_poke(W, f, &"attack", &"k_l1", 6)
	var t: ClipTiming = ClipDirector.timing_of(cut.swing)
	assert_almost_eq(ClipDirector.step(null, f, ctx).clip.time, t.clip_time(6.0), 1e-9, "on the swing's speed and marks")


func test_a_move_that_outlasts_its_clip_hands_on_and_never_freezes() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	ctx.lengths["HumanM/Clip_k_l1"] = 0.2
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	_re_keyed(cut)
	# 0.2 s is 6 source frames: from source frame 4, 4 rules frames of clip
	for frame: int in [1, 4]:
		_poke(W, f, &"attack", &"k_l1", frame)
		assert_eq(ClipDirector.step(null, f, ctx).drive, ClipDirector.ATTACK, "frame %d: in the clip" % frame)
	_poke(W, f, &"attack", &"k_l1", 5)
	assert_null(ClipDirector.attack_clip(f, ctx, 5.0), "past its end: no clip held")
	assert_eq(ClipDirector.step(null, f, ctx).drive, ClipDirector.LEGS, "handed on to the legs")


func test_a_held_charge_plays_its_loop() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	ctx.lengths["HumanM/Loop_A"] = 0.5
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	_re_keyed(cut)
	cut.swing.loop = &"Loop_A"
	var shot: ClipDirector.Shot = _next(W, ClipDirector.step(null, f, ctx), ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()] as Array[RawInput])
	for i: int in 3:
		shot = _next(W, shot, ctx)
	var frame: int = f.atk.frame
	var wound: float = shot.clip.time
	f.atk.charging = true
	for held: int in range(1, 50):
		W.frame += 1
		f.atk.frame = frame
		f.atk.charge_frames = held
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq([shot.clip.name, shot.phase], ["HumanM/Loop_A", &"hold"], "held: the loop")
		assert_almost_eq(shot.clip.time, fmod(held / 60.0, 0.5), 1e-9, "looped at 1.0 (held %d)" % held)
		if held == 1:
			assert_eq(shot.fade, StateClips.shared().fades[&"follow_up"], "faded into from the wound-up pose")
			assert_almost_eq(shot.from.time, wound, 1e-9)
	# let go: the attack's clip again, from its frame
	f.atk.charging = false
	W.frame += 1
	f.atk.frame = frame + 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.clip.name, shot.phase], ["HumanM/Clip_k_l1", &"swing"], "released")
	assert_eq(shot.fade, StateClips.shared().fades[&"follow_up"], "faded out of the loop")
	assert_almost_eq(shot.clip.time, (4.0 + (frame + 1) / 2.0) / 30.0, 1e-9)
	cut.swing.loop = &""


func test_a_state_clip_at_its_own_speed_loops_or_hands_on() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	var sc: StateClips = StateClips.shared()
	sc.own_speed = {&"CombatDamage01": &"hand_on", &"Stun01": &"loop"}
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	# CombatDamage01 is 30 source frames: 60 rules frames at 1.0. A 14-frame
	# hitstun plays it at 1.0, not sped up to fit; a 90-frame (heavy) one
	# outlasts it and hands on
	f.enter_hitstun(14)
	f.sf = 10
	assert_almost_eq(ClipDirector.reaction_clip(f, ctx, &"hitstun", 0).time, 10.0 / 60.0, 1e-9, "1.0, not fitted to the hitstun")
	sc.hit_clips[1] = &"CombatDamage01"
	f.enter_hitstun(90)
	for sf: int in [30, 59]:
		f.sf = sf
		assert_almost_eq(ClipDirector.reaction_clip(f, ctx, &"hitstun", 0).time, sf / 60.0, 1e-9, "frame %d at 1.0" % sf)
	f.sf = 61
	assert_null(ClipDirector.reaction_clip(f, ctx, &"hitstun", 0), "past its end it hands on, never held")
	# a looping clip loops
	f.enter_stun(200, &"stagger")
	f.sf = 170
	assert_almost_eq(ClipDirector.reaction_clip(f, ctx, &"stun", 0).time, fmod(170.0 / 60.0, 80.0 / 30.0), 1e-9, "looped")
	# a clip not on the list is fitted as before
	f.set_state(&"blockstun", 16)
	f.sf = 8
	assert_almost_eq(ClipDirector.reaction_clip(f, ctx, &"blockstun", 0).time,
		ClipDirector.fitted_time(8, 16, ctx.lengths["HumanM/Parry1H01_R_Hit"]), 1e-9, "fitted")


func test_today_no_katana_or_bare_hands_move_has_real_markers_but_the_counter_lunges() -> void:
	# the families' re-keys take them to 1.0x one by one (task 31's Right Cut first)
	for w: WeaponDef in [Moves.KATANA, Moves.FISTS]:
		for id: StringName in w.moves:
			var def: AttackDef = w.moves[id]
			if def.special == &"counterLunge":
				assert_true(def.real_markers, "%s: its own clip's markers (P48)" % id)
			elif FrameDataTable.shared().row(w.id, id).has("stand_in"):
				assert_false(def.real_markers, "%s: a stand-in until its family re-keys it" % id)


# ------------------------------------------------------------------ transitions (milestone-1 task 33)

## The frozen table with the string's first bridge (Right Cut into Return
## Cut, 8 source frames) and Right Cut's return to guard (12), and a context
## whose tree has them; Return Cut re-keyed (real markers), as the string's
## lights are. Undone by after_each.
func _transitions() -> ClipDirector.Context:
	var t: StateClips = StateClips.read(FrozenStateClips.PATH)
	t.bridges[&"k_l2"] = {&"k_l1": &"Bridge_k_l1_k_l2"}
	t.returns[&"k_l1"] = &"Return_k_l1"
	StateClips.use(t)
	Moves.KATANA.moves[&"k_l2"].real_markers = true
	var ctx: ClipDirector.Context = _ctx()
	for set_name: StringName in ClipLibraries.SETS:
		ctx.lengths["%s/Bridge_k_l1_k_l2" % set_name] = 8.0 / 30.0
		ctx.lengths["%s/Return_k_l1" % set_name] = 12.0 / 30.0
		ctx.lengths["%s/Parry1H01_R_Loop" % set_name] = 1.0
	return ctx


## A follow-up started from the move its bridge is keyed from plays the
## bridge at 1.0x over its first frames, then its own clip exactly where it
## would have been without one, before its active frames and with no blend
## (the bridge ends in that pose); the rules' frames are untouched.
func test_a_chained_follow_up_plays_its_bridge_then_its_own_clip() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _transitions()
	var follow: AttackDef = Moves.KATANA.moves[&"k_l2"]
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	_poke(W, f, &"attack", &"k_l1", 20)
	shot = ClipDirector.step(shot, f, ctx)
	for frame: int in 30:
		_poke(W, f, &"attack", &"k_l2", frame, &"k_l1")
		shot = ClipDirector.step(shot, f, ctx)
		if frame < 16:
			assert_eq(shot.clip.name, "HumanM/Bridge_k_l1_k_l2", "frame %d: the bridge" % frame)
			assert_almost_eq(shot.clip.time, frame / 60.0, 1e-9, "frame %d: at 1.0x from its start" % frame)
		else:
			assert_eq(shot.clip.name, "HumanM/Clip_k_l2", "frame %d: the follow-up's own clip" % frame)
			assert_almost_eq(shot.clip.time, follow.swing.marks[0] / 30.0 + frame / 60.0, 1e-9, "frame %d: where it would be without the bridge" % frame)
		assert_eq(shot.drive, ClipDirector.ATTACK)
		if frame == 16:
			assert_eq(shot.blend, 0, "handed on with no blend")
	assert_lt(16, follow.startup, "handed on before the active frames")


## No bridge for an opener, for a follow-up from a move it has none from, or
## without the packs (the fallback plays as before).
func test_only_a_follow_up_from_its_move_plays_a_bridge() -> void:
	var ctx: ClipDirector.Context = _transitions()
	for from: StringName in [&"", &"k_h2"]:
		var W: World = SimHelpers.make_world()
		var f: Fighter = W.fighters[0]
		_poke(W, f, &"attack", &"k_l2", 3, from)
		assert_eq(ClipDirector.step(null, f, ctx).clip.name, "HumanM/Clip_k_l2", "from %s: its own clip" % [from if from != &"" else &"the guard"])
	var W2: World = SimHelpers.make_world()
	_poke(W2, W2.fighters[0], &"attack", &"k_l2", 3, &"k_l1")
	assert_eq(ClipDirector.step(null, W2.fighters[0], _ctx(&"hunter", false)).clip.name, "ual/Sword_Attack", "without the packs: the fallback")


## A light played out with no follow-up hands on to its return to guard,
## whole body at 1.0x from its start, while the fighter stands in the free
## state; then the legs' idle.
func test_a_light_with_no_follow_up_returns_to_guard() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _transitions()
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	_poke(W, f, &"attack", &"k_l1", cut.total_frames() - 1)
	shot = ClipDirector.step(shot, f, ctx)
	for i: int in 24:
		_poke(W, f, &"free")
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq([shot.drive, shot.phase, shot.move], [ClipDirector.STATE, &"return", &"k_l1"], "step %d: returning" % i)
		assert_eq(shot.clip.name, "HumanM/Return_k_l1")
		assert_almost_eq(shot.clip.time, i / 60.0, 1e-9, "step %d: at 1.0x" % i)
		assert_false(shot.upper, "the whole body")
	_poke(W, f, &"free")
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.drive, ClipDirector.LEGS, "then the legs' idle")


## Moving or raising the guard hands the return on at once (to the legs or
## the guard), and it doesn't come back; a light cut short or played
## without the packs returns through the legs as before.
func test_moving_or_guarding_ends_the_return() -> void:
	var ctx: ClipDirector.Context = _transitions()
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	for how: String in ["move", "guard"]:
		var W: World = SimHelpers.make_world()
		var f: Fighter = W.fighters[0]
		var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
		_poke(W, f, &"attack", &"k_l1", cut.total_frames() - 1)
		shot = ClipDirector.step(shot, f, ctx)
		_poke(W, f, &"free")
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq(shot.phase, &"return", "%s: returning" % how)
		if how == "move":
			f.vel = V3.make(1.2, 0.0, 0.0)
		else:
			f.blocking = true
		_poke(W, f, &"free")
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq(shot.phase, &"" if how == "move" else &"guard", "%s: handed on" % how)
		f.vel = V3.make()
		f.blocking = false
		_poke(W, f, &"free")
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq(shot.drive, ClipDirector.LEGS, "%s: and it doesn't come back" % how)
	var W2: World = SimHelpers.make_world()
	var f2: Fighter = W2.fighters[0]
	var plain: ClipDirector.Context = _ctx(&"hunter", false)
	var s2: ClipDirector.Shot = ClipDirector.step(null, f2, plain)
	_poke(W2, f2, &"attack", &"k_l1", cut.total_frames() - 1)
	s2 = ClipDirector.step(s2, f2, plain)
	_poke(W2, f2, &"free")
	assert_eq(ClipDirector.step(s2, f2, plain).drive, ClipDirector.LEGS, "without the packs: the legs")
	var W3: World = SimHelpers.make_world()
	var f3: Fighter = W3.fighters[0]
	var s3: ClipDirector.Shot = ClipDirector.step(null, f3, ctx)
	_poke(W3, f3, &"attack", &"k_l1", 6)
	s3 = ClipDirector.step(s3, f3, ctx)
	_poke(W3, f3, &"free")
	assert_eq(ClipDirector.step(s3, f3, ctx).drive, ClipDirector.LEGS, "cut short in its startup: the legs")


## Pokes fighter `f` into a state for the director's next step.
static func _poke(W: World, f: Fighter, state: StringName, move: StringName = &"", frame: int = 0, from: StringName = &"") -> void:
	W.frame += 1
	f.state = state
	if move == &"":
		f.atk = null
		return
	if f.atk == null or f.atk.def.id != move:
		f.atk = AttackState.new()
		f.atk.def = Moves.KATANA.moves[move]
		f.atk.chained_from = Moves.KATANA.moves[from] if from != &"" else null
	f.atk.frame = frame


## Every hand-off asks for an inertial blend (milestone-1 task 23) of its
## length, on its first frame only, and shows the new motion whole at once:
## no crossfade. The lengths are today's crossfades' (the owner's choice,
## Oct 5), the hitstun cut a 4-frame blend.
func test_each_hand_off_requests_its_inertial_blend() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	assert_eq(shot.blend, 0, "nothing to blend from at first")
	# into an attack: 3 frames from the legs
	_poke(W, f, &"attack", &"k_l1", 1)
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.fade, shot.blend], [3, 3], "into an attack")
	assert_null(shot.from, "from the legs' blend")
	assert_eq(shot.authored(), 1.0, "the attack whole on its first frame")
	_poke(W, f, &"attack", &"k_l1", 2)
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.blend, 0, "asked on the hand-off's frame alone")
	assert_eq(shot.authored(), 1.0)
	# a follow-up: 4 frames, from the last clip's pose
	var last_time: float = shot.clip.time
	_poke(W, f, &"attack", &"k_l2", 1, &"k_l1")
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.fade, shot.blend], [4, 4], "a follow-up")
	assert_eq(shot.from.name, "HumanM/Clip_k_l1", "handed off from the last clip")
	assert_eq(shot.from.time, last_time, "held at its last pose")
	assert_eq(shot.clip.name, "HumanM/Clip_k_l2")
	assert_eq(shot.clip_share(), 1.0, "the follow-up's clip whole at once")
	# back to the legs: 6 frames
	_poke(W, f, &"free")
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.drive, shot.fade, shot.blend], [ClipDirector.LEGS, 6, 6], "back to the legs")
	assert_eq(shot.authored(), 0.0, "the legs alone at once")
	# a dodge-cancel: 2
	_poke(W, f, &"attack", &"k_l1", 1)
	shot = ClipDirector.step(shot, f, ctx)
	_poke(W, f, &"attack", &"k_l1", 15)
	shot = ClipDirector.step(shot, f, ctx)
	_poke(W, f, &"dodge")
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.fade, shot.blend], [2, 2], "a dodge-cancel")
	# hitstun: today's cut, now a 4-frame blend
	_poke(W, f, &"attack", &"k_l1", 1)
	shot = ClipDirector.step(shot, f, ctx)
	_poke(W, f, &"attack", &"k_l1", 6)
	shot = ClipDirector.step(shot, f, ctx)
	_poke(W, f, &"hitstun")
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.fade, shot.blend], [0, 4], "hitstun blends over 4")
	assert_eq(StateClips.shared().blends[&"stance"], 8, "a stance change blends 8")
	assert_eq(StateClips.shared().blends, {&"attack": 3, &"follow_up": 4, &"dodge_cancel": 2, &"hitstun": 4,
		&"locomotion": 6, &"stance": 8, &"state": 2, &"guard": 3, &"rebound": 4}, "today's crossfades, hitstun's 4")


func test_a_move_without_a_baked_swing_keeps_the_stand_in() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var move: AttackDef = Moves.KATANA.moves[&"k_l3"]
	var own: Swing = move.swing
	move.swing = null
	_poke(W, f, &"attack", &"k_l3", 1)
	assert_eq(ClipDirector.step(null, f, ctx).drive, ClipDirector.LEGS, "no swing: nothing authored")
	move.swing = _baked(move, [])
	assert_eq(ClipDirector.step(null, f, ctx).drive, ClipDirector.LEGS, "a swing not baked from a clip: nothing authored")
	move.swing = own


func test_without_the_packs_the_fallback_plays() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx(&"hunter", false)
	_poke(W, f, &"attack", &"k_l1", 0)
	var cut: AttackDef = f.atk.def
	for frame: int in [0, 10, cut.total_frames()]:
		f.atk.frame = frame
		var clip: ClipDirector.Clip = ClipDirector.attack_clip(f, ctx, float(frame))
		assert_eq(clip.name, "ual/Sword_Attack", "the swing's fallback")
		assert_almost_eq(clip.time, 1.2 * frame / cut.total_frames(), 1e-9, "stretched over the move")
	cut.swing.fallback = &""
	assert_null(ClipDirector.attack_clip(f, ctx, 5.0), "no fallback: the stand-in")


func test_the_rogue_plays_the_hunters_set_for_a_flagged_move() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	_poke(W, f, &"attack", &"k_l1", 4)
	assert_eq(ClipDirector.attack_clip(f, _ctx(&"rogue"), 4.0).name, "HumanF/Clip_k_l1", "her own set")
	f.atk.def.swing.rogue_humanm = true
	assert_eq(ClipDirector.attack_clip(f, _ctx(&"rogue"), 4.0).name, "HumanM/Clip_k_l1", "flagged: the Hunter's")
	assert_eq(ClipDirector.attack_clip(f, _ctx(&"hunter"), 4.0).name, "HumanM/Clip_k_l1")


func test_a_chain_plays_its_clips_in_turn() -> void:
	var ctx: ClipDirector.Context = _ctx()
	var chain: Array[StringName] = [&"Chain_A", &"Chain_B"]
	var a: ClipDirector.Clip = ClipDirector.chain_clip(chain, &"HumanM", 0.5, ctx)
	assert_eq([a.name, a.time], ["HumanM/Chain_A", 0.5])
	var b: ClipDirector.Clip = ClipDirector.chain_clip(chain, &"HumanM", LENGTH + 0.25, ctx)
	assert_eq(b.name, "HumanM/Chain_B")
	assert_almost_eq(b.time, 0.25, 1e-9)


## Moonsplitter (task 13): wound up and held through the rules' 36-frame
## wind-up, released from the hold as the wave goes out, by its variant.
func test_moonsplitter_holds_its_wind_up_and_cuts_with_the_wave() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var lengths: Dictionary[String, float] = {"HumanM/Attack2H01": 1.6, "HumanM/Attack2H03": 1.53, "ual/Sword_Heavy_Combo": 2.0}
	var ctx: ClipDirector.Context = ClipDirector.Context.make(&"hunter", true, lengths)
	f.state = &"ult"
	f.ult = UltState.make(&"moonsplitter", &"windup", 0, &"vertical", 0, false)
	f.ult.pf = 10
	var c: ClipDirector.Clip = ClipDirector.ult_clip(f, ctx)
	assert_eq(c.name, "HumanM/Attack2H01", "the vertical wave's clip")
	assert_almost_eq(c.time * 30.0, 5.0, 1e-6, "raised at 1.0")
	f.ult.pf = 30
	assert_almost_eq(ClipDirector.ult_clip(f, ctx).time * 30.0, 12.0, 1e-6, "held at the top")
	f.ult.phase = &"release"
	f.ult.pf = 3
	assert_almost_eq(ClipDirector.ult_clip(f, ctx).time * 30.0, 15.0, 1e-6, "cutting at 2.0 as the wave goes out")
	f.ult.variant = &"horizontal"
	assert_eq(ClipDirector.ult_clip(f, ctx).name, "HumanM/Attack2H03", "the horizontal wave's clip")
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	assert_eq([shot.drive, shot.move], [ClipDirector.ATTACK, &"moonsplitter"], "it drives")
	var bare: ClipDirector.Context = ClipDirector.Context.make(&"hunter", false, lengths)
	f.ult.phase = &"windup"
	f.ult.pf = 18
	c = ClipDirector.ult_clip(f, bare)
	assert_eq(c.name, "ual/Sword_Heavy_Combo", "without the packs, the fallback")
	assert_almost_eq(c.time, 2.0 * 18.0 / 70.0, 1e-6, "stretched over the wind-up and release")


func test_impaler_draws_back_thrusts_on_the_dash_and_holds_the_victim() -> void:
	var W: World = SimHelpers.make_world(Moves.GREATSWORD, Moves.KATANA)
	var f: Fighter = W.fighters[0]
	var lengths: Dictionary[String, float] = {"HumanM/AttackPolearm01": 41.0 / 30.0, "ual/Sword_Dash": 1.4}
	var ctx: ClipDirector.Context = ClipDirector.Context.make(&"hunter", true, lengths)
	f.state = &"ult"
	f.ult = UltState.make(&"impaler", &"aim", 0, &"vertical", 0, false)
	var at: Callable = func(phase: StringName, pf: int) -> float:
		f.ult.phase = phase
		f.ult.pf = pf
		var c: ClipDirector.Clip = ClipDirector.ult_clip(f, ctx)
		assert_eq(c.name, "HumanM/AttackPolearm01")
		return c.time * 30.0
	assert_almost_eq(at.call(&"aim", 8), 4.0, 1e-6, "drawing back at 1.0")
	assert_almost_eq(at.call(&"aim", 29), StateClips.shared().impaler_drawn, 1e-6, "held drawn back through the aim")
	assert_almost_eq(at.call(&"dash", 4), StateClips.shared().impaler_drawn + 3.0, 1e-6, "thrusting out as the dash starts")
	assert_almost_eq(at.call(&"dash", 30), StateClips.shared().impaler_out, 1e-6, "held out through the dash")
	assert_almost_eq(at.call(&"impale", 20), StateClips.shared().impaler_out, 1e-6, "and the impale")
	assert_almost_eq(at.call(&"recover", 30), 41.0, 1e-4, "recovering to the clip's end")
	# a phase change fades as a follow-up
	f.ult.phase = &"aim"
	f.ult.pf = 29
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	W.frame += 1
	f.ult.phase = &"dash"
	f.ult.pf = 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.drive, shot.move, shot.fade], [ClipDirector.ATTACK, &"impaler", StateClips.shared().fades[&"follow_up"]], "a phase change fades")
	var bare: ClipDirector.Context = ClipDirector.Context.make(&"hunter", false, lengths)
	f.ult.phase = &"dash"
	f.ult.pf = 5
	assert_almost_eq(ClipDirector.ult_clip(f, bare).time, 1.4 * 35.0 / 70.0, 1e-6, "without the packs the dash stretched over the aim and dash")



func test_tempest_spins_cutting_on_each_hit_and_ends_on_the_outward_slash() -> void:
	var W: World = SimHelpers.make_world(Moves.DAGGERS, Moves.KATANA)
	var f: Fighter = W.fighters[0]
	var lengths: Dictionary[String, float] = {"ual/Sword_Aerial_Combo": 1.0, "ual/Sword_Heavy_Combo": 1.9, "HumanM/AttackDW02": 37.0 / 30.0}
	var ctx: ClipDirector.Context = ClipDirector.Context.make(&"hunter", true, lengths)
	f.state = &"ult"
	f.ult = UltState.make(&"tempest", &"flash", 0, &"vertical", 0, false)
	var at: Callable = func(phase: StringName, pf: int, spins: int = 0, c: ClipDirector.Context = ctx) -> Array:
		f.ult.phase = phase
		f.ult.pf = pf
		f.ult.spins = spins
		var clip: ClipDirector.Clip = ClipDirector.ult_clip(f, c)
		return [clip.name, snappedf(clip.time * 30.0, 1e-4)]
	assert_eq(at.call(&"flash", 8), ["ual/Sword_Aerial_Combo", 2.0], "the flash eases into the first slash")
	# the spin's hit lands on its fifth frame (Fighter._ult_tempest()): each
	# slash cuts there (the combo's cuts at source frames 7 and 22), in turn
	assert_eq(at.call(&"spin", 5, 0), ["ual/Sword_Aerial_Combo", 7.0], "the first spin cuts on its hit")
	assert_eq(at.call(&"spin", 5, 1), ["ual/Sword_Aerial_Combo", 22.0], "the second the other slash")
	assert_eq(at.call(&"spin", 5, 4), ["ual/Sword_Aerial_Combo", 7.0], "and in turn")
	assert_eq(at.call(&"final", 8), ["HumanM/AttackDW02", 18.0], "the final's outward slash cuts on its hit")
	assert_eq(at.call(&"recover", 24), ["HumanM/AttackDW02", 37.0], "recovering to the clip's end")
	var bare: ClipDirector.Context = ClipDirector.Context.make(&"hunter", false, lengths)
	assert_eq(at.call(&"spin", 5, 1, bare)[0], "ual/Sword_Aerial_Combo", "the spins are CC0: they play without the packs")
	assert_eq(at.call(&"final", 8, 0, bare)[0], "ual/Sword_Heavy_Combo", "the final's fallback")
	# each spin fades in as a follow-up
	f.ult.phase = &"spin"
	f.ult.pf = 9
	f.ult.spins = 2
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	W.frame += 1
	f.ult.pf = 0
	f.ult.spins = 3
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.move, shot.fade, shot.since], [&"tempest", StateClips.shared().fades[&"follow_up"], 0], "the next spin fades in")

# ------------------------------------------------------------------ the shoulder carry (task 18)

## A context for a Greatsword fighter: Heavy Swing's clip and the carry's
## pose, with their lengths.
static func _gs_ctx(libraries: bool = true) -> ClipDirector.Context:
	var lengths: Dictionary[String, float] = {"ual/Sword_Heavy_A": 1.2, "ual/Sword_Idle": 2.0}
	for set_name: StringName in ClipLibraries.SETS:
		lengths["%s/Attack2H01" % set_name] = 1.6
		lengths["%s/%s" % [set_name, StateClips.shared().carry_pose]] = 0.33
	return ClipDirector.Context.make(&"hunter", libraries, lengths)


## A Greatsword fighter 8 m from a Katana, walked onto the shoulder: the
## world, the shot after it and the frames walked.
func _walk_onto_the_shoulder(ctx: ClipDirector.Context) -> Array:
	var W: World = SimHelpers.make_world(Moves.GREATSWORD, Moves.KATANA, 8.0)
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	var walked: int = 0
	while not f.shouldered and walked < 60:
		shot = _next(W, shot, ctx, [SimHelpers.move(0.0, 1.0), SimHelpers.idle()])
		walked += 1
	return [W, shot]


func test_the_carry_shows_on_the_upper_body_while_shouldered() -> void:
	var ctx: ClipDirector.Context = _gs_ctx()
	var got: Array = _walk_onto_the_shoulder(ctx)
	var W: World = got[0]
	var shot: ClipDirector.Shot = got[1]
	assert_true(W.fighters[0].shouldered, "walked onto the shoulder")
	assert_eq(shot.drive, ClipDirector.CARRY, "the carry drives")
	assert_eq(shot.clip.name, "HumanM/" + StateClips.shared().carry_pose)
	assert_eq(shot.fade, StateClips.shared().fades[&"stance"], "faded in as a stance")
	assert_eq(shot.legs_free(), 1.0, "the legs are the legs' blend's")
	for i: int in StateClips.shared().fades[&"stance"]:
		shot = _next(W, shot, ctx, [SimHelpers.move(0.0, 1.0), SimHelpers.idle()])
	assert_eq(shot.authored(), 1.0, "all of it on the upper body")
	assert_eq(shot.legs_free(), 1.0, "and the legs still walk")
	# standing still keeps it
	for i: int in 10:
		shot = _next(W, shot, ctx)
	assert_eq(shot.drive, ClipDirector.CARRY, "standing still keeps it")


func test_without_the_packs_nothing_shows_the_carry() -> void:
	var ctx: ClipDirector.Context = _gs_ctx(false)
	var got: Array = _walk_onto_the_shoulder(ctx)
	assert_true((got[0] as World).fighters[0].shouldered)
	assert_eq((got[1] as ClipDirector.Shot).drive, ClipDirector.LEGS, "no CC0 carry: the legs")


func test_an_attack_from_the_shoulder_fades_in_over_the_lift() -> void:
	var ctx: ClipDirector.Context = _gs_ctx()
	var got: Array = _walk_onto_the_shoulder(ctx)
	var W: World = got[0]
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = got[1]
	for i: int in 10:
		shot = _next(W, shot, ctx)
	shot = _next(W, shot, ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	assert_eq([f.state, f.atk.def.id, f.atk.lift], [&"attack", &"g_l1", SimConst.GS_SHOULDER_LIFT_FRAMES], "Heavy Swing from the shoulder")
	assert_eq(shot.drive, ClipDirector.ATTACK)
	assert_eq(shot.fade, SimConst.GS_SHOULDER_LIFT_FRAMES, "the lift is the crossfade")
	assert_eq(shot.from.name, "HumanM/" + StateClips.shared().carry_pose, "from the shoulder")
	assert_true(shot.from_upper)
	assert_eq(shot.blend, SimConst.GS_SHOULDER_LIFT_FRAMES, "blended over the lift")
	var first: float = shot.clip.time
	var legs: Array[float] = [shot.legs_free()]
	for i: int in SimConst.GS_SHOULDER_LIFT_FRAMES:
		shot = _next(W, shot, ctx)
		legs.append(shot.legs_free())
		if f.atk.lift_left > 0:
			assert_eq(shot.clip.time, first, "the attack's first frame held through the lift")
	for share: float in legs:
		assert_eq(share, 0.0, "the legs the attack's at once, the blend smoothing the hand-off: %s" % [legs])
	assert_null(shot.from, "the fade done")


func test_a_guard_raised_from_the_shoulder_fades_out_over_the_lift() -> void:
	var ctx: ClipDirector.Context = _gs_ctx()
	var got: Array = _walk_onto_the_shoulder(ctx)
	var W: World = got[0]
	var shot: ClipDirector.Shot = got[1]
	for i: int in 10:
		shot = _next(W, shot, ctx)
	shot = _next(W, shot, ctx, [SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()])
	assert_false(W.fighters[0].shouldered, "off the shoulder")
	assert_eq([shot.drive, shot.fade, shot.blend], [ClipDirector.LEGS, SimConst.GS_SHOULDER_LIFT_FRAMES, SimConst.GS_SHOULDER_LIFT_FRAMES], "back to the legs, blended over the lift")
	assert_eq(shot.authored(), 0.0, "the legs at once")


func test_the_stomp_plays_its_keyed_clip_fitted_to_the_state() -> void:
	var stomp: String = KeyedClips.anim_name(KeyedClips.STOMP)
	for libraries: bool in [true, false]:
		var ctx: ClipDirector.Context = _ctx(&"hunter", libraries)
		ctx.lengths[stomp] = 26.0 / 60.0
		# the attacker (fighter 0) thrusts its unblockable; the defender dodges into it
		var W: World = SimHelpers.make_world()
		var b: Fighter = W.fighters[1]
		var shot: ClipDirector.Shot = null
		var stomped: int = 0
		var last_time: float = -1.0
		var after: ClipDirector.Shot = null
		for i: int in 80:
			var a_in: RawInput = SimHelpers.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else SimHelpers.idle()
			var b_in: RawInput = SimHelpers.move(0.0, 1.0, Btn.DODGE) if i == 20 else SimHelpers.idle()
			W.step([a_in, b_in])
			var was: StringName = shot.drive if shot != null else &""
			shot = ClipDirector.step(shot, b, ctx)
			if b.state == &"stomp":
				assert_eq(shot.drive, ClipDirector.STATE, "the stomp's own clip drives (packs: %s)" % libraries)
				assert_eq(shot.clip.name, stomp, "the keyed Mikiri_Stomp")
				assert_almost_eq(shot.clip.time, float(b.sf) / float(b.state_dur) * ctx.lengths[stomp], 0.0001, "fitted to the stomp's length")
				assert_gte(shot.clip.time, last_time, "it runs forward")
				if was != ClipDirector.STATE:
					assert_eq(shot.fade, StateClips.shared().fades[&"state"], "it springs out of the dodge over 2 frames")
				last_time = shot.clip.time
				stomped += 1
			elif stomped > 0 and after == null:
				after = shot
		assert_gt(stomped, 0, "the defender stomped the thrust (packs: %s)" % libraries)
		assert_not_null(after, "the stomp ended")
		if after != null:
			assert_eq(after.drive, ClipDirector.LEGS, "the legs take over after it")
			assert_eq(after.fade, StateClips.shared().fades[&"locomotion"], "over the fade back to the legs")
		SimHelpers.dispose_all()


func test_a_state_clip_missing_from_the_tree_leaves_the_legs() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	f.set_state(&"stomp", 26)
	assert_null(ClipDirector.state_clip(f, _ctx()), "no keyed clip in the tree: nothing to play")
	var ctx: ClipDirector.Context = _ctx()
	ctx.lengths[KeyedClips.anim_name(KeyedClips.STOMP)] = 26.0 / 60.0
	assert_not_null(ClipDirector.state_clip(f, ctx))
	f.set_state(&"free", 0)
	assert_null(ClipDirector.state_clip(f, ctx), "the free state has no clip of its own")


# ------------------------------------------------------------------ the Daggers' grip (task 21)

func test_the_daggers_flip_forward_into_an_attack_and_back_after_it() -> void:
	var W: World = SimHelpers.make_world(Moves.DAGGERS, Moves.KATANA, 8.0)
	var f: Fighter = W.fighters[0]
	var lengths: Dictionary[String, float] = {}
	for set_name: StringName in ClipLibraries.SETS:
		for id: String in ["Attack1H01_R", "Attack1H01_L"]:
			lengths["%s/%s" % [set_name, id]] = 33.0 / 30.0
	var ctx: ClipDirector.Context = ClipDirector.Context.make(&"hunter", true, lengths)
	var poke: Callable = func(move: StringName, frame: int, from: StringName = &"") -> void:
		W.frame += 1
		f.state = &"attack"
		if f.atk == null or f.atk.def.id != move:
			f.atk = AttackState.new()
			f.atk.def = Moves.DAGGERS.moves[move]
			f.atk.chained_from = Moves.DAGGERS.moves[from] if from != &"" else null
		f.atk.frame = frame
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	assert_eq(shot.grip, 1.0, "the idle holds the reverse grip")
	var grips: Array[float] = []
	for i: int in 4:
		poke.call(&"d_l1", 1 + i)
		shot = ClipDirector.step(shot, f, ctx)
		grips.append(shot.grip)
	assert_eq(shot.fade, StateClips.shared().fades[&"attack"])
	assert_eq(grips[0], 1.0, "reverse on the attack's first frame")
	assert_true(grips[1] < 1.0 and grips[1] > 0.0, "turning over the crossfade: %s" % [grips])
	assert_eq(grips[3], 0.0, "forward once it is done")
	var total: int = Moves.DAGGERS.moves[&"d_l1"].total_frames()
	poke.call(&"d_l1", total - ClipDirector.GRIP_BACK)
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.grip, 0.0, "forward until the last recovery frames")
	poke.call(&"d_l1", total - 3)
	shot = ClipDirector.step(shot, f, ctx)
	assert_almost_eq(shot.grip, 0.5, 1e-6, "turning back over the last 6")
	f.atk.queued = &"d_l2"
	shot = ClipDirector.step(shot, f, ctx)
	W.frame += 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.grip, 0.0, "not while a follow-up is queued")
	f.atk.queued = &""
	poke.call(&"d_l1", total - 3)
	shot = ClipDirector.step(shot, f, ctx)
	var from: float = shot.grip
	poke.call(&"d_l2", 1, &"d_l1")
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.grip_from, from, "a follow-up turns forward from where the grip stood")
	W.frame += 1
	f.state = &"free"
	f.atk = null
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.grip, 1.0, "back to the legs: the reverse grip")


func test_the_stomped_thruster_plays_its_pin_fitted_to_the_stun() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx()
	var pinned: String = KeyedClips.anim_name(KeyedClips.PINNED)
	ctx.lengths[pinned] = 70.0 / 60.0
	f.enter_stun(ProtectedTimings.for_weapon(&"katana").stomp_stun, &"stunned", &"stomp")
	f.sf = f.state_dur / 2
	var clip: ClipDirector.Clip = ClipDirector.state_clip(f, ctx)
	assert_not_null(clip)
	assert_eq(clip.name, pinned, "the stomp's stun plays Mikiri_Pinned")
	assert_almost_eq(clip.time, 0.5 * ctx.lengths[pinned], 0.0001, "fitted to the stun")
	f.enter_stun(SimConst.LEAP_STUN)
	assert_null(ClipDirector.state_clip(f, ctx), "another stun has no keyed clip (it plays Stun01, a reaction)")


func test_shadow_step_plays_the_roll_and_blinks_through_its_active_frames() -> void:
	var W: World = SimHelpers.make_world(Moves.DAGGERS, Moves.KATANA, 2.0)
	var f: Fighter = W.fighters[0]
	var def: AttackDef = Moves.DAGGERS.moves[&"d_shadow"]
	assert_eq(def.swing.clips, [&"Roll01"] as Array[StringName], "played from Roll01")
	assert_eq(def.swing.speed, 1.0, "at its own speed (milestone-1 task 17; sped up 2x before)")
	var lengths: Dictionary[String, float] = {}
	for set_name: StringName in ClipLibraries.SETS:
		lengths["%s/Roll01" % set_name] = 39.0 / 30.0
	var ctx: ClipDirector.Context = ClipDirector.Context.make(&"hunter", true, lengths)
	var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.btn(Btn.BLOCK, Btn.HEAVY), SimHelpers.idle()])
	var blinked: Array[int] = []
	while f.state == &"attack":
		assert_eq(shot.drive, ClipDirector.ATTACK, "frame %d: the roll drives" % f.atk.frame)
		assert_eq(shot.clip.name, "HumanM/Roll01")
		if ClipDirector.blinks(f):
			blinked.append(f.atk.frame)
		shot = _next(W, shot, ctx)
	assert_eq(blinked.size(), def.active, "hidden through the active frames")
	assert_eq(blinked[0], def.startup + 1, "from the first")
	assert_false(ClipDirector.blinks(f), "shown again after it")


# ------------------------------------------------------------------ reactions (task 26)

## Source frames of the reaction clips (their real lengths), as seconds.
const REACTION_FRAMES: Dictionary[StringName, float] = {
	&"CombatDamage01": 30.0, &"CombatDamage02": 32.0, &"Stun01": 80.0,
	&"Parry1H01_R_Loop": 40.0, &"Parry1H01_R_Hit": 24.0, &"Parry2H01_Loop": 40.0, &"Parry2H01_Hit": 25.0,
	&"ParryDW01_Loop": 40.0, &"ParryDW01_Hit": 23.0,
}


## A context with every reaction clip in both sets and the CC0 fallbacks.
static func _reaction_ctx(libraries: bool = true) -> ClipDirector.Context:
	var ctx: ClipDirector.Context = _ctx(&"hunter", libraries)
	for set_name: StringName in ClipLibraries.SETS:
		for id: StringName in REACTION_FRAMES:
			ctx.lengths["%s/%s" % [set_name, id]] = REACTION_FRAMES[id] / 30.0
	for fallback: StringName in [&"Hit_Chest", &"Hit_Head", &"Sword_Block", &"Hit_Knockback"]:
		ctx.lengths["ual/%s" % fallback] = 1.0
	return ctx


func test_a_reaction_is_timed_to_its_state_at_one_to_two_times() -> void:
	# a 1 s clip (30 source frames, 60 rules frames at 1.0)
	assert_almost_eq(ClipDirector.fitted_time(30, 60, 1.0), 0.5, 1e-9, "a 60-frame state: 1.0, ending with it")
	assert_almost_eq(ClipDirector.fitted_time(20, 40, 1.0), 0.5, 1e-9, "a 40-frame state: 1.5, ending with it")
	assert_almost_eq(ClipDirector.fitted_time(7, 14, 1.0), 7.0 * 2.0 / 60.0, 1e-9, "a 14-frame state: 2.0 at most, handing back before the end")
	assert_almost_eq(ClipDirector.fitted_time(90, 120, 1.0), 1.0, 1e-9, "a long state: 1.0, then its last pose held")


func test_hitstun_plays_the_light_or_heavy_recoil() -> void:
	for libraries: bool in [true, false]:
		var ctx: ClipDirector.Context = _reaction_ctx(libraries)
		var W: World = SimHelpers.make_world()
		var f: Fighter = W.fighters[0]
		var shot: ClipDirector.Shot = _next(W, null, ctx)
		assert_eq(shot.drive, ClipDirector.LEGS)
		# a light's 14 frames, a heavy's 26, an ultimate's 40
		for case: Array in [[14, &"CombatDamage01", &"Hit_Chest"], [26, &"CombatDamage02", &"Hit_Head"], [40, &"CombatDamage02", &"Hit_Head"]]:
			f.enter_hitstun(case[0])
			W.frame += 1
			shot = ClipDirector.step(shot, f, ctx)
			var want: String = ("HumanM/%s" % case[1]) if libraries else ("ual/%s" % case[2])
			assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"hitstun", want], "%d frames (packs: %s)" % [case[0], libraries])
			assert_eq(shot.legs_free(), 0.0, "the whole body")
			f.sf = case[0] / 2
			var clip: ClipDirector.Clip = ClipDirector.reaction_clip(f, ctx, &"hitstun", 0)
			assert_almost_eq(clip.time, ClipDirector.fitted_time(f.sf, case[0], ctx.lengths[want]), 1e-9, "timed to the hitstun")


func test_a_hit_blends_into_its_recoil() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	for i: int in 3:
		shot = _next(W, shot, ctx)
	f.enter_hitstun(14)
	W.frame += 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.drive, shot.fade, shot.blend], [ClipDirector.STATE, 0, 4], "no crossfade, a 4-frame blend")


func test_a_held_block_loops_the_guard_on_the_upper_body() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	shot = _next(W, shot, ctx, [SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()])
	assert_true(f.blocking)
	assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"guard", "HumanM/Parry1H01_R_Loop"], "the Katana's guard")
	assert_eq(shot.fade, StateClips.shared().fades[&"guard"], "raised over 3 frames")
	assert_true(shot.upper)
	assert_eq(shot.legs_free(), 1.0, "the legs walk under it")
	var length: float = ctx.lengths["HumanM/Parry1H01_R_Loop"]
	var held: int = 0
	for i: int in 100:
		shot = _next(W, shot, ctx, [SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()])
		held += 1
		assert_almost_eq(shot.clip.time, fmod(float(held) / 60.0, length), 1e-9, "looped at 1.0 (frame %d)" % held)
	shot = _next(W, shot, ctx)
	assert_false(f.blocking)
	assert_eq([shot.drive, shot.blend], [ClipDirector.LEGS, StateClips.shared().blends[&"locomotion"]], "lowered back to the legs")
	assert_true(shot.from_upper)
	assert_eq(shot.authored(), 0.0, "the legs alone at once")


func test_each_weapon_class_guards_with_its_own_clips() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	var want: Dictionary[StringName, Array] = {
		&"katana": ["Parry1H01_R_Loop", "Parry1H01_R_Hit"], &"greatsword": ["Parry2H01_Loop", "Parry2H01_Hit"],
		&"daggers": ["ParryDW01_Loop", "ParryDW01_Hit"],
	}
	for wid: StringName in want:
		var W: World = SimHelpers.make_world(Moves.WEAPONS[wid])
		var f: Fighter = W.fighters[0]
		f.blocking = true
		assert_eq(ClipDirector.reaction_of(f), &"guard")
		assert_eq(ClipDirector.reaction_clip(f, ctx, &"guard", 0).name, "HumanM/" + want[wid][0], String(wid))
		f.set_state(&"blockstun", 10)
		assert_eq(ClipDirector.reaction_of(f), &"blockstun")
		assert_eq(ClipDirector.reaction_clip(f, ctx, &"blockstun", 0).name, "HumanM/" + want[wid][1], String(wid))
	var rogue: ClipDirector.Context = _reaction_ctx()
	rogue.fighter_id = &"rogue"
	var W2: World = SimHelpers.make_world()
	W2.fighters[0].blocking = true
	assert_eq(ClipDirector.reaction_clip(W2.fighters[0], rogue, &"guard", 0).name, "HumanF/Parry1H01_R_Loop", "the Rogue's own set")


func test_blockstun_plays_the_guards_hit_timed_to_it() -> void:
	for libraries: bool in [true, false]:
		var ctx: ClipDirector.Context = _reaction_ctx(libraries)
		var W: World = SimHelpers.make_world()
		var f: Fighter = W.fighters[0]
		var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()])
		assert_eq(shot.phase, &"guard")
		f.set_state(&"blockstun", 16)
		W.frame += 1
		shot = ClipDirector.step(shot, f, ctx)
		var want: String = "HumanM/Parry1H01_R_Hit" if libraries else "ual/Sword_Block"
		assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"blockstun", want], "packs: %s" % libraries)
		assert_eq(shot.fade, StateClips.shared().fades[&"state"], "from the guard over 2 frames")
		assert_true(shot.upper, "on the upper body")
		f.sf = 8
		assert_almost_eq(ClipDirector.reaction_clip(f, ctx, &"blockstun", 0).time, ClipDirector.fitted_time(8, 16, ctx.lengths[want]), 1e-9)


func test_the_long_stuns_play_stun01_timed_to_them() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var length: float = ctx.lengths["HumanM/Stun01"]
	for case: Array in [[&"stunned", SimConst.LEAP_STUN], [&"stunned", ProtectedTimings.for_weapon(&"katana").redirect_stun], [&"stagger", ProtectedTimings.for_weapon(&"katana").disarmed_daze],
			[&"disarmStagger", ProtectedTimings.for_weapon(&"katana").disarm_stagger], [&"impaled", 60]]:
		f.enter_stun(case[1], case[0])
		f.sf = case[1] / 2
		assert_eq(ClipDirector.reaction_of(f), &"stun", String(case[0]))
		var clip: ClipDirector.Clip = ClipDirector.reaction_clip(f, ctx, &"stun", 0)
		assert_eq(clip.name, "HumanM/Stun01", "%s plays Stun01" % case[0])
		assert_almost_eq(clip.time, ClipDirector.fitted_time(f.sf, case[1], length), 1e-9, "timed to the %d-frame stun" % case[1])
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	assert_eq([shot.drive, shot.upper], [ClipDirector.STATE, false], "the whole body")
	# the stomped thruster keeps its keyed pin
	var pinned: String = KeyedClips.anim_name(KeyedClips.PINNED)
	ctx.lengths[pinned] = 70.0 / 60.0
	f.enter_stun(ProtectedTimings.for_weapon(&"katana").stomp_stun, &"stunned", &"stomp")
	W.frame += 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.clip.name, pinned, "the stomp's stun: Mikiri_Pinned")


func test_a_guard_raised_from_the_shoulder_fades_into_the_guard_over_the_lift() -> void:
	var ctx: ClipDirector.Context = _gs_ctx()
	for set_name: StringName in ClipLibraries.SETS:
		ctx.lengths["%s/Parry2H01_Loop" % set_name] = 40.0 / 30.0
	var got: Array = _walk_onto_the_shoulder(ctx)
	var W: World = got[0]
	var shot: ClipDirector.Shot = got[1]
	for i: int in 10:
		shot = _next(W, shot, ctx)
	shot = _next(W, shot, ctx, [SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()])
	assert_false(W.fighters[0].shouldered, "off the shoulder")
	assert_eq([shot.drive, shot.phase, shot.fade], [ClipDirector.STATE, &"guard", SimConst.GS_SHOULDER_LIFT_FRAMES], "into the guard over the lift")
	assert_eq(shot.from.name, "HumanM/" + StateClips.shared().carry_pose, "from the shoulder")
	assert_eq(shot.legs_free(), 1.0, "the legs the legs' blend's throughout")


# ------------------------------------------------------------------ the parry (task 27)

func test_the_parrier_plays_its_guards_parry_hit() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	for wid: StringName in [&"katana", &"greatsword", &"daggers"]:
		var W: World = SimHelpers.make_world(Moves.WEAPONS[wid])
		var f: Fighter = W.fighters[0]
		f.set_state(&"parryAnim", SimConst.PARRIER_RECOVERY)
		f.sf = 3
		var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
		var want: String = "HumanM/" + String(StateClips.shared().guard_clips[wid][1])
		assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"parry", want], String(wid))
		assert_true(shot.upper, "on the upper body")
		assert_almost_eq(shot.clip.time, ClipDirector.fitted_time(3, SimConst.PARRIER_RECOVERY, ctx.lengths[want]), 1e-9, "timed to the recovery")


## Fighter 0 of a fresh world `frames` frames into Right Cut (its made-up
## baked clip), the director stepped along: [world, shot].
func _attacking(ctx: ClipDirector.Context, frames: int) -> Array:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	for i: int in frames - 1:
		shot = _next(W, shot, ctx)
	assert_eq([f.state, shot.drive], [&"attack", ClipDirector.ATTACK])
	return [W, shot]


func test_a_parried_attack_runs_back_then_staggers() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	var got: Array = _attacking(ctx, 12)
	var W: World = got[0]
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = got[1]
	var met: ClipDirector.Clip = shot.clip
	# a block's parry: the attacker recoils
	f.enter_recoil(SimConst.PARRY_RECOIL, SimConst.PARRY_RECOIL_GUARD_AFTER)
	f.atk = null
	W.frame += 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"rebound", met.name], "its own clip")
	assert_almost_eq(shot.clip.time, met.time, 1e-9, "from where the parry met it")
	assert_eq(shot.upper, false, "the whole body")
	var times: Array[float] = [shot.clip.time]
	while f.sf < StateClips.shared().rebound_frames:
		f.sf += 1
		W.frame += 1
		shot = ClipDirector.step(shot, f, ctx)
		if f.sf < StateClips.shared().rebound_frames:
			assert_eq(shot.phase, &"rebound")
			assert_almost_eq(shot.clip.time, maxf(0.0, met.time - float(f.sf) * StateClips.shared().rebound_speed / 60.0), 1e-9, "backwards at 2.0 (frame %d)" % f.sf)
			times.append(shot.clip.time)
	for i: int in times.size() - 1:
		assert_lte(times[i + 1], times[i], "running backwards, holding at its start: %s" % [times])
	assert_lt(times[-1], times[0], "it runs back")
	# handed over to the stagger
	assert_eq([shot.phase, shot.clip.name, shot.fade], [&"stun", "HumanM/Stun01", StateClips.shared().fades[&"rebound"]], "then Stun01, faded over 4 frames")
	assert_eq(shot.from.name, met.name, "from the rebound's last pose")
	var rest: int = SimConst.PARRY_RECOIL - StateClips.shared().rebound_frames
	f.sf = StateClips.shared().rebound_frames + 6
	W.frame += 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_almost_eq(shot.clip.time, ClipDirector.fitted_time(6, rest, ctx.lengths["HumanM/Stun01"]), 1e-9, "over the rest of the recoil")
	# the guard back up once the recoil allows it
	f.sf = SimConst.PARRY_RECOIL_GUARD_AFTER + 1
	f.blocking = true
	W.frame += 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.phase, &"guard", "blocking again")


func test_a_flash_or_redirect_stun_rebounds_too_but_not_a_stomp() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	for stun: int in [ProtectedTimings.for_weapon(&"katana").flash_stun, ProtectedTimings.for_weapon(&"katana").redirect_stun]:
		var got: Array = _attacking(ctx, 12)
		var W: World = got[0]
		var f: Fighter = W.fighters[0]
		var shot: ClipDirector.Shot = got[1]
		var met: ClipDirector.Clip = shot.clip
		f.enter_stun(stun)
		f.atk = null
		W.frame += 1
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq([shot.phase, shot.clip.name], [&"rebound", met.name], "a %d-frame stun rebounds" % stun)
		f.sf = StateClips.shared().rebound_frames
		W.frame += 1
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq([shot.phase, shot.clip.name], [&"stun", "HumanM/Stun01"])
	var got2: Array = _attacking(ctx, 12)
	var f2: Fighter = (got2[0] as World).fighters[0]
	var pinned: String = KeyedClips.anim_name(KeyedClips.PINNED)
	ctx.lengths[pinned] = 70.0 / 60.0
	f2.enter_stun(ProtectedTimings.for_weapon(&"katana").stomp_stun, &"stunned", &"stomp")
	f2.atk = null
	(got2[0] as World).frame += 1
	var shot2: ClipDirector.Shot = ClipDirector.step(got2[1], f2, ctx)
	assert_eq(shot2.clip.name, pinned, "the stomp's own keyed clip, no rebound")
	assert_null(shot2.rebound)


func test_a_stun_not_from_an_attack_plays_stun01_from_its_start() -> void:
	var ctx: ClipDirector.Context = _reaction_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	f.enter_recoil(SimConst.PARRY_RECOIL, SimConst.PARRY_RECOIL_GUARD_AFTER)
	W.frame += 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq([shot.phase, shot.clip.name], [&"stun", "HumanM/Stun01"], "no attack to run back")
	assert_null(shot.rebound)


# ------------------------------------------------------------------ knockdown and KO (task 28)

## A context with the knockdown's and the deaths' clips and their fallbacks.
static func _down_ctx(libraries: bool = true) -> ClipDirector.Context:
	var ctx: ClipDirector.Context = _ctx(&"hunter", libraries)
	var frames: Dictionary[StringName, float] = {
		&"Knockdown01_Fall": 28.0, &"Knockdown01_Ground": 52.0, &"Knockdown01_StandUp": 35.0,
		&"CombatDeath01": 45.0, &"CombatDeath02": 33.0, &"CombatDeath03": 35.0, &"CombatDeath04": 41.0,
	}
	for set_name: StringName in ClipLibraries.SETS:
		for id: StringName in frames:
			ctx.lengths["%s/%s" % [set_name, id]] = frames[id] / 30.0
	for fallback: StringName in [&"Hit_Knockback", &"LayToIdle", &"Death01"]:
		ctx.lengths["ual/%s" % fallback] = 1.5
	return ctx


func test_a_knockdown_fits_knockdown01_to_its_three_phases() -> void:
	var ctx: ClipDirector.Context = _down_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	f.enter_knockdown()
	var fall: int = f.knockdown_timings().knockdown_fall
	var ground: int = f.knockdown_timings().knockdown_ground
	var up: int = f.knockdown_timings().knockdown_rise
	var shot: ClipDirector.Shot = null
	var fall_len: float = ctx.lengths["HumanM/Knockdown01_Fall"]
	var ground_len: float = ctx.lengths["HumanM/Knockdown01_Ground"]
	var up_len: float = ctx.lengths["HumanM/Knockdown01_StandUp"]
	var from: float = StateClips.shared().knockdown_standup_from / 30.0
	for sf: int in range(1, fall + ground + up + 1):
		f.sf = sf
		W.frame += 1
		shot = ClipDirector.step(shot, f, ctx)
		assert_eq([shot.drive, shot.upper], [ClipDirector.STATE, false], "frame %d: the whole body" % sf)
		match f.knockdown_phase():
			&"fall":
				assert_eq([shot.phase, shot.clip.name], [&"fall", "HumanM/Knockdown01_Fall"])
				assert_almost_eq(shot.clip.time, ClipDirector.fitted_time(sf, fall, fall_len), 1e-9, "frame %d: timed to the fall" % sf)
			&"ground":
				assert_eq([shot.phase, shot.clip.name], [&"ground", "HumanM/Knockdown01_Ground"])
				assert_almost_eq(shot.clip.time, fmod(float(sf - fall) / 60.0, ground_len), 1e-9, "frame %d: lying, looped" % sf)
			&"standUp":
				assert_eq([shot.phase, shot.clip.name], [&"standUp", "HumanM/Knockdown01_StandUp"])
				assert_almost_eq(shot.clip.time, from + ClipDirector.fitted_time(sf - fall - ground, up, up_len - from), 1e-9, "frame %d: up over the stand-up" % sf)
	# the fall lands (the hips down on its source frame 20) as the fall ends,
	# and the stand-up is up (its source frame 31) as it ends
	f.sf = fall
	assert_almost_eq(ClipDirector.down_clip(f, ctx).time * 30.0, 20.0, 1e-6, "landed as the fall ends")
	f.sf = fall + ground + up
	assert_almost_eq(ClipDirector.down_clip(f, ctx).time * 30.0, 31.0, 1e-6, "up as the stand-up ends")


func test_without_the_packs_a_knockdown_plays_the_stand_ins() -> void:
	var ctx: ClipDirector.Context = _down_ctx(false)
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	f.enter_knockdown()
	f.sf = 10
	assert_eq(ClipDirector.down_clip(f, ctx).name, "ual/Hit_Knockback", "falling")
	f.sf = f.knockdown_timings().knockdown_fall + 5
	var lying: ClipDirector.Clip = ClipDirector.down_clip(f, ctx)
	assert_eq([lying.name, lying.time], ["ual/LayToIdle", 0.0], "lying in the rise's first pose")
	f.sf = f.knockdown_timings().knockdown_fall + f.knockdown_timings().knockdown_ground + 5
	assert_eq(ClipDirector.down_clip(f, ctx).name, "ual/LayToIdle", "rising")


func test_the_ko_picks_its_death_by_the_final_blows_side_and_weight() -> void:
	var ctx: ClipDirector.Context = _down_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var want: Dictionary = {
		[false, false]: "CombatDeath01", [false, true]: "CombatDeath02",
		[true, false]: "CombatDeath03", [true, true]: "CombatDeath04",
	}
	for key: Array in want:
		f.to_ko()
		f.ko_from_behind = key[0]
		f.ko_heavy = key[1]
		f.sf = 20
		var clip: ClipDirector.Clip = ClipDirector.down_clip(f, ctx)
		assert_eq(clip.name, "HumanM/" + String(want[key]), "behind %s, heavy %s" % key)
		assert_almost_eq(clip.time, 20.0 / 60.0, 1e-9, "at 1.0 from the blow, slowed with the rules")
	f.sf = 600
	assert_almost_eq(ClipDirector.down_clip(f, ctx).time, ctx.lengths["HumanM/CombatDeath04"], 1e-9, "held lying at its end")
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	assert_eq([shot.drive, shot.phase], [ClipDirector.STATE, &"ko"])
	assert_eq(ClipDirector.down_clip(f, _down_ctx(false)).name, "ual/Death01", "without the packs")


# ------------------------------------------------------------------ the roll and the other states (task 30)

## A context with the movement states' clips (their source lengths) and
## their fallbacks.
static func _move_ctx(libraries: bool = true) -> ClipDirector.Context:
	var ctx: ClipDirector.Context = _ctx(&"hunter", libraries)
	var frames: Dictionary[StringName, float] = {
		&"Roll01": 39.0, &"Dodge01": 32.0, &"Jump01_Begin": 20.0, &"Jump01": 46.0, &"Jump01_Land": 20.0,
		&"Fall01": 30.0, &"Loot01_Begin": 24.0, &"Loot01_Stop": 22.0,
	}
	for set_name: StringName in ClipLibraries.SETS:
		for id: StringName in frames:
			ctx.lengths["%s/%s" % [set_name, id]] = frames[id] / 30.0
	for fallback: StringName in [&"Roll", &"Jump_Start", &"Jump", &"Jump_Land", &"NinjaJump_Start", &"PickUp_Table"]:
		ctx.lengths["ual/%s" % fallback] = 1.2
	return ctx


func test_a_roll_tumbles_over_its_travel_and_gets_up_over_its_recovery() -> void:
	var ctx: ClipDirector.Context = _move_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.move(1.0, 0.0, Btn.DODGE), SimHelpers.idle()])
	assert_eq(f.state, &"dodge", "rolling right")
	var travel: int = f.dodge.frames
	var recovery: int = f.dodge.recovery
	var length: float = ctx.lengths["HumanM/Roll01"] * 30.0
	while f.state == &"dodge":
		assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"dodge", "HumanM/Roll01"], "frame %d" % f.sf)
		var want: float = ClipDirector.ROLL_TRAVEL_END * f.sf / travel if f.sf <= travel \
			else lerpf(ClipDirector.ROLL_TRAVEL_END, length, float(f.sf - travel) / recovery)
		assert_almost_eq(shot.clip.time * 30.0, want, 1e-6, "frame %d: the tumble with the ground, the getting-up over the recovery" % f.sf)
		shot = _next(W, shot, ctx)
	assert_almost_eq(ClipDirector.ROLL_TRAVEL_END * 2.0 / travel, 2.75, 1e-6, "the tumble at 2.75 (past the 1.0-2.0 range)")


func test_a_roll_turns_the_body_toward_the_roll_and_back_over_the_recovery() -> void:
	var ctx: ClipDirector.Context = _move_ctx()
	# far enough apart that the facing barely follows the opponent
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.move(1.0, 0.0, Btn.DODGE), SimHelpers.idle()])
	var travel: int = f.dodge.frames
	var turns: Array[float] = []
	while f.state == &"dodge":
		turns.append(shot.turn)
		var way: float = wrapf(atan2(f.dodge.dir_x, f.dodge.dir_z) - f.yaw, -PI, PI)
		if f.sf >= ClipDirector.ROLL_TURN_FRAMES and f.sf <= travel:
			assert_almost_eq(shot.turn, way, 1e-6, "frame %d: turned toward the roll" % f.sf)
		var before: float = shot.turn
		shot = _next(W, shot, ctx)
		assert_eq(shot.turn_before, before, "the frame before, for showing between frames")
	var full: float = turns[ClipDirector.ROLL_TURN_FRAMES] # (the first shot is the dodge's frame 0)
	assert_almost_eq(rad_to_deg(full), -90.0, 5.0, "a roll to the right turns the body right as it sets off (%.0f°)" % rad_to_deg(full))
	assert_lt(turns[travel - 1], full, "and further as the facing follows the opponent past it")
	assert_eq(shot.turn, 0.0, "facing the opponent again once it is free")
	assert_almost_eq(turns[-1], 0.0, 0.1, "turned back over the recovery, a frame before it is free")
	# a roll straight back turns the body round, away from the opponent
	var W2: World = SimHelpers.make_world()
	var shot2: ClipDirector.Shot = _next(W2, null, ctx, [SimHelpers.move(0.0, -1.0, Btn.DODGE), SimHelpers.idle()])
	for i: int in 6:
		shot2 = _next(W2, shot2, ctx)
	assert_almost_eq(absf(shot2.turn), PI, 0.15, "rolling back: turned round")
	assert_eq(ClipDirector.roll_turn(SimHelpers.make_world().fighters[0]), 0.0, "standing: none")


func test_a_dodge_attack_comes_up_facing_the_opponent_over_its_first_3_frames() -> void:
	var k: WeaponDef = Moves.KATANA
	_saved[&"k_dl"] = [k.moves[&"k_dl"].swing, k.moves[&"k_dl"].real_markers]
	k.moves[&"k_dl"].swing = _baked(k.moves[&"k_dl"], [&"Clip_k_l1"])
	var ctx: ClipDirector.Context = _move_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.move(1.0, 0.0, Btn.DODGE), SimHelpers.idle()])
	var turned: float = 0.0
	while f.state == &"dodge" and f.sf < f.dodge.iframes + 2:
		shot = _next(W, shot, ctx)
		turned = shot.turn
	shot = _next(W, shot, ctx, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	var frames: int = 0
	while f.state != &"attack" and frames < 20:
		shot = _next(W, shot, ctx)
		frames += 1
	assert_eq(f.state, &"attack", "the dodge attack")
	assert_eq(f.atk.def.id, &"k_dl")
	assert_eq(shot.drive, ClipDirector.ATTACK)
	assert_lt(absf(turned), PI, "it rolled turned")
	assert_ne(shot.turn_from, 0.0, "turning back from where the roll stood")
	while f.atk.frame < ClipDirector.TURN_BACK_FRAMES:
		assert_lte(absf(shot.turn), absf(shot.turn_from) + 1e-6)
		shot = _next(W, shot, ctx)
	assert_almost_eq(shot.turn, 0.0, 1e-6, "facing the opponent by its third frame")


func test_the_backstep_leans_back_on_dodge01_without_turning() -> void:
	var ctx: ClipDirector.Context = _move_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.btn(Btn.DODGE), SimHelpers.idle()])
	assert_eq(f.state, &"backstep")
	var travel: int = f.dodge.frames
	while f.state == &"backstep":
		assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"backstep", "HumanM/Dodge01"])
		var want: float = ClipDirector.BACKSTEP_LEAN_END * minf(1.0, float(f.sf) / travel) + maxf(0.0, f.sf - travel) * 2.0 * 30.0 / 60.0
		assert_almost_eq(shot.clip.time * 30.0, want, 1e-6, "frame %d: the lean back over the travel, on at 2.0 after" % f.sf)
		assert_eq(shot.turn, 0.0, "facing the opponent")
		shot = _next(W, shot, ctx)


func test_a_jump_takes_off_flies_and_lands() -> void:
	var ctx: ClipDirector.Context = _move_ctx()
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, [SimHelpers.btn(Btn.JUMP), SimHelpers.idle()])
	assert_eq(f.state, &"jump")
	var phases: Array[StringName] = []
	while f.state == &"jump":
		if phases.is_empty() or phases[-1] != shot.phase:
			phases.append(shot.phase)
		if shot.phase == &"jump_begin":
			assert_eq(shot.clip.name, "HumanM/Jump01_Begin")
			assert_almost_eq(shot.clip.time * 30.0, ClipDirector.JUMP_BEGIN_FROM + f.sf, 1e-6, "from its push-off at 2.0")
		else:
			assert_eq(shot.clip.name, "HumanM/Jump01")
			assert_between(shot.clip.time * 30.0, ClipDirector.JUMP_AIR_FROM, ClipDirector.JUMP_AIR_TO, "in the air")
		shot = _next(W, shot, ctx)
	assert_eq(phases, [&"jump_begin", &"jump_air"] as Array[StringName], "the take-off, then in the air")
	assert_eq(f.state, &"land")
	assert_eq([shot.phase, shot.clip.name], [&"land", "HumanM/Jump01_Land"])
	assert_almost_eq(shot.clip.time * 30.0, ClipDirector.JUMP_LAND_FROM + 2.0 * f.sf * 30.0 / 60.0, 1e-6, "from its touch-down at 2.0")
	assert_eq(shot.fade, StateClips.shared().fades[&"state"], "faded in from the air")
	while f.state == &"land":
		shot = _next(W, shot, ctx)
	assert_eq(shot.drive, ClipDirector.LEGS, "then the legs")


func test_the_leap_springs_then_falls_and_the_pick_up_reaches_then_rises() -> void:
	var ctx: ClipDirector.Context = _move_ctx()
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	var f: Fighter = W.fighters[0]
	f.begin_leap(W.fighters[1])
	for sf: int in [1, 9, 10, 25]:
		f.sf = sf
		var got: Array = ClipDirector.move_clip(f, ctx)
		var want: Array = ["HumanM/Jump01_Begin", &"leap_spring"] if sf < ClipDirector.LEAP_SPRING else ["HumanM/Fall01", &"leap_fall"]
		assert_eq([(got[0] as ClipDirector.Clip).name, got[1]], want, "leap frame %d" % sf)
	f.set_state(&"pickup", SimConst.PICKUP_FRAMES)
	for sf: int in range(1, SimConst.PICKUP_FRAMES + 1):
		f.sf = sf
		var got: Array = ClipDirector.move_clip(f, ctx)
		var clip: ClipDirector.Clip = got[0]
		if sf <= SimConst.PICKUP_ATTACH_FRAME:
			assert_eq([clip.name, got[1]], ["HumanM/Loot01_Begin", &"pickup"], "pick-up frame %d" % sf)
			assert_almost_eq(clip.time * 30.0, ClipDirector.PICKUP_FROM + sf, 1e-6, "reaching down at 2.0")
		else:
			assert_eq([clip.name, got[1]], ["HumanM/Loot01_Stop", &"pickup_rise"], "pick-up frame %d" % sf)
	assert_almost_eq(ClipDirector.PICKUP_FROM + SimConst.PICKUP_ATTACH_FRAME, 18.0, 1e-6, "at the ground (Loot01_Begin's frame 18) as the weapon comes to the hand")


func test_without_the_packs_the_states_play_their_fallbacks() -> void:
	var ctx: ClipDirector.Context = _move_ctx(false)
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var cases: Array = [
		[&"dodge", "ual/Roll"], [&"backstep", "ual/Roll"], [&"land", "ual/Jump_Land"], [&"leap", "ual/NinjaJump_Start"],
		[&"pickup", "ual/PickUp_Table"],
	]
	for c: Array in cases:
		f.set_state(c[0], 20)
		f.dodge = DodgeState.make(1.0, 0.0, 2.8, 16, 12, 9, c[0] == &"backstep", false)
		f.sf = 5
		var got: Array = ClipDirector.move_clip(f, ctx)
		assert_eq((got[0] as ClipDirector.Clip).name, c[1], String(c[0]))
	f.set_state(&"jump")
	f.sf = 2
	assert_eq((ClipDirector.move_clip(f, ctx)[0] as ClipDirector.Clip).name, "ual/Jump_Start")
	f.sf = 12
	assert_eq((ClipDirector.move_clip(f, ctx)[0] as ClipDirector.Clip).name, "ual/Jump")
	f.set_state(&"free")
	assert_eq(ClipDirector.move_clip(f, ctx), [], "the free state is the legs'")


func test_the_recall_plays_the_keyed_power_up_fitted_to_it() -> void:
	var lib: AnimationLibrary = KeyedClips.load_library()
	var ctx: ClipDirector.Context = _ctx()
	var name: String = KeyedClips.anim_name(KeyedClips.POWER_UP)
	ctx.lengths[name] = lib.get_animation(KeyedClips.POWER_UP).length
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	f.armed = false
	f.set_state(&"recall", SimConst.RECALL_FRAMES)
	for sf: int in [1, SimConst.RECALL_BURST_FRAME, SimConst.RECALL_FRAMES]:
		f.sf = sf
		W.frame += 1
		var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
		assert_eq([shot.drive, shot.clip.name], [ClipDirector.STATE, name], "frame %d: the power-up, whole body" % sf)
		assert_almost_eq(shot.clip.time, float(sf) / 60.0, 1e-6, "frame %d: on the recall's frames" % sf)
	assert_eq(ClipDirector.step(null, f, _ctx()).drive, ClipDirector.LEGS, "without the clip in the tree: none")
