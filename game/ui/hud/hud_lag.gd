class_name HudLag
extends RefCounted
## The white "damage just taken" band under an HP bar: it holds where the HP
## was for HOLD seconds after a loss, then drains at DRAIN of the bar a second
## until it meets the HP. A heal moves it up at once. On the wall clock, as
## the demo's (v0.1-web-mvp:src/ui/hud.ts).

const HOLD: float = 0.45
const DRAIN: float = 0.6

## The band's end, as a share of the bar.
var value: float = 1.0
var _held: float = 0.0


func step(hp: float, delta: float) -> void:
	if hp < value:
		_held += delta
		if _held > HOLD:
			value = maxf(hp, value - delta * DRAIN)
	else:
		value = hp
		_held = 0.0


## Puts the band on the HP at once (a new match, or a shot that skips time).
func reset(hp: float) -> void:
	value = hp
	_held = 0.0
