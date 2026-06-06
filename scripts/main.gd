extends Node3D

@onready var rocket: RocketController = $Rocket
@onready var ui: UIController = $UILayer/DashboardUI

func _ready() -> void:
	var camera := $Camera3D as Camera3D
	camera.current = true
	ui.launch_requested.connect(_on_launch_requested)
	ui.reset_requested.connect(_on_reset_requested)

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_SPACE):
		_on_launch_requested(ui.build_config())

func _on_launch_requested(config: RocketConfig) -> void:
	rocket.setup(config)
	rocket.launch()

func _on_reset_requested() -> void:
	get_tree().reload_current_scene()
