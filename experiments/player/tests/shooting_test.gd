extends SceneTree
var controller
var rig
var player
var sk: Skeleton3D
func _initialize(): call_deferred("run")
func run():
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	assert(scene.has_node("Player/WeaponRig/ObstructionProbe"))
	assert(scene.has_node("Player/WeaponRig/Glock17/Muzzle/Flash"))
	root.add_child(scene)
	player = scene.get_node("Player")
	player.set_physics_process(false)
	controller = player.weapon_controller
	rig = player.look_rig
	sk = controller.get_parent()
	controller.equipped = true
	controller.aim_pressed = true
	await create_timer(0.8).timeout
	assert(controller.aim_amount == 1.0 and not controller.obstructed)
	var old_rounds: int = controller.rounds
	var muzzle: Marker3D = controller.weapon.get_node("Muzzle")
	var direction := -muzzle.global_basis.z.normalized()
	var origin := muzzle.global_position
	var initial_sight_alignment: float = (controller.weapon.get_node("Sight").global_position - rig.camera.global_position).normalized().dot(direction)
	controller._fire_requested = true
	await process_frame
	await process_frame
	assert(controller.shots_fired == 1 and controller.rounds == old_rounds - 1)
	assert(controller.last_shot.direction.dot(direction) > 0.999)
	assert(controller.last_shot.origin.distance_to(origin) < 0.01)
	assert(not controller.last_shot.hit.is_empty(), "Shot hits corridor end wall")
	assert(controller.recoil.angles.x > 0.01 and controller.recoil.backward_offset > 0.005)
	assert(absf(controller.recoil.angles.y) >= deg_to_rad(controller.settings.recoil_yaw_degrees * controller.settings.recoil_yaw_minimum_factor) * 0.55, "Shot must kick the pistol sideways before hand IK follows it")
	assert(controller.settings.recoil_yaw_degrees == 4.0 and controller.settings.max_recoil_yaw_degrees == 8.0, "Horizontal recoil must remain noticeable but below the previous excessive tuning")
	assert(not controller.try_fire(), "Rate limit enforced")
	var checked := [false]
	controller.modification_processed.connect(func():
		for side in ["Right", "Left"]:
			var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin
			assert(hand.distance_to(controller.weapon.get_node("Grip" + side).global_position) < 0.025, "Hands follow recoil")
		checked[0] = true
	, CONNECT_ONE_SHOT)
	await process_frame
	await process_frame
	assert(checked[0])
	var retained_pitch: float = controller.recoil.angles.x
	var first_retained_yaw: float = controller.recoil.retained_yaw
	assert(absf(first_retained_yaw) > 0.001, "Part of horizontal kick must be retained")
	await create_timer(0.6).timeout
	assert(controller.recoil.angles.x < retained_pitch * 0.7, "Pitch partially recovers")
	assert(controller.recoil.retained_pitch > 0.001, "Some muzzle climb remains")
	assert(absf(controller.recoil.angles.x - controller.recoil.retained_pitch) < 0.005, "Recovery settles at retained pitch")
	assert(absf(controller.recoil.angles.y - first_retained_yaw) < 0.005, "Horizontal recovery must settle at a retained offset instead of zero")
	assert(controller.recoil.backward_offset < 0.001, "Transient backward kick settles")
	assert((-muzzle.global_basis.z).dot(Vector3.UP) > direction.dot(Vector3.UP) + 0.005, "Barrel stays above original aim")
	var settled_sight_direction: Vector3 = (controller.weapon.get_node("Sight").global_position - rig.camera.global_position).normalized()
	assert(absf(settled_sight_direction.dot(-muzzle.global_basis.z) - initial_sight_alignment) < 0.004, "Settled recoil must restore the original rear/front sight alignment at the displaced aim angle")
	controller._fire_requested = true
	await process_frame
	await process_frame
	assert(controller.shots_fired == 2)
	assert(controller.last_shot.direction.angle_to(direction) > 0.005, "Next shot follows the raised barrel")
	assert(controller.recoil.angles.x > retained_pitch, "Successive shots accumulate pitch")
	await create_timer(0.6).timeout
	var pull_down := InputEventMouseMotion.new()
	pull_down.relative.y = controller.recoil.angles.x / rig.sensitivity
	pull_down.relative.x = controller.recoil.angles.y / rig.sensitivity
	rig._unhandled_input(pull_down)
	await process_frame
	await process_frame
	assert(controller.recoil.angles.x < 0.0001, "Mouse pull compensates accumulated pitch")
	assert(controller.recoil.retained_pitch < 0.0001, "Compensation clears the recovery target too")
	assert(absf(controller.recoil.angles.y) < 0.0001 and absf(controller.recoil.retained_yaw) < 0.0001, "Opposite mouse yaw compensates retained horizontal recoil")
	assert(absf(rig.pitch) < 0.0001, "Compensation does not double-apply to the camera")
	rig.set_free_look(true)
	rig.yaw = deg_to_rad(70)
	rig.update_look()
	await create_timer(0.1).timeout
	var barrel_forward := -muzzle.global_basis.z.normalized()
	controller._fire_requested = true
	await process_frame
	await process_frame
	assert(controller.shots_fired == 3)
	var free_pitch: float = controller.recoil.angles.x
	assert(controller.compensate_recoil_pitch(-0.1) == -0.1)
	assert(controller.recoil.angles.x == free_pitch, "Alt look does not compensate weapon recoil")
	assert(controller.last_shot.direction.dot(barrel_forward) > 0.999, "Alt shots follow barrel")
	assert(controller.last_shot.direction.dot(-rig.global_basis.z) < 0.6, "Shots must not follow free-look camera")
	rig.set_free_look(false)
	await create_timer(0.9).timeout
	player.position = Vector3(0, 0, 13.45)
	await create_timer(0.5).timeout
	assert(controller.obstructed and controller.aim_amount == 1.0, "Wall keeps ADS and adaptively compresses the arms")
	assert(controller.obstruction.compression > 0.01 and controller.obstruction.compression <= controller.settings.obstruction_max_compression, "Compression must match available muzzle clearance")
	var count: int = controller.shots_fired
	controller._fire_requested = true
	await create_timer(0.1).timeout
	assert(controller.shots_fired == count + 1, "Compressed ADS may fire once the muzzle is kept behind the wall")
	await create_timer(0.4).timeout
	assert(controller.obstructed and controller.aim_amount == 1.0, "No compressed-ADS/low-ready oscillation")
	player.position = Vector3(0, 0, 12.5)
	await create_timer(0.5).timeout
	assert(not controller.obstructed and controller.aim_amount == 1.0, "Clearance restores aim while RMB held")
	controller.rounds = 0
	assert(not controller.try_fire(), "Empty magazine")
	controller.start_reload()
	assert(not controller.try_fire(), "No shooting during reload")
	await create_timer(1.8).timeout
	assert(controller.rounds == 17)
	var buffered_count: int = controller.shots_fired
	controller.firearm.set_cooldown(controller.settings.shot_interval * 0.8)
	controller._fire_requested = true
	await process_frame
	assert(controller.shots_fired == buffered_count and controller._fire_requested, "Early click must remain buffered during Shot Interval")
	await create_timer(controller.settings.shot_interval).timeout
	assert(controller.shots_fired == buffered_count + 1 and not controller._fire_requested, "Buffered click must fire automatically when Shot Interval ends")
	print("PASS: moved resources, muzzle hitscan, ammo/rate limit and input buffer, recoil/hand IK, Alt direction, wall lowering/hysteresis/recovery, reload guards")
	scene.queue_free()
	quit()
