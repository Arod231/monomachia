// The toon surface shared by toon.gdshader and toon_two_sided.gdshader, which
// differ only in culling. Include it after toon_light.gdshaderinc. Colour
// comes from base_color, optionally times an albedo texture and the vertex
// colour; a normal map is used when normal_strength > 0.

uniform vec4 base_color : source_color = vec4(0.72, 0.70, 0.66, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform bool use_vertex_color = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 4.0) = 0.0;
// The material's ink: its outline colour (copied to the outline pass) and the
// colour of the painterly wash stains.
uniform vec4 ink_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform float wash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wash_scale = 0.8;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
// View-only fresnel glow, independent of lights: keeps fighters readable
// against dark backgrounds.
uniform float rim_emission : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 albedo = base_color.rgb * texture(albedo_texture, UV).rgb;
	if (use_vertex_color) {
		albedo *= COLOR.rgb;
	}
	// One noise sample drives the brushed band edges; the wash stains add a
	// second, larger one. Two lookups per pixel keep props cheap on iGPUs.
	float brush = toon_noise3(world * 2.6);
	if (wash_amount > 0.0) {
		float w = toon_noise3(world * wash_scale) * 0.75 + brush * 0.25;
		w = smoothstep(0.45, 0.85, w);
		albedo = mix(albedo, albedo * ink_color.rgb * 3.0, w * wash_amount);
	}
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	if (normal_strength > 0.0) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	toon_brush = brush - 0.5;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = emission_color.rgb * emission_energy
		+ rim_color.rgb * smoothstep(1.0 - rim_width * 1.5, 1.0, fres) * rim_emission;
}
