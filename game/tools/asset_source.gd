class_name AssetSource
extends RefCounted
## Where the raw asset packs are unzipped: the folder holding `quaternius/`
## and `kevin_iglesias/` (on the owner's PC, Desktop/Monomachia-assets). The
## packs are never copied into the repo; the import tools read them from here.
##
## The folder is, in order:
## - the MONOMACHIA_ASSETS_SRC environment variable (scripts/godot.mjs sets it
##   from the setting file, which in a linked git worktree lives in the main
##   checkout);
## - the one-line `.assets-src-path` file at the repo root (not committed,
##   like `.godot-path`);
## - else `assets_src/` at the repo root (gitignored).

const ENV: String = "MONOMACHIA_ASSETS_SRC"
const SETTING_FILE: String = ".assets-src-path"
const DEFAULT_FOLDER: String = "assets_src"


## The repo root: the folder above the Godot project.
static func repo_root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()


## The packs' folder, absolute, with forward slashes.
static func folder() -> String:
	var env: String = OS.get_environment(ENV).strip_edges()
	if env != "":
		return env.replace("\\", "/")
	var setting: String = repo_root().path_join(SETTING_FILE)
	if FileAccess.file_exists(setting):
		var text: String = FileAccess.get_file_as_string(setting).strip_edges()
		if text != "":
			return text.replace("\\", "/")
	return repo_root().path_join(DEFAULT_FOLDER)


## A pack family's folder inside it ("quaternius", "kevin_iglesias").
static func pack_folder(family: String) -> String:
	return folder().path_join(family)


## True when the Kevin Iglesias packs are there.
static func has_iglesias() -> bool:
	return DirAccess.dir_exists_absolute(pack_folder("kevin_iglesias"))


## What to fix when the packs aren't found, naming the setting.
static func missing_message(family: String) -> String:
	return "the %s packs are not in %s. Write the folder they are unzipped in (the one holding %s/) into a %s file at the repo root, set %s, or unzip them into %s/ at the repo root." % [
		family, pack_folder(family), family, SETTING_FILE, ENV, DEFAULT_FOLDER]
