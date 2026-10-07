class_name HudToasts
extends Control
## The HUD's toasts (task 24.3): short feedback stacked under the centre of
## the screen, for parries, counters, ultimates, backstabs and dazes, and in
## Training for evades and the dummy's behaviour. Up to MAX at once (a new
## one past that drops the oldest), each LIFE rules steps long, the newest at
## the bottom: the text in its tone's colour over a subline in small spaced
## capitals. Port of Hud.toast() and the toast half of Hud.handleEvents() in
## src/ui/hud.ts and the demo's .toast style and @keyframes toast.
##
## The demo removed a toast on a 1.15 s timer that ran on through pause and
## slow motion. Here a toast is born on the host's step and lives LIFE steps,
## and its entrance is read from its age in steps plus the part of a step in
## the host's clock, as the announcements' is: a pause holds it where it is,
## slow motion stretches it, and one made while paused (the dummy's behaviour
## from the pause menu) waits for the resume.
##
## for_event() works out what an event toasts, with no nodes:
## - from the player's side, what you did is gold (a parry, Ultimate ready) or
##   jade (a flash, a redirect, a counter, Behind them, a backstab), and what
##   was done to you red, with the demo's sublines telling you what to do;
## - in Watch each toast names the fighter ("Rogue: Parry") in its side's
##   colour (赤 red, 青 blue), so a mirror match reads too, with no advice:
##   both sides' parries, counters, ultimates, backstabs and dazes (the
##   demo's Watch toasts named no one; the owner chose names on Oct 4, 2026);
## - in Training your parry's subline says how many frames before impact
##   you pressed and the window (23.4; Too early and Too late come from
##   ParryFeedback);
## - Evaded only in Training;
## - Versus (for_versus(), 23.7) takes Watch's form, naming the player
##   ("Player 2: Parry"), and adds the demo's dim "Player 1: Behind them"
##   (the owner's choice, Oct 5, 2026).

enum Tone { GOLD, JADE, RED, DIM, BLUE }

## Toasts on screen at once.
const MAX: int = 3
## A toast's length in rules steps (the demo's 1.15 s).
const LIFE: int = 69
## The entrance's length in rules steps (the demo's 1.1 s animation).
const ENTRANCE: int = 66
## The text colours: the demo's .toast.gold, jade, red and dim, and a blue
## for the 青 side in Watch, as light over the night as the red.
const TONE_COLORS: Dictionary = {
	Tone.GOLD: Color("#ffd98a"),
	Tone.JADE: UiPalette.JADE,
	Tone.RED: Color("#ff6a4a"),
	Tone.DIM: UiPalette.IVORY_DIM,
	Tone.BLUE: Color("#8cbcf0"),
}
## In Watch, each side's tone (赤 0, 青 1).
const SIDE_TONES: Array[int] = [Tone.RED, Tone.BLUE]
const PARRY_NAMES: Dictionary = {&"parry": "Parry", &"flash": "Flash", &"redirect": "Redirect"}
const COUNTER_NAMES: Dictionary = {&"stomp": "Stomp counter", &"leap": "Leap counter", &"evade": "Evade counter"}
const TEXT_SIZE: int = 30
const SUB_SIZE: int = 13
## Pixels between toasts.
const GAP: float = 6.0

## The host whose steps time the toasts (MatchHud binds it).
var host: MatchHost
## The toasts on screen, oldest first: { "text", "sub", "tone", "at" } (at is
## the host's step it was made on).
var _entries: Array[Dictionary] = []


func _init() -> void:
	name = "Toasts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## What an event toasts, as [{ "text", "sub", "tone" }] (none, or one). me is
## the player's side, or -1 for Watch; names are the sides' fighter names
## (used in Watch); light is the name of the player's light attack input.
static func for_event(e: Dictionary, me: int, training: bool, names: Array[String], light: String) -> Array[Dictionary]:
	if me < 0:
		return _for_watch(e, names)
	var out: Array[Dictionary] = []
	match e["t"]:
		&"parry":
			var parrier: int = int(e["parrier"])
			var kind: StringName = e["kind"]
			if parrier == me:
				# in Training, how early you pressed and the window you had (23.4)
				var timing: String = ParryFeedback.timing_line(e) if training else ""
				out.append(_toast(PARRY_NAMES[kind], Tone.GOLD if kind == &"parry" else Tone.JADE, timing))
			elif int(e["attacker"]) == me:
				out.append(_toast(PARRY_NAMES[kind], Tone.RED, "Your attack was deflected"))
		&"counter":
			var counter: StringName = e["kind"]
			if int(e["by"]) == me:
				var advice: String = ("Press %s now to lunge" % light) if counter == &"evade" else "They are stunned: attack"
				out.append(_toast(COUNTER_NAMES[counter], Tone.JADE, advice))
			else:
				out.append(_toast(COUNTER_NAMES[counter], Tone.RED, "You were countered"))
		&"ultReady":
			if int(e["f"]) == me:
				out.append(_toast("Ultimate ready", Tone.GOLD, "Light + Heavy together"))
		&"ultStart":
			if int(e["f"]) != me:
				out.append(_toast("Ultimate", Tone.RED, "Get ready to evade"))
		&"backstabReady":
			if int(e["f"]) == me:
				out.append(_toast("Behind them", Tone.JADE, "Light attack to backstab"))
		&"hit":
			if bool(e.get("backstab", false)):
				out.append(_toast("Backstab", Tone.JADE if int(e["attacker"]) == me else Tone.RED))
		&"stagger":
			if int(e["f"]) == me:
				out.append(_toast("Dazed", Tone.RED, "Posture broken"))
		&"evade":
			if training and int(e["f"]) == me:
				out.append(_toast("Evaded", Tone.DIM))
	return out


## What an event toasts in Versus: Watch's form with the players' names,
## and a player getting behind the other, dim, as the demo's Versus did.
static func for_versus(e: Dictionary, names: Array[String]) -> Array[Dictionary]:
	if e["t"] == &"backstabReady":
		return [_toast("%s: Behind them" % names[int(e["f"])], Tone.DIM)]
	return _for_watch(e, names)


## Watch's form: "<fighter>: <what>" in the side's tone, no subline.
static func _for_watch(e: Dictionary, names: Array[String]) -> Array[Dictionary]:
	var who: int = -1
	var what: String = ""
	match e["t"]:
		&"parry":
			who = int(e["parrier"])
			what = PARRY_NAMES[e["kind"]]
		&"counter":
			who = int(e["by"])
			what = COUNTER_NAMES[e["kind"]]
		&"ultStart":
			who = int(e["f"])
			what = "Ultimate"
		&"hit":
			if bool(e.get("backstab", false)):
				who = int(e["attacker"])
				what = "Backstab"
		&"stagger":
			who = int(e["f"])
			what = "Dazed"
	if who < 0:
		return []
	return [_toast("%s: %s" % [names[who], what], SIDE_TONES[who])]


static func _toast(text: String, tone: int, sub: String = "") -> Dictionary:
	return {"text": text, "sub": sub, "tone": tone}


## The entrance at an age in steps, as Vector2(opacity, y offset in px): the
## demo's keyframes over ENTRANCE steps (fade in rising from 8 px over the
## first 15%, hold to 75%, fade out rising to -10 px), then gone.
static func look_at(age: float) -> Vector2:
	var t: float = clampf(age / float(ENTRANCE), 0.0, 1.0)
	if t < 0.15:
		var k: float = t / 0.15
		return Vector2(k, 8.0 * (1.0 - k))
	if t <= 0.75:
		return Vector2(1.0, 0.0)
	var k: float = (t - 0.75) / 0.25
	return Vector2(1.0 - k, -10.0 * k)


## Puts a toast on screen now (on the host's current step); past MAX the
## oldest goes.
func push(text: String, tone: int, sub: String = "") -> void:
	_entries.append({"text": text, "sub": sub, "tone": tone, "at": _now()})
	while _entries.size() > MAX:
		_entries.pop_front()
	_rebuild()


## Puts each toast of for_event() on screen.
func push_all(toasts: Array[Dictionary]) -> void:
	for t: Dictionary in toasts:
		push(t["text"], t["tone"], t["sub"])


## Drops the toasts LIFE steps old (call after each host step).
func expire() -> void:
	var now: int = _now()
	var kept: Array[Dictionary] = []
	for t: Dictionary in _entries:
		if now - int(t["at"]) < LIFE:
			kept.append(t)
	if kept.size() != _entries.size():
		_entries = kept
		_rebuild()


func clear() -> void:
	_entries.clear()
	_rebuild()


## The toasts on screen, oldest first: { "text", "sub", "tone", "at" }.
func entries() -> Array[Dictionary]:
	return _entries


## Toast i's age in rules steps, with the part of a step in the host's clock.
func age(i: int) -> float:
	var partial: float = minf(host.accumulated() / MatchHost.DT, 1.0) if host != null else 0.0
	return _now() - int(_entries[i]["at"]) + partial


## Toast i's look now, as look_at() gives it.
func look(i: int) -> Vector2:
	return look_at(age(i))


## Places the toasts for this frame: stacked down from the top, newest at the
## bottom, each faded and lifted by its entrance.
func refresh() -> void:
	var y: float = 0.0
	for i: int in get_child_count():
		var box: Control = get_child(i)
		var h: float = box.get_combined_minimum_size().y
		var l: Vector2 = look(i) if i < _entries.size() else Vector2.ZERO
		box.size = Vector2(size.x, h)
		box.position = Vector2(0.0, y + l.y)
		box.modulate.a = l.x
		y += h + GAP


func _now() -> int:
	return host.step_count if host != null else 0


## One box per toast, in order.
func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	for t: Dictionary in _entries:
		var box: VBoxContainer = VBoxContainer.new()
		box.name = "Toast%d" % get_child_count()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		var text: Label = _label("Text", t["text"], UiTheme.DISPLAY, TEXT_SIZE, 8)
		text.add_theme_color_override("font_color", TONE_COLORS[t["tone"]])
		box.add_child(text)
		var sub: Label = _label("Sub", t["sub"], UiTheme.EYEBROW, SUB_SIZE, 4)
		sub.visible = t["sub"] != ""
		box.add_child(sub)
		add_child(box)
	refresh()


## A centred label in a theme variation, ink-outlined to read over the arena
## (the demo's text shadow).
static func _label(node_name: String, text: String, variation: StringName, font_size: int, outline: int) -> Label:
	var l: Label = UiTheme.label(text, variation, font_size)
	l.name = node_name
	l.add_theme_color_override("font_outline_color", Color(UiPalette.LACQUER, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
