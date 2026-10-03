extends SceneTree
## The before-and-after video's frames (authored-animation task 14): plays
## every move of a weapon on a real fighter through MoveBench (its defender,
## at the duelling distance, isn't drawn), on the rules' clock, and saves the
## view from the side once per attack frame, <out>/<move>/<frame>.png, with
## <out>/moves.txt listing each move and its frame count.
##
## It is written against what this branch and feature/godot-rebuild share
## (MoveBench, Moves, PoseCheck), so the same file renders the clip version
## here and the procedural version from a feature/godot-rebuild checkout:
##
##   node scripts/move_video.mjs   (renders both and composes the video)
##
## Run by hand in a real window (viewport capture needs one):
##   godot --path <checkout>/game --resolution 800x900 --script <this file> -- \
##     --weapon=katana --fighter=hunter --out=<dir>


func _initialize() -> void:
	_run.call_deferred()


## Loads the renderer from beside this file (an absolute path when another
## checkout runs it) once the tree is up, so the project's autoloads exist.
func _run() -> void:
	var here: String = (get_script() as Script).resource_path.get_base_dir()
	var runner: Node = (load(here.path_join("move_video_frames.gd")) as GDScript).new()
	root.add_child(runner)
	runner.call("run")
