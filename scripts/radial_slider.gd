class_name RadialSlider
extends Control

## A ring-shaped dial for picking an angle (0-360 deg). Exposes the same small
## API the dashboard uses for HSliders — `value`, `editable`, and the
## `value_changed` signal — so it can be wired up the same way. 0 deg points up
## (north) and increases clockwise, matching a compass.

signal value_changed(value: float)

@export var editable: bool = true
@export var dial_radius: float = 22.0
@export var value: float = 0.0:
	set(v):
		var wrapped := fposmod(v, 360.0)
		if is_equal_approx(wrapped, value):
			return
		value = wrapped
		queue_redraw()
		value_changed.emit(value)

var _dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(dial_radius * 2.0 + 10.0, dial_radius * 2.0 + 10.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from_position(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_set_from_position(event.position)

func _set_from_position(pos: Vector2) -> void:
	var center := size * 0.5
	var dir := pos - center
	if dir.length() < 1.0:
		return
	# 0 deg = up, clockwise.
	value = rad_to_deg(atan2(dir.x, -dir.y))

func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 5.0
	var accent := Color(0.21961, 0.74118, 0.97255)

	# Ring track.
	draw_arc(center, r, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.35), 2.0, true)
	# Faint tick at north.
	draw_line(center + Vector2(0, -r), center + Vector2(0, -r + 5.0), Color(accent.r, accent.g, accent.b, 0.6), 1.5)

	# Pointer + handle at the current angle.
	var a := deg_to_rad(value)
	var handle := center + Vector2(sin(a), -cos(a)) * r
	draw_line(center, handle, Color(accent.r, accent.g, accent.b, 0.55), 2.0)
	draw_circle(handle, 5.0, accent if editable else Color(0.5, 0.55, 0.6))
	draw_circle(center, 2.5, Color(accent.r, accent.g, accent.b, 0.8))
