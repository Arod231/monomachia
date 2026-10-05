---
tags: [architecture]
---

# Move data

Each weapon's moves are a table of numbers in its own data file ([[game.sim.moves]]), with shared defaults applied at load, as in the demo. A move has frames (startup / active / recovery at 60 a second), damage, posture damage, knockback, lunge, hitstun, the parry window and its follow-ups.

Since Oct 4, 2026 an attack's frame data are to be generated from its clip into a committed table with no hand overrides, and a test keeps every attack inside its [[Timing band]] (`docs/adr/0001-animation-leads-realistic-look.md`). The protected timings (the parry window, the input buffer, the dodge and backstep, hitstun, blockstun, hit-stop and the knockdown phases) and the jump arcs stay rules numbers.

Fields the rebuild added:

- `swing`: the weapon path. See [[Weapon swings]].
- `side_start`, `side_end`: which side the weapon starts and ends on, used to check that strings flow.
- `dodge_cancel_from`: the frame a heavy can be dodge-cancelled from.
- `charge_move`: a charge the fighter can walk during, at block speed, which a dodge cancels (the Katana's Iai stance).
- `release_variant`: the move a chargeable heavy becomes when drawn with the stick held sideways (the horizontal Iai).
- `lunge_along_dodge`: a dodge attack that lunges in the dodge's direction (Passing Cut).

Chains: each move names at most one light follow-up and one heavy follow-up, and pressing nothing ends the string. Each move's reach and arc, which the [[Computer opponent]] and the move list use, are computed from its swing at load.

Global tuning lives in `constants.gd` ([[Rules layer]]). Changing combat rules or tuning means adding or updating a test (see [[Tests and tools]]) and updating the docs in the same branch ([[Workflow]]).

**Sources:** [[Rebuild spec - Implementation Decisions]] · weapons: [[Katana]] · [[Greatsword]] · [[Twin Daggers]]
