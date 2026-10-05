class_name SwingDebugView
extends Node3D
## Debug view of blade sweeps and hurt capsules (task 7.15), drawn over the
## match so a swing can be checked against what it hits:
## - each fighter's hurt capsule, as a wire capsule;
## - each striking blade segment of an attack, where the rules hold it now;
## - the swept quad of each striking track on every tick that checks for hits
##   (World.checks_frame(), the active frames), from the blade at the last
##   tick to this one, kept for about a second;
## - a marker where each hit, block or parry started (its event's pos, where
##   the contact flash appears), and for a whiff at the tip of the attacker's
##   blade, coloured by outcome.
## Everything is drawn where the rules have it, not blended between steps,
## and on top of the bodies.
##
## It only reads the rules. MatchView adds it when its swing_debug flag is
## on, with F3 in a debug build, or with --swing-debug on the command line
## (npm run play -- --swing-debug), and it follows the host's steps and
## events. record() and on_event() take the World, so a test can drive it
## without a host.

## How long quads and markers stay, in world frames: about a second. The
## world's frame stands still through hit-stop and pause, so they hold
## through both.
const KEEP_FRAMES: int = 60
const CAPSULE_COLOR: Color = Color(0.35, 0.85, 1.0)
const BLADE_COLOR: Color = Color(1.0, 1.0, 1.0)
## The swept quads' colour per side.
const SWEEP_COLORS: Array[Color] = [Color(1.0, 0.55, 0.15), Color(0.8, 0.45, 1.0)]
const MARKER_COLORS: Dictionary[StringName, Color] = {
	&"hit": Color(1.0, 0.15, 0.1),
	&"block": Color(1.0, 0.85, 0.15),
	&"parry": Color(0.3, 1.0, 1.0),
	&"whiff": Color(0.65, 0.65, 0.65),
}
## Half the size of a marker's cross (m).
const MARKER_SIZE: float = 0.07
## The segments of a ring of a wire capsule, and of an arc over its end.
const RING: int = 16
const HALF_RING: int = 8

## The swept quads kept, oldest first: { "side", "frame" (the attack frame),
## "born" (the world frame), "corners" (PackedVector3Array: the last tick's
## base and tip, then this tick's tip and base) }.
var quads: Array[Dictionary] = []
## The outcome markers kept, oldest first: { "kind" (hit, block, parry or
## whiff), "at" (Vector3), "born" (the world frame) }.
var markers: Array[Dictionary] = []
## What redraw() builds: the quads filled, then the lines.
var mesh: ArrayMesh = ArrayMesh.new()

var host: MatchHost
## The world last recorded, drawn by redraw().
var _world: World
## Each side's attack as last recorded, and its frame then: an attack that
## ends in a step (parried, or its fighter hit) is gone from its fighter after
## the step, but its state still holds that tick's frame and blades.
var _atk: Array[AttackState] = [null, null]
var _atk_frame: Array[int] = [-1, -1]
var _fill: StandardMaterial3D
var _lines: StandardMaterial3D
## The vertices and colours of the surface redraw() is building.
var _verts: PackedVector3Array = PackedVector3Array()
var _colors: PackedColorArray = PackedColorArray()


func _init() -> void:
	name = "SwingDebug"
	_fill = _material(true)
	_lines = _material(false)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## An unshaded material coloured by vertex, drawn over everything: the quads
## see-through and two-sided.
static func _material(fill: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 10
	if fill:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Follows `p_host`: records each step and marks its outcome events.
func bind(p_host: MatchHost) -> void:
	_unbind()
	host = p_host
	host.stepped.connect(_on_stepped)
	host.sim_event.connect(_on_sim_event)


func _unbind() -> void:
	if host == null:
		return
	if host.stepped.is_connected(_on_stepped):
		host.stepped.disconnect(_on_stepped)
	if host.sim_event.is_connected(_on_sim_event):
		host.sim_event.disconnect(_on_sim_event)
	host = null


func _exit_tree() -> void:
	_unbind()


func _process(_delta: float) -> void:
	redraw()


func _on_stepped(_step: int) -> void:
	record(host.world)


func _on_sim_event(e: Dictionary) -> void:
	on_event(e, host.world)


## Keeps the swept quads of the step `world` just took: for each fighter
## whose attack moved on to a frame that checks for hits, one per striking
## track, from its blade at the last tick to this one. Call it after every
## step; a step that didn't move the world (hit-stop, pause) adds nothing.
func record(world: World) -> void:
	_follow(world)
	for i: int in world.fighters.size():
		var f: Fighter = world.fighters[i]
		var seen: AttackState = _atk[i]
		if seen != null and seen.frame != _atk_frame[i]:
			_keep(i, seen, world.frame)
		if f.atk != null and f.atk != seen:
			_keep(i, f.atk, world.frame)
		_atk[i] = f.atk
		_atk_frame[i] = f.atk.frame if f.atk != null else -1
	_expire(world.frame)


func _keep(side: int, atk: AttackState, now: int) -> void:
	if atk.charging or not World.checks_frame(atk.def, atk.frame):
		return
	for b: BladeSegment in atk.blades:
		quads.append({
			"side": side,
			"frame": atk.frame,
			"born": now,
			"corners": PackedVector3Array([_v(b.prev_base), _v(b.prev_tip), _v(b.tip), _v(b.base)]),
		})


## Marks an outcome event of `world`: a hit, block or parry where it started
## (its pos), a whiff at the tip of the attacker's first striking blade (none
## for a move without a swing). A new round clears everything.
func on_event(e: Dictionary, world: World) -> void:
	_follow(world)
	var kind: StringName = e["t"]
	match kind:
		&"hit", &"block", &"parry":
			var p: Dictionary = e["pos"]
			markers.append({"kind": kind, "at": Vector3(float(p["x"]), float(p["y"]), float(p["z"])), "born": world.frame})
		&"whiff":
			var blades: Array[BladeSegment] = world.fighters[int(e["f"])].blade_segments()
			if not blades.is_empty():
				markers.append({"kind": kind, "at": _v(blades[0].tip), "born": world.frame})
		&"roundStart":
			clear()


## Forgets every quad, marker and attack seen.
func clear() -> void:
	quads.clear()
	markers.clear()
	_atk.fill(null)
	_atk_frame.fill(-1)


## Starts over on a world other than the last one (a new match).
func _follow(world: World) -> void:
	if world != _world:
		clear()
		_world = world


func _expire(now: int) -> void:
	var q_kept: Array[Dictionary] = []
	for q: Dictionary in quads:
		if now - int(q["born"]) < KEEP_FRAMES:
			q_kept.append(q)
	quads = q_kept
	var m_kept: Array[Dictionary] = []
	for m: Dictionary in markers:
		if now - int(m["born"]) < KEEP_FRAMES:
			m_kept.append(m)
	markers = m_kept


## Builds the picture of the world last recorded: the quads filled and fading
## with age, then the capsules, the quads' edges, the blades and the markers
## as lines.
func redraw() -> void:
	mesh.clear_surfaces()
	if _world == null:
		return
	var now: int = _world.frame
	for q: Dictionary in quads:
		var c: Color = SWEEP_COLORS[int(q["side"]) % SWEEP_COLORS.size()]
		c.a = 0.4 * (1.0 - float(now - int(q["born"])) / float(KEEP_FRAMES))
		var k: PackedVector3Array = q["corners"]
		for i: int in [0, 1, 2, 0, 2, 3]:
			_add(k[i], c)
	_surface(Mesh.PRIMITIVE_TRIANGLES, _fill)
	for f: Fighter in _world.fighters:
		_capsule(f.hurt_capsule())
	for q: Dictionary in quads:
		var k: PackedVector3Array = q["corners"]
		var c: Color = SWEEP_COLORS[int(q["side"]) % SWEEP_COLORS.size()]
		for i: int in 4:
			_line(k[i], k[(i + 1) % 4], c)
	for f: Fighter in _world.fighters:
		for b: BladeSegment in f.blade_segments():
			_line(_v(b.base), _v(b.tip), BLADE_COLOR)
	for m: Dictionary in markers:
		var at: Vector3 = m["at"]
		var c: Color = MARKER_COLORS[m["kind"]]
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			_line(at - axis * MARKER_SIZE, at + axis * MARKER_SIZE, c)
	_surface(Mesh.PRIMITIVE_LINES, _lines)


## Adds the vertices gathered so far to the mesh as a surface of `primitive`
## in `material`, unless there are none.
func _surface(primitive: Mesh.PrimitiveType, material: Material) -> void:
	if _verts.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	mesh.add_surface_from_arrays(primitive, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	_verts = PackedVector3Array()
	_colors = PackedColorArray()


func _add(at: Vector3, color: Color) -> void:
	_verts.append(at)
	_colors.append(color)


## A wire capsule: a ring round each end of its axis, four lines down its
## sides and two arcs over each end.
func _capsule(c: SimCapsule) -> void:
	var a: Vector3 = _v(c.a)
	var b: Vector3 = _v(c.b)
	var r: float = c.radius
	for i: int in RING:
		var t0: float = TAU * i / RING
		var t1: float = TAU * (i + 1) / RING
		var p0: Vector3 = Vector3(cos(t0), 0.0, sin(t0)) * r
		var p1: Vector3 = Vector3(cos(t1), 0.0, sin(t1)) * r
		_line(a + p0, a + p1, CAPSULE_COLOR)
		_line(b + p0, b + p1, CAPSULE_COLOR)
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		_line(a + side * r, b + side * r, CAPSULE_COLOR)
	for across: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		for i: int in HALF_RING:
			var t0: float = PI * i / HALF_RING
			var t1: float = PI * (i + 1) / HALF_RING
			_line(b + (across * cos(t0) + Vector3.UP * sin(t0)) * r, b + (across * cos(t1) + Vector3.UP * sin(t1)) * r, CAPSULE_COLOR)
			_line(a + (across * cos(t0) - Vector3.UP * sin(t0)) * r, a + (across * cos(t1) - Vector3.UP * sin(t1)) * r, CAPSULE_COLOR)


func _line(from: Vector3, to: Vector3, color: Color) -> void:
	_add(from, color)
	_add(to, color)


## A rules point where Godot draws it: the rules' world axes are Godot's.
static func _v(p: V3) -> Vector3:
	return Vector3(p.x, p.y, p.z)
