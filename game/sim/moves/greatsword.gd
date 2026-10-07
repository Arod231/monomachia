class_name GreatswordMoves
extends RefCounted
## Port of v0.1-web-mvp:src/sim/moves/greatsword.ts.
##
## Greatsword — colossal class. Slow and crushing, big knockback, sweeps and slams.

const C: StringName = &"colossal"

const MOVES: Dictionary = {
	&"g_l1": {
		"id": &"g_l1", "name": "Heavy Swing", "kind": &"light", "type": &"slash", "anim": &"slashRL", "sound": C,
		"side_start": &"right", "side_end": &"left",
		"damage": 9, "posture": 11, "knockback": 0.8,
		"range": 3.0, "arc": 120, "lunge": 0.45, "lunge_end": 18, "chain_light": &"g_l2", "chain_heavy": &"g_h1",
	},
	# rides Heavy Swing's momentum back the other way, so it starts sooner
	&"g_l2": {
		"id": &"g_l2", "name": "Backswing", "kind": &"light", "type": &"slash", "anim": &"slashLR", "sound": C,
		"side_start": &"left", "side_end": &"right",
		"damage": 9, "posture": 11, "knockback": 0.8,
		"range": 3.0, "arc": 120, "lunge": 0.55, "lunge_end": 18, "chain_heavy": &"g_h1",
	},
	&"g_h1": {
		"id": &"g_h1", "name": "Overhead Strike", "kind": &"heavy", "type": &"overhead", "anim": &"overhead", "sound": C,
		"side_start": &"centre", "side_end": &"right",
		"damage": 18, "posture": 22, "knockback": 1.6,
		"range": 3.1, "arc": 90, "lunge": 1.05, "lunge_start": 16, "lunge_end": 48, "chargeable": true,
		"chain_heavy": &"g_h2", "hitstop": 9,
	},
	# the heavy string's finisher, at the feet: unblockable, and a jump over it
	# is a leap counter
	&"g_h2": {
		"id": &"g_h2", "name": "Low Sweep", "kind": &"heavy", "type": &"sweep", "anim": &"sweep", "sound": C,
		"side_start": &"right", "side_end": &"left",
		"damage": 16, "posture": 22, "knockback": 2.0,
		"range": 3.2, "arc": 110, "lunge": 0.85, "lunge_start": 11, "lunge_end": 30,
		"unblockable": true, "jumpable": true, "counter": &"sweep", "hitstop": 10,
	},
	&"g_sl": {
		"id": &"g_sl", "name": "Shoulder Charge", "kind": &"light", "type": &"bash", "anim": &"bash", "sound": &"fist",
		"damage": 5, "posture": 14, "knockback": 1.3,
		"range": 1.5, "arc": 100, "lunge": 3.35, "lunge_end": 20,
	},
	&"g_sh": {
		"id": &"g_sh", "name": "Leaping Smash", "kind": &"heavy", "type": &"overhead", "anim": &"leapCleave", "sound": C,
		"damage": 18, "posture": 22, "knockback": 1.8,
		"range": 3.0, "arc": 70, "lunge": 3.15, "lunge_start": 6, "lunge_end": 28, "hop": 5.5, "hitstop": 10,
	},
	# Piercing Lunge, on light out of a dodge: a quick stab that a block stops
	&"g_dl": {
		"id": &"g_dl", "name": "Piercing Lunge", "kind": &"light", "type": &"stab", "anim": &"thrust", "sound": C,
		"damage": 8, "posture": 10, "knockback": 0.8,
		"range": 3.0, "arc": 50, "lunge": 1.0,
	},
	# Skewer, on heavy out of a dodge: an unblockable thrust, stomped by a dodge
	# forward into it
	&"g_dh": {
		"id": &"g_dh", "name": "Skewer", "kind": &"heavy", "type": &"thrust", "anim": &"thrust", "sound": C,
		"damage": 14, "posture": 18, "knockback": 1.4,
		"range": 3.4, "arc": 36, "lunge": 1.0, "unblockable": true, "counter": &"thrust", "track_active": 0.5,
	},
	&"g_bl": {
		"id": &"g_bl", "name": "Rising Edge", "kind": &"light", "type": &"slash", "anim": &"diagUp", "sound": C,
		"damage": 8, "posture": 10, "knockback": 0.7,
		"range": 2.8, "arc": 110, "lunge": 1.15,
	},
	&"g_bh": {
		"id": &"g_bh", "name": "Lunge Cleave", "kind": &"heavy", "type": &"slash", "anim": &"diagDown", "sound": C,
		"damage": 14, "posture": 18, "knockback": 1.5,
		"range": 3.0, "arc": 80, "lunge": 2.35, "lunge_start": 7, "lunge_end": 30,
	},
	&"g_jl": {
		"id": &"g_jl", "name": "Aerial Chop", "kind": &"light", "type": &"slash", "anim": &"airSlash", "sound": C,
		"damage": 9, "posture": 10, "knockback": 0.7,
		"range": 2.7, "arc": 120, "airborne": true,
	},
	&"g_jh": {
		"id": &"g_jh", "name": "Meteor Drop", "kind": &"heavy", "type": &"overhead", "anim": &"plunge", "sound": C,
		"damage": 18, "posture": 24, "knockback": 1.8,
		"range": 2.8, "arc": 110, "airborne": true, "hitstop": 10,
	},
	# --- block abilities ---
	&"g_sweep": {
		"id": &"g_sweep", "name": "Reaping Sweep", "kind": &"ability", "type": &"sweep", "anim": &"sweep", "sound": C,
		"damage": 14, "posture": 18, "knockback": 1.0,
		"range": 3.0, "arc": 160, "lunge": 1.65, "unblockable": true, "jumpable": true, "counter": &"sweep",
	},
	&"g_slam": {
		"id": &"g_slam", "name": "Mountain Slam", "kind": &"ability", "type": &"slam", "anim": &"slam", "sound": C,
		"damage": 20, "posture": 26, "knockback": 1.6,
		"range": 3.2, "arc": 44, "lunge": 1.35, "lunge_start": 12, "lunge_end": 34,
		"unblockable": true, "counter": &"slam", "hitstop": 12,
	},
	&"g_crush": {
		"id": &"g_crush", "name": "Guard Crusher", "kind": &"ability", "type": &"bash", "anim": &"bash", "sound": &"fist",
		"damage": 4, "posture": 20, "knockback": 1.2,
		"range": 1.6, "arc": 100, "lunge": 1.85, "lunge_end": 19, "guard_crush": 1.6,
	},
	&"g_lunge": {
		"id": &"g_lunge", "name": "Counter Lunge", "kind": &"light", "type": &"slash", "anim": &"drawCut", "sound": C,
		"special": &"counterLunge", "damage": 12, "posture": 24,
		"knockback": 1.2, "range": 2.7, "arc": 100, "lunge": 0, "lunge_end": 18, "trail": &"ult",
	},
}


## GREATSWORD
static func build() -> WeaponDef:
	return WeaponDef.from_dict({
		"id": &"greatsword",
		"name": "Greatsword",
		"cls": &"colossal",
		"speed_mult": 0.9,
		"dodge_mult": 0.95,
		"parry_window": 12,
		"block_mitigation": 0.6,
		"moves": AttackDef.finalize_moves(MOVES, &"greatsword"),
		"light_start": &"g_l1",
		"heavy_start": &"g_h1",
		"sprint_light": &"g_sl",
		"sprint_heavy": &"g_sh",
		"dodge_light": &"g_dl",
		"dodge_heavy": &"g_dh",
		"back_light": &"g_bl",
		"back_heavy": &"g_bh",
		"jump_light": &"g_jl",
		"jump_heavy": &"g_jh",
		"abilities": [&"g_sweep", &"g_slam", &"g_crush"],
		"default_abilities": [&"g_sweep", &"g_slam"],
		"ultimate": &"impaler",
		"reach": 3.1,
		"duel_distance": 3.35,
		"blurb": "Slow and crushing. Huge knockback, sweeps and overhead slams.",
		# the blade from the guard to the point, 2.5 cm thick (grown by 1.15
		# with the bodies, KE task 4)
		"blade": StrikeSegment.make(V3.make(0.0, 0.156, 0.0), V3.make(0.0, 1.555, 0.0), 0.0253),
		"foot": null,
		# the left hand below the right on the long handle
		"off_hand_grip": V3.make(0.0, -0.306, 0.0),
		# one implicit grip (KE task 5)
		"grips": [],
	})
