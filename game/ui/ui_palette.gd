class_name UiPalette
## The UI's colours: the mood board's UI page, style A, lacquer and gold
## (milestone-1 task 53; the asset repository's moodboard/index.html, its
## .ui-a rules), for the UI theme (UiTheme.build() makes
## ui/theme/lacquer_gold.tres from them) and for UI code that colours things
## as they change (the HUD's bars, the results' winner). The 3D look's
## colours are LookPalette's.

## Black urushi lacquer: the ground, a panel's warm top and a raised box
## (buttons, chosen options, key caps).
const LACQUER: Color = Color("#060505")
const LACQUER_WARM: Color = Color("#16110d")
const LACQUER_RAISED: Color = Color("#231a12")
## Gold: hairlines and accents; the lit and chosen; quieter edges; and the
## pale gold of lit text.
const GOLD: Color = Color("#b8955a")
const GOLD_BRIGHT: Color = Color("#d7b14b")
const GOLD_DIM: Color = Color("#7a6340")
const GOLD_PALE: Color = Color("#f0d9a8")
## Rules and an unlit box's border: gold at 40% over the lacquer.
const LINE: Color = Color("#4d3f27")
## Text, and quieter text: eyebrows, labels, notes.
const IVORY: Color = Color("#e6dcc4")
const IVORY_DIM: Color = Color("#a59d8c")
## Brushed kanji, a shade brighter than the text.
const KANJI: Color = Color("#efe6d2")
## The sides: crimson against indigo, each with its deep lacquer (the HP
## bars' foot). Crimson is also the title's seal and a lost match.
const CRIMSON: Color = Color("#c0392f")
const CRIMSON_DEEP: Color = Color("#7d1a1d")
const INDIGO: Color = Color("#5a78c0")
const INDIGO_DEEP: Color = Color("#1d2a4d")
const JADE: Color = Color("#6fd6b8")
const POSTURE: Color = Color("#e7a53b")
## Posture at 70% or more (the demo's hot fill).
const POSTURE_HOT: Color = Color("#f06a2a")
const DANGER: Color = Color("#ff3b25")
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.55)
