class_name HudState
extends RefCounted
## What one side of the HUD's top bar shows, worked out from the fighter's
## numbers with no nodes (task 24.1): the HP bar and whether it runs low, the
## posture bar and its heat, the lit pips, the ultimate badge and the
## disarmed tag. MatchHud draws it; tests check it. The demo's rules from
## src/ui/hud.ts's update().

enum Posture { CALM, HOT, FULL }
enum Badge { HIDDEN, READY, USED }

## HP at or under this share of the bar pulses (a standing fighter only).
const LOW_HP: float = 0.25
## Posture at or over this share runs hot, and at the top it is full.
const HOT_POSTURE: float = 0.7
const FULL_POSTURE: float = 0.999
const ROUND_KANJI: Array[String] = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

## HP as a share of the bar, 0 to 1.
var hp: float = 1.0
var low: bool = false
## Posture as a share of the bar, 0 to 1.
var posture: float = 0.0
var posture_level: Posture = Posture.CALM
## Pips lit: rounds won, up to the rounds a match needs.
var pips: int = 0
var badge: Badge = Badge.HIDDEN
var disarmed: bool = false


static func of(hp_points: float, posture_points: float, wins: int, can_ult: bool, ult_used: bool, armed: bool) -> HudState:
	var s: HudState = HudState.new()
	s.hp = clampf(hp_points / SimConst.HP_MAX, 0.0, 1.0)
	s.low = s.hp > 0.0 and s.hp <= LOW_HP
	s.posture = clampf(posture_points / SimConst.POSTURE_MAX, 0.0, 1.0)
	if s.posture >= FULL_POSTURE:
		s.posture_level = Posture.FULL
	elif s.posture >= HOT_POSTURE:
		s.posture_level = Posture.HOT
	s.pips = clampi(wins, 0, SimConst.ROUNDS_TO_WIN)
	if can_ult:
		s.badge = Badge.READY
	elif ult_used and hp_points <= SimConst.ULT_HP_THRESHOLD:
		s.badge = Badge.USED
	s.disarmed = not armed
	return s


static func of_fighter(f: Fighter, wins: int) -> HudState:
	return of(f.hp, f.posture, wins, f.can_ult(), f.ult_used, f.armed)


## The kanji for round n (一 to 九, then round again, as the demo's).
static func round_kanji(n: int) -> String:
	return ROUND_KANJI[posmod(n - 1, ROUND_KANJI.size())]
