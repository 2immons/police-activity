class_name NpcCombatPose
extends SkeletonModifier3D

@export var npc: CharacterBody3D

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(npc) or npc.dead or not is_instance_valid(npc.weapon):
		return
	var skeleton := get_skeleton()
	for side in ["Right", "Left"]:
		_solve_arm(skeleton, side, npc.weapon.get_node("Grip" + side).global_position)

func _solve_arm(skeleton: Skeleton3D, side: String, world_target: Vector3) -> void:
	var upper := skeleton.find_bone(side + "UpperArm")
	var lower := skeleton.find_bone(side + "LowerArm")
	var hand := skeleton.find_bone(side + "Hand")
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(lower).origin
	var c := skeleton.get_bone_global_pose(hand).origin
	var target: Vector3 = skeleton.global_transform.affine_inverse() * world_target
	var length_a := a.distance_to(b)
	var length_b := b.distance_to(c)
	var direction := (target - a).normalized()
	var distance := clampf(a.distance_to(target), 0.01, length_a + length_b - 0.002)
	var pole := Vector3(-0.35 if side == "Right" else 0.35, -0.55, -0.25)
	pole -= direction * pole.dot(direction)
	pole = pole.normalized()
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(length_a * length_a - along * along, 0.0))
	var desired_elbow := a + direction * along + pole * height
	_rotate_bone_toward(skeleton, upper, b - a, desired_elbow - a)
	skeleton.force_update_bone_child_transform(upper)
	b = skeleton.get_bone_global_pose(lower).origin
	c = skeleton.get_bone_global_pose(hand).origin
	_rotate_bone_toward(skeleton, lower, c - b, target - b)

func _rotate_bone_toward(skeleton: Skeleton3D, bone: int, current: Vector3, desired: Vector3) -> void:
	if current.length_squared() < 0.0001 or desired.length_squared() < 0.0001:
		return
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var correction := Quaternion(current.normalized(), desired.normalized())
	var global_basis := Basis(correction) * skeleton.get_bone_global_pose(bone).basis
	var pose := skeleton.get_bone_pose(bone)
	pose.basis = parent_basis.inverse() * global_basis
	skeleton.set_bone_pose(bone, pose)
