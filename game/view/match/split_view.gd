class_name SplitView
extends CanvasLayer
## Versus split screen (task 23.6): two side-by-side views of the match's
## one world, player 1 on the left and player 2 on the right, with a thin
## divider between. MatchView builds it for a Versus match and puts a
## CameraRig in each half; the root viewport then has no camera and draws no
## 3D under the halves. Each half keeps the single view's vertical field of
## view at half the width (the demo's split did the same), and the HUD, on
## a higher layer, stays one overlay over both until 23.7.
##
## Neither half listens: MatchAudio's one listener, in the root viewport,
## hears the 3D sound (two listeners on one world would play every sound
## twice). Both halves are in GraphicsApplier.VIEWPORTS_GROUP, so the
## graphics preset reaches them as it reaches the root viewport.

## Under the HUD (5) and the menus (10).
const LAYER: int = 1
const DIVIDER_WIDTH: float = 2.0

## The halves, left then right: each SubViewportContainer and its viewport.
var containers: Array[SubViewportContainer] = []
var viewports: Array[SubViewport] = []
var divider: ColorRect


func _init() -> void:
	name = "SplitView"
	layer = LAYER
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Halves"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i: int in 2:
		if i == 1:
			divider = ColorRect.new()
			divider.name = "Divider"
			divider.color = UiPalette.INK
			divider.custom_minimum_size = Vector2(DIVIDER_WIDTH, 0.0)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(divider)
		var c: SubViewportContainer = SubViewportContainer.new()
		c.name = "Half%d" % (i + 1)
		c.stretch = true
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(c)
		var vp: SubViewport = SubViewport.new()
		vp.name = "View%d" % (i + 1)
		vp.own_world_3d = false
		vp.audio_listener_enable_3d = false
		vp.handle_input_locally = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.add_to_group(GraphicsApplier.VIEWPORTS_GROUP)
		c.add_child(vp)
		containers.append(c)
		viewports.append(vp)


## Both halves draw `world` (the match's).
func share_world(world: World3D) -> void:
	for vp: SubViewport in viewports:
		vp.world_3d = world


## Applies a graphics preset's anti-aliasing and render scale to both halves.
func apply_preset(preset: GraphicsPreset) -> void:
	for vp: SubViewport in viewports:
		GraphicsApplier.apply_to_viewport(preset, vp)
