class_name ResultsCalculator
extends RefCounted

static func build_results(rocket: RocketController, reason: String) -> Dictionary:
	var stability_score := clampf(100.0 - rocket.average_tilt() * 1.5 - rocket.max_tilt * 0.4, 0.0, 100.0)
	var success := stability_score >= 60.0 and rocket.max_tilt < 55.0 and rocket.max_altitude > 5.0
	return {
		"max_height": rocket.max_altitude,
		"max_speed": rocket.max_speed,
		"stability_score": stability_score,
		"max_tilt": rocket.max_tilt,
		"flight_time": rocket.flight_time(),
		"success": success,
		"failure_reason": "Stable flight" if success else reason,
	}
