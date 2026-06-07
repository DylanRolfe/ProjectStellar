class_name RocketPyBridge
extends RefCounted

## Bridges Godot and the RocketPy flight solver (python/rocket_sim.py).
##
## On start() we serialise the rocket configuration to a JSON file and launch
## the Python solver as a detached process. poll() is called every frame; it
## returns an empty dict while the solver runs and, once the solver has written
## its output file, the parsed result. The game animates the returned trajectory.
##
## If Python or RocketPy is unavailable (no interpreter, import error, etc.) the
## process either fails to start or writes a fallback payload, and the caller
## falls back to the built-in physics. This keeps the game working everywhere.

const SCRIPT_PATH := "res://python/rocket_sim.py"
const INPUT_PATH := "user://rocketpy_input.json"
const OUTPUT_PATH := "user://rocketpy_output.json"
const RUN_TIMEOUT := 35.0

# Interpreters to try, in order. "py" is the Windows launcher; the rest cover
# other platforms / installs. Each entry is [executable, [leading args...]].
const INTERPRETERS := [
	["py", ["-3.13"]],
	["py", []],
	["python", []],
	["python3", []],
]

var _pid: int = -1
var _running: bool = false
var _elapsed: float = 0.0

static func build_config_dict(config: RocketConfig) -> Dictionary:
	var mat: Dictionary = MaterialDatabase.get_material(config.body_material_name)
	var drag_modifier := float(mat.get("drag_modifier", 0.0))
	return {
		"engine_thrust": config.engine_thrust,
		"propellant_mass": config.propellant_mass,
		"burn_time": config.burn_time,
		"rocket_radius": config.rocket_radius,
		"rocket_height": config.rocket_height,
		"dry_mass": config.dry_mass,
		"drag_coefficient": clampf(0.5 + drag_modifier, 0.2, 1.5),
		"wind_speed": config.wind_speed,
		"wind_direction": config.wind_direction,
		"fin_count": config.fin_count,
		"fin_size": config.fin_size,
	}

## Writes the config and spawns the solver. Returns false if no interpreter
## could be started (caller should then use the physics fallback).
func start(config: RocketConfig) -> bool:
	var input_file := FileAccess.open(INPUT_PATH, FileAccess.WRITE)
	if input_file == null:
		push_warning("RocketPyBridge: cannot write input file")
		return false
	input_file.store_string(JSON.stringify(build_config_dict(config)))
	input_file.close()

	# Remove any stale output so poll() only sees a fresh result.
	if FileAccess.file_exists(OUTPUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT_PATH))

	var script_abs := ProjectSettings.globalize_path(SCRIPT_PATH)
	var input_abs := ProjectSettings.globalize_path(INPUT_PATH)
	var output_abs := ProjectSettings.globalize_path(OUTPUT_PATH)

	for entry in INTERPRETERS:
		var exe: String = entry[0]
		var args: Array = (entry[1] as Array).duplicate()
		args.append(script_abs)
		args.append(input_abs)
		args.append(output_abs)
		_pid = OS.create_process(exe, PackedStringArray(args))
		if _pid > 0:
			_running = true
			_elapsed = 0.0
			print("RocketPyBridge: launched '%s' (pid %d)" % [exe, _pid])
			return true

	push_warning("RocketPyBridge: no Python interpreter could be started")
	return false

## Call every frame. Returns:
##   {}                                   -> still solving
##   {"done": true, "ok": true,  "data": <payload>}  -> finished, parsed result
##   {"done": true, "ok": false, "data": {}}         -> failed / timed out
func poll(delta: float) -> Dictionary:
	if not _running:
		return {}
	_elapsed += delta

	if FileAccess.file_exists(OUTPUT_PATH):
		_running = false
		var text := FileAccess.get_file_as_string(OUTPUT_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and (parsed as Dictionary).has("samples"):
			return {"done": true, "ok": true, "data": parsed}
		return {"done": true, "ok": false, "data": {}}

	if _elapsed >= RUN_TIMEOUT:
		_running = false
		if _pid > 0 and OS.is_process_running(_pid):
			OS.kill(_pid)
		push_warning("RocketPyBridge: solver timed out")
		return {"done": true, "ok": false, "data": {}}

	return {}

func is_running() -> bool:
	return _running
