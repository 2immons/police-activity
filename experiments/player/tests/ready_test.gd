extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func wheel(weapon, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	weapon._unhandled_input(event)

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	player.set_physics_process(false)
	var weapon = player.weapon_controller
	wheel(weapon, MOUSE_BUTTON_WHEEL_UP)
	assert(not weapon.high_ready, "Holstered input is ignored")
	weapon.equipped = true
	await create_timer(0.6).timeout
	assert(weapon.aim_amount == 0.0)
	assert(weapon.get_parent().get_parent().get_parent().get_parent().has_node("WeaponRig/LeftHandObstructionProbe"))
	player.position = Vector3(0, 0, 13.45)
	await create_timer(0.5).timeout
	assert(weapon.obstructed and weapon.aim_amount == 0.0 and weapon.obstruction.compression > 0.01, "Low-ready must adaptively retract when muzzle or hands approach a wall")
	player.position = Vector3(0, 0, 12.5)
	await create_timer(0.5).timeout
	wheel(weapon, MOUSE_BUTTON_WHEEL_UP)
	await create_timer(0.35).timeout
	assert(is_equal_approx(weapon.aim_amount, weapon.settings.high_ready_amount))
	weapon.aim_pressed = true
	await create_timer(0.3).timeout
	assert(weapon.aim_amount == 1.0, "RMB overrides ready stance")
	wheel(weapon, MOUSE_BUTTON_WHEEL_DOWN)
	await create_timer(0.3).timeout
	assert(weapon.aim_amount == 1.0)
	weapon.aim_pressed = false
	await create_timer(0.3).timeout
	assert(weapon.aim_amount == 0.0, "RMB release restores selected stance")
	wheel(weapon, MOUSE_BUTTON_WHEEL_UP)
	await create_timer(0.3).timeout
	player.position = Vector3(0, 0, 13.45)
	await create_timer(0.5).timeout
	assert(weapon.obstructed and is_equal_approx(weapon.aim_amount, weapon.settings.high_ready_amount), "Wall keeps high-ready while compressing the arms")
	assert(weapon.obstruction.compression > 0.01, "High-ready must retract only by the measured clearance deficit")
	assert(is_zero_approx(weapon.obstruction.calculate_emergency_drop(weapon.settings.obstruction_emergency_drop_start)), "Moderate compression must not lower the stance")
	assert(is_equal_approx(weapon.obstruction.calculate_emergency_drop(weapon.settings.obstruction_max_compression), weapon.settings.obstruction_emergency_drop), "Extreme compression must apply the configured emergency drop")
	assert(weapon.obstruction.calculate_emergency_drop(0.12, 1.0) > weapon.obstruction.calculate_emergency_drop(0.12, 0.0), "AIM must begin lowering earlier than ready stances")
	assert(is_equal_approx(weapon.obstruction.calculate_emergency_drop(weapon.settings.obstruction_max_compression, 1.0), weapon.settings.aim_emergency_drop), "AIM must finish at its lower configured endpoint")
	player.position = Vector3(0, 0, 12.5)
	await create_timer(0.5).timeout
	assert(not weapon.obstructed and is_equal_approx(weapon.aim_amount, weapon.settings.high_ready_amount))
	weapon.start_reload()
	await create_timer(0.3).timeout
	assert(weapon.aim_amount == 0.0)
	await create_timer(1.8).timeout
	assert(is_equal_approx(weapon.aim_amount, weapon.settings.high_ready_amount), "Reload restores high-ready")
	print("PASS: wheel ready stances, ADS priority, adaptive wall compression/recovery, reload")
	quit()
