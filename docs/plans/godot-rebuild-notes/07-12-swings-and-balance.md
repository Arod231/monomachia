> Research notes from the Oct 1, 2026 task breakdown, a snapshot of the code at 51dcfb0.
> The plan (`docs/plans/godot-rebuild.md`) is the source of truth: its task ids, order and decisions
> supersede the proposals and keys here. Line numbers drift as the code changes.

# Plan task 7 (weapon swings drive hits) and plan task 12 (computer opponent and balance pass)

## Current state
State on feature/godot-rebuild at 51dcfb0. Tasks 8 to 11 are not built yet. Task 13 is unmerged.

RULES (game/sim). Hits still use the demo's cone.
- World._resolve_combat (world.gd 189-216) calls evaluate() on every active frame until hit_done.
- evaluate() (219-261) checks things in this order:
  - the three counter cones, with margins hard-coded at lines 228-239: thrust range+1.2 and arc/2+35deg, slam +2.6 and +40deg, sweep +0.8 and +20deg;
  - in_volume() (141-150): d - FIGHTER_RADIUS 0.42 <= range, and the half-arc gains 30deg inside 1.3 m;
  - then jumped, flash, evade, parry, block, hit.
- Every hit, block and parry event puts its contact point at the fighters' midpoint, y 1.25 (apply(), line 277). Disarm uses the victim's position at y 1.2 (fighter.gd 993).
- AttackDef (moves/attack_def.gd) has no swing, side or body fields. range, arc and lunge are written by hand on each move (the katana light has 2.2 m, 110deg, 0.35 m). test_moves requires KEYS to equal the script's properties, so every new field must be added to KEYS.
- WeaponDef.reach (2.1 / 2.75 / 1.6 / 1.2) is the AI's preferred distance.
- There is no per-fighter rules data. FighterConfig holds only weapon, abilities and name, and MatchHost (match_host.gd 128) never passes MatchSide.fighter_id.
- V3 and V2 only store numbers and have no vector operations. Trig goes through JsMath. Godot's Vector3 and Quaternion are 32-bit.
- No move uses multi_hit.
- Lunges are linear between lunge_start and lunge_end (fighter.gd 657-667) until task 8 eases them. Attacks keep 30% of velocity (line 601).
- Chains start at S+A+2 at the earliest (line 700).

PRESENTATION (game/view/match).
- StickPose poses the stand-in sticks from the demo's ARCH archetypes, chosen by move.anim: wind-up, impact and follow-through keys on an arc around the vertical axis. It reads no path data.
- Stick lengths are 0.95 / 1.6 / 0.4 m.
- MatchView spawns contact flashes at e["pos"].
- No debug drawing or debug toggle exists.

AI AND TOOLS.
- AIBrain:
  - assumes impact at startup+1 (ai_brain.gd 369);
  - computes reach as range + 0.42 + lunge + 0.6 (373);
  - takes neutral spacing from WeaponDef.reach (433, 494);
  - in _pick_attack (546-563), only knows unblockables that sit in the two block-ability slots.
- TrainingBrain:
  - hard-codes practice distances of 2.6 / 1.8 / 2.2 m (line 97);
  - finds unblockables with ability_for(), which only searches block abilities. So the Greatsword's Low Sweep (a heavy follow-up) and Skewer (a dodge attack) can't be practised.
- counterlab.gd runs only three cases: slam with the Greatsword, thrust with the Katana, sweep with the Greatsword.
- soak.gd:
  - prints wins and losses per weapon, and a mirror match counts as both;
  - prints no percentages and checks no targets;
  - checks "left the arena" against a hard-coded 12 m (task 8's job).
- The AI-parity and golden tests retire at task 8.

THE SPIKE (scratchpad prior/spike-anim).
- swing.gd keys a grip point around a sternum pivot at (0, 1.25, 0.05).
- It splines the blade and edge directions on their own. That caused the critique's "propeller" recovery and the wrist-flip wind-up.
- It works out chest and pelvis yaw from the grip angle (attack_driver.gd). The critique says to key them instead.
- Its 0.35 m lunge left the tip 0.63 m short of a defender at 2.5 m.
- rig.gd numbers: arm length 0.4895 m, palm offset (0, 0.064, 0.026), grip roll 25deg, tilt 28deg.

TASK 13 (fighters-and-weapons, fcfb8d8, unmerged).
- WeaponLook defines weapon space: origin at the main grip, +Y along the blade, +X toward the edge.
- Each weapon has BladeBase, BladeTip and OffHandGrip markers:
  - Katana: base y 0.09, tip (-0.077, 0.777);
  - Greatsword: base 0.136, tip 1.352, off hand -0.266;
  - Dagger: base 0.062, tip (-0.019, 0.322).
- test_fighters checks that no blade enters the torso or thighs in the idle poses.
- The Rogue holds her daggers reversed along her forearms.
- The rules must not load these scenes, so they need their own copy of the blade numbers.

HOW THE SWING SPLITS BETWEEN LAYERS.
- Rules layer (pure 64-bit math, no nodes):
  - the swing keys and the per-tick samples built from them (grip, hand frame, blade base and tip, torso and pelvis coil);
  - the hurt capsule, the quad sweep test and first-touch timing;
  - contact points, and reach and arc derived from the paths.
- Presentation:
  - IK;
  - blending from the cut pose into a chained entry;
  - blade lag and overshoot, trails, and the debug drawing.
- The wrist-limit and 5 cm self-collision checks run headless as pure math on a reference body: analytic two-bone elbows and proxy capsules, with numbers measured from the Rogue and Hunter rigs. Task 14 repeats the checks on the real IK rig.

## Tasks

### [7] v3-math (S): 64-bit vector and rotation helpers for the rules
- delivers: Static vector helpers on V3, all on 64-bit floats with no Godot Vector3 in the rules path: add, sub, scale, dot, cross, length (sqrt), normalized, lerp, distance. | Quat64, a 64-bit rotation with trig through JsMath: from an axis pair, compose, rotate a V3, nlerp and slerp, angle between. | SimMath.local_to_world(pos, yaw, right, up, forward), built on SimMath.fwd and right. right(yaw) = (-cos, sin), so a fighter's right is -x at yaw 0.
- check: test_v3_math covers identities, cross-product handedness, slerp endpoints and midpoint, rotation round trips, and local_to_world against fwd and right at yaw 0 and pi/2. | No behaviour changes: every existing test passes. | npm test and npm run typecheck pass.
- depends: 9, 10, 11
- stories: 59
- files: game/sim/v3.gd, game/sim/quat64.gd (new), game/sim/sim_math.gd, game/tests/sim/test_v3_math.gd (new)
- notes: V3 is make() only (25 lines). The spec keeps rules positions 64-bit and trig on JsMath, but Godot's Vector3 and Quaternion are 32-bit. This task doesn't technically need tasks 9-11; they are listed only to keep the plan's phase-C order (see open questions).

### [7] swing-format (M): Swing data format and arc sampler
- delivers: A Swing object on each move:
- timing equal to the move's startup, active and recovery;
- one or two tracks, each with a part (right hand, left hand, right foot, left foot, body) and a list of keys;
- each key holds a frame, a grip point in the fighter's own space (right, up, forward), the weapon's orientation (blade direction plus edge, which is the hand frame for a rigid grip), torso coil and pelvis coil in degrees, an optional elbow-pole tweak, and an ease (0 means zero velocity, used for the cocked hold and the settle). | The sampler, starting from the spike's swing.gd:
- Catmull-Rom tangents in time with Hermite segments;
- the grip's offset from a shoulder-line pivot splined in direction, with its radius splined separately, so hands travel on an arc;
- the orientation interpolated relative to the grip's arc frame, so the blade turns with the hands instead of being splined on its own as in the spike. | Per-tick tables built once at load (grip, orientation, coil), and sample(t) at fractional frames for presentation. Frames past the end hold the last sample. | AttackDef gains `swing` (null when absent), parsed from a const Dictionary record. Nothing reads it yet. | GLOSSARY.md entries for Swing, Hurt capsule, Sweep and Contact point.
- check: test_swing_sampler:
- samples equal the keys at key frames;
- ease-0 keys have zero grip velocity;
- the grip's distance to the pivot stays between neighbouring keys' radii (an arc, not a chord);
- the edge stays perpendicular to the blade in every sample;
- a 90deg hand sweep with a constant wrist offset turns the blade 90deg with it;
- two loads give bit-identical tables. | test_moves still passes with "swing" added to AttackDef.KEYS. | npm test and npm run typecheck pass.
- depends: v3-math
- stories: 16, 21, 59
- files: game/sim/swings/swing.gd (new), game/sim/swings/swing_sampler.gd (new), game/sim/moves/attack_def.gd, game/tests/sim/test_swing_sampler.gd (new), GLOSSARY.md, docs/specs/godot-rebuild.md (record the format in the Weapon swings section)
- notes: Spike conventions: authoring space is RUF, and Godot's fighter-local space has +X to the left. The critique's fix 1 says to stop splining the blade direction on its own. Here the blade follows the hand's arc frame, and the swing-checks task enforces the wrist limits on every tick. Rules sampling uses V3, Quat64 and JsMath, so it is deterministic.

### [7] swing-entries (S): Swing entries from guard and from the previous move, and the exit to guard
- delivers: A swing's timeline has four parts:
- an entry from guard, whose frame 0 is the weapon's guard key;
- an optional entry from the previous move, starting at that move's hand-off key;
- the main path: end of the wind-up, cocked hold, strike, follow-through and hand-off key;
- an exit that reaches guard on the last recovery frame. | A guard key per weapon in the rules data (grip, orientation, coil), with first values taken from StickPose.GUARD. | AttackState records the move it chained from, set when start_attack runs from a queued chain. The sampler picks the matching entry. Active frames are identical for either entry, so hits never depend on how a move was entered.
- check: Tests with synthetic swings:
- a chained start samples the previous move's hand-off pose on frame 0;
- a fresh start samples the guard;
- active-frame samples are identical either way. | test_swing_continuity: for every chain_light and chain_heavy pair whose moves both have swings, the follow-up's chained entry starts within 2 cm and 10deg of the previous move's hand-off key. It is empty until swings are authored, and it complements the spec's side_end/side_start test from tasks 9-11. | npm test and npm run typecheck pass.
- depends: swing-format
- stories: 16
- files: game/sim/swings/swing.gd, game/sim/swings/swing_sampler.gd, game/sim/moves/weapon_def.gd (guard key), game/sim/attack_state.gd, game/sim/fighter.gd (start_attack records chained_from), game/tests/sim/test_swing_entries.gd (new), game/tests/sim/test_swing_continuity.gd (new)
- notes: Chains cut the previous move at S+A+2 or later, which is often before its follow-through ends. Blending from the actual cut pose is presentation work (standin-follows-swing, then task 14). The rules only need the entry choice.

### [7] hurt-capsule-blades (S): Hurt capsules and blade dimensions in the rules data
- delivers: FighterBody, rules data per fighter id: hurt capsule radius 0.35 m and height 1.75 m for the Rogue and the Hunter (spec), plus a default for tests. | FighterConfig carries the fighter id and its body, and MatchHost passes MatchSide.fighter_id. Fighter.hurt_capsule() returns the capsule's world-space axis segment, raised by pos.y while airborne. | WeaponDef gains blade base and tip points in weapon space (origin at the main grip, +Y along the blade) and a sweep thickness, copied from task 13's markers:
- Katana: base (0, 0.09, 0), tip (-0.077, 0.777, 0);
- Greatsword: base 0.136, tip 1.352;
- Dagger: base 0.062, tip (-0.019, 0.322, 0).
Bare hands get fist and foot strike segments. | FIGHTER_RADIUS (0.42, used for spacing and the cone fallback) stays separate from the hurt radius.
- check: test_hurt_capsule: the capsule's bottom follows a jump's height, and a config without a fighter id gets the default. | Content test: each weapon's rules blade points match its WeaponLook BladeBase and BladeTip markers within 1 cm. The rules themselves never load the scenes. | test_moves passes with the new WeaponDef.KEYS. | Every existing test passes unchanged. | npm test and npm run typecheck pass.
- depends: v3-math, 13
- stories: 21, 44, 59, 63
- files: game/sim/fighter_body.gd (new), game/sim/fighter_config.gd, game/sim/fighter.gd, game/view/match/match_host.gd (World.new at line 128), game/sim/moves/weapon_def.gd, game/sim/moves/katana.gd, game/sim/moves/greatsword.gd, game/sim/moves/daggers.gd, game/sim/moves/fists.gd, game/tests/sim/test_hurt_capsule.gd (new), game/tests/content/test_weapons.gd
- notes: Needs task 13 merged (the plan merges it first on resume). The rules keep their own blade numbers because "sim never loads PackedScenes". The content test keeps the two copies in step.

### [7] swing-checks (M): Headless wrist, elbow and self-collision checks on a reference body
- delivers: ReferenceBody: the rest-pose numbers for the Rogue and for the Hunter, measured once from task 13's skeletons and committed as data:
- shoulder points, upper-arm and forearm lengths and the spine axis;
- proxy capsules for the torso, the head (with mask or tricorn), thighs, upper arms and forearms.
Torso coil turns the chest proxies and shoulders about the spine; pelvis coil turns the thighs. | SwingCheck, run on every tick of a swing (both entries and the exit) for each hand track:
- solves the elbow analytically: two bones, a default pole down-out-back, and the key's pole tweak;
- reports wrist bend against forearm (limit +-60deg) and deviation (limit +-25deg);
- reports the elbow angle (never locked: under 170deg);
- reports the blade's distance to every proxy, minus half its thickness, including the other arm (limit 5 cm);
- exempts sheathed keys, foot and body tracks, and the gripping fist. | test_swings_valid: runs the check on every move that has a swing, against both reference bodies. It is empty until swings are authored.
- check: test_swing_check:
- a synthetic good swing passes;
- one with the wrist bent 75deg at frame 6 fails and names frame 6 and the wrist;
- one whose blade crosses the head proxy at frame 4 fails and names frame 4;
- one crossing the off-hand forearm fails. | Content test: the committed reference numbers match the Rogue and Hunter skeletons' rest bones within 1 cm. It runs headless like task 13's content tests. | npm test and npm run typecheck pass.
- depends: swing-entries, hurt-capsule-blades, 13
- stories: 21, 59, 60
- files: game/sim/swings/reference_body.gd (new), game/sim/swings/swing_check.gd (new), game/tests/sim/test_swing_check.gd (new), game/tests/sim/test_swings_valid.gd (new), game/tests/content/test_reference_bodies.gd (new)
- notes: This is the critique's fix 1: an automatic check that fails any frame past the wrist limits, or where the blade comes within about 5 cm of the head, hood, forearms or torso. It is pure math with no nodes, so GUT runs it headless and the swing editor (14b) can show it live. Task 14 re-checks the same limits on the real TwoBoneIK3D rig. The two fighters have different proportions (female and male Ranger rigs), so every swing must pass on both.

### [7] sweep-geometry (M): Blade sweep against a capsule
- delivers: Sweep, pure 64-bit math:
- closest points between two segments, and between a segment and a triangle;
- a swept-quad test: blade base and tip at the previous tick, then tip and base at this tick, split into two triangles, tested against a capsule (axis segment plus radius), with half the blade thickness added. | The result: touched or not, the contact point on the blade (the quad point nearest the capsule axis), and the penetration depth. | The length of a blade segment that lies inside a capsule, for the reach tests.
- check: test_sweep:
- a quad crossing the capsule touches;
- quads passing 10 cm above its top, or behind it, miss;
- a graze within radius plus half-thickness touches, and one 1 cm further out misses;
- a quad with no blade motion reduces to segment against capsule;
- a 0.6 m per tick sweep through a 0.35 m capsule doesn't tunnel;
- parallel and coplanar cases are stable;
- the contact point lies on the quad. | npm test and npm run typecheck pass.
- depends: v3-math
- stories: 21, 59
- files: game/sim/swings/sweep.gd (new), game/tests/sim/test_sweep.gd (new)
- notes: Recon measured peak hand speeds of about 0.43 m per tick in the pack's sword clips, and the tip moves faster still, so testing sampled positions alone would miss hits. Only the blade's motion is swept; the defender's capsule is taken at the current tick.

### [7] blade-per-tick (S): The blade's place in the world each tick
- delivers: While a fighter attacks with a move that has a swing, AttackState keeps each striking track's world-space blade segment (base and tip) for this tick and the previous one. It is built from the per-tick sample, the weapon's blade points, the fighter's position (height and lunge included) and the fighter's yaw. | Sampling follows atk.frame:
- it holds while charging;
- a sheathed key has no blade;
- it holds the last sample through extra recovery. | Fighter.blade_segments(), a read-only accessor for the stand-in and the debug view. | tests/sim/swing_fixtures.gd: a synthetic test weapon and moves with simple swings, reused by the later tests.
- check: Tests with a synthetic swing:
- the world tip equals pos + right(yaw)*r + up*u + fwd(yaw)*f at yaw 0 and pi/2;
- the segment advances with the lunge and turns with tracking;
- it holds still while charging and through hit-stop;
- on the first tick the previous segment equals the current one. | npm test and npm run typecheck pass.
- depends: swing-entries, hurt-capsule-blades
- stories: 21, 59
- files: game/sim/attack_state.gd, game/sim/fighter.gd, game/tests/sim/swing_fixtures.gd (new), game/tests/sim/test_blade_per_tick.gd (new)
- notes: World.step updates the fighters (lunge included) before _resolve_combat, so the current segment is taken after the move.

### [7] sweep-hits (M): Swing sweeps decide hits, with the cone kept for moves without a swing
- delivers: World._resolve_combat: for a move with a swing, each active frame sweeps every striking track from the previous tick to this one against the defender's hurt capsule.
- No touch: nothing happens that frame.
- The first touch decides the outcome in the demo's order: the counters' cone checks first (unchanged), then jumped, flash, evade, parry, block, hit. | A whiff when the active frames pass with no touch. | Multi-hit moves count only touching ticks. | Moves without a swing, and scripted hits, keep World.in_volume, so the Duel plays unchanged while swings are being authored.
- check: test_swing_hits, the spec's swing-hit tests on synthetic moves:
- a blade passing behind the defender misses;
- one passing above misses;
- a low sweep misses a jumping defender;
- the hit lands on the frame the blade first touches (here the second active frame);
- a first touch after the active frames is a whiff;
- a parry timed to the first-touch frame parries;
- holding block at first touch blocks. | Every existing test passes unchanged, because no real move has a swing yet. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: sweep-geometry, blade-per-tick
- stories: 21, 24, 41, 59
- files: game/sim/world.gd (_resolve_combat 189-216, evaluate 219-261), game/tests/sim/test_swing_hits.gd (new), game/tests/sim/swing_fixtures.gd
- notes: Parry and block stay timing-only, with no blade-against-blade geometry (recon recommendation), and are judged at first touch. The jumpable flag stays the explicit rule, so a jump that the sweep still touches reports `jumped`.

### [7] contact-points (S): Contact points on hit, block and parry events
- delivers: Hit, block and parry events from a swing carry the blade's contact point from the sweep, instead of the fighters' midpoint at 1.25 m (world.gd apply(), line 277). | Cone-fallback moves and scripted ultimate hits keep the midpoint. | MatchView's contact flashes (_spawn_flash) move onto the blade with no view change.
- check: Tests:
- a hit event's pos lies on the attacker's blade quad at that tick, within capsule radius plus half-thickness of the defender's axis;
- a parry's and a block's pos do the same;
- a Moonsplitter wave hit still uses the midpoint. | npm test and npm run typecheck pass.
- depends: sweep-hits
- stories: 40, 48
- files: game/sim/world.gd, game/sim/events.gd (document pos), game/tests/sim/test_swing_hits.gd
- notes: The parry rebound (task 15) and sparks (task 18) start at this point.

### [7] unblockable-blade (S): Unblockables sweep a thicker blade
- delivers: An unblockable move's sweep adds SimConst.UNBLOCKABLE_SWEEP_BONUS to its blade's half-thickness, which gives the longer reach the spec asks for. | The value is readable by presentation, for task 18's reach effect on the warning mark.
- check: The spec test: a synthetic unblockable hits at a distance where the identical swing without the flag misses. | Normal moves are unchanged. | npm test and npm run typecheck pass.
- depends: sweep-hits
- stories: 22
- files: game/sim/constants.gd, game/sim/world.gd, game/tests/sim/test_swing_hits.gd
- notes: The bonus size is an open question.

### [7] standin-follows-swing (M): Stand-in weapons follow the swings
- delivers: StickPose poses each track's grip and blade direction from the move's swing at the display frame (atk.frame - 1 + alpha), using the chained or guard entry, and turns the stand-in body by the torso coil. | The ARCH archetypes remain only for moves without a swing. | During a chain, the stick blends from the cut pose into the chained entry over 3 frames instead of popping. | FighterStandin draws its stick from the grip to the rules' blade tip, so the blade on screen is the blade that hits. Today's sticks are 0.95 / 1.6 / 0.4 m; the rules tips are about 0.78 / 1.35 / 0.32 m.
- check: test_stick_pose:
- for a synthetic swing move, the stick tip matches Fighter.blade_segments() at whole frames;
- moves without a swing keep their old poses;
- test_each_standin_blade_is_as_long_as_its_stick is updated, with the reason in the commit. | Screenshots of a synthetic swing at wind-up, contact and follow-through, reviewed by eye. | npm test and npm run typecheck pass.
- depends: blade-per-tick, swing-entries
- stories: 16, 19, 21
- files: game/view/match/stick_pose.gd, game/view/match/fighter_standin.gd, game/view/match/match_view.gd (dropped-weapon length uses StickPose.LENGTH), game/tests/view/test_stick_pose.gd
- notes: Presentation only reads rules state. StickPose is replaced by real animation in tasks 14-15.

### [7] sweep-debug-view (M): Debug view of blade sweeps and hurt capsules
- delivers: SwingDebugView in the match scene draws:
- wire hurt capsules;
- each striking blade segment;
- the swept quads of the active frames, kept for about a second;
- contact points coloured by outcome (hit, block, parry, whiff). | It is turned on by an exported MatchView flag, by F3 in debug builds, or by a --swing-debug argument to npm run godot:run. | A screenshot scene, tools/shot_scenes/swing_debug.tscn, that steps a scripted duel to a hit, a block and a whiff.
- check: A headless test: the view draws one quad per active tick and one contact marker per touch. | Screenshots of the three moments, reviewed by eye: the sweeps meet the capsule where the flash appears. | npm test and npm run typecheck pass.
- depends: contact-points, standin-follows-swing
- stories: 21, 65
- files: game/view/match/swing_debug_view.gd (new), game/view/match/match_view.gd, game/tools/shot_scenes/swing_debug.tscn (new), game/tools/shot_scenes/skeleton_shot.gd (or a new swing_shot.gd), game/tests/view/test_swing_debug_view.gd (new)
- notes: Built before any authoring, so every authoring task can show its sweeps in screenshots.

### [7] derived-reach-arc (M): Reach and arc derived from each swing
- delivers: At load, each swing gets:
- reach: the furthest horizontal blade reach during the active frames, plus half-thickness, measured from the root without the lunge (the demo's meaning of range);
- arc: twice the largest bearing of the blade from facing during the active frames, or 360 for spins. | SwingReach.first_contact(def, weapon, distance, bearing, capsule), a pure function returning the first-touch frame and the blade depth against a standing capsule, lunge included. The AI and the reach tests use it. | AttackDef helpers give the swing's values when a move has a swing and the authored range and arc otherwise. | Users switch to them:
- AIBrain's reach checks (ai_brain.gd 373, 433, 494);
- WeaponDef.reach, the AI's preferred distance, derived from the light starter;
- TrainingBrain's practice distance (training_brain.gd 97, today 2.6 / 1.8 / 2.2), taken from WeaponDef.reach. | The counter cones keep reading the authored range and arc until the counters-from-paths task.
- check: test_swing_reach:
- a synthetic slash's reach and arc equal hand-computed values;
- a spin's arc is 360;
- first_contact agrees with a stepped World at three distances. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: sweep-geometry, blade-per-tick
- stories: 5, 53, 58
- files: game/sim/swings/swing_reach.gd (new), game/sim/moves/attack_def.gd, game/sim/moves/weapon_def.gd, game/sim/ai/ai_brain.gd, game/sim/ai/training_brain.gd, game/tests/sim/test_swing_reach.gd (new)
- notes: Deriving before authoring means the AI's sense of reach matches the real blade from the moment a move gets a swing. Today's authored ranges (the katana light's 2.2 m) are far longer than a real blade's 1.4-1.6 m.

### [7] duel-reach-test (S): The duelling-distance reach test
- delivers: test_duel_reach, a parametrised test over every light with a swing. At its weapon's duelling distance:
- the blade's last 15-20 cm enters the defender's capsule during the active frames;
- the lunge ends on the first-touch frame, so the front foot lands on contact. | The same harness checks that a light started 6 m away whiffs. | Per-weapon duelling distances, if the owner picks them, live in the rules data.
- check: The test runs (empty until the lights have swings) and fails on a synthetic light whose blade only grazes. | npm test and npm run typecheck pass.
- depends: derived-reach-arc
- stories: 21
- files: game/tests/sim/test_duel_reach.gd (new), game/sim/moves/weapon_def.gd (duelling distance, if per weapon)
- notes: Spec: lunges of 0.7-0.8 m on lights, front foot landing on the contact frame, and the last 15-20 cm of blade entering a defender 2.5 m away. Lunge easing is task 8's.

### [7] swing-shapes-cuts (M): Named swing shapes: the cuts
- delivers: SwingShapes builders for:
- the right-to-left slash;
- the left-to-right slash;
- the falling (kesa) diagonal;
- the rising diagonal;
- the overhead. | Each builder makes a full swing from the move's frame data:
- the entry from guard and the chained entry;
- a 40-60deg coil away in the wind-up, with the pelvis back over the rear foot;
- a 2-4 frame cocked hold (ease-0 keys);
- the strike across the active frames, hips leading;
- arm extension giving elbows of 150-160deg at contact;
- a follow-through overshoot and settle, a hand-off key, and the exit to guard. | Per-move tweaks as parameters: height, depth, side, contact frame, coil and extension. | Hands travel from one shoulder to the opposite hip and never cross in front of the face (critique fix 2).
- check: test_swing_shapes, for each shape at default parameters:
- it passes SwingCheck on both reference bodies with the Katana and the Greatsword;
- it has a 2-4 frame cocked hold and a 40-60deg coil;
- a slash's blade at contact is more than 45deg off the facing axis, so it never reads as a thrust. | Stand-in screenshots of each shape from the gameplay camera at one third of the wind-up, at contact and at follow-through, reviewed by eye: slash and overhead are told apart by the first third of the wind-up. | npm test and npm run typecheck pass.
- depends: swing-checks, standin-follows-swing
- stories: 16, 19, 21
- files: game/sim/swings/swing_shapes.gd (new), game/tests/sim/test_swing_shapes.gd (new), game/tools/shot_scenes/swing_shapes.tscn (new)
- notes: Spec: swings are built from a small set of named shapes with per-move tweaks. The cuts come first because the Katana's lights and heavies use them. The spike's Right Cut and Return Cut keys are the starting point, but critique fixes 2-5 apply: a keyed coil, hand-off poses, and an early load out to the right rather than straight up.

### [7] katana-light-swings (M): The Katana's four-light string on swings
- delivers: Swings for Right Cut, Return Cut, Kesa Cut and Crown Cut (ids from task 9), built from the shapes with per-move tweaks. Each one ends on the next one's start; for example, Right Cut ends low left and Return Cut starts there. | Lunges re-tuned to 0.7-0.8 m, ending on the contact frame, so the last 15-20 cm of blade enters a defender 2.5 m away. | The spec's Katana numbers updated.
- check: SwingCheck passes for all four moves on both bodies. | The continuity test passes for the string. | test_duel_reach passes for the four lights. | Combat tests that use the Katana light (the hit at gap 2.2, the parry timing of 4 frames, block, chain) pass, or are updated with the reason in the commit (the first-touch frame moved). | Debug-view screenshots of each cut, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: swing-shapes-cuts, duel-reach-test, sweep-debug-view, unblockable-blade, 9
- stories: 16, 18, 21, 25
- files: game/sim/moves/katana_swings.gd (new; see the storage open question), game/sim/moves/katana.gd, game/tests/sim/test_combat.gd (if timings move), docs/specs/godot-rebuild.md
- notes: These are the first real moves on sweeps. The Katana's other moves stay on the cone fallback. If the reach can't be met with a 0.8 m lunge and elbows at 150-160deg, raise the weapon-scale question (risk) instead of breaking the arm limits.

### [7] swing-shapes-more (M): Named swing shapes: thrusts, sweeps, spins and specials
- delivers: SwingShapes builders for:
- thrust and stab;
- double stab and crossing cut (two hand tracks);
- low sweep;
- spin (body turn carried by the coil);
- slam (overhead to the ground);
- draw cut;
- the Iai sheathe-and-draw. | A `sheathed` key flag: the blade is in the scabbard and has no striking segment. It is held through the charge.
- check: Each new shape passes SwingCheck on both bodies with its weapons. | Thrust contact points the blade within 15deg of facing. | A low sweep's blade stays below 0.5 m during the active frames. | A spin's derived arc is 360. | Stand-in screenshots from the gameplay camera, reviewed by eye: thrust, sweep and overhead are told apart by the first third of the wind-up. | npm test and npm run typecheck pass.
- depends: katana-light-swings
- stories: 19, 21, 26
- files: game/sim/swings/swing_shapes.gd, game/sim/swings/swing.gd (sheathed flag), game/tests/sim/test_swing_shapes.gd, game/tools/shot_scenes/swing_shapes.tscn
- notes: Placed after the Katana lights so the cut shapes are proven on real moves first.

### [7] katana-heavy-swings (M): The Katana's heavies on swings: Iai Slashes, Rising Heaven, Returning Draw, Heaven Splitter
- delivers: Swings for:
- Iai Slash (vertical): sheathed pose held while charging, vertical draw on release;
- Iai Slash (horizontal): right-to-left draw;
- Rising Heaven;
- Returning Draw;
- Heaven Splitter. | Lunges tuned so the Iai reaches about 3.6 m (spec) and the others reach the duelling distance.
- check: SwingCheck passes on both bodies; sheathed keys are exempt. | Continuity passes for the chains: Iai vertical to Rising Heaven, Iai horizontal to Returning Draw and to Return Cut, Rising Heaven to Heaven Splitter, Right Cut and Kesa Cut to Heaven Splitter, Return Cut to Rising Heaven. | The Iai's last 15-20 cm enters a defender at 3.6 m and misses at 4.2 m. | Task 9's Katana tests (Iai by stick, follow-ups, auto-release, dodge cancelling the stance) still pass. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: swing-shapes-more
- stories: 16, 18, 26, 27, 28, 29
- files: game/sim/moves/katana_swings.gd, game/sim/moves/katana.gd, docs/specs/godot-rebuild.md
- notes: Move ids and the charge_move and release_variant fields come from task 9; follow what it built.

### [7] katana-movement-swings (M): The Katana's movement attacks, Flash and Counter Lunge on swings
- delivers: Swings for:
- Running Draw and Leaping Cleave (sprint);
- Wind Cut and Whirl Cut (dodge);
- Rising Cut and Lunging Cut (backstep);
- Aerial Cut and Falling Crown (jump);
- Counter Lunge. | Flash as a pose-only swing with no striking track.
- check: SwingCheck and continuity pass. | Each move hits a standing defender at the distance it is used from: sprint and back attacks with their long lunges, jump attacks from the air. | The combat tests touching these moves pass, including the evade counter's follow-up Counter Lunge hit (test_combat line 293), or are updated with the reason. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: katana-heavy-swings
- stories: 21, 30, 41
- files: game/sim/moves/katana_swings.gd, game/sim/moves/katana.gd, game/tests/sim/test_combat.gd (if updated)
- notes: Counter Lunge's lunge is computed at start from the distance (fighter.gd 570-574). Its swing only has to reach from the minimum gap of 1.09 m. The Katana's unblockables (Piercing Thrust, Swallow Sweep) are in unblockable-swings.

### [7] greatsword-string-swings (M): The Greatsword's string, heavies and Piercing Lunge on swings
- delivers: Two-handed swings, with the off hand at OffHandGrip (-0.266 m), for:
- Heavy Swing;
- Backswing, starting faster from momentum;
- Overhead Strike, which is chargeable;
- Piercing Lunge, the blockable dodge thrust. | Lunges tuned to the Greatsword's duelling distance. | The colossal recovery slide's direction taken from the follow-through, if task 8 used a stand-in direction.
- check: SwingCheck passes on both bodies. | Continuity passes for L-L-H: Heavy Swing to Backswing to Overhead Strike. | test_duel_reach passes for both lights. | Task 10's Greatsword tests pass. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: swing-shapes-more, 10
- stories: 18, 20, 31, 33
- files: game/sim/moves/greatsword_swings.gd (new), game/sim/moves/greatsword.gd, docs/specs/godot-rebuild.md
- notes: Low Sweep and Skewer are unblockables and come in unblockable-swings.

### [7] greatsword-movement-swings (M): The Greatsword's movement attacks, Guard Crusher and Counter Lunge on swings
- delivers: Swings for:
- Shoulder Charge and Guard Crusher, bash moves struck with a body track at the shoulder or hilt;
- Leaping Smash;
- Rising Edge and Lunge Cleave;
- Aerial Chop and Meteor Drop;
- Counter Lunge.
- check: SwingCheck passes on both bodies (body tracks are exempt from the wrist check). | Each move hits from the distance it is used at. | The Guard Crusher golden-free tests and the posture-crush rule still pass. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: greatsword-string-swings
- stories: 21, 34
- files: game/sim/moves/greatsword_swings.gd, game/sim/moves/greatsword.gd
- notes: Bash moves have no blade contact. The owner should confirm what strikes in them (open question).

### [7] daggers-string-swings (M): The Daggers' string, Twin Fang, Spinning Backhand and Passing Cut on swings
- delivers: Two-track swings (right and left dagger) for:
- Quick Slice (right hand, right to left);
- Off-hand Slice (left hand, left to right);
- Twin Rip (crossing cut);
- Flurry Finisher (double stab);
- Twin Fang (dashing double stab, 1.4 m lunge);
- Spinning Backhand;
- Passing Cut, which lunges along the dodge. | Lunges tuned to the Daggers' duelling distance.
- check: SwingCheck passes on both bodies for both tracks. | Continuity passes for the alternating string and for Twin Fang to Spinning Backhand. | test_duel_reach passes for the lights. | Task 11's Daggers tests pass: dodge-cancel timing, no loop from Twin Fang, Passing Cut's direction. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: swing-shapes-more, 11
- stories: 16, 35, 36, 37, 38
- files: game/sim/moves/daggers_swings.gd (new), game/sim/moves/daggers.gd, docs/specs/godot-rebuild.md
- notes: The idle hand's dagger is a non-striking track. The forward or reverse grip is an open question, because the 5 cm forearm check rejects task 13's reversed idle grip.

### [7] daggers-movement-swings (M): The Daggers' movement attacks, Shadow Step and Counter Lunge on swings
- delivers: Swings for:
- Slide Slash and Pounce (sprint);
- Reverse Spin (dodge heavy);
- Flick and Rebound Lunge (backstep);
- Air Slash and Dive Stab (jump);
- Counter Lunge. | Shadow Step as a pose-only swing.
- check: SwingCheck and continuity pass. | Each move hits from the distance it is used at. | The Shadow Step backstab tests pass. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: daggers-string-swings
- stories: 21, 39
- files: game/sim/moves/daggers_swings.gd, game/sim/moves/daggers.gd
- notes: Serpent Sweep and Needle Thrust come in unblockable-swings.

### [7] bare-hand-punch-swings (M): Bare-hand punches on swings
- delivers: Fist-track swings for:
- Jab and Cross;
- Hook;
- Slip Jab;
- Spinning Backfist;
- Lunging Palm;
- Counter Lunge;
- Breaker Palm. | A fist strike segment from WeaponDef (fists).
- check: SwingCheck passes on both bodies; the fist is the striking part, so only the elbow and other-arm checks apply. | Continuity passes for Jab to Cross to Hook. | Each move hits a standing defender at its distance. | The disarmed tests pass: a disarmed fighter can't block, redirect, Breaker Palm. | Debug-view screenshots, reviewed by eye. | npm test and npm run typecheck pass.
- depends: swing-shapes-more
- stories: 21, 41
- files: game/sim/moves/fists_swings.gd (new), game/sim/moves/fists.gd
- notes: Bare hands are shared by every fighter (spec: fighters share the bare-hand moveset).

### [7] bare-hand-kick-swings (M): Bare-hand kicks on swings
- delivers: Foot-track swings with a hip pivot for:
- Roundhouse and Spinning Heel;
- Flying Knee;
- Dragon Kick;
- Snap Kick;
- Air Kick;
- Axe Kick.
- check: Each kick hits a standing defender at its distance and misses one 6 m away. | Continuity passes for Hook to Roundhouse to Spinning Heel. | Wrist checks don't apply to foot tracks. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: bare-hand-punch-swings
- stories: 21, 41
- files: game/sim/moves/fists_swings.gd, game/sim/moves/fists.gd
- notes: Kicks need the foot track part from swing-format, a hip pivot, and a foot strike segment from the fists WeaponDef. Flying Knee strikes with the knee: use a short shin segment as its striking part.

### [7] unblockable-swings (L): The unblockables on swings
- delivers: Swings for:
- Piercing Thrust and Swallow Sweep (Katana);
- Reaping Sweep, Mountain Slam, Low Sweep and Skewer (Greatsword);
- Serpent Sweep and Needle Thrust (Daggers).
They use the thrust, sweep and slam shapes and the thick-blade bonus. | Low Sweep is narrower and faster than Reaping Sweep and low enough that a jump clears it. | The counters still read the authored range and arc in this task.
- check: SwingCheck passes on both bodies. | Continuity passes for Overhead Strike to Low Sweep. | The spec tests on real moves:
- the Low Sweep misses a jumping defender;
- an unblockable hits at a range where the same weapon's light misses. | The combat tests on unblockables pass (gap 1.6 and 2.2):
- blocking takes the full hit;
- blocking with a full meter disarms;
- dodge invincibility doesn't help;
- stomp, leap and evade are each still triggered. | Debug-view screenshots, reviewed by eye. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: katana-movement-swings, greatsword-movement-swings, daggers-movement-swings
- stories: 22, 30, 32, 33, 34, 39, 41
- files: game/sim/moves/katana_swings.gd, game/sim/moves/greatsword_swings.gd, game/sim/moves/daggers_swings.gd, game/sim/moves/katana.gd, game/sim/moves/greatsword.gd, game/sim/moves/daggers.gd, game/tests/sim/test_combat.gd (if updated)
- notes: All the unblockables are kept together so the next task can move all three counter cones onto the paths in one change.

### [7] counters-from-paths (M): The counters' generous cones measured from the paths
- delivers: The stomp, leap and evade checks in World.evaluate (lines 228-239) use the swing's derived reach and arc, with their margins moved from hard-coded numbers to SimConst. | The margins are re-tuned so each counter stays as generous as in the demo.
- check: The combat tests for stomp (gap 2.2), leap (gap 2.2) and evade (gap 2.4) pass. | counterlab's three cases (slam with the Greatsword, thrust with the Katana, sweep with the Greatsword) count at least as many counters as before the change. The before and after tallies go in the commit message. | npm test and npm run typecheck pass.
- depends: unblockable-swings
- stories: 41
- files: game/sim/world.gd, game/sim/constants.gd, game/tools/counterlab.gd (run only)
- notes: Derived ranges exclude the lunge and are much shorter than the authored ones (Mountain Slam 3.2 m, Piercing Thrust 3.1 m), so the old margins would make the counters stingy. Extending counterlab to every unblockable is task 12's (counterlab-every-unblockable).

### [7] retire-cones (M): Every move hits by its swing; the cone is kept for scripted hits only
- delivers: A test that every move with damage or posture has a swing, and every zero-damage stance has a pose-only swing. | World.in_volume serves scripted ultimate hits only; the cone fallback is removed. | For moves with swings, the authored range and arc are deleted and filled from the swing at load. finalize_moves reports an error when a swing move also writes them by hand. | The old tests updated where needed, each with its reason in the commit.
- check: All the spec's swing-hit tests also pass on real moves. | Debug-view screenshots of each weapon's string, reviewed by eye. | A 40-match soak runs clean. | The spec's Weapon swings section and numbers are updated, and task 7 is ticked in the plan. | npm test and npm run typecheck pass.
- depends: counters-from-paths, bare-hand-kick-swings
- stories: 21, 58, 59, 62
- files: game/sim/world.gd, game/sim/moves/attack_def.gd, game/sim/moves/katana.gd, game/sim/moves/greatsword.gd, game/sim/moves/daggers.gd, game/sim/moves/fists.gd, game/tests/sim/test_swings_valid.gd, docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md
- notes: Moonsplitter's wave, Impaler and Tempest keep their own checks (spec). ULT_HITS keep their authored range and arc.

### [12] soak-targets (S): Soak reports the balance targets
- delivers: The soak prints:
- each weapon's win rate in percent, with mirror matches left out of the rates;
- disarms per round in total;
- the average round length;
- a targets block marking each number in or out of the spec's ranges: rounds 35-60 s, 0.3-0.6 disarms per round, each weapon 45-55%. | A larger tuning run (for example 300 matches) without changing the 40-match check. | The exit code still reflects only failures.
- check: A soak test with a short frame limit checks the new report lines and the mirror exclusion. | npm run soak:godot -- 40 runs clean. | npm test and npm run typecheck pass.
- depends: 8
- stories: 62
- files: game/tools/soak.gd, game/tests/sim/test_port_regressions.gd (soak tests) or game/tests/sim/test_soak.gd (new)
- notes: Today the soak counts a mirror match as both a win and a loss for the same weapon and prints no percentages. It needs only task 8 (the arena check) and could run earlier.

### [12] brain-contact-timing (M): The computer times its defence from the swing's first touch
- delivers: AIBrain._respond_to predicts impact with SwingReach.first_contact at the current distance and bearing, instead of startup+1 (ai_brain.gd 369). Parry, block, dodge and counter taps aim at that frame. | Moves that won't touch at the current distance are ignored, replacing the range+0.42+lunge+0.6 test. | TrainingBrain's parry feedback stays correct, because parry timing is measured from the first touch.
- check: Against a swing whose first touch is two frames after its first active frame, Hard parries inside the window at about the same rate as against a first-frame touch, measured over seeded runs. | The brain doesn't react to a move that can't reach it. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: retire-cones
- stories: 5, 41, 54
- files: game/sim/ai/ai_brain.gd, game/tests/sim/test_ai_brain.gd (new)
- notes: Once task 7 lands, hits land on the first touch, which can be later than startup+1. The brain's parry, block and counter taps then arrive early until this task. Keep the difficulty table's timing_error and reaction values unchanged here; the tuning rounds adjust them.

### [12] dummy-unblockables (S): The training dummy performs every unblockable
- delivers: A shared table of how to perform each unblockable (UnblockableRoutes):
- from a block-ability slot;
- Low Sweep as heavy then heavy;
- Skewer as dodge then heavy.
It replaces TrainingBrain.ability_for(), which only searches block abilities. | The thrust, sweep and slam behaviours rotate through every route of that counter kind the weapon has, and random includes them all. | With the Katana, the heavies behaviour alternates a vertical and a horizontal Iai.
- check: Tests:
- a Greatsword dummy on sweep telegraphs both Reaping Sweep and Low Sweep;
- on thrust it telegraphs Skewer;
- a Katana dummy on heavies releases both Iai variants. | npm test and npm run typecheck pass.
- depends: retire-cones, 10
- stories: 53
- files: game/sim/ai/unblockable_routes.gd (new), game/sim/ai/training_brain.gd, game/tests/sim/test_training_brain.gd (new)
- notes: Whether the dummy should also dodge-cancel is an open question.

### [12] counterlab-every-unblockable (S): Counterlab covers every unblockable
- delivers: counterlab runs every route of every weapon: Piercing Thrust, Swallow Sweep, Reaping Sweep, Mountain Slam, Low Sweep, Skewer, Serpent Sweep, Needle Thrust. | For each it prints attempts, counters by kind, hits and whiffs. | It exits 1 when any move's counter is never reached.
- check: A GUT test runs a short counterlab and asserts each unblockable is countered at least once. | The full run's table goes in the commit. | npm test and npm run typecheck pass.
- depends: dummy-unblockables, counters-from-paths
- stories: 41, 62
- files: game/tools/counterlab.gd, game/tests/sim/test_counterlab.gd (new)
- notes: Plan task 12's check: the counterlab shows every counter reachable. Today it runs three hard-coded cases.

### [12] brain-iai (M): The computer uses and answers the Iai
- delivers: Attacking with the Katana, the brain:
- taps heavy for a quick vertical draw;
- or holds heavy to stay sheathed and walks into about 3.6 m, releasing with the stick left or right for the horizontal draw about half the time;
- sometimes takes the follow-ups (Rising Heaven, Returning Draw);
- dodges out of the stance when the opponent attacks it. | Against a sheathed opponent, the brain stays out of draw range or punishes, since the stance can't block, and parries the release.
- check: Seeded tests:
- from 3.2 m the brain lands an Iai;
- it releases both variants over a run;
- attacked while sheathed, it dodge-cancels;
- facing a held Iai, Hard parries the release at a set rate. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: brain-contact-timing, 9
- stories: 5, 26, 27, 28, 54
- files: game/sim/ai/ai_brain.gd (_pick_attack 539-591, _perceive 302-338), game/tests/sim/test_ai_brain.gd
- notes: Today the brain's charged-heavy branch holds heavy for 30-160 frames without moving (ai_brain.gd 580-584), and _perceive ignores a charging attack.

### [12] brain-new-unblockables (M): The computer uses and answers Low Sweep and Skewer
- delivers: Attacking, the brain uses the routes against a turtling opponent: Overhead Strike into Low Sweep, and dodge into Skewer. Today _pick_attack only knows unblockables in the ability slots (546-563). | Defending, it counters both. Their telegraph fires at start_attack, so _respond_to's counter branch applies once timing comes from the path.
- check: Seeded tests:
- against a blocking dummy, a Greatsword brain uses Low Sweep and Skewer;
- a brain with counter 1.0 jumps the Low Sweep and stomps the Skewer. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: dummy-unblockables, brain-contact-timing
- stories: 5, 32, 33, 41
- files: game/sim/ai/ai_brain.gd, game/tests/sim/test_ai_brain.gd
- notes: Reuses the UnblockableRoutes table from dummy-unblockables, so the brain and the dummy perform each unblockable the same way. The break_chance logic in _pick_attack (0.7 against a full meter, 0.45 against turtling) should pick among all routes, not only the ability slot.

### [12] brain-dodge-cancels (M): The computer dodge-cancels
- delivers: With the Daggers, the brain dodges out of a light from its first recovery frame when the light was blocked or whiffed. | With any weapon, it dodges out of a heavy's late recovery (task 8's heavy dodge-cancel) when blocked, whiffed or facing a punish. | How often depends on difficulty.
- check: Seeded tests:
- a blocked Daggers light is followed by a dodge on its first recovery frame;
- a blocked heavy is dodge-cancelled in the second half of its recovery. | Hard dodge-cancels more often than Easy. | A 40-match soak runs clean. | npm test and npm run typecheck pass.
- depends: brain-contact-timing, 8, 11
- stories: 5, 23, 36
- files: game/sim/ai/ai_brain.gd, game/tests/sim/test_ai_brain.gd
- notes: Today the brain never cancels its own attacks.

### [12] tune-pace-disarms (M): Tuning round 1: round length and disarms
- delivers: Tuning runs (300 matches) with adjustments to damage, posture, parry posture, lunges and AI parameters, until rounds last 35-60 s and disarms are 0.3-0.6 per round. | Each change carries its test update and spec numbers in the same commit, with the soak report in the commit message.
- check: The soak's targets block shows round length and disarms in range. | 40-match soak and counterlab both run clean. | npm test and npm run typecheck pass.
- depends: soak-targets, counterlab-every-unblockable, brain-iai, brain-new-unblockables, brain-dodge-cancels
- stories: 62
- files: game/sim/constants.gd, game/sim/moves/katana.gd, game/sim/moves/greatsword.gd, game/sim/moves/daggers.gd, game/sim/ai/ai_brain.gd (DIFFICULTY table), docs/specs/godot-rebuild.md
- notes: The larger 15 m arena from task 8 may lengthen rounds (spec risk).

### [12] tune-weapon-balance (M): Tuning round 2: weapon win rates
- delivers: Per-weapon adjustments until each weapon wins 45-55% of its non-mirror matches in a 300-match run, without leaving round 1's targets. | Spec numbers and tests updated in the same commits.
- check: The soak's targets block is all in range on the tuning run. | 40-match soak and counterlab both run clean. | npm test and npm run typecheck pass.
- depends: tune-pace-disarms
- stories: 62
- files: game/sim/moves/katana.gd, game/sim/moves/greatsword.gd, game/sim/moves/daggers.gd, game/sim/constants.gd, docs/specs/godot-rebuild.md
- notes: Prefer per-weapon move numbers (damage, posture, frame data, lunges) and WeaponDef numbers (parry window, block mitigation) over AI parameters, so balance holds for human players too. Spot-check the 40-match soak between changes, because a 300-match run is slow.

### [12] balance-signoff (S): Record the balance and close task 12
- delivers: The final soak report and counterlab table recorded in the spec's testing section. | The strings tables in the spec checked against the move data. | Task 12 ticked in the plan.
- check: A 40-match soak runs clean, and the 300-match run is within all targets. | counterlab shows every counter reachable. | npm test and npm run typecheck pass.
- depends: tune-weapon-balance
- stories: 62
- files: docs/specs/godot-rebuild.md, docs/plans/godot-rebuild.md
- notes: This is the plan's 'spec numbers are updated' step for task 12. Any move whose numbers drifted from the spec's string tables during tuning gets its row corrected here, and the Progress section records the final check counts.

## Open questions
- The 2.5 m reach rule for every weapon: the Daggers' blade is only 0.26 m and can't put 15-20 cm into a defender 2.5 m away with a 0.8 m lunge. Recommend a duelling distance per weapon, taken from the demo AI's spacing: Katana 2.5 m, Greatsword about 3.0 m, Daggers about 2.0 m, bare hands about 1.6 m. The rule then holds at each weapon's own distance.
- Where swings are stored. Recommend a per-weapon const data file (game/sim/moves/<weapon>_swings.gd) holding a shape name with parameters or explicit keys, expanded to per-tick samples at load. Swing editor (14b) then rewrites one generated file and leaves the hand-tuned frame data alone. A JSON file would also work, but Godot's JSON reader was already the reason for the 1e-6 golden tolerance.
- Where the reference body comes from. Recommend committed per-fighter numbers (game/sim/swings/reference_body.gd), measured from the Rogue and Hunter skeletons, plus a content test that re-measures them. The rules-side checks then need no assets, and task 14 repeats the checks on the real IK rig.
- How reach and arc are defined. Recommend:
- range is the furthest horizontal blade reach during active frames plus half-thickness, measured without the lunge, which keeps the demo's meaning and keeps the AI's range+lunge formula valid;
- arc is twice the largest bearing of the blade from facing during the active frames, so the counters' cones stay symmetric.
- Whether WeaponDef.reach (the AI's preferred distance, 2.1 / 2.75 / 1.6 / 1.2 m today) stays hand-tuned or is derived. Recommend deriving it from the light starter's swing so the AI's spacing tracks the real blade.
- How big the unblockables' sweep bonus is. Recommend a SimConst radius bonus of about 0.2 m, tuned in counters-from-paths and the tuning rounds. Task 18 draws the same number in the reach effect.
- Dagger grip in swings: task 13's Rogue idles with the daggers reversed along her forearms, which the 5 cm forearm check would fail. Recommend a forward grip for all Dagger swings, with any reverse-grip flourish left to task 15's presentation.
- What strikes in the bash moves (Shoulder Charge, Guard Crusher) and in kicks. Recommend a body track at the shoulder or hilt for bashes and foot tracks with a hip pivot for kicks, with wrist checks applied to hand tracks only.
- Zero-damage stances (Flash, Shadow Step) and the sheathed Iai. Recommend pose-only swings with no striking track, so 'a swing on every final move' holds and task 15 has a path to animate.
- Elbows at 150-160deg at contact: a hard check in task 7, or only in task 14? Recommend that task 7 hard-fails only a locked elbow (170deg or more) and has the shapes aim for 150-160deg, with the exact band enforced on the real rig in task 14.
- Plan order: the infrastructure tasks (v3-math up to duel-reach-test) change nothing until a move has a swing, so they could land before task 8 without breaking the goldens. Recommend keeping the plan's order (8, then 9-11, then 7) for the one-task-at-a-time flow, unless the owner wants it sooner.
- Soak sample size: a weapon appears in about 27 of 40 matches, so its win rate has about +-10% noise and the 45-55% target can't be judged from the 40-match run. Recommend 300-match tuning runs with mirrors left out of win rates, keeping the 40-match run as the clean check.
- What 'the dummy learns the dodge cancels' means. Recommend the dummy stays a practice target that doesn't dodge-cancel, except in its 'fight' (spar) behaviour, which is the brain. Its new skills are the unblockable routes and both Iai variants.
- The colossal recovery slide 'in the swing's direction' (task 8) can't follow a path before swings exist. Recommend greatsword-string-swings take the slide direction from each swing's follow-through, if task 8 used a stand-in direction.
- How the debug view is toggled. Recommend F3 in debug builds, plus a --swing-debug argument and the swing_debug shot scene. Nothing appears in exported builds.

## Risks
- The reach may still fall short. The spike's tip reached only 1.35 m from the root, so even with a 0.8 m lunge, elbows at 150-160deg and a long contact key, the Katana may sit about 0.1-0.2 m short at 2.5 m. The critique's fallback is to scale weapons up 10-15%, which changes task 13's assets and its 0.99 / 1.72 / 0.4 m length tests.
- First-touch timing moves hit frames later than startup+1. That shifts parry windows, old timing tests (test_combat's parry timing of 4 frames) and the AI's reactions until brain-contact-timing lands, so soak numbers will drift through task 7.
- Derived ranges are much shorter than the demo's cones (the Katana light's 2.2 m becomes about 1.5 m plus lunge, the Mountain Slam's 3.2 m about 1.8 m). The AI's spacing and the counters' margins have to be re-tuned, and counterlab may show counters that can't be reached until they are.
- About 75 swings are authored by numbers before the swing editor (14b) exists. They will look like stand-ins and are likely to be re-keyed in tasks 14, 14b and 15, so keep shapes parametric to limit churn.
- The reference body is an analytic stand-in for TwoBoneIK3D. Task 14's real-rig check may flag frames that task 7's check passed. Treat task 7 as the gate for the rules and task 14 as the gate for the art.
- The Rogue and the Hunter have different proportions but share every move, so swings must pass both reference bodies. The tighter body may constrain everyone.
- The Moves registry builds all weapons in static vars when the class loads. Expanding swings (shapes, sampler, reach) inside finalize_moves can hit a GDScript static-initialisation cycle if swing code ever references Moves; keep the swing code independent of it.
- Only the blade's motion is swept. A defender moving fast within one tick (a dodge's first tick is up to about 0.5-0.7 m) could pass through a still blade. Dodge i-frames cover this today, but online play or new moves may expose it.
- Tasks 9-11 aren't built. The authoring tasks assume the spec's move names and fields (charge_move, release_variant, lunge_along_dodge, side_start and side_end) and must follow what those tasks actually ship. test_moves' comparison with the TypeScript fixture must already be replaced by then.
- Task 13 must be merged before hurt-capsule-blades and swing-checks, whose content tests read its WeaponLook markers and skeletons.
- 300-match tuning soaks run headless at up to 12 game minutes per match, so each run may take a long time. Measure the first run and size the tuning loops to match.
