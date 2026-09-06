extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	assert(scene.has_node("Player/LookRig/CameraMotion"), "Motion node must exist before ready")
	root.add_child(scene)
	var player = scene.get_node("Player")
	var rig = scene.get_node("Player/LookRig")
	var motion = rig.camera_motion
	player.set_physics_process(false)
	motion.set_process(false)
	motion.settings = motion.settings.duplicate()
	rig.set_first_person(true)
	var view: Basis = rig.global_basis
	var levels: Array[float] = []
	var walk_speed: float = player.movement_settings.walk_speed
	var sprint_speed: float = player.movement_settings.sprint_speed
	for state in [Vector2(0, 0), Vector2(0, 2.6), Vector2(walk_speed, 0), Vector2(walk_speed, 2.6), Vector2(sprint_speed, 0), Vector2(sprint_speed, 2.6)]:
		for frame in range(180):
			motion.advance_motion(1.0 / 60.0, state.x, state.y, true)
		levels.append(motion.intensity)
		assert(motion.offset.origin.length() < 0.04, "Position shake stays small")
		assert(motion.offset.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY) < deg_to_rad(4.0), "Rotation shake stays bounded")
	for i in range(1, levels.size()):
		assert(levels[i] > levels[i - 1], "Idle < turn < walk < walk+turn < sprint < sprint+turn")
	assert(rig.global_basis.is_equal_approx(view), "Shake must not modify gameplay view")
	motion.add_hit_impulse(Vector3(0.5, 0.0, -1.0), player.global_position + Vector3(0.4, 1.2, 0.0), "CHEST")
	motion.advance_motion(1.0 / 60.0, 0.0, 0.0, true)
	assert(motion._hit_position.length() > 0.0001, "Bullet impact must kick the first-person camera")
	assert(motion._hit_rotation.length() > 0.0001, "Off-centre bullet impact must rotate the camera")
	for frame in range(180):
		motion.advance_motion(1.0 / 60.0, 0.0, 0.0, true)
	assert(motion._hit_position.length() < 0.001 and motion._hit_rotation.length() < 0.001, "Hit reaction must settle instead of accumulating")
	var phase: float = motion._step_phase
	for frame in range(120):
		motion.advance_motion(1.0 / 60.0, sprint_speed, 0.0, false)
	assert(is_equal_approx(motion._step_phase, phase), "No footsteps in air")
	assert(motion.intensity < 0.16, "Airborne movement fades to idle")
	motion.settings.enabled = false
	motion.advance_motion(1.0 / 60.0, sprint_speed, 2.6, true)
	assert(motion.offset.is_equal_approx(Transform3D.IDENTITY), "Disabled shake has no offset")
	motion.settings.enabled = true
	motion.settings.master_strength = 0.0
	motion.advance_motion(1.0 / 60.0, sprint_speed, 2.6, true)
	assert(motion.offset.is_equal_approx(Transform3D.IDENTITY), "Zero master disables shake")
	motion.settings.master_strength = 1.0
	motion.advance_motion(1.0 / 60.0, 2.0, 1.0, true)
	rig.body_look.modification_processed.connect(func():
		var skeleton: Skeleton3D = rig.body_look.get_parent()
		var eye: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")) * rig.eye_center.position
		var expected: Transform3D = Transform3D(rig.global_basis, eye) * motion.offset
		assert(rig.camera.global_transform.is_equal_approx(expected), "Shake composes on final animated eye pose")
	)
	for frame in range(4):
		await process_frame
	print("PASS: layered strengths ", levels, ", bounds, no view feedback, grounded steps, disable, animated eye composition")
	scene.queue_free()
	quit()
