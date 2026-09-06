extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	var player: CharacterBody3D = scene.get_node("Player")
	var stress: PlayerStressController = player.stress_controller
	var overlay: SuppressionOverlay = player.get_node("SuppressionFeedback")

	assert(player.has_node("Stress") and player.has_node("SuppressionFeedback/Effect"), "Stress simulation and presentation must be authored in player.tscn")
	stress.settings = stress.settings.duplicate()
	overlay.settings = stress.settings
	stress.apply_suppression(Vector3.BACK * 5.0, player.global_position + Vector3.RIGHT * 0.2, 0.8)
	await create_timer(0.12).timeout
	assert(stress.get_amount() > 0.25, "Near fire must quickly raise visual stress")
	assert(overlay.effect.visible, "Stress must enable the peripheral screen effect")
	assert(float(overlay.effect.material.get_shader_parameter("stress_amount")) > 0.2, "Overlay must consume normalized stress")
	assert(not stress.get_weapon_sway(PI * 0.5).is_equal_approx(Transform3D.IDENTITY), "Stress must add deterministic hand/weapon sway")

	var before_hit := stress.stress
	player.receive_suppression(Vector3.LEFT * 3.0, player.global_position, 1.0)
	assert(stress.stress > before_hit, "A stronger threat must accumulate stress")
	stress.settings.decay_delay = 0.0
	stress.settings.decay_rate = 2.0
	stress.reset()
	stress.apply_suppression(Vector3.LEFT * 3.0, player.global_position, 0.5)
	await create_timer(0.7).timeout
	assert(stress.stress < 0.05, "Stress must recover after danger passes")

	print("PASS: authored suppression components, accumulated stress, edge effect, weapon sway and recovery")
	scene.queue_free()
	quit()
