# Issue tracker: local Markdown in docs/

Specs, plans and decision maps for this repo live as Markdown files in `docs/`, on the feature branch, so they arrive in the same pull request as the code (see CLAUDE.md, "Building major features").

## Conventions

- **Spec:** `docs/specs/<feature>.md`.
- **Plan:** `docs/plans/<feature>.md`, a list of small tasks with checkboxes, ticked off as they are done. Each task says what it delivers, what blocks it and how it is checked.
- **Decision records:** architecture decisions that are hard to reverse go in `docs/adr/NNNN-<slug>.md`.

## When a skill says "publish to the issue tracker"

Write or update the matching file under `docs/specs/` or `docs/plans/` on the current feature branch.

## When a skill says "fetch the relevant ticket"

Read the plan file and find the task by its number or title.

## Wayfinding operations

Used by `/wayfinder`. For an effort too big for one plan file, the **map** is `docs/plans/<effort>/map.md` (Destination, Notes, Decisions so far, Not yet specified, Out of scope), with one file per decision ticket at `docs/plans/<effort>/issues/NN-<slug>.md`.

- Each ticket has a `Type:` line (`research`, `prototype`, `grilling`, `task`), a `Status:` line (`open`, `claimed`, `resolved`) and a `Blocked by: NN, NN` line.
- **Frontier:** tickets that are open, unclaimed and whose blockers are all resolved; the lowest number goes first.
- **Claim:** set `Status: claimed` before any work.
- **Resolve:** append the answer under `## Answer`, set `Status: resolved`, and add a one-line pointer to the map's "Decisions so far".
