shader_type canvas_item;
// The round calls' brush-stroke wipe (milestone-1 task 54): the brushed
// kanji are painted in, left to right, by a front with a soft, ragged edge
// that crosses the label as reveal runs from 0 (nothing) to 1 (all). The
// label is as wide as its text, so size (its size in pixels, set by
// MatchHud) maps the front across the kanji themselves.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec2 size = vec2(1.0, 1.0);
// The edge's softness and how ragged it is, as shares of the width.
uniform float soft = 0.06;
uniform float ragged = 0.1;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float x = local.x / max(size.x, 1.0);
	float y = local.y / max(size.y, 1.0);
	// the bristles: a slow wave and a finer one along the stroke's edge
	float edge = (noise(y * 7.0) - 0.5) * ragged + (noise(y * 29.0 + 3.0) - 0.5) * ragged * 0.5;
	float front = mix(-soft - ragged, 1.0 + soft + ragged, reveal);
	COLOR.a *= 1.0 - smoothstep(front - soft, front + soft, x + edge);
}
