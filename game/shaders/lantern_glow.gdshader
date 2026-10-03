// The lit paper of stone lanterns: unshaded and warm, brighter toward the
// middle of each panel like a flame behind paper, and flickering on its own
// (the vertex colour's alpha is the flicker phase), so no script touches it.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.56, 0.22, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform float energy = 3.0;
uniform float flicker = 0.25;

varying float phase;

void vertex() {
	phase = COLOR.a * TAU;
}

void fragment() {
	float flame = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 9.0 + phase * 3.0)) * (0.6 + 0.4 * sin(TIME * 23.0 + phase * 7.0));
	float core = 1.0 - smoothstep(0.1, 0.5, length(UV - 0.5));
	ALBEDO = mix(glow_color.rgb, core_color.rgb, core * 0.6) * energy * flame;
}
