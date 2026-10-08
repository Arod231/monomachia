extends GutTest
## Air smears (milestone-1 task 37, in place of plan task 18.3's brush-stroke
## trails): a short haze ribbon behind the blade's last third, laid down on
## the effect clock only while the trail rules say so and only as fast as the
## tip moves, tinted for unblockables and ultimates, bending the scene behind
## it, clear of the attacker's body, and frozen in hit-stop.

const DT: float = SimConst.DT

var smear: AirSmear


func before_each() -> void:
	smear = AirSmear.new()
	add_child_autofree(smear)


# ------------------------------------------------------------------ the ribbon on its own

func test_the_span_is_the_blades_last_third() -> void:
	var base: Vector3 = Vector3(0.0, 1.0, 0.0)
	var tip: Vector3 = Vector3(0.0, 1.0, 0.9)
	var span: PackedVector3Array = AirSmear.span(base, tip)
	assert_almost_eq(span[0], Vector3(0.0, 1.0, 0.6), Vector3.ONE * 1e-6, "a third of the blade back from the tip")
	assert_eq(span[1], tip)
	assert_almost_eq(AirSmear.SHARE, 1.0 / 3.0, 1e-9)


## Sweeps a blade of span `width` round a quarter circle of radius 1 over
## `frames` frames from `from`, a sample a frame (a fast cut: the tip moves
## about 0.4 m a frame over 5 frames).
func _sweep(from: float, frames: int, strength: float = 1.0, kind: StringName = TrailState.NORMAL, radius: float = 1.0) -> void:
	for k: int in frames:
		var ang: float = PI * 0.5 * float(k) / float(maxi(1, frames - 1))
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		smear.feed(from + float(k), Vector3(0.0, 1.2, 0.0) + dir * radius * 0.5, Vector3(0.0, 1.2, 0.0) + dir * radius, strength, kind)
	smear.update(from + float(frames - 1))


func test_nothing_is_laid_while_the_rules_say_no_smear() -> void:
	_sweep(0.0, 5, 0.0)
	assert_eq(smear.sample_count(), 0)
	assert_eq(smear.vertices().size(), 0, "no ribbon")


func test_a_fast_sweep_lays_a_ribbon_from_the_blade_back() -> void:
	_sweep(10.0, 5)
	assert_eq(smear.sample_count(), 5)
	var v: PackedVector3Array = smear.vertices()
	assert_eq(v.size(), 2 * (4 * (AirSmear.SUBDIVISIONS + 1) + 1), "two vertices a point, subdivided between samples")
	assert_almost_eq(v[1], Vector3(0.0, 1.2, 1.0), Vector3.ONE * 1e-5, "its head at the blade's tip now")
	assert_almost_eq(v[v.size() - 1], Vector3(1.0, 1.2, 0.0), Vector3.ONE * 1e-5, "its tail where the tip was 4 frames ago")
	for p: Vector3 in v:
		assert_almost_eq(p.y, 1.2, 1e-5, "in the blade's plane")


## Only fast swings smear: nothing from a tip moving under SLOW, all of it
## from FAST, and between in between.
func test_only_a_fast_tip_smears() -> void:
	assert_eq(AirSmear.speed_share(AirSmear.SLOW), 0.0)
	assert_eq(AirSmear.speed_share(AirSmear.FAST), 1.0)
	assert_between(AirSmear.speed_share((AirSmear.SLOW + AirSmear.FAST) * 0.5), 0.2, 0.8)
	# a guard shift: the tip moving 2 cm a frame (1.2 m/s)
	_sweep(0.0, 8, 1.0, TrailState.NORMAL, 0.03)
	for c: Color in smear.colors():
		assert_eq(c.a, 0.0, "a slow tip leaves nothing to see")
	smear.clear()
	_sweep(0.0, 5)
	assert_almost_eq(smear.colors()[0].a, 1.0, 1e-6, "a cut's strike, whole")


func test_the_smear_tapers_and_fades_toward_its_tail() -> void:
	_sweep(0.0, 6)
	var v: PackedVector3Array = smear.vertices()
	var c: PackedColorArray = smear.colors()
	var head_width: float = v[0].distance_to(v[1])
	var tail_width: float = v[v.size() - 2].distance_to(v[v.size() - 1])
	assert_almost_eq(head_width, 0.5, 1e-5, "the span's width at the blade")
	assert_lt(tail_width, head_width * 0.7, "narrower at the tail")
	assert_lt(c[c.size() - 1].a, c[0].a, "fading toward the tail")


## A plain swing's smear is a pale sheen; an unblockable's keeps a faint red
## and an ultimate's its gold until the 危 and glint (task 82) take over.
func test_the_smear_takes_its_kinds_tint() -> void:
	for kind: StringName in [TrailState.NORMAL, TrailState.DANGER, TrailState.ULT]:
		smear.clear()
		_sweep(0.0, 3, 1.0, kind)
		var c: Color = smear.colors()[0]
		var want: Color = AirSmear.TINTS[kind]
		assert_almost_eq(Vector3(c.r, c.g, c.b), Vector3(want.r, want.g, want.b), Vector3.ONE * 1e-6, String(kind))
	var pale: Color = AirSmear.TINTS[TrailState.NORMAL]
	assert_lt(pale.s, 0.15, "a plain swing's sheen is all but colourless")
	assert_gt(AirSmear.TINTS[TrailState.DANGER].r, AirSmear.TINTS[TrailState.DANGER].g * 3.0, "red")
	assert_gt(AirSmear.TINTS[TrailState.ULT].g, AirSmear.TINTS[TrailState.ULT].b * 2.0, "gold")


## The smear bends the scene behind it like heat haze: its shader reads the
## screen, blends over it unlit, and its sheen stays faint.
func test_the_smear_bends_the_scene_behind_it() -> void:
	var m: ShaderMaterial = smear.material_override as ShaderMaterial
	assert_not_null(m)
	assert_eq(m, AirSmear.shared_material(), "one material for every smear")
	var code: String = m.shader.code
	assert_true(code.contains("hint_screen_texture"), "it reads the scene behind it")
	assert_true(code.contains("unshaded") and code.contains("blend_mix"))
	assert_false(code.contains("ink"), "no ink: the brush strokes retired")
	assert_true(code.contains("uniform float sheen = 0.2;"), "a faint sheen")


func test_a_sample_lasts_its_life_on_the_effect_clock() -> void:
	_sweep(0.0, 4)
	var life: int = int(AirSmear.LIFE_FRAMES)
	smear.update(3.0 + float(life - 4))
	assert_eq(smear.sample_count(), 4, "the oldest is just short of its life")
	smear.update(3.0 + float(life - 3))
	assert_eq(smear.sample_count(), 3, "the oldest gone at its life")
	smear.update(3.0 + float(life))
	assert_eq(smear.sample_count(), 0, "all gone a life after the last")
	assert_eq(smear.vertices().size(), 0)
	assert_lt(AirSmear.LIFE_FRAMES, 8.0, "shorter than the brush strokes' 8 frames")


func test_the_same_frame_shown_twice_lays_nothing_new() -> void:
	_sweep(0.0, 4)
	var before: PackedVector3Array = smear.vertices()
	var colors: PackedColorArray = smear.colors()
	# hit-stop or pause: the clock and the blade stand still
	var dir: Vector3 = Vector3(cos(PI * 0.5), 0.0, sin(PI * 0.5))
	for k: int in 5:
		smear.feed(3.0, Vector3(0.0, 1.2, 0.0) + dir * 0.5, Vector3(0.0, 1.2, 0.0) + dir, 1.0, TrailState.NORMAL)
		smear.update(3.0)
	assert_eq(smear.sample_count(), 4)
	assert_eq(smear.vertices(), before, "the ribbon stands still")
	assert_eq(smear.colors(), colors, "and keeps its strength")


func test_a_clock_that_went_back_starts_over() -> void:
	_sweep(100.0, 4)
	_sweep(2.0, 2)
	assert_eq(smear.sample_count(), 2, "a new round's clock")


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
## the attack frame, the right hand's trail rules and the ribbon.
func _play(steps: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f: Fighter = host.fighter(0)
	for k: int in steps:
		host.step(1)
		view.render(DT)
		rows.append({
			"frame": f.atk.frame if f.atk != null else -1,
			"on": TrailState.of(f, host.alpha()).intensity(TrailState.RIGHT),
			"ribbon": view.effects.smear(0, TrailState.RIGHT).vertices(),
		})
	return rows


func test_the_view_keeps_a_smear_per_side_and_hand_and_no_brush_strokes() -> void:
	_start()
	for side: int in 2:
		for hand: int in 2:
			assert_not_null(view.effects.smear(side, hand))
	assert_eq(view.effects.find_children("*", "AirSmear", true, false).size(), 4)
	assert_false(ResourceLoader.exists("res://shaders/brush_trail.gdshader"), "the brush strokes' shader retired")


func test_a_katana_light_smears_only_in_its_strike() -> void:
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
	assert_gt(first_on, 0, "the rules turned the smear on")
	var shown: bool = false
	for k: int in rows.size():
		var shows: bool = (rows[k]["ribbon"] as PackedVector3Array).size() > 0
		shown = shown or shows
		if k < first_on:
			assert_false(shows, "step %d: nothing in the wind-up" % k)
		elif k >= last_on + int(AirSmear.LIFE_FRAMES) + 1:
			assert_false(shows, "step %d: gone once its last sample ages out" % k)
	assert_true(shown, "the cut smeared")
	assert_eq(view.effects.smear(0, TrailState.LEFT).vertices().size(), 0, "one blade, one smear")
	assert_eq(view.effects.smear(1, TrailState.RIGHT).vertices().size(), 0, "the dummy never swung")


## Runs each fighter's modifier stack now, as the frame's skeleton update
## would: a weapon riding the clip's hands (the Katana, milestone-1 task
## 135) is placed there, and the next draw's smear reads it.
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


## Local-only: the Katana rides the clip's hands (milestone-1 task 135), and
## the CC0 stand-ins aren't keyed for it, so its blade crosses their bodies.
## Each light's strike smears, and the smear never enters the attacker.
func test_local_the_smear_stays_clear_of_the_attackers_body() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
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
			var colors: PackedColorArray = view.effects.smear(0, TrailState.RIGHT).colors()
			var v: PackedVector3Array = view.effects.smear(0, TrailState.RIGHT).vertices()
			for j: int in v.size():
				if colors[j].a > 0.01:
					nearest = minf(nearest, _capsule_distance(v[j], 0))
					laid += 1
		assert_gt(laid, 0, "%s smeared" % id)
		assert_gt(nearest, 0.0, "%s: the smear never enters the attacker's body (closest %.3f m)" % [id, nearest])
		host.queue_free()
		await get_tree().process_frame


func test_the_smear_freezes_in_hit_stop() -> void:
	_start()
	var f: Fighter = host.fighter(0)
	f.start_attack(&"k_l1")
	while f.atk.frame < f.atk.def.startup + 3:
		host.step(1)
		view.render(DT)
	assert_gt(view.effects.smear(0, TrailState.RIGHT).sample_count(), 0, "mid-cut")
	# the hit-stop's first step shows the impact frame (the alpha held at 1);
	# from there the ribbon holds
	host.world.hitstop = 8
	host.step(1)
	view.render(DT)
	var ribbon: PackedVector3Array = view.effects.smear(0, TrailState.RIGHT).vertices()
	for k: int in 6:
		host.step(1)
		view.render(DT)
		assert_eq(view.effects.smear(0, TrailState.RIGHT).vertices(), ribbon, "held through hit-stop step %d" % k)
	for k: int in 3:
		host.step(1)
		view.render(DT)
	assert_ne(view.effects.smear(0, TrailState.RIGHT).vertices(), ribbon, "and moves on after")


func test_daggers_smear_the_striking_hands() -> void:
	_start(&"daggers")
	var f: Fighter = host.fighter(0)
	assert_true(f.start_attack(&"d_l3"), "Twin Rip, both hands")
	var both: bool = false
	for k: int in f.atk.def.startup + f.atk.def.active + 1:
		host.step(1)
		view.render(DT)
		if view.effects.smear(0, TrailState.RIGHT).sample_count() > 0 and view.effects.smear(0, TrailState.LEFT).sample_count() > 0:
			both = true
	assert_true(both, "a smear from each dagger")


## Bare hands' eight movement attacks smear along the striking limb
## (milestone-1 task 95): the span runs from the joint behind the limb's end
## to past it, the fist past the wrist, the foot past the ankle, the knee
## past its joint.
const LIMB_ENDS: Dictionary[StringName, String] = {
	&"right_hand": "RightHand", &"left_hand": "LeftHand", &"right_foot": "RightFoot", &"left_foot": "LeftFoot",
	&"right_knee": "RightLowerLeg", &"left_knee": "LeftLowerLeg",
}


func test_a_limb_span_runs_along_the_striking_limb() -> void:
	_start()
	var fv: FighterView = view.fighters[0]
	var sk: Skeleton3D = fv.model.skeleton
	for part: StringName in LIMB_ENDS:
		var span: PackedVector3Array = fv.limb_span(part)
		assert_eq(span.size(), 2, String(part))
		var end: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(LIMB_ENDS[part])).origin
		assert_lt(span[1].distance_to(end), 0.25, "%s: its tip at the %s" % [part, LIMB_ENDS[part]])
		assert_between(span[0].distance_to(span[1]), 0.15, 0.8, "%s: a limb's length back from the tip" % part)
	assert_eq(fv.limb_span(&"body").size(), 0, "no span for a part that isn't a limb")


func test_a_bare_hand_strike_smears_its_striking_side_only() -> void:
	for pair: Array in [[&"f_sh", TrailState.RIGHT], [&"f_dl", TrailState.LEFT]]:
		_start()
		var f: Fighter = host.fighter(0)
		f.armed = false
		assert_true(f.start_attack(pair[0]), String(pair[0]))
		var laid: Array[int] = [0, 0]
		for k: int in f.atk.def.startup + f.atk.def.active + 1:
			host.step(1)
			view.render(DT)
			for hand: int in 2:
				laid[hand] = maxi(laid[hand], view.effects.smear(0, hand).sample_count())
		var side: int = pair[1]
		assert_gt(laid[side], 0, "%s smears its striking limb" % pair[0])
		assert_eq(laid[1 - side], 0, "%s: and nothing on the other side" % pair[0])
		host.queue_free()
		await get_tree().process_frame


func test_round_start_clears_the_smears() -> void:
	_start()
	var f: Fighter = host.fighter(0)
	f.start_attack(&"k_l1")
	_play(f.atk.def.startup + 3)
	assert_gt(view.effects.smear(0, TrailState.RIGHT).sample_count(), 0)
	host.sim_event.emit({"t": &"roundStart", "round": 2})
	assert_eq(view.effects.smear(0, TrailState.RIGHT).sample_count(), 0)
