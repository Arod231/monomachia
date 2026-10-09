extends GutTest
## The per-move checklist's items that no other test checks move by move on
## the live data (milestone-1 task 40), for every keyed move
## (ChecklistResults.keyed_moves()) and every clip row
## (ChecklistResults.clip_rows()), each result recorded for npm run
## checklist:
## - 3, a clip row's clips fit their protected frames at their own speed;
## - 4, each plays at its own speed (the clip director, on the committed
##   state clip table and the moves' baked swings);
## - 11, a keyed move hands off cleanly (its branch points the table's, its
##   string's sides continuous, a bridge into it and a return to guard);
## - 12, it has its deflect pair, the light block reaction and a light hit
##   reaction for every place;
## - 13, its swing, hit, block and parry sound, and its deflect pair's;
## - 14, its effects at the contact (blood on a hit, sparks on a block and a
##   parry, an air smear on its strike; a bare hand's dust-and-cloth puff on
##   all three, milestone-1 task 95);
## - 15, the computer uses it and answers it (seeded Hard duels).
## Reads committed data and runs the rules, so it runs on CI. Every keyed
## move must pass, but a keyed bare-hands move outside the movement attacks
## (Breaker Palm, task 99; the light string, task 89; the heavies, task 133)
## has its reactions (12) and its contacts' sound and effects (13, 14)
## recorded for its family's review, not held: bare hands' reactions and
## the redirect's deflect pair are tasks 69's and 90's. Bare hands' string
## starts and ends in its guard and hands on by the inertial blend, with no
## bridge or return to guard (task 89, the owner's word), and is played
## across bare hands' duelling distance. Bare hands' eight
## movement attacks have their sound and effects held since task 95 (a
## parried fist meets no steel, so sounds no deflect pair); a jump attack
## is played out of a jump, close, and a dodge attack from where its roll
## leaves it. A clip row's results
## are recorded for the owner whether they pass or not, as task 40 decided
## (the new strings re-key them). Each move is played on its own weapon:
## a bare-hands one by a disarmed fighter.

const SC := preload("res://tests/sim/test_string_continuity.gd")
const H := preload("res://tests/sim/sim_helpers.gd")

## The gap a keyed light is played across: the duelling distance, where its
## blade lands 15-20 cm in.
const GAP: float = 2.5
## The gap a jump attack is played across, from a jump in place: inside its
## reach (Air Kick and Axe Kick touch from 1.35 m), and the frames from the
## jump to the attack, as the move sheet's drives.
const JUMP_GAP: float = 1.2
const JUMP_LEAD: int = 3
## The gap a dodge attack is played across: where the roll in leaves it, as
## the computer throws one (AIBrain.DODGE_ATTACK_FROM; Slip Jab and Spinning
## Backfist step in only a little).
const DODGE_GAP: float = AIBrain.DODGE_ATTACK_FROM
## Bare hands' eight movement attacks (family 8), whose sound and effects
## are held (milestone-1 task 95).
const MOVEMENT_ATTACKS: Array[StringName] = [&"f_sl", &"f_sh", &"f_dl", &"f_dh", &"f_bl", &"f_bh", &"f_jl", &"f_jh"]
## Far enough apart that nothing lands, so no hit-stop.
const APART: float = 6.0
## The seeded duels for item 15, each this many steps at most: 22 since KE
## task 3's spacing (12 held every move before), where few four-hit strings
## get past their first light, so Crown Cut comes up only in the 13th.
const DUELS: int = 22
const DUEL_STEPS: int = 3600
## Breaker Palm needs a fighter disarmed and low enough for its ultimate,
## which the duels seldom give (since KE task 13 once in 60, never
## answered): these short duels start one fighter there, at this health.
const DISARMED_DUELS: int = 12
## Bare hands' movement attacks need both fighters bare-handed for a whole
## duel (milestone-1 task 93): each seed fought again so.
const BARE_DUELS: int = DUELS
const DISARMED_STEPS: int = 600
const DISARMED_HP: float = 20.0


func after_each() -> void:
	H.dispose_all()


## A director context with the libraries, each of `clips` (ids) 10 s long
## in the Hunter's set.
static func _ctx(clips: Array) -> ClipDirector.Context:
	var lengths: Dictionary[String, float] = {}
	for id: Variant in clips:
		lengths[_part_anim(id)] = 10.0
	return ClipDirector.Context.make(&"hunter", true, lengths)


## The hunter's animation of chain entry `entry` (its part's clip).
static func _part_anim(entry: Variant) -> String:
	var part: ClipChain.Part = ClipChain.parse(str(entry), [] as Array[String])
	return ClipChain.anim_name(ClipLibraries.set_for(&"hunter"), part.id)


## Plays keyed move `id` from the guard at `gap`, the defender pressing
## `defend` (Btn.BLOCK held from `from`, or nothing), and returns its events.
static func _play(wid: StringName, id: StringName, gap: float, defend: int = -1, from: int = 0) -> Array[Dictionary]:
	var W: World = _world(wid, gap)
	var a: Fighter = W.fighters[0]
	if _jumps(wid, id):
		W.step([H.btn(Btn.JUMP), H.idle()])
		H.run(W, JUMP_LEAD - 1)
		W.drain_events()
	a.start_attack(id)
	var events: Array[Dictionary] = []
	for i: int in 200:
		var guard: RawInput = H.btn(defend) if defend >= 0 and i >= from else H.idle()
		W.step([H.idle(), guard])
		events.append_array(W.drain_events())
		if a.state != &"attack":
			break
	return events


## A Katana duel `gap` apart, fighter 0 disarmed for a bare-hands move.
static func _world(wid: StringName, gap: float) -> World:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, gap)
	if wid == &"fists":
		W.fighters[0].armed = false
	return W


## Whether keyed move `id` of weapon `wid` is a jump attack, struck in the
## air.
static func _jumps(wid: StringName, id: StringName) -> bool:
	return ((Moves.WEAPONS[wid] as WeaponDef).moves[id] as AttackDef).airborne


## The gap keyed move `id` of weapon `wid` is played across.
static func _gap(wid: StringName, id: StringName) -> float:
	if wid == &"fists" and _of_string([wid, id]):
		return Moves.FISTS.duel_distance
	if _jumps(wid, id):
		return JUMP_GAP
	if String(FrameDataTable.shared().row(wid, id).get("kind", "")).begins_with("dodge_"):
		return DODGE_GAP
	return GAP


## Whether keyed move `m` ([weapon, id]) is one of a string's (its band
## kind string_light or string_heavy): the moves that bridge and return to
## guard, and whose reactions are held.
static func _of_string(m: Array) -> bool:
	return String(FrameDataTable.shared().row(m[0], m[1]).get("kind", "")).begins_with("string_")


## Whether keyed move `m` is held to a string's bridge, return to guard,
## reactions, sound and effects: the Katana's string moves (bare hands'
## string hands on by the inertial blend, its reactions and impacts tasks
## 69's, 90's and 91's).
static func _held(m: Array) -> bool:
	return _of_string(m) and m[0] == &"katana"


static func _first(events: Array[Dictionary], t: StringName, id: StringName) -> Dictionary:
	for e: Dictionary in events:
		if e["t"] == t and e.get("attack", &"") == id:
			return e
	return {}


## The keyed move `id`'s hit, block and parry events at the duelling
## distance (the parry: the guard pressed 4 frames before it lands).
static func _contacts(wid: StringName, id: StringName) -> Dictionary:
	var def: AttackDef = (Moves.WEAPONS[wid] as WeaponDef).moves[id]
	var gap: float = _gap(wid, id)
	return {
		&"swing": _first(_play(wid, id, gap), &"swing", id),
		&"hit": _first(_play(wid, id, gap), &"hit", id),
		&"block": _first(_play(wid, id, gap, Btn.BLOCK, 0), &"block", id),
		&"parry": _first(_play(wid, id, gap, Btn.BLOCK, def.startup - 4), &"parry", id),
	}


# ------------------------------------------------------------------ item 4

func test_every_keyed_move_plays_its_clip_at_1x() -> void:
	for m: Array in ChecklistResults.keyed_moves():
		var id: StringName = m[1]
		var def: AttackDef = (Moves.WEAPONS[m[0]] as WeaponDef).moves[id]
		var problems: Array[String] = []
		if not def.real_markers or def.swing == null or def.swing.clips.is_empty():
			problems.append("not on its own clip's markers")
		else:
			var ctx: ClipDirector.Context = _ctx(def.swing.clips)
			var W: World = _world(m[0], APART)
			var f: Fighter = W.fighters[0]
			f.start_attack(id)
			var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
			# a chain's parts in order (the Iai's, KE task 18), each at 1x
			var parts: Array[String] = []
			for entry: StringName in def.swing.clips:
				parts.append(_part_anim(entry))
			var at: int = 0
			var last: float = -1.0
			while f.state == &"attack" and problems.is_empty():
				var now: int = parts.find(shot.clip.name, at) if shot.clip != null else -1
				if shot.drive != ClipDirector.ATTACK or now < 0:
					problems.append("frame %d plays %s, not %s" % [f.atk.frame, shot.clip.name if shot.clip != null else "nothing", parts[at]])
				elif now == at and last >= 0.0 and absf(shot.clip.time - last - 1.0 / 60.0) > 1e-6:
					problems.append("frame %d steps %.4f s, not 1/60" % [f.atk.frame, shot.clip.time - last])
				at = maxi(at, now)
				if shot.clip != null:
					last = shot.clip.time
				W.step([H.idle(), H.idle()])
				shot = ClipDirector.step(shot, f, ctx)
		ChecklistResults.record_problems(4, id, problems)
		assert_eq(problems, [] as Array[String], String(id))


func test_every_clip_row_plays_at_1x() -> void:
	var sc: StateClips = StateClips.read()
	var rows: Dictionary[StringName, Array] = ChecklistResults.clip_rows()
	# the reactions: listed to play at 1.0 from their state's start
	for row: StringName in [&"clip_hit_light", &"clip_block_light"]:
		var by_clip: Dictionary = {}
		for clip: StringName in rows[row]:
			var problems: Array[String] = []
			if sc.own_speed.get(clip, &"") != &"hand_on":
				problems.append("not listed to play at its own speed")
			by_clip[clip] = problems
		ChecklistResults.record_clips(4, row, by_clip)
		for clip: Variant in by_clip:
			assert_eq(by_clip[clip], [] as Array[String], str(clip))
	# the deflect pairs (the lights', the redirect's and a blade's at a limb:
	# milestone-1 tasks 34 and 90): each half from its contact frame, a rules
	# frame a 60th of a second on
	var W: World = H.make_world()
	var f: Fighter = W.fighters[0]
	var pair_rows: Dictionary[StringName, Array] = ChecklistResults.pair_rows()
	for row: StringName in pair_rows:
		_record_pairs_at_1x(row, pair_rows[row], f)


## Item 4 for deflect pair row `row`: each of `pairs`' halves played by `f`
## from its contact frame at 1.0x, recorded and held.
func _record_pairs_at_1x(row: StringName, pairs: Array, f: Fighter) -> void:
	var by_pair: Dictionary = {}
	for pair: Dictionary in pairs:
		var ctx: ClipDirector.Context = _ctx([pair[&"deflect"], pair[&"recoil"]])
		for half: Array in [[&"recoil", &"recoil"], [&"deflect", &"parryAnim"]]:
			var problems: Array[String] = []
			f.set_state(half[1], 30)
			f.blocking = false
			var prev: ClipDirector.Shot = null
			for k: int in 10:
				var got: Array = ClipDirector.pair_clip(prev, f, ctx, pair)
				var want: float = float(pair[StringName("%s_contact" % half[0])]) / 30.0 + k / 60.0
				if got.is_empty() or got[1] != half[0] or absf((got[0] as ClipDirector.Clip).time - want) > 1e-6:
					problems.append("frame %d off 1.0x" % k)
					break
				prev = ClipDirector.Shot.new()
				prev.phase = half[0]
				prev.since = k
				prev.pair = pair
			by_pair[pair[half[0]]] = problems
	ChecklistResults.record_clips(4, row, by_pair)
	for clip: Variant in by_pair:
		assert_eq(by_pair[clip], [] as Array[String], str(clip))


# ------------------------------------------------------------------ item 3

## A clip row's fit, recorded for the owner, not held: the reactions settle
## within a rules frame of their stun's end (test_state_clip_fit.gd holds
## them); a deflect pair's recoil settles within a rules frame of the parry
## recoil after its contact (the deflect half hands on to whatever the
## parrier does once free).
func test_every_clip_row_s_fit_to_its_protected_frames_is_recorded() -> void:
	var sc: StateClips = StateClips.read()
	var manifest: ClipManifest = ClipManifest.read()
	var pt: ProtectedTimings = ProtectedTimings.for_weapon(&"katana")
	var rows: Dictionary[StringName, Array] = ChecklistResults.clip_rows()
	var frames: Dictionary = {&"clip_hit_light": pt.hitstun(&"light"), &"clip_block_light": pt.blockstun(&"light")}
	for row: StringName in frames:
		var by_clip: Dictionary = {}
		for clip: StringName in rows[row]:
			var settle: float = manifest.clips[clip].markers["settle"] * MoveClips.RULES_PER_SOURCE
			by_clip[clip] = [] if absf(settle - frames[row]) <= 1.0 else ["settles on rules frame %d of its %d" % [settle, frames[row]]]
		ChecklistResults.record_clips(3, row, by_clip)
	# each pair row's recoils (the redirect's, before Stun01 takes over the
	# rest of its stun, and the limbs' fit the parry recoil too: task 90)
	var pair_rows: Dictionary[StringName, Array] = ChecklistResults.pair_rows()
	for row: StringName in pair_rows:
		var by_pair: Dictionary = {}
		for pair: Dictionary in pair_rows[row]:
			var clip: StringName = pair[&"recoil"]
			var after: float = (manifest.clips[clip].markers["settle"] - float(pair[&"recoil_contact"])) * MoveClips.RULES_PER_SOURCE
			var want: int = SimConst.PARRY_RECOIL
			by_pair[clip] = [] if absf(after - want) <= 1.0 else ["settles %d rules frames after its contact, the parry recoil %d" % [after, want]]
		ChecklistResults.record_clips(3, row, by_pair)
	assert_eq(pair_rows[&"clip_deflect_light"].size(), sc.deflect_pairs.size(), "every light pair's recoil measured")


# ------------------------------------------------------------------ items 11 and 12

func test_every_keyed_move_hands_off_cleanly_and_has_its_reactions() -> void:
	var sc: StateClips = StateClips.read()
	var breaks: Array[String] = SC._breaks(Moves.KATANA.moves)
	for m: Array in ChecklistResults.keyed_moves():
		var w: WeaponDef = Moves.WEAPONS[m[0]]
		var id: StringName = m[1]
		var def: AttackDef = w.moves[id]
		var row: Dictionary = FrameDataTable.shared().row(w.id, id)
		var hand_off: Array[String] = []
		for follow: StringName in [def.chain_light, def.chain_heavy]:
			if follow == &"":
				continue
			var want: Array = ((row.get("branches", {}) as Dictionary).get(String(follow), []) as Array).map(func(x: Variant) -> int: return int(x))
			if Array(def.branch_window(follow)) != want:
				hand_off.append("its branch into %s isn't the table's" % follow)
		for b: String in breaks:
			if b.begins_with(String(id) + " ") or b.contains(" " + String(id) + ","):
				hand_off.append(b)
		# a follow-up whose own clip goes on from the move before (StateClips
		# meets, KE task 15) needs no bridge
		for before: StringName in w.moves:
			if _held(m) and (w.moves[before] as AttackDef).chain_light == id and ChecklistResults.keyed_moves().has([m[0], before]) \
					and not (sc.bridges.get(id, {}) as Dictionary).has(before) and sc.meets.get(id, &"") != before:
				hand_off.append("no bridge from %s" % before)
		# a string's moves return to guard on a clip of their own; any other
		# hands on by the inertial blend
		if _held(m) and not sc.returns.has(id):
			hand_off.append("no return to guard")
		ChecklistResults.record_problems(11, id, hand_off)
		assert_eq(_due(hand_off, id), [] as Array[String], "%s hands off" % id)
		var reactions: Array[String] = []
		if not sc.deflect_pairs.has(id):
			reactions.append("no deflect pair")
		if not sc.light_blocks.has(w.id):
			reactions.append("no light block reaction")
		for place: String in StateClips.HIT_PLACES:
			if not (sc.light_hits.get(w.id, {}) as Dictionary).has(StringName(place)):
				reactions.append("no light hit reaction %s" % place)
		ChecklistResults.record_problems(12, id, reactions)
		if _held(m):
			assert_eq(_due(reactions, id), [] as Array[String], "%s's reactions" % id)


# ------------------------------------------------------------------ items 13 and 14

func test_every_keyed_move_sounds_and_shows_its_contacts() -> void:
	var sc: StateClips = StateClips.read()
	for m: Array in ChecklistResults.keyed_moves():
		var id: StringName = m[1]
		var c: Dictionary = _contacts(m[0], id)
		var bare: bool = m[0] == EffectTable.BARE
		var sound: Array[String] = []
		var effects: Array[String] = []
		for t: StringName in c:
			if (c[t] as Dictionary).is_empty():
				sound.append("no %s at %.1f m" % [t, _gap(m[0], id)])
				effects.append("no %s at %.1f m" % [t, _gap(m[0], id)])
			elif SoundBank.cues_for(c[t]).is_empty():
				sound.append("its %s sounds nothing" % t)
		# a parried fist meets no steel: no deflect pair (task 95)
		if not (c[&"parry"] as Dictionary).is_empty() and not bare:
			if not SoundBank.sounds_deflect_pair(c[&"parry"]) or not sc.deflect_pairs.has(id):
				sound.append("its parry sounds no deflect pair")
			else:
				var direction: StringName = StringName(sc.deflect_pairs[id][&"direction"])
				for half: StringName in [&"deflect", &"recoil"]:
					if SoundBank.deflect_pair_cues(direction, half).is_empty():
						sound.append("its %s half sounds nothing" % half)
		if bare:
			for t: StringName in [&"hit", &"block", &"parry"]:
				if not (c[t] as Dictionary).is_empty() and EffectTable.count_of(c[t], EffectTable.PUFF) <= 0:
					effects.append("its %s throws no dust and cloth" % t)
		else:
			if not (c[&"hit"] as Dictionary).is_empty() and BloodEffects.plan(c[&"hit"], GameSettings.BLOOD_ON).is_empty():
				effects.append("its hit draws no blood")
			for t: StringName in [&"block", &"parry"]:
				if not (c[t] as Dictionary).is_empty() and EffectTable.count_of(c[t], EffectTable.SPARKS) <= 0:
					effects.append("its %s throws no sparks" % t)
		if not _smears(m[0], id):
			effects.append("its strike leaves no air smear")
		ChecklistResults.record_problems(13, id, sound)
		ChecklistResults.record_problems(14, id, effects)
		if _held(m) or MOVEMENT_ATTACKS.has(id):
			assert_eq(_due(sound, id), [] as Array[String], "%s's sound" % id)
			assert_eq(effects, [] as Array[String], "%s's effects" % id)


## `problems` less those a later KE task answers for a grip's own string hit
## (KE task 11): its deflect pair and the pair's sound (KE task 19). Its
## bridges and return to guard are held since KE task 15. They are still
## recorded in the checklist, for the owner.
static func _due(problems: Array[String], id: StringName = &"") -> Array[String]:
	var own: Callable = func(move: StringName) -> bool:
		return Moves.KATANA.moves.has(move) and (Moves.KATANA.moves[move] as AttackDef).grip != &""
	var out: Array[String] = []
	for p: String in problems:
		if own.call(id) and p in ["no deflect pair", "its parry sounds no deflect pair"]:
			continue
		out.append(p)
	return out


## Whether keyed move `id` smears through its active frames (TrailState),
## with either hand or limb (a bare hand's left strikes smear the left).
static func _smears(wid: StringName, id: StringName) -> bool:
	var W: World = _world(wid, APART)
	var f: Fighter = W.fighters[0]
	f.start_attack(id)
	var def: AttackDef = f.atk.def
	while f.state == &"attack":
		var t: TrailState = TrailState.of(f, 1.0)
		if f.atk.frame > def.startup and f.atk.frame <= def.startup + def.active and not (t.on(TrailState.RIGHT) or t.on(TrailState.LEFT)):
			return false
		W.step([H.idle(), H.idle()])
	return true


# ------------------------------------------------------------------ item 15

func test_the_computer_uses_and_answers_every_keyed_move() -> void:
	var used: Dictionary[StringName, int] = {}
	var answered: Dictionary[StringName, int] = {}
	for seed_value: int in DUELS:
		# every other duel from a round's start, one-handed, the rest
		# two-handed, so each grip's own string comes up (KE tasks 12 and 13)
		H.grip = WeaponGrip.ONE_HANDED if seed_value % 2 == 1 else WeaponGrip.TWO_HANDED
		var W: World = H.make_world(Moves.KATANA, Moves.KATANA, GAP)
		var brains: Array[AIBrain] = [
			AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"], 4000 + seed_value * 2),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"], 4001 + seed_value * 2),
		]
		_duel(W, brains, DUEL_STEPS, used, answered)
	# each seed again with both fighters bare-handed, since bare hands fight
	# only disarmed (4% of an armed duel; milestone-1 task 93), so the
	# movement attacks come up
	for seed_value: int in BARE_DUELS:
		H.grip = &""
		var W: World = H.make_world(Moves.KATANA, Moves.KATANA, GAP)
		W.fighters[0].armed = false
		W.fighters[1].armed = false
		var brains: Array[AIBrain] = [
			AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"], 4000 + seed_value * 2),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"], 4001 + seed_value * 2),
		]
		_duel(W, brains, DUEL_STEPS, used, answered)
		H.dispose_all()
	for seed_value: int in DISARMED_DUELS:
		H.grip = &""
		var W: World = H.make_world(Moves.KATANA, Moves.KATANA, GAP)
		W.fighters[0].hp = DISARMED_HP
		W.fighters[0].armed = false
		var brains: Array[AIBrain] = [
			AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"], 5000 + seed_value * 2),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"], 5001 + seed_value * 2),
		]
		_duel(W, brains, DISARMED_STEPS, used, answered)
		H.dispose_all()
	for m: Array in ChecklistResults.keyed_moves():
		var id: StringName = m[1]
		var problems: Array[String] = []
		if used.get(id, 0) == 0:
			problems.append("the computer never used it in %d Hard duels" % (DUELS + BARE_DUELS + DISARMED_DUELS))
		if answered.get(id, 0) == 0:
			problems.append("the computer never blocked or parried it in %d Hard duels" % (DUELS + BARE_DUELS + DISARMED_DUELS))
		ChecklistResults.record_problems(15, id, problems)
		# a grip's own hits 4 and 5 (KE tasks 12 and 14) are recorded, not
		# held: though Hard presses whole strings since KE task 14, most of its
		# strings in a duel are punishes of 2 or 3 presses, and a defender acts
		# in the gaps, so its strings seldom get past hit 3
		# the pilot's four lights are in neither grip's string (Right Cut and
		# Return Cut since KE task 13, Kesa Cut and Crown Cut since KE task
		# 14), so no computer plays them: recorded, not held
		# a move the defender is seldom free and in reach to answer has its
		# answers recorded, not held, only its use
		if SELDOM_ANSWERABLE.has(id):
			assert_gt(used.get(id, 0), 0, "%s: used" % id)
		elif not _late_hit(id) and not OUT_OF_PLAY.has(id) and not RARE_FOLLOW_UPS.has(id):
			assert_eq(problems, [] as Array[String], "%s: used %d, answered %d" % [id, used.get(id, 0), answered.get(id, 0)])
	gut.p("used: %s
answered: %s" % [used, answered])


## Plays `W`'s two Hard `brains` for up to `steps`, or to a knockout,
## counting each attack swung in `used` and blocked or parried in
## `answered`, then disposes of the brains.
static func _duel(W: World, brains: Array[AIBrain], steps: int, used: Dictionary[StringName, int], answered: Dictionary[StringName, int]) -> void:
	for i: int in steps:
		W.step([brains[0].think(), brains[1].think()])
		for e: Dictionary in W.drain_events():
			var id: StringName = StringName(str(e.get("attack", "")))
			if e["t"] == &"swing":
				used[id] = used.get(id, 0) + 1
			elif e["t"] == &"block" or e["t"] == &"parry":
				answered[id] = answered.get(id, 0) + 1
		if W.fighters[0].hp <= 0.0 or W.fighters[1].hp <= 0.0:
			break
	for b: AIBrain in brains:
		b.dispose()


## Whether each of `pairs`' halves hands on (item 11), played by `f`: the
## recoil once the guard is back up, the deflect once the parrier moves off;
## problems by clip.
func _pairs_hand_on(pairs: Array, f: Fighter) -> Dictionary:
	var hand: Dictionary = {}
	for pair: Dictionary in pairs:
		var ctx: ClipDirector.Context = _ctx([pair[&"deflect"], pair[&"recoil"]])
		f.vel = V3.make()
		f.set_state(&"recoil", 30)
		f.blocking = true
		var recoil_ends: bool = ClipDirector.pair_clip(null, f, ctx, pair).is_empty()
		f.blocking = false
		f.set_state(&"free", 0)
		f.vel = V3.make(1.0, 0.0, 0.0)
		var deflect_ends: bool = ClipDirector.pair_clip(null, f, ctx, pair).is_empty()
		f.vel = V3.make()
		hand[pair[&"recoil"]] = [] if recoil_ends else ["plays on with the guard back up"]
		hand[pair[&"deflect"]] = [] if deflect_ends else ["plays on with the parrier moving off"]
	return hand


## The pilot's lights no grip's string plays since KE tasks 13 and 14.
const OUT_OF_PLAY: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3", &"k_l4"]


## Bare hands' moves that seldom meet a defender free to answer them (task
## 133, measured over 90 bare and 80 disarmed duels): Spinning Heel comes
## mostly as the Roundhouse's follow-up, after its knockback has carried the
## defender out of reach (60 of 78 starts) or while they are still in
## hitstun, mid-dodge or mid-attack (the computer picks its answer on an
## attack's first frame), and was never parried; Snap Kick counters out of a
## backstep, the defender dodging or attacking, and was parried 3 times in
## 68 duels. Returning Draw (KE task 18) comes only as the horizontal Iai's
## heavy follow-up, which the computer draws a dozen times in 56 duels and
## follows with Returning Draw about once. The jump heavy (milestone-1 task
## 57, measured over the 22 bare duels): 18 of its 23 swings whiff, out of
## reach or on a defender mid-attack or mid-dodge, and 5 land; it was
## answered 4 times in 19 swings before the footwork moved the duels' paths,
## and not since.
const SELDOM_ANSWERABLE: Array[StringName] = [&"f_h2", &"f_bl", &"k_rdraw", &"f_jh"]


## Follow-ups the computer seldom reaches, recorded, not held (milestone-1
## task 57): Rising Heaven comes only as Heaven Splitter's optional
## follow-up or the vertical Iai's heavy one, and the Hard duels' only two
## (before task 57's footwork moved their paths) were one seed's two
## vertical Iai follow-ups; since then none in the 56 duels, nor with the
## armed ones doubled to 44, though Heaven Splitter came 74 times. KE task
## 17's rules tests (test_grip_heavies.gd) hold the follow-up itself.
const RARE_FOLLOW_UPS: Array[StringName] = [&"k_h1f"]


## Whether keyed move `id` is hit 4 or 5 of a grip's own string.
static func _late_hit(id: StringName) -> bool:
	var def: AttackDef = Moves.KATANA.moves.get(id, null)
	return def != null and def.grip != &"" and Moves.KATANA.string_position(id) >= 4


# ------------------------------------------------------------------ the clip rows' 11, 13 and 14

## A clip row hands off cleanly (11): a reaction plays at 1.0 and hands on
## at its end, never held; a recoil hands on when the guard comes back up,
## a deflect when the parrier moves off. It sounds (13) and shows (14) its
## contact: a parry's deflect pair cues and sparks, a light hit's sound and
## blood, a light block's sound and sparks (Right Cut's, at the duelling
## distance).
func test_every_clip_row_hands_off_sounds_and_shows_its_contact() -> void:
	var sc: StateClips = StateClips.read()
	var rows: Dictionary[StringName, Array] = ChecklistResults.clip_rows()
	var c: Dictionary = _contacts(&"katana", &"k_l1")
	# the reactions
	var reaction_contact: Dictionary = {&"clip_hit_light": c[&"hit"], &"clip_block_light": c[&"block"]}
	for row: StringName in reaction_contact:
		var hand: Dictionary = {}
		var sound: Dictionary = {}
		var shown: Dictionary = {}
		var e: Dictionary = reaction_contact[row]
		for clip: StringName in rows[row]:
			hand[clip] = [] if ClipDirector.state_time(clip, 61, 24, 1.0) < 0.0 and is_equal_approx(ClipDirector.state_time(clip, 30, 24, 1.0), 0.5) \
				else ["held or stretched, not handed on at its end"]
			sound[clip] = [] if not e.is_empty() and not SoundBank.cues_for(e).is_empty() else ["its contact sounds nothing"]
			var shows: bool = not e.is_empty() and (not BloodEffects.plan(e, GameSettings.BLOOD_ON).is_empty() if row == &"clip_hit_light"
				else EffectTable.count_of(e, EffectTable.SPARKS) > 0)
			shown[clip] = [] if shows else ["its contact shows nothing"]
		ChecklistResults.record_clips(11, row, hand)
		ChecklistResults.record_clips(13, row, sound)
		ChecklistResults.record_clips(14, row, shown)
		for clip: Variant in hand:
			assert_eq(hand[clip] + sound[clip] + shown[clip], [], "%s" % clip)
	# the deflect pairs: each hands on (11) as the lights' do; the lights'
	# sound and sparks (13, 14), the redirect's and a parried limb's sound
	# and effects being task 91's
	var W: World = H.make_world()
	var f: Fighter = W.fighters[0]
	var pair_rows: Dictionary[StringName, Array] = ChecklistResults.pair_rows()
	for row: StringName in pair_rows:
		if row != &"clip_deflect_light":
			var handed: Dictionary = _pairs_hand_on(pair_rows[row], f)
			ChecklistResults.record_clips(11, row, handed)
			for clip: Variant in handed:
				assert_eq(handed[clip], [], "%s" % clip)
	var hand: Dictionary = _pairs_hand_on(pair_rows[&"clip_deflect_light"], f)
	var sound: Dictionary = {}
	var shown: Dictionary = {}
	for pair: Dictionary in pair_rows[&"clip_deflect_light"]:
		for half: StringName in [&"deflect", &"recoil"]:
			var clip: StringName = pair[half]
			sound[clip] = [] if not SoundBank.deflect_pair_cues(StringName(pair[&"direction"]), half).is_empty() else ["its half sounds nothing"]
			shown[clip] = [] if not (c[&"parry"] as Dictionary).is_empty() and EffectTable.count_of(c[&"parry"], EffectTable.SPARKS) > 0 \
				else ["the parry throws no sparks"]
	ChecklistResults.record_clips(11, &"clip_deflect_light", hand)
	ChecklistResults.record_clips(13, &"clip_deflect_light", sound)
	ChecklistResults.record_clips(14, &"clip_deflect_light", shown)
	for clip: Variant in hand:
		assert_eq(hand[clip] + sound[clip] + shown[clip], [], "%s" % clip)
