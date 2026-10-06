class_name SoundBank
extends RefCounted
## The event-to-sound table: which sounds each rules event plays, how loud,
## how much the pitch varies, on which bus and whether in 3D.
##
## Data and pure functions only. [SoundPlayer] calls [method cues_for] with
## each event the rules emit and plays the returned cues, each described by
## [constant CUES]. Replacing a sound means replacing its file and, if the
## name changes, its entry here.
##
## Events are dictionaries shaped like the web demo's (v0.1-web-mvp:src/sim/events.ts):
## [code]{"t": "hit", "heavy": true, "sound": "colossal", ...}[/code].

const SFX_DIR := "res://assets/audio/sfx/"

## Buses, as laid out in res://default_bus_layout.tres.
const BUS_COMBAT := &"Combat"
const BUS_FOLEY := &"Foley"
const BUS_UI := &"UI"
const BUS_AMBIENCE := &"Ambience"
const BUS_MUSIC := &"Music"
const BUSES: Array[StringName] = [BUS_COMBAT, BUS_FOLEY, BUS_UI, BUS_AMBIENCE, BUS_MUSIC]

## Every cue: a pool of variation files (one is picked at random each time),
## its level in dB, the range of its random pitch scale, its bus, and whether
## it plays in 3D at the event's position ([code]spatial[/code]) or flat.
## [code]loop[/code] marks the ambience bed.
const CUES: Dictionary = {
	# --- swings
	&"whoosh_light": {
		"files": ["whoosh_light_01.wav", "whoosh_light_02.wav", "whoosh_light_03.wav", "whoosh_light_04.wav"],
		"volume_db": -7.0, "pitch": Vector2(0.94, 1.08), "bus": BUS_COMBAT, "spatial": true,
	},
	&"whoosh_heavy": {
		"files": ["whoosh_heavy_01.wav", "whoosh_heavy_02.wav", "whoosh_heavy_03.wav"],
		"volume_db": -5.0, "pitch": Vector2(0.93, 1.05), "bus": BUS_COMBAT, "spatial": true,
	},
	&"whoosh_small": {
		"files": ["whoosh_small_01.wav", "whoosh_small_02.wav", "whoosh_small_03.wav"],
		"volume_db": -8.0, "pitch": Vector2(0.95, 1.12), "bus": BUS_COMBAT, "spatial": true,
	},
	&"whoosh_colossal": {
		"files": ["whoosh_colossal_01.wav", "whoosh_colossal_02.wav", "whoosh_colossal_03.wav"],
		"volume_db": -4.0, "pitch": Vector2(0.92, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	# --- hits
	&"hit_blade": {
		"files": ["hit_blade_01.wav", "hit_blade_02.wav", "hit_blade_03.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.94, 1.06), "bus": BUS_COMBAT, "spatial": true,
	},
	&"hit_blade_heavy": {
		"files": ["hit_blade_heavy_01.wav", "hit_blade_heavy_02.wav"],
		"volume_db": -1.0, "pitch": Vector2(0.94, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"hit_dagger": {
		"files": ["hit_dagger_01.wav", "hit_dagger_02.wav", "hit_dagger_03.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.95, 1.1), "bus": BUS_COMBAT, "spatial": true,
	},
	&"hit_fist": {
		"files": ["hit_fist_01.wav", "hit_fist_02.wav", "hit_fist_03.wav", "hit_fist_04.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.93, 1.07), "bus": BUS_COMBAT, "spatial": true,
	},
	&"hit_fist_heavy": {
		"files": ["hit_fist_heavy_01.wav", "hit_fist_01.wav", "hit_fist_03.wav"],
		"volume_db": -1.0, "pitch": Vector2(0.85, 0.95), "bus": BUS_COMBAT, "spatial": true,
	},
	&"hit_colossal": {
		"files": ["hit_colossal_01.wav", "hit_colossal_02.wav", "hit_colossal_03.wav", "hit_colossal_04.wav"],
		"volume_db": 0.0, "pitch": Vector2(0.94, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"crunch": {
		"files": ["crunch_01.wav", "crunch_02.wav", "crunch_03.wav", "gen_bone_crunch_01.wav", "gen_bone_crunch_02.wav"],
		"volume_db": -5.0, "pitch": Vector2(0.9, 1.08), "bus": BUS_COMBAT, "spatial": true,
	},
	# the flesh layer under every blade hit, hit_blade being the cut alone
	# (milestone-1 task 36)
	&"hit_flesh": {
		"files": ["hit_flesh_01.wav", "hit_flesh_02.wav", "hit_flesh_03.wav", "hit_flesh_04.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.92, 1.08), "bus": BUS_COMBAT, "spatial": true,
	},
	# --- blocks and parries
	&"clang_light": {
		"files": ["clang_light_01.wav", "clang_light_02.wav", "clang_light_03.wav", "clang_light_04.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.95, 1.08), "bus": BUS_COMBAT, "spatial": true,
	},
	&"clang_heavy": {
		"files": ["clang_heavy_01.wav", "clang_heavy_02.wav", "clang_heavy_03.wav", "clang_heavy_04.wav"],
		"volume_db": -1.0, "pitch": Vector2(0.94, 1.05), "bus": BUS_COMBAT, "spatial": true,
	},
	&"parry_contact": {
		"files": ["parry_contact_01.wav", "parry_contact_02.wav", "parry_contact_03.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.97, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	# by the pair of weapons that meet (milestone-1 task 36): the Katana on
	# the Katana, then bare hands against the Katana
	&"clang_katana": {
		"files": ["clang_katana_01.wav", "clang_katana_02.wav", "clang_katana_03.wav", "clang_katana_04.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.96, 1.06), "bus": BUS_COMBAT, "spatial": true,
	},
	&"clang_katana_heavy": {
		"files": ["clang_katana_heavy_01.wav", "clang_katana_heavy_02.wav", "clang_katana_heavy_03.wav"],
		"volume_db": 0.0, "pitch": Vector2(0.95, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"parry_contact_katana": {
		"files": ["parry_contact_katana_01.wav", "parry_contact_katana_02.wav", "parry_contact_katana_03.wav"],
		"volume_db": -1.5, "pitch": Vector2(0.97, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"clang_fist": {
		"files": ["clang_fist_01.wav", "clang_fist_02.wav", "clang_fist_03.wav"],
		"volume_db": 0.0, "pitch": Vector2(0.93, 1.06), "bus": BUS_COMBAT, "spatial": true,
	},
	&"redirect_arm": {
		"files": ["redirect_arm_01.wav", "redirect_arm_02.wav", "redirect_arm_03.wav"],
		"volume_db": -1.0, "pitch": Vector2(0.94, 1.07), "bus": BUS_COMBAT, "spatial": true,
	},
	&"parry_ring": {
		"files": ["gen_parry_ring_01.wav", "gen_parry_ring_02.wav", "gen_parry_ring_03.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.98, 1.02), "bus": BUS_COMBAT, "spatial": false,
	},
	&"parry_flash": {
		"files": ["gen_parry_flash.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.98, 1.02), "bus": BUS_COMBAT, "spatial": false,
	},
	&"parry_redirect": {
		"files": ["gen_parry_redirect.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.96, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"disarm_sting": {
		"files": ["gen_disarm_sting.wav"],
		"volume_db": -1.0, "pitch": Vector2(0.98, 1.02), "bus": BUS_COMBAT, "spatial": false,
	},
	&"stagger": {
		"files": ["gen_stagger.wav"],
		"volume_db": -5.0, "pitch": Vector2(0.96, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"telegraph": {
		"files": ["gen_telegraph.wav"],
		"volume_db": -2.0, "pitch": Vector2(1.0, 1.0), "bus": BUS_COMBAT, "spatial": false,
	},
	# --- ultimates
	&"ult_ready": {
		"files": ["gen_ult_ready.wav"],
		"volume_db": -6.0, "pitch": Vector2(1.0, 1.0), "bus": BUS_COMBAT, "spatial": false,
	},
	&"ult_start": {
		"files": ["gen_ult_start.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.99, 1.01), "bus": BUS_COMBAT, "spatial": true,
	},
	&"ult_wave": {
		"files": ["ult_wave_01.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.97, 1.03), "bus": BUS_COMBAT, "spatial": true,
	},
	&"ult_dash": {
		"files": ["ult_dash_01.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.95, 1.05), "bus": BUS_COMBAT, "spatial": true,
	},
	&"lightning": {
		"files": ["lightning_01.wav", "lightning_02.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.95, 1.05), "bus": BUS_COMBAT, "spatial": true,
	},
	&"lightning_zap": {
		"files": ["gen_lightning_zap.wav"],
		"volume_db": -8.0, "pitch": Vector2(0.9, 1.1), "bus": BUS_COMBAT, "spatial": true,
	},
	&"boom": {
		"files": ["boom_01.wav", "boom_02.wav", "boom_03.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.96, 1.02), "bus": BUS_COMBAT, "spatial": false,
	},
	# --- weapons on the ground
	&"weapon_bounce": {
		"files": ["weapon_bounce_01.wav", "weapon_bounce_02.wav", "weapon_bounce_03.wav"],
		"volume_db": -6.0, "pitch": Vector2(0.9, 1.1), "bus": BUS_FOLEY, "spatial": true,
	},
	&"weapon_clatter": {
		"files": ["weapon_clatter_01.wav", "weapon_clatter_02.wav", "weapon_clatter_03.wav"],
		"volume_db": -8.0, "pitch": Vector2(0.94, 1.06), "bus": BUS_FOLEY, "spatial": true,
	},
	&"pickup": {
		"files": ["gen_pickup.wav"],
		"volume_db": -7.0, "pitch": Vector2(0.97, 1.03), "bus": BUS_FOLEY, "spatial": true,
	},
	&"recall": {
		"files": ["gen_recall.wav"],
		"volume_db": -5.0, "pitch": Vector2(1.0, 1.0), "bus": BUS_COMBAT, "spatial": true,
	},
	# --- movement
	&"dodge_swish": {
		"files": ["gen_dodge_01.wav", "gen_dodge_02.wav", "gen_dodge_03.wav"],
		"volume_db": -9.0, "pitch": Vector2(0.92, 1.1), "bus": BUS_FOLEY, "spatial": true,
	},
	&"dodge_cloth": {
		"files": ["dodge_cloth_01.wav", "dodge_cloth_02.wav", "dodge_cloth_03.wav"],
		"volume_db": -12.0, "pitch": Vector2(0.94, 1.08), "bus": BUS_FOLEY, "spatial": true,
	},
	# a roll: a cloth tumble and a thump on the stone (authored-animation task 30)
	&"roll": {
		"files": ["roll_01.wav", "roll_02.wav", "roll_03.wav"],
		"volume_db": -10.0, "pitch": Vector2(0.94, 1.06), "bus": BUS_FOLEY, "spatial": true,
	},
	&"step_scuff": {
		"files": ["gen_step_scuff_01.wav", "gen_step_scuff_02.wav"],
		"volume_db": -13.0, "pitch": Vector2(0.9, 1.1), "bus": BUS_FOLEY, "spatial": true,
	},
	&"footstep": {
		"files": [
			"gen_footstep_stone_01.wav", "gen_footstep_stone_02.wav", "gen_footstep_stone_03.wav",
			"gen_footstep_stone_04.wav", "gen_footstep_stone_05.wav", "gen_footstep_stone_06.wav",
		],
		"volume_db": -16.0, "pitch": Vector2(0.92, 1.08), "bus": BUS_FOLEY, "spatial": true,
	},
	&"land": {
		"files": ["gen_land_01.wav", "gen_land_02.wav"],
		"volume_db": -8.0, "pitch": Vector2(0.92, 1.06), "bus": BUS_FOLEY, "spatial": true,
	},
	&"body_fall": {
		"files": ["gen_body_fall.wav", "body_drop_01.wav", "body_drop_02.wav"],
		"volume_db": -4.0, "pitch": Vector2(0.94, 1.04), "bus": BUS_FOLEY, "spatial": true,
	},
	# --- the Hunter's own cloth and gear (milestone-1 task 36; see FOLEY)
	&"hunter_cloth_step": {
		"files": ["hunter_cloth_step_01.wav", "hunter_cloth_step_02.wav", "hunter_cloth_step_03.wav", "hunter_cloth_step_04.wav"],
		"volume_db": -9.0, "pitch": Vector2(0.92, 1.1), "bus": BUS_FOLEY, "spatial": true,
	},
	&"hunter_gear_tick": {
		"files": ["gen_hunter_gear_tick_01.wav", "gen_hunter_gear_tick_02.wav", "gen_hunter_gear_tick_03.wav", "gen_hunter_gear_tick_04.wav"],
		"volume_db": -15.0, "pitch": Vector2(0.92, 1.1), "bus": BUS_FOLEY, "spatial": true,
	},
	&"hunter_cloth_swing": {
		"files": ["hunter_cloth_swing_01.wav", "hunter_cloth_swing_02.wav", "hunter_cloth_swing_03.wav"],
		"volume_db": -11.0, "pitch": Vector2(0.94, 1.08), "bus": BUS_FOLEY, "spatial": true,
	},
	&"hunter_creak": {
		"files": ["gen_hunter_creak_01.wav", "gen_hunter_creak_02.wav", "gen_hunter_creak_03.wav"],
		"volume_db": -7.0, "pitch": Vector2(0.9, 1.1), "bus": BUS_FOLEY, "spatial": true,
	},
	&"hunter_cloth_dodge": {
		"files": ["hunter_cloth_dodge_01.wav", "hunter_cloth_dodge_02.wav", "hunter_cloth_dodge_03.wav"],
		"volume_db": -8.0, "pitch": Vector2(0.94, 1.08), "bus": BUS_FOLEY, "spatial": true,
	},
	&"hunter_gear_rattle": {
		"files": ["gen_hunter_gear_rattle_01.wav", "gen_hunter_gear_rattle_02.wav", "gen_hunter_gear_rattle_03.wav"],
		"volume_db": -11.0, "pitch": Vector2(0.94, 1.06), "bus": BUS_FOLEY, "spatial": true,
	},
	# --- effort vocals (milestone-1 task 114; see VOCALS): placeholders until a
	# vocals pack is bought, the kiai and breaths cut from the bundle's male
	# recordings, the pain and death cries generated
	&"vocal_kiai": {
		"files": ["vocal_kiai_01.wav", "vocal_kiai_02.wav", "vocal_kiai_03.wav", "vocal_kiai_04.wav"],
		"volume_db": -4.0, "pitch": Vector2(0.96, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"vocal_exhale": {
		"files": ["vocal_exhale_01.wav", "vocal_exhale_02.wav", "vocal_exhale_03.wav", "vocal_exhale_04.wav"],
		"volume_db": -9.0, "pitch": Vector2(0.95, 1.05), "bus": BUS_COMBAT, "spatial": true,
	},
	&"vocal_breath": {
		"files": ["vocal_breath_01.wav", "vocal_breath_02.wav", "vocal_breath_03.wav"],
		"volume_db": -10.0, "pitch": Vector2(0.95, 1.05), "bus": BUS_COMBAT, "spatial": true,
	},
	&"vocal_pain": {
		"files": ["gen_pain_01.wav", "gen_pain_02.wav", "gen_pain_03.wav", "gen_pain_04.wav"],
		"volume_db": -6.0, "pitch": Vector2(0.95, 1.06), "bus": BUS_COMBAT, "spatial": true,
	},
	&"vocal_pain_heavy": {
		"files": ["gen_pain_heavy_01.wav", "gen_pain_heavy_02.wav", "gen_pain_heavy_03.wav"],
		"volume_db": -4.0, "pitch": Vector2(0.96, 1.04), "bus": BUS_COMBAT, "spatial": true,
	},
	&"vocal_death": {
		"files": ["gen_death_01.wav", "gen_death_02.wav", "gen_death_03.wav"],
		"volume_db": -3.0, "pitch": Vector2(0.97, 1.03), "bus": BUS_COMBAT, "spatial": true,
	},
	# --- match calls
	&"taiko_light": {
		"files": ["gen_taiko_light_01.wav", "gen_taiko_light_02.wav"],
		"volume_db": -5.0, "pitch": Vector2(0.97, 1.03), "bus": BUS_COMBAT, "spatial": false,
	},
	&"taiko_heavy": {
		"files": ["gen_taiko_heavy_01.wav", "gen_taiko_heavy_02.wav"],
		"volume_db": -2.0, "pitch": Vector2(0.97, 1.03), "bus": BUS_COMBAT, "spatial": false,
	},
	&"gong": {
		"files": ["gen_gong.wav"],
		"volume_db": -5.0, "pitch": Vector2(0.99, 1.01), "bus": BUS_COMBAT, "spatial": false,
	},
	&"round_roll": {
		"files": ["gen_round_roll.wav"],
		"volume_db": -4.0, "pitch": Vector2(1.0, 1.0), "bus": BUS_COMBAT, "spatial": false,
	},
	&"fight_call": {
		"files": ["gen_fight.wav"],
		"volume_db": -2.0, "pitch": Vector2(1.0, 1.0), "bus": BUS_COMBAT, "spatial": false,
	},
	# --- menus
	&"ui_move": {
		"files": ["ui_move_01.wav", "ui_move_02.wav", "ui_move_03.wav"],
		"volume_db": -8.0, "pitch": Vector2(0.96, 1.06), "bus": BUS_UI, "spatial": false,
	},
	&"ui_select": {
		"files": ["ui_select_01.wav", "ui_select_02.wav"],
		"volume_db": -6.0, "pitch": Vector2(0.98, 1.03), "bus": BUS_UI, "spatial": false,
	},
	&"ui_confirm": {
		"files": ["ui_confirm_01.wav"],
		"volume_db": -4.0, "pitch": Vector2(1.0, 1.0), "bus": BUS_UI, "spatial": false,
	},
	&"ui_back": {
		"files": ["ui_back_01.wav", "ui_back_02.wav"],
		"volume_db": -7.0, "pitch": Vector2(0.97, 1.03), "bus": BUS_UI, "spatial": false,
	},
	# --- arena bed
	&"ambience_shrine": {
		"files": ["amb_shrine_loop.wav"],
		"volume_db": -12.0, "pitch": Vector2(1.0, 1.0), "bus": BUS_AMBIENCE, "spatial": false, "loop": true,
	},
}

## Every rules event type (the web demo's event list) and the menu events,
## each with the cues it plays when its fields don't pick others (see
## [method cues_for]). An empty list means the event is deliberately silent:
## its moment is already heard through another event, or shown only on screen.
const EVENTS: Dictionary = {
	&"swing": [&"whoosh_light"],
	&"telegraph": [&"telegraph"],
	&"hit": [&"hit_blade"],
	&"block": [&"clang_light"],
	&"parry": [&"parry_contact", &"parry_ring"],
	&"counter": [&"taiko_light"],
	&"evade": [], # the dodge that caused it already swished
	&"disarm": [&"disarm_sting", &"clang_heavy"],
	&"stagger": [&"stagger"],
	&"dodge": [&"dodge_swish", &"dodge_cloth"], # a backstep's; a roll's is the roll (cues_for)
	&"jump": [&"step_scuff"],
	&"land": [&"land"],
	&"step": [&"step_scuff"],
	&"ko": [&"taiko_heavy", &"gong", &"boom", &"body_fall"],
	&"ultReady": [&"ult_ready"],
	&"ultStart": [&"ult_start"],
	&"ultChoice": [&"ult_start"],
	&"ultWave": [&"ult_wave"],
	&"ultDash": [&"ult_dash"],
	&"ultImpale": [&"hit_blade_heavy", &"hit_flesh", &"crunch"],
	&"ultBurst": [&"boom", &"taiko_heavy"],
	&"ultLightning": [&"lightning", &"lightning_zap"],
	&"recall": [&"recall"],
	&"pickup": [&"pickup"],
	&"recallBurst": [&"boom"], # the recall's power-up burst (task 30b)
	# a disarmed weapon sticking in the ground (milestone-1 task 86): the
	# retired bounce's fast landing, until task 91 gives it its own sound
	&"weaponStuck": [&"weapon_bounce", &"weapon_clatter"],
	&"counterReady": [], # shown by a flash; the counter itself is loud
	&"backstabReady": [], # shown by a prompt
	&"roundStart": [&"round_roll", &"gong"],
	&"fight": [&"fight_call"],
	&"roundOver": [], # the KO already rang
	&"matchOver": [], # the music director takes over
	&"whiff": [], # the swing already whooshed
	&"ui_move": [&"ui_move"],
	&"ui_select": [&"ui_select"],
	&"ui_confirm": [&"ui_confirm"],
	&"ui_back": [&"ui_back"],
}

## Seconds after the event at which a cue in an event's list starts, where it
## isn't at once (the demo's timings: the KO gong 0.1 s after the drum, the
## counter's taiko 30 ms after the impact, the round gong on the roll's last
## stroke; the body fall is a guess until the knockdown clip is in).
const DELAYS: Dictionary = {
	&"ko": {&"gong": 0.1, &"body_fall": 0.6},
	&"counter": {&"taiko_light": 0.03},
	&"roundStart": {&"gong": 1.34},
}

## The impacts chosen by the pair of weapons that meet (milestone-1 task 36),
## keyed by [method pair_key] of the attacker's and the defender's weapon,
## then by outcome: a block light and heavy, and a parry's contact (played
## under its ring). Pairs not listed, and events that name no weapons, keep
## the general clangs until milestone 2 brings their weapons to final quality.
const PAIR_IMPACTS: Dictionary = {
	&"katana+katana": {&"block": &"clang_katana", &"block_heavy": &"clang_katana_heavy", &"parry": &"parry_contact_katana"},
	# a bare hand against the Katana: a fist meets the Katana's guard, and a
	# bare-handed parry turns the blade aside by the arm
	&"fists+katana": {&"block": &"clang_fist", &"block_heavy": &"clang_fist", &"parry": &"clang_fist", &"redirect": &"redirect_arm"},
}

## Each fighter's own cloth and gear (milestone-1 task 36), by fighter id and
## moment: under a footfall (step), with a swing, in a backstep (dodge, in
## place of the general cloth flap), in a roll and on a landing. A fighter not
## listed moves with the general cloth only.
const FOLEY: Dictionary = {
	&"hunter": {
		&"step": [&"hunter_cloth_step", &"hunter_gear_tick"],
		&"swing": [&"hunter_cloth_swing", &"hunter_creak"],
		&"dodge": [&"hunter_cloth_dodge", &"hunter_gear_rattle"],
		&"roll": [&"hunter_gear_rattle"],
		&"land": [&"hunter_cloth_dodge", &"hunter_gear_rattle"],
	},
}

## The voice each fighter speaks with where it isn't [constant DEFAULT_VOICE]
## (milestone-1 task 114).
const VOICES: Dictionary = {}
## Every fighter's voice unless VOICES names another: one male voice for every
## fighter (the owner's choice, Oct 6, 2026), the sides told apart by pitch
## (SIDE_PITCH).
const DEFAULT_VOICE := &"male"
## Each voice's cue for each moment (see [method vocal_moments]): placeholder
## effort vocals until a vocals pack is bought after the spending review.
const VOCALS: Dictionary = {
	&"male": {
		&"kiai": &"vocal_kiai", &"exhale": &"vocal_exhale", &"breath": &"vocal_breath",
		&"pain": &"vocal_pain", &"pain_heavy": &"vocal_pain_heavy", &"death": &"vocal_death",
	},
}
## How often a moment is voiced, where not every time: a light's exhale
## about one in three (the owner's choice, Oct 6, 2026).
const VOCAL_CHANCE: Dictionary = {&"exhale": 1.0 / 3.0}
## How much lower each side's voice is pitched, so that two fighters with the
## same voice can be told apart by ear: the second side about two semitones
## down (the owner's choice, Oct 6, 2026).
const SIDE_PITCH: Array[float] = [1.0, 0.8909]


## The cues to play for one rules event, in order, each as
## [code]{"cue": StringName, "delay": float, "volume_db": float,
## "pitch_scale": float, "chance": float}[/code] where volume_db is added to
## the cue's own level, pitch_scale multiplies its random pitch and chance is
## how likely it is to sound (1 for always). Applies the demo's sub-selection
## rules: the hit sound by the event's [code]sound[/code] field (blade,
## colossal, dagger, fist) and weight, every blade hit adding the flesh layer
## and a heavy the bone; clangs and parries by the pair of weapons that meet
## ([constant PAIR_IMPACTS]) and by weight; whooshes by weight and weapon;
## parries and counters by kind.
## [param cast] names the fighter on each side, by side (fighter ids, as
## [member MatchSide.fighter_id]); with it, a fighter's own cloth and gear
## ([constant FOLEY]) and voice ([constant VOCALS]) join the event's cues.
static func cues_for(event: Dictionary, cast: Array = []) -> Array[Dictionary]:
	var type := StringName(str(_field(event, "t", "")))
	var names: Array[StringName] = []
	var heavy := bool(_field(event, "heavy", false))
	var pair: Dictionary = PAIR_IMPACTS.get(pair_key(_field(event, "weapon", &""), _field(event, "defender_weapon", &"")), {})
	var own: Dictionary = _foley_of(event, cast)
	match type:
		&"swing":
			var weapon := str(_field(event, "weapon", "katana"))
			if weapon == "greatsword":
				names = [&"whoosh_colossal"]
			elif weapon == "daggers" or weapon == "fists":
				names = [&"whoosh_light" if heavy else &"whoosh_small"]
			else:
				names = [&"whoosh_heavy" if heavy else &"whoosh_light"]
			names.append_array(own.get(&"swing", []))
		&"telegraph":
			# The ultimate's warning is heard through its own start sound.
			if str(_field(event, "kind", "")) != "ult":
				names = [&"telegraph"]
		&"hit":
			# the cut, then the flesh under every blade, then the bone under
			# a heavy (the colossal always crunches)
			match str(_field(event, "sound", "blade")):
				"fist":
					names = [&"hit_fist_heavy" if heavy else &"hit_fist"]
				"colossal":
					names = [&"hit_colossal", &"hit_flesh", &"crunch"]
				"dagger":
					names = [&"hit_dagger", &"hit_flesh"]
				_:
					names = [&"hit_blade_heavy" if heavy else &"hit_blade", &"hit_flesh"]
			if heavy and names.has(&"hit_flesh") and not names.has(&"crunch"):
				names.append(&"crunch")
		&"block":
			names = [pair.get(&"block_heavy" if heavy else &"block", &"clang_heavy" if heavy else &"clang_light")]
		&"parry":
			var contact: StringName = pair.get(&"parry", &"parry_contact")
			match str(_field(event, "kind", "parry")):
				"flash":
					names = [contact, &"parry_flash"]
				"redirect":
					names = [&"parry_redirect"]
					if pair.has(&"redirect"):
						names.append(pair[&"redirect"])
				_:
					names = [contact, &"parry_ring"]
		&"dodge":
			# the backstep keeps the dash's whoosh; a roll tumbles (task 30);
			# a fighter's own coat takes the general cloth flap's place
			if bool(_field(event, "back", false)):
				names = [&"dodge_swish"]
				if own.has(&"dodge"):
					names.append_array(own[&"dodge"])
				else:
					names.append(&"dodge_cloth")
			else:
				names = [&"roll"]
				names.append_array(own.get(&"roll", []))
		&"land":
			names = [&"land"]
			names.append_array(own.get(&"land", []))
		&"counter":
			match str(_field(event, "kind", "")):
				"stomp":
					names = [&"crunch", &"clang_heavy", &"taiko_light"]
				"leap":
					names = [&"hit_fist_heavy", &"taiko_light"]
				"evade":
					names = [&"dodge_swish", &"taiko_light"]
				_:
					names = [&"taiko_light"]
		_:
			if not EVENTS.has(type):
				return []
			names.assign(EVENTS[type])
	var delays: Dictionary = DELAYS.get(type, {})
	var out: Array[Dictionary] = []
	for cue_name: StringName in names:
		out.append(_cue(cue_name, float(delays.get(cue_name, 0.0))))
	# the fighters' voices (task 114)
	for m: Dictionary in vocal_moments(event):
		var side: int = m["side"]
		var voice: Dictionary = VOCALS.get(voice_of(_fighter(cast, side)), {})
		if voice.has(m["moment"]):
			var cue := _cue(voice[m["moment"]], 0.0, m["chance"])
			cue["pitch_scale"] = SIDE_PITCH[side] if side < SIDE_PITCH.size() else 1.0
			out.append(cue)
	return out


## The cues of a footfall by [param fighter_id]: the stone footstep and the
## fighter's own cloth and gear ([constant FOLEY]).
static func footfall_cues(fighter_id: StringName) -> Array[StringName]:
	var names: Array[StringName] = [&"footstep"]
	names.append_array(FOLEY.get(fighter_id, {}).get(&"step", []))
	return names


## Where an event gives a fighter's effort vocals their hooks (task 114),
## each [code]{"moment": StringName, "side": int, "chance": float}[/code]: a
## kiai on a heavy swing (abilities and ultimates count) and an exhale on a
## light one; a breath on a dodge or a landing; pain on being hit, more on a
## heavy; a death cry on a K.O. (both on a double K.O.). A block is silent.
static func vocal_moments(event: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var heavy := bool(_field(event, "heavy", false))
	match StringName(str(_field(event, "t", ""))):
		&"swing":
			out.append(_moment(&"kiai" if heavy else &"exhale", int(_field(event, "f", -1))))
		&"dodge", &"land":
			out.append(_moment(&"breath", int(_field(event, "f", -1))))
		&"hit":
			out.append(_moment(&"pain_heavy" if heavy else &"pain", int(_field(event, "target", -1))))
		&"ko":
			var loser := int(_field(event, "loser", -1))
			for side: int in ([0, 1] if loser < 0 else [loser]):
				out.append(_moment(&"death", side))
	# an event that names no fighter gives nobody a voice
	var named: Array[Dictionary] = []
	named.assign(out.filter(func(m: Dictionary) -> bool: return int(m["side"]) >= 0))
	return named


## The voice [param fighter_id] speaks with, none for nobody (&"").
static func voice_of(fighter_id: StringName) -> StringName:
	if fighter_id.is_empty():
		return &""
	return VOICES.get(fighter_id, DEFAULT_VOICE)


## True for a cue that is a fighter's voice (VOCALS).
static func is_vocal(cue_name: StringName) -> bool:
	for voice: StringName in VOCALS:
		if (VOCALS[voice] as Dictionary).values().has(cue_name):
			return true
	return false


## The key of the pair of weapons [param a] and [param b] meet as, the same
## whichever side holds which: "fists+katana".
static func pair_key(a: Variant, b: Variant) -> StringName:
	var ids: Array[String] = [str(a), str(b)]
	ids.sort()
	return StringName("+".join(ids))


static func _cue(cue_name: StringName, delay: float = 0.0, chance: float = 1.0) -> Dictionary:
	return {"cue": cue_name, "delay": delay, "volume_db": 0.0, "pitch_scale": 1.0, "chance": chance}


static func _moment(moment: StringName, side: int) -> Dictionary:
	return {"moment": moment, "side": side, "chance": float(VOCAL_CHANCE.get(moment, 1.0))}


static func _fighter(cast: Array, side: int) -> StringName:
	return StringName(cast[side]) if side >= 0 and side < cast.size() else &""


## The [constant FOLEY] of the fighter an event names by its "f" field.
static func _foley_of(event: Dictionary, cast: Array) -> Dictionary:
	if cast.is_empty() or not (event.has("f") or event.has(&"f")):
		return {}
	return FOLEY.get(_fighter(cast, int(_field(event, "f", -1))), {})


## The resource path of every file a cue can play.
static func paths_for(cue_name: StringName) -> PackedStringArray:
	var paths := PackedStringArray()
	for file: String in CUES[cue_name]["files"]:
		paths.append(SFX_DIR + file)
	return paths


## Picks one variation's path at random, avoiding the one played last time
## ([param last] is its index, or -1). Returns [code][path, index][/code].
static func pick_variation(cue_name: StringName, rng: RandomNumberGenerator, last: int = -1) -> Array:
	var files: Array = CUES[cue_name]["files"]
	var index := rng.randi_range(0, files.size() - 1)
	if files.size() > 1 and index == last:
		index = (index + 1 + rng.randi_range(0, files.size() - 2)) % files.size()
	return [SFX_DIR + str(files[index]), index]


## A random pitch scale within the cue's range.
static func random_pitch(cue_name: StringName, rng: RandomNumberGenerator) -> float:
	var range_: Vector2 = CUES[cue_name]["pitch"]
	return rng.randf_range(range_.x, range_.y)


## Every cue name any event can produce, for checks and preloading.
static func all_event_cues() -> Array[StringName]:
	var seen: Array[StringName] = []
	for type: StringName in EVENTS:
		for cue_name: StringName in EVENTS[type]:
			if not seen.has(cue_name):
				seen.append(cue_name)
	return seen


## Reads a field whether the event uses String or StringName keys.
static func _field(event: Dictionary, key: String, fallback: Variant) -> Variant:
	if event.has(key):
		return event[key]
	var sn := StringName(key)
	if event.has(sn):
		return event[sn]
	return fallback
