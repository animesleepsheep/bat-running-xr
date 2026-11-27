extends "res://scripts/xr001.gd"
const Assets = preload("res://scripts/xr_assets.gd")
var display_bat: Node3D
var preview_mount: Node3D
var wing_left: Node3D
var wing_right: Node3D
var elapsed := 0.0
var lite := false
var asset_label: Label3D

func _build() -> void:
	super._build()
	# A dedicated display plinth outside the XR001 panel and grab zone.
	var world := get_world_3d()
	if world.environment != null:
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color("d7e6ff")
		world.environment.ambient_light_energy = 0.8
	var key := DirectionalLight3D.new()
	add_child(key)
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_energy = 1.3
	var fill := DirectionalLight3D.new()
	add_child(fill)
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.5
	_mesh(self, Vector3(1.35, 0.09, 0.68), Vector3(1.75, 0.94, -1.35), Color("37566b"))
	_mesh(self, Vector3(0.25, 0.9, 0.25), Vector3(1.75, 0.45, -1.35), Color("20344b"))
	preview_mount = Node3D.new()
	add_child(preview_mount)
	preview_mount.position = Vector3(1.75, 0.99, -1.35)
	preview_mount.rotation.y = PI
	preview_mount.scale = Vector3.ONE * 0.27
	asset_label = _text(self, "BAT / STANDARD", Vector3(1.75, 1.60, -1.35), 0.08, Color("b8a4ff"))
	_text(self, "Aim at TEST SELECT to switch LOD", Vector3(1.75, 1.73, -1.35), 0.06, Color("cbd5e1"))
	_load_bat(false)

func _load_bat(use_lite: bool) -> void:
	var next := Assets.instantiate("bat_lite" if use_lite else "bat_standard")
	if next == null:
		push_error("XR002 missing imported mascot")
		return
	if is_instance_valid(display_bat):
		preview_mount.remove_child(display_bat)
		display_bat.queue_free()
	display_bat = next
	preview_mount.add_child(display_bat)
	wing_left = display_bat.find_child("BatWingL", true, false) as Node3D
	wing_right = display_bat.find_child("BatWingR", true, false) as Node3D
	lite = use_lite
	asset_label.text = "BAT / LITE" if lite else "BAT / STANDARD"

func _activate(id: String, hand: int) -> void:
	super._activate(id, hand)
	if id == "test":
		_load_bat(not lite)
	elif id == "reset":
		_load_bat(false)

func _process(delta: float) -> void:
	super._process(delta)
	if smoke:
		return
	elapsed += delta
	# Idle motion only, no artificial movement of camera or player.
	var flap := sin(elapsed * 2.2) * 0.18
	if is_instance_valid(wing_left):
		wing_left.rotation.y = flap
	if is_instance_valid(wing_right):
		wing_right.rotation.y = -flap

func _smoke() -> void:
	var data := Assets.catalog()
	var entries: Dictionary = data.get("assets", {})
	var errors: Array[String] = []
	if entries.size() != 2:
		errors.append("catalog")
	for id in ["bat_standard", "bat_lite"]:
		var model := Assets.instantiate(id)
		if model == null:
			errors.append(id + " import")
			continue
		var count := Assets.mesh_count(model)
		if count < 40:
			errors.append(id + " mesh count")
		for pivot in ["BatWingL", "BatWingR", "BatFootL", "BatFootR", "BatArmL", "BatArmR", "BatTail"]:
			if model.find_child(pivot, true, false) == null:
				errors.append(id + " " + pivot)
		print("XR002_IMPORT_PASS ", id, " meshes=", count)
		model.free()
	if not is_instance_valid(display_bat) or wing_left == null or wing_right == null:
		errors.append("display")
	_load_bat(true)
	if not lite or wing_left == null:
		errors.append("LOD switch")
	_load_bat(false)
	if lite or wing_right == null:
		errors.append("LOD reset")
	if not errors.is_empty():
		push_error("XR002_SMOKE_FAIL " + str(errors))
		get_tree().quit(1)
		return
	print("XR002_SMOKE_PASS: catalog, GLB import, pivots, mesh count, LOD switching")
	super._smoke()
