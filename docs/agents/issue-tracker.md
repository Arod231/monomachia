# Issue tracker: local Markdown in docs/

Specs, plans and decision maps for this repo live as Markdown files in `docs/`, on the feature branch, so they arrive in the same pull request as the code (see CLAUDE.md, "Building major features").

## Conventions

- **Spec:** `docs/specs/<feature>.md`.
- **Plan:** `docs/plans/<feature>.md`, a list of small tasks with checkboxes, ticked off as they are done. Each task says what it delivers, what blocks it and how it is checked.
- **Decision records:** architecture decisions that are hard to reverse go in `docs/adr/NNNN-<slug>.md`.

## Blockers

The owner launches sessions that each take a batch of tasks in order (x, then y, then z) from the Project Manager board, and runs several at once. A batch can only start if its first task's blockers are done, so a false blocker idles a whole session. A task's "Blocked by" line is therefore exact:

- **Real needs only.** Name every task whose result this task uses (code, data, a test, a clip, an event it listens for), even when another blocker implies it, and no other. Ask of each blocker: "what does this task use from it?" If there's no answer, drop it.
- **Order isn't a need.** Coming later in the build order, the same stage or the same family is not a reason to block. The stages are a reading order; the board runs on the Blocked by lines.
- **Gates are written as gates.** An owner's decision to hold work back (a review, an approval, a "one family at a time" order) is written `N (and the owner's OK)` and gates only the work the decision is about, never unrelated systems that happen to sit near it in the plan.
- **Shared files aren't blockers.** Two tasks that edit the same files without using each other's result go to one lane, in order (say so in the plan's Notes), rather than blocking one on the other.
- **Dropping a blocker.** A later task that reached a gate only through the dropped blocker names that gate itself.

After drafting or changing a plan, check every Blocked by line against these rules, then list the frontier (the tasks that can start now) and the batches that could run side by side, each starting on a frontier task. The Project Manager finds the same batches live (`findBatches` in `tools/lanes-board/plans.mjs`): each starts on a task that can start (ready, or waiting only on the owner's OK, which launching gives) and takes, in build order, the tasks whose every blocker is done or earlier in the batch and that use the task just before (a chain: tasks that only share an earlier task fan out into sessions of their own once it lands), stopping before a review gate or other owner task and before any task gated on the owner's OK of a task in the batch; each task belongs to one batch. It draws them in pink.

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
