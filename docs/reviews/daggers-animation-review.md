# The Daggers' review: authored animation

Oct 3, 2026 · `docs/plans/authored-animation.md` tasks 21–23 · branch `feature/authored-animation` (draft PR Arod231/monomachia#12)

Every Daggers move, Shadow Step and Lightning Tempest now animate from clips, and the moves' hits are decided by the paths baked from those same clips, one track for each blade. The daggers sit in the reverse grip in the guard and turn forward to attack. This page is the review package, laid out as the Katana's and the Greatsword's were (`docs/reviews/katana-animation-review.md`, `docs/reviews/greatsword-animation-review.md`). The video and the sheets are local (under `shots/`, which git ignores); everything else is committed. **Your OK on the Daggers gates bare hands (task 24).**

## What to look at

- **The before-and-after video:** `shots/daggers_video.avi`, every Daggers move on the Hunter, the procedural version from `feature/godot-rebuild` on the left and the clip version on the right, side on, at half speed (`node scripts/move_video.mjs --weapon=daggers`).
- **Contact sheets of every Daggers move on both fighters:** `shots/task23/hunter/` and `shots/task23/rogue/`, one sheet per move and the guard (`daggers_<move>.png`), and `daggers.png`, every move at its first active frame from the gameplay camera.
- **The grip flip:** `shots/task21/flip_hunter.png` (the daggers turning from the guard's reverse grip to forward over Quick Slice's crossfade, and back over its last 6 frames).
- **Slide Slash's cut:** `shots/task22/slide_variants.png`, the three cuts tried over the slide (see decision 3).
- **The telegraphs:** `shots/task23/telegraphs/`, Twin Fang, Spinning Backhand, Pounce, Serpent Sweep and Needle Thrust at the first third of their startups.
- **Per task:** the string and heavies (`shots/task21/`), the movement attacks, Shadow Step and Counter Lunge (`shots/task22/`).

## Decisions for you

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Decision 1 is answered: the rules-authored lunges and the reach push retire, and a clip that falls short of the weapon's distance band is re-keyed with a longer step or reach, never slid. Decision 4's tuning change against the baseline gives way to a rebalance of each weapon as its animation lands, and the ±5-point rule retires.

1. **The lunges, both ways.** The Daggers' lights are the first moves whose clips reach *further* than the demo's cones: at the 2.0 m duelling distance they put the whole 26 cm dagger into a defender, so their lunges shorten to put the reach rule's 17.5 cm in, each ending on its first touch (Quick Slice 0.3 → 0.15 m, Off-hand Slice 0.3 → 0.17, Twin Rip 0.4 → 0.38, Flurry Finisher 0.6 → 0.35). The other moves reach less far than their cones and lengthen as the Katana's and Greatsword's did (Spinning Backhand 0.4 → 1.1, Slide Slash 2.0 → 2.2, Reverse Spin none → 0.45, Flick 0.5 → 0.95, Needle Thrust 0.8 → 1.15). The Katana's question is still open. **Recommended: keep them for now and judge them in play with the others.**
2. **The clip table changed where a probe of the blades showed the named clips don't fit their moves:**
   - Spinning Backhand plays AttackPolearm04, a whole-body spin (no one-handed or dual-wield clip spins), and Reverse Spin the same spin mirrored, so it turns the other way round (the table's AttackDW01 mirrored is a stab, not a spin).
   - Air Slash plays Attack1H02_R's descending cut and Dive Stab AttackPolearm03, both daggers raised overhead and driven down: the table's UAL2 Sword_Aerial_A is 12 frames and spins the body round, and Sword_Aerial_B is a level sweep.
   - Lightning Tempest's six spins play the CC0 Sword_Aerial_Combo's two whole-body spinning slashes in turn, each cutting on its spin's hit, and the final AttackDW02's outward double slash: the table's AttackDW01 and AttackDW02 stab to the front, and Roll01 has no room in a 10-frame spin.

   **Recommended: keep the new fits.**
3. **Slide Slash and Serpent Sweep are composed clips**, a new step in the import: one clip on the upper body over another's hips and legs, built locally like every converted clip (`"compose"` in the clip manifest, `ImportClips.compose()`). RunSlide01 is a baseball slide, the hips 8 cm off the floor, so the table's Attack1H02 cut, leaning back with the slide, went into the floor. Upright on the slide, Attack1H02 and Attack1H04 still dipped below it after contact, so Slide Slash cuts Quick Slice's Attack1H01_R at the shins. Serpent Sweep starts as the slide, then sweeps Attack1H04_R across at shin height as the body rises out of it (the slide's later frames, the hips higher, so the blade stays above the floor). **Recommended: keep composed clips; bare hands' kicks may want them too.**
4. **The Daggers win 5.4 points over their baseline** (55.8% against 50.4%; the soak below), just past the ±5 target. Their clips brought them down, not up: they won 57.4% before them, at the Greatsword's review. Some of what is left is likely the Greatsword's weakness (38.3%, 7.8 under its baseline), which lifts both other weapons; the Katana is inside its band. **Recommended: pass the animation and fold the Daggers into the Greatsword's tuning change, measured on 300-match runs, which should bring both back.**

## Every move

Frames are startup / active / recovery, all unchanged from today. The push is the bake's reach correction, played by moving the body above the hips (at most 15 cm). Test distances are the reach table's (the duelling distance 2.0 m for the lights and the dodge attacks, 2.5 for the heavies, 3.0 for the unblockables, 3.5 and 4.5 for the sprint attacks, 2.5 and 4.0 for the back attacks, 1.5 for the jump attacks, 4.0 for the counter lunge). "Inside" is how far the blade gets into the defender there (the lights' target 15–20 cm; 26 cm is the whole blade).

| Move | Clip (source frames) | Speed | Frames | Lunge before → now (m) | Push (cm) | Inside (cm) | Rogue plays |
|---|---|---|---|---|---|---|---|
| Quick Slice | Attack1H01_R from frame 2 | ×1.86 | 7 / 2 / 13 | 0.3 → 0.15 (end 8) | 0 | 17.4 | HumanM |
| Off-hand Slice | Attack1H01_L (the left hand's slash) from frame 2 | ×1.86 | 7 / 2 / 13 | 0.3 → 0.17 (end 8) | 0 | 17.7 | HumanF |
| Twin Rip | AttackDW01 | ×1.67 | 9 / 3 / 14 | 0.4 → 0.38 (end 11) | 0 | 18.1 | HumanM |
| Flurry Finisher | AttackDW02 | ×1.36 | 11 / 3 / 18 | 0.6 → 0.35 (end 13) | 0 | 16.7 | HumanM |
| Twin Fang | AttackDW02, its wind-back held 3 frames and on the charge frame | ×1.29 | 16 / 3 / 20 | 1.4, unchanged | 0 | 26.0 | HumanM |
| Spinning Backhand | AttackPolearm04 (the spin) | ×1.22 | 18 / 5 / 22 | 0.4 → 1.1 | 10.8 | touch | HumanM |
| Slide Slash | Attack1H01_R from frame 2 upright over RunSlide01 (composed) | ×1.63 | 8 / 3 / 14 | 2.0 → 2.2 | 0 | 10.0 | HumanM |
| Pounce | Jump01_Begin's crouch into AttackDW02 from frame 4 | ×1.36 | 14 / 4 / 20 | 3.0, unchanged | 0 | 26.1 | HumanM |
| Passing Cut | Attack1H03_R from frame 4 | ×1.67 | 6 / 2 / 12 | 1.2, unchanged | 0 | 20.9 | HumanM |
| Reverse Spin | AttackPolearm04 mirrored, from frame 2 | ×1.42 | 12 / 4 / 16 | none → 0.45 | 11.0 | touch | HumanM |
| Flick | AttackPunch02_L, the left jab with the blade | ×1.00 | 7 / 2 / 12 | 0.5 → 0.95 | 12.5 | touch | HumanF |
| Rebound Lunge | Attack1H04_R from frame 2 | ×1.58 | 12 / 4 / 18 | 2.5, unchanged | 7.0 | touch | HumanM |
| Air Slash | Attack1H02_R from frame 6 | ×1.86 | 7 / 3 / 12 | none | 0 | 26.1 | HumanM |
| Dive Stab | AttackPolearm03 from frame 4 | ×1.83 | 12 / 4 / 18 | none | 0 | 10.1 | HumanM |
| Serpent Sweep | RunSlide01 into Attack1H04_R over the slide's rise (composed) | ×1.55 | 20 / 5 / 22 | 2.5, unchanged | 0 | 26.1 | HumanM |
| Needle Thrust | AttackPolearm01, its pull-back held 4 frames | ×1.55 | 20 / 3 / 20 | 0.8 → 1.15 | 12.2 | touch | HumanM |
| Counter Lunge | Attack1H04_R from frame 6 | ×1.80 | 5 / 3 / 16 | from the distance, as before | 0 | 4.1 | HumanM |
| Shadow Step | Roll01; hidden through the active frames | ×2.00 | 5 / 14 / 8 | the rules' path round | n/a | n/a | her own |
| Lightning Tempest | Sword_Aerial_Combo's two spinning slashes in turn, then AttackDW02's outward slash | — | the rules' phases | n/a | n/a | n/a | her own (the final HumanF) |

## Moves that share a clip

- **AttackDW02:** Flurry Finisher, Twin Fang (with its wind-back held), Pounce (from frame 4), the Tempest's final (its outward slash).
- **Attack1H04_R:** Rebound Lunge (from frame 2), Counter Lunge (from frame 6), Serpent Sweep's upper body. The Katana's Returning Draw and Counter Lunge play it too.
- **Attack1H01_R:** Quick Slice, Slide Slash's upper body; Off-hand Slice is its left-handed twin (Attack1H01_L). The Katana's Right Cut plays it too.
- **AttackPolearm04:** Spinning Backhand, Reverse Spin (mirrored); the Greatsword's Reaping Sweep.
- **RunSlide01:** the legs of Slide Slash and Serpent Sweep.
- **AttackPolearm01:** Needle Thrust; the Greatsword's Piercing Lunge, Skewer, Counter Lunge and Impaler, the Katana's Piercing Thrust.
- **AttackPolearm03:** Dive Stab; the Greatsword's Mountain Slam.
- **Attack1H02_R:** Air Slash; the Katana's Wind Cut.
- **Attack1H03_R:** Passing Cut; the Katana's Return Cut.

## What's new under the Daggers

- **Two blades** (task 21). Every Daggers move bakes a track for each hand, and both strike.
- **The grip flip** (task 21). The guard holds the daggers reversed; the director turns them forward over an attack's crossfade and back over its last 6 recovery frames unless a follow-up is queued (`ClipDirector.Shot.grip`, `FighterRig.set_reverse_turn()`). The bake reads the forward grip, which every active frame holds.
- **Composed clips** (task 22; decision 3).
- **Shadow Step's blink** (task 22): Roll01 at double speed, the dive in over the startup and the rise out over the recovery, with the body and its floor marks hidden through the 14 active frames that carry it round to the opponent's back (`ClipDirector.blinks()`). The port had no rules tests for the step; `test_shadow_step` now covers the step round, the 6-frame blind, the invulnerability and the backstab window.
- **Lightning Tempest** (task 23) plays through the director as the other ultimates do, each spin a phase of its own crossfaded as a follow-up. Its spins are CC0, so they play without the packs too. No sheet tool plays an ultimate; a director test checks that each cut lands on its hit.

## Findings

- **The Rogue plays the Hunter's set for nearly every move**: her own clips stray more than 5 cm on her body (up to 11 cm), as for the other weapons; only Off-hand Slice and Flick are her own.
- **The slide moves sit on the floor**: Slide Slash ends seated and the director fades it back to standing over 6 frames; Serpent Sweep rises out of the slide on its own.
- **The jump attacks play grounded clips in the air**, as the other weapons' do.
- **The sheets' 2.5 m spacing is past the Daggers' 2.0 m duelling distance but short of their long moves' test distances**, so Slide Slash, Serpent Sweep and Needle Thrust carry the attacker into the defender on the sheets; at the real distances they meet the reach rule.
- **PoseCheck fails on clip frames** (knees and the blade near the thighs, on the slides most), as for the other weapons; the same recommendation: exempt clip-driven frames from its limits.
- **The grip flip is hard to see** at the gameplay camera's distance; the hands view on the sheets shows it.
- **No blade trail** yet (godot-rebuild 18.2–18.3).

## The animation spike critique, checked

As for the Katana (its table holds for the Daggers too, with these differences):

| Critique | The Daggers |
|---|---|
| Fix 3: a real coil and release, a held cocked pose | Twin Fang holds its wind-back on the charge frame; Needle Thrust holds its pull-back; Serpent Sweep drops into the slide before it sweeps |
| Fix 5: readable from the gameplay camera; slash, overhead, thrust and sweep apart in the first third | Each at the first third of its startup (`shots/task23/telegraphs/`): Twin Fang and Needle Thrust drawn back, Spinning Backhand already turning, Pounce crouched, Serpent Sweep down in the slide |
| Fix 6: reach measured | The four lights 16.7–18.1 cm into a defender at 2.0 m, each lunge ending on its first touch; every other move touches from its test distance (`test_duel_reach`, `test_move_reach`) |
| Fix 9: guard walking | The guard walks in the reverse grip |
| Condition 7: keyed or mocap clips for ultimates | Lightning Tempest plays from clips |

## The soak

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The target of staying within ±5 points of the baseline retires. Every weapon is rebalanced around its clips as its animation lands.

A 300-match `soak:tune` with every Katana, Greatsword and Daggers move on its clip (Oct 3), against the baseline before any rules change (task 3):

| | Now | Before the Daggers' clips (task 20) | Baseline | Target |
|---|---|---|---|---|
| Daggers win rate (no mirrors) | 55.8% (72 of 129) | 57.4% | 50.4% | within ±5 points of the baseline: **missed** (+5.4) |
| Katana | 54.6% (71 of 130) | 52.3% | 53.1% | met (+1.5) |
| Greatsword | 38.3% (44 of 115) | 39.1% | 46.1% | (its tuning change, decision 4) |
| Rounds | 40.7 s on average, longest 108.8 s | 39.1 s | 39.6 s | 35–60 s: **met** |
| Disarms per round | 1.05 | 0.99 | 1.06 | 0.3–0.6: **out**, as at the baseline |
| Hits, blocks per round | 24.3, 22.8 | 23.9, 21.9 | 25.1, 24.8 | |
| Knockdowns per round | 1.69 | 1.77 | (new, task 16) | |
| Lightning Tempests per round | 0.40 | | | |

0 failures in 300 matches.
