// surface.gdshader for far scenery (milestone-1 task 51: the pagodas and
// temple halls on the Shrine's cliffs): the same surface, faded into the
// horizon's mist by the aerial fade the landscape under it takes
// (aerial_fade.gdshaderinc) in place of the environment's depth fog, so the
// buildings and their rock step back alike. Build it through
// LookMaterials.far().
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#define AERIAL_FADE
#include "res://shaders/surface.gdshaderinc"
