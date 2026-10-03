# Domain docs

This repo has a single context.

- `GLOSSARY.md` at the repo root holds the game's vocabulary (Fighter, Weapon, Loadout, Posture, Parry, and so on). Use its terms in specs, plans, code names and commit messages, and avoid the words it lists under _Avoid_.
- `docs/adr/` holds architecture decision records, numbered `0001-<slug>.md` upward. Read the ADRs in the area you are touching before changing it, and don't reverse one without writing a new ADR that supersedes it.
- `docs/design.md` is the vision for the finished game; `docs/specs/` and `docs/mvp-spec.md` record what is actually built.

When a new term settles during design work, add it to `GLOSSARY.md` at once, with no implementation details.
