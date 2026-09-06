class_name CombatAIProfile
extends Resource

@export_group("Personality")
@export_range(0.0, 1.0, 0.01) var aggression := 0.58
@export_range(0.0, 1.0, 0.01) var caution := 0.68
@export_range(0.0, 1.0, 0.01) var cover_preference := 0.78
@export_range(0.0, 1.0, 0.01) var reposition_preference := 0.52
@export_range(0.0, 1.0, 0.01) var aim_skill := 0.66
@export_range(0.0, 1.0, 0.01) var suppression_sensitivity := 0.82
@export_range(0.0, 1.0, 0.01) var peek_confidence := 0.58
@export_range(0.0, 1.0, 0.01) var movement_confidence := 0.65
@export var preferred_combat_distance := 8.0

@export_group("Perception")
@export var vision_range := 24.0
@export_range(30.0, 180.0, 1.0) var vision_fov_degrees := 125.0
@export var perception_interval := 0.12
@export var detection_time := 0.34
@export var memory_duration := 7.0

@export_group("Decision")
@export var decision_interval := 0.18
@export var minimum_commitment_time := 0.65
@export_range(0.0, 0.5, 0.01) var continuation_bonus := 0.10
@export_range(0.0, 0.5, 0.01) var switch_threshold := 0.08

@export_group("Aim")
@export var initial_aim_error_degrees := 9.0
@export var settled_aim_error_degrees := 0.75
@export var aim_settle_time := 0.82
@export var tracking_speed := 8.0
@export var maximum_tracking_speed_degrees := 300.0
@export var aim_noise_frequency := Vector2(1.27, 0.83)
@export var movement_error_degrees := 3.2
@export var suppression_error_degrees := 5.5
@export var recoil_degrees := Vector2(2.4, 0.75)
@export var recoil_recovery_speed := 5.8
@export_range(0.0, 1.0, 0.01) var minimum_fire_quality := 0.57

@export_group("Weapon")
@export var magazine_capacity := 17
@export var shot_interval := 0.38
@export var burst_pause := 0.72
@export var reload_duration := 1.7
@export var shot_range := 30.0
@export var shot_damage := 25.0
## Радиус в метрах, внутри которого пролёт пули создаёт suppression у игрока.
@export_range(0.25, 6.0, 0.05) var player_suppression_radius := 2.5
## Максимальная сила stress stimulus от одного близкого пролёта.
@export_range(0.0, 1.0, 0.01) var player_suppression_strength := 0.34

@export_group("Movement")
@export var walk_speed := 1.55
@export var tactical_walk_speed := 1.05
@export var jog_speed := 2.55
@export var run_speed := 3.25
@export var acceleration := 6.5
@export var turn_speed := 5.0

@export_group("Tactics")
@export var suppression_decay := 0.20
@export var incoming_fire_memory := 2.5
@export var cover_scan_radius := 12.0
@export var cover_arrival_distance := 0.65
@export var search_arrival_distance := 0.8
@export var peek_prepare_time := 0.28
@export var peek_expose_time := 1.25
@export var crouch_cover_height := 1.15
