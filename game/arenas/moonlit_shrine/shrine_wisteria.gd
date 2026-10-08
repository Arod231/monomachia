class_name ShrineWisteria
extends RefCounted
## The Shrine's wisteria (milestone-1 task 48; spec story 149): huge, ancient
## wisteria with dark bark around the arena, their blossoms glowing purple
## and lighting the fight, a canopy that never hides the moon or the
## fighters, and glowing petals falling.
##
## The five trees are the project's own art in exaggerated proportions:
## huge trunks of twisted strands, roots sprawling over the ledge and down
## its edge, and wide, full canopies hanging over the arena above the
## fighters and into one another, with a window left for the moon. They are
## grown by script and shaped in Blender (the asset repository's
## blender/shrine/wisteria_build.py), and brought in by npm run export as one
## model each, MODELS (variant 0..4), each tree in its own frame (+X outward
## from the courtyard). Their bark is Poly Haven's Bark Willow (CC0), its own
## export, BARK: bark() puts it on every tree's <name>_Bark mesh through the
## look's physically based surface (LookMaterials). ShrineLayout.trees
## places them: (angle, radius, scale, variant). Under each:
## - its blossoms glowing pink-lavender like the owner's reference (Oct 7):
##   past the bloom's threshold, so they halo softly, short of glare
##   (BLOSSOM_GLOW, blossom());
## - its canopy lights: a purple light at each Glow marker the model carries
##   under its blossoms over the courtyard, on every preset (CANOPY_*): pools
##   of light under the canopy, fading toward the centre, kept out of the
##   fog, so the blossoms light the arena without a purple haze over it;
## - its petals: glowing purple flakes falling from the canopy on the wind,
##   which the presets thin out (group look_particles);
## and among them PETAL_LIGHTS small lights drifting down with the petals,
## which Low drops (group look_petal_light; drift_petal_lights() moves them).
## Shadows (the owner's choice, Oct 7): the trees cast none, the glowing
## blossoms take none either; the canopy lights cast the fighters' and
## props' shadows. Since milestone-1 task 49 the trees stand on the canopy
## layer (LookPalette.CANOPY_LAYER) and cast shadows there, which only the
## moon shafts in the mist take, so the shafts break through the canopy.
## At match point the petals turn blood red, their glow and the light they
## cast, to bring doom and despair to the final round (the owner's word, Oct
## 7; set_doom(), which MoonlitShrine.set_match_point() eases in): a deep red
## at a dimmer glow, never the tone map's pink.
## The floating rocks carry young ones: the same models, scaled down
## (young()).

const MODELS: String = "res://assets/exports/shrine/wisteria_%d.glb"
## The bark's surface and the blossoms' glow, both swaying on the arena's one
## wind (milestone-1 task 52): the outer branches and the racemes hanging
## from them move, the trunk and thick limbs stay still. Match point's
## blossoms shine through the mist (BLOSSOM_DOOM_SHADER).
const BARK_SHADER: Shader = preload("res://shaders/wisteria_bark.gdshader")
const BLOSSOM_SHADER: Shader = preload("res://shaders/wisteria_blossom.gdshader")
const BLOSSOM_DOOM_SHADER: Shader = preload("res://shaders/wisteria_blossom_doom.gdshader")
const BARK: String = "res://assets/exports/shrine/wisteria_bark.glb"
const VARIANTS: int = 5
## What the models keep, grown to it (wisteria_build.py's numbers, which
## test_shrine_wisteria.gd holds them to): nothing of a tree in the
## courtyard's camera room (over the courtyard, out to the cameras' limit)
## between the wall's top and CANOPY_FLOOR, so no branch or blossom stands
## between a camera and the fighters; and nothing in the line to the moon
## from any camera within MOON_CAMERA_RADIUS of the centre (the spawns' and
## the watch cameras), CAMERA_LOW to CAMERA_HIGH above the floor, so the
## moon shows through a window in the canopy.
const CANOPY_FLOOR: float = 6.6
const MOON_CAMERA_RADIUS: float = 9.0
const CAMERA_LOW: float = 1.4
const CAMERA_HIGH: float = 4.8
## How the bark wears its scan: its roughness, and how much of its normal
## map it keeps.
const BARK_ROUGHNESS: float = 0.9
const BARK_NORMAL_STRENGTH: float = 1.0

## The blossoms' glow: neon lavender, as if bioluminescent (the owner's
## word, Oct 7), at BLOSSOM_EMISSION, times the raceme's own colour; the
## global illumination carries it, so each petal lights what's round it.
const BLOSSOM_GLOW := Color(0.66, 0.2, 1.0)
const BLOSSOM_EMISSION: float = 3.4
## The canopy lights: the blossoms' purple, CANOPY_ENERGY, reaching
## CANOPY_RANGE and falling off steeply (CANOPY_FALLOFF), so each lights a
## pool under the canopy and the centre lies in their fringes.
const BLOSSOM := Color(0.78, 0.45, 1.0)
const CANOPY_ENERGY: float = 12.0
const CANOPY_RANGE: float = 18.0
const CANOPY_FALLOFF: float = 1.5
## Match point's blood red: the blossoms' glow and its strength, the canopy
## lights' colour and strength, and the falling petals' glow.
const DOOM_GLOW := Color(1.0, 0.0, 0.0)
const DOOM_EMISSION: float = 2.2
const DOOM_LIGHT := Color(1.0, 0.02, 0.0)
const DOOM_CANOPY_ENERGY: float = 11.0
const DOOM_PETAL_GLOW := Color(1.3, 0.0, 0.0)
## The lights drifting down with the petals: how many in all, how bright and
## far they reach, and how far each falls in its loop before it starts over.
const PETAL_LIGHTS: int = 5
const PETAL_ENERGY: float = 0.7
const PETAL_RANGE: float = 4.0
const PETAL_FALL: float = 8.0
## The petals: how many each tree drops at High, and how fast they fall
## (m/s, from x to y).
const PETALS: int = 260
## How big the petals are (m, from x to y), and their glow at its brightest
## (HDR, past the bloom's threshold like the blossoms).
const PETAL_SIZE := Vector2(0.14, 0.22)
const PETAL_GLOW := Color(2.1, 0.4, 2.5)
const PETAL_FALL_SPEED := Vector2(0.35, 0.7)

## The grove the layout lays out: one tree per ShrineLayout.trees entry under
## a new Node3D named Wisteria, with its lights and petals, and the petal
## lights. Bought art in layout.prop_scenes under "wisteria" stands in for
## a tree, as for the other props.
static func build(layout: ShrineLayout, props: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Wisteria"
	var spots: Array[Vector3] = []
	var bark_material: Material = bark()
	var blossom_material: Material = blossom()
	root.set_meta(&"blossom", blossom_material)
	for i: int in layout.trees.size():
		var t: Vector4 = layout.trees[i]
		var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(t.x - 90.0)).scaled(Vector3.ONE * t.z),
			ShrineLayout.polar(t.x, t.y, ShrinePlatform.LEDGE_Y))
		if layout.place_art(props, &"wisteria", i, xform):
			continue
		var tree: Node3D = tree_of(int(t.w), bark_material, blossom_material)
		tree.name = "Wisteria%d" % i
		tree.transform = xform
		root.add_child(tree)
		for marker: Node3D in glow_markers(tree):
			var spot: Vector3 = xform * marker.position
			marker.add_child(_canopy_light(spot.y))
			spots.append(spot)
		root.add_child(_petals(i, tree, layout.wind.velocity()))
	var lights := Node3D.new()
	lights.name = "PetalLights"
	root.add_child(lights)
	for k: int in PETAL_LIGHTS:
		if spots.is_empty():
			break
		var light := OmniLight3D.new()
		light.name = "PetalLight%d" % k
		light.light_color = BLOSSOM.lightened(0.15)
		light.light_energy = PETAL_ENERGY
		light.omni_range = PETAL_RANGE
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.5
		light.set_meta(&"from", spots[(k * 2) % spots.size()])
		light.position = spots[(k * 2) % spots.size()]
		light.add_to_group(GraphicsApplier.GROUP_PETAL_LIGHT)
		lights.add_child(light)
	drift_petal_lights(root, 0.0, layout.wind)
	return root


## Tree variant (0..VARIANTS - 1, wrapping) as a new node, in bark and
## blossom (bark() and blossom() when not given).
static func tree_of(variant: int, bark_material: Material = null, blossom_material: Material = null) -> Node3D:
	var v: int = posmod(variant, VARIANTS)
	var model: Node = (load(MODELS % v) as PackedScene).instantiate()
	var tree := (model.find_child("Wisteria%d" % v, false, false) as Node3D).duplicate() as Node3D
	model.free()
	tree.transform = Transform3D.IDENTITY
	if bark_material == null:
		bark_material = bark()
	for node: Node in tree.find_children("*_Bark", "MeshInstance3D", false, false):
		(node as MeshInstance3D).material_override = bark_material
	if blossom_material == null:
		blossom_material = blossom()
	for node: Node in tree.find_children("*_Blossom", "MeshInstance3D", false, false):
		(node as MeshInstance3D).material_override = blossom_material
		# baked into the global illumination, so the blossoms' glow lights
		(node as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_STATIC
	# on the canopy layer, casting shadows only in the moon shafts' light
	# (milestone-1 task 49; every other light leaves the layer out)
	for suffix: String in ["*_Bark", "*_Blossom"]:
		for node: Node in tree.find_children(suffix, "GeometryInstance3D", false, false):
			var geo := node as GeometryInstance3D
			geo.layers |= LookPalette.CANOPY_LAYER
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return tree


## The trees' bark: the bark export's scan (colour and normal map) on the
## look's physically based surface, its outer branches swaying (BARK_SHADER).
static func bark() -> Material:
	var model: Node = (load(BARK) as PackedScene).instantiate()
	var card := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var scan := card.mesh.surface_get_material(0) as BaseMaterial3D
	model.free()
	var m: ShaderMaterial = LookMaterials.make_with_shader(BARK_SHADER, LookMaterials.Surface.PROP, {
		&"base_color": Color.WHITE,
		&"roughness": BARK_ROUGHNESS,
		&"metallic": 0.0,
		&"albedo_texture": scan.albedo_texture,
		&"normal_texture": scan.normal_texture,
		&"normal_strength": BARK_NORMAL_STRENGTH if scan.normal_texture != null else 0.0,
	})
	m.resource_name = "WisteriaBark"
	return m


## The blossoms' glow: the raceme cards (the models' own texture, cut out by
## its alpha, seen from both sides, taking no shadow: a light of their own)
## glowing BLOSSOM_GLOW, swinging on the wind (BLOSSOM_SHADER).
static func blossom() -> ShaderMaterial:
	var model: Node = (load(MODELS % 0) as PackedScene).instantiate()
	var cards := model.find_children("*_Blossom", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var raceme := cards.mesh.surface_get_material(0) as BaseMaterial3D
	model.free()
	var m := ShaderMaterial.new()
	m.shader = BLOSSOM_SHADER
	m.resource_name = "WisteriaBlossom"
	m.set_shader_parameter(&"albedo_texture", raceme.albedo_texture)
	m.set_shader_parameter(&"alpha_scissor", 0.5)
	# lit by their own glow, not the lights under them, so the colour stays
	m.set_shader_parameter(&"albedo_color", BLOSSOM_GLOW.darkened(0.85))
	m.set_shader_parameter(&"emission_color", BLOSSOM_GLOW)
	m.set_shader_parameter(&"emission_energy", BLOSSOM_EMISSION)
	m.set_shader_parameter(&"emission_multiply", false)
	return m


## A young tree on a floating rock: variant scaled to `scale`, its glow
## markers dropped (the rocks' trees light nothing).
static func young(variant: int, scale: float) -> Node3D:
	var tree: Node3D = tree_of(variant)
	tree.name = "YoungWisteria"
	for marker: Node3D in glow_markers(tree):
		marker.get_parent().remove_child(marker)
		marker.free()
	tree.scale = Vector3.ONE * scale
	return tree


## The Glow markers a tree's model carries under its blossom clusters.
static func glow_markers(tree: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child: Node in tree.get_children():
		if child is Node3D and String(child.name).contains("_Glow"):
			out.append(child as Node3D)
	return out


## Turns the grove under root toward match point's blood red: t 0 is the
## lavender, 1 the blood red.
static func set_doom(root: Node3D, t: float) -> void:
	var m := root.get_meta(&"blossom", null) as ShaderMaterial
	if m != null:
		var glow: Color = BLOSSOM_GLOW.lerp(DOOM_GLOW, t)
		m.set_shader_parameter(&"emission_color", glow)
		m.set_shader_parameter(&"emission_energy", lerpf(BLOSSOM_EMISSION, DOOM_EMISSION, t))
		m.set_shader_parameter(&"albedo_color", glow.darkened(0.85))
		# the mist's blue veil would turn the blood red pink: glowing, they shine
		# through it
		m.shader = BLOSSOM_DOOM_SHADER if t > 0.0 else BLOSSOM_SHADER
		# the raceme's own lavender multiplies the red, not adds to it (which
		# turns it pink)
		m.set_shader_parameter(&"emission_multiply", t > 0.0)
	for node: Node in root.find_children("CanopyLight", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		light.light_color = BLOSSOM.lerp(DOOM_LIGHT, t)
		light.light_energy = lerpf(CANOPY_ENERGY, DOOM_CANOPY_ENERGY, t)
	var lights: Node = root.get_node_or_null(^"PetalLights")
	if lights != null:
		for node: Node in lights.get_children():
			(node as Light3D).light_color = BLOSSOM.lightened(0.15).lerp(DOOM_LIGHT, t)
	for node: Node in root.get_children():
		if node is GPUParticles3D and String(node.name).begins_with("Petals"):
			var ramp: GradientTexture1D = ((node as GPUParticles3D).process_material as ParticleProcessMaterial).color_ramp
			ramp.gradient.colors = _petal_colors(PETAL_GLOW.lerp(DOOM_PETAL_GLOW, t))


## The petals' colour over their fall, glowing `glow` at their brightest.
static func _petal_colors(glow: Color) -> PackedColorArray:
	return PackedColorArray([Color(glow, 0.0), Color(glow, 0.95), Color(glow * 0.8, 0.85), Color(glow * 0.5, 0.0)])


## Moves the petal lights under root down their loops at time t: each falls
## PETAL_FALL metres from its cluster, drifting on the arena's wind (carried
## further as a gust passes it) and swaying, then starts again from the top.
static func drift_petal_lights(root: Node3D, t: float, wind: Wind) -> void:
	var lights: Node = root.get_node_or_null(^"PetalLights")
	if lights == null:
		return
	for k: int in lights.get_child_count():
		var light := lights.get_child(k) as Node3D
		var from: Vector3 = light.get_meta(&"from")
		var fall_time: float = PETAL_FALL / ((PETAL_FALL_SPEED.x + PETAL_FALL_SPEED.y) * 0.5)
		var age: float = fposmod(t + k * fall_time / PETAL_LIGHTS, fall_time)
		var w: Vector2 = wind.at(from)
		var drift := Vector3(w.x, 0.0, w.y) * age * 0.5
		var sway := Vector3(sin(age * 1.3 + k), 0.0, cos(age * 1.1 + k * 2.0)) * 0.6
		light.position = from + drift + sway + Vector3.DOWN * (PETAL_FALL * age / fall_time)


## A canopy light hanging `height` over the floor: CANOPY_RANGE, or more, so
## one hanging high still reaches the floor.
static func _canopy_light(height: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "CanopyLight"
	light.light_color = BLOSSOM
	light.omni_range = maxf(CANOPY_RANGE, height + 4.0)
	light.light_energy = CANOPY_ENERGY
	light.omni_attenuation = CANOPY_FALLOFF
	# the fighters and props cast shadows in the blossoms' light, the
	# trees none
	light.shadow_enabled = true
	light.shadow_caster_mask = LookPalette.SHADOW_CASTERS
	light.light_specular = 0.3
	light.light_volumetric_fog_energy = 0.2
	return light


## Tree index's petals: glowing flakes falling from its canopy on the wind.
static func _petals(index: int, tree: Node3D, wind: Vector2) -> GPUParticles3D:
	var bounds := AABB()
	var first: bool = true
	for node: Node in tree.find_children("*_Blossom", "MeshInstance3D", false, false):
		var mi := node as MeshInstance3D
		var box: AABB = tree.transform * (mi.transform * mi.get_aabb())
		bounds = box if first else bounds.merge(box)
		first = false
	var p := GPUParticles3D.new()
	p.name = "Petals%d" % index
	p.amount = PETALS
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_to_group(GraphicsApplier.GROUP_PARTICLES)
	p.position = bounds.get_center() + Vector3(0.0, bounds.size.y * 0.2, 0.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(bounds.size.x * 0.4, bounds.size.y * 0.2, bounds.size.z * 0.4)
	m.direction = Vector3(wind.x, -(PETAL_FALL_SPEED.x + PETAL_FALL_SPEED.y) * 0.5, wind.y).normalized()
	m.initial_velocity_min = PETAL_FALL_SPEED.x / absf(m.direction.y)
	m.initial_velocity_max = PETAL_FALL_SPEED.y / absf(m.direction.y)
	m.spread = 18.0
	m.gravity = Vector3.ZERO
	m.scale_min = PETAL_SIZE.x
	m.scale_max = PETAL_SIZE.y
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.8, 1.0])
	g.colors = _petal_colors(PETAL_GLOW)
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	ramp.use_hdr = true
	m.color_ramp = ramp
	p.process_material = m
	var mat := ShaderMaterial.new()
	mat.shader = ShrineParticles.FLAKE
	mat.set_shader_parameter(&"near_fade", ShrineParticles.NEAR_FADE)
	var quad := QuadMesh.new()
	quad.material = mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(-m.emission_box_extents, m.emission_box_extents * 2.0).grow(
		m.initial_velocity_max * p.lifetime + ShrineParticles.QUAD_SLACK)
	return p
