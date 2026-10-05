class_name HudPrompts
extends VBoxContainer
## The HUD's prompts (task 24.4): at most MAX lines at the bottom centre
## telling the player what they can press now, urgent ones first and edged in
## gold, each key drawn as a KeyCap named for the device the player last used
## (keyboard and mouse names, or PlayStation, Xbox or generic buttons). Port
## of Hud.updatePrompts() in src/ui/hud.ts and the demo's #prompt, .hint and
## kbd styles.
##
## for_fighter() works out the prompts with no nodes:
## - urgent: the bare-hands ultimate's choice (light recalls the weapon,
##   heavy throws Breaker Palm); the Moonsplitter's tilt through its wind-up
##   (a controller names the stick, "Tilt the stick ↑/↓", since players steer
##   with it, as the owner chose on Oct 4, 2026; a keyboard its movement keys);
##   detonating the Impaler while it impales; the counter lunge while it is
##   open; picking up your own weapon within PICKUP_REACH of it;
## - then, not urgent, Ultimate ready (light + heavy, or the ultimate key
##   when one is bound) while the ultimate can be used.
##
## A prompt is { "parts": Array, "urgent": bool }, its parts plain text
## (String) or a key ({ "key": name }). MatchHud shows them only for the
## player's own side, while the round is fought, and while the Button hints
## setting is on.

## Prompts on screen at once.
const MAX: int = 2
## How near your dropped weapon (m, along the ground) the pick-up prompt
## shows: the demo's 2.2, further out than the rules' pick-up range, so it
## shows as you close in.
const PICKUP_REACH: float = 2.2
const TEXT_SIZE: int = 20
const KEY_SIZE: int = 17
## The urgent prompts' text (the demo's .hint.urgent).
const URGENT_TEXT: Color = Color("#ffe0a0")
## Between the two halves of a two-choice prompt.
const DOT: String = "  ·  "

## The prompts on screen.
var _prompts: Array[Dictionary] = []


func _init() -> void:
	name = "Prompts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 6)


## The prompts for a fighter now, at most MAX, urgent first. label(action)
## names the player's input for an action; on_pad says the player last used
## a controller.
static func for_fighter(f: Fighter, world: World, label: Callable, on_pad: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var k: Callable = func(action: String) -> Dictionary: return key(String(label.call(action)))
	if f.state == &"ultChoice":
		out.append(_urgent([k.call("light"), " Recall your weapon" + DOT, k.call("heavy"), " Breaker Palm"]))
	elif f.state == &"ult" and f.ult != null and f.ult.kind == &"moonsplitter" and f.ult.phase == &"windup":
		if on_pad:
			out.append(_urgent(["Tilt the stick ", key("↑"), "/", key("↓"), " vertical slash" + DOT, key("←"), "/", key("→"), " horizontal"]))
		else:
			out.append(_urgent(["Tilt ", k.call("up"), "/", k.call("down"), " vertical slash" + DOT, k.call("left"), "/", k.call("right"), " horizontal"]))
	elif f.state == &"ult" and f.ult != null and f.ult.kind == &"impaler" and f.ult.phase == &"impale":
		out.append(_urgent(["Press ", k.call("heavy"), " to detonate"]))
	if world.frame <= f.counter_lunge_until:
		out.append(_urgent(["Counter lunge: ", k.call("light")]))
	if not f.armed:
		var w: DroppedWeapon = world.weapon_of(f.id)
		if w != null and w.grounded and Vector2(w.pos.x - f.pos.x, w.pos.z - f.pos.z).length() < PICKUP_REACH:
			out.append(_urgent(["Pick up your weapon ", k.call("interact")]))
	if f.can_ult() and f.state != &"ult" and f.state != &"ultChoice":
		var parts: Array = ["Ultimate ready: ", k.call("light"), " + ", k.call("heavy")]
		if String(label.call("ultimate")) != "":
			parts.append_array([" or ", k.call("ultimate")])
		out.append({"parts": parts, "urgent": false})
	return out.slice(0, MAX)


## A key part of a prompt.
static func key(name: String) -> Dictionary:
	return {"key": name}


static func _urgent(parts: Array) -> Dictionary:
	return {"parts": parts, "urgent": true}


## A prompt as plain text, each key in brackets: "Pick up your weapon [E]"
## (for tests, and to tell a changed prompt from the one on screen).
static func text_of(prompt: Dictionary) -> String:
	var s: String = ""
	for part: Variant in prompt["parts"]:
		s += ("[%s]" % part["key"]) if part is Dictionary else String(part)
	return s


## Shows these prompts (at most MAX), rebuilding the lines only when they
## change.
func show_prompts(prompts: Array[Dictionary]) -> void:
	var next: Array[Dictionary] = prompts.slice(0, MAX)
	if _same(next, _prompts):
		return
	_prompts = next
	for child: Node in get_children():
		remove_child(child)
		child.free()
	for p: Dictionary in _prompts:
		add_child(_line(p))


## The prompts on screen.
func prompts() -> Array[Dictionary]:
	return _prompts


## The prompts on screen as plain text (text_of).
func lines() -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in _prompts:
		out.append(text_of(p))
	return out


static func _same(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if text_of(a[i]) != text_of(b[i]) or bool(a[i]["urgent"]) != bool(b[i]["urgent"]):
			return false
	return true


## One prompt line (the demo's .hint): its text and key caps in a row on a
## dark panel, edged in the line colour, or in gold with warm text when
## urgent.
func _line(p: Dictionary) -> PanelContainer:
	var urgent: bool = p["urgent"]
	var panel := PanelContainer.new()
	panel.name = "Prompt%d" % get_child_count()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiPalette.INK, 0.78)
	box.border_color = UiPalette.GOLD if urgent else UiPalette.LINE
	box.set_border_width_all(1)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", box)
	panel.set_meta("urgent", urgent)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)
	for part: Variant in p["parts"]:
		if part is Dictionary:
			row.add_child(KeyCap.new(String(part["key"]), KEY_SIZE))
		else:
			var l := Label.new()
			l.text = String(part)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_font_size_override("font_size", TEXT_SIZE)
			l.add_theme_color_override("font_color", URGENT_TEXT if urgent else UiPalette.PAPER)
			row.add_child(l)
	return panel
