extends Node3D

@onready var rocket: RocketController = $Rocket
@onready var ui: UIController = $UILayer/DashboardUI
@onready var simulation_manager: SimulationManager = $SimulationManager

func _ready() -> void:
	var camera := $Camera3D as Camera3D
	camera.current = true
	ui.launch_requested.connect(_on_launch_requested)
	ui.reset_requested.connect(_on_reset_requested)
	ui.config_changed.connect(_on_config_changed)
	simulation_manager.results_ready.connect(ui.show_results)
	rocket.preview_config(ui.build_config())

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		_on_launch_requested(ui.build_config())
	elif event.keycode == KEY_F11:
		_toggle_fullscreen()

func _on_launch_requested(config: RocketConfig) -> void:
	simulation_manager.start_launch(config)

func _on_config_changed(config: RocketConfig) -> void:
	rocket.preview_config(config)

func _on_reset_requested() -> void:
	get_tree().reload_current_scene()

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
