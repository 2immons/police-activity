class_name NpcTacticalMovementController
extends Node

@export var navigation_agent: NavigationAgent3D
var npc: NPC
var blackboard: Blackboard
var profile: CombatAIProfile
var destination := Vector3.ZERO
var active := false
var speed_mode := &"WALK"
var _avoid_direction := Vector3.ZERO
var _avoid_time := 0.0

func configure(owner_npc: NPC, state: Blackboard, ai_profile: CombatAIProfile) -> void:
	npc = owner_npc
	blackboard = state
	profile = ai_profile

func move_to(point: Vector3, reason: StringName, mode: StringName) -> void:
	destination = point
	active = true
	speed_mode = mode
	blackboard.set_var(&"movement_reason", reason)
	blackboard.set_var(&"movement_destination", point)
	if navigation_agent != null and navigation_agent.is_inside_tree():
		navigation_agent.target_position = point

func has_reached(point: Vector3) -> bool:
	return npc.global_position.distance_to(point) <= profile.search_arrival_distance

func stop(reason: StringName = &"TACTICAL_HOLD") -> void:
	active = false
	_avoid_time = 0.0
	blackboard.set_var(&"movement_reason", reason)
	blackboard.set_var(&"movement_speed", 0.0)
	blackboard.set_var(&"stability", 1.0)
	if is_instance_valid(npc):
		npc.velocity.x = 0.0
		npc.velocity.z = 0.0

func advance(delta: float) -> bool:
	_avoid_time = maxf(_avoid_time - delta, 0.0)
	var desired := Vector3.ZERO
	var arrived := true
	if active:
		var next := destination
		# Без запечённой NavigationRegion агент существует, но возвращает позицию NPC.
		# В таком случае сохраняем рабочий direct steering для тестовых площадок.
		if navigation_agent != null and navigation_agent.get_current_navigation_path().size() > 1 and not navigation_agent.is_navigation_finished():
			next = navigation_agent.get_next_path_position()
		var offset := next - npc.global_position
		offset.y = 0.0
		arrived = npc.global_position.distance_to(destination) <= 0.55
		if not arrived and offset.length_squared() > 0.001:
			var direction := offset.normalized()
			if _avoid_time > 0.0:
				direction = (_avoid_direction * 0.88 + direction * 0.12).normalized()
			desired = direction * _speed()
		else:
			active = false
	var horizontal := Vector3(npc.velocity.x, 0.0, npc.velocity.z).move_toward(desired, profile.acceleration * delta)
	npc.velocity.x = horizontal.x
	npc.velocity.z = horizontal.z
	if not npc.is_on_floor():
		npc.velocity += npc.get_gravity() * delta
	else:
		npc.velocity.y = 0.0
	npc.move_and_slide()
	_update_collision_avoidance(desired)
	blackboard.set_var(&"movement_speed", horizontal.length())
	blackboard.set_var(&"stability", clampf(1.0 - horizontal.length() / maxf(profile.jog_speed, 0.1) * 0.62, 0.25, 1.0))
	return arrived

func _update_collision_avoidance(desired_velocity: Vector3) -> void:
	if desired_velocity.length_squared() < 0.01 or npc.get_slide_collision_count() == 0:
		return
	var collision := npc.get_slide_collision(0)
	var normal := collision.get_normal()
	normal.y = 0.0
	if normal.length_squared() < 0.01:
		return
	normal = normal.normalized()
	var tangent := Vector3(-normal.z, 0.0, normal.x)
	var toward_goal := destination - npc.global_position
	toward_goal.y = 0.0
	if (-tangent).dot(toward_goal) > tangent.dot(toward_goal):
		tangent = -tangent
	_avoid_direction = tangent
	_avoid_time = 0.65

func face_direction(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.001:
		return
	# Gameplay-forward в Godot — локальная -Z.
	var desired_yaw := atan2(-flat.x, -flat.z)
	npc.rotation.y = lerp_angle(npc.rotation.y, desired_yaw, 1.0 - exp(-profile.turn_speed * delta))

func _speed() -> float:
	match speed_mode:
		&"RUN": return profile.run_speed
		&"JOG": return profile.jog_speed
		&"TACTICAL_WALK": return profile.tactical_walk_speed
		_: return profile.walk_speed
