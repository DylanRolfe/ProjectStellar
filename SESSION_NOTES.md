# Project Stellar — Claude Code session notes

A human-readable record of the work done with Claude Code so you can pick up
where you left off even if the chat window is closed. (The actual chat can also
be resumed — see "Getting the chat back" at the bottom.)

Branch all of this lives on: **`final`** (the `main` branch is untouched).
Last commit: `22fdc13` — "Add SetupInstructions and title-screen RocketPy warning".

---

## What was built (high level)

1. **Title screen** ([scenes/TitleScreen.tscn](scenes/TitleScreen.tscn),
   [scripts/title_screen.gd](scripts/title_screen.gd)) — "PROJECT STELLAR"
   wordmark, scanner line, "press any key to begin" prompt, and a soft
   bottom-right warning to read the setup instructions (pulses with the prompt).
   Themed to match projectstellar.ca ([theme/stellar_theme.tres](theme/stellar_theme.tres),
   fonts in [assets/fonts/](assets/fonts/)).

2. **RocketPy physics pipeline** — the real flight solver:
   - [python/rocket_sim.py](python/rocket_sim.py): maps the in-game rocket to a
     RocketPy Environment/Motor/Rocket/Flight, flies it, returns a sampled
     trajectory + results as JSON. Runs directly (no multiprocessing) and is
     sanitised so it always solves quickly.
   - [scripts/rocketpy_bridge.gd](scripts/rocketpy_bridge.gd): writes the config,
     spawns Python (`py -3.13` → `py` → `python` → `python3`), polls for the
     result. Falls back to built-in physics if RocketPy isn't installed.
   - [scripts/rocket_controller.gd](scripts/rocket_controller.gd) animates the
     returned trajectory (playback mode) and exposes live telemetry.

3. **Realistic controls** ([scenes/DashboardUI.tscn](scenes/DashboardUI.tscn),
   [scripts/ui_controller.gd](scripts/ui_controller.gd),
   [scripts/rocket_config.gd](scripts/rocket_config.gd)) — dry mass, payload,
   propellant, thrust, burn time, diameter, length, wind sliders with sensible
   defaults; liftoff-mass and thrust-to-weight readouts.

4. **Ring-shaped wind dial** ([scripts/radial_slider.gd](scripts/radial_slider.gd))
   for wind direction.

5. **Advanced wind menu** ([scripts/wind_advanced_panel.gd](scripts/wind_advanced_panel.gd))
   — 3 altitude layers, each with its own wind speed + angle, with two draggable
   boundary sliders. Opened via the `+` next to Wind. RocketPy flies the layered
   wind profile.

6. **Fin designer** ([scripts/fin_editor.gd](scripts/fin_editor.gd),
   [scripts/fin_shape_canvas.gd](scripts/fin_shape_canvas.gd)) — draggable green
   root corners (change root chord), info stats one-per-line, click tooltips.

7. **Flight HUD** ([scripts/flight_hud.gd](scripts/flight_hud.gd)) — live
   altitude, speed, mass, apogee, max speed, downrange, T+ (click a stat for help).

8. **Camera/zoom** ([scripts/simulation_camera.gd](scripts/simulation_camera.gd),
   [scripts/zoom_controls.gd](scripts/zoom_controls.gd)) — right-click drag to
   orbit, +/- zoom buttons (with a "right click and drag to rotate" hint),
   stronger proportional zoom, smooth trackpad gestures.

9. **Reset behaviour** — `Reset` re-arms on the pad keeping the design;
   `Back to Start` returns to the fin designer; each page has its own
   `Reset to Default`.

10. **Environment** ([scripts/desert_environment.gd](scripts/desert_environment.gd),
    [scripts/star_field.gd](scripts/star_field.gd)) — scattered props no longer
    overlap (minimum spacing); stars fade in with altitude (start ~600 m, peak
    ~1.2 km) and follow the camera so they stay in the blue sky.

11. **Setup guide** ([SetupInstructions.md](SetupInstructions.md)) — how to
    install Godot 4.6.1 + RocketPy.

---

## To run it
- Install Godot **4.6.1** and run `pip install rocketpy` (see
  [SetupInstructions.md](SetupInstructions.md)).
- Open `project.godot` in Godot and press F5.

## Known follow-ups / things to double-check
- The up/down orbit direction was inverted at your request — confirm it feels
  right; flipping it back is a one-line change in `simulation_camera.gd`.
- RocketPy must be installed for the real physics; otherwise the game falls back
  to the simpler built-in model.

---

## Getting the chat back
Claude Code stores each conversation as a transcript on disk (under
`~/.claude/projects/<this-project>/`), so closing the window does **not** delete it:
- In the terminal, run `claude --resume` (or `claude -r`) in this project folder
  to pick a past session from a list, or `claude --continue` (`claude -c`) to
  reopen the most recent one.
- In the VS Code / IDE extension, use the session/history picker to reopen a
  previous conversation.
