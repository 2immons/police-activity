class_name NpcHitReaction
extends SkeletonModifier3D

var settings: Resource
var _reactions: Dictionary = {}

func add_impulse(bone_name: StringName, world_direction: Vector3, strength: float) -> void:
	var skeleton := get_skeleton()
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var local_direction: Vector3 = skeleton.global_basis.inverse() * world_direction.normalized()
	var rotation_axis := Vector3(local_direction.z, 0.25, -local_direction.x).normalized()
	_reactions[bone] = {
		"offset": Vector3.ZERO,
		"velocity": local_direction * strength * settings.reaction_position_scale,
		"angle": 0.0,
		"angular_velocity": strength * settings.reaction_rotation_scale,
		"axis": rotation_axis,
	}

func clear_reactions() -> void:
	_reactions.clear()

func _process_modification_with_delta(delta: float) -> void:
	if settings == null or _reactions.is_empty():
		return
	var skeleton := get_skeleton()
	var finished: Array[int] = []
	for bone: int in _reactions:
		var reaction: Dictionary = _reactions[bone]
		var acceleration: Vector3 = -reaction.offset * settings.reaction_spring - reaction.velocity * settings.reaction_damping
		reaction.velocity += acceleration * delta
		reaction.offset += reaction.velocity * delta
		var angular_acceleration: float = -reaction.angle * settings.reaction_spring - reaction.angular_velocity * settings.reaction_damping
		reaction.angular_velocity += angular_acceleration * delta
		reaction.angle += reaction.angular_velocity * delta
		_reactions[bone] = reaction
		var pose := skeleton.get_bone_pose(bone)
		pose.origin += reaction.offset
		pose.basis *= Basis(Quaternion(reaction.axis, reaction.angle))
		skeleton.set_bone_pose(bone, pose)
		if reaction.offset.length_squared() < 0.000001 and absf(reaction.angle) < 0.001 and reaction.velocity.length_squared() < 0.0001:
			finished.append(bone)
	for bone in finished:
		_reactions.erase(bone)
