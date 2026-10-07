---
tags: [architecture]
---

# Presentation layer

Everything the player sees and hears. It reads the [[Rules layer]]'s state and events each frame and never changes them, so the rules stay testable without graphics.

- **Fighters** ([[game.view.fighter]]): models, palettes, [[Fighter animation]] and the weapon held by inverse kinematics.
- **The look** ([[game.view.look]]): the realistic look since milestone-1 task 43 (Oct 7, 2026): physically based materials (`LookMaterials`), the night and its one colour grade (`LookGrade`), light film grain, and the graphics presets. The toon and ink-wash shaders it replaced are gone. See [[Art direction]].
- **The match** ([[game.view.match]]): the match scene, the [[Camera]] rig and the swing debug view (F3 in a debug build).
- **Combat effects** ([[game.view.effects]]): one effects layer with pooled flashes, rings and particles, an event table saying which effects each rules event spawns, and the blades' air smears with the rules for when they show. Since Oct 4 the effects are fully realistic: sparks at blocks and parries with a warm contact light, a dull puff where a bare hand meets a blade, blood on cutting hits, and a faint haze smear behind fast swings (tinted red for unblockables and gold for ultimates until the 危 and glint), in place of the toon look's contact flashes and brush-stroke trails (milestone-1 task 37). Dust, smoke, the 危 mark and the rest join it.
- **The arena** ([[game.arenas.moonlit_shrine]]): the [[Moonlit Shrine]].
- **UI** ([[game.ui.hud]], [[game.ui.menus]], [[game.ui.theme]]): see [[HUD and menus]].
- **Audio** ([[game.audio]]): see [[Sound and music]].

Animations and effects run on the rules' clock, so they hold still in hit-stop and pause and slow down in the KO's slow motion. Between rules ticks the host's interpolation fraction smooths movement; effects are timed on the frame shown (the world frame before the last step plus that fraction).

The Oct 4 direction is recorded in `docs/adr/0001-animation-leads-realistic-look.md`.

**Sources:** [[Rebuild spec - Implementation Decisions]] · see [[Architecture]]
