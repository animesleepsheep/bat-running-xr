extends Node3D
## Reusable stationary XR origin, focus gate, tracked poses and normalized inputs.
const Edge = preload("res://scripts/xr_input.gd")
signal selected(hand: int)
signal grip_changed(hand: int, held: bool)
signal secondary(hand: int)
var xr: OpenXRInterface
var origin: XROrigin3D
var camera: XRCamera3D
var hands: Array[XRController3D] = []
var grips: Array[XRController3D] = []
var tracked: Array[bool] = [false, false]
var trigger_edges: Array = [Edge.new(), Edge.new()]
var grip_edges: Array = [Edge.new(), Edge.new()]
var secondary_edges: Array = [Edge.new(), Edge.new()]
var axes: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var runtime_ready := false
var focused := false
var smoke := false

func start(test_mode: bool) -> void:
	smoke = test_mode
	xr = XRServer.find_interface("OpenXR") as OpenXRInterface
	if not smoke and xr != null:
		if not xr.is_initialized():
			xr.initialize()
		runtime_ready = xr.is_initialized()
	if runtime_ready:
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	origin.add_child(camera)
	camera.current = true
	if not runtime_ready:
		camera.position = Vector3(0, 1.65, 0)
	for hand in ["left_hand", "right_hand"]:
		var aim := XRController3D.new()
		aim.tracker = hand
		aim.pose = "aim"
		origin.add_child(aim)
		hands.append(aim)
		var grip := XRController3D.new()
		grip.tracker = hand
		grip.pose = "grip_pose"
		origin.add_child(grip)
		grips.append(grip)

func poll() -> void:
	focused = runtime_ready and xr.is_initialized() and xr.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED
	for i in range(2):
		var hand := hands[i]
		tracked[i] = focused and hand.get_is_active() and hand.get_has_tracking_data()
		var available := tracked[i]
		var squeeze := available and grips[i].get_is_active() and grips[i].get_has_tracking_data()
		var trigger := hand.get_float("trigger") if available else 0.0
		var grip := hand.get_float("grip") if squeeze else 0.0
		var confirm := 1.0 if available and hand.is_button_pressed("ax_button") else 0.0
		var back := 1.0 if available and hand.is_button_pressed("by_button") else 0.0
		# Merge analog trigger and A/X, preventing duplicate activations.
		trigger_edges[i].sample(maxf(trigger, confirm), available)
		grip_edges[i].sample(grip, squeeze)
		secondary_edges[i].sample(back, available)
		axes[i] = Edge.stick(hand.get_vector2("primary")) if available else Vector2.ZERO
		if trigger_edges[i].pressed:
			selected.emit(i)
		if grip_edges[i].pressed:
			grip_changed.emit(i, true)
		if grip_edges[i].released:
			grip_changed.emit(i, false)
		if secondary_edges[i].pressed:
			secondary.emit(i)

func pulse(i: int) -> void:
	if tracked[i]:
		hands[i].trigger_haptic_pulse("haptic", 0.0, 0.25, 0.055, 0.0)
