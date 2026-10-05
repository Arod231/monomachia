# Plan: the second brain

Spec: `docs/specs/second-brain.md`. Branch `tools/second-brain`, PR into `feature/godot-rebuild` (Arod231/monomachia#18).

Each task is finished, tested (`npm test`, `npm run typecheck`), committed and pushed on its own.

## Tasks

- [x] **SB.1 Parsers.** `tools/second-brain/vault.mjs` with `safeName`, `taskIdsInSubject`, `parseGlossary`, `splitSections`, `parseScriptSummary`, `parsePlan` (tasks with done marks, text, "Blocked by" ids, stages from the build order with ranges expanded).
  - Check: `tests/second-brain.test.mjs` covers each parser on fixture text, including `(godot-rebuild 22.6, 22.8-22.10, first step)` and the `16.1–16.7` en-dash ranges.
  - Blocked by: none.
- [x] **SB.2 The vault builder.** `buildVault(source)` returns the hand-written notes under `brain/` and the generated glossary, plan (stages and tasks with Blocks), docs sections and code-map notes, with unique safe names; `linksIn` and `resolveLinks` find wikilinks and their targets.
  - Check: an in-memory source builds the expected notes; a task links its blockers, the tasks it blocks, its stage and the code folders whose commits name it; no generated link is unresolved.
  - Blocked by: SB.1.
- [x] **SB.3 Sources and `npm run brain`.** `sources.mjs` with `fsSource(dir)` and `gitSource(repo, ref)`; `build.mjs` writes `brain/generated/`; `brain/generated/` git-ignored; `npm run brain` script.
  - Check: `fsSource` and `gitSource('HEAD')` list and read the same tracked doc; `npm run brain` writes notes and a rerun changes nothing.
  - Blocked by: SB.2.
- [x] **SB.4 Hand-written notes.** `brain/Home.md` and the concept notes: weapons (Katana, Greatsword, Twin Daggers, Bare hands, the planned five), fighters, posture, parry, clash, disarm, strings, ultimates, the round and match flow, arenas, modes, the computer opponent, architecture (sim/view split, golden replays, swings), sound, the HUD and menus, the rebuild and its decisions; `.obsidian/app.json` with sensible defaults.
  - Check: the whole-vault test (real working tree) finds no broken link and no duplicate name.
  - Blocked by: SB.3.
- [x] **SB.5 Viewer and standalone server.** `serve.mjs` (`brainHandler`, port 5196) and `viewer.html` with vendored `marked.min.js`: folder tree, search, rendered notes with wikilinks, unresolved links struck through, "Linked from", URL hash navigation, "Open in Obsidian".
  - Check: `brainHandler` serves the page and `notes.json` (test); by hand in the Browser pane, links, back and search work.
  - Blocked by: SB.3.
- [x] **SB.6 Graph.** A canvas force-directed graph in the viewer: the open note's neighbours, or the whole vault; click a node to open it.
  - Check: by hand, both graphs draw and clicking opens the note.
  - Blocked by: SB.5.
- [ ] **SB.7 The board's button and routes (local, untracked).** A "Second brain" header button opening `/brain/` in a named popup; `/brain/*` served by `brainHandler` loaded from the newest ref holding `brain/Home.md`.
  - Check: by hand on http://localhost:5197, the button opens the popup, a second click reuses it, and plan ticks match the board.
  - Status: drafted and tested on a copy of the board at port 5195 (`docs/plans/second-brain-board-patch.md`). This session can't write to the board's worktree, so the board's own session applies it and restarts the board.
  - Blocked by: SB.5.
- [x] **SB.8 Docs.** README and CLAUDE.md name `npm run brain`, the viewer and the vault's rules (hand-written notes in `brain/`, generated ones never committed).
  - Check: the commands in the docs run.
  - Blocked by: SB.4, SB.6.
