class_name SimHelpers
extends RefCounted
## Port of tests/helpers.ts: the test harness for the rule tests.
##
## Port notes:
## - btn and move are variadic like the TS: SimHelpers.btn(Btn.BLOCK, Btn.HEAVY).
## - Per-player inputs are Callables taking the step index and returning a
##   RawInput; a null Callable means idle.
## - Rec.find returns an empty Dictionary where the TS returns undefined.
## - make_world remembers every world it builds; call dispose_all() (each test
##   file does in after_each) to break the worlds' reference cycles. track()
##   adds a world built some other way.
## - runUntil is not ported: no test uses it.

## The step a Katana light pressed on step 0 lands on, from make_world()'s
## 2.2 m or nearer: Right Cut, re-keyed (milestone-1 task 31), landing on its
## first active frame (startup 28), world frame 30 (a step later until the
## export's one-frame hold was fixed).
const LIGHT_LANDS: int = 29

static var _worlds: Array[World] = []
## The grip make_world() puts a gripped weapon's fighters in: two hands,
## whose string is still today's four lights (Right Cut first), which the
## rule tests are written round, since KE task 11 keyed the one-handed
## grip's own hits 1 and 2. A test of the other grip sets it on the
## fighter, or this before building its world (&"" leaves each weapon's
## first grip, the one rounds start in); dispose_all() puts it back.
const DEFAULT_GRIP: StringName = WeaponGrip.TWO_HANDED
static var grip: StringName = DEFAULT_GRIP


## abilities: { "a"?: [id, id], "b"?: [id, id] }
static func make_world(
	w1: WeaponDef = Moves.KATANA,
	w2: WeaponDef = Moves.KATANA,
	gap: float = 2.2,
	abilities: Dictionary = {},
) -> World:
	var W: World = World.new(
		FighterConfig.make(w1, abilities.get("a", [])),
		FighterConfig.make(w2, abilities.get("b", [])),
		7,
	)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	a.pos = V3.make(0.0, 0.0, -gap / 2.0)
	b.pos = V3.make(0.0, 0.0, gap / 2.0)
	a.yaw = 0.0
	b.yaw = PI
	a.set_state(&"free")
	b.set_state(&"free")
	# mid-round, in guard: neither Greatsword is on the shoulder (task 15)
	a.shouldered = false
	b.shouldered = false
	for f: Fighter in [a, b]:
		if grip != &"" and f.weapon != null and f.weapon.grip(grip) != null:
			f.grip = grip
	return track(W)


## Remembers a world for dispose_all().
static func track(W: World) -> World:
	_worlds.append(W)
	return W


## Disposes every world made or tracked since the last call, and puts
## make_world()'s grip back.
static func dispose_all() -> void:
	for W: World in _worlds:
		W.dispose()
	_worlds.clear()
	grip = DEFAULT_GRIP


## btn(...B)
static func btn(...bs: Array) -> RawInput:
	var mask: int = 0
	for b: Variant in bs:
		mask |= 1 << int(b)
	return RawInput.make(0.0, 0.0, mask)


## move(mx, my, ...B)
static func move(mx: float, my: float, ...bs: Array) -> RawInput:
	var mask: int = 0
	for b: Variant in bs:
		mask |= 1 << int(b)
	return RawInput.make(mx, my, mask)


static func idle() -> RawInput:
	return RawInput.empty()


## Collected events across steps.
class Rec:
	var events: Array[Dictionary] = []

	func collect(W: World) -> void:
		events.append_array(W.drain_events())

	func has(t: StringName) -> bool:
		for e: Dictionary in events:
			if e["t"] == t:
				return true
		return false

	## The first event of type t, or {} (TS undefined).
	func find(t: StringName) -> Dictionary:
		for e: Dictionary in events:
			if e["t"] == t:
				return e
		return {}

	func count(t: StringName) -> int:
		var n: int = 0
		for e: Dictionary in events:
			if e["t"] == t:
				n += 1
		return n

	## events.filter((e) => e.t === t)
	func all(t: StringName) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for e: Dictionary in events:
			if e["t"] == t:
				out.append(e)
		return out


## Step the world with per-player input functions of the step index.
static func run(W: World, n: int, p0: Callable = Callable(), p1: Callable = Callable(), rec: Rec = null) -> void:
	for i: int in n:
		var in0: RawInput = idle() if p0.is_null() else p0.call(i)
		var in1: RawInput = idle() if p1.is_null() else p1.call(i)
		W.step([in0, in1])
		if rec != null:
			rec.collect(W)


## Press a button on frame `at` only (a tap).
static func tap_at(at: int, b: int) -> Callable:
	return func(i: int) -> RawInput: return btn(b) if i == at else idle()
