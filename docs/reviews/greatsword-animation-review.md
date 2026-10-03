# The Greatsword's review: authored animation

Oct 3, 2026 · `docs/plans/authored-animation.md` tasks 18–20 · branch `feature/authored-animation` (draft PR Arod231/monomachia#12)

Every Greatsword move now animates from a clip, and its hits are decided by the path baked from that same clip. The sword rides the shoulder while the fighter moves and heaves off it into an attack. This page is the review package, laid out as the Katana's was (`docs/reviews/katana-animation-review.md`). The video and the sheets are local (under `shots/`, which git ignores); everything else is committed. **Your OK on the Greatsword gates the Daggers (task 21).**

## What to look at

- **The before-and-after video:** `shots/greatsword_video.avi`, every Greatsword move on the Hunter, the procedural version from `feature/godot-rebuild` on the left and the clip version on the right, side on, at half speed (`node scripts/move_video.mjs --weapon=greatsword`).
- **Contact sheets of every Greatsword move on both fighters:** `shots/task20/hunter/` and `shots/task20/rogue/`, one sheet per move and the guard (`greatsword_<move>.png`), and `greatsword.png`, every move at its first active frame from the gameplay camera.
- **The shoulder carry:** `shots/task18/carry_walk.png` (walking onto the shoulder after 20 frames, standing, strafing), `carry_lift.png` (Heavy Swing from the shoulder, its 6-frame lift), `carry_guard.png` (the guard raised off it), and `shoulder.png` (the two shoulder poses the packs have).
- **The telegraphs:** `shots/task20/telegraphs/`, Heavy Swing, Overhead Strike, Skewer, Low Sweep, Reaping Sweep and Mountain Slam at the first third of their startups.
- **Per task:** the string and Piercing Lunge on both fighters (`shots/task18/hunter/`, `rogue/`), the movement attacks, Guard Crusher and Counter Lunge (`shots/task19/`).

## Decisions for you

1. **The lunges, again.** As with the Katana, the clips reach less far than the demo's cones, and the spec's answer is a longer lunge in the rules. With its long blade the Greatsword needed less on its string (Heavy Swing 0.4 → 0.45 m), but much more on the moves whose test distances are long: Shoulder Charge 2.2 → 3.35 m (its shoulder gets 0.65 m ahead and its test distance is 4.5 m, which even its cone didn't reach), Reaping Sweep 0.3 → 1.65, Mountain Slam 0.6 → 1.35. The Katana's question (decision 1 of its review) is still open; the Greatsword followed the same rule meanwhile. **Recommended: keep them for now and judge them in play, with the Katana's.**
2. **The clip table changed where the probe showed the named clips don't match their moves**, as it did for the Katana: Attack2H01 is the diagonal from the right shoulder (Heavy Swing) and Attack2H02 the straight overhead (Overhead Strike), the reverse of the table. No two-handed clip cuts left to right, so Backswing is Attack2H01 mirrored, the only mirrored clip so far. Reaping Sweep plays AttackPolearm04 (a whole-body spin, newly added to the manifest) so it reads apart from Low Sweep, and Mountain Slam AttackPolearm03 so it reads apart from Leaping Smash. Rising Edge and Aerial Chop use Kevin's clips where the table named UAL2 ones (side-on and short, or too short to fill the move). Impaler draws back, thrusts and holds on AttackPolearm01 instead of Sprint01 into AttackPolearm03 (Sprint01 swings the arms free through the dash, and Polearm03 is an overhead). **Recommended: keep the new fits.**
3. **Overhead Strike's recovery is 3 frames shorter** (32 → 29): Attack2H02 runs out before the old recovery ends, and stretching it slower would push its startup off. Every other move keeps its frames. **Recommended: accept.**
4. **The Greatsword's win rate is 7 points under its baseline** (39.1% against 46.1%; the soak below). Its clips now cost it nothing (39.1% before them, at the Katana's review), after a fix to the computer opponent's spacing made in this task; the 7 points are what the shoulder carry's 6-frame lift and knockdown cost when they went in (tasks 15–16). The plan wanted this review to win them back, which only a rules or balance change can: a shorter lift (task 15 measured the 6-frame lift at about 6 points, so 4 frames might give back about 2, untested), faster Greatsword startups within its clips' speeds, or more damage or posture on its string. **Recommended: pass the animation as it stands and take the Greatsword's balance as its own small tuning change after the Daggers, measured on 300-match runs.**

## Every move

Frames are startup / active / recovery. The push is the bake's reach correction, played by moving the body above the hips (at most 15 cm). Test distances are the reach table's (the duelling distance 3.0 m for the lights and the dodge attacks, 3.5 for the heavies, 4.0 for the unblockables, 4.5 and 5.5 for the sprint attacks, 3.5 and 5.0 for the back attacks, 2.5 for the jump attacks, 5.0 for the counter lunge).

| Move | Clip (source frames) | Speed | Frames | Lunge before → now (m) | Push (cm) | Rogue plays |
|---|---|---|---|---|---|---|
| Heavy Swing | Attack2H01 from frame 8 | ×1.15 | 14 / 4 / 22 | 0.4 → 0.45 (end 15 → 16) | 2.7 | HumanM |
| Backswing | Attack2H01 mirrored, from frame 8 | ×1.45 | 11 / 4 / 22 | 0.4 → 0.55 | 7.7 | HumanM |
| Overhead Strike | Attack2H02, held raised on the charge frame | ×1.53 | 26 / 5 / 29 (was 32) | 0.7 → 1.05 | 13.1 | HumanM |
| Low Sweep | Attack2H03, wind-round held 5 frames | ×1.08 | 26 / 5 / 34 | 0.8 → 0.85 | 14.5 | HumanM |
| Shoulder Charge | UAL2 Shield_Dash, its crouch held 4 frames; the left shoulder strikes | ×1.20 | 10 / 6 / 20 | 2.2 → 3.35 | 9.3 | her own rig (CC0) |
| Leaping Smash | UAL2 Sword_GroundPound, held raised 4 frames | ×1.00 | 26 / 5 / 32 | 3.0 → 3.15 | 10.5 | her own rig (CC0) |
| Piercing Lunge | AttackPolearm01 | ×1.83 | 12 / 3 / 20 | 0.8 → 1.0 | 0 | HumanM |
| Skewer | AttackPolearm01, pull-back held 4 frames | ×1.36 | 22 / 4 / 28 | 1.0, unchanged | 0 | HumanM |
| Rising Edge | Attack1H05_R, two-handed | ×1.14 | 14 / 4 / 20 | 0.9 → 1.15 | 11.6 | HumanM |
| Lunge Cleave | Attack2H04 | ×1.17 | 24 / 5 / 28 | 2.2 → 2.35 | 10.3 | HumanM |
| Aerial Chop | Attack2H01 from frame 8 | ×1.33 | 12 / 4 / 18 | none | 0 | HumanM |
| Meteor Drop | UAL2 Sword_GroundPound, held raised 2 frames | ×1.10 | 20 / 6 / 30 | none | 15.0 | her own rig (CC0) |
| Reaping Sweep | AttackPolearm04 (the spin), held 4 frames | ×1.04 | 28 / 6 / 28 | 0.3 → 1.65 | 15.0 | HumanM |
| Mountain Slam | AttackPolearm03, held raised 1 frame | ×1.00 | 32 / 5 / 36 | 0.6 → 1.35 | 11.4 | HumanM |
| Guard Crusher | AttackShield01; the left shoulder strikes | ×1.00 | 14 / 5 / 22 | 1.6 → 1.85 | 10.6 | HumanF |
| Counter Lunge | AttackPolearm01 from frame 4 | ×1.75 | 8 / 3 / 22 | from the distance, as before | 0 | HumanM |
| Impaler | AttackPolearm01: drawn back through the aim, thrust on the dash, held through the impale | — | the rules' phases | n/a | n/a | her own |
| The carry | ObjectGripShoulder02_R on the upper body over the legs | — | on after 20 frames moving; the lift 6 | n/a | n/a | her own |

## Moves that share a clip

- **Attack2H01:** Heavy Swing, Backswing (mirrored), Aerial Chop (faster). The Katana's Kesa Cut, Lunging Cut and Moonsplitter play it too.
- **AttackPolearm01:** Piercing Lunge, Skewer (with a held pull-back), Counter Lunge (from frame 4), Impaler. The Katana's Piercing Thrust plays it too.
- **UAL2 Sword_GroundPound:** Leaping Smash, Meteor Drop.
- **Attack2H03:** Low Sweep; the Katana's Whirl Cut and Swallow Sweep.
- **Attack2H02:** Overhead Strike; the Katana's Crown Cut.
- **Attack2H04:** Lunge Cleave; the Katana's Heaven Splitter, Leaping Cleave and Falling Crown.

## What's new under the Greatsword

- **The shoulder carry** (task 18). While the rules have the sword shouldered, the clip director plays ObjectGripShoulder02_R (the Crafting pack's masked pose; 01_R throws the elbow out to the side) on the upper body, faded in over 8 frames, with the legs walking, jogging and strafing under it. An attack from the shoulder crossfades from it into the attack's first frame over its 6-frame lift, which the rules hold, and a guard raised from it fades back to the legs over the same lift. Without the packs nothing shows the carry: no CC0 clip has a shoulder pose.
- **Bashes strike with a shoulder** (task 19). Shoulder Charge and Guard Crusher bake a left-shoulder track (the packs' bashes both lead with it) that strikes with a segment at the joint, 24 cm thick, and the sword rides the clip's hands.
- **Impaler** (task 20) plays through the director as Moonsplitter does. A phase change of either ultimate now crossfades as a follow-up does. No sheet tool plays an ultimate; a director test checks the timing.

## Findings

- **Shoulder Charge's last frames turn the grip over** as the dash clip rises out of its crouch; the director then fades it to the idle.
- **Leaping Smash ends bent low over the planted blade**, the clip's own (Sword_GroundPound), and **Lunge Cleave hops** (Attack2H04 jumps into its slam) while the rules keep the fighter on the ground.
- **The jump attacks play grounded clips in the air**, as the Katana's do: Aerial Chop is Heavy Swing's clip faster, Meteor Drop the ground pound.
- **The sheets' 2.5 m spacing is short for the Greatsword** (its duelling distance is 3.0 m), so the longer lunges carry the attacker into the defender on many sheets; at the real distances they meet the reach rule.
- **PoseCheck fails on nearly every clip frame**, as it does for the Katana (the same recommendation: exempt clip-driven frames from its arm limits).
- **No blade trail** yet (godot-rebuild 18.2–18.3).

## The animation spike critique, checked

As for the Katana (its table holds for the Greatsword too, with these differences):

| Critique | The Greatsword |
|---|---|
| Fix 3: a real coil and release, a held cocked pose | Overhead Strike holds its raised pose on the charge frame; the unblockables hold their telling poses (the held thrust, the wind-round, the spin's start, the raised slam) |
| Fix 5: readable from the gameplay camera; slash, overhead, thrust and sweep apart in the first third | Each at the first third of its startup (`shots/task20/telegraphs/`): Skewer drawn back level at the hip with the knee up, Overhead Strike raised over the head, Low Sweep and Reaping Sweep the whole body wound round, the blade high behind (from the gameplay camera the turned body tells it more than the blade does), Mountain Slam raised high |
| Fix 6: reach measured | Heavy Swing and Backswing 17.5 cm into a defender at 3.0 m, each lunge ending on its first touch; every other move touches from its test distance (`test_duel_reach`, `test_move_reach`) |
| Fix 9: guard walking | The Greatsword has no guard stance; it walks on the shoulder |
| Condition 7: keyed or mocap clips for ultimates | Impaler plays from a clip |

## The soak

A 300-match `soak:tune` with every Katana and Greatsword move on its clip (Oct 3), against the baseline before any rules change (task 3):

| | Now | Before the Greatsword's clips (task 14) | Baseline | Target |
|---|---|---|---|---|
| Greatsword win rate (no mirrors) | 39.1% (45 of 115) | 39.1% | 46.1% | within ±5 points of the baseline: **missed** (−7.0) |
| Katana | 52.3% (68 of 130) | 55.4% | 53.1% | met (−0.8) |
| Daggers | 57.4% (74 of 129) | 54.3% | 50.4% | |
| Rounds | 39.1 s on average, longest 104.0 s | 40.4 s | 39.6 s | 35–60 s: **met** |
| Disarms per round | 0.99 | 1.00 | 1.06 | 0.3–0.6: **out**, as at the baseline |
| Hits, blocks per round | 23.9, 21.9 | 24.2, 22.8 | 25.1, 24.8 | |
| Knockdowns per round | 1.77 | 1.77 | (new, task 16) | |

0 failures in 300 matches.

**Where the Greatsword loses.** The first 300-match run with its clips put it at 33.9%. A per-move count over its 115 matches against the other weapons (with its clips, and again with every move back on its cone, which won 40.9% of the same matches) found the string barely changed (Heavy Swing landed 32% of its swings against 34% on the cone) but the computer opponent fighting closer: it attacks and keeps its distance from the weapon's reach, which had become Heavy Swing's path standing, 2.42 m, where the authored reach is 2.75. The clip reaches less far standing and its lunge was lengthened to make up the difference, so the opponent was keeping a distance 33 cm shorter than the weapon fights from. With the brain's reach put back to 2.75 the same matches won 40.9%, the cones' figure. **The fix (in this task):** a light starter's swing baked from a clip leaves the weapon's authored reach (`WeaponDef.derive_reach()`); a hand-keyed one still gives it. That moves the Katana's from 1.98 to its authored 2.1, which this run includes.

**What is left** is the 7 points the shoulder carry's lift and knockdown cost before any clip (task 15 measured the carry alone at 9.6 points, the lift about 6 of them and the brain's shorter attack reach under the lift about 3.5, and knockdown alone at 4.4). See decision 4.
