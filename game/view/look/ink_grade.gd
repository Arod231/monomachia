class_name InkGrade
extends RefCounted
## The look's colour grade, baked into a 3D lookup table that the Environment
## applies in its tonemap pass (adjustment_color_correction), so grading costs
## nothing extra per frame. The grade pulls colours toward the look's muted
## ink-and-bone colours (LookPalette):
## - colours lose some saturation, except warm accents (blood red, ember
##   orange), which keep it;
## - shadows lean cold blue, highlights lean bone;
## - contrast rises a little around the mid-tones;
## - the darkest values settle on ink rather than pure black.
## The fighters' palette colours (saturated red and blue) keep their hue.
##
## The LUT is indexed by the display (sRGB) colour after tonemapping.

const SIZE: int = 24

const SATURATION: float = 0.8
const ACCENT_SATURATION: float = 1.08
const CONTRAST: float = 1.07
const SHADOW_TINT: Color = Color(0.9, 0.95, 1.06)
const HIGHLIGHT_TINT: Color = Color(1.04, 1.0, 0.94)
const INK: Color = Color(0.075, 0.075, 0.1)
## How far the floor of each channel is lifted toward INK.
const BLACK_LIFT: float = 0.75

static var _cached: ImageTexture3D


## The shared LUT texture, built on first use.
static func lut() -> ImageTexture3D:
	if _cached == null:
		_cached = build(SIZE)
	return _cached


## Turns the grade on for env, with the other adjustments neutral.
static func apply(env: Environment) -> void:
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.0
	env.adjustment_saturation = 1.0
	env.adjustment_color_correction = lut()


## Grades one display-space colour.
static func grade(c: Color) -> Color:
	var r: float = c.r
	var g: float = c.g
	var b: float = c.b
	var lum: float = 0.2126 * r + 0.7152 * g + 0.0722 * b
	var mx: float = maxf(r, maxf(g, b))
	var mn: float = minf(r, minf(g, b))
	var chroma: float = (mx - mn) / maxf(mx, 1e-4)
	var warmth: float = (r - maxf(g, b) * 0.85) / maxf(mx, 1e-4)
	var warm: float = smoothstep(0.15, 0.5, warmth) * smoothstep(0.2, 0.5, chroma)
	var sat: float = lerpf(SATURATION, ACCENT_SATURATION, warm)
	r = lerpf(lum, r, sat)
	g = lerpf(lum, g, sat)
	b = lerpf(lum, b, sat)
	var tone: float = smoothstep(0.05, 0.7, lum)
	r *= lerpf(SHADOW_TINT.r, HIGHLIGHT_TINT.r, tone)
	g *= lerpf(SHADOW_TINT.g, HIGHLIGHT_TINT.g, tone)
	b *= lerpf(SHADOW_TINT.b, HIGHLIGHT_TINT.b, tone)
	r = (r - 0.5) * CONTRAST + 0.5
	g = (g - 0.5) * CONTRAST + 0.5
	b = (b - 0.5) * CONTRAST + 0.5
	r = lerpf(r, maxf(r, INK.r), BLACK_LIFT)
	g = lerpf(g, maxf(g, INK.g), BLACK_LIFT)
	b = lerpf(b, maxf(b, INK.b), BLACK_LIFT)
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0))


## Builds a size x size x size LUT of grade().
static func build(size: int) -> ImageTexture3D:
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, size, size, size, false, slices(size))
	return tex


## The LUT's images: red runs along x, green along y, and blue across the
## slices.
static func slices(size: int) -> Array[Image]:
	var out: Array[Image] = []
	for z: int in size:
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
		for y: int in size:
			for x: int in size:
				var c := Color(float(x) / (size - 1), float(y) / (size - 1), float(z) / (size - 1))
				img.set_pixel(x, y, grade(c))
		out.append(img)
	return out
