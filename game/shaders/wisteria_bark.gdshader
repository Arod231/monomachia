// The wisteria's bark (milestone-1 task 52): the look's physically based
// surface (surface.gdshaderinc, the bark scan through LookMaterials), its
// outer branches swaying on the arena's one wind (wisteria_sway.gdshaderinc).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/surface.gdshaderinc"
#include "res://shaders/wisteria_sway.gdshaderinc"

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX = pushed(VERTEX, branch_push(VERTEX, world), MODEL_MATRIX);
}
