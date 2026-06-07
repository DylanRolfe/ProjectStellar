class_name SimulationManager
extends Node

signal results_ready(results: Dictionary)
signal simulation_state_changed(message: String)

@export var rocket_path: NodePath

var _rocket: RocketController
var _config: RocketConfig
var _bridge: RocketPyBridge = null
var _pending_results: Dictionary = {}

# State machine: IDLE -> SOLVING (waiting on RocketPy) -> FLYING -> IDLE.
enum State { IDLE, SOLVING, FLYING }
var _state: int = State.IDLE
var _elapsed: float = 0.0

const MAX_FLIGHT_TIME: float = 30.0

func _ready() -> void:
	_rocket = get_node(rocket_path) as RocketController
	_rocket.flight_finished.connect(_on_flight_finished)

func start_launch(config: RocketConfig) -> void:
	_config = config
	_pending_results = {}
	_rocket.setup(config)

	# Try the RocketPy solver first; fall back to local physics if it can't run.
	_bridge = RocketPyBridge.new()
	if _bridge.start(config):
		_state = State.SOLVING
		_elapsed = 0.0
		simulation_state_changed.emit("Computing flight…")
	else:
		_bridge = null
		_start_physics_fallback()

func _process(delta: float) -> void:
	match _state:
		State.SOLVING:
			var result := _bridge.poll(delta)
			if result.has("done"):
				var ok: bool = result.get("ok", false)
				var data: Dictionary = result.get("data", {})
				_bridge = null
				if ok and data.has("samples"):
					_start_playback(data)
				else:
					push_warning("RocketPy unavailable — using built-in physics")
					_start_physics_fallback()
		State.FLYING:
			# Only the physics path needs a wall-clock watchdog; trajectory
			# playback ends itself when the samples run out.
			if _pending_results.is_empty():
				_elapsed += delta
				if _elapsed >= MAX_FLIGHT_TIME:
					_rocket.force_finish("Flight timed out after %.0f seconds" % MAX_FLIGHT_TIME)
		_:
			pass

func _start_playback(data: Dictionary) -> void:
	_state = State.FLYING
	_pending_results = (data.get("results", {}) as Dictionary).duplicate()
	simulation_state_changed.emit("In flight")
	var samples: Array = data["samples"]
	var burn_time := float(data.get("burn_time", 0.0))
	_rocket.play_trajectory(samples, burn_time)

func _start_physics_fallback() -> void:
	_state = State.FLYING
	_elapsed = 0.0
	_pending_results = {}  # empty => results come from ResultsCalculator
	simulation_state_changed.emit("In flight")
	_rocket.launch()

func _on_flight_finished(reason: String) -> void:
	if _state != State.FLYING:
		return
	_state = State.IDLE
	if _pending_results.is_empty():
		# Physics path: derive results from what the rocket recorded.
		results_ready.emit(ResultsCalculator.build_results(_rocket, reason))
	else:
		# RocketPy path: the solver already produced the full result set.
		results_ready.emit(_pending_results)
