class_name ShrineBackdrop
extends RefCounted
## Builds the world round the floating shrine, under World:
## - CloudSea, the dense sea of clouds, and CloudVeil, a softer layer over
##   it, both with a clearing where the lake shows through;
## - Mountains, rings of ranges (Range0 nearest) with a valley toward the
##   moon, down under the water in front of the lake;
## - Lake, far off under the moon, and LakeLanterns drifting on it. The fight
##   cameras look over the parapet, which hides the water; it shows from
##   outside the walls;
## - Cliffs: spires rising out of the clouds (Spires) with pagodas and temple
##   halls on top, facing the shrine, and Waterfalls falling into the clouds;
## - Mist, puffs on the clouds and at the waterfalls' feet, and CragMist round
##   the crag's tip, on the below-deck layer with the crag.
## All of it is far away and cheap: unshaded shaders on the look's noise (the
## cliffs' rock and buildings are lit), and no shadows. The
## presets trim it by scenery detail (DETAIL).

const CLOUD_SEA: Shader = preload("res://shaders/cloud_sea.gdshader")
const MOUNTAIN: Shader = preload("res://shaders/mountain_layer.gdshader")
const WATERFALL: Shader = preload("res://shaders/waterfall.gdshader")
const LAKE: Shader = preload("res://shaders/lake_water.gdshader")
const MIST: Shader = preload("res://shaders/mist_puff.gdshader")

## The scenery detail (GraphicsPreset.scenery_detail) each part needs to be
## drawn; the parts left out are drawn on every preset.
const DETAIL: Dictionary[StringName, int] = {&"CloudVeil": 1, &"Cliffs": 1, &"LakeLanterns": 1, &"Mist": 2, &"CragMist": 2}
## How far the clouds reach, and how far under the veil the sea lies.
const CLOUD_RADIUS := 2600.0
const CLOUD_SEA_DEPTH := 12.0
## The mountains' strokes round the nearest ring, and how many more each ring
## further out has (rounded to the noise's period, so they meet round it).
const STROKES := 600.0
const STROKES_PER_RING := 300.0
## How far under the lake's water the valley toward the moon drops at its
## deepest.
const VALLEY_FLOOR := 10.0
## Cliffs this wide (radius, m) or wider carry a pagoda; from TEMPLE_CLIFF a
## temple hall and a small pagoda; narrower ones a hall.
const PAGODA_CLIFF := 15.0
const TEMPLE_CLIFF := 12.0
## How far below the veil the cliffs' bases and the waterfalls end.
const SPIRE_FOOT := 40.0
const WATERFALL_PLUNGE := 5.5
## Lanterns on the lake, and mist puffs: at each waterfall's foot, on the
## clouds near the island and round the crag's tip.
const LAKE_LANTERNS := 16
const MIST_PER_FALL := 5
const CLOUD_BILLOWS := 40
const CRAG_MIST := 22


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
	root.add_child(_mountains(layout, moon, horizon))
	root.add_child(_lake(layout, lake_centre, moon, horizon))
	root.add_child(_lake_lanterns(layout, lake_centre))
	root.add_child(_cliffs(layout))
	root.add_child(_mist(layout))
	root.add_child(_crag_mist(layout))
	for part: Node in root.get_children():
		if DETAIL.has(part.name):
			part.set_meta(GraphicsApplier.META_DETAIL, DETAIL[part.name])
			part.add_to_group(GraphicsApplier.GROUP_SCENERY)
	return root


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


## The rings of mountains, nearest darkest, the farther ones fading toward
## the horizon's mist.
static func _mountains(layout: ShrineLayout, moon: Vector3, horizon: Color) -> Node3D:
	var node := Node3D.new()
	node.name = "Mountains"
	var rng: RandomNumberGenerator = layout.random_stream(&"mountains")
	var count: int = layout.mountain_layers.size()
	for i: int in count:
		var f: float = float(i) / maxf(count - 1, 1)
		var mat := _material(MOUNTAIN, {
			&"layer_fade": f * 0.35,
			&"body_color": Color(0.035, 0.04, 0.06).lerp(Color(0.12, 0.13, 0.17), f),
			&"ridge_color": Color(0.012, 0.014, 0.024).lerp(Color(0.07, 0.08, 0.11), f),
			&"horizon_color": horizon,
			&"moon_direction": moon,
			&"stroke_frequency": snappedf(STROKES + i * STROKES_PER_RING, LookNoise.CELLS),
		})
		var mi := MeshKit.instance(_mountain_ring(layout, i, rng.randi()), mat, false)
		mi.name = "Range%d" % i
		node.add_child(mi)
	return node


## Ring index of the mountains as a strip from far below the clouds up to a
## noisy ridge. UV.x runs once round the ring; UV.y is 0 at the clouds and 1
## at the ridge.
static func _mountain_ring(layout: ShrineLayout, index: int, noise_seed: int) -> ArrayMesh:
	# (distance, lowest ridge, highest peak, valley depth toward the moon)
	var m: Vector4 = layout.mountain_layers[index]
	var valley_floor: float = layout.lake.z - VALLEY_FLOOR
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55
	var segments: int = 720
	var cloud: float = layout.cloud_sea_height
	var bottom: float = cloud - 60.0
	var moon_angle: float = atan2(layout.moon_direction.x, layout.moon_direction.z)
	# Each ring samples the noise on a circle of its own size.
	var sample_radius: float = 1.5 + index * 0.35
	var tops := PackedVector3Array()
	var bases := PackedVector3Array()
	for i: int in segments + 1:
		var a: float = TAU * (i % segments) / segments
		var c := Vector2(sin(a), cos(a)) * sample_radius
		var n: float = noise.get_noise_2d(c.x, c.y) * 0.5 + 0.5
		var ridged: float = 1.0 - absf(noise.get_noise_2d(c.x * 2.7 + 9.0, c.y * 2.7))
		var h: float = clampf(pow(n, 1.6) * 1.25 + ridged * 0.1, 0.0, 1.0)
		# A valley toward the moon, down under the lake's water at its
		# deepest, keeps the moon and the lake in view.
		var valley: float = m.w * smoothstep(0.82, 0.99, cos(angle_difference(a, moon_angle)))
		var r: float = m.x * (1.0 + 0.07 * noise.get_noise_2d(c.x * 0.5 + 40.0, c.y * 0.5))
		tops.append(Vector3(sin(a) * r, lerpf(lerpf(m.y, m.z, h), valley_floor, valley), cos(a) * r))
		bases.append(Vector3(sin(a) * r * 1.02, bottom, cos(a) * r * 1.02))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in segments:
		var u0: float = float(i) / segments
		var u1: float = float(i + 1) / segments
		var v_bot0: float = (bottom - cloud) / maxf(tops[i].y - cloud, 1.0)
		var v_bot1: float = (bottom - cloud) / maxf(tops[i + 1].y - cloud, 1.0)
		_ring_vertex(st, bases[i], Vector2(u0, v_bot0))
		_ring_vertex(st, tops[i], Vector2(u0, 1.0))
		_ring_vertex(st, tops[i + 1], Vector2(u1, 1.0))
		_ring_vertex(st, bases[i], Vector2(u0, v_bot0))
		_ring_vertex(st, tops[i + 1], Vector2(u1, 1.0))
		_ring_vertex(st, bases[i + 1], Vector2(u1, v_bot1))
	return st.commit()


## A ring vertex, its normal facing the centre.
static func _ring_vertex(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_normal(-Vector3(p.x, 0, p.z).normalized())
	st.set_uv(uv)
	st.add_vertex(p)


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
static func _cliffs(layout: ShrineLayout) -> Node3D:
	var node := Node3D.new()
	node.name = "Cliffs"
	var rock := MeshKit.new()
	var falls := MeshKit.new()
	var kits := MeshKitSet.new()
	var noise := FastNoiseLite.new()
	noise.seed = layout.random_stream(&"cliffs").randi()
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var pagodas: RandomNumberGenerator = layout.random_stream(&"pagoda")
	for i: int in layout.cliffs.size():
		var c: Vector4 = layout.cliffs[i]
		var centre: Vector3 = _cliff_centre(layout, i)
		_spire(rock, centre, c.z, c.w, layout.cloud_sea_height - SPIRE_FOOT, noise)
		# The buildings face the shrine.
		var top := Transform3D(Basis(Vector3.UP, deg_to_rad(c.x + 180.0)), centre + Vector3(0, c.z, 0))
		if c.w >= PAGODA_CLIFF:
			_pagoda(node, kits, layout, i, top, 5, c.w * 0.42, pagodas)
		elif c.w >= TEMPLE_CLIFF:
			_temple_hall(node, kits, layout, i, top, c.w * 0.9, c.w * 0.6)
			_pagoda(node, kits, layout, i, top.translated_local(Vector3(c.w * 0.45, 0, c.w * 0.3)), 3, c.w * 0.22, pagodas)
		else:
			_temple_hall(node, kits, layout, i, top, c.w * 0.8, c.w * 0.55)
		if layout.waterfall_cliffs.has(i):
			var lip: Vector3 = _waterfall_lip(layout, i)
			_waterfall(falls, lip, _toward_shrine(layout, i), lip.y - layout.cloud_sea_height + WATERFALL_PLUNGE, c.w * 0.38)
	var spires := MeshKit.instance(rock.commit(), _cliff_rock(), false)
	spires.name = "Spires"
	node.add_child(spires)
	kits.finish(node, ShrineProps.materials(), kits.keys())
	var waterfalls := MeshKit.instance(falls.commit(), _material(WATERFALL, {}), false)
	waterfalls.name = "Waterfalls"
	node.add_child(waterfalls)
	return node


## A pagoda on xform, width wide, or the bought one scaled to width.
static func _pagoda(node: Node3D, kits: MeshKitSet, layout: ShrineLayout, index: int, xform: Transform3D, tiers: int,
		width: float, rng: RandomNumberGenerator) -> void:
	if not layout.place_art(node, &"pagoda", index, xform.scaled_local(Vector3.ONE * width)):
		ShrineProps.pagoda(kits, xform, tiers, width, rng)


## A temple hall on xform, width wide and depth deep, or the bought one
## scaled to width.
static func _temple_hall(node: Node3D, kits: MeshKitSet, layout: ShrineLayout, index: int, xform: Transform3D,
		width: float, depth: float) -> void:
	if not layout.place_art(node, &"temple_hall", index, xform.scaled_local(Vector3.ONE * width)):
		ShrineProps.temple_hall(kits, xform, width, depth)


## The cliffs' rock: the crag's, darker, with broader strata for its size.
static func _cliff_rock() -> ShaderMaterial:
	var mat: ShaderMaterial = ShrineUnderside.rock_material()
	mat.set_shader_parameter(&"rock_light", Color(0.2, 0.2, 0.23))
	mat.set_shader_parameter(&"rock_dark", Color(0.07, 0.07, 0.09))
	mat.set_shader_parameter(&"top_color", Color(0.24, 0.25, 0.28))
	mat.set_shader_parameter(&"strata_scale", 0.12)
	mat.set_shader_parameter(&"noise_scale", 0.08)
	return mat


## A cliff spire: a flat top at top_y, flaring a little toward its base far
## below the clouds, darker toward the base.
static func _spire(kit: MeshKit, centre: Vector3, top_y: float, radius: float, base_y: float, noise: FastNoiseLite) -> void:
	var segments: int = 20
	var levels: int = 16
	var rows: Array[PackedVector3Array] = []
	var colors: Array[PackedColorArray] = []
	for j: int in levels + 2:
		var row := PackedVector3Array()
		var shades := PackedColorArray()
		var shade: float = 1.0 - clampf(float(j) / levels, 0.0, 1.0) * 0.5
		for i: int in segments + 1:
			var a: float = -TAU * (i % segments) / segments
			var dir := Vector3(sin(a), 0, cos(a))
			var p := Vector3(0, top_y, 0)
			if j > 0:
				var t: float = float(j - 1) / levels
				var y: float = lerpf(top_y, base_y, t)
				var r: float = radius * (1.0 + 0.6 * t * t)
				r *= 1.0 + 0.3 * noise.get_noise_3d(centre.x + dir.x * 22.0, y * 0.5, centre.z + dir.z * 22.0) \
					+ 0.12 * noise.get_noise_3d(centre.x + dir.x * 70.0, y * 2.0, centre.z + dir.z * 70.0)
				p = dir * r + Vector3(0, y, 0)
			row.append(centre + p)
			shades.append(Color(shade, shade, shade))
		rows.append(row)
		colors.append(shades)
	kit.grid_surface(Transform3D.IDENTITY, rows, true, colors)


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
