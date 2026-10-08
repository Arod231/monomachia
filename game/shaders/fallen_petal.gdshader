shader_type spatial;
// The Shrine's fallen petals (milestone-1 task 137, ShrineFallenPetals): a
// wisteria petal cut from a unit plane, seen from both sides, glowing neon
// lavender. Each petal's custom data holds when its glow last flared (x, in
// the petals' own clock, `now`) and a per-petal tint (y): it glows fully
// while falling or kicked up, then dims over settle_time to settled_glow
// once it lies still. At match point (doom) it turns blood red with the
// canopy. A light of its own: it takes no shadow and skips the mist, as the
// blossoms' glow does.
render_mode cull_disabled, shadows_disabled, fog_disabled;

uniform float now = 0.0;
uniform float doom : hint_range(0.0, 1.0) = 0.0;
uniform float settle_time = 10.0;
uniform float settled_glow = 0.35;
uniform vec3 glow_color = vec3(2.1, 0.4, 2.5);
uniform vec3 doom_color = vec3(1.3, 0.0, 0.0);

varying float v_glow_from;
varying float v_tint;

void vertex() {
	v_glow_from = INSTANCE_CUSTOM.x;
	v_tint = INSTANCE_CUSTOM.y;
}

void fragment() {
	// a rounded petal narrowing to its base at one end
	vec2 p = UV * 2.0 - 1.0;
	float width = mix(0.22, 0.62, smoothstep(-1.0, 0.25, p.y));
	float d = length(vec2(p.x / width, p.y));
	if (d > 1.0) {
		discard;
	}
	float glow = mix(1.0, settled_glow, smoothstep(0.0, settle_time, now - v_glow_from));
	vec3 col = mix(glow_color, doom_color, doom) * (0.85 + 0.3 * v_tint);
	// brighter along the middle, softer at the edge and the base
	float body = 0.7 + 0.3 * (1.0 - d * d);
	ALBEDO = col * 0.08;
	ROUGHNESS = 0.6;
	EMISSION = col * glow * body;
}
