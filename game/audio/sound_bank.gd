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
## Events are dictionaries shaped like the web demo's (src/sim/events.ts):
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
	&"dodge": [&"dodge_swish", &"dodge_cloth"],
	&"jump": [&"step_scuff"],
	&"land": [&"land"],
	&"step": [&"step_scuff"],
	&"ko": [&"taiko_heavy", &"gong", &"boom", &"body_fall"],
	&"ultReady": [&"ult_ready"],
	&"ultStart": [&"ult_start"],
	&"ultChoice": [&"ult_start"],
	&"ultWave": [&"ult_wave"],
	&"ultDash": [&"ult_dash"],
	&"ultImpale": [&"hit_blade_heavy", &"crunch"],
	&"ultBurst": [&"boom", &"taiko_heavy"],
	&"ultLightning": [&"lightning", &"lightning_zap"],
	&"recall": [&"recall"],
	&"pickup": [&"pickup"],
	&"weaponBounce": [&"weapon_bounce"],
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

## A dropped weapon's first, fast landing also clatters.
const CLATTER_SPEED := 6.0
## The demo scaled a bounce's loudness by min(1, speed / 8).
const BOUNCE_FULL_SPEED := 8.0


## The cues to play for one rules event, in order, each as
## [code]{"cue": StringName, "delay": float, "volume_db": float}[/code]
## where volume_db is added to the cue's own level. Applies the demo's
## sub-selection rules: the hit sound by the event's [code]sound[/code] field
## (blade, colossal, dagger, fist) and weight; clangs and whooshes by weight
## and weapon; parries and counters by kind; bounces by speed.
static func cues_for(event: Dictionary) -> Array[Dictionary]:
	var type := StringName(str(_field(event, "t", "")))
	var names: Array[StringName] = []
	var extra_db := 0.0
	var heavy := bool(_field(event, "heavy", false))
	match type:
		&"swing":
			var weapon := str(_field(event, "weapon", "katana"))
			if weapon == "greatsword":
				names = [&"whoosh_colossal"]
			elif weapon == "daggers" or weapon == "fists":
				names = [&"whoosh_light" if heavy else &"whoosh_small"]
			else:
				names = [&"whoosh_heavy" if heavy else &"whoosh_light"]
		&"telegraph":
			# The ultimate's warning is heard through its own start sound.
			if str(_field(event, "kind", "")) != "ult":
				names = [&"telegraph"]
		&"hit":
			match str(_field(event, "sound", "blade")):
				"fist":
					names = [&"hit_fist_heavy" if heavy else &"hit_fist"]
				"colossal":
					names = [&"hit_colossal", &"crunch"]
				"dagger":
					names = [&"hit_dagger"]
				_:
					names = [&"hit_blade_heavy" if heavy else &"hit_blade"]
		&"block":
			names = [&"clang_heavy" if heavy else &"clang_light"]
		&"parry":
			match str(_field(event, "kind", "parry")):
				"flash":
					names = [&"parry_contact", &"parry_flash"]
				"redirect":
					names = [&"parry_redirect"]
				_:
					names = [&"parry_contact", &"parry_ring"]
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
		&"weaponBounce":
			var speed := float(_field(event, "speed", BOUNCE_FULL_SPEED))
			extra_db = linear_to_db(clampf(speed / BOUNCE_FULL_SPEED, 0.05, 1.0))
			names = [&"weapon_bounce"]
			if speed >= CLATTER_SPEED:
				names.append(&"weapon_clatter")
		_:
			if not EVENTS.has(type):
				return []
			names.assign(EVENTS[type])
	var delays: Dictionary = DELAYS.get(type, {})
	var out: Array[Dictionary] = []
	for cue_name: StringName in names:
		out.append({"cue": cue_name, "delay": float(delays.get(cue_name, 0.0)), "volume_db": extra_db})
	return out


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
