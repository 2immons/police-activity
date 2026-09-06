class_name BodycamOverlaySettings
extends Resource

@export_group("Watermark")
@export var overlay_enabled: bool = true
@export var camera_label: String = "AXON BODY 3"
@export var camera_id: String = "X60317001"
@export var use_local_time: bool = true
@export var first_person_only: bool = false
@export_range(0.0, 1.0) var watermark_opacity: float = 0.95
@export_group("Digital camera")
@export var effects_enabled: bool = true
@export_range(0.0, 0.2) var lens_distortion: float = 0.055
@export_range(0.0, 0.5) var vignette_strength: float = 0.16
@export_range(0.0, 0.05) var sensor_noise: float = 0.012
@export_range(0.0, 0.003) var chromatic_aberration: float = 0.00045
@export_range(0.0, 1.5) var saturation: float = 0.88
@export_range(0.5, 1.5) var contrast: float = 1.04
@export_range(0.5, 1.5) var exposure: float = 1.0
@export_range(0.0, 1.0) var compression_strength: float = 0.10
## Lightweight camera-turn motion blur. Zero disables it; no object velocity buffer.
@export_range(0.0, 1.0) var motion_smear: float = 0.25
@export_range(0.0, 0.01) var rolling_shutter: float = 0.0015
@export_range(10.0, 60.0) var noise_refresh_rate: float = 30.0
