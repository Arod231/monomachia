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

// The same without mipmaps (always the full-size texture), for screen-space
// use (the ink-wash pass), where a lattice cell spans only a few pixels and
// the screen-space derivatives would pick a blurred mipmap.
vec3 look_noise_lod0(vec2 p) {
	return textureLod(look_noise_tex, p / LOOK_NOISE_CELLS, 0.0).rgb;
}

// White noise in [0, 1] for a pixel (FRAGCOORD.xy), repeating with the
// texture (LookNoise.SIZE pixels).
float look_white(vec2 frag) {
	return texelFetch(look_noise_tex, ivec2(frag) % textureSize(look_noise_tex, 0), 0).a;
}

#endif
