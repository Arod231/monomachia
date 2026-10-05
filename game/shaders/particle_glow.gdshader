// Additive, camera-facing glow for lantern halos and embers (and, later,
// sparks). The instance or particle colour (COLOR) sets the hue and the fade;
// energy pushes it bright. toward_camera pulls the quad that many metres
// toward the camera, so a halo centred inside a lantern isn't hidden by the
// lantern's stone. near_fade, if set, fades a glow out as it nears the
// camera (embers), where it would swell into a blot.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/particle_billboard.gdshaderinc"

uniform float energy = 3.0;
uniform float toward_camera = 0.0;
// Gone nearer the camera than near_fade.x metres, whole from near_fade.y;
// off while near_fade.y is 0.
uniform vec2 near_fade = vec2(0.0, 0.0);

varying float fade;

void vertex() {
	MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	fade = near_fade_alpha(near_fade, length(MODELVIEW_MATRIX[3].xyz));
	MODELVIEW_MATRIX[3].xyz -= normalize(MODELVIEW_MATRIX[3].xyz) * toward_camera;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 0.35, d);
	float halo = 1.0 - smoothstep(0.2, 1.0, d);
	ALBEDO = COLOR.rgb * energy * (core * 0.7 + halo * 0.3);
	ALPHA = COLOR.a * halo * fade;
}
