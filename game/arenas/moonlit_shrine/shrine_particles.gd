class_name ShrineParticles
extends RefCounted
## Builds the shrine's drifting particles, under Particles:
## - LanternEmbers0 and on, embers rising from each lantern's fire;
## - EdgeEmbers, embers carried up past the ledge's rim on the updraft;
## - Ash, falling across the courtyard.
## They all drift on the layout's wind, which the sea of clouds drifts with
## too. None has turbulence: Godot's turbulence steers every particle toward
## its noise field each frame, and even at 1% it lost the wind, most of the
## updraft and the ash's fall (the ash flutters in its shader instead).
## Every emitter is in group look_particles, so the presets thin them out
## (GraphicsPreset.particle_ratio); the amounts here are High's.

const GLOW: Shader = preload("res://shaders/particle_glow.gdshader")
const FLAKE: Shader = preload("res://shaders/particle_flake.gdshader")

## Where the updraft's embers start, in metres past ShrineLayout.crag_radius
## (from and to): clear of the rim, whose bumps reach 16% past it.
const UPDRAFT_RING := Vector2(4.0, 8.0)
## How far under the floor the updraft's embers start, and the band's height.
const UPDRAFT_DEPTH := 4.0
const UPDRAFT_BAND := 3.0
## Where the ash starts: the middle of its band (m above the floor), the
## band's half height, and how far past ShrineLayout.crag_radius it reaches
## all round, so the wind blows it over the upwind edge too. It falls at
## ASH_FALL.x to ASH_FALL.y metres per second (see _launch).
const ASH_HEIGHT := 9.5
const ASH_BAND := 1.5
const ASH_REACH := 4.0
const ASH_FALL := Vector2(0.7, 1.1)
## Embers and ash fade out nearer the camera than this (from x to y metres),
## where they would swell into blots over the fighters.
const NEAR_FADE := Vector2(1.0, 4.0)
## Room (m) round the particles' paths in their visibility boxes, for the
## quads themselves.
const QUAD_SLACK := 1.0


## The particles round the shrine laid out by layout, with lanterns burning
## at fires (arena space).
static func build(layout: ShrineLayout, fires: PackedVector3Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Particles"
	var glow := _material(GLOW)
	for i: int in fires.size():
		root.add_child(_lantern_embers(i, fires[i], layout.wind, glow))
	root.add_child(_updraft(layout, glow))
	root.add_child(_ash(layout))
	return root


## Lantern index's embers, rising from its fire and drifting off on the wind.
static func _lantern_embers(index: int, fire: Vector3, wind: Vector2, glow: Material) -> GPUParticles3D:
	var p := _emitter("LanternEmbers%d" % index, 18, 3.5)
	p.position = fire
	p.randomness = 0.6
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.2
	_launch(m, wind, Vector2(0.25, 0.8), 20.0)
	m.gravity = Vector3(0, 0.2, 0)
	m.damping_min = 0.05
	m.damping_max = 0.2
	m.scale_min = 0.08
	m.scale_max = 0.16
	m.color_ramp = _ramp([Color(1.0, 0.75, 0.35, 0.0), Color(1.0, 0.6, 0.25, 1.0), Color(0.95, 0.25, 0.08, 0.8), Color(0.6, 0.1, 0.05, 0.0)])
	_finish(p, m, glow, AABB(-Vector3.ONE * m.emission_sphere_radius, Vector3.ONE * 2.0 * m.emission_sphere_radius))
	return p


## Embers carried up from the open air under the rim, all round the island,
## up past the ledge and off on the wind.
static func _updraft(layout: ShrineLayout, glow: Material) -> GPUParticles3D:
	var p := _emitter("EdgeEmbers", 70, 7.0)
	p.position = Vector3(0, -UPDRAFT_DEPTH, 0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_inner_radius = layout.crag_radius + UPDRAFT_RING.x
	m.emission_ring_radius = layout.crag_radius + UPDRAFT_RING.y
	m.emission_ring_height = UPDRAFT_BAND
	_launch(m, layout.wind, Vector2(0.8, 1.6), 15.0)
	m.gravity = Vector3(0, 0.05, 0)
	m.scale_min = 0.09
	m.scale_max = 0.18
	m.color_ramp = _ramp([Color(1.0, 0.6, 0.25, 0.0), Color(1.0, 0.5, 0.2, 0.9), Color(0.8, 0.2, 0.06, 0.6), Color(0.5, 0.08, 0.04, 0.0)])
	var r: float = m.emission_ring_radius
	_finish(p, m, glow, AABB(Vector3(-r, -UPDRAFT_BAND * 0.5, -r), Vector3(2.0 * r, UPDRAFT_BAND, 2.0 * r)))
	return p


## Pale ash falling with the wind over the whole island.
static func _ash(layout: ShrineLayout) -> GPUParticles3D:
	var p := _emitter("Ash", 260, 16.0)
	p.position = Vector3(0, ASH_HEIGHT, 0)
	var reach: float = layout.crag_radius + ASH_REACH
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(reach, ASH_BAND, reach)
	_launch(m, layout.wind, -ASH_FALL, 12.0)
	m.gravity = Vector3.ZERO
	m.scale_min = 0.06
	m.scale_max = 0.12
	m.color_ramp = _ramp([Color(0.68, 0.66, 0.7, 0.0), Color(0.68, 0.66, 0.7, 0.9), Color(0.5, 0.49, 0.53, 0.85), Color(0.35, 0.35, 0.38, 0.0)])
	_finish(p, m, _material(FLAKE), AABB(-m.emission_box_extents, m.emission_box_extents * 2.0))
	return p


## A new emitter of amount particles that live lifetime seconds, already
## under way when the arena appears, emitting in arena space, casting no
## shadow, and in the group the presets thin out.
static func _emitter(emitter_name: String, amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = emitter_name
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_to_group(GraphicsApplier.GROUP_PARTICLES)
	return p


## A particle material of shader, fading out near the camera.
static func _material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(&"near_fade", NEAR_FADE)
	return mat


## Launches m's particles drifting with the wind (level, m/s) and climbing
## at climb.x to climb.y metres per second (both negative to fall), before
## spread scatters them by up to about spread degrees. Godot gives each
## particle one aim and a speed, so all aim along the middle climb: one at
## the middle speed drifts exactly with the wind, slower ones a little
## slower and faster ones a little faster.
static func _launch(m: ParticleProcessMaterial, wind: Vector2, climb: Vector2, spread: float) -> void:
	var middle := Vector3(wind.x, (climb.x + climb.y) * 0.5, wind.y)
	assert(not is_zero_approx(middle.y), "_launch: particles that neither climb nor fall")
	m.direction = middle.normalized()
	m.initial_velocity_min = climb.x / m.direction.y
	m.initial_velocity_max = climb.y / m.direction.y
	m.spread = spread


## Gives p its motion (m) and its look (a camera-facing quad of material),
## and a visibility box round where its particles set off (start, relative
## to p) grown by as far as any can go in its life.
static func _finish(p: GPUParticles3D, m: ParticleProcessMaterial, material: Material, start: AABB) -> void:
	p.process_material = m
	var quad := QuadMesh.new()
	quad.material = material
	p.draw_pass_1 = quad
	var t: float = p.lifetime
	p.visibility_aabb = start.grow(m.initial_velocity_max * t + 0.5 * m.gravity.length() * t * t + QUAD_SLACK)


## A colour ramp over a particle's life through colors, evenly spaced.
static func _ramp(colors: Array[Color]) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i: int in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
