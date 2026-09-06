extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	player.set_physics_process(false)
	var weapon = player.weapon_controller
	var skeleton: Skeleton3D = weapon.get_parent()
	weapon.equipped = true
	weapon.high_ready = true
	await create_timer(0.7).timeout
	weapon.start_reload()
	player._sprint_animation = true
	player.animation_player.play("Sprint")
	await create_timer(0.15).timeout
	assert(weapon.reloading, "Reload remains active while sprint input is held")
	assert(weapon._sprint_hand_release < 1.0, "Reload brings the support hand back")
	assert(not weapon.try_fire())
	weapon.reloading = false
	await create_timer(0.4).timeout
	assert(weapon._sprint_hand_release == 1.0, "Sprint releases the support hand after reload")
	player._sprint_animation = false
	player.animation_player.play("Walk")
	await create_timer(0.08).timeout
	assert(weapon._sprint_hand_release > 0.0 and weapon._sprint_hand_release < 1.0, "Support hand blends back")
	await create_timer(0.4).timeout
	assert(weapon._sprint_hand_release == 0.0)
	var checked := [false]
	weapon.modification_processed.connect(func():
		for side in ["Left", "Right"]:
			var hand: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(side + "Hand")).origin
			assert(hand.distance_to(weapon.weapon.get_node("Grip" + side).global_position) < 0.025, "Walking restores two-handed grip")
		checked[0] = true
	, CONNECT_ONE_SHOT)
	await process_frame
	await process_frame
	assert(checked[0])
	assert(is_equal_approx(weapon.aim_amount, weapon.settings.high_ready_amount))
	print("PASS: sprint reload, one-hand sprint pose, smooth two-hand recovery and fire guard")
	quit()
