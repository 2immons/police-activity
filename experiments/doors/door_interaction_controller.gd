class_name DoorInteractionController
extends Node

enum LeftHandState { FREE, WEAPON_SUPPORT, DOOR }
enum DoorControlMode { NONE, HANDLE_CONTROL, PUSH_ONLY }

@export var settings: DoorInteractionSettings = preload("res://experiments/doors/door_interaction_settings.tres")
@onready var interaction_ray: RayCast3D = $InteractionRay

var left_hand_state := LeftHandState.FREE
var door_control_mode := DoorControlMode.NONE
var candidate: Node
var controlled_door: Node
var _pressed_door: Node
var _e_held := false
var _hold_time := 0.0
var _highlighted_door: Node

func _ready() -> void:
	interaction_ray.target_position = Vector3(0, 0, -settings.ray_length)
	interaction_ray.add_exception(get_parent())

func _physics_process(delta: float) -> void:
	_update_candidate()
	_update_hold(delta)
	_update_highlight()
	_update_left_hand_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_F and not event.echo:
		if event.pressed:
			_e_held = true
			_hold_time = 0.0
			_pressed_door = candidate
		else:
			_finish_interaction()
		if is_instance_valid(_pressed_door) or is_instance_valid(controlled_door):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and is_instance_valid(controlled_door):
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction: float = 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			controlled_door.add_control_angle(deg_to_rad(controlled_door.settings.controlled_wheel_step_degrees) * direction)
			get_viewport().set_input_as_handled()

func is_support_hand_busy() -> bool:
	return left_hand_state == LeftHandState.DOOR

func is_interaction_input_reserved() -> bool:
	return _e_held or is_instance_valid(candidate) or is_instance_valid(controlled_door)

func get_hand_target() -> Marker3D:
	return controlled_door.get_hand_target() if is_instance_valid(controlled_door) else null

func _update_candidate() -> void:
	var player = get_parent()
	if not is_instance_valid(player.look_rig):
		candidate = null
		return
	interaction_ray.global_transform = player.look_rig.camera.global_transform
	interaction_ray.force_raycast_update()
	candidate = _find_door(interaction_ray.get_collider()) if interaction_ray.is_colliding() else null
	if is_instance_valid(candidate):
		var distance: float = player.look_rig.camera.global_position.distance_to(candidate.get_hand_target().global_position)
		if distance > candidate.get_interaction_distance() or not candidate.can_interact():
			candidate = null

func _update_highlight() -> void:
	var desired: Node = controlled_door if is_instance_valid(controlled_door) else candidate
	if desired == _highlighted_door:
		return
	if is_instance_valid(_highlighted_door):
		_highlighted_door.set_interaction_highlight(false)
	_highlighted_door = desired
	if is_instance_valid(_highlighted_door):
		_highlighted_door.set_interaction_highlight(true)

func _update_hold(delta: float) -> void:
	if _e_held and is_instance_valid(_pressed_door) and not is_instance_valid(controlled_door):
		_hold_time += delta
		if _hold_time >= settings.hold_delay and _pressed_door.begin_control(get_parent().look_rig.camera.global_position):
			controlled_door = _pressed_door
	if is_instance_valid(controlled_door):
		var player = get_parent()
		var nearest_target: Marker3D = controlled_door.get_nearest_hand_target(player.look_rig.camera.global_position)
		var distance: float = player.look_rig.camera.global_position.distance_to(nearest_target.global_position)
		if distance > controlled_door.get_interaction_distance():
			_release_controlled_door()

func _finish_interaction() -> void:
	_e_held = false
	if is_instance_valid(controlled_door):
		_release_controlled_door()
	elif is_instance_valid(_pressed_door) and _hold_time < settings.hold_delay:
		_pressed_door.request_auto_toggle()
	_pressed_door = null
	_hold_time = 0.0

func _release_controlled_door() -> void:
	controlled_door.end_control()
	controlled_door = null

func _update_left_hand_state() -> void:
	if is_instance_valid(controlled_door):
		left_hand_state = LeftHandState.DOOR
		door_control_mode = controlled_door.hand_control_mode
	else:
		var weapon = get_parent().weapon_controller
		left_hand_state = LeftHandState.WEAPON_SUPPORT if is_instance_valid(weapon) and weapon.equipped else LeftHandState.FREE
		door_control_mode = DoorControlMode.NONE
	for door in get_tree().get_nodes_in_group("interactable_door"):
		door.debug_left_hand_state = LeftHandState.keys()[left_hand_state]

func _find_door(node: Node) -> Node:
	var current := node
	while is_instance_valid(current):
		if current.is_in_group("interactable_door"):
			return current
		current = current.get_parent()
	return null
