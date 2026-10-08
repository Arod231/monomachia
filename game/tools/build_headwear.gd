extends SceneTree
## Builds the fighters' headwear in code (the free packs have no masks or
## hats), fitted to each fighter's own head:
##
## - head wraps, shells made from the fighter's head mesh: the part of the
##   head the wrap covers, cut along a smooth line, pushed out a few
##   millimetres and smoothed so it drapes over hollows instead of following
##   the lips. A wrap keeps the head's bone weights, so it rides on the Head
##   and Neck bones exactly as the skin under it does:
##   fighters/rogue/face_mask.res, the Rogue's cloth over the nose, mouth
##   and the front of the neck, cut just under the eyes.
## - fighters/materials/worn_cloth.png: a tiling, near-white worn-cloth
##   texture (weave, blotches, grime) that the headwear materials tint.
##
## The Hunter's tricorn and scarf, once built here, are modelled in Blender
## (milestone-1 task 46: scripts/blender/build_headwear.py, from the fit that
## tools/export_headwear_fit.gd measures with the sizes and regions below).
##
## Run: node scripts/godot.mjs script res://tools/build_headwear.gd
## (after tools/cut_heads.gd; rerun when a head, the hair or the sizes below
## change), then `node scripts/godot.mjs import`.

const ImportAssets = preload("res://tools/import_assets.gd")

const CLOTH_TEXTURE: String = "res://fighters/materials/worn_cloth.png"
const CLOTH_MATERIAL: String = "res://fighters/materials/headwear_cloth.tres"

## Size of one repeat of the cloth texture on the headwear, in metres.
const TILE: float = 0.12

## Wraps: [fighter, output, region, distance from the skin in metres]. The
## region is where a wrap covers (see _face_region and _neck_region).
const WRAPS: Array[Array] = [
	[&"rogue", "res://fighters/rogue/face_mask.res", &"face", 0.0035],
]
## Face mask: the top edge, below the eyes' centre at the nose, rising toward
## the cheekbones; it covers the front of the head and neck back to this far
## behind the head bone (about the ears; the hood covers the rest).
const MASK_BELOW_EYES: float = 0.021
const MASK_EDGE_RISE: float = 0.18
const MASK_BACK: float = 0.005
## The Hunter's neck scarf (measured for Blender): the top edge, this far above the head bone at its pivot,
## sloping down toward the front (under the jaw) and up at the nape.
const SCARF_TOP: float = -0.01
const SCARF_SLOPE: float = 0.25
## How far the drape fills hollows (smoothing iterations).
const DRAPE_ITERATIONS: int = 30

## The Hunter's tricorn sizes (measured for Blender), in metres; the brim
## grew by 1.15 with the taller bodies (KE task 3).
const HAT_BAND_ABOVE_BROWS: float = 0.014
const HAT_FORWARD_TILT_DEG: float = 9.0
const HAT_CLEARANCE: float = 0.007
const HAT_BRIM: float = 0.083
const HAT_FRONT_BRIM: float = 0.098
const HAT_BAND_HEIGHT: float = 0.02


func _initialize() -> void:
	var failed: bool = false
	failed = not _save_texture(cloth_texture(256)) or failed
	for w: Array in WRAPS:
		var fighter: FighterModel = FighterLook.instantiate_fighter(w[0])
		failed = not _save(build_wrap(fighter, w[2], w[3]), w[1]) or failed
		fighter.free()
	quit(1 if failed else 0)


func _save(mesh: ArrayMesh, path: String) -> bool:
	var err: Error = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("build_headwear: cannot save %s (%s)" % [path, error_string(err)])
		return false
	var tris: int = 0
	for s: int in mesh.get_surface_count():
		tris += mesh.surface_get_array_index_len(s) / 3
	print("build_headwear: %s, %d triangles" % [path, tris])
	return true


func _save_texture(img: Image) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CLOTH_TEXTURE.get_base_dir()))
	var err: Error = img.save_png(ProjectSettings.globalize_path(CLOTH_TEXTURE))
	if err != OK:
		printerr("build_headwear: cannot save %s (%s)" % [CLOTH_TEXTURE, error_string(err)])
		return false
	ImportAssets.write_texture_import(CLOTH_TEXTURE, false)
	print("build_headwear: %s" % CLOTH_TEXTURE)
	return true


# --- cloth texture ---------------------------------------------------------

## A tiling worn-cloth texture, mean value about 0.9: a fine plain weave,
## soft blotches and darker grime.
static func cloth_texture(size: int) -> Image:
	var blotch: FastNoiseLite = FastNoiseLite.new()
	blotch.seed = 5
	blotch.frequency = 0.02
	blotch.fractal_octaves = 4
	var grime: FastNoiseLite = FastNoiseLite.new()
	grime.seed = 9
	grime.frequency = 0.025
	grime.fractal_octaves = 3
	var b: Image = blotch.get_seamless_image(size, size)
	var g: Image = grime.get_seamless_image(size, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var threads: float = size / 4.0
	for y: int in size:
		for x: int in size:
			var warp: float = 0.5 + 0.5 * sin(TAU * x / size * threads)
			var weft: float = 0.5 + 0.5 * sin(TAU * y / size * threads)
			var over: bool = (x / 4 + y / 4) % 2 == 0
			var weave: float = lerpf(warp, weft, 1.0 if over else 0.0)
			var v: float = 0.86 + 0.1 * weave
			v *= 0.92 + 0.16 * b.get_pixel(x, y).r
			v *= 1.0 - 0.14 * smoothstep(0.4, 0.9, g.get_pixel(x, y).r)
			img.set_pixel(x, y, Color(v, v * 0.985, v * 0.97))
	return img


# --- head wraps -------------------------------------------------------------

## The eyes' centre (between the two eyes) in fighter space.
static func _eyes_centre(fighter: FighterModel) -> Vector3:
	var eyes: MeshInstance3D = fighter.skeleton.get_node(^"Eyes")
	var aabb: AABB = eyes.get_aabb()
	return fighter.skeleton.transform * eyes.transform * aabb.get_center()


## Where the face mask covers: < 0 inside.
static func _face_region(p: Vector3, eyes: Vector3, head_bone: Vector3) -> float:
	var top: float = eyes.y - MASK_BELOW_EYES + MASK_EDGE_RISE * maxf(0.0, absf(p.x - eyes.x) - 0.022)
	return maxf(p.y - top, (head_bone.z - MASK_BACK) - p.z)


## Where the neck scarf covers: < 0 inside.
static func _neck_region(p: Vector3, _eyes: Vector3, head_bone: Vector3) -> float:
	return p.y - (head_bone.y + SCARF_TOP - SCARF_SLOPE * (p.z - head_bone.z))


## A wrap over the region named `region` ("face" or "neck"), `offset` metres
## off the skin.
static func build_wrap(fighter: FighterModel, region: StringName, offset: float) -> ArrayMesh:
	var sk: Skeleton3D = fighter.skeleton
	var head: MeshInstance3D = sk.get_node(^"Head")
	var to_fighter: Transform3D = sk.transform * head.transform
	var eyes: Vector3 = _eyes_centre(fighter)
	var head_bone: Vector3 = sk.transform * sk.get_bone_global_rest(sk.find_bone(&"Head")).origin
	var arrays: Array = head.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per: int = bones.size() / verts.size()
	# Weld the head's vertices by position (UV seams split them).
	var weld: PackedInt32Array = PackedInt32Array()
	weld.resize(verts.size())
	var by_key: Dictionary[Vector3i, int] = {}
	var pos: PackedVector3Array = PackedVector3Array()
	var nor: PackedVector3Array = PackedVector3Array()
	var first: PackedInt32Array = PackedInt32Array()
	for i: int in verts.size():
		var p: Vector3 = to_fighter * verts[i]
		var key: Vector3i = Vector3i((p * 20000.0).round())
		if not by_key.has(key):
			by_key[key] = pos.size()
			pos.append(p)
			nor.append(Vector3.ZERO)
			first.append(i)
		weld[i] = by_key[key]
		nor[weld[i]] += to_fighter.basis * norms[i]
	for k: int in nor.size():
		nor[k] = nor[k].normalized()
	# Inside the mask where f < 0.
	var f: PackedFloat32Array = PackedFloat32Array()
	f.resize(pos.size())
	for k: int in pos.size():
		var p: Vector3 = pos[k]
		f[k] = _face_region(p, eyes, head_bone) if region == &"face" else _neck_region(p, eyes, head_bone)
	# Triangles with a vertex inside.
	var tris: PackedInt32Array = PackedInt32Array()
	var neighbours: Dictionary[int, Array] = {}
	for t: int in index.size() / 3:
		var w: Array[int] = [weld[index[t * 3]], weld[index[t * 3 + 1]], weld[index[t * 3 + 2]]]
		if f[w[0]] >= 0.0 and f[w[1]] >= 0.0 and f[w[2]] >= 0.0:
			continue
		if w[0] == w[1] or w[1] == w[2] or w[0] == w[2]:
			continue
		for a: int in 3:
			tris.append(w[a])
			for b: int in 3:
				if a != b:
					if not neighbours.has(w[a]):
						neighbours[w[a]] = []
					if not neighbours[w[a]].has(w[b]):
						neighbours[w[a]].append(w[b])
	# Pull outside vertices onto the cut line, between them and their
	# inside neighbours, so the edge runs smoothly instead of along triangles.
	var skin_pos: Dictionary[int, Vector3] = {}
	for k: int in neighbours:
		if f[k] < 0.0:
			skin_pos[k] = pos[k]
			continue
		var sum: Vector3 = Vector3.ZERO
		var count: int = 0
		for j: int in neighbours[k]:
			if f[j] < 0.0:
				sum += pos[j] + (pos[k] - pos[j]) * (f[j] / (f[j] - f[k]))
				count += 1
		skin_pos[k] = sum / count if count > 0 else pos[k]
	# Drape: a smoothed copy of the surface; the shell sits on whichever is
	# farther out along the normal (the skin or the smoothed surface), so it
	# spans the hollows round the nose and lips.
	var smooth: Dictionary[int, Vector3] = skin_pos.duplicate()
	for it: int in DRAPE_ITERATIONS:
		var next: Dictionary[int, Vector3] = {}
		for k: int in smooth:
			var avg: Vector3 = Vector3.ZERO
			for j: int in neighbours[k]:
				avg += smooth[j]
			next[k] = smooth[k].lerp(avg / neighbours[k].size(), 0.5)
		smooth = next
	var shell: Dictionary[int, Vector3] = {}
	for k: int in skin_pos:
		var lift: float = maxf(0.0, (smooth[k] - skin_pos[k]).dot(nor[k]))
		shell[k] = skin_pos[k] + nor[k] * (offset + lift)
	# Build the surface: one vertex per welded position, with the head's
	# weights, and cylindrical UVs in metres around the head.
	var remap: Dictionary[int, int] = {}
	var out_v: PackedVector3Array = PackedVector3Array()
	var out_n: PackedVector3Array = PackedVector3Array()
	var out_uv: PackedVector2Array = PackedVector2Array()
	var out_b: PackedInt32Array = PackedInt32Array()
	var out_w: PackedFloat32Array = PackedFloat32Array()
	var back: Transform3D = to_fighter.affine_inverse()
	for k: int in shell:
		remap[k] = out_v.size()
		out_v.append(back * shell[k])
		out_n.append((back.basis * nor[k]).normalized())
		var rel: Vector3 = shell[k] - head_bone
		out_uv.append(Vector2(atan2(rel.x, rel.z) * 0.09 / TILE, -shell[k].y / TILE))
		for j: int in per:
			out_b.append(bones[first[k] * per + j])
			out_w.append(weights[first[k] * per + j])
	var out_i: PackedInt32Array = PackedInt32Array()
	for t: int in tris.size():
		out_i.append(remap[tris[t]])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_v
	out[Mesh.ARRAY_NORMAL] = out_n
	out[Mesh.ARRAY_TEX_UV] = out_uv
	out[Mesh.ARRAY_BONES] = out_b
	out[Mesh.ARRAY_WEIGHTS] = out_w
	out[Mesh.ARRAY_INDEX] = out_i
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {},
		Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
	mesh.surface_set_name(0, String(region))
	mesh.surface_set_material(0, load(CLOTH_MATERIAL))
	return mesh


# --- the Hunter's head (for export_headwear_fit.gd) --------------------------

## Every vertex of the head and the hair, in fighter space.
static func _head_points(fighter: FighterModel) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array()
	var sk: Skeleton3D = fighter.skeleton
	for mi_name: StringName in [&"Head", &"Hair_Buzzed", &"Eyebrows"]:
		var mi: MeshInstance3D = sk.get_node_or_null(NodePath(String(mi_name)))
		if mi == null:
			continue
		var xf: Transform3D = sk.transform * mi.transform
		for s: int in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				pts.append(xf * v)
	return pts
