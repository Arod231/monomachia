extends RefCounted
# Plays swings (weapon paths) on a fighter: weapon, torso/hips drive, pelvis dip, lunge and foot steps.
const Swing = preload("res://src/swing.gd")

var f: Node3D
var move
var root_start := Vector3.ZERO
var feet_start := {}       # world positions of the planted feet at the start of the move
var base := {}             # the stance the attack layer is added to
var phi_guard := 0.0

# body-drive tuning
var chest_k := 0.5         # chest yaw per radian of grip azimuth around the pivot
var pelvis_k := 0.32
var lead_frames := 2.0     # hips lead the chest by this many frames
var dip := 0.05            # pelvis dip at contact (m)

func _init(fighter: Node3D) -> void:
	f = fighter
	base = f.stance.duplicate()
	phi_guard = _phi(Vector3(-0.07, 1.07, 0.36), Vector3(0.0, 1.25, 0.05))

static func _phi(p: Vector3, c: Vector3) -> float:
	# azimuth of the grip around the pivot, + toward the fighter's right
	return atan2(-(p.x - c.x), p.z - c.z)

static func ease01(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

func start(m) -> void:
	move = m
	root_start = f.global_position
	for s in ["R", "L"]:
		var p: Vector3 = f.rig.feet[s].pos
		feet_start[s] = f.to_global(Vector3(p.x, 0.0, p.z))

func fwd() -> Vector3:
	return f.global_basis.z.normalized()

func lunge_at(t: float) -> float:
	return move.lunge * ease01((t - move.lunge_span.x) / (move.lunge_span.y - move.lunge_span.x))

func root_at(t: float) -> Vector3:
	return root_start + fwd() * lunge_at(t)

# world-space blade base and tip at fractional frame t (for trails and hit checks)
func blade_world(t: float) -> Array:
	var s: Dictionary = move.sample(t)
	var b := f.global_basis
	var r := root_at(t)
	return [r + b * ((s.p as Vector3) + (s.a as Vector3) * 0.2), r + b * Swing.tip(s)]

func pose(t: float) -> void:
	var s: Dictionary = move.sample(t)
	f.set_weapon(s.p, s.a, s.e)
	var c: Vector3 = move.pivot
	var d_now := _phi(s.p, c) - phi_guard
	var d_lead := _phi(move.sample(minf(t + lead_frames, move.total())).p, c) - phi_guard
	var chest := clampf(-chest_k * d_now, deg_to_rad(-55.0), deg_to_rad(55.0))
	var pelvis := clampf(-pelvis_k * d_lead, deg_to_rad(-40.0), deg_to_rad(40.0))
	f.stance.pelvis_yaw = base.pelvis_yaw + pelvis
	f.stance.spine_yaw = base.spine_yaw + chest - pelvis
	f.stance.spine_pitch = deg_to_rad(s.pitch)
	f.stance.spine_roll = deg_to_rad(s.roll)
	f.stance.head_yaw = -(f.stance.pelvis_yaw + f.stance.spine_yaw) * 0.85
	f.stance.head_pitch = -f.stance.spine_pitch * 0.6 - deg_to_rad(3.0)
	var g: float = (t - float(move.dip_frame)) / 3.0
	f.stance.hips_offset = base.hips_offset + Vector3(0.0, -dip * exp(-g * g), 0.0)
	f.rig.pole_off["R"] = Vector3(-0.30, -0.55 + s.pole_r_up, -0.35 + s.pole_r_fwd)
	f.rig.pole_off["L"] = Vector3(0.30, -0.55 + s.pole_l_up, -0.35 + s.pole_l_fwd)
	# root lunge and stepping feet (feet stay planted in the world unless stepping)
	f.global_position = root_at(t)
	var stepped := {"R": 0.0, "L": 0.0}
	var lift := {"R": 0.0, "L": 0.0}
	for st in move.steps:
		var u := clampf((t - st.span.x) / (st.span.y - st.span.x), 0.0, 1.0)
		stepped[st.side] = st.dist * ease01(u)
		lift[st.side] = st.lift * sin(PI * u) if u > 0.0 and u < 1.0 else 0.0
	for side in ["R", "L"]:
		var w: Vector3 = feet_start[side] + fwd() * stepped[side]
		var l := f.to_local(w)
		f.rig.feet[side].pos = Vector3(l.x, 0.0707, l.z)
		f.rig.feet[side].lift = lift[side]
