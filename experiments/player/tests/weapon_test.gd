extends SceneTree
var controller
var skeleton: Skeleton3D
var rig
var max_grip_error := 0.0
var max_sight_error := 0.0
func _initialize(): call_deferred("run")
func wait_seconds(seconds: float):
	await create_timer(seconds).timeout
func run():
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	assert(scene.has_node("Player/WeaponRig/Glock17/GripRight"))
	assert(scene.has_node("Player/WeaponRig/Glock17/GripLeft"))
	root.add_child(scene)
	scene.get_node("Player").set_physics_process(false)
	skeleton = scene.get_node("Player/UAL1_Standard/Armature/GeneralSkeleton")
	controller = skeleton.get_node("WeaponArms")
	rig = scene.get_node("Player/LookRig")
	rig.camera_motion.settings = rig.camera_motion.settings.duplicate()
	rig.camera_motion.settings.enabled = false
	rig.set_first_person(true)
	assert(not controller.weapon.visible)
	controller.start_reload()
	assert(not controller.reloading, "Cannot reload holstered weapon")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_1
	controller._unhandled_input(key)
	key.echo = true
	controller._unhandled_input(key)
	assert(controller.equipped, "Key echo must not re-toggle")
	controller.modification_processed.connect(func():
		if controller.draw_amount < 0.999 or controller.reloading: return
		for side in ["Right", "Left"]:
			var actual := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(side + "Hand")).origin
			var grip: Marker3D = controller.weapon.get_node("Grip" + side)
			max_grip_error = maxf(max_grip_error, actual.distance_to(grip.global_position))
	)
	await wait_seconds(0.6)
	assert(controller.weapon.visible and controller.draw_amount == 1.0)
	var light_key := InputEventKey.new()
	light_key.physical_keycode = KEY_C
	light_key.pressed = true
	controller._unhandled_input(light_key)
	await wait_seconds(0.05)
	assert(controller.flashlight.visible, "C enables weapon light in low-ready")
	light_key.echo = true
	controller._unhandled_input(light_key)
	assert(controller.flashlight_enabled, "Key repeat must not toggle light")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	controller._unhandled_input(mouse)
	await wait_seconds(0.3)
	assert(controller.aim_amount == 1.0)
	assert(controller.flashlight.visible, "ADS keeps flashlight enabled")
	for degrees in [0.0, 60.0, -60.0, 150.0, -150.0]:
		rig.yaw = deg_to_rad(degrees)
		rig.pitch = deg_to_rad(15.0)
		rig.update_look()
		await wait_seconds(0.04)
		if degrees == 60.0:
			assert(controller._aim_turn_lag.length() > 0.005, "Turning briefly separates the sights")
		await wait_seconds(0.8)
		var sight: Marker3D = controller.weapon.get_node("Sight")
		var camera_forward: Vector3 = -rig.camera.global_basis.z.normalized()
		var eye_to_sight: Vector3 = sight.global_position - rig.camera.global_position
		var lateral: Vector3 = eye_to_sight - camera_forward * eye_to_sight.dot(camera_forward)
		max_sight_error = maxf(max_sight_error, lateral.length())
	assert(max_grip_error < 0.025, "Both wrists must stay on grips; error=" + str(max_grip_error))
	assert(max_sight_error < 0.001, "ADS sight must settle on camera axis; error=" + str(max_sight_error))
	rig.yaw = 0
	rig.pitch = 0
	rig.update_look()
	controller.rounds = 3
	key.echo = false
	key.physical_keycode = KEY_R
	controller._unhandled_input(key)
	await wait_seconds(0.7)
	assert(controller.reloading and controller.aim_amount == 0.0)
	assert(controller.magazine_offset > 0.1, "Magazine must leave the grip during reload")
	var reload_time: float = controller.reload_time
	controller.start_reload()
	assert(controller.reload_time == reload_time, "R does not restart active reload")
	await wait_seconds(1.1)
	assert(not controller.reloading and controller.rounds == 17)
	await wait_seconds(0.3)
	assert(controller.aim_amount == 1.0, "Held RMB resumes aim after reload")
	controller.start_reload()
	await wait_seconds(0.2)
	key.physical_keycode = KEY_1
	controller._unhandled_input(key)
	await wait_seconds(0.6)
	assert(not controller.equipped and not controller.reloading and not controller.weapon.visible)
	assert(not controller.flashlight.visible and not controller.flashlight_enabled, "Holstering turns light off")
	assert(is_zero_approx(controller.magazine_offset))
	print("PASS: draw/holster, ADS alignment, RMB aim, reload, arm grip max error=", max_grip_error, " sight error=", max_sight_error)
	scene.queue_free()
	quit()
