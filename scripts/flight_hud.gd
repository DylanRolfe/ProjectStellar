extends Control

## A compact telemetry bar shown across the top of the screen during flight.
## Reads the rocket's live stats every frame and refreshes continuously.

@export var rocket_path: NodePath

# key, caption, format, unit
const STATS := [
	["altitude", "ALTITUDE", "%.0f", "m"],
	["speed", "SPEED", "%.0f", "m/s"],
	["max_altitude", "APOGEE", "%.0f", "m"],
	["max_speed", "MAX SPEED", "%.0f", "m/s"],
	["downrange", "DOWNRANGE", "%.0f", "m"],
	["time", "T+", "%.1f", "s"],
]

var _rocket: RocketController
var _value_labels: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rocket = get_node_or_null(rocket_path) as RocketController
	_build()
	visible = false

func _build() -> void:
	# Anchored to the top-right. The results panel lives there too, but it is
	# hidden during flight (when this HUD is shown), so they never clash.
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
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	margin.add_child(hbox)

	for stat in STATS:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER

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
