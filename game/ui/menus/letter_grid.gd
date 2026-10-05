class_name LetterGrid
extends VBoxContainer
## An on-screen letter grid for typing a name with a controller (22.12),
## since Godot on Windows has no on-screen keyboard: A–Z and 0–9 in rows,
## then Space, Shift (lower case), Delete and Done. A cursor walks it
## (move(), with the D-pad or stick: left and right wrap round a row, up and
## down wrap round the rows, keeping to a key on a shorter row) and press()
## acts on the key under it. A click on a key moves the cursor there and
## presses it. The keys never take the focus: the page drives the grid.

## A character to add.
signal typed(text: String)
## Delete: take off the last character.
signal erased
## Done: the name is finished.
signal done

const ROWS: Array[String] = ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ0123", "456789"]
const SPACE: String = "Space"
const SHIFT: String = "Shift"
const DELETE: String = "Delete"
const DONE: String = "Done"
## The last row's keys.
const SPECIALS: Array[String] = [SPACE, SHIFT, DELETE, DONE]

## (row, column) of the key under the cursor; the specials are row
## ROWS.size().
var cursor: Vector2i = Vector2i.ZERO:
	set(v):
		cursor = v
		_light()
## Letters type in lower case.
var shift: bool = false
## Rows of key buttons, the specials last.
var keys: Array[Array] = []


func _init() -> void:
	name = "LetterGrid"
	add_theme_constant_override("separation", 6)
	for r: int in ROWS.size() + 1:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		var buttons: Array[Button] = []
		var count: int = SPECIALS.size() if r == ROWS.size() else ROWS[r].length()
		for c: int in count:
			var b: Button = Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(108.0 if r == ROWS.size() else 52.0, 44.0)
			b.pressed.connect(_on_click.bind(Vector2i(r, c)))
			row.add_child(b)
			buttons.append(b)
		keys.append(buttons)
	_relabel()
	_light()


## The text of a key: a letter or digit (lower case with Shift), or a
## special's name.
func key_text(at: Vector2i) -> String:
	if at.x == ROWS.size():
		return SPECIALS[at.y]
	var ch: String = ROWS[at.x][at.y]
	return ch.to_lower() if shift else ch


## Moves the cursor one key (MenuNav's UP, DOWN, LEFT or RIGHT).
func move(cmd: MenuNav.Cmd) -> void:
	var r: int = cursor.x
	var c: int = cursor.y
	match cmd:
		MenuNav.Cmd.LEFT:
			c = posmod(c - 1, _row_size(r))
		MenuNav.Cmd.RIGHT:
			c = posmod(c + 1, _row_size(r))
		MenuNav.Cmd.UP:
			r = posmod(r - 1, ROWS.size() + 1)
		MenuNav.Cmd.DOWN:
			r = posmod(r + 1, ROWS.size() + 1)
		_:
			return
	cursor = Vector2i(r, mini(c, _row_size(r) - 1))


## Acts on the key under the cursor.
func press() -> void:
	match key_text(cursor):
		SPACE:
			typed.emit(" ")
		SHIFT:
			shift = not shift
			_relabel()
			_light()
		DELETE:
			erased.emit()
		DONE:
			done.emit()
		var ch:
			typed.emit(ch)


func _row_size(r: int) -> int:
	return SPECIALS.size() if r == ROWS.size() else ROWS[r].length()


func _on_click(at: Vector2i) -> void:
	cursor = at
	press()


func _relabel() -> void:
	for r: int in keys.size():
		for c: int in keys[r].size():
			(keys[r][c] as Button).text = key_text(Vector2i(r, c))


## The key under the cursor lit as a chosen option, the others plain.
func _light() -> void:
	for r: int in keys.size():
		for c: int in keys[r].size():
			var lit: bool = Vector2i(r, c) == cursor or (keys[r][c] == _shift_key() and shift)
			(keys[r][c] as Button).theme_type_variation = UiTheme.OPTION_ON if lit else UiTheme.OPTION


func _shift_key() -> Button:
	return keys[ROWS.size()][SPECIALS.find(SHIFT)] if keys.size() > ROWS.size() else null
