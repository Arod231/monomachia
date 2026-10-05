class_name ControlProfiles
extends RefCounted
## The saved controls profiles and which one is active. Port of ProfileStore,
## loadProfiles() and saveProfiles() in v0.1-web-mvp:src/input/bindings.ts and the profile
## row of the Controls screen, saved to user://controls.cfg (a ConfigFile)
## instead of browser storage. There is always at least one profile.
##
## Nothing here saves by itself: call save() after each change, as the demo's
## Controls screen did.
##
## File layout:
##   [controls]  version=1, active=<index>
##   [profile_0] name="Player 1", kb={ action: [tokens] }, pad={ action: [tokens] }
##   [profile_1] ...

const PATH: String = "user://controls.cfg"
const VERSION: int = 1
const SECTION: String = "controls"

var profiles: Array[ControlProfile] = [ControlProfile.create("Player 1")]
var active: int = 0


func active_profile() -> ControlProfile:
	return profiles[active]


## The profile at index, or the active one when index is out of range (a
## Versus selection saved before a profile was deleted).
func profile_at(index: int) -> ControlProfile:
	if index >= 0 and index < profiles.size():
		return profiles[index]
	return active_profile()


func set_active(index: int) -> void:
	active = clampi(index, 0, profiles.size() - 1)


func names() -> PackedStringArray:
	var out: PackedStringArray = []
	for p: ControlProfile in profiles:
		out.append(p.name)
	return out


## "New profile": default bindings, named "Player <n>", and made active.
func add_profile() -> ControlProfile:
	var p: ControlProfile = ControlProfile.create("Player %d" % (profiles.size() + 1))
	profiles.append(p)
	active = profiles.size() - 1
	return p


## Renames a profile: the name is trimmed and cut to 24 characters, and an empty
## name keeps the old one. Returns whether the name changed.
func rename(index: int, new_name: String) -> bool:
	if index < 0 or index >= profiles.size():
		return false
	var clean: String = ControlProfile.clean_name(new_name)
	if clean == "" or clean == profiles[index].name:
		return false
	profiles[index].name = clean
	return true


## The last profile can't be deleted.
func can_delete() -> bool:
	return profiles.size() > 1


## Deletes a profile unless it is the last. The active profile stays active;
## when it is the one deleted, the next one takes its place (or the previous
## one, when it was the last in the list).
func delete_profile(index: int) -> bool:
	if not can_delete() or index < 0 or index >= profiles.size():
		return false
	profiles.remove_at(index)
	if active > index:
		active -= 1
	active = clampi(active, 0, profiles.size() - 1)
	return true


func save(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, "version", VERSION)
	cfg.set_value(SECTION, "active", active)
	for i: int in profiles.size():
		var p: ControlProfile = profiles[i]
		var section: String = "profile_%d" % i
		cfg.set_value(section, "name", p.name)
		cfg.set_value(section, "kb", p.kb.duplicate(true))
		cfg.set_value(section, "pad", p.pad.duplicate(true))
	return cfg.save(path)


## Loads the saved profiles. A missing or unreadable file gives one default
## profile; actions a saved profile lacks are filled from the defaults, and the
## active index is clamped.
static func load_from(path: String = PATH) -> ControlProfiles:
	var store: ControlProfiles = ControlProfiles.new()
	var cfg: ConfigFile = ConfigFile.new()
	if not FileAccess.file_exists(path) or cfg.load(path) != OK:
		return store
	var loaded: Array[ControlProfile] = []
	var i: int = 0
	while cfg.has_section("profile_%d" % i):
		var section: String = "profile_%d" % i
		var data: Dictionary = {
			"name": cfg.get_value(section, "name", ""),
			"kb": cfg.get_value(section, "kb", {}),
			"pad": cfg.get_value(section, "pad", {}),
		}
		loaded.append(ControlProfile.from_dict(data, "Player %d" % (i + 1)))
		i += 1
	if loaded.is_empty():
		return store
	store.profiles = loaded
	var saved_active: Variant = cfg.get_value(SECTION, "active", 0)
	store.set_active(int(saved_active) if (saved_active is int or saved_active is float) else 0)
	return store


## The profiles a run starts with: one fresh profile when the run asks for the
## defaults (GameSettings.DEFAULTS_ENV, test and shot runs), so what a player
## saved can't change them; the saved ones otherwise.
static func load_for_run(use_defaults: bool = OS.has_environment(GameSettings.DEFAULTS_ENV), path: String = PATH) -> ControlProfiles:
	return ControlProfiles.new() if use_defaults else load_from(path)
