// Camera-facing flakes for the ash: a soft-edged ellipse in the particle
// colour that spins with the particle's age (INSTANCE_CUSTOM.y) and flips as
// it flutters. near_fade, if set, fades a flake out as it nears the camera,
// where it would cover the fighters as a pale blot.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/particle_billboard.gdshaderinc"

uniform float elongation = 1.6;
// Turns over the particle's life.
uniform float spin = 3.0;
// Gone nearer the camera than near_fade.x metres, whole from near_fade.y;
// off while near_fade.y is 0.
uniform vec2 near_fade = vec2(0.0, 0.0);

varying float age;
varying float seed;
varying float fade;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	seed = float(INSTANCE_ID) * 1.37;
	MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	fade = near_fade_alpha(near_fade, length(MODELVIEW_MATRIX[3].xyz));
}

void fragment() {
	float a = age * spin * 6.2831853 + seed;
	vec2 c = UV - 0.5;
	c = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * c;
	c.x *= elongation;
	// A slow flip makes flakes flutter.
	c.y /= max(abs(sin(a * 0.7)), 0.25);
	float d = length(c) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * (1.0 - smoothstep(0.6, 1.0, d)) * fade;
}
