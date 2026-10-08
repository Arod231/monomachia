// Night sky for the Moonlit Shrine: a dark ink gradient with a cold mist band
// at the horizon, stars, streaks of ink cloud, and a large blood-red moon
// with a red haze. The arena sets moon_direction from its layout, the
// horizon to its depth fog's colour, and the look's noise texture. Since
// milestone-1 task 49 the stars are many, of varied size and colour, some
// twinkling, with a faint Milky Way away from the moon (milky_way_pole, which
// the arena sets from the moon). The twinkling (TIME) stays out of the
// cubemap passes, so a radiance map, where an environment takes one, stays
// still.
shader_type sky;

#include "res://shaders/look_noise.gdshaderinc"

uniform vec3 moon_direction = vec3(0.38, 0.226, 0.897);
uniform vec4 zenith_color : source_color = vec4(0.012, 0.013, 0.024, 1.0);
uniform vec4 sky_color : source_color = vec4(0.035, 0.04, 0.066, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.2, 0.22, 0.29, 1.0);
uniform vec4 below_color : source_color = vec4(0.17, 0.18, 0.24, 1.0);
uniform vec4 haze_color : source_color = vec4(0.36, 0.08, 0.06, 1.0);
uniform vec4 moon_color : source_color = vec4(0.95, 0.24, 0.14, 1.0);
uniform vec4 moon_shadow_color : source_color = vec4(0.4, 0.06, 0.045, 1.0);
// The moon's angular radius, in radians.
uniform float moon_radius = 0.085;
uniform float moon_energy = 1.8;
uniform float haze_strength = 0.35;
uniform float star_amount = 0.75;
// How far the stars' colours spread from white, toward blue and orange; how
// deeply the twinkling ones dim; the Milky Way's brightness, the pole of its
// great circle and its half-width (as the sine of an angle).
uniform float star_colour_spread : hint_range(0.0, 1.0) = 0.6;
uniform float twinkle : hint_range(0.0, 1.0) = 0.55;
uniform float milky_way : hint_range(0.0, 1.0) = 0.1;
uniform vec3 milky_way_pole = vec3(0.5, 0.4, 0.75);
uniform float milky_way_width = 0.16;
uniform vec4 cloud_color : source_color = vec4(0.018, 0.018, 0.028, 1.0);
uniform vec4 cloud_edge_color : source_color = vec4(0.40, 0.12, 0.10, 1.0);
uniform float cloud_amount = 0.85;
// How brightly the moon lights the clouds round it (0: dark silhouettes),
// their edges facing it brightest, so they glow.
uniform float cloud_moon_glow = 0.0;

// The moon's seas, laid out like the real moon's face: centre (x right, y up)
// and radius, in moon radii. They overlap into the familiar dark shapes.
const vec3 MOON_SEAS[12] = vec3[](
	vec3(-0.58, 0.05, 0.42), vec3(-0.32, 0.42, 0.34), vec3(0.15, 0.40, 0.22), vec3(0.30, 0.12, 0.26),
	vec3(0.66, 0.30, 0.14), vec3(0.52, -0.12, 0.19), vec3(0.32, -0.27, 0.13), vec3(-0.18, -0.38, 0.24),
	vec3(-0.50, -0.38, 0.14), vec3(-0.15, 0.68, 0.14), vec3(0.15, 0.66, 0.12), vec3(0.0, 0.15, 0.15)
);

// A random value in [0, 1) per star cell.
float sky_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Four octaves of the look's noise, one texture fetch each.
float sky_fbm(vec2 p) {
	return look_noise(p).r * 0.5
		+ look_noise(p * 2.03 + vec2(13.1, 7.7)).g * 0.25
		+ look_noise(p * 4.12 + vec2(3.4, 19.2)).b * 0.125
		+ look_noise(p * 8.37 + vec2(11.8, 5.3)).r * 0.0625;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 m = normalize(moon_direction);
	float h = d.y;

	// Gradient: mist band at the horizon, ink toward the zenith, mist below.
	float up = max(h, 0.0);
	vec3 col = mix(horizon_color.rgb, sky_color.rgb, smoothstep(0.0, 0.2, up));
	col = mix(col, zenith_color.rgb, smoothstep(0.18, 0.8, up));
	col = mix(col, below_color.rgb, smoothstep(0.0, -0.1, h));

	// Red haze around the moon, stronger along the horizon.
	float cosang = dot(d, m);
	float ang = acos(clamp(cosang, -1.0, 1.0));
	float haze = exp(-ang * 3.2) * 0.55 + exp(-ang * 11.0) * 0.9;
	haze *= mix(1.0, 1.6, smoothstep(0.35, 0.0, abs(h)));
	col += haze_color.rgb * haze * haze_strength;

	// The Milky Way: a faint band along the great circle round
	// milky_way_pole, mottled and torn by dark lanes of dust; and the stars,
	// in three layers from many faint ones to a few bright ones (one
	// candidate per cell of a direction grid), thicker in the band, tinted
	// blue to orange, some twinkling; none near the moon or the horizon.
	if (h > 0.0) {
		float shown = smoothstep(0.02, 0.25, h) * smoothstep(0.15, 0.4, ang);
		vec3 pole = normalize(milky_way_pole);
		vec3 ax = normalize(cross(pole, abs(pole.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		vec3 ay = cross(pole, ax);
		float across = dot(d, pole);
		vec2 gp = vec2(atan(dot(d, ay), dot(d, ax)) * 2.5, across * 9.0);
		float band = exp(-across * across / (milky_way_width * milky_way_width));
		float lanes = smoothstep(0.48, 0.66, sky_fbm(gp * 1.7 + vec2(5.0, 2.0)));
		float glow = band * (0.45 + 0.55 * sky_fbm(gp * 0.8 + vec2(1.0, 7.0))) * (1.0 - 0.75 * lanes * band);
		// grained with stars too faint to see one by one
		glow *= 0.55 + 0.9 * look_noise(gp * 14.0 + vec2(3.0, 1.0)).g * look_noise(gp * 31.0).b;
		col += vec3(0.5, 0.54, 0.68) * glow * milky_way * shown;
		for (int layer = 0; layer < 3; layer++) {
			float scale = layer == 0 ? 300.0 : (layer == 1 ? 150.0 : 70.0);
			float keep = layer == 0 ? 0.95 - band * 0.05 : (layer == 1 ? 0.975 : 0.988);
			vec3 g = d * scale;
			vec3 cell = floor(g);
			float lc = float(layer) * 31.7;
			float s = sky_hash(cell + lc);
			if (s > keep) {
				vec3 centre = cell + 0.5 + (vec3(sky_hash(cell + 1.3 + lc), sky_hash(cell + 2.7 + lc), sky_hash(cell + 5.1 + lc)) - 0.5) * 0.6;
				float dist = length(g - centre);
				float size = layer == 0 ? 0.24 : (layer == 1 ? 0.3 : 0.34);
				float b = smoothstep(size, 0.0, dist) * (s - keep) / (1.0 - keep);
				b *= layer == 0 ? 0.45 : (layer == 1 ? 1.0 : 2.4);
				float temp = sky_hash(cell + 9.3 + lc);
				vec3 tint = mix(vec3(1.0, 0.7, 0.48), vec3(0.66, 0.78, 1.0), temp);
				tint = mix(vec3(0.8, 0.84, 0.95), tint, star_colour_spread);
				float tw = sky_hash(cell + 4.4 + lc);
				if (!AT_CUBEMAP_PASS && tw < 0.45) {
					b *= 1.0 - twinkle * (0.5 + 0.5 * sin(TIME * (1.5 + 5.0 * tw) + temp * 40.0));
				}
				col += tint * b * star_amount * shown;
			}
		}
	}

	// The moon: a sphere's face (features foreshortened toward the limb) with
	// soft seas warped by noise, grainy highlands, craters with dark floors
	// and lit rims, one bright rayed crater, limb darkening, and an eclipse's
	// shading, darker crimson toward one edge and brighter copper toward the
	// other. p is the point on its face, in moon radii, x right and y up
	// (toward the zenith, or toward -Z for a moon straight overhead).
	vec3 face_x = normalize(cross(m, abs(m.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, -1.0)));
	vec3 face_y = cross(face_x, m);
	vec2 p = vec2(dot(d, face_x), dot(d, face_y)) / moon_radius;
	float r = length(p);
	if (cosang > 0.0 && r < 1.05) {
		vec3 n = vec3(p, sqrt(max(1.0 - r * r, 0.0)));
		// the surface's own coordinates: longitude and latitude, about -1 to 1
		vec2 uv = vec2(atan(n.x, max(n.z, 1e-4)), asin(clamp(n.y, -1.0, 1.0))) / 1.5707963;
		// seas: the familiar shapes, their shores ragged at two scales
		vec2 q = uv + (vec2(sky_fbm(uv * 1.6 + vec2(3.0, 1.0)), sky_fbm(uv * 1.6 + vec2(8.0, 5.0))) - 0.5) * 0.34;
		float seas = 0.0;
		for (int i = 0; i < 12; i++) {
			seas += 1.0 - smoothstep(MOON_SEAS[i].z * 0.35, MOON_SEAS[i].z * 1.35, length(q - MOON_SEAS[i].xy));
		}
		seas = clamp(seas, 0.0, 1.0) * mix(0.7, 1.0, sky_fbm(uv * 5.0 + vec2(2.0, 9.0)));
		float light = 1.0 - seas * 0.85;
		// highlands: a soft mottle
		light += (sky_fbm(uv * 5.0 + vec2(11.0, 2.0)) - 0.5) * 0.16 * (1.0 - seas * 0.6);
		// a few soft craters: a darker floor and a faint rim lit from the
		// upper left
		for (int level = 0; level < 1; level++) {
			float scale = level == 0 ? 6.0 : 13.0;
			vec2 g = uv * scale;
			vec2 cell = floor(g);
			for (int j = -1; j <= 1; j++) {
				for (int i = -1; i <= 1; i++) {
					vec2 c = cell + vec2(float(i), float(j));
					float h = sky_hash(vec3(c, float(level) * 7.0 + 3.0));
					if (h > (level == 0 ? 0.28 : 0.4)) {
						continue;
					}
					vec2 centre = c + vec2(sky_hash(vec3(c, 11.0)), sky_hash(vec3(c, 23.0)));
					float rad = mix(0.08, 0.34, pow(sky_hash(vec3(c, 37.0)), 2.0));
					vec2 v = g - centre;
					float dd = length(v) / rad;
					float floor_dark = (1.0 - smoothstep(0.3, 1.0, dd)) * 0.1;
					float rim = smoothstep(0.7, 1.0, dd) * (1.0 - smoothstep(1.0, 1.4, dd));
					float lit = dot(normalize(v + 1e-5), normalize(vec2(-0.6, 0.8)));
					light += -floor_dark + rim * (0.02 + 0.04 * lit);
				}
			}
		}
		// a bright young crater low on the face, its rays across the seas
		vec2 t = uv - vec2(-0.08, -0.6);
		float td = length(t);
		float rays = pow(abs(sin(atan(t.y, t.x) * 9.0 + sky_fbm(t * 3.0) * 6.0)), 18.0) * exp(-td * 3.2);
		light += rays * 0.08 + (1.0 - smoothstep(0.03, 0.08, td)) * 0.12;
		light = clamp(light, 0.12, 1.4);
		// the eclipse: brighter copper toward the lower left, deep crimson
		// toward the upper right
		float side = smoothstep(-0.9, 0.9, dot(p, normalize(vec2(-0.55, -0.85))));
		vec3 mc = mix(moon_shadow_color.rgb, moon_color.rgb, clamp(light, 0.0, 1.0)) * max(light, 1.0);
		mc *= mix(vec3(0.8, 0.75, 0.8), vec3(1.08, 1.3, 1.1), side);
		// a little limb darkening, and a soft edge
		mc *= mix(0.7, 1.0, pow(n.z, 0.5));
		float disc = smoothstep(1.0, 0.985, r);
		col = mix(col, mc * moon_energy, disc);
	}

	// Ink cloud streaks, projected on a high plane; thin and torn near the moon.
	if (h > -0.02) {
		vec2 uv = d.xz / (h + 0.09);
		float c = sky_fbm(vec2(uv.x * 0.32, uv.y * 1.25) + vec2(4.0, 0.0));
		float band = smoothstep(0.0, 0.07, h) * (1.0 - smoothstep(0.32, 0.6, h));
		float mask = smoothstep(0.52, 0.72, c) * band * cloud_amount;
		float edge = smoothstep(0.52, 0.6, c) - smoothstep(0.6, 0.72, c);
		vec3 cc = mix(cloud_color.rgb, cloud_edge_color.rgb, clamp(edge * haze * 1.6, 0.0, 1.0));
		// lit by the moon: the nearer it, the brighter, the edges most
		float lit = exp(-ang * 4.5) * 0.8 + exp(-ang * 14.0) * 2.2;
		cc += moon_color.rgb * moon_energy * lit * cloud_moon_glow * (0.35 + 1.4 * edge);
		col = mix(col, cc, mask);
	}

	COLOR = col;
}
