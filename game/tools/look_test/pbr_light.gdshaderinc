// The look test's stand-in for toon_light.gdshaderinc (milestone-1 task 30):
// the same uniforms, varying and noise, so every toon-lit shader of the Shrine
// compiles against it unchanged, but no light() of its own, so the surface is
// lit by Godot's physically based model. LookTest swaps it in for the include
// on a copy of each shader, in the look test only; the game keeps the toon.

uniform vec4 shadow_tint : source_color = vec4(0.42, 0.52, 0.74, 1.0);
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.12;
uniform float band_mid : hint_range(0.0, 1.0) = 0.55;
uniform float band_low : hint_range(0.0, 1.0) = 0.10;
uniform float band_high : hint_range(0.0, 1.0) = 0.50;
uniform float band_softness : hint_range(0.0, 0.25) = 0.035;
uniform float brush_noise : hint_range(0.0, 0.5) = 0.10;
uniform vec4 rim_color : source_color = vec4(0.72, 0.82, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.25;
uniform float specular_strength : hint_range(0.0, 4.0) = 0.0;
uniform float specular_size : hint_range(0.0, 1.0) = 0.12;

varying float toon_brush;

#include "res://shaders/look_noise.gdshaderinc"

float toon_noise3(vec3 p) {
	return look_noise(p.xz + p.y * vec2(0.37, 0.71)).r;
}

// The surface's roughness and metalness, which LookMaterials sets per shader
// in place of the toon shader's own.
uniform float look_roughness : hint_range(0.0, 1.0) = 0.88;
uniform float look_metallic : hint_range(0.0, 1.0) = 0.0;
