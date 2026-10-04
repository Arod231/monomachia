---
tags: [architecture, tools]
---

# Tests and tools

Node is the task runner; every Godot command goes through `scripts/godot.mjs`, which finds Godot (via `GODOT`, the PATH, or a local `.godot-path` file) and watches for script errors.

| Command | What it does |
|---|---|
| `npm test` | The web demo's Vitest tests, the Node tests on Node's own runner (`node --test`), then the GUT tests headless (about 1,800) |
| `npm run typecheck` | TypeScript, then every GDScript file loaded and checked |
| `npm run soak:godot` | Computer-vs-computer matches with balance numbers (round length, disarms per round, win rates) |
| `npm run soak:tune` | A 300-match tuning run |
| `npm run shots` | Renders a scene to a PNG, failing on shader or script errors |
| `npm run godot:run` | Plays the game (`-- --swing-debug` shows the swing debug view) |
| `npm run godot:dev` | Opens the editor |
| `npm run check:sizes` | Keeps files over 10 MB out of the repo |
| `npm run brain` | Writes this vault's generated notes (see [[About this vault]]) |

- **Tests** ([[game.tests]]): rules tests drive the [[Rules layer]] with no graphics; content tests measure the fighters' bodies and the weapons' markers; view tests render scenes headless. Changing combat rules or tuning means adding or updating a test.
- **Tools** ([[game.tools]]): headless soak and counterlab runners, the swing editor, and shot scenes ([[game.tools.shot_scenes]]) for screenshots in reviews.
- Balance targets for the soak runs are in the rebuild spec's testing decisions, and [[Task 12.1]] built the soak that reports them. Since Oct 4, tuning toward them is milestone-1 work, with rounds of about 60–90 s.

**Sources:** [[Rebuild spec - Testing Decisions]] · [[README - Build and develop]] · see [[Workflow]]
