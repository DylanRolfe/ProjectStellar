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

const CARBON_NORMAL_PATH: String = "res://assets/materials/carbon_weave_normal.png"

const _PBR: Dictionary = {
	"aluminum": {"metallic": 1.0, "roughness": 0.35},
	"steel": {"metallic": 1.0, "roughness": 0.45},
	"carbon_fiber": {"metallic": 0.3, "roughness": 0.35},
	"titanium": {"metallic": 1.0, "roughness": 0.55},
	"plastic": {"metallic": 0.0, "roughness": 0.65},
}

var _material_cache: Dictionary = {}

func get_material(material_name: String) -> Dictionary:
	return MATERIALS.get(material_name, MATERIALS["aluminum"])

func get_surface_material(material_name: String) -> StandardMaterial3D:
	if _material_cache.has(material_name):
		return _material_cache[material_name]

	var stats: Dictionary = get_material(material_name)
	var pbr: Dictionary = _PBR.get(material_name, {"metallic": 0.4, "roughness": 0.5})
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats.get("color", Color(0.8, 0.82, 0.85))
	mat.metallic = pbr["metallic"]
	mat.roughness = pbr["roughness"]
	mat.metallic_specular = 0.5

	if material_name == "carbon_fiber" and ResourceLoader.exists(CARBON_NORMAL_PATH):
		mat.normal_enabled = true
		mat.normal_texture = load(CARBON_NORMAL_PATH)
		mat.uv1_scale = Vector3(6.0, 6.0, 6.0)

	_material_cache[material_name] = mat
	return mat

func material_names() -> Array:
	return MATERIALS.keys()
