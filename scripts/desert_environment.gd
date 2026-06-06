extends Node3D

const MODEL_PATH := "res://assets/models/low-poly_desert_scene.glb"

@export_group("Scale & Ground Alignment")
@export var model_scale: float = 1.0
@export var y_offset: float = 0.0
@export var floor_scale: float = 1000.0
@export var scatter_y_offset: float = 0.7
@export var hide_mountains: bool = true

@export_group("Scatter")
@export var scatter_count: int = 120
@export var scatter_radius: float = 850.0
@export var clear_radius: float = 200.0
@export var scatter_random_rotation: bool = true
@export var scatter_scale_variance: float = 0.25
@export var scatter_seed: int = 42

var _instance: Node3D
var _scatter_root: Node3D


func _ready() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_warning("DesertEnvironment: failed to load " + MODEL_PATH)
		return

	_instance = packed.instantiate() as Node3D
	if _instance == null:
		push_warning("DesertEnvironment: model did not instantiate as Node3D")
		return

	add_child(_instance)

	_instance.scale = Vector3.ONE * model_scale
	_instance.position.y = y_offset

	_strip_collision(_instance)

	# Make only the sand/floor huge, not the cactus, rocks, barrels, or mountains.
	_scale_nodes_with_prefix(_instance, "Plane", Vector3(floor_scale, 1.0, floor_scale))

	# Hide the original mountain/landscape.
	if hide_mountains:
		_set_nodes_with_prefix_visible(_instance, "Landscape", false)

	# First collect prop templates while the original props are still visible.
	var prop_templates: Array[Node3D] = []
	_collect_prop_templates_recursive(_instance, prop_templates)

	if prop_templates.is_empty():
		push_warning("DesertEnvironment: no scatter prop templates found.")
		return

	# Then hide original props close to the rocket/launch pad.
	# This keeps the launch zone clear.
	_hide_original_props_near_origin(_instance, clear_radius)

	# Scatter only copied small props, not the whole map.
	_scatter_root = Node3D.new()
	_scatter_root.name = "GeneratedScatterProps"
	add_child(_scatter_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	for i in range(scatter_count):
		var template := prop_templates[rng.randi_range(0, prop_templates.size() - 1)]
		if template == null:
			continue

		var copy := template.duplicate() as Node3D
		if copy == null:
			continue

		_scatter_root.add_child(copy)

		# Force copied props visible in case their original template was hidden later.
		_set_tree_visible(copy, true)

		var original_y := template.global_position.y
		copy.global_position = _random_position(rng, original_y + scatter_y_offset)

		if scatter_random_rotation:
			copy.rotation.y = rng.randf_range(0.0, TAU)

		var s := 1.0 + rng.randf_range(-scatter_scale_variance, scatter_scale_variance)
		copy.scale *= s

		_strip_collision(copy)


func _collect_prop_templates_recursive(node: Node, props: Array[Node3D]) -> void:
	if node is Node3D:
		var node_name := node.name.to_lower()

		if _is_scatter_prop(node_name):
			props.append(node as Node3D)

	for child in node.get_children():
		_collect_prop_templates_recursive(child, props)


func _random_position(rng: RandomNumberGenerator, y_value: float) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(clear_radius, scatter_radius)

	var x := cos(angle) * radius
	var z := sin(angle) * radius

	return Vector3(x, y_value, z)


func _hide_original_props_near_origin(node: Node, radius: float) -> void:
	if node is Node3D:
		var node_3d := node as Node3D
		var node_name := node.name.to_lower()

		if _is_scatter_prop(node_name):
			var pos := node_3d.global_position
			var distance_from_rocket := Vector2(pos.x, pos.z).length()

			if distance_from_rocket < radius:
				node_3d.visible = false

	for child in node.get_children():
		_hide_original_props_near_origin(child, radius)


func _is_scatter_prop(node_name: String) -> bool:
	return (
		node_name.begins_with("cylinder")
		or node_name.begins_with("icosphere")
		or node_name.begins_with("torus")
	)


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


func _set_tree_visible(node: Node, visible_value: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = visible_value

	for child in node.get_children():
		_set_tree_visible(child, visible_value)


func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0

	for child in node.get_children():
		_strip_collision(child)
