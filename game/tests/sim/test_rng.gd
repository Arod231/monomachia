extends GutTest
## Checks the Mulberry32 port bit for bit against the TypeScript Rng
## (game/tests/fixtures/rng.json, written by scripts/sim-fixtures.ts).

var _fx: Dictionary


func before_all() -> void:
	_fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rng.json"))


## A double from its IEEE-754 bits written as 16 hex digits (big-endian).
static func _from_bits(hex: String) -> float:
	var b: PackedByteArray = PackedByteArray()
	b.resize(8)
	b.encode_u32(0, hex.substr(8, 8).hex_to_int())
	b.encode_u32(4, hex.substr(0, 8).hex_to_int())
	return b.decode_double(0)


func test_bits_decoder() -> void:
	assert_eq(_from_bits("3ff0000000000000"), 1.0)
	assert_eq(_from_bits("c004000000000000"), -2.5)


func test_first_1000_draws_match_the_typescript_for_each_seed() -> void:
	var seeds: Array = _fx["seeds"]
	assert_eq(seeds.size(), 4)
	for s: Variant in seeds:
		var expected: Array = _fx["next"][str(int(s))]
		assert_eq(expected.size(), 1000)
		var r: Rng = Rng.new(int(s))
		var mismatches: Array[String] = []
		for i: int in expected.size():
			var want: float = float(expected[i]) / 4294967296.0
			var got: float = r.next()
			if got != want and mismatches.size() < 5:
				mismatches.append("draw %d: got %.17f, want %.17f" % [i, got, want])
		assert_eq(mismatches, [] as Array[String], "seed %d" % int(s))


func test_default_seed_is_1234567() -> void:
	var r: Rng = Rng.new()
	var expected: Array = _fx["defaultSeedFirst"]
	for u: Variant in expected:
		assert_eq(r.next(), float(u) / 4294967296.0)


func test_int_range_chance_and_pick_match_the_typescript() -> void:
	var pick_from: Array = _fx["pickFrom"]
	var samples: Dictionary = _fx["samples"]
	assert_eq(samples.size(), 6)
	for key: Variant in samples:
		var r: Rng = Rng.new(String(key).to_int())
		var mismatches: Array[String] = []
		var i: int = 0
		for sample: Dictionary in samples[key]:
			if sample.has("int"):
				var want_i: int = int(sample["int"])
				var got_i: int = r.int(-3, 3) if i % 5 == 0 else r.int(1, 7)
				if got_i != want_i:
					mismatches.append("#%d int: got %d, want %d" % [i, got_i, want_i])
			elif sample.has("range"):
				var want_r: float = _from_bits(sample["range"]["bits"])
				var got_r: float = r.range(-2.5, 4.0)
				if got_r != want_r:
					mismatches.append("#%d range: got %.17f, want %.17f" % [i, got_r, want_r])
			elif sample.has("chance"):
				var got_c: bool = r.chance(0.3)
				if got_c != bool(sample["chance"]):
					mismatches.append("#%d chance: got %s" % [i, got_c])
			elif sample.has("pick"):
				var got_p: Variant = r.pick(pick_from)
				if got_p != sample["pick"]:
					mismatches.append("#%d pick: got %s, want %s" % [i, got_p, sample["pick"]])
			i += 1
		assert_eq(i, 250, "seed %s sample count" % key)
		assert_eq(mismatches, [] as Array[String], "seed %s" % key)


func test_seeds_wrap_to_32_bits_like_js() -> void:
	# JS `seed >>> 0`: -5 becomes 2^32 - 5, 2^32 + 3 becomes 3.
	var a: Rng = Rng.new(-5)
	var b: Rng = Rng.new(4294967291)
	var c: Rng = Rng.new(4294967299)
	var d: Rng = Rng.new(3)
	for i: int in 20:
		assert_eq(a.next(), b.next())
		assert_eq(c.next(), d.next())
