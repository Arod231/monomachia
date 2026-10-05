shader_type spatial;
// Wrapped katana grip: black silk wrap crossing over ivory ray-skin, giving the diamond windows.
uniform vec3 ito : source_color = vec3(0.045, 0.04, 0.045);
uniform vec3 same : source_color = vec3(0.78, 0.74, 0.64);

void fragment() {
	vec2 p = vec2(UV.x * 4.0, UV.y * 9.0);
	vec2 q = fract(p) - 0.5;
	float d = abs(q.x) + abs(q.y);
	float window = smoothstep(0.24, 0.20, d);
	// fine weave lines on the wrap
	float weave = 0.85 + 0.15 * step(0.5, fract((p.x + p.y) * 6.0));
	ALBEDO = mix(ito * weave, same, window);
	ROUGHNESS = mix(0.8, 0.6, window);
}
