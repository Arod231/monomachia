// A puff of dust and cloth (CombatEffects' puffs, milestone-1 task 37): where
// a bare hand meets a blade, a dull, soft cloud that drifts and thins out,
// lit by nothing (it catches the scene's tone through its colour), with no
// glow. A camera-facing quad; the instance colour (COLOR) is the dust's, its
// alpha the fade.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/particle_billboard.gdshaderinc"
#include "res://shaders/look_noise.gdshaderinc"

void vertex() {
	MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c) * 2.0;
	// a ragged edge, so the cloud doesn't read as a disc
	vec3 n = look_noise(UV * 2.0 + COLOR.a * 0.3);
	float soft = 1.0 - smoothstep(0.35 + 0.25 * n.r, 1.0, d);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * soft * 0.55;
}
