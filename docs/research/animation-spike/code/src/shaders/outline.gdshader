shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
// Inverted-hull ink outline (used as next_pass). Width grows with view distance so it stays
// about the same number of pixels on screen. use_color_normal: weapon meshes store a smoothed
// outward normal in COLOR because their facets have split normals.
uniform float width = 0.0016;          // metres per metre of view distance
uniform vec4 ink : source_color = vec4(0.025, 0.02, 0.03, 1.0);
uniform bool use_color_normal = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_cut = 0.0;

void vertex() {
	vec3 n = use_color_normal ? normalize(COLOR.rgb * 2.0 - 1.0) : NORMAL;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = clamp(-vp.z, 0.5, 30.0);
	VERTEX += n * width * dist;
}

void fragment() {
	ALBEDO = ink.rgb;
	if (alpha_cut > 0.0) {
		ALPHA = texture(albedo_tex, UV).a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
}
