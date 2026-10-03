extends GutTest
## The clip catalogue (tools/shot_scenes/clip_sheet.gd): its pages cover
## every manifest clip, each page holds its weapon, and its options. The
## rendering needs a window and the clip libraries, so it is checked by
## running the shot, not here.

const ClipSheet := preload("res://tools/shot_scenes/clip_sheet.gd")


func _sheet() -> Node3D:
	var s: Node3D = ClipSheet.new()
	s.auto_run = false
	add_child_autofree(s)
	return s


func test_the_pages_show_every_manifest_clip() -> void:
	var s: Node3D = _sheet()
	var m: ClipManifest = ClipManifest.read()
	assert_eq(s.pages, ClipManifest.GROUPS)
	var shown: Dictionary[StringName, bool] = {}
	var rows: int = 0
	for page: StringName in s.pages:
		var ids: Array[StringName] = s.page_clips(page)
		assert_eq(ids, m.in_group(page), "the %s page shows its group" % page)
		rows += ids.size()
		for id: StringName in ids:
			shown[id] = true
	assert_eq(shown.size(), m.clips.size(), "every clip is in the catalogue")
	var listed: int = 0
	for c: ClipManifest.Clip in m.clips.values():
		listed += c.groups.size()
	assert_eq(rows, listed, "a clip shows once on each of its pages")


func test_each_page_holds_its_weapon() -> void:
	var s: Node3D = _sheet()
	assert_eq(s.page_weapon(&"katana"), &"katana")
	assert_eq(s.page_weapon(&"greatsword"), &"greatsword")
	assert_eq(s.page_weapon(&"daggers"), &"daggers")
	assert_eq(s.page_weapon(&"bare"), &"none")
	assert_eq(s.page_weapon(&"states"), &"katana")


func test_it_reads_its_options() -> void:
	var s: Node3D = _sheet()
	var first: StringName = ClipManifest.read().ids()[0]
	s.apply_args(PackedStringArray(["--page=daggers", "--weapon=none", "--clips=%s" % first, "--reverse", "--out=C:/x/sheet.png"]))
	assert_eq(s.pages, [&"daggers"] as Array[StringName])
	assert_eq(s.page_weapon(&"daggers"), &"none")
	assert_eq(s.page_clips(&"daggers"), [first] as Array[StringName])
	assert_true(s.reverse)
	assert_eq(s.out_path, "C:/x/sheet.png")


func test_each_page_goes_beside_the_out_file() -> void:
	assert_eq(ClipSheet.sheet_path("C:/x/sheet.png", &"greatsword"), "C:/x/sheet_greatsword.png")
