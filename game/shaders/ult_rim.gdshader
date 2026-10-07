// The ultimate-ready aura's rim glow (UltAura, milestone-1 task 100): a faint
// glow in the side's colour along the body's silhouette, drawn over its
// meshes as a material overlay, breathing slowly. Steady, so Reduce flashes
// keeps it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform float amount = 0.55;
uniform float power = 2.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	float breathe = 0.85 + 0.15 * sin(TIME * 2.2);
	ALBEDO = color.rgb * rim * amount * breathe;
}
