class_name PlayerCameraMotion
extends Node

@onready var rig: PlayerLookController = get_parent()
@onready var player: CharacterBody3D = rig.get_parent()
@export var settings: Resource = preload("res://experiments/player_camera/camera_motion_settings.tres")
@export var stress_controller: PlayerStressController

var offset := Transform3D.IDENTITY
var intensity := 0.0
var _previous_view := Basis.IDENTITY
var _time := 0.0
var _step_phase := 0.0
var _move_amount := 0.0
var _run_amount := 0.0
var _turn_amount := 0.0
var _hit_position := Vector3.ZERO
var _hit_position_velocity := Vector3.ZERO
var _hit_rotation := Vector3.ZERO
var _hit_rotation_velocity := Vector3.ZERO

func _ready() -> void:
	_previous_view = rig.global_basis.orthonormalized()

func get_step_phase() -> float:
	return _step_phase

func add_hit_impulse(world_direction: Vector3, world_hit_position: Vector3, zone: String) -> void:
	var local_direction := rig.global_basis.inverse() * world_direction.normalized()
	var local_hit := rig.to_local(world_hit_position)
	var side := signf(local_hit.x)
	if is_zero_approx(side):
		side = signf(local_direction.x)
	var multiplier: float = settings.chest_hit_multiplier
	if zone == "HEAD":
		multiplier = settings.head_hit_multiplier
	elif zone != "CHEST":
		multiplier = settings.limb_hit_multiplier

	# Короткий толчок приходит со стороны попадания, после чего spring возвращает камеру.
	_hit_position_velocity += Vector3(
		local_direction.x * settings.hit_position_impulse.x,
		local_direction.y * settings.hit_position_impulse.y,
		local_direction.z * settings.hit_position_impulse.z
	) * settings.hit_spring * multiplier
	var rotation_impulse: Vector3 = settings.hit_rotation_impulse_degrees * (PI / 180.0)
	_hit_rotation_velocity += Vector3(
		-local_direction.y * rotation_impulse.x + (0.35 if zone == "HEAD" else 0.0) * rotation_impulse.x,
		-local_direction.x * rotation_impulse.y,
		-side * rotation_impulse.z
	) * settings.hit_spring * multiplier

func _process(delta: float) -> void:
	var view := rig.global_basis.orthonormalized()
	var turn_rate := _previous_view.get_rotation_quaternion().angle_to(view.get_rotation_quaternion()) / maxf(delta, 0.0001)
	_previous_view = view
	var actual := player.get_real_velocity()
	advance_motion(delta, Vector2(actual.x, actual.z).length(), turn_rate, player.is_on_floor())
	rig.refresh_camera_transform()

func advance_motion(delta: float, speed: float, turn_rate: float, grounded: bool) -> void:
	_advance_hit_spring(delta)
	var response := 1.0 - exp(-maxf(settings.smoothing_speed, 0.01) * delta)
	var walk_speed: float = maxf(player.movement_settings.walk_speed, 0.01)
	var sprint_speed: float = maxf(player.movement_settings.sprint_speed, walk_speed + 0.01)
	var moving := clampf(speed / walk_speed, 0.0, 1.0) if grounded else 0.0
	var running := clampf((speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0)
	var turning := clampf(turn_rate / deg_to_rad(maxf(settings.full_turn_speed_degrees, 1.0)), 0.0, 1.0)
	_move_amount = lerpf(_move_amount, moving, response)
	_run_amount = lerpf(_run_amount, running, response)
	_turn_amount = lerpf(_turn_amount, turning, response)
	_time += delta
	if grounded:
		var step_length: float = lerpf(settings.walk_step_length, settings.sprint_step_length, running)
		_step_phase = fmod(_step_phase + speed * delta / maxf(step_length, 0.1) * TAU, TAU * 2.0)
	var movement_strength: float = _move_amount * lerpf(settings.walk_strength, settings.sprint_strength, _run_amount)
	var turn_strength: float = _turn_amount * (settings.turn_strength + _move_amount * settings.moving_turn_bonus)
	var breath: float = _time * settings.idle_frequency * TAU
	var turn_wave: float = _time * settings.turn_frequency * TAU
	var idle_wave := Vector3(sin(breath * 0.73), sin(breath), sin(breath * 1.13))
	var movement_wave := Vector3(sin(_step_phase * 0.5), sin(_step_phase), cos(_step_phase * 0.5))
	var turning_wave := Vector3(sin(turn_wave), sin(turn_wave * 1.17), sin(turn_wave * 0.83))
	var stress_amount: float = stress_controller.get_amount() if is_instance_valid(stress_controller) else 0.0
	var stress_wave: Vector3 = Vector3(sin(_time * 7.1), sin(_time * 8.3), cos(_time * 6.7)) * settings.stress_camera_strength * stress_amount * stress_amount
	var wave: Vector3 = idle_wave * settings.idle_strength + movement_wave * movement_strength + turning_wave * turn_strength + stress_wave
	var gain: float = settings.master_strength * (1.0 if rig.first_person else settings.third_person_multiplier)
	intensity = (settings.idle_strength + movement_strength + turn_strength) * gain
	if not settings.enabled:
		gain = 0.0
		intensity = 0.0
	var angles: Vector3 = wave * settings.rotation_amplitude_degrees * (PI / 180.0) * gain + _hit_rotation * gain
	offset = Transform3D(Basis.from_euler(angles), wave * settings.position_amplitude * gain + _hit_position * gain)

func _advance_hit_spring(delta: float) -> void:
	var damping := exp(-settings.hit_damping * delta)
	_hit_position_velocity = (_hit_position_velocity - _hit_position * settings.hit_spring * delta) * damping
	_hit_rotation_velocity = (_hit_rotation_velocity - _hit_rotation * settings.hit_spring * delta) * damping
	_hit_position += _hit_position_velocity * delta
	_hit_rotation += _hit_rotation_velocity * delta
	if _hit_position.length_squared() < 0.00000001 and _hit_position_velocity.length_squared() < 0.00000001:
		_hit_position = Vector3.ZERO
		_hit_position_velocity = Vector3.ZERO
	if _hit_rotation.length_squared() < 0.00000001 and _hit_rotation_velocity.length_squared() < 0.00000001:
		_hit_rotation = Vector3.ZERO
		_hit_rotation_velocity = Vector3.ZERO
