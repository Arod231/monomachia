extends Node
## The arena after a long match (milestone-1 task 115's check): plays the
## worst-case replay (WorstCase.PATH, a whole match with Moonsplitter and
## Breaker Palm) through the match view frame by frame, so the fight marks
## the Shrine as it would be shown, then looks at what it left under the
## chosen preset:
## - overview: the whole floor from above the parapet;
## - floor: low over the floor where the marks lie thickest;
## - groove: along Moonsplitter's groove; when the match made none, a
##   vertical wave is staged after it, from side 0 toward side 1, through the
##   marks alone (ArenaMarks.frame(), as the view would hand it the rules'
##   wave);
## - groove_glow: the same as it is cut, its silver core still glowing;
## - wall: at a mark on the parapet or a pillar (a cut or a scorch);
## - cut, gash, crack, scorch: close to the first mark of that kind on the
##   floor.
## Live (--live=<step>, for `npm run clip`): the match plays to that step
## unseen, then on at its own speed from the match's own camera. The steps of
## the big moments (Moonsplitter's waves, the bursts, knockdowns, stuck
## weapons) are printed to pick it by.
##
## With --duel=<weapon>,<weapon> a seeded Hard computer duel (the Hunter
## against the Rogue) plays --frames=<n> frames in place of the replay. Prints
## how many marks of each kind the match left. Shoot one with
##   npm run shots -- res://tools/shot_scenes/arena_marks.tscn shots/<name>.png 30 --view=<view> [--preset=<id>] [--duel=<a>,<b> --frames=<n>]

@export var view: StringName = &"overview"
@export var preset_id: StringName = &""
@export var settle_frames: int = 30
## A seeded computer duel (--duel=<weapon>,<weapon> --frames=<n>) in place of
## the replay, when set.
@export var duel: PackedStringArray = []
@export var duel_frames: int = 10800
## Play on live from this step (-1: a still).
@export var live_from: int = -1

var host: MatchHost
var _ready_flag: bool = false


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--view="):
			view = StringName(a.trim_prefix("--view="))
		elif a.begins_with("--preset="):
			preset_id = StringName(a.trim_prefix("--preset="))
		elif a.begins_with("--duel="):
			duel = a.trim_prefix("--duel=").split(",")
		elif a.begins_with("--frames="):
			duel_frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--live="):
			live_from = int(a.trim_prefix("--live="))
	var preset: GraphicsPreset = GraphicsPreset.load_id(preset_id) if preset_id != &"" else GameServices.graphics_preset()
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child(host)
	var log_in: InputLog = InputLog.load_file(WorstCase.PATH)
	var steps: int = log_in.step_count()
	if duel.size() == 2:
		host.start(MatchConfig.make(MatchConfig.DUEL, MatchSide.computer(&"hunter", StringName(duel[0]), 0, &"hard"),
			MatchSide.computer(&"rogue", StringName(duel[1]), 1, &"hard"), 31, &"moonlit_shrine"))
		steps = duel_frames
	else:
		host.start_replay(log_in)
	GraphicsApplier.apply(preset, host, get_viewport())
	var view_node := host.get_node("View") as MatchView
	view_node.arena_marks.set_preset(preset)
	var moments: PackedStringArray = []
	host.sim_event.connect(func(e: Dictionary) -> void:
		if [&"ultWave", &"ultBurst", &"ultLightning", &"knockdown", &"weaponStuck", &"counter", &"recallBurst"].has(e["t"]):
			moments.append("%s@%d" % [e["t"], host.step_count]))
	if live_from >= 0:
		steps = mini(steps, live_from)
	while host.step_count < steps:
		host.step(1)
		view_node.render(1.0 / 60.0)
	print("arena_marks_shot: moments ", " ".join(moments))
	if live_from >= 0:
		host.auto_run = true
		_ready_flag = true
		return
	var marks: ArenaMarks = view_node.arena_marks
	if (view == &"groove" or view == &"groove_glow") and marks.count_of(ArenaMarks.Kind.GROOVE) == 0:
		# long since glowing, unless the glow is the shot
		_stage_wave(view_node, 0.0 if view == &"groove_glow" else -2.0 * ArenaMarks.GROOVE_GLOW_FRAMES)
	var counts: PackedStringArray = []
	for kind: int in ArenaMarks.KIND_NAMES.size():
		counts.append("%s %d" % [ArenaMarks.KIND_NAMES[kind], marks.count_of(kind)])
	print("arena_marks_shot: %d marks after %d steps: %s" % [marks.count(), host.step_count, ", ".join(counts)])
	var cam := Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	_frame(cam, marks)
	cam.make_current()
	var arena: Node = view_node.arena
	if arena != null and arena.has_method(&"cull_below_deck"):
		arena.call(&"cull_below_deck", cam)
	_ready_flag = true


func _frame(cam: Camera3D, marks: ArenaMarks) -> void:
	match view:
		&"floor":
			var at: Vector3 = _thickest(marks)
			var back: Vector3 = (Vector3(at.x, 0.0, at.z) if at.length() > 1.0 else Vector3.BACK).normalized()
			var eye: Vector3 = at - back * 3.4 + Vector3.UP * 1.9
			cam.fov = 55.0
			cam.look_at_from_position(eye, at, Vector3.UP)
		&"groove", &"groove_glow":
			var pieces: Array[Decal] = marks.decals_of(ArenaMarks.Kind.GROOVE)
			if pieces.is_empty():
				push_warning("arena_marks_shot: the match left no groove")
				_overview(cam)
				return
			var a: Vector3 = pieces[0].global_position
			var b: Vector3 = pieces[pieces.size() - 1].global_position
			var along: Vector3 = (b - a).normalized() if a.distance_to(b) > 0.1 else pieces[0].global_basis.z
			var mid: Vector3 = (a + b) * 0.5
			var side: Vector3 = Vector3.UP.cross(along).normalized()
			if (mid + side).length() > (mid - side).length():
				side = -side
			cam.fov = 60.0
			cam.look_at_from_position(mid + side * 4.5 - along * 2.0 + Vector3.UP * 2.4, mid, Vector3.UP)
		&"wall":
			# the parapet's face first, else a pillar's
			var on_stone: Decal = null
			for d: Decal in marks.decals_of(ArenaMarks.Kind.SCORCH) + marks.decals_of(ArenaMarks.Kind.CUT):
				if absf(d.global_basis.y.normalized().y) > 0.5:
					continue
				if on_stone == null or absf(Vector2(d.global_position.x, d.global_position.z).length() - marks.wall_radius) < 0.2:
					on_stone = d
			if on_stone == null:
				push_warning("arena_marks_shot: the match left no mark on the parapet or a pillar")
				_overview(cam)
				return
			var out: Vector3 = on_stone.global_basis.y.normalized()
			var at: Vector3 = on_stone.global_position
			cam.fov = 55.0
			cam.look_at_from_position(at + out * 3.2 + Vector3.UP * 1.3, at, Vector3.UP)
		&"cut", &"gash", &"crack", &"scorch":
			var kind: int = ArenaMarks.KIND_NAMES.find(view)
			var first: Decal = null
			for d: Decal in marks.decals_of(kind):
				if d.global_basis.y.normalized().y > 0.5:
					first = d
					break
			if first == null:
				push_warning("arena_marks_shot: the match left no %s on the floor" % view)
				_overview(cam)
				return
			var at: Vector3 = first.global_position
			var back: Vector3 = (Vector3(at.x, 0.0, at.z) if Vector2(at.x, at.z).length() > 1.0 else Vector3.BACK).normalized()
			cam.fov = 50.0
			cam.look_at_from_position(at - back * (1.2 + first.size.z * 0.6) + Vector3.UP * (0.9 + first.size.z * 0.4), at, Vector3.UP)
		_:
			_overview(cam)


## A vertical Moonsplitter wave from side 0 toward side 1, flown through the
## marks alone.
func _stage_wave(view_node: MatchView, ago: float) -> void:
	var a: Vector3 = host.display_position(0)
	var b: Vector3 = host.display_position(1)
	var ahead := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var wave := SlashWave.new(null, &"vertical", a.x, a.z, ahead.x, ahead.z)
	var t: float = view_node.effects.clock() + ago
	var sides: Array[Dictionary] = []
	while wave.s < World.WAVE_RANGE:
		wave.s += World.WAVE_SPEED * SimConst.DT
		t += 1.0
		view_node.arena_marks.frame(sides, [wave] as Array[SlashWave], 1.0, view_node.effects, t)
		view_node.arena_marks.update(t)
		view_node.effects.update(t)


func _overview(cam: Camera3D) -> void:
	# under the canopy (the cameras' room reaches 6.6 m)
	cam.fov = 70.0
	cam.look_at_from_position(Vector3(0.0, 6.2, -13.5), Vector3(0.0, 0.0, 2.0), Vector3.UP)


## Where on the floor the most marks lie within 3 m.
static func _thickest(marks: ArenaMarks) -> Vector3:
	var spots: Array[Vector3] = []
	for kind: int in ArenaMarks.KIND_NAMES.size():
		for d: Decal in marks.decals_of(kind):
			if d.global_basis.y.normalized().y > 0.5:
				spots.append(d.global_position)
	var best := Vector3.ZERO
	var most: int = -1
	for p: Vector3 in spots:
		var n: int = 0
		for q: Vector3 in spots:
			if p.distance_to(q) < 3.0:
				n += 1
		if n > most:
			most = n
			best = p
	return best
