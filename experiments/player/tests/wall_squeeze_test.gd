extends SceneTree

const DT := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")

func make_wall(x: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.1, 3.0, 3.0)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(x, 1.5, 0.0)
	return wall

func make_front_wall(z: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 0.1)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(0.0, 1.5, z)
	return wall

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	var interior: Node = scene.get_node_or_null("Interior")
	if interior != null:
		scene.remove_child(interior)
		interior.free()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var environment: BodyEnvironmentInteractionController = player.get_node("BodyEnvironmentInteraction")
	player.set_physics_process(false)
	for frame in 10:
		await physics_frame
		player.move_player(Vector2.ZERO, DT)
	assert(player.is_on_floor())
	assert(environment.has_node("Shoulders/Left") and environment.has_node("Trajectory/Center"))
	var left_wall := make_wall(0.65)
	scene.add_child(left_wall)
	await physics_frame
	environment.advance(0.25, Vector3(0.0, 0.0, 1.0), player, player.weapon_controller)
	assert(environment.wall_squeeze_angle > deg_to_rad(5.0), "Left wall must bring the right shoulder forward")
	assert(is_zero_approx(environment.collision_reflex_amount), "A parallel side wall must not trigger the frontal Push reflex")
	player._update_locomotion_animation(1.0)
	assert(player.animation_player.current_animation != "Push", "Walking along a wall must keep the locomotion pose")
	environment.advance(0.1, Vector3(0.0, 0.0, 5.5), player, player.weapon_controller)
	player._update_locomotion_animation(5.5)
	assert(player.animation_player.current_animation != "Push", "Sprinting along a wall must keep the locomotion pose")
	left_wall.queue_free()
	await physics_frame
	environment.advance(0.25, Vector3.ZERO, player, player.weapon_controller)
	assert(is_zero_approx(environment.wall_squeeze_angle), "Standing still must release the squeeze pose")
	var right_wall := make_wall(-0.65)
	scene.add_child(right_wall)
	await physics_frame
	environment.advance(0.25, Vector3(0.0, 0.0, 1.0), player, player.weapon_controller)
	assert(environment.wall_squeeze_angle < -deg_to_rad(5.0), "Right wall must bring the left shoulder forward")
	var weapon = player.weapon_controller
	weapon.equipped = true
	weapon.aim_pressed = true
	environment.advance(0.25, Vector3(0.0, 0.0, 1.0), player, player.weapon_controller)
	assert(is_zero_approx(environment.wall_squeeze_angle), "ADS must disable wall squeeze")
	weapon.equipped = false
	weapon.aim_pressed = false
	right_wall.queue_free()
	var front_wall := make_front_wall(1.5)
	scene.add_child(front_wall)
	await physics_frame
	environment.advance(0.1, Vector3(0.0, 0.0, 5.5), player, weapon)
	var prediction := environment.get_interaction(BodyEnvironmentInteractionController.TRAJECTORY)
	assert(prediction.has_surface and prediction.time_to_contact < environment.settings.prediction_time, "Trajectory probe must predict a surface before reaction range")
	assert(is_zero_approx(environment.collision_reflex_amount), "Distant prediction should describe intent without raising hands yet")
	front_wall.position.z = 0.85
	await physics_frame
	environment.advance(0.2, Vector3(0.0, 0.0, player.movement_settings.walk_speed), player, weapon)
	assert(is_zero_approx(environment.collision_reflex_amount), "Ordinary walking must never enter the Push pose")
	player._update_locomotion_animation(player.movement_settings.walk_speed)
	assert(player.animation_player.current_animation != "Push", "Walking toward a wall must retain the walk animation")
	environment.advance(0.2, Vector3(0.0, 0.0, 5.5), player, weapon)
	assert(environment.collision_reflex_amount > 0.5, "Approaching a wall quickly must extend the hands")
	assert(environment.get_collision_reflex_weight() > 0.5)
	player._update_locomotion_animation(5.5)
	assert(player.animation_player.current_animation == "Push" and is_zero_approx(player.animation_player.get_playing_speed()), "Unarmed anticipation must hold the authored two-hand Push pose")
	environment.advance(0.25, Vector3.ZERO, player, weapon)
	assert(is_zero_approx(environment.collision_reflex_amount), "Stopping must return the hands")
	player._update_locomotion_animation(0.0)
	assert(player.animation_player.current_animation == "Idle")
	front_wall.position.z = 0.54
	await physics_frame
	player.velocity = Vector3(0.0, 0.0, 3.0)
	player.move_and_slide()
	environment.advance(DT, Vector3(0.0, 0.0, 3.0), player, weapon)
	assert(environment.collision_reflex_impulse > 0.5, "A real frontal collision must trigger a chest/arm impulse")
	for zone in [environment.LEFT_HAND, environment.RIGHT_HAND, environment.HEAD, environment.LEFT_SHOULDER, environment.RIGHT_SHOULDER, environment.FEET]:
		var data := environment.get_interaction(zone)
		assert(data.has("nearest_surface") and data.has("distance") and data.has("normal") and data.has("approach_factor") and data.has("relative_velocity") and data.has("surface_height"))
	print("PASS: predictive interaction data, shoulder squeeze, pre-contact reflex, stop return, impact and ADS suppression")
	quit()
