extends SceneTree
## Copies the Quaternius files the game uses into game/assets, scales their
## textures down, fixes their broken texture references and writes their
## import settings. Run it again whenever the selection below changes:
##
##   node scripts/godot.mjs script res://tools/build_bone_map.gd
##   node scripts/godot.mjs script res://tools/import_assets.gd -- \
##       [--quaternius=<folder holding the four Quaternius packs>] \
##       --weapons=<folder holding the Medieval Weapons Pack's FBX/ folder>
##   node scripts/godot.mjs import
##
## Without --quaternius it reads the packs from the `quaternius/` folder of
## the packs' folder (AssetSource: the repo root's `.assets-src-path`).
##
## What it does:
## - copies the animation GLBs in ANIMATIONS, the two base bodies, the UAL2
##   female mannequin, the Ranger outfit parts, the hairstyles in HAIR and the
##   weapons in WEAPONS;
## - scales textures with Lanczos: base colour to at most 2048 px, normal,
##   ORM and roughness maps to at most 1024 px;
## - rewrites each .gltf's image URIs: the bodies point at `*_Normal_png.png`
##   files that don't exist (the files are `*_Normal.png`), shared hair
##   textures are kept once in hair/, and the outfits use the darker,
##   unreferenced T_Ranger_3 colourway instead of the green T_Ranger one;
## - writes each model's .import with the humanoid BoneMap
##   (res://assets/quaternius/ual_bone_map.tres), so every clip plays on every
##   body, and turns off animation import for everything but the GLBs.

const DEST: String = "res://assets"
const BONE_MAP: String = "res://assets/quaternius/ual_bone_map.tres"

const UAL1: String = "Universal Animation Library[Standard]/Universal Animation Library[Standard]/Unreal-Godot"
const UAL2: String = "Universal Animation Library 2[Standard]/Universal Animation Library 2[Standard]/Unreal-Godot"
## The Source tier unzips without the doubled top folder.
const UAL2_SOURCE: String = "Universal Animation Library 2[Source]"
const BODIES: String = "Universal Base Characters[Standard]/Universal Base Characters[Standard]/Base Characters/Godot - UE"
const HAIRSTYLES: String = "Universal Base Characters[Standard]/Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)"
const OUTFIT_PARTS: String = "Modular Character Outfits - Fantasy[Standard]/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Modular Parts"
const OUTFIT_TEXTURES: String = "Modular Character Outfits - Fantasy[Standard]/Modular Character Outfits - Fantasy[Standard]/Textures/Ranger"

const MAX_BASE_COLOR: int = 2048
const MAX_DATA_MAP: int = 1024

## Destination file name -> path in the packs (relative to _quaternius). The
## _RM files have root motion baked in; the others have it disabled. The
## Source tier holds the full UAL2 clip set; its files are renamed so they
## sit beside the Standard ones.
const ANIMATIONS: Dictionary[String, String] = {
	"UAL1_Standard.glb": UAL1 + "/UAL1_Standard.glb",
	"UAL2_Standard.glb": UAL2 + "/UAL2_Standard.glb",
	"UAL2_Standard_RM.glb": UAL2 + "/UAL2_Standard_RM.glb",
	"UAL2_Source.glb": UAL2_SOURCE + "/Unreal-Godot/UAL2.glb",
	"UAL2_Source_RM.glb": UAL2_SOURCE + "/Unreal-Godot/UAL2_RM.glb",
}
## The UAL2 female mannequin: same rig as the library, no clips of its own.
const MANNEQUIN: String = UAL2_SOURCE + "/Female Mannequin/Unreal-Godot/Mannequin_F.glb"
const BODY_FILES: Array[String] = ["Superhero_Female_FullBody", "Superhero_Male_FullBody"]
const HAIR: Array[String] = ["Hair_Long", "Hair_Buzzed", "Hair_Beard"]
const OUTFIT_FILES: Array[String] = [
	# The Rogue goes without the pauldrons and the Hunter without the hood
	# (he wears a tricorn, modelled by scripts/blender/build_headwear.py).
	"Female_Ranger_Arms", "Female_Ranger_Body", "Female_Ranger_Feet", "Female_Ranger_Head_Hood", "Female_Ranger_Legs",
	"Male_Ranger_Acc_Pauldron", "Male_Ranger_Arms", "Male_Ranger_Body", "Male_Ranger_Feet_Boots", "Male_Ranger_Legs",
]
const WEAPONS: Array[String] = ["Sword_Big.fbx", "Dagger.fbx"]
## The weapon pack's flat colours, swapped at import for the game's darker
## weapon materials.
const WEAPON_MATERIALS: Dictionary[String, String] = {
	"Steel": "res://weapons/materials/steel.tres",
	"LightSteel": "res://weapons/materials/steel_edge.tres",
	"DarkSteel": "res://weapons/materials/iron.tres",
	"LightWood": "res://weapons/materials/leather_wrap.tres",
	"DarkWood": "res://weapons/materials/leather_wrap_dark.tres",
}

## Texture references the packs get wrong, and the colourway swap.
const URI_ALIASES: Dictionary[String, String] = {
	"T_Eye_Normal_png.png": "T_Eye_Normal.png",
	"T_Hair_1_Normal_png.png": "T_Hair_1_Normal.png",
	"T_Hair_2_Normal_png.png": "T_Hair_2_Normal.png",
	"T_Hair_1_BaseColor_png.png": "T_Hair_1_BaseColor.png",
	"T_Hair_2_BaseColor_png.png": "T_Hair_2_BaseColor.png",
	"T_Ranger_BaseColor.png": "T_Ranger_3_BaseColor.png",
}

var _quaternius: String
var _weapons: String
## Texture file name -> [source folder (relative to _quaternius), dest folder].
var _textures: Dictionary[String, Array] = {}
var _failed: bool = false


func _initialize() -> void:
	_quaternius = _arg("quaternius", AssetSource.pack_folder("quaternius"))
	_weapons = _arg("weapons", "")
	_register_textures()
	for f: String in ANIMATIONS:
		_copy(_quaternius.path_join(ANIMATIONS[f]), DEST + "/quaternius/animations/" + f)
		_write_scene_import(DEST + "/quaternius/animations/" + f, true)
	_copy(_quaternius.path_join(MANNEQUIN), DEST + "/quaternius/characters/Mannequin_F.glb")
	_write_scene_import(DEST + "/quaternius/characters/Mannequin_F.glb", false)
	for f: String in BODY_FILES:
		_copy_gltf(BODIES, f, "characters")
	for f: String in HAIR:
		_copy_gltf(HAIRSTYLES, f, "hair")
	for f: String in OUTFIT_FILES:
		_copy_gltf(OUTFIT_PARTS, f, "outfits")
	for tex: String in _textures:
		var spec: Array = _textures[tex]
		_copy_texture(_quaternius.path_join(spec[0]).path_join(tex), DEST + "/quaternius/" + spec[1] + "/" + tex)
	if _weapons != "":
		for f: String in WEAPONS:
			_copy(_weapons.path_join("FBX").path_join(f), DEST + "/weapons/" + f)
	else:
		print("import_assets: no --weapons folder given; weapon files left as they are")
	for f: String in WEAPONS:
		_write_weapon_import(DEST + "/weapons/" + f)
	if _failed:
		printerr("import_assets: finished with errors")
		quit(1)
	else:
		print("import_assets: done; now run `node scripts/godot.mjs import`")
		quit(0)


func _arg(arg_name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.substr(arg_name.length() + 3).replace("\\", "/")
	return fallback


func _register_textures() -> void:
	for t: String in ["T_Eye_Brown.png", "T_Eye_Normal.png",
			"T_Superhero_Female_Dark_BaseColor.png", "T_Superhero_Female_Normal.png", "T_Superhero_Female_Roughness.png",
			"T_Superhero_Male_Dark.png", "T_Superhero_Male_Normal.png", "T_Superhero_Male_Roughness.png"]:
		_textures[t] = [BODIES, "characters"]
	for t: String in ["T_Hair_1_BaseColor.png", "T_Hair_1_Normal.png", "T_Hair_2_BaseColor.png", "T_Hair_2_Normal.png"]:
		_textures[t] = [HAIRSTYLES, "hair"]
	for t: String in ["T_Ranger_Normal.png", "T_Ranger_ORM.png",
			"T_Regular_Female_Dark_BaseColor.png", "T_Regular_Female_Normal.png", "T_Regular_Female_Roughness.png",
			"T_Regular_Male_Dark_BaseColor.png", "T_Regular_Male_Normal.png", "T_Regular_Male_Roughness.png"]:
		_textures[t] = [OUTFIT_PARTS, "outfits"]
	_textures["T_Ranger_3_BaseColor.png"] = [OUTFIT_TEXTURES, "outfits"]


## Copies a .gltf and its .bin, rewriting the image URIs to the shared,
## scaled textures.
func _copy_gltf(src_dir: String, base: String, dest_folder: String) -> void:
	var src: String = _quaternius.path_join(src_dir).path_join(base + ".gltf")
	var text: String = FileAccess.get_file_as_string(src)
	if text.is_empty():
		_fail("cannot read %s" % src)
		return
	var json: Variant = JSON.parse_string(text)
	if not (json is Dictionary):
		_fail("cannot parse %s" % src)
		return
	var doc: Dictionary = json
	for image: Dictionary in doc.get("images", []):
		var uri: String = String(image["uri"]).uri_decode()
		uri = URI_ALIASES.get(uri, uri)
		if not _textures.has(uri):
			_fail("%s references unknown texture %s" % [base, uri])
			continue
		var tex_folder: String = _textures[uri][1]
		image["uri"] = uri if tex_folder == dest_folder else "../%s/%s" % [tex_folder, uri]
	var dest: String = "%s/quaternius/%s/%s.gltf" % [DEST, dest_folder, base]
	_ensure_dir(dest.get_base_dir())
	var out: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		_fail("cannot write %s" % dest)
		return
	out.store_string(JSON.stringify(doc, "\t", false))
	out.close()
	_copy(_quaternius.path_join(src_dir).path_join(base + ".bin"), dest.get_basename() + ".bin")
	_write_scene_import(dest, false)


func _copy_texture(src: String, dest: String) -> void:
	var img: Image = Image.load_from_file(src)
	if img == null or img.is_empty():
		_fail("cannot load %s" % src)
		return
	var is_base_color: bool = not (dest.contains("_Normal") or dest.contains("_ORM") or dest.contains("_Roughness"))
	var max_size: int = MAX_BASE_COLOR if is_base_color else MAX_DATA_MAP
	if img.get_width() > max_size or img.get_height() > max_size:
		var s: float = float(max_size) / float(maxi(img.get_width(), img.get_height()))
		img.resize(roundi(img.get_width() * s), roundi(img.get_height() * s), Image.INTERPOLATE_LANCZOS)
	_ensure_dir(dest.get_base_dir())
	var err: Error = img.save_png(dest)
	if err != OK:
		_fail("cannot save %s (%s)" % [dest, error_string(err)])
		return
	write_texture_import(dest, dest.contains("_Normal"))
	print("import_assets: %s %dx%d" % [dest, img.get_width(), img.get_height()])


## Writes a texture's import settings: VRAM-compressed with mipmaps (the
## textures are only used on 3D models), normal maps flagged as such so they
## get the right compression. Without this, the first headless import keeps
## them lossless until the editor notices they are used in 3D.
static func write_texture_import(path: String, normal_map: bool) -> void:
	var lines: PackedStringArray = [
		"[remap]",
		"",
		"importer=\"texture\"",
		"type=\"CompressedTexture2D\"",
	]
	var uid_line: String = _existing_uid(path)
	if uid_line != "":
		lines.append(uid_line)
	lines.append_array([
		"",
		"[params]",
		"",
		"compress/mode=2",
		"compress/normal_map=%d" % (1 if normal_map else 2),
		"mipmaps/generate=true",
		"detect_3d/compress_to=0",
		"",
	])
	var f: FileAccess = FileAccess.open(path + ".import", FileAccess.WRITE)
	if f == null:
		printerr("import_assets: cannot write %s.import" % path)
		return
	f.store_string("\n".join(lines))
	f.close()


## The `uid=` line of an existing .import file, so rewriting the file keeps
## the uid that scenes may refer to.
static func _existing_uid(path: String) -> String:
	if FileAccess.file_exists(path + ".import"):
		for line: String in FileAccess.get_file_as_string(path + ".import").split("\n"):
			if line.begins_with("uid="):
				return line
	return ""


func _copy(src: String, dest: String) -> void:
	_ensure_dir(dest.get_base_dir())
	var err: Error = DirAccess.copy_absolute(src, ProjectSettings.globalize_path(dest))
	if err != OK:
		_fail("cannot copy %s to %s (%s)" % [src, dest, error_string(err)])
		return
	print("import_assets: %s" % dest)


## Writes the import settings for a skinned model. Godot keeps these params
## and fills in the defaults for the rest on the next import. An existing
## file's uid is kept so that scenes referring to the model by uid still work.
func _write_scene_import(path: String, with_animation: bool) -> void:
	var uid_line: String = _existing_uid(path)
	var lines: PackedStringArray = [
		"[remap]",
		"",
		"importer=\"scene\"",
		"importer_version=1",
		"type=\"PackedScene\"",
	]
	if uid_line != "":
		lines.append(uid_line)
	lines.append_array([
		"",
		"[params]",
		"",
		"nodes/import_as_skeleton_bones=false",
		"animation/import=%s" % ("true" if with_animation else "false"),
		"_subresources={",
		"\"nodes\": {",
		"\"PATH:Armature/Skeleton3D\": {",
		"\"retarget/bone_map\": Resource(\"%s\")" % BONE_MAP,
		"}",
		"}",
		"}",
		"",
	])
	var f: FileAccess = FileAccess.open(path + ".import", FileAccess.WRITE)
	if f == null:
		_fail("cannot write %s.import" % path)
		return
	f.store_string("\n".join(lines))
	f.close()


## Writes a weapon model's import settings: its materials replaced by the
## game's (WEAPON_MATERIALS).
func _write_weapon_import(path: String) -> void:
	var lines: PackedStringArray = [
		"[remap]",
		"",
		"importer=\"scene\"",
		"importer_version=1",
		"type=\"PackedScene\"",
	]
	var uid_line: String = _existing_uid(path)
	if uid_line != "":
		lines.append(uid_line)
	# fbx/importer 0 is Godot's built-in ufbx reader (1 needs the external
	# FBX2glTF tool).
	lines.append_array(["", "[params]", "", "fbx/importer=0", "_subresources={", "\"materials\": {"])
	var entries: PackedStringArray = []
	for m: String in WEAPON_MATERIALS:
		entries.append("\"%s\": {\n\"use_external/enabled\": true,\n\"use_external/path\": \"%s\"\n}" % [m, WEAPON_MATERIALS[m]])
	lines.append(",\n".join(entries))
	lines.append_array(["}", "}", ""])
	var f: FileAccess = FileAccess.open(path + ".import", FileAccess.WRITE)
	if f == null:
		_fail("cannot write %s.import" % path)
		return
	f.store_string("\n".join(lines))
	f.close()


func _ensure_dir(res_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(res_dir))


func _fail(msg: String) -> void:
	printerr("import_assets: " + msg)
	_failed = true
