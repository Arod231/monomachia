extends GutTest
## The HUD's prompts (task 24.4): at most two at the bottom centre, urgent
## first and edged in gold, naming each key as a key cap from the device the
## player last used; hidden by the Button hints setting, in Watch and outside
## the fought round.

var host: MatchHost
var hud: MatchHud
var fake: FakeDeviceState
var me: Fighter


## Training against an idle dummy, the player's Rogue on side 0 with the
## given weapon, a few steps into the fight.
func _start(weapon: StringName = &"katana", mode: StringName = MatchConfig.TRAINING) -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	fake = FakeDeviceState.new()
	host.input = InputDevices.new(fake)
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	hud.settings = GameSettings.new()
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"katana", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig
	if mode == MatchConfig.WATCH:
		cfg = MatchConfig.make(mode, MatchSide.computer(&"rogue", weapon, 0), MatchSide.computer(&"hunter", &"katana", 1), 5, ArenaScenes.STANDIN)
	elif mode == MatchConfig.DUEL:
		cfg = MatchConfig.make(mode, MatchSide.human(&"rogue", weapon, 0), MatchSide.computer(&"hunter", &"katana", 1), 5, ArenaScenes.STANDIN)
	else:
		cfg = MatchConfig.make(mode, MatchSide.human(&"rogue", weapon, 0), dummy, 5, ArenaScenes.STANDIN)
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 2)
	me = host.fighter(0)


func _lines() -> Array[String]:
	hud._process(1.0 / 60.0)
	return hud.prompts.lines()


func _urgent() -> Array[bool]:
	var out: Array[bool] = []
	for p: Dictionary in hud.prompts.prompts():
		out.append(bool(p["urgent"]))
	return out


## Makes the player's last device a PlayStation controller.
func _use_pad() -> void:
	fake.plug_pad(0, "PS5 Controller")
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	host.input.note_event(e)


## The player's own weapon on the ground, `metres` away along the ground.
func _drop_weapon(metres: float) -> void:
	me.armed = false
	var w := DroppedWeapon.new(0, &"katana", V3.make(me.pos.x + metres, 0.0, me.pos.z), V3.make(), Rng.new(1))
	w.grounded = true
	host.world.weapons.append(w)


func test_nothing_to_prompt_shows_nothing() -> void:
	_start()
	assert_eq(_lines(), [] as Array[String])
	assert_eq(hud.prompts.get_child_count(), 0)


func test_ultimate_ready_names_light_heavy_and_the_ultimate_key() -> void:
	_start()
	me.hp = 20.0
	assert_eq(_lines(), ["Ultimate ready: [Left Click] + [Right Click] or [Q]"] as Array[String])
	assert_eq(_urgent(), [false] as Array[bool], "not urgent")


func test_the_bare_hands_choice() -> void:
	_start()
	me.set_state(&"ultChoice", SimConst.ULT_CHOICE_FRAMES)
	assert_eq(_lines(), ["[Left Click] Recall your weapon  ·  [Right Click] Breaker Palm"] as Array[String])
	assert_eq(_urgent(), [true] as Array[bool])


func test_the_moonsplitter_tilt_names_the_movement_keys() -> void:
	_start()
	me.hp = 20.0
	me.start_ult()
	assert_eq(me.ult.phase, &"windup")
	assert_eq(_lines(), ["Tilt [W]/[S] vertical slash  ·  [A]/[D] horizontal"] as Array[String])
	assert_eq(_urgent(), [true] as Array[bool])


## On a controller the tilt names the stick, not the D-pad (the owner's
## choice, Oct 4, 2026).
func test_on_a_controller_the_moonsplitter_tilt_names_the_stick() -> void:
	_start()
	_use_pad()
	me.hp = 20.0
	me.start_ult()
	assert_eq(_lines(), ["Tilt the stick [↑]/[↓] vertical slash  ·  [←]/[→] horizontal"] as Array[String])


func test_the_impaler_detonates_with_heavy() -> void:
	_start(&"greatsword")
	me.hp = 20.0
	me.start_ult()
	assert_eq(me.ult.kind, &"impaler")
	assert_eq(_lines(), [] as Array[String], "nothing to press while it aims")
	me.ult.phase = &"impale"
	assert_eq(_lines(), ["Press [Right Click] to detonate"] as Array[String])
	assert_eq(_urgent(), [true] as Array[bool])


func test_the_counter_lunge_while_it_is_open() -> void:
	_start()
	me.counter_lunge_until = host.world.frame + 3
	assert_eq(_lines(), ["Counter lunge: [Left Click]"] as Array[String])
	assert_eq(_urgent(), [true] as Array[bool])
	host.step(4)
	assert_eq(_lines(), [] as Array[String], "gone once it closes")


func test_picking_up_your_weapon_within_reach() -> void:
	_start()
	_drop_weapon(2.0)
	assert_eq(_lines(), ["Pick up your weapon [E]"] as Array[String])
	assert_eq(_urgent(), [true] as Array[bool])
	host.world.weapons[0].pos.x = me.pos.x + 2.3
	assert_eq(_lines(), [] as Array[String], "past 2.2 m")
	host.world.weapons[0].pos.x = me.pos.x + 1.0
	host.world.weapons[0].grounded = false
	assert_eq(_lines(), [] as Array[String], "still flying")


func test_at_most_two_urgent_first() -> void:
	_start()
	me.hp = 20.0
	_drop_weapon(1.0)
	me.counter_lunge_until = host.world.frame + 30
	assert_eq(_lines(), ["Counter lunge: [Left Click]", "Pick up your weapon [E]"] as Array[String])
	assert_eq(_urgent(), [true, true] as Array[bool])
	me.counter_lunge_until = -99999
	assert_eq(_lines(), ["Pick up your weapon [E]", "Ultimate ready: [Left Click] + [Right Click] or [Q]"] as Array[String])
	assert_eq(_urgent(), [true, false] as Array[bool], "the urgent one first")


## The keys follow the device used last: a PlayStation controller's names,
## then the keyboard's again after a key press.
func test_labels_follow_the_last_device_used() -> void:
	_start()
	me.hp = 20.0
	_use_pad()
	assert_eq(_lines(), ["Ultimate ready: [R1] + [R2] or [△]"] as Array[String])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	host.input.note_event(key)
	assert_eq(_lines(), ["Ultimate ready: [Left Click] + [Right Click] or [Q]"] as Array[String])


func test_button_hints_off_hides_them() -> void:
	_start()
	me.hp = 20.0
	hud.settings.button_hints = false
	assert_eq(_lines(), [] as Array[String])
	hud.settings.button_hints = true
	assert_eq(_lines().size(), 1, "back when turned on")


func test_no_prompts_in_watch() -> void:
	_start(&"katana", MatchConfig.WATCH)
	me.hp = 20.0
	assert_eq(_lines(), [] as Array[String])


func test_only_while_the_round_is_fought() -> void:
	_start()
	me.hp = 20.0
	assert_eq(_lines().size(), 1)
	host.start(host.config)
	host.fighter(0).hp = 20.0
	assert_eq(_lines(), [] as Array[String], "not in the round's intro")


## Each line is a panel edged in gold when urgent, the line colour when not,
## with a key cap per key, at the bottom centre (in a Duel: no Training
## panel to clear).
func test_the_lines_draw_key_caps_in_their_panels() -> void:
	_start(&"katana", MatchConfig.DUEL)
	me.hp = 20.0
	_drop_weapon(1.0)
	_lines()
	await wait_process_frames(2)
	assert_eq(hud.prompts.get_child_count(), 2)
	var urgent: PanelContainer = hud.prompts.get_child(0)
	var calm: PanelContainer = hud.prompts.get_child(1)
	assert_eq((urgent.get_theme_stylebox("panel") as StyleBoxFlat).border_color, UiPalette.GOLD)
	assert_eq((calm.get_theme_stylebox("panel") as StyleBoxFlat).border_color, UiPalette.LINE)
	var caps: Array[String] = []
	for node: Node in calm.get_node("Row").get_children():
		if node is KeyCap:
			caps.append((node as KeyCap).text)
	assert_eq(caps, ["Left Click", "Right Click", "Q"] as Array[String])
	var screen: Rect2 = hud.get_viewport().get_visible_rect()
	var rect: Rect2 = calm.get_global_rect()
	assert_almost_eq(rect.get_center().x, screen.size.x * 0.5, 1.0, "centred")
	assert_lt(rect.end.y, screen.size.y, "on screen")
	assert_gt(rect.end.y, screen.size.y - 40.0, "at the bottom")


## In Training a wide prompt moves right to clear the panel at the bottom
## left; outside Training it stays centred.
func test_in_training_the_prompts_clear_the_panel() -> void:
	_start()
	me.hp = 20.0
	me.start_ult()
	me.counter_lunge_until = host.world.frame + 30
	_lines()
	await wait_process_frames(3)
	assert_true(hud.training_panel.visible, "the panel shows")
	var panel: Rect2 = hud.training_panel.get_global_rect()
	for line: Control in hud.prompts.get_children():
		assert_gt(line.get_global_rect().position.x, panel.end.x, "clear of the panel")


## The lines are built again only when the prompts change.
func test_unchanged_prompts_keep_their_lines() -> void:
	_start()
	me.hp = 20.0
	_lines()
	var line: Node = hud.prompts.get_child(0)
	_lines()
	assert_eq(hud.prompts.get_child(0), line)


func test_the_results_clear_them() -> void:
	_start()
	me.hp = 20.0
	_lines()
	hud._on_match_finished(host.results())
	assert_eq(hud.prompts.lines(), [] as Array[String])
