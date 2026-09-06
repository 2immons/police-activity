class_name BasicPlayerMovementSettings
extends Resource

@export var walk_speed: float = 2.0
@export var jog_speed: float = 3.0
@export var sprint_speed: float = 4.5
@export_group("Aim movement")
@export var aim_slow_speed: float = 0.9
@export var aim_fast_speed: float = 2.2
@export var crouch_speed: float = 1.0
@export_range(0.1, 0.6, 0.01) var sprint_hold_delay: float = 0.28
@export var acceleration: float = 9.0
@export var braking: float = 14.0
@export var direction_acceleration: float = 7.0
## Higher steering response while Shift+forward is held.
@export var sprint_direction_acceleration: float = 22.0
@export var animation_blend: float = 0.25
@export var idle_blend: float = 0.30
@export var sprint_blend: float = 0.32
@export var crouch_blend: float = 0.28
@export_range(0.95, 1.7, 0.01) var crouch_collider_height: float = 1.25
@export_range(1.0, 15.0, 0.5) var crouch_collider_speed: float = 7.0
@export_range(0.1, 2.0, 0.05) var turn_in_place_animation_speed: float = 0.65
@export_group("Footsteps")
@export_range(0.5, 2.0, 0.01) var footsteps_walk_rate: float = 1.0
@export_range(0.5, 2.5, 0.01) var footsteps_sprint_rate: float = 1.45
@export_range(0.5, 2.5, 0.01) var footsteps_jog_rate: float = 1.25
@export_range(0.5, 2.0, 0.01) var footsteps_crouch_rate: float = 0.82
@export_range(0.25, 2.0, 0.01) var footsteps_turn_rate: float = 0.72
@export_range(-40.0, 6.0, 0.5) var footsteps_volume_db: float = -7.0
@export_range(-40.0, 6.0, 0.5) var footsteps_turn_volume_db: float = -11.0
@export_range(1.0, 90.0, 1.0) var footsteps_turn_threshold_degrees: float = 8.0
@export_range(0.0, 30.0, 0.5) var footsteps_fade_speed: float = 12.0
@export var turn_speed_degrees: float = 220.0
@export var turn_acceleration_degrees: float = 1000.0
@export var turn_response: float = 8.0
@export_group("Unarmed click alignment")
@export var unarmed_align_turn_speed_degrees: float = 180.0
@export var unarmed_align_turn_acceleration_degrees: float = 900.0
@export var unarmed_align_turn_response: float = 8.0
@export_group("Armed standing turn")
@export var armed_free_look_degrees: float = 45.0
@export var armed_turn_speed_degrees: float = 120.0
@export var armed_turn_acceleration_degrees: float = 600.0
@export var armed_turn_response: float = 6.0
@export var free_look_return_speed: float = 12.0
