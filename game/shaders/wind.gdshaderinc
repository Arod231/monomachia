// The arena's one wind (milestone-1 task 52, Wind): the global uniforms
// Wind.apply() and Wind.advance() set, and wind_gust(), which mirrors
// Wind.gust_at(), so what the shaders sway and what the scripts drift (the
// petals, the scarf) feel the same gust at the same moment.

#ifndef WIND_INC
#define WIND_INC

// (direction x, direction z, speed m/s, gust share)
global uniform vec4 wind;
// (seconds between gusts at a spot, metres between gust fronts)
global uniform vec2 wind_shape;
// the wind's own clock, seconds
global uniform float wind_time;

const float WIND_LULL = 0.25;

vec2 wind_direction() {
	return length(wind.xy) > 0.0001 ? normalize(wind.xy) : vec2(1.0, 0.0);
}

// The wind's strength at a world point, as a share of the breeze: about
// 1 - WIND_LULL between gusts, up to 1 + gust as a front rolls past.
float wind_gust(vec3 world) {
	vec2 dir = wind_direction();
	float phase = dot(world.xz, dir) / max(wind_shape.y, 0.01) - wind_time / max(wind_shape.x, 0.01);
	float front = pow(0.5 + 0.5 * sin(6.2831853 * phase), 4.0);
	float ripple = 0.5 + 0.5 * sin(6.2831853 * (phase * 2.37 + 0.31));
	return 1.0 - WIND_LULL + (wind.w + WIND_LULL) * front * (0.75 + 0.25 * ripple);
}

// The wind's level velocity at a world point, m/s.
vec2 wind_velocity(vec3 world) {
	return wind_direction() * wind.z * wind_gust(world);
}

#endif
