class_name UIController
extends Control

signal launch_requested(config: RocketConfig)
signal reset_requested
signal back_to_start_requested
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
@onready var wind_direction_slider: RadialSlider = $Panel/Margin/VBox/WindDirectionRow/WindDirectionDial
@onready var body_material_option: OptionButton = $Panel/Margin/VBox/BodyMaterialRow/BodyMaterialOption
@onready var advanced_wind_button: Button = $Panel/Margin/VBox/WindSpeedRow/AdvancedWindButton
@onready var wind_advanced_panel: WindAdvancedPanel = $WindAdvancedPanel
@onready var defaults_button: Button = $Panel/Margin/VBox/ActionRow/DefaultsButton
@onready var back_to_start_button: Button = $Panel/Margin/VBox/ActionRow/BackToStartButton

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
	advanced_wind_button.pressed.connect(_open_wind_advanced)
	wind_advanced_panel.back_pressed.connect(_close_wind_advanced)
	wind_advanced_panel.changed.connect(func() -> void: config_changed.emit(build_config()))
	wind_advanced_panel.reset_requested.connect(func() -> void:
		wind_advanced_panel.apply_reset(wind_speed_slider.value, wind_direction_slider.value))
	defaults_button.pressed.connect(reset_to_defaults)
	back_to_start_button.pressed.connect(func() -> void: back_to_start_requested.emit())
	_setup_tooltips()
	_update_value_labels()
	results_panel.visible = false
	config_changed.emit(build_config())

var _info_popup: PanelContainer
var _info_label: Label
var _info_anchor: Control = null

# Click a control's name (the cursor shows a help shape) to pop up an explanation.
func _setup_tooltips() -> void:
	_build_info_popup()
	var tips := {
		dry_mass_slider: "Dry mass — the empty airframe/structure mass, with no propellant or payload.",
		payload_slider: "Payload mass carried by the rocket (instruments, etc.). Adds weight.",
		propellant_slider: "Mass of propellant burned by the engine. More gives a longer, higher flight but adds liftoff weight.",
		thrust_slider: "Average engine thrust. Must beat the rocket's weight (thrust-to-weight > 1) to lift off.",
		burn_time_slider: "How long the engine burns. The thrust is delivered over this time.",
		diameter_slider: "Body diameter. A wider rocket has more aerodynamic drag (larger frontal area).",
		length_slider: "Body length. Affects the rocket's aerodynamics and stability.",
		wind_speed_slider: "Wind speed at the pad. Stronger wind pushes the rocket downrange.",
		wind_direction_slider: "Wind direction, like a compass (drag the dial). Sets which way the wind blows.",
		body_material_option: "Body material. Changes the body's drag and look.",
	}
	for control in tips:
		_register_row_help(control as Control, tips[control])
	_make_info_trigger(liftoff_mass_label, "Total mass at liftoff: dry mass + payload + propellant.")
	_make_info_trigger(twr_label, "Thrust-to-weight ratio. Below 1 the rocket can't lift off; ~3-6 is a healthy launch.")

func _build_info_popup() -> void:
	_info_popup = PanelContainer.new()
	_info_popup.visible = false
	_info_popup.top_level = true  # position in absolute screen coords
	_info_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_popup.z_index = 100
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(240, 0)
	margin.add_child(_info_label)
	_info_popup.add_child(margin)
	add_child(_info_popup)

# Wire the row's leading name label as the click target for help.
func _register_row_help(control: Control, text: String) -> void:
	var row := control.get_parent()
	if row != null and row.get_child_count() > 0:
		var name_label := row.get_child(0) as Control
		if name_label != null:
			_make_info_trigger(name_label, text)

func _make_info_trigger(node: Control, text: String) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.mouse_default_cursor_shape = Control.CURSOR_HELP
	node.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_toggle_info(node, text))

func _toggle_info(anchor: Control, text: String) -> void:
	if _info_popup.visible and _info_anchor == anchor:
		_hide_info()
		return
	_info_label.text = text
	_info_anchor = anchor
	_info_popup.visible = true
	_info_popup.reset_size()
	# Float the popup just to the right of the controls panel, at the clicked row.
	var panel := $Panel as Control
	var pos := Vector2(panel.global_position.x + panel.size.x + 8.0, anchor.global_position.y)
	var view := get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, view.x - _info_popup.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, view.y - _info_popup.size.y - 8.0)
	_info_popup.global_position = pos

func _hide_info() -> void:
	if _info_popup != null:
		_info_popup.visible = false
		_info_anchor = null

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
	config.wind_advanced = wind_advanced_panel.is_enabled()
	config.wind_layers = wind_advanced_panel.get_layers()
	config.body_material_name = _selected_body_material_name()
	config.recalculate_masses()
	return config

func reset_to_defaults() -> void:
	_hide_info()
	dry_mass_slider.value = 5.0
	payload_slider.value = 1.0
	propellant_slider.value = 4.0
	thrust_slider.value = 500.0
	burn_time_slider.value = 3.0
	diameter_slider.value = 12.0
	length_slider.value = 1.6
	wind_speed_slider.value = 2.0
	wind_direction_slider.value = 0.0
	for i in range(body_material_option.get_item_count()):
		if str(body_material_option.get_item_metadata(i)) == "aluminum":
			body_material_option.select(i)
			break
	# The advanced wind page has its own "Reset to Default" — leave it alone here.
	_update_value_labels()
	status_label.text = "Ready"
	config_changed.emit(build_config())

func _open_wind_advanced() -> void:
	wind_advanced_panel.initialize_from_simple(wind_speed_slider.value, wind_direction_slider.value)
	$Panel.visible = false
	wind_advanced_panel.visible = true

func _close_wind_advanced() -> void:
	wind_advanced_panel.visible = false
	$Panel.visible = true

func set_status(message: String) -> void:
	status_label.text = message

func set_hud_mode(enabled: bool) -> void:
	for slider in _sliders():
		slider.editable = not enabled
	body_material_option.disabled = enabled
	launch_button.disabled = enabled
	advanced_wind_button.disabled = enabled
	defaults_button.disabled = enabled
	wind_advanced_panel.set_interactive(not enabled)
	if enabled:
		_close_wind_advanced()
		results_panel.visible = false
	else:
		status_label.text = "Ready"

func _on_launch_pressed() -> void:
	_hide_info()
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
	_hide_info()
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
