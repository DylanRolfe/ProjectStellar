extends Node3D

enum AppState {
	EDITING_FINS,
	READY_TO_LAUNCH,
	IN_FLIGHT,
	RESULTS,
}

@onready var rocket: RocketController = $Rocket
@onready var ui: UIController = $UILayer/DashboardUI
@onready var simulation_manager: SimulationManager = $SimulationManager
@onready var fin_editor: FinEditor = $FinEditor
@onready var sim_camera: Camera3D = $Camera3D
@onready var ui_layer: CanvasLayer = $UILayer

const MAIN_SCENE_PATH: String = "res://scenes/Main.tscn"

var _app_state: int = AppState.EDITING_FINS

func _ready() -> void:
	fin_editor.fins_confirmed.connect(_on_fins_confirmed)
	if fin_editor.has_signal("fin_data_changed"):
		fin_editor.fin_data_changed.connect(_on_fin_data_changed)
	ui.launch_requested.connect(_on_launch_requested)
	ui.reset_requested.connect(_on_reset_requested)
	ui.config_changed.connect(_on_config_changed)
	simulation_manager.results_ready.connect(_on_results_ready)
	simulation_manager.simulation_state_changed.connect(func(message: String) -> void: ui.set_status(message))

	_set_app_state(AppState.EDITING_FINS)
	_on_fin_data_changed(fin_editor.get_current_fin_data())

func _on_fins_confirmed(fin_data: FinData) -> void:
	var config := _build_config_from_fin_data(fin_data)
	_set_app_state(AppState.READY_TO_LAUNCH)

	rocket.setup(config)
	rocket.preview_config(config)
	ui.set_base_config(rocket.config)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		_merge_launch_settings_into_rocket_config(ui.build_config())
		simulation_manager.start_launch(rocket.config)
	elif event.keycode == KEY_F11:
		_toggle_fullscreen()

func _on_launch_requested(slider_config: RocketConfig) -> void:
	_set_app_state(AppState.IN_FLIGHT)
	_merge_launch_settings_into_rocket_config(slider_config)
	simulation_manager.start_launch(rocket.config)

func _on_config_changed(slider_config: RocketConfig) -> void:
	_merge_launch_settings_into_rocket_config(slider_config)
	rocket.preview_config(rocket.config)

func _merge_launch_settings_into_rocket_config(slider_config: RocketConfig) -> void:
	var rc := rocket.config
	rc.engine_thrust = slider_config.engine_thrust
	rc.propellant_mass = slider_config.propellant_mass
	rc.burn_time = slider_config.burn_time
	rc.body_dry_mass = slider_config.body_dry_mass
	rc.payload_mass = slider_config.payload_mass
	rc.rocket_radius = slider_config.rocket_radius
	rc.rocket_height = slider_config.rocket_height
	rc.wind_speed = slider_config.wind_speed
	rc.wind_direction = slider_config.wind_direction
	rc.body_material_name = slider_config.body_material_name
	rc.recalculate_masses()

func _on_reset_requested() -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MAIN_SCENE_PATH)

func _on_fin_data_changed(fin_data: FinData) -> void:
	if _app_state != AppState.EDITING_FINS:
		return
	rocket.preview_fins(fin_data)

func _on_results_ready(results: Dictionary) -> void:
	_set_app_state(AppState.RESULTS)
	ui.show_results(results)

func _set_app_state(new_state: int) -> void:
	_app_state = new_state
	match _app_state:
		AppState.EDITING_FINS:
			fin_editor.set_editor_active(true)
			ui_layer.visible = false
			rocket.visible = true
			sim_camera.current = true
		AppState.READY_TO_LAUNCH:
			fin_editor.set_editor_active(false)
			ui_layer.visible = true
			rocket.visible = true
			sim_camera.current = true
			ui.set_hud_mode(false)
		AppState.IN_FLIGHT:
			fin_editor.set_editor_active(false)
			ui_layer.visible = true
			rocket.visible = true
			sim_camera.current = true
			ui.set_hud_mode(true)
		AppState.RESULTS:
			fin_editor.set_editor_active(false)
			ui_layer.visible = true
			rocket.visible = true
			sim_camera.current = true
			ui.set_hud_mode(true)

func _build_config_from_fin_data(fin_data: FinData) -> RocketConfig:
	var config := RocketConfig.new()
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
	return config

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
