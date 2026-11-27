extends RefCounted
## Edge detector: after loss or focus change require release before accepting input.
const DOWN := 0.70
const UP := 0.30
var armed := false
var pressed := false
var released := false
var held := false

func sample(value: float, enabled: bool) -> void:
	pressed = false
	released = false
	if not enabled:
		released = held
		held = false
		armed = false
		return
	if not armed:
		if value <= UP:
			armed = true
		return
	if not held and value >= DOWN:
		held = true
		pressed = true
	elif held and value <= UP:
		held = false
		released = true

static func stick(value: Vector2) -> Vector2:
	var length := value.length()
	if length <= 0.20:
		return Vector2.ZERO
	return value.normalized() * clampf((length - 0.20) / 0.80, 0.0, 1.0)
