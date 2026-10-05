// Additive ring for combat effects (CombatEffects' ring pool): a soft band
// at the edge of the quad. Each MultiMesh instance's custom data says how it
// sits: x above 0.5 turns it to face the camera, otherwise it keeps its own
// basis (flat on the ground, say); y is the band's width as a share of the
// radius. The instance colour (COLOR) sets the hue and the fade.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/particle_billboard.gdshaderinc"

uniform float energy = 2.0;

varying float band;

void vertex() {
	band = max(INSTANCE_CUSTOM.y, 0.01);
	if (INSTANCE_CUSTOM.x > 0.5) {
		MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	}
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float r = abs(d - (1.0 - band)) / band;
	float ring = 1.0 - smoothstep(0.0, 1.0, r);
	ALBEDO = COLOR.rgb * energy * ring;
	ALPHA = COLOR.a * ring;
}
