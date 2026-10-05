# Bare hands' review: authored animation

Oct 3, 2026 · `docs/plans/authored-animation.md` tasks 24–25 · branch `feature/authored-animation` (draft PR Arod231/monomachia#12)

Every bare-hands move now animates from clips: the punches (task 24), the kicks and Breaker Palm (task 25). Each move's hits are decided by the path baked from the same clip, the striking fist, foot or (for the Flying Knee) knee. This page is the review package, laid out as the other weapons' were (`docs/reviews/katana-animation-review.md`, `greatsword-animation-review.md`, `daggers-animation-review.md`). The video and the sheets are local (under `shots/`, which git ignores); everything else is committed. **Your OK on bare hands gates the reactions and movement (task 26).**

## What to look at

- **The before-and-after video:** `shots/fists_video.avi`, every bare-hands move on the Hunter, the procedural version from `feature/godot-rebuild` on the left and the clip version on the right, side on, at half speed (`node scripts/move_video.mjs --weapon=fists`).
- **Contact sheets of every move on both fighters:** `shots/task25/hunter/` and `shots/task25/rogue/`, one sheet per move and the guard.
- **The punch clips side by side:** `shots/task24/punches.png`.
- **The telegraphs:** `shots/task25/telegraphs/`, the heavies and Breaker Palm at the first third of their startups.

## Decisions for you

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Decision 4 is answered: rules-authored lunges such as Breaker Palm's retire, with the reach push, and a clip that falls short of its distance band is re-keyed with a longer step or reach, never slid.

1. **A fist's reach is measured by its depth** (task 24). The reach rule puts the last 15–20 cm of blade into a defender at the duelling distance; a fist's strike segment is 7.6 cm across the knuckles, so it can never hold that much. For any strike part shorter than 15 cm the bake and the reach test measure how deep it goes past the defender's surface instead, to the same 15–20 cm (`SwingReach.inside()`). Before it, the bake pushed every punch the full 15 cm chasing a length it couldn't reach. The three string lights now go 17.1–18.8 cm deep from 1.6 m, each lunge ending on its first touch. **Recommended: keep the depth rule.**
2. **The clip table changed where the clips didn't fit their moves:**
   - Cross plays AttackPunch02_R, the quick straight right (AttackPunch01_R is a wound-up lunging punch, 33 frames against Cross's 18); Hook AttackPunch01_L, the left wound back and thrown with a lunge (AttackPunch03 is a jumping, spinning uppercut).
   - Slip Jab and Lunging Palm swap to clips striking with the hand the rules use (the table had them the other way round).
   - Spinning Backfist plays AttackPunch03_R, the jumping, spinning uppercut.
   - Snap Kick plays AttackKick01_L from frame 3, the lead leg's quick kick: the table's AttackKick02_L is a spinning kick 24 frames long, which a 7-frame startup can't play under twice its speed. Axe Kick plays the same lead-leg kick, striking on its way down. Both kick with the left leg (the rules' `hand` for them is now `L`; the stand-in poses mirror them meanwhile).
   - Breaker Palm follows the table: AttackPunch03_R's deep crouch held 4 frames, then the CC0 Melee_Uppercut, the palm driven up into the defender at the end of the dash.

   **Recommended: keep the new fits.**
3. **The Flying Knee strikes with its knee**, a new strike part: a segment from the top of the kneecap 23 cm down the shin, 14 cm thick, on any weapon (`Swing`'s `right_knee` and `left_knee`, `SimConst.KNEE_STRIKE_*`, read by the poser from the knee joint and the shin). **Recommended: keep it.**
4. **Breaker Palm's lunge grows 2.5 → 2.95 m.** The uppercut reaches only 0.8 m ahead of the hips, so from the ultimate's 4.1 m test distance it fell about 30 cm short; at 2.95 m it touches with no push. The other way would be a straighter palm thrust, but every pack's long thrusting punch (AttackPunch01_R) already plays Lunging Palm and Counter Lunge. **Recommended: keep the lunge.**

## Every move

Frames are startup / active / recovery, all unchanged from today. The push is the bake's reach correction, played by moving the body above the hips (at most 15 cm). Test distances are the reach table's: the duelling distance 1.6 m for the lights and the dodge attacks, 2.1 for the heavies and the back light, 3.1 and 4.1 for the sprint attacks, 3.6 for the back heavy and the counter lunge, 1.1 for the jump attacks, 4.1 for Breaker Palm. "Deep" is how far the fist, foot or knee gets past the defender's surface there (the lights' target 15–20 cm).

| Move | Clip (source frames) | Speed | Frames | Lunge before → now (m) | Push (cm) | Deep (cm) | Rogue plays |
|---|---|---|---|---|---|---|---|
| Jab | AttackPunch02_L | ×1.40 | 5 / 2 / 10 | 0.3, now ending on frame 6 | 0 | 18.8 | HumanF |
| Cross | AttackPunch02_R | ×1.17 | 6 / 2 / 10 | 0.3 → 0.27 (end 7) | 0 | 17.9 | HumanF |
| Hook | AttackPunch01_L | ×1.88 | 8 / 3 / 14 | 0.3 → 0.07 (end 9) | 0 | 17.1 | HumanF |
| Slip Jab | AttackPunch01_L from frame 5 | ×1.00 | 5 / 2 / 10 | 0.4, unchanged | 0 | 33.0 | HumanF |
| Spinning Backfist | AttackPunch03_R, the jumping, spinning uppercut | ×1.40 | 10 / 3 / 16 | none | 11.1 | touch | HumanM |
| Lunging Palm | AttackPunch01_R | ×1.25 | 12 / 4 / 16 | 1.8 → 1.9 | 6.0 | touch | HumanF |
| Counter Lunge | AttackPunch01_R from frame 4 | ×1.40 | 5 / 3 / 14 | from the distance, as before | 0 | 20.6 | HumanF |
| Roundhouse | AttackKick01_R, chambered on the charge frame | ×1.40 | 14 / 4 / 20 | 0.4, unchanged | 0 | 34.8 | HumanF |
| Spinning Heel | AttackKick02_R, its last frame held 3 frames | ×1.25 | 16 / 4 / 22 | 0.4, unchanged | 0 | 25.5 | HumanM |
| Flying Knee | UAL2 Melee_Knee from frame 2, the knee | ×1.63 | 8 / 4 / 16 | 2.2, unchanged | 0 | 18.5 | her own (CC0) |
| Dragon Kick | Jump01_Begin's crouch into AttackKick01_R from frame 3 | ×1.57 | 14 / 5 / 20 | 2.4, unchanged | 0 | 34.8 | HumanF |
| Snap Kick | AttackKick01_L from frame 3, the left leg | ×1.71 | 7 / 3 / 12 | 0.5, unchanged | 0 | 34.6 | HumanF |
| Air Kick | UAL2 Melee_Knee from frame 2, the foot | ×1.86 | 7 / 3 / 12 | none | 0 | 11.8 | her own (CC0) |
| Axe Kick | AttackKick01_L, the left leg on its way down, its last frame held 2 | ×1.83 | 12 / 4 / 18 | none | 0 | 37.6 | HumanF |
| Breaker Palm | AttackPunch03_R's crouch held 4 frames, then UAL2 Melee_Uppercut from frame 3 | ×1.57 | 14 / 3 / 26 | 2.5 → 2.95 | 0 | 1.4 | HumanF (the uppercut her own) |

Every move but Counter Lunge, which works its lunge out from the distance, misses from 6 m (`test_move_reach`).

## Moves that share a clip

- **AttackKick01_R:** Roundhouse, Dragon Kick (from frame 3, after the jump's crouch).
- **AttackKick01_L:** Snap Kick (from frame 3), Axe Kick.
- **UAL2 Melee_Knee:** Flying Knee (the knee), Air Kick (the foot), both from frame 2.
- **AttackPunch01_R:** Lunging Palm, Counter Lunge (from frame 4).
- **AttackPunch01_L:** Hook, Slip Jab (from frame 5).
- **AttackPunch03_R:** Spinning Backfist, Breaker Palm's crouch.
- **AttackPunch02_L:** Jab; the Daggers' Flick.
- **Jump01_Begin:** Dragon Kick's crouch; the Daggers' Pounce.

## What's new under bare hands

- **No weapon** (task 24): the bake reads the striking fist straight from the hand (the fist's frame, `FighterRig.fist()`), and the move sheet takes `--weapon=fists`.
- **The depth rule for short strike parts** (task 24; decision 1).
- **Kicks bake a foot track** on the move's side (task 25): the ankle, along the foot to the toes, the sole's way as its edge, striking with bare hands' foot segment (heel to toe, 10 cm thick).
- **The knee strike** (task 25; decision 3).
- **Held clip ends:** Spinning Heel and Axe Kick hold their clips' last frame (the guard pose) for the few source frames their recoveries outlast the clips, so their frame data stays as it is.

## Findings

- **The Flying Knee's wind-up hunches**: the CC0 clip dips the hips and drops the head before the knee comes up (frames 2–6), the clip's own. With the rules' hop and 2.2 m lunge it reads as a leap into the knee at the real distance; on the sheets' 2.5 m it carries the attacker into the defender.
- **Breaker Palm crouches almost to a kneel** (AttackPunch03's own crouch) and slides the 2.95 m in that crouch before the uppercut; the sheets' 2.5 m puts the attacker under the defender.
- **The Hook reads as a heavy lunging left more than a hook** (task 24): no pack clip throws a true hook.
- **The Rogue plays her own clips for most bare-hands moves**: the punches and kicks stray little on her body; Spinning Backfist and Spinning Heel (both spins) play the Hunter's.
- **The jump attacks play grounded clips in the air**, as the other weapons' do.
- **Roundhouse and Dragon Kick tell late**: at the first third of their startups the kicking leg hasn't lifted yet (`shots/task25/telegraphs/`). A held chamber, as Roundhouse has on the charge frame, would fix it if they read too late in play.
- **PoseCheck fails on clip frames** (the knees, deep in the kicks' chambers and the crouches), as for the other weapons; the same recommendation: exempt clip-driven frames from its limits.

## The animation spike critique, checked

As for the Katana (its table holds for bare hands too, with these differences):

| Critique | Bare hands |
|---|---|
| Fix 3: a real coil and release, a held cocked pose | Roundhouse holds its chamber on the charge frame; Breaker Palm holds its crouch; Dragon Kick's crouch (Jump01_Begin's) is shallow |
| Fix 5: readable from the gameplay camera | Each heavy at the first third of its startup (`shots/task25/telegraphs/`): Spinning Heel already turned away and Breaker Palm down in its crouch read at once; Roundhouse is only shifting its weight onto the front foot and Dragon Kick still stands upright, so those two tell late (their kicking legs lift in the middle third) |
| Fix 6: reach measured | The three lights 17.1–18.8 cm deep at 1.6 m, each lunge ending on its first touch; every other move touches from its test distance and misses from 6 m |
| Condition 7: keyed or mocap clips for ultimates | Breaker Palm plays from clips |

## The soak

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The target of staying within ±5 points of the baseline retires. Every weapon is rebalanced around its clips as its animation lands.

A 300-match `node scripts/godot.mjs soak 300` with every bare-hands move on its clip: 0 failures. Bare hands aren't a weapon anyone picks, so they have no win rate of their own; they show in the weapons' rates through every disarm.

| | Now | After the Daggers' clips (task 23) | Baseline | Target |
|---|---|---|---|---|
| Katana win rate (no mirrors) | 54.6% (71 of 130) | 54.6% | 53.1% | within ±5 points of the baseline: met (+1.5) |
| Greatsword | 36.5% (42 of 115) | 38.3% | 46.1% | (its tuning change) |
| Daggers | 57.4% (74 of 129) | 55.8% | 50.4% | (the same tuning change) |
| Rounds | 40.7 s on average, longest 138.9 s | 40.7 s | 39.6 s | 35–60 s: **met** |
| Disarms per round | 1.02 | 1.05 | 1.06 | 0.3–0.6: **out**, as at the baseline |
| Re-arms (pick-ups), recalls per round | 0.89, 0.08 | | | |
| Disarmed ultimate choices per round | 0.23 | | | |
| Hits, blocks per round | 24.0, 22.8 | 24.3, 22.8 | 25.1, 24.8 | |
| Knockdowns per round | 1.72 | 1.69 | (new, task 16) | |

The weapons' rates move by a point or two from task 23's run, within a 300-match run's noise (about ±4 points on 115–130 matches); the Greatsword and the Daggers stay for their tuning change.
