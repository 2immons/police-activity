extends CharacterBody3D

@export var movement_settings: BasicPlayerMovementSettings = preload("res://experiments/player/movement_settings.tres")
@export var look_rig: PlayerLookController
@export var weapon_controller: PlayerWeaponPoseController
@onready var animation_player: AnimationPlayer = $UAL1_Standard/AnimationPlayer
@onready var footsteps: AudioStreamPlayer3D = $Footsteps
@onready var body_environment: BodyEnvironmentInteractionController = $BodyEnvironmentInteraction
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var door_interaction: DoorInteractionController = $DoorInteraction
@onready var damage_reaction: SkeletonModifier3D = $UAL1_Standard/Armature/GeneralSkeleton/PlayerHitReaction
@onready var skeleton: Skeleton3D = $UAL1_Standard/Armature/GeneralSkeleton
@onready var stress_controller: PlayerStressController = $Stress
@export var damage_settings: NpcReactionSettings = preload("res://npc/npc_settings.tres")
var _turn_velocity := 0.0
var _moving := false
var _jog_animation := false
var _sprint_animation := false
var _crouching := false
var _jogging_enabled := false
var _shift_held := false
var _shift_hold_time := 0.0
var _shift_became_sprint := false
var _jogging_before_sprint := false
var _aim_was_active := false
var _aim_fast_walk := false
var _jogging_before_aim := false
var _shift_started_in_aim := false
var _standing_collider_height := 0.0
var _standing_collider_y := 0.0
var _armed_backpedal := false
var _previous_backpedal_animation := false
var _footsteps_target_db := -80.0
var _unarmed_aligning := false
var _unarmed_align_direction := Vector3.ZERO
var dead := false
var chest_hits := 0
var death_ragdoll: CharacterBody3D
var _chest_bone_index := -1

func is_sprinting() -> bool:
	return _sprint_animation

func is_jogging() -> bool:
	return _jog_animation

func is_crouching() -> bool:
	return _crouching

func is_aim_fast_walking() -> bool:
	return _aim_fast_walk

func get_step_phase() -> float:
	return look_rig.camera_motion.get_step_phase() if is_instance_valid(look_rig) and is_instance_valid(look_rig.camera_motion) else 0.0

func _ready() -> void:
	animation_player.play("Idle")
	_standing_collider_height = (collision_shape.shape as CapsuleShape3D).height
	_standing_collider_y = collision_shape.position.y
	# The imported track contains a sequence of steps and should repeat while moving.
	footsteps.stream.loop = true
	damage_reaction.settings = damage_settings
	_chest_bone_index = skeleton.find_bone("UpperChest")
	assert(_chest_bone_index >= 0, "Player rig requires UpperChest")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_aim_movement_state()
	var input_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_advance_shift_state(delta)
	var sprint_requested := _shift_held and _shift_became_sprint
	move_player(input_direction, delta, sprint_requested, _jogging_enabled, _crouching)
	_update_footsteps(delta)

func _advance_shift_state(delta: float) -> void:
	if not _shift_held or _shift_became_sprint or _shift_started_in_aim:
		return
	_shift_hold_time += delta
	if _shift_hold_time >= movement_settings.sprint_hold_delay:
		_shift_became_sprint = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_SHIFT:
			if event.pressed:
				_update_aim_movement_state()
				_shift_held = true
				_shift_hold_time = 0.0
				_shift_became_sprint = false
				_jogging_before_sprint = _jogging_enabled
				_shift_started_in_aim = _aim_was_active
			else:
				_shift_held = false
				if _shift_started_in_aim and _aim_was_active:
					_aim_fast_walk = not _aim_fast_walk
				elif not _shift_became_sprint:
					_jogging_enabled = not _jogging_enabled
				else:
					_jogging_enabled = _jogging_before_sprint
				_shift_started_in_aim = false
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_CTRL and event.pressed:
			_crouching = not _crouching
			get_viewport().set_input_as_handled()
			return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
		and _is_unarmed()
		and is_instance_valid(look_rig)
	):
		_unarmed_align_direction = -look_rig.global_basis.z
		_unarmed_align_direction.y = 0.0
		_unarmed_align_direction = _unarmed_align_direction.normalized()
		_unarmed_aligning = _unarmed_align_direction.length_squared() > 0.001
		get_viewport().set_input_as_handled()

func move_player(input_direction: Vector2, delta: float, sprint_pressed: bool = false, jog_enabled: bool = false, crouching: bool = false) -> void:
	_update_aim_movement_state()
	var view_basis: Basis = look_rig.get_movement_basis() if is_instance_valid(look_rig) else global_basis * Basis(Vector3.UP, PI)
	var forward := -view_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var input_vector := input_direction.limit_length()
	if input_vector.length_squared() > 0.001 or not _is_unarmed():
		_unarmed_aligning = false
	var strafing := absf(input_vector.x) > 0.001 and absf(input_vector.y) < 0.001
	if strafing:
		# Side steps follow the body's right axis even while looking over a shoulder.
		right = -global_basis.x
		right.y = 0.0
		right = right.normalized()
	var direction := right * input_vector.x - forward * input_vector.y
	var reload_limited: bool = is_instance_valid(weapon_controller) and weapon_controller.reloading
	var aiming: bool = _aim_was_active and not crouching
	var sprinting: bool = sprint_pressed and input_vector.y < -0.001 and not crouching and not reload_limited and not aiming
	var jogging: bool = jog_enabled and not crouching and not aiming
	# With a pistol held, S is a backward tactical step. Keep the torso and
	# weapon facing the camera heading instead of turning toward travel.
	_armed_backpedal = (
		input_vector.y > 0.001
		and is_instance_valid(weapon_controller)
		and weapon_controller.equipped
		and weapon_controller.draw_amount > 0.95
	)
	var speed: float = (
		movement_settings.crouch_speed if crouching
		else movement_settings.aim_fast_speed if aiming and _aim_fast_walk
		else movement_settings.aim_slow_speed if aiming
		else movement_settings.sprint_speed if sprinting
		else movement_settings.jog_speed if jogging
		else movement_settings.walk_speed
	)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity := direction * speed
	var acceleration: float = movement_settings.acceleration
	var alignment := horizontal.normalized().dot(direction.normalized()) if horizontal.length_squared() > 0.01 and direction.length_squared() > 0.001 else 1.0
	if direction.length_squared() < 0.001 or (horizontal.length() > speed and alignment >= 0.95):
		acceleration = movement_settings.braking
	elif alignment < 0.95:
		acceleration = movement_settings.sprint_direction_acceleration if sprinting else movement_settings.direction_acceleration
	horizontal = horizontal.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_push_released_doors(horizontal)
	_update_crouch_collider(delta, crouching)
	var actual_horizontal := Vector3(get_real_velocity().x, 0.0, get_real_velocity().z)
	body_environment.advance(delta, horizontal, self, weapon_controller)
	var aim_movement_locked: bool = (
		actual_horizontal.length() > 0.1
		and is_instance_valid(weapon_controller)
		and weapon_controller.equipped
		and weapon_controller.draw_amount > 0.95
		and weapon_controller.aim_pressed
		and (not is_instance_valid(look_rig) or not look_rig.is_free_looking())
	)
	if aim_movement_locked:
		# ADS movement is tactical strafing/backpedalling. Keep the chest and
		# weapon on the camera heading instead of turning the body toward WASD.
		_turn_toward_movement(forward, delta)
	elif _armed_backpedal and actual_horizontal.length() > 0.1:
		_turn_toward_movement(forward, delta)
	elif direction.length_squared() > 0.001 and not strafing and actual_horizontal.length() > 0.1:
		_turn_toward_movement(actual_horizontal, delta)
	elif direction.length_squared() < 0.001 and actual_horizontal.length() < 0.1 and is_on_floor():
		if _unarmed_aligning:
			_turn_unarmed_to_direction(delta)
		else:
			_turn_armed_in_place(delta)
	else:
		_turn_velocity = 0.0
	_update_locomotion_animation(actual_horizontal.length(), sprinting, jogging, crouching)

func _update_aim_movement_state() -> void:
	var aiming_now: bool = (
		is_instance_valid(weapon_controller)
		and weapon_controller.equipped
		and weapon_controller.aim_pressed
	)
	if aiming_now == _aim_was_active:
		return
	if aiming_now:
		_jogging_before_aim = _jogging_enabled
		_aim_fast_walk = _jogging_enabled
	else:
		# ADS меняет только свой временный темп, а исходный locomotion mode сохраняется.
		_jogging_enabled = _jogging_before_aim
		_aim_fast_walk = false
	_aim_was_active = aiming_now

func _push_released_doors(movement_velocity: Vector3) -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var door := _find_door_owner(collision.get_collider())
		if is_instance_valid(door):
			door.try_body_push(movement_velocity, collision.get_position(), collision.get_normal())

func _find_door_owner(node: Node) -> Node:
	var current := node
	while is_instance_valid(current):
		if current.is_in_group("interactable_door"):
			return current
		current = current.get_parent()
	return null

func _update_locomotion_animation(actual_speed: float, sprinting: bool = false, jogging: bool = false, crouching: bool = false) -> void:
	# Hysteresis avoids restarting blends when speed fluctuates around a boundary.
	_moving = actual_speed > (0.06 if _moving else 0.12)
	var turning_in_place := (
		not _moving
		and is_on_floor()
		and absf(_turn_velocity) >= deg_to_rad(movement_settings.footsteps_turn_threshold_degrees)
	)
	var sprint_threshold: float = lerpf(movement_settings.walk_speed, movement_settings.sprint_speed, 0.20 if _sprint_animation else 0.40)
	_sprint_animation = _moving and sprinting and actual_speed > sprint_threshold
	_jog_animation = _moving and jogging and not sprinting
	var next_animation := "Walk" if _moving or turning_in_place else "Idle"
	if crouching:
		next_animation = "Crouch_Fwd" if _moving else "Crouch_Idle"
	elif _sprint_animation:
		next_animation = "Sprint"
	elif _jog_animation:
		next_animation = "Jog_Fwd"
	var unarmed_bracing: bool = _is_unarmed() and body_environment.get_collision_reflex_weight() > 0.05
	if unarmed_bracing:
		next_animation = "Push"
	var reverse_walk := _armed_backpedal and _moving and not _sprint_animation and not _jog_animation
	var animation_speed := -1.0 if reverse_walk else 1.0
	if turning_in_place:
		animation_speed = signf(_turn_velocity) * movement_settings.turn_in_place_animation_speed
	if unarmed_bracing:
		animation_speed = 0.0
	if (
		animation_player.current_animation != next_animation
		or reverse_walk != _previous_backpedal_animation
		or turning_in_place and not is_equal_approx(animation_player.get_playing_speed(), animation_speed)
	):
		var blend: float = movement_settings.animation_blend
		if next_animation == "Idle":
			blend = movement_settings.idle_blend
		elif next_animation == "Sprint" or animation_player.current_animation == "Sprint":
			blend = movement_settings.sprint_blend
		elif next_animation.begins_with("Crouch") or animation_player.current_animation.begins_with("Crouch"):
			blend = movement_settings.crouch_blend
		elif next_animation == "Push":
			blend = body_environment.settings.reflex_animation_blend
		animation_player.play(next_animation, blend, animation_speed, reverse_walk)
	if unarmed_bracing:
		var push_clip := animation_player.get_animation("Push")
		animation_player.seek(push_clip.length * body_environment.settings.reflex_push_pose, true)
	_previous_backpedal_animation = reverse_walk
	_footsteps_target_db = -80.0
	var rate: float = movement_settings.footsteps_walk_rate
	if _moving and is_on_floor():
		_footsteps_target_db = movement_settings.footsteps_volume_db
		if _sprint_animation:
			rate = movement_settings.footsteps_sprint_rate
		elif _jog_animation:
			rate = movement_settings.footsteps_jog_rate
		elif crouching:
			rate = movement_settings.footsteps_crouch_rate
	elif turning_in_place:
		_footsteps_target_db = movement_settings.footsteps_turn_volume_db
		rate = movement_settings.footsteps_turn_rate
	footsteps.pitch_scale = rate
	var bus_index := AudioServer.get_bus_index(&"Footsteps")
	if bus_index >= 0:
		var pitch_compensation := AudioServer.get_bus_effect(bus_index, 0) as AudioEffectPitchShift
		if is_instance_valid(pitch_compensation):
			pitch_compensation.pitch_scale = 1.0 / rate

func _update_crouch_collider(delta: float, crouching: bool) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	var target_height: float = movement_settings.crouch_collider_height if crouching else _standing_collider_height
	var target_y: float = _standing_collider_y - (_standing_collider_height - target_height) * 0.5
	capsule.height = move_toward(capsule.height, target_height, movement_settings.crouch_collider_speed * delta)
	collision_shape.position.y = move_toward(collision_shape.position.y, target_y, movement_settings.crouch_collider_speed * 0.5 * delta)

func _update_footsteps(delta: float) -> void:
	if _footsteps_target_db > -79.0 and not footsteps.playing:
		footsteps.play()
	footsteps.volume_db = move_toward(
		footsteps.volume_db,
		_footsteps_target_db,
		movement_settings.footsteps_fade_speed * delta * 80.0
	)
	if _footsteps_target_db <= -79.0 and footsteps.volume_db <= -79.0 and footsteps.playing:
		footsteps.stop()

func _turn_toward_movement(direction: Vector3, delta: float) -> void:
	# The imported character faces +Z. Rotate the body toward its travel direction.
	var body_forward := global_basis.z
	body_forward.y = 0.0
	var angle := body_forward.normalized().signed_angle_to(direction.normalized(), Vector3.UP)
	_turn_by_angle(angle, delta, movement_settings.turn_speed_degrees, movement_settings.turn_acceleration_degrees, movement_settings.turn_response)

func _turn_armed_in_place(delta: float) -> void:
	if is_instance_valid(look_rig) and look_rig.is_free_looking():
		_turn_velocity = 0.0
		return
	if not is_instance_valid(look_rig) or not is_instance_valid(weapon_controller) or not weapon_controller.equipped or weapon_controller.draw_amount < 0.95:
		_turn_velocity = 0.0
		return
	var relative_yaw: float = wrapf(look_rig.yaw, -PI, PI)
	var limit := deg_to_rad(movement_settings.armed_free_look_degrees)
	var excess := maxf(absf(relative_yaw) - limit, 0.0)
	if excess < 0.0001:
		_turn_velocity = 0.0
		return
	_turn_by_angle(signf(relative_yaw) * excess, delta, movement_settings.armed_turn_speed_degrees, movement_settings.armed_turn_acceleration_degrees, movement_settings.armed_turn_response)

func _is_unarmed() -> bool:
	return not is_instance_valid(weapon_controller) or not weapon_controller.equipped

func get_chest_target_position() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_chest_bone_index).origin

func get_damage_collision_rids() -> Array[RID]:
	var result: Array[RID] = [get_rid()]
	for attachment in get_tree().get_nodes_in_group("player_hit_zone_attachment"):
		if skeleton.is_ancestor_of(attachment):
			for child in attachment.get_children():
				if child is CollisionObject3D:
					result.append(child.get_rid())
	return result

func receive_bullet_hit(damage: float, hit_position: Vector3, direction: Vector3) -> void:
	var local := to_local(hit_position)
	if local.y > 1.48:
		receive_zone_hit("HEAD", &"Head", damage, hit_position, direction)
	elif local.y > 0.95 and absf(local.x) > 0.24:
		var left := local.x > 0.0
		receive_zone_hit("LEFT_ARM" if left else "RIGHT_ARM", &"LeftUpperArm" if left else &"RightUpperArm", damage, hit_position, direction)
	elif local.y > 0.9:
		receive_zone_hit("CHEST", &"UpperChest", damage, hit_position, direction)
	else:
		var left := local.x > 0.0
		receive_zone_hit("LEFT_LEG" if left else "RIGHT_LEG", &"LeftUpperLeg" if left else &"RightUpperLeg", damage, hit_position, direction)

func receive_zone_hit(zone: String, bone_name: StringName, _damage: float, hit_position: Vector3, direction: Vector3) -> void:
	if dead:
		return
	stress_controller.apply_suppression(hit_position - direction * 4.0, hit_position, 1.0, true)
	if is_instance_valid(look_rig) and is_instance_valid(look_rig.camera_motion):
		look_rig.camera_motion.add_hit_impulse(direction, hit_position, zone)
	var lethal := zone == "HEAD"
	if zone == "CHEST":
		chest_hits += 1
		lethal = chest_hits >= damage_settings.chest_hits_to_kill
	if lethal:
		_die_from_hit(zone, bone_name, hit_position, direction)
		return
	damage_reaction.add_impulse(bone_name, direction, damage_settings.limb_impulse)
	if zone in ["LEFT_ARM", "RIGHT_ARM", "LEFT_LEG", "RIGHT_LEG"]:
		damage_reaction.add_impulse(&"UpperChest", direction, damage_settings.limb_impulse * damage_settings.torso_transfer)

func receive_suppression(origin: Vector3, closest_point: Vector3, amount: float = 0.35) -> void:
	if not dead:
		stress_controller.apply_suppression(origin, closest_point, amount)

func _die_from_hit(zone: String, bone_name: StringName, hit_position: Vector3, direction: Vector3) -> void:
	if dead:
		return
	dead = true
	set_physics_process(false)
	set_process_unhandled_input(false)
	collision_shape.set_deferred("disabled", true)
	$UAL1_Standard.visible = false

	if is_instance_valid(weapon_controller):
		weapon_controller.equipped = false
		weapon_controller.aim_pressed = false
		weapon_controller.reloading = false
		weapon_controller.process_mode = Node.PROCESS_MODE_DISABLED
	var weapon_rig := get_node_or_null("WeaponRig") as Node3D
	if weapon_rig != null:
		weapon_rig.visible = false
	if is_instance_valid(door_interaction):
		door_interaction.process_mode = Node.PROCESS_MODE_DISABLED

	death_ragdoll = load("res://npc/npc.tscn").instantiate()
	get_parent().add_child(death_ragdoll)
	death_ragdoll.set_ai_active(false)
	death_ragdoll.global_transform = global_transform
	death_ragdoll.force_ragdoll(zone, bone_name, hit_position, direction)

	# Камера наследует падение головы, но больше не принимает look/aim input.
	if is_instance_valid(look_rig):
		var ragdoll_head: PhysicalBone3D = death_ragdoll.get_physical_bone(&"Head")
		look_rig.detach_camera_for_death(ragdoll_head)
		look_rig.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _turn_unarmed_to_direction(delta: float) -> void:
	if not is_instance_valid(look_rig) or _unarmed_align_direction.length_squared() < 0.001:
		_unarmed_aligning = false
		_turn_velocity = 0.0
		return
	var body_forward := global_basis.z
	body_forward.y = 0.0
	var angle := body_forward.normalized().signed_angle_to(_unarmed_align_direction, Vector3.UP)
	if absf(angle) < deg_to_rad(0.1):
		_unarmed_aligning = false
		_turn_velocity = 0.0
		return
	_turn_by_angle(
		angle,
		delta,
		movement_settings.unarmed_align_turn_speed_degrees,
		movement_settings.unarmed_align_turn_acceleration_degrees,
		movement_settings.unarmed_align_turn_response
	)

func _turn_by_angle(angle: float, delta: float, speed_degrees: float, acceleration_degrees: float, response: float) -> void:
	var max_rate := deg_to_rad(speed_degrees)
	var desired_rate := clampf(angle * response, -max_rate, max_rate)
	_turn_velocity = move_toward(_turn_velocity, desired_rate, deg_to_rad(acceleration_degrees) * delta)
	var turn := _turn_velocity * delta
	if signf(turn) == signf(angle) and absf(turn) > absf(angle):
		turn = angle
		_turn_velocity = 0.0
	global_basis = Basis(Vector3.UP, turn) * global_basis
	if is_instance_valid(look_rig):
		# Transfer yaw from free look to the body without turning the view a second time.
		look_rig.compensate_body_turn(turn)
