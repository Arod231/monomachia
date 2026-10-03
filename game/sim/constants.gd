class_name SimConst
extends RefCounted
## Port of src/sim/constants.ts.
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
## Dropped weapons bounce off a ring this far inside the wall.
const WEAPON_BOUNCE_MARGIN: float = 0.8
const FIGHTER_RADIUS: float = 0.42
const GRAVITY: float = 30.0 # m/s^2 (snappy, game-like)
const JUMP_CLEAR: float = 0.3 # feet height above which low attacks miss
## An unblockable's sweep is this much thicker than its blade on every side
## (added to half the strike segment's thickness), so it reaches this much
## further than the same swing without the flag. Presentation reads it for
## the reach shown on the warning mark.
const UNBLOCKABLE_SWEEP_BONUS: float = 0.1

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
const DISARMED_STAGGER: int = 60 # dazed when a disarmed fighter's meter fills
const DISARMED_STAGGER_RESET: float = 50.0 # posture after the daze

# --- Counters --------------------------------------------------------------
const STOMP_POSTURE: float = 30.0
const STOMP_STUN: int = 70
const LEAP_POSTURE: float = 30.0
const LEAP_STUN: int = 42
const EVADE_POSTURE: float = 15.0
const EVADE_EXTRA_RECOVERY: int = 40
const COUNTER_LUNGE_WINDOW: int = 45
const REDIRECT_POSTURE: float = 35.0
const REDIRECT_STUN: int = 50
const FLASH_STUN: int = 60

# --- Disarm ----------------------------------------------------------------
const DISARM_STAGGER: int = 26 # the disarmed fighter reels back
const PICKUP_RANGE: float = 1.25
const PICKUP_FRAMES: int = 24
const PICKUP_ATTACH_FRAME: int = 14

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

# DISARMED_MULT = { speed, dodge, jump }
const DISARMED_MULT_SPEED: float = 1.2
const DISARMED_MULT_DODGE: float = 1.5
const DISARMED_MULT_JUMP: float = 1.35

# --- Ultimates ------------------------------------------------------------
const ULT_CHOICE_FRAMES: int = 40
