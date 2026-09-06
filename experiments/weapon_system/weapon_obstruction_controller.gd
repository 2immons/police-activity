class_name PlayerWeaponObstructionController
extends Node

const ObstructionSolver = preload("res://experiments/weapon_system/weapon_obstruction_solver.gd")

@export var muzzle_probe: ShapeCast3D
@export var left_hand_probe: ShapeCast3D
@export var right_hand_probe: ShapeCast3D
@export var settings: PlayerWeaponSettings = preload("res://experiments/weapon_system/weapon_settings.tres")

var obstructed: bool = false
var compression: float = 0.0
var amount: float = 0.0
var emergency_drop: float = 0.0

var _solver: RefCounted = ObstructionSolver.new()

func _ready() -> void:
	assert(is_instance_valid(muzzle_probe) and is_instance_valid(left_hand_probe) and is_instance_valid(right_hand_probe), "Obstruction controller requires all three authored probes")

func exclude_player(player: CharacterBody3D) -> void:
	for probe: ShapeCast3D in [muzzle_probe, left_hand_probe, right_hand_probe]:
		probe.add_exception(player)
		if player.has_method("get_damage_collision_rids"):
			for hitbox_rid: RID in player.get_damage_collision_rids():
				probe.add_exception_rid(hitbox_rid)

func advance(delta: float, eye: Vector3, target_points: Array[Vector3], enabled: bool, stance_amount: float) -> void:
	var desired := 0.0
	if enabled:
		var release_clearance := settings.obstruction_release_margin if obstructed else 0.0
		desired = _solver.measure(
			[muzzle_probe, left_hand_probe, right_hand_probe], eye, target_points,
			[settings.obstruction_clearance + release_clearance, settings.obstruction_hand_clearance + release_clearance, settings.obstruction_hand_clearance + release_clearance],
			settings.obstruction_max_compression
		)
	obstructed = desired > 0.001
	compression = lerpf(compression, desired, 1.0 - exp(-settings.obstruction_compression_speed * delta))
	if absf(compression - desired) < 0.0005:
		compression = desired
	amount = clampf(compression / maxf(settings.obstruction_max_compression, 0.001), 0.0, 1.0)

	var desired_drop := calculate_emergency_drop(compression, stance_amount)
	emergency_drop = lerpf(emergency_drop, desired_drop, 1.0 - exp(-settings.obstruction_emergency_drop_speed * delta))
	if absf(emergency_drop - desired_drop) < 0.0005:
		emergency_drop = desired_drop

func calculate_emergency_drop(current_compression: float, stance_amount: float = 0.0) -> float:
	var aim_weight := smoothstep(0.75, 1.0, stance_amount)
	var start := lerpf(settings.obstruction_emergency_drop_start, settings.aim_emergency_drop_start, aim_weight)
	var maximum := lerpf(settings.obstruction_emergency_drop, settings.aim_emergency_drop, aim_weight)
	return smoothstep(0.0, 1.0, clampf(inverse_lerp(start, settings.obstruction_max_compression, current_compression), 0.0, 1.0)) * maximum
