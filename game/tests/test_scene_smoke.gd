extends GutTest
## Every scene in the project loads and instantiates without an error (the
## spec's smoke test). Scenes are built but not added to the tree, so their
## _ready() doesn't run: this catches broken references, missing resources
## and scripts that fail while the scene is assembled. Shaders only compile
## in a real window; tools/shot_scenes/shader_check.tscn covers those.

## Folders whose scenes aren't the game's own (dot-folders such as .godot
## are hidden from DirAccess already).
const SKIP_DIRS: Array[String] = ["res://addons"]


## Every .tscn under `dir_path`, outside SKIP_DIRS. Imported models
## (.gltf, .glb, .fbx) are left to the content tests.
static func _scenes(dir_path: String, out: Array[String]) -> Array[String]:
	if SKIP_DIRS.has(dir_path):
		return out
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		_scenes(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".tscn"):
			out.append(dir_path.path_join(file))
	return out


func test_every_scene_loads_and_instantiates() -> void:
	var scenes: Array[String] = _scenes("res://", [])
	assert_gt(scenes.size(), 10, "found the project's scenes")
	for path: String in scenes:
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, "%s loads" % path)
		if packed == null:
			continue
		var node: Node = packed.instantiate()
		assert_not_null(node, "%s instantiates" % path)
		if node != null:
			node.free()
