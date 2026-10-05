extends GutTest
## GalleryFilter (tools/anim_studio/gallery/gallery_filter.gd, docs/specs/
## animation-studio.md, task 6): which entries the gallery's search box and
## badge chips let through.


func _entry(entry_name: String, id: StringName, badges: Array[StringName] = []) -> StudioCatalogue.Entry:
	var e: StudioCatalogue.Entry = StudioCatalogue.Entry.new()
	e.name = entry_name
	e.id = id
	for b: StringName in badges:
		e.badges[b] = true
	return e


func test_no_text_and_no_badges_lets_everything_through() -> void:
	assert_true(GalleryFilter.matches(_entry("Light slash", &"light_1"), "", [] as Array[StringName]))


func test_text_matches_the_name() -> void:
	var e: StudioCatalogue.Entry = _entry("Overhead chop", &"heavy_1")
	assert_true(GalleryFilter.matches(e, "chop", [] as Array[StringName]), "a part of the name")
	assert_true(GalleryFilter.matches(e, "Overhead chop", [] as Array[StringName]), "the whole name")
	assert_false(GalleryFilter.matches(e, "thrust", [] as Array[StringName]), "text that is nowhere")


func test_text_matches_the_id() -> void:
	var e: StudioCatalogue.Entry = _entry("Overhead chop", &"heavy_1")
	assert_true(GalleryFilter.matches(e, "heavy_1", [] as Array[StringName]), "the id")
	assert_true(GalleryFilter.matches(e, "vy_", [] as Array[StringName]), "a part of the id")


func test_text_ignores_case() -> void:
	var e: StudioCatalogue.Entry = _entry("Overhead Chop", &"Heavy_1")
	assert_true(GalleryFilter.matches(e, "OVERHEAD", [] as Array[StringName]), "upper case text, mixed name")
	assert_true(GalleryFilter.matches(e, "heavy_1", [] as Array[StringName]), "lower case text, mixed id")
	assert_true(GalleryFilter.matches(e, "hEaVy", [] as Array[StringName]), "odd case")


func test_text_ignores_the_spaces_round_it() -> void:
	assert_true(GalleryFilter.matches(_entry("Overhead chop", &"heavy_1"), "  chop  ", [] as Array[StringName]))
	assert_true(GalleryFilter.matches(_entry("Overhead chop", &"heavy_1"), "   ", [] as Array[StringName]), "only spaces is no text")


func test_a_badge_must_be_set() -> void:
	var fallback: StudioCatalogue.Entry = _entry("A", &"a", [&"fallback"] as Array[StringName])
	var plain: StudioCatalogue.Entry = _entry("B", &"b")
	var chosen: Array[StringName] = [&"fallback"]
	assert_true(GalleryFilter.matches(fallback, "", chosen), "it has the badge")
	assert_false(GalleryFilter.matches(plain, "", chosen), "it doesn't")


func test_every_chosen_badge_must_be_set() -> void:
	var both: StudioCatalogue.Entry = _entry("A", &"a", [&"fallback", &"provisional"] as Array[StringName])
	var one: StudioCatalogue.Entry = _entry("B", &"b", [&"fallback"] as Array[StringName])
	var chosen: Array[StringName] = [&"fallback", &"provisional"]
	assert_true(GalleryFilter.matches(both, "", chosen), "both set")
	assert_false(GalleryFilter.matches(one, "", chosen), "one of two isn't enough")


func test_a_badge_the_entry_has_set_false_doesnt_count() -> void:
	var e: StudioCatalogue.Entry = _entry("A", &"a")
	e.badges[&"fallback"] = false
	assert_false(GalleryFilter.matches(e, "", [&"fallback"] as Array[StringName]))


func test_text_and_badges_both_have_to_hold() -> void:
	var e: StudioCatalogue.Entry = _entry("Overhead chop", &"heavy_1", [&"fallback"] as Array[StringName])
	var chosen: Array[StringName] = [&"fallback"]
	assert_true(GalleryFilter.matches(e, "chop", chosen), "both hold")
	assert_false(GalleryFilter.matches(e, "thrust", chosen), "the text fails")
	assert_false(GalleryFilter.matches(e, "chop", [&"fallback", &"balance"] as Array[StringName]), "a badge fails")
