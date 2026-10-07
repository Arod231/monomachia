# Plan: an Elden Ring Katana

Spec: `docs/specs/katana-elden-ring.md` · branch `master` · part of milestone 1 (`docs/plans/milestone-1.md`)

## Destination

The Katana plays as Elden Ring's Uchigatana inside milestone 1's realistic look: a 1.3 m blade on fighters about 15% taller, a grip button switching instantly between a one-handed and a two-handed grip, a five-hit light string and a chargeable heavy in each grip, the Iai Slash with Elden Ring's Unsheathe draws, every move re-keyed with Elden Ring's exaggeration and rhythm and landing in its timing and distance bands at the re-measured duelling distance, the computer playing both grips, and the owner's review passed.

## Notes

- **Inside milestone 1.** This plan follows milestone 1's Notes (one task at a time per lane; every task ends with `npm test`, `npm run typecheck`, a commit and a push; rules-data tasks end with a clean 40-match soak; visual tasks end with sheets reviewed and posted; the licence rules; `test_local_` tests for anything that needs the packs; the rules free of graphics). Lanes branch from `master` and open their pull requests into `master`.
- **Milestone 1's pilot review comes first** (the owner's word, Oct 6): the pilot family is reviewed on today's four lights (milestone-1 tasks 40 and 41), which also freezes the protected timings. So the scale change (task 2, and through it 3 and 4) waits on milestone-1 task 41, so the review sees the string at the blade and spacing it was keyed for, and every clip task here waits on it too, for the frozen protected timings, as every other family's clip work does. The grip's rules and view tasks (5–9) don't change what the review plays (both grips play today's lights until the re-keys) and start at once.
- **The bodies don't wait on the Godot check** (the owner's word, Oct 6): re-proportioning today's bodies in Blender (task 3) is needed for the spacing and every re-key, so it isn't held with milestone 1's art conversion (milestone-1 tasks 43–54). The final Katana model stays milestone-1 task 47, now at 1.3 m, behind its gate.
- **Stand-ins until the re-keys.** Task 5 gives both grips today's four lights in order (hit 5 repeats Crown Cut) and task 7 gives the grip heavies today's heavy clips, so the grip plays end to end before any clip is keyed; each re-key task replaces its stand-ins and takes its moves off the band tests' waiting list.
- **Who keys.** Claude's scripted Blender passes (`scripts/blender/rekey_clip.py`, a spec per clip in `scripts/blender/rekeys/`) with the reference's frame sheets beside each move (`tools/animeref/runs/9sJ2B7crfF8/`, on the owner's PC, never committed); the owner's Cascadeur pass (task 21) covers the strings' last hits, both heavies and both Iai draws (D17).
- **Timing.** Startups, gaps and recoveries follow the spec's measured reference table, inside the bands; the protected timings never move. The strings' last hits get their own move kind and timing band (D16), added by the task that keys them.
- **Re-slicing.** The string tasks key two or three hits each, as the pilot did; if the first (task 11) shows a hit costs more than a task can hold, the later ones are re-sliced before they start.
- **Where the work starts.** Once the owner approves this plan (task 1), task 5 can start at once. When it lands, three sessions can run side by side: 6; 7 then 9; and 8. Milestone-1 task 41 (the pilot's review) opens the scale chain, 2 then 3. Once the owner approves task 3's proportions, 4 and 10 can start. Once 10 lands, 11 then 12, 13 then 14, 16, 17 and 18 can run side by side, followed by 15, 19, 20, 21 and 22, then the review (23, 24).
- **Shared files.** Tasks 2, 3 and 4 all rewrite the band tables and the duelling distances; tasks 5, 7 and 9 all touch the fighter's attack rules. Each set runs in one lane, in order, where their blockers don't already order them.
- Use the glossary's terms: Grip, String, Follow-up, Branch point, Charged heavy, Iai Slash (its stance), Timing band, Distance band, Move kind, Transition clip, Deflect pair, Hurt capsule, Strike segment, Swing. A string's fifth hit is its **last hit**, never a finisher.

## Decisions so far

- Oct 6, 2026: the spec (`docs/specs/katana-elden-ring.md`), drafted from the owner's 28-question grilling, approved by the owner with its defaults D1–D17 as written; ADR 0002 records the direction.
- Oct 6, 2026: milestone 1's pilot is reviewed on today's four lights first, and the body re-proportioning doesn't wait on the Godot check (the owner's answers on the plan's breakdown).
- Oct 6, 2026, the blockers audited against `docs/agents/issue-tracker.md` and checked with the Project Manager's parser: every Blocked by line names each task whose result the task uses, the clip tasks name milestone-1 task 41's gate themselves, and milestone-1 tasks 65, 66 and 127, which reached that gate only through the retired 63 and 64, now name it.
- Replaced in milestone 1: task 63 (by task 18) and task 64 (by tasks 17 and 18); re-pointed there: 65, 66 and 127 to this plan's heavies and Iai, 45 and 46 to the new bodies, 120 to this plan's review. Tasks 31–35 stay done; this plan redoes their moves for both grips.

## Progress

- Oct 6, 2026: drafted with the spec (pull request #89); the owner approved the spec and this plan (task 1) and the pull request merged. Task 5 can start; tasks 2 and on wait on milestone-1 task 41 as their blockers say.

## Build order

1. **The owner's approval:** 1
2. **The grip in the rules and on screen:** 5, 6, 7, 8, 9
3. **Scale, after milestone 1's pilot review:** 2, 3, 4
4. **Guards and the strings:** 10, 11, 12, 13, 14, 15
5. **The heavies and the Iai:** 16, 17, 18
6. **Deflect pairs, reactions, polish and sound:** 19, 20, 21, 22
7. **The review:** 23, 24

## Tasks

- [x] **1. The owner's approval of the spec and this plan.** The spec, its defaults D1–D17 and this plan approved.
  - Delivers: the spec's status line and this plan's Progress recording the approval.
  - Check: both files say so on `master`.
  - Blocked by: none · Stories: all
  - **Owner:** approves the spec (given Oct 6) and this plan.
  - Done Oct 6, 2026, approved by the owner: the spec with D1–D17 and this plan, merged into `master` with pull request #89.
- [ ] **2. The 1.3 m blade and the spacing measured from it.** The Katana's blade is 1.3 m, and the duel is spaced for it.
  - Delivers: the code-built Katana (`build_katana`) and its strike segment, blade markers and off-hand marker at a 1.3 m blade; the swings' reach re-derived; the duelling distance, the computer's preferred distance, the round-start positions and the distance band table re-measured from the new reach (D1, about 3.2 m and ±4.0 m); the gameplay camera's distance re-framed for the wider spacing (D11, the distance half); the blade-length test and the distance-band tests updated; the deflect pairs' contacts measured from the new distance.
  - Check: the distance-band, duel-reach and blade-length tests; PoseCheck's blade clearance at the new distance on every Katana move; shots of the duel at rest and at a light's contact beside the blade-length prototype; a clean soak.
  - Blocked by: 1 (and the owner's OK), `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 33, 35, 38
- [ ] **3. Taller fighters.** The Hunter and the Rogue are re-proportioned about 15% taller with heroic proportions.
  - Delivers: both Quaternius bodies scaled by 1.15 and re-proportioned in Blender (D10: shoulders about 8% wider, the head about 5% smaller), exported into the game; the reference bodies, the hurt capsules and PoseCheck's defender capsule re-measured; the swings re-baked once on the new bodies; the camera heights scaled (D11); the wrist tunings, the scars' coordinates and the headwear capsules moved; the distance bands re-measured on the new bodies.
  - Check: the reference-body test within 1 cm of the meshes, the hurt-capsule tests, every swing passing the swing check on both bodies, the band tests; the foot lock on the new ankles; shots of both fighters side by side with today's bodies and with the reference's frame sheets; a clean soak.
  - Blocked by: 2 · Stories: 34, 35, 37, 38
  - **Owner:** approves the proportions from the shots before the re-keys build on them.
- [ ] **4. The Greatsword and the Twin Daggers grow with the bodies.** They keep their look in the taller hands until their own milestones size them.
  - Delivers: both weapons' models, strike segments and markers scaled by the body factor; their swings re-baked; their distance band rows re-measured.
  - Check: their band and reach tests; the blade-length tests at their new lengths; shots of both in the new hands; a clean soak.
  - Blocked by: 3 (and the owner's OK) · Stories: 36
- [ ] **5. Grip state and per-grip strings.** A fighter holds a grip, switches it with the grip button, and its string advances by count in whichever grip it holds.
  - Delivers: a ninth button, the grip, in the rules' input; the fighter's grip and string count, in the snapshot and the state hash; switching at once in every state the fighter can act in and ignored in hitstun, blockstun, knockdown, a jump or a dodge; a weapon's grips declared per grip (its string in order, its heavy branch), the Katana's two strings standing in as today's four lights with Crown Cut repeated as hit 5; a light after a string hit taking the current grip's next hit, so strings mix; a string ending after hit 5 (D4); rounds starting one-handed and the Katana returning one-handed after a disarm (D7); the block's posture mitigation by grip (D2: one-handed 0.7, two-handed 0.5); weapons without grips unchanged.
  - Check: rules tests by scripted input for switching in each allowed state and refusal in the others, both strings, a mixed string carrying the count, hit 5 ending the string, the round start and the disarm reset, two-handed blocks gaining less posture; the state-hash, save-and-restore and replay tests with grip switches; every weapon's existing string tests unchanged; a clean soak.
  - Blocked by: 1 (and the owner's OK) · Stories: 1, 2, 3, 4, 5, 6, 9, 10, 16, 44
- [ ] **6. Grip controls and screens.** Every layout can switch grip, and the screens teach it.
  - Delivers: the grip action on pad Y with the pad's Ultimate moved to L2, keyboard R (Ultimate staying on Q and U), a free button on the fight stick and a free key in player 2's shared-keyboard set (D12); saved control profiles gaining the grip at its default; rebinding; the controls screen, the move list (both grips' strings and heavies) and How to play showing it; the README's controls.
  - Check: the binding, profile, rebinding and controls-screen tests; an old saved profile loading with the grip added; shots of the controls screen, the move list and How to play.
  - Blocked by: 5 · Stories: 11, 12, 13, 14, 15
- [ ] **7. Grip heavies in the rules.** A light's heavy branch starts the current grip's heavy, and the grip heavies charge.
  - Delivers: Crescent Coil (D13), the one-handed heavy, and the two-handed pair (Heaven Splitter, then Rising Heaven as its follow-up), on stand-in clips (today's heavy clips); each string hit's heavy branch going to the current grip's heavy; charging both by holding heavy under the charged-heavy rule (D9); heavy from neutral staying the Iai Slash in both grips; the vertical Iai's heavy follow-up the current grip's heavy and the horizontal Iai keeping Returning Draw and the grip's hit 2 (D5).
  - Check: rules tests by scripted input for each heavy branch in each grip, the charge and the power attack, the Iai's follow-ups in both grips, heavy from neutral still the Iai; a clean soak.
  - Blocked by: 5 · Stories: 23, 24, 25, 26, 27, 31, 32
- [ ] **8. Per-grip clips in the view.** The idle, the guard and the way the weapon is carried follow the grip.
  - Delivers: the clip director choosing the idle, the guard and the carry layer by weapon and grip (stand-ins: today's guard idle for both until task 10); a hook for the two re-grip transition clips on a switch (D15); the Twin Daggers' reverse grip renamed in the view so "grip" means only the rules' grip.
  - Check: director tests of the picks by weapon and grip and of the transition on a switch; the weapon-in-hand test through a switch; shots of a switch.
  - Blocked by: 5 · Stories: 7, 22
- [ ] **9. The computer plays both grips.** It switches grips by situation and mixes them mid-string at the harder levels.
  - Delivers: the brain's grip choice (D8: two-handed when the opponent guards a lot or is close, one-handed at range or when low on posture) and mid-string switches at Hard and above; grip heavies from the branches; the soak and the counterlab reporting each grip; the soak's expectations and the worst-case bench replay re-recorded for the new random draws.
  - Check: seeded tests that it switches in each situation and mixes a string at Hard; the soak and counterlab reports by grip; the bench replay test; a clean soak.
  - Blocked by: 5, 7 · Stories: 39, 40, 42
- [ ] **10. The per-grip guards and the re-grip transitions.** Each grip has its own guard idle and carry, and the off hand joins or leaves the grip in a short clip.
  - Delivers: the one-handed guard idle and carry (the blade low at the side, as in the reference) and the two-handed guard idle and carry (task 33's, re-keyed on the new bodies with the longer blade), and the two re-grip transition clips (one-to-two, two-to-one), by Claude's scripted pass, exported, imported and wired into task 8's picks.
  - Check: the weapon-in-hand test through both guards and both transitions; PoseCheck's blade clearance; sheets of both guards and a switch each way beside the reference's idle frames; posted.
  - Blocked by: 3 (and the owner's OK), 8, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 7, 22, 34
- [ ] **11. One-handed hits 1 and 2.** The diagonal cut down and the backhand rising cut.
  - Delivers: both re-keyed from pack clips with Elden Ring's wide wrapping wind-ups, snap strikes and held poses, at the reference's rhythm (the first landing about 24–27 frames from rest, about 49–57 frames between hits), inside the light band, connecting from the new distance band; markers and branch points set; the table regenerated; both off the waiting list and replacing the stand-ins in the one-handed string.
  - Check: the timing-band, distance-band and free-frame tests; PoseCheck's foot slide and blade clearance; the weapon-in-hand test; sheets of both, both sides, beside the reference's frame sheets; a clean soak.
  - Blocked by: 2, 3 (and the owner's OK), 5, 10, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 17, 20, 21
- [ ] **12. One-handed hits 3, 4 and 5.** The rising twist, the horizontal cut and the overhead last hit into a deep crouch.
  - Delivers: as task 11 for the three hits; the last hit as a new move kind with its own timing band for its long recovery (D16), with the band row and its test.
  - Check: as task 11; the string-continuity test across all five; the last hit inside its new band.
  - Blocked by: 2, 3 (and the owner's OK), 5, 11, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 17, 19, 20, 21
- [ ] **13. Two-handed hits 1 and 2.** The overhead diagonal and the rising cut from the left.
  - Delivers: as task 11 for the two-handed string, tighter and quicker (the first landing about 21–23 frames from rest, about 37–41 frames between hits), about 15% more damage than the one-handed counterparts (D3).
  - Check: as task 11.
  - Blocked by: 2, 3 (and the owner's OK), 5, 10, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 8, 18, 20, 21
- [ ] **14. Two-handed hits 3, 4 and 5.** The rising cut from the right, the second overhead diagonal and the vertical last hit into a kneel.
  - Delivers: as task 12 for the two-handed string.
  - Check: as task 12.
  - Blocked by: 2, 3 (and the owner's OK), 5, 13, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 18, 19, 20, 21
- [ ] **15. Both strings' bridges and the mixed hand-offs.** Each string flows hit to hit, and a mixed string flows across the grips.
  - Delivers: the bridges between each string's hits as transition clips (as milestone-1 task 33 did for four lights); the mixed hand-offs through inertial blending and the re-grip transitions (D15); any hit whose start side breaks a mixed string's continuity re-keyed.
  - Check: the string-continuity test for both strings and for every mixed pair (one-handed hit n into two-handed hit n+1 and back); the free-frame test across mixed hand-offs; sheets of two mixed strings beside the reference.
  - Blocked by: 10, 12, 14 · Stories: 5, 21, 22
- [ ] **16. Crescent Coil.** The one-handed heavy: the blade coiled over the shoulder, a loop low and up, and a wide horizontal cut held at full extension.
  - Delivers: the re-key with its charge loop (the held coil growing to the power attack), inside the string-heavy band, from the heavy branches' distance; the stand-in replaced.
  - Check: band and distance tests for the tapped and charged release; rules tests of the charge on the clip; sheets beside the reference; a clean soak.
  - Blocked by: 2, 3 (and the owner's OK), 7, 10, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 24, 26
- [ ] **17. Heaven Splitter and Rising Heaven.** The two-handed pair: the held overhead, the lunge into a deep crouch, and the rising follow-up from the crouch.
  - Delivers: both re-keyed, Heaven Splitter with its charge loop, Rising Heaven as its optional follow-up from the crouch, in their bands; the stand-ins replaced.
  - Check: band and distance tests; rules tests that Rising Heaven is optional; the string-continuity test into and out of the pair; sheets beside the reference; a clean soak.
  - Blocked by: 2, 3 (and the owner's OK), 7, 10, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 25, 26
  - Replaces: `docs/plans/milestone-1.md` task 64
- [ ] **18. The Iai Slash with Elden Ring's draws.** The sheathe and stance as before; the horizontal a quick flat draw held at full extension, the vertical a deep coil and a rising draw; each ending in a chiburi and a resheathe; Returning Draw re-keyed.
  - Delivers: what milestone-1 task 63 delivered (the sheathe, the stance loop and its strafe at the clip's speed, both draws picked by the stick, the drift from the draw's travel, the held release at 2.5 s) with Elden Ring's draw shapes and timing (the flat draw about 18–20 frames, the coiled draw about 24), the chiburi and resheathe, and Returning Draw; the same in both grips, a switch in the stance applying to what follows the draw.
  - Check: band tests for the tapped and stance draws; the Iai's distance-band test at the new distance; rules tests of the release, the stance speed and a switch in the stance; sheets beside the reference's Unsheathe frames; a clean soak.
  - Blocked by: 2, 3 (and the owner's OK), 7, 10, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 28, 29, 30, 31, 32
  - Replaces: `docs/plans/milestone-1.md` task 63
- [ ] **19. Deflect pairs for both strings and the grip heavies.** Each new attack direction has its deflect pair at the new distance.
  - Delivers: deflect pairs (the parrier's deflect and the attacker's recoil) for every new string hit and grip heavy, measured from the new duelling distance, as Claude's block-outs (milestone-1 task 34's method); the pairs of today's four lights retired.
  - Check: the director's deflect picks; the state-clip fit test; blades meeting at the contact point on sheets; a clean soak.
  - Blocked by: 2, 3 (and the owner's OK), 12, 14, 16, 17, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 10, 21
- [ ] **20. Light hit and block reactions for the new strings.** The defender reacts by the new strings' directions and heights at the new distance.
  - Delivers: milestone-1 task 35's light hit and block reactions re-keyed or re-picked for the two strings' directions, on the new bodies.
  - Check: director tests of the picks for every hit of both strings; the state-clip fit test; sheets reviewed.
  - Blocked by: 3 (and the owner's OK), 12, 14, `docs/plans/milestone-1.md` task 41 (and the owner's OK) · Stories: 21
- [ ] **21. The owner's Cascadeur pass.** The owner polishes the signature moves, and the polished clips replace Claude's passes.
  - Delivers: both strings' last hits, Crescent Coil, Heaven Splitter and Rising Heaven, and both Iai draws polished (D17), exported to the asset repository and imported; markers checked; the table regenerated.
  - Check: their band, distance and continuity tests pass on the polished clips; sheets reviewed.
  - Blocked by: 12, 14, 16, 17, 18 · Stories: 43
  - **Owner:** polishes the moves in Cascadeur.
- [ ] **22. Sound and effects for the new moves.** The new swings, impacts, the re-grip, the chiburi and the resheathe sound and show.
  - Delivers: sound-bank entries for every new swing and impact by grip, the re-grip, the chiburi and the resheathe; the effect table's rows for them (air smears on the snap strikes, sparks on the deflect pairs).
  - Check: sound-bank and effect-table tests for every new event; shots reviewed.
  - Blocked by: 10, 12, 14, 16, 17, 18 · Stories: 20
- [ ] **23. The review package.** Everything the owner needs to judge the Elden Ring Katana as a player would.
  - Delivers: contact sheets of both strings, both heavies and the Iai beside the reference's frame sheets; the per-move checklist rows for every new move; a play build with the licensed clips; a 300-match `soak:tune` reporting both grips; the spec's stories ticked as delivered.
  - Check: the package complete; every check green.
  - Blocked by: 6, 9, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22 · Stories: 41, 42
- [ ] **24. The owner's review.** The owner plays the Elden Ring Katana and gives a verdict.
  - Delivers: the verdict recorded in Decisions so far; any changes it asks for as new tasks.
  - Check: the verdict recorded.
  - Blocked by: 23 · Stories: all
  - **Owner:** plays and reviews the Katana.
