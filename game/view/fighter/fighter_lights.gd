class_name FighterLights
extends Node3D
## A fighter's own key and rim light (milestone-1 task 44; spec story 142),
## so the fighters stand out of the dark without outlines. Both touch only
## this fighter: their cull mask is its side's render layer
## (LookPalette.side_layer()), which only its body and the weapons it holds
## carry, never the arena or the other fighter; neither lights the fog.
##
## Aimed from the fighter as the look test (task 30) lit it, the owner's
## choice (Oct 7): the key ahead of the fighter and to its left in moonlit
## steel, casting shadows on every preset but Low (GraphicsPreset.
## fighter_shadows); the rim cold, from behind and above. A child of the
## FighterView, so it moves and turns with the fighter: ahead is where the
## fighter faces, the opponent while it is locked on, so the gameplay
## camera, Watch and both halves of Versus see the same light.

## The chest both lights aim at, and where each hangs, in the fighter's own
## space (+Z ahead, +X its left), the look test's spots.
const CHEST := Vector3(0.0, 1.3, 0.0)
const KEY_AT := Vector3(1.6, 2.7, 2.2)
const RIM_AT := Vector3(-1.8, 3.1, -1.8)

const KEY_ENERGY: float = 6.0
const KEY_RANGE: float = 7.0
const KEY_ANGLE: float = 26.0
const RIM_COLOR := Color(0.72, 0.8, 1.0)
const RIM_ENERGY: float = 9.0
const RIM_RANGE: float = 8.0
const RIM_ANGLE: float = 22.0

var key: SpotLight3D
var rim: SpotLight3D


func _init() -> void:
	name = "FighterLights"
	key = _spot(&"Key", KEY_AT, LookPalette.MOON_STEEL.lightened(0.3), KEY_ENERGY, KEY_RANGE, KEY_ANGLE)
	key.shadow_enabled = true
	key.add_to_group(GraphicsApplier.GROUP_FIGHTER_KEY)
	rim = _spot(&"Rim", RIM_AT, RIM_COLOR, RIM_ENERGY, RIM_RANGE, RIM_ANGLE)
	set_side(0)


## Lights only the fighter on `side`.
func set_side(side: int) -> void:
	for light: SpotLight3D in [key, rim]:
		light.light_cull_mask = LookPalette.side_layer(side)


func _spot(light_name: StringName, at: Vector3, color: Color, energy: float, reach: float, angle: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = light_name
	light.transform = Transform3D(Basis.looking_at(CHEST - at, Vector3.UP), at)
	light.light_color = color
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = angle
	light.light_volumetric_fog_energy = 0.0
	add_child(light)
	return light
