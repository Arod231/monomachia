class_name HowToPlayScreen
extends MenuScreen
## How to play (port of showHowTo() in v0.1-web-mvp:src/ui/menus.ts, 22.14): a tab row
## over a scrolling page. The Rules tab holds the demo's rule blocks, written
## for this build's rules; a tab per weapon and bare hands holds its move list
## (MoveList). Back returns to the page that opened it (the main menu now,
## the pause menu with 22.15).
##
## Left and right on the tab row switch tabs, as do Q and E or the shoulder
## buttons from anywhere on the page. Up and down (the D-pad and the stick
## too) scroll the page while the tab row keeps the focus; down at the bottom
## goes to Back, and up from Back returns to the tabs. The mouse wheel
## scrolls, and a click on a tab picks it.

const TABS: Array[String] = ["Rules", "Katana", "Greatsword", "Daggers", "Bare hands"]
## The weapon each tab lists (none for the rules).
const TAB_WEAPONS: Array[StringName] = [&"", &"katana", &"greatsword", &"daggers", &"fists"]
## How far one up or down scrolls the page (px).
const SCROLL_STEP: int = 90
const PAGE_SIZE: Vector2 = Vector2(1240.0, 520.0)
## The move table's column widths: input, move, damage, posture, reach.
const COLUMNS: Array[float] = [330.0, 520.0, 100.0, 100.0, 100.0]

## The rule blocks: a title and its points. Text in [color] marks what the
## demo set in bold (the bundled fonts have no bold weight).
static var RULES: Array = [
	["Win the duel", [
		"Empty the other fighter's health to win a round. [color=#c9a15a]First to %d rounds[/color] wins." % SimConst.ROUNDS_TO_WIN,
		"You fight on a walled shrine %d m across. Your camera stays locked on: forward moves toward them, left and right circle around." % roundi(SimConst.ARENA_RADIUS * 2.0),
		"[color=#c9a15a]Tap[/color] a direction to step, [color=#c9a15a]double-tap and hold[/color] to sprint.",
	]],
	["Attack", [
		"Light and heavy run into strings: each weapon's tab shows where every press leads.",
		"Strings are [color=#c9a15a]not guaranteed[/color]: from the second hit on, the defender can block or parry.",
		"[color=#c9a15a]Hold heavy[/color] to charge it. A dodge cancels a heavy late in its recovery.",
		"Attacks keep half your running speed, so you can strike on the move.",
	]],
	["Defend", [
		"[color=#c9a15a]Hold block[/color] to stop health damage. Blocking still fills your posture a little, and you can walk while you block.",
		"[color=#c9a15a]Tap block just before a hit[/color] to parry: their weapon bounces, their posture fills, you strike first.",
		"[color=#c9a15a]Dodge[/color] with a direction for a dash that passes through normal attacks. Dodge with no direction to backstep.",
	]],
	["Posture", [
		"The bar under your health. Hits, blocks, parries and counters you take fill it.",
		"Armed, it only drains while you [color=#c9a15a]hold block and are not being hit[/color]: fastest standing still, slower when moving or hurt. Disarmed, it drains by itself.",
		"When it is full, a parried attack or blocking an unblockable, a full-charge heavy or an ultimate [color=#c9a15a]disarms you[/color].",
	]],
	["Unblockables (red 危 mark)", [
		"[color=#c9a15a]Thrust[/color]: dodge [color=#c9a15a]toward[/color] it to stomp their blade. They are stunned.",
		"[color=#c9a15a]Sweep[/color]: [color=#c9a15a]jump[/color] over it to vault off them for big posture damage.",
		"[color=#c9a15a]Slam[/color]: [color=#c9a15a]back-dash[/color] as it lands, then press light for a counter lunge.",
		"All three can also be parried. Dodge invincibility does not work against them.",
	]],
	["Disarmed", [
		"Your weapon flies away. You fight with bare hands: faster, longer dodges, higher jumps.",
		"You cannot block. A timed block press becomes a [color=#c9a15a]redirect[/color] counter that stuns and hammers posture.",
		"Stand on your weapon and press [color=#c9a15a]pick up[/color] to re-arm.",
	]],
	["Ultimate", [
		"At %d%% health or less you glow: press [color=#c9a15a]light + heavy together[/color] (or the ultimate button), once per round." % roundi(SimConst.ULT_HP_THRESHOLD),
		"Armed: your weapon's signature technique. Disarmed: choose Recall (your weapon returns in a burst that knocks them down if they are close) or Breaker Palm (a big posture blow).",
	]],
	["Modes", [
		"[color=#c9a15a]Duel[/color]: you against the computer, at three skill levels.",
		"[color=#c9a15a]Versus[/color]: two people on one screen, split down the middle. Each player picks a device and a controls profile; keyboard and mouse and the arrow-key layout can share one keyboard.",
		"[color=#c9a15a]Training[/color]: a dummy you tell what to do (keys 1–9, or the pause menu on a controller), with health refill (key 0).",
		"[color=#c9a15a]Watch[/color]: two computer fighters duel while you watch.",
	]],
]

var tabs: OptionRow
var scroll: ScrollContainer
## One page per tab, in TABS order; only the current one shows.
var pages: Array[Control] = []
var back_button: Button
var tab: int = 0


func _init() -> void:
	super()
	add_label("The rules of the duel", UiTheme.EYEBROW, 15)
	add_heading("How to play")
	tabs = add_options("", TABS, 0, show_tab)
	tabs.title.visible = false
	scroll = ScrollContainer.new()
	scroll.name = "Page"
	scroll.custom_minimum_size = PAGE_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var holder: VBoxContainer = VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	pages.append(_rules_page())
	for i: int in range(1, TABS.size()):
		pages.append(_weapon_page(Moves.WEAPONS[TAB_WEAPONS[i]]))
	for p: Control in pages:
		holder.add_child(p)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(160.0, 48.0)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(back_requested.emit)
	box.add_child(back_button)
	add_item(back_button)
	show_tab(0)


## Opens on the rules, at the top.
func open() -> void:
	show_tab(0)
	super()


## Shows a tab's page from its top.
func show_tab(i: int) -> void:
	tab = posmod(i, TABS.size())
	tabs.set_index(tab)
	for p: int in pages.size():
		pages[p].visible = p == tab
	scroll.scroll_vertical = 0


## Shows a weapon's move list (the pause menu opens on the fighter's own).
func show_weapon(weapon_id: StringName) -> void:
	show_tab(maxi(0, TAB_WEAPONS.find(weapon_id)))


func act(cmd: MenuNav.Cmd) -> void:
	var item: Control = focused_item()
	if item == tabs and (cmd == MenuNav.Cmd.UP or cmd == MenuNav.Cmd.DOWN):
		var before: int = scroll.scroll_vertical
		scroll.scroll_vertical = before + (SCROLL_STEP if cmd == MenuNav.Cmd.DOWN else -SCROLL_STEP)
		if cmd == MenuNav.Cmd.DOWN and scroll.scroll_vertical == before:
			back_button.grab_focus()
		return
	if item == back_button and (cmd == MenuNav.Cmd.UP or cmd == MenuNav.Cmd.DOWN):
		tabs.grab_focus()
		return
	super(cmd)


## Q and E, or the shoulder buttons, switch tabs wherever the focus is.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree():
		var step: int = _tab_step(event)
		if step != 0:
			get_viewport().set_input_as_handled()
			show_tab(tab + step)
			GameServices.play_ui(&"ui_move")
			return
	super(event)


static func _tab_step(event: InputEvent) -> int:
	if event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed or k.echo:
			return 0
		var key: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return -1 if key == KEY_Q else (1 if key == KEY_E else 0)
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		if not jb.pressed:
			return 0
		if jb.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if jb.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	return 0


# ------------------------------------------------------------------ pages

func _rules_page() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.name = "Rules"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 22)
	for block: Array in RULES:
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var title: Label = UiTheme.label(block[0], UiTheme.DISPLAY, 26)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(title)
		var text: RichTextLabel = RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(590.0, 0.0)
		text.add_theme_font_size_override(&"normal_font_size", 18)
		var points: PackedStringArray = []
		for point: String in block[1]:
			points.append("• " + point)
		text.text = "\n".join(points)
		col.add_child(text)
		grid.add_child(col)
	return grid


func _weapon_page(w: WeaponDef) -> Control:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "Moves_%s" % w.id
	page.add_theme_constant_override("separation", 8)
	var all: Array[MoveList.Row] = MoveList.rows(w)
	for s: int in MoveList.SECTION_NAMES.size():
		var section: Array[MoveList.Row] = []
		for r: MoveList.Row in all:
			if int(r.section) == s:
				section.append(r)
		if section.is_empty():
			continue
		var heading: Label = UiTheme.label(MoveList.SECTION_NAMES[s], UiTheme.EYEBROW, 15)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		page.add_child(heading)
		page.add_child(_row_box(["Input", "Move", "Damage", "Posture", "Reach"], UiTheme.MUTED, 14))
		for r: MoveList.Row in section:
			page.add_child(_move_row(r))
	return page


## A table row of plain labels.
func _row_box(texts: Array[String], variation: StringName, size: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i: int in texts.size():
		row.add_child(_cell(texts[i], i, variation, size))
	return row


func _cell(text: String, column: int, variation: StringName, size: int) -> Label:
	var l: Label = UiTheme.label(text, variation, size)
	l.custom_minimum_size = Vector2(COLUMNS[column], 0.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column < 2 else HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if column < 2:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _move_row(r: MoveList.Row) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % r.move_id
	row.add_theme_constant_override("separation", 12)
	row.add_child(_cell(r.input, 0, &"", 17))
	var move: VBoxContainer = VBoxContainer.new()
	move.custom_minimum_size = Vector2(COLUMNS[1], 0.0)
	move.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	move.add_theme_constant_override("separation", 2)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var name_label: Label = UiTheme.label(r.name, &"", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(name_label)
	if r.unblockable or r.counter != &"":
		var words: PackedStringArray = []
		if r.unblockable:
			words.append("unblockable")
		if r.counter != &"":
			words.append(String(r.counter))
		var tag: Label = UiTheme.label(" · ".join(words), UiTheme.TAG, 12)
		tag.name = "Tag"
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tag)
	move.add_child(top)
	var small: PackedStringArray = []
	if r.hits.size() > 1:
		small.append(hits_text(r))
	if r.note != "":
		small.append(r.note)
	if not r.also_after.is_empty():
		small.append("also after " + _list(r.also_after))
	for line: String in small:
		var l: Label = UiTheme.label(line, UiTheme.MUTED, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		move.add_child(l)
	row.add_child(move)
	row.add_child(_cell(number(r.damage), 2, &"", 18))
	row.add_child(_cell(number(r.posture), 3, &"", 18))
	row.add_child(_cell(metres(r.reach), 4, &"", 18))
	return row


## A damage or posture number: whole numbers without a point; "—" for none.
static func number(v: float) -> String:
	if is_nan(v):
		return "—"
	return str(int(v)) if is_equal_approx(v, roundf(v)) else String.num(v, 1)


## A reach in metres to a tenth; "—" for none.
static func metres(v: float) -> String:
	if is_nan(v) or v <= 0.0:
		return "—"
	return "%.1f m" % v


## A scripted ultimate's hits, repeats grouped: "6 × 5 + 8 damage".
static func hits_text(r: MoveList.Row) -> String:
	var parts: PackedStringArray = []
	var i: int = 0
	while i < r.hits.size():
		var n: int = 1
		while i + n < r.hits.size() and r.hits[i + n] == r.hits[i]:
			n += 1
		var dmg: String = number(r.hits[i].damage)
		parts.append(dmg if n == 1 else "%d × %s" % [n, dmg])
		i += n
	return " + ".join(parts) + " damage"


## "A", "A and B", "A, B and C".
static func _list(names: PackedStringArray) -> String:
	if names.size() < 2:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
