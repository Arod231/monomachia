// What the fight blows across the arena (milestone-1 task 115, ArenaAir):
// the global air_pushes texture holds the pushes the fighters make (a step,
// a low swing, a fall, a blow) and Moonsplitter's waves in flight; grass
// near one bends away from it and springs back over about a second, and a
// big one (the ultimates, the wave, a K.O. near the wall) reaches the
// banners on the ledge through the air. Needs wind.gdshaderinc first (its
// clock). ArenaAir writes the texture each frame:
// - rows 0 and 1, AIR_SLOTS pushes: (x, z, radius over the floor,
//   strength as m/s of wind) and (made, on the wind's clock; its level
//   velocity x and z; radius through the air);
// - rows 2 and 3, AIR_WAVES waves: (origin x, z; direction x, z) and (when
//   its front left the origin, on the wind's clock; its speed m/s; 1 for the
//   horizontal wave, 0 for the vertical; strength, 0 for none);
// - row 3, texel AIR_WAVES: how many pushes are live, listed first.

#ifndef AIR_PUSH_INC
#define AIR_PUSH_INC

global uniform sampler2D air_pushes;

const int AIR_SLOTS = 32;
const int AIR_WAVES = 2;
// How long a push lasts (s), how fast it dies away and how fast it springs.
const float AIR_LIFE = 1.4;
const float AIR_DAMP = 3.2;
const float AIR_SPRING = 6.0;
// The most a push may add to the wind (m/s), so short grass bends and
// doesn't stretch.
const float AIR_MOST = 3.0;
// How far to either side of its line the vertical wave pushes the grass and
// the air (m), and half the horizontal wave's span (MoonWave.SPAN / 2).
const float AIR_WAVE_REACH = 1.6;
const float AIR_WAVE_REACH_ALOFT = 6.0;
const float AIR_WAVE_HALF_SPAN = 15.75;

float air_spring(float age) {
	return exp(-AIR_DAMP * age) * cos(age * AIR_SPRING);
}

// The level push at a world point, as m/s of wind, through the floor
// (aloft false: the grass) or the air (aloft true: the banners).
vec2 air_push(vec3 world, bool aloft) {
	vec2 total = vec2(0.0);
	int live = int(texelFetch(air_pushes, ivec2(AIR_WAVES, 3), 0).x);
	for (int i = 0; i < AIR_SLOTS; i++) {
		if (i >= live) {
			break;
		}
		vec4 a = texelFetch(air_pushes, ivec2(i, 0), 0);
		vec4 b = texelFetch(air_pushes, ivec2(i, 1), 0);
		float age = wind_time - b.x;
		if (age < 0.0 || age > AIR_LIFE) {
			continue;
		}
		float radius = aloft ? b.w : a.z;
		vec2 d = world.xz - a.xy;
		float dist = length(d);
		float near = 1.0 - smoothstep(radius * 0.35, radius, dist);
		if (near <= 0.0) {
			continue;
		}
		vec2 away = dist > 0.001 ? d / dist : vec2(0.0);
		// a moving push leans the grass the way it goes as well as away
		vec2 lean = away + b.yz * 0.25;
		total += lean * a.w * near * air_spring(age);
	}
	for (int k = 0; k < AIR_WAVES; k++) {
		vec4 b = texelFetch(air_pushes, ivec2(k, 3), 0);
		if (b.w <= 0.0) {
			continue;
		}
		vec4 a = texelFetch(air_pushes, ivec2(k, 2), 0);
		vec2 rel = world.xz - a.xy;
		float along = dot(rel, a.zw);
		float side = dot(rel, vec2(-a.w, a.z));
		// how long since its front passed here
		float passed = wind_time - (b.x + along / max(b.y, 0.01));
		if (along < 0.0 || passed < 0.0 || passed > AIR_LIFE) {
			continue;
		}
		float reach = b.z > 0.5 ? AIR_WAVE_HALF_SPAN : (aloft ? AIR_WAVE_REACH_ALOFT : AIR_WAVE_REACH);
		float near = 1.0 - smoothstep(reach * 0.6, reach, abs(side));
		// on along its flight, and out from the vertical wave's line
		vec2 lean = a.zw + (b.z > 0.5 ? vec2(0.0) : vec2(-a.w, a.z) * sign(side) * 0.6);
		total += lean * b.w * near * air_spring(passed);
	}
	float most = length(total);
	return most > AIR_MOST ? total * (AIR_MOST / most) : total;
}

#endif
