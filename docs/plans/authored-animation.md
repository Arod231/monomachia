# Plan: Authored animation and the dodge roll

Spec: `docs/specs/authored-animation.md` · branch `feature/authored-animation` · draft pull request #12 (into `feature/godot-rebuild`)

## Destination

Every fighter animates from authored clips. The attacks come from Kevin Iglesias's packs, with UAL2 Source filling the gaps, retargeted onto the Rogue and the Hunter. Hits are decided by paths baked from those same clips, and every move's frame data is retuned to its clip. The dodge is a roll, big hits knock the defender down, the Greatsword rides on the shoulder, and each weapon has a draw and a victory pose. The procedural swings, the guard shuffle, the hip-turn, the lean and the stick poses are gone. A fresh clone without the packs plays the committed CC0 fallback clips and says so. The rules still decide everything at 60 steps a second and never read a clip.

## Notes

- **One task at a time.** Since task 1's gate the owner's OK is needed only at the hard gates below (see Decisions, Pacing). Before each task, merge `origin/feature/godot-rebuild` in and run the full tests. After each task:
  - tick it here;
  - update Progress;
  - in the spec, update the status line, any numbers the task changed, and tick each user story the build now fully delivers.
- **Hard gates** (nothing after the gate starts until the owner says OK):
  - task 1, the retargeting prototype;
  - task 5, the catalogue sheet, which gates the first clip assignment (task 9);
  - each weapon's review (tasks 14, 20, 23, 25), and the reactions and movement review (31), in the spec's order: Katana, Greatsword, Daggers, bare hands, then reactions and movement, then the round flow.

  The rules tasks (15–17) sit right after the Katana's review so that work goes on while the owner looks at it.
- **Every task ends with** `npm test` and `npm run typecheck` passing, a commit and a push. Visual tasks also end with sheets reviewed by eye. Tasks that change rules data also end with a clean 40-match soak, and each weapon's review adds a 300-match `soak:tune`.
- **Licence.**
  - Never commit an Iglesias file or a clip converted from one. They live in the packs' folder (`.assets-src-path`) and in the gitignored clip libraries.
  - Committed: the bone map, the clip manifest, the baked swing files, the roll curve and the frame data.
  - Before each commit, check `git status` for anything under the gitignored library folder or with an Iglesias clip name.
- **CI has no packs.** Every test that needs them skips itself with a message when the libraries are missing, and every other test passes on the committed CC0 fallback.
- **The rules stay free of graphics** (`game/sim`): no clip, AnimationTree or node. The bake and the import tool are tools, outside `game/sim`, and they write data the rules read.
- **A move's retune goes in the same commit as its baked swing:** the frame data, `test_moves`' deliberate-differences tables, the reach tests, the sheets and the soak.
- Use the glossary's terms (Clip, Swing, Dodge, Knockdown, Shouldered…) in code names.

## Decisions so far

- [Spec](../specs/authored-animation.md), approved by the owner on Oct 3, 2026.
- PR #11 already committed the whole UAL2 Source and root-motion GLBs (`UAL2_Source.glb`, `UAL2_Source_RM.glb`, `UAL2_Standard_RM.glb`), the female mannequin and the CREDITS note on the Iglesias packs, and raised the art budget to 110 MB. The spec's first step, bringing over only the clips used, is therefore done differently: the files are in, and task 3 folds the clips the clip table names into the committed library. Its `assets/ual2-source-and-iglesias-refs` worktree (`add-3d-references-530c11`) was removed with the owner's OK after task 17.
- The godot-rebuild plan's tasks this feature retires are marked there:
  - 14b (the swing editor) and 7.16–7.38 (the hand-keyed swings);
  - 14.14 (blade lag) and 14.15 (the parry-bounce prototype);
  - all of task 15 (full fighter animation), 15.9's ghost trails included. The owner chose on Oct 3 to retire 15.1–15.16 as well as 15.9, since this plan covers them.

  - 14.16 (the saya) goes into task 11, and 14.17 (the review sheets) into task 14 (the owner's choice, Oct 3, at task 1).

  The godot-rebuild tasks that waited on a retired one now wait on this plan:
  - 12.2 on task 25;
  - 18.12 on task 36;
  - 25.7 no longer waits on the swing editor.
- While a weapon is between tasks, a move with a baked swing plays its clip, and a move without one keeps the stand-in poses and its cone. The stand-ins go in task 35.
- The Greatsword's recovery slide keeps running along the facing; the retired 7.24 would have taken its direction from the follow-through.
- The counters (stomp, leap, evade) keep their demo cones; the retired 7.37 would have measured them from the paths.
- Story 42, the email to Kevin Iglesias, is drafted in the spec's Licence section; the owner sends it. Until he answers, the baked paths are committed.
- **Task 1 passed** (Oct 3). The owner chose foot locking under every clip, not just locomotion: task 8 builds it, and task 29 reuses it.
- **Pacing** (owner, Oct 3): tasks run back to back with no OK between them, each still ending with its checks, a commit and a push; work stops only at the hard gates (5, 14, 20, 23, 25, 31, 36).
- The merge of `origin/feature/godot-rebuild` (PR #11) into this branch was done at the start of task 1, on the owner's go-ahead (Oct 3).
- **The catalogue passed** (Oct 3, task 5's gate): the first candidates stand, so task 9 starts. The `add-3d-references-530c11` worktree was removed on the owner's OK (its branch was already merged).
- The Rogue's 5 cm drift is measured on her own body, HumanF against HumanM (task 7; the owner kept it on Oct 3): measured against the Hunter's path, every move tried was 7–12 cm off from her smaller body alone, which her hand IK closes anyway, so every move would have played HumanM.
- **The Katana's gate** (task 14): the owner closed the gate questions without answering, then set a goal of finishing the next four tasks (Oct 3). That was taken as the go-ahead for the Greatsword (task 18 on). The review's open questions stand: the longer lunges (the Greatsword's follow the same rule meanwhile) and the PoseCheck exemption for clip frames.
- **The Greatsword passed** (Oct 3, task 20's gate): task 21 starts. Its win rate (39.1% against its 46.1% baseline, the shoulder lift's and knockdown's cost) is taken as its own small tuning change after the Daggers, measured on 300-match runs (the owner's choice).

## Progress

Oct 3, 2026. Plan approved by the owner. Merged `origin/feature/godot-rebuild` (PR #11) in with the owner's go-ahead; tests and typecheck pass.

Oct 3, 2026. Task 1 built: `tools/build_iglesias_bone_map.gd` writes `assets/kevin_iglesias/iglesias_bone_map.tres` (52 of the 56 profile bones), the six clips retargeted onto both fighters, and the findings in `docs/research/retarget-prototype.md`. Bends and crossing pass; the off hand sits 7–16 cm from the Greatsword's off-hand grip (for task 4's IK); planted feet creep up to 6 cm in the 2H attack and the roll's getting-up (foot locking, beyond task 29's locomotion, would cure it). One fix made: the hips' travel scaled to the legs (×1.14), which task 2's import tool must repeat. Roll01 [RM]'s root reads cleanly; Dodge01 is a sway, usable as the backstep only as its back half. The owner passed the gate the same day, choosing to extend foot locking to every clip (task 8 builds it, for the attacks and the roll's getting-up as well as locomotion), and to run the tasks back to back between the hard gates, stopping only at them. Tasks 3, 15 and 16 run in parallel lanes (background agents in their own worktrees), merged into this branch as they finish, the soak baseline (task 3) before any rules change.

Oct 3, 2026. Task 2 done. `.assets-src-path` (or `assets_src/`) names the packs' folder, read by `tools/asset_source.gd` and passed by `scripts/godot.mjs` to every Godot run; `import_assets.gd` reads it too. The clip manifest (`assets/kevin_iglesias/clip_manifest.json`, task 1's six clips with provisional markers; `ClipManifest` reads it). `node scripts/godot.mjs clips` stages the clips into the gitignored `assets/kevin_iglesias/staging/`, imports them through the bone map and writes `ClipLibraries` (`assets/kevin_iglesias/library/iglesias_humanm.res` and `_humanf.res`, gitignored, about 200 KB each), with the hips' travel scaled to each fighter's legs and mirroring supported; two runs write identical files, and `git status` stays clean. The Windows export (`npm run godot -- build`) carries the libraries and leaves the staging and scratch folders out; `Monomachia.exe --smoke` plays every clip ("6 HumanM, 6 HumanF, each played"). The art-budget test now skips the two gitignored folders. Waiting on the owner: removing the clean `add-3d-references-530c11` worktree (asked at the next gate).

Oct 3, 2026. Task 3 done in a parallel lane and merged: the CC0 library gains the clip table's 25 UAL2 Source clips (39 to 64 clips, 1.0 MB; `Sword_Aerial_Combo_Loop` is `Sword_Aerial_Combo` and `Walk_*_Loop` the eight `Walk_*` directions, the importer having stripped `_Loop`); the art is 104.8 MiB of 110. **The soak baseline**, rules unchanged (each weapon's review is measured against it, ±5 points):
- 300-match `soak:tune`: rounds 39.6 s on average (longest 116.3 s); win rates without mirrors Katana 53.1%, Greatsword 46.1%, Daggers 50.4%; disarms 1.06 per round (the spec's 0.3–0.6 target is already out); hits 25.1 and blocks 24.8 per round; parries 4.58 per round.
- 40-match soak: rounds 41.1 s; Katana 40.0%, Greatsword 62.5%, Daggers 47.1% (15–17 matches each, too few to judge); disarms 1.06 per round.

Oct 3, 2026. Task 4 done. `FighterModel.fix_weapons(reverse)`: while a clip drives the arms each weapon rides its hand at its grip (the measured fist turned by the new `WeaponLook.grip_offset`, identity for all three weapons), the Daggers one in each hand and turned 180° about the knuckles in the reverse grip, and a two-handed weapon's off hand reaches its `OffHandGrip` on IK over the clip. Where the clip puts that grip past 90% of the off arm's reach (a one-handed clip, the death fall, Dodge01: up to 33 cm out), the weapon is drawn in toward the off shoulder by the shortfall and the main arm follows on IK. The off hand stays within 1 cm of the grip through task 1's clips on both fighters with the Katana and the Greatsword. Sheets: the new `tools/shot_scenes/clip_sheet.tscn` (every manifest clip on both fighters at its four markers, one sheet per weapon; task 5's catalogue builds on it).

Oct 3, 2026. Tasks 16 (knockdown) and 15 (the shoulder carry) done in parallel lanes and merged (conflicts only in two header notes); the decisions each made are in the spec. With both, a 40-match soak is clean (rounds 41.3 s, 1.88 knockdowns and 0.96 disarms per round). Their 300-match runs, each against the baseline: knockdown alone Greatsword 41.7% (−4.4), Katana 53.8%, Daggers 53.5%; the carry alone Greatsword 36.5% (−9.6; the 6-frame lift costs about 6 points and the computer opponent's shorter attack reach about 3.5), Katana 51.5%, Daggers 60.5%. The Greatsword's review (task 20) has to win this back.

Oct 3, 2026. Task 5 done. The manifest names 71 clips: every Iglesias first candidate in the clip table (two of them mirrored: Attack2H02 and AttackDW01), each tagged with its catalogue pages (`groups`), with provisional markers estimated from the striking hand or foot's fastest frames. `clip_sheet.tscn` renders a page per weapon, one for bare hands and one for the states: each clip a row, the Hunter then the Rogue at its four markers, the page's weapon in hand; a test counts the pages against the manifest. Found: Kevin's `_L` clips (Attack1H01_L and the rest) swing with the left hand, a whole-body mirror of the `_R` ones, so the table's "the other side" cuts can't use them for a right-handed backswing as they stand. **Waiting on the owner: the catalogue review, which gates task 9.** (Tasks 6–8 and 17, which don't need it, are done since.)

Oct 3, 2026. Task 6 done. `ClipTiming` (game side, for the clip director too) retimes a clip by its markers at a speed of 1.0–2.0: the wind-up start on frame 0, the contact start on the last startup frame, the contact end on the last active frame, the settle on the last, each stretch at least a frame; bad markers and speeds are refused. `SwingBake` (tools) is the pure bake: a sampled clip (`ClipPoser` poses the Hunter with the weapon fixed, the whole modifier stack run, so the weapon read is the weapon shown; chains supported), markers and a speed in; the retimed clip times, each part's grip, blade and edge (feet: ankle, toes, sole) and the body's coils and pelvis shift on every rules frame, and the frame data out; `pick_speed()` takes the slowest speed landing closest to today's startup. Swing files gain baked tracks (`{"baked": true, "keys": [...]}`, a key on every frame, no ease; a missing frame is refused) played key by key and blended in a straight line between frames. `node scripts/godot.mjs bake` bakes the moves the new move-clip table (`assets/kevin_iglesias/move_clips.json`, `MoveClips`: each weapon's guard clip, each fitted move's clips and optional speed) names into `sim/moves/swings/<weapon>.json`, with a report of speed and frames against today's that marks the moves to retune; the table fits no move yet (task 9 starts). Tests on the CC0 Sword_Attack: markers on their frames, samples within 1 mm of the posed hand, deterministic text, refusals, a round trip through `SwingFile`; local-only: Attack1H01_R bakes for the Katana's Right Cut, and every committed swing file matches a fresh bake. Found: `Skeleton3D.advance()` only queues the update, so the poser sends the update notification to pose at once.

Oct 3, 2026. Task 7 done. **The reach correction:** `SwingBake.correct_reach()` plays each striking move from the reach table's distance (a light of the string from its weapon's duelling distance, aiming at 17.5 cm of blade inside; any other move for a touch, aiming at 5 cm) on the baked path and the retimed frames (the lunge carried over), and where it falls short finds the least forward push of the striking grips, at most 15 cm, easing in over the wind-up and out over the recovery (`Swing.reach_weight()`). The push goes into the keys and, as `"reach"`, into the swing file; `FighterRig.reach_offset` plays it on a weapon fixed to the clip's hand, the arm reaching it on IK (the blade shown within 1 cm of the baked path on every active frame, the hand on the handle). Moves needing more are reported, lights over 20 cm too. **The Rogue:** the bake poses her with HumanF and with HumanM; a move whose HumanF clip is more than 5 cm off HumanM on her body is flagged (`"rogue_humanm"`), and `ClipLibraries.set_for()` gives her HumanM for it (see Decisions). A trial bake of provisional fits (not committed) shows the real clips: Attack1H01_R for Right Cut at ×1.40 puts 15.1 cm into the defender from 2.5 m with no push and keeps HumanF for the Rogue (4.9 cm); Attack2H01 for Heavy Swing at ×1.95 puts 18.2 cm in from 3.0 m, the Rogue on HumanM (12.5 cm); Attack1H02_R for Return Cut falls short even with 15 cm (5.7 cm in), so task 10 needs another clip or a longer lunge; and the provisional settle markers make every recovery 6–11 frames longer than today's, for task 9's fitting to settle. (The CC0 sword clips reach far less: their Katana tip gets 1.26 m ahead at most, so they can't meet the rule from 2.5 m.)

Oct 3, 2026. Task 8 done. `ClipDirector` (view side, no nodes, like `HudState`) steps a `Shot` per rules frame from the fighter's state and a context (its clip set, whether the libraries are there, the clips' lengths); a frame the world didn't step (hit-stop, pause) returns the same shot. It picks the free idle by weapon class (CombatIdle1H01, CombatIdle2H01, CombatIdle01; Sword_Idle and Idle without the packs), and for an attack whose move has a baked swing, the swing's clip timed from the attack frame on the frames the bake used (a charge holds it with the rules' frame), with the crossfades 3 into an attack, 4 for a follow-up (from the last clip held at its pose), 2 for a dodge-cancel, a cut for hitstun and 6 back to the legs (8 for stances, from task 18). Baked swings now carry what they were baked from (`clips`, `speed`, `marks`, and the clip table's CC0 `fallback`, which the move-clip table gains), so the view plays exactly the bake's timing; without the packs the fallback plays stretched over the move. Locomotion's AnimationTree gains the director's two clip slots blended over the legs, and holds the Iglesias libraries. `FighterView`: the Hunter on his own HumanM holds the weapon fixed in the clip's hand with the reach correction on the arm; the Rogue, and anyone on the fallback, has the weapon posed on the baked path (SwingPlayer); the swing's own body keys, the lean and the guard stance stand aside under a clip. The Katana's guard stance keeps its relaxed clip under the legs until task 29 retires the stance. **Foot locking:** `FootLock` holds a planted ankle where it landed (world space, stepped on rules frames), letting it go when the clip lifts it 6 cm, carries it 15 cm or the leg can't reach, easing back over 4 frames; it is on while an authored clip shows and while standing out of a guard stance (locomotion's feet stay as they are until task 29). Through task 1's clips on both fighters the held feet move under 1 cm, held 44–100% of each clip. Without the libraries the match shows a small "animation packs missing" note bottom-left and logs what to fix (`ClipLibraries.warn_if_missing()`; `--no-packs` plays any skeleton shot that way). Sheets: `shots/task8/` (the note, the idle per weapon class on both fighters, an exchange).

Oct 3, 2026. Task 17 done. The import tool stages Roll01 [RM] beside the clips for its root alone (`ROOT_SOURCES`, never put in a library) and prints its ground travel per set, normalised to 0–1 over the stretch it travels and resampled to the dodge's 16 frames (`curve_of()`). HumanM's 17 numbers are `SimConst.MOVE_ROLL_CURVE` (0, 0.0876, 0.1958 … 0.9899, 1), read through `SimMath.roll_travel()`; a roll (the `dodge` state) travels along it, the backstep keeps `ease_out_cubic`. The distance, frames, i-frames, recovery and the forward dodge's counter window are unchanged (tests on each); a local-only test reads the curve from the pack again. The design doc's roll now says it keeps an even pace and eases to a stop. (The 40-match soak first recorded here was the web demo's `npm run soak` by mistake; the Godot soak, `node scripts/godot.mjs soak 40`, run at task 9 with the roll and Right Cut, is clean.) **Waiting on the owner: the catalogue review (task 5's gate), which every remaining task waits on through task 9.**

Oct 3, 2026. Task 9 done: Right Cut plays and hits from Attack1H01_R. The clip winds up on the right, steps in (the front foot 42 cm, the hips 45 cm) and sweeps into full extension, holds it, then returns; its markers are wind-up 0, contact 8, contact end 10, settle 22, which at ×1.45 land exactly on today's 11 / 3 / 16 frames (the first fit, contact 7–9 at ×1.25, hit one frame later at 2.2 m and took away the defender's free step before Return Cut, which the spec's string property forbids). `move_clips.json` fits k_l1 (fallback Sword_Light_A); `sim/moves/swings/katana.json` is its baked swing (committed). From 2.5 m it puts 9.3 cm into the defender and the bake pushes it 8.2 cm to 17.5 cm; its first touch is frame 13, where its lunge now ends (`test_moves`' table). The Rogue's HumanF clip is 5.1 cm off HumanM on her body, so she plays HumanM for it. Changes the move brought out: the reach push is played by moving the body above the hips, not by the arm's IK (Right Cut's arm is straight at full extension); the two-handed draw-in now measures the off wrist (to 97% of the arm), so the off elbow never locks; a baked swing's guard isn't used for the free state, which keeps the stand-in guard; the swing check skips baked swings (spec updated); a weapon's reach falls back to its authored reach without a light starter's swing; a new world starts the view's director and foot lock afresh; tests that used Right Cut as "a move without a swing" use a swingless Katana (`SF.without_swings()`). Godot 40-match soak clean: 0 failures, rounds 44.4 s, longest 102.0 s; Katana 46.7%, Greatsword 56.3%, Daggers 47.1%; disarms 1.08 and knockdowns 1.97 per round. Sheets: `shots/task9/` (the debug view with the flash at 2.5 m on both fighters, Right Cut's contact sheets).

Oct 3, 2026. Task 10 done: Return Cut, Kesa Cut and Crown Cut play and hit from clips, on today's frames. A probe of every Katana candidate's blade path (fighter space, per source frame) showed the clip table's names don't match their swings: Attack1H03_R winds up overhead and cuts left to right at the waist (Return Cut, contact 9–12, ×1.80), Attack1H02_R is a short diagonal down that reaches only 1.73 m (no clip for a light), Attack2H01 is the big diagonal down from the right shoulder (Kesa Cut, started from its wound-up pose at frame 8, ×1.30), Attack2H02 is the packs' only straight overhead (Crown Cut, wind-up 10, contact 21–24, ×1.55); Attack1H04_R and Attack1H05_R are a descending left-to-right and a rising right-to-left cut, for task 11. The move-clip table gains a move's own `marks` (one clip serving moves of different timings: Kesa Cut's light from Attack2H01, whose whole clip is still Heaven Splitter's candidate). All three fell short of the reach rule even with the 15 cm push, so their lunges grow (the spec's way for that): Return Cut 0.35 → 0.45 m, Kesa Cut 0.35 → 0.4 m ending on frame 14, Crown Cut 0.5 → 0.7 m ending on 15 (each lunge ends on its first touch); pushes 11.4, 10.1 and 9.7 cm, each 17.5 cm inside from 2.5 m (`test_moves`' table, `test_katana_strings`). The Rogue plays HumanM for Return Cut (10.8 cm) and Crown Cut (7.1 cm), HumanF for Kesa Cut (4.4 cm). The first-key continuity test skips swings baked from clips; the sides test stays. The synthetic duel-reach tests now check only their own Right Cut (they ran every Katana light on a straight test blade). A defender hit by Right Cut still parries Return Cut. Found: the horizontal Iai's knockback (1.0) leaves the defender 2.35 m off through Return Cut's active frames, out of its clip's reach, so H-L sideways hits once from 2.2 m (it hit with the old 2.2 m cone); the strings-stop test plays those strings from 1.8 m, and task 11 looks at the Iai's knockback with its own swing. Crown Cut follows through into a deep bow, the tip near the floor (the clip's own), for the Katana's review. Godot 40-match soak clean: 0 failures, rounds 43.9 s, longest 123.0 s; Katana 53.3%, Greatsword 50.0%, Daggers 47.1%; disarms 1.05 and knockdowns 2.01 per round. Sheets: `shots/task10/` (string_l to string_llll on both fighters).

Oct 3, 2026. Task 11 done: the Katana's heavies play and hit from clips, on today's frames, and the Katana wears a saya. **Chains:** a chain entry may be part of a clip (`ClipChain`: "id@from" or "id@from-to"), each part fading in from the one before held at its end over 3 source frames; the bake's poser blends the bones as the director's crossfade does (`Clip.under`). **The hold:** a chargeable move's marks may carry a hold (`ClipTiming`): its pose lands on the charge frame (9) at whatever even speed gets it there, the speed timing the rest from it, so a held Iai holds its sheathed pose. **Sheathed frames:** the move-clip table's "sheathed" (source frames) becomes the swing's attack frames in the saya (`Swing.sheathed`, before the active frames; `SwingFile` refuses others); there the rig puts the katana in the saya and no hand reaches for it. **The saya** (`Saya`, godot-rebuild 14.16): a black lacquered scabbard meshed in code around the katana's own blade, on the hips at the frame the sheathe clip leaves the sheathed katana in on each body, whenever the Katana is the weapon. **The stance:** while charging, the held clip shows on the upper body only (Locomotion's upper blend over the legs, with its own copy of the clip slots as a blend-tree node feeds only one other) and the stance's legs stand and walk on the shuffle as before (handed over 4 frames each way; foot locking lets go meanwhile). The fits: the vertical Iai is SheatheHips01_R frames 3–12 (sheathed on frames 8–9, held on 9) into Attack1H04_R from frame 2 (a descending left-to-right cut) ×1.30; the horizontal the same sheathe into Attack1H05_R (a rising right-to-left cut) ×1.15; Rising Heaven Attack1H05_R ×1.00; Returning Draw Attack1H04_R ×1.35; Heaven Splitter Attack2H04 (the straight overhead slam) ×1.25 (the clip table's Attack2H02 and Attack2H01 are an overhead and a diagonal, used by Crown Cut and Kesa Cut). Every heavy fell far short of its test distance (the Iai 3.6 m, the others 3.0), so the lunges grow (the bake report now says how much more each needs): the Iai Slashes 0.4 → 2.1 m (hitting at 3.8 m where Right Cut whiffs, as godot-rebuild task 9's test wants, and missing at 4.2), Rising Heaven 0.5 → 1.2, Returning Draw 0.5 → 1.1, Heaven Splitter 0.7 → 0.95. With the Iai's longer lunge, H-L sideways hits from 2.2 m again, so task 10's 1.8 m start in the strings-stop test is gone. The Rogue plays HumanM for the horizontal Iai (13.7 cm), Rising Heaven (16.0) and Heaven Splitter (7.6). The guard shuffle no longer holds the steps through the Iai's stance just because the Iai has a swing. For the review: from the sheets' 2.5 m the Iai's 2.1 m lunge carries the attacker right up to the defender before the cut. Chains may also name a committed CC0 clip with its library ("ual/Sword_Aerial_A"; MoveClips asks such a chain for its own marks), for task 12. Godot 40-match soak clean: 0 failures, rounds 42.9 s, longest 126.2 s; disarms 1.09 and knockdowns 1.88 per round; but the Katana won 4 of 15 (26.7%, from 53.3% after task 10), the Greatsword 68.8% and the Daggers 52.9%: too few to judge: a 300-match run with every Katana move so far puts it at 50.8% (66 of 130; baseline 53.1), the Greatsword 43.5% (baseline 46.1) and the Daggers 55.0%, rounds 40.5 s, disarms 1.00 per round, hits 24.0 and blocks 22.9 per round. Sheets: `shots/task11/` (each heavy on the Hunter, the vertical Iai on the Rogue, the stance walked).

Oct 3, 2026. Task 12 done: the Katana's eight movement attacks play and hit from clips, all on today's frames. A probe of the UAL2 Source clips the table names (Sword_Dash, Sword_UpperCut, Sword_Aerial_A and B) found them side-on (the hips turned 80–120°) and short (the tip about 1 m ahead), and the aerials too short to fill a move (Aerial_A is 12 source frames), so Kevin's clips stand in where one fits: Running Draw Attack1H01_R ×1.30; Leaping Cleave Attack2H04, which hops into its slam, ×1.40; Wind Cut Attack1H02_R from frame 4 ×1.75; Whirl Cut Attack2H03, wound round from behind into its sweep, ×1.00; Rising Cut Attack1H05_R ×1.60; Lunging Cut Attack2H01 ×1.65; Aerial Cut Attack1H01_R from frame 4 ×1.15; Falling Crown Attack2H04 from frame 6, the blade already overhead, ×1.30. (Attack1H01_R now plays four moves, Attack2H04 three and Attack2H01 two: the review's list of shared clips.) Six needed longer lunges to touch from their test distances: Running Draw 1.6 → 1.7 m, Leaping Cleave 2.6 → 2.9, Wind Cut 0.4 → 0.5, Whirl Cut 0.3 → 0.5, Rising Cut 0.8 → 1.25, Lunging Cut 2.2 → 2.3 (`test_moves`, `test_katana_strings`); both jump attacks reach from 2.0 m as they are. The dodge attacks still come up facing the opponent (the rules' tests). The jump attacks play Kevin's standing legs in the air, for the review. Godot 40-match soak clean: 0 failures, rounds 43.6 s, longest 101.0 s; Katana 46.7%, Greatsword 56.3%, Daggers 47.1%; disarms 1.11 and knockdowns 1.74 per round. Sheets: `shots/task12/`.

Oct 3, 2026. Task 13 done: every Katana move now plays from a clip. Counter Lunge is Attack1H04_R from frame 6 ×1.65 (its lunge, worked out from the distance, reaches from 4.5 m as it is). Flash is pose-only: Parry1H01_R's loop for its window, then its hit, ×2.0; the bake gives a move with no damage or posture the body's track alone (`SwingBake.parts_for()`), so Flash places no blade and never strikes, and the weapon rides the clip's hand, for the Rogue too (`FighterView._fixed_on_clip()` now fixes it wherever there is no baked weapon path). Piercing Thrust is AttackPolearm01 two-handed ×1.15 and Swallow Sweep Attack2H03 ×1.00 (Whirl Cut's clip, wound round from behind). Both start straight into their wind-ups and hold the telling pose 4 source frames (chains gain a held part, "id@frame*n"), so by the first third of the wind-up the slash has the blade cocked at the right shoulder, the overhead raised over the head, the thrust drawn back level at the hip with the knee up, and the sweep the whole body wound round (`shots/task13/telegraphs.png`); a first fit, led in from 4 frames of the guard idle, left thrust and sweep alike there. With the thicker unblockable sweep counted, both needed longer lunges for 3.5 m: Piercing Thrust 1.0 → 1.4 m, Swallow Sweep 0.4 → 1.4. Both hit at 3.5 m where Right Cut misses (`test_katana_strings`). **Moonsplitter:** the director plays the ultimate (`ClipDirector.ult_clip()`): Attack2H01 raised at 1.0 to its frame 12 and held through the rules' 36-frame wind-up, then cut at 2.0 from there as the wave goes out (its blade passes the front 1.5 rules frames after); Attack2H03 for the horizontal wave; Sword_Heavy_Combo stretched over both without the packs; a director test checks the timing (no sheet tool plays the ultimate). Fixed on the way: a baked swing with no hand track no longer passes for a hand-keyed one when picking the free guard; the guard shuffle's strike plan with no steps (a charge, or no lunge) no longer reads a landing it doesn't have (it crashed a whole-match render). Godot 40-match soak clean: 0 failures, rounds 42.6 s, longest 99.5 s; Katana 60.0%, Greatsword 56.3%, Daggers 35.3% (15–17 matches each); disarms 1.13 and knockdowns 1.70 per round. Sheets: `shots/task13/`.

Oct 3, 2026. Task 14 done: the Katana's review package is in `docs/reviews/katana-animation-review.md`. **The video tool:** `node scripts/move_video.mjs` exports the reference branch's `game/` with `git archive` (no checkout; the main checkout is another session's), imports it once, renders every move of a weapon in both projects with the same `game/tools/move_video.gd` (written against what both branches share, MoveBench, and run by its absolute path in the other project; its renderer loads at run time so the other project's autoloads resolve), and composes them side by side under Godot's Movie Maker (`move_video_compose.gd`) into `shots/<weapon>_video.avi` (no ffmpeg needed); the Katana's is `shots/katana_video.avi` (local). The package also has contact sheets of every Katana move on both fighters (`shots/task14/hunter/`, `rogue/`), the guard and movement strips, the list of shared clips (none mirrored), the spike critique's 10 fixes and 7 conditions mapped to sheets and tests (godot-rebuild 14.17), and a 300-match `soak:tune`: the Katana 55.4% against its 53.1% baseline (within ±5), rounds 40.4 s (in target), disarms 1.00 per round (out, as at the baseline), the Greatsword 39.1% and the Daggers 54.3%, 0 failures. There are no trail sheets: trails are godot-rebuild 18.2–18.3, not built. Found: PoseCheck's arm limits fail on Kevin's clips as the swing checks did, so 14.17's "PoseCheck passes" needs the same exemption (recommended in the review). **Waiting on the owner: the Katana's review, which gates task 18.**

Oct 3, 2026. Task 18 done (started on the owner's goal of the next four tasks; see Decisions): the Greatsword's string and Piercing Lunge play and hit from clips, and the carry shows. A probe of the candidates with the Greatsword in hand (its tip 2.1–2.4 m ahead) found the clip table's two-handed names swapped, as the Katana's were: Attack2H01 is the diagonal from the right shoulder and Attack2H02 the straight overhead, and no two-handed clip cuts left to right. The fits: Heavy Swing Attack2H01 from its wound-up pose (frame 8; contact 16–18.3, settle 31) ×1.15; Backswing Attack2H01 mirrored, the same way round (new in the manifest as `Attack2H01_Mirror`) ×1.45; Overhead Strike Attack2H02 held raised on the charge frame (hold 8, contact 21–24.8, settle 47) ×1.53, whose clip ends 3 frames before today's recovery, so its recovery is 29 (from 32); Piercing Lunge AttackPolearm01 (contact 11–13.5, settle 32) ×1.83. All on today's startups and active frames. Lunges (the reach rule, as for the Katana): Heavy Swing 0.4 → 0.45 m ending on its first touch (frame 16), Backswing 0.4 → 0.55 (each 17.5 cm into a defender at 3.0 m after pushes of 2.7 and 7.7 cm), Overhead Strike 0.7 → 1.05 (touching from 3.5 m), and Piercing Lunge 0.8 → 1.0: it reaches 3.0 m by 33 cm as it was, but a sideways dodge out of the string's 2.2 m leaves the fighters 3.45 m apart, where the cone hit and the clip fell 11 cm short (the strings test's dodge-thrust), so it lunges further rather than the test moving. The Rogue plays HumanM for all four (7–14 cm off on her body). **The carry:** the manifest learns shared clips (`shared`: the masked poses' files sit in one folder for both sets), and gains ObjectGripShoulder01_R and 02_R of the Crafting pack; 02_R (01_R throws the elbow out) is `ClipDirector.CARRY_POSE`. While shouldered the director drives `CARRY`: the pose on the upper body over the legs' blend (`Shot.legs_free()` 1, so the legs walk, jog and strafe under it), faded in over 8 frames, the weapon riding the clip's hand on both fighters with the off hand on the grip below; an attack from the shoulder fades from it into the attack's first frame over its lift (6 frames, the clip held there by the rules), the legs handed to the attack across it; a guard raised from the shoulder fades back to the legs over the same 6. No CC0 clip carries, so without the packs nothing shows it. Tests: the director's carry, the lift and the guard (`test_clip_director`); the brain's impact estimate now checked against the first active frame, Heavy Swing's blade first touching on its second; the colossal-slide test starts 1.6 m apart (from 1.5 m the longer lunge left the block's pushback 1 cm short of the slide). Sheets: `shots/task18/` (the shoulder poses, `carry_walk`, `carry_lift` and `carry_guard` from the new sheet drives, each move on both fighters). Godot 40-match soak clean: 0 failures, rounds 42.8 s, longest 99.5 s; Katana 60.0%, Greatsword 31.3% (5 of 16), Daggers 58.8%; disarms 1.20 and knockdowns 1.69 per round.

Oct 3, 2026. Task 19 done: the Greatsword's movement attacks, Guard Crusher and Counter Lunge play and hit from clips, all on today's frames. **Bashes strike with a shoulder:** `Swing` gains `right_shoulder` and `left_shoulder` tracks (the joint, out along the shoulder line, the chest's forward as the edge), striking with a segment 12 cm long and 24 cm thick at the joint on any weapon (`SimConst.SHOULDER_STRIKE_*`); the bake gives a bash its left shoulder (both of the packs' bashes lead with it) and no hand, so the weapon rides the clip's hands on both fighters. The swing checks skip any swing baked from clips. The fits: Shoulder Charge UAL2 Shield_Dash, its crouch held 4 source frames first, ×1.20; Leaping Smash UAL2 Sword_GroundPound, held raised 4 frames, ×1.00; Rising Edge Attack1H05_R ×1.14 (Sword_UpperCut stands side-on and reaches 1.4 m); Lunge Cleave Attack2H04 ×1.17; Aerial Chop Attack2H01 from its wound-up pose ×1.33 (Sword_Aerial_A is 12 frames, too short to fill the move; Heavy Swing's clip played faster); Guard Crusher AttackShield01 ×1.00; Counter Lunge AttackPolearm01 from frame 4 ×1.75. Lunges for a touch from the test distances: Shoulder Charge 2.2 → 3.35 m (its shoulder gets 0.65 m ahead and its distance is 4.5 m, beyond even its cone's 4.1), Leaping Smash 3.0 → 3.15, Rising Edge 0.9 → 1.15, Lunge Cleave 2.2 → 2.35, Guard Crusher 1.6 → 1.85; Aerial Chop and Counter Lunge reach as they are. The Rogue plays HumanM for the Iglesias clips (8–15 cm off); the CC0 clips are on her own rig. The posture-crush tests pass. For the review: Shoulder Charge's last frames turn the Greatsword's grip over as the clip rises (it fades to the idle from there), and Leaping Smash ends bent low over the planted blade (the clip's own). Sheets: `shots/task19/`. Godot 40-match soak clean: 0 failures, rounds 42.7 s, longest 99.5 s; Katana 53.3%, Greatsword 37.5% (6 of 16), Daggers 58.8%; disarms 1.17 and knockdowns 1.72 per round.

Oct 3, 2026. Task 20 done: every Greatsword move now plays from a clip, and its review package is in `docs/reviews/greatsword-animation-review.md`. The fits, all on today's frames: Low Sweep Attack2H03 with its wind-round held 5 source frames ×1.08; Reaping Sweep AttackPolearm04, a whole-body spin (new in the manifest with AttackPolearm02), held 4 frames ×1.04, so it reads apart from Low Sweep; Mountain Slam AttackPolearm03, the overhead to the ground, ×1.00, so it reads apart from Leaping Smash; Skewer AttackPolearm01 with its pull-back held 4 frames ×1.36; Meteor Drop UAL2 Sword_GroundPound held raised 2 frames ×1.10. Lunges for the unblockables' 4.0 m: Reaping Sweep 0.3 → 1.65, Mountain Slam 0.6 → 1.35, Low Sweep 0.8 → 0.85 (for 3.5 m). **Impaler** plays through the director (`ClipDirector.impaler_clip()`): AttackPolearm01 drawn back through the aim, thrust out as the dash starts and held through the dash and the impale, the burst playing on and the recovery to the clip's end (the clip table's Sprint01 into AttackPolearm03 would swing the arms free through the dash, and Polearm03 is an overhead); the fallback is Sword_Dash over the aim and dash. A change of an ultimate's phase now crossfades as a follow-up (4), and an ultimate from the shoulder over the lift. Low Sweep's leap-counter test plays its baked path against a jumping defender, and the slams' knockdown tests pass. **The soak:** the first 300-match run put the Greatsword at 33.9%. Counting its moves over its 115 matches (`game/_scratch/gs_stats.gd`, local) with its clips and with every move back on its cone (40.9%) showed the string barely changed but the computer opponent fighting closer: it spaces and attacks from the weapon's reach, which Heavy Swing's baked path had made 2.42 m where the authored reach is 2.75; with the brain's reach at 2.75 the same matches won 40.9%. So a light starter's swing baked from a clip now leaves the weapon's authored reach (`WeaponDef.derive_reach()`; the Katana's goes from 1.98 to its authored 2.1), a hand-keyed one still giving it. The 300-match `soak:tune` after it: 0 failures; rounds 39.1 s (longest 104.0 s); Greatsword 39.1% (its figure before its clips; baseline 46.1, so −7.0, outside ±5), Katana 52.3% (−0.8), Daggers 57.4%; disarms 0.99 and knockdowns 1.77 per round; hits 23.9 and blocks 21.9 per round. The 7 points are the carry's and knockdown's (tasks 15–16), which the clips can't win back: decision 4 of the review. The package: the video `shots/greatsword_video.avi` (local), every move's sheets on both fighters (`shots/task20/hunter/`, `rogue/`), the telegraphs (`shots/task20/telegraphs/`), the carry sheets (`shots/task18/`), the shared clips (one mirrored: Attack2H01 for Backswing), the spike critique's differences from the Katana's table. No sheet tool plays an ultimate; a director test checks Impaler. The owner passed the Greatsword the same day (see Decisions).

Oct 3, 2026. Task 21 done: the Daggers' string, heavies and Passing Cut play and hit from clips, a baked track for each hand, all on today's frames. A probe of both hands' tips: Kevin's `_L` clips, a left-handed whole-body mirror, are exactly Off-hand Slice. The fits: Quick Slice Attack1H01_R and Off-hand Slice Attack1H01_L (from frame 2, contact 8.5, ×1.86); Twin Rip AttackDW01, both blades crossing in front (×1.67); Flurry Finisher AttackDW02, the double stab (×1.36); Twin Fang AttackDW02 with its wind-back held 3 source frames and on the charge frame (hold 6, ×1.29), the rules' 1.4 m lunge the dash; Spinning Backhand AttackPolearm04, the whole-body spin, a dagger in each hand (no one-handed or dual-wield clip spins) ×1.22; Passing Cut Attack1H03_R from frame 4 ×1.67. **The lights reach further than their cones:** at the Daggers' 2.0 m their clips put the whole 26 cm dagger into a defender, so their lunges shorten to put 17.5 cm in, each ending on its first touch: Quick Slice 0.3 → 0.15 m, Off-hand Slice 0.3 → 0.17, Twin Rip 0.4 → 0.38, Flurry Finisher 0.6 → 0.35 (lunge ends 8, 8, 11, 13). Quick Slice and Off-hand Slice were retimed (contact 8 → 8.5) so each first touches on its first active frame: touching on its second, Quick Slice left Off-hand Slice landing as the 10-frame string hitstun ended, taking the defender's free step (the strings test). Spinning Backhand falls short of 2.5 m: 0.4 → 1.1. The Rogue plays HumanM for all but Off-hand Slice. **The strings tests** now play each string from 2.2 m or the weapon's duelling distance if nearer (the Daggers' 2.0; `WeaponStringsTest._gap()`). **The grip flip:** `FighterRig`'s reverse grip is now a turn (`set_reverse_turn()`, 0 forward to 1 reverse, about the knuckles); the director gives each shot the grip (`Shot.grip`): reverse unless an attack drives, turned forward from where it stood over the attack's crossfade, and back over the last `GRIP_BACK` (6) recovery frames unless a follow-up is queued; the view turns the Hunter's fixed daggers by it (the Rogue's ride the baked paths, forward, and turn over the swing player's blend). Tests: the director's flip (`test_clip_director`), the daggers halfway round in the fist (`test_weapon_in_hand`). Sheets: `shots/task21/` (each move on both fighters, `flip_hunter.png`). Godot 40-match soak clean: 0 failures, rounds 43.3 s, longest 117.9 s; Katana 46.7%, Greatsword 43.8%, Daggers 58.8% (15–17 matches each); disarms 1.13 and knockdowns 1.62 per round.

## Build order

1. **The gate:** 1.
2. **The pipeline:** 2, 3, 4, 5 (the catalogue goes to the owner), 6, 7, 8.
3. **The Katana** (after the catalogue's OK): 9, 10, 11, 12, 13, 14 (its review goes to the owner).
4. **The rule changes** (while the owner reviews the Katana): 15, 16, 17.
5. **The Greatsword** (after the Katana's OK): 18, 19, 20.
6. **The Daggers** (after the Greatsword's OK): 21, 22, 23.
7. **Bare hands** (after the Daggers' OK): 24, 25.
8. **Reactions and movement** (after the bare hands' OK): 26, 27, 28, 29, 30, 31.
9. **The round flow** (after 31's OK): 32, 33, 34.
10. **Finish:** 35, 36.

## Tasks

### Phase A: the gate

- [x] **1. The retargeting prototype on five clips.** A bone map for Kevin's 56-bone `B-` rig onto Godot's humanoid profile, made the way `ual_bone_map.tres` is. Five clips are read through Godot's FBX importer from both HumanM and HumanF and retargeted: CombatIdle1H01, Attack1H01_R, Attack2H01, Roll01 and CombatDeath01, plus Dodge01 to settle the backstep. The root, scale, `B-handProp` and jaw tracks are stripped. The Hunter plays HumanM and the Rogue HumanF, with the Katana or the Greatsword roughly fixed in the main hand.
  - Throwaway apart from the bone map and a short findings note in `docs/research/retarget-prototype.md`. The converted clips go only to a gitignored scratch folder.
  - Check: contact sheets of each clip on both fighters at four phases, from the gameplay camera, three-quarter and close. The note also answers:
    - whether Roll01 [RM]'s root track can be read for the roll's travel;
    - whether Dodge01 works as the backstep.
  - **Gate.** The prototype passes if, after any bone-map or rest-pose fixes made in the task:
    - the hands hold the grip;
    - the feet neither slide nor cross;
    - shoulders, elbows and knees bend the right way on both fighters.

    Owner: decides pass or fail. On a fail, this plan is rewritten for the spec's fallback (UAL2 Source clips as first candidates, the procedural swing player kept for moves without one) before anything else.
  - Blocked by: none · Stories: 48

### Phase B: the pipeline

- [x] **2. The packs' folder, the clip manifest and the import tool.**
  - **The packs' folder.** An untracked `.assets-src-path` names the folder the packs are unzipped in; without it the tools look in `assets_src/`. Both are added to `.gitignore`, and `import_assets.gd` reads the same setting instead of its hard-coded folder.
  - **The clip manifest** is committed and holds no animation data. For each clip it gives the pack, file and set, whether it is mirrored, its loop mode and its four markers in source frames. It starts with task 1's clips.
  - **The import tool** converts only the manifest's clips, through task 1's bone map (with the hips' travel scaled to each fighter's legs, as task 1 found), into one animation library per set (HumanM, HumanF), in a gitignored folder inside the Godot project. It is deterministic. Without the packs it exits with a message naming the setting.
  - **The export.** `npm run build` carries the libraries, and `--smoke` plays a match with them.
  - Also, with the owner's OK, remove the clean `add-3d-references-530c11` worktree.
  - Check:
    - a content test that every manifest clip has its four markers;
    - a local-only test that the tool finds every manifest clip, and that two runs write identical files;
    - a test that the bone map maps every bone the tool uses;
    - `git status` is clean after an import;
    - the exported build plays a clip.
  - Blocked by: 1 (and the owner's pass) · Stories: 38, 39, 41, 49
- [x] **3. The fallback library and the soak baseline.**
  - **The fallback library.** `build_animation_library.gd` adds every UAL2 Source clip the spec's clip table names to the committed CC0 library, read from the already committed `UAL2_Source.glb`.
  - **The soak baseline.** A 300-match `soak:tune` and a 40-match soak, run before any rules change, recorded in Progress. Each weapon's review is measured against them (±5 points).
  - Check: a content test that the CC0 library holds every fallback clip in the table; the art stays inside its 110 MB budget.
  - Blocked by: none · Stories: 40, 44
- [x] **4. The weapon in hand.** The weapon is fixed to the main hand at a per-weapon grip offset, measured on each fighter's hand. A two-handed weapon (Katana, Greatsword) puts the off hand on its `OffHandGrip` with IK on top of the clip. The Daggers sit one in each hand and can be turned 180° about the hand into the reverse grip. Fixing the weapon is used only while a clip drives the arms; the stand-in poses keep posing it until task 35.
  - Check:
    - a content test that each grip offset puts the handle inside the fist on both fighters;
    - the off hand lands within 1 cm of the off-hand grip through task 1's clips;
    - sheets of the five clips with each weapon in hand.
  - Blocked by: 2 · Stories: 2, 11
- [x] **5. The catalogue sheet.** The manifest grows to every first candidate in the spec's clip table, with provisional markers, and the import tool converts them. A shot scene renders every candidate on both fighters at four phases with its weapon in hand, grouped by weapon, and captioned with the clip's name, length and set.
  - Check: one page per weapon and one for the states, with no candidate missing (a test counts them against the manifest).
  - **Owner:** reviews the catalogue and swaps any clip. Swaps go into the spec's clip table. This review gates task 9.
  - Blocked by: 4 · Stories: 45
- [x] **6. The bake.** The bake is a pure function. It takes a sampled clip (or a chain of clips), its markers and a speed between 1.0 and 2.0. It gives back:
  - the clip retimed onto rules frames;
  - each striking part's grip, blade and edge, and the body's coil, in the fighter's own space, one key per rules frame;
  - the move's startup, active and recovery frames from the markers.

  The swing file format gains a `baked` flag on a track (one key per frame, no splining), and the reader refuses a baked track with a missing frame. A bake command writes `game/sim/moves/swings/<weapon>.json` for the moves it is given, and a report of each move's speed and frames against today's.
  - Check: tests on a committed CC0 UAL clip, so CI needs no packs:
    - the markers land on the right rules frames at a given speed;
    - the samples match the posed hand within 1 mm;
    - the output is deterministic;
    - a missing marker or a speed outside 1.0–2.0 is refused;
    - a baked file round-trips;
    - the existing swing tests pass.
  - Blocked by: 4 · Stories: 2, 3, 43, 49
- [x] **7. The reach correction and the Rogue's paths.**
  - **The reach correction.** Where a clip's arm stops short of the reach rule, the bake adds an arm-IK offset toward it. The offset eases in over the wind-up and out over the recovery, is at most 15 cm, and is written with the swing. The fighter view plays the same correction from the same data.
  - **The Rogue's paths.** Paths are baked from HumanM on the Hunter. The Rogue's HumanF clip is pulled onto the shared path with hand IK. A move whose HumanF clip is more than 5 cm off at any active frame is flagged, and the Rogue plays HumanM for it.
  - Check:
    - the correction stays under 15 cm and is zero outside the attack;
    - a move that needs more is reported;
    - a flagged move resolves to HumanM for the Rogue;
    - on a CC0 clip, the visible blade and the baked path agree within 1 cm on every active frame.
  - Blocked by: 6 · Stories: 2, 36, 37
- [x] **8. The clip director: idle and attacks.** The clip director is a pure function, like `HudState`. It takes a fighter's rules state and the frame's events, and gives back which clips play, at what times and with what weights. `FighterView` applies its answer to an `AnimationTree` that is advanced only on rules frames.
  - **Covered here:**
    - the free idle by weapon class;
    - an attack's clip time set from its attack frame (wind-up across the startup, strike across the active frames, follow-through across the recovery);
    - a charge holding at the end of its wind-up;
    - hit-stop and pause holding the time;
    - the crossfades: 3 frames into an attack, 4 for a follow-up, 2 for a dodge-cancel, a cut for hitstun, 6 for locomotion and 8 for stances;
    - foot locking (the owner's choice at task 1's gate): the leg IK holds a planted foot where it landed under every clip, so the retarget's creep of up to 6 cm goes; task 29 reuses it for locomotion.
  - **Without the Iglesias libraries** it plays the fallback table, shows a small "animation packs missing" note in the match, and logs the setting to fix.
  - Moves without a baked swing keep the stand-in poses.
  - Check:
    - director tests on the cases above, and that the fallback is chosen when the libraries are missing;
    - a shot of the note;
    - a sheet of the idle on both fighters for each weapon class;
    - planted feet move under 1 cm through task 1's clips on both fighters.
  - Blocked by: 3, 4 · Stories: 3, 4, 6, 7, 40, 43

### Phase C: the Katana

- [x] **9. Right Cut from end to end.** The first move on the whole path:
  - its clip's markers set in the manifest;
  - baked at the chosen speed;
  - its retuned frames in `katana.gd` and `test_moves`' differences table;
  - its baked swing in `katana.json`;
  - the rules hitting with it;
  - the director playing it on both fighters, with the Rogue's path check.
  - Check:
    - the swing checks on the baked path;
    - `test_duel_reach` for Right Cut;
    - the Katana string tests pass or are updated with the reason;
    - a debug-view shot with the flash where the blade meets the capsule;
    - contact sheets;
    - a 40-match soak is clean.
  - Blocked by: 5 (and the owner's OK), 7, 8 · Stories: 1, 2, 3
- [x] **10. The Katana's other lights.** Return Cut, Kesa Cut and Crown Cut, each following the previous swing from its pose. The first-key continuity test is dropped for baked tracks; the side continuity test stays.
  - Check:
    - the swing checks;
    - the duel reach test for all four lights;
    - a defender can still block or parry the second light;
    - sheets of the L-L-L-L string with each stop;
    - a 40-match soak is clean.
  - Blocked by: 9 · Stories: 1, 4, 5
- [x] **11. The Katana's heavies.** Both Iai Slashes (Sheathe Hips01_R chained into Attack1H04 or Attack1H05), Rising Heaven, Returning Draw and Heaven Splitter. The manifest and the bake learn chained clips here. The Iai needs the saya, so this task builds it: a saya made in code at the left hip whenever the Katana is the weapon (godot-rebuild 14.16, retired into this task). The sheathe, the sheathed hold kept while walking and strafing at block speed, and the dodge cancel out of it play from clips.
  - Check:
    - the swing checks, with the sheathed frames carrying no blade;
    - the Iai enters a defender at 3.6 m and misses at 4.2 m;
    - task 9's Iai tests of the godot-rebuild plan pass;
    - sheets of the stance, both draws and each heavy chain;
    - a 40-match soak is clean.
  - Blocked by: 10 · Stories: 1, 8
- [x] **12. The Katana's sprint, dodge, backstep and jump attacks.** Running Draw, Leaping Cleave, Wind Cut, Whirl Cut, Rising Cut, Lunging Cut, Aerial Cut and Falling Crown.
  - Check: the swing checks; each hits from its distance in the test-distance table; the dodge attacks still come up facing the opponent; sheets; a 40-match soak is clean.
  - Blocked by: 11 · Stories: 1, 13
- [x] **13. The Katana's Counter Lunge, Flash, unblockables and Moonsplitter.**
  - Counter Lunge.
  - Flash, as a pose-only clip.
  - Piercing Thrust and Swallow Sweep, with the thick-blade bonus.
  - Moonsplitter, held then released, in time with the rules' wave.
  - Check:
    - the evade counter's lunge test and the unblockable combat tests pass;
    - an unblockable hits where the light misses;
    - sheets of slash, overhead, thrust and sweep side by side, telling them apart in the first third of the wind-up;
    - a 40-match soak is clean.
  - Blocked by: 12 · Stories: 5, 13
- [x] **14. The before-and-after video, and the Katana's review.**
  - **The video tool.** It renders each move of a weapon with the procedural version from a `feature/godot-rebuild` checkout and the clip version from this branch, side by side.
  - **The review package:**
    - the video;
    - contact sheets of every Katana move on both fighters;
    - a list of moves that share or mirror a clip;
    - sheets of the guard and the trails, and a checklist mapping each of the animation spike critique's fixes and conditions that still applies to its sheet or test (from godot-rebuild 14.17, folded in here; godot-rebuild task 14 is ticked when this review passes);
    - a 300-match `soak:tune`, with the Katana's win rate within ±5 points of the baseline and rounds and disarms in their targets.
  - Check: the package is committed (the video stays local under `shots/`) and sent to the owner.
  - **Owner:** OKs the Katana. This gates task 18.
  - Blocked by: 13 · Stories: 44, 46, 47

### Phase D: the rule changes

- [x] **15. The Greatsword's shoulder carry.**
  - A shouldered flag on an armed Greatsword fighter. It turns on after 20 frames of moving in the free state, and at every round start. It turns off on any attack, block, parry, dodge, backstep, hitstun, blockstun, knockdown, disarm or pick-up.
  - An attack from the shoulder adds `GS_SHOULDER_LIFT_FRAMES` (6) to its startup, and its dodge cancel opens 6 frames later.
  - The computer opponent's timing and reach estimates include the lift.
  - Check:
    - rules tests for each way on and off, and that standing still and jumping leave the flag alone;
    - an attack from the shoulder hits 6 frames later;
    - dodge attacks and follow-ups never pay;
    - the brain's estimate includes the lift;
    - a 40-match soak is clean.
  - Blocked by: none · Stories: 10
- [x] **16. Knockdown.** A new fighter state.
  - **Causes:** a hit (not a block, a parry or a counter) from an unblockable, a heavy at full charge, or Mountain Slam, Meteor Drop or Leaping Smash. A knock-out plays the KO instead.
  - **Phases:** fall 20, ground 30 and stand-up 25 frames (provisional).
  - **Invulnerability:** from the fall's first frame to stand-up frame 10.
  - **The last 15 frames:** the fighter can block or parry, but can't attack, dodge or move.
  - **Events:** `knockdown` and `standup`.
  - It replaces the hitstun of those hits. Damage, posture and knockback are unchanged, and the stomp keeps its 70-frame stun.
  - The computer opponent doesn't attack a downed fighter before the guard window.
  - Until task 28 the view plays the fallback (Hit_Knockback, LayToIdle).
  - Check:
    - rules tests for each cause, and for no knockdown on a block, a parry or a KO;
    - the invulnerability window and the guard window;
    - free on the last frame;
    - the stomp stays 70;
    - the brain waits;
    - a 40-match soak is clean.
  - Blocked by: none · Stories: 18, 19, 20
- [x] **17. The roll's travel.** The dodge's curve (today `ease_out_cubic` over 16 frames) becomes Roll01 [RM]'s ground travel. The import tool reads it once, normalised to 0–1 and resampled to 16 frames, and it is stored as 17 numbers in the rules' constants. The distance, frames, i-frames, recovery, the forward-dodge counter window and the backstep are unchanged.
  - Check:
    - the roll ends at the same distance in the same frames along the stored curve;
    - the curve rises from 0 to 1 and never falls;
    - the i-frames and the counter window are unchanged;
    - the backstep is unchanged;
    - a local-only test that the curve matches the pack's;
    - a 40-match soak is clean.
  - Blocked by: 2 · Stories: 26, 27

### Phase E: the Greatsword

- [x] **18. The Greatsword's string, Piercing Lunge and the carry.** Heavy Swing, Backswing, Overhead Strike and Piercing Lunge, two-handed. The view adds the carry: CombatIdle2H01, ObjectGripShoulder masked onto the upper body over locomotion while shouldered, and the 6-frame lift as a crossfade from the shoulder into the attack's first frame.
  - Check:
    - the swing checks;
    - the duel reach test at 3.0 m;
    - task 10's tests of the godot-rebuild plan;
    - director tests that the carry shows when the flag is on;
    - sheets of the carry, the lift and each move;
    - a 40-match soak is clean.
  - Blocked by: 14 (and the owner's OK), 15 · Stories: 1, 9
- [x] **19. The Greatsword's sprint, dodge, backstep and jump attacks, Guard Crusher and Counter Lunge.** Shoulder Charge, Leaping Smash, Rising Edge, Lunge Cleave, Aerial Chop, Guard Crusher and Counter Lunge. Shoulder Charge and Guard Crusher strike with a baked body track.
  - Check: the swing checks (body tracks exempt from the wrist check); each hits from its table distance; the posture-crush tests pass; sheets; a 40-match soak is clean.
  - Blocked by: 18 · Stories: 1, 13
- [x] **20. The Greatsword's unblockables and Impaler, and its review.**
  - The moves: Reaping Sweep, Mountain Slam, Low Sweep (narrower and faster than Reaping Sweep, and low enough to jump), Skewer, Meteor Drop and Impaler.
  - The review package as in task 14.
  - Check:
    - Low Sweep misses a jumper;
    - the slams knock down;
    - the unblockable combat tests pass;
    - the review package, including the soak within ±5 points.
  - **Owner:** OKs the Greatsword. This gates task 21.
  - Blocked by: 16, 19 · Stories: 5, 13, 18, 44, 46, 47

### Phase F: the Daggers

- [x] **21. The Daggers' string and heavies.** Quick Slice, Off-hand Slice, Twin Rip, Flurry Finisher, Twin Fang, Spinning Backhand and Passing Cut, with a baked track for each hand. The combat idle holds the daggers in reverse grip. They flip forward over the attack's 3-frame crossfade, and back over the last 6 recovery frames when no follow-up comes.
  - Check:
    - the swing checks for both blades;
    - the duel reach test at 2.0 m;
    - task 11's tests of the godot-rebuild plan;
    - a director test of the grip flip;
    - sheets;
    - a 40-match soak is clean.
  - Blocked by: 20 (and the owner's OK) · Stories: 1, 11
- [ ] **22. The Daggers' sprint, dodge, backstep and jump attacks, Shadow Step and Counter Lunge.**
  - Slide Slash, with Attack1H02 masked onto the upper body over RunSlide01.
  - Pounce, Reverse Spin, Flick, Rebound Lunge, Air Slash, Dive Stab and Counter Lunge.
  - Shadow Step: Roll01 sped up, with the body hidden in the blink.
  - Check: the swing checks; each hits from its table distance; the Shadow Step backstab tests pass; sheets; a 40-match soak is clean.
  - Blocked by: 21 · Stories: 1, 13
- [ ] **23. The Daggers' unblockables and Lightning Tempest, and their review.**
  - The moves: Serpent Sweep, Needle Thrust and Lightning Tempest (the chained spin and the final).
  - The review package as in task 14.
  - Check: the unblockable combat tests pass; the Tempest follows the rules' phases; the review package.
  - **Owner:** OKs the Daggers. This gates task 24.
  - Blocked by: 22 · Stories: 13, 44, 46, 47

### Phase G: bare hands

- [ ] **24. The punches.** Jab, Cross, Hook, Slip Jab, Spinning Backfist, Lunging Palm and Counter Lunge, striking with the fist.
  - Check:
    - the elbow checks;
    - the duel reach test at 1.6 m;
    - the disarmed tests pass (no block or redirect);
    - sheets;
    - a 40-match soak is clean.
  - Blocked by: 23 (and the owner's OK) · Stories: 1, 12
- [ ] **25. The kicks and Breaker Palm, and the bare hands' review.**
  - Roundhouse, Spinning Heel, Snap Kick, Flying Knee (a shin segment), Dragon Kick, Air Kick and Axe Kick, with baked foot tracks.
  - Breaker Palm.
  - The review package as in task 14.
  - Check: each hits from its table distance and misses from 6 m; the review package.
  - **Owner:** OKs bare hands. This gates task 26.
  - Blocked by: 24 · Stories: 12, 13, 44, 46, 47

### Phase H: reactions and movement

- [ ] **26. Hits, blocks and long stuns.**
  - Hitstun plays CombatDamage01 or 02, by the hit's side.
  - A held block holds the weapon class's Parry Loop, and blockstun plays its Parry Hit.
  - The stomp, leap, redirect, disarm-stagger and impaled stuns play Stun01, fitted to their length.
  - The procedural recoil and lean go.
  - Check: director tests for each state's clip and fit; sheets from the gameplay camera.
  - Blocked by: 25 (and the owner's OK) · Stories: 14, 15, 17
- [ ] **27. The parry.** The parrier plays Parry Hit. The parried attacker's own clip runs backwards from its contact frame over the rebound, then hands over to Stun01 for the rest of the recoil. Flash and redirect parries too. If the reversed clip looks wrong, the fallback is Stun01 from the contact frame.
  - Check: director tests for the reversed time and the handover; sheets of a parry for each weapon pairing.
  - Blocked by: 26 · Stories: 16
- [ ] **28. Knockdown and KO.** Knockdown01 Fall, Ground and StandUp fitted to the three phases. CombatDeath01–04 picked by the final blow's direction (front or back) and strength (light or heavy), slowed by the final-blow slow motion.
  - Check: director tests for the phase fit and the death pick; sheets; the phase lengths settled from the clips' markers and a soak, with the spec updated.
  - Blocked by: 16, 27 · Stories: 18, 21
- [ ] **29. Locomotion.**
  - A 2D blend space on velocity in the fighter's facing space:
    - Walk01 and Run01 forward, backward and on the diagonals;
    - StrafeWalk01 and StrafeRun01 sideways;
    - Sprint01 in its five forward directions;
    - Turn01 when the facing turns more than about 30° while standing.
  - The playback rate follows each clip's measured stride.
  - Foot locking keeps planted feet still.
  - The guard shuffle, the hip-turn, the reversed cycle and the lean go. Footsteps follow the clips' foot contacts.
  - Check: director tests for the blend weights by direction and speed; planted feet move under 1 cm; strips of running, strafing, backpedalling and sprinting; the footstep tests pass.
  - Blocked by: 28 · Stories: 22, 23, 24
- [ ] **30. The roll and the other states.**
  - **The roll** plays Roll01 with the body turned toward the roll's direction. The body turns back to face the opponent over the recovery, or over a dodge attack's first 3 frames.
  - **The backstep** plays Dodge01.
  - **A new roll sound** (cloth and a thump) plays on a dodge that isn't a backstep.
  - **The other states:** jump and land, the stomp, the leap, the evade lunge, the pick-up (Loot01) and the recall. On a disarm the weapon leaves the hand (its model on the ground is godot-rebuild 18.10's), and it returns on the pick-up or the recall.
  - Check:
    - director tests for the roll's turn and each state's clip;
    - a sound test that the roll and the backstep play different cues;
    - sheets.
  - Blocked by: 17, 29 · Stories: 13, 25, 28, 29, 30
- [ ] **31. The reactions and movement review.**
  - Contact sheets and strips of every state on both fighters.
  - A short playtest of the reactions, the roll and the knockdown.
  - **Owner:** OKs reactions and movement. This gates task 32.
  - Blocked by: 30 · Stories: 47

### Phase I: the round flow

- [ ] **32. The draw at the round intro.**
  - The Katana is drawn from its saya at the left hip (Unsheathe Hips01_R).
  - The Daggers are drawn from two leather sheaths at the small of the back (Unsheathe Hips01_Both, with IK onto the sheaths). The sheaths are new meshes built in code.
  - The Greatsword is lifted to the shoulder (CombatEnter2H01).
  - Bare hands play CombatEnter1H01.
  - Check: director tests for the intro clip by weapon; sheets of each draw; the scene smoke test loads the sheaths.
  - Blocked by: 31 (and the owner's OK) · Stories: 31
- [ ] **33. The victory poses from the packs.** The Katana sheathes into the saya (Sheathe Hips01_R) and bows (Reverence01); bare hands cheer (Cheer01).
  - Check: director tests for the victory clip by weapon; sheets.
  - Blocked by: 32 · Stories: 32, 35
- [ ] **34. The hand-keyed victories.** Both are keyed in Blender on the Quaternius rig, CC0 and committed:
  - the Daggers' toss, flip and catch;
  - the Greatsword planted in the ground, with both hands on the pommel (hand IK locks them to it).
  - Check: the clips are in the committed library; sheets; the art budget holds.
  - Blocked by: 33 · Stories: 33, 34

### Phase J: finish

- [ ] **35. Retire the procedural animation.**
  - Removed: `SwingPlayer`, `StickPose` and the WeaponHold idles, the guard shuffle's and stance's leftovers, the demo swings (`katana_demo.json` and `scripts/swings`), and the posing of weapons in space.
  - Added: a director test that every move of every weapon resolves to a clip, and a local-only test that re-bakes every move and fails if a committed swing file differs.
  - Check:
    - the full tests and the typecheck pass;
    - CI passes without the packs;
    - the scene smoke test loads every scene;
    - a 40-match soak is clean.
  - Blocked by: 34 · Stories: 37, 43, 49
- [ ] **36. The final playtest and the hand-over.**
  - A playtest of cancels, hitstun interrupts, the roll, knockdowns and the shoulder carry.
  - The final sheets and soak.
  - The spec and the godot-rebuild docs brought up to date, and the pull request marked ready.
  - **Owner:** plays the build and approves the pull request.
  - Blocked by: 35 · Stories: 1–49
