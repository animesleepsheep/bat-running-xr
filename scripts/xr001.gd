extends Node3D
const Runtime = preload("res://scripts/xr_runtime.gd")
const Panel = preload("res://scripts/xr_panel.gd")
const Edge = preload("res://scripts/xr_input.gd")
var core: Node3D
var panel: Node3D
var status: Label3D
var details: Label3D
var count_label: Label3D
var buttons := {}
var rays: Array[MeshInstance3D] = []
var tips: Array[MeshInstance3D] = []
var hovered: Array[String] = ["", ""]
var token: MeshInstance3D
var token_home := Vector3(0.0, 1.18, -0.82)
var owner := -1
var clicks := 0
var grabs := 0
var last_action := "READY"
var smoke := false

func _ready() -> void:
	smoke = "--smoke" in OS.get_cmdline_user_args()
	core = Runtime.new()
	add_child(core)
	core.start(smoke)
	_build()
	core.selected.connect(_select)
	core.grip_changed.connect(_grip)
	core.secondary.connect(_back)
	if smoke:
		_smoke()

func _mesh(parent: Node3D, size: Vector3, pos: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func _text(parent: Node3D, value: String, pos: Vector3, height: float, tint: Color) -> Label3D:
	var node := Label3D.new()
	node.text = value
	node.font_size = 64
	node.pixel_size = height / 64.0
	node.modulate = tint
	parent.add_child(node)
	node.position = pos
	return node

func _build() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10192c")
	world.environment = env
	add_child(world)
	_mesh(self, Vector3(7, 0.1, 7), Vector3(0, -0.08, -1), Color("20344b"))
	for i in range(-3, 4):
		_mesh(self, Vector3(0.018, 0.02, 6.0), Vector3(i, -0.014, -1), Color("37566b"))
	for i in range(-4, 3):
		_mesh(self, Vector3(6.0, 0.02, 0.018), Vector3(0, -0.014, i), Color("37566b"))
	panel = Panel.new()
	add_child(panel)
	panel.position = Vector3(0, 1.65, -2.4)
	_mesh(panel, Vector3(3.15, 1.85, 0.08), Vector3(0, 0, -0.05), Color("192b43"))
	_text(panel, "BAT RUNNING XR", Vector3(0, 0.73, 0.01), 0.22, Color("b8a4ff"))
	_text(panel, "XR-001  /  INTERACTION LAB", Vector3(0, 0.49, 0.01), 0.09, Color("6ee7b7"))
	status = _text(panel, "Waiting for OpenXR", Vector3(0, 0.26, 0.01), 0.09, Color.WHITE)
	details = _text(panel, "L  --      R  --", Vector3(0, 0.08, 0.01), 0.075, Color("cbd5e1"))
	_button("test", "TEST SELECT", Vector2(-0.67, -0.19))
	_button("reset", "RESET", Vector2(0.67, -0.19))
	count_label = _text(panel, "", Vector3(0, -0.46, 0.01), 0.09, Color("6ee7b7"))
	_text(panel, "Aim + trigger / A-X  |  Hold grip near cube", Vector3(0, -0.68, 0.01), 0.075, Color("cbd5e1"))
	_text(panel, "B-Y: reset   |   Stay seated or stationary", Vector3(0, -0.82, 0.01), 0.07, Color("cbd5e1"))
	_mesh(self, Vector3(0.6, 0.08, 0.55), Vector3(0, 1.00, -0.82), Color("37566b"))
	_mesh(self, Vector3(0.16, 1.0, 0.16), Vector3(0, 0.47, -0.82), Color("37566b"))
	token = _mesh(self, Vector3(0.22, 0.22, 0.22), token_home, Color("6ee7b7"))
	for i in range(2):
		var hand: XRController3D = core.hands[i]
		var tint := Color("6ee7b7") if i == 0 else Color("a78bfa")
		var ray := _mesh(hand, Vector3(0.009, 0.009, 1.0), Vector3(0, 0, -0.5), tint)
		var tip := _mesh(hand, Vector3(0.055, 0.055, 0.10), Vector3.ZERO, tint)
		rays.append(ray)
		tips.append(tip)
		ray.visible = false
		tip.visible = false
	_refresh()

func _button(id: String, title: String, center: Vector2) -> void:
	panel.add_button(id, center, Vector2(1.20, 0.28))
	buttons[id] = _mesh(panel, Vector3(1.20, 0.28, 0.04), Vector3(center.x, center.y, -0.01), Color("365778"))
	_text(panel, title, Vector3(center.x, center.y, 0.025), 0.10, Color.WHITE)

func _process(_delta: float) -> void:
	if smoke or not core.runtime_ready:
		return
	# Aiming is evaluated before dispatching the current input edge.
	for i in range(2):
		_update_ray(i)
	core.poll()
	for i in range(2):
		_update_ray(i)
	if owner >= 0:
		if not core.tracked[owner] or not core.focused or not core.grips[owner].get_has_tracking_data():
			_drop()
		else:
			token.global_transform = core.grips[owner].global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.10))
	for id in buttons:
		var material: StandardMaterial3D = buttons[id].material_override
		material.albedo_color = Color("427d71") if id in hovered else Color("365778")
	status.text = ("OPENXR FOCUSED" if core.focused else "XR PAUSED / NO FOCUS")
	var l: Vector2 = core.axes[0]
	var r: Vector2 = core.axes[1]
	details.text = "L %s %.1f %.1f   |   R %s %.1f %.1f" % ["OK" if core.tracked[0] else "--", l.x, l.y, "OK" if core.tracked[1] else "--", r.x, r.y]

func _update_ray(i: int) -> void:
	var hand: XRController3D = core.hands[i]
	var valid: bool = core.runtime_ready and core.xr.is_initialized() and core.xr.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED and hand.get_is_active() and hand.get_has_tracking_data()
	rays[i].visible = valid
	tips[i].visible = valid
	hovered[i] = ""
	if not valid:
		return
	var result: Dictionary = panel.hit(hand.global_position, -hand.global_basis.z)
	var length := 2.5
	if not result.is_empty():
		hovered[i] = result["id"]
		var point: Vector3 = result["point"]
		length = hand.global_position.distance_to(point)
	rays[i].scale.z = length
	rays[i].position.z = -length * 0.5

func _select(i: int) -> void:
	if not core.tracked[i]:
		return
	var hand: XRController3D = core.hands[i]
	var hit: Dictionary = panel.hit(hand.global_position, -hand.global_basis.z)
	if not hit.is_empty():
		_activate(hit["id"], i)
		core.pulse(i)

func _activate(id: String, hand: int) -> void:
	if id == "test":
		clicks += 1
		last_action = "SELECT " + ("L" if hand == 0 else "R")
	elif id == "reset":
		_reset()
	_refresh()

func _grip(i: int, held: bool) -> void:
	if not held:
		if owner == i:
			_drop()
		return
	if owner != -1 or not core.tracked[i] or not core.focused:
		return
	var hand: XRController3D = core.grips[i]
	if hand.global_position.distance_to(token.global_position) <= 0.28:
		owner = i
		grabs += 1
		last_action = "GRAB " + ("L" if i == 0 else "R")
		core.pulse(i)
		_refresh()

func _drop() -> void:
	owner = -1
	token.position = token_home
	token.rotation = Vector3.ZERO
	last_action = "RELEASE"
	_refresh()

func _reset() -> void:
	_drop()
	clicks = 0
	grabs = 0
	last_action = "RESET"
	_refresh()

func _back(_i: int) -> void:
	_reset()

func _refresh() -> void:
	count_label.text = "%s   |   SELECT %d   GRAB %d" % [last_action, clicks, grabs]

func _unhandled_key_input(event: InputEvent) -> void:
	if core.runtime_ready or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER:
		_activate("test", 0)
	elif event.keycode == KEY_R:
		_reset()

func _smoke() -> void:
	var errors: Array[String] = []
	if core.hands.size() != 2 or core.grips.size() != 2:
		errors.append("origin/controllers")
	var map: OpenXRActionMap = load("res://openxr_action_map.tres")
	if map == null or map.interaction_profiles.size() != 2:
		errors.append("action map")
	var edge := Edge.new()
	edge.sample(1.0, true)
	if edge.pressed:
		errors.append("held at startup")
	edge.sample(0.0, true)
	edge.sample(0.8, true)
	if not edge.pressed:
		errors.append("press edge")
	edge.sample(0.55, true)
	if edge.pressed or not edge.held:
		errors.append("hysteresis")
	edge.sample(0.9, false)
	if not edge.released or edge.held:
		errors.append("tracking loss")
	edge.sample(0.9, true)
	if edge.pressed:
		errors.append("reacquire while held")
	edge.sample(0.0, true)
	edge.sample(0.9, true)
	if not edge.pressed:
		errors.append("rearm")
	if Edge.stick(Vector2(0.1, 0)) != Vector2.ZERO or not is_equal_approx(Edge.stick(Vector2(1, 0)).length(), 1.0):
		errors.append("dead zone")
	var hit: Dictionary = panel.hit(panel.to_global(Vector3(-0.67, -0.19, 2)), Vector3(0, 0, -1))
	if hit.get("id", "") != "test" or not panel.hit(Vector3(0, 5, 0), Vector3(0, 0, -1)).is_empty():
		errors.append("ray hit/miss")
	if not panel.hit(panel.to_global(Vector3(-0.67, -0.19, -2)), Vector3(0, 0, 1)).is_empty():
		errors.append("backface")
	_activate("test", 0)
	_activate("test", 1)
	if clicks != 2:
		errors.append("dual select")
	owner = 0
	token.position = Vector3(1, 2, 3)
	_grip(0, false)
	if owner != -1 or token.position != token_home:
		errors.append("release cleanup")
	_activate("reset", 0)
	if clicks != 0 or grabs != 0:
		errors.append("reset")
	if not errors.is_empty():
		push_error("XR001_SMOKE_FAIL " + str(errors))
		get_tree().quit(1)
		return
	print("XR001_SMOKE_PASS: map, focus gate, hysteresis, deadzone, ray, dual select, release, reset (synthetic)")
	get_tree().quit(0)
