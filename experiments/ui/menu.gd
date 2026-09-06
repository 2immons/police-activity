extends CanvasLayer

@onready var panel: Control = $Backdrop
@onready var resume_button: Button = $Backdrop/Center/Panel/Content/Resume
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		set_menu_open(not panel.visible)
		get_viewport().set_input_as_handled()

func set_menu_open(open: bool) -> void:
	if panel.visible == open:
		return
	panel.visible = open
	if open:
		_previous_mouse_mode = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		resume_button.grab_focus()
	else:
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse_mode

func _on_resume_pressed() -> void:
	set_menu_open(false)

func _on_quit_pressed() -> void:
	get_tree().quit()
