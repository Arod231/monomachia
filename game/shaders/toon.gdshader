// The one toon material for fighters, weapons and props: the shared toon
// surface (toon_surface.gdshaderinc) lit by the shared three-band toon model
// (toon_light.gdshaderinc). Build it through ToonMaterials, which also
// attaches the ink outline pass. toon_two_sided.gdshader is the same surface
// drawn from both sides.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/toon_light.gdshaderinc"
#include "res://shaders/toon_surface.gdshaderinc"
