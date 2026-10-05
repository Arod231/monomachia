class_name TrainingPanel
extends PanelContainer
## Training's panel at the bottom left of the HUD (port of
## setupTrainingPanel() and trainingKeys() in v0.1-web-mvp:src/game.ts): "Dummy ·
## <weapon>", a hint, a chip per behaviour the roster offers (Roster.behaviours(),
## eight while the Greatsword's Slam is hidden) numbered from 1, and the refill
## chip numbered 0, the dummy's behaviour and the refill lit.
##
## A click on a chip, or its number key during play, tells the host
## (MatchHost.set_training_behaviour, set_refill). A digit bound to an action
## in the player's profile is left to that action. The chips never take the
## focus, so the keys and the mouse never fight the match for it. The panel
## shows only in a Training match being played (the pause menu has its own
## Training rows, so it hides while paused), and follows the
## host's training_changed and loadout_changed, so the pause menu's rows and
## a weapon swap show here too.

var host: MatchHost
var heading: Label
var hint: Label
## The behaviours offered, as the roster stood when the panel was made.
var behaviours: Array[StringName] = Roster.behaviours()
## One per behaviour, in that order.
var chips: Array[Button] = []
var refill_chip: Button
## Is the host's match a played Training match?
var _training: bool = false


func _init() -> void:
	name = "TrainingPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 24.0
	# above the HUD's packs-missing note in the same corner
	offset_bottom = -48.0
	custom_minimum_size = Vector2(560.0, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	heading = UiTheme.label("", UiTheme.DISPLAY, 22)
	heading.name = "Heading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(heading)
	hint = UiTheme.label("What should the dummy do? Keys 1–%d also work." % behaviours.size(), UiTheme.MUTED, 15)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hint)
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "Behaviours"
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	var names: Array[String] = MenuData.behaviour_names()
	for i: int in names.size():
		var chip: Button = _chip("%d %s" % [i + 1, names[i]])
		chip.pressed.connect(_choose.bind(i))
		row.add_child(chip)
		chips.append(chip)
	refill_chip = _chip("")
	refill_chip.pressed.connect(_toggle_refill)
	box.add_child(refill_chip)
	refill_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func bind(p_host: MatchHost) -> void:
	if host != null:
		host.match_started.disconnect(_on_match_started)
		host.training_changed.disconnect(refresh)
		host.loadout_changed.disconnect(_on_loadout_changed)
		host.stopped.disconnect(_on_stopped)
		host.pause_changed.disconnect(_on_pause_changed)
	host = p_host
	host.match_started.connect(_on_match_started)
	host.training_changed.connect(refresh)
	host.loadout_changed.connect(_on_loadout_changed)
	host.stopped.connect(_on_stopped)
	host.pause_changed.connect(_on_pause_changed)
	if host.is_started():
		_on_match_started(host.config)


## Whether behaviour chip i is lit (the dummy's behaviour).
func is_lit(i: int) -> bool:
	return chips[i].theme_type_variation == UiTheme.OPTION_ON


func refill_lit() -> bool:
	return refill_chip.theme_type_variation == UiTheme.OPTION_ON


## Brings the heading and the chips up to the host.
func refresh() -> void:
	if host == null or not host.is_started() or host.training_behaviour() == &"":
		return
	heading.text = "Dummy · %s" % host.fighter(host.config.dummy_side()).weapon.name
	var b: int = behaviours.find(host.training_behaviour())
	for i: int in chips.size():
		chips[i].theme_type_variation = UiTheme.OPTION_ON if i == b else UiTheme.OPTION
	var on: bool = host.refill()
	refill_chip.text = "0 Refill health: %s" % ("on" if on else "off")
	refill_chip.theme_type_variation = UiTheme.OPTION_ON if on else UiTheme.OPTION


## Whether a top-row digit key is bound to an action in the player's
## profile (then it plays that action, not the panel).
static func digit_bound(profile: ControlProfile, physical_keycode: int) -> bool:
	var token: String = InputToken.key(physical_keycode)
	for action: String in profile.kb:
		if (profile.kb[action] as Array).has(token):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or host == null or not host.is_playing():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code: int = key.physical_keycode
	if code < KEY_0 or code > KEY_9:
		return
	var player: int = host.player_of_side(host.config.first_human_side())
	if player >= 0 and host.input != null and digit_bound(host.input.profile_of(player), code):
		return
	get_viewport().set_input_as_handled()
	if code == KEY_0:
		_toggle_refill()
	else:
		_choose(code - KEY_1)


func _choose(i: int) -> void:
	if host != null and i >= 0 and i < behaviours.size():
		host.set_training_behaviour(behaviours[i])


func _toggle_refill() -> void:
	if host != null:
		host.set_refill(not host.refill())


func _on_match_started(cfg: MatchConfig) -> void:
	_training = cfg.mode == MatchConfig.TRAINING and not host.attract
	visible = _training
	refresh()


func _on_loadout_changed(_side: int) -> void:
	refresh()


func _on_stopped() -> void:
	_training = false
	visible = false


func _on_pause_changed(paused: bool) -> void:
	visible = _training and not paused


func _chip(text: String) -> Button:
	var chip: Button = Button.new()
	chip.text = text
	chip.theme_type_variation = UiTheme.OPTION
	chip.focus_mode = Control.FOCUS_NONE
	return chip
