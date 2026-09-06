class_name PenetrableSurface
extends Node

@export var settings: Resource

func can_penetrate(caliber: StringName, weapon_id: StringName, available_energy: float) -> bool:
	return settings != null and settings.accepts(caliber, weapon_id, available_energy)

func penetration_cost() -> float:
	return settings.penetration_cost if settings != null else INF
