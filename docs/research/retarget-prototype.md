# Retargeting prototype (Oct 3, 2026)

Plan task 1 of `docs/plans/authored-animation.md`: can Kevin Iglesias's clips be retargeted onto the Quaternius fighters well enough to replace the procedural animation? This is the hard gate before the rest of the plan. The owner decides pass or fail.

Only `game/tools/build_iglesias_bone_map.gd`, the bone map it writes (`game/assets/kevin_iglesias/iglesias_bone_map.tres`) and this note are committed. The converted clips, the prototype scripts and the contact sheets stayed in the gitignored `game/_scratch/` and `shots/retarget/` folders. No file from the packs was committed.

## What was built

- **The bone map.** Kevin's HumanM and HumanF rigs are the same `B-` rig: 55 bones, or 56 in the clips, which add `B-spineProxy`. 52 of them map to Godot's humanoid profile, by name, the same way `build_bone_map.gd` maps the UAL rig.
  - Unmapped, so the importer drops their tracks: `B-handProp.L/R`, `B-jaw` and `B-spineProxy` (a helper on `B-root` that nothing hangs from).
  - The rig has no upper chest. `B-chest` carries the neck and shoulders, so it maps to Chest, and the profile's UpperChest holds its rest pose on our skeleton. No kink shows at the chest in any sheet.
  - The rigs are T-posed with +Y along every bone, like the UAL rig, so Godot's default rest fixer (overwrite axis) needed no help.
- **The import.** Godot 4.7.2's built-in FBX importer (ufbx) read every clip. Each clip's `.import` points `PATH:Skeleton3D` at the bone map and sets `retarget/remove_tracks/unmapped_bones`. After import, the prototype also dropped:
  - the Root track (Roll01 [RM] has the only moving one);
  - every scale track (the packs key tiny scales on fingers and legs);
  - every position track except the hips.
- **The clips.** CombatIdle1H01, Attack1H01_R, Attack2H01, Roll01, CombatDeath01 and Dodge01, from both sets, plus Roll01 [RM] for its root. The Hunter plays HumanM and the Rogue plays HumanF.
  - The Katana is fixed in the right fist (`FighterRig.fist()`, no hold, no IK) for every clip except Attack2H01, which has the Greatsword.
  - The rig's other modifiers are off, so each sheet shows the clip alone. The fingers are the clip's own, not HandGrip's.
- **One fix, in the task: hips travel scaled to the legs.** Godot scales the hips' position track by hips height (×0.97 from Kevin's rig to the Hunter's). But our fighters' legs are about 11% longer than Kevin's for their hips height, so every weight shift moved the hips too little, and planted feet slid. The import now scales the hips' travel from their rest by the target's leg-to-hips ratio over the source's (×1.14 for both fighters). That took Dodge01's worst slide from 5.7 cm to 1.2 cm. The import tool (task 2) should do the same, once for each clip set.

## The gate's tests

The measurements come from the poses at every source frame (30 fps), on each fighter and on Kevin's own model of the set playing the same clip.

| Test | Result | Verdict |
|---|---|---|
| Shoulders, elbows and knees bend the right way | Every joint's rotation on our fighters equals the rotation on Kevin's model; the retarget copies them exactly. Elbows and knees bend about the same axis and in the same direction as the UAL clips (Walk, Sword_Regular_A), at most 7° off that axis. The only overextension is 8° at the right knee in Roll01 and CombatDeath01, and it's in Kevin's clip too. The sheets show no reversed joint on either fighter. | **Pass** |
| The feet don't cross | The ankles are never crossed: they stay at least 16 cm apart across the hips (the Rogue mid-roll), and Kevin's model gets as close as 12 cm. | **Pass** |
| The feet don't slide | Where Kevin's model has a foot planted, ours moves it by: idle 0.7–1.6 cm, Dodge01 up to 2.0, Attack1H01_R up to 3.8, CombatDeath01 up to 0.6, Roll01 up to 1.5 (Hunter) and 6.1 (Rogue, getting up), Attack2H01 up to 5.6 (Hunter) and 5.0 (Rogue). Kevin's model moves the same feet by 2.7 cm at most. | **Partial.** Under 2 cm in the idle, death and dodge clips. A slow creep of up to 6 cm in the 2H attack and the roll's getting-up. |
| The hands hold the grip | Main hand: with the weapon fixed in the fist, the blade points where the clip's swing points in every frame (sheets, close column). The clip's fingers close into a fist round the handle. Off hand (Attack2H01, Greatsword): it stays on the handle's line, 2–9 cm off its axis, but 7–16 cm nearer the main hand than the Greatsword's `OffHandGrip`. Kevin's hands sit about 12 cm apart; our marker is 26.6 cm below the main hand. | **Pass with a condition**: task 4's off-hand IK has to close a 7–16 cm gap (or the Greatsword's grip moves up). |

**What's left of the slide** comes from where the hip joints sit relative to the pelvis bone. Kevin's thighs hang 5.5 cm below his hips bone and 8.7 cm out from it; ours are 2 cm above it and 11.4 cm out. So when the pelvis tilts or twists (the 2H swing's wind-up, the roll), the same rotation swings our feet along a slightly different arc. A bone map or rest fix can't change that without changing our skeleton. The fix is foot locking: FighterRig's leg IK holding a planted foot where it landed. Task 29 plans it for locomotion only (planted feet under 1 cm). Running it under the attacks and the roll's getting-up too would take the slide under 1 cm everywhere.

The 1H clips leave the off hand free, a fist about a metre from the handle. That's the clip, not the retarget, but our Katana is two-handed, so the catalogue (task 5) should prefer 2H clips for it.

## The two questions

**Can Roll01 [RM]'s root track be read for the roll's travel? Yes.** The root moves only along +Z (forward), with no sideways drift and no rotation track. It covers 4.5 m on both sets, all of it in frames 0–22 (0.73 s at 1×), and is still after that. The hips stay over the root (within 15 cm), so the root carries all the travel. Normalised and resampled to the dodge's 16 frames (17 numbers):

- HumanM: 0.000, 0.088, 0.196, 0.282, 0.365, 0.448, 0.540, 0.650, 0.748, 0.801, 0.841, 0.870, 0.912, 0.959, 0.971, 0.990, 1.000
- HumanF (travel ends a frame sooner, at frame 21): 0.000, 0.092, 0.184, 0.269, 0.351, 0.433, 0.517, 0.621, 0.719, 0.787, 0.830, 0.861, 0.896, 0.936, 0.971, 0.996, 1.000
- today's `ease_out_cubic`, for comparison: 0.000, 0.176, 0.330, 0.464, 0.578, 0.675, 0.756, 0.822, 0.875, 0.916, 0.947, 0.969, 0.984, 0.993, 0.998, 1.000, 1.000

The roll's travel is close to even speed with a soft stop. The dash's is front-loaded. The spec bakes the curve from HumanM, the set the paths come from.

Two things for later tasks (the curve is task 17, the roll's clip task 30):

- **Speed.** The travel takes 22 source frames, and the dodge moves in 16 rules frames (0.27 s). Fitting the roll's travel to the dodge needs 2.75×, outside the spec's 1.0–2.0× range. At 2.0× the clip's travel lasts 22 rules frames, which nearly fills the dodge and its recovery (25 frames). So either the roll may play faster than 2×, or the visible roll runs about 6 frames past the rules' travel.
- **Entry and exit.** Roll01 starts crouched (hips at 0.58 m, against 0.95 m standing) and ends standing upright and relaxed, not in a guard. The roll needs a blend in from the guard, which the spec's 2-frame dodge-cancel crossfade won't hide, and a blend out into the guard.

**Does Dodge01 work as the backstep? Not as it stands.** It's a lean-back sway, not a hop. The hips go 0.47 m back by frame 12, then come forward again to where they started by frame 30, with the feet stepping back and then forward. The backstep moves 2.1 m in 14 frames.

- Its back half (frames 0–12 at about 1.7×) fits the backstep's 14 frames and reads as an evasion: lean back, rear foot back.
- It has to stop there and blend into the guard over the 9 recovery frames. The forward half would walk the fighter back to where the rules no longer have them.
- Its 0.47 m of hips travel against 2.1 m of rules travel means the feet skate, as the dash's do today.

The packs have no backward hop. Their only backward clips are walks, crouch-walks and runs, with Jump01 the nearest thing to a hop. Recommendation: put "Dodge01, frames 0–12, then the guard" in the catalogue (task 5) beside the spec's fallback (UAL Roll, reversed) and let the owner pick by eye.

## Other findings

- CombatDeath01 moves the hips 0.79 m to the fighter's left as it falls, and ends lying flat. The hips track is kept, so the body lands where the clip puts it.
- CombatIdle1H01 stands wide (feet 86 cm apart on the Hunter, 95 cm on the Rogue) and steady: its feet move under 2 cm.
- The import raised no errors or warnings, and the clips come through named `HumanM_<clip>`.

## The sheets

`shots/retarget/retarget_<clip>.png` (local only, not committed), made by the scratch scene `game/_scratch/proto/retarget_sheet.tscn`. One sheet per clip: the Hunter then the Rogue, four phases each (an attack's start, wind-up, strike and recovery; the other clips spread evenly). Columns: the gameplay camera, three-quarter, close, and the clip on Kevin's own model for comparison.
