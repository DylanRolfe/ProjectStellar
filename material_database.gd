extends Node
# Autoload named "MaterialDatabase".
# (Project > Project Settings > Globals/Autoload > add this script as MaterialDatabase.)
#
# Two jobs:
#   get_material(name)         -> Dictionary of physics stats (mass, drag, stability...)
#   get_surface_material(name) -> a ready StandardMaterial3D for the look (color + metal + roughness)
#
# The physics API (get_material, material_names) is unchanged, so nothing that
# already calls it breaks.

# OPTIONAL: drop a CC0 carbon-weave NORMAL map here to give carbon fiber a woven look.
# Leave this alone if you don't have one yet. The code checks if the file exists
# and simply skips it when it's missing, so carbon fiber still works without it.
const CARBON_NORMAL_PATH: String = "res://assets/materials/carbon_weave_normal.png"

const MATERIALS: Dictionary = {
	"aluminum": {
		"mass_multiplier": 1.0, "strength": 0.6, "heat_resistance": 0.5,
		"cost_multiplier": 1.0, "drag_modifier": 0.0, "stability_bonus": 0.0,
		"albedo": Color(0.85, 0.86, 0.88), "metallic": 1.0, "roughness": 0.35,
	},
	"steel": {
		"mass_multiplier": 2.4, "strength": 0.9, "heat_resistance": 0.8,
		"cost_multiplier": 0.7, "drag_modifier": 0.0, "stability_bonus": 0.0,
		"albedo": Color(0.55, 0.57, 0.60), "metallic": 1.0, "roughness": 0.45,
	},
	"carbon_fiber": {
		"mass_multiplier": 0.55, "strength": 0.85, "heat_resistance": 0.6,
		"cost_multiplier": 2.5, "drag_modifier": -0.05, "stability_bonus": 0.05,
		"albedo": Color(0.08, 0.08, 0.10), "metallic": 0.3, "roughness": 0.35,
	},
	"titanium": {
		"mass_multiplier": 0.85, "strength": 1.0, "heat_resistance": 1.0,
		"cost_multiplier": 3.2, "drag_modifier": -0.02, "stability_bonus": 0.02,
		"albedo": Color(0.62, 0.61, 0.60), "metallic": 1.0, "roughness": 0.55,
	},
	"plastic": {
		"mass_multiplier": 0.4, "strength": 0.25, "heat_resistance": 0.2,
		"cost_multiplier": 0.4, "drag_modifier": 0.03, "stability_bonus": -0.03,
		"albedo": Color(0.90, 0.50, 0.20), "metallic": 0.0, "roughness": 0.65,
	},
}

# Materials are built once and reused. They are read-only after creation, so
# sharing one instance across every rocket part is safe and cheap.
var _material_cache: Dictionary = {}

# --- physics stats (unchanged API) ---
func get_material(material_name: String) -> Dictionary:
	return MATERIALS.get(material_name, MATERIALS["aluminum"])

func material_names() -> Array:
	return MATERIALS.keys()

# --- visual material ---
func get_surface_material(material_name: String) -> StandardMaterial3D:
	if _material_cache.has(material_name):
		return _material_cache[material_name]

	var stats: Dictionary = get_material(material_name)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats.get("albedo", Color.WHITE)
	mat.metallic = stats.get("metallic", 0.0)
	mat.roughness = stats.get("roughness", 0.5)
	# Metals need something to reflect. Make sure your scene has a WorldEnvironment
	# with a sky/HDRI or these will look like flat grey plastic.
	mat.metallic_specular = 0.5

	# Carbon fiber gets a woven normal map if you've added one.
	if material_name == "carbon_fiber" and ResourceLoader.exists(CARBON_NORMAL_PATH):
		mat.normal_enabled = true
		mat.normal_texture = load(CARBON_NORMAL_PATH)
		mat.uv1_scale = Vector3(6.0, 6.0, 6.0)  # tile the weave so it reads as fine

	_material_cache[material_name] = mat
	return mat
