class_name StudioEditor
extends VBoxContainer
## The Studio's editor (milestone-1 task 25, carrying Studio tasks 7-9 as
## the milestone slims them): a large viewport with the fighter playing the
## entry's clip or chain under an orbit camera, a side panel with the move's
## frames and bands (its generated frame data against its kind's timing
## band, and the distance band's hit-or-miss check, the band tests' own) and
## the layer toggles, and a timeline over source frames with the rules
## ruler, the markers and the feet (StudioTimeline). Space plays and pauses,
## Left and Right step a frame, L loops.
##
## Only foot locking has a toggle: task 23 adds inertial blending's, and the
## reaction layer's task its own. Marker editing comes with task 26, the
## chain panel and save with task 27.

## The Back button was pressed: return to the gallery.
signal back_requested()

const VIEW_BACKGROUND: Color = Color(0.17, 0.18, 0.21)
const OK_MARK: String = "✓"
const BAD_MARK: String = "✗"

## The entry shown, or null.
var entry: StudioCatalogue.Entry = null
## &"hunter" or &"rogue".
var fighter_id: StringName = &"hunter"
## The fighter, or null before an entry is opened.
var model: FighterModel = null
var poser: ClipPoser = null
var playback: StudioPlayback = StudioPlayback.new()
## The move's frames and bands; null for a state, an ultimate or a clip.
var view: FramesAndBands = null
## Whether planted feet are held (the foot-locking layer).
var foot_lock_on: bool = true

var viewport: SubViewport = null
var camera: OrbitCamera = null
var timeline: StudioTimeline = null
var _view_container: SubViewportContainer = null
var _stage: Node3D = null
var _title: Label = null
var _verdict: Label = null
var _fields: VBoxContainer = null
var _distance: VBoxContainer = null
var _foot_lock: CheckBox = null
var _play: Button = null
var _loop: CheckBox = null
var _rate: HSlider = null
var _frame_label: Label = null
var _note: Label = null
## The rules frame last posed, so a jump (a scrub, a wrap) starts a fresh
## foot lock rather than easing over the gap.
var _last_rules: int = -1000


func _ready() -> void:
	_build_ui()


## Shows `e` on fighter `fid` (&"hunter" or &"rogue"), playhead at the start.
func open(e: StudioCatalogue.Entry, fid: StringName = fighter_id) -> void:
	entry = e
	fighter_id = fid
	playback.playing = false
	_build_fighter()
	_build_view()
	var length: float = poser.length * float(ClipManifest.SOURCE_FPS) if poser != null else 0.0
	playback.length = length
	playback.frame = 0.0
	timeline.set_data(length, _markers(), _feet(), view)
	_show_panel()
	seek(0.0)


## Frees the fighter (leaving the editor).
func close() -> void:
	playback.playing = false
	_drop_fighter()
	entry = null
	view = null


## Puts the playhead at source frame `f` and poses the fighter there.
func seek(f: float) -> void:
	playback.seek(f)
	_pose()


func play(on: bool) -> void:
	playback.playing = on and playback.length > 0.0
	_play.text = "Pause" if playback.playing else "Play"


## Switches the foot-locking layer on or off.
func set_foot_lock(on: bool) -> void:
	foot_lock_on = on
	_foot_lock.set_pressed_no_signal(on)
	_last_rules = -1000
	_pose()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not playback.playing:
		return
	playback.advance(delta)
	if not playback.playing:
		_play.text = "Play"
	_pose()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or not is_visible_in_tree() or entry == null:
		return
	match key.keycode:
		KEY_SPACE:
			play(not playback.playing)
		KEY_LEFT:
			playback.step(-1)
			_pose()
		KEY_RIGHT:
			playback.step(1)
			_pose()
		KEY_L:
			playback.loop = not playback.loop
			_loop.set_pressed_no_signal(playback.loop)
		_:
			return
	get_viewport().set_input_as_handled()


## Poses the fighter at the playhead: the rig's foot lock steps by rules
## frames (two to a source frame), a fresh one after any jump.
func _pose() -> void:
	timeline.set_frame(playback.frame)
	var rules: int = roundi(playback.frame * MoveClips.RULES_PER_SOURCE)
	_frame_label.text = "source %.1f / %.1f · rules %d" % [playback.frame, playback.length,
			roundi(view.to_rules(playback.frame)) if view != null else rules]
	if poser == null:
		return
	var rig: FighterRig = model.rig
	rig.leg_weight = 1.0
	if not foot_lock_on:
		rig.foot_lock = null
	elif rig.foot_lock == null or rules < _last_rules or rules > _last_rules + FootLock.EASE_FRAMES:
		rig.foot_lock = rig.new_foot_lock()
	_last_rules = rules
	rig.rules_frame = rules
	poser.pose(playback.source_time())
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_fighter() -> void:
	_drop_fighter()
	model = FighterLook.instantiate_fighter(fighter_id)
	model.autoplay_idle = false
	_stage.add_child(model)
	AnimTile.add_libraries(model)
	var weapon: StringName = AnimTile.weapon_for(entry)
	if weapon != &"":
		model.attach_weapon(WeaponLook.load_id(weapon))
	var chain: Array[String] = AnimTile.chain_on(model, entry, fighter_id)[0]
	poser = ClipPoser.new(model, chain if not chain.is_empty() else [AnimTile.still_clip(model)] as Array[String])
	_note.visible = chain.is_empty() or not ClipLibraries.available()
	_note.text = "Nothing to play: the fighter's idle, held." if chain.is_empty() else ClipLibraries.MISSING_NOTE
	_last_rules = -1000


func _drop_fighter() -> void:
	if model != null:
		_stage.remove_child(model)
		model.queue_free()
		model = null
	poser = null


func _build_view() -> void:
	view = null
	if entry == null or entry.kind != StudioCatalogue.KIND_MOVE:
		return
	var w: WeaponDef = Moves.WEAPONS.get(entry.group)
	if w == null or not w.moves.has(entry.id):
		return
	view = FramesAndBands.build(w, entry.id, FrameDataTable.shared().row(w.id, entry.id), _move_markers(), MoveBands.shared())


## The move's markers (MoveClips), or an empty Dictionary.
func _move_markers() -> Dictionary:
	if entry == null or entry.kind != StudioCatalogue.KIND_MOVE:
		return {}
	var e: MoveClips.Entry = MoveClips.read(ClipManifest.read()).of(entry.group).get(entry.id)
	return e.markers if e != null else {}


## The markers the timeline shows: a move's, else its clip's own (a single
## clip played whole).
func _markers() -> Dictionary:
	if entry == null:
		return {}
	if entry.kind == StudioCatalogue.KIND_MOVE:
		return StudioTimeline.flat_markers(_move_markers())
	if entry.clips.size() == 1:
		var clip: ClipManifest.Clip = ClipManifest.read().clips.get(StringName(entry.clips[0]))
		if clip != null:
			return StudioTimeline.flat_markers(clip.markers)
	return {}


## Each foot's contacts along the chain, from the manifest (measured, never
## edited here).
func _feet() -> Dictionary:
	if entry == null or entry.clips.is_empty() or poser == null or not ClipLibraries.available():
		return {}
	var manifest: ClipManifest = ClipManifest.read()
	var contacts: Dictionary = {}
	for c: StringName in manifest.clips:
		contacts[c] = (manifest.clips[c] as ClipManifest.Clip).foot_contacts
	return FrameDataGenerator.chain_contacts(poser.parts(), contacts)


func _show_panel() -> void:
	for box: VBoxContainer in [_fields, _distance]:
		for c: Node in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_title.text = "%s · %s" % [entry.name, entry.id] if entry != null else ""
	if view == null:
		_verdict.text = "Frames and bands are shown for moves."
		return
	_verdict.text = "%s · %s" % [String(view.kind).replace("_", " "), view.verdict()]
	_verdict.modulate = Color(0.55, 0.9, 0.6) if view.in_band() else (Color(0.95, 0.75, 0.4) if view.waiting else Color(1.0, 0.5, 0.45))
	for f: FramesAndBands.Field in view.fields:
		_fields.add_child(_line("%s %s" % [OK_MARK if f.ok else BAD_MARK, f.text()], f.ok))
	for l: MoveBands.DistanceLine in view.distance:
		_distance.add_child(_line("%s %s" % [OK_MARK if l.ok else BAD_MARK, l.text], l.ok))
	if view.distance.is_empty() and view.no_band == "":
		_distance.add_child(_line("no distance to check", true))


func _line(text: String, ok: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(0.82, 0.88, 0.84) if ok else Color(1.0, 0.6, 0.55))
	return label


func _build_ui() -> void:
	add_theme_constant_override(&"separation", 6)
	var top: HBoxContainer = HBoxContainer.new()
	add_child(top)
	var back: Button = Button.new()
	back.name = "BackButton"
	back.unique_name_in_owner = true
	back.text = "← Gallery"
	back.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back)
	_title = _named(Label.new(), "EditorTitle")
	_title.theme_type_variation = &"TitleLabel"
	top.add_child(_title)
	for preset: StringName in OrbitCamera.PRESETS:
		var b: Button = Button.new()
		b.text = String(preset).capitalize()
		b.pressed.connect(func() -> void: camera.use_preset(preset))
		top.add_child(b)
	_note = _named(Label.new(), "EditorNote")
	_note.theme_type_variation = &"NoteLabel"
	_note.visible = false
	top.add_child(_note)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(middle)
	_view_container = _named(SubViewportContainer.new(), "EditorView")
	_view_container.stretch = true
	_view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_container.gui_input.connect(_on_view_input)
	middle.add_child(_view_container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_view_container.add_child(viewport)
	_build_stage()

	var side: VBoxContainer = _named(VBoxContainer.new(), "SidePanel")
	side.custom_minimum_size.x = 320.0
	middle.add_child(side)
	side.add_child(_heading("Frames and bands"))
	_verdict = _named(Label.new(), "Verdict")
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_verdict)
	_fields = _named(VBoxContainer.new(), "BandFields")
	side.add_child(_fields)
	side.add_child(_heading("Distance band"))
	_distance = _named(VBoxContainer.new(), "DistanceLines")
	side.add_child(_distance)
	side.add_child(_heading("Layers"))
	_foot_lock = _named(CheckBox.new(), "FootLock")
	_foot_lock.text = "Foot locking"
	_foot_lock.button_pressed = foot_lock_on
	_foot_lock.toggled.connect(set_foot_lock)
	side.add_child(_foot_lock)

	var controls: HBoxContainer = HBoxContainer.new()
	add_child(controls)
	_play = _named(Button.new(), "PlayButton")
	_play.text = "Play"
	_play.pressed.connect(func() -> void: play(not playback.playing))
	controls.add_child(_play)
	_loop = _named(CheckBox.new(), "LoopToggle")
	_loop.text = "Loop"
	_loop.button_pressed = playback.loop
	_loop.toggled.connect(func(on: bool) -> void: playback.loop = on)
	controls.add_child(_loop)
	var rate_label: Label = Label.new()
	rate_label.text = "Speed"
	controls.add_child(rate_label)
	_rate = _named(HSlider.new(), "RateSlider")
	_rate.min_value = StudioPlayback.MIN_RATE
	_rate.max_value = StudioPlayback.MAX_RATE
	_rate.step = 0.05
	_rate.value = 1.0
	_rate.custom_minimum_size.x = 140.0
	_rate.value_changed.connect(func(v: float) -> void: playback.rate = v)
	controls.add_child(_rate)
	_frame_label = _named(Label.new(), "FrameLabel")
	controls.add_child(_frame_label)

	timeline = _named(StudioTimeline.new(), "Timeline")
	timeline.seeked.connect(seek)
	add_child(timeline)
	_own(self)


## The camera takes the viewport's drags and wheel.
func _on_view_input(event: InputEvent) -> void:
	if camera.handle(event):
		_view_container.accept_event()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Makes this editor the owner of its uniquely named nodes, so %Name finds
## them (the nodes are built in code, not loaded from a scene).
func _own(n: Node) -> void:
	for c: Node in n.get_children():
		if c.unique_name_in_owner:
			c.owner = self
		_own(c)


func _named(n: Control, node_name: String) -> Variant:
	n.name = node_name
	n.unique_name_in_owner = true
	return n


func _heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"TitleLabel"
	return label


## The viewport's world: a background, a key light, an ambient fill, a floor
## with a metre grid, and the orbit camera on the fighter.
func _build_stage() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = VIEW_BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	key.light_energy = 1.5
	viewport.add_child(key)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	floor_mesh.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.31, 0.33)
	floor_mat.roughness = 0.95
	floor_mesh.material_override = floor_mat
	viewport.add_child(floor_mesh)
	var grid: MeshInstance3D = MeshInstance3D.new()
	var lines: ImmediateMesh = ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i: int in range(-4, 5):
		lines.surface_add_vertex(Vector3(i, 0.002, -4.0))
		lines.surface_add_vertex(Vector3(i, 0.002, 4.0))
		lines.surface_add_vertex(Vector3(-4.0, 0.002, i))
		lines.surface_add_vertex(Vector3(4.0, 0.002, i))
	lines.surface_end()
	grid.mesh = lines
	var grid_mat: StandardMaterial3D = StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.albedo_color = Color(0.45, 0.47, 0.52)
	grid.material_override = grid_mat
	viewport.add_child(grid)
	_stage = Node3D.new()
	_stage.name = "Stage"
	viewport.add_child(_stage)
	camera = OrbitCamera.new()
	viewport.add_child(camera)
	camera.current = true
	camera.use_preset(&"front")
