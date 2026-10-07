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
## - the free state's idle, by weapon class (StateClips.idle; fallback_idle without the
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
## - the light string's transitions (milestone-1 task 33; StateClips.bridges
##   and returns, with the packs): a re-keyed follow-up started from the move
##   its bridge is keyed from plays the bridge over its first frames and
##   hands on to its own clip, where that clip would be, before its active
##   frames (bridge_clip()); a light played out with no follow-up plays its
##   return to guard, whole body, while the fighter stands in the free state
##   without blocking (return_clip()). Both at 1.0x, picture only;
## - the ultimate Moonsplitter (task 13; ult_clip()): its clip wound up and
##   held through the rules' wind-up, released as the wave goes out;
##   Impaler (task 20): AttackPolearm01 drawn back through the aim, thrust
##   out on the dash and held through the impale, then the burst and the
##   recovery; and Lightning Tempest (task 23): six whole-body spinning
##   slashes, each cutting on its spin's hit, and an outward double slash
##   for the final; a change of an ultimate's phase fades as a follow-up does;
## - the Greatsword's shoulder carry (task 18; carry_clip()): while the
##   fighter is shouldered, StateClips.carry_pose on the upper body over the legs' blend
##   (Shot.legs_free()), faded in as a stance (8 frames); an attack from the
##   shoulder fades from it into the attack's first frame over the lift
##   (AttackState.lift, 6 frames), the legs handed over with it, and a guard
##   raised from it fades back to the legs over the same lift. There is no
##   CC0 carry, so without the packs nothing shows it;
## - the states with a clip of their own (StateClips.state_clips; the stomp
##   counter's hand-keyed Mikiri_Stomp and the recall's Power_Up, task 30b,
##   KeyedClips; and by cause, stun_clips,
##   the stomped thruster's Mikiri_Pinned): the clip fitted to the
##   state's length, whole body, with or without the packs (the keyed clips
##   are committed);
## - the Daggers' grip (task 21; Shot.grip): the reverse grip under the legs
##   and the idle, turned forward over an attack's crossfade, and back over
##   its last GRIP_BACK recovery frames when no follow-up is queued;
## - Shadow Step (task 22): Roll01 sped up as any baked move plays, the body
##   hidden through the blink, the active frames that carry it round the
##   opponent (blinks());
## - the reactions (task 26; reaction_of(), reaction_clip()): hitstun's
##   recoil (StateClips.hit_clips, light or heavy by the hitstun's length), a held
##   block's guard (the weapon class's Parry Loop, looped) and blockstun's
##   Parry Hit on the upper body over the legs' blend, and the long stuns'
##   Stun01 (STUN_STATES), each timed to its state (fitted_time()); without
##   the packs their CC0 fallbacks;
## - the parry (task 27; milestone-1 task 34): with the packs, each parry
##   (a block's, a Flash's or a Redirect) plays a deflect pair
##   (StateClips.deflect_pairs; pick_pair(), pair_clip()): the parried move's
##   own, or the pair of the light whose cut sweeps nearest its own
##   (sweep_of()). Both halves play whole body at 1.0x from their contact
##   frames, where the blades meet: the parried attacker (recoiling, or
##   stunned by a Flash or a Redirect) its recoil, then Stun01 over the
##   rest of a stun, faded over the fades' rebound, or the guard once the
##   recoil allows it and it blocks; the parrier its deflect, through its
##   recovery and on in the free state while it stands, to the clip's end.
##   Without the packs, or with no pair, the parrier plays its guard's
##   Parry Hit through its recovery and the attacker Stun01 from the start
##   (the rebound, its attack's clip run backwards, retired with task 34);
## - knockdown and KO (task 28; down_clip()): Knockdown01's Fall, Ground and
##   StandUp fitted to the knockdown's three phases, and the KO's death
##   (StateClips.ko_clips, by the final blow's side and weight) at 1.0, so the
##   final-blow slow motion slows it with the rules;
## - the roll and the other movement states (task 30; move_clip()): the
##   roll's Roll01, its tumble over the travel and its getting-up over the
##   recovery, the body turned toward the roll (Shot.turn; roll_turn()) and
##   back to the opponent over the recovery or a dodge attack's first
##   TURN_BACK_FRAMES; the backstep's Dodge01 lean back; jump and land; the
##   leap; the pick-up; each whole body, without the packs their CC0
##   fallbacks;
## - at its own speed (milestone-1 task 19): a move whose markers are real
##   (AttackDef.real_markers) plays its clip at 1.0 of the world's time from
##   its wind-up start, whatever its swing's speed, and hands on to the legs
##   if it outlasts the clip rather than hold its last pose; a held charge
##   plays its swing's loop (Swing.loop) at 1.0 from when it began, faded
##   into and out of as a follow-up is (phases &"swing" and &"hold"). A
##   stand-in keeps its retime until its family re-keys it. A state clip
##   StateClips.own_speed lists plays at 1.0 from its state's start, looping
##   or handing on past its end (state_time()); the rest stay fitted. Hit-stop
##   and slow motion slow every clip alike: they step the world less often,
##   and the clips go by the world's frames;
## - the hand-offs, in rules frames: since milestone-1 task 23 each shows
##   the new motion whole at once and asks for an inertial blend
##   (Shot.blend, StateClips.blends: into an attack 3, a follow-up 4 from
##   the last clip's pose, a dodge-cancel 2, hitstun 4, 6 back to the legs,
##   8 for a stance, 2 into a state's clip (the stomp springs out of the
##   dodge), 3 into a raised guard), which the rig's InertialBlend plays;
##   the crossfades' lengths (StateClips.fades, hitstun's a cut) still time
##   the dagger grip's turn and the roll's turn back.

## What the director plays by is data, in StateClips (state_clips.json, read
## through StateClips.shared()): the crossfades' lengths, the idles, the hit,
## guard and stun clips, the deflect pairs, the carry pose and the three
## ultimates' clips and timings, and the hand-keyed clips of the states with
## their own, and the knockdown's and the KO's clips. What stays here are the
## rules' states and the handful of constants that name them.

## The roll (task 30): Roll01, its tumble (source frames 0 to
## ROLL_TRAVEL_END, the stretch its root travels, which the rules' roll
## curve was read from, task 17) over the dodge's travel frames, and its
## getting-up (the rest of the clip) over the recovery, so the body and the
## ground agree (the owner's choice, Oct 4: past the 1.0-2.0 range, about
## 2.75x and 3.8x). Without the packs the CC0 Roll stretched over the dodge.
const ROLL_CLIP: StringName = &"Roll01"
const ROLL_TRAVEL_END: float = 22.0
const ROLL_FALLBACK: StringName = &"Roll"
## The body turns toward the roll over its first ROLL_TURN_FRAMES (the
## dodge-cancel's crossfade) and back to the opponent over the recovery, or
## over a dodge attack's first TURN_BACK_FRAMES.
const ROLL_TURN_FRAMES: int = 2
const TURN_BACK_FRAMES: int = 3
## The backstep (and the evade counter's back-dash, which is the backstep):
## Dodge01's lean back, its source frames 0 to BACKSTEP_LEAN_END (task 1),
## over the backstep's travel, then on from there at 2.0 through the
## recovery as it comes upright. Without the packs the CC0 Roll run
## backwards over the backstep.
const BACKSTEP_CLIP: StringName = &"Dodge01"
const BACKSTEP_LEAN_END: float = 12.0
## The jump: Jump01_Begin from JUMP_BEGIN_FROM (the crouch before it is
## skipped: the rules leave the ground on the jump's first frame) at 2.0,
## then Jump01's airborne frames from JUMP_AIR_FROM at 1.0, held at
## JUMP_AIR_TO (before its own landing); the landing Jump01_Land from its
## touch-down, JUMP_LAND_FROM, at 2.0 over the land's frames. Without the
## packs the CC0 Jump_Start, Jump and Jump_Land.
const JUMP_BEGIN: StringName = &"Jump01_Begin"
const JUMP_BEGIN_FROM: float = 5.0
const JUMP_AIR: StringName = &"Jump01"
const JUMP_AIR_FROM: float = 14.0
const JUMP_AIR_TO: float = 28.0
const JUMP_LAND: StringName = &"Jump01_Land"
const JUMP_LAND_FROM: float = 3.0
const JUMP_FALLBACKS: Dictionary[StringName, StringName] = {&"begin": &"Jump_Start", &"air": &"Jump", &"land": &"Jump_Land"}
## The leap off a sweep (32 frames: up onto the attacker's shoulders over
## LEAP_SPRING, then the arc down): Jump01_Begin from JUMP_BEGIN_FROM over the
## spring, then Fall01 looped. Without the packs NinjaJump_Start stretched
## over it.
const LEAP_SPRING: int = 10
const LEAP_FALL: StringName = &"Fall01"
const LEAP_FALLBACK: StringName = &"NinjaJump_Start"
## The pick-up (SimConst.PICKUP_FRAMES, the weapon in hand on
## SimConst.PICKUP_ATTACH_FRAME): Loot01_Begin from PICKUP_FROM at 2.0,
## reaching the ground as the weapon comes to the hand, then Loot01_Stop
## rising over the rest. Without the packs the CC0 PickUp_Table stretched
## over it.
const PICKUP_BEGIN: StringName = &"Loot01_Begin"
const PICKUP_STOP: StringName = &"Loot01_Stop"
const PICKUP_FROM: float = 4.0
const PICKUP_FALLBACK: StringName = &"PickUp_Table"

## The Daggers turn back into the reverse grip over an attack's last this
## many recovery frames when no follow-up is queued (task 21).
const GRIP_BACK: int = 6
## What drives the body: the legs' blend, an authored attack clip, the
## shoulder carry's pose on the upper body over the legs, or a state's own
## clip (StateClips.state_clips).
const LEGS: StringName = &"legs"
const ATTACK: StringName = &"attack"
const CARRY: StringName = &"carry"
const STATE: StringName = &"state"
## The long stuns (a leap's, a redirect's or a flash's stun, the disarmed
## daze, a disarm's stagger, the impaled) play Stun01's stagger into a dazed
## sway (StateClips.stun_clip); without the packs the CC0 Hit_Knockback. (The
## stomped thruster plays its keyed pin, StateClips.stun_clips.)
const STUN_STATES: Array[StringName] = [&"stunned", &"stagger", &"disarmStagger", &"impaled", &"finished"]
## The stand-in finisher's moves by finisher kind (milestone-1 task 103), until
## tasks 104 and 105 bring the finishers' own clips: the Katana's vertical Iai
## Slash and bare hands' Cross. The victim (&"finished") holds the stun.
const FINISHER_STANDINS: Dictionary[StringName, StringName] = {&"katana": &"k_iai", &"fists": &"f_l2"}
## The reactions that show on the upper body alone.
const UPPER_REACTIONS: Array[StringName] = [&"guard", &"blockstun", &"parry"]
## The states a parried attacker plays its recoil in: a block's parry
## recoils it, a Flash's or a Redirect's stuns it (task 27).
const PARRIED_STATES: Array[StringName] = [&"recoil", &"stunned"]
## How high a hit lands (m, its contact) to play a high reaction rather than
## a low one (milestone-1 task 35): a little under the chest.
const HIT_HIGH_FROM: float = 1.0
## The most a fighter moves (m/s over the ground) and still stands for a
## light's return to guard (return_clip()): Locomotion's turn threshold.
const RETURN_STILL: float = 0.1


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
	## LEGS, ATTACK, CARRY or STATE.
	var drive: StringName = LEGS
	## The authored clip driving, at this frame and at the frame before (for
	## showing between frames); null when the legs drive.
	var clip: Clip = null
	var clip_before: Clip = null
	## What it fades in from: an authored clip held at its last pose, or null
	## for the legs' blend.
	var from: Clip = null
	## Whether `from` showed on the upper body alone (the shoulder carry's
	## pose, a guard's clip): its legs are the legs' blend's.
	var from_upper: bool = false
	## Whether a state's clip shows on the upper body alone (a guard's, task
	## 26), the legs the legs' blend's.
	var upper: bool = false
	## The crossfade's length and how many rules frames in it is. Since
	## milestone-1 task 23 no clip crossfades (see blend): it times only the
	## hand-overs that aren't the pose's, the dagger grip's turn and the
	## roll's turn back.
	var fade: int = 0
	var since: int = 0
	## The inertial blend this frame's hand-off asks for (rules frames;
	## StateClips.blends), on the hand-off's frame alone; 0 on every other.
	## The view asks the rig's InertialBlend for it.
	var blend: int = 0
	## The idle under the legs' blend (a name in the tree).
	var idle: String = ""
	## The attack it plays (to tell a new attack, a follow-up, from the same).
	var attack: AttackState = null
	## The move the attack's clip came from, and the state the fighter was in.
	var move: StringName = &""
	var state: StringName = &""
	## The ultimate's phase it plays, or the reaction (reaction_of()), or
	## empty.
	var phase: StringName = &""
	## The deflect pair the parry plays (milestone-1 task 34; a
	## StateClips.deflect_pairs entry), carried through the parried state or
	## the parrier's deflect; empty for none.
	var pair: Dictionary = {}
	## How far a pair of daggers is turned into the reverse grip (0 forward,
	## 1 reverse; FighterRig.set_reverse_turn()), and where it stood as the
	## attack began (task 21).
	var grip: float = 1.0
	var grip_from: float = 1.0
	## How far the body is turned from facing the opponent (radians, + to its
	## left; the roll's, task 30), at this frame and the frame before, and
	## where it stood as a dodge attack began.
	var turn: float = 0.0
	var turn_before: float = 0.0
	var turn_from: float = 0.0

	## How far the fade is in (0 to 1, smoothed), for what still hands over
	## by it (the dagger grip's turn); poses blend inertially instead.
	func fade_in() -> float:
		if fade <= 0 or since >= fade:
			return 1.0
		return smoothstep(0.0, 1.0, float(since) / float(fade))

	## How much the authored clip shows over the legs' blend: all of it
	## from a hand-off on, the inertial blend fading what was shown before.
	func authored() -> float:
		return 0.0 if drive == LEGS else 1.0

	## How much the legs are the legs' blend's under the authored clip,
	## which then shows on the upper body alone (0 or 1): all of them under
	## the carry or a guard, none otherwise, at once from a hand-off (the
	## inertial blend fades the change).
	func legs_free() -> float:
		return 1.0 if drive == CARRY or (drive == STATE and upper) else 0.0

	## How much of the authored clips is `clip` rather than `from`: all of
	## it, from its hand-off on (milestone-1 task 23).
	func clip_share() -> float:
		return 0.0 if clip == null else 1.0

	func copy() -> Shot:
		var s: Shot = Shot.new()
		for p: Dictionary in get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				s.set(p["name"], get(p["name"]))
		return s


## The next shot for fighter `f`, after `prev` (null at first).
static func step(prev: Shot, f: Fighter, ctx: Context) -> Shot:
	var sc: StateClips = StateClips.shared()
	var frame: int = f.world.frame if f.world != null else 0
	if prev != null and prev.frame == frame:
		return prev
	var out: Shot = prev.copy() if prev != null else Shot.new()
	out.frame = frame
	out.idle = idle_clip(f, ctx)
	var playing: Clip = attack_clip(f, ctx, float(f.atk.frame) if f.atk != null else 0.0)
	out.pair = {}
	if playing == null:
		playing = finisher_clip(f, ctx)
	if playing == null:
		playing = ult_clip(f, ctx)
	var drive: StringName = ATTACK if playing != null else LEGS
	var move: StringName = &""
	var phase: StringName = &""
	if playing != null:
		move = f.atk.def.id if f.atk != null else (f.ult.kind if f.ult != null else f.state)
		if f.atk == null and f.ult != null:
			phase = f.ult.phase
			if f.ult.kind == &"tempest" and phase == &"spin":
				# each spin is a phase of its own, faded into as a follow-up
				phase = StringName("spin%d" % f.ult.spins)
		elif f.atk != null and ctx.libraries and f.atk.def.swing != null and f.atk.def.swing.loop != &"":
			# a charge's loop is a phase of the attack (task 19); a finisher's
			# stand-in (task 103) plays with no attack, so it has none
			phase = &"hold" if f.atk.charging else &"swing"
	else:
		playing = state_clip(f, ctx)
		if playing == null:
			var back: Array = return_clip(prev, f, ctx)
			if not back.is_empty():
				playing = back[0]
				move = back[1]
				phase = &"return"
		if playing == null:
			var moving: Array = move_clip(f, ctx)
			if not moving.is_empty():
				playing = moving[0]
				phase = moving[1]
		if playing == null:
			playing = down_clip(f, ctx)
			if playing != null:
				phase = f.knockdown_phase() if f.state == &"knockdown" else &"ko"
		var reaction: StringName = reaction_of(f) if playing == null else &""
		if playing == null:
			out.pair = _pair_of(prev, f, ctx)
		var half: Array = pair_clip(prev, f, ctx, out.pair)
		if not half.is_empty():
			playing = half[0]
			phase = half[1]
		elif reaction != &"":
			var held: int = prev.since + 1 if prev != null and prev.drive == STATE and prev.phase == reaction else 0
			playing = reaction_clip(f, ctx, reaction, held)
			if playing != null and not out.pair.is_empty() and PARRIED_STATES.has(f.state) and reaction != &"guard":
				# after the recoil: the stun's clip over the rest of the state
				var played: int = recoil_frames(out.pair, ctx)
				var at: float = state_time(sc.stun_clip, f.sf - played, f.state_dur - played, ctx.lengths.get(playing.name, 0.0))
				playing = null if at < 0.0 else Clip.make(playing.name, at)
			phase = reaction if playing != null else &""
		if playing != null:
			drive = STATE
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
		out.from_upper = false
		out.phase = phase
		out.upper = drive == STATE and UPPER_REACTIONS.has(phase)
		out.grip_from = 1.0
		out.grip = _grip(out, f)
		out.turn = roll_turn(f)
		out.turn_before = out.turn
		out.turn_from = 0.0
		return out
	var changed: bool = drive != prev.drive or (drive == ATTACK and f.atk != prev.attack) 		or (phase != &"" and prev.phase != &"" and phase != prev.phase)
	if changed:
		# what it fades in from: the authored clip shown last, held where it was
		out.from = _shown(prev)
		if out.from != null and out.from == prev.from:
			out.from_upper = prev.from_upper
		else:
			out.from_upper = out.from != null and (prev.drive == CARRY or (prev.drive == STATE and prev.upper))
		out.grip_from = prev.grip
		out.fade = _fade(prev, f, drive, sc.fades)
		out.blend = _fade(prev, f, drive, sc.blends)
		if phase == &"recoil" or phase == &"deflect":
			# a deflect pair cuts in: its halves meet at the contact frame
			# (the recoil carries on from the attack's own pose there)
			out.fade = 0
			out.blend = 0
		out.since = 0
		out.clip_before = playing
	else:
		out.blend = 0
		out.since = prev.since + 1
		out.clip_before = prev.clip
		if out.from != null and out.since >= out.fade:
			out.from = null
	if out.fade <= 0:
		out.from = null
	if out.from == null:
		out.from_upper = false
	out.drive = drive
	out.upper = drive == STATE and UPPER_REACTIONS.has(phase)
	out.clip = playing
	out.attack = f.atk if drive == ATTACK else null
	out.move = move
	out.state = f.state
	out.phase = phase
	out.grip = _grip(out, f)
	out.turn_before = prev.turn
	if drive == ATTACK and f.atk != null and changed and prev.state == &"dodge":
		# a dodge attack turns back to the opponent from where the roll stood
		out.turn_from = prev.turn
	elif changed or drive != ATTACK:
		out.turn_from = 0.0
	out.turn = roll_turn(f)
	if drive == ATTACK and f.atk != null and out.turn_from != 0.0:
		out.turn = out.turn_from * (1.0 - smoothstep(0.0, 1.0, float(f.atk.frame) / float(TURN_BACK_FRAMES)))
	return out


## The clip of `f`'s state when it has one of its own (StateClips.state_clips), fitted
## to the state's length; null otherwise, or when the clip isn't in the
## tree. Keyed clips are committed, so it plays without the packs too.
static func state_clip(f: Fighter, ctx: Context) -> Clip:
	var sc: StateClips = StateClips.shared()
	var id: StringName = sc.state_clips.get(f.state, &"")
	if id == &"" and f.state == &"stunned":
		id = sc.stun_clips.get(f.stun_cause, &"")
	if id == &"":
		return null
	var anim_name: String = KeyedClips.anim_name(id)
	var length: float = ctx.lengths.get(anim_name, 0.0)
	if length <= 0.0:
		return null
	if sc.own_speed.has(id):
		var at: float = state_time(id, f.sf, f.state_dur, length)
		return null if at < 0.0 else Clip.make(anim_name, at)
	var share: float = clampf(float(f.sf) / float(maxi(1, f.state_dur)), 0.0, 1.0)
	return Clip.make(anim_name, share * length)


## How far fighter `f`'s body is turned toward its roll (radians, + to its
## left; task 30): in a roll (not the backstep), the roll's way from the way
## it faces, turned in over ROLL_TURN_FRAMES and back over the recovery; 0
## otherwise.
static func roll_turn(f: Fighter) -> float:
	if f.state != &"dodge" or f.dodge == null:
		return 0.0
	var dg: DodgeState = f.dodge
	var way: float = wrapf(atan2(dg.dir_x, dg.dir_z) - f.yaw, -PI, PI)
	var sf: float = float(f.sf)
	var share: float = smoothstep(0.0, 1.0, sf / float(ROLL_TURN_FRAMES))
	if f.sf > dg.frames:
		share = 1.0 - smoothstep(0.0, 1.0, (sf - float(dg.frames)) / float(maxi(1, dg.recovery)))
	return way * share


## The clip of `f`'s movement state (task 30) and its phase, as
## [Clip, phase], or [] when it isn't in one or the clip isn't in the tree:
## the roll, the backstep, the jump (its take-off, then in the air), the
## land, the leap (its spring, then the fall) and the pick-up (its reach,
## then the rise). Without the packs, each fallback stretched over its
## state (looped in the air).
static func move_clip(f: Fighter, ctx: Context) -> Array:
	var src: float = float(ClipManifest.SOURCE_FPS)
	var fps: float = float(SimConst.FPS)
	var sf: float = float(f.sf)
	var id: StringName = &""
	var fallback: StringName = &""
	var phase: StringName = f.state
	# the time (source frames) with the packs; without, the share of the
	# fallback (or < 0 to loop it)
	var source: float = 0.0
	var share: float = 0.0
	match f.state:
		&"dodge":
			if f.dodge == null:
				return []
			var travel: float = float(f.dodge.frames)
			id = ROLL_CLIP
			fallback = ROLL_FALLBACK
			share = sf / (travel + float(f.dodge.recovery))
			if sf <= travel:
				source = ROLL_TRAVEL_END * sf / travel
			else:
				var end: float = _length(ctx, ROLL_CLIP) * src
				source = lerpf(ROLL_TRAVEL_END, end, (sf - travel) / float(maxi(1, f.dodge.recovery)))
		&"backstep":
			if f.dodge == null:
				return []
			var travel: float = float(f.dodge.frames)
			id = BACKSTEP_CLIP
			fallback = ROLL_FALLBACK
			share = 1.0 - sf / (travel + float(f.dodge.recovery))
			source = BACKSTEP_LEAN_END * minf(1.0, sf / travel) + maxf(0.0, sf - travel) * 2.0 * src / fps
		&"jump":
			var begin_frames: float = maxf(1.0, (_length(ctx, JUMP_BEGIN) * src - JUMP_BEGIN_FROM) * fps / (2.0 * src))
			if not ctx.libraries:
				begin_frames = 8.0
			if sf < begin_frames:
				id = JUMP_BEGIN
				fallback = JUMP_FALLBACKS[&"begin"]
				phase = &"jump_begin"
				source = JUMP_BEGIN_FROM + sf * 2.0 * src / fps
				share = sf / begin_frames
			else:
				id = JUMP_AIR
				fallback = JUMP_FALLBACKS[&"air"]
				phase = &"jump_air"
				source = minf(JUMP_AIR_TO, JUMP_AIR_FROM + (sf - begin_frames) * src / fps)
				share = -1.0
		&"land":
			if f.blocking:
				return []
			id = JUMP_LAND
			fallback = JUMP_FALLBACKS[&"land"]
			source = JUMP_LAND_FROM + sf * 2.0 * src / fps
			share = sf / float(maxi(1, f.state_dur))
		&"leap":
			id = JUMP_BEGIN
			fallback = LEAP_FALLBACK
			phase = &"leap_spring"
			source = JUMP_BEGIN_FROM + sf * 2.0 * src / fps
			share = sf / float(maxi(1, f.state_dur))
			if sf >= float(LEAP_SPRING) and ctx.libraries:
				id = LEAP_FALL
				phase = &"leap_fall"
				source = fmod((sf - float(LEAP_SPRING)) * src / fps, maxf(1.0, _length(ctx, LEAP_FALL) * src))
		&"pickup":
			var grab: int = SimConst.PICKUP_ATTACH_FRAME
			id = PICKUP_BEGIN
			fallback = PICKUP_FALLBACK
			source = PICKUP_FROM + sf * 2.0 * src / fps
			share = sf / float(maxi(1, f.state_dur))
			if f.sf > grab and ctx.libraries:
				id = PICKUP_STOP
				phase = &"pickup_rise"
				var at: float = state_time(PICKUP_STOP, f.sf - grab, maxi(1, f.state_dur - grab), _length(ctx, PICKUP_STOP))
				if at < 0.0:
					return []
				source = at * src
		_:
			return []
	var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, fallback]
	if ctx.libraries:
		anim_name = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), id)
	var length: float = ctx.lengths.get(anim_name, 0.0)
	if length <= 0.0:
		return []
	if not ctx.libraries:
		var at: float = clampf(share, 0.0, 1.0) * length if share >= 0.0 else fmod(sf / fps, length)
		return [Clip.make(anim_name, at), phase]
	return [Clip.make(anim_name, clampf(source / src, 0.0, length)), phase]


## Clip `id`'s length (s) in the fighter's own set, or 0.
static func _length(ctx: Context, id: StringName) -> float:
	return ctx.lengths.get(ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), id), 0.0)


## The reaction `f`'s state plays (task 26): &"guard" (a held block, in a
## guard state), &"blockstun", &"hitstun" or &"stun" (STUN_STATES), or
## (task 27) &"parry" (the parrier's recovery) and the parried attacker's
## recoil (&"stun", or &"guard" once it blocks again); empty for none.
static func reaction_of(f: Fighter) -> StringName:
	if f.state == &"hitstun":
		return &"hitstun"
	if f.state == &"parryAnim":
		return &"parry"
	if f.state == &"recoil":
		# the guard back up once the recoil allows it
		return &"guard" if f.blocking else &"stun"
	if f.state == &"blockstun":
		return &"blockstun"
	if STUN_STATES.has(f.state):
		return &"stun"
	if f.blocking and (f.state == &"free" or f.state == &"step" or f.state == &"land"):
		return &"guard"
	return &""


## The clip of `f`'s reaction (reaction_of()), as a name in the tree and a
## time, or null when it isn't in the tree: the guard's Parry Loop looped
## from when the guard went up (`held` rules frames ago) at 1.0; the others
## timed to their state (fitted_time()). Without the packs, the fallbacks.
static func reaction_clip(f: Fighter, ctx: Context, reaction: StringName, held: int) -> Clip:
	var sc: StateClips = StateClips.shared()
	var wid: StringName = f.weapon.id if f.armed and f.weapon != null else &"fists"
	var guard: Array = sc.guard_clips.get(wid, sc.guard_clips[&"fists"])
	var id: StringName = &""
	var fallback: StringName = &""
	match reaction:
		&"guard":
			id = guard[0]
			fallback = sc.guard_fallback
		&"blockstun", &"parry":
			id = guard[1]
			fallback = sc.guard_fallback
			if reaction == &"blockstun" and not f.impact_heavy and ctx.libraries and sc.light_blocks.has(wid):
				# a light block's own reaction (milestone-1 task 35)
				id = sc.light_blocks[wid]
		&"hitstun":
			var heavy: int = 1 if f.impact_heavy else 0
			id = sc.hit_clips[heavy]
			fallback = sc.hit_fallbacks[heavy]
			if not f.impact_heavy and ctx.libraries and sc.light_hits.has(wid):
				# a light hit's reaction for where it landed (milestone-1 task 35)
				id = sc.light_hits[wid][hit_place(f)]
		&"stun":
			id = sc.stun_clip
			fallback = sc.stun_fallback
		_:
			return null
	var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, fallback]
	if ctx.libraries:
		anim_name = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), id)
	var length: float = ctx.lengths.get(anim_name, 0.0)
	if length <= 0.0:
		return null
	if reaction == &"guard":
		return Clip.make(anim_name, fmod(float(held) / float(SimConst.FPS), length))
	var at: float = state_time(id if ctx.libraries else fallback, f.sf, f.state_dur, length)
	return null if at < 0.0 else Clip.make(anim_name, at)


## Where `f`'s last hit landed on it (Fighter.impact_pos; milestone-1 task
## 35), as a StateClips.HIT_PLACES key: the side by the contact's bearing from
## the fighter (front or back within 45 degrees of its facing, else left or
## right), high from HIT_HIGH_FROM up.
static func hit_place(f: Fighter) -> StringName:
	var ahead_v: V2 = SimMath.fwd(f.yaw)
	var right_v: V2 = SimMath.right(f.yaw)
	var dx: float = f.impact_pos.x - f.pos.x
	var dz: float = f.impact_pos.z - f.pos.z
	var ahead: float = dx * ahead_v.x + dz * ahead_v.z
	var right: float = dx * right_v.x + dz * right_v.z
	var side: String = "front"
	if -ahead > absf(right):
		side = "back"
	elif absf(right) > absf(ahead):
		side = "right" if right > 0.0 else "left"
	return StringName("%s_%s" % [side, "high" if f.impact_pos.y >= HIT_HIGH_FROM else "low"])


## The time (s) into a clip `length` s long, `frame` rules frames into a
## state `frames` long: played from its start at the speed (1.0 to 2.0)
## that ends it with the state, or as near as that range allows; a state
## longer than the clip at 1.0 holds its last pose, and one shorter than it
## at 2.0 hands back before its end (the fade out to the legs takes it from
## where it stands).
static func fitted_time(frame: int, frames: int, length: float) -> float:
	var speed: float = clampf(length * float(SimConst.FPS) / float(maxi(1, frames)), ClipTiming.MIN_SPEED, ClipTiming.MAX_SPEED)
	return minf(float(frame) * speed / float(SimConst.FPS), length)


## The time (s) into state clip `id` (`length` s long), `frame` rules frames
## into a state `frames` long (milestone-1 task 19): a clip StateClips.own_speed
## lists plays at 1.0 from the state's start, looping past its end, or giving
## -1 there to hand on (never held or stretched); any other is fitted
## (fitted_time()).
static func state_time(id: StringName, frame: int, frames: int, length: float) -> float:
	var end: StringName = StateClips.shared().own_speed.get(id, &"")
	if end == &"":
		return fitted_time(frame, frames, length)
	var t: float = float(frame) / float(SimConst.FPS)
	if end == &"loop":
		return fmod(t, length) if length > 0.0 else 0.0
	return t if t <= length else -1.0


## The clip of a knocked-down or knocked-out `f` (task 28), as a name in
## the tree and a time, or null: not down, or the clip isn't in the tree.
static func down_clip(f: Fighter, ctx: Context) -> Clip:
	var sc: StateClips = StateClips.shared()
	var id: StringName = &""
	var fallback: StringName = &""
	var phase: StringName = f.knockdown_phase()
	if f.state == &"ko":
		id = sc.ko_clips[1 if f.ko_from_behind else 0][1 if f.ko_heavy else 0]
		fallback = sc.ko_fallback
	elif phase != &"":
		id = sc.knockdown_clips[phase]
		fallback = sc.knockdown_fallbacks[phase]
	else:
		return null
	var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, fallback]
	if ctx.libraries:
		anim_name = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), id)
	var length: float = ctx.lengths.get(anim_name, 0.0)
	if length <= 0.0:
		return null
	var fps: float = float(SimConst.FPS)
	var kd: ProtectedTimings = f.knockdown_timings()
	var fall: int = kd.knockdown_fall
	var ground: int = kd.knockdown_ground
	match phase:
		&"fall":
			var at: float = state_time(id if ctx.libraries else fallback, f.sf, fall, length)
			return null if at < 0.0 else Clip.make(anim_name, at)
		&"ground":
			if not ctx.libraries:
				return Clip.make(anim_name, 0.0)
			return Clip.make(anim_name, fmod(float(f.sf - fall) / fps, length))
		&"standUp":
			var from: float = sc.knockdown_standup_from / float(ClipManifest.SOURCE_FPS) if ctx.libraries else 0.0
			var up: float = state_time(id if ctx.libraries else fallback, f.sf - fall - ground, kd.knockdown_rise, length - from)
			return null if up < 0.0 else Clip.make(anim_name, from + up)
	return Clip.make(anim_name, minf(float(f.sf) / fps, length))


## The deflect pair `f` plays (milestone-1 task 34), or empty: with the
## packs, picked (pick_pair()) as a parried attacker's state begins straight
## from its attack (stunned by a parry, not a stomp) or as the parrier's
## recovery begins, and carried through that state (and the parrier's into
## the free state while its deflect plays).
static func _pair_of(prev: Shot, f: Fighter, ctx: Context) -> Dictionary:
	if not ctx.libraries or f.parry_move == &"" or prev == null:
		return {}
	var parried: bool = PARRIED_STATES.has(f.state) and f.stun_cause == &""
	if not prev.pair.is_empty() and (prev.state == f.state or (prev.phase == &"deflect" and f.state == &"free")):
		return prev.pair
	if (parried and prev.state == &"attack" and prev.drive == ATTACK) or (f.state == &"parryAnim" and prev.state != &"parryAnim"):
		return pick_pair(f)
	return {}


## The deflect pair (a StateClips.deflect_pairs entry) for `f`'s last parry
## (Fighter.parry_move): the parried move's own, or the pair of the light
## whose cut sweeps nearest the parried blade's (Fighter.parry_sweep against
## sweep_of() each paired light); empty with no pairs.
static func pick_pair(f: Fighter) -> Dictionary:
	var pairs: Dictionary[StringName, Dictionary] = StateClips.shared().deflect_pairs
	if pairs.has(f.parry_move):
		return pairs[f.parry_move]
	var best: StringName = &""
	var nearest: float = -INF
	for move: StringName in pairs:
		var d: float = V3.dot(f.parry_sweep, sweep_of(move))
		if d > nearest:
			nearest = d
			best = move
	return pairs.get(best, {})


## Which way move `move`'s blade sweeps as it lands (milestone-1 task 34):
## its baked swing's blade tip from its last startup frame to its first
## active one, a unit vector in the fighter's own frame (right, up,
## forward), as Fighter.parry_sweep is kept; zero for a move without a
## right-hand swing.
static func sweep_of(move: StringName) -> V3:
	for w: WeaponDef in Moves.WEAPONS.values():
		var def: AttackDef = w.moves.get(move)
		if def == null or def.swing == null or not def.swing.parts().has(&"right_hand"):
			continue
		var segment: StrikeSegment = Swing.strike_segment(&"right_hand", w)
		if segment == null:
			continue
		var d: V3 = V3.sub(def.swing.tick(&"right_hand", def.startup + 1).place(segment.tip),
			def.swing.tick(&"right_hand", def.startup).place(segment.tip))
		return V3.normalized(d) if V3.length(d) > 1e-9 else V3.make()
	return V3.make()


## `f`'s half of deflect pair `pair` as [clip, phase], or empty: the parried
## attacker's recoil (&"recoil"), until the guard is back up; the parrier's
## deflect (&"deflect"), through its recovery and on while it stands in the
## free state. Each at 1.0x from its contact frame, from the frame the pair
## was picked, never picked up again once it has handed on.
static func pair_clip(prev: Shot, f: Fighter, ctx: Context, pair: Dictionary) -> Array:
	if pair.is_empty():
		return []
	var recoil: bool = PARRIED_STATES.has(f.state)
	var phase: StringName = &"recoil" if recoil else &"deflect"
	if recoil and f.blocking:
		return []
	if not recoil and (f.state != &"parryAnim" and f.state != &"free" or Vector2(f.vel.x, f.vel.z).length() > RETURN_STILL):
		return []
	var since: int = 0
	if prev != null and prev.phase == phase:
		since = prev.since + 1
	elif prev != null and not prev.pair.is_empty():
		return []
	var id: StringName = pair[&"recoil" if recoil else &"deflect"]
	var contact: float = float(pair[&"recoil_contact" if recoil else &"deflect_contact"])
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), id)
	var at: float = contact / float(ClipManifest.SOURCE_FPS) + float(since) / float(SimConst.FPS)
	if at >= ctx.lengths.get(anim_name, 0.0) - 1e-9:
		return []
	return [Clip.make(anim_name, at), phase]


## How many rules frames `pair`'s recoil plays, from its contact frame to its
## end at 1.0x.
static func recoil_frames(pair: Dictionary, ctx: Context) -> int:
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), pair[&"recoil"])
	var left: float = ctx.lengths.get(anim_name, 0.0) - float(pair[&"recoil_contact"]) / float(ClipManifest.SOURCE_FPS)
	return maxi(0, roundi(left * float(SimConst.FPS)))


## Whether `f` is in Shadow Step's blink (task 22): its active frames,
## which carry it round to the opponent's back (Fighter._update_shadow_step())
## with its body hidden.
static func blinks(f: Fighter) -> bool:
	if f.state != &"attack" or f.atk == null or f.atk.def.special != &"shadowStep":
		return false
	var def: AttackDef = f.atk.def
	return f.atk.frame > def.startup and f.atk.frame <= def.startup + def.active


## How far a pair of daggers is turned into the reverse grip in shot `s`
## for `f`: all of it unless an attack drives; an attack turns it forward
## from where it stood (grip_from) over its crossfade, and back over its last
## GRIP_BACK recovery frames unless a follow-up is queued.
static func _grip(s: Shot, f: Fighter) -> float:
	if s.drive != ATTACK:
		return 1.0
	var t: float = lerpf(s.grip_from, 0.0, s.fade_in()) if s.fade > 0 else 0.0
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
	return ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), StateClips.shared().carry_pose)


## The idle under the legs' blend for `f`'s weapon class (bare hands when
## disarmed), as a name in the tree.
static func idle_clip(f: Fighter, ctx: Context) -> String:
	var sc: StateClips = StateClips.shared()
	var wid: StringName = f.weapon.id if f.armed and f.weapon != null else &"fists"
	if ctx.libraries:
		return "%s/%s" % [ClipLibraries.FIGHTER_SETS.get(ctx.fighter_id, &"HumanM"), sc.idle.get(wid, sc.idle[&"fists"])]
	return "%s/%s" % [FighterModel.LIBRARY, sc.fallback_idle.get(wid, sc.fallback_idle[&"fists"])]


## The authored clip `f`'s attack plays at attack frame `t` (which may fall
## between frames), or null when nothing authored drives: not attacking, a
## move without a baked swing (or of another moveset than its own), or
## without the packs a swing with no fallback.
static func attack_clip(f: Fighter, ctx: Context, t: float) -> Clip:
	if f.state != &"attack" or f.atk == null:
		return null
	var bridge: Clip = bridge_clip(f, ctx, t)
	if bridge != null:
		return bridge
	return _move_clip(f, f.atk.def, ctx, t)


## The bridge `f`'s follow-up plays at its frame `t` (milestone-1 task 33),
## or null: with the packs, a re-keyed follow-up that has a bridge from the
## move it follows (StateClips.bridges) plays it at 1.0x from its first
## frame, and hands on to its own clip where the bridge ends, the pose the
## bridge ends in and the time its own clip would be at. Picture only.
static func bridge_clip(f: Fighter, ctx: Context, t: float) -> Clip:
	var def: AttackDef = f.atk.def
	if not ctx.libraries or f.atk.chained_from == null or not def.real_markers or def.swing == null \
			or f.moveset().moves.get(def.id) != def:
		return null
	var id: StringName = (StateClips.shared().bridges.get(def.id, {}) as Dictionary).get(f.atk.chained_from.id, &"")
	if id == &"":
		return null
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id, def.swing), id)
	var at: float = t / float(SimConst.FPS)
	if at >= ctx.lengths.get(anim_name, 0.0) - 1e-9:
		return null
	return Clip.make(anim_name, at)


## `f`'s return to guard (milestone-1 task 33) as [clip, move], or empty:
## with the packs, a move with a return (StateClips.returns) played out to
## its recovery (`prev` the attack's last shot) hands on to it in the free
## state, at 1.0x from its start, while the fighter stands (RETURN_STILL)
## and doesn't block; it ends, for good, at its end or once either changes.
static func return_clip(prev: Shot, f: Fighter, ctx: Context) -> Array:
	if prev == null or not ctx.libraries or f.state != &"free" or f.blocking \
			or Vector2(f.vel.x, f.vel.z).length() > RETURN_STILL:
		return []
	var move: StringName = &""
	var since: int = 0
	if prev.drive == STATE and prev.phase == &"return":
		move = prev.move
		since = prev.since + 1
	elif prev.drive == ATTACK and prev.attack != null and prev.attack.frame >= prev.attack.def.startup + prev.attack.def.active:
		move = prev.attack.def.id
	var id: StringName = StateClips.shared().returns.get(move, &"")
	if id == &"":
		return []
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), id)
	var at: float = float(since) / float(SimConst.FPS)
	if at >= ctx.lengths.get(anim_name, 0.0) - 1e-9:
		return []
	return [Clip.make(anim_name, at), move]


## The stand-in finisher's clip (FINISHER_STANDINS) for the finisher `f`, or
## null: its move played over the finisher's frames so its last active frame
## lands at the kill, then held.
static func finisher_clip(f: Fighter, ctx: Context) -> Clip:
	if f.state != &"finisher" or f.world == null:
		return null
	var def: AttackDef = f.moveset().moves.get(FINISHER_STANDINS.get(f.world.finisher_kind, &""), null)
	if def == null:
		return null
	var strike: float = float(def.startup + def.active)
	var t: float = minf(float(def.total_frames()), float(f.world.finisher_frame) * strike / float(SimConst.FINISHER_KILL_FRAME))
	return _move_clip(f, def, ctx, t)


## Move `def`'s clip for `f` at its frame `t` (attack_clip()).
static func _move_clip(f: Fighter, def: AttackDef, ctx: Context, t: float) -> Clip:
	var swing: Swing = def.swing
	if swing == null or swing.clips.is_empty() or f.moveset().moves.get(def.id) != def:
		return null
	if not ctx.libraries:
		if swing.fallback == &"":
			return null
		var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, swing.fallback]
		var share: float = clampf(t / float(maxi(1, def.total_frames())), 0.0, 1.0)
		return Clip.make(anim_name, share * ctx.lengths.get(anim_name, 0.0))
	var set_name: StringName = ClipLibraries.set_for(ctx.fighter_id, swing)
	if swing.loop != &"" and f.atk.charging:
		# a held charge plays its loop at 1.0 from when it began (task 19)
		var loop: Array[StringName] = [swing.loop]
		var length: float = chain_length(loop, set_name, ctx)
		var held: float = float(f.atk.charge_frames) / float(SimConst.FPS)
		return chain_clip(loop, set_name, fmod(held, length) if length > 0.0 else 0.0, ctx)
	if def.real_markers and not swing.marks.is_empty():
		# its own speed: 1.0 from the wind-up start, handing on past the end
		var at: float = swing.marks[0] / float(ClipManifest.SOURCE_FPS) + t / float(SimConst.FPS)
		if at > chain_length(swing.clips, set_name, ctx):
			return null
		return chain_clip(swing.clips, set_name, at, ctx)
	var timing: ClipTiming = timing_of(swing)
	if timing == null:
		return null
	return chain_clip(swing.clips, set_name, timing.clip_time(t), ctx)


## Moonsplitter's clip for `f` in the ultimate's state, or null when it
## isn't playing it: the wind-up raising the blade (1.0) to the hold and
## waiting there, the release cutting from it (2.0) as the wave goes out;
## without the packs the fallback stretched over both. A Greatsword's lift
## off the shoulder waits at the clip's start.
static func ult_clip(f: Fighter, ctx: Context) -> Clip:
	var sc: StateClips = StateClips.shared()
	if f.state != &"ult" or f.ult == null:
		return null
	if f.ult.kind == &"impaler":
		return impaler_clip(f.ult, ctx)
	if f.ult.kind == &"tempest":
		return tempest_clip(f.ult, ctx)
	if f.ult.kind != &"moonsplitter":
		return null
	var u: UltState = f.ult
	var pf: float = float(u.pf)
	if not ctx.libraries:
		var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, sc.ult_fallback]
		var done: float = pf if u.phase == &"windup" else float(sc.ult_windup) + pf
		return Clip.make(anim_name, clampf(done / float(sc.ult_windup + sc.ult_release), 0.0, 1.0) * ctx.lengths.get(anim_name, 0.0))
	var pick: Array = sc.ult_clips.get(u.variant, sc.ult_clips[&"vertical"])
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), pick[0])
	var hold: float = pick[1]
	var source: float = minf(pf * 0.5, hold) if u.phase == &"windup" else hold + pf
	var length: float = ctx.lengths.get(anim_name, 0.0)
	return Clip.make(anim_name, clampf(source / float(ClipManifest.SOURCE_FPS), 0.0, length))


## Impaler's clip in ultimate state `u` (see StateClips.impaler_clip); without the packs
## the fallback stretched over the aim and the dash, then held.
static func impaler_clip(u: UltState, ctx: Context) -> Clip:
	var sc: StateClips = StateClips.shared()
	var pf: float = float(u.pf)
	if not ctx.libraries:
		var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, sc.impaler_fallback]
		var done: float = pf if u.phase == &"aim" else (float(sc.impaler_aim) + pf if u.phase == &"dash" else float(sc.impaler_aim + sc.impaler_dash))
		return Clip.make(anim_name, clampf(done / float(sc.impaler_aim + sc.impaler_dash), 0.0, 1.0) * ctx.lengths.get(anim_name, 0.0))
	var anim_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), sc.impaler_clip)
	var length: float = ctx.lengths.get(anim_name, 0.0)
	var source: float = sc.impaler_out
	match u.phase:
		&"aim":
			source = minf(pf * 0.5, sc.impaler_drawn)
		&"dash":
			source = minf(sc.impaler_drawn + pf * 0.75, sc.impaler_out)
		&"burst":
			source = sc.impaler_out + pf * 0.25
		&"recover":
			var end: float = length * float(ClipManifest.SOURCE_FPS)
			source = lerpf(sc.impaler_recover, end, clampf(pf / sc.impaler_recover_frames, 0.0, 1.0))
	return Clip.make(anim_name, clampf(source / float(ClipManifest.SOURCE_FPS), 0.0, length))


## Lightning Tempest's clip in ultimate state `u` (see StateClips.tempest_spin).
static func tempest_clip(u: UltState, ctx: Context) -> Clip:
	var sc: StateClips = StateClips.shared()
	var pf: float = float(u.pf)
	var fps: float = float(ClipManifest.SOURCE_FPS)
	if u.phase == &"flash" or u.phase == &"spin":
		var source: float = sc.tempest_slashes[0] * minf(1.0, pf / float(sc.tempest_flash))
		if u.phase == &"spin":
			var start: float = sc.tempest_slashes[u.spins % sc.tempest_slashes.size()]
			source = start + minf(pf, 10.0)
		var spin_name: String = String(sc.tempest_spin)
		return Clip.make(spin_name, clampf(source / fps, 0.0, ctx.lengths.get(spin_name, 0.0)))
	var done: float = pf if u.phase == &"final" else float(sc.tempest_final_frames) + pf
	if not ctx.libraries:
		var anim_name: String = "%s/%s" % [FighterModel.LIBRARY, sc.tempest_fallback]
		var share: float = clampf(done / float(sc.tempest_final_frames + sc.tempest_recover_frames), 0.0, 1.0)
		return Clip.make(anim_name, share * ctx.lengths.get(anim_name, 0.0))
	var final_name: String = ClipChain.anim_name(ClipLibraries.set_for(ctx.fighter_id), sc.tempest_final)
	var length: float = ctx.lengths.get(final_name, 0.0)
	var cut_end: float = sc.tempest_final_from + float(sc.tempest_final_frames) * 0.75
	var source: float = sc.tempest_final_from + pf * 0.75
	if u.phase == &"recover":
		source = lerpf(cut_end, length * fps, clampf(pf / float(sc.tempest_recover_frames), 0.0, 1.0))
	return Clip.make(final_name, clampf(source / fps, 0.0, length))


## The timing a baked swing was baked on (its markers and speed), or null.
static func timing_of(swing: Swing) -> ClipTiming:
	var markers: Dictionary = {}
	for i: int in mini(swing.marks.size(), ClipManifest.MARKERS.size()):
		markers[ClipManifest.MARKERS[i]] = swing.marks[i]
	if swing.marks.size() > ClipManifest.MARKERS.size():
		markers["hold"] = swing.marks[ClipManifest.MARKERS.size()]
	return ClipTiming.make(markers, swing.speed, [] as Array[String])


## The length (s) of chain `clips` (ClipChain entries, in set `set_name`),
## or 0 when a clip is missing.
static func chain_length(clips: Array[StringName], set_name: StringName, ctx: Context) -> float:
	var lengths: Dictionary = {}
	for entry: StringName in clips:
		var id: StringName = ClipChain.parse(String(entry), [] as Array[String]).id
		lengths[id] = ctx.lengths.get(ClipChain.anim_name(set_name, id), 0.0) * float(ClipManifest.SOURCE_FPS)
	var parts: Array[ClipChain.Part] = ClipChain.lay_out(clips, lengths, [] as Array[String])
	return ClipChain.length_of(parts) / float(ClipManifest.SOURCE_FPS) if not parts.is_empty() else 0.0


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
## drove, else null (the legs).
static func _shown(prev: Shot) -> Clip:
	# no crossfade since milestone-1 task 23: the clip shown is the clip
	return prev.clip


## How long the change from `prev` to `drive` takes, from `lengths` by what
## changes (StateClips.fades or StateClips.blends): into an attack 3, a
## follow-up 4, back to the legs 6; an attack cancelled into a dodge 2;
## hitstun a cut's 0 or a 4-frame blend. Onto the shoulder 8 (a stance); off
## it into an attack or a guard over the lift off the shoulder.
static func _fade(prev: Shot, f: Fighter, drive: StringName, lengths: Dictionary[StringName, int]) -> int:
	if f.state == &"hitstun":
		return lengths[&"hitstun"]
	if drive == CARRY:
		return lengths[&"stance"]
	if prev.drive == CARRY and f.guard_lift_left > 0:
		# a guard raised from the shoulder, over the lift off it
		return SimConst.GS_SHOULDER_LIFT_FRAMES
	if drive == STATE:
		if prev.phase == &"recoil":
			# the recoil handing on to the stun (the key's name the rebound's,
			# which it replaced)
			return lengths[&"rebound"]
		if f.blocking and f.state != &"blockstun" and f.state != &"parryAnim":
			return lengths[&"guard"]
		return lengths[&"state"]
	if drive == ATTACK:
		if prev.drive == ATTACK and f.atk != null and f.atk == prev.attack:
			# a phase of the same attack: into or out of a charge's loop
			return lengths[&"follow_up"]
		if prev.drive == ATTACK and f.atk == null and prev.attack == null:
			# a change of the ultimate's phase
			return lengths[&"follow_up"]
		if prev.drive == CARRY and f.atk != null and f.atk.lift > 0:
			return f.atk.lift
		if prev.drive == CARRY and f.atk == null:
			# the ultimate from the shoulder waits out the same lift
			return SimConst.GS_SHOULDER_LIFT_FRAMES
		if prev.drive == ATTACK and f.atk != null and f.atk.chained_from != null:
			return lengths[&"follow_up"]
		return lengths[&"attack"]
	if prev.drive == CARRY and f.guard_lift_left > 0:
		return SimConst.GS_SHOULDER_LIFT_FRAMES
	if prev.drive == ATTACK and (f.state == &"dodge" or f.state == &"backstep"):
		return lengths[&"dodge_cancel"]
	return lengths[&"locomotion"]
