# Spec: Monomachia rebuilt in Godot

Oct 2, 2026 · status: in build, one task at a time. Stages 1–5 of the build order are done, and with them tasks 1–6, 8, 13, 16, 17, 19, 20 and 21:
- the rules port, bit for bit with the TypeScript up to its last checked commit (4222167);
- the fighter models merged, and the safety nets: a file-size guard, the Windows export with a smoke run, and CI (13.1, 25.1–25.3, 16.1);
- the real fighters and weapons in the match, in the toon and ink-wash look (16.1–16.7, 14.1, 14.2);
- the Moonlit Shrine as every match's arena (17.1–17.10; High 67 fps at 1080p on the target laptop);
- the fluid combat rules (8.1–8.10): a 15 m arena, a 60% blocking walk, half the momentum kept, eased lunges, light hitstun 14, heavy dodge cancels and the Greatsword's recovery slide;
- a soak that reports the balance targets (12.1);
- sound and music in the game (19.1–19.9, 20.1–20.3): every rules event's sounds, placed in 3D and through the arena's reverb, footsteps, the arena's ambience, the three music tracks switched by the menus and the round call, ducking, menu sounds and saved volumes, with a sound check scene for listening. Stories 50 and 51 wait for the owner's listening pass, and story 52 for the Settings screen (22.9).

14.3–14.9 (animation, PR #4) was built in its own lane (pose checks and contact sheets for reviewing animation, the legs walking, jogging and sprinting with the rules' speed, hip-turn strafing and backpedalling with the chest on the opponent, the lean into starts, stops and turns with a brace when braking, the Katana's grounded guard stance, and the guard shuffle step, which ticks story 14; story 13 also waits for the dodge poses, 15.9) and merged into this branch on Oct 2, and 7.1–7.15 (the swing foundations, draft PR #5) goes on in another, with 7.1–7.10 done. Stage 6, the new strings, is done: 9.1 built the Katana's four-light string, the moves' sides and the continuity check, 9.2 made the Iai Slash the Katana's heavy, 9.3 lets the fighter walk in its stance, 9.4 adds the horizontal Iai, picked by the stick, 9.5 the Iai's follow-ups, and 9.6 the stand-in's sheathe pose, which finishes the Katana (task 9). 10.1 gave the Greatsword its momentum lights into Overhead Strike (the L-L-H), 10.2 the unblockable Low Sweep after it, and 10.3 its dodge thrusts, which finishes the Greatsword (task 10). 11.1 gave the Daggers their alternating four-light string, each light dodge-cancelling from its first recovery frame, 11.2 Twin Fang's 1.4 m dash into Spinning Backhand, and 11.3 the Passing Cut along the dodge direction, which finishes the Daggers (task 11) and stage 6. On the owner's word, this lane then began stage 10 early, since nothing in stages 7–9 was free for it: 22.1 gave the UI its ink-wash theme with the demo's fonts, bundled, 24.1 the HUD's top bar, and 24.2 its announcements with kanji. Stage 7 goes on in the swings lane, and the rest of stage 8 (14.10–14.13) waits for 7.15 (see the plan's build order and Progress) · branch `feature/godot-rebuild`

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** This spec's toon and ink-wash look, laptop performance gates, 110 MB art cap and ink-styled effects are superseded. A realistic look after Ghost of Tsushima's darker side replaces them, judged at the reference preset (Ultra, 4K at 60 fps on an RTX 3090), and size budgets per place replace the art cap. Attack frame data and footwork come from the clips, so the rules-set lunges and colossal slide go; tuning and effects move into the slice plan, and the rebuild merges into `master` first.

> **Superseded by milestone 1 (Oct 4, 2026):** for the Katana and bare hands, `docs/specs/milestone-1.md` replaces this spec's hand-written frame data (now generated from the clips), the light hitstun of 14 (now 23 for the Katana and 17 for bare hands; bare hands' Jab and Cross lose their guaranteed 16 frames), the half-speed momentum carry into attacks, the 60% blocking walk (now the gait clips' own speeds), the three presets (now four, with Ultra the reference) and the laptop gates (now the two new performance gates), the jump attack's skip to its active frames on landing, and the soak's targets (rounds of 60–90 s, mirror matches, win rates off). It delivers this spec's stories 13, 16, 18, 19, 21, 22, 24, 26–30, 40, 42, 43, 48 and 49 for the Katana and bare hands. The Greatsword and the Daggers keep today's values until milestone 2.

> **Triaged (Oct 4, 2026):** the open work was triaged under ADR 0001 (see the plan's [Triage and consolidation](../plans/godot-rebuild.md#triage-and-consolidation-oct-4) section). The rebuild is consolidated onto `master` first: the finished lanes merge in, the web version retires, and the branch merges into `master` (stage 14). Milestone 1 then gets its own spec. Story 46 (the toon look) is retired. The open stories about how attacks, defence and effects look and feel (13, 16, 18–22, 24, 26–40, 42, 43, 48 apart from the dropped-weapon marker, and 49) have no task left in this plan: milestone 1 delivers them for the Katana and bare hands, and milestone 2 for the Greatsword and the Twin Daggers, judged against the Oct 4 quality bar. While milestone 1 is built, the menus offer only the Hunter and the Katana; the Rogue, the Greatsword and the Twin Daggers return with milestone 2.

The playable duel from the web demo, rebuilt in Godot 4.7 as a PC game on the new direction from `docs/design.md`. Real fighters replace the block puppets, weapons swing along authored paths that also decide what they hit, the camera sits over the shoulder like For Honor, and the fight takes place on a larger floating shrine drawn in a toon and ink-wash style. The rules, the three weapons, the four modes, the computer opponent and the remappable controls carry over; the web version is retired once the Godot build matches it.

## Problem Statement

The demo proves the duel works, but it doesn't feel or look like the game in `docs/design.md`:

- Combat is stiff. Weapons are held out in front, each swing pops through 2–6 frames of motion with the hands moving in straight lines, and consecutive swings don't continue from where the last one ended, so they feel random.
- The rules add to the stiffness: attacks root the fighter in place, almost nothing can be cancelled, and hits are decided by an invisible cone around the attacker rather than by where the blade actually goes.
- Fighters are block puppets, the look is generic, and the arena is small.
- A browser game built with three.js is the wrong base for a PC fighter with eight fighters, nine weapons and real art.

## Solution

A Godot 4.7 PC game (Windows) that plays the same duel with the same rules and content (Katana, Greatsword, Twin Daggers; Duel, Training, Watch, Versus; posture, parry, disarm, counters and ultimates), rebuilt on the foundations the design update asks for:

- the rules layer ported line for line to GDScript and checked against the original, then changed on purpose for fluid combat;
- weapon swings authored as paths that drive both the animation and the hit detection;
- rigged fighters from the Quaternius packs (two fighters to start: the Rogue and the Hunter), with locomotion clips plus procedural animation for everything the packs lack;
- the new strings for the three weapons from the design doc;
- a For Honor-style camera, a larger walled floating Moonlit Shrine, and a toon, outline and ink-wash look;
  > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** A realistic look replaces the toon, outline and ink-wash look: physically based materials, dark lighting and volumetric fog under a painterly colour grade, after Ghost of Tsushima's darker side.
- recorded sound where the Sonniss bundle has it, generated sound and placeholder music at the target tempos where it doesn't.

## User Stories

A ticked story works in the Godot build today. The plan names the tasks that deliver each of the others.

### Playing a duel

1. [ ] As a player, I want to start Monomachia as a Windows program, so that I can play without a browser.
2. [x] As a player, I want a title screen with a live duel playing behind it, so that the game feels alive the moment it opens.
3. [ ] As a player, I want to choose Duel, Training, Versus or Watch from the main menu, so that I can play the way I want. (Duel, Watch and, since 23.3, Training are on the menu; Versus comes with 22.16.)
4. [ ] As a player, I want to pick my fighter, my weapon and my two block abilities before a match, so that I fight with the loadout I prefer.
5. [x] As a player, I want to pick the computer's fighter, weapon and difficulty (Easy, Normal, Hard), or leave its weapon random, so that I control the challenge.
6. [x] As a player, I want the match to be first to three rounds with a clear round call and "Fight", so that I always know where the match stands.
7. [x] As a player, I want health bars with the posture bar underneath, round pips and an ultimate badge, so that I can read the state of the fight at a glance. (Task 24: the top bar, the announcements, toasts, prompts and the dropped-weapon marker, in the ink-wash theme; milestone 1 restyles them for the realistic look.)
8. [x] As a player, I want a results screen with rounds won and match stats, and options to rematch, change fighters or go to the main menu, so that I can play again quickly.
9. [x] As a player, I want to pause at any time and reach the move list, controls and settings from the pause menu, so that I can check things mid-match. (22.15: `PauseScreen`, with Restart and Quit to menu; the move list opens on the weapon in hand.)
10. [x] As a player, I want the game to pause itself when the window loses focus, so that I don't lose a round while tabbed out.

### Camera and movement

11. [ ] As a player, I want the camera over my fighter's shoulder, slightly more zoomed out than For Honor, and always locked on to my opponent, so that I see my fighter, my opponent and the space between us.
12. [x] As a player, I want to move in eight directions around my opponent, step with a tap, sprint with a double-tap and hold, dodge with a direction, backstep with no direction, and jump, as in the demo, so that the controls I learned still work.
13. [ ] As a player, I want my fighter to lean into runs and turns, and to dash evasively when dodging, so that movement looks real.
14. [x] As a player, I want to walk noticeably faster while blocking than in the demo, so that I can reposition while guarding.
15. [x] As a player, I want a larger arena with walls at the edge, so that there's room to manoeuvre and nobody falls off.

### Attacking

16. [ ] As a player, I want each swing to continue from where the last one ended (a right-to-left cut followed by a left-to-right cut), so that strings flow.
17. [ ] As a player, I want every follow-up to be optional, so that I can stop after any hit and recover normally.
18. [ ] As a player, I want two lights to flow into a heavy as the third hit with every weapon, so that I have a standard finisher.
19. [ ] As a player, I want attacks to feel heavy: a visible wind-up, a strike that lands with hit-stop, and a follow-through, so that hits have weight.
20. [ ] As a player using a colossal weapon, I want the swing to pull my fighter along with its momentum, so that the weapon feels heavy.
21. [ ] As a player, I want a hit to register only when the blade actually reaches my opponent, and a swing to miss when it visibly misses, so that I trust what I see.
22. [ ] As a player, I want unblockable attacks to reach further than normal ones and to show their reach with a red ink trail and warning mark, so that I can read them and pick the right counter.
    > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The ink trail retires. As the wind-up starts, a red 危 flashes with a sound and the blade glints red, and the attack type reads from the animation.
23. [x] As a player, I want to dodge out of the late recovery of my heavies, not only my lights, so that I'm never fully stuck after committing.
24. [ ] As a player facing a string, I want to be able to block or parry the later hits after taking the first one, so that one mistake doesn't cost me a whole string (there is no combo breaker).

### Katana

25. [x] As a Katana player, I want a string of four lights, alternating sides and ending in a crown cut, so that the Katana is the slashing weapon the design describes.
26. [ ] As a Katana player, I want my heavy to be the Iai Slash: pressing heavy sheathes the blade, I can strafe while holding it, and releasing draws a long-range slash, so that the Katana has its signature quick-draw.
27. [ ] As a Katana player, I want the Iai Slash to be vertical (from above) unless I'm holding left or right when I release, which makes it horizontal (right to left), so that I choose its shape.
28. [ ] As a Katana player, I want an optional heavy follow-up after each Iai Slash: a rising cut from below after the vertical one, and a left-to-right cut after the horizontal one, so that I can extend the string or stop.
29. [ ] As a Katana player, I want a fully held Iai (2.5 s) to release by itself as a power attack, as other charged heavies do, so that the charge rules stay consistent.
30. [ ] As a Katana player, I want Flash, Piercing Thrust and Swallow Sweep as block abilities and Moonsplitter as the ultimate, as in the demo, so that the Katana keeps its identity.

### Greatsword

31. [ ] As a Greatsword player, I want side-to-side light swings that ride the sword's momentum, with the second swing starting faster than the first, so that the weight shows.
32. [ ] As a Greatsword player, I want my heavy string to be an overhead strike followed by an optional unblockable low sweep, so that the greatsword has a feared finisher.
33. [ ] As a Greatsword player, I want my dodge attacks to be thrusts (a quick blockable stab on light, an unblockable skewer on heavy), so that attacking out of a dodge matches the design.
34. [ ] As a Greatsword player, I want Reaping Sweep, Mountain Slam and Guard Crusher as block abilities and Impaler as the ultimate, as in the demo.

### Twin Daggers

35. [ ] As a Daggers player, I want a four-light string that alternates hands (right slash, left slash, crossing cut, double stab), so that the continuity rule holds for two blades.
36. [ ] As a Daggers player, I want to dodge out of any light as soon as it connects or whiffs, so that the daggers slip in and out.
37. [ ] As a Daggers player, I want my heavy to be a dashing double stab that can flow into a spinning backhand, so that the daggers have a committal option.
38. [ ] As a Daggers player, I want my dodge light to be a passing cut that carries me along my dodge direction, so that I can outmanoeuvre the opponent.
39. [ ] As a Daggers player, I want Serpent Sweep, Shadow Step and Needle Thrust as block abilities and Lightning Tempest as the ultimate, as in the demo.

### Defending

40. [ ] As a player, I want parries to look cinematic, with both weapons visibly bouncing off each other, sparks, a ring and a distinct clang, as in Sekiro, so that a parry feels like a reward.
41. [x] As a player, I want the parry, block, posture, disarm, counter (stomp, leap, evade) and ultimate rules to work exactly as in the demo, so that what I learned still applies.
42. [ ] As a player, I want the warning mark and attack type (thrust, sweep, slam) to appear over an unblockable's attacker during the wind-up, so that I know which counter to use.
    > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The attack type reads from the animation, and as the wind-up starts a red 危 flashes with a sound and the blade glints red. Floating labels and floor markers appear only in Training.

### Fighters and look

43. [ ] As a player, I want real fighters with clothing, hair and a silhouette I can recognise, so that the game looks like the dark fantasy it's meant to be.
44. [ ] As a player, I want to choose between at least two fighters (the Rogue and the Hunter), each able to wield any of the three weapons, so that fighter and weapon are separate choices.
45. [x] As a player in a mirror match, I want the second fighter in a different colour scheme, so that I can tell us apart.
46. [ ] As a player, I want a toon look with ink outlines and a painted, ink-wash finish, so that the game has its own style.
    > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** A realistic look replaces it: physically based materials, dark lighting and volumetric fog under a painterly colour grade, after Ghost of Tsushima's darker side, with no toon shading, outlines or ink-wash pass. Ink survives only as calligraphy in the UI.
47. [ ] As a player, I want the arena to float above a dark fantasy, ancient oriental landscape of mountains, buildings and water, so that the setting feels grand.
48. [ ] As a player, I want weapon trails (white for normal attacks, red for unblockables, gold for ultimates), sparks on clangs, a glowing aura when an ultimate is ready and a marker on a dropped weapon, so that the fight stays readable.
    > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Combat effects become fully realistic (sparks, blood, dust, smoke and air smears), and the ink-brush weapon trails retire. The ultimate-ready aura is a smouldering glow of embers and heat haze in the side's colour.
49. [ ] As a player, I want hit-stop, camera shake on heavy blows and slow motion on the final blow, so that big moments land.

### Sound

50. [ ] As a player, I want metal clangs on blocks, a distinct ringing clang on parries, slicing hits, bone-and-rock crunches for the Greatsword, whooshes on swings and dodges, footsteps and arena ambience, so that combat sounds physical.
51. [ ] As a player, I want menu music at 100–120 BPM, battle music at 130–150 BPM and a faster match-point version at 150–170 BPM, so that the music matches the design.
52. [x] As a player, I want master, effects and music volume settings, so that I can balance the mix.

### Modes and controls

53. [ ] As a player, I want Training against a dummy whose behaviour I choose (idle, block, lights, heavies, thrust, sweep, slam, random, spar), with optional health refill and early/late parry feedback, so that I can practise. (23.1–23.3: the upkeep, the behaviours with the weapon each needs, and the panel and pause rows; the parry feedback comes with 23.4.)
54. [ ] As a player, I want Watch mode with a side-on cinematic camera, so that I can learn the moves by watching the computer duel.
55. [ ] As two players on one PC, I want Versus in a vertical split screen, each with our own camera and device (keyboard and mouse, the arrow-key layout, or a controller), so that we can play head to head.
56. [x] As a player, I want to remap every action for keyboard, mouse and controller, save named profiles, and see PlayStation or Xbox button names, so that the controls suit me. (22.10–22.12: the Controls screen's binding table, rebinding capture and profiles, played with in a match through the active profile; a profile picked in the pause menu's Controls is taken up on resume (22.15); Versus picks profiles with 22.16.)
57. [x] As a player, I want graphics presets, a reduce-flashes-and-shaking option and a button-hints option, so that the game runs and reads well for me. (The presets (16.5), the Settings rows (22.9), Button hints hiding the prompts (24.4), and Reduce flashes and shaking applied to the shake, the field-of-view kicks and the flashes, body flashes included (18.11). 18.12 moved to milestone 1, where the push-in and every new effect follow Reduce flashes as they land.)
58. [x] As a player, I want a move list generated from the actual move data, so that it's always correct. (22.13 and 22.14: `MoveList` walks the move data, and How to play shows it as a tab per weapon and bare hands; the pause menu opens it with 22.15.)

### Building and maintaining

59. [x] As the developer, I want the combat rules in plain GDScript with no graphics, stepped at a fixed 60 per second, so that they can be tested headlessly and later run online.
60. [x] As the developer, I want the rule tests to run from the command line and in CI, so that every change is checked.
61. [x] As the developer, I want the ported rules checked frame by frame against the original TypeScript rules on recorded inputs, so that I know the port is faithful before changing anything.
62. [x] As the developer, I want a soak run of computer-vs-computer matches that prints balance numbers, so that tuning rests on data.
63. [x] As the developer, I want fighters, weapon models, sounds and music referenced by data, so that replacing an asset means replacing a file and one entry. Note: the rules never load a model, so they keep their own copy of each weapon's blade and of the bare fist and foot (task 7.5). Replacing a weapon model or a fighter therefore also means updating those numbers in the weapon files; `tests/content/test_strike_segments.gd` fails and names each mismatch until they match.
64. [ ] As the developer, I want a Windows build produced by CI and attached to GitHub releases, so that the game is easy to share.
    > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** CI builds made without the asset repository use labelled stand-ins, so they aren't release builds. Real builds, playtests and releases always use the asset repository.
    > **Task 25.5 (Oct 4, 2026):** `npm run release -- <tag>` exports the release on the PC with the clips, checks it with `--smoke`, zips it as `Monomachia-<tag>-windows.zip` and attaches it to the tag's GitHub release. CI's Windows build is the `Monomachia-windows-stand-in` artifact, with `STAND-IN.txt` inside.
65. [x] As the developer, I want to capture screenshots of any scene from the command line, so that visual changes can be reviewed without clicking through the game.

## Implementation Decisions

### Decisions in plain English

| Decision | What we chose | Why | What it costs |
|---|---|---|---|
| Engine and language | Godot 4.7.2 (standard build), typed GDScript | Already installed; the engine's own language, with the best docs and tooling; plenty fast for a two-fighter duel | No C#; if online play ever needs it, the rules can use integer math **Superseded by ADR 0001 (Oct 4):** Godot stays, with a check: the first milestone judges whether Godot 4.7 reaches the look and animation bar, and the engine is reconsidered only if it clearly doesn't. |
| Where the code lives | A Godot project in a `game/` folder of this repo, beside the web version until the Godot build matches it; then the web code is deleted (tag `v0.1-web-mvp` keeps it) | The web rules act as the reference while porting | The repo briefly holds both |
| Rules layer | Ported line for line to GDScript first, proven identical on recorded inputs, and only then changed | A faithful port gives a safety net; changes are then deliberate and tested | The port is done twice over: once faithful, then changed |
| What decides a hit | The weapon's path: each attack says where the weapon travels, frame by frame, and a hit lands only when the blade's sweep touches the opponent's body | "Hitboxes as tight as possible to the weapon"; what you see is what hits | Every move needs a path; ranges and arcs change a little, so tuning follows |
| How attacks are animated | **Superseded by `docs/specs/authored-animation.md`:** authored clips (Kevin Iglesias, with UAL2 as a supplement), retimed to each move, and the hit path baked from the same clip. Was: the same weapon path moves the weapon on screen; the arms reach for the grip, and the torso and hips turn and lean with it | Procedural swings read as procedural (the spike's critique); the Iglesias packs have one- and two-handed, dual-wield and unarmed attacks | Frame data retuned to the clips; the converted clips can't be committed **Superseded by ADR 0001 (Oct 4):** Clips are no longer retimed; each attack's clip is edited until it lands inside its timing band, and its frame data are generated from it. The numbers measured from the Kevin Iglesias clips are committed with each move's source clip recorded, while the paid clips live in the asset repository. |
| Movement animation | **Superseded by `docs/specs/authored-animation.md`:** Iglesias directional walk, run, strafe, sprint and turn sets, combat idles, and a roll for the dodge; all procedural movement retired. Was: Quaternius walk, jog, sprint, idle, jump, flinch, knockdown and death clips, with procedural strafing, backpedalling, leaning and dodge poses on top | Real directional clips are now available | The guard shuffle and lean go |
| Fighters | Two of the eight to start: the Rogue (female Ranger outfit without the pauldrons, dark colours, hood, a cloth mask over the lower face, idling with her daggers in a reverse grip, though her attacks use a forward grip) and the Hunter (male Ranger outfit, dark brown with muted ochre, a tricorn hat and neck scarf instead of the hood, a scar). The mask, scarf and hat are built in code, since the packs have none. Any fighter can wield any weapon | They are the two fighters the free packs can dress convincingly; the tricorn is the Hunter's strongest Bloodborne cue and stops the two reading as the same hooded figure | The other six wait for their own bodies and outfits. Nothing flows yet: the packs have no capes or coats **Superseded by ADR 0001 (Oct 4):** For the first milestone the current bodies are re-textured in the realistic look; new stylised-real models on a UE5-style skeleton with twist bones arrive by the second, with capes, coats and loose clothing cloth-simulated. |
| Weapon models | Quaternius Medieval Weapons for the Greatsword (rebuilt at 1.72 m with a broader blade) and the Daggers, and a Katana built in code (curved single edge, round guard). Every blade has a dark body and a bright edge band, so it reads at any angle and at gameplay distance | The pack has no katana | Flat-colour weapons next to painted characters, softened by the shared toon shader **Superseded by ADR 0001 (Oct 4):** Every weapon is modelled in Blender to fit the game's themes, in the realistic look rather than the toon shader. The models set the blade lengths, and reach, spacing and balance are retuned to match. |
| Look | Toon lighting in three bands, ink outlines, and an ink-wash finish (paper grain, soft edge darkening, muted palette with red accents) | The art direction in the design doc | Shader work up front **Superseded by ADR 0001 (Oct 4):** Physically based materials, dark lighting and volumetric fog under a painterly colour grade, after Ghost of Tsushima's darker side. No toon shading, outlines or ink-wash pass; ink survives only as calligraphy in the UI. |
| Camera | Over the right shoulder, about 4.6 m back, 1.3–1.4 m to the side (0.9 m hid the opponent in the spike) when the fighters stand 3.5 m apart or more, swinging further out by 0.8 m for each metre closer (about 3.5 m at the closest) so the player never hides the opponent; low enough that blades read against the sky, 60° field of view, always locked on; side-on for Watch. On the shrine every match camera stays within 16.2 m of the centre, short of the lanterns, pillars and trees on the ledge, so with a fighter backed against the wall the camera comes in to about 1.6 m behind them | "Like For Honor, slightly more zoomed out"; in the playable skeleton a fixed 1.35 m hid the opponent's weapon side inside about 3 m | No free camera yet; up close the view turns partly side-on. Re-check the swing with the real fighters |
| Arena | The Moonlit Shrine rebuilt as a floating walled platform, radius 15 m (was 11.5), over a landscape of mountains, pagodas, waterfalls and water | "Larger", "suspended over a void", oriental backgrounds; walls keep the weapon-drop and knockback rules unchanged | Rounds may run longer; the soak run checks it |
| Fluid combat | Attacks keep half of your running speed instead of 30%; lunges ease in and out; colossal swings end with a short slide; heavies can be dodge-cancelled late in recovery; light hitstun drops from 18 to 14 frames so later string hits can be blocked or parried | These are the rule causes of the stiffness; the last one replaces a combo breaker | Balance shifts; the soak run and tests re-tune it **Superseded by ADR 0001 (Oct 4):** A fighter moves only as their clips carry them, so lunges and the colossal slide come from the clips' own steps, and dodge cancels open at markers on each clip. |
| Blocking walk speed | 60% of running speed (was 45%) | "Walk a bit faster while blocking" | Blocking slightly stronger |
| Parry | Same rules; new presentation: both weapons rebound from the contact point, with sparks, ring, clang and a brief camera push-in | "Cinematic, like Sekiro" | None to the rules |
| Sound | The best of the Sonniss bundle (clangs, swings, gore, ice cracks, wind, water, UI), trimmed and converted; generated sound for what it lacks (taiko, gong, parry ring layer, footsteps, bone crunch layers) | The bundle has no oriental percussion, parry ring or footsteps on stone | Generated sounds are simpler than recordings; they are easy to replace |
| Music | Placeholder tracks generated in code at 110 BPM (menus), 140 BPM (battle) and 160 BPM (match point), switching at the round call when either fighter has two wins | The bundle has no music; the design sets the tempos | Placeholder quality until real tracks are licensed |
| Controls | The demo's defaults and remapping, per player device, saved per profile on the PC | Same habits as the demo | Browser-saved profiles don't carry over |
| Tests and tools | GUT tests run headless; `npm test`, `npm run typecheck`, `npm run soak` and `npm run build` stay the entry points and call Godot | The commit gate in CLAUDE.md keeps working | Node stays installed as a task runner |
| Large files | Git without LFS; textures are scaled down to 2K or 1K and sounds converted to 16-bit before committing; raw Sonniss files are never committed | Keeps the repo simple; the Sonniss licence forbids redistributing its files as they come | A repo of roughly 100 MB **Superseded by ADR 0001 (Oct 4):** Paid and large source art, Blender files included, lives in a private asset repository with Git LFS for big files; the public repository keeps code, free-licence and self-made art and labelled stand-ins. Size budgets per place (a small public repository, a budget per asset in the asset repository, a target size for the shipped game) replace the 100 MB figure. |

### Architecture

**Two layers.** The rules layer knows nothing about graphics, input devices or sound: it is a set of plain GDScript classes (world, fighter, match, input tracker, computer brains and move data) advanced exactly 60 times per second. The presentation layer (nodes, animation, camera, effects, sound, menus) reads the rules layer's state and events and never changes them. A host node runs the fixed-step loop with an accumulator, applies slow motion by scaling the accumulator (not the engine's time scale), feeds each player's input, and gives the presentation an interpolation fraction, which it holds still during hit-stop.

**Faithful port first.** The TypeScript rules were ported module by module with the same names and numbers, including the known quirks (update order, last-write-wins hit-stop, JS rounding and the Mulberry32 generator). Two details made whole runs match bit for bit, and both stay:
- the rules keep positions in their own 64-bit vector classes, because Godot's built-in vectors are 32-bit;
- `game/sim/js_math.gd` computes `sin`, `cos`, `atan2` and `hypot` exactly as V8 does (a port of its fdlibm), instead of using the platform's C library.

The port was proven by:

- the 47 existing rule tests, rewritten for GUT;
- golden replays: a Node script ran the TypeScript rules on 29 scripted duels and 6 computer-vs-computer matches and recorded every event and each fighter's state per frame; a GUT test fed the same inputs to the Godot rules and compared them, within 1e-6 on positions (the margin covered Godot's JSON reader, not the rules) and exactly on events;
- the Godot computer opponent producing the recorded inputs for all six matches, and the 40-match soak and the counterlab printing the same numbers as their TypeScript versions.

The goldens guarded the faithful port only. Commit 4222167 is the last one proven bit for bit: there the two soaks and the two counterlabs still printed identical reports (recorded in the plan's Progress). Task 8.2 then retired the goldens, the brain-parity checks and the whole-run hashes, before the first deliberate rule change, and the rules are now guarded by tests of their behaviour.

**Events.** The rules layer keeps emitting the demo's events (swing, telegraph, hit, block, parry, counter, disarm, and so on). The presentation, sound and HUD consume them, and tests assert on them.

**Move data.** Each weapon's moves stay a table of numbers in its own data file, as in the demo, with the same defaults applied at load. New fields:

- `swing`: the weapon path (see below);
- `side_start` and `side_end`: which side the weapon starts and ends on, used to check string continuity;
- `dodge_cancel_from` on heavies;
- `charge_move`: a charge the fighter can walk during, at block speed, and that a dodge cancels (the Iai stance);
- `release_variant`: the move a chargeable heavy turns into, on the same attack, when it is drawn with the stick held left or right (the horizontal Iai); it keeps the move's frames and lunge;
- `lunge_along_dodge`: a dodge attack that lunges in the dodge's direction instead of facing forward (Passing Cut). The fighter remembers the direction of its last dodge or backstep, and the lunge holds back only the part of each step that closes on the opponent: that part stops with the bodies 0.25 m apart, while the part across the line to them carries on.

Chains stay as they are: each move names at most one light follow-up and one heavy follow-up, and pressing nothing ends the string.

**Sides.** A side is left, right or centre, from the fighter's own point of view. A follow-up starts on the side the move before it ends on, except that a move starting at centre (an overhead, a thrust, a stab, a spin, the crossing cut) may follow any end. Every move in a string has both sides; other moves leave them unset. A release variant stands in for its move, so it is in that move's string. Built for the Katana (task 9): Right Cut, Kesa Cut, Rising Heaven and the horizontal Iai Slash run right to left; Return Cut, Returning Draw, and the vertical Iai Slash drawn from the left hip, left to right; Crown Cut and Heaven Splitter centre to centre. For the Greatsword (task 10): Heavy Swing runs right to left, Backswing left to right, Overhead Strike from centre to the right, and Low Sweep, which follows it, right to left. For the Daggers (task 11): Quick Slice runs right to left and Off-hand Slice left to right, and Twin Rip, Flurry Finisher, Twin Fang and Spinning Backhand centre to centre.

**Weapon swings.** A swing is a short list of key poses in the fighter's own space, covering the whole move: wind-up during startup, strike during the active frames, follow-through during recovery. It has a track of keys for each part it moves: the weapon hand (each hand, for the Daggers), a foot for a kick, and the body. A hand's keys hold:
- the grip position;
- the blade and edge directions, which set the hand's frame, since the grip is rigid, and so must stay within the wrist limits;
- an optional tweak of the elbow's pole.

The body's keys hold the torso and pelvis coil and the pelvis shift, so the hips can be keyed to lead the hands, and a swing with two hands still has one coil.

Between keys, the grip travels on an arc around the fighter's body, not in a straight line, and the blade turns with the hands, not on its own. The hands arc around the middle of the shoulder line, 1.44 m up and 6 cm back from the feet (the Rogue's shoulders are at 1.42 m and the Hunter's at 1.46 m), and a foot around the middle of the hips; both points sit on the spine, so a coil doesn't move them. A key with ease 0 holds still, and the grip's distance from the pivot, the coils and the pelvis shift never overshoot their keys.

The early spike (see the plan) proved this works on the Quaternius fighters and set the rules every swing must meet:
- wrist bend within about ±60° and deviation within ±25°;
- the blade never within 5 cm of the fighter's own body;
- a 2–4 frame cocked hold before the strike;
- elbows at 150–160° at contact, never locked;
- each move's end pose is a natural start for its follow-up;
- slash, overhead, thrust and sweep are told apart from the gameplay camera in the first third of the wind-up.

The body rules are checked headless on a reference body for each fighter, and every swing must pass on both, since the Rogue and the Hunter differ in proportions. A reference body is the fighter at rest, as rules data:
- the shoulders, and the upper-arm and forearm lengths, for solving the elbows;
- the spine, from the middle of the hips to the middle of the shoulders;
- capsules round the torso, the head (with the Rogue's hood or the Hunter's tricorn), the thighs and the arms, each covering the parts of the body its bones move. The Hunter's left upper arm is wider for his pauldron. The head's capsule ends at the crown, so the top of a hood or the back of a hat pokes out of it by up to 4.4 cm, still inside the 5 cm the checks keep a blade from the body.

The torso coil turns the torso and the shoulders about the spine, and the pelvis coil turns the thighs at the hips. The head keeps facing ahead and the knees stay planted, and the pelvis shift carries everything above the knees. A content test measures both fighters again and keeps the numbers within 1 cm.

The checks look at every quarter frame of a swing, entered from the guard and from each move that chains into it, through the exit:
- each hand sits on its grip as the fighter rig seats it, turned round the handle so that the hand carries on the line of its forearm, and each elbow bends toward the rig's pole (out, down and back from the shoulder, turning with the chest), plus the key's tweak;
- so a wrist doesn't bend back or forward, and it may turn ±25° sideways from straight, where straight puts the forearm square to the handle. An elbow at 170° or straighter is locked, and a grip out of the arm's reach fails;
- a blade keeps 5 cm, beyond half its thickness, from the torso, the head, the thighs and both arms, though not from the fist and forearm that hold it;
- in the wind-up neither grip passes in front of the face: within 12 cm of a line from the middle of the head, 60 cm straight ahead.

A weapon held in both hands puts the off hand on its off-hand grip, which the rules copy from the model's marker as they do the blade.

Swings are stored as sampled data, so a move can later take its path from an authored clip instead of hand keys, with the rules unchanged. The keys live in one JSON file per weapon, `game/sim/moves/swings/<weapon>.json`, read when the weapon is built, and the rules expand them to per-tick samples. The file also holds the weapon's guard: a pose for each part its swings move. A move enters from the guard, or, as a follow-up, from the last key of the move before it (its hand-off pose), and exits back to the guard on its last frame. Its own keys run from the last frame of the wind-up through the last active frame at least, and are splined on their own, so its hits are the same however it was entered. A follow-up's first key is within 2 cm and 10° of the previous move's hand-off pose, so a string flows from one cut into the next. Positions and directions are (right, up, forward) from the fighter's feet, and every key has an ease (0 holds still there, as in the cocked hold). A file with any mistake (an unknown field, keys out of order, a frame past the move) is refused whole, with an error, so a weapon never plays on half-read swings. The swing editor writes the files back with a stable key order and fixed decimals. Swings are built from a small set of named shapes (right-to-left slash, left-to-right slash, rising and falling diagonals, overhead, thrust, low sweep, spin, stab, plus a few specials) with per-move tweaks.

Each weapon supplies what its swings strike with, a strike segment in its own frame. A blade runs from where its cutting part starts to its point, as the model's BladeBase and BladeTip markers place them; the rules never load a model, so a content test keeps the two within 1 cm. Its thickness is the model's, out of the flat, at its thickest between the markers (within 1 mm, also kept by the content test): 1.5 cm for the Katana and 1.4 cm for a dagger, both at the collar (the blades themselves are 7 and 5 mm), and 2.2 cm for the Greatsword. So a blade that passes more than about a centimetre off the capsule misses, as it visibly does. The edge's width and the Katana's curve lie in the plane of a cut, where the sweep covers them. Bare hands strike with the fist, across the knuckles (7.6 cm thick, enough for either hand of either fighter), and kick with the foot, along the boot from heel to toe with its underside on the sole (10 cm thick). A foot track's grip is the ankle, its blade runs along the foot and its edge out of the sole.

- The rules layer takes the blade segment at consecutive ticks and tests the swept quad between them against the defender's hurt capsule. Each tick, once the fighters have moved and been pushed apart and just before hits are decided, every hand and foot track of the attack's swing is placed in the world from its pose at the attack's frame and the fighter's position and facing. The last tick's place is kept beside it. A charge holds the pose, as do frames past the swing's end and hit-stop, and an attack's first tick sweeps nothing. Between the ticks each end of the blade travels in a straight line; a blade that turns out of the plane it travels in makes a twisted quad, which is taken as two flat triangles. The sweep touches when any part of it comes within the capsule's radius plus half the blade's thickness of the capsule's axis, so even a blade moving 0.6 m in a tick can't pass through unseen. Its contact point is its point nearest the axis, where the blade went deepest; its depth is how far that is inside the capsule's surface, and its length inside is the most blade inside the capsule at any moment of the tick, which the reach tests measure. The capsule is part of each fighter's rules data: 0.35 m in radius from the feet to 1.75 m for the first two fighters, raised with the fighter when they jump. A fighter built without an id (the rule tests, the soak run) gets a default body of the same size. The capsule is separate from the 0.42 m radius that keeps the fighters apart. The hit lands on the first tick the sweep touches the capsule inside the active frames, in the same outcome order as the demo (counters, jumped, flash, evade, parry, block, hit): the touch takes the place of the demo's range-and-arc cone, and a swing that never touches whiffs. A move without a swing keeps the cone until it has one, so the Duel plays as before while swings are authored. Hit, block and parry events carry the contact point, where the sparks and the parry rebound start. Moves without a swing and scripted hits (the ultimates' waves, Impaler, Tempest) keep the demo's point, halfway between the fighters at 1.25 m.
- Reach comes from arm extension and lunge (0.7–0.8 m on lights, with the front foot landing on the contact frame), so that the last 15–20 cm of the blade enters a defender standing at the weapon's duelling distance: 2.5 m for the Katana (the demo's duelling distance), 3.0 m for the Greatsword, 2.0 m for the Daggers and 1.6 m for bare hands, kept in each weapon's rules data. "The last 15–20 cm" is the most blade inside the defender's capsule at any moment of the active ticks, played from standing at a standing defender. Each light of the string must also end its lunge on the frame it first touches, and whiff from 6 m. Every other move with a swing must touch a standing defender from its distance in the table of test distances below.
  > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Each weapon now has a distance band set by design, and a clip that falls short is re-keyed with a longer step or reach, never slid. The Blender weapon models set the blade lengths, and reach is retuned to match.
- Unblockables use a thicker blade for their longer reach: their sweeps add 10 cm to half the blade's thickness (`UNBLOCKABLE_SWEEP_BONUS`), so they reach 10 cm further than the same swing would. Presentation reads the same value for the reach shown on the warning mark.
- The counters (stomp, leap, evade), which the demo made deliberately generous, keep their generous cone checks, now measured from each move's path.
- Each move's reach and arc, which the computer opponent and the move list use, are computed from its path at load. The reach is how far the blade gets across the ground from the fighter's feet through the active frames, plus half the thickness its sweep tests, without the lunge, as the demo's range was. The arc is twice the blade's widest bearing from the facing over those frames, or 360 when it passes behind. The weapon's reach, which the computer keeps to, comes from its light starter's, and the training dummy keeps that distance once the starter has a swing. The rules can also play a move at a standing defender at any distance and bearing, lunge and turning included, for the frame it would first touch and how deep.
- Ultimate projectiles and scripted hits (the Moonsplitter wave, Impaler, Tempest) keep their own checks.
- A debug view draws, over the match, each fighter's hurt capsule, the blades where the rules hold them, each active tick's sweep (kept for about a second) and where each hit, block, parry or whiff landed, coloured by outcome. It is turned on by F3 in a debug build or by `npm run play -- --swing-debug`, and the `swing_debug` shot scene shows a hit, a block and a whiff.

**Test distances.** How far apart, centre to centre, each kind of move is tested from, played from standing at a standing defender (task 7.14; `game/tests/sim/reach_table.gd` holds the same table). D is the weapon's duelling distance. A kind's offset is how much further the demo's moves of that kind reached from standing (range, a fighter's radius and the lunge) than their weapon's first light, the median over the four weapons to the half-metre, so each kind keeps its place in its weapon's range as real blades replace the demo's cones. In play, sprint, dodge and backstep attacks start out of movement and reach further.

| Kind of move | Tested from | Katana (D 2.5 m) |
|---|---|---|
| Lights of the string | D, with 15–20 cm of blade inside | 2.5 m |
| Heavies: the heavy string, its variants and follow-ups | D + 0.5 m | 3.0 m |
| The Iai Slashes (vertical and horizontal) | 3.6 m, their own | 3.6 m |
| Sprint light | D + 1.5 m | 4.0 m |
| Sprint heavy | D + 2.5 m | 5.0 m |
| Dodge attacks, light and heavy | D | 2.5 m |
| Backstep light | D + 0.5 m | 3.0 m |
| Backstep heavy | D + 2 m | 4.5 m |
| Jump attacks, light and heavy | D − 0.5 m | 2.0 m |
| Counter lunge | D + 2 m | 4.5 m |
| Unblockable block abilities | D + 1 m | 3.5 m |
| Other block abilities (Guard Crusher) | D | |
| Breaker Palm (bare hands' ultimate palm) | D + 2.5 m | |

Zero-damage stances (Flash, Shadow Step) strike nothing and aren't tested. The ultimates' scripted hits keep their own checks.

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** A fighter now moves only as their clips carry them, jump arcs excepted, so the eased lunges and the colossal slide below give way to the clips' own steps. Dodge cancels open at markers on each clip, not at a frame worked out from the recovery.

**Rule changes after the port** (each with tests, then a soak run):

- Arena radius 15 m, with the values the demo hard-coded to the old radius tied to it (built in task 8.3): the Impaler's dash ends 0.7 m inside the wall (was 10.8 m from the centre), dropped weapons bounce 0.8 m inside it, the camera stays within the radius plus 4 m without arena data, and the soak counts a fighter more than 0.5 m past the wall as a failure. The Moonsplitter wave reaches 2 × radius + 3 m (33 m, was 26 m), so it still crosses the whole stage: the widest gap between two fighters is now 29.16 m. With the rules at 15 m the Moonlit Shrine is every match's arena.
- Blocking walk speed 60% of run speed (was 45%).
- Attacks keep half of the current velocity as they start (was 30%), and jump attacks and hop attacks keep all of it; lunges ease in and out over the same frames and distance.
- Colossal swings slide on 0.35 m over their first 10 recovery frames, easing out, on a hit, a block or a whiff: every grounded Greatsword attack, block abilities and Leaping Smash included, except the bashes (Shoulder Charge and Guard Crusher). The slide stops with the bodies 0.25 m apart, like a lunge, and ends with the attack, so a dodge cancel cuts it off. It runs along the facing until the swing paths give it the swing's direction.
- Heavies accept a dodge cancel in the second half of their recovery: from startup + active + half the recovery, rounded up. A charged heavy's cancel opens later by half its extra recovery. The movement attacks' heavies have one too. There is no cancel in the air, and block abilities, specials and ultimates get none.
- Light hitstun default 14 frames (was 18), so that from the second hit on a defender can block or parry, and strings are no longer guaranteed after the first hit. It applies to every light without its own hitstun, the movement attacks and counter lunges included. Two exceptions: bare hands keep their own 16 on their first two lights, so their early hits stay guaranteed, and the Daggers' four string lights, which follow each other faster, stun for 10 frames (task 11.1): Off-hand Slice lands 11 frames after Quick Slice, so 10 leave the defender one frame to block or parry it, as 14 do before the Katana's Return Cut. The Daggers' other lights, the movement attacks and Counter Lunge, keep 14.
- The new strings (next section).

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Tuning moves into the slice plan, where every weapon is rebalanced around its clips at the slower pace, each as its animation lands.

Task 8 built the rules above. On them the first 300-match tuning run (12.1) has rounds of 39.9 s, 0.74 disarms per round, and win rates against the other weapons of 48.5% for the Katana, 37.4% for the Greatsword and 62.8% for the Daggers. So disarms and the Greatsword's and the Daggers' win rates are outside the targets under Testing Decisions; task 12 tunes toward them (the plan's Progress has the numbers).

**Presentation of fighters.** The authored-animation feature (`docs/specs/authored-animation.md`) replaces most of what follows:
- authored clips replace the procedural swings, the guard shuffle, the hip-turn strafing, the lean and the dodge poses;
- the weapon is fixed to the main hand;
- the swing editor, blade lag, the procedural parry bounce and the ghost trail are retired.

The bullets below describe the build up to that feature.

- Each fighter is a scene built from the Quaternius base body (head only, cut from the full body at import), the outfit parts, hair, headwear built in code and palette, all on the shared 65-bone skeleton. Animations are retargeted through Godot's humanoid bone map.
- The two palettes differ over a large area seen from every side (the Rogue's second palette swaps dark for ash on the hood and sleeves), not just in trim. The outfit textures are baked with wear: ambient occlusion, dust up the boots and trouser hems, scuffed knees and cuffs, worn leather edges and grime. Faces get soot and shadowed eyes.
- Fighters and weapons are drawn in the toon look. Their imported materials become toon materials when a model is built, keeping the textures, the vertex colour and the palettes. Normal maps are kept at 40%, since full-strength bumps break the toon bands into blotches. The hoods, cloth edges and hair cards are drawn from both sides, as the imports are, and the fighters' rim is narrow, so dark cloth doesn't read as glossy. The Katana's blade and grip keep their own toon-lit shaders.
  > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The toon materials retire. Fighters and weapons get physically based materials in the realistic look, starting with the current bodies re-textured for the first milestone.
- A weapon is never fixed to a hand. It is posed in the fighter's own space, and the arms reach for it with inverse kinematics: the main hand on its grip, the off hand on a two-handed weapon's second grip, each dagger in its own hand. Each hand is turned onto the handle, and round it toward its forearm so the wrist doesn't bend back, with part of the twist taken by the forearm, and the shoulder comes forward near full reach. Each fist closes round its own handle: the fingers curl joint by joint to wrap that handle's thickness, measured on each fighter's hand, and the thumb closes over it.
- Until swings exist, the match poses the fighters from the demo's stick poses: the hands and blade directions place the weapon (pulled in to keep the elbows bent, since the poses were made for a stick figure's reach), the lean bends the spine, the crouch bends the knees over planted feet, and a knock-out plays a fall clip. The clips play on the rules' clock, so they hold still in hit-stop and pause. A hit, disarm or knock-out flashes the whole body, and an unblockable's wind-up lights the blade red, as overlays over the toon materials.
- Until the guard poses exist, a weapon that isn't posed is carried in the fist, as each fighter's stand-in hold for it says: the clip it idles in, how the weapon sits in the fist and which wrists are set. The Rogue idles low with her daggers reversed along her forearms; the Hunter idles in a raised guard with the greatsword trailing from his hanging hand.
- An animation tree blends idle, walk, jog and sprint by speed: idle at rest, the walk at about 1 m/s, the jog at the fighter's running speed and the sprint at its sprint. Every clip plays from one shared step phase that moves a stride per cycle, the strides measured from each fighter's own clips, so the feet stay in step and planted; the phase moves once per rules frame, so the legs hold still in hit-stop and pause. Unguarded strafing and backpedalling turn the hips and legs toward the direction of travel, at most 80° and on a spring, while the chest keeps facing the opponent; travelling more than about 100° from straight ahead, the legs turn toward the opposite way and the cycle runs backwards. While the legs move, the running clips' own swing of the shoulders is taken out, so the upper body stays square to the opponent with the weapon in its hands.
- Guard walking, where duels spend most of their time, is a procedural shuffle step instead: the lead foot moves first, the trailing foot closes, the feet never cross and the stance width holds. The stance is grounded, with knees over toes, the right foot in front pointing at the opponent, the rear foot turned out 30–45°, the pelvis lowered, and the weight shifting slowly between the feet.
  - A weapon with a guard stance (the Katana) shuffles whenever the fighter isn't running with its guard down: standing, walking while blocking or in the Iai stance, tap-stepping and braking.
  - One foot steps at a time. The first is the one on the side the fighter travels to, and the other closes after it. Each lands near its spot at the stance's angles and keeps clear of the mid-line. Planted feet stand still on the ground.
  - The cadence follows the speed: about 4 steps a second at 0.5 m/s, and 9 at the guard's 2.34 m/s. The feet lift a few centimetres.
  - The pelvis bobs with the stance's spread, and sinks when a leg would otherwise not reach its planted foot. The weapon follows the bob on a slight spring.
  - The footsteps fall where the feet come down. Running with the guard down, they fall every stride.
  - Running with the guard down hands the legs to the clips over a few frames, and stopping hands them back.
- A lean follows acceleration, at most 11°: forward setting off, into a turn when circling the opponent, and back when braking, with the hips dropping into a brace; it settles within about a third of a second once the speed holds, and the weapon rides with the upper body.
- Attacks, blocks, parries and guard stances are procedural upper-body layers: the weapon follows its swing, both arms reach for the grip with inverse kinematics (the left hand only on two-handed weapons), and the spine and hips turn toward the swing, with the hips leading so the motion ripples from hips to hands. The pelvis dips on impact.
- Weight comes from the presentation:
  - blade lag on a spring;
  - follow-through overshoot and settle;
  - a pelvis dip and camera kick on contact;
  - hit-stop holding both fighters still.
- Reactions are their own system, because weapon paths don't animate the defender:
  - flinch clips plus a recoil away from the hit direction;
  - block impacts;
  - knockdown and death clips;
  - dodge and backstep poses with a ghost trail;
  - the parried attacker's weapon bouncing back along its path.
- Dropped weapons are separate meshes.
- Swings are keyed in a small editor plugin that scrubs a move frame by frame on a fighter, so they can be tuned by eye rather than by editing numbers.

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The toon material, ink outlines and ink-wash pass give way to physically based rendering under a painterly grade, with temporal anti-aliasing, subtle bloom, ambient occlusion, fog and light film grain in play in place of FXAA and glow off. Four presets replace these three: Ultra at 4K and 60 fps on an RTX 3090 is the reference preset, and Low must hold 60 fps at 1080p, rendered at about 720p and upscaled, on the Ryzen 7 4700U laptop. The Moonlit Shrine is upgraded in place, and its distant landscape becomes real 3D (sculpted mountains and cliffs, pagoda and temple models, volumetric fog and clouds).

**Look.** One toon material for everything, with a three-band light ramp and a rim light, and inverted-hull ink outlines sized in screen pixels, which thin out only far away. Outlines are always on for fighters and weapons, and on props only on High. (Godot's built-in stencil outline was tried and not used: it draws the silhouette only, its width is fixed in metres, and it needs a StandardMaterial3D.) The shaders fetch a small generated noise texture instead of computing noise, which is much cheaper on integrated graphics. A full-screen ink-wash pass paints distance mist, ink lines 2 px wide where depth breaks, paper grain and a brushy vignette over the image without copying the screen. The colour grade (muted colours that keep the fighters' red and blue, cold shadows, ink rather than pure black) is baked into the environment's lookup table, so it costs nothing per frame. Three graphics presets, Low, Medium and High (the default), turn up or down the outlines on props, the shadow map's size and reach, height fog, particle counts, lantern lights, distant scenery detail and the ink-wash pass (off on Low, ink lines from Medium, the full pass on High). The chosen preset is saved with the player's settings (`user://settings.cfg`) and applied at start. To hold 60 fps at 1080p on High on the target laptop (Ryzen 7 4700U with Radeon Vega graphics), every preset uses FXAA instead of MSAA and leaves glow off. Benchmarked there with the real fighters fighting on the Moonlit Shrine (`tools/shot_scenes/arena_bench.tscn`), High runs 69 fps from the gameplay camera (14.6 ms a frame, 15.3 ms at the 95th percentile) and 66 fps from the Watch camera, which takes in the most of the arena; Medium runs 79 fps and Low 102. The sky, clouds, mountains, pagodas, waterfalls and water are built in code and shaders from simple shapes, so they can be swapped for bought art later. The shrine's props and buildings already can be: a scene in its layout's `prop_scenes` replaces the procedural lanterns, torii, pillars, trees, floating rocks, pagodas or temple halls at the same spots. Cameras above the courtyard leave out the rock under it, which they can't see, each camera deciding from its own position, so split screen keeps the saving.

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Combat effects become fully realistic (sparks, blood, dust, smoke and air smears), and the ink-brush trails below retire. The ultimates keep their supernatural energy (fire, lightning, shockwaves, spirit energy), lit and rendered realistically.

**Combat effects.** One effects layer (`CombatEffects`, a child of the match view) draws the match's flashes, rings and particles, each kind from a fixed pool on one MultiMesh, so effects never add nodes. Each effect is worked out from its age on the effect clock, the world frame on show (the frame before the last step plus the host's alpha), so effects hold through hit-stop and pause, run at 0.3× in the KO's slow motion, stay smooth between steps on a fast display, and a shot taken at a given frame always looks the same. An event table (`EffectTable`) says which effects each rules event spawns at its contact point; a contact flash is a soft camera-facing glow that grows and fades. Everything clears at round start. Combat particle counts follow the graphics preset's particle ratio but never drop below half, so hits still read on Low. A blade trails (`TrailState`) in its move's active frames and fades over the next two, never while charging and never for Flash; only the hands the move strikes with trail (one dagger or both), and bare hands never do. The trail is red for unblockables, gold for the ultimates and the counter lunges, and white otherwise. The ultimates trail where the demo's did: the Moonsplitter's first six frames of release, the Impaler's dash, and the Tempest's spin and the second half of its finisher. Each trailing blade draws a brush stroke (`WeaponTrail`, one per side and hand): a ribbon over its weapon's trail width back from the tip (Katana 0.55 m, Greatsword 0.9 m, Daggers 0.2 m), swept through the last 8 frames of the effect clock and smoothed between frames, which tapers toward its tail and fades with age. It is alpha-blended: the trail's colour (white `#dfe6ff`, red `#ff3020`, gold `#ffc040`) in bristle streaks that run dry toward the tail, darkening to a ragged ink edge on the tip side. The blades are read from the held weapon models' markers as posed, so the trails follow whatever poses the weapons.

**Sound.**

- An event-to-sound table (`game/audio/sound_bank.gd`) picks randomized variations and sends them to buses (Master > Music, Ambience, SFX > Arena reverb > Combat, Foley; UI); impacts play in 3D, every combat and foley sound passes through the arena's reverb, and the music and ambience duck a few dB under loud combat sounds.
- A Node script (`npm run audio:sonniss`) extracts the chosen Sonniss clips from the zips, trims, pitches and layers them, converts them to 16-bit mono at 44.1 kHz (the arena ambience is a stereo 60 s loop), and writes them into the project with a sources list (`game/assets/audio/SOURCES.md`).
- A second script (`npm run audio:synth`) generates the missing sounds, and a third (`npm run audio:music`) the placeholder music as seamless stereo loops whose tempos are listed in `game/assets/audio/music/tracks.json`.
- A music director (`game/audio/music_director.gd`) picks the menu, battle or match-point track; the switch to match point happens at the round call when either fighter has two wins. The loops start mid-signal (the tail of the last bar wraps into the first), so the player fades a track in and out over 10–20 ms whenever it starts, stops or switches one.
- The variations the sound bank picks between for one event are matched in loudness (their loudest 100 ms, with a peak ceiling), so no variation stands out.
- Only the processed files are committed, under 40 MB in all.

**Input.** Each player reads one device: keyboard and mouse, the arrow-key layout, controller 1 or controller 2. That player's profile maps the device to the demo's eight rule buttons plus pause. Profiles are saved in the user folder (`user://controls.cfg`). Controller button names follow the detected controller. One set of devices and profiles lives for the whole game in the `GameServices` autoload, which pauses a match when the window loses focus.

**Screens.**

- Title (with a live background duel), main menu, fighter and loadout select (per side: fighter, weapon, two block abilities, computer difficulty; devices and profiles in Versus), controls, settings, how to play and move list, pause, results, and the HUD.
- The UI uses an ink-wash theme with the demo's fonts (Zen Antique, Zen Kaku Gothic New; open font licence), bundled. It is the project theme (`ui/theme/ink_wash.tres`), with the demo's palette (`UiPalette`): text in Zen Kaku Gothic New on paper; titles, buttons and kanji in Zen Antique; label variations (`UiTheme`) DisplayLabel, KanjiLabel (lacquer), EyebrowLabel (spaced, in the dimmed paper; `UiTheme.label` sets it in capitals) and MutedLabel; buttons as the demo's (ink in a gold-dim border, gold when focused, lacquer when pressed, as its primary button); menu entries (MenuEntry) with the demo's lacquer wash and bar when focused or hovered; and panels of ink in a thin line (without the demo's gradient and gold inset line). The fonts and their licences are in `game/ui/fonts`. Neither font has "✕", so the PlayStation cross is named "×" (the demo's "✕").
  > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The menus and HUD are redesigned for the realistic look, replacing the ink-wash theme; the layout stays, and the style is picked from a UI page of the mood board. Ink survives only as calligraphy: brushed kanji and titles in the menus, the HUD and the round calls.
- The HUD's top bar is the demo's: each side's plate (the 赤 or 青 seal, name, weapon and a boxed Disarmed tag), HP with its slanted end, gradient, white lag band (held 0.45 s, then draining 0.6 of the bar a second) and pulse at a quarter or less, posture with its caption, hot at 70% and blinking red when full, three diamond pips, the 奥義 badge (hidden, ready with a glow, or used and struck through), and the round's kanji over "Round N". `HudState` works out what each side shows from the fighter's numbers, with no nodes, for tests. Its sizes are the demo's scaled to the game's 1600 × 900 canvas, and the bars keep fixed widths rather than shrinking with a narrow window.
- The HUD's announcements are the demo's: a kanji in lacquer over the words, with a subline under them, a third of the way down (第N戦 Round N, with Final round at two rounds each; 始め Fight; 一本 K.O.; 相打ち Double K.O.; 勝 or 敗 with the round's result, Perfect or a replay; 武器喪失 Disarmed, with advice to the player). Each lasts the demo's time in rules frames (Round 78, Fight 54, K.O. 120, Double K.O. 132, the result 96 after a 78-frame wait, Disarmed 90), and the demo's entrance (fading in while shrinking from 1.35, holding, fading out while easing to 0.98) runs its 1.3 s on the rules' frames whatever the call's length, so a pause freezes it and slow motion stretches it. The demo's blur in is left out. Versus wording ("X lost their weapon" and the like) comes with 23.7.
- Training keeps itself going in the rules (`TrainingUpkeep`, stepped inside the fixed step): a fighter knocked out gets up at once with full HP, empty posture and its ultimate back; with refill on (the default for every new Training, kept through Restart), from 90 frames after a fighter was last hurt its HP refills 2 a frame, the dummy's posture drains 2 a frame, and full HP gives the ultimate back; the dummy re-arms once it has been disarmed and unhurt for 240 frames (the demo counted from the last hurt alone). The player picks up their own weapon.
- Choosing the dummy's behaviour (`MatchHost.set_training_behaviour`) swaps its weapon in the rules when it can't perform it: to the first weapon in the select's order that can (Thrust: the Katana; Slam: the Greatsword), worked out from the abilities' counter kinds, and back to the weapon picked in the select whenever that one can. The swap lets go of an impale, ends any state of the old weapon, arms the dummy with the new weapon's default abilities and takes its old weapon off the floor; the dummy's model and its HUD plate follow. Restart keeps the behaviour.
- Training is chosen on the main menu and set up through the select, where the dummy picks only a fighter and a weapon. In the match, a panel at the bottom left shows "Dummy · <weapon>", the nine behaviours numbered 1–9 and refill numbered 0; the top-row digit keys and clicks change them, unless the player's profile binds that digit to an action. The panel hides while paused, where two rows at the top of the pause menu (the dummy's behaviour, Refill health) do the same for controller players.

**Build and tools.** The npm scripts become a task runner (`scripts/godot.mjs`). It finds Godot through a `GODOT` environment variable, then `godot` or `godot4` on PATH, then an untracked `.godot-path` file holding the executable's path. Until the web code was deleted, `test` and `typecheck` ran the web and Godot checks side by side, and the Godot soak, run and editor commands were `soak:godot`, `godot:run` and `godot:dev`. Since then (plan task 26.3) the scripts are:

- `test`: the Node tools' tests (`test:node`, on `node --test`), then GUT headless (`test:godot`).
- `typecheck`: loads every script and fails on any error.
- `soak`: headless computer-vs-computer matches with balance numbers and the targets; `soak:tune` runs 300 for tuning.
- `counterlab`: how often the computer lands each unblockable's counter.
- `build`: Windows export, with the licence, credits and notices beside the exe.
- `release`: on the PC with the clip libraries, exports, plays `--smoke`, zips and attaches the build to the tag's GitHub release.
- `play`: plays the game.
- `dev`: opens the editor.
- `studio`: opens the Animation Studio.
- `shots`: renders chosen scenes to PNG in a window, and fails on any shader or script error.
- `godot`: the runner itself, for its other commands (`npm run godot -- help`).
- `check:sizes`: fails on any tracked file over 10 MB that isn't allow-listed, and prints the asset and repo sizes.
- `audio:sonniss`, `audio:synth` and `audio:music`: rebuild the sound effects and music.
- `brain`, `brain:serve` and `board`: the second brain and the Project Manager, which are Node tools.

`package.json`'s version follows `project.godot`'s.

The exported game takes a `--smoke` flag: it plays a Watch match to the results and exits 0, or 1 on any error, stall or timeout.

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** CI builds made without the asset repository use labelled stand-ins. Real builds, playtests and releases always use the asset repository.

CI installs Godot 4.7.2 and its export templates, checks the file sizes, runs tests and a short soak, and uploads the Windows build. CI has no GPU, so its build is exported headless without baked shaders and compiles them on first use; a build from `npm run build` on a PC has them baked. The Pages workflow is removed, and the Release workflow uploads a zipped Windows build.

### The new strings

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Each attack's frame data and footwork now come from its clip, edited until it lands inside its timing band at a slower, For Honor-like pace (a Katana light lands in roughly 400–500 ms). The frames, lunges and slides below give way to a table generated from the clips, with no hand overrides.

"→" is a chain; every chain is optional. Frames are startup / active / recovery at 60 per second.

**Katana**

| Move | Input | Shape | Frames | Damage / posture | Notes |
|---|---|---|---|---|---|
| Right Cut | light | right-to-left slash | 11 / 3 / 16 | 6 / 7 | → Return Cut (light), → Heaven Splitter (heavy) |
| Return Cut | light, light | left-to-right slash | 10 / 3 / 16 | 6 / 7 | → Kesa Cut (light), → Rising Heaven (heavy): the L-L-H |
| Kesa Cut | 3rd light | right-shoulder-to-left-hip diagonal | 11 / 3 / 17 | 7 / 8 | → Crown Cut (light), → Heaven Splitter (heavy) |
| Crown Cut | 4th light | overhead | 14 / 4 / 22 | 8 / 10 | end of string |
| Iai Slash (vertical) | heavy (release) | sheathe, then vertical draw from above | 14 / 4 / 24 after release | 13 / 16 | Hold to stay sheathed and strafe at block speed; auto-release at 2.5 s as a power attack; reach about 3.6 m; → Rising Heaven (heavy) |
| Iai Slash (horizontal) | heavy released with left or right held | right-to-left draw | 14 / 4 / 24 after release | 13 / 16 | → Returning Draw (heavy), → Return Cut (light) |
| Rising Heaven | heavy follow-up | low-right to high-left rising diagonal | 16 / 4 / 24 | 12 / 15 | → Heaven Splitter (heavy) |
| Returning Draw | heavy after horizontal Iai | left-to-right heavy slash | 16 / 4 / 24 | 12 / 15 | end of string |
| Heaven Splitter | heavy follow-up | overhead | 22 / 4 / 28 | 15 / 18 | end of string |

The Katana's sprint, dodge, backstep and jump attacks, block abilities and ultimate are unchanged. While sheathed the fighter can't block; a dodge cancels the stance.

The Iai's frames count its sheathe in the startup: 23 frames are the 9-frame sheathe, which a held heavy stretches into the stance as a charge, and the 14-frame draw. A tapped heavy draws on frame 23 and hits on 24, and a held one hits 14 frames after release. It lunges only once the sheathe ends: 0.4 m over frames 10 to 25, easing in and out (2.1 m since authored-animation task 11, as its clip reaches less far than the cone; it still hits at 3.8 m and misses at 4.2). Until weapon paths decide hits (task 7), the vertical Iai hits with an interim cone of 3.6 m and 60°, which with the lunge reaches a fighter 3.8 m away where Right Cut misses. Once the sheathe's 9 frames end, the sheathed fighter walks and strafes at the blocking walk's speed, never sprinting or stepping, and a strafe circles the opponent as a free fighter's does; other weapons' charged heavies still stand still. A dodge cancels the stance, including one pressed up to 8 frames before it begins (the input buffer, as for every dodge cancel) and one pressed on the step heavy is let go, before the draw starts. A dodge pressed in the sheathe of a tapped heavy is refused. Once the draw starts it keeps only the dodge cancel every heavy has, from frame 39, and the walk's speed carries into it, braking as on every attack frame (about 0.14 m of drift after a full-speed strafe).

A tapped Iai is drawn as the sheathe's 9 frames end, and a held one as its stance ends, on release or auto-release. The stick at that moment picks the draw, by the same rule as Moonsplitter's: held left or right past the dead zone (0.4), and more sideways than forward or back, it draws the horizontal Iai; otherwise the vertical. The horizontal swaps in on the same attack, so it keeps the Iai's frames, lunge and charge, its auto-release as a power attack included. Until weapon paths decide hits, it hits with an interim cone of 3.6 m and 110°: the vertical's reach and Right Cut's width. Its follow-ups are Return Cut (light), which goes on through the light string as after Right Cut, and Returning Draw (heavy), which ends the string. Returning Draw's interim cone has Rising Heaven's reach (2.3 m), lunge (0.5 m) and knockback (0.9 m), and Return Cut's width (110°). (Since authored-animation task 11 Returning Draw lunges 1.1 m and Rising Heaven 1.2.) Its sides follow its cut, right to left, so that Return Cut and Returning Draw can follow it; how the draw brings the blade from the left-hip saya round to the right is for its swing (7.20) to show.

Until the swings (7.20) and the saya (14.16), the stand-in poses both Iai Slashes from a sheathe (their anims, `iaiVertical` and `iaiHorizontal`): over the sheathe's 9 frames the hands go to the hilt in front of the left hip, the blade lying back along it; they stay there in the stance; and the draw brings the blade out in front, pointing forward, then up into the cut's wind-up, above the head for the vertical and to the right shoulder for the horizontal, before cutting as Crown Cut and Right Cut do. The stance's walk makes footsteps, as the free walk does.

Kesa Cut dodge-cancels from frame 20, six frames after its cut ends, as Right Cut and Return Cut do; Crown Cut keeps the demo's 26. Until weapon paths decide hits (task 7), Kesa Cut hits with an interim cone of 2.2 m and 100° after a 0.35 m lunge, and knocks back 0.4 m (Right Cut: 110° and 0.35 m). (Since authored-animation task 10 its lunge is 0.4 m, Return Cut's 0.45 and Crown Cut's 0.7, so their clips reach the duelling distance.) Rising Heaven's, Returning Draw's and Heaven Splitter's lunges end two frames after their cuts start.

**Greatsword**

| Move | Input | Shape | Frames | Damage / posture | Notes |
|---|---|---|---|---|---|
| Heavy Swing | light | right-to-left slash, stepping into it | 14 / 4 / 22 | 9 / 11 | → Backswing (light), → Overhead Strike (heavy) |
| Backswing | light, light | left-to-right slash riding the momentum | 11 / 4 / 22 | 9 / 11 | faster start from momentum; → Overhead Strike (heavy): the L-L-H |
| Overhead Strike | heavy | overhead | 26 / 5 / 29 (32 until authored-animation task 18) | 18 / 22 | chargeable; → Low Sweep (heavy) |
| Low Sweep | heavy, heavy | low sweep at the feet | 26 / 5 / 34 | 16 / 22 | unblockable, can be jumped (leap counter), narrower and faster than Reaping Sweep |
| Piercing Lunge | light out of a dodge | stab | 12 / 3 / 20 | 8 / 10 | blockable stab |
| Skewer | heavy out of a dodge | thrust | 22 / 4 / 28 | 14 / 18 | unblockable thrust (stomp counter) |

Backswing rides Heavy Swing's momentum: it starts in 11 frames where the demo's took 13, and its lunge and dodge cancel keep pace, the lunge ending on frame 12 (one after its cut starts, as Heavy Swing's) and the cancel opening on 23 (eight frames after its cut ends, as Heavy Swing's). The light string is these two swings. Overhead Strike is the demo's Crushing Blow made an overhead, and charges as it did: held past its frame 9 it charges standing still, and it releases by itself 2.5 s later as a full charge. As every chargeable heavy does (the demo's Twin Fang after the Daggers' lights too), it charges however it started, so the L-L-H's finisher can be held. It no longer goes on to Backswing. Until weapon paths decide hits (task 7), it keeps Crushing Blow's cone (3.1 m, 90°), lunge (0.7 m over frames 10 to 30), knockback (1.6 m) and hitstop (9 frames). (Since authored-animation task 18 its clip, Attack2H02, sets its recovery at 29 frames and its lunge grows to 1.05 m, so it reaches 3.5 m; Heavy Swing lunges 0.45 m ending on frame 16 and Backswing 0.55 m, so their clips reach the duelling distance.)

Low Sweep, Overhead Strike's heavy follow-up, replaces the demo's Earthbreaker under its id. It is unblockable, as Reaping Sweep is: a blocking defender takes it as a hit, one whose posture meter is full is disarmed, and dodge invincibility doesn't help; it leaves the red danger trail, and turns more slowly to follow its target as it winds up (5 where other moves turn at 7). As it starts it warns of a sweep, and a defender in the air as it cuts leaps on the attacker, the leap counter. It is marked jumpable, as Reaping Sweep is, so a defender in the air that the counter misses (close in and off to the side, where the hit's cone widens by 30° and the counter's by 20°) is missed, not hit. Until weapon paths decide hits (task 7), it hits with an interim cone of 3.2 m and 110°, reaching past the lights' 3.0 m and narrower than Reaping Sweep's 160°, as it is faster (26 frames to 28), and it keeps Earthbreaker's lunge (0.8 m from frame 10, ending two frames after its cut starts, as Earthbreaker's did), knockback (2.0 m) and hitstop (10 frames). As a heavy it dodge-cancels late in its recovery, from frame 48.

Piercing Lunge and Skewer replace the demo's dodge attacks, Pommel Strike and Cyclone, under their ids: a light or a heavy pressed as a forward or sideways dodge ends, or within 12 frames after, gives them as before (a backward dodge still gives the back attacks). Piercing Lunge is a blockable stab with the blade, so it sounds as the Greatsword's swings do and, no longer a bash, ends with the colossal slide. Skewer is an unblockable thrust, as the Katana's Piercing Thrust is: it warns of a thrust as it starts, goes through a block, and a defender who dodges forward into it stomps the attacker, the stomp counter. As every unblockable, it leaves the red danger trail, dodge invincibility doesn't help against it, and it turns slowly as it winds up (5, where other moves turn at 7); like Piercing Thrust it also turns slowly once it strikes (0.5, where other moves turn at 1.2). As a heavy it dodge-cancels late in its recovery, from frame 40. Until weapon paths decide hits (task 7), Piercing Lunge hits with an interim cone of 3.0 m and 50° after a 0.8 m lunge (1.0 m since authored-animation task 18, so its clip still reaches from where a sideways dodge out of the string leaves the fighters), and Skewer with 3.4 m and 36°, past the lights' 3.0 m, after a 1.0 m lunge; each lunges over its startup and active frames, and they keep Pommel Strike's and Cyclone's knockback (0.8 and 1.4 m).

Sprint, backstep and jump attacks, block abilities and the ultimate are unchanged as moves. Every grounded attack but the bashes, block abilities and Leaping Smash included, ends with a short slide (0.35 m over 10 frames), along the facing until the swing paths give it the swing's direction.

**Twin Daggers**

| Move | Input | Shape | Frames | Damage / posture | Notes |
|---|---|---|---|---|---|
| Quick Slice | light | right hand, right-to-left | 7 / 2 / 13 | 4 / 4 | dodge-cancel from the first recovery frame; → Off-hand Slice, → Twin Fang |
| Off-hand Slice | light, light | left hand, left-to-right | 7 / 2 / 13 | 4 / 4 | dodge-cancel from the first recovery frame; → Twin Rip, → Twin Fang: the L-L-H |
| Twin Rip | 3rd light | crossing cut, both hands | 9 / 3 / 14 | 6 / 5 | dodge-cancel from the first recovery frame; → Flurry Finisher |
| Flurry Finisher | 4th light | double stab | 11 / 3 / 18 | 7 / 6 | dodge-cancel from the first recovery frame; → Spinning Backhand (heavy) |
| Twin Fang | heavy | dashing double stab, 1.4 m lunge | 16 / 3 / 20 | 10 / 9 | chargeable; → Spinning Backhand (heavy); the old light chain that looped back to Quick Slice is removed |
| Spinning Backhand | heavy, heavy | spin | 18 / 5 / 22 | 12 / 10 | end of string |
| Passing Cut | light out of a dodge | slash, lunging along the dodge direction | 6 / 2 / 12 | 5 / 4 | dodge-cancel from the first recovery frame; replaces Ghost Cut |

The four lights alternate hands, as the demo's did: Quick Slice in the right hand, Off-hand Slice in the left, then Twin Rip and Flurry Finisher with both. Each dodge-cancels from its first recovery frame, the one after its last active frame, after a hit or a whiff: Quick Slice and Off-hand Slice from frame 10 (the demo's 13), Twin Rip from 13 (16), and Flurry Finisher, which had no cancel, from 15. A dodge pressed during the active frames waits in the input buffer and comes on that frame. Twin Rip no longer goes on to Twin Fang, and Twin Fang no longer loops back to Quick Slice on light; that went in 11.1, ahead of the rest of Twin Fang's row, because a stab ends at centre and Quick Slice starts on the right. The four lights stun for 10 frames, not 14 (see the fluid combat rules).

Twin Fang dashes 1.4 m (the demo's 0.8) over its startup and active frames, easing in and out, and like every lunge stops 0.25 m short of the defender's body. As the demo's did, a held Twin Fang charges partway through its dash: it covers about 0.6 m before the charge begins at frame 9, stands still while charging, and covers the rest once released. Spinning Backhand, the heavy after Twin Fang or Flurry Finisher, is the demo's Gutting Spiral renamed, with its numbers, and ends the string.

Passing Cut replaces the demo's Ghost Cut under its id: a light pressed as a forward or sideways dodge ends, or within 12 frames after, gives it (a backward dodge still gives the back light, Flick). It lunges 1.2 m (Ghost Cut's 0.4) over its startup and active frames, easing in and out, along the direction of the dodge before it rather than its facing, so out of a dodge to the right it carries the fighter on 1.2 m to the right. Only the part of each step that closes on the opponent is held back: after a forward dodge it stops with the bodies 0.25 m apart, and a defender across its path doesn't stall it. It dodge-cancels from its first recovery frame, frame 9 (Ghost Cut's opened on 12). Until weapon paths decide hits (task 7), it keeps Ghost Cut's cone (1.8 m, 120°), knockback (0.2 m) and a light's hitstun (14).

Sprint, backstep and jump attacks, block abilities and the ultimate are unchanged.

## Testing Decisions

- A good test drives the rules only through their public surface, as the demo's tests do: build a world with two fighters, feed per-frame button and stick inputs, then assert on emitted events, HP, posture and state. Tests never reach into presentation code or private fields.
- **Rules (GUT, headless):**
  - the 47 ported tests;
  - golden replays against the TypeScript rules until the first deliberate rule change (retired by task 8.2 in ae4fbb5; 4222167 is the last commit they passed on);
  - behaviour tests for the training dummy (each behaviour judged by its events and states) and for the computer's counters (a brain that always tries the counter lands evade, stomp and leap), which replaced the input hashes that pinned both brains to the TypeScript;
  - new tests for each rule change (`test_fluid_combat.gd`): arena radius and wall; block walk speed; momentum carry; eased lunges; heavy dodge-cancel; light hitstun letting a defender parry the second hit; the colossal slide;
  - swing hit detection: a blade that passes behind or above the defender misses; a low sweep misses a jumping defender; an unblockable's longer blade hits at a range a normal attack misses; hits land on the frame the blade first touches the capsule;
  - every new move and chain: Katana four-light string, Iai vertical and horizontal by stick, Iai follow-ups, strafing while sheathed, sheathed auto-release, dodge cancelling the stance; Greatsword L-L-H, Low Sweep unblockable and jumpable, dodge thrusts; Daggers alternating string, dodge-cancel timing, no light loop from Twin Fang, Twin Fang's dash into Spinning Backhand, Passing Cut direction;
  - string continuity (`test_string_continuity.gd`): every follow-up starts on the side the move before it ends on, or at centre, and every move in a string has both sides;
  - every move's data still matches the demo's (`test_moves.gd` against `moves.json`), apart from the tables of deliberate differences that each data change adds to (rule-wide and per-move field changes, added, moved and removed moves, and weapon field changes).
    > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Frame data are now generated from the clips into a committed table with no hand overrides, and a test keeps every attack inside its timing band. Tests that pin frame data to the web demo will be replaced as the slice lands.
- **Content (GUT, headless):** every fighter scene assembles on the retargeted skeleton and the shared clips drive it; the body is cut down to the head and the headwear is in place; the two palettes differ from the front, the back and the side (rendered in software); every weapon has its markers and length; no held blade runs into its fighter's body; the art stays under 110 MB with no file over 25 MB and textures scaled down (raised from 60 MB and 10 MB for the UAL2 Source tier's two ~20 MB clip libraries).
  > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The 110 MB art cap retires: size budgets are set per place (a small public repository, a budget per asset in the asset repository and a target size for the shipped game). The test that caps art at 110 MB will be replaced as the slice lands.
- **Input (GUT, headless):** a fake device stands in for the keyboard, mouse and controllers. Tests cover the bindings, profiles and saving, rebinding capture, button names, per-player seats and pause, and the feed into the rules.
- **Sound:**
  - Node tests check the processing tools and measure the processed files: sharp attacks, no DC offset, clean tails, and variations matched in loudness.
  - GUT tests check:
    - every event has a sound and every file loads;
    - the bus layout;
    - the music director switches at match point;
    - the tracks have the design tempos and loop for exactly their bars.
- **Poses (GUT, headless):** `PoseCheck` measures the posed skeleton against the swing rules above: the wrists, the elbows on contact and never locked, the knees over the toes, the blade 5 cm clear of capsules measured from each fighter's own meshes, and how much blade enters a defender 2.5 m away. `MoveBench` plays any move frame by frame on the rules' clock for it.
- **Host and camera (GUT, headless):** the fixed step, hit-stop and slow motion, pause and focus loss, the camera's distances, the HUD's timing, and the flow from title to results, all driven through `step()` without a window.
- **Soak:** 40 computer-vs-computer matches must finish without errors or impossible values (NaN, a fighter outside the arena, posture out of range). They report round length, parries, counters, disarms and ultimates per round, and each weapon's win rate against the other weapons (mirror matches left out). Target after tuning: rounds of 35–60 s, 0.3–0.6 disarms per round, each weapon winning 45–55% of its matches against the other weapons. A targets block marks each in or out; a target out of range is not a failure. Tuning runs 300 matches (`soak:tune`); the 40-match run stays the clean check.
  > **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The slower, For Honor-like pace sets rounds of about 60–90 s in place of 35–60 s, and every weapon is rebalanced, each as its animation lands.
- **Presentation:** scripted screenshot scenes, rendered in a window from the command line:
  - a pose gallery of every attack at wind-up, contact and follow-through, for each weapon, on each fighter: contact sheets (`tools/shot_scenes/move_sheet.tscn`) play a move against a defender 2.5 m away and show its chosen frames from the gameplay camera behind each fighter, three-quarter, close and at the hands, each frame captioned with its phase and PoseCheck numbers; `--move=all` renders a weapon's whole set, the same images on every run;
  - the arena from the gameplay camera and the Watch camera;
  - every menu screen;
  - Versus split screen;
  - the parry, disarm and ultimate moments.

  They are reviewed by eye for clipping, hands off the grip, weapons through bodies and unreadable effects. A smoke test loads every scene headless and fails on errors. Shaders compile only in a window, so a shader-check scene draws every shader and its `shots` run fails on any shader error.
- **Prior art:** the demo's tests (combat, match, regressions and ultimate suites) and their helpers (world builder, button and stick input helpers, event recorder, run loop) are ported first and reused for new tests.

## Out of Scope

- The other six weapons (Odachi, Giant Hammer, Staff, Sword & Shield, Bladed Whip, Scythe) and their ultimates.
- The other six fighters (Knight, Samurai, Orc, Aristocrat, Monk, Skeleton Knight), per-fighter bare-hand moves and per-fighter computer personalities.
- The character select's gate cinematic in the design doc (the gate opening on lock in, the arena seen through it), the match intro with gates and fighter intros, and victory poses. The rebuild's fighter select follows the design's layout (a fighter grid, the fighter's 3D preview on the right, the loadout on the left, an arena slot and lock in) without them. (The authored-animation feature adds the weapon draw at the round intro and each weapon's victory pose.)
- Arenas other than the floating Moonlit Shrine, and stage select.
- Real music (placeholders only), voices and announcers.
- Online play, accounts, progression and cosmetics.
- A lock-on toggle or free camera.
- Ring-outs and the Hammer's wall slam.
- Mac and Linux builds.

## Further Notes

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** This list predates the Oct 4 direction. The spec's toon and ink-wash look, laptop performance target, 110 MB art cap, ink-brush effects and rules-set lunges and slide now also differ from `docs/design.md`.

**Where this differs from `docs/design.md`:**

- Fighters are cosmetic in this build. There are two of eight, and they share the bare-hand moveset.
- Music is placeholder.

**Where this differs from `docs/mvp-spec.md`, which stays the record of the web demo:**

- engine, platform, controls storage and build;
- hit detection by weapon path instead of a range-and-arc cone;
- arena radius 15 m;
- block walk speed 60%;
- light hitstun 14 frames (10 on the Daggers' string);
- momentum and cancel changes;
- the Katana, Greatsword and Daggers strings above;
- music tempos (the demo used 84 and 138 BPM).

The demo spec's block-posture figures (60, 50 and 70%) and speed figures don't match its own code (70, 60 and 80%; 0.9 and 1.12); the Godot port follows the code, and the demo spec's tables are corrected on this branch.

**Risks, and how they're handled:**

- Procedural attack animation may not look good enough. An early animation spike on one fighter and the Katana is judged from screenshots before all moves are built. Authored clips can replace any move later, because the swing path stays the hit authority. (Oct 3: it didn't look good enough, and `docs/specs/authored-animation.md` replaces it with authored clips.)
- Swing-based hits change balance. Handled by soak runs after the change, with ranges tuned per move.
- The body and outfit rest poses differ slightly, which risks clipping. Handled by cutting the body down to the head and checking screenshots.
- Asset licences:
  - Quaternius is CC0.
  - The Sonniss bundle allows use in the game but not redistribution of its raw files or any AI training; only processed files are committed, and their sources are listed.
  - The fonts are under the SIL Open Font License.
