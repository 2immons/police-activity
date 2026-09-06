class_name DoorInteractionSettings
extends Resource

@export_range(0.1, 0.8, 0.01) var hold_delay: float = 0.28
@export_range(0.5, 3.0, 0.05) var ray_length: float = 1.8
@export_range(0.05, 0.8, 0.01) var support_hand_transition: float = 0.22
@export_range(1.0, 30.0, 0.5) var hand_target_transition_speed: float = 11.0
@export_range(0.0, 0.2, 0.005) var hand_reach_margin: float = 0.04
@export_range(0.0, 0.25, 0.005) var torso_reach_extension: float = 0.14
@export_range(1.0, 30.0, 0.5) var torso_reach_transition_speed: float = 9.0
