extends Control

## Bottom-right +/- buttons that zoom the simulation camera. Always available
## (during fin/rocket design and flight) as a reliable alternative to scroll.

@export var camera_path: NodePath

var _camera: Node

func _ready() -> void:
	# IGNORE (not PASS): the full-screen root must be transparent to the mouse so
	# clicks fall through to the UI on lower layers. Only the buttons capture input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera = get_node_or_null(camera_path)
	_build()

func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 1.0
	vbox.anchor_top = 1.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vbox.offset_left = -16.0
	vbox.offset_top = -16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_END
	add_child(vbox)

	vbox.add_child(_make_hint("Right click and drag to rotate"))
	vbox.add_child(_make_button("+", "Zoom in", zoom_in))
	vbox.add_child(_make_button("−", "Zoom out", zoom_out))  # minus sign

func _make_hint(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	margin.add_child(label)
	panel.add_child(margin)
	return panel

func _make_button(label: String, tip: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(46.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(handler)
	return button

func zoom_in() -> void:
	if _camera and _camera.has_method("zoom_in"):
		_camera.zoom_in()

func zoom_out() -> void:
	if _camera and _camera.has_method("zoom_out"):
		_camera.zoom_out()
