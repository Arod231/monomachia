class_name RigCallback
extends SkeletonModifier3D
## A skeleton modifier that runs a callable, so that one script (FighterRig)
## can work at several points of the modifier stack, before and after the
## IK nodes.

## Called with the skeleton and the frame's delta.
var callback: Callable


func _process_modification_with_delta(delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk != null and callback.is_valid():
		callback.call(sk, delta)
