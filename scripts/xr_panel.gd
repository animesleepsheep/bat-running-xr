extends Node3D
## Reusable flat panel ray hit test, entirely world-space (no HTML or screen overlay).
var buttons: Array[Dictionary] = []
const MAX_DISTANCE := 5.0

func add_button(id: String, center: Vector2, size: Vector2) -> void:
	buttons.append({"id": id, "rect": Rect2(center - size * 0.5, size)})

func hit(from: Vector3, direction: Vector3) -> Dictionary:
	var local_from := to_local(from)
	var local_end := to_local(from + direction.normalized() * MAX_DISTANCE)
	var delta := local_end - local_from
	if delta.z >= -0.0001:
		return {}
	var t := -local_from.z / delta.z
	if t < 0.0 or t > 1.0:
		return {}
	var point := local_from + delta * t
	for button in buttons:
		var bounds: Rect2 = button["rect"]
		if bounds.has_point(Vector2(point.x, point.y)):
			return {"id": button["id"], "point": to_global(point)}
	return {}
