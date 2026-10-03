extends GutTest
## The debug view of blade sweeps and hurt capsules (task 7.15), headless. It
## keeps one swept quad per active tick of a move with a swing, from the
## blade at the last tick to this one, and one marker per hit, block, parry
## or whiff where the outcome landed, and draws them with the capsules.
## record() and on_event() are fed as the host feeds them, from a world
## stepped by hand: Right Cut with the level slashes of swing_fixtures.gd
## (active frames 12-14), from 1.6 m apart, lunging to 1.25 m and first
## touching the defender on frame 13.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
## The line vertices of a wire capsule: 16 segments round each of two
## rings, 4 lines down the sides and two 8-segment arcs over each end.
const CAPSULE_VERTICES: int = (2 * 16 + 4 + 2 * 2 * 8) * 2

var view: SwingDebugView
## The attacker's blade segments after each step it attacked in, by attack
## frame: [last base, last tip, tip, base] as Vector3s.
var _blades: Dictionary[int, PackedVector3Array] = {}
## Each outcome event of the last _play(), with the attacker's first blade
## tip as it was then (for a whiff).
var _outcomes: Array[Dictionary] = []


func before_each() -> void:
	view = SwingDebugView.new()
	add_child_autofree(view)
	_blades = {}
	_outcomes = []


func after_each() -> void:
	H.dispose_all()


static func _cut() -> AttackDef:
	return Moves.KATANA.moves[CUT]


static func _v(p: V3) -> Vector3:
	return Vector3(p.x, p.y, p.z)


## Plays Right Cut with `swing` (none: the cone) from 1.6 m at a defender
## playing `defend` (none: idle) for `steps` steps, feeding the view as the
## host does: each step's events, then the step.
func _play(swing: Swing, defend: Callable = Callable(), steps: int = 32) -> World:
	var w: WeaponDef = SF.weapon(&"katana", {CUT: swing}) if swing != null else SF.without_swings(&"katana")
	var W: World = H.make_world(w, Moves.KATANA, 1.6)
	var a: Fighter = W.fighters[0]
	for i: int in steps:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle() if defend.is_null() else defend.call(i)])
		for b: BladeSegment in a.blade_segments():
			_blades[a.atk.frame] = PackedVector3Array([_v(b.prev_base), _v(b.prev_tip), _v(b.tip), _v(b.base)])
		for e: Dictionary in W.drain_events():
			if [&"hit", &"block", &"parry", &"whiff"].has(e["t"]):
				var tips: Array[BladeSegment] = a.blade_segments()
				_outcomes.append({"e": e, "tip": _v(tips[0].tip) if not tips.is_empty() else Vector3.INF})
			view.on_event(e, W)
		view.record(W)
	return W


static func _frames(quads: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for q: Dictionary in quads:
		out.append(int(q["frame"]))
	return out


static func _pos(e: Dictionary) -> Vector3:
	return Vector3(float(e["pos"]["x"]), float(e["pos"]["y"]), float(e["pos"]["z"]))


func test_a_hit_keeps_a_quad_per_active_tick_and_a_marker_where_it_landed() -> void:
	_play(SF.level_slash(_cut()))
	assert_eq(_frames(view.quads), [12, 13, 14] as Array[int], "a quad for each active tick, on through the hit")
	for q: Dictionary in view.quads:
		assert_eq(q["corners"], _blades[int(q["frame"])], "frame %d: from the blade at the last tick to this one" % q["frame"])
		assert_eq(q["side"], 0)
	assert_eq(view.markers.size(), 1, "one marker")
	assert_eq(view.markers[0]["kind"], &"hit")
	assert_eq(view.markers[0]["at"], _pos(_outcomes[0]["e"]), "where the hit started, as the flash does")


func test_a_parry_ends_the_quads_on_the_tick_it_lands() -> void:
	var parry: Callable = func(i: int) -> RawInput: return H.btn(Btn.BLOCK) if i == 13 else H.idle()
	_play(SF.level_slash(_cut(), 1.2, 90.0, -30.0), parry)
	assert_eq(_outcomes.size(), 1)
	assert_eq(_outcomes[0]["e"]["t"], &"parry")
	assert_eq(_frames(view.quads), [12, 13] as Array[int], "the parried tick too, though the attack ended in it")
	assert_eq(view.markers.size(), 1)
	assert_eq(view.markers[0]["kind"], &"parry")
	assert_eq(view.markers[0]["at"], _pos(_outcomes[0]["e"]))


func test_a_block_and_a_whiff_each_leave_their_marker() -> void:
	var hold: Callable = func(_i: int) -> RawInput: return H.btn(Btn.BLOCK)
	_play(SF.level_slash(_cut()), hold)
	assert_eq(_frames(view.quads), [12, 13, 14] as Array[int])
	assert_eq(view.markers.size(), 1)
	assert_eq(view.markers[0]["kind"], &"block")
	assert_eq(view.markers[0]["at"], _pos(_outcomes[0]["e"]))
	# over the head: no touch, a whiff once the active frames pass, marked at
	# the blade's tip
	view.clear()
	_outcomes = []
	_play(SF.level_slash(_cut(), 2.2))
	assert_eq(_frames(view.quads), [12, 13, 14] as Array[int], "the sweeps that missed")
	assert_eq(view.markers.size(), 1)
	assert_eq(view.markers[0]["kind"], &"whiff")
	assert_eq(view.markers[0]["at"], _outcomes[0]["tip"], "at the blade's tip")


func test_a_move_without_a_swing_has_no_quads_and_marks_the_flash() -> void:
	_play(null)
	assert_eq(view.quads, [] as Array[Dictionary], "the cone sweeps nothing")
	assert_eq(view.markers.size(), 1)
	assert_eq(view.markers[0]["kind"], &"hit")
	assert_eq(view.markers[0]["at"], _pos(_outcomes[0]["e"]), "halfway between the fighters, where the flash is")


## Steps `W` idle, recording each step, until its frame is `frame`.
func _idle_until(W: World, frame: int) -> void:
	while W.frame < frame:
		W.step([H.idle(), H.idle()])
		view.record(W)


func test_quads_and_markers_last_about_a_second_of_world_frames() -> void:
	var W: World = _play(SF.level_slash(_cut()))
	# the hit's marker, born with the frame-13 quad; the frame-14 quad comes
	# after the hit-stop
	var born: int = int(view.markers[0]["born"])
	var last: int = int(view.quads[2]["born"])
	assert_gt(last, born, "the last quad is younger")
	_idle_until(W, born + SwingDebugView.KEEP_FRAMES - 1)
	assert_eq(view.markers.size(), 1, "the marker kept a frame short of a second")
	_idle_until(W, born + SwingDebugView.KEEP_FRAMES)
	assert_eq(view.markers.size(), 0, "and gone after a second")
	assert_eq(_frames(view.quads), [14] as Array[int], "with the quads born with it")
	_idle_until(W, last + SwingDebugView.KEEP_FRAMES)
	assert_eq(view.quads.size(), 0, "the last quad a second after its own tick")


func test_a_new_round_clears_it() -> void:
	var W: World = _play(SF.level_slash(_cut()))
	assert_eq(view.quads.size(), 3)
	view.on_event({"t": &"roundStart", "round": 2}, W)
	assert_eq(view.quads, [] as Array[Dictionary])
	assert_eq(view.markers, [] as Array[Dictionary])


func test_it_draws_each_quad_with_the_capsules_blades_and_markers() -> void:
	var W: World = _play(SF.level_slash(_cut()), Callable(), 14)
	view.redraw()
	var quads: int = view.quads.size()
	assert_eq(quads, 2, "frames 12 and 13 so far, the attack still on")
	assert_eq(view.mesh.get_surface_count(), 2, "the quads filled, then the lines")
	assert_eq(view.mesh.surface_get_array_len(0), 6 * quads, "two triangles a quad")
	var blades: int = W.fighters[0].blade_segments().size()
	assert_eq(blades, 1, "Right Cut's one blade")
	assert_eq(view.mesh.surface_get_array_len(1),
			2 * CAPSULE_VERTICES + 8 * quads + 2 * blades + 6 * view.markers.size(),
			"two wire capsules, each quad's edges, the blade and a cross per marker")
	# with nothing kept, only the capsules
	view.clear()
	view.redraw()
	assert_eq(view.mesh.get_surface_count(), 1)
	assert_eq(view.mesh.surface_get_array_len(0), 2 * CAPSULE_VERTICES + 2 * blades)


func test_the_match_view_turns_it_on_with_f3_or_the_argument() -> void:
	var host: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	add_child_autofree(host)
	var match_view: MatchView = host.get_node("View")
	host.start(MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"daggers", 1, &"hard"),
		7,
		ArenaScenes.STANDIN,
	))
	assert_null(match_view.swing_debug_view, "off by default")
	var f3: InputEventKey = InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	match_view._unhandled_input(f3)
	var dbg: SwingDebugView = match_view.swing_debug_view
	assert_not_null(dbg, "F3 turns it on")
	assert_eq(dbg.get_parent(), match_view)
	host.step(3)
	dbg.redraw()
	assert_eq(dbg.mesh.surface_get_array_len(0), 2 * CAPSULE_VERTICES, "following the host's world: the two capsules")
	match_view._unhandled_input(f3)
	assert_null(match_view.swing_debug_view, "and off again")
	assert_true(MatchView.wants_swing_debug(PackedStringArray(["--path", "game", "--swing-debug"])))
	assert_false(MatchView.wants_swing_debug(PackedStringArray(["--path", "game"])))
