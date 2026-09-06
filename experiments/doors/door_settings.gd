class_name PhysicalDoorSettings
extends Resource

@export_group("Geometry")
@export var min_angle_degrees: float = 0.0
@export var max_angle_degrees: float = 95.0
@export var auto_open_angle_degrees: float = 90.0

@export_group("Motion")
@export_range(1.0, 80.0, 0.5) var mass: float = 18.0
@export_range(0.0, 20.0, 0.1) var resistance: float = 3.2
@export_range(0.1, 30.0, 0.1) var auto_stiffness: float = 10.0
@export_range(0.1, 20.0, 0.1) var controlled_stiffness: float = 14.0
@export_range(0.1, 20.0, 0.1) var damping: float = 4.5
@export_range(0.1, 12.0, 0.1) var max_angular_speed: float = 4.6
@export_range(0.1, 100.0, 0.5) var max_motor_impulse: float = 24.0
@export_range(0.0, 2.0, 0.01) var release_inertia: float = 0.55
@export_range(0.05, 3.0, 0.05) var body_push_impulse_scale: float = 1.1
@export_range(0.05, 2.0, 0.05) var minimum_body_push_speed: float = 0.3

@export_group("Interaction")
@export_range(0.1, 3.0, 0.05) var interaction_distance: float = 1.65
@export_range(0.05, 0.6, 0.01) var handle_press_duration: float = 0.16
@export_range(1.0, 12.0, 0.1) var handle_return_speed: float = 7.0
@export_range(1.0, 45.0, 0.5) var handle_press_degrees: float = 18.0
@export_group("Interaction highlight")
@export_range(1.0, 30.0, 0.5) var highlight_transition_speed: float = 12.0
@export_range(0.0, 1.0, 0.05) var panel_highlight_strength: float = 0.55
@export_range(0.0, 1.0, 0.05) var handle_highlight_strength: float = 0.95
@export_range(0.25, 10.0, 0.25) var controlled_wheel_step_degrees: float = 5.0
@export_range(0.05, 1.0, 0.01) var closed_angle_epsilon_degrees: float = 3.0
