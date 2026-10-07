extends GutTest
## State and ult clips on data (Animation Studio task 3): ClipDirector's choice
## of which clips play lives in game/assets/kevin_iglesias/state_clips.json,
## read by StateClips, with the values the constants held. Three checks that
## matches play as before, run against a frozen copy of the table
## (FrozenStateClips: tests/fixtures/state_clips_frozen.json), so the Studio
## saving the live file can't break them:
##  - OLD, the constants' values copied here before they were deleted, equals
##    what StateClips reads from the frozen copy;
##  - a scripted bout (idle, attacks, hits, guards, stuns, a parried attack,
##    the shoulder carry, the three ultimates, the keyed stomp, knockdown and
##    KO) gives the Shots recorded from the constants before they moved
##    (tests/fixtures/state_clips_shots.json, thinned: every frame near a
##    change of what plays, the rest every few);
##  - a file with an unknown key is refused.
## The live file is only checked to read cleanly. No packs needed: the
## contexts name made-up clip lengths.
##
## The recorded Shots stand for the frozen copy. To record them again (only if
## ClipDirector's rules change on purpose), run
## `MONOMACHIA_RECORD_STATE_CLIPS=1 node scripts/godot.mjs test -gselect=test_state_clips`
## and commit the diff.

const FIXTURE: String = "res://tests/fixtures/state_clips_shots.json"
const RECORD_ENV: String = "MONOMACHIA_RECORD_STATE_CLIPS"
const LENGTH: float = 1.5

## ClipDirector's clip constants as they were before they moved to data.
const OLD: Dictionary = {
	"FADES": {
		&"attack": 3, &"follow_up": 4, &"dodge_cancel": 2, &"hitstun": 0, &"locomotion": 6, &"stance": 8, &"state": 2,
		&"guard": 3, &"rebound": 4,
	},
	"IDLE": {
		&"katana": &"CombatIdle1H01", &"daggers": &"CombatIdle1H01",
		&"greatsword": &"CombatIdle2H01", &"fists": &"CombatIdle01",
	},
	"FALLBACK_IDLE": {
		&"katana": &"Sword_Idle", &"daggers": &"Sword_Idle", &"greatsword": &"Sword_Idle", &"fists": &"Idle",
	},
	"STATE_CLIPS": {&"stomp": &"Mikiri_Stomp", &"recall": &"Power_Up"},
	"STUN_CLIPS": {&"stomp": &"Mikiri_Pinned"},
	"HIT_CLIPS": [&"CombatDamage01", &"CombatDamage02"],
	"HIT_FALLBACKS": [&"Hit_Chest", &"Hit_Head"],
	"HEAVY_HITSTUN": 20,
	"GUARD_CLIPS": {
		&"katana": [&"Parry1H01_R_Loop", &"Parry1H01_R_Hit"], &"greatsword": [&"Parry2H01_Loop", &"Parry2H01_Hit"],
		&"daggers": [&"ParryDW01_Loop", &"ParryDW01_Hit"], &"fists": [&"Parry1H01_R_Loop", &"Parry1H01_R_Hit"],
	},
	"GUARD_FALLBACK": &"Sword_Block",
	"STUN_CLIP": &"Stun01",
	"STUN_FALLBACK": &"Hit_Knockback",
	"CARRY_POSE": &"ObjectGripShoulder02_R",
	"ULT_CLIPS": {&"vertical": [&"Attack2H01", 12.0], &"horizontal": [&"Attack2H03", 7.0]},
	"ULT_FALLBACK": &"Sword_Heavy_Combo",
	"ULT_WINDUP": 36,
	"ULT_RELEASE": 34,
	"IMPALER_CLIP": &"AttackPolearm01",
	"IMPALER_DRAWN": 8.0,
	"IMPALER_OUT": 14.0,
	"IMPALER_RECOVER": 18.0,
	"IMPALER_RECOVER_FRAMES": 30.0,
	"IMPALER_FALLBACK": &"Sword_Dash",
	"IMPALER_AIM": 30,
	"IMPALER_DASH": 40,
	"TEMPEST_SPIN": &"ual/Sword_Aerial_Combo",
	"TEMPEST_SLASHES": [2.0, 17.0],
	"TEMPEST_FLASH": 8,
	"TEMPEST_FINAL": &"AttackDW02",
	"TEMPEST_FINAL_FROM": 12.0,
	"TEMPEST_FINAL_FRAMES": 14,
	"TEMPEST_RECOVER_FRAMES": 24,
	"TEMPEST_FALLBACK": &"Sword_Heavy_Combo",
	"KNOCKDOWN_CLIPS": {
		&"fall": &"Knockdown01_Fall", &"ground": &"Knockdown01_Ground", &"standUp": &"Knockdown01_StandUp",
	},
	"KNOCKDOWN_FALLBACKS": {&"fall": &"Hit_Knockback", &"ground": &"LayToIdle", &"standUp": &"LayToIdle"},
	"KNOCKDOWN_STANDUP_FROM": 6.0,
	"KO_CLIPS": [[&"CombatDeath01", &"CombatDeath02"], [&"CombatDeath03", &"CombatDeath04"]],
	"KO_FALLBACK": &"Death01",
}

var _saved: Dictionary[StringName, Swing] = {}


func before_each() -> void:
	FrozenStateClips.install()
	var k: WeaponDef = Moves.KATANA
	for id: StringName in [&"k_l1", &"k_l2"]:
		_saved[id] = k.moves[id].swing
		k.moves[id].swing = _baked(k.moves[id], [StringName("Clip_" + String(id))])


func after_each() -> void:
	for id: StringName in _saved:
		Moves.KATANA.moves[id].swing = _saved[id]
	_saved.clear()
	StateClips.use(null)
	SimHelpers.dispose_all()


# ------------------------------------------------------------------ the scripted bout

## A baked swing for `move` that holds still, baked at ×1.0 from `clips`.
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


## Every clip id the old constants name, collected from OLD's values.
static func _clip_ids(v: Variant, into: Array[String]) -> void:
	if v is String or v is StringName:
		into.append(String(v))
	elif v is Array:
		for x: Variant in v:
			_clip_ids(x, into)
	elif v is Dictionary:
		for k: Variant in v:
			_clip_ids(v[k], into)


## A made-up length (s) for a clip, from its name: 24 to 46 source frames.
static func _length_of(id: String) -> float:
	var sum: int = 0
	for b: int in id.to_utf8_buffer():
		sum += b
	return float(24 + sum % 23) / 30.0


## A context with every clip the old constants name, in each set and in the
## CC0 library, and the keyed stomp's two clips.
static func _ctx(libraries: bool, fighter_id: StringName = &"hunter") -> ClipDirector.Context:
	var ids: Array[String] = []
	_clip_ids(OLD, ids)
	var lengths: Dictionary[String, float] = {}
	for id: String in ids:
		if id.begins_with("ual/"):
			lengths[id] = _length_of(id)
			continue
		lengths["ual/" + id] = _length_of(id)
		for set_name: StringName in ClipLibraries.SETS:
			lengths["%s/%s" % [set_name, id]] = _length_of(id)
	for set_name: StringName in ClipLibraries.SETS:
		for id: String in ["Clip_k_l1", "Clip_k_l2"]:
			lengths["%s/%s" % [set_name, id]] = LENGTH
	lengths["ual/Sword_Attack"] = 1.2
	lengths[KeyedClips.anim_name(&"Mikiri_Stomp")] = 26.0 / 60.0
	lengths[KeyedClips.anim_name(&"Mikiri_Pinned")] = 70.0 / 60.0
	return ClipDirector.Context.make(fighter_id, libraries, lengths)


## Where a bout's Shots are collected, by segment name, in order.
class Bout:
	var segments: Dictionary = {}
	var _at: String = ""

	## The fields of a Shot the fixture keeps, in the order of an encoded one.
	const KEYS: Array[String] = [
		"frame", "drive", "clip", "clip_before", "from", "from_upper", "upper", "fade", "since", "idle", "move",
		"state", "phase", "reverse_hold", "reverse_hold_from",
	]
	## Every this many shots one is kept, and the ones within NEAR of a change.
	const EVERY: int = 12
	const NEAR: int = 2
	## The fields that hold a Clip.
	const CLIPS: Array[String] = ["clip", "clip_before", "from"]

	static func _clip(c: ClipDirector.Clip) -> Variant:
		if c == null:
			return null
		return {"name": c.name, "time": snappedf(c.time, 1e-6), "under": _clip(c.under), "under_weight": snappedf(c.under_weight, 1e-6)}

	## Everything a Shot says that the view reads, as plain data.
	static func _shot(s: ClipDirector.Shot) -> Dictionary:
		return {
			"frame": s.frame, "drive": String(s.drive), "clip": _clip(s.clip), "clip_before": _clip(s.clip_before),
			"from": _clip(s.from), "from_upper": s.from_upper, "upper": s.upper, "fade": s.fade, "since": s.since,
			"idle": s.idle, "move": String(s.move), "state": String(s.state), "phase": String(s.phase),
			"reverse_hold": snappedf(s.reverse_hold, 1e-6), "reverse_hold_from": snappedf(s.reverse_hold_from, 1e-6),
		}

	## What shows which clip is on for a shot: a change is where this does.
	static func _key(s: Dictionary) -> String:
		return "%s|%s|%s|%s|%s|%s" % [s["drive"], s["phase"], s["state"], s["move"], s["clip"]["name"] if s["clip"] != null else "", s["fade"]]

	## A clip as a short list: [name, time], or with the one under it.
	static func encode_clip(c: Variant) -> Variant:
		if c == null:
			return null
		if c["under"] == null:
			return [c["name"], c["time"]]
		return [c["name"], c["time"], encode_clip(c["under"]), c["under_weight"]]

	static func decode_clip(c: Variant) -> Variant:
		if c == null:
			return null
		var long: bool = (c as Array).size() > 2
		return {"name": c[0], "time": c[1], "under": decode_clip(c[2]) if long else null, "under_weight": c[3] if long else 0.0}

	## A shot as a list of its KEYS' values, for the fixture.
	## (clip_before as "=" when it is the clip.)
	static func encode(s: Dictionary) -> Array:
		var out: Array = []
		for k: String in KEYS:
			if k == "clip_before" and s[k] == s["clip"]:
				out.append("=")
			else:
				out.append(encode_clip(s[k]) if k in CLIPS else s[k])
		return out

	static func decode(a: Array) -> Dictionary:
		var out: Dictionary = {}
		for i: int in KEYS.size():
			if a[i] is String and KEYS[i] == "clip_before":
				continue
			out[KEYS[i]] = decode_clip(a[i]) if KEYS[i] in CLIPS else a[i]
		if a[3] is String:
			out["clip_before"] = out["clip"]
		return out

	## Begins segment `name`.
	func into(name: String) -> void:
		_at = name
		segments[name] = []

	## Steps the director (`prev` to the fighter's next shot) and notes it.
	func step(prev: ClipDirector.Shot, f: Fighter, ctx: ClipDirector.Context) -> ClipDirector.Shot:
		var s: ClipDirector.Shot = ClipDirector.step(prev, f, ctx)
		var d: Dictionary = _shot(s)
		if not _at.begins_with("idle"):
			d["idle"] = ""  # the idle only matters where the idle is the point
		(segments[_at] as Array).append(d)
		return s

	## Thins each segment to the shots worth keeping: every frame near a
	## change of what plays (NEAR frames either side), the rest every EVERY-th,
	## and the last; answers the segments as lists of encoded shots.
	func finish() -> Dictionary:
		var out: Dictionary = {}
		for name: String in segments:
			var shots: Array = segments[name]
			var changed: Array[int] = []
			for i: int in shots.size():
				if i == 0 or _key(shots[i]) != _key(shots[i - 1]):
					changed.append(i)
			var kept: Array = []
			for i: int in shots.size():
				var keep: bool = i % EVERY == 0 or i == shots.size() - 1
				for c: int in changed:
					keep = keep or absi(c - i) <= NEAR
				if keep:
					kept.append(encode(shots[i]))
			out[name] = kept
		return out


## Pokes `f` into `state` for the next step (a frame on): `sf` frames in.
static func _poke(W: World, f: Fighter, state: StringName, sf: int = 0) -> void:
	W.frame += 1
	f.state = state
	f.sf = sf


## Plays the world on (no inputs) for `frames`, noting fighter 0's shots.
static func _run(bout: Bout, W: World, shot: ClipDirector.Shot, ctx: ClipDirector.Context, frames: int, inputs: Array[RawInput] = []) -> ClipDirector.Shot:
	for i: int in frames:
		var given: Array[RawInput] = inputs
		if given.is_empty():
			given = [SimHelpers.idle(), SimHelpers.idle()]
		W.step(given)
		shot = bout.step(shot, W.fighters[0], ctx)
	return shot


static func _weapon_name(w: WeaponDef) -> String:
	return String(w.id)


static func _idles(bout: Bout) -> void:
	for libs: bool in [true, false]:
		for w: WeaponDef in [Moves.KATANA, Moves.GREATSWORD, Moves.DAGGERS, Moves.FISTS]:
			bout.into("idle %s libs=%s" % [_weapon_name(w), libs])
			var W: World = SimHelpers.make_world(w, Moves.KATANA)
			bout.step(null, W.fighters[0], _ctx(libs))
			bout.step(null, W.fighters[0], _ctx(libs, &"rogue"))
		bout.into("idle disarmed libs=%s" % libs)
		var W2: World = SimHelpers.make_world(Moves.GREATSWORD, Moves.KATANA)
		W2.fighters[0].armed = false
		bout.step(null, W2.fighters[0], _ctx(libs))


## The crossfades: into an attack, a follow-up, back to the legs, a
## dodge-cancel and a hit's cut.
static func _fades(bout: Bout) -> void:
	for libs: bool in [true, false]:
		bout.into("fades libs=%s" % libs)
		var W: World = SimHelpers.make_world()
		var f: Fighter = W.fighters[0]
		var ctx: ClipDirector.Context = _ctx(libs)
		var shot: ClipDirector.Shot = bout.step(null, f, ctx)
		var attack: Callable = func(move: StringName, frame: int, from: StringName = &"") -> void:
			W.frame += 1
			f.state = &"attack"
			if f.atk == null or f.atk.def.id != move:
				f.atk = AttackState.new()
				f.atk.def = Moves.KATANA.moves[move]
				f.atk.chained_from = Moves.KATANA.moves[from] if from != &"" else null
			f.atk.frame = frame
		for i: int in 5:
			attack.call(&"k_l1", 1 + i)
			shot = bout.step(shot, f, ctx)
		for i: int in 6:
			attack.call(&"k_l2", 1 + i, &"k_l1" if i == 0 else &"")
			shot = bout.step(shot, f, ctx)
		for i: int in 8:
			W.frame += 1
			f.state = &"free"
			f.atk = null
			shot = bout.step(shot, f, ctx)
		attack.call(&"k_l1", 1)
		shot = bout.step(shot, f, ctx)
		attack.call(&"k_l1", 15)
		shot = bout.step(shot, f, ctx)
		for i: int in 3:
			W.frame += 1
			f.state = &"dodge"
			shot = bout.step(shot, f, ctx)
		attack.call(&"k_l1", 1)
		shot = bout.step(shot, f, ctx)
		attack.call(&"k_l1", 6)
		shot = bout.step(shot, f, ctx)
		W.frame += 1
		f.enter_hitstun(14)
		shot = bout.step(shot, f, ctx)


static func _hits(bout: Bout) -> void:
	for libs: bool in [true, false]:
		for frames: int in [14, 26, 40]:
			if not libs and frames != 26:
				continue
			bout.into("hitstun %d libs=%s" % [frames, libs])
			var W: World = SimHelpers.make_world()
			var ctx: ClipDirector.Context = _ctx(libs)
			var shot: ClipDirector.Shot = _run(bout, W, null, ctx, 3)
			# a heavy's or an ultimate's weight, kept by the rules (task 35)
			W.fighters[0].keep_impact(W.fighters[0].pos, frames > 14)
			W.fighters[0].enter_hitstun(frames)
			_run(bout, W, shot, ctx, frames + 4)


static func _guards(bout: Bout) -> void:
	for libs: bool in [true, false]:
		for w: WeaponDef in [Moves.KATANA, Moves.GREATSWORD, Moves.DAGGERS, Moves.FISTS]:
			if not libs and w != Moves.KATANA:
				continue
			bout.into("guard %s libs=%s" % [_weapon_name(w), libs])
			var W: World = SimHelpers.make_world(w, Moves.KATANA)
			var f: Fighter = W.fighters[0]
			var ctx: ClipDirector.Context = _ctx(libs)
			var shot: ClipDirector.Shot = _run(bout, W, null, ctx, 2)
			shot = _run(bout, W, shot, ctx, 14, [SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()] as Array[RawInput])
			W.frame += 1
			f.set_state(&"blockstun", 16)
			f.blocking = true
			shot = bout.step(shot, f, ctx)
			for sf: int in range(1, 18, 2):
				_poke(W, f, &"blockstun", sf)
				shot = bout.step(shot, f, ctx)
			for sf: int in range(0, 8):
				_poke(W, f, &"parryAnim", sf)
				shot = bout.step(shot, f, ctx)
			f.blocking = false
			shot = _run(bout, W, shot, ctx, 10)


static func _stuns(bout: Bout) -> void:
	for libs: bool in [true, false]:
		var cases: Array = [
			[&"stunned", SimConst.LEAP_STUN, &""], [&"stunned", ProtectedTimings.today().redirect_stun, &""],
			[&"stagger", ProtectedTimings.today().disarmed_daze, &""], [&"disarmStagger", ProtectedTimings.today().disarm_stagger, &""],
			[&"impaled", 60, &""], [&"stunned", ProtectedTimings.today().stomp_stun, &"stomp"],
		]
		for case: Array in cases:
			if not libs and not (case[1] == SimConst.LEAP_STUN or case[2] == &"stomp"):
				continue
			bout.into("stun %s %s libs=%s" % [case[0], case[2], libs])
			var W: World = SimHelpers.make_world()
			var f: Fighter = W.fighters[0]
			var ctx: ClipDirector.Context = _ctx(libs)
			var shot: ClipDirector.Shot = _run(bout, W, null, ctx, 2)
			f.enter_stun(case[1], case[0], case[2])
			var step: int = maxi(1, int(case[1]) / 12)
			for sf: int in range(0, int(case[1]) + 1, step):
				_poke(W, f, case[0], sf)
				shot = bout.step(shot, f, ctx)
			_poke(W, f, &"free")
			f.stun_cause = &""
			for i: int in 8:
				_poke(W, f, &"free")
				shot = bout.step(shot, f, ctx)


## A parried attack, with no deflect pairs in the frozen table: Stun01 from
## the start (the rebound retired with milestone-1 task 34), and the guard
## back up; a Flash's and a Redirect's stun likewise.
static func _rebounds(bout: Bout) -> void:
	for libs: bool in [true, false]:
		var cases: Array = [
			[&"recoil", SimConst.PARRY_RECOIL], [&"stunned", ProtectedTimings.today().flash_stun], [&"stunned", ProtectedTimings.today().redirect_stun],
		]
		for case: Array in cases:
			if not libs and case[1] != SimConst.PARRY_RECOIL:
				continue
			bout.into("parried %s %d libs=%s" % [case[0], case[1], libs])
			var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 6.0)
			var f: Fighter = W.fighters[0]
			var ctx: ClipDirector.Context = _ctx(libs)
			var shot: ClipDirector.Shot = _run(bout, W, null, ctx, 1, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()] as Array[RawInput])
			shot = _run(bout, W, shot, ctx, 11)
			if case[0] == &"recoil":
				f.enter_recoil(case[1], SimConst.PARRY_RECOIL_GUARD_AFTER)
			else:
				f.enter_stun(case[1])
			f.atk = null
			for sf: int in case[1] + 2:
				_poke(W, f, f.state, sf)
				f.blocking = case[0] == &"recoil" and sf > SimConst.PARRY_RECOIL_GUARD_AFTER + 4
				shot = bout.step(shot, f, ctx)


## The Greatsword onto its shoulder, standing there, then an attack or a guard
## raised from it.
static func _carry(bout: Bout) -> void:
	for libs: bool in [true, false]:
		for then: String in ["stand", "attack", "guard"]:
			if not libs and then != "stand":
				continue
			bout.into("carry %s libs=%s" % [then, libs])
			var W: World = SimHelpers.make_world(Moves.GREATSWORD, Moves.KATANA, 8.0)
			var f: Fighter = W.fighters[0]
			var ctx: ClipDirector.Context = _ctx(libs)
			var shot: ClipDirector.Shot = bout.step(null, f, ctx)
			var walked: int = 0
			while not f.shouldered and walked < 60:
				shot = _run(bout, W, shot, ctx, 1, [SimHelpers.move(0.0, 1.0), SimHelpers.idle()] as Array[RawInput])
				walked += 1
			shot = _run(bout, W, shot, ctx, 12)
			match then:
				"attack":
					shot = _run(bout, W, shot, ctx, 1, [SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()] as Array[RawInput])
					shot = _run(bout, W, shot, ctx, 14)
				"guard":
					shot = _run(bout, W, shot, ctx, 1, [SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()] as Array[RawInput])
					shot = _run(bout, W, shot, ctx, 10)


## Each ultimate through its phases, from the aim to the recovery.
static func _ults(bout: Bout) -> void:
	for libs: bool in [true, false]:
		for variant: StringName in [&"vertical", &"horizontal"]:
			if not libs and variant != &"vertical":
				continue
			bout.into("moonsplitter %s libs=%s" % [variant, libs])
			var W: World = SimHelpers.make_world()
			var f: Fighter = W.fighters[0]
			var ctx: ClipDirector.Context = _ctx(libs)
			f.state = &"ult"
			f.ult = UltState.make(&"moonsplitter", &"windup", 0, variant, 0, false)
			var shot: ClipDirector.Shot = bout.step(null, f, ctx)
			for phase: Array in [[&"windup", 36], [&"release", 34]]:
				for pf: int in range(0, phase[1] + 1, 3):
					W.frame += 1
					f.ult.phase = phase[0]
					f.ult.pf = pf
					shot = bout.step(shot, f, ctx)
		bout.into("impaler libs=%s" % libs)
		var W2: World = SimHelpers.make_world(Moves.GREATSWORD, Moves.KATANA)
		var f2: Fighter = W2.fighters[0]
		var ctx2: ClipDirector.Context = _ctx(libs)
		f2.state = &"ult"
		f2.ult = UltState.make(&"impaler", &"aim", 0, &"vertical", 0, false)
		var shot2: ClipDirector.Shot = bout.step(null, f2, ctx2)
		for phase: Array in [[&"aim", 30], [&"dash", 40], [&"impale", 20], [&"burst", 12], [&"recover", 30]]:
			for pf: int in range(0, phase[1] + 1, 3):
				W2.frame += 1
				f2.ult.phase = phase[0]
				f2.ult.pf = pf
				shot2 = bout.step(shot2, f2, ctx2)
		bout.into("tempest libs=%s" % libs)
		var W3: World = SimHelpers.make_world(Moves.DAGGERS, Moves.KATANA)
		var f3: Fighter = W3.fighters[0]
		var ctx3: ClipDirector.Context = _ctx(libs)
		f3.state = &"ult"
		f3.ult = UltState.make(&"tempest", &"flash", 0, &"vertical", 0, false)
		var shot3: ClipDirector.Shot = bout.step(null, f3, ctx3)
		var plan: Array = [[&"flash", 0, 8]]
		for spin: int in 6:
			plan.append([&"spin", spin, 10])
		plan.append_array([[&"final", 0, 14], [&"recover", 0, 24]])
		for part: Array in plan:
			for pf: int in range(0, part[2] + 1, 2):
				W3.frame += 1
				f3.ult.phase = part[0]
				f3.ult.spins = part[1]
				f3.ult.pf = pf
				shot3 = bout.step(shot3, f3, ctx3)


## The stomp counter: the defender dodges into an unblockable thrust and
## stomps it (its keyed clip), the thruster pinned in its stun (its own).
static func _stomps(bout: Bout) -> void:
	for libs: bool in [true, false]:
		bout.into("stomp libs=%s" % libs)
		var W: World = SimHelpers.make_world()
		var ctx: ClipDirector.Context = _ctx(libs)
		var shot: ClipDirector.Shot = null
		for i: int in 80:
			var a_in: RawInput = SimHelpers.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else SimHelpers.idle()
			var b_in: RawInput = SimHelpers.move(0.0, 1.0, Btn.DODGE) if i == 20 else SimHelpers.idle()
			W.step([a_in, b_in])
			shot = bout.step(shot, W.fighters[1], ctx)
		bout.into("stomped thruster libs=%s" % libs)
		var W2: World = SimHelpers.make_world()
		var f: Fighter = W2.fighters[0]
		shot = bout.step(null, f, ctx)
		f.enter_stun(ProtectedTimings.today().stomp_stun, &"stunned", &"stomp")
		for sf: int in range(0, ProtectedTimings.today().stomp_stun + 3, 5):
			_poke(W2, f, &"stunned", sf)
			shot = bout.step(shot, f, ctx)


## A knockdown through its fall, ground and stand-up, and each KO (by the
## final blow's side and weight) through its death.
static func _downs(bout: Bout) -> void:
	for libs: bool in [true, false]:
		bout.into("knockdown libs=%s" % libs)
		var W: World = SimHelpers.make_world()
		var f: Fighter = W.fighters[0]
		var ctx: ClipDirector.Context = _ctx(libs)
		var shot: ClipDirector.Shot = _run(bout, W, null, ctx, 2)
		f.enter_knockdown()
		var total: int = f.knockdown_timings().knockdown_fall + f.knockdown_timings().knockdown_ground + f.knockdown_timings().knockdown_rise
		for sf: int in range(1, total + 1):
			_poke(W, f, &"knockdown", sf)
			shot = bout.step(shot, f, ctx)
		for key: Array in [[false, false], [false, true], [true, false], [true, true]]:
			if not libs and key[0] != key[1]:
				continue
			bout.into("ko behind=%s heavy=%s libs=%s" % [key[0], key[1], libs])
			var W2: World = SimHelpers.make_world()
			var f2: Fighter = W2.fighters[0]
			var shot2: ClipDirector.Shot = _run(bout, W2, null, ctx, 2)
			f2.to_ko()
			f2.ko_from_behind = key[0]
			f2.ko_heavy = key[1]
			for sf: int in range(0, 90):
				_poke(W2, f2, &"ko", sf)
				shot2 = bout.step(shot2, f2, ctx)
			_poke(W2, f2, &"ko", 600)
			shot2 = bout.step(shot2, f2, ctx)


## The whole scripted bout: segment name to its Shots.
static func record_bout() -> Dictionary:
	var bout: Bout = Bout.new()
	_idles(bout)
	_fades(bout)
	_hits(bout)
	_guards(bout)
	_stuns(bout)
	_rebounds(bout)
	_carry(bout)
	_ults(bout)
	_stomps(bout)
	_downs(bout)
	return bout.finish()


## The fixture's text: one encoded Shot per line (Bout.KEYS), segments in order.
static func fixture_text(segments: Dictionary) -> String:
	var lines: PackedStringArray = []
	for name: String in segments:
		var shots: PackedStringArray = []
		for s: Array in segments[name]:
			shots.append("\t\t" + JSON.stringify(s))
		lines.append("\t%s: [\n%s\n\t]" % [JSON.stringify(name), ",\n".join(shots)])
	return "{\n\t\"about\": \"The ClipDirector Shots of tests/view/test_state_clips.gd's scripted bout, recorded from the clip constants before they moved to state_clips.json, thinned (see the test). Each shot is a list of Bout.KEYS. Rewrite with MONOMACHIA_RECORD_STATE_CLIPS=1.\",\n%s\n}\n" % ",\n".join(lines)


## The first place `got` differs from `want` (numbers to within 1e-8), as a
## path and what each says; empty when they match.
static func first_difference(got: Variant, want: Variant, at: String = "") -> String:
	if (got is float or got is int) and (want is float or want is int):
		return "" if absf(float(got) - float(want)) <= 1e-8 else "%s: %s, want %s" % [at, got, want]
	if got is Dictionary and want is Dictionary:
		for k: Variant in want:
			if not (got as Dictionary).has(k):
				return "%s.%s: missing" % [at, k]
			var d: String = first_difference(got[k], want[k], "%s.%s" % [at, k])
			if d != "":
				return d
		return "" if (got as Dictionary).size() == (want as Dictionary).size() else "%s: different keys" % at
	if got is Array and want is Array:
		if (got as Array).size() != (want as Array).size():
			return "%s: %d entries, want %d" % [at, (got as Array).size(), (want as Array).size()]
		for i: int in (want as Array).size():
			var d: String = first_difference(got[i], want[i], "%s[%d]" % [at, i])
			if d != "":
				return d
		return ""
	return "" if typeof(got) == typeof(want) and got == want else "%s: %s, want %s" % [at, got, want]


func test_the_scripted_bout_gives_the_recorded_shots() -> void:
	var got: Dictionary = record_bout()
	if OS.get_environment(RECORD_ENV) != "":
		var out: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
		out.store_string(fixture_text(got))
		out.close()
		pass_test("recorded %s" % FIXTURE)
		return
	var want: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert_true(want is Dictionary, "the fixture reads")
	if not want is Dictionary:
		return
	(want as Dictionary).erase("about")
	assert_eq((got.keys() as Array), (want as Dictionary).keys(), "the same segments")
	for name: String in want:
		var got_shots: Array = got.get(name, [])
		assert_eq(got_shots.size(), (want[name] as Array).size(), "%s: the same number of shots" % name)
		var d: String = ""
		for i: int in mini(got_shots.size(), (want[name] as Array).size()):
			d = first_difference(Bout.decode(got_shots[i]), Bout.decode(want[name][i]), "%s[%d]" % [name, i])
			if d != "":
				break
		assert_eq(d, "", "%s: the same shots" % name)


# ------------------------------------------------------------------ the table equals the old constants

## The StateClips field that holds each of OLD's constants.
const FIELDS: Dictionary = {
	"FADES": "fades", "IDLE": "idle", "FALLBACK_IDLE": "fallback_idle", "STATE_CLIPS": "state_clips",
	"STUN_CLIPS": "stun_clips", "HIT_CLIPS": "hit_clips", "HIT_FALLBACKS": "hit_fallbacks",
	"HEAVY_HITSTUN": "heavy_hitstun", "GUARD_CLIPS": "guard_clips", "GUARD_FALLBACK": "guard_fallback",
	"STUN_CLIP": "stun_clip", "STUN_FALLBACK": "stun_fallback", "CARRY_POSE": "carry_pose", "ULT_CLIPS": "ult_clips",
	"ULT_FALLBACK": "ult_fallback", "ULT_WINDUP": "ult_windup", "ULT_RELEASE": "ult_release",
	"IMPALER_CLIP": "impaler_clip", "IMPALER_DRAWN": "impaler_drawn", "IMPALER_OUT": "impaler_out",
	"IMPALER_RECOVER": "impaler_recover", "IMPALER_RECOVER_FRAMES": "impaler_recover_frames",
	"IMPALER_FALLBACK": "impaler_fallback", "IMPALER_AIM": "impaler_aim", "IMPALER_DASH": "impaler_dash",
	"TEMPEST_SPIN": "tempest_spin", "TEMPEST_SLASHES": "tempest_slashes", "TEMPEST_FLASH": "tempest_flash",
	"TEMPEST_FINAL": "tempest_final", "TEMPEST_FINAL_FROM": "tempest_final_from",
	"TEMPEST_FINAL_FRAMES": "tempest_final_frames", "TEMPEST_RECOVER_FRAMES": "tempest_recover_frames",
	"TEMPEST_FALLBACK": "tempest_fallback", "KNOCKDOWN_CLIPS": "knockdown_clips", "KNOCKDOWN_FALLBACKS": "knockdown_fallbacks",
	"KNOCKDOWN_STANDUP_FROM": "knockdown_standup_from", "KO_CLIPS": "ko_clips", "KO_FALLBACK": "ko_fallback",
}


func test_the_file_reads_cleanly() -> void:
	var t: StateClips = StateClips.read()
	assert_eq(Array(t.errors), [], "state_clips.json reads without errors")


func test_the_table_has_the_values_the_constants_held() -> void:
	var t: StateClips = StateClips.read(FrozenStateClips.PATH)
	assert_eq(FIELDS.size(), OLD.size(), "every old constant has a field")
	for name: String in OLD:
		var got: Variant = t.get(FIELDS[name])
		var d: String = first_difference(got, OLD[name], name)
		assert_eq(d, "", "%s -> %s" % [name, FIELDS[name]])
		# the types the code reads: whole numbers stay ints, the rest floats
		assert_eq(typeof(got), typeof(OLD[name]), "%s: the same type" % name)
	assert_eq(typeof((t.ult_clips[&"vertical"] as Array)[1]), TYPE_FLOAT, "a hold frame is a float")
	assert_eq(typeof(t.heavy_hitstun), TYPE_INT, "a frame count is an int")


func test_shared_reads_once_and_can_be_swapped() -> void:
	var first: StateClips = StateClips.shared()
	assert_same(StateClips.shared(), first, "read once, then kept")
	var swapped: StateClips = StateClips.read(FrozenStateClips.PATH)
	swapped.fades[&"attack"] = 5
	StateClips.use(swapped)
	assert_same(StateClips.shared(), swapped, "use() swaps it")
	StateClips.use(null)
	assert_ne(StateClips.shared(), swapped, "use(null) reads the file again")


func test_the_director_plays_by_the_shared_table() -> void:
	var t: StateClips = StateClips.read(FrozenStateClips.PATH)
	t.fades[&"attack"] = 5
	t.idle[&"katana"] = &"CombatIdle2H01"
	StateClips.use(t)
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var ctx: ClipDirector.Context = _ctx(true)
	var shot: ClipDirector.Shot = ClipDirector.step(null, f, ctx)
	assert_eq(shot.idle, "HumanM/CombatIdle2H01", "the idle from the table")
	W.frame += 1
	f.state = &"attack"
	f.atk = AttackState.new()
	f.atk.def = Moves.KATANA.moves[&"k_l1"]
	f.atk.frame = 1
	shot = ClipDirector.step(shot, f, ctx)
	assert_eq(shot.fade, 5, "the crossfade from the table")


# ------------------------------------------------------------------ a file with a mistake

const TEST_FILE: String = "user://state_clips_test.json"


## Reads `text` as a state-clips file.
func _read_text(text: String) -> StateClips:
	var out: FileAccess = FileAccess.open(TEST_FILE, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	return StateClips.read(TEST_FILE)


## state_clips.json's text with `from` replaced by `to` (once).
func _edited(from: String, to: String) -> String:
	var text: String = FileAccess.get_file_as_string(FrozenStateClips.PATH)
	assert_true(text.contains(from), "the file has %s" % from)
	return text.replace(from, to)


func test_an_unknown_key_is_refused() -> void:
	var cases: Dictionary = {
		"a group": [{"from": "\"fades\": {", "to": "\"extra\": {}, \"fades\": {", "says": "unknown field extra"}],
		"a field": [{"from": "\"heavy_hitstun\": 20", "to": "\"heavy_hitstun\": 20, \"heavy\": 1", "says": "hit: unknown field heavy"}],
		"an ult's field": [{"from": "\"aim\": 30", "to": "\"aim\": 30, \"spare\": 1", "says": "ults.impaler: unknown field spare"}],
		"a fade": [{"from": "\"hitstun\": 0, \"locomotion\"", "to": "\"hitstun\": 0, \"blink\": 1, \"locomotion\"", "says": "fades: unknown field blink"}],
		"a blend": [{"from": "\"hitstun\": 4, \"locomotion\"", "to": "\"hitstun\": 4, \"blink\": 1, \"locomotion\"", "says": "blends: unknown field blink"}],
	}
	for name: String in cases:
		var c: Dictionary = cases[name][0]
		var t: StateClips = _read_text(_edited(c["from"], c["to"]))
		assert_eq(Array(t.errors).size(), 1, "%s: one error: %s" % [name, t.errors])
		assert_true(t.errors.size() > 0 and String(t.errors[0]).contains(c["says"]), "%s: says %s (got %s)" % [name, c["says"], t.errors])


func test_a_missing_or_wrong_field_is_refused() -> void:
	var t: StateClips = _read_text(_edited("\"carry\": {\"pose\": \"ObjectGripShoulder02_R\"},\n", ""))
	assert_true(Array(t.errors).has("the file: missing carry"), "a missing group: %s" % t.errors)
	t = _read_text(_edited("\"standup_from\": 6", "\"standup_from\": \"six\""))
	assert_true(Array(t.errors).has("knockdown.standup_from: must be a number, 0 or more"), "a wrong type: %s" % t.errors)
	t = _read_text(_edited("\"heavy_hitstun\": 20", "\"heavy_hitstun\": 20.5"))
	assert_true(Array(t.errors).has("hit.heavy_hitstun: must be a whole number, 0 or more"), "a fractional frame count: %s" % t.errors)
	t = _read_text(_edited("\"fists\": \"Idle\"", "\"boxing\": \"Idle\""))
	assert_true(Array(t.errors).has("idle.fallbacks: needs fists"), "no bare hands: %s" % t.errors)
	t = _read_text("not json")
	assert_eq(t.errors.size(), 1, "not JSON: %s" % t.errors)
	assert_true(t.errors[0].contains("is not valid JSON"), "says so: %s" % t.errors)
	t = _read_text("[1, 2]")
	assert_eq(Array(t.errors), [TEST_FILE + " is not a JSON object"], "not an object")
	t = StateClips.read("res://assets/kevin_iglesias/no_such_state_clips.json")
	assert_eq(Array(t.errors), ["res://assets/kevin_iglesias/no_such_state_clips.json is not there"], "no file")


func test_the_clips_at_their_own_speed_are_optional_and_checked() -> void:
	# milestone-1 task 19: the families list each clip they re-key to play at
	# 1.0x, looping or handing on past its end; none yet
	var live: Dictionary[StringName, StringName] = StateClips.read().own_speed
	assert_eq(live.size(), 9, "the Katana's light reactions (task 35): %s" % live)
	assert_true(live.values().all(func(v: StringName) -> bool: return v == &"hand_on"), "each handing on")
	var t: StateClips = _read_text(_edited("\"fades\": {", "\"own_speed\": {\"Stun01\": \"loop\", \"CombatDamage01\": \"hand_on\"}, \"fades\": {"))
	assert_eq(Array(t.errors), [], "read cleanly")
	assert_eq(t.own_speed, {&"Stun01": &"loop", &"CombatDamage01": &"hand_on"} as Dictionary[StringName, StringName])
	t = _read_text(_edited("\"fades\": {", "\"own_speed\": {\"Stun01\": \"hold\"}, \"fades\": {"))
	assert_eq(Array(t.errors), ["own_speed.Stun01: must be loop or hand_on"])
	t = _read_text(_edited("\"fades\": {", "\"own_speed\": [\"Stun01\"], \"fades\": {"))
	assert_eq(Array(t.errors), ["own_speed: must be an object"])


func test_the_knockdown_and_ko_groups_are_checked() -> void:
	var t: StateClips = _read_text(_edited("\"standUp\": \"Knockdown01_StandUp\"}", "\"stand_up\": \"Knockdown01_StandUp\"}"))
	assert_true(Array(t.errors).has("knockdown.clips: needs standUp"), "a phase missing: %s" % t.errors)
	assert_true(Array(t.errors).has("knockdown.clips: unknown field stand_up") or t.errors.size() >= 1, "and noted: %s" % t.errors)
	t = _read_text(_edited("\"behind\": [\"CombatDeath03\", \"CombatDeath04\"]", "\"behind\": [\"CombatDeath03\"]"))
	assert_true(Array(t.errors).has("ko.clips.behind: must be a list of 2 clip ids"), "a death missing: %s" % t.errors)
	t = _read_text(_edited("\"fallback\": \"Death01\"", "\"fallback\": \"Death01\", \"spare\": 1"))
	assert_true(Array(t.errors).has("ko: unknown field spare"), "an unknown ko field: %s" % t.errors)


func test_the_transitions_are_optional_and_checked() -> void:
	# milestone-1 task 33: the Katana's keyed guard, the light string's
	# bridges by the move each follows, and each light's return to guard
	var live: StateClips = StateClips.read()
	assert_eq(live.idle[&"katana"], &"KatanaGuard", "the Katana's keyed guard idle")
	assert_eq(live.bridges, {&"k_l2": {&"k_l1": &"RightCutToReturnCut"}, &"k_l3": {&"k_l2": &"ReturnCutToKesaCut"},
		&"k_l4": {&"k_l3": &"KesaCutToCrownCut"}}, "a bridge for each follow-up pair of the light string")
	assert_eq(live.returns, {&"k_l1": &"RightCutToGuard", &"k_l2": &"ReturnCutToGuard", &"k_l3": &"KesaCutToGuard",
		&"k_l4": &"CrownCutToGuard"} as Dictionary[StringName, StringName], "a return for each light")
	var frozen: StateClips = StateClips.read(FrozenStateClips.PATH)
	assert_eq([frozen.bridges.size(), frozen.returns.size()], [0, 0], "none in a table without the group")
	var t: StateClips = _read_text(_edited("\"fades\": {", "\"transitions\": {\"bridges\": {\"k_l2\": {\"k_l1\": \"B\"}}, \"returns\": {\"k_l1\": \"R\"}}, \"fades\": {"))
	assert_eq(Array(t.errors), [], "read cleanly")
	assert_eq(t.bridges, {&"k_l2": {&"k_l1": &"B"}})
	assert_eq(t.returns, {&"k_l1": &"R"} as Dictionary[StringName, StringName])
	var cases: Dictionary = {
		"\"transitions\": [], ": "transitions: not an object",
		"\"transitions\": {\"bridges\": {}, \"returns\": {}, \"spare\": 1}, ": "transitions: unknown field spare",
		"\"transitions\": {\"returns\": {}}, ": "transitions: missing bridges",
		"\"transitions\": {\"bridges\": {\"k_l2\": \"B\"}, \"returns\": {}}, ": "transitions.bridges.k_l2: must be an object of clip ids by the move it follows",
		"\"transitions\": {\"bridges\": {\"k_l2\": {\"k_l1\": \"\"}}, \"returns\": {}}, ": "transitions.bridges.k_l2.k_l1: must be a clip id (a non-empty string)",
		"\"transitions\": {\"bridges\": {}, \"returns\": {\"k_l1\": 3}}, ": "transitions.returns.k_l1: must be a clip id (a non-empty string)",
	}
	for group: String in cases:
		t = _read_text(_edited("\"fades\": {", group + "\"fades\": {"))
		assert_eq(Array(t.errors), [cases[group]], group)


func test_the_deflect_pairs_are_optional_and_checked() -> void:
	# milestone-1 task 34: a deflect pair for each light, played from the
	# contact frames
	var live: StateClips = StateClips.read()
	assert_eq(live.deflect_pairs.keys(), [&"k_l1", &"k_l2", &"k_l3", &"k_l4"], "a pair for each light")
	assert_eq(live.deflect_pairs[&"k_l1"], {&"deflect": &"RightCutDeflect", &"deflect_contact": 2.0,
		&"recoil": &"RightCutRecoil", &"recoil_contact": 15.0, &"direction": &"right_to_left"})
	assert_eq(StateClips.read(FrozenStateClips.PATH).deflect_pairs.size(), 0, "none in a table without the group")
	var pair: String = "\"deflects\": {\"pairs\": {\"k_l1\": {\"direction\": \"overhead\", \"deflect\": \"D\", \"deflect_contact\": 2, \"recoil\": \"R\", \"recoil_contact\": 12.5}}}, "
	var t: StateClips = _read_text(_edited("\"fades\": {", pair + "\"fades\": {"))
	assert_eq(Array(t.errors), [], "read cleanly")
	assert_eq(t.deflect_pairs[&"k_l1"], {&"deflect": &"D", &"deflect_contact": 2.0, &"recoil": &"R", &"recoil_contact": 12.5, &"direction": &"overhead"})
	var cases: Dictionary = {
		"\"deflects\": {\"pairs\": []}, ": "deflects.pairs: must be an object",
		"\"deflects\": {\"pairs\": {\"k_l1\": {\"direction\": \"overhead\", \"deflect\": \"D\", \"deflect_contact\": 2, \"recoil\": \"R\"}}}, ": "deflects.pairs.k_l1: missing recoil_contact",
		"\"deflects\": {\"pairs\": {\"k_l1\": {\"deflect\": \"D\", \"deflect_contact\": 2, \"recoil\": \"R\", \"recoil_contact\": 3}}}, ": "deflects.pairs.k_l1: missing direction",
		"\"deflects\": {\"pairs\": {\"k_l1\": {\"direction\": \"up\", \"deflect\": \"D\", \"deflect_contact\": 2, \"recoil\": \"R\", \"recoil_contact\": 3}}}, ": "deflects.pairs.k_l1.direction: must be one of right_to_left, left_to_right, diagonal, overhead",
		"\"deflects\": {\"pairs\": {\"k_l1\": {\"direction\": \"overhead\", \"deflect\": \"D\", \"deflect_contact\": -1, \"recoil\": \"R\", \"recoil_contact\": 3}}}, ": "deflects.pairs.k_l1.deflect_contact: must be a number, 0 or more",
		"\"deflects\": {}, ": "deflects: missing pairs",
	}
	for group: String in cases:
		t = _read_text(_edited("\"fades\": {", group + "\"fades\": {"))
		assert_eq(Array(t.errors), [cases[group]], group)
