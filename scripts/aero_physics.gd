class_name AeroPhysics
extends RefCounted

const G0: float = 9.81
const EARTH_RADIUS: float = 6_371_000.0

static func gravity_at(altitude: float) -> float:
	var clamped_altitude := maxf(altitude, 0.0)
	var ratio := EARTH_RADIUS / (EARTH_RADIUS + clamped_altitude)
	return G0 * ratio * ratio

static func frontal_area(radius: float) -> float:
	return PI * radius * radius

static func drag_force(speed: float, air_density: float, drag_coefficient: float, area: float) -> float:
	return 0.5 * air_density * speed * speed * drag_coefficient * area
