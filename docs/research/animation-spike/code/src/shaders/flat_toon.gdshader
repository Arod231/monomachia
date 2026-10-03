shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://src/shaders/toon_light.gdshaderinc"
// Flat-colour toon material (weapon fittings, props).
uniform vec4 color : source_color = vec4(0.5, 0.5, 0.5, 1.0);

void fragment() {
	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
	EMISSION = toon_rim(NORMAL, VIEW, VIEW_MATRIX, ALBEDO);
}
