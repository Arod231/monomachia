extends GutTest
## Checks that the project runs on the Godot version the build expects.


func test_runs_on_godot_4_7() -> void:
	var info: Dictionary = Engine.get_version_info()
	assert_eq(info.major, 4)
	assert_eq(info.minor, 7)


func test_simulation_ticks_at_60_per_second() -> void:
	assert_eq(Engine.physics_ticks_per_second, 60)
