// The one physically based material for fighters, weapons and props: the
// shared surface (surface.gdshaderinc) under Godot's own lighting. Build it
// through LookMaterials. surface_two_sided.gdshader is the same surface drawn
// from both sides.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/surface.gdshaderinc"
