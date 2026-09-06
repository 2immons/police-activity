# Glock / X12 integration

Controls in `test_scene.tscn`: **1** draws/holsters, hold **RMB** to aim, **R** reloads; **LMB** fires one shot per press. Reload can be demonstrated with a full magazine; repeated R does not restart it. Holstering cancels a reload. Sprint lowers the weapon and temporarily suppresses aiming.

With the weapon drawn, **wheel up** selects high-ready and **wheel down** selects low-ready. High-ready smoothly blends 85% toward the ADS pose (`high_ready_amount`), leaving the sights slightly below full alignment. RMB temporarily overrides either stance; releasing it restores the selection. Walls, reload and sprint lower the weapon temporarily. During Alt free look the captured weapon pose remains fixed until free look ends.

With the pistol fully drawn in low-ready, high-ready or ADS, **S** is a backpedal relative to the camera. The character keeps the chest and weapon facing the camera heading instead of turning toward backward travel; diagonal S+A/S+D retains the same facing rule. The Walk clip runs backward to avoid forward-walk footwork while retreating. Unarmed S keeps the normal movement-facing behavior.

Sprint holds the pistol in the right hand while the left arm keeps its locomotion animation. Its weapon animation and grip IK blend out together, then return when sprint ends (`sprint_hand_transition_duration`, 0.3 seconds). Sprint interrupts and prevents reloading so the support hand stays free.

`WeaponArms` is a SkeletonModifier3D after `BodyLook`. It samples only arm/finger rotation tracks from `Pistol_Idle`, `Pistol_Aim_Neutral`, and `Pistol_Reload`; the existing AnimationPlayer retains locomotion. A two-bone solver places the wrists on the weapon's grip markers. The left hand follows the magazine during reload. The original weapon bones `mag_main_09` and `j_slide_07` provide magazine/slide motion.

The support-hand grip applies a configurable wrist roll and finger curl after IK. `left_grip_roll_degrees` turns the palm onto the side of the firing hand; `left_finger_curl_degrees` closes all four fingers and lightly closes the thumb around the grip. Both values are in `weapon_settings.tres` and blend out with the left-hand IK during sprint.

Tuning: `experiments/weapon_system/weapon_settings.tres`. Grip transforms, muzzle, sight and magazine hand target: `prefabs/glock_17.tscn`. Holster pose: `prefabs/weapon_rig.tscn`. Static nodes exist in scenes before ready.

The supplied prefab selected the X12 from the X12/X13 asset. `glock_model.tscn` preserves that selection, textures, meshes, skin and bones, with the presentation transform removed and size/orientation normalized (roughly 19 cm long). The GLB is unchanged. There were no embedded gun animation clips. The gameplay prefab retains the user's Glock17 name.

Source asset metadata:
- Title: Call of Duty: MWII (2022) - X12&X13
- Author: thientrung2004pr (https://sketchfab.com/U.SSCIFI)
- Source: https://sketchfab.com/3d-models/call-of-duty-mwii-2022-x12x13-c43f2b4641bb4b739b774a2ee415c4b7
- License recorded in source: CC-BY-4.0 (https://creativecommons.org/licenses/by/4.0/)
- Changes: selected X12 only, normalized transform/scale, added gameplay grip markers and procedural magazine/slide motion.

Verification: `tests/weapon_test.gd` checks input transitions, draw/holster, aim, reload completion/cancellation and wrist-to-grip error through large head turns. `artifacts/capture_glock.gd` captures first-person ready/aim/reload and a third-person inspection view.


Shooting uses the current Muzzle global position and -Z axis, including recoil and Alt free look. It is a hitscan query with player exclusion, ammo and shot-interval checks. A chest-to-muzzle guard prevents shooting from a muzzle that has penetrated cover. Hit colliders may implement `receive_bullet_hit(damage, position, direction)`; the controller also emits `shot_fired(origin, direction, hit)`.

At full ADS, both grips are first kept within arm reach. The camera then smoothly moves by the lateral distance from the animated eye to the final Sight axis, capped by `max_aim_camera_offset`. This keeps rear/front sights aligned after torso, shoulder and grip IK corrections. `aim_camera_alignment_speed` controls settling. High-ready does not engage this correction. Armed look redistributes yaw toward the chest and shoulders so less camera correction is needed at side angles.

ADS turns temporarily offset the eye from the sight line. Angular travel accumulates with exponential decay, so faster/wider turns separate the sights more than slow tracking. `aim_turn_lag_strength`, `aim_turn_lag_limit` (metres), and `aim_turn_lag_return_speed` tune the effect. It clears during free look and does not change the muzzle's ballistic direction.

Vertical recoil accumulates up to `max_recoil_degrees`. A fraction (`recoil_pitch_recovery`, currently 65%) recovers smoothly at `recoil_pitch_return_speed`; the remaining 35% stays above the previous aim. Pulling the mouse down compensates both current pitch and its retained target, so automatic recovery cannot pull it back up. Remaining movement pitches the camera down. Alt free look never compensates the weapon. The backward impulse and lateral kick settle at `recoil_return_speed`. `recoil_pivot_distance` places the pivot behind the grip so the pistol and IK-driven hands rise together. Tune these values in `weapon_settings.tres`.

Recoil is applied to the weapon transform before the arm IK solve. Settings expose pitch/yaw kick, backward travel, return speed and maximum kick. The gunshot sound is a generated placeholder. Muzzle flash and audio nodes are authored in glock_17.tscn; temporary impact instances expire after 25 seconds and are capped at 48.

WeaponRig/ObstructionProbe is an editable sphere ShapeCast3D. It checks the desired aimed pose even while the current weapon is lowered, and uses extra clearance to resume aiming. Holding RMB restores aim when the space clears. Firing is rejected while obstructed, sprinting, reloading, holstered or empty.

After the folder move, camera tuning is in `experiments/player_camera/`; weapon behavior/tuning is in `experiments/weapon_system/`. Resource script references follow those locations.
