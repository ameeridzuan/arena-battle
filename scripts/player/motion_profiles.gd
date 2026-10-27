extends RefCounted
## Shared timing for the authored poses and the local test controller. No root motion.
const DASH := {"duration": 0.36, "speed": 11.0, "cooldown": 0.85,
	"times": [0.0, 0.05, 0.18, 0.70, 0.92, 1.0], "weights": [0.45, 0.9, 1.0, 1.0, 0.4, 0.0]}
const DODGE := {"duration": 0.42, "speed": 8.0, "cooldown": 0.75,
	"times": [0.0, 0.05, 0.20, 0.65, 0.88, 1.0], "weights": [0.35, 0.85, 1.0, 0.9, 0.3, 0.0]}
const PARRY_START := 0.04
const PARRY_END := 0.22
const PARRY_DURATION := 0.46
const PARRY_SUCCESS_DURATION := 0.30
const PARRY_COOLDOWN := 0.8
const PARRY_CONE_DEGREES := 120.0

static func evasion(id: String) -> Dictionary:
	return DASH if id == "Dash_Forward" else DODGE

static func speed_weight(id: String, phase: float) -> float:
	var spec := evasion(id)
	var times: Array = spec.times
	var weights: Array = spec.weights
	for i in range(1, times.size()):
		if phase <= float(times[i]):
			return lerpf(float(weights[i-1]), float(weights[i]), smoothstep(float(times[i-1]), float(times[i]), phase))
	return 0.0
