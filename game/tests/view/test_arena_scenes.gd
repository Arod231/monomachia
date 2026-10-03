extends GutTest
## ArenaScenes, the arenas a match can be fought in: an arena's own scene is
## used only when it exists and its walkable radius is the rules'
## ARENA_RADIUS, so a real arena never stands an invisible rules wall inside
## its visible one. Anything else draws the stand-in, whose wall follows the
## rules' radius.

## A scene that exists, to stand in for a built arena's.
const BUILT_SCENE := "res://tests/fixtures/arena_fixture.tscn"


func _def(radius: float, scene: String = BUILT_SCENE) -> ArenaDef:
	var d := ArenaDef.new()
	d.id = &"test_arena"
	d.scene_path = scene
	d.walkable_radius = radius
	return d


func test_a_built_arena_at_the_rules_radius_uses_its_own_scene() -> void:
	assert_eq(ArenaScenes.scene_path_for(_def(SimConst.ARENA_RADIUS)), BUILT_SCENE)


func test_an_arena_at_another_radius_falls_back_to_the_standin() -> void:
	assert_eq(ArenaScenes.scene_path_for(_def(SimConst.ARENA_RADIUS + 3.5)), ArenaScenes.STANDIN_SCENE)


func test_an_arena_whose_scene_isnt_built_falls_back_to_the_standin() -> void:
	var d: ArenaDef = _def(SimConst.ARENA_RADIUS, "res://arenas/no_such_arena/no_such_arena.tscn")
	assert_eq(ArenaScenes.scene_path_for(d), ArenaScenes.STANDIN_SCENE)


func test_the_shrine_is_known_by_its_data() -> void:
	assert_true(ArenaScenes.has(ArenaScenes.MOONLIT_SHRINE))
	assert_true(ArenaScenes.has(ArenaScenes.STANDIN))
	assert_false(ArenaScenes.has(&"no_such_arena"))
	var shrine: ArenaDef = ArenaScenes.def(ArenaScenes.MOONLIT_SHRINE)
	assert_not_null(shrine)
	assert_eq(shrine.id, ArenaScenes.MOONLIT_SHRINE)
	assert_null(ArenaScenes.def(ArenaScenes.STANDIN), "the stand-in has no data")
	assert_null(ArenaScenes.def(&"no_such_arena"))


func test_the_shrine_is_at_the_rules_radius_so_it_draws_as_itself() -> void:
	assert_eq(SimConst.ARENA_RADIUS, 15.0)
	var shrine: ArenaDef = ArenaScenes.def(ArenaScenes.MOONLIT_SHRINE)
	assert_eq(shrine.walkable_radius, SimConst.ARENA_RADIUS)
	assert_true(ResourceLoader.exists(shrine.scene_path), "the shrine's scene is built")
	assert_eq(ArenaScenes.scene_path(ArenaScenes.MOONLIT_SHRINE), shrine.scene_path)


func test_unknown_ids_and_the_standin_draw_the_standin() -> void:
	assert_eq(ArenaScenes.scene_path(&"no_such_arena"), ArenaScenes.STANDIN_SCENE)
	assert_eq(ArenaScenes.scene_path(ArenaScenes.STANDIN), ArenaScenes.STANDIN_SCENE)
	var node: Node3D = autofree(ArenaScenes.instantiate(&"no_such_arena"))
	assert_eq(node.scene_file_path, ArenaScenes.STANDIN_SCENE)
