class_name FinEditor
extends Node3D

signal fins_confirmed(fin_data: FinData)
signal fin_data_changed(fin_data: FinData)

const SUBDIVISIONS: int = 10
const FinShapeCanvasScene = preload("res://scripts/fin_shape_canvas.gd")

@onready var editor_canvas: CanvasLayer = $CanvasLayer

@onready var fin_count_slider: HSlider = $CanvasLayer/Panel/Margin/VBox/FinCountRow/HSlider
@onready var fin_count_value: Label = $CanvasLayer/Panel/Margin/VBox/FinCountRow/ValueLabel
@onready var material_option: OptionButton = $CanvasLayer/Panel/Margin/VBox/MaterialRow/OptionButton
@onready var thickness_slider: HSlider = $CanvasLayer/Panel/Margin/VBox/ThicknessRow/HSlider
@onready var thickness_value: Label = $CanvasLayer/Panel/Margin/VBox/ThicknessRow/ValueLabel
@onready var continue_button: Button = $CanvasLayer/Panel/Margin/VBox/ContinueButton
@onready var root_chord_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/RootChord
@onready var tip_chord_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/TipChord
@onready var span_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/Span
@onready var area_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/Area

var shape_points: Array[Vector2] = []
var fin_data: FinData = FinData.new()
var shape_panel: PanelContainer
var shape_canvas: FinShapeCanvas

func _ready() -> void:
	fin_count_slider.value_changed.connect(_on_fin_count_changed)
	thickness_slider.value_changed.connect(_on_thickness_changed)
	material_option.item_selected.connect(_on_material_changed)
	continue_button.pressed.connect(_on_continue)

	_populate_materials()
	_build_shape_step_ui()
	_show_shape_step()
	_rebuild_all()

func set_editor_active(active: bool) -> void:
	visible = active
	editor_canvas.visible = active
	set_process_input(active)

func get_current_fin_data() -> FinData:
	return fin_data

func _build_shape_step_ui() -> void:
	shape_panel = PanelContainer.new()
	shape_panel.offset_left = 16.0
	shape_panel.offset_top = 16.0
	shape_panel.offset_right = 430.0
	shape_panel.offset_bottom = 520.0
	shape_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_canvas.add_child(shape_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	shape_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Fin Shape"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var instructions := Label.new()
	instructions.text = "Root edge locked to rocket. Drag the outer points to shape the fin."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)

	shape_canvas = FinShapeCanvasScene.new()
	shape_canvas.shape_changed.connect(_on_shape_points_changed)
	vbox.add_child(shape_canvas)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	var reset_shape_button := Button.new()
	reset_shape_button.text = "Reset Shape"
	reset_shape_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_shape_button.pressed.connect(func() -> void: shape_canvas.reset_points())
	button_row.add_child(reset_shape_button)

	var next_button := Button.new()
	next_button.text = "Next: Fin Settings"
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(_show_settings_step)
	button_row.add_child(next_button)

func _show_shape_step() -> void:
	shape_panel.visible = true
	$CanvasLayer/Panel.visible = false

func _show_settings_step() -> void:
	shape_panel.visible = false
	$CanvasLayer/Panel.visible = true

func _populate_materials() -> void:
	material_option.clear()
	for mat in MaterialDatabase.material_names():
		material_option.add_item(mat.capitalize())
	material_option.select(0)

func _rebuild_all() -> void:
	_regenerate_fin_mesh()
	_update_info_labels()
	fin_data_changed.emit(fin_data)

func _regenerate_fin_mesh() -> void:
	fin_data.set_shape_points(shape_points)
	fin_data.thickness = thickness_slider.value
	fin_data.fin_count = int(fin_count_slider.value)
	fin_data.material_name = MaterialDatabase.material_names()[material_option.selected]

	fin_data.compute_mesh(SUBDIVISIONS)

func _compute_fin_span() -> float:
	return fin_data.fin_span

func _compute_fin_root_chord() -> float:
	return fin_data.fin_root_chord

func _compute_fin_tip_chord() -> float:
	return fin_data.fin_tip_chord

func _update_info_labels() -> void:
	var rc := _compute_fin_root_chord()
	var tc := _compute_fin_tip_chord()
	var sp := _compute_fin_span()
	root_chord_label.text = "Root: %.2f m" % rc
	tip_chord_label.text = "Tip: %.2f m" % tc
	span_label.text = "Span: %.2f m" % sp
	area_label.text = "Area: %.3f m²" % fin_data.surface_area

func _on_fin_count_changed(_val: float) -> void:
	fin_count_value.text = "%d" % int(fin_count_slider.value)
	_rebuild_all()

func _on_thickness_changed(_val: float) -> void:
	thickness_value.text = "%.3f m" % thickness_slider.value
	_rebuild_all()

func _on_material_changed(_idx: int) -> void:
	_rebuild_all()

func _on_continue() -> void:
	fin_data = FinData.new()
	fin_data.set_shape_points(shape_points)
	fin_data.thickness = thickness_slider.value
	fin_data.fin_count = int(fin_count_slider.value)
	fin_data.material_name = MaterialDatabase.material_names()[material_option.selected]
	fin_data.fin_span = _compute_fin_span()
	fin_data.fin_root_chord = _compute_fin_root_chord()
	fin_data.fin_tip_chord = _compute_fin_tip_chord()
	fin_data.compute_mesh(SUBDIVISIONS)

	fins_confirmed.emit(fin_data)

func _on_shape_points_changed(new_points: Array[Vector2]) -> void:
	shape_points.clear()
	for p in FinData.sanitize_shape_points(new_points):
		shape_points.append(p)
	_rebuild_all()
