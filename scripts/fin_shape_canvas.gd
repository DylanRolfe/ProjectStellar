class_name FinShapeCanvas
extends Control

signal shape_changed(points: Array[Vector2])

const POINT_RADIUS: float = 7.0
const PICK_RADIUS: float = 16.0
const ROOT_TOP_INDEX: int = 0
const TIP_TOP_INDEX: int = 1
const TIP_BOTTOM_INDEX: int = 2
const ROOT_BOTTOM_INDEX: int = 3

var points: Array[Vector2] = []
var _selected_index: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(320, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	reset_points()

func reset_points() -> void:
	points.clear()
	for p in FinData.get_default_shape_points():
		points.append(p)
	queue_redraw()
	_emit_shape_changed()

func set_points(new_points: Array[Vector2]) -> void:
	points.clear()
	for p in FinData.sanitize_shape_points(new_points):
		points.append(p)
	queue_redraw()
	_emit_shape_changed()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# All four corners are grabbable now. The root corners are kept on
			# the body (x = 0) by FinData.sanitize_shape_points, so dragging them
			# only slides along the body axis to change the root chord length.
			_selected_index = _pick_point(event.position)
		else:
			_selected_index = -1
	elif event is InputEventMouseMotion and _selected_index >= 0:
		points[_selected_index] = _canvas_to_shape(event.position)
		var sanitized := FinData.sanitize_shape_points(points)
		points.clear()
		for p in sanitized:
			points.append(p)
		queue_redraw()
		_emit_shape_changed()

func _emit_shape_changed() -> void:
	var emitted_points: Array[Vector2] = []
	for p in points:
		emitted_points.append(p)
	shape_changed.emit(emitted_points)

func _draw() -> void:
	var rect := _edit_rect()
	draw_rect(rect, Color(0.06, 0.08, 0.10, 0.95), true)
	draw_rect(rect, Color(0.35, 0.70, 0.95, 0.75), false, 2.0)

	for i in range(5):
		var t := float(i) / 4.0
		var x := lerpf(rect.position.x, rect.end.x, t)
		var y := lerpf(rect.position.y, rect.end.y, t)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.16, 0.24, 0.30), 1.0)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.16, 0.24, 0.30), 1.0)

	var root_top := _shape_to_canvas(points[ROOT_TOP_INDEX])
	var tip_top := _shape_to_canvas(points[TIP_TOP_INDEX])
	var tip_bottom := _shape_to_canvas(points[TIP_BOTTOM_INDEX])
	var root_bottom := _shape_to_canvas(points[ROOT_BOTTOM_INDEX])
	var fill_color := Color(0.08, 0.40, 0.55, 0.35)
	draw_primitive(PackedVector2Array([root_top, tip_top, tip_bottom]), PackedColorArray([fill_color, fill_color, fill_color]), PackedVector2Array())
	draw_primitive(PackedVector2Array([root_top, tip_bottom, root_bottom]), PackedColorArray([fill_color, fill_color, fill_color]), PackedVector2Array())
	draw_polyline(PackedVector2Array([root_top, tip_top, tip_bottom, root_bottom, root_top]), Color(0.25, 0.75, 1.0), 2.0)
	draw_line(root_top, root_bottom, Color(0.35, 1.0, 0.45), 4.0)

	for i in range(points.size()):
		var p := _shape_to_canvas(points[i])
		var is_root := i == ROOT_TOP_INDEX or i == ROOT_BOTTOM_INDEX
		var color: Color
		if i == _selected_index:
			color = Color(1.0, 0.85, 0.25)      # grabbed = yellow
		elif is_root:
			color = Color(0.35, 1.0, 0.45)      # root corners = green
		else:
			color = Color(1.0, 0.55, 0.18)      # tip corners = orange
		draw_circle(p, POINT_RADIUS, color)
		draw_arc(p, POINT_RADIUS, 0.0, TAU, 20, Color(0.05, 0.04, 0.03), 1.5)

func _pick_point(canvas_pos: Vector2) -> int:
	var best_idx := -1
	var best_dist := PICK_RADIUS
	for i in range(points.size()):
		var dist := canvas_pos.distance_to(_shape_to_canvas(points[i]))
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

func _edit_rect() -> Rect2:
	var margin := 22.0
	var side := minf(size.x, size.y) - margin * 2.0
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	return Rect2(origin, Vector2(side, side))

func _shape_to_canvas(point: Vector2) -> Vector2:
	var rect := _edit_rect()
	var nx := point.x / FinData.MAX_TIP_X
	var ny := 1.0 - ((point.y - FinData.MIN_Y) / (FinData.MAX_Y - FinData.MIN_Y))
	return rect.position + Vector2(nx * rect.size.x, ny * rect.size.y)

func _canvas_to_shape(canvas_pos: Vector2) -> Vector2:
	var rect := _edit_rect()
	var local := (canvas_pos - rect.position) / rect.size
	var x := clampf(local.x, 0.0, 1.0) * FinData.MAX_TIP_X
	var y := lerpf(FinData.MAX_Y, FinData.MIN_Y, clampf(local.y, 0.0, 1.0))
	return Vector2(x, y)
