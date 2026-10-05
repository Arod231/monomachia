class_name DemoDraft
extends RefCounted
## The fighter select's drafts as they were before milestone 1 (task 4 made
## every default the Hunter mirror): the Rogue with the Katana against the
## Hunter with the Greatsword, and in Watch against the Hunter with the Twin
## Daggers. The select's own tests walk these with the whole roster
## (Roster.full), so a step to another fighter or weapon has somewhere to go.


static func of(mode: StringName) -> MatchSelection.Draft:
	var d: MatchSelection.Draft = MatchSelection.default_draft(mode)
	d.sides[0].fighter_id = &"rogue"
	d.sides[1].weapon_id = &"daggers" if mode == MatchConfig.WATCH else &"greatsword"
	return d
