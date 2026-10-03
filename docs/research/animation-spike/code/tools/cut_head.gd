extends SceneTree
# Rebuilds the female body mesh keeping only triangles whose vertices are weighted mostly
# to the Head/Neck bones, so the outfit parts don't clip with the naked body underneath.
# Usage: --script res://tools/cut_head.gd -- [threshold]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var threshold := 0.5 if args.is_empty() else float(args[0])
	var scene: Node = (load("res://assets/body/Superhero_Female_FullBody.gltf") as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_child("Superhero_Female", true, false)
	var skin: Skin = mi.skin
	var src: ArrayMesh = mi.mesh
	var keep_bones := {}
	for i in skin.get_bind_count():
		var bn := String(skin.get_bind_name(i))
		if bn in ["Head", "Neck"]:
			keep_bones[i] = true
	print("binds=", skin.get_bind_count(), " head/neck bind ids=", keep_bones.keys(), " surfaces=", src.get_surface_count())
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		for ai in Mesh.ARRAY_MAX:
			if arr[ai] != null: print("  array ", ai, " type ", type_string(typeof(arr[ai])), " size ", arr[ai].size())
		print("  format ", src.surface_get_format(s))
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nv := verts.size()
		var per := bones.size() / nv
		var headw := PackedFloat32Array()
		headw.resize(nv)
		for v in nv:
			var w := 0.0
			for k in per:
				if keep_bones.has(bones[v * per + k]):
					w += weights[v * per + k]
			headw[v] = w
		# keep triangles whose weakest vertex is still mostly head/neck
		var remap := PackedInt32Array()
		remap.resize(nv)
		remap.fill(-1)
		var new_idx := PackedInt32Array()
		var kept_v := PackedInt32Array()
		for t in idx.size() / 3:
			var a := idx[t * 3]; var b := idx[t * 3 + 1]; var c := idx[t * 3 + 2]
			if min(headw[a], headw[b], headw[c]) >= threshold:
				for v in [a, b, c]:
					if remap[v] < 0:
						remap[v] = kept_v.size()
						kept_v.append(v)
					new_idx.append(remap[v])
		# compact every per-vertex array
		var na := []
		na.resize(Mesh.ARRAY_MAX)
		for ai in Mesh.ARRAY_MAX:
			var a2 = arr[ai]
			if a2 == null or ai == Mesh.ARRAY_INDEX or ai == Mesh.ARRAY_CUSTOM0 or ai == Mesh.ARRAY_CUSTOM1 or ai == Mesh.ARRAY_CUSTOM2 or ai == Mesh.ARRAY_CUSTOM3:
				continue
			var stride := 1
			if ai == Mesh.ARRAY_TANGENT:
				stride = 4
			elif ai == Mesh.ARRAY_BONES or ai == Mesh.ARRAY_WEIGHTS:
				stride = per
			var typ := typeof(a2)
			var outa = a2.duplicate()
			outa.resize(kept_v.size() * stride)
			for j in kept_v.size():
				for k in stride:
					outa[j * stride + k] = a2[kept_v[j] * stride + k]
			na[ai] = outa
		na[Mesh.ARRAY_INDEX] = new_idx
		var flags := 0
		if per == 8:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na, [], {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
		print("surface ", s, ": verts ", nv, " -> ", kept_v.size(), ", tris ", idx.size() / 3, " -> ", new_idx.size() / 3, " (bones per vert ", per, ")")
	var err := ResourceSaver.save(out, "res://gen/head_only.res")
	print("saved err=", err)
	scene.free()
	quit(0)
