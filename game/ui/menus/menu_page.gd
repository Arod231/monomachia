class_name MenuPage
extends Control
## One full-screen page of the menus, shown by a ScreenStack: a list of items
## (entries, option rows, slider rows, cards) walked with the keyboard, the
## mouse or a controller.
##
## MenuNav reads the events: up and down move the focus through the items
## (wrapping round), left and right change an option or slider row (an item
## with nav_step(), see OptionRow) and otherwise move like up and down, OK
## chooses (presses a button, or an item's nav_press()), and Back plays
## ui_back and emits back_requested. A held D-pad or stick repeats. Hovering
## an item with the mouse focuses it.
##
## The page takes its events from the focused item's gui_input signal, ahead
## of the item and of Godot's own focus moves, and with nothing focused in
## _unhandled_input(); it never takes one in _input(), where the InputFeed
## (GameServices) sees every event first, so the controls' labels follow the
## device last used.
##
## Sounds (GameServices.play_ui): ui_move when the focus moves from one item
## to another or a row's value changes (opening a page is silent),
## ui_select when an entry is pressed, ui_back on Back.

## Back (Esc, Backspace, controller B) was pressed while the page is open.
signal back_requested

## Whether Back closes the page on its ScreenStack (back to the page that
## opened it). A page that does something else on Back (the title, the pause
## menu, the results) turns it off and answers back_requested itself.
var back_pops: bool = true
var nav: MenuNav = MenuNav.new()
## The focusable items, in focus order.
var items: Array[Control] = []
## The item that had the focus when the page last closed, for reopening.
var _remembered: Control = null
## The item that last lost the focus, while the focus is between items.
var _left: Control = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


## Makes a control one of the page's items, after the last.
func add_item(c: Control) -> Control:
	c.focus_mode = Control.FOCUS_ALL
	c.mouse_entered.connect(_hover.bind(c))
	c.focus_entered.connect(_on_item_focused.bind(c))
	c.focus_exited.connect(_on_item_unfocused.bind(c))
	c.gui_input.connect(_on_item_input.bind(c))
	if c is BaseButton:
		(c as BaseButton).pressed.connect(GameServices.play_ui.bind(&"ui_select"))
	items.append(c)
	return c


## Takes an item out of the page (and its focus order).
func remove_item(c: Control) -> void:
	if not items.has(c):
		return
	items.erase(c)
	c.mouse_entered.disconnect(_hover.bind(c))
	c.focus_entered.disconnect(_on_item_focused.bind(c))
	c.focus_exited.disconnect(_on_item_unfocused.bind(c))
	c.gui_input.disconnect(_on_item_input.bind(c))
	if c is BaseButton:
		(c as BaseButton).pressed.disconnect(GameServices.play_ui.bind(&"ui_select"))
	if _remembered == c:
		_remembered = null


## Shows the page with its first item focused.
func open() -> void:
	_remembered = null
	reopen()


## Shows the page again with the item it last had focused (the first if
## none), as when a page it opened goes back to it.
func reopen() -> void:
	visible = true
	_left = null
	nav.reset()
	set_process(true)
	var target: Control = _remembered if items.has(_remembered) else first_item()
	if target != null and is_inside_tree():
		target.grab_focus.call_deferred()


func close() -> void:
	var f: Control = focused_item()
	if f != null:
		_remembered = f
	visible = false
	nav.reset()
	set_process(false)


## Forgets the remembered focus: the page reopens on its first item.
func forget_focus() -> void:
	_remembered = null


func first_item() -> Control:
	for c: Control in items:
		if _focusable(c):
			return c
	return null


## The item with the focus, or null.
func focused_item() -> Control:
	if not is_inside_tree():
		return null
	var f: Control = get_viewport().gui_get_focus_owner()
	return f if f != null and items.has(f) else null


## Moves the focus `step` items on, wrapping round and skipping hidden or
## disabled items. With nothing focused, focuses the first item.
func move_focus(step: int) -> void:
	var from: Control = focused_item()
	if from == null:
		var first: Control = first_item()
		if first != null:
			first.grab_focus()
		return
	var i: int = items.find(from)
	for _n: int in items.size():
		i = posmod(i + step, items.size())
		if _focusable(items[i]):
			items[i].grab_focus()
			return


## Carries out a menu command on the focused item (or with none focused).
func act(cmd: MenuNav.Cmd) -> void:
	var item: Control = focused_item()
	match cmd:
		MenuNav.Cmd.BACK:
			GameServices.play_ui(&"ui_back")
			back_requested.emit()
		MenuNav.Cmd.UP:
			move_focus(-1)
		MenuNav.Cmd.DOWN:
			move_focus(1)
		MenuNav.Cmd.LEFT, MenuNav.Cmd.RIGHT:
			var dir: int = -1 if cmd == MenuNav.Cmd.LEFT else 1
			if item != null and item.has_method(&"nav_step"):
				if item.call(&"nav_step", dir):
					GameServices.play_ui(&"ui_move")
			else:
				move_focus(dir)
		MenuNav.Cmd.OK:
			if item == null:
				move_focus(1)
			elif item is BaseButton:
				if not (item as BaseButton).disabled:
					(item as BaseButton).pressed.emit()
			elif item.has_method(&"nav_press"):
				item.call(&"nav_press")


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cmd: MenuNav.Cmd = nav.tick()
	if cmd != MenuNav.Cmd.NONE:
		act(cmd)


func _on_item_input(event: InputEvent, item: Control) -> void:
	if not is_visible_in_tree() or not MenuNav.is_nav_event(event):
		return
	item.accept_event()
	var cmd: MenuNav.Cmd = nav.command(event)
	if cmd != MenuNav.Cmd.NONE:
		act(cmd)


## With no item focused (none yet, or the focus lost to a click elsewhere),
## the page reads the events here: a move or OK brings the focus back.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or focused_item() != null or not MenuNav.is_nav_event(event):
		return
	get_viewport().set_input_as_handled()
	var cmd: MenuNav.Cmd = nav.command(event)
	if cmd != MenuNav.Cmd.NONE:
		act(cmd)


func _hover(c: Control) -> void:
	if is_visible_in_tree() and _focusable(c):
		c.grab_focus()


func _on_item_focused(c: Control) -> void:
	if _left != null and _left != c:
		GameServices.play_ui(&"ui_move")
	_left = null


func _on_item_unfocused(c: Control) -> void:
	_left = c


static func _focusable(c: Control) -> bool:
	if not c.is_visible_in_tree() and c.is_inside_tree():
		return false
	if not c.visible:
		return false
	return not (c is BaseButton and (c as BaseButton).disabled)
