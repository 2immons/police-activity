extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func _key(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = pressed
	return event

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var interaction = player.door_interaction
	var door = scene.get_node("Interior/Room01Door")
	door.settings = door.settings.duplicate()
	door.settings.interaction_distance = 100.0
	interaction.set_physics_process(false)

	interaction.candidate = door
	interaction._unhandled_input(_key(true))
	interaction._unhandled_input(_key(false))
	assert(door.motion_mode == door.MotionMode.AUTO, "Tap F toggles AUTO")

	interaction.candidate = door
	interaction._unhandled_input(_key(true))
	interaction._hold_time = interaction.settings.hold_delay
	interaction._update_hold(0.0)
	interaction._update_left_hand_state()
	assert(interaction.controlled_door == door and door.controlled_by_player)
	assert(interaction.left_hand_state == interaction.LeftHandState.DOOR)
	assert(interaction.door_control_mode == interaction.DoorControlMode.HANDLE_CONTROL)
	player.weapon_controller.equipped = true
	player.weapon_controller.high_ready = false
	var target_before: float = door.target_angle
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	player.weapon_controller._unhandled_input(wheel)
	assert(not player.weapon_controller.high_ready, "Door wheel control must not switch weapon ready stance")
	interaction._unhandled_input(wheel)
	assert(door.target_angle > target_before, "Mouse wheel changes arbitrary CONTROLLED target")

	interaction._update_left_hand_state()
	var skeleton: Skeleton3D = player.weapon_controller.get_parent()
	var shoulder: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftUpperArm")).origin
	var reach: float = player.weapon_controller._arm_length(skeleton, "Left") - interaction.settings.hand_reach_margin
	var handle_target: Marker3D = door.get_control_handle_target()
	var shoulder_to_handle: Vector3 = (handle_target.global_position - shoulder).normalized()
	var desired_shoulder: Vector3 = handle_target.global_position - shoulder_to_handle * (reach + interaction.settings.torso_reach_extension * 0.5)
	player.global_position += desired_shoulder - shoulder
	var hand_before: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin
	shoulder = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftUpperArm")).origin
	var selected_target: Marker3D = door.get_hand_target_for_reach(shoulder, reach + interaction.settings.torso_reach_extension)
	player.weapon_controller.advance_weapon(interaction.settings.support_hand_transition)
	assert(player.weapon_controller._door_hand_release > 0.9, "Left support hand releases Glock for door")
	assert(door.hand_control_mode == door.HandControlMode.HANDLE_CONTROL and player.weapon_controller._door_torso_offset.length() > 0.001, "Torso reach keeps an attainable handle in HANDLE_CONTROL")
	assert(player.weapon_controller._door_hand_pose.origin.distance_to(selected_target.global_position) < hand_before.distance_to(selected_target.global_position), "Left hand starts reaching toward the door")
	var hand_after: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin
	assert(hand_after.distance_to(selected_target.global_position) < hand_before.distance_to(selected_target.global_position), "Door IK moves the actual left hand")
	interaction._unhandled_input(_key(false))
	interaction._update_left_hand_state()
	assert(interaction.left_hand_state == interaction.LeftHandState.WEAPON_SUPPORT)

	print("PASS: Tap/Hold F, wheel control, distance-ready ownership and left hand weapon/door states")
	quit()
