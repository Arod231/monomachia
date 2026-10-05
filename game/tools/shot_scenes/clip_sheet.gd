extends Node3D
## The catalogue of Iglesias clips (ClipLibraries): every clip of the clip
## manifest on both fighters, a page per catalogue group (ClipManifest.GROUPS:
## each weapon's moves, bare hands, and the states every weapon shares), with
## the page's weapon fixed in hand (FighterModel.fix_weapons(); the states
## page holds the Katana, bare hands nothing). Each clip is a row, captioned
## with its name, length and markers: the Hunter playing HumanM, then the
## Rogue playing HumanF, each at the clip's four manifest markers (wind-up,
## contact, contact end, settle), from three-quarters in front on the weapon
## side. Needs the libraries (`node scripts/godot.mjs clips`); without them
## it fails, naming the fix.
##
##   npm run shots -- res://tools/shot_scenes/clip_sheet.tscn <out.png> 1 [--option=value...]
##
## Options:
## - --page=<group>|all (default all): which pages; with several, each is
##   saved beside <out.png> as <out>_<group>.png, and <out.png> is the first;
## - --weapon=katana|greatsword|daggers|none: the weapon in hand instead of
##   the page's own;
## - --clips=<id>,<id>...: these clips instead of the page's;
## - --reverse: the Daggers in the reverse grip.

const FIGHTERS: Array[StringName] = [&"hunter", &"rogue"]
## Each page's weapon in hand (&"none" for bare hands).
const PAGE_WEAPONS: Dictionary[StringName, StringName] = {
	&"katana": &"katana", &"greatsword": &"greatsword", &"daggers": &"daggers", &"bare": &"none", &"states": &"katana",
}
const CELL: int = 220
const CAPTION: int = 30
const HEADER: int = 64
const GAP: int = 6
## The gap between the Hunter's cells and the Rogue's.
const SPLIT: int = 24
const FONT: int = 16
const BACKGROUND: Color = Color8(24, 25, 28)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.87)
const PreviewScene := preload("res://fighters/preview/preview.gd")

## False to drive the sheet by hand (tests).
var auto_run: bool = true
var pages: Array[StringName] = ClipManifest.GROUPS.duplicate()
## Overrides of the pages' own weapon and clips, when given.
var weapon_override: StringName = &""
var clips_override: Array[StringName] = []
var reverse: bool = false
var out_path: String = ""
var models: Array[FighterModel] = []
var manifest: ClipManifest

var _camera: Camera3D
var _overlay: CanvasLayer
var _sheet: Image
var _done: bool = false


func _ready() -> void:
	manifest = ClipManifest.read()
	if auto_run:
		apply_args(OS.get_cmdline_user_args())
	PreviewScene.build_studio_stage(self)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	_overlay.visible = false
	add_child(_overlay)
	if not ClipLibraries.available():
		if auto_run:
			push_error("clip_sheet: no clip libraries; run `node scripts/godot.mjs clips` (needs the packs, see .assets-src-path)")
		_done = true
		return
	for i: int in FIGHTERS.size():
		var m: FighterModel = FighterLook.instantiate_fighter(FIGHTERS[i])
		m.autoplay_idle = false
		add_child(m)
		var set_name: StringName = ClipLibraries.SETS[i]
		m.animation_player.add_animation_library(set_name, ClipLibraries.load_set(set_name))
		models.append(m)
	if auto_run:
		GraphicsApplier.apply(GameServices.graphics_preset(), self, get_viewport())
		_run.call_deferred()


func shot_frames() -> int:
	return 1


func shot_ready() -> bool:
	return _done


func shot_image() -> Image:
	return _sheet


## Reads --page=, --weapon=, --clips=, --reverse and shot.gd's --out=. An
## unknown page, weapon or clip is an error, so the shot run fails.
func apply_args(args: PackedStringArray) -> void:
	for a: String in args:
		if a == "--reverse":
			reverse = true
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--page="):
			var p: String = a.substr(7)
			if p == "all":
				continue
			if not ClipManifest.GROUPS.has(StringName(p)):
				push_error("clip_sheet: unknown page %s" % p)
				continue
			pages = [StringName(p)]
		elif a.begins_with("--weapon="):
			var w: String = a.substr(9)
			if w != "none" and not WeaponLook.IDS.has(StringName(w)):
				push_error("clip_sheet: unknown weapon %s" % w)
				continue
			weapon_override = StringName(w)
		elif a.begins_with("--clips="):
			for id: String in a.substr(8).split(",", false):
				if not manifest.clips.has(StringName(id)):
					push_error("clip_sheet: %s is not in the clip manifest" % id)
					continue
				clips_override.append(StringName(id))


## The clips a page shows.
func page_clips(page: StringName) -> Array[StringName]:
	return clips_override if not clips_override.is_empty() else manifest.in_group(page)


## The weapon a page holds.
func page_weapon(page: StringName) -> StringName:
	return weapon_override if weapon_override != &"" else PAGE_WEAPONS[page]


## Where a page is saved when there are several.
static func sheet_path(out: String, page: StringName) -> String:
	return out.get_basename() + "_" + String(page) + ".png"


func _run() -> void:
	for i: int in pages.size():
		var sheet: Image = await render(pages[i])
		if i == 0:
			_sheet = sheet
		if pages.size() > 1 and out_path != "":
			sheet.save_png(sheet_path(out_path, pages[i]))
	_done = true


## One page.
func render(page: StringName) -> Image:
	var weapon: StringName = page_weapon(page)
	for m: FighterModel in models:
		m.detach_weapons()
		if weapon != &"none":
			m.attach_weapon(WeaponLook.load_id(weapon))
			m.fix_weapons(reverse)
	var rows: Array[Array] = []
	var ids: Array[StringName] = page_clips(page)
	for clip: StringName in ids:
		var c: ClipManifest.Clip = manifest.clips[clip]
		var cells: Array[Image] = []
		var length: float = 0.0
		for i: int in models.size():
			var m: FighterModel = models[i]
			var anim_name: String = "%s/%s" % [ClipLibraries.SETS[i], clip]
			length = m.animation_player.get_animation(anim_name).length
			for marker: String in ClipManifest.MARKERS:
				m.animation_player.play(anim_name, 0.0)
				m.animation_player.seek(minf(c.markers[marker] / ClipManifest.SOURCE_FPS, length), true)
				m.animation_player.pause()
				cells.append(await _capture(i))
		var line: String = "%s · %d frames (%.2f s)%s%s · markers %s%s · Hunter (HumanM) | Rogue (HumanF)" % [
			clip, roundi(length * ClipManifest.SOURCE_FPS), length, " · loops" if c.loop else "", " · mirrored" if c.mirror else "",
			" ".join(ClipManifest.MARKERS.map(func(k: String) -> String: return str(c.markers[k]))),
			" (provisional)" if c.provisional else ""]
		rows.append([await _text([line], Vector2i(_width(), CAPTION)), cells])
	var head: Image = await _text([
		"Clip catalogue: %s · %d clips · %s%s in hand (off hand on IK for a two-handed weapon)" % [
			page, ids.size(), "no weapon" if weapon == &"none" else String(weapon).capitalize(), " in the reverse grip" if reverse else ""],
		"each row: the Hunter, then the Rogue, at the wind-up, contact, contact-end and settle markers, from three-quarters in front",
	], Vector2i(_width(), HEADER))
	return _compose(head, rows)


func _width() -> int:
	var per: int = CELL * ClipManifest.MARKERS.size() + GAP * (ClipManifest.MARKERS.size() - 1)
	return per * FIGHTERS.size() + SPLIT * (FIGHTERS.size() - 1)


func _capture(fighter: int) -> Image:
	for i: int in models.size():
		models[i].visible = i == fighter
	var forward: Vector3 = Vector3.BACK
	_camera.fov = 45.0
	_camera.look_at_from_position(forward.rotated(Vector3.UP, deg_to_rad(-45.0)) * 3.8 + Vector3(0.0, 1.3, 0.0),
		forward * 0.5 + Vector3(0.0, 0.95, 0.0), Vector3.UP)
	var screen: Image = await _screen()
	var h: int = screen.get_height()
	var cell: Image = screen.get_region(Rect2i((screen.get_width() - h) / 2, 0, h, h))
	cell.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	return cell


func _screen() -> Image:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		var blank: Image = Image.create(CELL * 2, CELL * 2, false, Image.FORMAT_RGBA8)
		blank.fill(BACKGROUND)
		return blank
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _text(lines: Array, size: Vector2i) -> Image:
	for child: Node in _overlay.get_children():
		child.free()
	var back: ColorRect = ColorRect.new()
	back.color = BACKGROUND
	back.size = get_viewport().get_visible_rect().size
	_overlay.add_child(back)
	for i: int in lines.size():
		var label: Label = Label.new()
		label.text = lines[i]
		label.position = Vector2(8, 6 + i * (FONT + 9))
		label.add_theme_font_size_override(&"font_size", FONT)
		label.add_theme_color_override(&"font_color", TEXT_COLOR)
		_overlay.add_child(label)
	_overlay.visible = true
	var screen: Image = await _screen()
	_overlay.visible = false
	var out: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.fill(BACKGROUND)
	out.blit_rect(screen, Rect2i(0, 0, mini(size.x, screen.get_width()), mini(size.y, screen.get_height())), Vector2i.ZERO)
	return out


func _compose(head: Image, rows: Array[Array]) -> Image:
	var h: int = head.get_height()
	for row: Array in rows:
		h += GAP + CAPTION + CELL
	var out: Image = Image.create(_width(), h, false, Image.FORMAT_RGBA8)
	out.fill(BACKGROUND)
	out.blit_rect(head, Rect2i(Vector2i.ZERO, head.get_size()), Vector2i.ZERO)
	var y: int = head.get_height()
	var per: int = ClipManifest.MARKERS.size()
	for row: Array in rows:
		y += GAP
		var cap: Image = row[0]
		out.blit_rect(cap, Rect2i(Vector2i.ZERO, cap.get_size()), Vector2i(0, y))
		y += CAPTION
		var cells: Array[Image] = row[1]
		for i: int in cells.size():
			var x: int = (i % per) * (CELL + GAP) + (i / per) * (per * (CELL + GAP) - GAP + SPLIT)
			out.blit_rect(cells[i], Rect2i(Vector2i.ZERO, cells[i].get_size()), Vector2i(x, y))
		y += CELL
	return out
