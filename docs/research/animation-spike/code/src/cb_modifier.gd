extends SkeletonModifier3D
# A SkeletonModifier3D that runs a callable. Lets one script own logic that must run at two
# points of the modifier stack (before and after the IK nodes).
var callback: Callable

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk and callback.is_valid():
		callback.call(sk, delta)
