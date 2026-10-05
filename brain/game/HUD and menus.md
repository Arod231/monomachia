---
tags: [game, ui]
---

# HUD and menus

On Oct 4, 2026 a realistic look replaced the toon and ink-wash look, so the menus and HUD are to be redesigned for it. The layout below stays, ink survives only as calligraphy (brushed kanji and titles), and the style is picked from a UI page of the mood board: on Oct 4 the owner chose lacquer and gold (black lacquer panels, gold hairlines, lacquer-disc round pips, brushed kanji in ivory). See [[Art direction]] and `docs/adr/0001-animation-leads-realistic-look.md`.

## HUD

A minimalist fighting-game HUD: HP bars in classic style with the posture bar underneath.

- **Built:** the top bar ([[Task 24]]: plates with the 赤 and 青 seals, HP with a lag band and a low-HP pulse, posture, and round pips) and the announcements in kanji on the rules' frames (round calls, Fight, K.O.).
- **Built in Training:** the panel at the bottom left with the dummy's behaviour chips and refill.
- **To come:** toasts for parries, counters and ultimates, button prompts with the last device's key names, and the dropped-weapon marker.
- The ultimate is shown by a glowing aura around a fighter at 25% HP or less. Since Oct 4 the aura is a smouldering glow of embers and heat haze in the side's colour.
- **KO call (Oct 4):** every KO that ends a round, finishers included, is to be called Warrior Slain (討死) instead of 一本 K.O.; a double KO keeps its own call.

## Menus

An ink-wash UI theme with bundled Zen fonts, on a screen stack with keyboard and controller navigation ([[Task 22]]). The ink-wash theme is what the code has today; the Oct 4 redesign above replaces it.

- **Built:** the title over a live duel, the main menu, the fighter select (grid, sides, difficulty, arena, lock in and the loadout panel), results with stats, Rematch and Change fighters, Settings, the Controls screen with rebinding capture and profiles, How to play with the move list, and the pause menu (Resume, Move list, Controls, Settings, Restart, Quit to menu) over the frozen match.
- **To come (Oct 4):** a black-and-white mode in Settings ([[Art direction]]).
- **To come:** the select's 3D preview and Versus device pickers.

Most of this is stage 10 of the plan, begun early while the swings were reviewed: [[Stage 10 - While the owner reviews]].

**Sources:** [[Design doc - 5. Visuals, Audio, & UI-UX]] · [[Rebuild plan notes 22-24-screens-modes-hud]] · code in [[game.ui.hud]] and [[game.ui.menus]] · see [[Game modes]]
