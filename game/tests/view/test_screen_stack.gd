extends GutTest
## ScreenStack (22.2): pages one over the other, Back returning to the page
## that opened one, on the item that opened it.

var stack: ScreenStack
var bottom: MenuScreen
var middle: MenuScreen
var top: MenuScreen
var tops: Array[MenuPage] = []


func _page(n: String) -> MenuScreen:
	var p: MenuScreen = MenuScreen.new()
	p.name = n
	for label: String in ["A", "B", "C"]:
		p.add_button(label, "", func() -> void: pass)
	add_child_autofree(p)
	return p


func before_each() -> void:
	stack = ScreenStack.new()
	bottom = _page("Bottom")
	middle = _page("Middle")
	top = _page("Top")
	tops.clear()
	stack.changed.connect(func(t: MenuPage) -> void: tops.append(t))


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		get_viewport().push_input(e)


func test_only_the_top_page_shows() -> void:
	stack.push(bottom)
	stack.push(middle)
	assert_false(bottom.visible)
	assert_true(middle.visible)
	assert_eq(stack.top(), middle)
	assert_eq(tops, [bottom, middle] as Array[MenuPage])


func test_back_returns_to_the_opener_on_the_item_that_opened_it() -> void:
	stack.push(bottom)
	await get_tree().process_frame
	_key(KEY_DOWN)
	assert_eq(bottom.focused_item(), bottom.buttons[1])
	stack.push(middle)
	await get_tree().process_frame
	assert_eq(middle.focused_item(), middle.buttons[0])
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_eq(stack.top(), bottom)
	assert_true(bottom.visible)
	assert_false(middle.visible)
	assert_eq(bottom.focused_item(), bottom.buttons[1], "back on the item that opened the page")


func test_back_on_a_page_that_keeps_it_does_not_pop() -> void:
	middle.back_pops = false
	stack.push(bottom)
	stack.push(middle)
	watch_signals(middle)
	_key(KEY_ESCAPE)
	assert_eq(stack.top(), middle)
	assert_signal_emitted(middle, "back_requested", "the page answers Back itself")


func test_back_on_the_last_page_empties_the_stack() -> void:
	stack.push(bottom)
	_key(KEY_BACKSPACE)
	assert_null(stack.top())
	assert_false(bottom.visible)
	assert_eq(tops, [bottom, null] as Array[MenuPage])


func test_reset_replaces_the_stack_and_opens_the_last() -> void:
	stack.push(top)
	stack.reset([bottom, middle] as Array[MenuPage])
	assert_false(top.visible)
	assert_false(bottom.visible)
	assert_true(middle.visible)
	stack.pop()
	assert_eq(stack.top(), bottom)
	await get_tree().process_frame
	assert_eq(bottom.focused_item(), bottom.buttons[0], "a page reset under the top starts on its first item")


func test_a_page_pushed_again_moves_to_the_top() -> void:
	stack.push(bottom)
	stack.push(middle)
	stack.push(bottom)
	assert_eq(stack.pages, [middle, bottom] as Array[MenuPage])
	assert_true(bottom.visible)
	assert_false(middle.visible)


func test_clear_closes_every_page() -> void:
	stack.push(bottom)
	stack.push(middle)
	stack.clear()
	assert_null(stack.top())
	assert_false(middle.visible)
	assert_eq(tops[-1], null)
	_key(KEY_ESCAPE)
	assert_null(stack.top(), "a closed page's Back does nothing")


func test_pages_closed_by_the_stack_stop_listening() -> void:
	stack.push(bottom)
	stack.pop()
	bottom.open()
	bottom.back_requested.emit()
	assert_null(stack.top(), "a page off the stack doesn't pop it")
