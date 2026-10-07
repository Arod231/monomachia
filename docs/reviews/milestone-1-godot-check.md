# Milestone 1: the Godot check at the pilot and the look test

Oct 7, 2026 · `docs/plans/milestone-1.md` task 42 · branch `lane/m1-40-41-42` (pull request Arod231/monomachia#94)

The spec's Godot check (`docs/specs/milestone-1.md`, "The Godot check table", P31) asks whether Godot reaches the milestone's bar, judged on evidence: criteria 1–3 at the pilot family (animation), 4–6 at the look test scene (the look and performance), and 7–8 confirmed at sign-off. **Godot stays unless a criterion clearly fails and no fix inside Godot is in sight; then you decide.** Your OK here opens the art conversion (tasks 43–54).

The engine throughout: Godot 4.7.2, the official standard build (`4.7.2.stable.official.ed1daf0bf`), with no engine patch and no native extension. The project sets no renderer, so it runs Godot 4's default, Forward+.

## Verdict in short

| # | Criterion | Judged at | Result |
|---|---|---|---|
| 1 | The pilot passes the per-move checklist in the running game, its effects in the look test's look included: inertial blending, foot locking under 1 cm, the hands on the grips, no engine patch | the pilot | **passes** for the four lights; the pilot's reaction clips slide under the rules' knock, a keying matter with fixes inside Godot in sight (below) |
| 2 | The custom skeleton modifiers run in the rig's order every frame for both fighters, the rules unaffected | the pilot | **passes** |
| 3 | A clip goes from Blender to the game by the scripted export and import with no hand step, the same on two runs | the pilot | **passes** |
| 4 | The look test, beside the mood board, reaches its materials, volumetric fog, lighting and grade in your judgement | the look test | **passes**: you approved the look test (task 30, Oct 6) |
| 5 | The look test holds Ultra's gate with headroom: 99% of frames at 14 ms or less | the look test | **passes** on the RTX 3080, as you decided (Oct 7) |
| 6 | The features the milestone needs work on Windows under Forward+ | the look test | **passes** |
| 7 | No shader stutter after warm-up, no crash over a 40-match soak with the look loaded | sign-off | at sign-off (task 125) |
| 8 | All of the above on the finished build | sign-off | at sign-off (task 125) |

No criterion clearly fails. **Recommended: Godot stays.**

## 1. The pilot passes its checklist in the running game

- **The checklist:** the pilot's rows in `docs/reviews/milestone-1-checklist.md`, filled from a full test run (task 40) and reviewed by you (task 41). Right Cut, Return Cut, Kesa Cut and Crown Cut pass every item a test checks (1–5 and 8–16) and your three (6, 7 and 17). Among them:
  - foot locking under 1 cm (item 8): the worst planted-foot slide on any rules frame is 0.8 cm (Right Cut and Crown Cut), measured by PoseCheck on the posed rig through `MoveBench`;
  - the hands on the grips (item 10): the off hand stays on the Katana's grip on every rules frame of every light, deflect pair and the block, on both fighters (0.0 cm, `test_local_the_keyed_clips_keep_the_off_hand_on_the_grip`);
  - the effects (item 14): each light's hit draws blood, its block and parry throw sparks, its strike smears (`test_keyed_checklist.gd`), drawn in the look test's realistic look by the same `CombatEffects` and `AirSmear` layers (task 37, `test_look_test.gd`).
- **Inertial blending:** every hand-off blends inertially from the pose shown (task 23, the rig's first modifier; `test_inertial_blend.gd`, `test_clip_director.gd`'s blend requests), seen in the string's sheet and the play session.
- **What doesn't pass yet**, in the pilot's clip rows, reported and accepted at task 41: the light hit, block and recoil reactions' planted feet slide (7–99 cm) while the rules' knock moves the body, because those clips stand in place; three deflects start with the blade inside the parrier on their first frame; the recoils run 2 frames past the parry recoil. None is the engine's: foot locking holds the lights' own steps under 1 cm in the same rig, and the fixes are keying or rules choices inside Godot (keying the knock's travel into the reaction clips, or letting the foot lock re-plant under a knock; aiming the deflects' first frame; trimming the recoils), which `docs/plans/katana-elden-ring.md` tasks 19 and 20 take up as they redo these clips.
- **No engine patch:** the official build above; the rig's layers are GDScript `SkeletonModifier3D`s.

## 2. The skeleton modifiers run in order, the rules unaffected

- **The order:** every fighter's skeleton holds, after the clip: `InertialBlend` (task 23), `PhysicalReactionLayer` (task 70), `BodyLayer`, `RigPre`, `RightArmIK`, `LeftArmIK`, `LegIK` (with the foot lock), `RigPost`, `HandGrip` (the hands' grip) and `RigCarry`; `test_fighter_rig.gd::test_the_rig_stacks_its_modifiers_in_order` pins it.
- **Every frame, both fighters:** in a match each fighter's skeleton runs its whole stack every frame through Godot's own modifier process callback; the tests step it by hand instead and read each pose only once the stack has run (`PoseCheck.frame_of()` waits for `RigCarry`'s `modification_processed`), on both the Hunter and the Rogue.
- **The rules unaffected:** `game/sim` holds no node, clip or modifier (the rules are graphics-free, the plan's Notes), and two tests run seeded computer matches shown with a layer on and off and step to the same state hash: `test_fighter_view.gd::test_the_rules_are_the_same_with_inertial_blending_off` and `test_the_rules_are_the_same_with_the_reaction_layer_off`.

## 3. Blender to the game, scripted, the same on two runs

- **The export:** `npm run export -- --check` on Oct 7 re-exported all 27 sources the asset repository's `blender/sources.json` lists (the pilot's lights, guard, bridges, returns to guard, deflect pairs and reactions) with Blender headless, and compared each with its committed export and record byte for byte: "nothing would change". So a second run of the export gives the same files as the first.
- **The import:** `npm run godot -- clips` builds the clip libraries from those exports and the packs with no hand step. Run twice on Oct 7 over the same exports, it wrote the same libraries byte for byte (123 clips a set; SHA-256 `24c77e18…` for HumanM and `66f2b925…` for HumanF both times), as task 2 first showed for the packs.
- **No hand step anywhere:** the re-keys are `scripts/blender/rekey_clip.py` runs from committed specs (`scripts/blender/rekeys/`), the export and import are the two commands above, and the frame-data table is generated from the clips (`npm run godot -- bake`), its digests held by `test_frame_data_table.gd` and its re-bake by `test_local_every_move_matches_a_fresh_bake`.

## 4. The look beside the mood board

Your judgement, given at task 30 (Oct 6): you approved the look test scene as built, its lighting, camera effects and Camera 2's framing included, beside the approved mood board (the asset repository's `moodboard/`). Its materials (physically based, `LookMaterials`), volumetric fog with a ground mist, the night's lighting (the moon's cold key, the lanterns, a key and rim on fighters only) and the grade are `test_look_test.gd`'s. Since then the pilot's sparks and smears were added to it (task 37) and reviewed in shots beside it.

## 5. The look test's frame times

`npm run bench:look` on Oct 7, with the pilot's sparks and smears now in the scene: 3840×2160 output at Ultra (67% with FSR 2.2), 600 warm-up frames then 1,800 timed, on this PC's NVIDIA GeForce RTX 3080 under Vulkan and Forward+:

| | Oct 6 (task 30) | Oct 7 |
|---|---|---|
| 99th percentile | 6.95 ms | **6.04 ms** against the 14 ms gate |
| Frames within 14 ms | 100% | 100% |
| Mean / worst | 4.41 / 11.88 ms | 4.23 / 7.47 ms |
| GPU / CPU mean | 3.74 / 0.54 ms | 3.64 / 0.56 ms |

The gate holds with more than half its budget left for the second fighter and the effects. As you decided (Oct 7), the RTX 3080, the slower card, stands for the RTX 3090; the 3090's run is confirmed at sign-off (criterion 8).

## 6. The features under Forward+ on Windows

Each is built and checked in the look test (`test_look_test.gd`, run on this PC under Windows and Forward+):

| Feature | In the look test |
|---|---|
| Volumetric fog | the environment's volumetric fog in the mist's colour, and a ground mist volume |
| Decals | a damp stain and moss |
| GPU particles | dust in the moonlight |
| Temporal anti-aliasing | Godot's TAA with `--aa=taa` |
| FSR 2.2 | Ultra's 67% render scale upscaled by FSR 2.2 (the default) |
| Spring bones | the sageo cord and tassel on the saya, swinging as the saya moves |
| Skeleton modifiers | the fighter's rig (criterion 2) |

Every one renders in the look test's shots and runs inside its frame time (criterion 5).
