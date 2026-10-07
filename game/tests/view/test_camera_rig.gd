extends GutTest
## The match camera's math: behind the player on the line to the opponent,
## offset to the player's right, at the spec's distance and height, clamped
## inside the arena; the side-on Watch view; shake, field-of-view kicks and
## the parry's push-in (milestone-1 task 39).

var rig: CameraRig


func before_each() -> void:
	rig = CameraRig.new()
	autofree(rig)


func _dir(p: Vector3, o: Vector3) -> Vector3:
	return Vector3(o.x - p.x, 0.0, o.z - p.z).normalized()


func test_the_spec_numbers_are_the_defaults() -> void:
	assert_eq(rig.follow_back, 4.6)
	assert_eq(rig.follow_side, 1.35)
	assert_between(rig.follow_height, 1.9, 2.0)
	assert_eq(rig.base_fov, 60.0)
	assert_eq(rig.fov, 60.0)


func test_follow_sits_behind_the_player_on_the_line_to_the_opponent() -> void:
	# 4.5 m apart: past the close swing, so the plain 1.35 m to the side
	var p: Vector3 = Vector3(1.0, 0.0, -2.0)
	var o: Vector3 = Vector3(3.0, 0.0, 2.0)
	var d: Vector3 = _dir(p, o)
	var t: Dictionary = rig.follow_target(p, o, d)
	var pos: Vector3 = t["pos"]
	var rel: Vector3 = Vector3(pos.x - p.x, 0.0, pos.z - p.z)
	var sep: float = Vector2(o.x - p.x, o.z - p.z).length()
	var back: float = rig.follow_back + maxf(0.0, sep - rig.follow_far_from) * rig.follow_back_per_metre
	assert_almost_eq(rel.dot(d), -back, 1e-5, "behind the player along the line")
	assert_almost_eq(rel.dot(CameraRig.right_of(d)), rig.follow_side, 1e-5, "to the player's right")
	assert_gt(pos.y, 1.85)
	assert_lt(pos.y, 2.3)


func test_the_right_offset_is_the_fighters_own_right() -> void:
	for yaw: float in [0.0, 0.7, PI / 2.0, 2.4, PI, -1.1]:
		var f: V2 = SimMath.fwd(yaw)
		var r: V2 = SimMath.right(yaw)
		var right: Vector3 = CameraRig.right_of(Vector3(f.x, 0.0, f.z))
		assert_almost_eq(right, Vector3(r.x, 0.0, r.z), Vector3.ONE * 1e-6, "yaw %s" % yaw)
	# the player facing +z: their right is -x, so the camera sits at -x
	var t: Dictionary = rig.follow_target(Vector3.ZERO, Vector3(0.0, 0.0, 3.0), Vector3(0.0, 0.0, 1.0))
	assert_lt((t["pos"] as Vector3).x, 0.0)


func test_it_looks_at_the_opponents_chest() -> void:
	var p: Vector3 = Vector3(0.0, 0.0, -1.5)
	var o: Vector3 = Vector3(0.0, 0.0, 1.5)
	var t: Dictionary = rig.follow_target(p, o, _dir(p, o))
	var look: Vector3 = t["look"]
	assert_almost_eq(Vector2(look.x, look.z), Vector2(o.x, o.z), Vector2.ONE * 1e-5)
	assert_between(look.y, 1.1, 1.5)


func test_the_camera_backs_off_as_the_fighters_separate() -> void:
	var p: Vector3 = Vector3.ZERO
	var near_t: Dictionary = rig.follow_target(p, Vector3(0.0, 0.0, 3.0), Vector3(0.0, 0.0, 1.0))
	var far_t: Dictionary = rig.follow_target(p, Vector3(0.0, 0.0, 8.0), Vector3(0.0, 0.0, 1.0))
	assert_lt((far_t["pos"] as Vector3).z, (near_t["pos"] as Vector3).z, "further back")
	assert_gt((far_t["pos"] as Vector3).y, (near_t["pos"] as Vector3).y, "and a little higher")


func test_up_close_it_swings_out_so_the_opponent_shows_past_the_player() -> void:
	var p: Vector3 = Vector3.ZERO
	var d: Vector3 = Vector3(0.0, 0.0, 1.0)
	var at_range: Vector3 = rig.follow_target(p, Vector3(0.0, 0.0, 3.5), d)["pos"]
	var up_close: Vector3 = rig.follow_target(p, Vector3(0.0, 0.0, 1.3), d)["pos"]
	assert_eq(rig.follow_close_from, 3.5, "the swing starts at 3.5 m (spec, Camera)")
	assert_almost_eq(at_range.dot(CameraRig.right_of(d)), rig.follow_side, 1e-5, "the spec's 1.35 m from 3.5 m out")
	assert_gt(up_close.dot(CameraRig.right_of(d)), rig.follow_side + 1.0, "further right up close")
	var closest: Vector3 = rig.follow_target(p, Vector3(0.0, 0.0, SimConst.FIGHTER_RADIUS * 2.0), d)["pos"]
	assert_lt(closest.dot(CameraRig.right_of(d)), 3.6, "about 3.5 m at the closest")


## Seen from the follow camera, the angle between the player and the opponent
## stays wider than both half-widths: 0.35 m, a real fighter's shoulders,
## wider than the stand-in's 0.28 m capsule.
func test_the_player_never_hides_the_opponent_from_duelling_range_in() -> void:
	var p: Vector3 = Vector3.ZERO
	var d: Vector3 = Vector3(0.0, 0.0, 1.0)
	for sep: float in [1.5, 2.0, 2.5, 3.0, 3.5]:
		var o: Vector3 = Vector3(0.0, 0.0, sep)
		var cam: Vector3 = rig.follow_target(p, o, d)["pos"]
		var to_p: Vector3 = (p - cam) * Vector3(1, 0, 1)
		var to_o: Vector3 = (o - cam) * Vector3(1, 0, 1)
		var apart: float = to_p.angle_to(to_o)
		var widths: float = atan(0.35 / to_p.length()) + atan(0.35 / to_o.length())
		assert_gt(apart, widths, "clear at %.1f m apart" % sep)


func test_it_stays_inside_the_arena() -> void:
	var limit: float = SimConst.ARENA_RADIUS + rig.arena_margin
	# the player with their back to the wall
	var p: Vector3 = Vector3(0.0, 0.0, SimConst.ARENA_RADIUS - 0.5)
	var o: Vector3 = Vector3(0.0, 0.0, SimConst.ARENA_RADIUS - 3.5)
	rig.mode = CameraRig.Mode.FOLLOW
	rig.snap(p, o)
	assert_lte(Vector2(rig.rig_position.x, rig.rig_position.z).length(), limit + 1e-4)
	var raw: Vector3 = rig.follow_target(p, o, _dir(p, o))["pos"]
	assert_gt(Vector2(raw.x, raw.z).length(), limit, "unclamped it would leave")
	var clamped: Vector3 = rig.clamp_to_arena(raw)
	assert_almost_eq(Vector2(clamped.x, clamped.z).length(), limit, 1e-4)
	assert_eq(clamped.y, raw.y, "only the horizontal position is clamped")


func test_snap_puts_the_camera_on_target_facing_the_look_point() -> void:
	var p: Vector3 = Vector3(0.0, 0.0, -3.2)
	var o: Vector3 = Vector3(0.0, 0.0, 3.2)
	rig.snap(p, o)
	var t: Dictionary = rig.follow_target(p, o, Vector3(0.0, 0.0, 1.0))
	assert_almost_eq(rig.position, t["pos"] as Vector3, Vector3.ONE * 1e-5)
	var forward: Vector3 = -rig.transform.basis.z
	assert_gt(forward.z, 0.95, "looking toward the opponent")
	assert_gt(forward.y, -0.1, "nearly level...")
	assert_lt(forward.y, 0.12, "...pitched no more than a little up")


func test_movement_is_smoothed() -> void:
	var p: Vector3 = Vector3(0.0, 0.0, -3.2)
	var o: Vector3 = Vector3(0.0, 0.0, 3.2)
	rig.snap(p, o)
	var start: Vector3 = rig.rig_position
	var moved: Vector3 = p + Vector3(2.0, 0.0, 0.0)
	rig.update_rig(1.0 / 60.0, moved, o)
	var target: Vector3 = rig.follow_target(moved, o, rig.dir)["pos"]
	var step: float = rig.rig_position.distance_to(start)
	assert_gt(step, 0.0, "it moves")
	assert_lt(step, start.distance_to(target) * 0.5, "but only part of the way in one frame")
	for i: int in 240:
		rig.update_rig(1.0 / 60.0, moved, o)
	assert_almost_eq(rig.rig_position, rig.follow_target(moved, o, rig.dir)["pos"] as Vector3, Vector3.ONE * 1e-3)


func test_watch_is_side_on() -> void:
	var p: Vector3 = Vector3(0.0, 0.0, -1.5)
	var o: Vector3 = Vector3(0.0, 0.0, 1.5)
	var d: Vector3 = _dir(p, o)
	var t: Dictionary = rig.watch_target(p, o, d, 0.0)
	var pos: Vector3 = t["pos"]
	var mid: Vector3 = (p + o) / 2.0
	var rel: Vector3 = Vector3(pos.x - mid.x, 0.0, pos.z - mid.z)
	var side: float = rel.dot(CameraRig.right_of(d))
	assert_almost_eq(side, rig.watch_distance + 3.0 * rig.watch_distance_per_metre, 1e-5, "out to the side")
	assert_almost_eq(rel.dot(d), -rig.watch_back, 1e-5, "a little behind the middle")
	assert_almost_eq((t["look"] as Vector3).x, mid.x, 1e-5)


func test_menu_orbits_the_arena() -> void:
	var a: Vector3 = rig.menu_target(0.0)["pos"]
	var b: Vector3 = rig.menu_target(10.0)["pos"]
	assert_ne(a, b)
	assert_almost_eq(Vector2(a.x - rig.menu_centre.x, a.z - rig.menu_centre.z).length(), rig.menu_radius, 1e-4)
	assert_almost_eq(a.y, rig.menu_height, 1e-5)


func test_shake_is_capped_and_decays() -> void:
	for i: int in 5:
		rig.add_shake(0.8)
	assert_eq(rig.shake, rig.shake_max)
	rig.snap(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0))
	for i: int in 120:
		rig.update_rig(1.0 / 60.0, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0))
	assert_lt(rig.shake, 0.01)


func test_the_same_shake_looks_the_same_every_run() -> void:
	var other: CameraRig = CameraRig.new()
	autofree(other)
	var p: Vector3 = Vector3(0.0, 0.0, -1.5)
	var o: Vector3 = Vector3(0.0, 0.0, 1.5)
	var shaken: Array[Transform3D] = []
	for r: CameraRig in [rig, other]:
		r.add_shake(1.0)
		r.snap(p, o)
		r.update_rig(1.0 / 60.0, p, o)
		shaken.append(r.transform)
	assert_ne(shaken[0].origin, rig.rig_position, "the shake moved the camera")
	assert_eq(shaken[0], shaken[1], "a seeded shake: screenshots repeat")


func test_fov_kicks_narrow_and_recover() -> void:
	rig.snap(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0))
	rig.kick_fov(7.0)
	rig.update_rig(1.0 / 60.0, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0))
	assert_lt(rig.fov, 54.0)
	for i: int in 180:
		rig.update_rig(1.0 / 60.0, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0))
	assert_almost_eq(rig.fov, 60.0, 0.05)


func test_the_reduce_shaking_scales_apply() -> void:
	rig.shake_scale = 0.15
	rig.fov_kick_scale = 0.0
	rig.add_shake(1.0)
	rig.kick_fov(8.0)
	assert_almost_eq(rig.shake, 0.15, 1e-6)
	assert_eq(rig.fov_kick, 0.0)


func test_a_ko_swings_the_follow_camera_to_the_side_until_the_next_round() -> void:
	var p: Vector3 = Vector3(0.0, 0.0, -1.5)
	var o: Vector3 = Vector3(0.0, 0.0, 1.5)
	rig.snap(p, o)
	rig.start_ko_orbit()
	for i: int in 300:
		rig.update_rig(1.0 / 60.0, p, o)
	assert_gt(rig.rig_position.z, p.z, "no longer behind the player")
	assert_gt(Vector2(rig.rig_position.x, rig.rig_position.z).length(), 3.0, "out around the fighters")
	rig.reset_round()
	rig.snap(p, o)
	assert_lt(rig.rig_position.z, p.z, "behind the player again")


# ------------------------------------------------------------------ the push-in

const P: Vector3 = Vector3(0.0, 0.0, -1.5)
const O: Vector3 = Vector3(0.0, 0.0, 1.5)


func _step(frames: int = 1) -> void:
	for i: int in frames:
		rig.update_rig(1.0 / 60.0, P, O)


## How far the camera stands from the look point.
func _reach() -> float:
	return rig.transform.origin.distance_to(rig.rig_look)


## A parry's push-in (milestone-1 task 39): it closes in on the look point
## over about 3 frames, holds still through the hit-stop, then eases back out
## over about 0.4 s.
func test_a_push_in_snaps_in_holds_through_the_hit_stop_and_eases_back() -> void:
	rig.snap(P, O)
	var rest: float = _reach()
	rig.frozen = true
	rig.push_in(0.15)
	_step()
	assert_between(rig.push_amount(), 0.01, 0.15, "on its way in")
	_step(2)
	assert_almost_eq(rig.push_amount(), 0.15, 1e-4, "in after 3 frames")
	assert_almost_eq(_reach(), rest * 0.85, 0.01, "15% of the way to the look point")
	var held: Transform3D = rig.transform
	_step(9)
	assert_almost_eq(rig.push_amount(), 0.15, 1e-6, "held through the hit-stop")
	assert_eq(rig.transform, held, "the camera stands still")
	rig.frozen = false
	_step(12)
	assert_between(rig.push_amount(), 0.01, 0.149, "easing back")
	_step(12)
	assert_eq(rig.push_amount(), 0.0, "back after 0.4 s")
	assert_almost_eq(_reach(), rest, 0.01)


## Moonsplitter's wind-up (milestone-1 task 98, story 133): a slow push-in
## that closes in over the time it is given, holds until it is released (the
## wave leaving), then eases back out as any push-in does.
func test_a_held_push_in_closes_slowly_holds_until_released_then_eases_back() -> void:
	rig.snap(P, O)
	rig.push_in_held(0.35, 1.0)
	_step(30)
	assert_between(rig.push_amount(), 0.1, 0.3, "half way in after half the time")
	_step(30)
	assert_almost_eq(rig.push_amount(), 0.35, 1e-4, "in after a second")
	_step(60)
	assert_almost_eq(rig.push_amount(), 0.35, 1e-6, "held, not frozen, until released")
	rig.release_push_in()
	_step(12)
	assert_between(rig.push_amount(), 0.01, 0.349, "easing back")
	_step(12)
	assert_eq(rig.push_amount(), 0.0, "back after 0.4 s")


func test_a_released_push_in_before_it_is_in_eases_out_from_where_it_got() -> void:
	rig.snap(P, O)
	rig.push_in_held(0.35, 1.0)
	_step(30)
	var got: float = rig.push_amount()
	rig.release_push_in()
	_step()
	assert_true(rig.push_amount() <= got + 1e-6, "no further in once released")
	_step(30)
	assert_eq(rig.push_amount(), 0.0, "out")


func test_reduce_flashes_turns_the_held_push_in_off_too() -> void:
	rig.push_in_scale = 0.0
	rig.push_in_held(0.35, 1.0)
	_step(30)
	assert_eq(rig.push_amount(), 0.0)


func test_a_push_in_moves_toward_the_look_point_not_off_the_line() -> void:
	rig.snap(P, O)
	rig.push_in(0.25)
	_step(3)
	var want: Vector3 = rig.rig_position.lerp(rig.rig_look, 0.25)
	assert_almost_eq(rig.transform.origin, want, Vector3.ONE * 1e-3)
	assert_eq(rig.fov, rig.base_fov, "a push-in, not a field-of-view kick")


## A second push-in during the first goes on from where the camera is.
func test_a_second_push_in_carries_on_from_the_first() -> void:
	rig.snap(P, O)
	rig.push_in(0.15)
	_step(3)
	_step(10)
	var now: float = rig.push_amount()
	rig.push_in(0.25)
	assert_almost_eq(rig.push_amount(), now, 1e-6, "no jump")
	_step(3)
	assert_almost_eq(rig.push_amount(), 0.25, 1e-4)


## Depth of field comes in with the push-in: a far blur past the look point
## that clears as it eases out.
func test_the_push_in_brings_a_far_blur_that_clears_as_it_eases_out() -> void:
	rig.snap(P, O)
	assert_null(rig.attributes, "no blur at rest")
	rig.push_in(0.25)
	_step(3)
	var dof := rig.attributes as CameraAttributesPractical
	assert_not_null(dof)
	assert_true(dof.dof_blur_far_enabled)
	assert_false(dof.dof_blur_near_enabled, "the fighters stay sharp")
	assert_gt(dof.dof_blur_far_distance, _reach(), "past the look point")
	var full: float = dof.dof_blur_amount
	assert_gt(full, 0.0)
	_step(12)
	assert_between(dof.dof_blur_amount, 0.001, full - 0.001, "clearing")
	_step(20)
	assert_null(rig.attributes, "gone with the push-in")


func test_without_depth_of_field_the_push_in_has_no_blur() -> void:
	rig.dof_allowed = false
	rig.snap(P, O)
	rig.push_in(0.25)
	_step(3)
	assert_almost_eq(rig.push_amount(), 0.25, 1e-4, "the push-in itself still happens")
	assert_null(rig.attributes)


## Reduce flashes and shaking turns the push-in (and so its blur) off.
func test_the_push_in_scale_turns_it_off() -> void:
	rig.push_in_scale = 0.0
	rig.snap(P, O)
	var rest: Transform3D = rig.transform
	rig.push_in(0.25)
	_step(3)
	assert_eq(rig.push_amount(), 0.0)
	assert_null(rig.attributes)
	assert_almost_eq(rig.transform.origin, rest.origin, Vector3.ONE * 1e-4)


func test_end_push_in_clears_it() -> void:
	rig.snap(P, O)
	rig.push_in(0.25)
	_step(3)
	rig.end_push_in()
	assert_eq(rig.push_amount(), 0.0)
	assert_null(rig.attributes)


# ------------------------------------------------------------------ cinematic shots (milestone-1 task 97)

func _shot_view(dof: bool = true) -> Dictionary:
	return {"pos": Vector3(2.0, 1.4, 0.5), "look": Vector3(0.0, 1.2, 1.0), "fov": 40.0,
		"depth_of_field": dof, "dof_margin": 1.0, "dof_amount": 0.1}


func test_a_shot_takes_the_camera_and_hands_back_to_the_gameplay_camera() -> void:
	rig.snap(P, O)
	var rest: Transform3D = rig.transform
	rig.show_shot(_shot_view())
	_step()
	assert_true(rig.in_shot())
	assert_almost_eq(rig.transform.origin, Vector3(2.0, 1.4, 0.5), Vector3.ONE * 1e-4, "where the shot puts it")
	var ahead: Vector3 = -rig.transform.basis.z
	assert_almost_eq(ahead.dot((Vector3(0.0, 1.2, 1.0) - Vector3(2.0, 1.4, 0.5)).normalized()), 1.0, 1e-4, "looking at its look point")
	assert_almost_eq(rig.fov, 40.0, 1e-4, "its lens")
	var dof := rig.attributes as CameraAttributesPractical
	assert_not_null(dof, "its depth of field")
	assert_almost_eq(dof.dof_blur_far_distance, Vector3(2.0, 1.4, 0.5).distance_to(Vector3(0.0, 1.2, 1.0)) + 1.0, 1e-4)
	assert_almost_eq(dof.dof_blur_amount, 0.1, 1e-6)
	rig.end_shot()
	_step()
	assert_false(rig.in_shot())
	assert_almost_eq(rig.transform.origin, rest.origin, Vector3.ONE * 1e-3, "back behind the player")
	assert_eq(rig.fov, rig.base_fov)
	assert_null(rig.attributes, "and its blur gone")


func test_a_shot_has_no_blur_where_the_preset_drops_depth_of_field_or_the_shot_has_none() -> void:
	rig.snap(P, O)
	rig.show_shot(_shot_view(false))
	_step()
	assert_null(rig.attributes, "the shot has none")
	rig.dof_allowed = false
	rig.show_shot(_shot_view(true))
	_step()
	assert_null(rig.attributes, "the preset has none (Low)")


func test_a_shot_takes_no_push_in_or_kick_and_shakes_at_the_shake_scale() -> void:
	rig.snap(P, O)
	rig.show_shot(_shot_view())
	rig.push_in(0.25)
	rig.kick_fov(6.0)
	_step()
	assert_almost_eq(rig.transform.origin, Vector3(2.0, 1.4, 0.5), Vector3.ONE * 1e-4, "no push-in")
	assert_almost_eq(rig.fov, 40.0, 1e-4, "no kick")
	rig.shake_scale = 0.0
	rig.add_shake(1.0)
	_step()
	assert_almost_eq(rig.transform.origin, Vector3(2.0, 1.4, 0.5), Vector3.ONE * 1e-4, "Reduce flashes' scale reaches its shake")
	rig.shake_scale = 1.0
	rig.add_shake(1.0)
	_step()
	assert_gt(rig.transform.origin.distance_to(Vector3(2.0, 1.4, 0.5)), 1e-4, "it shakes")
