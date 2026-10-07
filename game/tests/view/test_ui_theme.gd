extends GutTest
## The lacquer-and-gold UI theme (milestone-1 task 53, the mood board's UI
## A), which replaced the ink-wash theme (22.1): the project theme draws the
## UI in Zen Kaku Gothic New for text, Shippori Mincho B1 for titles, names,
## buttons and spaced Latin, and Yuji Boku for brushed kanji, in UiPalette's
## black lacquer, gold and ivory. Checked through the controls that use it,
## and against what UiTheme.build() makes, so the theme file and UiPalette
## can't drift apart.

const TEXT_FONT: String = "Zen Kaku Gothic New"
const SERIF_FONT: String = "Shippori Mincho B1 Medium"
const DISPLAY_FONT: String = "Shippori Mincho B1"
const BRUSH_FONT: String = "Yuji Boku"
## Fonts no screen uses any more.
const RETIRED_FONTS: Array[String] = ["Zen Antique"]
const IVORY: Color = UiPalette.IVORY
const IVORY_DIM: Color = UiPalette.IVORY_DIM
const LACQUER: Color = UiPalette.LACQUER
const LACQUER_WARM: Color = UiPalette.LACQUER_WARM
const LACQUER_RAISED: Color = UiPalette.LACQUER_RAISED
const LINE: Color = UiPalette.LINE
const GOLD: Color = UiPalette.GOLD
const GOLD_BRIGHT: Color = UiPalette.GOLD_BRIGHT
const GOLD_DIM: Color = UiPalette.GOLD_DIM
const GOLD_PALE: Color = UiPalette.GOLD_PALE


func _label(variation: StringName = &"") -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	add_child_autofree(l)
	return l


## The mood board's UI A: black lacquer, gold, ivory and the sides' crimson
## and indigo (its .ui-a rules and swatches).
func test_the_palette_is_the_mood_boards_lacquer_and_gold() -> void:
	_assert_color(UiPalette.LACQUER, Color("#060505"), "black lacquer")
	_assert_color(UiPalette.LACQUER_WARM, Color("#16110d"), "the panels' warm top")
	_assert_color(UiPalette.GOLD, Color("#b8955a"), "the gold hairline")
	_assert_color(UiPalette.GOLD_BRIGHT, Color("#d7b14b"), "the chosen underline")
	_assert_color(UiPalette.KANJI, Color("#efe6d2"), "the brushed kanji's ivory")
	_assert_color(UiPalette.CRIMSON, Color("#c0392f"), "crimson")
	_assert_color(UiPalette.INDIGO, Color("#5a78c0"), "indigo")
	for name: String in ["INK", "INK_2", "INK_3", "PAPER", "PAPER_DIM", "LACQUER_DEEP", "HP_HI", "HP_LO", "LIT_TEXT"]:
		assert_false((UiPalette as Script).get_script_constant_map().has(name), "the ink-wash %s retired" % name)


## The project theme is the file UiTheme.build() saves: the same text once
## each external resource's id is replaced by its path.
func test_the_project_theme_is_the_one_the_builder_makes() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), UiTheme.PATH)
	var built: String = "user://test_ui_theme_built.tres"
	assert_eq(ResourceSaver.save(UiTheme.build(), built), OK)
	var want: String = _normalised(FileAccess.get_file_as_string(built))
	var got: String = _normalised(FileAccess.get_file_as_string(UiTheme.PATH))
	DirAccess.remove_absolute(built)
	assert_eq(got, want, "run node scripts/godot.mjs script res://tools/build_ui_theme.gd")


static func _normalised(text: String) -> String:
	var ids: Dictionary = {}
	var re: RegEx = RegEx.create_from_string("\\[ext_resource type=\"[^\"]+\"(?: uid=\"[^\"]+\")? path=\"([^\"]+)\" id=\"([^\"]+)\"\\]")
	for m: RegExMatch in re.search_all(text):
		ids[m.get_string(2)] = m.get_string(1)
	var out: PackedStringArray = []
	for line: String in text.split("\n"):
		if line.begins_with("[ext_resource"):
			continue
		for id: String in ids:
			line = line.replace("ExtResource(\"%s\")" % id, "ExtResource(\"%s\")" % ids[id])
		out.append(line)
	return "\n".join(out).strip_edges()


func test_plain_text_is_zen_kaku_gothic_new_in_ivory() -> void:
	var l: Label = _label()
	assert_eq(l.get_theme_font(&"font").get_font_name(), TEXT_FONT)
	_assert_color(l.get_theme_color(&"font_color"), IVORY)


func test_display_text_is_shippori_mincho_bold_in_ivory() -> void:
	var l: Label = _label(UiTheme.DISPLAY)
	var font: Font = l.get_theme_font(&"font")
	assert_eq(font.get_font_name(), DISPLAY_FONT)
	assert_eq(font.get_font_weight(), 700)
	_assert_color(l.get_theme_color(&"font_color"), IVORY)


func test_kanji_are_brushed_in_ivory() -> void:
	var l: Label = _label(UiTheme.KANJI)
	assert_eq(l.get_theme_font(&"font").get_font_name(), BRUSH_FONT)
	_assert_color(l.get_theme_color(&"font_color"), UiPalette.KANJI)


func test_muted_text_is_zen_kaku_gothic_new_in_dim_ivory() -> void:
	var l: Label = _label(UiTheme.MUTED)
	assert_eq(l.get_theme_font(&"font").get_font_name(), TEXT_FONT)
	_assert_color(l.get_theme_color(&"font_color"), IVORY_DIM)


## Eyebrows are the spaced serif: the same word sets wider than the serif
## unspaced at the same size.
func test_eyebrows_are_the_serif_spaced_out_in_dim_ivory() -> void:
	var eyebrow: Label = _label(UiTheme.EYEBROW)
	var font: Font = eyebrow.get_theme_font(&"font")
	assert_eq(font.get_font_name(), SERIF_FONT)
	_assert_color(eyebrow.get_theme_color(&"font_color"), IVORY_DIM)
	var size: int = eyebrow.get_theme_font_size(&"font_size")
	var spaced: float = font.get_string_size("ROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var unspaced: float = (load(UiTheme.SERIF_FONT) as Font).get_string_size("ROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	assert_almost_eq(spaced, unspaced + UiTheme.EYEBROW_SPACING * 5.0, 1.0, "the spacing after each of the five letters")
	assert_gt(UiTheme.EYEBROW_SPACING, 1)


## The serif and the brush fall back to Zen Kaku Gothic New for anything
## their cuts lack.
func test_the_cut_fonts_fall_back_to_the_text_font() -> void:
	for variation: StringName in [UiTheme.DISPLAY, UiTheme.KANJI, UiTheme.EYEBROW]:
		var font: Font = _label(variation).get_theme_font(&"font")
		var names: Array[String] = []
		for f: Font in font.fallbacks:
			names.append(f.get_font_name())
		assert_has(names, TEXT_FONT, String(variation))


func _button(variation: StringName = &"") -> Button:
	var b: Button = Button.new()
	b.theme_type_variation = variation
	add_child_autofree(b)
	return b


func _flat(c: Control, style: StringName) -> StyleBoxFlat:
	var box: StyleBox = c.get_theme_stylebox(style)
	assert_true(box is StyleBoxFlat, "%s is a flat style" % style)
	return box as StyleBoxFlat


func _border(box: StyleBoxFlat) -> Array[int]:
	return [box.border_width_left, box.border_width_top, box.border_width_right, box.border_width_bottom]


## Buttons: the serif on raised lacquer in a 1 px dim gold hairline; focus
## and hover turn it gold and the text pale gold; pressed is the warm
## lacquer in bright gold.
func test_buttons_are_lacquer_in_a_gold_hairline_and_light_up_on_focus() -> void:
	var b: Button = _button()
	assert_eq(b.get_theme_font(&"font").get_font_name(), SERIF_FONT)
	_assert_color(b.get_theme_color(&"font_color"), IVORY)
	var normal: StyleBoxFlat = _flat(b, &"normal")
	_assert_color(normal.bg_color, LACQUER_RAISED)
	_assert_color(normal.border_color, GOLD_DIM)
	assert_eq(_border(normal), [1, 1, 1, 1] as Array[int])
	for state: StringName in [&"focus", &"hover"]:
		var lit: StyleBoxFlat = _flat(b, state)
		_assert_color(lit.border_color, GOLD, String(state))
		assert_eq(_border(lit), [1, 1, 1, 1] as Array[int], String(state))
	_assert_color(b.get_theme_color(&"font_focus_color"), GOLD_PALE)
	_assert_color(b.get_theme_color(&"font_hover_color"), GOLD_PALE)
	var pressed: StyleBoxFlat = _flat(b, &"pressed")
	_assert_color(pressed.bg_color, LACQUER_WARM)
	_assert_color(pressed.border_color, GOLD_BRIGHT)


## Main-menu buttons (as the mock-up's menu): no box until focused or
## hovered, then a warm gold wash over a gold underline, the text pale gold.
## No red anywhere. (Godot draws a button's focus box only when the focus
## came from keys or a controller, so the mouse, which focuses what it
## hovers, shows the hover box alone.)
func test_menu_buttons_show_a_gold_underline_when_focused_or_hovered() -> void:
	var b: Button = _button(UiTheme.MENU_ENTRY)
	assert_eq(b.get_theme_font(&"font").get_font_name(), SERIF_FONT)
	assert_eq(_flat(b, &"normal").bg_color.a, 0.0)
	assert_eq(_border(_flat(b, &"normal")), [0, 0, 0, 0] as Array[int])
	for state: StringName in [&"focus", &"hover", &"pressed", &"hover_pressed"]:
		var lit: StyleBoxFlat = _flat(b, state)
		_assert_color(Color(lit.bg_color, 1.0), GOLD, String(state))
		assert_almost_eq(lit.bg_color.a, 0.14, 0.01, String(state))
		_assert_color(lit.border_color, GOLD_BRIGHT, String(state))
		assert_eq(_border(lit), [0, 0, 0, UiTheme.UNDERLINE] as Array[int], String(state))
	for color: StringName in [&"font_focus_color", &"font_hover_color", &"font_pressed_color"]:
		_assert_color(b.get_theme_color(color), GOLD_PALE, String(color))


func _panel_style(c: Control) -> LacquerPanel:
	var box: StyleBox = c.get_theme_stylebox(&"panel")
	assert_true(box is LacquerPanel, "a lacquer panel")
	return box as LacquerPanel


## Panels (the mock-up's .menu): black lacquer shading from the warm top, in
## a gold hairline with a fainter one inset inside it, a shadow under it,
## and a gold flourish at each corner.
func test_panels_are_lacquer_in_a_double_gold_hairline_with_a_flourish() -> void:
	var p: PanelContainer = PanelContainer.new()
	add_child_autofree(p)
	var box: LacquerPanel = _panel_style(p)
	_assert_color(box.fill_top, LACQUER_WARM, "the warm top")
	_assert_color(box.fill_bottom, LACQUER, "the black foot")
	_assert_color(box.edge_color, GOLD, "the hairline")
	_assert_color(Color(box.inner_color, 1.0), GOLD, "the inner hairline")
	assert_lt(box.inner_color.a, 0.6, "fainter")
	assert_gt(box.inner_inset, 3.0)
	assert_true(box.flourish)
	_assert_color(box.flourish_color, GOLD)
	assert_gt(box.shadow_size, 0.0)
	assert_eq(box.get_margin(SIDE_LEFT), 44.0)
	assert_eq(box.get_margin(SIDE_TOP), 32.0)
	var plain: Panel = Panel.new()
	add_child_autofree(plain)
	assert_eq(plain.get_theme_stylebox(&"panel"), box, "a Panel too")


## The flourish: three tapering grasses in each corner, inside the inner
## hairline and within the flourish's reach of its corner, fanning inward.
func test_the_flourish_is_three_grasses_in_each_corner_inside_the_hairline() -> void:
	var box: LacquerPanel = LacquerPanel.new()
	var rect: Rect2 = Rect2(100.0, 50.0, 600.0, 400.0)
	var strokes: Array[PackedVector2Array] = box.flourish_strokes(rect)
	assert_eq(strokes.size(), 12)
	var inner: Rect2 = rect.grow(-box.inner_inset)
	var corners: Array[Vector2] = [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	for k: int in 4:
		for g: int in 3:
			var poly: PackedVector2Array = strokes[k * 3 + g]
			assert_gt(poly.size(), 10, "a curve, not a line")
			for p: Vector2 in poly:
				assert_true(inner.grow(0.01).has_point(p), "inside the inner hairline: %s" % p)
				assert_lt(p.distance_to(corners[k]), box.flourish_size * 1.5, "near its corner")
			assert_false(Geometry2D.triangulate_polygon(poly).is_empty(), "a drawable polygon")
	# the grasses taper: the polygon is wider near the base than near the tip
	var grass: PackedVector2Array = box.grass_polygon(LacquerPanel.GRASSES[1])
	var n: int = LacquerPanel.GRASS_STEPS
	var base_width: float = grass[0].distance_to(grass[grass.size() - 1])
	var tip_width: float = grass[n - 1].distance_to(grass[n + 1])
	assert_gt(base_width, tip_width * 3.0)


## The shadow lies outside the panel, so the panel's drawing reaches past
## its rect by the shadow; without a shadow it stays inside.
func test_the_panels_drawing_reaches_out_to_its_shadow() -> void:
	var box: LacquerPanel = LacquerPanel.new()
	var rect: Rect2 = Rect2(0.0, 0.0, 200.0, 100.0)
	var drawn: Rect2 = box._get_draw_rect(rect)
	assert_true(drawn.encloses(rect))
	assert_eq(drawn.end.y, rect.end.y + box.shadow_offset.y + box.shadow_size, "down to the shadow's foot")
	assert_eq(drawn.position.x, rect.position.x - box.shadow_size, "out to its side")
	box.shadow_size = 0.0
	assert_eq(box._get_draw_rect(rect), rect)


## Colours read back from the theme file match to float precision.
func _assert_color(got: Color, want: Color, what: String = "") -> void:
	assert_true(got.is_equal_approx(want), "%s %s is %s" % [what, got, want])


## Every kanji the demo's UI shows (v0.1-web-mvp:src/ui/menus.ts, hud.ts and data.ts: the
## title, seals, ultimate badge, round and fight calls, results, pause and the
## weapons' kanji), which the screens still to come take over, and Warrior
## Slain (討死, task 72). scripts/fonts.mjs keeps the same in the cut fonts.
const DEMO_KANJI: String = "一騎討ち赤青奥義第二三四五六七八九戦始め武器喪失相打本勝敗利北決着休止危刀双短大剣死"
## The controller buttons' names (InputBindingLabels) and the arrow keys.
const BUTTON_SYMBOLS: String = "×○□△↑↓←→"
## The game's own folders that hold no UI text.
const NOT_UI: Array[String] = ["res://addons", "res://tests", "res://.godot", "res://_scratch"]


## The Japanese characters (kana, kanji, full-width forms) in a string.
static func _japanese(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if (c >= 0x3000 and c <= 0x30FF) or (c >= 0x3400 and c <= 0x9FFF) or (c >= 0xFF00 and c <= 0xFFEF):
			if not out.contains(text[i]):
				out += text[i]
	return out


## The Japanese characters in the game's scripts and scenes.
static func _game_japanese(dir_path: String = "res://") -> String:
	var out: String = ""
	var dir: DirAccess = DirAccess.open(dir_path)
	for sub: String in dir.get_directories():
		var p: String = dir_path.path_join(sub)
		if not NOT_UI.has(p):
			out += _game_japanese(p)
	for file: String in dir.get_files():
		if file.get_extension() in ["gd", "tscn", "tres"]:
			out += _japanese(FileAccess.get_file_as_string(dir_path.path_join(file)))
	return out


func _missing(font: Font, chars: String) -> String:
	var out: String = ""
	for i: int in chars.length():
		if not font.has_char(chars.unicode_at(i)):
			out += chars[i]
	return out


## Every font the UI draws Japanese in has every kanji the UI uses, the cut
## ones on their own (not through their fallback): when new text brings a
## new one, run node scripts/fonts.mjs.
func test_every_font_has_every_kanji_the_ui_uses() -> void:
	var chars: String = _japanese(DEMO_KANJI + _game_japanese())
	assert_gt(chars.length(), _japanese(DEMO_KANJI).length(), "the scan finds the game's own Japanese too")
	for path: String in [UiTheme.TEXT_FONT, UiTheme.SERIF_FONT, UiTheme.SERIF_BOLD_FONT, UiTheme.BRUSH_FONT]:
		var font: Font = load(path)
		assert_eq(_missing(font, chars), "", "%s lacks these; run node scripts/fonts.mjs" % path)


## Text names buttons in prompts, and buttons and titles are set in the
## serif: both have the symbols.
func test_the_text_font_and_the_serif_have_the_button_symbols() -> void:
	for path: String in [UiTheme.TEXT_FONT, UiTheme.SERIF_FONT, UiTheme.SERIF_BOLD_FONT]:
		assert_eq(_missing(load(path), BUTTON_SYMBOLS), "", "%s lacks these" % path)


## The cut fonts have every printable ASCII character.
func test_the_cut_fonts_have_ascii() -> void:
	var ascii: String = ""
	for c: int in range(0x20, 0x7f):
		ascii += String.chr(c)
	for path: String in [UiTheme.SERIF_FONT, UiTheme.SERIF_BOLD_FONT, UiTheme.BRUSH_FONT]:
		assert_eq(_missing(load(path), ascii), "", "%s lacks these" % path)


## The cut fonts stay small (the whole Shippori Mincho B1 is about 15 MB a
## weight and Yuji Boku 8.5 MB); every bundled font has its licence beside
## it, and the retired fonts are gone.
func test_the_bundled_fonts_are_small_and_licensed() -> void:
	for path: String in [UiTheme.SERIF_FONT, UiTheme.SERIF_BOLD_FONT, UiTheme.BRUSH_FONT]:
		assert_lt(FileAccess.get_file_as_bytes(path).size(), 1024 * 1024, "%s is cut" % path)
	for licence: String in ["ZenKakuGothicNew-OFL.txt", "ShipporiMinchoB1-OFL.txt", "YujiBoku-OFL.txt"]:
		assert_true(FileAccess.file_exists("res://ui/fonts/" + licence), licence)
	assert_false(FileAccess.file_exists("res://ui/fonts/ZenAntique-Regular.ttf"), "Zen Antique retired")
	assert_false(FileAccess.file_exists("res://ui/theme/ink_wash.tres"), "the ink-wash theme retired")


const STYLES: Array[StringName] = [&"normal", &"hover", &"focus", &"pressed", &"panel"]


static func _controls(n: Node, out: Array[Control] = []) -> Array[Control]:
	if n is Control:
		out.append(n as Control)
	for c: Node in n.get_children():
		_controls(c, out)
	return out


static func _labelled(root: Node, text: String) -> Control:
	for c: Control in _controls(root):
		if (c is Label and (c as Label).text == text) or (c is Button and (c as Button).text == text):
			return c
	return null


## No text or box on the screens sets its own font or style: they all come
## from the theme. Nor is any drawn in a retired font.
func _assert_themed(root: Node) -> void:
	for c: Control in _controls(root):
		assert_false(c.has_theme_font_override(&"font"), "%s sets its own font" % c.get_path())
		for style: StringName in STYLES:
			assert_false(c.has_theme_stylebox_override(style), "%s sets its own %s style" % [c.get_path(), style])
		if c is Label or c is Button:
			assert_false(RETIRED_FONTS.has(c.get_theme_font(&"font").get_font_name()), "%s is in a retired font" % c.get_path())


func _font_of(c: Control) -> String:
	return c.get_theme_font(&"font").get_font_name() if c != null else "(missing)"


func test_the_title_is_set_in_the_theme() -> void:
	var title: TitleScreen = TitleScreen.new()
	add_child_autofree(title)
	_assert_themed(title)
	var name_label: Label = _labelled(title, "MONOMACHIA") as Label
	assert_eq(_font_of(name_label), DISPLAY_FONT)
	_assert_color(name_label.get_theme_color(&"font_color"), GOLD, "the gold name")
	var prompt: Control = _labelled(title, "Press any key or button")
	assert_eq(_font_of(prompt), SERIF_FONT, "a spaced eyebrow")
	# 一騎討ち brushed down the side, the 一騎 seal, the device note
	var side: Label = _labelled(title, "一\n騎\n討\nち") as Label
	assert_eq(_font_of(side), BRUSH_FONT)
	_assert_color(side.get_theme_color(&"font_color"), UiPalette.KANJI, "the brushed kanji")
	var seal: Label = _labelled(title, "一\n騎") as Label
	assert_eq(_font_of(seal), DISPLAY_FONT)
	_assert_color(_flat(seal, &"normal").bg_color, UiPalette.CRIMSON, "the crimson seal")
	assert_eq(_flat(seal, &"normal").corner_radius_top_left, 8)
	assert_not_null(_labelled(title, TitleScreen.DEVICE_NOTE))


func test_the_main_menu_has_the_logo_over_its_entries() -> void:
	var menu: MainMenu = MainMenu.new()
	add_child_autofree(menu)
	var duel: Button = menu.add_button("Duel", "vs computer", func() -> void: pass)
	_assert_themed(menu)
	var logo: Label = _labelled(menu, "MONOMACHIA") as Label
	assert_eq(_font_of(logo), DISPLAY_FONT)
	_assert_color(logo.get_theme_color(&"font_color"), GOLD, "the gold logo")
	assert_not_null(_labelled(menu, "一騎討ち · Single combat"))
	var sub: Label = duel.get_node("Sub")
	assert_eq(sub.theme_type_variation, UiTheme.EYEBROW, "the sublabel is small spaced capitals")
	assert_true(sub.uppercase)
	assert_eq(duel.text, "Duel", "the entry's own text is its name")


func test_menus_are_a_themed_panel_of_menu_entries_under_a_display_heading() -> void:
	var menu: MenuScreen = MenuScreen.new()
	add_child_autofree(menu)
	menu.add_heading("Paused")
	var resume: Button = menu.add_button("Resume", "", func() -> void: pass)
	_assert_themed(menu)
	assert_eq(_font_of(_labelled(menu, "Paused")), DISPLAY_FONT)
	assert_eq(_font_of(resume), SERIF_FONT)
	var lit: StyleBoxFlat = _flat(resume, &"focus")
	_assert_color(lit.border_color, GOLD_BRIGHT, "the gold underline")
	assert_eq(lit.border_width_bottom, UiTheme.UNDERLINE)
	assert_eq(lit.border_width_left, 0, "no bar down the side")
	var panel: LacquerPanel = _panel_style(menu.panel)
	assert_true(panel.flourish, "the menu's panel has its flourish")


## The menus' option and slider rows (22.2): unboxed until focused, then the
## menu entry's gold wash and underline; options as small lacquer boxes, the
## chosen one raised in gold.
func test_option_and_slider_rows_are_set_in_the_theme() -> void:
	var menu: MenuScreen = MenuScreen.new()
	add_child_autofree(menu)
	var row: OptionRow = menu.add_options("Graphics", ["High", "Low"] as Array[String], 0, func(_i: int) -> void: pass)
	var slider: SliderRow = menu.add_slider("Music", 50, func(_v: int) -> void: pass)
	_assert_themed(menu)
	assert_false(_flat(row, &"panel").draw_center and _flat(row, &"panel").bg_color.a > 0.0, "no box until focused")
	row.grab_focus()
	_assert_color(_flat(row, &"panel").border_color, GOLD_BRIGHT, "the gold underline")
	assert_eq(_flat(row, &"panel").border_width_bottom, UiTheme.UNDERLINE)
	var on: StyleBoxFlat = _flat(row.chips[0], &"normal")
	_assert_color(on.border_color, GOLD, "the chosen option")
	_assert_color(on.bg_color, LACQUER_RAISED)
	_assert_color(row.chips[0].get_theme_color(&"font_color"), GOLD_PALE)
	var off: StyleBoxFlat = _flat(row.chips[1], &"normal")
	_assert_color(off.border_color, LINE, "the others")
	_assert_color(off.bg_color, LACQUER_WARM)
	_assert_color(_flat(row.chips[1], &"hover").border_color, GOLD_DIM, "a hovered option")
	assert_eq(_font_of(row.chips[0]), TEXT_FONT)
	_assert_color(_flat(slider.slider, &"grabber_area").bg_color, GOLD, "the slider's fill")
	_assert_color(_flat(slider.slider, &"slider").bg_color, LINE, "and its track")


func test_cards_are_lacquer_and_the_chosen_one_is_raised_in_bright_gold() -> void:
	var card: Button = _button(UiTheme.CARD)
	var chosen: Button = _button(UiTheme.CARD_ON)
	assert_eq(_font_of(card), DISPLAY_FONT)
	_assert_color(Color(_flat(card, &"normal").bg_color, 1.0), LACQUER_WARM)
	_assert_color(_flat(card, &"normal").border_color, LINE)
	_assert_color(Color(_flat(chosen, &"normal").bg_color, 1.0), LACQUER_RAISED)
	_assert_color(_flat(chosen, &"normal").border_color, GOLD_BRIGHT)
	assert_eq(_border(_flat(chosen, &"normal")), [2, 2, 2, 2] as Array[int])
	_assert_color(chosen.get_theme_color(&"font_color"), GOLD_PALE)


func test_results_are_set_in_the_theme() -> void:
	var results: ResultsScreen = ResultsScreen.new()
	add_child_autofree(results)
	var r: MatchResults = MatchResults.new()
	r.names = ["Rogue", "Hunter"] as Array[String]
	r.weapons = ["Katana", "Greatsword"] as Array[String]
	results.show_results(r)
	_assert_themed(results)
	assert_eq(_font_of(_labelled(results, r.title())), DISPLAY_FONT)
	_assert_color(_labelled(results, "Rounds won").get_theme_color(&"font_color"), IVORY_DIM, "a stat's name")


func test_the_hud_is_set_in_the_theme() -> void:
	var hud: MatchHud = MatchHud.new()
	add_child_autofree(hud)
	_assert_themed(hud)
	assert_eq(_font_of(hud.find_child("Announce", true, false) as Control), DISPLAY_FONT)
	assert_eq(_font_of(hud.find_child("Plate0", true, false) as Control), DISPLAY_FONT)
	# a toast in the display font (24.3), a prompt and its key cap in the
	# text font (24.4)
	hud.toasts.push("Parry", HudToasts.Tone.GOLD)
	assert_eq(_font_of(hud.toasts.get_child(0).get_node("Text") as Control), DISPLAY_FONT)
	hud.prompts.show_prompts([{"parts": ["Pick up your weapon ", HudPrompts.key("E")], "urgent": true}] as Array[Dictionary])
	var row: Node = hud.prompts.get_child(0).get_node("Row")
	assert_eq(_font_of(row.get_child(0) as Control), TEXT_FONT, "a prompt's text")
	assert_eq(_font_of(row.get_child(1).get_node("Name") as Control), TEXT_FONT, "a key cap")


## The HUD's tags (the plate's Disarmed tag): spaced capitals in danger red
## in a 1 px danger-red box.
func test_tags_are_danger_red_in_a_thin_box() -> void:
	var tag: Label = UiTheme.label("Disarmed", UiTheme.TAG)
	add_child_autofree(tag)
	assert_true(tag.uppercase)
	_assert_color(tag.get_theme_color(&"font_color"), UiPalette.DANGER)
	var box: StyleBoxFlat = _flat(tag, &"normal")
	_assert_color(box.border_color, UiPalette.DANGER)
	assert_eq(_border(box), [1, 1, 1, 1] as Array[int])
	assert_false(box.draw_center)
