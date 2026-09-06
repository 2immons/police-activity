class_name NpcAIController
extends Node

@export var profile: CombatAIProfile = preload("res://npc/ai/combat_ai_profile.tres")
@export var perception: NpcPerceptionController
@export var movement: NpcTacticalMovementController
@export var aim: NpcAimController
@export var weapon: NpcWeaponController
@export var knowledge: Node
@export var tactical_query: Node
@export var animation: Node
@export var debug_label: Label3D
@export var debug_enabled := true

var npc: NPC
var blackboard: Blackboard

func configure(owner_npc: NPC, limbo_blackboard: Blackboard) -> void:
	npc = owner_npc
	blackboard = limbo_blackboard
	perception.configure(npc, blackboard, profile)
	aim.configure(npc, blackboard, profile)
	movement.configure(npc, blackboard, profile)
	weapon.configure(npc, blackboard, profile, aim)
	tactical_query.configure(npc, blackboard, knowledge)
	animation.configure(npc, blackboard, profile, aim)
	if is_instance_valid(debug_label):
		debug_label.visible = debug_enabled

func set_target(target: CharacterBody3D) -> void:
	blackboard.set_var(&"target", target)

func register_incoming_fire(origin: Vector3, closest_point: Vector3, amount: float) -> void:
	blackboard.set_var(&"recent_incoming_fire", profile.incoming_fire_memory)
	blackboard.set_var(&"last_heard_position", origin)
	blackboard.set_var(&"incoming_fire_direction", (closest_point - origin).normalized())
	var impacts: Array = blackboard.get_var(&"recent_impact_positions", [])
	impacts.append(closest_point)
	blackboard.set_var(&"recent_impact_positions", impacts)
	var suppression: float = blackboard.get_var(&"suppression", 0.0)
	blackboard.set_var(&"suppression", clampf(suppression + amount * profile.suppression_sensitivity, 0.0, 1.0))

func register_heard_stimulus(position: Vector3, confidence: float = 1.0) -> void:
	blackboard.set_var(&"last_heard_position", position)
	if is_inf(float(blackboard.get_var(&"time_since_target_seen", INF))):
		blackboard.set_var(&"time_since_target_seen", 0.0)
	var suppression: float = blackboard.get_var(&"suppression", 0.0)
	blackboard.set_var(&"suppression", clampf(suppression + confidence * 0.08, 0.0, 1.0))

func advance_memory(delta: float) -> void:
	blackboard.set_var(&"time_since_target_seen", float(blackboard.get_var(&"time_since_target_seen", INF)) + delta)
	blackboard.set_var(&"recent_incoming_fire", maxf(float(blackboard.get_var(&"recent_incoming_fire", 0.0)) - delta, 0.0))
	blackboard.set_var(&"suppression", move_toward(float(blackboard.get_var(&"suppression", 0.0)), 0.0, profile.suppression_decay * delta))
	var impacts: Array = blackboard.get_var(&"recent_impact_positions", [])
	if impacts.size() > 6:
		impacts.pop_front()

func known_threat_position() -> Vector3:
	if blackboard.get_var(&"can_see_target", false):
		return blackboard.get_var(&"current_target_position", Vector3.ZERO)
	if float(blackboard.get_var(&"time_since_target_seen", INF)) < INF:
		return blackboard.get_var(&"last_seen_position", Vector3.ZERO)
	return blackboard.get_var(&"last_heard_position", Vector3.ZERO)

func has_recent_target() -> bool:
	return blackboard.get_var(&"can_see_target", false) or float(blackboard.get_var(&"time_since_target_seen", INF)) <= profile.memory_duration

func shutdown() -> void:
	movement.stop(&"DEAD")
	if is_instance_valid(debug_label):
		debug_label.visible = false

func force_exact_aim_at(point: Vector3) -> void:
	blackboard.set_var(&"can_see_target", true)
	blackboard.set_var(&"current_target_position", point)
	blackboard.set_var(&"last_seen_position", point)
	blackboard.set_var(&"time_since_target_seen", 0.0)
	for iteration in range(3):
		aim.force_exact_aim((point - npc.muzzle.global_position).normalized())
		animation.refresh_weapon_pose()

func face_tactical_direction(delta: float) -> void:
	if has_recent_target():
		movement.face_direction(known_threat_position() - npc.global_position, delta)
	elif movement.active:
		movement.face_direction(movement.destination - npc.global_position, delta)
