extends SceneTree

const DT := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")

func _step(player, input_direction: Vector2, frames: int, sprint := false, jog := false, crouch := false) -> void:
	for frame in frames:
		await physics_frame
		player.move_player(input_direction, DT, sprint, jog, crouch)

func _speed(player) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func _shift(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = pressed
	return event

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	var interior: Node = scene.get_node_or_null("Interior")
	if interior:
		scene.remove_child(interior)
		interior.free()
	root.add_child(scene)
	var player = scene.get_node("Player")
	var weapon = player.weapon_controller
	player.set_physics_process(false)

	player._jogging_enabled = false
	player._unhandled_input(_shift(true))
	player._advance_shift_state(player.movement_settings.sprint_hold_delay)
	assert(player._shift_became_sprint and not player._jogging_enabled, "Holding Shift from walk must not toggle jogging")
	player._unhandled_input(_shift(false))
	assert(not player._jogging_enabled, "Walk must be restored after sprint")

	player._jogging_enabled = true
	player._unhandled_input(_shift(true))
	player._advance_shift_state(player.movement_settings.sprint_hold_delay)
	player._unhandled_input(_shift(false))
	assert(player._jogging_enabled, "Jogging must be restored after sprint")

	player._jogging_enabled = false
	player._unhandled_input(_shift(true))
	player._unhandled_input(_shift(false))
	assert(player._jogging_enabled, "A short Shift tap toggles jogging")

	await _step(player, Vector2(0, -1), 90, false, true)
	assert(is_equal_approx(_speed(player), player.movement_settings.jog_speed))
	assert(player.animation_player.current_animation == "Jog_Fwd")

	await _step(player, Vector2(0, -1), 90, true, true)
	assert(is_equal_approx(_speed(player), player.movement_settings.sprint_speed))
	assert(player.animation_player.current_animation == "Sprint")
	assert(is_equal_approx(player.movement_settings.sprint_speed / player.movement_settings.jog_speed, 1.5))

	await _step(player, Vector2(0, -1), 90, false, false, true)
	assert(is_equal_approx(_speed(player), player.movement_settings.crouch_speed))
	assert(player.animation_player.current_animation == "Crouch_Fwd")
	await _step(player, Vector2.ZERO, 45, false, false, true)
	assert(player.animation_player.current_animation == "Crouch_Idle")
	assert((player.collision_shape.shape as CapsuleShape3D).height <= player.movement_settings.crouch_collider_height + 0.001)

	weapon.equipped = true
	await create_timer(0.6).timeout
	weapon.high_ready = true
	weapon.aim_pressed = true
	await _step(player, Vector2.ZERO, 20, false, false, true)
	assert(weapon.aim_amount > 0.9, "Crouch allows ADS and ready stances")
	weapon.start_reload()
	assert(weapon.reloading, "Crouch allows reload")
	weapon.aim_pressed = false
	player._update_aim_movement_state()

	player.velocity = Vector3.ZERO
	await _step(player, Vector2(0, -1), 90, true, true, false)
	assert(_speed(player) <= player.movement_settings.jog_speed + 0.001, "Reload limits held sprint to jogging")
	weapon.reloading = false
	await _step(player, Vector2(0, -1), 90, true, true, false)
	assert(is_equal_approx(_speed(player), player.movement_settings.sprint_speed), "Sprint resumes after reload")

	print("PASS: jog, sprint hold speed, crouch collider/animations, crouched weapon stances and sprint reload limit")
	quit()
