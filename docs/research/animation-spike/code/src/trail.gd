extends MeshInstance3D
# Weapon trail ribbon between blade base and tip, sampled from the swing path at sub-frame steps
# (the path is analytic, so the ribbon stays smooth even when the blade moves 50 degrees per frame),
# plus an optional thin polyline of the whole tip path so far.

var im := ImmediateMesh.new()
var ribbon_mat := StandardMaterial3D.new()
var line_mat := StandardMaterial3D.new()
var color := Color(1, 1, 1)

func _init() -> void:
	mesh = im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon_mat.vertex_color_use_as_albedo = true
	ribbon_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

# segs: Array of [base: Vector3, tip: Vector3] in world space, oldest first.
func draw(segs: Array, path: Array = []) -> void:
	im.clear_surfaces()
	if segs.size() >= 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, ribbon_mat)
		for i in segs.size():
			var a := float(i) / float(segs.size() - 1)
			var al := pow(a, 1.6) * 0.75
			im.surface_set_color(Color(color.r, color.g, color.b, al * 0.15))
			im.surface_add_vertex(segs[i][0])
			im.surface_set_color(Color(color.r, color.g, color.b, al))
			im.surface_add_vertex(segs[i][1])
		im.surface_end()
	if path.size() >= 2:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_mat)
		for p in path:
			im.surface_set_color(Color(1.0, 0.85, 0.3, 0.8))
			im.surface_add_vertex(p)
		im.surface_end()
