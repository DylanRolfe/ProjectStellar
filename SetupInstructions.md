# Project Stellar — Setup Instructions

This guide gets the rocket simulator running from scratch. There are two pieces
to install:

1. **Godot 4.6.1** — the game engine that runs the simulator.
2. **Python + RocketPy** — the physics solver the game calls to fly the rocket.

> You can hand this whole file to an AI assistant and ask it to walk you through
> the steps, or just follow it yourself. It should take about 10–15 minutes.

> **Note:** I can't embed screenshots in this file, so each step links to the
> official page (which has pictures). If a step is unclear, paste that step into
> an AI assistant and ask "show me what this looks like."

---

## TL;DR (for people in a hurry)

```
1. Install Python 3.11–3.13 from python.org  (CHECK "Add python.exe to PATH")
2. Open a terminal and run:   pip install rocketpy
3. Download Godot 4.6.1 (standard build) from godotengine.org/download/archive
4. Unzip it, open the Godot .exe, "Import" this project's  project.godot
5. Press F5 (or the ▶ Play button) to run.
```

If RocketPy isn't installed, the game still runs — it just falls back to a
simpler built-in physics model instead of the real RocketPy flight solver.

---

## Part 1 — Install Python and RocketPy

RocketPy is a Python library, so you need Python first.

### 1.1 Install Python

- Go to the official downloads page: **https://www.python.org/downloads/**
- Download Python **3.11, 3.12, or 3.13** (any of these work).
- Run the installer.
- ⚠️ **IMPORTANT (Windows):** on the first installer screen, tick the box
  **"Add python.exe to PATH"** at the bottom **before** clicking *Install Now*.
  If you miss this, the `python` and `pip` commands won't be found later.

Installer help with screenshots: https://docs.python.org/3/using/windows.html

### 1.2 Verify Python works

Open a terminal:
- **Windows:** press `Win`, type `cmd`, press Enter (or use PowerShell).
- **macOS:** open the **Terminal** app.
- **Linux:** open your terminal.

Run:

```
python --version
```

(On macOS/Linux, or if `python` isn't found on Windows, try `python3 --version`
or, on Windows, `py --version`.)

You should see something like `Python 3.13.1`.

### 1.3 Install RocketPy

In that same terminal, run:

```
pip install rocketpy
```

(If `pip` isn't found, try `python -m pip install rocketpy`, or on Windows
`py -m pip install rocketpy`.)

This downloads RocketPy and its dependencies (numpy, scipy, etc.). It can take a
couple of minutes and prints a lot of text — that's normal. When it finishes you
should see a line like `Successfully installed rocketpy-...`.

### 1.4 Verify RocketPy installed

```
python -c "import rocketpy; print('RocketPy OK')"
```

If it prints `RocketPy OK`, you're done with Part 1. If you get
`ModuleNotFoundError: No module named 'rocketpy'`, the install went to a
different Python than the one you're running — see Troubleshooting below.

---

## Part 2 — Install Godot 4.6.1

The project is built for Godot **4.6.1** (standard/GDScript build — **not** the
C#/.NET/Mono build).

### 2.1 Download Godot 4.6.1

- Open the version archive: **https://godotengine.org/download/archive/4.6.1-stable/**
- Download the build for your system:
  - **Windows:** `Godot_v4.6.1-stable_win64.exe.zip`
  - **macOS:** `Godot_v4.6.1-stable_macos.universal.zip`
  - **Linux:** `Godot_v4.6.1-stable_linux.x86_64.zip`
- (Alternative source: the GitHub release page
  https://github.com/godotengine/godot/releases/tag/4.6.1-stable )

### 2.2 Unzip and run Godot

- Godot doesn't need an installer — it's a single program inside the zip.
- **Unzip** the downloaded file, then **double-click the Godot executable**
  (e.g. `Godot_v4.6.1-stable_win64.exe`).
- On Windows you may get a "Windows protected your PC" SmartScreen warning the
  first time — click **More info → Run anyway** (Godot is safe; it's just
  unsigned).

---

## Part 3 — Open and run the project

1. When Godot opens, you'll see the **Project Manager**.
2. Click **Import**.
3. Browse to this project's folder and select the **`project.godot`** file
   (it's in the root of the Project Stellar folder), then click **Open** →
   **Import & Edit**.
4. The Godot editor opens. The first time, it imports assets — give it a moment.
5. Press **F5**, or click the **▶ (Play)** button in the top-right, to run it.

You should see the **PROJECT STELLAR** title screen — press any key to begin.

---

## How to know RocketPy is actually being used

- Design a rocket and launch it. While it computes, the status shows
  **"Computing flight…"** for a couple of seconds — that's the game calling
  RocketPy. Then the rocket flies the computed trajectory.
- If RocketPy is **not** found, launches are instant and use the simpler
  built-in physics instead. The game still works either way.

---

## Troubleshooting

**"`pip` / `python` is not recognized" (Windows).**
Python wasn't added to PATH. Re-run the Python installer, choose **Modify**, and
enable **"Add Python to environment variables"** — or just reinstall and tick
**"Add python.exe to PATH"**. Then open a **new** terminal and try again. The
Windows `py` launcher (`py --version`, `py -m pip install rocketpy`) usually
works even when `python` doesn't.

**"`ModuleNotFoundError: No module named 'rocketpy'`" even after installing.**
You have more than one Python and pip installed RocketPy into a different one.
Install it into the exact interpreter you'll run:
`python -m pip install rocketpy` (or `py -m pip install rocketpy` on Windows).

**Launches are instant / flights look too simple.**
That means the game couldn't run RocketPy and fell back to built-in physics.
Re-check Part 1 (especially step 1.4). The game looks for Python via these
commands, in order: `py -3.13`, `py`, `python`, `python3` — so make sure at
least one of those can `import rocketpy`.

**Godot won't open the project / wrong version.**
Make sure it's Godot **4.6.x** (this project targets 4.6.1). Older 4.x or 3.x
versions won't load it correctly.

**macOS "Godot can't be opened because it is from an unidentified developer."**
Right-click the Godot app → **Open** → **Open**, or allow it under
*System Settings → Privacy & Security*.

---

## Optional: prompt to paste into an AI assistant

> "I want to run a Godot game that uses the Python library RocketPy for physics.
> Help me, step by step, to: (1) install Python and add it to PATH, (2) run
> `pip install rocketpy` and verify it imports, and (3) download Godot 4.6.1
> (standard build), import the project's `project.godot`, and run it. I'm on
> [Windows / macOS / Linux]. Show me what each step looks like."
