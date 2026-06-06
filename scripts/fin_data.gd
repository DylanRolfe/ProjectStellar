class_name FinData
extends Resource

var control_points: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.4, 0.0, 0.0),
	Vector3(0.05, 0.3, 0.0),
	Vector3(0.3, 0.3, 0.0),
]

var thickness: float = 0.04
var fin_count: int = 4
var material_name: String = "aluminum"

var cached_mesh: Mesh = null
var surface_area: float = 0.0
var fin_span: float = 0.3
var fin_root_chord: float = 0.4
var fin_tip_chord: float = 0.25

func compute_mesh(subdivisions: int = 8) -> Mesh:
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
	surface_area *= 2.0

	var mesh := st.commit()
	cached_mesh = mesh

	fin_span = (control_points[2] - control_points[0]).length()
	fin_root_chord = (control_points[1] - control_points[0]).length()
	fin_tip_chord = (control_points[3] - control_points[2]).length()

	return mesh

func _bilinear(s: float, t: float) -> Vector3:
	var top := control_points[0].lerp(control_points[1], s)
	var bottom := control_points[2].lerp(control_points[3], s)
	return top.lerp(bottom, t)

func get_config_dict() -> Dictionary:
	return {
		"fin_count": fin_count,
		"material_name": material_name,
		"surface_area": surface_area,
		"fin_span": fin_span,
		"fin_root_chord": fin_root_chord,
		"fin_tip_chord": fin_tip_chord,
		"thickness": thickness,
	}
