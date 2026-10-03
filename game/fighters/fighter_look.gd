class_name FighterLook
extends Resource
## What a fighter looks like: the parts FighterModel assembles into a rigged
## model, the two palettes, and the clips that carry the fighter's
## personality. A fighter's scene (fighters/<id>/<id>.tscn) is a FighterModel
## pointing at its look.
##
## All parts share the Quaternius 65-bone skeleton, retargeted to Godot's
## humanoid profile at import. The fighter's skeleton is the first outfit
## part's: outfits and hair were modelled on it, so they fit it exactly. The
## base body only supplies the head (cut at import by tools/cut_heads.gd),
## the eyes and the eyebrows, which ride on the Head and Neck bones.
##
## Headwear the packs lack is built in code by tools/build_headwear.gd: a
## cloth wrap made from the head (skinned like it) and a hat on the Head bone.
## The skin is roughed up by tools/bake_skins.gd from the skin settings.

## The fighters that have a look, in character-select order. Fighter `id`'s
## look is fighters/<id>/<id>.tres and its scene fighters/<id>/<id>.tscn.
const IDS: Array[StringName] = [&"rogue", &"hunter"]

@export var id: StringName = &""
@export var display_name: String = ""
## The full Quaternius base body (.gltf). Its body mesh is replaced by
## `head_mesh`; its eyes and eyebrows are kept.
@export var body_scene: PackedScene
## The head-only cut of the body mesh, made by tools/cut_heads.gd.
@export var head_mesh: ArrayMesh
## Outfit parts (.gltf), each a skinned mesh on the shared skeleton. The
## first one supplies the fighter's skeleton.
@export var outfit_parts: Array[PackedScene] = []
## Hairstyles and beards (.gltf, rigged to the head bone).
@export var hair: Array[PackedScene] = []
## A cloth wrap made from the head mesh and skinned like it (the Rogue's
## face mask, the Hunter's neck scarf; made by tools/build_headwear.gd), or
## null.
@export var head_wrap: ArrayMesh
## A hat, a rigid mesh in Head-bone space (made by tools/build_headwear.gd),
## or null.
@export var hat: ArrayMesh
## The outfit material the palettes recolour (by its imported name).
@export var outfit_material: StringName = &"MI_Ranger"
## Exactly two: the first is the default, the second dresses the second
## fighter of a mirror match.
@export var palettes: Array[FighterPalette] = []
## The weapon offered by default at character select (a WeaponDef id).
@export var signature_weapon: StringName = &""
## Clip names in the shared animation library (without the library prefix).
## The idle clip is the one played with no weapon, or with a weapon that has
## no hold of its own.
@export var idle_clip: StringName = &"Idle"
@export var walk_clip: StringName = &"Walk"
## How the fighter carries each weapon outside its attacks (see WeaponHold).
@export var holds: Array[WeaponHold] = []

@export_group("Skin")
## The skin texture with the settings below baked in (by
## tools/bake_skins.gd); null keeps the base body's.
@export var skin_albedo: Texture2D
## Dark, sunken eye sockets, 0 to 1.
@export_range(0.0, 1.0) var eye_shadow: float = 0.5
## A band of dark paint across the eyes, 0 to 1.
@export_range(0.0, 1.0) var eye_band: float = 0.0
## Soot and grime over the face, 0 to 1.
@export_range(0.0, 1.0) var soot: float = 0.3
## Scars, each a segment between two points in fighter space (rest pose).
@export var scars: PackedVector3Array = PackedVector3Array()
@export_group("")


static func path_for(fighter_id: StringName) -> String:
	return "res://fighters/%s/%s.tres" % [fighter_id, fighter_id]


static func scene_path_for(fighter_id: StringName) -> String:
	return "res://fighters/%s/%s.tscn" % [fighter_id, fighter_id]


## Instantiates a fighter's scene: a built FighterModel.
static func instantiate_fighter(fighter_id: StringName) -> FighterModel:
	return (load(scene_path_for(fighter_id)) as PackedScene).instantiate() as FighterModel


## The fighter's hold for a weapon, or null when it has none.
func hold_for(weapon_id: StringName) -> WeaponHold:
	for h: WeaponHold in holds:
		if h.weapon == weapon_id:
			return h
	return null
