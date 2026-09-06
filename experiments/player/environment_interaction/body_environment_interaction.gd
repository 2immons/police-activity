class_name BodyEnvironmentInteractionController
extends Node3D

const LEFT_HAND := &"LEFT_HAND"
const RIGHT_HAND := &"RIGHT_HAND"
const HEAD := &"HEAD"
const LEFT_SHOULDER := &"LEFT_SHOULDER"
const RIGHT_SHOULDER := &"RIGHT_SHOULDER"
const FEET := &"FEET"
const TRAJECTORY := &"TRAJECTORY"

@export var settings: BodyEnvironmentInteractionSettings = preload("res://experiments/player/environment_interaction/body_environment_interaction_settings.tres")
@onready var trajectory: Node3D = $Trajectory
@onready var center_probe: ShapeCast3D = $Trajectory/Center
@onready var left_hand_probe: ShapeCast3D = $Trajectory/LeftHand
@onready var right_hand_probe: ShapeCast3D = $Trajectory/RightHand
@onready var head_probe: ShapeCast3D = $Trajectory/Head
@onready var feet_probe: ShapeCast3D = $Trajectory/Feet
@onready var left_shoulder_probe: ShapeCast3D = $Shoulders/Left
@onready var right_shoulder_probe: ShapeCast3D = $Shoulders/Right

var interactions: Dictionary[StringName, BodySurfaceInteraction] = {}
var _center_interaction := BodySurfaceInteraction.new()
var wall_squeeze_angle := 0.0
var collision_reflex_amount := 0.0
var collision_reflex_impulse := 0.0
var collision_reflex_direction := Vector3.ZERO
var collision_reflex_contact_distance := INF

func _ready() -> void:
	var body := get_parent() as CollisionObject3D
	for probe in [center_probe, left_hand_probe, right_hand_probe, head_probe, feet_probe, left_shoulder_probe, right_shoulder_probe]:
		probe.add_exception(body)
		interactions[_zone_for_probe(probe)] = BodySurfaceInteraction.new()
	interactions[TRAJECTORY] = BodySurfaceInteraction.new()

func advance(delta: float, intended_velocity: Vector3, body: CharacterBody3D, weapon) -> void:
	var horizontal_velocity := Vector3(intended_velocity.x, 0.0, intended_velocity.z)
	var speed := horizontal_velocity.length()
	if speed > 0.05:
		collision_reflex_direction = horizontal_velocity.normalized()
		var right := Vector3.UP.cross(collision_reflex_direction).normalized()
		trajectory.global_basis = Basis(right, Vector3.UP, collision_reflex_direction)
	var lookahead: float = clampf(speed * settings.prediction_time, settings.minimum_lookahead, settings.maximum_lookahead)
	_update_trajectory_targets(lookahead)
	_update_interactions(horizontal_velocity, body)
	_update_side_squeeze(delta, speed, body, weapon)
	_update_collision_reflex(delta, speed, body)

func get_interaction(zone: StringName) -> Dictionary:
	var interaction: BodySurfaceInteraction = interactions.get(zone)
	return interaction.to_dictionary() if interaction != null else BodySurfaceInteraction.new().to_dictionary()

func get_surface_interaction(zone: StringName) -> BodySurfaceInteraction:
	return interactions.get(zone)

func get_collision_reflex_weight() -> float:
	return clampf(collision_reflex_amount + collision_reflex_impulse * settings.impact_arm_impulse, 0.0, 1.0)

func _update_trajectory_targets(distance: float) -> void:
	var fan := deg_to_rad(settings.trajectory_fan_degrees)
	center_probe.target_position = Vector3(0.0, 0.0, distance)
	left_hand_probe.target_position = Vector3(sin(fan) * distance, 0.0, cos(fan) * distance)
	right_hand_probe.target_position = Vector3(-sin(fan) * distance, 0.0, cos(fan) * distance)
	head_probe.target_position = Vector3(0.0, 0.0, distance)
	feet_probe.target_position = Vector3(0.0, -0.65, minf(distance, 1.25))

func _update_interactions(relative_velocity: Vector3, body: CharacterBody3D) -> void:
	for probe in [center_probe, left_hand_probe, right_hand_probe, head_probe, feet_probe, left_shoulder_probe, right_shoulder_probe]:
		probe.force_shapecast_update()
		_read_probe_into(probe, relative_velocity, body.global_position.y, interactions[_zone_for_probe(probe)])
	_read_probe_into(center_probe, relative_velocity, body.global_position.y, _center_interaction)
	_select_nearest_interaction([interactions[LEFT_HAND], interactions[RIGHT_HAND], _center_interaction], interactions[TRAJECTORY])

func _update_side_squeeze(delta: float, speed: float, body: CharacterBody3D, weapon) -> void:
	var ads_active: bool = is_instance_valid(weapon) and weapon.equipped and (weapon.aim_pressed or weapon.aim_amount >= settings.ads_disable_amount)
	var target := 0.0
	if body.is_on_floor() and speed >= settings.minimum_movement_speed and not ads_active:
		var left_strength := _distance_strength(interactions[LEFT_SHOULDER], settings.shoulder_activation_distance, settings.shoulder_full_effect_distance)
		var right_strength := _distance_strength(interactions[RIGHT_SHOULDER], settings.shoulder_activation_distance, settings.shoulder_full_effect_distance)
		target = deg_to_rad(settings.max_torso_yaw_degrees) * (left_strength - right_strength)
	var response: float = settings.squeeze_turn_in_speed_degrees if not is_zero_approx(target) else settings.squeeze_return_speed_degrees
	wall_squeeze_angle = move_toward(wall_squeeze_angle, target, deg_to_rad(response) * delta)

func _update_collision_reflex(delta: float, speed: float, body: CharacterBody3D) -> void:
	var approach: BodySurfaceInteraction = interactions[TRAJECTORY]
	collision_reflex_contact_distance = approach.distance if approach.has_surface else INF
	var target := 0.0
	if speed >= settings.reflex_minimum_speed:
		var distance_strength := _distance_strength(approach, settings.reflex_activation_distance, settings.reflex_full_distance)
		var speed_strength := clampf(inverse_lerp(settings.reflex_minimum_speed, settings.reflex_full_speed, speed), 0.0, 1.0)
		target = distance_strength * speed_strength
		for collision_index in body.get_slide_collision_count():
			var collision := body.get_slide_collision(collision_index)
			if speed >= settings.impact_minimum_speed and collision.get_normal().dot(collision_reflex_direction) < -0.45:
				collision_reflex_impulse = 1.0
				break
	var response: float = settings.reflex_reaction_speed if target > collision_reflex_amount else settings.reflex_return_speed
	collision_reflex_amount = move_toward(collision_reflex_amount, target, response * delta)
	collision_reflex_impulse = move_toward(collision_reflex_impulse, 0.0, settings.impact_decay_speed * delta)

func _read_probe_into(probe: ShapeCast3D, relative_velocity: Vector3, body_height: float, result: BodySurfaceInteraction) -> void:
	result.clear()
	if not probe.is_colliding():
		return
	var nearest_index := -1
	var nearest_distance := INF
	for collision_index in probe.get_collision_count():
		var distance := probe.global_position.distance_to(probe.get_collision_point(collision_index))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = collision_index
	if nearest_index < 0:
		return
	var point := probe.get_collision_point(nearest_index)
	var normal: Vector3 = probe.get_collision_normal(nearest_index)
	var approach_factor := 0.0
	if relative_velocity.length_squared() > 0.0001:
		approach_factor = maxf(-normal.dot(relative_velocity.normalized()), 0.0)
	var closing_speed := maxf(-normal.dot(relative_velocity), 0.001)
	result.has_surface = true
	result.nearest_surface = point
	result.distance = nearest_distance
	result.normal = normal
	result.approach_factor = approach_factor
	result.relative_velocity = relative_velocity
	result.surface_height = point.y - body_height
	result.time_to_contact = nearest_distance / closing_speed
	result.collider = probe.get_collider(nearest_index)

func _select_nearest_interaction(candidates: Array[BodySurfaceInteraction], result: BodySurfaceInteraction) -> void:
	result.clear()
	for candidate: BodySurfaceInteraction in candidates:
		if candidate.has_surface and candidate.approach_factor >= settings.reflex_front_normal_dot and (not result.has_surface or candidate.distance < result.distance):
			result.copy_from(candidate)

func _distance_strength(interaction: BodySurfaceInteraction, activation_distance: float, full_distance: float) -> float:
	if not interaction.has_surface:
		return 0.0
	return clampf(inverse_lerp(activation_distance, full_distance, interaction.distance), 0.0, 1.0)

func _zone_for_probe(probe: ShapeCast3D) -> StringName:
	match probe:
		left_hand_probe: return LEFT_HAND
		right_hand_probe: return RIGHT_HAND
		head_probe: return HEAD
		feet_probe: return FEET
		left_shoulder_probe: return LEFT_SHOULDER
		right_shoulder_probe: return RIGHT_SHOULDER
	return TRAJECTORY
