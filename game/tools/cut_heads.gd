extends SceneTree
## Cuts each Quaternius base body down to its head and neck, so the outfit
## parts can be worn over it without the naked body poking through (the
## outfits' own readme says to use only the head). The free packs have no
## head-only mesh, so it is made here from the bone weights.
##
## Run: node scripts/godot.mjs script res://tools/cut_heads.gd
##
## A triangle is kept when each of its three vertices has at least
## HEAD_WEIGHT of its skin weight on the Head and Neck bones. The result is
## geometry only, with the body's vertex order inside each kept triangle and
## the same bone indices, so it keeps working with the body's Skin; the
## fighter takes the body's materials (see FighterModel).

## Body scene -> head mesh it produces.
const BODIES: Dictionary[String, String] = {
	"res://assets/quaternius/characters/Superhero_Female_FullBody_Tall.gltf": "res://fighters/heads/female_head.res",
	"res://assets/quaternius/characters/Superhero_Male_FullBody_Tall.gltf": "res://fighters/heads/male_head.res",
}
const HEAD_BONES: Array[StringName] = [&"Head", &"Neck"]
const HEAD_WEIGHT: float = 0.5


func _initialize() -> void:
	var failed: bool = false
	for body_path: String in BODIES:
		var scene: Node = (load(body_path) as PackedScene).instantiate()
		var body: MeshInstance3D = body_mesh_instance(scene)
		var head: ArrayMesh = cut(body.mesh, body.skin)
		var out_path: String = BODIES[body_path]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
		var err: Error = ResourceSaver.save(head, out_path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			printerr("cut_heads: cannot save %s (%s)" % [out_path, error_string(err)])
			failed = true
		else:
			print("cut_heads: %s: %d -> %d triangles, saved %s" % [
				body_path.get_file(), _triangles(body.mesh), _triangles(head), out_path])
		scene.free()
	quit(1 if failed else 0)


## The body's own mesh: the biggest skinned mesh in the scene (the others are
## the eyes and eyebrows).
static func body_mesh_instance(scene: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if best == null or mi.mesh.surface_get_array_len(0) > best.mesh.surface_get_array_len(0):
			best = mi
	return best


## Skin bind indices that belong to the head and neck bones.
static func head_binds(skin: Skin) -> Dictionary[int, bool]:
	var binds: Dictionary[int, bool] = {}
	for i: int in skin.get_bind_count():
		if HEAD_BONES.has(skin.get_bind_name(i)):
			binds[i] = true
	return binds


## How much of a vertex's weight is on the head and neck, for every vertex.
static func head_weights(arrays: Array, binds: Dictionary[int, bool]) -> PackedFloat32Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size() / verts.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(verts.size())
	for v: int in verts.size():
		var w: float = 0.0
		for k: int in per:
			if binds.has(bones[v * per + k]):
				w += weights[v * per + k]
		out[v] = w
	return out


static func cut(src: Mesh, skin: Skin) -> ArrayMesh:
	var binds: Dictionary[int, bool] = head_binds(skin)
	var out: ArrayMesh = ArrayMesh.new()
	for s: int in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var per: int = bones.size() / verts.size()
		var head_w: PackedFloat32Array = head_weights(arrays, binds)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var remap: PackedInt32Array = PackedInt32Array()
		remap.resize(verts.size())
		remap.fill(-1)
		var kept: PackedInt32Array = PackedInt32Array()
		var new_index: PackedInt32Array = PackedInt32Array()
		for t: int in index.size() / 3:
			var a: int = index[t * 3]
			var b: int = index[t * 3 + 1]
			var c: int = index[t * 3 + 2]
			if minf(head_w[a], minf(head_w[b], head_w[c])) < HEAD_WEIGHT:
				continue
			for v: int in [a, b, c]:
				if remap[v] < 0:
					remap[v] = kept.size()
					kept.append(v)
				new_index.append(remap[v])
		var new_arrays: Array = []
		new_arrays.resize(Mesh.ARRAY_MAX)
		for ai: int in Mesh.ARRAY_MAX:
			if arrays[ai] == null or ai == Mesh.ARRAY_INDEX:
				continue
			if ai >= Mesh.ARRAY_CUSTOM0 and ai <= Mesh.ARRAY_CUSTOM3:
				continue
			var stride: int = 1
			if ai == Mesh.ARRAY_TANGENT:
				stride = 4
			elif ai == Mesh.ARRAY_BONES or ai == Mesh.ARRAY_WEIGHTS:
				stride = per
			new_arrays[ai] = _compact(arrays[ai], kept, stride)
		new_arrays[Mesh.ARRAY_INDEX] = new_index
		var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays, [], {}, flags)
	return out


## Keeps the per-vertex entries of `kept`, in that order.
static func _compact(src: Variant, kept: PackedInt32Array, stride: int) -> Variant:
	var dst: Variant = src.duplicate()
	dst.resize(kept.size() * stride)
	for j: int in kept.size():
		for k: int in stride:
			dst[j * stride + k] = src[kept[j] * stride + k]
	return dst


static func _triangles(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n
