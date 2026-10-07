extends GutTest
## Import hygiene for the art: no file in game/assets or the baked textures
## and meshes in game/fighters and game/weapons over 25 MB, textures are
## scaled down, every texture a model references exists, and every skinned
## model is retargeted through the humanoid bone map (an exported Iglesias
## clip through the Iglesias one). The art's and the audio's totals are the
## public repository's budgets in the spec's size budget table (150 MB and
## 40 MB, milestone-1 task 8), checked by scripts/check-sizes.mjs (npm run
## check:sizes) in place of the 110 MB cap this test had.

const ASSETS: String = "res://assets"
const AUDIO: String = "res://assets/audio"
## Folders of baked art beside game/assets (palettes, skins, weapon meshes).
const BAKED: Array[String] = ["res://fighters", "res://weapons"]
## Binary art in the baked folders; their scenes and scripts aren't counted.
const BAKED_EXTENSIONS: Array[String] = ["png", "res", "exr"]
## Raised from 10 MB to take the UAL2 Source tier's two ~20 MB clip
## libraries (UAL2_Source.glb and UAL2_Source_RM.glb).
const MAX_FILE_BYTES: int = 25 * 1024 * 1024
const MAX_BASE_COLOR: int = 2048
const MAX_DATA_MAP: int = 1024
const BONE_MAP: String = "res://assets/quaternius/ual_bone_map.tres"
## The Kevin Iglesias clips' own bone map, which the clips exported from
## Blender (milestone-1 task 13, staged by import_clips.gd) retarget through.
const IGLESIAS: String = "res://assets/kevin_iglesias/"
const IGLESIAS_BONE_MAP: String = "res://assets/kevin_iglesias/iglesias_bone_map.tres"


static func _files(dir_path: String, out: Array[String]) -> Array[String]:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		_files(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		out.append(dir_path.path_join(file))
	return out


## Art exported from Blender with no skeleton, so no bone map: the Shrine's
## (the wisteria, milestone-1 task 48) and the fighters' dyed maps (the
## Hunter's palettes, task 45).
const UNRIGGED: Array[String] = ["res://assets/exports/shrine/", "res://assets/exports/fighters/"]
## Exports whose rig, if any, is their own: cloth on spring bones (the
## Hunter's scarf, milestone-1 task 46), never a fighter's, so never retargeted.
const OWN_RIGS: Array[String] = ["res://assets/exports/headwear/"]


## The gitignored folders the Iglesias import tool writes (the staged FBX
## copies and the clip libraries): never committed, so outside the budget.
const UNCOMMITTED: Array[String] = ["res://assets/kevin_iglesias/staging/", "res://assets/kevin_iglesias/library/"]


## Every committed file in game/assets except the audio, and the baked art
## beside it.
static func _art_files() -> Array[String]:
	var art: Array[String] = []
	for path: String in _files(ASSETS, []):
		if not path.begins_with(AUDIO + "/") and not UNCOMMITTED.any(func(p: String) -> bool: return path.begins_with(p)):
			art.append(path)
	for root: String in BAKED:
		for path: String in _files(root, []):
			if BAKED_EXTENSIONS.has(path.get_extension()):
				art.append(path)
	return art


## A PNG's width and height, from its header.
static func _png_size(path: String) -> Vector2i:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	f.big_endian = true
	f.seek(16)
	var size: Vector2i = Vector2i(f.get_32(), f.get_32())
	f.close()
	return size


func test_no_art_file_is_over_25_mb() -> void:
	for path: String in _art_files():
		assert_lt(FileAccess.get_size(path), MAX_FILE_BYTES, path)


func test_textures_are_scaled_down() -> void:
	var pngs: Array[String] = []
	for root: String in [ASSETS, "res://fighters"]:
		for path: String in _files(root, []):
			if path.ends_with(".png"):
				pngs.append(path)
	assert_gt(pngs.size(), 20)
	for path: String in pngs:
		var size: Vector2i = _png_size(path)
		var file: String = path.get_file()
		var lower: String = file.to_lower()
		var data_map: bool = lower.contains("_normal") or lower.contains("_orm") or lower.contains("_roughness")
		var limit: int = MAX_DATA_MAP if data_map else MAX_BASE_COLOR
		assert_true(size.x <= limit and size.y <= limit, "%s is %dx%d (limit %d)" % [file, size.x, size.y, limit])


func test_textures_import_vram_compressed() -> void:
	for root: String in [ASSETS, "res://fighters"]:
		for path: String in _files(root, []):
			if not path.ends_with(".png.import"):
				continue
			var cfg: ConfigFile = ConfigFile.new()
			assert_eq(cfg.load(path), OK)
			assert_eq(cfg.get_value("params", "compress/mode", -1), 2, "%s is VRAM compressed" % path.get_file())
			if path.contains("_Normal"):
				assert_eq(cfg.get_value("params", "compress/normal_map", -1), 1, "%s is a normal map" % path.get_file())


func test_every_texture_a_model_references_exists() -> void:
	var models: int = 0
	for path: String in _files(ASSETS, []):
		if not path.ends_with(".gltf"):
			continue
		models += 1
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for image: Dictionary in doc.get("images", []):
			var uri: String = String(image["uri"]).uri_decode()
			var target: String = path.get_base_dir().path_join(uri).simplify_path()
			assert_true(FileAccess.file_exists(target), "%s -> %s" % [path.get_file(), uri])
	# each with its taller copy (KE task 3), which keeps its materials and textures
	assert_eq(models, 30, "2 bodies, 10 outfit parts and 3 hairstyles, each with its _Tall copy")


func test_every_skinned_model_is_retargeted_through_the_bone_map() -> void:
	for path: String in _files(ASSETS, []):
		if not (path.ends_with(".gltf.import") or path.ends_with(".glb.import")):
			continue
		if UNRIGGED.any(func(prefix: String) -> bool: return path.begins_with(prefix)):
			var model: Node = (load(path.trim_suffix(".import")) as PackedScene).instantiate()
			assert_eq(model.find_children("*", "Skeleton3D", true, false).size(), 0, "%s has no rig" % path.get_file())
			model.free()
			continue
		if OWN_RIGS.any(func(prefix: String) -> bool: return path.begins_with(prefix)):
			var worn: Node = (load(path.trim_suffix(".import")) as PackedScene).instantiate()
			for sk: Node in worn.find_children("*", "Skeleton3D", true, false):
				assert_eq((sk as Skeleton3D).find_bone("Hips"), -1, "%s's rig is its own, not a fighter's" % path.get_file())
				assert_lt((sk as Skeleton3D).get_bone_count(), 20, "%s's rig is small" % path.get_file())
			worn.free()
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var bone_map: String = IGLESIAS_BONE_MAP if path.begins_with(IGLESIAS) else BONE_MAP
		assert_true(text.contains("\"retarget/bone_map\": Resource(") and text.contains(bone_map), "%s uses the bone map" % path.get_file())


func test_assets_are_credited() -> void:
	var credits: String = FileAccess.get_file_as_string("res://assets/CREDITS.md")
	assert_true(credits.contains("Quaternius"))
	assert_true(credits.contains("CC0"))
