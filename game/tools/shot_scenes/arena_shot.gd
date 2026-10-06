extends Node3D
## Screenshot rig for an arena: the arena as a match shows it, from each of
## the match's cameras and from two of its own. A MatchHost, stepped without
## the clock, plays a computer duel (the Rogue with the katana against the
## Hunter with the greatsword) held in the round's intro, so the real fighters
## stand on their spawns; MatchView.set_arena puts the arena in; the chosen
## graphics preset is applied to the renderer, the window and the whole rig.
## Each .tscn next to this script picks a view; render one with
##   node scripts/godot.mjs shots res://tools/shot_scenes/arena_<view>.tscn <out.png> 30 [--preset=<id>] [--arena=<id>] [--wall=<degrees>]
##
## The arena is its ArenaDef's own scene whenever that scene exists, even
## while ArenaScenes' radius guard keeps it out of matches, so an arena can be
## shot before the rules reach its radius. Otherwise it is whatever
## ArenaScenes draws for the id (the stand-in).
##
## Views:
## - gameplay: the match camera over side 0's shoulder (CameraRig FOLLOW);
## - watch: the match camera side-on (CameraRig WATCH);
## - menu: the match camera's orbit behind the menus, menu_time seconds in;
## - establishing: the whole arena from beyond its edge and below its floor,
##   which shows a floating arena's underside. Its numbers frame the
##   Moonlit Shrine's; the stand-in, with nothing under its floor, sits small
##   at the top of the frame;
## - top_down: an orthographic debug view with a legend: the rules' wall
##   (magenta), where fighters' centres stop (grey), the arena's walkable circle
##   when it differs from the rules' wall (orange) and its wall's inner face
##   (yellow) from the arena's ArenaDef, and the arena's Spawn and Gate
##   markers with their facing (cyan), plus a close-up of the wall at +X.
##
## At the wall: with wall_angle_deg set (or --wall=<degrees>), side 0 stands
## backed against the rules' wall at that angle (from +Z toward +X), facing
## side 1 wall_separation metres further in, so the gameplay and Watch views show
## where the camera goes when a fighter is cornered (arena_wall.tscn).
##
## Bench: with entries in bench, the rig times frames instead of taking one
## shot (arena_bench.tscn times Low, Medium, High and Ultra from the gameplay view):
##   node scripts/godot.mjs shots res://tools/shot_scenes/arena_bench.tscn <sheet.png>
## The window goes to bench_resolution with vsync off, and the match plays
## from the view's camera with its HUD, one rules step a frame. Each entry is
## timed bench_passes times, interleaved, so heat and clock changes hit every
## entry alike. For each, the match restarts at the start of the fight,
## bench_settle frames settle, then bench_frames frames are timed. The run
## prints one line per entry (fps and average frame time, the 95th
## percentile, the GPU's and the CPU's render times), and the shot it saves
## is a sheet of the entries side by side, each at the same moment of the
## fight (the camera's shake can differ a little: its random offsets don't
## restart with the match).
##
## An entry is a preset id, optionally followed by ":" and comma-separated
## overrides: <setting>=<value> sets any GraphicsPreset setting
## (outline_props=false, shadow_atlas_size=2048), and hide=<path> hides a
## node under the match view (hide=Arena/World, hide=Fighter1), to find what
## costs what. An entry that can't run is reported, so the run fails, and
## left out. On the command line, --bench= takes the entries
## separated by ";" (quoted: "--bench=high;high:hide=Arena/Particles"), and
## --bench-passes=, --bench-frames= and --bench-res=1600x900 override the
## exports. --versus (or versus) times Versus split screen (task 23.6): the
## match is a Versus of two standing players, each half drawn by its own
## camera, and the GPU and CPU times add up the root viewport's and both
## halves'.

enum View { GAMEPLAY, WATCH, MENU, ESTABLISHING, TOP_DOWN }

## The match camera's mode for each of its views.
const CAMERA_MODES: Dictionary[View, CameraRig.Mode] = {
	View.GAMEPLAY: CameraRig.Mode.FOLLOW,
	View.WATCH: CameraRig.Mode.WATCH,
	View.MENU: CameraRig.Mode.MENU,
}
const SEED: int = 7

const RULES_WALL_COLOR := Color(1.0, 0.2, 0.85)
const CENTRE_LIMIT_COLOR := Color(0.65, 0.65, 0.68)
const ARENA_WALKABLE_COLOR := Color(1.0, 0.55, 0.1)
const WALL_FACE_COLOR := Color(1.0, 0.85, 0.2)
const MARKER_COLOR := Color(0.3, 0.9, 1.0)
const TITLE_COLOR := Color(0.92, 0.92, 0.95)
## The overlay's marks: a ring on each spawn (fighter-sized) and on each gate,
## lifted clear of the floor and the gate's props, and an arrow for facing.
const SPAWN_MARK_RADIUS: float = 0.42
const SPAWN_MARK_LIFT: float = 2.0
const GATE_MARK_RADIUS: float = 0.6
const GATE_MARK_LIFT: float = 8.0

@export var arena_id: StringName = ArenaScenes.MOONLIT_SHRINE
@export var view: View = View.GAMEPLAY
## A preset id (low, medium, high or ultra); empty shoots the saved preset.
@export var preset_id: StringName = &""
## Frames to let the renderer settle before the capture.
@export var settle_frames: int = 20

@export_group("Menu")
## Seconds into the menu orbit. It starts straight behind side 1, where one
## fighter hides the other; 10 s in it shows them three-quarter on.
@export var menu_time: float = 10.0

@export_group("Establishing")
## Angle around the arena (degrees, from +Z toward +X), distance from the
## centre and height of the camera, and the height it looks at (m).
@export var establishing_angle_deg: float = 228.0
@export var establishing_distance: float = 58.0
@export var establishing_height: float = -5.0
@export var establishing_look_height: float = -13.0
@export var establishing_fov: float = 60.0

@export_group("Top-down")
## How many metres the top-down view spans, top to bottom (an orthographic
## camera's size is its height).
@export var top_down_size: float = 46.0
## How far right of the screen's centre the arena sits (m), clear of the
## legend and the close-up on the left.
@export var top_down_shift: float = 12.0
## The overlay rings' width (m): two pixels or so at 46 m tall.
@export var ring_width: float = 0.1

@export_group("Wall")
## Back side 0 against the wall at this angle (degrees, from +Z toward +X);
## NAN leaves both fighters on their spawns.
@export var wall_angle_deg: float = NAN
## How far apart the fighters stand, side 1 further in (m).
@export var wall_separation: float = 3.0

@export_group("Bench")
## The entries to time, in order; empty takes one shot instead.
@export var bench: PackedStringArray = PackedStringArray()
## How many times each entry is timed, interleaved with the others.
@export var bench_passes: int = 3
## Frames after each entry starts before the timing does.
@export var bench_settle: int = 45
## Frames timed per entry and pass.
@export var bench_frames: int = 300
## The window's size while timing (the 3D renders at the window's pixels).
@export var bench_resolution: Vector2i = Vector2i(1920, 1080)
## Bench Versus split screen: two players, two views (--versus).
@export var versus: bool = false

## Each entry's size in the bench's sheet, as a fraction of the screen.
const SHEET_SCALE: float = 0.5

var host: MatchHost
## The preset the shot is taken at (during a bench, the entry's).
var preset: GraphicsPreset
## The rig's own camera, for the establishing and top-down views; null for
## the match camera's views.
var shot_camera: Camera3D
## Entry -> one Dictionary per pass: frame_ms (the average frame time),
## p95_ms (the 95th percentile), gpu_ms and cpu_ms (the average render times).
var bench_results: Dictionary[String, Array] = {}
var _ready_flag: bool = false
## The entries in the order they are timed, every pass.
var _queue: PackedStringArray = PackedStringArray()
var _entry_index: int = -1
var _frame_in_entry: int = 0
var _last_usec: int = 0
var _frame_ms: PackedFloat64Array = PackedFloat64Array()
var _gpu_ms: PackedFloat64Array = PackedFloat64Array()
var _cpu_ms: PackedFloat64Array = PackedFloat64Array()
var _bench_done: bool = false
## What the current entry hid, shown again when the next one starts.
var _hidden: Array[Node] = []
## Entry -> the screen at the end of its first pass, for the sheet.
var _panels: Dictionary[String, Image] = {}
var _label: Label
var _saved_vsync: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
var _saved_window_size: Vector2i = Vector2i.ZERO


func shot_frames() -> int:
	if _queue.is_empty():
		return settle_frames
	return _queue.size() * (bench_settle + bench_frames)


func shot_ready() -> bool:
	return _ready_flag and (_queue.is_empty() or _bench_done)


## The bench's sheet once it is done; null for a plain shot, so shot.gd
## saves the screen.
func shot_image() -> Image:
	if not _bench_done:
		return null
	var panels: Array[Image] = []
	for key: String in bench:
		if _panels.has(key):
			panels.append(_panels[key])
	return sheet(panels, SHEET_SCALE)


func _ready() -> void:
	apply_args(OS.get_cmdline_user_args())
	preset = _chosen_preset()
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	if versus:
		host.input = InputDevices.new(FakeDeviceState.new())
		host.profiles = ControlProfiles.new()
	add_child(host)
	var match_view: MatchView = host.get_node("View")
	match_view.set_arena(_make_arena(), arena_id)
	host.start(_versus_config() if versus else MatchConfig.make(
		MatchConfig.WATCH,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"),
		SEED,
		arena_id,
	))
	# Twice: the view shows the position before the last step.
	host.step(2)
	if not is_nan(wall_angle_deg):
		_back_to_wall()
	var hud: CanvasLayer = host.get_node("Hud")
	hud.visible = false
	hud.set_process(false)
	_aim_match_camera(match_view)
	match_view.set_process(false)
	if not CAMERA_MODES.has(view):
		_add_shot_camera(match_view.camera.far)
	GraphicsApplier.apply(preset, self, get_viewport())
	GraphicsApplier.apply_to_group(preset, get_tree())
	if view == View.TOP_DOWN:
		_setup_top_down(match_view.arena)
	if not bench.is_empty():
		_start_bench()
	_ready_flag = true


func _exit_tree() -> void:
	if _queue.is_empty():
		return
	DisplayServer.window_set_vsync_mode(_saved_vsync)
	get_window().size = _saved_window_size
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)


## The command line's --preset=, --arena=, --wall=, --bench=,
## --bench-passes=, --bench-frames= and --bench-res= override the exports.
## An unknown arena, a wall angle that isn't a number, a count below 1 or a
## bad resolution is an error, so the shot run fails.
func apply_args(args: PackedStringArray) -> void:
	for a: String in args:
		if a.begins_with("--preset="):
			preset_id = StringName(a.trim_prefix("--preset="))
		elif a.begins_with("--arena="):
			arena_id = StringName(a.trim_prefix("--arena="))
		elif a.begins_with("--wall="):
			var deg: String = a.trim_prefix("--wall=")
			if not deg.is_valid_float():
				push_error("arena_shot.gd: --wall= takes an angle in degrees, not '%s'" % a)
			else:
				wall_angle_deg = float(deg)
		elif a == "--versus":
			versus = true
		elif a.begins_with("--bench="):
			bench = a.trim_prefix("--bench=").split(";", false)
		elif a.begins_with("--bench-passes="):
			bench_passes = _count_arg(a, bench_passes)
		elif a.begins_with("--bench-frames="):
			bench_frames = _count_arg(a, bench_frames)
		elif a.begins_with("--bench-res="):
			var size: PackedStringArray = a.trim_prefix("--bench-res=").split("x")
			if size.size() != 2 or int(size[0]) <= 0 or int(size[1]) <= 0:
				push_error("arena_shot.gd: --bench-res= takes <width>x<height>, not '%s'" % a)
			else:
				bench_resolution = Vector2i(int(size[0]), int(size[1]))
	if not ArenaScenes.has(arena_id):
		push_error("arena_shot.gd: no arena '%s'" % arena_id)


## Backs side 0 against the rules' wall at wall_angle_deg, facing side 1
## wall_separation metres further in, and steps twice so the view shows them
## there.
func _back_to_wall() -> void:
	var a: float = deg_to_rad(wall_angle_deg)
	var r: float = SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS
	var f0: Fighter = host.fighter(0)
	var f1: Fighter = host.fighter(1)
	f0.pos = V3.make(sin(a) * r, 0.0, cos(a) * r)
	f1.pos = V3.make(sin(a) * (r - wall_separation), 0.0, cos(a) * (r - wall_separation))
	for f: Fighter in [f0, f1]:
		f.vel = V3.make()
		f.yaw = SimMath.yaw_to(f.pos, f.opp.pos)
	host.step(2)


## The whole number after an arg's "=", or fallback (reported) when it isn't
## 1 or more.
static func _count_arg(arg: String, fallback: int) -> int:
	var text: String = arg.get_slice("=", 1)
	if not text.is_valid_int() or int(text) < 1:
		push_error("arena_shot.gd: %s takes a whole number of 1 or more" % arg)
		return fallback
	return int(text)


## The preset named by preset_id, or the saved one when it is empty. An
## unknown id is an error, so the shot run fails.
func _chosen_preset() -> GraphicsPreset:
	if preset_id == &"":
		return GameServices.graphics_preset()
	var chosen: GraphicsPreset = GraphicsPreset.load_id(preset_id)
	if chosen == null:
		push_error("arena_shot.gd: no preset '%s' (%s)" % [preset_id, ", ".join(PackedStringArray(GraphicsPreset.IDS))])
		return GameServices.graphics_preset()
	return chosen


## The arena's own scene when its data names one that exists (past the radius
## guard), else what ArenaScenes draws for the id.
func _make_arena() -> Node3D:
	var def: ArenaDef = ArenaScenes.def(arena_id)
	if def != null and ResourceLoader.exists(def.scene_path):
		return (load(def.scene_path) as PackedScene).instantiate() as Node3D
	return ArenaScenes.instantiate(arena_id)


## Puts the match camera in the view's mode (when the view is one of its
## own) and snaps it there.
func _aim_match_camera(match_view: MatchView) -> void:
	if versus:
		# each half's camera follows its player
		match_view.snap_camera()
		return
	var camera: CameraRig = match_view.camera
	camera.mode = CAMERA_MODES.get(view, CameraRig.Mode.FOLLOW)
	if view == View.MENU:
		# Nothing has rendered the view yet, so the orbit's clock is at 0:
		# run it to menu_time, and the snap lands there.
		camera.update_rig(menu_time, Vector3.ZERO, Vector3.ZERO)
	match_view.snap_camera()


## The rig's own camera, for the establishing and top-down views.
func _add_shot_camera(far_plane: float) -> void:
	shot_camera = Camera3D.new()
	shot_camera.name = "ShotCamera"
	shot_camera.near = 0.1
	shot_camera.far = far_plane
	add_child(shot_camera)
	if view == View.ESTABLISHING:
		var a: float = deg_to_rad(establishing_angle_deg)
		shot_camera.fov = establishing_fov
		shot_camera.position = Vector3(sin(a) * establishing_distance, establishing_height, cos(a) * establishing_distance)
		shot_camera.look_at(Vector3(0.0, establishing_look_height, 0.0))
	else:
		shot_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		shot_camera.size = top_down_size
		# Looking straight down with -Z up the screen, so +X is right.
		shot_camera.position = Vector3(-top_down_shift, 90.0, 0.0)
		shot_camera.look_at(Vector3(-top_down_shift, 0.0, 0.0), Vector3.FORWARD)
	shot_camera.make_current()


# ------------------------------------------------------------------ top-down

## No fog, distance mist or vignette, the overlay, the legend and the
## close-up.
func _setup_top_down(arena: Node3D) -> void:
	for node: Node in arena.find_children("*", "WorldEnvironment", true, false):
		(node as WorldEnvironment).environment.fog_enabled = false
	for node: Node in arena.find_children("*", "InkWashPass", true, false):
		var ink: InkWashPass = node
		ink.set_param(&"vignette_strength", 0.0)
		ink.set_param(&"fade_max", 0.0)
	var def: ArenaDef = arena.get("def") as ArenaDef
	add_child(_overlay(arena, def))
	var layer := CanvasLayer.new()
	layer.name = "Legend"
	add_child(layer)
	layer.add_child(_legend(arena, def))
	_add_close_up(layer, def.wall_inner_radius() if def != null else SimConst.ARENA_RADIUS)


func _overlay(arena: Node3D, def: ArenaDef) -> Node3D:
	var root := Node3D.new()
	root.name = "DebugOverlay"
	var r: float = SimConst.ARENA_RADIUS
	root.add_child(_ring("RulesWall", r, 1.5, RULES_WALL_COLOR))
	root.add_child(_ring("CentreLimit", r - SimConst.FIGHTER_RADIUS, 1.5, CENTRE_LIMIT_COLOR))
	if _walkable_differs(def):
		root.add_child(_ring("ArenaWalkable", def.walkable_radius, 1.52, ARENA_WALKABLE_COLOR))
	if def != null:
		root.add_child(_ring("WallFace", def.wall_inner_radius() + ring_width, 1.55, WALL_FACE_COLOR))
	var marks := MeshKit.new()
	for key: String in ["Spawn0", "Spawn1", "Gate0", "Gate1"]:
		var marker: Node3D = arena.get_node_or_null(key)
		if marker == null:
			continue
		var at: Transform3D = marker.global_transform
		var gate: bool = key.begins_with("Gate")
		var lift := Vector3(0.0, GATE_MARK_LIFT if gate else SPAWN_MARK_LIFT, 0.0)
		var size: float = GATE_MARK_RADIUS if gate else SPAWN_MARK_RADIUS
		marks.disc(Transform3D(Basis(), at.origin + lift), size, 24, 1, size - 0.15)
		var facing: Vector3 = -at.basis.z
		marks.box(Transform3D(at.basis, at.origin + lift + facing * (size + 0.4)), Vector3(0.12, 0.05, 0.8))
	var mi: MeshInstance3D = MeshKit.instance(marks.commit(), _flat(MARKER_COLOR), false)
	mi.name = "Markers"
	root.add_child(mi)
	return root


## A flat ring ring_width wide, its outer edge at radius.
func _ring(ring_name: String, radius: float, height: float, color: Color) -> MeshInstance3D:
	var kit := MeshKit.new()
	kit.disc(Transform3D(Basis(), Vector3(0.0, height, 0.0)), radius, 256, 1, radius - ring_width)
	var mi: MeshInstance3D = MeshKit.instance(kit.commit(), _flat(color), false)
	mi.name = ring_name
	return mi


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	return m


func _legend(arena: Node3D, def: ArenaDef) -> Control:
	var r: float = SimConst.ARENA_RADIUS
	var rows: Array[Array] = [
		[TITLE_COLOR, "%s, top-down (%.0f m tall), preset %s" % [_arena_title(def), top_down_size, preset.id]],
		[RULES_WALL_COLOR, "the rules' wall: ARENA_RADIUS %.2f m" % r],
		[CENTRE_LIMIT_COLOR, "fighters' centres stop at %.2f m (minus the %.2f m body)" % [r - SimConst.FIGHTER_RADIUS, SimConst.FIGHTER_RADIUS]],
	]
	if _walkable_differs(def):
		rows.append([ARENA_WALKABLE_COLOR, "the arena's walkable radius %.2f m (matches use the stand-in until the rules match it)" % def.walkable_radius])
	if def == null:
		rows.append([WALL_FACE_COLOR, "no arena data: the stand-in's wall stands on the rules' wall"])
	else:
		rows.append([WALL_FACE_COLOR, "wall inner face %.3f m (wall %.2f m, %.2f m thick)" % [def.wall_inner_radius(), def.wall_radius, def.wall_thickness]])
	var spawn: Node3D = arena.get_node_or_null("Spawn1")
	var gate: Node3D = arena.get_node_or_null("Gate1")
	if spawn != null and gate != null:
		rows.append([MARKER_COLOR, "markers: spawns at z = ±%.2f m, gates at ±%.2f m (arrows: facing)" % [absf(spawn.position.z), absf(gate.position.z)]])
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	var list := VBoxContainer.new()
	panel.add_child(list)
	for row: Array in rows:
		var label := Label.new()
		label.text = row[1]
		label.add_theme_color_override(&"font_color", row[0])
		label.add_theme_font_size_override(&"font_size", 20)
		list.add_child(label)
	return panel


## Whether the arena's data puts its walkable circle somewhere other than the
## rules' wall (which keeps it out of matches).
static func _walkable_differs(def: ArenaDef) -> bool:
	return def != null and not is_equal_approx(def.walkable_radius, SimConst.ARENA_RADIUS)


## The arena's name, or the stand-in's (and the arena it stands in for).
func _arena_title(def: ArenaDef) -> String:
	if def != null:
		return def.display_name
	if arena_id == ArenaScenes.STANDIN:
		return "The stand-in arena"
	return "The stand-in arena (in place of %s)" % arena_id


## A close-up of the wall at +X (its inner face at wall_x), 2.4 m tall, in
## the bottom-left corner.
func _add_close_up(layer: CanvasLayer, wall_x: float) -> void:
	var at_x: float = wall_x + 0.2
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.size = Vector2(480, 360)
	frame.position = Vector2(24, get_viewport().get_visible_rect().size.y - 360 - 24)
	layer.add_child(frame)
	var sub := SubViewport.new()
	sub.size = Vector2i(480, 360)
	frame.add_child(sub)
	var close := Camera3D.new()
	close.projection = Camera3D.PROJECTION_ORTHOGONAL
	close.size = 2.4
	close.far = 200.0
	sub.add_child(close)
	close.look_at_from_position(Vector3(at_x, 60.0, 0.0), Vector3(at_x, 0.0, 0.0), Vector3.FORWARD)
	close.make_current()
	var caption := Label.new()
	caption.text = "close-up of the wall at +X (2.4 m tall)"
	caption.add_theme_font_size_override(&"font_size", 18)
	caption.position = frame.position + Vector2(8, 4)
	layer.add_child(caption)


# ------------------------------------------------------------------ bench

## An entry's preset (a copy, with its overrides set), the nodes it hides
## (paths under the match view), its label and what is wrong with it ("" when
## nothing is).
static func bench_entry(entry: String) -> Dictionary:
	var out: Dictionary = {"preset": null, "hide": [] as Array[NodePath], "label": entry, "error": ""}
	var parts: PackedStringArray = entry.split(":", true, 1)
	var base: GraphicsPreset = GraphicsPreset.load_id(StringName(parts[0]))
	if base == null:
		out["error"] = "no preset '%s' (%s)" % [parts[0], ", ".join(PackedStringArray(GraphicsPreset.IDS))]
		return out
	var p: GraphicsPreset = base.duplicate() as GraphicsPreset
	var hide: Array[NodePath] = []
	var overrides: PackedStringArray = parts[1].split(",", false) if parts.size() > 1 else PackedStringArray()
	for o: String in overrides:
		var kv: PackedStringArray = o.split("=", true, 1)
		if kv.size() < 2:
			out["error"] = "'%s' is neither <setting>=<value> nor hide=<path>" % o
			return out
		if kv[0] == "hide":
			hide.append(NodePath(kv[1]))
			continue
		var problem: String = _set_preset_value(p, kv[0], kv[1])
		if problem != "":
			out["error"] = problem
			return out
	out["preset"] = p
	out["hide"] = hide
	out["label"] = p.display_name if overrides.is_empty() else "%s: %s" % [p.display_name, ", ".join(overrides)]
	return out


## Sets one of the preset's settings from text (true, 2048, 0.5); returns what
## is wrong, or "".
static func _set_preset_value(p: GraphicsPreset, key: String, text: String) -> String:
	var known: bool = false
	for prop: Dictionary in p.get_property_list():
		if prop["name"] == key and int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			known = true
	if not known or key == "id" or key == "display_name":
		return "no preset setting '%s'" % key
	var current: Variant = p.get(key)
	var value: Variant = str_to_var(text)
	if typeof(value) == TYPE_INT and typeof(current) == TYPE_FLOAT:
		value = float(value)
	if typeof(value) != typeof(current):
		return "%s=%s: %s takes a %s" % [key, text, key, type_string(typeof(current))]
	p.set(key, value)
	return ""


## The entries in the order they are timed: every entry once a pass.
func bench_queue() -> PackedStringArray:
	var queue := PackedStringArray()
	for r: int in bench_passes:
		queue.append_array(bench)
	return queue


static func average(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / maxf(values.size(), 1)


## The nearest-rank 95th percentile: 95% of the values are at most this.
static func percentile_95(values: PackedFloat64Array) -> float:
	return FrameTimes.percentile(values, 95.0)


## The entries' shots side by side, in order, each scaled by scale; null
## without shots.
static func sheet(panels: Array[Image], scale: float) -> Image:
	if panels.is_empty():
		return null
	var w: int = roundi(panels[0].get_width() * scale)
	var h: int = roundi(panels[0].get_height() * scale)
	var out: Image = Image.create(w * panels.size(), h, false, Image.FORMAT_RGBA8)
	for i: int in panels.size():
		var panel: Image = panels[i].duplicate() as Image
		panel.convert(Image.FORMAT_RGBA8)
		panel.resize(w, h, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(panel, Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i(i * w, 0))
	return out


## Drops the entries that can't run and the repeats (reported, so the run
## fails), then sets the window and the match up for timing and starts the
## first entry.
func _start_bench() -> void:
	var good := PackedStringArray()
	for e: String in bench:
		var problem: String = "it is listed twice" if good.has(e) else _bench_problem(e)
		if problem != "":
			push_error("arena_shot.gd: bench entry '%s': %s" % [e, problem])
		else:
			good.append(e)
	bench = good
	_queue = bench_queue()
	if _queue.is_empty():
		return
	_saved_vsync = DisplayServer.window_get_vsync_mode()
	_saved_window_size = get_window().size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = bench_resolution
	for rid: RID in _measured():
		RenderingServer.viewport_set_measure_render_time(rid, true)
	var hud: CanvasLayer = host.get_node("Hud")
	hud.visible = true
	hud.set_process(true)
	(host.get_node("View") as MatchView).set_process(true)
	_add_bench_label()
	_next_entry()


## What is wrong with an entry, its hide paths included, or "".
func _bench_problem(entry: String) -> String:
	var parsed: Dictionary = bench_entry(entry)
	if parsed["error"] != "":
		return parsed["error"]
	var match_view: MatchView = host.get_node("View")
	for path: NodePath in parsed["hide"]:
		var node: Node = match_view.get_node_or_null(path)
		if node == null or not "visible" in node:
			return "no node '%s' under the match view to hide" % path
	return ""


## The entry's name in the bottom-left corner, so each panel of the sheet
## says what it shows.
func _add_bench_label() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Bench"
	add_child(layer)
	_label = Label.new()
	_label.name = "Entry"
	_label.add_theme_font_size_override(&"font_size", 30)
	_label.add_theme_constant_override(&"outline_size", 8)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	layer.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Starts timing an entry: the match restarts at the start of the fight, so
## every entry times the same frames, then the entry's preset is applied and
## what it names is hidden.
func start_bench_entry(entry: String) -> void:
	var problem: String = _bench_problem(entry)
	if problem != "":
		push_error("arena_shot.gd: bench entry '%s': %s" % [entry, problem])
		return
	var parsed: Dictionary = bench_entry(entry)
	for node: Node in _hidden:
		if is_instance_valid(node):
			node.set("visible", true)
	_hidden.clear()
	host.start(host.config)
	host.step(Match.INTRO_FRAMES)
	var match_view: MatchView = host.get_node("View")
	_aim_match_camera(match_view)
	if shot_camera != null:
		shot_camera.make_current()
	preset = parsed["preset"]
	GraphicsApplier.apply(preset, self, get_viewport())
	GraphicsApplier.apply_to_group(preset, get_tree())
	for path: NodePath in parsed["hide"]:
		var node: Node = match_view.get_node(path)
		node.set("visible", false)
		_hidden.append(node)
	if _label != null:
		_label.text = parsed["label"]


func _next_entry() -> void:
	_entry_index += 1
	_frame_in_entry = 0
	_last_usec = 0
	_frame_ms.clear()
	_gpu_ms.clear()
	_cpu_ms.clear()
	if _entry_index >= _queue.size():
		_bench_done = true
		for line: String in bench_report():
			print(line)
		return
	start_bench_entry(_queue[_entry_index])


## Times the frame that just ended (from the last call to this one), then
## steps the match once.
func _process(_delta: float) -> void:
	if _queue.is_empty() or _bench_done:
		return
	var now: int = Time.get_ticks_usec()
	_frame_in_entry += 1
	if _frame_in_entry > bench_settle and _last_usec != 0:
		var gpu: float = 0.0
		var cpu: float = RenderingServer.get_frame_setup_time_cpu()
		for rid: RID in _measured():
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		_frame_ms.append((now - _last_usec) / 1000.0)
		_gpu_ms.append(gpu)
		_cpu_ms.append(cpu)
	_last_usec = now
	if _frame_ms.size() >= bench_frames:
		_end_entry()
		_next_entry()
		return
	host.step(1)


## Keeps the pass's numbers, and in the first pass the screen for the sheet
## (headless runs draw nothing, so they keep none).
func _end_entry() -> void:
	var key: String = _queue[_entry_index]
	if not bench_results.has(key):
		bench_results[key] = []
		if DisplayServer.get_name() != "headless":
			_panels[key] = get_viewport().get_texture().get_image()
	bench_results[key].append({
		"frame_ms": average(_frame_ms),
		"p95_ms": percentile_95(_frame_ms),
		"gpu_ms": average(_gpu_ms),
		"cpu_ms": average(_cpu_ms),
	})


## A header, then one line per entry, averaged over the passes (each pass's
## frame time listed too, to show drift).
func bench_report() -> PackedStringArray:
	# The window's pixels: the viewport texture's own size is scaled by the
	# canvas_items stretch.
	var size: Vector2i = get_window().size
	var lines := PackedStringArray()
	lines.append("bench: %s at %dx%d, %d passes of %d frames (after %d to settle), %s" % [
		arena_id, size.x, size.y, bench_passes, bench_frames, bench_settle, RenderingServer.get_video_adapter_name()])
	var width: int = 0
	for key: String in bench:
		width = maxi(width, key.length())
	for key: String in bench:
		var frame := PackedFloat64Array()
		var p95 := PackedFloat64Array()
		var gpu := PackedFloat64Array()
		var cpu := PackedFloat64Array()
		for r: Dictionary in bench_results.get(key, []):
			frame.append(r["frame_ms"])
			p95.append(r["p95_ms"])
			gpu.append(r["gpu_ms"])
			cpu.append(r["cpu_ms"])
		var passes := PackedStringArray()
		for pass_ms: float in frame:
			passes.append("%.2f" % pass_ms)
		var ms: float = average(frame)
		lines.append("bench: %s %6.1f fps  frame %6.2f ms (passes %s)  p95 %6.2f ms  gpu %6.2f ms  render cpu %5.2f ms" % [
			key.rpad(width), 1000.0 / ms if ms > 0.0 else 0.0, ms, " / ".join(passes), average(p95), average(gpu), average(cpu)])
	return lines


## The viewports the bench times: the root, and in Versus both halves.
func _measured() -> Array[RID]:
	var rids: Array[RID] = [get_viewport().get_viewport_rid()]
	var split: SplitView = (host.get_node("View") as MatchView).split
	if split != null:
		for vp: SubViewport in split.viewports:
			rids.append(vp.get_viewport_rid())
	return rids


## The --versus bench's match: the Rogue with the Katana and the Hunter with
## the Greatsword, two players on the keyboard and a controller.
func _versus_config() -> MatchConfig:
	return MatchConfig.make(
		MatchConfig.VERSUS,
		MatchSide.human(&"rogue", &"katana", 0, InputDevices.KBM),
		MatchSide.human(&"hunter", &"greatsword", 1, InputDevices.PAD0),
		SEED,
		arena_id,
	)
