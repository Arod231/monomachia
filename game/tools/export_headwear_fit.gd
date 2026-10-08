extends SceneTree
## Measures the Hunter's head and neck for his Blender headwear (milestone-1
## task 46) and writes them to scripts/blender/headwear/hunter_fit.json, which
## scripts/blender/build_headwear.py builds the tricorn and the scarf from:
##
## - hat: the tricorn's frame (at the band, tipped forward over the brow, as
##   tools/build_headwear.gd fitted it) in Head-bone space, the head's outline
##   at the band (half-widths rx, rz, centre zc) and the crown's height, the
##   brim's lengths, and the chin in the hat's frame (where the cords tie);
## - neck: in Neck-bone space, the neck's outline at heights from the
##   collar to under the jaw (where today's scarf covered), and the back's
##   line below it (where the tails hang).
##
## All in metres, in Godot's axes (y up, z forward).
##
## Run: node scripts/godot.mjs script res://tools/export_headwear_fit.gd

const BuildHeadwear = preload("res://tools/build_headwear.gd")

const OUT: String = "scripts/blender/headwear/hunter_fit.json"
## Heights the neck's outline is measured at, from the collar to the jaw.
const NECK_LEVELS: int = 7
## How far below the Neck bone the back's line is measured (m), and in how
## many steps.
const BACK_DEPTH: float = 0.6
const BACK_STEPS: int = 12


func _initialize() -> void:
	var fighter: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	var fit: Dictionary = {
		"about": "Milestone-1 task 46: the Hunter's head and neck, measured by game/tools/export_headwear_fit.gd for scripts/blender/build_headwear.py (metres, Godot's axes: y up, z forward).",
		"hat": hat_fit(fighter),
		"neck": neck_fit(fighter),
	}
	fighter.free()
	var path: String = ProjectSettings.globalize_path("res://").path_join("..").path_join(OUT).simplify_path()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("export_headwear_fit: cannot write %s" % path)
		quit(1)
		return
	f.store_string(JSON.stringify(fit, "\t", false) + "\n")
	f.close()
	print("export_headwear_fit: wrote %s" % path)
	quit(0)


static func _xf(t: Transform3D) -> Array:
	return [_v(t.basis.x), _v(t.basis.y), _v(t.basis.z), _v(t.origin)]


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 1e-5), snappedf(v.y, 1e-5), snappedf(v.z, 1e-5)]


static func _points(sk: Skeleton3D, mesh_name: StringName) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var mi: MeshInstance3D = sk.get_node_or_null(NodePath(String(mesh_name)))
	if mi == null:
		return out
	var xf: Transform3D = sk.transform * mi.transform
	for s: int in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


## The tricorn's fit, measured as tools/build_headwear.gd's build_tricorn()
## measured it.
static func hat_fit(fighter: FighterModel) -> Dictionary:
	var sk: Skeleton3D = fighter.skeleton
	var head_rest: Transform3D = sk.transform * sk.get_bone_global_rest(sk.find_bone(&"Head"))
	var brows: MeshInstance3D = sk.get_node(^"Eyebrows")
	var brow_top: float = (sk.transform * brows.transform * brows.get_aabb().end).y
	var pts: PackedVector3Array = BuildHeadwear._head_points(fighter)
	var band_y: float = brow_top + BuildHeadwear.HAT_BAND_ABOVE_BROWS
	var tilt: Basis = Basis(Vector3.RIGHT, deg_to_rad(BuildHeadwear.HAT_FORWARD_TILT_DEG))
	var frame: Transform3D = Transform3D(tilt, Vector3(0.0, band_y, head_rest.origin.z))
	var inv: Transform3D = frame.affine_inverse()
	var rx: float = 0.0
	var zf: float = -INF
	var zb: float = INF
	var top: float = 0.0
	for p: Vector3 in pts:
		var q: Vector3 = inv * p
		top = maxf(top, q.y)
		if absf(q.y) < 0.012:
			rx = maxf(rx, absf(q.x))
			zf = maxf(zf, q.z)
			zb = minf(zb, q.z)
	rx += BuildHeadwear.HAT_CLEARANCE
	var rz: float = (zf - zb) * 0.5 + BuildHeadwear.HAT_CLEARANCE
	# the chin: the head's most forward point on its middle, between 5 and
	# 16 cm below the eyes
	var eyes: Vector3 = BuildHeadwear._eyes_centre(fighter)
	var chin: Vector3 = Vector3(0.0, 0.0, -INF)
	for p: Vector3 in _points(sk, &"Head"):
		if absf(p.x) < 0.015 and p.y < eyes.y - 0.05 and p.y > eyes.y - 0.16 and p.z > chin.z:
			chin = p
	return {
		"to_bone": _xf(head_rest.affine_inverse() * frame),
		"rx": snappedf(rx, 1e-5), "rz": snappedf(rz, 1e-5), "zc": snappedf((zf + zb) * 0.5, 1e-5),
		"crown_h": snappedf(maxf(top + 0.02, 0.1), 1e-5),
		"brim": BuildHeadwear.HAT_BRIM, "front_brim": BuildHeadwear.HAT_FRONT_BRIM,
		"band_height": BuildHeadwear.HAT_BAND_HEIGHT,
		"chin": _v(inv * chin),
	}


## The neck's outline at NECK_LEVELS heights through today's scarf region,
## and the back's line below the neck, in Neck-bone space.
static func neck_fit(fighter: FighterModel) -> Dictionary:
	var sk: Skeleton3D = fighter.skeleton
	var neck_rest: Transform3D = sk.transform * sk.get_bone_global_rest(sk.find_bone(&"Neck"))
	var to_neck: Transform3D = neck_rest.affine_inverse()
	var head_bone: Vector3 = (sk.transform * sk.get_bone_global_rest(sk.find_bone(&"Head"))).origin
	var eyes: Vector3 = BuildHeadwear._eyes_centre(fighter)
	var inside: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in _points(sk, &"Head"):
		if BuildHeadwear._neck_region(p, eyes, head_bone) < 0.0:
			inside.append(to_neck * p)
	var lo: float = INF
	var hi: float = -INF
	for q: Vector3 in inside:
		lo = minf(lo, q.y)
		hi = maxf(hi, q.y)
	var levels: Array = []
	for k: int in NECK_LEVELS:
		var y: float = lerpf(lo + 0.004, hi - 0.004, float(k) / (NECK_LEVELS - 1))
		var x0: float = INF
		var x1: float = -INF
		var z0: float = INF
		var z1: float = -INF
		for q: Vector3 in inside:
			if absf(q.y - y) < 0.008:
				x0 = minf(x0, q.x)
				x1 = maxf(x1, q.x)
				z0 = minf(z0, q.z)
				z1 = maxf(z1, q.z)
		if x0 < x1:
			levels.append({"y": snappedf(y, 1e-5), "cx": snappedf((x0 + x1) * 0.5, 1e-5), "cz": snappedf((z0 + z1) * 0.5, 1e-5),
				"rx": snappedf((x1 - x0) * 0.5, 1e-5), "rz": snappedf((z1 - z0) * 0.5, 1e-5)})
	# the back: the outfit's rearmost point on the spine's line at each depth
	var body: PackedVector3Array = PackedVector3Array()
	for mesh_name: StringName in [&"Male_Ranger_Body", &"Male_Ranger_Body_Belt_1", &"Male_Ranger_Body_Belt_2"]:
		for p: Vector3 in _points(sk, mesh_name):
			body.append(to_neck * p)
	var back: Array = []
	for k: int in BACK_STEPS + 1:
		var y: float = -BACK_DEPTH * float(k) / BACK_STEPS
		var z: float = INF
		for q: Vector3 in body:
			if absf(q.x) < 0.06 and absf(q.y - y) < 0.02:
				z = minf(z, q.z)
		if z < INF:
			back.append([snappedf(y, 1e-5), snappedf(z, 1e-5)])
	return {"levels": levels, "back": back}
