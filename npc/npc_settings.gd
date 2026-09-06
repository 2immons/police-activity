class_name NpcReactionSettings
extends Resource

@export_range(1, 10, 1) var chest_hits_to_kill: int = 2
@export_range(0.0, 100.0, 0.5) var limb_impulse: float = 18.0
@export_range(0.0, 200.0, 1.0) var death_impulse: float = 58.0
@export_range(0.0, 2.0, 0.01) var reaction_position_scale: float = 0.18
@export_range(0.0, 2.0, 0.01) var reaction_rotation_scale: float = 0.55
@export_range(1.0, 80.0, 0.5) var reaction_spring: float = 34.0
@export_range(0.0, 30.0, 0.5) var reaction_damping: float = 8.5
@export_range(0.0, 1.0, 0.05) var torso_transfer: float = 0.28
@export_range(0.0, 30.0, 0.5) var ragdoll_linear_damp: float = 0.8
@export_range(0.0, 30.0, 0.5) var ragdoll_angular_damp: float = 2.2
@export_group("AI locomotion")
@export var walk_speed: float = 1.7
@export var jog_speed: float = 2.7
@export var acceleration: float = 5.0
@export var turn_speed: float = 5.0
@export var patrol_arrival_distance: float = 0.7
@export var min_patrol_pause: float = 0.4
@export var max_patrol_pause: float = 1.6
@export_group("AI shooting")
@export var engagement_range: float = 24.0
@export var fire_interval_min: float = 0.32
@export var fire_interval_max: float = 0.72
@export var aim_settle_time: float = 0.85
@export var base_spread_degrees: float = 0.45
@export var distance_spread_degrees: float = 1.1
@export var movement_spread_degrees: float = 1.25
@export var sway_degrees: float = 0.38
@export var shot_damage: float = 25.0
@export var bullet_impulse: float = 18.0
