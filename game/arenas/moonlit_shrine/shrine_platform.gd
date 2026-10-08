class_name ShrinePlatform
extends RefCounted
## Builds the Moonlit Shrine's courtyard and the props round it: the paved
## floor and its stone edge, the parapet that stops fighters, a landing at
## each gate with steps down and a torii on it, each gate's rope barrier,
## flat pebbles along the foot of the parapet, and on the ledge outside the
## stone lanterns with their lights and halos, the roped pillars, the trees,
## the banners (ShrineBanners) and loose rocks. Everything stands outside the
## walkable circle except the floor, the pebbles and the short grass in the
## paving's joints (ShrineGrass). The lanterns, the torii and the pillars are
## the modelled ones (ShrineBuildings, milestone-1 task 132), at the same
## spots.
##
## The platform itself is modelled too (milestone-1 task 50): the paving's
## slabs, the curb stones round its rim (Plinth), the parapet (Props/Parapet)
## and the gates' landings and steps (Props/Landing) are one export,
## ShrineBuildings' platform model, built in Blender from model_spec(), the
## layout's and the arena data's own numbers. The slabs lie where the
## floor's shader draws its joints (its joints unwobbled), tilted and sunk by
## up to MAX_DROP under the rules' flat floor at y = 0 and never above it, so
## feet neither sink into nor float visibly over them; the shader paints them
## (scan, wear, cracks, grime); a bed of grit shows in the joints and where a
## corner has broken off. The parapet keeps today's design at its footprint
## and height (the posts, caps and finials, the two rails, the broken rails
## and damaged posts at layout.broken_rails and damaged_posts), carved and
## worn, in the stone scans with moss on its tops.
##
## Each gate's rope barrier is its own node (GateRope0, GateRope1, by gate
## index), so the match intro can drop it while a fighter walks in. A prop
## kind with a scene in ShrineLayout.prop_scenes is instanced at the same
## spots (Platform/Props/Lantern0 and so on, by ShrineLayout.place_art)
## instead of being built.

const STONE_FLOOR: Shader = preload("res://shaders/stone_floor.gdshader")
## The paving's scans (milestone-1 task 49; paving_maps()).
const PAVING: String = "res://assets/exports/shrine/paving.glb"
## The share of the paving's slabs chipped at their edges and corners, and
## how far (m) the moss and grime spread onto the stone from a joint
## (milestone-1 task 49).
const BROKEN_SLABS: float = 0.05
const GRIME_SPREAD: float = 0.02
## The modelled platform (milestone-1 task 50): how far a slab's top sinks
## at most under the rules' floor, the share of slabs with a corner broken
## off, how deep their edges chip, the curb's height and the model's seed.
const MAX_DROP: float = 0.015
const BROKEN_CORNERS: float = 0.06
const SLAB_CHIP: float = 0.014
const CURB_HEIGHT: float = 0.17
const MODEL_SEED: int = 50
## How far the landings reach out from a gate (m, along the gate's outward
## axis).
const LANDING_FAR: float = 3.0
const HALO: Shader = preload("res://shaders/particle_glow.gdshader")

## Ledge height: the rock shelf around the courtyard (task 17.5), just below
## the floor. The plinth and the gate steps reach down to it, and the
## lanterns, pillars, trees and rocks stand on it.
const LEDGE_Y := -0.3
## A lantern light's brightness, which MoonlitShrine flickers around, and
## the colour of its light and halo.
const LANTERN_ENERGY := 8.0
const FIRE_COLOR := Color(1.0, 0.54, 0.24)
## Half the width of a parapet post, and how much wider the posts beside a
## gate opening are.
const POST_HALF := 0.16
const END_POST_WIDEN := 1.3

const NO_SHADOW: Array[StringName] = [&"paper", &"pebbles", &"glow"]


## Builds the platform under a new Node3D named Platform.
static func build(layout: ShrineLayout, def: ArenaDef) -> Node3D:
	for kind: StringName in layout.prop_scenes:
		if not ShrineLayout.PROP_KINDS.has(kind):
			push_error("ShrinePlatform: bought art under %s, which isn't a prop kind (ShrineLayout.PROP_KINDS)" % kind)
	var root := Node3D.new()
	root.name = "Platform"
	var mats: Dictionary[StringName, Material] = ShrineProps.materials()
	var kits := MeshKitSet.new()
	var buildings := ShrineBuildings.new()
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	_platform(buildings, root, props, layout, def)
	_gates(buildings, root, props, layout, def, mats)
	_pebbles(kits, layout, def)
	_lanterns(buildings, root, props, layout)
	_pillars(buildings, props, layout)
	root.add_child(ShrineWisteria.build(layout, props))
	root.add_child(ShrineBanners.build(layout))
	root.add_child(ShrineGrass.build(layout, def))
	_debris(kits, layout, def)
	kits.finish(props, mats, NO_SHADOW)
	return root


## Where each stone lantern stands on the ledge, by layout.lantern_angles.
static func _lantern_spots(layout: ShrineLayout) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for angle: float in layout.lantern_angles:
		out.append(Transform3D(Basis(Vector3.UP, deg_to_rad(angle)), ShrineLayout.polar(angle, layout.lantern_radius, LEDGE_Y)))
	return out


## Each lantern's fire (arena space), where its light, halo and embers go.
static func fire_points(layout: ShrineLayout) -> PackedVector3Array:
	var out := PackedVector3Array()
	for spot: Transform3D in _lantern_spots(layout):
		out.append(spot * ShrineProps.LANTERN_FIRE)
	return out


## The modelled platform: the paving (Floor, on the ground layer: the slabs
## in the floor's shader, the bed of grit in its scan), the curb stones round
## its rim (Plinth), the parapet and the gates' landings (Props/Parapet and
## Props/Landing).
static func _platform(buildings: ShrineBuildings, root: Node3D, props: Node3D, layout: ShrineLayout, def: ArenaDef) -> void:
	var params: Dictionary = {
		&"centre_radius": layout.centre_radius,
		&"ring_width": layout.ring_width,
		&"tile_length": layout.tile_length,
		&"wall_radius": def.wall_inner_radius(),
		&"joint_wobble": 0.0,
	}
	params.merge(paving_maps())
	var mat: ShaderMaterial = LookMaterials.make_with_shader(STONE_FLOOR, LookMaterials.Surface.PROP, params)
	var floor_mi: MeshInstance3D = buildings.platform("Platform_Floor", "Floor")
	floor_mi.set_surface_override_material(0, mat)
	floor_mi.layers = LookPalette.GROUND_LAYER
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(floor_mi)
	root.add_child(buildings.platform("Platform_Plinth", "Plinth"))
	props.add_child(buildings.platform("Platform_Parapet", "Parapet"))
	props.add_child(buildings.platform("Platform_Landing", "Landing"))


## The paving's scans for the floor's shader (milestone-1 task 49): the
## paving export's two cards, Paving_Stone (Poly Haven's rock_surface) and
## Paving_Grime (concrete_moss), each material's maps as the shader's
## parameters, with use_scans on.
static func paving_maps() -> Dictionary:
	var model: Node = (load(PAVING) as PackedScene).instantiate()
	var stone := model.find_child("Paving_Stone", true, false) as MeshInstance3D
	var grime := model.find_child("Paving_Grime", true, false) as MeshInstance3D
	var s := stone.mesh.surface_get_material(0) as BaseMaterial3D
	var g := grime.mesh.surface_get_material(0) as BaseMaterial3D
	model.free()
	return {
		&"use_scans": true,
		&"stone_albedo": s.albedo_texture,
		&"stone_normal": s.normal_texture,
		&"stone_rough": s.roughness_texture,
		&"grime_albedo": g.albedo_texture,
		&"grime_normal": g.normal_texture,
		&"broken_amount": BROKEN_SLABS,
		&"grime_spread": GRIME_SPREAD,
	}


## The numbers the platform's model is built from (milestone-1 task 50):
## game/tools/export_platform_spec.gd writes them to the build's
## scripts/blender/shrine/platform.json, and test_shrine_platform.gd holds
## that file to them. The floor's rings with their slabs and turns as the
## floor's shader lays them (ring_turn()), the parapet's posts and rails
## (the gates' end posts, the damaged posts and broken rails), and each
## gate's landing in the gate's frame (its local +z outward).
static func model_spec(layout: ShrineLayout, def: ArenaDef) -> Dictionary:
	var rings: Array = []
	var ri: int = 0
	while layout.centre_radius + ri * layout.ring_width < def.floor_radius - 0.01:
		var inner: float = layout.centre_radius + ri * layout.ring_width
		var rmid: float = inner + layout.ring_width * 0.5
		rings.append({
			"index": ri,
			"inner": inner,
			"outer": minf(inner + layout.ring_width, def.floor_radius),
			"tiles": maxi(8, floori(TAU * rmid / layout.tile_length)),
			"offset": ring_turn(ri),
		})
		ri += 1
	var n: int = layout.post_count
	var posts: Array = []
	var rails: Array = []
	for i: int in n:
		if post_in_gate(layout, def, i):
			continue
		posts.append({
			"index": i,
			"angle": post_angle(layout, i),
			"end": post_in_gate(layout, def, (i + 1) % n) or post_in_gate(layout, def, (i - 1 + n) % n),
			"damaged": layout.damaged_posts.has(i),
		})
		if not post_in_gate(layout, def, (i + 1) % n):
			rails.append({
				"index": i,
				"from": post_angle(layout, i),
				"to": post_angle(layout, i) + 360.0 / n,
				"broken": layout.broken_rails.has(i),
			})
	var gates: Array = []
	var angles: PackedFloat32Array = gate_angles(def)
	for side: int in def.gate_anchors.size():
		var xform: Transform3D = def.gate_anchor(side)
		var gate_r: float = Vector2(xform.origin.x, xform.origin.z).length()
		gates.append({
			"angle": angles[side],
			"origin": [xform.origin.x, xform.origin.y, xform.origin.z],
			"x": [xform.basis.x.x, xform.basis.x.y, xform.basis.x.z],
			"z": [xform.basis.z.x, xform.basis.z.y, xform.basis.z.z],
			"near_z": def.floor_radius - 0.3 - gate_r,
			"floor_edge_z": def.floor_radius - gate_r,
			"far_z": LANDING_FAR,
			"width": layout.torii_span + 1.4,
		})
	return {
		"seed": MODEL_SEED,
		"ledge_y": LEDGE_Y,
		"floor": {
			"floor_radius": def.floor_radius,
			"centre_radius": layout.centre_radius,
			"max_drop": MAX_DROP,
			"broken_corners": BROKEN_CORNERS,
			"chip": SLAB_CHIP,
			"rings": rings,
		},
		"wall": {
			"radius": def.wall_radius,
			"thickness": def.wall_thickness,
			"height": def.wall_height,
			"curb_height": CURB_HEIGHT,
			"post_half": POST_HALF,
			"end_post_widen": END_POST_WIDEN,
			"gate_opening": layout.gate_opening_deg,
		},
		"posts": posts,
		"rails": rails,
		"gates": gates,
	}


## How far ring ri of the paving is turned (a share of a turn), as
## stone_floor.gdshader turns it.
static func ring_turn(ri: int) -> float:
	return fposmod(ri * 0.618034, 1.0)


## Angle of parapet post i, in degrees.
static func post_angle(layout: ShrineLayout, i: int) -> float:
	return (i + 0.5) * 360.0 / layout.post_count


## Angle (degrees, from +Z toward +X) of each gate anchor in def.
static func gate_angles(def: ArenaDef) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for g: Transform3D in def.gate_anchors:
		out.append(rad_to_deg(atan2(g.origin.x, g.origin.z)))
	return out


## How far apart two angles are (degrees, 0 to 180).
static func _angle_apart(a: float, b: float) -> float:
	return absf(wrapf(a - b, -180.0, 180.0))


## Whether angle a (degrees) is within margin degrees of a gate.
static func near_gate(a: float, def: ArenaDef, margin: float) -> bool:
	for g: float in gate_angles(def):
		if _angle_apart(a, g) < margin:
			return true
	return false


## Whether post i is left out to open the parapet at a gate.
static func post_in_gate(layout: ShrineLayout, def: ArenaDef, i: int) -> bool:
	return near_gate(post_angle(layout, i), def, layout.gate_opening_deg)


## Centres of every parapet post (arena space), for the tests.
static func post_positions(layout: ShrineLayout, def: ArenaDef) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i: int in layout.post_count:
		if not post_in_gate(layout, def, i):
			out.append(ShrineLayout.polar(post_angle(layout, i), def.wall_radius))
	return out


## The torii standing on each gate's landing (the landing itself is the
## platform model's), and the gate's rope barrier.
static func _gates(buildings: ShrineBuildings, root: Node3D, props: Node3D, layout: ShrineLayout,
		def: ArenaDef, mats: Dictionary[StringName, Material]) -> void:
	var span_angle: float = _gate_end_angle(layout, def)
	var angles: PackedFloat32Array = gate_angles(def)
	for side: int in def.gate_anchors.size():
		# The anchor stands at the gate, facing into the arena: its local +z
		# points outward.
		var xform: Transform3D = def.gate_anchor(side)
		var angle: float = angles[side]
		if not layout.place_art(props, &"torii", side, xform):
			props.add_child(buildings.torii(side, xform, layout.torii_height, layout.torii_span))
		# A rope barrier across the parapet opening, tied to the outer faces of
		# the end posts so its sag stays outside the walkable circle.
		var rope_r: float = def.wall_radius + def.wall_thickness * 0.3
		var a: Vector3 = ShrineLayout.polar(angle - span_angle, rope_r, def.wall_height + 0.1)
		var b: Vector3 = ShrineLayout.polar(angle + span_angle, rope_r, def.wall_height + 0.1)
		var rope_kits := MeshKitSet.new()
		ShrineProps.shimenawa(rope_kits, a, b, 0.32, 5, 0.085)
		var rope := Node3D.new()
		rope.name = "GateRope%d" % side
		root.add_child(rope)
		rope_kits.finish(rope, mats, NO_SHADOW)


## Angle of the gate end posts from the gate axis.
static func _gate_end_angle(layout: ShrineLayout, def: ArenaDef) -> float:
	var gate: float = gate_angles(def)[0]
	var best: float = 180.0
	for i: int in layout.post_count:
		if not post_in_gate(layout, def, i):
			best = minf(best, _angle_apart(post_angle(layout, i), gate))
	return best


## Flat pebbles along the inside foot of the parapet, clear of the gates:
## the only things inside the walkable circle, and never in the way.
static func _pebbles(kits: MeshKitSet, layout: ShrineLayout, def: ArenaDef) -> void:
	_scatter_rocks(kits.kit(&"pebbles"), def, layout.random_stream(&"pebbles"), layout.pebble_count,
		Vector2(def.walkable_radius - 0.5, def.wall_inner_radius() - 0.05), Vector2(0.04, 0.08), 0.0)


## Loose rocks on the ledge, between the plinth and the crag's edge, clear of
## the gates.
static func _debris(kits: MeshKitSet, layout: ShrineLayout, def: ArenaDef) -> void:
	_scatter_rocks(kits.kit(&"stone_dark"), def, layout.random_stream(&"debris"), layout.debris_count,
		Vector2(def.floor_radius + 0.3, layout.crag_radius - 1.2), Vector2(0.08, 0.32), LEDGE_Y)


## Scatters count lumpy rocks into kit, lying at height y, between radii.x and
## radii.y from the centre and more than 12 degrees from a gate, each between
## sizes.x and sizes.y across.
static func _scatter_rocks(kit: MeshKit, def: ArenaDef, rng: RandomNumberGenerator, count: int,
		radii: Vector2, sizes: Vector2, y: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 3.0
	for i: int in count:
		var a: float = rng.randf_range(0.0, 360.0)
		while near_gate(a, def, 12.0):
			a = rng.randf_range(0.0, 360.0)
		var r: float = rng.randf_range(radii.x, radii.y)
		var size: float = rng.randf_range(sizes.x, sizes.y)
		kit.color = Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.3))
		var b := Basis(Vector3(rng.randf(), 1.0, rng.randf()).normalized(), rng.randf_range(0, TAU)) \
			.scaled(Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.45, 0.8), rng.randf_range(0.8, 1.3)))
		kit.sphere(Transform3D(b, ShrineLayout.polar(a, r, y + size * 0.25)), size, 7, 4, noise, size * 0.35)


## The stone lanterns on the ledge, and a light and a halo at each fire.
static func _lanterns(buildings: ShrineBuildings, root: Node3D, props: Node3D, layout: ShrineLayout) -> void:
	var rng: RandomNumberGenerator = layout.random_stream(&"lantern")
	var spots: Array[Transform3D] = _lantern_spots(layout)
	for i: int in spots.size():
		var phase: float = rng.randf()
		if not layout.place_art(props, &"lantern", i, spots[i]):
			props.add_child(buildings.lantern(i, spots[i], phase))
	var fires: PackedVector3Array = fire_points(layout)
	var lights := Node3D.new()
	lights.name = "LanternLights"
	root.add_child(lights)
	for i: int in fires.size():
		var light := _lantern_light(fires[i])
		light.name = "Lantern%d" % i
		lights.add_child(light)
	root.add_child(_lantern_halos(fires))


## A warm lantern light that lights the fighters and the props but skips the
## ground (LookPalette.SMALL_LIGHT_MASK), shown or hidden by the preset: an
## ember casting shadows and glowing in the mist, as the look test settled it
## (milestone-1 task 43).
static func _lantern_light(fire: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = fire
	light.light_color = LookPalette.LANTERN_EMBER
	light.light_energy = LANTERN_ENERGY
	light.light_volumetric_fog_energy = 2.0
	light.omni_range = 9.5
	light.omni_attenuation = 1.1
	light.shadow_enabled = true
	light.shadow_caster_mask = LookPalette.SHADOW_CASTERS
	# a soft-edged flame: the posts' and fighters' shadows fall into the
	# courtyard (the owner's word, Oct 7)
	light.light_size = 0.12
	light.light_specular = 0.0
	# a natural light source (the owner's word, Oct 7): it lights the ground
	# round its lantern too
	light.add_to_group(GraphicsApplier.GROUP_MINOR_LIGHT)
	return light


## Soft additive halos round the lantern fires: the warm glow without the
## cost of a bloom pass, on every preset.
static func _lantern_halos(fires: PackedVector3Array) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	for p: Vector3 in fires:
		transforms.append(Transform3D(Basis().scaled(Vector3.ONE * 2.6), p))
		colors.append(Color(FIRE_COLOR, 0.36))
	var mat := ShaderMaterial.new()
	mat.shader = HALO
	mat.set_shader_parameter(&"energy", 2.0)
	mat.set_shader_parameter(&"toward_camera", 0.75)
	var halos := MeshKit.multimesh(QuadMesh.new(), transforms, mat, colors)
	halos.name = "LanternHalos"
	halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halos


## The pillars on the ledge, each turned at random.
static func _pillars(buildings: ShrineBuildings, props: Node3D, layout: ShrineLayout) -> void:
	var rng: RandomNumberGenerator = layout.random_stream(&"pillar")
	for i: int in layout.pillars.size():
		var p: Vector4 = layout.pillars[i]
		var xform := Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), ShrineLayout.polar(p.x, p.y, LEDGE_Y))
		if not layout.place_art(props, &"pillar", i, xform):
			props.add_child(buildings.pillar(i, xform, p.z, p.w > 0.5))
