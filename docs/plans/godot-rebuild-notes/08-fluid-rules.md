> Research notes from the Oct 1, 2026 task breakdown, a snapshot of the code at 51dcfb0.
> The plan (`docs/plans/godot-rebuild.md`) is the source of truth: its task ids, order and decisions
> supersede the proposals and keys here. Line numbers drift as the code changes.

# Plan task 8: Fluid combat rules (arena radius 15 m and the values tied to it, blocking walk 60%, momentum carry 50%, eased lunges, light hitstun 14, heavy dodge-cancel in the second half of recovery, the colossal recovery slide, retiring the golden replays and the TypeScript soak comparison)

## Current state
The rules in game/sim still match the TypeScript bit for bit. Neither waiting branch touches game/sim: fighters-and-weapons (f061145..fcfb8d8) and the uncommitted look-and-arena worktree have no rules changes, so task 8 can start on feature/godot-rebuild without merging them first.

**Values tied to the radius**
- game/sim/constants.gd:21 `ARENA_RADIUS = 11.5`.
- world.gd:178-184 `_clamp_arena` already uses `ARENA_RADIUS - FIGHTER_RADIUS`.
- world.gd:569 dropped-weapon bounce already uses `ARENA_RADIUS - 0.8`.
- **Hard-coded:** fighter.gd:1170, the Impaler dash ends at `r > 10.8` (= 11.5 - 0.7).
- **Not named by the spec:**
  - world.gd:44 `WAVE_RANGE = 26`. The demo sized it to cross a 23 m arena: the mvp-spec says the Moonsplitter "crosses the whole stage". At radius 15 the largest gap between fighters is 29.16 m, so the wave would die short.
  - game/tools/soak.gd:126 fails a match with "left the arena" when `hypot > 12.0` (scripts/soak.ts:89 does the same). This must change in the same commit as the radius, or every soak reports false failures.
- **Camera (game/view/match/camera_rig.gd):**
  - `arena_limit()` is already `ARENA_RADIUS + arena_margin` (4.0); only the doc comment (line 106, "15.5 m") is stale.
  - `menu_radius` 10.5 was sized for the old arena, but a 10.5 m orbit still sits inside a 15 m one.
  - standin_arena.gd builds from `ARENA_RADIUS`, so it follows.
  - test_camera_rig.gd:99-102 and test_match_scene.gd:184/194 read `SimConst`, so they follow too.
- **AI:** ai_brain.gd and training_brain.gd have nothing tied to the radius.
  - The ultimate distance gates (14, 12, 10 m), sprint above 8 m and back-off below 3.5 m are distances between the fighters, not to the wall.
  - The brain has no wall awareness.
  - Fighter._integrate's strafe-orbit cap (`keep < 9.0`) and the spawns (±3.2 in World.reset_round) are not tied to the radius either.
- **look-and-arena (task 17):** ArenaDef has `walkable_radius 15.0` and `camera_max_radius 19.5`. Its test asserts the literal 15.0 instead of `SimConst.ARENA_RADIUS`; that is the "radius check" waiting on task 8.

**The other rule values**
- **Block walk:** constants.gd:84 `MOVE_BLOCK_SPEED_MULT = 0.45`, read in Fighter._locomotion (fighter.gd:442-443).
- **Momentum:** fighter.gd:599-602 `vel *= 0.3` in start_attack (not for airborne or hop moves).
  - While an attack runs, `_brake` multiplies velocity by 0.8 every frame, so carried speed fades fast.
  - Keeping 0.5 means about v/24 m of extra travel (v/40 at 0.3); at sprint speed that is 0.30 m instead of 0.18 m. (Corrected in plan task 8.5: the brake skips the step an attack starts on.)
- **Lunge:** fighter.gd:657-667 moves a flat share per frame (`lunge_total / (le - ls)`), clamped so the gap never drops below `2*FIGHTER_RADIUS + 0.25`. The window defaults to `le = S + A`. `SimMath.ease_in_out` (quadratic) and `ease_out_cubic` already exist; the dodge uses `ease_out_cubic`.
- **Dodge cancel:** fighter.gd:704-708 applies only where `dodge_cancel_from` is set. Today only lights have it (for example k_l1 20, g_l1 26, d_l1 13); no heavy does.
- **Hitstun:** attack_def.gd:189-191 `finalize_moves` gives lights 18. Fists f_l1 and f_l2 set 16 themselves; no other light sets its own.
- **Slide:** no colossal slide exists. WeaponDef.cls is `&"colossal"` only for the Greatsword.

**Light hitstun 14 does not free every weapon's second hit.** A chained light starts at attack frame S+A+2.
- **Katana:** Return Cut lands 15 frames after Right Cut's hit. With 14 the defender gets exactly one free frame; with 18 the hit is guaranteed.
- **Greatsword:** today's Backswing lands at 19, already blockable. The new 11/4/22 Backswing lands at 17.
- **Daggers:** lights 2 and 3 land 11 and 13 frames after the previous hit, so they stay guaranteed even at 14.
- **Fists:** the second hit lands at 10 against the fists' own 16, so it also stays guaranteed.

**Tests pinned to the TypeScript, which the first rule change breaks**
- game/tests/sim/test_golden_replay.gd: 35 goldens in game/tests/golden/.
- test_ai_parity.gd: the match-golden input replay plus the TRAINING_TS input hashes.
- test_port_regressions.gd:
  - the clampArena fixture, which sits on the 11.08 m clamp circle;
  - the whole-run duel and aiMatch hashes;
  - six sentinel traces (`_check_patched`) that compare the attacker's position and so break at the eased lunge.
- test_moves.gd compares every move against fixtures/moves.json, which breaks on the hitstun and dodge-cancel defaults.
- tests/golden.test.ts (the web tests) reads game/tests/golden, so deleting the goldens also breaks `npm test:web` unless it goes too.

**Tests that stay valid:**
- the JsMath bit-for-bit, deadzone, JS-format and soak-runner tests;
- test_math and test_rng;
- the 47 ported rule tests: none depends on the radius or on hitstun timing.

**Soak:** game/tools/soak.gd claims output identical to `npx tsx scripts/soak.ts`. CI runs only `npm test`, no soak.

**Other:** the spec already states the new numbers (15 m, 60%, half, 14). It words the lunge two ways: "ease in and out" in the decisions table and "ease out" in the rule list.

## Tasks

### [8] dummy-and-counter-behaviour-tests (S): Behaviour tests for the training dummy and the computer's counters, before the TypeScript hashes go
- delivers: game/tests/sim/test_training_brain.gd (new); each behaviour runs against an opponent at practice distance (2.2 m Katana, 2.6 m Greatsword, 1.8 m Daggers, from TrainingBrain.think): | - idle presses nothing; | - block holds BLOCK every frame; | - lights throws Right Cut, Return Cut and Crown Cut (k_l1 to k_l3) every 110-frame cycle; | - heavies throws a heavy, with the heavy follow-up every other cycle; | - thrust, sweep and slam put the matching ability on the light slot and send a telegraph event of that counter kind; | - random cycles through lights, heavies and each counter kind the weapon has; | - fight hands control to the sparring AIBrain. | A counter test built like game/tools/counterlab.gd: the dummy repeats each unblockable against a hard AIBrain set to always try the counter (counter 1, parry/dodge/block/aggression/guard 0); in 60 s it lands at least one stomp, one leap and one evade counter. | These replace the TRAINING_TS input hashes in test_ai_parity.gd, which pin the dummy to the TypeScript and break on the first rule change.
- check: The new tests pass on today's rules, which still match the TypeScript. | npm test and npm run typecheck pass.
- depends: 6
- stories: 41, 53, 60
- files: game/tests/sim/test_training_brain.gd, game/sim/ai/training_brain.gd, game/sim/ai/ai_brain.gd, game/tools/counterlab.gd
- notes: Assert on events and states only (swing or telegraph events, f.blocking, f.abilities), never on input hashes. Reset hp, posture and KO each frame as counterlab and test_ai_parity._run_dummy do.

### [8] retire-ts-reference (M): Record the demo baselines, then retire the golden replays and the other TypeScript-pinned checks
- delivers: Before deleting anything, at the current commit: | - `npm run soak -- 40` and `npm run soak:godot -- 40` print identical reports; | - counterlab, TypeScript (`npx tsx scripts/counterlab.ts`) and Godot (`node scripts/godot.mjs script res://tools/counterlab.gd`), print identical tallies. | Paste both outputs into the plan as the demo-rules baseline, with the commit hash where the port was last proven (and a tag if the owner agrees). | Delete: | - game/tests/golden/ (35 recordings, index.json, README.md); | - game/tests/sim/test_golden_replay.gd and test_ai_parity.gd, with their .uid files; | - tests/golden.test.ts (it reads game/tests/golden); | - scripts/golden/record.ts and the golden:record npm script. | test_port_regressions.gd: | - remove test_the_arena_clamp_uses_math_hypot (fixture on the 11.08 m circle) and the two whole-run hash tests (duel, aiMatch); | - rewrite the six _check_patched sentinel tests as behaviour asserts (hit count, hp, posture, state on given frames, whether the attacker moved), taking the expected values from today's traces in fixtures/port.json; | - keep the JsMath, deadzone, JS-format and soak-runner tests. | scripts/port-fixtures.ts stops writing the clampArena, duel, aiMatch and sentinels sections; regenerate with `npm run godot:fixtures` (the remaining sections come out byte-identical). | Text updates: | - soak.gd and counterlab.gd headers say their output matched the TypeScript up to the recorded commit and now report on the Godot rules alone; | - the spec's 'Faithful port first' and Testing Decisions, and the plan's Decisions line about the goldens, move to the past tense.
- check: Before the deletions, the two soak reports and the two counterlab tallies match line for line. | After the deletions: | - npm test and npm run typecheck pass; | - the Godot test count drops by the 35 replays, the guard test, the 2 parity tests and the 3 removed port tests, and the web count by the golden replay file; | - `npm run soak:godot -- 40` still prints exactly the baseline (no rule touched yet); | - searching the repo for game/tests/golden finds nothing outside git history.
- depends: dummy-and-counter-behaviour-tests
- stories: 60, 61, 62
- files: game/tests/golden/ (deleted), game/tests/sim/test_golden_replay.gd (deleted), game/tests/sim/test_ai_parity.gd (deleted), game/tests/sim/test_port_regressions.gd, game/tests/fixtures/port.json, scripts/port-fixtures.ts, scripts/golden/record.ts (deleted), tests/golden.test.ts (deleted), package.json, game/tools/soak.gd, game/tools/counterlab.gd, docs/plans/godot-rebuild.md, docs/specs/godot-rebuild.md
- notes: Why a separate, rules-neutral commit:
- The first rule change (the radius) breaks the goldens, the brain parity and the clampArena fixture.
- The eased lunge later breaks the whole-run hashes and the sentinel traces.
- Retiring them all at once keeps each later commit about one rule.

The soak comparison with the TypeScript ends here. From now on soak:godot is compared, by eye, only with the recorded baseline; balance targets belong to task 12. `npm run soak` keeps running the web demo until task 26.

test_moves.gd's comparison with moves.json stays: it is data, and it still guards the moves the new strings leave alone. Each later data change adds rows to a table of deliberate differences (see open questions).

### [8] arena-radius-15 (M): Arena radius 15 m, with every value the demo tied to 11.5 m
- delivers: game/sim/constants.gd: ARENA_RADIUS 11.5 -> 15.0, plus a named Impaler wall margin of 0.7 (the demo's 10.8 = 11.5 - 0.7). The dropped weapon's 0.8 gets a name too. | game/sim/fighter.gd:1170 (_ult_impaler) `r > 10.8` becomes `r > ARENA_RADIUS - margin`. | game/sim/world.gd: | - _clamp_arena and _update_weapons already follow the constant; | - WAVE_RANGE 26 becomes 2 * ARENA_RADIUS + 3 (33 m) if approved, so the Moonsplitter still crosses the whole stage. | game/tools/soak.gd:126 'left the arena' check becomes `hypot > ARENA_RADIUS + 0.5`. | game/view/match/camera_rig.gd: fix the arena_margin doc comment (19 m without arena data). No code change; standin_arena.gd already builds from the constant. | New game/tests/sim/test_fluid_combat.gd, section 'arena': | - backing away from an opponent at the centre carries a fighter past 12 m (beyond the old 11.08 clamp) and stops their centre at exactly ARENA_RADIUS - FIGHTER_RADIUS (14.58); | - a weapon dropped by a victim near the wall (World.spawn_dropped_weapon, attacker at the centre) never passes ARENA_RADIUS - 0.8 and comes to rest inside; | - an Impaler dash past a target held above 1.5 m (so it never makes contact) stops at ARENA_RADIUS - 0.7, beyond 10.8, before its 40 frames run out; | - if approved, a vertical Moonsplitter hits a target 28 m away. | Spec, 'Rule changes after the port': add the wave range decision.
- check: The new tests pass. | test_camera_rig and test_match_scene pass unchanged (they read SimConst). | npm test and npm run typecheck pass. | `npm run soak:godot -- 40` reports 0 failures; note the average round length against the baseline. | Screenshots of the stand-in arena (`npm run shots -- res://tools/shot_scenes/skeleton_round_start.tscn` and skeleton_watch.tscn) show the wall ring at 15 m, reviewed by eye.
- depends: retire-ts-reference
- stories: 15, 30, 34, 62
- files: game/sim/constants.gd, game/sim/fighter.gd, game/sim/world.gd, game/tools/soak.gd, game/view/match/camera_rig.gd, game/tests/sim/test_fluid_combat.gd, docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md
- notes: No AI change: ai_brain.gd and training_brain.gd hold no radius-tied values. Spawns stay at ±3.2.

This unblocks task 17's radius check: ArenaDef.walkable_radius must equal SimConst.ARENA_RADIUS, and look-and-arena's test_arena_def.gd asserts the literal 15.0, which should become the constant.

The Impaler test can hold the defender up by setting its pos.y each step from the input callable, as test_regressions' wave test writes a.hp.

### [8] block-walk-60 (S): Blocking walk at 60% of running speed
- delivers: constants.gd:84 MOVE_BLOCK_SPEED_MULT 0.45 -> 0.6 (read in Fighter._locomotion). | test_fluid_combat.gd, section 'block walk': holding block and forward at a 6 m gap settles at MOVE_RUN_FORWARD * speed_mult * 0.6 (2.34 m/s for the Katana, 2.106 for the Greatsword at speed_mult 0.9). | Strafing while blocking settles at MOVE_RUN_STRAFE * speed_mult * 0.6. | Holding block still blocks sprinting.
- check: The new test passes. | test_holding_block_while_standing_drains_posture_faster_than_while_moving... still passes (its moving threshold is 0.3 m/s). | npm test and npm run typecheck pass. | Soak: 0 failures.
- depends: retire-ts-reference
- stories: 14
- files: game/sim/constants.gd, game/tests/sim/test_fluid_combat.gd
- notes: Task 9's sheathed Iai stance strafes 'at block speed', so it reuses this constant.

### [8] momentum-carry-half (S): Attacks keep half of the current velocity
- delivers: New SimConst.ATTACK_MOMENTUM_KEEP = 0.5 replaces the 0.3 in Fighter.start_attack (fighter.gd:599-602). Airborne and hop attacks still keep their full velocity. | test_fluid_combat.gd, section 'momentum': | - running toward a far opponent (10 m gap, about 30 frames to reach full speed), the step a light starts leaves exactly half the previous step's horizontal speed; | - the attacker then travels about v/24 m further than a standing attacker (the 0.8-per-frame brake during the attack); | - a jump attack keeps its velocity.
- check: The new test passes. | npm test and npm run typecheck pass. | Soak: 0 failures.
- depends: retire-ts-reference
- stories: 16, 19, 20
- files: game/sim/constants.gd, game/sim/fighter.gd, game/tests/sim/test_fluid_combat.gd
- notes: On the step an attack starts, try_actions runs inside _update_free before _locomotion, and _update_attack's brake hasn't run yet. So velocity on that step is exactly 0.5 * v, and the assert can be exact.

### [8] eased-lunges (S): Lunges ease in and out
- delivers: Fighter._update_attack (fighter.gd:657-667): each frame moves (ease(t1) - ease(t0)) * lunge_total over (lunge_start, lunge_end], using SimMath.ease_in_out, instead of the flat lunge_total / (le - ls). | Same total distance, same window and the same min-gap clamp (2 * FIGHTER_RADIUS + 0.25). | The clamped forward step becomes a helper that the colossal slide reuses. | test_fluid_combat.gd, section 'lunge': | - Kesa Giri (k_h1: 0.6 m over frames 8-24) against an opponent too far to reach moves in steps that rise then fall (first and last smaller than the middle one) and add up to 0.6 m; | - a lunge into a defender inside its reach still stops 0.25 m clear of their body.
- check: The new tests pass. | The existing combo, range and counter tests pass. | npm test and npm run typecheck pass. | Soak: 0 failures.
- depends: retire-ts-reference
- stories: 19
- files: game/sim/fighter.gd, game/sim/sim_math.gd, game/tests/sim/test_fluid_combat.gd, docs/specs/godot-rebuild.md
- notes: The spec says 'ease in and out' in one place and 'ease out' in another (see open questions). Fix the wording in the same commit.

The shadow step has its own path and is not a lunge. The counter lunge's distance-based lunge_total is eased the same way.

Task 7 tunes lunge lengths and ends (0.7-0.8 m, front foot landing on the contact frame); this task changes only the per-frame profile.

### [8] light-hitstun-14 (S): Light hitstun 14 frames, so a defender can parry the second hit
- delivers: AttackDef.finalize_moves (attack_def.gd:189-191): the default hitstun for lights goes 18 -> 14. The fists' own 16 on f_l1 and f_l2 stays. | test_moves.gd gets a table of deliberate differences from the demo data: a light the TypeScript gives the default 18 now has 14. The rest of moves.json keeps guarding the unchanged moves. | test_fluid_combat.gd, section 'hitstun': | - Right Cut hits an idle Katana defender; the defender presses block as hitstun ends (the frame is found with a probe run, like test_one_block_press_parries_one_hit_not_a_whole_flurry); Return Cut is then parried (parry event, the attacker recoils), where it was guaranteed at 18; | - every light without its own hitstun has 14.
- check: The new tests pass. | test_moves passes with the deviation table. | npm test and npm run typecheck pass. | Soak: 0 failures.
- depends: retire-ts-reference
- stories: 24, 41
- files: game/sim/moves/attack_def.gd, game/tests/sim/test_moves.gd, game/tests/sim/test_fluid_combat.gd, docs/specs/godot-rebuild.md
- notes: The Katana leaves exactly one free frame (the second hit lands 15 frames after the first). The guard press is buffered for 2 frames and only registers once the defender is guard-capable, so press 1-2 frames before hitstun ends.

Daggers and fists keep guaranteed early follow-ups (see open questions); record that gap in the spec rather than changing it here.

### [8] heavy-dodge-cancel (S): Heavies can be dodge-cancelled in the second half of their recovery
- delivers: finalize_moves gives every kind=heavy move without its own dodge_cancel_from the frame S + A + ceil(R / 2). | If approved, Fighter._update_attack (fighter.gd:704-708) also: | - shifts the cancel frame by half of atk.extra_recovery (rounded up), so a charged heavy's extra recovery stays half punishable; | - refuses the cancel while airborne (jump heavies). | Abilities, specials and ultimates get no cancel. The test_moves deviation table gains the heavies' dodge_cancel_from. | test_fluid_combat.gd, section 'heavy dodge cancel': | - Kesa Giri whiffed at a far target: a dodge pressed only in the first half of recovery doesn't cancel and the attack runs to its end; a dodge pressed in the second half starts a dodge at once (dodge event, state dodge); | - the same after a blocked heavy; | - a charged heavy's cancel opens later by half its extra recovery; | - Mountain Slam (g_slam, an ability) still can't be cancelled.
- check: The new tests pass. | npm test and npm run typecheck pass. | Soak: 0 failures. The brain doesn't use the cancel yet (task 12).
- depends: retire-ts-reference
- stories: 23
- files: game/sim/moves/attack_def.gd, game/sim/fighter.gd, game/tests/sim/test_moves.gd, game/tests/sim/test_fluid_combat.gd, docs/specs/godot-rebuild.md
- notes: The input buffer is 8 frames (SimConst.INPUT_BUFFER). A dodge pressed up to 8 frames before the cancel frame still fires at it, so the 'no cancel' case must press earlier than that.

A queued chain starts at S+A+2, before the cancel check, so follow-ups win.

Tasks 9-11's new heavies get the default automatically.

### [8] colossal-recovery-slide (M): Colossal swings end with a short recovery slide
- delivers: SimConst slide constants (recommended: 0.35 m over the first 10 recovery frames, eased out). | In Fighter._update_attack, when moveset().cls == &"colossal" (only the Greatsword today), every grounded move except bashes slides forward along the facing during those first recovery frames: | - on a hit, a block or a whiff; | - through the eased-lunge helper's min-gap clamp; | - ending with the attack state (dodge cancel, chain, stun, parry recoil). | test_fluid_combat.gd, section 'slide': | - a whiffed Heavy Swing (g_l1) moves the attacker about 0.35 m during recovery, while a whiffed Katana Right Cut moves none; | - the slide stops short of a defender standing in front; | - g_l1's light dodge-cancel at frame 26 cuts the slide off; | - a jump attack and a bash (Shoulder Charge, Pommel Strike, Guard Crusher) don't slide. | Spec: record the numbers under 'Rule changes after the port' and in the Greatsword note.
- check: The new tests pass. | npm test and npm run typecheck pass. | Soak: 0 failures; note the Greatsword's win rate against the baseline.
- depends: eased-lunges, heavy-dodge-cancel
- stories: 20
- files: game/sim/constants.gd, game/sim/fighter.gd, game/tests/sim/test_fluid_combat.gd, docs/specs/godot-rebuild.md
- notes: The spec says 'in the swing's direction', but swings don't exist until task 7. Until then the facing at the start of recovery stands in (recovery tracking is 0.5 rad/s, so it barely turns); task 7 switches it to the swing's exit direction.

The spec doesn't list a slide test; this one is added.

### [8] fluid-rules-soak-closeout (S): Soak and counterlab on the finished fluid rules, record the drift, tick task 8
- delivers: `npm run soak:godot -- 40` and the Godot counterlab on the finished rules, compared with the baseline from retire-ts-reference: round length, parries, counters, disarms and ultimates per round, and wins by weapon. | The new numbers and the drift go into the plan's Progress; tuning toward the spec targets waits for task 12. | The spec's 'Rule changes after the port' and Testing Decisions list every rule as built, with the answers to this area's open questions. | Task 8 is ticked in the plan.
- check: Soak: 0 failures (no NaN, no fighter outside the arena, posture in range, every match finishes inside the 12-minute limit). | Counterlab still reaches stomp, leap and evade. | test_main_flow plays the Duel from title to results. | A skeleton_exchange screenshot of the stand-in Duel, reviewed by eye. | npm test and npm run typecheck pass.
- depends: arena-radius-15, block-walk-60, momentum-carry-half, eased-lunges, light-hitstun-14, heavy-dodge-cancel, colossal-recovery-slide
- stories: 59, 62
- files: docs/plans/godot-rebuild.md, docs/specs/godot-rebuild.md, game/tools/soak.gd, game/tools/counterlab.gd
- notes: If any rule task already showed a soak failure, it was fixed there. This task only compares numbers and closes task 8. Tasks 9-11 start after it.

## Open questions
- Moonsplitter wave range (the spec is silent): WAVE_RANGE = 26 m was sized for the 23 m-wide demo arena, and the mvp-spec says the wave 'crosses the whole stage'. On a 15 m radius the farthest two fighters can stand apart is 29.16 m. Recommend tying it to the arena (2 * ARENA_RADIUS + 3 m = 33 m, the same margin as the demo's 26) inside arena-radius-15, with a test at 28 m.
- Lunge easing: the spec's decisions table says 'lunges ease in and out', but its rule list says 'lunges ease out'. Recommend ease in and out with the existing SimMath.ease_in_out: same distance and window, a slow start in the wind-up and a settle at contact, which fits the spike's 'front foot lands on the contact frame'. Fix the spec wording.
- Heavy dodge-cancel details: (a) does a charged heavy's extra recovery count? Recommend yes: the cancel opens at the middle of the actual recovery, so charging stays a commitment. (b) Airborne jump heavies? Recommend no cancel in the air, since the demo has no air dodge. (c) Abilities like Mountain Slam? Recommend excluded: the spec says heavies, and they are the counter targets. Rounding: open from S + A + ceil(R / 2).
- Colossal slide: the spec gives no distance, frames or direction, and says only 'all swings'. Recommend 0.35 m over the first 10 recovery frames, eased out, along the facing until task 7 provides swing directions. It would apply to every grounded Greatsword move except bashes (abilities included), on a hit, a block or a whiff, and stop at the lunge's min gap. Constants in SimConst rather than a per-move field, because the spec's list of new move fields has none.
- Light hitstun 14 frees the Katana's second hit (by one frame) and the Greatsword's, but not the Daggers' second and third lights (they land 11 and 13 frames after the previous hit). Bare hands keep their own 16 (second hit at 10). That contradicts the spec's 'from the second hit on a defender can block or parry'. Recommend implementing 14 as specified, testing it on the Katana, and recording in the spec that the Daggers' early hits stay guaranteed; tasks 11 and 12 then decide, for example hitstun 10 on dagger lights. Ask the owner whether the Daggers' guaranteed early hits are wanted.
- Should the fists' explicit hitstun 16 drop too? Recommend no: the spec changes only the default.
- Mark the last bit-exact commit with a tag (for example v0.2-godot-port) before the goldens are deleted? It would be pushed to the public repo, so it needs the owner's OK. Recommend yes; otherwise record the commit hash in the plan and spec.
- test_moves.gd: keep comparing with the demo's moves.json plus a table of deliberate differences, or drop the comparison? Recommend keeping it. It guards the many moves the spec says stay unchanged (sprint, dodge and jump attacks, abilities, fists); task 8 adds two rows (light hitstun, heavy dodge_cancel_from), and tasks 9-11 add theirs.
- Delete scripts/golden/record.ts and tests/golden.test.ts with the recordings, or keep the recorder? Recommend deleting all three together. The web test can't pass without the files, and git history plus the tag keep them.
- Camera menu orbit (camera_rig.gd menu_radius 10.5, centre (0, 0, -1)) was sized for the 11.5 m arena. Recommend leaving it in task 8 (it still sits inside the 15 m floor) and letting task 17's ArenaDef camera data and task 22's title screen set it.

## Risks
- Retiring the goldens removes the bit-exact safety net. After that, an accidental rule change is caught only by the behaviour tests and the soak. Mitigation: the behaviour tests for the dummy and counters land first, the baseline soak and counterlab outputs are kept in the plan, and the proven commit is tagged or recorded.
- The soak's 'left the arena' check (soak.gd:126, a hard-coded 12.0) reports a failure for every fighter past 12 m. It must change in the same commit as ARENA_RADIUS, or soak:godot fails for the wrong reason.
- A larger arena may lengthen rounds. The AI has no wall awareness, backs off when closer than 3.5 m, and disarmed fighters fetch weapons from further away. Watch the average round length and 'did not finish' (12-minute limit) in each soak.
- Light hitstun 14 doesn't fully deliver the spec's promise: Daggers' early follow-ups and bare-hand hits stay guaranteed. If it isn't recorded, tasks 11 and 12 inherit a hidden contradiction.
- Exact-frame tests are easy to get wrong: one free frame in the Katana parry test, the 8-frame input buffer in the dodge-cancel test, and hit-stop freezing the world. Find frames with a probe run, as test_one_block_press_parries_one_hit_not_a_whole_flurry does, rather than hard-coding step numbers.
- Momentum carry, eased lunges and the slide shift where fighters stand at contact under the demo's range-and-arc cones, so ranges move slightly before task 7 replaces the cones. The existing tests have margin, and the soak shows drift.
- The slide's direction (the facing) stands in for the swing direction until task 7, so that task must revisit it.
- Merge order: the plan says merge task 13 first. It conflicts only in the plan and spec, and neither waiting branch touches game/sim. But look-and-arena's test_arena_def.gd asserts walkable_radius == 15.0 as a literal, which should become SimConst.ARENA_RADIUS once arena-radius-15 lands.
- Deleting tests/golden.test.ts lowers the web test count. Anyone comparing the plan's recorded counts (112 web, 382 Godot) will see drops; record the new counts in the plan when retiring.
