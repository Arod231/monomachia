extends GutTest
## StudioLibraries (tools/anim_studio/studio_libraries.gd, task 4): the clip
## libraries the Studio plays from, loaded once and shared.


func after_each() -> void:
	ClipLibraries.force_missing = false


func test_the_cc0_library_is_the_games() -> void:
	assert_same(StudioLibraries.ual(), FighterModel.ANIMATION_LIBRARY, "one copy")
	assert_true(StudioLibraries.ual().has_animation(&"Sword_Idle"), "with the committed clips")


func test_the_keyed_library_is_loaded_once() -> void:
	var lib: AnimationLibrary = StudioLibraries.keyed()
	assert_not_null(lib, "the committed library loads")
	assert_true(lib.has_animation(KeyedClips.STOMP), "it has the stomp")
	assert_same(StudioLibraries.keyed(), lib, "the second call shares it")


func test_reset_drops_the_cached_libraries() -> void:
	var lib: AnimationLibrary = StudioLibraries.keyed()
	assert_same(StudioLibraries.keyed(), lib, "cached")
	StudioLibraries.reset()
	var again: AnimationLibrary = StudioLibraries.keyed()
	assert_not_null(again, "loaded again")
	assert_true(again.has_animation(KeyedClips.STOMP), "with its clips")
	assert_same(StudioLibraries.keyed(), again, "and cached again")


func test_the_packs_follow_the_game() -> void:
	assert_eq(StudioLibraries.available(), ClipLibraries.available(), "available as the game says")
	ClipLibraries.force_missing = true
	assert_false(StudioLibraries.available(), "force_missing plays it as a fresh clone does")
	assert_null(StudioLibraries.get_set(&"HumanM"), "and no set loads")


func test_a_set_is_loaded_once() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	for set_name: StringName in ClipLibraries.SETS:
		var lib: AnimationLibrary = StudioLibraries.get_set(set_name)
		assert_not_null(lib, "%s loads" % set_name)
		assert_same(StudioLibraries.get_set(set_name), lib, "%s is shared" % set_name)
	assert_null(StudioLibraries.get_set(&"NoSuchSet"), "an unknown set is null")


func test_the_sets_come_together_or_not_at_all() -> void:
	ClipLibraries.force_missing = true
	assert_true(StudioLibraries.sets().is_empty(), "no packs, no sets")
	ClipLibraries.force_missing = false
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var sets: Dictionary[StringName, AnimationLibrary] = StudioLibraries.sets()
	assert_eq(sets.size(), ClipLibraries.SETS.size(), "every set")
	for set_name: StringName in ClipLibraries.SETS:
		assert_same(sets[set_name], StudioLibraries.get_set(set_name), "%s is the shared one" % set_name)
