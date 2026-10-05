extends SceneTree
## Measures each clip's foot contacts (FootContacts) from the clip libraries
## on the Hunter (HumanM) and writes them into the clip manifest's
## "foot_contacts" (milestone-1 task 14). Needs the clip libraries (`node
## scripts/godot.mjs clips`); the numbers it writes are committed, the clips
## never are.
##
##   node scripts/godot.mjs script res://tools/measure_feet.gd [-- --check]
##
## --check writes nothing and exits 1 when a clip's measured contacts differ
## from the manifest's. Exits 2 without the libraries.

const EXIT_NO_LIBRARIES: int = 2


func _initialize() -> void:
	# the fighter's skeleton poses only once the main loop runs
	await process_frame
	quit(run(OS.get_cmdline_user_args().has("--check")))


func run(check: bool) -> int:
	if not ClipLibraries.available():
		printerr("measure_feet: no clip libraries; run `node scripts/godot.mjs clips` (needs the packs, see .assets-src-path)")
		return EXIT_NO_LIBRARIES
	var manifest: ClipManifest = ClipManifest.read()
	if not manifest.errors.is_empty():
		printerr("measure_feet: mistakes in the clip manifest:\n  " + "\n  ".join(manifest.errors))
		return 1
	var model: FighterModel = FootContacts.hunter(root)
	var measured: Dictionary = {}
	var differ: PackedStringArray = []
	for id: StringName in manifest.ids():
		var contacts: Dictionary = FootContacts.measure(model, id)
		measured[id] = contacts
		if not FootContacts.same(contacts, manifest.clips[id].foot_contacts):
			differ.append(String(id))
	model.queue_free()
	if check:
		if not differ.is_empty():
			printerr("measure_feet: the manifest's foot contacts differ from the clips' for %s" % ", ".join(differ))
			return 1
		print("measure_feet: every clip's foot contacts match")
		return 0
	var errors: Array[String] = []
	var text: String = FootContacts.write(FileAccess.get_file_as_string(ClipManifest.PATH), measured, errors)
	if not errors.is_empty():
		printerr("measure_feet:\n  " + "\n  ".join(errors))
		return 1
	var f: FileAccess = FileAccess.open(ClipManifest.PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("measure_feet: wrote %d clips' foot contacts (%d changed) into %s" % [measured.size(), differ.size(), ClipManifest.PATH])
	return 0
