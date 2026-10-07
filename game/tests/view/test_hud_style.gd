extends GutTest
## The HUD and the round calls in the lacquer-and-gold style (milestone-1
## task 54, the mood board's UI A): HP in each side's lacquer in a gold-edged
## channel, posture in gold (amber when hot, blinking crimson when full),
## round pips as black lacquer discs with a gold rim lit in the side's
## colour, the 奥義 badge as a lacquer disc with brushed kanji, and the round
## calls' kanji large and brushed over small, widely spaced gold Latin,
## painted in by a brush-stroke wipe. The layout is task 24's.

var host: MatchHost
var hud: MatchHud


func _start(mode: StringName = MatchConfig.WATCH) -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	host.start(MatchConfig.make(
		mode,
		MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"),
		7,
		ArenaScenes.STANDIN,
	))
	host.step(2)
	hud._process(1.0 / 60.0)


func _node(node_name: String) -> Node:
	return hud.find_child(node_name, true, false)


func _assert_color(got: Color, want: Color, what: String = "") -> void:
	assert_true(got.is_equal_approx(want), "%s %s is %s" % [what, got, want])


# ------------------------------------------------------------------ bars

func test_hp_is_each_sides_lacquer_in_a_gold_edged_channel() -> void:
	_start()
	var red: HudBar = _node("Hp0") as HudBar
	var blue: HudBar = _node("Hp1") as HudBar
	_assert_color(red.fill_color, UiPalette.CRIMSON, "the red side's top")
	_assert_color(red.fill_bottom, UiPalette.CRIMSON_DEEP, "and foot")
	_assert_color(blue.fill_color, UiPalette.INDIGO, "the blue side's top")
	_assert_color(blue.fill_bottom, UiPalette.INDIGO_DEEP, "and foot")
	for bar: HudBar in [red, blue]:
		_assert_color(bar.edge_color, UiPalette.GOLD, "the gold edge")
		_assert_color(Color(bar.back_color, 1.0), UiPalette.LACQUER, "the lacquer channel")
		assert_gt(bar.back_color.a, 0.75)
	_assert_color(UiPalette.CRIMSON, Color("#c0392f"))
	_assert_color(UiPalette.INDIGO_DEEP, Color("#1d2a4d"))


func test_posture_is_gold_turning_amber_and_then_crimson() -> void:
	_start()
	var bar: HudBar = _node("Posture0") as HudBar
	_assert_color(bar.fill_color, UiPalette.POSTURE, "calm, gold")
	_assert_color(bar.fill_bottom, UiPalette.POSTURE_FOOT)
	_assert_color(UiPalette.POSTURE, Color("#e8cf96"))
	_assert_color(UiPalette.POSTURE_FOOT, Color("#a8853f"))
	host.fighter(0).posture = SimConst.POSTURE_MAX * 0.8
	hud._process(1.0 / 60.0)
	_assert_color(bar.fill_color, UiPalette.POSTURE_HOT, "hot, amber")
	_assert_color(bar.fill_bottom, UiPalette.POSTURE_HOT_FOOT)
	host.fighter(0).posture = SimConst.POSTURE_MAX
	var seen: Array[Color] = []
	for i: int in 21:
		hud._process(1.0 / 60.0)
		seen.append(Color(bar.fill_color, 1.0))
		_assert_color(Color(bar.fill_bottom, 1.0), UiPalette.CRIMSON_DEEP, "full, crimson to the foot")
	for c: Color in seen:
		_assert_color(c, UiPalette.CRIMSON, "full, crimson")
	_assert_color(bar.edge_color, Color(UiPalette.GOLD, bar.edge_color.a), "a gold edge")


## The blink dims the whole fill, top and foot alike.
func test_full_posture_blinks_top_and_foot_together() -> void:
	_start()
	host.fighter(1).posture = SimConst.POSTURE_MAX
	var bar: HudBar = _node("Posture1") as HudBar
	var dimmed: bool = false
	for i: int in 21:
		hud._process(1.0 / 60.0)
		assert_eq(bar.fill_color.a, bar.fill_bottom.a)
		dimmed = dimmed or bar.fill_color.a < 1.0
	assert_true(dimmed)


# ------------------------------------------------------------------ pips

func test_pips_are_lacquer_discs_with_a_gold_rim_lit_in_the_sides_colour() -> void:
	_start()
	host.sim_match.wins[0] = 2
	host.sim_match.wins[1] = 1
	hud._process(1.0 / 60.0)
	var red: HudPips = _node("Pips0") as HudPips
	var blue: HudPips = _node("Pips1") as HudPips
	_assert_color(red.color, UiPalette.CRIMSON)
	_assert_color(blue.color, UiPalette.INDIGO)
	_assert_color(red.fill(0), UiPalette.CRIMSON, "a won round, lit")
	_assert_color(red.fill(1), UiPalette.CRIMSON)
	_assert_color(red.fill(2), UiPalette.LACQUER, "one still to win, black lacquer")
	_assert_color(blue.fill(0), UiPalette.INDIGO)
	_assert_color(blue.fill(1), UiPalette.LACQUER)
	_assert_color(HudPips.RIM, UiPalette.GOLD)


## Discs in a row, the leftmost first, a gap between them, all inside the
## control (the glow included).
func test_the_pips_are_a_row_of_round_discs() -> void:
	var pips: HudPips = HudPips.new()
	add_child_autofree(pips)
	pips.size = pips.custom_minimum_size
	var centres: PackedVector2Array = pips.centres()
	assert_eq(centres.size(), SimConst.ROUNDS_TO_WIN)
	for k: int in centres.size():
		assert_eq(centres[k].y, pips.size.y * 0.5)
		assert_true(Rect2(Vector2.ZERO, pips.size).grow(0.01).encloses(Rect2(centres[k] - Vector2.ONE * HudPips.RADIUS * HudPips.GLOW_SCALE, Vector2.ONE * HudPips.RADIUS * HudPips.GLOW_SCALE * 2.0)))
		if k > 0:
			assert_almost_eq(centres[k].x - centres[k - 1].x, HudPips.RADIUS * 2.0 + HudPips.GAP, 0.001)


# ------------------------------------------------------------------ badge

func test_the_badge_is_a_lacquer_disc_with_brushed_kanji() -> void:
	var badge: HudBadge = HudBadge.new()
	add_child_autofree(badge)
	var text: Label = badge.get_child(0) as Label
	assert_eq(text.text, "奥義")
	assert_eq(text.theme_type_variation, UiTheme.KANJI, "brushed")
	assert_eq(badge.custom_minimum_size.x, badge.custom_minimum_size.y, "round")
	assert_gte(badge.custom_minimum_size.x, text.get_minimum_size().x, "the kanji fit inside")
	badge.state = HudState.Badge.READY
	_assert_color(text.get_theme_color(&"font_color"), UiPalette.GOLD_PALE, "pale gold while ready")
	_assert_color(badge.rim_color(), UiPalette.GOLD_BRIGHT, "a bright rim")
	assert_eq(badge.modulate.a, 1.0)
	badge.state = HudState.Badge.USED
	_assert_color(text.get_theme_color(&"font_color"), UiPalette.GOLD_DIM, "dim once used")
	_assert_color(badge.rim_color(), UiPalette.GOLD_DIM)
	assert_almost_eq(badge.modulate.a, HudBadge.USED_ALPHA, 0.0001)
	badge.state = HudState.Badge.HIDDEN
	assert_eq(badge.modulate.a, 0.0)


# ------------------------------------------------------------------ calls

func test_a_round_call_is_big_brushed_kanji_over_small_spaced_gold_latin() -> void:
	_start()
	hud.announce("始め", "Fight", "", MatchHud.FIGHT_FRAMES)
	var kanji: Label = _node("AnnounceKanji") as Label
	var word: Label = _node("Announce") as Label
	var sub: Label = _node("AnnounceSub") as Label
	assert_eq(kanji.theme_type_variation, UiTheme.KANJI)
	_assert_color(kanji.get_theme_color(&"font_color"), UiPalette.KANJI, "ivory")
	assert_eq(word.theme_type_variation, UiTheme.CALL_WORD)
	assert_eq(word.get_theme_font(&"font").get_font_name(), "Shippori Mincho B1")
	_assert_color(word.get_theme_color(&"font_color"), UiPalette.GOLD_BRIGHT, "gold")
	assert_gt(kanji.get_theme_font_size(&"font_size"), word.get_theme_font_size(&"font_size") * 3, "the kanji dominate")
	var font: Font = word.get_theme_font(&"font")
	var size: int = word.get_theme_font_size(&"font_size")
	var plain: Font = load(UiTheme.SERIF_BOLD_FONT)
	assert_gt(font.get_string_size("FIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, plain.get_string_size("FIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 5.0 * size * 0.3, "widely spaced")
	assert_true(word.uppercase, "in capitals")
	var order: Array[Node] = kanji.get_parent().get_children()
	assert_lt(order.find(kanji), order.find(word), "the kanji over the word")
	assert_lt(order.find(word), order.find(sub), "and the subline under it")
	assert_eq(kanji.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "as wide as its text, so the wipe crosses it")


## The brush wipe: the kanji are painted in, left to right, over the first
## WIPE_FRAMES of the run, easing out; the Latin fades in alongside; there
## is no scale-in; the call then fades out as before.
func test_the_entrance_paints_the_kanji_in_while_the_latin_fades_in() -> void:
	assert_eq(AnnouncementEntrance.wipe(0.0), 0.0)
	assert_eq(AnnouncementEntrance.wipe(-0.5), 0.0)
	var w: float = AnnouncementEntrance.WIPE
	assert_almost_eq(w * AnnouncementEntrance.FRAMES, 12.0, 0.001, "about 0.2 s")
	assert_eq(AnnouncementEntrance.wipe(w), 1.0)
	assert_eq(AnnouncementEntrance.wipe(0.5), 1.0)
	assert_gt(AnnouncementEntrance.wipe(w * 0.5), 0.5, "easing out: more than half painted at half time")
	var last: float = 0.0
	for k: int in 13:
		var v: float = AnnouncementEntrance.wipe(w * k / 12.0)
		assert_gte(v, last, "never unpaints")
		last = v
	for t: float in [0.0, 0.05, 0.1, 0.5, 0.78]:
		assert_eq(AnnouncementEntrance.scale(t), 1.0, "no scale-in at %s" % t)
	assert_eq(AnnouncementEntrance.scale(1.0), 0.98, "it still eases out")
	assert_almost_eq(AnnouncementEntrance.fade_in(0.06), 0.5, 0.0001, "the Latin fades in over the first 12%")
	assert_eq(AnnouncementEntrance.fade_in(0.5), 1.0)
	assert_eq(AnnouncementEntrance.fade_out(0.5), 1.0)
	assert_almost_eq(AnnouncementEntrance.fade_out(0.89), 0.5, 0.0001, "the whole call fades out from 78%")
	assert_eq(AnnouncementEntrance.fade_out(1.0), 0.0)
	for t: float in [0.03, 0.06, 0.5, 0.9]:
		assert_almost_eq(AnnouncementEntrance.alpha(t), AnnouncementEntrance.fade_in(t) * AnnouncementEntrance.fade_out(t), 0.0001)


func test_the_hud_paints_the_kanji_in_on_the_rules_steps() -> void:
	_start()
	hud.announce("始め", "Fight", "", MatchHud.FIGHT_FRAMES)
	var kanji: Label = _node("AnnounceKanji") as Label
	var word: Label = _node("Announce") as Label
	var box: Control = _node("Announcement") as Control
	var mat: ShaderMaterial = kanji.material as ShaderMaterial
	assert_not_null(mat, "the brush wipe on the kanji")
	assert_eq(mat.shader.resource_path, MatchHud.BRUSH_WIPE.resource_path)
	assert_eq(mat.get_shader_parameter("reveal"), 0.0, "nothing painted yet")
	host.step(6)
	hud._process(1.0 / 60.0)
	var half: float = mat.get_shader_parameter("reveal")
	assert_almost_eq(half, AnnouncementEntrance.wipe(6.0 / AnnouncementEntrance.FRAMES), 0.03)
	assert_almost_eq(hud.announcement_wipe(), half, 0.0001)
	assert_almost_eq(word.modulate.a, AnnouncementEntrance.fade_in(6.0 / AnnouncementEntrance.FRAMES), 0.03, "the Latin fading in")
	assert_eq(box.scale, Vector2.ONE, "no scale-in")
	assert_eq(mat.get_shader_parameter("size"), kanji.get_minimum_size(), "the wipe crosses the kanji's own width")
	assert_gt((mat.get_shader_parameter("size") as Vector2).x, 100.0, "known before the box lays the label out")
	host.pause()
	for i: int in 20:
		host.advance(1.0 / 60.0)
		hud._process(1.0 / 60.0)
	assert_eq(mat.get_shader_parameter("reveal"), half, "a pause holds the stroke")
	host.resume()
	host.step(10)
	hud._process(1.0 / 60.0)
	assert_eq(mat.get_shader_parameter("reveal"), 1.0, "painted by frame 12")


## The wipe's shader: a canvas-item shader that hides what lies past its
## ragged front, the front crossing the label as reveal runs 0 to 1.
func test_the_brush_wipe_shader_hides_past_a_ragged_front() -> void:
	var shader: Shader = MatchHud.BRUSH_WIPE
	assert_eq(shader.get_mode(), Shader.MODE_CANVAS_ITEM)
	var code: String = shader.code
	for uniform: String in ["reveal", "size", "soft", "ragged"]:
		assert_string_contains(code, "uniform float " + uniform if uniform != "size" else "uniform vec2 size")
	assert_string_contains(code, "COLOR.a")
