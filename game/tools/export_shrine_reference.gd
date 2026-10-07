extends SceneTree
## Writes the Moonlit Shrine's courtyard, props and ledge as a glTF file, as
## a reference to model arena art against in Blender (milestone-1 task 48:
## the wisteria's roots grip the ledge and the platform's sides but stop
## short of the floor). Picture data only: the backdrop, particles, lights
## and the arena's environment are left out, and nothing is committed from
## it.
##
## Run: node scripts/godot.mjs script res://tools/export_shrine_reference.gd -- <out.glb>

const SCENE: String = "res://arenas/moonlit_shrine/moonlit_shrine.tscn"
## What the reference keeps of the built Shrine.
const KEEP: Array[StringName] = [&"Platform", &"Underside", &"Spawn0", &"Spawn1", &"Gate0", &"Gate1"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("export_shrine_reference: give the output path")
		quit(1)
		return
	var shrine: Node3D = (load(SCENE) as PackedScene).instantiate() as Node3D
	# built out of the tree: it needs neither the game's services nor a frame
	shrine.call(&"_build")
	for child: Node in shrine.get_children():
		if not KEEP.has(child.name):
			shrine.remove_child(child)
			child.free()
	for name: StringName in [&"FloatingRocks", &"BelowDeck"]:
		var n: Node = shrine.find_child(name, true, false)
		if n != null:
			n.get_parent().remove_child(n)
			n.free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: Error = doc.append_from_scene(shrine, state)
	if err == OK:
		err = doc.write_to_filesystem(state, args[0])
	shrine.free()
	if err != OK:
		printerr("export_shrine_reference: could not write %s (%s)" % [args[0], error_string(err)])
		quit(1)
		return
	print("export_shrine_reference: wrote %s" % args[0])
	quit(0)
