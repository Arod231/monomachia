// The sea of clouds below the shrine: a large flat layer of slowly drifting,
// domain-warped cloud, lit cold on the tops and inked in the hollows, fading
// into the horizon mist with distance, with a clearing where the lake shows
// through. Transparent and unshaded. The backdrop sets the moon, the horizon
// (the depth fog's colour), the clearing and the look's noise texture; the
// clouds drift on the arena's one wind.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/look_noise.gdshaderinc"
#include "res://shaders/wind.gdshaderinc"

uniform vec4 lit_color : source_color = vec4(0.46, 0.49, 0.6, 1.0);
uniform vec4 shade_color : source_color = vec4(0.09, 0.1, 0.14, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.2, 0.22, 0.29, 1.0);
uniform vec4 moon_tint : source_color = vec4(0.45, 0.12, 0.09, 1.0);
uniform vec3 moon_direction = vec3(0.0, 0.25, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.01, 0.5) = 0.17;
// Noise cells per metre.
uniform float scale = 0.011;
// Noise cells the clouds drift for each metre the wind carries the air (the
// arena's one wind, wind.gdshaderinc: milestone-1 task 52).
uniform float drift_rate = 0.0207;
uniform float opacity : hint_range(0.0, 1.0) = 0.92;
uniform float fade_start = 250.0;
uniform float fade_end = 1800.0;
// A gap in the clouds (x, z, radius) so the lake below can show.
uniform vec3 clearing = vec3(0.0, 0.0, 0.0);

varying vec3 world_pos;

// Four octaves of the look's three noises at once, one fetch each.
vec3 cloud_fbm(vec2 p) {
	return look_noise(p) * 0.5
		+ look_noise(p * 2.1 + vec2(3.7, 1.9)) * 0.25
		+ look_noise(p * 4.41 + vec2(11.4, 5.9)) * 0.125
		+ look_noise(p * 9.26 + vec2(27.6, 14.3)) * 0.0625;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale - wind_direction() * wind.z * wind_time * drift_rate;
	// Two noises warp the third, which shapes the cloud.
	vec2 warp = cloud_fbm(p + 1.7).rg;
	float c = cloud_fbm(p + warp * 1.6).b;
	float density = smoothstep(coverage - softness, coverage + softness, c);
	vec3 col = mix(shade_color.rgb, lit_color.rgb, smoothstep(0.35, 0.85, c));
	// Red moonlight on the clouds toward the moon.
	vec2 to_frag = normalize(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	float toward = pow(max(dot(to_frag, normalize(moon_direction.xz)), 0.0), 5.0);
	col += moon_tint.rgb * toward * smoothstep(0.4, 0.9, c) * 0.6;
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	float far = smoothstep(fade_start, fade_end, dist);
	float open = 1.0;
	if (clearing.z > 0.0) {
		float dc = length(world_pos.xz - clearing.xy) / clearing.z;
		open = smoothstep(0.55, 1.05, dc + (c - 0.5) * 0.5);
	}
	col = mix(col, horizon_color.rgb, far);
	ALBEDO = col;
	ALPHA = mix(density, 1.0, far * 0.85 * open) * opacity * mix(0.15, 1.0, open);
}
