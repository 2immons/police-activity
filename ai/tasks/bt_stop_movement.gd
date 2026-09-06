@tool
extends BTAction

@export var reason: StringName = &"TACTICAL_HOLD"

func _generate_name() -> String:
	return "Stop movement [%s]" % reason

func _tick(_delta: float) -> Status:
	var npc := agent as NPC
	if npc == null:
		return FAILURE
	npc.ai_controller.movement.stop(reason)
	return SUCCESS

