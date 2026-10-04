extends GutTest
## The ink-wash UI theme (task 22.1): the project theme draws the UI in the
## demo's fonts (Zen Kaku Gothic New for text, Zen Antique for titles and
## kanji) and colours (UiPalette, the demo's src/ui/style.css), checked through
## the controls that use it, so the theme file and UiPalette can't drift apart.

const UI_FONT: String = "Zen Kaku Gothic New"
const DISPLAY_FONT: String = "Zen Antique"
const PAPER: Color = UiPalette.PAPER
const PAPER_DIM: Color = UiPalette.PAPER_DIM
const LACQUER: Color = UiPalette.LACQUER
const LACQUER_DEEP: Color = UiPalette.LACQUER_DEEP
const INK_2: Color = UiPalette.INK_2
const INK_3: Color = UiPalette.INK_3
const LINE: Color = UiPalette.LINE
const GOLD: Color = UiPalette.GOLD
const GOLD_DIM: Color = UiPalette.GOLD_DIM
const LIT_TEXT: Color = UiPalette.LIT_TEXT


func _label(variation: StringName = &"") -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	add_child_autofree(l)
	return l


func test_plain_text_is_zen_kaku_gothic_new_in_paper() -> void:
	var l: Label = _label()
	assert_eq(l.get_theme_font(&"font").get_font_name(), UI_FONT)
	_assert_color(l.get_theme_color(&"font_color"), PAPER)


func test_display_text_is_zen_antique_in_paper() -> void:
	var l: Label = _label(UiTheme.DISPLAY)
	assert_eq(l.get_theme_font(&"font").get_font_name(), DISPLAY_FONT)
	_assert_color(l.get_theme_color(&"font_color"), PAPER)


func test_kanji_are_zen_antique_in_lacquer() -> void:
	var l: Label = _label(UiTheme.KANJI)
	assert_eq(l.get_theme_font(&"font").get_font_name(), DISPLAY_FONT)
	_assert_color(l.get_theme_color(&"font_color"), LACQUER)


func test_muted_text_is_zen_kaku_gothic_new_in_paper_dim() -> void:
	var l: Label = _label(UiTheme.MUTED)
	assert_eq(l.get_theme_font(&"font").get_font_name(), UI_FONT)
	_assert_color(l.get_theme_color(&"font_color"), PAPER_DIM)


## The demo's eyebrows are letter-spaced: the same word sets wider than plain
## text at the same size.
func test_eyebrows_are_spaced_out_zen_kaku_gothic_new_in_paper_dim() -> void:
	var eyebrow: Label = _label(UiTheme.EYEBROW)
	var plain: Label = _label()
	var font: Font = eyebrow.get_theme_font(&"font")
	assert_eq(font.get_font_name(), UI_FONT)
	_assert_color(eyebrow.get_theme_color(&"font_color"), PAPER_DIM)
	var size: int = eyebrow.get_theme_font_size(&"font_size")
	var spaced: float = font.get_string_size("ROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var unspaced: float = plain.get_theme_font(&"font").get_string_size("ROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	assert_gt(spaced, unspaced + 3.0 * 4.0, "more than 3 px more in each of the four gaps between the letters")


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


## The demo's .btn: Zen Antique on --ink-3 in a 1 px --gold-dim border; focus
## and hover turn the border --gold and the text #ffe6b0; pressed is
## --lacquer-deep in a --lacquer border.
func test_buttons_are_ink_in_a_gold_border_and_light_up_on_focus() -> void:
	var b: Button = _button()
	assert_eq(b.get_theme_font(&"font").get_font_name(), DISPLAY_FONT)
	_assert_color(b.get_theme_color(&"font_color"), PAPER)
	var normal: StyleBoxFlat = _flat(b, &"normal")
	_assert_color(normal.bg_color, INK_3)
	_assert_color(normal.border_color, GOLD_DIM)
	assert_eq(_border(normal), [1, 1, 1, 1] as Array[int])
	for state: StringName in [&"focus", &"hover"]:
		var lit: StyleBoxFlat = _flat(b, state)
		_assert_color(lit.border_color, GOLD, String(state))
		assert_eq(_border(lit), [1, 1, 1, 1] as Array[int], String(state))
	_assert_color(b.get_theme_color(&"font_focus_color"), LIT_TEXT)
	_assert_color(b.get_theme_color(&"font_hover_color"), LIT_TEXT)
	var pressed: StyleBoxFlat = _flat(b, &"pressed")
	_assert_color(pressed.bg_color, LACQUER_DEEP)
	_assert_color(pressed.border_color, LACQUER)


## The demo's main-menu buttons (.mbtn): no box until focused or hovered,
## then a --lacquer wash with a 3 px --lacquer bar down the left edge, the
## text staying paper. (Godot draws a button's focus box only when the focus
## came from keys or a controller, so the mouse, which focuses what it hovers,
## shows the hover box alone.)
func test_menu_buttons_show_a_lacquer_bar_when_focused_or_hovered() -> void:
	var b: Button = _button(UiTheme.MENU_ENTRY)
	assert_eq(b.get_theme_font(&"font").get_font_name(), DISPLAY_FONT)
	assert_eq(_flat(b, &"normal").bg_color.a, 0.0)
	assert_eq(_border(_flat(b, &"normal")), [0, 0, 0, 0] as Array[int])
	for state: StringName in [&"focus", &"hover", &"pressed", &"hover_pressed"]:
		var lit: StyleBoxFlat = _flat(b, state)
		_assert_color(Color(lit.bg_color, 1.0), LACQUER, String(state))
		assert_almost_eq(lit.bg_color.a, 0.35, 0.01, String(state))
		_assert_color(lit.border_color, LACQUER, String(state))
		assert_eq(_border(lit), [3, 0, 0, 0] as Array[int], String(state))
	for color: StringName in [&"font_focus_color", &"font_hover_color", &"font_pressed_color"]:
		_assert_color(b.get_theme_color(color), PAPER, String(color))


## The demo's .panel: --ink-2 at 95% in a 1 px --line border, with a shadow.
func test_panels_are_ink_in_a_line_border() -> void:
	var p: PanelContainer = PanelContainer.new()
	add_child_autofree(p)
	var box: StyleBoxFlat = _flat(p, &"panel")
	_assert_color(Color(box.bg_color, 1.0), INK_2)
	assert_almost_eq(box.bg_color.a, 0.95, 0.01)
	_assert_color(box.border_color, LINE)
	assert_eq(_border(box), [1, 1, 1, 1] as Array[int])
	assert_gt(box.shadow_size, 0)


## Colours read back from the theme file match to float precision.
func _assert_color(got: Color, want: Color, what: String = "") -> void:
	assert_true(got.is_equal_approx(want), "%s %s is %s" % [what, got, want])


## Every kanji the demo's UI shows (src/ui/menus.ts, hud.ts and data.ts: the
## title, seals, ultimate badge, round and fight calls, results, pause and the
## weapons' kanji), which the screens still to come take over.
const DEMO_KANJI: String = "一騎討ち赤青奥義第二三四五六七八九戦始め武器喪失相打本勝敗利北決着休止危刀双短大剣"
## The controller buttons' names (InputBindingLabels) and the arrow keys.
const BUTTON_SYMBOLS: String = "×○□△↑↓←→"
## The game's own folders that hold no UI text.
const NOT_UI: Array[String] = ["res://addons", "res://tests", "res://.godot"]


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


func test_both_fonts_have_every_kanji_the_ui_uses() -> void:
	var chars: String = _japanese(DEMO_KANJI + _game_japanese())
	assert_gt(chars.length(), _japanese(DEMO_KANJI).length(), "the scan finds the game's own Japanese too")
	for variation: StringName in [&"", UiTheme.KANJI]:
		var font: Font = _label(variation).get_theme_font(&"font")
		assert_eq(_missing(font, chars), "", "%s lacks these" % font.get_font_name())


## Both fonts: text names buttons in prompts, and buttons and titles are set in
## Zen Antique.
func test_both_fonts_have_the_button_symbols() -> void:
	for variation: StringName in [&"", UiTheme.DISPLAY]:
		var font: Font = _label(variation).get_theme_font(&"font")
		assert_eq(_missing(font, BUTTON_SYMBOLS), "", "%s lacks these" % font.get_font_name())


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


## No text or box on the stand-in screens sets its own font or style: they
## all come from the theme.
func _assert_themed(root: Node) -> void:
	for c: Control in _controls(root):
		assert_false(c.has_theme_font_override(&"font"), "%s sets its own font" % c.get_path())
		for style: StringName in STYLES:
			assert_false(c.has_theme_stylebox_override(style), "%s sets its own %s style" % [c.get_path(), style])


func _font_of(c: Control) -> String:
	return c.get_theme_font(&"font").get_font_name() if c != null else "(missing)"


func test_the_title_is_set_in_the_theme() -> void:
	var title: TitleScreen = TitleScreen.new()
	add_child_autofree(title)
	_assert_themed(title)
	assert_eq(_font_of(_labelled(title, "MONOMACHIA")), DISPLAY_FONT)
	var prompt: Control = _labelled(title, "Press any key or button")
	assert_eq(_font_of(prompt), UI_FONT)
	# the demo's title: 一騎討ち down the side, the 一騎 seal, the device note
	assert_eq(_font_of(_labelled(title, "一\n騎\n討\nち")), DISPLAY_FONT)
	var seal: Label = _labelled(title, "一\n騎") as Label
	assert_eq(_font_of(seal), DISPLAY_FONT)
	_assert_color(_flat(seal, &"normal").bg_color, LACQUER, "the seal")
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
	assert_eq(_font_of(resume), DISPLAY_FONT)
	var lit: StyleBoxFlat = _flat(resume, &"focus")
	_assert_color(lit.border_color, LACQUER, "the focus bar")
	assert_eq(lit.border_width_left, 3)
	_assert_color(_flat(menu.panel, &"panel").border_color, LINE, "the panel's border")


## The menus' option and slider rows (22.2): unboxed until focused, then the
## menu entry's lacquer wash and bar; options as the demo's .seg .opt, the
## chosen one in gold.
func test_option_and_slider_rows_are_set_in_the_theme() -> void:
	var menu: MenuScreen = MenuScreen.new()
	add_child_autofree(menu)
	var row: OptionRow = menu.add_options("Graphics", ["High", "Low"] as Array[String], 0, func(_i: int) -> void: pass)
	var slider: SliderRow = menu.add_slider("Music", 50, func(_v: int) -> void: pass)
	_assert_themed(menu)
	assert_false(_flat(row, &"panel").draw_center and _flat(row, &"panel").bg_color.a > 0.0, "no box until focused")
	row.grab_focus()
	_assert_color(_flat(row, &"panel").border_color, LACQUER, "the focus bar")
	assert_eq(_flat(row, &"panel").border_width_left, 3)
	var on: StyleBoxFlat = _flat(row.chips[0], &"normal")
	_assert_color(on.border_color, GOLD, "the chosen option")
	_assert_color(on.bg_color, INK_3)
	var off: StyleBoxFlat = _flat(row.chips[1], &"normal")
	_assert_color(off.border_color, LINE, "the others")
	_assert_color(off.bg_color, INK_2)
	_assert_color(_flat(row.chips[1], &"hover").border_color, GOLD_DIM, "a hovered option")
	assert_eq(_font_of(row.chips[0]), UI_FONT)
	_assert_color(_flat(slider.slider, &"grabber_area").bg_color, GOLD, "the slider's fill")
	_assert_color(_flat(slider.slider, &"slider").bg_color, LINE, "and its track")


func test_results_are_set_in_the_theme() -> void:
	var results: ResultsScreen = ResultsScreen.new()
	add_child_autofree(results)
	var r: MatchResults = MatchResults.new()
	r.names = ["Rogue", "Hunter"] as Array[String]
	r.weapons = ["Katana", "Greatsword"] as Array[String]
	results.show_results(r)
	_assert_themed(results)
	assert_eq(_font_of(_labelled(results, r.title())), DISPLAY_FONT)
	_assert_color(_labelled(results, "Rounds won").get_theme_color(&"font_color"), PAPER_DIM, "a stat's name")


func test_the_hud_is_set_in_the_theme() -> void:
	var hud: MatchHud = MatchHud.new()
	add_child_autofree(hud)
	_assert_themed(hud)
	assert_eq(_font_of(hud.find_child("Announce", true, false) as Control), DISPLAY_FONT)
	assert_eq(_font_of(hud.find_child("Plate0", true, false) as Control), DISPLAY_FONT)
	# a toast in the display font (24.3), a prompt and its key cap in the UI
	# font (24.4)
	hud.toasts.push("Parry", HudToasts.Tone.GOLD)
	assert_eq(_font_of(hud.toasts.get_child(0).get_node("Text") as Control), DISPLAY_FONT)
	hud.prompts.show_prompts([{"parts": ["Pick up your weapon ", HudPrompts.key("E")], "urgent": true}] as Array[Dictionary])
	var row: Node = hud.prompts.get_child(0).get_node("Row")
	assert_eq(_font_of(row.get_child(0) as Control), UI_FONT, "a prompt's text")
	assert_eq(_font_of(row.get_child(1).get_node("Name") as Control), UI_FONT, "a key cap")


## The HUD's tags (the demo's .plate .tag): spaced capitals in --danger in a
## 1 px --danger box.
func test_tags_are_danger_red_in_a_thin_box() -> void:
	var tag: Label = UiTheme.label("Disarmed", UiTheme.TAG)
	add_child_autofree(tag)
	assert_true(tag.uppercase)
	_assert_color(tag.get_theme_color(&"font_color"), UiPalette.DANGER)
	var box: StyleBoxFlat = _flat(tag, &"normal")
	_assert_color(box.border_color, UiPalette.DANGER)
	assert_eq(_border(box), [1, 1, 1, 1] as Array[int])
	assert_false(box.draw_center)
