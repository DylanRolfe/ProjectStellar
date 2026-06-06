class_name RocketController
extends RigidBody3D

signal flight_finished(reason: String)

const FUEL_BURN_RATE: float = 8.0
const AIR_DENSITY: float = 1.225
const DRAG_COEFFICIENT: float = 1.2
const WIND_FORCE_MULTIPLIER: float = 1.0
const DESTABILIZING_TORQUE: float = 0.35
const STABILIZING_TORQUE: float = 0.55
const MIN_AIRFLOW_SPEED: float = 0.1
const MIN_TORQUE_AXIS: float = 0.001
const FIN_BASE_HEIGHT: float = 0.45
const FIN_BODY_RADIUS: float = 0.31
const MIN_FLIGHT_TIME: float = 1.0
const TUMBLE_TILT_DEGREES: float = 82.0
const GROUND_IMPACT_HEIGHT: float = 0.25

@export var use_meshy_visual_model: bool = false
@export var body_part_path: NodePath
@export var nose_part_path: NodePath
@export var engine_part_path: NodePath

var config: RocketConfig = RocketConfig.new()
var max_altitude: float = 0.0
var max_speed: float = 0.0
var current_tilt: float = 0.0
var max_tilt: float = 0.0

@onready var fin_holder: Node3D = $FinHolder
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var nose_mesh: MeshInstance3D = $NoseMesh
@onready var nozzle_mesh: MeshInstance3D = $NozzleMesh
@onready var visual_model_holder: Node3D = $VisualModelHolder
@onready var body_part: Node = get_node_or_null(body_part_path)
@onready var nose_part: Node = get_node_or_null(nose_part_path)
@onready var engine_part: Node = get_node_or_null(engine_part_path)

var _fuel: float = 0.0
var _launched: bool = false
var _finished: bool = false
var _flight_time: float = 0.0
var _tilt_sum: float = 0.0
var _tilt_samples: int = 0
var _tumbled: bool = false
var _deg: bool = false
var _last_print_time: float = 0.0
func _ready() -> void:
	setup(config)
	set_physics_process(true)

func preview_config(new_config: RocketConfig) -> void:
	if _launched:
		return
	config = new_config
	config.recalculate_masses()
	mass = config.total_launch_mass
	_apply_visual_model_mode()
	_apply_materials()
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
	_fuel = config.fuel_amount
	max_altitude = 0.0
	max_speed = 0.0
	current_tilt = 0.0
	max_tilt = 0.0
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
	angular_damp = 3.0
	freeze = true
	sleeping = false
	_apply_visual_model_mode()
	_apply_materials()
	_build_visual_fins()

func launch() -> void:
	if _launched or _finished:
		return
	_launched = true
	freeze = false
	sleeping = false
	print("Launch started: thrust %.1f N, mass %.1f kg, fuel %.1f, wind %.1f m/s @ %.0f deg, fins %d size %.2f" % [config.engine_thrust, mass, _fuel, config.wind_speed, config.wind_direction, config.fin_count, config.fin_size])

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
		var drag_magnitude := AeroPhysics.drag_force(relative_speed, AIR_DENSITY, drag_coefficient, area)
		apply_central_force(-relative_velocity.normalized() * drag_magnitude * WIND_FORCE_MULTIPLIER)
		_apply_airflow_torque(relative_velocity, relative_speed)

	if _fuel > 0.0:
		var tilt := rad_to_deg(global_transform.basis.y.angle_to(Vector3.UP))
		if tilt < 60.0:
			var burn := minf(_fuel, FUEL_BURN_RATE * delta)
			_fuel -= burn
			mass = config.dry_mass + _fuel * RocketConfig.FUEL_MASS_FACTOR
			apply_central_force(global_transform.basis.y.normalized() * config.engine_thrust)

	max_altitude = maxf(max_altitude, altitude)
	max_speed = maxf(max_speed, linear_velocity.length())
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
	var flight_dir := relative_velocity.normalized()
	var misalignment := nose_dir.angle_to(flight_dir)
	if misalignment < 0.001:
		return

	var axis := nose_dir.cross(flight_dir)
	if axis.length() < MIN_TORQUE_AXIS:
		return
	axis = axis.normalized()

	var sideways_airflow := clampf(1.0 - absf(nose_dir.dot(flight_dir)), 0.0, 1.0)
	var effective_area := config.fin_surface_area if config.fin_surface_area > 0.0 else config.fin_size
	var fin_power := float(config.fin_count) * effective_area
	var fin_mat_data: Dictionary = MaterialDatabase.get_material(config.fin_material_name)
	var fin_strength := float(fin_mat_data.get("strength", 0.6))
	var stability_bonus := float(fin_mat_data.get("stability_bonus", 0.0))
	fin_power *= maxf(0.25, fin_strength + stability_bonus)
	var fin_deficit := clampf(1.0 - fin_power / 1.6, 0.0, 1.0)
	var wind_ratio := clampf(config.wind_speed / 40.0, 0.0, 1.0)

	var destabilizing := misalignment * relative_speed * sideways_airflow * fin_deficit * DESTABILIZING_TORQUE
	if destabilizing > 0.0:
		apply_torque(-axis * destabilizing)

	var stabilizing := misalignment * relative_speed * sideways_airflow * fin_power * STABILIZING_TORQUE
	if stabilizing > 0.0:
		apply_torque(axis * stabilizing)

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

func _apply_materials() -> void:
	var body_mat: StandardMaterial3D = MaterialDatabase.get_surface_material(config.body_material_name)
	if body_part:
		_skin(body_part, body_mat)
	if nose_part:
		_skin(nose_part, body_mat)
	if engine_part:
		_skin(engine_part, body_mat)

func _apply_visual_model_mode() -> void:
	if not is_node_ready():
		return
	body_mesh.visible = not use_meshy_visual_model
	nose_mesh.visible = not use_meshy_visual_model
	nozzle_mesh.visible = not use_meshy_visual_model
	visual_model_holder.visible = use_meshy_visual_model
