class_name WindAdvancedPanel
extends PanelContainer

## Advanced wind editor: three altitude sections, each with its own wind speed
## and angle. Two draggable sliders set the boundary altitudes between the
## sections. Emits `changed` when anything is edited and `back_pressed` when the
## back arrow is used. ui_controller reads is_enabled()/get_layers().

signal back_pressed
signal changed
signal reset_requested

const SPEED_MAX := 25.0
# Default rockets apogee around ~1 km, so the boundary scale tops out a little
# above that to stay useful for typical flights (the top layer covers anything
# higher for edge cases).
const ALT_MAX := 1.2          # km — top of the adjustable range
const ALT_MIN_GAP := 0.1      # km — minimum gap between the two boundaries

# Index 0 = lowest section (ground..b0), 1 = middle (b0..b1), 2 = top (above b1).
var _speed_sliders: Array = [null, null, null]
var _speed_values: Array = [null, null, null]
var _angle_dials: Array = [null, null, null]
var _range_labels: Array = [null, null, null]

var _b0_slider: VSlider      # lower boundary (km)
var _b1_slider: VSlider      # upper boundary (km)
var _b0_label: Label
var _b1_label: Label
var _enable_check: CheckButton

var _enabled: bool = false
var _initialized: bool = false
var _updating: bool = false

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# --- Header: back arrow + title -------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var back := Button.new()
	back.text = "←"
	back.tooltip_text = "Back"
	back.custom_minimum_size = Vector2(38, 0)
	back.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back)
	var title := Label.new()
	title.text = "WIND PROFILE"
	title.theme_type_variation = &"Header"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	root.add_child(header)

	_enable_check = CheckButton.new()
	_enable_check.text = "Use layered wind"
	_enable_check.toggled.connect(func(on: bool) -> void:
		_enabled = on
		changed.emit())
	root.add_child(_enable_check)

	var reset_button := Button.new()
	reset_button.text = "Reset to Default"
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	root.add_child(reset_button)

	# --- Body: sections on the left, two boundary sliders on the right ---
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 8)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(sections)
	# Build top section first so high altitude is at the top, like the scale.
	_build_section(sections, 2)
	_add_divider(sections)
	_build_section(sections, 1)
	_add_divider(sections)
	_build_section(sections, 0)

	body.add_child(_build_boundary_column())

	_enforce_order()
	_refresh_labels()

func _build_section(parent: VBoxContainer, index: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var range_label := Label.new()
	range_label.add_theme_font_size_override("font_size", 12)
	range_label.modulate = Color(0.45, 0.74, 0.97)
	_range_labels[index] = range_label
	box.add_child(range_label)

	# Speed row
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	var slabel := Label.new()
	slabel.text = "Speed"
	slabel.custom_minimum_size = Vector2(50, 0)
	srow.add_child(slabel)
	var sslider := HSlider.new()
	sslider.min_value = 0.0
	sslider.max_value = SPEED_MAX
	sslider.step = 0.5
	sslider.value = 2.0
	sslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sslider.custom_minimum_size = Vector2(90, 0)
	var svalue := Label.new()
	svalue.custom_minimum_size = Vector2(56, 0)
	svalue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sslider.value_changed.connect(func(v: float) -> void:
		svalue.text = "%.1f m/s" % v
		changed.emit())
	srow.add_child(sslider)
	srow.add_child(svalue)
	box.add_child(srow)
	_speed_sliders[index] = sslider
	_speed_values[index] = svalue

	# Angle row
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	var alabel := Label.new()
	alabel.text = "Angle"
	alabel.custom_minimum_size = Vector2(50, 0)
	var dial := RadialSlider.new()
	dial.dial_radius = 17.0
	var avalue := Label.new()
	avalue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avalue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	avalue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dial.value_changed.connect(func(v: float) -> void:
		avalue.text = "%.0f deg" % v
		changed.emit())
	arow.add_child(alabel)
	arow.add_child(dial)
	arow.add_child(avalue)
	box.add_child(arow)
	_angle_dials[index] = dial

	parent.add_child(box)

func _add_divider(parent: VBoxContainer) -> void:
	var line := HSeparator.new()
	parent.add_child(line)

func _build_boundary_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.custom_minimum_size = Vector2(96, 0)

	var caption := Label.new()
	caption.text = "Boundaries (km)"
	caption.add_theme_font_size_override("font_size", 10)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

	var sliders := HBoxContainer.new()
	sliders.add_theme_constant_override("separation", 10)
	sliders.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sliders.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(sliders)

	_b1_slider = _make_boundary_slider(0.8)   # upper boundary
	_b0_slider = _make_boundary_slider(0.4)   # lower boundary
	# Put both vertical sliders side by side, full height.
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	_b0_label = _make_small_label()
	left.add_child(_b0_slider)
	left.add_child(_b0_label)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	_b1_label = _make_small_label()
	right.add_child(_b1_slider)
	right.add_child(_b1_label)
	sliders.add_child(right)
	sliders.add_child(left)

	_b0_slider.value_changed.connect(func(_v: float) -> void: _on_boundary_changed(false))
	_b1_slider.value_changed.connect(func(_v: float) -> void: _on_boundary_changed(true))
	return column

func _make_boundary_slider(value: float) -> VSlider:
	var slider := VSlider.new()
	slider.min_value = ALT_MIN_GAP
	slider.max_value = ALT_MAX
	slider.step = 0.1
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 240)
	slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return slider

func _make_small_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _on_boundary_changed(upper_moved: bool) -> void:
	if _updating:
		return
	_enforce_order(upper_moved)
	_refresh_labels()
	changed.emit()

# Keep the lower boundary at least ALT_MIN_GAP below the upper one.
func _enforce_order(upper_moved: bool = false) -> void:
	_updating = true
	if upper_moved:
		if _b1_slider.value < _b0_slider.value + ALT_MIN_GAP:
			_b0_slider.value = maxf(ALT_MIN_GAP, _b1_slider.value - ALT_MIN_GAP)
	else:
		if _b0_slider.value > _b1_slider.value - ALT_MIN_GAP:
			_b1_slider.value = minf(ALT_MAX, _b0_slider.value + ALT_MIN_GAP)
	_updating = false

func _refresh_labels() -> void:
	var b0 := _b0_slider.value
	var b1 := _b1_slider.value
	_b0_label.text = "%.1f" % b0
	_b1_label.text = "%.1f" % b1
	_range_labels[0].text = "Ground – %.1f km" % b0
	_range_labels[1].text = "%.1f – %.1f km" % [b0, b1]
	_range_labels[2].text = "Above %.1f km" % b1

## Initialise all three sections from the current simple wind (first open only).
func initialize_from_simple(speed: float, angle: float) -> void:
	if _initialized:
		return
	_initialized = true
	for i in range(3):
		_speed_sliders[i].value = speed
		_angle_dials[i].value = angle

func is_enabled() -> bool:
	return _enabled

## Layers ordered low -> high for the solver.
func get_layers() -> Array:
	return [
		{"top": _b0_slider.value * 1000.0, "speed": _speed_sliders[0].value, "angle": _angle_dials[0].value},
		{"top": _b1_slider.value * 1000.0, "speed": _speed_sliders[1].value, "angle": _angle_dials[1].value},
		{"top": 9000.0, "speed": _speed_sliders[2].value, "angle": _angle_dials[2].value},
	]

# Reset called by ui_controller, which passes the main page's current wind so
# all three zones match the simple Wind / Wind-dir controls.
func apply_reset(speed: float, angle: float) -> void:
	_updating = true
	_b0_slider.value = 0.4
	_b1_slider.value = 0.8
	_updating = false
	for i in range(3):
		_speed_sliders[i].value = speed
		_angle_dials[i].value = angle
	_enabled = false
	_enable_check.set_pressed_no_signal(false)
	_initialized = false
	_refresh_labels()
	changed.emit()

func set_interactive(interactive: bool) -> void:
	_enable_check.disabled = not interactive
	for i in range(3):
		_speed_sliders[i].editable = interactive
		_angle_dials[i].editable = interactive
	_b0_slider.editable = interactive
	_b1_slider.editable = interactive
