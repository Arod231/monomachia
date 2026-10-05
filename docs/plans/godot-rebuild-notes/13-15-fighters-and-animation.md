> Research notes from the Oct 1, 2026 task breakdown, a snapshot of the code at 51dcfb0.
> The plan (`docs/plans/godot-rebuild.md`) is the source of truth: its task ids, order and decisions
> supersede the proposals and keys here. Line numbers drift as the code changes.

# Plan tasks 13 (merge fighters-and-weapons), 14 (fighter animation core), 14b (swing editor) and 15 (full fighter animation)

## Current state
TASK 13 BRANCH (worktree .claude/worktrees/wf_416c4a7b-d50-1, branch fighters-and-weapons, commits 1f574a2 + fcfb8d8 on base f061145):
- Never pushed (no origin branch), so CI has never imported its assets. 206 files, about 32.6k lines, 42.9 MB of assets: game/assets/quaternius (UAL1/UAL2 GLBs, ual_library.res with 39 clips, both bodies, Ranger outfits, three hairs, ual_bone_map.tres), game/assets/weapons (Dagger.fbx, Sword_Big.fbx) and game/assets/CREDITS.md.
- Runtime code: game/fighters/fighter_model.gd (FighterModel: skeleton from the first outfit part, %GeneralSkeleton, AnimationPlayer with library 'ual', BoneAttachment hand sockets RIGHT_SOCKET/LEFT_SOCKET, attach_weapon() into the sockets, apply_palette(), play_idle()), fighter_look.gd (FighterLook, IDS rogue/hunter, holds, palettes, instantiate_fighter()), fighter_palette.gd, hand_grip.gd (HandGrip SkeletonModifier3D: fist curl 78/88/50 degrees, thumb wrap, set_wrist() from rest) and weapon_hold.gd (WeaponHold: a per-weapon stand-in idle clip, reverse grip, blade tilt and set wrists, 'until the guard poses of task 14').
- game/weapons/weapon_look.gd (WeaponLook: origin = main grip, +Y blade, +X edge; markers BladeBase/BladeTip/OffHandGrip; two_handed, paired, trail_width). Katana: tip at y 0.777, OffHandGrip at y -0.15, two_handed. Greatsword: 1.72 m, two_handed. Daggers: paired.
- Tools in game/tools: import_assets, build_bone_map, cut_heads, build_animation_library, bake_palettes, bake_skins, build_headwear, build_katana, build_pack_weapons, texel_map, inspect_scene.
- game/fighters/preview/preview.tscn has a --mode=sheet that stitches review sheets (_save_sheet).
- Tests in game/tests/content: test_fighters (includes test_no_blade_points_into_its_fighter, which measures blade points against bone capsules), test_weapons, test_animation_library, test_asset_budget (10 MB per file, 60 MB in all) and test_palettes.
- Six new class names (FighterLook, FighterModel, FighterPalette, HandGrip, WeaponHold, WeaponLook), none of which collide with master's.

MERGE PREVIEW (read-only `git merge-tree f061145 feature/godot-rebuild fcfb8d8`):
- Exactly two conflicts, both in docs:
  - docs/plans/godot-rebuild.md: the branch ticks 13 and adds 'Done' notes, but its text still names the old 'task 14. Animation spike';
  - docs/specs/godot-rebuild.md, 'Presentation of fighters': master's shuffle-step, stance and brace bullets against the branch's headwear, palette-wear and stand-in-hold bullets.
- These merge cleanly:
  - the spec table: the branch's Fighters and Weapon models rows sit beside master's new Camera row;
  - scripts/godot.mjs: master's parse-error and soak checks, plus the branch's `shots` forwarding extra scene args such as --mode=sheet;
  - game/tools/shot.gd: the shot_ready guard goes from 600 to 6000 frames;
  - .gitattributes (*.bin binary), GLOSSARY.md (Palette entry) and game/project.godot (the branch doesn't touch it; master added the GameServices autoload).
- Moves.PLAYABLE_WEAPONS (katana, greatsword, daggers) matches WeaponLook.IDS. MatchSide.palette is 0 or 1 per side, which matches FighterLook.palettes (exactly two).

VIEW CODE TODAY (game/view/match):
- MatchView builds two FighterStandin from res://view/match/fighter_standin.tscn in _on_match_started and calls setup(fighter_id, palette, weapon_id, side). Every frame it calls update_fighters(): update_from(f, host.display_position(i), host.display_yaw(i), host.alpha(), delta, _time). On events it calls flash(color, strength, world.frame).
- FighterStandin (297 lines): a capsule plus stick weapon posed by StickPose. Its PALETTES/BLADE_COLOR constants are also used by MatchView._make_dropped (box sticks sized by StickPose.LENGTH) and by game/ui/menus/results_screen.gd lines 45-46.
- StickPose (510 lines): the demo's ARCH keys (wind-up, impact, follow-through) per anim, GUARD and BLOCK per weapon, reels, KO fall. It interpolates on the fractional frame at.frame - 1 + alpha.
- Tests that name the stand-ins: tests/view/test_stick_pose.gd (FighterStandin mesh checks), test_match_scene.gd (last_pose, flash_left) and test_match_host.gd line 251 (StickPose.compute).
- MatchHost holds alpha() at 1 through hit-stop. CameraRig follows at 4.6 m back, 1.35 m side and 1.95 m up, swinging out by 0.8 m per metre inside 3.5 m.
- The rules' Fighter exposes pos, vel, yaw, state, sf, atk (AttackState.frame, def.lunge/lunge_start/lunge_end) and blocking. Speeds come from game/sim/constants.gd: run 3.9, strafe 3.5, back 3.0, sprint 7.2 m/s, blocking multiplier 0.45 (task 8 makes it 0.60). ARENA_RADIUS is still 11.5.
- No swing data exists yet: task 7 adds it under game/sim, and the moves are still the demo's GDScript dicts in game/sim/moves/*.gd.

SPIKE CODE (scratchpad\prior\spike-anim):
- swing.gd: keys holding frame, grip point, blade azimuth/elevation and an edge (explicit or 'lead'). It uses Catmull-Rom Hermite splines, ease 0 for holds, and swings the grip on an arc round the pivot (0, 1.25, 0.05), with the radius splined separately. The blade direction is splined on its own, which is the cause of the critique's propeller and wrist-flip flaws.
- attack_driver.gd: chest yaw = -0.5 x grip azimuth and pelvis = -0.32 x the azimuth 2 frames ahead (clamped at 55 and 40 degrees), so the coil is not keyed. The head counter-turns 85% and the pelvis dips 5 cm. The driver moves the fighter root itself by a 0.35 m lunge; in the game the rules own the root.
- rig.gd:
  - modifier order: BodyLayer, then RigPre (callback), ArmIK (TwoBoneIK3D x2), LegIK, then RigPost;
  - hand frames locked to the handle (roll 25, tilt 28 degrees), with palm offset (0, 0.064, 0.026);
  - grip_y R -0.058 / L -0.196 measured from the tsuba, and arm_len 0.4895, all measured on the female body only;
  - the forearm takes 50% of the wrist twist, and the clavicle protracts up to 18 degrees;
  - pole directions use SECONDARY_DIRECTION_MINUS_Z;
  - knee poles at the foot + 0.5 m up + 0.7 m along the foot, which caused the critique's knock-knees.
- body_layer.gd: rot_global, and a spine split of 28/36/36 over Spine, Chest and UpperChest.
- fighter.gd:
  - clip phase sync uses CLIPS walk 0.98 m/s with a 1.30 m stride, jog 5.36/5.00 and sprint 8.25/5.50 (measured by tools/foot_phase.gd);
  - hip-turn: clamp ±80 degrees, switch to backwards past ±100 with 10 degrees of hysteresis, spring ω 12, a 70/30 pelvis/thigh split;
  - lean of 0.014 rad per m/s², capped at 11 degrees;
  - an 8.5 cm crouch.
- The critique's 10 fixes and 7 conditions are hard requirements for 14, 14b and 15.

WHAT CAN START BEFORE TASK 7: only the merge (13). Everything else in 14 can start then (rig, real fighters in the match, pose checks, contact-sheet tool, locomotion, hip-turn, lean, stance, shuffle step); it needs only 13 plus the task 6 host already merged. Everything that plays a swing needs task 7's swing data and, through 7, task 9's final Katana moves. That covers swing playback, chains, coil, footwork, string keying, thrust and sweep, blade lag and the parry bounce. All of 14b except the plugin shell, and all of 15, also wait for 7.

SURPRISES:
- The spike moves the root for lunges, which is not allowed: the rules' position is authoritative.
- The branch holds weapons in hand sockets (WeaponHold), the opposite of the swing approach, where the path places the weapon and the arms follow on IK.
- game/tools/typecheck.gd skips res://addons, so an editor plugin placed there would not be type-checked.
- The current moves live in GDScript const dicts, which an editor can't safely write back.
- The spec's out-of-scope list excludes victory poses, while plan task 15 lists 'victory'.
- The Katana model has no scabbard, which the Iai sheathe needs.

## Tasks

### [13] 13-merge (M): Merge the fighters-and-weapons branch
- delivers: fighters-and-weapons (1f574a2, fcfb8d8) merged into feature/godot-rebuild with a merge commit, as tasks 5 and 6 were | docs/plans/godot-rebuild.md: master's restructured tasks 14, 14b and 15 kept; task 13 ticked, with the branch's 'Done' and art-review notes in place of its Progress line; the Progress section updated | docs/specs/godot-rebuild.md: master's Camera row kept, the branch's Fighters and Weapon models rows taken; in 'Presentation of fighters', master's locomotion, shuffle-step, stance and brace bullets kept, the branch's headwear, palette-wear and stand-in-hold bullets added, and the branch's older strafing and lean bullets dropped | auto-merged and checked: scripts/godot.mjs (shots forwards scene args, and master's parse-error and soak checks stay), game/tools/shot.gd (shot_ready guard 6000), .gitattributes (*.bin binary), GLOSSARY.md (Palette), game/assets/CREDITS.md | a code review of the branch's runtime scripts (fighter_model.gd, hand_grip.gd, weapon_hold.gd, weapon_look.gd, fighter_look.gd), with fixes for any findings | after the merge, the fighters-and-weapons worktree and local branch are removed
- check: npm run godot -- import is clean in headless (no missing textures or import errors) | npm test passes: the 382 existing Godot tests plus game/tests/content (fighters, weapons, animation library, asset budget, palettes), and the 112 web tests | npm run typecheck loads every script, including the branch's game/tools scripts | npm run shots -- res://fighters/preview/preview.tscn <out.png> 30 --mode=sheet --sheet=<dir> renders, and the sheets match the art-reviewed ones in the old fighters-shots/v2 folder | the first CI run after the push passes (it is the first CI import of the 42.9 MB of assets)
- depends: 
- stories: 43, 44, 45, 63
- files: docs/plans/godot-rebuild.md, docs/specs/godot-rebuild.md, scripts/godot.mjs, game/tools/shot.gd, .gitattributes, GLOSSARY.md, game/assets/**, game/fighters/**, game/weapons/**, game/tests/content/*.gd, game/tools/*.gd (branch tools)
- notes: A read-only merge-tree run confirms only the plan and the spec conflict. The branch predates the GameServices autoload and tasks 3 to 6, so its tests have never run alongside them: run the whole suite. Nothing changes in game/view yet; the Duel still uses the capsule stand-ins.

### [14] 14-rig (M): Fighter rig: the skeleton modifier stack
- delivers: typed production versions of the spike's body_layer.gd, rig.gd and cb_modifier.gd under game/view/fighter/ (new): BodyLayer (root lean, pelvis and thigh yaw, hips offset, spine yaw/pitch/roll over Spine/Chest/UpperChest at 28/36/36, head yaw/pitch, rot_global), and FighterRig with a RigPre callback, ArmIK and LegIK (TwoBoneIK3D, two settings each, SECONDARY_DIRECTION_MINUS_Z poles) and a RigPost callback (hand frames locked to the handle, 50% of the wrist twist on the forearm, clavicle protraction up to 18 degrees near full reach) | the branch's HandGrip runs last for the fingers, with its WeaponHold wrist-setting off whenever IK drives a hand | the weapon placed in fighter space by a pose (set_weapon(grip, blade_dir, edge_dir)) under the FighterModel, not in a hand socket; grip points come from WeaponLook (origin for the main hand, OffHandGrip for the off hand of two-handed weapons, two transforms for paired daggers) instead of the spike's grip_y constants | per-limb influence (arm_w, leg_w, each hand on or off); arm length and pole offsets read from each fighter's skeleton (no 0.4895 constant), so the Hunter's slimmer outfit skeleton works | a FighterModel hook to install the rig, and a shot scene posing both fighters in a katana guard
- check: new GUT test game/tests/view/test_fighter_rig.gd: on the Rogue and the Hunter with the katana in a guard pose, each wrist lands within 1 cm of its target and each grip centre within 1 cm of its WeaponLook grip point | the same input twice gives the same bone poses (no accumulation between updates) | a one-handed weapon leaves the off hand free; the greatsword's off hand reaches OffHandGrip; paired daggers fill both hands | screenshots of the guard grip (front, three-quarter, hands from below and the side), reviewed for palms against the handle (spike guard failure) and tight fingertips (critique fix 14) | npm test and npm run typecheck pass
- depends: 13-merge
- stories: 43, 44
- files: game/view/fighter/body_layer.gd (new), game/view/fighter/fighter_rig.gd (new), game/view/fighter/rig_callback.gd (new), game/fighters/fighter_model.gd, game/fighters/hand_grip.gd, game/tests/view/test_fighter_rig.gd (new), game/tools/shot_scenes/fighter_guard.tscn (new)
- notes: Can start before task 7. Tests should step the skeleton deterministically, either with the skeleton's manual modifier mode or by awaiting frames as test_fighters.gd does. The match still uses the stand-ins after this task.

### [14] 14-in-match (M): Real fighters in the match
- delivers: FighterView (game/view/fighter/fighter_view.gd, new) replaces FighterStandin in MatchView: the side's fighter via FighterLook.instantiate_fighter(fighter_id), its palette from MatchSide.palette, its WeaponLook model(s) (none when bare or disarmed), placed from host.display_position/display_yaw | until swings exist, posed by StickPose: the hand positions and blade directions become the weapon transform, FighterRig's IK places the arms, and the two-handed off hand goes on OffHandGrip; lean, crouch, spin and the KO fall go through BodyLayer and the root; the idle under the arms is the WeaponHold clip | the body flash (hit, disarm, KO) as a material_overlay timed on world frames (FLASH_FADE_PER_FRAME), leaving the surface materials free for task 16's toon conversion; the floor shadow and side ring kept | side colours moved out of FighterStandin into a shared constant used by results_screen.gd and MatchView's dropped-weapon beam; FighterStandin and fighter_standin.tscn deleted | models cached across rematches and restarts, rebuilt only when the fighter changes | the camera re-checked with real bodies at 3.5, 2.5 and 1.5 m (spec Camera row: 'Re-check the swing with the real fighters'); any change to CameraRig's exported numbers updates test_camera_rig and the spec row
- check: test_match_scene.gd updated to FighterView: positions and yaw follow the rules, the flash fades by rules frames and not the wall clock, rematches leave no stray nodes, a whole match renders without errors | test_stick_pose.gd's stand-in mesh tests moved to FighterView (the weapon sits where the pose says; the blade lengths come from WeaponLook) | test_main_flow and test_match_host still pass; report the suite's time before and after | shot scenes skeleton_round_start, exchange, parry and watch re-rendered with real fighters and reviewed: a mirror match reads as two palettes, the weapon is in the hands, the player never hides the opponent | npm test and npm run typecheck pass; npm run godot:run plays a Duel to the results
- depends: 14-rig
- stories: 11, 43, 44, 45
- files: game/view/fighter/fighter_view.gd (new), game/view/match/match_view.gd, game/view/match/fighter_standin.gd (deleted), game/view/match/fighter_standin.tscn (deleted), game/view/match/stick_pose.gd, game/view/match/camera_rig.gd, game/ui/menus/results_screen.gd, game/tests/view/test_match_scene.gd, game/tests/view/test_stick_pose.gd, game/tools/shot_scenes/skeleton_shot.gd
- notes: Can start before task 7. The dropped-weapon models are left for 15-disarm. Greatsword, Daggers and bare hands stay StickPose-driven until their 15 tasks, so the Duel stays readable throughout.

### [14] 14-checks (M): Pose checks on the posed skeleton
- delivers: PoseCheck (game/view/fighter/pose_check.gd, new), which measures a posed fighter: | wrist bend (hand against forearm, ±60 degrees) and deviation (±25 degrees), using the retargeted hand frame (+Y wrist to knuckles, +Z out of the palm) | elbow angle (150 to 160 degrees on contact frames, never locked) | the displayed blade (BladeBase to BladeTip) at least 5 cm from bone capsules round the head (with a hood/hat margin), torso (Hips to Neck), upper arms, forearms and thighs, extending test_no_blade_points_into_its_fighter's method | reach: blade-tip depth inside a defender's hurt capsule (0.35 m radius, feet to 1.75 m) at a given spacing (2.5 m by default) | a GUT helper that plays any move frame by frame through FighterView and returns a per-frame report
- check: GUT tests of the checker on made-up poses: a wrist bent 70 degrees fails, a blade 3 cm from the head fails, a locked elbow fails at contact, the katana guard passes | the report runs over the StickPose katana attacks and prints (not yet required to pass) | npm test and npm run typecheck pass
- depends: 14-in-match
- stories: 21
- files: game/view/fighter/pose_check.gd (new), game/tests/view/test_pose_check.gd (new), game/tests/view/pose_check_helper.gd (new)
- notes: Can start before task 7. This is the skeleton-level half of critique fix 1; task 7's data-level wrist and self-collision test is the other half (see open questions).

### [14] 14-sheet (M): Contact-sheet tool
- delivers: game/tools/shot_scenes/contact_sheet.gd/.tscn (new): plays one move (by move id, fighter, palette, weapon; from guard or chained from a named previous move) on a real fighter against a defender at 2.5 m | captures chosen frames from the gameplay camera behind the defender (what the defender's player sees), behind the attacker, from three-quarters, close up and at the hands, using CameraRig.follow_target so the framing matches the game | each frame labelled with its phase (startup/ACTIVE/recovery) and PoseCheck numbers (wrist, elbow, blade gap, tip depth) | sheets stitched per view into a folder (as preview.gd's _save_sheet does), driven by scene args through npm run shots (--move=k_l1 --fighter=rogue --sheet=<dir>), deterministic (rules clock only)
- check: sheets render for the katana guard and a StickPose katana light, and are reviewed for legibility | two runs give the same images (small pixel difference only) | npm test and npm run typecheck pass
- depends: 14-checks
- stories: 42, 65
- files: game/tools/shot_scenes/contact_sheet.gd (new), game/tools/shot_scenes/contact_sheet.tscn (new)
- notes: Can start before task 7. This is critique fix 5's regression check; from here on every animation task ends with its sheets.

### [14] 14-locomotion (M): Locomotion by speed
- delivers: an AnimationTree per FighterView in MANUAL mode, advanced by the rules' clock (frames moved plus alpha), so hit-stop and pause freeze it and slow motion slows it | idle, walk, jog and sprint blended by ground speed from the rules' Fighter.vel; all cycles seeked from one shared step phase, so feet never fall out of step (spike fighter.gd) | the clip speeds and strides re-measured on the outfit skeletons with a foot-phase tool (spike tools/foot_phase.gd ported to game/tools), the spike's CLIPS table as the starting point | blend bands set against the rules' speeds in constants.gd (run 3.9, strafe 3.5, back 3.0, sprint 7.2 m/s), using the library's clips ual/Idle, Walk, Jog_Fwd and Sprint
- check: GUT: blend weights at rest, 0.98, 3.9 and 7.2 m/s; the phase never jumps when speed changes | GUT: the tree's time doesn't move across hit-stop steps or while paused | screenshot strip, from the side, of a run accelerating from rest to sprint | npm test and npm run typecheck pass
- depends: 14-in-match
- stories: 12, 13
- files: game/view/fighter/locomotion.gd (new), game/view/fighter/fighter_view.gd, game/tools/foot_phase.gd (new), game/tests/view/test_locomotion.gd (new)
- notes: Can start before task 7. Task 8 changes the block speed and momentum; the bands are retuned then.

### [14] 14-hipturn (S): Hip-turn strafing and backpedal
- delivers: for unguarded movement: the legs turn toward travel relative to facing, clamped at ±80 degrees; beyond ±100 (10 degrees of hysteresis) they turn to travel - 180 and the cycle runs backwards | a critically damped spring (ω 12); the pelvis takes 70% of the turn and the thighs 30% | the chest keeps facing the opponent (spine twist = chest yaw - pelvis yaw, spread 28/36/36)
- check: GUT on the pure leg-yaw function: target yaw and the backwards flag for each of 8 directions, with hysteresis at the boundary | GUT on the posed skeleton: the chest faces within 5 degrees of the opponent while strafing | screenshot strips of strafing left and right, backpedalling and moving back-left at 135 degrees (the spike's m2 set) | npm test and npm run typecheck pass
- depends: 14-locomotion
- stories: 12, 13
- files: game/view/fighter/locomotion.gd, game/tests/view/test_locomotion.gd
- notes: Can start before task 7. The spike found the 80 degree turn isn't a true side step and the reversed walk may slide; the spec accepts that for unguarded movement until strafe clips exist.

### [14] 14-lean (S): Lean into runs and brace when braking
- delivers: a Root-bone lean toward smoothed local acceleration (0.014 rad per m/s², at most 11 degrees), taken from the rules' velocity on the rules' clock | a brace when braking: a back-lean and pelvis drop with a short settle, instead of the clip's high-knee step (critique fix 9 and look problem 10)
- check: GUT: the lean follows the sign of acceleration, stays within the cap, and holds still during hit-stop | GUT: braking from a run gives a back-lean that settles to zero | screenshot strip of a run, brake and stop (the spike's m2_run_lean equivalent) with the brace visible | npm test and npm run typecheck pass
- depends: 14-locomotion
- stories: 13
- files: game/view/fighter/locomotion.gd, game/view/fighter/body_layer.gd, game/tests/view/test_locomotion.gd
- notes: Can start before task 7.

### [14] 14-stance (M): Grounded guard stance
- delivers: the armed standing stance on leg IK: front foot toward the opponent, rear foot turned out 30 to 45 degrees, stance width held | knee poles moved outward so the knees track over the toes (the spike's poles caved the knees in) | the pelvis lowered and shifted with a visible slow weight shift between the feet; the torso set over the hips rather than upright on hips pushed back | the Katana guard pose (weapon and grip) replacing its WeaponHold idle; the other weapons keep StickPose until 15
- check: GUT on the posed skeleton for both fighters: each knee lies on or outside the hip-to-foot line (never inside), the rear foot's yaw is 30 to 45 degrees from the front foot's, the feet don't cross, and the stance width is within band | guard screenshots (front, three-quarter right and left, side), reviewed against critique fixes 8 and 9 | PoseCheck passes on the guard | npm test and npm run typecheck pass
- depends: 14-in-match, 14-checks
- stories: 43
- files: game/view/fighter/fighter_rig.gd, game/view/fighter/guard_stance.gd (new), game/view/fighter/fighter_view.gd, game/tests/view/test_guard_stance.gd (new)
- notes: Can start before task 7.

### [14] 14-shuffle (M): Guard shuffle step
- delivers: a procedural shuffle step for guard walking in 8 directions: the foot on the travel side steps first, the trailing foot closes, low lift, the feet never cross, stance width and foot angles kept | step cadence from the rules' speed, including the tap 'step' state (0.55 m in 8 frames) and the block walk (45% now, 60% after task 8) | the arms and weapon riding the pelvis bob with a slight spring lag (critique fix 9) | blends with clip locomotion when the guard walk turns into a run and back; the hip-turn clips stay for unguarded running only
- check: GUT on the pure step planner: for every direction over many steps the feet never cross the stance mid-line, the gap between the feet stays within band, and the lead foot moves first | GUT: on the posed skeleton, planted feet slide less than 1 cm | screenshot strips of a guard strafe left and a guard backpedal (the spike's m2_guard_* equivalents), reviewed for no crossed feet and no heel kick | npm test and npm run typecheck pass
- depends: 14-stance, 14-locomotion
- stories: 12, 14
- files: game/view/fighter/shuffle_step.gd (new), game/view/fighter/locomotion.gd, game/tests/view/test_shuffle_step.gd (new)
- notes: Can start before task 7. When the shuffle applies rather than the clips is an open question.

### [14] 14-swing-arms (M): Swing playback: weapon and arms
- delivers: SwingPlayer (game/view/fighter/swing_player.gd, new): samples task 7's swing at the fractional attack frame (AttackState.frame - 1 + alpha) and places the weapon from the grip, the hand frame (the blade follows the hand within the wrist limits) and the edge; the arms reach for it on IK | the root is always the rules' display position: the view never adds its own lunge (unlike the spike's attack_driver) | moves with a swing play from it; moves without one fall back to StickPose
- check: GUT: at every frame of Right Cut, the displayed weapon's grip and blade direction equal the swing sample (within 1 mm and 0.5 degrees) | GUT: PoseCheck runs over k_l1 to k_l4 and reports per frame | contact sheet of Right Cut | npm test and npm run typecheck pass
- depends: 7, 14-stance, 14-sheet
- stories: 16, 21
- files: game/view/fighter/swing_player.gd (new), game/view/fighter/fighter_view.gd, game/tests/view/test_swing_player.gd (new)
- notes: Needs task 7 (swing data and sampler under game/sim) and, through it, task 9's final Katana moves.

### [14] 14-chain (S): Chains: entries, exits and hand-offs
- delivers: a follow-up starts from the current displayed pose, blending into the move's entry from the previous move over at most 4 ticks | an opener uses the entry from guard | when no follow-up is pressed, the recovery runs the move's exit back to the guard pose | the chain point uses task 7's side_start/side_end data
- check: GUT: in L-L-L-L and in L, L-L and L-L-L stopped after each hit, the displayed grip never jumps more than the swing's own speed allows at a chain point | GUT: a stopped string ends exactly on the guard pose | contact sheets of the whole L-L-L-L string and of each stop-and-recover | npm test and npm run typecheck pass
- depends: 14-swing-arms
- stories: 16, 17
- files: game/view/fighter/swing_player.gd, game/tests/view/test_swing_player.gd
- notes: Critique fix 4's playback half; the poses themselves are keyed in 14-string.

### [14] 14-swing-body (M): Swing playback: coil, cocked hold and firing order
- delivers: the torso and pelvis coil from the swing's body keys (40 to 60 degree chest coil, pelvis back over the rear foot), replacing the spike's 'chest yaw = -0.5 x grip angle' | firing in sequence: the hips lead the chest and the chest leads the arms by a frame or two each, through per-segment time offsets on the same keys; the blade arrives last | the head counter-turns about 85% to keep the eyes on the opponent | a pelvis dip of about 5 cm around the contact frame | a camera kick on contact through the existing CameraRig.kick_fov/add_shake, scaled by weight
- check: GUT: over Right Cut, the pelvis yaw-rate peak comes before the chest's, which comes before the blade's angular-speed peak | GUT: a 2 to 4 frame cocked hold (near-zero grip speed) shows on the posed skeleton just before the strike | contact sheets reviewed for visible loading and release | npm test and npm run typecheck pass
- depends: 14-swing-arms
- stories: 19
- files: game/view/fighter/swing_player.gd, game/view/fighter/body_layer.gd, game/view/match/match_view.gd, game/tests/view/test_swing_player.gd
- notes: Critique fix 3. The keyed coil values live in the swing data from task 7.

### [14] 14-swing-feet (S): Swing footwork in time with the rules' lunge
- delivers: the front foot steps so it lands on the first active frame, in step with the rules' lunge (lunge, lunge_start, lunge_end; 0.7 to 0.8 m on lights after task 7) | the rear foot follows; feet otherwise stay planted in the world on leg IK while the root moves under the rules' momentum
- check: GUT: the front foot touches down on the first active frame ±1 for every Katana light | GUT: a planted foot slides less than 1 cm in world space | contact sheet reviewed for a driven lunge | npm test and npm run typecheck pass
- depends: 14-swing-arms, 14-shuffle
- stories: 19, 21
- files: game/view/fighter/swing_player.gd, game/view/fighter/shuffle_step.gd, game/tests/view/test_swing_player.gd
- notes: Critique fix 6's presentation half; reach itself is task 7's rules data.

### [14] 14-string (M): Key the Katana four-light string
- delivers: Right Cut, Return Cut, Kesa Cut and Crown Cut re-keyed in task 7's swing data to the critique's fixes 2 to 5: | the hands travel from one shoulder to the opposite hip, pivoting from the shoulders and spine, and never cross in front of the face | Right Cut loads out to the right early, not straight up (so it doesn't read as an overhead) | Return Cut winds up from the left hip without wrist-flipping | no contact pose reads as a thrust; elbows at 150 to 160 degrees at contact; a 2 to 4 frame cocked hold; overshoot keys | strong hand-off poses: Right Cut ends with the hands at the left hip and the blade low and back on the left, a loaded start for Return Cut, and every end pose a clean way back to guard
- check: GUT: PoseCheck passes on every frame of the four moves on both fighters (wrists, at least 5 cm from the body, elbows at contact) | task 7's swing-hit and reach tests still pass (the last 15 to 20 cm of blade enters at 2.5 m); the soak run is clean | contact sheets from the gameplay camera (attacker and defender views) reviewed: slash and overhead told apart in the first third of the wind-up | npm test and npm run typecheck pass
- depends: 14-chain, 14-swing-body, 14-swing-feet
- stories: 16, 19, 21, 25
- files: game/sim/moves/katana.gd or task 7's Katana swing data file, game/tests/view/test_pose_check.gd
- notes: This changes rules data that decides hits: run task 7's tests and the soak in the same commit, and give the reason in the commit message (see open questions).

### [14] 14-thrust-sweep (S): Katana thrust and sweep for the readability check
- delivers: Piercing Thrust (k_thrust) and Swallow Sweep (k_sweep) keyed and played, so the 14 sheets cover all four attack types: slash, overhead, thrust and sweep | each type distinguishable from the gameplay camera in the first third of its wind-up
- check: PoseCheck passes on every frame of both moves on both fighters | task 7's swing-hit tests pass; the soak run is clean | contact sheets of all four types side by side, reviewed for early readability | npm test and npm run typecheck pass
- depends: 14-string
- stories: 22, 30, 42
- files: game/sim/moves/katana.gd or task 7's Katana swing data file, game/tools/shot_scenes/contact_sheet.gd
- notes: Needed because the plan's task 14 check names thrust and sweep, which the four-light string doesn't contain.

### [14] 14-lag (S): Blade lag and follow-through overshoot
- delivers: a spring on the displayed blade's orientation and grip behind the hand path, stepped on the rules' clock so it freezes in hit-stop | the follow-through overshoots and then settles | the rules' blade (hits) unchanged; the lagged blade clamped inside the wrist limits and at least 5 cm from the body
- check: GUT: zero lag in the guard; during the strike the displayed blade trails the path by a bounded angle and settles within a set number of frames after the path stops | GUT: no change across hit-stop steps | PoseCheck still passes on the displayed pose for all Katana moves | contact sheets reviewed for weight | npm test and npm run typecheck pass
- depends: 14-string
- stories: 19
- files: game/view/fighter/swing_player.gd, game/view/fighter/blade_spring.gd (new), game/tests/view/test_swing_player.gd
- notes: Critique fix 7 and condition 4: weight must be in before any playtest judges it.

### [14] 14-parry (M): Parry-bounce prototype
- delivers: on a parry event (with task 7's contact point), the attacker's blade rebounds back along its own swing from the contact frame (the path played backward at a decaying rate, plus a kick away from the contact point) through the rules' recoil state | the defender's weapon rebounds off the same point during parryAnim | Katana only, on the SwingPlayer path system | a shot scene of a scripted parry
- check: GUT: after the parry event, the attacker's displayed tip moves away from the contact point and retraces earlier path samples, and the defender's blade moves away from the point | PoseCheck passes through the bounce | contact sheet of the parry from the gameplay camera, reviewed | npm test and npm run typecheck pass
- depends: 14-swing-body
- stories: 40
- files: game/view/fighter/parry_bounce.gd (new), game/view/fighter/swing_player.gd, game/tools/shot_scenes/contact_sheet.gd, game/tests/view/test_parry_bounce.gd (new)
- notes: Critique condition 3. Production for all weapons is 15-parry.

### [14] 14-review (S): Animation core review gate
- delivers: the full 14 sheet set: four lights, thrust, sweep, the L-L-L-L string with each stop, guard, guard shuffle, run and brake, strafe and backpedal, parry bounce; gameplay-camera, three-quarter and hands views | a checklist against the spike critique's 10 fixes and 7 conditions, each item pointing at its sheet or test | fixes for what the review finds; plan task 14 ticked with notes; the owner's art-direction OK recorded
- check: PoseCheck passes for every animated Katana move on both fighters | npm test and npm run typecheck pass; the soak run is clean | the owner approves the sheets before any 15 task starts
- depends: 14-thrust-sweep, 14-lag, 14-parry, 14-hipturn, 14-lean
- stories: 16, 19, 25, 40
- files: docs/plans/godot-rebuild.md, docs/specs/godot-rebuild.md

### [14b] 14b-data (S): Swing data save and reload
- delivers: a writer for task 7's swing key storage: loading and saving gives byte-identical files (stable key order and fixed float formatting) | editing a key, saving and reloading gives equal samples | validation on save: frames inside the move's length, keys sorted, ease values valid
- check: GUT: round trip byte-identical for every weapon's swing file | GUT: edit, save and reload gives the same sample at every quarter frame | npm test and npm run typecheck pass
- depends: 7
- stories: 16, 21
- files: game/tools/swing_editor/swing_store.gd (new), task 7's swing data files, game/tests/tools/test_swing_store.gd (new)
- notes: Depends on task 7 storing swings in data files, not GDScript const dicts (see open questions). Plan order puts 14b after the 14 review.

### [14b] 14b-plugin (M): Swing editor: dock, preview and scrubbing
- delivers: an EditorPlugin (game/addons/swing_editor/plugin.cfg and plugin.gd), enabled in project.godot's [editor_plugins] | a dock with weapon, move, fighter and palette pickers, a frame slider, step and play, and a defender at 2.5 m | an editor preview scene with FighterView and SwingPlayer at the chosen frame | the plugin's logic in a non-UI controller under game/tools/swing_editor/, which typecheck covers; tools/typecheck.gd changed to skip only addons/gut, so the plugin's own scripts are checked too
- check: GUT on the controller: selecting a move and setting a frame gives the same pose as SwingPlayer at that frame | the editor opens headless with the plugin enabled and no errors | screenshot of the preview scene | npm test and npm run typecheck pass
- depends: 14b-data, 14-swing-body, 14-swing-feet
- stories: 16, 19
- files: game/addons/swing_editor/plugin.cfg (new), game/addons/swing_editor/plugin.gd (new), game/tools/swing_editor/swing_editor_model.gd (new), game/tools/swing_editor/swing_dock.tscn (new), game/tools/typecheck.gd, game/project.godot

### [14b] 14b-drag (M): Drag grip path keys with live preview
- delivers: 3D handles (an EditorNode3DGizmoPlugin) for each key's grip point, hand and blade direction, and edge | the path drawn at quarter frames; live preview while dragging | undo and redo through EditorUndoRedoManager
- check: GUT on the controller's edit operations: moving a key changes the samples as expected, and undo restores them exactly | manual check in the editor, with a screenshot | npm test and npm run typecheck pass
- depends: 14b-plugin
- stories: 16, 19
- files: game/addons/swing_editor/swing_gizmo.gd (new), game/tools/swing_editor/swing_editor_model.gd

### [14b] 14b-body (M): Edit poles, body keys and timing
- delivers: editing of pole offsets (with handles), chest and pelvis coil, pitch and roll, and ease (0 for holds) | adding, removing and retiming keys, from the dock's inspector panel
- check: GUT on the controller: each edit changes the sample as expected, and undo restores it | GUT: retiming keeps the keys sorted and inside the move | npm test and npm run typecheck pass
- depends: 14b-drag
- stories: 19
- files: game/tools/swing_editor/swing_editor_model.gd, game/tools/swing_editor/swing_dock.tscn, game/addons/swing_editor/swing_gizmo.gd

### [14b] 14b-live (S): Live wrist, self-collision and reach checks in the editor
- delivers: PoseCheck run on every frame while editing | the timeline marks frames past the wrist limits, within 5 cm of the body or with a locked elbow at contact | the current frame's numbers shown, with tip depth into the 2.5 m defender's capsule
- check: GUT: a deliberately bad edit flags exactly the frames PoseCheck fails | npm test and npm run typecheck pass
- depends: 14b-plugin, 14-checks
- stories: 21
- files: game/tools/swing_editor/swing_editor_model.gd, game/tools/swing_editor/swing_dock.tscn

### [14b] 14b-proof (S): Re-key one Katana move in the editor and document it
- delivers: one Katana move (for example Kesa Cut) re-keyed in the editor and saved | a README section on the swing editor (opening it, scrubbing, dragging, checks, saving) | plan task 14b ticked
- check: the saved data reloads identically (byte-identical, the same samples) | PoseCheck and task 7's swing-hit and reach tests pass; the soak run is clean | contact sheet before and after | npm test and npm run typecheck pass
- depends: 14b-body, 14b-live, 14-review
- stories: 16, 19
- files: README.md, task 7's Katana swing data file, docs/plans/godot-rebuild.md

### [15] 15-gs-grip (S): Greatsword two-handed grip, guard and carry
- delivers: the Greatsword guard and carry with both hands on IK (off hand on OffHandGrip), replacing its StickPose and WeaponHold pose | stance, shuffle step and run with the heavier weapon (lower guard, wider stance)
- check: PoseCheck passes on the guard and the walk on both fighters | guard and shuffle sheets reviewed | npm test and npm run typecheck pass
- depends: 14-review, 14b-proof, 10
- stories: 31, 44
- files: game/view/fighter/guard_stance.gd, game/view/fighter/fighter_rig.gd, game/tests/view/test_guard_stance.gd

### [15] 15-dg-grip (S): Daggers in both hands: guard and carry
- delivers: paired daggers with two weapon transforms and independent arm IK | forward and reverse grip per pose | the Daggers guard and carry replacing StickPose and WeaponHold
- check: PoseCheck passes for both blades on the guard and the walk on both fighters | sheets reviewed | npm test and npm run typecheck pass
- depends: 14-review, 14b-proof, 11
- stories: 35, 44
- files: game/view/fighter/fighter_rig.gd, game/view/fighter/guard_stance.gd, game/view/fighter/swing_player.gd

### [15] 15-block (M): Block and guard for every weapon
- delivers: block raise, hold and lower for the Katana, Greatsword, Daggers and bare hands, driven by the rules' blocking flag and blockstun | a block impact pushing the guard back from the hit's contact point | guard crush and posture-break hand-offs into the stun task
- check: GUT: block poses follow blocking with no pop; impact direction follows the contact point | PoseCheck passes; sheets of blocks from the gameplay camera | npm test and npm run typecheck pass
- depends: 15-gs-grip, 15-dg-grip
- stories: 24, 41
- files: game/view/fighter/reactions/block_pose.gd (new), game/view/fighter/fighter_view.gd

### [15] 15-katana-moves (M): Katana sprint, dodge, backstep, jump and ability moves
- delivers: swings keyed in the editor and played for Running Draw, Wind Cut, Whirl Cut, Rising Cut, Lunging Cut, Aerial Cut, Falling Crown, Flash and Counter Lunge
- check: PoseCheck passes on every frame on both fighters | task 7's swing-hit tests pass; the soak run is clean | contact sheets per move reviewed | npm test and npm run typecheck pass
- depends: 14-review, 14b-proof
- stories: 25, 30
- files: task 7's Katana swing data file, game/view/fighter/swing_player.gd

### [15] 15-iai-stance (M): Iai sheathe and stance
- delivers: a saya built in code (game/tools/build_katana.gd) worn at the left hip whenever the Katana is the weapon | the sheathe on heavy press; the sheathed hold while walking and strafing at block speed (locomotion and shuffle under a held upper body) | the stance cancelled by a dodge; the hold at the 2.5 s auto-release
- check: GUT: the sheathe pose follows the rules' Iai stance state; walking while sheathed keeps the hold | PoseCheck passes; sheets reviewed | npm test and npm run typecheck pass
- depends: 15-katana-moves, 9
- stories: 26, 29
- files: game/tools/build_katana.gd, game/weapons/katana/ (saya mesh, new), game/view/fighter/swing_player.gd

### [15] 15-iai-draws (M): Iai draws and their follow-ups
- delivers: swings keyed and played for the vertical draw, the horizontal draw, Rising Heaven, Returning Draw and Heaven Splitter, with hand-offs between them | the power (auto-release) version
- check: PoseCheck passes; the chain-continuity GUT covers both Iai branches | task 7's swing-hit tests pass; the soak run is clean | sheets reviewed for vertical against horizontal readability | npm test and npm run typecheck pass
- depends: 15-iai-stance
- stories: 26, 27, 28, 29
- files: task 7's Katana swing data file

### [15] 15-gs-string (M): Greatsword string
- delivers: Heavy Swing and Backswing riding the momentum, Overhead Strike (with the charge hold) and the unblockable Low Sweep | keyed in the editor, with hand-offs, and the recovery slide shown
- check: PoseCheck passes for both hands on both fighters; chain-continuity GUT for L-L-H and H-H | task 7's swing-hit tests pass; the soak run is clean | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-gs-grip
- stories: 18, 20, 31, 32
- files: task 7's Greatsword swing data file

### [15] 15-gs-specials (M): Greatsword thrusts, special moves and abilities
- delivers: Piercing Lunge, Skewer, the sprint, backstep and jump attacks, Reaping Sweep, Mountain Slam, Guard Crusher and Counter Lunge
- check: PoseCheck passes; thrust, sweep and slam readable early from the gameplay camera | task 7's swing-hit tests pass; the soak run is clean | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-gs-string
- stories: 22, 33, 34, 42
- files: task 7's Greatsword swing data file

### [15] 15-dg-string (M): Daggers string and heavies
- delivers: Quick Slice, Off-hand Slice, Twin Rip and Flurry Finisher alternating hands | Twin Fang (dashing double stab) into Spinning Backhand | hand-offs between them
- check: PoseCheck passes for both blades; chain-continuity GUT for the four lights and Twin Fang into Spinning Backhand | task 7's swing-hit tests pass; the soak run is clean | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-dg-grip
- stories: 18, 35, 36, 37
- files: task 7's Daggers swing data file

### [15] 15-dg-specials (M): Daggers Passing Cut, special moves and abilities
- delivers: Passing Cut lunging along the dodge direction | the sprint, backstep and jump attacks, Serpent Sweep, Shadow Step, Needle Thrust and Counter Lunge
- check: PoseCheck passes | task 7's swing-hit tests pass; the soak run is clean | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-dg-string
- stories: 38, 39
- files: task 7's Daggers swing data file

### [15] 15-fists (M): Bare hands: guard, punches, kicks and Breaker Palm
- delivers: the bare-hand guard | punches on arm IK from fist paths, and kicks on leg IK from foot paths | the sprint, dodge, backstep and jump moves, Counter Lunge and the Breaker Palm
- check: PoseCheck (wrist and elbow checks for punches; knee and foot clearance for kicks) passes | task 7's swing-hit tests pass; the soak run is clean | sheets reviewed | npm test and npm run typecheck pass
- depends: 14-review, 14b-proof
- stories: 41, 44
- files: task 7's Fists swing data file, game/view/fighter/swing_player.gd, game/view/fighter/fighter_rig.gd
- notes: Whether kicks are foot-effector swings is an open question for task 7.

### [15] 15-parry (M): Parry deflect with both weapons rebounding
- delivers: the 14 parry-bounce prototype made production for every weapon, including both daggers and two-handed recoil | the parry, flash and redirect kinds, the defender's parryAnim and the attacker's recoil
- check: GUT: both weapons move away from the contact point for each weapon pairing | PoseCheck passes through the bounces; sheets of each pairing reviewed | npm test and npm run typecheck pass
- depends: 14-parry, 15-block
- stories: 40, 41
- files: game/view/fighter/parry_bounce.gd, game/view/fighter/fighter_view.gd

### [15] 15-flinch (M): Flinches by hit direction
- delivers: a reaction system separate from swings: procedural recoil away from the hit's contact point (in the defender's frame), blended with the pack's Hit_Chest and Hit_Head clips over the rules' hitstun (14 frames on lights)
- check: GUT: the recoil direction follows the contact side (front, left, right, high, low), and the pose returns to guard when hitstun ends | sheets from the gameplay camera reviewed | npm test and npm run typecheck pass
- depends: 14-review, 14b-proof
- stories: 19, 24
- files: game/view/fighter/reactions/flinch.gd (new), game/view/fighter/fighter_view.gd

### [15] 15-stun (S): Stun, stagger and daze
- delivers: poses for the rules' stunned, stagger, disarmStagger and impaled states: guard dropped, weapon sagging, a daze sway on the rules' clock
- check: GUT: each state maps to its pose and holds still in hit-stop | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-flinch
- stories: 41
- files: game/view/fighter/reactions/stun.gd (new)

### [15] 15-disarm (M): Disarm, dropped weapon and pickup
- delivers: on the disarm event the weapon leaves the hands and becomes a separate dropped-weapon mesh (the WeaponLook model, replacing MatchView._make_dropped's box sticks) following DroppedWeapon pos, tumble and yaw | a pickup pose on the rules' pickup state, then the weapon back in the hands; bare-hand guard while disarmed
- check: GUT: the dropped mesh follows the rules' dropped weapon each frame and is removed on pickup or round start | sheets of disarm and pickup reviewed | npm test and npm run typecheck pass
- depends: 15-fists, 15-stun
- stories: 41
- files: game/view/match/match_view.gd, game/view/fighter/fighter_view.gd, game/view/fighter/reactions/pickup.gd (new)

### [15] 15-dodge (M): Dodge and backstep poses with ghost trails
- delivers: dash poses by direction for the rules' dodge, backstep and evade, leaning into the dash | a ghost trail of fading afterimages of the fighter mesh, timed on the rules' clock
- check: GUT: the pose leans along the dodge direction; the afterimages fade by frame and clear at the round's start | sheets reviewed | npm test and npm run typecheck pass
- depends: 14-review, 14b-proof
- stories: 12, 13
- files: game/view/fighter/reactions/dodge_pose.gd (new), game/view/fighter/ghost_trail.gd (new)

### [15] 15-jump (S): Jump and land
- delivers: Jump_Start, Jump_Loop and Jump_Land clips seeked from the rules' jump state and height | the land-recovery crouch
- check: GUT: clip phase follows rise, apex and fall; the crouch lasts the land recovery (5 frames) | sheets reviewed | npm test and npm run typecheck pass
- depends: 14-review, 14b-proof
- stories: 12
- files: game/view/fighter/locomotion.gd, game/view/fighter/reactions/jump_pose.gd (new)

### [15] 15-counters (S): Stomp and leap counters
- delivers: poses for the rules' stomp state (onto a thrust) and leap state (over a sweep)
- check: GUT: each counter state maps to its pose | sheets of a stomp against Skewer and a leap over Low Sweep reviewed | npm test and npm run typecheck pass
- depends: 15-jump
- stories: 41, 42
- files: game/view/fighter/reactions/counter_pose.gd (new)

### [15] 15-ko (S): KO, death and victory
- delivers: Hit_Knockback or Death01 on KO, lying still until the next round | a simple victory hold on the rules' victory state
- check: GUT: KO plays once and holds; the round start resets the pose | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-flinch
- stories: 6, 49
- files: game/view/fighter/reactions/ko_pose.gd (new)
- notes: See the open question on victory poses.

### [15] 15-ult-moon (S): Moonsplitter presentation
- delivers: keyed motion on top of the paths for the ult, ultChoice and recall states, synced to the rules' wave hits
- check: GUT: poses follow the rules' ultimate phases | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-iai-draws
- stories: 30
- files: game/view/fighter/ultimates/moonsplitter.gd (new)

### [15] 15-ult-impaler (S): Impaler presentation
- delivers: the dash, impale and burst motion for both the attacker and the impaled defender
- check: GUT: poses follow the phases; the impaled defender's pose holds | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-gs-specials, 15-stun
- stories: 34
- files: game/view/fighter/ultimates/impaler.gd (new)

### [15] 15-ult-tempest (S): Lightning Tempest presentation
- delivers: the spin and the Thunder Finisher motion with both daggers
- check: GUT: the spin follows the rules' spin phase | sheets reviewed | npm test and npm run typecheck pass
- depends: 15-dg-specials
- stories: 39
- files: game/view/fighter/ultimates/tempest.gd (new)

### [15] 15-final (S): Retire the stand-in poses and review
- delivers: StickPose and the WeaponHold idles removed once every move has a swing and every state a pose (and their tests) | contact sheets for every move on both fighters | a match screenshot series | plan task 15 ticked
- check: PoseCheck passes on every move on both fighters | npm test and npm run typecheck pass; the soak run is clean | the owner's art-direction review passes
- depends: 15-katana-moves, 15-iai-draws, 15-gs-specials, 15-dg-specials, 15-fists, 15-parry, 15-disarm, 15-dodge, 15-counters, 15-ko, 15-ult-moon, 15-ult-impaler, 15-ult-tempest
- stories: 21, 43, 44
- files: game/view/match/stick_pose.gd (deleted), game/fighters/weapon_hold.gd, game/tests/view/test_stick_pose.gd (deleted), docs/plans/godot-rebuild.md

## Open questions
- Swing storage: the moves are GDScript const dicts in game/sim/moves/*.gd, which the 14b editor can't safely write back. Recommend that task 7 keep swing keys in per-weapon data files (JSON) read by the rules, with stable formatting, so the editor's round trip is byte-identical.
- Who checks wrist limits and self-collision? Recommend: task 7 checks the swing data in the rules with a simple body model, and 14's PoseCheck checks the real IK'd skeleton (head, hood, forearms, torso at 5 cm). Both must pass.
- May tasks 14 and 15 re-key swings that task 7 authored? They are rules data that decide hits. Recommend yes: each re-key commit re-runs task 7's swing-hit and reach tests and the soak, and gives the reason in the commit.
- When does the shuffle step apply instead of the clips? The rules' normal movement is a 3.9 m/s run with no walk speed. Recommend: shuffle while blocking, in the tap step state and below about 2.5 m/s; clips with hip-turn above that.
- Should the swing editor come before keying the Katana string? The spike found quality depends on key tuning. Recommend pulling 14b-data, 14b-plugin and 14b-drag forward to right after 14-swing-feet, if the owner agrees; my default order follows the plan (14b after 14).
- Should reaction tasks (block, flinch, stun, jump, dodge, KO) wait for 14b, as plan task 15 says? They don't use the editor. Recommend letting them start after the 14 review.
- Bare hands: are kicks swings with a foot effector? Recommend: the swing format names its effector (right or left hand, both hands, right or left foot), decided in task 7.
- Iai sheathe needs a scabbard the Katana lacks. Recommend a saya built in code by build_katana.gd, worn at the left hip whenever the Katana is the weapon.
- Victory: the spec puts victory poses out of scope, but plan task 15 lists 'victory'. Recommend a simple procedural hold on the rules' victory state now, with real victory poses later.
- Spring bones for the hood and hair (the critique's next step) aren't in plans 14 or 15. Recommend leaving them for later.
- Keep the coloured floor ring under each fighter after the capsules go? Recommend keeping it until task 24's HUD decisions; it helps Versus.

## Risks
- The fighters-and-weapons branch was never pushed. The first CI run after the merge imports 42.9 MB of assets headless on Linux inside a 30-minute job, and the content tests (one rasterises palettes in software) add time.
- Real fighter models in MatchView make the view tests (test_match_scene, test_main_flow) slower and heavier. Cache models across rematches and measure the suite time.
- Task 7 authors swings before any real body shows them, so 14 and 15 will re-key rules data. Hit tests, the soak and the AI's balance can shift with each re-key.
- The spike's IK constants were measured on the female body only. The Hunter's slimmer outfit skeleton may fail the pose checks unless arm lengths and poles are read from each skeleton.
- Clips, springs and IK must run on the rules' clock. Anything on the wall clock would move during hit-stop and pause, against the spec.
- The spike moved the fighter's root for lunges. In the game the rules own position, so footwork must match the rules' lunge and momentum or feet will slide.
- Two ways of holding a weapon coexist until 15 finishes: hand sockets with WeaponHold, and IK to a weapon pose. HandGrip's wrist setting must be off wherever IK drives a hand.
- tools/typecheck.gd skips res://addons, so an editor plugin there isn't type-checked unless the skip is narrowed to addons/gut.
- Contact sheets need a real window. They can't run in CI, so the readability reviews are local and by eye.
- The critique's quality bar may not be met at the 14 review gate on the first try; budget time for re-keying.
- The body flash should use a material overlay so it doesn't fight task 16's toon conversion, which replaces surface materials and adds outline passes.
