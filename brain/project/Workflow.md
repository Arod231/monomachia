---
tags: [project, process]
---

# Workflow

How changes are made, from the repo's `CLAUDE.md`.

## Major features: spec, then plan, then implement

A major feature is anything bigger than a tuning tweak or a small fix: a new weapon, arena, mode, system or large refactor.

1. **Spec, what we're building:** settle the open questions, then write `docs/specs/<feature>.md`, checked against the [[Design doc]] and the [[MVP spec]].
2. **Plan, how we'll build it:** small tasks, each finishable and testable on its own, in `docs/plans/<feature>.md`.
3. **Implement, task by task:** tests first, then code, then review, ticking tasks off in the plan.

The owner OKs the spec and the plan before the next stage starts. Small changes (tuning, fixes, doc edits) skip straight to a branch and a pull request.

## Every change reaches GitHub through a pull request

- A branch per change, from an up-to-date base, never committing straight to the main branch.
- Commit after each finished step, running `npm test` and `npm run typecheck` first; push after every commit.
- A draft pull request after the first push, marked ready when done; the owner approves each one before it merges.
- No secrets, nothing `.gitignore` excludes, no force-pushing the main branch.

## Rules for the code

- Keep rendering, input and audio out of the rules ([[Rules layer]]).
- When combat rules or tuning change, add or update a test, and update the docs if they disagree ([[Tests and tools]], [[Move data]]).

How several pieces of work run at once: [[Lanes and the board]].
