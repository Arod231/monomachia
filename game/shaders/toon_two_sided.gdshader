// toon.gdshader drawn from both sides, for open shells that show their inside
// (the fighters' hoods, cloth edges and hair cards: the Quaternius imports
// are all double-sided). Back faces are lit with their normal flipped.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

#include "res://shaders/toon_light.gdshaderinc"
#include "res://shaders/toon_surface.gdshaderinc"
