extends WeaponStringsTest
## The Katana's new strings (plan task 9): the spec's Katana table, played
## through the rules. Expected numbers come from the spec, not the code.

## The spec's Katana table, all nine rows (see WeaponStringsTest.rows).
const ROWS: Dictionary[StringName, Dictionary] = {
	&"k_l1": {
		"name": "Right Cut", "damage": 5, "posture": 5,
		"light": &"k_l2", "heavy": &"k_h2", "sides": [&"right", &"left"],
	},
	&"k_l2": {
		"name": "Return Cut", "damage": 5, "posture": 5,
		"light": &"k_l3", "heavy": &"k_h1f", "sides": [&"left", &"right"],
	},
	&"k_l3": {
		"name": "Kesa Cut", "damage": 6, "posture": 6,
		"light": &"k_l4", "heavy": &"k_h2", "sides": [&"right", &"left"],
	},
	&"k_l4": {
		"name": "Crown Cut", "damage": 7, "posture": 7,
		"light": &"", "heavy": &"", "sides": [&"centre", &"centre"],
	},
	# the data counts the sheathe in the startup: 9 + 14 = 23
	&"k_iai": {
		"name": "Iai Slash (vertical)", "damage": 13, "posture": 16,
		"light": &"", "heavy": &"k_h1f", "sides": [&"left", &"right"],
	},
	&"k_iai_h": {
		"name": "Iai Slash (horizontal)", "damage": 13, "posture": 16,
		"light": &"k_l2", "heavy": &"k_rdraw", "sides": [&"right", &"left"],
	},
	&"k_h1f": {
		"name": "Rising Heaven", "damage": 12, "posture": 15,
		"light": &"", "heavy": &"", "sides": [&"centre", &"left"],
	},
	&"k_rdraw": {
		"name": "Returning Draw", "damage": 12, "posture": 15,
		"light": &"", "heavy": &"", "sides": [&"left", &"right"],
	},
	&"k_h2": {
		"name": "Heaven Splitter", "damage": 15, "posture": 18,
		"light": &"", "heavy": &"k_h1f", "sides": [&"centre", &"centre"],
	},
	# the one-handed heavy (KE task 7): Heaven Splitter's clip until its
	# re-key, about 85% of its damage (D3)
	&"k_coil": {
		"name": "Crescent Coil", "damage": 13, "posture": 15,
		"light": &"", "heavy": &"", "sides": [&"centre", &"centre"],
	},
}

## Wind Cut, the dodge light, lunged 0.4 m, as the demo's did (the spec
## leaves the Katana's dodge attacks unchanged); 0.5 m since its clip
## (authored-animation task 12), to reach the duelling distance.
const WIND_CUT_LUNGE: float = 0.5


## The Iai Slash sheathes for 9 frames (a held heavy then stays sheathed, as
## a charge) and draws in 14, so a tapped heavy draws on frame 23 (the
## plan's decisions).
const IAI_SHEATHE: int = 9
const IAI_DRAW: int = 14

## The spec's blocking walk, 60% of running speed (m/s), at which a sheathed
## fighter walks: running speeds kept from the demo, the Katana's unchanged.
const BLOCK_STRAFE: float = 3.5 * 0.6
const BLOCK_FORWARD: float = 3.9 * 0.6
const BLOCK_BACK: float = 3.0 * 0.6


func _init() -> void:
	weapon = Moves.KATANA
	rows = ROWS


# ------------------------------------------------------------------ the light string

func test_four_lights_hit_with_right_cut_return_cut_kesa_cut_and_crown_cut() -> void:
	var r: PlayedString = _play([Btn.LIGHT, Btn.LIGHT, Btn.LIGHT, Btn.LIGHT])
	assert_eq(r.ids(&"hit"), [&"k_l1", &"k_l2", &"k_l3", &"k_l4"] as Array[StringName])


func test_a_heavy_ends_the_one_handed_string_on_crescent_coil() -> void:
	# a fighter starts one-handed; every hit's heavy branch is the grip's heavy
	# (KE task 7; the two-handed grip's in test_grip_heavies)
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	assert_eq(_play([light, heavy]).ids(&"hit"), [&"k_l1", &"k_coil"] as Array[StringName], "L-H: Right Cut, Crescent Coil")
	assert_eq(
		_play([light, light, heavy]).ids(&"hit"),
		[&"k_l1", &"k_l2", &"k_coil"] as Array[StringName],
		"L-L-H: Return Cut, Crescent Coil",
	)
	assert_eq(
		_play([light, light, light, heavy]).ids(&"hit"),
		[&"k_l1", &"k_l2", &"k_l3", &"k_coil"] as Array[StringName],
		"L-L-L-H: Kesa Cut, Crescent Coil",
	)


func test_crown_cut_again_as_hit_5_ends_the_string() -> void:
	# both grips' strings stand in as the four lights, Crown Cut repeated as
	# hit 5, and a string ends after hit 5 (KE task 5, D4)
	var light: int = Btn.LIGHT
	_assert_starts_nothing_in([light, light, light, light, light], [&"k_l1", &"k_l2", &"k_l3", &"k_l4", &"k_l4"], [light])
	# its heavy branch is the grip's heavy, as every hit's (KE task 7)
	assert_eq(_play([light, light, light, light, light, Btn.HEAVY]).ids(&"swing").back(), &"k_coil")


func test_stopping_after_any_hit_ends_the_string_when_that_move_ends() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	var strings: Array = [
		[light], [light, light], [light, light, light], [light, light, light, light],
		[light, heavy], [light, light, heavy], [light, light, light, heavy],
	]
	for presses: Array in strings:
		var typed: Array[int] = []
		typed.assign(presses)
		_assert_stops_after(typed)


func test_wind_cut_out_of_a_dodge_still_lunges_toward_the_defender() -> void:
	# Passing Cut, the Daggers' dodge light, lunges on along the dodge; the
	# Katana's, unchanged, lunges along its facing, toward the defender
	var r: PlayedString = _out_of_a_dodge(Btn.LIGHT, Callable(), Vector2(1.0, 0.0), WHIFF_GAP)
	assert_eq(r.ids(&"swing"), [&"k_dl"] as Array[StringName], "Wind Cut")
	var start: int = r.attack.find(&"k_dl")
	assert_gt(start, 0, "Wind Cut starts")
	if start <= 0:
		return
	assert_almost_eq(r.displacement(&"k_dl").length(), WIND_CUT_LUNGE, CLOSE, "its 0.5 m lunge")
	var closed: float = r.apart[start - 1] - r.apart[r.attack.rfind(&"k_dl")]
	assert_almost_eq(closed, WIND_CUT_LUNGE, CLOSE, "straight at the defender: the gap shrinks by all of it")


func test_kesa_cut_dodge_cancels_from_frame_20() -> void:
	_assert_dodge_cancels_from([Btn.LIGHT, Btn.LIGHT, Btn.LIGHT], &"k_l3", _cancel(&"k_l3"))


# ------------------------------------------------------------------ the Iai Slash

func test_a_tapped_heavy_draws_the_iai_on_frame_23() -> void:
	var r: PlayedString = _play([Btn.HEAVY])
	var draw: int = r.step_of(&"swing")
	assert_eq(r.ids(&"swing"), [&"k_iai"] as Array[StringName], "the heavy is the Iai Slash")
	assert_eq(r.frame[draw] if draw >= 0 else -1, IAI_SHEATHE + IAI_DRAW, "drawn on frame 23, the sheathe and the draw")
	assert_eq(r.ids(&"hit"), [&"k_iai"] as Array[StringName], "and it hits")


## Fighter 0 holds heavy for hold steps against an idle Katana 2.2 m away, for
## 240 steps.
func _hold_heavy(hold: int) -> PlayedString:
	return _run(func(i: int) -> RawInput: return H.btn(Btn.HEAVY) if i < hold else H.idle())


func test_a_held_iai_stays_sheathed_and_hits_14_frames_after_release() -> void:
	var r: PlayedString = _hold_heavy(60)
	assert_eq(r.charging.find(true), IAI_SHEATHE + 1, "sheathed once its 9 frames have passed")
	assert_eq(r.charging.rfind(true), 59, "until heavy is let go on step 60")
	assert_eq(r.frame.slice(IAI_SHEATHE, 60).count(IAI_SHEATHE), 60 - IAI_SHEATHE, "its frames stop on 9 meanwhile")
	assert_eq(r.ids(&"hit"), [&"k_iai"] as Array[StringName])
	assert_eq(r.step_of(&"hit") - 60, IAI_DRAW, "the cut lands 14 frames after the release")


func test_an_iai_held_for_2_5_s_releases_by_itself_as_a_stronger_power_attack() -> void:
	var r: PlayedString = _hold_heavy(220)
	var release: int = r.charging.rfind(true) + 1
	assert_eq(release, IAI_SHEATHE + 150, "the stance ends 150 frames (2.5 s) after the sheathe, heavy still held")
	assert_eq(r.step_of(&"hit") - release, IAI_DRAW, "and the cut lands 14 frames later")
	var hit: Dictionary = r.find(&"hit")
	assert_almost_eq(float(hit.get("damage", NAN)), 13.0 * 1.8, CLOSE, "a full charge's damage")


func test_the_iai_hits_at_3_8_m_where_right_cut_whiffs() -> void:
	var cut: PlayedString = _play([Btn.LIGHT], 3.8)
	assert_eq(cut.ids(&"whiff"), [&"k_l1"] as Array[StringName], "Right Cut whiffs")
	assert_eq(_play([Btn.HEAVY], 3.8).ids(&"hit"), [&"k_iai"] as Array[StringName], "the Iai hits")


## The Iai's clips (authored-animation task 11) still reach as the spec's
## Iai does: into a defender 3.6 m away, not one 4.2 m away.
func test_the_iai_enters_a_defender_at_3_6_m_and_misses_at_4_2_m() -> void:
	for id: StringName in [&"k_iai", &"k_iai_h"]:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_not_null(m.swing, "%s has its baked swing" % id)
		if m.swing == null:
			continue
		assert_not_null(SwingReach.first_contact(m, Moves.KATANA, 3.6, 0.0, FighterBody.of(&"")), "%s enters at 3.6 m" % id)
		assert_null(SwingReach.first_contact(m, Moves.KATANA, 4.2, 0.0, FighterBody.of(&"")), "%s misses at 4.2 m" % id)


## The unblockables' clips (authored-animation task 13), with their thicker
## sweep, reach a defender 3.5 m away, where Right Cut whiffs.
func test_an_unblockable_hits_where_the_light_misses() -> void:
	var body: FighterBody = FighterBody.of(&"")
	assert_null(SwingReach.first_contact(Moves.KATANA.moves[&"k_l1"], Moves.KATANA, 3.5, 0.0, body), "Right Cut misses at 3.5 m")
	for id: StringName in [&"k_thrust", &"k_sweep"]:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_true(m.unblockable, "%s is unblockable" % id)
		assert_not_null(SwingReach.first_contact(m, Moves.KATANA, 3.5, 0.0, body), "%s hits at 3.5 m" % id)


## Flash (task 13) is a pose-only clip: its swing moves the body alone, so it
## places no blade and never strikes.
func test_flash_plays_a_clip_but_strikes_nothing() -> void:
	var flash: AttackDef = Moves.KATANA.moves[&"k_flash"]
	assert_not_null(flash.swing, "a baked swing")
	assert_false(flash.swing.clips.is_empty(), "played from its clips")
	assert_eq(flash.swing.parts(), [&"body"] as Array[StringName], "the body alone")


func test_a_sheathed_fighter_cannot_block() -> void:
	# fighter 0 holds heavy to stay sheathed, and holds block too from step
	# 12; the opponent's Right Cut lands while it is sheathed
	var W: World = H.make_world()
	var r := PlayedString.new()
	for i: int in 60:
		var p0: RawInput = H.btn(Btn.HEAVY) if i < 12 else H.btn(Btn.HEAVY, Btn.BLOCK)
		r.step(W, p0, H.btn(Btn.LIGHT) if i == 20 else H.idle())
	var on_fighter_0: Callable = func(e: Dictionary) -> bool: return e["target"] == 0
	var hits: Array[Dictionary] = r.all(&"hit").filter(on_fighter_0)
	assert_eq(hits.size(), 1, "the Right Cut hits")
	if hits.size() == 1:
		assert_true(r.charging[int(hits[0]["step"]) - 1], "a sheathed fighter")
	assert_eq(r.all(&"block").filter(on_fighter_0), [] as Array[Dictionary], "holding block blocks nothing")


func test_the_iai_dodge_cancels_late_in_its_recovery() -> void:
	_assert_dodge_cancels_from([Btn.HEAVY], &"k_iai", _cancel(&"k_iai"))


# ------------------------------------------------------------------ the Iai stance
# Heavy held from step 0: the sheathe takes steps 1 to 9, and the stance
# begins on step 10.

func test_a_sheathed_fighter_strafes_round_the_opponent_at_block_speed() -> void:
	var r: PlayedString = _run(func(_i: int) -> RawInput: return H.move(1.0, 0.0, Btn.HEAVY), 2.2, 80)
	assert_eq(r.charging.slice(IAI_SHEATHE + 1).count(false), 0, "sheathed throughout")
	# up to speed by step 20; the orbit pulls each step back onto the circle
	var strafed: float = r.walked(20, 80)
	assert_almost_eq(strafed, BLOCK_STRAFE, BLOCK_STRAFE * 0.02, "a second's strafe is within 2% of the block strafe")
	var drift: float = 0.0
	for d: float in r.apart:
		drift = maxf(drift, absf(d - 2.2))
	assert_lt(drift, 0.01, "it circles the opponent, keeping its distance within 1 cm")


func test_a_sheathed_fighter_walks_forward_and_back_at_block_speed() -> void:
	# 8 m apart, so the walk forward ends more than 5 m short of the opponent
	var walks: Array[Dictionary] = [
		{"way": "forward", "my": 1.0, "speed": BLOCK_FORWARD},
		{"way": "back", "my": -1.0, "speed": BLOCK_BACK},
	]
	for walk: Dictionary in walks:
		var my: float = walk["my"]
		var r: PlayedString = _run(func(_i: int) -> RawInput: return H.move(0.0, my, Btn.HEAVY), 8.0, 80)
		assert_almost_eq(r.walked(20, 80), float(walk["speed"]), 1e-6, "a second's walk %s" % walk["way"])


func test_the_fighter_stands_still_while_it_sheathes() -> void:
	var r: PlayedString = _run(func(_i: int) -> RawInput: return H.move(1.0, 0.0, Btn.HEAVY), 2.2, 20)
	assert_eq(r.walked(0, IAI_SHEATHE + 1), 0.0, "no walking until the sheathe's 9 frames end")
	assert_gt(r.moved[IAI_SHEATHE + 1], 0.0, "then it walks, sheathed")


func test_a_sheathed_fighter_neither_steps_nor_sprints() -> void:
	# the stick pushed from neutral in the stance (a step when free), with
	# sprint held; 8 m apart
	var push: Callable = func(i: int) -> RawInput:
		return H.move(1.0, 0.0, Btn.HEAVY, Btn.SPRINT) if i >= 30 else H.btn(Btn.HEAVY)
	var r: PlayedString = _run(push, 8.0, 90)
	var fastest: float = 0.0
	for d: float in r.moved.slice(30):
		fastest = maxf(fastest, d)
	assert_lte(fastest, BLOCK_STRAFE / 60.0 + 1e-9, "never faster than the block strafe")
	assert_true(r.charging[89], "and still sheathed")


func test_a_dodge_cancels_the_stance() -> void:
	# a dodge to the right on step 30, heavy still held
	var dodge_on_30: Callable = func(i: int) -> RawInput:
		if i < 30:
			return H.btn(Btn.HEAVY)
		return H.move(1.0, 0.0, Btn.HEAVY, Btn.DODGE) if i == 30 else H.move(1.0, 0.0, Btn.HEAVY)
	var r: PlayedString = _run(dodge_on_30)
	assert_true(r.charging[29], "sheathed when the dodge is pressed")
	assert_eq(r.state[30], &"dodge", "the dodge comes at once")
	assert_eq(r.ids(&"swing"), [] as Array[StringName], "and the Iai is never drawn")


func test_a_dodge_pressed_late_in_the_sheathe_comes_as_the_stance_begins() -> void:
	# a dodge to the right pressed on step 5, in the sheathe, waits in the
	# input buffer (8 frames), as a press made just before any dodge cancel
	# opens does
	var held: Callable = func(i: int) -> RawInput:
		if i < 5:
			return H.btn(Btn.HEAVY)
		return H.move(1.0, 0.0, Btn.HEAVY, Btn.DODGE) if i == 5 else H.move(1.0, 0.0, Btn.HEAVY)
	var r: PlayedString = _run(held, 2.2, 40)
	assert_eq(r.state.find(&"dodge"), IAI_SHEATHE + 1, "held: not taken in the sheathe, but on the stance's first step")
	# heavy let go on step 3: there is no stance, so the dodge is refused
	var tapped: Callable = func(i: int) -> RawInput:
		if i < 3:
			return H.btn(Btn.HEAVY)
		if i < 5:
			return H.idle()
		return H.move(1.0, 0.0, Btn.DODGE) if i == 5 else H.move(1.0, 0.0)
	var t: PlayedString = _run(tapped, 2.2, 120)
	# (the stick, held right as the sheathe ends, picks the horizontal)
	assert_eq(t.ids(&"hit"), [&"k_iai_h"] as Array[StringName], "tapped: the Iai draws and hits")
	assert_false(t.state.has(&"dodge") or t.state.has(&"backstep"), "and no dodge comes")


func test_a_dodge_on_the_step_heavy_is_let_go_still_cancels_the_stance() -> void:
	# heavy let go and dodge pressed together on step 40: the stance is still
	# on as the step begins, and the draw hasn't started
	var together: Callable = func(i: int) -> RawInput:
		if i < 40:
			return H.btn(Btn.HEAVY)
		return H.move(1.0, 0.0, Btn.DODGE) if i == 40 else H.move(1.0, 0.0)
	var r: PlayedString = _run(together)
	assert_eq(r.state[40], &"dodge", "the dodge comes")
	assert_eq(r.ids(&"swing"), [] as Array[StringName], "and the Iai is never drawn")


func test_a_dodge_during_the_draw_does_not_cancel_it() -> void:
	# heavy let go on step 40, which starts the draw; a dodge pressed 1, 7 or
	# 13 steps later, the stick then held to the side
	for k: int in [1, 7, 13]:
		var dodge_in_draw: Callable = func(i: int) -> RawInput:
			if i < 40:
				return H.btn(Btn.HEAVY)
			if i < 40 + k:
				return H.idle()
			return H.move(1.0, 0.0, Btn.DODGE) if i == 40 + k else H.move(1.0, 0.0)
		var r: PlayedString = _run(dodge_in_draw, 2.2, 120)
		assert_eq(r.ids(&"hit"), [&"k_iai"] as Array[StringName], "a dodge %d frames into the draw: the Iai still hits" % k)
		assert_false(r.state.has(&"dodge") or r.state.has(&"backstep"), "and no dodge comes")


func test_other_charged_heavies_still_stand_still() -> void:
	# their heavies held with the stick to the side, 8 m apart
	for other: WeaponDef in [Moves.GREATSWORD, Moves.DAGGERS]:
		var r: PlayedString = PlayedString.run(other, func(_i: int) -> RawInput: return H.move(1.0, 0.0, Btn.HEAVY), 8.0, 80)
		var charged_from: int = r.charging.find(true)
		assert_gt(charged_from, 0, "%s charges" % other.id)
		assert_eq(r.walked(charged_from, 80), 0.0, "%s stands still while it charges" % other.id)


# ------------------------------------------------------------------ the horizontal Iai
# The stick as the Iai is drawn picks the draw: left or right, past the dead
# zone and more sideways than forward or back, gives the horizontal Iai.

## How long heavy is held for each way the Iai is drawn: a tap (drawn as the
## sheathe ends), a release on step 40, and an auto-release 2.5 s in.
const HOLDS: Dictionary[String, int] = {"a tap": 1, "a release": 40, "an auto-release": 220}


## Fighter 0 holds heavy for hold steps (1 is a tap), with the stick at (mx,
## my) from step 0 to the end, against an idle Katana 2.2 m away.
func _iai_with_stick(hold: int, mx: float, my: float) -> PlayedString:
	return _run(func(i: int) -> RawInput: return H.move(mx, my, Btn.HEAVY) if i < hold else H.move(mx, my))


func test_left_or_right_as_the_iai_is_drawn_gives_the_horizontal() -> void:
	for side: Dictionary in [{"way": "left", "mx": -1.0}, {"way": "right", "mx": 1.0}]:
		for hold: String in HOLDS:
			var r: PlayedString = _iai_with_stick(HOLDS[hold], side["mx"], 0.0)
			assert_eq(r.ids(&"swing"), [&"k_iai_h"] as Array[StringName], "%s with the stick %s" % [hold, side["way"]])


func test_neutral_forward_or_back_draws_the_vertical_iai() -> void:
	var sticks: Array[Dictionary] = [
		{"way": "neutral", "my": 0.0}, {"way": "forward", "my": 1.0}, {"way": "back", "my": -1.0},
	]
	for stick: Dictionary in sticks:
		for hold: String in HOLDS:
			var r: PlayedString = _iai_with_stick(HOLDS[hold], 0.0, stick["my"])
			assert_eq(r.ids(&"swing"), [&"k_iai"] as Array[StringName], "%s with the stick %s" % [hold, stick["way"]])


func test_only_a_stick_past_the_dead_zone_and_more_sideways_than_not_picks_the_horizontal() -> void:
	# tapped; the dead zone is 0.4
	var cases: Array[Dictionary] = [
		{"mx": 0.8, "my": 0.6, "draw": &"k_iai_h", "why": "more sideways than forward"},
		{"mx": -0.8, "my": -0.6, "draw": &"k_iai_h", "why": "more sideways than back"},
		{"mx": 0.6, "my": 0.8, "draw": &"k_iai", "why": "more forward than sideways"},
		{"mx": 0.6, "my": -0.6, "draw": &"k_iai", "why": "as far back as sideways"},
		{"mx": 0.35, "my": 0.0, "draw": &"k_iai", "why": "sideways but inside the dead zone"},
	]
	for c: Dictionary in cases:
		var r: PlayedString = _iai_with_stick(1, c["mx"], c["my"])
		assert_eq(r.ids(&"swing"), [c["draw"]] as Array[StringName], "the stick at (%s, %s): %s" % [c["mx"], c["my"], c["why"]])


func test_only_the_stick_as_the_iai_is_drawn_counts() -> void:
	# held to step 40: it is drawn on the release step
	var release: int = HOLDS["a release"]
	var let_go: PlayedString = _run(func(i: int) -> RawInput: return H.move(1.0, 0.0, Btn.HEAVY) if i < release else H.idle())
	assert_eq(let_go.ids(&"swing"), [&"k_iai"] as Array[StringName], "right in the stance, let go as heavy is: vertical")
	var pushed: PlayedString = _run(func(i: int) -> RawInput: return H.btn(Btn.HEAVY) if i < release else H.move(1.0, 0.0))
	assert_eq(pushed.ids(&"swing"), [&"k_iai_h"] as Array[StringName], "neutral in the stance, right as heavy is let go: horizontal")
	# tapped: it is drawn on step 10, as the sheathe's 9 frames end
	var ends: int = IAI_SHEATHE + 1
	var right_in_sheathe: Callable = func(i: int) -> RawInput:
		if i >= ends:
			return H.idle()
		return H.move(1.0, 0.0, Btn.HEAVY) if i == 0 else H.move(1.0, 0.0)
	var early: PlayedString = _run(right_in_sheathe)
	assert_eq(early.ids(&"swing"), [&"k_iai"] as Array[StringName], "tapped, right in the sheathe but let go as it ends: vertical")
	var right_as_it_ends: Callable = func(i: int) -> RawInput:
		if i == 0:
			return H.btn(Btn.HEAVY)
		return H.move(1.0, 0.0) if i >= ends else H.idle()
	var late: PlayedString = _run(right_as_it_ends)
	assert_eq(late.ids(&"swing"), [&"k_iai_h"] as Array[StringName], "tapped, right only as the sheathe ends: horizontal")


func test_the_horizontal_iai_keeps_the_iais_timing_and_charge() -> void:
	var tapped: PlayedString = _iai_with_stick(1, 1.0, 0.0)
	var draw: int = tapped.step_of(&"swing")
	assert_eq(tapped.frame[draw] if draw >= 0 else -1, IAI_SHEATHE + IAI_DRAW, "tapped, it draws on frame 23")
	var held: PlayedString = _iai_with_stick(HOLDS["a release"], 1.0, 0.0)
	assert_eq(held.ids(&"hit"), [&"k_iai_h"] as Array[StringName], "held, it hits")
	assert_eq(held.step_of(&"hit") - HOLDS["a release"], IAI_DRAW, "14 frames after the release")
	var full: PlayedString = _iai_with_stick(HOLDS["an auto-release"], 1.0, 0.0)
	assert_eq(full.ids(&"hit"), [&"k_iai_h"] as Array[StringName], "held for 2.5 s, it releases by itself and hits")
	assert_almost_eq(float(full.find(&"hit").get("damage", NAN)), 13.0 * 1.8, CLOSE, "as a full charge's power attack")


# ------------------------------------------------------------------ the Iai follow-ups

## As _play, with the stick held right throughout, so the Iai draws the
## horizontal.
func _play_sideways(presses: Array[int]) -> PlayedString:
	return _play(presses, 2.2, 1.0)


func test_the_vertical_iai_goes_on_to_the_grip_s_heavy() -> void:
	# one-handed, Crescent Coil, which ends the string (KE task 7, D5; the
	# two-handed grip's Rising Heaven in test_grip_heavies)
	var heavy: int = Btn.HEAVY
	assert_eq(
		_play([heavy, heavy, heavy]).ids(&"swing"),
		[&"k_iai", &"k_coil"] as Array[StringName],
		"heavy, heavy: Crescent Coil, then nothing",
	)
	assert_eq(_play([heavy, Btn.LIGHT]).ids(&"swing"), [&"k_iai"] as Array[StringName], "a light after it starts nothing")


func test_the_horizontal_iai_goes_on_to_returning_draw_or_return_cut() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	assert_eq(_play_sideways([heavy, heavy]).ids(&"swing"), [&"k_iai_h", &"k_rdraw"] as Array[StringName], "heavy: Returning Draw")
	assert_eq(_play_sideways([heavy, light]).ids(&"swing"), [&"k_iai_h", &"k_l2"] as Array[StringName], "light: Return Cut")
	assert_eq(
		_play_sideways([heavy, light, light, light]).ids(&"swing"),
		[&"k_iai_h", &"k_l2", &"k_l3", &"k_l4"] as Array[StringName],
		"Return Cut goes on through the light string",
	)
	assert_eq(
		_play_sideways([heavy, light, heavy]).ids(&"swing"),
		[&"k_iai_h", &"k_l2", &"k_coil"] as Array[StringName],
		"or to the grip's heavy, Crescent Coil",
	)


func test_a_held_horizontal_iai_goes_on_to_returning_draw_too() -> void:
	# heavy held with the stick right to step 40, then pressed again on step
	# 55, after the cut's swing on step 53
	var held_then_heavy: Callable = func(i: int) -> RawInput:
		if i < 40 or i == 55:
			return H.move(1.0, 0.0, Btn.HEAVY)
		return H.move(1.0, 0.0)
	assert_eq(_run(held_then_heavy).ids(&"swing"), [&"k_iai_h", &"k_rdraw"] as Array[StringName])


func test_returning_draw_ends_the_string() -> void:
	_assert_starts_nothing_in([Btn.HEAVY, Btn.HEAVY], [&"k_iai_h", &"k_rdraw"], LIGHT_OR_HEAVY, 1.0)


func test_stopping_after_any_hit_in_the_iais_strings_ends_the_string_when_that_move_ends() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	# mx 1.0 draws the horizontal
	var strings: Array[Dictionary] = [
		{"presses": [heavy], "mx": 0.0},
		{"presses": [heavy, heavy], "mx": 0.0},
		{"presses": [heavy], "mx": 1.0},
		{"presses": [heavy, heavy], "mx": 1.0},
		{"presses": [heavy, light], "mx": 1.0},
		{"presses": [heavy, light, heavy], "mx": 1.0},
	]
	for s: Dictionary in strings:
		var presses: Array[int] = []
		presses.assign(s["presses"])
		_assert_stops_after(presses, s["mx"])


# ------------------------------------------------------------------ the spec's table

func test_all_nine_rows_match_the_spec_table() -> void:
	_assert_rows_match_the_spec()


func test_the_horizontal_iai_hits_with_the_specs_interim_cone() -> void:
	# until weapon paths decide hits (task 7): a right-to-left slash drawn
	# from the sheathe (its anim, iaiHorizontal), as far as the vertical Iai
	# and as wide as Right Cut; lunging 2.1 m with the vertical since their
	# clips (authored-animation task 11), from 0.4
	var m: AttackDef = Moves.KATANA.moves.get(&"k_iai_h", null)
	assert_not_null(m, "the horizontal Iai exists")
	if m == null:
		return
	assert_eq([m.type, m.anim], [&"slash", &"iaiHorizontal"], "a right-to-left slash, drawn from the sheathe")
	assert_eq([m.range, m.arc, m.lunge, m.knockback], [3.6, 110.0, 2.1, 1.0], "range, arc, lunge and knockback")


func test_returning_draw_hits_with_the_specs_interim_cone() -> void:
	# until weapon paths decide hits (task 7): a left-to-right slash (the
	# stand-in's slashLR) with Rising Heaven's reach, lunge and knockback and
	# Return Cut's width, its lunge ending two frames after its cut starts;
	# the lunge is 1.1 m since its clip (authored-animation task 11), from 0.5
	var m: AttackDef = Moves.KATANA.moves.get(&"k_rdraw", null)
	assert_not_null(m, "Returning Draw exists")
	if m == null:
		return
	assert_eq([m.type, m.anim], [&"slash", &"slashLR"], "a left-to-right slash")
	assert_eq(
		[m.range, m.arc, m.lunge, m.lunge_end, m.knockback], [2.3, 110.0, 1.1, 18, 0.9], "range, arc, lunge, the lunge's end and knockback"
	)


func test_kesa_cut_hits_with_the_specs_interim_cone() -> void:
	# until weapon paths decide hits (task 7): a slash from the right shoulder
	# to the left hip (the stand-in's diagonal cut down), 2.2 m and 100° after
	# a lunge, knocking back 0.4 m; the lunge is 0.4 m since its clip
	# (authored-animation task 10), from 0.35, to reach the duelling distance
	var m: AttackDef = Moves.KATANA.moves[&"k_l3"]
	assert_eq([m.type, m.anim], [&"slash", &"diagDown"], "Kesa Cut is a diagonal slash down")
	assert_eq([m.range, m.arc, m.lunge, m.knockback], [2.2, 100.0, 0.4, 0.4], "range, arc, lunge and knockback")
