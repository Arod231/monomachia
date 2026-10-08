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
##   parry, an air smear on its strike);
## - 15, the computer uses it and answers it (seeded Hard duels).
## Reads committed data and runs the rules, so it runs on CI. Every keyed
## move must pass, but a keyed bare-hands move (Breaker Palm, task 99; Jab,
## Cross and Hook, task 89) has its reactions (12) and its contacts' sound
## and effects (13, 14) recorded for its family's review, not held: bare
## hands' reactions, the redirect's deflect pair and their impacts are tasks
## 69's, 90's and 91's. Bare hands' string starts and ends in its guard and
## hands on by the inertial blend, with no bridge or return to guard (task
## 89, the owner's word). A clip row's results
## are recorded for the owner whether they pass or not, as task 40 decided
## (the new strings re-key them). Each move is played on its own weapon:
## a bare-hands one by a disarmed fighter.

const SC := preload("res://tests/sim/test_string_continuity.gd")
const H := preload("res://tests/sim/sim_helpers.gd")

## The gap a keyed Katana move is played across: the duelling distance, where
## its blade lands 15-20 cm in. Bare hands play across theirs (_gap()).
const GAP: float = 2.5
## Far enough apart that nothing lands, so no hit-stop.
const APART: float = 6.0
## The seeded duels for item 15, each this many steps at most: 22 since KE
## task 3's spacing (12 held every move before), where few four-hit strings
## get past their first light, so Crown Cut comes up only in the 13th, and
## Breaker Palm, which needs a disarmed fighter's ultimate, is swung and
## answered only in the 22nd.
const DUELS: int = 22
const DUEL_STEPS: int = 3600


func after_each() -> void:
	H.dispose_all()


## A director context with the libraries, each of `clips` (ids) 10 s long
## in the Hunter's set.
static func _ctx(clips: Array) -> ClipDirector.Context:
	var lengths: Dictionary[String, float] = {}
	for id: Variant in clips:
		lengths[ClipChain.anim_name(ClipLibraries.set_for(&"hunter"), StringName(str(id)))] = 10.0
	return ClipDirector.Context.make(&"hunter", true, lengths)


## Plays keyed move `id` from the guard at `gap`, the defender pressing
## `defend` (Btn.BLOCK held from `from`, or nothing), and returns its events.
static func _play(wid: StringName, id: StringName, gap: float, defend: int = -1, from: int = 0) -> Array[Dictionary]:
	var W: World = _world(wid, gap)
	var a: Fighter = W.fighters[0]
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


## Whether keyed move `m` ([weapon, id]) is one of a string's (its band
## kind string_light or string_heavy): the moves that bridge and return to
## guard, and whose reactions are held.
## The gap weapon `wid`'s keyed moves are played across: bare hands'
## duelling distance, or GAP.
static func _gap(wid: StringName) -> float:
	return Moves.FISTS.duel_distance if wid == &"fists" else GAP


## Whether keyed move `m` is held to items 12 to 14 (and its string to a
## bridge and a return to guard): the Katana's string moves.
static func _held(m: Array) -> bool:
	return _of_string(m) and m[0] == &"katana"


static func _of_string(m: Array) -> bool:
	return String(FrameDataTable.shared().row(m[0], m[1]).get("kind", "")).begins_with("string_")


static func _first(events: Array[Dictionary], t: StringName, id: StringName) -> Dictionary:
	for e: Dictionary in events:
		if e["t"] == t and e.get("attack", &"") == id:
			return e
	return {}


## The keyed move `id`'s hit, block and parry events at the duelling
## distance (the parry: the guard pressed 4 frames before it lands).
static func _contacts(wid: StringName, id: StringName) -> Dictionary:
	var def: AttackDef = (Moves.WEAPONS[wid] as WeaponDef).moves[id]
	return {
		&"swing": _first(_play(wid, id, _gap(wid)), &"swing", id),
		&"hit": _first(_play(wid, id, _gap(wid)), &"hit", id),
		&"block": _first(_play(wid, id, _gap(wid), Btn.BLOCK, 0), &"block", id),
		&"parry": _first(_play(wid, id, _gap(wid), Btn.BLOCK, def.startup - 4), &"parry", id),
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
			var want: String = ClipChain.anim_name(ClipLibraries.set_for(&"hunter"), def.swing.clips[0])
			var last: float = -1.0
			while f.state == &"attack" and problems.is_empty():
				if shot.drive != ClipDirector.ATTACK or shot.clip == null or shot.clip.name != want:
					problems.append("frame %d plays %s, not %s" % [f.atk.frame, shot.clip.name if shot.clip != null else "nothing", want])
				elif last >= 0.0 and absf(shot.clip.time - last - 1.0 / 60.0) > 1e-6:
					problems.append("frame %d steps %.4f s, not 1/60" % [f.atk.frame, shot.clip.time - last])
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
	# the deflect pairs: each half from its contact frame, a rules frame a
	# 60th of a second on
	var by_pair: Dictionary = {}
	var W: World = H.make_world()
	var f: Fighter = W.fighters[0]
	for move: StringName in sc.deflect_pairs:
		var pair: Dictionary = sc.deflect_pairs[move]
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
	ChecklistResults.record_clips(4, &"clip_deflect_light", by_pair)
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
	var by_pair: Dictionary = {}
	for move: StringName in sc.deflect_pairs:
		var pair: Dictionary = sc.deflect_pairs[move]
		var clip: StringName = pair[&"recoil"]
		var after: float = (manifest.clips[clip].markers["settle"] - float(pair[&"recoil_contact"])) * MoveClips.RULES_PER_SOURCE
		var want: int = SimConst.PARRY_RECOIL
		by_pair[clip] = [] if absf(after - want) <= 1.0 else ["settles %d rules frames after its contact, the parry recoil %d" % [after, want]]
	ChecklistResults.record_clips(3, &"clip_deflect_light", by_pair)
	assert_eq(by_pair.size(), sc.deflect_pairs.size(), "every pair's recoil measured")


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
		for before: StringName in w.moves:
			if _held(m) and (w.moves[before] as AttackDef).chain_light == id and ChecklistResults.keyed_moves().has([m[0], before]) \
					and not (sc.bridges.get(id, {}) as Dictionary).has(before):
				hand_off.append("no bridge from %s" % before)
		# a string's moves return to guard on a clip of their own; any other
		# hands on by the inertial blend
		if _held(m) and not sc.returns.has(id):
			hand_off.append("no return to guard")
		ChecklistResults.record_problems(11, id, hand_off)
		assert_eq(hand_off, [] as Array[String], "%s hands off" % id)
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
			assert_eq(reactions, [] as Array[String], "%s's reactions" % id)


# ------------------------------------------------------------------ items 13 and 14

func test_every_keyed_move_sounds_and_shows_its_contacts() -> void:
	var sc: StateClips = StateClips.read()
	for m: Array in ChecklistResults.keyed_moves():
		var id: StringName = m[1]
		var c: Dictionary = _contacts(m[0], id)
		var sound: Array[String] = []
		var effects: Array[String] = []
		for t: StringName in c:
			if (c[t] as Dictionary).is_empty():
				sound.append("no %s at %.2f m" % [t, _gap(m[0])])
				effects.append("no %s at %.2f m" % [t, _gap(m[0])])
			elif SoundBank.cues_for(c[t]).is_empty():
				sound.append("its %s sounds nothing" % t)
		if not (c[&"parry"] as Dictionary).is_empty():
			if not SoundBank.sounds_deflect_pair(c[&"parry"]) or not sc.deflect_pairs.has(id):
				sound.append("its parry sounds no deflect pair")
			else:
				var direction: StringName = StringName(sc.deflect_pairs[id][&"direction"])
				for half: StringName in [&"deflect", &"recoil"]:
					if SoundBank.deflect_pair_cues(direction, half).is_empty():
						sound.append("its %s half sounds nothing" % half)
		if not (c[&"hit"] as Dictionary).is_empty() and BloodEffects.plan(c[&"hit"], GameSettings.BLOOD_ON).is_empty():
			effects.append("its hit draws no blood")
		for t: StringName in [&"block", &"parry"]:
			if not (c[t] as Dictionary).is_empty() and EffectTable.count_of(c[t], EffectTable.SPARKS) <= 0:
				effects.append("its %s throws no sparks" % t)
		if not _smears(m[0], id):
			effects.append("its strike leaves no air smear")
		ChecklistResults.record_problems(13, id, sound)
		ChecklistResults.record_problems(14, id, effects)
		if _held(m):
			assert_eq(sound, [] as Array[String], "%s's sound" % id)
			assert_eq(effects, [] as Array[String], "%s's effects" % id)


## Whether keyed move `id` smears through its active frames (TrailState).
static func _smears(wid: StringName, id: StringName) -> bool:
	var W: World = _world(wid, APART)
	var f: Fighter = W.fighters[0]
	f.start_attack(id)
	var def: AttackDef = f.atk.def
	while f.state == &"attack":
		if f.atk.frame > def.startup and f.atk.frame <= def.startup + def.active and not TrailState.of(f, 1.0).on(TrailState.RIGHT):
			return false
		W.step([H.idle(), H.idle()])
	return true


# ------------------------------------------------------------------ item 15

## Each weapon's keyed moves are played in its own Hard duels, across its
## duelling distance (bare hands' since milestone-1 task 89: in the Katana's
## duels they come only after a disarm).
func test_the_computer_uses_and_answers_every_keyed_move() -> void:
	var used: Dictionary[StringName, int] = {}
	var answered: Dictionary[StringName, int] = {}
	var weapons: Array[StringName] = []
	for m: Array in ChecklistResults.keyed_moves():
		if not weapons.has(m[0]):
			weapons.append(m[0])
	for wid: StringName in weapons:
		_duel(Moves.WEAPONS[wid], _gap(wid), used, answered)
	for m: Array in ChecklistResults.keyed_moves():
		var id: StringName = m[1]
		var problems: Array[String] = []
		if used.get(id, 0) == 0:
			problems.append("the computer never used it in %d Hard duels" % DUELS)
		if answered.get(id, 0) == 0:
			problems.append("the computer never blocked or parried it in %d Hard duels" % DUELS)
		ChecklistResults.record_problems(15, id, problems)
		assert_eq(problems, [] as Array[String], "%s: used %d, answered %d" % [id, used.get(id, 0), answered.get(id, 0)])


## Plays DUELS seeded Hard duels of weapon `w` against itself from `gap` m
## apart, counting each attack's swings into `used` and the blocks and parries
## of it into `answered`, by move id.
static func _duel(w: WeaponDef, gap: float, used: Dictionary[StringName, int], answered: Dictionary[StringName, int]) -> void:
	for seed_value: int in DUELS:
		var W: World = H.make_world(w, w, gap)
		var brains: Array[AIBrain] = [
			AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"], 4000 + seed_value * 2),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"], 4001 + seed_value * 2),
		]
		for i: int in DUEL_STEPS:
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
	# the deflect pairs
	var W: World = H.make_world()
	var f: Fighter = W.fighters[0]
	var hand: Dictionary = {}
	var sound: Dictionary = {}
	var shown: Dictionary = {}
	for move: StringName in sc.deflect_pairs:
		var pair: Dictionary = sc.deflect_pairs[move]
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
