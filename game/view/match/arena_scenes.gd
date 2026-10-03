class_name ArenaScenes
extends RefCounted
## The arenas a match can be fought in: arena id -> the arena's data
## (ArenaDef), which names its scene. The match view loads the arena named by
## MatchConfig.arena_id from here, so a real arena drops in by adding one
## line, without touching the host or the view.
##
## An arena scene's root is a Node3D centred on the arena's middle, floor at
## y = 0, wall at its ArenaDef's walkable_radius. It may hold Marker3D
## children named Spawn0, Spawn1, Gate0 and Gate1 (spawn points and gate
## anchors), and a `def` property holding its ArenaDef, from which the camera
## takes its limits (MatchView.arena_camera_data). The rules still place the
## fighters themselves (World.reset_round).
##
## The radius guard: an arena's own scene is used only when it exists and its
## walkable radius is the rules' ARENA_RADIUS. Otherwise the rules' wall would
## stand somewhere other than the arena's visible one, so the stand-in, whose
## wall follows the rules' radius, is drawn instead. The shrine's 15 m is the
## rules' radius, so it draws as itself.

const STANDIN: StringName = &"standin"
const MOONLIT_SHRINE: StringName = &"moonlit_shrine"

## The stand-in arena, built in code at the rules' radius. It has no ArenaDef.
const STANDIN_SCENE: String = "res://view/match/standin_arena.tscn"

## Each real arena's data (an ArenaDef .tres), by id.
const DEFS: Dictionary[StringName, String] = {
	MOONLIT_SHRINE: "res://arenas/moonlit_shrine/moonlit_shrine.tres",
}


static func has(id: StringName) -> bool:
	return id == STANDIN or DEFS.has(id)


## The arena's data, or null for the stand-in and unknown ids.
static func def(id: StringName) -> ArenaDef:
	var path: String = DEFS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as ArenaDef


## The scene to draw an arena with: its own when it exists and its walkable
## radius is the rules' ARENA_RADIUS, else the stand-in's.
static func scene_path_for(arena: ArenaDef) -> String:
	if arena == null or not is_equal_approx(arena.walkable_radius, SimConst.ARENA_RADIUS):
		return STANDIN_SCENE
	if arena.scene_path == "" or not ResourceLoader.exists(arena.scene_path):
		return STANDIN_SCENE
	return arena.scene_path


## The scene path for an arena id (see scene_path_for).
static func scene_path(id: StringName) -> String:
	return scene_path_for(def(id))


## A new instance of the arena (the stand-in when the id is unknown or the
## guard holds the arena back).
static func instantiate(id: StringName) -> Node3D:
	var packed: PackedScene = load(scene_path(id))
	return packed.instantiate() as Node3D
