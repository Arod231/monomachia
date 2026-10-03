# Spec: Authored animation and the dodge roll

Oct 3, 2026 · status: spec approved by the owner (Oct 3); plan approved (`docs/plans/authored-animation.md`, Oct 3); tasks 1–21 done (the Katana's review, task 14, `docs/reviews/katana-animation-review.md`, taken as passed when the owner set the next tasks going on Oct 3; its lunge and PoseCheck questions are still open); the Greatsword's review (task 20, `docs/reviews/greatsword-animation-review.md`) passed on Oct 3, its balance left to a tuning change after the Daggers · branch `feature/authored-animation`, off `feature/godot-rebuild` (at 8cb57c3, after PR #10; PR #11 merged in at task 1)

The Godot rebuild's fighters move with procedural animation. Attacks follow hand-keyed weapon paths with arm IK and a torso and hip turn; reactions are a recoil and a lean; movement is hip-turned clips, a lean and a guard shuffle. This feature replaces all of it with authored clips: Kevin Iglesias's Human Melee and Human Basic Motions packs, retargeted onto the Quaternius fighters, with the Quaternius Universal Animation Library 2 as a supplement and as the fallback. It also turns the dodge from a dash into a roll, adds a knockdown rule, and gives the Greatsword a shoulder carry. The rules stay in charge: they decide every hit and every frame at 60 steps a second, and the clips are fitted to them.

This reverses two decisions of `docs/specs/godot-rebuild.md` ("How attacks are animated" and "Movement animation"), retires the swing editor and the hand-keyed swings, and changes `docs/design.md` in four places. Every difference is listed under Further Notes.

## Problem Statement

The duel plays well, but the fighters don't move like people:

- Attacks look stiff. A hand-keyed path drags the weapon and the arms chase it with IK, so swings read as procedural, as the animation spike's critique warned ("the swings read as procedural"). No real swing has been keyed yet, so every move still hits with the demo's cone, and keying 70 moves by hand in an editor that doesn't exist yet would take a long time and still not look human.
- Defenders are statues. Hits, blocks and parries show as a lean or a pushed-out guard, and a knock-out is the only clip a fighter reacts with.
- Movement is approximate. Strafing and backpedalling twist the hips of a forward run clip, the backwards cycle looks "moonwalky", and the guard shuffle is procedural.
- The dodge is a dash with a crouch and a lean, which doesn't read as evasive.
- The fighters have no draw, sheathe or victory pose.

## Solution

Fighters animate from authored clips:

- **Attacks**: Kevin Iglesias's one-handed, two-handed, dual-wield and unarmed attacks, plus UAL2's sword chains and aerials, re-timed to each move. The path that decides hits is baked from the same clip, so what you see is what hits.
- **Reactions**: Iglesias damage, stun, parry, knockdown and death clips, played on the rules' clock.
- **Movement**: Iglesias walk, run, strafe and sprint sets in every direction, turns, combat idles per weapon class, draws and sheathes.
- **Dodge roll**: a directional dodge is a roll in any direction, with the same distance, frames and invulnerability as today's dash. The no-direction backstep stays a backstep.
- **Knockdown**: unblockables, fully charged heavies and the Greatsword's slams knock the defender down. They are invulnerable while down and stand up on a fixed timer.
- **Greatsword**: rests on the shoulder at the intro and while moving, and lifting it to attack costs 6 frames.
- **Intro and victory**: each weapon is drawn at the round intro, and each has a victory pose.

The raw Iglesias files and the clips converted from them stay out of the public repo: an import tool builds them locally from the owner's packs, and the exported game carries them. A fresh clone without the packs falls back to the committed CC0 clips and says so.

## User Stories

### Attacking

1. As a player, I want every attack to be an authored, human-looking motion with a wind-up, a strike and a follow-through, so that attacks feel fluid and weighty instead of stiff.
2. As a player, I want the weapon on screen to be exactly where the hit is decided, so that a swing hits when it visibly connects and misses when it visibly misses.
3. As a player, I want each attack's wind-up, contact and recovery to line up with when it can hit, be blocked or be cancelled, so that I can read timings from the animation.
4. As a player, I want string follow-ups to flow from the previous swing's end without a pop, so that strings look like one continuous motion.
5. As a player, I want to see attack types (slash, overhead, thrust, sweep) apart in the first third of the wind-up, so that I can pick the right defence.
6. As a player, I want a dodge-cancel to break out of my swing into a roll at once, so that the cancel feels responsive.
7. As a player, I want an attack that is hit to stop at once and turn into the hit reaction, so that interrupts read clearly.
8. As a Katana player, I want the Iai Slash to sheathe the blade into its saya and draw it in one authored motion, so that the quick-draw looks real.
9. [x] As a Greatsword player, I want my fighter to carry the sword on the shoulder while moving and visibly heave it into a swing, so that the weight shows.
10. [x] As a Greatsword player, I want attacks started from the shoulder to take longer, so that the carry is a real trade-off and not just a look.
11. As a Daggers player, I want my fighter to idle with the daggers in a reverse grip and flip them forward to attack, so that the Rogue's style survives the clips.
12. As a bare-hands fighter, I want real punches and kicks, so that disarmed play looks like fighting, not flailing.
13. As a player, I want the ultimates, block abilities, counters (stomp, leap, evade), Flash, Shadow Step and the jump attacks to have authored motion too, so that nothing looks procedural next to the rest.

### Defending and reactions

14. As a player, I want my fighter to flinch with an authored damage clip from the direction of the hit, so that taking a hit reads.
15. As a player, I want blocks to show my guard taking the impact, so that blocking feels solid.
16. As a player, I want a parry to show my fighter's parry motion and the attacker's weapon rebounding back along its own swing into a stagger, so that parries feel cinematic, as in Sekiro.
17. As a player, I want long stuns (stomp, leap, disarm, redirect) to show a dazed stun clip, so that I can see I'm open.
18. As a player hit by an unblockable, a fully charged heavy or a slam, I want to be knocked down, so that the biggest hits feel big.
19. As a knocked-down player, I want to be invulnerable while down and to stand up on a fixed timer, so that a knockdown can't be abused into an endless loop. *(Delivered by task 16.)*
20. As a knocked-down player, I want to be able to block or parry during the last part of my stand-up, so that the attacker can't time a guaranteed hit on my wake-up. *(Delivered by task 16.)*
21. As a player, I want a knock-out to play a death clip chosen by the direction and strength of the final blow, slowed by the final-blow slow motion, so that rounds end dramatically.

### Movement and dodge

22. As a player, I want my fighter to walk, run and strafe with real directional clips in every direction, so that circling the opponent looks natural.
23. As a player, I want to sprint with real sprint clips, and turn in place with real turn clips, so that movement is grounded.
24. As a player, I want my feet to stay planted and never slide, so that the fighter looks connected to the floor.
25. As a player, I want a directional dodge to be a roll in that direction, so that dodges look evasive.
26. As a player, I want the roll to keep today's distance, timing and invulnerability, so that what I learned about dodging still applies.
27. As a player, I want the roll's travel to follow the roll itself, fast while tumbling and easing on the recovery, so that the body and the ground match.
28. As a player, I want a dodge attack out of a roll to come up facing the opponent, so that dodge attacks still land.
29. As a player, I want the no-direction backstep to stay a quick hop back, so that backstep attacks and the evade counter keep their feel.
30. As a player, I want a distinct roll sound, so that I can hear a dodge.

### Round flow

31. As a player, I want my fighter to draw their weapon at the round intro (the Katana from its saya at the hip, the Daggers from leather sheaths at the small of the back, the Greatsword lifted to the shoulder), so that each round starts with a moment.
32. As a winning Katana player, I want my fighter to sheathe the blade and bow, so that the win is honourable.
33. As a winning Daggers player, I want my fighter to toss a dagger, flip it in the air and catch it, so that the win shows off.
34. As a winning Greatsword player, I want my fighter to plant the sword in the ground and rest both hands on the pommel, so that the win looks heavy.
35. As a winning bare-hands player, I want my fighter to cheer, so that the win has energy.

### Fighters

36. As a player, I want the Rogue to move with the female clip set and the Hunter with the male clip set, so that each fighter's body language suits them.
37. As a player in a mirror match, I want both fighters to hit identically whichever body they wear, so that fighters stay cosmetic.

### Licence and fresh clones

38. As the owner, I want the raw Iglesias files and the clips converted from them never committed to the public repo, so that I keep within their licence.
39. As the owner, I want one command that converts only the clips the game uses from my local packs, so that the game can be rebuilt on any of my checkouts.
40. As a contributor without the Iglesias packs, I want the game to run with the committed CC0 clips and tell me the packs are missing, so that I can still play and test.
41. As the owner, I want the exported Windows build to include the converted clips, so that players see the real animation.
42. As the owner, I want a drafted email asking Kevin Iglesias to confirm what may be published, so that the open question is settled in writing.

### Building, tuning and review

43. As the developer, I want the rules to stay free of graphics and never read a clip at runtime, so that they stay testable headless and ready for online play.
44. As the developer, I want each move's frame data retuned to its clip within set bounds and checked by soak runs, so that animation work doesn't wreck balance unseen.
45. As the developer, I want a catalogue sheet of every candidate clip on our fighters, so that I choose clips by eye, not by file name.
46. As the developer, I want a per-move contact sheet and a before/after side-by-side video for each weapon, so that I can judge the result.
47. As the owner, I want to OK each weapon before work on the next starts, so that problems surface early.
48. As the developer, I want a retargeting prototype on five clips before the rest of the work, with a stated fallback if it fails, so that the riskiest step is proven first.
49. As the developer, I want the tests to run on CI without the Iglesias packs, so that CI keeps checking every commit.

## Implementation Decisions

### Decisions in plain English

| Decision | What we chose | Why | What it costs |
|---|---|---|---|
| How attacks are animated | Authored clips: Iglesias first, UAL2 Source as a supplement, re-timed to the move. Reverses the godot-rebuild row "How attacks are animated" | Procedural swings read as procedural; the clips look human | Moves are limited to what the packs have; several moves share or mirror a clip |
| What decides a hit | Still the weapon's path, now baked from the clip: the import tool samples the posed grip and blade every rules frame and writes the swing file the rules already read | What you see is what hits, and the rules stay free of graphics | A re-bake after every clip or timing change; licence question on the baked numbers (below) |
| Movement animation | Iglesias directional walk, run, strafe, sprint and turn sets in a blend space, combat idles per weapon class, foot locking. All procedural movement is retired. Reverses the godot-rebuild row "Movement animation" | Real directional clips exist now | The guard shuffle, hip-turn and lean go |
| Root motion | Clips play in place. The roll's root curve (from Roll01 [RM]) is baked into rules data as the dodge's travel curve | The rules own every position | Only the roll has a baked curve; other clips must not move their root |
| Timing fit | Moves are retuned to their clips: each clip plays at 1.0–2.0× its 30 fps speed, chosen per move, and its markers set the startup, active and recovery frames, as close to today's as the clip allows | Clips look wrong when squashed piecewise | Every weapon is rebalanced; soak runs gate each weapon |
| Clip sets | HumanF for the Rogue, HumanM for the Hunter; the hit paths are baked once, from HumanM on the Hunter, and shared | Body language suits each body; fighters stay cosmetic | Two retargets to review; the Rogue's hands are corrected onto the shared path with IK |
| Dodge | A roll in any direction; same 2.8 m, 16 frames, 12 i-frames, 9 recovery; travel follows the roll's baked curve. The backstep stays a backstep (Dodge01) | Dodges look evasive without a balance change | `docs/design.md` changes ("a dash, not a roll") |
| Knockdown | A new rule: unblockables, fully charged heavies and the Greatsword's slams knock down on a hit. Invulnerable while down, fixed stand-up | The biggest hits feel big; uses the packs' knockdown clips | New rules state, tests, soak |
| Greatsword shoulder carry | Shouldered after 20 frames of moving; any attack from the shoulder adds 6 startup frames | The weight shows in play, not only in looks | Greatsword nerf; soak checks it |
| Parry and block | Parry: the parrier's Parry Hit clip; the attacker's own clip plays backwards from the contact frame into a stagger. Block: Parry Loop held, Parry Hit per blockstun | Cinematic, as the design asks | Reversed clips need a check that they look right |
| Intro and victory | Draw at the intro; victory: Katana sheathes and bows, Daggers toss and catch, Greatsword planted, fists cheer | Each weapon gets a moment | Two hand-keyed clips (Daggers toss, Greatsword plant); new sheath meshes |
| Licence | Raw packs and converted clips never committed. A local import tool builds them into a gitignored folder; exports include them. Baked hit paths and the clip manifest are committed. Kevin is asked to confirm | The EULA forbids assets "accessible or extractable for reuse" outside a product | Contributors need their own packs for the real look |
| Fresh clone | The committed CC0 Quaternius clips stand in for every Iglesias clip, with a "packs missing" note | Tests and CI run without the packs | The fallback looks rough |
| Swing editor and hand keys | Retired, with blade lag and the procedural parry bounce. The swing player and stick poses are removed once every move has a clip | Clips replace the keyed path | Work on 14b and 7.16–7.38 is dropped |

### Source assets and the import tool

- The raw packs are never copied into the repo. An untracked `.assets-src-path` file at the repo root holds the folder they are unzipped in (on the owner's PC, `Desktop/Monomachia-assets`, which already holds all four Iglesias packs, UAL1, and UAL2 Standard and Source); without it the tools look in a gitignored `assets_src/` folder at the repo root. This mirrors `.godot-path`. Both names are added to `.gitignore`, and the existing Quaternius import tool, which has the folder hard-coded, reads the same setting.
- PR #11 (merged into `feature/godot-rebuild` on Oct 3) committed the UAL2 Source, UAL2 root-motion and female-mannequin files whole, with the CREDITS note listing the Iglesias packs as "not in the repo", and raised the art budget to 110 MB. So the UAL2 Source clips the clip table names are folded into the committed CC0 clip library from the GLB already in the repo (plan task 3), and the `assets/ual2-source-and-iglesias-refs` worktree is retired.
- A new import tool converts only the clips the **clip manifest** names. For each one it:
  - reads the Iglesias FBX (binary FBX 7.7, 30 fps, one clip per file, on Kevin's 56-bone `B-` rig) through Godot's FBX importer;
  - retargets it through a new bone map for Kevin's rig onto Godot's humanoid profile, the same way `ual_bone_map.tres` retargets the UAL clips (the bone map is ours and committed);
  - strips the root track, scale tracks and the `B-handProp` and jaw bones;
  - scales the hips' travel from their rest by the target fighter's leg-to-hips ratio over the source rig's (about ×1.14), because our fighters' legs are longer than Kevin's for their hips height, and Godot alone scales the travel by hips height (found in the retargeting prototype, `docs/research/retarget-prototype.md`);
  - writes one animation library per clip set (HumanM, HumanF) into a gitignored folder inside the Godot project, so the exported game packs it.
- The **clip manifest** is committed. It names, for every clip the game uses: the source pack, file and set; whether it is mirrored; its loop mode; and its markers in source frames (wind-up start, contact start, contact end, settle). It holds no animation data.
- Everything the tool writes is deterministic, so two builds from the same packs give identical files, and the bake (below) can be checked by tests.

### Clips and the rules

- **The rules never read a clip.** The only clip-derived data the rules see are numbers committed in their own data: the baked swing files, the dodge's travel curve and the retuned frame data.
- **Baked swings.** For each move the bake poses the Hunter's skeleton with the move's HumanM clip at the move's speed, frame by frame on the rules' clock, applies the reach correction, and records each striking part's grip, blade and edge (the hand, both hands for the Daggers, a foot for a kick) and the body's coil in the fighter's own space, one key per rules frame, into `game/sim/moves/swings/<weapon>.json`. The rules read it as they read the hand-keyed format today: same parts, same per-tick samples, same blade sweep against the hurt capsule, same outcome order. The swing file format gains a flag marking a track as baked (one key per frame, no splining), and the reader refuses a baked track with a missing frame. Which clip (or chain) and speed each move bakes from is in a committed move-clip table beside the clip manifest (`move_clips.json`), with each weapon's guard read from its idle clip (task 6).
- **Weapon in hand.** The weapon is fixed to the main hand at a per-weapon grip offset, measured on the fighter's hand, rather than posed in space with the arms reaching for it. A two-handed weapon (Katana, Greatsword) puts the off hand on its off-hand grip with IK on top of the clip. This replaces the godot-rebuild decision "A weapon is never fixed to a hand".
- **Reach correction.** A clip's arm may stop short of the reach rule (the last 15–20 cm of blade entering a defender at the weapon's duelling distance). The bake then pushes the striking grips toward the reach, easing in over the wind-up and out over the recovery, at most 15 cm. The presentation plays the same correction from the same data by moving the body above the hips (an arm at full stretch can't reach further on IK; task 9), so the visible blade and the baked path agree. A move that needs more than 15 cm gets a different clip or a lunge in the rules. Task 10 lengthened three: Return Cut's lunge 0.35 → 0.45 m, Kesa Cut's 0.35 → 0.4 m (ending on frame 14), Crown Cut's 0.5 → 0.7 m (ending on frame 15). Task 11 the heavies, whose clips reach 1.4–1.9 m where their cones reached 2.3–3.6: the Iai Slashes 0.4 → 2.1 m (still hitting at 3.8 m and missing at 4.2), Rising Heaven 0.5 → 1.2, Returning Draw 0.5 → 1.1, Heaven Splitter 0.7 → 0.95. Task 12 the movement attacks: Running Draw 1.6 → 1.7, Leaping Cleave 2.6 → 2.9, Wind Cut 0.4 → 0.5, Whirl Cut 0.3 → 0.5, Rising Cut 0.8 → 1.25, Lunging Cut 2.2 → 2.3. Task 13 the unblockables (their 10 cm thicker sweep counted): Piercing Thrust 1.0 → 1.4, Swallow Sweep 0.4 → 1.4. Task 18 the Greatsword's, whose blade reaches 2.1–2.4 m on its clips: Heavy Swing 0.4 → 0.45 (ending on frame 16), Backswing 0.4 → 0.55, Overhead Strike 0.7 → 1.05 (for 3.5 m; its clip, Attack2H02, also sets its recovery at 29 frames, from 32), Piercing Lunge 0.8 → 1.0 (so it still reaches from where a sideways dodge out of the string leaves the fighters, 3.45 m). Task 19 the Greatsword's movement attacks and Guard Crusher: Shoulder Charge 2.2 → 3.35 (its shoulder reaches 0.65 m and its test distance is 4.5 m, past what even its cone reached, 4.1), Leaping Smash 3.0 → 3.15, Rising Edge 0.9 → 1.15, Lunge Cleave 2.2 → 2.35, Guard Crusher 1.6 → 1.85. Task 20 the Greatsword's unblockables (4.0 m): Reaping Sweep 0.3 → 1.65, Mountain Slam 0.6 → 1.35, and Low Sweep 0.8 → 0.85 (for 3.5 m). Task 21 the other way for the Daggers' lights, whose clips put the whole dagger into a defender at their 2.0 m: Quick Slice 0.3 → 0.15, Off-hand Slice 0.3 → 0.17, Twin Rip 0.4 → 0.38, Flurry Finisher 0.6 → 0.35, each now ending on its first touch (Quick Slice and Off-hand Slice retimed so it falls on their first active frame, keeping the defender's free step between them); Spinning Backhand 0.4 → 1.1.
- **A weapon's reach for the computer opponent** (task 20). Under hand-keyed swings a weapon's reach (where the computer opponent spaces and attacks from) came from its light starter's swing (godot-rebuild 7.13). A swing baked from a clip leaves the authored reach instead: a clip's arm reaches less far standing and its lunge was lengthened to keep the reach table's distances, so the weapon still fights from where it did. Spaced from Heavy Swing's path standing (2.42 m against 2.75), the Greatsword lost 7 points.
- **Bashes strike with a shoulder** (task 19). Shoulder Charge and Guard Crusher bake a left-shoulder track (`Swing`'s `left_shoulder`: the joint, out along the shoulder line, its edge forward) instead of the hand's; it strikes with a segment 12 cm long and 24 cm thick at the joint, the same on any weapon (`SimConst.SHOULDER_STRIKE_*`), and the weapon rides the clip's hands on both fighters.
- **Shared paths, two bodies.** Paths are baked once, from HumanM on the Hunter. The Rogue plays HumanF clips, and hand IK pulls her grip onto the shared path. A move whose HumanF clip is more than 5 cm off the path at any active frame is flagged by the bake, and the Rogue plays the HumanM clip for that move instead. The 5 cm is measured on her own body, HumanF against HumanM at the same frames (task 7): her smaller body holds any clip 7–12 cm off the Hunter's path, which her hand IK closes, so the absolute gap would flag every move.
- **The swing rules still apply.** The reach and whiff distances and the test-distance table run on the baked paths. The reference-body checks (wrist limits, elbows not locked at contact, blade 5 cm clear of the body) don't (task 9): a baked weapon was read from the clip's own hand, so an arm holds it by construction, and the reference body, which only turns and shifts its torso, can't stand in for a clip's leaning body (on Right Cut it reported a 136° wrist on the Hunter's own clip). The Rogue's hold is checked by the bake's 5 cm drift. The continuity rule (a follow-up's first key within 2 cm and 10° of the previous hand-off) is dropped, because a crossfade carries one clip into the next; the sides (`side_start` and `side_end`) stay as move data and the side continuity test stays.
- **Retuned frame data.** For each move the bake's chosen speed (1.0–2.0× the clip's 30 fps) turns the clip's markers into rules frames: startup runs to contact start, active from contact start to contact end, and recovery to the settle marker. The speed is picked per move to land as close as possible to today's startup, the main balance lever. The new numbers are written into each weapon's move data by hand from the bake's report, with the deliberate-differences tables in the move tests updated. Dodge-cancel frames are recomputed from the existing formula. Hitstun, blockstun, hit-stop, damage and posture don't change. Properties the current tests guard stay true: for example a defender can block or parry the second light of every string.
- **The roll's travel.** The dodge's position curve (today `ease_out_cubic` over 16 frames) becomes the Roll01 [RM] root's ground travel, normalised to 0–1, resampled to 16 frames and stored as 17 numbers in the rules' constants. The distance stays `MOVE_DODGE_DIST` × the weapon's dodge multiplier (× 1.5 disarmed). The backstep keeps its curve.

### Rules changes

All of these get rule tests and a soak run.

- **Dodge roll.** Same numbers: `MOVE_DODGE_DIST` 2.8, `MOVE_DODGE_FRAMES` 16, `MOVE_DODGE_I_FRAMES` 12, `MOVE_DODGE_RECOVERY` 9. Only the travel curve changes, as above. The forward-dodge counter window, the stomp, Passing Cut's direction and the dodge attacks are unchanged. The backstep keeps `MOVE_BACKSTEP_*` and its curve.
- **Knockdown.** A new fighter state.
  - It's caused by a hit (not a block, a parry or a counter) from: an unblockable; a heavy released at full charge (a power attack); Mountain Slam, Meteor Drop or Leaping Smash. A hit that knocks out plays the KO instead.
  - Three phases: fall, ground, stand-up. The provisional lengths are 20, 30 and 25 frames (75 in all); the clips' markers and soak runs settle the final ones.
  - The fighter is invulnerable from the first frame of the fall until frame 10 of the stand-up. For its last 15 frames the fighter can't attack, dodge or move but can block or parry (rising in guard), so a hit timed on the wake-up isn't guaranteed.
  - Knockdown replaces the hitstun of those hits; damage, posture and knockback distance are unchanged. A `knockdown` event marks the fall, and a `standup` event its end.
  - The stomp keeps its 70-frame stun (the thrust counter's reward is a punish string), and the leap's and redirect's stuns are unchanged.
  - Settled in task 16 (`SimConst.KNOCKDOWN_*`, `Fighter.enter_knockdown()`, `World.knocks_down()`):
    - the ultimates' hits don't knock down, though their move data marks them unblockable (a Tempest spin would otherwise end the ultimate on its first hit);
    - a bare-handed defender whose posture breaks on the hit is dazed (the stagger), as before, rather than knocked down;
    - "invulnerable" here means nothing can hit the downed fighter, undodgeable moves included (unlike dodge invincibility);
    - the downed fighter doesn't turn while down, and turns to face the attacker at the free turn rate during the guard window;
    - a block or parry in the guard window ends the knockdown there (into blockstun or the parry's recovery), without a `standup` event; `standup` marks only the timer running out;
    - the computer opponent presses no attack while its opponent is down, even one planned before the fall, and closes in to meet the rise.
- **Greatsword shoulder carry.** A new flag on an armed Greatsword fighter.
  - On: after 20 consecutive frames of moving in the free state (walking, running, sprinting or stepping), and at the start of every round.
  - Off at once on any attack, block, parry, dodge, backstep, hitstun, blockstun, knockdown, disarm or pick-up. Standing still and jumping leave it as it is.
  - Any attack started while shouldered (lights, heavies, sprint and jump attacks, block abilities and the ultimate) adds 6 frames to its startup (`GS_SHOULDER_LIFT_FRAMES`). Its active and recovery frames are unchanged; its dodge cancel opens 6 frames later.
  - Dodge attacks never pay, since the dodge clears the flag, and string follow-ups never pay, since the first attack cleared it.
  - A guard raised from the shoulder (a block or a parry press) clears the flag but starts the same 6-frame lift, and an attack started before that lift ends waits for the rest of it. So a block ability pressed with the guard pays all 6 frames, one pressed a frame later pays 5, and one from a guard already up pays none (settled in plan task 15).
  - While lifting, the attack holds its frame 0, and the ultimate holds its first phase.
  - The flag is part of the fighter's state, so the presentation and the computer opponent read it.
- **The computer opponent** knows about knockdowns (it doesn't attack a downed fighter until the stand-up's guard window) and about the shoulder lift (its timing and reach estimates for Greatsword attacks include it).

### Presentation

- **The clip director.** A pure function, like `HudState`: given a fighter's rules state (state, state frame, move and attack frame, velocity in the fighter's facing space, flags such as shouldered and blocking) and the frame's events, it returns which clips play, at what times, and with what blend weights. It has no nodes, so tests drive it directly. The fighter view applies its answer to an `AnimationTree` advanced only on rules frames, so everything holds still in hit-stop and pause and stretches in slow motion.
- **Clip time.** An attack's clip time is set from the attack frame each rules frame, so the clip never drifts from the rules: wind-up across the startup, strike across the active frames, follow-through across the recovery. A charge holds the clip at the end of its wind-up. Hit-stop holds it.
- **Crossfades** (in rules frames, held in hit-stop): into an attack 3; a string follow-up 4, from the previous clip's pose; a dodge-cancel 2; hitstun cutting into an attack 1, which is a cut; locomotion 6; stance changes 8. A crossfade into an attack starts on the attack's first frame and never delays it.
- **Locomotion.** A 2D blend space on velocity in the fighter's facing space:
  - forward and backward with Walk01 and Run01 (Forward, Backward and the diagonals);
  - sideways with StrafeWalk01 and StrafeRun01;
  - Sprint01 in its five forward directions at sprint speed;
  - Turn01 Left and Right when the facing changes by more than about 30° while standing.
  The playback rate follows the measured stride of each clip, as the step phase does today. The hip-turn strafing, the reversed cycle, the lean and the guard shuffle are retired; foot locking only keeps planted feet still.
- **Foot locking under every clip.** The leg IK holds a planted foot where it landed under every clip, not only locomotion: the attacks, the reactions and the roll's getting-up too. The retargeting prototype found planted feet creeping up to 6 cm on our fighters (where the hip joints sit on the pelvis differs between the rigs), and the owner chose at the task 1 gate to lock them everywhere (planted feet move under 1 cm).
- **Stances.**
  - The free state's idle is the weapon class's combat idle: CombatIdle1H01 for the Katana (two hands on the grip with IK) and the Daggers (in reverse grip), CombatIdle2H01 for the Greatsword, CombatIdle01 for bare hands.
  - The Greatsword carry layers the masked ObjectGripShoulder pose on the upper body over the locomotion. The 6-frame lift is a crossfade from the shoulder pose into the attack clip's first frame. Built in task 18 (`ClipDirector.carry_clip()`): ObjectGripShoulder02_R (of the Crafting pack's masked poses; 01_R throws the elbow out to the side), the right hand on the grip at the shoulder, the blade back over it and the off hand on the grip below; it fades in over 8 frames (a stance), the legs walking under it, and a guard raised from the shoulder fades back to the legs over the same 6-frame lift. There is no CC0 carry, so without the packs nothing shows it.
  - The Daggers flip from reverse to forward grip (a 180° turn of each dagger about the hand) over the attack's 3-frame crossfade, and back over the last 6 recovery frames when no follow-up comes. Built in task 21: the director gives each shot the grip (`Shot.grip`, 0 forward to 1 reverse), turned forward from wherever it stood over the attack's crossfade (a follow-up's 4 frames too) and back over the last 6 frames unless a follow-up is queued; `FighterRig.set_reverse_turn()` turns the fixed daggers that far. The bake reads the forward grip, which every active frame holds. The Rogue, whose daggers ride the baked paths, turns over the swing player's blend instead.
- **Reactions.**
  - Hitstun plays CombatDamage01 or CombatDamage02, picked by the hit's side.
  - Blockstun plays the weapon class's Parry Hit (1H, 2H, DW; the 1H one for bare hands), and a held block holds Parry Loop.
  - The parrier plays Parry Hit. The parried attacker's clip runs backwards from its contact frame over the rebound, then hands over to a stagger built from Stun01 for the rest of the recoil.
  - Long stuns (stomp, leap, redirect, disarm stagger, impaled) play Stun01 fitted to the stun's length.
  - Knockdown plays Knockdown01 Fall, Ground and StandUp fitted to the three phases.
  - KO plays CombatDeath01–04, picked by the final blow's direction (front or back) and strength (light or heavy). It is slowed by the final-blow slow motion.
- **Dodge.** A roll plays Roll01 with the body turned toward the roll's direction. It turns back to face the opponent over the recovery, or over a dodge attack's first 3 frames, so the attack comes up facing them. The backstep plays Dodge01 (to be confirmed in the prototype). The ghost trail planned in 15.9 is dropped. A new roll sound (cloth and a thump) plays on the `dodge` event when it isn't a backstep; the backstep keeps the dash whoosh.
- **Intro.**
  - The Katana is drawn from its saya at the left hip (Unsheathe Hips01_R).
  - The Daggers are drawn from two leather sheaths at the small of the back (Unsheathe Hips01_Both, with its hand targets moved onto the sheaths by IK). The sheaths are new meshes built in code, like the saya.
  - The Greatsword is lifted onto the shoulder (CombatEnter2H01 into the shoulder pose).
  - Bare hands play CombatEnter1H01 empty-handed.
- **Victory.**
  - Katana: sheathe into the saya (Sheathe Hips01_R), then bow (Reverence01).
  - Daggers: toss one dagger, flip it in the air and catch it. This is hand-keyed in Blender on the Quaternius rig: our own, CC0, committed.
  - Greatsword: plant the blade in the ground and rest both hands on the pommel. Hand-keyed the same way, with hand IK locking the hands to the pommel.
  - Bare hands: Cheer01.
- **Effects.** The trails, sparks, flashes and the unblockable's red blade follow the visible blade, which is now where the baked path is. The camera kick and the hit-stop stay.

### The clip table (provisional)

Every move has a first candidate and a fallback. The candidates are picked from clip names, lengths and the packs' lists, not yet by eye: the plan's first step renders a catalogue sheet of every candidate on our fighters, and each weapon's review gate may swap any clip. `_L` and `_R` are Kevin's mirrored pairs; the one whose swing direction matches the move's sides is used, and any clip may also be mirrored. "UAL2" clips are from the Source tier and CC0; "UAL" clips are in the committed library today. The fallback is what a fresh clone without the Iglesias packs plays, and also what plays if a candidate fails review with nothing better.

Two-handed weapons on one-handed clips (the Katana) put the off hand on the grip with IK.

**Katana**

| Move | First candidate | Fallback |
|---|---|---|
| Right Cut | Attack1H01 (R→L) | UAL2 Sword_Light_A |
| Return Cut | Attack1H03_R (its cut runs left to right at the waist; task 10) | UAL2 Sword_Light_B |
| Kesa Cut | Attack2H01 from its wound-up pose (frame 8; task 10) | UAL2 Sword_Light_C |
| Crown Cut | Attack2H02 (the packs' only straight overhead; task 10) | UAL2 Sword_Light_D |
| Iai Slash, vertical | SheatheHips01_R (frames 3–12, held on the charge frame) into Attack1H04_R from frame 2 (task 11) | UAL Sword_Attack |
| Iai Slash, horizontal | SheatheHips01_R (frames 3–12, held) into Attack1H05_R, whose cut rises right to left (task 11) | UAL Sword_Regular_A |
| Rising Heaven | Attack1H05_R (a rising cut, right to left; Attack2H02 is an overhead; task 11) | UAL2 Sword_UpperCut |
| Returning Draw | Attack1H04_R (a descending cut, left to right; task 11) | UAL Sword_Regular_B |
| Heaven Splitter | Attack2H04 (the straight overhead slam; Attack2H01 is a diagonal; task 11) | UAL2 Sword_Heavy_C |
| Running Draw (sprint light) | Attack1H01_R (task 12; UAL2 Sword_Dash reaches 1 m and stands side-on) | UAL Sword_Dash |
| Leaping Cleave (sprint heavy) | Attack2H04, which hops into its slam (task 12) | UAL2 Sword_Aerial_B |
| Wind Cut (dodge light) | Attack1H02_R from frame 4 (task 12) | UAL Sword_Regular_C |
| Whirl Cut (dodge heavy, spin) | Attack2H03, its sweep wound round from behind (task 12; Attack2H04 is the overhead slam) | UAL2 Sword_Heavy_D |
| Rising Cut (back light) | Attack1H05_R (task 12) | UAL Sword_Regular_A |
| Lunging Cut (back heavy) | Attack2H01 (task 12) | UAL Sword_Dash |
| Aerial Cut (jump light) | Attack1H01_R from frame 4 (task 12; UAL2 Sword_Aerial_A would need 60 cm more reach and 4 fewer recovery frames) | UAL Sword_Attack |
| Falling Crown (jump heavy) | Attack2H04 from frame 6, the blade already overhead (task 12; UAL2 Sword_Aerial_B is a level sweep) | UAL Sword_Attack |
| Flash | Parry1H01_R Loop, then Hit; pose-only, its swing moves the body alone (task 13) | UAL Sword_Block |
| Piercing Thrust (unblockable) | AttackPolearm01 (thrust), two-handed, its pull-back held 4 frames so it shows in the first third of the wind-up (task 13) | UAL Sword_Dash |
| Swallow Sweep (unblockable) | Attack2H03 (low), its wind-round held 4 frames the same way (task 13) | UAL2 Sword_Heavy_B |
| Counter Lunge | Attack1H04_R from frame 6 (task 13) | UAL Sword_Dash |
| Moonsplitter (ultimate) | Attack2H01 raised and held through the wind-up, then released as the wave goes out; Attack2H03 for the horizontal wave (task 13) | UAL Sword_Heavy_Combo |

**Greatsword**

| Move | First candidate | Fallback |
|---|---|---|
| Heavy Swing | Attack2H01 from its wound-up pose (frame 8), the diagonal from the right shoulder (task 18; Attack2H02 is the overhead) | UAL2 Sword_Heavy_A |
| Backswing | Attack2H01 mirrored, from frame 8 (task 18: no two-handed clip cuts left to right; Attack2H02 mirrored is still an overhead) | UAL2 Sword_Heavy_B |
| Overhead Strike | Attack2H02, the straight overhead, held raised on the charge frame (task 18) | UAL2 Sword_Heavy_C |
| Low Sweep | Attack2H03, its wind-round held 5 frames (task 20) | UAL2 Sword_Heavy_D |
| Shoulder Charge (sprint light) | UAL2 Shield_Dash, its crouch held 4 frames first; strikes with the left shoulder (task 19) | UAL Sword_Dash |
| Leaping Smash (sprint heavy) | UAL2 Sword_GroundPound, held raised 4 frames to fill the startup (task 19) | UAL Sword_Heavy_Combo |
| Piercing Lunge (dodge light) | AttackPolearm01 (task 18) | UAL Sword_Dash |
| Skewer (dodge heavy) | AttackPolearm01 (the thrust), its pull-back held 4 frames (task 20; AttackPolearm03 is an overhead to the ground) | UAL Sword_Dash |
| Rising Edge (back light) | Attack1H05_R, two-handed (task 19; UAL2 Sword_UpperCut stands side-on and reaches 1.4 m) | UAL Sword_Regular_A |
| Lunge Cleave (back heavy) | Attack2H04 (task 19) | UAL2 Sword_Heavy_A |
| Aerial Chop (jump light) | Attack2H01 from its wound-up pose, faster than Heavy Swing (task 19; UAL2 Sword_Aerial_A is 12 frames, too short for the move) | UAL Sword_Attack |
| Meteor Drop (jump heavy) | UAL2 Sword_GroundPound, held raised 2 frames (task 20; Sword_Aerial_B is a level sweep) | UAL Sword_Attack |
| Reaping Sweep | AttackPolearm04, a whole-body spin, held 4 frames (task 20: it reads apart from Low Sweep) | UAL2 Sword_Heavy_D |
| Mountain Slam | AttackPolearm03, the overhead to the ground (task 20: it reads apart from Leaping Smash) | UAL Sword_Heavy_Combo |
| Guard Crusher | AttackShield01 (bash), with both hands on the grip; strikes with the left shoulder (task 19) | UAL Idle_Shield_Break |
| Counter Lunge | AttackPolearm01 from frame 4 (task 19) | UAL Sword_Dash |
| Impaler (ultimate) | AttackPolearm01: drawn back through the aim, thrust on the dash and held through the impale (task 20; Sprint01 swings the arms free through the dash) | UAL Sword_Dash |

**Daggers**

| Move | First candidate | Fallback |
|---|---|---|
| Quick Slice (right hand) | Attack1H01_R (task 21) | UAL Punch_Jab |
| Off-hand Slice (left hand) | Attack1H01_L, the left hand's slash (task 21) | UAL Punch_Cross |
| Twin Rip (crossing cut) | AttackDW01 (task 21) | UAL Melee_Hook |
| Flurry Finisher (double stab) | AttackDW02 (task 21) | UAL2 Melee_Uppercut |
| Twin Fang (dash, double stab) | AttackDW02, its wind-back held 3 frames and on the charge frame; the rules' 1.4 m lunge is the dash (task 21) | UAL Sword_Dash |
| Spinning Backhand | AttackPolearm04, a whole-body spin with a dagger in each hand (task 21: no one-handed or dual-wield clip spins) | UAL Melee_Hook |
| Slide Slash (sprint light) | Basic Motions RunSlide01 with Attack1H02 on the upper body | UAL Sword_Dash |
| Pounce (sprint heavy) | Jump01 Begin into AttackDW02 | UAL2 Sword_Aerial_B |
| Passing Cut (dodge light) | Attack1H03_R from frame 4 (task 21) | UAL Sword_Regular_A |
| Reverse Spin (dodge heavy) | AttackDW01, mirrored | UAL Melee_Hook |
| Flick (back light) | AttackPunch02 with the blade (a short jab) | UAL Punch_Jab |
| Rebound Lunge (back heavy) | Attack1H04 | UAL Sword_Dash |
| Air Slash (jump light) | UAL2 Sword_Aerial_A | UAL Sword_Attack |
| Dive Stab (jump heavy) | UAL2 Sword_Aerial_B | UAL Sword_Attack |
| Serpent Sweep (unblockable) | RunSlide01 into Attack1H02, low | UAL2 Slide_Start |
| Shadow Step | Roll01, sped up, with the body hidden in the blink | UAL Roll |
| Needle Thrust (unblockable) | AttackPolearm01, one-handed | UAL Sword_Dash |
| Counter Lunge | Attack1H04 | UAL Sword_Dash |
| Lightning Tempest (ultimate) | AttackDW01 and AttackDW02 chained with Roll01, then UAL2 Sword_Aerial_Combo_Loop for the final | UAL Sword_Heavy_Combo |

**Bare hands**

| Move | First candidate | Fallback |
|---|---|---|
| Jab | AttackPunch02_L | UAL Punch_Jab |
| Cross | AttackPunch01_R | UAL Punch_Cross |
| Hook | AttackPunch03_L | UAL Melee_Hook |
| Roundhouse | AttackKick01_R | UAL Melee_Hook |
| Spinning Heel | AttackKick02_R with a body spin | UAL Melee_Hook |
| Flying Knee (sprint light) | UAL2 Melee_Knee | UAL Melee_Hook |
| Dragon Kick (sprint heavy) | Jump01 Begin into AttackKick01 | UAL Melee_Hook |
| Slip Jab (dodge light) | AttackPunch02_R | UAL Punch_Jab |
| Spinning Backfist (dodge heavy) | AttackPunch03_R with a body spin | UAL Melee_Hook |
| Snap Kick (back light) | AttackKick02_L | UAL Melee_Hook |
| Lunging Palm (back heavy) | AttackPunch01_L | UAL Punch_Cross |
| Air Kick (jump light) | UAL2 Melee_Knee in the air | UAL Melee_Hook |
| Axe Kick (jump heavy) | AttackKick01, downward | UAL Melee_Hook |
| Counter Lunge | AttackPunch01_R | UAL Punch_Cross |
| Breaker Palm (ultimate) | AttackPunch03, held, then UAL2 Melee_Uppercut | UAL Melee_Hook |

**States and counters**

| State | First candidate | Fallback |
|---|---|---|
| Free, idle | Combat idle per weapon class (above) | UAL Sword_Idle, Idle |
| Walk, run, strafe, sprint, turn | Iglesias Walk01, Run01, StrafeWalk01, StrafeRun01, Sprint01, Turn01 | UAL Walk, Jog_Fwd, Sprint and UAL2 Walk_*_Loop |
| Step | Walk01 at the step's speed | UAL Walk |
| Dodge (roll) | Roll01 | UAL Roll |
| Backstep, evade's back-dash | Dodge01 | UAL Roll, reversed |
| Jump, land | Jump01 Begin, Jump01, Jump01 Land | UAL Jump_Start, Jump, Jump_Land |
| Stomp (stepping on a thrust) | AttackKick02 (downward) | UAL Melee_Hook |
| Leap (off a sweep) | Jump01 Begin into Fall01 | UAL NinjaJump_Start |
| Evade lunge | Attack1H04, or the weapon's counter lunge | UAL Sword_Dash |
| Block (held), blockstun, parry | Parry Loop and Parry Hit per weapon class | UAL Sword_Block |
| Recoil after a parry | Own clip reversed, then Stun01 | UAL Hit_Knockback |
| Hitstun | CombatDamage01, CombatDamage02 | UAL Hit_Chest, Hit_Head |
| Stunned, stagger, disarm stagger, impaled | Stun01 | UAL Hit_Knockback |
| Knockdown | Knockdown01 Fall, Ground, StandUp | UAL Hit_Knockback, LayToIdle |
| Pick-up | Basic Motions Loot01 | UAL PickUp_Table |
| Recall | Unsheathe for the weapon | UAL Sword_Idle |
| KO | CombatDeath01–04 | UAL Death01 |
| Intro, victory | As above | UAL Idle, Yes |

### Fallback without the packs

When the Iglesias libraries are missing, the clip director plays every clip's fallback from the committed CC0 library: UAL1 and UAL2 Standard today, plus the UAL2 Source clips the table names. The match shows a small "animation packs missing" note, and the logs name the setting to fix. The rules and every rules test are unaffected, because the baked swings, the roll curve and the frame data are committed. The fallback isn't reviewed for looks.

### If the retargeting prototype fails

The plan's first task retargets five clips (CombatIdle1H01, Attack1H01_R, Attack2H01, Roll01, CombatDeath01) onto both fighters and renders their contact sheets. It fails if the hands can't hold the grip, the feet slide or cross through each other, or the proportions break (shoulders, elbows or knees bending wrongly), and no bone-map or rest-pose fix cures it in the task. If it fails, the feature continues with UAL2 Source clips (on our own rig, no retarget) as the first candidates wherever the table has one, and the procedural swing player stays for the moves without one. The owner decides at that gate.

### Review

- A **catalogue sheet** renders every candidate clip on both fighters at four phases, before any move is assigned.
- A **contact sheet** per move (the existing `move_sheet` scene, now playing clips) shows wind-up, contact and follow-through from the gameplay camera, three-quarter and close.
- A **before/after video** per weapon plays each move side by side: the procedural version from `feature/godot-rebuild` and the clip version.
- **The owner's OK per weapon** gates the next weapon, in the order Katana, Greatsword, Daggers, bare hands, then reactions and movement, then the round flow.
- A final **playtest** checks cancels, hitstun interrupts, the roll, knockdowns and the shoulder carry.

## Testing Decisions

A good test checks behaviour at a public seam, not how the code works inside: build the thing, feed it inputs, assert on outputs and events. Three seams cover this feature, each as high as it can be.

- **The rules (GUT, headless; prior art `test_fluid_combat`, `test_combat`, the weapon string tests, `test_duel_reach`, `test_move_reach`, `sim_helpers`).** A world with two fighters, inputs in, events and states out:
  - the roll travels the same distance in the same frames, along the baked curve, with the same i-frames and counter window; the backstep is unchanged;
  - each knockdown cause knocks down on a hit and not on a block or parry; a KO hit doesn't knock down; the downed fighter is invulnerable until stand-up frame 10, can then block or parry but not attack, and is free on the last frame; the stomp still stuns for 70;
  - the Greatsword's shoulder flag turns on after 20 frames of moving and at the round start, off on each listed action, and an attack from the shoulder hits 6 frames later with its dodge cancel 6 later;
  - every weapon's baked swings load, pass the swing checks, and pass the reach and whiff tests from the test-distance table;
  - the retuned frames: `test_moves` records each change in its deliberate-differences tables, and the string tests still pass (for example a defender can parry the second light);
  - the computer opponent waits out a knockdown.
- **The bake (GUT, headless; prior art `test_swing_*`, `test_animation_library`).** The bake as a pure function: a sampled clip, its markers and a speed in; the retimed clip and the swing samples out. Tested on a committed CC0 UAL clip, so CI needs no Iglesias packs:
  - the markers land on the right rules frames at a given speed;
  - the samples match the posed hand within 1 mm;
  - the reach correction stays under 15 cm and is zero outside the attack;
  - the output is deterministic;
  - a missing marker or a speed outside 1.0–2.0 is refused;
  - the import tool's bone map maps every bone it uses.
  A local-only test, skipped when the packs are missing, re-bakes every move and fails if a committed swing file differs.
- **The clip director (GUT, headless; prior art `HudState` and its tests).** A fighter's rules state and events in; clips, times and weights out:
  - each state picks its clip;
  - attack clip time follows the attack frame;
  - hit-stop and pause hold the time;
  - each crossfade has its length, and a hitstun cut has none;
  - the Daggers' grip flips on the crossfade;
  - the shoulder carry shows when the flag is on;
  - the fallback table is used when the libraries are missing;
  - every move of every weapon resolves to a clip, so none is ever missing.
- **Content.** The clip manifest names only clips the import tool can find, and every manifest clip has its four markers; the committed CC0 library holds every fallback clip.
- **Soak.** Per weapon, after its retune: 300 matches (`soak:tune`); win rates must stay within ±5 points of the last soak on `feature/godot-rebuild` before this work (recorded at the start of the plan), and round length and disarms stay in their targets. The 40-match soak stays the clean check.
- **By eye.** The catalogue sheet, contact sheets and before/after videos above, reviewed by the owner.

## Out of Scope

- New weapons, including the Polearm clips' future spear.
- New fighters, and per-fighter clip sets beyond the Rogue's HumanF and the Hunter's HumanM.
- Motion capture or new clips beyond the two hand-keyed victory clips (Daggers toss, Greatsword plant).
- Rule changes other than the knockdown, the Greatsword's shoulder carry, the roll curve and the retuned frame data.
- Ground attacks on downed fighters, and get-up choices.
- The match intro's gates and walk-out, and the character select screen. This feature adds only the draw at the round intro and the victory poses.
- Publishing converted Iglesias clips, unless Kevin confirms in writing that it's allowed.
- The swing editor plugin (14b), now retired.

## Further Notes

### Where this differs from `docs/specs/godot-rebuild.md`

- **"How attacks are animated":** authored clips replace the procedural swings (the weapon path moving the weapon, the arms reaching on IK, the torso and hips turning).
- **"Movement animation":** Iglesias directional sets replace the Quaternius forward clips with procedural strafing, backpedalling, leaning and dodge poses.
- **"What decides a hit":** still the swing, but baked from the clip, not hand-keyed. The continuity rule on a follow-up's first key is dropped.
- **Weapon swings:** the swing editor, the named shapes and the per-weapon hand keys (7.16–7.38) are retired. The swing file format gains baked tracks.
- **Presentation of fighters:**
  - the weapon is fixed to the main hand (it was never fixed to a hand);
  - the guard shuffle, the hip-turn strafing, the lean, blade lag (14.14), the procedural parry bounce (14.15) and the ghost trail (15.9) are retired;
  - the swing player (14.10–14.13) and the stick poses are removed once every move has a clip;
  - the saya (14.16) and the review sheets (14.17) stay.
- **Fighters:** the Rogue still idles with the daggers reversed, now flipping them to attack.
- **Rules:** a knockdown state, the Greatsword's shoulder carry and the roll's travel curve are new. Every move's frame data is retuned, so the move tables become provisional until each weapon's review.
- **Parry:** the attacker's rebound is its own clip reversed rather than the weapon bouncing back along a keyed path.
- **Out of scope:** victory poses move into scope. The draw at the round intro is added, but the match intro's gates aren't.
- **Licences:** a fourth source, the Iglesias packs, is used but not committed.
- **Risks:** "Procedural attack animation may not look good enough" becomes the risks below.

The godot-rebuild spec is updated on this branch where these change it. Its plan's retired tasks are marked when this feature's plan is written.

### Where this differs from `docs/design.md`

- **Dodge:** design.md said "a dash, not a roll" (Movement) and "a dash with brief invincibility frames" (Defending). It's now a roll in any direction; the backstep stays.
- **Knockdowns** are new: big hits knock down, and the downed fighter is invulnerable.
- **Greatsword:** carried on the shoulder while moving, and attacks from there are slower.
- **Assets:** licensed Iglesias packs join the CC0 sources, used in builds but not published.

design.md is updated on this branch for all four.

### Where this differs from `docs/mvp-spec.md`

Nothing changes there. mvp-spec.md is the record of the web demo, which keeps its dash, and the godot-rebuild spec already lists how the Godot game departs from it.

### Licence

Checked on Oct 3, 2026 against keviniglesias.com (the licence section, updated May 31, 2026), the Unity Asset Store EULA and the packs' PDFs:

- Commercial use is allowed, credit isn't required, and resale isn't allowed. Use in Godot is explicitly fine.
- The assets can't be distributed as standalone items or in any product "where the files are accessible or extractable for reuse". EULA 2.2.1(b) allows distributing them only as part of the product they're built into, and 2.4 says every user needs their own licence.
- Converted and retargeted clips are still the asset (EULA 2.2.1(e) and section 11), so committing them to a public repo is very likely not allowed. A built game is fine.

**Uncertain, for the owner to confirm with Kevin (support@keviniglesias.com):**

1. Whether the baked swing paths may be committed. They are a few numbers per frame for the grip and blade, not a playable animation.
2. Whether converted clips could ever sit in the public repo under a "not covered by the repo licence" note.
3. Whether contributors without a licence may build and run the game from the repo (the fallback means they never need the clips).
4. Whether the free and paid packs share these terms.

Until he answers, the baked paths are committed, and moving them into the local build is a small change if he objects.

A draft for the owner to send:

> Hello Kevin, I use your Human Melee Animations and Human Basic Motions packs in Monomachia, a fighting game made in Godot whose source is public on GitHub (github.com/Arod231/monomachia). I keep your files and the clips I convert from them out of the repo; they're built locally and ship only inside the exported game. Could you confirm two things? First, is it fine to commit the weapon paths I sample from your attack clips: for each attack, the hand position and blade direction once per frame, which the game uses to decide hits but which isn't an animation anyone could play? Second, is shipping the converted clips inside exported builds, including any web build, within your licence? Thank you for the packs.

### Risks

- **Retargeting from Kevin's rig onto the Quaternius rig fails or looks wrong.** The prototype gate comes first, and the fallback above is stated.
- **Too few clips for 70 moves.** Mirroring, speeds, chaining and UAL2 fill the gaps; moves that end up sharing a clip are listed at each review.
- **Retuning shifts balance.** Bounded speeds, per-weapon soaks with a ±5-point limit, and the string properties the tests guard.
- **The knockdown's wake-up guard window** may be too generous or too stingy. The soak and the playtest tune the phase lengths.
- **Reversed clips for the parry rebound** may look odd. The fallback is Stun01 from the contact frame.
- **The Rogue's HumanF clips drift from the shared path.** The bake flags any move more than 5 cm off, and she plays HumanM for it.
- **Licence.** The converted clips are never committed. The baked paths are committed pending Kevin's answer.
- **Clip quality varies.** The catalogue sheet is reviewed before assignment, and every weapon is reviewed before the next.
