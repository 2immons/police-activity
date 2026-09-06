class_name NpcAimController
extends Node

var npc: NPC
var blackboard: Blackboard
var profile: CombatAIProfile
var actual_direction := Vector3.FORWARD
var desired_direction := Vector3.FORWARD
var _tracking_direction := Vector3.FORWARD
var _settle := 0.0
var _time := 0.0
var _recoil := Vector2.ZERO
var _target_was_visible := false

func configure(owner_npc: NPC, state: Blackboard, ai_profile: CombatAIProfile) -> void:
	npc = owner_npc
	blackboard = state
	profile = ai_profile
	actual_direction = -npc.global_basis.z
	_tracking_direction = actual_direction

func advance(delta: float) -> void:
	_time += delta
	var visible: bool = blackboard.get_var(&"can_see_target", false)
	if visible and not _target_was_visible:
		_settle = 0.0
	if visible:
		_settle = move_toward(_settle, 1.0, delta / maxf(profile.aim_settle_time / maxf(profile.aim_skill, 0.15), 0.05))
	elif npc.ai_controller.has_recent_target():
		_settle = move_toward(_settle, 0.25, delta * 0.7)
	else:
		_settle = move_toward(_settle, 0.0, delta * 1.5)
	_target_was_visible = visible

	var aim_point := npc.ai_controller.known_threat_position()
	if aim_point == Vector3.ZERO:
		return
	desired_direction = (aim_point - npc.muzzle.global_position).normalized()
	var tracking_alpha := 1.0 - exp(-profile.tracking_speed * lerpf(0.45, 1.0, profile.aim_skill) * delta)
	var tracking_angle := _tracking_direction.angle_to(desired_direction)
	if tracking_angle > 0.0001:
		tracking_alpha = minf(tracking_alpha, deg_to_rad(profile.maximum_tracking_speed_degrees) * delta / tracking_angle)
	_tracking_direction = _tracking_direction.slerp(desired_direction, tracking_alpha).normalized()
	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-profile.recoil_recovery_speed * delta))

	var movement_factor := clampf(float(blackboard.get_var(&"movement_speed", 0.0)) / maxf(profile.jog_speed, 0.1), 0.0, 1.5)
	var error_degrees := lerpf(profile.initial_aim_error_degrees, profile.settled_aim_error_degrees, smoothstep(0.0, 1.0, _settle))
	error_degrees += movement_factor * profile.movement_error_degrees
	error_degrees += float(blackboard.get_var(&"suppression", 0.0)) * profile.suppression_error_degrees
	error_degrees *= lerpf(1.25, 0.72, profile.aim_skill)
	var noise := Vector2(
		sin(_time * TAU * profile.aim_noise_frequency.x + npc.get_instance_id() * 0.013),
		sin(_time * TAU * profile.aim_noise_frequency.y + 1.7 + npc.get_instance_id() * 0.021)
	)
	var error := noise * deg_to_rad(error_degrees) + _recoil
	var right := _tracking_direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = npc.global_basis.x
	var up := right.cross(_tracking_direction).normalized()
	actual_direction = (_tracking_direction + right * error.x + up * error.y).normalized()
	var aim_error := rad_to_deg(actual_direction.angle_to(desired_direction))
	blackboard.set_var(&"aim_error_degrees", aim_error)
	blackboard.set_var(&"aim_settled", _settle)
	blackboard.set_var(&"aim_quality", clampf(_settle * (1.0 - aim_error / maxf(profile.initial_aim_error_degrees, 0.1)), 0.0, 1.0))
	_update_engagement_phase()

func _update_engagement_phase() -> void:
	if not blackboard.get_var(&"can_see_target", false):
		blackboard.set_var(&"engagement_phase", &"SEARCH" if npc.ai_controller.has_recent_target() else &"UNAWARE")
	elif _settle < 0.15:
		blackboard.set_var(&"engagement_phase", &"NOTICE")
	elif _settle < 0.35:
		blackboard.set_var(&"engagement_phase", &"TRACK")
	elif _settle < 0.55:
		blackboard.set_var(&"engagement_phase", &"PRESENT_WEAPON")
	elif float(blackboard.get_var(&"aim_quality", 0.0)) < profile.minimum_fire_quality:
		blackboard.set_var(&"engagement_phase", &"AIM_SETTLING")
	else:
		blackboard.set_var(&"engagement_phase", &"FIRE_READY")

func register_shot() -> void:
	var side := -1.0 if sin(_time * 17.0 + npc.get_instance_id()) < 0.0 else 1.0
	_recoil += Vector2(deg_to_rad(profile.recoil_degrees.y) * side, deg_to_rad(profile.recoil_degrees.x))
	_settle = maxf(_settle - 0.16, 0.0)

func force_exact_aim(direction: Vector3) -> void:
	desired_direction = direction.normalized()
	_tracking_direction = desired_direction
	actual_direction = desired_direction
	_settle = 1.0
	blackboard.set_var(&"aim_settled", 1.0)
	blackboard.set_var(&"aim_quality", 1.0)
	blackboard.set_var(&"aim_error_degrees", 0.0)
	blackboard.set_var(&"engagement_phase", &"FIRE_READY")
