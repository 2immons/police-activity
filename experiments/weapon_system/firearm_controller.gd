class_name PlayerFirearmController
extends Node

signal shot_fired(origin: Vector3, direction: Vector3, hit: Dictionary)

const IMPACT_SCENE: PackedScene = preload("res://experiments/weapon_system/bullet_impact.tscn")
const BulletSolver = preload("res://experiments/weapon_system/ballistics/bullet_penetration_solver.gd")

@export var weapon: Node3D
@export var muzzle: Marker3D
@export var shot_audio: AudioStreamPlayer3D
@export var muzzle_flash: Node3D
@export var settings: PlayerWeaponSettings = preload("res://experiments/weapon_system/weapon_settings.tres")

var rounds: int = 0
var shots_fired: int = 0
var last_shot: Dictionary = {}

var _cooldown: float = 0.0
var _flash_time: float = 0.0
var _impacts: Array[Node3D] = []

func _ready() -> void:
	assert(is_instance_valid(weapon), "Firearm requires its weapon root")
	assert(is_instance_valid(muzzle), "Firearm requires a Muzzle marker")
	assert(is_instance_valid(shot_audio), "Firearm requires ShotAudio")
	assert(is_instance_valid(muzzle_flash), "Firearm requires a muzzle flash node")
	rounds = settings.magazine_capacity
	muzzle_flash.visible = false

func advance(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_flash_time = maxf(_flash_time - delta, 0.0)
	muzzle_flash.visible = _flash_time > 0.0

func can_fire(equipped: bool, draw_amount: float, reloading: bool, sprinting: bool) -> bool:
	return equipped and draw_amount >= 0.999 and not reloading and not sprinting and rounds > 0 and _cooldown <= 0.0

func fire(player: CharacterBody3D, chest_origin: Vector3) -> Dictionary:
	var origin: Vector3 = muzzle.global_position
	var direction: Vector3 = -muzzle.global_basis.z.normalized()
	var exclusions: Array[RID] = player.get_damage_collision_rids() if player.has_method("get_damage_collision_rids") else [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = weapon.get_world_3d().direct_space_state

	# The chest-to-muzzle guard prevents firing from the far side of nearby cover.
	var guard := PhysicsRayQueryParameters3D.create(chest_origin, origin, settings.shot_mask, exclusions)
	guard.hit_from_inside = true
	if not space.intersect_ray(guard).is_empty():
		return {}

	var trace: Dictionary = BulletSolver.trace(
		space, origin, direction, settings.shot_range, settings.shot_mask,
		exclusions, settings.caliber, settings.weapon_id,
		settings.penetration_energy, settings.maximum_penetrations
	)
	var hit: Dictionary = trace.hit
	rounds -= 1
	shots_fired += 1
	_cooldown = settings.shot_interval
	_flash_time = 0.035
	muzzle_flash.visible = true
	shot_audio.play()
	last_shot = {"origin": origin, "direction": direction, "hit": hit, "hits": trace.hits, "penetrations": trace.penetrations}

	_notify_nearby_shot(origin, direction, origin.distance_to(hit.position) if not hit.is_empty() else settings.shot_range)
	for traced_hit: Dictionary in trace.hits:
		_spawn_impact(traced_hit)
		if traced_hit.collider.has_method("receive_bullet_hit"):
			traced_hit.collider.receive_bullet_hit(settings.shot_damage, traced_hit.position, direction)
	shot_fired.emit(origin, direction, hit)
	return last_shot

func refill() -> void:
	rounds = settings.magazine_capacity

func get_cooldown_ratio() -> float:
	return clampf(_cooldown / maxf(settings.shot_interval, 0.01), 0.0, 1.0)

func is_cooled_down() -> bool:
	return _cooldown <= 0.0

func set_cooldown(seconds: float) -> void:
	_cooldown = maxf(seconds, 0.0)

func _notify_nearby_shot(origin: Vector3, direction: Vector3, distance: float) -> void:
	var end := origin + direction * distance
	for node in get_tree().get_nodes_in_group("damageable_npc"):
		if node.has_method("receive_heard_stimulus"):
			var hearing_distance: float = (node as Node3D).global_position.distance_to(origin)
			if hearing_distance <= 32.0:
				node.receive_heard_stimulus(origin, 1.0 - hearing_distance / 32.0)
		if not node.has_method("receive_suppression"):
			continue
		var target: Vector3 = (node as Node3D).global_position + Vector3.UP * 1.2
		var segment := end - origin
		var along := clampf((target - origin).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		var closest := origin + segment * along
		var miss_distance := target.distance_to(closest)
		if miss_distance <= 2.2:
			node.receive_suppression(origin, closest, (1.0 - miss_distance / 2.2) * 0.5)

func _spawn_impact(hit: Dictionary) -> void:
	_impacts = _impacts.filter(func(node: Node3D) -> bool: return is_instance_valid(node))
	if _impacts.size() >= 48:
		_impacts.pop_front().queue_free()
	var impact: Node3D = IMPACT_SCENE.instantiate()
	# Parenting to the collider keeps decals attached to moving doors and props.
	var impact_parent: Node = hit.collider if hit.collider is Node3D else get_tree().current_scene
	if impact_parent == null:
		impact_parent = get_tree().root
	impact_parent.add_child(impact)
	var normal: Vector3 = hit.normal
	if normal.length_squared() < 0.01:
		normal = Vector3.UP
	impact.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal.normalized())), hit.position + normal * 0.003)
	_impacts.append(impact)
