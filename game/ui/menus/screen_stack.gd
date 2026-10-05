class_name ScreenStack
extends RefCounted
## The menus' pages, one over the other: only the top one shows. A page
## pushed over another goes back to it on Back (when the page's back_pops is
## on), which reopens it on the item that opened the new page.
##
## The pages are the caller's nodes (main.gd keeps them all under its Menus
## layer): the stack only opens and closes them.

## The top page changed (null when the stack is empty).
signal changed(top: MenuPage)

var pages: Array[MenuPage] = []


func top() -> MenuPage:
	return null if pages.is_empty() else pages[-1]


func has(page: MenuPage) -> bool:
	return pages.has(page)


## Opens a page over the top one, which closes and remembers its focus.
func push(page: MenuPage) -> void:
	if page == null or top() == page:
		return
	if pages.has(page):
		_drop(page)
	var under: MenuPage = top()
	if under != null:
		under.close()
	_listen(page)
	pages.append(page)
	page.open()
	changed.emit(page)


## Closes the top page and reopens the one under it.
func pop() -> void:
	if pages.is_empty():
		return
	var gone: MenuPage = pages.pop_back()
	gone.close()
	_unlisten(gone)
	var under: MenuPage = top()
	if under != null:
		under.reopen()
	changed.emit(under)


## Replaces the whole stack: `stack` from the bottom up, with the last one
## open (and every page under it on its first item when it reopens).
func reset(stack: Array[MenuPage]) -> void:
	_close_all()
	for page: MenuPage in stack:
		page.forget_focus()
		_listen(page)
		pages.append(page)
	var t: MenuPage = top()
	if t != null:
		t.open()
	changed.emit(t)


## Closes every page.
func clear() -> void:
	_close_all()
	changed.emit(null)


func _close_all() -> void:
	for page: MenuPage in pages:
		page.close()
		_unlisten(page)
	pages.clear()


func _drop(page: MenuPage) -> void:
	page.close()
	_unlisten(page)
	pages.erase(page)


func _listen(page: MenuPage) -> void:
	if not page.back_requested.is_connected(_on_back.bind(page)):
		page.back_requested.connect(_on_back.bind(page))


func _unlisten(page: MenuPage) -> void:
	if page.back_requested.is_connected(_on_back.bind(page)):
		page.back_requested.disconnect(_on_back.bind(page))


func _on_back(page: MenuPage) -> void:
	if page == top() and page.back_pops:
		pop()
