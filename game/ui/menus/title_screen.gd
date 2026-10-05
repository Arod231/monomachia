class_name TitleScreen
extends MenuPage
## The title over the live duel behind it, as the demo's: 一騎討ち set
## down the side, the 一騎 seal, MONOMACHIA in gold, "Single combat", the
## breathing "press any key or button" and a note on the devices, over a
## soft dark pool so the text reads against the arena. It sits low on the
## screen and keeps short, so the fighters on the menu orbit show above it.
##
## Any key, mouse button or controller button goes on. Keys and buttons are
## taken in _unhandled_input() (never in _input(), so the InputFeed sees them
## too); a click lands on the screen itself. Going on plays ui_confirm. The
## title is the bottom of the menus' stack: Back goes on like any other key.

signal proceed

## The device note under the prompt.
const DEVICE_NOTE: String = "Keyboard and mouse, or any controller. Sound on."

var _prompt: Label
var _time: float = 0.0


func _init() -> void:
	super()
	back_pops = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -40.0
	column.add_theme_constant_override("separation", 10)

	# the dark pool behind the text (the demo's radial gradient)
	var pool: TextureRect = TextureRect.new()
	pool.name = "Pool"
	pool.texture = _pool_texture()
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pool.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pool.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pool.offset_left = -820.0
	pool.offset_right = 820.0
	pool.offset_top = -560.0
	pool.offset_bottom = 60.0
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(pool)
	add_child(column)

	var wrap: HBoxContainer = HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 34)
	column.add_child(wrap)
	# 一騎討ち down the side (the demo's vertical writing)
	var side: Label = UiTheme.label("一\n騎\n討\nち", UiTheme.DISPLAY, 34)
	side.name = "Vertical"
	side.add_theme_constant_override("line_spacing", 0)
	side.modulate.a = 0.9
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.add_child(side)

	var main_col: VBoxContainer = VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 10)
	wrap.add_child(main_col)
	# the seal beside the name, keeping the block short
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 22)
	main_col.add_child(name_row)
	name_row.add_child(_seal())
	var name_label: Label = UiTheme.label("MONOMACHIA", UiTheme.DISPLAY, 96)
	name_label.add_theme_color_override("font_color", UiPalette.GOLD)
	name_label.add_theme_constant_override("shadow_outline_size", 16)
	name_row.add_child(name_label)
	main_col.add_child(UiTheme.label("Single combat", UiTheme.EYEBROW, 24))

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 12.0)
	column.add_child(gap)
	_prompt = UiTheme.label("Press any key or button", UiTheme.EYEBROW, 22)
	_prompt.add_theme_color_override("font_color", UiPalette.PAPER)
	column.add_child(_prompt)
	column.add_child(UiTheme.label(DEVICE_NOTE, UiTheme.MUTED, 18))


## The 一騎 seal (the demo's .hanko): a lacquer square with the two kanji set
## downward, turned a little.
static func _seal() -> Control:
	var holder: Control = Control.new()
	holder.name = "Seal"
	holder.custom_minimum_size = Vector2(62.0, 62.0)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seal: Label = UiTheme.label("一\n騎", UiTheme.HANKO)
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.size = Vector2(62.0, 62.0)
	seal.pivot_offset = Vector2(31.0, 31.0)
	seal.rotation = deg_to_rad(-4.0)
	holder.add_child(seal)
	return holder


## A radial pool of ink, darkest at the centre and clear at 72% out.
static func _pool_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.72])
	g.colors = PackedColorArray([
		Color(UiPalette.INK, 0.78), Color(UiPalette.INK, 0.45), Color(UiPalette.INK, 0.0),
	])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.62)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 256
	t.height = 128
	return t


func reopen() -> void:
	super()
	_time = 0.0


## The prompt breathes (the demo's 2.2 s "breathe").
func _process(delta: float) -> void:
	_time += delta
	_prompt.modulate.a = 0.675 + 0.325 * cos(_time * TAU / 2.2)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _goes_on(event):
		get_viewport().set_input_as_handled()
		_go_on()


## A click on the title (it stops the mouse, so clicks end here).
func _gui_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and _goes_on(event):
		accept_event()
		_go_on()


func _go_on() -> void:
	GameServices.play_ui(&"ui_confirm")
	proceed.emit()


static func _goes_on(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false
