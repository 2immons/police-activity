@tool
extends BTAction

func _generate_name() -> String:
	return "Maintain threat facing"

func _tick(delta: float) -> Status:
	var npc := agent as NPC
	if npc == null or not npc.ai_controller.has_recent_target():
		return FAILURE
	npc.ai_controller.face_tactical_direction(delta)
	return RUNNING

