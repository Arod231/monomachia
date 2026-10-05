> Research notes from the Oct 1, 2026 task breakdown, a snapshot of the code at 51dcfb0.
> The plan (`docs/plans/godot-rebuild.md`) is the source of truth: its task ids, order and decisions
> supersede the proposals and keys here. Line numbers drift as the code changes.

# Plan tasks 22 (menus), 23 (Training, Watch and Versus) and 24 (the full HUD)

## Current state
What exists on feature/godot-rebuild (c400858), all from task 6 and task 21:

- **Flow:** `game/scenes/main.gd` and `main.tscn` run title, main menu, Duel or Watch, results and pause using a `Screen` enum (TITLE, MENU, PLAYING, PAUSED, RESULTS).
  - Menus are built in code on the "Menus" CanvasLayer (layer 10). Duel and Watch start the fixed `MatchConfig.default_duel()` and `default_watch()`; there is no select screen.
  - Rematch reuses `last_config.with_seed()`. One seed sequence (`_next_seed`) feeds both the matches and the attract duel.
  - `tests/view/test_main_flow.gd` covers this flow.
- **Stand-in screens (`game/ui/menus`):**
  - `MenuScreen` is a panel with a column of buttons, using per-node StyleBoxFlat overrides. It acts in `_unhandled_input` and never in `_input`, because the InputFeed must see every event. It adds W/S and controller A/B by hand, since the default `ui_accept`/`ui_cancel` lack them. There is no stick auto-repeat.
  - `TitleScreen` shows MONOMACHIA, "Single combat" and "Press any key or button".
  - `ResultsScreen` has Rematch and Main menu only; there is no Change fighters.
  - The pause menu, built inside `main.gd`, has only Resume and Main menu.
  - There is no theme, no fonts (`gui/theme/custom` is unset and no TTFs are in the repo; the demo loaded Zen Antique and Zen Kaku Gothic New from Google Fonts in `index.html`), no settings store and no ported menu data (`WEAPON_INFO`, `ABILITY_INFO` and `TRAINING_BEHAVIOURS` in `src/ui/data.ts`).
- **HUD (`game/ui/hud/match_hud.gd`, 387 lines, plus `hud_bar.gd`, CanvasLayer 5 inside `match_host.tscn`) is minimal:**
  - Plates show "Name · Weapon" and a Disarmed tag.
  - The HP bar has a lag band (`LAG_HOLD` 0.45 s, `LAG_DRAIN` 0.6/s on the wall clock) and blinks at 25% HP or less.
  - Posture uses hot at 70% and blinks when full; pips are ColorRects; the ultimate badge is the text "ULT"; the round label has no kanji.
  - Announcements are English only (no kanji, sublines partly, no animation). They are timed on `host.step_count`: `ROUND_FRAMES` 78, `FIGHT` 54, `KO` 120, `DOUBLE_KO` 132, `ROUND_RESULT_DELAY` 78 / 96, `DISARM` 90. So they already freeze in pause.
  - One hint line covers only "pick up" and "ultimate ready". It has no `show_hints` setting and no hints in Versus (`_me()` returns -1 in VERSUS).
  - Missing entirely: toasts, the weapon marker and the training panel.
- **`game/core`:**
  - `GameServices` autoload owns `ControlProfiles` (`user://controls.cfg`), `InputDevices` and `InputFeed`, and pauses on focus loss.
  - `MatchConfig` covers modes, sides, `arena_id`, `world_seed`, `problem()` validation (Training needs the DUMMY on side 1; Versus needs two distinct devices), and `to_dict`/`from_dict` "for saving the last selection". It has no `default_training()`.
  - `MatchSide` holds fighter_id, palette, weapon_id, abilities, controller (HUMAN, COMPUTER, DUMMY), device, profile and difficulty. It has no random flag, and `FIGHTER_NAMES` duplicates task 13's `FighterLook.IDS`.
  - `MatchResults` holds the 7 stats, `title()` and `stat_text()`.
- **`game/input`:** `RebindCapture` (keyboard/pad tabs, Esc cancels, Backspace/Delete clears, `apply_to`), `ControlProfiles` (add, rename to 24 characters, delete, save), `ControlProfile` (`reset_tab`, `use_fight_stick_layout`), `BindingLabels`, `PadStyle.detect`/`display_name`, and `InputDevices` (`set_versus`, `label(action, player)`, `last_used`, `pad_name`, `excluded_tokens`). The Controls screen that drives them doesn't exist.
- **`MatchHost` (`game/view/match/match_host.gd`):**
  - Training runs `sim_match.endless` with a `TrainingBrain`, but `_after_step` only carries a comment: there is no refill, no getting up after a KO (the fighter stays down) and no dummy re-arm.
  - There is no API to change the dummy's behaviour. `TrainingBrain.set_behaviour()` and `ability_for()` exist in `game/sim/ai/training_brain.gd`.
  - Training and Versus run in tests (`test_match_host.gd`) but aren't on the menu.
  - `resume()` already calls `set_profile` and `rearm_pause`; `stop()` calls `unbind_seats`.
- **View:** `MatchView` (`match_view.gd`) has a single `CameraRig` (a Camera3D child named "CameraRig") following `host.view_side()`, so there is no split screen.
  - `CameraRig` already has a WATCH side-on mode, a MENU orbit (radius 10.5 m, height 3.2 m), and `shake_scale`/`fov_kick_scale`, whose comment says reduce-flashes sets 0.15 and 0.
  - The KO orbit is already off in VERSUS.
  - `ArenaScenes.SCENES` lists `standin` and `moonlit_shrine`.
- **Audio:** the sound bank has `ui_move`, `ui_select`, `ui_confirm` and `ui_back` cues, and `default_bus_layout.tres` has Master, Music (-6 dB), Ambience, SFX (Combat, Foley), UI. Nothing plays yet; the players are task 19 and 20 work.
- **Rules state the HUD and training need is public:**
  - Fighter: `block_press_frame`, `parry_window_at_press`, `counter_lunge_until`, `ult` (`kind`/`phase`), `ult_used`, `can_ult()`.
  - World: `ko_resolved`, `slowmo_frames`, `remove_dropped_weapon()`, `weapon_of()`.
  - The `parry` event carries `timing` and `window`. `parryEarly` is never emitted.
- **Off-branch work this area depends on:**
  - Task 13 (branch `fighters-and-weapons`, unmerged): `FighterLook` (`IDS`, `palettes` with exactly two, the second "dresses the second fighter of a mirror match", `signature_weapon`) and `FighterModel` (`attach_weapon`, `apply_palette`, `play_idle`), which the select preview needs.
  - Tasks 16 and 17 (worktree `wf_c7f99fe5-f9a-1`, uncommitted, based on 67265af): `GraphicsPreset` (low, medium, high; default high) and `GraphicsApplier` (static `current()`/`apply()`) in `game/view/look/`, which the graphics setting needs.
  - That worktree's menu-orbit screenshot frames the whole island from far off, so the fighters would be specks.
- **Surprise, a contradiction to resolve:**
  - The spec's Out of Scope says the design doc's select (model on the right, loadout on the left, lock-in, gate) is out, with "a simpler fighter and loadout select".
  - Plan task 22 (and `pending-plan-changes.md` item 3) says to build that layout now, without the gate and intros.
  - The plan's "Not yet specified" still lists the full character select.

## Tasks

### [22] ui-theme-and-fonts (M): Ink-wash UI theme and bundled fonts
- delivers: Zen Antique and Zen Kaku Gothic New (Regular, Bold) TTFs in game/assets/fonts with the OFL licence text and a credits line | UiPalette constants ported from the demo's CSS tokens (ink #0f0b0b, ink-2, ink-3, line #4a352c, paper #eadfca, paper-dim, lacquer #b3261e, gold #c9a15a, jade #6fd6b8, posture #e7a53b, danger #ff3b25, hp-hi/hp-lo) | a project Theme set as gui/theme/custom: default font Zen Kaku Gothic New; type variations Display (Zen Antique), Kanji, Eyebrow, Muted; lacquered panel and button styleboxes (normal, hover, gold-edged focus, pressed, disabled), slider, option, tab, line edit and scroll styles | the stand-in MenuScreen, TitleScreen, ResultsScreen, pause and MatchHud switched from per-node overrides to the theme
- check: GUT tests/ui/test_ui_theme.gd: the theme loads; default font is Zen Kaku Gothic New and Display is Zen Antique; both fonts have every kanji the UI uses (一..九 第 戦 始め 一本 相打ち 勝 敗 勝利 敗北 決着 休止 武器喪失 奥義 赤 青 一騎討ち 刀 大剣 双短刀 危) | screenshots of the current title, main menu, pause, results and an in-match HUD in the theme, reviewed by eye | npm test and npm run typecheck pass
- depends: 
- stories: 2, 3, 8, 9, 46
- files: game/assets/fonts/ZenAntique-Regular.ttf, game/assets/fonts/ZenKakuGothicNew-Regular.ttf, game/assets/fonts/ZenKakuGothicNew-Bold.ttf, game/assets/fonts/OFL.txt, game/ui/theme/ui_palette.gd, game/ui/theme/ui_theme.gd, game/ui/theme/ui_theme.tres, game/project.godot, game/ui/menus/menu_screen.gd, game/ui/menus/title_screen.gd, game/ui/menus/results_screen.gd, game/ui/hud/match_hud.gd, game/tests/ui/test_ui_theme.gd
- notes: No font files are in the repo: the demo loaded them from Google Fonts (index.html). Fetching them from the google/fonts repository (ofl/zenantique, ofl/zenkakugothicnew) is a download to clear with the owner first. CJK fonts are a few MB each, so keep every file under the planned 10 MB cap. Check large kanji (84 px announcements) for import quality: MSDF or oversampling.

### [22] menu-navigation-kit (M): Screen stack and menu navigation for keyboard, mouse and controller
- delivers: ScreenStack: push, replace and pop screens on the Menus CanvasLayer; Back returns to whichever screen opened this one (a sub-screen opened from pause returns to pause); opened(args) and closed hooks; a first-focus rule | a MenuPage base replacing the stand-in MenuScreen, keeping its rule of acting in _unhandled_input and never taking events in _input (the InputFeed must see them) | navigation: arrows/WASD, Enter/Space, Esc/Backspace; D-pad and left stick with the demo's repeat (stick past 0.55, first repeat 380 ms, then every 120 ms); A chooses, B goes back; mouse hover focuses | reusable rows: an option row (left/right cycles, like the demo's segmented buttons) and a 0-100 slider row (left/right steps by 5) | main.gd moved from its Screen enum onto the stack with today's flow unchanged (title, main menu, Duel, Watch, results, pause)
- check: GUT tests/ui/test_screen_stack.gd: push, pop and replace; Back returns to the opener; focus lands on the first item | GUT tests/ui/test_menu_nav.gd: pushed key events and pushed joypad events move focus and press; with a fake clock the stick repeats at 380 ms, then every 120 ms; left/right change an option row and a slider | tests/view/test_main_flow.gd still passes (behaviour unchanged) | npm test and npm run typecheck pass
- depends: ui-theme-and-fonts
- stories: 3, 9
- files: game/ui/menus/screen_stack.gd, game/ui/menus/menu_page.gd, game/ui/menus/menu_nav.gd, game/ui/menus/option_row.gd, game/ui/menus/slider_row.gd, game/ui/menus/menu_screen.gd, game/scenes/main.gd, game/scenes/main.tscn, game/tests/ui/test_screen_stack.gd, game/tests/ui/test_menu_nav.gd, game/tests/view/test_main_flow.gd
- notes: Godot's ui_* actions cover the arrows, Enter and the D-pad. They lack W/S, controller A/B (MenuScreen handles these by hand today) and stick repeat (the demo's MenuNav did it). A ui_cue(name) signal (ui_move, ui_select, ui_confirm, ui_back: the sound bank's UI cues) is the seam for task 19's player, which nothing calls yet.

### [22] title-and-main-menu (M): Title over the live duel, and the main menu
- delivers: the title in the theme with the demo's content (vertical 一騎討ち, the 一騎 seal, MONOMACHIA, 'Single combat', a pulsing 'Press any key or button', a device note), laid out so the attract duel (MatchConfig.attract, the CameraRig MENU orbit) reads behind it | the main menu: logo and tagline, a lacquered column of entries with sublabels: Duel ('against the computer'), Watch ('computer against computer') and Quit. Later tasks add Training, Versus, How to play, Controls and Settings as their screens land | Back on the main menu returns to the title
- check: GUT: the title opens over a started attract host; any key, click or controller button goes on; the main menu's entries and order; a keyboard-only walk and a controller-only walk from the title to a started Duel | screenshots of the title and main menu over the duel, reviewed for the fighters staying visible behind the text (again on the shrine once task 17 is merged) | npm test and npm run typecheck pass
- depends: menu-navigation-kit
- stories: 2, 3
- files: game/ui/menus/title_screen.gd, game/ui/menus/main_menu_screen.gd, game/scenes/main.gd, game/tests/ui/test_title_and_main_menu.gd, game/tests/view/test_main_flow.gd, game/tools/shot_scenes/menu_shots.gd, game/tools/shot_scenes/menus_title.tscn, game/tools/shot_scenes/menus_main.tscn
- notes: The attract duel and the HUD hiding in attract already work (MatchHost.start(cfg, true)). This task restyles the screens and checks the framing. Tune CameraRig's exported menu_radius and menu_height if the real shrine hides the fighters.

### [22] match-selection-model (M): Selection model: last picks per mode, defaults, random and mirror rules
- delivers: MatchSelection (plain data, no nodes): one draft per mode (a MatchConfig plus random_weapon for the Duel opponent and random_arena), with the demo's defaults. Duel: Rogue/katana against Hunter/greatsword on Normal. Training: katana against a greatsword dummy. Watch: katana (Normal) against daggers (Normal). Versus: kbm against pad0, or kb_arrows when no controller is connected | rules: picking a weapon resets that side's abilities to the weapon's defaults; picking the ability already in the other slot swaps the two; in a mirror match the second side wears palette 1, otherwise palette 0 | resolve(rng) -> MatchConfig: draws the random weapon (with its default abilities) and the random arena, and the result passes MatchConfig.problem() | saving to user://last_select.cfg through MatchConfig.to_dict()/from_dict(); unreadable or invalid entries fall back to the defaults | MatchConfig.default_training(); ArenaScenes gains the list of selectable arenas with display names (the stand-in excluded)
- check: GUT tests/core/test_match_selection.gd, written first: every mode's default resolves with no problem(); the ability swap; the mirror palette; random picks draw only playable weapons and selectable arenas and repeat for a seeded RandomNumberGenerator; save and load round-trip; a corrupt file gives the defaults | npm test and npm run typecheck pass
- depends: 
- stories: 4, 5, 44, 45
- files: game/core/match_selection.gd, game/core/match_config.gd, game/core/match_side.gd, game/view/match/arena_scenes.gd, game/tests/core/test_match_selection.gd
- notes: MatchSide has no random flag, and the host never changes a MatchConfig, so random choices stay in the selection and resolve at lock in, as the demo resolved side.random at Begin.

### [22] select-flow (M): Fighter select: grid, per-side steps, difficulty, arena slot and lock in
- delivers: a select screen in the design layout: the fighter grid (Rogue, Hunter); a loadout column on the left (it shows only the weapon until the next task); the right side framed and reserved for the 3D preview | per-side steps: side 1, then side 2, titled per mode (You / Opponent; Red fighter / Blue fighter), each locked in. Back from side 2 returns to side 1, and from side 1 to the main menu | a Computer skill row (Easy, Normal, Hard) on computer sides | the arena slot (Moonlit Shrine, Random) and the final Lock in, which resolves and saves the MatchSelection and starts the match | Duel and Watch on the main menu open the select instead of the fixed defaults
- check: GUT tests/ui/test_select_screen.gd: walking the select with key events and with joypad events starts the expected MatchConfig (fighters, difficulty, arena, palettes); Back steps between sides; the last picks come back on the next visit | screenshots of both steps in Duel and in Watch | npm test and npm run typecheck pass
- depends: title-and-main-menu, match-selection-model
- stories: 3, 4, 5, 44
- files: game/ui/menus/select_screen.gd, game/ui/menus/fighter_grid.gd, game/ui/menus/main_menu_screen.gd, game/scenes/main.gd, game/tests/ui/test_select_screen.gd, game/tests/view/test_main_flow.gd, game/tools/shot_scenes/menu_shots.gd
- notes: This commit fixes the spec's Out of Scope line and the plan's 'Not yet specified' line to match the layout (see open questions). Today the fighter list is MatchSide.FIGHTER_NAMES; after task 13 merges, FighterLook.IDS is the select order, so keep only one source.

### [22] select-loadout-panel (M): Fighter select: loadout panel with weapon cards and block abilities
- delivers: menu data ported from src/ui/data.ts into game/ui/menu_data.gd: per weapon its kanji, class, five stat bars (speed, power, posture, reach, parry), ultimate name and description; per block ability its name and description | the loadout column: three weapon cards (kanji, class, name, stat bars); the weapon's blurb (WeaponDef.blurb) and its ultimate; 'Block abilities · pick 2 of 3' with the two slots ('Hold block + light', 'Hold block + heavy') and the chosen ability's description | Random weapon on the Duel opponent; no abilities for the training dummy side
- check: GUT tests/ui/test_loadout_panel.gd: every playable weapon and every ability id in Moves has menu data; choosing a card resets the abilities; the swap rule works through the UI; Random weapon hides the blurb and resolves at lock in; walks with keys only and with a controller only | screenshots of each weapon's card and abilities | npm test and npm run typecheck pass
- depends: select-flow
- stories: 4, 5
- files: game/ui/menu_data.gd, game/ui/menus/loadout_panel.gd, game/ui/menus/weapon_card.gd, game/ui/menus/select_screen.gd, game/tests/ui/test_loadout_panel.gd
- notes: The spec keeps the block abilities unchanged for all three weapons, so the ability data survives tasks 9-11.

### [22] select-3d-preview (M): Fighter select: 3D preview of the hovered fighter
- delivers: the right-hand preview: a SubViewport with its own World3D and a small lit stage, showing the hovered fighter's scene (fighters/<id>/<id>.tscn, a FighterModel) in that side's palette, holding the chosen weapon (attach_weapon), playing its idle clip and slowly turning | the model swaps on hover, palette and weapon changes without leaking nodes; in a mirror match the second side shows palette 1
- check: GUT tests/ui/test_fighter_preview.gd: hover swaps the model; palette and weapon follow the selection; no orphan nodes after 20 hover changes | screenshots of the select with each fighter, palette and weapon, reviewed by eye | npm test and npm run typecheck pass
- depends: select-flow, 13
- stories: 4, 44, 45
- files: game/ui/menus/fighter_preview.gd, game/ui/menus/fighter_preview.tscn, game/ui/menus/select_screen.gd, game/tests/ui/test_fighter_preview.gd
- notes: FighterModel and FighterLook exist only on the unmerged fighters-and-weapons branch (1f574a2, fcfb8d8), and the typecheck loads every script, so this waits for task 13's merge. Use the toon material and outlines once task 16 is merged.

### [22] results-screen (S): Results with stats, Rematch and Change fighters
- delivers: the results in the theme: kanji and title (勝利 Victory, 敗北 Defeat, or 決着 '<name> wins' in Watch and Versus); rounds won and rounds fought; the seven MatchResults stats in a table under each side's name and weapon, in the side colours | Rematch (same config, next seed), Change fighters (the select for the same mode with the last picks), Main menu; Back goes to the main menu
- check: GUT tests/ui/test_results_screen.gd: a lost Duel shows Defeat with the stats; Watch shows '<name> wins'; Rematch takes a new seed and keeps the loadouts; Change fighters opens the mode's select; walks with keys only and with a controller only | screenshots of a Victory, a Defeat and a Watch result | npm test and npm run typecheck pass
- depends: select-flow
- stories: 8
- files: game/ui/menus/results_screen.gd, game/core/match_results.gd, game/scenes/main.gd, game/tests/ui/test_results_screen.gd, game/tests/view/test_main_flow.gd

### [22] game-settings-store (S): Game settings: store, saving and applying
- delivers: GameSettings, owned by GameServices: graphics preset id (low, medium, high; default high), reduce flashes and shaking (default off), button hints (default on), and master, effects and music volumes (0-100) | saved to user://settings.cfg on every change, loaded at start, bad values clamped | applied: volumes scale the Master, SFX and Music buses relative to their levels in default_bus_layout.tres (Music sits at -6 dB); reduce flashes sets the match CameraRig's shake_scale to 0.15 and fov_kick_scale to 0 at match start and on change; a changed signal for the HUD's hints and task 18's effects
- check: GUT tests/core/test_game_settings.gd, written first: defaults; save and load round-trip to a temp path; clamping; volume 0 mutes and 100 keeps the layout's level; reduce flashes reaches the match camera | npm test and npm run typecheck pass
- depends: 
- stories: 52, 57
- files: game/core/game_settings.gd, game/core/game_services.gd, game/view/match/match_view.gd, game/tests/core/test_game_settings.gd, game/tests/core/test_game_services.gd
- notes: CameraRig's own comment already names the reduce-flashes numbers (0.15 and 0). Graphics only stores the id until graphics-preset-setting.

### [22] settings-screen (S): Settings screen
- delivers: Settings on the main menu: Graphics (Low, Medium, High), Reduce flashes and shaking (Off, On), Button hints on screen (On, Off), and Master, Effects and Music sliders; every change applies and saves at once; Back returns to the opener
- check: GUT tests/ui/test_settings_screen.gd: each row changes GameSettings and the file; sliders step by 5 with left/right; walks with keys only and with a controller only | screenshot of the screen | npm test and npm run typecheck pass
- depends: game-settings-store, title-and-main-menu
- stories: 52, 57
- files: game/ui/menus/settings_screen.gd, game/ui/menus/main_menu_screen.gd, game/tests/ui/test_settings_screen.gd

### [22] graphics-preset-setting (S): Apply the graphics preset setting
- delivers: the saved preset applied through task 16's GraphicsApplier at start, whenever Settings changes it, and whenever an arena or the select's preview stage loads; GraphicsApplier.current() follows the setting
- check: GUT: changing the setting changes GraphicsApplier.current() and the viewport's anti-aliasing and render scale; a newly loaded arena takes the setting | screenshots of a match on each preset after switching it in Settings | npm test and npm run typecheck pass
- depends: settings-screen, 16
- stories: 57
- files: game/core/game_settings.gd, game/core/game_services.gd, game/ui/menus/settings_screen.gd, game/view/look/graphics_applier.gd, game/tests/core/test_game_settings.gd
- notes: GraphicsPreset and GraphicsApplier exist only uncommitted in the look-and-arena worktree (game/view/look/), on a branch based on 67265af.

### [22] controls-bindings (M): Controls screen: binding table and rebinding capture
- delivers: Controls on the main menu, with Keyboard and mouse and Controller tabs; it opens on the tab of the last device used (InputDevices.last_used) | a status line: the controller's name and whether it gets PlayStation, Xbox or generic names (PadStyle), or 'No controller detected', plus the capture help text | the 13 actions from Bindings.ACTIONS with ACTION_LABELS and ACTION_HINTS, two slots each, named by BindingLabels in the detected style | choosing a slot starts a RebindCapture ('Press a key…', or 'Press a button…' once it arms); Esc cancels and Backspace or Delete clears; the result goes into the active profile and saves (ControlProfiles.save()); Back is ignored while listening | Reset to defaults (current tab) and Fight stick layout (Controller tab)
- check: GUT with FakeDeviceState, through the screen: binding a key, a mouse button, a controller button, a trigger and a stick direction; a token moves off its old action; clear and cancel; reset and fight stick; the saved file changes; walks with keys only and with a controller only | screenshots of both tabs and of a slot listening | npm test and npm run typecheck pass
- depends: title-and-main-menu
- stories: 56
- files: game/ui/menus/controls_screen.gd, game/ui/menus/binding_row.gd, game/ui/menus/main_menu_screen.gd, game/tests/ui/test_controls_screen.gd
- notes: RebindCapture's usage note says to feed it from _input() and mark each event handled. The InputFeed in the GameServices autoload also reads _input(), and a handled event never reaches it, so pass each event to GameServices.input.note_event() before taking it (held-key and Shift-side tracking).

### [22] controls-profiles (S): Controls screen: profiles
- delivers: the profile row: a picker over ControlProfiles.names() that makes the chosen profile active; Rename (a 24-character LineEdit, where an empty name keeps the old one); New profile ('Player N', made active); Delete, shown only when there is more than one profile; every change saves
- check: GUT: new, rename, delete and pick through the screen change ControlProfiles and the saved file; Delete is hidden with one profile; the bindings table follows the active profile | screenshot of the row with three profiles | npm test and npm run typecheck pass
- depends: controls-bindings
- stories: 56
- files: game/ui/menus/controls_screen.gd, game/ui/menus/profile_row.gd, game/tests/ui/test_controls_screen.gd

### [22] move-list-data (S): Move list generated from the move data
- delivers: MoveList (no nodes): for a WeaponDef, rows of input, move name, unblockable/counter, damage, posture and reach, read from the move data | coverage: the light and heavy strings walked from light_start and heavy_start through chain_light and chain_heavy (each move once, each string as 'A → B → C'); the sprint, dodge, backstep and jump attacks; the block abilities; fists included
- check: GUT tests/ui/test_move_list.gd, written first: every move reachable from a weapon's entry points and abilities appears exactly once; the numbers equal the AttackDef values; a made-up WeaponDef with a changed damage or an added follow-up changes the rows | npm test and npm run typecheck pass
- depends: 
- stories: 58
- files: game/ui/move_list.gd, game/tests/ui/test_move_list.gd
- notes: Tasks 9-11 replace the strings and task 7 derives reach from the swings. The walk reads whatever the data holds, so only the release_variant link (added by task 9) needs following once it exists. The demo's move list walked only chainLight.

### [22] how-to-play-screen (M): How to play and the move list screen
- delivers: How to play on the main menu with the demo's rule blocks (Win the duel, Defend, Posture, Unblockables, Disarmed, Ultimate, Modes), updated for this build: larger walled arena, strings not guaranteed after the first hit, heavy dodge cancel | the move list per weapon (Katana, Greatsword, Daggers, bare hands) as tabs from MoveList | scrolls with keys, D-pad and stick; Back returns to the opener (main menu now, pause later)
- check: GUT tests/ui/test_how_to_play.gd: the tabs show the MoveList rows; scrolling and switching tabs with keys only and with a controller only | screenshots of the rules page and each weapon's tab | npm test and npm run typecheck pass
- depends: move-list-data, title-and-main-menu
- stories: 58, 9
- files: game/ui/menus/how_to_play_screen.gd, game/ui/menus/main_menu_screen.gd, game/tests/ui/test_how_to_play.gd
- notes: Re-read the rule text after tasks 8-11 change the rules and strings.

### [22] pause-menu (M): Pause menu with move list, controls and settings
- delivers: the pause in the theme (休止 Paused): Resume, Move list, Controls, Settings, Restart, Quit to menu | the sub-screens open over the frozen match and Back returns to the pause; Back or the pause button resumes | Restart replays the same config with the next seed; Quit to menu calls host.stop() and returns to the main menu over the attract duel | a profile picked in the pause's Controls screen takes effect on resume (MatchHost.resume() already calls set_profile and rearm_pause)
- check: GUT tests/ui/test_pause_menu.gd: the pause opens on the pause binding and on focus loss; each entry and Back work; changing the active profile in the pause's Controls and resuming changes input.profile_of(0); the rules never step while any pause screen is open; walks with keys only and with a controller only | screenshots of the pause and each sub-screen over a match | npm test and npm run typecheck pass
- depends: controls-profiles, settings-screen, how-to-play-screen
- stories: 9, 10, 56
- files: game/ui/menus/pause_screen.gd, game/scenes/main.gd, game/tests/ui/test_pause_menu.gd, game/tests/view/test_main_flow.gd

### [24] hud-bars-and-plates (M): HUD top bar: plates, HP with lag bar, posture states, pips and ultimate badge
- delivers: the demo's top bar in the theme. Per side: a plate (seal 赤 or 青, fighter name, weapon name, Disarmed tag); the HP bar (lag band holds 0.45 s, then drains 0.6/s; pulses at 25% HP or less); the posture bar underneath with its label (hot at 70%, blinking when full); three round pips; the 奥義 ultimate badge (glows on can_ult(), dims when used at 25% HP or less) | the centre round label: a kanji (一..九) over 'Round N' | the per-frame HUD state as a pure function of the rules' state, for tests
- check: GUT tests/ui/test_hud_bars.gd: each bar state from HP, posture and wins; lag hold and drain with made-up deltas; the badge's three states; the round label's kanji | screenshots: full bars, low HP, posture hot, posture full, ultimate ready, Disarmed tag, on each side | npm test and npm run typecheck pass
- depends: ui-theme-and-fonts
- stories: 7
- files: game/ui/hud/match_hud.gd, game/ui/hud/hud_bar.gd, game/ui/hud/hud_side.gd, game/tests/ui/test_hud_bars.gd, game/tests/view/test_match_scene.gd, game/tools/shot_scenes/hud_shots.gd

### [24] hud-announcements (M): HUD announcements with kanji, timed on the rules' frames
- delivers: announcements as kanji, English and a subline: 第N戦 Round N (+ 'Final round' at 2-2), 始め Fight, 一本 K.O., 相打ち Double K.O., 勝/敗 round result 78 frames after roundOver, 武器喪失 Disarmed with its sublines. Watch and Versus wording names the fighter; Training shows none but Disarmed | the demo's entrance (scale from 1.35 and fade in over the first 12%, fade out after 78%), driven by the host's step count so it slows with slow motion and freezes in pause; the existing lengths kept (78, 54, 120, 132, 96, 90 frames)
- check: GUT tests/ui/test_hud_announcements.gd: each event's text and length; the animation's progress is a function of steps; pausing the host and advancing wall-clock time leaves the announcement and its animation unchanged; slow motion stretches it | screenshots: round call, Fight, K.O., round result, Disarmed, and a pair before and after a pause | npm test and npm run typecheck pass
- depends: hud-bars-and-plates
- stories: 6, 7
- files: game/ui/hud/match_hud.gd, game/ui/hud/hud_announcement.gd, game/tests/ui/test_hud_announcements.gd, game/tests/view/test_match_scene.gd
- notes: MatchHud already times announcements on host.step_count and queues the round result. This task adds the kanji, the sublines and the step-driven animation.

### [24] hud-toasts (M): HUD toasts
- delivers: a stack of up to three toasts below the centre, 69 rules frames each (the demo's 1.15 s), in gold, jade, red or dim | their events: parry, flash and redirect (yours, theirs, Watch); the three counters with sublines (evade: 'Press <light> now to lunge'); Ultimate ready; the opponent's Ultimate ('Get ready to evade'); Behind them (backstabReady); Backstab; Dazed (stagger); Evaded (Training only)
- check: GUT tests/ui/test_hud_toasts.gd: each event gives its text, subline and colour from the player's and from the Watch view; a fourth toast drops the oldest; toasts expire on steps and hold through a pause | screenshots of each colour | npm test and npm run typecheck pass
- depends: hud-bars-and-plates
- stories: 7
- files: game/ui/hud/hud_toasts.gd, game/ui/hud/match_hud.gd, game/tests/ui/test_hud_toasts.gd
- notes: The demo removed toasts on a 1,150 ms timer that kept running through pause and slow motion. Here they run on rules steps. The Versus forms ('Player 2: Parry') come in versus-hud.

### [24] hud-prompts (M): HUD context prompts with button names
- delivers: up to two prompts at the bottom centre, urgent ones gold-edged, each key drawn as a key cap from host.label() (PlayStation, Xbox or keyboard names) | the prompts: Recall your weapon / Breaker Palm (ultChoice); the Moonsplitter tilt directions (windup phase); Press heavy to detonate (Impaler impale phase); Counter lunge (until counter_lunge_until); Pick up your weapon (own weapon grounded within 2.2 m); Ultimate ready (light + heavy, or the ultimate key) | hidden when the Button hints setting is off; shown only while the round is fought; replaces today's single hint line
- check: GUT tests/ui/test_hud_prompts.gd: each fighter state gives its prompt; at most two, urgent first; labels follow the last device used; the setting hides them | screenshots with keyboard names and with controller names | npm test and npm run typecheck pass
- depends: hud-bars-and-plates, game-settings-store
- stories: 7, 56, 57
- files: game/ui/hud/hud_prompts.gd, game/ui/hud/key_cap.gd, game/ui/hud/match_hud.gd, game/tests/ui/test_hud_prompts.gd

### [24] hud-weapon-marker (S): HUD marker on your dropped weapon
- delivers: the 'Your weapon' label with a down arrow over your dropped weapon, projected with Camera3D.unproject_position at 0.6 m | off screen or behind the camera it clamps to the screen edge with ◀ or ▶ (flipped when behind); hidden while armed | a pure placement function for tests
- check: GUT tests/ui/test_weapon_marker.gd: placement on screen, at each edge and behind the camera; shown only for the player's own weapon and only while disarmed | screenshots with the weapon on screen and off screen | npm test and npm run typecheck pass
- depends: hud-bars-and-plates
- stories: 7, 48
- files: game/ui/hud/weapon_marker.gd, game/ui/hud/match_hud.gd, game/tests/ui/test_weapon_marker.gd
- notes: Task 18 owns the beam and in-world marker over a dropped weapon; this is only the screen-space label (the demo's .marker).

### [23] training-upkeep-rules (S): Training upkeep in the rules: refill, getting up after a KO, dummy re-arming
- delivers: TrainingUpkeep in game/sim (no nodes), a port of Game.trainingUpkeep() in src/game.ts | after a KO the fighter gets up at once: full HP, posture 0, ult_used and ult_announced reset, free state, world.ko_resolved and slowmo_frames cleared | with refill on: from 90 frames after a fighter was last hurt, HP refills by 2 per frame, the dummy's posture drains by 2 per frame, and reaching full HP gives the ultimate back | the dummy re-arms after 240 frames disarmed and free | MatchHost runs it inside the fixed step after Match.step in Training (replacing the comment in _after_step), with set_refill()
- check: GUT tests/sim/test_training_upkeep.gd, written first through the rules' public surface (sim_helpers): a KO in Training stands up; refill timing and rates; the re-arm; refill off; nothing changes outside Training | tests/view/test_match_host.gd's Training test extended | npm test, npm run typecheck and a short soak pass
- depends: 
- stories: 53
- files: game/sim/training_upkeep.gd, game/view/match/match_host.gd, game/tests/sim/test_training_upkeep.gd, game/tests/view/test_match_host.gd

### [23] training-dummy-control (S): Choosing the dummy's behaviour, with the weapon it needs
- delivers: MatchHost.set_training_behaviour(b) and training_behaviour(), which call TrainingBrain.set_behaviour | when the dummy's weapon lacks the behaviour's counter kind (TrainingBrain.ability_for), the dummy swaps to a weapon that has it, in the rules: release_if_impaling; to_free out of attack, ult, ultChoice, recall, pickup or disarmStagger; armed; abilities; remove_dropped_weapon (as Game.swapDummyWeapon did) | a loadout_changed(side) signal: MatchView re-sets that fighter's weapon and the HUD plate updates
- check: GUT: each of the nine behaviours on each dummy weapon ends with a weapon that can perform it; a swap leaves no dropped weapon or impale behind; the view and HUD follow | screenshot of the dummy after a swap | npm test and npm run typecheck pass
- depends: training-upkeep-rules
- stories: 53
- files: game/sim/training_upkeep.gd, game/view/match/match_host.gd, game/view/match/match_view.gd, game/ui/hud/match_hud.gd, game/tests/sim/test_training_upkeep.gd, game/tests/view/test_match_host.gd
- notes: The demo hard-coded which weapons a behaviour needs (thrust: katana or daggers; slam: greatsword). Derive this from ability_for() instead, so the new unblockables in tasks 10-11 don't break the table.

### [23] training-panel (M): Training: select, panel and controls
- delivers: Training on the main menu, through the select; the dummy side picks fighter and weapon only (no abilities or difficulty), with the demo's explanation | the on-screen panel bottom left: 'Dummy · <weapon>', nine behaviour chips (Stand still, Block, Light chains, Heavies, Thrust, Sweep, Slam, Mixed attacks, Spar) and Refill health on/off | keys 1-9 and 0 (unless bound in the active profile) and mouse clicks change it, with a 'Dummy behaviour' toast | controller access through a Training section in the pause menu (behaviour list and refill), so no fight button is taken
- check: GUT tests/ui/test_training_panel.gd: keys, clicks and the pause section change the host's behaviour and refill; a digit bound in the profile is ignored; Training starts from the menu with the dummy side's choices | screenshots of the panel in a match and of the pause's Training section | npm test and npm run typecheck pass
- depends: training-dummy-control, select-loadout-panel, pause-menu, hud-toasts
- stories: 53, 3
- files: game/ui/hud/training_panel.gd, game/ui/menus/pause_screen.gd, game/ui/menus/select_screen.gd, game/ui/menus/main_menu_screen.gd, game/ui/menu_data.gd, game/scenes/main.gd, game/tests/ui/test_training_panel.gd
- notes: No default keyboard binding uses the digit keys (Bindings.default_kb).

### [23] parry-timing-feedback (S): Training parry timing feedback
- delivers: in Training only, toasts ported from Hud.checkEarly and checkLate | on your parry: 'N frames before impact · window W', from the parry event's timing and window | 'Too early': a hit or block lands within 20 frames after your parry window closed ('Parry pressed N frames too early') | 'Too late': block pressed within 14 frames after a hit or block ('Parry pressed N frames after impact') | 'Evaded'
- check: GUT tests/ui/test_parry_feedback.gd with scripted inputs against the dummy's light chains: a parry pressed in the window, 5 frames early and 3 frames late each give the right toast and number; nothing shows outside Training | screenshots of each toast | npm test and npm run typecheck pass
- depends: hud-toasts, training-upkeep-rules
- stories: 53
- files: game/ui/hud/training_feedback.gd, game/ui/hud/match_hud.gd, game/tests/ui/test_parry_feedback.gd
- notes: It reads Fighter.block_press_frame and parry_window_at_press and changes nothing. The rules declare parryEarly but never emit it, so the HUD computes the early case, as the demo did.

### [23] watch-mode (S): Watch through the select, with the side-on camera
- delivers: Watch from the select: two computer sides, each with a difficulty | the CameraRig WATCH side-on camera, which already exists | the HUD in its Watch form: no prompts; toasts and round results name the fighters | pause with Esc or Start, and results naming the winner
- check: GUT: Watch starts with two computer sides and the WATCH camera, samples no human input, and its results title names the winner | screenshots from the Watch camera at round start, mid-exchange and at a KO | npm test and npm run typecheck pass
- depends: select-flow, hud-toasts
- stories: 54
- files: game/scenes/main.gd, game/ui/menus/select_screen.gd, game/tests/view/test_main_flow.gd, game/tools/shot_scenes/skeleton_watch.tscn

### [23] split-screen-view (L): Versus split screen: two cameras on one world
- delivers: in Versus, MatchView draws two side-by-side SubViewports (player 1 left, player 2 right) sharing one World3D, each with its own CameraRig in FOLLOW mode following its side toward the other, with half-screen aspect | shake and field-of-view kicks reach both cameras; the KO orbit stays off; the graphics preset and the ink-wash pass apply to both viewports | Duel, Training and Watch keep the single view | Versus is started from a config for now (no menu entry yet), so it can be tested and screenshotted
- check: GUT tests/view/test_split_view.gd: Versus builds two cameras following sides 0 and 1; other modes build one; rematches leave no stray viewports | screenshots of a Versus exchange | a frame-time measurement at 1080p on each preset (the single view held about 62 fps on High on the target laptop) | npm test and npm run typecheck pass
- depends: 16
- stories: 55
- files: game/view/match/match_view.gd, game/view/match/split_view.gd, game/view/match/camera_rig.gd, game/view/match/match_host.tscn, game/tests/view/test_split_view.gd, game/tools/shot_scenes/versus_split.tscn
- notes: MatchView hard-wires one camera child named 'CameraRig' following host.view_side(). The view tests address that camera, so keep it as player 1's. The demo skipped bloom in split screen; check the ink-wash pass cost per viewport.

### [23] versus-hud (M): Versus HUD: per-player prompts, markers and neutral calls
- delivers: the shared top bar over both halves, with 'Player 1' and 'Player 2' plates | prompts at 25% and 75% of the width, each using that player's device names (host.label(action, side)) | a dropped-weapon marker per half from that half's camera ('Player 2's weapon') | the demo's Versus toasts and announcements ('Player 2: Parry', 'Player 1 wins the round', 'Player 1 lost their weapon')
- check: GUT tests/ui/test_versus_hud.gd: each player's prompts use their own device's labels (kbm, kb_arrows, pad); markers project through the right camera; Versus toasts name the player | screenshots of both players with prompts and one disarmed | npm test and npm run typecheck pass
- depends: split-screen-view, hud-toasts, hud-prompts, hud-weapon-marker, hud-announcements
- stories: 55, 56
- files: game/ui/hud/match_hud.gd, game/ui/hud/hud_prompts.gd, game/ui/hud/weapon_marker.gd, game/ui/hud/hud_toasts.gd, game/tests/ui/test_versus_hud.gd
- notes: Today MatchHud._me() returns -1 in Versus, so neither player gets hints.

### [22] versus-select-pickers (M): Versus on the menu: device and profile pickers
- delivers: Versus on the main menu, through the select with Player 1 and Player 2 steps | each step adds 'Plays with' (Keyboard and mouse; Keyboard: arrows + J K L; Controller 1; Controller 2; each controller marked 'not connected' when absent) and a Controls profile picker (ControlProfiles.names()) | the same device on both sides shows a warning and refuses Lock in (MatchConfig.problem() already rejects it); defaults are kbm and pad0, or kb_arrows when no controller is connected
- check: GUT tests/ui/test_versus_select.gd with FakeDeviceState: the pickers write MatchSide.device and profile; a clash blocks lock in; a started Versus samples each player from their own device with their own profile | screenshots of both steps | a playtest with two controllers and with a shared keyboard (arrow layout) confirms Versus runs smoothly | npm test and npm run typecheck pass
- depends: select-loadout-panel, controls-profiles, versus-hud
- stories: 55, 56, 3
- files: game/ui/menus/select_screen.gd, game/ui/menus/device_picker.gd, game/ui/menus/main_menu_screen.gd, game/core/match_selection.gd, game/tests/ui/test_versus_select.gd

### [22] menus-navigation-audit (M): Whole-flow walk with keys only and with a controller only, plus the screen set
- delivers: two GUT walks through main.tscn, one with key events only and one with controller events only, covering: the title; the main menu; every mode's select through to a started match; the pause and each of its sub-screens; Controls (capture included); Settings; How to play; the results with Rematch, Change fighters and Main menu. Any focus gap found is fixed | the stand-in MenuScreen and the skeleton menu shot scenes retired; a screenshot scene for every screen (npm run shots)
- check: both walks pass | screenshots of every screen, reviewed by eye | npm test and npm run typecheck pass
- depends: versus-select-pickers, training-panel, results-screen, pause-menu, select-3d-preview
- stories: 3, 9
- files: game/tests/ui/test_navigation_walk.gd, game/tools/shot_scenes/menu_shots.gd, game/tools/shot_scenes/skeleton_main_menu.tscn, game/tools/shot_scenes/skeleton_results.tscn, game/ui/menus/menu_screen.gd

## Open questions
- The select layout is contradicted in three places. The spec's Out of Scope says the design doc's select (model on the right, loadout on the left, lock in, gate) is out and the rebuild ships 'a simpler fighter and loadout select'. Plan task 22 (and pending-plan-changes item 3) says to build that layout now, without the gate and intros. The plan's 'Not yet specified' still lists the full character select. Recommended: follow plan task 22, the later decision, and correct the spec's Out of Scope and the plan's 'Not yet specified' in the select-flow commit.
- How do two sides pick with one grid and one preview? Recommended: one side after the other (side 1, then side 2), each with its own lock in. Back from side 2 returns to side 1. Titles per mode follow the demo: You / Opponent, You / Training dummy, Red fighter / Blue fighter, Player 1 / Player 2.
- Palette choice. Recommended: no palette picker. Follow FighterLook's rule: the second side of a mirror match wears palette 1, otherwise both wear palette 0.
- What can be Random? Recommended: only the Duel opponent's weapon (story 5) and the arena slot (plan task 22); no random fighter.
- How does a controller player change the dummy's behaviour mid-match, when every pad button is bound to a fight action? Recommended: the on-screen panel uses keys 1-9 and 0 plus mouse clicks, and the Training pause menu gets a pad-navigable section with the behaviour list and refill.
- Renaming a profile on a controller only: Godot on Windows has no on-screen keyboard. Recommended: rename stays keyboard-only; controller users can still pick, add and delete profiles, which get 'Player N' names.
- Names in mirror matches: MatchSide.display_name() gives 'Rogue' for both sides. Recommended: Versus plates, toasts and results say 'Player 1' and 'Player 2' (as the demo did), with the fighter in the plate; elsewhere the seal colours (赤/青) tell the sides apart.
- Fonts: full Japanese fonts or a subset of the kanji used? Recommended: bundle the full TTFs (a few MB each, under the 10 MB per-file cap) so new kanji never go missing. The download from the google/fonts repository needs the owner's approval.
- Volumes: the demo defaulted to master 0.8, effects 0.9, music 0.45, while the Godot bus layout already sets levels (Music at -6 dB). Recommended: sliders default to 100 and scale on top of the layout's levels, so the layout stays the one place for the mix. Effects drives the SFX and Ambience buses; UI sounds follow Master.
- Graphics options: the demo had High and Fast; task 16 built Low, Medium and High. Recommended: offer Low, Medium and High. Reduce flashes defaults to Off (Godot has no reduced-motion query like the browser's).
- Where the Training upkeep lives: the spec says the presentation never changes the rules, but the demo's upkeep did, from game.ts. Recommended: a rules-layer TrainingUpkeep (game/sim) that MatchHost calls inside the fixed step, so it stays deterministic and testable headless.
- Move list contents: the demo showed only the light string. Recommended: also show heavy strings, release variants (once task 9 adds them) and a reach column (AttackDef.range now; path-derived reach after task 7), since the spec's new strings live in heavy follow-ups.

## Risks
- The spec/plan contradiction on the select layout may cause rework if the owner meant the simpler select. Settle it before select-flow.
- The typecheck loads every script, so tasks that use FighterModel/FighterLook (task 13, unmerged branch) or GraphicsPreset/GraphicsApplier (task 16, uncommitted and unreviewed in a worktree based on 67265af) can't land before those merges. select-3d-preview, graphics-preset-setting and split-screen-view are gated on them.
- Split screen draws the 3D scene twice. High held only about 62 fps at 1080p with one view on the target laptop, so Versus may need Medium or a lower render scale. The ink-wash pass and any camera-attached effects must exist in both viewports.
- RebindCapture is meant to take events in _input(), but the InputFeed in the GameServices autoload also relies on _input(). A handled event never reaches it, so held-key and Shift-side tracking could go stale during capture.
- Headless GUI tests: MenuScreen focuses with grab_focus.call_deferred, so tests must await frames. Stick repeat needs a fake clock. The menus must keep acting in _unhandled_input so the InputFeed sees every event.
- Tasks 9-11 rename moves, add heavy strings and add unblockables (Low Sweep, Skewer). The move list and the dummy's behaviour-to-weapon table must be derived from the data (chain walks, TrainingBrain.ability_for), or they break silently.
- Training upkeep changes rules state outside Match.step. It is deterministic only if it runs inside the fixed step; it must never run in the soak or attract paths.
- The title's 'live duel behind it' depends on the menu camera framing the fighters on the real shrine. The look-and-arena menu-orbit screenshot shows the whole island from far off.
- Overlaps with other areas: task 18 also owns reduce-flashes for effects and the in-world dropped-weapon beam (the HUD does only the screen label). Tasks 19 and 20 must call MusicDirector.enter_menu/enter_match and play the UI cues from the screen flow, so agree on the seams (the ui_cue signal, ScreenStack changes) to avoid both lanes editing main.gd.
- The CJK fonts are large, and dynamic-font rendering of 84 px kanji may need MSDF or oversampling. Check the import and the repo-size budget (spec: about 100 MB total).
- main.gd and match_hud.gd are touched by many tasks. Working one task at a time avoids merge conflicts, but parallel runs would collide.
