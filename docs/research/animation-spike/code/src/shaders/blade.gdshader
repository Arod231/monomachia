shader_type spatial;
// Katana blade: dark steel body with a wavy, polished hamon along the edge (UV.x = 0 at the edge, 1 at the back).
uniform vec3 steel : source_color = vec3(0.50, 0.53, 0.58);
uniform vec3 hamon : source_color = vec3(0.90, 0.92, 0.95);

void fragment() {
	float wave = 0.26 + 0.035 * sin(UV.y * 72.0) + 0.02 * sin(UV.y * 23.0 + 1.3);
	float h = smoothstep(wave + 0.025, wave - 0.025, UV.x);
	ALBEDO = mix(steel, hamon, h);
	METALLIC = 0.55;
	ROUGHNESS = mix(0.34, 0.2, h);
}
