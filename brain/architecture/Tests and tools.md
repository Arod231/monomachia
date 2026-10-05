---
tags: [architecture, tools]
---

# Tests and tools

Node is the task runner; every Godot command goes through `scripts/godot.mjs`, which finds Godot (via `GODOT`, the PATH, or a local `.godot-path` file) and watches for script errors.

| Command | What it does |
|---|---|
| `npm test` | The Node tests on Node's own runner (`npm run test:node`), then the GUT tests headless (`npm run test:godot`, about 1,800) |
| `npm run typecheck` | Every GDScript file loaded and checked |
| `npm run soak` | Computer-vs-computer matches with balance numbers (round length, disarms per round, win rates) |
| `npm run soak:tune` | A 300-match tuning run |
| `npm run counterlab` | How often the computer lands each unblockable's counter |
| `npm run shots` | Renders a scene to a PNG, failing on shader or script errors |
| `npm run play` | Plays the game (`-- --swing-debug` shows the swing debug view) |
| `npm run dev` | Opens the editor |
| `npm run studio` | Opens the Animation Studio |
| `npm run build` | Exports the Windows build, with the licence, credits and notices beside the exe |
| `npm run release -- <tag>` | On the PC with the clip libraries: exports, checks with `--smoke`, zips and attaches the build to the tag's GitHub release |
| `npm run check:sizes` | Keeps files over 10 MB out of the repo |
| `npm run brain` | Writes this vault's generated notes (see [[About this vault]]) |

- **Tests** ([[game.tests]]): rules tests drive the [[Rules layer]] with no graphics; content tests measure the fighters' bodies and the weapons' markers; view tests render scenes headless. Changing combat rules or tuning means adding or updating a test.
- **Tools** ([[game.tools]]): headless soak and counterlab runners, the swing editor, and shot scenes ([[game.tools.shot_scenes]]) for screenshots in reviews.
- Balance targets for the soak runs are in the rebuild spec's testing decisions, and [[Task 12.1]] built the soak that reports them. Since Oct 4, tuning toward them is milestone-1 work, with rounds of about 60–90 s.

**Sources:** [[Rebuild spec - Testing Decisions]] · [[README - Build and develop]] · see [[Workflow]]
