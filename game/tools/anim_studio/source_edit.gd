class_name SourceEdit
extends RefCounted
## Changes one value in a hand-formatted JSON file or GDScript dictionary
## literal and leaves every other byte alone. Every save in the Animation
## Studio goes through it, so the data files keep their hand formatting (one
## move per line, tabs, comments).
##
## A value is addressed by a key path. In JSON the first element is a key of the
## root object (["katana", "moves", "k_l1", "speed"]); in a .gd file it names a
## top-level `const` (["MOVES", "k_l1", "startup"]). A key is a "string", a
## &"StringName" or a bare name, and matches the path element either way.
##
## The scanner knows strings ("..." and '...' with escapes), `#` comments and
## the brackets {} [] (), so a `}` or a `"` inside a string or a comment never
## ends a value early. A value is one token or one bracketed group, with calls
## such as V3.make(...) kept whole.
##
## Every function that can fail takes the caller's `errors` and pushes a
## human-readable message into it; the text comes back unchanged (and a failed
## find gives Vector2i(-1, -1)). Tools only: the rules never read these files as
## text.


## The `[start, end)` span of the value at `path`, or Vector2i(-1, -1) when it
## isn't there (with the reason pushed into `errors`).
static func find_value(text: String, path: Array[String], errors: Array[String] = []) -> Vector2i:
	var found: Dictionary = _locate(text, path)
	if found.has("error"):
		errors.append(found["error"])
		return Vector2i(-1, -1)
	if not found.has("start"):
		errors.append(_missing_message(path))
		return Vector2i(-1, -1)
	return Vector2i(found["start"], found["end"])


## `text` with the value at `path` replaced by `literal(value, flavour)`, the
## flavour read from the text. A last key that isn't there is added after the
## last entry of its dictionary, on the same line (`, "key": value`), keyed in
## the style of the entries already there. On a failure the text comes back
## unchanged and the reason is pushed into `errors`.
static func replace_value(text: String, path: Array[String], value: Variant, errors: Array[String]) -> String:
	var found: Dictionary = _locate(text, path)
	if found.has("error"):
		errors.append(found["error"])
		return text
	var flavour: StringName = _flavour(text)
	if found.has("start"):
		return text.substr(0, found["start"]) + literal(value, flavour) + text.substr(found["end"])
	if not found.has("parent"):
		errors.append(_missing_message(path))
		return text
	return _add_key(text, found["parent"], path[path.size() - 1], literal(value, flavour))


## `text` without the key at `path` (and its value). The comma and the line
## that carried it go too, so the entries around it keep their layout.
static func remove_key(text: String, path: Array[String], errors: Array[String]) -> String:
	var found: Dictionary = _locate(text, path)
	if found.has("error"):
		errors.append(found["error"])
		return text
	if not found.has("start"):
		errors.append(_missing_message(path))
		return text
	if int(found["parent"]["close"]) < 0:
		errors.append("SourceEdit: %s is a whole const; removing it isn't supported" % path[0])
		return text
	var entries: Array = found["parent"]["entries"]
	var at: int = found["index"]
	var entry: Dictionary = entries[at]
	var key_start: int = entry["key_start"]
	var value_end: int = entry["value_end"]
	var prev_end: int = -1 if at == 0 else int(entries[at - 1]["value_end"])
	var next_start: int = -1 if at == entries.size() - 1 else int(entries[at + 1]["key_start"])
	# on the same line as the entry before it, or the last entry: the comma
	# before it goes with it
	if prev_end >= 0 and (next_start < 0 or not text.substr(prev_end, key_start - prev_end).contains("\n")):
		return _cut(text, prev_end, value_end)
	if next_start < 0:
		return _cut(text, key_start, _after_comma(text, value_end))
	var line_start: int = text.rfind("\n", key_start - 1) + 1
	var rest_end: int = _after_comma(text, value_end)
	var line_end: int = text.find("\n", rest_end)
	if _is_blank(text.substr(line_start, key_start - line_start)) and line_end >= 0 \
			and _is_blank(text.substr(rest_end, line_end - rest_end)):
		return _cut(text, line_start, line_end + 1)
	if not text.substr(value_end, next_start - value_end).contains("\n"):
		return _cut(text, key_start, next_start)
	return _cut(text, key_start, rest_end)


## The source text of `value`: numbers as JsFormat.num prints them, strings
## quoted, a StringName as &"x" in `&"gd"` (a plain string in `&"json"`), arrays
## and dictionaries on one line (`["a", "b"]`, `{"windup": 8, "contact": 15}`).
static func literal(value: Variant, flavour: StringName) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return JsFormat.num(value)
		TYPE_STRING:
			return _quote(value)
		TYPE_STRING_NAME:
			return ("&" if flavour == &"gd" else "") + _quote(String(value))
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item: Variant in value:
				parts.append(literal(item, flavour))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			var entries: Array[String] = []
			for key: Variant in value:
				entries.append("%s: %s" % [literal(key, flavour), literal(value[key], flavour)])
			return "{" + ", ".join(entries) + "}"
	push_error("SourceEdit.literal: no literal for %s" % type_string(typeof(value)))
	return "null"


# --- locating -----------------------------------------------------------------


## Where the path leads. The result holds "error" (a message) when the text can't
## be read or the path runs through something that isn't a dictionary literal;
## otherwise "start", "end" and "index" (the entry's place among its siblings)
## and "parent" (that dictionary's _entries) when the value is there, and only
## "parent" when just the last key is absent.
static func _locate(text: String, path: Array[String]) -> Dictionary:
	if path.is_empty():
		return {"error": "SourceEdit: an empty key path"}
	var n: int = text.length()
	var at: int = 1 if text.begins_with("﻿") else 0
	at = _skip_trivia(text, at)
	var keys: Array[String] = path
	var walked: String = ""
	var container: int
	if at < n and text[at] == "{":
		container = at
	elif at < n and text[at] == "[":
		return {"error": "SourceEdit: the text is a JSON array, which has no keys to follow"}
	else:
		var start: int = _find_const(text, path[0])
		if start < 0:
			return {"error": "SourceEdit: no const %s in the text" % path[0]}
		if start == n or _value_end(text, start) <= start:
			return {"error": "SourceEdit: const %s has no value" % path[0]}
		walked = path[0]
		keys = path.slice(1)
		if keys.is_empty():
			var end: int = _value_end(text, start)
			if end < 0:
				return {"error": "SourceEdit: const %s is unterminated" % path[0]}
			return {"start": start, "end": end, "index": 0, "parent": {"entries": [], "open": -1, "close": -1}}
		container = start
	for i: int in keys.size():
		if text[container] != "{":
			return {"error": "SourceEdit: %s is %s, not a dictionary literal; its keys can't be edited (replace the whole value instead)" % [walked, _describe(text, container)]}
		var parsed: Dictionary = _entries(text, container)
		if parsed.has("error"):
			return {"error": parsed["error"]}
		var index: int = -1
		for j: int in (parsed["entries"] as Array).size():
			if parsed["entries"][j]["key"] == keys[i]:
				index = j
				break
		walked += ("." if walked != "" else "") + keys[i]
		if index < 0:
			if i == keys.size() - 1:
				return {"parent": parsed}
			return {"error": _missing_message(path.slice(0, path.size() - keys.size() + i + 1))}
		var entry: Dictionary = parsed["entries"][index]
		if i == keys.size() - 1:
			return {"start": entry["value_start"], "end": entry["value_end"], "index": index, "parent": parsed}
		container = entry["value_start"]
	return {"error": "SourceEdit: could not follow " + ".".join(path)}


## The entries of the dictionary literal whose `{` is at `open`: {"entries": an
## array of {key, key_start, key_end, value_start, value_end}, "open" and "close": the
## indexes of the `{` and the `}`}, or {"error": a message}.
static func _entries(text: String, open: int) -> Dictionary:
	var n: int = text.length()
	var entries: Array[Dictionary] = []
	var at: int = open + 1
	while true:
		at = _skip_trivia(text, at)
		if at >= n:
			return {"error": "SourceEdit: the dictionary opened at offset %d is never closed" % open}
		if text[at] == "}":
			return {"entries": entries, "open": open, "close": at}
		var key_end: int = _value_end(text, at)
		if key_end <= at:
			return {"error": "SourceEdit: expected a key at offset %d, found %s" % [at, _snippet(text, at)]}
		var key: String = _decode_key(text.substr(at, key_end - at))
		var colon: int = _skip_trivia(text, key_end)
		if colon >= n or (text[colon] != ":" and text[colon] != "="):
			return {"error": "SourceEdit: expected ':' after the key %s at offset %d" % [key, key_end]}
		var value_start: int = _skip_trivia(text, colon + 1)
		var value_end: int = _value_end(text, value_start)
		if value_end <= value_start:
			return {"error": "SourceEdit: the key %s has no readable value at offset %d (unterminated string or bracket?)" % [key, value_start]}
		var next: int = _skip_trivia(text, value_end)
		if next >= n or (text[next] != "," and text[next] != "}"):
			return {"error": "SourceEdit: the value of %s (%s) isn't one literal or call, so it can't be edited safely" % [key, _snippet(text, value_start)]}
		entries.append({"key": key, "key_start": at, "key_end": key_end, "value_start": value_start, "value_end": value_end})
		at = next + 1 if text[next] == "," else next
	return {}


## The start of the value of the top-level `const <name>`, or -1.
static func _find_const(text: String, name: String) -> int:
	var n: int = text.length()
	var at: int = 0
	var depth: int = 0
	while at < n:
		var c: String = text[at]
		if c == "#":
			at = _skip_trivia(text, at)
		elif c == '"' or c == "'":
			at = _skip_string(text, at)
			if at < 0:
				return -1
		elif c == "{" or c == "[" or c == "(":
			depth += 1
			at += 1
		elif c == "}" or c == "]" or c == ")":
			depth -= 1
			at += 1
		elif depth == 0 and _is_ident_start(c) and (at == 0 or not _is_ident_char(text[at - 1])):
			var word_end: int = at
			while word_end < n and _is_ident_char(text[word_end]):
				word_end += 1
			if text.substr(at, word_end - at) == "const":
				var name_start: int = _skip_trivia(text, word_end)
				var name_end: int = name_start
				while name_end < n and _is_ident_char(text[name_end]):
					name_end += 1
				if name_end > name_start and text.substr(name_start, name_end - name_start) == name:
					return _after_equals(text, name_end)
			at = word_end
		else:
			at += 1
	return -1


## The start of the value after the `=` that follows a const's name (past any
## `: Type`), or -1.
static func _after_equals(text: String, from: int) -> int:
	var n: int = text.length()
	var at: int = from
	while at < n:
		var c: String = text[at]
		if c == "=":
			return _skip_trivia(text, at + 1)
		if c == "[" or c == "(":
			at = _match(text, at)
			if at < 0:
				return -1
		elif c == "\n":
			return -1
		else:
			at += 1
	return -1


# --- scanning -----------------------------------------------------------------


## The index of the first character at or after `at` that isn't whitespace or
## part of a `#` comment.
static func _skip_trivia(text: String, at: int) -> int:
	var n: int = text.length()
	while at < n:
		var c: String = text[at]
		if c == "#":
			var line_end: int = text.find("\n", at)
			at = n if line_end < 0 else line_end + 1
		elif c == " " or c == "\t" or c == "\n" or c == "\r":
			at += 1
		else:
			break
	return at


## The index after the string that opens at `at`, or -1 if it never closes.
static func _skip_string(text: String, at: int) -> int:
	var quote: String = text[at]
	var n: int = text.length()
	var i: int = at + 1
	while i < n:
		var c: String = text[i]
		if c == "\\":
			i += 2
		elif c == quote:
			return i + 1
		else:
			i += 1
	return -1


## The index after the bracket that closes the one at `at` ({} [] and () count
## together), or -1 if it never closes.
static func _match(text: String, at: int) -> int:
	var n: int = text.length()
	var depth: int = 0
	var i: int = at
	while i < n:
		var c: String = text[i]
		if c == '"' or c == "'":
			i = _skip_string(text, i)
			if i < 0:
				return -1
			continue
		if c == "#":
			i = _skip_trivia(text, i)
			continue
		if c == "{" or c == "[" or c == "(":
			depth += 1
		elif c == "}" or c == "]" or c == ")":
			depth -= 1
			if depth == 0:
				return i + 1
		i += 1
	return -1


## The index after the one-token value (or key) that starts at `at`: a string,
## a bracketed group, a bare word or number, or a call with its arguments. A
## token ends at a comma, a closing bracket, a colon or equals sign, a comment
## or whitespace. At or below `at` (equal) means nothing readable is there, and
## -1 an unterminated string or bracket.
static func _value_end(text: String, at: int) -> int:
	var n: int = text.length()
	var i: int = at
	while i < n:
		var c: String = text[i]
		if c == '"' or c == "'":
			i = _skip_string(text, i)
			if i < 0:
				return -1
		elif c == "{" or c == "[" or c == "(":
			i = _match(text, i)
			if i < 0:
				return -1
		elif ",}]):=# \t\r\n".contains(c):
			break
		else:
			i += 1
	return i


## The key text `raw` as a path element: a quoted string unescaped, with a
## leading & (StringName) or ^ (NodePath) dropped; a bare word as written.
static func _decode_key(raw: String) -> String:
	var s: String = raw
	if s.begins_with("&") or s.begins_with("^"):
		s = s.substr(1)
	if s.length() >= 2 and (s[0] == '"' or s[0] == "'"):
		s = s.substr(1, s.length() - 2)
		var out: String = ""
		var i: int = 0
		while i < s.length():
			if s[i] == "\\" and i + 1 < s.length():
				i += 1
				match s[i]:
					"n":
						out += "\n"
					"t":
						out += "\t"
					"r":
						out += "\r"
					_:
						out += s[i]
			else:
				out += s[i]
			i += 1
		return out
	return s


# --- editing ------------------------------------------------------------------


## `text` with `key: literal` added to the dictionary `parent` (_entries), after
## its last entry's value on the same line and keyed like the entries there.
static func _add_key(text: String, parent: Dictionary, key: String, value_literal: String) -> String:
	var entries: Array = parent["entries"]
	if entries.is_empty():
		var open: int = parent["open"]
		return text.substr(0, open + 1) + _quote(key) + ": " + value_literal + text.substr(open + 1)
	var last: Dictionary = entries[entries.size() - 1]
	var raw_key: String = text.substr(last["key_start"], last["key_end"] - last["key_start"])
	var key_literal: String = ("&" if raw_key.begins_with("&") else "") + _quote(key)
	var separator: String = text.substr(last["key_end"], last["value_start"] - last["key_end"])
	if separator.contains("\n") or separator.contains("#") or not separator.contains(":"):
		separator = ": "
	var at: int = last["value_end"]
	return text.substr(0, at) + ", " + key_literal + separator + value_literal + text.substr(at)


## `text` without [start, end).
static func _cut(text: String, start: int, end: int) -> String:
	return text.substr(0, start) + text.substr(end)


## The index after the comma that follows the value ending at `at` (and the
## spaces and tabs after it), or `at` when there is none.
static func _after_comma(text: String, at: int) -> int:
	var i: int = at
	while i < text.length() and (text[i] == " " or text[i] == "\t"):
		i += 1
	if i < text.length() and text[i] == ",":
		i += 1
		while i < text.length() and (text[i] == " " or text[i] == "\t"):
			i += 1
		return i
	return at


static func _is_blank(s: String) -> bool:
	return s.strip_edges(true, true) == ""


# --- small helpers --------------------------------------------------------------


## &"json" when the text is a JSON object, else &"gd".
static func _flavour(text: String) -> StringName:
	var at: int = _skip_trivia(text, 1 if text.begins_with("﻿") else 0)
	return &"json" if at < text.length() and (text[at] == "{" or text[at] == "[") else &"gd"


static func _quote(s: String) -> String:
	var out: String = '"'
	for c: String in s:
		match c:
			'"':
				out += '\\"'
			"\\":
				out += "\\\\"
			"\n":
				out += "\\n"
			"\t":
				out += "\\t"
			"\r":
				out += "\\r"
			_:
				out += c
	return out + '"'


static func _is_ident_start(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func _is_ident_char(c: String) -> bool:
	return _is_ident_start(c) or (c >= "0" and c <= "9")


static func _missing_message(path: Array[String]) -> String:
	return "SourceEdit: %s isn't in the text" % ".".join(path)


## A short look at the text at `at`, for a message.
static func _snippet(text: String, at: int) -> String:
	var snippet: String = text.substr(at, 24).replace("\n", " ").replace("\t", " ")
	return '"%s"' % snippet


## What the value at `at` is, for the message that refuses to look inside it.
static func _describe(text: String, at: int) -> String:
	var c: String = text[at]
	if c == "[":
		return "an array"
	if c == '"' or c == "'":
		return "a string"
	var end: int = _value_end(text, at)
	var token: String = text.substr(at, (end if end > at else at + 24) - at)
	return "a call (%s)" % token.left(40) if token.contains("(") else "a value (%s)" % token.left(40)
