class_name BodySurfaceInteraction
extends RefCounted

var has_surface: bool = false
var nearest_surface := Vector3.ZERO
var distance: float = INF
var normal := Vector3.ZERO
var approach_factor: float = 0.0
var relative_velocity := Vector3.ZERO
var surface_height: float = 0.0
var time_to_contact: float = INF
var collider: Object

func clear() -> void:
	has_surface = false
	nearest_surface = Vector3.ZERO
	distance = INF
	normal = Vector3.ZERO
	approach_factor = 0.0
	relative_velocity = Vector3.ZERO
	surface_height = 0.0
	time_to_contact = INF
	collider = null

func copy_from(other: BodySurfaceInteraction) -> void:
	has_surface = other.has_surface
	nearest_surface = other.nearest_surface
	distance = other.distance
	normal = other.normal
	approach_factor = other.approach_factor
	relative_velocity = other.relative_velocity
	surface_height = other.surface_height
	time_to_contact = other.time_to_contact
	collider = other.collider

func to_dictionary() -> Dictionary:
	return {
		"has_surface": has_surface,
		"nearest_surface": nearest_surface,
		"distance": distance,
		"normal": normal,
		"approach_factor": approach_factor,
		"relative_velocity": relative_velocity,
		"surface_height": surface_height,
		"time_to_contact": time_to_contact,
		"collider": collider,
	}
