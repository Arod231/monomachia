---
tags: [game, audio]
---

# Sound and music

## Effects

- Clangs when weapons meet, and a satisfying metal ring unique to parries.
- Slicing-flesh sounds when blades connect, and bone-and-rock crunches when colossal weapons land.
- Each fighter's movement has its own sound, such as the Skeleton Knight's rattling bones, and footsteps fall where the feet come down.
- **KO (Oct 4):** the final hit's impact rings out as the slow motion drains the arena's sound and the music, then a deep drum lands under the Warrior Slain call.
- The best of the Sonniss bundle (clangs, swings, gore, ice cracks, wind, water, UI), trimmed and converted, plus generated sound for what it lacks: taiko, gong, the parry ring layer, footsteps and bone-crunch layers. Raw Sonniss files are never committed.

## Music

Dark fantasy and ancient oriental instruments, combined with electronic music and metal. **Oct 5 (milestone 1):** in matches the traditional instruments lead (taiko, the biwa on the riff, the shamisen, the shakuhachi on the motif, a low choir), and the electronic and metal layers (kit, sub, distorted guitars) build in only at match point; the menus keep the groovier fusion.

| Where | Tempo |
|---|---|
| Menus, character select, loading | 100–120 BPM (placeholder at 110) |
| Matches | 130–150 BPM (placeholder at 140) |
| Match point | 150–170+ BPM (placeholder at 160) |

The placeholder tracks are generated in code. They switch to the match-point theme at the round call when either fighter has two wins, and loops fade in and out so they never click.

Stage 5 of the plan built this: [[Stage 5 - Sound and music in the game]].

**Sources:** [[Design doc - 5. Visuals, Audio, & UI-UX]] · [[Rebuild spec - Implementation Decisions]] · [[Rebuild plan notes 19-20-25-26-sound-and-ship]] · code in [[game.audio]]
