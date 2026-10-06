extends GutTest
## Blood (milestone-1 task 38): a blade hit throws a burst of blood, stains
## the defender's clothes where it landed and the attacker's blade, and
## splatters the floor. Stains on bodies and blades last the whole match;
## the floor's splatter lasts until the round ends and fades in the next
## round's start. The Blood setting scales it (Reduced: less of everything)
## or removes it (Off); fists draw none; Reduce flashes leaves it alone; the
## Low preset keeps it.

var host: MatchHost
var view: MatchView
var settings: GameSettings
var blood: BloodEffects


func before_each() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	add_child_autofree(host)
	view = host.get_node("View")
	settings = GameSettings.new()
	view.use_settings(settings)
	blood = view.blood
	host.start(MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"),
		7,
		ArenaScenes.STANDIN,
	))
	host.step(Match.INTRO_FRAMES + 2)
	view.render(0.016)


## Fighter 0 cuts fighter 1 at chest height, between them.
func _hit(heavy: bool = false, sound: StringName = &"blade") -> Dictionary:
	var a: Vector3 = host.display_position(0)
	var b: Vector3 = host.display_position(1)
	# where a blade sweep's contact lies: near the defender's middle
	var at: Vector3 = b + (a - b).normalized() * 0.1 + Vector3(0.0, 1.3, 0.0)
	var e := {"t": &"hit", "attacker": 0, "target": 1, "attack": &"k_l1", "damage": 10.0, "posture": 5.0,
		"pos": {"x": at.x, "y": at.y, "z": at.z}, "heavy": heavy, "sound": sound, "backstab": false,
		"weapon": &"katana", "defender_weapon": &"katana"}
	host.sim_event.emit(e)
	return e


func _settle() -> void:
	view.render(0.016)


func test_the_plan_under_each_setting() -> void:
	var light := {"t": &"hit", "heavy": false, "sound": &"blade"}
	var heavy := {"t": &"hit", "heavy": true, "sound": &"blade"}
	var on := BloodEffects.plan(light, GameSettings.BLOOD_ON)
	var on_heavy := BloodEffects.plan(heavy, GameSettings.BLOOD_ON)
	var reduced := BloodEffects.plan(light, GameSettings.BLOOD_REDUCED)
	for key: String in ["burst", "drop_size", "stain", "splat", "blade"]:
		assert_gt(float(on[key]), 0.0, "On: %s" % key)
		assert_gt(float(reduced[key]), 0.0, "Reduced still bleeds: %s" % key)
		assert_lt(float(reduced[key]), float(on[key]), "Reduced is less: %s" % key)
		assert_true(float(on_heavy[key]) >= float(on[key]), "a heavy as much or more: %s" % key)
	assert_gt(int(on_heavy["burst"]), int(on["burst"]))
	assert_eq(BloodEffects.plan(light, GameSettings.BLOOD_OFF), {}, "Off: none")
	for level: StringName in GameSettings.BLOOD_LEVELS:
		assert_eq(BloodEffects.plan({"t": &"hit", "heavy": true, "sound": &"fist"}, level), {}, "fists draw no blood")
	assert_eq(BloodEffects.plan({"t": &"block", "heavy": true}, GameSettings.BLOOD_ON), {}, "a block draws none")
	for sound: StringName in [&"dagger", &"colossal"]:
		assert_false(BloodEffects.plan({"t": &"hit", "heavy": false, "sound": sound}, GameSettings.BLOOD_ON).is_empty(), "%s cuts" % sound)


func test_a_blade_hit_bursts_stains_the_defender_and_the_blade_and_splatters_the_floor() -> void:
	_hit()
	_settle()
	assert_gt(blood.droplet_count(), 0, "a burst in the air")
	assert_eq(blood.stain_count(1), 1, "a stain on the defender")
	assert_eq(blood.stain_count(0), 0, "none on the attacker")
	assert_eq(blood.splat_count(), 1, "a splatter on the floor")
	assert_gt(blood.blade_amount(0), 0.0, "blood on the attacker's blade")
	assert_eq(blood.blade_amount(1), 0.0)
	var mats: Array[ShaderMaterial] = BloodEffects.body_materials(view.fighters[1])
	assert_gt(mats.size(), 3, "the defender's clothes, skin and hat")
	for m: ShaderMaterial in mats:
		assert_eq(int(m.get_shader_parameter(&"blood_stain_count")), 1)
	var blades: Array[ShaderMaterial] = BloodEffects.blade_materials(view.fighters[0])
	assert_gt(blades.size(), 0, "the Katana's blade")
	for m: ShaderMaterial in blades:
		assert_almost_eq(float(m.get_shader_parameter(&"blood_amount")), blood.blade_amount(0), 1e-6)
	for m: ShaderMaterial in BloodEffects.body_materials(view.fighters[0]):
		assert_eq(int(m.get_shader_parameter(&"blood_stain_count")), 0, "the attacker's clothes are clean")


## The stain sits on the side of the defender the blow came from, and rides
## the body as it moves.
func test_a_stain_rides_the_body() -> void:
	_hit()
	_settle()
	var before: Vector3 = blood.stain_world(1, 0)
	var chest: Vector3 = host.display_position(1) + Vector3(0.0, 1.3, 0.0)
	assert_lt(before.distance_to(chest), 0.6, "on the defender's body")
	var toward: Vector3 = (host.display_position(0) - host.display_position(1)).normalized()
	assert_gt((before - chest).dot(toward), 0.0, "on the side the blow came from")
	view.fighters[1].global_position += Vector3(1.0, 0.0, 0.0)
	blood.update(view.effects.clock())
	assert_almost_eq(blood.stain_world(1, 0), before + Vector3(1.0, 0.0, 0.0), Vector3.ONE * 1e-3, "carried with the body")


func test_reduced_draws_less_and_off_none() -> void:
	settings.blood = GameSettings.BLOOD_REDUCED
	settings.changed.emit()
	_hit(true)
	_settle()
	var reduced_drops: int = blood.droplet_count()
	var reduced_blade: float = blood.blade_amount(0)
	assert_gt(reduced_drops, 0)
	assert_eq(blood.stain_count(1), 1)
	host.start(host.config)
	settings.blood = GameSettings.BLOOD_ON
	settings.changed.emit()
	_hit(true)
	_settle()
	assert_gt(blood.droplet_count(), reduced_drops, "On throws more")
	assert_gt(blood.blade_amount(0), reduced_blade)
	assert_gt(blood.splat_size(0), 0.0)
	host.start(host.config)
	settings.blood = GameSettings.BLOOD_OFF
	settings.changed.emit()
	_hit(true)
	_settle()
	assert_eq(blood.droplet_count(), 0)
	assert_eq(blood.stain_count(1), 0)
	assert_eq(blood.splat_count(), 0)
	assert_eq(blood.blade_amount(0), 0.0)


## Turning blood off mid-match hides what is there at once.
func test_off_mid_match_hides_the_blood() -> void:
	_hit()
	_settle()
	settings.blood = GameSettings.BLOOD_OFF
	settings.changed.emit()
	_settle()
	for m: ShaderMaterial in BloodEffects.body_materials(view.fighters[1]):
		assert_eq(int(m.get_shader_parameter(&"blood_stain_count")), 0)
	for m: ShaderMaterial in BloodEffects.blade_materials(view.fighters[0]):
		assert_eq(float(m.get_shader_parameter(&"blood_amount")), 0.0)
	assert_false(blood.splats.visible, "the floor's splatter hidden")
	assert_false(blood.droplets.visible)


func test_fists_draw_no_blood() -> void:
	_hit(true, &"fist")
	_settle()
	assert_eq(blood.droplet_count(), 0)
	assert_eq(blood.stain_count(1), 0)
	assert_eq(blood.splat_count(), 0)


## Stains last the whole match; the floor's splatter lasts the round and
## fades in the next round's start; a new match is clean.
func test_stains_last_the_match_and_the_splatter_the_round() -> void:
	_hit()
	_settle()
	host.sim_event.emit({"t": &"roundStart", "round": 2})
	_settle()
	assert_eq(blood.stain_count(1), 1, "the stain stays through the round's reset")
	assert_gt(blood.blade_amount(0), 0.0, "and the blade's")
	assert_eq(blood.splat_count(), 1, "the splatter fading, still there")
	assert_lt(blood.splat_alpha(0), 1.0 + 1e-6)
	# the round's start beat runs on (the effect clock, without stepping a
	# duel that might land blows of its own)
	blood.update(view.effects.clock() + BloodEffects.SPLAT_FADE_FRAMES + 2)
	assert_eq(blood.splat_count(), 0, "faded away")
	assert_eq(blood.stain_count(1), 1)
	host.start(host.config)
	_settle()
	assert_eq(blood.stain_count(1), 0, "a new match starts clean")
	assert_eq(blood.blade_amount(0), 0.0)


func test_stains_splatter_and_blade_blood_are_capped() -> void:
	for i: int in 60:
		_hit(i % 3 == 0)
	_settle()
	var on: Dictionary = BloodEffects.PROFILES[GameSettings.BLOOD_ON]
	assert_eq(blood.stain_count(1), int(on["stains"]))
	assert_eq(blood.splat_count(), int(on["splats"]))
	assert_almost_eq(blood.blade_amount(0), 1.0, 1e-6)


## The burst keeps the effect clock: frozen in hit-stop like the sparks.
func test_the_burst_holds_still_in_hit_stop() -> void:
	_hit(true)
	host.world.hitstop = 10
	view.render(0.016)
	var held: Array[Vector3] = blood.droplet_positions()
	host.step(3)
	view.render(0.016)
	assert_eq(blood.droplet_positions(), held, "the clock stands still through the hit-stop's steps")
	host.world.hitstop = 0
	host.step(4)
	view.render(0.016)
	assert_ne(blood.droplet_positions(), held, "and moves on after")


## Blood follows the Blood setting only: Reduce flashes leaves it alone, and
## the Low preset keeps the floor's splatter (no minor-decal group).
func test_reduce_flashes_and_the_low_preset_keep_blood() -> void:
	settings.reduce_flashes = true
	settings.changed.emit()
	_hit()
	_settle()
	assert_eq(blood.stain_count(1), 1)
	assert_eq(blood.splat_count(), 1)
	for d: Node in blood.splats.get_children():
		assert_false(d.is_in_group(GraphicsApplier.GROUP_MINOR_DECAL), "the Low preset keeps it")
		assert_eq((d as Decal).cull_mask & FighterModel.LAYERS, 0, "the splatter stays off the fighters")
