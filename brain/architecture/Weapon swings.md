---
tags: [architecture, combat]
---

# Weapon swings

The rebuild's biggest rule change: **the weapon's real path decides a hit**. The design asks for hitboxes as tight to the weapon as possible, so what you see is what hits.

## What a swing is

A [[Swing]] is a short list of key poses in the fighter's own space, covering the whole move: wind-up in the startup, strike in the active frames, follow-through in the recovery. It has a track per moving part (each weapon hand, a foot for a kick, the body). Hand keys hold the grip, the blade and edge directions, and an optional elbow tweak; body keys hold the torso and pelvis coil and a pelvis shift, so the hips can lead the hands.

- Between keys the grip travels on an arc around the shoulder line (1.44 m up), not in a straight line, and the blade turns with the hand.
- The keys live in one JSON file per weapon, `game/sim/moves/swings/<weapon>.json`, expanded to per-tick samples at load. A file with any mistake is refused whole.
- A follow-up's first key sits within 2 cm and 10° of the previous move's last pose, so strings flow.

## How a hit lands

Each tick, every hand and foot track is placed in the world, and the blade's [[Strike segment]] between this tick and the last makes a [[Sweep]]. The hit lands on the first active tick the sweep touches the defender's [[Hurt capsule]] (0.42 m radius, from the feet to 2.0 m, since the taller bodies of the Katana's Elden Ring rework). The [[Contact point]] is where the blade went deepest; sparks start there, and on a parry the deflect pair's two blades meet there (milestone-1 task 34). A swing that never touches whiffs. [[Unblockable|Unblockables]] get 10 cm of extra reach.

## Body rules every swing must pass

Checked headless on both fighters' reference bodies: wrists within about ±60° of bend and ±25° of deviation, elbows never locked, the blade never within 5 cm of the fighter's own body, a 2–4 frame cocked hold before the strike, and the attack type readable in the first third of the wind-up.

The same path drives the animation: the arms reach for the grip by inverse kinematics. See [[Fighter animation]]. The planned swing editor (the rebuild plan's task 14b) was retired: authored clips replace hand-keyed swings ([[Plan - Authored animation and the dodge roll]]).

Plan: [[Task 7]], [[Stage 7 - Swing foundations]], then the [[Katana]] in [[Stage 9 - The Katana on swings, and the animation review]] and the other weapons in [[Stage 11 - The other weapons' swings]].

**Sources:** [[Rebuild spec - Implementation Decisions]] · [[Rebuild plan notes 07-12-swings-and-balance]] · [[Animation spike (Sep 30, 2026)]] · code in [[game.sim.swings]]
