class_name FinData
extends Resource

const ROOT_TOP_INDEX: int = 0
const TIP_TOP_INDEX: int = 1
const TIP_BOTTOM_INDEX: int = 2
const ROOT_BOTTOM_INDEX: int = 3
const MIN_TIP_X: float = 0.15
const MAX_TIP_X: float = 1.25
const MIN_Y: float = -0.75
const MAX_Y: float = 0.75
const MIN_CHORD_GAP: float = 0.08
const FIN_MASS_SCALE: float = 8.0

var control_points: Array[Vector3] = [
	Vector3(0.0, 0.35, 0.0),
	Vector3(0.75, 0.25, 0.0),
	Vector3(0.75, -0.25, 0.0),
	Vector3(0.0, -0.35, 0.0),
]

var shape_points: Array[Vector2] = [
	Vector2(0.0, 0.35),
	Vector2(0.75, 0.25),
	Vector2(0.75, -0.25),
	Vector2(0.0, -0.35),
]

var thickness: float = 0.04
var fin_count: int = 4
var material_name: String = "aluminum"

var cached_mesh: Mesh = null
var surface_area: float = 0.0
var fin_span: float = 0.3
var fin_root_chord: float = 0.4
var fin_tip_chord: float = 0.25

static func get_default_shape_points() -> Array[Vector2]:
	return [
		Vector2(0.0, 0.35),
		Vector2(0.75, 0.25),
		Vector2(0.75, -0.25),
		Vector2(0.0, -0.35),
	]

static func sanitize_shape_points(raw_points: Array[Vector2]) -> Array[Vector2]:
	var sanitized := get_default_shape_points()
	for i in range(min(raw_points.size(), sanitized.size())):
		sanitized[i] = raw_points[i]

	sanitized[ROOT_TOP_INDEX] = Vector2(0.0, 0.35)
	sanitized[ROOT_BOTTOM_INDEX] = Vector2(0.0, -0.35)

	var tip_top := sanitized[TIP_TOP_INDEX]
	var tip_bottom := sanitized[TIP_BOTTOM_INDEX]
	tip_top.x = clampf(tip_top.x, MIN_TIP_X, MAX_TIP_X)
	tip_bottom.x = clampf(tip_bottom.x, MIN_TIP_X, MAX_TIP_X)
	tip_top.y = clampf(tip_top.y, MIN_Y, MAX_Y)
	tip_bottom.y = clampf(tip_bottom.y, MIN_Y, MAX_Y)

	if tip_top.y <= tip_bottom.y + MIN_CHORD_GAP:
		var center_y := clampf((tip_top.y + tip_bottom.y) * 0.5, MIN_Y + MIN_CHORD_GAP * 0.5, MAX_Y - MIN_CHORD_GAP * 0.5)
		tip_top.y = center_y + MIN_CHORD_GAP * 0.5
		tip_bottom.y = center_y - MIN_CHORD_GAP * 0.5

	sanitized[TIP_TOP_INDEX] = tip_top
	sanitized[TIP_BOTTOM_INDEX] = tip_bottom
	return sanitized

func compute_mesh(subdivisions: int = 8) -> Mesh:
	set_shape_points(shape_points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_thick := thickness * 0.5
	var n := subdivisions + 1

	var front_verts: Array[Vector3] = []
	var back_verts: Array[Vector3] = []

	for j in range(n):
		var t := float(j) / float(subdivisions)
		for i in range(n):
			var s := float(i) / float(subdivisions)
			var p := _bilinear(s, t)
			front_verts.append(p + Vector3(0, 0, half_thick))
			back_verts.append(p + Vector3(0, 0, -half_thick))

	for j in range(subdivisions):
		for i in range(subdivisions):
			var idx := j * n + i
			var a := front_verts[idx]
			var b := front_verts[idx + n]
			var c := front_verts[idx + 1]
			var d := front_verts[idx + n + 1]
			var normal := (b - a).cross(c - a).normalized()
			if normal.length() < 0.001:
				normal = Vector3.FORWARD
			st.set_normal(normal)
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(d)

			var ab := back_verts[idx]
			var bb := back_verts[idx + n]
			var cb := back_verts[idx + 1]
			var db := back_verts[idx + n + 1]
			var normal_b := (cb - bb).cross(ab - bb).normalized()
			if normal_b.length() < 0.001:
				normal_b = Vector3.BACK
			st.set_normal(normal_b)
			st.add_vertex(ab)
			st.add_vertex(cb)
			st.add_vertex(bb)
			st.add_vertex(cb)
			st.add_vertex(db)
			st.add_vertex(bb)

	for e in range(4):
		for k in range(subdivisions):
			var fi_idx: int
			var fnext_idx: int
			var bi_idx: int
			var bnext_idx: int

			match e:
				0:
					fi_idx = k
					fnext_idx = k + 1
					bi_idx = k
					bnext_idx = k + 1
				1:
					fi_idx = subdivisions * n + k
					fnext_idx = subdivisions * n + k + 1
					bi_idx = subdivisions * n + k
					bnext_idx = subdivisions * n + k + 1
				2:
					fi_idx = k * n
					fnext_idx = (k + 1) * n
					bi_idx = k * n
					bnext_idx = (k + 1) * n
				3:
					fi_idx = k * n + subdivisions
					fnext_idx = (k + 1) * n + subdivisions
					bi_idx = k * n + subdivisions
					bnext_idx = (k + 1) * n + subdivisions

			var f0 := front_verts[fi_idx]
			var f1 := front_verts[fnext_idx]
			var b0 := back_verts[bi_idx]
			var b1 := back_verts[bnext_idx]

			var edge_normal := (f1 - f0).cross(b0 - f0).normalized()
			if edge_normal.length() < 0.001:
				edge_normal = Vector3.FORWARD if e < 2 else Vector3.RIGHT

			st.set_normal(edge_normal)
			st.add_vertex(f0)
			st.add_vertex(b0)
			st.add_vertex(f1)
			st.add_vertex(f1)
			st.add_vertex(b0)
			st.add_vertex(b1)

	surface_area = 0.0
	for j in range(subdivisions):
		for i in range(subdivisions):
			var idx := j * n + i
			var a := front_verts[idx]
			var b := front_verts[idx + n]
			var c := front_verts[idx + 1]
			surface_area += (b - a).cross(c - a).length() * 0.5
	surface_area = calculate_surface_area()

	var mesh := st.commit()
	cached_mesh = mesh

	_update_measurements()

	return mesh

func set_shape_points(new_points: Array[Vector2]) -> void:
	var sanitized_points := sanitize_shape_points(new_points)
	shape_points.clear()
	for p in sanitized_points:
		shape_points.append(p)
	_update_control_points_from_shape()

func _bilinear(s: float, t: float) -> Vector3:
	var top := control_points[ROOT_TOP_INDEX].lerp(control_points[TIP_TOP_INDEX], s)
	var bottom := control_points[ROOT_BOTTOM_INDEX].lerp(control_points[TIP_BOTTOM_INDEX], s)
	return top.lerp(bottom, t)

func _update_control_points_from_shape() -> void:
	control_points = [
		Vector3(shape_points[ROOT_TOP_INDEX].x, shape_points[ROOT_TOP_INDEX].y, 0.0),
		Vector3(shape_points[TIP_TOP_INDEX].x, shape_points[TIP_TOP_INDEX].y, 0.0),
		Vector3(shape_points[TIP_BOTTOM_INDEX].x, shape_points[TIP_BOTTOM_INDEX].y, 0.0),
		Vector3(shape_points[ROOT_BOTTOM_INDEX].x, shape_points[ROOT_BOTTOM_INDEX].y, 0.0),
	]
	_update_measurements()

func _update_measurements() -> void:
	fin_span = maxf(shape_points[TIP_TOP_INDEX].x, shape_points[TIP_BOTTOM_INDEX].x)
	fin_root_chord = shape_points[ROOT_TOP_INDEX].distance_to(shape_points[ROOT_BOTTOM_INDEX])
	fin_tip_chord = shape_points[TIP_TOP_INDEX].distance_to(shape_points[TIP_BOTTOM_INDEX])

func get_root_edge_points() -> Array[Vector2]:
	return [shape_points[ROOT_TOP_INDEX], shape_points[ROOT_BOTTOM_INDEX]]

func calculate_surface_area() -> float:
	var polygon_area := 0.0
	for i in range(shape_points.size()):
		var a := shape_points[i]
		var b := shape_points[(i + 1) % shape_points.size()]
		polygon_area += a.x * b.y - b.x * a.y
	return absf(polygon_area) * 0.5

func calculate_fin_mass() -> float:
	var mat_data: Dictionary = MaterialDatabase.get_material(material_name)
	return float(fin_count) * calculate_surface_area() * thickness * float(mat_data.get("mass_multiplier", 1.0)) * FIN_MASS_SCALE

func get_config_dict() -> Dictionary:
	return {
		"fin_count": fin_count,
		"material_name": material_name,
		"surface_area": surface_area,
		"fin_span": fin_span,
		"fin_root_chord": fin_root_chord,
		"fin_tip_chord": fin_tip_chord,
		"thickness": thickness,
		"shape_points": shape_points,
	}
