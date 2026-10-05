class_name PadStyle
extends RefCounted
## Which button names a controller gets: PlayStation, Xbox or generic. Port of
## styleOf() in v0.1-web-mvp:src/input/devices.ts, using Godot's joypad name and info
## (vendor ids 0x054C Sony and 0x045E Microsoft).

const GENERIC: int = 0
const PLAYSTATION: int = 1
const XBOX: int = 2

const SONY_VENDOR: int = 0x054C
const MICROSOFT_VENDOR: int = 0x045E

const XBOX_WORDS: Array[String] = ["xbox", "xinput", "045e"]
const PLAYSTATION_WORDS: Array[String] = [
	"054c", "dualsense", "dualshock", "wireless controller", "playstation", "ps3", "ps4", "ps5", "qanba",
]


## joy_name: Input.get_joy_name(); joy_info: Input.get_joy_info().
static func detect(joy_name: String, joy_info: Dictionary = {}) -> int:
	var vendor: int = vendor_id(joy_info)
	if vendor == MICROSOFT_VENDOR:
		return XBOX
	if vendor == SONY_VENDOR:
		return PLAYSTATION
	var text: String = (joy_name + " " + str(joy_info.get("raw_name", ""))).to_lower()
	# Xbox first: "Xbox Wireless Controller" would otherwise match the
	# PlayStation pad's generic "Wireless Controller" name
	for word: String in XBOX_WORDS:
		if text.contains(word):
			return XBOX
	for word: String in PLAYSTATION_WORDS:
		if text.contains(word):
			return PLAYSTATION
	return GENERIC


## The vendor id from joypad info, which may hold it as an int, a decimal
## string or a "0x" hex string. -1 when missing.
static func vendor_id(joy_info: Dictionary) -> int:
	var v: Variant = joy_info.get("vendor_id", null)
	if v is int:
		return v
	if v is float:
		return int(v)
	if v is String:
		var s: String = (v as String).strip_edges().to_lower()
		if s.begins_with("0x") and s.substr(2).is_valid_hex_number():
			return s.substr(2).hex_to_int()
		if s.is_valid_int():
			return s.to_int()
	return -1


## "PlayStation", "Xbox" or "generic", for the Controls screen status line.
static func display_name(style: int) -> String:
	match style:
		PLAYSTATION:
			return "PlayStation"
		XBOX:
			return "Xbox"
	return "generic"
