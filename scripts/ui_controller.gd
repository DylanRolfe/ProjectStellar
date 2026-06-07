class_name UIController
extends Control

signal launch_requested(config: RocketConfig)
signal reset_requested
signal config_changed(config: RocketConfig)

@onready var launch_button: Button = $Panel/Margin/VBox/ButtonRow/LaunchButton
@onready var reset_button: Button = $Panel/Margin/VBox/ButtonRow/ResetButton

@onready var dry_mass_slider: HSlider = $Panel/Margin/VBox/DryMassRow/DryMassSlider
@onready var payload_slider: HSlider = $Panel/Margin/VBox/PayloadRow/PayloadSlider
@onready var propellant_slider: HSlider = $Panel/Margin/VBox/PropellantRow/PropellantSlider
@onready var thrust_slider: HSlider = $Panel/Margin/VBox/ThrustRow/ThrustSlider
@onready var burn_time_slider: HSlider = $Panel/Margin/VBox/BurnTimeRow/BurnTimeSlider
@onready var diameter_slider: HSlider = $Panel/Margin/VBox/DiameterRow/DiameterSlider
@onready var length_slider: HSlider = $Panel/Margin/VBox/LengthRow/LengthSlider
@onready var wind_speed_slider: HSlider = $Panel/Margin/VBox/WindSpeedRow/WindSpeedSlider
@onready var wind_direction_slider: HSlider = $Panel/Margin/VBox/WindDirectionRow/WindDirectionSlider
@onready var body_material_option: OptionButton = $Panel/Margin/VBox/BodyMaterialRow/BodyMaterialOption

@onready var dry_mass_value: Label = $Panel/Margin/VBox/DryMassRow/DryMassValueLabel
@onready var payload_value: Label = $Panel/Margin/VBox/PayloadRow/PayloadValueLabel
@onready var propellant_value: Label = $Panel/Margin/VBox/PropellantRow/PropellantValueLabel
@onready var thrust_value: Label = $Panel/Margin/VBox/ThrustRow/ThrustValueLabel
@onready var burn_time_value: Label = $Panel/Margin/VBox/BurnTimeRow/BurnTimeValueLabel
@onready var diameter_value: Label = $Panel/Margin/VBox/DiameterRow/DiameterValueLabel
@onready var length_value: Label = $Panel/Margin/VBox/LengthRow/LengthValueLabel
@onready var wind_speed_value: Label = $Panel/Margin/VBox/WindSpeedRow/WindSpeedValueLabel
@onready var wind_direction_value: Label = $Panel/Margin/VBox/WindDirectionRow/WindDirectionValueLabel

@onready var liftoff_mass_label: Label = $Panel/Margin/VBox/LiftoffMassLabel
@onready var twr_label: Label = $Panel/Margin/VBox/TwrLabel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

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

func _sliders() -> Array:
	return [dry_mass_slider, payload_slider, propellant_slider, thrust_slider,
		burn_time_slider, diameter_slider, length_slider, wind_speed_slider,
		wind_direction_slider]

func _ready() -> void:
	launch_button.pressed.connect(_on_launch_pressed)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	_populate_body_materials()
	for slider in _sliders():
		slider.value_changed.connect(_on_slider_changed)
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
	config.body_dry_mass = dry_mass_slider.value
	config.payload_mass = payload_slider.value
	config.propellant_mass = propellant_slider.value
	config.engine_thrust = thrust_slider.value
	config.burn_time = burn_time_slider.value
	config.rocket_radius = diameter_slider.value / 200.0  # cm diameter -> m radius
	config.rocket_height = length_slider.value
	config.wind_speed = wind_speed_slider.value
	config.wind_direction = wind_direction_slider.value
	config.body_material_name = _selected_body_material_name()
	config.recalculate_masses()
	return config

func set_status(message: String) -> void:
	status_label.text = message

func set_hud_mode(enabled: bool) -> void:
	for slider in _sliders():
		slider.editable = not enabled
	body_material_option.disabled = enabled
	launch_button.disabled = enabled
	if not enabled:
		status_label.text = "Ready"
	if enabled:
		results_panel.visible = false

func _on_launch_pressed() -> void:
	status_label.text = "In flight"
	results_panel.visible = false
	launch_requested.emit(build_config())

func show_results(results: Dictionary) -> void:
	var success := bool(results.get("success", false))
	results_panel.visible = true
	result_banner.text = "STABLE FLIGHT" if success else "FLIGHT FAILED"
	result_banner.modulate = Color(0.3, 1.0, 0.45, 1.0) if success else Color(1.0, 0.25, 0.2, 1.0)
	max_height_label.text = "Max height: %.1f m" % results.get("max_height", 0.0)
	max_speed_label.text = "Max speed: %.1f m/s" % results.get("max_speed", 0.0)
	flight_time_label.text = "Flight time: %.1f s" % results.get("flight_time", 0.0)
	x_displacement_label.text = "Downrange: %.1f m" % results.get("x_displacement", 0.0)
	stability_score_label.text = "Stability: %.0f / 100" % results.get("stability_score", 0.0)
	max_tilt_label.text = "Max tilt: %.1f deg" % results.get("max_tilt", 0.0)
	failure_reason_label.text = "Reason: %s" % results.get("failure_reason", "")
	status_label.text = "Stable flight" if success else "Flight failed"

func _on_slider_changed(_value: float) -> void:
	_update_value_labels()
	status_label.text = "Ready"
	config_changed.emit(build_config())

func _update_value_labels() -> void:
	var display_config := build_config()
	dry_mass_value.text = "%.1f kg" % dry_mass_slider.value
	payload_value.text = "%.1f kg" % payload_slider.value
	propellant_value.text = "%.1f kg" % propellant_slider.value
	thrust_value.text = "%.0f N" % thrust_slider.value
	burn_time_value.text = "%.1f s" % burn_time_slider.value
	diameter_value.text = "%.0f cm" % diameter_slider.value
	length_value.text = "%.1f m" % length_slider.value
	wind_speed_value.text = "%.1f m/s" % wind_speed_slider.value
	wind_direction_value.text = "%.0f deg" % wind_direction_slider.value
	liftoff_mass_label.text = "Liftoff mass: %.1f kg" % display_config.total_launch_mass
	var twr := display_config.thrust_to_weight()
	if twr < 1.05:
		twr_label.text = "Thrust-to-weight: %.2f  (won't lift off)" % twr
		twr_label.modulate = Color(1.0, 0.5, 0.3)
	else:
		twr_label.text = "Thrust-to-weight: %.2f" % twr
		twr_label.modulate = Color(1.0, 1.0, 1.0)

func _selected_body_material_name() -> String:
	var metadata: Variant = body_material_option.get_item_metadata(body_material_option.selected)
	return str(metadata) if metadata != null else "aluminum"
