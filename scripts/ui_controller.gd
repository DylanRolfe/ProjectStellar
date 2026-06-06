class_name UIController
extends Control

signal launch_requested(config: RocketConfig)
signal reset_requested
signal config_changed(config: RocketConfig)

@onready var launch_button: Button = $Panel/Margin/VBox/ButtonRow/LaunchButton
@onready var reset_button: Button = $Panel/Margin/VBox/ButtonRow/ResetButton
@onready var payload_mass_slider: HSlider = $Panel/Margin/VBox/PayloadMassRow/PayloadMassSlider
@onready var thrust_slider: HSlider = $Panel/Margin/VBox/ThrustRow/ThrustSlider
@onready var fuel_slider: HSlider = $Panel/Margin/VBox/FuelRow/FuelSlider
@onready var wind_speed_slider: HSlider = $Panel/Margin/VBox/WindSpeedRow/WindSpeedSlider
@onready var wind_direction_slider: HSlider = $Panel/Margin/VBox/WindDirectionRow/WindDirectionSlider
@onready var body_material_row: HBoxContainer = $Panel/Margin/VBox/BodyMaterialRow
@onready var body_material_option: OptionButton = $Panel/Margin/VBox/BodyMaterialRow/BodyMaterialOption
@onready var fin_count_row: HBoxContainer = $Panel/Margin/VBox/FinCountRow
@onready var fin_count_slider: HSlider = $Panel/Margin/VBox/FinCountRow/FinCountSlider
@onready var fin_size_row: HBoxContainer = $Panel/Margin/VBox/FinSizeRow
@onready var fin_size_slider: HSlider = $Panel/Margin/VBox/FinSizeRow/FinSizeSlider
@onready var payload_mass_value_label: Label = $Panel/Margin/VBox/PayloadMassRow/PayloadMassValueLabel
@onready var thrust_value_label: Label = $Panel/Margin/VBox/ThrustRow/ThrustValueLabel
@onready var fuel_value_label: Label = $Panel/Margin/VBox/FuelRow/FuelValueLabel
@onready var wind_speed_value_label: Label = $Panel/Margin/VBox/WindSpeedRow/WindSpeedValueLabel
@onready var wind_direction_value_label: Label = $Panel/Margin/VBox/WindDirectionRow/WindDirectionValueLabel
@onready var fin_count_value_label: Label = $Panel/Margin/VBox/FinCountRow/FinCountValueLabel
@onready var fin_size_value_label: Label = $Panel/Margin/VBox/FinSizeRow/FinSizeValueLabel
@onready var shell_mass_label: Label = $Panel/Margin/VBox/ShellMassLabel
@onready var fin_mass_label: Label = $Panel/Margin/VBox/FinMassLabel
@onready var total_mass_label: Label = $Panel/Margin/VBox/TotalMassLabel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var flight_data_label: Label = $Panel/Margin/VBox/FlightDataLabel
@onready var fuel_data_label: Label = $Panel/Margin/VBox/FuelDataLabel
@onready var results_panel: Control = $ResultsPanel
@onready var result_banner: Label = $ResultsPanel/Panel/Margin/VBox/BannerLabel
@onready var max_height_label: Label = $ResultsPanel/Panel/Margin/VBox/MaxHeightLabel
@onready var max_speed_label: Label = $ResultsPanel/Panel/Margin/VBox/MaxSpeedLabel
@onready var flight_time_label: Label = $ResultsPanel/Panel/Margin/VBox/FlightTimeLabel
@onready var x_displacement_label: Label = $ResultsPanel/Panel/Margin/VBox/XDisplacementLabel
@onready var stability_score_label: Label = $ResultsPanel/Panel/Margin/VBox/StabilityScoreLabel
@onready var max_tilt_label: Label = $ResultsPanel/Panel/Margin/VBox/MaxTiltLabel
@onready var failure_reason_label: Label = $ResultsPanel/Panel/Margin/VBox/FailureReasonLabel

var _base_config: RocketConfig = RocketConfig.new()

func _ready() -> void:
	launch_button.pressed.connect(_on_launch_pressed)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	fin_count_row.visible = false
	fin_size_row.visible = false
	_populate_body_materials()
	payload_mass_slider.value_changed.connect(_on_slider_changed)
	thrust_slider.value_changed.connect(_on_slider_changed)
	fuel_slider.value_changed.connect(_on_slider_changed)
	wind_speed_slider.value_changed.connect(_on_slider_changed)
	wind_direction_slider.value_changed.connect(_on_slider_changed)
	body_material_option.item_selected.connect(func(_idx: int) -> void: _on_slider_changed(0.0))
	_update_value_labels()
	results_panel.visible = false
	config_changed.emit(build_config())

func set_base_config(config: RocketConfig) -> void:
	_base_config = config.duplicate(true) as RocketConfig
	_update_value_labels()

func _populate_body_materials() -> void:
	body_material_option.clear()
	var selected_index := 0
	var names := MaterialDatabase.material_names()
	for i in range(names.size()):
		var material_name: String = names[i]
		body_material_option.add_item(material_name.capitalize())
		body_material_option.set_item_metadata(i, material_name)
		if material_name == "aluminum":
			selected_index = i
	body_material_option.select(selected_index)

func build_config() -> RocketConfig:
	var config: RocketConfig = _base_config.duplicate(true) as RocketConfig
	config.payload_mass = payload_mass_slider.value
	config.engine_thrust = thrust_slider.value
	config.fuel_amount = fuel_slider.value
	config.wind_speed = wind_speed_slider.value
	config.wind_direction = wind_direction_slider.value
	config.body_material_name = _selected_body_material_name()
	config.recalculate_masses()
	return config

func apply_demo_preset(preset_name: String) -> void:
	match preset_name:
		"bad":
			payload_mass_slider.value = 35.0
			thrust_slider.value = 900.0
			fuel_slider.value = 38.0
			wind_speed_slider.value = 34.0
			wind_direction_slider.value = 90.0
			_select_body_material("steel")
		"good":
			payload_mass_slider.value = 12.0
			thrust_slider.value = 900.0
			fuel_slider.value = 38.0
			wind_speed_slider.value = 34.0
			wind_direction_slider.value = 90.0
			_select_body_material("carbon_fiber")
	_update_value_labels()
	status_label.text = "Ready"
	config_changed.emit(build_config())

func set_hud_mode(enabled: bool) -> void:
	payload_mass_slider.editable = not enabled
	thrust_slider.editable = not enabled
	fuel_slider.editable = not enabled
	wind_speed_slider.editable = not enabled
	wind_direction_slider.editable = not enabled
	body_material_option.disabled = enabled
	launch_button.disabled = enabled
	status_label.text = "In flight" if enabled else "Ready"
	flight_data_label.visible = enabled
	fuel_data_label.visible = enabled
	if enabled:
		results_panel.visible = false

func update_flight_data(altitude: float, fuel: float) -> void:
	flight_data_label.text = "Altitude: %.1f m" % altitude
	fuel_data_label.text = "Fuel: %.1f kg" % fuel

func _on_launch_pressed() -> void:
	status_label.text = "In flight"
	results_panel.visible = false
	launch_requested.emit(build_config())

func show_results(results: Dictionary) -> void:
	var success := bool(results["success"])
	results_panel.visible = true
	result_banner.text = "STABLE FLIGHT" if success else "FLIGHT FAILED"
	result_banner.modulate = Color(0.3, 1.0, 0.45, 1.0) if success else Color(1.0, 0.25, 0.2, 1.0)
	max_height_label.text = "Max height: %.1f m" % results["max_height"]
	max_speed_label.text = "Max speed: %.1f m/s" % results["max_speed"]
	flight_time_label.text = "Flight time: %.1f s" % results.get("flight_time", 0.0)
	x_displacement_label.text = "X displacement: %.1f m" % results.get("x_displacement", 0.0)
	stability_score_label.text = "Stability: %.0f / 100" % results["stability_score"]
	max_tilt_label.text = "Max tilt: %.1f deg" % results["max_tilt"]
	failure_reason_label.text = "Reason: %s" % results["failure_reason"]
	status_label.text = "Stable flight" if success else "Flight failed"

func _on_slider_changed(_value: float) -> void:
	_update_value_labels()
	status_label.text = "Ready"
	config_changed.emit(build_config())

func _update_value_labels() -> void:
	var display_config := build_config()
	payload_mass_value_label.text = "%.0f kg" % payload_mass_slider.value
	thrust_value_label.text = "%.0f N" % thrust_slider.value
	fuel_value_label.text = "%.0f" % fuel_slider.value
	wind_speed_value_label.text = "%.1f m/s" % wind_speed_slider.value
	wind_direction_value_label.text = "%.0f deg" % wind_direction_slider.value
	fin_count_value_label.text = "%d" % int(fin_count_slider.value)
	fin_size_value_label.text = "%.2f" % fin_size_slider.value
	shell_mass_label.text = "Shell mass: %.1f kg" % display_config.body_shell_mass
	fin_mass_label.text = "Fin mass: %.1f kg" % display_config.fin_mass
	total_mass_label.text = "Total launch mass: %.1f kg" % display_config.total_launch_mass

func _selected_body_material_name() -> String:
	var metadata: Variant = body_material_option.get_item_metadata(body_material_option.selected)
	return str(metadata) if metadata != null else "aluminum"

func _select_body_material(material_name: String) -> void:
	for i in range(body_material_option.get_item_count()):
		if str(body_material_option.get_item_metadata(i)) == material_name:
			body_material_option.select(i)
			return
