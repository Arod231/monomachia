// Moonsplitter's wave (MoonWave, milestone-1 task 100; design.md's mood
// board): moonlight given an edge, a crescent of cold silver-white light
// with a wisteria-violet fringe, bending the scene behind it, its light
// streaming along it like a wave's crest. UV.x runs across the crescent (0
// and 1 its edges), UV.y along it (0 and 1 its tips). `fade` brings it in
// as it leaves the blade and out at the end of its flight.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec3 core : source_color = vec3(0.9, 0.94, 1.0);
uniform vec3 fringe : source_color = vec3(0.66, 0.52, 0.92);
// How bright the light is (above 1 blooms where the preset glows).
uniform float glow = 1.5;
// How far it bends the scene behind it, as a share of the screen.
uniform float bend = 0.025;
uniform float fade = 1.0;
// How fast its light streams along it.
uniform float flow = 2.5;

void fragment() {
	// across: 0 its trailing edge, 1 its leading edge, the cutting light
	float across = UV.x;
	float al = abs(UV.y * 2.0 - 1.0);
	vec3 n = look_noise(vec2(UV.y * 5.0 - TIME * flow, across * 2.0 + TIME * 0.3));
	vec3 m = look_noise(vec2(UV.y * 13.0 - TIME * flow * 1.7, across * 5.0));
	// a soft trailing body, a sharp bright leading edge, thinning to the tips
	float trail = smoothstep(0.0, 0.7, across) * (1.0 - smoothstep(0.93, 1.0, across));
	float edge = smoothstep(0.7, 0.9, across) * (1.0 - smoothstep(0.95, 1.0, across));
	float tips = 1.0 - smoothstep(0.7, 1.0, al);
	float wisps = mix(0.35, 1.0, n.b) * mix(0.75, 1.1, m.g);
	float body = (trail * 0.45 * wisps + edge) * tips;
	vec3 light = mix(fringe, core, edge) * glow * mix(0.7, 1.2, n.b);
	float s = body * fade;
	vec2 offset = (n.rg - 0.5) * 2.0 * bend * trail * tips * fade;
	vec3 behind = textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb;
	ALBEDO = behind + light * s;
	ALPHA = clamp(max(s, trail * tips * fade * 0.6), 0.0, 1.0);
}
