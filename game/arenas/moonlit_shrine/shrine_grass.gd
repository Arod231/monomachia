class_name ShrineGrass
extends RefCounted
## The Shrine's grass (milestone-1 task 131; spec story 152): short tufts
## growing in the paving's breaks across the whole floor, the walkable circle
## included, thicker toward the parapet and on the ledge (the owner's
## answers, Oct 7). Picture only: no collision, and on the floor too short
## to hide a fighter's feet (FLOOR_HEIGHT). The tufts are the project's own,
## blade cards built in Blender by scripts/blender/build_banners_grass.py
## (MODEL: Tuft0..3, coloured by their vertex colour, its alpha the sway's
## weight), swaying on the arena's one wind (LookMaterials.sway()).
##
## On the floor they grow along the paving's ring joints (the stone floor
## shader's rings: ShrineLayout.centre_radius, then every ring_width, out to
## the parapet), FLOOR_DENSITY tufts a metre of joint at the centre rising to
## WALL_DENSITY at the parapet, and in a band along the parapet's foot; on
## the ledge they are scattered over the rock (LEDGE_COUNT), taller. One
## MultiMeshInstance3D per tuft, in a node named Grass.

const MODEL: String = "res://assets/exports/shrine/grass.glb"
const VARIANTS: int = 4
## Tufts per metre of joint at the centre and at the parapet, and from how
## far out the grass thickens.
const FLOOR_DENSITY: float = 1.2
const WALL_DENSITY: float = 8.0
const THICKEN_FROM: float = 9.0
## Tufts along the parapet's foot, per metre.
const WALL_FOOT_DENSITY: float = 10.0
## Tufts scattered on the ledge, and how much taller they grow there.
const LEDGE_COUNT: int = 2500
const LEDGE_SCALE: Vector2 = Vector2(1.2, 2.2)
## The tallest a tuft on the floor may stand (m): below the ankle.
const FLOOR_HEIGHT: float = 0.12
## How much wider than tall a clump spreads (its tufts' blades fanned out).
const SPREAD: Vector2 = Vector2(1.0, 1.8)
## How far a tuft's tips lean in a wind of 1 (m).
const SWAY: float = 0.06
## How far the fight's pushes bend it (steps, low swings, falls, blows), as a
## share of a wind as strong (milestone-1 task 115).
const AIR: float = 0.6


## The grass under a new Node3D named Grass.
static func build(layout: ShrineLayout, def: ArenaDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Grass"
	var model: Node = (load(MODEL) as PackedScene).instantiate()
	var meshes: Array[Mesh] = []
	var material: Material = null
	for v: int in VARIANTS:
		var mi: MeshInstance3D = model.find_child("Tuft%d" % v, true, false)
		if mi == null:
			push_error("ShrineGrass: %s lacks Tuft%d" % [MODEL, v])
			continue
		meshes.append(mi.mesh)
		if material == null:
			material = LookMaterials.sway(mi.mesh.surface_get_material(0) as BaseMaterial3D, SWAY, 0.0, false, AIR)
	model.free()
	if meshes.is_empty():
		return root
	var spots: Array[Array] = []
	for v: int in meshes.size():
		spots.append([])
	var all: Array[Transform3D] = placements(layout, def)
	for k: int in all.size():
		(spots[k % meshes.size()] as Array).append(all[k])
	for v: int in meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[v]
		mm.instance_count = (spots[v] as Array).size()
		for k: int in mm.instance_count:
			mm.set_instance_transform(k, spots[v][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Tufts%d" % v
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root


## Where every tuft grows: on the floor's ring joints and along the
## parapet's foot (y 0, scaled to stay under FLOOR_HEIGHT), and scattered on
## the ledge (taller). Seeded from the layout, so every build is the same.
static func placements(layout: ShrineLayout, def: ArenaDef) -> Array[Transform3D]:
	var rng: RandomNumberGenerator = layout.random_stream(&"grass")
	var out: Array[Transform3D] = []
	var wall: float = def.wall_inner_radius()
	# the ring joints
	var r: float = layout.centre_radius
	while r < wall - 0.2:
		var along: float = TAU * r
		var density: float = lerpf(FLOOR_DENSITY, WALL_DENSITY, smoothstep(THICKEN_FROM, wall, r))
		var count: int = int(along * density)
		for k: int in count:
			var a: float = rng.randf() * 360.0
			out.append(_tuft(rng, ShrineLayout.polar(a, r + rng.randf_range(-0.02, 0.02)), Vector2(0.6, 1.0)))
		r += layout.ring_width
	# the parapet's foot
	var foot: int = int(TAU * wall * WALL_FOOT_DENSITY)
	for k: int in foot:
		out.append(_tuft(rng, ShrineLayout.polar(rng.randf() * 360.0, wall - rng.randf_range(0.05, 0.3)), Vector2(0.7, 1.0)))
	# the ledge
	for k: int in LEDGE_COUNT:
		var lr: float = lerpf(def.floor_radius + 0.4, layout.crag_radius - 0.3, sqrt(rng.randf()))
		out.append(_tuft(rng, ShrineLayout.polar(rng.randf() * 360.0, lr, ShrinePlatform.LEDGE_Y), LEDGE_SCALE))
	return out


static func _tuft(rng: RandomNumberGenerator, at: Vector3, scale: Vector2) -> Transform3D:
	var s: float = rng.randf_range(scale.x, scale.y)
	var wide: float = s * rng.randf_range(SPREAD.x, SPREAD.y)
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, s, wide)), at)
