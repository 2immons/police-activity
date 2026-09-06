class_name PlayerWeaponRecoilController
extends Node

@export var settings: PlayerWeaponSettings = preload("res://experiments/weapon_system/weapon_settings.tres")

var angles := Vector3.ZERO
var retained_pitch: float = 0.0
var retained_yaw: float = 0.0
var backward_offset: float = 0.0

func advance(delta: float) -> void:
	angles.x = lerpf(retained_pitch, angles.x, exp(-settings.recoil_pitch_return_speed * delta))
	angles.y = lerpf(retained_yaw, angles.y, exp(-settings.recoil_yaw_return_speed * delta))
	backward_offset *= exp(-settings.recoil_return_speed * delta)

func apply_shot_impulse() -> void:
	var strength := randf_range(1.0 - settings.recoil_strength_variation, 1.0 + settings.recoil_strength_variation)
	var previous_pitch := angles.x
	angles.x = minf(previous_pitch + deg_to_rad(settings.recoil_pitch_degrees) * strength, deg_to_rad(settings.max_recoil_degrees))
	retained_pitch += (angles.x - previous_pitch) * (1.0 - settings.recoil_pitch_recovery)

	var yaw_impulse := deg_to_rad(settings.recoil_yaw_degrees) * randf_range(settings.recoil_yaw_minimum_factor, 1.0) * strength
	if randf() < 0.5:
		yaw_impulse = -yaw_impulse
	var max_yaw := deg_to_rad(settings.max_recoil_yaw_degrees)
	var previous_yaw := angles.y
	angles.y = clampf(previous_yaw + yaw_impulse, -max_yaw, max_yaw)
	retained_yaw = clampf(retained_yaw + (angles.y - previous_yaw) * (1.0 - settings.recoil_yaw_recovery), -max_yaw, max_yaw)
	backward_offset = minf(backward_offset + settings.recoil_back_distance * strength, settings.recoil_back_distance * 2.0)

func apply_to_pose(base_pose: Transform3D, eye: Vector3) -> Transform3D:
	var retained_basis := Basis.from_euler(Vector3(retained_pitch, retained_yaw, 0.0))
	var eye_local: Vector3 = base_pose.affine_inverse() * eye
	var settled := base_pose * Transform3D(retained_basis, eye_local - retained_basis * eye_local)
	var transient_basis := Basis.from_euler(angles - Vector3(retained_pitch, retained_yaw, 0.0))
	var pivot := Vector3(0.0, 0.0, settings.recoil_pivot_distance)
	return settled * Transform3D(transient_basis, pivot - transient_basis * pivot + Vector3(0.0, 0.0, backward_offset))

func compensate_pitch(input_delta: float, enabled: bool) -> float:
	if not enabled or input_delta >= 0.0:
		return input_delta
	var compensation := minf(angles.x, -input_delta)
	angles.x -= compensation
	retained_pitch = maxf(0.0, retained_pitch - compensation)
	return input_delta + compensation

func compensate_yaw(input_delta: float, enabled: bool) -> float:
	if not enabled or is_zero_approx(input_delta) or is_zero_approx(angles.y) or signf(input_delta) == signf(angles.y):
		return input_delta
	var recoil_sign := signf(angles.y)
	var compensation := minf(absf(angles.y), absf(input_delta))
	angles.y -= recoil_sign * compensation
	if signf(retained_yaw) == recoil_sign:
		retained_yaw -= recoil_sign * minf(absf(retained_yaw), compensation)
	return input_delta + recoil_sign * compensation
