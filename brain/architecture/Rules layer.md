---
tags: [architecture]
---

# Rules layer

The game's rules, in `game/sim` ([[game.sim]]): pure simulation with no rendering, input-device or audio code, stepped at a fixed 60 ticks a second so it can be unit tested and replayed.

- **Fighter** (`fighter.gd`): position, health, posture and a frame-by-frame state machine (attacking, dodging, blocking, stunned, disarmed and so on).
- **World**: both fighters, dropped weapons, projectiles such as the Moonsplitter wave, and the hit evaluation, run in the demo's update order.
- **Match** (`match.gd`): the round flow, intro → fight → KO → next round, first to three. See [[Rounds and matches]].
- **Input tracker**: turns raw buttons into taps, holds, double-taps and directions relative to the opponent.
- **Hits**: [[Weapon swings]] sweep each blade against the defender's [[Hurt capsule]]; the outcome order is counters, jumped, flash, evade, parry, block, hit.
- **[[Move data]]**: each weapon's moves as tables of numbers.
- **Constants** (`constants.gd`): global tuning.
- **Brains** ([[game.sim.ai]]): the [[Computer opponent]] and the training dummy, playing through the same inputs a human uses.

## Number rules

Positions live in the rules' own 64-bit vector classes, because Godot's built-in vectors are 32-bit, and `js_math.gd` computes sin, cos, atan2 and hypot exactly as V8 does. Both made the port match the TypeScript rules bit for bit ([[Faithful port]]) and keep results identical on every platform. Random numbers come from a seeded Mulberry32 generator, so matches can be replayed.

**Sources:** [[Rebuild spec - Implementation Decisions]] · [[MVP spec - At a glance]] · code in [[game.sim]]
