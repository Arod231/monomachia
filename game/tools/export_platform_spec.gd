extends SceneTree
## Writes the numbers the Moonlit Shrine's modelled platform is built from
## (ShrinePlatform.model_spec(), milestone-1 task 50) to
## scripts/blender/shrine/platform.json, which
## scripts/blender/build_shrine_buildings.py reads. Run it after a change to
## the Shrine's layout or arena data, then rebuild the platform in Blender and
## export it (test_shrine_platform.gd fails until the file matches).
##
## Run: node scripts/godot.mjs script res://tools/export_platform_spec.gd

const OUT: String = "res://../scripts/blender/shrine/platform.json"


func _initialize() -> void:
	var layout := load("res://arenas/moonlit_shrine/moonlit_shrine_layout.tres") as ShrineLayout
	var def := ArenaScenes.def(ArenaScenes.MOONLIT_SHRINE)
	var path: String = ProjectSettings.globalize_path(OUT)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("export_platform_spec: can't write %s" % path)
		quit(1)
		return
	f.store_string(JSON.stringify(ShrinePlatform.model_spec(layout, def), "  ", false) + "\n")
	f.close()
	print("export_platform_spec: wrote %s" % path)
	quit(0)
