class_name PlayerStressController
extends Node

signal stress_changed(amount: float)

@export var settings: PlayerStressSettings = preload("res://experiments/player/stress/player_stress_settings.tres")

var stress: float = 0.0
var visual_amount: float = 0.0
var last_threat_origin := Vector3.ZERO
var last_closest_point := Vector3.ZERO

var _decay_delay_left: float = 0.0
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	_decay_delay_left = maxf(_decay_delay_left - delta, 0.0)
	if _decay_delay_left <= 0.0:
		stress = move_toward(stress, 0.0, settings.decay_rate * delta)
	var response := settings.attack_speed if stress > visual_amount else settings.release_speed
	var previous := visual_amount
	visual_amount = lerpf(visual_amount, stress, 1.0 - exp(-response * delta))
	if absf(visual_amount - stress) < 0.0001:
		visual_amount = stress
	if not is_equal_approx(previous, visual_amount):
		stress_changed.emit(visual_amount)

func apply_suppression(origin: Vector3, closest_point: Vector3, amount: float, direct_hit: bool = false) -> void:
	last_threat_origin = origin
	last_closest_point = closest_point
	var gain := clampf(amount, 0.0, 1.0) * settings.suppression_gain
	if direct_hit:
		gain += settings.hit_gain
	stress = clampf(stress + gain, 0.0, 1.0)
	_decay_delay_left = settings.decay_delay

func get_amount() -> float:
	return visual_amount

func get_weapon_sway(step_phase: float) -> Transform3D:
	if visual_amount <= 0.0001:
		return Transform3D.IDENTITY
	var breath_phase := _time * settings.weapon_sway_frequency * TAU
	var step_wave := Vector3(sin(step_phase * 0.5), -absf(sin(step_phase)), cos(step_phase * 0.5))
	var stress_wave := Vector3(sin(breath_phase * 0.83), sin(breath_phase), cos(breath_phase * 1.17))
	var wave := stress_wave.lerp(step_wave, settings.step_coupling)
	var weight := visual_amount * visual_amount
	var position := wave * settings.weapon_position_amplitude * weight
	var rotation := Vector3(wave.y, wave.x, wave.z) * settings.weapon_rotation_amplitude_degrees * (PI / 180.0) * weight
	return Transform3D(Basis.from_euler(rotation), position)

func reset() -> void:
	stress = 0.0
	visual_amount = 0.0
	_decay_delay_left = 0.0
	stress_changed.emit(0.0)
