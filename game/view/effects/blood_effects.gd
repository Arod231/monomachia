class_name BloodEffects
extends Node3D
## Blood (milestone-1 task 38, the design's Violence section): a blade hit
## throws a burst of blood from where it landed, stains the defender's clothes
## there and the attacker's blade, and splatters the floor. The stains on
## bodies and blades last the whole match, through the round resets; the
## floor's splatter lasts until the round ends and fades in the next round's
## start. Fists draw none (spec P36).
##
## The Blood setting (GameSettings.blood) scales it: Reduced is less of
## everything (fewer, smaller drops, smaller and fewer stains and splatters,
## less on the blade), Off draws none and hides what a match had. Reduce
## flashes leaves blood alone, and every graphics preset keeps it (the Low
## preset included; the splatter's decals are not minor decals).
##
## Stains: a hit is noted in its fighter's own frame (the rules' place and
## facing), and at the next update, with the body posed for the frame shown,
## it is kept in the space of the bone nearest that spot, so it rides the
## body (the rules may run ahead of the drawing); every update hands the stains to the
## fighter's materials in world space (blood_stain.gdshaderinc, in the
## physically based surface, LookMaterials). The blade's blood is the
## Katana blade shader's blood_amount. The burst keeps the effect clock
## (CombatEffects.clock()), so it holds still in hit-stop like the sparks.
## Picture only: it reads rules events and never changes the rules.

## How much each level draws, per blade hit: the burst's drops (light,
## heavy) and their size (m across), a stain's radius (m, light and heavy)
## and the most stains a fighter keeps, a splatter's size (m across, light
## and heavy) and the most kept, and how much each hit adds to the blade (of
## the most, blade_max).
const PROFILES: Dictionary = {
	GameSettings.BLOOD_ON: {
		"burst": 20, "burst_heavy": 32, "drop_size": 0.045, "stain": 0.14, "stain_heavy": 0.19, "stains": 12,
		"splat": 0.5, "splat_heavy": 0.8, "splats": 24, "blade": 0.25, "blade_max": 1.0,
	},
	GameSettings.BLOOD_REDUCED: {
		"burst": 7, "burst_heavy": 11, "drop_size": 0.03, "stain": 0.08, "stain_heavy": 0.11, "stains": 6,
		"splat": 0.25, "splat_heavy": 0.4, "splats": 10, "blade": 0.12, "blade_max": 0.5,
	},
}
## The hit sounds that cut (AttackDef.HIT_SOUNDS less bare hands', BARE_SOUNDS).
const CUTTING: Array[StringName] = [&"blade", &"dagger", &"colossal"]
## How long the floor's splatter takes to fade at a round's start (frames).
const SPLAT_FADE_FRAMES: int = 45
## How far in from the hit a stain sits toward the attacker, onto the body's
## surface (the contact is near the defender's middle) (m).
const STAIN_OUT: float = 0.16
const BLOOD_COLOR := Color(0.32, 0.012, 0.02)
const DROP_CAPACITY: int = 400
const DROP_LIFE: float = 40.0
const DROP_SPEED: float = 3.0
const GRAVITY: float = 9.8
## The splatter's look: a few generated variations, made once a run.
const SPLAT_VARIATIONS: int = 4

## The level in use (GameSettings.BLOOD_LEVELS).
var setting: StringName = GameSettings.BLOOD_ON
## The host whose fighters' frames place new stains (MatchView sets it).
var host: MatchHost
## The fighters' views, by side (new_match()).
var fighters: Array = []
var droplets: MultiMeshInstance3D
var splats: Node3D

## side -> [{bone: int, offset: Vector3, radius: float}]
var _stains: Array = [[], []]
## Stains not yet on a bone: {side, local (in the fighter's frame), radius}
var _pending: Array[Dictionary] = []
var _blade: Array[float] = [0.0, 0.0]
## {p0, v, born, life, size}
var _drops: Array[Dictionary] = []
## Where each drawn drop is, as last updated (the MultiMesh's own instance
## transforms don't read back in a headless run).
var _drop_at: Array[Vector3] = []
## Decal -> {born, fade_from (or -1)}
var _splat_state: Dictionary = {}
var _hits: int = 0
var _now: float = 0.0
## model instance id -> its body materials
var _body_cache: Dictionary = {}
static var _splat_textures: Array[ImageTexture] = []
## shader instance id -> whether it takes blood_amount
static var _bloody_shaders: Dictionary = {}


func _init() -> void:
	name = &"Blood"
	droplets = MultiMeshInstance3D.new()
	droplets.name = &"Droplets"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.0
	drop.radial_segments = 6
	drop.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLOOD_COLOR
	mat.roughness = 0.25
	drop.material = mat
	mm.mesh = drop
	mm.instance_count = DROP_CAPACITY
	mm.visible_instance_count = 0
	droplets.multimesh = mm
	droplets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(droplets)
	splats = Node3D.new()
	splats.name = &"Splats"
	add_child(splats)


## What one rules event draws at [param level]: {} for none (an event that
## isn't a cutting hit, or Off), else "burst" (drops), "drop_size",
## "stain" (radius), "splat" (size) and "blade" (added to the blade).
static func plan(e: Dictionary, level: StringName) -> Dictionary:
	if e.get("t", &"") != &"hit" or not CUTTING.has(StringName(e.get("sound", &"blade"))):
		return {}
	if not PROFILES.has(level):
		return {}
	var p: Dictionary = PROFILES[level]
	var heavy: bool = e.get("heavy", false)
	return {
		"burst": int(p["burst_heavy"] if heavy else p["burst"]),
		"drop_size": float(p["drop_size"]),
		"stain": float(p["stain_heavy"] if heavy else p["stain"]),
		"splat": float(p["splat_heavy"] if heavy else p["splat"]),
		"blade": float(p["blade"]),
	}


## A new match: clean bodies, blades and floor.
func new_match(p_fighters: Array) -> void:
	fighters = p_fighters
	_stains = [[], []]
	_pending.clear()
	_blade = [0.0, 0.0]
	_drops.clear()
	_drop_at.clear()
	_body_cache.clear()
	for d: Node in splats.get_children():
		d.free()
	_splat_state.clear()
	_hits = 0


## A rules event at effect clock [param t].
func on_event(e: Dictionary, t: float) -> void:
	_now = t
	if e.get("t", &"") == &"roundStart":
		round_start(t)
		return
	var p := plan(e, setting)
	if p.is_empty() or fighters.size() < 2:
		return
	var attacker: int = int(e["attacker"])
	var target: int = int(e["target"])
	var at: Vector3 = _vector(e["pos"])
	var from: Vector3 = (fighters[attacker] as Node3D).global_position
	var away: Vector3 = Vector3(at.x - from.x, 0.0, at.z - from.z)
	away = away.normalized() if away.length() > 1e-4 else Vector3.FORWARD
	_hits += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _hits * 7919 + target
	_burst(at, away, int(p["burst"]), float(p["drop_size"]), t, rng)
	_pending.append({"side": target, "local": _frame_of(target).affine_inverse() * (at - away * STAIN_OUT), "radius": float(p["stain"])})
	_splat(at + away * 0.25, float(p["splat"]), t, rng)
	var most: float = float(PROFILES[setting]["blade_max"])
	_blade[attacker] = minf(most, _blade[attacker] + float(p["blade"]))


## A round starts: the floor's splatter fades; stains and blades stay.
func round_start(t: float) -> void:
	for d: Node in splats.get_children():
		if float(_splat_state[d]["fade_from"]) < 0.0:
			_splat_state[d]["fade_from"] = t


## Draws everything at effect clock [param t] (call it after the fighters
## are posed).
func update(t: float) -> void:
	_now = t
	var off: bool = setting == GameSettings.BLOOD_OFF
	droplets.visible = not off
	splats.visible = not off
	_update_drops(t)
	_update_splats(t)
	for s: Dictionary in _pending:
		_stain(int(s["side"]), _frame_of(int(s["side"])) * (s["local"] as Vector3), float(s["radius"]))
	_pending.clear()
	for side: int in mini(2, fighters.size()):
		var view: FighterView = fighters[side]
		if view == null or view.model == null:
			continue
		var points := PackedVector4Array()
		if not off:
			for s: Dictionary in _stains[side]:
				var w: Vector3 = _stain_point(view, s)
				points.append(Vector4(w.x, w.y, w.z, float(s["radius"])))
		var count: int = points.size()
		points.resize(12)
		for m: ShaderMaterial in _body_materials_of(view):
			m.set_shader_parameter(&"blood_stains", points)
			m.set_shader_parameter(&"blood_stain_count", count)
		for m: ShaderMaterial in blade_materials(view):
			m.set_shader_parameter(&"blood_amount", 0.0 if off else _blade[side])


# ------------------------------------------------------------------ for tests and tools

func droplet_count() -> int:
	return droplets.multimesh.visible_instance_count if droplets.visible else 0


func droplet_positions() -> Array[Vector3]:
	return _drop_at.duplicate()


func stain_count(side: int) -> int:
	return 0 if setting == GameSettings.BLOOD_OFF else (_stains[side] as Array).size()


## Fighter [param side]'s own frame: its place and facing in the rules
## (host), or its view's where there is no host.
func _frame_of(side: int) -> Transform3D:
	if host != null and host.is_started() and host.world != null:
		var f: Fighter = host.world.fighters[side]
		return Transform3D(Basis(Vector3.UP, f.yaw), Vector3(f.pos.x, f.pos.y, f.pos.z))
	return (fighters[side] as Node3D).global_transform


func stain_world(side: int, i: int) -> Vector3:
	return _stain_point(fighters[side], _stains[side][i])


func blade_amount(side: int) -> float:
	return 0.0 if setting == GameSettings.BLOOD_OFF else _blade[side]


func splat_count() -> int:
	return 0 if setting == GameSettings.BLOOD_OFF else splats.get_child_count()


func splat_size(i: int) -> float:
	return (splats.get_child(i) as Decal).size.x


func splat_alpha(i: int) -> float:
	return (splats.get_child(i) as Decal).modulate.a


## The materials a fighter's body draws with that take blood stains: every
## surface under its skeleton, not its weapons'.
static func body_materials(view: FighterView) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if view == null or view.model == null:
		return out
	for node: Node in view.model.skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if view.model.weapon_root != null and view.model.weapon_root.is_ancestor_of(mi):
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m is ShaderMaterial and LookMaterials.is_surface_shader((m as ShaderMaterial).shader):
				out.append(m)
	return out


## The blade materials of the weapon a fighter holds (the Katana's).
static func blade_materials(view: FighterView) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if view == null or view.model == null:
		return out
	for w: Node3D in view.model.weapons:
		for node: Node in w.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			for s: int in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null and _takes_blood(m as ShaderMaterial):
					out.append(m)
	return out


## Whether a material's shader has a blood_amount (the Katana blade's), asked
## of each shader once a run.
static func _takes_blood(m: ShaderMaterial) -> bool:
	var key: int = m.shader.get_instance_id()
	if not _bloody_shaders.has(key):
		_bloody_shaders[key] = m.shader.get_shader_uniform_list().any(
			func(u: Dictionary) -> bool: return u[&"name"] == &"blood_amount")
	return _bloody_shaders[key]


# ------------------------------------------------------------------ inside

func _body_materials_of(view: FighterView) -> Array[ShaderMaterial]:
	var key: int = view.model.get_instance_id()
	if not _body_cache.has(key):
		_body_cache[key] = body_materials(view)
	return _body_cache[key]


func _burst(at: Vector3, away: Vector3, count: int, size: float, t: float, rng: RandomNumberGenerator) -> void:
	for k: int in count:
		var dir: Vector3 = (away + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.1, 0.9), rng.randf_range(-0.7, 0.7))).normalized()
		_drops.append({
			"p0": at, "v": dir * DROP_SPEED * rng.randf_range(0.5, 1.3), "born": t,
			"life": DROP_LIFE * rng.randf_range(0.6, 1.0), "size": size * rng.randf_range(0.5, 1.2),
		})
	while _drops.size() > DROP_CAPACITY:
		_drops.pop_front()


func _update_drops(t: float) -> void:
	var alive: Array[Dictionary] = []
	for d: Dictionary in _drops:
		if t - float(d["born"]) < float(d["life"]):
			alive.append(d)
	_drops = alive
	var mm: MultiMesh = droplets.multimesh
	mm.visible_instance_count = _drops.size()
	_drop_at.resize(_drops.size())
	for i: int in _drops.size():
		var d: Dictionary = _drops[i]
		var s: float = maxf(0.0, t - float(d["born"])) / 60.0
		var p: Vector3 = d["p0"] + (d["v"] as Vector3) * s + Vector3(0.0, -0.5 * GRAVITY * s * s, 0.0)
		p.y = maxf(p.y, 0.01)
		_drop_at[i] = p
		var size: float = d["size"]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), p))


func _stain(side: int, at: Vector3, radius: float) -> void:
	var view: FighterView = fighters[side]
	if view == null or view.model == null:
		return
	var skel: Skeleton3D = view.model.skeleton
	var best: int = -1
	var best_d: float = INF
	for b: int in skel.get_bone_count():
		var d: float = (skel.global_transform * skel.get_bone_global_pose(b)).origin.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = b
	if best < 0:
		return
	var bone_xf: Transform3D = skel.global_transform * skel.get_bone_global_pose(best)
	var list: Array = _stains[side]
	list.append({"bone": best, "offset": bone_xf.affine_inverse() * at, "radius": radius})
	var most: int = int(PROFILES[setting]["stains"])
	while list.size() > most:
		list.pop_front()


func _stain_point(view: FighterView, s: Dictionary) -> Vector3:
	var skel: Skeleton3D = view.model.skeleton
	return (skel.global_transform * skel.get_bone_global_pose(int(s["bone"]))) * (s["offset"] as Vector3)


func _splat(at: Vector3, size: float, t: float, rng: RandomNumberGenerator) -> void:
	var d := Decal.new()
	d.texture_albedo = _splat_texture(rng.randi_range(0, SPLAT_VARIATIONS - 1))
	d.size = Vector3(size, 0.6, size)
	d.position = Vector3(at.x, 0.1, at.z)
	d.rotation.y = rng.randf_range(0.0, TAU)
	d.albedo_mix = 1.0
	d.upper_fade = 0.05
	d.lower_fade = 0.05
	# the floor only: never the fighters standing on it
	d.cull_mask = 0xFFFFF & ~FighterModel.LAYERS
	splats.add_child(d)
	_splat_state[d] = {"born": t, "fade_from": -1.0}
	var most: int = int(PROFILES[setting]["splats"])
	while splats.get_child_count() > most:
		var old: Node = splats.get_child(0)
		_splat_state.erase(old)
		old.free()


func _update_splats(t: float) -> void:
	for d: Node in splats.get_children():
		var fade_from: float = float(_splat_state[d]["fade_from"])
		if fade_from < 0.0:
			continue
		var gone: float = (t - fade_from) / float(SPLAT_FADE_FRAMES)
		if gone >= 1.0:
			_splat_state.erase(d)
			d.free()
		else:
			(d as Decal).modulate.a = clampf(1.0 - gone, 0.0, 1.0)


## A splatter: a ragged pool with drops thrown round it, dark blood that is
## lighter where thin, made once a run from a fixed seed.
static func _splat_texture(i: int) -> ImageTexture:
	if _splat_textures.is_empty():
		for v: int in SPLAT_VARIATIONS:
			_splat_textures.append(_make_splat(v))
	return _splat_textures[i % _splat_textures.size()]


static func _make_splat(variation: int) -> ImageTexture:
	const N := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 5381 + variation
	var blobs: Array[Vector3] = []
	for k: int in 9:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.0, 0.18)
		blobs.append(Vector3(0.5 + cos(a) * r, 0.5 + sin(a) * r, rng.randf_range(0.08, 0.16)))
	for k: int in 14:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.25, 0.46)
		blobs.append(Vector3(0.5 + cos(a) * r, 0.5 + sin(a) * r, rng.randf_range(0.01, 0.03)))
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y: int in N:
		for x: int in N:
			var p := Vector2((x + 0.5) / N, (y + 0.5) / N)
			var cover: float = 0.0
			for b: Vector3 in blobs:
				cover = maxf(cover, clampf((b.z - p.distance_to(Vector2(b.x, b.y))) / 0.012 + 0.5, 0.0, 1.0))
			var thin: float = clampf(p.distance_to(Vector2(0.5, 0.5)) * 2.0, 0.0, 1.0)
			var c: Color = BLOOD_COLOR.lerp(Color(0.42, 0.04, 0.04), thin * 0.6)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, cover * 0.92))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _vector(d: Variant) -> Vector3:
	if d is Vector3:
		return d
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
