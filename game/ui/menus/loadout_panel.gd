class_name LoadoutPanel
extends VBoxContainer
## The fighter select's loadout panel for one side (port of the weapon and
## ability part of showSelect() in v0.1-web-mvp:src/ui/menus.ts): the weapon cards
## (WeaponCardRow, with Random for the Duel opponent), the weapon's blurb and
## its ultimate, and the two block-ability slots, each an OptionRow of the
## weapon's three abilities under its button badge (a label over the row, so
## the chips fit the select's left column), with the chosen one's description. Random hides the blurb, the ultimate and the slots; the
## training dummy gets no slots, and a note on how Training is driven (the
## demo's) in their place.
##
## Editing a draft (edit()), the panel applies each pick through
## MatchSelection's rules (a new weapon resets the abilities and ends a random
## pick, an ability already in the other slot swaps), shows the side again and
## emits changed, for the select to refresh the rest. Without a draft it
## changes nothing and only reports the picks (weapon_chosen, random_chosen,
## ability_chosen); show_side() shows any side.
##
## Its items (items(): the cards, then the two slots) join the select's focus
## order through FighterSelect.add_loadout_item.

signal weapon_chosen(weapon_id: StringName)
signal random_chosen
signal ability_chosen(slot: int, ability_id: StringName)
## A pick changed the draft being edited.
signal changed

## The training dummy's note (the demo's, for this build's controls).
const DUMMY_NOTE: String = "In Training you tell the dummy what to do from the panel on screen (the number keys or a click), or from the pause menu on a controller. Health refills on its own; key 0 turns that off."
## The text column's width (px).
const TEXT_WIDTH: float = 400.0
## The panel's width (px): the widest pair of ability rows (the
## Greatsword's), so the select's columns hold still when the weapon changes.
const WIDTH: float = 510.0

var cards: WeaponCardRow
var blurb: Label
var ultimate_name: Label
var ultimate_desc: Label
var abilities_title: Label
var slots: Array[OptionRow] = []
## The button badge over each slot.
var slot_badges: Array[Label] = []
var slot_descs: Array[Label] = []
## How the training dummy is told what to do, shown on its side.
var dummy_note: Label
## The weapon whose abilities the slots offer.
var weapon_id: StringName = &""
## The draft being edited and its side, or null.
var draft: MatchSelection.Draft = null
var side_index: int = 0


func _init() -> void:
	name = "Loadout"
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 6)
	cards = WeaponCardRow.new()
	cards.changed.connect(_on_card)
	add_child(cards)
	blurb = _wrapped(&"", 18)
	ultimate_name = _wrapped(UiTheme.DISPLAY, 21)
	ultimate_desc = _wrapped(UiTheme.MUTED, 16)
	abilities_title = UiTheme.label("Block abilities · pick 2 of 3", UiTheme.EYEBROW, 15)
	abilities_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(abilities_title)
	for slot: int in 2:
		var badge: Label = UiTheme.label(MenuData.SLOT_BADGES[slot], UiTheme.MUTED, 15)
		badge.name = "SlotBadge%d" % slot
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(badge)
		slot_badges.append(badge)
		var row: OptionRow = OptionRow.new(MenuData.SLOT_BADGES[slot], ["", "", ""] as Array[String])
		row.name = "Slot%d" % slot
		row.title.visible = false
		row.changed.connect(_on_slot.bind(slot))
		add_child(row)
		slots.append(row)
		var desc: Label = _wrapped(UiTheme.MUTED, 15)
		desc.name = "SlotDesc%d" % slot
		slot_descs.append(desc)
	dummy_note = _wrapped(UiTheme.MUTED, 16)
	dummy_note.name = "DummyNote"
	dummy_note.text = DUMMY_NOTE
	dummy_note.visible = false
	weapon_chosen.connect(_apply_weapon)
	random_chosen.connect(_apply_random)
	ability_chosen.connect(_apply_ability)


## Edits one side of a draft: shows it, and applies the picks to it.
func edit(d: MatchSelection.Draft, side: int) -> void:
	draft = d
	side_index = side
	_show_draft()


func _show_draft() -> void:
	show_side(
		draft.sides[side_index], draft.random_weapon[side_index], MatchSelection.offers_random(draft.mode, side_index),
		MatchSelection.picks_abilities(draft.mode, side_index)
	)


## The panel's items in focus order: the cards, then the two slots.
func items() -> Array[Control]:
	return [cards, slots[0], slots[1]] as Array[Control]


## Shows a side's loadout. random: the weapon is left to chance (only with
## offer_random); with_abilities: the side picks block abilities (not the
## training dummy).
func show_side(side: MatchSide, random: bool = false, offer_random: bool = false, with_abilities: bool = true) -> void:
	cards.offer_random(offer_random)
	random = random and offer_random
	cards.set_choice(WeaponCardRow.RANDOM if random else side.weapon_id)
	var w: WeaponDef = side.weapon()
	var info: MenuData.WeaponInfo = MenuData.weapon(side.weapon_id)
	var known: bool = w != null and info != null
	for l: Label in [blurb, ultimate_name, ultimate_desc]:
		l.visible = known and not random
	if known:
		blurb.text = w.blurb
		ultimate_name.text = "Ultimate · %s" % info.ultimate
		ultimate_desc.text = info.ultimate_desc
	var picks: bool = known and with_abilities and not random
	abilities_title.visible = picks
	dummy_note.visible = known and not with_abilities and not random
	weapon_id = side.weapon_id
	var chosen: Array[StringName] = side.resolved_abilities()
	for slot: int in 2:
		slots[slot].visible = picks
		slot_badges[slot].visible = picks
		slot_descs[slot].visible = picks
		if not known:
			continue
		for i: int in slots[slot].chips.size():
			slots[slot].chips[i].text = MenuData.ability_name(w.abilities[i]) if i < w.abilities.size() else ""
		var id: StringName = chosen[slot] if slot < chosen.size() else &""
		slots[slot].set_index(maxi(0, w.abilities.find(id)))
		slot_descs[slot].text = MenuData.ability_desc(id)


func _on_card(choice: StringName) -> void:
	if choice == WeaponCardRow.RANDOM:
		random_chosen.emit()
	else:
		weapon_chosen.emit(choice)


func _on_slot(index: int, slot: int) -> void:
	var w: WeaponDef = Moves.WEAPONS.get(weapon_id, null)
	if w != null and index < w.abilities.size():
		ability_chosen.emit(slot, w.abilities[index])


func _apply_weapon(id: StringName) -> void:
	if draft != null:
		MatchSelection.set_weapon(draft, side_index, id)
		_after_pick()


func _apply_random() -> void:
	if draft != null:
		MatchSelection.set_random_weapon(draft, side_index, true)
		_after_pick()


func _apply_ability(slot: int, id: StringName) -> void:
	if draft != null:
		MatchSelection.set_ability(draft, side_index, slot, id)
		_after_pick()


func _after_pick() -> void:
	_show_draft()
	changed.emit()


func _wrapped(variation: StringName, font_size: int) -> Label:
	var l: Label = UiTheme.label("", variation, font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	add_child(l)
	return l
