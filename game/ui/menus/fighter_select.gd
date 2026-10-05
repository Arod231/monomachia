class_name FighterSelect
extends MenuPage
## The fighter select, in the design's layout without the gate cinematic or
## the intros: the loadout on the left (LoadoutPanel: weapon cards, the
## blurb and ultimate, the two block abilities), the fighter grid in the middle, and
## the right side shows the fighter's 3D preview (FighterPreview, 22.7), its
## name under it in the side's colour.
##
## The sides pick one after the other, each titled for the mode (You and
## Opponent in a Duel, Red and Blue fighter in Watch, ...). On a side the
## player picks a fighter from the grid; a computer side also has a skill row
## (Easy, Normal, Hard). The last side has the arena slot (each selectable
## arena, or Random) and Lock in; the sides before it have Next. Back (the
## key, the button or the entry) steps back a side, and from the first side
## leaves the select. Lock in emits locked_in with the finished draft; the
## caller saves it and starts the match (main.gd).
##
## The page works on its own copy of a MatchSelection draft, so leaving
## without locking in changes nothing.
##
## In Versus (22.16) each player's step also picks what they play with
## ("Plays with": keyboard and mouse, the arrow-key layout, controller 1 or
## 2, a missing controller marked "not connected") and their Controls
## profile, each one option between ‹ and ›. Both players on one device, or
## a controller that isn't connected, shows a warning and refuses Lock in
## (the owner's choice, Oct 5, 2026). The draft opens on the demo's
## defaults, keyboard and mouse against the first controller, or against the
## arrow layout with no controller connected (MatchSelection.fit_devices).

## The player locked in: the draft the match is made from.
signal locked_in(draft: MatchSelection.Draft)
## A side's step was shown (start, Next, Back): the loadout panel follows it.
signal side_shown(side: int)
## The draft changed (a pick on this page or through refresh()).
signal draft_changed

## Each mode's side titles.
const TITLES: Dictionary[StringName, Array] = {
	MatchConfig.DUEL: ["You", "Opponent"],
	MatchConfig.TRAINING: ["You", "Training dummy"],
	MatchConfig.WATCH: ["Red fighter", "Blue fighter"],
	MatchConfig.VERSUS: ["Player 1", "Player 2"],
}
## Each mode's line over the heading.
const MODE_LINES: Dictionary[StringName, String] = {
	MatchConfig.DUEL: "Duel · first to 3 rounds",
	MatchConfig.TRAINING: "Training",
	MatchConfig.WATCH: "Watch",
	MatchConfig.VERSUS: "Versus · two players · first to 3 rounds",
}
## The sides' eyebrows.
const SIDE_LINES: Array[String] = ["Red · 赤", "Blue · 青"]
const SKILLS: Array[StringName] = [&"easy", &"normal", &"hard"]
const SKILL_NAMES: Array[String] = ["Easy", "Normal", "Hard"]
## Versus's devices, in the "Plays with" row's order, and their names.
const DEVICES: Array[String] = [InputDevices.KBM, InputDevices.KB_ARROWS, InputDevices.PAD0, InputDevices.PAD1]
const DEVICE_NAMES: Array[String] = ["Keyboard and mouse", "Keyboard: arrows + J K L", "Controller 1", "Controller 2"]
const NOT_CONNECTED: String = " (not connected)"
## The device chips' width: "Controller 2 (not connected)" and a margin.
const DEVICE_CHIP_WIDTH: float = 270.0

## The draft being picked (a copy until lock in).
var draft: MatchSelection.Draft
## The side being picked, 0 or 1.
var side: int = 0
## The fighters on the grid, in order.
var fighter_ids: Array[StringName] = []

var mode_line: Label
var side_line: Label
var side_title: Label
var step_label: Label
var grid: OptionRow
var skill_row: OptionRow
## Versus: the player's device and Controls profile (22.16).
var device_row: OptionRow
var profile_row: OptionRow
## Versus: why Lock in is refused (a clash, a missing controller).
var warning: Label
var arena_row: OptionRow
var confirm: Button
var back_entry: Button
## The left column, holding the loadout panel.
var loadout: VBoxContainer
## The side's weapon and block abilities (22.6).
var loadout_panel: LoadoutPanel
## The right side: the 3D preview (22.7) and the fighter's name under it.
var preview_slot: Control
var preview_name: Label
var preview: FighterPreview
## The devices the "Plays with" row checks for controllers, and the profiles
## its profile row lists: the game's (GameServices) unless given.
var input: InputDevices
var profiles: ControlProfiles


func _init(p_input: InputDevices = null, p_profiles: ControlProfiles = null) -> void:
	super()
	input = p_input if p_input != null else GameServices.input
	profiles = p_profiles if p_profiles != null else GameServices.profiles
	for id: StringName in MatchSide.FIGHTER_NAMES:
		fighter_ids.append(id)

	# an ink veil over the duel behind, so the page reads (the demo dimmed
	# its menu screens the same way)
	var veil: ColorRect = ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(UiPalette.INK, 0.62)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	margin.add_child(columns)

	# the left: the loadout panel
	var left: PanelContainer = PanelContainer.new()
	left.name = "Loadout"
	left.custom_minimum_size = Vector2(380.0, 0.0)
	left.size_flags_vertical = Control.SIZE_SHRINK_END
	columns.add_child(left)
	loadout = VBoxContainer.new()
	loadout.add_theme_constant_override("separation", 10)
	left.add_child(loadout)
	loadout_panel = LoadoutPanel.new()
	loadout.add_child(loadout_panel)
	loadout_panel.changed.connect(refresh)
	side_shown.connect(func(i: int) -> void: loadout_panel.edit(draft, i))

	# the middle: heading, side, grid, rows and the entries
	var middle: VBoxContainer = VBoxContainer.new()
	middle.name = "Middle"
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	columns.add_child(middle)
	mode_line = _left_label(UiTheme.label("", UiTheme.EYEBROW, 17))
	middle.add_child(mode_line)
	middle.add_child(_left_label(UiTheme.label("Choose your fighters", UiTheme.DISPLAY, 52)))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(spacer)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	middle.add_child(head)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	side_line = _left_label(UiTheme.label("", UiTheme.EYEBROW, 17))
	titles.add_child(side_line)
	side_title = _left_label(UiTheme.label("", UiTheme.DISPLAY, 40))
	titles.add_child(side_title)
	step_label = UiTheme.label("", UiTheme.MUTED, 20)
	step_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(step_label)

	var names: Array[String] = []
	for id: StringName in fighter_ids:
		names.append(MatchSide.FIGHTER_NAMES[id])
	grid = OptionRow.new("Fighter", names, 0)
	grid.name = "Grid"
	grid.use_cards(Vector2(190.0, 130.0))
	# a short label column, so the three columns fit the 1600 px base width
	grid.title.custom_minimum_size.x = 110.0
	grid.changed.connect(_on_fighter)
	middle.add_child(grid)
	add_item(grid)
	skill_row = OptionRow.new("Computer skill", SKILL_NAMES, 1)
	skill_row.name = "Skill"
	skill_row.changed.connect(_on_skill)
	middle.add_child(skill_row)
	add_item(skill_row)
	device_row = OptionRow.new("Plays with", DEVICE_NAMES, 0)
	device_row.name = "Device"
	device_row.show_only_chosen()
	# as wide as the longest name, so the column never shifts as it changes
	for chip: Button in device_row.chips:
		chip.custom_minimum_size.x = DEVICE_CHIP_WIDTH
	device_row.changed.connect(_on_device)
	middle.add_child(device_row)
	add_item(device_row)
	profile_row = OptionRow.new("Controls profile", [""] as Array[String], 0)
	profile_row.name = "Profile"
	profile_row.show_only_chosen()
	profile_row.changed.connect(_on_profile)
	middle.add_child(profile_row)
	add_item(profile_row)
	var arena_names: Array[String] = []
	for id: StringName in ArenaScenes.SELECTABLE:
		arena_names.append(ArenaScenes.def(id).display_name)
	arena_names.append("Random")
	arena_row = OptionRow.new("Arena", arena_names, 0)
	arena_row.name = "Arena"
	arena_row.changed.connect(_on_arena)
	middle.add_child(arena_row)
	add_item(arena_row)

	warning = UiTheme.label("", &"", 18)
	warning.name = "Warning"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# the toasts' red, light enough to read over the veil
	warning.add_theme_color_override("font_color", HudToasts.TONE_COLORS[HudToasts.Tone.RED])
	# wrapped to the column, so a long warning never widens it
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(1.0, 0.0)
	warning.visible = false
	middle.add_child(warning)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	middle.add_child(actions)
	confirm = Button.new()
	confirm.name = "Confirm"
	confirm.custom_minimum_size = Vector2(260.0, 0.0)
	confirm.pressed.connect(_on_confirm)
	actions.add_child(confirm)
	add_item(confirm)
	back_entry = Button.new()
	back_entry.name = "Back"
	back_entry.text = "Back"
	back_entry.pressed.connect(step_back)
	actions.add_child(back_entry)
	add_item(back_entry)
	for c: Control in loadout_panel.items():
		add_loadout_item(c)

	# the right: the 3D preview, the name under it
	preview_slot = Control.new()
	preview_slot.name = "Preview"
	preview_slot.custom_minimum_size = Vector2(300.0, 0.0)
	preview_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(preview_slot)
	preview = FighterPreview.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# transparent and deaf to the mouse, it reaches into the margins round the
	# slot so a raised Greatsword or a turned blade isn't clipped
	preview.offset_top = -56.0
	preview.offset_left = -100.0
	preview.offset_right = 40.0
	preview_slot.add_child(preview)
	preview_name = UiTheme.label("", UiTheme.DISPLAY, 56)
	preview_name.name = "FighterName"
	preview_name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	preview_name.offset_top = -120.0
	preview_name.offset_bottom = -40.0
	preview_slot.add_child(preview_name)


static func _left_label(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


## Opens the select on a copy of `p_draft`, on the first side.
func start(p_draft: MatchSelection.Draft) -> void:
	draft = p_draft.copy()
	MatchSelection.fit_devices(draft, input)
	mode_line.text = MODE_LINES.get(draft.mode, "")
	show_side(0)


## Shows a side's step, with its fighter focused.
func show_side(i: int) -> void:
	side = i
	var s: MatchSide = draft.sides[side]
	var titles: Array = TITLES.get(draft.mode, ["", ""])
	side_line.text = SIDE_LINES[side]
	side_title.text = titles[side]
	step_label.text = "%d / 2" % (side + 1)
	grid.set_index(maxi(fighter_ids.find(s.fighter_id), 0))
	var computer: bool = MatchSelection.controller_for(draft.mode, side) == MatchSide.COMPUTER
	skill_row.visible = computer
	skill_row.set_index(maxi(SKILLS.find(s.difficulty), 0))
	var versus: bool = draft.mode == MatchConfig.VERSUS
	device_row.visible = versus
	profile_row.visible = versus
	if versus:
		_show_profiles()
	var last: bool = side == 1
	arena_row.visible = last
	var arena_i: int = ArenaScenes.SELECTABLE.find(draft.arena)
	arena_row.set_index(arena_i if arena_i >= 0 else ArenaScenes.SELECTABLE.size())
	confirm.text = "Lock in" if last else "Next: %s" % titles[1]
	side_shown.emit(side)
	refresh()
	forget_focus()
	if visible:
		reopen()


## Makes a control of the loadout panel (22.6) an item of the page, in focus
## order after the grid and before the skill row; the caller puts it in
## `loadout`.
func add_loadout_item(c: Control) -> Control:
	add_item(c)
	items.erase(c)
	items.insert(items.find(skill_row), c)
	return c


## Back: to the side before, or out of the select from the first.
func step_back() -> void:
	if side > 0:
		show_side(side - 1)
	else:
		back_requested.emit()


func act(cmd: MenuNav.Cmd) -> void:
	if cmd == MenuNav.Cmd.BACK and side > 0:
		GameServices.play_ui(&"ui_back")
		show_side(side - 1)
		return
	super(cmd)


func _on_confirm() -> void:
	if side == 0:
		show_side(1)
		return
	# Versus refuses a clash or a missing controller (the warning says which)
	if _device_problem() != "":
		return
	locked_in.emit(draft.copy())


func _on_fighter(i: int) -> void:
	MatchSelection.set_fighter(draft, side, fighter_ids[i])
	refresh()


func _on_skill(i: int) -> void:
	MatchSelection.set_difficulty(draft, side, SKILLS[i])


func _on_device(i: int) -> void:
	MatchSelection.set_device(draft, side, DEVICES[i])
	refresh()


func _on_profile(i: int) -> void:
	MatchSelection.set_profile(draft, side, i)


## The profile row: every profile by name, on the side's own (the active
## profile when it has none yet, which the draft then takes).
func _show_profiles() -> void:
	var names: Array[String] = []
	for n: String in profiles.names():
		names.append(n)
	var s: MatchSide = draft.sides[side]
	if s.profile < 0 or s.profile >= names.size():
		MatchSelection.set_profile(draft, side, profiles.active)
	if names != _chip_texts(profile_row):
		profile_row.set_options(names, s.profile)
	else:
		profile_row.set_index(s.profile)


## The "Plays with" row: each device's name, a controller marked when it
## isn't connected, on the side's own.
func _show_devices() -> void:
	for i: int in DEVICES.size():
		var seat: int = i - DEVICES.find(InputDevices.PAD0)
		var missing: bool = seat >= 0 and not input.pad_connected(seat)
		device_row.chips[i].text = DEVICE_NAMES[i] + (NOT_CONNECTED if missing else "")
	device_row.set_index(maxi(DEVICES.find(draft.sides[side].device), 0))


func _device_problem() -> String:
	return MatchSelection.device_problem(draft, input)


static func _chip_texts(row: OptionRow) -> Array[String]:
	var out: Array[String] = []
	for c: Button in row.chips:
		out.append(c.text)
	return out


func _on_arena(i: int) -> void:
	var id: StringName = ArenaScenes.SELECTABLE[i] if i < ArenaScenes.SELECTABLE.size() else MatchSelection.RANDOM
	MatchSelection.set_arena(draft, id)


## Brings the preview (the model and its name), and in Versus the device row
## and the warning, up to the draft and tells whoever follows it
## (draft_changed). Called after every pick (the loadout
## panel applies its own and calls it too).
func refresh() -> void:
	var s: MatchSide = draft.sides[side]
	if draft.mode == MatchConfig.VERSUS:
		_show_devices()
	warning.text = _device_problem()
	warning.visible = warning.text != ""
	preview_name.text = s.display_name()
	preview_name.add_theme_color_override("font_color", LookPalette.side_color(side).lightened(0.35))
	preview.show_draft(draft, side)
	draft_changed.emit()
