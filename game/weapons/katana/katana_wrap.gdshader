// Katana grip: a dark silk wrap (tsuka-ito) crossing over pale ray skin
// (same), which shows through in diamond-shaped windows. Toon-lit like every
// weapon (toon_light.gdshaderinc); ToonMaterials.weapon_from() adds the rim
// and the ink outline. The grip mesh's UV.x runs around the grip, UV.y along
// it.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec3 wrap : source_color = vec3(0.05, 0.045, 0.05);
uniform vec3 ray_skin : source_color = vec3(0.7, 0.66, 0.56);
uniform float diamonds_around = 4.0;
uniform float diamonds_along = 9.0;
// The outline's ink (ToonMaterials sets it on every toon material).
uniform vec4 ink_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);

void fragment() {
	vec2 p = vec2(UV.x * diamonds_around, UV.y * diamonds_along);
	vec2 q = fract(p) - 0.5;
	float d = abs(q.x) + abs(q.y);
	float window = smoothstep(0.24, 0.2, d);
	float weave = 0.85 + 0.15 * step(0.5, fract((p.x + p.y) * 6.0));
	ALBEDO = mix(wrap * weave, ray_skin, window);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	toon_brush = toon_noise3((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 2.6) - 0.5;
}
