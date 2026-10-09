# Milestone 1: the per-move checklist

The record of the spec's per-move checklist (`docs/specs/milestone-1.md`, "The per-move checklist", P32) for every Katana and bare-hands move and every clip that sets a rules length or shows a protected timing (milestone-1 task 10). A move must pass every item that applies before the milestone ends.

- The CI-checked columns are filled by `npm run checklist` from the last test run's results (`build/checklist-results.json`, written by the tests that check an item move by move); it never touches the owner's columns.
- The owner's columns (6, 7 and 17) are ticked here, by hand, at each family's review.
- Rows for clips not built yet say so under Status; a row's cells fill in as its family lands.

## Key

| # | Item | Applies to | Checked by |
|---|---|---|---|
| 1 | Keyed into its timing band; frame data generated from the clip, no hand overrides | attacks | the band test (CI) |
| 2 | Connects from its distance band and misses beyond it | attacks | the distance-band test (CI) |
| 3 | Fits its protected frames at its own speed | the roll, backstep, reactions, stuns, staggers, the daze, knockdown | the state-clip fit test (CI) |
| 4 | Plays at its own speed; holds are loops | every clip | the director test (CI) |
| 5 | No slide beyond its own steps; travel baked; a rules-length clip's length and markers in the table | every clip | the table and the rules tests (CI) |
| 6 | The attack type reads early in the wind-up | attacks | **the owner** (the side-by-side video) |
| 7 | The weight visibly shifts | every clip | **the owner** |
| 8 | Planted feet slide no more than 1 cm | every clip | PoseCheck's foot slide on every rules frame (local) |
| 9 | The blade never passes through the body | every clip with a weapon | PoseCheck's blade clearance on every rules frame (local) |
| 10 | The hands stay on the grips; Katana cuts two-handed but story 53's moments | every clip with a weapon | the weapon-in-hand test (local) and the sheets |
| 11 | Hands off cleanly: branch points, cancel markers, inertial blending, the next swing's side | every clip | the string-continuity test, and the owner at the review |
| 12 | Its deflect pair, its block reaction, the defender's directional hit reactions | attacks | the director test and the sheets |
| 13 | Its sound | every clip with an event | the sound-bank test, and the listening pass |
| 14 | Its effects at the contact point | every clip with an event | the effects parity check and the sheets |
| 15 | The computer can use it and answer it | attacks | seeded rules tests |
| 16 | Re-bakes from its clip with no drift | attacks | the local re-bake test |
| 17 | The owner's review: sheets, the side-by-side video, a play session with the licensed clips | its family | **the owner** |

Marks: ✓ passed · ✗ failed · · not checked yet · – doesn't apply · ☐ the owner's, not ticked yet · ☑ the owner's, ticked.

<!-- Rows: `id` is the move id in game/sim/moves, or a clip id for clips the rules don't name as moves. Keep one row per id. -->

## 1. The pilot: the Katana's light string

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Right Cut `k_l1` | move | ✓ | ✓ | – | ✓ | ✓ | ☑ | ☑ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ☑ |
| Return Cut `k_l2` | move | ✓ | ✓ | – | ✓ | ✓ | ☑ | ☑ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ☑ |
| Kesa Cut `k_l3` | move | ✓ | ✓ | – | ✓ | ✓ | ☑ | ☑ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ☑ |
| Crown Cut `k_l4` | move | ✓ | ✓ | – | ✓ | ✓ | ☑ | ☑ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ☑ |
| Slanting Cut `k_1l1` | move (KE task 11) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Backhand Rise `k_1l2` | move (KE task 11) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Twisting Rise `k_1l3` | move (KE task 12) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Level Cut `k_1l4` | move (KE task 12) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ | ☐ |
| Crouching Crown `k_1l5` | move (KE task 12) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ | ☐ |
| Heavy Slant `k_2l1` | move (KE task 13) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Left Rise `k_2l2` | move (KE task 13) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Right Rise `k_2l3` | move (KE task 14) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Second Slant `k_2l4` | move (KE task 14) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Kneeling Crown `k_2l5` | move (KE task 14) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ | ☐ |
| The light deflect pairs `clip_deflect_light` | keyed clips (task 34) | – | – | ✗ | ✓ | ✓ | – | ☑ | ✗ | ✗ | ✓ | ✓ | – | ✓ | ✓ | – | – | ☑ |
| Light hit reactions `clip_hit_light` | keyed clips (task 35) | – | – | ✓ | ✓ | ✓ | – | ☑ | ✗ | – | – | ✓ | – | ✓ | ✓ | – | – | ☑ |
| Light block reactions `clip_block_light` | keyed clips (task 35) | – | – | ✓ | ✓ | ✓ | – | ☑ | ✗ | ✓ | ✓ | ✓ | – | ✓ | ✓ | – | – | ☑ |

## 2. Guard movement and dodges

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| The roll `clip_roll` | stand-in clip | – | – | · | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The backstep `clip_backstep` | stand-in clip | – | – | · | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The jump's landing `clip_land` | stand-in clip | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |

## 3. The Katana's heavies and the Iai

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Iai Slash (vertical) `k_iai` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Iai Slash (horizontal) `k_iai_h` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Rising Heaven `k_h1f` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Returning Draw `k_rdraw` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ | ☐ |
| Heaven Splitter `k_h2` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Crescent Coil `k_coil` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| The heavy deflect pairs `clip_deflect_heavy` | not built | – | – | · | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| Heavy hit reactions `clip_hit_heavy` | stand-in clips | – | – | · | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |
| Heavy block reactions `clip_block_heavy` | stand-in clips | – | – | · | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |

## 4. Reactions, knockdown and KO

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| The knockdown's fall, down and rise `clip_knockdown` | stand-in clips | – | – | · | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The stuns (stomp, Flash, redirect) `clip_stun` | stand-in clips | – | – | · | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The disarm stagger `clip_stagger` | stand-in clip | – | – | · | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |
| The disarmed daze `clip_daze` | stand-in clip | – | – | · | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |
| The deaths `clip_death` | stand-in clips | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |

## 5. The Katana's movement attacks

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Running Draw `k_sl` | move (task 75) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Leaping Cleave `k_sh` | move (task 75) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Wind Cut `k_dl` | move (task 75) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Whirl Cut `k_dh` | move (task 75) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Rising Cut `k_bl` | move (task 76) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Lunging Cut `k_bh` | move (task 76) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Aerial Cut `k_jl` | move (task 76) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |
| Falling Crown `k_jh` | move (task 76) | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ☐ |

## 6. Block abilities and counters

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Flash `k_flash` | move | · | · | – | · | · | ☐ | ☐ | ✓ | ✓ | · | · | · | · | · | · | · | ☐ |
| Piercing Thrust `k_thrust` | move | · | · | – | · | · | ☐ | ☐ | ✗ | ✗ | · | · | · | · | · | · | · | ☐ |
| Swallow Sweep `k_sweep` | move | · | · | – | · | · | ☐ | ☐ | ✗ | ✓ | · | · | · | · | · | · | · | ☐ |
| The stomp's paired clip `clip_stomp` | stand-in clip | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The leap's paired clip `clip_leap` | stand-in clip | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |

## 7. The disarm and bare hands' core

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Jab `f_l1` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ | ☐ |
| Cross `f_l2` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ | ☐ |
| Hook `f_l3` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ | ☐ |
| Roundhouse `f_h1` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ | ☐ |
| Spinning Heel `f_h2` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✗ | ✗ | ✓ | ☐ |
| The pull-out pick-up `clip_pull_out` | not built | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The disarmed roll `clip_roll_disarmed` | not built | – | – | · | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |
| The redirect's deflect pair `clip_deflect_redirect` | keyed clips (task 90) | – | – | ✓ | ✓ | ✓ | – | ☐ | ✗ | ✗ | ✓ | ✓ | – | · | · | – | – | ☐ |
| A blade parrying a fist or a foot (the Katana's high and low deflects, the fist and foot recoils) `clip_deflect_limb` | keyed clips (task 90) | – | – | ✓ | ✓ | ✓ | – | ☐ | ✗ | ✗ | ✓ | ✓ | – | · | · | – | – | ☐ |

## 8. Bare hands' movement attacks

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Flying Knee `f_sl` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ☐ |
| Dragon Kick `f_sh` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ☐ |
| Slip Jab `f_dl` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ☐ |
| Spinning Backfist `f_dh` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ☐ |
| Snap Kick `f_bl` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✗ | ✓ | ☐ |
| Lunging Palm `f_bh` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ☐ |
| Air Kick `f_jl` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ☐ |
| Axe Kick `f_jh` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ☐ |

## 9. The ultimates

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Moonsplitter `moonsplitter` | move | · | · | – | · | · | ☐ | ☐ | · | · | · | · | · | · | · | · | · | ☐ |
| Breaker Palm `f_breaker` | move | ✓ | ✓ | – | ✓ | ✓ | ☐ | ☐ | · | – | – | ✓ | ✗ | ✓ | ✗ | ✓ | ✓ | ☐ |
| The disarmed choice `clip_ult_choice` | stand-in clip | – | – | – | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |
| The recall's power-up `clip_recall` | stand-in clip | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |

## 10. The finishers

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| The Katana's finisher `clip_finisher_katana` | not built | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| Bare hands' finisher `clip_finisher_fists` | not built | – | – | – | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |

## 11. Round flow

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| The draw at the round intro `clip_draw` | not built | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The round-end beat, the Katana's sheathe `clip_round_end_katana` | not built | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| The round-end beat, bare hands' shake-out `clip_round_end_fists` | not built | – | – | – | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |
| The Katana's victory pose (sheathe and bow) `clip_victory_katana` | not built | – | – | – | · | · | – | ☐ | · | · | · | · | – | · | · | – | – | ☐ |
| Bare hands' victory pose (the cheer) `clip_victory_fists` | not built | – | – | – | · | · | – | ☐ | · | – | – | · | – | · | · | – | – | ☐ |

## Waiting for milestone 2

Only the Greatsword's slams trigger the evade counter, so these wait (P48).

| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| The Katana's Counter Lunge `k_lunge` | milestone 2 | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – |
| Bare hands' Counter Lunge `f_lunge` | milestone 2 | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – |
| The evade's paired clip `clip_evade` | milestone 2 | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – |
