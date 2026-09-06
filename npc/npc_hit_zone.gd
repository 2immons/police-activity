class_name NpcHitZone
extends StaticBody3D

@export_enum("HEAD", "CHEST", "LEFT_ARM", "RIGHT_ARM", "LEFT_LEG", "RIGHT_LEG") var zone := "CHEST"
@export var reaction_bone: StringName = &"UpperChest"

func receive_bullet_hit(damage: float, hit_position: Vector3, direction: Vector3) -> void:
	var npc := _find_npc()
	if npc != null:
		npc.receive_zone_hit(zone, reaction_bone, damage, hit_position, direction)

func set_hitbox_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not enabled)

func _find_npc() -> Node:
	var current: Node = self
	while current != null:
		if current.is_in_group("damageable_humanoid"):
			return current
		current = current.get_parent()
	return null
