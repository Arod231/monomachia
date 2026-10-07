extends Node3D
## Contact sheets of a move, for reviewing animation: one move played on a
## real fighter against a defender at the duelling distance
## (PoseCheck.SPACING), on the rules' clock through MoveBench, with the
## chosen frames captured from each view. Each row is one frame, captioned
## with its frame, phase and PoseCheck numbers and what fails; the header
## names the move and gives MoveBench's summary of the whole move.
##
##   npm run shots -- res://tools/shot_scenes/move_sheet.tscn <out.png> 1 [--option=value...]
##
## Options:
## - --fighter=rogue|hunter: the attacker, in palette A (default rogue);
## - --weapon=katana|greatsword|daggers|fists: its weapon (default katana;
##   fists for bare hands' moves, task 24);
## - --move=<move id>, guard (the default: the fighter standing in its guard,
##   one row) or all: the batch, a sheet for the guard and for every move of
##   the weapon, each saved beside <out.png> as <out>_<move>.png, and
##   <out.png> itself an index of them all at their first active frame from
##   the first view, so a re-key can rerun the whole set;
## - --at=: the frames to show, comma-separated: frame numbers (1 is the
##   move's first frame), the landmarks start, windup (mid startup), cocked
##   (the last startup frame), contact (the first active frame), release (the
##   last active frame), follow (mid recovery) and end (the last frame the
##   move shows), keys (every landmark, the default) or all;
## - --views=: which views (VIEW_NAMES), comma-separated, in order (default
##   VIEWS for a move, the drive's own for a drive);
## - --defender=rogue|hunter: the defender, in palette B (default: the same
##   fighter as the attacker);
## - --defender-weapon=<weapon id>: the defender's weapon (default the Katana;
##   task 27's parry sheets pair every weapon);
## - --spacing=: metres between the fighters (default PoseCheck.SPACING, or
##   the drive's own for a drive);
## - --face=: a drive's fighter turned that many degrees from facing the
##   opponent (+ to its left) and held there, so a hit lands on its side or
##   its back (milestone-1 task 35); with --move, the opponent's light in a
##   drive is that move;
## - --swings=<res:// path>: a swing file (SwingFile) put on a fresh copy of
##   the weapon, so its moves play from those swings (SwingPlayer) rather
##   than the weapon's own; tools/swings/katana_demo.json holds stand-in
##   swings for the Katana's four lights, for reviewing swing playback
##   before the real keys (plan task 7.17). They are not the real keys: they
##   fail the swing check's wrist limits and run past the arms' reach in
##   places (scripts/swings/katana-demo.mjs writes them).
##
## Strips: --drive=<name> plays one of DRIVES instead of a move, scripted
## input from rest (rest_to_sprint: still, then running at the opponent, then
## sprinting; run_brake and sprint_brake: running or sprinting at it, then
## letting go; strafe_left and strafe_right round the opponent, backpedal and
## back_left away from it, each then stopping; the guard_ drives the same
## while blocking; tap_steps: a tap step each way;
## iai_walk: walking in the Iai stance; carry_walk, carry_lift and
## carry_guard: the Greatsword going onto the shoulder as it walks, then
## standing and strafing, attacking from it, or raising the guard off it
## (task 18); grip_switch: the Katana switched to two hands standing and back
## guarding (KE task 8); string_l to string_llll: the Katana's
## light string stopped after one, two, three and four lights, each press
## made after the move before has passed its startup, so it follows it), with
## the opponent out of the way (but for stomp: the opponent thrusts its
## unblockable and the fighter dodges into it, the stomp counter; and the
## reactions, task 26: hit_reactions and block_reactions, the opponent
## striking the fighter standing or guarding with a light then a heavy, and
## stun_reaction, the fighter's light into the opponent's Flash; and parry,
## task 27: the fighter's light parried by the opponent's block, pressed 3
## frames before it lands, at the fighter's duelling distance; knockdown,
## task 28: the opponent's Greatsword slams the fighter down with Mountain
## Slam; ko_light and ko_heavy: the fighter on 1 HP, knocked out by the
## opponent's Right Cut or heavy. A drive may name the opponent's weapon,
## "defender_weapon", and the fighter's HP, "hp"),
## and lays out a strip of the chosen frames: the first, every --every=th
## (default the drive's own, else 4) and the last, each captioned with the
## speed, the way the legs travel, Locomotion's blend and the step phase,
## the turn on the spot and the feet the foot lock holds, a block of rows per view.
##
## The defender holds the Katana and takes no input, so a move that reaches it
## lands as the rules say. The stage is the preview's studio, and the chosen
## graphics preset applies. Nothing moves between the captures of a frame, so
## two runs give the same images.

## The views of a move's sheet, in their default order: the match camera
## (CameraRig's FOLLOW) over the defender's shoulder, what the player being
## attacked sees, and over the attacker's; the attacker's whole body from
## three-quarters in front, on its weapon side; its head, chest and hands
## closer; and its hands on the grip.
const VIEWS: Array[StringName] = [&"defender", &"attacker", &"three_quarter", &"close", &"hands"]
## Besides these, for the drives and the guard: the whole fighter side on
## from its right, from in front, a little to its right, from
## three-quarters in front on its left, and its feet from in front on its
## left, square to the line between them, so neither hides the other.
const VIEW_NAMES: Dictionary[StringName, String] = {
	&"defender": "gameplay camera behind the defender",
	&"attacker": "gameplay camera behind the attacker",
	&"three_quarter": "three-quarter",
	&"three_quarter_left": "three-quarter from the left",
	&"close": "close",
	&"hands": "hands",
	&"side": "side",
	&"front": "front",
	&"feet": "feet",
}
## The held buttons the guard drives and the Iai walk use, and the light the
## string drives press.
const BLOCK: int = 1 << Btn.BLOCK
const HEAVY: int = 1 << Btn.HEAVY
const LIGHT: int = 1 << Btn.LIGHT
## Scripted input from rest, by name:
## - input: segments of [frames, strafe axis (+ to the right), forward axis,
##   held buttons];
## - notes: what it does, for the header;
## - views: the strip's views when --views= doesn't say;
## - spacing: how far off the opponent stands (m): out of the way, and for a
##   strafe near enough (under 9 m) that the rules keep the distance, so the
##   fighter circles it;
## - every (optional): every how many frames the strip shows one, when
##   --every= doesn't say;
## - defender (optional): the opponent's input, segments as for input
##   (otherwise it takes none).
const DRIVES: Dictionary[StringName, Dictionary] = {
	&"rest_to_sprint": {
		"input": [[12, 0.0, 0.0, 0], [60, 0.0, 1.0, 0], [60, 0.0, 1.0, 1 << Btn.SPRINT]],
		"notes": "still for 12 frames, running at the opponent for 60, then sprinting for 60",
		"views": [&"side"],
		"spacing": 26.0,
	},
	&"run_brake": {
		"input": [[12, 0.0, 0.0, 0], [48, 0.0, 1.0, 0], [36, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, running at the opponent for 48, then letting go of the stick for 36",
		"views": [&"side"],
		"spacing": 26.0,
	},
	&"sprint_brake": {
		"input": [[12, 0.0, 0.0, 0], [24, 0.0, 1.0, 0], [36, 0.0, 1.0, 1 << Btn.SPRINT], [36, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, running for 24, sprinting for 36, then letting go for 36",
		"views": [&"side"],
		"spacing": 26.0,
	},
	&"strafe_left": {
		"input": [[12, 0.0, 0.0, 0], [72, -1.0, 0.0, 0], [24, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, strafing left round the opponent for 72, then stopping",
		"views": [&"front"],
		"spacing": 8.0,
	},
	&"strafe_right": {
		"input": [[12, 0.0, 0.0, 0], [72, 1.0, 0.0, 0], [24, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, strafing right round the opponent for 72, then stopping",
		"views": [&"front"],
		"spacing": 8.0,
	},
	&"backpedal": {
		"input": [[12, 0.0, 0.0, 0], [72, 0.0, -1.0, 0], [24, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, backing away from the opponent for 72, then stopping",
		"views": [&"side"],
		"spacing": 8.0,
	},
	&"back_left": {
		"input": [[12, 0.0, 0.0, 0], [72, -0.7071, -0.7071, 0], [24, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, moving back and to the left for 72, then stopping",
		"views": [&"front"],
		"spacing": 8.0,
	},
	&"sprint_away": {
		"input": [[12, 0.0, 0.0, 0], [50, 0.0, -1.0, 1 << Btn.SPRINT], [30, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, sprinting straight back from the opponent for 50 (the body turns away), then stopping (and turning back)",
		"views": [&"side"],
		"spacing": 8.0,
	},
	&"turn_on_spot": {
		"input": [[150, 0.0, 0.0, 0]],
		"defender": [[10, 0.0, 0.0, 0], [100, 1.0, 0.0, 0], [40, 0.0, 0.0, 0]],
		"notes": "standing still while the opponent strafes round it for 100 frames: the legs step round each 30° the facing turns",
		"views": [&"front", &"feet"],
		"spacing": 3.0,
		"every": 4,
	},
	&"rolls": {
		"input": [[12, 0.0, 0.0, 0], [1, 1.0, 0.0, 1 << Btn.DODGE], [30, 0.0, 0.0, 0], [1, -1.0, 0.0, 1 << Btn.DODGE], [30, 0.0, 0.0, 0],
			[1, 0.0, 1.0, 1 << Btn.DODGE], [30, 0.0, 0.0, 0], [1, 0.0, -1.0, 1 << Btn.DODGE], [30, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then a roll right, left, forward and back, each let go for 30 (task 30: Roll01, the body turned toward the roll)",
		"views": [&"front"],
		"spacing": 8.0,
		"every": 3,
	},
	&"backstep": {
		"input": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, 1 << Btn.DODGE], [30, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then a backstep (dodge with the stick let go: Dodge01's lean back), let go for 30",
		"views": [&"side"],
		"spacing": 8.0,
		"every": 2,
	},
	&"jump": {
		"input": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, 1 << Btn.JUMP], [50, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then a jump on the spot: the weapon class's keyed flight and landing (milestone-1 task 59; the pack's Jump01 take-off, air and landing for the Greatsword and Daggers)",
		"views": [&"side"],
		"spacing": 8.0,
		"every": 3,
	},
	&"dodge_attack": {
		"input": [[12, 0.0, 0.0, 0], [1, 1.0, 0.0, 1 << Btn.DODGE], [13, 0.0, 0.0, 0], [1, 0.0, 0.0, 1 << Btn.LIGHT], [44, 0.0, 0.0, 0]],
		"notes": "a roll right, then the dodge light out of it: the body turns back to the opponent over the attack's first 3 frames",
		"views": [&"front"],
		"spacing": 3.0,
		"every": 2,
	},
	&"stand": {
		"input": [[330, 0.0, 0.0, 0]],
		"notes": "standing still for 330 frames",
		"views": [&"front", &"side"],
		"spacing": PoseCheck.SPACING,
	},
	&"guard_forward": {
		"input": [[12, 0.0, 0.0, BLOCK], [48, 0.0, 1.0, BLOCK], [24, 0.0, 0.0, BLOCK]],
		"notes": "blocking: still for 12 frames, walking at the opponent for 48, then stopping",
		"views": [&"side", &"feet"],
		"spacing": 8.0,
		"every": 2,
	},
	&"guard_backpedal": {
		"input": [[12, 0.0, 0.0, BLOCK], [48, 0.0, -1.0, BLOCK], [24, 0.0, 0.0, BLOCK]],
		"notes": "blocking: still for 12 frames, walking back from the opponent for 48, then stopping",
		"views": [&"side", &"feet"],
		"spacing": 8.0,
		"every": 2,
	},
	&"guard_strafe_left": {
		"input": [[12, 0.0, 0.0, BLOCK], [48, -1.0, 0.0, BLOCK], [24, 0.0, 0.0, BLOCK]],
		"notes": "blocking: still for 12 frames, walking left round the opponent for 48, then stopping",
		"views": [&"front", &"feet"],
		"spacing": 8.0,
		"every": 2,
	},
	&"guard_strafe_right": {
		"input": [[12, 0.0, 0.0, BLOCK], [48, 1.0, 0.0, BLOCK], [24, 0.0, 0.0, BLOCK]],
		"notes": "blocking: still for 12 frames, walking right round the opponent for 48, then stopping",
		"views": [&"front", &"feet"],
		"spacing": 8.0,
		"every": 2,
	},
	&"guard_back_left": {
		"input": [[12, 0.0, 0.0, BLOCK], [48, -0.7071, -0.7071, BLOCK], [24, 0.0, 0.0, BLOCK]],
		"notes": "blocking: still for 12 frames, walking back and to the left for 48, then stopping",
		"views": [&"front", &"feet"],
		"spacing": 8.0,
		"every": 2,
	},
	&"tap_steps": {
		"input": [[12, 0.0, 0.0, 0], [8, 0.0, 1.0, 0], [24, 0.0, 0.0, 0], [8, 1.0, 0.0, 0], [24, 0.0, 0.0, 0],
			[8, 0.0, -1.0, 0], [24, 0.0, 0.0, 0], [8, -1.0, 0.0, 0], [24, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then a tap step forward, right, back and left, each held 8 frames and let go for 24",
		"views": [&"front", &"feet"],
		"spacing": 8.0,
		"every": 2,
	},
	&"iai_walk": {
		"input": [[12, 0.0, 0.0, HEAVY], [48, 0.0, 1.0, HEAVY], [36, -1.0, 0.0, HEAVY], [24, 0.0, 0.0, HEAVY]],
		"notes": "holding heavy: sheathing into the Iai stance, walking at the opponent for 48 frames, left round it for 36, then stopping",
		"views": [&"side", &"feet"],
		"spacing": 8.0,
		"every": 3,
	},
	&"carry_walk": {
		"input": [[12, 0.0, 0.0, 0], [48, 0.0, 1.0, 0], [24, 0.0, 0.0, 0], [36, 1.0, 0.0, 0]],
		"notes": "still for 12 frames, walking at the opponent for 48 (onto the shoulder after 20), standing for 24, then strafing right for 36",
		"views": [&"side", &"three_quarter"],
		"spacing": 8.0,
		"every": 4,
	},
	&"carry_lift": {
		"input": [[12, 0.0, 0.0, 0], [36, 0.0, 1.0, 0], [1, 0.0, 0.0, LIGHT], [60, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, walking at the opponent for 36 (onto the shoulder), then Heavy Swing from the shoulder, its 6-frame lift first",
		"views": [&"side", &"three_quarter"],
		"spacing": 4.0,
		"every": 2,
	},
	&"carry_guard": {
		"input": [[12, 0.0, 0.0, 0], [36, 0.0, 1.0, 0], [30, 0.0, 0.0, BLOCK], [24, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, walking at the opponent for 36 (onto the shoulder), then blocking for 30 (the guard lifted off the shoulder), then letting go",
		"views": [&"side", &"three_quarter"],
		"spacing": 8.0,
		"every": 2,
	},
	&"grip_switch": {
		"input": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, 1 << Btn.GRIP], [30, 0.0, 0.0, 0], [12, 0.0, 0.0, BLOCK],
			[1, 0.0, 0.0, BLOCK | (1 << Btn.GRIP)], [30, 0.0, 0.0, BLOCK], [12, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, switching to the two-handed grip, standing for 30, then guarding and switching back to one hand, guarding for 30 (KE task 8: both grips stand in on the guard idle and guard until task 10)",
		"views": [&"three_quarter", &"hands"],
		"spacing": 4.0,
		"every": 4,
	},
	&"string_l": {
		"input": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [70, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then Right Cut alone, recovering to the guard",
		"views": [&"three_quarter", &"hands"],
		"spacing": 4.0,
		"every": 2,
	},
	&"string_ll": {
		"input": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [29, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [80, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then Right Cut into Return Cut, recovering to the guard",
		"views": [&"three_quarter", &"hands"],
		"spacing": 4.0,
		"every": 2,
	},
	&"string_lll": {
		"input": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [29, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [30, 0.0, 0.0, 0],
			[1, 0.0, 0.0, LIGHT], [80, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then Right Cut, Return Cut and Kesa Cut, recovering to the guard",
		"views": [&"three_quarter", &"hands"],
		"spacing": 4.0,
		"every": 2,
	},
	&"string_llll": {
		"input": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [29, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [30, 0.0, 0.0, 0],
			[1, 0.0, 0.0, LIGHT], [30, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [90, 0.0, 0.0, 0]],
		"notes": "still for 12 frames, then the whole L-L-L-L: Right Cut, Return Cut, Kesa Cut and Crown Cut, recovering to the guard",
		"views": [&"three_quarter", &"hands"],
		"spacing": 4.0,
		"every": 2,
	},
	&"stomp": {
		"input": [[32, 0.0, 0.0, 0], [1, 0.0, 1.0, 1 << Btn.DODGE], [52, 0.0, 0.0, 0]],
		"defender": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, BLOCK | HEAVY], [72, 0.0, 0.0, 0]],
		"notes": "the opponent thrusts its unblockable after 12 frames; 20 frames later the fighter dodges into it and stomps it (the keyed Mikiri_Stomp)",
		"views": [&"side", &"three_quarter"],
		"spacing": 2.2,
		"every": 2,
	},
	&"hit_reactions": {
		"input": [[128, 0.0, 0.0, 0]],
		"defender": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [44, 0.0, 0.0, 0], [1, 0.0, 0.0, HEAVY], [70, 0.0, 0.0, 0]],
		"notes": "the fighter stands; the opponent hits it with Right Cut after 12 frames (a light's hitstun), then 45 frames later with a heavy (a heavy's)",
		"views": [&"defender", &"three_quarter"],
		"spacing": 2.5,
		"every": 4,
	},
	&"block_reactions": {
		"input": [[128, 0.0, 0.0, BLOCK]],
		"defender": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [44, 0.0, 0.0, 0], [1, 0.0, 0.0, HEAVY], [70, 0.0, 0.0, 0]],
		"notes": "the fighter holds its guard; the opponent strikes it with Right Cut after 12 frames, then 45 frames later with a heavy (blockstun each time)",
		"views": [&"defender", &"three_quarter"],
		"spacing": 2.5,
		"every": 4,
	},
	&"stun_reaction": {
		"input": [[14, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [95, 0.0, 0.0, 0]],
		"defender": [[20, 0.0, 0.0, 0], [1, 0.0, 0.0, BLOCK | LIGHT], [89, 0.0, 0.0, 0]],
		"notes": "the fighter cuts Right Cut after 14 frames into the opponent's Flash, which stuns it for 60 frames (Stun01)",
		"views": [&"defender", &"three_quarter"],
		"spacing": 2.5,
		"every": 4,
	},
	&"parry": {
		"input": [[14, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [55, 0.0, 0.0, 0]],
		"parry": 14,
		"notes": "the fighter's first light (or --move's) after 14 frames, parried by the opponent's block pressed 3 frames before it lands: with the packs the deflect pair (milestone-1 task 34), the parrier's deflect and the attacker's recoil from the contact frame; without them the parrier's Parry Hit and the attacker's Stun01",
		"views": [&"three_quarter", &"side"],
		"spacing": 0.0,
		"every": 2,
	},
	&"knockdown": {
		"input": [[150, 0.0, 0.0, 0]],
		"defender": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, BLOCK | HEAVY], [137, 0.0, 0.0, 0]],
		"defender_weapon": &"greatsword",
		"notes": "the opponent's Greatsword slams the fighter down with Mountain Slam after 12 frames: Knockdown01's fall, ground and stand-up",
		"views": [&"defender", &"side"],
		"spacing": 3.5,
		"every": 4,
	},
	&"ko_light": {
		"input": [[90, 0.0, 0.0, 0]],
		"defender": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, LIGHT], [77, 0.0, 0.0, 0]],
		"hp": 1.0,
		"notes": "the fighter on 1 HP; the opponent's Right Cut knocks it out from the front after 12 frames (a light: CombatDeath01)",
		"views": [&"defender", &"side"],
		"spacing": 2.5,
		"every": 3,
	},
	&"ko_heavy": {
		"input": [[100, 0.0, 0.0, 0]],
		"defender": [[12, 0.0, 0.0, 0], [1, 0.0, 0.0, HEAVY], [87, 0.0, 0.0, 0]],
		"hp": 1.0,
		"notes": "the fighter on 1 HP; the opponent's heavy knocks it out from the front after 12 frames (CombatDeath02)",
		"views": [&"defender", &"side"],
		"spacing": 2.5,
		"every": 3,
	},
}
## How many frames before a parried light lands the parry drive presses the
## block (inside every weapon's window, 6 frames at the least).
const PARRY_LEAD: int = 3
## Cells per row of a drive's strip.
const STRIP_COLUMNS: int = 8
## A view's crop of the screen, its width over its height: the gameplay views
## keep the whole screen, the others a centred square.
const ASPECTS: Dictionary[StringName, float] = {&"defender": 16.0 / 9.0, &"attacker": 16.0 / 9.0}
## The --move= values that aren't a move.
const GUARD: StringName = &"guard"
const BATCH: StringName = &"all"
## The landmarks --at= can name, in order (see landmark()).
const LANDMARKS: Array[String] = ["start", "windup", "cocked", "contact", "release", "follow", "end"]
## Pixel sizes in the sheet: a cell's height, a row's caption, the header,
## and the gap between rows and cells.
const CELL_HEIGHT: int = 360
const CAPTION_HEIGHT: int = 64
## A strip cell's caption, a line taller for the feet.
const STRIP_CAPTION_HEIGHT: int = 88
const HEADER_HEIGHT: int = 156
const GAP: int = 6
const CAPTION_FONT: int = 19
const HEADER_FONT: int = 22
const TEXT_MARGIN: int = 8
## Cells per row of the batch's index.
const INDEX_COLUMNS: int = 4
const BACKGROUND: Color = Color8(24, 25, 28)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.87)
const PASS_COLOR: Color = Color(0.55, 0.9, 0.55)
const FAIL_COLOR: Color = Color(1.0, 0.52, 0.45)

const PreviewScene := preload("res://fighters/preview/preview.gd")


## One row of a sheet: a frame of the move (or the guard).
class Row:
	## The caption: the frame, phase and PoseCheck numbers, then the verdict.
	var lines: PackedStringArray = []
	var report: PoseCheck.Report
	## The move's first active frame.
	var contact: bool = false
	## The caption drawn, or null for none.
	var caption: Image
	## A picture per view.
	var cells: Array[Image] = []


## False to drive the sheet by hand (the tests): the command line is not
## read and nothing runs by itself.
var auto_run: bool = true
var fighter_id: StringName = &"rogue"
## A WeaponDef id.
var weapon_id: StringName = &"katana"
## A move id, GUARD or BATCH.
var move: StringName = GUARD
var at: String = "keys"
var views: Array[StringName] = VIEWS
## Empty for the same fighter as the attacker.
var defender_id: StringName = &""
var defender_weapon_id: StringName = &"katana"
var _defender_weapon_given: bool = false
var spacing: float = PoseCheck.SPACING
## Where shot.gd saves the sheet (its --out=): the batch's sheets go beside it.
var out_path: String = ""
## One of DRIVES to play instead of a move, or empty; and every how many
## frames its strip shows one.
var drive: StringName = &""
var every: int = 4
## A swing file for a fresh copy of the weapon (--swings=), or empty.
var swings_path: String = ""

var bench: MoveBench
var defender_view: FighterView
## A drive's fighter turned this many degrees from facing the opponent (+
## to its left) and held there (--face=; milestone-1 task 35's hit reactions
## from the side and behind).
var face: float = 0.0
var camera: CameraRig
## The last sheet's header lines and rows.
var title: PackedStringArray = []
var rows: Array[Row] = []
## The last strip's captions, a pair of lines per chosen frame.
var strip: Array[PackedStringArray] = []

var _views_given: bool = false
var _every_given: bool = false
var _spacing_given: bool = false
var _overlay: CanvasLayer
var _sheet: Image
var _done: bool = false


func _ready() -> void:
	if auto_run:
		apply_args(OS.get_cmdline_user_args())
	PreviewScene.build_studio_stage(self)
	camera = CameraRig.new()
	camera.name = &"Camera"
	add_child(camera)
	camera.make_current()
	_overlay = CanvasLayer.new()
	_overlay.name = &"Captions"
	_overlay.layer = 100
	_overlay.visible = false
	add_child(_overlay)
	var weapon: WeaponDef = Moves.WEAPONS[weapon_id] if swings_path == "" else with_swings(weapon_id, swings_path)
	bench = MoveBench.new(self, fighter_id, weapon, spacing, Moves.WEAPONS[defender_weapon_id])
	defender_view = FighterView.new()
	defender_view.name = &"Defender"
	add_child(defender_view)
	defender_view.setup(defender_id if defender_id != &"" else fighter_id, 1, defender_weapon_id, 1)
	defender_view.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_show_defender()
	if auto_run:
		GraphicsApplier.apply(GameServices.graphics_preset(), self, get_viewport())
		_run.call_deferred()


func _exit_tree() -> void:
	if bench != null:
		bench.dispose()


## For tools/shot.gd: frames to wait before asking shot_ready().
func shot_frames() -> int:
	return 1


## For tools/shot.gd: true once the sheet is made.
func shot_ready() -> bool:
	return _done


## For tools/shot.gd: the sheet (or the batch's index) to save.
func shot_image() -> Image:
	return _sheet


## Reads --fighter=, --weapon=, --move=, --at=, --views=, --defender=, --defender-weapon=,
## --spacing=, --swings= and shot.gd's --out=. An unknown fighter, weapon or view, or a
## spacing that isn't a positive number, is an error, so the shot run fails.
func apply_args(args: PackedStringArray) -> void:
	for a: String in args:
		if not a.begins_with("--") or not a.contains("="):
			continue
		var key: String = a.substr(2, a.find("=") - 2)
		var value: String = a.substr(a.find("=") + 1)
		match key:
			"fighter":
				fighter_id = StringName(value)
			"weapon":
				weapon_id = StringName(value)
			"move":
				move = StringName(value)
			"at":
				at = value
			"views":
				views = _parse_views(value)
				_views_given = true
			"defender":
				defender_id = StringName(value)
			"defender-weapon":
				if Moves.WEAPONS.has(StringName(value)):
					defender_weapon_id = StringName(value)
					_defender_weapon_given = true
				else:
					push_error("move_sheet.gd: no weapon '%s' for the defender" % value)
			"spacing":
				if value.is_valid_float() and float(value) > 0.0:
					spacing = float(value)
					_spacing_given = true
				else:
					push_error("move_sheet.gd: --spacing= takes metres, not '%s'" % value)
			"out":
				out_path = value
			"swings":
				swings_path = value
			"drive":
				drive = StringName(value)
				if not DRIVES.has(drive):
					push_error("move_sheet.gd: no drive '%s' (%s)" % [value, ", ".join(PackedStringArray(DRIVES.keys()))])
					drive = &""
			"face":
				if value.is_valid_float():
					face = float(value)
				else:
					push_error("move_sheet.gd: --face= takes degrees, not '%s'" % value)
			"every":
				if value.is_valid_int() and int(value) >= 1:
					every = int(value)
					_every_given = true
				else:
					push_error("move_sheet.gd: --every= takes a whole number of frames, not '%s'" % value)
	if drive != &"" and not _views_given:
		var own: Array[StringName] = []
		own.assign(DRIVES[drive]["views"])
		views = own
	if drive != &"" and not _every_given:
		every = int(DRIVES[drive].get("every", every))
	if drive != &"" and not _defender_weapon_given and DRIVES[drive].has("defender_weapon"):
		defender_weapon_id = DRIVES[drive]["defender_weapon"]
	for id: StringName in [fighter_id, defender_id]:
		if id != &"" and not FighterLook.IDS.has(id):
			push_error("move_sheet.gd: no fighter '%s' (%s)" % [id, ", ".join(PackedStringArray(FighterLook.IDS))])
	if not FighterLook.IDS.has(fighter_id):
		fighter_id = FighterLook.IDS[0]
	if defender_id != &"" and not FighterLook.IDS.has(defender_id):
		defender_id = &""
	if not Moves.WEAPONS.has(weapon_id):
		push_error("move_sheet.gd: no weapon '%s' (%s)" % [weapon_id, ", ".join(PackedStringArray(Moves.WEAPONS.keys()))])
		weapon_id = Moves.PLAYABLE_WEAPONS[0]


## A fresh copy of weapon `id` (a playable WeaponDef id) with the swings of
## the file at `path` on its moves; reported when the file gives none.
static func with_swings(id: StringName, path: String) -> WeaponDef:
	var w: WeaponDef
	match id:
		&"greatsword":
			w = GreatswordMoves.build()
		&"daggers":
			w = DaggersMoves.build()
		_:
			w = KatanaMoves.build()
	SwingFile.attach(path, w.moves)
	if not w.moves.values().any(func(m: AttackDef) -> bool: return m.swing != null):
		push_error("move_sheet.gd: no swings for the %s in '%s'" % [id, path])
	return w


static func _parse_views(text: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for part: String in text.split(",", false):
		var view: StringName = StringName(part.strip_edges())
		if VIEW_NAMES.has(view):
			out.append(view)
		else:
			push_error("move_sheet.gd: no view '%s' (%s)" % [view, ", ".join(PackedStringArray(VIEW_NAMES.keys()))])
	return out if not out.is_empty() else VIEWS


# --- frames ------------------------------------------------------------------

## The last frame a move shows: the rules end it on the frame after.
static func last_frame(def: AttackDef) -> int:
	return def.startup + def.active + def.recovery - 1


## A landmark's frame (see LANDMARKS), within the frames the move shows.
static func landmark(landmark_name: String, def: AttackDef) -> int:
	var f: int = 1
	match landmark_name:
		"windup":
			f = ceili(def.startup / 2.0)
		"cocked":
			f = def.startup
		"contact":
			f = def.startup + 1
		"release":
			f = def.startup + def.active
		"follow":
			f = def.startup + def.active + ceili(def.recovery / 2.0)
		"end":
			f = last_frame(def)
	return clampi(f, 1, last_frame(def))


## Every landmark's frame, in order, each once.
static func key_frames(def: AttackDef) -> Array[int]:
	var out: Array[int] = []
	for landmark_name: String in LANDMARKS:
		var f: int = landmark(landmark_name, def)
		if not out.has(f):
			out.append(f)
	out.sort()
	return out


## The frames --at= chooses (see the top), in order, each once; frames the
## move doesn't show are dropped.
static func frames_for(text: String, def: AttackDef) -> Array[int]:
	var last: int = last_frame(def)
	var out: Array[int] = []
	for part: String in text.split(",", false):
		var p: String = part.strip_edges()
		var chosen: Array[int] = []
		if p == "keys":
			chosen = key_frames(def)
		elif p == "all":
			for f: int in range(1, last + 1):
				chosen.append(f)
		elif p.is_valid_int():
			chosen.append(int(p))
		elif LANDMARKS.has(p):
			chosen.append(landmark(p, def))
		else:
			push_error("move_sheet.gd: --at= takes frame numbers, %s, keys or all, not '%s'" % [", ".join(LANDMARKS), p])
		for f: int in chosen:
			if f >= 1 and f <= last and not out.has(f):
				out.append(f)
	out.sort()
	return out


# --- cameras -----------------------------------------------------------------

## Points the camera for a view, at the fighters as they stand now.
func aim(view: StringName) -> void:
	var a: Vector3 = _feet(bench.attacker)
	var d: Vector3 = _feet(bench.defender)
	var forward: Vector3 = Vector3(sin(bench.attacker.yaw), 0.0, cos(bench.attacker.yaw))
	match view:
		&"defender":
			camera.snap(d, a)
		&"attacker":
			camera.snap(a, d)
		&"three_quarter":
			# From the front on the weapon (right) side, the whole body and
			# a blade raised overhead in frame.
			_look_from(a + forward.rotated(Vector3.UP, deg_to_rad(-45.0)) * 3.8 + Vector3(0.0, 1.3, 0.0),
				a + forward * 0.7 + Vector3(0.0, 1.05, 0.0), 45.0)
		&"three_quarter_left":
			# the same from the front on the off-hand (left) side
			_look_from(a + forward.rotated(Vector3.UP, deg_to_rad(45.0)) * 3.8 + Vector3(0.0, 1.3, 0.0),
				a + forward * 0.7 + Vector3(0.0, 1.05, 0.0), 45.0)
		&"side":
			# square on to the way it faces, from its right, the whole body
			_look_from(a + CameraRig.right_of(forward) * 4.2 + Vector3(0.0, 1.0, 0.0), a + Vector3(0.0, 0.95, 0.0), 40.0)
		&"front":
			# from in front, a little to its right, the whole body: legs
			# turned under a chest that faces the camera
			_look_from(a + forward.rotated(Vector3.UP, deg_to_rad(-20.0)) * 4.2 + Vector3(0.0, 1.0, 0.0), a + Vector3(0.0, 0.95, 0.0), 40.0)
		&"feet":
			# down on the feet from in front, square to the line between
			# them as they stand (the side of it the fighter faces)
			var ankles: PackedVector3Array = _ankles()
			var across: Vector3 = ((ankles[0] - ankles[1]) * Vector3(1.0, 0.0, 1.0)).normalized().rotated(Vector3.UP, PI / 2.0)
			if across.length() < 0.5:
				across = forward
			if across.dot(forward) < 0.0:
				across = -across
			_look_from(a + across * 2.0 + Vector3(0.0, 1.3, 0.0), a + Vector3(0.0, 0.2, 0.0), 38.0)
		&"close":
			_look_from(a + forward.rotated(Vector3.UP, deg_to_rad(-30.0)) * 2.1 + Vector3(0.0, 1.6, 0.0),
				a + forward * 0.3 + Vector3(0.0, 1.4, 0.0), 44.0)
		&"hands":
			# From the front, outside and above the gripping hands, further
			# back the further apart they are.
			var hands: PackedVector3Array = _hands()
			var centre: Vector3 = Vector3.ZERO
			for p: Vector3 in hands:
				centre += p / float(hands.size())
			var spread: float = 0.0
			for p: Vector3 in hands:
				spread = maxf(spread, p.distance_to(centre) * 2.0)
			var offset: Vector3 = CameraRig.right_of(forward) * 0.35 + Vector3.UP * 0.2 + forward * 0.55
			_look_from(centre + offset * (1.0 + spread), centre, 32.0)


func _look_from(pos: Vector3, target: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.look_at_from_position(pos, target, Vector3.UP)


## Where the attacker's hands grip, in world space: the grip points of the
## hands on posed weapons, or the hands themselves when none are posed.
## The attacker's ankles in the world as last posed, right then left.
func _ankles() -> PackedVector3Array:
	var sk: Skeleton3D = bench.view.model.skeleton
	var out: PackedVector3Array = []
	for side: String in ["Right", "Left"]:
		out.append(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "Foot")).origin)
	return out


func _hands() -> PackedVector3Array:
	var model: FighterModel = bench.view.model
	var sk: Skeleton3D = model.skeleton
	var out: PackedVector3Array = []
	for side: String in ["Right", "Left"]:
		if model.rig.drives(side):
			out.append(sk.global_transform * model.rig.grip_point(side))
	if out.is_empty():
		for side: String in ["Right", "Left"]:
			out.append(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin)
	return out


## A view's crop of a screen `size` pixels big (see ASPECTS).
static func crop_rect(view: StringName, size: Vector2) -> Rect2:
	var w: float = minf(size.x, roundf(size.y * ASPECTS.get(view, 1.0)))
	return Rect2(roundf((size.x - w) / 2.0), 0.0, w, size.y)


## A view's cell in the sheet, in pixels.
static func cell_size(view: StringName) -> Vector2i:
	return Vector2i(roundi(CELL_HEIGHT * ASPECTS.get(view, 1.0)), CELL_HEIGHT)


## How wide a row of these views is, in pixels.
static func row_width(p_views: Array[StringName]) -> int:
	var w: int = 0
	for view: StringName in p_views:
		w += cell_size(view).x
	return w + GAP * maxi(0, p_views.size() - 1)


# --- sheets ------------------------------------------------------------------

func _run() -> void:
	if drive != &"":
		_sheet = await render_drive(drive)
	elif move == BATCH:
		_sheet = await batch()
	else:
		_sheet = await render(move)
		if _sheet == null:
			push_error("move_sheet.gd: no sheet for '%s'" % move)
	_done = true


## The contact sheet of a move (or GUARD), with its rows kept in rows and its
## header in title; null (reported) when the weapon has no such move.
func render(move_id: StringName) -> Image:
	rows.clear()
	var steps: Array[MoveBench.Step] = []
	if move_id == GUARD:
		bench.stand()
		_show_defender()
		var report: PoseCheck.Report = bench.check.measure(await bench.frame())
		rows.append(await _row(PackedStringArray(["guard · " + report.summary(), verdict(report)]), report, false))
	else:
		if not bench.begin(move_id):
			return null
		_show_defender()
		var def: AttackDef = bench.move
		var chosen: Array[int] = frames_for(at, def)
		var s: MoveBench.Step = await bench.next_frame()
		while s != null:
			steps.append(s)
			_show_defender()
			if chosen.has(s.frame):
				rows.append(await _row(caption(s, def), s.report, s.contact))
			s = await bench.next_frame()
		print("move_sheet: %s %s" % [fighter_id, MoveBench.summary(move_id, steps)])
	title = _title(move_id, steps)
	var header: Image = await _text_image(title, tones(title),
		Vector2i(mini(row_width(views), _screen_size().x), HEADER_HEIGHT), HEADER_FONT)
	return compose(header, rows)


## A frame's caption: its number, phase and PoseCheck numbers, then the verdict.
static func caption(s: MoveBench.Step, def: AttackDef) -> PackedStringArray:
	return PackedStringArray([
		"frame %d of %d · %s%s · %s" % [s.frame, last_frame(def), s.phase, ", contact" if s.contact else "", s.report.summary()],
		verdict(s.report),
	])


## Each header line's colour: a verdict or failure count in red or green.
static func tones(lines: PackedStringArray) -> Array[Color]:
	var out: Array[Color] = []
	for line: String in lines:
		if line.begins_with("passes") or line.begins_with("fails 0/"):
			out.append(PASS_COLOR)
		elif line.begins_with("fails"):
			out.append(FAIL_COLOR)
		else:
			out.append(TEXT_COLOR)
	return out


## What fails PoseCheck, or that it passes.
static func verdict(report: PoseCheck.Report) -> String:
	var fails: PackedStringArray = report.failures()
	return "passes PoseCheck" if fails.is_empty() else "fails: " + ", ".join(fails)


func _title(move_id: StringName, steps: Array[MoveBench.Step]) -> PackedStringArray:
	var what: String = "the guard"
	if move_id != GUARD:
		var def: AttackDef = bench.weapon.moves[move_id]
		what = "%s %s, %s %s (startup %d, active %d, recovery %d)" % [
			def.id, def.name, def.kind, def.type, def.startup, def.active, def.recovery]
	var view_names: PackedStringArray = []
	for view: StringName in views:
		view_names.append(VIEW_NAMES[view])
	var out: PackedStringArray = [
		"%s (palette A) with the %s: %s" % [bench.view.model.look.display_name, bench.weapon.name, what],
		"against the %s (palette B) at %.1f m" % [defender_view.model.look.display_name, spacing],
		"views: " + ", ".join(view_names),
	]
	if swings_path != "":
		out[0] += " · swings from " + swings_path
	if steps.is_empty():
		out.append(verdict(rows[0].report))
	else:
		# MoveBench's summary of the whole move, its failure counts on a line
		# of their own
		var whole: String = " ".join(MoveBench.summary(move_id, steps).split(" ", false))
		var cut: int = whole.find(" fails ")
		out.append_array([whole.left(cut), whole.substr(cut + 1)])
	return out


## The guard and every move of the weapon (the batch's sheets, in order).
func batch_moves() -> Array[StringName]:
	var out: Array[StringName] = [GUARD]
	out.append_array(bench.weapon.moves.keys())
	return out


## Where the batch saves a move's sheet: beside out, named after it.
static func sheet_path(out: String, move_id: StringName) -> String:
	return "%s_%s.png" % [out.get_basename(), move_id]


## Renders and saves every sheet of the batch; the index of them all.
func batch() -> Image:
	var out: String = out_path if out_path != "" else ProjectSettings.globalize_path("user://move_sheet.png")
	var cells: Array[Image] = []
	var passing: int = 0
	var moves: Array[StringName] = batch_moves()
	for move_id: StringName in moves:
		var sheet: Image = await render(move_id)
		if sheet == null:
			continue
		var path: String = sheet_path(out, move_id)
		var err: Error = sheet.save_png(path)
		if err != OK:
			push_error("move_sheet.gd: cannot save %s (%s)" % [path, error_string(err)])
		else:
			print("move_sheet: saved %s" % path)
		if rows.is_empty():
			continue
		var row: Row = rows[0]
		for r: Row in rows:
			if r.contact:
				row = r
		if row.report.passed():
			passing += 1
		var name_text: String = "guard" if move_id == GUARD else "%s %s" % [move_id, bench.weapon.moves[move_id].name]
		var label: Image = await _text_image(PackedStringArray([
			"%s · %s" % [name_text, row.lines[0].get_slice(" · ", 0) if move_id != GUARD else "standing"], verdict(row.report),
		]), [TEXT_COLOR, PASS_COLOR if row.report.passed() else FAIL_COLOR], Vector2i(row.cells[0].get_width(), CAPTION_HEIGHT), CAPTION_FONT)
		cells.append(stack(label, row.cells[0]))
	var index: Array[Row] = []
	for i: int in cells.size():
		if i % INDEX_COLUMNS == 0:
			index.append(Row.new())
		index[-1].cells.append(cells[i])
	title = PackedStringArray([
		"%s (palette A) with the %s against the %s (palette B) at %.1f m: the guard and every move" % [
			bench.view.model.look.display_name, bench.weapon.name, defender_view.model.look.display_name, spacing],
		"each at its first active frame from the %s; the sheets are beside this one" % VIEW_NAMES[views[0]],
		"%d of %d pass PoseCheck there" % [passing, cells.size()],
	])
	var width: int = mini(INDEX_COLUMNS, cells.size()) * (cells[0].get_width() + GAP) - GAP if not cells.is_empty() else 0
	var header: Image = await _text_image(title, tones(title),
		Vector2i(clampi(width, 1, _screen_size().x), HEADER_HEIGHT), HEADER_FONT)
	return compose(header, index)


## Drive `drive_id`'s input, a RawInput per frame: the fighter's, or with
## `field` "defender" the opponent's (empty when it takes none).
static func drive_inputs(drive_id: StringName, field: String = "input") -> Array[RawInput]:
	var out: Array[RawInput] = []
	for segment: Array in DRIVES[drive_id].get(field, []):
		for i: int in int(segment[0]):
			out.append(RawInput.make(segment[1], segment[2], segment[3]))
	return out


## The opponent's input for the parry drive: still, then the block pressed
## PARRY_LEAD frames before a light pressed on frame `light_at` with
## `startup` frames lands, and held; `total` frames in all.
static func parry_inputs(light_at: int, startup: int, total: int) -> Array[RawInput]:
	var out: Array[RawInput] = []
	var press: int = light_at + startup - PARRY_LEAD
	for i: int in total:
		out.append(RawInput.make(0.0, 0.0, BLOCK if i >= press else 0))
	return out


## The frames a strip of `total` frames shows: the first, every `p_every`th
## and the last.
static func drive_frames(total: int, p_every: int) -> Array[int]:
	var out: Array[int] = [1]
	for f: int in range(p_every, total + 1, p_every):
		if not out.has(f):
			out.append(f)
	if not out.has(total):
		out.append(total)
	return out


## Plays drive `drive_id` from rest in a fresh world, the opponent out of
## the way (the drive's spacing unless --spacing= says), and lays out the
## strip: a cell at each chosen frame, captioned with the frame, the speed,
## the legs' turn, the blend's weights and the step phase, in a block of
## rows per view.
func render_drive(drive_id: StringName) -> Image:
	if not _spacing_given:
		bench.spacing = float(DRIVES[drive_id]["spacing"])
		if bench.spacing <= 0.0:
			# the fighter's duelling distance
			bench.spacing = bench.weapon.duel_distance
	bench.stand()
	if DRIVES[drive_id].has("hp"):
		bench.attacker.hp = float(DRIVES[drive_id]["hp"])
	_show_defender()
	strip.clear()
	var loco: Locomotion = bench.view.locomotion
	var inputs: Array[RawInput] = drive_inputs(drive_id)
	var opponent: Array[RawInput] = drive_inputs(drive_id, "defender")
	if face != 0.0:
		bench.attacker.yaw = SimMath.wrap_angle(bench.attacker.yaw + deg_to_rad(face))
		bench.attacker.blind_until = 1 << 30
	# the opponent's light in a drive that has one may be any move (--move),
	# started where the light's press would be (task 35's reactions by place)
	var opponent_move: StringName = &""
	var opponent_at: int = -1
	if not DRIVES[drive_id].has("parry") and bench.weapon.moves.has(move):
		for i: int in opponent.size():
			if opponent[i].buttons & LIGHT:
				opponent_move = move
				opponent_at = i
				break
	# a parry drive may parry any move (--move), started where the light's
	# press would be (milestone-1 task 34: each light's deflect pair)
	var parried: StringName = &""
	if DRIVES[drive_id].has("parry"):
		parried = move if bench.weapon.moves.has(move) else bench.weapon.light_start
		var light: AttackDef = bench.weapon.moves[parried]
		opponent = parry_inputs(int(DRIVES[drive_id]["parry"]), light.startup, inputs.size())
	var chosen: Array[int] = drive_frames(inputs.size(), every)
	var cells: Dictionary[StringName, Array] = {}
	for view: StringName in views:
		cells[view] = []
	for i: int in inputs.size():
		var input: RawInput = inputs[i]
		if parried != &"" and i == int(DRIVES[drive_id]["parry"]):
			bench.attacker.start_attack(parried)
			input = RawInput.empty()
		var other: RawInput = opponent[i] if i < opponent.size() else null
		if i == opponent_at:
			bench.defender.start_attack(opponent_move)
			other = RawInput.empty()
		bench.drive(input, other)
		_show_defender()
		if not chosen.has(i + 1):
			continue
		await bench.frame()
		var lines: PackedStringArray = drive_caption(i + 1, loco, _held(bench.view))
		if bench.attacker.state == &"attack":
			lines[0] += " · %s frame %d" % [bench.attacker.atk.def.id, bench.attacker.atk.frame]
		elif bench.attacker.state != &"free":
			lines[0] += " · %s %d" % [bench.attacker.state, bench.attacker.sf]
		var shot: ClipDirector.Shot = bench.view.shot
		if shot != null and shot.clip != null:
			# the clip driving (a bridge or a return to guard among them, task 33)
			lines[1] = "%s %.2f s · %s" % [String(shot.clip.name).get_file(), shot.clip.time, lines[1]]
		if parried != &"":
			# how far apart the two blades are (task 34: within 2 cm at contact)
			var dshot: ClipDirector.Shot = defender_view.shot
			lines[2] = "blades %.1f cm apart · %s %s · %s" % [blade_gap(bench.view, defender_view) * 100.0, dshot.phase if dshot != null else &"",
				String(dshot.clip.name).get_file() if dshot != null and dshot.clip != null else "", lines[2]]
		strip.append(lines)
		for view: StringName in views:
			var label: Image = await _text_image(lines, [TEXT_COLOR, TEXT_COLOR, TEXT_COLOR],
				Vector2i(cell_size(view).x, STRIP_CAPTION_HEIGHT), CAPTION_FONT)
			cells[view].append(stack(label, await _capture(view)))
	var grid: Array[Row] = []
	for view: StringName in views:
		for i: int in cells[view].size():
			if i % STRIP_COLUMNS == 0:
				grid.append(Row.new())
			grid[-1].cells.append(cells[view][i])
	var view_names: PackedStringArray = []
	for view: StringName in views:
		view_names.append(VIEW_NAMES[view])
	title = PackedStringArray([
		"%s (palette A) with the %s: %s (%s)%s" % [bench.view.model.look.display_name, bench.weapon.name, drive_id, DRIVES[drive_id]["notes"],
			" · swings from " + swings_path if swings_path != "" else ""],
		"views: %s · every %d frames · the opponent %.1f m off · legs: the way they travel, + to the left; held: the feet the foot lock holds" % [
			", ".join(view_names), every, bench.spacing],
		"blend: walk at the clips' pace (%.2f m/s ahead), run at %.2f that way, sprint at %.2f · strides ahead: walk %.2f m, run %.2f, sprint %.2f" % [
			loco.walk_speed(0.0), loco.run_speed, loco.sprint_speed, loco.gaits[loco.clips[&"walk"][0]].stride,
			loco.gaits[loco.clips[&"run"][0]].stride, loco.gaits[loco.clips[&"sprint"][0]].stride],
	])
	var width: int = 1
	if not grid.is_empty():
		width = mini(STRIP_COLUMNS, chosen.size()) * (grid[0].cells[0].get_width() + GAP) - GAP
	var header: Image = await _text_image(title, tones(title), Vector2i(clampi(width, 1, _screen_size().x), HEADER_HEIGHT), HEADER_FONT)
	return compose(header, grid)


## The least distance between two fighters' held blades as posed, in
## metres (INF with a blade missing).
static func blade_gap(a: FighterView, b: FighterView) -> float:
	var sa: Array[PackedVector3Array] = a.blade_segments()
	var sb: Array[PackedVector3Array] = b.blade_segments()
	if sa.is_empty() or sb.is_empty():
		return INF
	var near: PackedVector3Array = Geometry3D.get_closest_points_between_segments(sa[0][0], sa[0][1], sb[0][0], sb[0][1])
	return near[0].distance_to(near[1])


## A strip frame's caption: the frame, the speed and the way the legs
## travel (+ to the left), with the body's turn away for a sprint held
## backwards; then the blend's clips and weights (those over 0.005) and the
## step phase; then the turn on the spot while it plays, and which feet the
## foot lock holds (`held`: "Left", "Right").
static func drive_caption(frame: int, loco: Locomotion, held: Array = []) -> PackedStringArray:
	var first: String = "frame %d · %.2f m/s · legs %+.0f°" % [frame, loco.speed, rad_to_deg(loco.way)]
	if absf(loco.shown_away) >= deg_to_rad(0.5):
		first += " · turned away %+.0f°" % rad_to_deg(loco.shown_away)
	var weights: PackedStringArray = []
	if loco.shown_idle > 0.005:
		weights.append("idle %.2f" % loco.shown_idle)
	for c: Array in loco.shown_clips:
		if float(c[1]) > 0.005:
			weights.append("%s %.2f" % [String(c[0]).get_file(), float(c[1])])
	var second: String = "%s · phase %.2f" % [" ".join(weights), loco.shown_phase]
	var third: String = ""
	if loco.shown_turn > 0.005:
		third = "turning %s %.2f · " % ["left" if loco.turn_left else "right", loco.shown_turn]
	if held.is_empty():
		third += "feet free"
	else:
		third += "held: %s" % ", ".join(PackedStringArray(held.map(func(x: Variant) -> String: return String(x).to_lower())))
	return PackedStringArray([first, second, third])


## The feet view `v`'s foot lock holds now ("Left", "Right").
static func _held(v: FighterView) -> Array:
	var out: Array = []
	for side: String in ["Left", "Right"]:
		if v.foot_lock != null and v.foot_lock.holds(side):
			out.append(side)
	return out


## Lays out a sheet: the header on top, then each row's caption over its
## cells, with GAP between rows and between cells, on BACKGROUND.
static func compose(header: Image, p_rows: Array[Row]) -> Image:
	var width: int = header.get_width()
	var height: int = header.get_height()
	for row: Row in p_rows:
		var w: int = -GAP
		var h: int = 0
		for cell: Image in row.cells:
			w += cell.get_width() + GAP
			h = maxi(h, cell.get_height())
		if row.caption != null:
			w = maxi(w, row.caption.get_width())
			h += row.caption.get_height()
		width = maxi(width, w)
		height += GAP + h
	var out: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	out.fill(BACKGROUND)
	_blit(out, header, Vector2i.ZERO)
	var y: int = header.get_height()
	for row: Row in p_rows:
		y += GAP
		if row.caption != null:
			_blit(out, row.caption, Vector2i(0, y))
			y += row.caption.get_height()
		var x: int = 0
		var h: int = 0
		for cell: Image in row.cells:
			_blit(out, cell, Vector2i(x, y))
			x += cell.get_width() + GAP
			h = maxi(h, cell.get_height())
		y += h
	return out


## `top` over `bottom`, left-aligned.
static func stack(top: Image, bottom: Image) -> Image:
	var out: Image = Image.create(maxi(top.get_width(), bottom.get_width()), top.get_height() + bottom.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(BACKGROUND)
	_blit(out, top, Vector2i.ZERO)
	_blit(out, bottom, Vector2i(0, top.get_height()))
	return out


static func _blit(onto: Image, image: Image, at_pos: Vector2i) -> void:
	var src: Image = image
	if src.get_format() != Image.FORMAT_RGBA8:
		src = image.duplicate() as Image
		src.convert(Image.FORMAT_RGBA8)
	onto.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at_pos)


# --- capture -----------------------------------------------------------------

## One row: the caption drawn, and a cell per view of the fighters as they
## stand now.
func _row(lines: PackedStringArray, report: PoseCheck.Report, contact: bool) -> Row:
	var row: Row = Row.new()
	row.lines = lines
	row.report = report
	row.contact = contact
	row.caption = await _text_image(lines, [TEXT_COLOR, PASS_COLOR if report.passed() else FAIL_COLOR],
		Vector2i(mini(row_width(views), _screen_size().x), CAPTION_HEIGHT), CAPTION_FONT)
	for view: StringName in views:
		row.cells.append(await _capture(view))
	return row


func _capture(view: StringName) -> Image:
	aim(view)
	var screen: Image = await _screen()
	var crop: Rect2 = crop_rect(view, Vector2(screen.get_size()))
	var cell: Image = screen.get_region(Rect2i(crop))
	var size: Vector2i = cell_size(view)
	cell.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return cell


## Lines of text in their colours on BACKGROUND, `size` pixels big, drawn on
## the screen over everything for one frame.
func _text_image(lines: PackedStringArray, colors: Array[Color], size: Vector2i, font_size: int) -> Image:
	for child: Node in _overlay.get_children():
		child.free()
	var back: ColorRect = ColorRect.new()
	back.color = BACKGROUND
	back.size = Vector2(_screen_size())
	_overlay.add_child(back)
	var line_height: float = float(size.y - 2 * TEXT_MARGIN) / maxf(1.0, lines.size())
	for i: int in lines.size():
		var label: Label = Label.new()
		label.text = lines[i]
		label.position = Vector2(TEXT_MARGIN, TEXT_MARGIN + i * line_height)
		label.size = Vector2(size.x - 2 * TEXT_MARGIN, line_height)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", colors[mini(i, colors.size() - 1)])
		_overlay.add_child(label)
	_overlay.visible = true
	var screen: Image = await _screen()
	_overlay.visible = false
	return screen.get_region(Rect2i(Vector2i.ZERO, size))


## The next frame drawn. Headless runs draw nothing, so they get a blank one.
func _screen() -> Image:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		var blank: Image = Image.create(_screen_size().x, _screen_size().y, false, Image.FORMAT_RGBA8)
		blank.fill(BACKGROUND)
		return blank
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _screen_size() -> Vector2i:
	return Vector2i(get_viewport().get_visible_rect().size)


## Shows the defender where the rules have it, stepping its skeleton by hand
## like the attacker's, so its pose changes only with the rules.
func _show_defender() -> void:
	var f: Fighter = bench.defender
	defender_view.update_from(f, _feet(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	defender_view.model.skeleton.advance(1.0 / 60.0)


static func _feet(f: Fighter) -> Vector3:
	return Vector3(f.pos.x, f.pos.y, f.pos.z)
