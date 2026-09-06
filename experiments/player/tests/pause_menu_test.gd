extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://experiments/player/test_scene.tscn").instantiate()
	assert(scene.has_node("PauseMenu/Backdrop/Center/Panel/Content/Resume"))
	root.add_child(scene)
	await process_frame
	var menu = scene.get_node("PauseMenu")
	var weapon = scene.get_node("Player").weapon_controller
	weapon.aim_pressed = true
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	assert(paused and menu.panel.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	assert(not weapon.aim_pressed)
	escape.echo = true
	root.push_input(escape)
	assert(paused, "Key repeat must not close the menu")
	escape.echo = false
	root.push_input(escape)
	assert(not paused and not menu.panel.visible)
	menu.set_menu_open(true)
	menu.resume_button.pressed.emit()
	assert(not paused and not menu.panel.visible)
	print("PASS: reusable pause menu, Escape, mouse release, repeat guard, resume and held input reset")
	quit()
