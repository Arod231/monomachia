**Verdict: yes, this approach is good enough to build the game on.** Weapon paths on the Quaternius Rogue give believable arcs. Both hands stay on the grip in every captured frame (the IK lands each wrist within 1 mm of its target). The body visibly twists with each swing, the hips lead it, and the cut is driven from the legs. Two problems need fixing before the moves are built: the blade can't reach a defender standing 2.5 m away, and the camera numbers in the spec hide the opponent behind the player. Animation-wise it reads as solid game animation, not hand-keyed AAA work.

Everything is in `<scratch>/spike-anim\`. The project is in `proj\`, all screenshots are in `shots\`, and the repo and Downloads were not touched.

## (a) Screenshots

| Milestone | File in `shots\` | What it shows |
|---|---|---|
| 1 Fighter | `m1_fighter_rest_idle.png` | rest pose front and 3/4, then the retargeted UAL Idle front and 3/4 |
| 1 Fighter | `m1_head_Hair_Long.png` | close-ups of head cut, hood and hair: front, 3/4, back 3/4 |
| 2 Locomotion | `m2_strafe_left.png` | strafing left at 2.3 m/s, legs turned 80°, chest facing forward |
| 2 Locomotion | `m2_backpedal.png` | backpedal at 2.0 m/s (walk cycle reversed) |
| 2 Locomotion | `m2_back_left.png` | moving back-left at 135° (legs turned −45°, cycle reversed) |
| 2 Locomotion | `m2_run_lean.png` | accelerating to 3.9 m/s with lean, then braking |
| 2 Locomotion | `m2_guard_strafe_left.png`, `m2_guard_backpedal.png` | the real use case: crouched guard walk with the katana held by IK |
| 3 Guard | `m3_guard.png` | guard front, 3/4 right, 3/4 left, side |
| 3 Guard | `m3_grip_close.png` | close-ups of both hands on the grip |
| 3 Guard | `dev_grip_sweep.png` | dev only: comparison of hand-roll angles used to choose the grip |
| 4 Right Cut (R→L) | `m4_cut1_RtoL_34.png` | 3/4 side camera, 12 frames |
| 4 Right Cut (R→L) | `m4_cut1_RtoL_ots.png` | over-the-shoulder at spec framing (0.9 m right) |
| 4 Right Cut (R→L) | `m4_cut1_RtoL_ots_wide.png` | over-the-shoulder at 1.4 m right |
| 4 Right Cut (R→L) | `m4_cut1_RtoL_close.png`, `m4_cut1_RtoL_hands.png` | close views of the attacker and of the hands |
| 4 Return Cut (L→R) | `m4_cut2_LtoR_34.png`, `_ots.png`, `_ots_wide.png`, `_close.png`, `_hands.png` | same set of views for the second cut |
| 5 Look | `m5_guard_guard_close.png`, `m5_guard_ots.png` | guard pose in the toon look |
| 5 Look | `m5_contact_cut1_34.png`, `m5_contact_cut1_ots.png`, `m5_contact_cut1_ots_wide.png` | contact frame (f13) of the Right Cut |
| 5 Look | `m5_contact_cut2_34.png`, `m5_contact_cut2_ots.png`, `m5_contact_cut2_ots_wide.png` | contact frame (f12) of the Return Cut |
| 5 Look | `m5_cut1_sheet_34.png` | 12-frame sheet of the Right Cut in the toon look |
| 5 Look | the same `m5_*` names ending `_d2.0.png` | defender at 2.0 m instead of 2.5 m, so the blades actually meet |

Each contact sheet has 12 frames captured at 60 fps sim time. The Right Cut frames are 0, 3, 6, 9, 10, 11, 12, 13, 14, 17, 22, 30. The Return Cut frames are 0, 3, 5, 7, 9, 10, 11, 12, 13, 16, 21, 29.

## (b) What worked and what didn't

**1. Fighter assembly: worked.**
- The head-only cut keeps 3,020 of the body's 12,812 triangles. The hood and collar hide the neck seam, and there is no body showing through the outfit.
- The female outfit parts share the body's rest pose exactly, so there are no offsets.
- Hair_Long sits under the hood without clipping. Its texture is white, which turned out to be a strong silhouette accent.
- The darker Rogue colours are a generated texture, `T_Rogue_BaseColor.png`, made from the unreferenced `T_Ranger_3` texture: cream cloth turned to slate, ochre to oxblood, leather darkened.
  - My first version used hard colour thresholds and came out patchy. Soft per-pixel weights fixed it.

**2. Locomotion: worked.** Strafing, backpedal and lean all read correctly in stills.
- A plain BlendSpace would mix walk and jog with their feet out of step. Fixed by setting both clips' playback position every frame from one shared step phase.
- Guard walking first looked like an upright casual walk. Lowering the hips 8.5 cm and re-planting the clip's feet with leg IK gave a proper crouched guard walk.
- The 80° leg turn produces a forward walk seen sideways, not a true side-step.
- The reversed walk is fine in stills but will probably look slightly "moonwalky" in motion.

**3. Guard: worked, after one failed attempt.**
- My first hand orientation followed the forearm direction. Both palms ended up facing up and the left hand sat under the handle.
- Fixed by locking each hand's orientation to the handle, as on a real grip.

**4. The two cuts: worked.**
- The wind-up over the right shoulder, the 3-frame strike and the follow-through to low left all read clearly.
- The Return Cut starts from the exact end pose of the Right Cut, including turning the edge over.
- **Reach problem.** The blade tip only gets 1.35 m in front of the fighter's root. With the opponent at 2.5 m and a 0.35 m step, the tip falls 0.63 m short of the defender's body capsule on the first cut and 0.21 m short on the second. At 2.0 m the blades meet (the `_d2.0` shots).
- **Camera problem.** At the spec's 0.9 m side offset, the player hides the opponent's torso at 2.5 m. A 1.4 m offset fixes it (`ots_wide`).

**5. Look: worked.**
- Three-band toon ramp, ink outlines on fighters and katana, dark sky, moon light plus a rim light.
- Also added: vermilion pillars, lanterns, distant mountain silhouettes, fog and a vignette.
- Normal maps make the band edges noisy, so I turned them off on the face and halved their strength elsewhere.
- The hood shaded the whole face, so it no longer casts shadows.
- Orange lantern light was over-saturating the skin, so I toned it down.

## (c) Techniques that worked

- **Head-only cut** (`tools/cut_head.gd`)
  - Find the skin entries for the Head and Neck bones.
  - Keep a triangle only if every one of its vertices has at least 0.5 of its weight on those two bones.
  - Compact the vertex arrays and save as `gen/head_only.res`; the original skin binding still works.
  - Drop the CUSTOM0/1 vertex arrays: re-adding them without format flags makes the surface fail to build.

- **Retargeting**
  - `tools/make_bonemap.gd` builds a BoneMap for SkeletonProfileHumanoid (53 bones mapped).
  - Add it to every scene's `.import` file under `_subresources` → `PATH:Armature/Skeleton3D` → `retarget/bone_map`, then reimport headless. That covers UAL1, UAL2, the body, all outfit parts and the hair.
  - The skeleton becomes `GeneralSkeleton` with bones renamed and rests normalised, so the clips play correctly on the body.
  - The UAL animation libraries are shared into the character's own AnimationPlayer with `add_animation_library("ual1", lib)`.
  - All outfit and hair meshes are reparented under the body's skeleton with `skeleton = ".."`. Their skins bind by bone name.

- **IK setup** (`src/rig.gd`)
  - Two separate TwoBoneIK3D nodes, ArmIK and LegIK, so arms and legs can be blended independently with `influence`.
  - Each has `setting_count = 2`, bones UpperArm/LowerArm/Hand and UpperLeg/LowerLeg/Foot, and target and pole marker nodes that are children of the skeleton.
  - `set_pole_direction(i, SECONDARY_DIRECTION_MINUS_Z)` works for both elbows and knees on this skeleton. Arm poles sit at each shoulder + (±0.30 out, −0.55 down, −0.35 back) in chest space, with per-key offsets for crossing poses. Knee poles sit at the foot + 0.5 m up + 0.7 m along the foot.
  - TwoBoneIK3D only places the wrist; it does not rotate the hand.
  - A modifier after the IK sets the hand rotation, curls the fingers around the handle (62°/88°/48° by joint) and adds a thumb wrap.
  - Hand frame, fixed to the weapon: thumb toward the tip, knuckles toward the edge, rolled 25° about the handle and tilted 28° so the handle crosses the palm diagonally. Wrist target = grip point − hand rotation × (0, 0.064, 0.026).
  - The forearm takes 50% of the wrist twist, since the rig has no twist bones.
  - The shoulder girdle swings forward up to 18° when a target is beyond 90% of arm length.

- **Hip-turn strafing**
  - Leg angle = travel direction relative to facing, clamped to ±80°. Beyond ±100° (with 10° hysteresis) it switches to travel − 180° and runs the cycle backwards. Smoothed with a spring.
  - The pelvis takes 70% of the turn; the thighs take the rest at the hip joints.
  - The chest keeps facing the opponent: spine twist = chest yaw − pelvis yaw, spread 28/36/36% over Spine/Chest/UpperChest.
  - Lean rotates the Root bone (so the pivot is at the ground) toward smoothed acceleration: 0.014 rad per m/s², at most 11°.

- **Procedural bones after the AnimationTree**
  - Subclass `SkeletonModifier3D`, override `_process_modification_with_delta(delta)`, and add it as a child of the Skeleton3D. Child order is run order:
    1. BodyLayer (pelvis and thighs turn, foot positions recorded, pelvis drop, spine and head)
    2. RigPre (computes IK targets and poles)
    3. ArmIK
    4. LegIK
    5. RigPost (hands, fingers, feet)
  - RigPre and RigPost are one small callback modifier class, so one script can run on both sides of the IK nodes.
  - Every rotation is applied with a helper, `rot_global`, that converts a skeleton-space rotation into the bone's local pose. Parents go first; `get_bone_global_pose` already reflects earlier edits in the same pass.
  - Poses don't accumulate between frames.
  - The AnimationTree runs in MANUAL mode with `tree.advance(dt)` called each sim frame.

- **Weapon path arcs** (`src/swing.gd`)
  - Each key holds: frame, right-hand grip point, blade direction (azimuth/elevation), and an edge direction (explicit or "lead", i.e. facing the way the blade moves).
  - Interpolation is a cubic Hermite spline with Catmull-Rom tangents in time. Keys marked ease 0 have zero speed: start, the cocked wind-up, the settle.
  - The grip offset from the sternum pivot (0, 1.25, 0.05) is splined, then renormalised, with the radius splined separately. That makes the hands sweep around the body instead of moving in straight lines.
  - Blade and edge directions are splined unit vectors, renormalised, with the edge kept at right angles to the blade.
  - Body drive (`attack_driver.gd`):
    - Chest yaw is −0.5 × the grip's angle around the pivot.
    - Pelvis yaw is −0.32 × the same angle sampled 2 frames ahead, so the hips lead.
    - Pitch and side bend are keyed.
    - The head counter-turns 85% to keep looking at the opponent.
    - The pelvis dips 5 cm around the contact frame.
  - Footwork: the root lunges 0.35 m, the front foot steps (7 cm lift), the rear foot follows, and leg IK keeps feet planted in the world otherwise.
  - The trail ribbon is sampled at quarter frames from the same path.

## (d) Problems still visible, and what would help most

**Still visible:**
- The 80° hip turn is not a real side-step.
- The reversed walk may slide visually in motion.
- The edge turns over in about 4 frames at the start of the Return Cut; forearm twist is still visible.
- No secondary motion: hood and hair are rigid, and there's no blade lag, hit-stop or settle overshoot.
- I didn't measure blade-to-body distances; at the top of the Right Cut wind-up (f6) the blade passes very close to the hood.
- Normal-mapped toon bands are noisy on the clothes.
- The dark Rogue colours are low-contrast at night and rely on the rim light and outlines.
- Floor and props are placeholders.
- Performance on this integrated GPU was not measured.

**What would improve it most, in order:**
1. A small in-editor tool to scrub frames and drag path keys and poles. Quality now depends almost entirely on key tuning.
2. Overlap and weight: blade lag behind the hands, follow-through overshoot, hit-stop and camera push, and spring bones for hood and hair.
3. Fix the reach: lunges of about 0.7–0.8 m, a closer duel spacing, or more arm extension at contact.
4. Real strafe and backstep clips when available, keeping the hip-turn method as the fallback.
5. Change the spec's camera offset to about 1.3–1.4 m, or add a slight yaw.

TwoBoneIK3D itself needed no workarounds.