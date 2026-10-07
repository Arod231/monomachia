// Blood stains on a fighter (milestone-1 task 38, BloodEffects): a spot where
// each blade hit landed. BloodEffects keeps the spots in the space of the
// bone nearest each hit and hands them over every frame in world space, so
// they ride the body; a spot is a ragged-edged sphere the surface darkens to
// blood inside. The physically based surface (surface.gdshaderinc) includes it.

#include "res://shaders/look_noise.gdshaderinc"

// xyz: the spot's centre (world, m); w: its radius (m).
uniform vec4 blood_stains[12];
uniform int blood_stain_count = 0;
uniform vec3 blood_color : source_color = vec3(0.32, 0.012, 0.02);

// The albedo with the blood over it.
vec3 blood_over(vec3 albedo, vec3 world) {
	float wet = 0.0;
	for (int i = 0; i < blood_stain_count; i++) {
		vec4 s = blood_stains[i];
		float d = distance(world, s.xyz) / max(s.w, 0.001);
		// ragged edges and a few drops past them
		float ragged = look_noise3(world * 14.0 + float(i) * 3.1) * 0.6 + look_noise3(world * 38.0) * 0.4;
		wet = max(wet, smoothstep(1.0, 0.6, d + (ragged - 0.5) * 0.8));
	}
	// soaked cloth is darker than the blood on top of it
	return mix(albedo, mix(albedo * 0.3, blood_color, 0.9), wet);
}
