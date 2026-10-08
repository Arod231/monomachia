class_name KatanaMoves
extends RefCounted
## Port of v0.1-web-mvp:src/sim/moves/katana.ts.
##
## Katana — medium class. Balanced, versatile, decent speed.

const MOVES: Dictionary = {
	&"k_l1": {
		"id": &"k_l1", "name": "Right Cut", "kind": &"light", "type": &"slash", "anim": &"slashRL",
		"side_start": &"right", "side_end": &"left",
		"damage": 5, "posture": 5, "knockback": 0.35,
		"range": 2.2, "arc": 110, "lunge": 0.35, "lunge_end": 13, "chain_light": &"k_l2", "chain_heavy": &"k_h2",
	},
	&"k_l2": {
		"id": &"k_l2", "name": "Return Cut", "kind": &"light", "type": &"slash", "anim": &"slashLR",
		"side_start": &"left", "side_end": &"right",
		"damage": 5, "posture": 5, "knockback": 0.35,
		"range": 2.2, "arc": 110, "lunge": 0.45, "lunge_end": 11, "chain_light": &"k_l3", "chain_heavy": &"k_h1f",
	},
	&"k_l3": {
		"id": &"k_l3", "name": "Kesa Cut", "kind": &"light", "type": &"slash", "anim": &"diagDown",
		"side_start": &"right", "side_end": &"left",
		"damage": 6, "posture": 6, "knockback": 0.4,
		"range": 2.2, "arc": 100, "lunge": 0.4, "lunge_end": 14, "chain_light": &"k_l4", "chain_heavy": &"k_h2",
	},
	&"k_l4": {
		"id": &"k_l4", "name": "Crown Cut", "kind": &"light", "type": &"overhead", "anim": &"overhead",
		"side_start": &"centre", "side_end": &"centre",
		"damage": 7, "posture": 7, "knockback": 0.6,
		"range": 2.3, "arc": 60, "lunge": 0.7, "lunge_end": 15,
	},
	# the one-handed string's own hits (KE tasks 11 and 12), Elden Ring's,
	# keyed one-handed from the pack's one-handed attacks: today's lights'
	# damage and posture, the two-handed hits about 15% more (D3); each
	# chains to the string's next hit and branches to the grip's heavy
	&"k_1l1": {
		"id": &"k_1l1", "name": "Slanting Cut", "kind": &"light", "type": &"slash", "anim": &"diagDown",
		"side_start": &"right", "side_end": &"left", "grip": &"one_handed",
		"damage": 5, "posture": 5, "knockback": 0.35,
		"range": 2.2, "arc": 100, "chain_light": &"k_1l2", "chain_heavy": &"k_coil",
	},
	&"k_1l2": {
		"id": &"k_1l2", "name": "Backhand Rise", "kind": &"light", "type": &"slash", "anim": &"diagUp",
		"side_start": &"left", "side_end": &"right", "grip": &"one_handed",
		"damage": 5, "posture": 5, "knockback": 0.35,
		"range": 2.2, "arc": 110, "chain_light": &"k_1l3", "chain_heavy": &"k_coil",
	},
	&"k_1l3": {
		"id": &"k_1l3", "name": "Twisting Rise", "kind": &"light", "type": &"slash", "anim": &"diagUp",
		"side_start": &"right", "side_end": &"left", "grip": &"one_handed",
		"damage": 6, "posture": 6, "knockback": 0.4,
		"range": 2.2, "arc": 110, "chain_light": &"k_1l4", "chain_heavy": &"k_coil",
	},
	&"k_1l4": {
		"id": &"k_1l4", "name": "Level Cut", "kind": &"light", "type": &"slash", "anim": &"slashLR",
		"side_start": &"left", "side_end": &"right", "grip": &"one_handed",
		"damage": 7, "posture": 7, "knockback": 0.4,
		"range": 2.2, "arc": 120, "chain_light": &"k_1l5", "chain_heavy": &"k_coil",
	},
	# the last hit commits (D16): no light follow-up, and the grip's heavy only
	# late in the long recovery out of its crouch; the off hand joins the grip
	# for the cut
	&"k_1l5": {
		"id": &"k_1l5", "name": "Crouching Crown", "kind": &"light", "type": &"overhead", "anim": &"overhead",
		"side_start": &"centre", "side_end": &"centre", "grip": &"one_handed",
		"damage": 9, "posture": 9, "knockback": 0.8,
		"range": 2.3, "arc": 60, "chain_heavy": &"k_coil",
	},
	# the two-handed string's own hits (KE task 13), Elden Ring's, tighter and
	# quicker than the one-handed string's, about 15% more damage (D3); each
	# chains to the string's next hit and branches to the grip's heavy
	&"k_2l1": {
		"id": &"k_2l1", "name": "Heavy Slant", "kind": &"light", "type": &"slash", "anim": &"diagDown",
		"side_start": &"right", "side_end": &"left", "grip": &"two_handed",
		"damage": 6, "posture": 6, "knockback": 0.35,
		"range": 2.2, "arc": 100, "chain_light": &"k_2l2", "chain_heavy": &"k_h2",
	},
	&"k_2l2": {
		"id": &"k_2l2", "name": "Left Rise", "kind": &"light", "type": &"slash", "anim": &"diagUp",
		"side_start": &"left", "side_end": &"right", "grip": &"two_handed",
		"damage": 6, "posture": 6, "knockback": 0.35,
		"range": 2.2, "arc": 110, "chain_light": &"k_l3", "chain_heavy": &"k_h2",
	},
	# the heavy: sheathe for 9 frames (up to the fighter's charge check,
	# CHARGE_CHECK_FRAME: held, the stance is the charge, walked in at the
	# blocking walk's speed), then draw in 14, lunging only once the sheathe ends
	&"k_iai": {
		"id": &"k_iai", "name": "Iai Slash (vertical)", "kind": &"heavy", "type": &"overhead", "anim": &"iaiVertical",
		"side_start": &"left", "side_end": &"right",
		"damage": 13, "posture": 16, "knockback": 1.0,
		"range": 3.6, "arc": 60, "lunge": 2.1, "lunge_start": 9, "lunge_end": 25, "chargeable": true,
		"charge_move": true, "release_variant": &"k_iai_h", "chain_heavy": &"k_h1f",
	},
	# the same sheathe, drawn right to left when the stick is held left or
	# right as the Iai is drawn; it swaps in on the Iai's attack, so it keeps
	# the Iai's frames and lunge, and is never started on its own
	&"k_iai_h": {
		"id": &"k_iai_h", "name": "Iai Slash (horizontal)", "kind": &"heavy", "type": &"slash", "anim": &"iaiHorizontal",
		"side_start": &"right", "side_end": &"left",
		"damage": 13, "posture": 16, "knockback": 1.0,
		"range": 3.6, "arc": 110, "lunge": 2.1, "lunge_start": 9, "lunge_end": 25,
		"chain_light": &"k_2l2", "chain_heavy": &"k_rdraw",
	},
	# Heaven Splitter's follow-up (KE task 7), Elden Ring's (KE task 17): it
	# rises out of the Splitter's settled crouch, the blade drawn back low on
	# the left, and cuts rising up through the front to high on the right; its
	# step comes from its clip. The vertical Iai hands off to the same clip.
	&"k_h1f": {
		"id": &"k_h1f", "name": "Rising Heaven", "kind": &"heavy", "type": &"slash", "anim": &"diagUp",
		"side_start": &"centre", "side_end": &"right",
		"damage": 12, "posture": 15, "knockback": 0.9,
		"range": 2.3, "arc": 90,
	},
	# the horizontal Iai's heavy follow-up, back the other way
	&"k_rdraw": {
		"id": &"k_rdraw", "name": "Returning Draw", "kind": &"heavy", "type": &"slash", "anim": &"slashLR",
		"side_start": &"left", "side_end": &"right",
		"damage": 12, "posture": 15, "knockback": 0.9,
		"range": 2.3, "arc": 110, "lunge": 1.1, "lunge_end": 18,
	},
	# the two-handed heavy (KE task 7), Elden Ring's (KE task 17): the blade
	# raised and held overhead, then cut straight down with a long lunge into
	# a deep crouch; charged by holding heavy (D9), held overhead; Rising
	# Heaven its follow-up once the crouch settles, else a long rise
	&"k_h2": {
		"id": &"k_h2", "name": "Heaven Splitter", "kind": &"heavy", "type": &"overhead", "anim": &"overhead",
		"side_start": &"centre", "side_end": &"centre", "grip": &"two_handed",
		"damage": 15, "posture": 18, "knockback": 1.2,
		"range": 2.4, "arc": 60, "chargeable": true, "chain_heavy": &"k_h1f",
	},
	# the one-handed heavy (KE task 7, D13), Elden Ring's (KE task 16): the
	# blade coiled back over the shoulder, a loop low and up, and a wide level
	# cut from the left held at full extension; charged by holding heavy
	# through the coil (D9), where it holds; about 85% of Heaven Splitter (D3)
	&"k_coil": {
		"id": &"k_coil", "name": "Crescent Coil", "kind": &"heavy", "type": &"slash", "anim": &"slashLR",
		"side_start": &"centre", "side_end": &"right", "grip": &"one_handed",
		"damage": 13, "posture": 15, "knockback": 1.0,
		"range": 2.4, "arc": 120, "chargeable": true,
	},
	&"k_sl": {
		"id": &"k_sl", "name": "Running Draw", "kind": &"light", "type": &"slash", "anim": &"drawCut",
		"damage": 8, "posture": 9, "knockback": 0.5,
		"range": 2.3, "arc": 100, "lunge": 1.7, "lunge_end": 15,
	},
	&"k_sh": {
		"id": &"k_sh", "name": "Leaping Cleave", "kind": &"heavy", "type": &"overhead", "anim": &"leapCleave",
		"damage": 15, "posture": 18, "knockback": 1.2,
		"range": 2.4, "arc": 70, "lunge": 2.9, "lunge_start": 4, "lunge_end": 22, "hop": 5,
	},
	&"k_dl": {
		"id": &"k_dl", "name": "Wind Cut", "kind": &"light", "type": &"slash", "anim": &"slashRL",
		"damage": 6, "posture": 7, "knockback": 0.4,
		"range": 2.2, "arc": 120, "lunge": 0.5,
	},
	&"k_dh": {
		"id": &"k_dh", "name": "Whirl Cut", "kind": &"heavy", "type": &"spin", "anim": &"spin",
		"damage": 12, "posture": 14, "knockback": 1.0,
		"range": 2.3, "arc": 360, "lunge": 0.5,
	},
	&"k_bl": {
		"id": &"k_bl", "name": "Rising Cut", "kind": &"light", "type": &"slash", "anim": &"diagUp",
		"damage": 6, "posture": 8, "knockback": 0.4,
		"range": 2.2, "arc": 100, "lunge": 1.3,
	},
	&"k_bh": {
		"id": &"k_bh", "name": "Lunging Cut", "kind": &"heavy", "type": &"slash", "anim": &"diagDown",
		"damage": 12, "posture": 14, "knockback": 1.0,
		"range": 2.4, "arc": 80, "lunge": 2.3, "lunge_start": 4, "lunge_end": 20,
	},
	&"k_jl": {
		"id": &"k_jl", "name": "Aerial Cut", "kind": &"light", "type": &"slash", "anim": &"airSlash",
		"damage": 6, "posture": 7, "knockback": 0.4,
		"range": 2.1, "arc": 120, "airborne": true,
	},
	&"k_jh": {
		"id": &"k_jh", "name": "Falling Crown", "kind": &"heavy", "type": &"overhead", "anim": &"plunge",
		"damage": 13, "posture": 16, "knockback": 1.0,
		"range": 2.3, "arc": 80, "airborne": true,
	},
	# --- block abilities ---
	&"k_flash": {
		"id": &"k_flash", "name": "Flash", "kind": &"ability", "type": &"slash", "anim": &"flash", "special": &"flash",
		"damage": 0, "posture": 0, "knockback": 0,
		"range": 0, "arc": 0,
	},
	&"k_thrust": {
		"id": &"k_thrust", "name": "Piercing Thrust", "kind": &"ability", "type": &"thrust", "anim": &"thrust",
		"damage": 12, "posture": 16, "knockback": 0.8,
		"range": 3.1, "arc": 36, "lunge": 1.4, "lunge_start": 18, "lunge_end": 30,
		"unblockable": true, "counter": &"thrust", "track_startup": 5, "track_active": 0.5,
	},
	&"k_sweep": {
		"id": &"k_sweep", "name": "Swallow Sweep", "kind": &"ability", "type": &"sweep", "anim": &"sweep",
		"damage": 11, "posture": 16, "knockback": 0.8,
		"range": 2.6, "arc": 150, "lunge": 1.4, "unblockable": true, "jumpable": true, "counter": &"sweep",
	},
	# --- counter follow-up ---
	&"k_lunge": {
		"id": &"k_lunge", "name": "Counter Lunge", "kind": &"light", "type": &"slash", "anim": &"drawCut",
		"special": &"counterLunge", "damage": 10, "posture": 22,
		"knockback": 0.8, "range": 2.2, "arc": 100, "lunge": 0, "lunge_end": 14, "trail": &"ult",
	},
}


## The two-handed string: its own hits 1 and 2 (KE task 13), the stand-ins
## (today's Kesa Cut and Crown Cut, Crown Cut again as hit 5) for hits 3 to 5
## until KE task 14.
const TWO_HANDED_STRING: Array[StringName] = [&"k_2l1", &"k_2l2", &"k_l3", &"k_l4", &"k_l4"]
## The one-handed string's own five hits (KE tasks 11 and 12).
const ONE_HANDED_STRING: Array[StringName] = [&"k_1l1", &"k_1l2", &"k_1l3", &"k_1l4", &"k_1l5"]


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
		"moves": AttackDef.finalize_moves(MOVES, &"katana"),
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
		"reach": 2.8,
		"duel_distance": 3.3,
		"blurb": "Balanced and versatile. Flash parries with a wide window and stuns.",
		# the 1.3 m blade (KE task 2) from the habaki to the point, curving off
		# the straight line by up to 3 cm; 1.4 cm thick at the habaki and 7 mm
		# along the blade
		"blade": StrikeSegment.make(V3.make(0.0015, 0.09, 0.0), V3.make(-0.077, 1.39, 0.0), 0.015),
		"foot": null,
		# the left hand below the right on the long handle
		"off_hand_grip": V3.make(0.0, -0.15, 0.0),
		# Elden Ring's two grips (KE task 5), each with its five-hit string:
		# the one-handed string's own five (KE tasks 11 and 12), the
		# two-handed string's own hits 1 and 2 (KE task 13) and today's Kesa
		# Cut and Crown Cut standing in for the rest until KE task 14; a
		# two-handed block takes less posture (D2). Each hit's heavy branch is the grip's heavy, and the
		# vertical Iai's heavy follow-up the grip's too (KE task 7, D5)
		"grips": [
			WeaponGrip.make(WeaponGrip.ONE_HANDED, ONE_HANDED_STRING, 0.7, &"k_coil", &"k_coil"),
			WeaponGrip.make(WeaponGrip.TWO_HANDED, TWO_HANDED_STRING, 0.5, &"k_h2", &"k_h1f"),
		],
	})
