class_name BulletPenetrationSettings
extends Resource

## Пустой список означает, что ограничение по этому признаку не применяется.
@export var allowed_calibers: PackedStringArray = PackedStringArray()
@export var allowed_weapon_ids: PackedStringArray = PackedStringArray()
@export_range(0.0, 10.0, 0.05) var penetration_cost: float = 0.25

func accepts(caliber: StringName, weapon_id: StringName, available_energy: float) -> bool:
	if available_energy + 0.0001 < penetration_cost:
		return false
	if not allowed_calibers.is_empty() and not String(caliber) in allowed_calibers:
		return false
	if not allowed_weapon_ids.is_empty() and not String(weapon_id) in allowed_weapon_ids:
		return false
	return true
