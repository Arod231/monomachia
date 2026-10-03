class_name StickPose
extends RefCounted
## How a fighter holds its weapon, worked out from the rules' state the
## simple way: a stand-in for the swings (plan task 14.10 on). FighterView
## turns each hand into a weapon pose for the rig's IK.
##
## A pose is the hands' positions and blade directions in the fighter's own
## frame, plus a body lean, crouch and spin. Guard and block poses come per
## weapon; an attack sweeps the stick through three keys picked by the move's
## anim (falling back on its type): wind-up during startup, strike into the
## impact key on the first active frame, follow-through, then back to guard
## over recovery. The keys are the demo's attack archetypes (src/render/
## pose.ts ARCH, wind-up / impact / follow-through), and the hand travels
## between them on an arc around the body, not in a straight line.
##
## Keys are written as the demo wrote them, [right, up, forward] in metres;
## local() turns them into the fighter node's frame (+z forward, -x right).

## The stick's length per weapon (m), grip to tip, as the keys were made
## for: where a key's blade tip is (FighterView reads which way a strike
## sweeps it).
const LENGTH: Dictionary[StringName, float] = {
	&"katana": 0.95,
	&"greatsword": 1.6,
	&"daggers": 0.4,
	&"fists": 0.0,
}


## One hand: where it is, where its blade points, and whether it is drawn.
class Hand:
	var pos: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.UP
	var visible: bool = true

	static func make(p: Vector3, d: Vector3, v: bool = true) -> Hand:
		var h: Hand = Hand.new()
		h.pos = p
		h.dir = d.normalized() if d.length() > 1e-6 else Vector3.UP
		h.visible = v
		return h

	func copy() -> Hand:
		return make(pos, dir, visible)


## A whole pose. glow is &"" or one of &"danger" (an unblockable winding
## up), &"charge" (a held heavy), &"ult".
class Pose:
	var right: Hand
	var left: Hand
	## Both hands on one grip (katana, greatsword).
	var two_handed: bool = false
	## No weapon in hand (disarmed or bare hands).
	var bare: bool = false
	var lean: float = 0.0
	var crouch: float = 0.0
	var spin: float = 0.0
	## 0..1: lying on the floor after a KO.
	var down: float = 0.0
	var glow: StringName = &""
	var glow_amount: float = 0.0
	## Rough phase for tests and debugging: &"guard", &"block", &"windup",
	## &"strike", &"follow", &"recover", &"reel", &"down", ...
	var phase: StringName = &"guard"


# ------------------------------------------------------------------ data

## Guard per weapon: [rh, rd, lh, ld]. The Katana's is the grounded guard
## stance's (GuardStance, plan task 14.8): both hands on the centre line at
## the navel, the blade raised 50 degrees toward the opponent, so that both
## wrists pass PoseCheck on the rig's hanging elbows. The stance's lowered
## pelvis carries it down 9 cm, and FighterView pulls it 1-4 cm in toward
## the shoulders, as it does every pose out of reach. The left hand's key
## sits down the handle from the right's.
const GUARD: Dictionary[StringName, Array] = {
	&"katana": [[-0.02, 1.04, 0.33], [0.0, 0.766, 0.643], [-0.02, 0.934, 0.241], [0.0, 0.766, 0.643]],
	&"greatsword": [[0.3, 0.98, 0.24], [-0.1, 0.88, 0.46], [0.2, 0.88, 0.24], [-0.1, 0.88, 0.46]],
	&"daggers": [[0.2, 1.16, 0.32], [0.05, 0.34, 0.94], [-0.2, 1.2, 0.3], [-0.05, 0.34, 0.94]],
	&"fists": [[0.15, 1.45, 0.3], [0.0, 1.0, 0.0], [-0.15, 1.47, 0.3], [0.0, 1.0, 0.0]],
}

## Block per weapon (pose.ts BLOCK): [rh, rd, lh, ld]
const BLOCK: Dictionary[StringName, Array] = {
	&"katana": [[0.22, 1.44, 0.36], [-0.95, 0.24, 0.15], [0.0, 1.4, 0.36], [-0.95, 0.24, 0.15]],
	&"greatsword": [[0.1, 1.06, 0.36], [-0.16, 0.98, 0.12], [0.06, 0.92, 0.34], [-0.16, 0.98, 0.12]],
	&"daggers": [[0.08, 1.42, 0.34], [-0.62, 0.72, 0.28], [-0.08, 1.44, 0.34], [0.62, 0.72, 0.28]],
	&"fists": [[0.1, 1.5, 0.3], [0.0, 1.0, 0.0], [-0.1, 1.52, 0.3], [0.0, 1.0, 0.0]],
}

## Attack archetypes (pose.ts ARCH): anim -> [wind-up, impact, follow-through],
## each key { rh, rd, lh?, ld?, lean?, dy?, spin? }.
const ARCH: Dictionary[StringName, Array] = {
	&"slashRL": [
		{"rh": [0.42, 1.38, 0.02], "rd": [0.55, 0.4, -0.73], "lean": 0.02, "dy": -0.08},
		{"rh": [0.05, 1.22, 0.56], "rd": [-0.72, 0.05, 0.69], "lean": 0.14, "dy": -0.12},
		{"rh": [-0.34, 1.12, 0.36], "rd": [-0.82, -0.08, -0.56], "lean": 0.12, "dy": -0.11},
	],
	&"slashLR": [
		{"rh": [-0.3, 1.4, 0.18], "rd": [-0.62, 0.42, -0.66], "lean": 0.02, "dy": -0.08},
		{"rh": [0.1, 1.22, 0.56], "rd": [0.75, 0.05, 0.66], "lean": 0.14, "dy": -0.12},
		{"rh": [0.46, 1.12, 0.24], "rd": [0.85, -0.08, -0.52], "lean": 0.12, "dy": -0.11},
	],
	&"diagDown": [
		{"rh": [0.3, 1.82, -0.05], "rd": [0.32, 0.52, -0.79], "lean": -0.1, "dy": -0.05},
		{"rh": [0.06, 1.28, 0.56], "rd": [-0.5, -0.25, 0.83], "lean": 0.2, "dy": -0.14},
		{"rh": [-0.28, 0.88, 0.38], "rd": [-0.55, -0.72, 0.42], "lean": 0.32, "dy": -0.2},
	],
	&"diagUp": [
		{"rh": [-0.28, 0.82, 0.32], "rd": [-0.55, -0.68, 0.48], "lean": 0.25, "dy": -0.17},
		{"rh": [0.1, 1.32, 0.56], "rd": [0.42, 0.52, 0.74], "lean": 0.1, "dy": -0.1},
		{"rh": [0.34, 1.78, 0.16], "rd": [0.35, 0.82, -0.45], "lean": -0.1, "dy": -0.04},
	],
	&"overhead": [
		{"rh": [0.06, 1.98, -0.08], "rd": [0.02, 0.35, -0.94], "lean": -0.15, "dy": -0.04},
		{"rh": [0.03, 1.38, 0.58], "rd": [0.0, 0.12, 0.99], "lean": 0.16, "dy": -0.13},
		{"rh": [0.02, 0.98, 0.52], "rd": [0.0, -0.66, 0.75], "lean": 0.34, "dy": -0.2},
	],
	&"thrust": [
		{"rh": [0.22, 1.16, -0.18], "rd": [0.02, 0.06, 1.0], "lean": -0.05, "dy": -0.15},
		{"rh": [0.03, 1.26, 0.8], "rd": [0.0, 0.03, 1.0], "lean": 0.26, "dy": -0.21},
		{"rh": [0.03, 1.24, 0.74], "rd": [0.0, 0.0, 1.0], "lean": 0.22, "dy": -0.21},
	],
	&"sweep": [
		{"rh": [0.5, 0.86, -0.15], "rd": [0.62, -0.32, -0.72], "lean": 0.3, "dy": -0.36},
		{"rh": [0.06, 0.62, 0.58], "rd": [-0.76, -0.28, 0.58], "lean": 0.45, "dy": -0.42},
		{"rh": [-0.46, 0.66, 0.2], "rd": [-0.8, -0.24, -0.55], "lean": 0.36, "dy": -0.38},
	],
	&"slam": [
		{"rh": [0.02, 2.06, -0.26], "rd": [0.0, 0.12, -0.99], "lean": -0.25, "dy": 0.0},
		{"rh": [0.02, 0.9, 0.66], "rd": [0.0, -0.55, 0.83], "lean": 0.5, "dy": -0.3},
		{"rh": [0.02, 0.84, 0.64], "rd": [0.0, -0.62, 0.78], "lean": 0.52, "dy": -0.32},
	],
	&"spin": [
		{"rh": [0.45, 1.25, -0.1], "rd": [0.7, 0.1, -0.7], "dy": -0.12, "spin": 0.0},
		{"rh": [0.05, 1.2, 0.62], "rd": [-0.6, 0.0, 0.8], "dy": -0.16, "spin": -PI},
		{"rh": [-0.3, 1.15, 0.4], "rd": [-0.8, 0.0, -0.5], "dy": -0.13, "spin": -TAU},
	],
	&"bash": [
		{"rh": [0.2, 1.15, 0.05], "rd": [0.1, 0.6, -0.78], "lean": 0.1, "dy": -0.12},
		{"rh": [0.18, 1.12, 0.12], "rd": [0.1, 0.6, -0.78], "lean": 0.35, "dy": -0.18},
		{"rh": [0.18, 1.12, 0.12], "rd": [0.1, 0.6, -0.78], "lean": 0.3, "dy": -0.18},
	],
	&"pommel": [
		{"rh": [0.12, 1.22, 0.12], "rd": [0.05, 0.55, -0.83]},
		{"rh": [0.02, 1.42, 0.58], "rd": [0.08, 0.45, -0.89], "lean": 0.2},
		{"rh": [0.04, 1.36, 0.5], "rd": [0.08, 0.5, -0.86], "lean": 0.15},
	],
	&"drawCut": [
		{"rh": [-0.28, 1.02, 0.18], "rd": [-0.3, -0.25, 0.92], "lean": 0.25, "dy": -0.18},
		{"rh": [0.12, 1.18, 0.6], "rd": [0.8, 0.12, 0.58], "lean": 0.3, "dy": -0.2},
		{"rh": [0.5, 1.25, 0.2], "rd": [0.85, 0.2, -0.48], "lean": 0.25, "dy": -0.18},
	],
	&"leapCleave": [
		{"rh": [0.06, 2.0, -0.1], "rd": [0.02, 0.3, -0.95], "lean": -0.2, "dy": -0.1},
		{"rh": [0.03, 1.3, 0.6], "rd": [0.0, -0.05, 1.0], "lean": 0.3, "dy": -0.18},
		{"rh": [0.02, 0.92, 0.55], "rd": [0.0, -0.7, 0.71], "lean": 0.42, "dy": -0.26},
	],
	&"airSlash": [
		{"rh": [0.42, 1.4, 0.02], "rd": [0.55, 0.4, -0.73]},
		{"rh": [0.05, 1.22, 0.56], "rd": [-0.72, 0.0, 0.69], "lean": 0.14},
		{"rh": [-0.34, 1.1, 0.36], "rd": [-0.82, -0.1, -0.56], "lean": 0.12},
	],
	&"plunge": [
		{"rh": [0.03, 1.95, 0.05], "rd": [0.0, 0.95, -0.3], "lean": -0.1},
		{"rh": [0.03, 1.05, 0.52], "rd": [0.0, -0.8, 0.6], "lean": 0.35, "dy": -0.12},
		{"rh": [0.03, 0.9, 0.5], "rd": [0.0, -0.85, 0.52], "lean": 0.4, "dy": -0.26},
	],
	&"flash": [
		{"rh": [0.08, 1.02, 0.28], "rd": [-0.35, 0.28, 0.9], "lean": 0.12, "dy": -0.26},
		{"rh": [0.08, 1.02, 0.28], "rd": [-0.35, 0.28, 0.9], "lean": 0.12, "dy": -0.26},
		{"rh": [0.08, 1.02, 0.28], "rd": [-0.35, 0.28, 0.9], "lean": 0.12, "dy": -0.26},
	],
	&"slideSlash": [
		{"rh": [0.42, 1.1, 0.0], "rd": [0.55, 0.2, -0.8], "lean": 0.35, "dy": -0.34},
		{"rh": [0.05, 0.95, 0.6], "rd": [-0.72, -0.05, 0.69], "lean": 0.4, "dy": -0.38},
		{"rh": [-0.34, 0.95, 0.38], "rd": [-0.82, -0.1, -0.56], "lean": 0.35, "dy": -0.36},
	],
	&"shadowStep": [
		{"rh": [0.35, 1.0, -0.25], "rd": [0.25, -0.2, -0.95], "lh": [-0.35, 1.0, -0.25], "ld": [-0.25, -0.2, -0.95], "lean": 0.45, "dy": -0.32},
		{"rh": [0.35, 0.95, -0.3], "rd": [0.25, -0.2, -0.95], "lh": [-0.35, 0.95, -0.3], "ld": [-0.25, -0.2, -0.95], "lean": 0.55, "dy": -0.36},
		{"rh": [0.3, 1.1, 0.1], "rd": [0.1, 0.2, 0.97], "lh": [-0.3, 1.15, 0.1], "ld": [-0.1, 0.3, 0.95], "lean": 0.25, "dy": -0.2},
	],
	&"cross": [
		{"rh": [0.42, 1.55, 0.1], "rd": [0.3, 0.9, 0.3], "lh": [-0.42, 1.55, 0.1], "ld": [-0.3, 0.9, 0.3], "lean": -0.05},
		{"rh": [-0.05, 1.15, 0.56], "rd": [-0.7, -0.3, 0.65], "lh": [0.05, 1.12, 0.56], "ld": [0.7, -0.3, 0.65], "lean": 0.2, "dy": -0.13},
		{"rh": [-0.3, 0.95, 0.35], "rd": [-0.8, -0.5, 0.3], "lh": [0.3, 0.95, 0.35], "ld": [0.8, -0.5, 0.3], "lean": 0.25, "dy": -0.15},
	],
	&"doubleStab": [
		{"rh": [0.22, 1.15, -0.15], "rd": [0.0, 0.1, 1.0], "lh": [-0.2, 1.2, -0.15], "ld": [0.0, 0.1, 1.0], "lean": -0.05, "dy": -0.11},
		{"rh": [0.1, 1.2, 0.7], "rd": [0.0, 0.0, 1.0], "lh": [-0.1, 1.24, 0.68], "ld": [0.0, 0.0, 1.0], "lean": 0.26, "dy": -0.17},
		{"rh": [0.1, 1.2, 0.66], "rd": [0.0, 0.0, 1.0], "lh": [-0.1, 1.24, 0.64], "ld": [0.0, 0.0, 1.0], "lean": 0.24, "dy": -0.17},
	],
	&"pounce": [
		{"rh": [0.3, 1.3, -0.2], "rd": [0.2, 0.6, -0.8], "lh": [-0.3, 1.3, -0.2], "ld": [-0.2, 0.6, -0.8], "lean": 0.3, "dy": -0.32},
		{"rh": [0.12, 1.1, 0.62], "rd": [0.0, -0.5, 0.86], "lh": [-0.12, 1.1, 0.62], "ld": [0.0, -0.5, 0.86], "lean": 0.42, "dy": -0.1},
		{"rh": [0.12, 1.05, 0.6], "rd": [0.0, -0.55, 0.83], "lh": [-0.12, 1.05, 0.6], "ld": [0.0, -0.55, 0.83], "lean": 0.36, "dy": -0.22},
	],
	&"spinBoth": [
		{"rh": [0.5, 1.3, 0.0], "rd": [0.9, 0.1, 0.3], "lh": [-0.5, 1.3, 0.0], "ld": [-0.9, 0.1, -0.3], "dy": -0.13, "spin": 0.0},
		{"rh": [0.58, 1.25, 0.1], "rd": [0.95, 0.0, 0.3], "lh": [-0.58, 1.25, -0.1], "ld": [-0.95, 0.0, -0.3], "dy": -0.16, "spin": -PI},
		{"rh": [0.5, 1.25, 0.1], "rd": [0.95, 0.0, 0.3], "lh": [-0.5, 1.25, -0.1], "ld": [-0.95, 0.0, -0.3], "dy": -0.14, "spin": -TAU},
	],
}

## The sheathed hold (the Iai's sheathe and stance): the right hand on the
## hilt in front of the left hip, the blade lying back along the hip. The left
## hand's key, just behind it where the saya's mouth will be (14.16), goes
## unused while the two-handed Katana is posed from the right hand. A key as
## ARCH's are.
const SHEATHE: Dictionary = {
	"rh": [-0.1, 1.0, 0.22], "rd": [-0.3, -0.22, -0.93],
	"lh": [-0.18, 0.98, 0.1], "ld": [-0.3, -0.22, -0.93],
	"lean": 0.06, "dy": -0.08,
}

## Halfway through a draw from the sheathe: the blade out in front, pointing
## forward, so it clears the body before it rises into the cut's wind-up.
const DRAWN: Dictionary = {
	"rh": [-0.05, 1.15, 0.5], "rd": [0.15, 0.15, 0.97],
	"lh": [0.05, 1.1, 0.42], "ld": [0.15, 0.15, 0.97],
	"lean": 0.1, "dy": -0.1,
}

## Anims that draw from the sheathe: the move sheathes over its first
## Fighter.CHARGE_CHECK_FRAME frames, holds the sheathe while it charges (the
## stance), then draws the blade out in front (DRAWN) and up into the wind-up
## of the archetype named here, and cuts as that archetype does.
const SHEATHED_DRAWS: Dictionary[StringName, StringName] = {
	&"iaiVertical": &"overhead",
	&"iaiHorizontal": &"slashRL",
}

## The archetype for a move type when its anim has none.
const TYPE_ARCH: Dictionary[StringName, StringName] = {
	&"slash": &"slashRL",
	&"overhead": &"overhead",
	&"thrust": &"thrust",
	&"sweep": &"sweep",
	&"slam": &"slam",
	&"spin": &"spin",
	&"bash": &"bash",
	&"stab": &"thrust",
	&"punch": &"thrust",
	&"kick": &"bash",
}


# ------------------------------------------------------------------ helpers

## A [right, up, forward] key in the fighter node's frame (+z forward, -x right).
static func local(v: Array) -> Vector3:
	return Vector3(-float(v[0]), float(v[1]), float(v[2]))


## The same key mirrored to the other side of the body (a left-hand move).
static func mirrored(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Turns direction a toward b by t along the great circle, with a defined way
## round when they point opposite ways.
static func turn_dir(a: Vector3, b: Vector3, t: float) -> Vector3:
	var an: Vector3 = a.normalized()
	var bn: Vector3 = b.normalized()
	var axis: Vector3 = an.cross(bn)
	var ang: float = an.angle_to(bn)
	if ang < 1e-5:
		return bn
	if axis.length() < 1e-4:
		axis = an.cross(Vector3.UP)
		if axis.length() < 1e-4:
			axis = Vector3.RIGHT
	return an.rotated(axis.normalized(), ang * clampf(t, 0.0, 1.0))


## Keys this close to the body's centre line (|x|, m) are a vertical swing.
const CENTRE_LINE: float = 0.15


## Moves a hand from a to b by t on an arc around the body's vertical axis:
## the angle round the body, the distance from it and the height each blend,
## so a slash sweeps round the fighter instead of cutting a chord. Two keys
## on the body's centre line (an overhead, a slam: from behind the head to in
## front) move straight, in that vertical plane, instead of swinging out round
## the side.
static func arc(a: Vector3, b: Vector3, t: float) -> Vector3:
	t = clampf(t, 0.0, 1.0)
	var ra: float = Vector2(a.x, a.z).length()
	var rb: float = Vector2(b.x, b.z).length()
	if ra < 0.05 or rb < 0.05:
		return a.lerp(b, t)
	if absf(a.x) < CENTRE_LINE and absf(b.x) < CENTRE_LINE:
		return a.lerp(b, t)
	var aa: float = atan2(a.x, a.z)
	var ab: float = atan2(b.x, b.z)
	var ang: float = lerp_angle(aa, ab, t)
	var r: float = lerpf(ra, rb, t)
	return Vector3(sin(ang) * r, lerpf(a.y, b.y, t), cos(ang) * r)


static func blend_hand(a: Hand, b: Hand, t: float) -> Hand:
	return Hand.make(arc(a.pos, b.pos, t), turn_dir(a.dir, b.dir, t), b.visible if t > 0.5 else a.visible)


static func weapon_key(f: Fighter) -> StringName:
	return f.weapon.id if f.armed else &"fists"


static func _from_table(table: Dictionary[StringName, Array], wid: StringName) -> Array[Hand]:
	var row: Array = table.get(wid, table[&"katana"])
	return [Hand.make(local(row[0]), local(row[1])), Hand.make(local(row[2]), local(row[3]))]


## A key of the draw from the sheathe (SHEATHE, DRAWN) as attack_keys gives
## an attack's keys: { right, left, lean, crouch, spin }.
static func _draw_key(kf: Dictionary) -> Dictionary:
	return {
		"right": Hand.make(local(kf["rh"]), local(kf["rd"])),
		"left": Hand.make(local(kf["lh"]), local(kf["ld"])),
		"lean": float(kf.get("lean", 0.0)),
		"crouch": -float(kf.get("dy", 0.0)),
		"spin": 0.0,
	}


## The three keys of an attack as [[right hand, left hand], ...] plus the body
## numbers, for the fighter's weapon and the move's hand.
static func attack_keys(def: AttackDef, wid: StringName) -> Array[Dictionary]:
	var key: StringName = SHEATHED_DRAWS.get(def.anim, def.anim)
	if wid == &"daggers" and key == &"spin":
		key = &"spinBoth"
	if not ARCH.has(key):
		key = TYPE_ARCH.get(def.type, &"slashRL")
	var guard: Array[Hand] = _from_table(GUARD, wid)
	var out: Array[Dictionary] = []
	for kf: Dictionary in ARCH[key]:
		var rh: Vector3 = local(kf["rh"])
		var rd: Vector3 = local(kf["rd"])
		var right: Hand = Hand.make(rh, rd)
		var left: Hand = guard[1].copy()
		if kf.has("lh"):
			left = Hand.make(local(kf["lh"]), local(kf["ld"]))
		if def.hand == &"L":
			# a left-hand move: the right hand's key, mirrored, on the left
			left = Hand.make(mirrored(rh), mirrored(rd))
			right = guard[0].copy()
		elif def.hand == &"both" and not kf.has("lh"):
			left = Hand.make(mirrored(rh), mirrored(rd))
		out.append({
			"right": right,
			"left": left,
			"lean": float(kf.get("lean", 0.0)),
			"crouch": -float(kf.get("dy", 0.0)),
			"spin": float(kf.get("spin", 0.0)),
		})
	return out


# ------------------------------------------------------------------ the pose

## The pose for a fighter now. alpha is MatchHost.alpha(): the fraction of a
## step since the last one (1 during hit-stop); time is in seconds, for idle
## motion.
static func compute(f: Fighter, alpha: float, time: float = 0.0) -> Pose:
	var wid: StringName = weapon_key(f)
	var p: Pose = Pose.new()
	p.bare = wid == &"fists"
	p.two_handed = WeaponLook.IDS.has(wid) and WeaponLook.load_id(wid).two_handed
	var guard: Array[Hand] = _from_table(GUARD, wid)
	p.right = guard[0]
	p.left = guard[1]
	var sf: float = maxf(0.0, float(f.sf) - 1.0 + alpha)

	match f.state:
		&"attack":
			if f.atk != null:
				_attack(p, f, wid, guard, alpha, time)
		&"free", &"step", &"intro", &"land":
			if f.blocking:
				_set_block(p, wid, 1.0)
			else:
				var bob: float = sin(time * 2.4 + float(f.id)) * 0.012
				p.right.pos.y += bob
				p.left.pos.y += bob
			if f.state == &"land":
				p.crouch = 0.18
		&"blockstun":
			_set_block(p, wid, 1.0)
			p.lean = -0.12
			p.crouch = 0.1
			p.phase = &"block"
		&"parryAnim":
			_set_block(p, wid, 1.0)
			# the parry: the guard thrust out to meet the blade
			var push: float = 0.2 * (1.0 - smooth(sf / 7.0))
			p.right.pos.z += push
			p.left.pos.z += push
			p.lean = 0.1
			p.phase = &"parry"
		&"hitstun", &"stunned", &"stagger":
			_reel(p, 0.35, sf)
		&"recoil":
			# a parried attacker: the weapon thrown back and up
			_reel(p, 0.25, sf)
			p.right.dir = turn_dir(p.right.dir, Vector3(0.0, 0.7, -0.7), 0.8)
			p.left.dir = turn_dir(p.left.dir, Vector3(0.0, 0.7, -0.7), 0.8)
			p.right.pos.y += 0.35
			p.phase = &"recoil"
		&"disarmStagger":
			_reel(p, 0.45, sf)
		&"dodge", &"backstep":
			var back: bool = f.state == &"backstep" or (f.dodge != null and f.dodge.back)
			p.crouch = 0.25
			p.lean = -0.2 if back else 0.3
			p.phase = &"dodge"
		&"jump":
			p.crouch = 0.05
			p.phase = &"jump"
		&"pickup":
			p.crouch = 0.5
			p.lean = 0.45
			p.phase = &"pickup"
		&"stomp", &"leap":
			p.crouch = 0.3
			p.lean = 0.25
			p.phase = &"counter"
		&"ult", &"ultChoice", &"recall":
			_overhead(p, &"ult", 1.0)
			if f.ult != null and f.ult.kind == &"tempest" and f.ult.phase == &"spin":
				p.spin = -TAU * fmod(float(f.ult.pf) / 10.0, 1.0)
		&"impaled":
			_reel(p, 0.5, sf)
			p.phase = &"impaled"
		&"ko":
			p.down = smooth(sf / 18.0)
			p.phase = &"down"
		&"victory":
			_overhead(p, &"", smooth(sf / 20.0))
			p.phase = &"victory"
	return p


static func _set_block(p: Pose, wid: StringName, t: float) -> void:
	var b: Array[Hand] = _from_table(BLOCK, wid)
	p.right = blend_hand(p.right, b[0], t)
	p.left = blend_hand(p.left, b[1], t)
	p.phase = &"block"


static func _reel(p: Pose, amount: float, sf: float) -> void:
	var k: float = 1.0 - 0.5 * smooth(sf / 20.0)
	p.lean = -amount * k
	p.crouch = 0.06
	# guard dropped: blades sag toward the floor
	p.right.dir = turn_dir(p.right.dir, Vector3(0.0, -0.4, 0.9), 0.6)
	p.left.dir = turn_dir(p.left.dir, Vector3(0.0, -0.4, 0.9), 0.6)
	p.right.pos.y -= 0.15
	p.left.pos.y -= 0.15
	p.phase = &"reel"


static func _overhead(p: Pose, glow: StringName, t: float) -> void:
	var up_r: Hand = Hand.make(Vector3(-0.08, 1.95, 0.12), Vector3(0.0, 1.0, 0.15))
	var up_l: Hand = Hand.make(Vector3(0.08, 1.95, 0.12), Vector3(0.0, 1.0, 0.15))
	p.right = blend_hand(p.right, up_r, t)
	p.left = blend_hand(p.left, up_l, t)
	p.glow = glow
	p.glow_amount = 1.0 if glow != &"" else 0.0
	p.phase = &"raised"


static func _attack(p: Pose, f: Fighter, wid: StringName, guard: Array[Hand], alpha: float, time: float) -> void:
	var at: AttackState = f.atk
	var def: AttackDef = at.def
	var keys: Array[Dictionary] = attack_keys(def, wid)
	var s: float = float(maxi(1, def.startup))
	var a: float = float(maxi(1, def.active))
	var r: float = float(maxi(1, def.recovery + at.extra_recovery))
	var fr: float = maxf(0.0, float(at.frame) - 1.0 + alpha)
	if def.unblockable:
		p.glow = &"danger"
		p.glow_amount = 1.0 if fr <= s + a else 0.0
	elif def.trail == &"ult":
		p.glow = &"ult"
		p.glow_amount = 1.0
	var k0: Dictionary = keys[0]
	var k1: Dictionary = keys[1]
	var k2: Dictionary = keys[2]
	var sheathes: bool = SHEATHED_DRAWS.has(def.anim)
	var sheathe_end: float = float(Fighter.CHARGE_CHECK_FRAME)
	if sheathes and (at.charging or fr <= sheathe_end):
		# the Iai: sheathe the blade at the left hip, and hold it there while
		# charging (the stance)
		var sheathe: Dictionary = _draw_key(SHEATHE)
		var t_in: float = 1.0 if at.charging else smooth(fr / sheathe_end)
		p.right = blend_hand(guard[0], sheathe["right"], t_in)
		p.left = blend_hand(guard[1], sheathe["left"], t_in)
		p.lean = lerpf(0.0, sheathe["lean"], t_in)
		p.crouch = lerpf(0.0, sheathe["crouch"], t_in)
		p.phase = &"sheathe"
		if at.charging:
			p.glow = &"charge"
			p.glow_amount = at.charge_frac
			p.phase = &"sheathed"
		return
	if at.charging:
		# a held heavy: hold the wind-up, trembling as it charges
		var tremble: float = sin(time * 40.0) * 0.012 * at.charge_frac
		p.right = (k0["right"] as Hand).copy()
		p.left = (k0["left"] as Hand).copy()
		p.right.pos.x += tremble
		if not def.unblockable:
			p.glow = &"charge"
			p.glow_amount = at.charge_frac
		p.lean = k0["lean"]
		p.crouch = k0["crouch"]
		p.phase = &"windup"
		return
	var from: Array[Hand] = [guard[0], guard[1]]
	var to: Array[Hand]
	var body_from: Array[float] = [0.0, 0.0, 0.0]
	var body_to: Array[float]
	var t: float
	var windup_end: float = s * 0.7
	var impact: float = s + 1.0
	var follow_end: float = s + a + r * 0.3
	if fr < windup_end and sheathes:
		# drawn from the sheathe: out in front for the first half, then up
		# into the wind-up
		var u: float = (fr - sheathe_end) / (windup_end - sheathe_end)
		var first_half: bool = u < 0.5
		var a_key: Dictionary = _draw_key(SHEATHE if first_half else DRAWN)
		var b_key: Dictionary = _draw_key(DRAWN) if first_half else k0
		from = [a_key["right"], a_key["left"]]
		body_from = [a_key["lean"], a_key["crouch"], a_key["spin"]]
		to = [b_key["right"], b_key["left"]]
		body_to = [b_key["lean"], b_key["crouch"], b_key["spin"]]
		t = smooth(u * 2.0 if first_half else u * 2.0 - 1.0)
		p.phase = &"draw"
	elif fr < windup_end:
		to = [k0["right"], k0["left"]]
		body_to = [k0["lean"], k0["crouch"], k0["spin"]]
		t = smooth(fr / windup_end)
		p.phase = &"windup"
	elif fr < impact:
		from = [k0["right"], k0["left"]]
		to = [k1["right"], k1["left"]]
		body_from = [k0["lean"], k0["crouch"], k0["spin"]]
		body_to = [k1["lean"], k1["crouch"], k1["spin"]]
		var u: float = (fr - windup_end) / maxf(0.001, impact - windup_end)
		t = u * u # accelerate into the blow
		p.phase = &"strike"
	elif fr < follow_end:
		from = [k1["right"], k1["left"]]
		to = [k2["right"], k2["left"]]
		body_from = [k1["lean"], k1["crouch"], k1["spin"]]
		body_to = [k2["lean"], k2["crouch"], k2["spin"]]
		var u: float = (fr - impact) / maxf(0.001, follow_end - impact)
		t = 1.0 - (1.0 - u) * (1.0 - u) # and decelerate out of it
		p.phase = &"follow"
	else:
		from = [k2["right"], k2["left"]]
		to = [guard[0], guard[1]]
		body_from = [k2["lean"], k2["crouch"], k2["spin"]]
		body_to = [0.0, 0.0, 0.0]
		var end: float = s + a + r
		t = smooth((fr - follow_end) / maxf(0.001, end - follow_end))
		p.phase = &"recover"
	p.right = blend_hand(from[0], to[0], t)
	p.left = blend_hand(from[1], to[1], t)
	p.lean = lerpf(body_from[0], body_to[0], t)
	p.crouch = lerpf(body_from[1], body_to[1], t)
	# a full spin ends where it began: unwind the turns while recovering
	var spin_to: float = body_to[2]
	if p.phase == &"recover":
		spin_to = 0.0
		body_from[2] = fmod(body_from[2], TAU)
	p.spin = lerpf(body_from[2], spin_to, t)
