extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var rig = player.look_rig
	var weapon = player.weapon_controller
	player.set_physics_process(false)
	weapon.equipped = true
	weapon.aim_pressed = true
	await create_timer(0.8).timeout
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ALT
	key.pressed = true
	rig._unhandled_input(key)
	assert(rig.free_look_active)
	var locked: Transform3D = weapon.weapon.global_transform
	var body: Basis = player.global_basis
	var movement: Basis = rig.get_movement_basis()
	var original_yaw: float = rig.yaw
	for degrees in [60.0, -120.0, 160.0]:
		rig.yaw = deg_to_rad(degrees)
		rig.update_look()
		for frame in range(4):
			await physics_frame
			player.move_player(Vector2.ZERO, 1.0 / 60.0)
		await process_frame
		assert(weapon.weapon.global_basis.is_equal_approx(locked.basis), "Gun must not follow free look")
		assert(player.global_basis.is_equal_approx(body), "No armed auto-turn during Alt")
		assert(rig.get_movement_basis().is_equal_approx(movement), "Movement heading remains independent of free look")
		var sk: Skeleton3D = weapon.get_parent()
		var checked := [false]
		weapon.modification_processed.connect(func():
			for side in ["Right", "Left"]:
				var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin
				assert(hand.distance_to(weapon.weapon.get_node("Grip" + side).global_position) < 0.025, "Grip remains attached during free look")
			checked[0] = true
		, CONNECT_ONE_SHOT)
		await process_frame
		await process_frame
		assert(checked[0])
	key.pressed = false
	rig._unhandled_input(key)
	assert(rig.free_look_returning)
	# Regression: W + ADS + Alt release used to keep overwriting mouse input
	# until the automatic return finished.
	player.move_player(Vector2(0, -1), 1.0 / 60.0)
	var yaw_before_input: float = rig.yaw
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(25, 0)
	rig._unhandled_input(mouse)
	assert(not rig.is_free_looking(), "Mouse immediately cancels Alt return")
	assert(absf(angle_difference(rig.yaw, yaw_before_input)) > 0.01, "Mouse controls aim immediately")
	var controlled_yaw: float = rig.yaw
	await create_timer(0.25).timeout
	assert(absf(angle_difference(rig.yaw, controlled_yaw)) < 0.001, "Cancelled return cannot overwrite aim")
	# A release without further input still returns smoothly.
	key.pressed = true
	rig._unhandled_input(key)
	rig.yaw += deg_to_rad(30.0)
	rig.update_look()
	key.pressed = false
	rig._unhandled_input(key)
	await create_timer(0.9).timeout
	assert(not rig.is_free_looking() and absf(rig.yaw - controlled_yaw) < 0.001, "Release returns smoothly to weapon heading")
	weapon.equipped = false
	key.pressed = true
	rig._unhandled_input(key)
	assert(not rig.is_free_looking(), "Alt requires equipped weapon")
	print("PASS: Alt hold/release, W+ADS mouse takeover, locked gun, movement heading, smooth return, unarmed guard")
	scene.queue_free()
	quit()
