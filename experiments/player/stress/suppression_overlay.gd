class_name SuppressionOverlay
extends CanvasLayer

@export var stress_controller: PlayerStressController
@export var settings: PlayerStressSettings = preload("res://experiments/player/stress/player_stress_settings.tres")
@onready var effect: ColorRect = $Effect

var _time: float = 0.0

func _ready() -> void:
	assert(is_instance_valid(stress_controller), "SuppressionOverlay requires PlayerStressController")
	_apply_static_settings()

func _process(delta: float) -> void:
	_time += delta
	var amount := stress_controller.get_amount()
	var pulse_gate := smoothstep(0.35, 1.0, amount)
	var pulse := (sin(_time * settings.pulse_frequency * TAU) * 0.5 + 0.5) * settings.pulse_strength * amount * pulse_gate
	effect.material.set_shader_parameter("stress_amount", amount)
	effect.material.set_shader_parameter("pulse", pulse)
	effect.visible = amount > 0.001

func _apply_static_settings() -> void:
	effect.material.set_shader_parameter("vignette_strength", settings.vignette_strength)
	effect.material.set_shader_parameter("clear_center_radius", settings.clear_center_radius)
	effect.material.set_shader_parameter("vignette_softness", settings.vignette_softness)
	effect.material.set_shader_parameter("edge_blur_lod", settings.edge_blur_lod)
	effect.material.set_shader_parameter("desaturation", settings.desaturation)
