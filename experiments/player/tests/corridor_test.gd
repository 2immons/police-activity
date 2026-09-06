extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	var interior: Node3D = scene.get_node("Interior")
	assert(interior.find_children("*", "SpotLight3D", true, false).size() == 16)
	assert(interior.find_children("*CeilingFill", "SpotLight3D", true, false).size() == 8)
	assert(not scene.get_node("Environment").environment.sdfgi_enabled)
	assert(interior.find_children("Room*Sign", "Label3D", true, false).size() == 4)
	var node_count := interior.find_children("*", "", true, false).size()
	root.add_child(scene)
	var player: CharacterBody3D = scene.get_node("Player")
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	assert(interior.find_children("*", "", true, false).size() == node_count, "Interior must exist in scene, not be constructed at runtime")
	for z in [2.0, 10.0]:
		for side in [-1.0, 1.0]:
			var start := Transform3D(Basis.IDENTITY, Vector3(0, 0, z))
			assert(not player.test_move(start, Vector3(side * 3.4, 0, 0)), "All four doorways must pass the capsule")
	assert(player.test_move(Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(3.4, 0, 0)), "Corridor wall must block movement outside doorway")
	assert(player.test_move(Transform3D(Basis.IDENTITY, Vector3(0, 0, 12)), Vector3(0, 0, 4)), "End wall must stop player")
	print("PASS: four rooms, eight lights, static composition, four traversable doorways, solid walls")
	scene.queue_free()
	quit()
