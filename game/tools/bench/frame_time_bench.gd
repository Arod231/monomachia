extends Control
## The frame-time harness (milestone-1 task 28, story 201): plays the
## worst-case replay (WorstCase.PATH) in a window and writes every frame's
## time, for the performance gates: "holds 60 fps" is 99% of frames at
## 16.7 ms or less (FrameTimes). Run it with
##   npm run bench [-- --preset=<id>] [--res=<w>x<h>] [--log=<path>] [--out=<file.csv>] [--no-warmup]
## The match renders at --res (3840x2160, the Ultra gate's 4K, by default)
## into a render target the window shows scaled to fit, so a 4K run works on
## a smaller screen too (the owner's PC drives a 2560x1440 screen), with the
## preset (the default one unless --preset names another) applied to the
## render target and the match. Vsync is off and nothing caps the frame rate.
##
## The run, one rules step a frame, so every run times the same frames:
## 1. the warm-up: the whole log plays once, untimed, so every shader the
##    match uses has compiled (the owner's choice, Oct 5; --no-warmup skips
##    it, for a quick look);
## 2. the log starts again; its lead-in (all but the last WorstCase.STEPS
##    steps) plays untimed, several steps a frame;
## 3. the window: each of its WorstCase.STEPS frames is timed (the whole
##    frame, and the render target's GPU and CPU render times).
## Then it writes the frames to --out (by default user://bench/), prints the
## summary (the 99th percentile against the gate, the mean, the worst frame,
## the share within 16.7 ms) and whether the replay still matched its log,
## and quits: 0 when the replay matched, 1 when it drifted or the run
## couldn't start. godot.mjs passes --fixed-fps 60, so the view's animations
## move 1/60 s a frame, as the rules do. A replay feeds the log's inputs, so
## the computer's thinking is left out of the times.

enum Phase { WARMUP, LEAD_IN, TIMED, DONE }

const DEFAULT_RES: Vector2i = Vector2i(3840, 2160)
## Lead-in steps played per frame.
const LEAD_IN_STEPS: int = 8

var output_size: Vector2i = DEFAULT_RES
var preset: GraphicsPreset
var log_in: InputLog
var log_path: String = WorstCase.PATH
var out_path: String = ""
var warmup: bool = true
var host: MatchHost
## The steps before the timed window.
var window_start: int = 0
var phase: Phase = Phase.WARMUP

var _target: SubViewport
var _label: Label
var _last_usec: int = 0
var _frame_ms: PackedFloat64Array = PackedFloat64Array()
var _gpu_ms: PackedFloat64Array = PackedFloat64Array()
var _cpu_ms: PackedFloat64Array = PackedFloat64Array()
var _steps: PackedInt32Array = PackedInt32Array()
var _replay_checked: bool = false
var _replay_ok: bool = false
var _replay_report: String = "replay: never checked"


func _ready() -> void:
	var problem: String = _apply_args(OS.get_cmdline_user_args())
	if problem == "":
		log_in = InputLog.load_file(log_path)
		if log_in == null:
			problem = "no input log at %s" % log_path
	if problem != "":
		push_error("frame_time_bench.gd: %s" % problem)
		_quit(1)
		return
	window_start = maxi(0, log_in.step_count() - WorstCase.STEPS)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AudioServer.set_bus_mute(0, true)
	_target = SubViewport.new()
	_target.size = output_size
	_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_target)
	var shown := TextureRect.new()
	shown.texture = _target.get_texture()
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shown)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.position = Vector2(16, 12)
	add_child(_label)
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	host.replay_checked.connect(_on_replay_checked)
	_target.add_child(host)
	RenderingServer.viewport_set_measure_render_time(_target.get_viewport_rid(), true)
	print("bench: %s at %dx%d (3D at %.0f%%), %s: %d steps, the last %d timed, on %s" % [
		preset.display_name, output_size.x, output_size.y, preset.render_scale * 100.0, log_path,
		log_in.step_count(), log_in.step_count() - window_start, RenderingServer.get_video_adapter_name()])
	_start(Phase.WARMUP if warmup else Phase.LEAD_IN)


## Reads --preset=, --res=, --log=, --out= and --no-warmup; returns what is
## wrong with them, or "".
func _apply_args(args: PackedStringArray) -> String:
	var preset_id: StringName = GraphicsPreset.DEFAULT_ID
	for a: String in args:
		if a.begins_with("--preset="):
			preset_id = StringName(a.trim_prefix("--preset="))
		elif a.begins_with("--res="):
			var size: PackedStringArray = a.trim_prefix("--res=").split("x")
			if size.size() != 2 or not size[0].is_valid_int() or not size[1].is_valid_int() or int(size[0]) < 1 or int(size[1]) < 1:
				return "--res= takes <width>x<height>, not '%s'" % a
			output_size = Vector2i(int(size[0]), int(size[1]))
		elif a.begins_with("--log="):
			log_path = a.trim_prefix("--log=")
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a == "--no-warmup":
			warmup = false
	preset = GraphicsPreset.load_id(preset_id)
	if preset == null:
		return "no preset '%s' (%s)" % [preset_id, ", ".join(PackedStringArray(GraphicsPreset.IDS))]
	return ""


## Starts the log from its first step for the warm-up or the timed pass, and
## applies the preset to the render target and the match the view just built.
func _start(p: Phase) -> void:
	phase = p
	host.start_replay(log_in)
	GraphicsApplier.apply(preset, host, _target)
	_last_usec = 0


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	match phase:
		Phase.WARMUP:
			if host.step_count >= log_in.step_count():
				_start(Phase.LEAD_IN)
			else:
				host.step(1)
		Phase.LEAD_IN:
			if host.step_count >= window_start:
				phase = Phase.TIMED
			else:
				host.step(mini(LEAD_IN_STEPS, window_start - host.step_count))
		Phase.TIMED:
			if _last_usec != 0:
				var rid: RID = _target.get_viewport_rid()
				_frame_ms.append((now - _last_usec) / 1000.0)
				_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
				_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
				_steps.append(host.step_count)
			_last_usec = now
			if host.step_count >= log_in.step_count():
				_finish()
				return
			host.step(1)
	if Engine.get_process_frames() % 30 == 0:
		_label.text = "%s: step %d of %d" % [Phase.keys()[phase].to_lower().replace("_", "-"), host.step_count, log_in.step_count()]


func _on_replay_checked(ok: bool, report: String) -> void:
	_replay_checked = true
	_replay_ok = ok
	_replay_report = report


## Checks the replay against its log, writes the frames, prints the summary
## and quits.
func _finish() -> void:
	phase = Phase.DONE
	host.step(1) # past the log's end: the host checks it
	var path: String = out_path
	if path == "":
		DirAccess.make_dir_recursive_absolute("user://bench")
		var stamp: String = Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "-")
		path = "user://bench/frame-times-%s-%dx%d-%s.csv" % [preset.id, output_size.x, output_size.y, stamp]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("frame_time_bench.gd: cannot write %s" % path)
	else:
		f.store_string(FrameTimes.csv(_frame_ms, _gpu_ms, _cpu_ms, _steps))
		f.close()
	for line: String in report_lines(FrameTimes.summary(_frame_ms), FrameTimes.mean(_gpu_ms), FrameTimes.mean(_cpu_ms)):
		print(line)
	if not _replay_checked:
		print(_replay_report) # the host prints the line when it checks
	print("bench: frame times written to %s" % ProjectSettings.globalize_path(path))
	_quit(0 if _replay_ok else 1)


## The summary's lines: the gate's verdict with the 99th percentile, then the
## mean, the worst frame and the render times.
static func report_lines(s: Dictionary, gpu_mean: float, cpu_mean: float) -> PackedStringArray:
	return PackedStringArray([
		"bench: 99th percentile %.2f ms against the gate's %.1f ms: %s (%.2f%% of %d frames within it)" % [
			s["p99_ms"], FrameTimes.GATE_MS, "holds" if s["holds"] else "misses", s["within"] * 100.0, s["frames"]],
		"bench: mean %.2f ms (%.0f fps), worst %.2f ms at frame %d; render times: GPU mean %.2f ms, CPU mean %.2f ms" % [
			s["mean_ms"], 1000.0 / maxf(s["mean_ms"], 0.001), s["worst_ms"], int(s["worst_frame"]) + 1, gpu_mean, cpu_mean],
	])


func _quit(code: int) -> void:
	get_tree().quit.call_deferred(code)
