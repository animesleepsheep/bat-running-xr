extends "res://scripts/xr003.gd"
const Cloud = preload("res://scripts/xr004_cloud.gd")
const PlayerSpace = preload("res://scripts/xr004_space.gd")
const ROUTES := ["intro","lobby","preview","practice","settings","account","profile","login"]
var cloud: Cloud
var practice_saved := false

func _ready() -> void:
	cloud = Cloud.new()
	add_child(cloud)
	cloud.configure("--smoke" in OS.get_cmdline_user_args())
	cloud.changed.connect(_cloud_changed)
	super._ready()

func _install(id: String) -> void:
	var next := PlayerSpace.new()
	next.route = id
	next.use_lite = lite
	next.account_active = not cloud.records.account.is_empty()
	next.account_note = cloud.note
	next.cloud_available = cloud.available()
	next.summary = cloud.records.summary()
	next.pending_count = cloud.records.queue.size()
	if is_instance_valid(current):
		stage_root.remove_child(current)
		current.queue_free()
	current = next
	stage_root.add_child(current)
	route = id
	desktop_index = 0
	intro_time = 0.0
	hover = ["",""]

func _request(id: String, reload: bool = false) -> bool:
	if phase != 0 or not id in ROUTES or (id == route and not reload):
		return false
	pending = id
	phase = 1
	phase_time = 0.0
	for ray in rays:
		ray.visible = false
	hover = ["",""]
	if route == "login":
		var screen := current as PlayerSpace
		screen.email_text = ""
		screen.password_text = ""
	return true

func _dispatch(id: String) -> bool:
	if phase != 0:
		return false
	var screen := current as PlayerSpace
	if screen.keyboard_action(id):
		return true
	if id == "login" and route == "account":
		if not cloud.available():
			cloud._notify("Cloud not configured. Guest still available.")
			return true
		return _request("login")
	if id == "submit_login" and route == "login":
		if cloud.busy:
			return false
		var email := screen.email_text
		var password := screen.password_text
		screen.password_text = ""
		screen._refresh_keyboard()
		cloud.login(email,password)
		return true
	if id == "practice_save" and route == "practice":
		if current.count <= 0 or not cloud.records.record(current.count):
			current.status_label.text = "Nothing saved / queue full"
			return true
		current.count = 0
		current.status_label.text = "SAVED / " + ("GUEST" if cloud.records.account.is_empty() else "PENDING SYNC")
		return true
	if id == "sync" and route in ["profile","account"]:
		cloud.sync()
		return true
	if id == "clear_guest" and route in ["profile","account"] and cloud.records.account.is_empty():
		cloud.records.clear_guest()
		return _request(route,true)
	if id in ["logout","discard"] and route == "account" and not cloud.records.account.is_empty():
		if cloud.sign_out(id=="discard"):
			return _request("account",true)
		return true
	return super._dispatch(id)

func _cloud_changed() -> void:
	if not is_instance_valid(current):
		return
	if route == "login" and not cloud.records.account.is_empty() and phase == 0:
		_request("account")
		return
	if route in ["account","profile","login"] and is_instance_valid(current.status_label):
		current.status_label.text = cloud.note
	if route == "profile" and not cloud.busy and phase == 0:
		_request("profile",true)

func _unhandled_key_input(event: InputEvent) -> void:
	if route == "login" and not core.runtime_ready and phase == 0 and event is InputEventKey and event.pressed and not event.echo:
		var screen := current as PlayerSpace
		if event.keycode == KEY_TAB:
			screen.keyboard_action("field_email" if screen.editing_password else "field_password")
			return
		if event.keycode == KEY_BACKSPACE:
			screen.keyboard_action("backspace")
			return
		if event.unicode >= 32 and event.unicode <= 126:
			screen.append_character(char(event.unicode))
			screen._refresh_keyboard()
			return
	super._unhandled_key_input(event)

func _smoke() -> void:
	var errors: Array[String] = []
	var rig := core.origin.get_instance_id()
	_tick_intro(INTRO_TIME+0.1)
	_finish_transition()
	_dispatch("practice")
	_finish_transition()
	_dispatch("practice_hit")
	_dispatch("practice_hit")
	_dispatch("practice_save")
	_dispatch("practice_save")
	if cloud.records.guest_sessions != 1 or cloud.records.guest_selections != 2 or not cloud.records.queue.is_empty():
		errors.append("guest record isolation / dedupe")
	_back(0)
	_finish_transition()
	_dispatch("profile")
	_finish_transition()
	if route != "profile" or int((current as PlayerSpace).summary.get("selections",0)) != 2:
		errors.append("guest profile")
	_dispatch("clear_guest")
	_finish_transition()
	if cloud.records.guest_sessions != 0:
		errors.append("guest reset")
	_back(0)
	_finish_transition()
	_dispatch("account")
	_finish_transition()
	_dispatch("login")
	if route != "account" or phase != 0 or cloud.available():
		errors.append("offline config gate")
	# Exercise login keyboard without any network calls.
	_request("login")
	_finish_transition()
	var screen := current as PlayerSpace
	screen.keyboard_action("char_0")
	screen.keyboard_action("field_password")
	screen.keyboard_action("char_1")
	if screen.email_text != "a" or screen.password_text != "b" or not screen.password_label.text.ends_with("*"):
		errors.append("masked keyboard")
	_back(0)
	_finish_transition()
	# Synthetic authenticated context; never calls the network.
	if not cloud._accept_session({"user":{"id":"synthetic-user"},"access_token":"test","refresh_token":"test","expires_in":3600}):
		errors.append("session")
	cloud.records.record(4)
	var id: String = cloud.records.queue[0]["p_event_id"]
	if id.length()!=36 or cloud.records.ack("wrong") or cloud.sign_out(false):
		errors.append("queue safety")
	if not cloud.records.ack(id) or not cloud.sign_out(false) or not cloud.records.account.is_empty():
		errors.append("ack/logout")
	cloud.records.set_account("second")
	if not cloud.records.queue.is_empty() or not cloud.records.profile.is_empty():
		errors.append("account isolation")
	cloud.sign_out(true)
	if core.origin.get_instance_id()!=rig or stage_root.get_child_count()!=1:
		errors.append("rig integrity")
	if not errors.is_empty():
		push_error("XR004_SMOKE_FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("XR004_SMOKE_PASS: guest, saved practice, profile, offline gate, masked keyboard, queue ack, logout, isolation, rig (synthetic)")
	get_tree().quit(0)
