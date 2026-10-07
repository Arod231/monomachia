class_name ShrineLayout
extends Resource
## Where the Moonlit Shrine's pieces go: the numbers the builders read, kept in
## one data file so the arena can be re-dressed without touching code.
##
## Angles are in degrees around the arena centre, measured from +Z toward +X:
## 0 is player two's end (+Z) and 180 is player one's end (-Z), where the
## rules start each side. Player one's camera looks toward +Z, so the moon,
## the lake and the deepest valley sit on that side. Radii are metres from
## the centre; heights are metres above the courtyard floor. The walls,
## spawns and gates come from the ArenaDef, not from here.
##
## Any prop can be swapped for bought art: put a PackedScene in prop_scenes
## under the prop's kind (PROP_KINDS) and the builders instance it at the
## same spots instead of building the procedural one.

## The prop kinds that bought art can replace.
const PROP_KINDS: Array[StringName] = [&"lantern", &"torii", &"pillar", &"wisteria", &"floating_rock",
	&"pagoda", &"temple_hall"]

## Seed for every random choice in the builders; each kind of piece draws
## from a stream of its own (random_stream).
@export var seed: int = 7

@export_group("Courtyard")
## Paving: radius of the round centre stone, width of each ring of tiles, and
## the target tile length along a ring.
@export var centre_radius: float = 2.7
@export var ring_width: float = 1.18
@export var tile_length: float = 1.5
## Flat pebbles along the inside foot of the parapet: the only things built
## inside the walkable circle.
@export var pebble_count: int = 14

@export_group("Parapet")
## Posts around the parapet (gate openings remove some).
@export var post_count: int = 52
## Half-angle of the opening in the parapet at each gate.
@export var gate_opening_deg: float = 7.5
## Rail segments (between post i and i + 1) whose top rail is broken.
@export var broken_rails: PackedInt32Array = PackedInt32Array([7, 18, 33, 45])
## Posts that are cracked short.
@export var damaged_posts: PackedInt32Array = PackedInt32Array([8, 34, 46])

@export_group("Gates")
## The torii stand on the ArenaDef's gate anchors; these set their size. Each
## gate's landing is a little wider than its torii.
@export var torii_height: float = 6.6
@export var torii_span: float = 5.4

@export_group("Props on the ledge")
## Stone lanterns: angles; all stand at lantern_radius.
@export var lantern_angles: PackedFloat32Array = PackedFloat32Array([16, -16, 164, 196, 62, 118, 242, 298])
@export var lantern_radius: float = 17.4
## Pillars: (angle, radius, height, broken 0/1).
@export var pillars: PackedVector4Array = PackedVector4Array([
	Vector4(216, 18.9, 5.2, 0), Vector4(268, 19.4, 3.1, 1), Vector4(321, 18.7, 5.8, 0),
	Vector4(39, 19.1, 2.6, 1), Vector4(90, 18.8, 5.4, 0), Vector4(146, 19.3, 3.4, 1),
])
## The wisteria (milestone-1 task 48, ShrineWisteria): (angle, radius,
## scale, variant 0..4), one of each of the five trees, between the ledge's
## lanterns, pillars and gates, where their canopies keep the moon clear.
@export var trees: PackedVector4Array = PackedVector4Array([
	Vector4(332, 20.6, 1.0, 0), Vector4(75, 20.4, 1.0, 1), Vector4(132, 20.2, 1.0, 2),
	Vector4(229, 20.5, 1.0, 3), Vector4(283, 20.8, 1.0, 4),
])
## Loose rocks scattered on the ledge, clear of the gates.
@export var debris_count: int = 48

@export_group("Underside")
## The crag under the courtyard: the least reach of its top, the ledge, all
## round (bumps push the rim up to 16% further: 22.3 to 23.8 m with this
## seed), and how far below the floor its tip hangs.
@export var crag_radius: float = 21.3
@export var crag_depth: float = 38.0
## Roots hanging from the crag's sides.
@export var root_count: int = 26
## Chains from the crag's sides down into the clouds: angles.
@export var chain_angles: PackedFloat32Array = PackedFloat32Array([210, 330, 35, 150])
## Floating rocks round the shrine: (angle, distance, height, size).
@export var floating_rocks: PackedVector4Array = PackedVector4Array([
	Vector4(250, 34, -6, 3.2), Vector4(298, 46, 4, 2.0), Vector4(20, 38, -14, 4.0),
	Vector4(78, 52, 9, 2.4), Vector4(120, 31, -3, 1.6), Vector4(200, 58, -20, 5.0),
	Vector4(345, 64, 12, 2.8),
])

@export_group("World")
## Direction toward the moon (normalised by the builders): the sky draws the
## moon there, and the red rim light shines from it.
@export var moon_direction: Vector3 = Vector3(0.42, 0.25, 1.0)
## Direction the moonlight comes from (the key light), independent of the
## moon's disc.
@export var key_light_direction: Vector3 = Vector3(-0.95, 1.05, -0.25)
## The night's wind, level (m/s; x and z): the embers and ash drift with it,
## and the sea of clouds drifts its way.
@export var wind: Vector2 = Vector2(-0.55, -0.19)
## The top of the sea of clouds (its veil; the dense sea lies
## ShrineBackdrop.CLOUD_SEA_DEPTH lower), which the chains run down into.
@export var cloud_sea_height: float = -46.0
## Rings of mountains, nearest first: (distance, lowest ridge, highest peak,
## how far the valley toward the moon drops toward its floor under the lake,
## 0 to 1). The rings in front of the lake drop under its water, and every
## ridge stays under the moon.
@export var mountain_layers: PackedVector4Array = PackedVector4Array([
	Vector4(300, -22, 55, 0.95), Vector4(470, -10, 120, 0.95), Vector4(700, 0, 190, 0.6), Vector4(1000, 10, 280, 0.65),
])
## Cliff spires rising out of the clouds: (angle, distance, top height,
## radius). Their buildings go by radius (ShrineBackdrop.PAGODA_CLIFF and
## TEMPLE_CLIFF).
@export var cliffs: PackedVector4Array = PackedVector4Array([
	Vector4(326, 235, 26, 12), Vector4(52, 300, 46, 16), Vector4(90, 215, 16, 12),
	Vector4(132, 275, 34, 15), Vector4(218, 250, 28, 13), Vector4(276, 225, 12, 10),
])
## The cliffs (indices into cliffs) with a waterfall falling into the clouds.
@export var waterfall_cliffs: PackedInt32Array = PackedInt32Array([0, 1, 2])
## The far lake under the moon, showing through a clearing in the clouds:
## (angle, distance, height, radius).
@export var lake: Vector4 = Vector4(20, 640, -60, 420)

@export_group("Art overrides")
## Bought art per prop kind; a kind left out is built procedurally. A
## bought pagoda or temple hall is modelled 1 m wide and scaled to its cliff;
## it stands far off.
@export var prop_scenes: Dictionary[StringName, PackedScene] = {}


## A random stream of its own for one group of pieces, from the seed, so
## bought art in place of one kind leaves the others as they were.
func random_stream(group: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, group])
	return rng


## Instances the bought art for kind under parent at xform, named by kind
## and index (Lantern0, DeadTree2), when prop_scenes has it. Returns whether
## it did, so the builder makes the procedural piece otherwise.
func place_art(parent: Node3D, kind: StringName, index: int, xform: Transform3D) -> bool:
	var scene: PackedScene = prop_scenes.get(kind)
	if scene == null:
		return false
	var node: Node = scene.instantiate()
	if not node is Node3D:
		push_error("ShrineLayout: the %s art isn't a Node3D scene" % kind)
		node.free()
		return false
	node.name = "%s%d" % [String(kind).to_pascal_case(), index]
	(node as Node3D).transform = xform
	parent.add_child(node)
	return true


## Converts an angle (degrees, from +Z toward +X) and a radius to a point.
static func polar(angle_deg: float, radius: float, height: float = 0.0) -> Vector3:
	var a: float = deg_to_rad(angle_deg)
	return Vector3(sin(a) * radius, height, cos(a) * radius)
