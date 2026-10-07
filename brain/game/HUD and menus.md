---
tags: [game, ui]
---

# HUD and menus

On Oct 4, 2026 a realistic look replaced the toon and ink-wash look, so the menus and HUD are to be redesigned for it. The layout below stays, ink survives only as calligraphy (brushed kanji and titles), and the style is picked from a UI page of the mood board: on Oct 4 the owner chose lacquer and gold (black lacquer panels, gold hairlines, lacquer-disc round pips, brushed kanji in ivory). See [[Art direction]] and `docs/adr/0001-animation-leads-realistic-look.md`.

## HUD

A minimalist fighting-game HUD: HP bars in classic style with the posture bar underneath.

- **Built:** the top bar ([[Task 24]]: plates with the 赤 and 青 seals, HP with a lag band and a low-HP pulse, posture, and round pips), the announcements in kanji on the rules' frames (round calls, Fight, K.O.), and the toasts under the centre for parries, counters, ultimates, backstabs and dazes: gold or jade for what you did, red for what was done to you, and in Watch the fighter's name in the side's colour.
- **Built in Training:** the panel at the bottom left with the dummy's behaviour chips and refill, toasts for an evade and for a new dummy behaviour, and parry timing feedback: your parry says how many frames before impact you pressed and the window you had, and a press too early or too late says by how many frames.
- **Built:** the prompts at the bottom, at most two, urgent first, naming each key as a key cap from the device used last (on a controller the Moonsplitter's tilt names the stick); the Button hints setting hides them.
- **Built:** the marker on your dropped weapon, "Your weapon" over it from the disarm until it is back in hand, clamped to the screen's edge with an arrow pointing the way when it is off screen or behind the camera.
- **Built:** the Versus HUD: "Player 1" and "Player 2" plates with each fighter beside its weapon, each player's prompts and weapon marker in their own half of the split screen, named for their own device, and toasts and calls naming the player ("Player 2: Parry", "Player 1 wins the round") in the sides' colours.
- **Built (Oct 7, milestone 1's task 54):** the top bar and the calls in the lacquer-and-gold style, keeping their layout: HP in each side's lacquer (crimson, indigo) in gold-edged channels, posture in gold turning amber when hot and blinking crimson when full, the pips as black lacquer discs lit in the side's colour, the 奥義 badge as a lacquer disc with brushed kanji; each call's kanji large and brushed in ivory, painted in by a brush stroke while the word under it fades in, in small spaced gold capitals. The toasts, prompts, marker and the Versus HUD are restyled later.
- The ultimate is shown by a glowing aura around a fighter at 25% HP or less. Since Oct 4 the aura is a smouldering glow of embers and heat haze in the side's colour.
- **KO call (Oct 4):** every KO that ends a round, finishers included, is to be called Warrior Slain (討死) instead of 一本 K.O.; a double KO keeps its own call.

## Menus

A lacquer-and-gold UI theme on a screen stack with keyboard and controller navigation ([[Task 22]]). Since milestone 1's task 53 (Oct 7) the menus wear the mood board's UI A in place of the ink-wash theme: black lacquer panels in a double gold hairline with a small gold flourish of grasses at each corner, a gold underline over a warm gold wash on the focused entry, titles and buttons in the Shippori Mincho B1 serif, kanji brushed in ivory in Yuji Boku, text in Zen Kaku Gothic New, and the title's 一騎 seal still crimson. The two new fonts are cut down to the characters the game uses. The HUD's restyle follows.

- **Built:** the title over a live duel, the main menu, the fighter select (grid, sides, difficulty, arena, lock in, the loadout panel and the 3D preview of the fighter idling and turning), results with stats, Rematch and Change fighters, Settings, the Controls screen with rebinding capture and profiles, How to play with the move list, and the pause menu (Resume, Move list, Controls, Settings, Restart, Quit to menu) over the frozen match. The whole flow is walked by tests with the keyboard alone and with a controller alone, and every screen has a shot scene.
- **To come (Oct 4):** a black-and-white mode in Settings ([[Art direction]]).
- **Built:** the Versus select's device and profile pickers ("Plays with" and "Controls profile" on each player's step); two players on one device, or a controller that isn't connected, refuse Lock in.

Most of this is stage 10 of the plan, begun early while the swings were reviewed: [[Stage 10 - While the owner reviews]].

**Sources:** [[Design doc - 5. Visuals, Audio, & UI-UX]] · [[Rebuild plan notes 22-24-screens-modes-hud]] · code in [[game.ui.hud]] and [[game.ui.menus]] · see [[Game modes]]
