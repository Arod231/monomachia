extends Node
## Screenshot scenes for the playable skeleton (task 6). Each .tscn next to
## this script picks one `shot`; render one with
##   node scripts/godot.mjs shots res://tools/shot_scenes/<name>.tscn <out.png>
##
## Gameplay shots run a deterministic computer-against-computer duel (Rogue
## with katana against Hunter with greatsword, both Hard, seed SEED), step it
## without the clock to a chosen moment, snap the camera and hold still: the
## view and the HUD stop processing once snapped, so the wall clock (idle bob,
## shake decay, the menu orbit) can't change the picture between runs.
##
## "mirror" is a Rogue against a Rogue in her two palettes. "spacing" sets the
## fighters --spacing= metres apart (2.5 by default), to check that the
## player never hides the opponent from the gameplay camera.
##
## "iai_stance", "iai_vertical" and "iai_horizontal" show the player's Rogue
## with the Katana's Iai Slash against an idle training dummy: sheathed in the
## stance, from her front left so the left hip shows, and each draw on frame
## --frame= (16 by default, the end of its wind-up, just before the cut; 12 is
## halfway through the draw), the horizontal from her front right so its
## wind-up at the right shoulder shows.

const SEED: int = 7

@export_enum(
	"round_start", "exchange", "parry", "watch", "dropped", "results", "main_menu", "title", "mirror", "spacing", "hud_states", "ko", "call",
	"iai_stance", "iai_vertical", "iai_horizontal",
) var shot: String = "round_start"
## The fighters' distance apart for the "spacing" shot (m).
@export var spacing: float = 2.5
## The Iai draw shots' attack frame.
@export var iai_frame: int = 16
## The "call" shot's announcement (24.2), from the player's side: final_round,
## fight, double_ko, round_won (Perfect) or disarmed (--call= sets it too).
@export var call: String = "final_round"
## The "ko" shot's steps after the K.O. (--frame= sets it too).
@export var steps_after: int = 16
## The "hud_states" shot with the two sides' states swapped.
@export var swap_sides: bool = false
## The "hud_states" shot's moment in the low-HP pulse and the full posture's
## blink, before the shot's 0.1 s step (s): 0.25 lands on 0.35 s, the pulse
## near its brightest with the bar lit; 0.1 on 0.2 s, the pulse lower with
## the bar dimmed.
@export var blink_time: float = 0.25
## Frames to let the renderer settle before the capture.
@export var settle_frames: int = 10

var host: MatchHost
var main: Node
var _ready_flag: bool = false
var _parried: bool = false
var _katana_hit: bool = false
var _ko: bool = false


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--spacing="):
			spacing = float(a.trim_prefix("--spacing="))
		elif a.begins_with("--frame="):
			iai_frame = int(a.trim_prefix("--frame="))
			steps_after = iai_frame
		elif a.begins_with("--call="):
			call = a.trim_prefix("--call=")
	match shot:
		"round_start":
			_gameplay(MatchConfig.DUEL)
			host.step(40)
		"exchange":
			_gameplay(MatchConfig.DUEL)
			_step_until(_exchanging, 20000, 300)
		"parry":
			_gameplay(MatchConfig.DUEL)
			host.sim_event.connect(_on_event)
			_step_until(func() -> bool: return _parried, 40000, 0)
		"watch":
			# the katana (side 0) landing a cut, two steps on: the hit flash,
			# the defender reeling, held by the hit-stop
			_gameplay(MatchConfig.WATCH)
			host.step(600)
			host.sim_event.connect(_on_event)
			_step_until(func() -> bool: return _katana_hit, 40000, 0)
			host.step(2)
		"dropped":
			# the first weapon knocked out of a hand, lying on the floor
			# under its marker
			_gameplay(MatchConfig.WATCH)
			_step_until(_weapon_down, 200000, 0)
		"results":
			_main()
			main.call("start_match", _config(MatchConfig.DUEL))
			_step_until(func() -> bool: return host.is_finished(), 200000, 0)
			host.step(30)
		"main_menu":
			_main()
			main.call("show_main_menu")
			host.step(420)
		"title":
			_main()
			host.step(420)
		"mirror":
			_gameplay(MatchConfig.DUEL, MatchConfig.make(
				MatchConfig.DUEL,
				MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
				MatchSide.computer(&"rogue", &"katana", 1, &"hard"),
				SEED,
			))
			host.step(Match.INTRO_FRAMES + 30)
		"spacing":
			_gameplay(MatchConfig.DUEL)
			host.step(Match.INTRO_FRAMES + 20)
			_place_apart(spacing)
		"ko":
			# the first round's K.O. call (24.2), its entrance over: --frame=
			# steps after the K.O.
			_gameplay(MatchConfig.WATCH)
			host.sim_event.connect(_on_event)
			_step_until(func() -> bool: return _ko, 200000, 0)
			host.step(steps_after)
		"call":
			_call_shot()
		"hud_states":
			_gameplay(MatchConfig.DUEL)
			host.step(Match.INTRO_FRAMES + 60)
			_set_hud_states()
		"iai_stance", "iai_vertical", "iai_horizontal":
			_iai(shot)
	var view: MatchView = host.get_node("View")
	view.snap_camera()
	if shot == "dropped":
		_frame_dropped(view.camera)
	elif shot.begins_with("iai_"):
		_frame_front(view.camera, 0, shot == "iai_horizontal")
	var hud: MatchHud = host.get_node("Hud")
	hud.snap_bars()
	if shot == "hud_states":
		# a hit just taken (from the 40 HP _set_hud_states gave): the low
		# side's lag band held where its HP was; and the pulse and blink at a
		# chosen moment
		host.fighter(1 if swap_sides else 0).hp = 18.0
		hud.set("_blink", blink_time)
		hud._process(0.1)
	view.set_process(false)
	hud.set_process(false)
	_ready_flag = true


## Every top-bar state at once (task 24.1): one side at 40 HP (cut to 18 for
## the shot, for the lag band), posture hot, the ultimate ready, a round won;
## the other with posture full, the ultimate used, its weapon lost and two
## rounds won (all three when swapped, which only a shot can show).
func _set_hud_states() -> void:
	var a: Fighter = host.fighter(1 if swap_sides else 0)
	var b: Fighter = host.fighter(0 if swap_sides else 1)
	a.hp = 40.0
	a.posture = 78.0
	b.hp = 15.0
	b.posture = SimConst.POSTURE_MAX
	b.ult_used = true
	b.armed = false
	host.sim_match.wins[a.id] = 1
	host.sim_match.wins[b.id] = 3 if swap_sides else 2


## A duel with the player on side 0, a few steps past the intro, then the
## chosen call, held 20 steps into its run (past the entrance).
func _call_shot() -> void:
	var cfg: MatchConfig = MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.human(&"rogue", &"katana", 0),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"),
		SEED,
	)
	_gameplay(MatchConfig.DUEL, cfg, InputDevices.new(FakeDeviceState.new()))
	host.step(Match.INTRO_FRAMES + 10)
	var hud: MatchHud = host.get_node("Hud")
	match call:
		"final_round":
			host.sim_match.wins[0] = 2
			host.sim_match.wins[1] = 2
			hud._on_sim_event({"t": &"roundStart", "round": 5})
		"fight":
			hud._on_sim_event({"t": &"fight"})
		"double_ko":
			hud._on_sim_event({"t": &"ko", "winner": -1})
		"round_won":
			hud._on_sim_event({"t": &"roundOver", "winner": 0, "perfect": true})
			host.step(MatchHud.ROUND_RESULT_DELAY)
		"disarmed":
			hud._on_sim_event({"t": &"disarm", "victim": 0})
	host.step(20)


func _config(mode: StringName) -> MatchConfig:
	return MatchConfig.make(
		mode,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"),
		SEED,
	)


## Starts a match on a stepped host: cfg, or the duel of _config(mode). With
## devices set, the host reads the players' input from it, on the default
## controls profiles.
func _gameplay(mode: StringName, cfg: MatchConfig = null, devices: InputDevices = null) -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	if devices != null:
		host.input = devices
		host.profiles = ControlProfiles.new()
	add_child(host)
	host.start(cfg if cfg != null else _config(mode))


## Moves the fighters to `metres` apart about their midpoint, on the line
## between them, standing still, and steps twice so the view, which shows
## the position before the last step until the next, shows it.
func _place_apart(metres: float) -> void:
	var a: Fighter = host.fighter(0)
	var b: Fighter = host.fighter(1)
	var mid: Vector3 = Vector3(a.pos.x + b.pos.x, 0.0, a.pos.z + b.pos.z) * 0.5
	var along: Vector3 = Vector3(b.pos.x - a.pos.x, 0.0, b.pos.z - a.pos.z).normalized()
	for pair: Array in [[a, -0.5], [b, 0.5]]:
		var f: Fighter = pair[0]
		var at: Vector3 = mid + along * metres * float(pair[1])
		f.pos = V3.make(at.x, 0.0, at.z)
		f.vel = V3.make()
	host.step(2)


## The player's Rogue (side 0, on the default keyboard profile through a
## fake device) 2.6 m from an idle training dummy holds heavy (K): the
## Iai's sheathe, then 40 steps into the stance, where "iai_stance" stops.
## For a draw, heavy is let go, with the stick right (D) for the horizontal,
## and the shot steps on to the attack's frame iai_frame.
func _iai(which: String) -> void:
	var keys: FakeDeviceState = FakeDeviceState.new()
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana"), dummy, SEED)
	_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(keys))
	host.step(Match.INTRO_FRAMES + 20)
	_place_apart(2.6)
	keys.press_key(KEY_K)
	host.step(Fighter.CHARGE_CHECK_FRAME + 40)
	if which == "iai_stance":
		return
	if which == "iai_horizontal":
		keys.press_key(KEY_D)
	keys.release_key(KEY_K)
	var a: Fighter = host.fighter(0)
	_step_until(func() -> bool: return a.state == &"attack" and a.atk.frame >= iai_frame, 60, 0)


func _main() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	host = main.get_node("MatchHost")
	host.auto_run = false


## Steps until cond() holds (checked after at least min_steps), at most limit steps.
func _step_until(cond: Callable, limit: int, min_steps: int) -> void:
	var n: int = 0
	while n < limit:
		host.step(1)
		n += 1
		if n >= min_steps and cond.call():
			return
	push_warning("skeleton_shot: %s not reached in %d steps" % [shot, limit])


## Fighters close, the opponent (side 1, facing the camera) one frame before
## a slash or an overhead lands.
func _exchanging() -> bool:
	var a: Fighter = host.fighter(0)
	var b: Fighter = host.fighter(1)
	if Vector2(a.pos.x - b.pos.x, a.pos.z - b.pos.z).length() > 3.0:
		return false
	if b.state != &"attack" or b.atk == null or b.atk.charging:
		return false
	var d: AttackDef = b.atk.def
	return (d.type == &"slash" or d.type == &"overhead") and b.atk.frame == d.startup


## Puts the camera 3.5 m beyond the grounded weapon, looking past it at the
## fighters, so the blade, its marker and the fight share the frame.
func _frame_dropped(camera: Camera3D) -> void:
	for w: DroppedWeapon in host.world.weapons:
		if not w.grounded:
			continue
		var at := Vector3(w.pos.x, 0.0, w.pos.z)
		var mid: Vector3 = (host.display_position(0) + host.display_position(1)) * 0.5
		mid.y = 0.0
		var away: Vector3 = (at - mid).normalized() if at.distance_to(mid) > 0.1 else Vector3.BACK
		camera.global_position = at + away * 3.5 + Vector3(0.0, 1.7, 0.0)
		camera.look_at(at.lerp(mid, 0.35) + Vector3(0.0, 0.5, 0.0))
		return


## Puts the camera 2.6 m off fighter i's front left (or front right), at
## chest height, looking at its waist.
func _frame_front(camera: Camera3D, i: int, right: bool) -> void:
	var at: Vector3 = host.display_position(i)
	var yaw: float = host.display_yaw(i)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var side: Vector3 = Vector3.UP.cross(forward) * (-1.0 if right else 1.0)
	camera.global_position = at + (side * 0.8 + forward * 0.6).normalized() * 2.6 + Vector3(0.0, 1.4, 0.0)
	camera.look_at(at + Vector3(0.0, 1.05, 0.0))


func _weapon_down() -> bool:
	for w: DroppedWeapon in host.world.weapons:
		if w.grounded:
			return true
	return false


func _on_event(e: Dictionary) -> void:
	if e["t"] == &"parry":
		_parried = true
	elif e["t"] == &"ko":
		_ko = true
	elif e["t"] == &"hit" and int(e["attacker"]) == 0 and not _katana_hit:
		_katana_hit = true
