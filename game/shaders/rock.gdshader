// Weathered rock for the crag under the arena, its ledge and the floating
// rocks: noisy strata, vertical ink strokes like the texture strokes of an
// ink landscape, pale dust on upward faces, and vertex-colour shading for
// crevices. Lit by the shared toon model. No image textures.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// toon_light brings the look's noise (look_noise.gdshaderinc) too.
#include "res://shaders/toon_light.gdshaderinc"

// Set on every toon material (ToonMaterials); the rock has no outline or
// wash to use it.
uniform vec4 ink_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform vec4 rock_light : source_color = vec4(0.42, 0.415, 0.44, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.17, 0.17, 0.2, 1.0);
uniform vec4 top_color : source_color = vec4(0.42, 0.42, 0.44, 1.0);
uniform float top_amount : hint_range(0.0, 1.0) = 0.6;
uniform float strata_scale = 0.2;
uniform float stroke_amount : hint_range(0.0, 1.0) = 0.5;
uniform float noise_scale = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = world_pos;
	float n1 = toon_noise3(w * noise_scale);
	float n = n1 * 0.6 + toon_noise3(w * noise_scale * 2.7) * 0.4;
	float strata = sin(w.y * strata_scale * TAU + n1 * 7.0) * 0.5 + 0.5;
	vec3 col = mix(rock_dark.rgb, rock_light.rgb, smoothstep(0.2, 0.8, n * 0.85 + strata * 0.15));
	// Strokes stretched down the rock, like an ink painter's texture strokes.
	float stroke = toon_noise3(vec3(w.x * 2.2, w.y * 0.22, w.z * 2.2));
	col *= mix(1.0, mix(0.62, 1.06, smoothstep(0.3, 0.7, stroke)), stroke_amount);
	float up = smoothstep(0.5, 0.85, world_normal.y + (n - 0.5) * 0.35);
	col = mix(col, top_color.rgb * (0.85 + 0.3 * n), up * top_amount);
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// The rock noise doubles as the brush noise for the band edges.
	toon_brush = (n - 0.5) * 1.4 + (stroke - 0.5) * 0.4;
}
