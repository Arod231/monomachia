---
tags: [combat]
---

# Rounds and matches

- A [[Round]] ends when a fighter's HP reaches zero, or (Oct 4; the rules since milestone-1 task 103) when they're [[Finisher|finished]] after being disarmed at 5% HP or less. The first fighter to win three rounds wins the [[Match]].
- HP, posture, weapons and ultimates reset every round. There's no round timer, and a double KO replays the round.
- **Before the first round:** each fighter walks out of their [[Gate]] and performs an intro that reflects who they are and which weapon they picked, one at a time and skippable (the [[Match intro]]). Then the fighters take their positions, as in Tekken 8.
- **Round calls:** the rules announce each round and the fight, and the HUD shows the calls in kanji on the rules' frames ([[Task 24]]). Since Oct 4 the KO is to be called Warrior Slain, with the final hit's impact ringing out into it.
- **Match point:** the music switches to the faster match-point theme at the round call when either fighter has two wins. See [[Sound and music]].
- After the match comes the results screen. See [[HUD and menus]].

The round flow lives in the rules: `match.gd` runs intro → fight → KO → next round. See [[Rules layer]].

**Sources:** [[MVP spec - Combat rules]] · [[Design doc - 4. Game Modes & Progression]] · code in [[game.sim]] and [[game.view.match]]
