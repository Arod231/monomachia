// The far lake: dark ink water that mirrors the horizon's mist, with the
// blood moon's reflection broken into horizontal ripple strokes. The
// backdrop sets the moon, the horizon (the depth fog's colour) and the
// look's noise texture.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform vec4 water_color : source_color = vec4(0.03, 0.035, 0.055, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.2, 0.22, 0.29, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 0.32, 0.18, 1.0);
uniform vec3 moon_direction = vec3(0.0, 0.25, 1.0);
uniform float glint_energy = 2.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 v = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec2 rp = world_pos.xz * vec2(0.05, 0.35);
	float rx = look_noise(rp + vec2(TIME * 0.05, 0.0)).r - 0.5;
	float rz = look_noise(rp * 1.7 + vec2(3.1, TIME * 0.08)).g - 0.5;
	vec3 n = normalize(vec3(rx * 0.06, 1.0, rz * 0.35));
	vec3 r = reflect(v, n);
	float fresnel = pow(1.0 - max(dot(-v, n), 0.0), 4.0);
	vec3 col = mix(water_color.rgb, horizon_color.rgb, clamp(fresnel * 1.6 + 0.25, 0.0, 1.0));
	float m = dot(r, normalize(moon_direction));
	float strokes = smoothstep(0.45, 0.6, look_noise(world_pos.xz * vec2(0.08, 0.9)).b);
	col += glint_color.rgb * smoothstep(0.975, 0.997, m) * strokes * glint_energy;
	ALBEDO = col;
}
