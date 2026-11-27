extends Node3D
## One native world-space screen. The persistent XR rig belongs to the router.
const SpatialPanel = preload("res://scripts/xr_panel.gd")
const Assets = preload("res://scripts/xr_assets.gd")
const INK := Color("101d32")
const NAVY := Color("20344e")
const MINT := Color("75eed2")
const LILAC := Color("bca4ff")
@export var route: String = "lobby"
var use_lite := false
var panel: SpatialPanel
var button_meshes: Dictionary = {}
var choices: Array[String] = []
var mascot: Node3D
var mascot_mount: Node3D
var wing_l: Node3D
var wing_r: Node3D
var title_label: Label3D
var status_label: Label3D
var accent: MeshInstance3D
var seconds := 0.0
var count := 0
var bars: Array[MeshInstance3D] = []

func _ready() -> void:
	_architecture()
	match route:
		"intro": _intro()
		"lobby": _lobby()
		"preview": _preview()
		"practice": _practice()
		"settings": _settings()

func box(parent: Node3D, size: Vector3, pos: Vector3, tint: Color, lit: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	if not lit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func label3(parent: Node3D, value: String, pos: Vector3, height: float, tint: Color = Color.WHITE) -> Label3D:
	var node := Label3D.new()
	node.text = value
	node.font_size = 64
	node.pixel_size = height / 64.0
	node.modulate = tint
	parent.add_child(node)
	node.position = pos
	return node

func _architecture() -> void:
	box(self, Vector3(9, 0.12, 9), Vector3(0, -0.06, -2), INK, true)
	for i in range(-4, 5):
		box(self, Vector3(0.018, 0.015, 8), Vector3(i, 0.005, -2), Color("28425b"))
	for i in range(-6, 3):
		box(self, Vector3(8, 0.015, 0.018), Vector3(0, 0.005, i), Color("28425b"))
	box(self, Vector3(8.5, 3.3, 0.12), Vector3(0, 1.65, -4.6), NAVY, true)
	for side in [-1, 1]:
		box(self, Vector3(0.18, 3.2, 3.3), Vector3(side * 4.0, 1.6, -3.0), INK, true)
		box(self, Vector3(0.12, 3.0, 0.10), Vector3(side * 3.3, 1.5, -4.45), LILAC)
		box(self, Vector3(0.16, 0.025, 5), Vector3(side * 1.9, 0.02, -2.0), MINT)
	for i in range(5):
		var bar := box(self, Vector3(0.34, 0.055, 0.055), Vector3(-0.80 + i * 0.40, 3.0, -4.44), MINT)
		bars.append(bar)

func _make_panel(x: float, width: float, height: float, title: String, subtitle: String) -> void:
	panel = SpatialPanel.new()
	add_child(panel)
	panel.position = Vector3(x, 1.62, -2.65)
	box(panel, Vector3(width, height, 0.10), Vector3(0, 0, -0.07), INK)
	box(panel, Vector3(width - 0.10, 0.025, 0.045), Vector3(0, height / 2.0 - 0.07, 0.01), LILAC)
	title_label = label3(panel, title, Vector3(0, height / 2.0 - 0.22, 0.025), 0.20, LILAC)
	label3(panel, subtitle, Vector3(0, height / 2.0 - 0.43, 0.025), 0.083, MINT)

func _button(id: String, title: String, hint: String, y: float, width: float = 2.05) -> void:
	var center := Vector2(0, y)
	panel.add_button(id, center, Vector2(width, 0.29))
	choices.append(id)
	button_meshes[id] = box(panel, Vector3(width, 0.29, 0.05), Vector3(0, y, 0.0), Color("34516f"))
	label3(panel, title, Vector3(0, y + 0.046, 0.035), 0.11, Color.WHITE)
	label3(panel, hint, Vector3(0, y - 0.071, 0.035), 0.057, Color("c4d7e9"))

func _stage(x: float, z: float, scale_factor: float) -> void:
	box(self, Vector3(1.6, 0.14, 0.90), Vector3(x, 0.81, z), NAVY, true)
	box(self, Vector3(1.48, 0.025, 0.80), Vector3(x, 0.89, z), MINT)
	box(self, Vector3(0.40, 0.79, 0.40), Vector3(x, 0.39, z), NAVY, true)
	mascot_mount = Node3D.new()
	add_child(mascot_mount)
	mascot_mount.position = Vector3(x, 0.91, z)
	mascot_mount.rotation.y = PI
	mascot_mount.scale = Vector3.ONE * scale_factor
	mascot = Assets.instantiate("bat_lite" if use_lite else "bat_standard")
	if mascot == null:
		push_error("XR003 mascot asset missing")
		return
	mascot_mount.add_child(mascot)
	wing_l = mascot.find_child("BatWingL", true, false) as Node3D
	wing_r = mascot.find_child("BatWingR", true, false) as Node3D

func _intro() -> void:
	_make_panel(0, 3.7, 1.42, "BAT RUNNING XR", "POTTER SHEEP  /  ECO ADVENTURE")
	panel.position.y = 2.05
	_stage(0, -2.0, 0.31)
	_button("lobby", "ENTER", "Trigger / A-X to skip intro", -0.43, 1.85)
	accent = box(self, Vector3(2.4, 0.025, 0.04), Vector3(0, 2.77, -2.56), MINT)

func _lobby() -> void:
	_make_panel(0.74, 2.5, 2.05, "BAT RUNNING", "XR  /  ADVENTURE HUB")
	_button("preview", "START ADVENTURE", "Course preview", 0.29)
	_button("practice", "CONTROL PRACTICE", "Aim, select and reset", -0.07)
	_button("settings", "SETTINGS", "Model quality and controls", -0.43)
	_button("intro", "REPLAY INTRO", "Return to brand opening", -0.79)
	_stage(-1.18, -2.2, 0.30)
	label3(self, "WELCOME, RUNNER!", Vector3(-1.18, 1.65, -2.2), 0.095, MINT)
	label3(self, "Your adventure begins here.", Vector3(-1.18, 1.51, -2.2), 0.068, Color.WHITE)
	status_label = label3(self, "GUEST  /  OFFLINE", Vector3(0, 0.36, -2.6), 0.073, Color("c4d7e9"))

func _preview() -> void:
	_make_panel(0, 3.0, 1.88, "COURSE PREVIEW", "Stationary preview  /  race not unlocked")
	# A tiny stylized course diorama, not the original six tracks.
	for i in range(3):
		box(self, Vector3(0.19, 0.025, 1.35), Vector3(-1.3 + i * 0.23, 0.77, -1.35), Color("426983"), true)
	box(self, Vector3(0.84, 0.10, 1.55), Vector3(-1.07, 0.70, -1.35), INK, true)
	for i in range(4):
		box(self, Vector3(0.04, 0.04, 0.12), Vector3(-1.3, 0.8, -0.85 - i * 0.27), MINT)
		box(self, Vector3(0.10, 0.21 + i * 0.04, 0.15), Vector3(-1.55, 0.89, -0.85 - i * 0.27), LILAC, true)
	_button("practice", "TRY CONTROLS", "Open stationary practice", -0.17)
	_button("lobby", "BACK TO HUB", "Return to lobby", -0.56)
	label3(panel, "Full tracks and running unlock in later versions.", Vector3(0, 0.23, 0.025), 0.075, Color("c4d7e9"))

func _practice() -> void:
	_make_panel(0, 2.85, 1.98, "CONTROL PRACTICE", "Point at a tile and press trigger or A-X")
	_button("practice_hit", "SELECT TARGET", "Haptic feedback on selection", 0.20)
	_button("practice_reset", "RESET SCORE", "Clear your practice count", -0.16)
	_button("lobby", "BACK TO HUB", "B-Y also returns", -0.52)
	status_label = label3(panel, "SCORE  0", Vector3(0, -0.81, 0.025), 0.10, MINT)

func _settings() -> void:
	_make_panel(0, 2.85, 1.98, "SETTINGS", "Offline display preferences")
	_button("toggle_lod", "MODEL: " + ("LITE" if use_lite else "STANDARD"), "Switch mascot detail", 0.20)
	_button("practice", "CONTROL PRACTICE", "Learn the input controls", -0.16)
	_button("lobby", "BACK TO HUB", "Return to lobby", -0.52)
	label3(panel, "No forced movement  /  stand or sit safely", Vector3(0, -0.81, 0.025), 0.067, MINT)

func practice_action(id: String) -> bool:
	if route != "practice":
		return false
	if id == "practice_hit":
		count += 1
	elif id == "practice_reset":
		count = 0
	else:
		return false
	status_label.text = "SCORE  %d" % count
	return true

func highlight(ids: Array[String], desktop_index: int = -1) -> void:
	for i in range(choices.size()):
		var id := choices[i]
		var node: MeshInstance3D = button_meshes[id]
		var mat: StandardMaterial3D = node.material_override
		mat.albedo_color = Color("387f73") if id in ids or i == desktop_index else Color("34516f")

func animate(delta: float) -> void:
	seconds += delta
	if is_instance_valid(wing_l):
		wing_l.rotation.y = sin(seconds * 2.2) * (0.22 if route == "intro" else 0.12)
	if is_instance_valid(wing_r):
		wing_r.rotation.y = -sin(seconds * 2.2) * (0.22 if route == "intro" else 0.12)
	if is_instance_valid(mascot_mount):
		mascot_mount.position.y = 0.91 + sin(seconds * 1.9) * 0.018
	if route == "intro":
		title_label.modulate.a = clampf(seconds / 0.65, 0.0, 1.0)
		accent.scale.x = maxf(0.02, clampf(seconds / 1.4, 0.0, 1.0))
	for i in range(bars.size()):
		var mat: StandardMaterial3D = bars[i].material_override
		mat.albedo_color = MINT.lerp(LILAC, (sin(seconds * 1.2 + i * 0.65) + 1.0) * 0.5)
