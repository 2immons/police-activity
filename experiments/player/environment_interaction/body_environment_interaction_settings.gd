class_name BodyEnvironmentInteractionSettings
extends Resource

@export_group("Prediction")
@export_range(0.2, 0.5, 0.01) var prediction_time := 0.40
@export_range(0.4, 1.5, 0.05) var minimum_lookahead := 0.80
@export_range(1.0, 4.0, 0.1) var maximum_lookahead := 2.50
@export_range(0.0, 45.0, 1.0) var trajectory_fan_degrees := 18.0

@export_group("Side squeeze")
@export_range(0.0, 35.0, 0.5) var max_torso_yaw_degrees := 24.0
@export_range(0.0, 0.2, 0.005) var torso_side_offset := 0.075
@export_range(0.1, 1.5, 0.01) var shoulder_activation_distance := 0.82
@export_range(0.05, 1.0, 0.01) var shoulder_full_effect_distance := 0.42
@export_range(1.0, 180.0, 1.0) var squeeze_turn_in_speed_degrees := 95.0
@export_range(1.0, 180.0, 1.0) var squeeze_return_speed_degrees := 110.0
@export_range(0.0, 2.0, 0.01) var minimum_movement_speed := 0.12
@export_range(0.0, 1.0, 0.01) var ads_disable_amount := 0.85
@export_range(0.0, 1.0, 0.01) var side_arm_straightening := 1.0
@export_range(0.0, 0.25, 0.005) var side_arm_outset := 0.15
@export_range(0.05, 1.0, 0.01) var side_pose_blend_in := 0.28
@export_range(0.05, 1.0, 0.01) var side_pose_blend_out := 0.32

@export_group("Near collision reflex")
@export_range(0.2, 1.5, 0.01) var reflex_activation_distance := 1.0
@export_range(0.1, 1.0, 0.01) var reflex_full_distance := 0.50
@export_range(0.0, 8.0, 0.05) var reflex_minimum_speed := 3.0
@export_range(0.1, 8.0, 0.05) var reflex_full_speed := 5.5
@export_range(0.1, 20.0, 0.1) var reflex_reaction_speed := 9.0
@export_range(0.1, 20.0, 0.1) var reflex_return_speed := 6.0
@export_range(0.0, 1.0, 0.01) var reflex_front_normal_dot := 0.45
@export_range(0.0, 1.0, 0.01) var reflex_arm_reach := 0.82
@export_range(0.0, 0.5, 0.01) var reflex_hand_drop := 0.34
@export_range(0.0, 0.3, 0.01) var reflex_hand_outset := 0.14
@export_range(0.05, 0.5, 0.01) var reflex_animation_blend := 0.18
@export_range(0.0, 1.0, 0.01) var reflex_push_pose := 0.63
@export_range(0.0, 8.0, 0.1) var impact_minimum_speed := 3.0
@export_range(0.1, 20.0, 0.1) var impact_decay_speed := 6.0
@export_range(0.0, 1.0, 0.01) var impact_arm_impulse := 0.32
@export_range(0.0, 0.2, 0.005) var impact_chest_offset := 0.065
