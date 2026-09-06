class_name PlayerCameraMotionSettings
extends Resource

@export var enabled: bool = true
@export_group("Strength")
@export var master_strength: float = 1.0
@export var idle_strength: float = 0.15
@export var turn_strength: float = 0.35
@export var walk_strength: float = 0.70
@export var sprint_strength: float = 1.50
@export var moving_turn_bonus: float = 0.45
@export var third_person_multiplier: float = 0.65
## Дополнительная нерегулярная раскачка камеры при полном stress amount.
@export_range(0.0, 2.0, 0.05) var stress_camera_strength: float = 0.22
@export_group("Amplitude")
@export var position_amplitude: Vector3 = Vector3(0.006, 0.009, 0.003)
@export var rotation_amplitude_degrees: Vector3 = Vector3(0.8, 0.35, 0.55)
@export_group("Response")
@export var smoothing_speed: float = 9.0
@export var full_turn_speed_degrees: float = 150.0
@export var idle_frequency: float = 0.35
@export var turn_frequency: float = 2.5
@export var walk_step_length: float = 0.75
@export var sprint_step_length: float = 1.45

@export_group("Hit reaction")
@export var hit_position_impulse: Vector3 = Vector3(0.018, 0.012, 0.035)
@export var hit_rotation_impulse_degrees: Vector3 = Vector3(3.2, 2.4, 2.8)
@export_range(0.1, 3.0, 0.05) var limb_hit_multiplier: float = 0.75
@export_range(0.1, 3.0, 0.05) var chest_hit_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.05) var head_hit_multiplier: float = 1.35
@export_range(1.0, 100.0, 0.5) var hit_spring: float = 42.0
@export_range(0.1, 30.0, 0.1) var hit_damping: float = 9.5
