# Spec: Animation Studio

Oct 3, 2026 · status: spec approved by the owner (Oct 3); plan approved (`docs/plans/animation-studio.md`, Oct 3); tasks 1–6 done (the gallery), lane paused on Oct 4 at gate 6 · branch `feature/animation-studio`, off `feature/authored-animation` (at 3b9b01c, task 27), pull request against `feature/authored-animation` until PR #12 merges, then against `feature/godot-rebuild`

The Animation Studio is a local dev tool for the Godot game: a gallery of every clip the fighters play, grouped by category and playing live, where clicking one opens a full editor for it. Each animation also has a chat panel: a prompt sent from it starts a new Claude Code session in a fresh git worktree, with the animation's data and a screenshot attached, and that session takes the change through the usual spec, plan and pull request flow.

It is a new tool, not part of the game. It never ships, and it reads the owner's licensed Iglesias packs from their machine.

## Problem Statement

The authored-animation feature put all 70 moves, the reactions and the ults on clips, but tuning those clips is slow:

- There is nowhere to *see* every animation. The catalogue (`clip_sheet.tscn`) and the move sheets are still images; seeing a move in motion means a match, `move_bench.gd` or a rendered video (`move_video.mjs`).
- Every change is a hand edit of `clip_manifest.json`, `move_clips.json`, the frame data in `sim/moves/*.gd` or the constants in `clip_director.gd`, then `node scripts/godot.mjs bake`, then a match or a video to see the result. Marker and chain edits are numbers in source frames with nothing to scrub against.
- A pack clip that is nearly right (a wrist that bends too far, an elbow through the torso, a Rogue-only drift) can't be touched up. The only options are a different clip, a chain trick or a new hand-keyed clip, and hand keys mean writing IK targets into JSON by hand.
- Asking Claude for an animation change means describing the move, its file and the frame in words, from scratch, every time.

## Solution

`node scripts/godot.mjs studio` opens the Animation Studio, a Godot scene that plays clips through the game's own machinery (ClipDirector, ClipTiming, ClipChain, the retargeted libraries and the procedural layers), so what it shows is what a match shows.

- **Gallery.** One live tile per animation: the moves grouped by weapon (Katana, Daggers, Greatsword, Fists), then States, Ults and a Source clips tab. Visible tiles play on a loop; tiles scrolled out of view pause.
- **Editor.** Click a tile to open it:
  - a timeline with play, scrub, frame step, speed and loop;
  - draggable clip markers;
  - chain editing;
  - frame-data bands with editable frame data;
  - a blade trail and hit-arc overlay;
  - bone posing with gizmos and IK handles, which makes new keyed clips and **correctives** (per-bone touch-ups keyed on top of an existing clip).

  Edits are held in memory with undo and redo. Save writes the data files and reruns the bake.
- **Chat panel.** A prompt box beside the editor. Sending a prompt:
  1. makes a new worktree and branch from the commit the Studio is running on;
  2. writes a context folder with the animation's data, a screenshot and the selected frame or range;
  3. opens a terminal running `claude` in that worktree.

  The owner continues there, or resumes the session in the desktop app with `/resume`. Each animation keeps a log of the refinements sent for it.

## User Stories

### Browsing

1. As the owner, I want every animation the fighters play on one screen, playing, so that I can spot the ones that look wrong without starting a match.
2. As the owner, I want animations grouped as the game uses them: Katana, Daggers, Greatsword, Fists, States, Ults, and the raw source clips, so that I can find a move by where it lives in a fight.
3. As the owner, I want to switch the whole gallery between the Hunter (HumanM clips) and the Rogue (HumanF clips), so that I can check both bodies.
4. As the owner, I want each tile to show the move's name, its id, and a badge when it is playing a fallback (packs missing) or a provisional clip, so that I know what I'm looking at.
5. As the owner, I want tiles I've scrolled past to stop animating, so that the gallery stays smooth with 100+ tiles.
6. As the owner, I want to filter the gallery by name and by badge (provisional, has correctives, has unsaved edits, balance changed), so that I can work through a list.

### Playing and inspecting

7. As the owner, I want to play, pause, scrub, step one frame at a time, loop, and slow an animation down, so that I can study any instant.
8. As the owner, I want to switch between source frames (the clip at 30 fps) and rules frames (the move as the rules time it at 60 a second, after ClipTiming and the chain), so that I can relate the clip to the frame data.
9. As the owner, I want the startup, active and recovery frames drawn as bands on the timeline, with the clip markers above them, so that I can see whether the wind-up, contact and settle line up with the rules.
10. As the owner, I want the baked blade path drawn as a trail, with the hit arc, reach and lunge shown in the viewport, so that I can see where the move hits.
11. As the owner, I want to turn the procedural layers (guard stance, foot lock, lean) on and off, so that I can tell a clip problem from a layer problem.
12. As the owner, I want an orbit camera with presets (front, side, top, the match camera), so that I can view a motion from any angle.
13. As the owner, I want a rules preview that plays the move through the real rules against a standing dummy and shows hit or miss, so that I can check a change still connects.

### Editing clips and moves

14. As the owner, I want to drag a clip's windup, contact, contact_end and settle markers on the timeline, so that I can retime a clip without typing frame numbers.
15. As the owner, I want to edit a move's chain: add, remove and reorder parts, set each part's from-to range, add holds (`id@frame*n`), pick a part from the pack, UAL or keyed clips, and set the move's speed and sheathed frames, so that I can rebuild a move visually.
16. As the owner, I want to edit a move's frame data (startup, active, recovery, lunge, lunge_end, range, arc) next to the bands, so that I can make the rules and the clip agree.
17. As the owner, I want to edit the timings of the states and ults (guard, hit, stun, rebound, carry, knockdown, the ults' clips) the same way as moves, so that reactions get the same care as attacks.
18. As the owner, I want undo and redo for every edit, a marker for unsaved changes, and a warning before I leave with unsaved changes, so that experimenting is safe.
19. As the owner, I want Save to write the files and rerun the bake for the affected weapon, and to tell me plainly if the bake refuses (baked frames no longer match the frame data) and by how much, so that I never leave a weapon half-baked.
20. As the owner, I want a "balance change" badge whenever a save changes frame data, reach or arc, reminding me that the commit needs its tests and `docs/mvp-spec.md` updated and a soak run, with a button that sends the change to the chat panel to do that, so that tuning stays honest.

### Posing bones

21. As the owner, I want to select a bone in the viewport or from a skeleton list and rotate it with a gizmo on the current frame, so that I can touch up a pose.
22. As the owner, I want IK handles for the hands, feet, hips and spine, so that I can pose a limb by its end rather than joint by joint.
23. As the owner, I want my bone keys on a clip saved as a corrective that plays on top of it, with keys interpolated between frames and an ease in and out, so that I can fix a pack clip without replacing it.
24. As the owner, I want a corrective to apply to both bodies by default, with an optional override for one body, so that I can fix a shared problem once and a Rogue-only problem separately.
25. As the owner, I want correctives included in the bake, so that the blade I see is still the blade that hits.
26. As the owner, I want to create a new keyed clip, or edit an existing one (the Mikiri stomp and pin), by posing IK targets on key frames, saved in the KeyedPose JSON the game already plays, so that I can author motions no pack has.
27. As the owner, I want to see a ghost of the uncorrected pose while I pose, so that I can judge how far I've moved from the clip.

### Refining with Claude

28. As the owner, I want a chat panel next to the editor where I type what's wrong ("the follow-through ends too early", "frames 12-18 the elbow pops"), so that I can hand a fix to Claude without explaining where the move lives.
29. As the owner, I want sending a prompt to create a new worktree on a new branch `anim/<move>-<slug>` from the commit the Studio is running on, so that each refinement is isolated and starts from what I was looking at.
30. As the owner, I want a warning when I have unsaved or uncommitted edits as I send, since the new worktree won't contain them, so that I'm not surprised.
31. As the owner, I want the new session to get the move's data (id, weapon, chain, speed, markers, frame data, and the files and lines it comes from), a screenshot of the editor at the current frame, and the frame or range I selected, so that Claude starts with full context.
32. As the owner, I want a terminal to open running Claude Code in that worktree with my prompt, so that I can carry on the conversation right away, or `/resume` it in the desktop app.
33. As the owner, I want the new session to follow CLAUDE.md and size the work: small tweaks straight to a branch and pull request, bigger changes through a spec and plan with me first, so that refinements follow the same rules as any other change.
34. As the owner, I want each animation to list the refinements sent for it (prompt, branch, worktree, pull request link once one exists), with buttons to reopen the terminal or open the folder, so that I can keep track of what's in flight.
35. As the owner, I want the new worktree ready to run the game (Godot path, packs path, node_modules and the clip libraries in place), so that the session can render and test without setup.

### Living with the lane

36. As the owner, I want the Studio kept in its own folder, touching the game's files only where it must, so that it carries over cleanly when `feature/authored-animation` merges into `feature/godot-rebuild`.
37. As the owner, I want the Studio to open on a fresh clone without the packs, showing the CC0 fallbacks with badges, so that it never breaks.

## Implementation Decisions

### Decisions in plain English

| Question | Decision | Why |
|---|---|---|
| Who it's for | The owner, on their own machine. A dev tool, never exported | It can read the licensed packs, write repo files and start Claude Code |
| Built in | A Godot tool scene, `game/tools/anim_studio/studio.tscn`, run with `node scripts/godot.mjs studio` | Plays clips through the game's real machinery, so what it shows is what a match shows. A browser page would be a second renderer that drifts |
| Base branch | `feature/authored-animation`; the pull request moves to `feature/godot-rebuild` once PR #12 merges | Only that branch has the clip system |
| What a tile is | What the game plays: the 70 moves by weapon, plus States and Ults, plus a Source clips tab of raw clips | You edit the move you see in a fight; the raw clips stay reachable |
| Editor scope (v1) | Timeline, markers, chains, frame data with overlays and a rules preview, bone posing (correctives and keyed clips) | The owner picked all three; compare views (side by side, before/after) are left for later |
| Bone posing output | Correctives on top of existing clips, and keyed clips in the existing KeyedPose JSON | Touch up pack clips, and author what no pack has |
| Corrective scope | Shared by both bodies, with an optional override for one body | The Rogue already drifts on some clips |
| Correctives and the bake | Baked in | Keeps "the weapon shown is the weapon that hits" |
| Frame data | Edited in place in `sim/moves/*.gd`, then the bake and tests rerun, with a balance-change badge | Fast to tune, but the owner is reminded that tests, docs and a soak are needed |
| State and ult timings | Moved from constants in `clip_director.gd` into `state_clips.json`, then editable | States get the same editor as moves |
| Saving hand edits | Held in memory with undo and redo; Save writes files into the checkout the Studio runs in, and the owner commits them the normal way | Simple; hand edits and chat refinements never collide |
| Chat handoff | New worktree and branch from the Studio's current HEAD, a context folder, and a terminal running `claude` | The desktop app has no supported way to open a session with a prompt; a CLI session can be resumed there |
| Chat context | Move data, a screenshot, the selected frame or range | The owner's pick; uncommitted edits are not sent, only warned about |
| Refinement size | The session sizes the work per CLAUDE.md | Small tweaks shouldn't need a spec |
| Refinement log | Per animation, in a gitignored file | Keeps track of what's in flight |

### Where it lives

Everything new goes in `game/tools/anim_studio/` (scenes, scripts, its own theme) and `game/tests/tools/anim_studio/`. The game's own files change only at these touch points, each kept small:

- `view/fighter/clip_director.gd`: reads state and ult timings from `state_clips.json` instead of constants, and applies correctives.
- `view/fighter/clip_correctives.gd` (new, in the game): loads correctives and adds them on top of a posed skeleton. It sits beside ClipDirector because matches play correctives too.
- `tools/clip_poser.gd` / `tools/swing_bake.gd`: apply correctives when sampling, so the bake sees them.
- `tools/build_keyed_clips.gd`: its build moves into a static function the Studio can call (the CLI is unchanged).
- The procedural layers (guard stance, foot lock, lean, body layer): an `enabled` flag where one is missing, on by default, so the editor can switch them off.
- `scripts/godot.mjs`: a `studio` command.
- `.gitignore`: the refinement log and the context folder.
- `GLOSSARY.md`: the new terms (see Further Notes).

### Catalogue

- The Studio builds its catalogue at start-up from the data the game reads: `move_clips.json` (moves, grouped by weapon, in the table's order), `state_clips.json` (states and ults), `clip_manifest.json` plus the UAL list plus the keyed library (source clips).
- Each entry knows its kind (move, state, ult, source), display name, id, the clips it plays, its data's file and location, and its badges: fallback, provisional, has correctives, unsaved, balance changed.
- Tiles are small SubViewports, each with one fighter, sharing the loaded clip libraries. Only tiles on screen tick; the rest freeze on their last frame. A gallery-wide Hunter/Rogue toggle picks the body.
- Without the packs, tiles play the fallbacks the game would play, with the fallback badge.

### Editor

- The viewport plays one fighter through ClipDirector as a match would. There are two timeline modes:
  - **Source frames:** the clip or chain at 30 fps.
  - **Rules frames:** the move at 60 a second after ClipTiming.
- Layers (guard stance, foot lock, lean, body layer) can be switched off.
- Overlays, each toggleable:
  - the frame-data bands under the timeline;
  - the markers above it;
  - the blade trail from the baked swing;
  - the strike segment and sweep on active frames;
  - reach;
  - lunge travel;
  - a ghost of the uncorrected pose while posing.
- The rules preview runs the move through the rules (the same sim the soak uses) against a standing dummy, and marks the frames that hit.
- **Marker editing** drags markers in source frames, written to `clip_manifest.json`. A move's per-move `marks` override is edited when the clip is viewed inside that move.
- **The chain panel** lists the parts, each with a clip picker (pack, UAL, keyed), a range, holds and a crossfade preview. It also holds the move's speed and sheathed frames. All of it is written to `move_clips.json` in the chain syntax ClipChain parses.
- **The frame-data panel** edits the move's numbers in `sim/moves/<weapon>.gd`. The rewriter finds that move's entry and replaces only the numbers that changed. If the entry isn't in the shape it expects, it refuses and says why rather than guess. It never reformats the file.
- **Undo and redo** cover every edit, across panels. The unsaved marker shows per animation and in the gallery.
- **Save** writes the changed files (JSON with the repo's stable key order and number format, as `js_format.gd` does), then bakes the affected weapon in-process with SwingBake.
  - If the bake refuses, the editor shows the mismatch (for example, "baked active 14-17, frame data 13-16"). It offers to set the frame data to match, or to undo the save; the files are not left half-written.
  - A save that changes frame data, reach or arc sets the balance-change badge on that move until the owner commits.

### Correctives

- A corrective belongs to one clip (not to a move), so every move that plays the clip gets it.
- It is stored in `game/assets/authored/correctives/<clip id>.json`, which is committed and CC0, since it holds only offsets the owner keyed. It contains:
  - a list of keys, each a frame (in the clip's source frames) and per-bone rotation offsets;
  - an interpolation mode;
  - ease-in and ease-out frames;
  - an optional per-body override block (`humanf`, `humanm`) that replaces the shared keys for the bones it names.
- At play time, ClipCorrectives adds the interpolated offset to each named bone after the clip is posed and before the procedural layers. It follows the clip's own retiming, so a corrective keyed at source frame 12 stays on the same motion however the move times it.
- With no corrective file, nothing changes: the pose is identical to today's.
- The bake samples with correctives applied, so a corrective that moves the weapon arm changes the baked swing. Saving one reruns the bake, and it can raise the balance-change badge.

### Keyed clips

- The Studio edits KeyedPose clips in their existing format (`assets/authored/keys/<id>.json`: per-frame IK targets for hips, spine, legs and arms) and rebuilds `keyed_library.tres` with `build_keyed_clips.gd` on save.
- Posing a keyed clip uses the IK handles; KeyedPose solves the pose live as handles move.
- New keyed clips appear in the Source clips tab and in the chain panel's clip picker as soon as they are saved.

### States and ults on data

- The constants in `clip_director.gd` move, unchanged in value, into `game/assets/kevin_iglesias/state_clips.json`:
  - IDLE per weapon;
  - HIT_CLIPS, GUARD_CLIPS, STUN_CLIP and STUN_CLIPS;
  - REBOUND, CARRY_POSE and STATE_CLIPS;
  - ULT_CLIPS and the IMPALER and TEMPEST timings.
- ClipDirector reads that file, which can be edited like a move.
- This is the one refactor of game code in the feature. A test checks the file reproduces the old constants exactly, so matches play the same.

### Chat panel and refinements

- **The panel:** a prompt box, the selected frame or range (dragged on the timeline), and the animation's refinement log.
- **On send:**
  1. **Check.** If the animation has unsaved edits, or the checkout has uncommitted changes, warn: the worktree starts from the last commit. Send or cancel.
  2. **Name.** The branch is `anim/<animation id>-<slug from the prompt>`, made unique with a number if taken. The worktree is `.claude/worktrees/anim-<animation id>-<slug>`.
  3. **Create.** `git worktree add -b <branch> <path> HEAD`, run from the Studio's checkout.
  4. **Make it runnable.**
     - Copy `.godot-path` and `.assets-src-path` into the worktree.
     - Junction `node_modules` from the main checkout.
     - Copy the built clip libraries (`iglesias_human{m,f}.res`), which are gitignored, so the session can render without re-importing the packs.
  5. **Context folder.** Write `.anim-refine/` in the worktree root (gitignored):
     - `prompt.md`: the owner's words, which animation, the frame or range, the base branch, and the instructions below;
     - `animation.json`: the animation's data and the files and lines it comes from;
     - `screenshot.png`: the editor viewport at the current frame.
  6. **Launch.** Open a new terminal window in the worktree running `claude` with a short first message telling it to read `.anim-refine/prompt.md` and follow it. The real prompt lives in the file, so Windows quoting can't mangle it.
  7. **Log.** Add the refinement to the animation's log.
- **The instructions in `prompt.md`:**
  - follow CLAUDE.md;
  - size the work: a tuning or touch-up goes straight to a pull request; a new clip, a re-chained move or a new system gets a spec and plan, with the owner's OK first;
  - open the pull request against the branch the Studio was on;
  - never commit `.anim-refine/` or anything from the Iglesias packs;
  - balance changes need their tests and `docs/mvp-spec.md` updated.
- **The log** lives in `game/tools/anim_studio/.refinements.json` (gitignored). Each entry holds the prompt, branch, worktree, time, and the pull request URL once one exists. The Studio looks this up with `gh pr list --head <branch>` when the log is opened, and caches it. The buttons are: open the terminal again (a fresh `claude --continue` in the worktree) and open the folder.
- The Studio never deletes worktrees or branches. Cleaning up after a merge stays the owner's call.

### Carrying over to `feature/godot-rebuild`

The Studio has no dependencies outside the clip system. When PR #12 merges, this branch takes the merge, its pull request is retargeted to `feature/godot-rebuild`, and the tests run again. The touch points listed above are the only places a merge can conflict. `clip_director.gd` is the likeliest, since the authored-animation lane is still changing it (tasks 28-36), so the state-clips refactor lands as one small, early task that is easy to redo.

## Testing Decisions

Good tests here check what the Studio reads and writes, and that the game plays the same, not how the UI is laid out. They run under GUT with `node scripts/godot.mjs test` (inside `npm test`), headless, without the packs.

- **Catalogue:**
  - every move in `move_clips.json` appears exactly once, under its weapon, in table order;
  - every state and ult in `state_clips.json` appears;
  - source clips list the manifest, UAL and keyed clips;
  - badges follow the data (fallback when packs are forced missing with `ClipLibraries.force_missing`, provisional from the manifest).
- **Round trips:** loading and saving `clip_manifest.json`, `move_clips.json`, `state_clips.json`, a corrective and a keyed clip with no edits gives identical bytes; one edit changes only that value.
- **Chain editing:** each chain the panel can build is parsed back by ClipChain into the same parts (ranges, holds, `ual/` ids).
- **Frame-data rewriter:**
  - editing one number in a copy of `katana.gd` changes only that number;
  - an entry in an unexpected shape is refused with a reason;
  - the edited file still loads and its moves match the expected values.
- **States on data:** `state_clips.json` reproduces the old ClipDirector constants exactly. A short scripted match plays the same poses before and after the refactor (compare sampled bone transforms).
- **Correctives:**
  - no corrective leaves the pose bit-for-bit unchanged;
  - a single key offsets only its bone, by its amount, at its frame;
  - interpolation and easing between keys;
  - a body override replaces the shared key for that body only;
  - the corrective follows ClipTiming's retiming.
- **Bake with correctives:** a corrective on the weapon arm changes the baked right-hand track, and an empty one leaves `swings/<weapon>.json` unchanged.
- **Undo and redo:** a sequence of edits across panels undoes and redoes to identical data.
- **Refinements:** process launching sits behind a small interface that the tests fake. Tests check:
  - branch and worktree naming, including uniqueness;
  - the commands issued, in order;
  - the content of `prompt.md` and `animation.json`;
  - the unsaved/uncommitted warning;
  - the log entry.
- **Smoke:** the Studio scene loads headless, builds the catalogue and opens the editor on one move of each kind, with no script errors.

Manual checks (shots with `godot.mjs shots`, and an owner review) cover how the gallery and editor look and feel, and one real refinement end to end.

## Out of Scope

- Compare views: Hunter and Rogue side by side, before/after against git HEAD, onion skin. They come later.
- Sending uncommitted edits as a patch with a refinement.
- Editing locomotion blending (`locomotion.gd`) and the procedural layers' settings. Locomotion clips are in the gallery, and correctives work on them.
- Importing new clips from the packs (the existing `godot.mjs clips` flow stays).
- Chat inside the page: the conversation happens in Claude Code, not in the Studio.
- Cleaning up worktrees and branches after a refinement merges.
- Running on anything but the owner's Windows machine.
- Shipping the Studio in the game or exposing it to players or modders.

## Further Notes

### New glossary terms

- **Animation Studio**: the dev tool described here: gallery, editor and chat panel.
- **Corrective**: per-bone rotation offsets keyed on top of a clip, shared by both bodies or overridden for one, and baked into the swing. _Avoid_: additive, fix layer.
- **Refinement**: a change to one animation asked for in the Studio's chat panel, worked on in its own worktree and branch. _Avoid_: request, job.

### Where this differs from `docs/specs/authored-animation.md`

- That spec retired the swing editor along with the hand-keyed swings. The Studio is a new editor, but for clips, chains and correctives, not for hand-keyed weapon paths. Swings are still only ever baked from clips.
- It adds correctives, a new layer between the clip and the procedural layers, and the bake includes them.
- It moves ClipDirector's state and ult constants into `state_clips.json` (values unchanged).

### Where this differs from `docs/design.md` and `docs/mvp-spec.md`

Neither covers dev tools, and the Studio changes no game rule. Frame-data edits made with it are ordinary tuning changes and update `docs/mvp-spec.md` in their own commits, as CLAUDE.md asks.

### Licence

- The Studio renders the Iglesias clips locally, as the game does.
- Screenshots in `.anim-refine/` are gitignored.
- Refinement sessions are told never to commit them or any pack file.
- Correctives and keyed clips hold only the owner's own keys, so they are committed as CC0.

### Risks

- **Merge churn with the authored-animation lane.** `clip_director.gd` and the bake are still changing. Keeping the touch points small, landing the state-clips refactor early, and merging the lane in often keeps this cheap.
- **Gallery performance.** 100+ live SubViewports is too many. Ticking only visible tiles at a low resolution should hold; if not, tiles show a still until hovered.
- **The frame-data rewriter.** Rewriting GDScript source is fragile. It edits only numbers in an entry shape it recognises, and refuses anything else.
- **Bone posing UI is the largest piece.** Gizmos, IK handles and key interpolation are a lot of UI for Godot Controls. The plan should land it last, after the gallery, editor and chat panel work, so the rest is usable early.
- **Worktree setup.** A new worktree lacks gitignored files. The Studio copies what the game needs, and the session's first step is to check that the game launches.
