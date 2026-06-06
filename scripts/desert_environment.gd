extends Node3D

const MODEL_PATH := "res://assets/models/low-poly_desert_scene.glb"

@export_group("Scale & Ground Alignment")
## Uniform scale for the whole scene. Shrink (e.g. 0.05) if dunes are huge,
## grow (e.g. 5.0) if everything is tiny.
@export var model_scale: float = 1.0
## Shift the model up/down until its sand surface sits flush with y = 0.
@export var y_offset: float = 0.0

@export_group("Scatter")
## Drop extra copies of the scene in a ring around the launch pad.
## Great for filling out the horizon — set count to 0 to disable.
@export var scatter_count: int = 0
## Distance from origin where scattered copies are placed.
@export var scatter_radius: float = 80.0
## Each scatter copy gets a random Y rotation so they don't all face the same way.
@export var scatter_random_rotation: bool = true
## Scale variation on scattered copies. 1.0 = identical to the base copy.
@export var scatter_scale_variance: float = 0.2
## Fixed seed so the layout stays the same every run.
@export var scatter_seed: int = 42

var _instance: Node3D


func _ready() -> void:
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_warning("DesertEnvironment: failed to load " + MODEL_PATH)
		return

	# Base copy — sits at origin, ground aligned to y = 0
	_instance = packed.instantiate()
	add_child(_instance)
	_instance.scale = Vector3.ONE * model_scale
	_instance.position.y = y_offset
	_strip_collision(_instance)

	# Scatter ring
	if scatter_count > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = scatter_seed
		for i in range(scatter_count):
			var angle := TAU * float(i) / float(scatter_count)
			var copy: Node3D = packed.instantiate()
			add_child(copy)
			copy.position = Vector3(
				cos(angle) * scatter_radius,
				y_offset,
				sin(angle) * scatter_radius
			)
			var s := model_scale * (1.0 + rng.randf_range(-scatter_scale_variance, scatter_scale_variance))
			copy.scale = Vector3.ONE * s
			if scatter_random_rotation:
				copy.rotation.y = rng.randf_range(0.0, TAU)
			_strip_collision(copy)


## Zero out collision layers on every physics body in the imported tree so the
## desert can never interfere with the rocket or the flat launch pad.
func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_strip_collision(child)
