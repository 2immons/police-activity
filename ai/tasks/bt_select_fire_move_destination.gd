@tool
extends BTAction

@export var output_var: StringName = &"fire_move_destination"

func _generate_name() -> String:
	return "Select tactical pressure position -> %s" % LimboUtility.decorate_var(output_var)

func _tick(_delta: float) -> Status:
	var npc := agent as NPC
	if npc == null:
		return FAILURE
	var destination := npc.ai_controller.tactical_query.select_fire_move_destination()
	if destination == Vector3.ZERO:
		return FAILURE
	blackboard.set_var(output_var, destination)
	return SUCCESS

