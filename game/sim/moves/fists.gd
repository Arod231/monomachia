class_name FistsMoves
extends RefCounted
## Port of v0.1-web-mvp:src/sim/moves/fists.ts.
##
## Bare hands — used by any fighter after being disarmed.
## Low HP damage, high posture damage, extra knockback.

const F: StringName = &"fist"
## The movement attacks' hit sounds by the striking limb (milestone-1 task
## 95): an open palm's slap, a knee's dull thud, a kick's or heel drop's
## heavier thump; the eight also smear the air along that limb.
const PALM: StringName = &"palm"
const KNEE: StringName = &"knee"
const KICK: StringName = &"kick"

const MOVES: Dictionary = {
	&"f_l1": {
		"id": &"f_l1", "name": "Jab", "kind": &"light", "type": &"punch", "anim": &"f_jab", "hand": &"L", "sound": F,
		"damage": 3, "posture": 8, "knockback": 0.5,
		"range": 1.3, "arc": 90, "lunge": 0.3, "lunge_end": 6, "chain_light": &"f_l2", "chain_heavy": &"f_h1",
	},
	&"f_l2": {
		"id": &"f_l2", "name": "Cross", "kind": &"light", "type": &"punch", "anim": &"f_cross", "hand": &"R", "sound": F,
		"damage": 3, "posture": 8, "knockback": 0.5,
		"range": 1.3, "arc": 90, "lunge": 0.27, "lunge_end": 7, "chain_light": &"f_l3", "chain_heavy": &"f_h1",
	},
	&"f_l3": {
		"id": &"f_l3", "name": "Hook", "kind": &"light", "type": &"punch", "anim": &"f_hook", "hand": &"L", "sound": F,
		"damage": 4, "posture": 10, "knockback": 0.9,
		"range": 1.3, "arc": 110, "lunge": 0.07, "lunge_end": 9, "chain_heavy": &"f_h1",
	},
	&"f_h1": {
		"id": &"f_h1", "name": "Roundhouse", "kind": &"heavy", "type": &"kick", "anim": &"f_roundhouse", "sound": F,
		"damage": 6, "posture": 16, "knockback": 1.6,
		"range": 1.5, "arc": 110, "lunge": 0.4, "chargeable": true, "chain_heavy": &"f_h2",
	},
	&"f_h2": {
		"id": &"f_h2", "name": "Spinning Heel", "kind": &"heavy", "type": &"kick", "anim": &"f_spinHeel", "sound": F,
		"damage": 7, "posture": 18, "knockback": 2.0,
		"range": 1.5, "arc": 130, "lunge": 0.4,
	},
	&"f_sl": {
		"id": &"f_sl", "name": "Flying Knee", "kind": &"light", "type": &"kick", "anim": &"f_flyingKnee", "sound": KNEE, "smear": true,
		"damage": 6, "posture": 14, "knockback": 1.5,
		"range": 1.3, "arc": 100,
	},
	&"f_sh": {
		"id": &"f_sh", "name": "Dragon Kick", "kind": &"heavy", "type": &"kick", "anim": &"f_dragonKick", "sound": KICK, "smear": true,
		"damage": 9, "posture": 23, "knockback": 2.2,
		"range": 1.5, "arc": 100,
	},
	&"f_dl": {
		"id": &"f_dl", "name": "Slip Jab", "kind": &"light", "type": &"punch", "anim": &"f_jab", "hand": &"L", "sound": F, "smear": true,
		"damage": 4, "posture": 11, "knockback": 0.5,
		"range": 1.3, "arc": 110,
	},
	&"f_dh": {
		"id": &"f_dh", "name": "Spinning Backfist", "kind": &"heavy", "type": &"punch", "anim": &"f_backfist", "hand": &"R", "sound": F, "smear": true,
		"damage": 7, "posture": 18, "knockback": 1.4,
		"range": 1.4, "arc": 150,
	},
	&"f_bl": {
		"id": &"f_bl", "name": "Snap Kick", "kind": &"light", "type": &"kick", "anim": &"f_snapKick", "hand": &"L", "sound": KICK, "smear": true,
		"damage": 4, "posture": 12, "knockback": 1.0,
		"range": 1.5, "arc": 90,
	},
	&"f_bh": {
		"id": &"f_bh", "name": "Lunging Palm", "kind": &"heavy", "type": &"punch", "anim": &"f_palm", "hand": &"R", "sound": PALM, "smear": true,
		"damage": 7, "posture": 21, "knockback": 1.6,
		"range": 1.4, "arc": 90,
	},
	&"f_jl": {
		"id": &"f_jl", "name": "Air Kick", "kind": &"light", "type": &"kick", "anim": &"f_airKick", "sound": KICK, "smear": true,
		"damage": 5, "posture": 12, "knockback": 1.0,
		"range": 1.4, "arc": 110, "airborne": true,
	},
	&"f_jh": {
		"id": &"f_jh", "name": "Axe Kick", "kind": &"heavy", "type": &"kick", "anim": &"f_axeKick", "hand": &"L", "sound": KICK, "smear": true,
		"damage": 8, "posture": 21, "knockback": 1.4,
		"range": 1.5, "arc": 100, "airborne": true,
	},
	&"f_lunge": {
		"id": &"f_lunge", "name": "Counter Lunge", "kind": &"light", "type": &"punch", "anim": &"f_palm", "hand": &"R", "sound": F,
		"special": &"counterLunge", "damage": 6, "posture": 24,
		"knockback": 1.4, "range": 1.4, "arc": 100, "lunge": 0, "lunge_end": 11, "trail": &"ult",
	},
	&"f_breaker": {
		"id": &"f_breaker", "name": "Breaker Palm", "kind": &"ultimate", "type": &"punch", "anim": &"f_breakerPalm", "hand": &"R",
		"sound": F, "special": &"breakerPalm", "damage": 6, "posture": 50,
		"knockback": 1.8, "range": 1.5, "arc": 90, "power": true,
	},
}


## FISTS
static func build() -> WeaponDef:
	return WeaponDef.from_dict({
		"id": &"fists",
		"name": "Bare Hands",
		"cls": &"fists",
		"speed_mult": 1.0,
		"dodge_mult": 1.0,
		"parry_window": 8, # the Redirect counter's timing window
		"block_mitigation": 1,
		"moves": AttackDef.finalize_moves(MOVES, &"fists"),
		"light_start": &"f_l1",
		"heavy_start": &"f_h1",
		"sprint_light": &"f_sl",
		"sprint_heavy": &"f_sh",
		"dodge_light": &"f_dl",
		"dodge_heavy": &"f_dh",
		"back_light": &"f_bl",
		"back_heavy": &"f_bh",
		"jump_light": &"f_jl",
		"jump_heavy": &"f_jh",
		"abilities": [],
		"default_abilities": [&"", &""],
		"ultimate": &"disarmed",
		"reach": 1.45,
		"duel_distance": 1.85,
		"blurb": "Punches and kicks: little damage, heavy posture damage, big knockback.",
		# the fist across the knuckles, from the little finger's to the index
		# finger's, thick enough to cover them on either hand of either fighter
		# (grown by 1.15 with the taller bodies, KE task 3)
		"blade": StrikeSegment.make(V3.make(0.0023, -0.045, 0.0), V3.make(0.024, 0.039, 0.0), 0.087),
		# the foot along the boot, its underside on the sole and its ends at the
		# heel and the toe (grown by 1.15 with the taller bodies, KE task 3)
		"foot": StrikeSegment.make(V3.make(0.033, -0.006, 0.0), V3.make(0.033, 0.23, 0.0), 0.115),
		"off_hand_grip": null,
		# one implicit grip (KE task 5)
		"grips": [],
	})
