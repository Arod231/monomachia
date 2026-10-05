extends GutTest
## Every swing passes SwingCheck (task 7.7) on both reference bodies: entered
## from the guard, and from every move that chains into it. Empty until moves
## have swings (7.16 on); the second test shows it reports a bad one.

const TS := preload("res://tests/sim/test_swing_check.gd")


## Every problem of every swing of `w`, on each reference body, named by
## weapon, move, body and entry.
static func _problems(w: WeaponDef) -> Array[String]:
	var out: Array[String] = []
	for body_id: StringName in ReferenceBody.BODIES:
		var body: ReferenceBody = ReferenceBody.of(body_id)
		for id: StringName in w.moves:
			var m: AttackDef = w.moves[id]
			if m.swing == null:
				continue
			var entries: Dictionary[String, Swing] = {"the guard": null}
			for from_id: StringName in w.moves:
				var before: AttackDef = w.moves[from_id]
				if before.swing != null and (before.chain_light == id or before.chain_heavy == id):
					entries[String(from_id)] = before.swing
			for entry: String in entries:
				for p: String in SwingCheck.check(m, w, body, entries[entry]):
					out.append("%s.%s on the %s, from %s: %s" % [w.id, id, body_id, entry, p])
	return out


func test_every_swing_passes_on_both_bodies() -> void:
	var problems: Array[String] = []
	for wid: StringName in Moves.WEAPONS:
		problems.append_array(_problems(Moves.WEAPONS[wid]))
	assert_eq(problems, [] as Array[String])


func test_a_bad_follow_up_is_reported_from_each_entry_on_each_body() -> void:
	var w: WeaponDef = TS._sword()
	w.id = &"test_sword"
	var first: AttackDef = TS._move(TS._cut(ReferenceBody.of(&"rogue")), 8, 3, 14)
	first.id = &"first"
	var turned: AttackDef = TS._move(TS._cut_with(ReferenceBody.of(&"rogue"), 8,
			TS._key(ReferenceBody.of(&"rogue"), &"right", 8, TS._v(0.3, -0.8, 0.5), TS._v(-0.1, 0.2, 0.97), TS._v(1.0, 0.3, 0.0), 0.0, 50.0)), 8, 3, 14)
	turned.id = &"turned"
	first.chain_light = &"turned"
	w.moves = {&"first": first, &"turned": turned}
	var found: Array[String] = []
	for p: String in _problems(w):
		if p.contains("wrist turns"):
			found.append(p.get_slice(":", 0))
	found.sort()
	assert_eq(found, [
		"test_sword.turned on the hunter, from first",
		"test_sword.turned on the hunter, from the guard",
		"test_sword.turned on the rogue, from first",
		"test_sword.turned on the rogue, from the guard",
	] as Array[String])
