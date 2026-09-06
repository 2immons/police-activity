extends RefCounted

## Возвращает максимальное поджатие, требуемое для ствола и обеих кистей.
func measure(
	probes: Array,
	eye: Vector3,
	targets: Array,
	clearances: Array,
	maximum: float
) -> float:
	var compression := 0.0
	for index in probes.size():
		compression = maxf(compression, _measure_probe(probes[index], eye, targets[index], clearances[index]))
	return clampf(compression, 0.0, maximum)

func _measure_probe(probe: ShapeCast3D, eye: Vector3, target: Vector3, clearance: float) -> float:
	probe.global_transform = Transform3D(Basis.IDENTITY, eye)
	probe.target_position = target - eye
	probe.force_shapecast_update()
	if not probe.is_colliding():
		return 0.0

	var nearest_distance := INF
	for collision_index in probe.get_collision_count():
		nearest_distance = minf(nearest_distance, eye.distance_to(probe.get_collision_point(collision_index)))
	return maxf(eye.distance_to(target) - nearest_distance + clearance, 0.0)
