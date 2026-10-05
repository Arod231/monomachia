# Reactions and movement review: authored animation

Oct 4, 2026 · `docs/plans/authored-animation.md` tasks 26–30b · lane `lane/aa-29-30-31` (draft PR Arod231/monomachia#21 into `feature/authored-animation`)

Every state a fighter can be in now animates from clips: the reactions (hits, blocks, long stuns, task 26), the parry (task 27), knockdown and KO (task 28), the legs (task 29), and the roll, the backstep, jump, land, the leap and the pick-up (task 30), with the recall's power-up burst you designed (task 30b). The rules still decide everything; the clips are fitted to their frames. This page is the review package. The video and the strips are local (under `shots/`, which git ignores); everything else is committed. **Your OK here gates the round flow (task 32).**

## What to look at

- **The video:** `shots/task31/review_video.mp4`, 2 minutes 40 seconds (`node scripts/review_video.mjs`; without ffmpeg on PATH it stays Movie Maker's AVI). Two computer-against-computer matches on Hard, as the match shows them (the camera, the effects, the HUD): the Rogue's Katana against the Hunter's Greatsword, then the Hunter's Daggers against the Rogue's Katana, 75 seconds each, so the reactions, rolls, knockdowns and the legs come up as they do in play. Then the recall's burst three times on purpose (it comes up about once in fifteen rounds): the Katana and the Greatsword recalled with the opponent in reach, and once out of reach.
- **Strips of every state on both fighters:** `shots/task31/hunter/` (the Katana) and `shots/task31/rogue/` (the Daggers; the carry strips with the Greatsword), one strip per drive, each frame captioned with what plays:
  - the legs: `rest_to_sprint`, `run_brake`, `sprint_brake`, `strafe_left`, `strafe_right`, `backpedal`, `back_left`, `sprint_away`, `turn_on_spot`, `stand`, the blocking walks (`guard_*`), `tap_steps`, `iai_walk`, `carry_walk`, `carry_lift`, `carry_guard`;
  - the roll and the states: `rolls`, `backstep`, `jump`, `dodge_attack`, `stomp`;
  - the reactions: `hit_reactions`, `block_reactions`, `stun_reaction`, `parry`, `knockdown`, `ko_light`, `ko_heavy`.
- **The recall's burst in the match's view:** `shots/task30b/burst_8.png` … `burst_25.png` (the aura building, the burst, the opponent blasted away).
- **The parry for every weapon pairing:** `shots/task27/`.

## The playtest

The package's half of it is the video above. Your half is a short match yourself: start the game (`/play`, or `node scripts/godot.mjs run`), pick Duel, and fight through a round or two. What to try:

- **Move:** walk, run and sprint every way round the opponent, a tap step each way, and a sprint held straight back (the body turns away and back).
- **Roll:** a roll each way, a backstep (dodge with the stick let go), and a light out of a roll (it comes up facing the opponent).
- **Get hit and block:** a light's and a heavy's hit, a block, a parry (block just before a hit lands), a long stun.
- **Knockdown:** an unblockable or a fully charged heavy into the opponent (or take one), then rise in guard.
- **The recall:** at 25% HP or less and disarmed, press the ultimate and choose light: the power-up, and the burst blasting the opponent away if they stand within your weapon's duelling distance.

## Decisions for you

1. **The turn on the spot is Turn01 laid on as a difference** (task 29). Standing, once the facing has turned 30° from where the feet were set, the legs step round on Turn01. As it comes, Turn01 stands upright with its feet together (its turn is in the root, which the import strips), and played as it is it snapped the combat idle's wide stance narrow on every turn. Laid on as its motion from its own first frame, the feet lift and step while the stance stays the idle's (`shots/task31/hunter/turn_on_spot.png`). **Recommended: keep it.**
2. **Setting off and stopping cross over in 6 frames** (task 29; the spec's locomotion crossfade). The rules' tap step reaches its speed in a single frame, and the combat idles stand wider and lower than the walks, so the legs snapped into the walk on every push of the stick. **Recommended: keep it.**
3. **The roll's getting-up ends upright** (task 30). Roll01 tumbles over the 16 travel frames on the timing the travel curve was read from (about 2.75×) and gets up over the 9 recovery frames (about 3.8×), as you chose, then stands upright and relaxed for a few frames as the legs fade back to the combat idle (`shots/task31/hunter/rolls.png`). The other way would be to fade to the idle from the middle of the getting-up. **Recommended: keep it as it is; judge it in play.**
4. **The stand-in guard over the combat idles** (task 29). With the guard stance retired, the free state's weapon is still posed by the stand-in (StickPose) until task 35 fixes it to the clips' hands; it now stands 9 cm lower and 4 cm further out than it did over the stance, so the Katana's blade clears the body. PoseCheck still finds the stand-in's wrists 22–33° sideways, and the Rogue's CombatIdle1H01 puts her left knee 4.5 cm inside the foot line (the clip's own). **Recommended: leave both for task 35.**
5. **The roll's sound** (task 30): three takes cut from the Sonniss bundle, a cloth tumble over a thump on stone (an instrument case set down on concrete, pitched down and low-passed), played on a roll; the backstep keeps the dash's swish and cloth. Nobody has listened to it yet. **Listen in the playtest; it joins the sound listening pass.**
6. **The recall's burst tuning** (task 30b, your design): the reach is the recalled weapon's duelling distance (Katana 2.5, Greatsword 3.0, Daggers 2.0 m), the knockback 2.0 m over 14 frames into a knockdown, 6 frames of hit-stop and a camera shake. **Confirm the look and the numbers in the video and the playtest.**

## Every state

| State | Clip | Timing | Built |
|---|---|---|---|
| Free, standing | The weapon class's combat idle (CombatIdle1H01 for the Katana and the Daggers, CombatIdle2H01, CombatIdle01) | On the rules' clock | 8, 29 (the Katana's guard stance retired) |
| Walk, run, sprint | Walk01 and Run01 ahead, back and on the diagonals, StrafeWalk01 and StrafeRun01 sideways, Sprint01 on the forward five | One shared step phase, the rate following each clip's measured stride; anchored at the walks' pace (2.2 m/s), the rules' run that way (3.9 / 3.5 / 3.0) and the sprint (7.2) | 29 |
| Sprint held backwards | Sprint01 forward, the whole body turned away | A spring of about a third of a second each way | 29 |
| Tap step | The walk the step's way | Half a cycle (one step) over the 8 frames | 29 |
| Turning on the spot | Turn01 Left or Right, as a difference over the idle | Over 30 frames, each 30° the facing turns | 29 |
| Shouldered (Greatsword) | ObjectGripShoulder02_R on the upper body | Faded in over 8 frames; the lift 6 | 18 |
| Roll | Roll01, the body turned toward the roll | The tumble over the 16 travel frames, the getting-up over the 9 recovery; turned in over 2 frames, back over the recovery or a dodge attack's first 3 | 30 |
| Backstep, the evade's back-dash | Dodge01's lean back (frames 0–12) | Over the travel, then on at 2.0 | 30 |
| Jump, land | Jump01_Begin from frame 5, Jump01's airborne frames, Jump01_Land from its touch-down | 2.0, 1.0, 2.0 | 30 |
| Leap | Jump01_Begin over the spring, then Fall01 | | 30 |
| Pick-up | Loot01_Begin to the ground on the attach frame, then Loot01_Stop | 2.0, then fitted | 30 |
| Recall | Power_Up (hand-keyed), with RecallAura's aura and burst | The recall's 26 frames, the burst on 16 | 30b |
| Hitstun | CombatDamage01 (a light's), CombatDamage02 (a heavy's) | Fitted to the hitstun | 26 |
| Held block, blockstun | The weapon class's Parry Loop and Parry Hit, on the upper body | Looped; fitted | 26 |
| Long stuns | Stun01; the stomped thruster Mikiri_Pinned | Fitted | 26 |
| Parry | The parrier's Parry Hit; the attacker's own clip run back, then Stun01 | The rebound over 8 frames at 2.0 | 27 |
| Knockdown | Knockdown01 Fall, Ground, StandUp | 2.0, looped, 2.0 from its frame 6 | 28 |
| KO | CombatDeath01–04 by the final blow's side and weight | 1.0 from the blow, slowed with the rules | 28 |
| Stomp | Mikiri_Stomp (hand-keyed) | Fitted | before 26 |

## Findings

- **The packs' walks are brisk** (2.2 m/s on both fighters), close to the rules' blocking walk (1.8–2.3 m/s), so a blocking walk is nearly all walk; an open run is all run. The sprint clips show 5.3–6.3 m/s, so the 7.2 m/s sprint plays them about 1.2× fast.
- **Kevin's diagonals are the forward and backward cycles turned**, the same feet at a slant, so the eight ways blend cleanly.
- **Rolling sideways near the opponent, the body turns past 90°** as the rules' facing follows the opponent while the roll goes straight (140° by the roll's end at 3 m).
- **The jump's landing is a deep crouch** (Jump01_Land's own) over the 5-frame land, then back to the idle over 6.
- **The hit reactions both recoil straight back** (task 26): no pack clip reacts to a hit's side, so they're picked by the hit's weight.
- **The roll's getting-up and Roll01's last frames are relaxed, not guarded** (task 1 found it); see decision 3.
- **The stand-ins still hold the weapon in the free state and the legs** until task 35 fixes it to the clips' hands; see decision 4.

## Checks

- `npm test` and `npm run typecheck` pass after each task (1,605 Godot tests and 150 web tests with this package), and CI's no-packs run falls back to the CC0 clips for every state.
- Planted feet held by the foot lock move under 1 cm running on a diagonal (`test_locomotion`).
- The 40-match soak after task 30b's rules change: 0 failures, rounds 42.6 s, Katana 46.7%, Greatsword 50.0%, Daggers 52.9%; tasks 26–30 change no rules data.
