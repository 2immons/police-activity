extends MeshInstance3D

@export var controller: NpcAIController

func _process(_delta: float) -> void:
	if not is_instance_valid(controller) or not controller.debug_enabled or not is_instance_valid(controller.npc) or controller.npc.dead:
		visible = false
		return
	visible = true
	var immediate := mesh as ImmediateMesh
	immediate.clear_surfaces()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	var npc := controller.npc
	var board := controller.blackboard
	var remembered_target: Vector3 = controller.known_threat_position()
	var desired_direction := controller.aim.desired_direction
	if remembered_target != Vector3.ZERO:
		desired_direction = (remembered_target - npc.muzzle.global_position).normalized()
	_add_line(immediate, npc.muzzle.global_position, npc.muzzle.global_position + desired_direction * 6.0, Color(0.2, 0.8, 1.0))
	_add_line(immediate, npc.muzzle.global_position, npc.muzzle.global_position - npc.muzzle.global_basis.z * 6.0, Color(1.0, 0.25, 0.15))
	if float(board.get_var(&"time_since_target_seen", INF)) < INF:
		_add_line(immediate, controller.perception.eye_origin.global_position, board.get_var(&"last_seen_position", Vector3.ZERO), Color(1.0, 0.85, 0.15))
	if controller.movement.active:
		_add_line(immediate, npc.global_position + Vector3.UP * 0.3, controller.movement.destination + Vector3.UP * 0.3, Color(0.8, 0.3, 1.0))
	if board.get_var(&"has_escape_destination", false):
		var color := Color(1.0, 0.2, 0.15) if board.get_var(&"escape_route_threatened", false) else Color(0.15, 1.0, 0.35)
		_add_line(immediate, npc.global_position + Vector3.UP * 0.45, board.get_var(&"escape_destination", Vector3.ZERO) + Vector3.UP * 0.45, color)
	immediate.surface_end()

func _add_line(immediate: ImmediateMesh, from: Vector3, to: Vector3, color: Color) -> void:
	immediate.surface_set_color(color)
	immediate.surface_add_vertex(from)
	immediate.surface_set_color(color)
	immediate.surface_add_vertex(to)
