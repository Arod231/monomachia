extends SceneTree
## Loads every GDScript file in the project (except add-ons) and fails if any
## of them has a parse or type error. Run through `npm run typecheck`.

const SKIP_DIRS: Array[String] = ["res://addons", "res://.godot"]


func _initialize() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	var failed: Array[String] = []
	for path: String in files:
		var script: Resource = load(path)
		if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
			failed.append(path)
	if failed.is_empty():
		print("typecheck: %d scripts OK" % files.size())
		quit(0)
	else:
		for path: String in failed:
			printerr("typecheck: failed to load %s" % path)
		printerr("typecheck: %d of %d scripts failed" % [failed.size(), files.size()])
		quit(1)


func _collect(dir_path: String, out: Array[String]) -> void:
	for skip: String in SKIP_DIRS:
		if dir_path.begins_with(skip):
			return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
