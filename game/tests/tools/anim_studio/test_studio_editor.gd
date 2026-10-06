extends GutTest
## The Studio's editor (StudioEditor, milestone-1 task 25), headless: opened
## from the gallery on a Katana light it poses the fighter, shows the move's
## frames and bands and its distance check, draws its markers and rules bars
## on the timeline, scrubs, steps, toggles foot locking and goes back. Plays
## with or without the packs (their fallback clip without).

const SCENE: String = "res://tools/anim_studio/studio.tscn"


func _studio() -> AnimStudio:
	var studio: AnimStudio = (load(SCENE) as PackedScene).instantiate() as AnimStudio
	add_child_autofree(studio)
	await get_tree().process_frame
	return studio


func _open(studio: AnimStudio, id: StringName) -> StudioEditor:
	studio.open_editor(studio.catalogue.find(StudioCatalogue.KIND_MOVE, id))
	return studio.editor


func test_opening_a_katana_light_shows_its_frames_against_its_band() -> void:
	var studio: AnimStudio = await _studio()
	var editor: StudioEditor = _open(studio, &"k_l1")
	assert_not_null(editor.model, "a fighter")
	assert_not_null(editor.poser, "playing the move")
	assert_eq(editor.view.kind, &"string_light")
	var verdict: Label = editor.get_node("%Verdict")
	# re-keyed into its band (task 31)
	assert_eq(verdict.text, "string light · in band")
	var fields: Array = (editor.get_node("%BandFields") as Node).get_children().map(func(l: Label) -> String: return l.text)
	assert_eq(fields, ["✓ startup 28 (24-30)", "✓ active 4 (3-6)", "✓ recovery 28 (24-36)"])
	var distance: Array = (editor.get_node("%DistanceLines") as Node).get_children().map(func(l: Label) -> String: return l.text)
	assert_eq(distance.size(), 3, "the duelling, preferred and miss distances: %s" % [distance])
	assert_true(distance[2].ends_with("misses from 3.25 m") or distance[2].contains("where it must miss"), "%s" % [distance])
	assert_eq(editor.get_node("%EditorTitle").text, "Right Cut · k_l1")


func test_the_timeline_shows_the_move_s_markers_and_rules_bars() -> void:
	var studio: AnimStudio = await _studio()
	var editor: StudioEditor = _open(studio, &"k_l1")
	var tl: StudioTimeline = editor.timeline
	var markers: Dictionary = MoveClips.read(ClipManifest.read()).of(&"katana")[&"k_l1"].markers
	assert_eq(tl.markers["windup"], float(markers["windup"]))
	assert_eq(tl.markers["active_start"], float(markers["active_start"]))
	assert_true(tl.markers.has("branch k_l2"), "a follow-up's branch point")
	assert_same(tl.view, editor.view, "the rules bars")
	assert_gt(tl.length, 0.0)
	assert_eq(tl.length, editor.playback.length)


func test_scrubbing_and_stepping_move_the_playhead() -> void:
	var studio: AnimStudio = await _studio()
	var editor: StudioEditor = _open(studio, &"k_l1")
	var tl: StudioTimeline = editor.timeline
	tl.size = Vector2(1000.0, tl.custom_minimum_size.y)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(tl.x_of(10.0), 5.0)
	tl._gui_input(press)
	assert_almost_eq(editor.playback.frame, 10.0, 1e-6, "a click scrubs")
	var right: InputEventKey = InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	editor._unhandled_key_input(right)
	assert_eq(editor.playback.frame, 11.0, "Right steps a frame")
	assert_eq(tl.frame, 11.0, "and the playhead follows")


func test_foot_locking_switches_on_the_rig() -> void:
	var studio: AnimStudio = await _studio()
	var editor: StudioEditor = _open(studio, &"k_l1")
	assert_not_null(editor.model.rig.foot_lock, "on by default, as in a match")
	(editor.get_node("%FootLock") as CheckBox).button_pressed = false
	assert_false(editor.foot_lock_on)
	assert_null(editor.model.rig.foot_lock, "off")
	editor.set_foot_lock(true)
	assert_not_null(editor.model.rig.foot_lock, "on again")


func test_inertial_blending_switches_on_the_rig() -> void:
	# milestone-1 task 23's layer toggle: on by default, as in a match; a
	# loop back to the start blends as a follow-up would, any other jump cuts
	var studio: AnimStudio = await _studio()
	var editor: StudioEditor = _open(studio, &"k_l1")
	var inertial: InertialBlend = editor.model.rig.inertial
	assert_true(inertial.active, "on by default")
	(editor.get_node("%InertialBlending") as CheckBox).button_pressed = false
	assert_false(editor.inertial_on)
	assert_false(inertial.active, "off")
	editor.set_inertial_blending(true)
	assert_true(inertial.active, "on again")
	editor.playback.seek(12.0)
	editor._pose()
	assert_almost_eq(inertial.time, 24.0, 1e-9, "the rules frames at the playhead")
	editor.playback.seek(editor.playback.length)
	editor._pose()
	editor._wrapped()
	assert_true(inertial.blending(), "the loop back blends")
	editor.playback.seek(5.0)
	editor._pose()
	assert_false(inertial.blending(), "a jump cuts")


func test_a_state_has_no_bands_and_back_returns_to_the_gallery() -> void:
	var studio: AnimStudio = await _studio()
	studio.open_editor(studio.catalogue.find(StudioCatalogue.KIND_STATE, &"knockdown"))
	var editor: StudioEditor = studio.editor
	assert_null(editor.view)
	assert_eq(editor.get_node("%Verdict").text, "Frames and bands are shown for moves.")
	(editor.get_node("%BackButton") as Button).pressed.emit()
	assert_true((studio.get_node("%Gallery") as Control).visible, "back in the gallery")
	assert_null(editor.model, "the fighter is freed")


func test_without_the_packs_it_plays_the_fallback() -> void:
	ClipLibraries.force_missing = true
	StudioLibraries.reset()
	var studio: AnimStudio = await _studio()
	var editor: StudioEditor = _open(studio, &"k_l1")
	assert_not_null(editor.poser, "the CC0 fallback plays")
	assert_true(editor.get_node("%EditorNote").visible, "and says the packs are missing")
	assert_eq(editor.view.kind, &"string_light", "the bands come from the committed tables all the same")


func after_each() -> void:
	ClipLibraries.force_missing = false
	StudioLibraries.reset()


func test_the_camera_presets_and_orbit() -> void:
	var cam: OrbitCamera = OrbitCamera.new()
	add_child_autofree(cam)
	cam.use_preset(&"front")
	assert_gt(cam.position.z, 1.0, "in front of the fighter (it faces +Z)")
	cam.use_preset(&"side")
	assert_lt(cam.position.x, -1.0, "at its right side")
	cam.use_preset(&"top")
	assert_gt(cam.position.y, 3.0, "above it")
	cam.use_preset(&"match")
	assert_lt(cam.position.z, -1.0, "behind it")
	var yaw: float = cam.yaw
	cam.orbit(50.0, 0.0)
	assert_ne(cam.yaw, yaw, "a drag orbits")
	var d: float = cam.distance
	cam.zoom(1.0)
	assert_lt(cam.distance, d, "the wheel zooms in")
