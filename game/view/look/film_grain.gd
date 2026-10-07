class_name FilmGrain
extends CanvasLayer
## Light film grain over the 3D view (milestone-1 task 43; the look test's,
## task 30; spec story 135): a faint, moving noise on a full-screen rect, on
## a canvas layer under the HUD and the menus (LAYER), so the text stays
## clean. One covers every view of a split screen.

## Over SplitView's halves (layer 1), under the HUD (5) and the menus.
const LAYER: int = 2
## How strongly the grain shows (its alpha).
const AMOUNT: float = 0.035

const SHADER_CODE: String = """shader_type canvas_item;
uniform float amount = 0.035;
void fragment() {
	float n = fract(sin(dot(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 17.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(n), amount);
}
"""

static var _shader: Shader

var rect: ColorRect


func _init() -> void:
	name = "FilmGrain"
	layer = LAYER
	rect = ColorRect.new()
	rect.name = "Grain"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter(&"amount", AMOUNT)
	rect.material = mat
	add_child(rect)
