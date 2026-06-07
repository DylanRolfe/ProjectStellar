class_name RocketController
extends RigidBody3D

signal flight_finished(reason: String)

const AIR_DENSITY: float = 1.225
const DRAG_COEFFICIENT: float = 1.2
const WIND_FORCE_MULTIPLIER: float = 1.0
const DESTABILIZING_TORQUE: float = 2.0
const STABILIZING_TORQUE: float = 0.15
const MIN_AIRFLOW_SPEED: float = 0.1
const MIN_TORQUE_AXIS: float = 0.001
const FIN_BASE_HEIGHT: float = 0.45
const FIN_BODY_RADIUS: float = 0.26
const MIN_FLIGHT_TIME: float = 1.0
const TUMBLE_TILT_DEGREES: float = 82.0
const GROUND_IMPACT_HEIGHT: float = 0.25

var config: RocketConfig = RocketConfig.new()
var max_altitude: float = 0.0
var max_speed: float = 0.0
var current_tilt: float = 0.0
var max_tilt: float = 0.0
var start_x: float = 0.0

@onready var fin_holder: Node3D = $FinHolder
@onready var engine_flame: RocketFlame = $EngineFlame

var _fuel: float = 0.0
var _burn_rate: float = 0.0
var _launched: bool = false
var _finished: bool = false
var _flight_time: float = 0.0
var _tilt_sum: float = 0.0
var _tilt_samples: int = 0
var _tumbled: bool = false
var _deg: bool = false
var _last_print_time: float = 0.0

# --- RocketPy trajectory playback ---
const PLAYBACK_SPEED: float = 2.0  # animate at 2x real time so flights aren't tedious
var _playback: bool = false
var _pb_samples: Array = []
var _pb_time: float = 0.0
var _pb_duration: float = 0.0
var _pb_burn_time: float = 0.0
var _pb_origin: Vector3 = Vector3.ZERO
var _pb_index: int = 0

# Live telemetry (read by the flight HUD each frame).
var _launch_origin: Vector3 = Vector3.ZERO
var _live_speed: float = 0.0

func _ready() -> void:
	setup(config)
	set_physics_process(true)

func preview_config(new_config: RocketConfig) -> void:
	if _launched:
		return
	config = new_config
	config.recalculate_masses()
	mass = config.total_launch_mass
	_build_visual_fins()

func preview_fins(fin_data: FinData) -> void:
	if _launched:
		return
	config.fin_count = fin_data.fin_count
	config.fin_mesh = fin_data.cached_mesh
	config.fin_material_name = fin_data.material_name
	config.fin_thickness = fin_data.thickness
	config.fin_span = fin_data.fin_span
	config.fin_root_chord = fin_data.fin_root_chord
	config.fin_tip_chord = fin_data.fin_tip_chord
	config.fin_surface_area = fin_data.surface_area
	config.fin_size = maxf(fin_data.fin_span * 0.3, 0.1)
	config.recalculate_masses()
	_build_visual_fins()

func setup(new_config: RocketConfig) -> void:
	config = new_config
	config.recalculate_masses()
	mass = config.total_launch_mass
	_fuel = config.propellant_mass
	_burn_rate = config.propellant_mass / maxf(config.burn_time, 0.001)
	max_altitude = 0.0
	max_speed = 0.0
	current_tilt = 0.0
	max_tilt = 0.0
	start_x = global_position.x
	_launch_origin = global_position
	_live_speed = 0.0
	_launched = false
	_finished = false
	_flight_time = 0.0
	_tilt_sum = 0.0
	_tilt_samples = 0
	_tumbled = false
	_deg = false
	_last_print_time = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	angular_damp = 1.0
	freeze = true
	sleeping = false
	_build_visual_fins()

func launch() -> void:
	if _launched or _finished:
		return
	_launched = true
	freeze = false
	sleeping = false
	engine_flame.set_thrust_factor(config.engine_thrust / 5000.0)
	engine_flame.emitting = true
	print("Launch started: thrust %.1f N, mass %.1f kg, fuel %.1f, wind %.1f m/s @ %.0f deg, fins %d size %.2f" % [config.engine_thrust, mass, _fuel, config.wind_speed, config.wind_direction, config.fin_count, config.fin_size])

## Animate a RocketPy-computed trajectory instead of running local physics.
## `samples` is an array of {t, x, y, z, v} dictionaries (x=East, y=North,
## z=Up, all metres relative to the launch point); `burn_time` is how long the
## engine is lit, so the flame cuts out when the fuel runs out.
func play_trajectory(samples: Array, burn_time: float) -> void:
	if samples.size() < 2:
		force_finish("No trajectory returned")
		return
	_pb_samples = samples
	_pb_burn_time = burn_time
	_pb_time = 0.0
	_pb_index = 0
	_pb_duration = float(samples[samples.size() - 1]["t"])
	_pb_origin = global_position
	_launched = true
	_finished = false
	_playback = true
	freeze = true
	sleeping = false
	set_physics_process(false)
	set_process(true)
	max_altitude = 0.0
	max_speed = 0.0
	max_tilt = 0.0
	engine_flame.set_thrust_factor(clampf(config.engine_thrust / 5000.0, 0.15, 1.0))
	engine_flame.emitting = burn_time > 0.0
	# Place the rocket at the first sample, upright.
	global_position = _pb_origin + _sample_position(0.0)
	print("Playback started: %d samples, %.1fs flight, %.2fs burn" % [samples.size(), _pb_duration, burn_time])

func _process(delta: float) -> void:
	if not _playback:
		return
	_pb_time += delta * PLAYBACK_SPEED

	# Cut the flame once the engine burn is over (fuel exhausted).
	if engine_flame.emitting and _pb_time >= _pb_burn_time:
		engine_flame.stop()

	if _pb_time >= _pb_duration:
		_finish_playback()
		return

	var pos := _sample_position(_pb_time)

	# Point the nose (local +Y) along the direction of travel, and move there.
	# Set the whole transform at once (assigning global_transform.basis on its
	# own does not reliably persist on a frozen body).
	var ahead := _sample_position(minf(_pb_time + 0.04, _pb_duration))
	var velocity := ahead - pos
	var orientation := global_transform.basis
	if velocity.length() > 0.01:
		orientation = _basis_along(velocity.normalized())
	global_transform = Transform3D(orientation, _pb_origin + pos)

	var altitude := pos.y
	_live_speed = _sample_speed(_pb_time)
	max_altitude = maxf(max_altitude, altitude)
	max_speed = maxf(max_speed, _live_speed)
	current_tilt = rad_to_deg(global_transform.basis.y.angle_to(Vector3.UP))
	max_tilt = maxf(max_tilt, current_tilt)

func _finish_playback() -> void:
	if _finished:
		return
	_playback = false
	_finished = true
	_launched = false
	engine_flame.stop()
	var landing := _sample_position(_pb_duration)
	landing.y = maxf(landing.y, GROUND_IMPACT_HEIGHT)
	# Rest tipped over on the ground, like the physics path does.
	var tipped := Basis(Vector3.FORWARD, deg_to_rad(75.0))
	global_transform = Transform3D(tipped, _pb_origin + landing)
	_flight_time = _pb_duration
	print("Playback finished: max height %.1f m, max speed %.1f m/s" % [max_altitude, max_speed])
	flight_finished.emit("Flight complete: returned to the ground")

## Linearly interpolates the trajectory sample position at time `t`, mapping
## RocketPy axes (East, North, Up) into Godot's (x, y=up, z).
func _sample_position(t: float) -> Vector3:
	var i := _find_sample_index(t)
	var a: Dictionary = _pb_samples[i]
	var b: Dictionary = _pb_samples[min(i + 1, _pb_samples.size() - 1)]
	var ta := float(a["t"])
	var tb := float(b["t"])
	var f := 0.0 if tb <= ta else clampf((t - ta) / (tb - ta), 0.0, 1.0)
	var ax := float(a["x"]); var ay := float(a["y"]); var az := float(a["z"])
	var bx := float(b["x"]); var by := float(b["y"]); var bz := float(b["z"])
	return Vector3(
		lerpf(ax, bx, f),
		lerpf(az, bz, f),
		lerpf(ay, by, f)
	)

func _sample_speed(t: float) -> float:
	var i := _find_sample_index(t)
	return float(_pb_samples[i]["v"])

func _find_sample_index(t: float) -> int:
	# Samples are time-ordered; advance the cached cursor to the right segment.
	while _pb_index < _pb_samples.size() - 2 and float(_pb_samples[_pb_index + 1]["t"]) < t:
		_pb_index += 1
	while _pb_index > 0 and float(_pb_samples[_pb_index]["t"]) > t:
		_pb_index -= 1
	return _pb_index

func _basis_along(dir: Vector3) -> Basis:
	var y_axis := dir.normalized()
	var x_axis := Vector3.RIGHT
	if absf(y_axis.dot(Vector3.RIGHT)) > 0.99:
		x_axis = Vector3.FORWARD
	var z_axis := x_axis.cross(y_axis).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _physics_process(delta: float) -> void:
	if not _launched or _finished:
		return
	_flight_time += delta

	var altitude := maxf(global_position.y, 0.0)
	var gravity_force := Vector3.DOWN * mass * AeroPhysics.gravity_at(altitude)
	apply_central_force(gravity_force)

	var wind_velocity := WindModel.get_wind_vector(config.wind_speed, config.wind_direction)
	var relative_velocity := linear_velocity - wind_velocity
	var relative_speed := relative_velocity.length()
	if relative_speed > 0.01:
		var area := AeroPhysics.frontal_area(config.rocket_radius)
		var drag_coefficient := maxf(0.4, DRAG_COEFFICIENT + _body_drag_modifier())

		var rocket_speed := linear_velocity.length()
		if rocket_speed > 0.01:
			var drag_magnitude := AeroPhysics.drag_force(rocket_speed, AIR_DENSITY, drag_coefficient, area)
			apply_central_force(-linear_velocity.normalized() * drag_magnitude)

		var wind_push := AeroPhysics.drag_force(config.wind_speed, AIR_DENSITY, drag_coefficient, area)
		apply_central_force(wind_velocity.normalized() * wind_push)

		_apply_airflow_torque(relative_velocity, relative_speed)

	if _fuel > 0.0:
		var tilt := rad_to_deg(global_transform.basis.y.angle_to(Vector3.UP))
		if tilt < 60.0:
			var burn := minf(_fuel, _burn_rate * delta)
			_fuel -= burn
			mass = config.dry_mass + _fuel
			apply_central_force(global_transform.basis.y.normalized() * config.engine_thrust)

	# Cut the exhaust flame the moment the rocket runs out of fuel.
	if _fuel <= 0.0 and engine_flame.emitting:
		engine_flame.stop()

	if _fuel <= 0.0 and linear_velocity.y < 0.0:
		var nose_dir := global_transform.basis.y.normalized()
		var flip_axis := nose_dir.cross(Vector3.DOWN)
		if flip_axis.length() > MIN_TORQUE_AXIS:
			var flip_torque := nose_dir.angle_to(Vector3.DOWN) * mass * 0.8
			apply_torque(flip_axis.normalized() * flip_torque)

	_live_speed = linear_velocity.length()
	max_altitude = maxf(max_altitude, altitude)
	max_speed = maxf(max_speed, _live_speed)
	current_tilt = rad_to_deg(global_transform.basis.y.angle_to(Vector3.UP))
	max_tilt = maxf(max_tilt, current_tilt)
	_tilt_sum += current_tilt
	_tilt_samples += 1
	_check_flight_end(altitude)

	_last_print_time += delta
	if _last_print_time >= 1.0:
		_last_print_time = 0.0
		print("Altitude %.1f m | Speed %.1f m/s | Fuel %.1f | Wind %.1f m/s @ %.0f deg" % [altitude, linear_velocity.length(), _fuel, config.wind_speed, config.wind_direction])

func average_tilt() -> float:
	return _tilt_sum / float(_tilt_samples) if _tilt_samples > 0 else 0.0

func flight_time() -> float:
	return _flight_time

func is_flying() -> bool:
	return _playback or (_launched and not _finished)

## Live flight stats for the HUD, refreshed every frame while in flight.
func get_live_telemetry() -> Dictionary:
	var offset := global_position - _launch_origin
	return {
		"altitude": maxf(offset.y, 0.0),
		"speed": _live_speed,
		"max_altitude": max_altitude,
		"max_speed": max_speed,
		"downrange": Vector2(offset.x, offset.z).length(),
		"time": _pb_time if _playback else _flight_time,
	}

func x_displacement() -> float:
	return global_position.x - start_x

func force_finish(reason: String) -> void:
	_finish_flight(reason)

func _check_flight_end(altitude: float) -> void:
	if _flight_time < MIN_FLIGHT_TIME:
		return
	if altitude > 2.0 and current_tilt >= TUMBLE_TILT_DEGREES:
		_deg = true
	if max_altitude > 2.0 and global_position.y <= GROUND_IMPACT_HEIGHT and linear_velocity.y <= 0.0:
		if _deg == true:
			_finish_flight("Lost control: rocket tumbled past %.0f degrees" % TUMBLE_TILT_DEGREES)
			return
		var reason := "Flight failed: rocket tumbled before impact" if _tumbled else "Flight complete: returned to the ground"
		_finish_flight(reason)

func _finish_flight(reason: String) -> void:
	if _finished:
		return
	_finished = true
	_launched = false
	freeze = true
	engine_flame.stop()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position.y = GROUND_IMPACT_HEIGHT
	rotation.z = deg_to_rad(75.0)
	print("Flight finished: %s | Max height %.1f m | Max speed %.1f m/s | Max tilt %.1f deg" % [reason, max_altitude, max_speed, max_tilt])
	flight_finished.emit(reason)

func _apply_airflow_torque(relative_velocity: Vector3, relative_speed: float) -> void:
	if relative_speed < MIN_AIRFLOW_SPEED:
		return

	var nose_dir := global_transform.basis.y.normalized()
	var airflow_dir := relative_velocity.normalized()
	var misalignment := nose_dir.angle_to(airflow_dir)
	if misalignment < 0.001:
		return

	var dynamic_pressure := 0.5 * AIR_DENSITY * relative_speed * relative_speed
	var sideways_airflow := clampf(1.0 - absf(nose_dir.dot(airflow_dir)), 0.0, 1.0)
	var effective_area := config.fin_surface_area if config.fin_surface_area > 0.0 else config.fin_size
	var aspect_ratio := (config.fin_span * config.fin_span) / maxf(effective_area, 0.001)
	var fin_mat_data: Dictionary = MaterialDatabase.get_material(config.fin_material_name)
	var fin_strength := float(fin_mat_data.get("strength", 0.6))
	var stability_bonus := float(fin_mat_data.get("stability_bonus", 0.0))
	var fin_power := float(config.fin_count) * effective_area * maxf(0.5, minf(aspect_ratio / 2.0, 2.0))
	fin_power *= maxf(0.25, fin_strength + stability_bonus)
	var fin_deficit := clampf(1.0 - fin_power / 1.6, 0.0, 1.0)
	var moment_arm := config.rocket_height * 0.5

	var aoa_degrees := rad_to_deg(misalignment)
	var stall_factor := clampf(1.0 - ((aoa_degrees - 30.0) / 45.0), 0.0, 1.0)

	var torque_axis := nose_dir.cross(airflow_dir)
	if torque_axis.length() < MIN_TORQUE_AXIS:
		return
	torque_axis = torque_axis.normalized()

	var destabilizing := misalignment * sideways_airflow * fin_deficit * DESTABILIZING_TORQUE
	if destabilizing > 0.0:
		apply_torque(torque_axis * destabilizing)

	var stabilizing := misalignment * dynamic_pressure * sideways_airflow * fin_power * moment_arm * stall_factor * STABILIZING_TORQUE
	if stabilizing > 0.0:
		apply_torque(-torque_axis * stabilizing)

func _build_visual_fins() -> void:
	if not is_node_ready():
		return

	for child in fin_holder.get_children():
		child.queue_free()

	if config.fin_count <= 0:
		return

	var mesh := config.fin_mesh
	if mesh == null:
		return

	var fin_mat := MaterialDatabase.get_surface_material(config.fin_material_name).duplicate() as StandardMaterial3D
	fin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in range(config.fin_count):
		var angle := TAU * float(i) / float(config.fin_count)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))

		var fin := MeshInstance3D.new()
		fin.name = "Fin%d" % (i + 1)
		fin.mesh = mesh
		fin_holder.add_child(fin)
		_skin(fin, fin_mat)

		fin.position = radial * FIN_BODY_RADIUS
		fin.position.y = FIN_BASE_HEIGHT

		var basis := Basis()
		basis.x = radial
		basis.y = Vector3.UP
		basis.z = tangent
		fin.basis = basis
		fin.scale = Vector3(0.85, 0.85, 0.85)

func _effective_body_mass() -> float:
	var mat_data: Dictionary = MaterialDatabase.get_material(config.body_material_name)
	return config.body_shell_mass if config.body_shell_mass > 0.0 else config.rocket_mass * float(mat_data.get("mass_multiplier", 1.0))

func _body_drag_modifier() -> float:
	var mat_data: Dictionary = MaterialDatabase.get_material(config.body_material_name)
	return float(mat_data.get("drag_modifier", 0.0))

func _skin(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, mat)
	for child in node.get_children():
		_skin(child, mat)
