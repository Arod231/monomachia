extends SceneTree
## Writes LICENSE.txt, CREDITS.txt and THIRD-PARTY-NOTICES.txt (BuildNotices)
## into a build's folder. `node scripts/godot.mjs build` runs it after every
## export:
##
##   node scripts/godot.mjs script res://tools/write_build_notices.gd -- --out=<folder>
##
## The credits name the Kevin Iglesias packs only when the clip libraries are
## in the project (ClipLibraries.available()), since the export packs them
## then and only then; without them it also writes STAND-IN.txt.


func _initialize() -> void:
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("write_build_notices.gd: pass --out=<folder>")
		quit(1)
		return
	var with_iglesias: bool = ClipLibraries.available()
	var err: Error = BuildNotices.write(out, with_iglesias)
	if err != OK:
		push_error("write_build_notices.gd: writing into %s failed (%s)" % [out, error_string(err)])
		quit(1)
		return
	print("write_build_notices.gd: wrote %s, %s and %s into %s (%s)." % [
		BuildNotices.LICENSE_FILE, BuildNotices.CREDITS_FILE, BuildNotices.NOTICES_FILE, out,
		"Kevin Iglesias packs credited" if with_iglesias
		else "no clip libraries: Kevin Iglesias packs left out, and %s written" % BuildNotices.STAND_IN_FILE])
	quit(0)
