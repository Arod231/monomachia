class_name KatanaMoves
extends RefCounted
## Port of src/sim/moves/katana.ts.
##
## Katana — medium class. Balanced, versatile, decent speed.

const MOVES: Dictionary = {
	&"k_l1": {
		"id": &"k_l1", "name": "Right Cut", "kind": &"light", "type": &"slash", "anim": &"slashRL",
		"side_start": &"right", "side_end": &"left",
		"startup": 11, "active": 3, "recovery": 16, "damage": 6, "posture": 7, "knockback": 0.35,
		"range": 2.2, "arc": 110, "lunge": 0.35, "lunge_end": 13, "chain_light": &"k_l2", "chain_heavy": &"k_h2", "dodge_cancel_from": 20,
	},
	&"k_l2": {
		"id": &"k_l2", "name": "Return Cut", "kind": &"light", "type": &"slash", "anim": &"slashLR",
		"side_start": &"left", "side_end": &"right",
		"startup": 10, "active": 3, "recovery": 16, "damage": 6, "posture": 7, "knockback": 0.35,
		"range": 2.2, "arc": 110, "lunge": 0.45, "lunge_end": 11, "chain_light": &"k_l3", "chain_heavy": &"k_h1f", "dodge_cancel_from": 19,
	},
	&"k_l3": {
		"id": &"k_l3", "name": "Kesa Cut", "kind": &"light", "type": &"slash", "anim": &"diagDown",
		"side_start": &"right", "side_end": &"left",
		"startup": 11, "active": 3, "recovery": 17, "damage": 7, "posture": 8, "knockback": 0.4,
		"range": 2.2, "arc": 100, "lunge": 0.4, "lunge_end": 14, "chain_light": &"k_l4", "chain_heavy": &"k_h2", "dodge_cancel_from": 20,
	},
	&"k_l4": {
		"id": &"k_l4", "name": "Crown Cut", "kind": &"light", "type": &"overhead", "anim": &"overhead",
		"side_start": &"centre", "side_end": &"centre",
		"startup": 14, "active": 4, "recovery": 22, "damage": 8, "posture": 10, "knockback": 0.6,
		"range": 2.3, "arc": 60, "lunge": 0.7, "lunge_end": 15, "dodge_cancel_from": 26,
	},
	# the heavy: sheathe for 9 frames (up to the fighter's charge check,
	# CHARGE_CHECK_FRAME: held, the stance is the charge, walked in at the
	# blocking walk's speed), then draw in 14, lunging only once the sheathe ends
	&"k_iai": {
		"id": &"k_iai", "name": "Iai Slash (vertical)", "kind": &"heavy", "type": &"overhead", "anim": &"iaiVertical",
		"side_start": &"left", "side_end": &"right",
		"startup": 23, "active": 4, "recovery": 24, "damage": 13, "posture": 16, "knockback": 1.0,
		"range": 3.6, "arc": 60, "lunge": 2.1, "lunge_start": 9, "lunge_end": 25, "chargeable": true,
		"charge_move": true, "release_variant": &"k_iai_h", "chain_heavy": &"k_h1f",
	},
	# the same sheathe, drawn right to left when the stick is held left or
	# right as the Iai is drawn; it swaps in on the Iai's attack, so it keeps
	# the Iai's frames and lunge, and is never started on its own
	&"k_iai_h": {
		"id": &"k_iai_h", "name": "Iai Slash (horizontal)", "kind": &"heavy", "type": &"slash", "anim": &"iaiHorizontal",
		"side_start": &"right", "side_end": &"left",
		"startup": 23, "active": 4, "recovery": 24, "damage": 13, "posture": 16, "knockback": 1.0,
		"range": 3.6, "arc": 110, "lunge": 2.1, "lunge_start": 9, "lunge_end": 25,
		"chain_light": &"k_l2", "chain_heavy": &"k_rdraw",
	},
	&"k_h1f": {
		"id": &"k_h1f", "name": "Rising Heaven", "kind": &"heavy", "type": &"slash", "anim": &"diagUp",
		"side_start": &"right", "side_end": &"left",
		"startup": 16, "active": 4, "recovery": 24, "damage": 12, "posture": 15, "knockback": 0.9,
		"range": 2.3, "arc": 90, "lunge": 1.2, "lunge_end": 18, "chain_heavy": &"k_h2",
	},
	# the horizontal Iai's heavy follow-up, back the other way
	&"k_rdraw": {
		"id": &"k_rdraw", "name": "Returning Draw", "kind": &"heavy", "type": &"slash", "anim": &"slashLR",
		"side_start": &"left", "side_end": &"right",
		"startup": 16, "active": 4, "recovery": 24, "damage": 12, "posture": 15, "knockback": 0.9,
		"range": 2.3, "arc": 110, "lunge": 1.1, "lunge_end": 18,
	},
	&"k_h2": {
		"id": &"k_h2", "name": "Heaven Splitter", "kind": &"heavy", "type": &"overhead", "anim": &"overhead",
		"side_start": &"centre", "side_end": &"centre",
		"startup": 22, "active": 4, "recovery": 28, "damage": 15, "posture": 18, "knockback": 1.2,
		"range": 2.4, "arc": 60, "lunge": 0.95, "lunge_start": 8, "lunge_end": 24,
	},
	&"k_sl": {
		"id": &"k_sl", "name": "Running Draw", "kind": &"light", "type": &"slash", "anim": &"drawCut",
		"startup": 12, "active": 4, "recovery": 18, "damage": 8, "posture": 9, "knockback": 0.5,
		"range": 2.3, "arc": 100, "lunge": 1.7, "lunge_end": 15,
	},
	&"k_sh": {
		"id": &"k_sh", "name": "Leaping Cleave", "kind": &"heavy", "type": &"overhead", "anim": &"leapCleave",
		"startup": 20, "active": 5, "recovery": 26, "damage": 15, "posture": 18, "knockback": 1.2,
		"range": 2.4, "arc": 70, "lunge": 2.9, "lunge_start": 4, "lunge_end": 22, "hop": 5,
	},
	&"k_dl": {
		"id": &"k_dl", "name": "Wind Cut", "kind": &"light", "type": &"slash", "anim": &"slashRL",
		"startup": 9, "active": 3, "recovery": 16, "damage": 6, "posture": 7, "knockback": 0.4,
		"range": 2.2, "arc": 120, "lunge": 0.5, "dodge_cancel_from": 18,
	},
	&"k_dh": {
		"id": &"k_dh", "name": "Whirl Cut", "kind": &"heavy", "type": &"spin", "anim": &"spin",
		"startup": 18, "active": 6, "recovery": 24, "damage": 12, "posture": 14, "knockback": 1.0,
		"range": 2.3, "arc": 360, "lunge": 0.5,
	},
	&"k_bl": {
		"id": &"k_bl", "name": "Rising Cut", "kind": &"light", "type": &"slash", "anim": &"diagUp",
		"startup": 10, "active": 3, "recovery": 18, "damage": 6, "posture": 8, "knockback": 0.4,
		"range": 2.2, "arc": 100, "lunge": 1.25,
	},
	&"k_bh": {
		"id": &"k_bh", "name": "Lunging Cut", "kind": &"heavy", "type": &"slash", "anim": &"diagDown",
		"startup": 18, "active": 4, "recovery": 24, "damage": 12, "posture": 14, "knockback": 1.0,
		"range": 2.4, "arc": 80, "lunge": 2.3, "lunge_start": 4, "lunge_end": 20,
	},
	&"k_jl": {
		"id": &"k_jl", "name": "Aerial Cut", "kind": &"light", "type": &"slash", "anim": &"airSlash",
		"startup": 7, "active": 4, "recovery": 12, "damage": 6, "posture": 7, "knockback": 0.4,
		"range": 2.1, "arc": 120, "airborne": true,
	},
	&"k_jh": {
		"id": &"k_jh", "name": "Falling Crown", "kind": &"heavy", "type": &"overhead", "anim": &"plunge",
		"startup": 12, "active": 5, "recovery": 18, "damage": 13, "posture": 16, "knockback": 1.0,
		"range": 2.3, "arc": 80, "airborne": true,
	},
	# --- block abilities ---
	&"k_flash": {
		"id": &"k_flash", "name": "Flash", "kind": &"ability", "type": &"slash", "anim": &"flash", "special": &"flash",
		"startup": 2, "active": 18, "recovery": 18, "damage": 0, "posture": 0, "knockback": 0,
		"range": 0, "arc": 0,
	},
	&"k_thrust": {
		"id": &"k_thrust", "name": "Piercing Thrust", "kind": &"ability", "type": &"thrust", "anim": &"thrust",
		"startup": 26, "active": 4, "recovery": 24, "damage": 12, "posture": 16, "knockback": 0.8,
		"range": 3.1, "arc": 36, "lunge": 1.4, "lunge_start": 18, "lunge_end": 30,
		"unblockable": true, "counter": &"thrust", "track_startup": 5, "track_active": 0.5,
	},
	&"k_sweep": {
		"id": &"k_sweep", "name": "Swallow Sweep", "kind": &"ability", "type": &"sweep", "anim": &"sweep",
		"startup": 26, "active": 5, "recovery": 24, "damage": 11, "posture": 16, "knockback": 0.8,
		"range": 2.6, "arc": 150, "lunge": 1.4, "unblockable": true, "jumpable": true, "counter": &"sweep",
	},
	# --- counter follow-up ---
	&"k_lunge": {
		"id": &"k_lunge", "name": "Counter Lunge", "kind": &"light", "type": &"slash", "anim": &"drawCut",
		"special": &"counterLunge", "startup": 6, "active": 3, "recovery": 18, "damage": 10, "posture": 22,
		"knockback": 0.8, "range": 2.2, "arc": 100, "lunge": 0, "lunge_end": 8, "trail": &"ult",
	},
}


## KATANA
static func build() -> WeaponDef:
	return WeaponDef.from_dict({
		"id": &"katana",
		"name": "Katana",
		"cls": &"medium",
		"speed_mult": 1.0,
		"dodge_mult": 1.0,
		"parry_window": 9,
		"block_mitigation": 0.7,
		"moves": AttackDef.finalize_moves(MOVES),
		"light_start": &"k_l1",
		"heavy_start": &"k_iai",
		"sprint_light": &"k_sl",
		"sprint_heavy": &"k_sh",
		"dodge_light": &"k_dl",
		"dodge_heavy": &"k_dh",
		"back_light": &"k_bl",
		"back_heavy": &"k_bh",
		"jump_light": &"k_jl",
		"jump_heavy": &"k_jh",
		"abilities": [&"k_flash", &"k_thrust", &"k_sweep"],
		"default_abilities": [&"k_flash", &"k_thrust"],
		"ultimate": &"moonsplitter",
		"reach": 2.1,
		"duel_distance": 2.5,
		"blurb": "Balanced and versatile. Flash parries with a wide window and stuns.",
		# the blade from the habaki to the point, curving off the straight line
		# by up to 3 cm; 1.4 cm thick at the habaki and 7 mm along the blade
		"blade": StrikeSegment.make(V3.make(0.001, 0.09, 0.0), V3.make(-0.077, 0.777, 0.0), 0.015),
		"foot": null,
		# the left hand below the right on the long handle
		"off_hand_grip": V3.make(0.0, -0.15, 0.0),
	})
