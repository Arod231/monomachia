// The Moonlit Shrine's courtyard paving: concentric rings of worn stone tiles
// around a round centre stone with a faded crescent-moon crest, chipped
// edges, cracks and mottling, lit physically (milestone-1 task 43). Since
// milestone-1 task 49 the stone is a scan (Poly Haven's rock_surface, CC0:
// stone_albedo, stone_normal, stone_rough), laid at its own offset and turn on
// each slab and varied per slab in tone; the joints and cracks fill with moss
// and grime (concrete_moss: grime_albedo, grime_normal); and some slabs are
// broken (broken_amount), chunks of them gone to the grit and moss under
// them. Its other noise comes from the look's generated noise texture
// (LookNoise).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/look_noise.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.86;
uniform vec4 stone_light : source_color = vec4(0.47, 0.465, 0.46, 1.0);
uniform vec4 stone_dark : source_color = vec4(0.32, 0.32, 0.36, 1.0);
uniform vec4 grout_color : source_color = vec4(0.13, 0.13, 0.16, 1.0);
uniform vec4 crest_color : source_color = vec4(0.36, 0.1, 0.09, 1.0);
uniform float centre_radius = 2.7;
uniform float ring_width = 1.18;
uniform float tile_length = 1.5;
// The parapet's inner face: grime gathers against it.
uniform float wall_radius = 15.075;
uniform float grout_width = 0.011;
uniform float crack_amount : hint_range(0.0, 1.0) = 0.45;
uniform float long_crack_amount : hint_range(0.0, 1.0) = 1.0;
uniform float crest_strength : hint_range(0.0, 1.0) = 0.42;
uniform float wear : hint_range(0.0, 1.0) = 0.5;
// The scans (task 49): how many metres a tile of them covers, how much of
// the stone scan's own detail and relief the paving takes, and the grime's.
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D grime_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_scans = false;
uniform float scan_size = 1.6;
uniform float scan_detail : hint_range(0.0, 1.0) = 0.7;
uniform float scan_relief : hint_range(0.0, 2.0) = 0.12;
// The scan's mean colour (rock_surface's, linear), so only its detail varies
// the slab's own tone, round 1.
uniform vec3 scan_mean = vec3(0.162, 0.117, 0.087);
uniform vec4 grime_tint : source_color = vec4(0.42, 0.46, 0.36, 1.0);
// How wide the moss and grime spread from a joint (m), and the share of
// slabs broken.
uniform float grime_spread = 0.02;
uniform float broken_amount : hint_range(0.0, 1.0) = 0.14;
// How much the joints wander (the noise's wobble): 0 lays them straight,
// where the modelled slabs' joints are (milestone-1 task 50).
uniform float joint_wobble : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;

float sf_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// The nearest Voronoi cell's id (xy) and its border distance (z) at p.
vec3 sf_cell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(sf_hash(i + g), sf_hash(i + g + 17.1));
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				best = i + g;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(best, f2 - f1);
}

float sf_fbm(vec2 p) {
	return look_noise(p).r * 0.5 + look_noise(p * 2.07 + 5.3).g * 0.3 + look_noise(p * 4.3 + 9.1).b * 0.2;
}

// Distance to the nearest Voronoi cell border (F2 - F1): thin, angular,
// branching lines, like cracks in stone.
float sf_cell_border(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(sf_hash(i + g), sf_hash(i + g + 17.1));
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return f2 - f1;
}

// Crest mask in [0, 1] at p (metres from the centre).
float sf_crest(vec2 p) {
	float r = length(p);
	float ring_outer = smoothstep(0.035, 0.0, abs(r - 2.2) - 0.06);
	float ring_inner = smoothstep(0.03, 0.0, abs(r - 1.86) - 0.025);
	// Crescent: a disc minus an offset disc.
	float moon = smoothstep(1.32, 1.28, length(p));
	float bite = smoothstep(1.12, 1.16, length(p - vec2(0.42, 0.3)));
	float crescent = moon * bite;
	// Eight dots between the rings.
	float a = atan(p.x, p.y);
	float seg = TAU / 8.0;
	float ad = mod(a + seg * 0.5, seg) - seg * 0.5;
	vec2 q = vec2(ad * 2.03, r - 2.03);
	float dots = smoothstep(0.075, 0.05, length(q));
	return max(max(ring_outer, ring_inner), max(crescent, dots));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float r = length(p);
	float ang = atan(p.x, p.y);
	vec2 wob = look_noise(p * 0.7).rg - 0.5;
	float rw = r + wob.x * 0.07 * joint_wobble;
	float edge;
	vec2 id;
	if (rw < centre_radius) {
		// The centre stone, split into four slabs.
		float q = (ang + PI) / (PI * 0.5);
		float qf = fract(q + wob.y * 0.03 * joint_wobble);
		id = vec2(-1.0, floor(q));
		edge = min(centre_radius - rw, min(qf, 1.0 - qf) * (PI * 0.5) * r);
	} else {
		float rr = (rw - centre_radius) / ring_width;
		float ri = floor(rr);
		float rf = fract(rr);
		float rmid = centre_radius + (ri + 0.5) * ring_width;
		float n = max(8.0, floor(TAU * rmid / tile_length));
		// each ring turned by its own share (the golden ratio's, exact in
		// floats, so the modelled slabs can match it: ShrinePlatform.ring_turn())
		float a01 = (ang + PI) / TAU + fract(ri * 0.618034);
		float ta = a01 * n + wob.y * 0.18 * joint_wobble;
		float ti = floor(ta);
		float tf = fract(ta);
		id = vec2(ri, mod(ti, n));
		edge = min(min(rf, 1.0 - rf) * ring_width, min(tf, 1.0 - tf) * TAU * rw / n);
	}
	float h = sf_hash(id + 3.7);
	float h2 = sf_hash(id + 11.3);
	// Pixel footprint in metres (derivatives must be taken outside branches).
	// Fine detail (chips, hairline cracks) is skipped where a pixel covers
	// more than a few centimetres: it would be sub-pixel there anyway.
	float pix = length(fwidth(p));
	bool near = pix < 0.06;
	float chip = near ? (look_noise(p * 9.0).b - 0.5) * 0.022 : 0.0;
	float e = edge + chip;
	// Antialiased with the screen-space rate of change, so joints stay thin
	// lines up close and fade to an even tone far away.
	float fw = max(fwidth(e), 1e-4);
	float grout = 1.0 - smoothstep(grout_width - fw, grout_width + fw, e);

	vec3 col = mix(stone_dark.rgb, stone_light.rgb, 0.3 + 0.55 * h);
	float m = look_noise(p * 0.42 + h * 7.0).r * 0.62 + look_noise(p * 0.87 + 5.3).g * 0.38;
	// Large-scale stains and the mask for long cracks share one fetch.
	vec3 large = look_noise(p * 0.22 + 8.0);
	// Long cracks follow an isoline of a mid-scale noise, warped by the tile
	// wobble so they wander and kink. Its distance to the isoline, in metres,
	// comes from the screen-space gradient (taken here, outside branches).
	float iso = look_noise(p * 0.33 + wob * 0.5 + 3.7).b;
	float iso_dist = abs(iso - 0.5) * pix / max(fwidth(iso), 1e-5);
	col *= 0.82 + 0.36 * m;
	col *= mix(vec3(1.03, 1.0, 0.95), vec3(0.94, 0.98, 1.06), h2);
	// The scan, at its own offset and quarter turn on each slab, so no two
	// neighbours share its pattern, and the slab's own tone over it.
	float turn = floor(h * 4.0) * 1.5707963;
	mat2 rot = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
	vec2 suv = rot * (p / scan_size) + vec2(h, h2) * 17.0;
	vec2 guv = p / (scan_size * 1.3);
	vec3 scan = use_scans ? texture(stone_albedo, suv).rgb : scan_mean;
	col *= mix(vec3(1.0), scan / scan_mean, scan_detail);
	float rough = use_scans ? mix(roughness, texture(stone_rough, suv).g, 0.7) : roughness;
	vec3 nm = use_scans ? texture(stone_normal, suv).rgb * 2.0 - 1.0 : vec3(0.0, 0.0, 1.0);
	nm.xy = rot * nm.xy;
	nm.xy *= scan_relief;
	// A broken slab: chunks of it gone (cells of a coarse Voronoi inside it),
	// grit and moss where they were, the break's edge dark.
	float gone = 0.0;
	float break_edge = 0.0;
	if (sf_hash(id + 29.7) < broken_amount) {
		// Pieces break off at the slab's edges and corners, not its middle.
		vec3 piece = sf_cell(p * 3.2 + id * 3.1);
		if (sf_hash(piece.xy + id) < 0.5 && edge < 0.16 + 0.22 * h2) {
			gone = 1.0;
		} else {
			break_edge = 1.0 - smoothstep(0.0, 0.05 + pix * 2.0, piece.z);
		}
	}
	// Dirt gathers along the joints.
	col *= mix(0.84, 1.0, smoothstep(0.0, 0.08, e));
	// Cracks: angular cell borders on some nearby tiles, partly faded out
	// (the cell search only runs there; branches are coherent per tile), and
	// a few long cracks running across several tiles.
	float crack = 0.0;
	if (near && h2 > 1.0 - crack_amount * 0.45) {
		float cb = sf_cell_border(p * 2.4 + id * 7.3 + wob * 0.7);
		crack = (1.0 - smoothstep(0.0, 0.035 + pix * 2.4, cb)) * smoothstep(0.45, 0.62, look_noise(p * 1.1 + id * 2.3).b);
	}
	float long_mask = smoothstep(0.55, 0.72, large.g) * long_crack_amount;
	crack = max(crack, (1.0 - smoothstep(0.006, 0.006 + pix * 1.2, iso_dist)) * long_mask);
	col = mix(col, grout_color.rgb, crack * 0.7);
	// Stains and grime gathered against the parapet.
	float stain = smoothstep(0.5, 0.85, large.r * 0.7 + m * 0.3);
	col *= 1.0 - 0.28 * stain;
	col *= 1.0 - 0.22 * smoothstep(wall_radius - 2.6, wall_radius + 0.1, r);
	// A faded crest on the centre stone.
	if (r < 2.5) {
		float worn = smoothstep(0.28, 0.62, sf_fbm(p * 2.2 + 3.0));
		col = mix(col, crest_color.rgb * (0.7 + 0.5 * m), sf_crest(p) * crest_strength * worn);
	}
	// Moss and grime in the joints, the cracks and the broken chunks, spreading
	// a little onto the stone at the joints' edges.
	vec3 grime = use_scans ? texture(grime_albedo, guv).rgb * grime_tint.rgb * 2.2 : grout_color.rgb;
	float spread = 1.0 - smoothstep(grout_width, grout_width + grime_spread * (0.4 + look_noise(p * 3.0).r), e);
	float filled = max(max(grout, crack * 0.9), max(gone, break_edge * 0.8));
	float grimy = max(filled, spread * 0.4);
	// Where a piece is gone, grit and broken stone under the moss.
	vec3 grit = mix(grime, stone_dark.rgb * (0.55 + 0.4 * m), 0.55);
	vec3 filler = mix(mix(grime, grit, gone), grout_color.rgb, break_edge * 0.6);
	col = mix(col, filler, grimy * 0.9);
	col = mix(col, grout_color.rgb, grout * 0.35);
	if (use_scans && grimy > 0.0) {
		vec3 gn = texture(grime_normal, guv).rgb * 2.0 - 1.0;
		nm = mix(nm, gn, grimy);
	}
	rough = mix(rough, 0.95, grimy);
	// The fighting area is worn a little smoother and paler.
	col *= 1.0 + wear * 0.12 * (1.0 - smoothstep(4.0, 13.0, r));

	ALBEDO = col;
	ROUGHNESS = rough;
	// The floor lies flat in xz: the scan's u runs along x and its v along z.
	vec3 world_n = normalize(vec3(nm.x, max(nm.z, 0.05), nm.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
}
