extends Control

## A compact telemetry bar shown across the top-right during flight. Reads the
## rocket's live stats every frame and refreshes continuously. Hover any stat
## for a short explanation.

@export var rocket_path: NodePath

# key, caption, format, unit, tooltip
const STATS := [
	["altitude", "ALTITUDE", "%.0f", "m", "Height above the launch pad right now."],
	["speed", "SPEED", "%.0f", "m/s", "How fast the rocket is moving right now."],
	["mass", "MASS", "%.1f", "kg", "Current total mass. Falls as propellant burns, then holds at the dry mass."],
	["max_altitude", "APOGEE", "%.0f", "m", "The highest altitude reached so far this flight."],
	["max_speed", "MAX SPEED", "%.0f", "m/s", "The fastest speed reached so far this flight."],
	["downrange", "DOWNRANGE", "%.0f", "m", "Horizontal distance the rocket has drifted from the pad (mostly from wind)."],
	["time", "T+", "%.1f", "s", "Time elapsed since liftoff."],
]

var _rocket: RocketController
var _value_labels: Dictionary = {}
var _info_popup: PanelContainer
var _info_label: Label
var _info_anchor: Control = null

func _ready() -> void:
	# IGNORE so the full-screen root never blocks the UI/camera; the small stat
	# columns below use PASS so they can still show hover tooltips.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rocket = get_node_or_null(rocket_path) as RocketController
	_build()
	visible = false

func _build() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -16.0
	panel.offset_right = -16.0
	panel.offset_top = 12.0
	panel.offset_bottom = 12.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(hbox)

	for stat in STATS:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		# PASS: receives the left-click for the info popup but still lets right-click
		# fall through so the camera can be orbited even over the HUD during flight.
		col.mouse_filter = Control.MOUSE_FILTER_PASS
		col.mouse_default_cursor_shape = Control.CURSOR_HELP
		var info: String = stat[4]
		col.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_toggle_info(col, info))

		var caption := Label.new()
		caption.text = stat[1]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 10)
		caption.modulate = Color(0.45, 0.74, 0.97)
		col.add_child(caption)

		var value := Label.new()
		value.text = "—"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 20)
		col.add_child(value)

		hbox.add_child(col)
		_value_labels[stat[0]] = value

	_build_info_popup()

func _build_info_popup() -> void:
	_info_popup = PanelContainer.new()
	_info_popup.visible = false
	_info_popup.top_level = true
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

func _toggle_info(anchor: Control, text: String) -> void:
	if _info_popup.visible and _info_anchor == anchor:
		_info_popup.visible = false
		_info_anchor = null
		return
	_info_label.text = text
	_info_anchor = anchor
	_info_popup.visible = true
	_info_popup.reset_size()
	# Drop the popup just below the clicked stat, kept on-screen.
	var pos := Vector2(anchor.global_position.x, anchor.global_position.y + anchor.size.y + 6.0)
	var view := get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, view.x - _info_popup.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, view.y - _info_popup.size.y - 8.0)
	_info_popup.global_position = pos

func _process(_delta: float) -> void:
	if _rocket == null or not _rocket.is_flying():
		if visible:
			visible = false
		return
	visible = true
	var telemetry := _rocket.get_live_telemetry()
	for stat in STATS:
		var key: String = stat[0]
		var label: Label = _value_labels[key]
		label.text = (stat[2] % float(telemetry.get(key, 0.0))) + " " + stat[3]
