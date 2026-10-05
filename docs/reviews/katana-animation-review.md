# The Katana's review: authored animation

Oct 3, 2026 · `docs/plans/authored-animation.md` task 14 · branch `feature/authored-animation` (draft PR Arod231/monomachia#12)

Every Katana move now animates from a clip, and its hits are decided by the path baked from that same clip. This page is the review package. The video and the sheets are local (under `shots/`, which git ignores); everything else is committed. **Your OK on the Katana gates the Greatsword (task 18).**

## What to look at

- **The before-and-after video:** `shots/katana_video.avi`, every Katana move on the Hunter, the procedural version from `feature/godot-rebuild` on the left and the clip version on the right, side on, at half speed. Rebuild it with `node scripts/move_video.mjs` (`--weapon`, `--fighter`, `--moves`).
- **Contact sheets of every Katana move on both fighters:** `shots/task14/hunter/` and `shots/task14/rogue/`, one sheet per move from the gameplay camera behind the defender and behind the attacker, three-quarter, close and hands, plus `index.png` of every move at its first active frame.
- **The guard and movement:** `shots/task14/guard_hunter.png`, `guard_rogue.png`, and the strips `shots/task14/drives/` (run and brake, strafe, backpedal, the guard shuffle, tap steps, the Iai stance walked).
- **Per task:** the L-L-L-L string with each stop (`shots/task10/`), the heavies and the Iai stance (`shots/task11/`), the movement attacks (`shots/task12/`), slash, overhead, thrust and sweep side by side in the first third of the wind-up (`shots/task13/telegraphs.png`).

## Decisions for you

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** Decision 1 is answered: the rules-authored lunges and the reach push retire, and a clip that falls short of the weapon's distance band is re-keyed with a longer step or reach, never slid. The weapon models will set the blade lengths, and reach is retuned to match.

1. **The lunges.** Kevin's clips reach far less than the demo's cones did, and the spec's answer for a clip that falls short of its test distance is a longer lunge in the rules. So 19 of the Katana's 21 moves now lunge further (table below). The frames are unchanged on every move, and a 300-match run keeps the Katana inside ±5 points of its baseline. But a heavy now carries the fighter much further: the Iai Slash lunges 2.1 m (was 0.4), so from close range it runs right up to the defender before the cut, and a whiffed one leaves the attacker deep. The alternatives are to accept shorter reach (retune the test distances) or to retime the clips so their stepping covers more ground. **Recommended: keep the lunges for now and judge them in play.**
2. **The clip table changed where the probe showed the named clips don't match their moves** (the table was picked from names, before anyone looked): Return Cut, Kesa Cut, Crown Cut, Rising Heaven, Returning Draw, Heaven Splitter, Whirl Cut, Running Draw, Rising Cut, Lunging Cut and both jump attacks use other clips than the spec's first candidates (the spec's table now says which, and why). Kevin's `_L` clips swing with the left hand, a whole-body mirror, so "the other side" never meant a right-handed backswing. **Recommended: keep the new fits.**
3. **The Rogue plays the Hunter's clips (HumanM) for 15 of the 21 moves:** her own HumanF clip strays more than 5 cm on her body for those (the drift you kept at task 7). She looks the same as him in those moves. **Recommended: accept for now; revisit if it reads as wrong in play.**

## Every move

Frames are startup / active / recovery, unchanged from the demo on every move. The push is the bake's reach correction, played by moving the body above the hips (at most 15 cm).

| Move | Clip (source frames) | Speed | Frames | Lunge before → now (m) | Push (cm) | Rogue plays |
|---|---|---|---|---|---|---|
| Right Cut | Attack1H01_R | ×1.45 | 11 / 3 / 16 | 0.35 (lunge end 12 → 13) | 8.2 | HumanM |
| Return Cut | Attack1H03_R | ×1.80 | 10 / 3 / 16 | 0.35 → 0.45 | 11.4 | HumanM |
| Kesa Cut | Attack2H01 from frame 8 | ×1.30 | 11 / 3 / 17 | 0.35 → 0.4 (end 12 → 14) | 10.1 | HumanF |
| Crown Cut | Attack2H02 from frame 10 | ×1.55 | 14 / 4 / 22 | 0.5 → 0.7 (end 16 → 15) | 9.7 | HumanM |
| Iai Slash (vertical) | SheatheHips01_R 3–12, held, into Attack1H04_R from 2 | ×1.30 | 23 / 4 / 24 | 0.4 → 2.1 | 0 | HumanF |
| Iai Slash (horizontal) | SheatheHips01_R 3–12, held, into Attack1H05_R | ×1.15 | 23 / 4 / 24 | 0.4 → 2.1 | 0 | HumanM |
| Rising Heaven | Attack1H05_R | ×1.00 | 16 / 4 / 24 | 0.5 → 1.2 | 12.9 | HumanM |
| Returning Draw | Attack1H04_R | ×1.35 | 16 / 4 / 24 | 0.5 → 1.1 | 13.2 | HumanF |
| Heaven Splitter | Attack2H04 | ×1.25 | 22 / 4 / 28 | 0.7 → 0.95 | 11.5 | HumanM |
| Running Draw | Attack1H01_R | ×1.30 | 12 / 4 / 18 | 1.6 → 1.7 | 9.4 | HumanM |
| Leaping Cleave | Attack2H04 | ×1.40 | 20 / 5 / 26 | 2.6 → 2.9 | 13.9 | HumanM |
| Wind Cut | Attack1H02_R from frame 4 | ×1.75 | 9 / 3 / 16 | 0.4 → 0.5 | 6.0 | HumanM |
| Whirl Cut | Attack2H03 | ×1.00 | 18 / 6 / 24 | 0.3 → 0.5 | 12.4 | HumanM |
| Rising Cut | Attack1H05_R | ×1.60 | 10 / 3 / 18 | 0.8 → 1.25 | 13.7 | HumanM |
| Lunging Cut | Attack2H01 | ×1.65 | 18 / 4 / 24 | 2.2 → 2.3 | 13.9 | HumanM |
| Aerial Cut | Attack1H01_R from frame 4 | ×1.15 | 7 / 4 / 12 | none | 0 | HumanM |
| Falling Crown | Attack2H04 from frame 6 | ×1.30 | 12 / 5 / 18 | none | 0 | HumanM |
| Flash | Parry1H01_R loop 0–20, then its hit (pose only) | ×2.00 | 2 / 18 / 18 | none | n/a | HumanF |
| Piercing Thrust | AttackPolearm01, pull-back held 4 frames | ×1.15 | 26 / 4 / 24 | 1.0 → 1.4 | 12.3 | HumanM |
| Swallow Sweep | Attack2H03, wind-round held 4 frames | ×1.00 | 26 / 5 / 24 | 0.4 → 1.4 | 12.0 | HumanM |
| Counter Lunge | Attack1H04_R from frame 6 | ×1.65 | 6 / 3 / 18 | from the distance, as before | 0 | HumanF |
| Moonsplitter | Attack2H01 held, released with the wave (Attack2H03 for the horizontal) | — | the rules' 36 + 34 | n/a | n/a | her own |

## Moves that share a clip

None mirrors a clip. These share one:

- **Attack1H01_R:** Right Cut, Running Draw, Aerial Cut (from frame 4).
- **Attack1H04_R:** the vertical Iai's draw (from frame 2), Returning Draw, Counter Lunge (from frame 6).
- **Attack1H05_R:** the horizontal Iai's draw, Rising Heaven, Rising Cut.
- **Attack2H01:** Kesa Cut (from frame 8), Lunging Cut, Moonsplitter.
- **Attack2H03:** Whirl Cut, Swallow Sweep (with a held wind-round), Moonsplitter's horizontal wave.
- **Attack2H04:** Heaven Splitter, Leaping Cleave, Falling Crown (from frame 6).
- **SheatheHips01_R:** both Iai Slashes.

## Findings

- **Crown Cut follows through into a deep bow**, the tip near the floor: the clip's own (Attack2H02).
- **The jump attacks play Kevin's standing legs in the air.** The UAL2 aerial clips the spec named were side-on and too short (Sword_Aerial_A is 12 source frames and reaches 1 m), so Aerial Cut and Falling Crown use grounded clips. An upper-body-only version over the jump's legs is possible (the Iai's stance already does it) but needs the bake to pose the same way.
- **The UAL2 Source sword clips the spec named** (Sword_Dash, Sword_UpperCut, the aerials) turn the hips 80–120° side-on and reach about 1 m, so none is used.
- **The saya** (built in code around the blade, at the left hip whenever the Katana is out) holds the katana through the Iai's sheathe and stance; the stance is walked in with the guard shuffle's legs under the held clip.
- **PoseCheck fails on nearly every frame of every clip** (the red lines on the sheets): its wrist and elbow limits were written for the procedural swings, and Kevin's arms pass them by (wrists turned 50–70° sideways, elbows bent 60–80° at contact). It is the same reason the swing checks skip baked swings (task 9). godot-rebuild 14.17's "PoseCheck passes for every Katana move" can't hold under clips without the same exemption. **Recommended: exempt clip-driven frames from PoseCheck's arm limits, keeping its feet and blade-clearance checks.**
- **No blade trail is drawn yet:** trails are godot-rebuild 18.2–18.3, still to do, so there is no trail sheet.

## The animation spike critique, checked

The spike critique (`docs/research/animation-spike/critique.md`) judged the procedural swings. Its fixes and conditions, against what the clips now do:

| Critique | Status | Where to see or test it |
|---|---|---|
| Fix 1: the hands drive the blade, within wrist limits, never through the body | Met by construction: the blade is read from the clip's own hand (a mocap-quality arm), and the Rogue's hold is checked by the 5 cm drift. The procedural wrist check is skipped for baked swings (spec). | `test_swing_bake` (samples within 1 mm of the posed hand); sheets, hands view |
| Fix 2: full-body hand paths, shoulder to opposite hip, elbows never locked | Met by the clips; the two-handed draw-in keeps the off elbow under full stretch | sheets, three-quarter and close views |
| Fix 3: a real coil and release, a held cocked pose | Met by the clips (torso turns of 40–60° in the probes) | sheets; `shots/task13/telegraphs.png` |
| Fix 4: strings built on strong hand-off poses | Met differently: a follow-up crossfades 4 frames from the last pose; the sides check stays | `test_string_continuity`; `shots/task10/` |
| Fix 5: readable from the gameplay camera; slash, overhead, thrust and sweep apart in the first third | Met | `shots/task13/telegraphs.png`; each sheet's defender view |
| Fix 6: reach measured; 15–20 cm of blade into the defender at 2.5 m; the lunge's foot lands on contact | Met (17.5 cm on every light; each lunge ends on its first touch) | `test_duel_reach`, `test_move_reach` |
| Fix 7: impact weight (hit-stop, blade lag, camera kick, parry bounce) | Hit-stop and the camera kick were already in; blade lag (14.14) and the parry-bounce prototype (14.15) are retired; the parry plays from clips in task 27 | task 27 |
| Fix 8: the legs (knees over toes, stance width, weight shift) | Met under clips by the clips; foot locking holds planted feet (under 1 cm) | `test_foot_lock`; guard sheets |
| Fix 9: guard walking on a shuffle step | Met (godot-rebuild 14.9, unchanged); the Iai stance walks on it too | `test_guard_shuffle`; `shots/task14/drives/` |
| Fix 10: trail and presentation | Trails not built yet (godot-rebuild 18.2–18.3); palettes per fighter done | — |
| Condition 1: the wrist and self-collision check exists and every move passes | Superseded for baked swings (see fix 1); still applies to hand-keyed swings | spec, "The swing rules still apply" |
| Condition 2: cuts around a coil and hand-offs, passing the gameplay-camera review | This review | sheets |
| Condition 3: contact lands at the design spacing; parry bounce on the same paths | Contact met; the parry bounce moves to task 27 | `test_duel_reach` |
| Condition 4: hit-stop, blade lag and follow-through overshoot before "weight" is judged | Hit-stop in; overshoot comes from the clips; blade lag retired | — |
| Condition 5: guard walking on the shuffle without crossed feet | Met | `test_guard_shuffle` |
| Condition 6: the key editor before weapon #2 | Retired: clips replace hand keying | spec |
| Condition 7: keyed or mocap clips for ultimates, reactions and the rest | This plan: Moonsplitter here; reactions in tasks 26–31 | — |

## The soak

> **Superseded by [ADR 0001](../adr/0001-animation-leads-realistic-look.md) (Oct 4, 2026):** The target of staying within ±5 points of the baseline retires. Every weapon is rebalanced around its clips as its animation lands.

A 300-match `soak:tune` with every Katana move on its clip (Oct 3), against the baseline before any rules change (task 3):

| | Now | Baseline | Target |
|---|---|---|---|
| Katana win rate (no mirrors) | 55.4% (72 of 130) | 53.1% | within ±5 points of the baseline: **met** (+2.3) |
| Greatsword | 39.1% | 46.1% | the Greatsword's review (task 20) has to win this back; the shoulder carry and knockdown cost it before any clip |
| Daggers | 54.3% | 50.4% | |
| Rounds | 40.4 s on average, longest 116.2 s | 39.6 s | 35–60 s: **met** |
| Disarms per round | 1.00 | 1.06 | 0.3–0.6: **out**, as at the baseline (the spec's target was already missed before this feature) |
| Hits, blocks, parries per round | 24.2, 22.8, 4.4 | 25.1, 24.8, 4.6 | |
| Knockdowns per round | 1.77 | (new, task 16) | |

0 failures in 300 matches.
