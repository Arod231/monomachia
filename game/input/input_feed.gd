class_name InputFeed
extends Node
## Hands every input event to an InputDevices and tells the host when the
## window loses focus. Port of the window listeners in v0.1-web-mvp:src/input/devices.ts and
## the blur handler in v0.1-web-mvp:src/game.ts.
##
## Events go to InputDevices.note_event() from _input(), which runs before the
## GUI: a focused menu item takes ui_accept, and the viewport takes focus
## moves, so _unhandled_input() never sees them. Seeing them keeps the labels
## and the Controls screen's first tab on the last device used, and tracks
## which Shift, Ctrl or Alt key is held.
##
## When the application loses focus, the held keys are released (the demo
## cleared its keys on blur) and focus_lost is emitted: the host pauses a match
## on it (spec story 10).
##
## The host adds one to the tree with the InputDevices it samples:
##   var feed := InputFeed.new(input)
##   add_child(feed)
##   feed.focus_lost.connect(pause)

## The window lost focus: pause a match that is being played.
signal focus_lost

var input: InputDevices


func _init(p_input: InputDevices = null) -> void:
	input = p_input
	# Menus and the pause screen still need events while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if input != null:
		input.note_event(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if input != null:
			input.release_keys()
		focus_lost.emit()
