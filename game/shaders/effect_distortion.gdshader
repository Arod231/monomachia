// A ring of distortion (CombatEffects' distortion pool, milestone-1 task
// 100): a shockwave in the air that bends the scene behind its band as it
// widens, pushing it outward across the wavefront, with the faintest pale
// edge. As effect_ring.gdshader, each MultiMesh instance's custom data says
// how it sits (x above 0.5 faces the camera) and how wide its band is (y, a
// share of the radius); the instance colour's alpha is its strength.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/particle_billboard.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
// How far the scene is bent at full strength, as a share of the screen.
uniform float bend = 0.03;

varying float band;

void vertex() {
	band = max(INSTANCE_CUSTOM.y, 0.01);
	if (INSTANCE_CUSTOM.x > 0.5) {
		MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	}
}

void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c) * 2.0;
	float edge = 1.0 - band;
	// a signed place across the band: -1 inside, 1 outside
	float across = clamp((d - edge) / band, -1.0, 1.0);
	float ring = 1.0 - smoothstep(0.0, 1.0, abs(across));
	vec2 out_dir = d > 1e-4 ? c / length(c) : vec2(0.0);
	// a lens at the wavefront: the scene pulled in behind it, pushed out ahead
	float s = ring * COLOR.a;
	vec2 offset = out_dir * vec2(1.0, -1.0) * bend * s * sin(across * 3.14159);
	vec3 behind = textureLod(screen_texture, SCREEN_UV - offset, 0.0).rgb;
	ALBEDO = behind + vec3(0.06) * s;
	ALPHA = clamp(s * 1.4, 0.0, 1.0);
}
