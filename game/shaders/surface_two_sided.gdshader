// surface.gdshader drawn from both sides, for open shells that show their
// inside (the fighters' hoods, cloth edges and hair cards: the Quaternius
// imports are all double-sided).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

#include "res://shaders/surface.gdshaderinc"
