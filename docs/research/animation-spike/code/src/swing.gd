extends RefCounted
# A weapon swing authored as a WEAPON PATH: a few key poses of the katana in the fighter's own space.
# Each key: frame, grip point P (right-hand grip centre), blade direction (azimuth/elevation),
# edge direction (explicit, or "lead" = face the way the blade is moving), optional body keys.
# Between keys:
#   - the grip travels on an ARC around a pivot near the sternum: Hermite spline of (P - pivot), then the
#     direction is renormalised and the radius splined separately, so the hands sweep around the body;
#   - blade and edge directions are Hermite-splined unit vectors, renormalised (a C1 "slerp");
#   - key tangents are Catmull-Rom in time; ease = 0 on a key gives zero velocity there (the cock, the settle).
# Authoring space is RUF (right, up, forward); fighter local space is (+X left, +Y up, +Z forward).

var name := ""
var startup := 0
var active := 0
var recovery := 0
var pivot := Vector3(0.0, 1.25, 0.05)   # fighter local
var keys: Array = []                    # of Dictionary (converted to fighter local)
var lunge := 0.35
var lunge_span := Vector2(9, 17)        # frames over which the root moves forward
var steps: Array = []                   # [{side, span: Vector2, dist, lift}]
var dip_frame := 13.0

static func ruf(r: float, u: float, f: float) -> Vector3:
	return Vector3(-r, u, f)

static func blade_dir(az_deg: float, el_deg: float) -> Vector3:
	# azimuth from forward, + toward the fighter's right; elevation + up
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(el_deg)
	return ruf(sin(az) * cos(el), sin(el), cos(az) * cos(el))

func total() -> int:
	return startup + active + recovery

func add_key(frame: float, p_ruf: Vector3, az: float, el: float, edge, ease: float = 1.0, body: Dictionary = {}) -> void:
	var k := {"f": frame, "p": ruf(p_ruf.x, p_ruf.y, p_ruf.z), "a": blade_dir(az, el), "edge": edge, "ease": ease}
	k.merge(body)
	keys.append(k)

func finalize() -> void:
	# resolve "lead" edges: face the direction the blade is moving through this key
	for i in keys.size():
		var k: Dictionary = keys[i]
		var e = k.edge
		if e is String:
			var a0: Vector3 = keys[max(i - 1, 0)].a
			var a1: Vector3 = keys[min(i + 1, keys.size() - 1)].a
			var mv := a1 - a0
			var a: Vector3 = k.a
			var lead := (mv - a * mv.dot(a)).normalized()
			if e == "lead_down":
				lead = (lead + Vector3(0, -0.35, 0)).normalized()
			elif e == "lead_up":
				lead = (lead + Vector3(0, 0.35, 0)).normalized()
			k.e = lead
		else:
			var ev: Vector3 = e
			k.e = ruf(ev.x, ev.y, ev.z).normalized()
		var av: Vector3 = k.a
		k.e = (k.e - av * k.e.dot(av)).normalized()
		k.v = k.p - pivot

static func _herm(p0, p1, m0, m1, s: float, h: float):
	var s2 := s * s
	var s3 := s2 * s
	return p0 * (2 * s3 - 3 * s2 + 1) + m0 * h * (s3 - 2 * s2 + s) + p1 * (-2 * s3 + 3 * s2) + m1 * h * (s3 - s2)

func _tangent(field: String, i: int):
	var k: Dictionary = keys[i]
	if float(k.ease) == 0.0:
		return k[field] * 0.0
	var i0: int = max(i - 1, 0)
	var i1: int = min(i + 1, keys.size() - 1)
	var dt: float = keys[i1].f - keys[i0].f
	return (keys[i1][field] - keys[i0][field]) / dt * float(k.ease)

func _interp(field: String, t: float):
	if t <= keys[0].f:
		return keys[0][field]
	if t >= keys[-1].f:
		return keys[-1][field]
	var i := 0
	while keys[i + 1].f < t:
		i += 1
	var h: float = keys[i + 1].f - keys[i].f
	var s: float = (t - keys[i].f) / h
	return _herm(keys[i][field], keys[i + 1][field], _tangent(field, i), _tangent(field, i + 1), s, h)

func _interp_len(t: float) -> float:
	# radius of the grip around the pivot, splined separately from the direction
	for k in keys:
		k.r = (k.v as Vector3).length()
	return float(_interp("r", t))

func _body(field: String, t: float, default: float) -> float:
	for k in keys:
		if not k.has(field):
			k[field] = default
	return float(_interp(field, t))

# Sample the path at (fractional) frame t. Returns fighter-local P, A, E and body values.
func sample(t: float) -> Dictionary:
	var vdir: Vector3 = (_interp("v", t) as Vector3).normalized()
	var p := pivot + vdir * _interp_len(t)
	var a: Vector3 = (_interp("a", t) as Vector3).normalized()
	var e: Vector3 = _interp("e", t)
	e = (e - a * e.dot(a)).normalized()
	return {
		"p": p, "a": a, "e": e,
		"pitch": _body("pitch", t, 6.0), "roll": _body("roll", t, 0.0),
		"pole_r_up": _body("pole_r_up", t, 0.0), "pole_l_up": _body("pole_l_up", t, 0.0),
		"pole_l_fwd": _body("pole_l_fwd", t, 0.0), "pole_r_fwd": _body("pole_r_fwd", t, 0.0),
	}

# Blade tip in fighter space for a sample.
static func tip(s: Dictionary, grip_to_tip: float = 0.798) -> Vector3:
	return (s.p as Vector3) + (s.a as Vector3) * grip_to_tip

# ---------------------------------------------------------------- the two katana cuts

static func right_cut():
	var m = load("res://src/swing.gd").new()
	m.name = "Right Cut (R->L)"
	m.startup = 11
	m.active = 3
	m.recovery = 16
	# frame, grip (right, up, fwd), blade az, el, edge
	m.add_key(0, Vector3(0.07, 1.07, 0.36), -8, 27, Vector3(0, -1, 0), 0.0, {"pitch": 6.0})
	m.add_key(5, Vector3(0.24, 1.36, 0.24), 45, 62, Vector3(0.3, 0.0, 1.0), 1.0, {"pitch": 2.0, "roll": -3.0, "pole_l_up": 0.25, "pole_l_fwd": 0.45})
	m.add_key(9, Vector3(0.30, 1.50, 0.06), 150, 38, Vector3(0.85, -0.3, 0.45), 0.0, {"pitch": -2.0, "roll": -7.0, "pole_l_up": 0.3, "pole_l_fwd": 0.55, "pole_r_up": 0.25})
	m.add_key(11, Vector3(0.30, 1.38, 0.36), 92, 12, "lead_down", 1.0, {"pitch": 8.0, "roll": -4.0, "pole_l_fwd": 0.3})
	m.add_key(13, Vector3(0.02, 1.22, 0.56), -5, -8, "lead_down", 1.0, {"pitch": 16.0, "roll": 0.0})
	m.add_key(18, Vector3(-0.28, 1.06, 0.38), -95, -25, "lead_down", 1.0, {"pitch": 18.0, "roll": -6.0, "pole_r_fwd": 0.35})
	m.add_key(30, Vector3(-0.32, 0.97, 0.24), -128, -38, "lead_down", 0.0, {"pitch": 16.0, "roll": -9.0, "pole_r_fwd": 0.45, "pole_r_up": 0.1})
	m.lunge_span = Vector2(9, 17)
	m.steps = [{"side": "R", "span": Vector2(7, 14), "dist": 0.35, "lift": 0.07}, {"side": "L", "span": Vector2(14, 23), "dist": 0.35, "lift": 0.035}]
	m.dip_frame = 13.0
	m.finalize()
	return m

static func return_cut():
	var m = load("res://src/swing.gd").new()
	m.name = "Return Cut (L->R)"
	m.startup = 10
	m.active = 3
	m.recovery = 16
	# starts exactly where the Right Cut ended
	m.add_key(0, Vector3(-0.32, 0.97, 0.24), -128, -38, "lead_down", 0.0, {"pitch": 16.0, "roll": -9.0, "pole_r_fwd": 0.45, "pole_r_up": 0.1})
	# turn the wrists over (edge rolls through "down") while drawing the blade back along the left side
	m.add_key(4, Vector3(-0.34, 1.08, 0.14), -150, -8, Vector3(-0.2, -1.0, 0.1), 1.0, {"pitch": 8.0, "roll": 4.0, "pole_r_fwd": 0.55, "pole_r_up": 0.15})
	m.add_key(7, Vector3(-0.30, 1.18, 0.10), -150, 8, Vector3(-0.8, -0.25, 0.55), 0.0, {"pitch": 4.0, "roll": 6.0, "pole_r_fwd": 0.6, "pole_r_up": 0.2})
	m.add_key(10, Vector3(-0.28, 1.22, 0.38), -88, 2, "lead", 1.0, {"pitch": 10.0, "roll": 3.0, "pole_r_fwd": 0.35})
	m.add_key(12, Vector3(0.0, 1.20, 0.56), 4, 3, "lead", 1.0, {"pitch": 16.0, "roll": 0.0})
	m.add_key(17, Vector3(0.28, 1.22, 0.38), 90, 12, "lead_up", 1.0, {"pitch": 14.0, "roll": 4.0, "pole_l_fwd": 0.35})
	m.add_key(29, Vector3(0.30, 1.26, 0.20), 128, 26, "lead_up", 0.0, {"pitch": 10.0, "roll": 6.0, "pole_l_fwd": 0.5, "pole_l_up": 0.15})
	m.lunge_span = Vector2(7, 15)
	m.steps = [{"side": "R", "span": Vector2(6, 12), "dist": 0.35, "lift": 0.07}, {"side": "L", "span": Vector2(12, 21), "dist": 0.35, "lift": 0.035}]
	m.dip_frame = 12.0
	m.finalize()
	# continuity: the first key IS the previous cut's last key (grip, blade and edge)
	var prev = right_cut()
	var last: Dictionary = prev.keys[-1]
	for fld in ["p", "a", "e", "v"]:
		m.keys[0][fld] = last[fld]
	return m
