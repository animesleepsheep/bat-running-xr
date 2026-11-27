extends RefCounted
## Stable asset IDs; Godot imports GLB as PackedScene. No runtime web/CDN dependency.
const CATALOG := "res://assets/generated/catalog.json"
const PATHS := {"bat_standard": "res://assets/generated/bat_standard.glb", "bat_lite": "res://assets/generated/bat_lite.glb"}
static func catalog() -> Dictionary:
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}
static func instantiate(id: String) -> Node3D:
	if not PATHS.has(id):
		return null
	var scene := load(PATHS[id]) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D
static func mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += mesh_count(child)
	return count
