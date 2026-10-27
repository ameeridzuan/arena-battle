extends RefCounted
## Approved left-leg push: continuous pelvis arc, hand transfer, late right-foot follow.
const HANG_HIP := Vector2(0.53, -0.87)
const HANG_FOOT_HEIGHTS := [-0.85, -1.15]
const CLIMB_KEYS := [
	Vector3(0.00, 0.53, -0.87), Vector3(0.13, 0.50, -0.89),
	Vector3(0.20, 0.62, -0.67), Vector3(0.30, 0.60, -0.27), Vector3(0.43, 0.54, 0.14),
	Vector3(0.56, 0.47, 0.44), Vector3(0.68, 0.12, 0.39),
	Vector3(0.72, 0.08, 0.39), Vector3(0.79, -0.20, 0.52),
	Vector3(0.86, -0.40, 0.70), Vector3(0.94, -0.48, 0.87),
	Vector3(1.00, -0.48, 0.90),
]
const PITCH_KEYS := [Vector3(0, 8, 0), Vector3(0.26, 18, 0), Vector3(0.43, 58, 0), Vector3(0.57, 78, 0), Vector3(0.69, 78, 0), Vector3(0.76, 78, 0), Vector3(0.80, 52, 0), Vector3(0.86, 38, 0), Vector3(0.94, 12, 0), Vector3(1, 0, 0)]
const YAW_KEYS := [Vector3(0, 0, 0), Vector3(0.30, 10, 0), Vector3(0.56, 18, 0), Vector3(0.72, 14, 0), Vector3(0.86, 6, 0), Vector3(1, 0, 0)]
const ROLL_KEYS := [Vector3(0, 0, 0), Vector3(0.42, -6, 0), Vector3(0.72, -6, 0), Vector3(0.86, -4, 0), Vector3(1, 0, 0)]
const BIAS_KEYS := [Vector3(0, 0, 0), Vector3(0.43, 0.035, 0), Vector3(0.72, 0.09, 0), Vector3(0.86, 0.07, 0), Vector3(1, 0, 0)]
const WALL_TURN_KEYS := [Vector3(0, 0, 0), Vector3(0.22, 0, 0), Vector3(0.55, 0.25, 0), Vector3(0.82, 0.75, 0), Vector3(1, 1, 0)]

static func hip_at(p: float) -> Vector2:
	return _sample(CLIMB_KEYS, p)
static func pitch_at(p: float) -> float:
	return deg_to_rad(-_sample(PITCH_KEYS, p).x)
static func yaw_at(p: float) -> float:
	return deg_to_rad(-_sample(YAW_KEYS, p).x)
static func roll_at(p: float) -> float:
	return deg_to_rad(-_sample(ROLL_KEYS, p).x)
static func left_bias_at(p: float) -> float:
	return _sample(BIAS_KEYS, p).x
static func wall_turn(p: float) -> float:
	return _sample(WALL_TURN_KEYS, p).x

static func _sample(keys: Array, p: float) -> Vector2:
	for index in range(1, keys.size()):
		var a: Vector3 = keys[index - 1]
		var b: Vector3 = keys[index]
		if p <= b.x:
			var h := b.x - a.x
			var t := clampf((p - a.x) / h, 0.0, 1.0)
			var before := Vector2(a.y, a.z)
			var after := Vector2(b.y, b.z)
			var value := (2*t*t*t - 3*t*t + 1)*before + (t*t*t - 2*t*t + t)*h*_tangent(keys, index - 1) + (-2*t*t*t + 3*t*t)*after + (t*t*t - t*t)*h*_tangent(keys, index)
			return Vector2(clampf(value.x, minf(before.x, after.x), maxf(before.x, after.x)), clampf(value.y, minf(before.y, after.y), maxf(before.y, after.y)))
	return Vector2(keys[-1].y, keys[-1].z)

static func _tangent(keys: Array, i: int) -> Vector2:
	if i == 0 or i == keys.size() - 1:
		return Vector2.ZERO
	var a: Vector3 = keys[i - 1]
	var b: Vector3 = keys[i]
	var c: Vector3 = keys[i + 1]
	var h0 := b.x - a.x
	var h1 := c.x - b.x
	var left := Vector2(b.y - a.y, b.z - a.z) / h0
	var right := Vector2(c.y - b.y, c.z - b.z) / h1
	var w0 := 2*h1 + h0
	var w1 := h1 + 2*h0
	return Vector2(0.0 if left.x*right.x <= 0 else (w0+w1)/(w0/left.x+w1/right.x), 0.0 if left.y*right.y <= 0 else (w0+w1)/(w0/left.y+w1/right.y))

static func palm_weight(p: float) -> float:
	return smoothstep(0.32, 0.48, p)
static func hand_weight(p: float, side: int) -> float:
	return 1.0 - smoothstep(0.718 if side == 0 else 0.72, 0.748 if side == 0 else 0.75, p)
static func foot_release(p: float, side: int) -> float:
	return smoothstep(0.25 if side == 0 else 0.15, 0.36 if side == 0 else 0.25, p)
static func foot_lift(p: float, side: int) -> float:
	return smoothstep(0.29 if side == 0 else 0.86, 0.48 if side == 0 else 0.99, p)
static func foot_advance(p: float, side: int) -> float:
	return smoothstep(0.56 if side == 0 else 0.86, 0.72 if side == 0 else 0.99, p)
