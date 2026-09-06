@tool
extends BTAction

@export var position_var: StringName = &"movement_destination"
@export var movement_reason: StringName = &"MOVE"
@export_enum("WALK", "TACTICAL_WALK", "JOG", "RUN") var speed_mode: StringName = &"WALK"
@export var finish_when_los_lost := false

func _generate_name() -> String:
	return "Move to %s [%s]" % [LimboUtility.decorate_var(position_var), speed_mode]

func _tick(delta: float) -> Status:
	var npc := agent as NPC
	var destination_value: Variant = blackboard.get_var(position_var)
	if npc == null:
		return FAILURE
	var destination := Vector3.ZERO
	if destination_value is Vector3:
		destination = destination_value
	elif destination_value is Node3D and is_instance_valid(destination_value):
		destination = destination_value.global_position
	else:
		return FAILURE
	npc.ai_controller.movement.move_to(destination, movement_reason, speed_mode)
	npc.ai_controller.movement.face_direction(destination - npc.global_position, delta)
	if finish_when_los_lost and not blackboard.get_var(&"can_see_target", false):
		return SUCCESS
	return SUCCESS if npc.ai_controller.movement.has_reached(destination) else RUNNING
