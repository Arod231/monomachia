class_name ClipChain
extends RefCounted
## A move's chain of clips (the move-clip table's "clips", Swing.clips),
## played one after another (authored-animation task 11). Each entry is a
## clip id, or part of one: "id@from" plays it from source frame `from`,
## "id@from-to" from `from` to `to`, and "id@frame*n" holds source frame
## `frame` for `n` source frames (an unblockable's wound-up pose shown
## early, task 13). Each part after the first fades in from
## the one before, held at its last pose, over its first BLEND source frames,
## so a sheathe's end can lead into a cut's wind-up without a pop. The bake
## (ClipPoser) and the clip director (chain_clip()) lay the chain out the same
## way, so the clip shown is the clip baked.
##
## An id is a clip-manifest id, played from the fighter's Iglesias set, or a
## committed CC0 clip named with its library ("ual/Sword_Dash", task 12),
## played from that library whatever the set (anim_name()).

## How long each part fades in from the one before (source frames).
const BLEND: float = 3.0


## One part of a chain: a clip from one source frame to another.
class Part:
	var id: StringName = &""
	var from: float = 0.0
	## NAN for the clip's end.
	var to: float = NAN
	## Source frames it holds `from` for (a held part, "id@frame*n"), or 0.
	var hold: float = 0.0
	## Laid out (lay_out()): where it starts in the chain and how long it
	## plays (source frames).
	var start: float = 0.0
	var length: float = 0.0


## Where a chain is at one moment: its part and the source frame into that
## part's clip; and, while the part fades in, the part before held at its
## last frame and how much of it still shows (0 to 1).
class Place:
	var part: int = 0
	var frame: float = 0.0
	var under: int = -1
	var under_frame: float = 0.0
	var under_weight: float = 0.0


## The animation name of clip `id` for a fighter playing set `set_name`:
## the set's clip, or the id itself when it names its library.
static func anim_name(set_name: StringName, id: StringName) -> String:
	return String(id) if String(id).contains("/") else "%s/%s" % [set_name, id]


## Whether `id` is a committed CC0 clip (FighterModel.LIBRARY's) rather than
## a clip-manifest one.
static func is_cc0(id: StringName) -> bool:
	return String(id).begins_with(String(FighterModel.LIBRARY) + "/")


## Chain entry `entry` as an animation name for set `set_name`, its part
## (an "@from-to") kept.
static func qualified(set_name: StringName, entry: String) -> String:
	var at: int = entry.find("@")
	var id: String = entry if at < 0 else entry.substr(0, at)
	return anim_name(set_name, StringName(id)) + ("" if at < 0 else entry.substr(at))


## The part entry `entry` names, or null with a line in `errors` when it
## doesn't read ("id", "id@from", "id@from-to" from before to, or
## "id@frame*n").
static func parse(entry: String, errors: Array[String]) -> Part:
	var p: Part = Part.new()
	var at: int = entry.find("@")
	p.id = StringName(entry if at < 0 else entry.substr(0, at))
	if at < 0:
		return p
	var held: PackedStringArray = entry.substr(at + 1).split("*")
	if held.size() == 2:
		if held[0].is_valid_float() and held[1].is_valid_float() and float(held[0]) >= 0.0 and float(held[1]) > 0.0 and p.id != &"":
			p.from = float(held[0])
			p.to = p.from
			p.hold = float(held[1])
			return p
		errors.append("%s: a held part is \"id@frame*n\" (hold source frame `frame` for n source frames)" % entry)
		return null
	var span: PackedStringArray = entry.substr(at + 1).split("-")
	var ok: bool = span.size() <= 2 and span[0].is_valid_float() and (span.size() == 1 or span[1].is_valid_float())
	if ok:
		p.from = float(span[0])
		if span.size() == 2:
			p.to = float(span[1])
		ok = p.from >= 0.0 and (is_nan(p.to) or p.to > p.from)
	if not ok or p.id == &"":
		errors.append("%s: a chain part is \"id\", \"id@from\" or \"id@from-to\" (source frames, from before to)" % entry)
		return null
	return p


## The chain `entries` laid out with its clips' lengths (`lengths`: clip id
## -> source frames): each part's start and length. Empty, with errors, for
## an entry that doesn't read or runs past its clip.
static func lay_out(entries: Array, lengths: Dictionary, errors: Array[String]) -> Array[Part]:
	var out: Array[Part] = []
	var start: float = 0.0
	for e: Variant in entries:
		var p: Part = parse(String(e), errors)
		if p == null:
			return [] as Array[Part]
		var full: float = float(lengths.get(p.id, 0.0))
		var to: float = full if is_nan(p.to) else p.to
		if to > full + 1e-6 or (p.from >= to and p.hold <= 0.0):
			errors.append("%s: past the clip's end (frame %s)" % [e, ClipTiming.frame_text(snappedf(full, 0.01))])
			return [] as Array[Part]
		p.to = to
		p.start = start
		p.length = p.hold if p.hold > 0.0 else to - p.from
		start += p.length
		out.append(p)
	return out


## The chain's whole length (source frames).
static func length_of(parts: Array[Part]) -> float:
	return 0.0 if parts.is_empty() else parts[-1].start + parts[-1].length


## Where chain `parts` is at source frame `t` from its start (clamped to it).
static func place(parts: Array[Part], t: float) -> Place:
	var out: Place = Place.new()
	var at: float = clampf(t, 0.0, length_of(parts))
	var i: int = parts.size() - 1
	while i > 0 and at < parts[i].start:
		i -= 1
	out.part = i
	out.frame = parts[i].from + (0.0 if parts[i].hold > 0.0 else at - parts[i].start)
	var into: float = at - parts[i].start
	if i > 0 and into < BLEND:
		out.under = i - 1
		out.under_frame = parts[i - 1].to
		out.under_weight = 1.0 - into / BLEND
	return out
