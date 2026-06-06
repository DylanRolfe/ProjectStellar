class_name RocketController
extends RigidBody3D

const FUEL_BURN_RATE: float = 8.0

var config: RocketConfig = RocketConfig.new()
var max_altitude: float = 0.0
var max_speed: float = 0.0

var _fuel: float = 0.0
var _launched: bool = false
var _last_print_time: float = 0.0

func _ready() -> void:
	setup(config)
	set_physics_process(true)

func setup(new_config: RocketConfig) -> void:
	config = new_config
	mass = config.rocket_mass
	_fuel = config.fuel_amount
	max_altitude = 0.0
	max_speed = 0.0
	_launched = false
	_last_print_time = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = false

func launch() -> void:
	if _launched:
		return
	_launched = true
	freeze = false
	sleeping = false
	print("Launch started: thrust %.1f N, mass %.1f kg, fuel %.1f" % [config.engine_thrust, mass, _fuel])

func _physics_process(delta: float) -> void:
	if not _launched:
		return

	var altitude := maxf(global_position.y, 0.0)
	var gravity_force := Vector3.DOWN * mass * AeroPhysics.gravity_at(altitude)
	apply_central_force(gravity_force)

	if _fuel > 0.0:
		var burn := minf(_fuel, FUEL_BURN_RATE * delta)
		_fuel -= burn
		apply_central_force(global_transform.basis.y.normalized() * config.engine_thrust)

	max_altitude = maxf(max_altitude, altitude)
	max_speed = maxf(max_speed, linear_velocity.length())

	_last_print_time += delta
	if _last_print_time >= 1.0:
		_last_print_time = 0.0
		print("Altitude %.1f m | Speed %.1f m/s | Fuel %.1f" % [altitude, linear_velocity.length(), _fuel])
