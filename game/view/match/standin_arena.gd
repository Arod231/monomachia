extends Node3D
## The stand-in arena until the Moonlit Shrine lands (task 17), in the
## realistic look (milestone-1 task 43): a flat stone floor out to the wall
## at SimConst.ARENA_RADIUS with dark rings on it, a low lacquered wall
## along the wall line, a lower apron outside it so the follow camera never
## looks into the void, and a few pillars for scale. Built in code with
## MeshKit from the rules' radius, so it follows when task 8 changes it.
##
## Like a real arena it brings its own look: the night (LookGrade) under a
## dusk sky, the moon's key light, a warm rim light that touches fighters only
## (LookPalette.FIGHTER_LAYER) and two lantern lights. It applies the chosen
## graphics preset to itself when it loads.
##
## It carries the arena seams the real arena will fill (see ArenaScenes):
## Spawn0, Spawn1, Gate0 and Gate1 markers.

const FLOOR_COLOR: Color = Color("24232a")
const LINE_COLOR: Color = LookPalette.STONE_DARK
const APRON_COLOR: Color = LookPalette.INK
const LACQUER_COLOR: Color = LookPalette.LACQUER
const STONE_COLOR: Color = LookPalette.STONE

## Apron reach past the wall (m): wider than the camera's clamp margin.
@export var apron: float = 5.5
@export var pillar_count: int = 8
## Pillar ring distance past the wall (m).
@export var pillar_offset: float = 1.8
@export var pillar_height: float = 4.5


func _ready() -> void:
	var r: float = SimConst.ARENA_RADIUS
	_build_environment()
	_build_lights(r)
	var kits := MeshKitSet.new()
	_build_floor(kits, r)
	_build_wall(kits.kit(&"lacquer"), r)
	_build_pillars(kits, r)
	var meshes: Array[MeshInstance3D] = kits.finish(self, {
		&"floor": LookMaterials.prop(FLOOR_COLOR),
		&"apron": LookMaterials.prop(APRON_COLOR),
		&"lines": LookMaterials.prop(LINE_COLOR),
		&"lacquer": LookMaterials.prop(LACQUER_COLOR),
		&"stone": LookMaterials.prop(STONE_COLOR),
	}, [&"floor", &"apron", &"lines"])
	for mi: MeshInstance3D in meshes:
		if mi.name in [&"Floor", &"Apron", &"Lines"]:
			mi.layers = LookPalette.GROUND_LAYER
	_build_markers(r)
	GraphicsApplier.apply_to_tree(GameServices.graphics_preset(), self)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.025, 0.03, 0.07)
	sky_mat.sky_horizon_color = Color(0.2, 0.12, 0.17)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.1, 0.07, 0.09)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.015)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var base := Environment.new()
	base.sky = sky
	var env: Environment = LookGrade.environment(base)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)


func _build_lights(r: float) -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.74, 0.82, 1.0)
	moon.light_energy = 1.35
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-50.0, 150.0, 0.0)
	moon.add_to_group(GraphicsApplier.GROUP_SHADOW_LIGHT)
	add_child(moon)

	var rim := DirectionalLight3D.new()
	rim.name = "Rim"
	rim.light_color = Color(0.95, 0.55, 0.4)
	rim.light_energy = 0.35
	rim.light_cull_mask = LookPalette.FIGHTER_LAYER
	rim.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	rim.rotation_degrees = Vector3(-20.0, -30.0, 0.0)
	add_child(rim)

	# Two warm lanterns by the side pillars.
	for side: float in [-1.0, 1.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "Lantern%s" % ("L" if side < 0.0 else "R")
		lamp.light_color = Color(1.0, 0.55, 0.25)
		lamp.light_energy = 2.0
		lamp.omni_range = 9.0
		lamp.light_cull_mask = LookPalette.SMALL_LIGHT_MASK
		lamp.position = Vector3(side * (r + 0.6), 2.2, 0.0)
		lamp.add_to_group(GraphicsApplier.GROUP_MINOR_LIGHT)
		add_child(lamp)


func _build_floor(kits: MeshKitSet, r: float) -> void:
	kits.kit(&"floor").disc(Transform3D.IDENTITY, r, 96, 8)
	# The apron: a ring 15 cm below the floor out to r + apron, then a slope
	# down and in.
	var outer: float = r + apron
	kits.kit(&"apron").lathe(Transform3D.IDENTITY, PackedVector2Array([
		Vector2(outer - 1.5, -1.35), Vector2(outer, -0.15), Vector2(r, -0.15),
	]), 96, false)
	# Dark rings every 3 m and a centre mark, so movement reads against the
	# floor. They sit 4 mm up.
	var lines: MeshKit = kits.kit(&"lines")
	var lift := Transform3D(Basis(), Vector3(0.0, 0.004, 0.0))
	var ring_r: float = 3.0
	while ring_r < r - 0.5:
		lines.disc(lift, ring_r + 0.035, 96, 1, ring_r - 0.035)
		ring_r += 3.0
	lines.disc(lift, 0.25, 24, 1)


## A low wall along the rules' wall line, its inner face at the radius, with a
## bevelled top.
func _build_wall(kit: MeshKit, r: float) -> void:
	kit.lathe(Transform3D.IDENTITY, PackedVector2Array([
		Vector2(r + 0.4, 0.0), Vector2(r + 0.4, 0.5), Vector2(r + 0.3, 0.6),
		Vector2(r + 0.1, 0.6), Vector2(r, 0.5), Vector2(r, 0.0),
	]), 128, false)


func _build_pillars(kits: MeshKitSet, r: float) -> void:
	var stone: MeshKit = kits.kit(&"stone")
	var lacquer: MeshKit = kits.kit(&"lacquer")
	for i: int in pillar_count:
		var a: float = TAU * float(i) / float(pillar_count)
		var at: Vector3 = Vector3(sin(a), 0.0, cos(a)) * (r + pillar_offset)
		stone.cylinder(Transform3D(Basis(), at), 0.4, 0.32, pillar_height, 12)
		var cap := Transform3D(Basis(Vector3.UP, a), at + Vector3(0.0, pillar_height + 0.12, 0.0))
		lacquer.box(cap, Vector3(1.1, 0.25, 1.1))


func _build_markers(r: float) -> void:
	var spots: Dictionary[String, Vector3] = {
		"Spawn0": Vector3(0.0, 0.0, -3.2),
		"Spawn1": Vector3(0.0, 0.0, 3.2),
		"Gate0": Vector3(0.0, 0.0, -(r + 3.0)),
		"Gate1": Vector3(0.0, 0.0, r + 3.0),
	}
	# As in ArenaDef: -Z faces the opponent (spawns) or the centre (gates), so
	# side 0's markers, at -z, turn round to face +Z.
	for key: String in spots:
		var m := Marker3D.new()
		m.name = key
		m.position = spots[key]
		if m.position.z < 0.0:
			m.rotation.y = PI
		add_child(m)
