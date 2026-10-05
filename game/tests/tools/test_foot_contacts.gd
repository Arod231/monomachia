extends GutTest
## Foot contacts (milestone-1 task 14): FootContacts.spans() by FootLock's
## plant heights on made-up ankles, writing them into the manifest's text, and
## (local-only) the manifest's contacts against the clips.

const REST: float = 0.08


## An ankle path from heights (m above the rest height) and forward travel (m).
func _ankles(heights: Array, travel: Array = []) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in heights.size():
		out.append(Vector3(0.0, REST + float(heights[i]), float(travel[i]) if i < travel.size() else 0.0))
	return out


func test_a_foot_planted_throughout_is_one_contact() -> void:
	assert_eq(FootContacts.spans(_ankles([0.0, 0.01, 0.0, 0.02]), REST), [PackedInt32Array([0, 3])])


func test_a_step_lifts_and_plants_again() -> void:
	var spans: Array = FootContacts.spans(_ankles([0.0, 0.0, 0.08, 0.15, 0.07, 0.02, 0.0]), REST)
	assert_eq(spans, [PackedInt32Array([0, 1]), PackedInt32Array([5, 6])])


func test_a_held_foot_stays_down_until_it_rises_past_the_lift_height() -> void:
	# 4 cm is above the plant height (3) but under the lift height (6)
	var spans: Array = FootContacts.spans(_ankles([0.0, 0.04, 0.05, 0.07, 0.04, 0.02]), REST)
	assert_eq(spans, [PackedInt32Array([0, 2]), PackedInt32Array([5, 5])], "down at 4-5 cm once planted, not again until under 3 cm")


func test_a_foot_swept_back_on_the_ground_stays_one_contact() -> void:
	# a run played in place: the planted foot sweeps back 20 cm a frame
	var spans: Array = FootContacts.spans(_ankles([0, 0, 0, 0], [0.0, -0.2, -0.4, -0.6]), REST)
	assert_eq(spans, [PackedInt32Array([0, 3])], "the fighter's travel cancels the sweep in the game")


func test_contacts_go_into_the_manifest_after_the_markers_and_are_replaced_after() -> void:
	var text: String = "{\n\t\"clips\": {\n\t\t\"A\": {\n\t\t\t\"markers\": {\n\t\t\t\t\"windup\": 0\n\t\t\t},\n\t\t\t\"groups\": [\"states\"]\n\t\t}\n\t}\n}\n"
	var errors: Array[String] = []
	var once: String = FootContacts.write(text, {&"A": {"left": [[0, 3]], "right": []}}, errors)
	assert_eq(errors, [] as Array[String])
	assert_string_contains(once, "\t\t\t},\n\t\t\t\"foot_contacts\": {\"left\": [[0, 3]], \"right\": []},\n\t\t\t\"groups\"")
	var twice: String = FootContacts.write(once, {&"A": {"left": [[0, 3], [5, 9]], "right": [[1, 2]]}}, errors)
	assert_eq(twice, once.replace("{\"left\": [[0, 3]], \"right\": []}", "{\"left\": [[0, 3], [5, 9]], \"right\": [[1, 2]]}"))
	assert_true(JSON.parse_string(twice) is Dictionary, "still JSON")


func test_local_the_manifests_foot_contacts_are_the_clips() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clips imported (node scripts/godot.mjs clips)")
		return
	var manifest: ClipManifest = ClipManifest.read()
	var model: FighterModel = FootContacts.hunter(self)
	await get_tree().process_frame
	var differ: Array[String] = []
	for id: StringName in manifest.ids():
		if not FootContacts.same(FootContacts.measure(model, id), manifest.clips[id].foot_contacts):
			differ.append(String(id))
	model.queue_free()
	assert_eq(differ, [] as Array[String], "re-measure with node scripts/godot.mjs script res://tools/measure_feet.gd")
