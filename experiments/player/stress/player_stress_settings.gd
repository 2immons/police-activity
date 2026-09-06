class_name PlayerStressSettings
extends Resource

@export_group("Simulation")
## Множитель прироста стресса от близкого пролёта пули.
@export_range(0.0, 3.0, 0.05) var suppression_gain: float = 0.75
## Дополнительный импульс при фактическом попадании в тело.
@export_range(0.0, 2.0, 0.05) var hit_gain: float = 0.55
## Время в секундах после угрозы, в течение которого стресс не начинает спадать.
@export_range(0.0, 3.0, 0.05) var decay_delay: float = 0.65
## Скорость восстановления нормализованного stress amount в секунду.
@export_range(0.01, 2.0, 0.01) var decay_rate: float = 0.16
## Скорость визуального нарастания эффекта. Большие значения дают более резкую реакцию.
@export_range(1.0, 30.0, 0.5) var attack_speed: float = 14.0
## Скорость визуального возвращения после снижения simulation stress.
@export_range(0.5, 20.0, 0.5) var release_speed: float = 4.5

@export_group("Weapon sway")
## Максимальное смещение оружия в метрах при полном стрессе.
@export var weapon_position_amplitude: Vector3 = Vector3(0.010, 0.014, 0.006)
## Максимальное покачивание оружия в градусах при полном стрессе.
@export var weapon_rotation_amplitude_degrees: Vector3 = Vector3(1.15, 0.85, 0.75)
## Частота стрессового дыхания и мелкой моторики в герцах.
@export_range(0.2, 5.0, 0.05) var weapon_sway_frequency: float = 1.35
## Доля синхронизации stress sway с текущим циклом шага.
@export_range(0.0, 1.0, 0.05) var step_coupling: float = 0.35

@export_group("Screen effect")
## Максимальная непрозрачность периферийной виньетки.
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.72
## Радиус ясной центральной области экрана. Меньше — сильнее tunnel vision.
@export_range(0.1, 0.9, 0.01) var clear_center_radius: float = 0.48
## Ширина плавного перехода от ясного центра к затемнённой периферии.
@export_range(0.05, 0.8, 0.01) var vignette_softness: float = 0.34
## Максимальный уровень mip blur у краёв экрана.
@export_range(0.0, 6.0, 0.1) var edge_blur_lod: float = 3.2
## Максимальная потеря насыщенности на периферии.
@export_range(0.0, 1.0, 0.01) var desaturation: float = 0.34
## Пульсация тоннельного зрения в герцах при высоком стрессе.
@export_range(0.0, 4.0, 0.05) var pulse_frequency: float = 1.15
## Амплитуда пульсации относительно текущего stress amount.
@export_range(0.0, 0.5, 0.01) var pulse_strength: float = 0.10
