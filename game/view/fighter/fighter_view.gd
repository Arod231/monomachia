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
## - under it all, the legs walk, jog and sprint with the rules' speed
##   (Locomotion), over the clip for the held weapon (its WeaponHold's) at
##   rest, all on the rules' clock, so they hold still through hit-stop and
##   pause. They turn toward the way the fighter travels, or run backwards,
##   while the chest keeps facing the opponent, and the body leans into the
##   acceleration and braces when braking, the weapons riding with it;
## - with a weapon whose hold has a guard stance (the Katana's), the fighter
##   stands in it (GuardStance) over the relaxed idle instead of the hold's
##   clip, unless it runs with its guard down: the feet planted on leg IK and
##   stepping in the guard shuffle (GuardShuffle) as it walks, the pelvis
##   lowered, swaying and bobbing, the weapon riding the pelvis;
## - a knocked-out fighter lets go of the pose and falls with DEATH_CLIP,
##   timed on the rules' frames from the KO;
## - a disarmed fighter holds nothing, its arms on the clip.
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
## How far the guard stance showed in the last pose (0 to 1), how far its
## weight had shifted toward the front foot (m), and how far its pelvis sank
## for the legs to reach the feet (m), for tests and tools.
var stance: float = 0.0
var sway: float = 0.0
var sink: float = 0.0

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
	_flash_strength = 0.0
	_light_body(Color(0.0, 0.0, 0.0, 0.0))
	_light_weapons(Color.BLACK)


func side_color() -> Color:
	return LookPalette.side_color(palette)


## Briefly lights the body (a hit) from the world frame `frame` on. A weaker
## flash than what is left of the current one doesn't replace it.
func flash(color: Color, strength: float, frame: int) -> void:
	if strength >= flash_left(frame):
		_flash_strength = strength
		_flash_frame = frame
	_flash_color = color


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
	if f.state == &"ko":
		_fall(maxf(0.0, float(f.sf) - 1.0 + alpha))
	else:
		var seconds: float = (float(frame) + alpha) / float(SimConst.FPS)
		locomotion.update(f, GuardStance.CLIP if _in_guard() else model.idle_clip(), seconds, alpha, _in_guard())
		_pose(f, p, seconds, alpha)
	# the floor marks stay on the floor while the fighter jumps
	_floor.position = Vector3(0.0, -pos.y + 0.006, 0.0)
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

## True when the held weapon's hold stands in the guard stance.
func _in_guard() -> bool:
	return model.hold != null and model.hold.guard


## Poses the body and the weapons, `seconds` into the rules' clock, `alpha`
## of the way from the step before to the last.
func _pose(f: Fighter, p: StickPose.Pose, seconds: float, alpha: float) -> void:
	var rig: FighterRig = model.rig
	var swung: bool = SwingPlayer.plays(f) and not model.weapons.is_empty()
	var lean: float = 0.0 if swung else p.lean
	var crouch: float = 0.0 if swung else p.crouch
	var spin: float = 0.0 if swung else p.spin
	rig.leg_weight = 1.0
	rig.clear_pole_tweaks()
	rig.body.clear()
	rig.body.spine_pitch = lean
	rig.body.hips_offset = Vector3(0.0, -crouch, 0.0)
	locomotion.pose_body(rig.body)
	# a swing's body (its coil, shift and dip) takes over from the stance's
	var swing_body: SwingPlayer.Body = swing_player.body(f, alpha)
	swing_body.apply(rig.body)
	# the stance as far as the legs are the guard's; the clips' feet as they
	# run with the guard down
	stance = locomotion.shown[0] if _in_guard() else 0.0
	sway = GuardStance.sway(seconds) * stance
	sink = 0.0
	rig.clip_feet = 1.0
	model.rotation = Vector3(0.0, spin, 0.0)
	if stance > 0.0:
		sink = GuardStance.pose(rig, stance, seconds, locomotion.shuffle, spin, 1.0 - swing_body.weight)
	if model.weapons.is_empty():
		return
	var swing_poses: Dictionary[int, Transform3D] = {}
	if swung:
		swing_poses = SwingPlayer.weapon_poses(f, alpha, model.weapons.size(), rig)
	elif p.phase == &"guard":
		# a weapon with swings stands in their guard, riding as the stand-in's
		swing_poses = SwingPlayer.guard_poses(f.moveset(), model.weapons.size())
	var sweeps: Array[Vector3] = _strike_sweeps(f)
	var hands: Array[StickPose.Hand] = [p.right, p.left]
	# the weapons ride the stance's pelvis, sunk, and the shuffle's bob (on
	# its spring), the lean and the brace with the upper body
	var rides: Vector3 = (GuardStance.offset(seconds) + Vector3(0.0, locomotion.shuffle.shown_weapon_bob, 0.0)) * stance * (1.0 - swing_body.weight)
	rides.y -= sink
	var carry: Transform3D = Transform3D(Basis.IDENTITY, rides) * locomotion.carry(model.skeleton)
	var poses: Dictionary[int, Transform3D] = {}
	for i: int in model.weapons.size():
		if swing_poses.has(i):
			poses[i] = swing_poses[i] if swung else carry * swing_poses[i]
			continue
		var hand: StickPose.Hand = hands[i]
		var xf: Transform3D = carry * FighterRig.weapon_frame(hand.pos, hand.dir, edge_for(hand.dir, sweeps[i]))
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
	model.carry_weapons()
	model.rig.body.clear()
	model.rig.leg_weight = 0.0
	model.rotation = Vector3.ZERO
	stance = 0.0
	sway = 0.0
	sink = 0.0
	# the legs stand still while it falls: no footfalls carry over
	locomotion.footfalls.clear()
	_play(DEATH_CLIP, frames / float(SimConst.FPS))


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
