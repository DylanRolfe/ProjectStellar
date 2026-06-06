class_name SimulationManager
extends Node

signal results_ready(results: Dictionary)

@export var rocket_path: NodePath

var _rocket: RocketController
var _running: bool = false
var _elapsed: float = 0.0

const MAX_FLIGHT_TIME: float = 30.0

func _ready() -> void:
	_rocket = get_node(rocket_path) as RocketController
	_rocket.flight_finished.connect(_on_flight_finished)

func start_launch(config: RocketConfig) -> void:
	_running = true
	_elapsed = 0.0
	_rocket.setup(config)
	_rocket.launch()

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed >= MAX_FLIGHT_TIME:
		_rocket.force_finish("Flight timed out after %.0f seconds" % MAX_FLIGHT_TIME)

func _on_flight_finished(reason: String) -> void:
	if not _running:
		return
	_running = false
	results_ready.emit(ResultsCalculator.build_results(_rocket, reason))
