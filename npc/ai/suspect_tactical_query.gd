class_name SuspectTacticalQuery
extends Node

@export var escape_point: Marker3D
@export_range(0.1, 1.0, 0.01) var viability_when_fully_blocked := 0.08
@export_range(0.0, 3.0, 0.05) var route_safety_margin := 0.65

var npc: NPC
var blackboard: Blackboard
var knowledge: Node

func configure(owner: NPC, state: Blackboard, suspect_knowledge: Node) -> void:
	npc = owner
	blackboard = state
	knowledge = suspect_knowledge
	if is_instance_valid(escape_point):
		knowledge.remember_escape_point(escape_point)

func advance() -> void:
	var target := blackboard.get_var(&"target") as CharacterBody3D
	if not is_instance_valid(escape_point) or not is_instance_valid(target):
		blackboard.set_var(&"has_escape_destination", false)
		blackboard.set_var(&"escape_route_threatened", false)
		blackboard.set_var(&"escape_route_viability", 0.0)
		return
	if bool(target.get("dead")):
		knowledge.remember_escape_point(escape_point)
		blackboard.set_var(&"has_escape_destination", true)
		blackboard.set_var(&"escape_destination", escape_point.global_position)
		blackboard.set_var(&"escape_distance", npc.global_position.distance_to(escape_point.global_position))
		blackboard.set_var(&"escape_route_threat", 0.0)
		blackboard.set_var(&"escape_route_threatened", false)
		blackboard.set_var(&"escape_route_viability", 1.0)
		return
	knowledge.remember_escape_point(escape_point)
	blackboard.set_var(&"has_escape_destination", true)
	blackboard.set_var(&"escape_destination", escape_point.global_position)

	var start := npc.global_position
	var route := escape_point.global_position - start
	route.y = 0.0
	var route_length := route.length()
	if route_length < 0.01:
		blackboard.set_var(&"escape_route_threatened", false)
		blackboard.set_var(&"escape_route_viability", 1.0)
		return

	# При потере LOS маршрут оценивается по последней известной позиции, а не по live transform игрока.
	var can_see: bool = blackboard.get_var(&"can_see_target", false)
	var police_position: Vector3 = target.global_position if can_see else blackboard.get_var(&"last_seen_position", Vector3.ZERO)
	var police_offset := police_position - start
	police_offset.y = 0.0
	var along := police_offset.dot(route) / route.length_squared()
	var nearest := start + route * clampf(along, 0.0, 1.0)
	var lateral_distance := Vector3(police_position.x, start.y, police_position.z).distance_to(nearest)
	var point_control_radius: float = escape_point.get("police_control_radius")
	var control_radius := point_control_radius + route_safety_margin
	var between := smoothstep(-0.05, 0.18, along) * (1.0 - smoothstep(1.0, 1.25, along))
	var lateral_control := 1.0 - smoothstep(point_control_radius, control_radius, lateral_distance)
	var awareness := 1.0 if can_see else clampf(1.0 - float(blackboard.get_var(&"time_since_target_seen", INF)) / 3.0, 0.0, 0.75)
	var route_threat := clampf(between * lateral_control * awareness, 0.0, 1.0)
	blackboard.set_var(&"escape_route_threat", route_threat)
	blackboard.set_var(&"escape_route_threatened", route_threat > 0.32)
	blackboard.set_var(&"escape_route_viability", lerpf(1.0, viability_when_fully_blocked, route_threat))
	blackboard.set_var(&"escape_distance", route_length)

func select_fire_move_destination() -> Vector3:
	var threat := npc.ai_controller.known_threat_position()
	if threat == Vector3.ZERO:
		return Vector3.ZERO
	var away := npc.global_position - threat
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = npc.global_basis.z
	away = away.normalized()
	var side := Vector3(-away.z, 0.0, away.x)
	var phase := int(npc.get_instance_id() + Time.get_ticks_msec() / 1000.0)
	var side_sign := -1.0 if phase % 2 == 0 else 1.0
	return npc.global_position + side * side_sign * 1.6 + away * 0.35
