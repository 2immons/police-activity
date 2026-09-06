class_name PlayerLookController
extends Node3D

@export var sensitivity := 0.002
@export var max_yaw := deg_to_rad(170.0)
@export var max_pitch := deg_to_rad(80.0)
@export_group("First person self clipping")
## Clips geometry immediately surrounding the eye anchor, including the inside of the head.
@export_range(0.03, 0.25, 0.005) var first_person_near := 0.12
## Prevents armed free-look from rotating the eye ray through the shoulders and raised arms.
@export_range(35.0, 80.0, 1.0) var armed_free_look_down_pitch_degrees := 58.0
@export var eye_center: Marker3D
@export var body_look: SkeletonModifier3D
@export var lean_settings: Resource = preload("res://experiments/player/lean_settings.tres")

@onready var camera: Camera3D = $Camera3D
@onready var camera_motion: PlayerCameraMotion = $CameraMotion

var yaw := 0.0
var pitch := 0.0
var lean_angle := 0.0
var _lean_amount := 0.0

func advance_lean(delta: float, left: bool, right: bool) -> void:
	var target := float(int(left) - int(right))
	if get_parent().is_sprinting():
		target = 0.0
	var duration: float = lean_settings.return_duration
	if target > 0.0: duration = lean_settings.left_duration
	elif target < 0.0: duration = lean_settings.right_duration
	_lean_amount = move_toward(_lean_amount, target, delta / maxf(duration, 0.01))
	var angle: float = lean_settings.left_angle_degrees if _lean_amount >= 0.0 else lean_settings.right_angle_degrees
	lean_angle = signf(_lean_amount) * deg_to_rad(angle) * smoothstep(0.0, 1.0, absf(_lean_amount))

func get_weapon_view_basis() -> Basis:
	return global_basis * Basis(Vector3.BACK, lean_angle)

func set_aim_camera_offset(target: Vector3, delta: float, speed: float) -> void:
	_aim_camera_offset = _aim_camera_offset.lerp(target, 1.0 - exp(-speed * delta))
	if _aim_camera_offset.distance_to(target) < 0.0001:
		_aim_camera_offset = target
	if is_node_ready():
		_update_camera()

func get_recoil_eye_position(fallback_eye: Vector3) -> Vector3:
	return camera.global_position if first_person else fallback_eye + _aim_camera_offset
var first_person := false
var _rest_basis := Basis.IDENTITY
var _third_person_transform := Transform3D.IDENTITY
var _third_person_near := 0.05
var _eye_position := Vector3.ZERO
var _aim_camera_offset := Vector3.ZERO
var free_look_active := false
var free_look_returning := false
var _free_yaw := 0.0
var _free_pitch := 0.0
var _free_weapon_pose := Transform3D.IDENTITY
var _free_player_origin := Vector3.ZERO
var _camera_detached := false
var _head_bone_index := -1

func is_free_looking() -> bool:
	return free_look_active or free_look_returning

func set_free_look(pressed: bool) -> void:
	var player = get_parent()
	var weapon = player.weapon_controller
	if pressed:
		if free_look_active or not is_instance_valid(weapon) or not weapon.equipped or weapon.draw_amount < 0.95:
			return
		if not free_look_returning:
			_free_yaw = yaw
			_free_pitch = pitch
			_free_weapon_pose = weapon.rest_weapon_pose
			_free_player_origin = player.global_position
		free_look_active = true
		free_look_returning = false
	else:
		free_look_returning = is_free_looking()
		free_look_active = false

func get_free_weapon_pose() -> Transform3D:
	var pose := _free_weapon_pose
	pose.origin += get_parent_node_3d().global_position - _free_player_origin
	return pose

func get_movement_basis() -> Basis:
	if is_free_looking():
		return get_parent_node_3d().global_basis * _rest_basis * Basis.from_euler(Vector3(_free_pitch, _free_yaw, 0))
	return global_basis

func compensate_body_turn(turn: float) -> void:
	yaw = wrapf(yaw - turn, -PI, PI)
	if is_free_looking():
		_free_yaw = wrapf(_free_yaw - turn, -PI, PI)
	update_look()

func _process(delta: float) -> void:
	advance_lean(delta, Input.is_physical_key_pressed(KEY_Q), Input.is_physical_key_pressed(KEY_E))
	if not is_free_looking(): return
	var player = get_parent()
	if not is_instance_valid(player.weapon_controller) or not player.weapon_controller.equipped:
		free_look_active = false
		free_look_returning = false
		return
	if free_look_returning:
		var blend := 1.0 - exp(-player.movement_settings.free_look_return_speed * delta)
		yaw = lerp_angle(yaw, _free_yaw, blend)
		pitch = lerpf(pitch, _free_pitch, blend)
		if absf(angle_difference(yaw, _free_yaw)) < 0.001 and absf(pitch - _free_pitch) < 0.001:
			yaw = _free_yaw
			pitch = _free_pitch
			free_look_returning = false
		update_look()

func _ready() -> void:
	_rest_basis = basis
	_third_person_transform = camera.transform
	_third_person_near = camera.near
	if is_instance_valid(body_look):
		body_look.modification_processed.connect(_on_body_look_processed)
	var attachment := eye_center.get_parent() as BoneAttachment3D
	var skeleton := attachment.get_parent() as Skeleton3D
	_head_bone_index = skeleton.find_bone(attachment.bone_name)
	assert(_head_bone_index >= 0, "Eye anchor requires a valid head bone")
	_on_body_look_processed()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		set_free_look(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and (event.physical_keycode == KEY_ALT or event.keycode == KEY_ALT):
		set_free_look(event.pressed)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		set_first_person(not first_person)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		# Releasing Alt starts an automatic return to the held weapon. Any new mouse
		# motion means the player has taken control again, so do not fight that input.
		if free_look_returning:
			free_look_returning = false
		var yaw_delta: float = -event.relative.x * sensitivity
		var weapon = get_parent().weapon_controller
		if is_instance_valid(weapon):
			yaw_delta = weapon.compensate_recoil_yaw(yaw_delta)
		yaw = clampf(yaw + yaw_delta, -max_yaw, max_yaw)
		var pitch_delta: float = -event.relative.y * sensitivity
		if is_instance_valid(weapon):
			pitch_delta = weapon.compensate_recoil_pitch(pitch_delta)
		var minimum_pitch := -max_pitch
		if free_look_active and is_instance_valid(weapon) and weapon.equipped:
			minimum_pitch = -deg_to_rad(armed_free_look_down_pitch_degrees)
		pitch = clampf(pitch + pitch_delta, minimum_pitch, max_pitch)
		update_look()

func update_look() -> void:
	basis = _rest_basis * Basis.from_euler(Vector3(pitch, yaw, 0.0))
	_update_camera()

func set_first_person(enabled: bool) -> void:
	first_person = enabled
	camera.near = first_person_near if first_person else _third_person_near
	_update_camera()

func _update_camera() -> void:
	if _camera_detached:
		return
	if not first_person:
		camera.transform = Transform3D(Basis(Vector3.BACK, lean_angle * lean_settings.camera_roll_fraction), Vector3.ZERO) * _third_person_transform * camera_motion.offset
		return
	if not is_instance_valid(eye_center):
		return
	camera.global_transform = Transform3D(global_basis * Basis(Vector3.BACK, lean_angle * lean_settings.camera_roll_fraction), _eye_position + _aim_camera_offset) * camera_motion.offset

func refresh_camera_transform() -> void:
	_update_camera()

func _on_body_look_processed() -> void:
	if _camera_detached:
		return
	if not is_instance_valid(eye_center):
		return
	# Cache the animated eye anchor before Skeleton3D restores the unmodified pose.
	var attachment := eye_center.get_parent() as BoneAttachment3D
	var skeleton := attachment.get_parent() as Skeleton3D
	var head_pose := skeleton.get_bone_global_pose(_head_bone_index)
	_eye_position = skeleton.global_transform * head_pose * eye_center.position
	_update_camera()

func detach_camera_for_death(new_parent: Node3D) -> void:
	if _camera_detached or not is_instance_valid(new_parent):
		return
	_update_camera()
	_camera_detached = true
	if is_instance_valid(body_look):
		body_look.active = false
	camera.reparent(new_parent, true)

# Express the input rotation in world axes, including the authored forward direction.
func get_world_look_offset(yaw_weight: float, pitch_weight: float, yaw_deadzone: float = 0.0, pitch_deadzone: float = 0.0) -> Basis:
	return _world_offset(yaw, pitch, yaw_weight, pitch_weight, yaw_deadzone, pitch_deadzone)

func get_body_yaw() -> float:
	return _free_yaw if is_free_looking() else yaw

func get_torso_look_offset(yaw_weight: float, pitch_weight: float, yaw_deadzone: float, pitch_deadzone: float) -> Basis:
	return _world_offset(get_body_yaw(), _free_pitch if is_free_looking() else pitch, yaw_weight, pitch_weight, yaw_deadzone, pitch_deadzone)

func _world_offset(input_yaw: float, input_pitch: float, yaw_weight: float, pitch_weight: float, yaw_deadzone: float, pitch_deadzone: float) -> Basis:
	var reference := (get_parent_node_3d().global_basis * _rest_basis).orthonormalized()
	# Only the excess beyond the eye-look range reaches the skeleton.
	var body_yaw := signf(input_yaw) * maxf(absf(input_yaw) - yaw_deadzone, 0.0)
	var body_pitch := signf(input_pitch) * maxf(absf(input_pitch) - pitch_deadzone, 0.0)
	return reference * Basis.from_euler(Vector3(body_pitch * pitch_weight, body_yaw * yaw_weight, 0.0)) * reference.inverse()
