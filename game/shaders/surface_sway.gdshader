// surface.gdshader drawn from both sides and swayed by the Shrine's wind
// (milestone-1 task 131): the grass's blade cards and the banners' cloth. A
// vertex's weight, 0 where it is held (a blade's root, the cloth at the
// pole) to 1 where it hangs free, is in its vertex colour: alpha for the
// grass (whose colour is its own), red for the cloth (sway_from_red). The
// arena's one wind (wind.gdshaderinc, milestone-1 task 52) pushes it
// downwind, further as a gust rolls across the courtyard, with a quiver of
// its own, and the cloth flutters in a wave running away from the pole,
// harder in a gust. Build it through LookMaterials.sway().
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

#include "res://shaders/surface.gdshaderinc"
#include "res://shaders/wind.gdshaderinc"

// How far the freest vertex leans for each m/s of wind, in metres, and how
// fast it quivers.
uniform float sway = 0.04;
uniform float sway_speed = 1.7;
// The cloth's flutter: how far a wave lifts it, in metres, and its length.
uniform float flutter = 0.0;
uniform float flutter_length = 0.8;
uniform bool sway_from_red = false;

void vertex() {
	float w = sway_from_red ? COLOR.r : COLOR.a;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 v = wind_velocity(world);
	// a quiver of its own over the gusts' lean
	float quiver = 0.85 + 0.15 * sin(dot(world.xz, wind_direction()) * 0.45 - wind_time * sway_speed);
	vec3 push = vec3(v.x, 0.0, v.y) * sway * quiver * w;
	// the cloth's wave, through it, running away from the pole
	if (flutter > 0.0) {
		float wave = sin(VERTEX.x / flutter_length * 6.2832 - wind_time * sway_speed * 2.6 + world.y * 0.7);
		push += (MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz * wave * flutter * w * wind_gust(world);
	}
	VERTEX += inverse(mat3(MODEL_MATRIX)) * push;
	if (sway_from_red) {
		// the weight isn't a colour: the cloth's colour is its texture's
		COLOR = vec4(1.0);
	}
}
