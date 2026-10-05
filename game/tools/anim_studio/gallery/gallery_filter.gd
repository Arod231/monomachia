class_name GalleryFilter
extends RefCounted
## Which catalogue entries the gallery's search box and badge chips let through
## (docs/specs/animation-studio.md, Gallery).


## True when `entry` matches the search `text` and has every badge in
## `badges`. The text matches a part of the entry's name or id, ignoring case
## and the spaces round it; no text matches everything.
static func matches(entry: StudioCatalogue.Entry, text: String, badges: Array[StringName]) -> bool:
	for b: StringName in badges:
		if not entry.badges.get(b, false):
			return false
	var needle: String = text.strip_edges().to_lower()
	if needle.is_empty():
		return true
	return entry.name.to_lower().contains(needle) or String(entry.id).to_lower().contains(needle)
