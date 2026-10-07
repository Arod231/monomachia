class_name ArenaDef
extends Resource
## The data that describes one arena: where fighters may walk, where they
## start, where the gates stand, how far cameras may go, and which ambience
## plays. The arena's look lives in its scene (scene_path); the rules only
## need walkable_radius, which must equal the rules' ARENA_RADIUS for
## ArenaScenes to use the scene.
##
## All positions are in metres in the arena's own space, which is the rules'
## space: the floor is y = 0, the centre of the fighting area is the origin,
## and fighters face each other along the z axis (the rules start side 0 at
## z = -3.85 facing +Z and side 1 at z = +3.85 facing -Z).

## Stable id, used by saves, menus and the match setup.
@export var id: StringName = &""
@export var display_name: String = ""
## Path of the arena scene. A path, not a PackedScene, so the scene may point
## back at this resource without a load cycle.
@export_file("*.tscn") var scene_path: String = ""

@export_group("Space")
## How far fighters' bodies reach: their centres stay within
## walkable_radius - fighter radius. Equals the rules' ARENA_RADIUS (the
## demo's "inner wall radius"); the wall's inner face stands at or just
## outside it.
@export var walkable_radius: float = 15.0
## The centre line of the wall (the parapet) that visibly stops fighters.
@export var wall_radius: float = 15.3
## The wall's thickness; its inner face is wall_radius - wall_thickness / 2.
@export var wall_thickness: float = 0.45
## Height of the wall's top rail.
@export var wall_height: float = 1.05
## Outer edge of the paved floor.
@export var floor_radius: float = 15.9

@export_group("Placement")
## Each side's spawn: position and facing (-Z of the basis faces the
## opponent). Index 0 is player one (red), index 1 player two (blue). They
## match where the rules start each round.
@export var spawn_points: Array[Transform3D] = []
## Where each side's gate stands, facing into the arena (for the match
## intro: each fighter walks out of their gate toward their spawn).
@export var gate_anchors: Array[Transform3D] = []

@export_group("Camera")
## Horizontal distance from the centre the cameras may reach (CameraRig
## clamps to it).
@export var camera_max_radius: float = 19.5
## Far clip plane the arena's cameras need to see the whole backdrop (the
## farthest mountains and the edge of the sea of clouds).
@export var camera_far: float = 3000.0

@export_group("Sound")
## The looping ambience bed: a cue id in SoundBank.CUES.
@export var ambience_id: StringName = &""

@export_group("Look")
## The arena's Environment (sky, fog, ambient, tonemap). Unset, the arena's
## scene brings its own.
@export var environment: Environment


## Inner face of the wall.
func wall_inner_radius() -> float:
	return wall_radius - wall_thickness * 0.5


## Outer face of the wall.
func wall_outer_radius() -> float:
	return wall_radius + wall_thickness * 0.5


## Is a point (ignoring height) inside the walkable area?
func is_walkable(point: Vector3, body_radius: float = 0.0) -> bool:
	return Vector2(point.x, point.z).length() + body_radius <= walkable_radius


## Spawn for side 0 or 1.
func spawn_point(side: int) -> Transform3D:
	return spawn_points[side]


## Gate anchor for side 0 or 1.
func gate_anchor(side: int) -> Transform3D:
	return gate_anchors[side]


## Problems with the data, or an empty list. Checked by the tests. Whether
## the scene exists and the radius matches the rules is ArenaScenes' call.
func validate(fighter_radius: float = SimConst.FIGHTER_RADIUS) -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id is empty")
	if spawn_points.size() != 2:
		problems.append("needs exactly two spawn points")
	if gate_anchors.size() != 2:
		problems.append("needs exactly two gate anchors")
	if wall_inner_radius() < walkable_radius - 0.001:
		problems.append("the wall's inner face (%.2f) is inside the walkable radius (%.2f)" % [wall_inner_radius(), walkable_radius])
	if floor_radius < wall_outer_radius():
		problems.append("the floor ends inside the wall")
	for i: int in spawn_points.size():
		if not is_walkable(spawn_points[i].origin, fighter_radius):
			problems.append("spawn %d is outside the walkable area" % i)
	if spawn_points.size() == 2:
		for i: int in 2:
			var spawn: Transform3D = spawn_points[i]
			var other: Vector3 = spawn_points[1 - i].origin
			var facing: Vector3 = -spawn.basis.z
			if facing.dot((other - spawn.origin).normalized()) < 0.99:
				problems.append("spawn %d doesn't face the other spawn" % i)
	if gate_anchors.size() == 2 and spawn_points.size() == 2:
		for i: int in 2:
			var gate: Vector3 = gate_anchors[i].origin
			var spawn: Vector3 = spawn_points[i].origin
			if Vector2(gate.x, gate.z).length() <= Vector2(spawn.x, spawn.z).length():
				problems.append("gate %d is not outside its spawn point" % i)
			if (gate - spawn).dot(spawn - spawn_points[1 - i].origin) <= 0.0:
				problems.append("gate %d is not behind its spawn point" % i)
	return problems
