extends SceneTree
## Writes the numbers the Moonlit Shrine's modelled landscape is sculpted from
## (ShrineBackdrop.landscape_spec(), milestone-1 task 51) to
## scripts/blender/shrine/landscape.json, which
## scripts/blender/build_shrine_landscape.py reads. Run it after a change to
## the Shrine's layout, then rebuild the landscape in Blender and export it
## (test_shrine_landscape.gd fails until the file matches).
##
## Run: node scripts/godot.mjs script res://tools/export_landscape_spec.gd

const OUT: String = "res://../scripts/blender/shrine/landscape.json"


func _initialize() -> void:
	var layout := load("res://arenas/moonlit_shrine/moonlit_shrine_layout.tres") as ShrineLayout
	var path: String = ProjectSettings.globalize_path(OUT)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("export_landscape_spec: can't write %s" % path)
		quit(1)
		return
	f.store_string(JSON.stringify(ShrineBackdrop.landscape_spec(layout), "", false) + "\n")
	f.close()
	print("export_landscape_spec: wrote %s" % path)
	quit(0)
