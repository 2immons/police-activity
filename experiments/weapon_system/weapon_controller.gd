class_name PlayerWeaponPoseController
extends SkeletonModifier3D

signal shot_fired(origin: Vector3, direction: Vector3, hit: Dictionary)

@export var weapon: Node3D
@export var look_controller: PlayerLookController
@export var animation_player: AnimationPlayer
@export var player: CharacterBody3D
@export var body_environment: BodyEnvironmentInteractionController
@export var door_interaction: DoorInteractionController
@export var firearm: PlayerFirearmController
@export var recoil: PlayerWeaponRecoilController
@export var obstruction: PlayerWeaponObstructionController
@export var stress_controller: PlayerStressController
@export var settings: PlayerWeaponSettings = preload("res://experiments/weapon_system/weapon_settings.tres")

var equipped := false
var flashlight_enabled := false
@onready var flashlight: SpotLight3D = weapon.get_node("Flashlight")
var aim_pressed := false
var high_ready := false
var reloading := false
var draw_amount := 0.0
var aim_amount := 0.0
var reload_time := 0.0
var magazine_offset := 0.0
var _clips: Dictionary = {}
var _bone_indices: Dictionary[StringName, int] = {}
var _arm_bones: Array[int] = []
var _left_arm_bones: Array[int] = []
var _sprint_hand_release := 0.0
var _door_hand_release := 0.0
var _door_hand_pose := Transform3D.IDENTITY
var _door_hand_pose_initialized := false
var _door_torso_offset := Vector3.ZERO
var _gun_skeleton: Skeleton3D
var _mag_idx := -1
var _slide_idx := -1
var _mag_rest := Vector3.ZERO
var _slide_rest := Vector3.ZERO
var _authored_weapon := Transform3D.IDENTITY
var _holster: Marker3D
var _grip_left: Marker3D
var _grip_right: Marker3D
var _sight: Marker3D
var _magazine_grip: Marker3D
var _pose_time := 0.0
var rest_weapon_pose := Transform3D.IDENTITY
var _previous_aim_view := Basis.IDENTITY
var _aim_view_initialized := false
var _aim_turn_lag := Vector2.ZERO
var _side_squeeze_arm_weight := 0.0
var _side_squeeze_arm_side := ""

func _update_aim_turn_lag(delta: float, enabled: bool) -> void:
	var view: Basis = look_controller.global_basis.orthonormalized()
	if not _aim_view_initialized:
		_previous_aim_view = view
		_aim_view_initialized = true
	if enabled:
		# Integrate angular travel: wider/faster turns accumulate more offset,
		# while slow tracking gives the eye time to settle back behind the sights.
		var relative := view.inverse() * _previous_aim_view
		var angles := relative.get_euler()
		var decay := exp(-settings.aim_turn_lag_return_speed * delta)
		var integration := (1.0 - decay) / maxf(settings.aim_turn_lag_return_speed * delta, 0.00001)
		_aim_turn_lag = (_aim_turn_lag * decay + Vector2(-angles.y, angles.x) * settings.aim_turn_lag_strength * integration).limit_length(settings.aim_turn_lag_limit)
	else:
		_aim_turn_lag = Vector2.ZERO
	_previous_aim_view = view
var _fire_requested := false
var _animated_hand_center_filtered := Vector3.ZERO
var _animated_hand_center_initialized := false
var _aim_step_motion_weight := 0.0
var rounds: int:
	get: return firearm.rounds
	set(value): firearm.rounds = value
var shots_fired: int:
	get: return firearm.shots_fired
var last_shot: Dictionary:
	get: return firearm.last_shot
var obstructed: bool:
	get: return obstruction.obstructed

func _ready() -> void:
	assert(is_instance_valid(player), "Weapon pose controller requires Player")
	assert(is_instance_valid(body_environment), "Weapon pose controller requires BodyEnvironmentInteraction")
	assert(is_instance_valid(door_interaction), "Weapon pose controller requires DoorInteraction")
	assert(is_instance_valid(firearm) and is_instance_valid(recoil) and is_instance_valid(obstruction), "Weapon runtime components are not wired")
	assert(is_instance_valid(stress_controller), "Weapon pose controller requires PlayerStressController")
	var sk := get_skeleton()
	for i in range(sk.get_bone_count()):
		_bone_indices[sk.get_bone_name(i)] = i
		var ancestor := i
		while ancestor >= 0:
			if sk.get_bone_name(ancestor) in ["LeftShoulder", "RightShoulder"]:
				_arm_bones.append(i)
				if sk.get_bone_name(ancestor) == "LeftShoulder":
					_left_arm_bones.append(i)
				break
			ancestor = sk.get_bone_parent(ancestor)
	for clip_name in ["Pistol_Idle", "Pistol_Aim_Neutral", "Pistol_Reload"]:
		var clip := animation_player.get_animation(clip_name)
		var tracks: Dictionary = {}
		for track in range(clip.get_track_count()):
			var path := clip.track_get_path(track)
			if path.get_subname_count() == 0: continue
			var index := _bone(path.get_subname(0))
			if index in _arm_bones and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				tracks[index] = track
		_clips[clip_name] = {"animation": clip, "tracks": tracks}
	_gun_skeleton = weapon.get_node("Model/Skeleton3D")
	_mag_idx = _gun_skeleton.find_bone("mag_main_09")
	_slide_idx = _gun_skeleton.find_bone("j_slide_07")
	_mag_rest = _gun_skeleton.get_bone_pose_position(_mag_idx)
	_slide_rest = _gun_skeleton.get_bone_pose_position(_slide_idx)
	_authored_weapon = weapon.transform
	_holster = weapon.get_parent().get_node("HolsterPose")
	_grip_left = weapon.get_node("GripLeft")
	_grip_right = weapon.get_node("GripRight")
	_sight = weapon.get_node("Sight")
	_magazine_grip = weapon.get_node("MagazineGrip")
	weapon.visible = false
	# Player enters ready after this modifier because the rig lives in its child scene.
	call_deferred("_configure_obstruction_exclusions")
	firearm.shot_fired.connect(_on_firearm_shot_fired)

func _configure_obstruction_exclusions() -> void:
	obstruction.exclude_player(player)

func _bone(bone_name: StringName) -> int:
	return _bone_indices.get(bone_name, -1)

func _grip(side: String) -> Marker3D:
	return _grip_left if side == "Left" else _grip_right

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		# Release events can happen while the game is paused.
		aim_pressed = false
		_fire_requested = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_C and event.pressed and not event.echo and equipped:
		flashlight_enabled = not flashlight_enabled
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and equipped:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if is_instance_valid(door_interaction.controlled_door):
				return
			high_ready = event.button_index == MOUSE_BUTTON_WHEEL_UP
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1:
			toggle_weapon()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			start_reload()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and equipped:
		aim_pressed = event.pressed
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_fire_requested = true
		get_viewport().set_input_as_handled()

func toggle_weapon() -> void:
	equipped = not equipped
	if not equipped:
		reloading = false
		reload_time = 0.0
		_fire_requested = false

func start_reload() -> void:
	if equipped and draw_amount > 0.95 and not reloading:
		reloading = true
		reload_time = 0.0

func _process_modification() -> void:
	advance_weapon(get_process_delta_time())

func advance_weapon(delta: float) -> void:
	var state := _advance_state(delta, player)
	var support_weight: float = state.support_weight
	var reload_phase: float = state.reload_phase

	var sk := get_skeleton()
	var head_pose := sk.get_bone_global_pose(_bone("Head"))
	var eye: Vector3 = sk.global_transform * head_pose * look_controller.eye_center.position
	weapon.visible = draw_amount > 0.01

	var reflex_weight: float = body_environment.get_collision_reflex_weight()
	_update_side_squeeze_arm_weight(delta, body_environment, reflex_weight)

	if draw_amount <= 0.0:
		_update_holstered_pose(delta, sk, player, body_environment)
		return

	var influence_amount := smoothstep(0.0, 1.0, draw_amount)
	_apply_authored_arm_pose(sk, influence_amount, support_weight, reload_phase)
	var animated_hand_offset := _get_animated_hand_offset(sk, player, delta)

	var offset: Vector3 = settings.low_ready_position.lerp(settings.aim_position, aim_amount)
	offset += Vector3(0.0, -obstruction.emergency_drop, obstruction.compression)
	offset.y -= settings.sprint_lowering * smoothstep(0.0, 1.0, _sprint_hand_release)

	var reload_pose_weight := smoothstep(0.0, 0.15, reload_phase) * (1.0 - smoothstep(0.85, 1.0, reload_phase)) if reloading else 0.0
	offset = offset.lerp(settings.reload_position, reload_pose_weight)
	var pitch: float = deg_to_rad(settings.low_ready_pitch_degrees) * (1.0 - aim_amount)
	pitch = lerpf(pitch, deg_to_rad(-8.0), reload_pose_weight)

	var view_basis: Basis = look_controller.get_weapon_view_basis()
	var gun_basis: Basis = view_basis * Basis.from_euler(Vector3(pitch, 0, 0.25 * reload_pose_weight))
	var target_pose := Transform3D(gun_basis, eye + view_basis * offset)
	target_pose *= _get_aim_step_motion(player, delta)
	target_pose *= stress_controller.get_weapon_sway(player.get_step_phase())
	weapon.global_transform = _holster.global_transform.interpolate_with(target_pose, influence_amount) * _authored_weapon
	weapon.global_position += animated_hand_offset * influence_amount

	var free_looking: bool = look_controller.is_free_looking()
	if free_looking:
		weapon.global_transform = look_controller.get_free_weapon_pose()
		weapon.global_transform *= Transform3D(Basis(Vector3.RIGHT, deg_to_rad(settings.low_ready_pitch_degrees) * obstruction.amount), Vector3(0, -settings.blocked_free_look_drop * obstruction.amount, 0))

	_fit_weapon_to_arm_reach(sk, support_weight, free_looking)
	_update_camera_alignment(eye, view_basis, free_looking, delta)
	rest_weapon_pose = weapon.global_transform

	var recoil_eye: Vector3 = look_controller.get_recoil_eye_position(eye)
	_apply_recoil_pose(recoil_eye)
	_process_buffered_shot(recoil_eye)
	_solve_grip_ik(sk, player, influence_amount, support_weight, reload_phase, reflex_weight)
	_solve_door_hand(sk, player, delta)

## Обновляет независимые таймеры и состояния до расчёта позы оружия.
func _advance_state(delta: float, player: CharacterBody3D) -> Dictionary:
	if is_instance_valid(flashlight):
		if not equipped:
			flashlight_enabled = false
		flashlight.visible = equipped and draw_amount > 0.95 and flashlight_enabled
		flashlight.light_energy = settings.flashlight_energy
		flashlight.spot_range = settings.flashlight_range
		flashlight.spot_angle = settings.flashlight_angle
	_update_aim_turn_lag(delta, equipped and aim_pressed and not reloading and not look_controller.is_free_looking())
	_pose_time += delta
	firearm.advance(delta)
	recoil.advance(delta)
	draw_amount = move_toward(draw_amount, 1.0 if equipped else 0.0, delta / maxf(settings.draw_duration, 0.01))
	# Во время перезарядки Player сам ограничивает sprint скоростью jogging.
	var sprinting: bool = player.is_sprinting() and not reloading
	_sprint_hand_release = move_toward(_sprint_hand_release, 1.0 if sprinting else 0.0, delta / maxf(settings.sprint_hand_transition_duration, 0.01))
	var door_hand_busy: bool = door_interaction.is_support_hand_busy()
	var door_transition: float = door_interaction.settings.support_hand_transition
	_door_hand_release = move_toward(_door_hand_release, 1.0 if door_hand_busy else 0.0, delta / maxf(door_transition, 0.01))
	var support_weight := (1.0 - smoothstep(0.0, 1.0, _sprint_hand_release)) * (1.0 - smoothstep(0.0, 1.0, _door_hand_release))
	var emergency_stance_amount: float = 1.0 if aim_pressed else aim_amount
	_advance_obstruction(delta, equipped and draw_amount > 0.01, emergency_stance_amount)
	var can_raise := equipped and draw_amount > 0.95 and not reloading and not sprinting
	var raised_target: float = (1.0 if aim_pressed else settings.high_ready_amount if high_ready else 0.0) if can_raise else 0.0
	aim_amount = move_toward(aim_amount, raised_target, delta / maxf(settings.aim_duration, 0.01))
	if reloading:
		reload_time += delta
		if reload_time >= settings.reload_duration:
			reloading = false
			firearm.refill()
	var reload_phase: float = clampf(reload_time / maxf(settings.reload_duration, 0.01), 0.0, 1.0) if reloading else 0.0
	magazine_offset = _magazine_curve(reload_phase) * settings.magazine_travel
	# Двигаем исходные кости магазина и затвора, не затрагивая геометрию модели.
	_gun_skeleton.set_bone_pose_position(_mag_idx, _mag_rest + Vector3(0, 0, -magazine_offset / 1.25))
	var slide_pull := sin(clampf((reload_phase - 0.76) / 0.18, 0.0, 1.0) * PI) if reloading else 0.0
	var firing_slide: float = firearm.get_cooldown_ratio()
	_gun_skeleton.set_bone_pose_position(_slide_idx, _slide_rest + Vector3(0, maxf(slide_pull, firing_slide) * settings.slide_travel / 1.25, 0))
	return {"support_weight": support_weight, "reload_phase": reload_phase}

func _update_holstered_pose(delta: float, sk: Skeleton3D, player: CharacterBody3D, environment) -> void:
	_fire_requested = false
	look_controller.set_aim_camera_offset(Vector3.ZERO, delta, settings.aim_camera_alignment_speed)
	if is_instance_valid(environment) and _side_squeeze_arm_weight > 0.0001 and not _side_squeeze_arm_side.is_empty():
		_solve_arm(sk, _side_squeeze_arm_side, _side_squeeze_arm_target(sk, player, _side_squeeze_arm_side), _side_squeeze_arm_weight, Vector3.DOWN, true)
	_solve_door_hand(sk, player, delta)

func _apply_authored_arm_pose(sk: Skeleton3D, influence_amount: float, support_weight: float, reload_phase: float) -> void:
	for bone in _arm_bones:
		var idle := _sample("Pistol_Idle", bone, fmod(_pose_time, 1.66667), sk.get_bone_pose_rotation(bone))
		var target := idle.slerp(_sample("Pistol_Aim_Neutral", bone, 0.0, idle), aim_amount)
		if reloading:
			var clip: Animation = _clips["Pistol_Reload"].animation
			var reload_weight := smoothstep(0.0, 0.12, reload_phase) * (1.0 - smoothstep(0.88, 1.0, reload_phase))
			target = target.slerp(_sample("Pistol_Reload", bone, reload_phase * clip.length, target), reload_weight)
		var bone_weight: float = influence_amount * (support_weight if bone in _left_arm_bones else 1.0)
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(target, bone_weight))

func _get_animated_hand_offset(sk: Skeleton3D, player: CharacterBody3D, delta: float) -> Vector3:
	var animated_hand_center: Vector3 = (
		sk.global_transform * sk.get_bone_global_pose(_bone("RightHand")).origin
		+ sk.global_transform * sk.get_bone_global_pose(_bone("LeftHand")).origin
	) * 0.5
	if not _animated_hand_center_initialized:
		_animated_hand_center_filtered = animated_hand_center
		_animated_hand_center_initialized = true
	var animated_hand_offset: Vector3 = (animated_hand_center - _animated_hand_center_filtered).limit_length(settings.animated_hand_follow_limit) * settings.animated_hand_follow_strength
	_animated_hand_center_filtered = _animated_hand_center_filtered.lerp(animated_hand_center, 1.0 - exp(-settings.animated_hand_follow_filter_speed * delta))
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	animated_hand_offset *= 1.0 - smoothstep(0.05, player.movement_settings.walk_speed, horizontal_speed)
	# В ready сохраняем дыхание рук, а в ADS даём прицельной линии стабилизироваться.
	animated_hand_offset *= 1.0 - smoothstep(0.75, 1.0, aim_amount) * 0.85
	return animated_hand_offset

func _get_aim_step_motion(player: CharacterBody3D, delta: float) -> Transform3D:
	var speed: float = Vector2(player.get_real_velocity().x, player.get_real_velocity().z).length()
	var grounded_and_moving: bool = player.is_on_floor() and speed > 0.08
	var desired_weight: float = 1.0 if aim_amount > 0.8 and grounded_and_moving else 0.0
	_aim_step_motion_weight = lerpf(_aim_step_motion_weight, desired_weight, 1.0 - exp(-settings.aim_step_motion_transition_speed * delta))
	if _aim_step_motion_weight < 0.0001:
		return Transform3D.IDENTITY
	var fast_weight: float = 1.0 if player.is_aim_fast_walking() else 0.0
	var position_amplitude: Vector3 = settings.aim_slow_step_position.lerp(settings.aim_fast_step_position, fast_weight)
	var rotation_amplitude: Vector3 = settings.aim_slow_step_rotation_degrees.lerp(settings.aim_fast_step_rotation_degrees, fast_weight) * (PI / 180.0)
	var phase: float = player.get_step_phase()
	# Полупериод отвечает за перенос веса между ногами, полный — за каждый шаг.
	var wave := Vector3(sin(phase * 0.5), -absf(sin(phase)), cos(phase * 0.5))
	var position := wave * position_amplitude * _aim_step_motion_weight
	var angles := Vector3(wave.y, wave.x, wave.z) * rotation_amplitude * _aim_step_motion_weight
	return Transform3D(Basis.from_euler(angles), position)

func _fit_weapon_to_arm_reach(sk: Skeleton3D, support_weight: float, free_looking: bool) -> void:
	for pass_index in range(0 if free_looking else 3):
		for side in ["Right", "Left"]:
			var shoulder := sk.global_transform * sk.get_bone_global_pose(_bone(side + "UpperArm")).origin
			var reach := _arm_length(sk, side) * 0.98
			var grip: Marker3D = _grip(side)
			var vector := grip.global_position - shoulder
			if vector.length() > reach:
				weapon.global_position -= vector.normalized() * (vector.length() - reach) * (support_weight if side == "Left" else 1.0)

func _update_camera_alignment(eye: Vector3, view_basis: Basis, free_looking: bool, delta: float) -> void:
	var camera_offset := Vector3.ZERO
	var alignment_weight := smoothstep(0.90, 1.0, aim_amount) if not free_looking else 0.0
	if alignment_weight > 0.0:
		var sight: Marker3D = _sight
		var view_forward := -look_controller.global_basis.z.normalized()
		var eye_to_sight := sight.global_position - eye
		var lateral_offset := eye_to_sight - view_forward * eye_to_sight.dot(view_forward)
		camera_offset = lateral_offset.limit_length(settings.max_aim_camera_offset) * alignment_weight
		camera_offset += (view_basis.x * _aim_turn_lag.x + view_basis.y * _aim_turn_lag.y) * alignment_weight
	look_controller.set_aim_camera_offset(camera_offset, delta, settings.aim_camera_alignment_speed)

func _process_buffered_shot(recoil_eye: Vector3) -> void:
	if _fire_requested:
		# Запоминаем один ранний клик и выполняем его сразу после завершения интервала.
		if firearm.is_cooled_down():
			_fire_requested = false
			try_fire()
			_apply_recoil_pose(recoil_eye)

func _solve_grip_ik(sk: Skeleton3D, player: CharacterBody3D, influence_amount: float, support_weight: float, reload_phase: float, reflex_weight: float) -> void:
	for side in ["Right", "Left"]:
		var grip: Marker3D = _grip(side)
		var target := grip.global_transform
		if side == "Left":
			var roll_world := weapon.global_basis * Basis(Vector3.BACK, deg_to_rad(settings.left_grip_roll_degrees)) * weapon.global_basis.inverse()
			target.basis = roll_world * target.basis
		if side == "Left" and reloading:
			var mag_target: Transform3D = _magazine_grip.global_transform
			mag_target.origin += weapon.global_basis * Vector3(0, -magazine_offset, 0)
			mag_target.basis = target.basis
			var release := smoothstep(0.05, 0.18, reload_phase) * (1.0 - smoothstep(0.78, 0.95, reload_phase))
			target = target.interpolate_with(mag_target, release)
		if side == "Left" and reflex_weight > 0.0001:
			target = target.interpolate_with(_collision_brace_target(sk, player, side), reflex_weight)
		var grip_weight: float = influence_amount * (support_weight if side == "Left" else 1.0)
		if grip_weight > 0.0001:
			var brace_pole := _collision_brace_pole(sk, player, side) if side == "Left" and reflex_weight > 0.0001 else Vector3.ZERO
			_solve_arm(sk, side, target, grip_weight, brace_pole)
			if side == "Left" and reflex_weight < 0.5:
				_apply_support_hand_grip(sk, grip_weight)

func _solve_door_hand(sk: Skeleton3D, player: CharacterBody3D, delta: float) -> void:
	var interaction = player.door_interaction
	if not is_instance_valid(interaction) or not is_instance_valid(interaction.controlled_door) or _door_hand_release <= 0.0001:
		_door_hand_pose_initialized = false
		_update_door_torso_reach(sk, Vector3.ZERO, delta, interaction)
		return
	var shoulder: Vector3 = sk.global_transform * sk.get_bone_global_pose(_bone("LeftUpperArm")).origin
	var arm_reach: float = _arm_length(sk, "Left") - interaction.settings.hand_reach_margin
	var maximum_reach: float = arm_reach + interaction.settings.torso_reach_extension
	var marker: Marker3D = interaction.controlled_door.get_hand_target_for_reach(shoulder, maximum_reach)
	var handle_target: Marker3D = interaction.controlled_door.get_control_handle_target()
	var handle_vector: Vector3 = handle_target.global_position - shoulder
	var desired_torso_offset := Vector3.ZERO
	if marker == handle_target and handle_vector.length() > arm_reach:
		desired_torso_offset = handle_vector.normalized() * minf(handle_vector.length() - arm_reach, interaction.settings.torso_reach_extension)
	_update_door_torso_reach(sk, desired_torso_offset, delta, interaction)
	shoulder = sk.global_transform * sk.get_bone_global_pose(_bone("LeftUpperArm")).origin
	var hand: Transform3D = sk.global_transform * sk.get_bone_global_pose(_bone("LeftHand"))
	var desired := hand
	desired.origin = marker.global_position
	if not _door_hand_pose_initialized:
		_door_hand_pose = hand
		_door_hand_pose_initialized = true
	var response: float = 1.0 - exp(-interaction.settings.hand_target_transition_speed * delta)
	_door_hand_pose.origin = _door_hand_pose.origin.lerp(desired.origin, response)
	_door_hand_pose.basis = hand.basis
	var weight := smoothstep(0.0, 1.0, _door_hand_release)
	var pole := (_collision_brace_outward(sk, "Left") * 0.7 + Vector3.DOWN * 0.5).normalized()
	_solve_arm(sk, "Left", _door_hand_pose, weight, pole)

func _update_door_torso_reach(sk: Skeleton3D, desired_world_offset: Vector3, delta: float, interaction) -> void:
	var speed: float = interaction.settings.torso_reach_transition_speed if is_instance_valid(interaction) else 9.0
	_door_torso_offset = _door_torso_offset.lerp(desired_world_offset, 1.0 - exp(-speed * delta))
	if _door_torso_offset.length_squared() < 0.000001:
		_door_torso_offset = Vector3.ZERO
		return
	var spine := _bone("Spine")
	if spine < 0:
		return
	var pose := sk.get_bone_global_pose(spine)
	pose.origin += sk.global_basis.inverse() * _door_torso_offset
	sk.set_bone_global_pose(spine, pose)

func _apply_collision_brace(sk: Skeleton3D, player: CharacterBody3D, side: String, weight: float) -> void:
	_solve_arm(sk, side, _collision_brace_target(sk, player, side), weight, _collision_brace_pole(sk, player, side))

func _collision_brace_target(sk: Skeleton3D, player: CharacterBody3D, side: String) -> Transform3D:
	var upper := _bone(side + "UpperArm")
	var hand := _bone(side + "Hand")
	var shoulder_world: Vector3 = sk.global_transform * sk.get_bone_global_pose(upper).origin
	var hand_world_pose: Transform3D = sk.global_transform * sk.get_bone_global_pose(hand)
	var environment = body_environment
	var forward: Vector3 = environment.collision_reflex_direction.normalized()
	if forward.length_squared() < 0.001:
		forward = player.global_basis.z.normalized()
	var reach: float = _arm_length(sk, side) * environment.settings.reflex_arm_reach
	if is_finite(environment.collision_reflex_contact_distance):
		reach = minf(reach, maxf(environment.collision_reflex_contact_distance - 0.08, 0.15))
	var outward := _collision_brace_outward(sk, side)
	hand_world_pose.origin = shoulder_world + forward * reach + Vector3.DOWN * environment.settings.reflex_hand_drop + outward * environment.settings.reflex_hand_outset
	return hand_world_pose

func _collision_brace_pole(sk: Skeleton3D, player: CharacterBody3D, side: String) -> Vector3:
	var outward := _collision_brace_outward(sk, side)
	return (outward * 0.65 + Vector3.DOWN * 0.76).normalized()

func _side_squeeze_arm_target(sk: Skeleton3D, player: CharacterBody3D, side: String) -> Transform3D:
	var upper := _bone(side + "UpperArm")
	var hand := _bone(side + "Hand")
	var shoulder_world: Vector3 = sk.global_transform * sk.get_bone_global_pose(upper).origin
	var target: Transform3D = sk.global_transform * sk.get_bone_global_pose(hand)
	var environment = body_environment
	var outward := _collision_brace_outward(sk, side)
	target.origin = shoulder_world + Vector3.DOWN * (_arm_length(sk, side) * 0.985) + player.global_basis.z * 0.025 + outward * environment.settings.side_arm_outset
	return target

func _update_side_squeeze_arm_weight(delta: float, environment, reflex_weight: float) -> void:
	var desired_weight := 0.0
	var desired_side := ""
	if is_instance_valid(environment) and draw_amount <= 0.0 and reflex_weight <= 0.05:
		var squeeze_ratio: float = clampf(absf(environment.wall_squeeze_angle) / maxf(deg_to_rad(environment.settings.max_torso_yaw_degrees), 0.001), 0.0, 1.0)
		desired_weight = squeeze_ratio * environment.settings.side_arm_straightening
		if desired_weight > 0.0001:
			desired_side = "Left" if environment.wall_squeeze_angle > 0.0 else "Right"
	if _side_squeeze_arm_side.is_empty() and not desired_side.is_empty():
		_side_squeeze_arm_side = desired_side
	elif not desired_side.is_empty() and desired_side != _side_squeeze_arm_side:
		# Fade the old side out before changing arms, otherwise the IK target
		# jumps across the body when probes swap sides near a doorway.
		desired_weight = 0.0
	var duration: float = environment.settings.side_pose_blend_in if is_instance_valid(environment) and desired_weight > _side_squeeze_arm_weight else environment.settings.side_pose_blend_out if is_instance_valid(environment) else 0.25
	_side_squeeze_arm_weight = move_toward(_side_squeeze_arm_weight, desired_weight, delta / maxf(duration, 0.01))
	if _side_squeeze_arm_weight <= 0.0001:
		_side_squeeze_arm_weight = 0.0
		_side_squeeze_arm_side = desired_side

func _collision_brace_outward(sk: Skeleton3D, side: String) -> Vector3:
	var shoulder: Vector3 = sk.global_transform * sk.get_bone_global_pose(_bone(side + "UpperArm")).origin
	var other_side := "Left" if side == "Right" else "Right"
	var other_shoulder: Vector3 = sk.global_transform * sk.get_bone_global_pose(_bone(other_side + "UpperArm")).origin
	return (shoulder - other_shoulder).normalized()

func _apply_support_hand_grip(sk: Skeleton3D, weight: float) -> void:
	var base_angle := deg_to_rad(settings.left_finger_curl_degrees) * weight
	for finger in ["Index", "Middle", "Ring", "Little"]:
		for segment in ["Proximal", "Intermediate", "Distal"]:
			var bone := _bone("Left" + finger + segment)
			if bone < 0: continue
			var multiplier := 0.75 if segment == "Proximal" else 1.0 if segment == "Intermediate" else 0.55
			sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, base_angle * multiplier))
	for segment in ["Metacarpal", "Proximal", "Distal"]:
		var thumb := _bone("LeftThumb" + segment)
		if thumb >= 0:
			sk.set_bone_pose_rotation(thumb, sk.get_bone_pose_rotation(thumb) * Quaternion(Vector3.RIGHT, base_angle * 0.28))

func _advance_obstruction(delta: float, enabled: bool, stance_amount: float) -> void:
	var sk := get_skeleton()
	var eye: Vector3 = sk.global_transform * sk.get_bone_global_pose(_bone("Head")) * look_controller.eye_center.position
	var view_basis: Basis = look_controller.get_weapon_view_basis()
	var stance_offset: Vector3 = settings.low_ready_position.lerp(settings.aim_position, stance_amount)
	var stance_pitch: float = deg_to_rad(settings.low_ready_pitch_degrees) * (1.0 - stance_amount)
	var stance_basis: Basis = view_basis * Basis.from_euler(Vector3(stance_pitch, 0.0, 0.0))
	var aim_pose: Transform3D = Transform3D(stance_basis, eye + view_basis * stance_offset) * _authored_weapon
	if look_controller.is_free_looking():
		aim_pose = look_controller.get_free_weapon_pose()
	var muzzle_point: Vector3 = aim_pose * firearm.muzzle.position
	var left_hand_point: Vector3 = aim_pose * _grip_left.position
	var right_hand_point: Vector3 = aim_pose * _grip_right.position
	obstruction.advance(delta, eye, [muzzle_point, left_hand_point, right_hand_point], enabled, stance_amount)

func _apply_recoil_pose(eye: Vector3) -> void:
	weapon.global_transform = recoil.apply_to_pose(rest_weapon_pose, eye)

func compensate_recoil_pitch(pitch_delta: float) -> float:
	return recoil.compensate_pitch(pitch_delta, equipped and not look_controller.is_free_looking())

func compensate_recoil_yaw(yaw_delta: float) -> float:
	return recoil.compensate_yaw(yaw_delta, equipped and not look_controller.is_free_looking())

func try_fire() -> bool:
	if not firearm.can_fire(equipped, draw_amount, reloading, player.is_sprinting()):
		return false
	var sk := get_skeleton()
	var chest: Vector3 = sk.global_transform * sk.get_bone_global_pose(_bone("UpperChest")).origin
	var result := firearm.fire(player, chest)
	if result.is_empty():
		return false
	recoil.apply_shot_impulse()
	return true

func _on_firearm_shot_fired(origin: Vector3, direction: Vector3, hit: Dictionary) -> void:
	shot_fired.emit(origin, direction, hit)

func _sample(clip_name: String, bone: int, time: float, fallback: Quaternion) -> Quaternion:
	var data: Dictionary = _clips[clip_name]
	if not data.tracks.has(bone): return fallback
	return data.animation.rotation_track_interpolate(data.tracks[bone], time)

func _arm_length(sk: Skeleton3D, side: String) -> float:
	var upper := sk.get_bone_global_pose(_bone(side + "UpperArm")).origin
	var elbow := sk.get_bone_global_pose(_bone(side + "LowerArm")).origin
	var hand := sk.get_bone_global_pose(_bone(side + "Hand")).origin
	return upper.distance_to(elbow) + elbow.distance_to(hand)

func _solve_arm(sk: Skeleton3D, side: String, world_target: Transform3D, weight: float, pole_hint_world: Vector3 = Vector3.ZERO, blend_joint_rotations: bool = false) -> void:
	var upper := _bone(side + "UpperArm")
	var lower := _bone(side + "LowerArm")
	var hand := _bone(side + "Hand")
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(lower).origin
	var c := sk.get_bone_global_pose(hand).origin
	var full_target: Vector3 = sk.global_transform.affine_inverse() * world_target.origin
	var target: Vector3 = full_target if blend_joint_rotations else c.lerp(full_target, weight)
	var length_a := a.distance_to(b)
	var length_b := b.distance_to(c)
	var distance := clampf(a.distance_to(target), 0.01, length_a + length_b - 0.001)
	var direction := (target - a).normalized()
	var pole := sk.global_basis.inverse() * pole_hint_world if pole_hint_world.length_squared() > 0.001 else b - (a + c) * 0.5
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 0.0001:
		pole = Vector3(-0.7 if side == "Right" else 0.7, -1, 0)
		pole -= direction * pole.dot(direction)
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2.0 * distance)
	var elbow := a + direction * along + pole.normalized() * sqrt(maxf(length_a * length_a - along * along, 0.0))
	_rotate_bone(sk, upper, b - a, elbow - a, weight if blend_joint_rotations else 1.0)
	b = sk.get_bone_global_pose(lower).origin
	c = sk.get_bone_global_pose(hand).origin
	_rotate_bone(sk, lower, c - b, target - b, weight if blend_joint_rotations else 1.0)
	var hand_pose := sk.get_bone_global_pose(hand)
	var desired_basis := sk.global_basis.inverse() * world_target.basis
	hand_pose.basis = Basis(hand_pose.basis.get_rotation_quaternion().slerp(desired_basis.get_rotation_quaternion(), weight))
	sk.set_bone_global_pose(hand, hand_pose)

func _rotate_bone(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3, weight: float = 1.0) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001: return
	var pose := sk.get_bone_global_pose(bone)
	var desired_basis := Basis(Quaternion(from.normalized(), to.normalized())) * pose.basis
	pose.basis = Basis(pose.basis.get_rotation_quaternion().slerp(desired_basis.get_rotation_quaternion(), clampf(weight, 0.0, 1.0)))
	sk.set_bone_global_pose(bone, pose)

func _magazine_curve(phase: float) -> float:
	return smoothstep(0.16, 0.35, phase) * (1.0 - smoothstep(0.52, 0.72, phase))
