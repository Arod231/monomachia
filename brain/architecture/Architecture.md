---
tags: [architecture]
---

# Architecture

A Godot 4.7 project in `game/`, written in typed GDScript. The original three.js web demo was the reference for the port; it was deleted once the Godot build matched it, and tag `v0.1-web-mvp` keeps it.

## Two layers

- **[[Rules layer]]** (`game/sim`): plain GDScript classes for the world, fighters, match, input tracker, computer brains and [[Move data]], advanced exactly 60 times a second. It knows nothing of graphics, input devices or sound.
- **[[Presentation layer]]** (`game/view`, `game/ui`, `game/audio`): nodes, [[Fighter animation]], camera, effects, sound and menus. It reads the rules' state and events and never changes them.

A host node runs the fixed-step loop with an accumulator, applies slow motion by scaling the accumulator (not the engine's time scale), feeds each player's input, and gives the presentation an interpolation fraction, which it holds still during hit-stop.

## How they talk

The rules emit **events** (swing, telegraph, hit, block, parry, counter, disarm and so on). The presentation, sound and HUD consume them, and tests assert on them.

## Where things live

| Folder | What |
|---|---|
| [[game.sim]] | The rules: fighter, world, match, hits, [[Weapon swings]] |
| [[game.sim.moves]] | Each weapon's move data and swing files |
| [[game.sim.ai]] | The [[Computer opponent]] |
| [[game.core]] | Match configuration, services, settings |
| [[game.input]] | Devices, bindings and profiles |
| [[game.view]] | Fighters, the look, the match scene, the camera |
| [[game.ui]] | The HUD, menus and theme |
| [[game.audio]] | Sound and music |
| [[game.arenas]] | The [[Moonlit Shrine]] |
| [[game.tests]] | GUT tests: see [[Tests and tools]] |
| [[game.tools]] | Headless runners, the swing editor, shot scenes |

The [[Code map]] covers every folder, generated from the scripts' doc comments.

**Sources:** [[Rebuild spec - Implementation Decisions]] · [[README - Build and develop]]
