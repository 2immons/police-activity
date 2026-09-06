class_name SuspectAnimation
extends Node

var npc: NPC
var blackboard: Blackboard
var profile: CombatAIProfile
var aim: NpcAimController

func configure(owner: NPC, state: Blackboard, ai_profile: CombatAIProfile, aim_controller: NpcAimController) -> void:
	npc = owner
	blackboard = state
	profile = ai_profile
	aim = aim_controller

func advance() -> void:
	refresh_weapon_pose()
	_update_locomotion()

func refresh_weapon_pose() -> void:
	var direction := aim.actual_direction
	if direction.length_squared() < 0.5:
		direction = -npc.global_basis.z
	var origin := npc.global_position + Vector3.UP * (1.08 if blackboard.get_var(&"posture", &"STANDING") == &"CROUCHED" else 1.36) + direction * 0.42
	# Компенсирует несовпадение muzzle axis импортированного Glock с его root axis.
	var local_muzzle_direction := -npc.muzzle.basis.z.normalized()
	var weapon_basis := Basis.looking_at(direction, Vector3.UP) * Basis.looking_at(local_muzzle_direction, Vector3.UP).inverse()
	npc.weapon.global_transform = Transform3D(weapon_basis, origin)

func _update_locomotion() -> void:
	var movement_speed: float = blackboard.get_var(&"movement_speed", 0.0)
	if blackboard.get_var(&"is_reloading", false):
		npc.play_locomotion("Pistol_Reload")
	elif blackboard.get_var(&"posture", &"STANDING") == &"CROUCHED":
		npc.play_locomotion("Crouch_Fwd" if movement_speed > 0.12 else "Crouch_Idle")
	elif movement_speed > profile.walk_speed * 1.1:
		npc.play_locomotion("Jog_Fwd")
	elif movement_speed > 0.12:
		npc.play_locomotion("Walk")
	else:
		npc.play_locomotion("Pistol_Idle" if npc.ai_controller.has_recent_target() else "Idle")
