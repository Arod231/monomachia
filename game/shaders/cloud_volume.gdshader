// The sea of clouds as a volume (milestone-1 task 51, Ultra and High): a
// disc laid over the sea's highest tops, from which each pixel marches a ray
// down through the cloud to its floor, or to whatever stands in it (the
// depth buffer: the ranges' and spires' feet), gathering the light it meets.
// Godot's own volumetric fog reaches only a few tens of metres from the
// camera, so the clouds, which lie hundreds of metres off, march their own.
//
// The disc (ShrineBackdrop's CloudVolume) is a shallow cone over the island
// out to the horizon, its height at each distance just over the highest top
// the cloud can reach there, so every ray starts above the cloud.
//
// The cloud is a field of tops: a billowing height over the sea's own
// (cloud_top), rising into fog banks between the ranges (bank_radii,
// bank_heights), thinning where the lake shows through (clearing), and
// drifting with the wind (drift_direction, speed). Inside it the density
// grows down from the top and is broken up by the look's noise. The key
// moonlight lights the tops and leaves the hollows and the undersides of
// the billows in shade, the red moon glows through the cloud toward it, and
// distance fades it to the horizon's mist. Transparent and unshaded, like
// the mesh layers it replaces (cloud_sea.gdshader), which Medium and Low
// draw instead.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

#include "res://shaders/look_noise.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 lit_color : source_color = vec4(0.42, 0.45, 0.56, 1.0);
uniform vec4 shade_color : source_color = vec4(0.06, 0.07, 0.1, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.2, 0.22, 0.29, 1.0);
uniform vec4 moon_tint : source_color = vec4(0.45, 0.12, 0.09, 1.0);
uniform vec3 moon_direction = vec3(0.0, 0.25, 1.0);
// The direction the key moonlight comes from.
uniform vec3 key_direction = vec3(-0.6, 0.66, -0.16);
// The sea's own top (the veil's height), how far the billows rise over it,
// and the cloud's floor.
uniform float cloud_top = -46.0;
uniform float billow = 9.0;
uniform float cloud_floor = -76.0;
// Fog banks between the ranges: their distances from the shrine, and how
// high over the sea each rises.
uniform vec4 bank_radii = vec4(385.0, 585.0, 850.0, 0.0);
uniform vec4 bank_heights = vec4(14.0, 20.0, 24.0, 0.0);
uniform float bank_width = 55.0;
// Noise cells per metre, for the billows and for the cloud's inside.
uniform float scale = 0.018;
uniform float detail_scale = 0.06;
// How thick the cloud gets (per metre), and the light's extinction through it.
uniform float density = 0.07;
uniform float shade_depth = 6.0;
// Noise cells per second the cloud drifts, and which way: level, a unit
// vector (the wind's).
uniform float speed = 0.012;
uniform vec2 drift_direction = vec2(-0.944, -0.33);
uniform float fade_start = 260.0;
uniform float fade_end = 1900.0;
// A gap in the clouds (x, z, radius) so the lake below can show.
uniform vec3 clearing = vec3(0.0, 0.0, 0.0);
uniform int steps = 28;
uniform float max_march = 700.0;

varying vec3 world_pos;

vec3 cloud_fbm(vec2 p) {
	return look_noise(p) * 0.5
		+ look_noise(p * 2.1 + vec2(3.7, 1.9)) * 0.25
		+ look_noise(p * 4.41 + vec2(11.4, 5.9)) * 0.125
		+ look_noise(p * 9.26 + vec2(27.6, 14.3)) * 0.0625;
}

// The cloud's top over the level point xz, and how open the clearing leaves
// it (0 in the gap, 1 clear of it).
vec2 top_at(vec2 xz, vec2 drift) {
	vec2 p = xz * scale - drift;
	vec2 warp = cloud_fbm(p + 1.7).rg;
	float c = cloud_fbm(p + warp * 1.6).b;
	float r = length(xz);
	float banks = 0.0;
	for (int i = 0; i < 4; i++) {
		if (bank_heights[i] > 0.0) {
			float d = (r - bank_radii[i]) / bank_width;
			banks += bank_heights[i] * exp(-d * d) * (0.55 + 0.9 * c);
		}
	}
	float open = 1.0;
	if (clearing.z > 0.0) {
		float dc = length(xz - clearing.xy) / clearing.z;
		open = smoothstep(0.55, 1.05, dc + (c - 0.5) * 0.5);
	}
	// the noise's middle stretched to the billows' full height, their tops
	// rounded
	float b = smoothstep(0.3, 0.7, c);
	float top = cloud_top + (sqrt(b) * 2.0 - 1.0) * billow + banks;
	return vec2(mix(cloud_floor + 2.0, top, open), open);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 dir = normalize(world_pos - eye);
	float entry = length(world_pos - eye);
	// how far the ray may go: to the cloud's floor, or to what stands there
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene = length(view.xyz / view.w);
	float to_floor = dir.y < -1e-4 ? (cloud_floor - world_pos.y) / dir.y : max_march;
	float span = min(min(to_floor, scene - entry), max_march);
	if (span <= 0.0) {
		discard;
	}
	vec2 drift = drift_direction * TIME * speed;
	vec3 key = normalize(key_direction);
	vec3 moon = normalize(moon_direction);
	float jitter = texture(look_noise_tex, FRAGCOORD.xy / 256.0).a;
	float dt = span / float(steps);
	float transmit = 1.0;
	vec3 light = vec3(0.0);
	float glow = pow(max(dot(dir, moon), 0.0), 6.0);
	for (int i = 0; i < steps; i++) {
		vec3 p = world_pos + dir * dt * (float(i) + jitter);
		vec2 t = top_at(p.xz, drift);
		float below = t.x - p.y;
		if (below <= 0.0) {
			continue;
		}
		float inside = look_noise3(p * detail_scale + vec3(drift.x, 0.0, drift.y) * 4.0);
		float d = density * smoothstep(0.0, 5.0, below) * (0.45 + 0.9 * inside) * t.y;
		if (d <= 0.0) {
			continue;
		}
		// the key light reaches in from the top, less under a higher top
		// toward it (the billows shade one another)
		float toward = top_at(p.xz + key.xz / max(key.y, 0.2) * 6.0, drift).x - p.y;
		float lit = exp(-max(below, 0.0) / shade_depth) * exp(-max(toward - below, 0.0) * 0.35);
		vec3 col = mix(shade_color.rgb, lit_color.rgb, clamp(lit, 0.0, 1.0));
		col += moon_tint.rgb * glow * (0.35 + 0.65 * exp(-below / (shade_depth * 2.0)));
		float absorb = exp(-d * dt);
		light += transmit * (1.0 - absorb) * col;
		transmit *= absorb;
		if (transmit < 0.02) {
			break;
		}
	}
	// what the ray leaves at the cloud's floor: the sea's dense depths, but
	// in the clearing, where the lake shows
	if (span >= to_floor - 0.01 && transmit > 0.0) {
		vec2 t = top_at(world_pos.xz + dir.xz * to_floor, drift);
		light += transmit * t.y * shade_color.rgb * 0.8;
		transmit *= 1.0 - t.y;
	}
	float alpha = 1.0 - transmit;
	if (alpha <= 0.002) {
		discard;
	}
	vec3 col = light / alpha;
	float far = smoothstep(fade_start, fade_end, length(world_pos.xz - eye.xz));
	ALBEDO = mix(col, horizon_color.rgb, far);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
