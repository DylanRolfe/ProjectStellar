# Project Stellar — BUILD_PLAN.md

> Single source of truth for the hackathon. Godot 4.6.1 stable, GDScript, GitHub.
> The physics here is a simplified, real-time, physics-inspired model. It is built for a believable demo and for teaching intuition, not for real CFD or real aerospace certification. Say that out loud during judging so nobody expects NASA-grade accuracy.

---

## 1. Project overview

Project Stellar is a 3D rocket fin and wing simulator. A user picks a rocket configuration (fin count, fin size, fin angle, body and fin material, mass, height, radius, engine thrust, fuel) and a launch environment (wind speed and direction), then hits Launch and watches a `RigidBody3D` rocket lift off from a launch pad under a slightly angled mission-control camera. The rocket climbs, the fins fight to keep it pointed into the airflow, wind pushes it sideways, and drag bleeds off speed. When the flight ends, a telemetry results panel reports max height, max speed, a stability score, drag loss, and a plain-English failure reason. The whole point of the demo is the second launch: take a wobbly, under-finned rocket that tumbles, change a few sliders, relaunch, and watch it fly straight and higher. That before-and-after is the story.

---

## 2. MVP definition

This is the smallest version that is actually demo-worthy. Build this first, in order, and do not start polish until every box below is checked.

**MVP checklist**

- [ ] Project opens in Godot 4.6.1 with the folder structure in place
- [ ] A rocket (`RigidBody3D`) sits on a launch pad and stays still until launch
- [ ] Pressing **Launch** makes the rocket lift off under thrust
- [ ] Sliders change real values that the simulation reads (thrust, mass, fuel at minimum)
- [ ] Wind pushes the rocket off a perfectly vertical path
- [ ] Fins affect stability (few/small fins wobble, more/bigger fins fly straighter)
- [ ] Max height is calculated and tracked during flight
- [ ] A results panel appears after the flight ends with height, speed, stability, and a reason
- [ ] A **Reset** button lets you run again without restarting the editor

If you only finish section 2, you still have something to show. Everything after this is upside.

---

## 3. Non-MVP stretch goals

Pull these in only after the MVP checklist is green. Roughly easiest to hardest:

- Smoke and flame `GPUParticles3D` on the engine
- Camera shake on liftoff
- Animated wind direction arrow in the 3D scene
- Material-driven body color (steel looks like steel, carbon fiber looks dark)
- Sound effects (engine rumble, wind, success/failure stinger)
- Real-time graph of altitude vs time on the dashboard
- Imported custom `.glb` / `.gltf` fin models with a dropdown to swap them
- Joystick or click-drag wind control instead of a slider
- Canted fins (`fin_angle`) inducing visible roll spin
- Save and compare two runs side by side
- A simple AI design recommender that suggests "add one more fin" or "reduce mass" based on the failure reason

---

## 4. Recommended project folder structure

Create this exactly. It keeps ownership clean and makes Git conflicts rare.

```
project_stellar/
├── project.godot
├── BUILD_PLAN.md
├── scenes/
│   ├── Main.tscn
│   ├── Rocket.tscn
│   ├── Fin.tscn
│   ├── LaunchPad.tscn
│   ├── SimulationCamera.tscn
│   ├── DashboardUI.tscn
│   └── ResultsPanel.tscn
├── scripts/
│   ├── main.gd
│   ├── rocket_controller.gd
│   ├── rocket_config.gd
│   ├── simulation_manager.gd
│   ├── aero_physics.gd
│   ├── wind_model.gd
│   ├── material_database.gd
│   ├── results_calculator.gd
│   ├── ui_controller.gd
│   └── simulation_camera.gd
├── assets/
│   ├── models/
│   │   └── fin_default.glb        (optional imported fin)
│   ├── materials/
│   │   ├── body_metal.tres
│   │   └── pad.tres
│   └── ui/
│       ├── theme.tres
│       └── fonts/
├── data/
│   └── presets.json               (optional saved rocket configs)
└── docs/
    └── demo_script.md
```

Folders cost nothing. Make them all on day one so nobody has to "figure out where this goes" at hour 20.

---

## 5. Scene architecture

Seven scenes. Each one is owned by exactly one person (see section 15) so two people never save the same `.tscn` at the same time.

- **`Main.tscn`** — the root. Holds the 3D world, the camera, the lights, the `SimulationManager` node, and the UI layer. This is the scene you run. Owned by the integration person only.
- **`Rocket.tscn`** — the `RigidBody3D` rocket: body mesh, collision shape, a `FinHolder` node for spawned fins, and an engine particle node. Has `rocket_controller.gd` attached.
- **`Fin.tscn`** — one fin. A `MeshInstance3D` (or imported model) plus an optional small collision shape. Instanced multiple times around the rocket at runtime.
- **`LaunchPad.tscn`** — the ground and pad the rocket rests on. A `StaticBody3D` with a flat collision shape, plus mesh and some mission-control set dressing.
- **`SimulationCamera.tscn`** — a `Camera3D` at a slight angle with `simulation_camera.gd` for follow and shake.
- **`DashboardUI.tscn`** — the full Control UI: left parameter panel, right telemetry panel, bottom button bar. Has `ui_controller.gd`. Contains an instance of `ResultsPanel.tscn`.
- **`ResultsPanel.tscn`** — the post-flight summary card (hidden until a flight ends).

---

## 6. Script architecture

Each script has one job. Keeping them small and single-purpose is what lets five people work in parallel.

- **`rocket_config.gd`** — a `Resource` that holds every rocket parameter as one tidy object you can pass around, duplicate, and save.
- **`rocket_controller.gd`** — attached to the rocket. Applies thrust, gravity, drag, and fin torque every physics frame. Tracks telemetry and emits signals.
- **`simulation_manager.gd`** — orchestrates a run: set up the rocket from a config, start the launch, watch for the end, ask for results, broadcast them.
- **`aero_physics.gd`** — pure stateless physics math (gravity, drag, air density, fin strength). No nodes, easy to reason about and tweak.
- **`wind_model.gd`** — turns wind speed and direction into a `Vector3`. Holds the optional gust logic.
- **`material_database.gd`** — an autoload singleton with the material table and lookups.
- **`results_calculator.gd`** — converts the rocket's flight telemetry into the final results dictionary.
- **`ui_controller.gd`** — reads sliders and dropdowns into a config, updates telemetry labels, shows the results panel, handles the buttons.
- **`simulation_camera.gd`** — follows the rocket and does the launch shake.
- **`main.gd`** — tiny glue script that wires the UI, manager, and rocket signals together.

---

## 7. Physics model

Here's the honest framing: every formula below is a deliberate simplification. We treat the rocket as a single rigid body, the fins as an aggregate stabilizing effect rather than individual aerofoils, and the atmosphere as a smooth exponential. That is enough to make sliders feel meaningful and to make a bad rocket visibly tumble. It is not real CFD and you should not pretend it is.

Let's break down each force.

### Gravity that weakens with altitude

```
g(h) = g0 * (R / (R + h))^2
```

`g0 = 9.81`, `R = 6,371,000 m`. At hackathon altitudes the change is tiny, but it reads as "aerospace" and costs nothing. Force applied = `mass * g(h)` straight down.

### Thrust

```
F_thrust = rocket_forward_direction * engine_thrust
```

In Godot the rocket's nose points along its local up axis, which in world space is `global_transform.basis.y`. While fuel remains, push along that vector. This is what makes the rocket follow its own tilt, which is exactly why an unstable rocket flies off course.

### Fuel burn (and shrinking mass)

```
fuel = fuel - burn_rate * delta
if fuel <= 0: thrust = 0
mass = dry_mass + fuel * fuel_mass_factor
```

Burning fuel lightens the rocket, so acceleration climbs near burnout. Nice touch, basically free.

### Drag (computed against the air, not the ground)

```
F_drag = 0.5 * air_density * speed^2 * drag_coefficient * frontal_area
```

`frontal_area = PI * radius^2`. Air density thins with altitude: `rho(h) = rho0 * exp(-h / 8500)`. Drag opposes the direction of motion **relative to the wind**, which is the trick that folds wind into the same calculation.

### Wind-relative velocity

```
relative_velocity = rocket_velocity - wind_velocity
```

`wind_velocity` comes from `wind_model.gd`. We feed `relative_velocity` (not raw velocity) into the drag force. What this really means: a crosswind shows up as a sideways drag push, and a strong headwind costs altitude. One formula, two behaviors.

### Fin stabilization torque (weathercocking)

The spec formula:

```
torque = -pitch_angle * fin_area * fin_count * stability_multiplier * airspeed
```

In 3D we generalize "pitch_angle" to the misalignment between the nose and the airflow, and we apply the torque around the axis that closes that gap:

```
nose_dir     = global_transform.basis.y
flight_dir   = relative_velocity.normalized()
misalignment = angle_between(nose_dir, flight_dir)        # radians
axis         = nose_dir.cross(flight_dir).normalized()
strength     = fin_area * fin_count * stability_multiplier * airspeed
torque       = axis * misalignment * strength
```

More fins, bigger fins, and faster airspeed all produce a stronger correction. This is why few fins = slow correction = tumble, and enough fins = snappy correction = straight flight. Pair it with a small `angular_damp` on the body so the correction settles instead of oscillating.

### Fin drag penalty (the trade-off that makes it a real choice)

```
drag_coefficient = base_cd + fin_count * fin_area * fin_drag_factor
```

Fins stabilize but they add drag, which steals top altitude. So the answer is never "infinite fins." The sweet spot is "just enough to stay stable." That tension is the whole design game and it powers the demo.

### Net force

```
F_net = F_thrust + F_drag + F_gravity + (wind enters through F_drag)
```

You do not sum these by hand. You call `apply_central_force()` once per force each physics frame and let Godot integrate them.

### Max height and max speed tracking

```
max_height = max(max_height, position.y)
max_speed  = max(max_speed, velocity.length())
```

### Stability score

Accumulate tilt away from vertical across the flight, then convert to a 0–100 score:

```
tilt_deg     = angle_between(nose_dir, world_up) in degrees
avg_tilt     = sum(tilt_deg) / samples
stability    = clamp(100 - avg_tilt * 1.8 - max_tilt * 0.4, 0, 100)
```

A rocket that stays near vertical scores high. One that flops over scores low. Simple, readable, and it matches what the viewer sees.

**How this maps to Godot:** disable the body's built-in gravity (`gravity_scale = 0`), then every `_physics_process(delta)` call `apply_central_force()` for gravity, thrust, and drag, and `apply_torque()` for fin correction. The pure math lives in `aero_physics.gd` so the physics person can tune constants without touching the node tree.

---

## 8. Materials system

A small table drives mass, look, and feel. Body material scales mass and drag. Fin material nudges the stability bonus. These numbers are tuned for gameplay, not for a materials datasheet.

| Material      | Mass multiplier | Strength | Heat resistance | Cost multiplier | Drag modifier | Stability bonus |
|---------------|-----------------|----------|-----------------|-----------------|---------------|-----------------|
| Aluminum      | 1.0             | 0.6      | 0.5             | 1.0             | 0.00          | 0.00            |
| Steel         | 2.4             | 0.9      | 0.8             | 0.7             | 0.00          | 0.00            |
| Carbon fiber  | 0.55            | 0.85     | 0.6             | 2.5             | -0.05         | +0.05           |
| Titanium      | 0.85            | 1.0      | 1.0             | 3.2             | -0.02         | +0.02           |
| Plastic       | 0.4             | 0.25     | 0.2             | 0.4             | +0.03         | -0.03           |

Demo-relevant read: steel makes a heavy, sluggish rocket. Swap to aluminum or carbon fiber and the same thrust reaches much higher. That single dropdown change is a great second-launch beat.

---

## 9. UI design

Mission-control dashboard, four zones.

- **Left panel — rocket parameters.** All the inputs.
- **Center — 3D launch view.** The `SubViewport` or main viewport showing the rocket and pad.
- **Right panel — live telemetry.** Updates every frame during flight.
- **Bottom bar — controls.** Launch, Reset, and a one-line result summary.

**Exact controls to build**

Left panel:
- `HSlider` Fin count (0 to 8, step 1)
- `HSlider` Fin size (0.05 to 1.0)
- `HSlider` Fin angle (-10 to 10 degrees)
- `HSlider` Wind speed (0 to 40 m/s)
- `HSlider` Wind direction (0 to 360 degrees)
- `HSlider` Rocket mass (1 to 200 kg)
- `HSlider` Rocket height (0.5 to 10 m)
- `HSlider` Rocket radius (0.05 to 1.0 m)
- `HSlider` Engine thrust (100 to 5000 N)
- `HSlider` Fuel amount (0 to 100)
- `OptionButton` Body material
- `OptionButton` Fin material
- A `Label` next to every slider showing its current value

Right panel:
- `Label` max altitude (live)
- `Label` current speed (live)
- `Label` current tilt
- `ProgressBar` stability meter
- A small wind indicator (text now, arrow later)

Bottom bar:
- `Button` Launch
- `Button` Reset
- `Label` one-line status ("Ready", "In flight", "Apogee 142 m")

Results panel (overlay, hidden until flight ends):
- Result cards for max height, max speed, stability score, drag loss
- A big success or failure banner with the failure reason

Tip: mark the nodes you read from code as **Access as Unique Name** (the `%` toggle in the scene tree). Then `ui_controller.gd` can use `%LaunchButton` instead of fragile long paths, and the UI person can rearrange the layout without breaking the script.

---

## 10. Visual design

Make it feel like a control room.

- Dark theme. Near-black panels, one accent color (cyan or amber), monospace font for numbers.
- Telemetry labels glow slightly (a bright accent color on dark works; add a subtle `WorldEnvironment` glow for stretch).
- A simple launch pad with a metal deck and a couple of gantry shapes.
- `GPUParticles3D` flame at the nozzle (orange, additive) plus a `GPUParticles3D` smoke puff at liftoff (grey, fading).
- Animated wind arrows in the scene pointing in the wind direction, length scaled to wind speed.
- Camera shake on the first second of liftoff.
- Results banner: red panel for failure, green for success. Big, readable, instant.

None of this is required for the MVP. It is what makes the 90 seconds land.

---

## 11. Step-by-step implementation plan

Ten phases. Each one ends in something you can run.

**Phase 1 — Project structure.**
Tasks: create the Godot 4.6.1 project, make every folder from section 4, set up the Git repo, register `MaterialDatabase` as an autoload, commit.
Output: empty project opens, folders exist, `MaterialDatabase` loads with no errors.

**Phase 2 — Rocket scene.**
Tasks: build `Rocket.tscn` (`RigidBody3D` + body `MeshInstance3D` + `CollisionShape3D` + `FinHolder` `Node3D`). Build `LaunchPad.tscn`. Drop both into `Main.tscn` with a camera and a light.
Output: a capsule rocket rests on a pad when you press Play.

**Phase 3 — Basic launch physics.**
Tasks: write `aero_physics.gd` and `rocket_controller.gd`. Set `gravity_scale = 0`, apply manual gravity and thrust, add a temporary key press to call `launch()`.
Output: pressing the key sends the rocket straight up, then it falls back.

**Phase 4 — Sliders.**
Tasks: build `DashboardUI.tscn` and `ui_controller.gd`, wire thrust/mass/fuel sliders into a `RocketConfig`, replace the temporary key with the Launch button.
Output: changing thrust or mass visibly changes the climb.

**Phase 5 — Wind.**
Tasks: write `wind_model.gd`, add wind sliders, feed wind into drag via relative velocity.
Output: with wind on, the rocket drifts off vertical.

**Phase 6 — Fins and stability.**
Tasks: build `Fin.tscn`, spawn `fin_count` fins around the body at runtime, add fin torque and the fin drag penalty, set a small `angular_damp`.
Output: 1 fin tumbles, 4 fins fly straight. This is the core of the project, so get it feeling right before moving on.

**Phase 7 — Materials.**
Tasks: hook the material dropdowns into mass, drag, stability, and body color.
Output: steel is sluggish, carbon fiber is peppy, the body recolors.

**Phase 8 — Results panel.**
Tasks: write `results_calculator.gd` and `simulation_manager.gd`, detect flight end, build `ResultsPanel.tscn`, show it with real numbers.
Output: a clean summary card appears after every flight.

**Phase 9 — Visual polish.**
Tasks: particles, camera shake, wind arrows, themed UI, success/failure banners, optional sound.
Output: it looks like a product, not a prototype.

**Phase 10 — Demo script and bug fixing.**
Tasks: lock the two rocket presets for the demo, rehearse the 90 seconds, fix the top 5 bugs, freeze the build.
Output: a rehearsed, reliable demo.

---

## 12. GDScript code scaffolding

Realistic Godot 4.6.1 GDScript. Treat it as a strong starting point, then tune the constants. Comments mark the numbers worth tuning.

### `scripts/rocket_config.gd`

```gdscript
class_name RocketConfig
extends Resource

# Every tunable rocket parameter in one object you can pass, copy, and save.

@export_range(0, 8, 1) var fin_count: int = 3
@export_range(0.05, 1.0, 0.01) var fin_size: float = 0.3          # effective fin area, m^2
@export_range(-10.0, 10.0, 0.5) var fin_angle: float = 0.0        # canted fins, degrees (roll, optional)
@export_range(0.0, 40.0, 0.5) var wind_speed: float = 5.0         # m/s
@export_range(0.0, 360.0, 1.0) var wind_direction: float = 90.0   # degrees
@export_range(1.0, 200.0, 1.0) var rocket_mass: float = 20.0      # kg, dry mass
@export_range(0.5, 10.0, 0.1) var rocket_height: float = 3.0      # m
@export_range(0.05, 1.0, 0.01) var rocket_radius: float = 0.2     # m
@export_range(100.0, 5000.0, 10.0) var engine_thrust: float = 600.0  # newtons
@export_range(0.0, 100.0, 1.0) var fuel_amount: float = 40.0      # arbitrary units
@export_enum("aluminum", "steel", "carbon_fiber", "titanium", "plastic") var body_material: String = "aluminum"
@export_enum("aluminum", "steel", "carbon_fiber", "titanium", "plastic") var fin_material: String = "aluminum"

func clone() -> RocketConfig:
	return duplicate(true) as RocketConfig
```

### `scripts/aero_physics.gd`

```gdscript
class_name AeroPhysics
extends RefCounted

# Pure, stateless physics math. Simplified on purpose. Not real CFD.

const G0: float = 9.81                       # surface gravity, m/s^2
const EARTH_RADIUS: float = 6_371_000.0      # m
const SEA_LEVEL_AIR_DENSITY: float = 1.225   # kg/m^3
const ATMOSPHERE_SCALE_HEIGHT: float = 8500.0  # m

# g(h) = g0 * (R / (R + h))^2
static func gravity_at(altitude: float) -> float:
	var h: float = maxf(altitude, 0.0)
	var ratio: float = EARTH_RADIUS / (EARTH_RADIUS + h)
	return G0 * ratio * ratio

# Air thins with altitude (exponential atmosphere).
static func air_density_at(altitude: float) -> float:
	var h: float = maxf(altitude, 0.0)
	return SEA_LEVEL_AIR_DENSITY * exp(-h / ATMOSPHERE_SCALE_HEIGHT)

# Circular frontal area from radius.
static func frontal_area(radius: float) -> float:
	return PI * radius * radius

# F_drag = 0.5 * rho * v^2 * Cd * A
static func drag_force(relative_speed: float, air_density: float, drag_coefficient: float, area: float) -> float:
	return 0.5 * air_density * relative_speed * relative_speed * drag_coefficient * area

# More/bigger fins add drag. fin_drag_factor ~ 0.02 to tune the penalty.
static func drag_coefficient(base_cd: float, fin_count: int, fin_area: float, fin_drag_factor: float) -> float:
	return base_cd + float(fin_count) * fin_area * fin_drag_factor

# Stabilizing strength without the angle term (the controller multiplies by misalignment).
static func stabilizing_strength(fin_area: float, fin_count: int, stability_multiplier: float, airspeed: float) -> float:
	return fin_area * float(fin_count) * stability_multiplier * airspeed
```

### `scripts/wind_model.gd`

```gdscript
class_name WindModel
extends RefCounted

# Wind blows horizontally. 0 deg = +X, 90 deg = +Z. Pick a convention and keep it.
static func get_wind_vector(speed: float, direction_degrees: float) -> Vector3:
	var rad: float = deg_to_rad(direction_degrees)
	return Vector3(cos(rad), 0.0, sin(rad)) * speed

# Stretch goal: gusts that wobble over time.
static func get_wind_vector_with_gust(speed: float, direction_degrees: float, time: float, gust_strength: float = 0.0) -> Vector3:
	var base: Vector3 = get_wind_vector(speed, direction_degrees)
	if base.length() < 0.001:
		return base
	return base + base.normalized() * sin(time * 2.3) * gust_strength
```

### `scripts/material_database.gd`

```gdscript
extends Node
# Register as an Autoload named "MaterialDatabase":
# Project > Project Settings > Globals (Autoload) > add this script.

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
```

### `scripts/rocket_controller.gd`

```gdscript
class_name RocketController
extends RigidBody3D

signal telemetry_updated(altitude: float, speed: float, tilt_degrees: float, fuel_ratio: float)
signal flight_finished(reason: String)

@export var config: RocketConfig
@export var fin_scene: PackedScene          # assign Fin.tscn in the inspector

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var fin_holder: Node3D = $FinHolder
@onready var engine_particles: GPUParticles3D = $EngineParticles

# runtime state
var _launched: bool = false
var _fuel: float = 0.0
var _dry_mass: float = 1.0
var _fuel_mass_factor: float = 0.8          # weight per fuel unit (tune)
var _burn_rate: float = 0.0
var _wind_velocity: Vector3 = Vector3.ZERO

# physics constants to tune
var _base_cd: float = 0.35
var _fin_drag_factor: float = 0.02
var _stability_multiplier: float = 0.5

# telemetry
var max_altitude: float = 0.0
var max_speed: float = 0.0
var _tilt_sum: float = 0.0
var _tilt_samples: int = 0
var _max_tilt: float = 0.0
var _drag_energy_lost: float = 0.0

func setup(new_config: RocketConfig) -> void:
	config = new_config
	_apply_config()
	_build_fins()

func _apply_config() -> void:
	gravity_scale = 0.0          # we apply gravity ourselves
	can_sleep = false
	angular_damp = 1.0           # lets fin corrections settle instead of oscillating (tune)
	freeze = true                # sit on the pad until launch

	var body_mat: Dictionary = MaterialDatabase.get_material(config.body_material)
	var fin_mat: Dictionary = MaterialDatabase.get_material(config.fin_material)

	_dry_mass = config.rocket_mass * body_mat.get("mass_multiplier", 1.0)
	_fuel = config.fuel_amount
	_burn_rate = config.fuel_amount / 6.0   # ~6 s of burn at full tank (tune)
	mass = _dry_mass + _fuel * _fuel_mass_factor

	_base_cd = 0.35 + body_mat.get("drag_modifier", 0.0)
	_stability_multiplier = 0.5 + fin_mat.get("stability_bonus", 0.0)

	_wind_velocity = WindModel.get_wind_vector(config.wind_speed, config.wind_direction)

	# recolor the body to match the chosen material
	if body_mesh and body_mesh.get_active_material(0):
		var mat := body_mesh.get_active_material(0).duplicate() as StandardMaterial3D
		mat.albedo_color = body_mat.get("color", Color.WHITE)
		body_mesh.set_surface_override_material(0, mat)

func _build_fins() -> void:
	for child in fin_holder.get_children():
		child.queue_free()
	if fin_scene == null:
		return
	var count: int = maxi(config.fin_count, 0)
	for i in count:
		var fin := fin_scene.instantiate() as Node3D
		var angle: float = TAU * float(i) / float(maxi(count, 1))
		fin.position = Vector3(cos(angle), 0.0, sin(angle)) * config.rocket_radius
		fin.rotation.y = -angle
		fin.scale = Vector3.ONE * config.fin_size * 2.0   # rough visual scale (tune)
		fin_holder.add_child(fin)

func launch() -> void:
	if _launched:
		return
	_launched = true
	freeze = false
	if engine_particles:
		engine_particles.emitting = true

func _physics_process(delta: float) -> void:
	if not _launched:
		return

	var altitude: float = global_position.y
	var velocity: Vector3 = linear_velocity
	var speed: float = velocity.length()

	# gravity (weakens with altitude)
	var g: float = AeroPhysics.gravity_at(altitude)
	apply_central_force(Vector3.DOWN * g * mass)

	# thrust while fuel remains
	if _fuel > 0.0:
		var thrust_dir: Vector3 = global_transform.basis.y.normalized()
		apply_central_force(thrust_dir * config.engine_thrust)
		_fuel = maxf(_fuel - _burn_rate * delta, 0.0)
		mass = _dry_mass + _fuel * _fuel_mass_factor
		if _fuel <= 0.0 and engine_particles:
			engine_particles.emitting = false

	# wind + drag (computed against the air, not the ground)
	var relative_velocity: Vector3 = velocity - _wind_velocity
	var rel_speed: float = relative_velocity.length()
	if rel_speed > 0.01:
		var rho: float = AeroPhysics.air_density_at(altitude)
		var area: float = AeroPhysics.frontal_area(config.rocket_radius)
		var cd: float = AeroPhysics.drag_coefficient(_base_cd, config.fin_count, config.fin_size, _fin_drag_factor)
		var drag_mag: float = AeroPhysics.drag_force(rel_speed, rho, cd, area)
		apply_central_force(-relative_velocity.normalized() * drag_mag)
		_drag_energy_lost += drag_mag * rel_speed * delta

		# fin stabilization: rotate the nose toward the airflow
		var nose_dir: Vector3 = global_transform.basis.y.normalized()
		var flight_dir: Vector3 = relative_velocity.normalized()
		var misalignment: float = nose_dir.angle_to(flight_dir)
		if misalignment > 0.001:
			var axis: Vector3 = nose_dir.cross(flight_dir).normalized()
			var strength: float = AeroPhysics.stabilizing_strength(config.fin_size, config.fin_count, _stability_multiplier, rel_speed)
			apply_torque(axis * misalignment * strength)

	# optional: canted fins induce roll (stretch)
	# if absf(config.fin_angle) > 0.01 and speed > 1.0:
	#     apply_torque(global_transform.basis.y * deg_to_rad(config.fin_angle) * speed * 0.05)

	# telemetry
	max_altitude = maxf(max_altitude, altitude)
	max_speed = maxf(max_speed, speed)
	var tilt_deg: float = rad_to_deg(global_transform.basis.y.angle_to(Vector3.UP))
	_max_tilt = maxf(_max_tilt, tilt_deg)
	_tilt_sum += tilt_deg
	_tilt_samples += 1

	var fuel_ratio: float = (_fuel / config.fuel_amount) if config.fuel_amount > 0.0 else 0.0
	telemetry_updated.emit(altitude, speed, tilt_deg, fuel_ratio)

	_check_for_end(altitude, tilt_deg)

func _check_for_end(altitude: float, tilt_deg: float) -> void:
	if tilt_deg > 80.0 and altitude > 2.0:
		_finish("Lost control: tumbled past 80 degrees")
	elif altitude <= 0.5 and linear_velocity.y < 0.0 and _fuel <= 0.0:
		_finish("Flight complete: returned to the ground")

func _finish(reason: String) -> void:
	set_physics_process(false)
	if engine_particles:
		engine_particles.emitting = false
	flight_finished.emit(reason)

func average_tilt() -> float:
	return (_tilt_sum / float(_tilt_samples)) if _tilt_samples > 0 else 0.0

func get_max_tilt() -> float:
	return _max_tilt

func get_drag_loss() -> float:
	return _drag_energy_lost
```

### `scripts/simulation_manager.gd`

```gdscript
class_name SimulationManager
extends Node

signal results_ready(results: Dictionary)

@export var rocket_path: NodePath
@export var camera_path: NodePath

var _rocket: RocketController
var _camera: Node
var _running: bool = false
var _elapsed: float = 0.0
const MAX_FLIGHT_TIME: float = 30.0   # safety timeout, seconds

func _ready() -> void:
	_rocket = get_node(rocket_path) as RocketController
	_camera = get_node_or_null(camera_path)
	if _rocket:
		_rocket.flight_finished.connect(_on_flight_finished)

func start_launch(config: RocketConfig) -> void:
	_elapsed = 0.0
	_running = true
	_rocket.setup(config)
	_rocket.launch()
	if _camera and _camera.has_method("shake"):
		_camera.shake(0.7, 0.25)   # duration, intensity

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed >= MAX_FLIGHT_TIME:
		_on_flight_finished("Flight timed out at apogee")

func _on_flight_finished(reason: String) -> void:
	if not _running:
		return
	_running = false
	var results: Dictionary = ResultsCalculator.build_results(_rocket, reason)
	results_ready.emit(results)
```

### `scripts/results_calculator.gd`

```gdscript
class_name ResultsCalculator
extends RefCounted

static func build_results(rocket: RocketController, reason: String) -> Dictionary:
	var avg_tilt: float = rocket.average_tilt()
	var max_tilt: float = rocket.get_max_tilt()
	var stability: float = clampf(100.0 - avg_tilt * 1.8 - max_tilt * 0.4, 0.0, 100.0)
	var success: bool = max_tilt < 45.0 and rocket.max_altitude > 10.0
	return {
		"max_height": rocket.max_altitude,
		"max_speed": rocket.max_speed,
		"stability_score": stability,
		"drag_loss": rocket.get_drag_loss(),
		"max_tilt": max_tilt,
		"success": success,
		"failure_reason": "Nominal flight" if success else reason,
	}
```

### `scripts/ui_controller.gd`

```gdscript
class_name UIController
extends Control

signal launch_requested(config: RocketConfig)
signal reset_requested

# Mark each of these nodes "Access as Unique Name" (%) in the scene tree.
@onready var fin_count_slider: HSlider = %FinCountSlider
@onready var fin_size_slider: HSlider = %FinSizeSlider
@onready var wind_speed_slider: HSlider = %WindSpeedSlider
@onready var wind_dir_slider: HSlider = %WindDirSlider
@onready var mass_slider: HSlider = %MassSlider
@onready var radius_slider: HSlider = %RadiusSlider
@onready var thrust_slider: HSlider = %ThrustSlider
@onready var fuel_slider: HSlider = %FuelSlider
@onready var body_material_option: OptionButton = %BodyMaterialOption
@onready var fin_material_option: OptionButton = %FinMaterialOption

@onready var altitude_label: Label = %AltitudeLabel
@onready var speed_label: Label = %SpeedLabel
@onready var tilt_label: Label = %TiltLabel
@onready var stability_meter: ProgressBar = %StabilityMeter
@onready var status_label: Label = %StatusLabel

@onready var launch_button: Button = %LaunchButton
@onready var reset_button: Button = %ResetButton
@onready var results_panel: Control = %ResultsPanel

func _ready() -> void:
	_populate_materials()
	launch_button.pressed.connect(_on_launch_pressed)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	results_panel.visible = false

func _populate_materials() -> void:
	for option in [body_material_option, fin_material_option]:
		option.clear()
		for n in MaterialDatabase.material_names():
			option.add_item(n)

func build_config() -> RocketConfig:
	var c := RocketConfig.new()
	c.fin_count = int(fin_count_slider.value)
	c.fin_size = fin_size_slider.value
	c.wind_speed = wind_speed_slider.value
	c.wind_direction = wind_dir_slider.value
	c.rocket_mass = mass_slider.value
	c.rocket_radius = radius_slider.value
	c.engine_thrust = thrust_slider.value
	c.fuel_amount = fuel_slider.value
	c.body_material = body_material_option.get_item_text(body_material_option.selected)
	c.fin_material = fin_material_option.get_item_text(fin_material_option.selected)
	return c

func _on_launch_pressed() -> void:
	results_panel.visible = false
	status_label.text = "In flight"
	launch_requested.emit(build_config())

func update_telemetry(altitude: float, speed: float, tilt: float, _fuel_ratio: float) -> void:
	altitude_label.text = "ALT  %6.1f m" % altitude
	speed_label.text = "VEL  %6.1f m/s" % speed
	tilt_label.text = "TILT %5.1f deg" % tilt
	stability_meter.value = clampf(100.0 - tilt * 2.0, 0.0, 100.0)

func show_results(results: Dictionary) -> void:
	results_panel.visible = true
	status_label.text = "Apogee %.0f m" % results["max_height"]
	# Populate the result cards inside ResultsPanel here using the dictionary keys:
	# max_height, max_speed, stability_score, drag_loss, success, failure_reason
```

### `scripts/main.gd`

```gdscript
extends Node3D

@onready var sim: SimulationManager = $SimulationManager
@onready var rocket: RocketController = $World/Rocket
@onready var ui: UIController = $UILayer/DashboardUI

func _ready() -> void:
	ui.launch_requested.connect(sim.start_launch)
	ui.reset_requested.connect(_on_reset)
	sim.results_ready.connect(ui.show_results)
	rocket.telemetry_updated.connect(ui.update_telemetry)

func _on_reset() -> void:
	get_tree().reload_current_scene()
```

### `scripts/simulation_camera.gd`

```gdscript
extends Camera3D

@export var target_path: NodePath
var _target: Node3D
var _base_position: Vector3
var _shake_time: float = 0.0
var _shake_intensity: float = 0.0

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_base_position = position

func shake(duration: float, intensity: float) -> void:
	_shake_time = duration
	_shake_intensity = intensity

func _process(delta: float) -> void:
	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		offset = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * _shake_intensity
	# follow the rocket's height a little so it does not fly out of frame
	var follow_y := _base_position.y
	if _target:
		follow_y = _base_position.y + _target.global_position.y * 0.3
	position = Vector3(_base_position.x, follow_y, _base_position.z) + offset
	if _target:
		look_at(_target.global_position, Vector3.UP)
```

---

## 13. Godot node setup instructions

Build each scene with these exact nodes. Names matter because the scripts reference them.

**`Rocket.tscn`** (root `RigidBody3D`, attach `rocket_controller.gd`):
- `RigidBody3D` "Rocket" — set `gravity_scale = 0`, `can_sleep = off`, `angular_damp ≈ 1.0`, `freeze = on`
  - `MeshInstance3D` "BodyMesh" — a `CapsuleMesh` or `CylinderMesh` with a cone nose; give it a `StandardMaterial3D`
  - `CollisionShape3D` "Collision" — a `CapsuleShape3D` roughly matching the body
  - `Node3D` "FinHolder" — empty, fins spawn here
  - `GPUParticles3D` "EngineParticles" — at the base, `emitting = off`, `ParticleProcessMaterial` shooting downward, orange
- In the inspector, assign `Fin.tscn` to the controller's **fin_scene** slot.

**`Fin.tscn`** (root `Node3D`):
- `Node3D` "Fin"
  - `MeshInstance3D` "FinMesh" — a thin `BoxMesh` (or an imported model, see section 14)
  - `CollisionShape3D` "FinCollision" — optional, only if you want fins to collide on landing

**`LaunchPad.tscn`** (root `StaticBody3D`):
- `StaticBody3D` "LaunchPad"
  - `MeshInstance3D` "Deck" — a wide flat `BoxMesh`
  - `CollisionShape3D` "DeckCollision" — a `BoxShape3D` matching the deck
  - Optional `Node3D` gantry props made of boxes

**`SimulationCamera.tscn`** (root `Camera3D`, attach `simulation_camera.gd`):
- `Camera3D` "SimulationCamera" — position it back, up, and slightly to the side, angled down toward the pad

**`DashboardUI.tscn`** (root `Control`, attach `ui_controller.gd`):
- `Control` "DashboardUI" (full rect)
  - `PanelContainer` "LeftPanel" → `VBoxContainer` with every slider + its value `Label` + the two `OptionButton`s
  - `PanelContainer` "RightPanel" → `VBoxContainer` with `AltitudeLabel`, `SpeedLabel`, `TiltLabel`, `StabilityMeter` (`ProgressBar`)
  - `HBoxContainer` "BottomBar" → `LaunchButton`, `ResetButton`, `StatusLabel`
  - an instance of `ResultsPanel.tscn` named "ResultsPanel"
- Mark every node the script reads as **Access as Unique Name**.

**`Main.tscn`** (root `Node3D`, attach `main.gd`):
- `Node3D` "Main"
  - `Node3D` "World"
    - instance of `LaunchPad.tscn`
    - instance of `Rocket.tscn` (named "Rocket", sitting just above the pad)
    - `DirectionalLight3D` "Sun"
    - `WorldEnvironment` (dark sky, optional glow for telemetry)
  - instance of `SimulationCamera.tscn`
  - `SimulationManager` (Node, attach `simulation_manager.gd`) — set its `rocket_path` to the Rocket and `camera_path` to the camera
  - `CanvasLayer` "UILayer"
    - instance of `DashboardUI.tscn` named "DashboardUI"

---

## 14. How to handle imported fin models

You can use a real fin model or fall back to built-in geometry. Build the fallback first so nobody is blocked waiting on an artist.

**Importing a `.glb` / `.gltf` fin:**
1. Drop `fin_default.glb` into `assets/models/`. Godot imports it automatically.
2. Open `Fin.tscn`. Drag the imported `.glb` in as a child of the "Fin" root, or open the `.glb`, right-click the scene root, and choose **Save Branch as Scene** to make it editable.
3. Make sure the model's pivot sits at the fin's mounting edge and the fin points outward along +X in its local space, so the runtime placement in `_build_fins()` lines up. Rotate the mesh, not the script.
4. If the model imports huge, set the import scale (select the `.glb` in the FileSystem dock, Import tab, lower the scale, click Reimport), or scale the `MeshInstance3D` down inside `Fin.tscn`.

**Fallback with built-in geometry (do this first):**
- In `Fin.tscn`, use a `MeshInstance3D` with a thin `BoxMesh`, for example size `(0.02, 0.4, 0.25)`, tilted slightly. It reads clearly as a fin and needs no assets.

Because `rocket_controller.gd` only cares about `fin_count` and `fin_size` for physics, you can swap the visual fin (box vs imported model) at any time without touching the simulation. That decoupling is intentional.

---

## 15. Team collaboration plan

Five roles, clear file ownership. The golden rule: nobody opens a `.tscn` they do not own.

| Role | Owns (edit freely) | Do not touch |
|------|--------------------|--------------|
| Physics | `aero_physics.gd`, `wind_model.gd`, `rocket_controller.gd`, `Rocket.tscn` | `Main.tscn`, UI scenes |
| UI | `ui_controller.gd`, `DashboardUI.tscn`, `ResultsPanel.tscn`, `assets/ui/` | `Main.tscn`, `Rocket.tscn`, physics scripts |
| Visuals | `simulation_camera.gd`, `LaunchPad.tscn`, `SimulationCamera.tscn`, particle nodes, `assets/materials/` | physics scripts, UI scripts |
| Materials and results | `material_database.gd`, `results_calculator.gd`, the materials table | scene files |
| Integration | `Main.tscn`, `main.gd`, `simulation_manager.gd`, merges and releases | everyone's working files mid-task |

**Hard rules**

- Pull before you start working. Every time.
- Commit the moment a feature actually works, not hours later.
- Push often so others see your scenes early.
- Never edit the same `.tscn` as someone else at the same time. Scene files merge badly.
- One person owns `Main.tscn`. Others ask them to wire new nodes in.
- New code goes in new scripts when possible, so two people rarely edit the same file.
- Clear commit messages: `physics: add fin drag penalty`, `ui: wire thrust slider`, not `stuff` or `fixes`.
- If you must touch someone's file, tell them in chat first and pull right after they push.

Why so strict on scenes: Godot `.tscn` files are text, but the editor rewrites internal node IDs and ordering on save. Two simultaneous edits almost always conflict. Owning scenes per person sidesteps the most common hackathon Git disaster.

---

## 16. Demo plan

Target 60 to 90 seconds. Rehearse it twice before judging.

1. **0:00 to 0:10.** "This is Project Stellar, a rocket fin design simulator." Show the dashboard. Load the bad preset: 1 small fin, heavy steel body, gusty crosswind.
2. **0:10 to 0:30.** Hit Launch. The rocket lifts, tilts into the wind, wobbles, and tumbles. Results panel: low altitude, low stability score, red banner, "Lost control."
3. **0:30 to 0:35.** "Let's fix it." Talk while you adjust.
4. **0:35 to 0:55.** Bump fins from 1 to 4, increase fin size a notch, switch the body from steel to carbon fiber. Optionally nudge thrust up.
5. **0:55 to 1:15.** Relaunch. Clean vertical climb, fins holding it steady through the same wind. Results panel: much higher altitude, high stability score, green banner.
6. **1:15 to 1:30.** "Same engine, same wind. We changed the fins and the material and got a stable, higher flight. That is the design loop, virtually, in seconds." Land the pitch.

Lock both presets in code or a `presets.json` so you are never fiddling with twelve sliders live.

---

## 17. Pitch angle

Here's why this matters beyond a cool demo. Physical rocket prototyping is slow, expensive, and risky. Project Stellar is a fast, visual way to build intuition about how fin geometry, mass, and materials trade against stability and altitude before anyone cuts metal.

For a company like SpaceX, the value reads as:
- Faster virtual prototyping. Test a hundred fin configurations in an afternoon instead of one in a month.
- Early-stage design screening. Kill bad configurations on a laptop, not on a test stand.
- Lower cost. Fewer physical builds means less material and less stand time.
- Safer experimentation. Find the "this tumbles" cases in software where nothing explodes.
- Educational and engineering value. New engineers and students build real intuition for why stability matters and what fins actually do.
- Better launch reliability and sustainability. More stable designs mean fewer failed launches, less debris, and less waste.

We are not claiming to replace CFD or flight software. We are claiming the first ten minutes of a design conversation should happen here, fast and visual, before the expensive tools come out.

---

## 18. Build priorities

**Priority 1, must have.** Rocket launches under thrust. Gravity and fuel work. At least thrust, mass, and fuel sliders are live. Wind pushes the trajectory. Fins change stability. Max height is tracked. Results panel appears. Reset works.

**Priority 2, should have.** All sliders and both material dropdowns wired. Stability score and drag loss in results. Flame and smoke particles. Themed mission-control UI. Success and failure banners.

**Priority 3, nice to have.** Camera shake. Animated wind arrows. Imported custom fin models. Sound. Live altitude graph. Canted-fin roll. Save and compare runs. AI design recommendations.

If you are behind, cut from Priority 3 first, then Priority 2. Never cut Priority 1.

---

## 19. Common bugs and fixes

- **Rocket does not move on launch.** It is probably still frozen or gravity is fighting thrust. Check `freeze = false` after `launch()`, confirm `gravity_scale = 0`, and make sure `engine_thrust` exceeds weight (`mass * 9.81`). Defaults give thrust-to-weight near 3, which lifts cleanly.
- **Rocket flies sideways immediately.** The body's local up axis is not actually up, or thrust is applied along the wrong axis. Confirm thrust uses `global_transform.basis.y` and the rocket starts upright with identity rotation.
- **RigidBody not responding to forces.** Forces must be applied inside `_physics_process` (or `_integrate_forces`), not `_process`. Also check `can_sleep = false` so it does not nap on the pad.
- **Slider changes nothing.** You built the config once at startup instead of on each launch. Call `build_config()` inside `_on_launch_pressed()` every time. Also confirm `int(slider.value)` for fin count.
- **Camera does not follow.** The `target_path` on the camera is unset or points at the wrong node. Set it to the Rocket and verify `look_at` is not throwing because the target equals the camera position.
- **Imported model is gigantic or invisible.** Fix the import scale on the `.glb` (FileSystem dock, Import tab, Reimport) or scale the `MeshInstance3D` inside `Fin.tscn`. Also check the model is not below the floor due to a pivot offset.
- **Collisions behave weirdly (rocket jitters or sinks into the pad).** Mismatched collision shapes. Use a `CapsuleShape3D` that matches the body and a `BoxShape3D` that matches the pad deck, and keep the rocket starting just above the deck, not clipping into it.
- **Rocket oscillates forever and never settles.** Fin torque has no damping. Set `angular_damp ≈ 1.0` on the rocket and tune `_stability_multiplier` down if it overshoots.
- **Git conflict in a `.tscn`.** Two people edited the same scene. Prefer one side fully (usually the scene owner's), reopen in Godot to confirm it loads, recommit. Then re-read section 15 and stop sharing scenes.

---

## 20. Final checklist

**Launch day, before judging**

- [ ] `git pull`, project opens clean in Godot 4.6.1, zero script errors
- [ ] `MaterialDatabase` autoload is registered
- [ ] Bad preset and good preset both load correctly
- [ ] Bad rocket tumbles and shows a red failure result
- [ ] Good rocket flies straight, higher, and shows a green success result
- [ ] Every slider you plan to touch live actually changes the flight
- [ ] Reset works repeatedly with no leftover state
- [ ] Particles, camera, and banners all fire as expected
- [ ] Demo rehearsed twice, under 90 seconds, with the pitch line memorized
- [ ] Final build committed and pushed, everyone on the same commit
- [ ] One laptop designated as the demo machine and tested on the actual screen or projector

**Say during judging:** this is a simplified, real-time, physics-inspired educational simulator, not full CFD. Owning that framing makes the project look smarter, not weaker.

Good luck. Build the MVP first, make the second launch look great, and let the before-and-after tell the story.
