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
## Foot locking, inertial blending (milestone-1 task 23) and the physical
## reaction layer (task 70) have toggles, all on as in a match. Inertial
## blending and the reaction layer run on the playhead's rules frames: a loop
## back to the start hands off as a follow-up would (StateClips.blends), any
## other jump cuts. The Studio has no hits, so Test push lands a light Katana
## blow on the chest from in front at the playhead.
##
## Markers (milestone-1 task 26) are edited in the Markers panel's boxes or by
## dragging them on the timeline: a move's (MoveClips: wind-up, active start
## and end, settle, dodge-cancel window, branch points) or, for an entry
## playing one whole clip, that clip's (ClipManifest). Each edit is held in
## the Studio's EditSession (MarkerEdits), with undo and redo (the buttons,
## Ctrl+Z, Ctrl+Shift+Z or Ctrl+Y); a move with stand-in markers asks first
## whether to replace them with real ones. Foot contacts are shown, never
## edited.
##
## A move's chain (milestone-1 task 27) is edited in the Chain panel: each
## part's clip and source-frame range, moved up or down, removed or added
## (ChainEdits); today's holds and the move's speed show read-only, going
## with the stand-ins (milestone-1 task 19). The fighter plays the pending
## chain at once. Save (the button or Ctrl+S) writes the pending edits and regenerates the frame-data
## table (StudioSaver), and the side panel shows its report: what was saved
## or refused, each move whose frame data changed, each one out of band, and
## that a soak is due.

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
## Whether the inertial-blending layer is on (milestone-1 task 23).
var inertial_on: bool = true
## Whether the physical reaction layer is on (milestone-1 task 70).
var reaction_on: bool = true
## The Studio's pending edits (shared with the gallery's badges).
var session: EditSession = EditSession.new()
## The data files marker edits go to (fixture copies in tests).
var moves_file: String = MoveClips.PATH
var manifest_file: String = ClipManifest.PATH
## The move as read, when the entry is a move; null otherwise.
var move_entry: MoveClips.Entry = null
## The clip whose markers the entry edits, when it plays one whole clip.
var clip_id: StringName = &""
## The last marker edit refused, or "".
var last_error: String = ""
## The save (its generator a seam for tests).
var saver: StudioSaver = null
## The last save's result, or null.
var last_save: StudioSaver.Result = null

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
var _inertial: CheckBox = null
var _reaction: CheckBox = null
var _play: Button = null
var _loop: CheckBox = null
var _rate: HSlider = null
var _frame_label: Label = null
var _note: Label = null
var _markers_box: GridContainer = null
var _chain_box: VBoxContainer = null
var _speed_label: Label = null
var _report: Label = null
var _status: Label = null
var _undo: Button = null
var _redo: Button = null
var _confirm: ConfirmationDialog = null
## The marker edit waiting on the stand-in question: [name, frame].
var _asked: Array = []
## The manifest, read once per open.
var _manifest: ClipManifest = null
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
	_manifest = ClipManifest.read()
	move_entry = null
	clip_id = &""
	if e != null and e.kind == StudioCatalogue.KIND_MOVE:
		move_entry = MoveClips.read(_manifest).of(e.group).get(e.id)
	elif e != null and e.clips.size() == 1 and _manifest.clips.has(StringName(e.clips[0])):
		clip_id = StringName(e.clips[0])
	_build_fighter()
	_build_view()
	var length: float = poser.length * float(ClipManifest.SOURCE_FPS) if poser != null else 0.0
	playback.length = length
	playback.frame = 0.0
	timeline.set_data(length, _markers(), _feet(), view)
	timeline.markers_editable = move_entry != null or clip_id != &""
	_show_panel()
	_show_markers()
	_show_chain()
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


## Switches the inertial-blending layer on or off (milestone-1 task 23).
func set_inertial_blending(on: bool) -> void:
	inertial_on = on
	_inertial.set_pressed_no_signal(on)
	if model != null:
		model.rig.inertial.clear()
	_pose()


## Switches the physical reaction layer on or off (milestone-1 task 70).
func set_physical_reaction(on: bool) -> void:
	reaction_on = on
	_reaction.set_pressed_no_signal(on)
	if model != null:
		model.rig.reaction.clear()
	_pose()


## Lands a light Katana blow on the chest from in front at the playhead,
## to see the reaction layer (the Studio has no hits).
func push_test_blow() -> void:
	if model == null:
		return
	var rig: FighterRig = model.rig
	rig.reaction.push(rig.reaction.time, Vector3(0.0, 1.4, 0.2), Vector3(0.0, 0.0, -1.0),
		PhysicalReactionLayer.strength(false, &"medium"))
	_pose()


## A loop back to the start: blends into it as a follow-up would.
func _wrapped() -> void:
	if model != null:
		model.rig.inertial.request(StateClips.shared().blends[&"follow_up"])


## Switches the foot-locking layer on or off.
func set_foot_lock(on: bool) -> void:
	foot_lock_on = on
	_foot_lock.set_pressed_no_signal(on)
	_last_rules = -1000
	_pose()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not playback.playing:
		return
	var before: float = playback.frame
	playback.advance(delta)
	if not playback.playing:
		_play.text = "Play"
	_pose(playback.loop and playback.frame < before)


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
		KEY_Z when key.ctrl_pressed and key.shift_pressed:
			redo()
		KEY_Z when key.ctrl_pressed:
			undo()
		KEY_Y when key.ctrl_pressed:
			redo()
		KEY_S when key.ctrl_pressed:
			save()
		_:
			return
	get_viewport().set_input_as_handled()


## Poses the fighter at the playhead: the rig's foot lock steps by rules
## frames (two to a source frame), a fresh one after any jump; inertial
## blending runs on them, cutting at a jump but a loop round (`wrapped`).
func _pose(wrapped: bool = false) -> void:
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
	rig.inertial.active = inertial_on
	rig.inertial.time = playback.frame * MoveClips.RULES_PER_SOURCE
	rig.reaction.active = reaction_on
	rig.reaction.time = rig.inertial.time
	if rules < _last_rules or rules > _last_rules + FootLock.EASE_FRAMES:
		if wrapped:
			_wrapped()
		else:
			rig.inertial.clear()
			rig.reaction.clear()
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
	# Typed by the declaration: an `as Array[String]` cast of a literal inside
	# the conditional left it untyped, and ClipPoser.new refused it.
	var plays: Array[String] = chain
	if plays.is_empty():
		plays = [AnimTile.still_clip(model)]
	poser = ClipPoser.new(model, plays)
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
	return move_entry.markers if move_entry != null else {}


## The markers the timeline shows, with the pending edits made: a move's,
## else its clip's own (a single clip played whole).
func _markers() -> Dictionary:
	if move_entry != null:
		return StudioTimeline.flat_markers(MarkerEdits.move_markers(session, moves_file, entry.group, entry.id, move_entry.markers))
	if clip_id != &"":
		return StudioTimeline.flat_markers(MarkerEdits.clip_markers(session, manifest_file, clip_id, _clip_base()))
	return {}


func _clip_base() -> Dictionary:
	return (_manifest.clips[clip_id] as ClipManifest.Clip).markers


## Puts marker `name` at source frame `frame` as a pending edit. A move with
## stand-in markers asks first (unless `confirmed`); a refusal shows in the
## status line (`last_error`).
func set_marker(name: String, frame: float, confirmed: bool = false) -> MarkerEdits.Result:
	var r: MarkerEdits.Result = MarkerEdits.Result.new()
	if move_entry != null:
		r = MarkerEdits.set_move_marker(session, moves_file, entry.group, move_entry, name, frame, confirmed)
	elif clip_id != &"":
		r = MarkerEdits.set_clip_marker(session, manifest_file, clip_id, _clip_base(), name, frame)
	else:
		r.error = "nothing here has markers to edit"
	last_error = r.error
	if r.question != "":
		_asked = [name, frame]
		_confirm.dialog_text = r.question
		_confirm.popup_centered()
	elif r.error == "":
		session.apply(r.edits, r.label)
	_status.text = r.error
	_show_markers()
	return r


## Sets the move's chain to `rows` as a pending edit; the fighter plays it
## at once. A refusal shows in the status line.
func set_chain(rows: Array[ChainEdits.Row]) -> MarkerEdits.Result:
	var r: MarkerEdits.Result = MarkerEdits.Result.new()
	if move_entry == null:
		r.error = "only a move has a chain"
	else:
		r = ChainEdits.set_chain(session, moves_file, entry.group, move_entry, rows, _manifest)
	last_error = r.error
	_status.text = r.error
	if r.error == "" and not r.edits.is_empty():
		session.apply(r.edits, r.label)
		_relay()
	_show_chain()
	_show_markers()
	return r


## The move's chain rows as the session has them.
func chain_rows() -> Array[ChainEdits.Row]:
	if move_entry == null:
		return [] as Array[ChainEdits.Row]
	return ChainEdits.rows_of(ChainEdits.current(session, moves_file, entry.group, move_entry))


## Saves the pending edits and regenerates the table; the report shows in
## the side panel. After a regeneration the weapons are built afresh from
## the new files and the entry shown again.
func save() -> StudioSaver.Result:
	if saver == null:
		saver = StudioSaver.new()
	last_save = saver.save(session, self)
	if last_save.regenerated and saver.table_path == FrameDataTable.PATH:
		for wid: StringName in Moves.WEAPONS.keys():
			var fresh: WeaponDef = StudioSaver.fresh_weapon(wid)
			if fresh != null:
				Moves.WEAPONS[wid] = fresh
	if not last_save.written.is_empty() and entry != null:
		open(entry, fighter_id)
	_report.text = "\n".join(last_save.report())
	_show_markers()
	return last_save


## Plays the pending chain: the poser laid out afresh.
func _relay() -> void:
	if model == null or move_entry == null:
		return
	var e: StudioCatalogue.Entry = StudioCatalogue.Entry.new()
	e.kind = entry.kind
	e.group = entry.group
	e.id = entry.id
	e.fallbacks = entry.fallbacks
	e.clips.assign(ChainEdits.current(session, moves_file, entry.group, move_entry))
	var chain: Array[String] = AnimTile.chain_on(model, e, fighter_id)[0]
	if chain.is_empty():
		return
	poser = ClipPoser.new(model, chain)
	playback.length = poser.length * float(ClipManifest.SOURCE_FPS)
	timeline.length = playback.length
	seek(minf(playback.frame, playback.length))


## The Chain panel: a row per part, from the session.
func _show_chain() -> void:
	if _chain_box == null:
		return
	for c: Node in _chain_box.get_children():
		_chain_box.remove_child(c)
		c.queue_free()
	_chain_box.visible = move_entry != null
	_speed_label.visible = move_entry != null and not is_nan(move_entry.speed)
	if move_entry == null:
		return
	_speed_label.text = "speed %s (goes with the stand-ins)" % move_entry.speed
	var rows: Array[ChainEdits.Row] = chain_rows()
	for i: int in rows.size():
		var row: ChainEdits.Row = rows[i]
		var line: HBoxContainer = HBoxContainer.new()
		line.name = "Part%d" % i
		_chain_box.add_child(line)
		if row.is_held():
			var held: Label = Label.new()
			held.text = "%s · hold (goes with the stand-ins)" % row.held
			held.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(held)
		else:
			var clip: LineEdit = LineEdit.new()
			clip.name = "Clip"
			clip.text = row.clip
			clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			clip.text_submitted.connect(_on_part_clip.bind(i))
			line.add_child(clip)
			var from: SpinBox = SpinBox.new()
			from.name = "From"
			from.step = 0.5
			from.max_value = 999.0
			from.set_value_no_signal(row.from)
			from.value_changed.connect(_on_part_from.bind(i))
			line.add_child(from)
			var to: LineEdit = LineEdit.new()
			to.name = "To"
			to.placeholder_text = "end"
			to.custom_minimum_size.x = 48.0
			to.text = "" if is_nan(row.to) else ChainEdits._num(row.to)
			to.text_submitted.connect(_on_part_to.bind(i))
			line.add_child(to)
		for b: Array in [["↑", -1], ["↓", 1]]:
			var move: Button = Button.new()
			move.text = b[0]
			move.disabled = i + int(b[1]) < 0 or i + int(b[1]) >= rows.size()
			move.pressed.connect(_on_part_move.bind(i, int(b[1])))
			line.add_child(move)
		var remove: Button = Button.new()
		remove.text = "✕"
		remove.disabled = row.is_held() or rows.size() == 1
		remove.pressed.connect(_on_part_remove.bind(i))
		line.add_child(remove)
	var add: Button = Button.new()
	add.name = "AddPart"
	add.text = "Add part"
	add.pressed.connect(_on_part_add)
	_chain_box.add_child(add)


func _on_part_clip(text: String, i: int) -> void:
	var rows: Array[ChainEdits.Row] = chain_rows()
	rows[i].clip = text.strip_edges()
	set_chain(rows)


func _on_part_from(value: float, i: int) -> void:
	var rows: Array[ChainEdits.Row] = chain_rows()
	rows[i].from = value
	set_chain(rows)


func _on_part_to(text: String, i: int) -> void:
	var rows: Array[ChainEdits.Row] = chain_rows()
	rows[i].to = NAN if text.strip_edges() == "" else text.to_float()
	set_chain(rows)


func _on_part_move(i: int, by: int) -> void:
	var rows: Array[ChainEdits.Row] = chain_rows()
	var row: ChainEdits.Row = rows[i]
	rows.remove_at(i)
	rows.insert(i + by, row)
	set_chain(rows)


func _on_part_remove(i: int) -> void:
	var rows: Array[ChainEdits.Row] = chain_rows()
	rows.remove_at(i)
	set_chain(rows)


func _on_part_add() -> void:
	var rows: Array[ChainEdits.Row] = chain_rows()
	var row: ChainEdits.Row = ChainEdits.Row.new()
	row.clip = rows[-1].clip if not rows.is_empty() else ""
	rows.append(row)
	set_chain(rows)


## Answers the stand-in question with yes: the waiting edit is made.
func confirm_stand_ins() -> void:
	if _asked.is_empty():
		return
	var asked: Array = _asked
	_asked = []
	set_marker(asked[0], asked[1], true)


func undo() -> void:
	session.undo()
	_show_markers()


func redo() -> void:
	session.redo()
	_show_markers()


## Whether the entry has pending edits.
func is_unsaved() -> bool:
	if move_entry != null:
		return session.touches(moves_file, [String(entry.group), "moves", String(entry.id)] as Array[String])
	if clip_id != &"":
		return session.touches(manifest_file, ["clips", String(clip_id)] as Array[String])
	return false


## The Markers panel, the timeline's markers, the title's "unsaved" and the
## undo and redo buttons, from the session.
func _show_markers() -> void:
	if timeline == null:
		return
	var flat: Dictionary = _markers()
	timeline.markers = flat
	timeline.queue_redraw()
	for c: Node in _markers_box.get_children():
		_markers_box.remove_child(c)
		c.queue_free()
	var names: Array = flat.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool: return flat[a] < flat[b])
	for name: Variant in names:
		var label: Label = Label.new()
		label.text = str(name)
		_markers_box.add_child(label)
		var box: SpinBox = SpinBox.new()
		box.name = "Marker_" + str(name).replace(" ", "_")
		box.step = 0.5 if move_entry != null else 1.0
		box.min_value = 0.0
		box.max_value = maxf(playback.length, float(flat[name])) + 200.0
		box.set_value_no_signal(flat[name])
		box.value_changed.connect(_on_marker_box.bind(str(name)))
		_markers_box.add_child(box)
	if move_entry != null and MarkerEdits.is_stand_in(session, moves_file, entry.group, entry.id, move_entry.markers_stand_in):
		var stand: Label = Label.new()
		stand.text = "stand-ins"
		stand.tooltip_text = "Today's frame data; editing one asks to replace them with real markers."
		_markers_box.add_child(stand)
		_markers_box.add_child(Control.new())
	_undo.disabled = session.undo_label() == ""
	_undo.tooltip_text = "Undo " + session.undo_label()
	_redo.disabled = session.redo_label() == ""
	_redo.tooltip_text = "Redo " + session.redo_label()
	if entry != null:
		_title.text = "%s · %s%s" % [entry.name, entry.id, " · unsaved" if is_unsaved() else ""]


func _on_marker_box(value: float, name: String) -> void:
	set_marker(name, value)


func _on_marker_moved(name: String, frame: float) -> void:
	set_marker(name, frame)


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
	if view.no_band != "":
		_verdict.modulate = Color(0.75, 0.77, 0.82)
	else:
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

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 380.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	var side: VBoxContainer = _named(VBoxContainer.new(), "SidePanel")
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(side)
	side.add_child(_heading("Frames and bands"))
	_verdict = _named(Label.new(), "Verdict")
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_verdict)
	_fields = _named(VBoxContainer.new(), "BandFields")
	side.add_child(_fields)
	side.add_child(_heading("Distance band"))
	_distance = _named(VBoxContainer.new(), "DistanceLines")
	side.add_child(_distance)
	side.add_child(_heading("Markers"))
	_markers_box = _named(GridContainer.new(), "MarkersPanel")
	_markers_box.columns = 2
	side.add_child(_markers_box)
	var history: HBoxContainer = HBoxContainer.new()
	side.add_child(history)
	_undo = _named(Button.new(), "UndoButton")
	_undo.text = "Undo"
	_undo.pressed.connect(undo)
	history.add_child(_undo)
	_redo = _named(Button.new(), "RedoButton")
	_redo.text = "Redo"
	_redo.pressed.connect(redo)
	history.add_child(_redo)
	_status = _named(Label.new(), "MarkerStatus")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.55))
	side.add_child(_status)
	_confirm = ConfirmationDialog.new()
	_confirm.name = "StandInQuestion"
	_confirm.ok_button_text = "Replace"
	_confirm.confirmed.connect(confirm_stand_ins)
	_confirm.canceled.connect(_on_stand_in_refused)
	add_child(_confirm)
	side.add_child(_heading("Chain"))
	_speed_label = _named(Label.new(), "SpeedLabel")
	side.add_child(_speed_label)
	_chain_box = _named(VBoxContainer.new(), "ChainPanel")
	side.add_child(_chain_box)
	var save_button: Button = _named(Button.new(), "SaveButton")
	save_button.text = "Save"
	save_button.tooltip_text = "Write the pending edits and regenerate the frame-data table (Ctrl+S)"
	save_button.pressed.connect(save)
	side.add_child(save_button)
	_report = _named(Label.new(), "SaveReport")
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_report)
	side.add_child(_heading("Layers"))
	_foot_lock = _named(CheckBox.new(), "FootLock")
	_foot_lock.text = "Foot locking"
	_foot_lock.button_pressed = foot_lock_on
	_foot_lock.toggled.connect(set_foot_lock)
	side.add_child(_foot_lock)
	_inertial = _named(CheckBox.new(), "InertialBlending")
	_inertial.text = "Inertial blending"
	_inertial.button_pressed = inertial_on
	_inertial.toggled.connect(set_inertial_blending)
	side.add_child(_inertial)
	_reaction = _named(CheckBox.new(), "PhysicalReaction")
	_reaction.text = "Physical reaction"
	_reaction.button_pressed = reaction_on
	_reaction.toggled.connect(set_physical_reaction)
	side.add_child(_reaction)
	var push_button: Button = _named(Button.new(), "TestPush")
	push_button.text = "Test push"
	push_button.tooltip_text = "A light Katana blow to the chest from in front, at the playhead"
	push_button.pressed.connect(push_test_blow)
	side.add_child(push_button)

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
	timeline.marker_moved.connect(_on_marker_moved)
	add_child(timeline)
	_own(self)


## The stand-in question answered no: the edit is dropped.
func _on_stand_in_refused() -> void:
	_asked = []
	_show_markers()


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
