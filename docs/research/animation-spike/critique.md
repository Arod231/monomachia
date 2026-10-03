**Verdict: yes, with conditions.** Procedural weapon paths are the right approach for this game. The reasons are a fixed 60 Hz simulation, 9 weapons, attack timing that has to match frame data, and Sekiro-style parry bounces, which are easy to do as a branch off a procedural path. But the two cuts as keyed now aren't good enough to ship. Both have frames that read as a different attack type, and the Return Cut has no weight at all in its wind-up. The report's "solid game animation" is too generous. The hips-down and the guard are mid-tier game animation. The swings read as procedural: the wrists spin the blade, the arms lock straight, and the body barely coils.

## What reads well

- **Best frame: `m5_contact_cut1_34` (Right Cut contact).** The deep lunge, the head tucked behind the lead shoulder, a turned torso and a clean high-right arc. This is the target quality.
- **Grip.** Both hands stay on the handle in every frame, right hand at the guard and left at the pommel, and no hand floats free.
- **Timing.** Cocked wind-up, a 3-frame strike, then follow-through gives real snap at f10–f13. The arcs are smooth and the trail sampling is clean.
- **Fighter.** The hood, the white hair accent and a clean neck seam. The white hair is the best long-range readability asset in the whole scene.
- **Run lean.** The lean on acceleration reads (`m2_run_lean` f16–f50).
- **Engineering.** The modifier order, a tree stepped once per sim frame and the retarget pipeline are solid.
- **Toon look.** The blade highlight and the rim light separate silhouettes well in the 3/4 views.

## What looks wrong

1. **Return Cut wind-up, f0–f9 (worst problem).** The arms stay locked out at chest height and the blade flips back around the wrists. At f5 and f7 the blade points back past the forearm toward her own face and hood. From the defender's over-the-shoulder view (`m4_cut2_LtoR_ots` f3–f9) you see two hands in front of a chest and nothing else, so nothing telegraphs the attack.
2. **Return Cut contact, f10–f13 (`m5_contact_cut2_34`).** Both elbows are locked, the shoulders are square and the blade points straight at the defender. That is the "held stiffly straight out in front" look the design forbids. Worse, it reads as a thrust, which in this design is an unblockable with a different counter.
3. **Right Cut wind-up, f6–f10 (`m4_cut1_RtoL_close`).**
   - The hands sit in front of her chin and the forearms cover her face.
   - At f6 the vertical blade runs through the hood brim line.
   - The knees almost touch (knock-kneed), there's no weight shift onto the rear leg, and the chest barely coils.
   - The cocked pose looks like flinching, not loading.
4. **Right Cut from the over-the-shoulder view, f6–f9.** The blade rises vertically above the head, which reads as an overhead slam (another unblockable) until f10, one frame before the hit. The defender can't tell slash from overhead in time.
5. **Right Cut follow-through, f17–f30.** The blade does end low-left in space, but the hands stay at arm's length in front of the chest and the blade hangs straight down from the wrists. The swing's energy dies there, and the Return Cut inherits this weak pose. The string connects in the data, not in the body.
6. **Return Cut recovery, f16–f29.** The blade sweeps about 180°, from pointing at the defender to pointing behind her, while the hands move a few centimetres. It spins like a propeller around the grip. This is a flaw in the method: blade direction is splined separately from the hand path.
7. **Reach (`m5_contact_cut1_34`).** At contact the tip only meets the defender's blade tip, not their body.
8. **Guard walking.**
   - `m2_guard_strafe_left` f110 and f140: the feet cross over, with long walking strides. It looks like a casual sideways walk with a sword glued on.
   - `m2_guard_backpedal` f90 and f120: the rear heel kicks up like a jog, while the arms and sword sit rigid on top like a statue.
   - The 8.5 cm crouch barely shows.
9. **Guard stance (`m3_guard`, `m5_guard_guard_close`).** The knees cave inward, and in the 3/4 view the rear knee tucks behind the front knee. The feet are splayed and the torso sits upright on hips pushed back. It isn't a grounded duelist's stance.
10. **Run.**
    - Braking (f74–f80) has no brace or back-lean; she stands up and takes a high-knee step.
    - The run was only captured without the sword, so running in guard is untested.
11. **Trail.** A wide grey sheet stays on into recovery (3/4 view f14 and f17) and covers the attacker's torso. It reads as a solid CG fan, not an ink stroke.
12. **Weapon and camera.**
    - The blade is straight with no curve (no sori) and only about 2 px wide at gameplay distance. Against the floor it vanishes and only the trail reads.
    - The player's own sword is hidden behind their body in the over-the-shoulder shots.
    - The camera in the `m5` over-the-shoulder shots is high and far, so the fighters fill about a third of the frame.
    - In `m4_cut1_RtoL_ots` f12–f14 the two identical fighters merge into one silhouette.
13. **Look.** This is a cel shader, not ink-wash yet: outlines are uniform and thin, with no brush or paper texture. The skin is oversaturated orange against the cold scene, and the face shading bands are noisy.
14. **Grip, minor.** The finger curl reads loose and fingertips poke out below the handle (`m3_grip_close`, front-right view). In `m4_cut2_LtoR_hands` f10 the lower hand looks like an open palm under the handle.

## The 10 most valuable fixes, in priority order

1. **Make the hands drive the blade, not the wrists.**
   - Work out blade direction from the forearm and hand-path frame, plus a limited wrist offset (roughly ±60° bend, ±25° side-to-side). Stop splining it on its own.
   - Add an automatic check that fails any frame past those wrist limits, or where the blade comes within about 5 cm of the fighter's own head, hood, forearms or torso.
   - This removes the propeller recovery (Return Cut f16–f29), the wrist-flip wind-up (Return Cut f0–f9) and the blade through the hood (Right Cut f6, Return Cut f7).
2. **Re-key the hand paths with full-body travel.**
   - The hands should go from one shoulder to the opposite hip. For the Right Cut: above the right ear, through the centre at chest height, then to the left hip.
   - Pivot from the shoulders and spine, not from a point at the sternum with the hands circling at face height. Hands should never cross in front of the face (Right Cut f9–f12).
   - Elbows stay at about 150–160° at contact, never locked.
3. **Key a real coil and release.**
   - Replace "chest yaw = −0.5 × grip angle" with keyed torso and pelvis values. The grip angle itself is small, so the torso hardly turns.
   - In the wind-up, coil the chest 40–60° away and move the pelvis back over the rear foot. Hold the cocked pose for 2–4 frames; parry timing depends on reading that hold.
   - Then fire in sequence: hips, chest, arms, blade. Overshoot on the follow-through, then settle.
4. **Build strings around strong hand-off poses.**
   - The Right Cut should end with the hands at the left hip and the blade low and back on the left, a natural loaded start for the Return Cut.
   - Every end pose must be a valid cocked start for the next swing and a clean way back to guard.
5. **Check readability from the gameplay camera.**
   - At the final over-the-shoulder framing, a viewer should be able to tell slash, overhead, thrust and sweep apart within the first third of the wind-up.
   - The Right Cut has to load out to the attacker's right early, not go straight up.
   - A slash's contact pose must never look like a thrust.
   - Make an over-the-shoulder contact sheet per move a regression check.
6. **Fix reach and contact geometry, and measure it.**
   - Lunge 0.7–0.8 m, with the front foot landing on the contact frame.
   - At 2.5 m spacing, the last 15–20 cm of the blade should enter the defender's body capsule on the active frame.
   - Consider scaling the weapon up 10–15% for readability.
7. **Add impact weight.**
   - Hit-stop on both fighters, scaled by attack weight (about 3–6 frames).
   - Blade lag on a spring, plus a follow-through overshoot and a camera kick.
   - Prototype the parry bounce on the same path system now, since visible parries are a design pillar.
8. **Fix the legs.**
   - Move the knee poles outward so each knee tracks over its toes.
   - Set targets for stance width and foot angle: front foot toward the opponent, rear foot turned out 30–45°.
   - Make the weight shift visible in the pelvis. This fixes the knock-knees in the guard and the wind-up.
9. **Guard walking.**
   - Use a procedural shuffle step instead: lead foot first, trailing foot closes, low lift, stance width kept, feet never cross.
   - Tie the arms and weapon to the pelvis bounce, with a slight spring lag.
   - Keep the hip-turn walk clips for unguarded running only, and add a brace and back-lean when braking.
10. **Trail and presentation.**
    - Show the trail only during active frames plus about 2 frames of fade, as a tapered ink-brush stroke that never covers the attacker's torso.
    - Make the blade thicker, with a bright edge.
    - Give each fighter a different palette.
    - Lower the camera so blades read against the sky, not the floor.

Next after these: spring bones for the hood and hair, and toning down the skin.

## Conditions for building the first playable on this approach

1. The wrist-limit and self-collision check (fix 1) exists, and every move passes it.
2. Both cuts are re-keyed around a body coil and strong hand-off poses, and pass the gameplay-camera readability review: the attack type is clear early and the cocked hold is visible.
3. Contact is measured to land at the design spacing, and a parry-bounce prototype works off the same path system.
4. Hit-stop, blade lag and follow-through overshoot are in before any playtest judges "weight".
5. Guard walking uses the shuffle step without crossed feet; the duel spends most of its time there.
6. The scrub-and-drag key editor is built before weapon #2. Without it, keying 9 weapons' strings by editing numbers won't get done.
7. Accept the limit of the method: procedural paths cover strings and guard. Ultimates, executions, disarms and the whip need keyed or mocap clips, or physics, blended on top. So do hit and block reactions: the defender is a statue in every shot, and weapon paths don't address that at all.

Detail crops I made for this review are in `<scratch>/review\`: `c1_close_f6_f11.png`, `c2_close_f3_f9.png`, `c2_hands_row1.png` and `c1_ots_row1.png`.