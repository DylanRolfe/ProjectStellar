extends Node3D

enum AppState {
	EDITING_FINS,
	READY_TO_LAUNCH,
	IN_FLIGHT,
	RESULTS,
}

var rocket: RocketController
var ui: UIController
var simulation_manager: SimulationManager
var fin_editor: FinEditor
var sim_camera: Camera3D
var ui_layer: CanvasLayer

const MAIN_SCENE_PATH: String = "res://scenes/Main.tscn"

var _app_state: int = AppState.EDITING_FINS

func _ready() -> void:
	rocket = get_node_or_null("Rocket") as RocketController
	ui = get_node_or_null("UILayer/DashboardUI") as UIController
	simulation_manager = get_node_or_null("SimulationManager") as SimulationManager
	fin_editor = get_node_or_null("FinEditor") as FinEditor
	sim_camera = get_node_or_null("Camera3D") as Camera3D
	ui_layer = get_node_or_null("UILayer") as CanvasLayer

	if fin_editor != null:
		fin_editor.fins_confirmed.connect(_on_fins_confirmed)
		if fin_editor.has_signal("fin_data_changed"):
			fin_editor.fin_data_changed.connect(_on_fin_data_changed)
	else:
		push_error("Main: FinEditor node not found")

	if ui != null:
		ui.launch_requested.connect(_on_launch_requested)
		ui.reset_requested.connect(_on_reset_requested)
		ui.config_changed.connect(_on_config_changed)
	else:
		push_error("Main: DashboardUI node not found")

	if simulation_manager != null:
		simulation_manager.results_ready.connect(_on_results_ready)
	else:
		push_error("Main: SimulationManager node not found")

	_set_app_state(AppState.EDITING_FINS)
	if fin_editor != null:
		_on_fin_data_changed(fin_editor.get_current_fin_data())

func _on_fins_confirmed(fin_data: FinData) -> void:
	if rocket == null or ui == null:
		return
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
	if rocket == null or simulation_manager == null or ui == null:
		return
	if event.keycode == KEY_SPACE:
		_merge_launch_settings_into_rocket_config(ui.build_config())
		simulation_manager.start_launch(rocket.config)
	elif event.keycode == KEY_F11:
		_toggle_fullscreen()

func _on_launch_requested(slider_config: RocketConfig) -> void:
	if rocket == null or simulation_manager == null:
		return
	_set_app_state(AppState.IN_FLIGHT)
	_merge_launch_settings_into_rocket_config(slider_config)
	simulation_manager.start_launch(rocket.config)

func _on_config_changed(slider_config: RocketConfig) -> void:
	if rocket == null:
		return
	_merge_launch_settings_into_rocket_config(slider_config)
	rocket.preview_config(rocket.config)

func _merge_launch_settings_into_rocket_config(slider_config: RocketConfig) -> void:
	if rocket == null:
		return
	var rc := rocket.config
	rc.engine_thrust = slider_config.engine_thrust
	rc.fuel_amount = slider_config.fuel_amount
	rc.wind_speed = slider_config.wind_speed
	rc.wind_direction = slider_config.wind_direction
	rc.rocket_radius = slider_config.rocket_radius
	rc.rocket_height = slider_config.rocket_height
	rc.body_material_name = slider_config.body_material_name
	rc.payload_mass = slider_config.payload_mass
	rc.recalculate_masses()

func _on_reset_requested() -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MAIN_SCENE_PATH)

func _on_fin_data_changed(fin_data: FinData) -> void:
	if _app_state != AppState.EDITING_FINS or rocket == null:
		return
	rocket.preview_fins(fin_data)

func _on_results_ready(results: Dictionary) -> void:
	_set_app_state(AppState.RESULTS)
	ui.show_results(results)

func _set_app_state(new_state: int) -> void:
	_app_state = new_state
	match _app_state:
		AppState.EDITING_FINS:
			if fin_editor != null:
				fin_editor.set_editor_active(true)
			if ui_layer != null:
				ui_layer.visible = false
			if rocket != null:
				rocket.visible = true
			if sim_camera != null:
				sim_camera.current = true
		AppState.READY_TO_LAUNCH:
			if fin_editor != null:
				fin_editor.set_editor_active(false)
			if ui_layer != null:
				ui_layer.visible = true
			if rocket != null:
				rocket.visible = true
			if sim_camera != null:
				sim_camera.current = true
			if ui != null:
				ui.set_hud_mode(false)
		AppState.IN_FLIGHT:
			if fin_editor != null:
				fin_editor.set_editor_active(false)
			if ui_layer != null:
				ui_layer.visible = true
			if rocket != null:
				rocket.visible = true
			if sim_camera != null:
				sim_camera.current = true
			if ui != null:
				ui.set_hud_mode(true)
		AppState.RESULTS:
			if fin_editor != null:
				fin_editor.set_editor_active(false)
			if ui_layer != null:
				ui_layer.visible = true
			if rocket != null:
				rocket.visible = true
			if sim_camera != null:
				sim_camera.current = true
			if ui != null:
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
