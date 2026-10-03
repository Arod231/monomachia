> Research notes from the Oct 1, 2026 task breakdown, a snapshot of the code at 51dcfb0.
> The plan (`docs/plans/godot-rebuild.md`) is the source of truth: its task ids, order and decisions
> supersede the proposals and keys here. Line numbers drift as the code changes.

# Plan tasks 9, 10 and 11: the new Katana, Greatsword and Twin Daggers strings, plus the move-data fields side_start/side_end (with the continuity test), charge_move, release_variant and lunge_along_dodge (dodge_cancel_from on heavies belongs to task 8; see open questions)

## Current state
Main checkout at 51dcfb0 (feature/godot-rebuild). Task 8 has not started, so everything below is still the faithful port.

Move schema (game/sim/moves/attack_def.gd)
- AttackDef has no side_start, side_end, charge_move, release_variant or lunge_along_dodge.
- dodge_cancel_from already exists, with an UNSET sentinel. Only lights use it today, plus the dodge lights Wind Cut, Ghost Cut and Slip Jab.
- KEYS must list the script's properties in order (test_moves.gd asserts this), and from_dict push_errors on unknown keys.
- finalize_moves still gives lights 18 hitstun, which task 8 changes to 14.

Katana (game/sim/moves/katana.gd)
- k_l1 Right Cut: chains to k_l2 (light) and k_h1f (heavy).
- k_l2 Return Cut: chains to k_l3 and k_h1f.
- k_l3 is Crown Cut today (overhead 14/4/22, heavy follow-up k_h2). There is no Kesa Cut light and no fourth light.
- heavy_start is k_h1 Kesa Giri: diagDown, 22/4/26, 13/16, chargeable, chains to k_l2 and k_h2.
- k_h1f Rising Heaven is 18/4/24; the spec wants 16.
- k_h2 Heaven Splitter is 24/4/28; the spec wants 22.
- There is no Iai and no Returning Draw.

Greatsword (greatsword.gd)
- g_l1 chains to g_l2 and g_h2.
- g_l2 has startup 13 (the spec wants 11) and chains to g_h2.
- heavy_start g_h1 Crushing Blow: diagDown, 26/5/32, 18/22, chargeable, chains to g_h2 and to the light g_l2.
- g_h2 Earthbreaker: overhead 30/5/34.
- g_dl is Pommel Strike (bash) and g_dh is Cyclone (spin).

Daggers (daggers.gd)
- d_l1 to d_l4 already alternate hands. d_l2 is hand L with anim slashRL, and StickPose mirrors it into a left-to-right cut.
- dodge_cancel_from is 13, 13 and 16 on d_l1 to d_l3, and unset on d_l4.
- d_l3 chains to d_h1 as a heavy.
- d_h1 Twin Fang has lunge 0.8 and chain_light d_l1 (the loop the spec removes).
- d_h2 "Gutting Spiral" already has the Spinning Backhand numbers (18/5/22, 12/10).
- d_dl is Ghost Cut (6/2/12, 5/4, lunge 0.4).

Fighter (game/sim/fighter.gd)
- Chains: in _update_attack a follow-up is queued once f > S (not while block is held) and starts at f >= S+A+2.
- Charging:
  - CHARGE_CHECK_FRAME = 9 (line 51, checked at line 633). Holding heavy at frame 9 freezes the attack and calls _brake().
  - Release, or CHARGE_MAX 150, ends the charge. charge_frac scales damage and adds up to 16 recovery frames.
  - The frames after release continue from 10 to S.
- Dodge cancel: f >= dodge_cancel_from with DODGE buffered.
- Lunge:
  - Goes along fwd(yaw), with a min-gap clamp on the whole step (about line 660).
  - start_attack keeps 30% of velocity (line 601; task 8 makes it 50%).
- Dodge follow-ups:
  - They come from _context_attack inside MOVE_FOLLOW_WINDOW.
  - The dodge direction is forgotten when the dodge ends, because set_state clears DodgeState.
- _integrate orbits the opponent only in the free and step states.
- Moonsplitter's stick rule is "dir != -1 and |mx| > |my| means horizontal" (_ult_moonsplitter, about line 1124).
- Sheathed fighters already can't block: the attack state isn't guard-capable.

Input and AI
- InputTracker (game/sim/input_tracker.gd) needs no change: mx, my, dir, is_held and buffered cover everything here.
- AIBrain (game/sim/ai/ai_brain.gd):
  - Its charged-heavy branch holds heavy for 30–160 frames with the stick zeroed, so it will play a vertical Iai standing still.
  - _perceive ignores charging attacks and compares AttackState by identity.
  - _respond_to reaches range + lunge + 0.6 and answers counter kinds (the jump answers a sweep).
  - TrainingBrain "heavies" taps heavy, then heavy again 34 frames later.
- None of these need changes for 9–11; task 12 teaches the brain the Iai.

Presentation
- view/match/stick_pose.gd maps each anim to an ARCH archetype.
- Every archetype the new moves need already exists (slashRL, slashLR, diagDown, diagUp, overhead, thrust, sweep, spin/spinBoth, doubleStab, cross).
- While charging it holds the wind-up key; there is no sheathe pose.
- No HUD, menu or sound code names moves: the sound bank keys on the event's weapon, heavy and sound fields.
- The waiting branches don't touch game/sim/moves.

Tests that name these moves
- test_combat.gd: the three-light string k_l1..k_l3 (line 46), and the auto-release test that expects k_h1 at 13×1.8 (line 55).
- test_moves.gd: compares all 67 moves with the TS fixture tests/fixtures/moves.json, checks KEYS order, and checks that k_l1 is 30 frames in total.
- test_regressions.gd: the charged-heavy trade, and k_l2 being refused when disarmed.
- test_stick_pose.gd: the d_l2 mirror test.
- The TS-parity suites (goldens, test_ai_parity with its TRAINING_TS dummy hashes that include katana heavies, and test_port_regressions' traces patched on k_l1) record the demo rules. Task 8 is expected to retire them.

Surprises
- With one side per move, the spec's continuity rule can't hold. Greatsword Overhead Strike follows both Heavy Swing (ends left) and Backswing (ends right). Daggers Twin Fang follows both Quick Slice and Off-hand Slice.
- The spec's "14 / 4 / 24 after release" for the Iai only fits the charge code if the data startup is 23 (a 9-frame sheathe plus a 14-frame draw).

## Tasks

### [9] katana-four-lights (M): Katana four-light string, string sides and the continuity test
- delivers: AttackDef gains side_start and side_end (StringName, &"" when unset; AttackDef.SIDES = left, right, center), appended to KEYS and from_dict | New game/tests/sim/test_string_continuity.gd over a list of rebuilt weapons (katana for now): every chain target exists in the same weapon, every chain source and target has both sides, values are in SIDES, and each target starts on the source's side_end or at center | Kesa Cut becomes k_l3: right-shoulder-to-left-hip diagonal (anim diagDown), 11/3/17, 7/8, light follow-up k_l4, heavy follow-up k_h2; cone range 2.2, arc 100, lunge 0.35 | Crown Cut moves to k_l4: 14/4/22, 8/10, end of string (its old heavy follow-up k_h2 is removed) | Right Cut's heavy follow-up becomes Heaven Splitter (k_h2); Return Cut stays → Kesa Cut / Rising Heaven (the L-L-H) | Rising Heaven 16/4/24 (lunge_end 18) and Heaven Splitter 22/4/28 (lunge_end 24) | Sides on every katana string move: Right Cut R→L, Return Cut L→R, Kesa Cut R→L, Rising Heaven R→L, Crown Cut and Heaven Splitter center; Kesa Giri R→L until the next task removes it | The spec's Move data records the side values and the continuity rule
- check: New game/tests/sim/test_katana_strings.gd: a light every 8 frames hits with k_l1, k_l2, k_l3, k_l4 in order | Same file: L-L-H ends on Rising Heaven, L-H on Heaven Splitter, L-L-L-H on Heaven Splitter | Same file: a light pressed during Crown Cut queues nothing, and Crown Cut runs to its last frame | Same file: stopping after any hit returns the fighter to free at that move's S+A+R | Same file: frames, damage, posture and follow-ups of the five light-string rows match the spec table | test_string_continuity passes for the katana and reports a deliberately broken synthetic chain | test_combat.gd's string test is updated; test_moves.gd's KEYS-order test passes | npm test and npm run typecheck pass
- depends: 8
- stories: 16, 17, 18, 25
- files: game/sim/moves/attack_def.gd, game/sim/moves/katana.gd, game/tests/sim/test_string_continuity.gd, game/tests/sim/test_katana_strings.gd, game/tests/sim/test_combat.gd, game/tests/sim/test_moves.gd, docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md
- notes: Kesa Cut's light dodge cancel isn't in the spec. Recommended: dodge_cancel_from 20 (S+A+6, as k_l1 and k_l2). test_moves.gd compares all 67 moves with the TS fixture and counts them. Task 8's hitstun change already breaks that test, so task 8 should retire it. If it hasn't, narrow it here to the moves the new strings leave unchanged and drop the count. Keep the existing ids for moves whose role stays; k_l3 = Kesa Cut, k_l4 = Crown Cut.

### [9] katana-iai-slash (S): Iai Slash (vertical) replaces Kesa Giri as the Katana heavy
- delivers: The katana's heavy_start becomes Iai Slash (vertical), recommended id k_iai; Kesa Giri (k_h1) is removed | Frames: startup 23 (the 9-frame sheathe up to CHARGE_CHECK_FRAME plus the 14-frame draw), active 4, recovery 24 | Numbers: 13 damage / 16 posture, chargeable, type overhead, anim overhead | Cone and lunge: range 3.6, arc 60, lunge 0.4 from frame 9 (after release) | Heavy follow-up Rising Heaven; sides left→right | Holding heavy keeps it sheathed through the existing charge (atk.charging) and auto-releases at CHARGE_MAX as a power attack; no fighter code changes yet (the fighter still stands while sheathed) | The spec table notes how the Iai's frames are counted (23 = sheathe + draw)
- check: test_katana_strings: a tapped heavy emits the swing at attack frame 23 and hits with k_iai | Same file: hold 60 frames then release, and the hit lands on the 15th step counting the release step (14 draw frames) | Same file: hold 220 frames and it releases by itself for 13×1.8 damage (test_combat.gd's auto-release test now expects k_iai) | Same file: the Iai hits at 3.8 m centre to centre, where Right Cut whiffs | Same file: a sheathed fighter holding block takes the opponent's light as a hit (no block event) | Same file: Iai → heavy gives Rising Heaven | Same file: the Iai's late recovery accepts a dodge (task 8's heavy rule) | test_regressions.gd's charged-heavy trade still passes; continuity passes | npm test and npm run typecheck pass
- depends: katana-four-lights
- stories: 26, 29
- files: game/sim/moves/katana.gd, game/tests/sim/test_katana_strings.gd, game/tests/sim/test_combat.gd, game/tests/sim/test_regressions.gd, docs/specs/godot-rebuild.md
- notes: The charge freezes atk.frame at 9 and resumes at 10 on release, so data startup 23 gives exactly 14 frames after release; a tap draws 23 frames after the press. The AI's held-heavy branch (ai_brain.gd _pick_attack) now plays a standing vertical Iai; _respond_to's reach grows with range 3.6. Both are acceptable until task 12.

### [9] katana-iai-stance-walk (M): Walk while sheathed (charge_move) and dodge to cancel the stance
- delivers: AttackDef.charge_move (bool) in KEYS and from_dict; k_iai.charge_move = true | While a charge_move attack charges, the fighter walks at block speed in any stick direction instead of braking: _locomotion gets a guard-speed parameter applying MOVE_BLOCK_SPEED_MULT with no sprint or step | _integrate's strafing orbit also applies while sheathed | A buffered dodge while sheathed cancels the stance into a dodge | Other chargeable heavies (Greatsword, Daggers, bare hands) keep standing still
- check: With the stick right, the sheathed fighter's lateral speed settles within 2% of MOVE_RUN_STRAFE × MOVE_BLOCK_SPEED_MULT, and the distance to the opponent stays within 1 cm over 60 frames | With the stick forward, it closes at the block-speed forward rate | Holding sprint doesn't raise the speed | There's no walking during the 9-frame sheathe | Dodge while sheathed gives a dodge event and the dodge state, with no swing or hit | Dodge pressed during the draw (after release) does not cancel | A greatsword charged heavy still brakes and ignores dodge while charging | npm test and npm run typecheck pass
- depends: katana-iai-slash
- stories: 26
- files: game/sim/moves/attack_def.gd, game/sim/moves/katana.gd, game/sim/fighter.gd, game/tests/sim/test_katana_strings.gd
- notes: Edit the charging branch of _update_attack (fighter.gd around lines 633-649), _locomotion (419) and _integrate's keep-distance condition (848). The charge turn rate (3 rad/s in _update_facing) covers block-speed strafing at duelling range (about 0.84 rad/s). The block-speed number comes from task 8 (0.6).

### [9] katana-iai-release-variant (S): Horizontal Iai by stick at release (release_variant)
- delivers: AttackDef.release_variant (StringName) in KEYS and from_dict | New move Iai Slash (horizontal), recommended id k_iai_h: right-to-left draw, anim slashRL, 23/4/24, 13/16, cone range 3.6, arc 110, sides right→left | k_iai.release_variant = k_iai_h | When the stance ends with the stick left or right (dir != -1 and |mx| > |my|, Moonsplitter's rule), atk.def becomes the variant. The stance ends on release, on auto-release, or when a tap reaches CHARGE_CHECK_FRAME without heavy held | The swap keeps the same AttackState (frame, charge_frac, extra_recovery, started_by)
- check: Release with the stick right, and with it left, hits with k_iai_h; neutral, forward and back hit with k_iai | A tap with left held gives k_iai_h | Auto-release with left held gives a k_iai_h power attack (13×1.8) | Strafing right while sheathed, then releasing, gives the horizontal | The swing event names the variant | Data test: every release_variant names a move of the same weapon with the same startup, active and recovery | npm test and npm run typecheck pass
- depends: katana-iai-stance-walk
- stories: 27, 29
- files: game/sim/moves/attack_def.gd, game/sim/moves/katana.gd, game/sim/fighter.gd, game/tests/sim/test_katana_strings.gd, game/tests/sim/test_moves.gd, docs/specs/godot-rebuild.md
- notes: After the swap, refresh the local def in _update_attack: S, A and R are read after the charging block, and the lunge and swing code read def. Keep the AttackState object: the AI tracks attacks by identity (_seen_atk).

### [9] katana-iai-followups (S): Iai follow-ups: Returning Draw and the horizontal Iai's chains
- delivers: New move Returning Draw, recommended id k_rdraw: left-to-right heavy slash, anim slashLR, 16/4/24, 12/15, cone range 2.4, arc 90, lunge 0.5, sides left→right, end of string | k_iai_h follow-ups: Returning Draw (heavy) and Return Cut (light); k_iai → Rising Heaven → Heaven Splitter | A full katana spec-table test | Plan task 9 ticked
- check: Horizontal Iai → heavy gives Returning Draw, and a further heavy doesn't chain | Horizontal Iai → light → light gives Return Cut, then Kesa Cut | Vertical Iai → heavy → heavy gives Rising Heaven, then Heaven Splitter | Pressing nothing after either Iai returns to free at S+A+R plus the charge recovery | All nine katana rows of the spec table match the data | test_string_continuity passes for every katana chain | npm run soak:godot -- 10 finishes with no errors | npm test and npm run typecheck pass
- depends: katana-iai-release-variant
- stories: 28, 16, 17
- files: game/sim/moves/katana.gd, game/tests/sim/test_katana_strings.gd, docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md

### [9] katana-iai-standin-pose (S): Stand-in sheathe pose and anim coverage for the new moves
- delivers: StickPose holds a sheathe pose while a charge_move attack charges (both hands by the left hip, blade back and down), instead of the wind-up key, and the draw blends out of it | test_stick_pose.gd checks that every move of the katana, greatsword and daggers names an anim present in StickPose.ARCH | A new iai_stance shot in tools/shot_scenes/skeleton_shot.gd (plus .tscn) steps the seeded Duel until the katana fighter is sheathed
- check: test_stick_pose: the sheathed right hand is left of centre and below 1.1 m, with the blade pointing backwards and the pose different from the overhead wind-up | The anim coverage test passes | Screenshots of the stance, a vertical draw and a horizontal draw are reviewed by eye | npm test and npm run typecheck pass
- depends: katana-iai-release-variant
- stories: 26, 27
- files: game/view/match/stick_pose.gd, game/tests/view/test_stick_pose.gd, game/tools/shot_scenes/skeleton_shot.gd, game/tools/shot_scenes/skeleton_iai.tscn
- notes: Stand-in only; task 15 builds the real sheathe. Later greatsword and daggers tasks must keep the anim coverage test green by using existing archetypes.

### [10] greatsword-lights-and-overhead (S): Greatsword momentum lights into Overhead Strike (the L-L-H)
- delivers: g_l1 Heavy Swing: heavy follow-up is now g_h1; sides right→left | g_l2 Backswing: startup 13 → 11 (lunge_end 12, dodge_cancel_from 23), heavy follow-up g_h1, sides left→right | g_h1 becomes Overhead Strike: overhead, anim overhead, 26/5/32, 18/22, chargeable, heavy follow-up g_h2; its light follow-up g_l2 is removed; sides center→right | Earthbreaker (g_h2) gets temporary sides center→center until the next task | The continuity test's weapon list adds the greatsword
- check: New game/tests/sim/test_greatsword_strings.gd: L-L-H hits with g_l1, g_l2, g_h1 | Same file: Backswing's swing event comes 11 frames after it starts, against Heavy Swing's 14 | Same file: heavy from neutral starts Overhead Strike, and holding it charges while standing still | Same file: a light during Overhead Strike starts no Backswing | Same file: stopping after any hit returns the fighter to free | Same file: these three rows match the spec table | Continuity passes for the greatsword | npm test and npm run typecheck pass
- depends: 8, katana-four-lights
- stories: 31, 18, 16, 17
- files: game/sim/moves/greatsword.gd, game/tests/sim/test_greatsword_strings.gd, game/tests/sim/test_string_continuity.gd, docs/specs/godot-rebuild.md
- notes: Task 8's colossal recovery slide applies to every greatsword swing; nothing to add here. Keep g_h1's hitstop 9.

### [10] greatsword-low-sweep (S): Overhead Strike into the unblockable Low Sweep
- delivers: g_h2 becomes Low Sweep (Earthbreaker is removed): sweep, anim sweep, 26/5/34, 16/22 | Low Sweep is unblockable and jumpable with counter sweep; cone range 3.2 (beyond the lights' 3.0), arc 110 (narrower than Reaping Sweep's 160); sides right→left
- check: test_greatsword_strings: Overhead Strike → heavy gives Low Sweep and a telegraph event (kind sweep, attack g_h2) | Same file: a defender holding block is hit | Same file: a defender in the air at contact triggers the leap counter | Data assertions: Low Sweep startup < g_sweep startup, arc < g_sweep arc, range > g_l1 range | Continuity passes | npm test and npm run typecheck pass
- depends: greatsword-lights-and-overhead
- stories: 32, 22, 41
- files: game/sim/moves/greatsword.gd, game/tests/sim/test_greatsword_strings.gd, docs/specs/godot-rebuild.md
- notes: start_attack emits the telegraph for chained moves too. The AI already jumps sweeps through _respond_to. Counterlab only drives abilities, so task 12 covers Low Sweep there.

### [10] greatsword-dodge-thrusts (S): Greatsword dodge attacks become thrusts (Piercing Lunge and Skewer)
- delivers: g_dl becomes Piercing Lunge: blockable stab (type stab, anim thrust), 12/3/20, 8/10, cone range 3.0, arc 50, lunge 0.8 | g_dh becomes Skewer: unblockable thrust (counter thrust), 22/4/28, 14/18, cone range 3.4, arc 36, lunge 1.0, track_active 0.5 | Plan task 10 ticked
- check: test_greatsword_strings: dodge then light gives Piercing Lunge, and a blocking defender gets a block event | Same file: dodge then heavy gives Skewer, with a telegraph of kind thrust, and a blocking defender is hit | Same file: a defender dodging forward into Skewer gets the stomp counter | Same file: Skewer's range exceeds the lights' range | All six greatsword rows of the spec table match the data | npm run soak:godot -- 10 finishes with no errors | npm test and npm run typecheck pass
- depends: greatsword-lights-and-overhead
- stories: 33, 22
- files: game/sim/moves/greatsword.gd, game/tests/sim/test_greatsword_strings.gd, docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md

### [11] daggers-alternating-string (S): Daggers alternating four-light string and the dodge cancel from first recovery
- delivers: Sides: d_l1 R→L, d_l2 L→R, d_l3 Twin Rip and d_l4 Flurry Finisher center, d_h1 and d_h2 center | Twin Rip loses its heavy follow-up (per the spec table) | dodge_cancel_from becomes each light's first recovery frame: d_l1 10, d_l2 10, d_l3 13, d_l4 15 | The continuity test's weapon list adds the daggers
- check: New game/tests/sim/test_daggers_strings.gd: four lights hit with d_l1, d_l2, d_l3, d_l4, with hands R, L, both, both | Same file: L-L-H gives Twin Fang | Same file: a heavy during Twin Rip queues no follow-up | Same file: dodge pressed in Quick Slice's active frames leaves the fighter attacking on attack frame 9 and dodging on frame 10, both after a hit (through hit-stop) and after a whiff | Same file: the four rows match the spec table | Continuity passes for all three weapons; test_stick_pose's d_l2 mirror test still passes | npm test and npm run typecheck pass
- depends: 8, katana-four-lights
- stories: 35, 36, 16, 18
- files: game/sim/moves/daggers.gd, game/tests/sim/test_daggers_strings.gd, game/tests/sim/test_string_continuity.gd, docs/specs/godot-rebuild.md
- notes: Keep d_l2 on anim slashRL with hand L: StickPose mirrors it into a left-to-right cut. The input buffer survives hit-stop, because the tracker frame doesn't advance.

### [11] daggers-twin-fang-backhand (S): Twin Fang dash into Spinning Backhand, with the light loop removed
- delivers: d_h1 Twin Fang: lunge 0.8 → 1.4 m; chain_light d_l1 removed; heavy follow-up stays d_h2 | d_h2 is renamed Spinning Backhand (numbers unchanged: 18/5/22, 12/10) | Flurry Finisher keeps its heavy follow-up into Spinning Backhand
- check: test_daggers_strings: a light pressed in Twin Fang's follow-up window starts no Quick Slice before Twin Fang ends | Same file: Twin Fang → heavy gives Spinning Backhand, and four lights then heavy also give Spinning Backhand | Same file: Twin Fang moves the attacker about 1.4 m toward an opponent 4 m away | Same file: rows match the spec table | Continuity passes | npm test and npm run typecheck pass
- depends: daggers-alternating-string
- stories: 37, 17
- files: game/sim/moves/daggers.gd, game/tests/sim/test_daggers_strings.gd

### [11] daggers-passing-cut (M): Passing Cut lunges along the dodge direction (lunge_along_dodge)
- delivers: AttackDef.lunge_along_dodge (bool) in KEYS and from_dict | Fighter remembers its last dodge direction (set in start_dodge), and start_attack copies it into new AttackState lunge-direction fields for lunge_along_dodge moves | _update_attack lunges along that direction, clamping only the part of each step that closes on the opponent | d_dl becomes Passing Cut (replacing Ghost Cut): 6/2/12, 5/4, lunge 1.2 m over frames 1–8, lunge_along_dodge, dodge_cancel_from 9 | Plan task 11 ticked
- check: test_daggers_strings: dodge right then light gives Passing Cut, and the attacker moves about 1.2 m along the dodge direction (sideways relative to the opponent); dodge left moves left | Same file: a forward dodge then light stops at the minimum gap | Same file: a light just after the dodge ends (inside MOVE_FOLLOW_WINDOW) still uses that dodge's direction | Same file: the Katana's Wind Cut still lunges along its facing | Same file: all seven daggers rows match the spec table | npm run soak:godot -- 10 finishes with no errors | npm test and npm run typecheck pass
- depends: daggers-alternating-string
- stories: 38, 36
- files: game/sim/moves/attack_def.gd, game/sim/moves/daggers.gd, game/sim/attack_state.gd, game/sim/fighter.gd, game/tests/sim/test_daggers_strings.gd, docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md
- notes: Build on task 8's eased lunge. The current clamp (fighter.gd, lunge block around line 660) limits the whole step, which would stall a sideways cut at close range. Backsteps and backward dodges still give the back light (Flick), so Passing Cut only comes out of forward or side dodges.

## Open questions
- Continuity with one side per move fails: Greatsword Overhead Strike follows moves ending left and right, and so does Daggers Twin Fang. Recommended: sides are left, right or center. A move starting at center (overheads, thrusts, stabs, spins, the crossing cut) may follow any end; a left or right start must match the previous end exactly. The alternative is to let side_start be a list.
- How should the Iai's frames be counted? Recommended: data startup 23 = the existing 9-frame sheathe (CHARGE_CHECK_FRAME) plus the 14-frame draw. A held Iai then draws 14 frames after release, and a tapped heavy draws 23 frames after the press. Note this under the spec table.
- Iai direction rule: recommended Moonsplitter's rule (stick out of the dead zone and |mx| > |my| means horizontal). It's read on the frame the stance ends: release, auto-release, or frame 9 for a tap. Diagonals with |mx| = |my| count as vertical.
- 'Reach about 3.6 m': recommended cone range 3.6, the same measure as the lights' 2.2 (attacker centre to target surface), plus a 0.4 m lunge after release. Task 7 re-derives it from the swing.
- When can a dodge cancel the Iai? Recommended only while sheathed and held (charging), not during the 9-frame sheathe or once the draw starts. Task 8's heavy rule still covers late recovery.
- Who owns the heavy dodge cancel? Recommended: task 8, as a finalize_moves default for heavies (dodge_cancel_from = S + A + ceil(R/2) when unset). Every new heavy here then inherits it, and these tasks only test it.
- Daggers dodge cancel: the table puts 'from the first recovery frame' on Quick Slice only, while story 36 says any light. Recommended: all four lights and Passing Cut cancel from their first recovery frame (d_l1 10, d_l2 10, d_l3 13, d_l4 15, d_dl 9).
- Twin Rip: the table drops its current heavy follow-up into Twin Fang. Recommended: follow the table, so the L-L-H stays Off-hand Slice → Twin Fang.
- Kesa Cut's light dodge-cancel frame isn't in the spec. Recommended 20 (S+A+6, as the other katana lights).
- Move ids:
- - Recommended: keep the ids of moves whose role stays (k_l1, k_l2, k_h1f, k_h2, g_l1, g_l2; g_h1 as Overhead Strike, g_h2 as Low Sweep; g_dl, g_dh, d_*).
- - Make k_l3 Kesa Cut and k_l4 Crown Cut.
- - Add k_iai, k_iai_h and k_rdraw, and remove Kesa Giri.
- Interim cone numbers until task 7. Recommended:
- - Low Sweep: range 3.2, arc 110.
- - Skewer: 3.4 / 36 / lunge 1.0.
- - Piercing Lunge: 3.0 / 50 / 0.8.
- - Iai horizontal: arc 110.
- - Returning Draw: 2.4 / 90.
- - Passing Cut: lunge 1.2 m.
- Piercing Lunge type: recommended stab (blockable), so 'thrust' keeps meaning the unblockable counter shape in the data and the move list.
- Continuity test scope: recommended the three playable weapons only. Bare hands are unchanged and out of scope.

## Risks
- Task 8 must retire the TypeScript-parity suites, or the first katana task fails them: test_moves.gd's 67-move fixture comparison, the goldens, test_ai_parity (including the TRAINING_TS dummy hashes, which play katana heavies) and test_port_regressions' traces patched on k_l1.
- Release-variant swap: _update_attack caches def at its top. If the local def isn't refreshed after the swap, the first draw frames use the vertical's numbers. The AttackState must be kept, not rebuilt, because the AI compares attacks by identity.
- Sheathed strafing will drift outward unless _integrate's orbit is extended beyond the free and step states. The slow 3 rad/s charge turn could then leave the draw's cone off target.
- The Iai's 3.6 m cone and two unblockables in normal Greatsword strings shift balance and the AI's reaction ranges. A 10-match soak per weapon only catches crashes; tuning waits for tasks 7 and 12.
- Passing Cut: the existing lunge clamp limits the whole step, so a sideways lunge at close range would stall unless only the closing part is clamped.
- d_l2 must keep anim slashRL with hand L. StickPose mirrors it into a left-to-right cut; switching to slashLR would reverse it and break test_daggers_left_hand_moves_mirror_the_right.
- These tasks extend code that task 8 rewrites: the lunge easing, the momentum carry and the block-speed constant. Start them only after task 8 is merged, not in parallel with it.
- Cone numbers chosen here are temporary: task 7 replaces hit cones with weapon paths. The spec must mark them as interim so they aren't mistaken for tuned values.
