// Inverted-hull ink outline, used as the next_pass of a toon material.
// The hull is pushed out along the normal in view space by a width given in
// pixels at 1080p, converted to metres at the vertex's depth, so the line keeps
// roughly the same on-screen width near and far (clamped by min/max_width).
// If the mesh carries smoothed normals in CUSTOM0 (MeshKit bakes them for
// hard-edged props), those are used so box corners don't split the line, and
// CUSTOM0.w stretches the push so every face moves out by the whole width.
// CUSTOM0 doesn't follow skinning, so it suits static meshes only.
// Draws inner contours too (an arm over the torso), unlike a stencil outline.
// tools/shot_scenes/outline_check.tscn measures the lines it draws.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, skip_vertex_transform, shadows_disabled;

uniform vec4 ink_color : source_color = vec4(0.03, 0.03, 0.045, 1.0);
// Line width in pixels on a 1080-pixel-tall screen.
uniform float width_px : hint_range(0.0, 16.0) = 2.4;
// Clamp in metres, so distant hulls don't balloon and close ones stay visible.
uniform float min_width = 0.0015;
uniform float max_width = 0.06;

void vertex() {
	// Shadow maps are drawn from each light's point of view, and a hull drawn
	// there would widen every shadow by the outline. Collapsing every vertex
	// onto one point leaves nothing to draw.
	if (distance(INV_VIEW_MATRIX[3].xyz, MAIN_CAM_INV_VIEW_MATRIX[3].xyz) > 0.001) {
		VERTEX = vec3(0.0);
	} else {
		vec3 n_obj = NORMAL;
		float miter = 1.0;
		if (dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.25) {
			n_obj = CUSTOM0.xyz;
			miter = CUSTOM0.w;
		}
		VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n = normalize(MODELVIEW_NORMAL_MATRIX * n_obj);
		float depth = max(-VERTEX.z, 0.05);
		bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
		// The projection's y scale is negative under Vulkan, which flips Y.
		float metres_per_px = (ortho ? 2.0 : 2.0 * depth) / (abs(PROJECTION_MATRIX[1][1]) * 1080.0);
		float w = clamp(width_px * metres_per_px, min_width, max_width) * step(0.001, width_px);
		VERTEX += n * w * miter;
		NORMAL = n;
	}
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
