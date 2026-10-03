class_name ClipDirector
extends RefCounted
## The clip director (authored-animation task 8): which authored clips a
## fighter plays, at what times and with what weights, worked out from its
## rules state with no nodes, like HudState, so tests drive it directly.
## FighterView applies the answer (a Shot) to its model's AnimationTree
## (Locomotion's, which blends the shot's clips over the legs' blend), once
## per rules frame.
##
## step() takes the last shot, the fighter and a Context (its clip set,
## whether the Iglesias libraries are there, the clips' lengths) and gives the
## next shot. It is a pure function of them: the shot carries all it needs
## from one rules frame to the next (what drives, the crossfade's progress,
## the clip faded out). A frame the world didn't step (hit-stop, pause) gives
## the same shot, so everything holds still.
##
## What it covers so far:
## - the free state's idle, by weapon class (IDLE; FALLBACK_IDLE without the
##   packs): under the legs' blend (Shot.idle);
## - an attack whose move has a baked swing (Swing.clips): its clip, timed
##   from the attack frame on the frames the bake used (ClipTiming: the
##   wind-up across the startup, the strike across the active frames, the
##   follow-through across the recovery), entered from the attack's first
##   frame; a charge holds it where the rules hold the frame. Without the
##   packs it plays the swing's fallback stretched over the move, or nothing.
##   The Rogue plays the Hunter's set for a move whose HumanF clip strays
##   (ClipLibraries.set_for()). Moves without a baked swing keep the
##   stand-in poses: nothing drives;
## - the ultimate Moonsplitter (task 13; ult_clip()): its clip wound up and
##   held through the rules' wind-up, released as the wave goes out; and
##   Impaler (task 20): AttackPolearm01 drawn back through the aim, thrust
##   out on the dash and held through the impale, then the burst and the
##   recovery; a change of an ultimate's phase fades as a follow-up does;
## - the Greatsword's shoulder carry (task 18; carry_clip()): while the
##   fighter is shouldered, CARRY_POSE on the upper body over the legs' blend
##   (Shot.legs_free()), faded in as a stance (8 frames); an attack from the
##   shoulder fades from it into the attack's first frame over the lift
##   (AttackState.lift, 6 frames), the legs handed over with it, and a guard
##   raised from it fades back to the legs over the same lift. There is no
##   CC0 carry, so without the packs nothing shows it;
## - the Daggers' grip (task 21; Shot.grip): the reverse grip under the legs
##   and the idle, turned forward over an attack's crossfade, and back over
##   its last GRIP_BACK recovery frames when no follow-up is queued;
## - the crossfades, in rules frames (FADES): into an attack 3, a follow-up 4
##   from the last clip's pose, a dodge-cancel 2, a cut for hitstun, 6 back to
##   the legs, 8 for a stance.

## The crossfades' lengths, in rules frames.
## The Daggers turn back into the reverse grip over an attack's last this
## many recovery frames when no follow-up is queued (task 21).
const GRIP_BACK: int = 6
const FADES: Dictionary[StringName, int] = {
	&"attack": 3, &"follow_up": 4, &"dodge_cancel": 2, &"hitstun": 0, &"locomotion": 6, &"stance": 8,
}
## The free state's idle per weapon (a WeaponDef id; bare hands and a
## disarmed fighter are fists): clip-manifest ids.
const IDLE: Dictionary[StringName, StringName] = {
	&"katana": &"CombatIdle1H01", &"daggers": &"CombatIdle1H01",
	&"greatsword": &"CombatIdle2H01", &"fists": &"CombatIdle01",
}
## The idle without the packs: clips of the committed CC0 library.
const FALLBACK_IDLE: Dictionary[StringName, StringName] = {
	&"katana": &"Sword_Idle", &"daggers": &"Sword_Idle", &"greatsword": &"Sword_Idle", &"fists": &"Idle",
}
## What drives the body: the legs' blend, an authored attack clip, or the
## shoulder carry's pose on the upper body over the legs.
const LEGS: StringName = &"legs"
const ATTACK: StringName = &"attack"
const CARRY: StringName = &"carry"
## The Greatsword's shoulder carry: the right hand on the grip at the
## shoulder, the blade resting back over it (a masked pose of the Crafting
## pack; ObjectGripShoulder01_R throws the elbow out to the side).
const CARRY_POSE: StringName = &"ObjectGripShoulder02_R"
## Moonsplitter's clip per variant (clip-manifest ids) and the source frame
## it holds at through the wind-up: Attack2H01 raised overhead for the
## vertical wave, Attack2H03 wound round for the horizontal. The wind-up
## plays at 1.0 to the hold and waits there; the release plays at 2.0 from
## it, its cut landing as the rules send the wave.
const ULT_CLIPS: Dictionary[StringName, Array] = {&"vertical": [&"Attack2H01", 12.0], &"horizontal": [&"Attack2H03", 7.0]}
## Without the packs: the CC0 clip stretched over the wind-up and release.
const ULT_FALLBACK: StringName = &"Sword_Heavy_Combo"
## Moonsplitter's wind-up and release, in rules frames (Fighter._ult_moonsplitter()).
const ULT_WINDUP: int = 36
const ULT_RELEASE: int = 34
## Impaler's clip (the thrust) and the source frames it plays through
## (Fighter._ult_impaler()): drawn back to IMPALER_DRAWN at 1.0 through the
## aim and held; thrust out to IMPALER_OUT at 1.5 as the dash starts, and held
## there through the dash and the impale (the victim on the blade); the burst
## plays on at 0.5, and the recovery from IMPALER_RECOVER to the clip's end
## over its 30 frames. (The clip table's Sprint01 into AttackPolearm03 would
## swing the arms free through the dash, and Polearm03 is an overhead.)
const IMPALER_CLIP: StringName = &"AttackPolearm01"
const IMPALER_DRAWN: float = 8.0
const IMPALER_OUT: float = 14.0
const IMPALER_RECOVER: float = 18.0
const IMPALER_RECOVER_FRAMES: float = 30.0
## Without the packs: the CC0 dash stretched over the aim and the dash.
const IMPALER_FALLBACK: StringName = &"Sword_Dash"
const IMPALER_AIM: int = 30
const IMPALER_DASH: int = 40


## What a fighter is playing and from what it plays.
class Context:
	## The fighter (a FighterLook id), whose own clip set it plays.
	var fighter_id: StringName = &"hunter"
	## Whether the Iglesias clip libraries are there.
	var libraries: bool = false
	## Each animation's length (s), by its name in the tree ("HumanM/x").
	var lengths: Dictionary[String, float] = {}

	static func make(p_fighter: StringName, p_libraries: bool, p_lengths: Dictionary[String, float]) -> Context:
		var c: Context = Context.new()
		c.fighter_id = p_fighter
		c.libraries = p_libraries
		c.lengths = p_lengths
		return c


## One animation at one moment: its name in the tree and its time (s).
class Clip:
	var name: String = ""
	var time: float = 0.0
	## Inside a chain, while a part fades in (ClipChain): the part before,
	## held at its end, and how much of it still shows; else null.
	var under: Clip = null
	var under_weight: float = 0.0

	static func make(p_name: String, p_time: float) -> Clip:
		var c: Clip = Clip.new()
		c.name = p_name
		c.time = p_time
		return c


## The director's answer for one rules frame.
class Shot:
	## The world frame it is for; -1 before the first.
	var frame: int = -1
	## LEGS, ATTACK or CARRY.
	var drive: StringName = LEGS
	## The authored clip driving, at this frame and at the frame before (for
	## showing between frames); null when the legs drive.
	var clip: Clip = null
	var clip_before: Clip = null
	## What it fades in from: an authored clip held at its last pose, or null
	## for the legs' blend.
	var from: Clip = null
	## Whether `from` is the shoulder carry's pose (its legs are the legs'
	## blend's).
	var from_carry: bool = false
	## The crossfade's length and how many rules frames in it is.
	var fade: int = 0
	var since: int = 0
	## The idle under the legs' blend (a name in the tree).
	var idle: String = ""
	## The attack it plays (to tell a new attack, a follow-up, from the same).
	var attack: AttackState = null
	## The move the attack's clip came from, and the state the fighter was in.
	var move: StringName = &""
	var state: StringName = &""
	## The ultimate's phase it plays, or empty.
	var phase: StringName = &""
	## How far a pair of daggers is turned into the reverse grip (0 forward,
	## 1 reverse; FighterRig.set_reverse_turn()), and where it stood as the
	## attack began (task 21).
	var grip: float = 1.0
	var grip_from: float = 1.0

	## How far the crossfade is in (0 to 1, smoothed): the share of the new
	## drive over what it fades in from.
	func blend() -> float:
		if fade <= 0 or since >= fade:
			return 1.0
		return smoothstep(0.0, 1.0, float(since) / float(fade))

	## How much the authored clips (clip and from) show over the legs' blend.
	func authored() -> float:
		if drive != LEGS:
			return 1.0 if from != null else blend()
		return 0.0 if from == null else 1.0 - blend()

	## How much the legs are the legs' blend's under the authored clips,
	## which then show on the upper body alone (0 to 1): all of them under the
	## carry and while it fades out to the legs, handed over to an attack
	## across the lift.
	func legs_free() -> float:
		if drive == CARRY:
			return 1.0
		if from == null or not from_carry:
			return 0.0
		return 1.0 - blend() if drive == ATTACK else 1.0

	## How much of the authored clips is `clip` rather than `from`.
	func clip_share() -> float:
		if clip == null:
			return 0.0
		if from == null:
			return 1.0
		return blend()

	func copy() -> Shot:
		var s: Shot = Shot.new()
		for p: Dictionary in get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				s.set(p["name"], get(p["name"]))
		return s


## The next shot for fighter `f`, after `prev` (null at first).
static func step(prev: Shot, f: Fighter, ctx: Context) -> Shot:
	var frame: int = f.world.frame if f.world != null else 0
	if prev != null and prev.frame == frame:
		return prev
	var out: Shot = prev.copy() if prev != null else Shot.new()
	out.frame = frame
	out.idle = idle_clip(f, ctx)
	var playing: Clip = attack_clip(f, ctx, float(f.atk.frame) if f.atk != null else 0.0)
	if playing == null:
		playing = ult_clip(f, ctx)
	var drive: StringName = ATTACK if playing != null else LEGS
	var move: StringName = &""
	var phase: StringName = &""
	if playing != null:
		move = f.atk.def.id if f.atk != null else f.ult.kind
		if f.atk == null:
			phase = f.ult.phase
	else:
		playing = carry_clip(f, ctx)
		if playing != null:
			drive = CARRY
	if prev == null:
		out.drive = drive
		out.clip = playing
		out.clip_before = playing
		out.attack = f.atk if drive == ATTACK else null
		out.move = move
		out.state = f.state
		out.fade = 0
		out.since = 0
		out.from = null
		out.from_carry = false
		out.phase = phase
		out.grip_from = 1.0
		out.grip = _grip(out, f)
		return out
	var changed: bool = drive != prev.drive or (drive == ATTACK and f.atk != prev.attack) 		or (phase != &"" and prev.phase != &"" and phase != prev.phase)
	if changed:
		# what it fades in from: the authored clip shown last, held where it was
		out.from = _shown(prev)
		out.from_carry = out.from != null and out.from.name == carry_name(ctx)
		out.grip_from = prev.grip
		out.fade = _fade(prev, f, drive)
		out.since = 0
		out.clip_before = playing
	else:
		out.since = prev.since + 1
		out.clip_before = prev.clip
		if out.from != null and out.since >= out.fade:
			out.from = null
	if out.fade <= 0:
		out.from = null
	if out.from == null:
		out.from_carry = false
	out.drive = drive
	out.clip = playing
	out.attack = f.atk if drive == ATTACK else null
	out.move = move
	out.state = f.state
	out.phase = phase
	out.grip = _grip(out, f)
	return out


## How far a pair of daggers is turned into the reverse grip in shot `s`
## for `f`: all of it unless an attack drives; an attack turns it forward
## from where it stood (grip_from) over its crossfade, and back over its last
## GRIP_BACK recovery frames unless a follow-up is queued.
static func _grip(s: Shot, f: Fighter) -> float:
	if s.drive != ATTACK:
		return 1.0
	var t: float = lerpf(s.grip_from, 0.0, s.blend()) if s.fade > 0 else 0.0
	if f.atk != null and f.atk.queued == &"":
		var left: int = f.atk.def.total_frames() - f.atk.frame
		if left < GRIP_BACK:
			t = maxf(t, 1.0 - float(left) / float(GRIP_BACK))
	return t


## The shoulder carry's pose for `f` while it is shouldered (held, a pose),
## or null: not shouldered, or without the packs.
static func carry_clip(f: Fighter, ctx: Context) -> Clip:
	if not f.shouldered or not ctx.libraries:
		return null
	return Clip.make(carry_name(ctx), 0.0)


## The carry's pose as a name in the tree, in the fighter's own set.
static func carry_name(ctx: Context) -> String:
	return ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), CARRY_POSE)


## The idle under the legs' blend for `f`'s weapon class (bare hands when
## disarmed), as a name in the tree.
static func idle_clip(f: Fighter, ctx: Context) -> String:
	var wid: StringName = f.weapon.id if f.armed and f.weapon != null else &"fists"
	if ctx.libraries:
		return "%s/%s" % [ClipLibraries.FIGHTER_SETS.get(ctx.fighter_id, &"HumanM"), IDLE.get(wid, IDLE[&"fists"])]
	return "%s/%s" % [FighterModel.LIBRARY, FALLBACK_IDLE.get(wid, FALLBACK_IDLE[&"fists"])]


## The authored clip `f`'s attack plays at attack frame `t` (which may fall
## between frames), or null when nothing authored drives: not attacking, a
## move without a baked swing (or of another moveset than its own), or
## without the packs a swing with no fallback.
static func attack_clip(f: Fighter, ctx: Context, t: float) -> Clip:
	if f.state != &"attack" or f.atk == null:
		return null
	var def: AttackDef = f.atk.def
	var swing: Swing = def.swing
	if swing == null or swing.clips.is_empty() or f.moveset().moves.get(def.id) != def:
		return null
	if not ctx.libraries:
		if swing.fallback == &"":
			return null
		var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, swing.fallback]
		var share: float = clampf(t / float(maxi(1, def.total_frames())), 0.0, 1.0)
		return Clip.make(anim_name, share * ctx.lengths.get(anim_name, 0.0))
	var timing: ClipTiming = timing_of(swing)
	if timing == null:
		return null
	var set_name: StringName = ClipLibraries.set_for(ctx.fighter_id, swing)
	return chain_clip(swing.clips, set_name, timing.clip_time(t), ctx)


## Moonsplitter's clip for `f` in the ultimate's state, or null when it
## isn't playing it: the wind-up raising the blade (1.0) to the hold and
## waiting there, the release cutting from it (2.0) as the wave goes out;
## without the packs the fallback stretched over both. A Greatsword's lift
## off the shoulder waits at the clip's start.
static func ult_clip(f: Fighter, ctx: Context) -> Clip:
	if f.state != &"ult" or f.ult == null:
		return null
	if f.ult.kind == &"impaler":
		return impaler_clip(f.ult, ctx)
	if f.ult.kind != &"moonsplitter":
		return null
	var u: UltState = f.ult
	var pf: float = float(u.pf)
	if not ctx.libraries:
		var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, ULT_FALLBACK]
		var done: float = pf if u.phase == &"windup" else float(ULT_WINDUP) + pf
		return Clip.make(anim_name, clampf(done / float(ULT_WINDUP + ULT_RELEASE), 0.0, 1.0) * ctx.lengths.get(anim_name, 0.0))
	var pick: Array = ULT_CLIPS.get(u.variant, ULT_CLIPS[&"vertical"])
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), pick[0])
	var hold: float = pick[1]
	var source: float = minf(pf * 0.5, hold) if u.phase == &"windup" else hold + pf
	var length: float = ctx.lengths.get(anim_name, 0.0)
	return Clip.make(anim_name, clampf(source / float(ClipManifest.SOURCE_FPS), 0.0, length))


## Impaler's clip in ultimate state `u` (see IMPALER_CLIP); without the packs
## the fallback stretched over the aim and the dash, then held.
static func impaler_clip(u: UltState, ctx: Context) -> Clip:
	var pf: float = float(u.pf)
	if not ctx.libraries:
		var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, IMPALER_FALLBACK]
		var done: float = pf if u.phase == &"aim" else (float(IMPALER_AIM) + pf if u.phase == &"dash" else float(IMPALER_AIM + IMPALER_DASH))
		return Clip.make(anim_name, clampf(done / float(IMPALER_AIM + IMPALER_DASH), 0.0, 1.0) * ctx.lengths.get(anim_name, 0.0))
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), IMPALER_CLIP)
	var length: float = ctx.lengths.get(anim_name, 0.0)
	var source: float = IMPALER_OUT
	match u.phase:
		&"aim":
			source = minf(pf * 0.5, IMPALER_DRAWN)
		&"dash":
			source = minf(IMPALER_DRAWN + pf * 0.75, IMPALER_OUT)
		&"burst":
			source = IMPALER_OUT + pf * 0.25
		&"recover":
			var end: float = length * float(ClipManifest.SOURCE_FPS)
			source = lerpf(IMPALER_RECOVER, end, clampf(pf / IMPALER_RECOVER_FRAMES, 0.0, 1.0))
	return Clip.make(anim_name, clampf(source / float(ClipManifest.SOURCE_FPS), 0.0, length))


## The timing a baked swing was baked on (its markers and speed), or null.
static func timing_of(swing: Swing) -> ClipTiming:
	var markers: Dictionary = {}
	for i: int in mini(swing.marks.size(), ClipManifest.MARKERS.size()):
		markers[ClipManifest.MARKERS[i]] = swing.marks[i]
	if swing.marks.size() > ClipManifest.MARKERS.size():
		markers["hold"] = swing.marks[ClipManifest.MARKERS.size()]
	return ClipTiming.make(markers, swing.speed, [] as Array[String])


## The clip of chain `clips` (ClipChain entries, in set `set_name`) at
## `time` (s from the chain's start) and the time into it, with the part
## before under it while a part fades in; null when a clip is missing.
static func chain_clip(clips: Array[StringName], set_name: StringName, time: float, ctx: Context) -> Clip:
	var lengths: Dictionary = {}
	for entry: StringName in clips:
		var id: StringName = ClipChain.parse(String(entry), [] as Array[String]).id
		lengths[id] = ctx.lengths.get(ClipChain.anim_name(set_name, id), 0.0) * float(ClipManifest.SOURCE_FPS)
	var parts: Array[ClipChain.Part] = ClipChain.lay_out(clips, lengths, [] as Array[String])
	if parts.is_empty():
		return null
	var at: ClipChain.Place = ClipChain.place(parts, time * float(ClipManifest.SOURCE_FPS))
	var fps: float = float(ClipManifest.SOURCE_FPS)
	var out: Clip = Clip.make(ClipChain.anim_name(set_name, parts[at.part].id), at.frame / fps)
	if at.under >= 0:
		out.under = Clip.make(ClipChain.anim_name(set_name, parts[at.under].id), at.under_frame / fps)
		out.under_weight = at.under_weight
	return out


## What showed last as an authored clip, held at its pose: the clip when one
## drove, else the one still fading out, else null (the legs).
static func _shown(prev: Shot) -> Clip:
	if prev.clip != null and prev.clip_share() >= 0.5:
		return prev.clip
	if prev.from != null:
		return prev.from
	return prev.clip


## How long the change from `prev` to `drive` fades: into an attack 3, a
## follow-up 4, back to the legs 6; an attack cancelled into a dodge 2;
## hitstun cuts. Onto the shoulder 8 (a stance); off it into an attack or a
## guard over the lift off the shoulder.
static func _fade(prev: Shot, f: Fighter, drive: StringName) -> int:
	if f.state == &"hitstun":
		return FADES[&"hitstun"]
	if drive == CARRY:
		return FADES[&"stance"]
	if drive == ATTACK:
		if prev.drive == ATTACK and f.atk == null and prev.attack == null:
			# a change of the ultimate's phase
			return FADES[&"follow_up"]
		if prev.drive == CARRY and f.atk != null and f.atk.lift > 0:
			return f.atk.lift
		if prev.drive == CARRY and f.atk == null:
			# the ultimate from the shoulder waits out the same lift
			return SimConst.GS_SHOULDER_LIFT_FRAMES
		if prev.drive == ATTACK and f.atk != null and f.atk.chained_from != null:
			return FADES[&"follow_up"]
		return FADES[&"attack"]
	if prev.drive == CARRY and f.guard_lift_left > 0:
		return SimConst.GS_SHOULDER_LIFT_FRAMES
	if prev.drive == ATTACK and (f.state == &"dodge" or f.state == &"backstep"):
		return FADES[&"dodge_cancel"]
	return FADES[&"locomotion"]
