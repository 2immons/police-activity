extends SceneTree

var player
var rig
const DT := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")

func step(input_direction: Vector2, frames: int, sprint: bool = false) -> void:
	for frame in range(frames):
		await physics_frame
		player.move_player(input_direction, DT, sprint)

func horizontal_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	# Keep locomotion assertions on an open floor; corridor_test checks room collisions.
	var interior: Node = scene.get_node_or_null("Interior")
	if interior != null:
		scene.remove_child(interior)
		interior.free()
	var floor_shape: CollisionShape3D = scene.get_node("StaticBody3D/CollisionShape3D")
	var floor_mesh: MeshInstance3D = scene.get_node("StaticBody3D/MeshInstance3D")
	assert(floor_shape.shape.size.is_equal_approx(floor_mesh.mesh.size))
	assert(floor_shape.transform.is_equal_approx(floor_mesh.transform))
	root.add_child(scene)
	player = scene.get_node("Player")
	rig = scene.get_node("Player/LookRig")
	player.set_physics_process(false)
	for clip in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Fwd", "Crouch_Idle"]:
		assert(player.animation_player.has_animation(clip))
	await step(Vector2.ZERO, 30)
	assert(player.is_on_floor())
	assert(player.animation_player.current_animation == "Idle")
	await step(Vector2(0, -1), 1)
	assert(horizontal_speed() > 0.0 and horizontal_speed() < 0.2, "Gradual acceleration")
	await step(Vector2(0, -1), 30)
	assert(is_equal_approx(horizontal_speed(), player.movement_settings.walk_speed))
	assert(player.animation_player.current_animation == "Walk")
	var before_tap: Basis = player.global_basis
	var before_velocity: Vector3 = player.velocity
	var view_before: Basis = rig.global_basis
	await step(Vector2(-1, -1), 1)
	var tap_velocity_change: float = player.velocity.distance_to(before_velocity)
	assert(tap_velocity_change < 0.13, "Short A tap must not snap velocity; change=" + str(tap_velocity_change))
	assert(player.global_basis.get_rotation_quaternion().angle_to(before_tap.get_rotation_quaternion()) < deg_to_rad(1.0), "Short A tap must not snap body")
	await step(Vector2(0, -1), 45)
	assert(player.global_basis.z.dot(-view_before.z) > 0.999, "Recover forward heading")
	await step(Vector2(-1, -1), 60)
	var diagonal: Vector3 = (-view_before.x - view_before.z).normalized()
	assert(player.global_basis.z.dot(diagonal) > 0.999, "Sustained diagonal turns the body")
	assert(horizontal_speed() <= player.movement_settings.walk_speed + 0.001)
	assert(rig.global_basis.get_rotation_quaternion().angle_to(view_before.get_rotation_quaternion()) < 0.001, "Preserve camera heading")
	for side in [-1.0, 1.0]:
		var strafe_basis: Basis = player.global_basis
		await step(Vector2(side, 0), 60)
		assert(player.global_basis.is_equal_approx(strafe_basis), "A/D must not turn body")
		assert(player.velocity.normalized().dot(-strafe_basis.x * side) > 0.99)
	await step(Vector2.ZERO, 1)
	assert(horizontal_speed() > 0.1, "Stopping must brake gradually")
	await step(Vector2.ZERO, 30)
	assert(is_zero_approx(horizontal_speed()))
	assert(player.animation_player.current_animation == "Idle")
	await step(Vector2(0, -1), 1, true)
	assert(player.animation_player.current_animation != "Sprint", "Sprint pose waits for speed")
	await step(Vector2(0, -1), 60, true)
	assert(is_equal_approx(horizontal_speed(), player.movement_settings.sprint_speed))
	assert(player.animation_player.current_animation == "Sprint")
	var sprint_view: Basis = rig.global_basis
	await step(Vector2(1, -1), 6, true)
	var sprint_right_speed: float = Vector3(player.velocity.x, 0.0, player.velocity.z).dot(sprint_view.x)
	assert(sprint_right_speed > 1.5, "Sprint steering must react sharply; lateral speed=" + str(sprint_right_speed))
	await step(Vector2(1, -1), 45, true)
	assert(is_equal_approx(horizontal_speed(), player.movement_settings.sprint_speed), "Sprint diagonal normalized")
	await step(Vector2(0, -1), 1)
	assert(horizontal_speed() > player.movement_settings.walk_speed, "Release Shift decelerates")
	await step(Vector2(0, -1), 45)
	assert(player.animation_player.current_animation == "Walk")
	await step(Vector2.ZERO, 30, true)
	assert(player.animation_player.current_animation == "Idle")
	# A single RMB click with empty hands captures the view direction and starts
	# an autonomous body alignment; the button does not need to remain held.
	var weapon = player.weapon_controller
	weapon.equipped = false
	player.global_basis = Basis.IDENTITY
	player.velocity = Vector3.ZERO
	rig.yaw = deg_to_rad(70.0)
	rig.update_look()
	var unarmed_view: Basis = rig.global_basis
	var align_click := InputEventMouseButton.new()
	align_click.button_index = MOUSE_BUTTON_RIGHT
	align_click.pressed = true
	player._unhandled_input(align_click)
	assert(player._unarmed_aligning)
	await step(Vector2.ZERO, 2)
	assert(player.animation_player.current_animation == "Walk", "Turn-in-place must visibly step the legs")
	assert(is_equal_approx(absf(player.animation_player.get_playing_speed()), player.movement_settings.turn_in_place_animation_speed))
	await step(Vector2.ZERO, 60)
	assert(player.global_basis.z.dot(-unarmed_view.z) > 0.999, "Unarmed RMB click aligns body to captured camera direction")
	assert(not player._unarmed_aligning)
	assert(rig.global_basis.get_rotation_quaternion().angle_to(unarmed_view.get_rotation_quaternion()) < 0.001, "Body alignment preserves camera view")
	# Armed S is a backpedal in all weapon-ready states: movement follows the
	# camera backward while the body and muzzle keep facing its forward axis.
	player.global_transform = Transform3D.IDENTITY
	player.velocity = Vector3.ZERO
	rig.yaw = 0.0
	rig.pitch = 0.0
	rig.update_look()
	weapon.equipped = true
	await create_timer(0.6).timeout
	for stance in ["low", "high", "aim"]:
		player.global_basis = Basis.IDENTITY
		player.velocity = Vector3.ZERO
		rig.yaw = 0.0
		rig.update_look()
		weapon.high_ready = stance == "high"
		weapon.aim_pressed = stance == "aim"
		await step(Vector2(0, 1), 45)
		var view: Basis = rig.get_movement_basis()
		assert(player.velocity.normalized().dot(view.z.normalized()) > 0.99, stance + " S moves backward from camera")
		assert(player.global_basis.z.dot(-view.z) > 0.999, stance + " body keeps facing camera forward")
		assert(player.animation_player.current_animation == "Walk" and player.animation_player.get_playing_speed() < 0.0, stance + " uses backward walk cycle")
	# Rotating the camera while backpedalling turns the armed body toward the
	# camera forward direction, never toward the backward travel direction.
	player.global_basis = Basis.IDENTITY
	player.velocity = Vector3.ZERO
	rig.yaw = deg_to_rad(70.0)
	rig.update_look()
	var aimed_view: Basis = rig.global_basis
	await step(Vector2(0, 1), 90)
	assert(player.global_basis.z.dot(-aimed_view.z) > 0.995, "Backpedal body follows camera heading")
	assert(rig.global_basis.get_rotation_quaternion().angle_to(aimed_view.get_rotation_quaternion()) < 0.001, "Backpedal turn preserves camera aim")
	# ADS diagonal movement is still strafing: WASD changes travel, while the
	# torso settles onto the camera/weapon heading rather than the diagonal.
	player.global_basis = Basis(Vector3.UP, deg_to_rad(45.0))
	player.velocity = Vector3.ZERO
	rig.yaw = deg_to_rad(-45.0)
	rig.update_look()
	var diagonal_aim_view: Basis = rig.global_basis
	weapon.aim_pressed = true
	await step(Vector2(-1, -1), 90)
	assert(player.global_basis.z.dot(-diagonal_aim_view.z) > 0.995, "ADS WASD keeps the torso facing the camera")
	assert(rig.global_basis.get_rotation_quaternion().angle_to(diagonal_aim_view.get_rotation_quaternion()) < 0.001, "ADS body alignment preserves camera aim")
	var stopped_basis: Basis = player.global_basis
	player.velocity = Vector3.ZERO
	rig.yaw = 0.5
	rig.update_look()
	await step(Vector2.ZERO, 10)
	assert(player.global_basis.is_equal_approx(stopped_basis))
	assert(player.movement_settings.idle_blend >= 0.25 and player.movement_settings.sprint_blend >= 0.25)
	for point in [Vector3(-12, 0.2, -16), Vector3(12, 0.2, -16), Vector3(-12, 0.2, 16), Vector3(12, 0.2, 16)]:
		player.position = point
		player.velocity = Vector3.ZERO
		await step(Vector2.ZERO, 30)
		assert(player.is_on_floor() and player.position.y > -0.2)
	print("PASS: locomotion, animated turn-in-place, unarmed RMB click alignment, armed backpedal and floor")
	scene.queue_free()
	quit()
