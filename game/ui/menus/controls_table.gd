class_name ControlsTable
extends RefCounted
## The Controls screen's binding table as plain data, for the screen and its
## tests: the 14 actions with two slots each, named in a button style, the tab
## the screen opens on and the controller status line. Port of the table,
## tabs and status of showControls() in v0.1-web-mvp:src/ui/menus.ts.

## An empty slot.
const EMPTY: String = "—"
## The keyboard tab's note over the table.
const KB_NOTE: String = "Choose a slot, then press the key or mouse button. Esc cancels, Backspace clears. Sprint also works by double-tapping a direction."
## The controller tab's line under the status: how to bind, clear and back out.
const PAD_NOTE: String = "Choose a slot, then press a button, pull a trigger or push a stick. Y clears a slot (△ on PlayStation), and a slot stops listening after 5 seconds."


## One action's row: its name, small print and the two slots' labels (EMPTY
## when unbound) with their tokens ("" when unbound).
class Row:
	var action: String
	var label: String
	var hint: String
	var slots: Array[String] = []
	var tokens: Array[String] = []


## The rows of one tab (ControlProfile.KB or PAD) of a profile. style is a
## PadStyle constant, used for controller tokens only.
static func rows(profile: ControlProfile, tab: String, style: int) -> Array[Row]:
	var out: Array[Row] = []
	for action: String in Bindings.ACTIONS:
		var r: Row = Row.new()
		r.action = action
		r.label = Bindings.ACTION_LABELS[action]
		r.hint = Bindings.ACTION_HINTS.get(action, "")
		var tokens: Array[String] = profile.slots(tab, action)
		for slot: int in Bindings.SLOTS:
			var token: String = tokens[slot] if slot < tokens.size() else ""
			r.tokens.append(token)
			r.slots.append(BindingLabels.token_label(token, style) if token != "" else EMPTY)
		out.append(r)
	return out


## The tab of the last device used: the controller tab after a controller,
## else keyboard and mouse.
static func opening_tab(input: InputDevices) -> String:
	return ControlProfile.PAD if input.last_used == InputDevices.LastUsed.PAD else ControlProfile.KB


## The controller tab's line over the table: the connected controller and the
## names its buttons get, or how to connect one.
static func status_line(input: InputDevices) -> String:
	if input.first_pad() < 0:
		return "No controller detected. Connect one and press any button on it."
	var names: String = "%s button names" % PadStyle.display_name(input.pad_style())
	if not input.first_pad_known():
		names += ", unrecognised layout: set buttons below"
	return "Controller connected: %s (%s)" % [input.first_pad_name(), names]
