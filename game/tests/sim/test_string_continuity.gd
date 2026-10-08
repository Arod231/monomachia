extends GutTest
## String continuity (the spec's move data, plan task 9.1): each follow-up
## starts on the side the move before it ends on, so a string's swings flow
## (story 16). Sides are left, right or centre. A move starting at centre (an
## overhead, a thrust, a stab, a spin, the crossing cut) may follow any end; a
## left or right start must match the end before it.

## The weapons whose strings the rebuild has redone.
const WEAPONS: Array[StringName] = [&"katana", &"greatsword", &"daggers"]

## The spec's sides (written out here rather than read from AttackDef.SIDES,
## so the check holds the data to the spec).
const SIDES: Array[StringName] = [&"left", &"right", &"centre"]


## Every way the follow-ups among moves break continuity, one message each
## ([] when none): a follow-up or a release variant that isn't among the
## moves, a follow-up starting on the wrong side, a move in a string without
## both its sides, and a move in no string with a side. A release variant (the
## horizontal Iai) stands in for its move, so it is in its move's string.
## Given its weapon `w`, a move's follow-ups are its grips' too (KE task 7):
## a string hit's next hit and heavy in each grip, the heavy starter's heavy
## follow-up in each.
static func _breaks(moves: Dictionary[StringName, AttackDef], w: WeaponDef = null) -> Array[String]:
	var out: Array[String] = []
	var in_a_string: Dictionary[StringName, bool] = {}
	for id: StringName in moves:
		var m: AttackDef = moves[id]
		for next_id: StringName in _follow_ups(m, w):
			if next_id == &"":
				continue
			in_a_string[id] = true
			var next: AttackDef = moves.get(next_id, null)
			if next == null:
				out.append("%s follows %s but isn't one of its weapon's moves" % [next_id, id])
				continue
			in_a_string[next_id] = true
			var both_sided: bool = SIDES.has(m.side_end) and SIDES.has(next.side_start)
			if both_sided and next.side_start != &"centre" and next.side_start != m.side_end:
				out.append(
					"%s starts on the %s but follows %s, which ends on the %s" % [next_id, next.side_start, id, m.side_end]
				)
	for id: StringName in moves:
		var variant: StringName = moves[id].release_variant
		if variant == &"":
			continue
		if not moves.has(variant):
			out.append("%s is %s's release variant but isn't one of its weapon's moves" % [variant, id])
		elif in_a_string.has(id):
			in_a_string[variant] = true
	for id: StringName in moves:
		var m: AttackDef = moves[id]
		var sides: Array = [id, m.side_start, m.side_end]
		if in_a_string.has(id) and not (SIDES.has(m.side_start) and SIDES.has(m.side_end)):
			out.append("%s is in a string but its sides are '%s' to '%s'" % sides)
		elif not in_a_string.has(id) and (m.side_start != &"" or m.side_end != &""):
			out.append("%s is in no string but its sides are '%s' to '%s'" % sides)
	return out


## Move m's follow-ups: its own light and heavy, and with weapon `w` its
## grips' (KE task 7).
static func _follow_ups(m: AttackDef, w: WeaponDef) -> Array[StringName]:
	var out: Array[StringName] = [m.chain_light, m.chain_heavy]
	if w == null:
		return out
	for g: WeaponGrip in w.grips:
		var at: int = g.string.find(m.id)
		while at >= 0:
			out.append(g.hit(at + 2))
			out.append(g.heavy)
			at = g.string.find(m.id, at + 1)
		if m.id == w.heavy_start and m.chain_heavy != &"":
			out.append(g.draw_heavy)
	return out


## Moves for the checks on _breaks: each record gets the frames every move
## needs.
static func _moves(records: Dictionary) -> Dictionary[StringName, AttackDef]:
	var full: Dictionary = {}
	for id: StringName in records:
		var r: Dictionary = (records[id] as Dictionary).duplicate()
		r.merge({"id": id, "kind": &"light", "startup": 10, "active": 3, "recovery": 15})
		full[id] = r
	return AttackDef.finalize_moves(full)


func test_every_follow_up_starts_where_the_move_before_it_ends() -> void:
	for w: StringName in WEAPONS:
		assert_eq(_breaks(Moves.WEAPONS[w].moves, Moves.WEAPONS[w]), [] as Array[String], String(w))


# Into and out of the two-handed heavy pair (KE task 17): Heaven Splitter,
# an overhead from the centre, follows every two-handed hit; Rising Heaven
# rises from the centre of its crouch (and from the vertical Iai's end) to
# the right, and nothing follows it.
func test_the_two_handed_heavy_pair_flows_in_and_out() -> void:
	var w: WeaponDef = Moves.KATANA
	var splitter: AttackDef = w.moves[&"k_h2"]
	var rising: AttackDef = w.moves[&"k_h1f"]
	var two: WeaponGrip = w.grip(WeaponGrip.TWO_HANDED)
	assert_eq(two.heavy, &"k_h2")
	for id: StringName in two.string:
		assert_true(_follow_ups(w.moves[id], w).has(&"k_h2"), "%s branches into Heaven Splitter" % id)
	assert_eq([splitter.side_start, splitter.side_end], [&"centre", &"centre"], "straight down the centre")
	assert_eq(splitter.chain_heavy, &"k_h1f")
	assert_eq(two.draw_heavy, &"k_h1f", "the vertical Iai's heavy follow-up too")
	assert_eq([rising.side_start, rising.side_end], [&"centre", &"right"], "up from the crouch to the right")
	assert_eq([rising.chain_light, rising.chain_heavy], [&"", &""], "the pair ends there")


func test_the_check_reports_a_follow_up_starting_on_the_wrong_side() -> void:
	var moves: Dictionary[StringName, AttackDef] = _moves({
		&"a": {"side_start": &"right", "side_end": &"left", "chain_light": &"b", "chain_heavy": &"c"},
		&"b": {"side_start": &"right", "side_end": &"left"},
		&"c": {"side_start": &"centre", "side_end": &"right", "chain_light": &"d"},
		&"d": {"side_start": &"right", "side_end": &"left"},
	})
	assert_eq(
		_breaks(moves),
		["b starts on the right but follows a, which ends on the left"] as Array[String],
		"a right start after a left end breaks; a centre start after any end and a right start after a right end don't",
	)


func test_the_check_reports_a_missing_follow_up_and_a_missing_side() -> void:
	var moves: Dictionary[StringName, AttackDef] = _moves({
		&"a": {"side_start": &"right", "side_end": &"left", "chain_light": &"gone", "chain_heavy": &"b"},
		&"b": {"side_start": &"left"},
		&"c": {},
	})
	assert_eq(
		_breaks(moves),
		[
			"gone follows a but isn't one of its weapon's moves",
			"b is in a string but its sides are 'left' to ''",
		] as Array[String],
		"a move outside any string (c) needs no sides",
	)


func test_the_check_reports_a_missing_release_variant_and_puts_a_variant_in_its_moves_string() -> void:
	var moves: Dictionary[StringName, AttackDef] = _moves({
		&"a": {"side_start": &"left", "side_end": &"right", "chain_heavy": &"b", "release_variant": &"a_h"},
		&"b": {"side_start": &"right", "side_end": &"left"},
		&"a_h": {},
		&"c": {"release_variant": &"gone"},
	})
	assert_eq(
		_breaks(moves),
		[
			"gone is c's release variant but isn't one of its weapon's moves",
			"a_h is in a string but its sides are '' to ''",
		] as Array[String],
		"a's variant stands in for a, so it needs sides; c is in no string, so it needs none",
	)


func test_the_check_reports_sides_on_a_move_outside_any_string() -> void:
	var moves: Dictionary[StringName, AttackDef] = _moves({
		&"a": {"side_start": &"right", "side_end": &"left", "chain_light": &"b"},
		&"b": {"side_start": &"left", "side_end": &"right"},
		&"c": {"side_end": &"left"},
	})
	assert_eq(
		_breaks(moves),
		["c is in no string but its sides are '' to 'left'"] as Array[String],
		"only moves in a string have sides",
	)
