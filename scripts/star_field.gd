extends Node3D

## Scatters a sprinkle of faint stars across the upper sky. Purely cosmetic —
## small unshaded billboards on a large dome, well beyond the desert scatter.

@export var star_count: int = 55
@export var dome_radius: float = 2200.0
@export var min_elevation: float = 0.18   # keep stars above the horizon haze
@export var brightness: float = 0.6
@export var star_seed: int = 7

func _ready() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed

	for i in range(star_count):
		# Random direction on the upper hemisphere.
		var theta := rng.randf_range(0.0, TAU)
		var up := rng.randf_range(min_elevation, 1.0)
		var ring := sqrt(maxf(1.0 - up * up, 0.0))
		var dir := Vector3(cos(theta) * ring, up, sin(theta) * ring)

		var star := MeshInstance3D.new()
		star.mesh = mesh
		star.position = dir * dome_radius
		var size := rng.randf_range(5.0, 11.0)
		star.scale = Vector3(size, size, size)
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(1.0, 1.0, 1.0, rng.randf_range(0.25, 0.65) * brightness)
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.92, 1.0)
		mat.emission_energy_multiplier = 1.2
		star.material_override = mat

		add_child(star)
