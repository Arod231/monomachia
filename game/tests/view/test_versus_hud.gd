extends GutTest
## The Versus HUD (task 23.7): "Player 1" and "Player 2" plates with each
## side's fighter and weapon under them; each player's prompts in the middle
## of their own half, named for their own device; a marker on each player's
## dropped weapon in their own half, through their own camera; and the
## demo's Versus toasts and calls naming the player, in Watch's side colours
## (the owner's choices, Oct 5, 2026). The other modes keep one column of
## prompts and one marker.

const RED: Color = HudToasts.TONE_COLORS[HudToasts.Tone.RED]
const BLUE: Color = HudToasts.TONE_COLORS[HudToasts.Tone.BLUE]
const DIM: Color = HudToasts.TONE_COLORS[HudToasts.Tone.DIM]

var host: MatchHost
var hud: MatchHud
var view: MatchView
var fake: FakeDeviceState


## Versus on the stand-in arena: the Rogue with the Katana on keyboard and
## mouse against the Hunter with the Greatsword on `second` (the arrow keys
## or the first controller, a PlayStation one), a few steps into the fight.
func _start(second: String = InputDevices.PAD0) -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	fake = FakeDeviceState.new()
	fake.plug_pad(0, "PS5 Controller")
	host.input = InputDevices.new(fake)
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	hud.settings = GameSettings.new()
	view = host.get_node("View")
	var cfg: MatchConfig = MatchConfig.make(
		MatchConfig.VERSUS,
		MatchSide.human(&"rogue", &"katana", 0, InputDevices.KBM),
		MatchSide.human(&"hunter", &"greatsword", 1, second),
		5,
		ArenaScenes.STANDIN,
	)
	assert_true(host.start(cfg), "started: %s" % cfg.problem())
	host.step(Match.INTRO_FRAMES + 2)
	# the split's halves are laid out on the next frames
	await wait_process_frames(2)
	view.render(1.0 / 60.0)


## A Duel on the same arena, for what stays as it was outside Versus.
func _start_duel() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	hud.settings = GameSettings.new()
	view = host.get_node("View")
	host.start(MatchConfig.make(MatchConfig.DUEL, MatchSide.human(&"rogue", &"katana", 0), MatchSide.computer(&"hunter", &"katana", 1), 5, ArenaScenes.STANDIN))
	host.step(Match.INTRO_FRAMES + 2)
	await wait_process_frames(2)
	view.render(1.0 / 60.0)


## The one toast an event gives, as [text, subline, colour].
func _toast_of(e: Dictionary) -> Array:
	hud.toasts.clear()
	hud._on_sim_event(e)
	var on: Array[Dictionary] = hud.toasts.entries()
	assert_eq(on.size(), 1, "one toast for %s" % e)
	if on.size() != 1:
		return []
	return [on[0]["text"], on[0]["sub"], HudToasts.TONE_COLORS[on[0]["tone"]]]


func _nothing_for(e: Dictionary) -> void:
	hud.toasts.clear()
	hud._on_sim_event(e)
	assert_eq(hud.toasts.entries().size(), 0, "no toast for %s" % e)


## The key caps of player i's prompt lines, in order.
func _caps(i: int) -> Array[String]:
	var out: Array[String] = []
	for line: Node in hud.prompt_columns[i].get_children():
		for node: Node in line.get_node("Row").get_children():
			if node is KeyCap:
				out.append((node as KeyCap).text)
	return out


## A weapon of `owner` stuck in the ground at a world position.
func _drop(owner: int, at: Vector3) -> DroppedWeapon:
	host.fighter(owner).armed = false
	var w := DroppedWeapon.stuck_at(owner, &"katana", V3.make(at.x, at.y, at.z), 0.0)
	host.world.weapons.append(w)
	return w


## A point on the floor 4 m ahead of camera i.
func _ahead_of(i: int) -> Vector3:
	var cam: Camera3D = view.cameras[i]
	var p: Vector3 = cam.global_position - cam.global_basis.z * 4.0
	p.y = 0.0
	return p


## Half i of the split as the HUD sees it (its rect on the screen).
func _half(i: int) -> Rect2:
	return view.split.containers[i].get_global_rect()


# ------------------------------------------------------------------ plates

func test_the_plates_name_the_players_with_fighter_and_weapon() -> void:
	await _start()
	assert_eq((hud.get_node("Root/Side0").find_child("Plate0", true, false) as Label).text, "Player 1")
	assert_eq((hud.get_node("Root/Side1").find_child("Plate1", true, false) as Label).text, "Player 2")
	assert_eq((hud.get_node("Root/Side0").find_child("Weapon0", true, false) as Label).text, "Rogue · Katana")
	assert_eq((hud.get_node("Root/Side1").find_child("Weapon1", true, false) as Label).text, "Hunter · Greatsword")


func test_a_duel_keeps_the_fighter_s_plate() -> void:
	await _start_duel()
	assert_eq((hud.get_node("Root/Side0").find_child("Plate0", true, false) as Label).text, "Rogue (You)")
	assert_eq((hud.get_node("Root/Side0").find_child("Weapon0", true, false) as Label).text, "Katana")


# ------------------------------------------------------------------ toasts

func test_toasts_name_the_player_in_the_side_s_colour() -> void:
	await _start()
	assert_eq(_toast_of({"t": &"parry", "parrier": 1, "attacker": 0, "kind": &"parry", "timing": 3, "window": 6}), ["Player 2: Parry", "", BLUE])
	assert_eq(_toast_of({"t": &"parry", "parrier": 0, "attacker": 1, "kind": &"flash", "timing": 3, "window": 6}), ["Player 1: Flash", "", RED])
	assert_eq(_toast_of({"t": &"counter", "kind": &"stomp", "by": 0, "on": 1}), ["Player 1: Stomp counter", "", RED])
	assert_eq(_toast_of({"t": &"ultStart", "f": 1, "ult": &"impaler"}), ["Player 2: Ultimate", "", BLUE])
	assert_eq(_toast_of({"t": &"hit", "attacker": 0, "target": 1, "backstab": true, "heavy": false}), ["Player 1: Backstab", "", RED])
	assert_eq(_toast_of({"t": &"stagger", "f": 1}), ["Player 2: Dazed", "", BLUE])


## The demo's Versus also toasted a player getting behind the other, dim.
func test_getting_behind_them_toasts_dim() -> void:
	await _start()
	assert_eq(_toast_of({"t": &"backstabReady", "f": 0}), ["Player 1: Behind them", "", DIM])
	assert_eq(_toast_of({"t": &"backstabReady", "f": 1}), ["Player 2: Behind them", "", DIM])
	_nothing_for({"t": &"ultReady", "f": 0})
	_nothing_for({"t": &"evade", "f": 1, "attacker": 0})


## Watch keeps its own set: no "behind them".
func test_watch_still_toasts_no_behind_them() -> void:
	assert_eq(HudToasts.for_event({"t": &"backstabReady", "f": 0}, -1, false, ["Rogue", "Hunter"] as Array[String], ""), [] as Array[Dictionary])


# ------------------------------------------------------------------ calls

func test_the_round_s_winner_is_named_in_the_side_s_colour() -> void:
	await _start()
	hud._on_sim_event({"t": &"roundOver", "winner": 1, "perfect": false})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(hud.announcement_kanji(), "勝")
	assert_eq(hud.announcement_text(), "Player 2 wins the round")
	assert_eq(hud.announcement.get("color"), BLUE)
	hud._on_sim_event({"t": &"roundOver", "winner": 0, "perfect": true})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(hud.announcement_text(), "Player 1 wins the round")
	assert_eq(hud.announcement_sub(), "Perfect")
	assert_eq(hud.announcement.get("color"), RED)


func test_a_disarm_says_who_lost_their_weapon() -> void:
	await _start()
	hud._on_sim_event({"t": &"disarm", "victim": 1, "by": 0})
	assert_eq(hud.announcement_kanji(), "武器喪失")
	assert_eq(hud.announcement_text(), "Disarmed")
	assert_eq(hud.announcement_sub(), "Player 2 lost their weapon")


## One K.O. call for every mode (milestone 1 changes it everywhere at once).
func test_the_k_o_call_is_every_mode_s() -> void:
	await _start()
	hud._on_sim_event({"t": &"ko", "winner": 0, "loser": 1})
	assert_eq([hud.announcement_kanji(), hud.announcement_text()], ["一本", "K.O."])


func test_the_results_name_the_player() -> void:
	await _start()
	var r: MatchResults = MatchResults.from_match(host.sim_match, host.config, host.config.first_human_side())
	r.winner = 1
	assert_eq(r.names, ["Player 1", "Player 2"] as Array[String])
	assert_eq(r.weapons, ["Rogue · Katana", "Hunter · Greatsword"] as Array[String])
	assert_eq(r.title(), "Player 2 wins")
	assert_eq(r.kanji(), "決着")


# ------------------------------------------------------------------ prompts

## Each player's prompts use their own device's names: keyboard and mouse
## for player 1, a PlayStation controller for player 2.
func test_each_player_s_prompts_name_their_own_device() -> void:
	await _start()
	host.fighter(0).hp = 20.0
	host.fighter(1).hp = 20.0
	hud._process(1.0 / 60.0)
	assert_eq(_caps(0), ["Left Click", "Right Click", "Q"] as Array[String])
	assert_eq(_caps(1), ["R1", "R2", "△"] as Array[String])


## Sharing the keyboard: player 2 on the arrow layout reads its J, K and U.
func test_the_arrow_layout_names_its_own_keys() -> void:
	await _start(InputDevices.KB_ARROWS)
	host.fighter(1).hp = 20.0
	hud._process(1.0 / 60.0)
	assert_eq(_caps(0), [] as Array[String], "player 1 has nothing to press")
	assert_eq(_caps(1), ["J", "K", "U"] as Array[String])


## Each player's prompts sit at the bottom of the middle of their own half.
func test_each_player_s_prompts_sit_in_their_own_half() -> void:
	await _start()
	host.fighter(0).hp = 20.0
	host.fighter(1).hp = 20.0
	hud._process(1.0 / 60.0)
	await wait_process_frames(2)
	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	for i: int in 2:
		var line: Control = hud.prompt_columns[i].get_child(0)
		var rect: Rect2 = line.get_global_rect()
		assert_almost_eq(rect.get_center().x, screen.x * (0.25 if i == 0 else 0.75), 1.0, "player %d's prompt in the middle of their half" % (i + 1))
		assert_gt(rect.end.y, screen.y - 40.0, "at the bottom")
		assert_true(_half(i).encloses(rect), "inside player %d's half" % (i + 1))


func test_button_hints_off_hides_both_players_prompts() -> void:
	await _start()
	hud.settings.button_hints = false
	host.fighter(0).hp = 20.0
	host.fighter(1).hp = 20.0
	hud._process(1.0 / 60.0)
	assert_eq(hud.prompt_columns[0].lines(), [] as Array[String])
	assert_eq(hud.prompt_columns[1].lines(), [] as Array[String])


## Outside Versus the player's prompts stay one column at the bottom centre.
func test_a_duel_keeps_one_column_of_prompts() -> void:
	await _start_duel()
	host.fighter(0).hp = 20.0
	hud._process(1.0 / 60.0)
	await wait_process_frames(2)
	assert_eq(hud.prompts, hud.prompt_columns[0])
	assert_eq(hud.prompt_columns[0].lines().size(), 1)
	assert_eq(hud.prompt_columns[1].lines(), [] as Array[String])
	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	assert_almost_eq(hud.prompts.get_child(0).get_global_rect().get_center().x, screen.x * 0.5, 1.0)


# ------------------------------------------------------------------ markers

## Player 2's dropped weapon is marked in their half, through their camera,
## as "Player 2's weapon"; player 1, armed, has no marker.
func test_a_marker_projects_through_its_player_s_camera() -> void:
	await _start()
	var at: Vector3 = _ahead_of(1)
	_drop(1, at)
	hud._process(1.0 / 60.0)
	var marker: WeaponMarker = hud.weapon_markers[1]
	assert_false(hud.weapon_markers[0].visible, "player 1 is armed")
	assert_true(marker.visible)
	assert_eq(marker.label.text, "Player 2's weapon")
	assert_eq(marker.side(), WeaponMarker.Side.NONE, "on screen")
	var cam: Camera3D = view.cameras[1]
	var half: Rect2 = _half(1)
	var vp: Vector2 = Vector2(cam.get_viewport().size)
	var expected: Vector2 = half.position + cam.unproject_position(at + Vector3(0.0, WeaponMarker.MARKER_HEIGHT, 0.0)) * half.size / vp
	assert_almost_eq(marker.anchor().x, expected.x, 1.0)
	assert_almost_eq(marker.anchor().y, expected.y, 1.0)
	assert_true(half.has_point(marker.anchor()), "in player 2's half")


## Both players disarmed: each has their own marker, each in their own half.
func test_both_players_have_their_own_marker() -> void:
	await _start()
	_drop(0, _ahead_of(0))
	_drop(1, _ahead_of(1))
	hud._process(1.0 / 60.0)
	assert_eq(hud.weapon_markers[0].label.text, "Player 1's weapon")
	for i: int in 2:
		var marker: WeaponMarker = hud.weapon_markers[i]
		assert_true(marker.visible, "player %d's marker" % (i + 1))
		assert_true(_half(i).has_point(marker.anchor()), "player %d's marker in their half" % (i + 1))


## A weapon behind a player's camera clamps to the bottom of their own half,
## whole inside it.
func test_off_screen_a_marker_stays_in_its_half() -> void:
	await _start()
	var cam: Camera3D = view.cameras[0]
	var at: Vector3 = cam.global_position + cam.global_basis.z * 3.0
	at.y = 0.0
	_drop(0, at)
	hud._process(1.0 / 60.0)
	var marker: WeaponMarker = hud.weapon_markers[0]
	var half: Rect2 = _half(0)
	assert_ne(marker.side(), WeaponMarker.Side.NONE, "points the way")
	assert_almost_eq(marker.anchor().y, half.end.y - WeaponMarker.PAD, 1.0, "on the bottom margin")
	assert_true(half.encloses(marker.get_global_rect()), "whole inside player 1's half")


func test_a_duel_keeps_your_weapon() -> void:
	await _start_duel()
	var cam: Camera3D = view.camera
	var p: Vector3 = cam.global_position - cam.global_basis.z * 4.0
	p.y = 0.0
	_drop(0, p)
	hud._process(1.0 / 60.0)
	assert_eq(hud.weapon_marker, hud.weapon_markers[0])
	assert_true(hud.weapon_marker.visible)
	assert_eq(hud.weapon_marker.label.text, "Your weapon")
	assert_false(hud.weapon_markers[1].visible)


func test_the_results_hide_both_markers() -> void:
	await _start()
	_drop(0, _ahead_of(0))
	_drop(1, _ahead_of(1))
	hud._process(1.0 / 60.0)
	hud._on_match_finished(host.results())
	for i: int in 2:
		assert_false(hud.weapon_markers[i].visible)
		assert_eq(hud.prompt_columns[i].get_child_count(), 0)
