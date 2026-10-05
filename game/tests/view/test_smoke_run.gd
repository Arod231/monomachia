extends GutTest
## The --smoke check that exported builds run: a computer-vs-computer match
## played through main.tscn to the results, as fast as the rules step,
## failing on any error, on a stall or when it runs out of time.

const MainScript := preload("res://scenes/main.gd")

var main: Node
var host: MatchHost


func before_each() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# These tests don't need the shrine: the stand-in keeps them fast.
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	host = main.get_node("MatchHost")
	host.auto_run = false


func _run(smoke: SmokeRun, ticks: int) -> SmokeRun.Status:
	var status: SmokeRun.Status = SmokeRun.Status.RUNNING
	for i: int in ticks:
		status = smoke.tick()
		if status != SmokeRun.Status.RUNNING:
			break
	return status


func test_the_flag_is_read_from_the_joined_argument_lists() -> void:
	var engine_args: PackedStringArray = PackedStringArray(["--path", "game"])
	var user_args: PackedStringArray = PackedStringArray(["--smoke"])
	assert_true(SmokeRun.requested(engine_args + user_args))
	assert_true(SmokeRun.requested(PackedStringArray(["--smoke", "--log-file", "x.log"])))
	assert_false(SmokeRun.requested(PackedStringArray(["--headless", "--smoke-test"])))


func test_main_only_processes_frames_for_a_smoke_run() -> void:
	assert_false(main.is_processing(), "an ordinary session never ticks a smoke run")


func test_a_watch_match_reaches_the_results() -> void:
	var smoke: SmokeRun = autofree_smoke(SmokeRun.new(main))
	smoke.start()
	assert_eq(host.config.mode, MatchConfig.WATCH, "computer against computer")
	assert_false(host.attract)
	assert_eq(_run(smoke, 1000), SmokeRun.Status.PASSED)
	assert_not_null(smoke.results)
	assert_eq(main.get("screen"), MainScript.Screen.RESULTS, "the results screen is up")
	assert_string_contains(smoke.report(), "results")
	assert_eq(smoke.exit_code(), 0)


func test_a_pause_from_focus_loss_does_not_stall_it() -> void:
	var smoke: SmokeRun = autofree_smoke(SmokeRun.new(main))
	smoke.start()
	smoke.tick()
	host.pause()
	assert_true(host.is_paused())
	assert_eq(_run(smoke, 1000), SmokeRun.Status.PASSED, "the smoke run resumes the match")


func test_it_fails_when_the_results_never_come() -> void:
	var smoke: SmokeRun = autofree_smoke(SmokeRun.new(main))
	smoke.max_steps = 120
	smoke.start()
	assert_eq(_run(smoke, 1000), SmokeRun.Status.FAILED)
	assert_string_contains(smoke.report(), "no results")
	assert_eq(smoke.exit_code(), 1)


func test_it_fails_when_it_runs_out_of_time() -> void:
	var smoke: SmokeRun = autofree_smoke(SmokeRun.new(main))
	smoke.max_seconds = 0.0
	smoke.start()
	assert_eq(_run(smoke, 1000), SmokeRun.Status.FAILED)
	assert_string_contains(smoke.report(), "out of time")


func test_any_error_fails_it_at_once() -> void:
	var smoke: SmokeRun = autofree_smoke(SmokeRun.new(main))
	smoke.start()
	# What the engine calls on a script error, without raising a real one.
	smoke.errors._log_error("f", "res://x.gd", 3, "boom", "", false, Logger.ERROR_TYPE_SCRIPT, [])
	assert_eq(_run(smoke, 1000), SmokeRun.Status.FAILED)
	assert_eq(smoke.exit_code(), 1)
	assert_string_contains(smoke.report(), "1 error")
	assert_string_contains(smoke.report(), "res://x.gd:3: boom")


func test_a_warning_alone_does_not_fail_it() -> void:
	var smoke: SmokeRun = autofree_smoke(SmokeRun.new(main))
	smoke.start()
	smoke.errors._log_error("f", "res://x.gd", 4, "a warning", "", false, Logger.ERROR_TYPE_WARNING, [])
	assert_eq(_run(smoke, 1000), SmokeRun.Status.PASSED)


func test_the_report_names_the_control_profiles() -> void:
	var smoke: SmokeRun = autofree_smoke(SmokeRun.new(main))
	var names: PackedStringArray = GameServices.profiles.names()
	assert_gt(names.size(), 0)
	assert_string_contains(smoke.report(), names[0])


## Removes the run's error logger when the test ends.
func autofree_smoke(smoke: SmokeRun) -> SmokeRun:
	_smokes.append(smoke)
	return smoke


var _smokes: Array[SmokeRun] = []


func after_each() -> void:
	for s: SmokeRun in _smokes:
		s.finish()
	_smokes.clear()
