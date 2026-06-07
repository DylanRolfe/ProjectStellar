class_name RocketConfig
extends Resource

## Physical rocket configuration, in real units (kg, m, N, s). Values are sized
## for a high-power amateur rocket so the RocketPy solve produces sensible
## flights (a few hundred metres to a couple of km) instead of orbital extremes.

const FIN_MASS_SCALE: float = 8.0
const GRAVITY: float = 9.80665

# --- Engine -----------------------------------------------------------------
@export_range(50.0, 4000.0, 10.0) var engine_thrust: float = 500.0   # average thrust, N
@export_range(0.2, 25.0, 0.2) var propellant_mass: float = 4.0       # kg of propellant
@export_range(0.3, 10.0, 0.1) var burn_time: float = 3.0             # s

# --- Airframe ---------------------------------------------------------------
@export_range(1.0, 40.0, 0.5) var body_dry_mass: float = 5.0         # structural mass, kg
@export_range(0.0, 20.0, 0.5) var payload_mass: float = 1.0          # kg
@export_range(0.02, 0.20, 0.005) var rocket_radius: float = 0.06     # body radius, m
@export_range(0.5, 5.0, 0.1) var rocket_height: float = 1.6          # body length, m
@export_enum("aluminum", "steel", "carbon_fiber", "titanium", "plastic") var body_material_name: String = "aluminum"

# --- Environment ------------------------------------------------------------
@export_range(0.0, 20.0, 0.5) var wind_speed: float = 2.0
@export_range(0.0, 360.0, 1.0) var wind_direction: float = 0.0

# Optional altitude-layered wind ("advanced" wind profile). When wind_advanced
# is true, wind_layers replaces the single uniform wind above. Each layer is a
# dictionary {"top": metres, "speed": m/s, "angle": degrees}, ordered low->high.
var wind_advanced: bool = false
var wind_layers: Array = []

# --- Fins (configured in the fin editor) ------------------------------------
@export_range(0, 8, 1) var fin_count: int = 4
@export_range(0.05, 1.0, 0.01) var fin_size: float = 0.3

var fin_mesh: Mesh = null
var fin_material_name: String = "aluminum"
var fin_thickness: float = 0.04
var fin_span: float = 0.3
var fin_root_chord: float = 0.4
var fin_tip_chord: float = 0.25
var fin_surface_area: float = 0.0

# --- Derived (filled by recalculate_masses) ---------------------------------
var fin_mass: float = 0.0
var dry_mass: float = 0.0
var total_launch_mass: float = 0.0
# Kept for compatibility with code that referenced the old field names.
var body_shell_mass: float = 0.0
var rocket_mass: float = 0.0

func recalculate_masses() -> void:
	var fin_data: Dictionary = MaterialDatabase.get_material(fin_material_name)
	fin_mass = float(fin_count) * maxf(fin_surface_area, fin_size * 0.25) \
		* fin_thickness * float(fin_data.get("mass_multiplier", 1.0)) * FIN_MASS_SCALE
	dry_mass = body_dry_mass + fin_mass + payload_mass
	total_launch_mass = dry_mass + propellant_mass
	body_shell_mass = body_dry_mass
	rocket_mass = dry_mass

## Thrust-to-weight ratio at liftoff. < 1 means the rocket can't leave the pad.
func thrust_to_weight() -> float:
	return engine_thrust / maxf(total_launch_mass * GRAVITY, 0.001)
