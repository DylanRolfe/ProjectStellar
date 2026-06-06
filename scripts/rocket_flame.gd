class_name RocketFlame
extends Node3D

const PARTICLE_COUNT := 50
const BASE_SIZE := 1.2
const BASE_VELOCITY := 16.0
const LIFETIME_MIN := 0.6
const LIFETIME_MAX := 1.4

const FLAME_COLORS: Array[Color] = [
	Color(1.0, 0.55, 0.05),
	Color(1.0, 0.75, 0.1),
	Color(0.9, 0.3, 0.0),
	Color(0.95, 0.15, 0.0),
	Color(1.0, 0.4, 0.0),
]

var emitting := false
var _thrust_factor: float = 1.0
var _particles: Array[Dictionary] = []
var _quad_mesh: QuadMesh
var _pool_index := 0
var _emit_timer := 0.0

func _ready() -> void:
	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2(1, 1)

	for i in PARTICLE_COUNT:
		var color := FLAME_COLORS[i % FLAME_COLORS.size()]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color.r, color.g, color.b, 0.0)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 4.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

		var mi := MeshInstance3D.new()
		mi.mesh = _quad_mesh
		mi.material_override = mat
		mi.visible = false
		add_child(mi)

		_particles.append({
			node = mi,
			material = mat,
			age = 0.0,
			lifetime = 0.0,
			velocity = Vector3.ZERO,
			active = false,
		})

func set_thrust_factor(factor: float) -> void:
	_thrust_factor = clampf(factor, 0.0, 1.0)

func _process(delta: float) -> void:
	if emitting:
		_emit_timer += delta
		var interval := 0.5 - _thrust_factor * 0.48
		while _emit_timer >= interval:
			_spawn_particle()
			_emit_timer -= interval

	for p in _particles:
		if not p.active:
			continue
		p.age += delta
		if p.age >= p.lifetime:
			p.active = false
			p.node.visible = false
			continue

		var t: float = p.age / p.lifetime
		var s := 1.0 + t * 2.5
		p.node.scale = Vector3(s, s, s) * BASE_SIZE
		p.node.position += p.velocity * delta
		p.material.albedo_color.a = 1.0 - t * t * t

func _spawn_particle() -> void:
	var p := _particles[_pool_index]
	_pool_index = (_pool_index + 1) % PARTICLE_COUNT
	p.active = true
	p.age = 0.0
	p.lifetime = (LIFETIME_MIN + randf() * (LIFETIME_MAX - LIFETIME_MIN)) * (0.2 + _thrust_factor * 0.8)
	var speed := 2.0 + (BASE_VELOCITY + randf() * 8.0) * _thrust_factor
	var spread := 5.0 * _thrust_factor
	var radius := 3.0 * _thrust_factor
	p.velocity = Vector3(
		(randf() - 0.5) * spread,
		-speed,
		(randf() - 0.5) * spread
	)
	p.node.position = Vector3(
		(randf() - 0.5) * radius,
		(randf() - 0.5) * 1.0,
		(randf() - 0.5) * radius
	)
	p.node.scale = Vector3.ONE * BASE_SIZE * (0.1 + _thrust_factor * 0.9) * 0.5
	p.material.albedo_color.a = 1.0
	p.node.visible = true

func stop() -> void:
	emitting = false
	for p in _particles:
		p.active = false
		p.node.visible = false
