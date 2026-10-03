class_name JsFormat
extends RefCounted
## Prints numbers and small objects exactly as the TypeScript tools do under
## Node, so the ported tools (soak.gd, counterlab.gd) print their reports as
## scripts/soak.ts and scripts/counterlab.ts do. The reports matched line for
## line up to the last bit-exact commit, 4222167 (plan task 8.2).
## Tools only: the rules never format text.


## Number.prototype.toFixed(digits) for digits 0..3: the exact decimal value
## of x rounded half up (JS picks the larger n on a tie), not printf's
## rounding of the binary value. Exact for finite |x| < 2^53; NaN and
## |x| >= 1e21 print as String(x), as in JS.
static func to_fixed(x: float, digits: int) -> String:
	if digits < 0 or digits > 3:
		push_error("JsFormat.to_fixed: digits must be 0 to 3, got %d" % digits)
		return ""
	if is_nan(x):
		return "NaN"
	if absf(x) >= 1e21:
		return num(x)
	var neg: bool = x < 0.0
	if neg:
		x = -x
	var scale: int = 1
	for _i: int in digits:
		scale *= 10
	# x = mant * 2^e exactly
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, x)
	var bits: int = bytes.decode_s64(0)
	var exp_bits: int = (bits >> 52) & 0x7FF
	var mant: int = bits & ((1 << 52) - 1)
	var e: int = -1074
	if exp_bits != 0:
		mant |= 1 << 52
		e = exp_bits - 1075
	# n = x * scale rounded half up; mant * scale < 2^63 for digits <= 3
	var n: int = 0
	if e >= 0:
		n = (mant << e) * scale
	else:
		var sh: int = -e
		var prod: int = mant * scale
		if sh <= 62:
			var rest: int = prod & ((1 << sh) - 1)
			n = (prod >> sh) + (1 if rest >= 1 << (sh - 1) else 0)
		elif sh == 63:
			n = 1 if prod >= 1 << 62 else 0
		# else: prod < 2^63 <= half of 2^sh, so n = 0
	@warning_ignore("integer_division")
	var s: String = str(n / scale)
	if digits > 0:
		s += "." + str(n % scale).lpad(digits, "0")
	return ("-" if neg else "") + s


## String(x) for a number (Number::toString): the shortest digits that read
## back as x, laid out the JS way (fixed notation for exponents -7 to 20,
## otherwise "1.5e+21", "1e-7"). The digits come from String.num_scientific,
## Godot's shortest round-trip form. (var_to_str gives a double that a float32
## holds exactly float32's shortest digits, too few to read back as x.)
static func num(x: float) -> String:
	if is_nan(x):
		return "NaN"
	if x == 0.0:
		return "0"
	if is_inf(x):
		return "Infinity" if x > 0.0 else "-Infinity"
	if x < 0.0:
		return "-" + num(-x)
	# x = 0.<digits> * 10^point, digits without leading or trailing zeros
	var digits: String
	var point: int
	if x == floorf(x) and x < 9007199254740992.0:
		digits = str(int(x))
		point = digits.length()
	else:
		var text: String = String.num_scientific(x)
		var exponent: int = 0
		var at: int = text.find("e")
		if at >= 0:
			exponent = text.substr(at + 1).to_int()
			text = text.substr(0, at)
		var dot: int = text.find(".")
		var whole: String = text if dot < 0 else text.substr(0, dot)
		var frac: String = "" if dot < 0 else text.substr(dot + 1)
		digits = whole + frac
		point = whole.length() + exponent
		while digits.begins_with("0"):
			digits = digits.substr(1)
			point -= 1
	while digits.ends_with("0"):
		digits = digits.substr(0, digits.length() - 1)
	var k: int = digits.length()
	if k <= point and point <= 21:
		return digits + "0".repeat(point - k)
	if 0 < point and point <= 21:
		return digits.substr(0, point) + "." + digits.substr(point)
	if -6 < point and point <= 0:
		return "0." + "0".repeat(-point) + digits
	var e: int = point - 1
	var m: String = digits.substr(0, 1) + ("." + digits.substr(1) if k > 1 else "")
	return m + "e" + ("+" if e >= 0 else "-") + str(absi(e))


## JS StrWhiteSpaceChar: WhiteSpace and LineTerminator.
const _JS_SPACE: String = "\t\n\u000B\u000C\r                  　﻿"


## Number(s) for a string (StringToNumber): surrounding JS whitespace is
## ignored; "" is 0; a decimal literal with optional sign, fraction and
## exponent, "Infinity" with optional sign, or an unsigned 0x, 0o or 0b
## integer; anything else is NaN. Decimal literals are read with Godot's
## to_float, which can be one unit in the last place off for more than 17
## significant digits; hex, octal and binary literals beyond 2^53 likewise.
static func number(s: String) -> float:
	var a: int = 0
	var b: int = s.length()
	while a < b and _JS_SPACE.contains(s[a]):
		a += 1
	while b > a and _JS_SPACE.contains(s[b - 1]):
		b -= 1
	var t: String = s.substr(a, b - a)
	if t == "":
		return 0.0
	if t.length() > 2 and t[0] == "0" and "xXoObB".contains(t[1]):
		var base: int = {"x": 16, "o": 8, "b": 2}[t[1].to_lower()]
		var v: float = 0.0
		for c: String in t.substr(2):
			var d: int = "0123456789abcdef".find(c.to_lower())
			if d < 0 or d >= base:
				return NAN
			v = v * float(base) + float(d)
		return v
	var sign: float = 1.0
	if t[0] == "+" or t[0] == "-":
		sign = -1.0 if t[0] == "-" else 1.0
		t = t.substr(1)
	if t == "Infinity":
		return sign * INF
	if RegEx.create_from_string("^(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$").search(t) == null:
		return NAN
	return sign * t.to_float()


## console.log of a flat object (util.inspect): keys in insertion order,
## quoted unless they match Node's /^[a-zA-Z_][a-zA-Z_0-9]*$/, ints and arrays of ints as values. The
## object stays on one line when it fits Node's 80-column break length.
static func inspect(obj: Dictionary) -> String:
	if obj.is_empty():
		return "{}"
	var ident: RegEx = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	var entries: Array[String] = []
	for k: Variant in obj:
		var key: String = String(k)
		if ident.search(key) == null:
			key = "'" + key + "'"
		entries.append("%s: %s" % [key, _value(obj[k])])
	# util.inspect's reduceToSingleString / isBelowBreakLength
	var n: int = entries.size()
	var start: int = n + 1 + 10
	var total: int = n + start
	var single: bool = total + n <= 80
	if single:
		for s: String in entries:
			total += s.length()
			if total > 80:
				single = false
				break
	if single:
		return "{ " + ", ".join(entries) + " }"
	return "{\n  " + ",\n  ".join(entries) + "\n}"


static func _value(v: Variant) -> String:
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return "[]"
		var parts: Array[String] = []
		for x: Variant in a:
			parts.append(_value(x))
		return "[ " + ", ".join(parts) + " ]"
	if v is float:
		return num(v)
	return str(v)
