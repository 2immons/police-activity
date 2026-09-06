class_name SuspectKnowledge
extends Node

var selected_escape_point: Marker3D
var known_escape_points: Array[Marker3D] = []

func remember_escape_point(point: Marker3D) -> void:
	if not is_instance_valid(point):
		return
	if not known_escape_points.has(point):
		known_escape_points.append(point)
	selected_escape_point = point

func selected_escape_position() -> Vector3:
	return selected_escape_point.global_position if is_instance_valid(selected_escape_point) else Vector3.ZERO
