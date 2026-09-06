class_name LimboSuspectMind
extends Node

@export var personality: SuspectPersonality = preload("res://npc/ai/aggressive_escape_personality.tres")

var desired_action: StringName = &"IDLE"
var scores: Dictionary = {}
var selected_break_los_point: Marker3D
var _reevaluate_left := 0.0
var _commitment_left := 0.0

func advance(delta: float, npc: NPC) -> void:
	_reevaluate_left -= delta
	_commitment_left = maxf(_commitment_left - delta, 0.0)
	if _reevaluate_left > 0.0:
		return
	_reevaluate_left = personality.decision_interval
	_evaluate(npc)

func force_reevaluate(npc: NPC) -> void:
	_commitment_left = 0.0
	_reevaluate_left = 0.0
	_evaluate(npc)

func _evaluate(npc: NPC) -> void:
	var board := npc.ai_controller.blackboard
	selected_break_los_point = npc.select_break_los_point()
	var visible := float(board.get_var(&"can_see_target", false))
	var route_viability: float = board.get_var(&"escape_route_viability", 0.0)
	var threat := clampf(visible * 0.65 + float(board.get_var(&"suppression", 0.0)) * 0.55, 0.0, 1.0)
	var blocked: float = board.get_var(&"escape_route_threat", 0.0)
	var armed := float(npc.ai_controller.weapon.rounds > 0)
	scores = {
		&"ESCAPE": personality.escape_drive * route_viability,
		&"FIRE_TO_ESCAPE": personality.escape_drive * personality.aggression * blocked * visible * armed * (0.55 + float(board.get_var(&"aim_quality", 0.0)) * 0.45),
		&"SURRENDER": personality.compliance * personality.self_preservation * (0.45 + threat * 0.75) * (1.0 - route_viability * 0.7),
		&"BREAK_LOS": float(is_instance_valid(selected_break_los_point)) * threat * (1.0 - route_viability) * personality.self_preservation * 0.82 * (1.0 - personality.aggression * 0.7),
		&"IDLE": 0.08 if board.get_var(&"has_escape_destination", false) else 0.35,
	}
	if scores.has(desired_action):
		scores[desired_action] += 0.08
	var candidate: StringName = &"IDLE"
	var best := -1.0
	for action: StringName in scores:
		if float(scores[action]) > best:
			candidate = action
			best = scores[action]
	var current: float = scores.get(desired_action, 0.0)
	var urgent_opening: bool = desired_action == &"FIRE_TO_ESCAPE" and not bool(board.get_var(&"escape_route_threatened", false))
	if not urgent_opening and _commitment_left > 0.0 and best < current + personality.switch_threshold:
		return
	if candidate != desired_action and (urgent_opening or best >= current + personality.switch_threshold):
		desired_action = candidate
		_commitment_left = personality.minimum_commitment
