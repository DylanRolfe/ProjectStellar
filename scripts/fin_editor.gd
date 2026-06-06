class_name FinEditor
extends Node3D

signal fins_confirmed(fin_data: FinData)
signal fin_data_changed(fin_data: FinData)
signal demo_preset_selected(preset_name: String)

const HANDLE_RADIUS: float = 0.035
const PICK_THRESHOLD: float = 0.08
const SUBDIVISIONS: int = 10
const ORBIT_SENSITIVITY: float = 0.008
const MIN_CAMERA_DISTANCE: float = 3.0
const MAX_CAMERA_DISTANCE: float = 12.0
const FinShapeCanvasScene = preload("res://scripts/fin_shape_canvas.gd")
const DEFAULT_POINTS: Array = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.4, 0.0, 0.0),
	Vector3(0.05, 0.3, 0.0),
	Vector3(0.3, 0.3, 0.0),
]

@onready var camera: Camera3D = $Camera3D
@onready var fin_root: Node3D = $FinRoot
@onready var fin_mesh_instance: MeshInstance3D = $FinRoot/FinMesh
@onready var rocket_preview: Node3D = $RocketPreview
@onready var preview_body: MeshInstance3D = $RocketPreview/Body
@onready var preview_fins: Node3D = $RocketPreview/PreviewFins
@onready var editor_canvas: CanvasLayer = $CanvasLayer

@onready var fin_count_slider: HSlider = $CanvasLayer/Panel/Margin/VBox/FinCountRow/HSlider
@onready var fin_count_value: Label = $CanvasLayer/Panel/Margin/VBox/FinCountRow/ValueLabel
@onready var material_option: OptionButton = $CanvasLayer/Panel/Margin/VBox/MaterialRow/OptionButton
@onready var thickness_slider: HSlider = $CanvasLayer/Panel/Margin/VBox/ThicknessRow/HSlider
@onready var thickness_value: Label = $CanvasLayer/Panel/Margin/VBox/ThicknessRow/ValueLabel
@onready var bad_preset_button: Button = $CanvasLayer/Panel/Margin/VBox/PresetRow/BadPresetButton
@onready var good_preset_button: Button = $CanvasLayer/Panel/Margin/VBox/PresetRow/GoodPresetButton
@onready var continue_button: Button = $CanvasLayer/Panel/Margin/VBox/ContinueButton
@onready var root_chord_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/RootChord
@onready var tip_chord_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/TipChord
@onready var span_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/Span
@onready var area_label: Label = $CanvasLayer/Panel/Margin/VBox/InfoRow/Area

var points: Array[Vector3] = []
var shape_points: Array[Vector2] = []
var handle_nodes: Array[MeshInstance3D] = []
var selected_index: int = -1
var is_dragging: bool = false
var fin_data: FinData = FinData.new()
var shape_panel: PanelContainer
var shape_canvas: FinShapeCanvas
var _camera_focus: Vector3 = Vector3(0.55, 1.35, 0.0)
var _camera_distance: float = 7.1
var _camera_yaw: float = 0.52
var _camera_pitch: float = 0.24

func _ready() -> void:
	_reset_points()
	_configure_preview_view()

	fin_count_slider.value_changed.connect(_on_fin_count_changed)
	thickness_slider.value_changed.connect(_on_thickness_changed)
	material_option.item_selected.connect(_on_material_changed)
	bad_preset_button.pressed.connect(func() -> void: _apply_demo_preset("bad"))
	good_preset_button.pressed.connect(func() -> void: _apply_demo_preset("good"))
	continue_button.pressed.connect(_on_continue)

	_populate_materials()
	_build_shape_step_ui()
	_show_shape_step()
	_rebuild_all()

func set_editor_active(active: bool) -> void:
	visible = active
	editor_canvas.visible = active
	set_process_input(active)
	if active:
		camera.current = true

func get_current_fin_data() -> FinData:
	return fin_data

func _reset_points() -> void:
	points.clear()
	for p in DEFAULT_POINTS:
		points.append(p)
	shape_points.clear()
	for p in FinData.get_default_shape_points():
		shape_points.append(p)

func _configure_preview_view() -> void:
	rocket_preview.position = Vector3(0.55, 0.0, 0.0)
	rocket_preview.scale = Vector3(1.35, 1.35, 1.35)
	preview_body.position = Vector3(0.0, 1.25, 0.0)
	_camera_focus = Vector3(0.55, 1.35, 0.0)
	_camera_distance = 7.1
	_camera_yaw = 0.52
	_camera_pitch = 0.24
	camera.fov = 62.0
	camera.current = true
	_update_preview_camera()
	fin_root.visible = false

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

func _update_preview_camera() -> void:
	var horizontal_distance := cos(_camera_pitch) * _camera_distance
	var offset := Vector3(
		sin(_camera_yaw) * horizontal_distance,
		sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal_distance
	)
	camera.global_position = _camera_focus + offset
	camera.look_at(_camera_focus, Vector3.UP)

func _populate_materials() -> void:
	material_option.clear()
	for mat in MaterialDatabase.material_names():
		material_option.add_item(mat.capitalize())
	material_option.select(0)
	_ensure_handles()

func _ensure_handles() -> void:
	while handle_nodes.size() < 4:
		var sphere := MeshInstance3D.new()
		sphere.mesh = SphereMesh.new()
		sphere.mesh.radius = HANDLE_RADIUS
		sphere.mesh.height = HANDLE_RADIUS * 2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.6, 0.0)
		mat.metallic = 0.7
		mat.roughness = 0.3
		sphere.material_override = mat
		sphere.name = "Handle%d" % handle_nodes.size()
		fin_root.add_child(sphere)
		handle_nodes.append(sphere)

func _rebuild_all() -> void:
	_update_handle_positions()
	_regenerate_fin_mesh()
	_update_rocket_preview()
	_update_info_labels()
	fin_data_changed.emit(fin_data)

func _update_handle_positions() -> void:
	_ensure_handles()
	for i in range(min(points.size(), handle_nodes.size())):
		handle_nodes[i].position = points[i]
		handle_nodes[i].visible = true
	for i in range(points.size(), handle_nodes.size()):
		handle_nodes[i].visible = false

func _regenerate_fin_mesh() -> void:
	fin_data.set_shape_points(shape_points)
	points.clear()
	for p in fin_data.control_points:
		points.append(p)
	fin_data.thickness = thickness_slider.value
	fin_data.fin_count = int(fin_count_slider.value)
	fin_data.material_name = MaterialDatabase.material_names()[material_option.selected]

	var mesh := fin_data.compute_mesh(SUBDIVISIONS)
	fin_mesh_instance.mesh = mesh

	var names := MaterialDatabase.material_names()
	var name: String = names[material_option.selected]
	var mat_data: Dictionary = MaterialDatabase.get_material(name)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = mat_data.get("color", Color(0.8, 0.82, 0.85))
	mat.metallic = 0.3
	mat.roughness = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fin_mesh_instance.material_override = mat

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

func _update_rocket_preview() -> void:
	for child in preview_fins.get_children():
		child.queue_free()

	var count := int(fin_count_slider.value)
	if count <= 0:
		return

	var mesh := fin_data.cached_mesh
	if mesh == null:
		mesh = fin_data.compute_mesh(SUBDIVISIONS)

	var body_radius := 0.28
	var names := MaterialDatabase.material_names()
	var name: String = names[material_option.selected]
	var mat_data: Dictionary = MaterialDatabase.get_material(name)
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = mat_data.get("color", Color(0.8, 0.82, 0.85))
	fin_mat.metallic = 0.3
	fin_mat.roughness = 0.5

	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))

		var fin_inst := MeshInstance3D.new()
		fin_inst.mesh = mesh
		fin_inst.material_override = fin_mat

		fin_inst.position = radial * body_radius
		fin_inst.position.y = 0.45

		var basis := Basis()
		basis.x = radial
		basis.y = Vector3.UP
		basis.z = tangent
		fin_inst.basis = basis
		preview_fins.add_child(fin_inst)

func _on_fin_count_changed(_val: float) -> void:
	fin_count_value.text = "%d" % int(fin_count_slider.value)
	_rebuild_all()

func _on_thickness_changed(_val: float) -> void:
	thickness_value.text = "%.3f m" % thickness_slider.value
	_rebuild_all()

func _on_material_changed(_idx: int) -> void:
	_rebuild_all()

func _apply_demo_preset(preset_name: String) -> void:
	match preset_name:
		"bad":
			shape_canvas.set_points([
				Vector2(0.0, 0.35),
				Vector2(0.35, 0.15),
				Vector2(0.30, -0.12),
				Vector2(0.0, -0.35),
			])
			fin_count_slider.value = 1.0
			thickness_slider.value = 0.015
			_select_material("plastic")
		"good":
			shape_canvas.set_points([
				Vector2(0.0, 0.35),
				Vector2(0.95, 0.30),
				Vector2(0.85, -0.30),
				Vector2(0.0, -0.35),
			])
			fin_count_slider.value = 4.0
			thickness_slider.value = 0.055
			_select_material("carbon_fiber")
	fin_count_value.text = "%d" % int(fin_count_slider.value)
	thickness_value.text = "%.3f m" % thickness_slider.value
	_rebuild_all()
	demo_preset_selected.emit(preset_name)

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

func _select_material(material_name: String) -> void:
	var names := MaterialDatabase.material_names()
	for i in range(names.size()):
		if names[i] == material_name:
			material_option.select(i)
			return

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_camera_distance = maxf(MIN_CAMERA_DISTANCE, _camera_distance - 0.7)
				_update_preview_camera()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_camera_distance = minf(MAX_CAMERA_DISTANCE, _camera_distance + 0.7)
				_update_preview_camera()
				return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if fin_root.visible and event.pressed:
				_try_pick_handle(event.position)
			else:
				is_dragging = false
				selected_index = -1

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_camera_yaw -= event.relative.x * ORBIT_SENSITIVITY
			_camera_pitch = clampf(_camera_pitch - event.relative.y * ORBIT_SENSITIVITY, -0.2, 1.2)
			_update_preview_camera()
		elif is_dragging and selected_index >= 0:
			_drag_handle(event.position)

func _try_pick_handle(screen_pos: Vector2) -> void:
	var params := PhysicsRayQueryParameters3D.new()
	params.from = camera.project_ray_origin(screen_pos)
	params.to = params.from + camera.project_ray_normal(screen_pos) * 100.0
	params.collide_with_areas = false
	params.collide_with_bodies = false

	var closest_dist := PICK_THRESHOLD
	var closest_idx := -1

	for i in points.size():
		var cp := fin_root.to_global(points[i])
		var inters := Geometry3D.get_closest_point_to_segment(cp, params.from, params.to)
		var dist := inters.distance_to(cp)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	if closest_idx >= 0:
		selected_index = closest_idx
		is_dragging = true
		_highlight_handle(selected_index)

func _highlight_handle(idx: int) -> void:
	for i in handle_nodes.size():
		var mat := handle_nodes[i].material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			handle_nodes[i].material_override = mat
		if i == idx:
			mat.albedo_color = Color(1.0, 1.0, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.0)
		else:
			mat.albedo_color = Color(1.0, 0.6, 0.0)
			mat.emission_enabled = false

func _drag_handle(screen_pos: Vector2) -> void:
	if selected_index < 0 or selected_index >= points.size():
		return

	var cp := fin_root.to_global(points[selected_index])
	var cam_pos := camera.global_position
	var cam_dir := (cp - cam_pos).normalized()
	var drag_plane := Plane(cam_dir, cp)

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)

	var inters: Variant = drag_plane.intersects_ray(ray_origin, ray_dir)
	if inters == null:
		return

	var local_pos := fin_root.to_local(inters)

	if selected_index == 0:
		return

	if selected_index == 1:
		local_pos.y = points[0].y
		local_pos.z = 0.0
		if local_pos.x < 0.05:
			local_pos.x = 0.05
	elif selected_index == 2:
		local_pos.z = 0.0
		if local_pos.y < 0.05:
			local_pos.y = 0.05
		var tip_x := local_pos.x
		var root_x := points[0].x
		if tip_x < root_x - 0.15:
			local_pos.x = root_x - 0.15
	elif selected_index == 3:
		local_pos.z = 0.0
		if local_pos.y < 0.05:
			local_pos.y = 0.05
		if local_pos.x < points[2].x + 0.02:
			local_pos.x = points[2].x + 0.02

	points[selected_index] = local_pos
	_rebuild_all()
