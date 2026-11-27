extends Node3D
## Stationary OpenXR smoke lab; no artificial locomotion.
var xr: XRInterface
var origin: XROrigin3D
var camera: XRCamera3D
var controllers: Array[XRController3D] = []
var markers: Array[MeshInstance3D] = []
var status: Label3D
var counter: Label3D
var hits := 0
var active := false
var smoke := false
var runtime_ready := false

func _ready() -> void:
	smoke = "--smoke" in OS.get_cmdline_user_args()
	xr = XRServer.find_interface("OpenXR")
	if not smoke and xr != null and not xr.is_initialized():
		xr.initialize()
	if not smoke and xr != null and xr.is_initialized():
		runtime_ready = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_lab()
	if smoke:
		_run_smoke()

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material
	parent.add_child(instance)
	instance.position = pos
	return instance

func _label(value: String, pos: Vector3, height: float, tint: Color) -> Label3D:
	var node := Label3D.new()
	node.text = value
	node.font_size = 64
	node.pixel_size = height / 64.0
	node.modulate = tint
	add_child(node)
	node.position = pos
	return node

func _build_lab() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10192c")
	environment.environment = env
	add_child(environment)
	_box(self, Vector3(7, 0.1, 7), Vector3(0, -0.08, -1), Color("263953"))
	for i in range(-3, 4):
		_box(self, Vector3(0.025, 0.02, 6.0), Vector3(i, -0.015, -1), Color("46607c"))
	for i in range(-4, 3):
		_box(self, Vector3(6.0, 0.02, 0.025), Vector3(0, -0.015, i), Color("46607c"))
	_box(self, Vector3(3.3, 1.55, 0.08), Vector3(0, 1.65, -2.8), Color("192b43"))
	_label("BAT RUNNING XR", Vector3(0, 2.15, -2.74), 0.22, Color("a78bfa"))
	_label("XR-000  /  CONTROLLER LAB", Vector3(0, 1.88, -2.74), 0.09, Color("6ee7b7"))
	status = _label("Checking XR...", Vector3(0, 1.55, -2.74), 0.10, Color.WHITE)
	counter = _label("INPUT TEST: 0", Vector3(0, 1.28, -2.74), 0.12, Color("6ee7b7"))
	_label("Press trigger to start / count", Vector3(0, 1.06, -2.74), 0.085, Color("cbd5e1"))
	# Original primitive bat emblem, not a migrated web asset.
	_box(self, Vector3(0.28, 0.38, 0.22), Vector3(0, 0.62, -2.2), Color("a78bfa"))
	for side in [-1, 1]:
		var wing := _box(self, Vector3(0.5, 0.16, 0.15), Vector3(side * 0.34, 0.64, -2.2), Color("8b5cf6"))
		wing.rotation.z = side * -0.27
		_box(self, Vector3(0.07, 0.07, 0.03), Vector3(side * 0.075, 0.69, -2.075), Color("10192c"))
	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	origin.add_child(camera)
	camera.current = true
	if not runtime_ready:
		camera.position = Vector3(0, 1.65, 0)
	for hand in ["left_hand", "right_hand"]:
		var controller := XRController3D.new()
		controller.tracker = hand
		controller.pose = "aim"
		origin.add_child(controller)
		controller.button_pressed.connect(_on_button.bind(hand))
		controllers.append(controller)
		var marker := _box(controller, Vector3(0.055, 0.055, 0.12), Vector3.ZERO, Color("6ee7b7") if hand == "left_hand" else Color("a78bfa"))
		_box(marker, Vector3(0.012, 0.012, 0.7), Vector3(0, 0, -0.4), Color("e2e8f0"))
		markers.append(marker)
		marker.visible = false
	status.text = "OpenXR active — waiting for controllers" if runtime_ready else "NO XR RUNTIME — desktop test only"

func _process(_delta: float) -> void:
	if not runtime_ready:
		return
	var tracked := 0
	for i in range(controllers.size()):
		var tracking := controllers[i].get_is_active() and controllers[i].get_has_tracking_data()
		markers[i].visible = tracking
		if tracking:
			tracked += 1
	status.text = "OPENXR | HANDS: %d / 2" % tracked

func _on_button(button: String, hand: String) -> void:
	if button != "trigger_click" and button != "ax_button" and button != "by_button":
		return
	if not runtime_ready and not smoke:
		return
	_record_input(hand)

func _record_input(hand: String) -> void:
	active = true
	hits += 1
	counter.text = "INPUT TEST: %d | %s" % [hits, hand]

func _unhandled_key_input(event: InputEvent) -> void:
	if not runtime_ready and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_record_input("desktop")

func _run_smoke() -> void:
	if controllers.size() != 2 or camera == null or status == null:
		push_error("XR000 scene construction failed")
		get_tree().quit(1)
		return
	_on_button("trigger_click", "left_hand")
	_on_button("trigger_click", "right_hand")
	if not active or hits != 2 or not counter.text.contains("right_hand"):
		push_error("XR000 input routing failed")
		get_tree().quit(1)
		return
	print("XR000_SMOKE_PASS (synthetic inputs only)")
	get_tree().quit(0)
