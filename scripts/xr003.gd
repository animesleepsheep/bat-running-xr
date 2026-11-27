extends Node3D
const Runtime = preload("res://scripts/xr_runtime.gd")
const Space = preload("res://scripts/xr003_space.gd")
const SCENES := {
	"intro": preload("res://scenes/spaces/intro.tscn"),
	"lobby": preload("res://scenes/spaces/lobby.tscn"),
	"preview": preload("res://scenes/spaces/preview.tscn"),
	"practice": preload("res://scenes/spaces/practice.tscn"),
	"settings": preload("res://scenes/spaces/settings.tscn")
}
const FADE_TIME := 0.24
const INTRO_TIME := 3.0
const PREF_PATH := "user://xr003_preferences.cfg"
var core: Runtime
var stage_root: Node3D
var current: Space
var route := ""
var pending := ""
var phase := 0 # 0 idle, 1 fade to black, 2 fade in
var phase_time := 0.0
var transition_count := 0
var intro_time := 0.0
var lite := false
var smoke := false
var desktop_index := 0
var rays: Array[MeshInstance3D] = []
var hover: Array[String] = ["", ""]
var fade: MeshInstance3D
var fade_mat: StandardMaterial3D

func _ready() -> void:
	smoke = "--smoke" in OS.get_cmdline_user_args()
	if not smoke:
		_load_preferences()
	core = Runtime.new()
	add_child(core)
	core.start(smoke)
	_world()
	stage_root = Node3D.new()
	stage_root.name = "SpaceRoot"
	add_child(stage_root)
	_build_rays()
	_build_fade()
	core.selected.connect(_select)
	core.secondary.connect(_back)
	_install("intro")
	if smoke:
		_smoke()

func _world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10192c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e6ff")
	env.ambient_light_energy = 0.75
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	add_child(key)
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_energy = 1.25
	var fill := DirectionalLight3D.new()
	add_child(fill)
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.55

func _build_rays() -> void:
	for i in range(2):
		var ray := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.008, 0.008, 1.0)
		ray.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("75eed2") if i == 0 else Color("bca4ff")
		ray.material_override = mat
		core.hands[i].add_child(ray)
		ray.position.z = -0.5
		ray.visible = false
		rays.append(ray)

func _build_fade() -> void:
	fade = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5)
	fade.mesh = quad
	fade_mat = StandardMaterial3D.new()
	fade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade_mat.no_depth_test = true
	fade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fade_mat.render_priority = 127
	fade.material_override = fade_mat
	core.camera.add_child(fade)
	fade.position.z = -0.24
	_alpha(0.0)

func _alpha(value: float) -> void:
	fade_mat.albedo_color = Color(0, 0, 0, clampf(value, 0.0, 1.0))
	fade.visible = value > 0.001

func _load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREF_PATH) == OK:
		lite = bool(cfg.get_value("display", "lite", false))

func _save_preferences() -> void:
	if smoke:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("display", "lite", lite)
	if cfg.save(PREF_PATH) != OK:
		push_warning("Unable to save display preference")

func _install(id: String) -> void:
	var packed: PackedScene = SCENES[id]
	var next := packed.instantiate() as Space
	next.use_lite = lite
	if is_instance_valid(current):
		stage_root.remove_child(current)
		current.queue_free()
	current = next
	stage_root.add_child(current)
	route = id
	desktop_index = 0
	intro_time = 0.0
	hover = ["", ""]

func _request(id: String, reload: bool = false) -> bool:
	if phase != 0 or not SCENES.has(id) or (id == route and not reload):
		return false
	pending = id
	phase = 1
	phase_time = 0.0
	for ray in rays:
		ray.visible = false
	hover = ["", ""]
	return true

func _advance(delta: float) -> void:
	if phase == 0:
		return
	phase_time += delta
	if phase == 1:
		_alpha(phase_time / FADE_TIME)
		if phase_time >= FADE_TIME:
			_install(pending)
			transition_count += 1
			phase = 2
			phase_time = 0.0
			_alpha(1.0)
	elif phase == 2:
		_alpha(1.0 - phase_time / FADE_TIME)
		if phase_time >= FADE_TIME:
			phase = 0
			phase_time = 0.0
			pending = ""
			_alpha(0.0)
			# Prevent a held button from activating the newly mounted scene.
			for i in range(2):
				core.trigger_edges[i].sample(0.0, false)
				core.secondary_edges[i].sample(0.0, false)
				core.grip_edges[i].sample(0.0, false)

func _tick_intro(delta: float) -> void:
	if route == "intro" and phase == 0:
		intro_time += delta
		if intro_time >= INTRO_TIME:
			_request("lobby")

func _process(delta: float) -> void:
	if smoke:
		return
	if core.runtime_ready:
		core.poll()
	var interactive := not core.runtime_ready or core.focused
	# Freeze animations and transition timers while the system menu owns focus.
	if interactive:
		_advance(delta)
		if phase == 0:
			current.animate(delta)
			_tick_intro(delta)
	for i in range(2):
		_update_ray(i)
	current.highlight(hover, desktop_index if not core.runtime_ready and phase == 0 else -1)

func _update_ray(i: int) -> void:
	hover[i] = ""
	var ray := rays[i]
	var valid := phase == 0 and core.runtime_ready and core.tracked[i] and core.focused
	ray.visible = valid
	if not valid:
		return
	var hand := core.hands[i]
	var hit: Dictionary = current.panel.hit(hand.global_position, -hand.global_basis.z)
	var length := 2.4
	if not hit.is_empty():
		hover[i] = hit["id"]
		var point: Vector3 = hit["point"]
		length = hand.global_position.distance_to(point)
	ray.scale.z = length
	ray.position.z = -length * 0.5

func _select(i: int) -> void:
	if phase != 0 or not core.tracked[i] or not core.focused:
		return
	if route == "intro":
		_dispatch("lobby")
		core.pulse(i)
		return
	var hand := core.hands[i]
	var hit: Dictionary = current.panel.hit(hand.global_position, -hand.global_basis.z)
	if not hit.is_empty() and _dispatch(hit["id"]):
		core.pulse(i)

func _dispatch(id: String) -> bool:
	if phase != 0:
		return false
	if id == "toggle_lod" and route == "settings":
		lite = not lite
		_save_preferences()
		return _request("settings", true)
	if current.practice_action(id):
		return true
	if not id in current.choices and not (route == "intro" and id == "lobby"):
		return false
	return _request(id)

func _back(_i: int) -> void:
	if phase == 0 and route != "lobby":
		_request("lobby")

func _unhandled_key_input(event: InputEvent) -> void:
	if core.runtime_ready or phase != 0 or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP: desktop_index = posmod(desktop_index - 1, current.choices.size())
		KEY_DOWN: desktop_index = posmod(desktop_index + 1, current.choices.size())
		KEY_ENTER: _dispatch(current.choices[desktop_index])
		KEY_ESCAPE: _back(0)

func _finish_transition() -> void:
	_advance(FADE_TIME + 0.01)
	_advance(FADE_TIME + 0.01)

func _smoke() -> void:
	var errors: Array[String] = []
	var origin_id := core.origin.get_instance_id()
	var camera_id := core.camera.get_instance_id()
	if route != "intro" or current.mascot == null or current.wing_l == null:
		errors.append("intro mascot")
	current.animate(0.7)
	if current.title_label.modulate.a < 0.99:
		errors.append("brand reveal")
	_tick_intro(INTRO_TIME + 0.01)
	if phase != 1 or _request("preview"):
		errors.append("auto intro/transition lock")
	_finish_transition()
	if route != "lobby" or current.choices.size() != 4 or current.mascot == null:
		errors.append("lobby")
	if stage_root.get_child_count() != 1 or core.origin.get_instance_id() != origin_id or core.camera.get_instance_id() != camera_id:
		errors.append("single persistent rig")
	if _dispatch("unknown") or _request("bad_route"):
		errors.append("invalid route")
	var point := current.panel.to_global(Vector3(0, 0.29, 2))
	var hit: Dictionary = current.panel.hit(point, -current.panel.global_basis.z)
	if hit.get("id", "") != "preview" or not _dispatch(hit.get("id", "")):
		errors.append("spatial lobby selection")
	_finish_transition()
	if route != "preview":
		errors.append("preview")
	_dispatch("practice")
	_finish_transition()
	_dispatch("practice_hit")
	_dispatch("practice_hit")
	if route != "practice" or current.count != 2:
		errors.append("practice score")
	_dispatch("practice_reset")
	if current.count != 0:
		errors.append("practice reset")
	_back(0)
	_finish_transition()
	_dispatch("settings")
	_finish_transition()
	_dispatch("toggle_lod")
	_finish_transition()
	if route != "settings" or not lite or not current.use_lite:
		errors.append("quality preference")
	_dispatch("lobby")
	_finish_transition()
	if current.mascot == null or not current.use_lite:
		errors.append("lite mascot retained")
	_dispatch("intro")
	_finish_transition()
	_dispatch("lobby")
	_finish_transition()
	if route != "lobby" or fade.visible or phase != 0 or stage_root.get_child_count() != 1:
		errors.append("skip intro/cleanup")
	if core.camera.get_instance_id() != camera_id or core.origin.get_instance_id() != origin_id:
		errors.append("rig replaced")
	if not errors.is_empty():
		push_error("XR003_SMOKE_FAIL " + str(errors))
		get_tree().quit(1)
		return
	print("XR003_SMOKE_PASS: animated intro, five native spaces, ray selection, route lock, practice, LOD, back, skip, one rig; transitions=", transition_count)
	get_tree().quit(0)
