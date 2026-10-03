// One ring of far mountains, painted like an ink-wash landscape: a dark
// brushed ridge line that dissolves downward into mist, with vertical texture
// strokes. UV.x runs once round the ring, UV.y is 0 at the sea of clouds and
// 1 at the ridge. Unshaded; the environment fog fades far rings further. The
// backdrop sets the moon, the horizon's mist (the depth fog's colour) and
// the look's noise texture.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform vec4 ridge_color : source_color = vec4(0.03, 0.035, 0.05, 1.0);
uniform vec4 body_color : source_color = vec4(0.07, 0.08, 0.11, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.2, 0.22, 0.29, 1.0);
uniform vec4 moon_tint : source_color = vec4(0.35, 0.10, 0.08, 1.0);
uniform vec3 moon_direction = vec3(0.0, 0.25, 1.0);
// How far the ring fades into the mist: 0 for the nearest (darkest), more
// for farther rings (the backdrop goes up to 0.35).
uniform float layer_fade : hint_range(0.0, 1.0) = 0.0;
// Strokes round the ring: a multiple of the noise's period
// (LOOK_NOISE_CELLS), so they meet where the ring closes.
uniform float stroke_frequency = 896.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = UV.y;
	float strokes = look_noise(vec2(UV.x * stroke_frequency, t * 2.5)).r * 0.6
		+ look_noise(vec2(UV.x * stroke_frequency * 3.0, t * 6.0 + 3.1)).g * 0.4;
	float wash = clamp(t + (strokes - 0.5) * 0.4, 0.0, 1.0);
	vec3 col = mix(horizon_color.rgb, body_color.rgb, smoothstep(0.25, 0.95, wash));
	col = mix(col, ridge_color.rgb, smoothstep(0.86, 1.0, t + (strokes - 0.5) * 0.12) * 0.85);
	// A faint red cast on the ranges that stand in front of the moon, from
	// the clouds up (t runs far below 0 where the valley drops under them).
	vec2 dir = normalize(world_pos.xz);
	float toward = pow(max(dot(dir, normalize(moon_direction.xz)), 0.0), 6.0);
	col += moon_tint.rgb * toward * 0.35 * clamp(t, 0.0, 1.0);
	col = mix(col, horizon_color.rgb, layer_fade);
	ALBEDO = col;
}
