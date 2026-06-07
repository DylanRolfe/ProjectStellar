extends Control

## Boot screen shown before the simulator. Mirrors the projectstellar.ca hero:
## gradient "PROJECT STELLAR" wordmark over a dark sci-fi backdrop with a
## sweeping scanner line and a flashing "press any key to begin" prompt.

@onready var prompt: Label = $CenterContainer/VBox/ClickPrompt
@onready var scanner: ColorRect = $ScannerLine
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var setup_warning: Label = $SetupWarning

var _started: bool = false

func _ready() -> void:
	# Flashing prompt — pulse the alpha forever.
	var pulse := create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.12, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# The setup warning pulses in time with the prompt, brightening to a soft
	# lighter white at the peak. Same timing/phase keeps them in sync.
	var warn_dim := Color(0.9, 0.92, 0.96, 0.35)
	var warn_bright := Color(1.25, 1.3, 1.4, 0.85)
	setup_warning.modulate = warn_bright
	var warn_pulse := create_tween().set_loops()
	warn_pulse.tween_property(setup_warning, "modulate", warn_dim, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	warn_pulse.tween_property(setup_warning, "modulate", warn_bright, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Scanner line sweeping top-to-bottom, echoing the website's .scanner-line.
	var screen_height := get_viewport_rect().size.y
	var sweep := create_tween().set_loops()
	sweep.tween_property(scanner, "position:y", screen_height + 20.0, 7.0) \
		.from(-20.0).set_trans(Tween.TRANS_LINEAR)

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	# Start on any key press (keyboard or controller button), not on mouse click.
	var triggered: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed)
	if triggered:
		_begin()

func _begin() -> void:
	_started = true
	var t := create_tween()
	t.tween_property(fade_overlay, "modulate:a", 1.0, 0.35)
	t.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Main.tscn"))
