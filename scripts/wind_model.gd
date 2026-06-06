class_name WindModel
extends RefCounted

static func get_wind_vector(speed: float, direction_degrees: float) -> Vector3:
	var radians := deg_to_rad(direction_degrees)
	return Vector3(cos(radians), 0.0, sin(radians)) * speed
