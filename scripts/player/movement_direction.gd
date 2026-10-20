extends RefCounted
## Shared sector thresholds for movement targets and presentation.
const CENTERS := [0.0, PI / 2.0, PI, -PI / 2.0]
static func select(local: Vector3, previous: int, margin_degrees: float, fresh: bool = false) -> int:
	var angle := atan2(local.x, local.z)
	var distance := absf(wrapf(angle - float(CENTERS[previous]), -PI, PI))
	if fresh or distance > PI / 4.0 + deg_to_rad(margin_degrees):
		# Resolve exact diagonals consistently despite inverse-rotation roundoff.
		return posmod(roundi((angle + signf(angle) * 0.00001) / (PI / 2.0)), 4)
	return previous
