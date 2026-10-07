extends SceneTree
## Saves the UI theme UiTheme.build() makes as the project theme
## (UiTheme.PATH, ui/theme/lacquer_gold.tres). Run it after changing
## UiPalette, the fonts or the builder; test_ui_theme.gd fails until it has
## run.
##
## usage: node scripts/godot.mjs script res://tools/build_ui_theme.gd


func _initialize() -> void:
	var err: Error = ResourceSaver.save(UiTheme.build(), UiTheme.PATH)
	if err != OK:
		push_error("could not save %s: %s" % [UiTheme.PATH, error_string(err)])
	else:
		print("saved ", UiTheme.PATH)
	quit(0 if err == OK else 1)
