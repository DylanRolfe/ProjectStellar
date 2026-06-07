"""Project Stellar — RocketPy flight solver.

Godot writes the rocket configuration to a JSON file and runs this script:

    py -3.13 rocket_sim.py <input.json> <output.json>

We translate the in-game rocket parameters into a RocketPy model, fly it, and
write back a trajectory (sampled position over time) plus summary results.
Godot then animates the rocket along that trajectory.

The output JSON is ALWAYS written (even on failure) so the game can react
gracefully. Coordinates in the samples are relative to the launch point:
    x = East (m), y = North (m), z = altitude above ground (m), v = speed (m/s)
"""

import json
import math
import os
import sys
import traceback

GRAVITY = 9.80665


def clamp(value, low, high):
    return max(low, min(high, value))


def write_output(path, payload):
    # Write to a temp file and atomically replace, so a reader (Godot) polling
    # for the output file never sees a half-written JSON document.
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(payload, handle)
    os.replace(tmp, path)


def fallback_payload(error, reason="Simulation unavailable"):
    """Minimal, valid payload used when RocketPy cannot produce a flight."""
    return {
        "ok": False,
        "error": str(error),
        "burn_time": 0.0,
        "results": {
            "max_height": 0.0,
            "max_speed": 0.0,
            "flight_time": 0.0,
            "x_displacement": 0.0,
            "stability_score": 0.0,
            "max_tilt": 0.0,
            "success": False,
            "failure_reason": reason,
        },
        "samples": [
            {"t": 0.0, "x": 0.0, "y": 0.0, "z": 0.0, "v": 0.0},
            {"t": 1.0, "x": 0.0, "y": 0.0, "z": 0.0, "v": 0.0},
        ],
    }


def no_liftoff_payload(burn_time):
    """Rocket too heavy for its thrust — it sits on the pad."""
    return {
        "ok": True,
        "burn_time": round(float(burn_time), 4),
        "static_margin": 0.0,
        "results": {
            "max_height": 0.0,
            "max_speed": 0.0,
            "flight_time": 1.0,
            "x_displacement": 0.0,
            "stability_score": 0.0,
            "max_tilt": 0.0,
            "success": False,
            "failure_reason": "Insufficient thrust — rocket never left the pad",
        },
        "samples": [
            {"t": 0.0, "x": 0.0, "y": 0.0, "z": 0.0, "v": 0.0},
            {"t": 1.0, "x": 0.0, "y": 0.0, "z": 0.0, "v": 0.0},
        ],
    }


def build_wind_profile(layers):
    """Turn altitude wind layers into RocketPy [altitude, value] tables.

    Each layer is {"top": metres, "speed": m/s, "angle": deg}, ordered low->high.
    Produces a near-stepwise East (u) and North (v) profile.
    """
    wind_u = []
    wind_v = []
    prev_top = 0.0
    for i, layer in enumerate(layers):
        speed = max(0.0, float(layer.get("speed", 0.0)))
        angle = math.radians(float(layer.get("angle", 0.0)))
        u = speed * math.sin(angle)
        v = speed * math.cos(angle)
        top = float(layer.get("top", 9000.0))
        bottom = prev_top if i == 0 else prev_top + 1.0
        if top <= bottom:
            top = bottom + 1.0
        wind_u.append([bottom, u])
        wind_u.append([top, u])
        wind_v.append([bottom, v])
        wind_v.append([top, v])
        prev_top = top
    return wind_u, wind_v


def build_and_fly(cfg):
    # Imported lazily so a missing dependency still produces a clean fallback.
    from rocketpy import Environment, GenericMotor, Rocket, Flight

    # ---- Parameter mapping ------------------------------------------------
    # Inputs arrive already in real physical units from the game.
    thrust = max(1.0, float(cfg.get("engine_thrust", 500.0)))
    propellant_mass = max(0.0, float(cfg.get("propellant_mass", 0.0)))
    burn_time = clamp(float(cfg.get("burn_time", 3.0)), 0.2, 12.0)
    radius = clamp(float(cfg.get("rocket_radius", 0.06)), 0.02, 1.0)
    height = clamp(float(cfg.get("rocket_height", 1.6)), 0.4, 20.0)
    dry_mass = max(0.3, float(cfg.get("dry_mass", 6.0)))
    drag_cd = clamp(float(cfg.get("drag_coefficient", 0.5)), 0.2, 2.0)

    wind_speed = float(cfg.get("wind_speed", 0.0))
    wind_dir = math.radians(float(cfg.get("wind_direction", 0.0)))

    fin_count = int(cfg.get("fin_count", 0))
    fin_size = clamp(float(cfg.get("fin_size", 0.3)), 0.05, 1.0)

    # Safety net only — inputs are already realistic, but guard against extreme
    # combinations so the RocketPy solve always stays fast and well-behaved.
    propellant_mass = clamp(propellant_mass, 0.0, dry_mass * 4.0)
    liftoff_mass = dry_mass + propellant_mass
    thrust = clamp(thrust, 1.0, 8.0 * liftoff_mass * GRAVITY)  # cap TWR at ~8:1
    twr = thrust / (liftoff_mass * GRAVITY)

    # If the rocket can't overcome its own weight it never leaves the pad.
    # Short-circuit here: RocketPy on a non-lifting rocket yields a degenerate
    # solution that crashes the spline interpolation.
    if twr < 1.05:
        return no_liftoff_payload(burn_time)

    # RocketPy's GenericMotor produces a NaN centre of mass when its dry_mass is
    # zero and the propellant mass dominates. Give the motor a small structural
    # mass and take it out of the airframe mass so the total stays consistent.
    motor_dry_mass = max(1.0, propellant_mass * 0.1)
    struct_mass = max(1.0, dry_mass - motor_dry_mass)

    # The in-game body can be extremely slender (up to ~100 m), which combined
    # with the tiny in-game fins makes the rocket aerodynamically unstable. An
    # unstable rocket tumbles, and RocketPy's 6-DOF solver bogs down to a crawl
    # on tumbling flight. We keep the mass / thrust / drag / wind faithful (they
    # shape the trajectory) but model the aero body at a stable aspect ratio and
    # size the fins generously, so every flight is clean and quick to solve.
    # Fins still help: bigger in-game fins only raise the stability further.
    aero_len = clamp(height, 0.4, 6.0)
    # Size the modelled fins from the body radius and the in-game fin-size
    # control, targeting a realistic ~1.5-2.5 caliber static margin. Bigger fins
    # raise stability (and wind weathercocking); tiny fins make it marginal.
    fin_factor = clamp(0.8 + fin_size * 1.4, 0.8, 2.4)
    model_fin_span = radius * fin_factor
    model_fin_root = clamp(radius * fin_factor * 1.3, 0.03, aero_len * 0.4)
    model_fin_tip = model_fin_root * 0.5
    model_fin_n = max(3, fin_count if fin_count > 0 else 3)

    # Uniform-cylinder inertia for the dry airframe.
    i_axial = 0.5 * struct_mass * radius * radius
    i_trans = (1.0 / 12.0) * struct_mass * (3.0 * radius * radius + aero_len * aero_len)

    # ---- Environment ------------------------------------------------------
    env = Environment(latitude=0.0, longitude=0.0, elevation=0.0)
    layers = cfg.get("wind_layers") if cfg.get("wind_advanced") else None
    if layers:
        # Altitude-layered wind profile (advanced wind menu).
        wind_u_profile, wind_v_profile = build_wind_profile(layers)
        env.set_atmospheric_model(
            type="custom_atmosphere", wind_u=wind_u_profile, wind_v=wind_v_profile
        )
    else:
        # Single uniform wind.
        env.set_atmospheric_model(
            type="custom_atmosphere",
            wind_u=wind_speed * math.sin(wind_dir),   # East component
            wind_v=wind_speed * math.cos(wind_dir),   # North component
        )

    # ---- Motor (constant thrust over the burn) ----------------------------
    motor = GenericMotor(
        thrust_source=thrust,
        burn_time=burn_time,
        chamber_radius=max(0.02, radius * 0.5),
        chamber_height=max(0.1, aero_len * 0.3),
        chamber_position=0.0,
        propellant_initial_mass=max(0.001, propellant_mass),
        nozzle_radius=max(0.01, radius * 0.3),
        dry_mass=motor_dry_mass,
        center_of_dry_mass_position=0.0,
        dry_inertia=(0.0, 0.0, 0.0),
    )

    # ---- Rocket -----------------------------------------------------------
    rocket = Rocket(
        radius=radius,
        mass=struct_mass,
        inertia=(i_trans, i_trans, i_axial),
        power_off_drag=drag_cd,
        power_on_drag=drag_cd,
        center_of_mass_without_motor=0.0,
        coordinate_system_orientation="tail_to_nose",
    )
    # Aerodynamic surfaces must be added BEFORE the motor: add_motor() triggers
    # a static-margin evaluation, which needs a defined centre of pressure (i.e.
    # at least a nose cone) or it divides by zero and produces NaNs.
    nose_len = clamp(aero_len * 0.15, 0.1, aero_len * 0.4)
    try:
        rocket.add_nose(length=nose_len, kind="ogive", position=aero_len / 2.0)
    except Exception:
        pass

    try:
        rocket.add_trapezoidal_fins(
            n=model_fin_n,
            root_chord=model_fin_root,
            tip_chord=model_fin_tip,
            span=model_fin_span,
            position=-aero_len / 2.0 + model_fin_root * 0.5,
        )
    except Exception:
        pass

    # Place the motor mass near the body centre rather than the extreme tail.
    # A tail-heavy rocket has its centre of mass behind the centre of pressure
    # (negative static margin) and tumbles; centring the propellant keeps the
    # modelled rocket stable so the solve stays fast and the flight is clean.
    rocket.add_motor(motor, position=0.0)

    try:
        static_margin = float(rocket.static_margin(0))
    except Exception:
        static_margin = 0.0

    # ---- Flight (powered ascent up to apogee) -----------------------------
    # We let RocketPy fly the aerodynamically-interesting powered + coasting
    # ascent and stop at apogee. The unpowered descent of a finned rocket is
    # prone to tumbling, which makes the 6-DOF solver slow and numerically
    # fragile, so we synthesize a clean ballistic descent ourselves below.
    rail_length = clamp(height * 0.5, 1.0, 50.0)
    flight = Flight(
        rocket=rocket,
        environment=env,
        rail_length=rail_length,
        inclination=90.0,
        heading=0.0,
        terminate_on_apogee=True,
        max_time=40.0,
        max_time_step=0.2,
        rtol=5e-3,
        atol=5e-3,
        verbose=False,
    )

    t_apogee = float(flight.t_final)
    if not math.isfinite(t_apogee) or t_apogee <= 0.0:
        t_apogee = burn_time + 1.0

    x0 = float(flight.x(0.0))
    y0 = float(flight.y(0.0))
    z0 = float(flight.z(0.0))

    def state(t):
        return (
            float(flight.x(t)) - x0,
            float(flight.y(t)) - y0,
            float(flight.z(t)) - z0,
            float(flight.vx(t)),
            float(flight.vy(t)),
            float(flight.vz(t)),
        )

    samples = []
    max_height = 0.0
    max_speed = 0.0
    max_tilt = 0.0

    n_up = int(clamp(t_apogee / 0.04, 8, 1000))
    for i in range(n_up):
        t = t_apogee * i / (n_up - 1)
        x, y, z, vx, vy, vz = state(t)
        if not all(math.isfinite(val) for val in (x, y, z, vx, vy, vz)):
            break
        speed = math.sqrt(vx * vx + vy * vy + vz * vz)
        samples.append({"t": round(t, 4), "x": round(x, 4), "y": round(y, 4),
                        "z": round(z, 4), "v": round(speed, 4)})
        max_height = max(max_height, z)
        max_speed = max(max_speed, speed)
        # Tilt = how far the velocity leans from vertical, measured only during
        # the upward ascent (first ~70% of the climb). The natural arc-over near
        # apogee, where vertical speed approaches zero, is excluded so it is not
        # mistaken for instability.
        if t < 0.7 * t_apogee and vz > 1.0:
            tilt = math.degrees(math.atan2(math.hypot(vx, vy), vz))
            max_tilt = max(max_tilt, tilt)

    # ---- Synthesized ballistic descent from apogee ------------------------
    if samples:
        ax, ay, az, avx, avy, avz = state(t_apogee)
        frontal_area = math.pi * radius * radius
        # Quadratic-drag coefficient k such that a_drag = k * speed * vel / mass.
        k = 0.5 * 1.225 * drag_cd * frontal_area
        px, py, pz = samples[-1]["x"], samples[-1]["y"], samples[-1]["z"]
        vx, vy, vz = avx, avy, 0.0  # vertical velocity ~0 at apogee
        t = t_apogee
        dt = 0.05
        guard = 0
        while pz > 0.0 and guard < 4000:
            guard += 1
            speed = math.sqrt(vx * vx + vy * vy + vz * vz)
            drag = k * speed
            axf = -drag * vx / dry_mass
            ayf = -drag * vy / dry_mass
            azf = -GRAVITY - drag * vz / dry_mass
            vx += axf * dt
            vy += ayf * dt
            vz += azf * dt
            px += vx * dt
            py += vy * dt
            pz += vz * dt
            t += dt
            descent_speed = math.sqrt(vx * vx + vy * vy + vz * vz)
            max_speed = max(max_speed, descent_speed)
            samples.append({"t": round(t, 4), "x": round(px, 4), "y": round(py, 4),
                            "z": round(max(pz, 0.0), 4), "v": round(descent_speed, 4)})
        t_final = t
    else:
        t_final = t_apogee

    last = samples[-1] if samples else {"x": 0.0, "y": 0.0}
    x_displacement = math.hypot(last["x"], last["y"])

    stability_score = clamp(static_margin * 45.0, 0.0, 100.0)
    success = max_height > 5.0 and max_tilt < 55.0
    if max_height <= 5.0:
        reason = "Insufficient thrust — rocket barely cleared the pad"
    elif max_tilt >= 55.0:
        reason = "Unstable flight — rocket tilted %.0f deg off vertical" % max_tilt
    else:
        reason = "Stable flight"

    return {
        "ok": True,
        "burn_time": round(burn_time, 4),
        "static_margin": round(static_margin, 3),
        "results": {
            "max_height": round(max_height, 2),
            "max_speed": round(max_speed, 2),
            "flight_time": round(t_final, 2),
            "x_displacement": round(x_displacement, 2),
            "stability_score": round(stability_score, 1),
            "max_tilt": round(max_tilt, 2),
            "success": bool(success),
            "failure_reason": reason,
        },
        "samples": samples,
    }


def main():
    if len(sys.argv) < 3:
        print("usage: rocket_sim.py <input.json> <output.json>", file=sys.stderr)
        return 2

    input_path, output_path = sys.argv[1], sys.argv[2]
    try:
        with open(input_path, "r", encoding="utf-8") as handle:
            cfg = json.load(handle)
    except Exception as exc:  # noqa: BLE001
        write_output(output_path, fallback_payload(exc, "Could not read config"))
        return 1

    # Run the solve directly (no child process). The input is sanitised into a
    # well-behaved regime so it always returns quickly; if anything ever did
    # hang, the Godot bridge kills this process after its own timeout.
    try:
        payload = build_and_fly(cfg)
    except Exception as exc:  # noqa: BLE001
        traceback.print_exc()
        payload = fallback_payload(exc, "RocketPy simulation failed")
    write_output(output_path, payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
