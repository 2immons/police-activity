extends SceneTree

const Solver = preload("res://experiments/weapon_system/ballistics/bullet_penetration_solver.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D = load("res://experiments/weapon_system/ballistics/tests/penetration_test_scene.tscn").instantiate()
	root.add_child(scene)
	await physics_frame

	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var nine_mm: Dictionary = Solver.trace(space, Vector3(0, 0, 2), Vector3.FORWARD, 10.0, 0xffffffff, [], &"9x19mm", &"glock_17", 1.0, 6)
	assert(nine_mm.hits.size() == 2, "9 mm must pass through the marked door and stop at the wall")
	assert(nine_mm.penetrations == 1)
	assert(nine_mm.hits[0].collider.name == "DoorPanel" and nine_mm.hits[1].collider.name == "Wall")

	var forbidden_caliber: Dictionary = Solver.trace(space, Vector3(0, 0, 2), Vector3.FORWARD, 10.0, 0xffffffff, [], &".22LR", &"other", 1.0, 6)
	assert(forbidden_caliber.hits.size() == 1 and forbidden_caliber.penetrations == 0, "A caliber absent from the surface settings must stop")

	assert(scene.get_node("DoorPanel/BallisticSurface") != null)
	assert(scene.get_node("Wall").get_node_or_null("BallisticSurface") == null, "Unmarked walls remain non-penetrable")
	print("PASS: caliber-filtered penetration continues through marked objects and stops at walls")
	quit()
