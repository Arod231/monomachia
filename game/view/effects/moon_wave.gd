class_name MoonWave
extends Node3D
## Moonsplitter's wave on screen (milestone-1 task 100, the owner's choices
## of Oct 7; design.md's mood board): each wave the rules hold
## (World.waves) is a curved crescent of moonlight standing where the rules
## put it on every drawn frame, drawn with shaders/moon_wave.gdshader (cold
## silver-white at its heart, a wisteria-violet fringe, bending the scene
## behind it), with a light travelling with it that lights the floor and the
## fighters, and shedding mist and petals behind it (shed(), on the
## effects' clock).
##
## - The vertical wave stands tall in its lane (the rules hit within 0.95 m
##   either side of its line), bowed forward and its crest curling over.
## - The horizontal wave is a low sheet at knee height spanning the whole
##   arena from wherever it flies, since the rules hit it anywhere sideways,
##   bowed forward in the middle like a crescent seen from above.
##
## It fades in over its first metres and out over the last of its range
## (fade()). Reduce flashes halves its light (light_scale), as the contact
## lights'. MatchView owns it and syncs it every drawn frame (sync()); the
## floor cracks along its path are task 115's.

const SILVER: Color = Color(0.9, 0.94, 1.0)
const WISTERIA: Color = Color(0.66, 0.52, 0.92)
const SHADER: Shader = preload("res://shaders/moon_wave.gdshader")
## The vertical wave: a crescent seen from ahead, its tips TIP_X across
## and its back and front arcs bulging INNER and OUTER from them (inside the
## rules' 0.95 m lane either side), its height, how far its middle bows
## ahead and its crest curls over.
const TIP_X: float = -0.55
const INNER: float = 0.35
const OUTER: float = 1.15
const TALL: float = 2.8
const BOW: float = 0.5
const CURL: float = 0.45
## The horizontal wave: its half-span (twice the arena's radius, so it spans
## the arena from anywhere a wave can start), its band (from knee to shin),
## how far its middle bows ahead and its top leans over.
const SPAN: float = 2.0 * SimConst.ARENA_RADIUS + 1.0
const KNEE: float = 0.5
const BAND: float = 0.32
const SPAN_BOW: float = 3.0
const LEAN: float = 0.18
## The travelling light: its energy at full, its reach, and its height.
const LIGHT_ENERGY: float = 3.5
const LIGHT_RANGE: float = 6.0
const LIGHT_HEIGHT: float = 1.0
## The metres it fades in over as it leaves, and out over before its range ends.
const FADE_IN: float = 1.5
const FADE_OUT: float = 4.0
## Mist and petals shed per rules frame (before the preset's scale).
const MIST: int = 1
const PETALS: int = 2
const MIST_COLOR: Color = Color(0.42, 0.45, 0.58, 0.07)
const PETAL_COLOR: Color = Color(0.82, 0.66, 0.95)

## Multiplies the light (CombatEffects.REDUCED_LIGHT under Reduce flashes).
var light_scale: float = 1.0

static var _meshes: Dictionary[StringName, ArrayMesh] = {}
## Each wave on screen by the rules' wave: [its crescent, its light].
var _shown: Dictionary[SlashWave, Array] = {}
## The last rules frame shed (-1 for none).
var _shed: int = -1
var _material: ShaderMaterial


func _init() -> void:
	name = "MoonWaves"
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"core", SILVER)
	_material.set_shader_parameter(&"fringe", WISTERIA)


## Shows every wave of `world` where the rules put it, `alpha` of the way
## from the step before to the last (MatchHost.alpha()), and drops the ones
## the rules no longer hold.
func sync(world: World, alpha: float) -> void:
	var live: Dictionary[SlashWave, bool] = {}
	if world != null:
		for w: SlashWave in world.waves:
			live[w] = true
			if not _shown.has(w):
				_shown[w] = _make(w.kind)
			var crescent: MeshInstance3D = _shown[w][0]
			var light: OmniLight3D = _shown[w][1]
			crescent.transform = transform_of(w, alpha)
			var f: float = fade(shown_s(w, alpha))
			(crescent.material_override as ShaderMaterial).set_shader_parameter(&"fade", f)
			light.position = crescent.position + Vector3(0.0, LIGHT_HEIGHT, 0.0)
			light.light_energy = LIGHT_ENERGY * f * light_scale
	for w: SlashWave in _shown.keys():
		if not live.has(w):
			for node: Node in _shown[w]:
				node.queue_free()
				remove_child(node)
			_shown.erase(w)


## How many waves are on screen.
func shown() -> int:
	return _shown.size()


## The crescent showing rules wave `w`, or null.
func node_of(w: SlashWave) -> Node3D:
	return _shown[w][0] if _shown.has(w) else null


## The light travelling with rules wave `w`, or null.
func light_of(w: SlashWave) -> OmniLight3D:
	return _shown[w][1] if _shown.has(w) else null


## Takes every wave off the screen (a new round, a new match).
func clear() -> void:
	for w: SlashWave in _shown.keys():
		for node: Node in _shown[w]:
			node.queue_free()
			remove_child(node)
	_shown.clear()
	_shed = -1


## How far wave `w` has flown on the frame shown, `alpha` of the way from
## the step before to the last.
static func shown_s(w: SlashWave, alpha: float) -> float:
	return maxf(0.0, w.s - World.WAVE_SPEED * SimConst.DT * (1.0 - clampf(alpha, 0.0, 1.0)))


## Where wave `w` stands on the frame shown: on the floor on its line,
## `shown_s()` along it, its +Z the way it flies.
static func transform_of(w: SlashWave, alpha: float) -> Transform3D:
	var s: float = shown_s(w, alpha)
	var ahead: Vector3 = Vector3(w.dx, 0.0, w.dz).normalized()
	var left: Vector3 = Vector3.UP.cross(ahead).normalized()
	return Transform3D(Basis(left, Vector3.UP, ahead), Vector3(w.ox + w.dx * s, 0.0, w.oz + w.dz * s))


## How much of a wave shows `s` metres into its flight: fading in as it
## leaves the blade and out at the end of its range.
static func fade(s: float) -> float:
	return smoothstep(0.0, FADE_IN, s + 0.15) * (1.0 - smoothstep(World.WAVE_RANGE - FADE_OUT, World.WAVE_RANGE, s))


## The crescent of wave kind `kind` (&"vertical" or &"horizontal"), in the
## wave's frame (+Z ahead, +X to its left, +Y up, its foot at the origin):
## a curved sheet, UV.x across it and UV.y along it, built once.
static func mesh_for(kind: StringName) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var along_n: int = 40 if kind == &"horizontal" else 24
	var across_n: int = 8
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in along_n + 1:
		for j: int in across_n + 1:
			var u: float = float(i) / along_n * 2.0 - 1.0
			var v: float = float(j) / across_n * 2.0 - 1.0
			st.set_uv(Vector2(float(j) / across_n, float(i) / along_n))
			st.add_vertex(_point(kind, u, v))
	for i: int in along_n:
		for j: int in across_n:
			var a: int = i * (across_n + 1) + j
			var b: int = a + across_n + 1
			for k: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(k)
	st.generate_normals()
	_meshes[kind] = st.commit()
	return _meshes[kind]


## A point of the crescent, `u` along it and `v` across it (each -1 to 1).
static func _point(kind: StringName, u: float, v: float) -> Vector3:
	# the lens: thinning to points at the tips
	var thick: float = sqrt(maxf(0.0, 1.0 - u * u))
	if kind == &"horizontal":
		var up: float = (v + 1.0) * 0.5
		return Vector3(u * SPAN, KNEE - BAND + (2.0 * BAND) * up * mix_thick(thick), SPAN_BOW * (1.0 - u * u) + LEAN * up * up)
	var top: float = (u + 1.0) * 0.5
	# across: from the back arc (v = -1) to the front one (v = 1), meeting
	# at the tips
	var bulge: float = lerpf(INNER, OUTER, (v + 1.0) * 0.5) * (1.0 - u * u)
	return Vector3(TIP_X + bulge, top * TALL, BOW * (1.0 - u * u) + CURL * top * top * top)


## Keeps a little band even at the tips, so the sheet never pinches to a line.
static func mix_thick(thick: float) -> float:
	return lerpf(0.25, 1.0, thick)


## Sheds mist and petals behind every wave of `world` for each rules frame
## stepped since the last call.
func shed(effects: CombatEffects, world: World) -> void:
	if world == null:
		return
	var frame: int = world.frame
	var last: int = _shed
	_shed = frame
	if last < 0 or frame <= last:
		return
	for fr: int in range(maxi(last + 1, frame - 8), frame + 1):
		for w: SlashWave in world.waves:
			shed_frame(effects, w, fr)


## One rules frame `fr` of wave `w`'s mist and petals, scattered by the
## frame and its owner: mist hanging in the air it has just passed through,
## petals drifting down and aside.
static func shed_frame(effects: CombatEffects, w: SlashWave, fr: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([w.owner.id if w.owner != null else 0, fr, &"moon_wave"])
	var xf: Transform3D = transform_of(w, 1.0)
	var f: float = fade(w.s)
	if f <= 0.0:
		return
	var born: float = float(fr)
	var wide: bool = w.kind == &"horizontal"
	var mist: int = MIST * (2 if wide else 1)
	for k: int in mist:
		var u: float = rng.randf_range(-1.0, 1.0) * (0.7 if wide else 1.0)
		var p: Vector3 = xf * (_point(w.kind, u, rng.randf_range(-0.6, 0.6)) - Vector3(0.0, 0.0, 0.6 + rng.randf() * 0.6))
		effects.burst(p, {
			"count": 1, "color": Color(MIST_COLOR, MIST_COLOR.a * f), "size": 0.35, "size_end": 0.9,
			"life": 36, "life_jitter": 0.3, "speed": 0.4, "dir": Vector3.UP, "spread": 70.0,
		}, born, rng.randi())
	for k: int in PETALS * (2 if wide else 1):
		var u: float = rng.randf_range(-1.0, 1.0) * (0.6 if wide else 1.0)
		var p: Vector3 = xf * (_point(w.kind, u, rng.randf_range(-0.8, 0.8)) - Vector3(0.0, 0.0, 0.3))
		effects.burst(p, {
			"count": 1, "color": PETAL_COLOR.lerp(SILVER, rng.randf() * 0.4), "size": 0.07, "size_end": 0.05,
			"life": 70, "life_jitter": 0.3, "speed": 1.6, "dir": xf.basis.x * (1.0 if rng.randf() < 0.5 else -1.0) + Vector3.UP * 0.4,
			"spread": 45.0, "gravity": 1.2, "floor": 0.02,
		}, born, rng.randi())


func _make(kind: StringName) -> Array:
	var crescent: MeshInstance3D = MeshInstance3D.new()
	crescent.name = "Wave"
	crescent.mesh = mesh_for(kind)
	crescent.material_override = _material.duplicate()
	crescent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crescent)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "WaveLight"
	light.light_color = SILVER.lerp(WISTERIA, 0.3)
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	add_child(light)
	return [crescent, light]
