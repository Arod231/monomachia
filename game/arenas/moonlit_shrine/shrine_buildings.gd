class_name ShrineBuildings
extends RefCounted
## The Shrine's buildings, remodelled in place (milestone-1 task 132): the
## stone lanterns, the torii with their shimenawa, the pillars, and the far
## pagodas and temple halls. The project's own art, built and weathered in
## Blender by scripts/blender/build_shrine_buildings.py and brought in by the
## export, one model a kind (MODELS); the builders place them at today's
## spots (ShrineLayout), and bought art in ShrineLayout.prop_scenes still
## stands in for any kind.
##
## Every piece is ancient (the owner's answers, Oct 8): the stone chipped and
## cracked, moss and lichen in its crevices and on its tops (Poly Haven's
## rock_surface and mossy_rock, baked onto each model), the vermilion lacquer
## chipped to the grey wood (over wood_peeling_paint_weathered), frayed straw
## rope, the broken pillars still broken; the far buildings in grey tiles
## and weathered timber (grey_roof_tiles, weathered_planks). Their surfaces
## become the look's physically based ones (LookMaterials.prop_from(), each
## model's own maps); the lanterns' paper and the far windows glow
## (ShrineProps' glow materials).
##
## - Lanterns: Kasuga-doro, LANTERN_VARIANTS of them weathered apart, taken in
##   turn; Lantern<n>_Stone and Lantern<n>_Paper (round the fire, at
##   ShrineProps.LANTERN_FIRE), each lantern's paper flickering at its own
##   phase.
## - Torii: Torii_Wood (pillars, beams, strut and plaque), Torii_Rope (the
##   shimenawa under the tie beam) and Torii_Paper (its shide), modelled
##   TORII_SPAN wide and TORII_HEIGHT tall, and scaled to the layout's.
## - Pillars: PillarWhole_Stone (with its rope and shide) modelled
##   WHOLE_HEIGHT tall, PillarBroken_Stone (snapped, its drum fallen beside
##   it) BROKEN_HEIGHT, each scaled to its layout height.
## - The far buildings: Pagoda and TempleHall with their _Window, modelled
##   1 m wide (ShrineLayout's convention for far art), scaled to their cliffs,
##   casting no shadow like the rest of the backdrop; their spires' bronze is
##   a plain colour.

const MODELS: Dictionary[StringName, String] = {
	&"lantern": "res://assets/exports/shrine/lantern.glb",
	&"torii": "res://assets/exports/shrine/torii.glb",
	&"pillar": "res://assets/exports/shrine/pillar.glb",
	&"pagoda": "res://assets/exports/shrine/pagoda.glb",
	&"temple_hall": "res://assets/exports/shrine/temple_hall.glb",
}
const LANTERN_VARIANTS: int = 2
const TORII_HEIGHT: float = 6.6
const TORII_SPAN: float = 5.4
const WHOLE_HEIGHT: float = 5.5
const BROKEN_HEIGHT: float = 3.0

## Each model's meshes, loaded once a build: kind -> {node name -> [mesh,
## its surfaces' materials]}.
var _parts: Dictionary[StringName, Dictionary] = {}
var _glow: Material
var _window: Material


func _init() -> void:
	var mats: Dictionary[StringName, Material] = ShrineProps.materials()
	_glow = mats[&"glow"]
	_window = mats[&"window"]


## A stone lantern (variant index % LANTERN_VARIANTS) standing on xform,
## named Lantern<index>, its paper flickering at phase (0..1).
func lantern(index: int, xform: Transform3D, phase: float) -> Node3D:
	var v: int = posmod(index, LANTERN_VARIANTS)
	var root := _piece("Lantern%d" % index, xform)
	_add(root, &"lantern", "Lantern%d_Stone" % v, "Stone")
	var paper: MeshInstance3D = _add(root, &"lantern", "Lantern%d_Paper" % v, "Paper", _glow)
	paper.set_instance_shader_parameter(&"phase_offset", phase)
	return root


## A torii on xform (its passage along local z), height tall with its
## pillars span apart, named Torii<index>.
func torii(index: int, xform: Transform3D, height: float, span: float) -> Node3D:
	var root := _piece("Torii%d" % index, xform.scaled_local(Vector3(span / TORII_SPAN, height / TORII_HEIGHT, 1.0)))
	_add(root, &"torii", "Torii_Wood", "Wood")
	_add(root, &"torii", "Torii_Rope", "Rope")
	_add(root, &"torii", "Torii_Paper", "Paper")
	return root


## A pillar on xform, height tall, whole or broken, named Pillar<index>.
func pillar(index: int, xform: Transform3D, height: float, broken: bool) -> Node3D:
	var modelled: float = BROKEN_HEIGHT if broken else WHOLE_HEIGHT
	var root := _piece("Pillar%d" % index, xform.scaled_local(Vector3(1.0, height / modelled, 1.0)))
	if broken:
		_add(root, &"pillar", "PillarBroken_Stone", "Stone")
	else:
		_add(root, &"pillar", "PillarWhole_Stone", "Stone")
		_add(root, &"pillar", "PillarWhole_Rope", "Rope")
		_add(root, &"pillar", "PillarWhole_Paper", "Paper")
	return root


## A far pagoda on xform, width wide, named Pagoda<index>.
func pagoda(index: int, xform: Transform3D, width: float) -> Node3D:
	return _far(&"pagoda", "Pagoda", index, xform, width)


## A far temple hall on xform, width wide, named TempleHall<index>.
func temple_hall(index: int, xform: Transform3D, width: float) -> Node3D:
	return _far(&"temple_hall", "TempleHall", index, xform, width)


## Far scenery stays cheap: it casts no shadow.
func _far(kind: StringName, model_name: String, index: int, xform: Transform3D, width: float) -> Node3D:
	var root := _piece("%s%d" % [model_name, index], xform.scaled_local(Vector3.ONE * width))
	_add(root, kind, model_name, "Body").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, kind, model_name + "_Window", "Window", _window)
	return root


func _piece(piece_name: String, xform: Transform3D) -> Node3D:
	var root := Node3D.new()
	root.name = piece_name
	root.transform = xform
	return root


## A MeshInstance3D named child_name under root of kind's mesh node_name, in
## its look materials, or all in `override` (a glow, which casts no shadow).
func _add(root: Node3D, kind: StringName, node_name: String, child_name: String, override: Material = null) -> MeshInstance3D:
	var part: Array = _part(kind, node_name)
	var mi := MeshInstance3D.new()
	mi.name = child_name
	mi.mesh = part[0]
	if override != null:
		mi.material_override = override
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var mats: Array = part[1]
		for s: int in mats.size():
			mi.set_surface_override_material(s, mats[s])
	root.add_child(mi)
	return mi


## [mesh, materials] of kind's mesh node_name, loading the model the first
## time.
func _part(kind: StringName, node_name: String) -> Array:
	if not _parts.has(kind):
		var found: Dictionary = {}
		var model: Node = (load(MODELS[kind]) as PackedScene).instantiate()
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var mats: Array[Material] = []
			for s: int in mi.mesh.get_surface_count():
				var source: Material = mi.mesh.surface_get_material(s)
				mats.append(LookMaterials.prop_from(source) if source is BaseMaterial3D else source)
			found[String(mi.name)] = [mi.mesh, mats]
		model.free()
		_parts[kind] = found
	var parts: Dictionary = _parts[kind]
	assert(parts.has(node_name), "ShrineBuildings: %s lacks %s" % [MODELS[kind], node_name])
	return parts[node_name]
