extends SceneTree
## Bakes each fighter's skin texture, fighters/<id>/<id>_skin.png: the base
## body's skin with the face roughed up to the game's gritty tone, set by the
## look's skin settings (see FighterLook):
## - `eye_shadow`: dark, sunken eye sockets;
## - `eye_band`: a smear of dark paint across the eyes (the Rogue's);
## - `soot`: blotches of soot and grime over the face;
## - `scars`: pale, raised scars with reddened edges, each a segment between
##   two points in fighter space (rest pose), drawn where it crosses the face.
## Only the head's texels change (found from the head mesh's UVs by
## tools/texel_map.gd); the face's position on the head places the effects.
##
## Run: node scripts/godot.mjs script res://tools/bake_skins.gd
## then `node scripts/godot.mjs import`.

const ImportAssets = preload("res://tools/import_assets.gd")
const TexelMap = preload("res://tools/texel_map.gd")

const SOOT: Color = Color(0.09, 0.078, 0.07)
const PAINT: Color = Color(0.05, 0.045, 0.05)


func _initialize() -> void:
	var failed: bool = false
	for id: StringName in FighterLook.IDS:
		var look: FighterLook = load(FighterLook.path_for(id))
		var fighter: FighterModel = FighterLook.instantiate_fighter(id)
		var head: MeshInstance3D = fighter.skeleton.get_node(^"Head")
		var src: Image = Image.load_from_file(ProjectSettings.globalize_path(_source_path(look)))
		src.convert(Image.FORMAT_RGB8)
		var texels: TexelMap = TexelMap.new(src.get_width(), src.get_height())
		texels.add_surface(head.mesh, 0, fighter.skeleton.transform * head.transform, 0)
		texels.dilate(4)
		var eyes: Array[Vector3] = _eye_centres(fighter)
		fighter.free()
		var out: Image = bake(src, texels, eyes, look)
		var out_path: String = "res://fighters/%s/%s_skin.png" % [id, id]
		var err: Error = out.save_png(ProjectSettings.globalize_path(out_path))
		if err != OK:
			printerr("bake_skins: cannot save %s (%s)" % [out_path, error_string(err)])
			failed = true
			continue
		ImportAssets.write_texture_import(out_path, false)
		print("bake_skins: %s -> %s" % [id, out_path])
	quit(1 if failed else 0)


## The body's own skin texture (the base body's material, whatever the
## fighter currently wears).
static func _source_path(look: FighterLook) -> String:
	var body: Node = look.body_scene.instantiate()
	var path: String = ""
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var mat: BaseMaterial3D = mi.mesh.surface_get_material(0) as BaseMaterial3D
		if mat != null and mat.resource_name.begins_with("MI_Superhero"):
			path = mat.albedo_texture.resource_path
	body.free()
	return path


## The centre of each eye in fighter space (the Eyes mesh holds both).
static func _eye_centres(fighter: FighterModel) -> Array[Vector3]:
	var eyes: MeshInstance3D = fighter.skeleton.get_node(^"Eyes")
	var xf: Transform3D = fighter.skeleton.transform * eyes.transform
	var sums: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var counts: Array[int] = [0, 0]
	for v: Vector3 in eyes.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var p: Vector3 = xf * v
		var side: int = 0 if p.x > 0.0 else 1
		sums[side] += p
		counts[side] += 1
	return [sums[0] / counts[0], sums[1] / counts[1]]


## Distance from p to the segment ab, measured across the face (in the
## plane facing forward).
static func _face_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2: Vector2 = Vector2(p.x, p.y)
	var a2: Vector2 = Vector2(a.x, a.y)
	var b2: Vector2 = Vector2(b.x, b.y)
	var ab: Vector2 = b2 - a2
	var t: float = clampf((p2 - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p2 - (a2 + ab * t)).length()


static func bake(src: Image, texels: TexelMap, eyes: Array[Vector3], look: FighterLook) -> Image:
	var data: PackedByteArray = src.get_data()
	var out: PackedByteArray = data.duplicate()
	var blotch: FastNoiseLite = FastNoiseLite.new()
	blotch.seed = 17
	blotch.frequency = 1.0
	blotch.fractal_octaves = 3
	var front_z: float = maxf(eyes[0].z, eyes[1].z)
	for i: int in texels.piece.size():
		if texels.piece[i] == TexelMap.NONE:
			continue
		var p: Vector3 = texels.position[i]
		var nrm: Vector3 = texels.normal[i]
		var o: Color = Color8(data[i * 3], data[i * 3 + 1], data[i * 3 + 2])
		var facing: float = smoothstep(-0.2, 0.4, nrm.z)
		var big: float = blotch.get_noise_3dv(p * 28.0) * 0.5 + 0.5
		var fine: float = blotch.get_noise_3dv(p * 140.0) * 0.5 + 0.5
		# Sunken eye sockets: darker and a little cooler round each eye.
		var socket: float = 0.0
		for e: Vector3 in eyes:
			var d: float = ((p - e) * Vector3(0.8, 1.15, 1.0)).length()
			socket = maxf(socket, 1.0 - smoothstep(0.011, 0.034, d))
		socket *= smoothstep(front_z - 0.06, front_z - 0.02, p.z)
		o = o.lerp(o * Color(0.45, 0.38, 0.4), socket * look.eye_shadow)
		# A band of dark paint across the eyes, ragged at its edges.
		if look.eye_band > 0.0:
			var eye_y: float = (eyes[0].y + eyes[1].y) * 0.5
			var half: float = 0.017 + 0.005 * (big - 0.5)
			var band: float = 1.0 - smoothstep(half - 0.004, half + 0.002, absf(p.y - eye_y))
			band *= 1.0 - smoothstep(0.055, 0.075, absf(p.x))
			band *= smoothstep(front_z - 0.07, front_z - 0.035, p.z) * facing
			o = o.lerp(PAINT, band * look.eye_band * (0.8 + 0.2 * fine))
		# Soot and grime over the face.
		var soot: float = smoothstep(0.5, 0.82, big) * (0.6 + 0.4 * fine) * facing
		o = o.lerp(SOOT, soot * look.soot * 0.55)
		o *= 1.0 - look.soot * 0.08 * (1.0 - fine)
		# Scars.
		for k: int in look.scars.size() / 2:
			var a: Vector3 = look.scars[k * 2]
			var b: Vector3 = look.scars[k * 2 + 1]
			if p.z < minf(a.z, b.z) - 0.025 or nrm.z < 0.0:
				continue
			var d: float = _face_distance(p, a, b) * (0.85 + 0.3 * fine)
			var rim: float = 1.0 - smoothstep(0.0022, 0.0048, d)
			var core: float = 1.0 - smoothstep(0.0009, 0.0021, d)
			o = o.lerp(o * Color(0.82, 0.66, 0.64), rim * 0.4)
			var l: float = o.get_luminance()
			var pale: Color = Color(l, l * 0.93, l * 0.9) * 1.3 + Color(0.05, 0.04, 0.04)
			o = o.lerp(pale, core * 0.8)
		out[i * 3] = clampi(roundi(o.r * 255.0), 0, 255)
		out[i * 3 + 1] = clampi(roundi(o.g * 255.0), 0, 255)
		out[i * 3 + 2] = clampi(roundi(o.b * 255.0), 0, 255)
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGB8, out)
