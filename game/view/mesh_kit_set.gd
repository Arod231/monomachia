class_name MeshKitSet
extends RefCounted
## A set of MeshKits keyed by material name, so a builder can add pieces of
## many props (stone, lacquer, rope...) and end up with one mesh and one draw
## call per material.

var _kits: Dictionary[StringName, MeshKit] = {}


## The kit for key, created on first use.
func kit(key: StringName) -> MeshKit:
	if not _kits.has(key):
		_kits[key] = MeshKit.new()
	return _kits[key]


func keys() -> Array[StringName]:
	return _kits.keys()


## Commits every non-empty kit and adds a MeshInstance3D per kit under parent,
## using materials[key]; a kit with no material is reported and drawn in the
## engine's default. Kits listed in no_shadow don't cast shadows. Returns the
## instances.
func finish(parent: Node3D, materials: Dictionary, no_shadow: Array[StringName] = []) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for key: StringName in _kits:
		var k: MeshKit = _kits[key]
		if k.is_empty():
			continue
		var material := materials.get(key) as Material
		if material == null:
			push_error("MeshKitSet: no material for kit %s" % key)
		var mi := MeshKit.instance(k.commit(), material, not no_shadow.has(key))
		mi.name = String(key).to_pascal_case()
		parent.add_child(mi)
		out.append(mi)
	return out
