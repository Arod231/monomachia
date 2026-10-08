// The Moonlit Shrine's distant ranges and cliff spires (milestone-1 task
// 51), lit physically: Poly Haven's rock_surface scan (stone_*) laid over
// them by world position from three sides (triplanar), at a near tile and a
// far one so it reads both on the spires and across a range, its colour the
// scan's detail on the night's cool rock; moss and grime (concrete_moss,
// grime_*) gather on the tops and ledges and where the sculpt says water runs
// (UV.x, the Blender script's "Mask": the gullies and fissures, also darker
// and damper), and the rock darkens down toward the sea of clouds (UV.y: 0
// there, 1 at the crest). Its other noise comes from the look's noise
// texture (LookNoise). It fades into the horizon's mist by the aerial fade
// (aerial_fade.gdshaderinc), gentler than the environment's depth fog. Far scenery: no
// shadows (the builder turns them off).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/look_noise.gdshaderinc"
#include "res://shaders/aerial_fade.gdshaderinc"

uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D grime_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres a tile of the scans covers, near and far.
uniform float near_tile = 7.0;
uniform float far_tile = 55.0;
// The scan's mean colour (rock_surface's, linear), so only its detail
// varies the rock's own tone, round 1.
uniform vec3 scan_mean = vec3(0.162, 0.117, 0.087);
uniform vec4 rock_light : source_color = vec4(0.36, 0.37, 0.41, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.17, 0.175, 0.2, 1.0);
uniform vec4 moss_color : source_color = vec4(0.16, 0.2, 0.15, 1.0);
// How much moss the tops and ledges, and the wet runs, take.
uniform float moss_on_tops : hint_range(0.0, 1.0) = 0.75;
uniform float moss_in_runs : hint_range(0.0, 1.0) = 0.5;
// How dark the rock grows down toward the clouds, and in the runs.
uniform float foot_shade : hint_range(0.0, 1.0) = 0.55;
uniform float run_shade : hint_range(0.0, 1.0) = 0.4;
uniform float relief : hint_range(0.0, 2.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 1e-4);
}

vec3 tri_color(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}

float tri_value(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).g * w.x + texture(tex, p.xz).g * w.y + texture(tex, p.xy).g * w.z;
}

// The scan's normal map from three sides, whiteout-blended onto the world
// normal n.
vec3 tri_normal(sampler2D tex, vec3 p, vec3 n, vec3 w, float strength) {
	vec3 tx = texture(tex, p.zy).rgb * 2.0 - 1.0;
	vec3 ty = texture(tex, p.xz).rgb * 2.0 - 1.0;
	vec3 tz = texture(tex, p.xy).rgb * 2.0 - 1.0;
	tx.xy *= strength;
	ty.xy *= strength;
	tz.xy *= strength;
	vec3 nx = vec3(0.0, tx.y, tx.x) * sign(n.x);
	vec3 ny = vec3(ty.x, 0.0, ty.y) * sign(n.y);
	vec3 nz = vec3(tz.x, tz.y, 0.0) * sign(n.z);
	return normalize(n + nx * w.x + ny * w.y + nz * w.z);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = tri_weights(n);
	vec3 pn = world_pos / near_tile;
	vec3 pf = world_pos / far_tile + vec3(0.37, 0.11, 0.73);
	float lum_mean = dot(scan_mean, vec3(0.299, 0.587, 0.114));
	float near_detail = dot(tri_color(stone_albedo, pn, w), vec3(0.299, 0.587, 0.114)) / lum_mean;
	float far_detail = dot(tri_color(stone_albedo, pf, w), vec3(0.299, 0.587, 0.114)) / lum_mean;
	float big = look_noise3(world_pos * 0.012);
	vec3 rock = mix(rock_dark.rgb, rock_light.rgb, clamp(big * 1.2 - 0.1, 0.0, 1.0));
	rock *= clamp(mix(1.0, near_detail, 0.6) * mix(1.0, far_detail, 0.7), 0.25, 2.2);
	// the moss: on the tops and ledges, broken up, and down the wet runs
	float wet = clamp(UV.x, 0.0, 1.0);
	float up = smoothstep(0.55, 0.9, n.y);
	float breakup = smoothstep(0.35, 0.65, look_noise3(world_pos * 0.08 + vec3(3.1)));
	float moss = clamp(up * moss_on_tops * breakup + smoothstep(0.35, 0.8, wet) * moss_in_runs, 0.0, 1.0);
	vec3 grime = tri_color(grime_albedo, pn * 0.8, w);
	vec3 moss_col = moss_color.rgb * (dot(grime, vec3(0.299, 0.587, 0.114)) / 0.25);
	vec3 col = mix(rock, moss_col, moss);
	col *= 1.0 - run_shade * smoothstep(0.3, 0.9, wet);
	col *= mix(1.0 - foot_shade, 1.0, smoothstep(0.0, 0.75, clamp(UV.y, 0.0, 1.0)));
	ALBEDO = col;
	ROUGHNESS = clamp(mix(roughness, tri_value(stone_rough, pn, w), 0.5) - wet * 0.15, 0.3, 1.0);
	vec3 nw = tri_normal(stone_normal, pn, n, w, relief);
	nw = normalize(mix(nw, tri_normal(grime_normal, pn * 0.8, n, w, relief), moss * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	FOG = aerial_fade(world_pos, CAMERA_POSITION_WORLD);
}
