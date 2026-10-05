extends Node3D
# One fighter: assembled model, phase-synced locomotion AnimationTree, procedural body layer,
# weapon grip/stance rig. Local frame: +Z forward (toward the opponent), +X left, +Y up.
const FB = preload("res://src/fighter_builder.gd")
const BodyLayer = preload("res://src/body_layer.gd")
const Rig = preload("res://src/rig.gd")
const Katana = preload("res://src/katana.gd")

# clip data measured with tools/foot_phase.gd: natural speed (m/s), metres per cycle, phase offset
const CLIPS := {
	"walk": {"anim": "ual1/Walk", "speed": 0.98, "stride": 1.30, "off": 0.027},
	"jog": {"anim": "ual1/Jog_Fwd", "speed": 5.36, "stride": 5.00, "off": -0.118},
	"sprint": {"anim": "ual1/Sprint", "speed": 8.25, "stride": 5.50, "off": -0.107},
}

var model: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var tree: AnimationTree
var body: BodyLayer
var rig: Rig
var katana: MeshInstance3D

var vel := Vector3.ZERO          # world velocity
var accel_s := Vector3.ZERO      # smoothed local acceleration
var phase := 0.0
var legs_yaw := 0.0
var legs_yaw_v := 0.0
var backwards := false
var move_w := 0.0
var max_leg_turn := deg_to_rad(80.0)

# stance / attack layer (added on top of locomotion), set by the caller each frame
var stance := {
	"pelvis_yaw": deg_to_rad(14.0), "spine_yaw": deg_to_rad(-10.0), "spine_pitch": deg_to_rad(6.0),
	"spine_roll": 0.0, "head_yaw": deg_to_rad(-4.0), "head_pitch": deg_to_rad(-4.0),
	"hips_offset": Vector3(0.0, -0.085, 0.0),
}
var stance_w := 0.0      # 1 once a weapon is equipped (stance legs/torso); legs fade out while moving

func _init(hair: String = "Hair_Long", outfit_tex: String = "res://assets/ranger/T_Rogue_BaseColor.png") -> void:
	model = FB.build(hair, outfit_tex)
	add_child(model)
	skel = model.find_child("GeneralSkeleton", true, false)
	ap = model.get_node("AnimationPlayer")
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model.add_child(tree)
	tree.anim_player = NodePath("../AnimationPlayer")
	tree.tree_root = _make_tree()
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	body = BodyLayer.new()
	body.name = "BodyLayer"
	skel.add_child(body)

func equip_katana(mats: Array = []) -> void:
	rig = Rig.new()
	rig.setup(skel)
	rig.body = body
	katana = Katana.build(mats)
	add_child(katana)
	stance_w = 1.0

func _make_tree() -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = "ual1/Idle"
	bt.add_node("idle", idle)
	for k in CLIPS:
		var a := AnimationNodeAnimation.new()
		a.animation = CLIPS[k].anim
		bt.add_node(k, a)
		bt.add_node(k + "_seek", AnimationNodeTimeSeek.new())
		bt.connect_node(k + "_seek", 0, k)
	bt.add_node("wj", AnimationNodeBlend2.new())
	bt.connect_node("wj", 0, "walk_seek")
	bt.connect_node("wj", 1, "jog_seek")
	bt.add_node("js", AnimationNodeBlend2.new())
	bt.connect_node("js", 0, "wj")
	bt.connect_node("js", 1, "sprint_seek")
	bt.add_node("move", AnimationNodeBlend2.new())
	bt.connect_node("move", 0, "idle")
	bt.connect_node("move", 1, "js")
	bt.connect_node("output", 0, "move")
	return bt

func face(dir: Vector3) -> void:
	rotation.y = atan2(dir.x, dir.z)

static func spring(x: float, v: float, target: float, omega: float, dt: float) -> Vector2:
	# critically damped spring step (implicit)
	var f := 1.0 + 2.0 * dt * omega
	var oo := omega * omega
	var hoo := dt * oo
	var hhoo := dt * hoo
	var det := 1.0 / (f + hhoo)
	var nx := (f * x + dt * v + hhoo * target) * det
	var nv := (v + hoo * (target - x)) * det
	return Vector2(nx, nv)

# Weapon pose in fighter space: P = right-hand grip point, A = blade direction, E = edge direction.
func set_weapon(p: Vector3, a: Vector3, e: Vector3) -> void:
	var y := a.normalized()
	var x := (e - y * e.dot(y)).normalized()
	var z := x.cross(y)
	var xf := Transform3D(Basis(x, y, z), p - y * float(rig.grip_y["R"]))
	rig.weapon_xf = xf
	katana.transform = xf

# Advance movement + locomotion by dt with a desired world-space velocity.
func step_move(dt: float, desired_vel: Vector3, accel: float = 14.0) -> void:
	var prev := vel
	var dv := desired_vel - vel
	vel += dv.limit_length(accel * dt)
	global_position += vel * dt
	var a_local := global_basis.inverse() * ((vel - prev) / dt)
	accel_s = accel_s.lerp(a_local, 1.0 - exp(-dt * 10.0))
	_locomotion(dt)

func _locomotion(dt: float) -> void:
	var lv := global_basis.inverse() * vel
	lv.y = 0.0
	var s := lv.length()
	var target_yaw := 0.0
	if s > 0.08:
		var psi := atan2(lv.x, lv.z)   # 0 = forward, +PI/2 = left
		var lim := deg_to_rad(100.0) + (deg_to_rad(10.0) if not backwards else -deg_to_rad(10.0))
		backwards = absf(psi) > lim
		if backwards:
			target_yaw = wrapf(psi - PI, -PI, PI)
		else:
			target_yaw = psi
		target_yaw = clampf(target_yaw, -max_leg_turn, max_leg_turn)
	var sp := spring(legs_yaw, legs_yaw_v, target_yaw, 12.0, dt)
	legs_yaw = sp.x
	legs_yaw_v = sp.y
	var wk: Dictionary = CLIPS.walk
	var jg: Dictionary = CLIPS.jog
	var spr: Dictionary = CLIPS.sprint
	var target_move := clampf(s / wk.speed, 0.0, 1.0)
	move_w = lerpf(move_w, target_move, 1.0 - exp(-dt * 12.0))
	var w1 := clampf((s - wk.speed) / (jg.speed - wk.speed), 0.0, 1.0)
	var w2 := clampf((s - jg.speed) / (spr.speed - jg.speed), 0.0, 1.0)
	var stride := lerpf(lerpf(wk.stride, jg.stride, w1), spr.stride, w2)
	phase = fposmod(phase + (s / stride) * dt * (-1.0 if backwards else 1.0), 1.0)
	for k in CLIPS:
		var c: Dictionary = CLIPS[k]
		var clip_len: float = ap.get_animation(c.anim).length
		tree.set("parameters/%s_seek/seek_request" % k, fposmod(phase + c.off, 1.0) * clip_len)
	tree.set("parameters/wj/blend_amount", w1)
	tree.set("parameters/js/blend_amount", w2)
	tree.set("parameters/move/blend_amount", move_w)
	_compose()

# Sum locomotion (hip-turn strafing, lean) and the stance/attack layer into the BodyLayer.
func _compose() -> void:
	var lw := stance_w * (1.0 - move_w)     # stance legs only when standing
	body.pelvis_yaw = legs_yaw * 0.7 + stance.pelvis_yaw * lw
	body.thigh_yaw = legs_yaw * 0.3
	# the chest keeps facing the opponent (plus the stance/attack twist) whatever the legs do;
	# spine_yaw is the chest yaw relative to the pelvis
	var chest_yaw: float = (stance.pelvis_yaw + stance.spine_yaw) * stance_w
	body.spine_yaw = chest_yaw - body.pelvis_yaw
	body.spine_pitch = stance.spine_pitch * stance_w
	body.spine_roll = stance.spine_roll * stance_w
	body.head_yaw = stance.head_yaw * stance_w
	body.head_pitch = stance.head_pitch * stance_w
	# armed: the pelvis stays low while walking too; the leg IK then re-plants the clip's feet
	body.hips_offset = stance.hips_offset * stance_w
	var ah := Vector3(accel_s.x, 0.0, accel_s.z)
	var ang := clampf(ah.length() * 0.014, 0.0, deg_to_rad(11.0))
	body.lean = Vector3.ZERO if ah.length() < 0.01 else Vector3.UP.cross(ah.normalized()).normalized() * ang
	if rig:
		rig.leg_w = stance_w
		rig.walk_feet_w = 1.0 - lw / maxf(stance_w, 0.001)

func advance_anim(dt: float) -> void:
	tree.advance(dt)
