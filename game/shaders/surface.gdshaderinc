// The physically based surface shared by surface.gdshader and
// surface_two_sided.gdshader, which differ only in culling (milestone-1 task
// 43; the look test's materials, task 30). Godot's own physically based model
// lights it: no light() here. Colour comes from base_color, optionally times
// an albedo texture and the vertex colour; a normal map is used when
// normal_strength > 0. Roughness and metalness are the fixed numbers, or
// with use_orm_texture a map's green and blue (glTF's packing; the Hunter's
// dyed outfit, milestone-1 task 45). A fighter's blood stains (blood_stain.gdshaderinc,
// milestone-1 task 38) go over the colour. Build it through LookMaterials,
// which sets the roughness and metalness by the surface's kind.

#include "res://shaders/blood_stain.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.72, 0.70, 0.66, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform bool use_vertex_color = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 4.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform bool use_orm_texture = false;
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;

void fragment() {
	vec3 albedo = base_color.rgb * texture(albedo_texture, UV).rgb;
	if (use_vertex_color) {
		albedo *= COLOR.rgb;
	}
	if (blood_stain_count > 0) {
		albedo = blood_over(albedo, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	}
	ALBEDO = albedo;
	if (use_orm_texture) {
		vec3 orm = texture(orm_texture, UV).rgb;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
	} else {
		ROUGHNESS = roughness;
		METALLIC = metallic;
	}
	if (normal_strength > 0.0) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	EMISSION = emission_color.rgb * emission_energy;
}
