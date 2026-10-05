class_name FighterBuilder
extends RefCounted
# Assembles the Rogue: head-only female body + Ranger outfit parts + hair on ONE Skeleton3D
# (the body's retargeted GeneralSkeleton), plus an AnimationPlayer holding the UAL libraries.

const PARTS: Array[String] = ["Arms", "Body", "Legs", "Feet", "Head_Hood", "Acc_Pauldrons"]
static var _libs := {}
static var _mat_cache := {}

static func anim_libraries() -> Dictionary:
	if _libs.is_empty():
		for pair in [["ual1", "res://assets/anim/UAL1_Standard.glb"], ["ual2", "res://assets/anim/UAL2_Standard.glb"]]:
			var s: Node = (load(pair[1]) as PackedScene).instantiate()
			var ap: AnimationPlayer = s.find_child("AnimationPlayer", true, false)
			_libs[pair[0]] = ap.get_animation_library("")
			s.free()
		# loop flags are inconsistent in the packs: set the ones we use
		for n in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle"]:
			var a: Animation = _libs["ual1"].get_animation(n)
			a.loop_mode = Animation.LOOP_LINEAR
	return _libs

static func build(hair: String = "Hair_Long", outfit_tex: String = "res://assets/ranger/T_Rogue_BaseColor.png", head_cut: bool = true, parts: Array[String] = PARTS) -> Node3D:
	var model: Node3D = (load("res://assets/body/Superhero_Female_FullBody.gltf") as PackedScene).instantiate()
	model.name = "Model"
	var skel: Skeleton3D = model.find_child("GeneralSkeleton", true, false)
	var body: MeshInstance3D = skel.get_node("Superhero_Female")
	if head_cut:
		body.mesh = load("res://gen/head_only.res")
	var tex: Texture2D = load(outfit_tex) if outfit_tex != "" else null
	for p in parts:
		var ps: Node = (load("res://assets/ranger/Female_Ranger_%s.gltf" % p) as PackedScene).instantiate()
		_steal_meshes(ps, skel, tex)
		ps.free()
	if hair != "":
		var hs: Node = (load("res://assets/hair/%s.gltf" % hair) as PackedScene).instantiate()
		_steal_meshes(hs, skel, null)
		hs.free()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	model.add_child(ap)
	var libs := anim_libraries()
	for k in libs:
		ap.add_animation_library(k, libs[k])
	return model

static func _steal_meshes(scene: Node, skel: Skeleton3D, outfit_tex: Texture2D) -> void:
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := m.transform
		m.get_parent().remove_child(m)
		m.owner = null
		skel.add_child(m)
		m.transform = xf
		m.skeleton = NodePath("..")
		if outfit_tex:
			for s in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(s) as BaseMaterial3D
				if mat and mat.albedo_texture and mat.albedo_texture.resource_path.contains("T_Ranger_BaseColor"):
					var key := mat.get_instance_id()
					if not _mat_cache.has(key):
						var d := mat.duplicate() as BaseMaterial3D
						d.albedo_texture = outfit_tex
						_mat_cache[key] = d
					m.set_surface_override_material(s, _mat_cache[key])
