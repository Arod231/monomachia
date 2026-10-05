---
tags: [combat]
---

# Attacking

A fighter has two attack buttons.

- **[[Light attack|Lights]]** are quick strikes that chain into a [[String]] of 2–4 hits, depending on the weapon.
- **[[Heavy attack|Heavies]]** are slower and deal more HP and posture damage and more knockback. Holding heavy makes a [[Charged heavy]]: after 2.5 s it releases by itself as a **power attack**, which disarms a blocker whose posture is full, then leaves the attacker open.
- **[[Movement attack|Movement attacks]]** come out of a sprint, a dodge, a backstep or a jump, each with its own move.
- **[[Block ability|Block abilities]]:** holding block and pressing light or heavy triggers one of the weapon's two chosen abilities, set in the [[Loadout]].
- **[[Ultimate]]:** pressing light and heavy together, once unlocked. See [[Ultimates]].

## Strings flow

- A [[Follow-up]] is always optional: pressing nothing ends the string.
- A swing that ends on the right comes back from the right. Every move in a string records the side it starts and ends on, and a follow-up must start where the last move ended. Moves that start at the centre (overheads, thrusts, stabs, spins, the crossing cut) may follow any side.
- Two lights flow into a heavy as the third hit (the L-L-H).
- A light hitstun of 14 frames (it was 18) lets a defender block or parry from the second hit on. This replaces a combo breaker.

## Feel (the fluid rules)

Attacks keep half of the running speed as they start (it was 30%), lunges ease in and out, colossal swings end with a short slide, and heavies can be dodge-cancelled in the second half of their recovery. [[Task 8]] and [[Stage 4 - Fluid rules]] built these.

On Oct 4, 2026 animation took the lead (`docs/adr/0001-animation-leads-realistic-look.md`). A fighter now moves only as their clips carry them, so the rules stop adding lunges and slides, and dodge cancels open at markers on each clip. The pace becomes slower and weightier, close to For Honor's (the Katana's lights land in roughly 400–500 ms), and every weapon is rebalanced as its animation lands. Hitstun stays a rules number. See [[Fighter animation]].

What decides a hit is the weapon's real path: see [[Weapon swings]].

**Sources:** [[Design doc - 2. Core Mechanics & Controls]] · [[Rebuild spec - Implementation Decisions]] · [[MVP spec - Combat rules]]
