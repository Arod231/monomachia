# Monomachia

A one-on-one weapon duel in the browser, built with three.js, TypeScript and Vite. See README.md for the game design, controls and folder layout.

## Design documents

Read these before changing gameplay or planning new features:

- `docs/design.md`: the full game design document, the vision for the finished game (all 9 weapons, arenas, progression, online play).
- `docs/mvp-spec.md`: the MVP plan and spec, what the current demo builds and how. Its "Decisions", "Scope" and "Gaps in the design doc" tables record the choices made so far, and its combat numbers match the code.
- `docs/architecture.md`: a map of the code with diagrams: the folders, how one frame flows through the Godot game, the rules, the view, tests and tools. Start here when new to the code, and update it when a change moves a boundary it describes.

- `GLOSSARY.md`: the game's vocabulary (Fighter, Weapon, Loadout and so on). Use its terms.

When building toward the full game, use `docs/design.md` for what to build and `docs/mvp-spec.md` for how the existing systems work. If a change contradicts either doc (for example, new tuning numbers or a different answer to a "Gaps" question), update the doc in the same branch.

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
2. Commit often: after each finished step (the spec, the plan, each task, each fix), not just at the end. Before each commit, run `npm test` and `npm run typecheck`. If either fails, fix it before committing. If you can't fix it, tell me and don't push.
3. Write a clear commit message that says what changed and why (for example, "Shorten greatsword heavy startup by 4 frames").
4. Push the branch to `origin` after every commit so GitHub always has the latest work.
5. Open a pull request against `master` with `gh pr create` once the first commit is pushed (keep it as a draft while the work is still in progress). The description says what changed, why, and how it was tested. Later commits update the same pull request.
6. When the work is done, mark the pull request ready, tell me in one line what's in it with its link, and ask me to approve it.
7. Only after I approve: bring the branch up to date with `master`, rerun the tests, push, then merge the pull request with `gh pr merge --merge --delete-branch`. Update local `master` (`git checkout master` and `git pull origin master`) and delete the local branch.
8. Tell me in one line what you merged.

Rules:
- Never commit secrets, API keys, tokens or passwords. Never commit anything that `.gitignore` excludes (node_modules, dist, shots, coverage, logs).
- Never force-push or rewrite history on `master`.
- Never merge a pull request or turn on auto-merge without my approval. Approval of one pull request doesn't cover the next. Ask again for each one.
- If a push is rejected because GitHub has newer commits, run `git pull --rebase origin <branch>`, rerun the tests, then push again.
- If I say "don't push" or "just try something", commit locally on the branch or leave the change uncommitted, whichever I ask for, and don't push.

## Commands

- `npm install`: install dependencies (Node 22.12+)
- `npm run dev`: dev server at http://localhost:5173
- `npm test`: combat rule tests (Vitest, no graphics)
- `npm run typecheck`: TypeScript check
- `npm run build`: type-check, then build the single-file game
- `npm run soak -- 40`: 40 computer-vs-computer matches, prints balance numbers

## Code notes

- `src/sim` holds the rules with no graphics, stepped at a fixed 60 per second. Keep rendering, input and audio code out of it.
- Weapon frame data lives in `src/sim/moves`. Global tuning lives in `src/sim/constants.ts`.
- When you change combat rules or tuning, add or update a test in `tests/`.
