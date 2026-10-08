extends GutTest
## The Katana's movement attacks re-keyed (milestone-1 tasks 75 and 76,
## family 5): each on its own re-keyed clip's real markers, moved by the
## clip's travel with the rules' lunge and hop retired, its damage and
## posture as they were (the owner's answer of Oct 8: balance waits on family
## 5's review, task 78) and its hitstun and hit-stop the frozen protected
## timings, as the pilot's were. One clip each for both grips (KE D14): the
## lights one-handed, the heavies two-handed (the owner's answer of Oct 8).
## The bands and distances are test_move_bands.gd's.

## id: [startup, active, recovery (rules frames), damage, posture, the least
## the clip carries it forward by its last active frame (m), its clip,
## one-handed]
const KEYED: Dictionary[StringName, Array] = {
	&"k_sl": [27, 4, 35, 8, 9, 2.0, &"RunningDraw", true], # Running Draw, a cut at a run
	&"k_sh": [47, 4, 42, 15, 18, 3.0, &"LeapingCleave", false], # Leaping Cleave, a long leap
}
## The heavies, which keep a dodge cancel in the second half of their recovery.
const HEAVIES: Array[StringName] = [&"k_sh"]


func test_each_plays_its_keyed_clip_s_markers() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_eq([m.startup, m.active, m.recovery], KEYED[id].slice(0, 3), "%s (%s)" % [m.name, id])
		assert_true(m.real_markers, "%s: real markers" % m.name)


func test_each_keeps_its_damage_and_posture() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_eq([m.damage, m.posture], [float(KEYED[id][3]), float(KEYED[id][4])], m.name)


func test_each_moves_by_its_clip_s_travel_with_no_lunge_or_hop() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_true(m.by_travel, "%s: led by its clip" % m.name)
		assert_eq(m.lunge_from(4.0), 0.0, "%s: no lunge" % m.name)
		assert_eq(m.hop, 0.0, "%s: no hop, the clip leaps" % m.name)
		var forward: float = 0.0
		for f: int in m.startup + m.active + 1:
			forward += m.travel_at(f)[0]
		assert_gt(forward, float(KEYED[id][5]), "%s: carried forward by its last active frame (%.2f m)" % [m.name, forward])


func test_each_turns_no_more_than_a_few_degrees() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		var turned: float = 0.0
		for f: int in m.total_frames() + 1:
			turned += m.travel_at(f)[2]
		assert_between(turned, -8.0, 8.0, "%s turns %.1f degrees" % [m.name, turned])


func test_each_takes_the_frozen_protected_timings() -> void:
	var t: ProtectedTimings = ProtectedTimings.for_weapon(&"katana")
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_eq(m.hitstun, t.hitstun(m.kind, id), "%s: hitstun" % m.name)
		assert_eq(m.hitstop, t.hitstop(m.kind), "%s: hit-stop" % m.name)


func test_the_heavies_keep_a_dodge_cancel_late_in_their_recovery() -> void:
	for id: StringName in HEAVIES:
		var m: AttackDef = Moves.KATANA.moves[id]
		var recovery_from: int = m.startup + m.active
		assert_between(m.dodge_cancel_from, recovery_from + m.recovery / 2 - 2, m.startup + m.active + m.recovery, "%s: from the second half of its recovery" % m.name)


func test_each_plays_one_clip_for_both_grips_the_lights_one_handed() -> void:
	var clips: MoveClips = MoveClips.read(ClipManifest.read())
	for id: StringName in KEYED:
		var e: MoveClips.Entry = clips.of(&"katana")[id]
		assert_eq(e.clips, [KEYED[id][6]] as Array[StringName], "%s: its own clip" % id)
		assert_eq(Moves.KATANA.moves[id].grip, &"", "%s: no grip of its own, played from either" % id)
		assert_eq(StateClips.shared().one_handed(&"katana", KEYED[id][6]), KEYED[id][7],
			"%s: %s" % [id, "one-handed, the off hand off the grip" if KEYED[id][7] else "two-handed, the off hand on the grip"])
