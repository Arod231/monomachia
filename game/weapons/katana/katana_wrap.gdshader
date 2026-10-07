// Katana grip: a dark silk wrap (tsuka-ito) crossing over pale ray skin
// (same), which shows through in diamond-shaped windows. Lit physically
// (milestone-1 task 43). The grip mesh's UV.x runs around the grip, UV.y
// along it.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 wrap : source_color = vec3(0.05, 0.045, 0.05);
uniform vec3 ray_skin : source_color = vec3(0.7, 0.66, 0.56);
uniform float diamonds_around = 4.0;
uniform float diamonds_along = 9.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec2 p = vec2(UV.x * diamonds_around, UV.y * diamonds_along);
	vec2 q = fract(p) - 0.5;
	float d = abs(q.x) + abs(q.y);
	float window = smoothstep(0.24, 0.2, d);
	float weave = 0.85 + 0.15 * step(0.5, fract((p.x + p.y) * 6.0));
	ALBEDO = mix(wrap * weave, ray_skin, window);
	ROUGHNESS = roughness;
}
