---
tags: [architecture]
---

# Presentation layer

Everything the player sees and hears. It reads the [[Rules layer]]'s state and events each frame and never changes them, so the rules stay testable without graphics.

- **Fighters** ([[game.view.fighter]]): models, palettes, [[Fighter animation]] and the weapon held by inverse kinematics.
- **The look** ([[game.view.look]]): the toon and ink-wash shaders. On Oct 4, 2026 a realistic look replaced toon and ink-wash in the design (physically based materials under a painterly grade, no outlines), so these shaders retire as it lands. See [[Art direction]].
- **The match** ([[game.view.match]]): the match scene, the [[Camera]] rig and the swing debug view (F3 in a debug build).
- **Combat effects** ([[game.view.effects]]): one effects layer with pooled flashes, rings and particles, an event table saying which effects each rules event spawns, and the blades' brush-stroke trails (white, red for unblockables, gold for ultimates) with the rules for when they show. Sparks, the parry ring, the 危 mark and the rest join it. Since Oct 4 the effects are to be fully realistic (sparks, blood, dust, smoke and air smears), and the brush-stroke trails retire.
- **The arena** ([[game.arenas.moonlit_shrine]]): the [[Moonlit Shrine]].
- **UI** ([[game.ui.hud]], [[game.ui.menus]], [[game.ui.theme]]): see [[HUD and menus]].
- **Audio** ([[game.audio]]): see [[Sound and music]].

Animations and effects run on the rules' clock, so they hold still in hit-stop and pause and slow down in the KO's slow motion. Between rules ticks the host's interpolation fraction smooths movement; effects are timed on the frame shown (the world frame before the last step plus that fraction).

The Oct 4 direction is recorded in `docs/adr/0001-animation-leads-realistic-look.md`.

**Sources:** [[Rebuild spec - Implementation Decisions]] · see [[Architecture]]
