// Body of the full-screen ink-wash pass, shared by ink_wash.gdshader (depth
// and normal lines) and ink_wash_lite.gdshader (depth lines only: reading the
// normal buffer makes the depth prepass write normals for every object).
// Drawn on a 2x2 quad (InkWashPass) at the start of the transparent pass
// (render_priority -128).
//
// It never reads the screen colour: everything it paints is layered over the
// image with premultiplied alpha, so Godot doesn't have to copy the screen.
// The colour grade lives in the Environment's LUT (InkGrade) instead. Layers,
// bottom to top:
// - distance fade toward mist (the sky keeps its own horizon);
// - ink lines from depth breaks (and normal breaks with INK_NORMALS), with a
//   slight hand-drawn jitter that "boils" a few times a second, dry-brush
//   breaks and a soft bleed halo (quality 3);
// - paper grain, fixed to the screen;
// - a brushy vignette toward ink.
//
// Readability rules: lines fade out with distance, and grain and vignette
// stay weak in the middle of the screen where the fighters are.

render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
#ifdef INK_NORMALS
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
#endif

// InkWashPass.Quality: 1 = fade, grain and vignette; 2 = + ink lines;
// 3 = + jitter, dry-brush breaks and bleed halo.
uniform int quality : hint_range(1, 3) = 3;

group_uniforms colors;
uniform vec4 ink_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform vec4 paper_color : source_color = vec4(0.55, 0.53, 0.5, 1.0);
uniform vec4 mist_color : source_color = vec4(0.22, 0.24, 0.31, 1.0);

group_uniforms lines;
uniform float line_strength : hint_range(0.0, 1.0) = 0.85;
uniform float line_width_px : hint_range(0.5, 4.0) = 2.0;
uniform float depth_threshold : hint_range(0.0, 1.0) = 0.12;
#ifdef INK_NORMALS
uniform float normal_threshold : hint_range(0.0, 2.0) = 0.45;
#endif
uniform float line_fade_start = 18.0;
uniform float line_fade_end = 140.0;
uniform float jitter_px : hint_range(0.0, 4.0) = 0.9;
uniform float boil_fps : hint_range(0.0, 24.0) = 5.0;
uniform float bleed : hint_range(0.0, 1.0) = 0.5;

group_uniforms atmosphere;
uniform float fade_start = 70.0;
uniform float fade_end = 900.0;
uniform float fade_max : hint_range(0.0, 1.0) = 0.35;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.62;

// Inverse linear depth (1 / metres) from the raw depth buffer: for a
// symmetric projection only the z and w rows of the inverse matter.
float inv_depth(vec2 uv, mat4 ip) {
	float raw = texture(depth_tex, uv).r;
	return -(ip[2][3] * raw + ip[3][3]) / (ip[2][2] * raw + ip[3][2]);
}

// Depth edge strength at uv for a sampling radius r (UV units): the second
// difference of inverse depth, which is zero on flat surfaces, so floors seen
// at a grazing angle don't turn black.
float depth_edge(vec2 uv, vec2 r, float inv0, mat4 ip) {
	float l = inv_depth(uv - vec2(r.x, 0.0), ip);
	float rr = inv_depth(uv + vec2(r.x, 0.0), ip);
	float u = inv_depth(uv - vec2(0.0, r.y), ip);
	float d = inv_depth(uv + vec2(0.0, r.y), ip);
	float lap = abs(l + rr - 2.0 * inv0) + abs(u + d - 2.0 * inv0);
	return smoothstep(depth_threshold, depth_threshold * 2.0, lap / inv0);
}

#ifdef INK_NORMALS
float normal_edge(vec2 uv, vec2 r) {
	vec3 l = texture(normal_tex, uv - vec2(r.x, 0.0)).xyz;
	vec3 rr = texture(normal_tex, uv + vec2(r.x, 0.0)).xyz;
	vec3 u = texture(normal_tex, uv - vec2(0.0, r.y)).xyz;
	vec3 d = texture(normal_tex, uv + vec2(0.0, r.y)).xyz;
	// Stored as n * 0.5 + 0.5, so differences are half size.
	float s = (length(l - rr) + length(u - d)) * 2.0;
	return smoothstep(normal_threshold, normal_threshold + 0.35, s);
}
#endif

// Premultiplied "over": paints colour c with coverage a on top of acc.
void paint(inout vec4 acc, vec3 c, float a) {
	acc = vec4(acc.rgb * (1.0 - a) + c * a, acc.a * (1.0 - a) + a);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	// Reversed depth: the sky (the far plane) is 0.
	bool sky = texture(depth_tex, uv).r <= 0.000001;
	mat4 ip = INV_PROJECTION_MATRIX;
	float inv0 = inv_depth(uv, ip);
	float d0 = sky ? 1e6 : 1.0 / max(inv0, 1e-6);
	vec4 acc = vec4(0.0);

	if (!sky) {
		paint(acc, mist_color.rgb, smoothstep(fade_start, fade_end, d0) * fade_max);
		float fade = 1.0 - smoothstep(line_fade_start, line_fade_end, d0);
		if (quality >= 2 && fade > 0.0) {
			vec2 jitter = vec2(0.0);
			float boil = boil_fps > 0.0 ? floor(TIME * boil_fps) : 0.0;
			if (quality >= 3) {
				vec2 q = FRAGCOORD.xy / 9.0 + boil * 17.13;
				jitter = (look_noise_lod0(q).rg - 0.5) * 2.0 * jitter_px * px;
			}
			vec2 r = px * line_width_px;
			// The edge test's centre moves with its neighbours: a centre left
			// behind would read a sloped floor's even change in depth as a
			// break.
			float inv_j = quality >= 3 ? inv_depth(uv + jitter, ip) : inv0;
			float line = depth_edge(uv + jitter, r, inv_j, ip);
#ifdef INK_NORMALS
			line = max(line, normal_edge(uv + jitter, r));
#endif
			if (quality >= 3) {
				// Dry-brush breaks along the line, and a soft wider halo of
				// ink bleeding into the paper around silhouettes.
				float dry = look_noise_lod0(FRAGCOORD.xy / 3.5 + boil * 5.31).b;
				line *= mix(1.0, smoothstep(0.1, 0.55, dry), 0.35);
				line = max(line, depth_edge(uv, r * 2.6, inv0, ip) * 0.3 * bleed);
			}
			paint(acc, ink_color.rgb, clamp(line * line_strength * fade, 0.0, 1.0));
		}
	}

	// Paper grain: light fibres and dark specks, weaker in the middle. Only
	// the stronger part of the noise paints, so the grain reads as sparse
	// fibres and most pixels in the middle are left alone (see the discard).
	vec2 fc = FRAGCOORD.xy;
	float grain = (look_white(fc) * 0.65 + look_noise_lod0(vec2(fc.x * 0.05, fc.y * 0.9)).g * 0.35) * 2.0 - 1.0;
	vec2 c = (uv - 0.5) * vec2(aspect, 1.0);
	float centre = mix(0.45, 1.0, smoothstep(0.15, 0.55, length(c)));
	float ga = smoothstep(0.3, 0.85, abs(grain)) * grain_strength * centre * 1.4;
	paint(acc, grain > 0.0 ? paper_color.rgb : ink_color.rgb, ga);

	// Brushy vignette toward ink.
	float edge_noise = look_noise_lod0(uv * vec2(aspect, 1.0) * 5.0).r * 0.12;
	float v = smoothstep(vignette_radius, vignette_radius + 0.55, length(c) + edge_noise);
	paint(acc, ink_color.rgb * 0.5, v * vignette_strength);

	// Pixels with nothing to paint are dropped: the blend (a read and a write
	// of the HDR colour buffer) is most of this pass's cost on integrated GPUs.
	if (acc.a < 0.003) {
		discard;
	}
	ALBEDO = acc.rgb;
	ALPHA = acc.a;
}
