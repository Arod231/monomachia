class_name ShrineProps
extends RefCounted
## The shrine props' shared pieces: the materials every kit key the platform
## and its props use, the lanterns' fire, and the gates' sacred rope
## barriers, added to a MeshKitSet. The lanterns, torii, pillars, pagodas and
## temple halls are modelled (ShrineBuildings, milestone-1 task 132), the
## wisteria ShrineWisteria's.

const LANTERN_GLOW: Shader = preload("res://shaders/lantern_glow.gdshader")

## A stone lantern's fire, in the lantern's own space: the middle of its
## lit paper box. Bought lanterns keep their fire at the same height, since
## the lights and halos go there.
const LANTERN_FIRE := Vector3(0.0, 2.12, 0.0)
## The gates' rope: its strands and how many times they turn end to end.
const STRANDS: int = 3
const TWISTS: float = 5.0


## Materials for every kit key the platform, its props and the backdrop's
## buildings use: physically based (LookMaterials), the lanterns' glow its
## own.
static func materials() -> Dictionary[StringName, Material]:
	var glow := ShaderMaterial.new()
	glow.shader = LANTERN_GLOW
	# brighter than the shader's own, so the lanterns' paper burns (Oct 7)
	glow.set_shader_parameter(&"energy", 4.2)
	return {
		&"landing": LookMaterials.prop(LookPalette.STONE_LIGHT),
		&"parapet": LookMaterials.prop(LookPalette.STONE),
		&"stone": LookMaterials.prop(LookPalette.STONE_LIGHT),
		&"stone_dark": LookMaterials.prop(LookPalette.STONE_DARK),
		&"pebbles": LookMaterials.prop(LookPalette.STONE_DARK),
		&"lacquer": LookMaterials.prop(LookPalette.LACQUER),
		&"black_lacquer": LookMaterials.prop(LookPalette.INK_SOFT),
		&"rope": LookMaterials.prop(LookPalette.ROPE),
		&"paper": LookMaterials.prop(LookPalette.PAPER),
		&"wood": LookMaterials.prop(LookPalette.WOOD_DARK.lightened(0.05)),
		&"roof": LookMaterials.prop(LookPalette.INK_SOFT.lightened(0.04)),
		&"glow": glow,
		&"window": distant_glow_material(),
	}


## Lit windows and lanterns far away: the lanterns' glow, dimmer and
## steadier.
static func distant_glow_material() -> ShaderMaterial:
	var window := ShaderMaterial.new()
	window.shader = LANTERN_GLOW
	window.set_shader_parameter(&"energy", 2.2)
	window.set_shader_parameter(&"flicker", 0.12)
	return window


## A sacred straw rope (shimenawa) sagging from a to b, with paper streamers:
## STRANDS strands twisted round each other, thickest in the middle, as the
## torii's modelled ones are (milestone-1 task 132).
static func shimenawa(kits: MeshKitSet, a: Vector3, b: Vector3, sag: float, streamers: int, thickness: float) -> void:
	var rope: MeshKit = kits.kit(&"rope")
	var n: int = 40
	var along: Vector3 = (b - a).normalized()
	var side: Vector3 = along.cross(Vector3.UP).normalized()
	var up: Vector3 = side.cross(along)
	for strand: int in STRANDS:
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i: int in n + 1:
			var t: float = float(i) / n
			var r: float = thickness * (1.0 - 0.4 * absf(t * 2.0 - 1.0))
			var turn: float = TAU * (TWISTS * t + float(strand) / STRANDS)
			pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t) + (side * cos(turn) + up * sin(turn)) * r * 0.45)
			radii.append(r * 0.62)
		rope.tube(pts, radii, 6)
	var paper: MeshKit = kits.kit(&"paper")
	var face := Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
	for k: int in streamers:
		var t: float = (k + 1.0) / (streamers + 1.0)
		var top: Vector3 = a.lerp(b, t) + Vector3.DOWN * (sag * 4.0 * t * (1.0 - t) + thickness)
		_streamer(paper, Transform3D(face, top), 0.045)
		rope.box(Transform3D(face, top + Vector3.DOWN * 0.12 + along * 0.11), Vector3(0.025, 0.22, 0.025))


## A zigzag paper streamer (shide) hanging from top, its pieces stepping
## sideways by step along local x.
static func _streamer(paper: MeshKit, top: Transform3D, step: float) -> void:
	for piece: int in 4:
		var off: float = step if piece % 2 == 0 else -step
		paper.box(top * Transform3D(Basis(), Vector3(off, -0.07 - piece * 0.12, 0)), Vector3(0.09, 0.12, 0.012))
