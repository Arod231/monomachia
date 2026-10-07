class_name GraphicsPreset
extends Resource
## One graphics preset (Low, Medium, High or Ultra). GraphicsApplier applies it
## to the renderer, a viewport and a scene tree; GameSettings remembers which
## one the player chose. The four presets live in res://view/look/presets/.
##
## Ultra is the reference (milestone-1 task 29, stories 182-184): the look is
## judged at it, tests and shots render at it (DEFAULT_ID), and every other
## preset follows it in every setting but CUTS, the resolution and upscaler
## and the atmosphere, as the owner chose (Oct 5): Ultra renders at 67% of the
## output (1440p at 4K) and upscales with FSR 2.2; High upscales from 59%
## (FSR 2.2's Balanced mode); Medium also drops ambient occlusion and the minor
## decals; Low renders at 67% with FSR 1 (until the laptop bench picks its
## upscaler) and drops all four atmosphere items, keeping the palettes, the
## rim lights, blood, the 危 and the cinematic shots. Low also drops the
## parry push-in's depth of field (push_in_dof, milestone-1 task 39; the
## owner's choice, Oct 6). Medium and Low also drop the sparks' contact
## lights (spark_light, milestone-1 task 37; the owner's choice, Oct 6).
##
## The first launch picks a preset from the graphics card's name (for_card(),
## the rules in CARDS); a card no rule names gets UNKNOWN_CARD_ID.
##
## Costs quoted below were measured at 1080p on the target laptop (Ryzen 7
## 4700U with Radeon Vega graphics) while the arena was first built, in the
## toon look, with capsule stand-ins.

const IDS: Array[StringName] = [&"low", &"medium", &"high", &"ultra"]
## The preset the look is judged at.
const REFERENCE_ID: StringName = &"ultra"
## The preset when nothing chose one: what tests and shots render at.
const DEFAULT_ID: StringName = REFERENCE_ID
## The first launch's preset for a card the table doesn't name.
const UNKNOWN_CARD_ID: StringName = &"medium"
## The first launch's table: res://view/look/presets/cards.json.
const CARDS: String = "res://view/look/presets/cards.json"
## The settings a preset may set apart from Ultra's: the resolution and
## upscaler, and the atmosphere. A test holds every other setting to Ultra's.
const CUTS: Array[StringName] = [
	&"render_scale", &"scaling_3d_mode", &"screen_space_aa",
	&"volumetric_fog", &"petal_lights", &"ambient_occlusion", &"minor_decals",
	&"push_in_dof", &"spark_light",
]

@export var id: StringName = &"high"
@export var display_name: String = "High"

@export_group("Shadows")
@export var shadows_enabled: bool = true
## Directional shadow atlas size in pixels (power of two).
@export var shadow_atlas_size: int = 4096
## Distance from the camera that the moon's shadows reach, in metres.
@export var shadow_max_distance: float = 34.0
## 1 = orthogonal, 2 or 4 = parallel splits.
@export var shadow_splits: int = 2
@export var soft_shadow_quality: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW

@export_group("Anti-aliasing and resolution")
@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED
## FXAA rather than MSAA: MSAA 2x cost about 5 ms per frame. Off under FSR
## 2.2, which anti-aliases itself.
@export var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.SCREEN_SPACE_AA_FXAA
## 3D render scale: the share of the output's width and height the 3D view
## renders at (1.0 = native).
@export_range(0.5, 1.0) var render_scale: float = 1.0
## How the 3D view is scaled up to the output: bilinear, FSR 1 or FSR 2.2.
@export var scaling_3d_mode: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_BILINEAR

@export_group("Fog and bloom")
@export var fog_enabled: bool = true
@export var height_fog: bool = true
## The Environment's glow: the realistic look's subtle bloom (milestone-1
## task 43), on every preset as the look test settled it.
@export var glow_enabled: bool = true

@export_group("Atmosphere")
## The arena's volumetric fog, where its environment has it; off, its height
## fog carries the night alone.
@export var volumetric_fog: bool = true
## The arena's ambient occlusion (SSAO), where its environment has it.
@export var ambient_occlusion: bool = true
## The falling petals' lights: Light3D nodes in group look_petal_light.
@export var petal_lights: bool = true
## The decals that only dress the arena: Decal nodes in group
## look_minor_decal.
@export var minor_decals: bool = true

@export_group("Effects")
## Fraction of each ambient particle emitter's amount that is drawn.
@export_range(0.0, 1.0) var particle_ratio: float = 1.0
## Lantern lights and other small omni lights.
@export var minor_lights: bool = true
## Distant scenery detail: 0 = silhouettes only, 1 = with props, 2 = all.
@export_range(0, 2) var scenery_detail: int = 2
## The far blur (depth of field) while the camera is pushed in on a parry
## (CameraRig.dof_allowed).
@export var push_in_dof: bool = true
## The warm light a spark burst throws on the fighters and blades for a few
## frames (CombatEffects.contact_light()).
@export var spark_light: bool = true


## Loads a preset by id (low, medium, high or ultra); null for any other id.
static func load_id(preset_id: StringName) -> GraphicsPreset:
	if not IDS.has(preset_id):
		return null
	return load("res://view/look/presets/%s.tres" % preset_id) as GraphicsPreset


static func default_preset() -> GraphicsPreset:
	return load_id(DEFAULT_ID)


## Ultra, the preset the others follow.
static func ultra() -> GraphicsPreset:
	return load_id(REFERENCE_ID)


## The card table's rules, in order: { "pattern": a regular expression,
## "preset": an id }.
static func card_rules() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARDS))
	if not data is Dictionary:
		push_error("GraphicsPreset: %s isn't a card table" % CARDS)
		return out
	for r: Variant in (data as Dictionary).get("rules", []):
		if r is Dictionary:
			out.append(r)
	return out


## The preset for a graphics card's name (RenderingServer's video adapter
## name): the first rule whose pattern is found in it, ignoring case, or
## UNKNOWN_CARD_ID.
static func for_card(card_name: String) -> StringName:
	var lower: String = card_name.to_lower()
	for r: Dictionary in card_rules():
		var re := RegEx.new()
		if re.compile(str(r["pattern"])) != OK:
			continue
		if re.search(lower) != null and IDS.has(StringName(r["preset"])):
			return StringName(r["preset"])
	return UNKNOWN_CARD_ID
