class_name BulletPenetrationSolver
extends RefCounted

const SURFACE_NODE_NAME := "BallisticSurface"

static func trace(
	space: PhysicsDirectSpaceState3D,
	origin: Vector3,
	direction: Vector3,
	distance: float,
	collision_mask: int,
	excluded: Array[RID],
	caliber: StringName,
	weapon_id: StringName,
	energy: float,
	maximum_penetrations: int
) -> Dictionary:
	var hits: Array[Dictionary] = []
	var current_origin := origin
	var remaining_distance := distance
	var remaining_energy := energy
	var penetration_count := 0
	var query_excluded := excluded.duplicate()

	while remaining_distance > 0.001:
		var query := PhysicsRayQueryParameters3D.create(current_origin, current_origin + direction * remaining_distance, collision_mask, query_excluded)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break

		hits.append(hit)
		var surface: Node = find_surface(hit.collider)
		if surface == null or penetration_count >= maximum_penetrations or not surface.can_penetrate(caliber, weapon_id, remaining_energy):
			break

		remaining_energy -= surface.penetration_cost()
		penetration_count += 1
		var travelled: float = current_origin.distance_to(hit.position)
		remaining_distance -= travelled
		query_excluded.append(hit.rid)
		current_origin = hit.position + direction * 0.002
		remaining_distance -= 0.002

	return {
		"hits": hits,
		"hit": hits[0] if not hits.is_empty() else {},
		"final_hit": hits[-1] if not hits.is_empty() else {},
		"penetrations": penetration_count,
		"remaining_energy": remaining_energy,
	}

static func find_surface(collider: Object) -> Node:
	if collider is Node:
		var node := collider as Node
		var surface: Node = node.get_node_or_null(SURFACE_NODE_NAME)
		if surface != null:
			return surface
		if node.get_parent() != null:
			return node.get_parent().get_node_or_null(SURFACE_NODE_NAME)
	return null
