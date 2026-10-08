// An aerial fade of its own toward the horizon's mist, for far scenery that
// the environment's depth fog would leave a flat band (milestone-1 task 51:
// the Shrine's ranges and cliffs, landscape_rock.gdshader, and the far
// buildings on them, surface_far.gdshader). A shader that writes FOG takes
// no environment fog, so the fade stands in for it: it starts fade_start
// metres out, is whole at fade_end, and there reaches fade_most of the mist,
// so ring after ring steps back into the night.

#ifndef AERIAL_FADE_INC
#define AERIAL_FADE_INC

uniform vec4 horizon_color : source_color = vec4(0.2, 0.22, 0.29, 1.0);
uniform float fade_start = 120.0;
uniform float fade_end = 1900.0;
uniform float fade_most : hint_range(0.0, 1.0) = 0.88;

vec4 aerial_fade(vec3 world, vec3 eye) {
	float dist = length(world - eye);
	return vec4(horizon_color.rgb, fade_most * pow(smoothstep(fade_start, fade_end, dist), 0.75));
}

#endif
