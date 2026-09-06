@tool
extends BTAction

func _generate_name() -> String:
	return "Reevaluate suspect intent"

func _tick(_delta: float) -> Status:
	var npc := agent as NPC
	if npc == null:
		return FAILURE
	npc.suspect_mind.force_reevaluate(npc)
	npc.publish_mind_to_blackboard()
	return SUCCESS

