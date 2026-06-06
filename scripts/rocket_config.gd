class_name RocketConfig
extends Resource

const FUEL_MASS_FACTOR: float = 0.15
const FIN_MASS_SCALE: float = 8.0

@export_range(1000.0, 200000.0, 100.0) var rocket_mass: float = 20000.0
@export_range(100000.0, 5000000.0, 10000.0) var engine_thrust: float = 800000.0
@export_range(0.0, 100000.0, 100.0) var fuel_amount: float = 40000.0
@export_range(0.5, 10.0, 0.1) var rocket_radius: float = 2.8
@export_range(5.0, 100.0, 1.0) var rocket_height: float = 31.0
@export_range(0.0, 40.0, 0.5) var wind_speed: float = 0.0
@export_range(0.0, 360.0, 1.0) var wind_direction: float = 0.0
@export_enum("aluminum", "steel", "carbon_fiber", "titanium", "plastic") var body_material_name: String = "aluminum"
@export_range(0.0, 200000.0, 100.0) var payload_mass: float = 20000.0
@export_range(0, 8, 1) var fin_count: int = 4
@export_range(0.05, 1.0, 0.01) var fin_size: float = 0.3

var fin_mesh: Mesh = null
var fin_material_name: String = "aluminum"
var fin_thickness: float = 0.04
var fin_span: float = 0.3
var fin_root_chord: float = 0.4
var fin_tip_chord: float = 0.25
var fin_surface_area: float = 0.0

var body_shell_mass: float = 0.0
var fin_mass: float = 0.0
var dry_mass: float = 0.0
var total_launch_mass: float = 0.0

func recalculate_masses() -> void:
	var body_data: Dictionary = MaterialDatabase.get_material(body_material_name)
	var fin_data: Dictionary = MaterialDatabase.get_material(fin_material_name)
	var base_body_mass := maxf(1.0, rocket_height * rocket_radius * 12.0)
	body_shell_mass = base_body_mass * float(body_data.get("mass_multiplier", 1.0))
	fin_mass = float(fin_count) * maxf(fin_surface_area, fin_size * 0.25) * fin_thickness * float(fin_data.get("mass_multiplier", 1.0)) * FIN_MASS_SCALE
	dry_mass = body_shell_mass + fin_mass + payload_mass
	total_launch_mass = dry_mass + fuel_amount * FUEL_MASS_FACTOR
	rocket_mass = dry_mass
