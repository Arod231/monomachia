extends SceneTree
## The bake command (authored-animation task 6, milestone-1 task 16): bakes
## each move the move-clip table (MoveClips) fits to a clip into its
## weapon's swing file, game/sim/moves/swings/<weapon>.json, from HumanM on
## the Hunter (ClipPoser), and in the same run writes the frame-data table
## (FrameDataTable, game/sim/moves/frame_data.json): each move's row
## generated from its clip at 1.0x by its markers (FrameDataGenerator; a
## stand-in's clip sampled on today's timing), each gait clip's measured
## speed and each rules-length clip's length (FrameDataRows). It prints a
## report of each move's frames against today's. Needs the clip libraries
## (`node scripts/godot.mjs clips`) and, for the source checksums, the packs.
##
##   node scripts/godot.mjs bake [--weapon=<id>] [--check]
##
## - --weapon: only that weapon (default: every weapon with a move fitted);
## - --check: write nothing; exit 1 if a file (a swing file or the table)
##   would change.
##
## A Katana or bare-hands move a family has re-keyed is led by its clip
## (AttackDef.led_by_clip(), milestone-1 task 21): its swing is sampled
## relative to the moving body, which its travel moves, and has no reach
## push. Each other move's reach is corrected toward the reach rule
## (SwingBake.correct_reach(); the report gives the blade inside the defender before
## and after, and marks a move that needs more than 15 cm), and the Rogue
## playing HumanF is measured against the path (SwingBake.drift()): past
## 5 cm the swing says she plays HumanM. A move's swing is the generator's
## when its move data's frames are the table's; until they are (the move
## data set them until task 17), its swing stays baked on today's timing
## (SwingBake.bake() at its speed), and the report says so. Moves of the
## file the table doesn't fit (baked before) are kept; the guard is read
## afresh from the weapon's idle clip. Exits 2 without the libraries.

const SET: StringName = &"HumanM"
## The Rogue's own clip set, measured against the Hunter's path.
const ROGUE_SET: StringName = &"HumanF"
const EXIT_NO_LIBRARIES: int = 2


func _initialize() -> void:
	# the fighters' skeletons pose only once the main loop runs
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: StringName = &""
	for a: String in args:
		if a.begins_with("--weapon="):
			only = StringName(a.substr(9))
	quit(run(only, args.has("--check")))


## Bakes the table's weapons (or only `only`) and writes their files, or
## with `check` compares them, printing the report. Returns the exit code.
func run(only: StringName, check: bool) -> int:
	var out: Dictionary = bake(only, check, root)
	for line: String in out["report"]:
		print(line)
	for line: String in out["errors"]:
		printerr(line)
	return out["code"]


## The bake itself, run under `parent` (the command's root, or the Studio's
## save, milestone-1 task 27): {"code": the exit code, "report": the lines it
## prints, "errors": the lines it complains with}.
static func bake(only: StringName, check: bool, parent: Node) -> Dictionary:
	var lines: PackedStringArray = []
	var complaints: PackedStringArray = []
	var code: int = _bake(only, check, parent, lines, complaints)
	return {"code": code, "report": lines, "errors": complaints}


static func _bake(only: StringName, check: bool, parent: Node, lines: PackedStringArray, complaints: PackedStringArray) -> int:
	if not ClipLibraries.available():
		complaints.append("bake_swings: no clip libraries; run `node scripts/godot.mjs clips` (needs the packs, see .assets-src-path)")
		return EXIT_NO_LIBRARIES
	var manifest: ClipManifest = ClipManifest.read()
	var table: MoveClips = MoveClips.read(manifest)
	if not manifest.errors.is_empty() or not table.errors.is_empty():
		complaints.append("bake_swings: mistakes in the tables:\n  " + "\n  ".join(manifest.errors + table.errors))
		return 1
	if only != &"" and not table.moves.has(only):
		complaints.append("bake_swings: %s is not in the move-clip table" % only)
		return 1
	var code: int = 0
	var old_table: FrameDataTable = FrameDataTable.read()
	var rows: Dictionary = {}
	for wid: StringName in Moves.WEAPONS:
		if old_table.moves.has(String(wid)):
			rows[String(wid)] = old_table.moves[String(wid)]
	for wid: StringName in table.moves:
		if (only != &"" and wid != only) or table.of(wid).is_empty():
			continue
		var path: String = SwingFile.path_for(wid)
		var old: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var out: Dictionary = bake_weapon(wid, table, manifest, parent, old)
		lines.append("%s:\n  %s" % [wid, "\n  ".join(out["report"])])
		if not (out["errors"] as Array).is_empty():
			complaints.append("bake_swings: %s:\n  %s" % [wid, "\n  ".join(out["errors"])])
			code = 1
			continue
		rows[String(wid)] = out["rows"]
		if check:
			if out["text"] != old:
				complaints.append("bake_swings: %s differs from a fresh bake" % path)
				code = 1
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SwingFile.DIR))
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(out["text"])
		f.close()
		lines.append("  wrote %s" % path)
	if code != 0:
		return code
	var extras: Dictionary = bake_extras(manifest, parent)
	if not (extras["errors"] as Array).is_empty():
		complaints.append("bake_swings: the table:\n  %s" % "\n  ".join(extras["errors"]))
		return 1
	var ordered: Dictionary = {}
	for wid: StringName in Moves.WEAPONS:
		if rows.has(String(wid)):
			ordered[String(wid)] = rows[String(wid)]
	var text: String = FrameDataRows.table_text(ordered, extras["gaits"], extras["clips"], FrameDataRows.NOT_KEYED_YET)
	var old_text: String = FileAccess.get_file_as_string(FrameDataTable.PATH) if FileAccess.file_exists(FrameDataTable.PATH) else ""
	if check:
		if text != old_text:
			complaints.append("bake_swings: %s differs from a fresh bake" % FrameDataTable.PATH)
			code = 1
		return code
	var f: FileAccess = FileAccess.open(FrameDataTable.PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	lines.append("wrote %s" % FrameDataTable.PATH)
	return code


## The table's gait and rules-length clip rows, measured on a Hunter put
## under `parent` (and freed after): {"gaits": {...}, "clips": {...},
## "errors": [...]}.
static func bake_extras(manifest: ClipManifest, parent: Node) -> Dictionary:
	var errors: Array[String] = []
	var model: FighterModel = FootContacts.hunter(parent)
	var gaits: Dictionary = {}
	for id: StringName in FrameDataRows.gait_clips():
		var clip: ClipManifest.Clip = manifest.clips[id]
		var poser: ClipPoser = ClipPoser.new(model, [ClipChain.qualified(SET, String(id))] as Array[String])
		var sha: String = FrameDataRows.source_checksum(manifest, [id] as Array[StringName], errors)
		var row: Dictionary = FrameDataRows.gait_row(FrameDataGenerator.gait(poser.pose, poser.length, clip.foot_contacts),
			poser.length, clip.foot_contacts, sha)
		gaits[String(id)] = FrameDataRows.sealed(row, null)
	var clips: Dictionary = {}
	for id: StringName in FrameDataRows.rules_length_clips(manifest):
		var length: float = model.animation_player.get_animation(ClipChain.anim_name(SET, id)).length
		var sha: String = FrameDataRows.source_checksum(manifest, [id] as Array[StringName], errors)
		clips[String(id)] = FrameDataRows.sealed(FrameDataRows.clip_row(manifest.clips[id], length, sha), null)
	parent.remove_child(model)
	model.free()
	return {"gaits": gaits, "clips": clips, "errors": errors}


## Bakes weapon `wid`'s moves the table fits, on a Hunter put under
## `parent` (and freed after), over the swing file text `old` (empty for
## none): {"text": the new file, "rows": each move with markers' row of the
## frame-data table, sealed with its swing, "report": a line per move,
## "errors": []}.
static func bake_weapon(wid: StringName, table: MoveClips, manifest: ClipManifest, parent: Node, old: String) -> Dictionary:
	var weapon: WeaponDef = Moves.WEAPONS[wid]
	var errors: Array[String] = []
	var report: PackedStringArray = []
	var model: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	model.autoplay_idle = false
	parent.add_child(model)
	if WeaponLook.IDS.has(wid):
		model.attach_weapon(WeaponLook.load_id(wid))
	model.animation_player.add_animation_library(SET, ClipLibraries.load_set(SET))
	var rogue: FighterModel = FighterLook.instantiate_fighter(&"rogue")
	rogue.autoplay_idle = false
	parent.add_child(rogue)
	if WeaponLook.IDS.has(wid):
		rogue.attach_weapon(WeaponLook.load_id(wid))
	rogue.animation_player.add_animation_library(ROGUE_SET, ClipLibraries.load_set(ROGUE_SET))
	rogue.animation_player.add_animation_library(SET, ClipLibraries.load_set(SET))
	var kept: Dictionary = {}
	if old != "":
		var data: Variant = JSON.parse_string(old)
		if data is Dictionary and (data as Dictionary).get("swings") is Dictionary:
			kept = data["swings"]
	var baked: Dictionary = {}
	var rows: Dictionary = {}
	var entries: Dictionary = table.of(wid)
	for id: StringName in entries:
		var e: MoveClips.Entry = entries[id]
		var move: AttackDef = weapon.moves[id]
		var chain: Array[String] = []
		var lengths: PackedFloat64Array = PackedFloat64Array()
		var by_id: Dictionary = {}
		var contacts_of: Dictionary = {}
		var ids: Array[StringName] = []
		for clip: StringName in e.clips:
			chain.append(ClipChain.qualified(SET, String(clip)))
			var cid: StringName = ClipChain.parse(String(clip), [] as Array[String]).id
			var whole: String = ClipChain.anim_name(SET, cid)
			lengths.append(model.animation_player.get_animation(whole).length * ClipManifest.SOURCE_FPS)
			by_id[cid] = lengths[-1]
			if manifest.clips.has(cid):
				contacts_of[cid] = (manifest.clips[cid] as ClipManifest.Clip).foot_contacts
			if not ids.has(cid):
				ids.append(cid)
		var poser: ClipPoser = ClipPoser.new(model, chain)
		var markers: Dictionary = MoveClips.markers(e, manifest, lengths)
		var speed: float = e.speed if not is_nan(e.speed) else SwingBake.pick_speed(markers, move.startup)
		var parts: Array[StringName] = SwingBake.parts_for(move, weapon)
		var why: Array[String] = []
		var layout: Array[ClipChain.Part] = ClipChain.lay_out(e.clips, by_id, why)
		var contacts: Dictionary = FrameDataGenerator.chain_contacts(layout, contacts_of)
		var gen: FrameDataGenerator.Result = null
		var retime: ClipTiming = null
		# the generator's swing once the move data's frames are the table's;
		# until then today's, baked first, so its samples are today's
		var fd: Dictionary = MoveClips.frame_data(e.markers) if not e.markers.is_empty() else {}
		var generated: bool = not fd.is_empty() and fd["startup"] == move.startup and fd["active"] == move.active 			and fd["recovery"] == move.recovery
		# a move led by its clip moves by its travel: its swing sampled relative
		# to the moving body, and no reach push (milestone-1 task 21)
		var led: bool = not e.markers.is_empty() and AttackDef.led_by_clip(wid, e.markers_stand_in, move.special)
		var r: SwingBake.Result = null
		if not generated:
			r = SwingBake.bake(poser.pose, poser.length, markers, speed, parts, why)
			if r == null:
				errors.append("%s: %s" % [id, "; ".join(why)])
				continue
		if not e.markers.is_empty():
			retime = SwingBake.timing(markers, speed, why) if e.markers_stand_in else _one_times(e.markers, why)
			if retime != null:
				gen = FrameDataGenerator.generate(poser.pose, poser.length, e.markers, contacts, parts, why, led,
					retime if e.markers_stand_in else null)
			if gen == null:
				errors.append("%s: %s" % [id, "; ".join(why)])
				continue
		if generated:
			r = _result(gen, retime)
		# the Rogue's HumanF clip against HumanM on her own body: her smaller
		# body holds any clip's blade some way off the Hunter's path, which
		# her hand IK closes; what flags a move is her clip moving otherwise
		var own_chain: Array[String] = []
		for clip: StringName in e.clips:
			own_chain.append(ClipChain.qualified(ROGUE_SET, String(clip)))
		var own: ClipPoser = ClipPoser.new(rogue, own_chain)
		var hunters: ClipPoser = ClipPoser.new(rogue, chain)
		var on_her: SwingBake.Result = _result(FrameDataGenerator.generate(hunters.pose, hunters.length, e.markers, contacts, parts, why, led,
			retime if e.markers_stand_in else null), retime) if generated \
			else SwingBake.bake(hunters.pose, hunters.length, markers, speed, parts, why)
		if on_her == null:
			errors.append("%s on the Rogue: %s" % [id, "; ".join(why)])
			continue
		var drift: float = SwingBake.drift(on_her, own.pose)
		var off_path: float = SwingBake.drift(r, own.pose)
		r.rogue_humanm = drift > SwingBake.ROGUE_DRIFT
		var line: String = SwingBake.report_line(id, " + ".join(e.clips), r.timing, move)
		if gen != null and not generated:
			line += "\n      the table: startup %d, active %d, recovery %d at 1.0x; the swing stays on today's timing until the move data take the table's frames (task 17)" % [
				gen.startup, gen.active, gen.recovery]
		if led:
			line += "\n      moved by its travel (%.2f m forward by the end of its active frames): no reach push" % _forward(gen, move)
		elif move.damage > 0.0 or move.posture > 0.0:
			var reach: SwingBake.Reach = SwingBake.correct_reach(r, move, weapon)
			line += "\n      reach from %.1f m: %s inside, %s after a %.1f cm push%s%s; first touch on frame %d" % [
				reach.distance, _cm(reach.before), _cm(reach.after), V3.length(reach.offset) * 100.0,
				"  <- needs more than 15 cm: another clip or a lunge" if reach.short else "",
				"  <- over 20 cm inside" if reach.over else "", reach.first_touch]
			if reach.short:
				line += "\n      " + _shortfall(r, move, weapon, reach.distance)
		line += "\n      Rogue: HumanF %.1f cm off HumanM on her body (%.1f cm off the Hunter's path)%s" % [
			drift * 100.0, off_path * 100.0, ": she plays HumanM" if r.rogue_humanm else ""]
		r.clips = e.clips
		r.fallback = e.fallback
		r.loop = e.loop
		if e.sheathed.size() == 2:
			r.sheathed = SwingBake.sheathed_frames(r, e.sheathed[0], e.sheathed[1])
			if r.sheathed.size() == 2:
				line += "\n      sheathed on frames %d-%d" % [r.sheathed[0], r.sheathed[1]]
		baked[String(id)] = r.record()
		if gen != null:
			var sha: String = FrameDataRows.source_checksum(manifest, ids, errors)
			rows[String(id)] = FrameDataRows.move_row(FrameDataRows.kind_of(weapon, id), layout, e.markers_stand_in, gen, sha)
		report.append(line)
	# the moves in their weapon's order, those not baked now kept as they were
	var swings: Dictionary = {}
	var used: Dictionary[StringName, bool] = {}
	for id: StringName in weapon.moves:
		var record: Variant = baked.get(String(id), kept.get(String(id)))
		if record == null:
			continue
		swings[String(id)] = record
		for part: Variant in (record as Dictionary)["tracks"]:
			used[StringName(str(part))] = true
	var guard_poses: Dictionary = ClipPoser.new(model, ["%s/%s" % [SET, table.guards[wid]]] as Array[String]).pose(0.0)
	var guard: Dictionary = {}
	for part: StringName in guard_poses:
		if used.has(part):
			guard[part] = guard_poses[part]
	for m: FighterModel in [model, rogue]:
		parent.remove_child(m)
		m.free()
	var text: String = SwingBake.file_text(SwingBake.guard_record(guard), swings) if not swings.is_empty() else old
	# each row sealed with its swing as the file reads back
	var read: Variant = JSON.parse_string(text) if text != "" else null
	var sealed: Dictionary = {}
	for id: StringName in weapon.moves:
		if rows.has(String(id)):
			var record: Variant = (read["swings"] as Dictionary).get(String(id)) if read is Dictionary else null
			sealed[String(id)] = FrameDataRows.sealed(rows[String(id)], record)
	return {"text": text, "rows": sealed, "report": report, "errors": errors}


## The timing a move with real markers plays on: its markers at 1.0x (the
## wind-up start, the active frames' start and end as the contact and its
## end, and the settle; a charge's hold is left out, so a charge holds
## wherever its check frame falls).
static func _one_times(markers: Dictionary, errors: Array[String]) -> ClipTiming:
	return ClipTiming.make({"windup": markers["windup"], "contact": markers["active_start"],
		"contact_end": markers["active_end"], "settle": markers["settle"]}, 1.0, errors)


## A generated move as the bake's result, timed by `timing` (what the view
## plays it on); null for none.
static func _result(gen: FrameDataGenerator.Result, timing: ClipTiming) -> SwingBake.Result:
	if gen == null:
		return null
	var r: SwingBake.Result = SwingBake.Result.new()
	r.timing = timing
	r.times = gen.times
	r.tracks = gen.tracks
	return r


## How far forward `gen`'s travel carries the body by the end of `move`'s
## active frames (m), for the report.
static func _forward(gen: FrameDataGenerator.Result, move: AttackDef) -> float:
	var at: float = 0.0
	for f: int in range(1, mini(gen.forward.size(), move.startup + move.active + 1)):
		at += gen.forward[f]
	return at


## How much further a move that falls short even with the whole push needs
## to go: the distance it first touches from with it (scanned down in 5 cm
## steps from `distance`), and so the extra lunge.
static func _shortfall(r: SwingBake.Result, move: AttackDef, weapon: WeaponDef, distance: float) -> String:
	# r already carries the whole push (correct_reach())
	var push: V3 = V3.make()
	var d: float = distance
	while d > 0.5:
		d -= 0.05
		if (SwingBake._measure(r, move, weapon, d, push)[0] as float) >= 0.0:
			return "with the push it first touches from %.2f m: about %.0f cm more lunge" % [d, (distance - d) * 100.0]
	return "it touches from nowhere above 0.5 m"


static func _cm(inside: float) -> String:
	return "no touch" if inside < 0.0 else "%.1f cm" % (inside * 100.0)
