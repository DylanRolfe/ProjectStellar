class_name UIController
extends Control

signal launch_requested(config: RocketConfig)
signal reset_requested

@onready var launch_button: Button = $Panel/Margin/VBox/ButtonRow/LaunchButton
@onready var reset_button: Button = $Panel/Margin/VBox/ButtonRow/ResetButton
@onready var mass_slider: HSlider = $Panel/Margin/VBox/MassRow/MassSlider
@onready var thrust_slider: HSlider = $Panel/Margin/VBox/ThrustRow/ThrustSlider
@onready var fuel_slider: HSlider = $Panel/Margin/VBox/FuelRow/FuelSlider
@onready var mass_value_label: Label = $Panel/Margin/VBox/MassRow/MassValueLabel
@onready var thrust_value_label: Label = $Panel/Margin/VBox/ThrustRow/ThrustValueLabel
@onready var fuel_value_label: Label = $Panel/Margin/VBox/FuelRow/FuelValueLabel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

func _ready() -> void:
	launch_button.pressed.connect(_on_launch_pressed)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	mass_slider.value_changed.connect(_on_slider_changed)
	thrust_slider.value_changed.connect(_on_slider_changed)
	fuel_slider.value_changed.connect(_on_slider_changed)
	_update_value_labels()

func build_config() -> RocketConfig:
	var config := RocketConfig.new()
	config.rocket_mass = mass_slider.value
	config.engine_thrust = thrust_slider.value
	config.fuel_amount = fuel_slider.value
	return config

func _on_launch_pressed() -> void:
	status_label.text = "In flight"
	launch_requested.emit(build_config())

func _on_slider_changed(_value: float) -> void:
	_update_value_labels()
	status_label.text = "Ready"

func _update_value_labels() -> void:
	mass_value_label.text = "%.0f kg" % mass_slider.value
	thrust_value_label.text = "%.0f N" % thrust_slider.value
	fuel_value_label.text = "%.0f" % fuel_slider.value
