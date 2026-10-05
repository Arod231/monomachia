extends RefCounted
## Where each texel of a texture sits on a model: for every texel that a
## mesh's UVs cover, the piece it belongs to and its position and normal on
## the model in rest pose (fighter space: metres, +Y up, +Z forward). The
## bake tools use it to recolour by garment and to place wear (grime near
## the ground, scuffed knees, soot round the eyes) where it belongs on the
## body, with noise that is continuous across UV seams.
##
## Used by tools/bake_palettes.gd and tools/bake_skins.gd (preload it).

## Piece index of a texel no mesh covers.
const NONE: int = 255

var width: int
var height: int
## Piece index per texel (NONE where nothing is mapped).
var piece: PackedByteArray
## Rest-pose position and normal per texel.
var position: PackedVector3Array
var normal: PackedVector3Array


func _init(w: int, h: int) -> void:
	width = w
	height = h
	piece = PackedByteArray()
	piece.resize(w * h)
	piece.fill(NONE)
	position = PackedVector3Array()
	position.resize(w * h)
	normal = PackedVector3Array()
	normal.resize(w * h)


## Rasterises one mesh surface into the map as piece `piece_index`.
## `xf` takes the mesh's vertices to fighter space.
func add_surface(mesh: Mesh, surface: int, xf: Transform3D, piece_index: int) -> void:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.is_empty():
		index.resize(verts.size())
		for i: int in verts.size():
			index[i] = i
	var nb: Basis = xf.basis.inverse().transposed()
	var size: Vector2 = Vector2(width, height)
	for t: int in index.size() / 3:
		var ia: int = index[t * 3]
		var ib: int = index[t * 3 + 1]
		var ic: int = index[t * 3 + 2]
		_raster(uvs[ia] * size, uvs[ib] * size, uvs[ic] * size,
			xf * verts[ia], xf * verts[ib], xf * verts[ic],
			(nb * norms[ia]).normalized(), (nb * norms[ib]).normalized(), (nb * norms[ic]).normalized(), piece_index)


func _raster(a: Vector2, b: Vector2, c: Vector2, pa: Vector3, pb: Vector3, pc: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, piece_index: int) -> void:
	var area: float = (b - a).cross(c - a)
	if absf(area) < 1e-12:
		return
	# UVs wrap: keep the triangle where most of it lies.
	var x0: int = maxi(0, floori(minf(a.x, minf(b.x, c.x))))
	var x1: int = mini(width - 1, ceili(maxf(a.x, maxf(b.x, c.x))))
	var y0: int = maxi(0, floori(minf(a.y, minf(b.y, c.y))))
	var y1: int = mini(height - 1, ceili(maxf(a.y, maxf(b.y, c.y))))
	var inv: float = 1.0 / area
	for y: int in range(y0, y1 + 1):
		var py: float = y + 0.5
		for x: int in range(x0, x1 + 1):
			var px: float = x + 0.5
			var w0: float = ((b.x - px) * (c.y - py) - (b.y - py) * (c.x - px)) * inv
			var w1: float = ((c.x - px) * (a.y - py) - (c.y - py) * (a.x - px)) * inv
			var w2: float = 1.0 - w0 - w1
			# A small tolerance closes the hairline gaps between triangles.
			if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
				continue
			var i: int = y * width + x
			piece[i] = piece_index
			position[i] = pa * w0 + pb * w1 + pc * w2
			normal[i] = (na * w0 + nb * w1 + nc * w2).normalized()


## Grows the mapped islands into the empty texels around them, `steps`
## texels deep, so that mipmaps and filtering at island borders read the
## island's own values instead of the padding between islands.
func dilate(steps: int) -> void:
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for step: int in steps:
		var grown: PackedInt32Array = PackedInt32Array()
		var source: PackedInt32Array = PackedInt32Array()
		for y: int in height:
			for x: int in width:
				var i: int = y * width + x
				if piece[i] != NONE:
					continue
				for o: Vector2i in offsets:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var j: int = ny * width + nx
					if piece[j] != NONE:
						grown.append(i)
						source.append(j)
						break
		if grown.is_empty():
			return
		for k: int in grown.size():
			piece[grown[k]] = piece[source[k]]
			position[grown[k]] = position[source[k]]
			normal[grown[k]] = normal[source[k]]


## Share of texels that are mapped.
func coverage() -> float:
	return 1.0 - float(piece.count(NONE)) / float(piece.size())
