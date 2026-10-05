class_name FighterPreview
extends SubViewportContainer
## The fighter select's 3D preview (task 22.7): the side's fighter in its
## palette, holding its weapon, idling and slowly turning, in the select's
## right-hand column.
##
## A SubViewport with its own World3D, so nothing of the duel behind the
## menus lights or hides it, and a transparent background, so the fighter
## stands over the ink veil with no frame or backdrop (the owner's choice,
## Oct 4, 2026). Plain lighting: a key and a fill over a soft ambient. The
## stage is restyled with the milestone-1 UI redesign.
##
## The fighter is the match's own FighterView, driven by a small rules world
## where it stands free in guard facing an opponent that is never shown, so
## the preview plays the match's combat idle for the weapon (the packs'
## clips when installed, the CC0 fallback otherwise) with the weapon fixed in
## the hands: the select shows the fighter as the match will. Its floor marks
## (the shadow disc and the side's ring) come with it. A Random weapon (the
## Duel opponent's) cycles the three playable weapons every CYCLE_SECONDS.
##
## The world steps at the rules' 60 a second and the stage turns only while
## the preview is visible in the tree; a hidden select renders nothing.

## One revolution of the slow turn, in seconds.
const TURN_SECONDS: float = 12.0
## How long a Random weapon shows each of the three.
const CYCLE_SECONDS: float = 1.5
## Where the unseen opponent stands, straight ahead.
const OPPONENT_GAP: float = 2.5
const CAMERA_POS: Vector3 = Vector3(0.0, 1.2, 7.0)
const CAMERA_TARGET: Vector3 = Vector3(0.0, 1.15, 0.0)
const CAMERA_FOV: float = 30.0

var viewport: SubViewport
var camera: Camera3D
## Turns the fighter.
var pivot: Node3D
var view: FighterView
## The rules world the fighter idles in; remade when the weapon changes.
var world: World
## The weapon held now (one of the three while a Random weapon cycles).
var weapon_shown: StringName = &""
## The slow turn so far, in radians (unwrapped).
var turn: float = 0.0

var _fighter_id: StringName = &""
var _palette: int = 0
var _side: int = 0
var _random: bool = false
var _cycle_left: float = 0.0
var _step_left: float = 0.0
var _seconds: float = 0.0


func _init() -> void:
	name = "FighterPreview"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "Stage"
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	_build_stage()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_dispose_world()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and viewport != null:
		viewport.render_target_update_mode = (
			SubViewport.UPDATE_WHEN_VISIBLE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
		)


## Shows a side of a selection draft: its fighter, palette and weapon, or the
## cycle of the three when its weapon is Random.
func show_draft(d: MatchSelection.Draft, p_side: int) -> void:
	var s: MatchSide = d.sides[p_side]
	show_side(s.fighter_id, s.palette, s.weapon_id, p_side, d.random_weapon[p_side])


## Shows `fighter_id` in `palette` holding `weapon_id` (ignored while
## `random`, which cycles the three).
func show_side(fighter_id: StringName, palette: int, weapon_id: StringName, p_side: int, random: bool) -> void:
	var was_random: bool = _random
	var same: bool = world != null and fighter_id == _fighter_id and palette == _palette and p_side == _side
	_fighter_id = fighter_id
	_palette = palette
	_side = p_side
	_random = random
	var weapon: StringName = weapon_id
	if random:
		# a cycle already running carries on; a new one starts on the first
		weapon = weapon_shown if was_random and weapon_shown != &"" else Moves.PLAYABLE_WEAPONS[0]
		if not was_random:
			_cycle_left = CYCLE_SECONDS
	# a refresh that changes nothing shown keeps the idle running
	if same and weapon == weapon_shown:
		return
	_show(weapon)


## The rules' fighter shown.
func fighter() -> Fighter:
	return world.fighters[0] if world != null else null


## Runs the preview on by `delta` seconds: the world's steps, the Random
## cycle, the turn and the fighter's pose.
func advance(delta: float) -> void:
	if world == null:
		return
	if _random:
		_cycle_left -= delta
		while _cycle_left <= 0.0:
			_cycle_left += CYCLE_SECONDS
			var i: int = Moves.PLAYABLE_WEAPONS.find(weapon_shown)
			_show(Moves.PLAYABLE_WEAPONS[(i + 1) % Moves.PLAYABLE_WEAPONS.size()])
	_step_left += delta
	var dt: float = 1.0 / float(SimConst.FPS)
	while _step_left >= dt - 0.000001:
		_step_left -= dt
		world.step([RawInput.empty(), RawInput.empty()])
	_seconds += delta
	turn += TAU * delta / TURN_SECONDS
	pivot.rotation = Vector3(0.0, wrapf(turn, -PI, PI), 0.0)
	_pose(delta)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		advance(delta)


func _show(weapon_id: StringName) -> void:
	weapon_shown = weapon_id
	_dispose_world()
	world = World.new(
		FighterConfig.make(Moves.WEAPONS[weapon_id], [], "", _fighter_id),
		FighterConfig.make(Moves.KATANA),
		1,
	)
	var me: Fighter = world.fighters[0]
	var opp: Fighter = world.fighters[1]
	me.pos = V3.make(0.0, 0.0, 0.0)
	opp.pos = V3.make(0.0, 0.0, OPPONENT_GAP)
	me.yaw = 0.0
	opp.yaw = PI
	for f: Fighter in world.fighters:
		f.set_state(&"free")
		# standing in guard, the Greatsword off the shoulder
		f.shouldered = false
	view.setup(_fighter_id, _palette, weapon_id, _side)
	_step_left = 0.0
	_pose(0.0)


func _pose(delta: float) -> void:
	view.update_from(fighter(), Vector3.ZERO, 0.0, 1.0, delta, _seconds)


func _dispose_world() -> void:
	if world != null:
		world.dispose()
		world = null


func _build_stage() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.78)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	viewport.add_child(we)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "Key"
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.95, 0.88)
	key.shadow_enabled = true
	viewport.add_child(key)
	key.transform = _looking(Vector3(2.0, 3.5, 3.0), Vector3.ZERO)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_energy = 0.45
	fill.light_color = Color(0.72, 0.8, 1.0)
	viewport.add_child(fill)
	fill.transform = _looking(Vector3(-3.0, 1.5, -1.0), Vector3(0.0, 1.0, 0.0))

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = CAMERA_FOV
	camera.current = true
	viewport.add_child(camera)
	camera.transform = _looking(CAMERA_POS, CAMERA_TARGET)

	pivot = Node3D.new()
	pivot.name = "Turn"
	viewport.add_child(pivot)
	view = FighterView.new()
	view.name = "Fighter"
	pivot.add_child(view)


static func _looking(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from), from)
