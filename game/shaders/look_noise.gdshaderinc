// The look's shared noise texture (LookNoise): three tiling value noises in
// RGB, white noise in A. Fetching it is much cheaper than computing value
// noise on integrated GPUs. LookNoise.apply_to() sets the texture.

#ifndef LOOK_NOISE_INC
#define LOOK_NOISE_INC

uniform sampler2D look_noise_tex : filter_linear_mipmap, repeat_enable;

// Lattice cells across the texture (LookNoise.CELLS).
const float LOOK_NOISE_CELLS = 8.0;

// Three independent value noises in [0, 1] at p, one lattice cell per unit,
// filtered with mipmaps (for surfaces).
vec3 look_noise(vec2 p) {
	return texture(look_noise_tex, p / LOOK_NOISE_CELLS).rgb;
}

// Value noise in [0, 1] at a world position: one fetch on a skewed plane, so
// it varies across floors and walls alike. Much cheaper than true 3D value
// noise on integrated GPUs.
float look_noise3(vec3 p) {
	return look_noise(p.xz + p.y * vec2(0.37, 0.71)).r;
}

#endif
