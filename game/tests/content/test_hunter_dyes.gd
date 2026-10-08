extends GutTest
## The Hunter's two palettes, crimson and indigo, dyed in Blender
## (milestone-1 task 45, scripts/blender/dye_outfit.py) and brought in by the
## export as a GLB per palette: a cloth atlas for the dyed garments and a gear
## atlas for the belts and boots, which reuse the cloth's texels in the
## outfit's shared atlas. Each atlas is three maps: base colour, roughness and
## metalness, and the normal map.

const DYES: Dictionary[String, String] = {
	"Crimson": "res://assets/exports/fighters/hunter_crimson.glb",
	"Indigo": "res://assets/exports/fighters/hunter_indigo.glb",
}
## Outfit meshes and the atlas each wears.
const ATLAS_OF: Dictionary[String, String] = {
	"Male_Ranger_Body": "cloth", "Male_Ranger_Arms": "cloth", "Male_Ranger_Legs": "cloth",
	"Male_Ranger_Acc_Pauldron": "cloth", "Male_Ranger_Body_Belt_1": "gear", "Male_Ranger_Body_Belt_2": "gear",
	"Male_Ranger_Feet_Boots": "gear",
}


func _hunter() -> FighterLook:
	return load(FighterLook.path_for(&"hunter"))


func test_the_hunters_palettes_are_crimson_and_indigo_from_the_export() -> void:
	var look: FighterLook = _hunter()
	assert_eq(look.palettes.size(), 2)
	for p: FighterPalette in look.palettes:
		assert_true(DYES.has(p.display_name), "%s is crimson or indigo" % p.display_name)
		assert_not_null(p.outfit_maps, "%s is dyed" % p.display_name)
		assert_eq(p.outfit_maps.resource_path, DYES.get(p.display_name, ""), "from the export")
	assert_eq(look.palettes[0].display_name, "Crimson", "palette A is crimson (the HUD's red)")
	assert_eq(look.palettes[1].display_name, "Indigo")


func test_each_dye_holds_a_cloth_and_a_gear_atlas_of_three_maps() -> void:
	for p: FighterPalette in _hunter().palettes:
		var seen: Dictionary = {}
		for mesh: String in ATLAS_OF:
			var m: BaseMaterial3D = p.dyed_material(mesh)
			assert_not_null(m, "%s: %s has its atlas" % [p.display_name, mesh])
			if m == null:
				continue
			assert_string_ends_with(m.resource_name, "_" + ATLAS_OF[mesh], "%s: %s" % [p.display_name, mesh])
			assert_not_null(m.albedo_texture, "base colour")
			assert_not_null(m.roughness_texture, "roughness")
			assert_eq(m.roughness_texture_channel, BaseMaterial3D.TEXTURE_CHANNEL_GREEN)
			assert_eq(m.metallic_texture, m.roughness_texture, "metalness in the same map")
			assert_true(m.normal_enabled and m.normal_texture != null, "a normal map")
			seen[ATLAS_OF[mesh]] = m
		assert_ne(seen.get("cloth"), seen.get("gear"), "two atlases")
	var a: FighterPalette = _hunter().palettes[0]
	var b: FighterPalette = _hunter().palettes[1]
	assert_ne(a.dyed_material("Male_Ranger_Body").albedo_texture, b.dyed_material("Male_Ranger_Body").albedo_texture)


func test_the_hunter_wears_his_palettes_dyed_maps() -> void:
	var f: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	f.autoplay_idle = false
	add_child_autofree(f)
	for index: int in 2:
		f.apply_palette(index)
		var p: FighterPalette = f.look.palettes[index]
		var count: int = 0
		for node: Node in f.skeleton.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			for s: int in mi.mesh.get_surface_count():
				var m: ShaderMaterial = mi.get_surface_override_material(s) as ShaderMaterial
				if m == null or StringName(m.resource_name) != f.look.outfit_material:
					continue
				var dyed: BaseMaterial3D = p.dyed_material(mi.name)
				assert_eq(m.get_shader_parameter(&"albedo_texture"), dyed.albedo_texture, "%s %s" % [p.display_name, mi.name])
				assert_eq(m.get_shader_parameter(&"orm_texture"), dyed.roughness_texture)
				assert_eq(m.get_shader_parameter(&"use_orm_texture"), true)
				assert_eq(m.get_shader_parameter(&"normal_texture"), dyed.normal_texture)
				assert_gt(float(m.get_shader_parameter(&"normal_strength")), 0.0)
				assert_eq(m.get_shader_parameter(&"base_color"), Color.WHITE, "the maps' own colour")
				count += 1
		assert_gt(count, 6, "every outfit surface")


func test_the_rogue_keeps_her_baked_palettes() -> void:
	var rogue: FighterLook = load(FighterLook.path_for(&"rogue"))
	for p: FighterPalette in rogue.palettes:
		assert_null(p.outfit_maps)
		assert_not_null(p.outfit_albedo)
