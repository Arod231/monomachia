class_name FighterView
extends Node3D
## A side's fighter in the match: its FighterModel in the side's palette,
## holding the side's weapon models. MatchView places it every frame from the
## host's blended position and yaw (update_from()) and poses it from the
## rules' state; it never changes the rules.
##
## A move with a swing (task 7) plays from it (SwingPlayer, plan task 14.10):
## the weapon goes exactly where the rules' swing has it at the frame shown,
## the arms reach for it on IK, and the stand-in's lean, crouch and spin are
## left out, since the swing's body comes from its own keys. A weapon with
## swings stands in their guard, and a change of what poses the weapons (a
## swing starting, a follow-up, a swing ending) blends over a few frames
## (14.11). The swing's body keys turn the hips, the chest and the head, the
## hips leading, and move and dip the pelvis, taking over from the guard
## stance's (14.12). Every other pose comes from StickPose, the stand-in posing from
## the rules' state:
## - its hands and blade directions become the weapons' poses in fighter
##   space, and the rig's IK puts the arms on them (the off hand on a
##   two-handed weapon's second grip). StickPose's keys were made for a stick
##   figure with long arms, so a pose out of reach is pulled in until the
##   elbows bend (REACH). A blade's edge faces the way the move's strike
##   sweeps it, or down and forward in a guard;
## - its lean bends the spine, its crouch drops the hips over feet the leg IK
##   keeps where the clip has them, and its spin turns the whole body;
## - under it all, the legs walk, run and sprint in the packs' directional
##   clips by the rules' velocity (Locomotion, authored-animation task 29),
##   over the director's combat idle at rest, all on the rules' clock, so
##   they hold still through hit-stop and pause; a sprint held backwards turns
##   the whole body away (Locomotion.shown_away);
## - a knocked-down or knocked-out fighter plays the director's clips
##   (task 28: Knockdown01's phases, the KO's death), the legs off IK and
##   unlocked so they go with the fall; only with no clip in the tree for it
##   does it fall the old way, with DEATH_CLIP from the KO, or with
##   KNOCKDOWN_FALL_CLIP and KNOCKDOWN_RISE_CLIP fitted to the phases;
## - a disarmed fighter holds nothing, its arms on the clip.
##
## The clip director (ClipDirector, authored-animation task 8) picks the
## authored clips on each rules frame, and the legs' tree plays them over its
## blend (Locomotion.set_authored()):
## - the free state's idle is its weapon class's combat idle (the CC0
##   fallback's without the packs), under the legs' blend;
## - a state with a clip of its own (the stomp's hand-keyed Mikiri_Stomp)
##   plays it whole body, the weapon fixed in the clip's hand, the stand-in's
##   crouch and lean giving way as it fades in;
## - an attack whose move has a baked swing plays its clip, timed from the
##   attack frame, the crossfades the director's. Its reach correction
##   (Swing.reach_at()) moves the whole body above the hips, the planted feet
##   held, so an arm at full stretch still holds the weapon. The Hunter holds
##   the weapon fixed in the clip's hand, which the shift carries onto the
##   baked path; the Rogue, and either fighter on the fallback clips, has the
##   weapon posed on the baked path (SwingPlayer) and her hands pulled onto
##   it by IK. The swing's own body keys stand aside;
## - planted feet are held where they landed under every clip (FootLock),
##   the legs' walks and runs too, unless the fighter is down.
## Moves without a baked swing keep the stand-in poses below.
##
## A roll turns the whole body toward the way it rolls (ClipDirector.Shot.turn,
## task 30), and back to the opponent over the recovery.
##
## Shadow Step's blink (ClipDirector.blinks()) hides the model and its floor
## marks.
##
## A body flash (hit, disarm, KO) and a blade's glow (an unblockable winding
## up, a charging heavy, an ultimate) are material overlays, timed on the
## rules' frames: the toon materials underneath are left alone. A floor ring
## in the side's colour and a soft shadow keep the fighter readable from any
## camera.
##
## The model is built once per fighter and kept across rematches and
## restarts; a new palette or weapon goes on the same model.

## How much of a body flash fades per world frame (the demo faded 6 per
## second).
const FLASH_FADE_PER_FRAME: float = 0.1
## The most a body flash tints the fighter.
const FLASH_MAX: float = 0.6
## How dark a knocked-out fighter goes: a black overlay this strong.
const KO_DIM: float = 0.45
const GLOW_COLORS: Dictionary[StringName, Color] = {
	&"danger": Color(1.0, 0.16, 0.08),
	&"charge": Color(1.0, 0.85, 0.55),
	&"ult": Color(1.0, 0.75, 0.2),
}
## The clip a knocked-out fighter falls with.
const DEATH_CLIP: StringName = &"Death01"
## Frames the legs take to pass between a held clip and the legs walking
## under it (_legs_free()).
const LEGS_RAMP: float = 4.0
## The stand-in clips a knocked-down fighter falls and rises with (the clip
## table's fallback) until task 28 brings the knockdown clips.
const KNOCKDOWN_FALL_CLIP: StringName = &"Hit_Knockback"
const KNOCKDOWN_RISE_CLIP: StringName = &"LayToIdle"
## The furthest a stand-in pose may stretch an arm, as a share of its length
## from the shoulder to the wrist: the elbows stay bent.
const REACH: float = 0.96
## The way a blade's edge faces in a guard, or in a move that doesn't sweep
## it sideways (a thrust): down and forward, made square to the blade.
const GUARD_EDGE: Vector3 = Vector3(0.0, -1.0, 0.5)

var fighter_id: StringName = &""
var palette: int = 0
## The side's weapon (a WeaponDef id) at the start of the match.
var weapon_id: StringName = &""
var side: int = 0
var model: FighterModel
## The legs: the model's locomotion tree.
var locomotion: Locomotion
## The last pose applied, for tests and debugging.
var last_pose: StickPose.Pose
## Plays swings, and blends the weapons between what poses them.
var swing_player: SwingPlayer = SwingPlayer.new()
## The clip director's last answer (null before the first frame), what it
## plays from, and the foot lock under the clips.
var shot: ClipDirector.Shot = null
## Whether the inertial blend under way hands off from an authored clip
## (an attack's or a state's), whose pose already carries its body: the swing
## player's body then stays off until it ends (milestone-1 task 23).
var _blend_from_clip: bool = false
var director: ClipDirector.Context
var foot_lock: FootLock
## The world the shot and the foot lock are for: a new one starts them afresh.
var _shot_world: World = null

var _floor: Node3D
var _ring_mat: StandardMaterial3D
## The body flash or KO dimming over every mesh of the model, and the glow
## over every mesh of the held weapons; each on only while it shows.
var _body_overlay: StandardMaterial3D
var _glow_overlay: StandardMaterial3D
var _body_meshes: Array[MeshInstance3D] = []
var _weapon_meshes: Array[MeshInstance3D] = []
var _body_lit: bool = false
var _weapon_lit: bool = false
## The body flash: its strength when lit, the world frame it was lit on, and
## its colour. Timed on the rules' frames, not the wall clock, so it holds
## through hit-stop and a screenshot stepped without rendering doesn't carry
## stale flashes.
var _flash_strength: float = 0.0
var _flash_frame: int = 0
var _flash_color: Color = Color.WHITE


## Sets the fighter, palette and weapon for a match. The model is built only
## when the fighter changes.
func setup(p_fighter: StringName, p_palette: int, p_weapon: StringName, p_side: int) -> void:
	if _floor == null:
		_build_floor()
	if model == null or p_fighter != fighter_id:
		_build_model(p_fighter)
	fighter_id = p_fighter
	palette = p_palette
	weapon_id = p_weapon
	side = p_side
	model.apply_palette(p_palette)
	_ring_mat.albedo_color = side_color().lightened(0.2)
	_hold(p_weapon)
	shot = null
	foot_lock.clear()
	_flash_strength = 0.0
	_light_body(Color(0.0, 0.0, 0.0, 0.0))
	_light_weapons(Color.BLACK)


## Holds another weapon (the training dummy's swap), keeping everything else.
func set_weapon(p_weapon: StringName) -> void:
	weapon_id = p_weapon
	_hold(p_weapon)


func side_color() -> Color:
	return LookPalette.side_color(palette)


## Briefly lights the body (a hit) from the world frame `frame` on. A weaker
## flash than what is left of the current one doesn't replace it.
func flash(color: Color, strength: float, frame: int) -> void:
	if strength >= flash_left(frame):
		_flash_strength = strength
		_flash_frame = frame
	_flash_color = color


## Pushes the body's physical reaction layer (milestone-1 task 70): a blow
## landing at `contact`, driven from `from` (both in the match's space; the
## push goes level, from `from` toward `contact`), this `strength`
## (PhysicalReactionLayer.strength()), reaching `parts` with `arms` of the
## arms' share, at world frame `at`. Picture only.
func react(contact: Vector3, from: Vector3, strength: float, parts: int, arms: float, at: float) -> void:
	if model == null:
		return
	var drive: Vector3 = Vector3(contact.x - from.x, 0.0, contact.z - from.z)
	if drive.length() < 1e-4:
		return
	var to_skeleton: Transform3D = _skeleton_frame().affine_inverse()
	model.rig.reaction.push(at, to_skeleton * contact, to_skeleton.basis * drive, strength, parts, arms)


## The skeleton's frame in the match's space, as last placed.
func _skeleton_frame() -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = model.skeleton
	while n != null and n != self:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return transform * xf


## What is left of the body flash at a world frame.
func flash_left(frame: int) -> float:
	return maxf(0.0, _flash_strength - FLASH_FADE_PER_FRAME * float(maxi(0, frame - _flash_frame)))


## Places and poses the fighter for this frame: pos and yaw from
## MatchHost.display_position() and display_yaw(), alpha from
## MatchHost.alpha(), time in seconds for StickPose's idle motion.
func update_from(f: Fighter, pos: Vector3, yaw: float, alpha: float, _delta: float, time: float) -> void:
	if model == null:
		return
	position = pos
	rotation = Vector3(0.0, yaw, 0.0)
	var p: StickPose.Pose = StickPose.compute(f, alpha, time)
	last_pose = p
	_hold(StickPose.weapon_key(f))
	var frame: int = f.world.frame if f.world != null else _flash_frame
	var seconds: float = (float(frame) + alpha) / float(SimConst.FPS)
	if f.world != _shot_world:
		shot = null
		foot_lock.clear()
		model.rig.inertial.clear()
		model.rig.reaction.clear()
		_shot_world = f.world
	var before: ClipDirector.Shot = shot
	shot = ClipDirector.step(shot, f, director)
	# a hand-off asks the rig for its inertial blend (milestone-1 task 23),
	# which runs on the world's time, as the clips do
	var inertial: InertialBlend = model.rig.inertial
	inertial.time = float(frame) - 1.0 + alpha
	# and the physical reaction layer on the same time (milestone-1 task 70)
	model.rig.reaction.time = inertial.time
	if shot != before and shot.blend > 0:
		inertial.request(shot.blend)
		_blend_from_clip = before != null and (before.drive == ClipDirector.ATTACK or before.drive == ClipDirector.STATE)
	var down: bool = f.state == &"ko" or f.state == &"knockdown"
	if down and shot.drive != ClipDirector.STATE:
		# no clip in the tree for it (task 28's come through the director):
		# the stand-in fall
		model.rig.foot_lock = null
		foot_lock.clear()
		if f.state == &"ko":
			_fall(maxf(0.0, float(f.sf) - 1.0 + alpha))
		else:
			_knocked_down(maxf(0.0, float(f.sf) - 1.0 + alpha), f.knockdown_timings())
	else:
		_show_authored(f, alpha)
		locomotion.update(f, StringName(shot.idle), seconds, alpha)
		_pose(f, p, seconds, alpha)
		if down:
			# the legs go with the fall: no footfalls carry over
			locomotion.footfalls.clear()
	# the floor marks stay on the floor while the fighter jumps
	_floor.position = Vector3(0.0, -pos.y + 0.006, 0.0)
	# Shadow Step's blink hides the fighter and its floor marks (task 22)
	var shown: bool = not ClipDirector.blinks(f)
	model.visible = shown
	_floor.visible = shown
	var lit: float = flash_left(frame)
	if lit > 0.0:
		_light_body(Color(_flash_color, minf(FLASH_MAX, lit)))
	elif f.state == &"ko":
		_light_body(Color(0.0, 0.0, 0.0, KO_DIM))
	else:
		_light_body(Color(0.0, 0.0, 0.0, 0.0))
	var glow: Color = Color.BLACK
	if GLOW_COLORS.has(p.glow) and p.glow_amount > 0.0:
		glow = GLOW_COLORS[p.glow] * p.glow_amount
	_light_weapons(glow)


## How much `f`'s weapon is pinned under its stomper's foot (0 to 1): a
## thruster stunned by a stomp, over the stun's first frames
## (KeyedClips.pin_weight()).
static func _pin(f: Fighter, alpha: float) -> float:
	if f.state != &"stunned" or f.stun_cause != &"stomp" or f.opp == null or not f.armed:
		return 0.0
	return KeyedClips.pin_weight(maxf(0.0, float(f.sf) - 1.0 + alpha))


## Where the stomper's foot presses `f`'s blade, in `f`'s fighter space.
static func pin_point(f: Fighter) -> Vector3:
	var o: Fighter = f.opp
	var foot: Vector3 = KeyedClips.STOMP_FOOT.rotated(Vector3.UP, o.yaw) + Vector3(o.pos.x, 0.0, o.pos.z)
	return (foot - Vector3(f.pos.x, 0.0, f.pos.z)).rotated(Vector3.UP, -f.yaw)


## The stomped thruster's weapon `pin` of the way from where the clip's
## hand holds it to pinned: its tip under the stomper's foot, its grip back
## along the line to the clip's hand, the hands reaching it on IK (the off
## hand of a two-handed weapon on its OffHandGrip). A pair's other dagger
## stays in its hand.
func _pin_weapons(f: Fighter, pin: float) -> void:
	var rig: FighterRig = model.rig
	var sk: Skeleton3D = model.skeleton
	var held: Dictionary[int, Transform3D] = {}
	for i: int in model.weapons.size():
		var side: String = "Right" if i == 0 else "Left"
		held[i] = sk.get_bone_global_pose(sk.find_bone(side + "Hand")) * rig.fixed_grip(side)
	var tip: Vector3 = pin_point(f)
	# the blade's tip marker (off the grip's axis on a curved blade) onto the pin
	var marker: Vector3 = WeaponLook.blade_segment(model.weapons[0])[1]
	var back: Vector3 = held[0].origin - tip
	if back.length() < 0.001:
		back = Vector3.UP
	var basis: Basis = FighterRig.weapon_frame(Vector3.ZERO, -back, edge_for(-back, Vector3.ZERO)).basis
	basis = Basis(Quaternion((basis * marker).normalized(), -back.normalized())) * basis
	var pinned: Transform3D = Transform3D(basis, tip - basis * marker)
	var shown: Transform3D = held[0].interpolate_with(pinned, pin)
	model.pose_weapon(0, shown)
	for i: int in range(1, model.weapons.size()):
		model.pose_weapon(i, held[i])


## Each held weapon's blade in world space, as posed this frame: [BladeBase,
## BladeTip] for the right hand's weapon, then the left's (a pair of
## daggers). Empty with no model or nothing held. The trails read it.
func blade_segments() -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if model == null:
		return out
	for w: Node3D in model.weapons:
		if not w.is_inside_tree():
			continue
		var seg: PackedVector3Array = WeaponLook.blade_segment(w)
		var xf: Transform3D = w.global_transform
		out.append(PackedVector3Array([xf * seg[0], xf * seg[1]]))
	return out


## How far back from the tip the held weapon's blade trails (its
## WeaponLook.trail_width), or 0 with nothing held.
func trail_width() -> float:
	return model.weapon_look.trail_width if model != null and model.weapon_look != null else 0.0


## The way a blade's edge faces: the way the strike sweeps the blade's tip
## (`sweep`), made square to the blade, or GUARD_EDGE when the strike
## doesn't sweep it sideways (a thrust, or no strike).
static func edge_for(blade: Vector3, sweep: Vector3) -> Vector3:
	var y: Vector3 = blade.normalized()
	var lead: Vector3 = sweep - y * sweep.dot(y)
	if lead.length() > 0.05 and lead.length() > 0.25 * sweep.length():
		return lead.normalized()
	var guard: Vector3 = GUARD_EDGE - y * GUARD_EDGE.dot(y)
	if guard.length() > 0.1:
		return guard.normalized()
	return Vector3(0.0, 0.0, 1.0) - y * y.z


# ------------------------------------------------------------------ posing

## Hands the director's clips to the legs' tree: the driving clip shown
## alpha of the way from the frame before (held while charging, but for a
## charge's loop, unless it just came round), over the clip it fades in from.
func _show_authored(f: Fighter, alpha: float) -> void:
	var a: String = ""
	var a_time: float = 0.0
	if shot.clip != null:
		a = shot.clip.name
		a_time = shot.clip.time
		var before: ClipDirector.Clip = shot.clip_before
		var looping: bool = shot.phase == &"hold"
		var held: bool = f.atk != null and f.atk.charging and not looping
		if before != null and before.name == a and not held and not (looping and before.time > a_time):
			a_time = lerpf(before.time, a_time, alpha)
	var b: String = shot.from.name if shot.from != null else ""
	var b_time: float = shot.from.time if shot.from != null else 0.0
	var share: float = shot.clip_share()
	if shot.from == null and shot.clip != null and shot.clip.under != null:
		# a chain's part fading in from the one before (ClipChain)
		b = shot.clip.under.name
		b_time = shot.clip.under.time
		share = 1.0 - shot.clip.under_weight
	locomotion.set_authored(a, a_time, b, b_time, share, shot.authored(), _legs_free(f))


## How much the legs are the legs' blend's under the authored clips, which
## then show on the upper body alone: under the Greatsword's shoulder carry
## as the director says (Shot.legs_free(), task 18), and under a charging
## attack's held clip (the Iai's stance, stood and walked in at the blocking
## walk's speed; task 11) all of them through the charge, handed over
## LEGS_RAMP frames each way, as it starts and once it is let go.
func _legs_free(f: Fighter) -> float:
	var carried: float = shot.legs_free() if shot != null else 0.0
	if f.state != &"attack" or f.atk == null or f.atk.charge_frames <= 0:
		return carried
	if f.atk.charging:
		return clampf(float(f.atk.charge_frames) / LEGS_RAMP, 0.0, 1.0)
	return clampf(1.0 - float(f.atk.frame - Fighter.CHARGE_CHECK_FRAME) / LEGS_RAMP, 0.0, 1.0)


## True when an authored clip drives the arms and the weapon rides the
## clip's hand (see the class notes): a state's own clip (the stomp's keyed
## clip, which has no weapon path; with or without the packs), or the
## Iglesias clips are there, and
## either the paths were baked on him (the Hunter) or there is no baked
## weapon path to pose it on (a pose-only swing like Flash's, the ultimate,
## task 13, or the shoulder carry, task 18), for the Rogue too.
func _fixed_on_clip(f: Fighter) -> bool:
	if shot != null and shot.drive == ClipDirector.STATE:
		return true
	if shot == null or shot.drive == ClipDirector.LEGS or not director.libraries:
		return false
	if fighter_id == &"hunter":
		return true
	var swing: Swing = _playing_swing(f)
	return swing == null or not swing.parts().has(&"right_hand")


## The baked swing of the attack `f` plays, or null (not attacking, a move
## without one, the ultimate).
static func _playing_swing(f: Fighter) -> Swing:
	return f.atk.def.swing if f.state == &"attack" and f.atk != null else null


## Poses the body and the weapons, `seconds` into the rules' clock, `alpha`
## of the way from the step before to the last.
func _pose(f: Fighter, p: StickPose.Pose, _seconds: float, alpha: float) -> void:
	var rig: FighterRig = model.rig
	var swung: bool = SwingPlayer.plays(f) and not model.weapons.is_empty()
	var authored: float = shot.authored() if shot != null else 0.0
	var driving: bool = shot != null and (shot.drive == ClipDirector.ATTACK or shot.drive == ClipDirector.STATE)
	# a state's own clip crouches and leans itself: the stand-in's give way
	# as it fades in
	var own: float = 1.0 - authored if shot != null and shot.drive == ClipDirector.STATE else 1.0
	var lean: float = 0.0 if swung else p.lean * own
	var crouch: float = 0.0 if swung else p.crouch * own
	var spin: float = 0.0 if swung else p.spin
	# down (task 28), the legs go with the clip's fall, off IK
	var down: bool = f.state == &"ko" or f.state == &"knockdown"
	rig.leg_weight = 0.0 if down else 1.0
	rig.clear_pole_tweaks()
	rig.body.clear()
	rig.body.spine_pitch = lean
	rig.body.hips_offset = Vector3(0.0, -crouch, 0.0)
	# a swing's body (its coil, shift and dip)
	var swing_body: SwingPlayer.Body = swing_player.body(f, alpha)
	if driving or (_blend_from_clip and rig.inertial.active and rig.inertial.blending()):
		# the clip turns the body itself, and while the blend away from it
		# runs, what is left of its pose does
		swing_body.weight = 0.0
	swing_body.apply(rig.body)
	rig.clip_feet = 1.0
	# a sprint held backwards turns the whole body away (task 29), and a roll
	# toward the way it rolls (task 30)
	var turn: float = lerp_angle(shot.turn_before, shot.turn, alpha) if shot != null else 0.0
	model.rotation = Vector3(0.0, spin + locomotion.shown_away + turn, 0.0)
	# planted feet held where they landed under every clip, the legs' too
	rig.foot_lock = foot_lock
	rig.rules_frame = f.world.frame if f.world != null else 0
	foot_lock.enabled = not down
	var playing: Swing = _playing_swing(f) if driving else null
	if playing != null:
		# the reach correction carries the body above the hips, and the arms
		# and weapon with it
		rig.body.hips_offset += SwingPlayer.to_skeleton(playing.reach_at(SwingPlayer.swing_frame(f, alpha)))
	# the blade in the saya through the Iai's sheathe and stance (task 11)
	rig.sheathed = playing != null and playing.is_sheathed(float(f.atk.frame))
	if model.weapons.is_empty():
		return
	if _fixed_on_clip(f) and _pin(f, alpha) > 0.0:
		_pin_weapons(f, _pin(f, alpha))
		return
	if _fixed_on_clip(f):
		# the weapon rides the clip's hand
		if not rig.is_fixed():
			model.fix_weapons()
		# a pair of daggers flips between the idle's reverse grip and the
		# attack's forward one (task 21)
		rig.set_reverse_turn(shot.grip if model.weapon_look.paired else 0.0)
		var held: Dictionary[int, Transform3D] = {}
		for i: int in model.weapons.size():
			held[i] = model.weapons[i].transform
		swing_player.show(f, alpha, held)
		return
	var swing_poses: Dictionary[int, Transform3D] = {}
	if swung:
		swing_poses = SwingPlayer.weapon_poses(f, alpha, model.weapons.size(), rig)
	elif p.phase == &"guard":
		# a weapon with swings stands in their guard, riding as the stand-in's
		swing_poses = SwingPlayer.guard_poses(f.moveset(), model.weapons.size())
	var sweeps: Array[Vector3] = _strike_sweeps(f)
	var hands: Array[StickPose.Hand] = [p.right, p.left]
	var poses: Dictionary[int, Transform3D] = {}
	for i: int in model.weapons.size():
		if swing_poses.has(i):
			poses[i] = swing_poses[i]
			continue
		var hand: StickPose.Hand = hands[i]
		var xf: Transform3D = FighterRig.weapon_frame(hand.pos, hand.dir, edge_for(hand.dir, sweeps[i]))
		poses[i] = _within_reach(i, xf, rig.body)
	# a change of what poses the weapons blends rather than jumps
	var shown: Dictionary[int, Transform3D] = swing_player.show(f, alpha, poses)
	for i: int in shown:
		model.pose_weapon(i, shown[i])


## How each hand's blade tip moves from the attack's wind-up to its impact
## (right, then left), or nothing outside an attack.
func _strike_sweeps(f: Fighter) -> Array[Vector3]:
	if f.state != &"attack" or f.atk == null:
		return [Vector3.ZERO, Vector3.ZERO]
	var wid: StringName = StickPose.weapon_key(f)
	var keys: Array[Dictionary] = StickPose.attack_keys(f.atk.def, wid)
	var length: float = StickPose.LENGTH.get(wid, 0.9)
	var out: Array[Vector3] = []
	for hand_name: String in ["right", "left"]:
		var from: StickPose.Hand = keys[0][hand_name]
		var to: StickPose.Hand = keys[1][hand_name]
		out.append((to.pos + to.dir * length) - (from.pos + from.dir * length))
	return out


## Pulls a weapon pose in toward the shoulders until every hand that grips
## it can reach its grip within REACH of its arm. The shoulders and chest
## are the clip's, moved as the body layer will move them
## (BodyLayer.upper_body()): the hips turned and dropped, the spine turned
## and bent.
func _within_reach(index: int, xf: Transform3D, body: BodyLayer) -> Transform3D:
	var rig: FighterRig = model.rig
	var grips: Dictionary[String, Vector3] = rig.grips_on(index)
	var upper: Transform3D = body.upper_body(model.skeleton)
	var chest: Basis = (upper * _clip_pose("UpperChest")).basis.orthonormalized()
	var shoulders: Dictionary[String, Vector3] = {}
	for s: String in grips:
		shoulders[s] = upper * _clip_pose(s + "UpperArm").origin
	for attempt: int in 4:
		var moved: bool = false
		for s: String in grips:
			var wrist: Vector3 = rig.seat(s, xf, grips[s], shoulders[s], chest).origin
			var over: float = shoulders[s].distance_to(wrist) - REACH * rig.arm_length(s)
			if over > 0.001:
				xf.origin += (shoulders[s] - wrist).normalized() * over
				moved = true
		if not moved:
			break
	return xf


func _clip_pose(bone: String) -> Transform3D:
	return model.skeleton.get_bone_global_pose(model.skeleton.find_bone(bone))


## Lets go of the pose and plays the fall, `frames` rules frames after the KO.
func _fall(frames: float) -> void:
	_let_go()
	_play(DEATH_CLIP, frames / float(SimConst.FPS))


## A knocked-down fighter (task 16), `frames` rules frames into the
## knockdown, its phases those of `kd`: until task 28's clips, the
## fallback's stand-in. The fall plays KNOCKDOWN_FALL_CLIP over the fall's
## frames, then the fighter lies in KNOCKDOWN_RISE_CLIP's first pose and
## rises with it over the stand-up.
func _knocked_down(frames: float, kd: ProtectedTimings) -> void:
	_let_go()
	var fall: float = float(kd.knockdown_fall)
	var standup_from: float = fall + float(kd.knockdown_ground)
	if frames < fall:
		_play_share(KNOCKDOWN_FALL_CLIP, frames / fall)
	else:
		_play_share(KNOCKDOWN_RISE_CLIP, maxf(0.0, frames - standup_from) / float(kd.knockdown_rise))


## Shows the share `t` (0 to 1) of clip `clip`.
func _play_share(clip: StringName, t: float) -> void:
	var anim: Animation = model.animation_player.get_animation(String(FighterModel.LIBRARY) + "/" + String(clip))
	_play(clip, clampf(t, 0.0, 1.0) * anim.length)


## Lets go of the pose for a whole-body clip: the weapons carried in the
## hands, the body layer and leg IK off, the legs still.
func _let_go() -> void:
	model.carry_weapons()
	model.rig.body.clear()
	model.rig.leg_weight = 0.0
	model.rotation = Vector3.ZERO
	# the legs stand still while it falls: no footfalls carry over
	locomotion.footfalls.clear()


## Shows clip `clip` at `seconds` into it (looping round if it loops, held
## at its end if not).
func _play(clip: StringName, seconds: float) -> void:
	var ap: AnimationPlayer = model.animation_player
	var anim_name: String = String(FighterModel.LIBRARY) + "/" + String(clip)
	if ap.current_animation != anim_name:
		ap.play(anim_name, 0.0)
	var anim: Animation = ap.get_animation(anim_name)
	var at: float = fposmod(seconds, anim.length) if anim.loop_mode != Animation.LOOP_NONE else minf(seconds, anim.length)
	ap.seek(at, true)


## Holds weapon `wid` (a WeaponLook id), or nothing for any other id (bare
## hands): attaches it when it isn't the one held.
func _hold(wid: StringName) -> void:
	if not WeaponLook.IDS.has(wid):
		if model.weapon_look != null:
			model.detach_weapons()
			_weapon_meshes.clear()
			_weapon_lit = false
		return
	if model.weapon_look != null and model.weapon_look.id == wid:
		return
	model.attach_weapon(WeaponLook.load_id(wid))
	_weapon_meshes.clear()
	_weapon_lit = false
	for w: Node3D in model.weapons:
		for node: Node in w.find_children("*", "MeshInstance3D", true, false):
			_weapon_meshes.append(node as MeshInstance3D)
	GraphicsApplier.apply_to_tree(GameServices.graphics_preset(), model.weapon_root)


# ------------------------------------------------------------------ overlays

func _light_body(tint: Color) -> void:
	var on: bool = tint.a > 0.0
	if on:
		_body_overlay.albedo_color = tint
	if on != _body_lit:
		_body_lit = on
		for mi: MeshInstance3D in _body_meshes:
			mi.material_overlay = _body_overlay if on else null


func _light_weapons(glow: Color) -> void:
	var on: bool = glow.get_luminance() > 0.001
	if on:
		_glow_overlay.albedo_color = Color(glow, 1.0)
	if on != _weapon_lit:
		_weapon_lit = on
		for mi: MeshInstance3D in _weapon_meshes:
			mi.material_overlay = _glow_overlay if on else null


# ------------------------------------------------------------------ building

func _build_model(id: StringName) -> void:
	if model != null:
		remove_child(model)
		model.free()
	model = FighterLook.instantiate_fighter(id)
	model.name = &"Model"
	model.autoplay_idle = false
	add_child(model)
	model.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	locomotion = Locomotion.new(model, id)
	director = ClipDirector.Context.make(id, ClipLibraries.available(), _lengths(locomotion.tree))
	foot_lock = model.rig.new_foot_lock()
	shot = null
	_body_meshes.clear()
	for node: Node in model.skeleton.find_children("*", "MeshInstance3D", true, false):
		_body_meshes.append(node as MeshInstance3D)
	_weapon_meshes.clear()
	_body_lit = false
	_weapon_lit = false
	if _body_overlay == null:
		_body_overlay = StandardMaterial3D.new()
		_body_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_body_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_overlay = StandardMaterial3D.new()
		_glow_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	GraphicsApplier.apply_to_tree(GameServices.graphics_preset(), model)


## Each animation's length in the tree, by its name there.
static func _lengths(tree: AnimationMixer) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for lib_name: StringName in tree.get_animation_library_list():
		var lib: AnimationLibrary = tree.get_animation_library(lib_name)
		for anim: StringName in lib.get_animation_list():
			out["%s/%s" % [lib_name, anim]] = lib.get_animation(anim).length
	return out


func _build_floor() -> void:
	_floor = Node3D.new()
	_floor.name = &"FloorMarks"
	add_child(_floor)
	var shadow_mat: StandardMaterial3D = StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow: CylinderMesh = CylinderMesh.new()
	shadow.top_radius = 0.38
	shadow.bottom_radius = 0.38
	shadow.height = 0.004
	_floor_mesh(shadow, shadow_mat, &"Shadow")
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.56
	ring.rings = 48
	ring.ring_segments = 4
	var ring_mi: MeshInstance3D = _floor_mesh(ring, _ring_mat, &"SideRing")
	ring_mi.position = Vector3(0.0, 0.002, 0.0)
	ring_mi.scale = Vector3(1.0, 0.05, 1.0)


func _floor_mesh(mesh: Mesh, mat: Material, node_name: StringName) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor.add_child(mi)
	return mi
