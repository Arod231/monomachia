class_name Stage
extends RefCounted
# Scene dressing, cameras and capture helpers for the screenshot scripts.

static func neutral(root: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.37)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 35, 0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 200, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.75, 0.82, 1.0)
	root.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.42, 0.43)
	fm.roughness = 0.9
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	# grid lines every metre to read distances
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.3, 0.3, 0.31)
	im.surface_begin(Mesh.PRIMITIVE_LINES, gm)
	for i in range(-10, 11):
		im.surface_add_vertex(Vector3(i, 0.002, -10)); im.surface_add_vertex(Vector3(i, 0.002, 10))
		im.surface_add_vertex(Vector3(-10, 0.002, i)); im.surface_add_vertex(Vector3(10, 0.002, i))
	im.surface_end()
	root.add_child(grid)

static func camera(root: Node, pos: Vector3, target: Vector3, fov: float = 40.0) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	cam.current = true
	return cam

static func label(root: Node) -> Label:
	var cl := CanvasLayer.new()
	root.add_child(cl)
	var l := Label.new()
	l.position = Vector2(24, 16)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	cl.add_child(l)
	return l

static func grab(tree: SceneTree) -> Image:
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()

# Crops each image to `crop` (a Rect2i in viewport pixels), scales it by `scale`,
# and lays the cells out in rows of `cols`.
static func sheet(images: Array, crop: Rect2i, cols: int, scale: float, path: String) -> void:
	var cw := int(crop.size.x * scale); var ch := int(crop.size.y * scale)
	var rows := int(ceil(images.size() / float(cols)))
	var out := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.06))
	for i in images.size():
		var img: Image = (images[i] as Image).get_region(crop)
		img.convert(Image.FORMAT_RGBA8)
		if scale != 1.0:
			img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	out.save_png(path)
