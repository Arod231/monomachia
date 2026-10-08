---
tags: [game, arena]
---

# Moonlit Shrine

The one [[Arena]] so far. The demo's shrine has been rebuilt as a floating walled platform with a radius of 15 m (the demo's was 11.5 m), over a landscape of mountains, pagodas, waterfalls and water. The walls mean fighters can't fall off, and the weapon-drop and knockback rules stay unchanged.

- The bigger radius moved several numbers with it ([[Task 8]]): the Impaler's dash ends 0.7 m inside the wall, dropped weapons land at least 0.8 m inside it (since milestone-1 task 86 they stick there instead of bouncing; 0.95 m since the Greatsword grew to 1.98 m with the taller bodies), and the Moonsplitter's wave reaches 33 m so it still crosses the stage.
- The match camera stays within 16.2 m of the centre, short of the lanterns, pillars and wisteria on the ledge. See [[Camera]].
- It has its own ambience loop. See [[Sound and music]].
- Stage 3 of the plan built it: [[Stage 3 - The shrine]].

## The look since Oct 4, 2026

The shrine is to be upgraded in place to the realistic look ([[Art direction]]): an ancient battleground under a blood moon and a starry sky, ringed by huge, ancient wisteria trees with dark bark. Their canopy reaches over the arena without hiding the moon or blocking the camera, and their blossoms glow a soft purple, give off light and rain glowing petals in the wind. The paving is worn, weathered, uneven and broken across the whole arena.

- **The wisteria (Oct 7, 2026, milestone-1 task 48):** five unique giant wisteria in exaggerated proportions replaced the pines and dead trees on the ledge, the owner's own art grown by script in Blender, in Poly Haven's Bark Willow (CC0). Their roots sprawl over the ledge and the wall's lip; their canopies hang over the arena above the fighters, overlapping, kept out of the cameras' room (up to 6.6 m) and leaving a window for the moon from the cameras near the centre. The blossoms glow neon lavender as if bioluminescent, each lighting what's round it (global illumination on Ultra and High), with purple lights in pools under the canopy and no tree shadows on the floor; the blood moon, larger and vivid in a near-black sky, lights the clouds round it and casts the fighters' shadows; the lanterns give more light and cast shadows; at match point the petals turn blood red and light the arena blood red; glowing petals fall, and a few lights drift down with them (off on Low). Young ones grow on the floating rocks.
- **The fallen petals (Oct 8, 2026, milestone-1 task 137):** glowing lavender petals fall from the canopy into the arena on the wind, settle on the floor and build up over the match into drifts against the parapet (cleared at a new match), dimming to a soft glow once settled. The fighters' steps, rolls and low swings and the heavy blows, falls and KOs push and scatter them; they turn blood red at match point. Picture only, thinned per graphics preset.
- **The buildings remodelled (Oct 8, 2026, milestone-1 task 132):** the lanterns are Kasuga-dōrō, the torii carry a shimenawa with shide under the tie beam as well as the gates' rope barriers, the pillars stand whole or broken, and the far pagodas and temple halls are modelled in grey tiles and weathered timber, all the project's own models in today's places. Everything is ancient: chipped vermilion lacquer showing grey wood, moss and lichen in the stone's crevices, cracked edges, frayed rope.
- **Weather:** five states (clear, partly cloudy, cloudy with lightning and thunder, light rain, rainstorm) drift during the match, with storms more likely toward the final round, all moved by one wind. In a rainstorm lightning lights the fight, and clashing blades push the rain away. The clear night comes first.
- **Reactions:** slams knock up dust and crack the floor, and the cracks and cut marks last the match. Nothing in the arena changes the rules.
- Dropped weapons are to stick in the ground where they land instead of bouncing ([[Disarm and re-arm]]).

The design's other arenas, all floating and reimagined in the dark fantasy, oriental style: a fantasy coliseum, hell and ice. The original list's Cyberpunk Grid, Deep Space Nebula, Synthwave Sunset and Retro Vector are dropped as off-style.

**Sources:** [[Design doc - 4. Game Modes & Progression]] · [[Rebuild spec - Implementation Decisions]] · [[Rebuild plan notes 16-18-look-arena-effects]] · code in [[game.arenas.moonlit_shrine]]
