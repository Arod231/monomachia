extends GutTest
## Foot slide in every gait (milestone-1 task 55, story 81): the rules move
## the Hunter at each gait clip's own measured speed and the clip plays at
## 1.0x; how far a planted foot slides from where it came down, on the final
## pose in the world, by task 9's measure (PoseCheck.FootTrack: planted by
## FootLock's ankle-height rule). The packs' gaits don't reach the
## checklist's 1 cm (PoseCheck.FOOT_SLIDE_MAX): the walks' heels roll over
## the toes while the rule still counts the foot planted, and the strafes
## sweep their feet about 3 degrees off square. On the owner's word (Oct 8)
## each gait is held to the slide it had when task 55 landed (CEILINGS, its
## measure plus half a centimetre), so nothing gets worse while family 2's
## review (task 62) decides on new gait clips. Local-only: the gait clips are
## the packs'.

## [stick x, stick y, sprint, what, ceiling (m)]: the ceilings task 55
## recorded.
const GAITS: Array = [
	[0.0, 0.5, false, "walking forward", 0.217], [0.0, -0.5, false, "walking back", 0.185],
	[-0.5, 0.0, false, "walking left", 0.331], [0.5, 0.0, false, "walking right", 0.308],
	[-0.35, 0.35, false, "walking forward-left", 0.22],
	[0.0, 1.0, false, "running forward", 0.022], [-0.7071, 0.7071, false, "running forward-left", 0.019],
	[-1.0, 0.0, false, "running left", 0.125], [1.0, 0.0, false, "running right", 0.125],
	[0.0, -1.0, false, "running back", 0.033], [0.7071, -0.7071, false, "running back-right", 0.062],
	[-0.7071, -0.7071, false, "running back-left", 0.061], [0.0, 1.0, true, "sprinting", 0.056],
]


func after_each() -> void:
	SimHelpers.dispose_all()


func test_local_no_gait_slides_further_than_task_55_recorded() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	for g: Array in GAITS:
		var worst: float = await _worst_slide(g[0], g[1], g[2])
		gut.p("%s: worst slide %.2f cm (the checklist's %.0f cm: %s)" % [g[3], worst * 100.0, PoseCheck.FOOT_SLIDE_MAX * 100.0,
			"met" if worst < PoseCheck.FOOT_SLIDE_MAX else "not met"])
		assert_lt(worst, float(g[4]), "%s: worst slide %.2f cm, no more than task 55 recorded" % [g[3], worst * 100.0])


## The worst planted foot's slide (m) over a second of the Hunter moving
## with the stick at (mx, my), once up to speed, starting where it has room
## inside the arena's wall: from 28 m apart going forward, 3 m apart going
## back, 10 m apart circling.
func _worst_slide(mx: float, my: float, sprint: bool) -> float:
	var gap: float = 28.0 if my > 0.1 else (3.0 if my < -0.1 else 10.0)
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, gap)
	var f: Fighter = W.fighters[0]
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(&"hunter", 0, &"katana", 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var check: PoseCheck = PoseCheck.new(v.model)
	var track: PoseCheck.FootTrack = PoseCheck.FootTrack.new(check)
	var input: RawInput = SimHelpers.move(mx, my, Btn.SPRINT) if sprint else SimHelpers.move(mx, my)
	var worst: float = 0.0
	for i: int in 90:
		W.step([input, SimHelpers.idle()])
		v.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		var frame: PoseCheck.Frame = await PoseCheck.frame_of(v.model)
		var slid: Dictionary[String, float] = track.step(frame)
		if i < 30:
			continue
		for side: String in slid:
			worst = maxf(worst, slid[side])
	return worst
