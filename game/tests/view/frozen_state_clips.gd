class_name FrozenStateClips
extends RefCounted
## A frozen copy of state_clips.json as the game shipped it with the director's
## clip constants moved to data (Animation Studio task 3). The live file is the
## Studio's to edit; tests that hard-code clip names or timings from the table
## (the director's, the views') install this one instead, so a saved edit
## can't break them. Install it in before_each, restore in after_each.

const PATH: String = "res://tests/fixtures/state_clips_frozen.json"


## Makes the frozen table what StateClips.shared() answers.
static func install() -> void:
	StateClips.use(StateClips.read(PATH))


## Back to the live file.
static func restore() -> void:
	StateClips.use(null)
