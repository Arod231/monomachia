extends GutTest
## The roll's travel (authored-animation task 17): a dodge covers the same
## distance in the same frames, along Roll01 [RM]'s ground travel
## (SimConst.MOVE_ROLL_CURVE) instead of ease_out_cubic; the backstep, the
## i-frames and the forward dodge's counter window are unchanged. A
## local-only test reads the curve from the pack again.

const H := preload("res://tests/sim/sim_helpers.gd")
const ImportClips := preload("res://tools/import_clips.gd")


func after_each() -> void:
	H.dispose_all()


## Starts a dodge with `input` on a lone fighter (the opponent far off) and
## returns how far it has travelled after each of its state frames, by frame.
func _travel(input: RawInput) -> Dictionary:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 9.0)
	var f: Fighter = W.fighters[0]
	var start: V3 = V3.make(f.pos.x, f.pos.y, f.pos.z)
	W.step([input, H.idle()])
	var out: Dictionary = {"state": f.state, "dodge": f.dodge, "by_frame": {}}
	while f.state == out["state"] and f.sf <= 40:
		out["by_frame"][f.sf] = SimMath.dist2(start, f.pos)
		W.step([H.idle(), H.idle()])
	return out


func test_the_curve_rises_from_0_to_1() -> void:
	var c: Array[float] = SimConst.MOVE_ROLL_CURVE
	assert_eq(c.size(), SimConst.MOVE_DODGE_FRAMES + 1, "a point per frame, and the start")
	assert_eq(c[0], 0.0)
	assert_eq(c[-1], 1.0)
	for i: int in range(1, c.size()):
		assert_gte(c[i], c[i - 1], "never falls (frame %d)" % i)
	assert_eq(SimMath.roll_travel(0.5), c[8], "on its points")
	assert_almost_eq(SimMath.roll_travel(0.5 / 16.0), c[1] * 0.5, 1e-12, "a straight line between them")
	assert_eq(SimMath.roll_travel(-1.0), 0.0)
	assert_eq(SimMath.roll_travel(2.0), 1.0)


func test_a_roll_travels_along_the_curve_to_the_same_distance() -> void:
	var got: Dictionary = _travel(H.move(1.0, 0.0, Btn.DODGE))
	assert_eq(got["state"], &"dodge")
	var dg: DodgeState = got["dodge"]
	assert_eq(dg.frames, SimConst.MOVE_DODGE_FRAMES, "the same frames")
	assert_almost_eq(dg.dist, SimConst.MOVE_DODGE_DIST, 1e-12, "the same distance (the Katana's multiplier is 1)")
	var by_frame: Dictionary = got["by_frame"]
	for f: int in by_frame:
		var want: float = dg.dist * SimConst.MOVE_ROLL_CURVE[mini(f, dg.frames)]
		assert_almost_eq(by_frame[f], want, 1e-9, "frame %d: %.3f m along Roll01's travel" % [f, want])
	assert_almost_eq(by_frame[dg.frames], dg.dist, 1e-9, "the whole distance on its last frame")
	assert_almost_eq(by_frame[by_frame.keys().max()], dg.dist, 1e-9, "and still through the recovery")


func test_the_backstep_keeps_its_curve() -> void:
	var got: Dictionary = _travel(H.btn(Btn.DODGE))
	assert_eq(got["state"], &"backstep")
	var dg: DodgeState = got["dodge"]
	assert_eq([dg.frames, dg.iframes, dg.recovery], [SimConst.MOVE_BACKSTEP_FRAMES, SimConst.MOVE_BACKSTEP_I_FRAMES, SimConst.MOVE_BACKSTEP_RECOVERY])
	assert_almost_eq(dg.dist, SimConst.MOVE_BACKSTEP_DIST, 1e-12)
	var by_frame: Dictionary = got["by_frame"]
	for f: int in range(1, dg.frames + 1):
		assert_almost_eq(by_frame[f], dg.dist * SimMath.ease_out_cubic(float(f) / dg.frames), 1e-9, "frame %d eases out" % f)


func test_the_iframes_and_counter_window_are_unchanged() -> void:
	assert_eq([SimConst.MOVE_DODGE_DIST, SimConst.MOVE_DODGE_FRAMES, SimConst.MOVE_DODGE_I_FRAMES, SimConst.MOVE_DODGE_RECOVERY],
		[2.8, 16, 12, 9])
	var got: Dictionary = _travel(H.move(0.0, 1.0, Btn.DODGE))
	var dg: DodgeState = got["dodge"]
	assert_true(dg.forward, "a forward roll")
	assert_eq([dg.iframes, dg.recovery], [12, 9])
	# the forward dodge's counter window: its i-frames and 3 more (Fighter)
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 9.0)
	var f: Fighter = W.fighters[0]
	W.step([H.move(0.0, 1.0, Btn.DODGE), H.idle()])
	var open: Array[int] = []
	while f.state == &"dodge":
		if f.is_forward_dodging():
			open.append(f.sf)
		W.step([H.idle(), H.idle()])
	assert_eq(open[-1], SimConst.MOVE_DODGE_I_FRAMES + 3, "the window closes 3 frames after the i-frames")


func test_local_the_curve_is_roll01s() -> void:
	var path: String = ImportClips.staged_path(ImportClips.ROLL_SET, ImportClips.root_clips()[0])
	if not ResourceLoader.exists(path):
		pending("local-only: Roll01 [RM] isn't imported (node scripts/godot.mjs clips)")
		return
	var curve: PackedFloat64Array = ImportClips.roll_curve(ImportClips.ROLL_SET)
	assert_eq(curve.size(), SimConst.MOVE_ROLL_CURVE.size())
	for i: int in curve.size():
		assert_almost_eq(SimConst.MOVE_ROLL_CURVE[i], curve[i], 1e-9, "frame %d is the pack's" % i)
