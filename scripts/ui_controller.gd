class_name UIController
extends Control

signal launch_requested(config: RocketConfig)
signal reset_requested
signal config_changed(config: RocketConfig)

@onready var launch_button: Button = $Panel/Margin/VBox/ButtonRow/LaunchButton
@onready var reset_button: Button = $Panel/Margin/VBox/ButtonRow/ResetButton
@onready var mass_slider: HSlider = $Panel/Margin/VBox/MassRow/MassSlider
@onready var thrust_slider: HSlider = $Panel/Margin/VBox/ThrustRow/ThrustSlider
@onready var fuel_slider: HSlider = $Panel/Margin/VBox/FuelRow/FuelSlider
@onready var wind_speed_slider: HSlider = $Panel/Margin/VBox/WindSpeedRow/WindSpeedSlider
@onready var wind_direction_slider: HSlider = $Panel/Margin/VBox/WindDirectionRow/WindDirectionSlider
@onready var fin_count_slider: HSlider = $Panel/Margin/VBox/FinCountRow/FinCountSlider
@onready var fin_size_slider: HSlider = $Panel/Margin/VBox/FinSizeRow/FinSizeSlider
@onready var mass_value_label: Label = $Panel/Margin/VBox/MassRow/MassValueLabel
@onready var thrust_value_label: Label = $Panel/Margin/VBox/ThrustRow/ThrustValueLabel
@onready var fuel_value_label: Label = $Panel/Margin/VBox/FuelRow/FuelValueLabel
@onready var wind_speed_value_label: Label = $Panel/Margin/VBox/WindSpeedRow/WindSpeedValueLabel
@onready var wind_direction_value_label: Label = $Panel/Margin/VBox/WindDirectionRow/WindDirectionValueLabel
@onready var fin_count_value_label: Label = $Panel/Margin/VBox/FinCountRow/FinCountValueLabel
@onready var fin_size_value_label: Label = $Panel/Margin/VBox/FinSizeRow/FinSizeValueLabel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var results_panel: Control = $ResultsPanel
@onready var result_banner: Label = $ResultsPanel/Panel/Margin/VBox/BannerLabel
@onready var max_height_label: Label = $ResultsPanel/Panel/Margin/VBox/MaxHeightLabel
@onready var max_speed_label: Label = $ResultsPanel/Panel/Margin/VBox/MaxSpeedLabel
@onready var stability_score_label: Label = $ResultsPanel/Panel/Margin/VBox/StabilityScoreLabel
@onready var max_tilt_label: Label = $ResultsPanel/Panel/Margin/VBox/MaxTiltLabel
@onready var failure_reason_label: Label = $ResultsPanel/Panel/Margin/VBox/FailureReasonLabel

func _ready() -> void:
	launch_button.pressed.connect(_on_launch_pressed)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	mass_slider.value_changed.connect(_on_slider_changed)
	thrust_slider.value_changed.connect(_on_slider_changed)
	fuel_slider.value_changed.connect(_on_slider_changed)
	wind_speed_slider.value_changed.connect(_on_slider_changed)
	wind_direction_slider.value_changed.connect(_on_slider_changed)
	fin_count_slider.value_changed.connect(_on_slider_changed)
	fin_size_slider.value_changed.connect(_on_slider_changed)
	_update_value_labels()
	results_panel.visible = false
	config_changed.emit(build_config())

func build_config() -> RocketConfig:
	var config := RocketConfig.new()
	config.rocket_mass = mass_slider.value
	config.engine_thrust = thrust_slider.value
	config.fuel_amount = fuel_slider.value
	config.wind_speed = wind_speed_slider.value
	config.wind_direction = wind_direction_slider.value
	config.fin_count = int(fin_count_slider.value)
	config.fin_size = fin_size_slider.value
	return config

func _on_launch_pressed() -> void:
	status_label.text = "In flight"
	results_panel.visible = false
	launch_requested.emit(build_config())

func show_results(results: Dictionary) -> void:
	var success := bool(results["success"])
	results_panel.visible = true
	result_banner.text = "STABLE FLIGHT" if success else "FLIGHT CRASHED"
	result_banner.modulate = Color(0.3, 1.0, 0.45, 1.0) if success else Color(1.0, 0.25, 0.2, 1.0)
	max_height_label.text = "Max height: %.1f m" % results["max_height"]
	max_speed_label.text = "Max speed: %.1f m/s" % results["max_speed"]
	stability_score_label.text = "Stability: %.0f / 100" % results["stability_score"]
	max_tilt_label.text = "Max tilt: %.1f deg" % results["max_tilt"]
	failure_reason_label.text = "Reason: %s" % results["failure_reason"]
	status_label.text = "Flight crashed"

func _on_slider_changed(_value: float) -> void:
	_update_value_labels()
	status_label.text = "Ready"
	config_changed.emit(build_config())

func _update_value_labels() -> void:
	mass_value_label.text = "%.0f kg" % mass_slider.value
	thrust_value_label.text = "%.0f N" % thrust_slider.value
	fuel_value_label.text = "%.0f" % fuel_slider.value
	wind_speed_value_label.text = "%.1f m/s" % wind_speed_slider.value
	wind_direction_value_label.text = "%.0f deg" % wind_direction_slider.value
	fin_count_value_label.text = "%d" % int(fin_count_slider.value)
	fin_size_value_label.text = "%.2f" % fin_size_slider.value
