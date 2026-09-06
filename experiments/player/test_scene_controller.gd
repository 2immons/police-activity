extends Node3D

@export var npc_scene: PackedScene = preload("res://npc/npc.tscn")
@onready var interior: Node3D = $Interior
@onready var npc_spawn: Marker3D = $NpcPatrol/NpcSpawn
@onready var escape_point: Marker3D = $EscapeScenario/EscapePoint
@onready var break_los_left: Marker3D = $SuspectTacticalPoints/BreakLOSLeft
@onready var break_los_right: Marker3D = $SuspectTacticalPoints/BreakLOSRight

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		_reset_npc()
	elif event.physical_keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		get_tree().call_deferred("reload_current_scene")
	elif event.physical_keycode == KEY_F3:
		get_viewport().set_input_as_handled()
		_activate_npc()

func _reset_npc() -> void:
	var old_npc := interior.get_node_or_null("SuspectNpc")
	if old_npc != null:
		interior.remove_child(old_npc)
		old_npc.queue_free()
	var npc := npc_scene.instantiate() as NPC
	npc.name = "SuspectNpc"
	# Runtime-created replacement must receive the authored tactical context before _ready().
	npc.escape_point = escape_point
	npc.break_los_points = [break_los_left, break_los_right]
	interior.add_child(npc)
	npc.global_transform = npc_spawn.global_transform
	npc.set_ai_active(false)

func _activate_npc() -> void:
	var npc := interior.get_node_or_null("SuspectNpc") as NPC
	if npc != null:
		npc.set_ai_active(true)
