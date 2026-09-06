extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var rig = player.look_rig
	var weapon = player.weapon_controller
	player.set_physics_process(false)
	for frame in range(30):
		await physics_frame
		player.move_player(Vector2.ZERO, 1.0 / 60.0)
	weapon.equipped = true
	weapon.draw_amount = 1.0
	for aiming in [false, true]:
		weapon.aim_pressed = aiming
		for degrees in [44.0, -45.0, 90.0, -90.0]:
			player.rotation = Vector3.ZERO
			player._turn_velocity = 0.0
			rig.yaw = deg_to_rad(degrees)
			rig.update_look()
			var view: Basis = rig.global_basis
			var position: Vector3 = player.position
			for frame in range(70):
				await physics_frame
				var before: Basis = player.global_basis
				player.move_player(Vector2.ZERO, 1.0 / 60.0)
				assert(before.get_rotation_quaternion().angle_to(player.global_basis.get_rotation_quaternion()) <= deg_to_rad(2.01), "Standing turn speed limited")
				assert(rig.global_basis.get_rotation_quaternion().angle_to(view.get_rotation_quaternion()) < 0.001, "World camera heading preserved")
			if absf(degrees) <= 45:
				assert(player.global_basis.is_equal_approx(Basis.IDENTITY), "Inside free-look cone body stays still")
			else:
				assert(absf(rad_to_deg(rig.yaw)) >= 44.9 and absf(rad_to_deg(rig.yaw)) < 45.3, "Body absorbs excess yaw")
			assert(player.position.distance_to(position) < 0.005, "Turning in place must not translate player")
	weapon.equipped = false
	player.rotation = Vector3.ZERO
	rig.yaw = deg_to_rad(90.0)
	rig.update_look()
	for frame in range(10):
		await physics_frame
		player.move_player(Vector2.ZERO, 1.0 / 60.0)
	assert(player.global_basis.is_equal_approx(Basis.IDENTITY), "Unarmed free look remains unchanged")
	print("PASS: armed ready/aim, +/-45 cone, smooth +/-90 turns, fixed view, no translation, unarmed behavior")
	scene.queue_free()
	quit()
