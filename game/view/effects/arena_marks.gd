class_name ArenaMarks
extends Node3D
## The arena reacting to the fight, in the picture only (milestone-1 task
## 115, story 155; the owner's answers of Oct 8): marks on the stone that
## last the match, and the dust and sparks that make them.
##
## The rules send no blade-meets-stone event, and the Shrine's pillars stand
## outside the parapet beyond any sword, so the view finds the reactions
## itself from what it draws and the rules' events:
## - CUT: a blade's tip dipping to the floor (lower than TIP_FLOOR) in an
##   attack cuts the stone along its path while it stays down; a tip reaching
##   the parapet's face cuts it there and throws sparks (frame(), from each
##   fighter's posed blades);
## - GASH: a weapon stuck in the ground (weaponStuck);
## - GROOVE: Moonsplitter's vertical wave cuts a groove along its path over
##   the floor, its silver core glowing a moment (GROOVE_GLOW), and cracks
##   the floor as it goes; both waves throw sparks off and scorch the
##   parapet and every pillar they reach (frame(), the rules' waves);
## - SCORCH: the ultimates' bursts (ultBurst), the Tempest's lightning along
##   its path (ultLightning) and Breaker Palm (a hit with f_breaker): soot in
##   a ring of heat-bleached stone, its embers glowing a moment
##   (SCORCH_GLOW);
## - CRACK: only the heaviest: the stomp as its foot comes down, the leap
##   counter's landing, a knockdown's slam, the ultimates' bursts and
##   Moonsplitter's path;
## - dust (CombatEffects.puff()) for every fall, knockdown, landing and
##   stomp, and a stuck weapon.
## Each mark is one or more Decals (a groove or a crack counts as one); they
## last the match, and past the preset's cap (GraphicsPreset.arena_marks)
## the oldest fades out over FADE_FRAMES. They land only on the stone that
## carries LookPalette.GROUND_LAYER or MARKS_LAYER, never on a fighter.
## new_match() clears them. It reads the rules and the view and writes
## nothing back; with `enabled` off it draws nothing (the test that the
## rules don't care).

enum Kind { CUT, SCORCH, CRACK, GASH, GROOVE }

const KIND_NAMES: Array[StringName] = [&"cut", &"scorch", &"crack", &"gash", &"groove"]
## The layers a mark may land on: the floor and the arena's marked stone.
const MASK: int = LookPalette.GROUND_LAYER | LookPalette.MARKS_LAYER
## A blade's tip lower than this (m) is on the floor.
const TIP_FLOOR: float = 0.06
## How far past the parapet's face (m) a tip must reach to cut it.
const TIP_WALL: float = 0.02
## The longest a cut grows before a new one starts (m), and its width.
const CUT_MAX: float = 1.6
const CUT_WIDTH: float = 0.06
const GASH_SIZE := Vector2(0.16, 0.55)
## The groove along the vertical wave's path: its width, each piece's
## length, its glow at first and how long it takes to die (effect frames).
const GROOVE_WIDTH: float = 0.4
const GROOVE_PIECE: float = 2.0
const GROOVE_GLOW: float = 2.5
const GROOVE_GLOW_FRAMES: float = 150.0
## A scorch's embers: their glow at first, and how long it takes to die.
const SCORCH_GLOW: float = 2.0
const SCORCH_GLOW_FRAMES: float = 120.0
## Every how far (m) the vertical wave cracks the floor along its path.
const WAVE_CRACK_EVERY: float = 4.0
## How high on the parapet or a pillar the vertical wave strikes (m), and
## how far to either side of its line it reaches.
const VERTICAL_HIT_HEIGHT: float = 0.8
const VERTICAL_REACH: float = 0.95
## Across (m): cracks by blow, scorches by what made them, and the
## lightning's scorch's width.
const CRACK_SIZE: Dictionary[StringName, float] = {
	&"stomp": 2.2, &"leap": 2.6, &"knockdown": 1.8, &"ult": 3.4, &"wave": 1.6,
}
const SCORCH_SIZE: Dictionary[StringName, float] = {&"ult": 3.0, &"palm": 1.6}
## A wave's scorch on the parapet or a pillar: a streak along its cut
## (across it, along it; m), level for the horizontal wave, upright for the
## vertical one.
const STRIKE_SIZE := Vector2(0.45, 1.7)
const LIGHTNING_WIDTH: float = 0.9
## The oldest mark's fade once the cap is passed (effect clock frames).
const FADE_FRAMES: float = 45.0
## Dust by what raised it: count, size (m), life (frames), speed (m/s).
const DUST: Dictionary[StringName, Vector4] = {
	&"land": Vector4(5, 0.3, 34, 0.5), &"knockdown": Vector4(8, 0.42, 44, 0.6),
	&"stomp": Vector4(9, 0.45, 46, 0.8), &"leap": Vector4(9, 0.45, 46, 0.8),
	&"ko": Vector4(8, 0.42, 44, 0.6), &"ult": Vector4(14, 0.6, 60, 1.1),
	&"palm": Vector4(8, 0.45, 44, 0.8), &"stuck": Vector4(4, 0.25, 30, 0.4),
}
const DUST_COLOR := Color(0.46, 0.45, 0.47, 0.32)
## Sparks off stone: the wave's, and a blade's scrape on the parapet.
const WAVE_SPARKS: Dictionary = {"count": 22, "speed": 5.5, "spread": 60.0, "life": 18}
const SCRAPE_SPARKS: Dictionary = {"count": 6, "speed": 3.5, "spread": 45.0, "life": 12}
## How deep (m) a decal reaches through its surface: the floor's slabs sit
## within a few centimetres of it, the parapet's posts and rails stand back
## from its inner face and the pillars curve away.
const FLOOR_DEPTH: float = 0.3
const STONE_DEPTH: float = 0.9
## A stomp's foot is down when the fighter is shown this low (m) again.
const FOOT_DOWN: float = 0.02

## Whether the arena reacts at all.
var enabled: bool = true
## The preset's cap on marks.
var cap: int = 96
## The arena's surfaces (setup()): the floor's radius, the parapet's inner
## face and its top, its openings at the gates (angle from +Z toward +X and
## half-width, degrees) and the pillars (x, z, radius, height), standing on
## pillar_base.
var floor_radius: float = 15.0
var wall_radius: float = 15.075
var wall_top: float = 1.05
var gaps: PackedVector2Array = []
var pillars: PackedVector4Array = []
var pillar_base: float = 0.0

var _marks: Array[Mark] = []
## Per side and hand: the cut it is making (absent when lifted).
var _cutting: Dictionary[Vector2i, Mark] = {}
## Per wave: {laid, crack, groove, wall, pillars}.
var _waves: Dictionary = {}
## Per side: last frame's state, knockdown phase and how high it was shown,
## and whether its stomp's foot has come down.
var _last_state: Array[StringName] = []
var _last_phase: Array[StringName] = []
var _last_y: Array[float] = []
var _stomp_down: Array[bool] = []

static var _textures: Dictionary[StringName, Array] = {}


class Mark:
	var kind: int
	var nodes: Array[Decal] = []
	var born: float = 0.0
	## When it began to fade (INF while it stays).
	var fade_from: float = INF
	## Whether its glow (a groove's or a scorch's) is still dying down.
	var glowing: bool = true
	## A cut: where it starts, and the surface's normal.
	var start: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.UP


func _init() -> void:
	name = &"ArenaMarks"


## Takes the arena's surfaces from its reaction_surfaces() (the Shrine's
## parapet, gates and pillars), else from its ArenaDef (`def`), and makes the
## marks' textures now rather than at the first blow.
func setup(arena: Node) -> void:
	if arena != null and arena.has_method(&"reaction_surfaces"):
		var s: Dictionary = arena.call(&"reaction_surfaces")
		floor_radius = s.get("floor_radius", floor_radius)
		wall_radius = s.get("wall_radius", wall_radius)
		wall_top = s.get("wall_top", wall_top)
		gaps = s.get("gaps", PackedVector2Array())
		pillars = s.get("pillars", PackedVector4Array())
		pillar_base = s.get("pillar_base", 0.0)
	elif arena != null and arena.get(&"def") is ArenaDef:
		var def: ArenaDef = arena.get(&"def")
		floor_radius = def.wall_inner_radius()
		wall_radius = def.wall_inner_radius()
		wall_top = def.wall_height
		gaps = PackedVector2Array()
		pillars = PackedVector4Array()
	for kind: int in KIND_NAMES.size():
		_textures_of(kind)


func set_preset(preset: GraphicsPreset) -> void:
	cap = preset.arena_marks


## Clears every mark (a new match).
func new_match() -> void:
	for m: Mark in _marks:
		for d: Decal in m.nodes:
			d.queue_free()
	_marks.clear()
	_cutting.clear()
	_waves.clear()
	_last_state.clear()
	_last_phase.clear()
	_last_y.clear()
	_stomp_down.clear()


## How many marks there are (fading ones too).
func count() -> int:
	return _marks.size()


func count_of(kind: Kind) -> int:
	var n: int = 0
	for m: Mark in _marks:
		if m.kind == kind:
			n += 1
	return n


## Every decal of every mark of kind, oldest first.
func decals_of(kind: Kind) -> Array[Decal]:
	var out: Array[Decal] = []
	for m: Mark in _marks:
		if m.kind == kind:
			out.append_array(m.nodes)
	return out


# ------------------------------------------------------------------ the rules' events

## Takes a rules event on the effects' clock `t` (CombatEffects.clock());
## at_of(side) is where side's fighter is shown.
func on_event(e: Dictionary, at_of: Callable, effects: CombatEffects, t: float) -> void:
	if not enabled:
		return
	var seed: int = int(t * 977.0) + _marks.size() * 31
	match e.get("t", &""):
		&"weaponStuck":
			var at: Vector3 = _vector(e["pos"])
			_floor_mark(Kind.GASH, at, GASH_SIZE, _turn(seed), t)
			_dust(effects, at, &"stuck", t, seed)
		&"ultBurst":
			if e.has("pos"):
				var at: Vector3 = _vector(e["pos"])
				_floor_mark(Kind.SCORCH, at, Vector2.ONE * SCORCH_SIZE[&"ult"], _turn(seed), t)
				_crack(at, CRACK_SIZE[&"ult"], t, seed + 1)
				_dust(effects, at, &"ult", t, seed)
		&"ultLightning":
			var a: Vector3 = _vector(e["from"])
			var b: Vector3 = _vector(e["to"])
			var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
			if along.length() > 0.1:
				_floor_mark(Kind.SCORCH, (a + b) * 0.5, Vector2(LIGHTNING_WIDTH, along.length() + LIGHTNING_WIDTH),
					atan2(along.x, along.z), t)
		&"hit":
			if e.get("attack", &"") == &"f_breaker" and at_of.is_valid():
				var at: Vector3 = at_of.call(int(e["target"]))
				_floor_mark(Kind.SCORCH, at, Vector2.ONE * SCORCH_SIZE[&"palm"], _turn(seed), t)
				_dust(effects, at, &"palm", t, seed)
		&"ko":
			if int(e.get("loser", -1)) >= 0 and at_of.is_valid():
				_dust(effects, at_of.call(int(e["loser"])), &"ko", t, seed)
	_trim(t)


# ------------------------------------------------------------------ each drawn frame

## Each drawn frame: `sides` as FloorStirrer takes them ({"at", "state",
## "phase", "blades"}), the rules' waves shown `alpha` of the way to their
## next step, the effects and their clock `t`.
func frame(sides: Array[Dictionary], waves: Array[SlashWave], alpha: float, effects: CombatEffects, t: float) -> void:
	if not enabled:
		return
	while _last_state.size() < sides.size():
		_last_state.append(&"")
		_last_phase.append(&"")
		_last_y.append(0.0)
		_stomp_down.append(true)
	for i: int in sides.size():
		_fighter(i, sides[i], effects, t)
	_follow_waves(waves, alpha, effects, t)
	_trim(t)


## Glows the grooves down and fades the marks past the cap, on the effects'
## clock `t`.
func update(t: float) -> void:
	var gone: Array[Mark] = []
	for m: Mark in _marks:
		if m.glowing and (m.kind == Kind.GROOVE or m.kind == Kind.SCORCH):
			var glow: float = glow_at(m.kind, t - m.born)
			for d: Decal in m.nodes:
				d.emission_energy = glow
			# a groove still being cut keeps glowing with its new pieces
			m.glowing = glow > 0.0 or t < m.born
		if m.fade_from < INF:
			var a: float = clampf(1.0 - (t - m.fade_from) / FADE_FRAMES, 0.0, 1.0)
			for d: Decal in m.nodes:
				d.modulate.a = a
			if a <= 0.0:
				gone.append(m)
	for m: Mark in gone:
		for d: Decal in m.nodes:
			d.queue_free()
		_marks.erase(m)


func _fighter(i: int, side: Dictionary, effects: CombatEffects, t: float) -> void:
	var at: Vector3 = side["at"]
	var floor_at := Vector3(at.x, 0.0, at.z)
	var state: StringName = side.get("state", &"free")
	var phase: StringName = side.get("phase", &"")
	var seed: int = int(t * 131.0) + i * 17
	var was: StringName = _last_state[i]
	if state != was:
		if state == &"land":
			_dust(effects, floor_at, &"land", t, seed)
		if was == &"leap":
			_crack(floor_at, CRACK_SIZE[&"leap"], t, seed)
			_dust(effects, floor_at, &"leap", t, seed)
		if state == &"stomp":
			_stomp_down[i] = false
		elif was == &"stomp" and not _stomp_down[i]:
			_stomp(i, floor_at, effects, t, seed)
	if state == &"stomp" and not _stomp_down[i] and _last_y[i] > FOOT_DOWN and at.y <= FOOT_DOWN:
		_stomp(i, floor_at, effects, t, seed)
	if state == &"knockdown" and phase == &"ground" and _last_phase[i] == &"fall":
		_crack(floor_at, CRACK_SIZE[&"knockdown"], t, seed)
		_dust(effects, floor_at, &"knockdown", t, seed)
	_last_state[i] = state
	_last_phase[i] = phase
	_last_y[i] = at.y
	var blades: Array = side.get("blades", [])
	for hand: int in blades.size():
		_blade(Vector2i(i, hand), blades[hand], state == &"attack", effects, t)


func _stomp(i: int, at: Vector3, effects: CombatEffects, t: float, seed: int) -> void:
	_stomp_down[i] = true
	_crack(at, CRACK_SIZE[&"stomp"], t, seed)
	_dust(effects, at, &"stomp", t, seed)


# ------------------------------------------------------------------ blades

func _blade(key: Vector2i, blade: Variant, attacking: bool, effects: CombatEffects, t: float) -> void:
	if not attacking or not blade is PackedVector3Array or (blade as PackedVector3Array).size() < 2:
		_cutting.erase(key)
		return
	var tip: Vector3 = (blade as PackedVector3Array)[1]
	var r: float = Vector2(tip.x, tip.z).length()
	var on_floor: bool = tip.y <= TIP_FLOOR and r < wall_radius
	var on_wall: bool = not on_floor and r >= wall_radius + TIP_WALL and tip.y > 0.0 and tip.y < wall_top \
		and not _in_gap(tip)
	if not on_floor and not on_wall:
		_cutting.erase(key)
		return
	var normal: Vector3 = Vector3.UP if on_floor else -Vector3(tip.x, 0.0, tip.z).normalized()
	var at: Vector3 = Vector3(tip.x, 0.0, tip.z) if on_floor else _on_wall(tip)
	var cut: Mark = _cutting.get(key, null)
	if cut == null or cut.normal.dot(normal) < 0.9 or cut.start.distance_to(at) > CUT_MAX:
		cut = _new_mark(Kind.CUT, t)
		cut.start = at
		cut.normal = normal
		cut.nodes.append(_decal(Kind.CUT, at, normal, Vector3.UP.cross(normal) if on_wall else Vector3.FORWARD, Vector2(CUT_WIDTH, 0.05)))
		_cutting[key] = cut
		if on_wall:
			effects.sparks(at, normal, SCRAPE_SPARKS, t, int(t * 271.0) + key.x * 5 + key.y)
	_stretch(cut.nodes[0], cut.start, at, normal)


## The point on the parapet's inner face nearest p.
func _on_wall(p: Vector3) -> Vector3:
	var level: Vector2 = Vector2(p.x, p.z).normalized() * wall_radius
	return Vector3(level.x, clampf(p.y, 0.05, wall_top - 0.05), level.y)


## Whether p's bearing is in one of the parapet's gate openings.
func _in_gap(p: Vector3) -> bool:
	var a: float = rad_to_deg(atan2(p.x, p.z))
	for g: Vector2 in gaps:
		if absf(wrapf(a - g.x, -180.0, 180.0)) < g.y:
			return true
	return false


# ------------------------------------------------------------------ Moonsplitter's waves

func _follow_waves(waves: Array[SlashWave], alpha: float, effects: CombatEffects, t: float) -> void:
	var live: Dictionary = {}
	for w: SlashWave in waves:
		live[w] = true
		if not _waves.has(w):
			_waves[w] = {"laid": 0.0, "crack": WAVE_CRACK_EVERY * 0.5, "groove": null, "wall": false, "pillars": {}}
		var track: Dictionary = _waves[w]
		var s: float = MoonWave.shown_s(w, alpha)
		var origin := Vector3(w.ox, 0.0, w.oz)
		var ahead := Vector3(w.dx, 0.0, w.dz).normalized()
		var vertical: bool = w.kind == &"vertical"
		if vertical:
			_groove(track, origin, ahead, s, t)
		var height: float = VERTICAL_HIT_HEIGHT if vertical else MoonWave.KNEE + MoonWave.BAND * 0.5
		var front: Vector3 = origin + ahead * s
		if not track["wall"] and Vector2(front.x, front.z).length() >= wall_radius:
			track["wall"] = true
			var hit: Vector3 = crossing(origin, ahead, wall_radius)
			if hit != Vector3.INF and not _in_gap(hit):
				var normal: Vector3 = -Vector3(hit.x, 0.0, hit.z).normalized()
				_strike(Vector3(hit.x, minf(height, wall_top - 0.15), hit.z), normal, vertical, effects, t)
		var met: Dictionary = track["pillars"]
		for k: int in pillars.size():
			if met.has(k):
				continue
			var p: Vector4 = pillars[k]
			var centre := Vector3(p.x, 0.0, p.y)
			var along: float = (centre - origin).dot(ahead)
			if along < 0.0 or along - p.z > s:
				continue
			var off: float = absf((centre - origin).dot(Vector3.UP.cross(ahead)))
			if off > (VERTICAL_REACH + p.z if vertical else MoonWave.SPAN * 0.5):
				continue
			met[k] = true
			var face: Vector3 = centre - ahead * p.z
			_strike(Vector3(face.x, pillar_base + minf(height, p.w * 0.8), face.z), -ahead, vertical, effects, t)
	for w: Variant in _waves.keys():
		if not live.has(w):
			_waves.erase(w)


## The vertical wave's groove and cracks over the floor, up to s along it.
func _groove(track: Dictionary, origin: Vector3, ahead: Vector3, s: float, t: float) -> void:
	while float(track["laid"]) + GROOVE_PIECE <= s:
		var a: Vector3 = origin + ahead * float(track["laid"])
		var b: Vector3 = a + ahead * GROOVE_PIECE
		track["laid"] = float(track["laid"]) + GROOVE_PIECE
		if Vector2(b.x, b.z).length() > floor_radius:
			continue
		if track["groove"] == null:
			track["groove"] = _new_mark(Kind.GROOVE, t)
		var groove: Mark = track["groove"]
		groove.nodes.append(_decal(Kind.GROOVE, (a + b) * 0.5, Vector3.UP, ahead, Vector2(GROOVE_WIDTH, GROOVE_PIECE)))
	while float(track["crack"]) <= s:
		var c: Vector3 = origin + ahead * float(track["crack"])
		track["crack"] = float(track["crack"]) + WAVE_CRACK_EVERY
		if Vector2(c.x, c.z).length() + CRACK_SIZE[&"wave"] * 0.5 < floor_radius:
			_crack(c, CRACK_SIZE[&"wave"], t, int(t * 53.0) + int(track["crack"]))


## A wave meeting stone at `at` (its face's normal): sparks and a scorch
## streaked along its cut.
func _strike(at: Vector3, normal: Vector3, vertical: bool, effects: CombatEffects, t: float) -> void:
	effects.sparks(at, normal, WAVE_SPARKS, t, int(t * 311.0) + _marks.size())
	var m: Mark = _new_mark(Kind.SCORCH, t)
	var along: Vector3 = Vector3.UP if vertical else Vector3.UP.cross(normal)
	m.nodes.append(_decal(Kind.SCORCH, at, normal, along, STRIKE_SIZE))


## How brightly a groove's core or a scorch's embers glow `age` effect
## frames after they were made (0 for the other kinds).
static func glow_at(kind: int, age: float) -> float:
	match kind:
		Kind.GROOVE:
			return GROOVE_GLOW * clampf(1.0 - age / GROOVE_GLOW_FRAMES, 0.0, 1.0)
		Kind.SCORCH:
			return SCORCH_GLOW * clampf(1.0 - age / SCORCH_GLOW_FRAMES, 0.0, 1.0)
	return 0.0


## Where the level ray from origin along ahead leaves the circle of radius r
## round the arena's centre, or Vector3.INF.
static func crossing(origin: Vector3, ahead: Vector3, r: float) -> Vector3:
	var o := Vector2(origin.x, origin.z)
	var d := Vector2(ahead.x, ahead.z).normalized()
	var b: float = o.dot(d)
	var disc: float = b * b - (o.length_squared() - r * r)
	if disc < 0.0:
		return Vector3.INF
	var p: Vector2 = o + d * (-b + sqrt(disc))
	return Vector3(p.x, 0.0, p.y)


# ------------------------------------------------------------------ marks

func _new_mark(kind: Kind, t: float) -> Mark:
	var m := Mark.new()
	m.kind = kind
	m.born = t
	_marks.append(m)
	return m


func _floor_mark(kind: Kind, at: Vector3, size: Vector2, yaw: float, t: float) -> void:
	if Vector2(at.x, at.z).length() > floor_radius:
		return
	var m: Mark = _new_mark(kind, t)
	m.nodes.append(_decal(kind, Vector3(at.x, 0.0, at.z), Vector3.UP, Vector3(sin(yaw), 0.0, cos(yaw)), size))


func _crack(at: Vector3, size: float, t: float, seed: int) -> void:
	_floor_mark(Kind.CRACK, at, Vector2.ONE * size, _turn(seed), t)


func _dust(effects: CombatEffects, at: Vector3, kind: StringName, t: float, seed: int) -> void:
	var d: Vector4 = DUST[kind]
	effects.puff(Vector3(at.x, 0.08, at.z), {"count": int(d.x), "size": d.y, "life": d.z, "speed": d.w, "color": DUST_COLOR}, t, seed)


## Past the cap, the oldest staying marks begin to fade from `t` (never a
## cut still being made).
func _trim(t: float) -> void:
	var staying: int = 0
	for m: Mark in _marks:
		if m.fade_from == INF:
			staying += 1
	for m: Mark in _marks:
		if staying <= cap:
			return
		if m.fade_from == INF and not _cutting.values().has(m):
			m.fade_from = t
			staying -= 1


## A decal of kind lying on the surface at `at` whose outward normal is
## `normal`, its texture's length along `along`, size (across, along).
func _decal(kind: Kind, at: Vector3, normal: Vector3, along: Vector3, size: Vector2) -> Decal:
	var d := Decal.new()
	var tex: Array = _textures_of(kind)
	d.texture_albedo = tex[0]
	d.texture_normal = tex[1]
	if tex[2] != null:
		d.texture_emission = tex[2]
		d.emission_energy = glow_at(kind, 0.0)
	d.cull_mask = MASK
	d.albedo_mix = 1.0
	d.upper_fade = 0.15
	d.lower_fade = 0.15
	d.normal_fade = 0.4
	add_child(d)
	_place(d, at, normal, along, size)
	return d


## Lays decal d on the surface at `at` (outward normal `normal`), its V along
## `along`, size (across, along).
static func _place(d: Decal, at: Vector3, normal: Vector3, along: Vector3, size: Vector2) -> void:
	var y: Vector3 = normal.normalized()
	var z: Vector3 = along - y * along.dot(y)
	z = z.normalized() if z.length() > 0.001 else y.cross(Vector3.RIGHT).normalized()
	var x: Vector3 = y.cross(z).normalized()
	d.global_transform = Transform3D(Basis(x, y, z), at)
	d.size = Vector3(size.x, FLOOR_DEPTH if y.y > 0.5 else STONE_DEPTH, size.y)


## Stretches cut decal d from `from` to `to` on the surface (normal).
static func _stretch(d: Decal, from: Vector3, to: Vector3, normal: Vector3) -> void:
	var along: Vector3 = to - from
	var keep: Vector3 = d.global_basis.z
	_place(d, (from + to) * 0.5, normal, along if along.length() > 0.01 else keep, Vector2(CUT_WIDTH, maxf(along.length(), 0.05)))


static func _turn(seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng.randf() * TAU


static func _vector(d: Variant) -> Vector3:
	if d is Vector3:
		return d
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))


## [albedo, normal, emission or null] for kind, made once a run.
static func _textures_of(kind: int) -> Array:
	var key: StringName = KIND_NAMES[kind]
	if not _textures.has(key):
		_textures[key] = ArenaMarkTextures.make(key)
	return _textures[key]
