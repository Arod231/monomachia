extends GutTest
## Gallery (tools/anim_studio/gallery/gallery.gd, docs/specs/animation-studio.md,
## task 6): tabs of live tiles built lazily per tab, only the tiles on screen
## playing, search and badge filters, the body switch and the click through to
## the editor. Runs on the fallback path (`force_missing`), so it needs no
## clip libraries.

const GALLERY_SCENE: PackedScene = preload("res://tools/anim_studio/gallery/gallery.tscn")
const STUDIO_SCENE: PackedScene = preload("res://tools/anim_studio/studio.tscn")

var _catalogue: StudioCatalogue


func before_each() -> void:
	AnimTile.builds_per_frame = 1000000
	ClipLibraries.force_missing = true
	var manifest: ClipManifest = ClipManifest.read()
	_catalogue = StudioCatalogue.build(manifest, MoveClips.read(manifest), StateClips.read(), StudioLibraries.keyed().get_animation_list())


func after_each() -> void:
	AnimTile.builds_per_frame = 2
	ClipLibraries.force_missing = false


## A gallery in a 1200x800 area, set up on `catalogue`, a few frames in.
func _gallery(fighter_id: StringName = &"hunter", catalogue: StudioCatalogue = null) -> Gallery:
	var area: Control = Control.new()
	area.custom_minimum_size = Vector2(1200.0, 800.0)
	area.size = Vector2(1200.0, 800.0)
	add_child_autofree(area)
	var gallery: Gallery = GALLERY_SCENE.instantiate() as Gallery
	gallery.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(gallery)
	gallery.setup(catalogue if catalogue != null else _catalogue, fighter_id)
	await wait_process_frames(3)
	return gallery


func _playing(tiles: Array[AnimTile]) -> Array[AnimTile]:
	return tiles.filter(func(t: AnimTile) -> bool: return t.is_playing())


func _built(tiles: Array[AnimTile]) -> Array[AnimTile]:
	return tiles.filter(func(t: AnimTile) -> bool: return t.model != null)


# --- tabs ------------------------------------------------------------------------


func test_the_tabs_are_the_catalogue_groups_in_order() -> void:
	var gallery: Gallery = await _gallery()
	assert_eq(gallery.groups(), [&"katana", &"daggers", &"greatsword", &"fists", &"states", &"ults", &"source"] as Array[StringName])
	var tabs: TabContainer = gallery.get_node("%Tabs")
	assert_eq(tabs.get_tab_count(), 7)
	assert_eq(tabs.get_tab_title(0), "Katana")
	assert_eq(tabs.get_tab_title(4), "States")
	assert_eq(tabs.get_tab_title(6), "Source")


func test_only_the_open_tab_has_tiles() -> void:
	var gallery: Gallery = await _gallery()
	assert_eq(gallery.current_group(), &"katana", "it opens on the Katana")
	assert_true(gallery.is_tab_built(&"katana"))
	assert_eq(gallery.tiles_in(&"katana").size(), _catalogue.in_group(&"katana").size(), "a tile for each Katana entry")
	for g: StringName in [&"daggers", &"greatsword", &"fists", &"states", &"ults", &"source"]:
		assert_false(gallery.is_tab_built(g), "%s isn't built" % g)
		assert_eq(gallery.tiles_in(g).size(), 0, "%s has no tiles" % g)


func test_switching_to_a_tab_builds_that_tabs_tiles_once() -> void:
	var gallery: Gallery = await _gallery()
	gallery.show_group(&"states")
	await wait_process_frames(2)
	assert_eq(gallery.current_group(), &"states")
	assert_eq(gallery.tiles_in(&"states").size(), _catalogue.in_group(&"states").size())
	assert_eq(gallery.tiles_in(&"daggers").size(), 0, "the others stay unbuilt")
	var first: AnimTile = gallery.tiles_in(&"states")[0]
	gallery.show_group(&"katana")
	gallery.show_group(&"states")
	assert_same(gallery.tiles_in(&"states")[0], first, "coming back reuses the tiles")
	assert_eq(gallery.tiles_in(&"states").size(), _catalogue.in_group(&"states").size(), "and does not add more")


func test_choosing_a_tab_header_builds_it() -> void:
	var gallery: Gallery = await _gallery()
	(gallery.get_node("%Tabs") as TabContainer).current_tab = 1
	assert_eq(gallery.current_group(), &"daggers")
	assert_true(gallery.is_tab_built(&"daggers"))


func test_every_group_builds_its_tiles_without_the_packs() -> void:
	var gallery: Gallery = await _gallery()
	for g: StringName in gallery.groups():
		gallery.show_group(g)
		await wait_process_frames(2)
		assert_eq(gallery.tiles_in(g).size(), _catalogue.in_group(g).size(), "%s has a tile for each entry" % g)


# --- on screen ---------------------------------------------------------------------


func test_only_tiles_on_screen_play() -> void:
	var gallery: Gallery = await _gallery()
	gallery.show_group(&"source")
	await wait_process_frames(4)
	var tiles: Array[AnimTile] = gallery.tiles_in(&"source")
	assert_gt(tiles.size(), 12, "a long tab, more than a screenful")
	var playing: Array[AnimTile] = _playing(tiles)
	assert_gt(playing.size(), 0, "the tiles in view play")
	assert_lt(playing.size(), tiles.size(), "the ones below the fold do not")
	for t: AnimTile in tiles:
		assert_eq(t.is_playing(), t.is_on_screen(), "%s plays exactly when it is on screen" % t.entry.id)
		assert_eq(t.model != null, t.is_playing(), "and only a playing tile has built its fighter")


func test_a_tab_you_leave_pauses_and_the_other_plays() -> void:
	var gallery: Gallery = await _gallery()
	var katana: Array[AnimTile] = gallery.tiles_in(&"katana")
	assert_gt(_playing(katana).size(), 0, "the Katana tiles play")
	gallery.show_group(&"daggers")
	await wait_process_frames(3)
	assert_eq(_playing(katana).size(), 0, "left behind, none of the Katana tiles play")
	assert_gt(_playing(gallery.tiles_in(&"daggers")).size(), 0, "the Daggers tiles play")


func test_scrolling_plays_the_tiles_that_come_into_view() -> void:
	var gallery: Gallery = await _gallery()
	gallery.show_group(&"source")
	await wait_process_frames(4)
	var tiles: Array[AnimTile] = gallery.tiles_in(&"source")
	var last: AnimTile = tiles[tiles.size() - 1]
	assert_false(last.is_playing(), "the last tile is out of view")
	var scroll: ScrollContainer = gallery.scroll_of(&"source")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await wait_process_frames(3)
	assert_true(last.is_playing(), "it plays once scrolled to")
	assert_false(tiles[0].is_playing(), "and the first has paused")


# --- the body --------------------------------------------------------------------------


func test_the_body_switch_re_sets_up_the_tiles_on_both_built_tabs() -> void:
	var gallery: Gallery = await _gallery()
	gallery.show_group(&"daggers")
	await wait_process_frames(3)
	gallery.set_fighter(&"rogue")
	await wait_process_frames(3)
	for g: StringName in [&"katana", &"daggers"]:
		for t: AnimTile in gallery.tiles_in(g):
			assert_eq(t.fighter_id, &"rogue", "%s tile is set up on the Rogue" % t.entry.id)
	for t: AnimTile in _playing(gallery.tiles_in(&"daggers")):
		assert_eq(t.model.look.id, &"rogue", "a playing tile has the Rogue's fighter")
	gallery.show_group(&"states")
	await wait_process_frames(3)
	for t: AnimTile in _built(gallery.tiles_in(&"states")):
		assert_eq(t.model.look.id, &"rogue", "a tab built after the switch is on the Rogue")


func test_the_gallery_opens_on_the_body_it_is_given() -> void:
	var gallery: Gallery = await _gallery(&"rogue")
	var built: Array[AnimTile] = _built(gallery.tiles_in(&"katana"))
	assert_gt(built.size(), 0, "some tiles are playing")
	for t: AnimTile in built:
		assert_eq(t.model.look.id, &"rogue")


# --- search and badge filters ------------------------------------------------------------


func test_the_search_box_hides_the_tiles_that_dont_match() -> void:
	var gallery: Gallery = await _gallery()
	var tiles: Array[AnimTile] = gallery.tiles_in(&"katana")
	var wanted: String = String(tiles[0].entry.id).to_upper()
	var search: LineEdit = gallery.get_node("%Search")
	search.text = wanted
	search.text_changed.emit(wanted)
	var shown: Array[AnimTile] = tiles.filter(func(t: AnimTile) -> bool: return t.visible)
	assert_gt(shown.size(), 0, "something matches")
	assert_lt(shown.size(), tiles.size(), "not everything")
	for t: AnimTile in shown:
		assert_true(GalleryFilter.matches(t.entry, wanted, [] as Array[StringName]))
	await wait_process_frames(2)
	for t: AnimTile in tiles:
		if not t.visible:
			assert_false(t.is_playing(), "a hidden tile does not play")


func test_a_filter_applies_to_a_tab_built_later() -> void:
	var gallery: Gallery = await _gallery()
	gallery.set_filter("zzz no such animation", [] as Array[StringName])
	gallery.show_group(&"states")
	for t: AnimTile in gallery.tiles_in(&"states"):
		assert_false(t.visible, "%s is filtered out" % t.entry.id)
	assert_true((gallery.get_node("%EmptyNote") as Control).visible, "the tab says nothing matches")
	gallery.set_filter("", [] as Array[StringName])
	assert_false((gallery.get_node("%EmptyNote") as Control).visible)
	for t: AnimTile in gallery.tiles_in(&"states"):
		assert_true(t.visible)


func test_badge_chips_filter_by_badge() -> void:
	var gallery: Gallery = await _gallery()
	var tiles: Array[AnimTile] = gallery.tiles_in(&"katana")
	tiles[0].entry.badges[&"balance"] = true
	var chip: Button = gallery.get_node("%Badge_balance")
	chip.button_pressed = true
	for t: AnimTile in tiles:
		assert_eq(t.visible, t.entry.badges[&"balance"], "%s: shown only when it has the badge" % t.entry.id)
	chip.button_pressed = false
	for t: AnimTile in tiles:
		assert_true(t.visible, "chip off, all back")


func test_the_count_says_how_many_of_the_tab_show() -> void:
	var gallery: Gallery = await _gallery()
	var total: int = _catalogue.in_group(&"katana").size()
	var count: Label = gallery.get_node("%CountLabel")
	assert_string_contains(count.text, str(total))
	gallery.set_filter("zzz no such animation", [] as Array[StringName])
	assert_string_contains(count.text, "0 of %d" % total)


# --- errors and clicking -------------------------------------------------------------------


func test_data_errors_show_in_a_banner() -> void:
	var clean: Gallery = await _gallery()
	assert_false((clean.get_node("%ErrorBanner") as Control).visible, "no errors, no banner")
	_catalogue.errors = PackedStringArray(["move_clips.json: line 3: expected a number", "state_clips.json: cannot open"])
	var gallery: Gallery = await _gallery()
	assert_true((gallery.get_node("%ErrorBanner") as Control).visible, "errors show a banner")
	var text: String = (gallery.get_node("%ErrorLabel") as Label).text
	assert_string_contains(text, "move_clips.json: line 3: expected a number")
	assert_string_contains(text, "state_clips.json: cannot open")


func test_a_tile_click_opens_its_entry() -> void:
	var gallery: Gallery = await _gallery()
	watch_signals(gallery)
	var tile: AnimTile = gallery.tiles_in(&"katana")[2]
	tile.opened.emit(tile.entry)
	assert_signal_emitted_with_parameters(gallery, "opened", [tile.entry])


# --- in the studio -----------------------------------------------------------------------


func _studio() -> AnimStudio:
	var studio: AnimStudio = STUDIO_SCENE.instantiate() as AnimStudio
	add_child_autofree(studio)
	await wait_process_frames(3)
	return studio


func test_the_studio_shows_the_gallery_with_its_catalogue() -> void:
	var studio: AnimStudio = await _studio()
	var gallery: Gallery = studio.get_node("%Gallery") as Gallery
	assert_not_null(gallery, "the gallery fills the central area")
	assert_true(gallery.is_tab_built(&"katana"), "its first tab is built")
	assert_gt(gallery.tiles_in(&"katana").size(), 0)


func test_the_studios_body_toggle_switches_the_gallery() -> void:
	var studio: AnimStudio = await _studio()
	var gallery: Gallery = studio.get_node("%Gallery") as Gallery
	studio.set_fighter(&"rogue")
	await wait_process_frames(3)
	for t: AnimTile in gallery.tiles_in(&"katana"):
		assert_eq(t.fighter_id, &"rogue")
	assert_eq(gallery.fighter_id, &"rogue")


func test_clicking_a_tile_opens_the_editor_in_the_studio() -> void:
	var studio: AnimStudio = await _studio()
	var gallery: Gallery = studio.get_node("%Gallery") as Gallery
	var tile: AnimTile = gallery.tiles_in(&"katana")[1]
	tile.opened.emit(tile.entry)
	assert_same(studio.current_entry, tile.entry, "the studio has the entry")
	assert_false(gallery.visible, "the gallery gives way")
	assert_true((studio.get_node("%Editor") as Control).visible, "to the editor")
	await wait_process_frames(2)
	assert_eq(_playing(gallery.tiles_in(&"katana")).size(), 0, "and its tiles stop playing")


# --- the build budget, a repeated setup, an unknown group, refresh_filter ------------------


func test_opening_a_tab_builds_a_couple_of_tiles_a_frame() -> void:
	AnimTile.builds_per_frame = 2
	var gallery: Gallery = await _gallery()
	gallery.show_group(&"source")
	await wait_process_frames(1)
	var tiles: Array[AnimTile] = gallery.tiles_in(&"source")
	var before: int = _built(tiles).size()
	var frame: int = Engine.get_process_frames()
	await wait_process_frames(1)
	var elapsed: int = Engine.get_process_frames() - frame
	assert_lte(_built(tiles).size() - before, 2 * elapsed, "%d frame(s) build at most two each" % elapsed)
	await wait_process_frames(10)
	assert_eq(_built(tiles).size(), _playing(tiles).size(), "in the end every tile in view is built")
	assert_gt(_built(tiles).size(), 0)


func test_a_body_switch_in_the_gallery_rebuilds_a_few_a_frame() -> void:
	var gallery: Gallery = await _gallery()
	var tiles: Array[AnimTile] = gallery.tiles_in(&"katana")
	var visible_count: int = _built(tiles).size()
	assert_gt(visible_count, 4, "enough tiles in view to need several frames")
	AnimTile.builds_per_frame = 2
	gallery.set_fighter(&"rogue")
	assert_eq(_built(tiles).size(), 0, "every fighter is dropped at the switch")
	await wait_process_frames(1)
	var after_one: int = _built(tiles).size()
	assert_lt(after_one, visible_count, "not all come back at once")
	assert_lte(after_one, 4, "a couple a frame")
	await wait_process_frames(visible_count + 2)
	assert_eq(_built(tiles).size(), visible_count, "but they all do")


func test_showing_a_group_with_no_tab_does_nothing() -> void:
	var gallery: Gallery = await _gallery()
	gallery.show_group(&"states")
	gallery.show_group(&"no_such_group")
	assert_eq(gallery.current_group(), &"states", "the open tab stays")
	assert_eq((gallery.get_node("%Tabs") as TabContainer).current_tab, 4)
	gallery.show_group(&"")
	assert_eq(gallery.current_group(), &"states")


func test_setting_the_gallery_up_again_replaces_its_tiles() -> void:
	var gallery: Gallery = await _gallery()
	gallery.show_group(&"states")
	var flow: Node = gallery.scroll_of(&"katana").get_child(0).get_child(0)
	var old: Array[AnimTile] = gallery.tiles_in(&"katana")
	assert_eq(flow.get_child_count(), old.size())
	gallery.setup(_catalogue, &"rogue")
	assert_eq(flow.get_child_count(), 0, "the old tiles are out of the flow at once, before they are freed")
	for t: AnimTile in old:
		assert_null(t.get_parent(), "%s is out of the tree" % t.entry.id)
	assert_eq(gallery.fighter_id, &"rogue")
	assert_false(gallery.is_tab_built(&"katana"), "a tab that is not open starts unbuilt again")
	assert_true(gallery.is_tab_built(&"states"), "and the open one is made at once")
	assert_eq(gallery.tiles_in(&"states").size(), _catalogue.in_group(&"states").size())
	await wait_process_frames(2)
	gallery.show_group(&"katana")
	assert_eq(flow.get_child_count(), _catalogue.in_group(&"katana").size(), "one tile for each entry, no more")
	assert_eq(gallery.tiles_in(&"katana").size(), flow.get_child_count())


func test_refresh_filter_applies_badges_set_after_the_tiles_were_made() -> void:
	var gallery: Gallery = await _gallery()
	var tiles: Array[AnimTile] = gallery.tiles_in(&"katana")
	(gallery.get_node("%Badge_unsaved") as Button).button_pressed = true
	for t: AnimTile in tiles:
		assert_false(t.visible, "no entry is unsaved yet")
	tiles[1].entry.badges[&"unsaved"] = true
	tiles[3].entry.badges[&"unsaved"] = true
	gallery.refresh_filter()
	for i: int in tiles.size():
		assert_eq(tiles[i].visible, i == 1 or i == 3, "tile %d" % i)
	assert_string_contains((gallery.get_node("%CountLabel") as Label).text, "2 of %d" % tiles.size())
	tiles[1].entry.badges[&"unsaved"] = false
	gallery.refresh_filter()
	assert_false(tiles[1].visible, "an entry that lost the badge hides")
	assert_true(tiles[3].visible)
	assert_string_contains((gallery.get_node("%CountLabel") as Label).text, "1 of %d" % tiles.size())


func test_refresh_filter_keeps_the_search_text() -> void:
	var gallery: Gallery = await _gallery()
	var tiles: Array[AnimTile] = gallery.tiles_in(&"katana")
	var wanted: String = String(tiles[0].entry.id)
	gallery.set_filter(wanted, [] as Array[StringName])
	var shown: int = tiles.filter(func(t: AnimTile) -> bool: return t.visible).size()
	gallery.refresh_filter()
	assert_eq(tiles.filter(func(t: AnimTile) -> bool: return t.visible).size(), shown, "unchanged data, unchanged result")
