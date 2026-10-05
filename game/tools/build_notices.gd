class_name BuildNotices
extends RefCounted
## The text files the Windows build carries beside the exe (plan task 25.4),
## written by tools/write_build_notices.gd after every export:
## - LICENSE.txt: the repository's LICENSE (all rights reserved);
## - CREDITS.txt: the repository's CREDITS.md, leaving out the Kevin Iglesias
##   packs when the export holds no clip libraries (CI's stand-in build, a
##   fresh clone's), since that build has none of their clips;
## - THIRD-PARTY-NOTICES.txt: the licence notices the engine and the bundled
##   fonts ask every copy to carry: the engine's own licence, its third-party
##   components and their licence texts, read from the running engine so they
##   match its version, then each font's SIL Open Font License.
##
## A build without the clip libraries also gets STAND-IN.txt (plan task
## 25.5), saying what it lacks, so CI's export and a release made without the
## asset repository can't pass for the real thing.
##
## CREDITS.md stays readable as plain text (bare links, no tables), so the
## build copies it as it is but for its section markers.

const LICENSE_FILE: String = "LICENSE.txt"
const CREDITS_FILE: String = "CREDITS.txt"
const NOTICES_FILE: String = "THIRD-PARTY-NOTICES.txt"
const STAND_IN_FILE: String = "STAND-IN.txt"
const STAND_IN_TEXT: String = """This is a stand-in build of Monomachia, not a release.

It was exported without the licensed Kevin Iglesias animation clips, which
only the developer's PC has. The fighters play the free stand-in clips
instead, and in attacks the weapons drift away from the hands.

Releases are built with the clips: https://github.com/Arod231/monomachia/releases
"""
## CREDITS.md's section naming the Kevin Iglesias packs sits between these
## two lines.
const IGLESIAS_BEGIN: String = "<!-- packs: kevin_iglesias -->"
const IGLESIAS_END: String = "<!-- /packs -->"
## The bundled fonts' folder, where each font's licence lies beside it as
## <Font>-OFL.txt.
const FONTS: String = "res://ui/fonts"
const FONT_LICENCE_SUFFIX: String = "-OFL.txt"


## CREDITS.md as a build ships it: without its section markers, and without
## the Kevin Iglesias section unless with_iglesias.
static func credits_text(markdown: String, with_iglesias: bool) -> String:
	var text: String = markdown.replace("\r\n", "\n")
	if not with_iglesias:
		var begin: int = text.find(IGLESIAS_BEGIN)
		var end: int = text.find(IGLESIAS_END)
		if begin >= 0 and end > begin:
			text = text.substr(0, begin) + text.substr(end + IGLESIAS_END.length())
	text = text.replace(IGLESIAS_BEGIN + "\n", "").replace(IGLESIAS_END + "\n", "")
	text = text.replace(IGLESIAS_BEGIN, "").replace(IGLESIAS_END, "")
	while text.contains("\n\n\n"):
		text = text.replace("\n\n\n", "\n\n")
	return text


## The licence notices for the engine and the bundled fonts.
static func notices_text() -> String:
	var out: PackedStringArray = []
	out.append("Third-party notices\n")
	out.append("Monomachia is built with the Godot Engine and uses the fonts below. Their licences ask that these notices go with every copy of the game.\n")
	out.append(_heading("Godot Engine %s" % Engine.get_version_info()["string"]))
	out.append(Engine.get_license_text().strip_edges() + "\n")
	out.append(_heading("Components of the Godot Engine"))
	for component: Dictionary in Engine.get_copyright_info():
		out.append("- %s" % component["name"])
		for part: Dictionary in component["parts"]:
			for line: String in part["copyright"]:
				out.append("  Copyright %s" % line)
			out.append("  Licence: %s" % part["license"])
	out.append("")
	var licences: Dictionary = Engine.get_license_info()
	var ids: Array = licences.keys()
	ids.sort()
	for id: String in ids:
		out.append(_heading("Licence: %s" % id))
		out.append(String(licences[id]).strip_edges() + "\n")
	for file: String in _font_licences():
		var font: String = file.trim_suffix(FONT_LICENCE_SUFFIX)
		out.append(_heading("Font: %s" % _spaced(font)))
		out.append(FileAccess.get_file_as_string(FONTS.path_join(file)).strip_edges() + "\n")
	return "\n".join(out)


## Writes the three files into out_dir (an absolute path), from the
## repository's LICENSE and CREDITS.md, and STAND-IN.txt unless with_iglesias
## (a stale one from an earlier build is removed).
static func write(out_dir: String, with_iglesias: bool) -> Error:
	var made: Error = DirAccess.make_dir_recursive_absolute(out_dir)
	if made != OK:
		return made
	var root: String = AssetSource.repo_root()
	var licence: String = FileAccess.get_file_as_string(root.path_join("LICENSE"))
	var credits: String = FileAccess.get_file_as_string(root.path_join("CREDITS.md"))
	if licence == "" or credits == "":
		push_error("build_notices.gd: LICENSE or CREDITS.md is missing at %s" % root)
		return ERR_FILE_NOT_FOUND
	var files: Array[Array] = [
		[LICENSE_FILE, licence],
		[CREDITS_FILE, credits_text(credits, with_iglesias)],
		[NOTICES_FILE, notices_text()],
	]
	var stand_in: String = out_dir.path_join(STAND_IN_FILE)
	if with_iglesias:
		if FileAccess.file_exists(stand_in):
			DirAccess.remove_absolute(stand_in)
	else:
		files.append([STAND_IN_FILE, STAND_IN_TEXT])
	for entry: Array in files:
		var file: FileAccess = FileAccess.open(out_dir.path_join(entry[0]), FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(entry[1])
		file.close()
	return OK


static func _font_licences() -> PackedStringArray:
	var out: PackedStringArray = []
	for file: String in DirAccess.get_files_at(FONTS):
		if file.ends_with(FONT_LICENCE_SUFFIX):
			out.append(file)
	out.sort()
	return out


static func _heading(title: String) -> String:
	return "%s\n%s\n" % [title, "=".repeat(title.length())]


## "ZenKakuGothicNew" -> "Zen Kaku Gothic New".
static func _spaced(camel: String) -> String:
	var out: String = ""
	for i: int in camel.length():
		var c: String = camel[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower() and camel[i - 1] == camel[i - 1].to_lower():
			out += " "
		out += c
	return out
