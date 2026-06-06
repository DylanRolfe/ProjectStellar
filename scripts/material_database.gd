extends Node

const MATERIALS: Dictionary = {
	"aluminum": {},
	"steel": {},
	"carbon_fiber": {},
	"titanium": {},
	"plastic": {},
}

func material_names() -> Array:
	return MATERIALS.keys()

