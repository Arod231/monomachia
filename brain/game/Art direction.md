---
tags: [game, presentation]
---

# Art direction

Gritty dark fantasy and ancient oriental: noble warriors fighting for honour and glory.

## The look since Oct 4, 2026

On Oct 4, 2026 a realistic look replaced the toon and ink-wash look the rebuild first built (kept below as the record). Why is in `docs/adr/0001-animation-leads-realistic-look.md`.

- **Look:** physically based materials, dark lighting and volumetric fog under a painterly colour grade. Ghost of Tsushima's darker side is the main reference: night, storm and the blood moon, deep shadow and mist, with colour used as accents (red leaves, lanterns, blood).
- **No ink in play:** no toon shading, outlines or ink-wash screen effect. Ink survives only as calligraphy in the UI: brushed kanji and titles in the menus, the HUD and the round calls ([[HUD and menus]]).
- **Telling the sides apart:** muted dyed palettes, crimson against indigo, and key and rim lights that touch only the fighters. No outlines.
- **Camera effects:** clean during play (anti-aliasing, subtle bloom, ambient occlusion, fog, the grade and light film grain). Depth of field and motion blur come in only for the intros, ultimates, parry push-ins and the KO.
- **Effects:** fully realistic sparks, blood, dust, smoke and air smears; the ink-brush trails retire. The ultimates keep their supernatural energy (fire, lightning, shockwaves, spirit energy), lit and rendered realistically. Hits draw blood (a burst, stains on blades and clothes for the whole match, splatter on the floor until the round ends; milestone-1 task 38), and a Blood setting offers On, Reduced (less of everything) or Off. Nothing is dismembered except in the [[Finisher|finishers]], with Blood On.
- **Black-and-white mode:** a Settings option like Ghost of Tsushima's Kurosawa Mode; blood and the red unblockable warning keep their colour.
- **Arena:** the [[Moonlit Shrine]] gains glowing purple wisteria, stars, worn paving and dynamic weather moved by one wind.
- **Fighters and weapons:** for the first milestone the current bodies are re-textured in the new look; new stylised-real models with cloth-simulated clothing arrive by the second. Every weapon is modelled in Blender; the models set the blade lengths, and reach is retuned to match.
- **Target:** Ultra at 4K and 60 fps on an RTX 3090 is the reference preset every look is judged at. Low must hold 60 fps at 1080p, upscaled from about 720p, on the Ryzen 7 4700U laptop.
- **Mood board (Oct 4):** approved, subject to change: the look and grade as drawn, crimson #9e2b25 against indigo #1d2a4d, Moonsplitter's wave as moonlight and the disarmed ultimate as a spirit shockwave (neither in a side's colour), the UI in lacquer and gold, and For Honor's camera framing ([[Camera]]). It lives in the private asset repository.
- **Look test:** a mood board, then a test scene (one fighter with the Katana in a corner of the [[Moonlit Shrine]], at Ultra) settled the look before anything converted. On Oct 7, 2026 (milestone-1 task 43) the game itself took it: its materials, grade, mist and camera framing.
- **Assets:** paid and large art lives in a private asset repository that the import tools read. The public repository keeps the code, free-licence and self-made art, and labelled stand-ins.

## Before Oct 4: the toon look

What the rebuild built first, and what the code still draws until the new look lands.

- **Look:** stylised toon lighting in three bands, ink outlines and an ink-wash finish (paper grain, soft edge darkening, a muted palette with red accents).
- **Fighters:** clothing that's gritty, worn and flowing, and says who the fighter is. Outfit textures are baked with wear (dust up the boots, scuffed knees, grime), and faces get soot and shadowed eyes. Normal maps run at 40%, because full-strength bumps break the toon bands into blotches.
- **Weapons:** every blade has a dark body and a bright edge band, so it reads at any angle and at gameplay distance. Colossal weapons are huge and must look heavy.
- **Effects:** cinematic parries with sparks, hit flashes, the red glow of an unblockable's wind-up, and the 危 danger mark.
- **Assets:** Quaternius characters, outfits, animations and weapons (CC0) and the Sonniss GDC 2026 audio bundle. Assets must be easy to swap as new packs arrive.

Stages 2 (the look) and 3 (the shrine) of the plan built this: [[Stage 2 - The look, and the real fighters in the match]], [[Stage 3 - The shrine]].

**Sources:** [[Design doc - 5. Visuals, Audio, & UI-UX]] · [[Rebuild spec - Implementation Decisions]] · [[Rebuild plan notes 16-18-look-arena-effects]] · code in [[game.view.look]]
