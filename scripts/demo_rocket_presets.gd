class_name DemoRocketPresets
extends RefCounted

# LOCKED DEMO PRESETS: edit these values once before final demo
static func get_preset(preset_name: String) -> Dictionary:
	match preset_name:
		"bad":
			return {
				"fin_count": 1,
				"fin_material_name": "plastic",
				"body_material_name": "steel",
				"payload_mass": 80.0,
				"engine_thrust": 1400.0,
				"fuel_amount": 35.0,
				"wind_speed": 30.0,
				"wind_direction": 90.0,
				"fin_thickness": 0.015,
				"shape_points": [
					Vector2(0.0, 0.22),
					Vector2(0.28, 0.12),
					Vector2(0.28, -0.12),
					Vector2(0.0, -0.22),
				],
			}
		"good":
			return {
				"fin_count": 4,
				"fin_material_name": "carbon_fiber",
				"body_material_name": "carbon_fiber",
				"payload_mass": 25.0,
				"engine_thrust": 1600.0,
				"fuel_amount": 45.0,
				"wind_speed": 30.0,
				"wind_direction": 90.0,
				"fin_thickness": 0.055,
				"shape_points": [
					Vector2(0.0, 0.36),
					Vector2(0.82, 0.28),
					Vector2(0.82, -0.28),
					Vector2(0.0, -0.36),
				],
			}
		_:
			push_warning("Unknown demo rocket preset: %s" % preset_name)
			return {}
