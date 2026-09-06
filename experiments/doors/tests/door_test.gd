extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var door = load("res://experiments/doors/door.tscn").instantiate()
	root.add_child(door)
	await physics_frame
	assert(door.has_node("FrameAnchor") and door.has_node("DoorBody") and door.has_node("Hinge"))
	assert(door.has_node("DoorBody/HandlePivot") and door.has_node("DoorBody/HandleTargets/Front") and door.has_node("DoorBody/HandleTargets/Rear"))
	assert(door.has_node("DoorBody/PanelOutline") and door.has_node("DoorBody/HandlePivot/FrontLeverOutline"))
	door.set_interaction_highlight(true)
	await physics_frame
	await process_frame
	var panel_highlight: float = door.panel_outline.get_instance_shader_parameter("highlight_strength")
	var handle_highlight: float = door.handle_outlines[0].get_instance_shader_parameter("highlight_strength")
	assert(panel_highlight > 0.0 and handle_highlight > panel_highlight, "Handle outline must be brighter than the door outline")
	var front_probe: Vector3 = door.body.to_global(Vector3(0, 0, -1))
	var rear_probe: Vector3 = door.body.to_global(Vector3(0, 0, 1))
	assert(door.get_nearest_hand_target(front_probe) != door.get_nearest_hand_target(rear_probe), "Each side selects its own handle/hand targets")

	assert(door.request_auto_toggle())
	assert(door.motion_mode == door.MotionMode.AUTO)
	assert(is_equal_approx(door.target_angle, deg_to_rad(door.settings.auto_open_angle_degrees)))
	var hinge_origin: Vector3 = door.hinge.global_position
	await create_timer(1.2).timeout
	assert(door.current_angle > deg_to_rad(15.0), "AUTO motor must physically move the rigid door")
	var body_hinge_point: Vector3 = door.body.global_transform * Vector3(-0.46, 0, 0)
	assert(body_hinge_point.distance_to(hinge_origin) < 0.015, "Door edge must stay on the hinge axis")

	assert(door.begin_control())
	await physics_frame
	await process_frame
	assert(door.handle_pivot.rotation.z > 0.0, "Pressed lever must rotate downward")
	var blocked_push: bool = door.try_body_push(Vector3(0, 0, -2.0), door.body.global_position, Vector3(0, 0, 1))
	assert(not blocked_push, "Body push is disabled while Hold F controls the door")
	var target_before: float = door.target_angle
	door.add_control_angle(deg_to_rad(-7.0))
	assert(door.target_angle < target_before, "CONTROLLED supports small arbitrary angle changes")
	var inner_target: Marker3D = door.get_node("DoorBody/PanelHandTargets/Front/PanelInner")
	var selected_target: Marker3D = door.get_hand_target_for_reach(inner_target.global_position + Vector3(0, 0, 0.2), 0.3)
	assert(selected_target != door.get_hand_target(), "Unreachable handle switches to a panel push target")
	assert(door.hand_control_mode == door.HandControlMode.PUSH_ONLY)
	var push_only_target: float = door.target_angle
	door.add_control_angle(deg_to_rad(-10.0))
	assert(is_equal_approx(door.target_angle, push_only_target), "PUSH_ONLY cannot pull the door closed")
	var handle_again: Marker3D = door.get_hand_target_for_reach(door.get_hand_target().global_position, 0.1)
	assert(handle_again == door.get_hand_target() and door.hand_control_mode == door.HandControlMode.HANDLE_CONTROL, "Reachable handle restores HANDLE_CONTROL")
	door.end_control()
	assert(not door.controlled_by_player and door.motion_mode == door.MotionMode.IDLE)
	var contact: Vector3 = door.body.global_transform * Vector3(0.44, 0, 0)
	var pushed: bool = door.try_body_push(Vector3(0, 0, -2.0), contact, Vector3(0, 0, 1))
	assert(pushed, "Released latch allows body impulse")
	await physics_frame
	assert(absf(door.body.angular_velocity.y) > 0.001, "Body contact transfers angular impulse")

	door.body.rotation.y = deg_to_rad(1.0)
	door.body.angular_velocity = Vector3(0, -1.0, 0)
	door.motion_mode = door.MotionMode.IDLE
	door.latch_released = true
	await physics_frame
	await physics_frame
	assert(not door.latch_released, "Door latches when pushed into the closed stop")

	door.locked = true
	assert(not door.request_auto_toggle() and not door.begin_control())
	assert(door.debug_label.text.contains("left hand"))
	print("PASS: physical hinge AUTO/CONTROLLED, arbitrary targets, handle/latch, lock and editor-authored nodes")
	quit()
