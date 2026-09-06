class_name PlayerWeaponSettings
extends Resource

@export var draw_duration: float = 0.45
@export var aim_duration: float = 0.22
@export_range(1.0, 40.0) var aim_camera_alignment_speed: float = 18.0
@export_range(0.0, 0.15) var max_aim_camera_offset: float = 0.08
## Metres of temporary sight offset per radian of view rotation.
@export_range(0.0, 0.1) var aim_turn_lag_strength: float = 0.035
@export_range(0.0, 0.05) var aim_turn_lag_limit: float = 0.018
@export_range(1.0, 30.0) var aim_turn_lag_return_speed: float = 7.0
## High-ready blends toward ADS without fully aligning the sights.
@export_range(0.0, 1.0) var high_ready_amount: float = 0.85
@export var reload_duration: float = 1.67
@export var magazine_capacity: int = 17
@export_group("Flashlight")
@export var flashlight_energy: float = 8.0
@export var flashlight_range: float = 25.0
@export_range(1.0, 89.0) var flashlight_angle: float = 24.0
@export_group("Weapon pose")
@export var low_ready_position: Vector3 = Vector3(0.12, -0.19, -0.40)
@export var aim_position: Vector3 = Vector3(0.0, -0.0505, -0.42)
@export var low_ready_pitch_degrees: float = -22.0
@export var sprint_lowering: float = 0.12
@export_range(0.05, 1.0) var sprint_hand_transition_duration: float = 0.3
@export var reload_position: Vector3 = Vector3(0.10, -0.12, -0.48)
@export var magazine_travel: float = 0.12
@export var slide_travel: float = 0.035
@export_group("Grip")
## Rotates the support hand around the pistol's longitudinal axis.
@export_range(-120.0, 120.0) var left_grip_roll_degrees: float = -48.0
@export_range(-90.0, 90.0) var left_finger_curl_degrees: float = 48.0
@export_group("Shooting")
@export var shot_interval: float = 0.16
@export var shot_range: float = 120.0
@export var shot_damage: float = 25.0
@export var weapon_id: StringName = &"glock_17"
@export var caliber: StringName = &"9x19mm"
@export_range(0.0, 10.0, 0.05) var penetration_energy: float = 1.0
@export_range(0, 16, 1) var maximum_penetrations: int = 6
@export_flags_3d_physics var shot_mask: int = 4294967295
@export var recoil_pitch_degrees: float = 4.0
## Maximum sideways kick per shot. Its sign is randomized.
@export_range(0.0, 10.0, 0.1) var recoil_yaw_degrees: float = 3.0
## Prevents random yaw from becoming imperceptibly small.
@export_range(0.0, 1.0, 0.05) var recoil_yaw_minimum_factor: float = 0.35
@export_range(0.0, 20.0, 0.1) var max_recoil_yaw_degrees: float = 6.0
@export_range(0.1, 30.0, 0.1) var recoil_yaw_return_speed: float = 12.0
## Fraction of sideways kick recovered automatically; the rest remains until mouse compensation.
@export_range(0.0, 1.0, 0.05) var recoil_yaw_recovery: float = 0.65
@export var recoil_back_distance: float = 0.025
@export var recoil_return_speed: float = 14.0
## Fraction of vertical kick recovered automatically; the rest needs mouse compensation.
@export_range(0.0, 1.0) var recoil_pitch_recovery: float = 0.65
@export_range(0.1, 30.0) var recoil_pitch_return_speed: float = 8.0
## Pivot behind the grip raises the hands together with the muzzle.
@export_range(0.0, 0.4) var recoil_pivot_distance: float = 0.2
@export var max_recoil_degrees: float = 12.0
## Random per-shot strength variation: 0.2 gives 80–120% of the base impulse.
@export_range(0.0, 0.5) var recoil_strength_variation: float = 0.0
@export_group("Aim step motion")
@export var aim_slow_step_position: Vector3 = Vector3(0.0015, 0.001, 0.0008)
@export var aim_fast_step_position: Vector3 = Vector3(0.006, 0.004, 0.002)
@export var aim_slow_step_rotation_degrees: Vector3 = Vector3(0.15, 0.1, 0.18)
@export var aim_fast_step_rotation_degrees: Vector3 = Vector3(0.6, 0.4, 0.75)
@export_range(1.0, 30.0, 0.5) var aim_step_motion_transition_speed: float = 12.0
@export_group("Obstruction")
@export var obstruction_margin: float = 0.06
@export var obstruction_release_margin: float = 0.08
@export var blocked_free_look_drop: float = 0.12
## Clearance kept between the muzzle probe and an obstacle.
@export_range(0.02, 0.2, 0.005) var obstruction_clearance: float = 0.075
@export_range(0.0, 0.15, 0.005) var obstruction_hand_clearance: float = 0.04
@export_range(0.05, 0.4, 0.01) var obstruction_max_compression: float = 0.28
@export_range(1.0, 30.0, 0.5) var obstruction_compression_speed: float = 14.0
## Only after the arms are heavily compressed, lower the unchanged AIM/HR pose.
@export_range(0.05, 0.35, 0.01) var obstruction_emergency_drop_start: float = 0.17
@export_range(0.0, 0.3, 0.01) var obstruction_emergency_drop: float = 0.14
@export_range(0.03, 0.3, 0.01) var aim_emergency_drop_start: float = 0.08
@export_range(0.0, 0.4, 0.01) var aim_emergency_drop: float = 0.24
@export_range(1.0, 30.0, 0.5) var obstruction_emergency_drop_speed: float = 12.0
@export_group("Animated hand follow")
## Makes the weapon inherit small authored hand motion before final grip IK.
@export_range(0.0, 1.0, 0.05) var animated_hand_follow_strength: float = 0.75
@export_range(0.5, 20.0, 0.5) var animated_hand_follow_filter_speed: float = 4.0
@export_range(0.0, 0.08, 0.005) var animated_hand_follow_limit: float = 0.035
