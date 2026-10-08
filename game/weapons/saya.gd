class_name Saya
extends Node3D
## The Katana's saya (authored-animation task 11, from godot-rebuild 14.16;
## modelled in milestone-1 task 47): black lacquer with faint maki-e grasses
## and horn fittings, grown round the blade in Blender
## (scripts/blender/build_katana.py) and brought in by the export (SCENE).
## Its frame is the sheathed katana's (grip at the origin, blade +Y, edge +X;
## see WeaponLook), so placing the katana at the saya's transform puts the
## blade inside it. FighterModel makes one whenever the Katana is the weapon
## and FighterRig carries it at the left hip (FRAMES), riding the hips.
##
## Its sageo, the cord through the kurikata, hangs on the model's own rig
## (Sageo0 to Sageo5), swung by a SpringBoneSimulator3D (CORD_*), in the
## side's dye (FighterPalette.cord_color; tint()).

## Where the saya sits on each fighter, in their Hips bone's frame: the
## katana's frame as the sheathe clip (SheatheHips01_R, frame 12, the blade
## all the way in) leaves it on each body, measured with the weapon fixed in
## the hand (tools: _scratch probes; the numbers are ours, not the pack's),
## each offset grown on KE task 3's taller bodies by as much as the same
## probe's hand moved (the turns kept).
## A fighter without its own uses the Hunter's.
const FRAMES: Dictionary[StringName, Transform3D] = {
	&"hunter": Transform3D(Basis(Vector3(0.2321, -0.7617, 0.6049), Vector3(0.2295, -0.5614, -0.7951), Vector3(0.9452, 0.3234, 0.0445)), Vector3(0.1923, 0.2124, 0.3250)),
	&"rogue": Transform3D(Basis(Vector3(0.2321, -0.7617, 0.6049), Vector3(0.2295, -0.5614, -0.7951), Vector3(0.9452, 0.3234, 0.0445)), Vector3(0.2584, 0.2025, 0.3371)),
}
## The modelled saya: a rig (SayaRoot, then Sageo0-5) holding the
## mesh "Saya" (Saya_Lacquer, Saya_Horn) and the cord, "Sageo" (sageo).
const SCENE: PackedScene = preload("res://assets/exports/weapons/katana_saya.glb")
## The sageo's swing: its bones (<CORD>0 to <CORD>5), the length past the
## last bone, stiffness, drag, gravity (m/s²) and each joint's radius.
const CORD: String = "Sageo"
const CORD_BONES: int = 6
const CORD_END: float = 0.03
const CORD_STIFFNESS: float = 1.2
const CORD_DRAG: float = 0.4
const CORD_GRAVITY: float = 3.0
const CORD_RADIUS: float = 0.005

## The rig the sageo hangs on, and the springs swinging it.
var cord_rig: Skeleton3D
var springs: SpringBoneSimulator3D
var _saya: MeshInstance3D
var _cord: MeshInstance3D


## A saya with its sageo in `cord_color`.
static func build(cord_color: Color) -> Saya:
	var saya: Saya = Saya.new()
	saya.name = &"Saya"
	var model: Node3D = SCENE.instantiate()
	saya.add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		mi.layers = 1 | LookPalette.FIGHTER_LAYER
		var physical: Array[Material] = []
		for s: int in mi.mesh.get_surface_count():
			physical.append(LookMaterials.weapon_from(mi.mesh.surface_get_material(s)))
			mi.set_surface_override_material(s, physical[s])
		# kept in the metadata too, as WeaponLook.instantiate() does
		mi.set_meta(&"look_materials", physical)
		if mi.name == &"Saya":
			saya._saya = mi
		elif mi.name == &"Sageo":
			saya._cord = mi
	var rigs: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		saya.cord_rig = rigs[0]
		saya.springs = _cord_springs(saya.cord_rig)
	saya.tint(cord_color)
	return saya


static func _cord_springs(rig: Skeleton3D) -> SpringBoneSimulator3D:
	var sim: SpringBoneSimulator3D = SpringBoneSimulator3D.new()
	sim.name = &"SageoSprings"
	rig.add_child(sim)
	sim.setting_count = 1
	sim.set_root_bone_name(0, CORD + "0")
	sim.set_end_bone_name(0, CORD + str(CORD_BONES - 1))
	sim.set_extend_end_bone(0, true)
	sim.set_end_bone_length(0, CORD_END)
	sim.set_stiffness(0, CORD_STIFFNESS)
	sim.set_drag(0, CORD_DRAG)
	sim.set_gravity(0, CORD_GRAVITY)
	sim.set_radius(0, CORD_RADIUS)
	return sim


## Dyes the sageo.
func tint(cord_color: Color) -> void:
	var m: ShaderMaterial = cord_material()
	if m != null:
		m.set_shader_parameter(&"base_color", cord_color)


## The sageo's material in the look, or null.
func cord_material() -> ShaderMaterial:
	return _cord.get_surface_override_material(0) as ShaderMaterial if _cord != null else null


## The lacquer's material in the look.
func lacquer() -> ShaderMaterial:
	return _saya.get_surface_override_material(0) as ShaderMaterial


## The saya's box (the scabbard, without its cord) in its own frame.
func bounds() -> AABB:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = _saya
	while n != self and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf * _saya.get_aabb()


## The saya's frame on fighter `fighter_id`, in its Hips bone's frame.
static func frame_for(fighter_id: StringName) -> Transform3D:
	return FRAMES.get(fighter_id, FRAMES[&"hunter"])
