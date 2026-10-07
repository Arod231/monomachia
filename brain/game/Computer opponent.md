---
tags: [game, ai]
---

# Computer opponent

The computer plays through a virtual controller, so it follows exactly the player's rules and timings: it can't cheat, only react. Several times a second it:

- keeps its weapon's ideal distance: closing in, circling or backing off;
- attacks with a mix of strings, heavies, sprint attacks and [[Unblockable|unblockables]], using more unblockables against a player who hides behind their block;
- reacts to attacks after a human-like delay with a parry, a block, a dodge or the correct [[Counter]];
- blocks to drain its own posture when the meter runs high;
- holds the Katana in the [[Grip]] the moment calls for: one-handed when low on posture or at range, two-handed up close or against a player who guards a lot (posture first), and at Hard switches mid-string to mix the two strings;
- guards the player's dropped weapon when the player is disarmed, and runs for its own (or fights bare-handed) when it's disarmed;
- fires its [[Ultimate]] when it unlocks and the player is in range.

| Level | Reaction | Parry chance | Correct counter | Aggression | Grips |
|---|---|---|---|---|---|
| Easy | 0.45 s | 8% | 10% | Low | One-handed only |
| Normal | 0.30 s | 30% | 35% | Medium | Switches by the situation |
| Hard | 0.18 s | 55% | 60% | High | Also mixes strings |

The same brain drives the training dummy's behaviours and the soak run, where computer-vs-computer matches print balance numbers (round length, disarms per round, each weapon's win rate, and since KE task 9 each grip's share, swings, hits and damage, the switches and the mixed strings). Stage 12 of the plan retunes it for the new rules: [[Stage 12 - Computer opponent and balance]].

**Sources:** [[MVP spec - Computer opponent]] · [[Rebuild plan notes 07-12-swings-and-balance]] · code in [[game.sim.ai]] · see [[Tests and tools]]
