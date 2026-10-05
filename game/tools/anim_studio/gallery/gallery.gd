class_name Gallery
extends PanelContainer
## The Studio's gallery (docs/specs/animation-studio.md, Gallery): a tab for
## each group of the catalogue (Katana, Daggers, Greatsword, Fists, States,
## Ults, Source), each a scrolling flow of live AnimTiles; a search box and a
## chip for each badge to narrow them; and, above, a banner listing the data
## files the Studio couldn't read. A click on a tile says so (`opened`); the
## Studio opens the editor.
##
## A tab's tiles are made when the tab is first shown, so opening the Studio
## makes the Katana's and nothing else. A tile only plays while it is on screen
## (AnimTile), so a hidden tab, a filtered-out tile and a tile below the fold
## cost nothing; the Studio's Hunter/Rogue switch re-sets up every tile that
## exists (`set_fighter()`), and the ones in view rebuild on the new body a few
## a frame.

## A tile was clicked: open `entry` in the editor.
signal opened(entry: StudioCatalogue.Entry)

## The tabs, in order: the catalogue group each shows and the tab's title.
const TABS: Array[Dictionary] = [
	{"group": &"katana", "title": "Katana"},
	{"group": &"daggers", "title": "Daggers"},
	{"group": &"greatsword", "title": "Greatsword"},
	{"group": &"fists", "title": "Fists"},
	{"group": &"states", "title": "States"},
	{"group": &"ults", "title": "Ults"},
	{"group": &"source", "title": "Source"},
]
const TILE_SCENE: PackedScene = preload("res://tools/anim_studio/gallery/anim_tile.tscn")
const ERROR_INTRO: String = "Some data files could not be read, so their animations are read-only:"
## The gap between tiles (px) and the margin round them.
const TILE_GAP: int = 12
const TILE_MARGIN: int = 14

## &"hunter" or &"rogue": the body the tiles play on.
var fighter_id: StringName = &"hunter"
var catalogue: StudioCatalogue = null

@onready var _tabs: TabContainer = %Tabs
@onready var _search: LineEdit = %Search
@onready var _count: Label = %CountLabel
@onready var _empty_note: Label = %EmptyNote
@onready var _error_banner: Control = %ErrorBanner
@onready var _error_label: Label = %ErrorLabel
@onready var _chips: HBoxContainer = %BadgeChips

var _text: String = ""
var _badges: Array[StringName] = []
## Each group's tiles, once its tab has been built.
var _tiles: Dictionary[StringName, Array] = {}
var _scrolls: Dictionary[StringName, ScrollContainer] = {}
var _flows: Dictionary[StringName, HFlowContainer] = {}


func _ready() -> void:
	_search.text_changed.connect(_on_search_changed)
	for b: StringName in StudioCatalogue.BADGES:
		var chip: Button = _chips.get_node("%%Badge_%s" % b) as Button
		_style_chip(chip, b)
		chip.toggled.connect(_on_chip_toggled)
	for tab: Dictionary in TABS:
		_add_tab(tab["group"], tab["title"])
	_tabs.tab_changed.connect(_on_tab_changed)
	_empty_note.visible = false


## Fills the gallery from `p_catalogue` on `p_fighter_id`, building the open tab's
## tiles. Calling it again starts over.
func setup(p_catalogue: StudioCatalogue, p_fighter_id: StringName) -> void:
	catalogue = p_catalogue
	fighter_id = p_fighter_id
	for g: StringName in _tiles:
		for t: AnimTile in _tiles[g]:
			# out of the flow at once, so the old tiles and the new never share it
			t.get_parent().remove_child(t)
			t.queue_free()
	_tiles.clear()
	_error_label.text = ERROR_INTRO + "\n" + "\n".join(catalogue.errors)
	_error_banner.visible = not catalogue.errors.is_empty()
	_ensure_built(current_group())


## The groups the tabs show, in tab order.
func groups() -> Array[StringName]:
	var out: Array[StringName] = []
	for tab: Dictionary in TABS:
		out.append(tab["group"])
	return out


## The group of the open tab.
func current_group() -> StringName:
	return TABS[_tabs.current_tab]["group"]


## Opens the tab of `group` (building its tiles if this is the first time); a
## group with no tab does nothing.
func show_group(group: StringName) -> void:
	var index: int = groups().find(group)
	if index < 0:
		return
	_tabs.current_tab = index
	_ensure_built(group)


## Whether `group`'s tiles have been made.
func is_tab_built(group: StringName) -> bool:
	return _tiles.has(group)


## `group`'s tiles, in the catalogue's order; empty until its tab is built.
func tiles_in(group: StringName) -> Array[AnimTile]:
	var out: Array[AnimTile] = []
	if _tiles.has(group):
		out.assign(_tiles[group])
	return out


## The scroll container of `group`'s tab.
func scroll_of(group: StringName) -> ScrollContainer:
	return _scrolls[group]


## Chooses the body the tiles play on (&"hunter" or &"rogue"): every tile that
## exists is set up again, and the ones in view rebuild on the new body a few
## a frame (AnimTile.builds_per_frame), top to bottom.
func set_fighter(id: StringName) -> void:
	if id == fighter_id:
		return
	fighter_id = id
	for g: StringName in _tiles:
		for t: AnimTile in _tiles[g]:
			t.setup(t.entry, fighter_id)


## Shows only the entries that match `text` and have every badge of `badges`
## (GalleryFilter), in every tab. Sets the search box and the chips to match.
func set_filter(text: String, badges: Array[StringName]) -> void:
	_text = text
	_badges = badges.duplicate()
	if _search.text != text:
		_search.text = text
	for b: StringName in StudioCatalogue.BADGES:
		(_chips.get_node("%%Badge_%s" % b) as Button).set_pressed_no_signal(badges.has(b))
	refresh_filter()


func _add_tab(group: StringName, title: String) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, TILE_MARGIN)
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", TILE_GAP)
	flow.add_theme_constant_override("v_separation", TILE_GAP)
	margin.add_child(flow)
	scroll.add_child(margin)
	_tabs.add_child(scroll)
	_scrolls[group] = scroll
	_flows[group] = flow


## Makes `group`'s tiles if they aren't made, filtered as the box and chips say.
func _ensure_built(group: StringName) -> void:
	if catalogue != null and not _tiles.has(group):
		var tiles: Array[AnimTile] = []
		for e: StudioCatalogue.Entry in catalogue.in_group(group):
			var tile: AnimTile = TILE_SCENE.instantiate() as AnimTile
			_flows[group].add_child(tile)
			tile.setup(e, fighter_id)
			tile.visible = GalleryFilter.matches(e, _text, _badges)
			tile.opened.connect(_on_tile_opened)
			tiles.append(tile)
		_tiles[group] = tiles
	_update_summary()


## Applies the search box and the badge chips to every tile again, and updates
## the count: call it after changing an entry's badges (a tile that is no
## longer in the filter hides, one that now is shows).
func refresh_filter() -> void:
	for g: StringName in _tiles:
		for t: AnimTile in _tiles[g]:
			t.visible = GalleryFilter.matches(t.entry, _text, _badges)
	_update_summary()


## The count of the open tab ("12 of 40") and the note for a tab with nothing
## showing.
func _update_summary() -> void:
	var group: StringName = current_group()
	var total: int = catalogue.in_group(group).size() if catalogue != null else 0
	var shown: int = 0
	for t: AnimTile in tiles_in(group):
		if t.visible:
			shown += 1
	_count.text = "%d of %d" % [shown, total]
	_empty_note.visible = shown == 0 and total > 0
	_empty_note.text = "No animation here matches the search and badges."


func _on_tab_changed(_index: int) -> void:
	_ensure_built(current_group())


func _on_search_changed(text: String) -> void:
	_text = text
	refresh_filter()


func _on_chip_toggled(_pressed: bool) -> void:
	var chosen: Array[StringName] = []
	for b: StringName in StudioCatalogue.BADGES:
		if (_chips.get_node("%%Badge_%s" % b) as Button).button_pressed:
			chosen.append(b)
	_badges = chosen
	refresh_filter()


func _on_tile_opened(entry: StudioCatalogue.Entry) -> void:
	opened.emit(entry)


## A filter chip wears its badge's colour (the tile's chip) once chosen.
func _style_chip(chip: Button, badge: StringName) -> void:
	var color: Color = AnimTile.CHIP_COLORS.get(badge, Color(0.4, 0.4, 0.45))
	var off: StyleBoxFlat = StyleBoxFlat.new()
	off.bg_color = Color(0.13, 0.14, 0.16)
	off.border_color = color.darkened(0.25)
	off.set_border_width_all(1)
	off.set_corner_radius_all(10)
	off.content_margin_left = 10.0
	off.content_margin_right = 10.0
	off.content_margin_top = 2.0
	off.content_margin_bottom = 2.0
	var on: StyleBoxFlat = off.duplicate() as StyleBoxFlat
	on.bg_color = color
	on.border_color = color.lightened(0.2)
	var hover: StyleBoxFlat = off.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.55)
	chip.add_theme_stylebox_override(&"normal", off)
	chip.add_theme_stylebox_override(&"hover", hover)
	chip.add_theme_stylebox_override(&"pressed", on)
	chip.add_theme_stylebox_override(&"hover_pressed", on)
	chip.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	chip.add_theme_font_size_override(&"font_size", 12)
	chip.add_theme_color_override(&"font_color", color.lightened(0.35))
	chip.add_theme_color_override(&"font_hover_color", Color(1.0, 1.0, 1.0))
	chip.add_theme_color_override(&"font_pressed_color", Color(0.08, 0.08, 0.1))
	chip.add_theme_color_override(&"font_hover_pressed_color", Color(0.08, 0.08, 0.1))
