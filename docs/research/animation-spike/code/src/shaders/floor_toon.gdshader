shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://src/shaders/toon_light.gdshaderinc"
// Shrine floor: large worn stone slabs in world space, dark joints, faint value noise.
uniform vec3 stone : source_color = vec3(0.155, 0.16, 0.18);
uniform vec3 joint : source_color = vec3(0.075, 0.075, 0.09);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz / vec2(1.9, 1.3);
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;   // running bond
	vec2 g = abs(fract(p) - 0.5);
	float j = smoothstep(0.488, 0.496, max(g.x, g.y)) * (0.6 + 0.4 * noise(wpos.xz * 7.0));
	float slab = hash(floor(p)) * 0.22 + noise(wpos.xz * 1.7) * 0.14 + noise(wpos.xz * 9.0) * 0.05;
	vec3 c = stone * (0.88 + slab);
	ALBEDO = mix(c, joint, j);
	ROUGHNESS = 1.0;
}
