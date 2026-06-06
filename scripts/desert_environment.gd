extends Node3D

const MODEL_PATH := "res://assets/models/low-poly_desert_scene.glb"

@export_group("Scale & Ground Alignment")
@export var model_scale: float = 1.0
@export var y_offset: float = 0.0
@export var floor_scale: float = 260.0
@export var scatter_y_offset: float = 0.35
@export var hide_mountains: bool = true

@export_group("Scatter")
@export var scatter_count: int = 80
@export var scatter_radius: float = 250.0
@export var clear_radius: float = 35.0
@export var scatter_random_rotation: bool = true
@export var scatter_scale_variance: float = 0.25
@export var scatter_seed: int = 42

var _instance: Node3D
var _scatter_root: Node3D


func _ready() -> void:
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_warning("DesertEnvironment: failed to load " + MODEL_PATH)
		return

	# Main base scene.
	_instance = packed.instantiate()
	add_child(_instance)
	_instance.scale = Vector3.ONE * model_scale
	_instance.position.y = y_offset
	_strip_collision(_instance)

	# Make only the floor huge, not the cactus/rocks/barrels/mountains.
	_scale_nodes_with_prefix(_instance, "Plane", Vector3(floor_scale, 1.0, floor_scale))

	if hide_mountains:
		_set_nodes_with_prefix_visible(_instance, "Landscape", false)

	# Scatter only individual props, not the whole map.
	_scatter_root = Node3D.new()
	_scatter_root.name = "GeneratedScatterProps"
	add_child(_scatter_root)

	var prop_templates := _collect_prop_templates(_instance)

	if prop_templates.is_empty():
		push_warning("DesertEnvironment: no scatter prop templates found.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	for i in range(scatter_count):
		var template: Node3D = prop_templates[rng.randi_range(0, prop_templates.size() - 1)]
		var copy := template.duplicate() as Node3D
		if copy == null:
			continue

		_scatter_root.add_child(copy)

		# Use the original prop height, then add a small lift so it sits above the sand.
		var original_y := template.global_position.y
		var pos := _random_position(rng, original_y + scatter_y_offset)
		copy.global_position = pos

		if scatter_random_rotation:
			copy.rotation.y = rng.randf_range(0.0, TAU)

		var s := 1.0 + rng.randf_range(-scatter_scale_variance, scatter_scale_variance)
		copy.scale *= s

		_strip_collision(copy)


func _collect_prop_templates(root: Node) -> Array[Node3D]:
	var props: Array[Node3D] = []
	_collect_prop_templates_recursive(root, props)
	return props


func _collect_prop_templates_recursive(node: Node, props: Array[Node3D]) -> void:
	if node is Node3D:
		var node_name := node.name.to_lower()

		# Include small props only.
		# Cylinder = cactus/barrels
		# Icosphere = rocks
		# Torus = barrels/props
		#
		# Exclude:
		# Plane = floor
		# Landscape = mountain
		if node_name.begins_with("cylinder") or node_name.begins_with("icosphere") or node_name.begins_with("torus"):
			props.append(node as Node3D)

	for child in node.get_children():
		_collect_prop_templates_recursive(child, props)


func _random_position(rng: RandomNumberGenerator, y_value: float) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(clear_radius, scatter_radius)
	var x := cos(angle) * radius
	var z := sin(angle) * radius
	return Vector3(x, y_value, z)


func _scale_nodes_with_prefix(node: Node, prefix: String, new_scale: Vector3) -> void:
	if node is Node3D and node.name.begins_with(prefix):
		(node as Node3D).scale = new_scale

	for child in node.get_children():
		_scale_nodes_with_prefix(child, prefix, new_scale)


func _set_nodes_with_prefix_visible(node: Node, prefix: String, visible_value: bool) -> void:
	if node is Node3D and node.name.begins_with(prefix):
		(node as Node3D).visible = visible_value

	for child in node.get_children():
		_set_nodes_with_prefix_visible(child, prefix, visible_value)


func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0

	for child in node.get_children():
		_strip_collision(child)
