extends GutTest
## The match scene (match_host.tscn) headless: the arena loaded by id, the
## fighters following the rules, the camera following the player,
## and the HUD's announcements timed on rules steps.

var host: MatchHost
var view: MatchView
var hud: MatchHud


func after_each() -> void:
	Roster.reset()


func before_each() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	view = host.get_node("View")
	hud = host.get_node("Hud")


## Computer against computer on the stand-in arena. The tests ask for the
## stand-in by id unless they need the default arena, so they stay fast and
## stable once the shrine is every match's arena.
func _cpu(mode: StringName = MatchConfig.DUEL, seed_value: int = 7) -> MatchConfig:
	return MatchConfig.make(
		mode,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"daggers", 1, &"hard"),
		seed_value,
		ArenaScenes.STANDIN,
	)


func _with_standin(cfg: MatchConfig) -> MatchConfig:
	cfg.arena_id = ArenaScenes.STANDIN
	return cfg


func test_the_scene_builds_the_stage_from_the_config() -> void:
	var cfg: MatchConfig = _cpu()
	cfg.arena_id = MatchConfig.DEFAULT_ARENA
	host.start(cfg)
	assert_not_null(view.arena, "an arena")
	assert_eq(view.arena_id, MatchConfig.DEFAULT_ARENA)
	assert_eq(MatchConfig.DEFAULT_ARENA, ArenaScenes.MOONLIT_SHRINE, "the shrine by default, so it shows once it lands")
	assert_eq(view.arena.scene_file_path, ArenaScenes.scene_path(MatchConfig.DEFAULT_ARENA))
	assert_not_null(view.arena.get_node_or_null("Spawn0"), "spawn and gate markers")
	assert_not_null(view.arena.get_node_or_null("Gate1"))
	assert_eq(view.fighters.size(), 2)
	assert_eq(view.fighters[0].weapon_id, &"katana")
	assert_eq(view.fighters[1].weapon_id, &"daggers")
	assert_ne(view.fighters[0].side_color(), view.fighters[1].side_color())
	for i: int in 2:
		var model: FighterModel = view.fighters[i].model
		assert_eq(model.look.id, host.config.sides[i].fighter_id, "side %d is its fighter" % i)
		assert_eq(model.palette, host.config.sides[i].palette, "in its palette")
		assert_eq(model.weapon_look.id, host.config.sides[i].weapon_id, "holding its weapon")
	assert_true(view.camera.current)
	assert_eq(view.camera.mode, CameraRig.Mode.FOLLOW)
	assert_true(hud.visible)


func test_an_arena_that_cant_be_drawn_is_the_standin_under_its_own_id() -> void:
	var cfg: MatchConfig = _cpu()
	cfg.arena_id = &"no_such_arena"
	host.start(cfg)
	assert_eq(view.arena_id, &"no_such_arena")
	assert_eq(view.arena.scene_file_path, ArenaScenes.STANDIN_SCENE)
	assert_not_null(view.arena.get_node_or_null("Spawn0"), "with the stand-in's markers")


func test_watch_and_menu_pick_their_cameras() -> void:
	host.start(_cpu(MatchConfig.WATCH))
	assert_eq(view.camera.mode, CameraRig.Mode.WATCH)
	host.start(_with_standin(MatchConfig.attract()), true)
	assert_eq(view.camera.mode, CameraRig.Mode.MENU)
	assert_false(hud.visible, "no HUD behind the menus")


func test_fighters_and_camera_follow_the_rules() -> void:
	host.start(_cpu())
	host.step(900)
	view.render(1.0 / 60.0)
	for i: int in 2:
		var f: Fighter = host.fighter(i)
		assert_almost_eq(view.fighters[i].position, host.display_position(i), Vector3.ONE * 1e-5)
		assert_almost_eq(view.fighters[i].rotation.y, wrapf(host.display_yaw(i), -PI, PI), 1e-4)
		assert_not_null(view.fighters[i].last_pose)
		assert_false(f.hp != f.hp, "no NaN")
	view.snap_camera()
	var p: Vector3 = host.display_position(0)
	var o: Vector3 = host.display_position(1)
	var d: Vector3 = Vector3(o.x - p.x, 0.0, o.z - p.z).normalized()
	var rel: Vector3 = view.camera.rig_position - p
	assert_lt(Vector3(rel.x, 0.0, rel.z).dot(d), 0.0, "the camera is behind the player")


func test_events_shake_and_kick_the_camera() -> void:
	host.start(_cpu())
	var at: Dictionary = {"x": 0.0, "y": 1.25, "z": 0.0}
	host.sim_event.emit({"t": &"hit", "attacker": 0, "target": 1, "heavy": false, "sound": &"blade", "pos": at})
	assert_eq(view.camera.shake, 0.0, "light hits don't shake")
	host.sim_event.emit({"t": &"hit", "attacker": 0, "target": 1, "heavy": true, "sound": &"blade", "pos": at})
	assert_almost_eq(view.camera.shake, view.heavy_hit_shake, 1e-6, "heavy hits do")
	view.camera.shake = 0.0
	host.sim_event.emit({"t": &"parry", "parrier": 1, "attacker": 0, "kind": &"parry", "pos": at})
	assert_almost_eq(view.camera.shake, view.parry_shake, 1e-6)
	assert_eq(view.camera.fov_kick, 3.0)
	host.sim_event.emit({"t": &"disarm", "victim": 0, "by": 1, "reason": &"parried", "pos": at})
	assert_eq(view.camera.fov_kick, 7.0)
	host.sim_event.emit({"t": &"ko", "loser": 1, "winner": 0})
	assert_gt(view.camera.ko_orbit, 0.0, "the KO swings the camera out")
	host.sim_event.emit({"t": &"roundStart", "round": 2})
	assert_eq(view.camera.ko_orbit, 0.0)


## A hit or a block kicks the camera by the weight of the attacker's weapon,
## half again for a heavy (task 14.12): here the Rogue's Katana against the
## Hunter's Daggers.
func test_contact_kicks_the_camera_by_the_weapons_weight() -> void:
	host.start(_cpu())
	var at: Dictionary = {"x": 0.0, "y": 1.25, "z": 0.0}
	host.sim_event.emit({"t": &"hit", "attacker": 0, "target": 1, "heavy": false, "sound": &"blade", "pos": at})
	var katana: float = view.camera.fov_kick
	assert_almost_eq(katana, view.contact_kick[&"medium"], 1e-6, "a Katana hit")
	host.sim_event.emit({"t": &"block", "attacker": 1, "target": 0, "heavy": false, "pos": at})
	var daggers: float = view.camera.fov_kick
	assert_lt(daggers, katana, "the Daggers kick less")
	host.sim_event.emit({"t": &"hit", "attacker": 1, "target": 0, "heavy": true, "sound": &"blade", "pos": at})
	assert_almost_eq(view.camera.fov_kick, daggers * MatchView.HEAVY_KICK, 1e-6, "a heavy half again")
	assert_lt(view.contact_kick[&"medium"], view.contact_kick[&"colossal"], "the Greatsword the most")


func test_the_hud_times_announcements_on_rules_steps() -> void:
	host.start(_cpu())
	assert_eq(hud.announcement_text(), "Round 1", "the intro calls the round")
	host.step(Match.FIGHT_CALL_FRAME - 1)
	assert_eq(hud.announcement_text(), "Round 1")
	host.step(1)
	assert_eq(hud.announcement_text(), "Fight")
	host.pause()
	# wall time passing changes nothing while paused
	for i: int in 30:
		host.advance(0.1)
		hud._process(0.1)
	assert_eq(hud.announcement_text(), "Fight")
	host.resume()
	host.step(MatchHud.FIGHT_FRAMES)
	assert_eq(hud.announcement_text(), "", "gone after its frames")


func test_the_hud_calls_the_ko_and_the_round_winner() -> void:
	host.start(_cpu())
	var steps: int = 0
	while host.sim_match.phase != &"roundEnd" and steps < 30000:
		host.step(1)
		steps += 1
	assert_eq(host.sim_match.phase, &"roundEnd")
	assert_true(hud.announcement_text() == "K.O." or hud.announcement_text() == "Double K.O.")
	host.step(MatchHud.ROUND_RESULT_DELAY)
	var winner: int = host.sim_match.round_winner
	if winner >= 0:
		assert_eq(hud.announcement_text(), "%s wins the round" % host.fighter(winner).name)
	else:
		assert_eq(hud.announcement_text(), "Draw")


## The HUD's prompts (24.4) as one text, keys in brackets.
func _prompt_text() -> String:
	return "\n".join(hud.prompts.lines())


func test_the_hud_offers_the_ultimate_to_a_human_player() -> void:
	var cfg: MatchConfig = _with_standin(MatchConfig.default_duel())
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 1)
	host.fighter(0).hp = 20.0
	hud._process(1.0 / 60.0)
	assert_string_contains(_prompt_text(), "Ultimate ready")
	assert_string_contains(_prompt_text(), "[Left Click] + [Right Click]")
	host.fighter(0).hp = 100.0
	hud._process(1.0 / 60.0)
	assert_eq(_prompt_text(), "")


func test_a_whole_match_renders_without_errors() -> void:
	host.start(_cpu(MatchConfig.DUEL, 19))
	var steps: int = 0
	while not host.is_finished() and steps < 60 * 60 * 12:
		host.step(3)
		steps += 3
		view.render(1.0 / 20.0)
		hud._process(1.0 / 20.0)
	assert_true(host.is_finished())


# ------------------------------------------------------------------ arena data

## An arena root carrying an ArenaDef-like `def`, built at run time so this
## lane needs no ArenaDef class.
func _fake_arena(max_radius: float, far_plane: float) -> Node3D:
	var def_script: GDScript = GDScript.new()
	def_script.source_code = "extends Resource\nvar camera_max_radius: float = %s\nvar camera_far: float = %s\n" % [max_radius, far_plane]
	def_script.reload()
	var arena_script: GDScript = GDScript.new()
	arena_script.source_code = "extends Node3D\nvar def: Resource\n"
	arena_script.reload()
	var node: Node3D = Node3D.new()
	node.set_script(arena_script)
	node.set("def", def_script.new())
	return node


func test_the_camera_takes_the_arenas_camera_data() -> void:
	var standin: MatchConfig = _cpu()
	host.start(standin)
	assert_eq(view.camera.far, view.camera.far_clip, "the stand-in has no data: the defaults")
	assert_almost_eq(view.camera.arena_limit(), SimConst.ARENA_RADIUS + view.camera.arena_margin, 1e-6)
	view.set_arena(_fake_arena(19.5, 3000.0), &"fake")
	assert_eq(view.arena_id, &"fake")
	assert_eq(view.camera.far, 3000.0, "the arena's far clip, so its backdrop isn't cut off")
	assert_eq(view.camera.arena_limit(), 19.5, "the arena's camera radius")
	var far_out: Vector3 = view.camera.clamp_to_arena(Vector3(30.0, 2.0, 0.0))
	assert_almost_eq(far_out.x, 19.5, 1e-5)
	# back to an arena without data: the defaults again
	host.start(standin)
	assert_eq(view.camera.far, view.camera.far_clip)
	assert_almost_eq(view.camera.arena_limit(), SimConst.ARENA_RADIUS + view.camera.arena_margin, 1e-6)


# ------------------------------------------------------------------ the HUD outside the fight

func test_the_ultimate_hint_shows_only_while_the_round_is_fought() -> void:
	host.start(_with_standin(MatchConfig.default_duel()))
	host.fighter(0).hp = 20.0
	hud._process(1.0 / 60.0)
	assert_eq(_prompt_text(), "", "not during the round's intro")
	host.step(Match.INTRO_FRAMES + 1)
	hud._process(1.0 / 60.0)
	assert_string_contains(_prompt_text(), "Ultimate ready")
	# the player wins the round on 20 HP with the ultimate unused
	host.fighter(1).hp = 0.0
	host.step(2)
	assert_eq(host.sim_match.phase, &"roundEnd")
	hud._process(1.0 / 60.0)
	assert_eq(_prompt_text(), "", "gone once the round is over")


func test_the_hud_clears_and_hides_when_the_results_open() -> void:
	host.start(_with_standin(MatchConfig.default_duel()))
	host.step(Match.INTRO_FRAMES + 1)
	hud.announce("武器喪失", "Disarmed", "Retrieve your weapon", 300)
	assert_true(hud.visible)
	host.match_finished.emit(host.results())
	assert_eq(hud.announcement_text(), "")
	assert_eq(_prompt_text(), "")
	assert_false(hud.visible, "the results take the screen")
	host.start(_with_standin(MatchConfig.default_duel()))
	assert_true(hud.visible, "back for the rematch")


# ------------------------------------------------------------------ stray nodes

func _child_names() -> Array[String]:
	var out: Array[String] = []
	for c: Node in view.get_children():
		if not c.is_queued_for_deletion():
			out.append(String(c.name))
	out.sort()
	return out


func test_rematches_and_restarts_leave_no_stray_nodes() -> void:
	host.start(_cpu())
	await get_tree().process_frame
	var baseline: Array[String] = _child_names()
	assert_eq(baseline.size(), 5, "the arena, the camera, two fighters and the effects")
	var at: Dictionary = {"x": 0.0, "y": 1.25, "z": 0.0}
	for k: int in 3:
		host.step(Match.INTRO_FRAMES + 20)
		host.sim_event.emit({"t": &"parry", "parrier": 1, "attacker": 0, "kind": &"parry", "pos": at})
		host.world.weapons.append(DroppedWeapon.new(0, &"katana", V3.make(1.0, 0.0, 1.0), V3.make(), Rng.new(k + 1)))
		view.render(1.0 / 60.0)
		assert_eq(view.effects.flash_count(), 1, "a flash, drawn from the effects' pool")
		assert_gt(view.get_child_count(), baseline.size(), "and a dropped weapon")
		if k == 1:
			host.start(_with_standin(MatchConfig.attract(k + 5)), true)
		else:
			host.start(_cpu(MatchConfig.DUEL, 7 + k))
		await get_tree().process_frame
		assert_eq(_child_names(), baseline, "match %d: nothing left behind" % k)


func test_a_dropped_weapon_is_in_the_toon_look() -> void:
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 5)
	host.world.weapons.append(DroppedWeapon.new(1, &"daggers", V3.make(1.0, 0.0, 1.0), V3.make(), Rng.new(3)))
	view.render(1.0 / 60.0)
	var daggers: Array[Node] = view.get_node("Dropped1/Stick").get_children()
	assert_eq(daggers.size(), 2, "a pair of daggers")
	for dagger: Node in daggers:
		var meshes: Array[Node] = dagger.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, "the dagger's own model")
		for node: Node in meshes:
			var mi: MeshInstance3D = node
			assert_eq(mi.layers, 1 | LookPalette.FIGHTER_LAYER, "on the fighters' layer, so the rim light finds it")
			for i: int in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(i)
				assert_true(ToonMaterials.is_toon(m), "a toon dagger")
				assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.WEAPON)
				assert_true(ToonMaterials.is_outlined(m), "weapons are outlined on every preset")


## A dropped weapon's beam is drawn with a material and mesh the view built
## before the match, never new ones at the disarm: a new StandardMaterial3D
## compiled its shader on the main thread, some 40 ms at every disarm (the
## frame-time harness's worst frame), since freeing the last beam had freed
## the shader too.
func test_a_dropped_weapon_s_beam_needs_nothing_new_at_the_disarm() -> void:
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 5)
	var mats: Array[Material] = []
	for side: int in 2:
		mats.append(view.beam_material(side))
		assert_not_null(mats[side], "side %d's beam material is built before any disarm" % side)
		assert_eq(Color(mats[side].albedo_color, 1.0), LookPalette.side_color(host.config.sides[side].palette), "in side %d's colour" % side)
	assert_ne(mats[0], mats[1], "one for each side")
	var mesh: Mesh = view.beam_mesh()
	assert_not_null(mesh, "the beam's mesh is built before any disarm")
	for k: int in 2:
		host.world.weapons.append(DroppedWeapon.new(1, &"katana", V3.make(1.0, 0.0, 1.0), V3.make(), Rng.new(k + 1)))
		view.render(1.0 / 60.0)
		var beam: MeshInstance3D = view.get_node("Dropped1/Beam")
		assert_same(beam.material_override, mats[1], "drop %d: the view's own material" % k)
		assert_same(beam.mesh, mesh, "drop %d: the view's own mesh" % k)
		host.world.weapons.clear() # picked up: the stand-in is freed
		view.render(1.0 / 60.0)
		await get_tree().process_frame
		assert_null(view.get_node_or_null("Dropped1"), "drop %d: picked up" % k)
	assert_same(view.beam_material(1), mats[1], "kept across the pickups")


func test_the_view_and_hud_follow_the_dummy_s_weapon_swap() -> void:
	# a Greatsword dummy, with the whole roster so the Slam can bring it back
	Roster.full = true
	var cfg: MatchConfig = _with_standin(MatchConfig.default_training(5))
	cfg.sides[1].weapon_id = &"greatsword"
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 5)
	var dummy: Fighter = host.fighter(1)
	dummy.disarm(host.fighter(0), &"parried")
	host.step(1)
	view.render(1.0 / 60.0)
	assert_not_null(view.get_node_or_null("Dropped1"), "the Greatsword on the floor")
	host.set_training_behaviour(&"thrust")
	view.render(1.0 / 60.0)
	var fv: FighterView = view.fighters[1]
	assert_eq(fv.weapon_id, &"katana")
	assert_eq(fv.model.weapon_look.id, &"katana", "the dummy holds the Katana")
	var plate: Label = hud.find_child("Weapon1", true, false)
	assert_eq(plate.text, Moves.KATANA.name, "the plate names it")
	await get_tree().process_frame
	assert_null(view.get_node_or_null("Dropped1"), "no Greatsword left on the floor")
	host.set_training_behaviour(&"slam")
	assert_eq(fv.model.weapon_look.id, &"greatsword", "and back")
	assert_eq(plate.text, Moves.GREATSWORD.name)


func test_a_body_flash_fades_with_the_rules_not_the_wall_clock() -> void:
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 5)
	var at: Dictionary = {"x": 0.0, "y": 1.25, "z": 0.0}
	var now: int = host.world.frame
	host.sim_event.emit({"t": &"hit", "attacker": 0, "target": 1, "heavy": true, "sound": &"blade", "pos": at})
	var target: FighterView = view.fighters[1]
	assert_almost_eq(target.flash_left(now), 0.55, 1e-6, "lit by the heavy hit")
	view.render(1.0)
	assert_almost_eq(target.flash_left(now), 0.55, 1e-6, "a long wall-clock frame doesn't fade it")
	assert_almost_eq(target.flash_left(now + 2), 0.35, 1e-6, "it fades by the frame")
	assert_eq(target.flash_left(now + 10), 0.0, "gone ten frames on")


## Rematches and restarts keep each side's model while its fighter stays the
## same; a side whose fighter changes gets a new one.
func test_rematches_keep_the_fighters_models() -> void:
	host.start(_cpu())
	var models: Array[FighterModel] = [view.fighters[0].model, view.fighters[1].model]
	host.start(_cpu(MatchConfig.DUEL, 8))
	assert_eq(view.fighters[0].model, models[0], "the Rogue kept")
	assert_eq(view.fighters[1].model, models[1], "the Hunter kept")
	host.start(_with_standin(MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"rogue", &"greatsword", 1, &"hard"),
		9,
	)))
	assert_eq(view.fighters[0].model, models[0], "the Rogue still kept")
	assert_ne(view.fighters[1].model, models[1], "a Rogue in place of the Hunter")
	assert_eq(view.fighters[1].model.palette, 1, "in her second palette")
