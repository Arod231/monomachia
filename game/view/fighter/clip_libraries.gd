class_name ClipLibraries
extends RefCounted
## The Iglesias clip libraries: one AnimationLibrary per clip set (HumanM,
## HumanF), written by the import tool (tools/import_clips.gd) from the packs
## on the developer's PC into a gitignored folder, so the exported game packs
## them but the public repo never holds them (docs/specs/authored-animation.md,
## Licence). A fresh clone has no libraries: available() is false and the
## game plays the committed CC0 fallback clips instead.
##
## Tracks address bones as `%GeneralSkeleton:<profile bone>`, like the UAL
## library, so a clip plays on any FighterModel. Clips keep their manifest
## names (game/assets/kevin_iglesias/clip_manifest.json).

const FOLDER: String = "res://assets/kevin_iglesias/library"
## The clip sets, in the order the import tool writes them.
const SETS: Array[StringName] = [&"HumanM", &"HumanF"]
## The match's small note when the libraries are missing, and what the log
## says to fix.
const MISSING_NOTE: String = "animation packs missing"
const MISSING_LOG: String = "Iglesias clip libraries not found in res://assets/kevin_iglesias/library: playing the CC0 fallback clips. To build them, put the packs' folder in .assets-src-path and run node scripts/godot.mjs clips."
## Each fighter's own clip set.
const FIGHTER_SETS: Dictionary[StringName, StringName] = {&"hunter": &"HumanM", &"rogue": &"HumanF"}


## Where a set's library is saved.
static func path(set_name: StringName) -> String:
	return FOLDER.path_join("iglesias_%s.res" % String(set_name).to_lower())


## Tests and shots set it to play as a fresh clone does, without the packs.
static var force_missing: bool = false
static var _warned: bool = false


## True when every set's library is there.
static func available() -> bool:
	if force_missing:
		return false
	for set_name: StringName in SETS:
		if not ResourceLoader.exists(path(set_name)):
			return false
	return true


## Logs MISSING_LOG once, when the libraries are missing; true if missing.
static func warn_if_missing() -> bool:
	if available():
		return false
	if not _warned:
		_warned = true
		push_warning(MISSING_LOG)
	return true


## A set's library, or null when it hasn't been imported.
static func load_set(set_name: StringName) -> AnimationLibrary:
	var p: String = path(set_name)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as AnimationLibrary


## The clip set fighter `fighter_id` plays a move with `swing` (null for a move
## without one) from: its own, except that the Rogue plays the Hunter's
## HumanM for a move whose HumanF clip strays from the shared path
## (Swing.rogue_humanm, authored-animation task 7).
static func set_for(fighter_id: StringName, swing: Swing = null) -> StringName:
	if fighter_id == &"rogue" and swing != null and swing.rogue_humanm:
		return &"HumanM"
	return FIGHTER_SETS.get(fighter_id, &"HumanM")
