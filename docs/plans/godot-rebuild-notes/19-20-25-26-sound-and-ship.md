> Research notes from the Oct 1, 2026 task breakdown, a snapshot of the code at 51dcfb0.
> The plan (`docs/plans/godot-rebuild.md`) is the source of truth: its task ids, order and decisions
> supersede the proposals and keys here. Line numbers drift as the code changes.

# Sound and music playback (rest of plan tasks 19 and 20), and shipping (plan tasks 25 and 26)

## Current state
SOUND AND MUSIC (checked at c400858/51dcfb0 on feature/godot-rebuild)
- Built: data and logic only. Nothing in game/ creates an AudioStreamPlayer, AudioStreamPlayer3D or AudioListener3D (grep finds none), so nothing plays.
- game\audio\sound_bank.gd (class SoundBank, RefCounted, static):
  - CUES: about 50 cues. Each has a pool of files, volume_db, a pitch range, a bus (Combat, Foley, UI, Ambience or Music) and a spatial flag.
  - EVENTS: covers all 33 SimEvents types plus ui_move, ui_select, ui_confirm and ui_back.
  - DELAYS: ko gong at 0.1 s and body_fall at 0.6 s; counter taiko at 0.03 s; roundStart gong at 1.34 s.
  - Functions: cues_for(e), returning [{cue, delay, volume_db}]; paths_for; pick_variation(rng, last); random_pitch; all_event_cues.
  - Two cues are played directly, not from events: `footstep` ("follow the walk cycle") and `ambience_shrine` (loop).
  - Its doc says the player is "a later task".
- game\audio\music_director.gd (class MusicDirector, RefCounted):
  - enter_menu, enter_match, round_call and handle_event(roundOver, roundStart); signal track_changed.
  - track_info and track_path come from assets/audio/music/tracks.json, loaded as a JSON resource. seconds_to_next_bar is also there.
  - Its doc puts results on the menu track, and requires 10-20 ms fades because the loops start mid-signal.
- game\default_bus_layout.tres:
  - Master has a compressor (-14 dB, 4:1) and a hard limiter (-0.5 dB).
  - Music (-6 dB), Ambience, SFX and UI send to Master. Combat, Foley and Arena (-4 dB, reverb) send to SFX.
  - There is no sidechain or ducking anywhere.
  - Surprise: nothing can reach the Arena reverb bus. A Godot bus has one send, and Combat and Foley send to SFX. 3D players can only reach Arena through an Area3D's reverb_bus.
- Assets: game/assets/audio is 30.4 MB of 16-bit WAV.
  - Every import uses compress/mode=2 (QOA). Loop points come from the smpl chunk.
  - Surprise: game/assets/audio/sfx/amb_shrine_loop.wav is 10.58 MB, over the planned 10 MB CI guard.
  - The music files are 6.2, 4.8 and 4.2 MB.
- Tests:
  - game/tests/audio holds 31 GUT tests: test_sound_bank (every event has an entry, every file loads), test_music_director and test_bus_layout.
  - tests/audio/*.test.mjs holds 27 Node tests (Vitest, found through vite.config.ts). They check the scripts/audio tools and the committed files, including "stays under 40 MB". So the plan's 40 MB check already exists.
- The match side:
  - game\view\match\match_host.gd emits sim_event(e) once per rules event in world order, plus match_started, pause_changed and match_finished.
  - It has an `attract` flag and keeps stepping on the results screen. stop() emits nothing, but main.gd always follows it with start_attract().
  - MatchView and Hud are children in match_host.tscn. MatchView binds through host_path "..", and reads the arena root's `def` by name for camera data.
  - Event positions are {"x","y","z"} Dictionaries in rules space, which is Godot world space.
  - SimConst.ARENA_RADIUS is 11.5 (15 after task 8).
  - The fighter has pos, vel, state and airborne(). The `step` event is the tap step, not a walk footstep.
- game\core\game_services.gd (autoload) holds profiles, input, feed and begin_match/end_match. It has no audio and no settings.
  - ControlProfiles (game/input/control_profiles.gd) is the pattern for saving: load_from(path), save(), user://controls.cfg.
- game\scenes\main.gd runs title, menu (Duel/Watch/Quit), match, pause and results, with an attract duel behind the menus.
- Demo reference (src/audio/audio.ts, src/game.ts, src/ui/menus.ts):
  - Sound plays only in 'playing' and 'results'. The attract duel is silent apart from music.
  - The `step` event plays a footstep only for fighter 0.
  - Volumes are master 0.8, sfx 0.9 and music 0.45, saved in localStorage 'monomachia.audio'. The sliders run 0-100 in steps of 5.
  - Music switches to 'fight' at startMatch and to 'menu' on quit; the results screen kept the fight music.
- Surprise in the uncommitted look-and-arena worktree (wf_c7f99fe5-f9a-1): game/arenas/arena_def.gd has a Sound group, and moonlit_shrine.tres sets ambience_id=&"shrine_night" and music_track_id=&"battle_140". Neither matches SoundBank's &"ambience_shrine" or MusicDirector's &"battle".

SHIPPING
- No export_presets.cfg exists anywhere.
  - scripts\godot.mjs already has `build`, which exports preset "Windows Desktop" to build/windows/Monomachia.exe (build/ is gitignored) and explains missing templates.
  - No npm script calls it; `npm run godot -- build` works. `npm run build` is still the web build.
- .github/workflows:
  - ci.yml is one ubuntu job: setup-godot 4.7.2 with include-templates false, npm ci, test, typecheck, the web build, and an upload of Monomachia.html. It has no soak, no export and no size guard, and takes about 1 min (last runs green).
  - release.yml builds the web game and attaches Monomachia.html when a release is published.
  - pages.yml is a manual web deploy.
  - On GitHub, no releases exist and Pages isn't enabled (the API returns 404), so deleting pages.yml takes nothing offline.
- pending-plan-changes.md:
  - Item 5 is done: godot.mjs finds Godot through GODOT, then PATH, then a gitignored .godot-path, and no longer scans Downloads.
  - Item 6 is NOT done: there is no check failing on tracked files over 10 MB, and no asset size print.
  - Item 7 is NOT done: .gitattributes lacks *.exr, *.blend, *.mp3 and *.tpz. Task 13's branch adds only *.bin.
  - Items 1-4 and 9-15 are already recorded in the plan and spec.
- The v0.1-web-mvp tag ALREADY EXISTS. It is annotated ("Web MVP (three.js) before the Godot rebuild"), points at master 76d4a09 and is already pushed to origin (git ls-remote shows it). No tagging task is needed.
- Licences and credits:
  - There is no LICENSE file at the repo root, yet SOURCES.md says the generated sounds "carry the repository's licence".
  - GUT's MIT licence is at game/addons/gut/LICENSE.md.
  - game/assets/CREDITS.md (Quaternius, CC0) arrives with task 13 (fcfb8d8), which adds about 42.6 MB of assets; the largest file is 8.1 MB.
  - The fonts aren't bundled yet (task 22).
- README.md and CLAUDE.md are entirely about the web version: three.js, src/sim, src/sim/moves, constants.ts, Vitest, `npm run soak -- 40`, Pages. The README embeds three web screenshots from docs/screenshots.
  - docs/mvp-spec.md isn't marked as a record yet. Its header still reads like the live spec, and CLAUDE.md says "its combat numbers match the code".
  - design.md line 5 already calls mvp-spec "the original web demo".
- Web files to delete:
  - Folders and pages: src/, index.html, vite.config.ts, tsconfig.json, and the tracked Monomachia.html (820 KB).
  - Web tests: tests/*.ts (combat, golden, helpers, match, regressions, ultimate).
  - Scripts: scripts/browser.mjs, make-artifact.mjs, counterlab.ts, soak.ts, port-fixtures.ts, sim-fixtures.ts and golden/.
  - Dependencies: three, @types/three, typescript, vite, vite-plugin-singlefile, tsx, @types/node and vitest.
- Files to keep: scripts/godot.mjs, scripts/audio/**, tests/audio/** (they need a runner once Vitest goes), and game/tests/fixtures/*.json as frozen data.
  - scripts/audio refers to src/audio/audio.ts only in comments and in the SOURCES.md text written by lib/sources.mjs.
- No runtime script references res://tools or res://tests, including task 13's tools. Only tools/js_format.gd has a class_name, and only tools use it. So the export can exclude tools/*, tests/* and addons/gut/*.
- project.godot: config/version="0.2.0", no custom user dir, the GUT editor plugin enabled.
- Prior research (recon-5): since Godot 4.5 the Windows icon and metadata are written without rcedit; the 4.7.2 templates are 1.28 GB; the Shader Baker avoids first-play stutter. recon-1 recommends ducking music with a compressor sidechain.

## Tasks

### [19] sound-player (M): Pooled sound player that plays sound bank cues
- delivers: game/audio/sound_player.gd (class SoundPlayer, Node). | Streams: cached per path, with optional preload_cues(list). | Voice pools: one of flat AudioStreamPlayer voices and one of AudioStreamPlayer3D voices, sizes exported. A full pool steals its oldest voice and never grows. | play_cue(cue, at, extra_db): | - picks a variation with SoundBank.pick_variation, remembering the last index per cue; | - picks a pitch with SoundBank.random_pitch; | - sets volume_db to the cue's level plus extra_db, and the cue's bus; | - uses a 3D voice at `at` when the cue is spatial and a position is given, else a flat voice. | play_event(e, position_resolver): expands one rules event through SoundBank.cues_for and queues its delayed cues. | advance(delta), also run from _process when auto_run, fires delayed cues when due. | set_held(bool): pauses voices (stream_paused) and the delay clock. | stop_all(): clears voices and pending cues. | An injectable RandomNumberGenerator. | A `played(cue, path, position)` signal. | A `missing` list: any path that fails to load is recorded and reported with push_error once.
- check: New GUT file game/tests/audio/test_sound_player.gd: | - a colossal hit requests hit_colossal and crunch on Combat; | - the ko gong (0.1 s), the body fall (0.6 s) and the roundStart gong (1.34 s) fire only once advance() passes their delay, and never while held; | - no cue repeats its last variation; | - a full pool steals its oldest voice; | - a spatial cue with a position gets a 3D voice at that point, and parry_ring gets a flat one; | - an unknown event plays nothing; | - `missing` stays empty for the real bank. | npm test and npm run typecheck pass.
- depends: 
- stories: 50, 63
- files: game/audio/sound_player.gd, game/tests/audio/test_sound_player.gd
- notes: Headless runs use the dummy audio driver, so the tests assert on the player's state and signals (voice, stream, bus, volume_db, pitch_scale, global_position), not on audio output. Attenuation stays at the defaults here; impacts-in-3d tunes it. Keep the class free of match knowledge: the same player serves menu sounds.

### [19] match-sound-events (M): Play the rules events' sounds in a match
- delivers: game/view/match/match_audio.gd (class MatchAudio, Node3D), added to match_host.tscn as `Audio` beside View and Hud. It binds to the host through host_path "..", as MatchView does. | It owns a SoundPlayer and listens to sim_event, match_started and pause_changed. | It plays every event's cues in played matches (Duel, Training, Watch, Versus) and on the results screen. The attract duel stays silent, as in the demo. | Sounds and pending delayed cues hold while the match is paused. | Everything stops when a new match (or the attract duel after a quit) starts. | All cues play flat for now.
- check: New GUT file game/tests/view/test_match_audio.gd: | - a scripted Duel driven by host.step() plays the roundStart, swing and hit/block cues in the world's event order; | - the attract duel plays nothing; | - a pause holds the pending roundStart gong until resume; | - quitting to the menu leaves no voice playing or pending; | - rematches leave no stray nodes (as test_rematches_and_restarts_leave_no_stray_nodes). | `npm run godot:run`: a Duel has sound. | npm test and npm run typecheck pass.
- depends: sound-player
- stories: 50, 19, 40
- files: game/view/match/match_audio.gd, game/view/match/match_host.tscn, game/view/match/match_host.gd (the doc comment says the audio listens 'later'), game/tests/view/test_match_audio.gd
- notes: MatchHost.stop() emits no signal. main.gd.quit_to_menu() calls stop() then start_attract(), whose match_started(attract) is where MatchAudio stops everything. If that proves fragile, add a `stopped` signal to MatchHost in this task. Recommended pause behaviour: hold SFX and delayed cues, and let ambience and music carry on (see open questions).

### [19] impacts-in-3d (M): Place impacts and fighter sounds in 3D, with the arena reverb
- delivers: MatchAudio gives each event a position: | - the event's `pos` for hit, block, parry, counter, disarm, ultWave, ultBurst and weaponBounce; | - `to` for ultLightning; | - otherwise the position of the fighter the event names (f, attacker, parrier, victim, loser, owner, by), at chest height, from host.display_position. | Spatial cues play from 3D voices there. Flat cues (parry_ring, telegraph, the calls, boom) stay flat. | Attenuation is exported and gentle, so the opponent 2.5-15 m away stays clearly audible and the hits mostly pan. | An explicit AudioListener3D follows the view camera, so Versus (task 23) can choose its listener. | An Area3D covers the arena, sized from SimConst.ARENA_RADIUS plus a margin, with reverb_bus_enabled to the Arena bus. Today nothing reaches that bus.
- check: GUT, extending game/tests/view/test_match_audio.gd: | - a hit event at a known pos plays from a 3D voice at that Vector3; | - a dodge plays at the dodging fighter; | - a ko's taiko, gong and boom stay flat while its body_fall plays in 3D at the loser; | - the reverb area's bus is Arena and covers the arena radius; | - the listener is current and follows the camera. | By ear in a Duel: the opponent's hits come from the opponent's side. | npm test and npm run typecheck pass.
- depends: match-sound-events
- stories: 50
- files: game/view/match/match_audio.gd, game/audio/sound_player.gd (attenuation exports), game/tests/view/test_match_audio.gd
- notes: Field names per event are listed at the top of game/sim/events.gd. Positions come as {x,y,z} Dictionaries. Read the radius from SimConst.ARENA_RADIUS: it is 11.5 m now and 15 m after task 8. The camera sits about 4.6 m behind the player, so strong distance falloff would bury the opponent's sounds.

### [19] footsteps (S): Footsteps from the fighters' movement
- delivers: game/audio/footstep_cadence.gd (class FootstepCadence), pure logic. Per fighter, each rules step it adds the horizontal distance covered on the ground. Nothing counts while airborne(), dodging, knocked down or in hit-stop. | It reports a foot-down every stride. Stride lengths for guard walk, run and sprint are exported. | MatchAudio plays the `footstep` cue (6 variations, -16 dB, Foley) at that fighter's feet.
- check: New GUT file game/tests/audio/test_footstep_cadence.gd: | - walking a set distance gives distance/stride footsteps; | - standing, jumping and dodging give none; | - a frozen world.frame (hit-stop) gives none; | - variations never repeat back to back. | npm test and npm run typecheck pass.
- depends: impacts-in-3d
- stories: 50
- files: game/audio/footstep_cadence.gd, game/view/match/match_audio.gd, game/tests/audio/test_footstep_cadence.gd
- notes: The stand-in fighters have no walk cycle, so the cadence comes from distance. Task 14's locomotion should later trigger it from real foot contacts, so keep a 'foot down at position' interface. The rules' `step` event (tap step) keeps its step_scuff cue. The demo played footsteps only for side 0; this plays both, placed in 3D (see open questions).

### [20] music-player (M): Music player with 10-20 ms fades and crossfades
- delivers: game/audio/faded_loop.gd (class FadedLoop): one AudioStreamPlayer that fades in on start and out before stop. The fade is exported, 15 ms by default. Ambience reuses it. | game/audio/music_player.gd (class MusicPlayer, Node): two FadedLoops on the Music bus. | - play(track) loads MusicDirector.track_path(track), fades in, and crossfades from the current track; | - stop() fades out, then stops the stream; | - playing the track already playing does nothing; | - bind(director) follows track_changed; | - advance(delta) for tests.
- check: New GUT file game/tests/audio/test_music_player.gd: | - the gain reaches full and silence within 10-20 ms of advance(); | - a switch overlaps the two tracks with no silent gap; | - the stream is stopped only after its fade ends; | - the same track isn't restarted; | - the player follows a director's track_changed. | One windowed capture (AudioEffectCapture or AudioEffectRecord on the Music bus) of a start, a stop and a switch shows no click. | npm test and npm run typecheck pass.
- depends: 
- stories: 51
- files: game/audio/faded_loop.gd, game/audio/music_player.gd, game/tests/audio/test_music_player.gd
- notes: _process runs about every 16.7 ms, longer than the fade, so a per-frame tween can't shape a 15 ms ramp. Measure whether Godot's per-mix-buffer volume ramp is enough. If it isn't, do the fade on the audio thread, for example with AudioStreamInteractive transitions. The tracks are seamless stereo WAV loops (QOA at import, loop_begin 0, loop_end at the file's end) that start mid-signal.

### [20] music-flow (S): Drive the music from the menus and the match
- delivers: GameServices owns one MusicDirector and one MusicPlayer bound to it, so music lives for the whole game. The autoload never starts music by itself. | main.gd calls enter_menu() on the title, the menus and the results, and enter_match() when a played match starts. | MatchAudio forwards roundOver and roundStart from played matches (never the attract duel) to the director, so the round call with a fighter on two wins switches to the match-point track.
- check: GUT, extending game/tests/view/test_main_flow.gd and game/tests/core/test_game_services.gd: | - the title plays the menu track; | - a Duel switches to battle; | - a scripted match reaching two wins switches to match point at the next roundStart, not at roundOver; | - the results and quit-to-menu return to the menu track; | - the attract duel never changes the track, even when one of its fighters reaches two wins. | npm test and npm run typecheck pass.
- depends: music-player, match-sound-events
- stories: 51, 6
- files: game/core/game_services.gd, game/scenes/main.gd, game/view/match/match_audio.gd, game/tests/view/test_main_flow.gd, game/tests/core/test_game_services.gd
- notes: GUT runs with the GameServices autoload loaded, so its music must stay off until main.gd starts it. The director's doc puts the results on the menu track; the demo kept the fight music (see open questions).

### [19] arena-ambience (S): Arena ambience bed
- delivers: MatchAudio starts the arena's ambience loop (a FadedLoop on the Ambience bus) when a played match starts, keeps it through pauses, and fades it out on quit. | The cue comes from the arena root's `def.ambience_id`, read by name as MatchView reads camera data. Without one (the stand-in arena) it falls back to `ambience_shrine`.
- check: GUT: | - a Duel starts the ambience_shrine loop on the Ambience bus with a fade-in; | - the attract duel has none; | - quit fades it out and stops it; | - a fake arena (the _fake_arena pattern in test_match_scene.gd) whose def names a cue plays that cue. | npm test and npm run typecheck pass.
- depends: match-sound-events, music-player
- stories: 50, 47
- files: game/view/match/match_audio.gd, game/tests/view/test_match_audio.gd
- notes: The uncommitted ArenaDef in look-and-arena has ambience_id &"shrine_night" and music_track_id &"battle_140". Fix them to &"ambience_shrine" (and drop or ignore music_track_id) when task 17 is reviewed. test_sound_bank already checks that amb_shrine_loop.wav is a stereo forward loop of 60-90 s.

### [19] music-ducking (S): Duck the music and ambience under combat
- delivers: A compressor on the Music bus and on the Ambience bus, each sidechained to the Combat bus. Heavy impacts and the round calls pull them down a few dB, and they recover within about half a second. | The settings live in default_bus_layout.tres.
- check: game/tests/audio/test_bus_layout.gd asserts both compressors exist with sidechain Combat. | Heard during the listening pass. | npm test and npm run typecheck pass.
- depends: match-sound-events, music-flow
- stories: 50, 51
- files: game/default_bus_layout.tres, game/tests/audio/test_bus_layout.gd
- notes: This is the 'ducking' the plan's Progress note names. recon-1 recommends a compressor sidechain for it. Master already has a compressor (-14 dB, 4:1) and a limiter.

### [20] volume-settings (S): Master, effects and music volumes, saved
- delivers: game/core/game_settings.gd (class GameSettings) holds the master, effects and music volumes, 0-100 in steps of 5. | load_from() and save() use user://settings.cfg (ConfigFile, [audio] section), following ControlProfiles. | apply_volumes() sets the buses to their layout level plus linear_to_db(v/100), muting at 0: | - master sets Master; | - effects sets SFX, UI and Ambience; | - music sets Music. | GameServices loads and applies it at start and exposes `settings` for task 22's Settings screen.
- check: New GUT file game/tests/core/test_game_settings.gd: | - defaults apply when the file is missing; | - a save and load round-trips; | - values clamp to 0-100 and snap to steps of 5; | - apply_volumes keeps Music 6 dB under the others at 100 and mutes at 0; | - GameServices exposes the loaded settings. | Tests write to a test path in user://, never user://settings.cfg. | npm test and npm run typecheck pass.
- depends: 
- stories: 52
- files: game/core/game_settings.gd, game/core/game_services.gd, game/tests/core/test_game_settings.gd, game/tests/core/test_game_services.gd
- notes: Store each bus's layout level at start, so applying a volume never accumulates. Task 22 adds the graphics preset, reduce flashes and button hints to the same file, and builds the Settings screen.

### [19] menu-sounds (S): Menu sounds
- delivers: GameServices gets a flat SoundPlayer and play_ui(event) for ui_move, ui_select, ui_confirm and ui_back on the UI bus. | The stand-in menus call it, so task 22's menus inherit the hook: | - MenuScreen: focus moves, presses and back; | - TitleScreen: proceed; | - ResultsScreen: its buttons.
- check: GUT: | - moving focus in the main menu plays ui_move; | - pressing a button plays ui_select; | - Back plays ui_back, on the UI bus; | - the attract duel stays silent. | npm test and npm run typecheck pass.
- depends: sound-player
- stories: 3
- files: game/core/game_services.gd, game/ui/menus/menu_screen.gd, game/ui/menus/title_screen.gd, game/ui/menus/results_screen.gd, game/tests/view/test_main_flow.gd
- notes: The menus act in _unhandled_input and must never consume events in _input, because the InputFeed reads them there. The demo played uiMove on focus moves and uiSelect on presses (src/ui/menus.ts).

### [19] headless-sound-check (S): Headless check that every sound plays from real matches
- delivers: A GUT test that plays computer-vs-computer matches headless through MatchHost with MatchAudio and the music flow attached, one per weapon pairing, with fixed seeds. | It fails when: | - any sound file is missing or fails to load (the SoundPlayer's `missing` list); | - an event type with a non-empty table entry fired without playing a cue; | - an error is logged; | - any of the three music tracks fails to load.
- check: The test passes. | Pointing one cue at a missing file in a scratch edit (not committed) makes it fail. | npm test and npm run typecheck pass, and the CI run stays fast.
- depends: impacts-in-3d, footsteps, arena-ambience, music-flow
- stories: 50, 60, 63
- files: game/tests/audio/test_sound_playback.gd
- notes: test_sound_bank already proves the files exist. This covers the plan's check that a headless run logs no missing sound files. Reuse the whole-match loop from test_a_whole_match_renders_without_errors (step(3) up to 12 game minutes).

### [19] listening-pass (S): Sound check scene and the owner's listening pass
- delivers: game/tools/sound_check.tscn, excluded from export. It steps through every event's cues with labels, the footsteps, the ambience, and the three music tracks with their switches, so the owner hears what a Duel rarely triggers (ultimates, counters, disarms). | The owner's pass over a Duel, a Watch match and the sound check. | Fixes from the pass: levels, pitch and delays in sound_bank.gd; attenuation and ducking numbers; default volumes. | Plan tasks 19 and 20 ticked, and the spec's Sound section updated for anything that changed.
- check: The owner signs off by ear. | Any re-processed file goes through npm run audio:sonniss or audio:synth, and the Node audio tests (2 dB pool matching, 40 MB cap) pass. | npm test and npm run typecheck pass.
- depends: headless-sound-check, music-ducking, volume-settings, menu-sounds
- stories: 50, 51, 52
- files: game/tools/sound_check.tscn, game/tools/sound_check.gd, game/audio/sound_bank.gd, game/default_bus_layout.tres, docs/plans/godot-rebuild.md, docs/specs/godot-rebuild.md
- notes: The plan's Progress lists this pass as 'waiting on the owner'. It closes plan tasks 19 and 20 together.

### [25] repo-size-guard (S): CI guard on large files, and binary attributes
- delivers: scripts/check-sizes.mjs (npm run check:sizes) fails when a tracked file is over 10 MB unless it is on the script's allow-list. Today the only one is game/assets/audio/sfx/amb_shrine_loop.wav (10.58 MB). | It prints the size of game/assets and of all tracked files. | A CI step runs it. | The .gitattributes binary list gains *.exr, *.blend, *.mp3, *.tpz and *.bin.
- check: It passes on the branch, and fails on a scratch 11 MB file that isn't committed. | CI prints the sizes. | npm test and npm run typecheck pass.
- depends: 
- stories: 60, 63
- files: scripts/check-sizes.mjs, package.json, .github/workflows/ci.yml, .gitattributes
- notes: These are pending-plan-changes items 6 and 7, not done yet. Best done before merging task 13, which adds about 42.6 MB, all under 10 MB per file; it adds *.bin to .gitattributes, so expect a one-line merge conflict. Use `git ls-files` so ignored files never count.

### [25] windows-export-preset (S): Windows export preset and a local build
- delivers: game/export_presets.cfg with a "Windows Desktop" preset: | - x86_64 release, with the PCK embedded; | - excludes tests/*, tools/*, addons/gut/* and _probe/*; | - name and icon Monomachia, version 0.2.0 from project.godot; | - the Shader Baker on. | `npm run godot -- build` writes build/windows/Monomachia.exe on the owner's PC, where the 4.7.2 templates are installed.
- check: The export runs with no errors. | The exe launches, plays a Duel to results with sound and music, and keeps controls and settings between runs. | npm test and npm run typecheck pass.
- depends: 
- stories: 1, 64
- files: game/export_presets.cfg
- notes: godot.mjs `build` already targets this preset name and output path. No runtime script references res://tools or res://tests, checked including task 13's tools. tracks.json is loaded as a JSON resource, and the play check proves it is in the pack. Godot 4.5+ writes the icon and metadata without rcedit. Export credentials live in .godot/, so the preset is safe to commit.

### [25] licence-notices (S): Credits and licence notices shipped with the build
- delivers: A tool script (game/tools/write_notices.gd) that writes a THIRD-PARTY notice file from Engine.get_license_text(), get_copyright_info() and get_license_info(), matching the engine version. | A CREDITS file covering: | - Quaternius, CC0 (game/assets/CREDITS.md from task 13); | - the Sonniss bundle terms (game/assets/audio/SOURCES.md); | - GUT, MIT, dev only and not shipped; | - the project's own licence, per the owner's answer. | Both files are placed beside the exe by the build.
- check: `npm run godot -- build` output contains both files, and every asset folder's licence is listed. | The owner approves the licence wording. | npm test and npm run typecheck pass.
- depends: windows-export-preset, 13
- stories: 64
- files: game/tools/write_notices.gd, scripts/godot.mjs (build copies the notices), LICENSE (if the owner picks one)
- notes: There is no LICENSE file at the repo root, yet SOURCES.md says the generated sounds carry the repository's licence. Godot's MIT licence requires its notice in distributed copies. Task 22 adds the fonts' SIL OFL text to the list when it bundles them.

### [25] ci-windows-export (S): CI exports the Windows build and runs a short soak
- delivers: ci.yml installs the 4.7.2 export templates (setup-godot include-templates: true, cached). | After the tests it runs a short soak (npm run soak:godot -- 4). | It exports with the preset and uploads Monomachia-windows.zip (exe plus notices) as a run artifact. | The web steps stay until delete-web.
- check: The pull request's CI is green, and its run page offers the zip. | Downloaded on the owner's PC, the zip launches and plays a match.
- depends: windows-export-preset, licence-notices, repo-size-guard
- stories: 64, 60, 62
- files: .github/workflows/ci.yml
- notes: The templates are 1.28 GB, so cache them or each run downloads them. CI takes about 1 min now; consider a separate export job so test failures report first.

### [25] release-workflow (S): Release workflow uploads the zipped Windows build; Pages removed
- delivers: release.yml rebuilt: when a release is published it installs Godot and the templates, runs the tests, exports, zips Monomachia-<tag>-windows.zip with the notices, and runs gh release upload. | A workflow_dispatch trigger uploads the zip as an artifact instead, so the workflow can be tested without publishing. | pages.yml deleted.
- check: A workflow_dispatch run on the branch produces the zip. | After merge, the owner publishes a release (with their OK) and the zip is attached.
- depends: ci-windows-export
- stories: 64, 1
- files: .github/workflows/release.yml, .github/workflows/pages.yml
- notes: No GitHub releases exist yet, and Pages was never enabled (the API returns 404), so removing pages.yml takes nothing offline. Publishing a release is public: ask the owner first.

### [26] node-audio-tests (S): Run the Node audio tests without the web toolchain
- delivers: tests/audio/audio-tools.test.mjs and audio-quality.test.mjs (27 tests, using measure.mjs) ported from Vitest to Node's built-in runner (node --test with node:assert). | npm test runs them and GUT.
- check: npm test runs both suites with the same test counts, and fails when one test is broken on purpose. | The 40 MB cap and the pool-loudness tests still run in CI.
- depends: 
- stories: 60
- files: tests/audio/audio-tools.test.mjs, tests/audio/audio-quality.test.mjs, tests/audio/measure.mjs, package.json
- notes: Today Vitest finds these tests through vite.config.ts (include tests/**/*.test.mjs), which delete-web removes. The tests use only toBe, toBeCloseTo, greater/less-than and equals, so the port is mechanical. The alternative is to keep Vitest as the one dev dependency (see open questions).

### [26] delete-web (M): Delete the web version
- delivers: Removed: | - src/, index.html, vite.config.ts, tsconfig.json and the tracked Monomachia.html; | - tests/*.ts; | - scripts/browser.mjs, make-artifact.mjs, counterlab.ts, soak.ts, port-fixtures.ts, sim-fixtures.ts and golden/; | - docs/screenshots (web); | - the web dependencies and their package-lock entries; | - the web steps in ci.yml; | - dist/ and coverage/ in .gitignore. | Comments in scripts/audio and the SOURCES.md text from lib/sources.mjs say src/audio/audio.ts lives in tag v0.1-web-mvp. | game/tests/fixtures/*.json stay as frozen data, with a note that their generators are in the tag.
- check: git grep finds no remaining reference to src/, vite, three or tsx outside docs history. | npm ci, npm test and npm run typecheck pass. | CI is green.
- depends: node-audio-tests, ci-windows-export, 12, 17, 18, 20, 23, 24
- stories: 59, 60
- files: src/, tests/*.ts, scripts/, index.html, vite.config.ts, tsconfig.json, Monomachia.html, docs/screenshots/, package.json, package-lock.json, .gitignore, .github/workflows/ci.yml, scripts/audio/lib/sources.mjs, game/assets/audio/SOURCES.md
- notes: v0.1-web-mvp already exists (annotated, on master 76d4a09, pushed). Confirm it with `git ls-remote --tags origin v0.1-web-mvp`; no new tag is needed. The golden replays and golden:record should already be gone with task 8; remove any leftovers here.

### [26] final-npm-scripts (S): Final npm script names
- delivers: package.json scripts, kept: | - test: GUT plus the Node audio tests; | - typecheck; | - soak: headless Godot; | - build: Windows export; | - dev: the editor; | - shots; | - play (was godot:run), counterlab, godot, check:sizes and the audio:* scripts. | Removed: test:web, typecheck:web, preview, soak:godot, godot:dev, godot:run, golden:record, godot:fixtures. | godot.mjs usage text updated. | ci.yml and release.yml use the new names. | package.json's description and version updated for the Godot game.
- check: Each script runs: `npm run soak -- 4`, `npm run build`, and `npm run shots` on one scene. | CI is green.
- depends: delete-web
- stories: 60, 62, 64, 65
- files: package.json, scripts/godot.mjs, .github/workflows/ci.yml, .github/workflows/release.yml
- notes: The spec's final list is test, typecheck, soak, build, dev and shots. Task 13's branch also edits godot.mjs (scene args for shots), so do this after that merge.

### [25] claude-md-and-mvp-spec (S): CLAUDE.md for Godot, and mvp-spec marked as the web record
- delivers: CLAUDE.md: | - intro line: Godot 4.7.2, typed GDScript; | - design-docs paragraph: mvp-spec is the web demo's record, and docs/specs/godot-rebuild.md holds the current numbers; | - Commands: the final npm scripts and how Godot is found; | - Code notes: game/sim has no nodes and steps 60 per second, frame data is in game/sim/moves, tuning in game/sim/constants.gd, GUT tests in game/tests. | docs/mvp-spec.md's header marks it as the record of the web demo at tag v0.1-web-mvp. | docs/agents/domain.md updated if any paths it cites change.
- check: Every path and command in CLAUDE.md exists and runs. | The owner OKs the CLAUDE.md change.
- depends: final-npm-scripts
- stories: 59, 60
- files: CLAUDE.md, docs/mvp-spec.md, docs/agents/domain.md
- notes: CLAUDE.md is the owner's instruction file: use the writing-for-agents skill and get explicit approval. Today it says 'in the browser, built with three.js, TypeScript and Vite', src/sim, src/sim/moves, src/sim/constants.ts, 'Vitest, no graphics', and that mvp-spec's 'combat numbers match the code'.

### [25] readme-for-godot (M): README rewritten for the Godot game
- delivers: README covering: | - the Windows download from releases; | - the modes; | - how a fight works under the rebuild's rules (walls, 60% block walk, 14-frame light hitstun, the new strings and the Iai); | - controls (same defaults, saved in the user folder); | - build and develop (Godot 4.7.2 and Node 22.12; GODOT, PATH or .godot-path; the npm scripts); | - the swing editor (task 14b's check asks for it here); | - the game/ folder layout and scripts/audio; | - the workflows and the credits. | New screenshots in docs/screenshots (parry, ultimate, Versus) rendered with npm run shots.
- check: Every command in the README runs as written. | The screenshots are reviewed by eye. | The owner reads it.
- depends: final-npm-scripts, 14b, 18, 23
- stories: 1, 56, 64, 65
- files: README.md, docs/screenshots/
- notes: Written last, so the rules, the art and the script names are final.

### [26] final-verification (S): Final verification and ready for review
- delivers: Run and record: | - npm test and npm run typecheck; | - npm run soak -- 40, clean and within the spec's targets; | - every shot scene (game/tools/shot_scenes and the arena and fighter shot scenes), rendered and reviewed; | - npm run check:sizes; | - CI green with the Windows zip; | - the downloaded zip played to results on the target laptop. | Plan tasks 25 and 26 ticked, the spec's status updated, and the pull request marked ready.
- check: All of the above pass. | The owner gets the one-line summary and link, per CLAUDE.md.
- depends: readme-for-godot, claude-md-and-mvp-spec, release-workflow, listening-pass
- stories: 1, 60, 62, 64, 65
- files: docs/plans/godot-rebuild.md, docs/specs/godot-rebuild.md
- notes: Merging still waits for the owner's approval, per CLAUDE.md.

## Open questions
- Footsteps: both fighters placed in 3D, or only the viewed fighter as in the demo (step for fighter 0 only)? Recommended: both, placed in 3D, re-judged in the listening pass.
- Results-screen music: the menu track (music_director.gd's doc) or keep the battle track (the demo)? Recommended: follow the director, so menu.
- The attract duel behind the menus: silent apart from music (demo parity), with no ambience? Recommended: yes.
- While paused: hold SFX voices and delayed cues (so the round gong doesn't ring over the pause menu), and let music and ambience carry on? Recommended: yes.
- Which buses the Effects slider drives, given the spec has three sliders? Recommended: SFX, UI and Ambience, matching the demo's sfx gain, which covered everything but music.
- Default volumes? Recommended: master 80, effects 90, music 100. The layout's -6 dB Music bus already plays the role of the demo's 0.45, so these reproduce the demo's balance. The listening pass can move them.
- Ducking: sidechain compressors on Music and Ambience keyed by Combat? Recommended: yes, about 3-4 dB on heavy impacts and calls, tuned by ear.
- The uncommitted ArenaDef's sound ids (ambience_id shrine_night, music_track_id battle_140) match nothing. Recommended: set ambience_id to ambience_shrine and drop music_track_id when task 17 is reviewed, since the director picks music by match state, not by arena.
- Fade mechanism for the 10-20 ms fades: Godot's per-buffer volume ramp, or an audio-thread fade such as AudioStreamInteractive? Recommended: decide by measuring a captured bus in the music-player task.
- Should the sound check scene be built for the listening pass? Recommended: yes, as a tool scene excluded from export, because ultimates, counters and disarms are hard to trigger on demand.
- The Node audio tests once Vitest goes: port them to node:test, or keep Vitest as the one dev dependency? Recommended: port them; it's mechanical and leaves no web toolchain.
- Pull the export preset, size guard, notices, CI export and Release workflow forward, before the gameplay tasks? Plan task 25 is blocked by 12, 17, 18, 20, 23 and 24, but only the docs and the final check need those. Recommended: yes; repo-size-guard before merging task 13, and the export tasks early to catch problems that only appear in an exported pack.
- The project's own licence: there is no LICENSE file, yet SOURCES.md refers to 'the repository's licence'. Owner's call. The Sonniss-derived and Quaternius files keep their own terms whatever is chosen.
- The first Godot release: who publishes it and under which tag? Recommended: v0.2.0, matching project.godot's config/version, published by the owner (or by Claude with explicit OK) after the PR merges, which also proves the Release workflow.
- Export details: embed the PCK in the exe (recommended, one file plus notices)? And set a custom user dir 'Monomachia', so saves land in %APPDATA%\Monomachia rather than %APPDATA%\Godot\app_userdata\Monomachia? Recommended: embed yes; custom user dir is optional, the owner's choice.
- Should CI also run the exported exe on a windows-latest runner? Recommended: no. Keep CI on ubuntu and rely on the owner's play check of the downloaded zip.

## Risks
- 15 ms fades are shorter than one _process frame (16.7 ms). A tween or per-frame volume step may still click. Verify by capturing the bus, not by reading code.
- Headless GUT runs use the dummy audio driver: playback positions and mixing aren't real. Tests must assert on the players' state and signals. Real behaviour (clicks, levels, panning) needs a windowed check or the listening pass.
- Versus split screen (task 23): every viewport's listener that shares the World3D hears AudioStreamPlayer3D, so 3D sounds can play twice. MatchAudio's explicit listener has to be the only one, and task 23 must turn off 3D listening on the second viewport.
- The camera sits about 4.6 m behind the player. Default distance falloff would make the opponent's hits and footsteps noticeably quieter than the player's. Keep attenuation gentle and tune it by ear.
- Bursty ultimates (Lightning Tempest) fire many events in a few frames. Oldest-voice stealing could cut a KO's taiko or gong. Size the pools generously, or let calls and KO cues refuse to be stolen.
- amb_shrine_loop.wav (10.58 MB) trips the planned 10 MB guard unless allow-listed. Re-encoding it to OGG would mean changing the extractor, the spec's '16-bit WAV' rule and test_sound_bank's AudioStreamWAV assertion.
- Without a cache, CI downloads the 1.28 GB export templates on every run, turning a 1-minute CI into several minutes.
- The exported pack must include tracks.json (loaded as a JSON resource) and every imported WAV. Only playing the exported build proves it. Excluding tools/ is safe today but would break if a runtime script ever starts using a tools class.
- Deleting the web version removes the generators of game/tests/fixtures/*.json and the golden recorder. Any later need to regenerate them means checking out tag v0.1-web-mvp.
- CLAUDE.md is the owner's own instruction file, and pushing tags and publishing releases are public actions. These need explicit owner approval, not just the plan.
- README and screenshots written before the rules (8-12), art (13-18) and modes (23) are final would need redoing. Keep readme-for-godot last.
- Merging task 13 touches .gitattributes and scripts/godot.mjs. repo-size-guard and final-npm-scripts edit the same files, so do them after that merge or expect small conflicts.
