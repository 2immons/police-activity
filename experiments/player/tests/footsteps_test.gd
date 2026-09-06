extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	root.add_child(scene)
	for frame in 10:
		await physics_frame
	var player = scene.get_node("Player")
	var footsteps: AudioStreamPlayer3D = player.get_node("Footsteps")
	assert(player.is_on_floor())
	assert(footsteps.stream != null and footsteps.stream.loop)
	assert(footsteps.bus == &"Footsteps")
	player._update_locomotion_animation(player.movement_settings.walk_speed)
	assert(is_equal_approx(footsteps.pitch_scale, player.movement_settings.footsteps_walk_rate))
	player._update_locomotion_animation(player.movement_settings.sprint_speed, true, true)
	var sprint_rate: float = player.movement_settings.footsteps_sprint_rate
	assert(is_equal_approx(footsteps.pitch_scale, sprint_rate))
	var bus_index := AudioServer.get_bus_index(&"Footsteps")
	assert(bus_index >= 0)
	var compensation := AudioServer.get_bus_effect(bus_index, 0) as AudioEffectPitchShift
	assert(is_instance_valid(compensation))
	assert(is_equal_approx(compensation.pitch_scale, 1.0 / sprint_rate))
	player._update_locomotion_animation(player.movement_settings.jog_speed, false, true)
	assert(is_equal_approx(footsteps.pitch_scale, player.movement_settings.footsteps_jog_rate))
	player._update_locomotion_animation(player.movement_settings.crouch_speed, false, false, true)
	assert(is_equal_approx(footsteps.pitch_scale, player.movement_settings.footsteps_crouch_rate))
	player._turn_velocity = deg_to_rad(player.movement_settings.footsteps_turn_threshold_degrees + 5.0)
	player._update_locomotion_animation(0.0)
	assert(player.animation_player.current_animation == "Walk")
	assert(is_equal_approx(absf(player.animation_player.get_playing_speed()), player.movement_settings.turn_in_place_animation_speed))
	assert(is_equal_approx(footsteps.pitch_scale, player.movement_settings.footsteps_turn_rate))
	assert(is_equal_approx(player._footsteps_target_db, player.movement_settings.footsteps_turn_volume_db))
	player._turn_velocity = 0.0
	player._update_locomotion_animation(0.0)
	assert(player._footsteps_target_db <= -79.0)
	print("PASS: footsteps walk, jog, sprint, crouch, turn-in-place and pitch compensation")
	quit()
