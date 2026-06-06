class_name RocketConfig
extends Resource

@export_range(1.0, 200.0, 1.0) var rocket_mass: float = 20.0
@export_range(100.0, 5000.0, 10.0) var engine_thrust: float = 800.0
@export_range(0.0, 100.0, 1.0) var fuel_amount: float = 40.0
@export_range(0.05, 1.0, 0.01) var rocket_radius: float = 0.28
@export_range(0.5, 10.0, 0.1) var rocket_height: float = 3.1
@export_range(0.0, 40.0, 0.5) var wind_speed: float = 0.0
@export_range(0.0, 360.0, 1.0) var wind_direction: float = 0.0
@export_range(0, 8, 1) var fin_count: int = 0
@export_range(0.05, 1.0, 0.01) var fin_size: float = 0.2
