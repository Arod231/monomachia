class_name UiTheme
## The UI theme's type variations (ui/theme/ink_wash.tres, the project theme)
## and a label factory for them. Plain text needs no variation: the theme
## draws every Label in Zen Kaku Gothic New on paper.

## Titles, names and announcements: Zen Antique, slightly spaced.
const DISPLAY: StringName = &"DisplayLabel"
## Kanji: Zen Antique in lacquer.
const KANJI: StringName = &"KanjiLabel"
## Small spaced capitals in the dimmed paper (label() sets the capitals).
const EYEBROW: StringName = &"EyebrowLabel"
## Quieter text in the dimmed paper.
const MUTED: StringName = &"MutedLabel"
## A boxed warning in the HUD (the plate's Disarmed tag): small spaced
## capitals in danger red in a thin danger-red box.
const TAG: StringName = &"HudTag"
## The title's seal (the demo's .hanko): kanji in pale paper on a rounded
## lacquer square.
const HANKO: StringName = &"HankoLabel"
## A main-menu button: no box until focused, then a lacquer wash and bar.
const MENU_ENTRY: StringName = &"MenuEntry"
## A menu row (an OptionRow or SliderRow): no box, and while focused the menu
## entry's lacquer wash and bar (MENU_ROW_LIT).
const MENU_ROW: StringName = &"MenuRow"
const MENU_ROW_LIT: StringName = &"MenuRowLit"
## An option in a row (the demo's .seg .opt): a small ink box in a line
## border; the chosen one (OPTION_ON) in a gold border with warm text.
const OPTION: StringName = &"OptionChip"
const OPTION_ON: StringName = &"OptionChipOn"
## A card in a row of cards (the fighter select's grid, the demo's .card):
## a large name on ink in a line border; the chosen one (CARD_ON) in a gold
## border over a lacquer wash.
const CARD: StringName = &"Card"
const CARD_ON: StringName = &"CardOn"


## A centred label in one of the variations (or plain text for &""), at the
## variation's size unless a size is given. Eyebrows are set in capitals, as
## the demo's are.
static func label(text: String, variation: StringName = &"", font_size: int = 0) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.uppercase = variation == EYEBROW or variation == TAG
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l
