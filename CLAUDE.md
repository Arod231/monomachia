# Monomachia

A one-on-one weapon duel for Windows, built in Godot 4.7 with typed GDScript. It began as a three.js browser demo, kept at the tag `v0.1-web-mvp`. See README.md for how a fight works, the controls and the folder layout.

## Design documents

Read these before changing gameplay or planning new features:

- `docs/design.md`: the full game design document, the vision for the finished game (all 9 weapons, arenas, progression, online play). Its "(Oct 4)" lines set the current direction: animation leads the rules' timing, a realistic look replaces the toon and ink-wash style, an RTX 3090 is the target, and the existing content reaches final quality before new content.
- `docs/adr/0001-animation-leads-realistic-look.md`: why that direction was taken. Where an older spec or plan section carries a "Superseded by ADR 0001" note, follow `docs/design.md` and the ADR, not that section.
- `docs/specs/milestone-1.md`: the current milestone, the Hunter with the Katana and bare hands on the Moonlit Shrine at final quality; its plan is `docs/plans/milestone-1.md`.
- `docs/plans/roadmap.md`: the order of the work from the consolidation to online play, in six phases, pointing at each phase's plan.
- `docs/mvp-spec.md`: the MVP plan and spec, the record of the original web demo. Its "Decisions", "Scope" and "Gaps in the design doc" tables record the choices it made; the Godot game's rules and numbers have moved on (see `docs/specs/`).
- `docs/architecture.md`: a map of the code with diagrams: the folders, how one frame flows through the Godot game, the rules, the view, tests and tools. Start here when new to the code, and update it when a change moves a boundary it describes.

- `GLOSSARY.md`: the game's vocabulary (Fighter, Weapon, Loadout and so on). Use its terms.

When building toward the full game, use `docs/design.md` for what to build, and the specs in `docs/specs/` (the game as built is `godot-rebuild.md`, with milestone 1's and the animation specs' changes) and `docs/architecture.md` for how the existing systems work. If a change contradicts one of them (for example, new tuning numbers or a different answer to an open design question), update that doc in the same branch.

## Building major features: spec, then plan, then implement

A major feature is anything bigger than a tuning tweak or a small fix: a new weapon, arena, game mode, system (progression, online play) or a large refactor. For these, work in three stages, in order, and don't skip ahead:

1. **Spec: what we're building.** Interview me until the open questions are settled (use `/grill-me`, or `/grill-with-docs` when the answers should also update the design docs), then write the spec with `/to-spec`. Save it as `docs/specs/<feature>.md`. Check it against `docs/design.md` and `docs/mvp-spec.md`, and note any place it differs from them.
2. **Plan: how we'll build it.** Turn the approved spec into a step-by-step plan of small tasks with `/to-tickets` (use `/wayfinder` for very large features such as online play). Save it as `docs/plans/<feature>.md`. Each task should be small enough to finish and test on its own.
3. **Implement: build it task by task.** Work through the plan with `/implement` (tests first, then code, then review), or `/implement-spec` when tasks can safely run in parallel. Use `/prototype` to answer design questions with throwaway code, and `diagnosing-bugs` for hard bugs. Tick off tasks in the plan file as they're done.

After the spec and after the plan, show me a short summary and wait for my OK before starting the next stage. The spec, the plan and the code all go on the feature's branch (see below), so they arrive in one pull request.

Small changes (tuning, bug fixes, doc edits) skip the spec and plan and go straight to a branch and pull request.

## Agent skills

### Issue tracker

Local Markdown in `docs/`: specs in `docs/specs/`, plans and wayfinder maps in `docs/plans/`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single context: `GLOSSARY.md` at the root and ADRs in `docs/adr/`. See `docs/agents/domain.md`.

## Publishing every change to GitHub

This repo is public at https://github.com/Arod231/monomachia. The main branch is `master`.

Every change goes on its own branch and reaches `master` only through a pull request that I approve.

For each change:

1. Before editing, create a new branch from an up-to-date `master` with a short descriptive name (for example, `feature/spear-weapon`, `tune/greatsword-heavy-startup` or `docs/controls`). Never commit directly to `master`.
2. Commit often: after each finished step (the spec, the plan, each task, each fix), not just at the end. Before each commit, run `npm test` and `npm run typecheck`; a branch that changes only docs or the Node tools (the lanes board, the second brain) runs `npm run test:node` instead. If a check fails, fix it before committing. If you can't fix it, tell me and don't push.
3. Write a clear commit message that says what changed and why (for example, "Shorten greatsword heavy startup by 4 frames").
4. Push the branch to `origin` after every commit so GitHub always has the latest work.
5. Open a pull request against `master` with `gh pr create` once the first commit is pushed (keep it as a draft while the work is still in progress). The description says what changed, why, and how it was tested. Later commits update the same pull request.
6. When the work is done, mark the pull request ready, tell me in one line what's in it with its link, and ask me to approve it.
7. Only after I approve: bring the branch up to date with `master`, rerun the tests, push, then merge the pull request with `gh pr merge --merge --delete-branch`. Update local `master` (`git checkout master` and `git pull origin master`) and delete the local branch.
8. Tell me in one line what you merged.

Rules:
- Never commit secrets, API keys, tokens or passwords. Never commit anything that `.gitignore` excludes (shots, build, logs, `game/.godot`, the clip libraries).
- Never commit paid assets (the Kevin Iglesias packs or anything bought), or files converted from them. They live in the private asset repository, which the import tools read through `.assets-src-path`; numbers measured from them (frame data, hit paths, travel) may be committed with their source clip recorded.
- Visual work (a look, an animation, an arena, an effect, a screen) posts a shot or a clip of it, with a one-line caption, to its session's page in the Project Manager at each finished step, and whenever I ask to be shown (Show me): `npm run shots` or `npm run clip` into `shots/`, then `npm run post`. Shots and clips go nowhere else and are never committed, since renders can show paid assets.
- Never force-push or rewrite history on `master`.
- Never merge a pull request or turn on auto-merge without my approval. Approval of one pull request doesn't cover the next. Ask again for each one.
- When I press Merge on a session's page in the Project Manager, that is my approval for that pull request: the Project Manager merges it on GitHub (merge commit, remote branch deleted) and tells the session, which then brings its local base up to date and deletes its local branch, with no second approval.
- If a push is rejected because GitHub has newer commits, run `git pull --rebase origin <branch>`, rerun the tests, then push again.
- If I say "don't push" or "just try something", commit locally on the branch or leave the change uncommitted, whichever I ask for, and don't push.

## Setup

- Godot 4.7.2 (standard build) and Node 22.12+. npm is only the task runner: it has no dependencies, and every Godot command goes through `scripts/godot.mjs`, which finds Godot through the `GODOT` environment variable, `godot` or `godot4` on PATH, or an untracked `.godot-path` file holding the executable's path (on Windows, the `*_console.exe`).
- The licensed animation clips live in the private asset repository (github.com/Arod231/monomachia-assets). Put the path of its clone in an untracked `.assets-src-path` file at the repo root (a worktree reads the main checkout's), then run `npm run godot -- clips` to build the clip libraries into `game/assets/kevin_iglesias/library/`. Without them the game plays labelled CC0 stand-ins, on which the weapons float off the hands, and the `test_local_` tests skip. Playtests and releases always use the clips.
- `npm run build` needs Godot's 4.7.2 export templates.

## Commands

- `npm test`: the Node tools' tests (`npm run test:node`, on `node --test`), then the GUT tests headless (`npm run test:godot`, about 5 minutes)
- `npm run typecheck`: loads every GDScript file; fails on parse or type errors
- `npm run soak -- 40`: 40 computer-vs-computer matches, prints balance numbers (`npm run soak:tune` runs 300); `npm run counterlab` measures how often the computer lands each unblockable's counter
- `npm run play`: plays the game (`-- --swing-debug` draws the blade sweeps and hurt capsules); `npm run dev` opens the editor; `npm run studio` opens the Animation Studio
- `npm run shots -- res://tools/shot_scenes/<scene>.tscn shots/<name>.png`: renders a scene to a PNG in an off-screen window, failing on shader or script errors
- `npm run clip -- <scene> [--seconds N] [scene args]`: records a scene the shots tool runs as a looping MP4 (30 fps, 1280×720, no sound; 6 seconds unless asked, 20 at most) and a still into `shots/`, with Godot's Movie Maker and ffmpeg
- `npm run post -- <files> [--caption "…"] [--task <ref>]`: publishes shots and clips to this session's page in the Project Manager (`--session <id>` when run outside a session), converting other video (AVI, MOV, WebM) to MP4; the media stays in `~/.claude/lanes-board/media/` for 30 days
- `npm run build`: exports `build/windows/Monomachia.exe` with the licence, credits and notices beside it; the exe's `--smoke` flag plays a Watch match to the results and exits 0
- `npm run release -- v<version>`: on the PC with the clips, exports, runs `--smoke`, zips and attaches the build to that tag's GitHub release as a draft; publishing stays my click
- `npm run check:sizes`: fails on tracked files over 10 MB, or when the committed game art passes 150 MB or the audio 40 MB (the asset repository checks its own budgets with its `tools/check-budgets.mjs`)
- `npm run checklist`: after a test run, writes the results of the checks that go move by move into the per-move checklist, `docs/reviews/milestone-1-checklist.md` (the owner's columns are ticked by hand)
- `npm run export`: the Blender export, the only way art reaches the game: Blender run headless over each source the asset repository's `blender/sources.json` lists, one GLB per source in its `exports/` with a record of its source beside it, and self-made or CC0 models copied into `game/assets/` inside the art budget (`-- --check` writes nothing and fails on a change; finds Blender through `BLENDER`, the PATH, an untracked `.blender-path` file or Program Files)
- `npm run godot -- help`: the runner's other commands (`clips`, `bake`, `import`, `script`)
- `npm run brain`: write the second brain's generated notes to `brain/generated/` (not committed); `npm run brain:serve` shows the vault at http://localhost:5196
- `npm run board`: the Project Manager (the lanes board) at http://localhost:5197, live progress of every plan and worktree; the Roadmap tab is the default view and each session shows its context fill. Right-click a task to queue and launch it into its own session, or to end a launched session's work. Its "New session" button (in the header, and on the phone's Launch tab) starts a session with no tasks on the latest master, for prompting from the Claude app over Remote Control. Its Graph tab shows each plan's tasks as a dependency graph (queue, launch and end from there too); its Sessions tab shows every Claude session of the last three days, each with a page of its state, commands (Approve & continue, Show me, Merge, Compact, Stop now, End work), posted shots and clips, images of the work, documents, pull request and artifacts; its bell lists what happened while I was elsewhere; and while its Away switch is on, every session's permission prompts, plans and turn ends wait in its Questions tab, answered from the phone or the PC (through `tools/lanes-board/relay-hook.mjs`, installed in user settings). Questions (AskUserQuestion) always stay in the app; the bell only says that a session is waiting on you to answer them. It also listens on this PC's Tailscale address (never the LAN) and serves phones `tools/lanes-board/m.html`; `LANES_LOCAL_ONLY=1` turns that off
- `npm run board:hooks`: installs the Project Manager's hooks in user settings (only with my OK); `-- --check` says whether the installed ones are current, `-- --dry-run` what an install would change

## Code notes

- `game/sim` holds the rules with no nodes, rendering, input or sound, stepped at a fixed 60 per second. Keep it deterministic: use `Rng`, `V3`, `JsMath` and `SimMath` in place of Godot's `randf()`, `Vector3` and maths functions.
- Weapon frame data lives in `game/sim/moves/<weapon>.gd`, and each move's baked hit path in `game/sim/moves/swings/<weapon>.json` (`npm run godot -- bake` writes them from the clips in `game/view/fighter/move_clips.gd`). Global tuning lives in `game/sim/constants.gd` (`SimConst`).
- When you change combat rules or tuning, add or update a GUT test in `game/tests/` (`<area>/test_*.gd`). The Node tools' tests are `tests/*.test.mjs`.
- A Godot test run rewrites `game/default_bus_layout.tres`: revert that change rather than committing it.
- `brain/` is an Obsidian vault (the second brain). Hand-written notes link with `[[Note name]]`, must not reuse a generated name (glossary terms, `Task 7.1`, `Stage N - …`, `game.sim`, `<Doc> - <Section>`), and must keep every link resolving: `tests/second-brain.test.mjs` fails otherwise. When a concept a note explains changes, update the note in the same branch. Never edit or commit `brain/generated/`.
