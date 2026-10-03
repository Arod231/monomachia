class_name FighterBody
extends RefCounted
## A fighter's body in the rules (task 7.5): the hurt capsule that blades are
## swept against. It is rules data by fighter id (MatchSide.fighter_id), so
## the rules never load a fighter's scene, and a fighter built without an id
## (the rule tests, the soak run) gets the default body.
##
## The hurt capsule stands on the feet: `hurt_radius` round the fighter's
## upright axis, from the feet up to `hurt_height`, and it rises with the
## fighter when they leave the ground. For the Rogue and the Hunter it is
## 0.35 m round and 1.75 m tall. SimConst.FIGHTER_RADIUS (0.42), which keeps
## the fighters apart and serves the cone checks, is a separate number.

## The bodies by fighter id. The default body, for no id, is the same.
const BODIES: Dictionary[StringName, Dictionary] = {
	&"rogue": {"hurt_radius": 0.35, "hurt_height": 1.75},
	&"hunter": {"hurt_radius": 0.35, "hurt_height": 1.75},
}
const DEFAULT: Dictionary = {"hurt_radius": 0.35, "hurt_height": 1.75}

## The fighter id; empty for the default body.
var id: StringName = &""
var hurt_radius: float = 0.0
var hurt_height: float = 0.0


## The body of the fighter `fighter_id`: the default body when the id is
## empty, and with an error when no fighter has it.
static func of(fighter_id: StringName) -> FighterBody:
	var body: FighterBody = FighterBody.new()
	var record: Dictionary = DEFAULT
	if BODIES.has(fighter_id):
		body.id = fighter_id
		record = BODIES[fighter_id]
	elif fighter_id != &"":
		push_error("FighterBody: unknown fighter %s; the default body stands in" % fighter_id)
	body.hurt_radius = float(record["hurt_radius"])
	body.hurt_height = float(record["hurt_height"])
	return body


## The hurt capsule of this body standing at `pos` (its feet; above the
## ground while airborne), in world space.
func hurt_capsule(pos: V3) -> SimCapsule:
	return SimCapsule.make(
		V3.make(pos.x, pos.y + hurt_radius, pos.z),
		V3.make(pos.x, pos.y + hurt_height - hurt_radius, pos.z),
		hurt_radius,
	)
