class_name PhysicalDoor
extends Node3D

enum MotionMode { IDLE, AUTO, CONTROLLED }
enum HandControlMode { NONE, HANDLE_CONTROL, PUSH_ONLY }

@export var settings: PhysicalDoorSettings = preload("res://experiments/doors/door_settings.tres")
@export var locked := false

@onready var body: RigidBody3D = $DoorBody
@onready var hinge: HingeJoint3D = $Hinge
@onready var handle_pivot: Node3D = $DoorBody/HandlePivot
@onready var front_handle_target: Marker3D = $DoorBody/HandleTargets/Front
@onready var rear_handle_target: Marker3D = $DoorBody/HandleTargets/Rear
@onready var debug_label: Label3D = $DebugInfo
@onready var panel_outline: MeshInstance3D = $DoorBody/PanelOutline
@onready var handle_outlines: Array[MeshInstance3D] = [
	$DoorBody/HandlePivot/FrontHubOutline,
	$DoorBody/HandlePivot/FrontLeverOutline,
	$DoorBody/HandlePivot/RearHubOutline,
	$DoorBody/HandlePivot/RearLeverOutline,
]

var current_angle := 0.0
var target_angle := 0.0
var angular_velocity := 0.0
var latch_released := false
var controlled_by_player := false
var motion_mode := MotionMode.IDLE
var hand_control_mode := HandControlMode.NONE
var debug_left_hand_state := "FREE"
var debug_hand_target := "HANDLE"
var _control_side := -1.0
var _handle_amount := 0.0
var _handle_timer := 0.0
var _highlight_target := 0.0
var _highlight_amount := 0.0

func _ready() -> void:
	body.mass = settings.mass
	body.angular_damp = settings.resistance
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(settings.min_angle_degrees))
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(settings.max_angle_degrees))
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, settings.max_motor_impulse)
	target_angle = clampf(body.rotation.y, _min_angle(), _max_angle())

func _physics_process(delta: float) -> void:
	current_angle = clampf(body.rotation.y, _min_angle(), _max_angle())
	angular_velocity = body.angular_velocity.y
	_update_latch(delta)
	_update_motor()
	_update_interaction_highlight(delta)
	_update_debug()

func can_interact() -> bool:
	return not locked

func set_interaction_highlight(enabled: bool) -> void:
	_highlight_target = 1.0 if enabled and can_interact() else 0.0

func _update_interaction_highlight(delta: float) -> void:
	var response := 1.0 - exp(-settings.highlight_transition_speed * delta)
	_highlight_amount = lerpf(_highlight_amount, _highlight_target, response)
	if _highlight_amount < 0.001 and _highlight_target <= 0.0:
		_highlight_amount = 0.0
	panel_outline.set_instance_shader_parameter("highlight_strength", _highlight_amount * settings.panel_highlight_strength)
	for outline in handle_outlines:
		outline.set_instance_shader_parameter("highlight_strength", _highlight_amount * settings.handle_highlight_strength)

func request_auto_toggle() -> bool:
	if locked:
		return false
	_release_latch()
	controlled_by_player = false
	motion_mode = MotionMode.AUTO
	var near_closed := absf(current_angle - _min_angle()) <= deg_to_rad(settings.closed_angle_epsilon_degrees)
	target_angle = deg_to_rad(settings.auto_open_angle_degrees) if near_closed else _min_angle()
	return true

func begin_control(interactor_position: Vector3 = Vector3.ZERO) -> bool:
	if locked:
		return false
	controlled_by_player = true
	motion_mode = MotionMode.CONTROLLED
	hand_control_mode = HandControlMode.HANDLE_CONTROL
	_control_side = _side_for_world_position(interactor_position)
	target_angle = current_angle
	_handle_timer = settings.handle_press_duration if not latch_released else 0.0
	if _handle_timer <= 0.0:
		_release_latch()
	return true

func add_control_angle(delta_angle: float) -> void:
	if not controlled_by_player or not latch_released:
		return
	if hand_control_mode == HandControlMode.PUSH_ONLY:
		if delta_angle <= 0.0:
			return
		target_angle = maxf(target_angle, current_angle)
	target_angle = clampf(target_angle + delta_angle, _min_angle(), _max_angle())

func end_control() -> void:
	controlled_by_player = false
	motion_mode = MotionMode.IDLE
	hand_control_mode = HandControlMode.NONE
	target_angle = current_angle + angular_velocity * settings.release_inertia
	target_angle = clampf(target_angle, _min_angle(), _max_angle())

func try_body_push(movement_velocity: Vector3, contact_position: Vector3, collision_normal: Vector3) -> bool:
	if controlled_by_player or motion_mode == MotionMode.CONTROLLED:
		return false
	if not latch_released or movement_velocity.length() < settings.minimum_body_push_speed:
		return false
	var into_surface: float = maxf(-movement_velocity.dot(collision_normal), 0.0)
	if into_surface < settings.minimum_body_push_speed:
		return false
	controlled_by_player = false
	motion_mode = MotionMode.IDLE
	var impulse: Vector3 = movement_velocity.normalized() * into_surface * settings.body_push_impulse_scale
	body.apply_impulse(impulse, contact_position - body.global_position)
	return true

func get_hand_target() -> Marker3D:
	return _handle_for_side(_control_side)

func get_control_handle_target() -> Marker3D:
	return _handle_for_side(_control_side)

func get_nearest_hand_target(world_position: Vector3) -> Marker3D:
	var nearest: Marker3D = _handle_for_side(_side_for_world_position(world_position))
	for marker in _panel_targets_for_side(_side_for_world_position(world_position)):
		if marker.global_position.distance_to(world_position) < nearest.global_position.distance_to(world_position):
			nearest = marker
	return nearest

func get_hand_target_for_reach(shoulder_position: Vector3, maximum_reach: float) -> Marker3D:
	# Сторону нельзя фиксировать при захвате: распахнутая дверь меняет взаимное
	# положение игрока и ручек. Берём ту ручку, до которой плечу ближе сейчас.
	var front_distance := front_handle_target.global_position.distance_to(shoulder_position)
	var rear_distance := rear_handle_target.global_position.distance_to(shoulder_position)
	_control_side = -1.0 if front_distance <= rear_distance else 1.0
	var handle_target := _handle_for_side(_control_side)
	if handle_target.global_position.distance_to(shoulder_position) <= maximum_reach:
		hand_control_mode = HandControlMode.HANDLE_CONTROL
		debug_hand_target = "HANDLE"
		return handle_target
	hand_control_mode = HandControlMode.PUSH_ONLY
	target_angle = maxf(target_angle, current_angle)
	var panel_targets := _panel_targets_for_side(_control_side)
	var nearest: Marker3D = panel_targets[0]
	for marker in panel_targets:
		if marker.global_position.distance_to(shoulder_position) < nearest.global_position.distance_to(shoulder_position):
			nearest = marker
	debug_hand_target = nearest.name.to_upper()
	return nearest

func _side_for_world_position(world_position: Vector3) -> float:
	return -1.0 if body.to_local(world_position).z <= 0.0 else 1.0

func _handle_for_side(side: float) -> Marker3D:
	return front_handle_target if side < 0.0 else rear_handle_target

func _panel_targets_for_side(side: float) -> Array[Node]:
	return $DoorBody/PanelHandTargets/Front.get_children() if side < 0.0 else $DoorBody/PanelHandTargets/Rear.get_children()

func get_interaction_distance() -> float:
	return settings.interaction_distance

func _release_latch() -> void:
	latch_released = true
	_handle_amount = 1.0

func _update_latch(delta: float) -> void:
	if _handle_timer > 0.0:
		_handle_timer = maxf(_handle_timer - delta, 0.0)
		_handle_amount = 1.0 - _handle_timer / maxf(settings.handle_press_duration, 0.001)
		if _handle_timer <= 0.0:
			_release_latch()
	elif not controlled_by_player:
		_handle_amount = move_toward(_handle_amount, 0.0, settings.handle_return_speed * delta)
	var handle_angle := deg_to_rad(settings.handle_press_degrees) * _handle_amount
	handle_pivot.rotation.z = handle_angle
	var at_closed_stop := absf(current_angle - _min_angle()) <= deg_to_rad(settings.closed_angle_epsilon_degrees)
	var closing_into_stop := angular_velocity < -0.05
	var settled_at_stop := absf(angular_velocity) < 0.08
	if at_closed_stop and motion_mode == MotionMode.IDLE and (closing_into_stop or settled_at_stop):
		latch_released = false
		body.angular_velocity = Vector3.ZERO
		body.linear_velocity = Vector3.ZERO
		target_angle = _min_angle()

func _update_motor() -> void:
	var motor_enabled := motion_mode != MotionMode.IDLE
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, motor_enabled)
	if not motor_enabled:
		return
	if not latch_released and target_angle <= _min_angle() + 0.001:
		hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		return
	var stiffness: float = settings.controlled_stiffness if motion_mode == MotionMode.CONTROLLED else settings.auto_stiffness
	var error: float = target_angle - current_angle
	if motion_mode == MotionMode.AUTO and absf(error) < 0.01 and absf(angular_velocity) < 0.08:
		motion_mode = MotionMode.IDLE
		target_angle = current_angle
	# Motor сам гасит разницу скоростей; damping задаёт только плавное торможение у цели.
	var brake: float = clampf(absf(error) * settings.damping, 0.18, 1.0)
	var desired_velocity: float = error * stiffness * brake
	desired_velocity = clampf(desired_velocity, -settings.max_angular_speed, settings.max_angular_speed)
	if motion_mode == MotionMode.IDLE and absf(error) < 0.01:
		desired_velocity = 0.0
	hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, desired_velocity)

func _update_debug() -> void:
	var mode_name: String = MotionMode.keys()[motion_mode]
	var control_name: String = HandControlMode.keys()[hand_control_mode]
	var latch_name := "RELEASED" if latch_released else "LATCHED"
	debug_label.text = "%s\nangle %5.1f° → %5.1f°\n%s | %s | %s\nleft hand: %s @ %s" % [name, rad_to_deg(current_angle), rad_to_deg(target_angle), mode_name, control_name, latch_name, debug_left_hand_state, debug_hand_target]

func _min_angle() -> float:
	return deg_to_rad(settings.min_angle_degrees)

func _max_angle() -> float:
	return deg_to_rad(settings.max_angle_degrees)
