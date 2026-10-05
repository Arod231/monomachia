shader_type spatial;
render_mode cull_back;
#include "res://src/shaders/toon_light.gdshaderinc"
// Toon katana blade: steel body, bright wavy hamon along the edge, hard specular glint.
uniform vec3 steel : source_color = vec3(0.46, 0.50, 0.58);
uniform vec3 hamon : source_color = vec3(0.92, 0.94, 0.98);

void fragment() {
	float wave = 0.26 + 0.035 * sin(UV.y * 72.0) + 0.02 * sin(UV.y * 23.0 + 1.3);
	float h = smoothstep(wave + 0.02, wave - 0.02, UV.x);
	ALBEDO = mix(steel, hamon, h);
	ROUGHNESS = 1.0;
	EMISSION = toon_rim(NORMAL, VIEW, VIEW_MATRIX, ALBEDO) + hamon * h * 0.06;
}
