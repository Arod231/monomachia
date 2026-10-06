// Katana blade: a dark steel body with a bright, wavy temper line (hamon)
// along the edge, so the blade keeps its value against any background and
// the edge reads at gameplay distance. Toon-lit like every weapon
// (toon_light.gdshaderinc); its material sets the hard steel highlight, and
// ToonMaterials.weapon_from() adds the rim and the ink outline. The blade
// mesh's UV.x runs from 0 at the edge to 1 at the back, UV.y from 0 at the
// guard to 1 at the tip.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec3 steel : source_color = vec3(0.17, 0.18, 0.2);
uniform vec3 hamon : source_color = vec3(0.86, 0.88, 0.9);
// The outline's ink (ToonMaterials sets it on every toon material).
uniform vec4 ink_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
// Blood on the blade (milestone-1 task 38, BloodEffects): 0 clean, 1 the
// most a match gathers, spreading from the tip down and from the edge back.
uniform float blood_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blood_color : source_color = vec3(0.32, 0.012, 0.02);

void fragment() {
	float wave = 0.3 + 0.035 * sin(UV.y * 72.0) + 0.02 * sin(UV.y * 23.0 + 1.3);
	float h = smoothstep(wave + 0.025, wave - 0.025, UV.x);
	ALBEDO = mix(steel, hamon, h);
	if (blood_amount > 0.0) {
		// noise in the blade's own space, so the blood stays put as it swings
		float n = toon_noise3(vec3(UV.x * 6.0, UV.y * 40.0, 0.0));
		float along = smoothstep(0.08, -0.08, (1.0 - blood_amount * 0.85) - UV.y - (n - 0.5) * 0.2);
		float edge = smoothstep(0.12 + 0.55 * blood_amount, 0.0, UV.x + (n - 0.5) * 0.25);
		ALBEDO = mix(ALBEDO, blood_color, clamp(along * edge * 1.4, 0.0, 1.0) * 0.92);
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	toon_brush = toon_noise3((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 2.6) - 0.5;
}
