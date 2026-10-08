extends Node
## The Shrine's fallen petals (milestone-1 task 137): a computer duel of two
## Hunters with the Katana on the Moonlit Shrine, playing live on the clock
## from the gameplay camera (or --watch from the Watch camera), the floor's
## cover first grown for --cover= seconds of falling petals (150 by default:
## the drifts of a third round), so a clip shows the petals falling, lying in
## drifts and scattered by the fighters. --doom shows match point's blood
## red; --top looks straight down on the floor (the drifts at the parapet);
## --preset= a graphics preset. Record it with
##   npm run clip -- petals --seconds 12
## or shoot a still with
##   npm run shots -- res://tools/shot_scenes/petals.tscn shots/petals.png 30

const SEED: int = 11

@export var cover_seconds: float = 150.0
@export var watch: bool = false
@export var doom: bool = false
@export var top: bool = false
@export var preset_id: StringName = &""
## Rules steps into the fight before the shot, past the round's intro.
@export var fight_steps: int = 420
@export var settle_frames: int = 30

var host: MatchHost
var _ready_flag: bool = false


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cover="):
			cover_seconds = float(a.trim_prefix("--cover="))
		elif a == "--watch":
			watch = true
		elif a == "--doom":
			doom = true
		elif a == "--top":
			top = true
		elif a.begins_with("--preset="):
			preset_id = StringName(a.trim_prefix("--preset="))
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	add_child(host)
	host.start(MatchConfig.make(
		MatchConfig.WATCH if watch else MatchConfig.DUEL,
		MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"),
		SEED,
		ArenaScenes.MOONLIT_SHRINE,
	))
	var view: MatchView = host.get_node("View")
	var hud: CanvasLayer = host.get_node("Hud")
	hud.visible = false
	var preset: GraphicsPreset = GraphicsPreset.load_id(preset_id) if preset_id != &"" else GameServices.graphics_preset()
	GraphicsApplier.apply(preset, self, get_viewport())
	var arena := view.arena as MoonlitShrine
	var fallen := arena.get_node("FallenPetals") as ShrineFallenPetals
	for i: int in roundi(cover_seconds * 30.0):
		fallen.advance(1.0 / 30.0)
	host.step(fight_steps)
	view.snap_camera()
	if doom:
		arena.set_match_point(true)
	if top:
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = arena.def.floor_radius * 2.2
		cam.far = 8.0
		add_child(cam)
		cam.look_at_from_position(Vector3(0.0, 5.0, 0.0), Vector3.ZERO, Vector3.FORWARD)
		cam.make_current()
		view.set_process(false)
	host.auto_run = true
	_ready_flag = true
