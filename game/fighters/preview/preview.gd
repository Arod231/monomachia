extends Node3D
## A stage for looking at the fighters and weapons, and for screenshotting
## them. Run it from the editor, or through the screenshot command:
##
##   node scripts/godot.mjs shots res://fighters/preview/preview.tscn <out.png> [frames] [--option=value...]
##
## Modes (--mode=):
## - lineup (default): both fighters idle with their signature weapons, and
##   the three weapons standing beside them with their markers;
## - turntable: the lineup, slowly turning;
## - fighter: one fighter, chosen with --fighter=rogue|hunter, --palette=0|1,
##   --weapon=katana|greatsword|daggers|none (default: signature),
##   --view=front|three_quarter|side|back|head|head_back|right_hand|left_hand
##   (hands also with _below or _side) and --range=close|gameplay;
## - weapons: the weapons upright on a 10 cm grid, with their markers;
## - mirror: a mirror match of --fighter=, palette A against B, side on, or
##   with --shoulder=0|1 from the gameplay camera over that side's shoulder;
## - sheet: renders the whole review set into contact sheets in the folder
##   given by --sheet=<folder>: both fighters in both palettes from the front,
##   three-quarters, side and back, close and at gameplay distance; head
##   close-ups; hands on the grips from three angles; every weapon posed in
##   a guard on the rig, with the hands from the sides and below; rest
##   poses; every fighter with every weapon; mirror matches side on and from
##   the gameplay camera; the weapons and close-ups of their blades.
##
## With --pose=carry (the default) a fighter carries each weapon the way its
## look's WeaponHold says, frozen in the hold's idle clip. With --pose=guard
## the weapon is posed in a guard (GUARDS) and the arms reach for it on the
## rig's IK, over the relaxed idle clip; the sheet's guard section uses it.
##
## Stages (--stage=): studio (default), a neutral grey room for judging the
## art; or night, the match's look: the stand-in arena's night environment,
## moon, fighter rim light, lanterns and ink-wash pass. --preset=low|medium|
## high applies that graphics preset to the whole stage (the chosen one
## otherwise).
##
## Markers: green is BladeBase, red BladeTip, blue OffHandGrip, yellow the
## weapon origin (the main hand's grip).

enum Mode { LINEUP, TURNTABLE, FIGHTER, WEAPONS, MIRROR, SHEET }

const VIEWS: Dictionary[StringName, float] = {
	&"front": 0.0, &"three_quarter": -38.0, &"side": -90.0, &"back": 180.0,
}
const MARKER_COLORS: Dictionary[StringName, Color] = {
	&"BladeBase": Color(0.2, 0.9, 0.3), &"BladeTip": Color(0.95, 0.2, 0.15), &"OffHandGrip": Color(0.25, 0.45, 1.0),
}
## Frames to let a new setup settle before a capture.
const SETTLE_FRAMES: int = 6
## Where the idle clips are frozen for screenshots, so every run matches.
const POSE_TIME: float = 0.5
## Guards for reviewing the grip on the rig (--pose=guard), in the fighter's
## frame (+Z forward, +X to the fighter's left): per held weapon, its main
## grip point, the way its blade points and the way its edge faces (see
## FighterRig.weapon_frame()). Review poses only, with both elbows bent: the
## guard stances (plan 14.7, 15) bring the real ones.
## (the grips' places grown by 1.15 with KE task 3's taller bodies, as the
## framing of every view is)
const GUARDS: Dictionary[StringName, Array] = {
	&"katana": [[Vector3(-0.069, 1.242, 0.311), Vector3(0.12, 0.5, 0.86), Vector3(0.0, -1.0, 0.0)]],
	&"greatsword": [[Vector3(-0.058, 1.323, 0.345), Vector3(0.05, 0.55, 0.83), Vector3(0.0, 0.0, 1.0)]],
	&"daggers": [
		[Vector3(-0.207, 1.288, 0.322), Vector3(-0.05, 0.34, 0.94), Vector3(0.0, -1.0, 0.0)],
		[Vector3(0.207, 1.334, 0.299), Vector3(0.05, 0.34, 0.94), Vector3(0.0, -1.0, 0.0)],
	],
}
## The clip under a guard: the relaxed idle, with the shoulders square.
const GUARD_CLIP: StringName = &"Idle"

@export var mode: Mode = Mode.LINEUP
@export var fighter_id: StringName = &"rogue"
@export_range(0, 1) var palette: int = 0
## Empty for the fighter's signature weapon; "none" for bare hands.
@export var weapon_id: StringName = &""
@export var view: StringName = &"front"
@export var gameplay_range: bool = false
## Mirror mode: -1 side on, or the side whose shoulder the camera looks over.
@export_range(-1, 1) var shoulder: int = -1
## Turntable speed in radians per second.
@export var turntable_speed: float = 0.6
## studio or night (see above).
@export var stage: StringName = &"studio"
## A graphics preset id to apply to the stage, or empty for the chosen one.
@export var preset_id: StringName = &""
## carry or guard (see above).
@export var pose: StringName = &"carry"

var _camera: Camera3D
var _label: Label
var _actors: Node3D
var _sheet_dir: String = ""
var _done: bool = false


func _ready() -> void:
	_read_args()
	_build_stage()
	_actors = Node3D.new()
	_actors.name = &"Actors"
	add_child(_actors)
	match mode:
		Mode.LINEUP, Mode.TURNTABLE:
			_setup_lineup()
		Mode.FIGHTER:
			_setup_fighter(fighter_id, palette, weapon_id, view, gameplay_range)
		Mode.WEAPONS:
			_setup_weapons()
		Mode.MIRROR:
			_setup_mirror(fighter_id, shoulder)
		Mode.SHEET:
			_setup_lineup()
			_run_sheet.call_deferred()
	if mode != Mode.SHEET:
		_apply_preset()
		_done = true


func _process(delta: float) -> void:
	if mode == Mode.TURNTABLE:
		for child: Node in _actors.get_children():
			if child is FighterModel:
				(child as FighterModel).rotate_y(turntable_speed * delta)


## For tools/shot.gd: frames to wait before asking shot_ready().
func shot_frames() -> int:
	return 1 if mode == Mode.SHEET else 20


## For tools/shot.gd: true once the scene has finished posing itself.
func shot_ready() -> bool:
	return _done


func _read_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--") or not a.contains("="):
			continue
		var key: String = a.substr(2, a.find("=") - 2)
		var value: String = a.substr(a.find("=") + 1)
		match key:
			"mode":
				mode = Mode.get(value.to_upper(), mode) as Mode
			"fighter":
				fighter_id = StringName(value)
			"palette":
				palette = int(value)
			"weapon":
				weapon_id = StringName(value)
			"view":
				view = StringName(value)
			"range":
				gameplay_range = value == "gameplay"
			"sheet":
				_sheet_dir = value
			"shoulder":
				shoulder = clampi(int(value), -1, 1)
			"stage":
				stage = StringName(value)
			"preset":
				preset_id = StringName(value)
			"pose":
				pose = StringName(value)
				if pose != &"carry" and pose != &"guard":
					push_error("preview.gd: --pose must be carry or guard, not '%s'" % value)


# --- stage -------------------------------------------------------------------

func _build_stage() -> void:
	if stage == &"night":
		_build_night_stage()
	elif stage != &"studio":
		push_error("preview.gd: --stage must be studio or night, not '%s'" % stage)
	else:
		build_studio_stage(self)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	# Bottom centre, so it survives the portrait crops of the contact sheets.
	_label = Label.new()
	_label.position = Vector2(505.0, 790.0)
	_label.size = Vector2(590.0, 100.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)


## The stand-in arena, turned round so its moon lights the fighters' fronts
## (they face the preview's cameras, along +Z).
func _build_night_stage() -> void:
	var arena: Node3D = ArenaScenes.instantiate(ArenaScenes.STANDIN)
	arena.rotation.y = PI
	add_child(arena)


## The graphics preset --preset= names, or the chosen one, applied to the
## whole stage (the renderer, the viewport and every node).
func _apply_preset() -> void:
	var preset: GraphicsPreset = GameServices.graphics_preset()
	if preset_id != &"":
		preset = GraphicsPreset.load_id(preset_id)
		if preset == null:
			push_error("preview.gd: --preset must be low, medium, high or ultra, not '%s'" % preset_id)
			return
	GraphicsApplier.apply(preset, self, get_viewport())


## The neutral grey studio for judging the art: lights, a floor and a 1 m
## grid, added under `parent` (the move sheets use it too).
static func build_studio_stage(parent: Node) -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.32, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	parent.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 160.0, 0.0)
	fill.light_energy = 0.7
	fill.light_color = Color(0.75, 0.82, 1.0)
	parent.add_child(fill)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.4, 0.4, 0.41)
	floor_mat.roughness = 0.95
	floor_mesh.material_override = floor_mat
	parent.add_child(floor_mesh)
	var grid: PackedVector3Array = PackedVector3Array()
	for i: int in range(-10, 11):
		grid.append_array([Vector3(i, 0.002, -10), Vector3(i, 0.002, 10), Vector3(-10, 0.002, i), Vector3(10, 0.002, i)])
	parent.add_child(_lines(grid, Color(0.3, 0.3, 0.31)))


func _look_from(pos: Vector3, target: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.position = pos
	_camera.look_at(target, Vector3.UP)


## Unshaded line segments (pairs of points).
static func _lines(points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for p: Vector3 in points:
		mesh.surface_add_vertex(p)
	mesh.surface_end()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _dot(color: Color, radius: float) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	sphere.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = sphere
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- setups ------------------------------------------------------------------

func _clear() -> void:
	for child: Node in _actors.get_children():
		_actors.remove_child(child)
		child.free()


## Adds a fighter holding a weapon ("" = signature, "none" = bare hands),
## frozen at POSE_TIME of its idle clip, carrying the weapon or, with
## --pose=guard, posed in its guard.
func _add_fighter(id: StringName, pal: int, weapon: StringName, pos: Vector3, rest_pose: bool = false) -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(id)
	f.autoplay_idle = false
	f.palette = pal
	f.position = pos
	_actors.add_child(f)
	var wid: StringName = f.look.signature_weapon if weapon == &"" else weapon
	var guard: bool = pose == &"guard" and GUARDS.has(wid) and not rest_pose
	if wid != &"none":
		f.attach_weapon(WeaponLook.load_id(wid))
		if guard:
			for i: int in f.weapons.size():
				var g: Array = GUARDS[wid][i]
				f.pose_weapon(i, FighterRig.weapon_frame(g[0], g[1], g[2]))
	if rest_pose:
		f.skeleton.reset_bone_poses()
	else:
		if guard:
			f.play(GUARD_CLIP, 0.0)
		else:
			f.play_idle(0.0)
		f.animation_player.seek(POSE_TIME, true)
		f.animation_player.pause()
	return f


## Stands a weapon upright with its origin at `pos`, with its markers shown.
func _add_weapon_display(look: WeaponLook, pos: Vector3) -> Node3D:
	var w: Node3D = look.instantiate()
	w.position = pos
	_actors.add_child(w)
	_show_markers(w)
	var label: Label3D = Label3D.new()
	var tip: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_TIP).position
	label.text = "%s\n%.2f m" % [look.display_name, _length(w)]
	label.font_size = 40
	label.pixel_size = 0.0015
	label.position = Vector3(0.0, tip.y + 0.08, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	w.add_child(label)
	return w


func _show_markers(w: Node3D) -> void:
	var origin_dot: MeshInstance3D = _dot(Color(1.0, 0.85, 0.1), 0.014)
	w.add_child(origin_dot)
	w.add_child(_lines(PackedVector3Array([Vector3.ZERO, Vector3(0.08, 0, 0), Vector3.ZERO, Vector3(0, 0, 0.08)]), Color(1.0, 0.85, 0.1)))
	for marker_name: StringName in MARKER_COLORS:
		var m: Marker3D = WeaponLook.marker(w, marker_name)
		if m != null:
			m.add_child(_dot(MARKER_COLORS[marker_name], 0.014))


## Overall length along the blade axis, from the meshes' bounds.
static func _length(w: Node3D) -> float:
	var lo: float = INF
	var hi: float = -INF
	for node: Node in w.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh is ImmediateMesh or mi.mesh is SphereMesh:
			continue
		var xf: Transform3D = _transform_in(mi, w)
		var box: AABB = xf * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	return hi - lo


## A bone's posed position in world space.
static func _bone_position(f: FighterModel, bone: StringName) -> Vector3:
	var sk: Skeleton3D = f.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


static func _transform_in(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf: Transform3D = node.transform
	var p: Node = node.get_parent()
	while p != null and p != ancestor:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _setup_lineup() -> void:
	_clear()
	_add_fighter(&"rogue", 0, &"", Vector3(-0.85, 0, 0))
	_add_fighter(&"hunter", 0, &"", Vector3(0.85, 0, 0))
	var x: float = 2.1
	for id: StringName in WeaponLook.IDS:
		_add_weapon_display(WeaponLook.load_id(id), Vector3(x, 0.4, 0.2))
		x += 0.45
	_look_from(Vector3(0.7, 1.73, 6.2), Vector3(0.7, 1.09, 0.0), 42.0)
	_label.text = "Rogue and Hunter with their signature weapons (palette A); Katana, Greatsword, Dagger"


## Views of one fighter: VIEWS turn the camera round the fighter; "head"
## and "head_back" are close-ups of the head; "<side>_hand", with
## "_below" or "_side" appended for those angles, are close-ups of a hand on
## its weapon.
func _setup_fighter(id: StringName, pal: int, weapon: StringName, view_name: StringName, gameplay: bool, rest_pose: bool = false) -> void:
	_clear()
	var f: FighterModel = _add_fighter(id, pal, weapon, Vector3.ZERO, rest_pose)
	var yaw: float = deg_to_rad(VIEWS.get(view_name, 0.0))
	var dir: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var head: Vector3 = _bone_position(f, &"Head") + Vector3(0.0, 0.08, 0.0)
	var name_text: String = String(view_name).replace("_", " ")
	if view_name == &"head":
		_look_from(head + Vector3(-0.3, 0.06, 0.8), head, 30.0)
	elif view_name == &"head_back":
		_look_from(head + Vector3(0.55, 0.12, -0.65), head, 30.0)
	elif String(view_name).contains("_hand"):
		_look_at_hand(f, view_name)
	elif gameplay:
		_look_from(dir * 5.75 + Vector3(0, 2.19, 0), Vector3(0, 1.15, 0), 55.0)
	else:
		_look_from(dir * 3.1 + Vector3(0, 1.32, 0), Vector3(0, 1.09, 0), 40.0)
	var weapon_name: String = f.weapon_look.display_name if f.weapon_look != null else "bare hands"
	if f.rig.drives("Right"):
		weapon_name += " in guard"
	_label.text = "%s, palette %s (%s), %s, %s%s" % [
		f.look.display_name, "AB"[pal], f.look.palettes[pal].display_name, weapon_name,
		name_text, ", rest pose" if rest_pose else (", 5 m" if gameplay else "")]


## A close-up of a hand on its weapon: from the front and outside (the
## default), from below, or from the fighter's side.
func _look_at_hand(f: FighterModel, view_name: StringName) -> void:
	var right: bool = String(view_name).begins_with("right")
	var side: String = "Right" if right else "Left"
	var sk: Skeleton3D = f.skeleton
	# Where the fist is: on its posed weapon's grip, or in the clip's hand.
	var grip: Vector3 = f.rig.grip_point(side) if f.rig.drives(side) \
		else sk.get_bone_global_pose(sk.find_bone(side + "Hand")) * f.rig.fist(side).origin
	var hand: Vector3 = sk.global_transform * grip
	var out: float = -1.0 if right else 1.0
	var offset: Vector3 = Vector3(out * 0.35, 0.2, 0.55)
	if String(view_name).ends_with("_below"):
		offset = Vector3(out * 0.3, -0.45, 0.4)
	elif String(view_name).ends_with("_side"):
		offset = Vector3(out * 0.6, 0.12, 0.28)
	_look_from(hand + offset, hand, 32.0)


func _setup_weapons() -> void:
	_clear()
	var x: float = -0.5
	for id: StringName in WeaponLook.IDS:
		_add_weapon_display(WeaponLook.load_id(id), Vector3(x, 0.4, 0.0))
		x += 0.5
	# A 10 cm grid behind the weapons to read their sizes.
	var grid: PackedVector3Array = PackedVector3Array()
	for i: int in 21:
		grid.append_array([Vector3(-1.0, i * 0.1, -0.15), Vector3(1.0, i * 0.1, -0.15)])
	for i: int in 21:
		grid.append_array([Vector3(-1.0 + i * 0.1, 0.0, -0.15), Vector3(-1.0 + i * 0.1, 2.0, -0.15)])
	_actors.add_child(_lines(grid, Color(0.42, 0.44, 0.47)))
	_look_from(Vector3(0.0, 1.05, 2.75), Vector3(0.0, 1.0, 0.0), 42.0)
	_label.text = "Weapons: green BladeBase, red BladeTip, blue OffHandGrip, yellow origin (main grip)"


## Close-ups of the blades: the katana's point and its curve, the dagger and
## the greatsword's edge, flat on and edge on.
func _setup_weapon_detail(id: StringName, part: StringName, edge_on: bool) -> void:
	_clear()
	var look: WeaponLook = WeaponLook.load_id(id)
	var w: Node3D = look.instantiate()
	w.position = Vector3(0.0, 0.3, 0.0)
	if edge_on:
		w.rotation.y = deg_to_rad(80.0)
	_actors.add_child(w)
	var tip: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_TIP).global_position
	var base: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_BASE).global_position
	if part == &"tip":
		_look_from(tip + Vector3(0.0, -0.045, 0.2), tip + Vector3(0.0, -0.045, 0.0), 30.0)
	else:
		var mid: Vector3 = (tip + base) * 0.5
		var span: float = tip.distance_to(base)
		_look_from(mid + Vector3(0.0, 0.0, span * 1.25 + 0.15), mid, 40.0)
	_label.text = "%s, %s, %s" % [look.display_name, "point" if part == &"tip" else "blade", "edge on" if edge_on else "flat"]


## Two fighters of the same kind, palette A against palette B, 2.6 m apart,
## seen side on from 5 m, or over the shoulder of one of them from the
## gameplay camera (the spec's: 4.6 m back, 2.2 m up, 0.9 m to the right,
## 60 degrees, looking at the other).
func _setup_mirror(id: StringName, shoulder_of: int) -> void:
	_clear()
	var a: FighterModel = _add_fighter(id, 0, &"", Vector3(0, 0, -1.3))
	var b: FighterModel = _add_fighter(id, 1, &"", Vector3(0, 0, 1.3))
	b.rotation.y = PI
	var who: String = String(id).capitalize()
	if shoulder_of < 0:
		a.rotation.y = deg_to_rad(20.0)
		b.rotation.y = PI + deg_to_rad(20.0)
		_look_from(Vector3(6.0, 2.3, 0.0), Vector3(0, 1.15, 0), 55.0)
		_label.text = "%s mirror match: palette A (right) against palette B (left), side on at 6 m" % who
		return
	var me: FighterModel = a if shoulder_of == 0 else b
	var fwd: Vector3 = Vector3(0, 0, 1) if shoulder_of == 0 else Vector3(0, 0, -1)
	var right: Vector3 = Vector3.UP.cross(fwd)
	_look_from(me.position - fwd * 5.3 - right * 0.9 + Vector3(0, 2.53, 0), me.position + fwd * 1.6 + Vector3(0, 1.15, 0), 60.0)
	_label.text = "%s mirror match from the gameplay camera, over palette %s's shoulder" % [who, "AB"[shoulder_of]]


# --- sheet -------------------------------------------------------------------

func _capture() -> Image:
	_apply_preset()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _run_sheet() -> void:
	var dir: String = _sheet_dir if _sheet_dir != "" else ProjectSettings.globalize_path("user://preview_sheet")
	DirAccess.make_dir_recursive_absolute(dir)
	var portrait: Rect2i = Rect2i(500, 0, 600, 900)
	var wide: Rect2i = Rect2i(0, 0, 1600, 900)
	var square: Rect2i = Rect2i(350, 0, 900, 900)
	# Each fighter: palettes A and B from the front, three-quarters, the side
	# and behind, close and at 5 m.
	for id: StringName in FighterLook.IDS:
		for gameplay: bool in [false, true]:
			var cells: Array[Image] = []
			for pal: int in 2:
				for v: StringName in [&"front", &"three_quarter", &"side", &"back"]:
					_setup_fighter(id, pal, &"", v, gameplay)
					cells.append(await _capture())
			_save_sheet(cells, portrait, 4, 0.7, dir.path_join("%s_%s.png" % [id, "gameplay_5m" if gameplay else "close"]))
	# Heads close up, for the headwear and the faces, and for clipping at the
	# hood, hat, hair and neck.
	var heads: Array[Image] = []
	for id: StringName in FighterLook.IDS:
		for pal: int in 2:
			for v: StringName in [&"head", &"head_back"]:
				_setup_fighter(id, pal, &"none", v, false)
				heads.append(await _capture())
	_save_sheet(heads, square, 4, 0.5, dir.path_join("heads_close.png"))
	# Hands on the grips: the right hand on each weapon, and both daggers
	# from the front, from below and from the side, where a bad seat shows.
	var hands: Array[Image] = []
	for id: StringName in FighterLook.IDS:
		for w: StringName in [&"katana", &"greatsword"]:
			_setup_fighter(id, 0, w, &"right_hand", false)
			hands.append(await _capture())
		for v: StringName in [&"right_hand", &"right_hand_below", &"right_hand_side", &"left_hand", &"left_hand_below", &"left_hand_side"]:
			_setup_fighter(id, 0, &"daggers", v, false)
			hands.append(await _capture())
	_save_sheet(hands, square, 4, 0.5, dir.path_join("hands_close.png"))
	# The rig: every weapon posed in a guard with the arms on IK, and the
	# hands on the katana and the greatsword from the sides and below, where
	# a loose fist or a palm off the handle shows.
	var carry: StringName = pose
	pose = &"guard"
	for id: StringName in FighterLook.IDS:
		var guard: Array[Image] = []
		for v: StringName in [&"front", &"three_quarter", &"side"]:
			for w: StringName in WeaponLook.IDS:
				_setup_fighter(id, 0, w, v, false)
				guard.append(await _capture())
		_save_sheet(guard, portrait, 3, 0.7, dir.path_join("%s_guard.png" % id))
		var grips: Array[Image] = []
		for w: StringName in [&"katana", &"greatsword"]:
			for v: StringName in [&"right_hand_side", &"left_hand_side", &"right_hand_below", &"left_hand_below"]:
				_setup_fighter(id, 0, w, v, false)
				grips.append(await _capture())
		_save_sheet(grips, square, 4, 0.5, dir.path_join("%s_guard_hands.png" % id))
	pose = carry
	# Rest pose, front and side.
	var rest: Array[Image] = []
	for id: StringName in FighterLook.IDS:
		for v: StringName in [&"front", &"side"]:
			_setup_fighter(id, 0, &"", v, false, true)
			rest.append(await _capture())
	_save_sheet(rest, Rect2i(300, 0, 1000, 900), 4, 0.5, dir.path_join("rest_pose.png"))
	# Every fighter with every weapon, as it holds it when idle.
	for id: StringName in FighterLook.IDS:
		var held: Array[Image] = []
		for v: StringName in [&"front", &"three_quarter", &"side"]:
			for w: StringName in WeaponLook.IDS:
				_setup_fighter(id, 0, w, v, false)
				held.append(await _capture())
		_save_sheet(held, portrait, 3, 0.7, dir.path_join("%s_weapons.png" % id))
	# Mirror matches: side on at 5 m, and from the gameplay camera over each
	# fighter's shoulder (one's back against the other's front).
	for id: StringName in FighterLook.IDS:
		_setup_mirror(id, -1)
		_save_sheet([await _capture()], wide, 1, 1.0, dir.path_join("%s_mirror.png" % id))
		var over: Array[Image] = []
		for who: int in 2:
			_setup_mirror(id, who)
			over.append(await _capture())
		_save_sheet(over, wide, 2, 0.5, dir.path_join("%s_mirror_gameplay.png" % id))
	# The weapons, and close-ups of their blades.
	_setup_weapons()
	_save_sheet([await _capture()], wide, 1, 1.0, dir.path_join("weapons_lineup.png"))
	var detail: Array[Image] = []
	for spec: Array in [[&"katana", &"tip", false], [&"katana", &"tip", true], [&"katana", &"blade", false],
			[&"daggers", &"blade", false], [&"daggers", &"blade", true], [&"greatsword", &"blade", true]]:
		_setup_weapon_detail(spec[0], spec[1], spec[2])
		detail.append(await _capture())
	_save_sheet(detail, square, 3, 0.5, dir.path_join("weapons_detail.png"))
	_setup_lineup()
	_save_sheet([await _capture()], wide, 1, 1.0, dir.path_join("lineup.png"))
	print("preview: sheets saved in %s" % dir)
	_done = true


## Crops each image, scales it and lays the cells out in rows of `cols`.
static func _save_sheet(images: Array[Image], crop: Rect2i, cols: int, scale: float, path: String) -> void:
	var cw: int = int(crop.size.x * scale)
	var ch: int = int(crop.size.y * scale)
	var rows: int = ceili(images.size() / float(cols))
	var out: Image = Image.create(cw * mini(cols, images.size()), ch * rows, false, Image.FORMAT_RGBA8)
	for i: int in images.size():
		var cell: Image = images[i].get_region(crop)
		cell.convert(Image.FORMAT_RGBA8)
		cell.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i((i % cols) * cw, (i / cols) * ch))
	var err: Error = out.save_png(path)
	if err != OK:
		printerr("preview: cannot save %s (%s)" % [path, error_string(err)])
