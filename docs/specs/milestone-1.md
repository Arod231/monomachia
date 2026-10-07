# Spec: Milestone 1, the Hunter with the Katana and bare hands at final quality

Oct 4, 2026 · status: approved by the owner on Oct 4, 2026, together with its plan (reviewed once, back to back, for this round only), after the owner confirmed all 56 proposed defaults (P1–P56) as written · progress: tasks 2 (the private asset repository) and 3 (the mood board, approved with For Honor's camera framing) done Oct 4; the groundwork (tasks 4–11, 14, 113, 134), the Blender export (12) the clip import (13) the frame-data generator (15), the committed frame-data table (16), every reader reading it (17) and the band tables with their tests (18) done Oct 5; the clips at their own speed (19) built Oct 5, playing each move at 1.0× as its family re-keys it, follow-ups and dodge cancels at the table's markers (20) done Oct 5, and travel from the clips (21) built Oct 5, moving each move by its clip's travel as its family re-keys it; the protected timings retuned and frozen (22) Oct 5, their outcomes in play at once and each move's own values as its family re-keys it; inertial blending (23) done Oct 5; Right Cut and Return Cut re-keyed by Claude's scripted Blender pass as two-handed cuts with a real step, inside the light band (31) Oct 6, and Kesa Cut and Crown Cut likewise, the vertical cuts stepping into the cut (32) Oct 6, so the whole light string is in band (stories 52 and 59 ticked; 34, 53 and 211 wait for the other families); the Katana riding the clip's hands in every state, guard and free movement included, with or without the clip libraries (135) Oct 6 (story 102 ticked); the Katana's keyed guard idle, the light string's bridges and each light's return to guard (33) Oct 6 (stories 47 and 95 wait for tasks 64 and 57); each light's deflect pair, the blades meeting at the parry's contact point, the rebound retired (34) Oct 6 (story 106 ticked; 105 waits for the other families' pairs); the Katana's light hit reactions by where they land and its light block reaction, each fitting its frames at its own speed (35) Oct 6 (stories 97 and 107 wait for the heavies'); the pilot's review package (40) Oct 7: the pilot's checklist rows filled, the side-by-side video and sheets, the play build with the clips, the lights rebalanced to posture 5/5/6/7 and damage 5/5/6/7, and a 300-match run of 56.8 s rounds and 1.62 disarms a round (stories 50, 209 and 210 wait for the other families); the pilot family's review (41) Oct 7, approved by the owner with no change to the protected timings, which are now frozen (stories 32, 40 and 51 ticked); the Godot check at the pilot and the look test (42) Oct 7, criteria 1–6 passing on their evidence in `docs/reviews/milestone-1-godot-check.md`, accepted by the owner the same day, so Godot stays and the art conversion may start (story 212 waits for sign-off's criteria 7 and 8) · the code's branch: `feature/milestone-1`, cut from `master` after `docs/plans/godot-rebuild.md` task 26.4 · this spec and its plan: branch `docs/milestone-1-spec`, through a draft pull request into `feature/godot-rebuild`, so they reach `master` with the consolidation, before the code's branch exists (an exception, for this round only, to CLAUDE.md's rule that the spec, the plan and the code arrive in one pull request)

Read with: `docs/design.md` (section 1, Order of work, and every "(Oct 4)" line), [ADR 0001](../adr/0001-animation-leads-realistic-look.md), the plan `docs/plans/milestone-1.md`, and the roadmap `docs/plans/roadmap.md`.

Milestone 1 brings the Hunter (both palettes) with the Katana and bare hands on the Moonlit Shrine to final quality, including everything inside a round. It is the first of the two milestones that bring the existing content to final quality before any new weapon, fighter or arena. This spec turns the owner's 27 answers from the milestone-1 grilling (Oct 4; the grilling's record, its defaults and the facts found are folded into this spec) and the "(Oct 4)" lines of `docs/design.md` into one buildable description. Where the grilling left something undecided, this spec proposed an answer (P1–P56). The owner went through them on Oct 4 and confirmed every one as written; each is marked **(Pn, confirmed Oct 4)** where it applies and listed under "Defaults the owner confirmed (Oct 4)". A later change to one becomes a change to the plan.

## Problem Statement

On Oct 4, 2026 the owner played the Godot build and found the animation stiff and the look below the bar they want for a commercial Steam release:

- **The motion is fitted to the rules, not the other way round.** Clips play 1.15–2× fast to land on the web demo's frame data (Right Cut lands on frame 11, 183 ms), the knockdown plays at 2× and the roll at about 2.75× and 3.8×, and long states hold a frozen last pose. The Katana's lights read as twitches rather than cuts.
- **Fighters slide.** The rules move fighters further than their clips step: the Iai Slash slides 2.1 m, lights lunge by rules numbers, and the rules push short weapons' swings forward to reach (the reach push) while the view slides the body to hide it.
- **Hand-offs pop.** Attack hand-offs blend over 2–4 frames, and a hit cuts straight into hitstun with no blend at all. Both hit reactions recoil straight back whatever side the hit came from.
- **Weapons leave the hands.** In free movement the weapon is posed in space by the demo's stick poses and the arms chase it with IK; on a clone without the clips, attacks do the same.
- **Motion is played at the wrong speed elsewhere too.** The locomotion scales its clips' playback to match the rules' speeds by stride (the sprint, at the rules' 7.2 m/s against the clips' 5.3–6.3, plays about 1.15–1.35× fast) instead of the rules moving the fighter at the clips' own speeds.
- **Generic clips are shared** across moves, and many Katana cuts are one-handed.
- **The look is a toon and ink-wash style** tuned for an integrated-graphics laptop. It isn't the realistic, Ghost of Tsushima-like dark fantasy the owner now wants, judged at 4K on an RTX 3090.
- **Whole parts of a round are missing:** no finishers, no blood, no real draw or victory, no cinematic shots, a stylised ring for parries, a toon beam over a dropped weapon that bounces and lies flat, and placeholder music.
- **There's no way to work at the new bar.** Nothing brings a clip edited in Blender back into the game, the paid packs sit in a loose folder, frame data are typed by hand, and nothing proves the rules are deterministic enough for online play later.

## Solution

Bring a small slice of the game, everything a Hunter-against-Hunter Katana duel on the Moonlit Shrine can show, to the final quality, built the way the rest of the game will be built:

- **The pipeline first.** A private asset repository (Git LFS) holds the packs, Blender sources and exports. A scripted export brings Blender work into the game. A frame-data generator reads each attack's clip at its own speed and writes a committed frame-data table, and tests keep every attack inside its timing band and distance band. A replay test and a save-and-restore test prove the rules deterministic. The Animation Studio is slimmed to the gallery, timeline, markers and chains, with marker edits driving the table.
- **Animation leads.** Each attack is re-keyed (first passes by script in Blender, the signature moves polished by the owner in Cascadeur) until it lands in its timing band and connects from its distance band. Nothing speeds up, slows down, freezes or stretches one clip while the game runs (hit-stop and slow motion slow the whole world alike), and no fighter slides further than their clips step. Only the protected timings stay rules numbers, retuned once for the slower pace and then frozen.
- **A pilot family, then the rest one at a time.** The Katana's light string goes all the way to final quality first (keyed into its band, with its deflect pairs, hit reactions, sound and effects) and the owner reviews it. The look test scene is built alongside the pilot's keying, so the pilot's effects take the approved look before its review. The other move families follow one by one, each with contact sheets, a side-by-side video against the reference games and a play session.
- **Everything inside a round.** The draw at the round intro, the finishers (the Katana's diagonal iai cut and bare hands' crushing strike), the disarmed weapon stuck blade-first in the ground and pulled out, the ultimates' cinematic shots, Warrior Slain, the round-end beat and the match-winning KO shot and victory pose.
- **The realistic look.** A mood board and a look test scene settle the look while the clips are keyed; then the Hunter is re-dyed crimson and indigo in realistic materials, the Katana and saya are modelled, the Shrine is upgraded in place with wisteria, banners, grass and a real 3D landscape under one wind, and the effects become sparks, blood, dust, smoke and air smears.
- **Sound and screens.** Sound follows every new motion and event; the generated score gains its new instruments; the HUD, the round calls and the finisher prompt are redesigned, and the menus take the new theme.
- **A milestone end the owner can trust.** Every move passes a written checklist, Ultra holds 4K at 60 fps on the RTX 3090 and Low 60 fps on the laptop, a balance run of mirror matches comes out clean, every check is green, and the owner plays the real build with the asset repository and signs off. The Godot check is judged at the pilot family and the look test, and confirmed at sign-off.

## User Stories

One global numbering; the plan cites these as "Stories: N". Stories 220 and later were added in review; each sits at the end of its area, out of numeric order, so that the earlier numbers stay stable.

### The starting point and the roster

1. As the owner, I want milestone 1 to start only after the consolidation has merged the Godot rebuild into `master` (the web version retired, CI green on clones without the clips), so that new work branches from `master` again and nothing is built on a branch about to move.
2. As a developer, I want milestone 1's code on its own branch, `feature/milestone-1`, cut from `master` after godot-rebuild task 26.4 and merged back by one pull request, with this spec and its plan already on `master` (they arrive earlier, through the docs pull request into `feature/godot-rebuild` and the consolidation, an exception to CLAUDE.md for this round), so that the owner reviews the code in one place. **(Changed Oct 6 by the owner: `feature/milestone-1` was folded into `master` and retired; milestone 1's lanes branch from `master` and open their pull requests into it.)**
3. [x] As a player, I want the menus during milestone 1 to offer only the Hunter and the Katana, with bare hands when disarmed, so that every match I play is one this milestone has brought to final quality. (Ticked with task 4.)
4. As a developer, I want a dev flag that still shows the Rogue, the Greatsword and the Twin Daggers, with their code kept and their tests passing (those that pin frame data become reads of the generated table), so that milestone 2 starts from working code.
5. [x] As a player, I want every default match (Duel, Training, Watch and the title's attract duel) to be the Hunter in crimson against the Hunter in indigo, both with the Katana and today's default block abilities (Flash and Piercing Thrust), so that no default reaches a hidden fighter or weapon. (Ticked with task 4.)
6. [x] As a Training player, I want no drill to swap the dummy to a hidden weapon (today the slam drill brings in the Greatsword), so that Training stays inside the milestone's content. (Ticked with task 4.)
7. [x] As a player reading How to play or the move list, I want only the Katana's and bare hands' tabs while the roster is hidden, so that nothing describes content I can't pick. (Ticked with task 4.)
8. [x] As the owner, I want bare hands to stay the disarmed state, not a loadout, so that there is no bare-hands draw to make and the cheer plays only when a disarmed fighter wins the match. **(P1, confirmed Oct 4)** (Ticked with task 4.)

### The pipeline

9. [x] As the owner, I want a private GitHub repository with Git LFS holding the packs, the Blender sources and the exports (about 2 GB), so that paid and large art has a home the public repository never sees.
10. [x] As the owner, I want the raw Sonniss zips kept outside the asset repository and only processed sounds committed, as today, so that neither repository carries 6.5 GB of raw audio.
11. [x] As a developer, I want the import tools to read the asset repository wherever the owner keeps it, through today's asset-source setting, so that a real build always uses it.
12. As a developer, I want clones and CI builds without the asset repository to run on labelled stand-ins (CC0 clips and code-built or committed models), with every test that needs the clips skipping itself, so that CI stays green for anyone.
13. [x] As a developer, I want a scripted export from the Blender sources to the files the game uses, for clips and for models, so that an edit in Blender reaches the game with one command and no hand steps. (Ticked with task 12.)
14. [x] As a developer, I want clips edited in Blender or Cascadeur imported like the pack clips (retargeted, mirrored where the manifest says, markers kept), so that a re-keyed move replaces its pack clip in the game. (Ticked with task 13.)
15. [x] As the owner, I want every new model and every clip keyed from scratch to be the project's own art (all rights reserved), with its Blender source in the asset repository; clips re-keyed from a pack clip to stay under the pack's licence, exported only into the asset repository; and the exports of self-made and CC0 models and materials also committed to the public repository inside its size budget **(P23, confirmed Oct 4)**, so that everything shipped can be sold and plain clones and CI see the art they may. (Ticked with task 12.)
16. [x] As a developer, I want every move's source clip recorded beside its numbers, so that any move can be re-baked from another clip. (Ticked with task 16.)
17. [x] As a developer, I want a frame-data generator that reads each attack's clip at its own speed and writes the startup, active and recovery frames, the cancel windows, the branch points and the per-frame travel into a committed frame-data table, and the hit path into the committed swing files, in the same run, so that the clip decides the frame data with no hand overrides. (Ticked with task 17.)
18. [x] As a developer, I want the rules, the computer opponent, the move list, the sheets and every other reader of frame data to read that table, so that there is one source of truth. (Ticked with task 17.)
19. As a developer, I want each attack's travel baked per frame from the hips and foot plants, and its swing sampled relative to the moving body, so that travel isn't counted twice. **(P13, confirmed Oct 4)**
20. As a developer, I want CI to check that the committed table is complete and that every Katana and bare-hands attack sits inside its timing band and connects from its distance band, so that a clip out of band can't be merged.
21. [x] As a developer, I want a local-only test that re-bakes every move from the clips and fails on any drift from the committed table, so that the table never falls behind the clips. **(P12, confirmed Oct 4)** (Ticked with task 16.)
22. [x] As a developer, I want the Greatsword's and the Daggers' frame data generated from their current clips through the same generator, with no band test until milestone 2, so that one generator serves every weapon. **(P10, confirmed Oct 4)** (Ticked with task 17.)
23. [x] As a developer, I want a replay test in the pipeline phase, in this form: a seeded match run twice gives matching state hashes on every step **(P18, confirmed Oct 4)**, so that the rules stay deterministic for rollback netcode. (Ticked with task 5.)
24. [x] As a developer, I want a save-and-restore test in the pipeline phase, in this form: save mid-match, restore, step again and compare **(P18, confirmed Oct 4)**, so that the rules can be rolled back later without a retrofit. (Ticked with tasks 134 and 6.)
25. [x] As a developer, I want both tests to cover a finisher and a stuck weapon, so that the new rules are as deterministic as the old. **(P18, confirmed Oct 4)** (Ticked with task 103.)
26. [x] As a developer, I want matches recordable as input logs that replay to the same result, so that the performance gate, the balance run and bug reports can replay a match exactly. (Ticked with task 6.)
27. [x] As the owner, I want the Animation Studio slimmed to its gallery, a timeline, markers and chains, so that it does what animation-leads needs and nothing it no longer needs. (Ticked with task 27.)
28. [x] As the owner, I want markers set on the Studio's timeline to give each clip's active frames, cancel windows and branch points, and saving to regenerate the frame-data table and report any move outside its band, so that a marker edit is the only way frame data change. **(P12, confirmed Oct 4)** (Ticked with task 27.)
29. [x] As the owner, I want the Studio's timeline to show each move's generated frame data against its timing band, and whether it connects from its distance band, so that I see at once whether a clip fits. (Ticked with task 25.)
30. [x] As the owner, I want the Studio's chains kept without their speed field or held frames, so that nothing in the Studio can speed up, slow down or freeze a clip. (Ticked with task 27: the Studio makes neither; today's holds and speeds stay in the data, read-only, until task 19.)
31. [x] As a developer, I want bone posing, correctives, IK handles, keyed-clip editing, the refinement launcher and the chat panel dropped from the Studio in favour of Blender, so that the tool stays small. (Ticked with task 11.)
32. [x] As the owner, I want to try the slimmed Studio on the pilot family before the other families start, so that the marker workflow is proven early.

### Timing, distance and pace

33. [x] As the owner, I want one timing band per move kind for the Katana and bare hands, in a table I approve in this spec, so that the slower, For Honor-like pace is set by design before any clip is keyed. The values are in the timing band table **(P26, confirmed Oct 4)**. (Ticked with task 18.)
34. As a player, I want the Katana's lights to land in 400–500 ms (24–30 frames), bare hands faster and every heavy slower, so that the pace is weightier and each weapon class keeps its feel.
35. As a player, I want every Katana and bare-hands clip played at its own speed, never sped up, slowed down, frozen or stretched on its own while the game runs, apart from the whole-world time effects (hit-stop, the KO's and the finisher's slow motion, the disarmed ultimate's choice), which slow every clip alike, so that the motion I see is the motion that was keyed.
36. As a player, I want holds, such as the Iai stance, played as authored loops, so that a held charge looks alive rather than frozen.
37. As a player, I want no fighter to slide further than their clips step, so that feet and ground agree.
38. As the owner, I want each weapon's distance band, starting from today's duelling distances (the Katana duels at 2.5 m and its computer prefers 2.1 m; bare hands 1.6 m and 1.2 m), and every attack to connect from its band, so that spacing is set by design and met by re-keying, never by sliding. The values are in the distance band table **(P27, confirmed Oct 4)**. **(Oct 6) Superseded by ADR 0002:** the duelling distances are re-measured for the 1.3 m Katana and the taller bodies (`docs/specs/katana-elden-ring.md`, D1).
39. As a player, I want the protected timings (the parry window, the input buffer, the dodge and backstep, hitstun, blockstun, hit-stop and the knockdown phases, joined by the counters' stuns, the disarm's stagger and daze, and the parry recoil **(P50, confirmed Oct 4)**) to stay rules numbers that every clip showing them must fit, so that defence is consistent whatever the clip.
40. [x] As the owner, I want hitstun, blockstun, hit-stop and the knockdown phases retuned once, at the start, for the slower pace, and then frozen, so that later clip work never shifts them. The new values, and the pilot's play session ending the one retune, are in the protected-timing table **(P28, confirmed Oct 4)**; the Greatsword's and the Daggers' wait for milestone 2 **(P48, confirmed Oct 4)**.
41. As a player facing a light string, I want to be free a frame or two before each next hit, enough to block or parry but not to strike back, so that one mistake doesn't cost me the whole string.
42. [x] As a player, I want the parry window (9 frames for the Katana, 8 for the redirect) and the input buffer (8 frames) unchanged, so that what I learned about parrying still applies. (Ticked with task 22.)
43. [x] As a player, I want the roll to keep 16 frames (12 invincible) plus 9 of recovery over 2.8 m, and the backstep 14 (10) plus 9 over 2.1 m, so that dodging still works as before. (Ticked with task 22.)
44. [x] As a developer, I want a test that pins the frozen protected timings and checks the free-frame rule and the earliest branch points across every follow-up pair in the table, so that changing one needs a deliberate edit the owner approves. (Ticked with task 22.)
45. As the owner, I want follow-ups and dodge cancels to open at markers on each clip, where the body can plausibly break off, so that a follow-up starts from its branch point rather than waiting for the move to end.
46. [x] As a player, I want every follow-up to stay optional, so that I can stop after any hit and recover normally. (Ticked with task 20.)
47. As a player, I want strings to flow, each swing continuing from where the last one ended, and two lights to flow into a heavy as the third hit, so that a string reads as one motion.
48. As a player, I want the jump arcs to stay rules numbers and the jump clips made to match them, so that clearing a sweep always works the same way.
49. [x] As a player, I want the rules to keep running at a fixed 60 steps a second, with faster displays showing frames blended between steps, so that the fight is the same on every screen. (Ticked with task 19.)
50. As the owner, I want the Katana and bare hands rebalanced around their clips as each family lands, with the old "within 5 points of the baseline" rule retired, so that balance follows the new pace.

### The Katana

51. [x] As the owner, I want the Katana's light string (Right Cut, Return Cut, Kesa Cut, Crown Cut) brought all the way to final quality first, as the pilot family, with its deflect pairs, hit reactions, sound and effects, and reviewed before any other family starts, so that the pipeline and the bar are proven on one family. The order of the other families (P33, confirmed Oct 4) and building the look test alongside the pilot so that its effects can take the approved look before the review (P51). **(Oct 6) Changed by ADR 0002:** the pilot is still reviewed on today's four lights; the Katana's two five-hit strings, one per grip, replace them afterwards with their own review (`docs/specs/katana-elden-ring.md`).
52. [x] As a Katana player, I want the four lights re-keyed as two-handed cuts with longer wind-ups and real steps, each landing inside the light band, so that the Katana's core reads weighty and real. (Ticked with task 32.) **(Oct 6) Superseded by ADR 0002:** redone as the one-handed and two-handed five-hit strings (`docs/specs/katana-elden-ring.md`).
53. As a Katana player, I want every cut two-handed, with the off hand leaving the grip only in the listed one-handed moments (the Iai draws and the sheathe before them, the finisher's draw and re-sheathe, the round intro's draw, the round-end and victory sheathes, Moonsplitter's sheathe and draw, the pull-out, the recall's catch, Piercing Thrust's full extension and Running Draw's follow-through) **(P54, confirmed Oct 4)**, so that the Katana looks like a katana. **(Oct 6) Superseded by ADR 0002:** the Katana has a one-handed and a two-handed grip (`docs/specs/katana-elden-ring.md`).
54. As a Katana player, I want the Iai Slash re-keyed: pressing heavy sheathes the blade into the saya, I can strafe in the stance, and letting go draws a vertical cut, or a horizontal one if I hold the stick left or right, so that the quick-draw is the signature it should be. In the stance the fighter moves at the stance-strafe clip's measured speed, and the draw's drift comes from the draw clip's travel, which closes the open question about halving the stance's walking speed as the draw starts **(P29, confirmed Oct 4)**. **(Oct 6) Changed by ADR 0002:** the controls stay; the draws take Elden Ring's Unsheathe shapes (`docs/specs/katana-elden-ring.md`).
55. As a Katana player, I want the vertical Iai's rising follow-up (Rising Heaven) and the horizontal Iai's left-to-right follow-up (Returning Draw) re-keyed and optional, so that the Iai extends naturally into its next cut. **(Oct 6) Changed by ADR 0002:** Rising Heaven becomes the two-handed heavy pair's follow-up; Returning Draw stays (`docs/specs/katana-elden-ring.md`).
56. As a Katana player, I want a fully held Iai to release by itself at 2.5 s as a power attack, out of an authored stance loop, so that the charge rules stay consistent.
57. As a Katana player, I want the Iai's long reach to come from its clip's step and draw, re-keyed to its distance band in place of today's 2.1 m slide, so that the long draw is a real lunge.
58. As a Katana player, I want Heaven Splitter re-keyed into the string-heavy band, so that heavies are slow and committal.
59. [x] As a Katana player, I want the vertical cuts to step forward into the cut, so that attacks move the body. (Ticked with task 32.)
60. As a Katana player, I want the eight movement attacks re-keyed, each in its own band (Running Draw and Leaping Cleave out of a sprint, Wind Cut and Whirl Cut out of a dodge, Rising Cut and Lunging Cut out of a backstep, Aerial Cut and Falling Crown out of a jump), so that every way into an attack looks deliberate.
61. As a Katana player, I want Flash re-keyed as a two-handed parry stance with its wide window, stunning the attacker, so that the Katana's signature block ability reads at a glance.
62. As a Katana player, I want Piercing Thrust and Swallow Sweep re-keyed in the unblockable band with long, readable wind-ups, so that they're feared but answerable.
63. As a Katana player, I want Moonsplitter re-keyed: the fighter sheathes, the stick picks vertical or horizontal, and a wave crosses the stage, so that the ultimate looks like a finale.
64. As a player facing Moonsplitter, I want the horizontal wave still jumpable and the vertical one still avoidable by stepping aside, so that the ultimate stays answerable.
65. [x] As the owner, I want the Katana's Counter Lunge left on today's clip until milestone 2, since no milestone-1 move triggers the evade counter, so that no work goes into a move no milestone-1 match reaches. Its clip plays at 1.0× like every other, with its frame data generated like the Greatsword's and no band test **(P48, confirmed Oct 4)**. (Ticked with task 17.)

### The disarm and bare hands

66. [x] As a player, I want a disarm to send the weapon flying the way the blow knocked it (on a parry, the way the deflect sends it) and stick blade-first in the ground at an angle, always inside the walls, so that a disarm reads as a real moment. (Ticked with task 86.)
67. [x] As a developer, I want the weapon's flight deterministic, along the knock or deflect direction and inside the walls, with its landing angle as rules state, so that a replay or a rollback lands it in the same place. **(P16, confirmed Oct 4)** (Ticked with task 86.)
68. As a disarmed player, I want to pick my weapon up by pulling it out of the ground, taking as long as its clip, so that the pick-up looks and plays as it should. **(P16, confirmed Oct 4)**
69. As a player whose opponent is disarmed, I want to stand in their way to keep the advantage, so that the disarm game stays live.
70. As a disarmed player, I want to move faster, dodge farther and jump higher than when armed, so that bare hands keep their agility.
71. As a disarmed player, I want a longer roll clip covering the disarmed dodge's 1.5× distance inside the same protected frames, so that the longer dodge doesn't slide. **(P15, confirmed Oct 4)**
72. As a disarmed player, I want the light string (Jab, Cross, Hook) and the heavies (Roundhouse, Spinning Heel) re-keyed in the bare-hands bands, so that disarmed fighting looks like fighting.
73. As a disarmed player, I want the eight bare-hands movement attacks re-keyed (Flying Knee and Dragon Kick out of a sprint, Slip Jab and Spinning Backfist out of a dodge, Snap Kick and Lunging Palm out of a backstep, Air Kick and Axe Kick out of a jump), so that every way in has a real motion.
74. As a disarmed player, I want the redirect to play its own deflect pair, turning the attack aside by hand, so that it reads apart from a parry.
75. As a player whose fist or foot is parried by a blade, I want my fighter to recoil without being cut, so that the moment reads right. **(P9, confirmed Oct 4)**
76. As a disarmed player at 25% HP or less, I want the ultimate to open its choice of the recall or Breaker Palm, so that I can re-arm or hit back hard.
77. As a disarmed player, I want the recall's power-up (the roar, the golden burst, the weapon flying back into my hands, a nearby opponent blasted off their feet) at final quality, the burst still reaching an opponent within the weapon's duelling distance and knocking them back about 2.0 m as today, now through the reaction clip's travel **(P43, confirmed Oct 4)**, so that re-arming feels like a power-up.
78. As a disarmed player, I want Breaker Palm re-keyed with its crouch into the uppercut as its own travel, so that the ultimate's lunge is real.
79. As the owner, I want all fighters to share one bare-hands moveset, re-animated at the new quality, until the breadth phase brings per-fighter styles, so that milestone 1 stays in scope.
80. [x] As the owner, I want bare hands' Counter Lunge left on today's clip until milestone 2, played at 1.0× with generated frame data and no band test **(P48, confirmed Oct 4)**, so that no work goes into an unreachable move. (Ticked with task 17.)

### Movement and the body

81. As a player, I want the walk, run, strafe and sprint speeds to be each clip's own measured speed, committed with the frame data, so that the feet never skate.
82. As a player, I want a blend between gaits or directions kept in step and moving at the blended pace, so that circling the opponent looks natural.
83. As a player, I want guarded strafe and shuffle cycles for the Katana and for bare hands, so that guarded movement looks like a duel.
84. As a player, I want to keep walking a little faster while blocking than in the demo, at about 55–65% of the run speed **(P29, confirmed Oct 4)**, so that I can reposition while guarding.
85. As a player, I want guarded steps to start and stop within about 0.1 s, so that guarded footwork stays responsive.
86. As a player, I want run stops and plant-and-reverse pivots to take about 0.2–0.25 s and up to about 0.5 m, and a sprint stop about a third of a second and 1 m, so that every movement carries momentum and the weight visibly shifts.
87. As a player, I want the rules to move me exactly as the start, stop and pivot clips do, so that what I see is where I am.
88. As a player, I want a tap step to keep its instant start, so that spacing stays precise.
89. As a player, I want attacks, dodges, backsteps, parries and blocks to start at once out of any movement, with the leftover momentum shown only in the hand-off, so that defence and offence stay responsive.
90. As the owner, I want an attack started out of a run to keep none of the run's speed in the rules, so that the attack's travel comes only from its clip. **(P14, confirmed Oct 4)**
91. As a player, I want running fighters to lean forward, so that movement looks real.
92. As a player, I want the roll and the backstep re-keyed to fit their protected frames at the clip's own speed, so that dodges look evasive and real.
93. As a player, I want the jump, the landing and the jump attacks keyed to the rules' jump arcs, with a jump attack starting only while its startup and active frames fit the airtime left and a landing never skipping an air attack's frames **(P53, confirmed Oct 4)**, so that a jump looks like the arc that decides it.
94. [x] As a player, I want every hand-off between motions to use inertial blending, the new motion starting at once and the old pose fading over a few frames, hit reactions included, so that nothing pops. (Ticked with task 23.)
95. As a player, I want authored transition clips (returns to guard, bridges between the hits of a string, run stops and pivots) on top of the blending, so that hand-offs look keyed, not computed.
96. [x] As a developer, I want inertial blending and the physical reaction layer built as custom skeleton modifiers that change only the picture, so that the rules never depend on them. **(P11, confirmed Oct 4)** (Ticked with task 70.)
97. As a player hit by an attack, I want a directional reaction (front, left, right or back; high or low; light or heavy), so that I can see where the hit landed.
98. [x] As a player, I want a physical layer on the spine, head and arms, pushed from where and how hard the hit landed, so that every hit lands a little differently. (Ticked with task 70.)
99. As a player, I want the knockdown (fall, down, rise), the stuns and the staggers re-keyed to fit their retuned frames at their own speed, so that the biggest hits feel big without a sped-up clip.
100. As a player, I want knockback and pushback to come from the reaction clips' travel, the recall burst's knock-back included, so that a fighter moves only as clips carry them.
101. As a player, I want planted feet to slide no more than 1 cm under every clip, so that the fighter looks connected to the floor.
102. [x] As a player, I want the weapon to ride the clip's hands in every state, guard and free movement included, so that it never leaves the hands. **(P34, confirmed Oct 4)** (Ticked with task 135.)
103. As a player, I want the blade never to pass through the body, so that the illusion holds.
104. As a player, I want hits decided by a path taken from the same clip I see, kept as tight to the weapon as possible, so that I trust what I see.

### Defence on screen

105. As a player, I want each attack direction to have its deflect pair, the parrier's deflect and the attacker's recoil, so that a parry looks like Sekiro's rather than a clip played backwards. **(P9, confirmed Oct 4)**
106. [x] As a player, I want the two blades to meet at the contact point on a parry, where sparks fly and the clang starts, so that the parry lands where I see it. (Ticked with task 34.)
107. As a player, I want a block to show my guard taking the impact, light or heavy, so that blocking feels solid.
108. As a player, I want a plain parry, a Flash and a redirect to read apart through their own deflect pairs, sounds and sparks, so that I know which one happened.
109. [x] As a player, I want every parry, Flash and redirect to give a short camera push-in, frozen in hit-stop and turned off by Reduce flashes, so that the moment lands. **(P8, confirmed Oct 4)** (Ticked with task 39.)
110. As a player, I want the stomp against Piercing Thrust and the leap over Swallow Sweep played as paired clips, the two fighters lined up over a few frames so their bodies meet, so that counters look real.
111. As a player facing an unblockable, I want a red 危 to flash with a sound and the blade to glint red as the wind-up starts, with the attack type reading from the animation, so that I know which counter to use.
112. As a player in a match, I want an unblockable's reach shown only through the red 危, its sound and the blade's glint, with labels and floor markers only in Training, so that the screen stays clean. **(P6, confirmed Oct 4)**
113. As a player knocked down, I want to be invulnerable while down, stand up on a fixed timer and be able to block or parry while rising, as today, so that knockdowns can't be looped.

### Finishers

114. [x] As a player who disarms an opponent at 5% HP or less, I want the disarm to play in slow motion and give me one timed prompt, so that I can end the round with a finisher. (5% is 5 HP at today's 100 maximum.) (Ticked with task 103.)
115. As a player, I want the prompt to be heavy, shown as the button's glyph over the disarmed fighter and pressed within about a second of slow motion, so that it's clear what to press and when.
116. [x] As a player, I want a press made before the prompt appears not to count, the input buffer included, so that mashing can't take the finisher. (Ticked with task 103.)
117. [x] As a player who misses the prompt, I want the disarm to play out as normal, so that the round goes on. (Ticked with task 103.)
118. [x] As a player being finished, I want no escape once the finisher starts, so that defence happens before the disarm, as with strings. (Ticked with task 103.)
119. As a Katana player, I want the Katana's finisher: I sheathe, then draw in a lightning-fast iai slash that carries me through to stand behind the opponent; I re-sheathe, and as the guard clicks home blood sprays along the cut and the opponent falls in two halves, cut diagonally from one shoulder to the opposite hip, so that the finisher is the game's signature moment.
120. As a disarmed player who redirects an armed opponent at 5% HP or less into a disarm, I want the bare-hands finisher: I turn their last attack aside, then drop them with a crushing palm to the chest or a blow to the throat, cutting nothing, so that bare hands can finish too. When a disarmed fighter disarms by a blocked Breaker Palm or a fully charged Roundhouse instead, the same finisher opens and plays from its strike, skipping the turn-aside **(P52, confirmed Oct 4)**.
121. As a player, I want each finisher played as a paired clip with its own cinematic shot, so that it reads as a killing move.
122. As a player with Blood set to Reduced, I want the Katana's finisher to show the cut with less blood and the body staying whole, and with Blood Off no blood at all, so that I choose how graphic it is.
123. [x] As a player against the computer, I want it to use finishers too, landing them more often on higher difficulties **(P3, confirmed Oct 4)**, at the rates in the computer's finisher rates table **(P55, confirmed Oct 4)**, so that it plays by the same rules. (Ticked with task 107.)
124. [x] As a Training player, I want a finisher to play in full and the HP then to refill, so that I can practise finishing. **(P3, confirmed Oct 4)** (Ticked with task 107.)
125. As the owner, I want a finisher to end the round as a KO, called Warrior Slain, so that rounds end one way.

### Round flow, cinematics and the camera

126. As a player, I want the Hunter to draw the Katana from its saya at the left hip at the round intro, at final quality and at the clip's own speed, so that each round opens with a moment.
127. As a player, I want "Fight!" called when both draws reach their ready pose, so that the intro lasts as long as its motion and no longer. **(P41, confirmed Oct 4)**
128. As a player, I want a KO that ends a round, other than a finisher, to play on the gameplay camera, with the slow motion, the sound drain and the Warrior Slain call, so that the fight's flow isn't broken mid-match. A finisher plays its own shot **(P38, confirmed Oct 4)**.
129. As a player, I want the round's winner to sheathe, or shake out their hands if disarmed, as a short beat after a round KO, so that the round closes cleanly.
130. As a player, I want the authored KO shot and the full victory pose (the Katana's sheathe and bow, or bare hands' cheer) to play only for the KO that wins the match, so that the match end feels bigger than a round end.
131. As a player, I want neither the round-end beat nor the victory pose to play its own sheathe after a Katana finisher, which already re-sheathes; the winner holds the finisher's end pose through Warrior Slain, and the victory pose starts from it, so that the blade isn't sheathed twice. **(P4, confirmed Oct 4)**
132. As a player, I want every KO that ends a round, finishers included, called Warrior Slain with the brushed kanji 討死 in place of 一本 K.O., and a double KO to keep its own call, so that the call fits the game.
133. As a player, I want an ultimate's wind-up to stay on the gameplay camera, with the roar and a push-in, and its cinematic shot to play only once it connects, so that I can read and answer it.
134. [x] As a player, I want the camera over the shoulder, framed like For Honor (the mood board's Camera 2, chosen Oct 4 in place of "slightly more zoomed out") and locked on to the opponent, with its framing settled in the look test scene **(P20, confirmed Oct 4)**, so that I see both fighters and the space between. (Ticked with task 30.)
135. As a player, I want the camera clean during play (temporal anti-aliasing, subtle bloom, ambient occlusion, fog, the colour grade and light film grain, with no depth of field, motion blur or colour fringing), with those effects coming in only for the ultimates' and finishers' shots, the push-ins and the KO, so that wind-ups stay readable.
136. As a player, I want hit-stop, camera shake on heavy blows and slow motion on the final blow at the new pace, so that big moments land.

### The look

137. [x] As the owner, I want to approve a mood board, with a UI page on it, before anything converts, with the ultimates' energy (element and colour) and the gameplay camera's framing settled on it too **(P20, confirmed Oct 4)**, so that the look is agreed before work is spent on it.
138. [x] As the owner, I want a look test scene (one fighter with the Katana in a corner of the Moonlit Shrine at Ultra on the RTX 3090) approved before the art converts, settling the lighting and the camera effects, so that the realistic look is proven in Godot first. (Ticked with task 30.)
139. As the owner, I want clip work to start at once and only the art conversion (materials, models, the arena, how effects look and the UI style) to wait for the mood board and the look test, so that animation isn't blocked by the look. **(P2, confirmed Oct 4)**
140. As a player, I want the realistic look (physically based materials, dark lighting and volumetric fog under a painterly grade, after Ghost of Tsushima's darker side), with no toon shading, outlines or ink-wash, so that the game looks like the dark fantasy it means to be.
141. As a player, I want the Hunter's two palettes re-dyed crimson and indigo in realistic materials with wear and oriental patterns, so that the sides read apart and match the HUD's red and blue.
142. As a player, I want key and rim lights that touch only the fighters, so that the fighters stand out of the dark without outlines.
143. As the owner, I want a test that the crimson and indigo palettes read apart in grey, so that the black-and-white mode can come after this milestone without re-dyeing.
144. As a player, I want the Hunter's tricorn and scarf remodelled in Blender with oriental touches, the scarf's ends swinging on spring bones, so that the silhouette reads and moves.
145. As the owner, I want the Hunter's body re-textured, not remodelled, with a neutral face and no cloth simulation in milestone 1, so that new models, cloth and faces wait for milestone 2. **(Oct 6) Superseded by ADR 0002:** both bodies are re-proportioned about 15% taller in milestone 1 (`docs/specs/katana-elden-ring.md`).
146. As a player, I want the Katana and its saya modelled in Blender to fit the look, keeping today's 0.72 m blade within 2 cm **(P44, confirmed Oct 4)**, so that the weapon I watch most is real. **(Oct 6) Superseded by ADR 0002:** the blade becomes 1.3 m (`docs/specs/katana-elden-ring.md`).
147. As the owner, I want the art made from CC0 scanned materials and models (Poly Haven, ambientCG) and models built in Blender, partly by script, with generative AI used only for the mood board, so that every asset can be sold.
148. As a player, I want the Moonlit Shrine upgraded in place, keeping its layout: its props first, then its materials, and last its platform, so that the arena I know becomes the arena of the design.
149. As a player, I want huge, ancient wisteria with dark bark around the arena, their blossoms glowing purple and lighting the fight, a canopy that never hides the moon or the fighters, and glowing petals falling, so that the Shrine looks like the design's.
150. As a player, I want worn, weathered, uneven and broken paving, mist drifting through the moon shafts, a blood moon and a starry sky, so that the arena feels ancient.
151. As a player, I want the distant landscape in real 3D (sculpted mountains and cliffs, pagodas and temples, volumetric fog and clouds), simpler on Low, so that the arena floats in a real world.
152. As a player, I want banners, and grass in the broken paving, so that the wind and the fight have something to move. **(P21, confirmed Oct 4)**
153. As a player, I want one wind moving the clouds, the branches, the petals, the grass, the banners and the cloth, so that the night feels alive and consistent. In milestone 1 the cloth is the scarf's spring bones and the banners **(P46, confirmed Oct 4)**.
154. As the owner, I want only the clear night in milestone 1, with both performance gates measured on it, so that the weather system and its other four states come after sign-off.
155. As a player, I want the arena to react in the picture only, with the marks lasting the whole match, so that the fight leaves its trace without changing the rules. The reactions milestone 1 shows are cut marks and scorch on stone, sparks off pillars, dust and cracks where blows hit the ground, and banners and grass pushed by swings and falls **(P42, confirmed Oct 4)**.

### Effects and blood

156. [x] As a player, I want realistic sparks at the contact point on blocks and blade clashes, so that contact reads. (Ticked with task 37.)
157. [x] As a player, I want hits to draw blood (a burst on each blade hit, blood on blades and clothes for the whole match, and splatter on the floor that fades), so that the duel has weight. (Ticked with task 38, in today's toon look; the art conversion carries the stains into the realistic materials.)
158. As a player, I want a bare-hand hit to show its own impact rather than a blade's blood burst, so that fists read apart from blades. **(P36, confirmed Oct 4)**
159. [x] As a player, I want air smears on fast swings in place of the brush trails, so that swings read without ink. (Ticked with task 37.)
160. As a player, I want dust and smoke where feet, falls and rolls meet the ground, where the clips' feet land, so that movement has weight.
161. [x] As a player, I want a Blood setting of On, Reduced or Off, shipped in milestone 1 and On by default **(P5, confirmed Oct 4)**, so that I choose. (Ticked with task 38; the finishers' Reduced and Off cut lands with the finisher tasks.)
162. As the owner, I want the age rating to cover blood and the Katana finisher's cut, with the Blood setting as the player's control: the sign-off build, answered through the IARC questionnaire Steam offers, rates no higher than PEGI 18 and ESRB Mature 17+, with the finisher's two halves as its strongest content, and the owner answers it at sign-off **(P56, confirmed Oct 4)**, so that the game can be rated and sold.
163. As a player, I want the ultimate-ready aura as a smouldering glow of embers and heat haze in my side's colour, shown only while my ultimate is ready and I'm not knocked out, so that readiness reads.
164. As a player, I want Moonsplitter's wave rendered with supernatural energy, lit realistically and standing where the rules put it on each frame, so that the ultimate is both spectacular and honest.
165. As a player, I want the disarmed ultimate's choice moment, Breaker Palm's blow and the recall's burst rendered realistically, so that bare hands' ultimate matches the Katana's.
166. As a player, I want the dropped-weapon beam retired and the stuck weapon to show a faint glint, so that the weapon reads without a toon marker. **(P7, confirmed Oct 4)**
167. As a player, I want the disarm's effect to follow the weapon's flight into the ground, the counters' effects to land on their paired clips, and the KO's effect to lead into Warrior Slain, so that effects match motion.
168. As a developer, I want a parity check that every rules event has an effect or sits on an explicit no-visual list, with shake and kick amounts included and every effect following Reduce flashes, so that no event goes unseen.

### Sound and music

169. As a player, I want footsteps where the clips' feet land, sounding like stone, so that movement sounds grounded. **(P21, confirmed Oct 4)**
170. [x] As a player, I want metal impacts that depend on which weapons meet, a distinct ring on parries and Flash, flesh and bone layers that match the blood, and the Hunter's own cloth and gear movement sounds, so that combat sounds physical. (Ticked with task 36, for milestone 1's weapons: the Katana and bare hands; the other pairs keep the general clangs until milestone 2.)
171. As a player, I want the deflect pairs, the stuck weapon, the pull-out, the finisher prompt and both finishers to have their own sounds, so that every new event is heard.
172. As a player, I want the final hit to ring out as the slow motion drains the arena's sound and the music, then a deep drum under Warrior Slain, so that a round's end is felt.
173. As a player, I want the 危's warning sound distinct from everything else, so that I hear an unblockable coming.
174. [x] As a player, I want placeholder effort vocals (breaths, kiai shouts on heavies, pain on hits, death cries), so that the fighters aren't silent until a vocals pack is bought after this milestone. (Ticked with task 114.)
175. [x] As the owner, I want the code-generated score extended with the shakuhachi, the biwa and a low choir beside its taiko, with electronic and metal layers rising at match point, while the menus keep the groovier fusion, so that the sign-off build sounds like the design. (Ticked with task 113.)
176. As the owner, I want a listening pass on each family's sounds as part of its review, the roll's sound included, so that sound reaches final quality with the moves.

### HUD, menus and settings

177. As a player, I want the HUD fully redesigned for the realistic look (HP bars, the posture bar underneath, round pips and the ultimate badge), keeping its layout, in the style of the mood board's UI page, so that it fits the game.
178. As a player, I want the round calls redesigned in brushed calligraphy, with Warrior Slain among them, so that ink survives where it belongs.
179. As a player, I want the finisher prompt designed as the heavy button's glyph, from the device I last used, over the disarmed fighter, so that I can read it in the slow motion.
180. As a player, I want the HUD's off-screen marker for my dropped weapon restyled and lifted to clear the stuck weapon's hilt, so that I can always find my weapon. **(P7, confirmed Oct 4)**
181. [x] As a player, I want the menus to take the new theme (colours, fonts and panels) so nothing looks ink-wash, with their layouts redone later, so that the game looks consistent. (Ticked with task 53.)
182. [x] As a player, I want four graphics presets (Ultra, High, Medium and Low), with Ultra as the reference preset, so that the game runs on my machine. (Ticked with task 29.)
183. [x] As a player, I want the first launch to pick a preset from my graphics card, so that the game starts well without fiddling. (Ticked with task 29.)
184. As a player, I want Ultra to render at about 1440p–1800p and upscale to 4K with FSR 2.2, and Low to drop only atmosphere (volumetric fog becomes height fog, petals stop casting light, no ambient occlusion, fewer decals) while keeping the palettes, the rim lights, blood, the 危 and the cinematic shots, so that every preset reads the fight.
185. As a player, I want Settings to hold the Blood setting, and Reduce flashes to cover every new effect, shake and push-in, so that comfort options stay complete. **(P7, confirmed Oct 4)**
186. As a player reading How to play, I want it to describe finishers, Warrior Slain and the slower pace, so that it matches the game.
220. As a developer, I want the whole-flow walks (keys only, controller only) and every screen's shot scene run again after the UI redesign, so that the new theme breaks no screen.

### The computer opponent, Training, Watch and Versus

187. [x] As a player, I want the computer to read the generated frame-data table, so that its defence follows the clips as they're re-animated. **(P17, confirmed Oct 4)** (Ticked with task 24.)
188. [x] As a player, I want the computer to time its defence from each swing's first touch and ignore moves that can't reach, so that it defends fairly at the new pace. (Ticked with task 24.)
189. [x] As a Training player, I want the dummy to perform every milestone-1 unblockable (Piercing Thrust and Swallow Sweep) through one shared routes table, and the Katana dummy's heavies to alternate both Iai variants, so that I can drill every counter the milestone has. (Ticked with task 83.)
190. [x] As a developer, I want counterlab to show the stomp and the leap reached, with the evade waiting for milestone 2, so that every reachable counter is proven. (Ticked with task 83.)
191. As a player, I want the computer to use and answer the Iai (quick draws, walking in sheathed, both variants, the follow-ups, dodging out when attacked; against a sheathed opponent, keeping out of range, punishing or parrying the release), landing it from the Iai's distance band, so that it plays the Katana well.
192. As a player, I want the computer to deal with a stuck weapon (standing in my way when I'm disarmed, running for its own when it is), so that the disarm game stays live against it.
193. As a player, I want the computer to use its ultimates by today's rules at the new pace (Moonsplitter when the opponent is 2.5–14 m away and neither knocked out nor invulnerable; when disarmed, the recall when the opponent is farther than 2.5 m and Breaker Palm when closer), with those distances rechecked against the distance bands, so that ultimates appear in its play.
194. As a player, I want Watch's two computer fighters to play the mirror match at the new pace, so that I can learn the moves by watching.
195. As a Versus player, I want split screen to hold its own target (60 fps at High on the RTX 3090), so that two players get a smooth game. **(P19, confirmed Oct 4)**
196. As a Training player, I want the unblockables' labels and the floor reach marker shown in Training only, so that I can study reach without cluttering matches.

### Checks, balance and performance

197. As the owner, I want a balance run of mirror matches to come out clean (no failures, rounds of 60–90 s, 0.3–0.6 disarms per round, finishers in some rounds, and the stomp, the leap, Flash, both ultimates and a pick-up all appearing), so that the pace and the rules work together. Each fighter's two block abilities are picked at random, so that all three of the Katana's, and so the stomp and the leap, can appear **(P49, confirmed Oct 4)**.
198. As the owner, I want the finisher share set after the first balance run, so that the target rests on data.
199. [x] As a developer, I want the soak to play mirror matches, report finishers and the appear-list, and turn per-weapon win rates off until milestone 2, with its round-length target changed to 60–90 s **(P24, confirmed Oct 4)** and each fighter's two Katana block abilities picked at random (seeded) from Flash, Piercing Thrust and Swallow Sweep **(P49, confirmed Oct 4)**, so that the soak checks what milestone 1 promises. (Ticked with task 7.)
200. As a developer, I want milestone 1's tuning to change only damage, posture, parry and computer numbers, one change per commit, asking the owner after five changes in a row with a target still out, so that frame data and footwork stay the clips'.
201. As the owner, I want "holds 60 fps" to mean 99% of frames at 16.7 ms or less in a scripted worst-case replay with shaders warmed up first, for Ultra at 4K on the RTX 3090 and for Low at 1080p on the laptop, so that the gate means one thing. **(P19, confirmed Oct 4)**
202. As a developer, I want the worst-case replay (both ultimates, a finisher, blood and petals, at the wall) to run from a recorded input log, so that every bench measures the same match. **(P19, confirmed Oct 4)**
203. As the owner, I want Training and Watch to meet the Duel's gate, so that no mode is slower. **(P19, confirmed Oct 4)**
204. As the owner, I want the laptop kept available for benchmarking the Low preset, so that the Low gate is measured on real hardware. **(P25, confirmed Oct 4)**
205. As a developer, I want size budgets per place (the public repository, each asset in the asset repository, the shipped game) checked in place of the 110 MB art cap, with the numbers in the size budget table **(P23, confirmed Oct 4)**, so that size stays under control.
206. As a developer, I want the tests that pin the demo's frame data, assert toon materials or outlines, or cap art at 110 MB replaced as milestone 1 lands, so that the suite tests the game being built.
207. As the owner, I want every check green at sign-off (the tests and the typecheck, the frame-data and band checks, the replay and save-and-restore tests, the grey-palette test, the size budgets, the smoke run, the whole-flow walks with keys only and with a controller only, and the local-only re-bake on the owner's PC), so that the milestone ends on a clean build.

### Review, sign-off and the Godot check

208. As the owner, I want every move to pass a written checklist before the milestone ends, the items in the per-move checklist table **(P32, confirmed Oct 4)**, so that "final quality" is concrete.
209. As the owner, I want moves to come to me family by family, each with contact sheets, a side-by-side video against the reference games and a play session with the licensed clips loaded, so that I judge each as a player would. **(P22, confirmed Oct 4)**
210. As the owner, I want the reference-game footage to stay on my machine, so that nothing licensed is committed. **(P22, confirmed Oct 4)**
211. As the owner, I want Claude to make the first passes by script in Blender (longer wind-ups, re-gripped hands, travel, block-outs of new clips) and to polish the signature moves (the Iai, the deflect pairs, the finishers) myself in Cascadeur, bought when the first polish starts, with Claude preparing each Cascadeur scene and exporting the polished clip by script (Oct 6), so that each of us does what we do best.
212. As the owner, I want the Godot check judged at the pilot family and at the look test scene against written criteria, and confirmed at sign-off, so that the engine question is settled on evidence. The criteria are in the Godot check table **(P31, confirmed Oct 4)**.
213. As the owner, I want to sign off milestone 1 by playing the real build with the asset repository, once every move passes its checklist, both performance gates hold, the balance run is clean and every check is green, so that the milestone ends on the game, not on a report.
214. As the owner, I want a spending review at the end of milestone 1 (inside the roughly $300 for both milestones, Cascadeur Indie and any Git LFS storage first), so that the next purchases, a vocals pack among them, are made knowing what's missing. No animation packs are bought for the existing content: the owned Kevin Iglesias packs and clips keyed in Blender are the animation sources.

### Upkeep

215. As a developer, I want the procedural poses (the stick poses, the swing player, the weapon-hold idles, the demo swings and the posing of weapons in space) retired once the clips' hands hold the weapons, so that no second animation system remains. The labelled stand-ins that clones and CI play stay. **(P34, confirmed Oct 4)**
216. As a developer, I want a director test that every move of every weapon resolves to a clip, so that nothing falls back silently.
217. As a developer, I want the rules-tuned lunges, the recovery slide, the dodge-cancel formula, the reach push and the clip retime (1.0–2.0×) retired for the Katana and bare hands, and the locomotion's stride-matched playback rate (PR #21) retired with them (gait clips play at 1.0× and the rules move at their measured speeds), so that only clips move fighters.
218. As a developer, I want every place this spec changes `docs/design.md` or the older specs updated on `docs/milestone-1-spec` once the owner approves this spec, before its pull request merges (the new `GLOSSARY.md` terms are already there), so that the docs agree before any code is built.
219. As a developer, I want `docs/architecture.md` updated as modules appear and retire, so that the next reader finds their way.

## Implementation Decisions

Module names are the code's; the plan names the files. The tables at the end of this section hold the values these decisions refer to. Every number in them was proposed with this spec and confirmed by the owner on Oct 4 (P1–P56) unless it is marked as today's or as the owner's. Times are at 60 rules frames a second (one frame is 16.7 ms).

### Decisions in plain English

| Decision | Choice | Why |
|---|---|---|
| What leads | The clip: frame data and footwork are generated from it | ADR 0001; the motion was fitted to the rules and looked stiff |
| What stays a rules number | The protected timings, the jump arcs, damage, posture, knockback strength | Defence must be consistent; the jump must clear sweeps the same way every time |
| Pace | Katana lights 400–500 ms; everything else scaled from that | The owner's anchor, close to For Honor |
| Order | Pipeline, then the pilot family, then families one at a time | Prove the method on one family before spending it on the other 31 re-keyed moves |
| Who keys | Claude's scripted first passes in Blender, and Claude's scripted Cascadeur set-up (the rig, each clip's scene) and export; the owner's Cascadeur polish of the Iai, deflect pairs and finishers | Claude scripts Blender, and since Cascadeur 2026.2 scripts Cascadeur too, over its MCP server while the owner has it open (tested Oct 6, `docs/research/cascadeur-python-api.md`); the polish needs the owner's eye |
| Roster | The Hunter and the Katana only, behind a dev flag for the rest | Every match is one the milestone has finished |
| Look | Mood board, then a look test scene, then conversion | Agree the look before converting anything |
| Engine | Godot stays unless the written check clearly fails | ADR 0001 |
| Determinism | Snapshot, restore, state hash and input log on the rules | Online play last, without a retrofit |

### Order of work and branches

- Milestone 1 waits on the consolidation: `docs/plans/godot-rebuild.md` stage 14, ending with task 26.4 merging `feature/godot-rebuild` into `master`. Its code's branch, `feature/milestone-1`, is cut from `master` then, and its pull request targets `master` (until Oct 6, when the owner folded it into `master`: since then each lane's pull request targets `master` directly). This spec and its plan go earlier, on `docs/milestone-1-spec` through a draft pull request into `feature/godot-rebuild`, and reach `master` with the consolidation.
- The work runs in this order: (1) the pipeline (asset repository, Blender export and clip import, frame-data generator with the band tests, replay and save-and-restore tests, the Studio's slimming, the protected-timing retune); (2) the mood board, started at once and in parallel with the pipeline; (3) the pilot family keyed, with its sound and rules, and alongside it the look test scene, built as soon as the mood board is approved and showing the pilot's moves; (4) the pilot's effects made in the approved look, the pilot's final review by the owner (its play session ending the protected-timing retune), and the first Godot check, then the art conversion; (5) the other move families one at a time; (6) the closing checks: effects parity, the performance gates, the balance run, then the owner's sign-off. Clip work never waits for the look **(P2, confirmed Oct 4)**: the pipeline and the pilot's keying start at once, and only the pilot's effects wait for the look test, so the pilot reaches final quality whole before any other family starts, as the owner decided. If the look test runs late, the owner decides at a review of the pilot's motion whether family 2 starts before the pilot's effects are final **(P51, confirmed Oct 4)**.
- The godot-rebuild master follow-ups run on `master` at the same time. Milestone 1 restyles what they build (the toasts, prompts and dropped-weapon marker, the Versus HUD, the fighter-select preview, the Reduce flashes wiring) and does not wait for them, except where a milestone-1 story needs the function: the finisher prompt builds on 24.4's prompts, the off-screen marker restyle on 24.5, and Reduce flashes covering the new effects on 18.11.

### The roster during milestone 1

- A roster filter decides what the menus offer: by default the Hunter and the Katana; with the dev flag (a command-line flag, also settable for tests) the Rogue, the Greatsword and the Twin Daggers too. Every place that lists fighters or weapons reads the filter: the fighter grid, the weapon cards, a random weapon at lock in, the How to play tabs, Training's weapon-for-drill fallback and the soak.
- The match defaults (Duel, Training, Watch, the attract duel and the select draft) become the Hunter against the Hunter with the Katana, crimson against indigo.
- Training's slam drill is unavailable while the Greatsword is hidden; the Katana has no slam.
- Bare hands stay the disarmed state, not a loadout **(P1, confirmed Oct 4)**.

### The asset repository, the export and the import

- A private GitHub repository with Git LFS holds the Kevin Iglesias packs, the Quaternius sources the game uses, the Blender sources (fighters, the Katana and saya, the Shrine's models, re-keyed and new clips) and every scripted export. Today's asset-source setting points the import tools at its checkout. The raw Sonniss zips stay outside it; processed sounds stay in the public repository as today.
- Which exports the public repository also holds: the exports of self-made and CC0 art (the Katana and saya, the Hunter's tricorn, scarf and re-dyed materials, and the Shrine's models and materials) are committed there too, inside its 150 MB art budget; what doesn't fit, such as full-resolution textures, stays in the asset repository only, and plain clones play a reduced copy or a labelled stand-in **(P23, confirmed Oct 4)**. Clip exports stay in the asset repository only, since most derive from the Kevin Iglesias packs (every retargeted or re-keyed pack clip), whose licence forbids redistribution; plain clones and CI play the CC0 stand-in clips and the committed frame-data table instead.
- A Blender export script, run headless, turns each Blender source into the file the game imports (glTF for models and clips), and records each export's source file. It is the only way art reaches the game.
- The clip import grows a second source beside the pack FBX paths: exported clips from the asset repository, named in the clip manifest by asset-repository path instead of pack, set and source. Both go through the same retarget, mirroring and library build. A manifest entry may name an exported clip that replaces a pack clip; the pack clip stays recorded as its origin.
- The prop bones of the Iglesias rig are kept on import where a clip needs the weapon's own motion (the Iai's draw, the finisher's re-sheathe, the recall's catch), instead of being dropped as today.

### The frame-data table and the generator

- The generator is today's bake turned round: it reads each move's clip (or chain of clips) at 1.0×, reads its markers, and writes, instead of checking against hand-typed numbers. It is deterministic, and runs headless in CI on the committed CC0 stand-ins (for its own tests) and locally on the real clips.
- The committed table holds, per move: the weapon, the move, its kind (the timing band's row), the source clip or chain with each part's source frames, startup, active and recovery in rules frames, the dodge-cancel window, each follow-up's branch point and window, per-frame travel (forward, sideways and turn, from the hips and foot plants), and two checksums: the source clip's, which only the local re-bake test can check, and a digest of the move's generated row together with its swing file, which CI recomputes from the committed files so that a hand edit to either fails. The hit paths stay in the swing files, regenerated in the same run; swings are sampled relative to the moving body **(P13, confirmed Oct 4)**. Per gait it holds the measured speed, stride and foot contacts; per start, stop and pivot clip its length and travel.
- The table also holds every non-attack clip that sets a rules length, since neither the rules nor CI can read clips: the draw's ready frame (when "Fight!" is called, P41), the pull-out's length and the frame the weapon is in hand (P16), each finisher's length, kill frame and paired placement, the stomp's and the leap's paired lengths and placement, the round-end beats' and the victory poses' lengths, and each state clip's length. Each is recorded in rules frames with its markers, its source clip and the same two checksums.
- Move data keep only what design sets: damage, posture, knockback, kind, type, unblockable and counter flags, the follow-up graph and the protected-timing overrides. `AttackDef`'s startup, active, recovery, dodge-cancel and travel fields are filled from the table when the moves load, so every reader keeps reading `AttackDef` fields.
- The rules-set lunges (their start, end and eased share), the recovery slide, the reach push and the run-speed carry into attacks retire for the Katana and bare hands **(P14, confirmed Oct 4)**. The Greatsword and Daggers get their startup, active and recovery from their current clips at 1.0× through the same generator, with no band test **(P10, confirmed Oct 4)**, and keep their rules lunges, the colossal slide and the shoulder carry until milestone 2 re-keys them **(P45, confirmed Oct 4)**. Both Counter Lunges do the same on today's clips **(P48, confirmed Oct 4)**.
- The timing bands and the distance bands are committed data tables, one row per move kind per weapon, read by the band tests and shown by the Studio. A move has one kind, and so one band, wherever it is played from; the moves reached from more than one slot are listed under the timing band table **(P26, confirmed Oct 4)**.
- CI checks that the committed table is complete (every move and every rules-length clip has an entry), generated (the digests match), and that every Katana and bare-hands move is in band. A local-only test re-bakes every move from the real clips and fails on any drift **(P12, confirmed Oct 4)**.

### Protected timings

- The protected timings stay rules constants. Beside design's list, the stuns the counters buy (the stomp, Flash and the redirect), the disarm's stagger and the disarmed fighter's daze, and the parry recoil with the parrier's recovery join them, since they decide how many hits a counter or a parry buys **(P50, confirmed Oct 4)**. The finisher prompt is a new rules number frozen with them (P35).
- They are retuned once, in the pipeline phase, from the band floors by the rules in the protected-timing table. The pilot family's play session ends that one retune: it may adjust the values, and then they are frozen **(P28, confirmed Oct 4)**. No later family's play session changes a protected timing; the clips are keyed to fit them. A test pins the frozen values; changing one needs the owner's OK and an entry in this spec.
- The retune covers the Katana and bare hands. The Greatsword and the Daggers keep today's protected timings, the Daggers' 10 frames of string hitstun included, until milestone 2 re-keys them and retunes them once against their own bands. Both Counter Lunges, unreachable in milestone 1, take their weapon's retuned light hitstun (23 and 17, 24 and 18 since the Oct 5 correction in the protected-timing table), which closes the old question of 18 or 14 frames; whether the evade's reward needs more is asked when milestone 2 re-keys the evade **(P48, confirmed Oct 4)**.
- The free-frame rule is set by the retune and then checked over the table, not by hand. The retune sizes each hitstun so that, at the band floors, the defender is free 1–2 frames before the next hit of a light string can land. The check then holds every follow-up pair in the table to at least 1 frame (no follow-up is guaranteed), counting from a hit on the move's last active frame and the follow-up taken at its branch point **(P28, confirmed Oct 4)**. The earliest branch points under the timing band table keep that true at the band floors. A clip whose branch point breaks the rule is re-keyed; a slower clip only gives the defender more time.
- The clips that show protected timings (the roll, the backstep, the knockdown phases, hitstun and blockstun reactions, the stuns, staggers and daze) are made to fit them: a test compares each state clip's length at 1.0× with its frames. The dodge's travel curve is regenerated from the re-keyed roll clip.

### Movement, gaits and momentum

- The rules' gait speeds (walk, run in each of the eight directions, sprint, the guarded strafe and shuffle, the disarmed gaits) come from the table's measured clip speeds. The rules gain a walk speed. The stick's tilt picks a blend of gait clips, and the rules move the fighter at the blended speed, kept in step.
- Starts, stops and pivots become short rules states driven by their clips' travel: a guarded start or stop (6 frames or fewer), a run stop and a plant-and-reverse pivot (12–15 frames, up to 0.5 m), a sprint stop (about 20 frames, about 1 m). Any attack, dodge, backstep, parry or block cuts in at once; the leftover momentum shows only in the blend. The tap step keeps its instant start.
- The blocking walk and the disarmed speed stop being multipliers on the run: they are the guarded and the disarmed gait clips' own speeds, chosen or keyed to about 55–65% and about 1.2× of the run **(P29, confirmed Oct 4)**. The Iai stance's strafe is a gait too, at its clip's measured speed; the draw's drift comes from the draw clip's travel **(P29, confirmed Oct 4)**. The disarmed dodge stays 1.5× the distance through a longer roll clip **(P15, confirmed Oct 4)**; the disarmed jump stays a rules number.
- A jump attack can start only while its startup and active frames fit the airtime left on the rules' arc; a later press is ignored. Landing no longer skips an air attack's frames forward to its active part: the attack's landing recovery plays from its clip **(P53, confirmed Oct 4)**.

### Strings, cancels and markers

- Today's four markers (wind-up, contact, contact end, settle) grow to: active start and end, the dodge-cancel window, each follow-up's branch point, and foot plant and lift, and, on the clips that set a rules length, their ready, in-hand, strike and kill frames. They live in the clip manifest and the per-move chain entries, and the slimmed Studio edits them.
- A follow-up starts at its branch point, not at the end of the active frames plus two, and a dodge cancel opens at its marker, not by today's formula.

### The finisher

- New rules: a disarm of a fighter at 5% HP or less (5 HP at today's 100 maximum; the disarming blow still deals no damage) opens the finisher prompt for the fighter who disarmed them. The rules count the prompt in rules frames while the world runs in slow motion: the match host steps the rules at the slow-motion rate, so 18 rules frames at 0.3× last about a second **(P35, confirmed Oct 4)**. A fresh heavy press inside the window starts the finisher; a press or hold from before the window doesn't count, and the input buffer doesn't carry one into it.
- The finisher is a paired state for both fighters: the rules line them up over a few frames to the clip's relative placement, the victim's inputs are ignored, and the round ends as a KO when the clip reaches its kill marker. Its length is its clip's, read from the table. New events: the prompt opening and closing, the finisher starting, and the kill.
- The weapon decides the finisher: the Katana's iai finisher when the armed fighter disarmed, bare hands' turn-aside-and-strike when the disarmed fighter redirected. When a disarmed fighter disarms by a blocked Breaker Palm or a fully charged Roundhouse instead (an armed fighter at full posture blocking a power attack or an ultimate is disarmed), bare hands' finisher opens too and plays from its strike marker, skipping the turn-aside, with the line-up made to that marker's placement **(P52, confirmed Oct 4)**. Under Blood Reduced and Off the Katana's finisher plays without the two halves, as a picture-only choice; the rules are the same.
- The computer opponent presses the prompt at its difficulty's rate in the computer's finisher rates table **(P3 and P55, confirmed Oct 4)**. Training plays the finisher, then refills HP **(P3, confirmed Oct 4)**.

### The disarm and the stuck weapon

- The dropped weapon stops drawing from the world's random number generator: its flight is a fixed arc along the knock or deflect direction, shortened to land inside the walls, and it lands stuck at an angle that is rules state **(P16, confirmed Oct 4)**. Nothing else in the rules uses that generator, so the other rules don't shift. The bounce, its event and the weapon-bounce sparks retire.
- The pick-up becomes pulling the weapon out of the ground; its length and the frame the weapon is in hand come from its clip **(P16, confirmed Oct 4)**. The recall still returns it.

### Determinism: snapshot, hash and input log

- `World`, `Fighter`, `Match`, `DroppedWeapon`, the world's random number generator (`Rng`, while anything still draws from it) and each `AIBrain` (with its own generator) gain a snapshot and a restore, and the world gains a state hash over everything the rules own. An input log records each step's inputs per side and replays them through the match host. These are the seams of the replay test, the save-and-restore test, the worst-case performance replay and the balance run's reproductions **(P18, confirmed Oct 4)**.

### Clip playback and the body

- The clip director plays every clip of the Katana and bare hands at 1.0× of the world's time (hit-stop and slow motion slow every clip alike): the fitted retime of state clips and the attack retime go, and the locomotion's stride-matched playback rate (PR #21) retires with them, so gait clips play at 1.0× and the rules move at their measured speeds. Hand-offs request an inertial blend instead of a crossfade, the hitstun cut included.
- Inertial blending and the physical reaction layer are skeleton modifiers in the fighter's rig, after the clip and before foot locking and the hands' grip; they change only the picture **(P11, confirmed Oct 4)**.
- Hit reactions pick a clip by direction (front, left, right, back), height (high, low) and weight (light, heavy) from the hit's contact point and the move. Blocks pick a block reaction by weight.
- Deflect pairs: each attack direction has a pair (the parrier's deflect, the attacker's recoil); a parry event carries the contact point and the direction, and both fighters play their half from the contact frame **(P9, confirmed Oct 4)**. A blade parrying a fist or foot plays a recoil with no cut.
- Paired clips (the stomp, the leap, both finishers) line the two fighters up over a few rules frames so their bodies meet; the alignment is rules movement, recorded in the table like any travel.
- The weapon is fixed to the clip's hands in every state, free movement included, using the clip's prop bone where the clip has one **(P34, confirmed Oct 4)**. The procedural poses (the stick poses, the swing player, the weapon-hold idles and the demo swings) retire for every weapon in milestone 1, the hidden ones included, which ride their current clips' hands **(P45, confirmed Oct 4)**. The labelled stand-ins that clones and CI play stay.
- The rules-authored knock-backs and lunges that remain (the recall burst's 2.0 m knock-back, Breaker Palm's lunge) become clip travel; Moonsplitter's wave stays a scripted rules hit, since it isn't body movement **(P43, confirmed Oct 4)**.

### Cinematic shots and the camera

- A shot director plays authored camera shots from data (a camera path, a lens, and the camera effects allowed) on the presentation side, never in the rules. Shots: Moonsplitter and Breaker Palm once they connect, both finishers, and the match-winning KO. The recall gets a push-in, not a shot **(P37, confirmed Oct 4)**. A finisher that ends a round plays its own shot through Warrior Slain, and a match-winning finisher's shot replaces the authored KO shot **(P38, confirmed Oct 4)**. After a Katana finisher, which already re-sheathes, neither the round-end beat nor the victory pose plays its own sheathe: the winner holds the finisher's end pose through Warrior Slain, and a victory pose starts from it **(P4, confirmed Oct 4)**.
- The camera rig gains a push-in for every parry, Flash and redirect, frozen in hit-stop and off under Reduce flashes **(P8, confirmed Oct 4)**. The gameplay camera's framing comes from the look test **(P20, confirmed Oct 4)**. The mood board set its target on Oct 4: For Honor's framing, the board's Camera 2 (about 3.4 m back, 1.0 m to the right (swinging out 0.6 m for each metre closer than 3.5 m), 1.75 m up, a 55° field of view), in place of today's 4.6 m back, 1.35 m right, 1.95 m up and 60°.

### Effects and blood

- The effect table grows from contact flashes to: sparks (block, parry, Flash, blade clash; by weapon pair), blood (hit burst, blade and cloth stains for the match, floor splatter that fades; scaled or removed by the Blood setting), bare-hand impacts **(P36, confirmed Oct 4)**, dust and smoke (feet, rolls, falls, knockdowns), air smears, the 危 and the blade glint, the ultimate aura, the ultimates' energy, the stuck weapon's glint **(P7, confirmed Oct 4)**, and the arena reactions' decals.
- How a Flash and a redirect read apart from a plain parry: their deflect pairs and sounds first, then their effects **(P39, confirmed Oct 4)**. The gold 奥義 ULTIMATE mark retires in matches **(P40, confirmed Oct 4)**, and the status flashes (evade, stagger, counter-ready, pick-up) retire in favour of the clips, the push-ins and Training's toasts **(P40, confirmed Oct 4)**.
- The brush-stroke trails, the ink splash, the stylised parry ring and the dropped-weapon beam and ring retire.

### Look, presets and the performance harness

- The mood board (`moodboard/` in the asset repository) was approved by the owner on Oct 4, subject to change: the look and grade as drawn; crimson dye #9e2b25 against indigo dye #1d2a4d (ΔL* 18.5, so they read apart in grey); Moonsplitter's wave as moonlight and the disarmed ultimate as a spirit shockwave, neither in a side's colour; the UI in lacquer and gold; and the gameplay camera framed like For Honor (Camera 2).
- Physically based materials under one colour grade replace the toon materials, outlines and ink-wash pass. The graphics presets become four data files (Ultra, High, Medium, Low), with Ultra the reference, FSR 2.2 upscaling on Ultra, and a first-launch pick from the detected graphics card. Low's upscaler is chosen at its first bench **(P30, confirmed Oct 4)**.
- A performance harness plays the worst-case input log in a window after a shader warm-up pass and writes every frame's time; the gate reads the 99th percentile. CI has no GPU, so the gates are owner-run measurements recorded in the plan, not CI checks.

### The Shrine and the wind

- The Shrine keeps its layout and arena definition. Props are replaced first (wisteria in place of the pines and dead trees, banners, grass, the lanterns, torii, pillars and temple re-modelled), then materials, then the platform. The distant landscape becomes real 3D.
- One wind object replaces the fixed wind vector and drives the clouds, the branches, the petals, the grass, the banners and the scarf's spring bones. It is presentation only. The weather system is not built.

### Sound and music

- The sound bank gains entries for every new event (deflect pairs, the stuck weapon, the pull-out, the finisher prompt and kill, Warrior Slain's drum, the 危), metal impacts chosen by the pair of weapons that meet, flesh and bone layers keyed to the hit, and stone footsteps at the clips' foot contacts **(P21, confirmed Oct 4)**. The KO drains the arena and music buses during the slow motion.
- The music generator gains the shakuhachi, the biwa and a low choir, and match-point electronic and metal layers; tempos stay inside the design's ranges.
- Effort vocals are placeholders from the Sonniss bundle and generated sounds until a pack is bought after the spending review.

### HUD, menus and settings

- A new UI theme replaces the ink-wash theme and its palette across every screen. The HUD, the round calls (Warrior Slain 討死 replaces 一本 K.O. in every mode at once; the double KO keeps 相打ち), the finisher prompt and the off-screen weapon marker are redesigned. Menu layouts are not redone.
- Settings gain the Blood setting (On, Reduced, Off; default On) **(P5, confirmed Oct 4)** and the four presets.

### The computer opponent, Training, the soak and counterlab

- The brain reads frame data from `AttackDef`, which the table fills, so it follows the clips **(P17, confirmed Oct 4)**; godot-rebuild tasks 12.2–12.5 run after the frame-data change. It learns the finisher prompt, the stuck weapon and the pull-out.
- Training's unblockable drills come from one routes table; Training plays a finisher, then refills.
- The soak plays mirror matches, targets rounds of 60–90 s **(P24, confirmed Oct 4)** and 0.3–0.6 disarms, reports the finisher share and the appear-list, and turns win rates off. It builds each fighter with two Katana block abilities picked at random (seeded) from Flash, Piercing Thrust and Swallow Sweep, instead of today's default of Flash and Piercing Thrust, so that every ability, and so the stomp and the leap, can appear **(P49, confirmed Oct 4)**. The menus' default loadout stays Flash and Piercing Thrust. Counterlab's Greatsword cases wait for milestone 2.

### The Animation Studio

- Kept: the gallery (done), the timeline over source frames, a frames-and-bands view (the generated frame data against the move kind's timing band, with the distance band's hit-or-miss check), the edit session, marker editing (extended to the new markers), the chain panel without speeds or holds, and save (markers and chains written, the table regenerated, out-of-band moves reported). Dropped: the frame-data editor, the state-timings panel, the refinement launcher, the chat panel, correctives, bone posing, IK handles and keyed-clip editing. The owner tries the slimmed Studio on the pilot family.

### The timing band table (P26, confirmed by the owner Oct 4)

"Lands in" is the startup: the frames from the move's first frame (its press, or its branch point for a follow-up) to its first active frame. The anchor is the owner's: the Katana's lights land in 400–500 ms (24–30 frames). The For Honor column is what its moves are commonly known to take, from public frame-data knowledge, to be checked against the owner's footage of the game; For Honor has no jumps and no stance-release like the Iai.

**The Katana (medium weapon)**

| Kind | Moves | Lands in (frames) | Lands in (ms) | Active (frames) | Recovery (frames) | For Honor, roughly |
|---|---|---|---|---|---|---|
| Light (string) | Right Cut, Return Cut, Kesa Cut, Crown Cut | 24–30 | 400–500 | 3–6 | 24–36 | lights 400–500 ms (openers often 500, chained lights 400–433) |
| String heavy | Heaven Splitter | 42–54 | 700–900 | 4–8 | 36–48 | heavies 700–1000 ms; chain-ending heavies about 700–900 |
| Iai draw, tapped (the sheathe included) | Iai Slash vertical, Iai Slash horizontal | 36–48 | 600–800 | 4–6 | 36–48 | between a light and a heavy |
| Iai draw from the stance (from the release) | the same, held | 15–21 | 250–350 | 4–6 | 36–48 | no match |
| Iai follow-ups | Rising Heaven, Returning Draw | 36–45 | 600–750 | 4–6 | 30–42 | chained heavies about 600–800 |
| Unblockable | Piercing Thrust, Swallow Sweep | 48–60 | 800–1000 | 4–6 | 36–48 | unblockables about 800–1100 |
| Sprint light | Running Draw | 27–33 | 450–550 | 4–6 | 30–42 | running attacks about 500–600 |
| Sprint heavy | Leaping Cleave | 42–54 | 700–900 | 4–8 | 36–48 | leaping heavies about 800–1000 |
| Dodge light | Wind Cut | 24–30 | 400–500 | 3–6 | 24–36 | dodge attacks about 400–500 |
| Dodge heavy | Whirl Cut | 36–48 | 600–800 | 5–8 | 36–48 | heavy dodge attacks about 600–800 |
| Backstep light | Rising Cut | 24–30 | 400–500 | 3–6 | 24–36 | as dodge lights |
| Backstep heavy | Lunging Cut | 36–48 | 600–800 | 4–6 | 36–48 | as dodge heavies |
| Jump light | Aerial Cut | 12–18 | 200–300 | 4–6 | to landing, then 12–18 | no jumps |
| Jump heavy | Falling Crown | 18–22 | 300–367 | 4–6 | to landing, then 18–24 | no jumps |
| Block ability (stance) | Flash | 2–4 | 33–67 | 18 (its window, kept) | 18–30 | parry inputs act at once |
| Ultimate | Moonsplitter (vertical, horizontal) | 54–66 to the wave | 900–1100 | the wave, as the rules run it | 36–48 | — |
| Counter Lunge | Counter Lunge | milestone 2 | | | | |

The jump bands must also land before touchdown: today's jump (0.95 m at 30 m/s²) is in the air about 30 frames, and 35 disarmed. Each jump attack's startup and active frames, at their band ceilings, fit inside the airtime from a press in the jump's first few airborne frames (Falling Crown 28 of 30, Axe Kick 33 of 35); a press later than that is refused once the move no longer fits the airtime left **(P53, confirmed Oct 4)**. A charged heavy's hold is an authored loop and doesn't count toward its band; its release counts from the release.

**Moves reached from more than one slot.** A move has one clip and so one band, wherever it is played from. Return Cut is the string's second light and the horizontal Iai's light follow-up (light band). Rising Heaven is the vertical Iai's heavy follow-up and Return Cut's heavy follow-up, so it is also the string's heavy as the third hit; it sits in the Iai follow-up band wherever it is played from. Heaven Splitter is the heavy follow-up of Right Cut, Kesa Cut and Rising Heaven (string-heavy band). Bare hands' Roundhouse is the neutral heavy and the heavy follow-up of Jab, Cross and Hook (string-heavy band).

**Earliest branch points** (frames after the move's last active frame), which keep the free-frame rule at the band floors and which the data-seam test checks: a light's follow-ups 1; a heavy's follow-ups (the Iai draws, the Iai follow-ups, the string heavies, Roundhouse) 18, so a light follow-up after a Katana heavy lands no sooner than 43 frames after the hit, against 41 frames of heavy hitstun **(P28, confirmed Oct 4; counted as the rules step, Oct 5)**. Only the string lights, the Iai draws and the heavies they lead to have follow-ups.

**Bare hands (faster than the Katana)**

| Kind | Moves | Lands in (frames) | Lands in (ms) | Active (frames) | Recovery (frames) | For Honor, roughly |
|---|---|---|---|---|---|---|
| Light (string) | Jab, Cross, Hook | 18–24 | 300–400 | 2–4 | 15–24 | its fastest lights about 400; a Tekken jab about 170 |
| String heavy | Roundhouse (chargeable), Spinning Heel | 33–42 | 550–700 | 3–6 | 30–42 | fast heavies about 600–700 |
| Sprint light | Flying Knee | 21–27 | 350–450 | 3–6 | 24–36 | |
| Sprint heavy | Dragon Kick | 33–42 | 550–700 | 4–6 | 30–42 | |
| Dodge light | Slip Jab | 18–24 | 300–400 | 2–4 | 15–24 | |
| Dodge heavy | Spinning Backfist | 27–36 | 450–600 | 3–5 | 24–36 | |
| Backstep light | Snap Kick | 18–24 | 300–400 | 3–5 | 18–27 | |
| Backstep heavy | Lunging Palm | 33–42 | 550–700 | 3–6 | 24–36 | |
| Jump light | Air Kick | 12–18 | 200–300 | 3–5 | to landing, then 9–15 | |
| Jump heavy | Axe Kick | 18–27 | 300–450 | 4–6 | to landing, then 15–21 | |
| Block ability | none: a disarmed fighter can't block; the redirect is a protected timing | | | | | |
| Unblockable | none | | | | | |
| Ultimate | Breaker Palm (from the choice) | 30–42 | 500–700 | 3–5 | 30–42 | |
| Ultimate | The recall (weapon back and the burst, from the choice) | 16–24 | 267–400 | the burst's frame | to 26–36 in all | |
| Counter Lunge | Counter Lunge | milestone 2 | | | | |

### The distance band table (P27, confirmed Oct 4)

They start from today's duelling distances (confirmed in the code on Oct 4: the Katana duels at 2.5 m and its computer prefers to fight from 2.1 m, the weapon's `reach`; bare hands at 1.6 m and 1.2 m) and today's table of test distances by kind. All distances are centre to centre, with each move played from standing. "Touches from" is the longest distance a move must still touch the defender from; a move is also checked at its weapon's duelling distance and at the computer's preferred distance where those are closer, and closer distances still aren't checked, as today. The string's lights must put 15–20 cm of blade (or of fist, past the surface) into the defender at their weapon's duelling distance, and still touch from the computer's preferred distance. "Misses from" is new: a move must touch nothing from there or farther, so that reach doesn't creep as clips get longer steps.

| Kind | Katana: touches from | Katana: misses from | Bare hands: touches from | Bare hands: misses from |
|---|---|---|---|---|
| String lights | 2.5 m (15–20 cm of blade in), and from 2.1 m | 3.25 m | 1.6 m (15–20 cm past the surface), and from 1.2 m | 2.1 m |
| Heavies (string heavy, Iai follow-ups) | 3.0 m | 3.75 m | 2.1 m | 2.6 m |
| Iai Slashes | 3.6 m | 4.2 m | — | — |
| Sprint light | 4.0 m | 4.75 m | 3.1 m | 3.6 m |
| Sprint heavy | 5.0 m | 5.75 m | 4.1 m | 4.6 m |
| Dodge attacks | 2.5 m | 3.25 m | 1.6 m | 2.1 m |
| Backstep light | 3.0 m | 3.75 m | 2.1 m | 2.6 m |
| Backstep heavy | 4.5 m | 5.25 m | 3.6 m | 4.1 m |
| Jump attacks | 2.0 m | 2.75 m | 1.1 m | 1.6 m |
| Unblockables | 3.5 m | 4.25 m | — | — |
| Ultimate | Moonsplitter: the whole stage (its wave runs 33 m) | — | Breaker Palm: 4.1 m | 4.6 m |
| Counter Lunge | milestone 2 (4.5 m today) | | milestone 2 | |

Every bare-hands move also keeps today's check that it misses from 6 m.

### The protected-timing table (the retune, P28, confirmed Oct 4, then frozen)

Today's values are the build's (Oct 4). The retune happens once, in the pipeline phase, from the band floors; the pilot's play session ends it and may adjust it; then every value below is frozen, and no later family's session changes one without the owner's OK. The rows after design's list (the stuns, the stagger and daze, the parry recoil, the finisher prompt, the disarmed choice and the parry-spam shrink) are protected timings by P50, or rules numbers frozen with them. These are the Katana's and bare hands' values; the Greatsword and the Daggers keep today's until milestone 2 (P48). The rule for every hitstun: at the band floors, the defender in a light string is free 1–2 frames before the next hit can land at the earliest (the next light at its band floor, taken at a branch point 1 frame after the last active frame, and playing its first frame the step after its branch point, so it lands its startup plus 2 frames after the hit: the hitstuns below are those of the retune, task 22, a frame longer than this table first counted, as the owner decided on Oct 5); every other follow-up pair leaves the defender free at least 1 frame before, and the table check holds every pair to that. Blockstun keeps today's ratio to recovery (recovery band floors are about 1.5× today's). Stuns keep the punish they buy today.

| Timing | Today | Retuned (P28) | Rule |
|---|---|---|---|
| Parry window, Katana | 9 | 9 (kept) | design keeps it |
| Flash's window | 18 | 18 (kept) | a parry-type window |
| Redirect window | 8 | 8 (kept) | design keeps it |
| Input buffer | 8 | 8 (kept) | design keeps it |
| Roll | 16 (12 invincible) + 9 over 2.8 m | kept | design keeps the dodge |
| Backstep | 14 (10 invincible) + 9 over 2.1 m | kept | design keeps the backstep |
| Hitstun, Katana light | 14 | 24 (corrected Oct 5 from 23) | 24 (light floor) + 2 − 2: the follow-up plays its first frame the step after its branch point |
| Hitstun, bare-hands light | 14 (Jab and Cross 16) | 18 (corrected Oct 5 from 17), Jab and Cross included | 18 (light floor) + 2 − 2; Jab and Cross stop being guaranteed |
| Hitstun, heavy | 26 | Katana 41, bare hands 35 (corrected Oct 5 from 40 for both) | a heavy's branch points sit at least 18 frames after its active frames end, so a light follow-up lands no sooner than 43 frames after the hit (18 + 24 + 1) for the Katana and 37 (18 + 18 + 1) for bare hands; 2 free frames each |
| Hitstun, ability | 24 | 36 | × 1.5 (no milestone-1 ability uses it: the unblockables knock down, Flash strikes nothing) |
| Hitstun, ultimate | 40 (Moonsplitter 50, Breaker Palm 36) | 60 (Moonsplitter 75, Breaker Palm 54) | × 1.5 |
| Hitstun, Counter Lunges | 14 | 24 (Katana), 18 (bare hands), corrected Oct 5 from 23 and 17 | the weapon's light hitstun; the moves wait for milestone 2 **(P48, confirmed Oct 4)** |
| Full-charge bonus | +12 hitstun, +8 blockstun, +4 hit-stop | +18, +12, +4 | × 1.5; hit-stop kept |
| Blockstun light / heavy / ability | 10 / 16 / 14 | 15 / 24 / 21 | × 1.5, the recovery floors' ratio |
| Hit-stop light / heavy / ability | 4 / 7 / 6 | 5 / 9 / 8 | heavier impacts at the slower pace |
| Hit-stop, ultimate (Moonsplitter's waves, Breaker Palm) | 12 | 14 | + 2, as the outcome hit-stops |
| Hit-stop on a block | the move's − 2, at least 3 | kept as a rule | |
| Hit-stop on a parry / Flash and redirect / disarm / stomp / leap | 8 / 10 / 14 / 10 / 6 | 10 / 12 / 16 / 12 / 8 | + 2 each (the evade's 5 waits for milestone 2) |
| Parry recoil (guard after) / parrier recovery | 26 (14) / 7 | kept | the parrier still acts first by 19 frames, less than a light's 24, so the parried fighter can still parry the answer |
| Stomp stun | 70 | 90 | three Katana lights still land |
| Flash stun | 60 | 66 | two Katana lights still land |
| Redirect stun | 50 | 56 | two bare-hand lights still land |
| Disarm stagger / disarmed daze | 26 / 60 | 36 / 66 | × 1.4 and × 1.1, set in the retune and frozen with the rest; the disarm family re-keys its clips to fit |
| Parry-spam shrink | a press within 30 frames of the last shrinks the window by 3, down to 2 frames | kept | design keeps the parry window |
| Knockdown fall / down / rise (guard window) | 20 / 30 / 25 (15) | 30 / 30 / 40 (20) | the fall × 1.5 and a slower, weightier rise; the knockdown family re-keys the clips to fit (Knockdown01 at 1.0× falls in about 56 frames and rises in about 58); invulnerable until the guard window opens, as today, so to rise frame 20 (corrected Oct 5 from "still to rise frame 10") |
| Finisher prompt | none | 18 rules frames at 0.3× (about 1 s) | design's "about a second of slow motion" **(P35, confirmed Oct 4)** |
| Disarmed ultimate's choice | 40 frames at 0.35× | kept | a rules number frozen with the rest |

### The momentum and gait table

| Item | Today | Milestone 1 |
|---|---|---|
| Guarded start and stop | acceleration 38 m/s² (a full run in about 0.1 s), deceleration 30 m/s² | within about 6 frames (0.1 s), from the start and stop clips (the owner's) |
| Run stop | about 8 frames and 0.25 m at 30 m/s² | 12–15 frames (0.2–0.25 s), up to about 0.5 m (the owner's) |
| Plant-and-reverse pivot | steering at 14 rad/s | 12–15 frames, up to about 0.5 m (the owner's) |
| Sprint stop | about 15 frames | about 20 frames and 1 m (the owner's) |
| Tap step | 0.55 m in 8 frames, instant start | unchanged |
| Walk | no walk speed in the rules (a partial tilt of the run) | the walk clip's measured speed (the packs measure about 2.2 m/s) |
| Run forward / sideways / back | 3.9 / 3.5 / 3.0 m/s | each clip's measured speed (the packs' runs measure 4.1–4.6 forward) |
| Sprint | 7.2 m/s | the sprint clip's measured speed (the packs: 5.3–6.3) |
| Blocking | 0.6 × the run | the guarded strafe and shuffle clips' own speeds, chosen or keyed to about 55–65% of the run **(P29, confirmed Oct 4)** |
| Disarmed speed | × 1.2 | the disarmed gait clips' own speeds, chosen or keyed to about 1.2 × the armed run **(P29, confirmed Oct 4)** |
| Disarmed dodge | × 1.5 distance | a longer disarmed roll clip in the same protected frames **(P15, confirmed Oct 4)** |
| Disarmed jump | × 1.35 | unchanged: jump arcs stay rules numbers |
| Speed kept into an attack | 0.5 | none; the leftover shows only in the blend **(P14, confirmed Oct 4)** |
| Turning to face the opponent | 14 rad/s | unchanged; the turn shows through the blend and the pivot clips **(P29, confirmed Oct 4)** |

### The balance-run targets

| Measure | Target | Notes |
|---|---|---|
| Matches | mirror matches, the Hunter with the Katana on both sides, random difficulties, random block abilities | the owner's; the random abilities are **P49, confirmed Oct 4** |
| Failures | none (no errors, stalls, NaN, a fighter outside the arena, posture out of range) | the owner's |
| Round length | 60–90 s | the owner's; the soak's target changes from 35–60 s **(P24, confirmed Oct 4)** |
| Disarms per round | 0.3–0.6 | the owner's; every recorded run since 11.1 is above 1.0 |
| Finishers | in some rounds; the share is set after the first run | the owner's |
| Must appear at least once | the stomp, the leap, Flash, both ultimates (Moonsplitter and Breaker Palm; the recall is reported too) and a pick-up | the owner's list; which "both ultimates" are is **P37, confirmed Oct 4**; the random block abilities let the stomp (against Piercing Thrust) and the leap (against Swallow Sweep) both appear |
| Per-weapon win rates | off until milestone 2 | the owner's |
| Run size | 300 matches to tune, 40 to check clean | as today |

### The computer's finisher rates table (P55, confirmed Oct 4)

When a finisher prompt opens for the computer, it presses heavy on a share of prompts set by its difficulty, at a frame drawn from its own seeded generator inside the window; otherwise it lets the prompt pass and the disarm plays out. Tuning may change these numbers like any other computer number.

| Difficulty | Prompts pressed | When |
|---|---|---|
| Easy | 30% | a random frame in the window's second half |
| Normal | 60% | a random frame anywhere in the window |
| Hard | 90% | within the window's first 6 frames |

### The performance gates

| Gate | Target | Measured how |
|---|---|---|
| Definition of "holds 60 fps" | 99% of frames take 16.7 ms or less | a scripted worst-case replay from a recorded input log, about 90 s: both ultimates, a finisher, blood and petals, the fighters at the wall; shaders warmed up first **(P19, confirmed Oct 4)** |
| Ultra | 4K output, rendered at about 1440p–1800p and upscaled with FSR 2.2, on the RTX 3090 | on the clear night (the owner's) |
| Low | 1080p output, rendered at about 720p and upscaled, on the Ryzen 7 4700U laptop | on the clear night; FSR 2.2 if it fits the frame budget at its first bench, otherwise FSR 1 **(P30, confirmed Oct 4)** |
| Training and Watch | the Duel's gate | **(P19, confirmed Oct 4)** |
| Versus split screen | 60 fps at High on the RTX 3090, same definition | **(P19, confirmed Oct 4)**; no laptop target in milestone 1 |
| The look test scene | Ultra's gate with headroom: 99% of frames at 14 ms or less (Godot check 5) | measured when the owner approves the scene |

### The size budget table (P23, confirmed Oct 4)

| Place | Budget |
|---|---|
| Public repository | no tracked file over 10 MB (today's guard); committed game art (CC0 and self-made models and materials, including the exports copied from the asset repository, and labelled stand-ins) under 150 MB in all, replacing the 110 MB cap; committed audio under 40 MB (today's test) |
| Asset repository (Git LFS) | under 8 GiB in all, inside GitHub Free's 10 GiB; per fighter under 400 MB of sources and 120 MB exported; per weapon under 60 MB of sources and 20 MB exported; per exported clip under 5 MB; the arena under 1.5 GB of sources and 600 MB exported; textures at 4K only for fighters, weapons and hero props, 2K elsewhere |
| Shipped game | milestone 1's build under 2 GB zipped and 3 GB installed |

### The Godot check table (written criteria, P31, confirmed Oct 4)

Judged at the pilot family (the animation criteria) and at the look test scene (the look and performance criteria), and confirmed at sign-off. Godot stays unless a criterion clearly fails and no fix inside Godot is in sight; then the owner decides.

| # | Criterion | Judged at |
|---|---|---|
| 1 | The pilot family passes the per-move checklist in the running game, its effects in the look test's approved look included: inertial blending, foot locking under 1 cm and the hands on the grips, with no engine patch | the pilot |
| 2 | The custom skeleton modifiers (inertial blending, the physical reaction layer, foot locking, the hands' grip) run in the rig's order every frame for both fighters with the rules unaffected | the pilot |
| 3 | A clip goes from Blender to the game by the scripted export and import with no hand step, and comes out the same on two runs | the pilot |
| 4 | The look test scene, beside the approved mood board, reaches its materials, volumetric fog, lighting and grade in the owner's judgement | the look test |
| 5 | The look test scene holds Ultra's gate on the RTX 3090 with FSR 2.2, with headroom left (99% of frames at 14 ms or less) for the second fighter and the effects | the look test |
| 6 | The features the milestone needs work on Windows under Forward+: volumetric fog, decals, GPU particles, temporal anti-aliasing, FSR 2.2, spring bones, skeleton modifiers | the look test |
| 7 | No shader stutter after the warm-up pass, and no crash over a 40-match soak with the look loaded | sign-off |
| 8 | All of the above still hold on the finished build | sign-off |

### The per-move checklist (P32, confirmed Oct 4)

A move must pass every item that applies before the milestone ends. Built from `docs/design.md`'s quality bar and the grilling's work order.

| # | Item | Applies to | How it's checked |
|---|---|---|---|
| 1 | Keyed into its timing band; frame data generated from the clip, no hand overrides | attacks | the band test (CI) |
| 2 | Connects from its distance band and misses beyond it | attacks | the distance-band test (CI) |
| 3 | Fits its protected frames at its own speed | the roll, backstep, reactions, stuns, staggers, the daze, knockdown | the state-clip fit test (CI) |
| 4 | Plays at its own speed: never sped up, slowed, frozen or stretched on its own, apart from the whole-world time effects (hit-stop, the KO's and the finisher's slow motion, the disarmed choice), which slow every clip alike; holds are loops | every clip | the director test (CI) |
| 5 | No slide beyond its own steps; travel baked from the hips and foot plants; a clip that sets a rules length (the draw, the pull-out, the finishers, the paired counters, the round-end beats, the victory poses) has its length and markers recorded in the table | every clip | the table and the rules tests (CI) |
| 6 | The attack type reads early in the wind-up | attacks | the side-by-side video and the owner |
| 7 | The weight visibly shifts | every clip | the owner |
| 8 | Planted feet slide no more than 1 cm | every clip | a foot-slide measure added to PoseCheck, run on every rules frame of the clip, skipping none (the sheets show only the chosen frames) |
| 9 | The blade never passes through the body | every clip with a weapon | PoseCheck's blade clearance, run on every rules frame of the clip, skipping none |
| 10 | The hands stay on the grips; Katana cuts two-handed except the one-handed moments listed in story 53 **(P54, confirmed Oct 4)** | every clip with a weapon | the weapon-in-hand test (local) and the sheets |
| 11 | Hands off cleanly: branch points and cancel markers set, inertial blending in and out, follow-ups starting on the side the last swing ended | every clip | the string-continuity test and the owner |
| 12 | Its deflect pair (attacks), its block reaction, and the defender's directional hit reactions | attacks | the director test and the sheets |
| 13 | Its sound: swing, impact by weapon pair, flesh and bone layers, the parry ring, placeholder effort vocals | every clip with an event | the sound-bank test and the listening pass |
| 14 | Its effects at the contact point (sparks, blood, dust, air smears; the 危 and glint for unblockables) | every clip with an event | the effects parity check and the sheets |
| 15 | The computer can use it and answer it | attacks | seeded rules tests |
| 16 | Re-bakes from its clip with no drift | attacks | the local re-bake test |
| 17 | The owner's review: sheets, a side-by-side video against For Honor, Ghost of Tsushima and Tekken 8 or Mortal Kombat 1, and a play session with the licensed clips | its family | the owner |

### Move families and their order (P33, confirmed Oct 4)

Each family goes to final quality, with every checklist item, and the owner reviews each, in this order. Since Oct 6 (the owner's word) the order is the order of the reviews, not a gate: a task waits only on the tasks whose results it uses, so families run side by side. The pilot comes first and its review freezes the protected timings, so the other families' clip work waits on it; the Godot check holds the art conversion; the closing checks wait on round flow's review. Systems with no clip of their own (rules, the camera, the computer, Training) and the draw at the round intro were released on Oct 5 (see the plan's Notes). "Reached in a milestone-1 match" assumes the Hunter-against-Hunter Katana mirror, with bare hands when disarmed; a block ability is reached when the loadout picks it.

| Order | Family | Moves and clips | Reached in a milestone-1 match |
|---|---|---|---|
| 1 | **The pilot: the Katana's light string** | Right Cut, Return Cut, Kesa Cut, Crown Cut; their deflect pairs; light hit and block reactions; the Katana's guard idle and the bridges between the hits | yes, all |
| 2 | Guard movement and dodges | walk, run, strafe and sprint sets; guarded strafe and shuffle; starts, stops and pivots; the tap step; the roll and the backstep; the jump and the landing | yes, all |
| 3 | The Katana's heavies and the Iai | Iai Slash (vertical, horizontal), the stance loop, Rising Heaven, Returning Draw, Heaven Splitter; heavy reactions and their deflect pairs; the knockdown on a power attack | yes, all |
| 4 | Reactions, knockdown and KO | directional hit reactions (every direction, height and weight), the physical layer, the knockdown's fall, down and rise, stuns and staggers, deaths | yes, all |
| 5 | The Katana's movement attacks | Running Draw, Leaping Cleave, Wind Cut, Whirl Cut, Rising Cut, Lunging Cut, Aerial Cut, Falling Crown | yes, all |
| 6 | Block abilities and counters | Flash; Piercing Thrust with the stomp's paired clip; Swallow Sweep with the leap's paired clip; the 危 and glint | yes, when the loadout picks them (two of three) |
| 7 | The disarm and bare hands' core | the disarm's flight and stuck weapon, the pull-out pick-up, the disarmed gaits and longer roll; Jab, Cross, Hook, Roundhouse, Spinning Heel; the redirect's deflect pair; a blade parrying a fist or foot | yes, all |
| 8 | Bare hands' movement attacks | Flying Knee, Dragon Kick, Slip Jab, Spinning Backfist, Snap Kick, Lunging Palm, Air Kick, Axe Kick | yes, when disarmed |
| 9 | The ultimates | Moonsplitter (vertical, horizontal) and its shot; the disarmed choice; the recall's power-up; Breaker Palm and its shot | yes, all |
| 10 | The finishers | the Katana's finisher and bare hands' finisher (paired clips with their shots), the slow motion and the prompt | yes, both |
| 11 | Round flow | the draw at the round intro, the round-end beat (sheathe, or shake out the hands), the match-winning KO shot, the victory poses (the Katana's sheathe and bow, bare hands' cheer) | yes, all |

Every Katana move, by family: light string (family 1): Right Cut, Return Cut, Kesa Cut, Crown Cut; heavies (3): Iai Slash vertical, Iai Slash horizontal, Rising Heaven, Returning Draw, Heaven Splitter; movement attacks (5): Running Draw, Leaping Cleave, Wind Cut, Whirl Cut, Rising Cut, Lunging Cut, Aerial Cut, Falling Crown; block abilities (6): Flash, Piercing Thrust, Swallow Sweep; ultimate (9): Moonsplitter; waiting for milestone 2: Counter Lunge. That is 21 moves plus Moonsplitter, of which 20 and Moonsplitter are re-keyed.

Every bare-hands move, by family: light string and heavies (7): Jab, Cross, Hook, Roundhouse, Spinning Heel; movement attacks (8): Flying Knee, Dragon Kick, Slip Jab, Spinning Backfist, Snap Kick, Lunging Palm, Air Kick, Axe Kick; ultimate (9): Breaker Palm; waiting for milestone 2: Counter Lunge. That is 15 moves, of which 14 are re-keyed.

Waiting for milestone 2, because only the Greatsword's slams trigger the evade counter: the evade's paired clip, the Katana's Counter Lunge and bare hands' Counter Lunge. A dodge through an attack on the roll's invincible frames still happens in milestone 1 and plays the re-keyed roll.

## Testing Decisions

A good test here checks behaviour at a public seam: build the rules or the data, feed inputs, and assert on outputs, events and states. It never reaches into private fields or pins how a module works inside. Clip-dependent checks must run from the committed table and the committed CC0 stand-ins, or be local-only (`test_local_` names that skip themselves without the clips), or CI goes red again on clones without the asset repository.

The seams, highest first, preferring the ones that exist:

1. **The match seam** (exists: the match host stepped with `step()` and fed by the brains or recorded inputs). The replay test, the save-and-restore test, the soak, the balance run and the worst-case performance replay all run here. Prior art: `test_match_host.gd::test_the_host_plays_exactly_the_soak_loop`, `test_smoke_run.gd`, `test_soak.gd`.
2. **The rules seam** (exists: a world with two fighters fed scripted inputs through the sim helpers; events, HP, posture and states out). New rules are tested here: the finisher (opens only at 5% HP or less on a disarm, an early press doesn't count, nor a buffered one, a miss plays the disarm out, the victim can't act, the round ends as a KO; a disarmed fighter's blocked Breaker Palm or fully charged Roundhouse at that HP opens bare hands' finisher from its strike), the deterministic stuck weapon (lands along the knock or deflect direction, inside the walls, at the same place every run), the pull-out's length, attacks starting from the table's frames and branch points, dodge cancels at markers, gait speeds and momentum travel matching the table, no attack keeping run speed, a jump attack refused once it can't fit the airtime left and a landing that skips no frames, the frozen protected timings in play (a defender can block or parry the next hit of every light string). Prior art: `test_fluid_combat.gd`, `test_combat.gd`, `test_knockdown.gd`, `test_katana_strings.gd` and `weapon_strings_test.gd`, `test_recall_burst.gd`, `test_regressions.gd`.
3. **The data seam** (exists in shape: a table plus "every move passes"). The committed frame-data table and the band tables, read as data: every move and every rules-length clip (the draw, the pull-out, the finishers, the paired counters, the round-end beats, the victory poses, the state clips) has an entry and a recorded source clip; each entry's digest matches its committed row and swing file; every Katana and bare-hands attack is inside its timing band; every one connects from its distance band and misses beyond it, through the swing reach check; the free-frame rule and the earliest branch points hold over every follow-up pair; the protected timings equal their frozen values; every state clip fits its protected frames. Prior art: `test_duel_reach.gd`, `test_move_reach.gd` and its reach table, `test_string_continuity.gd`.
4. **The generator seam** (exists: the bake as a pure function). A committed CC0 clip and its markers in, frame data, travel and swing samples out; deterministic; refuses a missing marker; travel isn't counted twice. The local-only re-bake test lives here. Prior art: `test_swing_bake.gd` (`test_the_bake_is_deterministic`, `test_local_every_swing_file_matches_a_fresh_bake`), `test_import_clips.gd`, `test_clip_manifest.gd`.
5. **The director seam** (exists: rules state in, a shot of clips, times and blend requests out). Every clip at 1.0× of the world's time scale (hit-stop and slow motion slow every clip alike, and nothing else changes a clip's speed); inertial blend requests on every hand-off, hitstun included; directional reactions; deflect pairs by direction; paired clips; the round-end beat against the match-winning victory; the round-end beat and the victory pose after a Katana finisher both skipping their sheathe; every move resolving to a clip. Prior art: `test_clip_director.gd`, `test_state_clips.gd` (its frozen golden re-recorded once), `test_foot_lock.gd`, `test_weapon_in_hand.gd`.

The one new seam is the rules' snapshot, restore and state hash, with the input log. It sits as high as it can (the whole world, driven through the match host), and it serves the replay test, the save-and-restore test and the performance replay at once.

Other modules with tests, each at its existing seam: the roster filter and the defaults (`test_match_selection.gd`, `test_fighter_select.gd`, `test_how_to_play.gd`); the soak's mirror mode, its random block abilities and its targets (`test_soak.gd`); the slimmed Studio at its save seam (markers in; the regenerated table and the out-of-band report out; no speed or holds in a saved chain; prior art `test_source_edit.gd`, `test_studio_smoke.gd`); the shot director at the director seam (rules events in, the chosen shot out: the ultimates' shots only once they connect, a round-ending finisher's shot, a match-winning finisher's shot replacing the KO shot, the recall's push-in only; prior art `test_clip_director.gd`); the presets as data (four files, Ultra the reference, a graphics card's name mapping to a preset; prior art `test_graphics_presets.gd`, rewritten); counterlab's stomp and leap; Training's routes and refill (`test_training_brain.gd`, `test_training_upkeep.gd`); the brain's use of the table, the finisher prompt and the stuck weapon (seeded rules tests); settings (`test_game_settings.gd`, `test_settings_screen.gd`); the HUD's states and calls (`test_hud_state.gd`, `test_hud_announcements.gd`); the camera's push-in (`test_camera_rig.gd`); every event's sound (`test_sound_bank.gd::test_every_event_type_has_an_entry`) and the music's tempos and loops (`test_music_director.gd`, the Node audio tests); the effects parity check, built like the sound bank's; the grey-palette test (prior art `test_palettes.gd::test_palettes_differ_over_a_large_area_from_every_side`); the size budgets (prior art the Node size check and `test_asset_budget.gd`).

Tests replaced as milestone 1 lands: `test_moves.gd`'s parity with the TypeScript; the pinned frames in `test_katana_strings.gd`, `test_greatsword_strings.gd` and `test_daggers_strings.gd` (they become reads of the generated table; the Greatsword's and the Daggers' get no band test, and their string and counterlab tests stay and must pass behind the dev flag); `test_fluid_combat.gd`'s momentum-keep and 60% blocking-walk tests (they become clip-speed tests); `test_look.gd`, `test_ink_wash.gd`, `test_graphics_presets.gd` and the toon assertion in `test_weapons.gd`; the 110 MB cap in `test_asset_budget.gd`; `test_ui_theme.gd`'s ink palette; and, with the procedural poses, `test_stick_pose.gd`, `test_swing_player.gd` and the procedural-pose tests in `test_fighter_view.gd`.

Not in CI, owner-run or by eye: contact sheets and side-by-side videos per family (`move_sheet.gd`, `move_video.gd`, `review_video.gd`), the shot scenes (every screen's again after the UI redesign; the whole-flow walks themselves run wherever godot-rebuild task 22.17 puts them), the look test, the performance gates, the listening passes, the play sessions and the age-rating questionnaire.

## Out of Scope

- **Milestone 2:** the Greatsword, the Twin Daggers and the Rogue at final quality and back in the menus; new fighter models on the UE5-style skeleton (twist, prop, IK and face bones) and where the final models come from; cloth simulation and facial expressions; the evade's paired clip and both Counter Lunges, with the Greatsword's slams; the Impaler's paired clip and the Impaler's and Tempest's effects; the Greatsword's and the Daggers' victories, draws and finishers; band tests for both; per-weapon win rates (godot-rebuild 12.6, 12.7 and the 45–55% check of 12.9); the colossal hits' dust, cracks and bone-and-rock sounds; the backstab's flashes.
- **After milestone 1's sign-off (no milestone named):** the weather system and its other four states; the black-and-white mode (only its grey-palette test is in milestone 1); a bought vocals pack; footsteps on wood and water; the menus' new layouts.
- **Breadth:** match intros and gate walk-outs, the fighter intros' shots and the character select's gate cinematic; per-fighter bare-hand movesets; the six other weapons, the six other fighters and their finishers; the other arenas and a stage select; progression and cosmetics; licensed or recorded music.
- **Online play:** rollback netcode and everything around it. Milestone 1 only adds the replay and save-and-restore tests and the input log.
- **Not planned:** Mac and Linux builds; a lock-on toggle or free camera; ring-outs.

## Further Notes

- **What "final quality" leaves out in milestone 1**, so sign-off isn't judged on them: placeholder effort vocals, the code-generated score, neutral faces and no cloth simulation (the wind's cloth is only the scarf's spring bones and the banners), the shared bare-hands moveset, only the clear night, stone-only footsteps, and both Counter Lunges and the evade's paired clip on today's clips.
- **Risks.**
  - *Finishers may be rare*: 100 HP, a 5% HP threshold (5 HP) and a full posture meter, with a disarm doing no damage. The balance run sets the share after its first pass; if finishers are near zero, tuning raises posture pressure, not the threshold **(P47, confirmed Oct 4)**.
  - *Keying about 100 clips takes long.* The pilot family measures the cost per family before the rest are committed to.
  - *The skeleton changes in milestone 2.* Milestone 1's clips are keyed on today's 65-bone skeleton; the UE5-style skeleton keeps today's bone names, so the clips should carry over by name, but twist and prop bones will need a pass.
  - *Cascadeur Indie* allows commercial use only under $100,000 a year of revenue or funding; above that the licence must be upgraded before release.
  - *The Katana's Blender model* sets the blade length. It keeps today's 0.72 m blade within 2 cm so the distance bands hold; a different length shifts the band table once, with the owner's OK **(P44, confirmed Oct 4)**.
  - *Godot may not reach the bar.* The check's criteria are in the Godot check table, and the engine is reconsidered only if they clearly fail.
- **Git LFS spending.** The asset repository's 2 GB fits GitHub Free's 10 GiB of storage, so no LFS storage is bought unless the size budget is exceeded; the 10 GiB a month of downloads allows a few full clones a month.
- **The grilling's record.** The owner's 27 answers are in the stories and decisions above, the defaults it proposed are P1–P25, and the facts it found are under "Facts found while preparing this spec" below; the separate inputs file was folded in here on Oct 4 and deleted. Two options the owner passed over are recorded here: free-licence music tracks (the code-generated score is extended instead) and recording their own voice for the effort vocals (placeholders until a pack is bought). In the owner's words on consolidating first: "I want to consolidate before starting on the new design and development path. The html can be retired and the rebuild should be the master branch."
- **`brain/project/Key decisions.md`** is stale against Oct 4 (sound, the roster, the blocking walk, finishers, weather, blood, Warrior Slain); the plan updates it with the first task that touches each.

### Facts found while preparing this spec (Oct 4)

Checked against the build at `f6acc21`. The numbers the tables above already hold (today's protected timings, movement and the soak's targets) aren't repeated.

- **The roster in code.** Bare hands can't be picked as a loadout: `PLAYABLE_WEAPONS` is the Katana, the Greatsword and the Daggers. Each side already wears its own palette, but the Hunter's two are "Umber and tobacco" and "Ash and rust", so both are re-dyed.
- **The clips today.** At their own speed the string's four lights land in 233–367 ms (Kesa Cut 233, Right Cut 267, Return Cut 300, Crown Cut 367), against the light band's 400–500 ms. The string plays them 1.3–1.8× fast, every Katana light 1.15–1.8×, and the whole move table 1.0–2.0×. Knockdown01's fall would need about 2.8× and its stand-up about 2.3× to fit today's 20 and 25 frames; both are clamped at 2.0×, so each phase ends before its clip does. The manifest names 94 Iglesias clips, the keyed library 3 (Mikiri_Stomp, Mikiri_Pinned, Power_Up, made from key-pose JSON) and the CC0 library about 64 stand-ins; about 100 clips need keying or re-keying.
- **Round flow today.** The round intro lasts 100 frames with "Fight!" at frame 62; the round end lasts 170 frames, the winner's victory pose starting at frame 70; a KO gives 50 frames of slow motion at 0.3×; Moonsplitter winds up for 36 frames.
- **Damage today.** Max HP is 100. Katana lights deal 6–8 HP (Right Cut, Return Cut, Wind Cut, Rising Cut and Aerial Cut 6, Kesa Cut 7, Crown Cut and Running Draw 8), its heavies 12–15; a full charge multiplies by 1.8 and a backstab by 1.6; a disarm deals no HP damage.
- **The laptop today.** At 1080p on the Ryzen 7 4700U, the toon Low preset ran at 99.9–102 fps and High at 66.8–69.
- **Sizes.** The packs' folder (`Desktop/Monomachia-assets`) is about 1.9 GB: Kevin Iglesias 1.1 GB, Quaternius 0.8 GB, effects 37 MB. The five Sonniss GDC 2026 zips are 6.5 GB.
- **Sound today.** The Sonniss bundle holds only a few male effort vocals (a warrior's "Ai yah", a yell, male panting) and no pain or death cries. The code-generated music has three 16-bar loops at 110, 140 and 160 BPM, and its instruments already include taiko, ka, gong, shamisen, koto and metal power chords. Footsteps have one cue, stone, and no surface types.
- **Godot.** Godot 4.5 and later have a stencil buffer, so the black-and-white mode's colour mask is feasible (a stencil read forces a pass into the transparent queue). Godot has no skinned-cloth solver, and the build uses no spring bones, soft bodies or physical bones yet.
- **The Shrine today.** No banners or grass. Its props are lanterns, torii with shimenawa ropes and paper streamers, pillars, pines, dead trees, pagodas and a temple hall, with parapet posts, pebbles and debris on the platform and a sea of clouds, mountains, cliffs with waterfalls, a lake and mist in the backdrop. Its wind is a fixed vector that moves the embers and the ash and sets the clouds' drift.
- **The weapon in the hands.** In free movement the weapon is posed in space by the swing file's guard or by `StickPose`'s hands, with the arms reaching it on IK; it rides the clip's hands only while an attack or state clip drives and the clip libraries are present, so on every CI run attacks pose it too. Nothing imports a clip edited in Blender or Cascadeur: the import reads only the packs' FBX paths.

### Where milestone 1 sits

The roadmap (`docs/plans/roadmap.md`) runs in six phases:

1. **Consolidation.** The finished lanes are already merged into `feature/godot-rebuild` (PRs #21, #25 and #19, Oct 4). Stage 14 of `docs/plans/godot-rebuild.md` retires the web version, CI goes green on clones without the Kevin Iglesias clips, and task 26.4 merges the rebuild into `master`.
2. **Milestone 1** (this spec). It branches from `master` once 26.4 has merged.
3. **The master follow-ups**, alongside milestone 1: the look-independent godot-rebuild tasks the triage kept (18.11, 22.7, 22.16, 22.17, 23.4–23.7, 24.3–24.5 and their parents), finished on `master` in today's theme. Milestone 1 restyles what they build.
4. **Milestone 2:** the Greatsword, the Twin Daggers and the second fighter at final quality, with new fighter models, cloth and faces.
5. **Breadth:** the remaining weapons, fighters and arenas, per-fighter bare hands, match intros and gate walk-outs, progression.
6. **Online play**, last, on the replay and save-and-restore tests this milestone adds.

### Work carried over from the older plans

The Oct 4 triage moved these tasks to milestone 1. Each now lives in milestone 1's plan, whose tasks name them in their `Replaces:` lines.

| Older task | What it was | How milestone 1 delivers it | Stories |
|---|---|---|---|
| godot-rebuild 12.2 | The computer times its defence from the swing's first touch | The same behaviour, run after the frame-data change, reading the generated table | 187, 188 |
| godot-rebuild 12.3 | The dummy performs every unblockable | One routes table; the Katana's two unblockables and both Iai variants; the Greatsword's drills wait for milestone 2 | 189, 196, 6 |
| godot-rebuild 12.4 | Counterlab covers every unblockable | The stomp and the leap reached; the evade waits for milestone 2 | 190 |
| godot-rebuild 12.5 | The computer uses and answers the Iai | As written, landing the Iai from its distance band instead of a fixed 3.2 m | 191 |
| godot-rebuild 12.8 | Tuning round 1: round length and disarms | Milestone 1's tuning as each family lands: rounds 60–90 s, 0.3–0.6 disarms, finishers, only damage, posture, parry and computer numbers | 197, 198, 199, 200 |
| godot-rebuild 12 and 12.9 (the milestone-1 part) | The computer opponent and the balance pass; per-weapon win rates | The Katana and bare hands rebalanced around their clips; the balance run of mirror matches; teaching the computer finishers; the owner's Duel playtest becomes the sign-off. The 45–55% check waits for milestone 2 | 50, 123, 192, 193, 197, 213 |
| godot-rebuild 18.4 | Sparks and ink splashes | Realistic sparks at the contact point, blood in place of the ink splash, the Blood setting, a bare hand's own impact; the weapon-bounce sparks retire | 156, 157, 158, 161 |
| godot-rebuild 18.5 | Parry ring, sparks and the push-in | Deflect-pair contact sparks and clang; the ring retires; a parry, a Flash and a redirect read apart; the push-in, frozen in hit-stop and off under Reduce flashes | 106, 108, 109 |
| godot-rebuild 18.6 | Warning mark and reach arc for unblockables | The red 危, its sound and the blade's glint; labels and the floor marker only in Training; the gold ultimate mark retires | 111, 112, 196 |
| godot-rebuild 18.7 | Ultimate-ready aura | Embers and heat haze in the side's colour, only while ready and not knocked out | 163 |
| godot-rebuild 18.8 | Ultimate effects | Moonsplitter's wave with its shot; the disarmed choice, Breaker Palm and the recall's burst restyled | 164, 165, 133 |
| godot-rebuild 18.9 | Counter, disarm, KO and status flashes; movement dust | The disarm's effect on the weapon's flight, the counters' effects on their paired clips, the KO into Warrior Slain, real dust at the clips' feet; the status flashes retire | 160, 167 |
| godot-rebuild 18.10 | Dropped-weapon beam, ground marker and model | The stuck weapon in the realistic look with a faint glint; the beam and ring retire; removed on pull-out, recall and round start | 66, 166, 180 |
| godot-rebuild 18.12 | Effects parity check, re-shoot and re-benchmark | The parity check over every event, the effects shot series at Ultra and Low, and the two performance gates | 168, 201, 202, 203 |
| authored-animation 32 | The draw at the round intro | The Hunter draws the Katana from a Blender-modelled saya at the left hip, at final quality and its own speed; bare hands' combat entry is dropped | 126, 127, 146 |
| authored-animation 33 | The victory poses | The Katana's sheathe and bow and bare hands' cheer, only for the match-winning KO, skipping the sheathe after a Katana finisher; the round-end beat for other KOs | 129, 130, 131 |
| authored-animation 35 | Retire the procedural animation | The procedural poses retire for every weapon; a director test that every move resolves to a clip; the re-bake test becomes the table's checks | 102, 215, 216, 20, 21 |

#### The Animation Studio, slimmed

`docs/plans/animation-studio.md` is not followed as its own plan; milestone 1's slimming tasks absorb it (Stories 27–32).

| Studio task | Verdict | What milestone 1 keeps |
|---|---|---|
| 1–6 (the shell, source edits, state clips on data, the catalogue, the tile, the gallery) | done, kept | the gallery; its open gate (the owner's look at the gallery shots) folds into the owner's try of the slimmed Studio |
| 7 The timeline | kept | where markers are set, over source frames |
| 8 Rules frames, bands, markers and layers | kept, slimmed | the generated frame data against the timing band, the markers, and only the layers that survive (foot lock, inertial blending, the reaction layer) |
| 9 Overlays and the rules preview | folded into 8 | only the distance band's hit-or-miss check |
| 10 The edit session | kept | undo and redo for marker and chain edits |
| 11 Marker editing | kept and extended | active frames, cancel windows, branch points, foot plants |
| 12 The chain panel | kept, slimmed | parts and ranges; the speed field and holds go |
| 15 Save, bake and the balance flag | kept, slimmed | save writes markers and chains, regenerates the table and reports out-of-band moves; "set frame data to match" goes |
| 22 The owner's review | kept, re-scoped | the owner tries the slimmed Studio on the pilot family |
| 13 The frame-data panel | dropped | frame data are generated, never edited |
| 14 The state timings panel | dropped | protected timings stay rules numbers |
| 16 The refinement launcher, 17 the chat panel | dropped | not in the slimmed Studio |
| 18 Correctives, 19 bone posing, 20 IK handles, 21 keyed-clip editing | dropped | bone posing moves to Blender |

### Where this differs from `docs/design.md`

- **The unblockable's reach.** The older "(update)" line says unblockables have "a visible effect showing their reach". This spec reads that effect as the blade's red glint: in matches the reach shows only through the 危, its sound and the glint (P6).
- **Cinematic shots.** design.md gives every ultimate a shot once it connects and says a KO that ends a round plays on the gameplay camera; this spec gives the recall a push-in instead of a shot (P37), and a finisher that ends a round plays its own shot through Warrior Slain (P38). After a Katana finisher, neither the round-end beat nor the victory pose sheathes again (P4).
- **Protected timings.** design.md's free-frame rule ("a frame or two before each next hit of a string") is applied as 1–2 frames in light strings at the band floors, and at least 1 frame for every other follow-up, which a check over the table enforces (P28). The list grows: the counters' stuns, the disarm's stagger and daze, and the parry recoil join it (P50).
- **Movement.** design.md's faster blocking walk and the disarmed agility become clip speeds rather than multipliers (P29).
- **Blade length.** design.md lets the Blender models set the blade lengths and retunes reach to match; milestone 1 instead keeps the Katana's blade at 0.72 m within 2 cm so the distance bands hold, and a different length needs the owner's OK (P44).
- **The finisher prompt.** "About a second of slow motion" is set as 18 rules frames at 0.3× (P35).
- **Bare hands' finisher.** design.md describes it as turning the attack aside, then a crushing strike. When a disarmed fighter disarms by a blocked Breaker Palm or a fully charged Roundhouse, there is no attack to turn aside, so the same finisher plays from its strike (P52).
- **Low's upscaler** is named (P30); design.md only says "upscaling".
- **Spending.** design.md budgets Git LFS storage; the asset repository fits GitHub Free, so none is bought unless the size budget is exceeded.

The first five (the unblockable's reach, the cinematic shots, the protected timings, movement and the blade length) were written into design.md on `docs/milestone-1-spec` on Oct 4, when the owner approved this spec, before its pull request merged; the rest are details below design.md's level. The one wind moving only the scarf and the banners as cloth (P46) and stone-only footsteps (P21) are milestone-1 scope, listed under "What final quality leaves out", not changes to the design.

### Where this differs from ADR 0001

- **Hidden content keeps rules movement.** The ADR says no fighter slides further than its clips step. In milestone 1 the hidden Greatsword and Daggers keep their rules lunges, the colossal slide and the shoulder carry, with frame data generated from their current clips at 1.0× and no band test, until milestone 2 re-keys them (P10, P45). Both Counter Lunges stay on today's clips the same way (P48). No milestone-1 match reaches any of them.

### Where this differs from `docs/mvp-spec.md`

Nothing changes there: it is the record of the web demo, and task 25.6 marks it so. For the record, milestone 1 departs from it in the pace (Katana lights 400–500 ms), finishers and blood, the disarmed weapon sticking in the ground instead of landing marked on screen, Warrior Slain, the unblockable's type no longer shown over the attacker in matches, and rounds of 60–90 s.

### Where this differs from `docs/specs/godot-rebuild.md`

- Frame data come from the clips (as ADR 0001 already notes), and the soak's targets become rounds of 60–90 s with mirror matches and win rates off.
- Light hitstun 14 becomes 23 (Katana) and 17 (bare hands); bare hands' Jab and Cross lose their guaranteed 16 frames (P28). The Greatsword's and the Daggers' stay as they are until milestone 2 (P48). The momentum carry (half the speed into an attack) retires (P14), and the 60% blocking walk becomes a clip speed (P29).
- Three presets become four, with Ultra the reference; the laptop gates give way to the two new gates.
- A jump attack starts only while it fits the airtime left, and landing no longer skips an air attack's frames forward to its active part (P53).
- The triaged stories this spec delivers for the Katana and bare hands: 13, 16, 18, 19, 21, 22, 24, 26–30, 40, 42, 43, 48 (apart from the dropped-weapon marker's function, which stays with godot-rebuild 24.5, and is restyled here) and 49. It also delivers story 17 (optional follow-ups) and story 47 (the floating landscape, as real 3D), which the triage list left out. Story 20 (colossal momentum) and stories 31–39 wait for milestone 2, and so does story 44 (choosing the Rogue), since the roster is hidden.
- It also changes stories 7, 11, 50, 51 and 57 (the HUD's redesign, the camera's framing and push-ins, sounds by weapon pair, the score's new instruments, and four presets with the Blood setting); whatever of them the master follow-ups still build on `master` is restyled or extended here.

### Where this differs from `docs/specs/authored-animation.md`

- The timing fit (1.0–2.0×), the reach push and the rules-authored lunges retire, as ADR 0001 says; frame data are generated, not "written by hand from the bake's report".
- Crossfades and the hitstun cut give way to inertial blending; the parry rebound (the attacker's clip run backwards) gives way to deflect pairs.
- The knockdown's provisional 20, 30 and 25 frames become 30, 30 and 40, with a 20-frame guard window (P28).
- The roll keeps its frames, but its clip is re-keyed to play at its own speed, and its travel curve is regenerated from it.
- The recall burst's knock-back becomes clip travel (P43).
- Bare hands' combat entry is dropped (it would never play), and the victory poses play only for the match-winning KO.
- The Greatsword's and the Daggers' victories (its task 34) wait for milestone 2.

### Glossary changes

Added to `GLOSSARY.md` on `docs/milestone-1-spec`, with this spec: **Move family** (with the pilot family), **Move kind**, **Mood board**, **Look test**, **Marker**, **Branch point**, **Inertial blending**, **Transition clip**, **Physical reaction layer**, **Cinematic shot** (with the push-in), **Blood setting**, **Balance run**, **Stand-in**, **Procedural pose** and **Warrior Slain**. The **Animation Studio** entry is rewritten for the slimmed tool; the **Protected timing** entry gains the stuns, the stagger and daze, and the parry recoil (P50); the **Recall** entry's _Avoid_ now describes the pick-up as pulling the weapon out of the ground. **Corrective** and **Refinement** describe parts of the Studio that milestone 1 drops; they are removed from the glossary when the slimming lands.

## Defaults the owner confirmed (Oct 4)

P1–P25 are the grilling's "Defaults to propose", adopted as written, except that P4 is widened to the round-end beat. P26–P56 are this spec's own proposals for the questions the grilling left open (P48–P56 came out of the spec's review). The owner went through all of them on Oct 4 (in four rounds of questions, the player-facing ones one by one and the technical ones as a batch) and confirmed every one as written. Each lists the stories that depend on it.

| # | Proposal | Stories |
|---|---|---|
| P1 | Bare hands stay the disarmed state, not a loadout: no bare-hands draw, and the cheer plays when a disarmed fighter wins the match | 8, 126, 130 |
| P2 | Clip work starts at once; only the art conversion (materials, models, the arena, how effects look, the UI style) waits for the mood board and the look test | 139, 51 |
| P3 | Training plays the finisher, then refills HP; the computer lands finishers more often on higher difficulties | 123, 124 |
| P4 | After a Katana finisher, which already re-sheathes, neither the round-end beat nor the victory pose plays its own sheathe; the winner holds the finisher's end pose through Warrior Slain | 129, 131 |
| P5 | The Blood setting ships in milestone 1 and defaults to On | 161, 122, 162 |
| P6 | In matches an unblockable's reach shows only through the red 危, its sound and the blade's glint; labels and floor markers only in Training | 112, 196 |
| P7 | The dropped-weapon beam retires and the stuck weapon gets a faint glint; the HUD's off-screen marker stays, restyled; Reduce flashes stays and covers the new effects | 166, 180, 185 |
| P8 | Every parry, Flash and redirect gets a short camera push-in, which Reduce flashes turns off | 109 |
| P9 | Deflect pairs follow the attack directions; when a blade parries a fist or a foot, the attacker recoils without being cut | 105, 75 |
| P10 | The Greatsword's and the Daggers' frame data come from their current clips through the same generator, with no band test until milestone 2 | 22 |
| P11 | Inertial blending and the physical reaction layer are custom skeleton modifiers that only change the picture | 96, 94, 98 |
| P12 | Markers set in the slimmed Animation Studio give active frames, cancels and branch points; CI checks the committed frame-data table and its bands; a local-only test re-bakes every move and fails on any drift | 21, 28, 20 |
| P13 | Each attack's travel is baked per frame from the hips and foot plants, and swings are sampled relative to the moving body | 19 |
| P14 | An attack started out of a run keeps none of the run's speed in the rules; the leftover shows only in the blend | 90, 89 |
| P15 | A longer disarmed roll clip covers the disarmed dodge's 1.5× distance inside the same protected frames | 71 |
| P16 | The disarmed weapon's flight is deterministic, along the knock or deflect direction and inside the walls, its landing angle rules state; the pull-out pick-up takes as long as its clip | 67, 68, 25 |
| P17 | The computer reads the generated frame-data table; godot-rebuild 12.2–12.5 run after the frame-data change | 187, 188, 191 |
| P18 | Replay test: a seeded match run twice gives matching state hashes; save-and-restore test: save mid-match, restore, step again and compare; both cover the finisher and the stuck weapon | 23, 24, 25 |
| P19 | "Holds 60 fps" means 99% of frames at 16.7 ms or less in a scripted worst-case replay (both ultimates, a finisher, blood and petals, at the wall), shaders warmed up first; Training and Watch meet the Duel's gate; Versus split screen gets 60 fps at High on the RTX 3090 | 201, 202, 203, 195 |
| P20 | The ultimates' energy (element and colour) and the gameplay camera's framing are settled on the mood board and in the look test scene | 137, 134, 164 |
| P21 | The upgraded Shrine gains banners, and grass in the broken paving; footsteps are stone only | 152, 153, 169 |
| P22 | Moves come to the owner family by family, each with sheets, a side-by-side video and a play session; reference-game footage stays on the owner's machine | 209, 210 |
| P23 | Size budgets per place (public repository, per asset, shipped game), the numbers in the size budget table; the self-made and CC0 model and material exports that fit the public budget are also committed publicly | 205, 15 |
| P24 | The soak's round-length target changes from 35–60 s to 60–90 s | 199, 197 |
| P25 | The laptop stays available for benchmarking the Low preset | 204 |
| P26 | The timing band table above, with one band per move wherever it is played from (Rising Heaven in the Iai follow-up band) | 33, 34, 52, 58, 60, 62, 72, 73 |
| P27 | The distance band table above, with its new "misses from" column and its definition of touching from a band (Oct 6: re-measured under ADR 0002) | 38, 57, 191 |
| P28 | The protected-timing retune and its rules (light hitstun 23 for the Katana and 17 for bare hands, heavy 40, and the rest in the table; corrected Oct 5 with the owner to 24, 18 and 41, bare hands' heavy 35, counted as the rules step), done once in the pipeline phase and ended by the pilot's play session, then frozen, with no later family's session changing one without the owner's OK; the free-frame rule checked over the table (1–2 frames in light strings at the band floors, at least 1 frame for every follow-up pair), with the earliest branch points (1 frame after a light's active frames, 18 after a heavy's) | 40, 41, 44, 99 |
| P29 | The blocking walk and the disarmed speed become their gait clips' own speeds, chosen or keyed to about 55–65% and 1.2× of the run; the Iai stance's strafe moves at its clip's measured speed and the draw's drift comes from its clip; the turn rate stays 14 rad/s | 84, 70, 81, 54 |
| P30 | Low upscales with FSR 2.2 if it fits at its first bench, otherwise FSR 1; the worst-case replay lasts about 90 s | 184, 201 |
| P31 | The Godot check's written criteria in the Godot check table | 212 |
| P32 | The per-move checklist above, and which items apply to clips that aren't attacks | 208 |
| P33 | The move families and their order above | 51, 209 |
| P34 | Milestone 1 retires the procedural poses and rides the weapon on the clips' hands in every state, using the clips' prop bones where a clip has one; the labelled stand-ins stay | 102, 215 |
| P35 | The finisher prompt lasts 18 rules frames played at 0.3× (about 1 s), counted in rules frames; only a fresh heavy press inside it counts | 114, 115, 116 |
| P36 | A bare-hand hit shows a dust-and-cloth impact and the physical layer's push, not a blood burst; blood comes from blades | 158 |
| P37 | The recall gets a push-in, not a cinematic shot; the balance run's "both ultimates" are Moonsplitter and Breaker Palm, with the recall reported too | 133, 197 |
| P38 | A finisher that ends a round plays its own shot through Warrior Slain; a match-winning finisher's shot replaces the authored KO shot, then the victory pose | 121, 128, 130 |
| P39 | A plain parry, a Flash and a redirect read apart by their deflect pairs and sounds first: a parry throws sparks; a Flash a brighter burst with a longer ring-out; a redirect no sparks, a hand-on-arm impact | 108 |
| P40 | The gold 奥義 ULTIMATE mark retires in matches (the roar, the push-in and the aura read the ultimate), and the evade, stagger, counter-ready and pick-up flashes retire in favour of the clips and Training's toasts | 133, 167 |
| P41 | The round intro and round end take their lengths from their clips: "Fight!" when both draws reach their ready marker; the round end lasts the slow motion, the call and the beat, or the KO shot and the victory pose | 127, 129, 130 |
| P42 | The arena reactions shown in milestone 1: cut marks and scorch where blades strike stone (the sweeps, the plunging and leaping cuts, Moonsplitter's wave cracking the floor along its path), dust from falls and rolls, sparks off pillars, banners and grass pushed | 155 |
| P43 | The recall burst's knock-back and Breaker Palm's lunge become clip travel; Moonsplitter's wave stays a scripted rules hit | 100, 77, 78, 164 |
| P44 | The Katana's Blender model keeps today's 0.72 m blade within 2 cm, so the distance bands hold; another length shifts the band table once, with the owner's OK (Oct 6: superseded by ADR 0002, the blade becomes 1.3 m) | 146, 38 |
| P45 | The hidden Greatsword and Daggers lose the procedural poses too (riding their current clips' hands) but keep their rules lunges, the colossal slide and the shoulder carry until milestone 2 | 4, 22, 215 |
| P46 | Milestone 1's "cloth" is the scarf's spring bones and the banners; no cloth simulation | 144, 153 |
| P47 | If the first balance run shows almost no finishers, tuning raises posture pressure rather than the 5% threshold | 197, 198 |
| P48 | Content waiting for milestone 2: the Greatsword and the Daggers keep today's protected timings (the Daggers' 10 frames of string hitstun included, so their later hits stay free) until milestone 2 re-keys and retunes them; both Counter Lunges play today's clips at 1.0× with generated frame data and no band test, and take their weapon's retuned light hitstun (23, 17; 24, 18 since the Oct 5 correction), which closes the question of 18 or 14 frames | 4, 22, 40, 65, 80 |
| P49 | The soak and the balance run pick each fighter's two Katana block abilities at random (seeded) from Flash, Piercing Thrust and Swallow Sweep; the menus' default stays Flash and Piercing Thrust | 5, 197, 199 |
| P50 | The stuns the counters buy (the stomp, Flash, the redirect), the disarm's stagger and the disarmed daze, and the parry recoil with the parrier's recovery join the protected timings | 39, 99 |
| P51 | The look test scene is built alongside the pilot's keying, showing the pilot's moves, so the pilot's effects take the approved look before its review; if the look test runs late, the owner decides at a review of the pilot's motion whether family 2 starts before the pilot's effects are final | 51, 139, 212 |
| P52 | When a disarmed fighter disarms by a blocked Breaker Palm or a fully charged Roundhouse at 5% HP or less, bare hands' finisher opens and plays from its strike, skipping the turn-aside | 120 |
| P53 | A jump attack starts only while its startup and active frames fit the airtime left; landing no longer skips an air attack's frames; Falling Crown's band is 18–22 frames with 4–6 active so it fits | 93, 60, 73 |
| P54 | The Katana's off hand leaves the grip only in the listed one-handed moments (story 53) | 53 |
| P55 | The computer presses the finisher prompt on 30% of prompts on Easy, 60% on Normal and 90% on Hard | 123 |
| P56 | The sign-off build, through Steam's IARC questionnaire, rates no higher than PEGI 18 and ESRB Mature 17+; the owner answers it at sign-off | 162 |
