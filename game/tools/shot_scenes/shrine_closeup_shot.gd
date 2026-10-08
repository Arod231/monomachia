extends Node
## Close-ups of the Moonlit Shrine's art (milestone-1 tasks 132 and 49), the
## arena alone (no match) under the chosen preset, from a camera the view
## picks out of the layout:
## - sky: up at the Milky Way, from past the trees, away from the shafts;
## - moon: at the blood moon;
## - lantern: the first stone lantern, from the courtyard;
## - torii: the first gate's torii, from the courtyard;
## - pillar: the first whole pillar and its neighbour;
## - far: the first far pagoda or temple hall, through a long lens;
## - paving: the floor's slabs, looking down at them.
## Shoot one with
##   npm run shots -- res://tools/shot_scenes/shrine_closeup.tscn shots/<name>.png 30 --view=<view> [--preset=<id>]

const SCENE: String = "res://arenas/moonlit_shrine/moonlit_shrine.tscn"

@export var view: StringName = &"sky"
@export var preset_id: StringName = &""
@export var settle_frames: int = 40

var arena: MoonlitShrine
var _ready_flag: bool = false


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--view="):
			view = StringName(a.trim_prefix("--view="))
		elif a.begins_with("--preset="):
			preset_id = StringName(a.trim_prefix("--preset="))
	var preset: GraphicsPreset = GraphicsPreset.load_id(preset_id) if preset_id != &"" else GameServices.graphics_preset()
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)
	GraphicsApplier.apply(preset, self, get_viewport())
	var cam := Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	_frame(cam)
	cam.make_current()
	arena.cull_below_deck(cam)
	_ready_flag = true


func _frame(cam: Camera3D) -> void:
	var layout: ShrineLayout = arena.layout
	match view:
		&"sky":
			var pole: Vector3 = MoonlitShrine.milky_way_pole(layout.moon_direction)
			var top: Vector3 = (Vector3.UP - pole * Vector3.UP.dot(pole)).normalized()
			# where the band meets the horizon, on the side away from the
			# moon shafts' light (whose glow in the mist would hide it)
			var low: Vector3 = pole.cross(Vector3.UP).normalized()
			if low.dot(layout.key_light_direction) > 0.0:
				low = -low
			var at: Vector3 = (top + low).normalized()
			var eye: Vector3 = Vector3(at.x, 0.0, at.z).normalized() * 48.0 + Vector3.UP * 2.0
			cam.fov = 85.0
			cam.look_at_from_position(eye, eye + at, Vector3.UP)
		&"moon":
			var eye := Vector3(0.0, 1.7, 0.0)
			cam.fov = 45.0
			cam.look_at_from_position(eye, eye + layout.moon_direction.normalized(), Vector3.UP)
		&"lantern":
			_look_at_piece(cam, arena.get_node("Platform/Props/Lantern0") as Node3D, 3.6, 0.5, 50.0)
		&"torii":
			_look_at_piece(cam, arena.get_node("Platform/Props/Torii0") as Node3D, 10.0, -1.3, 55.0)
		&"pillar":
			_look_at_piece(cam, arena.get_node("Platform/Props/Pillar0") as Node3D, 6.0, -1.0, 55.0)
		&"far":
			var far: Node3D = null
			for child: Node in arena.get_node("World/Cliffs").get_children():
				if child.name.begins_with("Pagoda") or child.name.begins_with("TempleHall"):
					far = child as Node3D
					break
			var c: Vector3 = _centre(far)
			var flat := Vector3(c.x, 0.0, c.z).normalized()
			cam.fov = 9.0
			cam.look_at_from_position(flat * 16.0 + Vector3.UP * 3.0, c, Vector3.UP)
		&"paving":
			cam.fov = 60.0
			cam.look_at_from_position(Vector3(2.0, 1.6, -4.0), Vector3(5.0, 0.0, -1.0), Vector3.UP)
		_:
			push_error("shrine_closeup: no view %s" % view)


## Frames piece from the courtyard side, back metres in from it, raised by
## lift above its centre.
func _look_at_piece(cam: Camera3D, piece: Node3D, back: float, lift: float, fov: float) -> void:
	var c: Vector3 = _centre(piece)
	var inward := -Vector3(c.x, 0.0, c.z).normalized()
	cam.fov = fov
	cam.look_at_from_position(c + inward * back + Vector3.UP * lift, c, Vector3.UP)


## The centre of the world bounds of node's meshes.
func _centre(node: Node3D) -> Vector3:
	var box := AABB()
	var first: bool = true
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center() if not first else node.global_position
