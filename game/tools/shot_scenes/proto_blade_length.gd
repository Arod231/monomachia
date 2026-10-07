extends "res://tools/shot_scenes/move_sheet.gd"
## PROTOTYPE, throwaway: the move sheet with the Katana's blade stretched by
## --blade=<factor> (1 is today's blade, 0.69 m from the habaki to the tip in
## a straight line), to pick a blade length by eye before the spec. Only the
## blade past the habaki stretches; the handle and guard keep their size. The
## look only: the rules still use today's blade.
##
##   npm run shots -- res://tools/shot_scenes/proto_blade_length.tscn shots/blade.png 1 --blade=1.88 --fighter=hunter --move=k_l1

## The habaki's height on the weapon's long axis (katana.tscn's BladeBase).
const BASE_Y: float = 0.09

var blade_scale: float = 1.0
var _stretched: Dictionary[Mesh, Mesh] = {}


func _enter_tree() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--blade="):
			blade_scale = float(a.trim_prefix("--blade="))
	if blade_scale != 1.0:
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.mesh != null and mi.mesh.resource_path.ends_with("katana_mesh.res"):
			mi.mesh = _stretch(mi.mesh)
	elif n is Marker3D and n.name == &"BladeTip":
		var m: Marker3D = n
		m.position = Vector3(m.position.x * blade_scale, BASE_Y + (m.position.y - BASE_Y) * blade_scale, m.position.z)


func _stretch(src: Mesh) -> Mesh:
	if _stretched.has(src):
		return _stretched[src]
	var out := ArrayMesh.new()
	for s: int in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			if v.y > BASE_Y:
				# along the blade, and the curve's sweep scaled with it
				var t: float = v.y - BASE_Y
				verts[i] = Vector3(v.x + _sori(t) * (blade_scale - 1.0), BASE_Y + t * blade_scale, v.z)
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, src.surface_get_material(s))
	_stretched[src] = out
	return out


## The blade's sideways sweep (sori) at t metres past the habaki, from the
## markers: 0 at the habaki, -0.0787 m at the tip, growing with the square.
func _sori(t: float) -> float:
	var u: float = t / 0.687
	return -0.0787 * u * u
