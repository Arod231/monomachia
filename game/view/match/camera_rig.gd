class_name CameraRig
extends Camera3D
## The match camera. Port of v0.1-web-mvp:src/render/camera.ts, reframed as the spec's For
## Honor camera (spec, Decisions: "Camera"):
##
## - FOLLOW: over the player's right shoulder on the line from the player to
##   the opponent, about 4.6 m back (a little more as they separate), 1.35 m
##   to the right at 3.5 m apart and further, swinging further out by 0.8 m
##   for each metre closer (about 3.5 m at the closest), so the player doesn't
##   hide the opponent; at about head height and pitched nearly level, so
##   raised weapons read against the sky. It looks past the player's shoulder
##   at the opponent's chest.
## - WATCH: side-on to the line between the fighters, swaying slowly (Watch
##   mode, and the follow camera's swing to the side after a KO).
## - MENU: a slow orbit of the arena behind the menus.
##
## Direction, position and look point are smoothed (exponential damping), the
## position is clamped inside the arena (the arena's camera_max_radius from
## apply_arena(), else ARENA_RADIUS + arena_margin), and shake and
## field-of-view kicks are hooks for the view (on block, parry, counter,
## disarm, heavy hits and KO; see MatchView). The shake's random offsets come
## from a fixed seed, so a screenshot with shake is the same on every run.
## push_in() moves the camera part of the way to its look point and back
## (milestone-1 task 39: the parry's, and later the recall's and the
## ultimates'): it closes in over about 3 frames, holds while frozen (MatchView
## sets that through the hit-stop), then eases back over about 0.4 s, with a
## far blur (depth of field) while it is in where the graphics preset allows
## it (dof_allowed; off on Low).
## Every number is an exported tunable.
##
## The math is in follow_target(), watch_target() and menu_target(), which
## take positions and return {"pos", "look"}, so tests can check them without
## a scene.

enum Mode { FOLLOW, WATCH, MENU }

## The seed of the shake's random offsets.
const SHAKE_SEED: int = 0x5EED
## The furthest a push-in may go toward the look point.
const PUSH_IN_MAX: float = 0.9
## Slack on the push-in's timers, so 3 frames of 1/60 s make its 0.05 s.
const PUSH_EPSILON: float = 1e-5

@export var mode: Mode = Mode.FOLLOW

@export_group("Follow")
## Distance behind the player (m).
@export var follow_back: float = 4.6
## Extra distance per metre of separation past follow_far_from.
@export var follow_back_per_metre: float = 0.25
@export var follow_far_from: float = 3.0
## Separation past follow_far_from counts up to this many metres.
@export var follow_far_cap: float = 8.0
## Extra distance per metre the fighters are closer than follow_close_from
## (the demo used 0.5, which hid the opponent behind the player up close).
@export var follow_close_push: float = 0.0
## Extra offset to the right per metre the fighters are closer than
## follow_close_from, so the opponent stays in view past the shoulder: at
## 0.8 from 3.5 m a 0.35 m half-width (a real fighter's shoulders) on both
## stays clear down to 1.5 m apart.
@export var follow_close_side: float = 0.8
@export var follow_close_from: float = 3.5
## Offset to the player's right (m); positive is right.
@export var follow_side: float = 1.35
## Camera height above the floor (m).
@export var follow_height: float = 1.95
## Extra height per metre of separation past follow_far_from.
@export var follow_height_per_metre: float = 0.08
## How much of the player's jump height the camera follows.
@export var follow_jump: float = 0.5
## The look point: this far from the player toward the opponent (0 = player,
## 1 = opponent)...
@export var follow_look_lead: float = 1.0
## ...at this height (the opponent's chest)...
@export var follow_look_height: float = 1.3
## ...plus this much of their jump heights.
@export var follow_look_jump: float = 0.3
## Extra upward tilt after looking at the look point (degrees).
@export var follow_pitch_up: float = 3.0

@export_group("Watch")
@export var watch_distance: float = 4.6
@export var watch_distance_per_metre: float = 0.55
@export var watch_height: float = 1.9
@export var watch_height_per_metre: float = 0.08
## Pull back along the fighters' line (m).
@export var watch_back: float = 1.2
@export var watch_look_height: float = 1.1
## Slow sway around the side-on view (radians, and radians per second).
@export var watch_sway: float = 0.5
@export var watch_sway_speed: float = 0.15

@export_group("Menu")
@export var menu_radius: float = 10.5
@export var menu_height: float = 3.2
## Orbit speed (radians per second).
@export var menu_speed: float = 0.08
@export var menu_centre: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var menu_look: Vector3 = Vector3(0.0, 1.4, 0.0)

@export_group("Smoothing")
## Damping rates (1/s): higher follows faster.
@export var direction_damping: float = 6.0
@export var follow_position_damping: float = 9.0
@export var watch_position_damping: float = 3.0
@export var look_damping: float = 12.0

@export_group("Lens")
@export var base_fov: float = 60.0
@export var near_clip: float = 0.1
## The far clip without arena data (an arena's camera_far replaces it).
@export var far_clip: float = 900.0

@export_group("Arena")
## Without arena data the camera stays within ARENA_RADIUS + arena_margin of
## the centre (19 m for the 15 m arena), except in MENU.
@export var arena_margin: float = 4.0

@export_group("Shake and kicks")
@export var shake_max: float = 1.2
## Offset per unit of shake (m, peak to peak).
@export var shake_amplitude: float = 0.12
@export var shake_decay: float = 9.0
@export var fov_kick_decay: float = 3.0
## Scales every shake and kick (the reduce-flashes-and-shaking setting sets
## 0.15 and 0).
@export var shake_scale: float = 1.0
@export var fov_kick_scale: float = 1.0
## Scales every push-in (the reduce-flashes-and-shaking setting sets 0).
@export var push_in_scale: float = 1.0
## After a KO the follow camera swings out to the side-on view until the next
## round (single screen only).
@export var ko_orbit_enabled: bool = true

@export_group("Push-in")
## How long a push-in takes to close in (s): about 3 frames.
@export var push_in_time: float = 0.05
## How long it takes to ease back out once it is no longer frozen (s).
@export var push_out_time: float = 0.4
## The far blur while pushed in: where it starts past the look point (m),
## how far it takes to reach full (m), and how much at full.
@export var push_dof_margin: float = 1.5
@export var push_dof_transition: float = 6.0
@export var push_dof_amount: float = 0.08

var shake: float = 0.0
var fov_kick: float = 0.0
## The current push-in's peak (the share of the way to the look point), 0
## when there is none.
var push_peak: float = 0.0
## The match is in hit-stop: a push-in holds where it is (MatchView sets it
## every frame).
var frozen: bool = false
## Whether a push-in brings its far blur (the graphics preset's push_in_dof).
var dof_allowed: bool = true
## Seconds since a KO swung the camera out, 0 when it isn't.
var ko_orbit: float = 0.0
## The smoothed player-to-opponent direction (unit, horizontal).
var dir: Vector3 = Vector3(0.0, 0.0, 1.0)
## The smoothed position and look point, before shake.
var rig_position: Vector3 = Vector3(0.0, 3.0, -9.0)
var rig_look: Vector3 = Vector3(0.0, 1.2, 0.0)
## The arena's camera data (ArenaDef.camera_max_radius and camera_far), set by
## apply_arena(); 0 when the arena has none.
var arena_max_radius: float = 0.0
var arena_far: float = 0.0
var _time: float = 0.0
## The shake's offsets: seeded, so the same shake looks the same every run.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The push-in: where it closes in from, its timers, and its blur.
var _push_from: float = 0.0
var _push_in_t: float = 0.0
var _push_out_t: float = 0.0
var _dof: CameraAttributesPractical


func _init() -> void:
	_rng.seed = SHAKE_SEED
	_apply_lens()


func _ready() -> void:
	_apply_lens()


func _apply_lens() -> void:
	fov = base_fov
	near = near_clip
	far = arena_far if arena_far > 0.0 else far_clip


## Takes an arena's camera data: how far from the centre the camera may go
## (ArenaDef.camera_max_radius) and the far clip its backdrop needs
## (ArenaDef.camera_far). 0 for either restores the default
## (ARENA_RADIUS + arena_margin, far_clip).
func apply_arena(max_radius: float, far_plane: float) -> void:
	arena_max_radius = maxf(0.0, max_radius)
	arena_far = maxf(0.0, far_plane)
	far = arena_far if arena_far > 0.0 else far_clip


# ------------------------------------------------------------------ hooks

func add_shake(amount: float) -> void:
	shake = minf(shake_max, shake + amount * shake_scale)


func kick_fov(amount: float) -> void:
	fov_kick = amount * fov_kick_scale


## Pushes the camera in toward its look point by amount (the share of the way
## there: MatchView's 0.15 on a parry, 0.25 on a Flash or a redirect): it
## closes in over push_in_time, holds while frozen (the hit-stop), then eases
## back out over push_out_time, with a far blur while it is in when
## dof_allowed. A push-in during another carries on from where the camera is.
## Scaled by push_in_scale (Reduce flashes sets 0).
func push_in(amount: float) -> void:
	var peak: float = clampf(amount * push_in_scale, 0.0, PUSH_IN_MAX)
	if peak <= 0.0:
		return
	_push_from = push_amount()
	push_peak = maxf(peak, _push_from)
	_push_in_t = 0.0
	_push_out_t = 0.0


## Ends any push-in at once (match start).
func end_push_in() -> void:
	push_peak = 0.0
	_push_from = 0.0
	_push_in_t = 0.0
	_push_out_t = 0.0
	_apply_dof(0.0, 0.0)


## The share of the way to the look point the camera is pushed in now.
func push_amount() -> float:
	if push_peak <= 0.0:
		return 0.0
	if not _pushed_in():
		return lerpf(_push_from, push_peak, smoothstep(0.0, push_in_time, _push_in_t))
	return push_peak * (1.0 - smoothstep(0.0, push_out_time, _push_out_t))


func _pushed_in() -> bool:
	return _push_in_t >= push_in_time - PUSH_EPSILON


## Moves the push-in on by delta seconds: in, then held while frozen, then out.
func _advance_push(delta: float) -> void:
	if push_peak <= 0.0:
		return
	if not _pushed_in():
		_push_in_t = minf(push_in_time, _push_in_t + delta)
	elif not frozen:
		_push_out_t += delta
		if _push_out_t >= push_out_time - PUSH_EPSILON:
			end_push_in()


## The far blur for a push-in of p, the look point `reach` metres away: off at
## rest, without dof_allowed, or on a camera given attributes of its own.
func _apply_dof(p: float, reach: float) -> void:
	if p <= 0.0 or push_peak <= 0.0 or not dof_allowed:
		if _dof != null and attributes == _dof:
			attributes = null
		return
	if attributes != null and attributes != _dof:
		return
	if _dof == null:
		_dof = CameraAttributesPractical.new()
		_dof.dof_blur_far_enabled = true
		_dof.dof_blur_near_enabled = false
	_dof.dof_blur_far_distance = reach + push_dof_margin
	_dof.dof_blur_far_transition = push_dof_transition
	_dof.dof_blur_amount = push_dof_amount * p / push_peak
	attributes = _dof


## Swing out to the side after a KO (cleared by reset_round()).
func start_ko_orbit() -> void:
	if ko_orbit_enabled and ko_orbit <= 0.0:
		ko_orbit = 0.001


func reset_round() -> void:
	ko_orbit = 0.0


# ------------------------------------------------------------------ per frame

## Jumps straight to where the camera wants to be (match start, screenshots).
func snap(player: Vector3, opponent: Vector3) -> void:
	_move(0.0, player, opponent, true)


## Moves the camera toward its target for this frame. player and opponent are
## the fighters' feet positions; in MENU they are ignored.
func update_rig(delta: float, player: Vector3, opponent: Vector3) -> void:
	_move(delta, player, opponent, false)


func _move(delta: float, player: Vector3, opponent: Vector3, p_snap: bool) -> void:
	_time += delta
	dir = smoothed_direction(dir, player, opponent, 1.0 if p_snap else 1.0 - exp(-direction_damping * delta))
	var target: Dictionary
	var damping: float = follow_position_damping
	if mode == Mode.MENU:
		target = menu_target(_time)
		damping = watch_position_damping
	elif mode == Mode.WATCH or ko_orbit > 0.0:
		target = watch_target(player, opponent, dir, _time, ko_orbit)
		damping = watch_position_damping
		if ko_orbit > 0.0:
			ko_orbit += delta
	else:
		target = follow_target(player, opponent, dir)
	var tpos: Vector3 = target["pos"]
	var tlook: Vector3 = target["look"]
	if mode != Mode.MENU:
		tpos = clamp_to_arena(tpos)
	if p_snap:
		rig_position = tpos
		rig_look = tlook
	else:
		rig_position = rig_position.lerp(tpos, 1.0 - exp(-damping * delta))
		rig_look = rig_look.lerp(tlook, 1.0 - exp(-look_damping * delta))
	_apply(delta)


func _apply(delta: float) -> void:
	_advance_push(delta)
	var push: float = push_amount()
	var at: Vector3 = rig_position.lerp(rig_look, push)
	_apply_dof(push, at.distance_to(rig_look))
	if shake > 0.001:
		var s: float = shake * shake_amplitude
		at += Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * s
		shake *= exp(-shake_decay * delta)
	else:
		shake = 0.0
	var t: Transform3D = Transform3D(Basis.IDENTITY, at)
	if not at.is_equal_approx(rig_look):
		t = t.looking_at(rig_look, Vector3.UP)
	var pitch_up: float = follow_pitch_up if mode == Mode.FOLLOW and ko_orbit <= 0.0 else 0.0
	if pitch_up != 0.0:
		t.basis = t.basis * Basis(Vector3.RIGHT, deg_to_rad(pitch_up))
	if is_inside_tree():
		global_transform = t
	else:
		transform = t
	fov_kick *= exp(-fov_kick_decay * delta)
	fov = base_fov - fov_kick


# ------------------------------------------------------------------ the math

## The player-to-opponent direction blended from the last one by t (0..1),
## kept when they stand on top of each other.
static func smoothed_direction(current: Vector3, player: Vector3, opponent: Vector3, t: float) -> Vector3:
	var d: Vector3 = Vector3(opponent.x - player.x, 0.0, opponent.z - player.z)
	if d.length() <= 0.3:
		return current
	var blended: Vector3 = current.lerp(d.normalized(), t)
	if blended.length() < 1e-4:
		return d.normalized()
	return blended.normalized()


## The fighter's right for a facing direction (+z forward means -x right).
static func right_of(direction: Vector3) -> Vector3:
	return Vector3(-direction.z, 0.0, direction.x)


## FOLLOW: { "pos": camera position, "look": look point } behind the player.
func follow_target(player: Vector3, opponent: Vector3, direction: Vector3) -> Dictionary:
	var d: float = Vector2(opponent.x - player.x, opponent.z - player.z).length()
	var extra: float = clampf(d - follow_far_from, 0.0, follow_far_cap)
	var close: float = maxf(0.0, follow_close_from - d)
	var back: float = follow_back + extra * follow_back_per_metre + close * follow_close_push
	var side: float = follow_side + close * follow_close_side
	var pos: Vector3 = Vector3(player.x, 0.0, player.z) - direction * back + right_of(direction) * side
	pos.y = follow_height + extra * follow_height_per_metre + player.y * follow_jump
	var look: Vector3 = Vector3(player.x, 0.0, player.z).lerp(Vector3(opponent.x, 0.0, opponent.z), follow_look_lead)
	look.y = follow_look_height + (player.y + opponent.y) * follow_look_jump
	return {"pos": pos, "look": look}


## WATCH: side-on to the fighters' midpoint, swaying slowly. ko_t > 0 swings
## it further round after a KO.
func watch_target(player: Vector3, opponent: Vector3, direction: Vector3, time: float, ko_t: float = 0.0) -> Dictionary:
	var d: float = Vector2(opponent.x - player.x, opponent.z - player.z).length()
	var mid: Vector3 = Vector3((player.x + opponent.x) / 2.0, 0.0, (player.z + opponent.z) / 2.0)
	var swing: float = sin(time * watch_sway_speed) * watch_sway + (ko_t * 0.25 if ko_t > 0.0 else 0.0)
	var side: Vector3 = right_of(direction).rotated(Vector3.UP, swing)
	var pos: Vector3 = mid + side * (watch_distance + d * watch_distance_per_metre) - direction * watch_back
	pos.y = watch_height + d * watch_height_per_metre
	var look: Vector3 = mid
	look.y = watch_look_height
	return {"pos": pos, "look": look}


## MENU: a slow orbit around the arena.
func menu_target(time: float) -> Dictionary:
	var a: float = time * menu_speed
	var pos: Vector3 = menu_centre + Vector3(sin(a) * menu_radius, menu_height, cos(a) * menu_radius)
	return {"pos": pos, "look": menu_look}


## How far from the arena's centre the camera may go: the arena's
## camera_max_radius, else ARENA_RADIUS + arena_margin.
func arena_limit() -> float:
	return arena_max_radius if arena_max_radius > 0.0 else SimConst.ARENA_RADIUS + arena_margin


## The arena clamp: no further than arena_limit() from the centre.
func clamp_to_arena(p: Vector3) -> Vector3:
	var limit: float = arena_limit()
	var r: float = Vector2(p.x, p.z).length()
	if r > limit:
		p.x *= limit / r
		p.z *= limit / r
	return p
