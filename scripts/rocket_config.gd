class_name RocketConfig
extends Resource

@export_range(1.0, 200.0, 1.0) var rocket_mass: float = 20.0
@export_range(100.0, 5000.0, 10.0) var engine_thrust: float = 800.0
@export_range(0.0, 100.0, 1.0) var fuel_amount: float = 40.0
@export_range(0.05, 1.0, 0.01) var rocket_radius: float = 0.28
@export_range(0.5, 10.0, 0.1) var rocket_height: float = 3.1
@export_range(0.0, 40.0, 0.5) var wind_speed: float = 0.0
@export_range(0.0, 360.0, 1.0) var wind_direction: float = 0.0
@export_range(0, 8, 1) var fin_count: int = 4
@export_range(0.05, 1.0, 0.01) var fin_size: float = 0.3

var fin_mesh: Mesh = null
var fin_material_name: String = "aluminum"
var fin_thickness: float = 0.04
var fin_span: float = 0.3
var fin_root_chord: float = 0.4
var fin_tip_chord: float = 0.25
var fin_surface_area: float = 0.0
