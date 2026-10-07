---
tags: [combat]
---

# Disarm and re-arm

A fighter whose [[Posture]] is full is [[Disarm|disarmed]] when they're parried, or when they block a power attack, an [[Unblockable]] or an [[Ultimate]]. A [[Redirect]] also disarms an armed attacker whose posture is full.

- The weapon flies off and sticks in the arena, marked on screen. **Since milestone-1 task 86** it no longer bounces or lands at random: it flies 3.5 m along the blade's motion at contact (the blow's for a blocked power attack, the attacker's own reversed for a parry or redirect, straight away from the disarmer when the blade barely moves), shortened to land at least 0.95 m inside the walls (0.8 m until the Greatsword grew to 1.98 m), and sticks blade-first 25° from vertical, leaning back the way it came, the same way every run. Picking it up will mean pulling it out (task 87).
- The disarmed fighter's posture resets to empty, and they fight [[Hand-to-hand]] with their [[Bare hands]].
- **Re-arming:** stand on the weapon and press Pick up. It takes about 0.4 s, and the fighter is open meanwhile. The disarmed fighter's ultimate can be Recall instead, which brings the weapon flying back.
- The armed fighter tries to stand between them and the weapon; the [[Computer opponent]] does this too.
- **[[Finisher|Finishers]] (Oct 4; the rules since milestone-1 task 103, Oct 5, on a stand-in until the clips land):** disarming a fighter at 5% HP or less slows the game and gives the disarmer one timed press: a fresh heavy press inside 18 rules frames (about a second at 0.3×), never one made before or waiting in the buffer, and any other attack, block, dodge, jump or ultimate forfeits it. The computer presses it on 30% of prompts on Easy, 60% on Normal and 90% on Hard (task 107); Training's dummy never does, and a finisher in Training plays in full before its victim comes back, refilled and re-armed. In time, their weapon's finisher kills and ends the round; missed, the disarm plays out. There's no escape. Every weapon has one and so do bare hands, since a redirect can disarm. The [[Katana]]'s is an iai slash that carries the fighter behind the opponent, who falls in two halves as the blade clicks home.

Balance target: disarms per round are one of the numbers the soak run watches. The soak ([[Task 12.1]]) measured 0.74 a round; since Oct 4, tuning it toward 0.3–0.6 is milestone-1 work.

**Sources:** [[MVP spec - Combat rules]] · [[Design doc - 1. High Concept & Overview]] · [[Rebuild spec - Implementation Decisions]] · code in [[game.sim]]
