extends Camera3D

@export var target_path: NodePath
@export var distance: float = 8.0
@export var min_distance: float = 3.0
@export var max_distance: float = 25.0
@export var height_offset: float = 1.2
@export var follow_smoothing: float = 0.0
@export var orbit_sensitivity: float = 0.008
# Proportional zoom: distance is multiplied each step, so it feels consistent at
# any range. Smaller = stronger zoom-in per step.
@export var wheel_zoom: float = 0.82    # per mouse-wheel notch
@export var button_zoom: float = 0.72   # per +/- button press (stronger)

var _target: Node3D
var _focus: Vector3 = Vector3.ZERO
var _yaw: float = 0.4
var _pitch: float = 0.15

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
	# Orbit the rocket by dragging with the RIGHT mouse button held.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * orbit_sensitivity
		# Pulling the mouse down tilts the view down (and vice versa).
		_pitch = clampf(_pitch + event.relative.y * orbit_sensitivity, -0.2, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		# event.factor is fractional on precision trackpads / high-res wheels, so
		# the zoom scales smoothly with the scroll amount rather than jumping.
		var factor: float = event.factor if event.factor > 0.0 else 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_mul(pow(wheel_zoom, factor))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_mul(pow(1.0 / wheel_zoom, factor))
	elif event is InputEventMagnifyGesture:
		# Trackpad pinch — continuous; factor > 1 means spread fingers (zoom in).
		_zoom_mul(1.0 / maxf(event.factor, 0.01))
	elif event is InputEventPanGesture:
		# Trackpad two-finger scroll — continuous.
		_zoom_mul(1.0 + event.delta.y * 0.03)

func _zoom_mul(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)

func zoom_in() -> void:
	_zoom_mul(button_zoom)

func zoom_out() -> void:
	_zoom_mul(1.0 / button_zoom)

func _update_camera(_delta: float) -> void:
	var horizontal_distance := cos(_pitch) * distance
	var offset := Vector3(
		sin(_yaw) * horizontal_distance,
		sin(_pitch) * distance,
		cos(_yaw) * horizontal_distance
	)
	global_position = _focus + offset
	look_at(_focus, Vector3.UP)
