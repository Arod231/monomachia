extends Node
## A shot scene for the Animation Studio's gallery: opens the Studio on a tab and
## a body, lets the tiles in view start playing, and saves the window. Run
## through `node scripts/godot.mjs shots` (tools/shot.gd), which fills the
## window at 1600x900; the PNGs go to shots/studio/ (gitignored):
##
##   node scripts/godot.mjs shots res://tools/anim_studio/studio_shot.tscn shots/studio/katana_hunter.png 60 --tab=katana --body=hunter
##
## Options:
## - --tab=katana|daggers|greatsword|fists|states|ults|source (default katana)
## - --body=hunter|rogue (default hunter)
## - --search=<text>: type this in the search box
## - --badges=<badge>,<badge>...: choose these badge chips
## - --warm=<tab>: open this tab first and, once its tiles are built, switch to
##   --tab and start measuring (the libraries are loaded by then, so the
##   opening measured is a later one, not the first)
## - --budget=<n>: AnimTile.builds_per_frame (a huge number is the old build-all-at-once)
##
## It also prints how the frames went: how long opening the tab took until
## every tile in view had its fighter (frames, ms and the worst frame, the
## stall), then the average and the slowest frame after, and how many of the
## tab's tiles were built and playing. So it doubles as the gallery's
## performance check. `--fixed-fps` switches off the wait for the next frame, so
## a frame takes what its work costs (an empty gallery, `--search=zzz`, is the
## baseline: the Studio's own cost).

## Frames after the tiles in view are built before the shot is taken, so the
## animations are part way through and the viewports have drawn.
const SETTLE_FRAMES: int = 30

var studio: AnimStudio = null
var _tab: StringName = &"katana"
var _frames_since_ready: int = 0
## The frame (count) at which every tile in view had its fighter; -1 before.
var _built_at: int = -1
## The tab to open first (--warm), until it is built; empty after.
var _warm: StringName = &""
var _last_usec: int = 0
var _frame_msec: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var body: StringName = &"hunter"
	var search: String = ""
	var badges: Array[StringName] = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tab="):
			_tab = StringName(a.substr(6))
		elif a.begins_with("--body="):
			body = StringName(a.substr(7))
		elif a.begins_with("--search="):
			search = a.substr(9)
		elif a.begins_with("--warm="):
			_warm = StringName(a.substr(7))
		elif a.begins_with("--budget="):
			AnimTile.builds_per_frame = int(a.substr(9))
		elif a.begins_with("--badges="):
			for b: String in a.substr(9).split(",", false):
				badges.append(StringName(b))
	studio = (load("res://tools/anim_studio/studio.tscn") as PackedScene).instantiate() as AnimStudio
	add_child(studio)
	studio.set_fighter(body)
	var gallery: Gallery = studio.get_node("%Gallery") as Gallery
	gallery.show_group(_warm if _warm != &"" else _tab)
	if not search.is_empty() or not badges.is_empty():
		gallery.set_filter(search, badges)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _warm != &"" and _all_in_view_built(_warm):
		(studio.get_node("%Gallery") as Gallery).show_group(_tab)
		_warm = &""
		_frame_msec.clear()
		_last_usec = Time.get_ticks_usec()
		return
	if _warm != &"":
		_last_usec = now
		return
	_frame_msec.append(float(now - _last_usec) / 1000.0)
	_last_usec = now
	if _built_at < 0 and _all_in_view_built():
		_built_at = _frame_msec.size()
	elif _built_at >= 0:
		_frames_since_ready += 1


func shot_frames() -> int:
	return SETTLE_FRAMES


## True once the tiles in view are built and have had SETTLE_FRAMES to draw;
## then reports the frame times.
func shot_ready() -> bool:
	if _frames_since_ready < SETTLE_FRAMES:
		return false
	var gallery: Gallery = studio.get_node("%Gallery") as Gallery
	var tiles: Array[AnimTile] = gallery.tiles_in(_tab)
	var built: int = 0
	var playing: int = 0
	for t: AnimTile in tiles:
		built += 1 if t.model != null else 0
		playing += 1 if t.is_playing() else 0
	# The frames up to the one that finished building the tiles in view (the
	# worst of them is the stall), then the frames after, the first few skipped.
	var open_total: float = 0.0
	var open_worst: float = 0.0
	for i: int in _built_at:
		open_total += _frame_msec[i]
		open_worst = maxf(open_worst, _frame_msec[i])
	var total: float = 0.0
	var slowest: float = 0.0
	var count: int = 0
	for i: int in range(_built_at + 5, _frame_msec.size()):
		total += _frame_msec[i]
		slowest = maxf(slowest, _frame_msec[i])
		count += 1
	print("studio_shot: opening frames (ms): ", _frame_msec.slice(0, _built_at))
	print("studio_shot: %s: %d tiles, %d built, %d playing; opening took %d frames, %.0f ms, worst frame %.0f ms; then %d frames, average %.1f ms, slowest %.1f ms" % [
		_tab, tiles.size(), built, playing, _built_at, open_total, open_worst, count, total / maxf(1.0, float(count)), slowest])
	return true


## True once at least one tile is playing and every tile in view has its
## fighter.
func _all_in_view_built(tab: StringName = _tab) -> bool:
	var gallery: Gallery = studio.get_node("%Gallery") as Gallery
	var any: bool = false
	for t: AnimTile in gallery.tiles_in(tab):
		if t.visible and t.is_on_screen():
			if t.model == null:
				return false
			any = true
	return any or not gallery.tiles_in(tab).any(func(t: AnimTile) -> bool: return t.visible)
