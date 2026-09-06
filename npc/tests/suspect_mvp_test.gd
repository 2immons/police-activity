extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var player: CharacterBody3D = scene.get_node("Player")
	var npc := scene.get_node("Interior/SuspectNpc") as NPC
	assert(not npc.bt_player.active)

	npc.global_position = Vector3(0, 0, 8)
	var board := npc.ai_controller.blackboard
	npc.ai_controller.set_target(player)
	board.set_var(&"can_see_target", true)
	board.set_var(&"time_since_target_seen", 0.0)
	board.set_var(&"target_visible_fraction", 1.0)
	board.set_var(&"aim_quality", 1.0)
	board.set_var(&"stability", 1.0)

	# A: открытый маршрут.
	player.global_position = Vector3(5, 0, 1.2)
	npc.ai_controller.tactical_query.advance()
	npc.suspect_mind.force_reevaluate(npc)
	assert(npc.desired_action() == &"ESCAPE")
	npc.set_ai_active(true)
	await physics_frame
	assert(board.get_var(&"current_action") == &"ESCAPE", "BTPlayer must route the Mind decision after F3 activation")
	npc.set_ai_active(false)

	# B: офицер контролирует прямой маршрут, стрельба открывает возможность побега.
	player.global_position = Vector3(0, 0, 1.2)
	board.set_var(&"can_see_target", true)
	board.set_var(&"time_since_target_seen", 0.0)
	npc.ai_controller.tactical_query.advance()
	npc.suspect_mind.force_reevaluate(npc)
	assert(npc.desired_action() == &"FIRE_TO_ESCAPE")
	npc.ai_controller.force_exact_aim_at(player.get_chest_target_position())
	npc.ai_controller.weapon.advance(1.0)
	var rounds := npc.ai_controller.weapon.rounds
	var pressure_start := npc.global_position
	npc.tick_suspect_action(&"FIRE_TO_ESCAPE", 0.016)
	assert(npc.ai_controller.weapon.rounds < rounds, "FireToEscape must fire the authored Glock from its muzzle")
	assert(npc.ai_controller.movement.active, "FireToEscape must keep tactical repositioning active while firing")
	for frame in range(8):
		npc.ai_controller.movement.advance(0.016)
	assert(npc.global_position.distance_to(pressure_start) > 0.01, "FireToEscape must move and shoot in the same action")
	player.global_position = Vector3(5, 0, 1.2)
	npc.ai_controller.tactical_query.advance()
	npc.suspect_mind.force_reevaluate(npc)
	assert(npc.desired_action() == &"ESCAPE", "Opening the route must end FireToEscape immediately")
	npc.set_ai_active(true)
	await process_frame
	assert(board.get_var(&"current_action") == &"ESCAPE", "Dynamic branch must abort FireToEscape when desired_action changes")
	npc.set_ai_active(false)

	# C: compliant personality surrenders when escape is poor.
	npc.suspect_mind.personality = npc.suspect_mind.personality.duplicate()
	npc.suspect_mind.personality.aggression = 0.0
	npc.suspect_mind.personality.compliance = 1.0
	npc.suspect_mind.personality.self_preservation = 1.0
	npc.suspect_mind.personality.escape_drive = 0.15
	player.global_position = Vector3(0, 0, 1.2)
	board.set_var(&"suppression", 0.8)
	npc.ai_controller.tactical_query.advance()
	npc.suspect_mind.force_reevaluate(npc)
	assert(npc.desired_action() == &"SURRENDER")

	# D: low aggression plus a poor direct route selects an authored break-LOS point.
	npc.suspect_mind.personality.compliance = 0.02
	npc.suspect_mind.personality.escape_drive = 0.65
	npc.suspect_mind.personality.aggression = 0.05
	npc.suspect_mind.force_reevaluate(npc)
	assert(npc.desired_action() == &"BREAK_LOS")
	assert(is_instance_valid(npc.suspect_mind.selected_break_los_point))

	# E: route query uses remembered officer position after LOS is lost.
	board.set_var(&"last_seen_position", Vector3(0, 0, 1.2))
	board.set_var(&"time_since_target_seen", 0.2)
	board.set_var(&"can_see_target", false)
	player.global_position = Vector3(8, 0, 1.2)
	npc.ai_controller.tactical_query.advance()
	assert(board.get_var(&"escape_route_threatened", false), "Lost sight must use last-known position instead of the live player transform")

	# F1 recreates the Limbo agent inactive at the authored spawn.
	scene.call("_reset_npc")
	await process_frame
	var reset_npc := scene.get_node("Interior/SuspectNpc") as NPC
	assert(not reset_npc.bt_player.active)
	assert(reset_npc.global_transform.is_equal_approx(scene.get_node("NpcPatrol/NpcSpawn").global_transform))
	assert(reset_npc.escape_point == scene.get_node("EscapeScenario/EscapePoint"))
	assert(reset_npc.break_los_points.size() == 2, "F1 must restore authored tactical references")
	assert(reset_npc.has_node("AIDebugDraw"), "New Limbo NPC must own the muzzle/aim debug rays")

	# Movement is owned by CharacterBody3D physics, not the Limbo idle-process tick.
	var reset_board := reset_npc.ai_controller.blackboard
	reset_npc.ai_controller.set_target(player)
	reset_board.set_var(&"can_see_target", true)
	reset_board.set_var(&"time_since_target_seen", 0.0)
	player.global_position = Vector3(5, 0, 1.2)
	reset_npc.ai_controller.tactical_query.advance()
	reset_npc.suspect_mind.force_reevaluate(reset_npc)
	var reset_start := reset_npc.global_position
	reset_npc.set_ai_active(true)
	for frame in range(12):
		await physics_frame
	assert(reset_npc.global_position.distance_to(reset_start) > 0.05, "Escape animation must correspond to real CharacterBody movement")

	print("PASS: Limbo suspect escape, FireToEscape shot/transition, surrender, BreakLOS and F3 gate")
	scene.queue_free()
	await process_frame
	quit()
