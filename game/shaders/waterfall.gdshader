// A distant waterfall: streaks scrolling down a ribbon, pale in the
// moonlight, foamy at the lip, dissolving into mist at the bottom. UV.x runs
// across the ribbon, UV.y from the lip (0) to the bottom (1). The backdrop
// sets the look's noise texture.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform vec4 water_color : source_color = vec4(0.42, 0.48, 0.6, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.8, 0.86, 1.0);
uniform float speed = 0.35;
uniform float streak_density = 22.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec2 uv = UV;
	float s1 = look_noise(vec2(uv.x * streak_density, uv.y * 3.0 - TIME * speed * 3.0)).r;
	float s2 = look_noise(vec2(uv.x * streak_density * 2.3, uv.y * 7.0 - TIME * speed * 5.0) + vec2(4.7, 0.0)).g;
	float body = smoothstep(0.35, 0.75, s1 * 0.6 + s2 * 0.4);
	float edges = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
	float lip = 1.0 - smoothstep(0.0, 0.08, uv.y);
	float bottom = 1.0 - smoothstep(0.55, 1.0, uv.y);
	ALBEDO = mix(water_color.rgb, foam_color.rgb, clamp(body * 0.8 + lip, 0.0, 1.0));
	ALPHA = clamp((0.3 + 0.6 * body + lip * 0.4) * edges * bottom, 0.0, 1.0) * opacity;
}
