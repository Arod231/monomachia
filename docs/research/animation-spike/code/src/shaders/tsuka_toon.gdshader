shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://src/shaders/toon_light.gdshaderinc"
// Toon wrapped grip: black silk wrap over ivory ray-skin diamonds.
uniform vec3 ito : source_color = vec3(0.05, 0.045, 0.05);
uniform vec3 same : source_color = vec3(0.80, 0.75, 0.64);

void fragment() {
	vec2 p = vec2(UV.x * 4.0, UV.y * 9.0);
	vec2 q = fract(p) - 0.5;
	float d = abs(q.x) + abs(q.y);
	float window = smoothstep(0.24, 0.20, d);
	ALBEDO = mix(ito, same, window);
	ROUGHNESS = 1.0;
	EMISSION = toon_rim(NORMAL, VIEW, VIEW_MATRIX, ALBEDO);
}
