// Shared toon lighting for every toon-lit surface in Monomachia (fighters,
// weapons, props, stone, rock). Include it after `shader_type spatial;` and the
// render_mode line; it supplies the uniforms below and light().
//
// Lighting model:
// - three soft-edged bands (shadow, mid, lit) from N·L times ATTENUATION, so
//   cast shadows and omni-light falloff snap into the same bands;
// - a world-space "brush" noise nudges the band edges so the terminator reads
//   as a painted stroke rather than a clean CG line (the including shader sets
//   `toon_brush` in fragment(), usually from toon_noise3());
// - directional lights add a faint cold fill on the unlit side (shadow_tint),
//   which keeps shadows moonlit blue instead of dead black;
// - a light-facing rim and an optional hard toon specular go to SPECULAR_LIGHT.

uniform vec4 shadow_tint : source_color = vec4(0.42, 0.52, 0.74, 1.0);
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.12;
uniform float band_mid : hint_range(0.0, 1.0) = 0.55;
uniform float band_low : hint_range(0.0, 1.0) = 0.10;
uniform float band_high : hint_range(0.0, 1.0) = 0.50;
uniform float band_softness : hint_range(0.0, 0.25) = 0.035;
uniform float brush_noise : hint_range(0.0, 0.5) = 0.10;
// Rim: off by default (a floor seen at a grazing angle would glow all over);
// ToonMaterials turns it on for rounded things like fighters and weapons.
// rim_width is the fraction of the silhouette band that lights up.
uniform vec4 rim_color : source_color = vec4(0.72, 0.82, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.25;
uniform float specular_strength : hint_range(0.0, 4.0) = 0.0;
uniform float specular_size : hint_range(0.0, 1.0) = 0.12;

varying float toon_brush;

#include "res://shaders/look_noise.gdshaderinc"

// Value noise in [0, 1] at a world position: one fetch of the shared noise
// texture (LookNoise) on a skewed plane, so it varies across floors and walls
// alike. Much cheaper than true 3D value noise on integrated GPUs.
float toon_noise3(vec3 p) {
	return look_noise(p.xz + p.y * vec2(0.37, 0.71)).r;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Directional lights: band N·L, then multiply by a softened shadow term.
	// Thresholding the shadow itself would turn shadow-map texels into
	// stair-steps; the PCF gradient makes a soft, brushy shadow edge instead.
	// Omni and spot lights: band N·L times distance falloff, so lantern light
	// falls off in painted rings.
	float shadow = 1.0;
	float lit = clamp(ndl, 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		shadow = smoothstep(0.1, 0.9, ATTENUATION + toon_brush * brush_noise);
	} else {
		lit *= ATTENUATION;
	}
	lit += toon_brush * brush_noise;
	float s = band_softness;
	float b1 = smoothstep(band_low - s, band_low + s, lit);
	float b2 = smoothstep(band_high - s, band_high + s, lit);
	float band = (b1 * band_mid + b2 * (1.0 - band_mid)) * shadow;
	vec3 lc = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += lc * band;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += lc * (1.0 - b1 * shadow) * shadow_fill * shadow_tint.rgb;
	}

	// Rim and highlight come from the moon lights only: lantern light stays a
	// plain warm pool, and the omni path stays cheap.
	if (LIGHT_IS_DIRECTIONAL && rim_strength > 0.0) {
		float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = smoothstep(1.0 - rim_width - 0.04, 1.0 - rim_width + 0.04, 1.0 - ndv);
		float rim_mask = rim * smoothstep(-0.15, 0.3, ndl) * ATTENUATION;
		SPECULAR_LIGHT += lc * rim_color.rgb * rim_mask * rim_strength;
	}
	if (LIGHT_IS_DIRECTIONAL && specular_strength > 0.0) {
		vec3 hv = normalize(VIEW + LIGHT);
		float nh = clamp(dot(NORMAL, hv), 0.0, 1.0);
		float spec = smoothstep(1.0 - specular_size - 0.015, 1.0 - specular_size + 0.015, nh * nh);
		SPECULAR_LIGHT += lc * spec * specular_strength * ATTENUATION;
	}
}
