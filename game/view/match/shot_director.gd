class_name ShotDirector
extends RefCounted
## The shot director (milestone-1 task 97; spec stories 133 and 135, P37,
## P38): chooses cinematic shots from the rules' events and plays them from
## their data (ShotData) on the presentation side, never in the rules.
## MatchView feeds it every event and every frame, and while a shot plays
## its cameras (both halves in Versus) take the shot's view.
##
## The choice (choose(), the seam the tests drive):
## - Moonsplitter and Breaker Palm once they connect (a hit by u_moon_v,
##   u_moon_h or f_breaker), never their wind-up: the wind-up stays on the
##   gameplay camera so the defender can read and answer it;
## - each finisher (finisher_katana, finisher_fists), played through Warrior
##   Slain when it ends the round;
## - the KO that wins the match (match_ko), on the round's score
##   (roundOver); a KO that only ends a round stays on the gameplay camera;
## - the recall gets a push-in (RECALL_PUSH_IN), not a shot.
## A shot that is playing gives way only to one that ranks as high or higher
## (RANK): so a match-winning finisher's shot stands in for the KO shot, and
## the match-winning KO takes over from an ultimate's.
##
## A shot runs on real time (advance()), so the camera keeps moving through
## hit-stop and the KO's slow motion. The rules never pause for it, so an
## ultimate's shot hands back to the gameplay camera at its length or when
## the victim's stun ends, in the world's frames, whichever is first. A new
## round ends any shot.

## The shots, by slot; each has its data in shots/<id>.tres.
const SLOTS: Array[StringName] = [&"moonsplitter", &"breaker_palm", &"finisher_katana", &"finisher_fists", &"match_ko"]
const DIR: String = "res://view/match/shots/"
## Which moves' hits play which shot.
const ON_HIT: Dictionary[StringName, StringName] = {
	&"u_moon_v": &"moonsplitter", &"u_moon_h": &"moonsplitter", &"f_breaker": &"breaker_palm",
}
## How a shot ranks against one that is playing.
const RANK: Dictionary[StringName, int] = {
	&"moonsplitter": 1, &"breaker_palm": 1, &"match_ko": 2, &"finisher_katana": 3, &"finisher_fists": 3,
}
## The recall's push-in: the share of the way to the camera's look point.
const RECALL_PUSH_IN: float = 0.25

## The shot playing, null for none; the fighter it is about; how long it
## has played (s of real time); and the world frame it hands back at (-1:
## only at its length).
var playing: ShotData = null
var about: int = -1
var elapsed: float = 0.0
var until_frame: int = -1

static var _cache: Dictionary[StringName, ShotData] = {}


## A slot's shot data, loaded once.
static func load_shot(id: StringName) -> ShotData:
	if not _cache.has(id):
		var path: String = DIR + String(id) + ".tres"
		_cache[id] = load(path) as ShotData if ResourceLoader.exists(path) else null
	return _cache[id]


## What a rules event asks of the camera, the world `W` as the rules left it
## after the event: {shot, about, cap} (cap: the victim's stun left in
## rules frames, -1 for none), {push_in}, or {} for nothing.
static func choose(e: Dictionary, W: World) -> Dictionary:
	match e["t"]:
		&"hit":
			var shot: StringName = ON_HIT.get(e.get("attack", &""), &"")
			if shot == &"":
				return {}
			return {"shot": shot, "about": int(e["attacker"]), "cap": _stun_left(W.fighters[int(e["target"])])}
		&"finisher":
			var kind: StringName = &"finisher_fists" if e["kind"] == &"fists" else &"finisher_katana"
			return {"shot": kind, "about": int(e["f"]), "cap": -1}
		&"roundOver":
			var winner: int = int(e["winner"])
			if winner < 0 or int((e["wins"] as Array)[winner]) < SimConst.ROUNDS_TO_WIN:
				return {}
			return {"shot": &"match_ko", "about": winner, "cap": -1}
		&"recallBurst":
			return {"push_in": RECALL_PUSH_IN}
	return {}


## A stunned fighter's frames left in its stun, -1 when it isn't in a timed
## stun (a KO).
static func _stun_left(f: Fighter) -> int:
	if f.state == &"ko" or f.hp <= 0.0 or f.state_dur <= 0:
		return -1
	return maxi(0, f.state_dur - f.sf)


## Takes a rules event: starts its shot when it ranks, ends any shot on a new
## round. Returns the choice (for the push-in).
func on_event(e: Dictionary, W: World) -> Dictionary:
	if e["t"] == &"roundStart":
		stop()
		return {}
	var c: Dictionary = choose(e, W)
	if c.has("shot"):
		var id: StringName = c["shot"]
		var shot: ShotData = load_shot(id)
		if shot != null and (playing == null or int(RANK[id]) >= int(RANK.get(playing.id, 0))):
			playing = shot
			about = int(c["about"])
			elapsed = 0.0
			until_frame = W.frame + int(c["cap"]) if int(c["cap"]) >= 0 else -1
	return c


## Moves the shot on by `delta` seconds of real time, at world frame
## `frame`: it ends at its length or at the victim's stun's end.
func advance(delta: float, frame: int) -> void:
	if playing == null:
		return
	elapsed += delta
	if elapsed > playing.length() + 1e-6 or (until_frame >= 0 and frame >= until_frame):
		stop()


func stop() -> void:
	playing = null
	about = -1
	elapsed = 0.0
	until_frame = -1


func active() -> bool:
	return playing != null


## The shot playing's id, &"" for none.
func playing_id() -> StringName:
	return playing.id if playing != null else &""


## The camera now, from the fighters' feet positions `at` (by side):
## {pos, look, fov, depth_of_field, dof_margin, dof_amount}; {} for none.
func view(at: Array[Vector3]) -> Dictionary:
	if playing == null:
		return {}
	var v: Dictionary = playing.view_at(elapsed, at[about], at[1 - about])
	v["depth_of_field"] = playing.depth_of_field
	v["dof_margin"] = playing.dof_margin
	v["dof_amount"] = playing.dof_amount
	return v
