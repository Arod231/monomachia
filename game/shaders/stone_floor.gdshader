// The Moonlit Shrine's courtyard paving, painted procedurally: concentric rings
// of worn stone tiles around a round centre stone with a faded crescent-moon
// crest, dark grout, chipped edges, cracks and painterly mottling. Lit by the
// shared toon model. No image textures: its noise comes from the look's
// generated noise texture (LookNoise), which is far cheaper than computing it.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// toon_light brings the look's noise (look_noise.gdshaderinc) too.
#include "res://shaders/toon_light.gdshaderinc"

// Set on every toon material (ToonMaterials); the floor has no outline or
// wash to use it.
uniform vec4 ink_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
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

varying vec3 world_pos;

float sf_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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
	float rw = r + wob.x * 0.07;
	float edge;
	vec2 id;
	if (rw < centre_radius) {
		// The centre stone, split into four slabs.
		float q = (ang + PI) / (PI * 0.5);
		float qf = fract(q + wob.y * 0.03);
		id = vec2(-1.0, floor(q));
		edge = min(centre_radius - rw, min(qf, 1.0 - qf) * (PI * 0.5) * r);
	} else {
		float rr = (rw - centre_radius) / ring_width;
		float ri = floor(rr);
		float rf = fract(rr);
		float rmid = centre_radius + (ri + 0.5) * ring_width;
		float n = max(8.0, floor(TAU * rmid / tile_length));
		float a01 = (ang + PI) / TAU + sf_hash(vec2(ri, 4.0));
		float ta = a01 * n + wob.y * 0.18;
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
	// Ink-wash stains and grime gathered against the parapet.
	float stain = smoothstep(0.5, 0.85, large.r * 0.7 + m * 0.3);
	col *= 1.0 - 0.28 * stain;
	col *= 1.0 - 0.22 * smoothstep(wall_radius - 2.6, wall_radius + 0.1, r);
	// A faded crest on the centre stone.
	if (r < 2.5) {
		float worn = smoothstep(0.28, 0.62, sf_fbm(p * 2.2 + 3.0));
		col = mix(col, crest_color.rgb * (0.7 + 0.5 * m), sf_crest(p) * crest_strength * worn);
	}
	col = mix(col, grout_color.rgb, grout * 0.85);
	// The fighting area is worn a little smoother and paler.
	col *= 1.0 + wear * 0.12 * (1.0 - smoothstep(4.0, 13.0, r));

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Cheap brush noise for the band edges: reuse the layout wobble.
	toon_brush = (wob.x + wob.y) * 0.8;
}
