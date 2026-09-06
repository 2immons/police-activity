@tool
extends BTAction

func _generate_name() -> String:
	return "Fire when visible and settled"

func _tick(_delta: float) -> Status:
	var npc := agent as NPC
	if npc == null:
		return FAILURE
	if blackboard.get_var(&"can_see_target", false) 			and float(blackboard.get_var(&"aim_quality", 0.0)) >= npc.ai_controller.profile.minimum_fire_quality:
		npc.ai_controller.weapon.try_fire()
	return RUNNING

