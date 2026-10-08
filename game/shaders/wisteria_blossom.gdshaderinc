// The wisteria's blossoms (milestone-1 tasks 48 and 52): the raceme cards in
// the models' own texture, cut out by its alpha and seen from both sides,
// lit by their own glow (emission_color, times or plus the raceme's colour)
// rather than the lights under them, and taking no shadow. Each raceme rides
// its branch's sway at its top and swings beneath it on the arena's one wind
// (raceme_swing, by UV.y: 0 at the card's top, 1 at its tip).
// wisteria_blossom.gdshader is the night's; wisteria_blossom_doom.gdshader,
// for match point's blood red, also shines through the mist (no fog).

#ifdef DOOM
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, fog_disabled;
#else
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;
#endif

#include "res://shaders/wisteria_sway.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_scissor = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform vec4 emission_color : source_color = vec4(0.66, 0.2, 1.0, 1.0);
uniform float emission_energy = 3.4;
// The raceme's colour times the glow (match point's blood red, never pink),
// or added to it (the night's lavender).
uniform bool emission_multiply = false;
// How far a raceme's tip swings for each m/s of wind, in metres.
uniform float raceme_swing = 0.3;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 push = branch_push(VERTEX, world);
	float hang = UV.y * UV.y;
	vec2 v = wind_velocity(world);
	float sway = 0.8 + 0.4 * sin(wind_time * 1.7 + dot(world.xz, vec2(1.3, 0.7)));
	push += vec3(v.x, 0.0, v.y) * raceme_swing * hang * sway;
	VERTEX = pushed(VERTEX, push, MODEL_MATRIX);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex.rgb;
	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = roughness;
	EMISSION = (emission_multiply ? emission_color.rgb * tex.rgb : emission_color.rgb + tex.rgb) * emission_energy;
}
