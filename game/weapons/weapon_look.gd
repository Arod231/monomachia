class_name WeaponLook
extends Resource
## What a weapon looks like and how it is held: its model scene, the markers
## the swing and trail code read, and how it sits in the hand. Each weapon's
## look is weapons/<id>/<id>.tres, with `id` equal to its WeaponDef id.
##
## Weapon space, which every weapon scene's root uses:
## - origin: the centre of the main hand's grip, where the hand closes;
## - +Y: along the blade, from the grip toward the tip;
## - +X: toward the cutting edge (the side that leads a cut);
## - +Z: X cross Y, out of the flat of the blade;
## - metres, at the size the weapon has in the game.
##
## Markers, Marker3D children of the scene root, in weapon space:
## - BladeBase: where the cutting part of the blade starts, above the guard;
## - BladeTip: the point;
## - OffHandGrip (two-handed weapons only): the centre of the off hand's
##   grip, below the origin.
##
## A fighter's closed fist (HandGrip.fist()) has the same frame: origin in
## the hollow of the fist, +Y out of the thumb side, +X out of the knuckles.
## A weapon held straight in the fist therefore has its origin in the hollow,
## blade out of the thumb side and edge toward the knuckles. A posed weapon
## (FighterModel.pose_weapon()) puts the main hand on its origin and, for a
## two-handed weapon, the off hand on OffHandGrip.

## The weapons that have a look (WeaponDef ids).
const IDS: Array[StringName] = [&"katana", &"greatsword", &"daggers"]

const BLADE_BASE: StringName = &"BladeBase"
const BLADE_TIP: StringName = &"BladeTip"
const OFF_HAND_GRIP: StringName = &"OffHandGrip"

@export var id: StringName = &""
@export var display_name: String = ""
## The weapon's model, its root in weapon space, with the markers above.
@export var scene: PackedScene
## Held in both hands: the off hand goes to OffHandGrip.
@export var two_handed: bool = false
## One copy in each hand (the daggers).
@export var paired: bool = false
## The handle's radius where the hands close on it, in metres: the fists are
## fitted to it (see HandGrip). An oval handle takes the mean of its two
## half-widths.
@export var grip_radius: float = 0.015
## How the weapon sits in the fist when it is fixed to the hand for a clip
## (FighterModel.fix_weapons()), in the fist's frame: identity holds it
## straight, its origin in the hollow of the fist. The fist itself is
## measured on each fighter's hand (HandGrip.fist()).
@export var grip_offset: Transform3D = Transform3D.IDENTITY


static func path_for(weapon_id: StringName) -> String:
	return "res://weapons/%s/%s.tres" % [weapon_id, weapon_id]


static func load_id(weapon_id: StringName) -> WeaponLook:
	return load(path_for(weapon_id)) as WeaponLook


## Instantiates the model in the toon look: each surface's material (as the
## model was made) becomes a toon weapon material with an ink outline
## (ToonMaterials.weapon_from()), and every mesh goes on the fighters' render
## layer, so the arena's rim light finds it. Each instance gets its own
## materials, so a graphics preset applied to one scene leaves the others
## alone.
func instantiate() -> Node3D:
	var weapon: Node3D = scene.instantiate()
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		mi.layers = 1 | LookPalette.FIGHTER_LAYER
		var toon: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			toon.append(ToonMaterials.weapon_from(mi.mesh.surface_get_material(s)))
			mi.set_surface_override_material(s, toon[s])
		# Held in the node's metadata too: a material only the override holds
		# is freed before the mesh instance lets go of it, which the renderer
		# reports. Metadata outlives the instance.
		mi.set_meta(&"toon_materials", toon)
	return weapon


## A marker of a weapon instance, or null when it has none.
static func marker(weapon: Node, marker_name: StringName) -> Marker3D:
	return weapon.get_node_or_null(NodePath(String(marker_name))) as Marker3D


## The blade's base and tip in weapon space.
static func blade_segment(weapon: Node) -> PackedVector3Array:
	return PackedVector3Array([marker(weapon, BLADE_BASE).position, marker(weapon, BLADE_TIP).position])
