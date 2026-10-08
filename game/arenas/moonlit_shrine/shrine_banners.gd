class_name ShrineBanners
extends RefCounted
## The Shrine's nobori (milestone-1 task 131; spec story 152): banners on
## poles standing round the ledge outside the parapet, their cloth dark and
## weathered (black, deep purple, faded ivory), each with a brushed kanji
## column and the gold sagari-fuji mon at its head, no side colours (the
## owner's answers, Oct 7). The project's own art, built in Blender by
## scripts/blender/build_banners_grass.py and brought in by the export
## (MODEL: Nobori<n>_Pole and Nobori<n>_Cloth for each variant n, the pole's
## foot at the origin, the cloth facing +Z). They stand round the ledge at
## ShrineLayout.banners (every 30 degrees, each at its own radius among the
## wisteria's roots), facing the courtyard, the variants in turn; the cloth sways and flutters
## on the layout's wind (LookMaterials.sway(), its weight in the cloth's
## vertex red). They stand beyond the cameras' room (ArenaDef
## camera_max_radius), so none ever comes between a camera and a fighter.

const MODEL: String = "res://assets/exports/shrine/nobori.glb"
const VARIANTS: int = 4
## How far the cloth's free corner leans in a wind of 1 (m), and how far its
## flutter lifts it.
const CLOTH_SWAY: float = 0.35
const CLOTH_FLUTTER: float = 0.05


## The banners under a new Node3D named Banners.
static func build(layout: ShrineLayout) -> Node3D:
	var root := Node3D.new()
	root.name = "Banners"
	var model: Node = (load(MODEL) as PackedScene).instantiate()
	var parts: Array[Array] = []
	for v: int in VARIANTS:
		var pole: MeshInstance3D = model.find_child("Nobori%d_Pole" % v, true, false)
		var cloth: MeshInstance3D = model.find_child("Nobori%d_Cloth" % v, true, false)
		if pole == null or cloth == null:
			push_error("ShrineBanners: %s lacks banner %d" % [MODEL, v])
			model.free()
			return root
		var pole_mats: Array[Material] = []
		for s: int in pole.mesh.get_surface_count():
			pole_mats.append(LookMaterials.prop_from(pole.mesh.surface_get_material(s)))
		var cloth_mat: Material = LookMaterials.sway(cloth.mesh.surface_get_material(0) as BaseMaterial3D,
			layout.wind, CLOTH_SWAY, CLOTH_FLUTTER, true)
		parts.append([pole.mesh, pole_mats, cloth.mesh, cloth_mat])
	model.free()
	var spot_list: PackedVector3Array = spots(layout)
	for i: int in spot_list.size():
		var at: Vector3 = spot_list[i]
		# +Z, the cloth's face, toward the courtyard's centre
		var facing := Basis(Vector3.UP, atan2(-at.x, -at.z))
		var banner := Node3D.new()
		banner.name = "Banner%d" % i
		banner.transform = Transform3D(facing, at)
		root.add_child(banner)
		var p: Array = parts[i % VARIANTS]
		var pole_mi := MeshInstance3D.new()
		pole_mi.name = "Pole"
		pole_mi.mesh = p[0]
		for s: int in (p[1] as Array).size():
			pole_mi.set_surface_override_material(s, p[1][s])
		banner.add_child(pole_mi)
		var cloth_mi := MeshInstance3D.new()
		cloth_mi.name = "Cloth"
		cloth_mi.mesh = p[2]
		cloth_mi.set_surface_override_material(0, p[3])
		banner.add_child(cloth_mi)
	return root


## Every banner's spot on the ledge (its pole's foot).
static func spots(layout: ShrineLayout) -> PackedVector3Array:
	var out := PackedVector3Array()
	for b: Vector2 in layout.banners:
		out.append(ShrineLayout.polar(b.x, b.y, ShrinePlatform.LEDGE_Y))
	return out
