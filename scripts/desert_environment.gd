extends Node3D

const MODEL_PATH := "res://assets/models/low-poly_desert_scene.glb"

@export_group("Scale & Ground Alignment")
@export var model_scale: float = 1.0
@export var y_offset: float = 0.0
@export var floor_scale: float = 1000.0
@export var scatter_y_offset: float = 0.7
@export var hide_mountains: bool = true

@export_group("Bumpy Sand Visuals")
@export var use_bumpy_sand: bool = true
@export var bumpy_floor_size: float = 2200.0
@export var bumpy_floor_subdivisions: int = 180
@export var bump_height: float = 0.45
@export var bump_scale: float = 0.015
@export var hide_original_floor_when_bumpy: bool = true

@export_group("Scatter")
@export var scatter_count: int = 120
@export var scatter_radius: float = 850.0
@export var clear_radius: float = 200.0
@export var scatter_random_rotation: bool = true
@export var scatter_scale_variance: float = 0.25
@export var scatter_seed: int = 42
@export var min_spacing: float = 6.0  # metres — keep scattered props from overlapping

var _instance: Node3D
var _scatter_root: Node3D
var _occupied: Dictionary = {}  # spatial hash of placed prop positions (Vector2 xz)


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

	# Make only the original sand/floor huge, not the cactus, rocks, barrels, or mountains.
	# If bumpy sand is enabled, we hide this original floor after scaling it.
	_scale_nodes_with_prefix(_instance, "Plane", Vector3(floor_scale, 1.0, floor_scale))

	# Add a bumpy visual sand floor. This is visual only and does not affect rocket physics.
	if use_bumpy_sand:
		_create_bumpy_sand_floor()

		if hide_original_floor_when_bumpy:
			_set_nodes_with_prefix_visible(_instance, "Plane", false)

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
		copy.global_position = _spaced_position(rng, original_y + scatter_y_offset)

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


# Picks a random position that keeps at least `min_spacing` from already-placed
# props, using a spatial hash so the check stays cheap even with many props.
func _spaced_position(rng: RandomNumberGenerator, y_value: float) -> Vector3:
	for _attempt in range(12):
		var candidate := _random_position(rng, y_value)
		var flat := Vector2(candidate.x, candidate.z)
		if _is_spaced(flat):
			_register(flat)
			return candidate
	# Couldn't find a clear spot — place it anyway so the count is preserved.
	var fallback := _random_position(rng, y_value)
	_register(Vector2(fallback.x, fallback.z))
	return fallback


func _spatial_cell(flat: Vector2) -> Vector2i:
	var inv := 1.0 / maxf(min_spacing, 0.1)
	return Vector2i(int(floor(flat.x * inv)), int(floor(flat.y * inv)))


func _is_spaced(flat: Vector2) -> bool:
	var cell := _spatial_cell(flat)
	var min_sq := min_spacing * min_spacing
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := cell + Vector2i(dx, dy)
			if _occupied.has(key):
				for other in _occupied[key]:
					if flat.distance_squared_to(other) < min_sq:
						return false
	return true


func _register(flat: Vector2) -> void:
	var cell := _spatial_cell(flat)
	if not _occupied.has(cell):
		_occupied[cell] = []
	_occupied[cell].append(flat)


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


func _create_bumpy_sand_floor() -> void:
	var sand := MeshInstance3D.new()
	sand.name = "BumpySandFloor"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(bumpy_floor_size, bumpy_floor_size)
	mesh.subdivide_width = bumpy_floor_subdivisions
	mesh.subdivide_depth = bumpy_floor_subdivisions

	sand.mesh = mesh
	sand.position.y = y_offset + 0.03
	sand.material_override = _create_bumpy_sand_material()

	add_child(sand)


func _create_bumpy_sand_material() -> ShaderMaterial:
	var shader := Shader.new()

	shader.code = """
shader_type spatial;

uniform float bump_height = 0.45;
uniform float bump_scale = 0.015;
uniform vec3 sand_dark : source_color = vec3(0.52, 0.36, 0.18);
uniform vec3 sand_light : source_color = vec3(0.88, 0.68, 0.36);

varying vec2 ground_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) +
		(c - a) * u.y * (1.0 - u.x) +
		(d - b) * u.x * u.y;
}

void vertex() {
	ground_pos = VERTEX.xz;

	float large_bumps = noise(VERTEX.xz * bump_scale);
	float small_bumps = noise(VERTEX.xz * bump_scale * 5.0) * 0.35;

	// Positive-only displacement so the sand does not dip below the flat world floor.
	float height = (large_bumps * 0.75 + small_bumps) * bump_height;
	VERTEX.y += height;
}

void fragment() {
	float sand_noise = noise(ground_pos * bump_scale * 2.0);
	ALBEDO = mix(sand_dark, sand_light, sand_noise);
	ROUGHNESS = 0.95;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("bump_height", bump_height)
	material.set_shader_parameter("bump_scale", bump_scale)

	return material


func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0

	for child in node.get_children():
		_strip_collision(child)
