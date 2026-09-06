extends SceneTree

const DT := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")

func _shift(player, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = pressed
	player._unhandled_input(event)

func _step(player, frames: int) -> void:
	for frame in frames:
		await physics_frame
		player.move_player(Vector2(0, -1), DT, false, player._jogging_enabled, false)

func _speed(player) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func run() -> void:
	var scene: Node3D = load("res://experiments/player/test_scene.tscn").instantiate()
	var interior := scene.get_node_or_null("Interior")
	if interior != null:
		interior.queue_free()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var weapon = player.weapon_controller
	player.set_physics_process(false)
	weapon.equipped = true
	weapon.aim_pressed = true
	player._update_aim_movement_state()

	await _step(player, 90)
	assert(is_equal_approx(_speed(player), player.movement_settings.aim_slow_speed), "ADS starts in slow tactical walk when entered from walk")
	_shift(player, true)
	_shift(player, false)
	await _step(player, 90)
	assert(player._aim_fast_walk and is_equal_approx(_speed(player), player.movement_settings.aim_fast_speed), "Shift tap toggles fast ADS walk")

	weapon.aim_pressed = false
	player._update_aim_movement_state()
	await _step(player, 90)
	assert(not player._jogging_enabled and is_equal_approx(_speed(player), player.movement_settings.walk_speed), "Leaving ADS entered from walk restores walk")

	player._jogging_enabled = true
	weapon.aim_pressed = true
	player._update_aim_movement_state()
	await _step(player, 90)
	assert(player._aim_fast_walk and is_equal_approx(_speed(player), player.movement_settings.aim_fast_speed), "Entering ADS from jogging selects fast ADS walk")
	weapon.aim_pressed = false
	player._update_aim_movement_state()
	await _step(player, 90)
	assert(player._jogging_enabled and is_equal_approx(_speed(player), player.movement_settings.jog_speed), "Leaving ADS restores jogging")

	weapon.aim_amount = 1.0
	player.look_rig.camera_motion._step_phase = PI * 0.5
	weapon._aim_step_motion_weight = 1.0
	player._aim_fast_walk = false
	var slow_motion: Transform3D = weapon._get_aim_step_motion(player, DT)
	player._aim_fast_walk = true
	var fast_motion: Transform3D = weapon._get_aim_step_motion(player, DT)
	assert(fast_motion.origin.length() > slow_motion.origin.length() * 2.0, "Fast ADS gait must produce stronger step-synchronised weapon motion")

	print("PASS: slow/fast ADS walk, Shift toggle, locomotion restoration and step-synchronised weapon motion")
	quit()
