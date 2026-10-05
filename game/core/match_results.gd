class_name MatchResults
extends RefCounted
## What the results screen shows when a match ends: the winner, the rounds
## won, how many rounds were fought, and the demo's seven per-fighter stats.
## MatchHost.results() builds it from the rules' Match and Fighter state.

## The stats in display order: [FighterStats field, label].
const STATS: Array[Array] = [
	["hits_landed", "Hits landed"],
	["damage_dealt", "Damage dealt"],
	["blocks", "Blocks"],
	["parries", "Parries"],
	["counters", "Counters"],
	["disarms", "Disarms"],
	["ultimates", "Ultimates"],
]

var mode: StringName = MatchConfig.DUEL
## The winning side, or -1 (no winner yet).
var winner: int = -1
## [side 0, side 1] rounds won.
var wins: Array[int] = [0, 0]
## Rounds fought, drawn ones included.
var rounds: int = 0
var names: Array[String] = ["", ""]
var weapons: Array[String] = ["", ""]
## [side 0, side 1] palette indices (MatchSide.palette): each side's colour.
var palettes: Array[int] = [0, 1]
## [side 0, side 1]: { stat field: number }
var stats: Array[Dictionary] = [{}, {}]
## The sides' seals (赤 red, 青 blue), which tell a mirror match's sides apart.
const SEALS: Array[String] = ["赤", "青"]

## The side a human played (the perspective of "Victory" / "Defeat"), or -1.
var player_side: int = -1


static func from_match(m: Match, cfg: MatchConfig, p_player_side: int) -> MatchResults:
	var r: MatchResults = MatchResults.new()
	r.mode = cfg.mode
	r.winner = m.match_winner
	r.wins = [m.wins[0], m.wins[1]]
	r.rounds = m.round
	r.player_side = p_player_side
	for i: int in 2:
		var f: Fighter = m.world.fighters[i]
		r.names[i] = f.name
		r.weapons[i] = f.weapon.name
		if i < cfg.sides.size() and cfg.sides[i] != null:
			r.palettes[i] = cfg.sides[i].palette
		var s: Dictionary = {}
		for row: Array in STATS:
			s[row[0]] = f.stats.get(String(row[0]))
		r.stats[i] = s
	return r


## Whether the results speak to one human player (Victory or Defeat), not
## name a winner (Watch, Versus).
func for_one_player() -> bool:
	return mode != MatchConfig.WATCH and mode != MatchConfig.VERSUS and player_side >= 0


## The headline: Victory or Defeat for one human player, else who won (with
## the side's seal in a mirror match: "Rogue 青 wins").
func title() -> String:
	if winner < 0:
		return "Draw"
	if for_one_player():
		return "Victory" if winner == player_side else "Defeat"
	return "%s wins" % side_name(names, winner)


## The kanji over the headline: the demo's 勝利 Victory, 敗北 Defeat and 決着
## (settled) when someone else's win is named, and 引分 for a draw, which the
## demo never showed.
func kanji() -> String:
	if winner < 0:
		return "引分"
	if for_one_player():
		return "勝利" if winner == player_side else "敗北"
	return "決着"


## A stat as the results table shows it (damage rounded to a whole number).
func stat_text(side: int, field: String) -> String:
	var v: Variant = stats[side].get(field, 0)
	if v is float:
		return str(roundi(float(v)))
	return str(v)


## A side's fighter by name, with the side's seal when both sides have the
## same name (a mirror match): "Rogue", or "Rogue 青".
static func side_name(p_names: Array[String], side: int) -> String:
	if p_names[0] == p_names[1]:
		return "%s %s" % [p_names[side], SEALS[side]]
	return p_names[side]
