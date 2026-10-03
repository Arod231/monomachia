class_name GraphicsPreset
extends Resource
## One graphics preset (Low, Medium or High). GraphicsApplier applies it to the
## renderer, a viewport and a scene tree; GameSettings remembers which one the
## player chose. The three presets live in res://view/look/presets/, and High
## is the default.
##
## The costs quoted below were measured at 1080p on the target laptop (Ryzen 7
## 4700U with Radeon Vega graphics) while the arena was first built, with
## capsule stand-ins. Benchmarked there since with the real fighters fighting
## on the Moonlit Shrine (tools/shot_scenes/arena_bench.tscn), High runs
## about 69 fps, Medium 79 and Low 102.

const IDS: Array[StringName] = [&"low", &"medium", &"high"]
const DEFAULT_ID: StringName = &"high"

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
## FXAA rather than MSAA on every preset: MSAA 2x cost about 5 ms per frame,
## and FXAA softens the ink lines pleasantly.
@export var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.SCREEN_SPACE_AA_FXAA
## 3D render scale (1.0 = native); below 1 uses FSR 1.
@export_range(0.5, 1.0) var render_scale: float = 1.0

@export_group("Outlines")
@export var outline_fighters: bool = true
@export var outline_weapons: bool = true
@export var outline_props: bool = true
## Multiplies every outline's width (ToonMaterials.OUTLINE_WIDTH).
@export_range(0.5, 2.0) var outline_width_scale: float = 1.0

@export_group("Post and atmosphere")
@export var post_quality: InkWashPass.Quality = InkWashPass.Quality.FULL
## Ink lines at normal breaks too (creases inside silhouettes). Off on all
## three presets: the normal buffer it needs cost about 3 ms per frame, and
## the prop outlines on High draw the main creases instead.
@export var ink_normal_lines: bool = false
@export var fog_enabled: bool = true
@export var height_fog: bool = true
## The Environment's glow (bloom). Off on all three presets: even on its
## low-resolution levels it cost about 2 ms per frame. Lantern halos and the
## moon's sky haze carry the glow instead; turn it on for faster GPUs.
@export var glow_enabled: bool = false

@export_group("Effects")
## Fraction of each ambient particle emitter's amount that is drawn.
@export_range(0.0, 1.0) var particle_ratio: float = 1.0
## Lantern lights and other small omni lights.
@export var minor_lights: bool = true
## Distant scenery detail: 0 = silhouettes only, 1 = with props, 2 = all.
@export_range(0, 2) var scenery_detail: int = 2


## Loads a preset by id (low, medium or high); null for any other id.
static func load_id(preset_id: StringName) -> GraphicsPreset:
	if not IDS.has(preset_id):
		return null
	return load("res://view/look/presets/%s.tres" % preset_id) as GraphicsPreset


## Whether this preset outlines materials of the given kind (never NONE).
func outlines_on(kind: ToonMaterials.OutlineKind) -> bool:
	match kind:
		ToonMaterials.OutlineKind.FIGHTER:
			return outline_fighters
		ToonMaterials.OutlineKind.WEAPON:
			return outline_weapons
		ToonMaterials.OutlineKind.PROP:
			return outline_props
	return false


static func default_preset() -> GraphicsPreset:
	return load_id(DEFAULT_ID)
