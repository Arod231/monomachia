> Research notes from the Oct 1, 2026 task breakdown, a snapshot of the code at 51dcfb0.
> The plan (`docs/plans/godot-rebuild.md`) is the source of truth: its task ids, order and decisions
> supersede the proposals and keys here. Line numbers drift as the code changes.

# Phase E: look (plan task 16), the floating Moonlit Shrine (plan task 17) and combat effects and game feel (plan task 18)

## Current state
WHAT THE CURRENT BRANCH HAS (feature/godot-rebuild at 51dcfb0)
- No look code, no shaders folder, no arenas folder. The match draws with StandardMaterial3D everywhere: game/view/match/fighter_standin.gd (FighterStandin, posed by StickPose, flash and blade glow via emission), game/view/match/standin_arena.gd (flat floor at SimConst.ARENA_RADIUS, its own WorldEnvironment and moon lights, Spawn0/1 and Gate0/1 markers).
- game/view/match/arena_scenes.gd maps &"moonlit_shrine" (MatchConfig.DEFAULT_ARENA) to res://arenas/moonlit_shrine/moonlit_shrine.tscn and falls back to the stand-in only while that file is missing. MatchView.arena_camera_data() reads `def.camera_max_radius` and `def.camera_far` from the arena root by name and hands them to CameraRig.apply_arena().
- SimConst.ARENA_RADIUS is still 11.5 (game/sim/constants.gd:21); world.gd:179 and :569 use it. Task 8 changes it to 15.
- Game feel that task 6 already does:
  - hit-stop: rules freeze world.frame, MatchHost.alpha() holds at 1;
  - slow motion: the accumulator is scaled by world.time_scale(), so KO 0.3x and ultChoice 0.35x already work;
  - camera shake and FOV kicks per event with the demo's amounts: MatchView._on_sim_event, CameraRig.add_shake/kick_fov;
  - reduce-flashes hooks: CameraRig.shake_scale and fov_kick_scale. No setting stores or sets them yet;
  - KO orbit;
  - body hit flash and blade glow (danger/charge/ult) on FighterStandin, timed on world frames;
  - stand-in contact flashes (MatchView._spawn_flash: unshaded spheres timed on world frames, marked as a placeholder for task 18's sparks);
  - a dropped-weapon beam (MatchView._make_dropped: a cylinder in the palette colour, visible when grounded, no ground ring, no pulse).
- Missing: trails, sparks, ink splashes, parry ring, push-in, warning mark, reach effect, aura, ultimate effects, dust, status flashes, and any settings store (GameServices holds only controls).
- Task 13 (unmerged, fcfb8d8):
  - fighters and weapons use StandardMaterial3D and two custom non-toon shaders (game/weapons/katana/katana_blade.gdshader, katana_wrap.gdshader). FighterModel duplicates BaseMaterial3D per palette;
  - WeaponLook gives BladeBase/BladeTip markers and trail_width (0.5 m from the tip), which the trails need.
- The demo's effects: src/render/view.ts handleEvents and src/render/vfx.ts. The trail kind comes from src/render/pose.ts (def.trail, ult phases). The Godot port has the same event set in game/sim/events.gd.

THE LOOK-AND-ARENA WORKTREE (.claude/worktrees/wf_c7f99fe5-f9a-1, branch look-and-arena, base 67265af, all untracked)
- game/view/: mesh_kit.gd (464 lines), mesh_kit_set.gd.
- game/view/look/:
  - toon_materials.gd, look_palette.gd, look_noise.gd;
  - ink_wash_pass.gd, ink_grade.gd;
  - graphics_preset.gd, graphics_applier.gd, presets/low|medium|high.tres;
  - ink_night_environment.tres, stand_in_fighter.gd;
  - shots/outline_compare.*.
- game/shaders/: 19 files (toon, toon_light inc, outline, look_noise inc, ink_wash inc plus full and lite, stone_floor, rock, sky_moonlit, cloud_sea, mountain_layer, waterfall, lake_water, mist_puff, lantern_glow, particle_glow, particle_flake).
- game/arenas/:
  - arena_def.gd;
  - moonlit_shrine/: moonlit_shrine.gd/.tscn/.tres, _env.tres, _layout.tres, shrine_layout.gd, shrine_platform.gd (318), shrine_props.gd (294), shrine_underside.gd (255), shrine_backdrop.gd (294), shrine_ambience.gd (165);
  - shots/arena_shot.gd (420) and 7 shot scenes.
- game/tests/view/: test_look, test_graphics_presets, test_arena_def, test_moonlit_shrine. Its last run passed 40 tests in 0.8 s, shrine build included.
- .uid files are present.
- game/_probe/ is scratch and must never be copied.
- docs/ diff: ticks 16 as [x] too early (don't carry that), and rewrites the spec's Look paragraph (stencil outline rejected, FXAA, glow off, noise texture, laptop budget). Keep that paragraph.

CODE QUALITY
- Generally good: documented, typed, data-driven:
  - ShrineLayout keeps every placement number;
  - a prop_scenes override seam for bought art;
  - presets act through node groups (look_shadow_light, look_minor_light, look_particles, look_scenery_detail) so arenas don't know about presets.
- Performance work is careful. The bench at 1080p on the Ryzen 7 4700U laptop: Low ~96 fps, Medium ~72 fps, High ~61-63 fps (p95 17-21 ms). That was measured with capsule stand-ins.

OVERLAPS AND CONFLICTS WITH THE CURRENT BRANCH, FILE BY FILE
No path or class_name collides. The problems are semantic:
1. arenas/moonlit_shrine/moonlit_shrine.tscn is exactly ArenaScenes' path.
   - Landing it makes the shrine the default arena of every match at once.
   - Its parapet stands at 15.3 m (ArenaDef walkable 15.0) while the rules' wall is still at 11.5. That is an invisible wall 3.5 m inside the visible one.
   - The camera would also take camera_max_radius 19.5.
2. arenas/arena_def.gd and moonlit_shrine.tres:
   - music_track_id &"battle_140" and ambience_id &"shrine_night" don't exist. They should be MusicDirector's &"battle" (game/audio/music_director.gd) and SoundBank's &"ambience_shrine" (game/audio/sound_bank.gd:225);
   - validate() hard-codes fighter_radius 0.42 instead of SimConst.FIGHTER_RADIUS;
   - camera_bounds and clamp_camera() duplicate CameraRig.clamp_to_arena, which uses the radius only;
   - otherwise it fits MatchView's by-name reads and the marker seams.
3. arenas/moonlit_shrine/shots/arena_shot.gd places its own Camera3D at the old 0.9 m right and 2.2 m up offsets. CameraRig now uses 1.35 m right and 1.95 m up with swing-out. The rig uses StandInFighter, and its shots live in the arena folder, while task 6 keeps shots in game/tools/shot_scenes/.
4. view/look/stand_in_fighter.gd (StandInFighter) duplicates view/match/fighter_standin.gd (FighterStandin). Drop it.
5. view/look/look_palette.gd:
   - FIGHTER_RED/BLUE overlap FighterStandin.PALETTES and task 13's FighterPalette;
   - FIGHTER_LAYER (render layer 2) is required for the shrine's red MoonRim light, but neither FighterStandin nor FighterModel sets it.
6. view/look/shots/outline_compare.gd depends on ShrineProps (arena code) and StandInFighter. Its decision is already recorded in the spec diff.
7. tests/view/test_look.gd mixes look and arena shaders in one list. test_arena_def.gd and test_moonlit_shrine.gd use the old camera offsets and the 0.42 radius. test_arena_def asserts walkable == 15.0, which the rules don't have until task 8.
8. Stale comments in shaders/ink_wash.gdshader and ink_wash_lite.gdshader: they say High uses normal lines, but every preset turns those off.
9. moonlit_shrine.gd hides the rock under the rim by get_viewport().get_camera_3d(). That doesn't hold for task 23's split screen.
10. shrine_ambience.gd adds pale petals, beyond the plan's "embers and ash".
11. The plan's "no shader errors in headless loading" check can't work as written:
   - headless uses the dummy renderer, which never compiles shaders;
   - test_every_shader_loads only proves the resources parse;
   - `npm run shots` (scripts/godot.mjs ERROR_PATTERNS) doesn't fail on SHADER ERROR.

SCREENSHOTS (look-arena-shots)
- 01_gameplay_high: reads well. Blood-red moon over ink mountains, red torii, glowing stone lanterns, parapet, painted stone floor with a red crescent; fighters pop in red and blue.
- 02_watch_high: reads well too. Waterfalls and pagodas show.
- 03_menu_orbit_high: delivers "floating": an inverted crag on chains over a sea of clouds, with floating rocks.
- 04_gameplay_low: keeps the composition but loses haze.
- 05_top_down_debug: confirms walkable 15.00, parapet inner face 15.075 m, spawns at ±3.2, gates at 16.9.
- What needs owner review:
  - the ink-wash lines and outlines are faint. In 06_outline_compare the inverted-hull, stencil and no-outline columns look almost the same, so the 3 px fighter outline barely reads;
  - the moon texture is blotchy.

VERDICT PER PIECE
- Salvage after review:
  - MeshKit/MeshKitSet;
  - toon shader, outline and ToonMaterials;
  - LookNoise and LookPalette (trimmed);
  - the ink-wash pass and InkGrade;
  - presets and the applier;
  - ArenaDef (fixed) and ShrineLayout;
  - the platform, props, underside, backdrop and ambience builders and their shaders;
  - the tests, fixed.
- Rebuild:
  - arena_shot.gd, on MatchHost, MatchView.set_arena and CameraRig, keeping its top-down overlay and bench code;
  - outline_compare, as a small look bench.
- Drop: StandInFighter and _probe.

## Tasks

### [16] look-shader-check (S): Make screenshot runs fail on shader compile errors
- delivers: `npm run shots` (scripts/godot.mjs) exits non-zero when Godot prints SHADER ERROR or a shader compile error. Today only test, typecheck and script check ERROR_PATTERNS. | A shot scene game/tools/shot_scenes/shader_check.tscn and .gd that scans res://shaders at run time and puts every spatial shader on a quad and every sky shader on a Sky in view, so each one compiles in a real window. This makes the plan's 'no shader errors' check real: headless uses the dummy renderer and never compiles shaders.
- check: A deliberately broken scratch .gdshader makes `npm run shots -- res://tools/shot_scenes/shader_check.tscn` fail; with the file removed it passes. | npm test and npm run typecheck pass.
- depends: 6
- stories: 46, 65
- files: scripts/godot.mjs, game/tools/shot_scenes/shader_check.gd, game/tools/shot_scenes/shader_check.tscn
- notes: Run shader_check before every visual commit in tasks 16-18. CI runs headless, so it can't catch shader errors.

### [16] mesh-kit (S): Bring over MeshKit and MeshKitSet with their geometry tests
- delivers: game/view/mesh_kit.gd and mesh_kit_set.gd (with their .uid files), copied from the look-and-arena worktree after review. | They hold boxes, discs, lathes, tubes, tori, spheres, curved roofs and mesh copies, merged into one ArrayMesh per material, with smoothed outline normals baked into CUSTOM0. | game/tests/view/test_mesh_kit.gd: front faces face outward for every primitive, and CUSTOM0 is baked (both from the worktree's test_look.gd). | A new test that MeshKitSet.finish makes one MeshInstance3D per non-empty kit, honours no_shadow and bakes CUSTOM0 only for outlined keys.
- check: New GUT tests pass. | npm test and npm run typecheck pass.
- depends: 6
- stories: 47, 63
- files: game/view/mesh_kit.gd, game/view/mesh_kit_set.gd, game/tests/view/test_mesh_kit.gd
- notes: Source: .claude/worktrees/wf_c7f99fe5-f9a-1/game/view/. Pure geometry, no look dependency. The arena builders and the outline shader's CUSTOM0 path need it.

### [16] toon-material (M): Toon material and inverted-hull ink outlines
- delivers: Shaders: game/shaders/toon.gdshader, toon_light.gdshaderinc (three soft bands, brushed terminator, cold shadow fill, rim, hard specular), outline.gdshader (hull width in pixels at 1080p, clamped in metres, CUSTOM0 smoothed normals), look_noise.gdshaderinc. | game/view/look/toon_materials.gd: fighter, weapon and prop classes, with an outline pass per class kept in metadata. | game/view/look/look_noise.gd. | game/view/look/look_palette.gd: keeps the ink, stone and moon colours plus FIGHTER_LAYER and GROUND_LAYER, and drops FIGHTER_RED/BLUE in favour of FighterStandin.PALETTES and task 13's palettes. | game/tests/view/test_look.gd (material part): outline by class, switching on and off with width scale, toon shaders load, LookNoise.build deterministic and tiling. | A look bench shot (game/tools/shot_scenes/look_bench.tscn and .gd): toon capsules and MeshKit props under a moon key light, near and 14 m back, outlines on and off. It replaces the worktree's outline_compare, which depended on arena code. | Spec: the Look paragraph's outline decision from the worktree diff (always on for fighters and weapons, props on High only; the built-in stencil outline was tried and not used).
- check: GUT tests pass, and the shader_check shot passes. | Look bench screenshots reviewed by eye: three bands, rim, outlines visible near and far. | The owner reviews the outline width; the old comparison shot showed 3 px fighter hulls barely visible. | npm test and npm run typecheck pass.
- depends: look-shader-check, mesh-kit
- stories: 46
- files: game/shaders/toon.gdshader, game/shaders/toon_light.gdshaderinc, game/shaders/outline.gdshader, game/shaders/look_noise.gdshaderinc, game/view/look/toon_materials.gd, game/view/look/look_palette.gd, game/view/look/look_noise.gd, game/tests/view/test_look.gd, game/tools/shot_scenes/look_bench.gd, game/tools/shot_scenes/look_bench.tscn, docs/specs/godot-rebuild.md
- notes: Salvage from the worktree's game/shaders and game/view/look. Do not bring stand_in_fighter.gd or shots/outline_compare.*.

### [16] ink-wash-pass (M): Ink-wash post pass and colour grade
- delivers: Shaders: game/shaders/ink_wash.gdshaderinc, ink_wash.gdshader and ink_wash_lite.gdshader. Fix their header comments: the normal-buffer variant is off on every preset. | Layers: distance mist, depth ink lines with jitter, dry-brush breaks and bleed, paper grain, brushy vignette. Premultiplied, never reads the screen colour. | game/view/look/ink_wash_pass.gd: a 2x2 quad at render priority -128 that picks its shader by quality and keeps parameters across a shader swap. | game/view/look/ink_grade.gd: the colour grade baked into a 24-cubed LUT in the Environment's adjustment_color_correction. | game/view/look/ink_night_environment.tres. | Tests: the pass picks its shader by quality and hides at OFF; parameters survive a swap; the grade keeps red and blue accents and settles blacks on ink; the LUT is 24-cubed; the environment is tuned. | The look bench gains the pass.
- check: GUT tests pass, and the shader_check shot passes. | Look bench screenshots with the pass OFF, LITE, LINES and FULL, reviewed: depth lines on silhouettes, grain and vignette weak in the middle of the screen. | npm test and npm run typecheck pass.
- depends: toon-material
- stories: 46
- files: game/shaders/ink_wash.gdshaderinc, game/shaders/ink_wash.gdshader, game/shaders/ink_wash_lite.gdshader, game/view/look/ink_wash_pass.gd, game/view/look/ink_grade.gd, game/view/look/ink_night_environment.tres, game/tests/view/test_look.gd, game/tools/shot_scenes/look_bench.gd
- notes: The old screenshots show the ink lines faint at gameplay distance. Tune line_strength and line_width_px with the owner here.

### [16] graphics-presets (M): Low, Medium and High presets, the graphics applier and a saved preset setting
- delivers: game/view/look/graphics_preset.gd and presets/low.tres, medium.tres, high.tres (High is the default). | Each preset sets: FXAA, glow off, shadow atlas and distance, outline classes and width, post quality, fog and height fog, particle ratio, minor lights, scenery detail. | game/view/look/graphics_applier.gd: applies a preset to the RenderingServer, a viewport and a tree, by node groups and outline classes. | game/core/game_settings.gd: the chosen preset id, saved to user://settings.cfg, owned by GameServices (game/core/game_services.gd) and applied to the root viewport at startup. Task 22's settings screen edits it later. | Tests: game/tests/view/test_graphics_presets.gd (from the worktree: three load, monotonic Low to High, fighters and weapons always outlined, each preset applies, height fog restored) and game/tests/core/test_game_settings.gd (save and load; an unknown id falls back to High). | Spec: the rest of the worktree's Look paragraph (presets' contents, FXAA, glow off, noise texture, the target laptop).
- check: GUT tests pass. | Look bench screenshots side by side at Low, Medium and High, reviewed. | npm test and npm run typecheck pass.
- depends: ink-wash-pass
- stories: 57, 46
- files: game/view/look/graphics_preset.gd, game/view/look/presets/low.tres, game/view/look/presets/medium.tres, game/view/look/presets/high.tres, game/view/look/graphics_applier.gd, game/core/game_settings.gd, game/core/game_services.gd, game/tests/view/test_graphics_presets.gd, game/tests/core/test_game_settings.gd, docs/specs/godot-rebuild.md
- notes: GraphicsApplier keeps a static _current. Make it read from GameSettings, or reset it in tests, so tests don't leak state into each other.

### [16] toon-standins (S): Put the match's stand-ins in the toon look
- delivers: FighterStandin (game/view/match/fighter_standin.gd) builds torso, hood, belt, nose, arms, blades and hilts with ToonMaterials.fighter or weapon, on render layers 1 and LookPalette.FIGHTER_LAYER, so the shrine's rim light reaches them. | The body hit flash and the blade glow drive the toon shader's emission_color and emission_energy instead of StandardMaterial3D emission. | The dropped weapon's blades in MatchView._make_dropped (game/view/match/match_view.gd) use the toon weapon material. | StandinArena (game/view/match/standin_arena.gd) uses ToonMaterials props, adds an InkWashPass and applies the current preset. | A test that every FighterStandin surface is toon, outlined and on the fighter layer (from the worktree's StandInFighter test). The worktree's StandInFighter is not brought over.
- check: Existing view tests pass, including the frame-timed body flash and the no-stray-nodes test. | The six skeleton shot scenes (game/tools/shot_scenes/skeleton_*.tscn) re-rendered and reviewed. | npm test and npm run typecheck pass.
- depends: graphics-presets
- stories: 46
- files: game/view/match/fighter_standin.gd, game/view/match/match_view.gd, game/view/match/standin_arena.gd, game/tests/view/test_match_scene.gd
- notes: The duel stays playable throughout. This is how the look reaches the match before tasks 14 and 15 put real fighters in it.

### [16] toon-real-fighters (M): Toon look on the Rogue, the Hunter and the three weapons
- delivers: FighterModel (game/fighters/fighter_model.gd from task 13) turns each outfit, skin, hair and headwear surface into a ToonMaterials.fighter material: albedo texture and normal map, palette overrides kept, outlined, on the fighter layer. | WeaponLook models (game/weapons/*) get ToonMaterials.weapon materials (steel, iron and leather .tres). | The katana's hamon blade and wrap shaders get toon variants that include toon_light.gdshaderinc. | Tests in game/tests/content: every fighter and weapon surface is toon, outlined and on layer 2, and the two palettes still differ (test_palettes.gd).
- check: Content tests pass. | Fighter preview lineup and mirror match from the gameplay camera, at Low and High, reviewed: no split outlines at mesh seams. | npm test and npm run typecheck pass.
- depends: toon-material, graphics-presets, 13
- stories: 43, 45, 46
- files: game/fighters/fighter_model.gd, game/weapons/weapon_look.gd, game/weapons/katana/katana_blade.gdshader, game/weapons/katana/katana_wrap.gdshader, game/weapons/materials/steel.tres, game/view/look/toon_materials.gd, game/tests/content/test_fighters.gd, game/tests/content/test_weapons.gd
- notes: Needs task 13 merged. If hull outlines split at the Quaternius seams, bake smoothed normals into CUSTOM0 at import (task 13's tools), as MeshKit does.

### [17] arena-data (S): Arena data (ArenaDef) and a radius guard in ArenaScenes
- delivers: game/arenas/arena_def.gd and game/arenas/moonlit_shrine/moonlit_shrine.tres from the worktree, fixed: | - music_track_id is &"battle" (MusicDirector) and ambience_id is &"ambience_shrine" (SoundBank), instead of the nonexistent &"battle_140" and &"shrine_night"; | - validate() defaults to SimConst.FIGHTER_RADIUS; | - camera_bounds and clamp_camera are removed, since CameraRig clamps by camera_max_radius; | - the environment is left unset until the sky task. | ArenaScenes (game/view/match/arena_scenes.gd) maps each id to its ArenaDef. It uses the arena's scene only when that scene exists and walkable_radius equals SimConst.ARENA_RADIUS; otherwise it uses the stand-in. | With that guard, the shrine can't put the rules' 11.5 m wall inside its 15.3 m parapet before task 8. | game/tests/view/test_arena_def.gd, fixed: spawns at ±3.2 facing each other as World.reset_round places them; gates beyond the spawns; the wall outside the walkable circle; the sound and music ids exist; the starting camera from CameraRig.follow_target within camera_max_radius. | test_match_scene's fallback test updated.
- check: GUT tests pass, including a test that an arena whose walkable radius differs from SimConst.ARENA_RADIUS falls back to the stand-in. | npm test and npm run typecheck pass.
- depends: 6
- stories: 15, 63, 11
- files: game/arenas/arena_def.gd, game/arenas/moonlit_shrine/moonlit_shrine.tres, game/view/match/arena_scenes.gd, game/tests/view/test_arena_def.gd, game/tests/view/test_match_scene.gd
- notes: Recommended answer to how the shrine lands before task 8; see open questions. ArenaDef already matches MatchView.arena_camera_data's by-name reads and the Spawn/Gate marker seams.

### [17] arena-shot-rig (M): Arena screenshot rig on the match host and CameraRig
- delivers: game/tools/shot_scenes/arena_shot.gd, rebuilt from the worktree's arenas/moonlit_shrine/shots/arena_shot.gd: | - a MatchHost stepped without the clock, as skeleton_shot.gd does; | - the ArenaDef's scene put in with MatchView.set_arena, so the shrine can be shot before task 8; | - FighterStandin at the spawns; | - views: CameraRig FOLLOW, WATCH and MENU, plus the worktree's establishing view (58 m out, 5 m below the floor) and its top-down debug overlay (walkable radius, fighter centre limit, parapet face, spawns, gates); | - a preset_id export. | Scenes: arena_gameplay, arena_watch, arena_menu, arena_establishing and arena_top_down .tscn in game/tools/shot_scenes/. | Until the shrine lands it shoots the stand-in arena.
- check: Screenshots of the stand-in arena from every view, reviewed. | npm test and npm run typecheck pass.
- depends: arena-data, toon-standins
- stories: 65, 54, 2
- files: game/tools/shot_scenes/arena_shot.gd, game/tools/shot_scenes/arena_gameplay.tscn, game/tools/shot_scenes/arena_watch.tscn, game/tools/shot_scenes/arena_menu.tscn, game/tools/shot_scenes/arena_establishing.tscn, game/tools/shot_scenes/arena_top_down.tscn
- notes: The bench mode comes later, in shrine-preset-bench. The old rig placed its own camera at 0.9 m right and 2.2 m up; the real camera now sits 1.35 m right and 1.95 m up.

### [17] shrine-courtyard (M): Moonlit Shrine scene: courtyard floor, parapet, gate landings and markers
- delivers: game/arenas/moonlit_shrine/moonlit_shrine.gd and .tscn: a copy of the environment, the moon key light, the fighter-only red rim light, the ink-wash pass, the current preset applied, and Spawn0/1 and Gate0/1 markers. Calls to the underside, backdrop and ambience builders wait for their tasks. | shrine_layout.gd and moonlit_shrine_layout.tres. | From ShrinePlatform: the floor with shaders/stone_floor.gdshader, the plinth, the parapet (posts, rails, broken rails, damaged posts), the gate landings, the gate rope barriers and the pebbles. | A plain night environment until the sky task. | Tests from test_moonlit_shrine.gd: parts present; markers match the ArenaDef; posts and ropes outside the walkable circle; only pebbles inside; floor at y = 0 under both spawns; exactly one ink pass; rim light on the fighter layer only; the environment is a copy.
- check: GUT tests pass, and the shader_check shot passes. | arena_gameplay, arena_watch and arena_top_down shots reviewed. | npm test and npm run typecheck pass.
- depends: arena-shot-rig, graphics-presets, mesh-kit
- stories: 15, 46, 47
- files: game/arenas/moonlit_shrine/moonlit_shrine.gd, game/arenas/moonlit_shrine/moonlit_shrine.tscn, game/arenas/moonlit_shrine/shrine_layout.gd, game/arenas/moonlit_shrine/moonlit_shrine_layout.tres, game/arenas/moonlit_shrine/shrine_platform.gd, game/shaders/stone_floor.gdshader, game/tests/view/test_moonlit_shrine.gd
- notes: Because of the radius guard, matches keep using the stand-in until task 8. Only the shot rig shows the shrine for now.

### [17] shrine-props (M): Torii, stone lanterns, pillars, trees and debris
- delivers: game/arenas/moonlit_shrine/shrine_props.gd: lantern, torii, shimenawa, pillar, pine, dead tree, pagoda, temple hall. | ShrinePlatform's torii, lanterns, pillars, trees and debris. | Lantern lights: group look_minor_light, LookPalette.SMALL_LIGHT_MASK (they skip the ground layer), with MoonlitShrine's flicker. | Lantern halos (shaders/particle_glow.gdshader) and shaders/lantern_glow.gdshader. | The ShrineLayout.prop_scenes override seam for bought art. | Tests: every lantern has a light that skips the ground layer and lights fighters; nothing but pebbles inside the walkable circle; a PackedScene in prop_scenes[&"lantern"] replaces the procedural lantern at the same spots; prop outlines follow the preset (High only).
- check: GUT tests pass, and the shader_check shot passes. | Gameplay and watch shots at High and Medium, reviewed. | npm test and npm run typecheck pass.
- depends: shrine-courtyard
- stories: 47, 63, 46
- files: game/arenas/moonlit_shrine/shrine_props.gd, game/arenas/moonlit_shrine/shrine_platform.gd, game/arenas/moonlit_shrine/moonlit_shrine.gd, game/shaders/lantern_glow.gdshader, game/shaders/particle_glow.gdshader, game/tests/view/test_moonlit_shrine.gd

### [17] shrine-underside (M): Rocky underside, roots, chains and floating rocks
- delivers: game/arenas/moonlit_shrine/shrine_underside.gd: the ledge, the inverted crag, hanging roots, chains into the clouds, and floating rocks that bob. | shaders/rock.gdshader. | MoonlitShrine.sees_below_deck and the below-deck hiding. | Tests: the ledge is on the ground layer; the rock under the rim is hidden only from cameras above the courtyard, using CameraRig.follow_target and watch_target positions instead of the old offsets.
- check: GUT tests pass, and the shader_check shot passes. | arena_establishing and arena_top_down shots reviewed. | npm test and npm run typecheck pass.
- depends: shrine-courtyard
- stories: 47
- files: game/arenas/moonlit_shrine/shrine_underside.gd, game/arenas/moonlit_shrine/moonlit_shrine.gd, game/shaders/rock.gdshader, game/tests/view/test_moonlit_shrine.gd
- notes: The below-deck hiding reads one camera (get_viewport().get_camera_3d()). Leave a note for task 23's split screen.

### [17] shrine-sky (S): Night sky and blood moon
- delivers: shaders/sky_moonlit.gdshader (no TIME, so its radiance renders once). | moonlit_shrine_env.tres, set as ArenaDef.environment. | MoonlitShrine syncs the sky's moon direction from ShrineLayout. | Tests: the moon rises ahead of player one; the environment uses the sky with fog and height fog.
- check: GUT tests pass, and the shader_check shot passes. | Gameplay and watch shots reviewed; the owner signs off on the red moon. | npm test and npm run typecheck pass.
- depends: shrine-courtyard
- stories: 47, 46
- files: game/shaders/sky_moonlit.gdshader, game/arenas/moonlit_shrine/moonlit_shrine_env.tres, game/arenas/moonlit_shrine/moonlit_shrine.tres, game/arenas/moonlit_shrine/moonlit_shrine.gd, game/tests/view/test_moonlit_shrine.gd

### [17] shrine-backdrop (M): Sea of clouds, mountains, cliff pagodas, waterfalls and the lake
- delivers: game/arenas/moonlit_shrine/shrine_backdrop.gd: two cloud-sea layers, mountain silhouette rings, cliff spires with pagodas and temple halls, waterfalls into mist, a far lake. | Shaders: cloud_sea, mountain_layer, waterfall, lake_water, mist_puff. | Scenery detail levels (meta look_detail, group look_scenery_detail) for the presets. | Tests: camera_far reaches the farthest mountain ring and the lake, and CameraRig takes it (far = 3000); mist and far detail follow scenery_detail at each preset.
- check: GUT tests pass, and the shader_check shot passes. | Gameplay, watch, menu and establishing shots at Low, Medium and High, reviewed. | npm test and npm run typecheck pass.
- depends: shrine-sky, shrine-props, graphics-presets
- stories: 47, 46, 57
- files: game/arenas/moonlit_shrine/shrine_backdrop.gd, game/shaders/cloud_sea.gdshader, game/shaders/mountain_layer.gdshader, game/shaders/waterfall.gdshader, game/shaders/lake_water.gdshader, game/shaders/mist_puff.gdshader, game/arenas/moonlit_shrine/moonlit_shrine.gd, game/tests/view/test_moonlit_shrine.gd

### [17] shrine-embers-ash (S): Drifting embers and ash
- delivers: game/arenas/moonlit_shrine/shrine_ambience.gd: embers from each lantern, embers carried up past the edge, ash falling across the courtyard. All in group look_particles. | shaders/particle_flake.gdshader. | The worktree's petals only if the owner keeps them. | Tests: one ember emitter per lantern; ash and embers follow each preset's particle ratio. | Built in 17.8 as game/arenas/moonlit_shrine/shrine_particles.gd (ShrineParticles, under Particles), since "ambience" names the arena's sound bed; see the plan's Done notes.
- check: GUT tests pass, and the shader_check shot passes. | Gameplay and watch shots at High and Low, reviewed. | npm test and npm run typecheck pass.
- depends: shrine-props
- stories: 47, 57
- files: game/arenas/moonlit_shrine/shrine_ambience.gd, game/shaders/particle_flake.gdshader, game/arenas/moonlit_shrine/moonlit_shrine.gd, game/tests/view/test_moonlit_shrine.gd

### [17] shrine-preset-bench (S): Preset benchmark and side-by-side preset shots of the shrine
- delivers: The worktree's bench mode moved into arena_shot.gd: interleaved rounds, average and p95 frame time, GPU and CPU render times, SHOT_BENCH and SHOT_RES overrides. | game/tools/shot_scenes/arena_bench.tscn. | A bench run at 1080p on the target laptop (Ryzen 7 4700U, Radeon Vega), with the toon stand-ins, and with the real fighters too if toon-real-fighters is done. | Presets tuned if High drops under 60 fps. | Numbers recorded in the spec's Look paragraph and the plan.
- check: High averages at least 60 fps at 1080p. The old run with capsules: 61-63 fps, p95 17-21 ms. | Gameplay shots at the three presets side by side, reviewed. | npm test and npm run typecheck pass.
- depends: shrine-backdrop, shrine-underside, shrine-embers-ash
- stories: 57
- files: game/tools/shot_scenes/arena_shot.gd, game/tools/shot_scenes/arena_bench.tscn, docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md (17.9 also touched game/tools/shot.gd, game/tests/view/test_arena_shot.gd and game/view/look/graphics_preset.gd)
- notes: Re-run after task 18's effects land; the old margin over 60 fps was thin. | Built in 17.9: the bench plays a live computer duel from the view's camera, restarted at the start of the fight for every entry, and takes overrides as `<setting>=<value>` and `hide=<path>` in place of the worktree's hard-coded list; command-line args (`--bench=`, `--bench-passes=`, `--bench-frames=`, `--bench-res=`; the task's rounds are passes in the code, since a Round is the match's) in place of SHOT_BENCH and SHOT_RES, as 17.2 did for the preset and the arena. High measured 69 fps (gameplay) and 66 fps (Watch) with the real fighters; see the plan's Done notes.

### [17] shrine-radius-check (S): Radius check and the shrine as the default arena (after task 8)
- delivers: With task 8's SimConst.ARENA_RADIUS = 15: | - test_arena_def asserts walkable_radius == SimConst.ARENA_RADIUS; | - the ArenaScenes guard lets the shrine in, so every match defaults to it. | A headless computer-vs-computer match on the shrine checks that: | - no fighter centre passes ARENA_RADIUS - FIGHTER_RADIUS; | - a fighter never overlaps the parapet's inner face (15.075 m); | - dropped weapons bounce inside the parapet (world.gd uses ARENA_RADIUS - 0.8). | A gameplay-camera check with the player against the parapet: within camera_max_radius 19.5 the camera must not pass through lanterns (17.4 m), pillars (18.7-19.4 m) or trees (about 20 m). Lower camera_max_radius or move props if it does. | View tests that don't need the shrine start on ArenaScenes.STANDIN, to keep the test run fast.
- check: GUT tests pass. | Shots at the wall and the top-down debug view, reviewed. | Frame time within budget (arena_bench). | npm test and npm run typecheck pass.
- depends: 8, shrine-courtyard, shrine-props, shrine-preset-bench
- stories: 15, 11
- files: game/tests/view/test_arena_def.gd, game/tests/view/test_moonlit_shrine.gd, game/tests/view/test_match_scene.gd, game/tests/view/test_main_flow.gd, game/arenas/moonlit_shrine/moonlit_shrine.tres

### [18] effects-layer (M): Combat effects layer on the match clock
- delivers: game/view/effects/combat_effects.gd, a child of MatchView: | - pooled one-shot flashes and rings; | - a particle pool (a MultiMesh stepped in GDScript) for sparks, dust and splashes; | - an effect clock of world.frame + host.alpha(), so effects hold through hit-stop and pause and slow down with slow motion; | - a clear on roundStart, the preset's particle ratio, and a flash_scale hook. | game/view/effects/effect_table.gd: data mapping each event to its effects, starting with the contact flashes task 6 has now. | MatchView._spawn_flash, _update_flashes and _clear_flashes replaced. | Tests written first: | - test_a_contact_flash_holds_through_its_hit_stop, moved from test_match_scene; | - effects stand still while paused; | - effects advance at 0.3x during the KO slow motion; | - cleared at roundStart; | - no stray nodes after a rematch; | - particle counts scale with the preset.
- check: GUT tests pass. | skeleton_exchange and skeleton_parry shots re-rendered: effects visible and deterministic between runs. | npm test and npm run typecheck pass.
- depends: graphics-presets, toon-standins
- stories: 48, 49, 19
- files: game/view/effects/combat_effects.gd, game/view/effects/effect_table.gd, game/view/match/match_view.gd, game/tests/view/test_combat_effects.gd, game/tests/view/test_match_scene.gd
- notes: Most game feel is done by task 6: hit-stop, slow motion, shake and FOV kicks. This layer makes effects obey the same clock. Shot scenes stop processing once snapped, so effects must freeze too.

### [18] sparks-ink-splashes (M): Sparks and ink splashes on hits, blocks and bounces
- delivers: Effect-table entries: | - hit: warm sparks 36 heavy / 18 light; a dark-red ink splash 22/12 in place of the demo's blood; grey dust for fists; a ground dust ring 0.3 to 2.6 m for colossal hits; a purple flash for backstabs; | - block: sparks 40/22 (#ffd890) and a flash (#fff0c0); | - weaponBounce: 10 sparks. | Ink droplets are normal-blended with an ink droplet shader. | Everything is placed at the event's pos, which becomes the blade contact point when task 7 lands.
- check: Table tests pass: counts by heavy and sound; splashes fall and settle on the floor. | Shot scenes effects_hit_light, effects_hit_heavy, effects_block and effects_colossal from the gameplay camera, reviewed. | npm test and npm run typecheck pass.
- depends: effects-layer
- stories: 48, 19
- files: game/view/effects/effect_table.gd, game/view/effects/combat_effects.gd, game/shaders/ink_droplet.gdshader, game/tools/shot_scenes/effects_shot.gd, game/tests/view/test_combat_effects.gd

### [18] trail-state (S): Trail rules: when a blade leaves a trail, and in which colour
- delivers: game/view/effects/trail_state.gd: per fighter and hand, an intensity from 0 to 1 and a kind. | - On during the active frames, plus about 2 frames of fade (spike critique fix 10). | - None while charging or for the Flash special. | - Danger for unblockables (def.unblockable or def.trail == &"danger"). | - Ult for ultimate moves and phases (def.trail == &"ult", the ult phases that trail in src/render/pose.ts). | - Normal otherwise. | - Both hands for the daggers.
- check: GUT tests written first (game/tests/view/test_trail_state.gd), driving a World through a katana light, a greatsword unblockable, a charged heavy and an ultimate. | npm test and npm run typecheck pass.
- depends: 6
- stories: 48, 22
- files: game/view/effects/trail_state.gd, game/tests/view/test_trail_state.gd

### [18] brush-trails (M): Brush-stroke weapon trails in white, red and gold
- delivers: game/view/effects/weapon_trail.gd and shaders/brush_trail.gdshader: a tapered, ink-edged ribbon over the blade's last trail_width metres up to the tip. | Width from WeaponLook.trail_width (0.5 m) or StickPose.LENGTH on stand-ins. The ribbon never covers the attacker's torso. | Sampled on the effect clock with sub-frame alpha. | Colours: white #dfe6ff, red #ff3020, gold #ffc040. | FighterStandin exposes blade_segments(): base and tip per hand in world space. | Two trails per fighter for the daggers.
- check: GUT tests: the ribbon exists only while TrailState is on, stays outside the attacker's body capsule, and freezes in hit-stop. | Shots of a katana light, a greatsword unblockable and a Moonsplitter from the gameplay camera, reviewed. | npm test and npm run typecheck pass.
- depends: trail-state, effects-layer, toon-standins
- stories: 48, 22, 16
- files: game/view/effects/weapon_trail.gd, game/shaders/brush_trail.gdshader, game/view/match/fighter_standin.gd, game/view/match/match_view.gd, game/tests/view/test_weapon_trail.gd
- notes: The real fighters (tasks 14 and 15) supply blade_segments() from the WeaponLook BladeBase and BladeTip markers.

### [18] parry-ring-push-in (S): Parry ring, sparks and a camera push-in
- delivers: Parry entry: a camera-facing ring growing from 0.1 to 0.8 (parry #fff2c0, flash #9ad8ff, redirect #7affd6), 60 sparks and a flash. | CameraRig.push_in(amount): a short dolly toward the look point over about 6 world frames, easing back over about 20, frozen in hit-stop, with a push_in_scale hook. | Task 6's FOV kick stays: 3, or 5 for flash and redirect. | Both weapons rebounding is task 15's.
- check: GUT tests: push_in moves the rig toward rig_look and settles back on the follow target; a parry event spawns the ring and the push-in. | skeleton_parry shot re-rendered and reviewed. | npm test and npm run typecheck pass.
- depends: sparks-ink-splashes
- stories: 40, 49
- files: game/view/match/camera_rig.gd, game/view/effects/effect_table.gd, game/tests/view/test_camera_rig.gd, game/tests/view/test_combat_effects.gd

### [18] warning-mark (M): Warning mark and reach effect for unblockables
- delivers: On telegraph, a billboard mark over the attacker's head: | - 危 with THRUST, SWEEP or SLAM in red; 奥義 ULTIMATE in gold; | - no depth test, pops in, follows FighterStandin.head_position(); | - lasts the move's startup plus 7 frames on the effect clock, or 48 frames for ultimates. | A flash above the head. | The reach effect: a red ink arc on the floor spanning the move's range and arc (AttackDef.range and arc; from the swing after task 7) during the wind-up. | The kanji font bundled (Zen Antique, OFL) under game/ui/fonts.
- check: GUT tests: text and colour per kind; life in world frames; the mark follows the head; the reach arc's radius equals the move's range. | Shots of thrust, sweep and slam wind-ups and an ultimate call from the gameplay camera, reviewed. | npm test and npm run typecheck pass.
- depends: effects-layer
- stories: 42, 22
- files: game/view/effects/warning_mark.gd, game/view/effects/reach_arc.gd, game/view/match/fighter_standin.gd, game/ui/fonts/ZenAntique-Regular.ttf, game/tests/view/test_warning_mark.gd

### [18] ult-aura (S): Ultimate-ready aura
- delivers: Rising embers around a fighter while can_ult() and not KO, on the particle pool. Side colours as the demo: red #ff5a20, blue #40c8ff. | Off at KO, at roundStart and once the ultimate is used.
- check: GUT test: the aura is on exactly when can_ult() and not KO. | Shot with one fighter at or under 25% HP, reviewed. | npm test and npm run typecheck pass.
- depends: effects-layer
- stories: 48
- files: game/view/effects/combat_effects.gd, game/tests/view/test_combat_effects.gd

### [18] ult-effects (M): Ultimate effects: rings, Moonsplitter wave, Impaler burst, Tempest lightning
- delivers: ultStart: gold ground ring 0.3 to 3.2 m and a flash. | ultChoice: a jade ground ring. | ultWave: a crescent, vertical radius 1.6 or horizontal radius 9, starting 0.6 m ahead and travelling at World.WAVE_SPEED (30) out to WAVE_RANGE (26). | ultDash: dust. | ultImpale: a red ink burst at the target. | ultBurst: flash 2.4, a camera ring, a ground ring to 6 m, 220 sparks. | ultLightning: a jittered 14-point bolt and two flashes. | Camera shakes and kicks stay in MatchView.
- check: GUT tests: the wave stands at 0.6 + 30·n/60 m along its yaw after n frames and is gone at 26 m; each ult event spawns its effect. | Shots of each ultimate, reviewed. | npm test and npm run typecheck pass.
- depends: sparks-ink-splashes
- stories: 48, 30, 34, 39
- files: game/view/effects/effect_table.gd, game/view/effects/ult_wave.gd, game/view/effects/lightning_bolt.gd, game/tests/view/test_combat_effects.gd

### [18] counter-disarm-status (M): Counter, disarm, KO and status flashes; movement dust
- delivers: Counter: flash #9ad8ff, ground ring 0.3 to 2.4 m, 50 sparks, dust except for leap. | Disarm: white flash 1.4, a ring, 110 sparks. | KO: a white flash on the loser. | Status flashes: evade blue, stagger yellow above the head, counterReady blue, backstabReady purple, recall and pickup at the right hand. | Dodge, jump and land dust.
- check: Effect-table tests pass. | Shots of a stomp counter, a disarm and a KO, reviewed. | npm test and npm run typecheck pass.
- depends: sparks-ink-splashes
- stories: 41, 48
- files: game/view/effects/effect_table.gd, game/tests/view/test_combat_effects.gd

### [18] dropped-weapon-marker (S): Dropped-weapon beam and ground marker
- delivers: Task 6's MatchView._make_dropped restyled: an additive column 3.5 m tall (0.05 to 0.25 m radius) and a pulsing ground ring in the owner's colour while grounded. | The weapon drawn with its toon model through WeaponLook once task 13 is merged, the stick stand-in otherwise. The daggers lie as a pair. | Removed on pickup, recall and roundStart.
- check: GUT tests: beam and ring only while grounded; removed on pickup; the pulse runs on the effect clock. | Shot after a disarm, reviewed. | npm test and npm run typecheck pass.
- depends: effects-layer, toon-standins
- stories: 48
- files: game/view/match/match_view.gd, game/tests/view/test_match_scene.gd
- notes: The HUD's screen-edge marker for the dropped weapon is task 24's.

### [18] reduce-flashes (S): Reduce flashes and shaking option
- delivers: GameSettings.reduce_flashes, saved, default off. | Applied at match start and whenever it changes: | - CameraRig.shake_scale 0.15 and fov_kick_scale 0 (task 6's hooks); | - push-in scale 0; | - effects flash_scale 0.45 (the demo's numbers). | The settings-screen toggle is task 22's.
- check: GUT tests: with the option on, a parry makes no FOV kick and no push-in, shake is scaled by 0.15 and flashes by 0.45; the setting saves and loads. | npm test and npm run typecheck pass.
- depends: parry-ring-push-in, graphics-presets
- stories: 57
- files: game/core/game_settings.gd, game/view/match/match_view.gd, game/view/effects/combat_effects.gd, game/tests/core/test_game_settings.gd, game/tests/view/test_combat_effects.gd

### [18] effects-parity-check (S): Effect parity check against the demo's event table
- delivers: A test that every SimEvents.TYPES entry either has an effect-table entry or is on an explicit no-visual list: | - swing and step: sound only; | - ultReady, fight, roundOver and matchOver: HUD; | - whiff and parryEarly: unused; | - roundStart: clears effects. | The test also covers the camera shake and FOV amounts per event. | An effects shot series (game/tools/shot_scenes/effects_*.tscn) at High and Low. | After task 15, the series re-shot on the real fighters with the parry rebound.
- check: GUT tests pass. | Shot series reviewed. | npm test and npm run typecheck pass.
- depends: sparks-ink-splashes, brush-trails, parry-ring-push-in, warning-mark, ult-aura, ult-effects, counter-disarm-status, dropped-weapon-marker, reduce-flashes, 15
- stories: 48, 49, 40, 65
- files: game/tests/view/test_effect_parity.gd, game/tools/shot_scenes/effects_shot.gd
- notes: Only the final re-shoot needs task 15. The test can run as soon as the other effect tasks are in.

## Open questions
- How should the shrine land before task 8 sets the radius? Today, the moment moonlit_shrine.tscn exists, ArenaScenes makes it every match's arena while the rules' wall is still at 11.5 m, inside a parapet at 15.3 m. Recommended: the ArenaScenes guard in arena-data (use an arena only when its walkable_radius equals SimConst.ARENA_RADIUS). The alternatives are holding the scene back until task 8, or reading the radius from SimConst.
- The plan blocks task 18 on task 15. Recommended: build the effects on the stand-ins once 16 is done (they key off event positions, the head and blade segments), and keep only the final re-shoot on real fighters (effects-parity-check) behind 15.
- Combat particles: GPUParticles3D (the recon's verdict) or a MultiMesh pool stepped in GDScript on the match clock? Recommended: the MultiMesh pool for combat effects. It is deterministic for screenshots, testable headless, and freezes through hit-stop and pause and slows with slow motion for free. Keep GPUParticles3D for the ambient embers and ash.
- Where do settings live? Recommended: a small GameSettings in game/core owned by GameServices, started by graphics-presets (preset id) and extended by reduce-flashes. Task 22 builds the screen, and task 20 adds the volumes.
- What is the 'reach effect' for unblockables? Recommended: a red ink arc on the floor showing the move's range and arc during the wind-up, alongside the warning mark and the red trail that story 22 names.
- The parry 'push-in': task 6's FOV kick already narrows the view. Recommended: also add a short dolly toward the contact (about 0.3-0.5 m), scaled to zero by reduce-flashes, because the spec lists push-in as its own beat.
- Font for the 危 and 奥義 marks: bundle Zen Antique now in warning-mark, or wait for task 22's bundled fonts? Recommended: bundle it now under game/ui/fonts and let task 22 reuse it.
- Petals in the ambience go beyond the plan's 'embers and ash'. Keep them (built and cheap) or drop them? Recommended: drop them unless the owner wants them. The worktree is gone (removed Oct 2, 2026), so here is its recipe, to rebuild in `ShrineParticles` beside the ash if the owner wants them: one GPUParticles3D "Petals", 28 particles, lifetime and preprocess 12 s, emitted from a box with half-extents (6, 3, 18) centred at (-14, 4, -4) upwind, scale 0.07-0.11, colour ramp from (0.9, 0.82, 0.8) through (0.92, 0.84, 0.82, 0.95) and (0.85, 0.72, 0.72, 0.9) to (0.8, 0.65, 0.65) fading in and out (the worktree's look palette called this pink `PETAL`, e6d6d2; today's `LookPalette` has no such entry), drawn with the ash's flake material at elongation 1.9 and spin 0.8. The worktree moved them with direction (1, 0, 0.3), 25° spread, 1-2 m/s, damping 0.1-0.3 and a gravity of (0.6 × wind.x, -0.22, 0.6 × wind.z), plus turbulence (1.2, 1.4). Rebuild the motion the way 17.8 moves the ash instead: through `_launch` at the layout's wind speed with a gentle fall, and no turbulence (17.8 found it erases the drift).
- The blood-red moon and the faint outlines and ink lines in the old screenshots need an owner look review. Recommended: keep the red moon, and widen the fighter hull (about 4 px) and the ink lines at the toon-material and ink-wash steps.
- Ultimate aura colour: side colours as the demo (red and blue), the fighter's palette accent, or ultimate gold? Recommended: side colours, since both sides can be the same fighter.
- Should combat effects follow the preset's particle ratio? The spec says presets turn particle counts down. Recommended: scale combat counts by max(ratio, 0.5) so Low still reads hits, and apply the full ratio to ambience.
- Where should shot scenes live? Recommended: game/tools/shot_scenes (task 6's convention) instead of arenas/moonlit_shrine/shots and view/look/shots.

## Risks
- Invisible wall: before task 8, the rules' 11.5 m wall sits inside the shrine's 15.3 m parapet if the scene lands unguarded.
- Test run time: if every view test builds the shrine (roughly 0.3 s each), the suite slows down. Tests that don't need it should use ArenaScenes.STANDIN.
- Shader errors aren't caught by CI or headless tests, because the dummy renderer never compiles shaders. Only windowed shots catch them, so look-shader-check must run before visual commits.
- Performance margin is thin. High measured 61-63 fps with capsules; skinned Quaternius fighters with outlines (a second draw pass) plus combat effects may push the target laptop under 60 fps. Re-bench after toon-real-fighters and after task 18. (17.9: with the real fighters fighting, High runs 69 fps from the gameplay camera, about 2 ms of headroom a frame (1.4 ms at the 95th percentile), and 66 fps from the Watch camera, about 1.5 ms (0.3 ms at the 95th percentile), for task 18's effects.)
- Inverted-hull outlines can split at hard-normal seams on the Quaternius outfits. MeshKit's CUSTOM0 smoothing only covers procedural meshes, so the real fighters may need smoothed normals baked at import.
- The camera clamp (19.5 m) lets the gameplay camera go past the parapet into the lantern, pillar and tree ring (17.4-20.6 m) when a fighter stands at the wall, so the camera can clip through props. (17.10: it did, all round the wall; the shrine's camera_max_radius is now 16.2 m.)
- Fighters must be on render layer 2 for the shrine's rim light. FighterStandin and task 13's FighterModel aren't today.
- GraphicsApplier._current, InkGrade's LUT cache and LookNoise's texture are static, so state can leak between tests.
- Salvage hazards: the worktree is uncommitted and based on 67265af. Copy only the listed new files, never game/_probe, never merge the branch, and never carry its premature [x] on task 16. Remove the worktree only after the last piece is salvaged.
- Effects timed on whole world frames step at 60 Hz on high-refresh displays unless the clock adds host.alpha().
- The single ink-wash quad assumes one camera, so task 23's split screen needs a per-viewport answer. (The below-deck hiding is per camera since 17.5: `MoonlitShrine.cull_below_deck`.)
- Effect positions use the demo's event pos until task 7 sends the blade contact point, so sparks and rings will move when task 7 lands. The reach arc likewise switches from AttackDef.range and arc to swing-derived values.
