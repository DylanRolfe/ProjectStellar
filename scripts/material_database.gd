extends Node

const MATERIALS: Dictionary = {
	"aluminum": {
		"mass_multiplier": 1.0, "strength": 0.6, "heat_resistance": 0.5,
		"cost_multiplier": 1.0, "drag_modifier": 0.0, "stability_bonus": 0.0,
		"color": Color(0.80, 0.82, 0.85),
	},
	"steel": {
		"mass_multiplier": 2.4, "strength": 0.9, "heat_resistance": 0.8,
		"cost_multiplier": 0.7, "drag_modifier": 0.0, "stability_bonus": 0.0,
		"color": Color(0.55, 0.57, 0.60),
	},
	"carbon_fiber": {
		"mass_multiplier": 0.55, "strength": 0.85, "heat_resistance": 0.6,
		"cost_multiplier": 2.5, "drag_modifier": -0.05, "stability_bonus": 0.05,
		"color": Color(0.12, 0.12, 0.14),
	},
	"titanium": {
		"mass_multiplier": 0.85, "strength": 1.0, "heat_resistance": 1.0,
		"cost_multiplier": 3.2, "drag_modifier": -0.02, "stability_bonus": 0.02,
		"color": Color(0.60, 0.60, 0.66),
	},
	"plastic": {
		"mass_multiplier": 0.4, "strength": 0.25, "heat_resistance": 0.2,
		"cost_multiplier": 0.4, "drag_modifier": 0.03, "stability_bonus": -0.03,
		"color": Color(0.90, 0.50, 0.20),
	},
}

func get_material(material_name: String) -> Dictionary:
	return MATERIALS.get(material_name, MATERIALS["aluminum"])

func material_names() -> Array:
	return MATERIALS.keys()
