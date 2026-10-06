class_name SoundCheck
extends Node3D
## The sound check: a scene for listening to the game's sound, step by step.
## It plays every rules event's cues (each one the sound bank picks by weight,
## weapon or kind), the menu sounds, one hit at growing distances, the
## footsteps at each pace, the arena's ambience, the three music tracks with
## their switches, and heavy hits ducking the music and the ambience, so the
## owner can hear what a Duel rarely triggers. Play it with
##   node scripts/godot.mjs run res://tools/sound_check.tscn
##
## It plays at the game's levels (GameServices applies the saved volumes at
## start) through the game's own players: a [SoundPlayer] for the cues, a
## [FadedLoop] for the ambience, and a [MusicPlayer] following a
## [MusicDirector] for the music. The camera stands where the gameplay camera
## follows your fighter (blue), with the opponent (red) at duelling distance,
## and each event plays where it would in a match: at its contact point, or at
## the chest of the fighter it names. A white ball marks each 3D cue.
##
## Every step starts from silence and moves on when its last sound has played.
## Keys: Right and Left step, Down and Up jump between sections, Enter (or R)
## plays the step again, Space stops and restarts the stepping on, Esc quits.

## A step began (each start, replays included).
signal step_started(index: int)

## Silence after a step's last sound, before the next step (s).
const GAP := 0.6
## Your fighter's feet and the opponent's, at duelling distance, and the height
## their sounds come from (as MatchAudio).
const YOU := Vector3(0.0, 0.0, 1.5)
const FOE := Vector3(0.0, 0.0, -1.5)
const CHEST := 1.25
## Where blows land: between the fighters, at chest height.
const CONTACT := Vector3(0.0, 1.25, 0.0)
## The camera, where the gameplay camera follows your fighter (CameraRig's
## follow_back, follow_side and follow_height), looking at the opponent.
const CAMERA_AT := Vector3(1.35, 1.95, 6.1)
const LOOK_AT := Vector3(0.0, 1.3, -1.5)
## Who fights: you are the Hunter, so the Hunter's own cloth, gear and voice
## are heard near the camera (SoundBank.FOLEY, VOCALS), and the opponent the
## Rogue, who moves with the general cloth.
const CAST: Array = [&"hunter", &"rogue"]
## How far in front of the camera the distance step's hits land (m).
const DISTANCES: Array[float] = [1.5, 3.0, 6.0, 12.0, 24.0]
## The footstep steps' paces (m/s): the guard walk's fastest, the run's
## fastest and the sprint (see FootstepCadence).
const PACES: Array = [["your guard walk", 2.34], ["your run", 4.7], ["your sprint", 7.2]]
## How long each footstep step walks (s).
const WALK_SECONDS := 3.0

## Step on by itself every frame. Tests turn it off and call [method advance].
@export var auto_run := true

## The steps, in order: [code]{"section", "label", "actions", "seconds"}[/code],
## where each action has a "time" (s into the step) and one of: "event" (a
## rules or menu event, played as the game plays it), "cue" with "pos" (one cue
## there), "ambience" (a loop cue to fade in, or &"" to fade it out), "music"
## (&"menu" or &"match" for the director's call, &"stop" to fade out) or
## "music_event" (an event fed to the director). "seconds" is the least the
## step lasts; it lasts until its last sound ends in any case.
var steps: Array[Dictionary] = make_steps()
## Move on when a step ends; Space turns it off and on.
var auto_advance := true
## The step playing, or -1 before the first.
var index := -1

var player: SoundPlayer
var ambience: FadedLoop
var director := MusicDirector.new()
var music: MusicPlayer
var camera: Camera3D

var _time := 0.0
var _seconds := 0.0
var _next := 0
var _finished := false
var _lines: PackedStringArray = []
var _label: Label
var _ping: MeshInstance3D
var _ping_left := 0.0


func _ready() -> void:
	_build_stage()
	player = SoundPlayer.new()
	player.name = "Sounds"
	player.auto_run = false
	add_child(player)
	player.played.connect(_on_played)
	ambience = FadedLoop.new()
	ambience.name = "Ambience"
	ambience.auto_run = false
	add_child(ambience)
	music = MusicPlayer.new()
	music.name = "Music"
	music.auto_run = false
	add_child(music)
	music.bind(director)
	_build_text()
	if auto_run:
		start(0)


func _process(delta: float) -> void:
	if auto_run:
		advance(delta)
	_refresh()


## Starts step [param i] from silence.
func start(i: int) -> void:
	_silence()
	index = clampi(i, 0, steps.size() - 1)
	_time = 0.0
	_next = 0
	_seconds = step_seconds(steps[index])
	_finished = false
	_lines.clear()
	step_started.emit(index)
	_run_due()


## Moves the step on by [param delta] seconds, and on to the next step when
## this one is over (unless the stepping is stopped).
func advance(delta: float) -> void:
	_ping_left -= delta
	if _ping != null:
		_ping.visible = _ping_left > 0.0
	if index < 0 or _finished:
		return
	player.advance(delta)
	ambience.advance()
	music.advance()
	_time += delta
	_run_due()
	if _time >= _seconds and auto_advance:
		if index + 1 < steps.size():
			start(index + 1)
		else:
			_finished = true
			_silence()


func is_finished() -> bool:
	return _finished


## How long a step lasts (s): until its last sound has played out, and at
## least its "seconds", then a short gap.
func step_seconds(step: Dictionary) -> float:
	var end := float(step.get("seconds", 0.0))
	for action: Dictionary in step["actions"]:
		var t := float(action["time"])
		if action.has("event"):
			for cue: Dictionary in SoundBank.cues_for(action["event"], CAST):
				end = maxf(end, t + float(cue["delay"]) + cue_seconds(cue["cue"]) / float(cue["pitch_scale"]))
		elif action.has("cue"):
			end = maxf(end, t + cue_seconds(action["cue"]))
		elif action.has("footfall"):
			for cue: StringName in SoundBank.footfall_cues(CAST[int(action["footfall"])]):
				end = maxf(end, t + cue_seconds(cue))
		else:
			end = maxf(end, t)
	return end + GAP


## The longest a cue can sound (s): its longest file at its lowest pitch.
func cue_seconds(cue_name: StringName) -> float:
	var longest := 0.0
	for path: String in SoundBank.paths_for(cue_name):
		var stream := player.stream_for(path)
		if stream != null:
			longest = maxf(longest, stream.get_length())
	return longest / (SoundBank.CUES[cue_name]["pitch"] as Vector2).x


## Where an event happens, as MatchAudio places it: its contact point (pos),
## where lightning strikes (to), else the chest of the fighter it names.
func event_position(e: Dictionary) -> Variant:
	if e.has("pos"):
		return _vector(e["pos"])
	if e.has("to"):
		return _vector(e["to"])
	for key: String in MatchAudio.FIGHTER_KEYS:
		if e.has(key) and (int(e[key]) == 0 or int(e[key]) == 1):
			return (YOU if int(e[key]) == 0 else FOE) + Vector3(0.0, CHEST, 0.0)
	return null


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT:
			if index < steps.size() - 1:
				start(index + 1)
		KEY_LEFT:
			start(index - 1)
		KEY_DOWN:
			var starts := _section_starts()
			for s: int in starts:
				if s > index:
					start(s)
					break
		KEY_UP:
			var starts := _section_starts()
			var here := 0
			for s: int in starts:
				if s <= index:
					here = s
			if index > here:
				start(here)
			else:
				start(starts[maxi(starts.find(here) - 1, 0)])
		KEY_ENTER, KEY_KP_ENTER, KEY_R:
			start(index)
		KEY_SPACE:
			auto_advance = not auto_advance
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


## The first step of each section.
func _section_starts() -> Array[int]:
	var out: Array[int] = []
	for i: int in steps.size():
		if i == 0 or steps[i]["section"] != steps[i - 1]["section"]:
			out.append(i)
	return out


func _run_due() -> void:
	var actions: Array = steps[index]["actions"]
	while _next < actions.size() and float(actions[_next]["time"]) <= _time:
		_do(actions[_next])
		_next += 1


func _do(action: Dictionary) -> void:
	if action.has("event"):
		player.play_event(action["event"], event_position, CAST)
	elif action.has("cue"):
		player.play_cue(action["cue"], action["pos"])
	elif action.has("footfall"):
		# a foot of side "footfall" comes down, as MatchAudio.foot_down
		for cue: StringName in SoundBank.footfall_cues(CAST[int(action["footfall"])]):
			player.play_cue(cue, action["pos"])
	elif action.has("ambience"):
		var cue: StringName = action["ambience"]
		if cue.is_empty():
			ambience.stop()
		else:
			ambience.bus = SoundBank.CUES[cue]["bus"]
			ambience.volume_db = SoundBank.CUES[cue]["volume_db"]
			ambience.play(player.stream_for(SoundBank.paths_for(cue)[0]))
	elif action.has("music"):
		match action["music"]:
			&"menu":
				music.play(director.enter_menu())
			&"match":
				music.play(director.enter_match())
			_:
				music.stop()
	elif action.has("music_event"):
		director.handle_event(action["music_event"])


func _silence() -> void:
	player.stop_all()
	ambience.stop()
	music.stop()


func _on_played(cue: StringName, voice: Node) -> void:
	var where := "flat"
	if voice is AudioStreamPlayer3D:
		var at := (voice as Node3D).global_position
		where = "3D, %.1f m away" % at.distance_to(camera.global_position)
		_ping.global_position = at
		_ping_left = 0.3
	var stream: AudioStream = voice.get("stream")
	_lines.append("%s   %s   %+.1f dB   pitch %.2f   %s   %s" % [
		cue, stream.resource_path.get_file(), float(voice.get("volume_db")), float(voice.get("pitch_scale")),
		voice.get("bus"), where])
	if _lines.size() > 12:
		_lines.remove_at(0)


func _refresh() -> void:
	if _label == null or index < 0:
		return
	var step := steps[index]
	var text := "SOUND CHECK   step %d of %d%s\n\n" % [index + 1, steps.size(), "   (finished)" if _finished else ""]
	text += "%s: %s\n\n" % [step["section"], step["label"]]
	text += "\n".join(_lines)
	var track := music.current_track()
	text += "\n\nMusic: %s   Ambience: %s\n" % [
		"off" if track.is_empty() else "%s (%d BPM)" % [track, int(MusicDirector.track_info(track).get("bpm", 0))],
		"on" if ambience.is_playing() else "off"]
	if index + 1 < steps.size():
		text += "Next: %s: %s\n" % [steps[index + 1]["section"], steps[index + 1]["label"]]
	text += "\nRight/Left: step   Down/Up: section   Enter: again   Space: stepping on is %s   Esc: quit" % (
		"ON" if auto_advance else "OFF")
	_label.text = text


## The camera, a floor, the two fighters as capsules and the ball that marks
## each 3D cue.
func _build_stage() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 60.0
	add_child(camera)
	camera.look_at_from_position(CAMERA_AT, LOOK_AT)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 40.0)
	_add_mesh(floor_mesh, Color(0.22, 0.21, 0.2), Vector3.ZERO)
	for side: Array in [[YOU, Color(0.25, 0.45, 0.95)], [FOE, Color(0.9, 0.25, 0.2)]]:
		var body := CapsuleMesh.new()
		body.radius = 0.3
		body.height = 1.8
		_add_mesh(body, side[1], (side[0] as Vector3) + Vector3(0.0, 0.9, 0.0))
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	_ping = _add_mesh(ball, Color.WHITE, CONTACT)
	(_ping.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ping.visible = false


func _add_mesh(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = at
	add_child(m)
	return m


func _build_text() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24.0, 20.0)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_label)


static func _vector(d: Dictionary) -> Vector3:
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))


static func _dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func _step(section: String, label: String, actions: Array, seconds: float = 0.0) -> Dictionary:
	return {"section": section, "label": label, "actions": actions, "seconds": seconds}


## A step that plays one event at once.
static func _event_step(section: String, label: String, event: Dictionary) -> Dictionary:
	return _step(section, label, [{"time": 0.0, "event": event}])


## The steps: every event (each kind and weight the bank tells apart), the
## menu sounds, the distances, the footsteps, the ambience, the music and the
## ducking. The opponent (fighter 1) acts, so its sounds come from in front;
## movement is your fighter's (0), near the camera, as in a match.
static func make_steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := "Combat and foley"
	var at := _dict(CONTACT)
	for swing: Array in [
		["katana", false, "Katana, light"], ["katana", true, "Katana, heavy"], ["greatsword", false, "Greatsword"],
		["daggers", false, "Daggers, light"], ["daggers", true, "Daggers, heavy"], ["fists", false, "fists"],
	]:
		out.append(_event_step(c, "swing: %s" % swing[2],
			{"t": &"swing", "f": 1, "attack": &"swing", "heavy": swing[1], "weapon": StringName(swing[0])}))
	out.append(_event_step(c, "swing: Katana, light (yours: the Hunter's sleeves and harness)",
		{"t": &"swing", "f": 0, "attack": &"swing", "heavy": false, "weapon": &"katana"}))
	out.append(_event_step(c, "telegraph: an unblockable winds up",
		{"t": &"telegraph", "f": 1, "kind": &"thrust", "attack": &"thrust"}))
	for hit: Array in [
		["blade", false, "blade, light"], ["blade", true, "blade, heavy"], ["dagger", false, "Daggers"],
		["dagger", true, "Daggers, heavy"], ["fist", false, "fist, light"], ["fist", true, "fist, heavy"],
		["colossal", true, "Greatsword"],
	]:
		out.append(_event_step(c, "hit: %s" % hit[2], {"t": &"hit", "attacker": 1, "target": 0, "attack": &"swing",
			"damage": 10.0, "posture": 10.0, "pos": at, "heavy": hit[1], "sound": StringName(hit[0]), "backstab": false}))
	# blocks and parries by the pair of weapons that meet (milestone-1 task
	# 36): the general clangs (a Greatsword on a Katana), the Katana on the
	# Katana, and bare hands against the Katana
	for pair: Array in [["greatsword", "katana", "Greatsword on Katana"], ["katana", "katana", "Katana on Katana"],
			["fists", "katana", "fist on the Katana's guard"]]:
		for heavy: bool in [false, true]:
			out.append(_event_step(c, "block: %s, %s" % [pair[2], "heavy" if heavy else "light"],
				{"t": &"block", "attacker": 1, "target": 0, "attack": &"swing", "posture": 10.0, "pos": at, "heavy": heavy,
				"weapon": StringName(pair[0]), "defender_weapon": StringName(pair[1])}))
	for parry: Array in [[&"parry", "greatsword", "katana", "parry: Greatsword by Katana"],
			[&"flash", "greatsword", "katana", "parry: flash, Greatsword by Katana"],
			[&"parry", "katana", "katana", "parry: Katana by Katana"], [&"flash", "katana", "katana", "parry: flash, Katana by Katana"],
			[&"parry", "fists", "katana", "parry: a fist by the Katana"], [&"flash", "fists", "katana", "parry: flash, a fist by the Katana"],
			[&"redirect", "greatsword", "fists", "parry: redirect, Greatsword by a bare hand"],
			[&"redirect", "katana", "fists", "parry: redirect, Katana by a bare hand"]]:
		out.append(_event_step(c, parry[3],
			{"t": &"parry", "parrier": 0, "attacker": 1, "pos": at, "kind": parry[0], "timing": 4, "window": 8,
			"weapon": StringName(parry[1]), "defender_weapon": StringName(parry[2])}))
	for kind: StringName in [&"stomp", &"leap", &"evade"]:
		out.append(_event_step(c, "counter: %s" % kind, {"t": &"counter", "kind": kind, "by": 0, "on": 1, "pos": at}))
	out.append(_event_step(c, "disarm", {"t": &"disarm", "victim": 1, "by": 0, "pos": at, "reason": &"parried"}))
	out.append(_event_step(c, "stagger: a disarmed fighter's posture breaks", {"t": &"stagger", "f": 1}))
	out.append(_event_step(c, "dodge: a roll (yours)", {"t": &"dodge", "f": 0, "back": false}))
	out.append(_event_step(c, "dodge: a backstep (yours)", {"t": &"dodge", "f": 0, "back": true}))
	out.append(_event_step(c, "dodge: a backstep (the opponent's, the general cloth)", {"t": &"dodge", "f": 1, "back": true}))
	out.append(_event_step(c, "jump (yours)", {"t": &"jump", "f": 0}))
	out.append(_event_step(c, "land (yours)", {"t": &"land", "f": 0}))
	out.append(_event_step(c, "step: a tap step (yours)", {"t": &"step", "f": 0}))
	out.append(_event_step(c, "ko: the drum, the gong, the boom and the body falling", {"t": &"ko", "loser": 1, "winner": 0}))
	out.append(_event_step(c, "ultReady (yours)", {"t": &"ultReady", "f": 0}))
	out.append(_event_step(c, "ultStart", {"t": &"ultStart", "f": 1, "ult": &"moonsplitter"}))
	out.append(_event_step(c, "ultChoice: a disarmed fighter's ultimate", {"t": &"ultChoice", "f": 1}))
	out.append(_event_step(c, "ultWave: the Moonsplitter's wave",
		{"t": &"ultWave", "f": 1, "kind": &"vertical", "pos": at, "yaw": 0.0}))
	out.append(_event_step(c, "ultDash", {"t": &"ultDash", "f": 1}))
	out.append(_event_step(c, "ultImpale", {"t": &"ultImpale", "f": 1, "target": 0}))
	out.append(_event_step(c, "ultBurst", {"t": &"ultBurst", "f": 1, "pos": _dict(FOE + Vector3(0.0, 0.5, 0.0))}))
	out.append(_event_step(c, "ultLightning", {"t": &"ultLightning", "f": 1,
		"from": _dict(YOU + Vector3(0.0, 8.0, 0.0)), "to": _dict(YOU + Vector3(0.0, CHEST, 0.0))}))
	out.append(_event_step(c, "recall: a weapon flies back", {"t": &"recall", "f": 1}))
	out.append(_event_step(c, "recallBurst: the recall's power-up bursts", {"t": &"recallBurst", "f": 1, "on": 0, "hit": true, "reach": 2.5, "pos": at}))
	out.append(_event_step(c, "pickup", {"t": &"pickup", "f": 1}))
	out.append(_event_step(c, "weaponStuck: a disarmed weapon sticks in the ground",
		{"t": &"weaponStuck", "owner": 1, "pos": _dict(FOE + Vector3(1.0, 0.0, 0.0))}))
	out.append(_event_step(c, "roundStart: the round call", {"t": &"roundStart", "round": 1}))
	out.append(_event_step(c, "fight", {"t": &"fight", "round": 1}))

	for ui: StringName in [&"ui_move", &"ui_select", &"ui_confirm", &"ui_back"]:
		out.append(_event_step("Menus", String(ui), {"t": ui}))

	var ahead := (LOOK_AT - CAMERA_AT).normalized()
	var hits: Array = []
	for k: int in DISTANCES.size():
		hits.append({"time": 1.2 * k, "event": {"t": &"hit", "attacker": 1, "target": 0, "attack": &"swing",
			"damage": 10.0, "posture": 10.0, "pos": _dict(CAMERA_AT + ahead * DISTANCES[k]), "heavy": true,
			"sound": &"blade", "backstab": false}})
	out.append(_step("Distance", "a heavy blade hit at 1.5, 3, 6, 12 and 24 m", hits))

	var cadence := FootstepCadence.new()
	var paces: Array = PACES.duplicate()
	paces.append(["the opponent's run", 4.7])
	for pace: Array in paces:
		var speed: float = pace[1]
		var every := cadence.stride_for(speed) / speed
		var feet := FOE if String(pace[0]).begins_with("the opponent") else YOU
		var falls: Array = []
		var t := 0.0
		while t < WALK_SECONDS:
			falls.append({"time": t, "footfall": 1 if feet == FOE else 0, "pos": feet})
			t += every
		out.append(_step("Footsteps", "%s (%.1f m/s, a footfall every %.2f s)" % [pace[0], speed, every], falls))

	out.append(_step("Ambience", "the shrine's bed fades in, plays and fades out",
		[{"time": 0.0, "ambience": &"ambience_shrine"}, {"time": 10.0, "ambience": &""}]))

	var m := "Music"
	var round_call := {"t": &"roundStart", "round": 4}
	out.append(_step(m, "the menu track (110 BPM), from silence", [{"time": 0.0, "music": &"menu"}], 8.0))
	out.append(_step(m, "a match starts: the menu track, then battle (140 BPM)",
		[{"time": 0.0, "music": &"menu"}, {"time": 4.0, "music": &"match"}], 10.0))
	out.append(_step(m, "the round call with a fighter on two wins: battle, then match point (160 BPM)", [
		{"time": 0.0, "music": &"match"},
		{"time": 3.5, "music_event": {"t": &"roundOver", "winner": 0, "wins": [2, 1], "perfect": false}},
		{"time": 4.0, "music_event": round_call},
		{"time": 4.0, "event": round_call},
	], 10.0))
	out.append(_step(m, "the results: match point, then the menu track", [
		{"time": 0.0, "music": &"match"},
		{"time": 0.0, "music_event": {"t": &"roundOver", "winner": 0, "wins": [2, 2], "perfect": false}},
		{"time": 0.0, "music_event": round_call},
		{"time": 4.0, "music": &"menu"},
	], 9.0))
	out.append(_step(m, "the music stops: the menu track fades out",
		[{"time": 0.0, "music": &"menu"}, {"time": 4.0, "music": &"stop"}], 5.0))

	var heavy_hit := {"t": &"hit", "attacker": 1, "target": 0, "attack": &"swing", "damage": 30.0, "posture": 30.0,
		"pos": at, "heavy": true, "sound": &"colossal", "backstab": false}
	var light_hit := heavy_hit.duplicate()
	light_hit["heavy"] = false
	light_hit["sound"] = &"blade"
	out.append(_step("Ducking", "Greatsword hits, then light hits, over the battle music and the ambience", [
		{"time": 0.0, "music": &"match"},
		{"time": 0.0, "ambience": &"ambience_shrine"},
		{"time": 2.5, "event": heavy_hit},
		{"time": 4.0, "event": heavy_hit},
		{"time": 5.5, "event": heavy_hit},
		{"time": 7.0, "event": light_hit},
		{"time": 7.8, "event": light_hit},
		{"time": 10.5, "music": &"stop"},
		{"time": 10.5, "ambience": &""},
	], 11.0))
	return out
