class_name FinEditor
extends Node3D

signal fins_confirmed(fin_data: FinData)

const HANDLE_RADIUS: float = 0.035
const PICK_THRESHOLD: float = 0.08
const SUBDIVISIONS: int = 10
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

var points: Array[Vector3] = []
var handle_nodes: Array[MeshInstance3D] = []
var selected_index: int = -1
var is_dragging: bool = false
var fin_data: FinData = FinData.new()

func _ready() -> void:
	_reset_points()

	fin_count_slider.value_changed.connect(_on_fin_count_changed)
	thickness_slider.value_changed.connect(_on_thickness_changed)
	material_option.item_selected.connect(_on_material_changed)
	continue_button.pressed.connect(_on_continue)

	_populate_materials()
	_rebuild_all()

func _reset_points() -> void:
	points.clear()
	for p in DEFAULT_POINTS:
		points.append(p)

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

func _update_handle_positions() -> void:
	_ensure_handles()
	for i in range(min(points.size(), handle_nodes.size())):
		handle_nodes[i].position = points[i]
		handle_nodes[i].visible = true
	for i in range(points.size(), handle_nodes.size()):
		handle_nodes[i].visible = false

func _regenerate_fin_mesh() -> void:
	fin_data.control_points = points.duplicate()
	fin_data.thickness = thickness_slider.value
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
	var root_to_tip_le := points[2] - points[0]
	return root_to_tip_le.length()

func _compute_fin_root_chord() -> float:
	return (points[1] - points[0]).length()

func _compute_fin_tip_chord() -> float:
	return (points[3] - points[2]).length()

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

		var basis := Basis()
		basis.x = Vector3.DOWN
		basis.y = radial
		basis.z = tangent
		fin_inst.basis = basis
		preview_fins.add_child(fin_inst)

func _on_fin_count_changed(_val: float) -> void:
	fin_count_value.text = "%d" % int(fin_count_slider.value)
	_update_rocket_preview()

func _on_thickness_changed(_val: float) -> void:
	thickness_value.text = "%.3f m" % thickness_slider.value
	_regenerate_fin_mesh()
	_update_rocket_preview()

func _on_material_changed(_idx: int) -> void:
	_regenerate_fin_mesh()
	_update_rocket_preview()

func _on_continue() -> void:
	fin_data = FinData.new()
	fin_data.control_points = points.duplicate()
	fin_data.thickness = thickness_slider.value
	fin_data.fin_count = int(fin_count_slider.value)
	fin_data.material_name = MaterialDatabase.material_names()[material_option.selected]
	fin_data.fin_span = _compute_fin_span()
	fin_data.fin_root_chord = _compute_fin_root_chord()
	fin_data.fin_tip_chord = _compute_fin_tip_chord()
	fin_data.compute_mesh(SUBDIVISIONS)

	fins_confirmed.emit(fin_data)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_pick_handle(event.position)
			else:
				is_dragging = false
				selected_index = -1

	if event is InputEventMouseMotion and is_dragging and selected_index >= 0:
		_drag_handle(event.position)

func _try_pick_handle(screen_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state
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
