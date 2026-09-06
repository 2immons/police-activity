extends CanvasLayer

@export var look_controller: Node3D
@export var settings: Resource = preload("res://experiments/player_camera/overlay/bodycam_settings.tres")
@onready var effects: ColorRect = $Effects
@onready var watermark: Control = $Watermark
@onready var timestamp: Label = $Watermark/Timestamp
@onready var device: Label = $Watermark/Device
var _previous_view := Basis.IDENTITY
var _turn_velocity := Vector2.ZERO

func _ready() -> void:
	if is_instance_valid(look_controller): _previous_view = look_controller.global_basis.orthonormalized()
	_update_clock()
	_apply_settings()

func _process(delta: float) -> void:
	var show_view: bool = not settings.first_person_only or not is_instance_valid(look_controller) or look_controller.first_person
	watermark.visible = settings.overlay_enabled and show_view
	effects.visible = settings.effects_enabled and show_view
	if is_instance_valid(look_controller):
		var view := look_controller.global_basis.orthonormalized()
		var relative := _previous_view.inverse() * view
		var angles := relative.get_euler()
		var velocity := Vector2(-angles.y, angles.x) / maxf(delta, 0.001)
		_turn_velocity = _turn_velocity.lerp(velocity.limit_length(3.0), 1.0 - exp(-12.0 * delta))
		_previous_view = view
	_apply_settings()

func _apply_settings() -> void:
	watermark.modulate.a = settings.watermark_opacity
	device.text = "%s %s" % [settings.camera_label, settings.camera_id]
	for parameter in ["lens_distortion", "vignette_strength", "sensor_noise", "chromatic_aberration", "saturation", "contrast", "exposure", "compression_strength", "motion_smear", "rolling_shutter", "noise_refresh_rate"]:
		effects.material.set_shader_parameter(parameter, settings.get(parameter))
	effects.material.set_shader_parameter("turn_velocity", _turn_velocity)

func _update_clock() -> void:
	var offset: int = Time.get_time_zone_from_system().bias if settings.use_local_time else 0
	timestamp.text = format_timestamp(int(Time.get_unix_time_from_system()), offset)

func format_timestamp(unix_seconds: int, offset_minutes: int) -> String:
	var time := Time.get_datetime_dict_from_unix_time(unix_seconds + offset_minutes * 60)
	var zone := "%s%02d%02d" % ["+" if offset_minutes >= 0 else "-", int(absi(offset_minutes) / 60), absi(offset_minutes) % 60]
	return "%04d-%02d-%02d %02d:%02d:%02d %s" % [time.year, time.month, time.day, time.hour, time.minute, time.second, zone]
