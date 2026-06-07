extends Node3D

## Faint stars on a large sky dome. They fade in with altitude: invisible near
## the ground, climbing (exponentially) to ~40% opacity by ~1.2 km, so the sky
## darkens as the rocket gets high. Opacity tracks the active camera's height.

@export var star_count: int = 180
@export var dome_radius: float = 1000.0
@export var min_elevation: float = 0.12   # above the viewer's horizon (dome follows camera)
@export var star_seed: int = 7

@export var fade_start: float = 600.0    # m — stars start appearing here
@export var fade_full: float = 1200.0    # m — stars reach peak brightness here (and stay)
@export var max_opacity: float = 0.95    # peak additive alpha
@export var brightness: float = 1.5      # HDR colour multiplier (extra glow)
@export var fade_exponent: float = 3.0   # >1 = slow start, faster near the top

var _stars: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _base_alpha: Array[float] = []
var _last_factor: float = -1.0

func _ready() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed

	for i in range(star_count):
		var theta := rng.randf_range(0.0, TAU)
		var up := rng.randf_range(min_elevation, 1.0)
		var ring := sqrt(maxf(1.0 - up * up, 0.0))
		var dir := Vector3(cos(theta) * ring, up, sin(theta) * ring)

		var star := MeshInstance3D.new()
		star.mesh = mesh
		star.position = dir * dome_radius
		var size := rng.randf_range(12.0, 22.0)
		star.scale = Vector3(size, size, size)
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Additive, unshaded billboards so the stars glow visibly even against a
		# bright daytime sky. Brightness (alpha) is driven by altitude in _process.
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		# HDR base colour (>1) so the additive glow is 1.5x brighter; alpha (set in
		# _process) starts at 0 so the star is hidden until we gain altitude.
		var base_color := Color(0.92, 0.95, 1.0) * brightness
		base_color.a = 0.0
		mat.albedo_color = base_color
		star.material_override = mat

		add_child(star)
		_stars.append(star)
		_materials.append(mat)
		# Each star has its own peak brightness for a little variety.
		_base_alpha.append(rng.randf_range(0.7, 1.0) * max_opacity)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Keep the dome centred on the camera (like a skybox) so the stars always sit
	# overhead in the blue sky and never drift down past the horizon as we climb.
	global_position = camera.global_position
	var altitude := camera.global_position.y
	var t := clampf((altitude - fade_start) / maxf(fade_full - fade_start, 1.0), 0.0, 1.0)
	# Exponential ease-in: slow near the ground, ramping up with altitude.
	var factor := (exp(fade_exponent * t) - 1.0) / (exp(fade_exponent) - 1.0)
	if absf(factor - _last_factor) < 0.004:
		return
	_last_factor = factor
	for i in range(_materials.size()):
		var color := _materials[i].albedo_color
		color.a = _base_alpha[i] * factor
		_materials[i].albedo_color = color
