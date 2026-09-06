extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func snapshot(weapon, sk: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}
	weapon.modification_processed.connect(func():
		for name in ["Hips", "LeftFoot", "RightFoot", "Head", "LeftHand", "RightHand"]:
			var index := sk.find_bone(name)
			assert(index >= 0)
			result[name] = sk.global_transform * sk.get_bone_global_pose(index)
		result["left_grip"] = weapon.weapon.get_node("GripLeft").global_position
		result["right_grip"] = weapon.weapon.get_node("GripRight").global_position
	, CONNECT_ONE_SHOT)
	await process_frame
	await process_frame
	return result

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	player.set_physics_process(false)
	var rig = player.look_rig
	rig.set_process(false)
	rig.camera_motion.settings = rig.camera_motion.settings.duplicate()
	rig.camera_motion.settings.enabled = false
	rig.set_first_person(true)
	var weapon = player.weapon_controller
	weapon.equipped = true
	weapon.aim_pressed = true
	await create_timer(0.8).timeout
	player.animation_player.pause()
	var sk: Skeleton3D = weapon.get_parent()
	var base := await snapshot(weapon, sk)
	var right_axis: Vector3 = rig.get_movement_basis().x.normalized()
	rig.advance_lean(0.22, false, true)
	assert(is_equal_approx(rad_to_deg(rig.lean_angle), -22.0))
	var right := await snapshot(weapon, sk)
	assert((right.Head.origin - base.Head.origin).dot(right_axis) > 0.1, "E leans right")
	for name in ["Hips", "LeftFoot", "RightFoot"]:
		assert(right[name].is_equal_approx(base[name]), "Pelvis and legs must stay in place")
	assert(right.LeftHand.origin.distance_to(right.left_grip) < 0.025)
	assert(right.RightHand.origin.distance_to(right.right_grip) < 0.025)
	rig.advance_lean(0.25, false, false)
	assert(rig.lean_angle == 0.0)
	rig.advance_lean(0.22, true, false)
	assert(rad_to_deg(rig.lean_angle) < 14.0, "Left lean takes longer")
	rig.advance_lean(0.1, true, false)
	var left := await snapshot(weapon, sk)
	assert(is_equal_approx(rad_to_deg(rig.lean_angle), 14.0))
	assert((left.Head.origin - base.Head.origin).dot(right_axis) < -0.1, "Q leans left")
	assert(right.Head.origin.distance_to(base.Head.origin) > left.Head.origin.distance_to(base.Head.origin))
	rig.advance_lean(0.25, true, true)
	assert(rig.lean_angle == 0.0, "Both keys cancel")
	player._sprint_animation = true
	rig.advance_lean(0.3, false, true)
	assert(rig.lean_angle == 0.0, "Sprint suppresses leaning")
	print("PASS: asymmetric lean angles/timing, fixed pelvis/feet, gun grips, return and sprint")
	quit()
