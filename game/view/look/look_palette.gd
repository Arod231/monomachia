class_name LookPalette
extends RefCounted
## The look's muted colours (ink blacks, bone and paper whites, stone greys,
## lacquer red), the side colours, and the render layers the look relies on.
## Colours are sRGB, as picked; shader uniforms marked source_color convert
## them. The fighters' palettes (FighterPalette) and the side colours are the
## only saturated colours near the fighting area, so the fighters pop from the
## arena.

## Each side's colour, by its palette index (MatchSide.palette): side 0
## takes 0 (red) and side 1 takes 1 (blue) by default, as the demo's two
## fighters did. The floor ring under a fighter, the beam over its dropped
## weapon and its name on the results screen.
const SIDE_COLORS: Array[Color] = [
	Color(0.7, 0.16, 0.13),
	Color(0.18, 0.4, 0.72),
	Color(0.18, 0.58, 0.45),
	Color(0.78, 0.58, 0.16),
]

const INK: Color = Color("0e0e14")
const INK_SOFT: Color = Color("1c1c26")
const BONE: Color = Color("d6ccb8")
const PAPER: Color = Color("e8e0cc")
const LACQUER: Color = Color("6a1a15")
const STONE_LIGHT: Color = Color("76736f")
const STONE: Color = Color("5c5a61")
const STONE_DARK: Color = Color("3c3b44")
const WOOD_DARK: Color = Color("2a201c")
const ROPE: Color = Color("b3a078")
const PINE: Color = Color("1e2b28")
const IRON: Color = Color("34343c")
const STEEL: Color = Color("b8bec8")

## The realistic look's night, from the mood board (milestone-1 task 43; the
## look test's, task 30): the blue-black the grade lifts black to, the moon's
## cold light, the mist, and the lanterns' ember.
const NIGHT_INK: Color = Color("0b0e16")
const MOON_STEEL: Color = Color("8f9bb0")
const MIST: Color = Color("4b5468")
const LANTERN_EMBER: Color = Color("d4873a")

## Render layer bit for fighters and their weapons (layer 2). Lights whose
## cull mask is only this layer (the arena's moon rim light) touch fighters
## and nothing else.
const FIGHTER_LAYER: int = 2
## Render layer bits for each side's fighter (layers 7 and 8; milestone-1
## task 44): a fighter's body and the weapons it holds carry its side's bit
## beside FIGHTER_LAYER, and its own key and rim light (FighterLights) light
## only that bit, so neither the arena nor the other fighter catches them.
const SIDE_LAYERS: Array[int] = [64, 128]
const SIDE_LAYERS_MASK: int = 64 | 128
## Render layer bit for large ground surfaces (layer 4): the courtyard floor
## and the rock ledge. Small warm lights (lanterns) leave this layer out of
## their cull mask: their pools on the ground were barely visible and cost
## about 0.4 ms per frame on the target laptop.
const GROUND_LAYER: int = 8
## Cull mask for small lights: every layer but the ground.
const SMALL_LIGHT_MASK: int = 0xFFFFF & ~GROUND_LAYER
## Render layer bit for the rock under an arena's rim (layer 5). Cameras
## above the courtyard can't see it, so the arena leaves this layer out of
## their cull masks, camera by camera.
const BELOW_DECK_LAYER: int = 16
## Render layer bit for an arena's canopy (layer 10; milestone-1 task 49):
## the Shrine's wisteria cast their shadows only in the moon shafts' light,
## which breaks through them into the mist. Every other light that casts
## shadows leaves this layer out of its caster mask (SHADOW_CASTERS), so the
## trees still cast no shadow on the arena.
const CANOPY_LAYER: int = 512
## Shadow caster mask for every light but the moon shafts: all but the canopy.
const SHADOW_CASTERS: int = 0xFFFFF & ~CANOPY_LAYER


## The render layer bit of the fighter on `side` (SIDE_LAYERS).
static func side_layer(side: int) -> int:
	return SIDE_LAYERS[posmod(side, SIDE_LAYERS.size())]


## The colour of a side with palette index `palette`.
static func side_color(palette: int) -> Color:
	return SIDE_COLORS[posmod(palette, SIDE_COLORS.size())]
