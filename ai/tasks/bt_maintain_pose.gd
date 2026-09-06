@tool
extends BTAction

@export var pose: StringName = &"Idle"

func _generate_name() -> String:
	return "Maintain pose [%s]" % pose

func _tick(_delta: float) -> Status:
	var npc := agent as NPC
	if npc == null:
		return FAILURE
	npc.play_locomotion(pose)
	return RUNNING

