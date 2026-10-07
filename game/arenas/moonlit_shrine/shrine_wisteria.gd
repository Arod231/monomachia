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
## - its canopy lights: a soft purple light at each Glow marker the model
##   carries under its blossom clusters, on every preset (CANOPY_*);
## - its petals: glowing purple flakes falling from the canopy on the wind,
##   which the presets thin out (group look_particles);
## and among them PETAL_LIGHTS small lights drifting down with the petals,
## which Low drops (group look_petal_light; drift_petal_lights() moves them).
## The floating rocks carry young ones: the same models, scaled down
## (young()).

const MODELS: String = "res://assets/exports/shrine/wisteria_%d.glb"
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

## The canopy lights: the blossoms' purple, CANOPY_ENERGY at CANOPY_RANGE,
## each reaching CANOPY_REACH past the floor under it (the higher it hangs,
## the farther and brighter, so each lights the fight alike).
const BLOSSOM := Color("a77bff")
const CANOPY_ENERGY: float = 1.6
const CANOPY_RANGE: float = 9.0
const CANOPY_REACH: float = 4.0
## The lights drifting down with the petals: how many in all, how bright and
## far they reach, and how far each falls in its loop before it starts over.
const PETAL_LIGHTS: int = 5
const PETAL_ENERGY: float = 0.7
const PETAL_RANGE: float = 4.0
const PETAL_FALL: float = 8.0
## The petals: how many each tree drops at High, and how fast they fall
## (m/s, from x to y).
const PETALS: int = 160
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
	for i: int in layout.trees.size():
		var t: Vector4 = layout.trees[i]
		var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(t.x - 90.0)).scaled(Vector3.ONE * t.z),
			ShrineLayout.polar(t.x, t.y, ShrinePlatform.LEDGE_Y))
		if layout.place_art(props, &"wisteria", i, xform):
			continue
		var tree: Node3D = tree_of(int(t.w), bark_material)
		tree.name = "Wisteria%d" % i
		tree.transform = xform
		root.add_child(tree)
		for marker: Node3D in glow_markers(tree):
			var spot: Vector3 = xform * marker.position
			marker.add_child(_canopy_light(spot.y + CANOPY_REACH))
			spots.append(spot)
		root.add_child(_petals(i, tree, layout.wind))
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


## Tree variant (0..VARIANTS - 1, wrapping) as a new node, in bark (bark()
## when not given).
static func tree_of(variant: int, bark_material: Material = null) -> Node3D:
	var v: int = posmod(variant, VARIANTS)
	var model: Node = (load(MODELS % v) as PackedScene).instantiate()
	var tree := (model.find_child("Wisteria%d" % v, false, false) as Node3D).duplicate() as Node3D
	model.free()
	tree.transform = Transform3D.IDENTITY
	if bark_material == null:
		bark_material = bark()
	for node: Node in tree.find_children("*_Bark", "MeshInstance3D", false, false):
		(node as MeshInstance3D).material_override = bark_material
	return tree


## The trees' bark: the bark export's scan (colour and normal map) on the
## look's physically based surface.
static func bark() -> Material:
	var model: Node = (load(BARK) as PackedScene).instantiate()
	var card := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var scan := card.mesh.surface_get_material(0) as BaseMaterial3D
	model.free()
	var m: ShaderMaterial = LookMaterials.make(Color.WHITE, LookMaterials.Surface.PROP,
		Vector2(BARK_ROUGHNESS, 0.0), {
			&"albedo_texture": scan.albedo_texture,
			&"normal_texture": scan.normal_texture,
			&"normal_strength": BARK_NORMAL_STRENGTH if scan.normal_texture != null else 0.0,
		})
	m.resource_name = "WisteriaBark"
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


## Moves the petal lights under root down their loops at time t: each falls
## PETAL_FALL metres from its cluster, drifting on the wind and swaying, then
## starts again from the top.
static func drift_petal_lights(root: Node3D, t: float, wind: Vector2) -> void:
	var lights: Node = root.get_node_or_null(^"PetalLights")
	if lights == null:
		return
	for k: int in lights.get_child_count():
		var light := lights.get_child(k) as Node3D
		var from: Vector3 = light.get_meta(&"from")
		var fall_time: float = PETAL_FALL / ((PETAL_FALL_SPEED.x + PETAL_FALL_SPEED.y) * 0.5)
		var age: float = fposmod(t + k * fall_time / PETAL_LIGHTS, fall_time)
		var drift := Vector3(wind.x, 0.0, wind.y) * age * 0.5
		var sway := Vector3(sin(age * 1.3 + k), 0.0, cos(age * 1.1 + k * 2.0)) * 0.6
		light.position = from + drift + sway + Vector3.DOWN * (PETAL_FALL * age / fall_time)


static func _canopy_light(reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "CanopyLight"
	light.light_color = BLOSSOM
	light.omni_range = maxf(CANOPY_RANGE, reach)
	light.light_energy = CANOPY_ENERGY * pow(light.omni_range / CANOPY_RANGE, 2.0)
	light.omni_attenuation = 1.0
	light.shadow_enabled = false
	light.light_specular = 0.3
	light.light_volumetric_fog_energy = 1.0
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
	m.scale_min = 0.05
	m.scale_max = 0.09
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.8, 1.0])
	var hot := Color(1.3, 0.85, 2.2, 0.0)
	g.colors = PackedColorArray([hot, Color(hot, 0.9), Color(0.9, 0.6, 1.6, 0.8), Color(0.6, 0.4, 1.0, 0.0)])
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
