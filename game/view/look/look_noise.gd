class_name LookNoise
extends RefCounted
## A small tiling noise texture shared by the look's shaders, so they fetch
## noise instead of computing it. On the target laptop's integrated GPU each
## procedural value-noise call over the courtyard floor cost about 0.15 ms per
## frame; a texture fetch costs next to nothing.
##
## SIZE x SIZE texels, RGBA8, tiling, with mipmaps:
## - R, G, B: three independent value noises with CELLS lattice cells across
##   the texture, smoothstep-interpolated like the shaders' own value noise, so
##   thresholds tuned for one suit the other;
## - A: white noise, one random value per texel (paper grain specks).
##
## Shaders include res://shaders/look_noise.gdshaderinc, whose look_noise()
## returns value noise with one cell per unit, like a procedural noise(p).
## Materials get the texture through apply_to(); ToonMaterials does that for
## every material it makes.

const SIZE: int = 256
const CELLS: int = 8
const SEED: int = 1337
## The shaders' uniform for the texture.
const PARAM: StringName = &"look_noise_tex"

static var _texture: ImageTexture


## The shared texture, built on first use (a few tens of milliseconds).
static func texture() -> ImageTexture:
	if _texture == null:
		var img: Image = build(SIZE, CELLS, SEED)
		img.generate_mipmaps()
		_texture = ImageTexture.create_from_image(img)
	return _texture


## Sets the noise texture on a shader material (harmless if its shader has no
## look_noise_tex uniform).
static func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter(PARAM, texture())


## Builds the noise image. Pure function of its arguments; cells must divide
## size.
@warning_ignore("integer_division")
static func build(size: int, cells: int, noise_seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var lattices: Array[PackedFloat32Array] = []
	for c: int in 3:
		var lattice := PackedFloat32Array()
		lattice.resize(cells * cells)
		for i: int in cells * cells:
			lattice[i] = rng.randf()
		lattices.append(lattice)
	var step: int = size / cells
	var weights := PackedFloat32Array()
	weights.resize(step)
	for i: int in step:
		var f: float = float(i) / step
		weights[i] = f * f * (3.0 - 2.0 * f)
	var data := PackedByteArray()
	data.resize(size * size * 4)
	for y: int in size:
		var cy: int = y / step
		var cy1: int = (cy + 1) % cells
		var wy: float = weights[y % step]
		for x: int in size:
			var cx: int = x / step
			var cx1: int = (cx + 1) % cells
			var wx: float = weights[x % step]
			var o: int = (y * size + x) * 4
			for c: int in 3:
				var l: PackedFloat32Array = lattices[c]
				var top: float = lerpf(l[cy * cells + cx], l[cy * cells + cx1], wx)
				var bottom: float = lerpf(l[cy1 * cells + cx], l[cy1 * cells + cx1], wx)
				data[o + c] = int(lerpf(top, bottom, wy) * 255.0 + 0.5)
			data[o + 3] = rng.randi() & 255
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
