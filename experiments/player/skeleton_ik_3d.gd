extends SkeletonModifier3D

@export var look_controller: PlayerLookController
@export var body_environment: BodyEnvironmentInteractionController
@export var head_bone_name := "Head"
@export var neck_bone_name := "Neck"
@export var chest_bone_name := "UpperChest"
@export var spine_bone_name := "Spine"
@export var middle_chest_bone_name := "Chest"
@export_range(0.0, 80.0, 1.0) var eye_yaw_range_degrees := 20.0
@export_range(0.0, 80.0, 1.0) var eye_pitch_range_degrees := 20.0
@export_range(20.0, 150.0, 1.0) var rear_turn_start_degrees := 85.0
@export_range(1.0, 40.0, 1.0) var rear_turn_blend_degrees := 10.0

@export var head_yaw_weight := 0.58
@export var neck_yaw_weight := 0.25
@export var chest_yaw_weight := 0.17
@export_group("Armed upper-body follow")
@export var armed_head_yaw_weight := 0.25
@export var armed_neck_yaw_weight := 0.15
@export var armed_chest_yaw_weight := 0.60
@export var head_pitch_weight := 0.65
@export var neck_pitch_weight := 0.25
@export var chest_pitch_weight := 0.10

var _head_idx := -1
var _neck_idx := -1
var _chest_idx := -1
var _spine_idx := -1
var _middle_chest_idx := -1

func _ready() -> void:
	var skeleton := get_skeleton()
	_head_idx = skeleton.find_bone(head_bone_name)
	_neck_idx = skeleton.find_bone(neck_bone_name)
	_chest_idx = skeleton.find_bone(chest_bone_name)
	_spine_idx = skeleton.find_bone(spine_bone_name)
	_middle_chest_idx = skeleton.find_bone(middle_chest_bone_name)
	assert(_head_idx >= 0 and _neck_idx >= 0 and _chest_idx >= 0, "Look bones missing from skeleton")
	assert(_spine_idx >= 0 and _middle_chest_idx >= 0, "Torso bones missing from skeleton")
	assert(is_instance_valid(look_controller), "Assign the camera look controller")
	assert(is_instance_valid(body_environment), "Assign BodyEnvironmentInteraction")

func _process_modification() -> void:
	if not is_instance_valid(look_controller):
		return
	var skeleton := get_skeleton()
	var weights := get_yaw_weights()
	# Spread the torso twist along the spine; hips and legs keep their animated pose.
	_apply_rotation(skeleton, _spine_idx, weights.z * 0.30, 0.0)
	_apply_rotation(skeleton, _middle_chest_idx, weights.z * 0.35, 0.0)
	_apply_rotation(skeleton, _chest_idx, weights.z * 0.35, chest_pitch_weight)
	_apply_rotation(skeleton, _neck_idx, weights.y, neck_pitch_weight)
	_apply_rotation(skeleton, _head_idx, weights.x, head_pitch_weight)
	_apply_wall_squeeze(skeleton)
	_apply_lean(skeleton)

func _apply_wall_squeeze(skeleton: Skeleton3D) -> void:
	var player = look_controller.get_parent()
	var environment := body_environment
	if is_zero_approx(environment.wall_squeeze_angle) and is_zero_approx(environment.collision_reflex_impulse):
		return
	# Rotate the complete spine subtree as one shoulder belt. Hips and legs keep
	# their locomotion pose while chest, shoulders and arms pass the obstacle.
	var world_up_local := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
	var pose := skeleton.get_bone_global_pose(_spine_idx)
	pose.basis = Basis(world_up_local, environment.wall_squeeze_angle) * pose.basis
	var squeeze_ratio: float = environment.wall_squeeze_angle / maxf(deg_to_rad(environment.settings.max_torso_yaw_degrees), 0.001)
	var player_side_local: Vector3 = skeleton.global_basis.inverse() * player.global_basis.x
	pose.origin -= player_side_local * squeeze_ratio * environment.settings.torso_side_offset
	if environment.collision_reflex_impulse > 0.0:
		var impact_forward_local: Vector3 = skeleton.global_basis.inverse() * environment.collision_reflex_direction
		pose.origin -= impact_forward_local * environment.collision_reflex_impulse * environment.settings.impact_chest_offset
	skeleton.set_bone_global_pose(_spine_idx, pose)

func _apply_lean(skeleton: Skeleton3D) -> void:
	# Rotate only the spine subtree around the pelvis: hips and both legs stay animated.
	var hips := skeleton.get_bone_parent(_spine_idx)
	var pivot := skeleton.get_bone_global_pose(hips).origin
	var world_axis: Vector3 = look_controller.get_movement_basis().z.normalized()
	var axis := (skeleton.global_basis.inverse() * world_axis).normalized()
	var rotation := Basis(axis, look_controller.lean_angle)
	var pose := skeleton.get_bone_global_pose(_spine_idx)
	pose.origin = pivot + rotation * (pose.origin - pivot)
	pose.basis = rotation * pose.basis
	skeleton.set_bone_global_pose(_spine_idx, pose)

func get_yaw_weights() -> Vector3:
	var view_degrees: float = absf(rad_to_deg(look_controller.get_body_yaw()))
	var body_degrees := maxf(view_degrees - eye_yaw_range_degrees, 0.0)
	var weapon = look_controller.get_parent().weapon_controller
	var armed: bool = is_instance_valid(weapon) and weapon.equipped and weapon.draw_amount > 0.95 and not look_controller.is_free_looking()
	var base := Vector3(armed_head_yaw_weight, armed_neck_yaw_weight, armed_chest_yaw_weight) if armed else Vector3(head_yaw_weight, neck_yaw_weight, chest_yaw_weight)
	base /= maxf(base.x + base.y + base.z, 0.001)
	if body_degrees <= 0.001:
		return base
	var excess := maxf(view_degrees - maxf(rear_turn_start_degrees, eye_yaw_range_degrees), 0.0)
	var blend := maxf(rear_turn_blend_degrees, 0.001)
	# Continuous angle and slope: gradually transfer further yaw to the torso.
	var torso_extra := excess * excess / (2.0 * blend) if excess < blend else excess - blend * 0.5
	var torso_share := clampf(torso_extra / body_degrees, 0.0, 1.0)
	return base * (1.0 - torso_share) + Vector3(0.0, 0.0, torso_share)

func _apply_rotation(skeleton: Skeleton3D, bone_idx: int, yaw_weight: float, pitch_weight: float) -> void:
	if bone_idx < 0:
		return
	# Apply after animation; convert world look axes to this animated bone's axes.
	var world_offset: Basis = look_controller.get_world_look_offset(
		yaw_weight, pitch_weight,
		deg_to_rad(eye_yaw_range_degrees), deg_to_rad(eye_pitch_range_degrees)
	)
	if bone_idx in [_spine_idx, _middle_chest_idx, _chest_idx]:
		world_offset = look_controller.get_torso_look_offset(yaw_weight, pitch_weight, deg_to_rad(eye_yaw_range_degrees), deg_to_rad(eye_pitch_range_degrees))
	var bone_world := (skeleton.global_basis * skeleton.get_bone_global_pose(bone_idx).basis).orthonormalized()
	var local_offset := bone_world.inverse() * world_offset * bone_world
	var current_pose := skeleton.get_bone_pose(bone_idx)
	current_pose.basis = current_pose.basis * local_offset
	skeleton.set_bone_pose(bone_idx, current_pose)
