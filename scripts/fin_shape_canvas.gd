class_name FinShapeCanvas
extends Control

signal shape_changed(points: Array[Vector2])

const GRID_SIZE: int = 3
const POINT_RADIUS: float = 7.0
const PICK_RADIUS: float = 16.0

var points: Array[Vector2] = []
var _selected_index: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(320, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	reset_points()

func reset_points() -> void:
	points = [
		Vector2(0.00, 0.00), Vector2(0.50, 0.00), Vector2(1.00, 0.00),
		Vector2(0.00, 0.50), Vector2(0.55, 0.45), Vector2(1.00, 0.55),
		Vector2(0.00, 1.00), Vector2(0.45, 1.00), Vector2(0.82, 1.00),
	]
	queue_redraw()
	shape_changed.emit(points.duplicate())

func set_points(new_points: Array[Vector2]) -> void:
	points.clear()
	for p in new_points:
		points.append(p)
	queue_redraw()
	shape_changed.emit(points.duplicate())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_selected_index = _pick_point(event.position)
		else:
			_selected_index = -1
	elif event is InputEventMouseMotion and _selected_index >= 0:
		points[_selected_index] = _canvas_to_normalized(event.position)
		queue_redraw()
		shape_changed.emit(points.duplicate())

func _draw() -> void:
	var rect := _edit_rect()
	draw_rect(rect, Color(0.06, 0.08, 0.10, 0.95), true)
	draw_rect(rect, Color(0.35, 0.70, 0.95, 0.75), false, 2.0)

	for i in range(GRID_SIZE):
		var t := float(i) / float(GRID_SIZE - 1)
		var x := lerpf(rect.position.x, rect.end.x, t)
		var y := lerpf(rect.position.y, rect.end.y, t)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.16, 0.24, 0.30), 1.0)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.16, 0.24, 0.30), 1.0)

	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE - 1):
			var idx := row * GRID_SIZE + col
			draw_line(_normalized_to_canvas(points[idx]), _normalized_to_canvas(points[idx + 1]), Color(0.25, 0.75, 1.0), 2.0)
	for col in range(GRID_SIZE):
		for row in range(GRID_SIZE - 1):
			var idx := row * GRID_SIZE + col
			draw_line(_normalized_to_canvas(points[idx]), _normalized_to_canvas(points[idx + GRID_SIZE]), Color(0.25, 0.75, 1.0), 2.0)

	for i in range(points.size()):
		var p := _normalized_to_canvas(points[i])
		var color := Color(1.0, 0.85, 0.25) if i == _selected_index else Color(1.0, 0.55, 0.18)
		draw_circle(p, POINT_RADIUS, color)
		draw_arc(p, POINT_RADIUS, 0.0, TAU, 20, Color(0.05, 0.04, 0.03), 1.5)

func _pick_point(canvas_pos: Vector2) -> int:
	var best_idx := -1
	var best_dist := PICK_RADIUS
	for i in range(points.size()):
		var dist := canvas_pos.distance_to(_normalized_to_canvas(points[i]))
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

func _edit_rect() -> Rect2:
	var margin := 22.0
	var side := minf(size.x, size.y) - margin * 2.0
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	return Rect2(origin, Vector2(side, side))

func _normalized_to_canvas(point: Vector2) -> Vector2:
	var rect := _edit_rect()
	return rect.position + Vector2(point.x * rect.size.x, point.y * rect.size.y)

func _canvas_to_normalized(canvas_pos: Vector2) -> Vector2:
	var rect := _edit_rect()
	var local := (canvas_pos - rect.position) / rect.size
	return Vector2(clampf(local.x, 0.0, 1.0), clampf(local.y, 0.0, 1.0))
