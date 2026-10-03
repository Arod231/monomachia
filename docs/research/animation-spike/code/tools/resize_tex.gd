extends SceneTree
# Downscales the 4K outfit textures to 2K PNGs inside the project, and builds the Rogue recolour.
const SRC := "<scratch>/spike-anim/src4k/"
func _initialize() -> void:
	for n in ["T_Ranger_BaseColor", "T_Ranger_Normal", "T_Ranger_ORM", "T_Regular_Female_Dark_BaseColor", "T_Regular_Female_Normal", "T_Regular_Female_Roughness", "T_Ranger_3_BaseColor"]:
		var img := Image.load_from_file(SRC + n + ".png")
		print(n, " ", img.get_size(), " fmt ", img.get_format())
		if img.get_width() > 2048:
			img.resize(2048, 2048, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/ranger/" + n + ".png")
	quit(0)
