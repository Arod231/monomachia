// A fast swing's air smear (AirSmear, milestone-1 task 37): a short ribbon
// behind the blade's last third that bends the scene behind it like heat
// haze, with a faint pale sheen, in place of the toon look's brush strokes.
// The vertex COLOR is the smear's tint (pale for a plain swing, red for an
// unblockable's, gold for an ultimate's) and its alpha the smear's strength,
// fading with age. UV.x is the age along the ribbon (0 at the blade, 1 at the
// tail); UV.y runs across it (0 on the inner edge, 1 at the tip).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

// How far the haze bends the scene behind it, as a share of the screen.
uniform float bend = 0.012;
// How much of the tint shows over the bent scene, at full strength.
uniform float sheen = 0.2;
// How finely the haze ripples along and across the ribbon.
uniform vec2 ripple = vec2(3.0, 9.0);

void fragment() {
	float age = UV.x;
	float across = UV.y;
	// soft on both edges, strongest just inside the tip's edge, where the
	// blade moved fastest
	float body = smoothstep(0.0, 0.35, across) * (1.0 - smoothstep(0.85, 1.0, across));
	float strength = COLOR.a * body * (1.0 - age * age);
	vec3 n = look_noise(vec2(age * ripple.x, across * ripple.y));
	vec2 offset = (n.rg - 0.5) * 2.0 * bend * strength;
	vec3 behind = textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb;
	// the sheen streaks along the stroke, brighter toward the tip
	float streak = mix(0.5, 1.0, n.b) * smoothstep(0.2, 1.0, across);
	ALBEDO = mix(behind, COLOR.rgb, sheen * streak);
	ALPHA = clamp(strength, 0.0, 1.0);
}
