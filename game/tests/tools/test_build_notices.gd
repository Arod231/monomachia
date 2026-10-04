extends GutTest
## The text files the Windows build carries beside the exe (tools/
## build_notices.gd, plan task 25.4): LICENSE.txt, CREDITS.txt and
## THIRD-PARTY-NOTICES.txt. Whether every pack and asset folder is credited is
## checked by tests/credits.test.mjs.

const OUT: String = "user://test_build_notices"
const SAMPLE: String = "# Credits\n\nBy us.\n\n<!-- packs: kevin_iglesias -->\nAnimation by Kevin Iglesias.\n<!-- /packs -->\n\nSound by them.\n"


func after_each() -> void:
	for file: String in [BuildNotices.LICENSE_FILE, BuildNotices.CREDITS_FILE, BuildNotices.NOTICES_FILE, BuildNotices.STAND_IN_FILE]:
		DirAccess.remove_absolute(OUT.path_join(file))
	DirAccess.remove_absolute(OUT)


func _repo_file(name: String) -> String:
	return FileAccess.get_file_as_string(AssetSource.repo_root().path_join(name))


func test_credits_keep_the_iglesias_packs_when_the_build_holds_their_clips() -> void:
	var text: String = BuildNotices.credits_text(SAMPLE, true)
	assert_string_contains(text, "Animation by Kevin Iglesias.")
	assert_string_contains(text, "Sound by them.")
	assert_false(text.contains("<!--"), "the section's markers are left out")


func test_credits_leave_the_iglesias_packs_out_of_a_build_without_their_clips() -> void:
	var text: String = BuildNotices.credits_text(SAMPLE, false)
	assert_false(text.contains("Kevin Iglesias"))
	assert_string_contains(text, "By us.")
	assert_string_contains(text, "Sound by them.")
	assert_false(text.contains("\n\n\n"), "no gap is left where the section was")


func test_the_repositorys_credits_mark_off_the_iglesias_packs() -> void:
	var credits: String = _repo_file("CREDITS.md")
	assert_eq(credits.count(BuildNotices.IGLESIAS_BEGIN), 1)
	assert_eq(credits.count(BuildNotices.IGLESIAS_END), 1)
	assert_lt(credits.find(BuildNotices.IGLESIAS_BEGIN), credits.find(BuildNotices.IGLESIAS_END))
	assert_string_contains(BuildNotices.credits_text(credits, true), "Kevin Iglesias")
	assert_false(BuildNotices.credits_text(credits, false).contains("Kevin Iglesias"))


func test_notices_carry_the_engines_licence_and_every_component() -> void:
	var text: String = BuildNotices.notices_text()
	assert_string_contains(text, Engine.get_license_text())
	for component: Dictionary in Engine.get_copyright_info():
		assert_string_contains(text, String(component["name"]))
		for part: Dictionary in component["parts"]:
			for line: String in part["copyright"]:
				assert_string_contains(text, line)
	var licences: Dictionary = Engine.get_license_info()
	assert_gt(licences.size(), 0)
	for id: String in licences:
		assert_true(text.contains(String(licences[id]).strip_edges()), "licence %s" % id)


func test_notices_carry_each_bundled_fonts_licence() -> void:
	var text: String = BuildNotices.notices_text()
	var fonts: PackedStringArray = DirAccess.get_files_at(BuildNotices.FONTS)
	var licences: int = 0
	for file: String in fonts:
		if not file.ends_with(BuildNotices.FONT_LICENCE_SUFFIX):
			continue
		licences += 1
		assert_true(text.contains(FileAccess.get_file_as_string(BuildNotices.FONTS.path_join(file)).strip_edges()), file)
	assert_eq(licences, 2, "Zen Antique and Zen Kaku Gothic New")
	assert_string_contains(text, "Zen Antique")
	assert_string_contains(text, "Zen Kaku Gothic New")


func test_write_puts_the_three_files_in_the_folder() -> void:
	assert_eq(BuildNotices.write(ProjectSettings.globalize_path(OUT), false), OK)
	var licence: String = FileAccess.get_file_as_string(OUT.path_join(BuildNotices.LICENSE_FILE))
	var credits: String = FileAccess.get_file_as_string(OUT.path_join(BuildNotices.CREDITS_FILE))
	var notices: String = FileAccess.get_file_as_string(OUT.path_join(BuildNotices.NOTICES_FILE))
	assert_eq(licence, _repo_file("LICENSE"))
	assert_eq(credits, BuildNotices.credits_text(_repo_file("CREDITS.md"), false))
	assert_eq(notices, BuildNotices.notices_text())


func test_a_build_without_the_clips_says_it_is_a_stand_in() -> void:
	assert_eq(BuildNotices.write(ProjectSettings.globalize_path(OUT), false), OK)
	var note: String = FileAccess.get_file_as_string(OUT.path_join(BuildNotices.STAND_IN_FILE))
	assert_eq(note, BuildNotices.STAND_IN_TEXT)
	assert_string_contains(note, "stand-in")
	assert_string_contains(note, "not a release")


func test_a_build_with_the_clips_drops_a_stale_stand_in_note() -> void:
	assert_eq(BuildNotices.write(ProjectSettings.globalize_path(OUT), false), OK)
	assert_true(FileAccess.file_exists(OUT.path_join(BuildNotices.STAND_IN_FILE)))
	assert_eq(BuildNotices.write(ProjectSettings.globalize_path(OUT), true), OK)
	assert_false(FileAccess.file_exists(OUT.path_join(BuildNotices.STAND_IN_FILE)))
	assert_string_contains(FileAccess.get_file_as_string(OUT.path_join(BuildNotices.CREDITS_FILE)), "Kevin Iglesias")
