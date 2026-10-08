extends GutTest
## SourceEdit (tools/anim_studio/source_edit.gd, docs/specs/animation-studio.md,
## task 2): changes one value in a hand-formatted JSON or GDScript file and
## touches no other byte. The tests work on copies of the real data files' text
## in memory; nothing on disk is written.

const MOVE_CLIPS: String = "res://assets/kevin_iglesias/move_clips.json"
const CLIP_MANIFEST: String = "res://assets/kevin_iglesias/clip_manifest.json"
const KATANA: String = "res://sim/moves/katana.gd"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## `text` with the [start, end) span cut out.
func _cut(text: String, start: int, end: int) -> String:
	return text.substr(0, start) + text.substr(end)


func _errors() -> Array[String]:
	var errors: Array[String] = []
	return errors


## Whether GDScript accepts `text` as a script. The class_name line is dropped
## first: a copy of a game script would otherwise hide the registered class.
func _parses(text: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = ("\n" + text).replace("\nclass_name ", "\n#class_name ")
	return script.reload() == OK


# --- finding ---------------------------------------------------------------


func test_find_reads_a_json_value_by_key_path() -> void:
	var text: String = _read(MOVE_CLIPS)
	# Leaping Cleave, a stand-in (a re-keyed move names no speed: it plays at 1.0x)
	var span: Vector2i = SourceEdit.find_value(text, ["katana", "moves", "k_sh", "speed"])
	assert_ne(span, Vector2i(-1, -1), "speed is found")
	assert_eq(text.substr(span.x, span.y - span.x), "1.4", "the span is the value alone")


func test_find_reads_a_whole_object_value() -> void:
	var text: String = _read(MOVE_CLIPS)
	var span: Vector2i = SourceEdit.find_value(text, ["katana", "moves", "k_sh", "marks"])
	assert_eq(text.substr(span.x, span.y - span.x), '{"windup": 0, "contact": 14, "contact_end": 17.5, "settle": 36}')


func test_find_reads_a_gd_value_under_a_const() -> void:
	var text: String = _read(KATANA)
	var span: Vector2i = SourceEdit.find_value(text, ["MOVES", "k_l1", "damage"])
	assert_ne(span, Vector2i(-1, -1), "damage is found")
	assert_eq(text.substr(span.x, span.y - span.x), "5")


func test_find_matches_stringname_and_string_keys_alike() -> void:
	var text: String = _read(KATANA)
	var move: Vector2i = SourceEdit.find_value(text, ["MOVES", "k_iai"])
	assert_eq(text.substr(move.x, 1), "{", "the &\"k_iai\" key matches k_iai")
	var id: Vector2i = SourceEdit.find_value(text, ["MOVES", "k_iai", "id"])
	assert_eq(text.substr(id.x, id.y - id.x), '&"k_iai"', "a StringName value keeps its &")
	var name_span: Vector2i = SourceEdit.find_value(text, ["MOVES", "k_iai", "name"])
	assert_eq(text.substr(name_span.x, name_span.y - name_span.x), '"Iai Slash (vertical)"', "parentheses inside a string don't matter")


func test_find_spans_a_call_value_whole() -> void:
	var text: String = 'const M: Dictionary = {\n\t"a": {"grip": V3.make(0.0, -0.15, 0.0), "x": StrikeSegment.make(V3.make(1, 2, 3), V3.make(4, 5, 6), 0.015), "y": 2},\n}\n'
	var span: Vector2i = SourceEdit.find_value(text, ["M", "a", "grip"])
	assert_eq(text.substr(span.x, span.y - span.x), "V3.make(0.0, -0.15, 0.0)")
	span = SourceEdit.find_value(text, ["M", "a", "x"])
	assert_eq(text.substr(span.x, span.y - span.x), "StrikeSegment.make(V3.make(1, 2, 3), V3.make(4, 5, 6), 0.015)", "nested calls")
	span = SourceEdit.find_value(text, ["M", "a", "y"])
	assert_eq(text.substr(span.x, span.y - span.x), "2", "the key after a call is still found")


func test_find_in_the_clip_manifest() -> void:
	var text: String = _read(CLIP_MANIFEST)
	var span: Vector2i = SourceEdit.find_value(text, ["clips", "Attack1H01_L", "loop"])
	assert_eq(text.substr(span.x, span.y - span.x), "false")


func test_find_a_missing_path_gives_minus_one_and_an_error() -> void:
	var text: String = _read(MOVE_CLIPS)
	var errors: Array[String] = _errors()
	var span: Vector2i = SourceEdit.find_value(text, ["katana", "moves", "k_nope", "speed"], errors)
	assert_eq(span, Vector2i(-1, -1))
	assert_eq(errors.size(), 1, "one error")
	assert_true(errors[0].contains("k_nope"), "it names the missing key: " + errors[0])
	errors.clear()
	span = SourceEdit.find_value(text, ["katana", "moves", "k_l1", "nope"], errors)
	assert_eq(span, Vector2i(-1, -1))
	assert_true(errors[0].contains("nope"), errors[0])
	errors.clear()
	span = SourceEdit.find_value(_read(KATANA), ["NOPE", "k_l1"], errors)
	assert_eq(span, Vector2i(-1, -1))
	assert_true(errors[0].contains("NOPE"), errors[0])


func test_find_without_an_errors_array_still_works() -> void:
	assert_eq(SourceEdit.find_value('{"a": 1}', ["b"]), Vector2i(-1, -1))


# --- replacing -------------------------------------------------------------


func test_replacing_speed_in_move_clips_changes_only_those_bytes() -> void:
	var text: String = _read(MOVE_CLIPS)
	var path: Array[String] = ["katana", "moves", "k_sh", "speed"]
	var span: Vector2i = SourceEdit.find_value(text, path)
	var errors: Array[String] = _errors()
	var edited: String = SourceEdit.replace_value(text, path, 2.5, errors)
	assert_eq(errors, [] as Array[String], "no errors")
	assert_ne(edited, text)
	var new_span: Vector2i = SourceEdit.find_value(edited, path)
	assert_eq(edited.substr(new_span.x, new_span.y - new_span.x), "2.5")
	assert_eq(new_span.x, span.x, "it starts where it did")
	assert_eq(_cut(edited, new_span.x, new_span.y), _cut(text, span.x, span.y), "every other byte is the same")


func test_numbers_are_written_the_way_jsformat_does() -> void:
	var text: String = '{"a": {"speed": 1.45}}'
	var out: String = SourceEdit.replace_value(text, ["a", "speed"], 2.0, _errors())
	assert_eq(out, '{"a": {"speed": 2}}', "a whole float prints without .0")
	out = SourceEdit.replace_value(text, ["a", "speed"], 0.1 + 0.2, _errors())
	assert_eq(out, '{"a": {"speed": %s}}' % JsFormat.num(0.1 + 0.2))
	out = SourceEdit.replace_value(text, ["a", "speed"], 12, _errors())
	assert_eq(out, '{"a": {"speed": 12}}', "an int")


func test_replacing_a_whole_object_value() -> void:
	var text: String = _read(MOVE_CLIPS)
	var path: Array[String] = ["katana", "moves", "k_sh", "marks"]
	var edited: String = SourceEdit.replace_value(text, path, {"windup": 9, "contact": 15.5}, _errors())
	var span: Vector2i = SourceEdit.find_value(edited, path)
	assert_eq(edited.substr(span.x, span.y - span.x), '{"windup": 9, "contact": 15.5}')
	var old: Vector2i = SourceEdit.find_value(text, path)
	assert_eq(_cut(edited, span.x, span.y), _cut(text, old.x, old.y))
	assert_not_null(JSON.parse_string(edited), "still valid JSON")


func test_replacing_clips_with_an_array() -> void:
	var text: String = _read(MOVE_CLIPS)
	var path: Array[String] = ["katana", "moves", "k_iai", "clips"]
	var edited: String = SourceEdit.replace_value(text, path, ["A@1-2", "B"], _errors())
	var span: Vector2i = SourceEdit.find_value(edited, path)
	assert_eq(edited.substr(span.x, span.y - span.x), '["A@1-2", "B"]')
	var parsed: Variant = JSON.parse_string(edited)
	assert_eq((parsed as Dictionary)["katana"]["moves"]["k_iai"]["clips"], ["A@1-2", "B"])


func test_replacing_damage_in_katana_gd_still_parses() -> void:
	# the move data's frames come from the frame-data table since milestone-1
	# task 17, so a design number stands in
	var text: String = _read(KATANA)
	var path: Array[String] = ["MOVES", "k_l1", "damage"]
	var span: Vector2i = SourceEdit.find_value(text, path)
	var edited: String = SourceEdit.replace_value(text, path, 9, _errors())
	var new_span: Vector2i = SourceEdit.find_value(edited, path)
	assert_eq(edited.substr(new_span.x, new_span.y - new_span.x), "9")
	assert_eq(_cut(edited, new_span.x, new_span.y), _cut(text, span.x, span.y), "only the damage changed")
	assert_true(_parses(edited), "the edited text still parses")


func test_a_gd_stringname_is_written_with_its_ampersand() -> void:
	var text: String = _read(KATANA)
	var path: Array[String] = ["MOVES", "k_l1", "chain_light"]
	var edited: String = SourceEdit.replace_value(text, path, &"k_l3", _errors())
	var span: Vector2i = SourceEdit.find_value(edited, path)
	assert_eq(edited.substr(span.x, span.y - span.x), '&"k_l3"')
	var json: String = SourceEdit.replace_value('{"a": {"b": 1}}', ["a", "b"], &"x", _errors())
	assert_eq(json, '{"a": {"b": "x"}}', "in JSON a StringName is a plain string")


func test_replacing_a_whole_call_value_inline() -> void:
	var text: String = 'const M: Dictionary = {\n\t"a": {"grip": V3.make(0.0, -0.15, 0.0), "x": 1},\n}\n'
	var edited: String = SourceEdit.replace_value(text, ["M", "a", "grip"], "gone", _errors())
	assert_eq(edited, 'const M: Dictionary = {\n\t"a": {"grip": "gone", "x": 1},\n}\n')


func test_a_key_under_a_call_value_is_refused() -> void:
	var text: String = 'const M: Dictionary = {\n\t"a": {"grip": V3.make(0.0, -0.15, 0.0), "x": 1},\n}\n'
	var errors: Array[String] = _errors()
	var out: String = SourceEdit.replace_value(text, ["M", "a", "grip", "y"], 1, errors)
	assert_eq(out, text, "the text is unchanged")
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("grip"), "the message names the call's key: " + errors[0])
	errors.clear()
	assert_eq(SourceEdit.find_value(text, ["M", "a", "grip", "y"], errors), Vector2i(-1, -1))
	assert_eq(errors.size(), 1, "find refuses too")
	errors.clear()
	assert_eq(SourceEdit.remove_key(text, ["M", "a", "grip", "y"], errors), text)
	assert_eq(errors.size(), 1, "remove refuses too")


func test_katana_calls_outside_the_const_are_not_reachable() -> void:
	# the blade and grip are built in build(), not held in MOVES
	var errors: Array[String] = _errors()
	assert_eq(SourceEdit.find_value(_read(KATANA), ["MOVES", "k_l1", "blade"], errors), Vector2i(-1, -1))
	assert_eq(errors.size(), 1)


func test_a_missing_path_on_replace_pushes_an_error_and_keeps_the_text() -> void:
	var text: String = _read(MOVE_CLIPS)
	var errors: Array[String] = _errors()
	var out: String = SourceEdit.replace_value(text, ["katana", "moves", "k_nope", "speed"], 1.0, errors)
	assert_eq(out, text)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("k_nope"), errors[0])


# --- adding and removing keys ----------------------------------------------


func test_adding_marks_to_a_move_that_has_none_and_removing_it_again_gives_the_original() -> void:
	var text: String = _read(MOVE_CLIPS)
	var path: Array[String] = ["katana", "moves", "k_l4", "marks"]
	assert_eq(SourceEdit.find_value(text, path), Vector2i(-1, -1), "k_l4 starts without marks")
	var errors: Array[String] = _errors()
	var added: String = SourceEdit.replace_value(text, path, {"windup": 8, "contact": 15}, errors)
	assert_eq(errors, [] as Array[String])
	var span: Vector2i = SourceEdit.find_value(added, path)
	assert_ne(span, Vector2i(-1, -1), "marks are there now")
	assert_true(added.contains('"dodge_cancel": 22}, "marks": {"windup": 8, "contact": 15}}'), "added on the same line, after the last entry (its markers)")
	assert_eq(added.count("\n"), text.count("\n"), "no line was added")
	assert_not_null(JSON.parse_string(added), "still valid JSON")
	var removed: String = SourceEdit.remove_key(added, path, errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(removed, text, "removing it gives the original bytes")


func test_adding_a_key_in_a_gd_dict_uses_its_style_and_round_trips() -> void:
	var text: String = _read(KATANA)
	var path: Array[String] = ["MOVES", "k_l1", "newkey"]
	var errors: Array[String] = _errors()
	var added: String = SourceEdit.replace_value(text, path, 3, errors)
	assert_eq(errors, [] as Array[String])
	assert_true(added.contains('"chain_heavy": &"k_h2", "newkey": 3,\n'), "string key, same line, trailing comma kept")
	assert_true(_parses(added), "still parses")
	assert_eq(SourceEdit.remove_key(added, path, errors), text, "round trip")


func test_adding_a_key_to_a_stringname_keyed_dict_uses_the_ampersand() -> void:
	var text: String = 'const M: Dictionary = {\n\t&"a": 1,\n\t&"b": 2,\n}\n'
	var out: String = SourceEdit.replace_value(text, ["M", "c"], 3, _errors())
	assert_eq(out, 'const M: Dictionary = {\n\t&"a": 1,\n\t&"b": 2, &"c": 3,\n}\n')


func test_adding_a_key_to_an_empty_dict() -> void:
	var out: String = SourceEdit.replace_value('{"a": {}}', ["a", "b"], 1, _errors())
	assert_eq(out, '{"a": {"b": 1}}')
	out = SourceEdit.replace_value('{"a": {\n}}', ["a", "b"], 1, _errors())
	assert_eq(out, '{"a": {"b": 1\n}}')


func test_removing_keys_in_each_position() -> void:
	var errors: Array[String] = _errors()
	# first on its line, more entries on later lines: the whole line goes
	var multi: String = '{\n\t"a": 1,\n\t"b": 2,\n\t"c": 3\n}'
	assert_eq(SourceEdit.remove_key(multi, ["a"], errors), '{\n\t"b": 2,\n\t"c": 3\n}')
	assert_eq(SourceEdit.remove_key(multi, ["b"], errors), '{\n\t"a": 1,\n\t"c": 3\n}')
	# the last one without a trailing comma: the comma before it goes too
	assert_eq(SourceEdit.remove_key(multi, ["c"], errors), '{\n\t"a": 1,\n\t"b": 2\n}')
	# several on one line
	var one: String = '{"a": 1, "b": 2, "c": 3}'
	assert_eq(SourceEdit.remove_key(one, ["a"], errors), '{"b": 2, "c": 3}')
	assert_eq(SourceEdit.remove_key(one, ["b"], errors), '{"a": 1, "c": 3}')
	assert_eq(SourceEdit.remove_key(one, ["c"], errors), '{"a": 1, "b": 2}')
	# the only one
	assert_eq(SourceEdit.remove_key('{"a": 1}', ["a"], errors), "{}")
	# with a trailing comma, as in the .gd files
	var gd: String = 'const M: Dictionary = {\n\t"a": 1, "b": 2,\n\t"c": 3,\n}\n'
	assert_eq(SourceEdit.remove_key(gd, ["M", "b"], errors), 'const M: Dictionary = {\n\t"a": 1,\n\t"c": 3,\n}\n')
	assert_eq(SourceEdit.remove_key(gd, ["M", "c"], errors), 'const M: Dictionary = {\n\t"a": 1, "b": 2,\n}\n')
	assert_eq(errors, [] as Array[String], "no errors along the way")
	for edited: String in [SourceEdit.remove_key(multi, ["a"], errors), SourceEdit.remove_key(multi, ["c"], errors), SourceEdit.remove_key(one, ["b"], errors)]:
		assert_not_null(JSON.parse_string(edited), "valid JSON: " + edited)


func test_removing_a_missing_key_pushes_an_error_and_keeps_the_text() -> void:
	var errors: Array[String] = _errors()
	var text: String = '{"a": {"b": 1}}'
	assert_eq(SourceEdit.remove_key(text, ["a", "zzz"], errors), text)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("zzz"), errors[0])


func test_removing_a_whole_move_from_move_clips() -> void:
	var text: String = _read(MOVE_CLIPS)
	var errors: Array[String] = _errors()
	var removed: String = SourceEdit.remove_key(text, ["katana", "moves", "k_l2"], errors)
	assert_eq(errors, [] as Array[String])
	assert_false(removed.contains('"k_l2": {'), "k_l2 is gone (k_l1's branch point still names it)")
	assert_eq(removed.count("\n"), text.count("\n") - 1, "exactly its line went")
	assert_not_null(JSON.parse_string(removed), "still valid JSON")


# --- awkward text ----------------------------------------------------------


func test_strings_holding_braces_quotes_and_hashes_dont_fool_the_matcher() -> void:
	var text: String = '{"a": {"note": "has } and \\" and # and { inside", "n": 1}, "b": {"n": 2}}'
	var span: Vector2i = SourceEdit.find_value(text, ["a", "n"])
	assert_eq(text.substr(span.x, span.y - span.x), "1")
	span = SourceEdit.find_value(text, ["b", "n"])
	assert_eq(text.substr(span.x, span.y - span.x), "2")
	span = SourceEdit.find_value(text, ["a", "note"])
	assert_eq(text.substr(span.x, span.y - span.x), '"has } and \\" and # and { inside"')
	var out: String = SourceEdit.replace_value(text, ["b", "n"], 3, _errors())
	assert_eq(out, text.replace('"n": 2', '"n": 3'))
	assert_not_null(JSON.parse_string(out))


func test_a_key_that_looks_like_another_inside_a_string_is_not_matched() -> void:
	var text: String = '{"a": {"note": "\\"n\\": 5", "n": 1}}'
	var span: Vector2i = SourceEdit.find_value(text, ["a", "n"])
	assert_eq(text.substr(span.x, span.y - span.x), "1")


func test_gd_comments_with_quotes_and_brackets_are_skipped() -> void:
	var text: String = 'const M: Dictionary = {\n\t# the fighter\'s "charge" { check (\n\t&"a": {"n": 1},\n\t&"b": {"n": 2},\n}\n'
	var span: Vector2i = SourceEdit.find_value(text, ["M", "b", "n"])
	assert_eq(text.substr(span.x, span.y - span.x), "2")
	assert_true(_parses(SourceEdit.replace_value(text, ["M", "b", "n"], 7, _errors())))


func test_the_const_is_found_among_other_declarations() -> void:
	var text: String = 'class_name X\nconst A: int = 1\nconst B := {"k": [1, 2]}\nconst C: Dictionary = {"k": "const A = {"}\n'
	var span: Vector2i = SourceEdit.find_value(text, ["B", "k"])
	assert_eq(text.substr(span.x, span.y - span.x), "[1, 2]")
	span = SourceEdit.find_value(text, ["C", "k"])
	assert_eq(text.substr(span.x, span.y - span.x), '"const A = {"')
	span = SourceEdit.find_value(text, ["A"])
	assert_eq(text.substr(span.x, span.y - span.x), "1", "a whole const's value")


func test_a_value_that_is_an_expression_is_refused() -> void:
	var text: String = 'const M: Dictionary = {"a": 1 + 2, "b": 3}\n'
	var errors: Array[String] = _errors()
	var out: String = SourceEdit.replace_value(text, ["M", "b"], 4, errors)
	assert_eq(out, text, "a dictionary it can't read safely is left alone")
	assert_eq(errors.size(), 1)


func test_an_unterminated_text_gives_an_error_not_a_crash() -> void:
	var errors: Array[String] = _errors()
	assert_eq(SourceEdit.find_value('{"a": {"b": "oops', ["a", "b"], errors), Vector2i(-1, -1))
	assert_eq(errors.size(), 1)
	errors.clear()
	assert_eq(SourceEdit.find_value('{"a": {"b": 1', ["a", "b"], errors), Vector2i(-1, -1))
	errors.clear()
	assert_eq(SourceEdit.find_value("", ["a"], errors), Vector2i(-1, -1))
	assert_eq(errors.size(), 1)


func test_replacing_a_value_that_wraps_across_lines() -> void:
	var text: String = '{"m": {\n\t"a": {"clips": ["x",\n\t\t"y"],\n\t\t"speed": 1},\n\t"b": {"speed": 2}\n}}'
	var out: String = SourceEdit.replace_value(text, ["m", "a", "clips"], ["z"], _errors())
	assert_eq(out, '{"m": {\n\t"a": {"clips": ["z"],\n\t\t"speed": 1},\n\t"b": {"speed": 2}\n}}')
	out = SourceEdit.replace_value(text, ["m", "a", "speed"], 5, _errors())
	assert_eq(out, text.replace('"speed": 1', '"speed": 5'))


func test_a_load_with_no_edit_is_identical_bytes() -> void:
	var text: String = _read(MOVE_CLIPS)
	var path: Array[String] = ["katana", "moves", "k_sh", "speed"]
	var span: Vector2i = SourceEdit.find_value(text, path)
	var same: String = SourceEdit.replace_value(text, path, text.substr(span.x, span.y - span.x).to_float(), _errors())
	assert_eq(same, text, "writing the value it already has changes nothing")


# --- literals --------------------------------------------------------------


func test_literals() -> void:
	assert_eq(SourceEdit.literal(1.45, &"json"), "1.45")
	assert_eq(SourceEdit.literal(2.0, &"gd"), "2")
	assert_eq(SourceEdit.literal(-0.5, &"json"), "-0.5")
	assert_eq(SourceEdit.literal(7, &"json"), "7")
	assert_eq(SourceEdit.literal(true, &"json"), "true")
	assert_eq(SourceEdit.literal(false, &"gd"), "false")
	assert_eq(SourceEdit.literal(null, &"json"), "null")
	assert_eq(SourceEdit.literal("Sword", &"json"), '"Sword"')
	assert_eq(SourceEdit.literal("Sword", &"gd"), '"Sword"')
	assert_eq(SourceEdit.literal(&"k_l1", &"gd"), '&"k_l1"')
	assert_eq(SourceEdit.literal(&"k_l1", &"json"), '"k_l1"')
	assert_eq(SourceEdit.literal(["a", "b"], &"json"), '["a", "b"]')
	assert_eq(SourceEdit.literal([8, 9.5], &"gd"), "[8, 9.5]")
	assert_eq(SourceEdit.literal([], &"json"), "[]")
	assert_eq(SourceEdit.literal({"windup": 8, "contact": 15}, &"json"), '{"windup": 8, "contact": 15}')
	assert_eq(SourceEdit.literal({}, &"gd"), "{}")
	assert_eq(SourceEdit.literal({"a": ["x", {"b": 1}]}, &"json"), '{"a": ["x", {"b": 1}]}')


func test_literal_strings_are_escaped() -> void:
	var tricky: String = 'a "quote", a \\ slash,\na newline and a tab\t'
	var json: String = SourceEdit.literal(tricky, &"json")
	assert_eq(json, '"a \\"quote\\", a \\\\ slash,\\na newline and a tab\\t"')
	assert_eq(JSON.parse_string(json), tricky, "reads back as the same string")
	var gd: String = SourceEdit.literal(tricky, &"gd")
	var expr: Expression = Expression.new()
	assert_eq(expr.parse(gd), OK)
	assert_eq(expr.execute(), tricky, "GDScript reads it back too")


func test_a_string_value_with_awkward_characters_survives_a_replace() -> void:
	var text: String = '{"a": {"note": "x", "n": 1}}'
	var tricky: String = 'brace } and quote " and # hash'
	var out: String = SourceEdit.replace_value(text, ["a", "note"], tricky, _errors())
	assert_eq((JSON.parse_string(out) as Dictionary)["a"]["note"], tricky)
	var span: Vector2i = SourceEdit.find_value(out, ["a", "n"])
	assert_eq(out.substr(span.x, span.y - span.x), "1", "the next key is still found")


func test_the_untouched_katana_passes_the_parse_check() -> void:
	assert_true(_parses(_read(KATANA)), "the untouched katana.gd parses")


func test_every_real_move_is_found_where_the_game_reads_it() -> void:
	var gd: String = _read(KATANA)
	for move: StringName in KatanaMoves.MOVES:
		for field: String in ["damage", "posture", "knockback"]:
			var span: Vector2i = SourceEdit.find_value(gd, ["MOVES", String(move), field])
			assert_ne(span, Vector2i(-1, -1), "%s.%s is found" % [move, field])
			assert_eq(gd.substr(span.x, span.y - span.x), str(KatanaMoves.MOVES[move][field]), "%s.%s" % [move, field])
	var json: String = _read(MOVE_CLIPS)
	var data: Dictionary = JSON.parse_string(json)
	for weapon: String in ["katana", "greatsword", "daggers"]:
		for move: String in (data[weapon]["moves"] as Dictionary):
			if not (data[weapon]["moves"][move] as Dictionary).has("speed"):
				continue # re-keyed: it plays at 1.0x and names no speed
			var path: Array[String] = [weapon, "moves", move, "speed"]
			var span: Vector2i = SourceEdit.find_value(json, path)
			assert_eq(JsFormat.number(json.substr(span.x, span.y - span.x)), float(data[weapon]["moves"][move]["speed"]), "%s speed" % move)
			# a hand-written 1.0 or 2.0 is printed as 1 or 2 (JsFormat.num), so
			# the rewrite may change that span, and nothing else
			var speed: float = float(data[weapon]["moves"][move]["speed"])
			var out: String = SourceEdit.replace_value(json, path, speed, _errors())
			assert_eq(_cut(out, span.x, span.x + JsFormat.num(speed).length()), _cut(json, span.x, span.y), "%s: only its speed may change" % move)
