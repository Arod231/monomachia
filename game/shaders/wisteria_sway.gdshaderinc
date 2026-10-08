// How the arena's one wind (wind.gdshaderinc, milestone-1 task 52) moves the
// wisteria: the thin outer branches sway, more the further out from the
// trunk's axis and the higher up they are, while the trunk and the thick
// limbs near it stay still (the owner's choice, Oct 8). The racemes hang
// from the branch tips, so they ride the same sway at their tops and swing
// beneath it (wisteria_blossom.gdshaderinc). Positions are the tree's own
// (its model's frame: the trunk's axis at x = z = 0, up +y), so the young
// trees on the floating rocks sway alike, scaled down.

#ifndef WISTERIA_SWAY_INC
#define WISTERIA_SWAY_INC

#include "res://shaders/wind.gdshaderinc"

// How far the freest branch moves for each m/s of wind, in metres, and the
// model's distances from the trunk's axis between which the branches go
// from still to free, and the height under which nothing moves.
uniform float branch_sway = 0.12;
uniform float branch_from = 3.0;
uniform float branch_to = 11.0;
uniform float branch_base = 4.0;

// The push (world space) on the branch at model point at, world point world.
vec3 branch_push(vec3 at, vec3 world) {
	float free = smoothstep(branch_from, branch_to, length(at.xz)) * smoothstep(branch_base, branch_base + 4.0, at.y);
	vec2 v = wind_velocity(world);
	float bob = 0.75 + 0.25 * sin(wind_time * 1.3 + dot(world.xz, vec2(0.21, 0.17)));
	return vec3(v.x, 0.0, v.y) * branch_sway * free * bob;
}

// Moves a vertex (model space) by a world-space push, scaled with the tree.
vec3 pushed(vec3 vertex, vec3 push, mat4 model) {
	float scale = length(model[0].xyz);
	return vertex + inverse(mat3(model)) * push * scale;
}

#endif
