extends Node3D

@onready var rocket: RocketController = $Rocket
@onready var ui: UIController = $UILayer/DashboardUI
@onready var simulation_manager: SimulationManager = $SimulationManager
@onready var fin_editor: FinEditor = $FinEditor
@onready var sim_camera: Camera3D = $Camera3D
@onready var ui_layer: CanvasLayer = $UILayer

func _ready() -> void:
	fin_editor.fins_confirmed.connect(_on_fins_confirmed)
	ui.launch_requested.connect(_on_launch_requested)
	ui.reset_requested.connect(_on_reset_requested)
	ui.config_changed.connect(_on_config_changed)
	simulation_manager.results_ready.connect(ui.show_results)

	sim_camera.current = false

func _on_fins_confirmed(fin_data: FinData) -> void:
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

	fin_editor.visible = false
	ui_layer.visible = true
	sim_camera.current = true

	rocket.setup(config)
	rocket.preview_config(config)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		simulation_manager.start_launch(rocket.config)
	elif event.keycode == KEY_F11:
		_toggle_fullscreen()

func _on_launch_requested(_config: RocketConfig) -> void:
	simulation_manager.start_launch(rocket.config)

func _on_config_changed(slider_config: RocketConfig) -> void:
	var rc := rocket.config
	rc.rocket_mass = slider_config.rocket_mass
	rc.engine_thrust = slider_config.engine_thrust
	rc.fuel_amount = slider_config.fuel_amount
	rc.wind_speed = slider_config.wind_speed
	rc.wind_direction = slider_config.wind_direction
	rc.rocket_radius = slider_config.rocket_radius
	rc.rocket_height = slider_config.rocket_height
	rocket.preview_config(rc)

func _on_reset_requested() -> void:
	get_tree().reload_current_scene()

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
