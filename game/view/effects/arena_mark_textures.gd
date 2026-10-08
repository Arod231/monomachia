class_name ArenaMarkTextures
extends RefCounted
## The arena's marks' looks (ArenaMarks, milestone-1 task 115), made once a
## run from fixed seeds: for each kind an albedo (its alpha where the mark
## covers the stone), a normal map from the mark's own height (the cut's
## gouge, the crack's split, the groove's channel), and for the groove an
## emission (its silver core). Each texture's V runs along the mark, U
## across it.
## - cut: a thin gouge, dark in its bottom, with fresh pale stone at its lips;
## - gash: a short, deep, ragged slot where a weapon stood stuck;
## - crack: dark splits branching out from a crushed, paler centre;
## - scorch: soot, densest in the middle, streaked outward, in a ring of
##   pale heat-bleached stone, with embers that glow a moment;
## - groove: a wide channel cut along the wave's path, its edges chipped,
##   a silver core that glows a moment.

const SIZE: Dictionary[StringName, Vector2i] = {
	&"cut": Vector2i(32, 256), &"gash": Vector2i(64, 128), &"crack": Vector2i(256, 256),
	&"scorch": Vector2i(128, 128), &"groove": Vector2i(64, 256),
}
const SEEDS: Dictionary[StringName, int] = {&"cut": 1151, &"gash": 1153, &"crack": 1157, &"scorch": 1159, &"groove": 1163}
## The stone's colours in a mark: its shadowed bottom, freshly cut stone,
## crushed dust, soot.
const DEEP := Color(0.07, 0.07, 0.08)
const FRESH := Color(0.66, 0.65, 0.63)
const DUST := Color(0.55, 0.54, 0.52)
const SOOT := Color(0.04, 0.035, 0.035)
const SILVER := Color(0.85, 0.9, 1.0)
const BLEACHED := Color(0.62, 0.6, 0.58)
const EMBER := Color(1.0, 0.42, 0.12)
## How steep the normal map makes a unit of height per texel.
const BUMP: float = 2.5


## [albedo, normal, emission (null but for the groove)] for kind.
static func make(kind: StringName) -> Array:
	var size: Vector2i = SIZE[kind]
	var noise := FastNoiseLite.new()
	noise.seed = SEEDS[kind]
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var height := PackedFloat32Array()
	height.resize(size.x * size.y)
	var albedo := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var emission: Image = null
	match kind:
		&"cut":
			_gouge(size, height, albedo, noise, 0.16, 0.5, 0.35)
		&"gash":
			_gouge(size, height, albedo, noise, 0.3, 1.0, 0.9)
		&"groove":
			_gouge(size, height, albedo, noise, 0.72, 0.8, 0.02)
			emission = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			for y: int in size.y:
				for x: int in size.x:
					var u: float = (x + 0.5) / size.x - 0.5
					var core: float = exp(-u * u / 0.012) * (0.75 + 0.25 * noise.get_noise_2d(x * 0.5, y * 3.0))
					emission.set_pixel(x, y, Color(SILVER.r * core, SILVER.g * core, SILVER.b * core))
		&"crack":
			_crack(size, height, albedo, noise)
		&"scorch":
			_scorch(size, albedo, noise)
			emission = _embers(size, noise)
	albedo.generate_mipmaps()
	var out: Array = [ImageTexture.create_from_image(albedo), _normal_map(size, height), null]
	if emission != null:
		emission.generate_mipmaps()
		out[2] = ImageTexture.create_from_image(emission)
	return out


## A channel along V: `width` of the texture across at its middle, `depth`
## deep (height units), tapering to points at its ends over `taper` of its
## length; ragged at its lips by the noise.
static func _gouge(size: Vector2i, height: PackedFloat32Array, albedo: Image, noise: FastNoiseLite,
		width: float, depth: float, taper: float) -> void:
	for y: int in size.y:
		var v: float = (y + 0.5) / size.y
		var ends: float = clampf(minf(v, 1.0 - v) / maxf(taper * 0.5, 0.001), 0.0, 1.0)
		var half: float = width * 0.5 * sqrt(ends) * (0.85 + 0.3 * noise.get_noise_2d(7.0, y * 0.7))
		var wander: float = noise.get_noise_2d(31.0, y * 0.15) * 0.06
		for x: int in size.x:
			var u: float = (x + 0.5) / size.x - 0.5 - wander
			var rag: float = noise.get_noise_2d(x * 2.0, y * 2.0) * 0.25
			var across: float = absf(u) / maxf(half, 0.0001) + rag * 0.3
			var h: float = -depth * clampf(1.0 - across * across, 0.0, 1.0)
			height[y * size.x + x] = h
			# the lips: fresh stone chipped out round the gouge
			var lip: float = clampf(1.0 - absf(across - 1.15) / 0.45, 0.0, 1.0) * (0.6 + 0.4 * rag * 4.0)
			var inside: float = clampf((1.0 - across) * 4.0, 0.0, 1.0)
			var c: Color = FRESH.lerp(DEEP, inside * clampf(-h / maxf(depth, 0.001) * 1.4, 0.0, 1.0))
			var a: float = maxf(inside, clampf(lip, 0.0, 1.0) * 0.55)
			albedo.set_pixel(x, y, Color(c.r, c.g, c.b, a))


## Splits running out from the middle, branching, over a crushed centre.
static func _crack(size: Vector2i, height: PackedFloat32Array, albedo: Image, noise: FastNoiseLite) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEEDS[&"crack"]
	var lines: Array[PackedVector2Array] = []
	var mains: int = 7
	for k: int in mains:
		var angle: float = TAU * (k + rng.randf_range(-0.3, 0.3)) / mains
		_walk(rng, Vector2(0.5, 0.5), angle, rng.randf_range(0.32, 0.47), 0.012, lines, 2)
	var dist := PackedFloat32Array()
	dist.resize(size.x * size.y)
	dist.fill(1e9)
	var width := PackedFloat32Array()
	width.resize(size.x * size.y)
	for line: PackedVector2Array in lines:
		for i: int in line.size() - 1:
			var a: Vector2 = line[i] * Vector2(size)
			var b: Vector2 = line[i + 1] * Vector2(size)
			# thinning toward the tips
			var w: float = lerpf(2.6, 0.6, float(i) / maxf(1.0, line.size() - 1.0)) * (1.0 if line.size() > 8 else 0.6)
			var lo := Vector2i(int(minf(a.x, b.x) - 4), int(minf(a.y, b.y) - 4))
			var hi := Vector2i(int(maxf(a.x, b.x) + 4), int(maxf(a.y, b.y) + 4))
			for y: int in range(maxi(lo.y, 0), mini(hi.y, size.y - 1) + 1):
				for x: int in range(maxi(lo.x, 0), mini(hi.x, size.x - 1) + 1):
					var p := Vector2(x + 0.5, y + 0.5)
					var d: float = Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) / w
					var idx: int = y * size.x + x
					if d < dist[idx]:
						dist[idx] = d
						width[idx] = w
	for y: int in size.y:
		for x: int in size.x:
			var idx: int = y * size.x + x
			var p := Vector2((x + 0.5) / size.x, (y + 0.5) / size.y)
			var r: float = p.distance_to(Vector2(0.5, 0.5))
			var split: float = clampf(1.0 - dist[idx], 0.0, 1.0)
			var edge: float = clampf(1.0 - (dist[idx] - 1.0) / 1.5, 0.0, 1.0) * 0.35
			var crushed: float = clampf(1.0 - r / (0.09 + 0.03 * noise.get_noise_2d(x, y)), 0.0, 1.0)
			height[idx] = -split * 0.8 - crushed * 0.25 * (0.5 + 0.5 * noise.get_noise_2d(x * 3.0, y * 3.0))
			var c: Color = DUST.lerp(DEEP, split)
			albedo.set_pixel(x, y, Color(c.r, c.g, c.b, maxf(maxf(split, edge), crushed * 0.6)))


## A jagged walk from `from` heading `angle` for `length` (texture widths),
## in steps of about `step`, branching up to `branches` deep; each line in
## `lines`.
static func _walk(rng: RandomNumberGenerator, from: Vector2, angle: float, length: float, step: float,
		lines: Array[PackedVector2Array], branches: int) -> void:
	var line := PackedVector2Array([from])
	var at: Vector2 = from
	var heading: float = angle
	var went: float = 0.0
	while went < length:
		heading += rng.randf_range(-0.45, 0.45)
		heading = lerp_angle(heading, angle, 0.25)
		at += Vector2(cos(heading), sin(heading)) * step
		went += step
		line.append(at)
		if branches > 0 and rng.randf() < 0.07:
			_walk(rng, at, heading + rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0),
				(length - went) * rng.randf_range(0.3, 0.6), step, lines, branches - 1)
	lines.append(line)


## Soot: densest in the middle, thinning in streaks blown outward.
static func _scorch(size: Vector2i, albedo: Image, noise: FastNoiseLite) -> void:
	for y: int in size.y:
		for x: int in size.x:
			var p := Vector2((x + 0.5) / size.x - 0.5, (y + 0.5) / size.y - 0.5) * 2.0
			var r: float = p.length()
			var a: float = atan2(p.y, p.x)
			var streak: float = 0.5 + 0.5 * noise.get_noise_2d(cos(a) * 9.0, sin(a) * 9.0)
			var reach: float = 0.5 + 0.35 * streak
			var cover: float = clampf(1.0 - r / reach, 0.0, 1.0)
			cover = pow(cover, 0.7) * (0.75 + 0.25 * noise.get_noise_2d(x * 2.0, y * 2.0))
			# the heat's ring: bleached stone just past the soot
			var ring: float = clampf(1.0 - absf(r - reach * 1.08) / 0.16, 0.0, 1.0) * (0.6 + 0.4 * streak)
			var c: Color = SOOT.lerp(Color(0.16, 0.13, 0.11), clampf(r, 0.0, 1.0))
			if ring > cover:
				c = BLEACHED
			albedo.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(maxf(cover * 0.9, ring * 0.45), 0.0, 1.0)))


## Embers scattered through a scorch's middle.
static func _embers(size: Vector2i, noise: FastNoiseLite) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var p := Vector2((x + 0.5) / size.x - 0.5, (y + 0.5) / size.y - 0.5) * 2.0
			var spot: float = clampf((noise.get_noise_2d(x * 4.0 + 500.0, y * 4.0) - 0.25) * 4.0, 0.0, 1.0)
			var hot: float = spot * clampf(1.0 - p.length() / 0.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(EMBER.r * hot, EMBER.g * hot, EMBER.b * hot))
	return img


## A normal map (OpenGL convention, as Godot's decals take it) from a
## height field.
static func _normal_map(size: Vector2i, height: PackedFloat32Array) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for y: int in size.y:
		for x: int in size.x:
			var l: float = height[y * size.x + maxi(x - 1, 0)]
			var r: float = height[y * size.x + mini(x + 1, size.x - 1)]
			var d: float = height[mini(y + 1, size.y - 1) * size.x + x]
			var u: float = height[maxi(y - 1, 0) * size.x + x]
			var n := Vector3((l - r) * BUMP, (d - u) * BUMP, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
