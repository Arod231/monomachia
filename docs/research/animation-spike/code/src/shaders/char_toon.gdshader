shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://src/shaders/toon_light.gdshaderinc"
// Character toon material: painted albedo (slightly desaturated, tinted), its normal map for the
// painted folds, 3-band ramp + rim from the include. Alpha scissor for hair cards.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth = 0.6;
uniform bool use_normal = true;
uniform float saturation = 0.82;
uniform float alpha_cut = 0.5;

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), c.rgb, saturation);
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	ROUGHNESS = 1.0;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	EMISSION = toon_rim(NORMAL, VIEW, VIEW_MATRIX, ALBEDO);
}
