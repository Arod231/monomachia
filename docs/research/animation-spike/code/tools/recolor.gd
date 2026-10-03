extends SceneTree
# Builds the Rogue colourway from T_Ranger_3 (brown/ochre/cream) with soft weights:
# cream cloth -> dark slate, ochre quilting -> dark oxblood, leather -> darker brown, metal untouched.
func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)
func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ranger/T_Ranger_3_BaseColor.png"))
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width(); var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var hue := c.h * 360.0; var s := c.s; var v := c.v
			var warm := 1.0 - _ss(80.0, 110.0, hue) * (1.0 - _ss(300.0, 330.0, hue))
			var cream := (1.0 - _ss(0.26, 0.42, s)) * warm
			var ochre := _ss(0.40, 0.55, s) * _ss(38.0, 46.0, hue) * (1.0 - _ss(68.0, 78.0, hue))
			var leather := Color.from_hsv(c.h, s * 0.8, v * 0.6)
			var slate := Color.from_hsv(0.61, 0.16, v * 0.33)
			var blood := Color.from_hsv(0.985, clamp(s * 0.9, 0.0, 1.0), v * 0.5)
			var o := leather.lerp(blood, ochre)
			o = o.lerp(slate, cream)
			o = c.lerp(o, warm)
			img.set_pixel(x, y, o)
	img.save_png("res://assets/ranger/T_Rogue_BaseColor.png")
	var small := img.duplicate(); small.resize(1024, 1024)
	small.save_png(ProjectSettings.globalize_path("res://../rogue_tex_preview.png"))
	print("done")
	quit(0)
