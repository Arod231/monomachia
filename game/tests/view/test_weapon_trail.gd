extends GutTest
## Brush-stroke trails (plan task 18.3): the ribbon over the blade's trailing
## span, laid down on the effect clock, only while the trail rules say so,
## clear of the attacker's body, and frozen in hit-stop.

const DT: float = SimConst.DT

var trail: WeaponTrail


func before_each() -> void:
	trail = WeaponTrail.new()
	add_child_autofree(trail)


# ------------------------------------------------------------------ the ribbon on its own

func test_the_span_is_the_trail_width_back_from_the_tip_or_the_whole_blade() -> void:
	var base: Vector3 = Vector3(0.0, 1.0, 0.0)
	var tip: Vector3 = Vector3(0.0, 1.0, 1.0)
	var span: PackedVector3Array = WeaponTrail.span(base, tip, 0.55)
	assert_almost_eq(span[0], Vector3(0.0, 1.0, 0.45), Vector3.ONE * 1e-6, "0.55 m back from the tip")
	assert_eq(span[1], tip)
	span = WeaponTrail.span(base, tip, 1.4)
	assert_eq(span[0], base, "never past the blade's base")


## Sweeps a blade of span 0.5 m round a quarter circle over `frames` frames
## from `from`, a sample a frame.
func _sweep(from: float, frames: int, strength: float = 1.0, kind: StringName = TrailState.NORMAL) -> void:
	for k: int in frames:
		var ang: float = PI * 0.5 * float(k) / float(maxi(1, frames - 1))
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		trail.feed(from + float(k), Vector3(0.0, 1.2, 0.0) + dir * 0.5, Vector3(0.0, 1.2, 0.0) + dir, strength, kind)
	trail.update(from + float(frames - 1))


func test_nothing_is_laid_while_the_trail_is_off() -> void:
	_sweep(0.0, 5, 0.0)
	assert_eq(trail.sample_count(), 0)
	assert_eq(trail.vertices().size(), 0, "no ribbon")


func test_a_sweep_lays_a_ribbon_from_the_blade_back() -> void:
	_sweep(10.0, 5)
	assert_eq(trail.sample_count(), 5)
	var v: PackedVector3Array = trail.vertices()
	assert_eq(v.size(), 2 * (4 * (WeaponTrail.SUBDIVISIONS + 1) + 1), "two vertices a point, subdivided between samples")
	assert_almost_eq(v[1], Vector3(0.0, 1.2, 1.0), Vector3.ONE * 1e-5, "its head at the blade's tip now")
	assert_almost_eq(v[v.size() - 1], Vector3(1.0, 1.2, 0.0), Vector3.ONE * 1e-5, "its tail where the tip was 4 frames ago")
	for p: Vector3 in v:
		assert_almost_eq(p.y, 1.2, 1e-5, "in the blade's plane")
		var r: float = Vector2(p.x, p.z).length()
		assert_between(r, 0.5 - 1e-3, 1.0 + 0.03, "between the span's ends (a little overshoot on the curve)")


func test_the_stroke_tapers_and_fades_toward_its_tail() -> void:
	_sweep(0.0, 6)
	var v: PackedVector3Array = trail.vertices()
	var c: PackedColorArray = trail.colors()
	var head_width: float = v[0].distance_to(v[1])
	var tail_width: float = v[v.size() - 2].distance_to(v[v.size() - 1])
	assert_almost_eq(head_width, 0.5, 1e-5, "full width at the blade")
	assert_lt(tail_width, head_width * 0.6, "narrow at the tail")
	assert_almost_eq(c[0].a, 1.0, 1e-6, "solid at the blade")
	assert_lt(c[c.size() - 1].a, c[0].a, "fading toward the tail")


func test_the_trail_takes_its_kinds_colour() -> void:
	for kind: StringName in [TrailState.NORMAL, TrailState.DANGER, TrailState.ULT]:
		trail.clear()
		_sweep(0.0, 3, 1.0, kind)
		var c: Color = trail.colors()[0]
		var want: Color = WeaponTrail.COLORS[kind]
		assert_almost_eq(Vector3(c.r, c.g, c.b), Vector3(want.r, want.g, want.b), Vector3.ONE * 1e-6, String(kind))
	assert_eq(WeaponTrail.COLORS[TrailState.NORMAL], Color("dfe6ff"), "white")
	assert_eq(WeaponTrail.COLORS[TrailState.DANGER], Color("ff3020"), "red")
	assert_eq(WeaponTrail.COLORS[TrailState.ULT], Color("ffc040"), "gold")


func test_a_sample_lasts_eight_frames_on_the_effect_clock() -> void:
	_sweep(0.0, 4)
	trail.update(3.0 + 4.0)
	assert_eq(trail.sample_count(), 4, "the oldest is 7 frames old")
	trail.update(3.0 + 5.0)
	assert_eq(trail.sample_count(), 3, "8 frames: gone")
	trail.update(3.0 + 8.0)
	assert_eq(trail.sample_count(), 0, "all gone 8 frames after the last")
	assert_eq(trail.vertices().size(), 0)


func test_the_same_frame_shown_twice_lays_nothing_new() -> void:
	_sweep(0.0, 4)
	var before: PackedVector3Array = trail.vertices()
	# hit-stop or pause: the clock and the blade stand still
	var dir: Vector3 = Vector3(cos(PI * 0.5), 0.0, sin(PI * 0.5))
	for k: int in 5:
		trail.feed(3.0, Vector3(0.0, 1.2, 0.0) + dir * 0.5, Vector3(0.0, 1.2, 0.0) + dir, 1.0, TrailState.NORMAL)
		trail.update(3.0)
	assert_eq(trail.sample_count(), 4)
	assert_eq(trail.vertices(), before, "the ribbon stands still")


func test_a_clock_that_went_back_starts_over() -> void:
	_sweep(100.0, 4)
	_sweep(2.0, 2)
	assert_eq(trail.sample_count(), 2, "a new round's clock")


# ------------------------------------------------------------------ in a match, on the real fighters

var host: MatchHost
var view: MatchView


func _start(weapon: StringName = &"katana") -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	view = host.get_node("View")
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", weapon), dummy, 3, ArenaScenes.STANDIN)
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 5)
	view.render(DT)


## Steps one frame at a time, drawing each, and returns a row per frame:
## the attack frame, the right hand's trail strength and the ribbon.
func _play(steps: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f: Fighter = host.fighter(0)
	for k: int in steps:
		host.step(1)
		view.render(DT)
		rows.append({
			"frame": f.atk.frame if f.atk != null else -1,
			"on": TrailState.of(f, host.alpha()).intensity(TrailState.RIGHT),
			"ribbon": view.effects.trail(0, TrailState.RIGHT).vertices(),
		})
	return rows


func test_the_view_keeps_a_trail_per_side_and_hand() -> void:
	_start()
	for side: int in 2:
		for hand: int in 2:
			assert_not_null(view.effects.trail(side, hand))
	assert_eq(view.effects.get_child_count(), 7, "three pools and four trails, however many effects")


func test_a_katana_light_lays_a_ribbon_only_while_its_trail_is_on() -> void:
	_start()
	var f: Fighter = host.fighter(0)
	assert_true(f.start_attack(&"k_l1"))
	var def: AttackDef = f.atk.def
	var rows: Array[Dictionary] = _play(def.startup + def.active + 12)
	var first_on: int = -1
	var last_on: int = -1
	for k: int in rows.size():
		if float(rows[k]["on"]) > 0.0:
			if first_on < 0:
				first_on = k
			last_on = k
	assert_gt(first_on, 0, "the trail came on")
	for k: int in rows.size():
		var shows: bool = (rows[k]["ribbon"] as PackedVector3Array).size() > 0
		if k < first_on:
			assert_false(shows, "step %d: no ribbon in the wind-up" % k)
		elif k > first_on and k <= last_on:
			assert_true(shows, "step %d: a ribbon while the trail is on" % k)
		elif k >= last_on + int(WeaponTrail.LIFE_FRAMES) + 1:
			assert_false(shows, "step %d: gone once its last sample ages out" % k)
	assert_eq(view.effects.trail(0, TrailState.LEFT).vertices().size(), 0, "one blade, one trail")
	assert_eq(view.effects.trail(1, TrailState.RIGHT).vertices().size(), 0, "the dummy never swung")


## Runs each fighter's modifier stack now, as the frame's skeleton update
## would: a weapon riding the clip's hands (the Katana, milestone-1 task
## 135) is placed there, and the next draw's trail reads it.
func _pose_skeletons() -> void:
	for fv: FighterView in view.fighters:
		fv.model.skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)


## The shortest distance from p to the hurt capsule of side i as shown.
func _capsule_distance(p: Vector3, i: int) -> float:
	var at: Vector3 = host.display_position(i)
	var body: FighterBody = FighterBody.of(host.config.sides[i].fighter_id)
	var r: float = body.hurt_radius
	var a: Vector3 = at + Vector3(0.0, r, 0.0)
	var b: Vector3 = at + Vector3(0.0, body.hurt_height - r, 0.0)
	var q: Vector3 = Geometry3D.get_closest_point_to_segment(p, a, b)
	return p.distance_to(q) - r


func test_the_ribbon_stays_clear_of_the_attackers_body() -> void:
	for id: StringName in [&"k_l1", &"k_l2", &"k_l3", &"k_l4", &"k_thrust", &"k_sweep"]:
		_start()
		var f: Fighter = host.fighter(0)
		assert_true(f.start_attack(id), String(id))
		var nearest: float = INF
		var laid: int = 0
		for k: int in f.atk.def.startup + f.atk.def.active + f.atk.def.recovery:
			host.step(1)
			view.render(DT)
			_pose_skeletons()
			for p: Vector3 in view.effects.trail(0, TrailState.RIGHT).vertices():
				nearest = minf(nearest, _capsule_distance(p, 0))
				laid += 1
		assert_gt(laid, 0, "%s laid a ribbon" % id)
		assert_gt(nearest, 0.0, "%s: the ribbon never enters the attacker's body (closest %.3f m)" % [id, nearest])
		host.queue_free()
		await get_tree().process_frame


func test_the_ribbon_freezes_in_hit_stop() -> void:
	_start()
	var f: Fighter = host.fighter(0)
	f.start_attack(&"k_l1")
	while f.atk.frame < f.atk.def.startup + 3:
		host.step(1)
		view.render(DT)
	assert_gt(view.effects.trail(0, TrailState.RIGHT).vertices().size(), 0, "mid-cut")
	# the hit-stop's first step shows the impact frame (the alpha held at 1);
	# from there the ribbon holds
	host.world.hitstop = 8
	host.step(1)
	view.render(DT)
	var ribbon: PackedVector3Array = view.effects.trail(0, TrailState.RIGHT).vertices()
	for k: int in 6:
		host.step(1)
		view.render(DT)
		assert_eq(view.effects.trail(0, TrailState.RIGHT).vertices(), ribbon, "held through hit-stop step %d" % k)
	for k: int in 3:
		host.step(1)
		view.render(DT)
	assert_ne(view.effects.trail(0, TrailState.RIGHT).vertices(), ribbon, "and moves on after")


func test_daggers_trail_the_striking_hands() -> void:
	_start(&"daggers")
	var f: Fighter = host.fighter(0)
	assert_true(f.start_attack(&"d_l3"), "Twin Rip, both hands")
	var both: bool = false
	for k: int in f.atk.def.startup + f.atk.def.active + 1:
		host.step(1)
		view.render(DT)
		if view.effects.trail(0, TrailState.RIGHT).vertices().size() > 0 and view.effects.trail(0, TrailState.LEFT).vertices().size() > 0:
			both = true
	assert_true(both, "a ribbon from each dagger")


func test_round_start_clears_the_trails() -> void:
	_start()
	var f: Fighter = host.fighter(0)
	f.start_attack(&"k_l1")
	_play(f.atk.def.startup + 3)
	assert_gt(view.effects.trail(0, TrailState.RIGHT).sample_count(), 0)
	host.sim_event.emit({"t": &"roundStart", "round": 2})
	assert_eq(view.effects.trail(0, TrailState.RIGHT).sample_count(), 0)
