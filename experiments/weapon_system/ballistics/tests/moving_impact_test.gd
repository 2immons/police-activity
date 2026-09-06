extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	await physics_frame

	var controller = scene.get_node("Player").weapon_controller
	var door_body: RigidBody3D = scene.get_node("Interior/Room01Door/DoorBody")
	var hit_position: Vector3 = door_body.to_global(Vector3(0.2, 0.1, -0.04))
	controller._spawn_impact({
		"collider": door_body,
		"position": hit_position,
		"normal": -door_body.global_basis.z,
	})

	var impact: Node3D = controller._impacts[-1]
	assert(impact.get_parent() == door_body, "Impact on a movable door must be parented to its RigidBody3D")
	var local_transform := impact.transform
	door_body.freeze = true
	door_body.rotation.y += deg_to_rad(35.0)
	await process_frame
	assert(impact.transform.is_equal_approx(local_transform), "Impact must preserve its local pose while the door moves")
	assert(impact.global_position.distance_to(hit_position) > 0.01, "Impact must follow the rotated door instead of floating in world space")

	print("PASS: bullet impact inherits moving collider transform")
	quit()
