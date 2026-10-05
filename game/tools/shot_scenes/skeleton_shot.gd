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
## "watch_start" is Watch's first round call (23.5). --mirror makes the
## computer duels (Watch's among them) a Rogue against a Rogue.
##
## "mirror" is a Rogue against a Rogue in her two palettes. "spacing" sets the
## fighters --spacing= metres apart (2.5 by default), to check that the
## player never hides the opponent from the gameplay camera.
##
## "select_duel" and "select_watch" show the fighter select (22.5): a Duel on
## your side, and Watch on its second side.
##
## "select_preview" shows the fighter select's 3D preview (22.7) on your side
## of a Duel: --fighter=rogue|hunter, --weapon=katana|greatsword|daggers and
## --palette=0|1 (1 shows the opponent's side of a mirror match, in the second
## palette), turned --turn= degrees (20 by default) and held still.
##
## "iai_stance", "iai_vertical" and "iai_horizontal" show the player's Rogue
## with the Katana's Iai Slash against an idle training dummy: sheathed in the
## stance, from her front left so the left hip shows, and each draw on frame
## --frame= (16 by default, the end of its wind-up, just before the cut; 12 is
## halfway through the draw), the horizontal from her front right so its
## wind-up at the right shoulder shows.
##
## --reduce-flashes plays any shot with Reduce flashes and shaking on (18.11):
## the parry's glow and the fighters' body flashes dimmed.
##
## --no-packs plays any shot as a fresh clone without the Iglesias clip
## libraries does: the CC0 fallback clips and the HUD's "animation packs
## missing" note (authored-animation task 8).
##
## "trail_light", "trail_unblockable" and "trail_moonsplitter" show the
## brush-stroke trails (18.3) on the same Rogue against the idle dummy: Right
## Cut and Swallow Sweep on their last active frame, and Moonsplitter on the
## fifth frame of its release (--frame= sets the attack's frame, or the
## release's). Every step is drawn, as in play, so the ribbon is laid frame
## by frame, and the camera stands off her front left, raised to see the
## stroke's arc.
##
## "training_swap" shows the Hunter dummy, picked with the Greatsword, after
## Thrust was chosen for it (23.2): it swapped to the Katana, which the HUD's
## plate names, and is 30 steps into its drill. "training_panel" shows the
## Training panel at the bottom left (23.3): the dummy on Light chains with
## refill off, 40 steps into its drill.
## "recall_burst" shows the recall's power-up (task 30b) on the disarmed Rogue
## against the idle dummy at 2.2 m, up to its frame --frame= (default 18,
## just after the burst): the aura, the burst's flare and shockwave, the dummy
## blasted down.
##
## "toasts" shows three toasts (24.3) in their hold, by --toasts=: "player"
## (gold Parry, the jade Evade counter with its advice, the opponent's red
## Ultimate), "training" (the dim Dummy behaviour and Evaded, the jade Behind
## them), "watch" (named in the sides' red and blue) or "timing" (Training's
## parry timing, 23.4: the gold Parry with its frames before impact and
## window, then the dim Too early and Too late).
##
## "prompts" shows the prompts (24.4) by --prompts=: "keyboard" (the
## disarmed Rogue 1.5 m from her Katana with the ultimate ready: the urgent
## pick-up over Ultimate ready, in keyboard and mouse names), "pad" (the same
## after a PlayStation controller was used) or "tilt" (the Moonsplitter's
## wind-up on that controller, naming the stick, over the counter lunge).
##
## "marker" shows the marker on the disarmed Rogue's Katana (24.5) by
## --marker=: "on" (on the floor ahead, between her and the dummy, the arrow
## down at it), "edge" (8 m off to her right, clamped to the right edge) or
## "behind" (7 m behind her, behind the camera, clamped to the bottom).

const SEED: int = 7

@export_enum(
	"round_start", "exchange", "parry", "watch", "watch_start", "dropped", "results", "main_menu", "title", "mirror", "spacing", "hud_states", "ko", "call",
	"iai_stance", "iai_vertical", "iai_horizontal", "select_duel", "select_watch", "select_preview",
	"trail_light", "trail_unblockable", "trail_moonsplitter", "training_swap", "training_panel",
	"recall_burst", "toasts", "prompts", "marker",
) var shot: String = "round_start"
## The fighters' distance apart for the "spacing" shot (m).
@export var spacing: float = 2.5
## The Iai draw shots' attack frame.
@export var iai_frame: int = 16
## The trail shots' attack (or release) frame; -1 for the default.
@export var trail_frame: int = -1
## The "call" shot's announcement (24.2), from the player's side: final_round,
## fight, double_ko, round_won (Perfect) or disarmed (--call= sets it too).
@export var call: String = "final_round"
## The "toasts" shot's form: player, training, watch or timing (--toasts= sets
## it too).
@export var toasts_form: String = "player"
## The "prompts" shot's form: keyboard, pad or tilt (--prompts= sets it too).
@export var prompts_form: String = "keyboard"
## Where the "marker" shot's weapon lies: on, edge or behind (--marker= sets
## it too).
@export var marker_place: String = "on"
## The "ko" shot's steps after the K.O. (--frame= sets it too).
@export var steps_after: int = 16
## The "hud_states" shot with the two sides' states swapped.
@export var swap_sides: bool = false
## The "hud_states" shot's moment in the low-HP pulse and the full posture's
## blink, before the shot's 0.1 s step (s): 0.25 lands on 0.35 s, the pulse
## near its brightest with the bar lit; 0.1 on 0.2 s, the pulse lower with
## the bar dimmed.
@export var blink_time: float = 0.25
## The "select_preview" shot's fighter, weapon, palette (the side shown) and
## turn in degrees (--fighter=, --weapon=, --palette=, --turn=).
@export var preview_fighter: StringName = &"rogue"
@export var preview_weapon: StringName = &"katana"
@export var preview_palette: int = 0
@export var preview_turn: float = 20.0
## The computer duels with a Rogue on both sides (--mirror).
@export var mirror: bool = false
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
			trail_frame = iai_frame
			steps_after = iai_frame
		elif a.begins_with("--call="):
			call = a.trim_prefix("--call=")
		elif a.begins_with("--toasts="):
			toasts_form = a.trim_prefix("--toasts=")
		elif a.begins_with("--prompts="):
			prompts_form = a.trim_prefix("--prompts=")
		elif a.begins_with("--marker="):
			marker_place = a.trim_prefix("--marker=")
		elif a.begins_with("--fighter="):
			preview_fighter = StringName(a.trim_prefix("--fighter="))
		elif a.begins_with("--weapon="):
			preview_weapon = StringName(a.trim_prefix("--weapon="))
		elif a.begins_with("--palette="):
			preview_palette = int(a.trim_prefix("--palette="))
		elif a.begins_with("--turn="):
			preview_turn = float(a.trim_prefix("--turn="))
		elif a == "--mirror":
			mirror = true
		elif a == "--no-packs":
			ClipLibraries.force_missing = true
		elif a == "--reduce-flashes":
			# the run's own settings (shot runs use the defaults, never saved)
			GameServices.settings.reduce_flashes = true
	match shot:
		"watch_start":
			# Watch's first round call over the side-on camera (23.5)
			_gameplay(MatchConfig.WATCH)
			host.step(40)
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
		"select_duel":
			# the fighter select on your side, over the duel behind the menus
			_main()
			main.call("open_select", MatchConfig.DUEL)
			host.step(420)
		"select_preview":
			_main()
			main.call("open_select", MatchConfig.DUEL)
			_select_preview()
		"select_watch":
			# the Watch select on its second side: the skill row, the arena
			# slot and Lock in
			_main()
			main.call("open_select", MatchConfig.WATCH)
			(main.get("select") as FighterSelect).show_side(1)
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
		"trail_light", "trail_unblockable", "trail_moonsplitter":
			_trail(shot)
		"training_swap":
			var cfg: MatchConfig = MatchConfig.default_training(SEED)
			_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(FakeDeviceState.new()))
			host.step(Match.INTRO_FRAMES + 20)
			_place_apart(2.6)
			host.set_training_behaviour(&"thrust")
			host.step(30)
		"training_panel":
			var cfg: MatchConfig = MatchConfig.default_training(SEED)
			_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(FakeDeviceState.new()))
			host.step(Match.INTRO_FRAMES + 20)
			_place_apart(2.6)
			host.set_training_behaviour(&"lights")
			host.set_refill(false)
			host.step(40)
		"recall_burst":
			_recall_burst()
		"toasts":
			_toasts_shot()
		"prompts":
			_prompts_shot()
		"marker":
			_marker_shot()
			# the Training panel settles its size over a frame or two; the
			# marker keeps off it by its rect
			for k: int in 2:
				await get_tree().process_frame
	var view: MatchView = host.get_node("View")
	view.snap_camera()
	if shot == "dropped":
		_frame_dropped(view.camera)
	elif shot.begins_with("iai_"):
		_frame_front(view.camera, 0, shot == "iai_horizontal")
	elif shot.begins_with("trail_") or shot == "recall_burst":
		_frame_raised(view.camera, 0)
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


## Three toasts of toasts_form, made a few steps apart and held 20 steps on
## (all in their hold): a Duel with the player on side 0, Training against an
## idle dummy, or Watch. The match's own events are cut off from the HUD
## after the intro, so a live parry can't push one of them out.
func _toasts_shot() -> void:
	var events: Array[Dictionary] = []
	match toasts_form:
		"training", "timing":
			var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
			dummy.controller = MatchSide.DUMMY
			var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana"), dummy, SEED)
			_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(FakeDeviceState.new()))
			if toasts_form == "timing":
				events = [{"t": &"parry", "parrier": 0, "attacker": 1, "kind": &"parry", "timing": 4, "window": 9}]
			else:
				events = [{"t": &"evade", "f": 0, "attacker": 1}, {"t": &"backstabReady", "f": 0}]
		"watch":
			_gameplay(MatchConfig.WATCH)
			events = [
				{"t": &"parry", "parrier": 0, "attacker": 1, "kind": &"parry", "timing": 3, "window": 6},
				{"t": &"counter", "kind": &"stomp", "by": 1, "on": 0},
				{"t": &"ultStart", "f": 1, "ult": &"impaler"},
			]
		_:
			var cfg: MatchConfig = MatchConfig.make(
				MatchConfig.DUEL,
				MatchSide.human(&"rogue", &"katana", 0),
				MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"),
				SEED,
			)
			_gameplay(MatchConfig.DUEL, cfg, InputDevices.new(FakeDeviceState.new()))
			events = [
				{"t": &"parry", "parrier": 0, "attacker": 1, "kind": &"parry", "timing": 3, "window": 6},
				{"t": &"counter", "kind": &"evade", "by": 0, "on": 1},
				{"t": &"ultStart", "f": 1, "ult": &"impaler"},
			]
	host.step(Match.INTRO_FRAMES + 10)
	var hud: MatchHud = host.get_node("Hud")
	# only the shot's own toasts: the live duel's events no longer reach the HUD
	host.sim_event.disconnect(hud._on_sim_event)
	if toasts_form == "training":
		host.set_training_behaviour(&"lights")
		host.step(4)
	for e: Dictionary in events:
		hud._on_sim_event(e)
		host.step(4)
	if toasts_form == "timing":
		# a hit 6 frames past the window of a press, then a press 2 frames
		# after a block
		var me: Fighter = host.fighter(0)
		me.parry_window_at_press = 9
		me.block_press_frame = host.world.frame - 15
		hud._on_sim_event({"t": &"hit", "attacker": 1, "target": 0, "backstab": false})
		host.step(4)
		# the block long after any press, so it isn't too early as well
		me.block_press_frame = host.world.frame - 100
		hud._on_sim_event({"t": &"block", "attacker": 1, "target": 0})
		host.step(2)
		me.block_press_frame = host.world.frame
		host.step(2)
	host.step(20)
	hud._process(0.0)


## The player's Rogue 2.6 m from an idle training dummy at 20 HP (the
## ultimate ready), by prompts_form: disarmed with her Katana on the ground
## 1.5 m away, on the keyboard or after a PlayStation controller was used;
## or ("tilt") in the Moonsplitter's wind-up on that controller with a
## counter lunge open.
func _prompts_shot() -> void:
	var devices: FakeDeviceState = FakeDeviceState.new()
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana"), dummy, SEED)
	_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(devices))
	host.step(Match.INTRO_FRAMES + 20)
	_place_apart(2.6)
	if prompts_form != "keyboard":
		devices.plug_pad(0, "PS5 Controller")
		var press := InputEventJoypadButton.new()
		press.button_index = JOY_BUTTON_A
		press.pressed = true
		host.input.note_event(press)
	var a: Fighter = host.fighter(0)
	a.hp = 20.0
	if prompts_form == "tilt":
		a.start_ult()
		a.counter_lunge_until = host.world.frame + 30
		host.step(4)
		return
	a.armed = false
	var b: Fighter = host.fighter(1)
	var away: Vector3 = Vector3(a.pos.x - b.pos.x, 0.0, a.pos.z - b.pos.z).normalized()
	var w := DroppedWeapon.new(0, &"katana", V3.make(a.pos.x + away.x * 1.5, 0.0, a.pos.z + away.z * 1.5), V3.make(), Rng.new(SEED))
	w.grounded = true
	host.world.weapons.append(w)
	host.step(2)


## The player's Rogue, disarmed, 2.6 m from an idle training dummy, her
## Katana lying where marker_place puts it (relative to her and the dummy,
## so to the follow camera behind her).
func _marker_shot() -> void:
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana"), dummy, SEED)
	_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(FakeDeviceState.new()))
	host.step(Match.INTRO_FRAMES + 20)
	_place_apart(2.6)
	var a: Fighter = host.fighter(0)
	var b: Fighter = host.fighter(1)
	var ahead: Vector3 = Vector3(b.pos.x - a.pos.x, 0.0, b.pos.z - a.pos.z).normalized()
	var right: Vector3 = ahead.cross(Vector3.UP)
	var at: Vector3 = Vector3(a.pos.x, 0.0, a.pos.z)
	match marker_place:
		"edge":
			at += right * 8.0 + ahead * 1.0
		"behind":
			at -= ahead * 7.0
		_:
			at += ahead * 1.2 + right * 0.9
	a.armed = false
	var w := DroppedWeapon.new(0, &"katana", V3.make(at.x, 0.0, at.z), V3.make(), Rng.new(SEED))
	w.grounded = true
	host.world.weapons.append(w)
	host.step(2)


func _config(mode: StringName) -> MatchConfig:
	return MatchConfig.make(
		mode,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"rogue" if mirror else &"hunter", &"greatsword", 1, &"hard"),
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


## The player's Rogue 2.6 m from an idle training dummy strikes: Right Cut
## (trail_light), Swallow Sweep (trail_unblockable) or Moonsplitter, every
## step drawn so the trails are laid as in play, up to trail_frame.
func _trail(which: String) -> void:
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana"), dummy, SEED)
	_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(FakeDeviceState.new()))
	host.step(Match.INTRO_FRAMES + 20)
	_place_apart(2.6)
	var view: MatchView = host.get_node("View")
	var a: Fighter = host.fighter(0)
	var done: Callable
	if which == "trail_moonsplitter":
		a.hp = 20.0
		a.start_ult()
		var at: int = trail_frame if trail_frame >= 0 else 5
		done = func() -> bool: return a.ult == null or (a.ult.phase == &"release" and a.ult.pf >= at)
	else:
		a.start_attack(&"k_l1" if which == "trail_light" else &"k_sweep")
		var def: AttackDef = a.atk.def
		var at: int = trail_frame if trail_frame >= 0 else def.startup + def.active
		done = func() -> bool: return a.atk == null or a.atk.frame >= at
	for k: int in 200:
		if done.call():
			break
		host.step(1)
		view.render(1.0 / 60.0)


## The player's Rogue, disarmed, 2.2 m from an idle training dummy, recalls
## her Katana (task 30b): the power-up, its aura swelling, the burst on frame
## 16 blasting the dummy down, every step drawn, up to the recall's frame
## trail_frame (default 18, just after the burst).
func _recall_burst() -> void:
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana"), dummy, SEED)
	_gameplay(MatchConfig.TRAINING, cfg, InputDevices.new(FakeDeviceState.new()))
	host.step(Match.INTRO_FRAMES + 20)
	_place_apart(2.2)
	var view: MatchView = host.get_node("View")
	var a: Fighter = host.fighter(0)
	a.armed = false
	a.set_state(&"recall", SimConst.RECALL_FRAMES)
	var at: int = trail_frame if trail_frame >= 0 else SimConst.RECALL_BURST_FRAME + 2
	for k: int in 120:
		if a.state != &"recall" or a.sf >= at:
			break
		host.step(1)
		view.render(1.0 / 60.0)


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


## Puts the camera 3.4 m off fighter i's left, a little ahead, and 2.3 m up,
## looking down at the space in front of her, so a cut's arc reads clear of
## the opponent.
func _frame_raised(camera: Camera3D, i: int) -> void:
	var at: Vector3 = host.display_position(i)
	var yaw: float = host.display_yaw(i)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var side: Vector3 = Vector3.UP.cross(forward)
	camera.global_position = at + (side * 0.95 + forward * 0.3).normalized() * 3.4 + Vector3(0.0, 2.3, 0.0)
	camera.look_at(at + forward * 0.7 + Vector3(0.0, 1.0, 0.0))


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


## Sets the select's side for the "select_preview" shot and turns its
## preview to --turn=, then holds it still.
func _select_preview() -> void:
	var select: FighterSelect = main.get("select")
	for side: int in 2:
		MatchSelection.set_fighter(select.draft, side, preview_fighter)
		MatchSelection.set_weapon(select.draft, side, preview_weapon)
	select.show_side(clampi(preview_palette, 0, 1))
	host.step(420)
	var p: FighterPreview = select.preview
	p.set_process(false)
	p.advance(preview_turn / 360.0 * FighterPreview.TURN_SECONDS)
