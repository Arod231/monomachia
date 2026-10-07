# Milestone 1: the pilot family's review

Oct 7, 2026 · `docs/plans/milestone-1.md` tasks 40 (the package) and 41 (the review) · branch `lane/m1-40-41-42` (pull request Arod231/monomachia#94)

The pilot is the Katana's light string as it stands today: Right Cut, Return Cut, Kesa Cut and Crown Cut, their deflect pairs, the light hit and block reactions, the guard idle and the bridges between the hits, with the pilot's sound, sparks, smears, blood and parry push-in. This page is the review package and, once you have played it, the record of the review. `docs/plans/katana-elden-ring.md` replaces these four lights with two five-hit strings after this review, so what matters most here is the pace, the protected timings (which this review freezes) and the pipeline, more than these four clips' polish. The video, the sheets, the soak's log and the build are local (under `shots/` and `build/`, which git ignores); everything else is committed.

**Your OK here (task 41) freezes the protected timings and opens every other family's clip work and the Elden Ring plan's scale tasks.**

## What to look at

- **The side-by-side video:** `shots/m40/pilot_video.mp4` (also on this session's page in the Project Manager). For each light, a grid of ours from the gameplay camera in the look test's realistic look beside Elden Ring's Uchigatana two-handed (the style the re-keys follow), For Honor's Orochi (Crosswind Slashes), Ghost of Tsushima's light attacks and Tekken 8's Yoshimitsu (Heshikiriseibatsu), each cut round its hit, at full speed and then at half; then the whole string in each. For Honor's chain has three hits, so its fourth panel says so. Rebuild it with `node scripts/pilot_video.mjs --runs=<tools/animeref/runs>`; the footage was fetched with `tools/animeref/fetch.py` and stays on this PC (the three new videos sit beside the Elden Ring run in the uchigatana analysis worktree's `tools/animeref/runs/`).
- **Contact sheets** in `shots/m40/sheets/` (the Hunter, the Katana, from 2.5 m):
  - each light: `k_l1_hunter.png` to `k_l4_hunter.png`, every view and PoseCheck's numbers;
  - the whole string with its bridges and the return to guard: `string_llll.png`;
  - each light's deflect pair, the opponent's guard pressed 3 frames before it lands: `k_l1_parry.png` to `k_l4_parry.png`, the blades' distance in each caption;
  - the light hit reactions from the front, each side and behind (`hit_reactions_face0.png`, `face90`, `face-90`, `face180`), and from Crown Cut (`hit_reactions_crown.png`);
  - the light block reaction: `block_reactions.png`.
- **The checklist:** the pilot's rows in `docs/reviews/milestone-1-checklist.md`, filled by `npm run checklist` from the test run (summary below).
- **The play build:** see "The play session" below.

## The checklist

Every item a test checks passes for the four lights (1–5 and 8–16). The owner's columns (6, 7 and 17) are yours to tick at the review.

The clip rows are recorded as they stand, not re-keyed, as you decided (the new strings replace them):

| Row | Fails | What |
|---|---|---|
| Deflect pairs | 3 | each recoil settles 28 rules frames after its contact, the parry recoil is 26 (the attacker is free 2 frames before the clip ends; moving cuts it) |
| Deflect pairs | 8 | the recoils' planted feet slide 7–53 cm while the parry's knock moves the body |
| Deflect pairs | 9 | three deflects start with the blade inside the parrier's body on their first frame (−0.4, −2.7 and −8.8 cm), the inertial blend in from the guard |
| Light hit reactions | 8 | the feet slide 25–99 cm under the hit's knockback (the clips stand in place) |
| Light block reaction | 8 | the feet slide 14 cm under the block's knock |

## Found and fixed while filling it

- **The computer never played the string past Right Cut.** It pressed each follow-up 8 frames after the last, which suited the old ten-frame lights; the re-keyed lights take about 30 frames to land, so every press left the input buffer before the branch point opened. In 12 seeded Hard duels it used Right Cut 550 times, Return Cut twice and never Kesa Cut or Crown Cut. It now presses each follow-up 4 frames before the move's branch point, and its combos run up to four hits (they stopped at three, so Crown Cut was out of reach).

## Balance

The rebalance changed the lights only, one change at a time, each soaked over 40 mirror matches:

| Run | Rounds | Disarms a round |
|---|---|---|
| Before (the computer now chaining the string) | 52.8 s | 1.72 |
| The lights' posture 7/7/8/10 → 5/5/6/7 | 56.7 s | 1.51 |
| And their damage 6/6/7/8 → 5/5/6/7 | 58.3 s | 1.65 |
| The 300-match `soak:tune` on those numbers | 56.8 s (1,090 rounds, the longest 163.4 s) | 1.62 |
| 40 matches after merging `master`'s grip (KE tasks 5–8), the play build's rules | 65.3 s (157 rounds) | 1.75 |

Targets: 60–90 s rounds and 0.3–0.6 disarms. Almost every disarm is a parry landing on a fighter whose posture is full (about 12 parries and 530 frames at full posture a round), which the lights' numbers can't reach; on your word (Oct 7) the two changes stay, and disarms are left to the disarm family's review (family 7, task 85). The 300-match run had no failures, finishers in 49 of 1,090 rounds (4.5%), and every item of the must-appear list (the stomp 522, the leap 480, Flash 356, Moonsplitter 684, Breaker Palm 190, the recall 25, a pick-up 1,525).

## The play session

The exported build with the licensed clips is `build/windows/Monomachia.exe` in this lane's worktree (`.claude/worktrees/lane-m1-40-41-42`), exported on Oct 7 at the rebalance's numbers, after merging `master`'s grip (`docs/plans/katana-elden-ring.md` tasks 5–8: the grip button, pad Y or keyboard R, switches between one and two hands, and both grips play today's four lights, a fifth hit repeating Crown Cut, until the re-keys); its `--smoke` match plays clean. It stays on this PC. The match keeps the toon look until the art conversion; the look test shows the pilot in the realistic look.

What to play, and what to judge:

- **A Duel against the computer on Normal, then Hard**, Katana on both sides: the string's pace (each light about half a second to land), how each hit reads in its wind-up (checklist 6), the weight shifting through the step (7), the hands-off between the lights (11), and the light reactions, blocks, sparks, blood and smears in play.
- **Training**, to take the string one hit at a time: hit the dummy, then let it block and parry each light. Watch the deflect pairs, the recoil, and the push-in on every parry.
- **A listening pass** (story 176): each light's swing, the hit's flesh and bone, the block's steel, the parry's ring with the deflect pair's scrape, cloth and stagger, and the levels left open at task 136 (the scrape under the parry's contact, the recoil's whoosh).
- **The protected timings** this review freezes, the Katana's and bare hands' values in the spec's protected-timing table: a light's hitstun 24 (free 1–2 frames before the next light can land), blockstun 15, hit-stop 5 (a parry's 10, a Flash's 12), the parry recoil 26 frames with the guard back after 14, the parrier free after 7. To change one, name it and its new value: I change it, the spec's table and the frozen-timings test, rebuild, and you play it again (your answer, Oct 7). Once you're happy, they freeze.

## Trying the slimmed Studio

Story 32: the marker workflow proven on the pilot before the other families start. `npm run studio` (with the clip libraries), then:

1. Open **Right Cut** from the gallery. The side panel's verdict should read "in band", with each frame-data number against its timing band (✓) and the distance check's lines (17.2 cm in from 2.5 m, nothing from 3.25 m).
2. Scrub the timeline (click or drag; Space plays, Left and Right step a frame, L loops) and toggle foot locking. The rules ruler shows the startup, active and recovery bars over the band.
3. Move a marker: drag Right Cut's settle a frame later in the markers row (or set it in the Markers panel). The verdict and the numbers follow at once, and the title says "unsaved". Undo it (Ctrl+Z) and redo it (Ctrl+Shift+Z).
4. Open **Return Cut**'s Chain panel: its single part and range, with no speed field. Change its range, watch the fighter play the pending chain, then undo.
5. Leave without saving, or save (Ctrl+S) to see the regenerated table's report of changed and out-of-band moves; tell me if you saved, and I'll keep or revert the change and soak it.

Note anything that gets in the way of keying the next families.

## The verdict

Oct 7, 2026: **approved** by the owner (task 41), with no notes and no change to the protected timings. The protected timings are frozen at task 22's retune: the spec's protected-timing table and `test_protected_timings.gd` stand, and changing one now needs your OK and an entry in the spec. The pilot's owner columns (6, 7 and 17) are ticked on the approval. The clip rows' failures above stand as recorded; `docs/plans/katana-elden-ring.md` tasks 19 and 20 redo those clips for the new strings.
