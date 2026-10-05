// A blade's brush-stroke trail (WeaponTrail): an alpha-blended ribbon in the
// trail's colour (white, red or gold, from the vertex COLOR, whose alpha is
// the trail's strength fading with age) that darkens to an ink edge on the
// tip side, and breaks up into bristle streaks like a dry brush, more and
// more toward the tail. UV.x is the age along the stroke (0 at the blade, 1
// at the tail); UV.y runs across it (0 on the inner edge, 1 at the tip).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look_noise.gdshaderinc"

// The ink of the edge.
uniform vec3 ink : source_color = vec3(0.06, 0.04, 0.07);
// How much of the width the ink edge takes on the tip side.
uniform float ink_edge = 0.24;
// Bristle streaks across the stroke.
uniform float bristles = 16.0;
// The share of the bristles dry at the blade, and at the tail.
uniform float dry_head = 0.3;
uniform float dry_tail = 0.9;

void fragment() {
	float age = UV.x;
	float across = UV.y;
	// bristle streaks run along the stroke: each bristle's noise varies
	// slowly with age, so it reads as a hair of the brush running dry
	vec3 n = look_noise(vec2(across * bristles, age * 2.0));
	// the noise stretched to fill 0 to 1, so the share dry is about right
	float bristle = clamp((n.r * 0.7 + n.g * 0.3 - 0.3) / 0.45, 0.0, 1.0);
	float dry_share = mix(dry_head, dry_tail, age);
	float wet = smoothstep(dry_share - 0.06, dry_share + 0.06, bristle);
	// the brush presses hardest on the tip side: light inside, full at the
	// edge, and soft where the stroke thins out on the inner edge
	float press = mix(0.45, 1.0, smoothstep(0.0, 0.8, across)) * smoothstep(0.0, 0.18, across);
	// the ink edge, ragged with the same bristles
	float edge_from = 1.0 - ink_edge * (0.7 + 0.6 * n.b);
	float edge = smoothstep(edge_from, edge_from + 0.06, across);
	ALBEDO = mix(COLOR.rgb, ink, edge);
	ALPHA = clamp(COLOR.a * press * mix(wet, 1.0, edge * 0.6), 0.0, 1.0);
}
