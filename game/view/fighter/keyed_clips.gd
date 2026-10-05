class_name KeyedClips
extends RefCounted
## The hand-keyed clips: our own CC0 work, committed, so they play with or
## without the Iglesias packs. Each is keyed from a key-pose file in
## KEYS_FOLDER (KeyedPose) by tools/build_keyed_clips.gd, which writes them
## all into one AnimationLibrary at PATH. Tracks address bones as
## `%GeneralSkeleton:<profile bone>`, like the other libraries, so a clip
## plays on either fighter.
##
## - Mikiri_Stomp: the stomp counter (dodging into a thrust), after Sekiro's
##   mikiri counter: the hop onto the spear, the foot pinning it, the press
##   held as the attacker's posture breaks, and the rise to a ready stance,
##   fitted to the stomp state's 26 frames (Fighter.begin_stomp()).
## - Mikiri_Pinned: the stomped thruster's 70-frame stun (Fighter.stun_cause
##   &"stomp"): yanked down over the blade pinned under the stomper's foot,
##   wrenched free as the stomper rises, a stagger back and a dazed sway, then
##   back to the guard. Over its first frames the view pins the weapon's tip
##   under the stomper's foot (pin_weight(), STOMP_FOOT).
## - Power_Up: the recall's power-up (authored-animation task 30b, the
##   owner's design after a Super Saiyan power-up): feet planted wide, a
##   gather, then the chest thrown out, the head back shouting and the fists
##   clenched low at the sides, bursting on frame 16 as the weapon returns,
##   and up to ready, fitted to the recall's 26 frames; RecallAura draws its
##   aura and burst.

const LIBRARY: StringName = &"keyed"
const PATH: String = "res://assets/authored/keyed_library.tres"
const KEYS_FOLDER: String = "res://assets/authored/keys"
const STOMP: StringName = &"Mikiri_Stomp"
const PINNED: StringName = &"Mikiri_Pinned"
const POWER_UP: StringName = &"Power_Up"
## Where the stomp's right foot presses the blade from its landing on: the
## middle of the sole, in the stomper's fighter space (+Z forward, +X its
## left), on the floor (Mikiri_Stomp's right ankle key, 0.32 m ahead).
const STOMP_FOOT: Vector3 = Vector3(-0.12, 0.015, 0.39)
## The thruster's stun frames: the tip driven down onto the floor by PIN_FULL
## (the foot's landing), held there to PIN_RELEASE, wrenched free by PIN_FREE.
const PIN_FULL: float = 8.0
const PIN_RELEASE: float = 20.0
const PIN_FREE: float = 25.0


## The library, or null before the builder has written it.
static func load_library() -> AnimationLibrary:
	if not ResourceLoader.exists(PATH):
		return null
	return load(PATH) as AnimationLibrary


## How much the stomped thruster's weapon is pinned under the stomper's foot
## (0 to 1), `sf` frames into the stun.
static func pin_weight(sf: float) -> float:
	if sf <= PIN_RELEASE:
		return smoothstep(0.0, PIN_FULL, sf)
	return 1.0 - smoothstep(PIN_RELEASE, PIN_FREE, sf)


## A clip's name in a tree that has the library.
static func anim_name(clip: StringName) -> String:
	return "%s/%s" % [LIBRARY, clip]
