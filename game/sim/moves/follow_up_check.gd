class_name FollowUpCheck
extends RefCounted
## The free-frame rule over the follow-up pairs (milestone-1 spec, "The
## protected-timing table"; milestone-1 task 22): no follow-up is
## guaranteed. Counting from a hit on a move's last active frame and its
## follow-up taken at its branch point, the defender must be out of hitstun
## at least 1 frame before the follow-up lands; and each branch point is at
## least the earliest the timing band table allows after the move's last
## active frame (a light's follow-ups 1, a heavy's 18), which keeps the rule
## at the band floors.
##
## As the rules step: a follow-up starts on the step its move reaches its
## branch point and plays its frame 1 on the next, so it lands its startup
## plus 1 step after the branch point, and a defender put in H frames of
## hitstun by a hit on step L is free from step L + H. A pair is checked once
## both moves are off the band tests' waiting list (MoveBands.is_held()), as
## each family's keying task brings its pairs in.

## The fewest frames after a move's last active frame its follow-ups may
## branch, by the move's kind in the frame-data table (the spec's earliest
## branch points): the string lights 1 (each grip's own too, KE task 11); the heavies with follow-ups (the Iai
## draws, the Iai follow-ups, the string heavies, Roundhouse among them, and
## the grips' own heavies, KE task 16) 18.
const EARLIEST_BRANCH: Dictionary[StringName, int] = {
	&"string_light": 1,
	&"string_light_1h": 1,
	&"string_last_1h": 1,
	&"string_light_2h": 1,
	&"string_last_2h": 1,
	&"string_heavy": 18,
	&"grip_heavy_1h": 18,
	&"grip_heavy_2h": 18,
	&"grip_heavy_follow_up": 18,
	&"iai_draw": 18,
	&"iai_follow_up": 18,
}


## The frames the defender is free before `follow` lands, after a hit of
## `def` on its last active frame and `follow` taken at its branch point (a
## negative count: still in hitstun when it lands).
static func free_frames(def: AttackDef, follow: AttackDef) -> int:
	return branch_gap(def, follow.id) + follow.startup + 1 - def.hitstun


## How many frames after its last active frame `def` branches to `follow`.
static func branch_gap(def: AttackDef, follow: StringName) -> int:
	return def.branch_window(follow)[0] - (def.startup + def.active)


## Every problem of weapon `w`'s follow-up pairs with both moves held, as
## `held(id) -> bool` says, with each move's kind from `kind(id) ->
## StringName`: a pair that leaves the defender no free frame, and a branch
## point earlier than its kind allows.
static func problems(w: WeaponDef, held: Callable, kind: Callable) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in w.moves:
		var def: AttackDef = w.moves[id]
		if not held.call(id):
			continue
		for follow: StringName in [def.chain_light, def.chain_heavy]:
			if follow == &"" or not w.moves.has(follow) or not held.call(follow):
				continue
			var next: AttackDef = w.moves[follow]
			var free: int = free_frames(def, next)
			if free < 1:
				out.append("%s.%s -> %s: the defender is free %d frames before it lands (at least 1)" % [w.id, id, follow, free])
			var k: StringName = kind.call(id)
			var gap: int = branch_gap(def, follow)
			if EARLIEST_BRANCH.has(k) and gap < EARLIEST_BRANCH[k]:
				out.append("%s.%s -> %s: branches %d frames after its active frames (a %s's earliest is %d)" % [w.id, id, follow, gap, k, EARLIEST_BRANCH[k]])
	return out


## The problems of a weapon of the game, its pairs held by the band tests
## and its kinds from the frame-data table.
static func weapon_problems(w: WeaponDef) -> Array[String]:
	var bands: MoveBands = MoveBands.shared()
	var table: FrameDataTable = FrameDataTable.shared()
	var kind: Callable = func(id: StringName) -> StringName:
		return StringName(table.row(w.id, id).get("kind", ""))
	var held: Callable = func(id: StringName) -> bool:
		return bands.is_held(w.id, id, kind.call(id))
	return problems(w, held, kind)
