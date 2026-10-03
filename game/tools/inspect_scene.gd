extends SceneTree
## Prints what an imported model holds: its node tree, skeleton bones, mesh
## surfaces with their materials and textures, and animation clips.
##
## Run: node scripts/godot.mjs script res://tools/inspect_scene.gd -- res://path/model.gltf [...]


func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		print("=== ", path)
		var packed: PackedScene = load(path)
		if packed == null:
			printerr("inspect_scene: cannot load %s" % path)
			continue
		var scene: Node = packed.instantiate()
		_print_node(scene, 0)
		for skel: Node in scene.find_children("*", "Skeleton3D", true, false):
			var sk: Skeleton3D = skel
			var names: PackedStringArray = []
			for i: int in sk.get_bone_count():
				names.append(sk.get_bone_name(i))
			print("  skeleton %s: %d bones, motion_scale %.3f: %s" % [sk.name, sk.get_bone_count(), sk.motion_scale, ", ".join(names)])
		for node: Node in scene.find_children("*", "AnimationPlayer", true, false):
			var ap: AnimationPlayer = node
			for lib_name: StringName in ap.get_animation_library_list():
				var lib: AnimationLibrary = ap.get_animation_library(lib_name)
				var clips: PackedStringArray = []
				for clip: StringName in lib.get_animation_list():
					var a: Animation = lib.get_animation(clip)
					clips.append("%s(%.2fs,%d tr,%s)" % [clip, a.length, a.get_track_count(), "loop" if a.loop_mode != Animation.LOOP_NONE else "once"])
				print("  library '%s': %d clips: %s" % [lib_name, clips.size(), ", ".join(clips)])
		scene.free()
	quit(0)


func _print_node(n: Node, depth: int) -> void:
	var extra: String = ""
	if n is Node3D:
		var t: Transform3D = (n as Node3D).transform
		if not t.is_equal_approx(Transform3D.IDENTITY):
			extra += " xf=%s" % t
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		extra += " skin=%s aabb=%s" % [mi.skin != null, mi.get_aabb()]
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			var desc: String = "none"
			if mat is BaseMaterial3D:
				var bm: BaseMaterial3D = mat
				desc = "%s albedo=%s col=%s normal=%s(%s) orm=%s rough=%s cull=%d" % [
					bm.resource_name, _tex(bm.albedo_texture), bm.albedo_color, _tex(bm.normal_texture), bm.normal_enabled,
					_tex(bm.orm_texture) if bm is ORMMaterial3D else "-", _tex(bm.roughness_texture), bm.cull_mode]
			elif mat != null:
				desc = mat.get_class()
			extra += "\n%s    surface %d (%d verts): %s" % ["  ".repeat(depth), s, mi.mesh.surface_get_array_len(s), desc]
	print("%s%s <%s>%s" % ["  ".repeat(depth), n.name, n.get_class(), extra])
	for c: Node in n.get_children():
		_print_node(c, depth + 1)


func _tex(t: Texture2D) -> String:
	if t == null:
		return "null"
	return "%s %dx%d" % [t.resource_path.get_file(), t.get_width(), t.get_height()]
