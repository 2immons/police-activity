extends SceneTree

var poses: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("Player").set_physics_process(false)
	var rig = scene.get_node("Player/LookRig")
	# This test isolates eye anchoring from the intentional cosmetic shake offset.
	rig.camera_motion.settings = rig.camera_motion.settings.duplicate()
	rig.camera_motion.settings.enabled = false
	rig.camera_motion.advance_motion(0.0, 0.0, 0.0, true)
	rig._update_camera()
	var skeleton: Skeleton3D = scene.get_node("Player/UAL1_Standard/Armature/GeneralSkeleton")
	var modifier = skeleton.get_node("BodyLook")
	var animation: AnimationPlayer = scene.get_node("Player/UAL1_Standard/AnimationPlayer")
	animation.pause()
	modifier.modification_processed.connect(func():
		for bone_name in ["Head", "Neck", "UpperChest", "LeftShoulder", "Hips"]:
			poses[bone_name] = skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).basis.orthonormalized()
	)
	await process_frame
	await process_frame
	var neutral := poses.duplicate()
	var neutral_camera: Basis = rig.global_basis
	for degrees in [-20.0, -10.0, 10.0, 20.0]:
		rig.yaw = deg_to_rad(degrees)
		rig.pitch = deg_to_rad(degrees)
		rig.update_look()
		await process_frame
		await process_frame
		for bone_name in neutral:
			assert((poses[bone_name] as Basis).get_rotation_quaternion().angle_to((neutral[bone_name] as Basis).get_rotation_quaternion()) < 0.001, "Bones must remain neutral inside eye range")
		assert(rig.global_basis.get_rotation_quaternion().angle_to(neutral_camera.get_rotation_quaternion()) > 0.1, "Camera must move inside eye range")
	for angles in [Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0, 0.4), Vector2(0, -0.4), Vector2(deg_to_rad(85.0), 0), Vector2(deg_to_rad(90.0), 0), Vector2(deg_to_rad(120.0), 0), Vector2(deg_to_rad(170.0), 0), Vector2(deg_to_rad(-170.0), 0)]:
		rig.yaw = angles.x
		rig.pitch = angles.y
		rig.update_look()
		await process_frame
		await process_frame
		var expected: Basis = rig.get_world_look_offset(1.0, 1.0, deg_to_rad(20.0), deg_to_rad(20.0))
		var actual: Basis = poses["Head"] * (neutral["Head"] as Basis).inverse()
		assert(actual.get_rotation_quaternion().angle_to(expected.get_rotation_quaternion()) < 0.01, "Head must follow excess beyond eye range")
		assert((poses["UpperChest"] as Basis).get_rotation_quaternion().angle_to((neutral["UpperChest"] as Basis).get_rotation_quaternion()) > 0.003, "Chest must turn")
		assert((poses["LeftShoulder"] as Basis).get_rotation_quaternion().angle_to((neutral["LeftShoulder"] as Basis).get_rotation_quaternion()) > 0.003, "Shoulder must follow chest")
		assert((poses["Hips"] as Basis).get_rotation_quaternion().angle_to((neutral["Hips"] as Basis).get_rotation_quaternion()) < 0.001, "Rear look must not rotate hips")
		if absf(angles.x) > deg_to_rad(169.0):
			var torso_angle := (poses["UpperChest"] as Basis).get_rotation_quaternion().angle_to((neutral["UpperChest"] as Basis).get_rotation_quaternion())
			assert(torso_angle > deg_to_rad(85.0) and torso_angle < deg_to_rad(100.0), "Rear look must turn upper torso about 90 degrees")
		var camera_expected: Basis = rig.get_world_look_offset(1.0, 1.0) * neutral_camera
		assert(rig.global_basis.get_rotation_quaternion().angle_to(camera_expected.get_rotation_quaternion()) < 0.001, "Camera must not double rotation")
		for frame in range(20):
			await process_frame
		assert((poses["Head"] as Basis).get_rotation_quaternion().angle_to((actual * (neutral["Head"] as Basis)).get_rotation_quaternion()) < 0.001, "Look must not accumulate")
	rig.yaw = 0
	rig.pitch = 0
	rig.update_look()
	await process_frame
	await process_frame
	assert((poses["Head"] as Basis).get_rotation_quaternion().angle_to((neutral["Head"] as Basis).get_rotation_quaternion()) < 0.001, "Return to neutral")
	var camera: Camera3D = rig.camera
	var third_person_pose := camera.transform
	var third_person_near := camera.near
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_V
	toggle.pressed = true
	rig._unhandled_input(toggle)
	assert(rig.first_person, "V must enter first person")
	assert(is_equal_approx(camera.near, rig.first_person_near) and camera.near >= 0.1, "First-person near plane must clip the inside of the single-mesh head")
	toggle.echo = true
	rig._unhandled_input(toggle)
	assert(rig.first_person, "Key repeat must not toggle the camera")
	toggle.echo = false
	modifier.modification_processed.connect(func():
		if rig.first_person:
			var expected_eye: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")) * rig.eye_center.position
			assert(camera.global_position.distance_to(expected_eye) < 0.0001, "First-person camera must stay at eye center")
			assert(camera.global_basis.get_rotation_quaternion().angle_to(rig.global_basis.get_rotation_quaternion()) < 0.001, "First-person camera must not inherit head rotation")
	)
	animation.play("Walk")
	for degrees in [0.0, 15.0, 90.0, 170.0, -170.0]:
		rig.yaw = deg_to_rad(degrees)
		rig.pitch = deg_to_rad(25.0)
		rig.update_look()
		for frame in range(5):
			await process_frame
	rig._unhandled_input(toggle)
	assert(not rig.first_person, "V must return to third person")
	assert(camera.transform.is_equal_approx(third_person_pose), "Restore authored third-person transform")
	assert(is_equal_approx(camera.near, third_person_near), "Restore third-person near plane")
	print("PASS: V toggle, repeat ignored, animated eye position, rear-look camera orientation, third-person restoration")
	print("PASS: eye range, rear look both sides, torso twist, fixed hips, camera independence, no drift, neutral return")
	scene.queue_free()
	quit()





