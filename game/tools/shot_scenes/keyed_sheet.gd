extends Node3D
## Contact sheets of a hand-keyed clip (KeyedClips), for reviewing a re-key:
## the clip on both fighters with the weapon fixed in hand, a row per fighter
## and view, a column per chosen rules frame. For the stomp a stand-in spear
## lies pinned under the right foot from its landing on, so the foot can be
## checked against it.
##
##   npm run shots -- res://tools/shot_scenes/keyed_sheet.tscn <out.png> 1 [--option=value...]
##
## Options:
## - --clip=<name> (default Mikiri_Stomp);
## - --weapon=katana|greatsword|daggers|none (default katana);
## - --at=<frame>,<frame>... rules frames (default every 2nd and the last);
## - --views=side,back,front (VIEWS, in order; default all three);
## - --cell=<px>: each cell's size (default 210).

const FIGHTERS: Array[StringName] = [&"hunter", &"rogue"]
## Each view's camera place and the point it looks at (fighter space: +Z
## forward, +X the fighter's left): the weapon side, behind over the right
## shoulder (the reference's camera), three-quarters in front.
const VIEWS: Dictionary[StringName, Array] = {
	&"side": [Vector3(-3.6, 1.0, 0.3), Vector3(0.0, 0.75, 0.25)],
	&"back": [Vector3(-1.3, 2.2, -3.2), Vector3(0.0, 0.7, 0.45)],
	&"front": [Vector3(2.1, 1.3, 3.2), Vector3(0.0, 0.8, 0.2)],
}
## The stand-in spear: from the attacker's hands to its tip on the floor,
## shown from the frame the foot lands.
const SPEAR_FROM: Vector3 = Vector3(-0.15, 0.9, 1.25)
const SPEAR_TO: Vector3 = Vector3(-0.12, 0.0, 0.29)
const SPEAR_FRAME: int = 8
var cell_size: int = 210
const CAPTION: int = 26
const HEADER: int = 56
const GAP: int = 4
const FONT: int = 15
const BACKGROUND: Color = Color8(24, 25, 28)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.87)
const PreviewScene := preload("res://fighters/preview/preview.gd")

var clip: StringName = KeyedClips.STOMP
var weapon: StringName = &"katana"
var at: Array[int] = []
var views: Array[StringName] = [&"side", &"back", &"front"]
var models: Array[FighterModel] = []

var _camera: Camera3D
var _overlay: CanvasLayer
var _spear: MeshInstance3D
var _sheet: Image
var _done: bool = false


func _ready() -> void:
	_apply_args(OS.get_cmdline_user_args())
	PreviewScene.build_studio_stage(self)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	_overlay.visible = false
	add_child(_overlay)
	var lib: AnimationLibrary = KeyedClips.load_library()
	if lib == null or not lib.has_animation(clip):
		push_error("keyed_sheet: no clip %s; run node scripts/godot.mjs script res://tools/build_keyed_clips.gd" % clip)
		_done = true
		return
	for id: StringName in FIGHTERS:
		var m: FighterModel = FighterLook.instantiate_fighter(id)
		m.autoplay_idle = false
		add_child(m)
		m.animation_player.add_animation_library(KeyedClips.LIBRARY, lib)
		if weapon != &"none":
			m.attach_weapon(WeaponLook.load_id(weapon))
			m.fix_weapons()
		models.append(m)
	if at.is_empty():
		var frames: int = roundi(lib.get_animation(clip).length * SimConst.FPS)
		for f: int in range(0, frames, 2):
			at.append(f)
		if at[-1] != frames:
			at.append(frames)
	_spear = _build_spear()
	GraphicsApplier.apply(GameServices.graphics_preset(), self, get_viewport())
	_run.call_deferred()


func shot_frames() -> int:
	return 1


func shot_ready() -> bool:
	return _done


func shot_image() -> Image:
	return _sheet


func _apply_args(args: PackedStringArray) -> void:
	for a: String in args:
		if a.begins_with("--clip="):
			clip = StringName(a.substr(7))
		elif a.begins_with("--cell="):
			cell_size = int(a.substr(7))
		elif a.begins_with("--weapon="):
			weapon = StringName(a.substr(9))
		elif a.begins_with("--at="):
			for s: String in a.substr(5).split(",", false):
				at.append(int(s))
		elif a.begins_with("--views="):
			views.clear()
			for s: String in a.substr(8).split(",", false):
				if VIEWS.has(StringName(s)):
					views.append(StringName(s))
				else:
					push_error("keyed_sheet: unknown view %s" % s)


func _build_spear() -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.018
	mesh.bottom_radius = 0.018
	mesh.height = SPEAR_FROM.distance_to(SPEAR_TO)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.22, 0.12)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	var mid: Vector3 = (SPEAR_FROM + SPEAR_TO) * 0.5
	var y: Vector3 = (SPEAR_FROM - SPEAR_TO).normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), mid)
	return mi


func _run() -> void:
	var anim_name: String = KeyedClips.anim_name(clip)
	var rows: Array[Array] = []
	for i: int in models.size():
		for view: StringName in views:
			var cells: Array[Image] = []
			for f: int in at:
				var m: FighterModel = models[i]
				m.animation_player.play(anim_name, 0.0)
				m.animation_player.seek(float(f) / float(SimConst.FPS), true)
				m.animation_player.pause()
				_spear.visible = clip == KeyedClips.STOMP and f >= SPEAR_FRAME
				cells.append(await _capture(i, view))
			rows.append([await _text(["%s · %s view" % [String(FIGHTERS[i]).capitalize(), view]], Vector2i(_width(), CAPTION)), cells])
	var head: Image = await _text([
		"Keyed clip: %s · %s in hand · rules frames %s" % [clip, "no weapon" if weapon == &"none" else String(weapon).capitalize(), ", ".join(at.map(func(f: int) -> String: return str(f)))],
		"rows: each fighter from the weapon side, from behind over the right shoulder, three-quarters in front",
	], Vector2i(_width(), HEADER))
	_sheet = _compose(head, rows)
	_done = true


func _width() -> int:
	return cell_size * at.size() + GAP * (at.size() - 1)


func _capture(fighter: int, view: StringName) -> Image:
	for i: int in models.size():
		models[i].visible = i == fighter
	var v: Array = VIEWS[view]
	_camera.fov = 40.0
	_camera.look_at_from_position(v[0], v[1], Vector3.UP)
	var screen: Image = await _screen()
	var h: int = screen.get_height()
	var cell: Image = screen.get_region(Rect2i((screen.get_width() - h) / 2, 0, h, h))
	cell.resize(cell_size, cell_size, Image.INTERPOLATE_LANCZOS)
	return cell


func _screen() -> Image:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		var blank: Image = Image.create(cell_size * 2, cell_size * 2, false, Image.FORMAT_RGBA8)
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
		label.position = Vector2(8, 4 + i * (FONT + 9))
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
		h += GAP + CAPTION + cell_size
	var out: Image = Image.create(_width(), h, false, Image.FORMAT_RGBA8)
	out.fill(BACKGROUND)
	out.blit_rect(head, Rect2i(Vector2i.ZERO, head.get_size()), Vector2i.ZERO)
	var y: int = head.get_height()
	for row: Array in rows:
		y += GAP
		var cap: Image = row[0]
		out.blit_rect(cap, Rect2i(Vector2i.ZERO, cap.get_size()), Vector2i(0, y))
		y += CAPTION
		var cells: Array[Image] = row[1]
		for i: int in cells.size():
			out.blit_rect(cells[i], Rect2i(Vector2i.ZERO, cells[i].get_size()), Vector2i(i * (cell_size + GAP), y))
		y += cell_size
	return out
