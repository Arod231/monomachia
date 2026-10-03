// A soft camera-facing puff of mist or cloud, for MultiMesh clusters on the
// sea of clouds, at the foot of waterfalls and round the crag's tip. Fades
// where it meets solid geometry (depth fade), so puffs never show a hard
// intersection line. The backdrop sets the look's noise texture.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform vec4 lit_color : source_color = vec4(0.42, 0.45, 0.55, 1.0);
uniform vec4 shade_color : source_color = vec4(0.12, 0.13, 0.18, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.55;
uniform float depth_fade = 6.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

// A different patch of noise per puff, from where it stands.
varying float seed;

void vertex() {
	seed = fract(MODEL_MATRIX[3].x * 0.137 + MODEL_MATRIX[3].z * 0.071);
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 c = UV - 0.5;
	float n = look_noise(UV * 4.0 + seed * 31.0 + TIME * 0.03).r * 0.6 + look_noise(UV * 9.0 + seed * 7.0).g * 0.4;
	float a = smoothstep(0.5, 0.1, length(c) + (n - 0.5) * 0.3);
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_depth = -sv.z / sv.w;
	float soft = clamp((scene_depth - (-VERTEX.z)) / depth_fade, 0.0, 1.0);
	ALBEDO = mix(shade_color.rgb, lit_color.rgb, smoothstep(0.1, 0.6, -c.y + n * 0.5));
	ALPHA = a * opacity * soft;
}
