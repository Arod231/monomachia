class_name DaggersMoves
extends RefCounted
## Port of src/sim/moves/daggers.ts.
##
## Twin Daggers — small class. Fast, slippery, strong HP damage over many hits,
## weak posture damage, short parry window.

const D: StringName = &"dagger"
## The string's four lights stun for 10 frames, where lights default to 14:
## they follow each other faster than other weapons' (Off-hand Slice lands 11
## frames after Quick Slice), so this leaves the defender a frame to block or
## parry the next.
const STRING_HITSTUN: int = 10

const MOVES: Dictionary = {
	&"d_l1": {
		"id": &"d_l1", "name": "Quick Slice", "kind": &"light", "type": &"slash", "anim": &"slashRL", "hand": &"R", "sound": D,
		"side_start": &"right", "side_end": &"left",
		"startup": 7, "active": 2, "recovery": 13, "damage": 4, "posture": 4, "knockback": 0.2, "hitstun": STRING_HITSTUN,
		"range": 1.8, "arc": 110, "lunge": 0.3, "chain_light": &"d_l2", "chain_heavy": &"d_h1", "dodge_cancel_from": 10,
	},
	# the left hand's slash: the stand-in mirrors slashRL onto the left hand, so
	# it runs left to right
	&"d_l2": {
		"id": &"d_l2", "name": "Off-hand Slice", "kind": &"light", "type": &"slash", "anim": &"slashRL", "hand": &"L", "sound": D,
		"side_start": &"left", "side_end": &"right",
		"startup": 7, "active": 2, "recovery": 13, "damage": 4, "posture": 4, "knockback": 0.2, "hitstun": STRING_HITSTUN,
		"range": 1.8, "arc": 110, "lunge": 0.3, "chain_light": &"d_l3", "chain_heavy": &"d_h1", "dodge_cancel_from": 10,
	},
	&"d_l3": {
		"id": &"d_l3", "name": "Twin Rip", "kind": &"light", "type": &"slash", "anim": &"cross", "hand": &"both", "sound": D,
		"side_start": &"centre", "side_end": &"centre",
		"startup": 9, "active": 3, "recovery": 14, "damage": 6, "posture": 5, "knockback": 0.3, "hitstun": STRING_HITSTUN,
		"range": 1.8, "arc": 100, "lunge": 0.4, "chain_light": &"d_l4", "dodge_cancel_from": 13,
	},
	&"d_l4": {
		"id": &"d_l4", "name": "Flurry Finisher", "kind": &"light", "type": &"stab", "anim": &"doubleStab", "hand": &"both", "sound": D,
		"side_start": &"centre", "side_end": &"centre",
		"startup": 11, "active": 3, "recovery": 18, "damage": 7, "posture": 6, "knockback": 0.6, "hitstun": STRING_HITSTUN,
		"range": 1.9, "arc": 70, "lunge": 0.6, "chain_heavy": &"d_h2", "dodge_cancel_from": 15,
	},
	# a dashing double stab
	&"d_h1": {
		"id": &"d_h1", "name": "Twin Fang", "kind": &"heavy", "type": &"stab", "anim": &"doubleStab", "hand": &"both", "sound": D,
		"side_start": &"centre", "side_end": &"centre",
		"startup": 16, "active": 3, "recovery": 20, "damage": 10, "posture": 9, "knockback": 0.6,
		"range": 1.9, "arc": 70, "lunge": 1.4, "chargeable": true, "chain_heavy": &"d_h2",
	},
	# the heavy string's finisher, after Twin Fang or Flurry Finisher: a spin
	&"d_h2": {
		"id": &"d_h2", "name": "Spinning Backhand", "kind": &"heavy", "type": &"spin", "anim": &"spin", "hand": &"both", "sound": D,
		"side_start": &"centre", "side_end": &"centre",
		"startup": 18, "active": 5, "recovery": 22, "damage": 12, "posture": 10, "knockback": 0.9,
		"range": 1.9, "arc": 360, "lunge": 0.4,
	},
	&"d_sl": {
		"id": &"d_sl", "name": "Slide Slash", "kind": &"light", "type": &"slash", "anim": &"slideSlash", "hand": &"R", "sound": D,
		"startup": 8, "active": 3, "recovery": 14, "damage": 6, "posture": 5, "knockback": 0.4,
		"range": 1.9, "arc": 110, "lunge": 2.0, "lunge_end": 11,
	},
	&"d_sh": {
		"id": &"d_sh", "name": "Pounce", "kind": &"heavy", "type": &"stab", "anim": &"pounce", "hand": &"both", "sound": D,
		"startup": 14, "active": 4, "recovery": 20, "damage": 11, "posture": 9, "knockback": 0.8,
		"range": 1.9, "arc": 80, "lunge": 3.0, "lunge_start": 2, "lunge_end": 16, "hop": 4,
	},
	# Passing Cut, on light out of a dodge: a cut that carries the fighter on
	# along the dodge, dodge-cancelling from its first recovery frame
	&"d_dl": {
		"id": &"d_dl", "name": "Passing Cut", "kind": &"light", "type": &"slash", "anim": &"slashRL", "hand": &"R", "sound": D,
		"startup": 6, "active": 2, "recovery": 12, "damage": 5, "posture": 4, "knockback": 0.2,
		"range": 1.8, "arc": 120, "lunge": 1.2, "lunge_along_dodge": true, "dodge_cancel_from": 9,
	},
	&"d_dh": {
		"id": &"d_dh", "name": "Reverse Spin", "kind": &"heavy", "type": &"spin", "anim": &"spin", "hand": &"both", "sound": D,
		"startup": 12, "active": 4, "recovery": 16, "damage": 9, "posture": 7, "knockback": 0.6,
		"range": 1.9, "arc": 360,
	},
	&"d_bl": {
		"id": &"d_bl", "name": "Flick", "kind": &"light", "type": &"slash", "anim": &"slashLR", "hand": &"L", "sound": D,
		"startup": 7, "active": 2, "recovery": 12, "damage": 4, "posture": 4, "knockback": 0.2,
		"range": 1.8, "arc": 110, "lunge": 0.5,
	},
	&"d_bh": {
		"id": &"d_bh", "name": "Rebound Lunge", "kind": &"heavy", "type": &"stab", "anim": &"doubleStab", "hand": &"both", "sound": D,
		"startup": 12, "active": 4, "recovery": 18, "damage": 10, "posture": 8, "knockback": 0.6,
		"range": 1.9, "arc": 70, "lunge": 2.5, "lunge_start": 2, "lunge_end": 14,
	},
	&"d_jl": {
		"id": &"d_jl", "name": "Air Slash", "kind": &"light", "type": &"slash", "anim": &"airSlash", "hand": &"R", "sound": D,
		"startup": 7, "active": 3, "recovery": 12, "damage": 5, "posture": 4, "knockback": 0.3,
		"range": 1.8, "arc": 120, "airborne": true,
	},
	&"d_jh": {
		"id": &"d_jh", "name": "Dive Stab", "kind": &"heavy", "type": &"stab", "anim": &"plunge", "hand": &"both", "sound": D,
		"startup": 12, "active": 4, "recovery": 18, "damage": 10, "posture": 9, "knockback": 0.6,
		"range": 1.9, "arc": 90, "airborne": true,
	},
	# --- block abilities ---
	&"d_sweep": {
		"id": &"d_sweep", "name": "Serpent Sweep", "kind": &"ability", "type": &"sweep", "anim": &"sweep", "hand": &"R", "sound": D,
		"startup": 20, "active": 5, "recovery": 22, "damage": 10, "posture": 12, "knockback": 0.6,
		"range": 2.0, "arc": 150, "lunge": 2.5, "lunge_start": 10, "lunge_end": 25,
		"unblockable": true, "jumpable": true, "counter": &"sweep",
	},
	&"d_shadow": {
		"id": &"d_shadow", "name": "Shadow Step", "kind": &"ability", "type": &"slash", "anim": &"shadowStep", "special": &"shadowStep",
		"startup": 5, "active": 14, "recovery": 8, "damage": 0, "posture": 0, "knockback": 0,
		"range": 0, "arc": 0, "invuln": [0, 20],
	},
	&"d_needle": {
		"id": &"d_needle", "name": "Needle Thrust", "kind": &"ability", "type": &"thrust", "anim": &"thrust", "hand": &"R", "sound": D,
		"startup": 20, "active": 3, "recovery": 20, "damage": 10, "posture": 12, "knockback": 0.5,
		"range": 2.4, "arc": 34, "lunge": 0.8, "lunge_start": 12, "lunge_end": 23,
		"unblockable": true, "counter": &"thrust", "track_active": 0.5,
	},
	&"d_lunge": {
		"id": &"d_lunge", "name": "Counter Lunge", "kind": &"light", "type": &"stab", "anim": &"pounce", "hand": &"both", "sound": D,
		"special": &"counterLunge", "startup": 5, "active": 3, "recovery": 16, "damage": 10, "posture": 18,
		"knockback": 0.6, "range": 1.9, "arc": 100, "lunge": 0, "lunge_end": 7, "trail": &"ult",
	},
}


## DAGGERS
static func build() -> WeaponDef:
	return WeaponDef.from_dict({
		"id": &"daggers",
		"name": "Twin Daggers",
		"cls": &"small",
		"speed_mult": 1.12,
		"dodge_mult": 1.2,
		"parry_window": 6,
		"block_mitigation": 0.8,
		"moves": AttackDef.finalize_moves(MOVES),
		"light_start": &"d_l1",
		"heavy_start": &"d_h1",
		"sprint_light": &"d_sl",
		"sprint_heavy": &"d_sh",
		"dodge_light": &"d_dl",
		"dodge_heavy": &"d_dh",
		"back_light": &"d_bl",
		"back_heavy": &"d_bh",
		"jump_light": &"d_jl",
		"jump_heavy": &"d_jh",
		"abilities": [&"d_sweep", &"d_shadow", &"d_needle"],
		"default_abilities": [&"d_sweep", &"d_shadow"],
		"ultimate": &"tempest",
		"reach": 1.6,
		"duel_distance": 2.0,
		"blurb": "Fast and slippery. Many quick hits, long dodges, a short parry window.",
		# each dagger's blade from the guard to the point, 1.3 cm thick at the
		# guard and 5 mm along the blade
		"blade": StrikeSegment.make(V3.make(0.0, 0.062, 0.0), V3.make(-0.019, 0.322, 0.0), 0.014),
		"foot": null,
		"off_hand_grip": null,
	})
