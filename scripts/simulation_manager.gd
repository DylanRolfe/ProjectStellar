class_name SimulationManager
extends Node

signal results_ready(results: Dictionary)

@export var rocket_path: NodePath

var _rocket: RocketController
var _running: bool = false

func _ready() -> void:
	_rocket = get_node(rocket_path) as RocketController
	_rocket.flight_finished.connect(_on_flight_finished)

func start_launch(config: RocketConfig) -> void:
	_running = true
	_rocket.setup(config)
	_rocket.launch()

func _on_flight_finished(reason: String) -> void:
	if not _running:
		return
	_running = false
	results_ready.emit(ResultsCalculator.build_results(_rocket, reason))
