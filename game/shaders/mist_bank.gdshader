// The Moonlit Shrine's banks of mist (milestone-1 task 49): patches of mist
// drifting on the night's wind over the courtyard, thick low down and
// thinning in wisps up through the canopy, for the moon shafts to light. Its
// shape is two scales of the look's noise (LookNoise, set by the arena) in
// world space, carried downwind by the arena's one wind (wind.gdshaderinc,
// milestone-1 task 52), so the banks drift through the still volume and
// surge on as a gust passes; its edges fade out.
shader_type fog;

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D look_noise_tex : filter_linear, repeat_enable;
uniform vec4 albedo : source_color = vec4(0.42, 0.46, 0.56, 1.0);
// The banks' density low down, and the wisps' up high.
uniform float bank_density = 0.15;
uniform float wisp_density = 0.1;
// How wide a bank is (m), how much of the floor they cover, and how deep
// they lie (m).
uniform float bank_size = 9.0;
uniform float cover : hint_range(0.0, 1.0) = 0.5;
uniform float bank_depth = 1.8;
// The share of the edge over which the volume fades out.
uniform float edge_fade = 0.12;

// The look's noise channel c at p (one lattice cell a unit, LookNoise.CELLS
// to the texture).
float mb_noise(vec2 p, int c) {
	vec4 n = textureLod(look_noise_tex, p / 8.0, 0.0);
	return c == 0 ? n.r : (c == 1 ? n.g : n.b);
}

void fog() {
	vec3 w = WORLD_POSITION;
	// how far the wind has carried the air: the breeze, and a gust's surge
	vec2 carried = wind_direction() * wind.z * (wind_time + (wind_gust(w) - 1.0) * 0.8);
	vec2 p = (w.xz - carried) / bank_size;
	// the banks, their edges ragged with a finer noise drifting a little faster
	float n = mb_noise(p, 0) * 0.7 + mb_noise(p * 2.6 - carried * 0.04 + w.y * 0.08, 1) * 0.3;
	float bank = smoothstep(1.0 - cover - 0.12, 1.0 - cover + 0.18, n);
	// thick low down, each bank's top rolling with the noise
	float top = bank_depth * (0.55 + 0.9 * n);
	float low = 1.0 - smoothstep(top * 0.35, top, w.y);
	// the wisps up through the canopy: thin streaks along the wind
	vec2 q = (w.xz - carried * 1.6) / (bank_size * 0.7) + vec2(w.y * 0.13, -w.y * 0.07);
	float wisp = smoothstep(0.35, 0.75, mb_noise(q * vec2(0.6, 1.4), 2)) * smoothstep(0.5, 3.0, w.y);
	// fade out at the volume's sides and top
	vec3 e = min(UVW, 1.0 - UVW);
	float fade = smoothstep(0.0, edge_fade, min(e.x, e.z)) * smoothstep(0.0, edge_fade, 1.0 - UVW.y);
	DENSITY = (bank * low * bank_density + wisp * wisp_density) * fade;
	ALBEDO = albedo.rgb;
}
