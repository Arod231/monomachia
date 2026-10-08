---
tags: [architecture, presentation]
---

# Fighter animation

- **Bodies:** each fighter is a scene built from the Quaternius base body, outfit parts, hair, headwear built in code and a palette, all on a shared 65-bone skeleton. Animations are retargeted through Godot's humanoid bone map.
- **Movement:** walk, jog, sprint, idle, jump, flinch, knockdown and death clips from the packs, blended by speed on one shared step phase so the feet stay planted. Strafing and backpedalling turn the hips toward the direction of travel while the chest keeps facing the opponent.
- **Guard walking**, where duels spend most of their time, is a procedural shuffle: the lead foot moves first, the trailing foot closes, and the feet never cross.
- **Lean:** follows acceleration, up to 11°: forward when setting off, into turns, and back when braking.
- **Weapons:** a weapon is never fixed to a hand. It's posed in the fighter's space by its [[Weapon swings|swing]], and the arms reach for it with inverse kinematics; each fist curls round its own handle.
- **Attacks:** the swing that decides hits also moves the weapon on screen, with the torso and hips coiling and the feet stepping with the lunge. The free packs have no weapon attacks, and one path for hits and visuals keeps them in sync.

Procedural animation is less expressive than hand-keyed clips, so the authored-animation plan ([[Plan - Authored animation and the dodge roll]]) is replacing moves, reactions, knockdowns and KOs with authored clips while keeping the rules unchanged. It retired the rebuild plan's task 15 (full fighter animation) and 14b (the swing editor). Clips play on the rules' clock and hold still in hit-stop.

## Animation leads (Oct 4)

On Oct 4, 2026 the owner reversed the premise that the rules stay in charge and the clips are fitted to them (`docs/adr/0001-animation-leads-realistic-look.md`). Each attack's frame data and footwork now come from its clip, edited until it lands inside the attack's [[Timing band]], and nothing speeds up, slows down, freezes or stretches a clip while the game runs. No fighter slides further than its clips step, and holds such as the charged heavy's are authored loops.

- Only the protected timings stay set by the rules (the parry window, the input buffer, the dodge and backstep, hitstun, blockstun, hit-stop and the knockdown phases), and the clips that show them are made to fit. Jump arcs also stay rules numbers.
- The authored-animation plan closes after its task 30b; its draws, victories and the retiring of the stand-ins move into the slice spec.
- New parts of the bar: directional hit reactions with a physical layer, a matched deflect pair for each attack direction, paired clips for counters and the Impaler, cancels marked on each clip, and inertial blending with authored transitions.
- Capes, coats and other loose clothing are cloth-simulated, and the final models share a UE5-style skeleton with twist bones.
- **Gaits (milestone-1 task 55, Oct 8):** the rules move a fighter at its walk, run and sprint clips' own measured speeds (the pace a planted foot sweeps at, committed in the frame-data table), so the gait clips play at 1.0× and the feet stay put. A partial tilt of the stick walks and a full tilt runs. The right strafes are the left ones mirrored and the backward run is re-keyed slower than the forward one. The packs' walks and strafes still slide more than the 1 cm checklist allows; task 62 takes that up.
- **Guarded cycles (milestone-1 task 56, Oct 8):** blocking (or in the Iai stance), the Katana walks on its own guarded shuffles (okuri-ashi, forward and back) and strafes, four ways blended every 90°, at their measured speed (60% of the run) whatever the tilt; a disarmed fighter walks on bare hands' guarded cycles. They are legs and hips only: the block plays over them on the upper body. Keyed through Cascadeur with every frame a key, since the AI inbetweening moves planted feet, and each step lifting its foot 16 cm in place (high enough that FootLock's 4-frame ease-out lifts the shown foot past 6 cm before it moves), travelling while up and setting it down in place, so FootLock's ankle rule (lifted above 6 cm, planted within 3 cm) never drags a planted foot.
- **Momentum:** starting a run, stopping and turning take their clips' time and distance, with the weight visibly shifting, and the rules move the fighter as the clip does. Attacks, dodges, backsteps, parries and blocks still start at once out of any movement.

Plan: [[Task 13]], [[Task 14]] · [[Stage 8 - Fighter animation core]] · [[Stage 13 - Full animation]]

**Sources:** [[Rebuild spec - Implementation Decisions]] · [[Rebuild plan notes 13-15-fighters-and-animation]] · [[Animation spike (Sep 30, 2026)]] · code in [[game.view.fighter]] · see [[Roster]]
