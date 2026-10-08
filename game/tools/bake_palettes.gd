extends SceneTree
## Bakes each fighter palette's outfit texture from the Ranger outfit's
## T_Ranger_3 base colour: <palette>_outfit.png next to each palette, every
## garment recoloured to the palette (see FighterPalette), then worn: the
## outfit's ambient occlusion multiplied in, dust rising from the ground up
## the boots and trouser hems, scuffed knees, grimy cuffs and hems, pale
## scuffs on the edges of straps and leather, and blotchy grime all over.
## (The toon look ignores roughness, so the outfit needs no roughness map.)
##
## Which garment a texel belongs to comes from the fighter's own outfit
## meshes (their UVs, rasterised by tools/texel_map.gd), so the hood, vest,
## sleeves and trousers can each take their own colour; the material (cloth,
## trim, leather, metal) comes from the source colour. Wear is placed by the
## texel's position on the body in rest pose and broken up with 3D noise, so
## it is continuous across UV seams.
##
## Run: node scripts/godot.mjs script res://tools/bake_palettes.gd
## then `node scripts/godot.mjs import`. Takes about a minute.
##
## Palettes are found through the fighter looks (FighterLook.IDS). A palette
## dyed in Blender (outfit_maps, the Hunter's since milestone-1 task 45) is
## skipped: scripts/blender/dye_outfit.py makes its maps. A new
## palette's .tres can be written without its outfit_albedo first; point it
## at the baked PNG once the PNG has been imported.

const ImportAssets = preload("res://tools/import_assets.gd")
const TexelMap = preload("res://tools/texel_map.gd")

const SOURCE: String = "res://assets/quaternius/outfits/T_Ranger_3_BaseColor.png"
const SOURCE_ORM: String = "res://assets/quaternius/outfits/T_Ranger_ORM.png"
const SOURCE_NORMAL: String = "res://assets/quaternius/outfits/T_Ranger_Normal.png"

## Garments, from the outfit mesh names (the first match wins).
enum Piece { HOOD, BODY, BELT, ARMS, BRACER, LEGS, BOOTS, PAULDRON }
const PIECE_NAMES: Array[Array] = [
	["_Head_Hood", Piece.HOOD], ["_Acc_Pauldron", Piece.PAULDRON], ["_Body_Belt", Piece.BELT],
	["_Arms_Bracer", Piece.BRACER], ["_Body", Piece.BODY], ["_Arms", Piece.ARMS],
	["_Legs", Piece.LEGS], ["_Feet", Piece.BOOTS],
]
## Palette colours, one per garment and material.
enum Slot { HOOD, VEST, SHIRT, TRIM, SLEEVE, TROUSER, LEATHER, BOOT, METAL }
enum Mat { CLOTH, TRIM, LEATHER }

## The colour dust and dirt tend to.
const DIRT: Color = Color(0.21, 0.18, 0.14)


func _initialize() -> void:
	var t0: int = Time.get_ticks_msec()
	var src: Image = _load(SOURCE)
	var size: Vector2i = src.get_size()
	var orm: Image = _load(SOURCE_ORM)
	var normal_map: Image = _load(SOURCE_NORMAL)
	var failed: bool = false
	orm.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	normal_map.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	var materials: Dictionary = classify(src)
	for id: StringName in FighterLook.IDS:
		var look: FighterLook = load(FighterLook.path_for(id))
		var fighter: FighterModel = FighterLook.instantiate_fighter(id)
		var texels: TexelMap = map_outfit(fighter, size)
		var landmarks: Dictionary = _landmarks(fighter)
		fighter.free()
		print("bake_palettes: %s outfit covers %.0f%% of the texture" % [id, texels.coverage() * 100.0])
		for p: FighterPalette in look.palettes:
			if p.outfit_maps != null:
				print("bake_palettes: %s (%s) is dyed in Blender; skipped" % [id, p.display_name])
				continue
			var out_path: String = p.resource_path.get_basename() + "_outfit.png"
			var img: Image = recolour(src, orm, normal_map, materials, texels, landmarks, p)
			var err: Error = img.save_png(ProjectSettings.globalize_path(out_path))
			if err != OK:
				printerr("bake_palettes: cannot save %s (%s)" % [out_path, error_string(err)])
				failed = true
				continue
			ImportAssets.write_texture_import(out_path, false)
			print("bake_palettes: %s (%s) -> %s" % [id, p.display_name, out_path])
	print("bake_palettes: done in %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(1 if failed else 0)


static func _load(path: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGB8)
	return img


## The garment a mesh belongs to, from its name, or -1.
static func piece_of(mesh_name: String) -> int:
	for entry: Array in PIECE_NAMES:
		if mesh_name.contains(entry[0]):
			return entry[1]
	return -1


## Rasterises the fighter's outfit surfaces into a texel map.
static func map_outfit(fighter: FighterModel, size: Vector2i) -> TexelMap:
	var texels: TexelMap = TexelMap.new(size.x, size.y)
	for node: Node in fighter.skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var piece: int = piece_of(String(mi.name))
		if piece < 0:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat != null and StringName(mat.resource_name) == fighter.look.outfit_material:
				texels.add_surface(mi.mesh, s, fighter.skeleton.transform * mi.transform, piece)
	texels.dilate(6)
	return texels


## Rest-pose positions the wear is placed around.
static func _landmarks(fighter: FighterModel) -> Dictionary:
	var sk: Skeleton3D = fighter.skeleton
	var at: Callable = func(bone: StringName) -> Vector3:
		return sk.transform * sk.get_bone_global_rest(sk.find_bone(bone)).origin
	return {
		"hands": [at.call(&"LeftHand"), at.call(&"RightHand")],
		"knees": [at.call(&"LeftLowerLeg"), at.call(&"RightLowerLeg")],
		"hips": at.call(&"Hips"),
	}


## Per-texel material weights of the source, by colour:
## - metal: the cool hues (the blue-grey metal and its glow);
## - cloth: unsaturated warm tones;
## - trim: the saturated ochre quilting (hue about 47-50). The leather is a
##   darker, redder orange (hue about 36-42, value about 0.12);
## - leather: the rest.
static func classify(src: Image) -> Dictionary:
	var data: PackedByteArray = src.get_data()
	var n: int = src.get_width() * src.get_height()
	var cloth: PackedFloat32Array = PackedFloat32Array()
	var trim: PackedFloat32Array = PackedFloat32Array()
	var warm: PackedFloat32Array = PackedFloat32Array()
	var value: PackedFloat32Array = PackedFloat32Array()
	for arr: PackedFloat32Array in [cloth, trim, warm, value]:
		arr.resize(n)
	for i: int in n:
		var c: Color = Color8(data[i * 3], data[i * 3 + 1], data[i * 3 + 2])
		var hue: float = c.h * 360.0
		var w: float = 1.0 - smoothstep(80.0, 110.0, hue) * (1.0 - smoothstep(300.0, 330.0, hue))
		cloth[i] = (1.0 - smoothstep(0.26, 0.42, c.s)) * w
		trim[i] = smoothstep(0.55, 0.7, c.s) * smoothstep(42.5, 45.5, hue) * (1.0 - smoothstep(68.0, 78.0, hue)) * smoothstep(0.15, 0.2, c.v) * w
		warm[i] = w
		value[i] = c.v
	return {"cloth": cloth, "trim": trim, "warm": warm, "value": value}


## The palette slot a garment's material takes.
static func slot_of(piece: int, mat: int) -> int:
	match piece:
		Piece.HOOD:
			return Slot.HOOD
		Piece.BODY:
			return [Slot.SHIRT, Slot.TRIM, Slot.VEST][mat]
		Piece.ARMS:
			return [Slot.SLEEVE, Slot.TRIM, Slot.LEATHER][mat]
		Piece.LEGS:
			return Slot.TROUSER if mat != Mat.TRIM else Slot.TRIM
		Piece.BOOTS:
			return Slot.BOOT
	return Slot.LEATHER if mat != Mat.TRIM else Slot.TRIM


static func slot_colors(p: FighterPalette) -> Array[Color]:
	return [p.hood_color, p.vest_color, p.shirt_color, p.trim_color, p.sleeve_color,
		p.trouser_color, p.leather_color, p.boot_color, p.metal_color]


## The reference values: the source value each garment's material is
## pinned to, so that there it takes its slot's colour exactly. One per
## garment and material (index piece * 3 + material), because the source
## paints them at different values (cream straps next to dark gloves, say),
## plus one for all the metal (the last). Each is the 75th percentile of the
## source's value over those texels, which lands on the material itself
## rather than its darker seams.
static func slot_references(materials: Dictionary, texels: TexelMap) -> PackedFloat32Array:
	var hists: Array[PackedFloat64Array] = []
	for s: int in Piece.size() * 3 + 1:
		var h: PackedFloat64Array = PackedFloat64Array()
		h.resize(256)
		hists.append(h)
	var cloth: PackedFloat32Array = materials.cloth
	var trim: PackedFloat32Array = materials.trim
	var warm: PackedFloat32Array = materials.warm
	var value: PackedFloat32Array = materials.value
	for i: int in value.size():
		var piece: int = texels.piece[i]
		if piece == TexelMap.NONE:
			continue
		var bin: int = clampi(int(value[i] * 255.0), 0, 255)
		var w: Array[float] = _weights(cloth[i], trim[i], warm[i])
		for m: int in 3:
			hists[piece * 3 + m][bin] += w[m]
		hists[Piece.size() * 3][bin] += w[3]
	var refs: PackedFloat32Array = PackedFloat32Array()
	for h: PackedFloat64Array in hists:
		refs.append(maxf(_percentile(h, 0.75), 0.02))
	return refs


## Cloth, trim, leather and metal weights of a texel (they sum to 1).
static func _weights(cl: float, tr: float, w: float) -> Array[float]:
	var cloth: float = cl
	var trim: float = tr * (1.0 - cl)
	var leather: float = maxf(0.0, w - cloth - trim)
	return [cloth, trim, leather, 1.0 - w]


## The value (0..1) below which `fraction` of a 256-bin histogram lies.
static func _percentile(hist: PackedFloat64Array, fraction: float) -> float:
	var total: float = 0.0
	for h: float in hist:
		total += h
	var acc: float = 0.0
	for b: int in hist.size():
		acc += hist[b]
		if acc >= total * fraction:
			return (b + 0.5) / 256.0
	return 1.0


## A colour in the slot's colour, as bright relative to `target` as `v` is
## to the slot's reference value. When a dark source is lifted far (a brown
## hood dyed bone white), its contrast is compressed so the painted detail
## doesn't turn into harsh noise.
static func shade(target: Color, v: float, ref: float) -> Color:
	var ratio: float = v / ref
	var gamma: float = 1.0
	if target.v > ref:
		gamma = clampf(sqrt(ref / target.v), 0.45, 1.0)
	var value: float = clampf(target.v * pow(ratio, gamma), 0.0, 1.0)
	# Highlights lose a little saturation, shadows keep it, as on real dye.
	var sat: float = clampf(target.s * (1.15 - 0.15 * ratio), 0.0, 1.0)
	return Color.from_hsv(target.h, sat, value)


static func _noise(seed_value: int, octaves: int) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	n.fractal_octaves = octaves
	return n


static func recolour(src: Image, orm: Image, normal_map: Image, materials: Dictionary, texels: TexelMap,
		landmarks: Dictionary, p: FighterPalette) -> Image:
	var data: PackedByteArray = src.get_data()
	var orm_data: PackedByteArray = orm.get_data()
	var nrm: PackedByteArray = normal_map.get_data()
	var out: PackedByteArray = data.duplicate()
	var cloth: PackedFloat32Array = materials.cloth
	var trim: PackedFloat32Array = materials.trim
	var warm: PackedFloat32Array = materials.warm
	var value: PackedFloat32Array = materials.value
	var refs: PackedFloat32Array = slot_references(materials, texels)
	var colors: Array[Color] = slot_colors(p)
	var hands: Array = landmarks.hands
	var knees: Array = landmarks.knees
	var blotch: FastNoiseLite = _noise(11, 3)
	var grain: FastNoiseLite = _noise(23, 2)
	var wear: float = p.wear
	for i: int in value.size():
		var piece: int = texels.piece[i]
		if piece == TexelMap.NONE:
			continue
		var v: float = value[i]
		var w: Array[float] = _weights(cloth[i], trim[i], warm[i])
		var o: Color = Color(0, 0, 0)
		for m: int in 3:
			if w[m] > 0.0:
				var slot: int = slot_of(piece, m)
				o += shade(colors[slot], v, refs[piece * 3 + m]) * w[m]
		if w[3] > 0.0:
			var src_c: Color = Color8(data[i * 3], data[i * 3 + 1], data[i * 3 + 2])
			o += shade(colors[Slot.METAL], src_c.get_luminance(), refs[Piece.size() * 3]) * w[3]
		var pos: Vector3 = texels.position[i]
		var nor: Vector3 = texels.normal[i]
		var leather: float = w[2] + (w[0] + w[1]) * (1.0 if piece == Piece.BOOTS or piece == Piece.BELT else 0.0)
		# Ambient occlusion from the outfit's ORM map.
		var ao: float = orm_data[i * 3] / 255.0
		o *= lerpf(1.0, ao, 0.85)
		var big: float = blotch.get_noise_3dv(pos * 5.0) * 0.5 + 0.5
		var fine: float = grain.get_noise_3dv(pos * 40.0) * 0.5 + 0.5
		# Dust rising from the ground: boots and trouser hems.
		var dirt: float = 0.0
		if piece == Piece.BOOTS:
			dirt = 1.0 - smoothstep(0.02, 0.5, pos.y)
		elif piece == Piece.LEGS:
			dirt = 0.55 * (1.0 - smoothstep(0.38, 0.7, pos.y))
		# Scuffed knees.
		if piece == Piece.LEGS:
			for k: Vector3 in knees:
				var d: float = (pos - (k + Vector3(0.0, 0.0, 0.06))).length()
				dirt = maxf(dirt, 0.75 * (1.0 - smoothstep(0.03, 0.11, d)) * smoothstep(-0.2, 0.5, nor.z))
		# Grimy cuffs and gloves.
		if piece == Piece.ARMS or piece == Piece.BRACER:
			for h: Vector3 in hands:
				dirt = maxf(dirt, 0.6 * (1.0 - smoothstep(0.05, 0.2, (pos - h).length())))
		# Hems of the vest and shirt.
		if piece == Piece.BODY:
			dirt = maxf(dirt, 0.45 * (1.0 - smoothstep(landmarks.hips.y - 0.02, landmarks.hips.y + 0.12, pos.y)))
		dirt *= wear * (0.45 + 0.75 * big) * (0.8 + 0.4 * fine)
		o = o.lerp(DIRT.lerp(o * 0.6, 0.35), clampf(dirt, 0.0, 0.85))
		# Pale scuffs on the edges of straps and leather, where the normal
		# map bevels.
		if leather > 0.2:
			var nz: float = nrm[i * 3 + 2] / 127.5 - 1.0
			var edge: float = smoothstep(0.06, 0.32, 1.0 - nz) * smoothstep(0.35, 0.75, fine)
			var lum: float = o.get_luminance()
			var scuff: Color = Color(lum, lum, lum).lerp(o, 0.4) * 1.7 + Color(0.05, 0.045, 0.04)
			o = o.lerp(scuff, clampf(edge * leather * wear * 0.55, 0.0, 1.0))
		# Blotchy grime and a fine grain over everything.
		o *= 1.0 - wear * 0.22 * smoothstep(0.45, 0.85, big)
		o *= 0.95 + 0.1 * fine
		out[i * 3] = clampi(roundi(o.r * 255.0), 0, 255)
		out[i * 3 + 1] = clampi(roundi(o.g * 255.0), 0, 255)
		out[i * 3 + 2] = clampi(roundi(o.b * 255.0), 0, 255)
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGB8, out)
