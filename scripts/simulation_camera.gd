extends Camera3D

@export var target_path: NodePath
@export var distance: float = 8.0
@export var min_distance: float = 3.0
@export var max_distance: float = 25.0
@export var height_offset: float = 1.2
@export var follow_smoothing: float = 0.0
@export var orbit_sensitivity: float = 0.008

var _target: Node3D
var _focus: Vector3 = Vector3.ZERO
var _yaw: float = 0.45
var _pitch: float = 0.35

func _ready() -> void:
	current = true
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		_focus = _target.global_position + Vector3.UP * height_offset
	_update_camera(1.0)

func _process(delta: float) -> void:
	if _target:
		var target_focus := _target.global_position + Vector3.UP * height_offset
		if follow_smoothing <= 0.0:
			_focus = target_focus
		else:
			var weight := 1.0 - exp(-follow_smoothing * delta)
			_focus = _focus.lerp(target_focus, weight)
	_update_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * orbit_sensitivity
		_pitch = clampf(_pitch - event.relative.y * orbit_sensitivity, -0.2, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance + 0.7)

func _update_camera(_delta: float) -> void:
	var horizontal_distance := cos(_pitch) * distance
	var offset := Vector3(
		sin(_yaw) * horizontal_distance,
		sin(_pitch) * distance,
		cos(_yaw) * horizontal_distance
	)
	global_position = _focus + offset
	look_at(_focus, Vector3.UP)
