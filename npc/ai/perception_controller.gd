class_name NpcPerceptionController
extends Node

@export var eye_origin: Marker3D
var npc: NPC
var blackboard: Blackboard
var profile: CombatAIProfile
var _timer := 0.0
var _detection := 0.0
var _previous_visible_position := Vector3.ZERO

func configure(owner_npc: NPC, state: Blackboard, ai_profile: CombatAIProfile) -> void:
	npc = owner_npc
	blackboard = state
	profile = ai_profile

func advance(delta: float) -> void:
	if not is_instance_valid(blackboard.get_var(&"target")):
		_clear_visibility(delta)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = profile.perception_interval
	_sample_target(profile.perception_interval)

func sample_now(sample_delta: float = 0.0) -> void:
	_sample_target(sample_delta)

func _sample_target(sample_delta: float) -> void:
	var target := blackboard.get_var(&"target") as CharacterBody3D
	var chest := _target_chest_position(target)
	var to_target := chest - eye_origin.global_position
	blackboard.set_var(&"target_distance", to_target.length())
	blackboard.set_var(&"target_direction", to_target.normalized())
	var facing := -npc.global_basis.z
	var inside_fov := to_target.length() <= profile.vision_range and facing.dot(to_target.normalized()) >= cos(deg_to_rad(profile.vision_fov_degrees * 0.5))
	var visible_samples := 0
	if inside_fov:
		for point in [chest, target.global_position + Vector3.UP * 1.62, target.global_position + Vector3.UP * 0.82]:
			visible_samples += int(has_line_of_sight(point))
	var visible_fraction := float(visible_samples) / 3.0
	blackboard.set_var(&"target_visible_fraction", visible_fraction)
	var detect_target := visible_fraction
	_detection = move_toward(_detection, detect_target, sample_delta / maxf(profile.detection_time, 0.01))
	var visible_now := visible_fraction >= 0.34 and _detection >= 0.55
	if visible_now:
		blackboard.set_var(&"can_see_target", true)
		blackboard.set_var(&"current_target_position", chest)
		blackboard.set_var(&"last_seen_position", chest)
		blackboard.set_var(&"target_velocity_estimate", (chest - _previous_visible_position) / maxf(sample_delta, 0.01) if _previous_visible_position != Vector3.ZERO else target.velocity)
		_previous_visible_position = chest
		blackboard.set_var(&"time_since_target_seen", 0.0)
	else:
		blackboard.set_var(&"can_see_target", false)
	blackboard.set_var(&"target_is_aiming_at_me", _target_aims_at_npc(target) if visible_now else false)

func _clear_visibility(delta: float) -> void:
	blackboard.set_var(&"can_see_target", false)
	blackboard.set_var(&"target_visible_fraction", 0.0)
	_detection = move_toward(_detection, 0.0, delta / maxf(profile.detection_time, 0.01))

func has_line_of_sight(point: Vector3) -> bool:
	var target := blackboard.get_var(&"target") as CharacterBody3D
	if not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye_origin.global_position, point, 0xffffffff, npc.get_damage_collision_rids())
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.collider == target or target.is_ancestor_of(hit.collider))

func _target_chest_position(target: CharacterBody3D) -> Vector3:
	if target.has_method("get_chest_target_position"):
		return target.get_chest_target_position()
	return target.global_position + Vector3.UP * 1.3

func _target_aims_at_npc(target: CharacterBody3D) -> bool:
	var look := target.get("look_rig") as Node3D
	if look == null:
		return false
	var toward_npc := (npc.global_position + Vector3.UP * 1.2 - look.global_position).normalized()
	return (-look.global_basis.z).dot(toward_npc) > 0.93
