class_name UiTheme
## The UI theme (milestone-1 task 53): the mood board's UI A, lacquer and
## gold. build() makes it from UiPalette's colours and the bundled fonts, and
## tools/build_ui_theme.gd saves it as ui/theme/lacquer_gold.tres, the
## project theme, which a test keeps equal to what build() makes. This class
## also names the theme's type variations and makes labels in them. Plain
## text needs no variation: the theme draws every Label in Zen Kaku Gothic
## New in ivory.
##
## The fonts: Zen Kaku Gothic New for text; Shippori Mincho B1 (Medium and
## Bold) for titles, names, buttons and spaced Latin; Yuji Boku for brushed
## kanji. The last two are cut down to the characters the game uses by
## scripts/fonts.mjs, and fall back to Zen Kaku Gothic New for anything else.

## Titles, names and announcements: Shippori Mincho B1 Bold, slightly spaced.
const DISPLAY: StringName = &"DisplayLabel"
## Kanji: brushed (Yuji Boku) in ivory.
const KANJI: StringName = &"KanjiLabel"
## Small spaced capitals in the dimmed ivory, in the serif (label() sets the
## capitals).
const EYEBROW: StringName = &"EyebrowLabel"
## Quieter text in the dimmed ivory.
const MUTED: StringName = &"MutedLabel"
## A boxed warning in the HUD (the plate's Disarmed tag): small spaced
## capitals in danger red in a thin danger-red box.
const TAG: StringName = &"HudTag"
## The title's seal: kanji in ivory on a rounded crimson lacquer square.
const HANKO: StringName = &"HankoLabel"
## A round call's word under its brushed kanji (milestone-1 task 54): small
## spaced capitals in the bold serif, in bright gold (label() sets the
## capitals).
const CALL_WORD: StringName = &"CallWord"
## A main-menu button: no box until focused, then a warm gold wash over a
## gold underline, its text pale gold.
const MENU_ENTRY: StringName = &"MenuEntry"
## A menu row (an OptionRow or SliderRow): no box, and while focused the menu
## entry's gold wash and underline (MENU_ROW_LIT).
const MENU_ROW: StringName = &"MenuRow"
const MENU_ROW_LIT: StringName = &"MenuRowLit"
## An option in a row: a small lacquer box in a line border; the chosen one
## (OPTION_ON) raised, in a gold border with pale gold text.
const OPTION: StringName = &"OptionChip"
const OPTION_ON: StringName = &"OptionChipOn"
## A card in a row of cards (the fighter select's grid): a large name on
## lacquer in a line border; the chosen one (CARD_ON) raised, in a bright
## gold border.
const CARD: StringName = &"Card"
const CARD_ON: StringName = &"CardOn"

## The project theme's file (project.godot's gui/theme/custom).
const PATH: String = "res://ui/theme/lacquer_gold.tres"
const TEXT_FONT: String = "res://ui/fonts/ZenKakuGothicNew-Regular.ttf"
const SERIF_FONT: String = "res://ui/fonts/ShipporiMinchoB1-Medium.ttf"
const SERIF_BOLD_FONT: String = "res://ui/fonts/ShipporiMinchoB1-Bold.ttf"
const BRUSH_FONT: String = "res://ui/fonts/YujiBoku-Regular.ttf"

## The gold wash behind a focused menu entry or row.
const MENU_WASH: Color = Color(UiPalette.GOLD, 0.14)
## The eyebrows' extra space between letters, in pixels (the serif's
## capitals run wider than the old sans's, so less than its 4).
const EYEBROW_SPACING: int = 2
## A round call's word's extra space between letters, in pixels (about
## half a letter, as the mock-up's).
const CALL_SPACING: int = 12
## The focused menu entry's underline, in pixels.
const UNDERLINE: int = 2


## A centred label in one of the variations (or plain text for &""), at the
## variation's size unless a size is given. Eyebrows are set in capitals.
static func label(text: String, variation: StringName = &"", font_size: int = 0) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.uppercase = variation == EYEBROW or variation == TAG or variation == CALL_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l


## The theme, made from UiPalette and the fonts. Every sub-resource has a
## fixed id, so saving it twice writes the same file.
static func build() -> Theme:
	var t: Theme = Theme.new()
	var text: FontFile = load(TEXT_FONT)
	var serif: Font = _font("serif", load(SERIF_FONT), 1, [text])
	var display: Font = _font("display", load(SERIF_BOLD_FONT), 2, [text])
	var seal: Font = _font("seal", load(SERIF_BOLD_FONT), 0, [text])
	var eyebrow: Font = _font("eyebrow", load(SERIF_FONT), EYEBROW_SPACING, [text])
	var call: Font = _font("call", load(SERIF_BOLD_FONT), CALL_SPACING, [text])
	var brush: Font = _font("brush", load(BRUSH_FONT), 0, [load(SERIF_BOLD_FONT), text])
	t.default_font = text
	t.default_font_size = 22

	t.set_color(&"font_color", &"Label", UiPalette.IVORY)
	t.set_color(&"font_shadow_color", &"Label", UiPalette.SHADOW)
	t.set_constant(&"shadow_offset_x", &"Label", 0)
	t.set_constant(&"shadow_offset_y", &"Label", 2)
	t.set_constant(&"shadow_outline_size", &"Label", 6)

	_variation(t, DISPLAY, &"Label")
	t.set_font(&"font", DISPLAY, display)
	t.set_font_size(&"font_size", DISPLAY, 40)
	_variation(t, KANJI, &"Label")
	t.set_font(&"font", KANJI, brush)
	t.set_font_size(&"font_size", KANJI, 64)
	t.set_color(&"font_color", KANJI, UiPalette.KANJI)
	_variation(t, EYEBROW, &"Label")
	t.set_font(&"font", EYEBROW, eyebrow)
	t.set_font_size(&"font_size", EYEBROW, 17)
	t.set_color(&"font_color", EYEBROW, UiPalette.IVORY_DIM)
	_variation(t, CALL_WORD, &"Label")
	t.set_font(&"font", CALL_WORD, call)
	t.set_font_size(&"font_size", CALL_WORD, 30)
	t.set_color(&"font_color", CALL_WORD, UiPalette.GOLD_BRIGHT)
	_variation(t, MUTED, &"Label")
	t.set_color(&"font_color", MUTED, UiPalette.IVORY_DIM)
	_variation(t, TAG, &"Label")
	t.set_font(&"font", TAG, eyebrow)
	t.set_font_size(&"font_size", TAG, 14)
	t.set_color(&"font_color", TAG, UiPalette.DANGER)
	var tag: StyleBoxFlat = _box("tag", Color(0, 0, 0, 0), UiPalette.DANGER, 1, Vector4(7, 1, 7, 1))
	tag.draw_center = false
	t.set_stylebox(&"normal", TAG, tag)
	_variation(t, HANKO, &"Label")
	t.set_font(&"font", HANKO, seal)
	t.set_font_size(&"font_size", HANKO, 22)
	t.set_color(&"font_color", HANKO, UiPalette.KANJI)
	t.set_constant(&"line_spacing", HANKO, -4)
	t.set_constant(&"shadow_outline_size", HANKO, 0)
	var hanko: StyleBoxFlat = _box("hanko", UiPalette.CRIMSON, Color(0, 0, 0, 0), 0, Vector4(-1, -1, -1, -1))
	hanko.set_corner_radius_all(8)
	hanko.shadow_color = Color(0, 0, 0, 0.5)
	hanko.shadow_size = 12
	hanko.shadow_offset = Vector2(0, 6)
	t.set_stylebox(&"normal", HANKO, hanko)

	# buttons: a raised lacquer box in a dim gold hairline, lit in gold
	var pad: Vector4 = Vector4(24, 12, 24, 12)
	t.set_font(&"font", &"Button", serif)
	t.set_font_size(&"font_size", &"Button", 24)
	t.set_color(&"font_color", &"Button", UiPalette.IVORY)
	t.set_color(&"font_disabled_color", &"Button", Color(UiPalette.IVORY_DIM, 0.6))
	for c: StringName in [&"font_focus_color", &"font_hover_color", &"font_hover_pressed_color", &"font_pressed_color"]:
		t.set_color(c, &"Button", UiPalette.GOLD_PALE)
	var button: StyleBoxFlat = _box("button", UiPalette.LACQUER_RAISED, UiPalette.GOLD_DIM, 1, pad)
	var button_lit: StyleBoxFlat = _box("button_lit", UiPalette.LACQUER_RAISED, UiPalette.GOLD, 1, pad)
	var button_focus: StyleBoxFlat = _box("button_focus", Color(0, 0, 0, 0), UiPalette.GOLD, 1, pad)
	button_focus.draw_center = false
	var button_pressed: StyleBoxFlat = _box("button_pressed", UiPalette.LACQUER_WARM, UiPalette.GOLD_BRIGHT, 1, pad)
	var button_disabled: StyleBoxFlat = _box("button_disabled", UiPalette.LACQUER_WARM, UiPalette.LINE, 1, pad)
	t.set_stylebox(&"normal", &"Button", button)
	t.set_stylebox(&"hover", &"Button", button_lit)
	t.set_stylebox(&"focus", &"Button", button_focus)
	t.set_stylebox(&"pressed", &"Button", button_pressed)
	t.set_stylebox(&"hover_pressed", &"Button", button_pressed)
	t.set_stylebox(&"disabled", &"Button", button_disabled)

	# menu entries and rows: unboxed, then a gold wash over a gold underline
	var menu_pad: Vector4 = Vector4(20, 12, 20, 12)
	var menu: StyleBoxFlat = _box("menu", Color(UiPalette.GOLD, 0.0), Color(0, 0, 0, 0), 0, menu_pad)
	var menu_lit: StyleBoxFlat = _box("menu_lit", MENU_WASH, UiPalette.GOLD_BRIGHT, 0, menu_pad)
	menu_lit.border_width_bottom = UNDERLINE
	_variation(t, MENU_ENTRY, &"Button")
	t.set_font_size(&"font_size", MENU_ENTRY, 22)
	for c: StringName in [&"font_focus_color", &"font_hover_color", &"font_hover_pressed_color", &"font_pressed_color"]:
		t.set_color(c, MENU_ENTRY, UiPalette.GOLD_PALE)
	t.set_stylebox(&"normal", MENU_ENTRY, menu)
	for s: StringName in [&"focus", &"hover", &"hover_pressed", &"pressed"]:
		t.set_stylebox(s, MENU_ENTRY, menu_lit)
	_variation(t, MENU_ROW, &"PanelContainer")
	t.set_stylebox(&"panel", MENU_ROW, menu)
	_variation(t, MENU_ROW_LIT, &"PanelContainer")
	t.set_stylebox(&"panel", MENU_ROW_LIT, menu_lit)

	# options
	var chip_pad: Vector4 = Vector4(12, 5, 12, 5)
	_variation(t, OPTION, &"Button")
	t.set_font(&"font", OPTION, text)
	t.set_font_size(&"font_size", OPTION, 18)
	_lit_colors(t, OPTION, UiPalette.IVORY)
	var chip: StyleBoxFlat = _box("chip", UiPalette.LACQUER_WARM, UiPalette.LINE, 1, chip_pad)
	var chip_lit: StyleBoxFlat = _box("chip_lit", UiPalette.LACQUER_WARM, UiPalette.GOLD_DIM, 1, chip_pad)
	t.set_stylebox(&"normal", OPTION, chip)
	for s: StringName in [&"focus", &"hover", &"hover_pressed", &"pressed"]:
		t.set_stylebox(s, OPTION, chip_lit)
	_variation(t, OPTION_ON, OPTION)
	_lit_colors(t, OPTION_ON, UiPalette.GOLD_PALE)
	var chip_on: StyleBoxFlat = _box("chip_on", UiPalette.LACQUER_RAISED, UiPalette.GOLD, 1, chip_pad)
	for s: StringName in [&"normal", &"focus", &"hover", &"hover_pressed", &"pressed"]:
		t.set_stylebox(s, OPTION_ON, chip_on)

	# cards
	var card_pad: Vector4 = Vector4(18, 14, 18, 14)
	_variation(t, CARD, &"Button")
	t.set_font(&"font", CARD, display)
	t.set_font_size(&"font_size", CARD, 34)
	_lit_colors(t, CARD, UiPalette.IVORY)
	var card: StyleBoxFlat = _box("card", Color(UiPalette.LACQUER_WARM, 0.92), UiPalette.LINE, 1, card_pad)
	var card_lit: StyleBoxFlat = _box("card_lit", Color(UiPalette.LACQUER_WARM, 0.92), UiPalette.GOLD_DIM, 1, card_pad)
	t.set_stylebox(&"normal", CARD, card)
	for s: StringName in [&"focus", &"hover", &"hover_pressed", &"pressed"]:
		t.set_stylebox(s, CARD, card_lit)
	_variation(t, CARD_ON, CARD)
	_lit_colors(t, CARD_ON, UiPalette.GOLD_PALE)
	var card_on: StyleBoxFlat = _box("card_on", Color(UiPalette.LACQUER_RAISED, 0.95), UiPalette.GOLD_BRIGHT, 2, card_pad)
	for s: StringName in [&"normal", &"focus", &"hover", &"hover_pressed", &"pressed"]:
		t.set_stylebox(s, CARD_ON, card_on)

	# sliders: a line track filled in gold
	var track: StyleBoxFlat = _box("slider", UiPalette.LINE, Color(0, 0, 0, 0), 0, Vector4(-1, 2, -1, 2))
	var fill: StyleBoxFlat = _box("slider_fill", UiPalette.GOLD, Color(0, 0, 0, 0), 0, Vector4(-1, 2, -1, 2))
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)

	# panels: black lacquer in a double gold hairline, a flourish at each corner
	var panel: LacquerPanel = LacquerPanel.new()
	panel.resource_scene_unique_id = "LacquerPanel_panel"
	panel.content_margin_left = 44.0
	panel.content_margin_top = 32.0
	panel.content_margin_right = 44.0
	panel.content_margin_bottom = 32.0
	t.set_stylebox(&"panel", &"Panel", panel)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	return t


static func _font(id: String, base: Font, spacing: int, fallbacks: Array) -> FontVariation:
	var f: FontVariation = FontVariation.new()
	f.resource_scene_unique_id = "FontVariation_" + id
	f.base_font = base
	f.spacing_glyph = spacing
	var list: Array[Font] = []
	list.assign(fallbacks)
	f.fallbacks = list
	return f


## A flat box: its fill, a border of the given width all round (none for 0)
## and content margins (left, top, right, bottom; -1 leaves one unset).
static func _box(id: String, bg: Color, border: Color, width: int, margins: Vector4) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.resource_scene_unique_id = "StyleBoxFlat_" + id
	b.bg_color = bg
	if width > 0:
		b.set_border_width_all(width)
		b.border_color = border
	elif border.a > 0.0:
		b.border_color = border
	b.content_margin_left = margins.x
	b.content_margin_top = margins.y
	b.content_margin_right = margins.z
	b.content_margin_bottom = margins.w
	return b


static func _variation(t: Theme, variation: StringName, base: StringName) -> void:
	t.add_type(variation)
	t.set_type_variation(variation, base)


## The same text colour in every state of a button variation.
static func _lit_colors(t: Theme, variation: StringName, color: Color) -> void:
	for c: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_hover_pressed_color", &"font_pressed_color"]:
		t.set_color(c, variation, color)
