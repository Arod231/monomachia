class_name SimConst
extends RefCounted
## Port of v0.1-web-mvp:src/sim/constants.ts.
##
## Global tuning for the Monomachia simulation.
## All time values are in simulation frames (60 per second) unless noted.
##
## Port notes: frame counts and other counts are int; everything else (HP,
## posture points, distances, speeds, rates, multipliers, angles) is float, so
## that no division in the port truncates by accident. MOVE.x becomes MOVE_X and
## DISARMED_MULT.x becomes DISARMED_MULT_X.

const FPS: int = 60
const DT: float = 1.0 / 60.0

const HP_MAX: float = 100.0
const POSTURE_MAX: float = 100.0
const ULT_HP_THRESHOLD: float = 25.0 # % HP at or below which the ultimate unlocks
const ROUNDS_TO_WIN: int = 3

const ARENA_RADIUS: float = 15.0 # inner wall radius (m); the demo's was 11.5
## The Impaler's dash ends this far inside the wall (the demo's 10.8 m stop).
const IMPALER_WALL_MARGIN: float = 0.7
## A disarmed weapon sticks no nearer the wall than this (milestone-1 task
## 86): its flight is shortened to land on a ring this far inside it.
const STUCK_WEAPON_MARGIN: float = 0.8
## The first bodies' 0.42 m, grown with KE task 3's bodies (20% round the
## torso, as FighterBody's hurt capsule).
const FIGHTER_RADIUS: float = 0.5
const GRAVITY: float = 30.0 # m/s^2 (snappy, game-like)
const JUMP_CLEAR: float = 0.3 # feet height above which low attacks miss
## An unblockable's sweep is this much thicker than its blade on every side
## (added to half the strike segment's thickness), so it reaches this much
## further than the same swing without the flag. Presentation reads it for
## the reach shown on the warning mark.
const UNBLOCKABLE_SWEEP_BONUS: float = 0.1
## A bash's striking shoulder (authored-animation task 19; Swing's
## left_shoulder and right_shoulder tracks): in the shoulder's frame (origin
## at the shoulder joint, +Y out along the shoulder line, +X forward), from
## just inside the joint to the outside of the upper arm, 24 cm thick for the
## deltoid and the arm's bulk.
const SHOULDER_STRIKE_BASE: float = -0.04
const SHOULDER_STRIKE_TIP: float = 0.08
const SHOULDER_STRIKE_THICKNESS: float = 0.24
## A knee strike's knee and shin (authored-animation task 25, the Flying
## Knee; Swing's left_knee and right_knee tracks): in the shin's frame
## (origin at the knee joint, +Y down the shin toward the ankle, +X the
## shin's front), from the top of the kneecap to the upper third of the shin,
## 14 cm thick for the knee and the calf.
const KNEE_STRIKE_BASE: float = -0.05
const KNEE_STRIKE_TIP: float = 0.18
const KNEE_STRIKE_THICKNESS: float = 0.14

# --- Defence ---------------------------------------------------------------
const PARRY_POSTURE: float = 16.0 # "each parry does a consistent amount of posture damage"
## undefended hits hurt posture more than blocked ones
const HIT_POSTURE_MULT: float = 1.5
const PARRY_SPAM_WINDOW: int = 30 # presses closer together than this are "spam"
const PARRY_SPAM_PENALTY: int = 3 # frames removed from the window per spam press
const PARRY_MIN_WINDOW: int = 2
const GUARD_HALF_ANGLE: float = 100.0 # degrees: must roughly face the attacker to block/parry

const PARRY_RECOIL: int = 26 # attacker can't act
const PARRY_RECOIL_GUARD_AFTER: int = 14 # attacker may block/parry again after this
const PARRIER_RECOVERY: int = 7 # parrier is free after this

# --- Posture ---------------------------------------------------------------
const POSTURE_RECOVER_DELAY: int = 45 # frames without posture damage before draining
const POSTURE_RECOVER_STAND: float = 14.0 # points / second (full HP, standing, blocking)
const POSTURE_RECOVER_MOVE: float = 5.0 # points / second (full HP, moving, blocking)
const POSTURE_RECOVER_HP_FLOOR: float = 0.35 # multiplier at 0 HP
const DISARMED_POSTURE_RECOVER: float = 6.0 # passive drain while disarmed
const DISARMED_POSTURE_DELAY: int = 60
# the daze when a disarmed fighter's meter fills: ProtectedTimings (task 22)
const DISARMED_STAGGER_RESET: float = 50.0 # posture after the daze

# --- Counters --------------------------------------------------------------
const STOMP_POSTURE: float = 30.0
# Where a stomp lands, by the thruster's weapon: this far in front of the
# thruster, so the stomping foot comes down on the blade's tip as the blade
# is driven into the floor (the mikiri counter's pin). A thruster nearer than
# that (the dodge carried the defender into it) is jolted back to it over
# STOMP_PUSH_FRAMES while the stomp's hop lands.
const STOMP_PIN_DIST: Dictionary[StringName, float] = {&"katana": 2.2, &"daggers": 1.1, &"greatsword": 2.15}
const STOMP_PIN_DIST_DEFAULT: float = 1.55
const STOMP_PUSH_FRAMES: int = 8
const LEAP_POSTURE: float = 30.0
const LEAP_STUN: int = 42
const EVADE_POSTURE: float = 15.0
const EVADE_EXTRA_RECOVERY: int = 40
const COUNTER_LUNGE_WINDOW: int = 45
const REDIRECT_POSTURE: float = 35.0
# the stomp's, Flash's and the redirect's stuns are protected timings:
# ProtectedTimings (milestone-1 task 22); the leap's stays here

# --- Knockdown (authored-animation task 16) ---------------------------------
# A hit from an unblockable (not an ultimate), a heavy released at full charge,
# or one of KNOCKDOWN_MOVES knocks the defender down instead of into hitstun:
# a fall, a time on the ground and a stand-up, whose lengths and guard window
# (the stand-up's last frames, in which the fighter is no longer invulnerable
# and can block or parry, but not attack, dodge or move) are protected
# timings: ProtectedTimings (milestone-1 task 22), by the weapon of the move
# that knocked the fighter down (Fighter.knockdown_timings()).
## The Greatsword's slams, which knock down though they aren't all
## unblockable: Mountain Slam, Meteor Drop and Leaping Smash.
const KNOCKDOWN_MOVES: Array[StringName] = [&"g_slam", &"g_jh", &"g_sh"]

# --- Finisher (milestone-1 task 103) ----------------------------------------
## A disarm of a fighter at this share of HP_MAX or less (5 HP) opens the
## finisher prompt for the disarmer.
const FINISHER_HP_SHARE: float = 0.05
## The prompt: rules frames, played at this slow motion (P35: about 1 s).
const FINISHER_PROMPT_FRAMES: int = 18
const FINISHER_PROMPT_SLOWMO: float = 0.3
## The stand-in finisher, both weapons', until tasks 104 and 105 read each
## from its clip in the table (the owner's numbers, Oct 5): the finisher lines
## up FINISHER_GAP from the victim, face to face, over FINISHER_LINE_UP_FRAMES;
## it lasts FINISHER_FRAMES, the round ending at FINISHER_KILL_FRAME. Bare
## hands' finisher with no attack to turn aside (P52) starts at
## FINISHER_STRIKE_FRAME.
const FINISHER_LINE_UP_FRAMES: int = 6
const FINISHER_GAP: float = 1.2
const FINISHER_FRAMES: int = 80
const FINISHER_KILL_FRAME: int = 56
const FINISHER_STRIKE_FRAME: int = 32

# --- Disarm ----------------------------------------------------------------
# the disarmed fighter's stagger: ProtectedTimings (milestone-1 task 22)
# The disarmed weapon's flight (milestone-1 task 86, the owner's numbers of
# Oct 5): it follows the blade's motion at contact, unless the blade moves
# slower than DISARM_BLADE_MIN_SPEED across the ground; it flies
# DISARM_FLIGHT metres at DISARM_FLIGHT_SPEED, rising DISARM_FLIGHT_PEAK above
# the straight line, and sticks STUCK_WEAPON_LEAN from vertical.
const DISARM_BLADE_MIN_SPEED: float = 0.5 # m/s
const DISARM_FLIGHT: float = 3.5 # m
const DISARM_FLIGHT_SPEED: float = 6.4 # m/s across the ground: 3.5 m in 33 frames
const DISARM_FLIGHT_PEAK: float = 1.0 # m
const STUCK_WEAPON_LEAN: float = 25.0 * PI / 180.0
const PICKUP_RANGE: float = 1.25
const PICKUP_FRAMES: int = 24
const PICKUP_ATTACH_FRAME: int = 14
# The recall (the disarmed ultimate's choice): its frames, the frame the weapon
# returns to the hand (invulnerable up to it), and the power-up burst on that
# frame (authored-animation task 30b, the owner's design): an opponent within
# the recalled weapon's duelling distance is blasted this far away (twice a
# heavy's 1.0) and knocked down, with no damage or posture.
const RECALL_FRAMES: int = 26
const RECALL_BURST_FRAME: int = 16
const RECALL_BURST_KNOCKBACK: float = 2.0
const RECALL_BURST_KNOCK_FRAMES: int = 14
const RECALL_BURST_HITSTOP: int = 6

# --- Input -----------------------------------------------------------------
const INPUT_BUFFER: int = 8
const CHORD_FRAMES: int = 4 # light+heavy within this = ultimate
const DOUBLE_TAP_FRAMES: int = 16
const TAP_MAX_FRAMES: int = 14 # first press of a double-tap must be at most this long
const DIR_DEADZONE: float = 0.4

# --- Charged heavy ---------------------------------------------------------
const CHARGE_MAX: int = 150 # 2.5 s: auto-release as a power attack
const CHARGE_MIN: int = 18 # below this a released charge is a normal heavy

# --- Movement --------------------------------------------------------------
# MOVE = { ... }
const MOVE_RUN_FORWARD: float = 3.9
const MOVE_RUN_STRAFE: float = 3.5
const MOVE_RUN_BACK: float = 3.0
const MOVE_SPRINT: float = 7.2
const MOVE_BLOCK_SPEED_MULT: float = 0.6 # share of running speed while blocking; the demo's was 0.45
const MOVE_ACCEL: float = 38.0 # m/s^2 toward desired velocity
const MOVE_DECEL: float = 30.0
const MOVE_STEP_DIST: float = 0.55
const MOVE_STEP_FRAMES: int = 8
const MOVE_DODGE_DIST: float = 2.8
const MOVE_DODGE_FRAMES: int = 16
const MOVE_DODGE_I_FRAMES: int = 12
const MOVE_DODGE_RECOVERY: int = 9
## The roll's travel (authored-animation task 17): the share of its distance
## covered after each of its 16 frames, from 0 to 1, read from Roll01 [RM]'s
## root on HumanM by the import tool (tools/import_clips.gd prints it): about
## even speed with a soft stop. The backstep keeps ease_out_cubic.
const MOVE_ROLL_CURVE: Array[float] = [
	0.0, 0.0876, 0.1958, 0.2823, 0.3651, 0.4479, 0.5398, 0.6502, 0.748, 0.8015, 0.8413, 0.8697, 0.912, 0.9585, 0.9709, 0.9899, 1.0,
]
const MOVE_BACKSTEP_DIST: float = 2.1
const MOVE_BACKSTEP_FRAMES: int = 14
const MOVE_BACKSTEP_I_FRAMES: int = 10
const MOVE_BACKSTEP_RECOVERY: int = 9
const MOVE_JUMP_HEIGHT: float = 0.95
const MOVE_LAND_RECOVERY: int = 5
const MOVE_TURN_RATE: float = 14.0 # rad/s when free
const MOVE_FOLLOW_WINDOW: int = 12 # frames after a dodge/backstep that count for follow-up attacks
const MOVE_SPRINT_ATTACK_MIN_FRAMES: int = 8

## The share of its speed a fighter keeps as an attack starts; jump attacks and
## hop attacks keep it all. The demo's was 0.3.
const ATTACK_MOMENTUM_KEEP: float = 0.5
## Colossal weapons' grounded attacks (bashes aside) slide on this far along
## the facing as their recovery starts, easing out. The demo had none.
const COLOSSAL_SLIDE_DIST: float = 0.35
## The slide takes this many recovery frames.
const COLOSSAL_SLIDE_FRAMES: int = 10

# --- Greatsword shoulder carry (authored-animation task 15) ----------------
## An armed Greatsword goes onto the shoulder (Fighter.shouldered) after this
## many frames in a row of moving in the free state (walking, running,
## sprinting or stepping), and at every round start.
const GS_SHOULDER_MOVE_FRAMES: int = 20
## An attack started from the shoulder holds its frame 0 this many frames
## while the sword is heaved off: its startup and its dodge cancel come this
## much later, its active and recovery frames don't change.
const GS_SHOULDER_LIFT_FRAMES: int = 6

# DISARMED_MULT = { speed, dodge, jump }
const DISARMED_MULT_SPEED: float = 1.2
const DISARMED_MULT_DODGE: float = 1.5
const DISARMED_MULT_JUMP: float = 1.35

# --- Ultimates ------------------------------------------------------------
const ULT_CHOICE_FRAMES: int = 40
## The Lightning Tempest spins this many times before its finisher.
const TEMPEST_SPINS: int = 6
