class_name ShrineBackdrop
extends RefCounted
## Builds the world round the floating shrine, under World:
## - CloudSea, the dense sea of clouds, and CloudVeil, a softer layer over
##   it, both with a clearing where the lake shows through;
## - Mountains, rings of ranges (Range0 nearest) with a valley toward the
##   moon, down under the water in front of the lake: the landscape's model
##   (milestone-1 task 51), sculpted in Blender from landscape_spec() by
##   scripts/blender/build_shrine_landscape.py, each range beside its lighter
##   twin (Range<i>Low), which Low draws in its place
##   (GraphicsPreset.light_landscape);
## - Lake, far off under the moon, and LakeLanterns drifting on it. The fight
##   cameras look over the parapet, which hides the water; it shows from
##   outside the walls;
## - Cliffs: spires rising out of the clouds (Spire<i>, the landscape
##   model's, with its Spire<i>Low) with pagodas and temple halls on top,
##   facing the shrine, and Waterfalls falling into the clouds;
## - Mist, puffs on the clouds and at the waterfalls' feet, and CragMist round
##   the crag's tip, on the below-deck layer with the crag.
## All of it is far away and casts no shadows: the ranges and spires are lit
## rock (LANDSCAPE: the paving's scans laid on by world position), the rest
## unshaded shaders on the look's noise. The presets trim it by scenery
## detail (DETAIL).

const CLOUD_SEA: Shader = preload("res://shaders/cloud_sea.gdshader")
const CLOUD_VOLUME: Shader = preload("res://shaders/cloud_volume.gdshader")
const LANDSCAPE: Shader = preload("res://shaders/landscape_rock.gdshader")
## The landscape's model: Range<i> and Cliff<i>, each with its _Low twin.
const MODEL: String = "res://assets/exports/shrine/landscape.glb"
const WATERFALL: Shader = preload("res://shaders/waterfall.gdshader")
const LAKE: Shader = preload("res://shaders/lake_water.gdshader")
const MIST: Shader = preload("res://shaders/mist_puff.gdshader")

## The scenery detail (GraphicsPreset.scenery_detail) each part needs to be
## drawn; the parts left out are drawn on every preset.
const DETAIL: Dictionary[StringName, int] = {&"CloudVeil": 1, &"Cliffs": 1, &"LakeLanterns": 1, &"Mist": 2, &"CragMist": 2}
## How far the clouds reach, and how far under the veil the sea lies.
const CLOUD_RADIUS := 2600.0
const CLOUD_SEA_DEPTH := 12.0
## How far under the lake's water the valley toward the moon drops at its
## deepest.
const VALLEY_FLOOR := 10.0
## Cliffs this wide (radius, m) or wider carry a pagoda; from TEMPLE_CLIFF a
## temple hall and a small pagoda; narrower ones a hall.
const PAGODA_CLIFF := 15.0
const TEMPLE_CLIFF := 12.0
## How far below the veil the cliffs' feet and the waterfalls end.
const SPIRE_FOOT := 40.0
const WATERFALL_PLUNGE := 5.5
## Lanterns on the lake, and mist puffs: at each waterfall's foot, on the
## clouds near the island and round the crag's tip.
const LAKE_LANTERNS := 16
const MIST_PER_FALL := 5
const CLOUD_BILLOWS := 40
const CRAG_MIST := 22
## The cloud volume (Ultra and High): how high its billows rise over the
## sea's top, how deep it reaches under it, how high its fog banks rise
## between the ranges (nearest first) and how wide they spread, and where
## its disc starts (a point's width from the centre, where the crag stands
## in it).
const BILLOW := 13.0
const VOLUME_DEPTH := 30.0
const BANK_HEIGHTS: PackedFloat32Array = [14.0, 20.0, 24.0]
const BANK_WIDTH := 55.0
const VOLUME_INNER := 0.5
## Points round each ring's crest (ridge()).
const RIDGE_SAMPLES := 720
## How far under the veil the ranges' feet lie.
const RANGE_FOOT := 60.0


## The world round the shrine. horizon is the colour the depth fog fades to,
## which the clouds, the mountains and the lake fade to as well.
static func build(layout: ShrineLayout, horizon: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "World"
	var moon: Vector3 = layout.moon_direction.normalized()
	var lake_centre: Vector3 = ShrineLayout.polar(layout.lake.x, layout.lake.y, layout.lake.z)
	var clearing := Vector3(lake_centre.x, lake_centre.z, layout.lake.w * 0.75)
	var shared: Dictionary = {&"moon_direction": moon, &"horizon_color": horizon, &"clearing": clearing,
		&"drift_direction": layout.wind.normalized()}
	root.add_child(_clouds(&"CloudSea", layout.cloud_sea_height - CLOUD_SEA_DEPTH, shared.merged({
		&"coverage": 0.3, &"scale": 0.006, &"lit_color": Color(0.28, 0.3, 0.38), &"opacity": 1.0})))
	root.add_child(_clouds(&"CloudVeil", layout.cloud_sea_height, shared.merged({&"opacity": 0.8})))
	root.add_child(_cloud_volume(layout, shared))
	var model: Node = (load(MODEL) as PackedScene).instantiate()
	var rock: ShaderMaterial = rock_material()
	rock.set_shader_parameter(&"horizon_color", horizon)
	root.add_child(_mountains(layout, model, rock))
	root.add_child(_lake(layout, lake_centre, moon, horizon))
	root.add_child(_lake_lanterns(layout, lake_centre))
	root.add_child(_cliffs(layout, model, rock, horizon))
	model.free()
	root.add_child(_mist(layout))
	root.add_child(_crag_mist(layout))
	for part: Node in root.get_children():
		if DETAIL.has(part.name):
			part.set_meta(GraphicsApplier.META_DETAIL, DETAIL[part.name])
			part.add_to_group(GraphicsApplier.GROUP_SCENERY)
	# the mesh layers on Medium and Low, the volume on Ultra and High
	for part: StringName in [&"CloudSea", &"CloudVeil", &"CloudVolume"]:
		var clouds: Node = root.get_node(NodePath(part))
		clouds.set_meta(GraphicsApplier.META_VOLUMETRIC_CLOUDS, part == &"CloudVolume")
		clouds.add_to_group(GraphicsApplier.GROUP_CLOUDS)
	return root


## The numbers the modelled landscape is sculpted from (milestone-1 task 51):
## game/tools/export_landscape_spec.gd writes them to
## scripts/blender/shrine/landscape.json, which
## scripts/blender/build_shrine_landscape.py reads, and
## test_shrine_landscape.gd holds that file to them. Each range's crest
## (ridge(), which keeps the valley toward the moon) and each cliff's place,
## top, radius and foot, with the side its waterfall falls from; the sea of
## clouds' height, the ranges' feet under it, the moon and the lake.
static func landscape_spec(layout: ShrineLayout) -> Dictionary:
	var rng: RandomNumberGenerator = layout.random_stream(&"mountains")
	var ranges: Array = []
	for i: int in layout.mountain_layers.size():
		var m: Vector4 = layout.mountain_layers[i]
		var crest: Array = []
		for p: Vector3 in ridge(layout, i, rng.randi()):
			crest.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
		ranges.append({"index": i, "distance": m.x, "lowest": m.y, "highest": m.z, "crest": crest,
			"seed": i * 101 + layout.seed})
	var cliffs: Array = []
	for i: int in layout.cliffs.size():
		var c: Vector4 = layout.cliffs[i]
		var centre: Vector3 = _cliff_centre(layout, i)
		var toward: Vector3 = _toward_shrine(layout, i)
		cliffs.append({"index": i, "centre": [snappedf(centre.x, 0.001), snappedf(centre.z, 0.001)], "top": c.z,
			"radius": c.w, "foot": layout.cloud_sea_height - SPIRE_FOOT,
			"toward": [snappedf(toward.x, 0.0001), snappedf(toward.z, 0.0001)],
			"waterfall": layout.waterfall_cliffs.has(i), "seed": i * 37 + layout.seed})
	var moon: Vector3 = layout.moon_direction.normalized()
	var lake: Vector3 = ShrineLayout.polar(layout.lake.x, layout.lake.y, layout.lake.z)
	return {
		"cloud_sea_height": layout.cloud_sea_height,
		"range_foot": layout.cloud_sea_height - RANGE_FOOT,
		"moon": [snappedf(moon.x, 0.0001), snappedf(moon.y, 0.0001), snappedf(moon.z, 0.0001)],
		"lake": {"centre": [snappedf(lake.x, 0.001), snappedf(lake.z, 0.001)], "height": lake.y, "radius": layout.lake.w},
		"ranges": ranges,
		"cliffs": cliffs,
	}


## A material of shader with params set, and the look's noise.
static func _material(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key: StringName in params:
		mat.set_shader_parameter(key, params[key])
	LookNoise.apply_to(mat)
	return mat


## A layer of cloud at height, out to CLOUD_RADIUS.
static func _clouds(part: StringName, height: float, params: Dictionary) -> MeshInstance3D:
	var kit := MeshKit.new()
	kit.disc(Transform3D(Basis(), Vector3(0, height, 0)), CLOUD_RADIUS, 96, 14)
	var mi := MeshKit.instance(kit.commit(), _material(CLOUD_SEA, params), false)
	mi.name = part
	return mi


## The sea of clouds as a volume the moon lights (cloud_volume.gdshader): a
## shallow cone over the island out to CLOUD_RADIUS, at each distance just
## over the highest top the cloud reaches there, its fog banks rising midway
## between the ranges.
static func _cloud_volume(layout: ShrineLayout, shared: Dictionary) -> MeshInstance3D:
	var radii := Vector4.ZERO
	var heights := Vector4.ZERO
	var rings: PackedVector4Array = layout.mountain_layers
	for i: int in mini(rings.size() - 1, BANK_HEIGHTS.size()):
		radii[i] = (rings[i].x + rings[i + 1].x) * 0.5
		heights[i] = BANK_HEIGHTS[i]
	var top: float = layout.cloud_sea_height
	var steps: PackedFloat32Array = []
	var r: float = VOLUME_INNER
	while r < CLOUD_RADIUS:
		steps.append(r)
		r = r * 1.12 + 2.0
	steps.append(CLOUD_RADIUS)
	var segments: int = 128
	var grid: Array[PackedVector3Array] = []
	for ring_r: float in steps:
		var h: float = top + BILLOW * 1.15 + 1.0
		for i: int in 4:
			var d: float = (ring_r - radii[i]) / BANK_WIDTH
			h += heights[i] * 1.5 * exp(-d * d)
		var row := PackedVector3Array()
		for k: int in segments + 1:
			var a: float = -TAU * k / segments
			row.append(Vector3(sin(a) * ring_r, h, cos(a) * ring_r))
		grid.append(row)
	var kit := MeshKit.new()
	kit.grid_surface(Transform3D.IDENTITY, grid, true)
	var mat := _material(CLOUD_VOLUME, shared.merged({
		&"cloud_top": top, &"billow": BILLOW, &"cloud_floor": top - VOLUME_DEPTH,
		&"bank_radii": radii, &"bank_heights": heights, &"bank_width": BANK_WIDTH,
		&"key_direction": layout.key_light_direction.normalized()}))
	var mi := MeshKit.instance(kit.commit(), mat, false)
	mi.name = "CloudVolume"
	return mi


## The rings of mountains, each the landscape model's range and its lighter
## twin for Low.
static func _mountains(layout: ShrineLayout, model: Node, rock: ShaderMaterial) -> Node3D:
	var node := Node3D.new()
	node.name = "Mountains"
	for i: int in layout.mountain_layers.size():
		_landscape_pair(node, model, "Range%d" % i, "Range%d" % i, rock)
	return node


## The model's mesh model_name and its _Low twin under parent, named
## child_name and child_name + "Low", in rock, casting no shadow, each shown
## on the presets that ask for it (GraphicsApplier.GROUP_LANDSCAPE).
static func _landscape_pair(parent: Node3D, model: Node, model_name: String, child_name: String, rock: ShaderMaterial) -> void:
	for light: bool in [false, true]:
		var source := model.find_child(model_name + ("_Low" if light else ""), true, false) as MeshInstance3D
		var mi := MeshInstance3D.new()
		mi.name = child_name + ("Low" if light else "")
		mi.mesh = source.mesh
		mi.material_override = rock
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta(GraphicsApplier.META_LIGHT_LANDSCAPE, light)
		mi.add_to_group(GraphicsApplier.GROUP_LANDSCAPE)
		mi.visible = not light
		parent.add_child(mi)


## The ranges' and spires' rock: the paving's scans (ShrinePlatform.paving_maps())
## laid on by world position.
static func rock_material() -> ShaderMaterial:
	var maps: Dictionary = ShrinePlatform.paving_maps()
	var params: Dictionary = {}
	for key: StringName in [&"stone_albedo", &"stone_normal", &"stone_rough", &"grime_albedo", &"grime_normal"]:
		params[key] = maps[key]
	return _material(LANDSCAPE, params)


## The crest of ring index, RIDGE_SAMPLES points round it from angle 0 (+z)
## toward +x: a noisy ridge between the ring's lowest and highest, its
## distance wandering a little, with a valley toward the moon down under the
## lake's water, so the moon and the lake stay in view. Rounded to the
## millimetre, as landscape_spec() hands it to Blender.
static func ridge(layout: ShrineLayout, index: int, noise_seed: int) -> PackedVector3Array:
	# (distance, lowest ridge, highest peak, valley depth toward the moon)
	var m: Vector4 = layout.mountain_layers[index]
	var valley_floor: float = layout.lake.z - VALLEY_FLOOR
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55
	var moon_angle: float = atan2(layout.moon_direction.x, layout.moon_direction.z)
	# Each ring samples the noise on a circle of its own size.
	var sample_radius: float = 1.5 + index * 0.35
	var tops := PackedVector3Array()
	for i: int in RIDGE_SAMPLES:
		var a: float = TAU * i / RIDGE_SAMPLES
		var c := Vector2(sin(a), cos(a)) * sample_radius
		var n: float = noise.get_noise_2d(c.x, c.y) * 0.5 + 0.5
		var ridged: float = 1.0 - absf(noise.get_noise_2d(c.x * 2.7 + 9.0, c.y * 2.7))
		var h: float = clampf(pow(n, 1.6) * 1.25 + ridged * 0.1, 0.0, 1.0)
		var valley: float = m.w * smoothstep(0.82, 0.99, cos(angle_difference(a, moon_angle)))
		var r: float = m.x * (1.0 + 0.07 * noise.get_noise_2d(c.x * 0.5 + 40.0, c.y * 0.5))
		var top := Vector3(sin(a) * r, lerpf(lerpf(m.y, m.z, h), valley_floor, valley), cos(a) * r)
		tops.append(Vector3(snappedf(top.x, 0.001), snappedf(top.y, 0.001), snappedf(top.z, 0.001)))
	return tops


## The lake, mirroring the horizon's mist and the moon.
static func _lake(layout: ShrineLayout, centre: Vector3, moon: Vector3, horizon: Color) -> MeshInstance3D:
	var kit := MeshKit.new()
	kit.disc(Transform3D(Basis(), centre), layout.lake.w, 64, 6)
	var mi := MeshKit.instance(kit.commit(), _material(LAKE, {&"moon_direction": moon, &"horizon_color": horizon}), false)
	mi.name = "Lake"
	return mi


## Small warm lights drifting on the lake.
static func _lake_lanterns(layout: ShrineLayout, centre: Vector3) -> MultiMeshInstance3D:
	var rng: RandomNumberGenerator = layout.random_stream(&"lake_lanterns")
	var spots: Array[Transform3D] = []
	for k: int in LAKE_LANTERNS:
		var spot: Vector3 = ShrineLayout.polar(rng.randf_range(0.0, 360.0), sqrt(rng.randf()) * layout.lake.w * 0.8, 0.6)
		spots.append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), centre + spot))
	var bulb := SphereMesh.new()
	bulb.radius = 1.0
	bulb.height = 2.0
	bulb.radial_segments = 8
	bulb.rings = 4
	var lanterns := MeshKit.multimesh(bulb, spots, ShrineProps.distant_glow_material())
	lanterns.name = "LakeLanterns"
	lanterns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lanterns


## The cliff spires with their buildings and waterfalls.
static func _cliffs(layout: ShrineLayout, model: Node, rock: ShaderMaterial, horizon: Color) -> Node3D:
	var node := Node3D.new()
	node.name = "Cliffs"
	var falls := MeshKit.new()
	var buildings := ShrineBuildings.new()
	for i: int in layout.cliffs.size():
		var c: Vector4 = layout.cliffs[i]
		var centre: Vector3 = _cliff_centre(layout, i)
		_landscape_pair(node, model, "Cliff%d" % i, "Spire%d" % i, rock)
		# The buildings face the shrine.
		var top := Transform3D(Basis(Vector3.UP, deg_to_rad(c.x + 180.0)), centre + Vector3(0, c.z, 0))
		if c.w >= PAGODA_CLIFF:
			_pagoda(node, buildings, layout, i, top, c.w * 0.42)
		elif c.w >= TEMPLE_CLIFF:
			_temple_hall(node, buildings, layout, i, top, c.w * 0.9)
			_pagoda(node, buildings, layout, i, top.translated_local(Vector3(c.w * 0.45, 0, c.w * 0.3)), c.w * 0.22)
		else:
			_temple_hall(node, buildings, layout, i, top, c.w * 0.8)
		if layout.waterfall_cliffs.has(i):
			var lip: Vector3 = _waterfall_lip(layout, i)
			_waterfall(falls, lip, _toward_shrine(layout, i), lip.y - layout.cloud_sea_height + WATERFALL_PLUNGE, c.w * 0.38)
	# the modelled buildings step back with their rock (LookMaterials.far())
	for building: Node in node.get_children():
		var body := building.get_node_or_null(^"Body") as MeshInstance3D
		if body != null:
			for s: int in body.get_surface_override_material_count():
				body.set_surface_override_material(s, LookMaterials.far(body.get_surface_override_material(s), horizon))
	var waterfalls := MeshKit.instance(falls.commit(), _material(WATERFALL, {}), false)
	waterfalls.name = "Waterfalls"
	node.add_child(waterfalls)
	return node


## A pagoda on xform, width wide (the modelled one, milestone-1 task 132,
## ShrineBuildings), or the bought one scaled to width.
static func _pagoda(node: Node3D, buildings: ShrineBuildings, layout: ShrineLayout, index: int, xform: Transform3D,
		width: float) -> void:
	if not layout.place_art(node, &"pagoda", index, xform.scaled_local(Vector3.ONE * width)):
		node.add_child(buildings.pagoda(index, xform, width))


## A temple hall on xform, width wide (the modelled one), or the bought one
## scaled to width.
static func _temple_hall(node: Node3D, buildings: ShrineBuildings, layout: ShrineLayout, index: int, xform: Transform3D,
		width: float) -> void:
	if not layout.place_art(node, &"temple_hall", index, xform.scaled_local(Vector3.ONE * width)):
		node.add_child(buildings.temple_hall(index, xform, width))


## Cliff index's centre, at the courtyard floor's height.
static func _cliff_centre(layout: ShrineLayout, index: int) -> Vector3:
	return ShrineLayout.polar(layout.cliffs[index].x, layout.cliffs[index].y)


## From cliff index toward the shrine, level.
static func _toward_shrine(layout: ShrineLayout, index: int) -> Vector3:
	return -_cliff_centre(layout, index).normalized()


## Where cliff index's waterfall leaves it: on the side facing the shrine,
## just under its top.
static func _waterfall_lip(layout: ShrineLayout, index: int) -> Vector3:
	var c: Vector4 = layout.cliffs[index]
	return _cliff_centre(layout, index) + _toward_shrine(layout, index) * c.w * 0.92 + Vector3(0, c.z - 1.5, 0)


## A ribbon falling from lip, first out along toward, then straight down
## for drop metres, half_width either side and widening as it falls.
static func _waterfall(kit: MeshKit, lip: Vector3, toward: Vector3, drop: float, half_width: float) -> void:
	var side: Vector3 = toward.cross(Vector3.UP).normalized()
	var steps: int = 14
	for k: int in steps:
		var t0: float = float(k) / steps
		var t1: float = float(k + 1) / steps
		var p0: Vector3 = lip + toward * 3.0 * sqrt(t0) + Vector3.DOWN * drop * t0
		var p1: Vector3 = lip + toward * 3.0 * sqrt(t1) + Vector3.DOWN * drop * t1
		var w0: float = half_width * (1.0 + t0 * 0.6)
		var w1: float = half_width * (1.0 + t1 * 0.6)
		kit.tri(p0 - side * w0, p0 + side * w0, p1 + side * w1, toward, toward, toward, Vector2(0, t0), Vector2(1, t0), Vector2(1, t1))
		kit.tri(p0 - side * w0, p1 + side * w1, p1 - side * w1, toward, toward, toward, Vector2(0, t0), Vector2(1, t1), Vector2(0, t1))


## Mist puffs at each waterfall's foot and billowing on the clouds near the
## island.
static func _mist(layout: ShrineLayout) -> MultiMeshInstance3D:
	var rng: RandomNumberGenerator = layout.random_stream(&"mist")
	var puffs: Array[Transform3D] = []
	for i: int in layout.waterfall_cliffs:
		var lip: Vector3 = _waterfall_lip(layout, i)
		var toward: Vector3 = _toward_shrine(layout, i)
		for k: int in MIST_PER_FALL:
			var p: Vector3 = lip + toward * rng.randf_range(4.0, 12.0) + Vector3(rng.randf_range(-8.0, 8.0),
				layout.cloud_sea_height - lip.y + rng.randf_range(0.0, 8.0), rng.randf_range(-8.0, 8.0))
			puffs.append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(16.0, 30.0)), p))
	var cloud: float = layout.cloud_sea_height
	_puffs(puffs, rng, CLOUD_BILLOWS, Vector2(35.0, 240.0), Vector2(cloud + 2.0, cloud + 9.0), Vector2(28.0, 55.0))
	return _mist_instance(&"Mist", puffs)


## Mist round the crag's tip, under the floor: on the below-deck layer, so
## the cameras above the courtyard leave it out with the crag.
static func _crag_mist(layout: ShrineLayout) -> MultiMeshInstance3D:
	var puffs: Array[Transform3D] = []
	_puffs(puffs, layout.random_stream(&"crag_mist"), CRAG_MIST, Vector2(4.0, 22.0),
		Vector2(layout.cloud_sea_height + 4.0, -layout.crag_depth + 4.0), Vector2(10.0, 22.0))
	var mist := _mist_instance(&"CragMist", puffs)
	mist.layers = LookPalette.BELOW_DECK_LAYER
	return mist


## Adds count puffs round the arena's centre, their distance, height and
## size each drawn from a range (x to y).
static func _puffs(out: Array[Transform3D], rng: RandomNumberGenerator, count: int, radii: Vector2, heights: Vector2,
		sizes: Vector2) -> void:
	for k: int in count:
		var spot: Vector3 = ShrineLayout.polar(rng.randf_range(0.0, 360.0), rng.randf_range(radii.x, radii.y),
			rng.randf_range(heights.x, heights.y))
		out.append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(sizes.x, sizes.y)), spot))


static func _mist_instance(part: StringName, puffs: Array[Transform3D]) -> MultiMeshInstance3D:
	var mist := MeshKit.multimesh(QuadMesh.new(), puffs, _material(MIST, {}))
	mist.name = part
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mist
