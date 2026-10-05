# Plan: Animation Studio

Spec: `docs/specs/animation-studio.md` · branch `feature/animation-studio`, off `feature/authored-animation` · draft pull request #19 (into `feature/authored-animation`; retargeted to `feature/godot-rebuild` once #12 merges)

> **Absorbed by milestone 1 (Oct 4, 2026):** this plan is no longer followed on its own. PR #19 merged it into `feature/godot-rebuild` as it stood (tasks 1–6 done), and milestone 1 slims the Studio to its gallery, timeline, markers and chains (`docs/specs/milestone-1.md`, The Animation Studio). Its leftover tasks fold into `docs/plans/milestone-1.md`: task 11 drops tasks 13, 14 and 16–21; task 25 carries 7, 8 and 9 (only the distance band's hit-or-miss check); task 26 carries 10 and 11; task 27 carries 12 and 15; task 41 carries 22 and the gallery's open gate 6, as the owner's try of the slimmed Studio on the pilot family. The Global Constraints' excuse for `test_whole_attacks_keep_the_weapon_in_the_hands` no longer holds: `docs/plans/roadmap.md` task R1 fixes it before the consolidation merges.

> **For agentic workers:** work task by task with `/implement` (tests first, then code, then review), or superpowers:subagent-driven-development / superpowers:executing-plans. Tick each task's box here when it's done.

## Destination

`node scripts/godot.mjs studio` opens a Godot tool scene with three parts:

- **Gallery:** every animation the fighters play, live, grouped as Katana, Daggers, Greatsword, Fists, States, Ults and Source clips.
- **Editor:** a click opens one animation for editing:
  - a timeline in source or rules frames;
  - markers, chains, frame data and state timings;
  - overlays and a rules preview;
  - correctives and keyed clips posed with gizmos and IK handles;
  - undo and redo; Save writes the files and re-bakes.
- **Chat panel:** hands a refinement to Claude Code in a fresh worktree, with the animation's data and a screenshot attached, and keeps a log of refinements per animation.

**Architecture:**
- The Studio lives in `game/tools/anim_studio/`.
- It reads the same data the game reads (ClipManifest, MoveClips, the new StateClips, the KeyedPose keys, the new correctives).
- It plays clips with the game's own pieces: ClipPoser for source frames, and MoveBench (a rules World and a FighterView facing a defender) for rules frames and the rules preview.
- Every write goes through one text-span editor, SourceEdit, that changes only the values edited and keeps the hand-formatted files byte-identical everywhere else.
- Correctives are a SkeletonModifier3D that runs after the clip pose and before the procedural layers, so matches, the Studio and the bake all see them.

**Tech stack:** Godot 4.7 (Forward Plus), typed GDScript, GUT tests run by `node scripts/godot.mjs test`, `git`, `gh` and Claude Code's `claude` CLI on Windows 11 (Windows Terminal `wt.exe`, falling back to `cmd /c start`).

## Global Constraints

- Godot 4.7, typed GDScript, matching the surrounding code's naming and comment style (`##` doc comments, glossary terms in names).
- Everything new goes in `game/tools/anim_studio/` and `game/tests/tools/anim_studio/`. The game's own files change only at the spec's touch points:
  - `view/fighter/clip_director.gd` (state clips on data);
  - the corrective modifier's install in the fighter rig;
  - `tools/clip_poser.gd` (correctives in the bake);
  - `tools/build_keyed_clips.gd` (a callable `build_all`, task 21);
  - an `enabled` flag on the procedural layers that lack one (task 8);
  - `scripts/godot.mjs` (`studio`);
  - `.gitignore`;
  - `GLOSSARY.md`.
- `game/sim` stays free of graphics. The Studio never adds nodes or clips to it.
- Tests run headless and **without the packs** (CI has none). A test that needs the clip libraries skips itself with `pending("local-only: no clip libraries (node scripts/godot.mjs clips)")`, as the existing local-only tests do.
- Never commit an Iglesias file, a clip converted from one, a screenshot of one, `.anim-refine/` or `game/tools/anim_studio/.refinements.json`.
- Data files keep their hand formatting: one move per line in `move_clips.json`, numbers in `JsFormat.num()` style, tabs. A load and save with no edits writes identical bytes.
- Every task ends with:
  - `npm test` and `npm run typecheck` passing (`test_whole_attacks_keep_the_weapon_in_the_hands`, once a failure inherited from the base on clones without the packs, has been local-only since Oct 4);
  - `git checkout -- game/default_bus_layout.tres` (Godot test runs rewrite it);
  - a commit and a push.
- New worktrees lack gitignored files. Before Godot runs in one, copy `.godot-path` (and `.assets-src-path`) and junction `node_modules` from the main checkout.
- Before each task, merge `origin/feature/authored-animation` in and run the tests. After #12 merges, merge `origin/feature/godot-rebuild` instead and retarget #19.

## Review Focus

The input classes the spec implies but no story spells out. Each has a test in the task named.

1. **Packs missing (fresh clone, CI).** The Studio opens, every tile plays the game's fallback with the fallback badge, and nothing errors (tasks 4, 5).
2. **A data file with a mistake.** If `move_clips.json`, `clip_manifest.json` or `state_clips.json` fails to read, the Studio lists the errors and opens that data read-only. It never saves over a file it couldn't read (task 4).
3. **A data file changed on disk while there are unsaved edits** (a pull, a refinement merged, a hand edit). Save sees the file differs from what was loaded and refuses for that file, offering to reload. It never clobbers (task 15).
4. **Awkward prompts:** quotes, newlines, `%`, backticks, non-ASCII, emoji, 5,000 characters, or empty. The prompt reaches `prompt.md` byte for byte, the slug is ASCII and short, and an empty prompt can't be sent (task 16).
5. **The handoff failing partway:**
   - the branch or worktree path already exists;
   - `git` errors;
   - `wt.exe` or `claude` is missing.

   Each gives a clear message naming the step. Nothing half-made is logged, and a worktree made before the failure is reported, not deleted (tasks 16, 17).

## Decisions so far

- [Spec](../specs/animation-studio.md), approved by the owner on Oct 3, 2026.
- PR #19 was opened with the base's grips/elbows failure noted. The owner chose to commit and push anyway (Oct 3).
- **The plan was approved** by the owner on Oct 3.
  - **Execution:** a fresh subagent builds each task test-first, and a fresh reviewer checks it before the next starts.
  - **Pacing:** tasks run back to back. Work stops only at the gates (6, 17, 22).
- **Choices made while building** (Oct 3–4):
  - **Knockdown and KO** moved to `state_clips.json` in task 3 along with the other states. They arrived with authored-animation task 28, after this plan was written, and spec story 17 lists knockdown among the editable states.
  - **The regression tests use a frozen copy of the table** (`tests/fixtures/state_clips_frozen.json`), so Studio edits to the live file don't break them.
  - **Roll and the locomotion clips** are view-only source entries in the States tab.
  - **Catalogue entries carry their fallback clips** (`Entry.fallbacks`), so the tiles and the editor play what the game plays without the packs.
  - **Tiles build when first shown**, at most two per frame, and tick at 30 Hz. These are the spec's speed mitigations, applied early.
  - **Task 15** will signal `send_to_chat` for task 17 to connect. **Task 16** owns building the terminal command.
  - **Task 22** also adds the Studio to `docs/architecture.md`, which CLAUDE.md now asks for.

## Progress

- **Tasks 1–6 done** (Oct 3–4, up to 7208d42). Each task was built test-first by a fresh implementer and passed an independent review; tasks 3 to 6 needed one fix round each.
  - **What works:** the Studio opens with `node scripts/godot.mjs studio` and shows a live gallery of every animation in seven tabs (Katana, Daggers, Greatsword, Fists, States, Ults, Source), on either body. It has search and badge filters, and tiles play the real clips, or the fallbacks without the packs.
  - **Gate shots:** `shots/studio/<tab>_<body>.png` (gitignored).
  - **Speed:** about 19–33 ms per frame with a screenful of 12 live tiles. Opening a later tab takes 70–95 ms; the first tab after start takes about 0.6 s, while the clip libraries and shaders load.
  - **Tests:** the full suite was 1772/1772 with the clip libraries present.
- **Paused after task 6** (Oct 4), on the owner's word relayed from the roadmap session: the owner is rethinking the animation approach (the fighters' skeleton and models; whether clips or frame data lead). Gate 6, the owner's look at the gallery shots, is still open. Nothing starts until the owner restarts the lane.

## Build order

The tasks run in this order:

1. **Foundations** (1–4).
2. **The gallery** (5–6).
3. **Viewing in the editor** (7–9).
4. **Editing and saving** (10–15).
5. **Refinements** (16–17).
6. **Correctives and posing** (18–21).
7. **The owner's review** (22).

The state-clips refactor (3) comes early because `clip_director.gd` is still changing in the authored-animation lane. Bone posing comes last so that the rest is usable first (spec, Risks). **Hard gates** (nothing after them starts without the owner's OK): task 6 (the gallery's look), task 17 (one real refinement end to end), task 22.

## File map

```text
game/tools/anim_studio/
├── studio.tscn / studio.gd          # the scene: gallery ⇄ editor, chat panel docked right
├── source_edit.gd                   # SourceEdit: span edits in JSON and GDScript dict text
├── studio_catalogue.gd              # StudioCatalogue + Entry: what the gallery lists
├── studio_libraries.gd              # StudioLibraries: clip libraries loaded once, shared
├── gallery/  gallery.tscn/.gd, anim_tile.tscn/.gd, gallery_filter.gd
├── editor/   editor.tscn/.gd, orbit_camera.gd, playback.gd, timeline.gd,
│             overlays.gd, rules_preview.gd, marker_panel.gd, chain_panel.gd,
│             frame_data_panel.gd, state_panel.gd, bone_picker.gd, pose_gizmo.gd,
│             ik_handles.gd, keyed_editor.gd
├── edit_session.gd                  # EditSession: pending edits, undo/redo, dirty flags
├── moves_patch.gd                   # MovesPatch: frame data edits in sim/moves/<weapon>.gd
├── studio_saver.gd                  # StudioSaver: write, bake, refuse, balance flag
├── chat/     chat_panel.tscn/.gd, refinement_launcher.gd, process_runner.gd,
│             refinement_log.gd, context_writer.gd
game/view/fighter/clip_correctives.gd     # ClipCorrectives: load, sample, SkeletonModifier3D
game/assets/kevin_iglesias/state_clips.json
game/assets/authored/correctives/         # <clip id>.json, committed, CC0
game/view/fighter/state_clips.gd          # StateClips: reads state_clips.json
game/tests/tools/anim_studio/test_*.gd
```

## Tasks

### Phase A: foundations

- [x] **1. The Studio shell and its launch command.**
  - **The scene.** `game/tools/anim_studio/studio.tscn` with `studio.gd` (`class_name AnimStudio`, `extends Control`). A full-window layout holds a top bar (title, Hunter/Rogue toggle, a packs-missing note from `ClipLibraries.MISSING_NOTE`), a central area that swaps between an empty gallery and an empty editor, and a chat panel docked on the right that can be collapsed. It has a dark theme in `studio_theme.tres`.
  - **`node scripts/godot.mjs studio`** runs `godot --path game res://tools/anim_studio/studio.tscn` windowed (1600×900), like `run`. It is added to the usage line.
  - **`.gitignore`** gains `.anim-refine/` and `game/tools/anim_studio/.refinements.json`.
  - **`GLOSSARY.md`** gains a "Tools" section with **Animation Studio**, **Corrective** and **Refinement**, worded as in the spec's Further Notes.
  - Interfaces produced:
    - `AnimStudio.show_gallery() -> void` and `AnimStudio.open_editor(entry: StudioCatalogue.Entry) -> void`;
    - `signal body_changed(fighter_id: StringName)`, with `&"hunter"` or `&"rogue"`.
  - Check: `tests/tools/anim_studio/test_studio_smoke.gd` instantiates the scene headless, awaits two process frames and asserts the three areas exist with no script errors. A shot (`godot.mjs shots`) of the empty layout.
  - Blocked by: none · Stories: 36, 37

- [x] **2. SourceEdit: change one value in a hand-formatted file.**
  - `game/tools/anim_studio/source_edit.gd` (`class_name SourceEdit`, `extends RefCounted`), a pure text tool for JSON and GDScript dictionary literals.
  - It is string-aware (`"..."` with escapes, `&"..."` StringNames) and bracket-matching over `{}`, `[]` and `()`.
  - Interfaces produced:
    - `static func find_value(text: String, path: Array[String]) -> Vector2i`: the `[start, end)` span of the value at a key path. `["katana", "moves", "k_l1", "speed"]` in JSON, `["MOVES", "k_l1", "startup"]` in a `.gd` file (the first element names a `const` there). `Vector2i(-1, -1)` if absent.
    - `static func replace_value(text: String, path: Array[String], value: Variant) -> String`: replaces the value at `path` with `literal(value, flavour)`. An absent last key is added before the entry's closing brace as `, "key": value` on the same line, in the entry's own style.
    - `static func remove_key(text: String, path: Array[String]) -> String`.
    - `static func literal(value: Variant, flavour: StringName) -> String`, with `&"json"` or `&"gd"`:
      - numbers via `JsFormat.num()`;
      - strings quoted;
      - StringName as `&"x"` in gd;
      - arrays and dicts compact (`["a", "b"]`, `{"windup": 8, "contact": 15}`).
    - `class Error`, holding `message: String`, which is pushed into a passed `errors: Array[String]` when a path can't be found or a span isn't a plain literal (a call such as `V3.make(...)` is refused unless the key's whole value is replaced).
  - Check, in `test_source_edit.gd`:
    - finding and replacing `speed` in the real `move_clips.json` text changes only those bytes (compare the two texts with the edited span cut out);
    - adding `marks` to a move that has none, and removing it again, gives the original bytes;
    - `startup` in a copy of `katana.gd`'s text, where the edited text still parses (`GDScript.new()` + `source_code` + `reload() == OK`);
    - strings holding `}` and `"` don't fool the matcher;
    - a missing path gives `(-1, -1)` and an error;
    - a key under a call value is refused.
  - Blocked by: none · Stories: 14–17, 19

- [x] **3. State and ult clips on data.**
  - **The file.** `game/assets/kevin_iglesias/state_clips.json` holds, with unchanged values, everything ClipDirector's constants hard-code about which clips play:
    - `IDLE`, `FALLBACK_IDLE` and `FADES`;
    - `STATE_CLIPS` and `STUN_CLIPS`;
    - `HIT_CLIPS`, `HIT_FALLBACKS` and `HEAVY_HITSTUN`;
    - `GUARD_CLIPS` and `GUARD_FALLBACK`;
    - `STUN_CLIP` and `STUN_FALLBACK`;
    - `REBOUND_FRAMES` and `REBOUND_SPEED`;
    - `CARRY_POSE`;
    - `ULT_CLIPS`, `ULT_FALLBACK`, `ULT_WINDUP` and `ULT_RELEASE`;
    - the `IMPALER_*` and `TEMPEST_*` timings.

    Keys are snake_case, grouped as `idle`, `fades`, `hit`, `guard`, `stun`, `rebound`, `carry`, `ults` (`moonsplitter`, `impaler`, `tempest`) and `keyed` (`state`, `stun`). An `about` line, house formatting.
  - **The reader.** `game/view/fighter/state_clips.gd` (`class_name StateClips`, `extends RefCounted`):
    - `const PATH := "res://assets/kevin_iglesias/state_clips.json"`;
    - `static func read(path: String = PATH) -> StateClips`, typed fields mirroring the old constants (for example, `var idle: Dictionary[StringName, StringName]`, `var ult_clips: Dictionary[StringName, Array]`), and `var errors: PackedStringArray`, which refuses unknown fields as MoveClips does;
    - `static func shared() -> StateClips`, read once and cached; a test can swap it with `static func use(s: StateClips) -> void`.
  - **ClipDirector** reads `StateClips.shared()` wherever it read a constant. The constants that aren't clip choices (`GRIP_BACK`, `LEGS`, `ATTACK`, `CARRY`, `STATE`, `UPPER_REACTIONS`, `STUN_STATES`, `REBOUND_STATES`) stay.
  - Check, in `tests/view/test_state_clips.gd` (it tests game code, so it lives in `view/`):
    - a table of the old constant values, copied into the test before they're deleted, equals what `read()` returns;
    - a scripted bout (the existing ClipDirector test fixtures) gives the same Shot sequence before and after: record `ClipDirector.step` shots for a fixed input script into `tests/fixtures/state_clips_shots.json` *before* the refactor, then assert equality after;
    - a file with an unknown key is refused with an error.
  - Blocked by: 2 · Stories: 17

- [x] **4. The catalogue.**
  - `game/tools/anim_studio/studio_catalogue.gd` (`class_name StudioCatalogue`) and `studio_libraries.gd` (`class_name StudioLibraries`).
  - Interfaces produced:
    - `class Entry`:
      - `kind: StringName`: `&"move"`, `&"state"`, `&"ult"` or `&"source"`;
      - `group: StringName`: `&"katana"`, `&"daggers"`, `&"greatsword"`, `&"fists"`, `&"states"`, `&"ults"` or `&"source"`;
      - `id: StringName` and `name: String`;
      - `clips: Array[String]`, the ClipChain entries it plays;
      - `speed: float`;
      - `source: Array[Location]`, where `Location` has `path: String`, `key_path: Array[String]` and `line: int`;
      - `badges: Dictionary[StringName, bool]`, keyed by `&"fallback"`, `&"provisional"`, `&"corrective"`, `&"unsaved"` and `&"balance"`;
      - `read_only: bool`, true when the file it comes from had read errors.
    - `static func build(manifest: ClipManifest, table: MoveClips, states: StateClips, keyed: Array[StringName]) -> StudioCatalogue`, with `var entries: Array[Entry]`, `func in_group(g: StringName) -> Array[Entry]`, `func find(kind: StringName, id: StringName) -> Entry` and `var errors: PackedStringArray` (each reader's errors, prefixed with its file).
    - Display names come from `Moves.WEAPONS[w].moves[id].name` for moves, and from a small name table in the catalogue for states and ults.
    - `StudioLibraries.get_set(set_name: StringName) -> AnimationLibrary` (loaded once, `ClipLibraries.load_set`), `StudioLibraries.ual() -> AnimationLibrary`, `StudioLibraries.keyed() -> AnimationLibrary` and `StudioLibraries.available() -> bool`.
  - Move order follows `move_clips.json`. Fists come from the table's `fists` key. States list idle per weapon, hit, guard per weapon, stun, rebound, carry, knockdown, roll, and the keyed stomp and pinned clips. Locomotion clips (walk, run, strafe, sprint, turn) are listed as source entries in the `states` group with view-only timing.
  - **Read-only on errors.** If any reader has errors, `errors` is non-empty and every entry from that file gets `read_only = true`. The Studio shows the errors in a banner (Review Focus 2).
  - Check, in `test_studio_catalogue.gd`:
    - every move in `move_clips.json` appears exactly once, in its weapon's group and in table order (70 in all);
    - every state and ult in `state_clips.json` appears;
    - source covers the manifest, the UAL list in `build_animation_library.gd` and the keyed library;
    - with `ClipLibraries.force_missing` on, move entries carry `fallback` (Review Focus 1);
    - provisional clips carry `provisional`;
    - a broken `move_clips.json` text (via a temp file) yields errors and read-only entries.
  - Blocked by: 3 · Stories: 2, 4, 37

### Phase B: the gallery

- [x] **5. The animation tile.**
  - `gallery/anim_tile.tscn/.gd` (`class_name AnimTile`, `extends PanelContainer`) holds:
    - a 256×256 `SubViewport` with its own `World3D`, a key light and a three-quarter camera;
    - a `FighterModel` from `FighterLook.instantiate_fighter(fighter_id)` with the entry's weapon attached (`WeaponLook`), its AnimationPlayer given the shared libraries;
    - a `ClipPoser` over the entry's chain;
    - a caption (name and id) and badge chips.
  - It loops `poser.pose(t)` at the clip's speed. Without the packs it plays the fallback the game would (`MoveClips` entry `fallback` qualified as `ual/`).
  - Interfaces produced:
    - `func setup(entry: StudioCatalogue.Entry, fighter_id: StringName) -> void`;
    - `func set_playing(on: bool) -> void`, which sets the viewport's update mode to `UPDATE_DISABLED` when off;
    - `signal opened(entry)` on a click.
  - **Visibility.** A `VisibleOnScreenNotifier`-style check on the tile's rect against the scroll container drives `set_playing`.
  - Check, in `test_anim_tile.gd`:
    - setup on a move entry poses the skeleton differently at t=0 and t=mid (compare a hand bone's global position), local-only when the packs are needed, otherwise on the fallback;
    - `set_playing(false)` stops `_process` advancing time;
    - a source entry for a UAL clip plays without the packs.
  - Blocked by: 4 · Stories: 1, 4, 5

- [x] **6. The gallery screen.**
  - `gallery/gallery.tscn/.gd`:
    - tabs Katana, Daggers, Greatsword, Fists, States, Ults and Source, each a scrolling `HFlowContainer` of tiles;
    - a search box and badge filter chips;
    - the gallery-wide Hunter/Rogue toggle, which re-setups visible tiles;
    - tiles built lazily per tab;
    - a click calls `AnimStudio.open_editor(entry)`.
  - `gallery_filter.gd` (`class_name GalleryFilter`): `static func matches(entry, text: String, badges: Array[StringName]) -> bool`. Matching is case-insensitive on name and id; all chosen badges must be set.
  - Check:
    - `test_gallery_filter.gd` (name, id, badge, combined);
    - a smoke test that switching tabs creates tiles only for that tab and that only on-screen tiles play;
    - shots of each tab on both bodies.
  - **Gate.** The owner looks at the gallery shots (layout, tile size, captions, badges) before the editor work starts.
  - Blocked by: 5 · Stories: 1–6

### Phase C: viewing in the editor

- [ ] **7. The editor viewport, camera and timeline (source frames).**
  - **The editor.** `editor/editor.tscn/.gd` (`class_name StudioEditor`): a large 3D viewport (one FighterModel, floor grid, the shared libraries) above a timeline and side panels in tabs: Markers, Chain, Frame data, States, Pose. Panels come in later tasks; empty tabs for now. A back button returns to the gallery.
  - **The camera.** `editor/orbit_camera.gd` (`class_name OrbitCamera`, `extends Camera3D`): right-drag orbits, middle-drag pans, the wheel zooms. Presets are front, side, top and match (the gameplay camera's angle, from the match scene's camera).
  - **Playback.** `editor/playback.gd` (`class_name StudioPlayback`, `extends RefCounted`), a pure model with no nodes:
    - `var mode: StringName`: `&"source"` or `&"rules"`;
    - `var frame: float`, `var length: float` (in the current mode's frames), `var playing: bool`, `var loop: bool`, `var rate: float` (0.1–2.0);
    - `func advance(delta: float) -> void`, `func step(n: int) -> void`, `func seek(f: float) -> void`;
    - `func source_time() -> float`, the seconds into the chain to pose.
  - **The timeline.** `editor/timeline.gd` (`class_name StudioTimeline`, `extends Control`):
    - draws the frame ruler, the playhead and the loop range;
    - scrubs on drag;
    - keys: Space plays and pauses, the Left and Right arrows step a frame, L toggles loop;
    - a rate slider;
    - `signal seeked(frame: float)` and `signal range_selected(from: int, to: int)` (shift-drag).
  - Check, in `test_playback.gd`:
    - advance at rate 1 for 1 s in source mode moves 30 frames;
    - stepping stops at the ends without loop and wraps with it;
    - seek clamps.

    Plus a smoke test that opening one entry of each kind shows a posed fighter, and a shot.
  - Blocked by: 4 · Stories: 7, 12

- [ ] **8. Rules frames, bands, markers and layers.**
  - **Rules mode** plays the move through `MoveBench` (`tools/move_bench.gd`). `begin()` and `next_frame()` step the rules World one attack frame at a time, and the FighterView poses the fighter with ClipDirector and the procedural layers, as a match does. The editor's viewport shows the bench's fighter.
  - **The mode switch** maps the playhead with the move's `ClipTiming` (`ClipDirector.timing_of(swing)`):
    - `StudioPlayback.to_rules(source_frame) -> float` and `to_source(rules_frame) -> float`, using `ClipTiming.clip_time()` and its inverse by search over `timing.frames`.
  - **The timeline draws** the startup, active and recovery bands from the move's `AttackDef` (rules frames, or their source frames in source mode), and the four markers (`MoveClips.markers(...)`) above the ruler, labelled.
  - **Layer toggles** (guard stance, foot lock, lean, body layer) switch the corresponding FighterView/FighterRig parts off for the editor's fighter only. Each part gets an `enabled` flag if it lacks one, the only game-file touch in this task, defaulting to on.
  - States and ults play in source mode only. The rules mode is greyed out for them.
  - Check, in `test_playback.gd`:
    - `to_rules(to_source(f)) ≈ f` for every rules frame of `k_l1` (within 0.5);
    - band edges equal `startup`, `startup + active` and the total.

    Plus a test that turning foot lock off changes a foot's position on a frame where it was locked (local-only).
  - Blocked by: 7 · Stories: 8, 9, 11

- [ ] **9. Overlays and the rules preview.**
  - **Overlays.** `editor/overlays.gd` (`class_name StudioOverlays`, `extends Node3D`) draws with `ImmediateMesh`, each part toggleable:
    - the blade trail: the baked swing's blade tip per rules frame, from the move's `AttackDef.swing` (`Moves.WEAPONS[wid].moves[id].swing`, attached from `sim/moves/swings/<weapon>.json` by `SwingFile.attach`), coloured by phase;
    - the strike segment and the sweep on active frames;
    - a reach ring at `AttackDef.range`;
    - lunge travel: the root's path over the move, from the bench.
  - **The rules preview.** `editor/rules_preview.gd` (`class_name RulesPreview`) runs the bench with its defender standing at `PoseCheck.SPACING` and records which attack frames hit (from the World's hit events). The timeline marks hit frames with ticks, and a label says "hits on frame N" or "misses".
  - Check, in `test_rules_preview.gd`:
    - `k_l1` against a standing defender reports a hit on an active frame;
    - with the spacing pushed past `range + lunge` it reports a miss;
    - the overlay trail has one point per rules frame of the move.
  - Blocked by: 8 · Stories: 10, 13

### Phase D: editing and saving

- [ ] **10. The edit session: pending edits, undo and redo.**
  - `edit_session.gd` (`class_name EditSession`, `extends RefCounted`), a pure model.
  - Interfaces produced:
    - `class Edit`, with `file: String`, `key_path: Array[String]`, `before: Variant` (null when absent), `after: Variant` (null to remove) and `label: String`;
    - `func apply(e: Edit) -> void`, `func undo() -> bool`, `func redo() -> bool`;
    - `func value(file: String, key_path: Array[String], fallback: Variant) -> Variant`, the current value with pending edits applied;
    - `func dirty_files() -> PackedStringArray` and `func is_dirty(entry: StudioCatalogue.Entry) -> bool`;
    - `func text_for(file: String, original: String) -> String`, which applies the file's pending edits to its loaded text through SourceEdit, picking the flavour by extension;
    - `func clear(file: String) -> void`;
    - `signal changed()`.
  - The session records each file's text and modified time when first loaded (`var loaded: Dictionary[String, Array]`, holding `[text, mtime]`) for task 15's clobber check.
  - The editor and the gallery show `unsaved` badges from `is_dirty`. Leaving the Studio (closing the window) with dirty files asks first (`get_tree().auto_accept_quit = false` plus a `ConfirmationDialog`).
  - Check, in `test_edit_session.gd`:
    - three edits to two files undo and redo back to identical `text_for` output;
    - an edit then a new edit after an undo drops the redo stack;
    - `value()` sees pending edits;
    - dirty tracking.
  - Blocked by: 2 · Stories: 18

- [ ] **11. Marker editing.**
  - `editor/marker_panel.gd` lists the four markers with spin boxes. Dragging a marker on the timeline edits it too, snapped to whole source frames, with Alt for halves.
  - When viewing a clip alone, edits go to `clip_manifest.json` at `["clips", <id>, "markers", <name>]`. When viewing a move, a toggle picks between the clip's markers and the move's `marks` override (`move_clips.json` at `[<weapon>, "moves", <id>, "marks"]`), and creating the override copies the clip's markers first.
  - Markers must stay in order (windup ≤ contact ≤ contact_end ≤ settle). The drag clamps.
  - Clearing the provisional flag is a checkbox, written to `["clips", <id>, "provisional"]`.
  - Check, in `test_marker_edits.gd`:
    - dragging contact past contact_end clamps;
    - the edit goes to the right file and path in each mode;
    - creating an override copies the clip's markers;
    - after `text_for`, `ClipManifest`/`MoveClips` read the new values from a temp copy.
  - Blocked by: 8, 10 · Stories: 14

- [ ] **12. The chain panel.**
  - `editor/chain_panel.gd` shows the move's parts as rows. Each row has:
    - a clip picker: a searchable list of pack clips (manifest ids), `ual/` clips and keyed clips;
    - from and to spin boxes, blank for whole;
    - a hold frame and a count (`id@frame*n`);
    - up, down and delete buttons.

    Below the rows: add part, speed (1.0–2.0, step `SwingBake.SPEED_STEP`, or blank to let the bake pick), the fallback clip, and sheathed frames.
  - It serializes with `static func part_text(id: String, from: float, to: float, hold_frame: float, hold_count: int) -> String`, the exact syntax `ClipChain.parse` reads, and writes `clips`, `speed`, `fallback` and `sheathed` at `[<weapon>, "moves", <id>, <field>]`.
  - Changing the chain re-lays the poser live, so the viewport and the timeline follow the pending chain.
  - Check, in `test_chain_panel.gd`: every part shape is round-tripped through `ClipChain.parse`:
    - whole;
    - `@from`;
    - `@from-to`;
    - `@frame*n`;
    - `ual/x`.

    Also: reordering writes the array in the new order, and a hold on a frame past the clip's length is refused with the parser's error shown.
  - Blocked by: 10 · Stories: 15

- [ ] **13. The frame-data panel.**
  - `moves_patch.gd` (`class_name MovesPatch`):
    - `const FIELDS := ["startup", "active", "recovery", "lunge", "lunge_end", "range", "arc", "damage", "posture", "knockback", "dodge_cancel_from"]`;
    - `static func path_for(weapon: StringName) -> String`, which gives `res://sim/moves/<weapon>.gd`;
    - edits go through SourceEdit with `key_path = ["MOVES", <move id>, <field>]` and flavour `&"gd"`;
    - a move whose entry isn't a plain dict literal under `MOVES`, or a field whose value isn't a number literal, is refused with SourceEdit's error.
  - `editor/frame_data_panel.gd` shows the fields with spin boxes beside the bands. Editing startup, active or recovery redraws the bands from the pending values.
  - Check, in `test_moves_patch.gd`:
    - editing `k_l1.startup` in a copy of `katana.gd` changes only that number, and the file still compiles (`GDScript.reload() == OK`);
    - a load of the patched script's `MOVES` gives the new value;
    - a refused field leaves the text unchanged and reports why.
  - Blocked by: 10 · Stories: 16

- [ ] **14. The state timings panel.**
  - `editor/state_panel.gd` edits a state or ult entry's fields from `state_clips.json`: clip pickers for clip ids, spin boxes for frames and speeds, in the order the file holds them. Edits are written through the session at `[<group>, <key>...]`.
  - Each state's viewport plays the edited clip choice live.
  - Check, in `test_state_panel.gd`:
    - editing `stun.clip` and `ults.impaler.out` writes the right paths;
    - `StateClips.read` of the result has the new values;
    - unknown keys can't be created from the panel.
  - Blocked by: 3, 10 · Stories: 17

- [ ] **15. Save, bake and the balance flag.**
  - `studio_saver.gd` (`class_name StudioSaver`):
    - `func save(session: EditSession, parent: Node) -> Result`, where `class Result` holds `written: PackedStringArray`, `refused: Dictionary[String, String]` (file to reason), `bake_errors: PackedStringArray`, `balance: Dictionary[StringName, PackedStringArray]` (move id to changed fields) and `report: PackedStringArray`.
    - **Clobber check.** For each dirty file, if its text on disk differs from `session.loaded[file][0]`, refuse that file with "changed on disk since it was opened" and keep its edits pending, with a Reload button that drops them (Review Focus 3).
    - **Atomic write.** Write each new text to `<file>.studio-tmp`, then rename over the file. Keep each file's old text in memory.
    - **Bake.** For each weapon whose `move_clips.json` entries, clip markers or `sim/moves/<weapon>.gd` changed, call `bake_swings.gd`'s `bake_weapon(wid, MoveClips.read(...), ClipManifest.read(), parent, old)` in-process. This needs the packs; without them the save writes the data and reports "bake skipped: no clip libraries", as the CLI does.
    - **Bake refused** (`out.errors` not empty). Restore every file written in this save from memory, and report the errors. The editor shows them with two buttons:
      - **Set frame data to match** reads the baked startup, active and recovery from the bake report, pushes them as frame-data edits and saves again;
      - **Undo save** keeps the edits pending.
    - **Balance flag.** Compare each touched move's `AttackDef` fields and the baked `reach` before and after: any change in startup, active, recovery, range, arc, lunge, lunge_end or reach marks `balance[move]`. The entry shows the `balance` badge until `git diff --quiet -- <files>` says the files are committed.
  - The editor's Save button (Ctrl+S) shows the report in a panel. The balance badge's tooltip says "Balance change: update tests and docs/mvp-spec.md, and run a soak before committing", and a "Send to chat" button pre-fills the chat panel (task 17) with a request to do that.
  - Check, in `test_studio_saver.gd`, on temp copies of the data files with the bake behind a Callable seam so tests can fake it:
    - a clean save writes only dirty files;
    - a file changed on disk is refused and its edits kept;
    - a refusing fake bake restores every file byte for byte;
    - a startup change sets the balance flag and a fallback-clip change doesn't;
    - with the packs present (local-only), the real bake of an unchanged katana gives `text == old`.
  - Blocked by: 11, 12, 13, 14 · Stories: 19, 20

### Phase E: refinements

- [ ] **16. The refinement launcher.**
  - `chat/process_runner.gd` (`class_name ProcessRunner`): `func run(cmd: String, args: PackedStringArray, cwd: String) -> Array`, returning `[exit_code: int, output: String]` through `OS.execute` with `cwd` handled by running `git -C <cwd>` / `cmd /c cd /d <cwd> && ...`, and `func spawn(cmd: String, args: PackedStringArray) -> int` (`OS.create_process`). Tests pass `FakeRunner` (in the test folder), which records calls and returns scripted results.
  - `chat/context_writer.gd` (`class_name ContextWriter`):
    - `static func prompt_md(prompt: String, entry, frame_or_range: Vector2i, base_branch: String) -> String`. It includes the owner's prompt verbatim in a fenced block, the animation (kind, group, id, name), the frame or range, and the base branch. It then gives the instructions:
      - follow CLAUDE.md;
      - size the work per CLAUDE.md;
      - open the pull request against the base branch;
      - never commit `.anim-refine/` or pack files;
      - balance changes need tests, `docs/mvp-spec.md` and a soak;
      - first check the game launches in this worktree.
    - `static func animation_json(entry, session: EditSession) -> String`: the entry's data with each value's file, key path and line (line found from `SourceEdit.find_value` span start).
  - `chat/refinement_launcher.gd` (`class_name RefinementLauncher`):
    - `static func slug(prompt: String) -> String`: lowercase ASCII words, at most 5 words and 40 characters, falling back to `refine` (Review Focus 4);
    - `func branch_name(entry, prompt) -> String`, which gives `anim/<id>-<slug>` with `-2`, `-3`… while `git rev-parse --verify` finds it or the worktree path exists;
    - `func launch(prompt: String, entry, frame_or_range: Vector2i, screenshot: Image) -> Result`, where `class Result` holds `ok: bool`, `step: String`, `message: String`, `branch: String` and `worktree: String`. It runs these steps in order, each failure stopping with `step` named (Review Focus 5):
      1. `git rev-parse --abbrev-ref HEAD` (base branch) and `git status --porcelain` (warn, task 17);
      2. `git worktree add -b <branch> <repo>/.claude/worktrees/anim-<id>-<slug> HEAD`;
      3. copy `.godot-path` and `.assets-src-path` if present; `cmd /c mklink /J node_modules <main>/node_modules`; copy `game/assets/kevin_iglesias/library/*.res` if present;
      4. write `.anim-refine/prompt.md`, `animation.json` and `screenshot.png` (`Image.save_png`);
      5. spawn the terminal (task 17).

      A failure after step 2 reports the worktree path and leaves it in place.
    - An empty or whitespace prompt returns `ok = false` and `step = "prompt"` without running anything.
  - Check, in `test_refinement_launcher.gd` with FakeRunner and a temp folder as the repo:
    - commands come in order, with the right args;
    - a taken branch gets `-2`;
    - prompts with quotes, newlines, backticks, `%`, emoji and 5,000 characters reach `prompt.md` byte for byte inside the block, with an ASCII slug of 40 characters or fewer;
    - an empty prompt runs nothing;
    - a scripted failure at each step gives that `step` and no log entry;
    - `animation_json` names `move_clips.json` and the right line for `k_l1`.
  - Blocked by: 4, 10 · Stories: 29, 31, 33, 35

- [ ] **17. The chat panel, the terminal and the log.**
  - **The panel.** `chat/chat_panel.tscn/.gd` has:
    - the selected animation's name;
    - the frame or range from the timeline (`range_selected`, or the playhead);
    - a multi-line prompt box with Send (Ctrl+Enter);
    - the animation's refinement log below.
  - **On Send:**
    1. If the session is dirty or `git status --porcelain` isn't empty, a dialog warns: "Unsaved or uncommitted edits won't be in the new worktree." The owner chooses Send or Cancel (story 30).
    2. The viewport is captured to an image (`get_viewport().get_texture().get_image()` of the editor's SubViewport).
    3. `RefinementLauncher.launch` runs.
  - **The terminal.** Step 5 spawns `wt.exe -d <worktree> --title "<id> refinement" claude "Read .anim-refine/prompt.md and follow it."`. If `wt.exe` is missing, it falls back to `cmd /c start "<id>" /D <worktree> cmd /k claude "Read .anim-refine/prompt.md and follow it."`. If `claude` isn't on PATH (`where claude` fails), it reports step "terminal" with the command to run by hand.
  - **The log.** `chat/refinement_log.gd` (`class_name RefinementLog`):
    - `const PATH := "res://tools/anim_studio/.refinements.json"`;
    - `func add(entry_key: String, r: RefinementLauncher.Result, prompt: String) -> void`;
    - `func for_entry(entry_key: String) -> Array[Dictionary]`;
    - `func refresh_pr(item: Dictionary, runner: ProcessRunner) -> void`, which runs `gh pr list --head <branch> --json url,state --limit 1` and caches the result.

    Each row shows the prompt's first line, the branch, the time and the PR link (`OS.shell_open`). It has buttons for "Reopen terminal" (`claude --continue` in the worktree, same spawn rule) and "Open folder".
  - **Balance hand-off.** The balance badge's "Send to chat" (task 15) fills the prompt box.
  - Check:
    - `test_refinement_log.gd`: add, then `for_entry`, survives a reload; `refresh_pr` parses scripted `gh` output, and empty output means no PR yet;
    - `test_chat_panel.gd` with FakeRunner: the dirty warning appears; the `wt.exe` and `cmd` fallback command lines are as above.
  - **Gate.** One real refinement end to end with the owner: send a small tweak on a Katana move, see the terminal open in the new worktree with the context, and see Claude open a PR against the Studio's branch. Its log row shows the PR.
  - Blocked by: 15, 16 · Stories: 28, 30, 32, 34

### Phase F: correctives and posing

- [ ] **18. Correctives in the game.**
  - **The data.** `game/view/fighter/clip_correctives.gd` (`class_name ClipCorrectives`, `extends RefCounted`):
    - `const FOLDER := "res://assets/authored/correctives"`;
    - `class Key`, holding `frame: float` (source frames) and `bones: Dictionary[StringName, Quaternion]`, read from `{"bone": [x, y, z]}` Euler degrees in the file;
    - `class Corrective`, holding `clip: StringName`, `keys: Array[Key]`, `interp: StringName` (`&"linear"` or `&"smooth"`, slerp with smoothstep), `ease_in: float`, `ease_out: float` and `overrides: Dictionary[StringName, Array[Key]]` (by set: `&"HumanM"`, `&"HumanF"`);
    - `static func read(clip: StringName) -> Corrective`, null when there is no file;
    - `static func write_text(c: Corrective) -> String`, in house format;
    - `func sample(frame: float, set_name: StringName) -> Dictionary[StringName, Quaternion]`. Override keys replace shared keys only for the bones they name. The weight ramps from 0 to 1 over `ease_in` frames before the first key and from 1 to 0 over `ease_out` frames after the last.
  - **The modifier.** `class CorrectiveModifier extends SkeletonModifier3D` (same file or `clip_corrective_modifier.gd`):
    - `var clip: StringName`, `var frame: float` and `var set_name: StringName`, set each frame by whoever poses the clip;
    - `_process_modification()` multiplies each sampled offset onto the bone's pose rotation (`set_bone_pose_rotation(b, get_bone_pose_rotation(b) * q)`);
    - it does nothing when the clip has no corrective. Files are cached by clip id, with `static func invalidate(clip)` for the Studio.
  - **Install.** FighterRig adds the modifier as the first SkeletonModifier3D child of `%GeneralSkeleton`, so it runs after the AnimationTree and before foot lock, the lean, the grips and the IK.
    - FighterView sets `clip`, `frame` and `set_name` from the Shot's driving clip and its time each rules frame. The source frame is the clip's time × `ClipManifest.SOURCE_FPS`, and for a chain the part's clip and local frame come from `ClipChain.place`.
    - ClipPoser sets them in `_apply(index, frame)`, so the bake samples corrected poses.
  - Check, in `tests/view/test_clip_correctives.gd`:
    - with no file, the pose is bit-for-bit unchanged (compare all bone poses);
    - one key offsets only its bone, by its amount, at its frame;
    - linear and smooth interpolation at the midpoint;
    - easing at the edges;
    - a HumanF override replaces the shared key for that bone on HumanF only;
    - the corrective follows ClipTiming: the offset peaks on the rules frame that maps to the key's source frame;
    - with a corrective on the right forearm, `bake_weapon` (local-only) gives a different `right_hand` track, and with an empty corrective file the swing text is unchanged.
  - Blocked by: 2 · Stories: 23–25

- [ ] **19. Bone posing: pick, rotate, key.**
  - **Picking.** `editor/bone_picker.gd` lists the humanoid bones (`SkeletonProfileHumanoid` names) in a tree. A click in the viewport ray-picks the nearest bone, using bone positions and a small screen-space radius.
  - **Rotating.** `editor/pose_gizmo.gd` (`class_name PoseGizmo`, `extends Node3D`) draws three rotation rings on the selected bone. Dragging a ring rotates about that axis in bone-local space, Shift snaps to 5°, and numeric fields in the Pose tab mirror it.
  - **Keying.** "Key" writes the bone's offset from the clip's own pose at the current source frame into the pending corrective (a session Edit on `assets/authored/correctives/<clip>.json`). Edits are per bone, per key frame. "Delete key" and a key track on the timeline (diamonds) let you jump between keys. A body scope picker (Shared, Hunter only, Rogue only) picks between shared keys and an override.
  - **Ghost.** The uncorrected pose draws as a translucent second skeleton (a duplicate model with the modifier off, shaded with an unshaded transparent material).
  - **Saving.** Save writes the corrective file, calls `ClipCorrectives.invalidate`, and re-bakes every weapon whose moves use the clip (task 15's bake path, with the balance flag).
  - Check, in `test_pose_edits.gd`:
    - keying a 20° elbow bend writes the expected Euler values to the corrective's key;
    - deleting the key leaves no key;
    - scope Rogue writes under `overrides.HumanF`;
    - undo restores the previous corrective;
    - `ClipCorrectives.read` of the saved temp file samples the same offset.

    Plus a shot of the gizmo and ghost.
  - Blocked by: 15, 18 · Stories: 21, 23, 24, 27

- [ ] **20. IK handles.**
  - `editor/ik_handles.gd` (`class_name IkHandles`) adds draggable handles for the left and right hands, the left and right feet, the hips and the chest. Dragging a hand or foot solves its limb with two-bone IK; Godot 4.7's `TwoBoneIK3D` or the solver in `tools/keyed_pose.gd` (`KeyedPose._limb`), whichever gives the same bend directions (`LEG_BEND`, `ARM_BEND`). Hips and chest translate and rotate.
  - On a corrective, "Key" converts the solved pose into per-bone rotation offsets from the clip's pose (upper arm, forearm and hand, or thigh, shin and foot) and keys them as task 19 does.
  - Check, in `test_ik_handles.gd`: dragging the right hand 10 cm forward and keying gives offsets that, sampled back through the modifier, put the hand within 1 cm of the target; the elbow bends the right way (pole side).
  - Blocked by: 19 · Stories: 22

- [ ] **21. Keyed clip editing.**
  - `editor/keyed_editor.gd`:
    - **Open.** Opening a keyed source entry (Mikiri_Stomp, Mikiri_Pinned) or "New keyed clip" (asks for an id, CamelCase, unique) edits `assets/authored/keys/<id>.json` in KeyedPose's format. Its keys are frames with IK targets for the hips, spine, legs and arms, as `KeyedPose.solve` reads them.
    - **Pose.** The IK handles (task 20) set the targets on the current key. "Add key" and "delete key" work on the timeline. The pose is solved live with `KeyedPose.solve(key, skeleton, base)`, with in-between frames as `KeyedPose.build` interpolates them.
    - **Save.** Save writes the JSON, then rebuilds `keyed_library.tres`. `tools/build_keyed_clips.gd` gets a small refactor: its `_initialize` body moves into `static func build_all(parent: Node, errors: Array[String]) -> AnimationLibrary`, which `_initialize` calls, so the CLI is unchanged. The Studio calls `build_all`, then `ResourceSaver.save` to `KeyedClips.PATH`. It's a tool file, not game code, but it adds one touch point to the spec's list.
    - **Refresh.** The catalogue rebuilds, so a new clip appears in Source and in the chain panel's picker.
  - Check, in `test_keyed_editor.gd`:
    - creating `TestKick` with two keys writes a file `KeyedPose.build` turns into an Animation of the right length;
    - editing Mikiri_Stomp's hips target on one key changes only that value (SourceEdit);
    - a duplicate id is refused;
    - after a rebuild the catalogue lists the new clip.
  - Blocked by: 20 · Stories: 26

### Phase G: the owner's review

- [ ] **22. The owner's review.**
  - Shots of every gallery tab on both bodies, and of the editor on a move, a state, an ult, a keyed clip and a corrective being posed. A short screen recording of scrubbing and a save with a bake.
  - The spec's status line is updated and each delivered user story ticked. `docs/specs/authored-animation.md` gets a one-line pointer to correctives under its "Presentation" section.
  - PR #19 is marked ready.
  - **Gate.** The owner tries the Studio and approves the pull request.
  - Blocked by: 17, 21 · Stories: all
