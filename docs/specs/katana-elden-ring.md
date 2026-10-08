# Spec: an Elden Ring Katana, with grips, a 1.3 m blade and taller fighters

Oct 6, 2026 · status: approved by the owner on Oct 6, 2026, with the defaults D1–D17 as written; the plan is `docs/plans/katana-elden-ring.md`

Read with: [ADR 0002](../adr/0002-elden-ring-motion-and-scale.md) (and [ADR 0001](../adr/0001-animation-leads-realistic-look.md), which it amends), `docs/design.md` (every "(Oct 6)" line), `docs/specs/milestone-1.md` (this spec changes it inside milestone 1; the stories it supersedes are listed under "Changes to milestone 1") and its plan `docs/plans/milestone-1.md`.

This spec turns the owner's answers from the Oct 6 grilling (28 questions, after a frame-by-frame reading of an Elden Ring Uchigatana moveset showcase and a blade-length prototype) into one build. It sits inside milestone 1: the Hunter with the Katana and bare hands at final quality now means the Katana as Elden Ring's Uchigatana plays it.

## Problem Statement

On Oct 6, 2026 the owner compared the Katana with Elden Ring's Uchigatana and found ours short and tame:

- **The blade is short.** It is 0.69 m from the habaki to the tip (documented as 0.72 m), about 0.39 of the Hunter's height, which is real-world proportion. Elden Ring's blade is about three-quarters of its character's height, and the owner wants that presence.
- **The swings are small.** Today's cuts start near the body and stop near it. Elden Ring's carry the blade behind the head before a near-instant strike, hold the pose after it, and drop into a deep crouch on a string's last hit; that rhythm (slow, readable wind-up, snap, held follow-through) is what the owner wants the duel to feel like.
- **There is one way to hold the sword.** The Katana is fixed two-handed (design.md's Oct 4 "every cut two-handed"). Elden Ring's Uchigatana has a one-handed and a two-handed grip, each with its own string and heavies, and switching between them is part of its play.
- **The fighters look small next to an Elden Ring hero.** The owner wants them taller, with heroic proportions, so the oversized sword sits right in their hands.
- **The light string is four hits.** Elden Ring's is five, ending in a heavy, crouching last hit.

The reference, as measured from the video (60 fps, by eye, ±3 frames):

| | One-handed | Two-handed |
|---|---|---|
| Light string | 5 hits; first lands ~24–27 f from rest; hits ~49–57 f apart; last hit's recovery ~85–90 f with a flourish | 5 hits; first lands ~21–23 f from rest; hits ~37–41 f apart (~25% quicker); last hit's crouch ~42 f |
| Shapes | diagonal down, backhand rising, rising with a big twist, horizontal, overhead last hit into a crouch | overhead diagonal, rising from the left, rising from the right, overhead diagonal, vertical last hit into a kneel |
| Heavy | blade coiled over the shoulder (~0.65 s hold), a loop low and up, a wide horizontal cut held ~0.5 s at full extension; ~90 f to impact | held overhead (~0.5 s), an overhead cut with a long lunge into a deep crouch, then a rising follow-up from the crouch ~1.3–1.45 s later |
| Unsheathe (our Iai) | quick flat draw ~18–20 f from the stance, held 0.7–0.9 s, chiburi and resheathe; or a deep coil and a vertical rising draw ~24 f, snapping back into the stance in ~12 f | (shared) |

## Solution

The Katana becomes Elden Ring's Uchigatana inside the realistic look:

- **Two grips.** A new grip button (pad Y, keyboard R; the pad's Ultimate moves to L2) switches between a one-handed and a two-handed grip instantly, in any state the fighter can act in. Each grip has its own five-hit light string, its own chargeable heavy, its own idle, guard and carry. Rounds start one-handed. Mid-string, the swing in progress finishes and the next hit is the next one of the other grip's string, so strings can mix grips. One-handed reaches wider and recovers faster for less damage; two-handed hits harder, pressures the guard more and guards better.
- **Elden Ring's moves, re-keyed.** Both strings, both heavies and the Iai's draws are re-keyed in Blender from the Kevin Iglesias clips with the video's frame sheets as reference, and the owner polishes the signature moves in Cascadeur. Animation still leads: the frame data come from the clips, timed to the video's measured rhythm, and only the protected timings stay rules numbers.
- **Heavy from neutral stays the Iai Slash**, shared by both grips, with Elden Ring's Unsheathe draws: the horizontal is the quick flat draw, the vertical the coiled rising draw, both ending in a chiburi and a resheathe. The grip heavies come off the strings' heavy branches and the Iai's follow-ups; Heaven Splitter becomes the two-handed overhead lunge and Rising Heaven its rising follow-up.
- **A 1.3 m blade, taller fighters, wider spacing.** The Katana's model gets a 1.3 m blade. The Hunter and the Rogue are re-proportioned about 15% taller with heroic proportions. The duelling distance and the distance bands grow with the new reach; the Greatsword and Twin Daggers grow with the bodies until their own milestones size them.

## User Stories

### The grip

1. As a Katana player, I want a grip button that switches between a one-handed and a two-handed grip, so that I can play both of the Uchigatana's movesets.
2. As a Katana player, I want the switch to happen at once, with no switching animation to wait out, so that switching is a tool I use mid-fight.
3. As a Katana player, I want to switch while standing, moving, blocking, mid-string and in the Iai's stance, so that the grip never locks me out.
4. As a Katana player, I want the switch refused while I'm in hitstun or blockstun, knocked down, jumping or dodging, so that it can't escape punishment.
5. As a Katana player, I want a switch made mid-string to let the swing in progress finish and make my next light the next hit of the other grip's string, so that I can mix the two strings (one-handed hit 2, then two-handed hit 3).
6. As a Katana player, I want each round to start one-handed, as Elden Ring does, so that every round starts the same.
7. As a Katana player, I want to read my grip and my opponent's from the pose alone (each grip with its own idle, guard and way of carrying the sword), so that the screen stays clean without a grip icon.
8. As a Katana player, I want the one-handed grip faster and wider-reaching for less damage, and the two-handed grip harder-hitting with more guard pressure, so that the choice matters.
9. As a Katana player, I want my guard to take less posture in the two-handed grip, so that holding the sword in both hands is also the defensive choice.
10. As a Katana player, I want parrying, Flash and the protected defensive timings to work the same in both grips, so that defence stays learnable.
11. As a player on a gamepad, I want the grip on Y (Triangle) and the Ultimate moved to L2, so that the grip sits where Elden Ring puts it.
12. As a player on a keyboard, I want the grip on R, with the Ultimate staying on Q and U, so that the switch is beside the movement keys.
13. As a player on a fight stick, or player 2 on a shared keyboard, I want the grip on a free button of my layout, so that every layout can switch.
14. As a player, I want to rebind the grip in my control profile like any other action, so that my profile keeps working.
15. As a player, I want the move list, How to play and the controls screen to show the grip and both grips' moves, so that I can learn them.
16. As a disarmed player, I want bare hands to have no grip, and my Katana to come back one-handed when I pick it up or recall it, so that the grip has one simple reset.

### The light strings

17. As a Katana player, I want a five-hit one-handed string (a diagonal cut down, a backhand rising cut, a rising cut with a big twist, a horizontal cut, and an overhead last hit into a deep crouch), so that it plays like the Uchigatana's.
18. As a Katana player, I want a five-hit two-handed string (an overhead diagonal, a rising cut from the left, a rising cut from the right, another overhead diagonal, and a vertical last hit into a kneel), tighter and about a quarter quicker between hits, so that the two-handed grip has its own rhythm.
19. As a Katana player, I want each string's last hit to commit me (a long recovery, as Elden Ring's crouch is), so that finishing a string is a real risk.
20. As a Katana player, I want the strings' wind-ups to carry the blade far behind the head and the strikes to snap through in a few frames, so that the swings read as Elden Ring's.
21. As a defender, I want to stay free to block or parry a frame or two before each next hit of a string, in both grips and in mixed strings, so that the protected free-frame rule still holds.
22. As a Katana player, I want a string to flow (a swing that ends on the right continues from the right) across a grip switch too, so that mixed strings look keyed, not stitched.

### The heavies

23. As a Katana player, I want heavy from neutral to stay the Iai Slash in both grips, so that the Katana keeps its signature.
24. As a Katana player, I want a one-handed heavy (the blade coiled over the shoulder, then a wide horizontal cut held at full extension) as the one-handed string's heavy branch and the Iai's follow-up, so that the one-handed grip has its heavy.
25. As a Katana player, I want the two-handed heavy pair (Heaven Splitter: an overhead lunge into a deep crouch; then Rising Heaven: a rising follow-up from the crouch) as the two-handed string's heavy branch and the Iai's follow-up, so that the two-handed grip has its heavies.
26. As a Katana player, I want to charge the grip heavies by holding heavy (the held coil or overhead pose growing longer and the cut landing harder, up to the power attack), so that they work like Elden Ring's charged heavies.
27. As a Katana player, I want a light's heavy branch to start my current grip's heavy, so that the grip decides the heavy.

### The Iai Slash

28. As a Katana player, I want the Iai's controls unchanged (heavy sheathes into the stance, I can strafe, letting go draws; the stick held left or right picks the horizontal draw), so that the input I know still works.
29. As a Katana player, I want the horizontal draw re-keyed as Elden Ring's quick flat draw, held at full extension, then a chiburi and a resheathe, so that it reads as an iaijutsu cut.
30. As a Katana player, I want the vertical draw re-keyed as Elden Ring's deep coil and rising vertical draw, so that the two draws look and feel different.
31. As a Katana player, I want Returning Draw kept as the horizontal draw's follow-up, so that the Iai keeps its extension.
32. As a Katana player, I want the Iai the same in both grips, and a grip switch in the stance to take effect for what follows the draw, so that the stance never depends on the grip.

### Blade, bodies and spacing

33. As a player, I want the Katana's blade 1.3 m long, so that it has the Uchigatana's presence.
34. As a player, I want the Hunter and the Rogue about 15% taller, with heroic proportions after Elden Ring's player characters (broad shoulders, longer limbs), so that the big sword sits right in their hands.
35. As a player, I want the duelling distance and the distance bands to grow with the longer blade and taller bodies, so that exchanges read as today's, only further apart, and blades don't pass through bodies.
36. As a Greatsword or Twin Daggers player, I want my weapon to grow with the bodies until its own milestone sizes it, so that it doesn't look shrunken in the taller hands.
37. As a player, I want hits to land where the blade visibly meets the body, so that the hurt capsules and the swing paths follow the new bodies.
38. As a player, I want the gameplay camera to frame the taller fighters as the mood board's Camera 2 framed today's, so that the view feels the same.

### The computer opponent

39. As a player against the computer, I want it to switch grips (two-handed to press and to guard, one-handed to reach and to recover fast), so that it plays the Katana fully.
40. As a player against the computer, I want it to mix grips mid-string at the harder levels, so that mixed strings are something I learn to read.

### The owner's tools and checks

41. As the owner, I want every new move in the per-move checklist and the move sheets, with the video's frame sheets beside it, so that I can review each against the reference.
42. As the owner, I want the soak and the counterlab to report both grips, so that balance covers each grip and mixed strings.
43. As the owner, I want the strings' last hits, the heavies and the Iai draws left for my Cascadeur pass after the scripted re-keys, so that the signature moves get my polish.
44. As the owner, I want the replay and save-and-restore tests to cover the grip and the string's count, so that online play stays possible.

## Implementation Decisions

### Rules

- **Grip is fighter state in the rules.** A fighter carries its current grip (one-handed or two-handed) and a string count (which hit of a string it is on). Both are snapshot fields, in the state hash and restored with the rest; the snapshot test already fails on a field left out.
- **The grip button is a ninth button.** It joins the button set and the input tracker. A press switches the grip at once when the fighter can act (neutral, moving, blocking, mid-attack, in the stance) and is ignored otherwise (hitstun, blockstun, knockdown, a jump, a dodge); it is not buffered. A switch never changes the move playing.
- **A weapon declares its grips.** A weapon with grips lists, per grip, its string (the moves in order) and its heavy branch, and the moves its grip heavies chain to; a weapon without grips (the Twin Daggers, bare hands, and the Greatsword until its milestone) keeps one implicit grip and behaves exactly as today. The one-handed and two-handed strings are separate moves with their own frame data, damage and swings.
- **Strings advance by count.** When a light follows a string hit, the next move is the current grip's string at the next count, wherever the previous hit came from, so a mixed string works without a move per pair. A light from neutral starts the grip's hit 1; a string ends after hit 5; any non-light move resets the count. This replaces the light chain from move to move for weapons with grips; heavy branches and follow-ups stay as branch points on the moves.
- **Heavies by grip.** Heavy from neutral starts the Iai Slash in both grips. A light's heavy branch starts the current grip's heavy (one-handed: the one-handed heavy; two-handed: Heaven Splitter, whose follow-up is Rising Heaven). The grip heavies charge through the existing charged-heavy rule, held pose growing to the power attack.
- **Guarding by grip.** The defender's posture gain on a block takes a mitigation factor per grip (two-handed lower than one-handed) in place of the weapon's single factor. Blockstun, the parry window and the other protected timings don't change with the grip.
- **Spacing.** The duelling distance, the round-start positions and the distance bands are re-measured from the new reach (D1). The Katana's strike segment becomes 1.3 m; the reach comes from the re-baked swings as today.
- **The computer** gains grip choice and mid-string switches (D8). New random draws shift the soak's numbers once; the soak's expectations are re-recorded.

### Frame data and clips

- **The usual pipeline.** Each new move is a Blender re-key of a Kevin Iglesias clip (`rekey_clip.py` specs), exported through the asset repository, imported, marked and baked; the frame-data table and the swings regenerate; every move must land in its timing band and connect from its distance band.
- **New band rows.** The timing table gains rows for the one-handed and two-handed string hits (with the last hit as its own kind, for its long recovery) and the grip heavies; the distance table is re-measured at the new duelling distance.
- **Per-grip state clips.** The idle, the guard and the carry layer are chosen by weapon and grip. The view's existing "grip" (the Twin Daggers' reverse grip in the clip director) is renamed so the word means only the rules' grip.
- **Grip switches in the view.** A switch plays a short re-grip transition clip (the off hand joining or leaving the grip) on top of inertial blending, one per direction, not one per pair of moves (D15).
- **Movement attacks and block abilities** keep one animation each, played from either grip; the re-grip transition covers the off hand.

### Bodies and blade

- **The Katana model** (plan task 47) is built with a 1.3 m blade; the strike segment, the blade markers and the blade-length test follow it.
- **The bodies are re-proportioned in Blender** from today's Quaternius sources: both scaled by the same factor (about 1.15) with heroic proportions on top (D10). Because both bodies change alike, the swings stay shared and are re-baked once. The reference bodies, the hurt capsules and the defender capsule are re-measured; the clips need no change (the hips track already follows each skeleton's motion scale), and the foot lock reads the new ankles.
- **Camera.** The gameplay camera's heights and distances are re-framed to keep the mood board's Camera 2 framing on the taller fighters (D11).
- **The other weapons** grow with the bodies (their models, strike segments and swings scaled by the body factor) until their own milestones.

### Controls

- **Bindings.** A fourteenth action, the grip: pad Y, keyboard R, a free button on the fight stick and a free key in player 2's shared-keyboard set (D12). The pad's Ultimate moves from Y to L2. Saved control profiles gain the action with its default; the controls screen, the move list and How to play show it.

## Testing Decisions

A good test drives the game the way a player does (inputs over steps) and checks what a player could observe (the move that plays, a hit, posture, a position), never a private field.

1. **Rules, driven by scripted input** (prior art: `test_katana_strings`, `weapon_strings_test`, `test_shoulder_carry`, `test_combat`): switching in every allowed state and refusal in the others; both five-hit strings; mixed strings carrying the count; a heavy branch per grip; the grip heavies' charge; two-handed guarding gaining less posture; rounds starting one-handed; the Katana coming back one-handed after a disarm.
2. **The generated tables** (`test_move_bands`, `test_duel_reach`, `test_protected_timings`): every new move inside its timing band and connecting from its distance band at the new duelling distance; the free-frame rule in both strings and across mixed hand-offs.
3. **Bodies and blade** (`test_reference_bodies`, `test_hurt_capsule`, `test_weapons`): the re-measured bodies within 1 cm of the meshes; the 1.3 m blade; every swing passing the swing check on both bodies.
4. **Controls** (`test_sampling`, `test_controls_table`, `test_profiles`, `test_rebinding`): the grip's defaults in every layout, Ultimate on L2, an old saved profile gaining the grip, rebinding.
5. **Determinism** (`test_state_hash`, `test_save_restore`, the replay test): grip and count in the snapshot and hash; a replay with grip switches reproduces; the committed worst-case bench replay is re-recorded.
6. **Clip choice** (the clip director's tests): the idle, guard and carry clips chosen by weapon and grip; the re-grip transition on a switch.
7. **Balance tools** (`test_soak`, `test_counterlab`): the soak and counterlab run both grips and report them.

The look (the exaggeration, the poses, the held frames) is judged as milestone 1 judges every move: move sheets beside the reference's frame sheets, the per-move checklist, and the owner's review.

## Changes to milestone 1

This spec changes `docs/specs/milestone-1.md` and its plan inside the milestone:

- **Superseded stories:** 51–53 (the four-light pilot and "every cut two-handed": the pilot is still reviewed on today's four lights, which also freezes the protected timings, and then the two five-hit strings replace them with their own review), 54–55 (the Iai and its follow-ups: same controls, Elden Ring's draws, Rising Heaven moved to the two-handed pair), 145 (bodies "not remodelled": re-proportioned), 146 and P44 (the 0.72 m blade: 1.3 m), 38 and P27 (the duelling distances: re-measured).
- **Plan tasks redone or replaced:** 31 and 32 (the four lights, done) are redone as the two strings after the pilot's review (41); 33 (guard idle and bridges), 34 (deflect pairs measured from 2.5 m) and 35 (light reactions) are redone at the new distance and for both grips; 45 (no remodel) becomes the re-proportioning; 47 (Katana model at 0.72 m) takes the 1.3 m blade; 63 and 64 (Iai and heavy re-keys) are replaced by this spec's moves; 65 (heavy reactions) gives its deflect pairs to this plan; 66 (the computer and the Iai) and 127 (the owner's Cascadeur pass) are re-pointed to this plan's Iai and heavies; 120 (the first balance run) waits on this plan's review.
- The plan for this spec (`docs/plans/katana-elden-ring.md`) carries these as tasks and marks the milestone-1 tasks it replaces. The body re-proportioning doesn't wait on milestone 1's Godot check (the owner's word, Oct 6).

## Defaults to confirm

| # | Proposal | Stories |
|---|---|---|
| D1 | The duelling distance becomes about 3.2 m (from 2.5) and the round start ±4.0 m (from ±3.2), the bands re-measured from the re-baked swings; the exact numbers come from the bake. KE task 2 (Oct 7, the owner's choice): 3.0 m and ±3.85 m with today's clips, the computer preferring 2.5 m, every Katana band 0.5 m further out and the light band 5–30 cm deep until the string re-keys; KE task 3 (Oct 7, the owner's choice), on the taller bodies: 3.3 m and ±4.15 m, the computer preferring 2.8 m, every Katana band another 0.3 m out and the light band 4–30 cm deep | 35 |
| D2 | Posture mitigation on a block: two-handed 0.5, one-handed 0.7 (today's single 0.7) | 9 |
| D3 | "Less damage one-handed" is set per move: each one-handed hit deals about 85% of its two-handed counterpart; startups and recoveries come from the clips | 8 |
| D4 | A string ends after hit 5 (no loop back to hit 1); the next light starts hit 1 again | 17–19 |
| D5 | The vertical Iai's heavy follow-up is the current grip's heavy (one-handed heavy, or Rising Heaven); the horizontal Iai keeps Returning Draw (heavy) and the grip's hit 2 (light). KE task 18 (Oct 8, the owner's choice): the horizontal draw is Elden Ring's, from the left hip out to the right, so its light is the grip's hit 3 (which starts on the right), and Returning Draw cuts back from the right to the left | 24, 25, 31 |
| D6 | The grip switch has no rules cost (0 frames, no posture); its only cost is the other grip's trade-offs | 2, 8 |
| D7 | Each round starts one-handed; the grip survives a parry, a block and a knockdown; disarm clears it and the Katana returns one-handed | 6, 16 |
| D8 | The computer goes two-handed when the opponent guards a lot or is close, one-handed at range or when low on posture; Hard and above switch mid-string; tuned by soak | 39, 40 |
| D9 | The grip heavies use the existing charged-heavy rule (released by itself at 2.5 s as a power attack). KE task 16 (Oct 8, the owner's choice): each grip heavy holds its charge at its own pose (the coil over the shoulder, the blade overhead), its clip's hold marker, where the rules check for a held heavy; the Iai keeps frame 9 | 26 |
| D10 | Both bodies scale by 1.15, then shoulders widen about 8% and the head shrinks about 5% toward heroic proportions (about 7.5 heads tall); final numbers set in Blender with the owner. KE task 3 (Oct 7, approved by the owner from the shots): ×1.15, the shoulders 8% wider, the head 95%; the hurt capsule 0.42 m round and 2.0 m tall, the push-apart radius 0.50 m | 34 |
| D11 | The camera's heights scale by 1.15 and its distance by the new duelling distance, so the mood board's framing holds. KE tasks 2 and 3: the distances by 3.3/2.5, the heights by 1.15 | 38 |
| D12 | Fight stick: the grip on its free button (L2 there moves to the stick's spare); player 2's shared keyboard: the grip on a free key of its set, picked in the plan | 13 |
| D13 | The one-handed heavy is named **Crescent Coil** | 24 |
| D14 | Movement attacks and block abilities keep one animation each for both grips | 3 |
| D15 | Mixed-string hand-offs use inertial blending plus two re-grip transition clips (one-to-two and two-to-one), not a bridge per pair of hits | 22 |
| D16 | The strings' last hits are a new move kind with their own timing band (long recovery), so the light band isn't stretched for them | 19 |
| D17 | The owner's Cascadeur pass covers both strings' last hits, both heavies and both Iai draws | 43 |

## Out of Scope

- The Greatsword's one-handed grip and the other weapons' Elden Ring sizes (each in its own milestone).
- Milestone 2's new fighter models on the UE5-style skeleton; this spec only re-proportions today's bodies.
- A grip icon on the HUD.
- Elden Ring's dual wielding (two katanas), its running, rolling and jumping attacks per grip, and a separate weapon-art button.
- Retuning the protected timings, the parry window or the input buffer.

## Further Notes

- The reference reading (contact sheets and 20 fps frame sheets of the video's first 70 seconds) is in `tools/animeref/runs/9sJ2B7crfF8/` on the owner's PC; reference footage is for motion only and never ships or gets committed.
- The blade-length prototype (Right Cut at 0.69 m, 1.0 m and 1.3 m) is on the throwaway branch `prototype/katana-blade-length`; the owner chose 1.3 m from it.
- On Oct 6 the asset repository's `main` lacked the Katana's light reaction exports (they are on its `clips/m1-35-reactions` branch), so a clip build from `master` fails until that branch merges.
