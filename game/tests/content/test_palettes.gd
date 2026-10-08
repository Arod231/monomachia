extends GutTest
## A fighter's two palettes must tell a mirror match apart from every side,
## not just from the front: palette B has to change a large area that shows
## from the front, the back and the side (the hood, sleeves and trousers),
## not only a trim that the vest hides from behind.
##
## The tests run headless, where nothing can be rendered on the GPU, so this
## renders each fighter here in software: its assembled meshes in rest pose,
## projected flat (orthographic) from each side with a depth buffer, each
## pixel coloured by its material's base colour and texture, unlit. That is
## what the eye compares between two fighters across a match: the colour
## of each visible patch.

## Pixel size of the software render, in metres.
const PIXEL: float = 0.02
## Mean colour difference between palettes A and B over the fighter's
## visible pixels, from each side, at the least: CIELAB delta E (1976),
## where about 2 is just noticeable and 10 or more is a plainly different
## colour. The first palettes came to about 6 for the Rogue from behind
## (they only swapped her chest trim and hair, which the art review found
## too alike), and 12 to 14 for the Hunter, which it found clearly apart.
const MIN_DIFFERENCE: float = 12.0
## Mean lightness difference (CIELAB L*) between the Hunter's crimson and
## indigo over the pixels the dye changes (a colour difference of DYED_DELTA_E
## or more), from each side, at the least, so the sides read apart in grey
## too (story 143: the black-and-white mode can come later without
## re-dyeing). The mood board's dyes differ by 18.5 in L*. The skin, hat,
## leather, boots and metal are the same on both sides, so they are left out,
## and the dyed pixels must cover MIN_DYED_SHARE of the silhouette. The
## painted shading darkens both dyes, so the dyed cloth came to 11.5 to 11.8
## (a plain step in grey; 2 is just noticeable) over 63 to 73% of him.
const MIN_GREY_DIFFERENCE: float = 10.0
const DYED_DELTA_E: float = 10.0
const MIN_DYED_SHARE: float = 0.4
## The views: the direction the "camera" looks along.
const VIEWS: Dictionary[String, Vector3] = {
	"front": Vector3(0, 0, -1), "back": Vector3(0, 0, 1), "side": Vector3(1, 0, 0),
}

var _images: Dictionary[String, Image] = {}


func test_palettes_differ_over_a_large_area_from_every_side() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = FighterLook.instantiate_fighter(id)
		f.autoplay_idle = false
		add_child_autofree(f)
		var tris: Array[Dictionary] = _triangles(f)
		for view: String in VIEWS:
			var hits: Dictionary = _rasterise(tris, VIEWS[view])
			f.apply_palette(0)
			var a: PackedColorArray = _shade(tris, hits)
			f.apply_palette(1)
			var b: PackedColorArray = _shade(tris, hits)
			var total: float = 0.0
			for i: int in a.size():
				total += _lab(a[i]).distance_to(_lab(b[i]))
			var mean: float = total / maxf(1.0, a.size())
			gut.p("%s palettes A and B, %s: mean difference %.3f over %d pixels" % [id, view, mean, a.size()])
			assert_gt(a.size(), 400, "%s seen from the %s covers the render" % [id, view])
			assert_gt(mean, MIN_DIFFERENCE, "%s's palettes differ seen from the %s" % [id, view])


func test_the_hunters_crimson_and_indigo_read_apart_in_grey_from_every_side() -> void:
	var f: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	f.autoplay_idle = false
	add_child_autofree(f)
	var tris: Array[Dictionary] = _triangles(f)
	for view: String in VIEWS:
		var hits: Dictionary = _rasterise(tris, VIEWS[view])
		f.apply_palette(0)
		var a: PackedColorArray = _shade(tris, hits)
		f.apply_palette(1)
		var b: PackedColorArray = _shade(tris, hits)
		var total: float = 0.0
		var dyed: int = 0
		for i: int in a.size():
			var la: Vector3 = _lab(a[i])
			var lb: Vector3 = _lab(b[i])
			if la.distance_to(lb) >= DYED_DELTA_E:
				total += absf(la.x - lb.x)
				dyed += 1
		var mean: float = total / maxf(1.0, dyed)
		var share: float = float(dyed) / maxf(1.0, a.size())
		gut.p("hunter crimson and indigo, %s: mean lightness difference %.3f over the %.0f%% dyed" % [view, mean, share * 100.0])
		assert_gt(a.size(), 400, "the Hunter seen from the %s covers the render" % view)
		assert_gt(share, MIN_DYED_SHARE, "the dye covers the Hunter seen from the %s" % view)
		assert_gt(mean, MIN_GREY_DIFFERENCE, "crimson and indigo read apart in grey from the %s" % view)


## Every triangle of the fighter's meshes in fighter space (rest pose), with
## its UVs and the mesh surface it belongs to.
func _triangles(f: FighterModel) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sk: Skeleton3D = f.skeleton
	for node: Node in f.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var xf: Transform3D = sk.transform * mi.transform
		var attachment: BoneAttachment3D = mi.get_parent() as BoneAttachment3D
		if attachment != null:
			xf = sk.transform * sk.get_bone_global_rest(sk.find_bone(attachment.bone_name)) * mi.transform
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t: int in index.size() / 3:
				var ids: Array[int] = [index[t * 3], index[t * 3 + 1], index[t * 3 + 2]]
				out.append({
					"p": [xf * verts[ids[0]], xf * verts[ids[1]], xf * verts[ids[2]]],
					"uv": [uvs[ids[0]], uvs[ids[1]], uvs[ids[2]]] if not uvs.is_empty() else [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
					"mesh": mi, "surface": s,
				})
	return out


## The nearest triangle at each pixel and the barycentric weights there:
## {pixel index: [triangle index, w0, w1]}.
func _rasterise(tris: Array[Dictionary], look: Vector3) -> Dictionary:
	var right: Vector3 = Vector3.UP.cross(look).normalized()
	var w: int = int(2.2 / PIXEL)
	var h: int = int(2.0 / PIXEL)
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(w * h)
	depth.fill(INF)
	var hits: Dictionary = {}
	for t: int in tris.size():
		var p: Array = tris[t].p
		var s: Array[Vector2] = []
		var d: Array[float] = []
		for v: Vector3 in p:
			s.append(Vector2((v.dot(right) + 1.1) / PIXEL, (2.0 - v.y) / PIXEL))
			d.append(v.dot(look))
		var area: float = (s[1] - s[0]).cross(s[2] - s[0])
		if absf(area) < 1e-9:
			continue
		var x0: int = maxi(0, floori(minf(s[0].x, minf(s[1].x, s[2].x))))
		var x1: int = mini(w - 1, ceili(maxf(s[0].x, maxf(s[1].x, s[2].x))))
		var y0: int = maxi(0, floori(minf(s[0].y, minf(s[1].y, s[2].y))))
		var y1: int = mini(h - 1, ceili(maxf(s[0].y, maxf(s[1].y, s[2].y))))
		for y: int in range(y0, y1 + 1):
			for x: int in range(x0, x1 + 1):
				var c: Vector2 = Vector2(x + 0.5, y + 0.5)
				var w0: float = (s[1] - c).cross(s[2] - c) / area
				var w1: float = (s[2] - c).cross(s[0] - c) / area
				var w2: float = 1.0 - w0 - w1
				if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
					continue
				var z: float = d[0] * w0 + d[1] * w1 + d[2] * w2
				var i: int = y * w + x
				if z < depth[i]:
					depth[i] = z
					hits[i] = [t, w0, w1]
	return hits


## The unlit base colour at every hit pixel, with the fighter's current
## (toon) materials: the base colour times the texture.
func _shade(tris: Array[Dictionary], hits: Dictionary) -> PackedColorArray:
	var out: PackedColorArray = PackedColorArray()
	for i: int in hits:
		var hit: Array = hits[i]
		var tri: Dictionary = tris[hit[0]]
		var mat: ShaderMaterial = (tri.mesh as MeshInstance3D).get_active_material(tri.surface) as ShaderMaterial
		var c: Color = Color.WHITE
		if mat != null:
			c = mat.get_shader_parameter(&"base_color")
			var tex: Texture2D = mat.get_shader_parameter(&"albedo_texture")
			if tex != null:
				var uv: Vector2 = tri.uv[0] * hit[1] + tri.uv[1] * hit[2] + tri.uv[2] * (1.0 - hit[1] - hit[2])
				c *= _sample(tex, uv)
		out.append(c)
	return out


## A colour (sRGB) in CIELAB, D65 white.
static func _lab(c: Color) -> Vector3:
	var lin: Color = c.srgb_to_linear()
	var x: float = (0.4124 * lin.r + 0.3576 * lin.g + 0.1805 * lin.b) / 0.95047
	var y: float = 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	var z: float = (0.0193 * lin.r + 0.1192 * lin.g + 0.9505 * lin.b) / 1.08883
	var fx: float = _lab_f(x)
	var fy: float = _lab_f(y)
	var fz: float = _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lab_f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


func _sample(tex: Texture2D, uv: Vector2) -> Color:
	# by the texture's own image: a dyed palette's maps sit inside the
	# export's GLB, with no file of their own
	var path: String = str(tex.get_instance_id())
	if not _images.has(path):
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGB8)
		_images[path] = img
	var image: Image = _images[path]
	var x: int = clampi(int(fposmod(uv.x, 1.0) * image.get_width()), 0, image.get_width() - 1)
	var y: int = clampi(int(fposmod(uv.y, 1.0) * image.get_height()), 0, image.get_height() - 1)
	return image.get_pixel(x, y)
