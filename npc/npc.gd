class_name NPC
extends CharacterBody3D

signal died(zone: String, hit_position: Vector3)
signal hit_reacted(zone: String, bone_name: StringName)

@export var settings: NpcReactionSettings = preload("res://npc/npc_settings.tres")
@export var escape_point: Marker3D
@export var break_los_points: Array[Marker3D] = []
@onready var animation_player: AnimationPlayer = $UAL1_Standard/AnimationPlayer
@onready var skeleton: Skeleton3D = $UAL1_Standard/Armature/GeneralSkeleton
@onready var simulator: PhysicalBoneSimulator3D = $UAL1_Standard/Armature/GeneralSkeleton/PhysicalBoneSimulator3D
@onready var hit_reaction: SkeletonModifier3D = $UAL1_Standard/Armature/GeneralSkeleton/NpcHitReaction
@onready var weapon: Node3D = $WeaponRig/Glock17
@onready var muzzle: Marker3D = $WeaponRig/Glock17/Muzzle
@onready var body_collision: CollisionShape3D = $BodyCollision
@onready var shot_audio: AudioStreamPlayer3D = $WeaponRig/Glock17/ShotAudio
@onready var muzzle_flash: Node3D = $WeaponRig/Glock17/Muzzle/Flash
@onready var ai_controller: NpcAIController = $AIController
@onready var bt_player: BTPlayer = $BTPlayer
@onready var suspect_mind: LimboSuspectMind = $SuspectMind

var dead := false
var chest_hits := 0
var last_hit_zone := ""
var ai_active := false
var _target: CharacterBody3D
var _flash_time := 0.0

func _ready() -> void:
	hit_reaction.settings = settings
	simulator.active = false
	animation_player.play("Idle")
	ai_controller.tactical_query.escape_point = escape_point
	ai_controller.debug_label = $AIDebugLabel
	ai_controller.perception.eye_origin = $Sensors/EyeOrigin
	ai_controller.movement.navigation_agent = $NavigationAgent3D
	ai_controller.configure(self, bt_player.blackboard)
	bt_player.active = false
	for physical_bone in simulator.get_children():
		if physical_bone is PhysicalBone3D:
			physical_bone.collision_layer = 0
			physical_bone.linear_damp = settings.ragdoll_linear_damp
			physical_bone.angular_damp = settings.ragdoll_angular_damp
	call_deferred("_acquire_target")

func _physics_process(delta: float) -> void:
	_flash_time = maxf(_flash_time - delta, 0.0)
	muzzle_flash.visible = _flash_time > 0.0
	if dead or not ai_active:
		return
	if not is_instance_valid(_target):
		_acquire_target()
	ai_controller.advance_memory(delta)
	ai_controller.perception.advance(delta)
	ai_controller.aim.advance(delta)
	ai_controller.weapon.advance(delta)
	ai_controller.tactical_query.advance()
	suspect_mind.advance(delta, self)
	publish_mind_to_blackboard()
	if ai_controller.movement.active:
		ai_controller.movement.advance(delta)
	ai_controller.animation.advance()
	_update_suspect_debug()

func set_ai_active(value: bool) -> void:
	if dead:
		return
	ai_active = value
	bt_player.active = value
	if value:
		suspect_mind.force_reevaluate(self)
		publish_mind_to_blackboard()
	else:
		ai_controller.movement.stop(&"AI_DISABLED")
		velocity = Vector3.ZERO
		play_locomotion(&"Idle")

func desired_action() -> StringName:
	return suspect_mind.desired_action

func select_break_los_point() -> Marker3D:
	var best: Marker3D
	var best_score := -INF
	var threat := ai_controller.known_threat_position()
	for point in break_los_points:
		if not is_instance_valid(point):
			continue
		var score := (1.5 if not _point_visible_from_threat(point.global_position, threat) else 0.0)
		score += point.global_position.distance_to(threat) * 0.06
		score -= global_position.distance_to(point.global_position) * 0.08
		if score > best_score:
			best_score = score
			best = point
	return best

func _point_visible_from_threat(point: Vector3, threat: Vector3) -> bool:
	if threat == Vector3.ZERO:
		return false
	var query := PhysicsRayQueryParameters3D.create(threat + Vector3.UP * 1.3, point + Vector3.UP * 1.2, 0xffffffff, get_damage_collision_rids())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func publish_mind_to_blackboard() -> void:
	var board := ai_controller.blackboard
	board.set_var(&"escape_point", escape_point)
	board.set_var(&"selected_break_los_point", suspect_mind.selected_break_los_point)
	board.set_var(&"desired_action", suspect_mind.desired_action)
	board.set_var(&"under_fire", float(board.get_var(&"suppression", 0.0)) > 0.1)

func _update_suspect_debug() -> void:
	var board := ai_controller.blackboard
	$AIDebugLabel.text = "desired: %s | BT: %s\nofficer visible: %s | memory: %.1fs\nescape viability: %.2f | blocked: %s\nESC %.2f  FIRE_ESC %.2f\nBLUE desired | RED muzzle/shot | YELLOW last seen | PURPLE move" % [
		suspect_mind.desired_action, board.get_var(&"current_action", &"IDLE"), board.get_var(&"can_see_target", false),
		board.get_var(&"time_since_target_seen", INF),
		board.get_var(&"escape_route_viability", 0.0), board.get_var(&"escape_route_threatened", false),
		suspect_mind.scores.get(&"ESCAPE", 0.0), suspect_mind.scores.get(&"FIRE_TO_ESCAPE", 0.0),
	]

func play_locomotion(clip: StringName) -> void:
	_play_locomotion(clip)

func get_physical_bone(bone_name: StringName) -> PhysicalBone3D:
	return _physical_bone_for(bone_name)

func set_muzzle_flash_time(duration: float) -> void:
	_flash_time = maxf(_flash_time, duration)

func _acquire_target() -> void:
	_target = get_tree().get_first_node_in_group("controllable_player") as CharacterBody3D
	if is_instance_valid(ai_controller):
		ai_controller.set_target(_target)

func _play_locomotion(clip: String) -> void:
	if animation_player.current_animation != clip:
		animation_player.play(clip, 0.2)

func receive_suppression(origin: Vector3, closest_point: Vector3, amount: float = 0.35) -> void:
	if not dead and is_instance_valid(ai_controller):
		ai_controller.register_incoming_fire(origin, closest_point, amount)

func receive_heard_stimulus(position: Vector3, confidence: float = 1.0) -> void:
	if not dead and is_instance_valid(ai_controller):
		ai_controller.register_heard_stimulus(position, confidence)

func get_damage_collision_rids() -> Array[RID]:
	var result: Array[RID] = [get_rid()]
	for attachment in get_tree().get_nodes_in_group("npc_hit_zone_attachment"):
		if skeleton.is_ancestor_of(attachment):
			for child in attachment.get_children():
				if child is CollisionObject3D:
					result.append(child.get_rid())
	return result

func receive_zone_hit(zone: String, bone_name: StringName, _damage: float, hit_position: Vector3, direction: Vector3) -> void:
	if dead:
		return
	receive_suppression(hit_position - direction * 4.0, hit_position, 0.55)
	last_hit_zone = zone
	var lethal := zone == "HEAD"
	if zone == "CHEST":
		chest_hits += 1
		lethal = chest_hits >= settings.chest_hits_to_kill
	if lethal:
		_die(zone, bone_name, hit_position, direction)
		return
	hit_reaction.add_impulse(bone_name, direction, settings.limb_impulse)
	if zone in ["LEFT_ARM", "RIGHT_ARM", "LEFT_LEG", "RIGHT_LEG"]:
		hit_reaction.add_impulse(&"UpperChest", direction, settings.limb_impulse * settings.torso_transfer)
	hit_reacted.emit(zone, bone_name)

# Используется для уже подтверждённой смерти, например для player-ragdoll surrogate.
func force_ragdoll(zone: String, bone_name: StringName, hit_position: Vector3, direction: Vector3) -> void:
	if dead:
		return
	_die(zone, bone_name, hit_position, direction)

func receive_bullet_hit(damage: float, hit_position: Vector3, direction: Vector3) -> void:
	var local := to_local(hit_position)
	if local.y > 1.48:
		receive_zone_hit("HEAD", &"Head", damage, hit_position, direction)
	elif local.y > 0.95 and absf(local.x) > 0.24:
		var left := local.x > 0.0
		receive_zone_hit("LEFT_ARM" if left else "RIGHT_ARM", &"LeftUpperArm" if left else &"RightUpperArm", damage, hit_position, direction)
	elif local.y > 0.9:
		receive_zone_hit("CHEST", &"UpperChest", damage, hit_position, direction)
	else:
		var left := local.x > 0.0
		receive_zone_hit("LEFT_LEG" if left else "RIGHT_LEG", &"LeftUpperLeg" if left else &"RightUpperLeg", damage, hit_position, direction)

func _die(zone: String, bone_name: StringName, hit_position: Vector3, direction: Vector3) -> void:
	dead = true
	ai_active = false
	bt_player.active = false
	ai_controller.shutdown()
	set_physics_process(false)
	body_collision.set_deferred("disabled", true)
	animation_player.stop()
	hit_reaction.clear_reactions()
	hit_reaction.active = false
	for attachment in get_tree().get_nodes_in_group("npc_hit_zone_attachment"):
		if not skeleton.is_ancestor_of(attachment):
			continue
		for child in attachment.get_children():
			if child is NpcHitZone:
				child.set_hitbox_enabled(false)
	simulator.active = true
	for physical_bone in simulator.get_children():
		if physical_bone is PhysicalBone3D:
			physical_bone.collision_layer = 1
	simulator.physical_bones_start_simulation()
	_attach_weapon_to_ragdoll_hand()
	call_deferred("_apply_death_impulse", bone_name, hit_position, direction)
	died.emit(zone, hit_position)

func _attach_weapon_to_ragdoll_hand() -> void:
	var weapon_rig := get_node_or_null("WeaponRig") as Node3D
	var hand_bone := _physical_bone_for(&"RightLowerArm")
	if weapon_rig == null or hand_bone == null:
		return
	weapon_rig.reparent(hand_bone, true)

func _apply_death_impulse(bone_name: StringName, hit_position: Vector3, direction: Vector3) -> void:
	if not is_inside_tree():
		return
	var impacted_bone := _physical_bone_for(bone_name)
	if impacted_bone != null:
		var impulse: Vector3 = direction.normalized() * settings.death_impulse
		impacted_bone.apply_impulse(impulse, hit_position - impacted_bone.global_position)

func _physical_bone_for(bone_name: StringName) -> PhysicalBone3D:
	for child in simulator.get_children():
		if child is PhysicalBone3D and child.bone_name == bone_name:
			return child
	# Грудные hit zones используют UpperChest, а физическое ядро торса — Chest.
	if bone_name == &"UpperChest":
		return simulator.get_node_or_null("Physical Bone Chest") as PhysicalBone3D
	return simulator.get_node_or_null("Physical Bone Hips") as PhysicalBone3D
