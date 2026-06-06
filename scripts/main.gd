extends Node3D

@onready var rocket: RocketController = $Rocket

func _ready() -> void:
	var camera := $Camera3D as Camera3D
	camera.current = true
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_SPACE):
		rocket.launch()
