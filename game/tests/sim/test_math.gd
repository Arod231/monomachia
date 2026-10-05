extends GutTest
## Spot checks of the math helpers against values computed by the TypeScript
## (game/tests/fixtures/math.json, written by scripts/sim-fixtures.ts). The
## fixture holds plain JSON numbers, which Godot's JSON reader can read a unit
## in the last place off, so floats are compared within 1e-12 (the bit-exact
## checks of JsMath are in test_port_regressions.gd).

const EPS: float = 1e-12

var _fx: Dictionary


func before_all() -> void:
	_fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/math.json"))


func _cases(key: String) -> Array:
	var cases: Array = _fx[key]
	assert_gt(cases.size(), 0, key)
	return cases


func _v3(x: Variant, z: Variant, y: float = 0.0) -> V3:
	return V3.make(float(x), y, float(z))


func test_constants() -> void:
	assert_eq(SimConst.DT, 1.0 / 60.0)
	assert_eq(SimConst.FPS, 60)
	assert_eq(SimMath.DEG, PI / 180.0)


func test_wrap_angle() -> void:
	for c: Array in _cases("wrapAngle"):
		assert_almost_eq(SimMath.wrap_angle(c[0]), float(c[1]), EPS, "wrapAngle(%s)" % c[0])


func test_turn_toward() -> void:
	for c: Array in _cases("turnToward"):
		assert_almost_eq(SimMath.turn_toward(c[0], c[1], c[2]), float(c[3]), EPS, "turnToward%s" % [c])


func test_angle_between() -> void:
	for c: Array in _cases("angleBetween"):
		assert_almost_eq(SimMath.angle_between(c[0], c[1]), float(c[2]), EPS, "angleBetween%s" % [c])


func test_yaw_to() -> void:
	for c: Array in _cases("yawTo"):
		assert_almost_eq(SimMath.yaw_to(_v3(c[0], c[1]), _v3(c[2], c[3])), float(c[4]), EPS, "yawTo%s" % [c])


func test_dist2_ignores_height() -> void:
	for c: Array in _cases("dist2"):
		assert_almost_eq(SimMath.dist2(_v3(c[0], c[1], 5.0), _v3(c[2], c[3], -2.0)), float(c[4]), EPS, "dist2%s" % [c])


func test_len2() -> void:
	for c: Array in _cases("len2"):
		assert_almost_eq(SimMath.len2(c[0], c[1]), float(c[2]), EPS, "len2%s" % [c])


func test_norm2() -> void:
	for c: Array in _cases("norm2"):
		var n: V2 = SimMath.norm2(c[0], c[1])
		assert_almost_eq(n.x, float(c[2]), EPS, "norm2%s.x" % [c])
		assert_almost_eq(n.z, float(c[3]), EPS, "norm2%s.z" % [c])


func test_norm2_of_the_zero_vector_is_forward() -> void:
	var n: V2 = SimMath.norm2(0.0, 0.0)
	assert_eq(n.x, 0.0)
	assert_eq(n.z, 1.0)


func test_fwd_and_right() -> void:
	for c: Array in _cases("fwd"):
		var f: V2 = SimMath.fwd(c[0])
		assert_almost_eq(f.x, float(c[1]), EPS, "fwd(%s).x" % c[0])
		assert_almost_eq(f.z, float(c[2]), EPS, "fwd(%s).z" % c[0])
	for c: Array in _cases("right"):
		var r: V2 = SimMath.right(c[0])
		assert_almost_eq(r.x, float(c[1]), EPS, "right(%s).x" % c[0])
		assert_almost_eq(r.z, float(c[2]), EPS, "right(%s).z" % c[0])


func test_easing() -> void:
	for c: Array in _cases("easeOutCubic"):
		assert_almost_eq(SimMath.ease_out_cubic(c[0]), float(c[1]), EPS, "easeOutCubic(%s)" % c[0])
	for c: Array in _cases("easeInOut"):
		assert_almost_eq(SimMath.ease_in_out(c[0]), float(c[1]), EPS, "easeInOut(%s)" % c[0])


func test_clamp_lerp_sign() -> void:
	for c: Array in _cases("clamp"):
		assert_eq(SimMath.clamp(c[0], c[1], c[2]), float(c[3]), "clamp%s" % [c])
	for c: Array in _cases("lerp"):
		assert_eq(SimMath.lerp(c[0], c[1], c[2]), float(c[3]), "lerp%s" % [c])
	for c: Array in _cases("sign"):
		assert_eq(SimMath.sign(c[0]), float(c[1]), "sign(%s)" % c[0])


func test_js_round_matches_math_round() -> void:
	for c: Array in _cases("round"):
		assert_eq(SimMath.js_round(c[0]), int(c[1]), "Math.round(%.17f)" % c[0])
	# Halves go toward +infinity, unlike Godot's round().
	assert_eq(SimMath.js_round(-0.5), 0)
	assert_eq(SimMath.js_round(2.5), 3)
	assert_eq(SimMath.js_round(-2.5), -2)
	# floor(x + 0.5) would give 1 here and 2^52 + 2 below.
	assert_eq(SimMath.js_round(0.49999999999999994), 0)
	var big: float = float(1 << 52) + 1.0
	assert_eq(SimMath.js_round(big), (1 << 52) + 1)


func test_vectors_are_64_bit() -> void:
	# 0.1 is not exact in float32; a Vector3 would round it.
	var v: V3 = V3.make(0.1, 0.2, 0.3)
	assert_eq(v.x + v.y, 0.1 + 0.2)
	assert_ne(v.x, float(Vector3(0.1, 0.0, 0.0).x))
