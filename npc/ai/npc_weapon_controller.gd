class_name NpcWeaponController
extends Node

const BulletSolver = preload("res://experiments/weapon_system/ballistics/bullet_penetration_solver.gd")
const IMPACT_SCENE: PackedScene = preload("res://experiments/weapon_system/bullet_impact.tscn")
const BALLISTIC_SETTINGS: PlayerWeaponSettings = preload("res://experiments/weapon_system/weapon_settings.tres")

var npc: NPC
var blackboard: Blackboard
var profile: CombatAIProfile
var aim: NpcAimController
var cooldown := 0.0
var burst_pause := 0.0
var reload_left := 0.0
var rounds := 17
var shots_in_sequence := 0
var _impacts: Array[Node3D] = []

func configure(owner_npc: NPC, state: Blackboard, ai_profile: CombatAIProfile, aim_controller: NpcAimController) -> void:
	npc = owner_npc
	blackboard = state
	profile = ai_profile
	aim = aim_controller
	rounds = profile.magazine_capacity

func advance(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	burst_pause = maxf(burst_pause - delta, 0.0)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			rounds = profile.magazine_capacity
	blackboard.set_var(&"magazine_ammo", rounds)
	blackboard.set_var(&"is_reloading", reload_left > 0.0)
	blackboard.set_var(&"weapon_ready", cooldown <= 0.0 and burst_pause <= 0.0 and reload_left <= 0.0 and rounds > 0)

func start_reload() -> void:
	if reload_left <= 0.0 and rounds < profile.magazine_capacity:
		reload_left = profile.reload_duration
		shots_in_sequence = 0

func try_fire() -> bool:
	if not blackboard.get_var(&"weapon_ready", false) or not blackboard.get_var(&"can_see_target", false) or float(blackboard.get_var(&"aim_quality", 0.0)) < profile.minimum_fire_quality:
		return false
	var origin := npc.muzzle.global_position
	var direction := -npc.muzzle.global_basis.z.normalized()
	var trace: Dictionary = BulletSolver.trace(
		npc.get_world_3d().direct_space_state, origin, direction, profile.shot_range,
		BALLISTIC_SETTINGS.shot_mask, npc.get_damage_collision_rids(),
		BALLISTIC_SETTINGS.caliber, BALLISTIC_SETTINGS.weapon_id,
		BALLISTIC_SETTINGS.penetration_energy, BALLISTIC_SETTINGS.maximum_penetrations
	)
	var hit: Dictionary = trace.hit
	for traced_hit: Dictionary in trace.hits:
		_spawn_impact(traced_hit)
		if traced_hit.collider.has_method("receive_bullet_hit"):
			traced_hit.collider.receive_bullet_hit(profile.shot_damage, traced_hit.position, direction)
	_notify_player_suppression(origin, direction, hit)
	npc.shot_audio.play()
	npc.set_muzzle_flash_time(0.035)
	npc.muzzle_flash.visible = true
	rounds -= 1
	shots_in_sequence += 1
	cooldown = profile.shot_interval * lerpf(1.18, 0.88, profile.aggression)
	if shots_in_sequence >= 2 or float(blackboard.get_var(&"aim_quality", 0.0)) < profile.minimum_fire_quality + 0.12:
		burst_pause = profile.burst_pause * lerpf(1.2, 0.75, profile.aggression)
		shots_in_sequence = 0
	aim.register_shot()
	return true

func _spawn_impact(hit: Dictionary) -> void:
	# Array.filter() теряет typed-array metadata в Godot; чистим массив на месте.
	for index in range(_impacts.size() - 1, -1, -1):
		if not is_instance_valid(_impacts[index]):
			_impacts.remove_at(index)
	if _impacts.size() >= 48:
		_impacts.pop_front().queue_free()
	var impact := IMPACT_SCENE.instantiate() as Node3D
	var impact_parent: Node = hit.collider if hit.collider is Node3D else get_tree().current_scene
	if impact_parent == null:
		impact_parent = get_tree().root
	impact_parent.add_child(impact)
	var normal: Vector3 = hit.normal
	if normal.length_squared() < 0.01:
		normal = Vector3.UP
	impact.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal.normalized())), hit.position + normal * 0.003)
	_impacts.append(impact)

func _notify_player_suppression(origin: Vector3, direction: Vector3, hit: Dictionary) -> void:
	var target := blackboard.get_var(&"target") as CharacterBody3D
	if not is_instance_valid(target) or not target.has_method("receive_suppression"):
		return
	var segment_length: float = origin.distance_to(hit.position) if not hit.is_empty() else profile.shot_range
	var segment := direction * segment_length
	var target_point: Vector3 = target.get_chest_target_position() if target.has_method("get_chest_target_position") else target.global_position + Vector3.UP * 1.3
	var along := clampf((target_point - origin).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	var closest := origin + segment * along
	var miss_distance := target_point.distance_to(closest)
	if miss_distance > profile.player_suppression_radius:
		return
	var amount := (1.0 - miss_distance / profile.player_suppression_radius) * profile.player_suppression_strength
	target.receive_suppression(origin, closest, amount)
