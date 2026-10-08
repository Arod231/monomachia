// surface.gdshader drawn from both sides and swayed by the Shrine's wind
// (milestone-1 task 131): the grass's blade cards and the banners' cloth. A
// vertex's weight, 0 where it is held (a blade's root, the cloth at the
// pole) to 1 where it hangs free, is in its vertex colour: alpha for the
// grass (whose colour is its own), red for the cloth (sway_from_red). The
// wind pushes it downwind, in gusts that roll across the courtyard, and the
// cloth flutters in a wave running away from the pole. Build it through
// LookMaterials.sway().
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

#include "res://shaders/surface.gdshaderinc"

// The wind across the ground (ShrineLayout.wind), m/s-ish: its direction
// and strength.
uniform vec2 wind = vec2(-0.55, -0.19);
// How far the freest vertex leans in a wind of 1, in metres, and how fast
// the gusts come.
uniform float sway = 0.04;
uniform float sway_speed = 1.7;
// The cloth's flutter: how far a wave lifts it, in metres, and its length.
uniform float flutter = 0.0;
uniform float flutter_length = 0.8;
uniform bool sway_from_red = false;

void vertex() {
	float w = sway_from_red ? COLOR.r : COLOR.a;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 dir = length(wind) > 0.0001 ? normalize(wind) : vec2(1.0, 0.0);
	// gusts roll downwind across the ground
	float phase = dot(world.xz, dir) * 0.45 - TIME * sway_speed;
	float gust = 0.55 + 0.3 * sin(phase) + 0.15 * sin(phase * 2.3 + 1.1);
	vec3 push = vec3(wind.x, 0.0, wind.y) * sway * gust * w;
	// the cloth's wave, through it, running away from the pole
	if (flutter > 0.0) {
		float wave = sin(VERTEX.x / flutter_length * 6.2832 - TIME * sway_speed * 2.6 + world.y * 0.7);
		push += (MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz * wave * flutter * w;
	}
	VERTEX += inverse(mat3(MODEL_MATRIX)) * push;
	if (sway_from_red) {
		// the weight isn't a colour: the cloth's colour is its texture's
		COLOR = vec4(1.0);
	}
}
