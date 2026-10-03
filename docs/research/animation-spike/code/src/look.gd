extends RefCounted
# Toon + ink look: swaps every material on a fighter / katana for toon shaders with an
# inverted-hull outline next_pass, and builds the moonlit stage.

const CHAR := "res://src/shaders/char_toon.gdshader"
const FLAT := "res://src/shaders/flat_toon.gdshader"
const OUTLINE := "res://src/shaders/outline.gdshader"

static func outline_mat(width: float, use_color_normal: bool = false, tex: Texture2D = null, cut: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(OUTLINE)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("use_color_normal", use_color_normal)
	if tex and cut > 0.0:
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("alpha_cut", cut)
	return m

static func apply_fighter(fighter: Node3D, rim_dir: Vector3) -> void:
	var cache := {}
	for node in fighter.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			var bm := src as BaseMaterial3D
			if bm == null:
				continue
			var key := str(bm.get_instance_id()) + mi.name
			if not cache.has(key):
				var sm := ShaderMaterial.new()
				sm.shader = load(CHAR)
				sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
				sm.set_shader_parameter("tint", bm.albedo_color)
				sm.set_shader_parameter("rim_dir", rim_dir)
				if bm.normal_texture:
					sm.set_shader_parameter("normal_tex", bm.normal_texture)
				else:
					sm.set_shader_parameter("use_normal", false)
				var cut := 0.0
				if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					cut = 0.5
				sm.set_shader_parameter("alpha_cut", cut)
				var nm := String(mi.name)
				if nm.contains("Hair"):
					sm.set_shader_parameter("tint", Color(0.80, 0.82, 0.9))
					sm.set_shader_parameter("normal_depth", 0.3)
				sm.set_shader_parameter("normal_depth", 0.35 if not nm.contains("Hair") else 0.25)
				sm.set_shader_parameter("rim_strength", 0.8)
				sm.set_shader_parameter("rim_width", 0.58)
				if nm == "Superhero_Female":
					# the face reads better without the normal map and with softer band edges
					sm.set_shader_parameter("use_normal", false)
					sm.set_shader_parameter("band_soft", 0.07)
					sm.set_shader_parameter("band_lo", 0.0)
					sm.set_shader_parameter("saturation", 0.7)
				if nm in ["Eyes", "Eyebrows"]:
					sm.set_shader_parameter("rim_strength", 0.0)
				else:
					sm.next_pass = outline_mat(0.002 if not nm.contains("Hair") else 0.0013, false, bm.albedo_texture, cut)
				cache[key] = sm
			mi.set_surface_override_material(s, cache[key])
		if String(mi.name).contains("Hood"):
			# the hood would shade the whole face; keep faces readable
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _flat(c: Color, rim_dir: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(FLAT)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("rim_dir", rim_dir)
	return m

static func katana_materials(rim_dir: Vector3) -> Array:
	var blade := ShaderMaterial.new()
	blade.shader = load("res://src/shaders/blade_toon.gdshader")
	blade.set_shader_parameter("spec_strength", 1.6)
	blade.set_shader_parameter("rim_dir", rim_dir)
	blade.set_shader_parameter("rim_strength", 0.8)
	var tsuka := ShaderMaterial.new()
	tsuka.shader = load("res://src/shaders/tsuka_toon.gdshader")
	tsuka.set_shader_parameter("rim_dir", rim_dir)
	var mats := [blade, _flat(Color(0.70, 0.52, 0.22), rim_dir), _flat(Color(0.08, 0.075, 0.07), rim_dir), tsuka, _flat(Color(0.10, 0.09, 0.08), rim_dir)]
	for m in mats:
		(m as ShaderMaterial).next_pass = outline_mat(0.0009, true)
	return mats

static func apply_katana(k: MeshInstance3D, rim_dir: Vector3) -> void:
	var mats := katana_materials(rim_dir)
	for i in k.mesh.get_surface_count():
		k.set_surface_override_material(i, mats[i])

# Moonlit stage: dark sky with the moon disc, one moon directional light, cool ambient, fog,
# a stone floor with toon lighting, and a few dark shrine silhouettes with warm lantern accents.
static func moonlit(root: Node, moon_from: Vector3) -> DirectionalLight3D:
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.015, 0.02, 0.045)
	psm.sky_horizon_color = Color(0.07, 0.08, 0.13)
	psm.ground_bottom_color = Color(0.01, 0.01, 0.015)
	psm.ground_horizon_color = Color(0.06, 0.065, 0.1)
	psm.sun_angle_max = 2.2
	psm.sun_curve = 0.05
	psm.energy_multiplier = 1.0
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.42)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.035
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.78, 0.85, 1.0)
	moon.light_energy = 2.4
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 25.0
	moon.shadow_blur = 0.5
	root.add_child(moon)
	moon.look_at_from_position(moon_from.normalized() * 10.0, Vector3.ZERO, Vector3.UP)
	# stone floor
	var floor_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 15.0
	cm.bottom_radius = 15.0
	cm.height = 0.4
	cm.radial_segments = 96
	floor_mi.mesh = cm
	floor_mi.position = Vector3(0, -0.2, 0)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://src/shaders/floor_toon.gdshader")
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	# shrine silhouettes: pillars + lanterns at the edge of the platform
	var stone := _flat(Color(0.10, 0.10, 0.12), Vector3(0.55, 0.4, -0.75))
	stone.next_pass = outline_mat(0.0012)
	var lacquer := _flat(Color(0.42, 0.07, 0.05), Vector3(0.55, 0.4, -0.75))
	lacquer.next_pass = outline_mat(0.0012)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mtn := StandardMaterial3D.new()
	mtn.albedo_color = Color(0.075, 0.085, 0.13)
	mtn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mtn.disable_fog = true
	var mtn_far := mtn.duplicate() as StandardMaterial3D
	mtn_far.albedo_color = Color(0.11, 0.12, 0.18)
	for i in 26:
		var ma := rng.randf() * TAU
		var md := rng.randf_range(70.0, 160.0)
		var m := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(18.0, 40.0)
		cone.height = rng.randf_range(25.0, 60.0)
		cone.radial_segments = 7
		m.mesh = cone
		m.material_override = mtn if md < 115.0 else mtn_far
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(sin(ma) * md, cone.height * 0.5 - 30.0, cos(ma) * md)
		m.rotation.y = rng.randf() * TAU
		root.add_child(m)
	for ang in [200.0, 235.0, 300.0, 330.0, 20.0, 60.0, 120.0, 150.0]:
		var a := deg_to_rad(ang)
		var p := Vector3(sin(a), 0, cos(a)) * 9.0
		var pil := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.22
		cyl.height = 3.2
		pil.mesh = cyl
		pil.material_override = lacquer
		pil.position = p + Vector3(0, 1.6, 0)
		root.add_child(pil)
		var cap := MeshInstance3D.new()
		var bx2 := BoxMesh.new()
		bx2.size = Vector3(0.75, 0.22, 0.75)
		cap.mesh = bx2
		cap.material_override = stone
		cap.position = p + Vector3(0, 3.3, 0)
		root.add_child(cap)
		var lamp := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.11
		sp.height = 0.22
		lamp.mesh = sp
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(1.0, 0.62, 0.35)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.4, 0.15)
		lm.emission_energy_multiplier = 2.5
		lamp.material_override = lm
		lamp.position = p + Vector3(0, 2.6, 0) - p.normalized() * 0.3
		root.add_child(lamp)
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.5, 0.25)
		ol.light_energy = 0.5
		ol.omni_range = 4.0
		ol.position = lamp.position
		root.add_child(ol)
	return moon
