extends GutTest
## The stand-in finisher on screen (milestone-1 task 103, until tasks 104 and
## 105 bring its clips): the finisher plays a move it already has, the
## Katana's vertical Iai Slash or bare hands' Cross, over the finisher's
## frames so it lands at the kill; the victim holds the disarm stagger's stun.
## The moves are given made-up baked clips here, so this runs without the
## packs, as in test_clip_director.gd.

const LENGTH: float = 1.5

var _saved: Dictionary = {}


func before_each() -> void:
	FrozenStateClips.install()
	for pair: Array in [[Moves.KATANA, &"k_iai"], [Moves.FISTS, &"f_l2"]]:
		var w: WeaponDef = pair[0]
		var id: StringName = pair[1]
		_saved[id] = [w, w.moves[id].swing]
		w.moves[id].swing = _baked(w.moves[id], [StringName("Clip_" + String(id))])


func after_each() -> void:
	for id: StringName in _saved:
		var w: WeaponDef = _saved[id][0]
		w.moves[id].swing = _saved[id][1]
	_saved.clear()
	FrozenStateClips.restore()
	SimHelpers.dispose_all()


## A baked swing for `move` holding still, from `clips` at x1.0.
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


static func _ctx() -> ClipDirector.Context:
	var lengths: Dictionary[String, float] = {}
	for set_name: StringName in ClipLibraries.SETS:
		for id: String in ["Clip_k_iai", "Clip_f_l2"]:
			lengths["%s/%s" % [set_name, id]] = LENGTH
	return ClipDirector.Context.make(&"hunter", true, lengths)


## A world where fighter 1 has just started a finisher on fighter 0 at 5 HP.
static func _finishing(armed: bool) -> World:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	W.fighters[1].armed = armed
	W.fighters[0].hp = 5.0
	W.fighters[0].disarm(W.fighters[1], &"parried" if armed else &"redirect")
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	W.step([SimHelpers.idle(), SimHelpers.btn(Btn.HEAVY)])
	W.drain_events()
	return W


## The finisher's clip name and time after each world frame up to `frames`.
static func _played(W: World, frames: int) -> Array:
	var out: Array = []
	var shot: ClipDirector.Shot = null
	var ctx: ClipDirector.Context = _ctx()
	while W.finisher_frame < frames and W.finisher_by >= 0:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		shot = ClipDirector.step(shot, W.fighters[1], ctx)
		out.append([shot.clip.name if shot.clip != null else "", shot.clip.time if shot.clip != null else -1.0, shot.drive])
	return out


func test_the_katana_s_stand_in_finisher_plays_the_vertical_iai_slash_up_to_the_kill() -> void:
	var W: World = _finishing(true)
	assert_eq(W.fighters[1].state, &"finisher")
	var played: Array = _played(W, SimConst.FINISHER_KILL_FRAME)
	assert_gt(played.size(), 10)
	var last: float = -1.0
	for p: Array in played:
		assert_true(String(p[0]).ends_with("/Clip_k_iai"), "the Iai Slash's clip (%s)" % p[0])
		assert_eq(p[2], ClipDirector.ATTACK, "driven like an attack")
		assert_gte(float(p[1]), last, "moving on")
		last = p[1]
	assert_gt(last, 0.0)


func test_bare_hands_stand_in_finisher_plays_the_cross() -> void:
	var W: World = _finishing(false)
	var played: Array = _played(W, 20)
	assert_true(String(played[-1][0]).ends_with("/Clip_f_l2"), "the Cross's clip (%s)" % played[-1][0])


func test_the_victim_holds_the_stun_until_it_falls() -> void:
	var W: World = _finishing(true)
	assert_eq(W.fighters[0].state, &"finished")
	assert_eq(ClipDirector.reaction_of(W.fighters[0]), &"stun", "the disarm stagger's stun")
