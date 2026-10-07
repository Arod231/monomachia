// The ultimate-ready aura's heat haze (UltAura, milestone-1 task 100): a
// camera-facing veil round the body that bends the scene behind it in a slow
// rising shimmer, strongest round the body's middle and gone at its edges.
// Steady, so Reduce flashes keeps it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look_noise.gdshaderinc"
#include "res://shaders/particle_billboard.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float bend = 0.006;
uniform float strength = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.6, 0.3);

void vertex() {
	// face the camera about the vertical, standing upright
	MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
}

void fragment() {
	vec2 c = UV - vec2(0.5, 0.55);
	float body = 1.0 - smoothstep(0.15, 0.5, length(c * vec2(1.6, 1.0)));
	vec3 n = look_noise(vec2(UV.x * 3.0, UV.y * 4.0 + TIME * 0.9));
	vec2 offset = (n.rg - 0.5) * 2.0 * bend * body * strength;
	vec3 behind = textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb;
	ALBEDO = behind + tint * 0.03 * body * strength;
	ALPHA = clamp(body * strength, 0.0, 1.0);
}
